import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/domain/app_user.dart';
import '../features/chat/domain/message.dart';
import '../features/chat/domain/room.dart';
import '../features/search/search.dart';
import 'backend.dart';

/// Přepisuje se v main() hotovým `Backend`.
final backendProvider = Provider<Backend>((ref) => throw UnimplementedError('backendProvider není přepsaný'));

final authStateProvider = StreamProvider<AppUser?>((ref) => ref.watch(backendProvider).auth.authStateChanges());

/// Přihlášený uživatel (null, dokud není známý).
final currentUserProvider = Provider<AppUser?>((ref) => ref.watch(authStateProvider).value);

final roomsProvider = StreamProvider<List<Room>>((ref) {
  ref.watch(currentUserProvider);
  return ref.watch(backendProvider).chat.watchRooms();
});

/// Všech (max. 6) členů týmu podle uid.
final usersProvider = StreamProvider<Map<String, AppUser>>((ref) {
  ref.watch(currentUserProvider);
  return ref.watch(backendProvider).users.watchUsers();
});

typedef RoomQuery = ({String roomId, int limit});

final messagesProvider = StreamProvider.autoDispose.family<List<Message>, RoomQuery>((ref, q) {
  return ref.watch(backendProvider).chat.watchMessages(q.roomId, limit: q.limit);
});

/// Poslední zpráva místnosti pro náhled v seznamu místností.
final lastMessageProvider = StreamProvider.autoDispose.family<Message?, String>((ref, roomId) {
  return ref.watch(backendProvider).chat.watchMessages(roomId, limit: 1).map((l) => l.isEmpty ? null : l.first);
});

final lastReadProvider = StreamProvider<Map<String, DateTime>>((ref) {
  ref.watch(currentUserProvider);
  return ref.watch(backendProvider).chat.watchLastRead();
});

/// Texty zpráv všech místností pro vyhledávání. Drží se po dobu běhu aplikace;
/// obrazovka hledání ho obnoví, pokud je starší než pár minut.
class SearchCorpus {
  const SearchCorpus(this.messages, this.loadedAt);
  final List<Message> messages;
  final DateTime loadedAt;
}

final searchCorpusProvider = FutureProvider<SearchCorpus>((ref) async {
  final chat = ref.watch(backendProvider).chat;
  final rooms = await ref.watch(roomsProvider.future);
  final all = <Message>[];
  for (final r in rooms) {
    all.addAll(await chat.fetchHistory(r.id));
  }
  return SearchCorpus(all, DateTime.now());
});

final searchHitsProvider = Provider.family<List<SearchHit>, ({String query, String? roomId})>((ref, q) {
  final corpus = ref.watch(searchCorpusProvider).value;
  if (corpus == null) return const [];
  final messages = q.roomId == null ? corpus.messages : corpus.messages.where((m) => m.roomId == q.roomId);
  return searchMessages(messages, q.query);
});
