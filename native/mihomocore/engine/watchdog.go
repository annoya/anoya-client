package engine

import (
	"slices"
	"sync/atomic"
	"time"

	"github.com/metacubex/mihomo/log"
	"github.com/metacubex/mihomo/tunnel/statistic"
)

const (
	watchedGroup      = "PROXY"
	sampleInterval    = time.Second
	answerTimeout     = 5 * time.Second
	silenceWindow     = 15 * time.Second
	minUnanswered     = 5
	minRecoverBackoff = time.Minute
	maxRecoverBackoff = 10 * time.Minute
)

type connSample struct {
	id       string
	up, down int64
	start    time.Time
	final    func() int64
}

type stallDetector struct {
	lastAnswer time.Time
	last       map[string]connSample
	gaveUp     map[string]bool
	misses     []time.Time
}

func newStallDetector(now time.Time) *stallDetector {
	return &stallDetector{
		lastAnswer: now,
		last:       map[string]connSample{},
		gaveUp:     map[string]bool{},
	}
}

func (d *stallDetector) observe(now time.Time, samples []connSample) (stalled bool, unanswered int) {
	alive := make(map[string]connSample, len(samples))
	for _, s := range samples {
		alive[s.id] = s
		if s.down > d.last[s.id].down {
			d.lastAnswer = now
		}
		if s.up > 0 && s.down == 0 && now.Sub(s.start) >= answerTimeout && !d.gaveUp[s.id] {
			d.gaveUp[s.id] = true
			d.misses = append(d.misses, now)
		}
	}
	for id, s := range d.last {
		if _, ok := alive[id]; ok {
			continue
		}
		switch {
		case s.final != nil && s.final() > s.down:
			d.lastAnswer = now
		case s.up > 0 && s.down == 0 && !d.gaveUp[id]:
			d.misses = append(d.misses, now)
		}
		delete(d.gaveUp, id)
	}
	d.last = alive

	cutoff := now.Add(-silenceWindow)
	d.misses = slices.DeleteFunc(d.misses, func(t time.Time) bool { return t.Before(cutoff) })

	unanswered = len(d.misses)
	stalled = now.Sub(d.lastAnswer) >= silenceWindow && unanswered >= minUnanswered
	return stalled, unanswered
}

func watchedSamples() []connSample {
	var out []connSample
	statistic.DefaultManager.Range(func(t statistic.Tracker) bool {
		info := t.Info()
		if slices.Contains(info.Chain, watchedGroup) {
			out = append(out, connSample{
				id:    info.UUID.String(),
				up:    info.UploadTotal.Load(),
				down:  info.DownloadTotal.Load(),
				start: info.Start,
				final: info.DownloadTotal.Load,
			})
		}
		return true
	})
	return out
}

var watchdogStop chan struct{}

var serverSilent atomic.Bool

func ServerSilent() bool { return serverSilent.Load() }

type silenceEpisode struct {
	reloaded bool
}

func (e *silenceEpisode) answered() bool {
	e.reloaded = false
	return serverSilent.Swap(false)
}

func (e *silenceEpisode) stalled() bool {
	if !e.reloaded {
		return false
	}
	return !serverSilent.Swap(true)
}

func (e *silenceEpisode) afterReload() { e.reloaded = true }

func startWatchdog() {
	stopWatchdog()
	stop := make(chan struct{})
	watchdogStop = stop
	go runWatchdog(stop)
}

func stopWatchdog() {
	if watchdogStop != nil {
		close(watchdogStop)
		watchdogStop = nil
	}
	serverSilent.Store(false)
}

func runWatchdog(stop <-chan struct{}) {
	ticker := time.NewTicker(sampleInterval)
	defer ticker.Stop()
	detector := newStallDetector(time.Now())
	lastRotate := time.Now()
	memory := &memoryGuard{}
	episode := &silenceEpisode{}
	backoff := minRecoverBackoff
	var notBefore time.Time
	for {
		select {
		case <-stop:
			return
		case now := <-ticker.C:
			if now.Sub(lastRotate) >= logRotateInterval {
				rotateEngineLog()
				lastRotate = now
			}
			memory.check(now)
			answeredBefore := detector.lastAnswer
			stalled, unanswered := detector.observe(now, watchedSamples())
			if detector.lastAnswer.After(answeredBefore) {
				backoff = minRecoverBackoff
				if episode.answered() {
					journal("watchdog: the server answers again")
				}
			}
			if !stalled || now.Before(notBefore) {
				continue
			}
			log.Warnln("[watchdog] nothing came back through %s for %s, %d connection(s) unanswered",
				watchedGroup, now.Sub(detector.lastAnswer).Round(time.Second), unanswered)
			journal("watchdog: nothing came back through %s for %s, %d connection(s) unanswered; reloading the engine",
				watchedGroup, now.Sub(detector.lastAnswer).Round(time.Second), unanswered)
			if episode.stalled() {
				journal("watchdog: still silent after a reload; the person is told")
			}
			select {
			case <-stop:
				return
			default:
			}
			if err := Recover("watchdog"); err != nil {
				log.Warnln("[watchdog] reload failed: %v", err)
				journal("watchdog: reload failed: %s", briefError(err))
			}
			episode.afterReload()
			notBefore = now.Add(backoff)
			backoff = min(backoff*2, maxRecoverBackoff)
			detector = newStallDetector(time.Now())
		}
	}
}
