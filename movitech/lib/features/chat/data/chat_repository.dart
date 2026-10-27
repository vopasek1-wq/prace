import '../domain/message.dart';
import '../domain/reaction.dart';
import '../domain/room.dart';

abstract class ChatRepository {
  Stream<List<Room>> watchRooms();

  /// Nejnovější zprávy místnosti, řazené od nejnovější. Živý stream.
  Stream<List<Message>> watchMessages(String roomId, {int limit = 50});

  /// Jednorázové načtení historie pro vyhledávání (od nejnovější).
  Future<List<Message>> fetchHistory(String roomId, {int limit = 1000});

  /// Neawaitujte v UI: ve Firestore se Future dokončí až po potvrzení serverem,
  /// takže offline by se nikdy nedokončil. Zpráva se v UI ukáže hned z lokální cache.
  Future<void> sendText(String roomId, String text);

  Future<void> sendPhoto(String roomId, PhotoRef photo, {String caption = ''});

  Future<void> toggleReaction({
    required String roomId,
    required String messageId,
    required ReactionKind kind,
    required bool alreadyReacted,
  });

  /// Kdy jsem naposledy četl které místnosti (pro tečku "nepřečteno").
  Stream<Map<String, DateTime>> watchLastRead();

  Future<void> markRoomRead(String roomId);
}
