import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../core/config.dart';
import '../features/auth/data/auth_repository.dart';
import '../features/auth/domain/app_user.dart';
import '../features/chat/data/chat_repository.dart';
import '../features/chat/domain/message.dart';
import '../features/chat/domain/reaction.dart';
import '../features/chat/domain/room.dart';
import '../features/drive/data/photo_store.dart';

/// Hodnota, ke které se dá připojit stream (po připojení hned dostane aktuální stav).
class _Live<T> {
  _Live(this._value);

  T _value;
  final _controller = StreamController<T>.broadcast();

  T get value => _value;

  set value(T v) {
    _value = v;
    _controller.add(v);
  }

  Stream<T> get stream async* {
    yield _value;
    yield* _controller.stream;
  }
}

/// Celý "server" v paměti telefonu: 6 členů týmu, 3 místnosti a ukázkové zprávy.
/// Slouží k vyzkoušení aplikace bez Firebase i bez Google účtu.
class DemoBackend {
  DemoBackend({this.simulateTeammates = true, DateTime? now, Random? random})
    : _now = now ?? DateTime.now(),
      _random = random ?? Random(7) {
    _seed();
  }

  /// Ostatní členové občas odpoví / zareagují, aby bylo vidět doručování "v reálném čase".
  final bool simulateTeammates;
  final DateTime _now;
  final Random _random;

  static const meUid = 'u-me';

  final List<AppUser> users = const [
    AppUser(uid: meUid, email: 'vy@demo.cz', displayName: 'Vy (demo)'),
    AppUser(uid: 'u-petr', email: 'petr@demo.cz', displayName: 'Petr Novák'),
    AppUser(uid: 'u-jana', email: 'jana@demo.cz', displayName: 'Jana Svobodová'),
    AppUser(uid: 'u-martin', email: 'martin@demo.cz', displayName: 'Martin Dvořák'),
    AppUser(uid: 'u-eva', email: 'eva@demo.cz', displayName: 'Eva Černá'),
    AppUser(uid: 'u-tomas', email: 'tomas@demo.cz', displayName: 'Tomáš Procházka'),
  ];

  final rooms = const [
    Room(id: 'movitech', name: 'Movitech', order: 0, emoji: '🏢'),
    Room(id: 'velke-nakladky', name: 'Velké nakládky', order: 1, emoji: '🚛'),
    Room(id: 'napady', name: 'Nápady', order: 2, emoji: '💡'),
  ];

  final _messages = <String, _Live<List<Message>>>{};
  final _lastRead = _Live<Map<String, DateTime>>({});
  final _signedIn = _Live<bool>(false);
  final _photos = <String, Uint8List>{};
  int _idCounter = 0;

  AppUser get me => users.first;
  bool get signedIn => _signedIn.value;

  List<Message> messagesOf(String roomId) => _messages[roomId]!.value;

  // ---------------------------------------------------------------- seed

  void _seed() {
    for (final r in rooms) {
      _messages[r.id] = _Live<List<Message>>(const []);
    }
    DateTime ago(Duration d) => _now.subtract(d);
    void add(
      String room,
      String sender,
      String text,
      Duration age, {
      Map<ReactionKind, List<String>>? react,
      PhotoRef? photo,
    }) {
      final list = [..._messages[room]!.value];
      list.insert(
        0,
        Message(
          id: 'm${_idCounter++}',
          roomId: room,
          senderId: sender,
          type: photo == null ? MessageType.text : MessageType.photo,
          text: text,
          photo: photo,
          reactions: {...emptyReactions(), ...?react},
          createdAt: ago(age),
        ),
      );
      _messages[room]!.value = list;
    }

    add(
      'movitech',
      'u-petr',
      'Dobré ráno všem! Dnes jsem v kanceláři až od desíti.',
      const Duration(days: 2, hours: 3),
    );
    add(
      'movitech',
      'u-jana',
      'Ahoj Petře, díky za info. Příliš žluťoučký kůň úpěl ďábelské ódy 🙂',
      const Duration(days: 2, hours: 2),
      react: {
        ReactionKind.thumbsUp: ['u-petr', 'u-eva'],
      },
    );
    add('movitech', 'u-martin', 'Kdo zítra přinese kávu na poradu?', const Duration(days: 1, hours: 5));
    add(
      'movitech',
      'u-eva',
      'Já! A přidám i něco sladkého.',
      const Duration(days: 1, hours: 4),
      react: {
        ReactionKind.green: ['u-martin', 'u-tomas', meUid],
      },
    );
    add('movitech', 'u-tomas', 'Porada je v 9:30, nezapomeňte prosím připravit podklady.', const Duration(hours: 3));

    add(
      'velke-nakladky',
      'u-jana',
      'Zítřejší velká nakládka je potvrzená, kamiony přijedou v 7:00.',
      const Duration(days: 3),
      react: {
        ReactionKind.green: ['u-petr', 'u-martin'],
      },
    );
    add(
      'velke-nakladky',
      'u-petr',
      'Druhý kamion má zpoždění, bude až v 9:30.',
      const Duration(days: 1, hours: 2),
      react: {
        ReactionKind.orange: ['u-jana'],
        ReactionKind.red: ['u-tomas'],
      },
    );
    add(
      'velke-nakladky',
      'u-martin',
      'Přikládám fotku nakládací rampy.',
      const Duration(hours: 6),
      photo: const PhotoRef(driveFileId: 'demo-seed-1', mimeType: 'image/png', width: 800, height: 600),
    );
    add(
      'velke-nakladky',
      'u-tomas',
      'Díky Martine, vypadá to dobře.',
      const Duration(hours: 5, minutes: 40),
      react: {
        ReactionKind.thumbsUp: [meUid],
      },
    );

    add('napady', 'u-eva', 'Co kdybychom zkusili týdenní krátký stand-up přes video?', const Duration(days: 4));
    add(
      'napady',
      'u-martin',
      'Souhlasím, ušetří nám to spoustu e-mailů.',
      const Duration(days: 4, hours: -1),
      react: {
        ReactionKind.thumbsUp: ['u-eva', 'u-jana', 'u-petr'],
      },
    );
    add('napady', 'u-jana', 'Navrhuji čtvrtek v 15:00.', const Duration(days: 3, hours: 20));

    // Čtení: "nepřečteno" ukáže poslední zprávu v Movitechu a ve Velkých nakládkách.
    _lastRead.value = {
      'napady': _now,
      'movitech': ago(const Duration(hours: 4)),
      'velke-nakladky': ago(const Duration(days: 1)),
    };
  }

  /// Vygeneruje ukázkovou fotku (barevný přechod), aby šla vyzkoušet bublina s obrázkem.
  /// Fotky ve "složce na hlavním Disku" (v demu jen vygenerované obrázky).
  final List<DrivePhotoItem> drivePhotos = [];

  Future<void> seedPhotos() async {
    _photos['demo-seed-1'] = await generateDemoImage(800, 600, const [
      Color(0xFF3F6FD8),
      Color(0xFF7AD3B0),
    ], 'Nakládka – rampa');

    const palettes = [
      [Color(0xFFEF6C00), Color(0xFFFFCC80)],
      [Color(0xFF00897B), Color(0xFF80CBC4)],
      [Color(0xFF8E24AA), Color(0xFFCE93D8)],
      [Color(0xFF3949AB), Color(0xFF9FA8DA)],
      [Color(0xFFC62828), Color(0xFFEF9A9A)],
      [Color(0xFF2E7D32), Color(0xFFA5D6A7)],
    ];
    for (var i = 0; i < palettes.length; i++) {
      final id = 'demo-drive-${i + 1}';
      final label = 'Nakládka ${i + 1}';
      _photos[id] = await generateDemoImage(800, 600, palettes[i], label);
      drivePhotos.add(
        DrivePhotoItem(
          id: id,
          name: 'nakladka-${i + 1}.png',
          mimeType: 'image/png',
          width: 800,
          height: 600,
          thumbnail: await generateDemoImage(240, 180, palettes[i], label, fontSize: 20),
        ),
      );
    }
  }

  // ---------------------------------------------------------------- operace

  Stream<List<Message>> watchMessages(String roomId, int limit) =>
      _messages[roomId]!.stream.map((l) => l.length > limit ? l.sublist(0, limit) : l);

  void send(String roomId, {required String senderId, required String text, PhotoRef? photo}) {
    final live = _messages[roomId]!;
    live.value = [
      Message(
        id: 'm${_idCounter++}',
        roomId: roomId,
        senderId: senderId,
        type: photo == null ? MessageType.text : MessageType.photo,
        text: text,
        photo: photo,
        reactions: emptyReactions(),
        createdAt: DateTime.now(),
      ),
      ...live.value,
    ];
    if (senderId == meUid && simulateTeammates) _scheduleTeammate(roomId);
  }

  void toggleReaction(String roomId, String messageId, ReactionKind kind, String uid, bool alreadyReacted) {
    final live = _messages[roomId]!;
    live.value = [
      for (final m in live.value)
        if (m.id != messageId)
          m
        else
          m.copyWith(
            reactions: {
              for (final e in m.reactions.entries)
                e.key: e.key == kind
                    ? (alreadyReacted ? e.value.where((u) => u != uid).toList() : {...e.value, uid}.toList())
                    : (AppConfig.exclusiveReactions && !alreadyReacted
                          ? e.value.where((u) => u != uid).toList()
                          : e.value),
            },
          ),
    ];
  }

  void markRead(String roomId) => _lastRead.value = {..._lastRead.value, roomId: DateTime.now()};

  Stream<Map<String, DateTime>> watchLastRead() => _lastRead.stream;

  Stream<bool> watchSignedIn() => _signedIn.stream;

  void setSignedIn(bool v) => _signedIn.value = v;

  Uint8List? photoBytes(String id) => _photos[id];

  String storePhoto(Uint8List bytes) {
    final id = 'demo-${_photos.length + 1}-${DateTime.now().microsecondsSinceEpoch}';
    _photos[id] = bytes;
    return id;
  }

  static const _replies = [
    'Super, díky!',
    'Jasně, beru na vědomí 👍',
    'Podíváme se na to po obědě.',
    'Souhlasím.',
    'To zní dobře, pojďme na to.',
    'Dám vědět, jakmile to bude hotové.',
  ];

  void _scheduleTeammate(String roomId) {
    final others = users.where((u) => u.uid != meUid).toList();
    Timer(const Duration(milliseconds: 1600), () {
      final who = others[_random.nextInt(others.length)];
      send(roomId, senderId: who.uid, text: _replies[_random.nextInt(_replies.length)]);
    });
  }

  Future<void> dispose() async {}
}

Future<Uint8List> generateDemoImage(int w, int h, List<Color> colors, String label, {double fontSize = 48}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final rect = Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble());
  canvas.drawRect(rect, Paint()..shader = ui.Gradient.linear(rect.topLeft, rect.bottomRight, colors));
  final painter = TextPainter(
    text: TextSpan(
      text: label,
      style: TextStyle(color: const Color(0xFFFFFFFF), fontSize: fontSize, fontWeight: FontWeight.w600),
    ),
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: w - fontSize * 1.7);
  painter.paint(canvas, Offset(fontSize * 0.85, h - painter.height - fontSize * 0.85));
  final image = await recorder.endRecording().toImage(w, h);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
}

// ====================================================================== wrappery

class DemoAuthRepository implements AuthRepository {
  DemoAuthRepository(this._b);
  final DemoBackend _b;

  @override
  Stream<AppUser?> authStateChanges() => _b.watchSignedIn().map((s) => s ? _b.me : null);

  @override
  AppUser? get currentUser => _b.signedIn ? _b.me : null;

  @override
  Future<void> signIn() async => _b.setSignedIn(true);

  @override
  Future<void> signOut() async => _b.setSignedIn(false);
}

class DemoUserDirectory implements UserDirectory {
  DemoUserDirectory(this._b);
  final DemoBackend _b;

  @override
  Stream<Map<String, AppUser>> watchUsers() => Stream.value({for (final u in _b.users) u.uid: u});
}

class DemoChatRepository implements ChatRepository {
  DemoChatRepository(this._b);
  final DemoBackend _b;

  @override
  Stream<List<Room>> watchRooms() => Stream.value(_b.rooms);

  @override
  Stream<List<Message>> watchMessages(String roomId, {int limit = AppConfig.pageSize}) =>
      _b.watchMessages(roomId, limit);

  @override
  Future<List<Message>> fetchHistory(String roomId, {int limit = AppConfig.searchHistoryPerRoom}) async {
    final all = _b.messagesOf(roomId);
    return all.length > limit ? all.sublist(0, limit) : all;
  }

  @override
  Future<void> sendText(String roomId, String text) async {
    final t = text.trim();
    if (t.isEmpty) return;
    _b.send(roomId, senderId: DemoBackend.meUid, text: t);
  }

  @override
  Future<void> sendPhoto(String roomId, PhotoRef photo, {String caption = ''}) async =>
      _b.send(roomId, senderId: DemoBackend.meUid, text: caption.trim(), photo: photo);

  @override
  Future<void> toggleReaction({
    required String roomId,
    required String messageId,
    required ReactionKind kind,
    required bool alreadyReacted,
  }) async => _b.toggleReaction(roomId, messageId, kind, DemoBackend.meUid, alreadyReacted);

  @override
  Stream<Map<String, DateTime>> watchLastRead() => _b.watchLastRead();

  @override
  Future<void> markRoomRead(String roomId) async => _b.markRead(roomId);
}

class DemoPhotoStore implements PhotoStore {
  DemoPhotoStore(this._b);
  final DemoBackend _b;

  static const _sampleText =
      'Nakládací list č. 2024/118\nTrasa: Praha – Brno\nHmotnost: 18,4 t\nVykládka do 14:00\n'
      '(ukázkový přepis – v demo režimu se text z fotky nerozpoznává doopravdy)';

  @override
  Future<PhotoUpload> upload(
    Uint8List bytes, {
    required String mimeType,
    int? width,
    int? height,
    bool recognizeText = false,
  }) async => PhotoUpload(
    PhotoRef(driveFileId: _b.storePhoto(bytes), mimeType: mimeType, width: width, height: height),
    text: recognizeText ? _sampleText : '',
  );

  @override
  Future<String> recognizeText(PhotoRef ref) async => _sampleText;

  @override
  Future<DrivePage> listDrivePhotos({String? pageToken}) async => DrivePage(_b.drivePhotos, null);

  @override
  Future<PhotoRef> attachDrivePhoto(DrivePhotoItem item) async =>
      PhotoRef(driveFileId: item.id, mimeType: item.mimeType, width: item.width, height: item.height);

  @override
  Future<Uint8List> preview(PhotoRef ref) async =>
      _b.photoBytes(ref.driveFileId) ?? (throw const PhotoException('Fotka v demo režimu už neexistuje'));

  @override
  Future<Uint8List> full(PhotoRef ref) => preview(ref);
}
