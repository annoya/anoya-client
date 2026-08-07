package main

// Real mihomo engine wiring. The Network Extension passes the utun file
// descriptor and a mihomo YAML config (with a TUN inbound). We parse the
// config, bind the TUN to the provided fd, and apply it. The C surface in
// core.go is unchanged.

import (
	"context"
	"fmt"
	"strings"
	"time"

	"github.com/metacubex/mihomo/component/dialer"
	"github.com/metacubex/mihomo/config"
	"github.com/metacubex/mihomo/constant"
	"github.com/metacubex/mihomo/hub/executor"
	"github.com/metacubex/mihomo/log"
	"github.com/metacubex/mihomo/tunnel/statistic"
)

func engineVersion() string {
	return "mihomo " + constant.Version
}

// setEngineHomeDir sets mihomo's working directory (GeoIP/GeoSite database
// location). Must be called before startEngine; the config keeps
// geo-auto-update off, so mihomo only ever reads what the host app downloaded.
func setEngineHomeDir(path string) {
	if path != "" {
		constant.SetHomeDir(path)
	}
}

// setEngineLogLevel changes the engine's log level on a running tunnel. The
// level in the config is only read when the config is applied, so without this
// turning logging off would not take effect until the next connect — while the
// engine kept writing to its log file the whole time.
func setEngineLogLevel(level string) {
	if l, ok := log.LogLevelMapping[strings.ToLower(level)]; ok {
		log.SetLevel(l)
	}
}

func startEngine(fd int, configYAML string) error {
	_, err := applyEngineConfig(fd, configYAML)
	return err
}

// reloadEngine applies a new config to the running engine, keeping the same
// tunnel fd. The tun section of our rendered configs never changes between
// locations/profiles, so mihomo skips re-creating the TUN listener and the fd
// (and with it the NE session) stays untouched — that is what makes switching
// leak-free: the OS keeps routing all traffic into the utun for the whole swap.
//
// The dial to the newly selected server has to leave over the physical
// interface — the OS default route points into the tunnel. That is mihomo's own
// per-dial detection (auto-detect-interface), installed by the TUN listener and
// kept current by its route monitor; since a hot reload does not re-create the
// listener, it survives the swap. Deliberately NOT pinned as `interface-name`:
// that would take priority over the detector and go stale the moment the machine
// changes network.
func reloadEngine(fd int, configYAML string) error {
	cfg, err := applyEngineConfig(fd, configYAML)
	if err != nil {
		return err
	}
	log.Infoln("[hot switch] redialing %d live connection(s) through the new server",
		closeTrackedConnections())
	go logProxyEgress(cfg)
	return nil
}

// closeTrackedConnections ends the connections the engine is currently proxying,
// so they are re-established through the newly selected server.
//
// Applying a config only changes where *new* connections go. Everything already
// established keeps running over its open socket to the previous server, and
// since browsers and system services hold connections open for minutes, a switch
// would look like it did nothing at all — the visible exit address would not
// change. Closing them is safe: they live inside the tunnel, so clients redial
// without anything escaping.
func closeTrackedConnections() int {
	closed := 0
	statistic.DefaultManager.Range(func(c statistic.Tracker) bool {
		_ = c.Close()
		closed++
		return true
	})
	return closed
}

func applyEngineConfig(fd int, configYAML string) (*config.Config, error) {
	if fd <= 0 {
		return nil, fmt.Errorf("invalid tun fd %d", fd)
	}
	if configYAML == "" {
		return nil, fmt.Errorf("empty config")
	}
	cfg, err := executor.ParseWithBytes([]byte(configYAML))
	if err != nil {
		return nil, fmt.Errorf("parse config: %w", err)
	}
	// Bind the TUN inbound to the fd provided by the Network Extension instead
	// of letting mihomo create its own interface.
	cfg.General.Tun.Enable = true
	cfg.General.Tun.FileDescriptor = fd
	executor.ApplyConfig(cfg, true)
	return cfg, nil
}

// logProxyEgress records how a dial to the newly selected server leaves the
// extension. Nothing else can tell the two failure modes apart: a dead server
// and a socket that never reaches the physical interface both surface as an i/o
// timeout in the tunnel log. The local address in the success line names the
// interface that carried it.
func logProxyEgress(cfg *config.Config) {
	proxy, ok := cfg.Proxies["proxy"]
	if !ok {
		return
	}
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	conn, err := dialer.DialContext(ctx, "tcp", proxy.Addr())
	if err != nil {
		log.Warnln("[egress] %s unreachable after reload: %v", proxy.Addr(), err)
		return
	}
	log.Infoln("[egress] %s reachable after reload, from %s", proxy.Addr(), conn.LocalAddr())
	_ = conn.Close()
}

func stopEngine() {
	executor.Shutdown()
}
