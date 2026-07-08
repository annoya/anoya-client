package main

// Real mihomo engine wiring. The Network Extension passes the utun file
// descriptor and a mihomo YAML config (with a TUN inbound). We parse the
// config, bind the TUN to the provided fd, and apply it. The C surface in
// core.go is unchanged.

import (
	"fmt"

	"github.com/metacubex/mihomo/constant"
	"github.com/metacubex/mihomo/hub/executor"
)

func engineVersion() string {
	return "mihomo " + constant.Version
}

func startEngine(fd int, configYAML string) error {
	if fd <= 0 {
		return fmt.Errorf("invalid tun fd %d", fd)
	}
	if configYAML == "" {
		return fmt.Errorf("empty config")
	}
	cfg, err := executor.ParseWithBytes([]byte(configYAML))
	if err != nil {
		return fmt.Errorf("parse config: %w", err)
	}
	// Bind the TUN inbound to the fd provided by the Network Extension instead
	// of letting mihomo create its own interface.
	cfg.General.Tun.Enable = true
	cfg.General.Tun.FileDescriptor = fd
	executor.ApplyConfig(cfg, true)
	return nil
}

func stopEngine() {
	executor.Shutdown()
}
