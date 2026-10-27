@TestOn('vm')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:jimmy/features/chat/domain/message.dart';
import 'package:jimmy/features/drive/data/gateway_photo_store.dart';
import 'package:jimmy/features/drive/data/photo_store.dart';

/// Skutečný klient proti skutečnému kódu brány (gateway/Code.gs), který běží v Node.js
/// za HTTP serverem napodobujícím přesměrování Apps Scriptu. Vyžaduje nainstalovaný Node.js.
String _jwt(String email) {
  String enc(Object o) => base64Url.encode(utf8.encode(jsonEncode(o))).replaceAll('=', '');
  return '${enc({'alg': 'none', 'typ': 'JWT'})}.${enc({'sub': 'u1', 'user_id': 'u1', 'email': email, 'email_verified': true})}.';
}

Future<bool> _hasNode() async {
  try {
    return (await Process.run('node', ['--version'])).exitCode == 0;
  } on ProcessException {
    return false;
  }
}

void main() {
  late Process server;
  late String url;
  var nodeAvailable = false;

  setUpAll(() async {
    nodeAvailable = await _hasNode();
    if (!nodeAvailable) return;
    server = await Process.start(
      'node',
      ['backend-tests/fake-gateway-server.mjs'],
      environment: {'ALLOWED_EMAILS': 'a@gmail.com,b@gmail.com'},
    );
    final port = Completer<int>();
    server.stdout.transform(utf8.decoder).listen((chunk) {
      final m = RegExp(r'PORT (\d+)').firstMatch(chunk);
      if (m != null && !port.isCompleted) port.complete(int.parse(m.group(1)!));
    });
    server.stderr.transform(utf8.decoder).listen((e) => stderr.write(e));
    url = 'http://127.0.0.1:${await port.future.timeout(const Duration(seconds: 20))}/exec';
  });

  tearDownAll(() {
    if (nodeAvailable) server.kill();
  });

  GatewayPhotoStore store(String? email) =>
      GatewayPhotoStore(gatewayUrl: url, idToken: () async => email == null ? null : _jwt(email));

  test('člen vidí fotky ze složky na Disku, nejnovější první, s náhledy', () async {
    if (!nodeAvailable) markTestSkipped('Node.js není nainstalovaný');
    final page = await store('a@gmail.com').listDrivePhotos();
    expect(page.items.map((i) => i.name), ['rucni-foto-3.jpg', 'rucni-foto-2.jpg', 'rucni-foto-1.jpg']);
    expect(utf8.decode(page.items.first.thumbnail!), startsWith('THUMB-'));
    expect(page.items.first.width, 800);
    expect(page.nextPageToken, isNull);
  }, skip: false);

  test('nahrání a stažení druhým členem (jiná instance, bez sdílené cache)', () async {
    if (!nodeAvailable) return;
    final photo = Uint8List.fromList(List.generate(5000, (i) => i % 256));
    final ref = (await store('a@gmail.com').upload(photo, mimeType: 'image/png', width: 10, height: 20)).photo;

    final other = store('b@gmail.com');
    expect(await other.full(ref), photo);
    expect(utf8.decode(await other.preview(ref)), 'THUMB-${ref.driveFileId}-1080');

    final list = await other.listDrivePhotos();
    expect(list.items.first.id, ref.driveFileId); // nově nahraná je nahoře
  });

  test('výběr existující fotky ze složky', () async {
    if (!nodeAvailable) return;
    final s = store('b@gmail.com');
    final item = (await s.listDrivePhotos()).items.last;
    final ref = await s.attachDrivePhoto(item);
    expect(utf8.decode(await s.full(ref)), 'seed-1');
  });

  test('přepis textu z fotky při nahrání i dodatečně', () async {
    if (!nodeAvailable) return;
    final s = store('a@gmail.com');
    // "Fotka" obsahuje text; falešný Disk ho vrátí jako OCR (skutečné OCR dělá Google Disk).
    final withText = Uint8List.fromList(utf8.encode('TEXT:Nakládací list č. 5\nTrasa: Praha – Brno'));

    final upload = await s.upload(withText, mimeType: 'image/png', recognizeText: true);
    expect(upload.text, 'Nakládací list č. 5\nTrasa: Praha – Brno');
    expect(upload.ocrFailed, isFalse);

    final noOcr = await s.upload(withText, mimeType: 'image/png');
    expect(noOcr.text, '');
    expect(await s.recognizeText(noOcr.photo), 'Nakládací list č. 5\nTrasa: Praha – Brno');

    final plain = await s.upload(Uint8List.fromList([1, 2, 3]), mimeType: 'image/png', recognizeText: true);
    expect(plain.text, '');
  });

  test('cizí účet (není na seznamu) dostane srozumitelné odmítnutí', () async {
    if (!nodeAvailable) return;
    await expectLater(
      store('x@gmail.com').listDrivePhotos(),
      throwsA(isA<PhotoException>().having((e) => e.message, 'message', contains('nemá přístup'))),
    );
    await expectLater(
      store('x@gmail.com').upload(Uint8List.fromList([1, 2, 3]), mimeType: 'image/jpeg'),
      throwsA(isA<PhotoException>()),
    );
  });

  test('soubor, který na Disku není, nebo cizí ID', () async {
    if (!nodeAvailable) return;
    await expectLater(
      store('a@gmail.com').full(const PhotoRef(driveFileId: 'NeexistujiciId1234567', mimeType: 'image/jpeg')),
      throwsA(isA<PhotoException>().having((e) => e.message, 'message', contains('už na Disku není'))),
    );
  });

  test('špatná adresa brány vede na návod k nasazení', () async {
    if (!nodeAvailable) return;
    final bad = GatewayPhotoStore(
      gatewayUrl: url.replaceAll('/exec', '/jina-cesta'),
      idToken: () async => _jwt('a@gmail.com'),
    );
    await expectLater(
      bad.listDrivePhotos(),
      throwsA(isA<PhotoException>().having((e) => e.message, 'message', contains('Kdokoli'))),
    );
  });
}
