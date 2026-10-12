package engine

import (
	"fmt"
	"os"
	"runtime/debug"
	"strings"
	"sync"
	"time"
)

const LogMaxBytes = 4 << 20

var (
	journalMu   sync.Mutex
	journalPath string
)

func SetJournal(path string) {
	journalMu.Lock()
	defer journalMu.Unlock()
	journalPath = path
}

func SetCrashLog(path string) {
	if path == "" {
		_ = debug.SetCrashOutput(nil, debug.CrashOptions{})
		return
	}
	fh, err := os.OpenFile(path, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0o644)
	if err != nil {
		return
	}
	defer fh.Close()
	_ = debug.SetCrashOutput(fh, debug.CrashOptions{})
}

func JournalLine(at time.Time, msg string) string {
	return at.UTC().Format("2006-01-02T15:04:05.000Z") + " " + msg + "\n"
}

func journal(format string, args ...any) {
	journalMu.Lock()
	defer journalMu.Unlock()
	if journalPath == "" {
		return
	}
	RotateLog(journalPath)
	fh, err := os.OpenFile(journalPath, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0o644)
	if err != nil {
		return
	}
	defer fh.Close()
	_, _ = fh.WriteString(JournalLine(time.Now(), fmt.Sprintf(format, args...)))
}

func RotateLog(path string) {
	fh, err := os.OpenFile(path, os.O_RDWR, 0)
	if err != nil {
		return
	}
	defer fh.Close()
	st, err := fh.Stat()
	if err != nil || st.Size() <= LogMaxBytes {
		return
	}
	size := st.Size()
	keep := make([]byte, size-size/2)
	if _, err := fh.ReadAt(keep, size/2); err != nil {
		return
	}
	if err := fh.Truncate(0); err != nil {
		return
	}
	_, _ = fh.WriteAt(keep, 0)
}

func briefError(err error) string {
	msg := err.Error()
	if i := strings.LastIndex(msg, ": "); i >= 0 {
		msg = msg[i+2:]
	}
	return msg
}
