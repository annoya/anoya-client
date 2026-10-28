import 'package:camera/camera.dart' show FlashMode;
import 'package:flutter/material.dart';
import 'package:flutter_zxing/flutter_zxing.dart';
import 'package:image_picker/image_picker.dart';

import '../core/ds.dart';
import '../core/log.dart';
import '../core/parsers/qr_payload.dart';
import '../core/parsers/subscription.dart';
import '../core/theme.dart';
import '../core/ui.dart';
import '../l10n/l10n.dart';

class QrScanScreen extends StatefulWidget {
  const QrScanScreen({
    super.key,
    this.refuse = refuseUnlessConnection,
    this.title,
    this.headline,
    this.hint,
    this.photos = true,
  });

  final String? Function(String text) refuse;

  final String? title;

  final String? headline;

  final String? hint;

  final bool photos;

  static String? refuseUnlessConnection(String text) =>
      detectInput(text) != null
      ? null
      : whyUnusable(text) ?? L10n.current.importUnusableNotALink;

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen> {
  final _reader = QrReader();
  CameraController? _camera;
  bool _noCamera = false;
  bool _torch = false;
  QrParts? _parts;
  String? _refusal;
  bool _done = false;

  void _onCode(Code code) {
    final raw = code.text;
    if (_done || !mounted || raw == null || raw.trim().isEmpty) return;
    switch (_reader.read(raw)) {
      case final QrParts parts:
        setState(() {
          _parts = parts;
          _refusal = null;
        });
      case QrText(:final text):
        final refusal = widget.refuse(text);
        if (refusal == null) {
          _done = true;
          Navigator.of(context).pop(text);
          return;
        }
        setState(() {
          _parts = null;
          _refusal = refusal;
        });
    }
  }

  void _onCamera(CameraController? controller, Exception? error) {
    if (error != null) {
      Log.e('qr: camera unavailable', '$error');
      if (mounted) setState(() => _noCamera = true);
      return;
    }
    _camera = controller;
  }

  Future<void> _toggleTorch() async {
    final camera = _camera;
    if (camera == null) return;
    final next = !_torch;
    try {
      await camera.setFlashMode(next ? FlashMode.torch : FlashMode.off);
      if (mounted) setState(() => _torch = next);
    } catch (e) {
      Log.e('qr: flashlight unavailable', '$e');
    }
  }

  Future<void> _fromPhotos() async {
    final XFile? file;
    try {
      file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        requestFullMetadata: false,
      );
    } catch (e) {
      Log.e('qr: photo picker failed', '$e');
      return;
    }
    if (file == null) return;
    final code = await zx.readBarcodeImagePath(
      file,
      DecodeParams(format: Format.qrCode, tryHarder: true, tryInverted: true),
    );
    if (!mounted) return;
    if (!code.isValid) {
      showToast(context, context.l10n.qrNoCodeInImage);
      return;
    }
    _onCode(code);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (_noCamera) return _noCameraPage(context);
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kNavRowHeight),
        child: Theme(
          data: theme.copyWith(
            appBarTheme: theme.appBarTheme.copyWith(
              backgroundColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
            ),
            iconButtonTheme: IconButtonThemeData(
              style: IconButton.styleFrom(foregroundColor: Colors.white),
            ),
          ),
          child: DsNavBar(
            leading: DsLeading.close,
            actions: [
              DsNavButton(
                glyph: Glyph.flashlight,
                filled: _torch,
                tooltip: l10n.qrTorch,
                onPressed: _toggleTorch,
              ),
            ],
          ),
        ),
      ),
      body: _scanner(context),
    );
  }

  Widget _scanner(BuildContext context) {
    final l10n = context.l10n;
    final parts = _parts;
    final refusal = _refusal;
    final insets = MediaQuery.paddingOf(context);
    return LayoutBuilder(
      builder: (context, box) {
        // The reader centres its crop and frame: growing it past the top lifts both together.
        final below = box.maxHeight / 2 - kQrViewfinderLift + kQrViewfinder / 2;
        return Stack(
          children: [
            Positioned(
              top: -2 * kQrViewfinderLift,
              left: 0,
              right: 0,
              bottom: 0,
              child: ReaderWidget(
                onScan: _onCode,
                onControllerCreated: _onCamera,
                codeFormat: Format.qrCode,
                tryInverted: true,
                showFlashlight: false,
                showToggleCamera: false,
                showGallery: false,
                cropPercent: kQrViewfinder / box.maxWidth,
                scanDelay: const Duration(milliseconds: 150),
                scanDelaySuccess: const Duration(milliseconds: 300),
                scannerOverlay: ScannerOverlayBorder(
                  cutOutSize: kQrViewfinder,
                  borderColor: Colors.white,
                  borderWidth: 4,
                  borderRadius: kQrViewfinderRadius,
                  borderLength: kQrViewfinderCorner,
                  overlayColor: const Color(
                    0xFF08090E,
                  ).withValues(alpha: kQrScrimOpacity),
                ),
              ),
            ),
            Positioned(
              top: insets.top,
              left: 0,
              right: 0,
              child: DsLargeTitle(
                widget.title ?? l10n.startScanQr,
                color: Colors.white,
              ),
            ),
            Positioned(
              top: below + 24,
              left: kGutter,
              right: kGutter,
              child: DsStack(
                gap: 6,
                children: [
                  if (parts != null) ...[
                    DsNotification(
                      small: true,
                      title: l10n.qrParts(parts.received, parts.total),
                    ),
                    _HintTitle(l10n.qrPartsDetail),
                  ] else if (refusal != null) ...[
                    DsNotification(
                      small: true,
                      title: l10n.startCantUseThis(refusal),
                    ),
                    _HintTitle(l10n.qrStillLooking),
                  ] else ...[
                    _HintTitle(widget.headline ?? l10n.qrHint),
                    Text(
                      widget.hint ?? l10n.qrHintDetail,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xCCFFFFFF),
                        fontSize: 13,
                        height: 16 / 13,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (widget.photos)
              Positioned(
                left: kGutter,
                right: kGutter,
                bottom: kGutter + insets.bottom,
                child: _fromPhotosButton(context),
              ),
          ],
        );
      },
    );
  }

  Widget _fromPhotosButton(BuildContext context) => DsButton.tonal(
    label: context.l10n.qrFromPhotos,
    glyph: Glyph.image,
    onPressed: _fromPhotos,
  );

  Widget _noCameraPage(BuildContext context) {
    final l10n = context.l10n;
    final ds = context.ds;
    return DsPage(
      title: widget.title ?? l10n.startScanQr,
      leading: DsLeading.close,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 80),
          child: DsStack(
            children: [
              const Center(child: GlyphIcon(Glyph.cameraOff, size: 48)),
              Text(
                l10n.qrNoCamera,
                textAlign: TextAlign.center,
                style: DsType.h3.copyWith(color: ds.text1),
              ),
              DsNote(l10n.qrNoCameraDetail, align: TextAlign.center),
              if (widget.photos) _fromPhotosButton(context),
            ],
          ),
        ),
      ],
    );
  }
}

class _HintTitle extends StatelessWidget {
  const _HintTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    textAlign: TextAlign.center,
    style: const TextStyle(
      color: Colors.white,
      fontSize: 15,
      height: 18 / 15,
      fontWeight: FontWeight.w600,
    ),
  );
}
