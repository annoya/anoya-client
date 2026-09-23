package service

import (
	"bytes"
	"errors"
	"io"
	"os"
	"path/filepath"
	"time"
)

// Same layout as the Android tunnel process (TunnelFiles.kt).
type Files struct {
	Dir string
}

func (f Files) Config() string     { return filepath.Join(f.Dir, "last_config.yaml") }
func (f Files) EngineLog() string  { return filepath.Join(f.Dir, "mihomo.log") }
func (f Files) ServiceLog() string { return filepath.Join(f.Dir, "tunnel.log") }

func (f Files) CrashLog() string        { return filepath.Join(f.Dir, "crash.log") }
func (f Files) errorFile() string       { return filepath.Join(f.Dir, "disconnect_error") }
func (f Files) logFlag() string         { return filepath.Join(f.Dir, "log_enabled") }
func (f Files) autoConnectFlag() string { return filepath.Join(f.Dir, "auto_connect") }

func (f Files) Ensure() error { return os.MkdirAll(f.Dir, 0o755) }

func (f Files) SaveConfig(yaml string) error {
	// Owner-only: it carries credentials and on Linux the directory is
	// world-writable. Windows ignores the mode; the installer sets the ACL.
	return writeFileAtomic(f.Config(), []byte(yaml), 0o600)
}

func (f Files) LoadConfig() (string, error) {
	b, err := os.ReadFile(f.Config())
	return string(b), err
}

func (f Files) RemoveConfig() { _ = os.Remove(f.Config()) }

func (f Files) SetAutoConnect(on bool) {
	if !on {
		_ = os.Remove(f.autoConnectFlag())
		return
	}
	_ = os.WriteFile(f.autoConnectFlag(), []byte("1"), 0o644)
}

func (f Files) AutoConnect() bool {
	_, err := os.Stat(f.autoConnectFlag())
	return err == nil
}

func (f Files) RecordError(msg string) { _ = os.WriteFile(f.errorFile(), []byte(msg), 0o644) }
func (f Files) ClearError()            { _ = os.Remove(f.errorFile()) }
func (f Files) LastError() string {
	b, err := os.ReadFile(f.errorFile())
	if err != nil {
		return ""
	}
	return string(b)
}

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

// Same numbers as the Android and Apple tunnel processes.
const (
	logTailBytes = 512 * 1024
	logMaxBytes  = 4 * 1024 * 1024
)

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

// Halved rather than cut to the cap, or every line past the cap would rotate.
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

func writeFileAtomic(path string, data []byte, perm os.FileMode) error {
	tmp := path + ".tmp"
	if err := os.WriteFile(tmp, data, perm); err != nil {
		return err
	}
	return os.Rename(tmp, path)
}
