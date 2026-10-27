import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/config.dart';
import '../../../firebase_options.dart';
import '../domain/app_user.dart';
import 'auth_repository.dart';

/// Přihlášení přes Google -> Firebase Auth. Google se používá jen k ověření totožnosti (žádný přístup k Disku).
/// Členství hlídá Firestore (allowlist).
class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository(this._auth, this._db, [GoogleSignIn? google]) : _google = google ?? GoogleSignIn.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;
  final GoogleSignIn _google;

  /// Volat jednou při startu aplikace.
  Future<void> init() async {
    String? iosClientId;
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      iosClientId = DefaultFirebaseOptions.currentPlatform.iosClientId;
    }
    await _google.initialize(
      clientId: iosClientId,
      serverClientId: AppConfig.googleWebClientId.isEmpty ? null : AppConfig.googleWebClientId,
    );
  }

  @override
  Stream<AppUser?> authStateChanges() => _auth.authStateChanges().map(_toUser);

  @override
  AppUser? get currentUser => _toUser(_auth.currentUser);

  AppUser? _toUser(User? u) {
    if (u == null) return null;
    final email = u.email ?? '';
    return AppUser(
      uid: u.uid,
      email: email,
      displayName: (u.displayName?.trim().isNotEmpty ?? false) ? u.displayName! : email,
      photoUrl: u.photoURL,
    );
  }

  @override
  Future<void> signIn() async {
    final GoogleSignInAccount account;
    try {
      account = await _google.authenticate();
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled || e.code == GoogleSignInExceptionCode.interrupted) {
        throw const SignInCancelledException();
      }
      if (e.code == GoogleSignInExceptionCode.clientConfigurationError ||
          e.code == GoogleSignInExceptionCode.providerConfigurationError) {
        throw StateError(
          'Přihlášení přes Google není správně nastavené (otisk SHA-1 ve Firebase, '
          'GOOGLE_WEB_CLIENT_ID v config.json, na iPhonu URL schéma). Viz docs/SPUSTENI.md, kapitola 5.4.\n$e',
        );
      }
      rethrow;
    }
    final idToken = account.authentication.idToken;
    if (idToken == null) {
      throw StateError('Google nevrátil ID token. Zkontrolujte GOOGLE_WEB_CLIENT_ID v config.json.');
    }

    final cred = await _auth.signInWithCredential(GoogleAuthProvider.credential(idToken: idToken));
    final user = cred.user!;
    try {
      // Pravidla tento zápis odmítnou, pokud e-mail není v allowlistu.
      await _db.doc('users/${user.uid}').set({
        'email': user.email,
        'displayName': user.displayName ?? user.email,
        'photoUrl': user.photoURL,
      }, SetOptions(merge: true));
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        await signOut();
        throw const NotAllowlistedException();
      }
      rethrow;
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _google.signOut();
    } catch (_) {}
    await _auth.signOut();
  }
}

class FirebaseUserDirectory implements UserDirectory {
  FirebaseUserDirectory(this._db);

  final FirebaseFirestore _db;

  @override
  Stream<Map<String, AppUser>> watchUsers() => _db.collection('users').snapshots().map((snap) {
    return {
      for (final d in snap.docs)
        d.id: AppUser(
          uid: d.id,
          email: (d.data()['email'] as String?) ?? '',
          displayName: (d.data()['displayName'] as String?) ?? (d.data()['email'] as String?) ?? '',
          photoUrl: d.data()['photoUrl'] as String?,
        ),
    };
  });
}
