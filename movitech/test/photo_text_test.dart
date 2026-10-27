import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:jimmy/app/backend.dart';
import 'package:jimmy/app/providers.dart';
import 'package:jimmy/features/chat/domain/message.dart';
import 'package:jimmy/features/chat/domain/reaction.dart';
import 'package:jimmy/features/chat/presentation/message_bubble.dart';
import 'package:jimmy/features/drive/photo_text.dart';
import 'package:jimmy/features/drive/presentation/photo_flow.dart';

void main() {
  setUpAll(() => initializeDateFormatting('cs'));

  group('composePhotoText', () {
    test('popisek a přepis se oddělí prázdným řádkem', () {
      expect(composePhotoText(caption: 'Rampa 3', recognized: 'Dodací list 77'), 'Rampa 3\n\nDodací list 77');
    });

    test('chybějící část se vynechá a mezery se ořežou', () {
      expect(composePhotoText(caption: '  ', recognized: ' Dodací list 77 \n'), 'Dodací list 77');
      expect(composePhotoText(caption: 'Jen popisek', recognized: ''), 'Jen popisek');
      expect(composePhotoText(caption: '', recognized: ''), '');
    });

    test('text se ořízne na 4000 znaků (limit pravidel)', () {
      final text = composePhotoText(caption: 'Popisek', recognized: 'x' * 5000);
      expect(text.length, 4000);
      expect(text, endsWith('…'));
    });
  });

  testWidgets('dialog fotky: přepis textu je výchozí, jde vypnout, popisek se vrátí', (tester) async {
    PhotoChoice? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => result = await showDialog<PhotoChoice>(
              context: context,
              builder: (_) => const PhotoConfirmDialog(preview: null),
            ),
            child: const Text('otevřít'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('otevřít'));
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value, isTrue);
    await tester.enterText(find.byType(TextField), 'Rampa 3');
    await tester.tap(find.text('Odeslat'));
    await tester.pumpAndSettle();
    expect(result?.caption, 'Rampa 3');
    expect(result?.recognizeText, isTrue);

    await tester.tap(find.text('otevřít'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(SwitchListTile));
    await tester.pump();
    await tester.tap(find.text('Odeslat'));
    await tester.pumpAndSettle();
    expect(result?.recognizeText, isFalse);
  });

  testWidgets('dlouhý přepis pod fotkou je zkrácený a jde rozbalit', (tester) async {
    late Backend backend;
    await tester.runAsync(() async => backend = await createDemoBackend(simulateTeammates: false));
    final long = List.generate(40, (i) => 'Řádek ${i + 1} dodacího listu').join('\n');
    final message = Message(
      id: 'm1',
      roomId: 'movitech',
      senderId: 'u-petr',
      type: MessageType.photo,
      text: long,
      photo: const PhotoRef(driveFileId: 'demo-seed-1', mimeType: 'image/png', width: 800, height: 600),
      reactions: emptyReactions(),
      createdAt: DateTime(2026, 10, 25, 12),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [backendProvider.overrideWithValue(backend)],
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: MessageBubble(
                message: message,
                mine: false,
                sender: null,
                showSender: true,
                myUid: 'u-me',
                onToggleReaction: (_) {},
                onLongPress: () {},
                onOpenPhoto: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Zobrazit celý text'), findsOneWidget);
    final collapsedHeight = tester.getSize(find.text(long)).height;

    await tester.ensureVisible(find.text('Zobrazit celý text'));
    await tester.tap(find.text('Zobrazit celý text'));
    await tester.pump();
    expect(find.text('Zobrazit méně'), findsOneWidget);
    expect(tester.getSize(find.text(long)).height, greaterThan(collapsedHeight * 3));
  });
}
