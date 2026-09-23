package mobile

import (
	"fmt"
	"syscall"

	"github.com/metacubex/mihomo/component/dialer"

	"mihomocore/engine"
)

type SocketProtector interface {
	Protect(fd int) bool
}

func SetSocketProtector(p SocketProtector) {
	if p == nil {
		dialer.DefaultSocketHook = nil
		return
	}
	dialer.DefaultSocketHook = func(network, address string, conn syscall.RawConn) error {
		var protectErr error
		err := conn.Control(func(fd uintptr) {
			if !p.Protect(int(fd)) {
				protectErr = fmt.Errorf("protect failed for %s %s", network, address)
			}
		})
		if err != nil {
			return err
		}
		return protectErr
	}
}

func Version() string { return engine.Version() }

func SetHomeDir(path string) { engine.SetHomeDir(path) }

func SetLogLevel(level string) { engine.SetLogLevel(level) }

func Start(fd int, configYAML string) error { return engine.Start(fd, configYAML) }

func Reload(fd int, configYAML string) error { return engine.Reload(fd, configYAML) }

func Stop() { engine.Stop() }

// One string because gomobile cannot return two integers.
func ProxyBytes(name string) string {
	up, down := engine.ProxyBytes(name)
	return fmt.Sprintf("%d:%d", up, down)
}

func URLTest(name, url string, timeoutMs int) (int, error) {
	return engine.URLTest(name, url, timeoutMs)
}

func GroupMember(group string) string { return engine.GroupMember(group) }
