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
  final PlatformFile? file;
  try {
    file = await FilePicker.pickFile();
  } on PlatformException catch (e) {
    if (e.code != 'explorer_not_found') rethrow;
    throw AppErrorException(
      AppError(l10n.fileNoPicker, detail: l10n.fileNoPickerDetail),
    );
  }
  if (file == null) return null;
  final Uint8List bytes;
  try {
    bytes = await file.readAsBytes();
  } on Exception {
    throw AppErrorException(
      AppError(
        l10n.startCouldntReadFile,
        detail: l10n.startCouldntReadFileDetail,
      ),
    );
  }
  return OpenedFile(name: file.name, bytes: bytes);
}

Future<String?> saveFileAs({
  required String title,
  required String name,
  required Uint8List bytes,
}) async {
  final saved = await FilePicker.saveFile(
    dialogTitle: title,
    fileName: name,
    bytes: bytes,
  );
  if (saved == null) return null;
  return saved.scheme == 'file' ? saved.toFilePath() : '$saved';
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
