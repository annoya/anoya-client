import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart' show XFile;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anoya/core/app_error.dart';
import 'package:anoya/core/file_open.dart';
import 'package:anoya/l10n/l10n.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const control = MethodChannel('vpn/control');

  late _Picker picker;
  late List<String> asked;
  late bool granted;

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    picker = _Picker();
    FilePickerPlatform.instance = picker;
    asked = [];
    granted = true;
    messenger.setMockMethodCallHandler(control, (call) async {
      asked.add(call.method);
      return granted;
    });
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    messenger.setMockMethodCallHandler(control, null);
  });

  Matcher failsWith(String title) => throwsA(
    isA<AppErrorException>().having((e) => e.error.title, 'title', title),
  );

  test('a picked file comes back with its name and bytes', () async {
    picker.result = _File('home.json', Uint8List.fromList([123, 125]));
    final file = await openFile();
    expect(file?.name, 'home.json');
    expect(file?.bytes, [123, 125]);
    expect(asked, ['ensure_file_access']);
  });

  test('cancelling the picker gives nothing back', () async {
    expect(await openFile(), isNull);
  });

  test('storage access refused on a box without DocumentsUI says so', () async {
    granted = false;
    await expectLater(openFile(), failsWith(L10n.current.fileAccessDenied));
    expect(picker.opened, isFalse, reason: 'the pick would fail to read');
  });

  test('a device with nothing to pick files with says so', () async {
    picker.error = PlatformException(code: 'explorer_not_found');
    await expectLater(openFile(), failsWith(L10n.current.fileNoPicker));
  });

  test('a file the picker could not read is reported as unreadable', () async {
    picker.result = _File('home.json', null);
    await expectLater(openFile(), failsWith(L10n.current.startCouldntReadFile));
  });

  test('outside Android nothing is asked first', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    await openFile();
    expect(asked, isEmpty);
    expect(picker.opened, isTrue);
  });
}

class _Picker extends FilePickerPlatform {
  PlatformFile? result;
  PlatformException? error;
  bool opened = false;

  @override
  Future<PlatformFile?> pickFile({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    AndroidOptions androidOptions = const AndroidOptions(),
    DarwinOptions darwinOptions = const DarwinOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    opened = true;
    if (error case final e?) throw e;
    return result;
  }
}

final class _File extends PlatformFile {
  _File(this.name, this.bytes);

  @override
  final String name;
  final Uint8List? bytes;

  @override
  Uri get uri => Uri.parse('content://picked/$name');

  @override
  XFile get xFile => XFile.fromData(bytes ?? Uint8List(0), name: name);

  @override
  int? lengthSync() => bytes?.length;

  @override
  Future<int> length() async => bytes?.length ?? 0;

  @override
  Future<Uint8List> readAsBytes() async =>
      bytes ?? (throw const FileSystemException('unreadable'));

  @override
  Stream<Uint8List> readAsByteStream() => Stream.fromFuture(readAsBytes());
}
