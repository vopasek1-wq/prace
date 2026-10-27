import 'reaction.dart';

/// Odkaz na fotku uloženou na Google Disku (nebo v paměti v demo režimu).
class PhotoRef {
  const PhotoRef({required this.driveFileId, required this.mimeType, this.width, this.height});

  final String driveFileId;
  final String mimeType;
  final int? width;
  final int? height;

  double get aspectRatio {
    final w = width;
    final h = height;
    if (w == null || h == null || w <= 0 || h <= 0) return 4 / 3;
    return (w / h).clamp(0.5, 2.5);
  }

  Map<String, Object?> toMap() => {'driveFileId': driveFileId, 'mimeType': mimeType, 'width': width, 'height': height};

  static PhotoRef? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['driveFileId'];
    if (id is! String) return null;
    return PhotoRef(
      driveFileId: id,
      mimeType: raw['mimeType'] is String ? raw['mimeType'] as String : 'image/jpeg',
      width: (raw['width'] as num?)?.toInt(),
      height: (raw['height'] as num?)?.toInt(),
    );
  }

  @override
  bool operator ==(Object other) => other is PhotoRef && other.driveFileId == driveFileId;

  @override
  int get hashCode => driveFileId.hashCode;
}

enum MessageType { text, photo }

class Message {
  const Message({
    required this.id,
    required this.roomId,
    required this.senderId,
    required this.type,
    required this.text,
    required this.reactions,
    required this.createdAt,
    this.photo,
    this.pending = false,
  });

  final String id;
  final String roomId;
  final String senderId;
  final MessageType type;

  /// Text zprávy. U fotky je to nepovinný popisek (může být prázdný). Hledá se jen v tomto poli.
  final String text;
  final PhotoRef? photo;
  final Reactions reactions;
  final DateTime createdAt;

  /// true, dokud server zprávu nepotvrdí (offline / odesílání).
  final bool pending;

  bool reactedBy(ReactionKind kind, String uid) => reactions[kind]?.contains(uid) ?? false;

  /// Krátký text do náhledu místnosti.
  String get preview => type == MessageType.photo ? (text.isEmpty ? '📷 Fotka' : '📷 $text') : text;

  factory Message.fromMap(
    String id,
    String roomId,
    Map<String, dynamic> data, {
    required DateTime createdAt,
    bool pending = false,
  }) {
    final isPhoto = data['type'] == 'photo';
    return Message(
      id: id,
      roomId: roomId,
      senderId: (data['senderId'] as String?) ?? '',
      type: isPhoto ? MessageType.photo : MessageType.text,
      text: (data['text'] as String?) ?? '',
      photo: PhotoRef.fromMap(data['photo']),
      reactions: parseReactions(data['reactions']),
      createdAt: createdAt,
      pending: pending,
    );
  }

  Message copyWith({Reactions? reactions, bool? pending}) => Message(
    id: id,
    roomId: roomId,
    senderId: senderId,
    type: type,
    text: text,
    photo: photo,
    reactions: reactions ?? this.reactions,
    createdAt: createdAt,
    pending: pending ?? this.pending,
  );
}
