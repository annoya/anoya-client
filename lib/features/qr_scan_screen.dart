import 'package:camera/camera.dart' show FlashMode;
import 'package:flutter/material.dart';
import 'package:flutter_zxing/flutter_zxing.dart';
import 'package:image_picker/image_picker.dart';

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
    this.hint,
  });

  final String? Function(String text) refuse;

  final String? hint;

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
    return Scaffold(
      backgroundColor: _noCamera ? null : Colors.black,
      extendBodyBehindAppBar: !_noCamera,
      appBar: AppBar(
        backgroundColor: _noCamera ? null : Colors.transparent,
        foregroundColor: _noCamera ? null : Colors.white,
        leading: const CloseButton(),
        title: Text(l10n.startScanQr),
        actions: [
          if (!_noCamera)
            IconButton(
              tooltip: l10n.qrTorch,
              icon: Icon(_torch ? Icons.flashlight_off : Icons.flashlight_on),
              onPressed: _toggleTorch,
            ),
        ],
      ),
      body: _noCamera ? _noCameraBody(context) : _scanner(context),
    );
  }

  Widget _scanner(BuildContext context) {
    final l10n = context.l10n;
    final parts = _parts;
    final refusal = _refusal;
    return LayoutBuilder(
      builder: (context, box) {
        final below = box.maxHeight / 2 + kQrViewfinder / 2;
        return Stack(
          children: [
            Positioned.fill(
              child: ReaderWidget(
                onScan: _onCode,
                onControllerCreated: _onCamera,
                codeFormat: Format.qrCode,
                tryInverted: true,
                showFlashlight: false,
                showToggleCamera: false,
                showGallery: false,
                cropPercent: 0.7,
                scanDelay: const Duration(milliseconds: 150),
                scanDelaySuccess: const Duration(milliseconds: 300),
                scannerOverlay: ScannerOverlayBorder(
                  cutOutSize: kQrViewfinder,
                  borderColor: Colors.white,
                  borderWidth: 4,
                  borderRadius: 20,
                  borderLength: 36,
                  overlayColor: Colors.black.withValues(alpha: kQrScrimOpacity),
                ),
              ),
            ),
            Positioned(
              top: below + 20,
              left: 24,
              right: 24,
              child: Column(
                children: [
                  if (parts != null) ...[
                    _Chip(
                      leading: const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                      text: l10n.qrParts(parts.received, parts.total),
                    ),
                    _Hint(detail: l10n.qrPartsDetail),
                  ] else if (refusal != null) ...[
                    _Chip(
                      warn: true,
                      leading: Icon(
                        Icons.error_outline,
                        size: 18,
                        color: context.vpnColors.connecting,
                      ),
                      text: l10n.startCantUseThis(refusal),
                    ),
                    _Hint(detail: l10n.qrStillLooking),
                  ] else
                    _Hint(
                      title: l10n.qrHint,
                      detail: widget.hint ?? l10n.qrHintDetail,
                    ),
                ],
              ),
            ),
            Positioned(
              left: 24,
              right: 24,
              bottom: 40 + MediaQuery.paddingOf(context).bottom,
              child: FilledButton.tonalIcon(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.16),
                  foregroundColor: Colors.white,
                ),
                onPressed: _fromPhotos,
                icon: const Icon(Icons.photo_library_outlined, size: 18),
                label: Text(l10n.qrFromPhotos),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _noCameraBody(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  Icons.no_photography_outlined,
                  size: 56,
                  color: cs.onSurfaceVariant,
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.qrNoCamera,
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.qrNoCameraDetail,
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 24),
                FilledButton.tonalIcon(
                  onPressed: _fromPhotos,
                  icon: const Icon(Icons.photo_library_outlined, size: 18),
                  label: Text(l10n.qrFromPhotos),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.leading, required this.text, this.warn = false});

  final Widget leading;
  final String text;
  final bool warn;

  @override
  Widget build(BuildContext context) {
    final background = warn
        ? Color.alphaBlend(
            context.vpnColors.connecting.withValues(alpha: 0.30),
            Colors.black.withValues(alpha: 0.40),
          )
        : Colors.white.withValues(alpha: 0.16);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          leading,
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({this.title, required this.detail});

  final String? title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, left: 8, right: 8),
      child: Column(
        children: [
          if (title != null)
            Text(
              title!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          if (title != null) const SizedBox(height: 6),
          Text(
            detail,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.72),
              fontSize: 12.5,
            ),
          ),
        ],
      ),
    );
  }
}
