//go:build windows

package main

import (
	"errors"
	"fmt"
	"net"
	"os"
	"os/signal"
	"path/filepath"
	"time"

	"github.com/tailscale/go-winio"
	"golang.org/x/sys/windows/svc"
	"golang.org/x/sys/windows/svc/mgr"

	"mihomocore/service"
)

func defaultDir() string {
	base := os.Getenv("ProgramData")
	if base == "" {
		base = `C:\ProgramData`
	}
	return filepath.Join(base, "Anoya", "engine")
}

func listen() (net.Listener, error) {
	return winio.ListenPipe(pipeName, &winio.PipeConfig{SecurityDescriptor: pipeSDDL})
}

func runService(files service.Files) error {
	if inService, err := svc.IsWindowsService(); err != nil {
		return err
	} else if !inService {
		return errors.New("not started by the service manager; use -console to run in the foreground")
	}
	return svc.Run(serviceName, &handler{files: files})
}

type handler struct {
	files service.Files
}

func (h *handler) Execute(_ []string, r <-chan svc.ChangeRequest, changes chan<- svc.Status) (bool, uint32) {
	changes <- svc.Status{State: svc.StartPending}
	ln, err := listen()
	if err != nil {
		h.files.Append("pipe listen failed: " + err.Error())
		return false, 1
	}
	s := newService(h.files)
	go func() { _ = s.Serve(ln) }()
	go func() { _ = s.StartSaved() }()

	const accepted = svc.AcceptStop | svc.AcceptShutdown
	changes <- svc.Status{State: svc.Running, Accepts: accepted}
	for c := range r {
		switch c.Cmd {
		case svc.Interrogate:
			changes <- c.CurrentStatus
		case svc.Stop, svc.Shutdown:
			changes <- svc.Status{State: svc.StopPending}
			_ = ln.Close()
			s.Shutdown()
			return false, 0
		}
	}
	return false, 0
}

func runConsole(files service.Files) error {
	ln, err := listen()
	if err != nil {
		return err
	}
	s := newService(files)
	fmt.Fprintf(os.Stderr, "listening on %s, engine dir %s\n", pipeName, files.Dir)
	stop := make(chan os.Signal, 1)
	signal.Notify(stop, os.Interrupt)
	go func() {
		<-stop
		_ = ln.Close()
		s.Shutdown()
	}()
	return s.Serve(ln)
}

func installService() error {
	exe, err := os.Executable()
	if err != nil {
		return err
	}
	m, err := mgr.Connect()
	if err != nil {
		return err
	}
	defer m.Disconnect()
	if existing, err := m.OpenService(serviceName); err == nil {
		existing.Close()
		return fmt.Errorf("service %s already exists", serviceName)
	}
	s, err := m.CreateService(serviceName, exe, mgr.Config{
		DisplayName:  "Anoya Tunnel",
		Description:  "Hosts the VPN tunnel for Anoya.",
		StartType:    mgr.StartAutomatic,
		ErrorControl: mgr.ErrorNormal,
	})
	if err != nil {
		return err
	}
	defer s.Close()
	restart := mgr.RecoveryAction{Type: mgr.ServiceRestart, Delay: 5 * time.Second}
	if err := s.SetRecoveryActions([]mgr.RecoveryAction{restart, restart, restart}, 24*60*60); err != nil {
		return fmt.Errorf("set recovery actions: %w", err)
	}
	return s.Start()
}

func uninstallService() error {
	m, err := mgr.Connect()
	if err != nil {
		return err
	}
	defer m.Disconnect()
	s, err := m.OpenService(serviceName)
	if err != nil {
		return fmt.Errorf("service %s is not installed", serviceName)
	}
	defer s.Close()
	if st, err := s.Query(); err == nil && st.State != svc.Stopped {
		if _, err := s.Control(svc.Stop); err != nil {
			return err
		}
		// Delete on a running service only marks it for deletion.
		for i := 0; i < 50; i++ {
			if st, err := s.Query(); err != nil || st.State == svc.Stopped {
				break
			}
			time.Sleep(100 * time.Millisecond)
		}
	}
	return s.Delete()
}
