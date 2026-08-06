package main

import (
	"bytes"
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
	t.Cleanup(func() { logrus.SetOutput(nil) })

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
