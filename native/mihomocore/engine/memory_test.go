package engine

import (
	"math"
	"os"
	"path/filepath"
	"runtime"
	"runtime/debug"
	"strings"
	"testing"
)

const testBudget = 50 << 20

func TestMemoryGuardStepsUpOnlyNearTheBudget(t *testing.T) {
	g := &memoryGuard{}
	mb := func(n int64) int64 { return n << 20 }

	steps := []struct {
		at        int
		footprint int64
		want      memoryStep
		why       string
	}{
		{0, mb(30), memoryCalm, "well under the budget"},
		{1, mb(41), memoryRelease, "within 10 MB of the budget"},
		{5, mb(42), memoryCalm, "a release was made moments ago"},
		{12, mb(42), memoryRelease, "the release pause is over"},
		{13, mb(46), memoryShed, "within 5 MB of the budget"},
		{20, mb(46), memoryCalm, "connections were just closed"},
		{24, mb(46), memoryRelease, "too soon to close again, not to release"},
		{44, mb(47), memoryShed, "the shed pause is over"},
	}
	for _, s := range steps {
		if got := g.step(at(s.at), s.footprint, testBudget); got != s.want {
			t.Fatalf("at %ds with %d MB: got step %d, want %d (%s)", s.at, s.footprint>>20, got, s.want, s.why)
		}
	}
}

func TestMemoryGuardStaysOutWithoutABudgetOrAReading(t *testing.T) {
	g := &memoryGuard{}
	if got := g.step(at(0), 1<<30, 0); got != memoryCalm {
		t.Fatalf("no budget: got step %d", got)
	}
	if got := g.step(at(0), -1, testBudget); got != memoryCalm {
		t.Fatalf("no footprint reading: got step %d", got)
	}
}

func TestMemoryBudgetSetsTheGoSoftLimitToThreeQuarters(t *testing.T) {
	t.Cleanup(func() { SetMemoryBudget(0) })

	SetMemoryBudget(testBudget)
	if got := debug.SetMemoryLimit(-1); got != testBudget*3/4 {
		t.Fatalf("soft limit %d, want %d", got, testBudget*3/4)
	}
	SetMemoryBudget(0)
	if got := debug.SetMemoryLimit(-1); got != math.MaxInt64 {
		t.Fatalf("soft limit %d after clearing the budget, want none", got)
	}
}

func TestReleasingMemoryWritesWhatTheMemoryIsMadeOf(t *testing.T) {
	path := filepath.Join(t.TempDir(), "tunnel.log")
	SetJournal(path)
	t.Cleanup(func() { SetJournal("") })

	ReleaseMemory()

	b, _ := os.ReadFile(path)
	line := string(b)
	for _, want := range []string{"memory: go ", "heap ", "goroutines", "connection(s)", "returned memory"} {
		if !strings.Contains(line, want) {
			t.Errorf("journal lacks %q: %q", want, line)
		}
	}
}

func TestFootprintIsReadOnApplePlatforms(t *testing.T) {
	if runtime.GOOS != "darwin" {
		t.Skip("phys_footprint is an Apple measure")
	}
	if got := physFootprint(); got <= 0 {
		t.Fatalf("footprint %d", got)
	}
}
