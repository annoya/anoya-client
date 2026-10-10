package engine

import (
	"testing"
	"time"

	"github.com/metacubex/bbolt"
	"github.com/metacubex/mihomo/component/profile/cachefile"
	"github.com/metacubex/mihomo/constant"
)

func useTempHome(t *testing.T) {
	previous := constant.Path.HomeDir()
	constant.SetHomeDir(t.TempDir())
	t.Cleanup(func() {
		closeCacheFile()
		constant.SetHomeDir(previous)
	})
}

func TestStartWaitsForTheEngineThatStillHoldsTheCacheFile(t *testing.T) {
	useTempHome(t)
	closeCacheFile()

	previous, err := bbolt.Open(constant.Path.Cache(), 0o666, &bbolt.Options{Timeout: time.Second})
	if err != nil {
		t.Fatal(err)
	}
	go func() {
		time.Sleep(1500 * time.Millisecond)
		previous.Close()
	}()

	started := time.Now()
	openCacheFile()

	if cachefile.Cache().DB == nil {
		t.Fatal("the fake-ip store was left without its file, so no fake address would resolve")
	}
	if waited := time.Since(started); waited < time.Second {
		t.Fatalf("opened after %s while the file was still locked", waited)
	}
}

func TestStopReleasesTheCacheFileForTheNextEngine(t *testing.T) {
	useTempHome(t)
	closeCacheFile()
	openCacheFile()
	if cachefile.Cache().DB == nil {
		t.Fatal("cache file did not open")
	}

	closeCacheFile()

	next, err := bbolt.Open(constant.Path.Cache(), 0o666, &bbolt.Options{Timeout: 200 * time.Millisecond})
	if err != nil {
		t.Fatalf("the next engine could not open the cache file: %s", err)
	}
	next.Close()
}
