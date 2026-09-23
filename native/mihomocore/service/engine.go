package service

import (
	"os"

	"github.com/sirupsen/logrus"

	"mihomocore/engine"
)

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

func RedirectEngineLog(path string) error {
	fh, err := os.OpenFile(path, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0o644)
	if err != nil {
		return err
	}
	logrus.SetOutput(fh)
	return nil
}
