package main

import (
	"bytes"
	"os"
	"testing"

	"github.com/metacubex/mihomo/log"
	"github.com/sirupsen/logrus"
)

// The engine logs while it *parses* a config (geo rule loading, "initial
// configuration in progress") — before ApplyConfig gets to read log-level out of
// the YAML. So the level has to be settable up front; this pins that
// setEngineLogLevel does exactly that.
func TestSetEngineLogLevelSilencesTheEngine(t *testing.T) {
	var out bytes.Buffer
	logrus.SetOutput(&out)
	t.Cleanup(func() { logrus.SetOutput(os.Stderr) })

	setEngineLogLevel("info")
	log.Infoln("while collecting")
	if !bytes.Contains(out.Bytes(), []byte("while collecting")) {
		t.Fatalf("expected the line to be written at info level, got %q", out.String())
	}

	out.Reset()
	setEngineLogLevel("silent")
	log.Infoln("after the switch")
	log.Warnln("and a warning")
	if out.Len() != 0 {
		t.Fatalf("expected silence, got %q", out.String())
	}

	// An unknown level must not silently disable logging.
	setEngineLogLevel("nonsense")
	log.Infoln("still silent")
	if out.Len() != 0 {
		t.Fatalf("an unknown level must leave the current one alone, got %q", out.String())
	}
	setEngineLogLevel("info")
	log.Infoln("back on")
	if !bytes.Contains(out.Bytes(), []byte("back on")) {
		t.Fatalf("expected logging to resume, got %q", out.String())
	}
}

// A hot reload must never be able to take the running tunnel down: a config
// that does not parse has to be rejected *before* anything is applied, leaving
// the engine on the previous config. (Parse happens in full before ApplyConfig
// in startEngine/reloadEngine, so a returned error means the engine was never
// touched.)
func TestReloadRejectsBadInputBeforeTouchingTheEngine(t *testing.T) {
	// "{" is not parseable YAML; anything parseable would reach ApplyConfig,
	// which starts real listeners — exactly what this test must not do.
	if err := reloadEngine(5, "{"); err == nil {
		t.Fatal("a config that does not parse must be rejected")
	}
	if err := reloadEngine(5, ""); err == nil {
		t.Fatal("an empty config must be rejected")
	}
	if err := reloadEngine(0, "log-level: info"); err == nil {
		t.Fatal("a missing fd must be rejected")
	}
}
