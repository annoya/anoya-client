package service

import (
	"fmt"

	"github.com/metacubex/mihomo/common/yaml"
)

var acceptedKeys = map[string]map[string]bool{
	"log-level":         nil,
	"mode":              nil,
	"profile":           {"store-fake-ip": true},
	"ipv6":              nil,
	"find-process-mode": nil,
	"geox-url":          {"geoip": true, "geosite": true, "mmdb": true, "asn": true},
	"geodata-mode":      nil,
	"geo-auto-update":   nil,
	"dns": {
		"enable":                  true,
		"enhanced-mode":           true,
		"fake-ip-range":           true,
		"fake-ip-range6":          true,
		"default-nameserver":      true,
		"proxy-server-nameserver": true,
		"nameserver":              true,
	},
	"sniffer": {
		"enable":               true,
		"force-dns-mapping":    true,
		"parse-pure-ip":        true,
		"override-destination": true,
		"sniff":                true,
	},
	"tun": {
		"enable":                  true,
		"device":                  true,
		"stack":                   true,
		"disable-icmp-forwarding": true,
		"dns-hijack":              true,
		"inet6-address":           true,
		"auto-route":              true,
		"strict-route":            true,
		"auto-detect-interface":   true,
		"mtu":                     true,
	},
	"proxies":        nil,
	"proxy-groups":   nil,
	"rule-providers": nil,
	"rules":          nil,
}

func checkConfig(config string) error {
	var doc map[string]any
	if err := yaml.Unmarshal([]byte(config), &doc); err != nil {
		return fmt.Errorf("config is not a YAML mapping: %w", err)
	}
	for key, value := range doc {
		if key == "rule-providers" {
			if err := checkRuleProviders(value); err != nil {
				return err
			}
			continue
		}
		sub, ok := acceptedKeys[key]
		if !ok {
			return fmt.Errorf("config key %q is not accepted", key)
		}
		if sub == nil {
			continue
		}
		section, ok := value.(map[string]any)
		if !ok {
			if value == nil {
				continue
			}
			return fmt.Errorf("config key %q must be a mapping", key)
		}
		for k := range section {
			if !sub[k] {
				return fmt.Errorf("config key %q is not accepted", key+"."+k)
			}
		}
	}
	return nil
}

var providerKeys = map[string]bool{"type": true, "path": true, "behavior": true, "format": true}

func checkRuleProviders(value any) error {
	if value == nil {
		return nil
	}
	providers, ok := value.(map[string]any)
	if !ok {
		return fmt.Errorf("config key %q must be a mapping", "rule-providers")
	}
	for name, raw := range providers {
		provider, ok := raw.(map[string]any)
		if !ok {
			return fmt.Errorf("rule provider %q must be a mapping", name)
		}
		for k := range provider {
			if !providerKeys[k] {
				return fmt.Errorf("rule provider %q: key %q is not accepted", name, k)
			}
		}
		if provider["type"] != "file" {
			return fmt.Errorf("rule provider %q: only type file is accepted", name)
		}
	}
	return nil
}
