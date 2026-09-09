// Package main builds the Amnezia gateway SDK's C ABI as a linkable library
// for the *app* process — on Apple an xcframework the Runner links, on Android
// a plain .so in jniLibs.
//
// It is deliberately a separate artifact from the mihomo engine rather than
// one merged library. Two Go runtimes cannot share a process, and these two
// belong to different ones anyway: the engine runs in the tunnel (Network
// Extension / :tunnel service), while the gateway is ordinary HTTPS the app
// makes on its own behalf — the same place a subscription is fetched from.
//
// The whole surface comes from the blank import: cabi's //export directives
// are what produce the agw_* symbols. See upstream/cabi/agw.h.
package main

import _ "github.com/amnezia-vpn/libagw/cabi"

func main() {}
