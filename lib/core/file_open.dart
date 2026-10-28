import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../l10n/l10n.dart';
import 'app_error.dart';
import 'network_extension_core.dart';

class OpenedFile {
  const OpenedFile({required this.name, required this.bytes});

  final String name;
  final Uint8List bytes;
}

Future<OpenedFile?> openFile() async {
  final l10n = L10n.current;
  if (!await _mayReadStorage()) {
    throw AppErrorException(
      AppError(l10n.fileAccessDenied, detail: l10n.fileAccessDeniedDetail),
    );
  }
  final FilePickerResult? res;
  try {
    res = await FilePicker.platform.pickFiles(withData: true);
  } on PlatformException catch (e) {
    if (e.code != 'invalid_format_type') rethrow;
    throw AppErrorException(
      AppError(l10n.fileNoPicker, detail: l10n.fileNoPickerDetail),
    );
  }
  final file = res?.files.single;
  if (file == null) return null;
  final bytes = file.bytes;
  if (bytes == null) {
    throw AppErrorException(
      AppError(
        l10n.startCouldntReadFile,
        detail: l10n.startCouldntReadFileDetail,
      ),
    );
  }
  return OpenedFile(name: file.name, bytes: bytes);
}

Future<bool> _mayReadStorage() async {
  if (defaultTargetPlatform != TargetPlatform.android) return true;
  try {
    return await NetworkExtensionCore.control.invoke<bool>(
          'ensure_file_access',
        ) ??
        true;
  } on MissingPluginException {
    return true;
  }
}
