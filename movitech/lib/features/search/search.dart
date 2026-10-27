import 'package:diacritic/diacritic.dart';
import 'package:flutter/painting.dart' show TextRange;

import '../chat/domain/message.dart';

/// Bez diakritiky a velká/malá písmena: "Příliš" najde "prilis".
String normalizeForSearch(String s) => removeDiacritics(s).toLowerCase();

class SearchHit {
  const SearchHit(this.message, this.ranges);

  final Message message;

  /// Pozice shod v původním textu (pro zvýraznění); prázdné, pokud je nelze bezpečně určit.
  final List<TextRange> ranges;
}

/// Hledá jen v TEXTU zpráv (ne v názvech souborů, ne v reakcích).
/// Všechna zadaná slova musí ve zprávě být (AND). Nejnovější výsledky první.
List<SearchHit> searchMessages(Iterable<Message> messages, String query, {int limit = 200}) {
  final words = normalizeForSearch(query).split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  if (words.isEmpty) return const [];

  final hits = <SearchHit>[];
  for (final m in messages) {
    if (m.text.isEmpty) continue; // fotka bez popisku
    final haystack = normalizeForSearch(m.text);
    if (!words.every(haystack.contains)) continue;

    // Pozice jsou platné jen, když normalizace nezměnila délku (pro češtinu platí).
    final ranges = <TextRange>[];
    if (haystack.length == m.text.length) {
      for (final w in words) {
        for (var i = haystack.indexOf(w); i != -1; i = haystack.indexOf(w, i + w.length)) {
          ranges.add(TextRange(start: i, end: i + w.length));
        }
      }
      ranges.sort((a, b) => a.start.compareTo(b.start));
    }
    hits.add(SearchHit(m, ranges));
  }
  hits.sort((a, b) => b.message.createdAt.compareTo(a.message.createdAt));
  return hits.length > limit ? hits.sublist(0, limit) : hits;
}
