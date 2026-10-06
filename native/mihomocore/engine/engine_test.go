package engine

import (
	"bytes"
	"errors"
	"net/netip"
	"os"
	"strings"
	"testing"
	"time"

	"github.com/metacubex/mihomo/adapter"
	"github.com/metacubex/mihomo/constant"
	"github.com/metacubex/mihomo/hub/executor"
	"github.com/metacubex/mihomo/log"
	"github.com/sirupsen/logrus"
)

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

func TestReloadRejectsBadInputBeforeTouchingTheEngine(t *testing.T) {
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

type closeRecorder struct {
	constant.ProxyAdapter
	closed bool
}

func (c *closeRecorder) Close() error {
	c.closed = true
	return nil
}

func TestReloadClosesTheOutboundsItReplaced(t *testing.T) {
	kept, replaced, dropped, successor := &closeRecorder{}, &closeRecorder{}, &closeRecorder{}, &closeRecorder{}
	keptProxy := adapter.NewProxy(kept)
	previous := map[string]constant.Proxy{
		"DIRECT": keptProxy,
		"proxy":  adapter.NewProxy(replaced),
		"p1":     adapter.NewProxy(dropped),
	}
	current := map[string]constant.Proxy{
		"DIRECT": keptProxy,
		"proxy":  adapter.NewProxy(successor),
	}

	closeReplacedProxies(previous, current)

	if !replaced.closed || !dropped.closed {
		t.Fatal("an outbound the new config replaced or dropped must be closed, " +
			"or a WireGuard device keeps handshaking next to its successor")
	}
	if kept.closed || successor.closed {
		t.Fatal("an outbound still in use must stay open")
	}
}

func TestMissingGeoDatabaseFailsFastInsteadOfDownloading(t *testing.T) {
	constant.SetHomeDir(t.TempDir())

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
	if elapsed > time.Second {
		t.Fatalf("parsing took %v — the engine attempted a download", elapsed)
	}
}

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

func TestInlineRuleListsParseAndMatchWithoutFetching(t *testing.T) {
	constant.SetHomeDir(t.TempDir())

	const cfg = "log-level: silent\n" +
		"rule-providers:\n" +
		"  _inline_0:\n" +
		"    type: inline\n" +
		"    behavior: domain\n" +
		"    payload:\n" +
		"      - \"+.youtube.com\"\n" +
		"      - \"exact.example\"\n" +
		"  _inline_1:\n" +
		"    type: inline\n" +
		"    behavior: ipcidr\n" +
		"    payload:\n" +
		"      - \"142.250.0.0/15\"\n" +
		"      - \"2001:4860::/32\"\n" +
		"rules:\n" +
		"  - RULE-SET,_inline_0,DIRECT\n" +
		"  - RULE-SET,_inline_1,DIRECT,no-resolve\n" +
		"  - MATCH,DIRECT\n"

	parsed, err := executor.ParseWithBytes([]byte(cfg))
	if err != nil {
		t.Fatalf("inline lists must parse: %v", err)
	}
	if got := parsed.Rules[0].Payload(); got != "_inline_0" {
		t.Fatalf("first rule should point at the inline list, got %q", got)
	}
	domains := parsed.RuleProviders["_inline_0"]
	cidrs := parsed.RuleProviders["_inline_1"]
	if domains == nil || cidrs == nil {
		t.Fatal("both inline lists must be registered")
	}
	if domains.Count() != 2 || cidrs.Count() != 2 {
		t.Fatalf("payload counts: %d domains, %d subnets", domains.Count(), cidrs.Count())
	}

	host := func(h string) *constant.Metadata { return &constant.Metadata{Host: h} }
	for _, h := range []string{"youtube.com", "www.youtube.com", "exact.example"} {
		if !domains.Match(host(h), constant.RuleMatchHelper{}) {
			t.Errorf("%s should match", h)
		}
	}
	for _, h := range []string{"notyoutube.com", "sub.exact.example"} {
		if domains.Match(host(h), constant.RuleMatchHelper{}) {
			t.Errorf("%s should not match", h)
		}
	}
	ip := &constant.Metadata{DstIP: netip.MustParseAddr("142.251.1.1")}
	if !cidrs.Match(ip, constant.RuleMatchHelper{}) {
		t.Error("an address inside the subnet should match")
	}
}
