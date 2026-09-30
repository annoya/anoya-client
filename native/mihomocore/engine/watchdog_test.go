package engine

import (
	"errors"
	"fmt"
	"net"
	"testing"
	"time"

	"github.com/metacubex/mihomo/adapter/outbound"
	C "github.com/metacubex/mihomo/constant"
	"github.com/metacubex/mihomo/tunnel/statistic"
)

var t0 = time.Date(2026, 9, 30, 7, 53, 0, 0, time.UTC)

func at(seconds int) time.Time { return t0.Add(time.Duration(seconds) * time.Second) }

func unansweredConns(prefix string, n int, start time.Time) []connSample {
	out := make([]connSample, n)
	for i := range out {
		out[i] = connSample{id: fmt.Sprintf("%s%d", prefix, i), up: 1200, start: start}
	}
	return out
}

func TestSilentProxyIsReportedAfterTheWindow(t *testing.T) {
	d := newStallDetector(t0)
	conns := unansweredConns("c", 6, t0)
	for s := 1; s < int(silenceWindow/time.Second); s++ {
		if stalled, _ := d.observe(at(s), conns); stalled {
			t.Fatalf("reported a stall after %ds, before the %s window", s, silenceWindow)
		}
	}
	stalled, unanswered := d.observe(at(int(silenceWindow/time.Second)), conns)
	if !stalled || unanswered != 6 {
		t.Fatalf("stalled=%v unanswered=%d, want a stall over 6 connections", stalled, unanswered)
	}
}

func TestConnectionsClosedWithoutAnAnswerCount(t *testing.T) {
	d := newStallDetector(t0)
	var stalled bool
	for s := 1; s <= 16; s++ {
		batch := unansweredConns(fmt.Sprintf("s%d-", s), 1, at(s))
		stalled, _ = d.observe(at(s), batch)
	}
	if !stalled {
		t.Fatal("short-lived connections that never got a byte back must count as unanswered")
	}
}

func TestAnyAnswerKeepsTheTunnelHealthy(t *testing.T) {
	d := newStallDetector(t0)
	dead := unansweredConns("c", 10, t0)
	for s := 1; s <= 60; s++ {
		alive := connSample{id: "stream", up: 500, down: int64(100 * s), start: t0}
		if stalled, _ := d.observe(at(s), append(dead, alive)); stalled {
			t.Fatalf("reported a stall at %ds while a connection kept receiving", s)
		}
	}
}

func TestIdleTunnelIsNotAStall(t *testing.T) {
	d := newStallDetector(t0)
	idle := []connSample{{id: "push", up: 300, down: 900, start: t0}}
	for s := 1; s <= 120; s++ {
		if stalled, _ := d.observe(at(s), idle); stalled {
			t.Fatalf("an idle tunnel was reported as stalled at %ds", s)
		}
	}
}

func TestFewUnansweredConnectionsAreNotAStall(t *testing.T) {
	d := newStallDetector(t0)
	conns := unansweredConns("c", minUnanswered-1, t0)
	for s := 1; s <= 60; s++ {
		if stalled, _ := d.observe(at(s), conns); stalled {
			t.Fatalf("%d unanswered connections were enough for a stall", minUnanswered-1)
		}
	}
}

func TestConnectionThatSentNothingIsNotUnanswered(t *testing.T) {
	d := newStallDetector(t0)
	conns := make([]connSample, 10)
	for i := range conns {
		conns[i] = connSample{id: fmt.Sprintf("c%d", i), start: t0}
	}
	for s := 1; s <= 60; s++ {
		if stalled, _ := d.observe(at(s), conns); stalled {
			t.Fatal("a connection that sent nothing is not waiting for an answer")
		}
	}
}

func TestRecoverWithoutARunningEngineRefuses(t *testing.T) {
	if err := Recover("test"); !errors.Is(err, errNotRunning) {
		t.Fatalf("Recover before Start: got %v, want errNotRunning", err)
	}
}

type namedAdapter struct {
	*outbound.Direct
	name string
}

func (a namedAdapter) Name() string { return a.name }

func trackConn(t *testing.T, chain ...string) {
	t.Helper()
	local, remote := net.Pipe()
	t.Cleanup(func() { _ = remote.Close() })
	conn := outbound.NewConn(local, namedAdapter{outbound.NewDirect(), chain[0]})
	for _, hop := range chain[1:] {
		conn.AppendToChains(namedAdapter{outbound.NewDirect(), hop})
	}
	tracker := statistic.NewTCPTracker(conn, statistic.DefaultManager, &C.Metadata{}, nil, 1200, 0, false)
	t.Cleanup(func() { _ = tracker.Close() })
}

func TestOnlyConnectionsThroughTheProxyAreWatched(t *testing.T) {
	trackConn(t, "proxy", watchedGroup)
	trackConn(t, "DIRECT")
	samples := watchedSamples()
	if len(samples) != 1 {
		t.Fatalf("watched %d connection(s), want only the one through %s", len(samples), watchedGroup)
	}
	if samples[0].up != 1200 || samples[0].down != 0 {
		t.Fatalf("sample = %+v, want the tracker's own counters", samples[0])
	}
}
