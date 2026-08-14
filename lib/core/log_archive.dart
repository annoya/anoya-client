import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';

import 'ext_logs.dart';
import 'log.dart';

/// Collects every log the app can reach into one zip and returns it.
///
/// The tunnel and engine logs live in the extension's own container and are
/// only readable while the VPN is up (see [fetchExtensionLog]); when it is
/// down, their entries still go into the archive carrying that explanation
/// rather than being silently missing — a support archive with a hole in it is
/// worse than one that says why.
///
/// [now] is passed in so the file name is deterministic in tests.
Future<File> buildLogArchive({required DateTime now}) async {
  final archive = Archive();

  void add(String name, String text) {
    final bytes = utf8.encode(text.isEmpty ? '(empty)\n' : text);
    archive.addFile(ArchiveFile(name, bytes.length, bytes));
  }

  add('app.log', Log.dump());
  for (final name in extensionLogNames) {
    add('$name.log', await fetchExtensionLog(name));
  }

  final stamp = '${now.year}${_two(now.month)}${_two(now.day)}'
      '-${_two(now.hour)}${_two(now.minute)}${_two(now.second)}';
  // Temp dir, not app-support: the zip only exists to be shared/copied away,
  // and app-support archives accumulated forever (and outlived "Clear all
  // logs"). The OS reclaims the temp dir on its own.
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/vpn-logs-$stamp.zip');
  await file.writeAsBytes(ZipEncoder().encode(archive), flush: true);
  Log.i('log archive written: ${file.path}');
  return file;
}

String _two(int n) => n.toString().padLeft(2, '0');
