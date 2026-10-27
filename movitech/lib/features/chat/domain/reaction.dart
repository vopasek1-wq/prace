/// Čtyři povolené reakce. `key` je stabilní identifikátor uložený ve Firestore
/// (ne emoji), takže vzhled lze měnit bez migrace dat.
enum ReactionKind {
  thumbsUp('thumbs_up', '👍', 'Palec nahoru'),
  green('green', '🟩', 'Zelený čtvereček'),
  red('red', '🟥', 'Červený čtvereček'),
  orange('orange', '🟧', 'Oranžový čtvereček');

  const ReactionKind(this.key, this.emoji, this.label);

  final String key;
  final String emoji;
  final String label;

  static ReactionKind? fromKey(String key) {
    for (final k in ReactionKind.values) {
      if (k.key == key) return k;
    }
    return null;
  }
}

/// Reakce na jedné zprávě: druh -> seznam uid uživatelů, kteří ho zvolili.
typedef Reactions = Map<ReactionKind, List<String>>;

Reactions emptyReactions() => {for (final k in ReactionKind.values) k: <String>[]};

Reactions parseReactions(Object? raw) {
  final result = emptyReactions();
  if (raw is Map) {
    for (final entry in raw.entries) {
      final kind = ReactionKind.fromKey('${entry.key}');
      final value = entry.value;
      if (kind != null && value is List) {
        result[kind] = value.whereType<String>().toList();
      }
    }
  }
  return result;
}

Map<String, List<String>> reactionsToMap(Reactions r) => {
  for (final e in r.entries) e.key.key: List<String>.of(e.value),
};
