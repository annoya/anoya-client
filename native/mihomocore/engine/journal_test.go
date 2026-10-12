package engine

import (
	"errors"
	"net"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

func TestJournalWritesOnlyWhileAPathIsSet(t *testing.T) {
	path := filepath.Join(t.TempDir(), "tunnel.log")
	t.Cleanup(func() { SetJournal("") })

	journal("before")
	SetJournal(path)
	journal("engine %s", "started")
	SetJournal("")
	journal("after")

	b, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	lines := strings.Split(strings.TrimSuffix(string(b), "\n"), "\n")
	if len(lines) != 1 || !strings.HasSuffix(lines[0], " engine started") {
		t.Fatalf("journal holds %q, want only the line written while it was on", lines)
	}
}

func TestJournalLinesAreStampedInUTCWithMilliseconds(t *testing.T) {
	at := time.Date(2026, 10, 12, 13, 4, 5, 7_000_000, time.FixedZone("MSK", 3*3600))
	if got := JournalLine(at, "wake"); got != "2026-10-12T10:04:05.007Z wake\n" {
		t.Fatalf("line %q", got)
	}
}

func TestBriefErrorKeepsTheCauseWithoutTheAddress(t *testing.T) {
	err := &net.OpError{Op: "dial", Net: "tcp",
		Addr: &net.TCPAddr{IP: net.ParseIP("203.0.113.7"), Port: 443},
		Err:  errors.New("i/o timeout")}
	if got := briefError(err); got != "i/o timeout" {
		t.Fatalf("brief %q", got)
	}
}

func TestCrashLogCanBeSwitchedOnAndOff(t *testing.T) {
	path := filepath.Join(t.TempDir(), "mihomo.log")
	SetCrashLog(path)
	SetCrashLog("")
	if _, err := os.Stat(path); err != nil {
		t.Fatalf("crash log was not opened: %v", err)
	}
}
