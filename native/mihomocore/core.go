// Package main builds a C archive that wraps the mihomo engine for use inside
// the macOS Network Extension. It exposes a tiny C API:
//
//	MihomoVersion() -> version string
//	MihomoStart(fd, configJSON) -> "" on success or an error message
//	MihomoStop()
//
// The extension passes the utun file descriptor (from NEPacketTunnelFlow) and a
// mihomo config (with a TUN inbound bound to that fd). This file is only the C
// surface; the engine wiring lives in the engine package, shared with the
// Android bindings in ./mobile.
package main

/*
#include <stdlib.h>
*/
import "C"

import (
	"sync"
	"unsafe"

	"mihomocore/engine"
)

var mu sync.Mutex

func main() {} // required for c-archive

//export MihomoVersion
func MihomoVersion() *C.char {
	return C.CString(engine.Version())
}

// MihomoSetHomeDir points the engine at its working directory — where it looks
// for the GeoIP/GeoSite databases (geoip.metadb, GeoSite.dat). Call before
// MihomoStart. The host app downloads the databases into the same directory.
//
//export MihomoSetHomeDir
func MihomoSetHomeDir(path *C.char) {
	mu.Lock()
	defer mu.Unlock()
	engine.SetHomeDir(C.GoString(path))
}

// MihomoSetLogLevel applies a mihomo log level ("silent", "error", "warning",
// "info", "debug") to the running engine. Used by the app's "Collect logs"
// switch, which must take effect without reconnecting.
//
//export MihomoSetLogLevel
func MihomoSetLogLevel(level *C.char) {
	mu.Lock()
	defer mu.Unlock()
	engine.SetLogLevel(C.GoString(level))
}

//export MihomoStart
func MihomoStart(fd C.int, configJSON *C.char) *C.char {
	mu.Lock()
	defer mu.Unlock()
	if err := engine.Start(int(fd), C.GoString(configJSON)); err != nil {
		return C.CString(err.Error())
	}
	return C.CString("")
}

// MihomoReload swaps the running engine onto a new config without touching the
// tunnel fd — the switch happens under a live NE session, so the connection
// never drops. Returns "" on success or an error message (in which case the
// engine keeps running on the previous config).
//
//export MihomoReload
func MihomoReload(fd C.int, configJSON *C.char) *C.char {
	mu.Lock()
	defer mu.Unlock()
	if err := engine.Reload(int(fd), C.GoString(configJSON)); err != nil {
		return C.CString(err.Error())
	}
	return C.CString("")
}

//export MihomoStop
func MihomoStop() {
	mu.Lock()
	defer mu.Unlock()
	engine.Stop()
}

// FreeCString lets the caller release strings returned by this library.
//
//export FreeCString
func FreeCString(s *C.char) {
	C.free(unsafe.Pointer(s))
}

// MihomoGroupMember returns which member of a proxy group the engine is
// currently using ("" when the running config has no such group). The app polls
// it to show what "auto" resolved to, since a group's name alone tells the user
// nothing about where their traffic goes.
//
//export MihomoGroupMember
func MihomoGroupMember(group *C.char) *C.char {
	mu.Lock()
	defer mu.Unlock()
	return C.CString(engine.GroupMember(C.GoString(group)))
}
