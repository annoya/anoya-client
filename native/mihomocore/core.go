// Package main builds a C archive that wraps the mihomo engine for use inside
// the macOS Network Extension. It exposes a tiny C API:
//
//	MihomoVersion() -> version string
//	MihomoStart(fd, configJSON) -> "" on success or an error message
//	MihomoStop()
//
// The extension passes the utun file descriptor (from NEPacketTunnelFlow) and a
// mihomo config (with a TUN inbound bound to that fd). This file is the C
// surface; the actual engine wiring lives in engine.go behind startEngine /
// stopEngine so this surface stays stable while the engine is filled in.
package main

/*
#include <stdlib.h>
*/
import "C"

import (
	"sync"
	"unsafe"
)

var mu sync.Mutex

func main() {} // required for c-archive

//export MihomoVersion
func MihomoVersion() *C.char {
	return C.CString(engineVersion())
}

// MihomoSetHomeDir points the engine at its working directory — where it looks
// for the GeoIP/GeoSite databases (geoip.metadb, GeoSite.dat). Call before
// MihomoStart. The host app downloads the databases into the same directory.
//
//export MihomoSetHomeDir
func MihomoSetHomeDir(path *C.char) {
	mu.Lock()
	defer mu.Unlock()
	setEngineHomeDir(C.GoString(path))
}

// MihomoSetLogLevel applies a mihomo log level ("silent", "error", "warning",
// "info", "debug") to the running engine. Used by the app's "Collect logs"
// switch, which must take effect without reconnecting.
//
//export MihomoSetLogLevel
func MihomoSetLogLevel(level *C.char) {
	mu.Lock()
	defer mu.Unlock()
	setEngineLogLevel(C.GoString(level))
}

//export MihomoStart
func MihomoStart(fd C.int, configJSON *C.char) *C.char {
	mu.Lock()
	defer mu.Unlock()
	if err := startEngine(int(fd), C.GoString(configJSON)); err != nil {
		return C.CString(err.Error())
	}
	return C.CString("")
}

//export MihomoStop
func MihomoStop() {
	mu.Lock()
	defer mu.Unlock()
	stopEngine()
}

// FreeCString lets the caller release strings returned by this library.
//
//export FreeCString
func FreeCString(s *C.char) {
	C.free(unsafe.Pointer(s))
}
