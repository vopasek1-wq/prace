import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../chat/domain/message.dart';
import 'photo_cache.dart';
import 'photo_store.dart';

typedef IdTokenProvider = Future<String?> Function();

/// Fotky na HLAVNÍM Google Disku přes "bránu" (skript gateway/Code.gs v Apps Scriptu).
///
/// Členové týmu se k Disku nepřihlašují. Aplikace pošle bráně svůj Firebase ID token,
/// brána ověří, že jde o člena týmu, a čte/ukládá fotky ve složce na Disku hlavního účtu.
class GatewayPhotoStore implements PhotoStore {
  GatewayPhotoStore({
    required String gatewayUrl,
    required this.idToken,
    http.Client? client,
    PhotoCache? cache,
    this.timeout = const Duration(seconds: 90),
  }) : _url = gatewayUrl.trim(),
       _client = client ?? http.Client(),
       _cache = cache ?? MemoryPhotoCache();

  final String _url;
  final IdTokenProvider idToken;
  final Duration timeout;
  final http.Client _client;
  final PhotoCache _cache;

  final _previews = <String, Future<Uint8List>>{};

  static const _allowedMime = {'image/jpeg', 'image/png', 'image/webp', 'image/heic', 'image/heif', 'image/gif'};

  // ---------------------------------------------------------------- protokol

  Future<Map<String, dynamic>> _call(Map<String, Object?> body) async {
    if (_url.isEmpty) {
      throw const PhotoException(
        'Fotky nejsou nastavené: v config.json chybí PHOTO_GATEWAY_URL (viz docs/SPUSTENI.md, kapitola 5.3).',
      );
    }
    final token = await idToken();
    if (token == null) throw const PhotoException('Nejste přihlášeni.');

    final uri = Uri.parse(_url);
    final request = http.Request('POST', uri)
      ..followRedirects = false
      ..headers['Content-Type'] = 'text/plain;charset=utf-8'
      ..body = jsonEncode({...body, 'idToken': token});

    http.Response response;
    try {
      response = await http.Response.fromStream(await _client.send(request).timeout(timeout));
      // Apps Script na POST odpoví přesměrováním (302) na adresu s hotovým výsledkem, který se čte GETem.
      var hops = 0;
      while (_isRedirect(response) && hops++ < 3) {
        final location = response.headers['location'];
        if (location == null) break;
        response = await _client.get(uri.resolve(location)).timeout(timeout);
      }
    } on TimeoutException {
      throw const PhotoException('Server s fotkami neodpověděl včas. Zkuste to znovu.');
    } on http.ClientException {
      throw const PhotoException('Nepodařilo se spojit se serverem. Zkontrolujte připojení k internetu.');
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      throw PhotoException(
        'Brána pro fotky neodpověděla správně (HTTP ${response.statusCode}). '
        'Zkontrolujte nasazení: "Kdo má přístup" musí být "Kdokoli" (docs/SPUSTENI.md, kapitola 5.3).',
      );
    }
    if (decoded is! Map<String, dynamic>) throw const PhotoException('Brána pro fotky vrátila neočekávanou odpověď.');
    if (decoded['ok'] != true) throw PhotoException(_messageFor('${decoded['error']}'));
    return decoded;
  }

  /// dart:io u POST hlásí `isRedirect` jen pro 303, proto se kontroluje přímo stavový kód.
  static bool _isRedirect(http.Response r) =>
      const {301, 302, 303, 307, 308}.contains(r.statusCode) && r.headers.containsKey('location');

  static String _messageFor(String code) => switch (code) {
    'unauthorized' => 'Přihlášení vypršelo. Odhlaste se a přihlaste znovu.',
    'forbidden' => 'Tento účet nemá přístup (není v seznamu povolených).',
    'not-found' => 'Fotka už na Disku není.',
    'too-large' => 'Fotka je příliš velká.',
    'unsupported-type' => 'Tento typ souboru nejde poslat.',
    'ocr-failed' => 'Text z fotky se nepodařilo přepsat.',
    'not-configured' => 'Brána pro fotky není dokončená (ve skriptu spusťte funkci setup, viz docs/SPUSTENI.md).',
    _ => 'Brána pro fotky vrátila chybu ($code).',
  };

  String _key(String id, String variant) => '$id@$variant';

  // ---------------------------------------------------------------- nahrání a výběr

  @override
  Future<PhotoUpload> upload(
    Uint8List bytes, {
    required String mimeType,
    int? width,
    int? height,
    bool recognizeText = false,
  }) async {
    if (!_allowedMime.contains(mimeType)) throw const PhotoException('Tento typ souboru nejde poslat.');
    if (bytes.length > PhotoStore.maxUploadBytes) throw const PhotoException('Fotka je příliš velká (max. 8 MB).');

    final res = await _call({
      'action': 'upload',
      'mimeType': mimeType,
      'data': base64Encode(bytes),
      'ocr': recognizeText,
    });
    final id = res['fileId'];
    if (id is! String) throw const PhotoException('Brána pro fotky nevrátila ID souboru.');

    // Odesílatel má bajty už v ruce -> nemusí je znovu stahovat.
    _previews[id] = Future.value(bytes);
    await _cache.write(_key(id, 'preview'), bytes);
    await _cache.write(_key(id, 'full'), bytes);
    final text = res['text'];
    return PhotoUpload(
      PhotoRef(driveFileId: id, mimeType: mimeType, width: width, height: height),
      text: text is String ? text : '',
      ocrFailed: res['ocrFailed'] == true,
    );
  }

  @override
  Future<String> recognizeText(PhotoRef ref) async {
    final res = await _call({'action': 'ocr', 'fileId': ref.driveFileId});
    final text = res['text'];
    return text is String ? text : '';
  }

  @override
  Future<DrivePage> listDrivePhotos({String? pageToken}) async {
    final res = await _call({'action': 'list', 'limit': 36, 'pageToken': pageToken});
    final raw = res['items'];
    final items = <DrivePhotoItem>[
      if (raw is List)
        for (final e in raw.whereType<Map<String, dynamic>>())
          if (e['id'] is String)
            DrivePhotoItem(
              id: e['id'] as String,
              name: (e['name'] as String?) ?? '',
              mimeType: (e['mimeType'] as String?) ?? 'image/jpeg',
              width: (e['width'] as num?)?.toInt(),
              height: (e['height'] as num?)?.toInt(),
              thumbnail: e['thumb'] is String ? base64Decode(e['thumb'] as String) : null,
            ),
    ];
    final next = res['next'];
    return DrivePage(items, next is String && next.isNotEmpty ? next : null);
  }

  @override
  Future<PhotoRef> attachDrivePhoto(DrivePhotoItem item) async =>
      PhotoRef(driveFileId: item.id, mimeType: item.mimeType, width: item.width, height: item.height);

  // ---------------------------------------------------------------- zobrazení

  @override
  Future<Uint8List> preview(PhotoRef ref) {
    final id = ref.driveFileId;
    final future = _previews.putIfAbsent(id, () => _load(id, 'preview'));
    // Neúspěch se nezapamatuje, ať jde fotka načíst znovu.
    future.catchError((Object _) {
      _previews.remove(id);
      return Uint8List(0);
    });
    return future;
  }

  @override
  Future<Uint8List> full(PhotoRef ref) => _load(ref.driveFileId, 'full');

  Future<Uint8List> _load(String id, String variant) async {
    final cached = await _cache.read(_key(id, variant));
    if (cached != null) return cached;
    final res = await _call({'action': 'get', 'fileId': id, 'variant': variant});
    final data = res['data'];
    if (data is! String) throw const PhotoException('Brána pro fotky nevrátila data.');
    final bytes = base64Decode(data);
    await _cache.write(_key(id, variant), bytes);
    return bytes;
  }
}
