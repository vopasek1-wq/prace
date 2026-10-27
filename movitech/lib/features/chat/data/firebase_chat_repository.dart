import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/config.dart';
import '../domain/message.dart';
import '../domain/reaction.dart';
import '../domain/room.dart';
import 'chat_repository.dart';

class FirebaseChatRepository implements ChatRepository {
  FirebaseChatRepository(this._db, this._auth);

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  String get _uid => _auth.currentUser!.uid;

  CollectionReference<Map<String, dynamic>> _messages(String roomId) => _db.collection('rooms/$roomId/messages');

  @override
  Stream<List<Room>> watchRooms() => _db.collection('rooms').orderBy('order').snapshots().map((snap) {
    return [
      for (final d in snap.docs)
        Room(
          id: d.id,
          name: (d.data()['name'] as String?) ?? d.id,
          order: (d.data()['order'] as num?)?.toInt() ?? 0,
          emoji: d.data()['emoji'] as String?,
        ),
    ];
  });

  Message _parse(String roomId, QueryDocumentSnapshot<Map<String, dynamic>> d) {
    final data = d.data();
    // Čerstvě odeslaná zpráva má createdAt == null, dokud ho nedoplní server.
    final created = (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
    return Message.fromMap(d.id, roomId, data, createdAt: created, pending: d.metadata.hasPendingWrites);
  }

  @override
  Stream<List<Message>> watchMessages(String roomId, {int limit = AppConfig.pageSize}) =>
      _messages(roomId)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .snapshots(includeMetadataChanges: true)
          .map((snap) => [for (final d in snap.docs) _parse(roomId, d)]);

  @override
  Future<List<Message>> fetchHistory(String roomId, {int limit = AppConfig.searchHistoryPerRoom}) async {
    final snap = await _messages(roomId).orderBy('createdAt', descending: true).limit(limit).get();
    return [for (final d in snap.docs) _parse(roomId, d)];
  }

  Map<String, Object?> _base(String type, String text, PhotoRef? photo) => {
    'senderId': _uid,
    'type': type,
    'text': text,
    'photo': photo?.toMap(),
    'reactions': reactionsToMap(emptyReactions()),
    'createdAt': FieldValue.serverTimestamp(),
  };

  @override
  Future<void> sendText(String roomId, String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return Future.value();
    // ID vytvořené v klientovi: zápis je idempotentní a funguje offline.
    return _messages(roomId).doc().set(_base('text', trimmed, null));
  }

  @override
  Future<void> sendPhoto(String roomId, PhotoRef photo, {String caption = ''}) =>
      _messages(roomId).doc().set(_base('photo', caption.trim(), photo));

  @override
  Future<void> toggleReaction({
    required String roomId,
    required String messageId,
    required ReactionKind kind,
    required bool alreadyReacted,
  }) {
    final uid = _uid;
    return _messages(roomId).doc(messageId).update({
      'reactions.${kind.key}': alreadyReacted ? FieldValue.arrayRemove([uid]) : FieldValue.arrayUnion([uid]),
      if (AppConfig.exclusiveReactions && !alreadyReacted)
        for (final other in ReactionKind.values.where((o) => o != kind))
          'reactions.${other.key}': FieldValue.arrayRemove([uid]),
    });
  }

  @override
  Stream<Map<String, DateTime>> watchLastRead() => _db.doc('users/$_uid').snapshots().map((snap) {
    final raw = snap.data()?['lastReadAt'];
    if (raw is! Map) return <String, DateTime>{};
    return {
      for (final e in raw.entries)
        if (e.value is Timestamp) '${e.key}': (e.value as Timestamp).toDate(),
    };
  });

  @override
  Future<void> markRoomRead(String roomId) => _db.doc('users/$_uid').set({
    'lastReadAt': {roomId: FieldValue.serverTimestamp()},
  }, SetOptions(merge: true));
}
