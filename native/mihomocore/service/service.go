// Package service is the Windows tunnel: the mihomo engine hosted in a process
// with the privilege to create a TUN adapter, driven by the unprivileged app
// over a named pipe.
//
// It speaks the same contract as the Apple extension and the Android tunnel
// process — start, stop, reload, the probes, the logs, a status the app
// subscribes to — so the Dart side sees one VpnCore with the platform
// difference on the far side of the pipe. Everything here that is not the wire
// itself is a port of MihomoVpnService.kt, because the two solve the same
// problem: a tunnel that outlives the app, dies on its own, and has to be
// explained afterwards.
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

// The status vocabulary shared with the other platforms (TunnelState.kt,
// VpnStatus on the Dart side).
const (
	StatusDisconnected = "disconnected"
	StatusConnecting   = "connecting"
	StatusConnected    = "connected"
	StatusError        = "error"
)

// TunnelOutbound is the group every rendered config routes through
// (kTunnelOutbound in mihomo_tun_config.dart). Probing the group and not a
// member means the probe follows whatever the engine picked.
const TunnelOutbound = "PROXY"

// Service owns the engine's state and answers the app.
type Service struct {
	eng   Engine
	files Files
	now   func() time.Time

	// runMu serialises start, stop and reload — the engine has its own mutex,
	// but the status transitions around a call have to be atomic with it, or a
	// stop landing mid-start would be overwritten by "connected".
	runMu sync.Mutex

	mu     sync.Mutex
	status string
	since  time.Time
	conns  map[*conn]struct{}
}

func New(eng Engine, files Files) *Service {
	return &Service{
		eng:    eng,
		files:  files,
		now:    time.Now,
		status: StatusDisconnected,
		conns:  map[*conn]struct{}{},
	}
}

// Status is the current state, for the process hosting the service.
func (s *Service) Status() string {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.status
}

func (s *Service) setStatus(st string) {
	s.mu.Lock()
	s.status = st
	subs := make([]*conn, 0, len(s.conns))
	for c := range s.conns {
		subs = append(subs, c)
	}
	s.mu.Unlock()
	for _, c := range subs {
		c.send(event{Event: "status", Status: st})
	}
}

// Shutdown is the service being stopped by the system: the tunnel goes down
// with it, and every client learns so before its pipe closes.
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

// Handle answers one request. Every method the app can send is here; the
// names are the MethodChannel names, so the Dart side stays a rename away from
// the other platforms.
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
		s.persist(config, boolOr("log_enabled", true))
		return nil, s.start(config)

	case "stop":
		s.stop()
		return nil, nil

	case "set_auto_connect":
		// The one thing that may raise a tunnel with no app running. Kept
		// apart from connect and disconnect on purpose: those say what the
		// user wants now, this says what they want every time the machine
		// comes back, and the two are not the same question.
		s.files.SetAutoConnect(boolOr("enabled", false))
		return nil, nil

	case "reload":
		config := str("config")
		if config == "" {
			return nil, errors.New("config required")
		}
		s.persist(config, boolOr("log_enabled", true))
		return nil, s.reload(config)

	case "sync_config":
		// Keep the saved config in step with the selection, so a start nobody
		// is watching never resurrects a stale one.
		config := str("config")
		if config == "" {
			return nil, errors.New("config required")
		}
		s.persist(config, boolOr("log_enabled", true))
		return nil, nil

	case "remove_profile":
		// No system profile to remove; what must not outlive the last
		// configuration is the saved config a boot-time start would run. The
		// auto-connect switch is left alone: it is the user's answer, not a
		// property of the configuration they just removed.
		s.stop()
		s.files.RemoveConfig()
		return nil, nil

	case "set_on_demand":
		// Windows has no on-demand rules of its own. Never armed here.
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
		// Refused rather than attempted when the tunnel is down: the engine
		// would answer "no outbound named PROXY", which reads as a broken
		// config instead of "there is nothing running to test".
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
		s.eng.SetLogLevel(logLevel(on))
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

// start brings the tunnel up from the config just saved. A second start while
// one is up or under way is not an error and does nothing, as on Android: the
// app and a boot-time start can both ask, and two engines on one adapter is not
// what either of them meant.
func (s *Service) start(config string) error {
	s.runMu.Lock()
	defer s.runMu.Unlock()
	switch s.Status() {
	case StatusConnecting, StatusConnected:
		return nil
	}
	s.setStatus(StatusConnecting)
	s.eng.SetHomeDir(s.files.Dir)
	s.eng.SetLogLevel(logLevel(s.files.LogsEnabled()))
	s.files.Append("starting engine")
	if err := s.eng.Start(config); err != nil {
		s.files.Append("start failed: " + err.Error())
		s.files.RecordError(err.Error())
		s.setStatus(StatusError)
		// Whatever half came up goes down with the attempt; "error" is a
		// moment, not a state the tunnel can be left in.
		s.eng.Stop()
		s.setStatus(StatusDisconnected)
		return err
	}
	s.files.ClearError()
	s.mu.Lock()
	s.since = s.now()
	s.mu.Unlock()
	s.setStatus(StatusConnected)
	s.files.Append("tunnel up")
	return nil
}

// StartSaved brings the tunnel up from the persisted config with no app
// involved — the service starting with the machine.
//
// It runs only when auto-connect is on. The config is saved on every sync of
// the selection, so it exists after any run of the app at all; starting from
// its mere presence turned a reboot into a VPN nobody had asked for. An absent
// flag is not an error: it is the ordinary answer for anyone who never turned
// the switch on.
func (s *Service) StartSaved() error {
	if !s.files.AutoConnect() {
		return nil
	}
	config, err := s.files.LoadConfig()
	if err != nil {
		return nil
	}
	return s.start(config)
}

func (s *Service) stop() {
	s.runMu.Lock()
	defer s.runMu.Unlock()
	if s.Status() == StatusDisconnected {
		return
	}
	s.eng.Stop()
	s.mu.Lock()
	s.since = time.Time{}
	s.mu.Unlock()
	s.setStatus(StatusDisconnected)
	s.files.Append("tunnel down")
}

// reload swaps the running engine onto a new config under the standing
// adapter. Refused when nothing runs; on a rejected config the engine keeps
// the previous one, and the error says so to the app.
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

// --- the wire ---------------------------------------------------------------

// One JSON object per line, both ways. The app sends requests and reads
// responses matched by id; the service pushes status events in between,
// starting with the current status the moment a client connects — the app may
// have just been opened over a tunnel the service started at boot.
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
	Status string `json:"status"`
}

// A rendered config with a long rule list runs to megabytes; the line buffer
// has to hold one.
const maxLineBytes = 16 << 20

// A client that stops reading must not stop the service: a status push is
// delivered to every client in turn, and a write that blocks on one of them
// would hold the response another is waiting for. So each connection owns a
// queue and a writer; a queue that fills means a client that is not reading,
// and that client is disconnected rather than waited on.
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

// close ends the connection once. The queue is never closed: a request still
// being handled answers into it after the client has gone, and that answer is
// dropped here rather than panicking there.
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

// Serve accepts clients until the listener closes.
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

// ServeConn talks to one client until it hangs up. Requests are answered
// concurrently: a probe blocks for as long as its timeout allows, and it must
// not hold a stop behind it.
func (s *Service) ServeConn(nc net.Conn) {
	c := newConn(nc)
	s.mu.Lock()
	s.conns[c] = struct{}{}
	current := s.status
	s.mu.Unlock()
	defer func() {
		s.mu.Lock()
		delete(s.conns, c)
		s.mu.Unlock()
		c.close()
	}()

	c.send(event{Event: "status", Status: current})

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
