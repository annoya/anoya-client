module libagw

go 1.24

// The upstream repository is github.com/amnezia-vpn/libagw, and since v1.0.1 its
// go.mod says so too. The submodule in ./upstream pins the commit we build —
// v1.0.4, which also fails over to the proxies on a TLS error and keeps a
// working proxy it learned — and this replace points the module path at it:
// their code stays theirs, at a commit we can name.
require github.com/amnezia-vpn/libagw v0.0.0

replace github.com/amnezia-vpn/libagw => ./upstream
