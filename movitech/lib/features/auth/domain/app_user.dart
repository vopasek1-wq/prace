/// Přihlášený uživatel nebo profil člena týmu (načítá se z `users/{uid}`).
class AppUser {
  const AppUser({required this.uid, required this.email, required this.displayName, this.photoUrl});

  final String uid;
  final String email;
  final String displayName;
  final String? photoUrl;

  /// Křestní jméno pro krátké náhledy ("Jana: ahoj").
  String get shortName {
    final trimmed = displayName.trim();
    if (trimmed.isEmpty) return email;
    return trimmed.split(RegExp(r'\s+')).first;
  }

  String get initial {
    final t = displayName.trim();
    return t.isEmpty ? '?' : String.fromCharCode(t.runes.first).toUpperCase();
  }
}
