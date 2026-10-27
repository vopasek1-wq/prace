class Room {
  const Room({required this.id, required this.name, required this.order, this.emoji});

  final String id;
  final String name;
  final int order;
  final String? emoji;

  String get avatarText {
    final e = emoji;
    if (e != null && e.isNotEmpty) return e;
    return name.isEmpty ? '?' : String.fromCharCode(name.runes.first).toUpperCase();
  }
}
