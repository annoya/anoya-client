package org.annoya.vpn_client

import android.content.Context
import java.io.File

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
}
