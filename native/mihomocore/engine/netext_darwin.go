package engine

import "github.com/metacubex/mihomo/config"

func leaveDialsUnbound(cfg *config.Config) {
	cfg.General.Tun.AutoDetectInterface = false
}
