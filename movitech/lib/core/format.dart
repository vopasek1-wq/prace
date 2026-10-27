import 'package:intl/intl.dart';

import 'strings.dart';

bool isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

String formatClock(DateTime t) => DateFormat.Hm('cs').format(t);

/// Oddělovač dní v chatu: "Dnes", "Včera", "pátek 24. října".
String formatDayLabel(DateTime d, {DateTime? now}) {
  final n = now ?? DateTime.now();
  final today = DateTime(n.year, n.month, n.day);
  final day = DateTime(d.year, d.month, d.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return S.today;
  if (diff == 1) return S.yesterday;
  final pattern = d.year == n.year ? 'EEEE d. MMMM' : 'd. MMMM y';
  return DateFormat(pattern, 'cs').format(d);
}

/// Čas u náhledu místnosti: dnes hodiny, včera "Včera", jinak datum.
String formatRoomTime(DateTime d, {DateTime? now}) {
  final n = now ?? DateTime.now();
  if (isSameDay(d, n)) return formatClock(d);
  final diff = DateTime(n.year, n.month, n.day).difference(DateTime(d.year, d.month, d.day)).inDays;
  if (diff == 1) return S.yesterday;
  return DateFormat('d. M.', 'cs').format(d);
}

/// Datum + čas pro výsledky vyhledávání.
String formatDateTime(DateTime d) => DateFormat('d. M. y  HH:mm', 'cs').format(d);
