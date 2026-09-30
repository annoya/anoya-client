package main

/*
#include <stdlib.h>
*/
import "C"

import (
	"fmt"
	"unsafe"

	"mihomocore/engine"
)

func main() {} // required for c-archive

//export MihomoVersion
func MihomoVersion() *C.char {
	return C.CString(engine.Version())
}

//export MihomoSetHomeDir
func MihomoSetHomeDir(path *C.char) {
	engine.SetHomeDir(C.GoString(path))
}

//export MihomoSetLogLevel
func MihomoSetLogLevel(level *C.char) {
	engine.SetLogLevel(C.GoString(level))
}

//export MihomoStart
func MihomoStart(fd C.int, configJSON *C.char) *C.char {
	if err := engine.Start(int(fd), C.GoString(configJSON)); err != nil {
		return C.CString(err.Error())
	}
	return C.CString("")
}

//export MihomoReload
func MihomoReload(fd C.int, configJSON *C.char) *C.char {
	if err := engine.Reload(int(fd), C.GoString(configJSON)); err != nil {
		return C.CString(err.Error())
	}
	return C.CString("")
}

//export MihomoRecover
func MihomoRecover(reason *C.char) *C.char {
	if err := engine.Recover(C.GoString(reason)); err != nil {
		return C.CString(err.Error())
	}
	return C.CString("")
}

//export MihomoStop
func MihomoStop() {
	engine.Stop()
}

//export FreeCString
func FreeCString(s *C.char) {
	C.free(unsafe.Pointer(s))
}

//export MihomoProxyBytes
func MihomoProxyBytes(name *C.char) *C.char {
	up, down := engine.ProxyBytes(C.GoString(name))
	return C.CString(fmt.Sprintf("%d:%d", up, down))
}

//export MihomoURLTest
func MihomoURLTest(name *C.char, url *C.char, timeoutMs C.int) *C.char {
	delay, err := engine.URLTest(C.GoString(name), C.GoString(url), int(timeoutMs))
	if err != nil {
		return C.CString("err:" + err.Error())
	}
	return C.CString(fmt.Sprintf("ms:%d", delay))
}

//export MihomoGroupMember
func MihomoGroupMember(group *C.char) *C.char {
	return C.CString(engine.GroupMember(C.GoString(group)))
}
