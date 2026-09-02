package engine

// Real mihomo engine wiring, shared by every platform shim: the host passes a
// tun file descriptor and a mihomo YAML config (with a TUN inbound); we parse
// the config, bind the TUN to the provided fd, and apply it. Apple reaches
// this through the C surface in ../core.go, Android through the gomobile
// bindings in ../mobile.

import (
	"context"
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

// SetHomeDir sets mihomo's working directory (GeoIP/GeoSite database
// location) and the process-wide policy the engine runs under. Must be called
// before Start.
func SetHomeDir(path string) {
	mu.Lock()
	defer mu.Unlock()
	if path != "" {
		constant.SetHomeDir(path)
	}
	configureEngineGlobals()
}

var engineGlobalsOnce sync.Once

// configureEngineGlobals pins the one engine-wide behaviour that cannot be
// expressed in the config file. (Blocking the engine's own geo downloads is
// the other thing we need, and that one IS config — `geox-url`, emitted by the
// renderer; setting the geodata URLs here would not survive, because parsing a
// config re-applies them from its own `geox-url`.)
func configureEngineGlobals() {
	engineGlobalsOnce.Do(func() {
		// The engine's IPv6 support must not depend on the physical network.
		//
		// config.parseIPV6 probes the host's interfaces and, finding no global
		// v6 address, strips tun.inet6-address and dns.fake-ip-range6 from the
		// parsed config. That makes the rendered `tun` section a function of
		// the current network: connect on v4-only Wi-Fi, switch on cellular,
		// and Tun.Equal fails — mihomo re-creates the TUN listener, closing the
		// Network Extension's fd with it. The probe asks "does the host have
		// IPv6?", which is the wrong question for a VPN that supplies IPv6
		// itself, over its own interface.
		os.Setenv("SKIP_SYSTEM_IPV6_CHECK", "1")
	})
}

// SetLogLevel changes the engine's log level on a running tunnel. The
// level in the config is only read when the config is applied, so without this
// turning logging off would not take effect until the next connect — while the
// engine kept writing to its log file the whole time.
func SetLogLevel(level string) {
	mu.Lock()
	defer mu.Unlock()
	if l, ok := log.LogLevelMapping[strings.ToLower(level)]; ok {
		log.SetLevel(l)
	}
}

// mu serialises the calls that change the engine's state — start, reload,
// stop, home dir, log level — for every host: the C archive on Apple and the
// gomobile binding on Android. It lives here rather than in either shim so the
// two cannot drift; the Android side used to rely on its caller's executor
// alone. Probes (URLTest, ProxyBytes, GroupMember) do not take it: they can
// block for as long as a dead server keeps them waiting, and a probe must not
// stop the user from disconnecting.
var mu sync.Mutex

func Start(fd int, configYAML string) error {
	mu.Lock()
	defer mu.Unlock()
	_, err := applyConfig(fd, configYAML)
	return err
}

// Reload applies a new config to the running engine, keeping the same
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
func Reload(fd int, configYAML string) error {
	mu.Lock()
	defer mu.Unlock()
	cfg, err := applyConfig(fd, configYAML)
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

func applyConfig(fd int, configYAML string) (*config.Config, error) {
	// Idempotent, and here rather than only in SetHomeDir: invariant 3 (both
	// address families carried) hangs on the IPv6 check being disabled, and a
	// host that forgot to set the home dir first must not get a different
	// engine.
	configureEngineGlobals()
	if fd <= 0 {
		return nil, fmt.Errorf("invalid tun fd %d", fd)
	}
	if configYAML == "" {
		return nil, fmt.Errorf("empty config")
	}
	cfg, err := executor.ParseWithBytes([]byte(configYAML))
	if err != nil {
		return nil, fmt.Errorf("parse config: %s", sanitizeConfigError(err))
	}
	// Bind the TUN inbound to the fd provided by the Network Extension instead
	// of letting mihomo create its own interface.
	cfg.General.Tun.Enable = true
	cfg.General.Tun.FileDescriptor = fd
	executor.ApplyConfig(cfg, true)
	// ApplyConfig returns nothing and logs every apply-stage failure instead of
	// reporting it, so "the config was rejected" only ever meant "it did not
	// parse". The one failure that matters here is the TUN listener: mihomo
	// closes the old one before creating the new, and the old one owns OUR fd
	// (sing-tun wraps it directly, no dup) — so a failed re-creation leaves a
	// dead tunnel while proxies/DNS have already been swapped. On that path
	// mihomo forces Enable=false in the stored conf, which is what we check.
	if !listener.GetTunConf().Enable {
		return nil, fmt.Errorf("engine applied the config but the tun listener is down")
	}
	return cfg, nil
}

// Longest sanitized error we hand back. The message travels to a dialog and a
// log line, and mihomo's parse errors can run to whole embedded documents; a
// sentence is what a user can act on.
const maxErrorChars = 200

// quotedText matches what mihomo's decoder puts around the offending value
// ("cannot parse 'x' as int", yaml.v3 type errors) — the part that can be a
// uuid or a password.
var quotedText = regexp.MustCompile(`'[^']*'|"[^"]*"`)

// sanitizeConfigError strips the config text out of a parse error: this error
// crosses into the extension log, which the user exports (AGENTS invariant 6).
// A missing geo database is translated, because "unsupported protocol scheme"
// — what emptying the download URLs produces — explains nothing.
func sanitizeConfigError(err error) string {
	msg := err.Error()
	if strings.Contains(msg, "can't download") {
		return "the config uses geo rules, but the geo databases are not downloaded"
	}
	if i := strings.IndexByte(msg, '\n'); i >= 0 {
		msg = msg[:i]
	}
	msg = quotedText.ReplaceAllString(msg, "'<redacted>'")
	// Cut in runes: a yaml error quotes the document, and slicing bytes could
	// split a multibyte character and hand the app an invalid string.
	if r := []rune(msg); len(r) > maxErrorChars {
		msg = string(r[:maxErrorChars]) + "…"
	}
	return msg
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
	// Only meaningful for a proxy that speaks TCP. A WireGuard peer listens on
	// UDP, so this dial is refused by design — and reporting that as
	// "unreachable" sent a reader looking for a network fault that was not
	// there, which is worse than saying nothing.
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

// proxyDialsTCP reports whether reaching this proxy means a TCP connection.
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
	executor.Shutdown()
	// Shutdown closes the TUN listener but leaves LastTunConf populated, and
	// re-creation is skipped whenever the new conf compares equal — our tun
	// section is byte-identical by design and a fresh utun often gets the same
	// fd number, so a start after a stop in the same process would take the
	// "equal" branch and create no listener at all: a tunnel that looks up and
	// carries nothing. Zeroing the remembered conf forces the next start to
	// build a real listener.
	listener.ReCreateTun(LC.Tun{}, nil)
}

// GroupMember returns the member a proxy group is currently sending
// traffic through, or "" when there is no such group.
//
// Read in process, deliberately: mihomo also exposes this over its HTTP API,
// but `external-controller` opens an unauthenticated control surface inside the
// extension's container, which AGENTS forbids. A group's pick is one map lookup
// away, so there is nothing to justify the API.
//
// The name returned is the engine-side one (`p0`, `p1`, …) that the renderer
// generated; the app maps it back to the label the provider gave. Provider text
// never has to cross this boundary.
// ProxyBytes reports how much has been carried through the named outbound in
// this session, as the engine's own connection tracking sees it.
//
// The passive half of the connection check: bytes that came *back* through the
// server are proof the tunnel works, paid for by traffic the user was making
// anyway. No probe, nothing sent to a third party, no waiting.
//
// Counted per connection chain rather than from the tunnel's totals on
// purpose. `statistic.Manager.Total()` includes everything the tunnel handled,
// and in split mode much of that went out DIRECT — a number that grows while
// the proxy is dead. Only live connections are visible here (a tracker leaves
// the manager when its connection closes), so silence means "nothing to look
// at yet", never "nothing works" — which is exactly when the caller falls back
// to asking.
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

// URLTest sends one HTTP HEAD through a running outbound and reports how long
// the answer took, in milliseconds. The result reads "the tunnel carries
// traffic"; anything else is an error naming why it does not.
//
// This is mihomo's own health check (the one url-test groups pick members
// with), and it dials the outbound directly rather than through the rule
// engine — so split tunnelling cannot route the probe away from the server
// under test, and equally a pass says nothing about where the user's own
// traffic goes.
//
// It exists because "connected" is a claim about an interface, not about a
// path: an AmneziaWG peer whose handshake never completes and a VLESS server
// that accepts TCP and says nothing both leave a tunnel that looks perfectly
// up and carries nothing.
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
	// No expected-status range: mihomo treats an empty one as "any 2xx/3xx the
	// server sends", which is the only thing we can judge without asking the
	// user to describe their captive portal.
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
	// Every engine-picking group (url-test, fallback, load-balance, relay)
	// answers Now(); a plain proxy does not, and neither does `select` before
	// anything selected it.
	if g, ok := p.Adapter().(interface{ Now() string }); ok {
		return g.Now()
	}
	return ""
}
