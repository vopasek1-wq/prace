import '../domain/app_user.dart';

class SignInCancelledException implements Exception {
  const SignInCancelledException();
}

/// Účet je v Googlu v pořádku, ale není v `allowlist` (max. 6 lidí).
class NotAllowlistedException implements Exception {
  const NotAllowlistedException();
}

abstract class AuthRepository {
  /// Aktuálně přihlášený uživatel (null = odhlášen). Emituje hned po startu.
  Stream<AppUser?> authStateChanges();

  AppUser? get currentUser;

  Future<void> signIn();

  Future<void> signOut();
}

/// Seznam všech členů týmu (jména, e-maily) – jen 6 dokumentů, drží se v paměti.
abstract class UserDirectory {
  Stream<Map<String, AppUser>> watchUsers();
}
