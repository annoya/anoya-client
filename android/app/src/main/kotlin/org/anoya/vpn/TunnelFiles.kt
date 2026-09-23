package org.anoya.vpn

import android.content.Context
import java.io.File
import java.io.RandomAccessFile

object TunnelFiles {
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

    fun setLogsEnabled(context: Context, on: Boolean) {
        runCatching { logFlagFile(context).writeText(if (on) "1" else "0") }
    }

    fun logsEnabled(context: Context): Boolean =
        runCatching { logFlagFile(context).readText().trim() != "0" }.getOrDefault(true)

    private const val LOG_TAIL_BYTES = 512L * 1024
    private const val LOG_MAX_BYTES = 4L * 1024 * 1024

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
