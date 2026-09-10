package engine

import (
	"bytes"
	"errors"
	"os"
	"strings"
	"testing"
	"time"

	"github.com/metacubex/mihomo/constant"
	"github.com/metacubex/mihomo/hub/executor"
	"github.com/metacubex/mihomo/log"
	"github.com/sirupsen/logrus"
)

// The engine logs while it *parses* a config (geo rule loading, "initial
// configuration in progress") — before ApplyConfig gets to read log-level out of
// the YAML. So the level has to be settable up front; this pins that
// SetLogLevel does exactly that.
func TestSetEngineLogLevelSilencesTheEngine(t *testing.T) {
	var out bytes.Buffer
	logrus.SetOutput(&out)
	t.Cleanup(func() { logrus.SetOutput(os.Stderr) })

	SetLogLevel("info")
	log.Infoln("while collecting")
	if !bytes.Contains(out.Bytes(), []byte("while collecting")) {
		t.Fatalf("expected the line to be written at info level, got %q", out.String())
	}

	out.Reset()
	SetLogLevel("silent")
	log.Infoln("after the switch")
	log.Warnln("and a warning")
	if out.Len() != 0 {
		t.Fatalf("expected silence, got %q", out.String())
	}

	// An unknown level must not silently disable logging.
	SetLogLevel("nonsense")
	log.Infoln("still silent")
	if out.Len() != 0 {
		t.Fatalf("an unknown level must leave the current one alone, got %q", out.String())
	}
	SetLogLevel("info")
	log.Infoln("back on")
	if !bytes.Contains(out.Bytes(), []byte("back on")) {
		t.Fatalf("expected logging to resume, got %q", out.String())
	}
}

// A hot reload must never be able to take the running tunnel down: a config
// that does not parse has to be rejected *before* anything is applied, leaving
// the engine on the previous config. (Parse happens in full before ApplyConfig
// in Start/Reload, so a returned error means the engine was never
// touched.)
func TestReloadRejectsBadInputBeforeTouchingTheEngine(t *testing.T) {
	// "{" is not parseable YAML; anything parseable would reach ApplyConfig,
	// which starts real listeners — exactly what this test must not do.
	if err := Reload(5, "{"); err == nil {
		t.Fatal("a config that does not parse must be rejected")
	}
	if err := Reload(5, ""); err == nil {
		t.Fatal("an empty config must be rejected")
	}
	if err := Reload(0, "log-level: info"); err == nil {
		t.Fatal("a missing fd must be rejected")
	}
}

// Geo rules are the one thing mihomo will go to the network for while merely
// PARSING a config: a missing or unverifiable database is downloaded on the
// spot, with a 90-second timeout per file, inside the engine lock. The client
// renders empty `geox-url` entries to forbid that, and this pins the property
// against the real engine — a config that needs a database we do not have must
// be rejected immediately, without a request.
func TestMissingGeoDatabaseFailsFastInsteadOfDownloading(t *testing.T) {
	constant.SetHomeDir(t.TempDir()) // empty: no databases at all

	// DIRECT, not PROXY: this config has no proxies, and an unknown outbound
	// would fail the rule before geo loading is ever reached.
	const cfg = "log-level: silent\n" +
		"geox-url:\n  geoip: ''\n  geosite: ''\n  mmdb: ''\n  asn: ''\n" +
		"rules:\n  - GEOSITE,youtube,DIRECT\n"

	start := time.Now()
	err := Reload(5, cfg)
	elapsed := time.Since(start)

	if err == nil {
		t.Fatal("a config needing an absent GeoSite.dat must be rejected")
	}
	if !strings.Contains(err.Error(), "not downloaded") {
		t.Fatalf("the error must name the cause, got: %v", err)
	}
	// A real download attempt cannot finish this fast; anything slower means
	// the engine went to the network after all.
	if elapsed > time.Second {
		t.Fatalf("parsing took %v — the engine attempted a download", elapsed)
	}
}

// Parse errors cross into the extension log, which the user exports from the
// app. mihomo's decoder quotes the offending config value, and config bodies
// carry uuids and passwords.
func TestParseErrorsCarryNoConfigText(t *testing.T) {
	err := Reload(5, "log-level: info\nport: 'a-secret-looking-value'\n")
	if err == nil {
		t.Skip("engine accepted the config; nothing to sanitize")
	}
	if strings.Contains(err.Error(), "a-secret-looking-value") {
		t.Fatalf("config text leaked into the error: %v", err)
	}
}

func TestSanitizeConfigErrorRedactsQuotedValues(t *testing.T) {
	in := errors.New("cannot parse 'super-secret-uuid' as int: bad\nsecond line")
	got := sanitizeConfigError(in)
	if strings.Contains(got, "super-secret-uuid") {
		t.Fatalf("quoted value survived: %q", got)
	}
	if strings.Contains(got, "second line") {
		t.Fatalf("only the first line should be kept: %q", got)
	}
}

// The egress probe and the PROXY group both look the outbound up by the name
// "proxy", which the Dart renderer assigns. Renaming it on either side would
// not fail anything — the probe would just quietly stop running, taking with it
// the only signal that distinguishes "server is down" from "the dial never
// reached the physical interface".
func TestEgressProbeLooksUpTheAgreedOutboundName(t *testing.T) {
	if !strings.Contains(engineSource(t), `cfg.Proxies["proxy"]`) {
		t.Fatal("the probe no longer looks up the outbound named \"proxy\"; " +
			"if that is intended, update lib/core/mihomo_tun_config.dart too")
	}
}

func engineSource(t *testing.T) string {
	t.Helper()
	b, err := os.ReadFile("engine.go")
	if err != nil {
		t.Fatal(err)
	}
	return string(b)
}

// mihomo's config.parseIPV6 probes the host's interfaces and, finding no
// global IPv6 address, strips tun.inet6-address from the parsed config. That
// would make the `tun` section a function of the current network: connect on
// v4-only Wi-Fi, move to cellular, and Tun.Equal fails on the next hot reload —
// mihomo re-creates the TUN listener, closing the Network Extension's fd with
// it. The probe asks whether the HOST has IPv6, which is the wrong question for
// a VPN that supplies IPv6 over its own interface, so the engine wrapper turns
// it off.
//
// The first assertion is the load-bearing one: it fails on any machine if the
// knob is ever dropped. The parse below checks the consequence, and can only
// fail on a host without IPv6 — which is precisely the host where the bug
// bites, and never the developer machine that introduces it.
func TestTunSectionDoesNotDependOnHostIPv6(t *testing.T) {
	configureEngineGlobals()
	if os.Getenv("SKIP_SYSTEM_IPV6_CHECK") != "1" {
		t.Fatal("the host-IPv6 probe must be disabled before any config is parsed")
	}

	const cfg = "log-level: silent\nipv6: true\n" +
		"geox-url:\n  geoip: ''\n  geosite: ''\n  mmdb: ''\n  asn: ''\n" +
		"dns:\n  enable: true\n  enhanced-mode: fake-ip\n" +
		"  fake-ip-range: 198.18.0.1/16\n  fake-ip-range6: fc00::/18\n" +
		"tun:\n  enable: true\n  stack: gvisor\n  inet6-address:\n    - fdfe:dcba:9876::1/126\n"

	parsed, err := executor.ParseWithBytes([]byte(cfg))
	if err != nil {
		t.Fatalf("config must parse: %v", err)
	}
	if len(parsed.General.Tun.Inet6Address) == 0 {
		t.Fatal("tun.inet6-address was stripped — the tun section now varies with the network")
	}
	if !parsed.DNS.FakeIPRange6.IsValid() {
		t.Fatal("dns.fake-ip-range6 was stripped — AAAA answers would be refused")
	}
}
