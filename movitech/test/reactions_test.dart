import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jimmy/features/chat/domain/message.dart';
import 'package:jimmy/features/chat/domain/reaction.dart';
import 'package:jimmy/features/chat/presentation/reaction_bar.dart';

void main() {
  test('existují právě čtyři reakce ve správném pořadí', () {
    expect(ReactionKind.values.map((k) => k.key), ['thumbs_up', 'green', 'red', 'orange']);
    expect(ReactionKind.values.map((k) => k.label), [
      'Palec nahoru',
      'Zelený čtvereček',
      'Červený čtvereček',
      'Oranžový čtvereček',
    ]);
  });

  test('parseReactions ignoruje neznámé klíče a špatné hodnoty', () {
    final r = parseReactions({
      'thumbs_up': ['a', 'b'],
      'green': 'nesmysl',
      'heart': ['x'],
      'red': [1, 'c'],
    });
    expect(r[ReactionKind.thumbsUp], ['a', 'b']);
    expect(r[ReactionKind.green], isEmpty);
    expect(r[ReactionKind.red], ['c']);
    expect(r[ReactionKind.orange], isEmpty);
    expect(r.length, 4);
  });

  test('Message.fromMap zvládne chybějící pole', () {
    final m = Message.fromMap('id', 'room', {'senderId': 'u'}, createdAt: DateTime(2026));
    expect(m.type, MessageType.text);
    expect(m.text, '');
    expect(m.photo, isNull);
    expect(m.reactions.length, 4);
  });

  test('PhotoRef.fromMap a poměr stran', () {
    final p = PhotoRef.fromMap({'driveFileId': 'f1', 'mimeType': 'image/png', 'width': 800, 'height': 400})!;
    expect(p.aspectRatio, 2.0);
    expect(PhotoRef.fromMap({'mimeType': 'x'}), isNull);
    expect(const PhotoRef(driveFileId: 'f', mimeType: 'image/jpeg').aspectRatio, closeTo(4 / 3, 0.001));
  });

  testWidgets('ReactionBar ukáže jen použité reakce a zvýrazní moji', (tester) async {
    final taps = <ReactionKind>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReactionBar(
            reactions: {
              ...emptyReactions(),
              ReactionKind.green: ['me', 'u2'],
              ReactionKind.red: ['u2'],
            },
            myUid: 'me',
            onToggle: taps.add,
          ),
        ),
      ),
    );
    expect(find.byType(ReactionButton), findsNWidgets(2));
    expect(find.text('2'), findsOneWidget);

    await tester.tap(find.byType(ReactionButton).first);
    await tester.tap(find.byType(ReactionButton).last);
    expect(taps, [ReactionKind.green, ReactionKind.red]);
  });

  testWidgets('ReactionBar(showEmpty) ukáže všechna čtyři tlačítka', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReactionBar(reactions: emptyReactions(), myUid: 'me', onToggle: (_) {}, showEmpty: true),
        ),
      ),
    );
    expect(find.byType(ReactionButton), findsNWidgets(4));
    expect(find.text('👍'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Zelený čtvereček')), findsOneWidget);
  });
}
