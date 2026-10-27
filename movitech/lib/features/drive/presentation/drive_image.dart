import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/strings.dart';
import '../../chat/domain/message.dart';
import '../data/photo_store.dart';

/// Náhled fotky v bublině chatu. Fotka se načítá přes `PhotoStore` (brána k Disku + cache).
class DriveImage extends ConsumerStatefulWidget {
  const DriveImage({super.key, required this.photo, this.onTap});

  final PhotoRef photo;
  final VoidCallback? onTap;

  @override
  ConsumerState<DriveImage> createState() => _DriveImageState();
}

class _DriveImageState extends ConsumerState<DriveImage> {
  late Future<Uint8List> _future;

  PhotoStore get _store => ref.read(backendProvider).photos;

  @override
  void initState() {
    super.initState();
    _future = _store.preview(widget.photo);
  }

  @override
  void didUpdateWidget(DriveImage old) {
    super.didUpdateWidget(old);
    if (old.photo != widget.photo) _reload();
  }

  void _reload() => setState(() => _future = _store.preview(widget.photo));

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AspectRatio(
      aspectRatio: widget.photo.aspectRatio,
      child: FutureBuilder<Uint8List>(
        future: _future,
        builder: (context, snap) {
          if (snap.hasData) {
            return GestureDetector(
              onTap: widget.onTap,
              child: Image.memory(snap.data!, fit: BoxFit.cover, gaplessPlayback: true),
            );
          }
          if (snap.hasError) {
            final error = snap.error;
            return Material(
              color: scheme.surfaceContainerHighest,
              child: InkWell(
                onTap: _reload,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.broken_image_outlined, color: scheme.onSurfaceVariant),
                        const SizedBox(height: 6),
                        Text(
                          '${error is PhotoException ? error.message : S.photoLoadFailed}\n${S.retry}',
                          textAlign: TextAlign.center,
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }
          return Container(
            color: scheme.surfaceContainerHighest,
            alignment: Alignment.center,
            child: const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
          );
        },
      ),
    );
  }
}
