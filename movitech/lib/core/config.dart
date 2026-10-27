/// Konfigurace aplikace. Hodnoty se předávají při spuštění přes
/// `--dart-define-from-file=config.json` (vzor: config.example.json).
class AppConfig {
  const AppConfig._();

  /// Demo režim: žádný Firebase, žádný Google účet, data jsou jen v paměti telefonu.
  static const bool demo = bool.fromEnvironment('DEMO');

  /// "Web client ID" z Firebase Console -> Authentication -> Google. Nutné pro Android.
  static const String googleWebClientId = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');

  /// Adresa nasazené brány pro fotky (Apps Script, hlavní Google Disk). Viz docs/SPUSTENI.md, kapitola 5.3.
  static const String photoGatewayUrl = String.fromEnvironment('PHOTO_GATEWAY_URL');

  /// Push notifikace (potřebují Blaze plán, Cloud Function a na iOS placený Apple účet).
  static const bool enablePush = bool.fromEnvironment('ENABLE_PUSH');

  /// true = uživatel může mít na zprávě jen jednu reakci, false = libovolně mnoho.
  static const bool exclusiveReactions = bool.fromEnvironment('EXCLUSIVE_REACTIONS');

  static const int maxMessageLength = 4000;
  static const int pageSize = 50;

  /// Kolik posledních zpráv z každé místnosti se načte pro vyhledávání.
  static const int searchHistoryPerRoom = 1000;
}
