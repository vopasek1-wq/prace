import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/providers.dart';
import '../../../app/widgets.dart';
import '../../../core/strings.dart';
import '../../chat/domain/message.dart';
import '../data/photo_store.dart';
import '../photo_text.dart';
import 'drive_picker_page.dart';

enum PhotoSource { camera, gallery, drive }

/// Co uživatel v náhledu zvolil: popisek a zda se má z fotky přepsat text.
class PhotoChoice {
  const PhotoChoice({required this.caption, required this.recognizeText});

  final String caption;
  final bool recognizeText;
}

/// Celý postup "přidat fotku": výběr zdroje -> náhled s popiskem -> nahrání -> (přepis textu) -> odeslání zprávy.
Future<void> pickAndSendPhoto(BuildContext context, WidgetRef ref, String roomId) async {
  final backend = ref.read(backendProvider);
  final source = await showModalBottomSheet<PhotoSource>(
    context: context,
    showDragHandle: true,
    builder: (_) => const _SourceSheet(),
  );
  if (source == null || !context.mounted) return;

  void send(PhotoRef photo, String text) {
    unawaited(backend.chat.sendPhoto(roomId, photo, caption: text).catchError((Object _) {}));
  }

  try {
    switch (source) {
      case PhotoSource.camera:
      case PhotoSource.gallery:
        final picked = await ImagePicker().pickImage(
          source: source == PhotoSource.camera ? ImageSource.camera : ImageSource.gallery,
          maxWidth: 1600,
          maxHeight: 1600,
          imageQuality: 80,
        );
        if (picked == null || !context.mounted) return;
        final bytes = await picked.readAsBytes();
        if (!context.mounted) return;
        final choice = await showDialog<PhotoChoice>(
          context: context,
          builder: (_) => PhotoConfirmDialog(preview: bytes),
        );
        if (choice == null || !context.mounted) return;
        final size = await _imageSize(bytes);
        final mime = picked.name.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg';
        if (!context.mounted) return;
        var ocrFailed = false;
        await _withProgress(context, choice.recognizeText ? S.recognizing : S.uploading, () async {
          final upload = await backend.photos.upload(
            bytes,
            mimeType: mime,
            width: size?.$1,
            height: size?.$2,
            recognizeText: choice.recognizeText,
          );
          ocrFailed = upload.ocrFailed;
          send(upload.photo, composePhotoText(caption: choice.caption, recognized: upload.text));
        });
        if (ocrFailed && context.mounted) showSnack(context, S.ocrFailed);
      case PhotoSource.drive:
        final item = await Navigator.of(context)
            .push<DrivePhotoItem>(MaterialPageRoute(builder: (_) => const DrivePickerPage()));
        if (item == null || !context.mounted) return;
        final thumb = item.thumbnail;
        final choice = await showDialog<PhotoChoice>(
          context: context,
          builder: (_) => PhotoConfirmDialog(preview: thumb),
        );
        if (choice == null || !context.mounted) return;
        var ocrFailed = false;
        await _withProgress(context, choice.recognizeText ? S.recognizing : S.uploading, () async {
          var photo = await backend.photos.attachDrivePhoto(item);
          if ((photo.width == null || photo.height == null) && thumb != null) {
            final size = await _imageSize(thumb);
            photo = PhotoRef(
              driveFileId: photo.driveFileId,
              mimeType: photo.mimeType,
              width: size?.$1,
              height: size?.$2,
            );
          }
          var recognized = '';
          if (choice.recognizeText) {
            try {
              recognized = await backend.photos.recognizeText(photo);
            } catch (_) {
              ocrFailed = true;
            }
          }
          send(photo, composePhotoText(caption: choice.caption, recognized: recognized));
        });
        if (ocrFailed && context.mounted) showSnack(context, S.ocrFailed);
    }
  } catch (e) {
    if (context.mounted) showSnack(context, '${S.genericError}: $e');
  }
}

Future<(int, int)?> _imageSize(Uint8List bytes) async {
  try {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final size = (frame.image.width, frame.image.height);
    frame.image.dispose();
    codec.dispose();
    return size;
  } catch (_) {
    return null;
  }
}

Future<void> _withProgress(BuildContext context, String message, Future<void> Function() action) async {
  final navigator = Navigator.of(context, rootNavigator: true);
  unawaited(
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(
            children: [
              const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 3)),
              const SizedBox(width: 20),
              Flexible(child: Text(message)),
            ],
          ),
        ),
      ),
    ),
  );
  try {
    await action();
  } finally {
    navigator.pop();
  }
}

class _SourceSheet extends StatelessWidget {
  const _SourceSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text(S.takePhoto),
            onTap: () => Navigator.of(context).pop(PhotoSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text(S.fromGallery),
            onTap: () => Navigator.of(context).pop(PhotoSource.gallery),
          ),
          ListTile(
            leading: const Icon(Icons.add_to_drive_outlined),
            title: const Text(S.fromDrive),
            subtitle: const Text(S.fromDriveHint),
            onTap: () => Navigator.of(context).pop(PhotoSource.drive),
          ),
        ],
      ),
    );
  }
}

/// Náhled fotky s popiskem a přepínačem "Přepsat text z fotky" (výchozí: zapnuto).
class PhotoConfirmDialog extends StatefulWidget {
  const PhotoConfirmDialog({super.key, required this.preview});

  final Uint8List? preview;

  @override
  State<PhotoConfirmDialog> createState() => _PhotoConfirmDialogState();
}

class _PhotoConfirmDialogState extends State<PhotoConfirmDialog> {
  final _caption = TextEditingController();
  bool _recognize = true;

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      contentPadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.preview != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 240),
                  child: Image.memory(widget.preview!, fit: BoxFit.contain),
                ),
              ),
            const SizedBox(height: 12),
            TextField(
              controller: _caption,
              maxLength: 300,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(hintText: S.caption, counterText: ''),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              value: _recognize,
              onChanged: (v) => setState(() => _recognize = v),
              title: const Text(S.recognizeText),
              subtitle: const Text(S.recognizeHint),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text(S.cancel)),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(PhotoChoice(caption: _caption.text, recognizeText: _recognize)),
          child: const Text(S.send),
        ),
      ],
    );
  }
}
