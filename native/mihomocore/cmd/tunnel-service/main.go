package main

import (
	"flag"
	"fmt"
	"log"
	"os"
	"runtime/debug"

	"mihomocore/service"
)

// Shared with the installer and the Dart side; change them together.
const (
	serviceName = "AnoyaTunnel"
	pipeName    = `\\.\pipe\Anoya.tunnel`
)

// SYSTEM, admins and the interactive user only: whoever reaches the pipe can
// reroute the machine's traffic.
const pipeSDDL = "D:P(A;;GA;;;SY)(A;;GA;;;BA)(A;;GRGW;;;IU)"

func main() {
	console := flag.Bool("console", false, "run in the foreground")
	install := flag.Bool("install", false, "register the system service")
	uninstall := flag.Bool("uninstall", false, "remove the system service")
	dir := flag.String("dir", defaultDir(), "engine directory")
	flag.Parse()

	files := service.Files{Dir: *dir}
	if err := files.Ensure(); err != nil {
		log.Fatalf("engine dir: %v", err)
	}
	recordCrashes(files)

	switch {
	case *install:
		exitOn(installService())
	case *uninstall:
		exitOn(uninstallService())
	case *console:
		exitOn(runConsole(files))
	default:
		exitOn(runService(files))
	}
}

func exitOn(err error) {
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}

func newService(files service.Files) *service.Service {
	if err := service.RedirectEngineLog(files.EngineLog()); err != nil {
		files.Append("engine log redirect failed: " + err.Error())
	}
	return service.New(service.RealEngine{}, files)
}

func recordCrashes(files service.Files) {
	fh, err := os.OpenFile(files.CrashLog(), os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0o644)
	if err != nil {
		files.Append("crash log unavailable: " + err.Error())
		return
	}
	if err := debug.SetCrashOutput(fh, debug.CrashOptions{}); err != nil {
		files.Append("crash log unavailable: " + err.Error())
	}
}
