module libagw

go 1.24

// The upstream repository is github.com/amnezia-vpn/libagw, but its go.mod
// declares the module as amnezia-gateway-sdk — the two disagree, so `go get`
// by the repository path is refused. The submodule in ./upstream pins the
// v1.0.0 tag and this replace points the declared path at it: their code
// stays theirs, at a commit we can name.
require github.com/amnezia-vpn/amnezia-gateway-sdk v0.0.0

replace github.com/amnezia-vpn/amnezia-gateway-sdk => ./upstream
