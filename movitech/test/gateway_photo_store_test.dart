import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jimmy/features/chat/domain/message.dart';
import 'package:jimmy/features/drive/data/gateway_photo_store.dart';
import 'package:jimmy/features/drive/data/photo_cache.dart';
import 'package:jimmy/features/drive/data/photo_store.dart';

const _gateway = 'https://script.google.com/macros/s/ABC/exec';
const _echo = 'https://script.googleusercontent.com/macros/echo?user_content_key=xyz';

/// Napodobí Apps Script: POST na /exec -> 302 s adresou výsledku, GET na ni -> JSON.
class _FakeScript {
  _FakeScript(this.respond);

  final Map<String, Object?> Function(Map<String, dynamic> request) respond;
  final requests = <Map<String, dynamic>>[];
  final methods = <String>[];
  Map<String, Object?>? _pending;

  MockClient get client => MockClient((request) async {
    methods.add('${request.method} ${request.url}');
    if (request.method == 'POST') {
      expect(request.url.toString(), _gateway);
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      requests.add(body);
      _pending = respond(body);
      return http.Response('', 302, headers: {'location': _echo});
    }
    expect(request.url.toString(), _echo);
    return http.Response.bytes(
      utf8.encode(jsonEncode(_pending)),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  });
}

GatewayPhotoStore _store(_FakeScript script, {String? token = 'tok', PhotoCache? cache}) =>
    GatewayPhotoStore(gatewayUrl: _gateway, idToken: () async => token, client: script.client, cache: cache);

void main() {
  final bytes = Uint8List.fromList([1, 2, 3, 250, 255, 0, 7]);

  test('upload: pošle ID token a base64 fotku, přečte výsledek přes přesměrování', () async {
    final script = _FakeScript((_) => {'ok': true, 'fileId': 'FILE123456'});
    final upload = await _store(script).upload(bytes, mimeType: 'image/jpeg', width: 800, height: 600);

    expect(upload.photo.driveFileId, 'FILE123456');
    expect(upload.photo.width, 800);
    expect(upload.text, '');
    expect(upload.ocrFailed, isFalse);
    final sent = script.requests.single;
    expect(sent['action'], 'upload');
    expect(sent['idToken'], 'tok');
    expect(sent['mimeType'], 'image/jpeg');
    expect(sent['ocr'], false);
    expect(base64Decode(sent['data'] as String), bytes);
    expect(script.methods, ['POST $_gateway', 'GET $_echo']);
  });

  test('upload: fotku si odesílatel pamatuje, náhled se už nestahuje', () async {
    final script = _FakeScript((_) => {'ok': true, 'fileId': 'FILE123456'});
    final store = _store(script);
    final ref = (await store.upload(bytes, mimeType: 'image/png')).photo;
    expect(await store.preview(ref), bytes);
    expect(await store.full(ref), bytes);
    expect(script.requests.length, 1); // jen upload
  });

  test('preview se stáhne jednou a pak bere z cache; full je zvlášť', () async {
    final script = _FakeScript(
      (req) => {'ok': true, 'mimeType': 'image/jpeg', 'data': base64Encode(utf8.encode('P-${req['variant']}'))},
    );
    final store = _store(script);
    const ref = PhotoRef(driveFileId: 'FILE123456', mimeType: 'image/jpeg');

    expect(utf8.decode(await store.preview(ref)), 'P-preview');
    expect(utf8.decode(await store.preview(ref)), 'P-preview');
    expect(utf8.decode(await store.full(ref)), 'P-full');
    expect(script.requests.map((r) => r['variant']), ['preview', 'full']);
    expect(script.requests.first['fileId'], 'FILE123456');
  });

  test('cache přežije novou instanci (disk po restartu)', () async {
    final cache = MemoryPhotoCache();
    final first = _FakeScript((_) => {'ok': true, 'data': base64Encode(bytes)});
    const ref = PhotoRef(driveFileId: 'FILE123456', mimeType: 'image/jpeg');
    await _store(first, cache: cache).preview(ref);

    final second = _FakeScript((_) => fail('nemělo se volat'));
    expect(await _store(second, cache: cache).preview(ref), bytes);
    expect(second.requests, isEmpty);
  });

  test('neúspěšné načtení se nezapamatuje, další pokus projde', () async {
    var fail = true;
    final script = _FakeScript(
      (_) => fail ? {'ok': false, 'error': 'server-error'} : {'ok': true, 'data': base64Encode(bytes)},
    );
    final store = _store(script);
    const ref = PhotoRef(driveFileId: 'FILE123456', mimeType: 'image/jpeg');

    await expectLater(store.preview(ref), throwsA(isA<PhotoException>()));
    fail = false;
    expect(await store.preview(ref), bytes);
  });

  test('upload s přepisem textu: pošle ocr:true a vrátí text z fotky', () async {
    final script = _FakeScript(
      (_) => {'ok': true, 'fileId': 'FILE123456', 'text': 'Nakládací list č. 118', 'ocrFailed': false},
    );
    final upload = await _store(script).upload(bytes, mimeType: 'image/png', recognizeText: true);
    expect(script.requests.single['ocr'], true);
    expect(upload.text, 'Nakládací list č. 118');
    expect(upload.ocrFailed, isFalse);
  });

  test('upload: když se text nepodařilo přepsat, fotka je přesto nahraná a stav se nahlásí', () async {
    final script = _FakeScript((_) => {'ok': true, 'fileId': 'FILE123456', 'text': '', 'ocrFailed': true});
    final upload = await _store(script).upload(bytes, mimeType: 'image/png', recognizeText: true);
    expect(upload.photo.driveFileId, 'FILE123456');
    expect(upload.text, '');
    expect(upload.ocrFailed, isTrue);
  });

  test('recognizeText přepíše fotku, která už na Disku je', () async {
    final script = _FakeScript((_) => {'ok': true, 'text': 'Dodací list 77'});
    final text = await _store(script).recognizeText(const PhotoRef(driveFileId: 'FILE123456', mimeType: 'image/jpeg'));
    expect(text, 'Dodací list 77');
    expect(script.requests.single['action'], 'ocr');
    expect(script.requests.single['fileId'], 'FILE123456');
  });

  test('recognizeText: chyba brány se přeloží', () async {
    final script = _FakeScript((_) => {'ok': false, 'error': 'ocr-failed'});
    await expectLater(
      _store(script).recognizeText(const PhotoRef(driveFileId: 'FILE123456', mimeType: 'image/jpeg')),
      throwsA(isA<PhotoException>().having((e) => e.message, 'message', contains('nepodařilo přepsat'))),
    );
  });

  test('list: položky s náhledy a stránkováním', () async {
    final script = _FakeScript(
      (_) => {
        'ok': true,
        'items': [
          {
            'id': 'A1',
            'name': 'a.jpg',
            'mimeType': 'image/jpeg',
            'width': 400,
            'height': 300,
            'thumb': base64Encode(bytes),
          },
          {'id': 'B2', 'name': 'b.png', 'mimeType': 'image/png', 'width': null, 'height': null, 'thumb': null},
        ],
        'next': '36',
      },
    );
    final page = await _store(script).listDrivePhotos(pageToken: 'PT');

    expect(page.nextPageToken, '36');
    expect(page.items.map((i) => i.id), ['A1', 'B2']);
    expect(page.items.first.thumbnail, bytes);
    expect(page.items.first.width, 400);
    expect(page.items.last.thumbnail, isNull);
    expect(script.requests.single['pageToken'], 'PT');
    expect(script.requests.single['limit'], 36);
  });

  test('list: poslední stránka nemá další token', () async {
    final script = _FakeScript((_) => {'ok': true, 'items': <Object>[], 'next': null});
    final page = await _store(script).listDrivePhotos();
    expect(page.items, isEmpty);
    expect(page.nextPageToken, isNull);
  });

  test('attachDrivePhoto je jen odkaz na soubor, bez sítě', () async {
    final script = _FakeScript((_) => fail('nemělo se volat'));
    final ref = await _store(
      script,
    ).attachDrivePhoto(const DrivePhotoItem(id: 'A1', name: 'a.jpg', mimeType: 'image/jpeg', width: 400, height: 300));
    expect(ref.driveFileId, 'A1');
    expect(ref.width, 400);
    expect(script.requests, isEmpty);
  });

  group('chyby se překládají do češtiny', () {
    final cases = {
      'unauthorized': 'Přihlášení vypršelo',
      'forbidden': 'nemá přístup',
      'not-found': 'už na Disku není',
      'too-large': 'příliš velká',
      'not-configured': 'funkci setup',
      'cokoli-jineho': 'cokoli-jineho',
    };
    cases.forEach((code, expected) {
      test(code, () async {
        final script = _FakeScript((_) => {'ok': false, 'error': code});
        await expectLater(
          _store(script).preview(const PhotoRef(driveFileId: 'FILE123456', mimeType: 'image/jpeg')),
          throwsA(isA<PhotoException>().having((e) => e.message, 'message', contains(expected))),
        );
      });
    });
  });

  test('bez PHOTO_GATEWAY_URL: srozumitelná chyba', () async {
    final store = GatewayPhotoStore(gatewayUrl: '  ', idToken: () async => 'tok');
    await expectLater(
      store.listDrivePhotos(),
      throwsA(isA<PhotoException>().having((e) => e.message, 'message', contains('PHOTO_GATEWAY_URL'))),
    );
  });

  test('nepřihlášený uživatel: chyba místo volání brány', () async {
    final script = _FakeScript((_) => fail('nemělo se volat'));
    await expectLater(
      _store(script, token: null).listDrivePhotos(),
      throwsA(isA<PhotoException>().having((e) => e.message, 'message', contains('Nejste přihlášeni'))),
    );
    expect(script.requests, isEmpty);
  });

  test('odpověď, která není JSON (špatné nasazení), vede na návod', () async {
    final client = MockClient((_) async => http.Response('<html>Sign in</html>', 200));
    final store = GatewayPhotoStore(gatewayUrl: _gateway, idToken: () async => 'tok', client: client);
    await expectLater(
      store.listDrivePhotos(),
      throwsA(isA<PhotoException>().having((e) => e.message, 'message', contains('Kdokoli'))),
    );
  });

  test('síťová chyba se přeloží', () async {
    final client = MockClient((_) async => throw http.ClientException('Failed host lookup'));
    final store = GatewayPhotoStore(gatewayUrl: _gateway, idToken: () async => 'tok', client: client);
    await expectLater(
      store.listDrivePhotos(),
      throwsA(isA<PhotoException>().having((e) => e.message, 'message', contains('připojení'))),
    );
  });

  test('upload: špatný typ a příliš velká fotka se odmítnou ještě v telefonu', () async {
    final script = _FakeScript((_) => fail('nemělo se volat'));
    final store = _store(script);
    await expectLater(store.upload(bytes, mimeType: 'application/pdf'), throwsA(isA<PhotoException>()));
    await expectLater(
      store.upload(Uint8List(PhotoStore.maxUploadBytes + 1), mimeType: 'image/jpeg'),
      throwsA(isA<PhotoException>().having((e) => e.message, 'message', contains('velká'))),
    );
    expect(script.requests, isEmpty);
  });
}
