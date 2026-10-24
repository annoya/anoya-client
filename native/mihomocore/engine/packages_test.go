package engine

import (
	"net"
	"net/netip"
	"testing"

	"github.com/metacubex/mihomo/component/process"
	C "github.com/metacubex/mihomo/constant"
)

func TestTheAppIsAskedAboutTheConnectionAsTheAppSeesIt(t *testing.T) {
	var gotNetwork string
	var gotSrc, gotDst netip.AddrPort
	SetPackageLookup(func(network string, src, dst netip.AddrPort) string {
		gotNetwork, gotSrc, gotDst = network, src, dst
		return "org.telegram.messenger"
	})
	t.Cleanup(func() { SetPackageLookup(nil) })

	m := &C.Metadata{
		NetWork:    C.TCP,
		SrcIP:      netip.MustParseAddr("172.19.0.1"),
		SrcPort:    40000,
		DstIP:      netip.MustParseAddr("149.154.167.51"),
		DstPort:    443,
		RawSrcAddr: &net.TCPAddr{IP: net.ParseIP("172.19.0.1"), Port: 40000},
		RawDstAddr: &net.TCPAddr{IP: net.ParseIP("198.18.0.7"), Port: 443},
	}
	pkg, err := process.FindPackageName(m)
	if err != nil || pkg != "org.telegram.messenger" {
		t.Fatalf("package %q, err %v", pkg, err)
	}
	if gotNetwork != "tcp" || gotSrc.String() != "172.19.0.1:40000" || gotDst.String() != "198.18.0.7:443" {
		t.Fatalf("asked about %s %s → %s, want the raw tcp ends the app opened", gotNetwork, gotSrc, gotDst)
	}
}

func TestWithoutRawAddressesTheMetadataEndsAreUsed(t *testing.T) {
	var gotDst netip.AddrPort
	SetPackageLookup(func(_ string, _, dst netip.AddrPort) string {
		gotDst = dst
		return ""
	})
	t.Cleanup(func() { SetPackageLookup(nil) })

	m := &C.Metadata{
		NetWork: C.UDP,
		SrcIP:   netip.MustParseAddr("172.19.0.1"),
		SrcPort: 5353,
		DstIP:   netip.MustParseAddr("8.8.8.8"),
		DstPort: 53,
	}
	if _, err := process.FindPackageName(m); err == nil {
		t.Fatal("an unknown owner must be an error, not an empty package")
	}
	if gotDst.String() != "8.8.8.8:53" {
		t.Fatalf("asked about %s", gotDst)
	}
}

func TestNoLookupMeansNoPackageResolver(t *testing.T) {
	SetPackageLookup(nil)
	if process.DefaultPackageNameResolver != nil {
		t.Fatal("clearing the lookup must leave mihomo without a resolver")
	}
}
