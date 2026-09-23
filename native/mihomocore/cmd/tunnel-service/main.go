// tunnel-service hosts the mihomo engine on Windows and Linux as a service:
// the one process on the machine with the privilege to create the TUN device,
// driven by the unprivileged app over a named pipe (Windows) or a unix socket
// (Linux). Everything it does is in the service package; this file is how the
// operating system starts and stops it.
//
//	tunnel-service                 run as a service (what the SCM / systemd does)
//	tunnel-service -console        run in the foreground, logging to stderr
//	tunnel-service -install        register the service, started at boot
//	tunnel-service -uninstall      stop and remove it
//	tunnel-service -dir <path>     engine directory (default %ProgramData%\AnnoyaTest\engine
//	                               on Windows, /var/lib/annoyatest/engine on Linux)
package main

import (
	"flag"
	"fmt"
	"log"
	"os"
	"runtime/debug"

	"mihomocore/service"
)

// The service's name to the system, and the pipe the app dials. Both are part
// of the contract with the installer and the Dart side; change them together.
const (
	serviceName = "AnnoyaTunnel"
	pipeName    = `\\.\pipe\AnnoyaTest.tunnel`
)

// Who may talk to the pipe: the system itself, administrators, and whoever is
// logged in interactively. Anything that can reach this pipe can point the
// machine's traffic wherever it likes, so "everyone" is not an option — and
// the interactive user is exactly who the app runs as.
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

// newService wires the real engine to the files and points its log at the
// file the app fetches.
func newService(files service.Files) *service.Service {
	if err := service.RedirectEngineLog(files.EngineLog()); err != nil {
		files.Append("engine log redirect failed: " + err.Error())
	}
	return service.New(service.RealEngine{}, files)
}

// recordCrashes points the runtime's fatal output at a file next to the logs.
// As a service the process has no stderr, so a panic used to vanish: the SCM
// noted "terminated unexpectedly" and the traceback went nowhere. Appended, so
// repeated crashes accumulate; the file is small unless something is wrong.
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
