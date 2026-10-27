import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../app/widgets.dart';
import '../../../core/format.dart';
import '../../../core/strings.dart';

/// Hledání v textu zpráv (ne v názvech souborů, ne v reakcích).
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key, this.initialRoomId});

  final String? initialRoomId;

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;
  String _query = '';
  String? _roomId;

  @override
  void initState() {
    super.initState();
    _roomId = widget.initialRoomId;
    // Index je starší než pár minut -> načíst znovu, ať jsou v něm nové zprávy.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final corpus = ref.read(searchCorpusProvider).value;
      if (corpus != null && DateTime.now().difference(corpus.loadedAt) > const Duration(minutes: 3)) {
        ref.invalidate(searchCorpusProvider);
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (mounted) setState(() => _query = value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final rooms = ref.watch(roomsProvider).value ?? const [];
    final users = ref.watch(usersProvider).value ?? const {};
    final corpus = ref.watch(searchCorpusProvider);
    final hits = ref.watch(searchHitsProvider((query: _query, roomId: _roomId)));
    final scheme = Theme.of(context).colorScheme;
    final roomNames = {for (final r in rooms) r.id: r.name};

    Widget results;
    if (corpus.hasError) {
      results = ErrorView(
        message: '${S.genericError}\n${corpus.error}',
        onRetry: () => ref.invalidate(searchCorpusProvider),
      );
    } else if (corpus.isLoading && !corpus.hasValue) {
      results = const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [CircularProgressIndicator(), SizedBox(height: 12), Text(S.searchLoading)],
        ),
      );
    } else if (_query.trim().isEmpty) {
      results = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(S.searchPrompt),
              const SizedBox(height: 8),
              Text(
                '${S.searchTooltip}\n${S.searchLimitNote}',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      );
    } else if (hits.isEmpty) {
      results = const Center(child: Text(S.searchNothing));
    } else {
      results = ListView.separated(
        itemCount: hits.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, i) {
          final hit = hits[i];
          final m = hit.message;
          final sender = users[m.senderId]?.displayName ?? S.unknownUser;
          return ListTile(
            title: Text('$sender · ${roomNames[m.roomId] ?? m.roomId}', style: Theme.of(context).textTheme.labelLarge),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text.rich(
                TextSpan(
                  children: highlightSpans(
                    m.text,
                    hit.ranges,
                    base: Theme.of(context).textTheme.bodyMedium!,
                    highlight: TextStyle(
                      backgroundColor: scheme.tertiaryContainer,
                      color: scheme.onTertiaryContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            trailing: Text(formatDateTime(m.createdAt), style: Theme.of(context).textTheme.labelSmall),
            isThreeLine: true,
            onTap: () => context.push('/rooms/${m.roomId}'),
          );
        },
      );
    }

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.search,
          onChanged: _onChanged,
          decoration: InputDecoration(
            hintText: S.searchHint,
            suffixIcon: _controller.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      _controller.clear();
                      setState(() => _query = '');
                    },
                  ),
          ),
        ),
      ),
      body: Column(
        children: [
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: const Text(S.searchAll),
                    selected: _roomId == null,
                    onSelected: (_) => setState(() => _roomId = null),
                  ),
                ),
                for (final r in rooms)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(r.name),
                      selected: _roomId == r.id,
                      onSelected: (_) => setState(() => _roomId = r.id),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(child: results),
        ],
      ),
    );
  }
}

/// Rozdělí text na obyčejné a zvýrazněné části podle (i překrývajících se) shod.
List<TextSpan> highlightSpans(
  String text,
  List<TextRange> ranges, {
  required TextStyle base,
  required TextStyle highlight,
  int context = 40,
}) {
  if (ranges.isEmpty) return [TextSpan(text: text, style: base)];

  // sloučení překrývajících se shod
  final merged = <TextRange>[];
  for (final r in [...ranges]..sort((a, b) => a.start.compareTo(b.start))) {
    if (merged.isNotEmpty && r.start <= merged.last.end) {
      final last = merged.removeLast();
      merged.add(TextRange(start: last.start, end: r.end > last.end ? r.end : last.end));
    } else {
      merged.add(r);
    }
  }

  final windowStart = (merged.first.start - context).clamp(0, text.length);
  final spans = <TextSpan>[];
  if (windowStart > 0) spans.add(TextSpan(text: '…', style: base));
  var cursor = windowStart;
  for (final r in merged) {
    if (r.end <= cursor) continue;
    final start = r.start < cursor ? cursor : r.start;
    if (start > cursor) spans.add(TextSpan(text: text.substring(cursor, start), style: base));
    spans.add(TextSpan(text: text.substring(start, r.end), style: highlight));
    cursor = r.end;
  }
  if (cursor < text.length) spans.add(TextSpan(text: text.substring(cursor), style: base));
  return spans;
}
