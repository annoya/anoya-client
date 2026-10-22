package engine

import (
	"fmt"
	"math"
	"runtime"
	"runtime/debug"
	"sync/atomic"
	"time"

	"github.com/metacubex/mihomo/tunnel/statistic"
)

const (
	memoryReleaseGap   = 10 << 20
	memoryShedGap      = 5 << 20
	memoryReleaseEvery = 10 * time.Second
	memoryShedEvery    = 30 * time.Second
)

var memoryBudget atomic.Int64

func SetMemoryBudget(bytes int64) {
	memoryBudget.Store(bytes)
	if bytes <= 0 {
		debug.SetMemoryLimit(math.MaxInt64)
		return
	}
	debug.SetMemoryLimit(bytes * 3 / 4)
}

type memoryStep int

const (
	memoryCalm memoryStep = iota
	memoryRelease
	memoryShed
)

type memoryGuard struct {
	lastRelease, lastShed time.Time
}

func (g *memoryGuard) step(now time.Time, footprint, budget int64) memoryStep {
	if budget <= 0 || footprint <= 0 {
		return memoryCalm
	}
	if footprint >= budget-memoryShedGap && now.Sub(g.lastShed) >= memoryShedEvery {
		g.lastShed, g.lastRelease = now, now
		return memoryShed
	}
	if footprint >= budget-memoryReleaseGap && now.Sub(g.lastRelease) >= memoryReleaseEvery {
		g.lastRelease = now
		return memoryRelease
	}
	return memoryCalm
}

func (g *memoryGuard) check(now time.Time) {
	budget := memoryBudget.Load()
	footprint := physFootprint()
	switch g.step(now, footprint, budget) {
	case memoryShed:
		usage := describeMemory()
		closed := closeTrackedConnections()
		debug.FreeOSMemory()
		journal("memory: %s of the %s limit, closed %d connection(s) and returned memory · %s; now %s",
			megabytes(footprint), megabytes(budget), closed, usage, megabytes(physFootprint()))
	case memoryRelease:
		debug.FreeOSMemory()
	}
}

func ReleaseMemory() {
	before := physFootprint()
	usage := describeMemory()
	debug.FreeOSMemory()
	journal("memory: %s · returned memory, %s → %s", usage, megabytes(before), megabytes(physFootprint()))
}

func describeMemory() string {
	var m runtime.MemStats
	runtime.ReadMemStats(&m)
	tcp, udp := 0, 0
	statistic.DefaultManager.Range(func(t statistic.Tracker) bool {
		if md := t.Info().Metadata; md != nil && md.NetWork.String() == "udp" {
			udp++
		} else {
			tcp++
		}
		return true
	})
	return fmt.Sprintf("go %s (heap %s, stacks %s, held for reuse %s), %d goroutines, %d tcp / %d udp connection(s)",
		megabytes(int64(m.Sys-m.HeapReleased)), megabytes(int64(m.HeapInuse)), megabytes(int64(m.StackInuse)),
		megabytes(int64(m.HeapIdle-m.HeapReleased)), runtime.NumGoroutine(), tcp, udp)
}

func megabytes(n int64) string {
	if n < 0 {
		return "unknown"
	}
	return fmt.Sprintf("%.1f MB", float64(n)/(1<<20))
}
