package org.annoya.vpn_client

import android.content.Context
import java.io.File
import java.io.RandomAccessFile

/// The facts both processes need to read.
///
/// The tunnel runs in its own process, so anything one half writes and the
/// other reads cannot live in memory. Nor in SharedPreferences: cross-process
/// prefs were never reliable and `MODE_MULTI_PROCESS` is gone. Every process
/// of an app shares its sandbox, so plain files are the honest channel — and
/// the only one that still works when the process that wrote them has died,
/// which is precisely the case [lastError] exists for.
object TunnelFiles {
    /// The engine's working directory: rendered config, geo databases, logs.
    /// Handed to Dart over `shared_dir`, the same way the App Group container
    /// is on Apple.
    fun engineDir(context: Context): File =
        File(context.filesDir, "engine").apply { mkdirs() }

    fun config(context: Context): File = File(engineDir(context), "last_config.yaml")
    fun engineLog(context: Context): File = File(engineDir(context), "mihomo.log")
    fun serviceLog(context: Context): File = File(engineDir(context), "tunnel.log")

    private fun errorFile(context: Context) = File(engineDir(context), "disconnect_error")
    private fun logFlagFile(context: Context) = File(engineDir(context), "log_enabled")

    fun recordError(context: Context, message: String) {
        runCatching { errorFile(context).writeText(message) }
    }

    fun lastError(context: Context): String =
        runCatching { errorFile(context).readText() }.getOrDefault("")

    fun clearError(context: Context) {
        runCatching { errorFile(context).delete() }
    }

    /// Written by the app, read by the tunnel process on a start nobody was
    /// watching — an always-on boot has no app to ask.
    fun setLogsEnabled(context: Context, on: Boolean) {
        runCatching { logFlagFile(context).writeText(if (on) "1" else "0") }
    }

    fun logsEnabled(context: Context): Boolean =
        runCatching { logFlagFile(context).readText().trim() != "0" }.getOrDefault(true)

    /// The most of a log the app reads into memory, and the size a log may
    /// reach before it is halved. The same two numbers as the Apple extension:
    /// the engine writes its log through a redirected stdout for as long as
    /// the tunnel lives, and nothing else prunes it — a long session used to
    /// grow it without bound, and `fetch_log` then read all of it at once.
    private const val LOG_TAIL_BYTES = 512L * 1024
    private const val LOG_MAX_BYTES = 4L * 1024 * 1024

    /// The last [LOG_TAIL_BYTES] of a log, cut at a line boundary. Also where
    /// the engine's log gets pruned: the tunnel process only appends to it.
    fun tail(file: File): String {
        if (!file.exists()) return ""
        rotateIfNeeded(file)
        return runCatching {
            RandomAccessFile(file, "r").use { raf ->
                val size = raf.length()
                val take = minOf(size, LOG_TAIL_BYTES)
                raf.seek(size - take)
                val bytes = ByteArray(take.toInt())
                raf.readFully(bytes)
                var text = String(bytes, Charsets.UTF_8)
                if (size > take) {
                    val nl = text.indexOf('\n')
                    if (nl >= 0) text = text.substring(nl + 1)
                }
                text
            }
        }.getOrDefault("")
    }

    /// Trim a log that has grown past the cap, keeping the newest half. Half
    /// rather than "down to the cap", so a rotation happens once per half-cap
    /// of writing instead of on every line once the cap is reached. Safe
    /// against a writer in another process: both append, and an append lands
    /// at whatever the end is after the truncation.
    fun rotateIfNeeded(file: File) {
        runCatching {
            RandomAccessFile(file, "rw").use { raf ->
                val size = raf.length()
                if (size <= LOG_MAX_BYTES) return
                raf.seek(size / 2)
                val keep = ByteArray((size - size / 2).toInt())
                raf.readFully(keep)
                raf.setLength(0)
                raf.write(keep)
            }
        }
    }
}
