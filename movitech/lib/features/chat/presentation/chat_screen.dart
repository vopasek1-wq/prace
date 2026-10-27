import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../app/widgets.dart';
import '../../../core/config.dart';
import '../../../core/format.dart';
import '../../../core/strings.dart';
import '../../drive/presentation/photo_flow.dart';
import '../domain/message.dart';
import '../domain/reaction.dart';
import 'composer.dart';
import 'message_bubble.dart';
import 'reaction_bar.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.roomId});

  final String roomId;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _scroll = ScrollController();
  int _limit = AppConfig.pageSize;
  List<Message> _previous = const [];
  String? _lastMarkedId;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _markRead());
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  RoomQuery get _query => (roomId: widget.roomId, limit: _limit);

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final pos = _scroll.position;
    if (pos.pixels >= pos.maxScrollExtent - 300) {
      final loaded = ref.read(messagesProvider(_query)).value;
      if (loaded != null && loaded.length >= _limit) {
        setState(() => _limit += AppConfig.pageSize);
      }
    }
  }

  void _markRead() {
    if (!mounted) return;
    unawaited(ref.read(backendProvider).chat.markRoomRead(widget.roomId).catchError((Object _) {}));
  }

  void _send(String text) {
    // Záměrně bez await: ve Firestore se Future dokončí až po potvrzení serverem.
    ref.read(backendProvider).chat.sendText(widget.roomId, text).catchError((Object e) {
      if (mounted) showSnack(context, '${S.sendFailed}: $e');
    });
  }

  void _toggle(Message m, ReactionKind kind) {
    final me = ref.read(currentUserProvider);
    if (me == null) return;
    ref
        .read(backendProvider)
        .chat
        .toggleReaction(roomId: widget.roomId, messageId: m.id, kind: kind, alreadyReacted: m.reactedBy(kind, me.uid))
        .catchError((Object e) {
          if (mounted) showSnack(context, S.reactionFailed);
        });
  }

  Future<void> _openReactionSheet(Message m) async {
    final me = ref.read(currentUserProvider);
    if (me == null) return;
    HapticFeedback.selectionClick();
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(S.reactTitle, style: Theme.of(sheetContext).textTheme.titleMedium),
              const SizedBox(height: 12),
              Center(
                child: ReactionBar(
                  reactions: m.reactions,
                  myUid: me.uid,
                  showEmpty: true,
                  large: true,
                  onToggle: (kind) {
                    Navigator.of(sheetContext).pop();
                    _toggle(m, kind);
                  },
                ),
              ),
              if (m.text.isNotEmpty) ...[
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.copy_rounded),
                  title: const Text(S.copy),
                  onTap: () async {
                    await Clipboard.setData(ClipboardData(text: m.text));
                    if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                    if (mounted) showSnack(context, S.copied);
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rooms = ref.watch(roomsProvider).value;
    final roomName = rooms?.where((r) => r.id == widget.roomId).firstOrNull?.name ?? '';
    final me = ref.watch(currentUserProvider);
    final users = ref.watch(usersProvider).value ?? const {};
    final isDemo = ref.watch(backendProvider).isDemo;

    final async = ref.watch(messagesProvider(_query));
    if (async.hasValue) _previous = async.requireValue;
    final messages = async.value ?? _previous;

    // Nová zpráva v otevřené místnosti = hned přečtená.
    ref.listen(messagesProvider(_query), (_, next) {
      final list = next.value;
      if (list != null && list.isNotEmpty && list.first.id != _lastMarkedId) {
        _lastMarkedId = list.first.id;
        _markRead();
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(roomName),
        actions: [
          IconButton(
            tooltip: S.search,
            icon: const Icon(Icons.search),
            onPressed: () => context.push('/search?room=${widget.roomId}'),
          ),
        ],
      ),
      body: Column(
        children: [
          if (isDemo) const DemoBanner(),
          Expanded(child: _buildList(context, async, messages, me?.uid ?? '', users)),
          Composer(onSend: _send, onAttach: () => pickAndSendPhoto(context, ref, widget.roomId)),
        ],
      ),
    );
  }

  Widget _buildList(
    BuildContext context,
    AsyncValue<List<Message>> async,
    List<Message> messages,
    String myUid,
    Map<String, dynamic> users,
  ) {
    if (async.hasError && messages.isEmpty) {
      return ErrorView(
        message: '${S.genericError}\n${async.error}',
        onRetry: () => ref.invalidate(messagesProvider(_query)),
      );
    }
    if (async.isLoading && messages.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (messages.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(S.emptyChat, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
        ),
      );
    }

    return ListView.builder(
      controller: _scroll,
      reverse: true,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: messages.length,
      itemBuilder: (context, i) {
        final m = messages[i];
        final older = i + 1 < messages.length ? messages[i + 1] : null;
        final newDay = older == null || !isSameDay(older.createdAt, m.createdAt);
        final mine = m.senderId == myUid;
        final showSender = newDay || older.senderId != m.senderId;
        return Column(
          children: [
            if (newDay) _DayDivider(date: m.createdAt),
            MessageBubble(
              key: ValueKey(m.id),
              message: m,
              mine: mine,
              sender: users[m.senderId],
              showSender: showSender,
              myUid: myUid,
              onToggleReaction: (k) => _toggle(m, k),
              onLongPress: () => _openReactionSheet(m),
              onOpenPhoto: (p) => context.push('/photo', extra: p),
            ),
          ],
        );
      },
    );
  }
}

class _DayDivider extends StatelessWidget {
  const _DayDivider({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(color: scheme.surfaceContainerHigh, borderRadius: BorderRadius.circular(12)),
          child: Text(formatDayLabel(date), style: Theme.of(context).textTheme.labelMedium),
        ),
      ),
    );
  }
}
