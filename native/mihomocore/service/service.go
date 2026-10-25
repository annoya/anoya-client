package service

import (
	"bufio"
	"encoding/json"
	"errors"
	"fmt"
	"net"
	"sync"
	"time"
)

const (
	StatusDisconnected = "disconnected"
	StatusConnecting   = "connecting"
	StatusConnected    = "connected"
	StatusError        = "error"
)

const TunnelOutbound = "PROXY"

const (
	NoticeSilent      = "silent"
	NoticeAnswers     = "answers"
	NoticeStartFailed = "start_failed"
)

const silencePoll = 5 * time.Second

type Service struct {
	eng   Engine
	files Files
	now   func() time.Time

	runMu sync.Mutex

	mu     sync.Mutex
	status string
	since  time.Time
	conns  map[*conn]struct{}
	silent bool
	missed string

	silencePoll time.Duration
	quiet       chan struct{}
}

func New(eng Engine, files Files) *Service {
	return &Service{
		eng:    eng,
		files:  files,
		now:    time.Now,
		status: StatusDisconnected,
		conns:  map[*conn]struct{}{},

		silencePoll: silencePoll,
	}
}

func (s *Service) Status() string {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.status
}

func (s *Service) setStatus(st string) {
	s.mu.Lock()
	s.status = st
	s.mu.Unlock()
	s.broadcast(event{Event: "status", Status: st})
}

func (s *Service) broadcast(ev event) {
	s.mu.Lock()
	subs := make([]*conn, 0, len(s.conns))
	for c := range s.conns {
		subs = append(subs, c)
	}
	s.mu.Unlock()
	for _, c := range subs {
		c.send(ev)
	}
}

func (s *Service) watchSilence(quiet <-chan struct{}) {
	ticker := time.NewTicker(s.silencePoll)
	defer ticker.Stop()
	for {
		select {
		case <-quiet:
			return
		case <-ticker.C:
			now := s.eng.ServerSilent()
			s.mu.Lock()
			changed := now != s.silent
			s.silent = now
			s.mu.Unlock()
			if !changed {
				continue
			}
			if now {
				s.files.Append("the app is told: the server is not answering")
				s.broadcast(event{Event: "notice", Notice: NoticeSilent})
			} else {
				s.broadcast(event{Event: "notice", Notice: NoticeAnswers})
			}
		}
	}
}

func (s *Service) stopWatchingSilence() {
	s.mu.Lock()
	quiet, wasSilent := s.quiet, s.silent
	s.quiet, s.silent = nil, false
	s.mu.Unlock()
	if quiet != nil {
		close(quiet)
	}
	if wasSilent {
		s.broadcast(event{Event: "notice", Notice: NoticeAnswers})
	}
}

func (s *Service) Shutdown() {
	s.stop()
	s.mu.Lock()
	conns := make([]*conn, 0, len(s.conns))
	for c := range s.conns {
		conns = append(conns, c)
	}
	s.mu.Unlock()
	for _, c := range conns {
		c.close()
	}
}

func (s *Service) Handle(method string, args map[string]any) (any, error) {
	str := func(k string) string {
		v, _ := args[k].(string)
		return v
	}
	boolOr := func(k string, def bool) bool {
		if v, ok := args[k].(bool); ok {
			return v
		}
		return def
	}
	intOr := func(k string, def int) int {
		if v, ok := args[k].(float64); ok {
			return int(v)
		}
		return def
	}

	switch method {
	case "version":
		return s.eng.Version(), nil

	case "start":
		config := str("config")
		if config == "" {
			return nil, errors.New("config required")
		}
		if err := checkConfig(config); err != nil {
			return nil, err
		}
		s.persist(config, boolOr("log_enabled", true))
		return nil, s.start(config)

	case "stop":
		s.stop()
		return nil, nil

	case "set_auto_connect":
		s.files.SetAutoConnect(boolOr("enabled", false))
		return nil, nil

	case "reload":
		config := str("config")
		if config == "" {
			return nil, errors.New("config required")
		}
		if err := checkConfig(config); err != nil {
			return nil, err
		}
		if err := s.reload(config); err != nil {
			return nil, err
		}
		s.persist(config, boolOr("log_enabled", true))
		return nil, nil

	case "sync_config":
		config := str("config")
		if config == "" {
			return nil, errors.New("config required")
		}
		if err := checkConfig(config); err != nil {
			return nil, err
		}
		s.persist(config, boolOr("log_enabled", true))
		return nil, nil

	case "remove_profile":
		s.stop()
		s.files.RemoveConfig()
		return nil, nil

	case "set_on_demand":
		return false, nil

	case "connected_since":
		s.mu.Lock()
		defer s.mu.Unlock()
		if s.since.IsZero() {
			return 0.0, nil
		}
		return float64(s.since.UnixMilli()) / 1000, nil

	case "disconnect_error":
		return s.files.LastError(), nil

	case "group_member":
		if s.Status() != StatusConnected {
			return "", nil
		}
		return s.eng.GroupMember(str("group")), nil

	case "proxy_bytes":
		if s.Status() != StatusConnected {
			return "0:0", nil
		}
		up, down := s.eng.ProxyBytes(TunnelOutbound)
		return fmt.Sprintf("%d:%d", up, down), nil

	case "url_test":
		if s.Status() != StatusConnected {
			return "err:the tunnel is not running", nil
		}
		delay, err := s.eng.URLTest(TunnelOutbound, str("url"), intOr("timeout_ms", 5000))
		if err != nil {
			return "err:" + err.Error(), nil
		}
		return fmt.Sprintf("ms:%d", delay), nil

	case "set_logging":
		on := boolOr("enabled", true)
		s.files.SetLogsEnabled(on)
		s.applyLogging()
		return nil, nil

	case "clear_logs":
		s.files.ClearLogs()
		return nil, nil

	case "fetch_log":
		if str("name") == "mihomo" {
			return s.files.Tail(s.files.EngineLog()), nil
		}
		return s.files.Tail(s.files.ServiceLog()), nil

	case "shared_dir":
		return s.files.Dir, nil
	}
	return nil, fmt.Errorf("unknown method %q", method)
}

func (s *Service) applyLogging() {
	on := s.files.LogsEnabled()
	s.eng.SetLogLevel(logLevel(on))
	if on {
		s.eng.SetJournal(s.files.ServiceLog())
	} else {
		s.eng.SetJournal("")
	}
}

func logLevel(on bool) string {
	if on {
		return "debug"
	}
	return "silent"
}

func (s *Service) persist(config string, logEnabled bool) {
	if err := s.files.SaveConfig(config); err != nil {
		s.files.Append("could not save the config: " + err.Error())
	}
	s.files.SetLogsEnabled(logEnabled)
}

func (s *Service) start(config string) error {
	s.runMu.Lock()
	defer s.runMu.Unlock()
	switch s.Status() {
	case StatusConnecting, StatusConnected:
		return nil
	}
	s.setStatus(StatusConnecting)
	s.eng.SetHomeDir(s.files.Dir)
	s.eng.SetEngineLog(s.files.EngineLog())
	s.applyLogging()
	s.files.Append("starting engine")
	if err := s.eng.Start(config); err != nil {
		s.files.Append("start failed: " + err.Error())
		s.files.RecordError(err.Error())
		s.setStatus(StatusError)
		s.eng.Stop()
		s.setStatus(StatusDisconnected)
		return err
	}
	s.files.ClearError()
	quiet := make(chan struct{})
	s.mu.Lock()
	s.since = s.now()
	s.quiet = quiet
	s.mu.Unlock()
	s.setStatus(StatusConnected)
	s.files.Append("tunnel up")
	go s.watchSilence(quiet)
	return nil
}

func (s *Service) StartSaved() error {
	if !s.files.AutoConnect() {
		return nil
	}
	config, err := s.files.LoadConfig()
	if err != nil {
		return nil
	}
	if err := checkConfig(config); err != nil {
		s.files.Append("saved config refused: " + err.Error())
		s.noticeStartFailed()
		return err
	}
	s.files.Append("auto-connect: starting the saved config")
	if err := s.start(config); err != nil {
		s.noticeStartFailed()
		return err
	}
	return nil
}

func (s *Service) noticeStartFailed() {
	s.mu.Lock()
	nobody := len(s.conns) == 0
	if nobody {
		s.missed = NoticeStartFailed
	}
	s.mu.Unlock()
	if !nobody {
		s.broadcast(event{Event: "notice", Notice: NoticeStartFailed})
	}
}

func (s *Service) stop() {
	s.runMu.Lock()
	defer s.runMu.Unlock()
	if s.Status() == StatusDisconnected {
		return
	}
	s.stopWatchingSilence()
	s.eng.Stop()
	s.mu.Lock()
	up := s.now().Sub(s.since)
	if s.since.IsZero() {
		up = 0
	}
	s.since = time.Time{}
	s.mu.Unlock()
	s.setStatus(StatusDisconnected)
	s.files.Append(fmt.Sprintf("tunnel down after %s", up.Round(time.Second)))
}

func (s *Service) reload(config string) error {
	s.runMu.Lock()
	defer s.runMu.Unlock()
	if s.Status() != StatusConnected {
		return errors.New("tunnel is not running")
	}
	if err := s.eng.Reload(config); err != nil {
		s.files.Append("hot reload failed: " + err.Error())
		return err
	}
	s.files.Append("hot reload applied")
	return nil
}

type request struct {
	ID     int64          `json:"id"`
	Method string         `json:"method"`
	Args   map[string]any `json:"args"`
}

type response struct {
	ID     int64  `json:"id"`
	Result any    `json:"result"`
	Error  string `json:"error,omitempty"`
}

type event struct {
	Event  string `json:"event"`
	Status string `json:"status,omitempty"`
	Notice string `json:"notice,omitempty"`
}

const maxLineBytes = 16 << 20

const outboundQueue = 64

type conn struct {
	nc   net.Conn
	out  chan []byte
	done chan struct{}
	once sync.Once
}

func newConn(nc net.Conn) *conn {
	c := &conn{nc: nc, out: make(chan []byte, outboundQueue), done: make(chan struct{})}
	go c.writeLoop()
	return c
}

func (c *conn) writeLoop() {
	for {
		select {
		case <-c.done:
			return
		case b := <-c.out:
			if _, err := c.nc.Write(b); err != nil {
				c.close()
				return
			}
		}
	}
}

func (c *conn) close() {
	c.once.Do(func() {
		_ = c.nc.Close()
		close(c.done)
	})
}

func (c *conn) send(v any) {
	b, err := json.Marshal(v)
	if err != nil {
		return
	}
	select {
	case <-c.done:
	case c.out <- append(b, '\n'):
	default:
		c.close()
	}
}

func (s *Service) Serve(ln net.Listener) error {
	for {
		nc, err := ln.Accept()
		if err != nil {
			if errors.Is(err, net.ErrClosed) {
				return nil
			}
			return err
		}
		go s.ServeConn(nc)
	}
}

func (s *Service) ServeConn(nc net.Conn) {
	c := newConn(nc)
	s.mu.Lock()
	s.conns[c] = struct{}{}
	current, silent, missed := s.status, s.silent, s.missed
	s.missed = ""
	s.mu.Unlock()
	defer func() {
		s.mu.Lock()
		delete(s.conns, c)
		s.mu.Unlock()
		c.close()
	}()

	c.send(event{Event: "status", Status: current})
	if silent {
		c.send(event{Event: "notice", Notice: NoticeSilent})
	}
	if missed != "" {
		c.send(event{Event: "notice", Notice: missed})
	}

	sc := bufio.NewScanner(nc)
	sc.Buffer(make([]byte, 64*1024), maxLineBytes)
	for sc.Scan() {
		line := sc.Bytes()
		if len(line) == 0 {
			continue
		}
		var req request
		if err := json.Unmarshal(line, &req); err != nil {
			c.send(response{ID: 0, Error: "malformed request"})
			continue
		}
		go func(req request) {
			res, err := s.Handle(req.Method, req.Args)
			out := response{ID: req.ID, Result: res}
			if err != nil {
				out.Error = err.Error()
			}
			c.send(out)
		}(req)
	}
}
