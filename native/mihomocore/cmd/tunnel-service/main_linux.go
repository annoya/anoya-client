//go:build linux

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

// Shared with linux/packaging and lib/core/unix_socket_link.dart; change them
// together.
const (
	unitName   = "annoyatest-tunnel.service"
	unitPath   = "/etc/systemd/system/" + unitName
	socketDir  = "/run/annoyatest"
	socketPath = socketDir + "/tunnel.sock"
)

func defaultDir() string { return "/var/lib/annoyatest/engine" }

func listen() (net.Listener, error) {
	if err := os.MkdirAll(socketDir, 0o755); err != nil {
		return nil, err
	}
	_ = os.Remove(socketPath)
	ln, err := net.Listen("unix", socketPath)
	if err != nil {
		return nil, err
	}
	// World-accessible on purpose: no socket mode expresses "the console user",
	// and a dedicated group would need a re-login after install.
	if err := os.Chmod(socketPath, 0o666); err != nil {
		_ = ln.Close()
		return nil, err
	}
	return ln, nil
}

func runService(files service.Files) error {
	// The app writes the geo databases here; the sticky bit stops users removing
	// each other's files.
	if err := os.Chmod(files.Dir, 0o1777); err != nil {
		files.Append("engine dir permissions: " + err.Error())
	}
	ln, err := listen()
	if err != nil {
		files.Append("socket listen failed: " + err.Error())
		return err
	}
	s := newService(files)
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

func runConsole(files service.Files) error {
	fmt.Fprintf(os.Stderr, "listening on %s, engine dir %s\n", socketPath, files.Dir)
	return runService(files)
}

// The .deb ships the same unit from linux/packaging; keep the two in step.
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
	// Disable before removing the file, or systemd keeps a unit it cannot find.
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
