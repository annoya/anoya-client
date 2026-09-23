//go:build !windows && !linux

// The macOS build exists so the service can be exercised without a Windows or
// Linux machine: `-console` listens on a unix socket instead of a named pipe
// and drives the same engine. Starting a tunnel still needs root (the engine
// creates a utun), but the wire and the state machine do not.

package main

import (
	"errors"
	"fmt"
	"net"
	"os"
	"os/signal"
	"path/filepath"

	"mihomocore/service"
)

func defaultDir() string {
	return filepath.Join(os.TempDir(), "annoya-tunnel")
}

// socketPath is the unix-socket stand-in for the named pipe.
func socketPath(files service.Files) string { return filepath.Join(files.Dir, "tunnel.sock") }

func runService(service.Files) error {
	return errors.New("a Windows or Linux service only; use -console")
}

func runConsole(files service.Files) error {
	path := socketPath(files)
	_ = os.Remove(path)
	ln, err := net.Listen("unix", path)
	if err != nil {
		return err
	}
	s := newService(files)
	fmt.Fprintf(os.Stderr, "listening on %s, engine dir %s\n", path, files.Dir)
	stop := make(chan os.Signal, 1)
	signal.Notify(stop, os.Interrupt)
	go func() {
		<-stop
		_ = ln.Close()
		s.Shutdown()
	}()
	return s.Serve(ln)
}

func installService() error   { return errors.New("a Windows or Linux service only") }
func uninstallService() error { return errors.New("a Windows or Linux service only") }
