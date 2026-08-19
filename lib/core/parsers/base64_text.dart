import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Base64 as this ecosystem actually uses it: the url-safe alphabet and the
/// standard one are mixed freely, and padding is routinely omitted.
///
/// Both formats that carry credentials rely on this — a `vmess://` payload is
/// base64 JSON, and a subscription body is usually a base64 list of links — so
/// the tolerance lives in one place rather than being re-derived per parser.
String decodeLooseBase64(String s) {
  var t = s.trim().replaceAll('-', '+').replaceAll('_', '/');
  final pad = t.length % 4;
  if (pad != 0) t += '=' * (4 - pad);
  return utf8.decode(base64.decode(t));
}

/// Null instead of throwing, for the callers that are only guessing whether a
/// blob is base64 at all.
String? tryDecodeLooseBase64(String s) {
  try {
    return decodeLooseBase64(s);
  } catch (_) {
    return null;
  }
}

/// Short, stable digest used to build [Location] ids. A location's identity has
/// to survive a refresh — favourites and the current selection are keyed by it —
/// so it is derived from the link (or the proxy name) rather than the position
/// in the list, and derived the same way for every format.
String shortDigest(String s) => sha1.convert(utf8.encode(s)).toString().substring(0, 10);
