package service

import (
	"os"

	"github.com/sirupsen/logrus"

	"mihomocore/engine"
)

// Engine is the part of the mihomo wrapper the service drives. An interface so
// the service's own behaviour — status, persisted files, the wire protocol —
// is tested without bringing a tunnel up, which needs SYSTEM and a Wintun
// adapter.
type Engine interface {
	Version() string
	SetHomeDir(dir string)
	SetLogLevel(level string)
	Start(configYAML string) error
	Reload(configYAML string) error
	Stop()
	URLTest(name, url string, timeoutMs int) (int, error)
	ProxyBytes(name string) (up, down int64)
	GroupMember(group string) string
}

// RealEngine is the mihomo engine creating its own device — the Windows shape.
type RealEngine struct{}

func (RealEngine) Version() string                       { return engine.Version() }
func (RealEngine) SetHomeDir(dir string)                 { engine.SetHomeDir(dir) }
func (RealEngine) SetLogLevel(level string)              { engine.SetLogLevel(level) }
func (RealEngine) Start(configYAML string) error         { return engine.StartOwnDevice(configYAML) }
func (RealEngine) Reload(configYAML string) error        { return engine.ReloadOwnDevice(configYAML) }
func (RealEngine) Stop()                                 { engine.Stop() }
func (RealEngine) GroupMember(group string) string       { return engine.GroupMember(group) }
func (RealEngine) ProxyBytes(name string) (int64, int64) { return engine.ProxyBytes(name) }
func (RealEngine) URLTest(name, url string, timeoutMs int) (int, error) {
	return engine.URLTest(name, url, timeoutMs)
}

// RedirectEngineLog sends mihomo's own log to a file the app can fetch. The
// other tunnel processes point stdout at a file for the same reason — a service
// has no console, and the log is the only account of what the engine did.
// Appended, and pruned by [RotateIfNeeded] whenever the app reads it.
func RedirectEngineLog(path string) error {
	fh, err := os.OpenFile(path, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0o644)
	if err != nil {
		return err
	}
	logrus.SetOutput(fh)
	return nil
}
