import 'dart:io';

import 'package:http/http.dart' as http;

import '../api/api_client.dart';

const kDownloadStallTimeout = Duration(seconds: 30);

Future<void> downloadToFile(
  Uri url,
  File dest, {
  required String what,
  int? maxBytes,
  Duration stallTimeout = kDownloadStallTimeout,
}) async {
  final client = http.Client();
  final tmp = File('${dest.path}.tmp');
  try {
    final res = await client
        .send(http.Request('GET', url))
        .timeout(kHttpTimeout);
    if (res.statusCode ~/ 100 != 2) {
      throw http.ClientException('$what download failed (${res.statusCode})');
    }
    final sink = tmp.openWrite();
    var written = 0;
    try {
      await for (final chunk in res.stream.timeout(stallTimeout)) {
        written += chunk.length;
        if (maxBytes != null && written > maxBytes) {
          throw http.ClientException('$what exceeds ${maxBytes ~/ 1024} KB');
        }
        sink.add(chunk);
      }
    } finally {
      await sink.close();
    }
    if (written == 0) throw http.ClientException('$what was empty');
    await tmp.rename(dest.path);
  } catch (_) {
    if (await tmp.exists()) await tmp.delete();
    rethrow;
  } finally {
    client.close();
  }
}
