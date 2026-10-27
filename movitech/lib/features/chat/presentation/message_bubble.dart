import 'package:flutter/material.dart';

import '../../../app/widgets.dart';
import '../../../core/format.dart';
import '../../../core/strings.dart';
import '../../auth/domain/app_user.dart';
import '../../drive/presentation/drive_image.dart';
import '../domain/message.dart';
import '../domain/reaction.dart';
import 'reaction_bar.dart';

class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    required this.mine,
    required this.sender,
    required this.showSender,
    required this.myUid,
    required this.onToggleReaction,
    required this.onLongPress,
    required this.onOpenPhoto,
  });

  final Message message;
  final bool mine;
  final AppUser? sender;
  final bool showSender;
  final String myUid;
  final void Function(ReactionKind kind) onToggleReaction;
  final VoidCallback onLongPress;
  final void Function(PhotoRef photo) onOpenPhoto;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final bubbleColor = mine ? scheme.primaryContainer : scheme.surfaceContainerHighest;
    final onBubble = mine ? scheme.onPrimaryContainer : scheme.onSurface;
    final maxWidth = MediaQuery.sizeOf(context).width * 0.78;
    final photo = message.photo;
    final hasText = message.text.isNotEmpty;

    final bubble = GestureDetector(
      onLongPress: onLongPress,
      child: Container(
        constraints: BoxConstraints(maxWidth: maxWidth),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(mine ? 18 : 4),
            bottomRight: Radius.circular(mine ? 4 : 18),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showSender && !mine)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: Text(
                  sender?.displayName ?? '…',
                  style: theme.textTheme.labelMedium?.copyWith(color: scheme.primary, fontWeight: FontWeight.w700),
                ),
              ),
            if (photo != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: SizedBox(
                  width: maxWidth,
                  child: DriveImage(photo: photo, onTap: () => onOpenPhoto(photo)),
                ),
              ),
            if (hasText)
              Padding(
                padding: EdgeInsets.fromLTRB(12, photo != null ? 8 : (showSender && !mine ? 2 : 8), 12, 0),
                child: _BubbleText(
                  text: message.text,
                  style: theme.textTheme.bodyLarge?.copyWith(color: onBubble),
                  // Přepis textu z fotky bývá dlouhý -> ve výchozím stavu zkrácený.
                  collapsible: photo != null && message.text.length > 240,
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 2, 10, 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    formatClock(message.createdAt),
                    style: theme.textTheme.labelSmall?.copyWith(color: onBubble.withValues(alpha: 0.65)),
                  ),
                  if (message.pending) ...[
                    const SizedBox(width: 4),
                    Icon(Icons.schedule, size: 12, color: onBubble.withValues(alpha: 0.65)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );

    final hasReactions = message.reactions.values.any((l) => l.isNotEmpty);

    return Padding(
      padding: EdgeInsets.fromLTRB(8, showSender ? 6 : 1, 8, 1),
      child: Row(
        mainAxisAlignment: mine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!mine) SizedBox(width: 36, child: showSender ? UserAvatar(user: sender, radius: 14) : null),
          Flexible(
            child: Column(
              crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                bubble,
                if (hasReactions)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: ReactionBar(reactions: message.reactions, myUid: myUid, onToggle: onToggleReaction),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Text zprávy; u dlouhého přepisu z fotky ukáže jen začátek a "Zobrazit celý text".
class _BubbleText extends StatefulWidget {
  const _BubbleText({required this.text, required this.style, required this.collapsible});

  final String text;
  final TextStyle? style;
  final bool collapsible;

  @override
  State<_BubbleText> createState() => _BubbleTextState();
}

class _BubbleTextState extends State<_BubbleText> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final collapsed = widget.collapsible && !_expanded;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.text,
          style: widget.style,
          maxLines: collapsed ? 6 : null,
          overflow: collapsed ? TextOverflow.ellipsis : TextOverflow.clip,
        ),
        if (widget.collapsible)
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                _expanded ? S.showLess : S.showMore,
                style: widget.style?.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
