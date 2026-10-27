import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../app/widgets.dart';
import '../../../core/format.dart';
import '../../../core/strings.dart';
import '../../chat/domain/room.dart';

class RoomListScreen extends ConsumerWidget {
  const RoomListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rooms = ref.watch(roomsProvider);
    final me = ref.watch(currentUserProvider);
    final isDemo = ref.watch(backendProvider).isDemo;

    return Scaffold(
      appBar: AppBar(
        title: const Text(S.appName),
        actions: [
          IconButton(tooltip: S.search, icon: const Icon(Icons.search), onPressed: () => context.push('/search')),
          PopupMenuButton<String>(
            tooltip: '',
            onSelected: (v) {
              if (v == 'signout') ref.read(backendProvider).auth.signOut();
            },
            itemBuilder: (_) => [
              PopupMenuItem<String>(
                enabled: false,
                child: Text('${S.signedInAs}\n${me?.email ?? ''}', style: Theme.of(context).textTheme.bodySmall),
              ),
              const PopupMenuItem<String>(value: 'signout', child: Text(S.signOut)),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          if (isDemo) const DemoBanner(),
          Expanded(
            child: rooms.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) =>
                  ErrorView(message: '${S.genericError}\n$e', onRetry: () => ref.invalidate(roomsProvider)),
              data: (list) {
                if (list.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(S.noRooms, style: TextStyle(fontWeight: FontWeight.w600)),
                          SizedBox(height: 8),
                          Text(S.noRoomsHint, textAlign: TextAlign.center),
                        ],
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const Divider(height: 1, indent: 76),
                  itemBuilder: (_, i) => _RoomTile(room: list[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _RoomTile extends ConsumerWidget {
  const _RoomTile({required this.room});

  final Room room;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final last = ref.watch(lastMessageProvider(room.id)).value;
    final lastRead = ref.watch(lastReadProvider).value?[room.id];
    final users = ref.watch(usersProvider).value ?? const {};
    final me = ref.watch(currentUserProvider);

    final unread =
        last != null &&
        last.senderId != me?.uid &&
        !last.pending &&
        (lastRead == null || last.createdAt.isAfter(lastRead));

    String subtitle;
    if (last == null) {
      subtitle = S.noMessagesYet;
    } else {
      final who = last.senderId == me?.uid ? S.you : (users[last.senderId]?.shortName ?? S.unknownUser);
      subtitle = '$who: ${last.preview}';
    }

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: scheme.secondaryContainer,
        child: Text(room.avatarText, style: const TextStyle(fontSize: 22)),
      ),
      title: Text(room.name, style: TextStyle(fontWeight: unread ? FontWeight.w700 : FontWeight.w500)),
      subtitle: Text(
        subtitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontWeight: unread ? FontWeight.w600 : FontWeight.w400,
          fontStyle: last == null ? FontStyle.italic : FontStyle.normal,
          color: unread ? scheme.onSurface : scheme.onSurfaceVariant,
        ),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (last != null) Text(formatRoomTime(last.createdAt), style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 6),
          if (unread)
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: scheme.primary, shape: BoxShape.circle),
            ),
        ],
      ),
      onTap: () => context.push('/rooms/${room.id}'),
    );
  }
}
