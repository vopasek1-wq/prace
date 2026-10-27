import 'dart:typed_data';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Místní cache stažených fotek, aby se každá stáhla z Disku jen jednou.
abstract class PhotoCache {
  Future<Uint8List?> read(String key);
  Future<void> write(String key, Uint8List bytes);
}

class MemoryPhotoCache implements PhotoCache {
  final _data = <String, Uint8List>{};

  @override
  Future<Uint8List?> read(String key) async => _data[key];

  @override
  Future<void> write(String key, Uint8List bytes) async => _data[key] = bytes;
}

/// Cache na disku telefonu (přežije restart aplikace).
class DiskPhotoCache implements PhotoCache {
  final _manager = CacheManager(
    Config('jimmy_photos', stalePeriod: const Duration(days: 180), maxNrOfCacheObjects: 500),
  );

  @override
  Future<Uint8List?> read(String key) async {
    final info = await _manager.getFileFromCache(key);
    return info?.file.readAsBytes();
  }

  @override
  Future<void> write(String key, Uint8List bytes) async {
    await _manager.putFile(key, bytes, key: key, fileExtension: 'jpg');
  }
}
