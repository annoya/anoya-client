import 'dart:convert';
import 'dart:typed_data';

import 'share_link.dart' show kShareLinkSchemes;

const kAmneziaQrMagic = 1984;

sealed class QrStep {
  const QrStep();
}

final class QrText extends QrStep {
  const QrText(this.text);

  final String text;
}

final class QrParts extends QrStep {
  const QrParts(this.received, this.total);

  final int received;
  final int total;
}

class QrReader {
  final _parts = <int, Uint8List>{};
  int _total = 0;

  QrStep read(String raw) {
    final text = raw.trim();
    final chunk = _amneziaChunk(text);
    if (chunk == null) return QrText(unwrapImportLink(text));
    if (chunk.total != _total) {
      _parts.clear();
      _total = chunk.total;
    }
    _parts[chunk.index] = chunk.data;
    if (_parts.length < _total) return QrParts(_parts.length, _total);
    final joined = utf8.decode([
      for (var i = 0; i < _total; i++) ..._parts[i]!,
    ], allowMalformed: true).trim();
    _parts.clear();
    _total = 0;
    return QrText(joined.contains('://') ? joined : 'vpn://$joined');
  }
}

final _base64Url = RegExp(r'^[A-Za-z0-9_-]+$');

({int total, int index, Uint8List data})? _amneziaChunk(String text) {
  if (text.length < 12 || !_base64Url.hasMatch(text)) return null;
  final Uint8List bytes;
  try {
    bytes = base64Url.decode(base64Url.normalize(text));
  } on FormatException {
    return null;
  }
  if (bytes.length < 8) return null;
  final view = ByteData.sublistView(bytes);
  if (view.getInt16(0) != kAmneziaQrMagic) return null;
  final total = bytes[2];
  final index = bytes[3];
  if (total == 0 || index >= total) return null;
  final length = view.getUint32(4);
  if (length == 0xFFFFFFFF) {
    return (total: total, index: index, data: Uint8List(0));
  }
  if (8 + length > bytes.length) return null;
  return (
    total: total,
    index: index,
    data: Uint8List.sublistView(bytes, 8, 8 + length),
  );
}

final _scheme = RegExp(r'^([A-Za-z][A-Za-z0-9+.-]*)://');
final _pathWrapped = RegExp(
  r'^[A-Za-z][A-Za-z0-9+.-]*://[^/?#]*/(https?://.+)$',
);

String unwrapImportLink(String text) {
  final t = text.trim();
  final scheme = _scheme.firstMatch(t)?[1]?.toLowerCase();
  if (scheme == null ||
      kShareLinkSchemes.contains(scheme) ||
      const {'http', 'https', 'vpn'}.contains(scheme)) {
    return t;
  }
  String? param;
  try {
    param = Uri.tryParse(t)?.queryParameters['url'];
  } on FormatException {
    param = null;
  }
  if (param != null && _isHttp(param)) return param;
  return _pathWrapped.firstMatch(t)?[1] ?? t;
}

bool _isHttp(String s) {
  final lower = s.toLowerCase();
  return lower.startsWith('https://') || lower.startsWith('http://');
}
