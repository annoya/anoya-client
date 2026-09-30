package service

import (
	"bufio"
	"encoding/json"
	"errors"
	"net"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"testing"
	"time"
)

type fakeEngine struct {
	mu       sync.Mutex
	startErr error
	reloadEr error
	calls    []string
	configs  []string
	level    string
	home     string
}

func (f *fakeEngine) record(c string) {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.calls = append(f.calls, c)
}
func (f *fakeEngine) Version() string          { return "mihomo test" }
func (f *fakeEngine) SetHomeDir(dir string)    { f.home = dir }
func (f *fakeEngine) SetLogLevel(level string) { f.level = level }
func (f *fakeEngine) Start(c string) error {
	f.record("start")
	f.configs = append(f.configs, c)
	return f.startErr
}
func (f *fakeEngine) Reload(c string) error {
	f.record("reload")
	f.configs = append(f.configs, c)
	return f.reloadEr
}
func (f *fakeEngine) Stop()                                    { f.record("stop") }
func (f *fakeEngine) GroupMember(string) string                { return "p1" }
func (f *fakeEngine) ProxyBytes(string) (int64, int64)         { return 10, 20 }
func (f *fakeEngine) URLTest(string, string, int) (int, error) { return 42, nil }

func (f *fakeEngine) sequence() string {
	f.mu.Lock()
	defer f.mu.Unlock()
	return strings.Join(f.calls, ",")
}

func harness(t *testing.T) (*Service, *fakeEngine, Files) {
	t.Helper()
	files := Files{Dir: t.TempDir()}
	eng := &fakeEngine{}
	s := New(eng, files)
	return s, eng, files
}

func TestStartPersistsThenBringsTheTunnelUp(t *testing.T) {
	s, eng, files := harness(t)
	at := time.Date(2026, 9, 4, 12, 0, 0, 0, time.UTC)
	s.now = func() time.Time { return at }

	if _, err := s.Handle("start", map[string]any{"config": "tun: {}", "log_enabled": false}); err != nil {
		t.Fatal(err)
	}
	if got, _ := files.LoadConfig(); got != "tun: {}" {
		t.Fatalf("config not persisted before the start, got %q", got)
	}
	if files.LogsEnabled() {
		t.Fatal("the log switch travels with the start")
	}
	if eng.level != "silent" || eng.home != files.Dir {
		t.Fatalf("engine set up wrong: level=%q home=%q", eng.level, eng.home)
	}
	if s.Status() != StatusConnected {
		t.Fatalf("status %q", s.Status())
	}
	since, _ := s.Handle("connected_since", nil)
	if since.(float64) != float64(at.Unix()) {
		t.Fatalf("connected_since %v, want %d", since, at.Unix())
	}
	if _, err := s.Handle("start", map[string]any{"config": "tun: {}"}); err != nil {
		t.Fatal(err)
	}
	if eng.sequence() != "start" {
		t.Fatalf("engine calls: %s", eng.sequence())
	}
}

func TestAFailedStartIsRecordedAndLeavesNothingHalfUp(t *testing.T) {
	s, eng, files := harness(t)
	eng.startErr = errors.New("parse config: bad")

	_, err := s.Handle("start", map[string]any{"config": "mode: nonsense"})
	if err == nil || err.Error() != "parse config: bad" {
		t.Fatalf("start error %v", err)
	}
	if s.Status() != StatusDisconnected {
		t.Fatalf("status %q: error is a moment, not a resting state", s.Status())
	}
	if eng.sequence() != "start,stop" {
		t.Fatalf("a failed start must be followed by a stop, got %s", eng.sequence())
	}
	if got, _ := s.Handle("disconnect_error", nil); got != "parse config: bad" {
		t.Fatalf("disconnect_error %q", got)
	}
	if files.LastError() == "" {
		t.Fatal("the reason must survive in a file, not only in memory")
	}

	eng.startErr = nil
	if _, err := s.Handle("start", map[string]any{"config": "mode: ok"}); err != nil {
		t.Fatal(err)
	}
	if got, _ := s.Handle("disconnect_error", nil); got != "" {
		t.Fatalf("stale disconnect_error %q after a good start", got)
	}
}

func TestProbesAreRefusedWhileNothingRuns(t *testing.T) {
	s, _, _ := harness(t)
	if got, _ := s.Handle("url_test", map[string]any{"url": "https://x"}); got != "err:the tunnel is not running" {
		t.Fatalf("url_test down: %q", got)
	}
	if got, _ := s.Handle("proxy_bytes", nil); got != "0:0" {
		t.Fatalf("proxy_bytes down: %q", got)
	}
	if got, _ := s.Handle("group_member", map[string]any{"group": "PROXY"}); got != "" {
		t.Fatalf("group_member down: %q", got)
	}
	if _, err := s.Handle("reload", map[string]any{"config": "mode: c"}); err == nil {
		t.Fatal("reload with nothing running must be refused")
	}

	_, _ = s.Handle("start", map[string]any{"config": "mode: c"})
	if got, _ := s.Handle("url_test", map[string]any{"url": "https://x", "timeout_ms": 1000.0}); got != "ms:42" {
		t.Fatalf("url_test up: %q", got)
	}
	if got, _ := s.Handle("proxy_bytes", nil); got != "10:20" {
		t.Fatalf("proxy_bytes up: %q", got)
	}
	if got, _ := s.Handle("group_member", map[string]any{"group": "PROXY"}); got != "p1" {
		t.Fatalf("group_member up: %q", got)
	}
}

func TestReloadKeepsTheSessionAndReportsARejectedConfig(t *testing.T) {
	s, eng, files := harness(t)
	_, _ = s.Handle("start", map[string]any{"config": "mode: one"})
	eng.reloadEr = errors.New("parse config: bad")
	_, err := s.Handle("reload", map[string]any{"config": "mode: two"})
	if err == nil {
		t.Fatal("a rejected config must come back as an error")
	}
	if s.Status() != StatusConnected {
		t.Fatalf("a rejected reload must not take the tunnel down, status %q", s.Status())
	}
	if got, _ := files.LoadConfig(); got != "mode: two" {
		t.Fatalf("the saved config follows the selection even when the engine refused it, got %q", got)
	}
	eng.reloadEr = nil
	if _, err := s.Handle("reload", map[string]any{"config": "mode: three"}); err != nil {
		t.Fatal(err)
	}
	if eng.sequence() != "start,reload,reload" {
		t.Fatalf("no stop anywhere on the switch path, got %s", eng.sequence())
	}
}

func TestOnlyTheRenderedShapeReachesTheEngine(t *testing.T) {
	refused := []string{
		"external-controller: 0.0.0.0:9090",
		"listeners:\n  - {name: open, type: socks, listen: 0.0.0.0, port: 1080}",
		"dns:\n  listen: 0.0.0.0:53",
		"tun:\n  include-uid: [1000]",
		"iptables:\n  enable: true",
		"tun: [1]",
		"rule-providers:\n  ads: {type: http, url: 'https://x/y', path: ./r.yaml, behavior: domain}",
		"rule-providers:\n  ads: {type: file, path: ./r.yaml, behavior: domain, proxy: DIRECT}",
		"not a mapping",
	}
	for _, config := range refused {
		for _, method := range []string{"start", "reload", "sync_config"} {
			s, eng, files := harness(t)
			if method == "reload" {
				_, _ = s.Handle("start", map[string]any{"config": "tun: {}"})
				_ = os.Remove(files.Config())
			}
			if _, err := s.Handle(method, map[string]any{"config": config}); err == nil {
				t.Fatalf("%s accepted %q", method, config)
			}
			if _, err := files.LoadConfig(); err == nil {
				t.Fatalf("%s saved the refused %q", method, config)
			}
			if strings.Contains(eng.sequence(), "reload") || len(eng.configs) > 1 {
				t.Fatalf("%s handed the refused %q to the engine", method, config)
			}
		}
	}

	s, eng, files := harness(t)
	if err := files.SaveConfig("external-controller: 0.0.0.0:9090"); err != nil {
		t.Fatal(err)
	}
	files.SetAutoConnect(true)
	if err := s.StartSaved(); err == nil || eng.sequence() != "" {
		t.Fatalf("a boot ran a planted config: err=%v calls=%s", err, eng.sequence())
	}
}

func TestBootConnectsOnlyWhenAutoConnectIsOn(t *testing.T) {
	s, eng, files := harness(t)

	if _, err := s.Handle("sync_config", map[string]any{"config": "tun: {}"}); err != nil {
		t.Fatal(err)
	}
	if err := s.StartSaved(); err != nil {
		t.Fatal(err)
	}
	if eng.sequence() != "" {
		t.Fatalf("a synced config started the tunnel at boot: %q", eng.sequence())
	}
	if s.Status() != StatusDisconnected {
		t.Fatalf("status after a boot with auto-connect off: %v", s.Status())
	}

	if _, err := s.Handle("start", map[string]any{"config": "tun: {}"}); err != nil {
		t.Fatal(err)
	}
	if files.AutoConnect() {
		t.Fatal("connecting turned auto-connect on behind the user")
	}

	if _, err := s.Handle("set_auto_connect", map[string]any{"enabled": true}); err != nil {
		t.Fatal(err)
	}
	next, nextEng, _ := harness(t)
	next.files = files
	if err := next.StartSaved(); err != nil {
		t.Fatal(err)
	}
	if nextEng.sequence() != "start" {
		t.Fatalf("auto-connect did not bring the tunnel up: %q", nextEng.sequence())
	}
}

func TestTurningAutoConnectOffOutlivesAReboot(t *testing.T) {
	s, _, files := harness(t)
	if _, err := s.Handle("sync_config", map[string]any{"config": "tun: {}"}); err != nil {
		t.Fatal(err)
	}
	if _, err := s.Handle("set_auto_connect", map[string]any{"enabled": true}); err != nil {
		t.Fatal(err)
	}
	if _, err := s.Handle("set_auto_connect", map[string]any{"enabled": false}); err != nil {
		t.Fatal(err)
	}

	next, nextEng, _ := harness(t)
	next.files = files
	if err := next.StartSaved(); err != nil {
		t.Fatal(err)
	}
	if nextEng.sequence() != "" {
		t.Fatalf("the tunnel came up with auto-connect off: %q", nextEng.sequence())
	}
}

func TestDisconnectingDoesNotAnswerTheAutoConnectQuestion(t *testing.T) {
	s, _, files := harness(t)
	if _, err := s.Handle("set_auto_connect", map[string]any{"enabled": true}); err != nil {
		t.Fatal(err)
	}
	if _, err := s.Handle("start", map[string]any{"config": "tun: {}"}); err != nil {
		t.Fatal(err)
	}
	if _, err := s.Handle("stop", nil); err != nil {
		t.Fatal(err)
	}
	if !files.AutoConnect() {
		t.Fatal("a manual disconnect switched auto-connect off")
	}
	if _, err := s.Handle("remove_profile", nil); err != nil {
		t.Fatal(err)
	}
	if !files.AutoConnect() {
		t.Fatal("removing a configuration switched auto-connect off")
	}
	if err := s.StartSaved(); err != nil {
		t.Fatal(err)
	}
	if s.Status() != StatusDisconnected {
		t.Fatal("a boot with no saved config still started something")
	}
}

func TestStopAndRemoveProfile(t *testing.T) {
	s, eng, files := harness(t)
	_, _ = s.Handle("start", map[string]any{"config": "mode: c"})
	_, _ = s.Handle("stop", nil)
	if s.Status() != StatusDisconnected {
		t.Fatalf("status %q", s.Status())
	}
	if since, _ := s.Handle("connected_since", nil); since.(float64) != 0 {
		t.Fatalf("connected_since after stop: %v", since)
	}
	_, _ = s.Handle("stop", nil)
	if eng.sequence() != "start,stop" {
		t.Fatalf("engine calls: %s", eng.sequence())
	}
	if _, err := files.LoadConfig(); err != nil {
		t.Fatal("a stop keeps the saved config: the next start runs it")
	}
	_, _ = s.Handle("remove_profile", nil)
	if _, err := files.LoadConfig(); err == nil {
		t.Fatal("remove_profile must leave no config a boot-time start could run")
	}
}

func TestLoggingSwitchAndLogs(t *testing.T) {
	s, eng, files := harness(t)
	_, _ = s.Handle("set_logging", map[string]any{"enabled": false})
	if files.LogsEnabled() || eng.level != "silent" {
		t.Fatal("set_logging must reach both the flag and the engine")
	}
	_, _ = s.Handle("set_logging", map[string]any{"enabled": true})
	if !files.LogsEnabled() || eng.level != "debug" {
		t.Fatal("and back")
	}
	_ = os.WriteFile(files.EngineLog(), []byte("engine line\n"), 0o644)
	files.Append("service line")
	if got, _ := s.Handle("fetch_log", map[string]any{"name": "mihomo"}); got != "engine line\n" {
		t.Fatalf("engine log: %q", got)
	}
	if got, _ := s.Handle("fetch_log", map[string]any{"name": "tunnel"}); !strings.Contains(got.(string), "service line") {
		t.Fatalf("service log: %q", got)
	}
	_, _ = s.Handle("clear_logs", nil)
	if got, _ := s.Handle("fetch_log", map[string]any{"name": "mihomo"}); got != "" {
		t.Fatalf("after clear: %q", got)
	}
}

func TestTailCutsAtALineAndRotationKeepsTheNewestHalf(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "big.log")
	line := strings.Repeat("x", 99) + "\n"
	var b strings.Builder
	for b.Len() < logMaxBytes+100*1024 {
		b.WriteString(line)
	}
	_ = os.WriteFile(path, []byte(b.String()), 0o644)

	got := Files{Dir: dir}.Tail(path)
	if len(got) > logTailBytes || !strings.HasPrefix(got, "x") || !strings.HasSuffix(got, "\n") {
		t.Fatalf("tail is %d bytes, starts %q", len(got), got[:1])
	}
	st, _ := os.Stat(path)
	if st.Size() > logMaxBytes {
		t.Fatalf("log past the cap was not rotated: %d", st.Size())
	}
	if st.Size() < logMaxBytes/2 {
		t.Fatalf("rotation threw away too much: %d", st.Size())
	}
}

func TestUnknownMethodAndMissingConfig(t *testing.T) {
	s, _, _ := harness(t)
	if _, err := s.Handle("nope", nil); err == nil {
		t.Fatal("unknown method must be an error, not a silent null")
	}
	if _, err := s.Handle("start", map[string]any{}); err == nil {
		t.Fatal("start without a config must be refused")
	}
}

type wireClient struct {
	nc  net.Conn
	sc  *bufio.Scanner
	seq int64
}

func dialFake(t *testing.T, s *Service) *wireClient {
	t.Helper()
	server, client := net.Pipe()
	go s.ServeConn(server)
	t.Cleanup(func() { _ = client.Close() })
	sc := bufio.NewScanner(client)
	sc.Buffer(make([]byte, 64*1024), maxLineBytes)
	return &wireClient{nc: client, sc: sc}
}

func (w *wireClient) read(t *testing.T) map[string]any {
	t.Helper()
	if !w.sc.Scan() {
		t.Fatalf("connection closed: %v", w.sc.Err())
	}
	var m map[string]any
	if err := json.Unmarshal(w.sc.Bytes(), &m); err != nil {
		t.Fatalf("bad json %q", w.sc.Text())
	}
	return m
}

func (w *wireClient) call(t *testing.T, method string, args map[string]any) map[string]any {
	t.Helper()
	w.seq++
	b, _ := json.Marshal(request{ID: w.seq, Method: method, Args: args})
	if _, err := w.nc.Write(append(b, '\n')); err != nil {
		t.Fatal(err)
	}
	for {
		m := w.read(t)
		if m["event"] != nil {
			continue
		}
		if m["id"].(float64) != float64(w.seq) {
			t.Fatalf("response for %v while waiting for %d", m["id"], w.seq)
		}
		return m
	}
}

func TestAClientLearnsTheStatusFirstAndOnEveryChange(t *testing.T) {
	s, _, _ := harness(t)
	w := dialFake(t, s)

	first := w.read(t)
	if first["event"] != "status" || first["status"] != StatusDisconnected {
		t.Fatalf("first message must be the current status, got %v", first)
	}

	res := w.call(t, "start", map[string]any{"config": "mode: c"})
	if res["error"] != nil {
		t.Fatalf("start over the wire: %v", res["error"])
	}
	res = w.call(t, "proxy_bytes", nil)
	if res["result"] != "10:20" {
		t.Fatalf("proxy_bytes over the wire: %v", res)
	}

	w2 := dialFake(t, s)
	if got := w2.read(t); got["status"] != StatusConnected {
		t.Fatalf("second client's first message: %v", got)
	}
	_ = w.call(t, "stop", nil)
	if got := w2.read(t); got["status"] != StatusDisconnected {
		t.Fatalf("second client after stop: %v", got)
	}
}

func TestWireErrorsAreAnswersNotHangUps(t *testing.T) {
	s, _, _ := harness(t)
	w := dialFake(t, s)
	_ = w.read(t)
	if res := w.call(t, "nope", nil); res["error"] == nil {
		t.Fatalf("unknown method over the wire: %v", res)
	}
	if _, err := w.nc.Write([]byte("this is not json\n")); err != nil {
		t.Fatal(err)
	}
	if res := w.read(t); res["error"] != "malformed request" {
		t.Fatalf("malformed line: %v", res)
	}
	if res := w.call(t, "version", nil); res["result"] != "mihomo test" {
		t.Fatalf("after the bad line: %v", res)
	}
}
