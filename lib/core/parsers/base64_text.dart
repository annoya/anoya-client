import 'dart:convert';

import 'package:crypto/crypto.dart';

String decodeLooseBase64(String s) {
  var t = s.trim().replaceAll('-', '+').replaceAll('_', '/');
  final pad = t.length % 4;
  if (pad != 0) t += '=' * (4 - pad);
  return utf8.decode(base64.decode(t));
}

String? tryDecodeLooseBase64(String s) {
  try {
    return decodeLooseBase64(s);
  } catch (_) {
    return null;
  }
}

String shortDigest(String s) =>
    sha1.convert(utf8.encode(s)).toString().substring(0, 10);
