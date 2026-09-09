module libagw

go 1.24

// The upstream repository is github.com/amnezia-vpn/libagw, and since v1.0.1 its
// go.mod says so too. The submodule in ./upstream pins the commit we build —
// 2f0215b, the C ABI that reports transport outcomes only and survives a
// misused handle — and this replace points the module path at it: their code
// stays theirs, at a commit we can name.
require github.com/amnezia-vpn/libagw v0.0.0

replace github.com/amnezia-vpn/libagw => ./upstream
