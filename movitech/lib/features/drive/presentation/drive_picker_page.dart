import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../app/widgets.dart';
import '../../../core/strings.dart';
import '../data/photo_store.dart';

/// Prohlížeč fotek ze složky "Movitech – fotky" na hlavním Google Disku (mřížka 3 sloupce, stránkování).
class DrivePickerPage extends ConsumerStatefulWidget {
  const DrivePickerPage({super.key});

  @override
  ConsumerState<DrivePickerPage> createState() => _DrivePickerPageState();
}

class _DrivePickerPageState extends ConsumerState<DrivePickerPage> {
  final _items = <DrivePhotoItem>[];
  final _scroll = ScrollController();
  String? _nextToken;
  bool _loading = true;
  Object? _error;
  DrivePhotoItem? _selected;

  PhotoStore get _store => ref.read(backendProvider).photos;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 400) _load();
    });
    _load(first: true);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load({bool first = false}) async {
    if (!first && (_loading || _nextToken == null)) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await _store.listDrivePhotos(pageToken: first ? null : _nextToken);
      if (!mounted) return;
      setState(() {
        _items.addAll(page.items);
        _nextToken = page.nextPageToken;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e;
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget body;
    if (_error != null && _items.isEmpty) {
      body = ErrorView(message: '$_error', onRetry: () => _load(first: true));
    } else if (_items.isEmpty && _loading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_items.isEmpty) {
      body = const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(S.driveEmpty, textAlign: TextAlign.center),
        ),
      );
    } else {
      body = GridView.builder(
        controller: _scroll,
        padding: const EdgeInsets.all(4),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 4,
          crossAxisSpacing: 4,
        ),
        itemCount: _items.length,
        itemBuilder: (context, i) {
          final item = _items[i];
          final selected = _selected?.id == item.id;
          return GestureDetector(
            onTap: () => setState(() => _selected = selected ? null : item),
            child: Stack(
              fit: StackFit.expand,
              children: [
                item.thumbnail != null
                    ? Image.memory(item.thumbnail!, fit: BoxFit.cover, gaplessPlayback: true)
                    : Container(color: scheme.surfaceContainerHighest, child: const Icon(Icons.image_outlined)),
                if (selected)
                  Container(
                    color: scheme.primary.withValues(alpha: 0.35),
                    child: Icon(Icons.check_circle, color: scheme.onPrimary, size: 36),
                  ),
              ],
            ),
          );
        },
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text(S.driveTitle)),
      body: body,
      bottomNavigationBar: _selected == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(_selected),
                  child: const Text(S.attachSelected),
                ),
              ),
            ),
    );
  }
}
