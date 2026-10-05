import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';

import 'app_version.dart';
import 'ext_logs.dart';
import 'log.dart';

Future<File> buildLogArchive({required DateTime now}) async {
  final archive = Archive();

  void add(String name, String text) {
    final bytes = utf8.encode(text.isEmpty ? '(empty)\n' : text);
    archive.addFile(ArchiveFile(name, bytes.length, bytes));
  }

  add('app.log', '${logHeader(now)}\n${Log.dump()}');
  for (final name in extensionLogNames) {
    add('$name.log', await fetchExtensionLog(name));
  }

  final stamp =
      '${now.year}${_two(now.month)}${_two(now.day)}'
      '-${_two(now.hour)}${_two(now.minute)}${_two(now.second)}';
  final dir = await (await getTemporaryDirectory()).create(recursive: true);
  final file = File('${dir.path}/vpn-logs-$stamp.zip');
  await file.writeAsBytes(ZipEncoder().encode(archive), flush: true);
  Log.i('log archive written: ${file.path}');
  return file;
}

String logHeader(DateTime now) =>
    '$kAppName $appVersionLabel · ${Platform.operatingSystem} '
    '${Platform.operatingSystemVersion} · $engineVersionLabel · '
    'written ${now.toIso8601String()}';

String _two(int n) => n.toString().padLeft(2, '0');
