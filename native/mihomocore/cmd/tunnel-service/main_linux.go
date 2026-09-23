//go:build linux

// On Linux the service is a systemd unit running as root — creating the TUN
// device and installing the routes is the privileged act, as on Windows — and
// the app dials a unix socket instead of a named pipe. Same wire, same state
// machine (the service package); this file is only how systemd starts and
// stops it, and how `-install` registers it on a machine without the package
// manager's help.

package main

import (
	"fmt"
	"net"
	"os"
	"os/exec"
	"os/signal"
	"path/filepath"
	"strings"
	"syscall"

	"mihomocore/service"
)

// The unit's name to systemd, and the socket the app dials. Both are part of
// the contract with the packaging (linux/packaging) and the Dart side
// (lib/core/unix_socket_link.dart); change them together.
const (
	unitName   = "annoyatest-tunnel.service"
	unitPath   = "/etc/systemd/system/" + unitName
	socketDir  = "/run/annoyatest"
	socketPath = socketDir + "/tunnel.sock"
)

// The engine's home: the service writes the config and the logs here, the
// app downloads the geo databases into it (`shared_dir`). The Windows
// installer grants Users modify on the same directory; here it is created
// world-writable with the sticky bit, so every local user can add files and
// none can remove another's.
func defaultDir() string { return "/var/lib/annoyatest/engine" }

// listen opens the socket any local user may connect to. Anyone reaching it
// can point the machine's traffic anywhere, which on Windows is why the pipe
// is limited to the interactive user. Linux has no equivalent of "whoever is
// logged in at the console" that a socket mode can express, and a dedicated
// group would mean a re-login after every install for the one person the
// machine belongs to. Mullvad and NetBird ship their daemon sockets
// world-accessible for the same reason; this follows them.
func listen() (net.Listener, error) {
	if err := os.MkdirAll(socketDir, 0o755); err != nil {
		return nil, err
	}
	_ = os.Remove(socketPath)
	ln, err := net.Listen("unix", socketPath)
	if err != nil {
		return nil, err
	}
	if err := os.Chmod(socketPath, 0o666); err != nil {
		_ = ln.Close()
		return nil, err
	}
	return ln, nil
}

// runService is what systemd runs. SIGTERM (systemctl stop, shutdown) takes
// the tunnel down with it: a service that is stopped is not a VPN the user
// can still be relying on.
func runService(files service.Files) error {
	if err := os.Chmod(files.Dir, 0o1777); err != nil {
		files.Append("engine dir permissions: " + err.Error())
	}
	ln, err := listen()
	if err != nil {
		files.Append("socket listen failed: " + err.Error())
		return err
	}
	s := newService(files)
	// A tunnel the user left on comes back with the machine. StartSaved does
	// nothing when no config was saved, and a start that fails is recorded
	// where the app will read it.
	go func() { _ = s.StartSaved() }()

	stop := make(chan os.Signal, 1)
	signal.Notify(stop, syscall.SIGTERM, os.Interrupt)
	go func() {
		<-stop
		_ = ln.Close()
		s.Shutdown()
	}()
	return s.Serve(ln)
}

// runConsole is the same service in the foreground, for development: still
// needs root, because the device does.
func runConsole(files service.Files) error {
	fmt.Fprintf(os.Stderr, "listening on %s, engine dir %s\n", socketPath, files.Dir)
	return runService(files)
}

// The unit `-install` writes. The .deb ships the same text from
// linux/packaging; keep the two in step. Restart=on-failure is the Windows
// recovery action: a crashed service must come back on its own, because the
// app only knocks on the socket and cannot start it.
const unitText = `[Unit]
Description=AnnoyaTest tunnel
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=%s
Restart=on-failure
RestartSec=5
RuntimeDirectory=annoyatest
StateDirectory=annoyatest

[Install]
WantedBy=multi-user.target
`

func installService() error {
	exe, err := os.Executable()
	if err != nil {
		return err
	}
	if exe, err = filepath.EvalSymlinks(exe); err != nil {
		return err
	}
	if _, err := os.Stat(unitPath); err == nil {
		return fmt.Errorf("%s already exists; run -uninstall first", unitName)
	}
	if err := os.WriteFile(unitPath, []byte(fmt.Sprintf(unitText, exe)), 0o644); err != nil {
		return err
	}
	if err := systemctl("daemon-reload"); err != nil {
		return err
	}
	return systemctl("enable", "--now", unitName)
}

func uninstallService() error {
	if _, err := os.Stat(unitPath); err != nil {
		return fmt.Errorf("%s is not installed", unitName)
	}
	// Disable and stop before the file goes, or systemd keeps a unit it can
	// no longer find.
	err := systemctl("disable", "--now", unitName)
	if rmErr := os.Remove(unitPath); rmErr != nil && err == nil {
		err = rmErr
	}
	if reloadErr := systemctl("daemon-reload"); reloadErr != nil && err == nil {
		err = reloadErr
	}
	return err
}

func systemctl(args ...string) error {
	out, err := exec.Command("systemctl", args...).CombinedOutput()
	if err != nil {
		return fmt.Errorf("systemctl %s: %w: %s", strings.Join(args, " "), err, out)
	}
	return nil
}
