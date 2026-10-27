import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/strings.dart';
import '../../chat/domain/message.dart';

/// Fotka přes celou obrazovku s přibližováním. Hned ukáže náhled, pak originál.
class PhotoViewerScreen extends ConsumerStatefulWidget {
  const PhotoViewerScreen({super.key, required this.photo});

  final PhotoRef photo;

  @override
  ConsumerState<PhotoViewerScreen> createState() => _PhotoViewerScreenState();
}

class _PhotoViewerScreenState extends ConsumerState<PhotoViewerScreen> {
  Uint8List? _preview;
  Uint8List? _full;
  Object? _error;

  @override
  void initState() {
    super.initState();
    final store = ref.read(backendProvider).photos;
    store
        .preview(widget.photo)
        .then((b) {
          if (mounted && _full == null) setState(() => _preview = b);
        })
        .catchError((Object e) {
          if (mounted && _full == null) setState(() => _error = e);
        });
    store
        .full(widget.photo)
        .then((b) {
          if (mounted) setState(() => _full = b);
        })
        .catchError((Object e) {
          if (mounted && _preview == null) setState(() => _error = e);
        });
  }

  @override
  Widget build(BuildContext context) {
    final bytes = _full ?? _preview;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white, title: const Text(S.photoTitle)),
      body: Center(
        child: bytes != null
            ? InteractiveViewer(minScale: 1, maxScale: 5, child: Image.memory(bytes, fit: BoxFit.contain))
            : _error != null
            ? Text(
                '${S.photoLoadFailed}\n$_error',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white),
              )
            : const CircularProgressIndicator(),
      ),
    );
  }
}
