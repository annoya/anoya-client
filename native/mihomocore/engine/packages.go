package engine

import (
	"errors"
	"net"
	"net/netip"

	"github.com/metacubex/mihomo/component/process"
	C "github.com/metacubex/mihomo/constant"
)

type PackageLookup func(network string, src, dst netip.AddrPort) string

var errNoOwner = errors.New("no app owns this connection")

func SetPackageLookup(lookup PackageLookup) {
	if lookup == nil {
		process.DefaultPackageNameResolver = nil
		return
	}
	process.DefaultPackageNameResolver = func(m *C.Metadata) (string, error) {
		src := addrPortOf(m.RawSrcAddr, m.SrcIP, m.SrcPort)
		dst := addrPortOf(m.RawDstAddr, m.DstIP, m.DstPort)
		if !src.IsValid() || !dst.IsValid() {
			return "", errNoOwner
		}
		if pkg := lookup(m.NetWork.String(), src, dst); pkg != "" {
			return pkg, nil
		}
		return "", errNoOwner
	}
}

func addrPortOf(raw net.Addr, ip netip.Addr, port uint16) netip.AddrPort {
	var ap netip.AddrPort
	switch a := raw.(type) {
	case *net.TCPAddr:
		ap = a.AddrPort()
	case *net.UDPAddr:
		ap = a.AddrPort()
	default:
		ap = netip.AddrPortFrom(ip, port)
	}
	return netip.AddrPortFrom(ap.Addr().Unmap(), ap.Port())
}
