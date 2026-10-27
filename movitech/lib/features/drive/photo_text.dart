/// Text zprávy s fotkou = popisek + přepis textu z fotky (max. 4000 znaků, tolik povolují pravidla).
String composePhotoText({required String caption, required String recognized, int maxLength = 4000}) {
  final parts = [caption.trim(), recognized.trim()].where((p) => p.isNotEmpty).toList();
  final joined = parts.join('\n\n');
  if (joined.length <= maxLength) return joined;
  return '${joined.substring(0, maxLength - 1).trimRight()}…';
}
