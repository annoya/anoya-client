//go:build !darwin

package engine

import "github.com/metacubex/mihomo/config"

func leaveDialsUnbound(*config.Config) {}
