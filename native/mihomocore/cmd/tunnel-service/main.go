// tunnel-service hosts the mihomo engine on Windows as a service: the one
// process on the machine with the privilege to create the TUN adapter, driven
// by the unprivileged app over a named pipe. Everything it does is in the
// service package; this file is how the operating system starts and stops it.
//
//	tunnel-service                 run as a Windows service (what the SCM does)
//	tunnel-service -console        run in the foreground, logging to stderr
//	tunnel-service -install        register the service, start type automatic
//	tunnel-service -uninstall      stop and remove it
//	tunnel-service -dir <path>     engine directory (default %ProgramData%\AnnoyaTest\engine)
package main

import (
	"flag"
	"fmt"
	"log"
	"os"

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
	install := flag.Bool("install", false, "register the Windows service")
	uninstall := flag.Bool("uninstall", false, "remove the Windows service")
	dir := flag.String("dir", defaultDir(), "engine directory")
	flag.Parse()

	files := service.Files{Dir: *dir}
	if err := files.Ensure(); err != nil {
		log.Fatalf("engine dir: %v", err)
	}

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
