import 'package:flutter/foundation.dart';

import '../../chat/domain/message.dart';

/// Fotka ze složky na hlavním Google Disku (výběr "Ze složky na Google Disku").
class DrivePhotoItem {
  const DrivePhotoItem({
    required this.id,
    required this.name,
    required this.mimeType,
    this.width,
    this.height,
    this.thumbnail,
  });

  final String id;
  final String name;
  final String mimeType;
  final int? width;
  final int? height;

  /// Malý náhled (~256 px) pro mřížku; brána ho posílá přímo v seznamu.
  final Uint8List? thumbnail;
}

class DrivePage {
  const DrivePage(this.items, this.nextPageToken);

  final List<DrivePhotoItem> items;
  final String? nextPageToken;
}

/// Výsledek nahrání fotky; `text` je přepis textu z fotky (prázdný, pokud nebyl žádný nebo se nežádal).
class PhotoUpload {
  const PhotoUpload(this.photo, {this.text = '', this.ocrFailed = false});

  final PhotoRef photo;
  final String text;

  /// Přepis textu se nepodařil (fotka je ale nahraná).
  final bool ocrFailed;
}

/// Chyba s textem, který se rovnou ukáže uživateli.
class PhotoException implements Exception {
  const PhotoException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Úložiště fotek. Ostrá verze: brána k hlavnímu Google Disku. Demo verze: paměť.
abstract class PhotoStore {
  static const maxUploadBytes = 8 * 1024 * 1024;

  /// Nahraje fotku (už zmenšenou) do složky na hlavním Disku. S `recognizeText` se z ní přepíše i text (OCR).
  Future<PhotoUpload> upload(
    Uint8List bytes, {
    required String mimeType,
    int? width,
    int? height,
    bool recognizeText = false,
  });

  /// Přepíše text z fotky, která už ve složce na Disku je (např. ji tam vložil majitel ručně).
  Future<String> recognizeText(PhotoRef ref);

  /// Fotky ve složce na Disku (nejnovější první), včetně těch, které tam majitel vložil ručně.
  Future<DrivePage> listDrivePhotos({String? pageToken});

  /// Použije fotku, která už ve složce je (nic se nekopíruje).
  Future<PhotoRef> attachDrivePhoto(DrivePhotoItem item);

  /// Náhled pro bublinu v chatu (~1080 px), cachovaný.
  Future<Uint8List> preview(PhotoRef ref);

  /// Originál pro celoobrazovkové zobrazení.
  Future<Uint8List> full(PhotoRef ref);
}
