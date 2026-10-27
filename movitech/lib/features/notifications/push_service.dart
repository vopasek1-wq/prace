import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Push notifikace (FCM). Zapíná se přes ENABLE_PUSH=true v config.json.
/// Potřebuje nasazenou Cloud Function (functions/) a na iOS placený Apple Developer účet.
class PushService {
  PushService(this._db);

  final FirebaseFirestore _db;
  StreamSubscription<String>? _refreshSub;
  StreamSubscription<RemoteMessage>? _openedSub;
  String? _uid;

  /// Zavolá se s roomId, když uživatel klepne na notifikaci.
  void Function(String roomId)? onOpenRoom;

  /// Zavolá se, když přijde zpráva, zatímco je aplikace otevřená.
  void Function(String title, String body)? onForeground;

  Future<void> start(String uid) async {
    if (_uid == uid) return;
    _uid = uid;
    try {
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;
      // ignore: deprecated_member_use
      final token = await messaging.getToken();
      if (token != null) await _saveToken(uid, token);
      // ignore: deprecated_member_use
      _refreshSub = messaging.onTokenRefresh.listen((t) => _saveToken(uid, t));
      _openedSub = FirebaseMessaging.onMessageOpenedApp.listen((m) => _open(m));
      FirebaseMessaging.onMessage.listen((m) {
        final n = m.notification;
        if (n != null) onForeground?.call(n.title ?? '', n.body ?? '');
      });
      final initial = await messaging.getInitialMessage();
      if (initial != null) _open(initial);
    } catch (e) {
      // Bez APNs klíče (iOS) nebo bez povolení push nefunguje; aplikace funguje dál.
      debugPrint('Push notifikace se nespustily: $e');
    }
  }

  void _open(RemoteMessage m) {
    final roomId = m.data['roomId'];
    if (roomId is String && roomId.isNotEmpty) onOpenRoom?.call(roomId);
  }

  Future<void> _saveToken(String uid, String token) => _db.doc('users/$uid').set({
    'fcmTokens': FieldValue.arrayUnion([token]),
  }, SetOptions(merge: true));

  Future<void> stop() async {
    await _refreshSub?.cancel();
    await _openedSub?.cancel();
    _refreshSub = null;
    _openedSub = null;
    _uid = null;
  }
}
