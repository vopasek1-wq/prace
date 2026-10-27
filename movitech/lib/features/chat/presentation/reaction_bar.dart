import 'package:flutter/material.dart';

import '../domain/reaction.dart';

/// Barvy čtverečků (přibližně jako emoji 🟩 🟥 🟧). Čtverečky se kreslí, ne píšou
/// emoji: 🟩🟥🟧 jsou z Unicode 12 a na Androidu 9 a starším by se zobrazil prázdný znak.
const _squareColors = {
  ReactionKind.green: Color(0xFF77B255),
  ReactionKind.red: Color(0xFFDD2E44),
  ReactionKind.orange: Color(0xFFF4900C),
};

/// Tlačítka čtyř reakcí. Pod bublinou se ukazují jen použité reakce (`showEmpty: false`),
/// v nabídce po dlouhém stisku všechny čtyři (`showEmpty: true`).
class ReactionBar extends StatelessWidget {
  const ReactionBar({
    super.key,
    required this.reactions,
    required this.myUid,
    required this.onToggle,
    this.showEmpty = false,
    this.large = false,
  });

  final Reactions reactions;
  final String myUid;
  final void Function(ReactionKind kind) onToggle;
  final bool showEmpty;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final kinds = ReactionKind.values.where((k) => showEmpty || (reactions[k]?.isNotEmpty ?? false));
    return Wrap(
      spacing: large ? 12 : 6,
      runSpacing: 4,
      children: [
        for (final k in kinds)
          ReactionButton(
            kind: k,
            count: reactions[k]?.length ?? 0,
            mine: reactions[k]?.contains(myUid) ?? false,
            large: large,
            onTap: () => onToggle(k),
          ),
      ],
    );
  }
}

class ReactionButton extends StatelessWidget {
  const ReactionButton({
    super.key,
    required this.kind,
    required this.count,
    required this.mine,
    required this.onTap,
    this.large = false,
  });

  final ReactionKind kind;
  final int count;
  final bool mine;
  final VoidCallback onTap;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final glyphSize = large ? 30.0 : 16.0;
    // Všechny značky mají stejně velký rámeček, aby tlačítka byla stejně vysoká.
    final Widget glyph = SizedBox.square(
      dimension: glyphSize * 1.2,
      child: Center(
        child: kind == ReactionKind.thumbsUp
            ? Text('👍', style: TextStyle(fontSize: glyphSize, height: 1))
            : Container(
                width: glyphSize,
                height: glyphSize,
                decoration: BoxDecoration(
                  color: _squareColors[kind],
                  borderRadius: BorderRadius.circular(glyphSize * 0.2),
                ),
              ),
      ),
    );

    return Semantics(
      button: true,
      selected: mine,
      label:
          '${kind.label}, ${count == 0 ? 'bez reakcí' : '$count'}, ${mine ? 'vy jste reagovali' : 'nereagovali jste'}',
      child: ExcludeSemantics(
        child: Material(
          color: mine ? scheme.primaryContainer : scheme.surfaceContainerHighest,
          shape: StadiumBorder(side: BorderSide(color: mine ? scheme.primary : Colors.transparent, width: 1.5)),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: onTap,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: large ? 16 : 10, vertical: large ? 12 : 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  glyph,
                  if (count > 0) ...[
                    const SizedBox(width: 6),
                    Text(
                      '$count',
                      style: TextStyle(fontSize: large ? 16 : 13, fontWeight: FontWeight.w600),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
