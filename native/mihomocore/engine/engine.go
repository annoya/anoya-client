package engine

import (
	"context"
	"errors"
	"fmt"
	"os"
	"regexp"
	"strings"
	"sync"
	"time"

	"github.com/metacubex/mihomo/component/dialer"
	"github.com/metacubex/mihomo/config"
	"github.com/metacubex/mihomo/constant"
	"github.com/metacubex/mihomo/hub/executor"
	"github.com/metacubex/mihomo/listener"
	LC "github.com/metacubex/mihomo/listener/config"
	"github.com/metacubex/mihomo/log"
	"github.com/metacubex/mihomo/tunnel"
	"github.com/metacubex/mihomo/tunnel/statistic"
)

func Version() string {
	return "mihomo " + constant.Version
}

func SetHomeDir(path string) {
	mu.Lock()
	defer mu.Unlock()
	if path != "" {
		constant.SetHomeDir(path)
	}
	configureEngineGlobals()
}

var engineGlobalsOnce sync.Once

func configureEngineGlobals() {
	engineGlobalsOnce.Do(func() {
		// mihomo strips the tun IPv6 on a v4-only host, so a reload closes the host fd.
		os.Setenv("SKIP_SYSTEM_IPV6_CHECK", "1")
	})
}

func SetLogLevel(level string) {
	mu.Lock()
	defer mu.Unlock()
	if l, ok := log.LogLevelMapping[strings.ToLower(level)]; ok {
		log.SetLevel(l)
	}
}

var mu sync.Mutex

type appliedConfig struct {
	fd        int
	ownDevice bool
	yaml      string
}

var running *appliedConfig

var errNotRunning = errors.New("the engine is not running")

func Start(fd int, configYAML string) error {
	mu.Lock()
	defer mu.Unlock()
	return start(fd, false, configYAML)
}

func StartOwnDevice(configYAML string) error {
	mu.Lock()
	defer mu.Unlock()
	return start(0, true, configYAML)
}

func start(fd int, ownDevice bool, configYAML string) error {
	if _, err := applyConfig(fd, ownDevice, configYAML); err != nil {
		return err
	}
	running = &appliedConfig{fd: fd, ownDevice: ownDevice, yaml: configYAML}
	startWatchdog()
	return nil
}

func Reload(fd int, configYAML string) error {
	mu.Lock()
	defer mu.Unlock()
	return reload(fd, false, configYAML)
}

func ReloadOwnDevice(configYAML string) error {
	mu.Lock()
	defer mu.Unlock()
	return reload(0, true, configYAML)
}

func Recover(reason string) error {
	mu.Lock()
	defer mu.Unlock()
	if running == nil {
		return errNotRunning
	}
	log.Warnln("[recover] %s: reloading the engine on the running config", reason)
	level := log.Level()
	defer log.SetLevel(level)
	return reload(running.fd, running.ownDevice, running.yaml)
}

func reload(fd int, ownDevice bool, configYAML string) error {
	previous := tunnel.Proxies()
	defer func() { closeReplacedProxies(previous, tunnel.Proxies()) }()
	cfg, err := applyConfig(fd, ownDevice, configYAML)
	if err != nil {
		return err
	}
	running = &appliedConfig{fd: fd, ownDevice: ownDevice, yaml: configYAML}
	log.Infoln("[hot switch] redialing %d live connection(s) through the new server",
		closeTrackedConnections())
	go logProxyEgress(cfg)
	return nil
}

func closeTrackedConnections() int {
	closed := 0
	statistic.DefaultManager.Range(func(c statistic.Tracker) bool {
		_ = c.Close()
		closed++
		return true
	})
	return closed
}

func closeReplacedProxies(previous, current map[string]constant.Proxy) {
	for name, p := range previous {
		if current[name] != p {
			_ = p.Close()
		}
	}
}

func applyConfig(fd int, ownDevice bool, configYAML string) (*config.Config, error) {
	configureEngineGlobals()
	if !ownDevice && fd <= 0 {
		return nil, fmt.Errorf("invalid tun fd %d", fd)
	}
	if configYAML == "" {
		return nil, fmt.Errorf("empty config")
	}
	openCacheFile()
	cfg, err := executor.ParseWithBytes([]byte(configYAML))
	if err != nil {
		return nil, fmt.Errorf("parse config: %s", sanitizeConfigError(err))
	}
	cfg.General.Tun.Enable = true
	if !ownDevice {
		cfg.General.Tun.FileDescriptor = fd
		leaveDialsUnbound(cfg)
	}
	executor.ApplyConfig(cfg, true)
	// ApplyConfig only logs a failed TUN re-creation, which has already closed our fd.
	if !listener.GetTunConf().Enable {
		return nil, fmt.Errorf("engine applied the config but the tun listener is down")
	}
	return cfg, nil
}

const maxErrorChars = 200

var quotedText = regexp.MustCompile(`'[^']*'|"[^"]*"`)

func sanitizeConfigError(err error) string {
	msg := err.Error()
	// mihomo error for a missing geo database when geox-url is empty.
	if strings.Contains(msg, "can't download") {
		return "the config uses geo rules, but the geo databases are not downloaded"
	}
	if i := strings.IndexByte(msg, '\n'); i >= 0 {
		msg = msg[:i]
	}
	msg = quotedText.ReplaceAllString(msg, "'<redacted>'")
	if r := []rune(msg); len(r) > maxErrorChars {
		msg = string(r[:maxErrorChars]) + "…"
	}
	return msg
}

func logProxyEgress(cfg *config.Config) {
	proxy, ok := cfg.Proxies["proxy"]
	if !ok {
		return
	}
	if !proxyDialsTCP(proxy) {
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

func proxyDialsTCP(proxy constant.Proxy) bool {
	switch proxy.Type() {
	case constant.WireGuard, constant.Hysteria, constant.Hysteria2, constant.Tuic:
		return false
	default:
		return true
	}
}

func Stop() {
	mu.Lock()
	defer mu.Unlock()
	stopWatchdog()
	running = nil
	executor.Shutdown()
	closeCacheFile()
	// Shutdown leaves LastTunConf set, so a reused fd would get no listener.
	listener.ReCreateTun(LC.Tun{}, nil)
}

func ProxyBytes(name string) (up, down int64) {
	statistic.DefaultManager.Range(func(t statistic.Tracker) bool {
		for _, hop := range t.Info().Chain {
			if hop == name {
				up += t.Info().UploadTotal.Load()
				down += t.Info().DownloadTotal.Load()
				break
			}
		}
		return true
	})
	return up, down
}

func URLTest(name, url string, timeoutMs int) (int, error) {
	proxies := tunnel.Proxies()
	p, ok := proxies[name]
	if !ok {
		return 0, fmt.Errorf("no outbound named %s", name)
	}
	if timeoutMs <= 0 {
		timeoutMs = 5000
	}
	ctx, cancel := context.WithTimeout(context.Background(), time.Duration(timeoutMs)*time.Millisecond)
	defer cancel()
	delay, err := p.URLTest(ctx, url, nil)
	if err != nil {
		return 0, err
	}
	return int(delay), nil
}

func GroupMember(group string) string {
	proxies := tunnel.Proxies()
	p, ok := proxies[group]
	if !ok {
		return ""
	}
	if g, ok := p.Adapter().(interface{ Now() string }); ok {
		return g.Now()
	}
	return ""
}
