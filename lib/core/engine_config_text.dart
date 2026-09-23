library;

final _configKey = RegExp(r'^[A-Za-z0-9._-]+$');

bool isSafeConfigKey(String key) => _configKey.hasMatch(key);

String yamlScalar(dynamic value) {
  if (value is bool) return value ? 'true' : 'false';
  if (value is num) return value.toString();
  final s = value.toString().replaceAll('\\', r'\\').replaceAll('"', r'\"');
  return '"$s"';
}

String yamlKey(String key) => isSafeConfigKey(key) ? key : yamlScalar(key);
