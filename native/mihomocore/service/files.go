package service

import (
	"bytes"
	"errors"
	"io"
	"os"
	"path/filepath"
	"time"
)

// Files is the engine's working directory and what both halves keep in it.
//
// The same layout as the Android tunnel process (TunnelFiles.kt), for the same
// reason: the app and the tunnel are two processes, and the one fact that
// matters most — why the tunnel stopped — has to survive the process that
// learned it. Plain files are the channel that still works after a crash.
//
// On Windows this is %ProgramData%\<app>\engine. The service runs as SYSTEM
// and owns the directory; the installer grants Users modify on it, because the
// app (not the service) downloads the geo databases into the same place —
// mihomo's home dir — and asks for the path over `shared_dir`.
type Files struct {
	Dir string
}

func (f Files) Config() string     { return filepath.Join(f.Dir, "last_config.yaml") }
func (f Files) EngineLog() string  { return filepath.Join(f.Dir, "mihomo.log") }
func (f Files) ServiceLog() string { return filepath.Join(f.Dir, "tunnel.log") }

// CrashLog is where the Go runtime writes the traceback of a panic or fatal
// error. A service has no stderr, so without this a crash leaves nothing but
// the SCM's "terminated unexpectedly".
func (f Files) CrashLog() string  { return filepath.Join(f.Dir, "crash.log") }
func (f Files) errorFile() string { return filepath.Join(f.Dir, "disconnect_error") }
func (f Files) logFlag() string   { return filepath.Join(f.Dir, "log_enabled") }

// Ensure creates the directory. Idempotent; the installer normally did it
// already, with the permissions the app needs.
func (f Files) Ensure() error { return os.MkdirAll(f.Dir, 0o755) }

// SaveConfig persists the config a start nobody is watching will run from —
// the boot-time equivalent of Android's always-on.
func (f Files) SaveConfig(yaml string) error {
	return writeFileAtomic(f.Config(), []byte(yaml))
}

func (f Files) LoadConfig() (string, error) {
	b, err := os.ReadFile(f.Config())
	return string(b), err
}

func (f Files) RemoveConfig() { _ = os.Remove(f.Config()) }

func (f Files) RecordError(msg string) { _ = os.WriteFile(f.errorFile(), []byte(msg), 0o644) }
func (f Files) ClearError()            { _ = os.Remove(f.errorFile()) }
func (f Files) LastError() string {
	b, err := os.ReadFile(f.errorFile())
	if err != nil {
		return ""
	}
	return string(b)
}

// SetLogsEnabled is written by the app and read by the service on a start
// nobody is watching, when there is no app to ask.
func (f Files) SetLogsEnabled(on bool) {
	v := "1"
	if !on {
		v = "0"
	}
	_ = os.WriteFile(f.logFlag(), []byte(v), 0o644)
}

func (f Files) LogsEnabled() bool {
	b, err := os.ReadFile(f.logFlag())
	if err != nil {
		return true
	}
	return string(bytes.TrimSpace(b)) != "0"
}

// The most of a log the app reads at once, and the size a log may reach before
// it is halved — the same two numbers as the other two tunnel processes.
const (
	logTailBytes = 512 * 1024
	logMaxBytes  = 4 * 1024 * 1024
)

// Tail returns the last [logTailBytes] of a log, cut at a line boundary, and
// prunes it on the way when it has grown past the cap. The engine appends to
// its log for as long as the tunnel lives; this is the only thing that trims it.
func (f Files) Tail(path string) string {
	RotateIfNeeded(path)
	fh, err := os.Open(path)
	if err != nil {
		return ""
	}
	defer fh.Close()
	st, err := fh.Stat()
	if err != nil {
		return ""
	}
	size := st.Size()
	take := min(size, int64(logTailBytes))
	buf := make([]byte, take)
	n, err := fh.ReadAt(buf, size-take)
	if err != nil && !errors.Is(err, io.EOF) {
		return ""
	}
	buf = buf[:n]
	if size > take {
		if nl := bytes.IndexByte(buf, '\n'); nl >= 0 {
			buf = buf[nl+1:]
		}
	}
	return string(buf)
}

// RotateIfNeeded trims a log past the cap to its newest half. Half rather than
// "down to the cap", so a rotation happens once per half-cap of writing instead
// of on every line once the cap is reached. Safe against an appender: after the
// truncation its next write lands at whatever the end is then.
func RotateIfNeeded(path string) {
	fh, err := os.OpenFile(path, os.O_RDWR, 0)
	if err != nil {
		return
	}
	defer fh.Close()
	st, err := fh.Stat()
	if err != nil || st.Size() <= logMaxBytes {
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

// Append writes one timestamped line to the service log, when logs are on.
func (f Files) Append(line string) {
	if !f.LogsEnabled() {
		return
	}
	RotateIfNeeded(f.ServiceLog())
	fh, err := os.OpenFile(f.ServiceLog(), os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0o644)
	if err != nil {
		return
	}
	defer fh.Close()
	_, _ = fh.WriteString(time.Now().Format("2006-01-02 15:04:05 ") + line + "\n")
}

func (f Files) ClearLogs() {
	_ = os.WriteFile(f.EngineLog(), nil, 0o644)
	_ = os.WriteFile(f.ServiceLog(), nil, 0o644)
}

// writeFileAtomic lands the whole file or none of it: a start that raced a
// half-written config would run half a config.
func writeFileAtomic(path string, data []byte) error {
	tmp := path + ".tmp"
	if err := os.WriteFile(tmp, data, 0o644); err != nil {
		return err
	}
	return os.Rename(tmp, path)
}
