// ZÁSTUPNÝ SOUBOR. Po spuštění `flutterfire configure` ho FlutterFire přepíše
// vlastními hodnotami vašeho Firebase projektu (viz docs/SPUSTENI.md).
// Poté doporučujeme: git update-index --skip-worktree lib/firebase_options.dart
// aby se vaše konfigurace omylem nedostala do gitu.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform => throw UnsupportedError(
    'Firebase není nastavený. Spusťte "flutterfire configure" '
    '(nebo aplikaci spusťte v demo režimu: --dart-define=DEMO=true).',
  );
}
