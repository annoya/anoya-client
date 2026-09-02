// Package mobile is the Android surface of the engine, generated into an AAR
// by `gomobile bind` (see ../build-aar.sh). Same contract as the C surface in
// ../core.go — the host passes a tun fd and a rendered config — plus one thing
// Android alone needs: a SocketProtector.
//
// On Apple the extension owns routing and the engine binds its dials to the
// physical interface. Android has no interface binding an app may use; the one
// sanctioned way around the VPN's own routes is VpnService.protect(fd). So the
// service hands us a protector, and every socket the engine opens goes through
// it before it dials — the proxy connection leaves on the physical network,
// everything else stays inside the tunnel.
package mobile

import (
	"fmt"
	"syscall"

	"github.com/metacubex/mihomo/component/dialer"

	"mihomocore/engine"
)

// SocketProtector is implemented by the Android VpnService.
type SocketProtector interface {
	// Protect marks a socket to bypass the VPN. Returns false when the mark
	// could not be applied.
	Protect(fd int) bool
}

// SetSocketProtector installs the protector for every socket the engine dials.
// Must be called before Start; the engine keeps it across reloads.
//
// A dial whose protect failed is refused, not sent: unprotected it would be
// routed back into the tunnel it is trying to carry — a loop, not a leak, but
// the failure mode is the same silence and this way it has a name in the log.
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

// Version reports the embedded engine build, for diagnostics.
func Version() string { return engine.Version() }

// SetHomeDir points the engine at its working directory — where it looks for
// the GeoIP/GeoSite databases. Call before Start.
func SetHomeDir(path string) { engine.SetHomeDir(path) }

// SetLogLevel applies a mihomo log level ("silent", "error", "warning",
// "info", "debug") to the running engine, without a reconnect.
func SetLogLevel(level string) { engine.SetLogLevel(level) }

// Start brings the engine up on the given tun fd (from
// VpnService.Builder.establish) and rendered config.
func Start(fd int, configYAML string) error { return engine.Start(fd, configYAML) }

// Reload swaps the running engine onto a new config without touching the fd,
// so the session survives a location or profile switch.
func Reload(fd int, configYAML string) error { return engine.Reload(fd, configYAML) }

// Stop shuts the engine down.
func Stop() { engine.Stop() }

// ProxyBytes reports bytes carried through the named outbound in this session
// as "<up>:<down>" — one string because gomobile cannot return two integers,
// and the caller parses it anyway.
func ProxyBytes(name string) string {
	up, down := engine.ProxyBytes(name)
	return fmt.Sprintf("%d:%d", up, down)
}

// URLTest sends one HTTP HEAD through the named outbound and returns the round
// trip in milliseconds, or an error saying why nothing came back. Blocking:
// the caller is the tunnel service, which answers the app over its binder.
func URLTest(name, url string, timeoutMs int) (int, error) {
	return engine.URLTest(name, url, timeoutMs)
}

// GroupMember returns which member of a proxy group the engine is currently
// using ("" when the running config has no such group).
func GroupMember(group string) string { return engine.GroupMember(group) }
