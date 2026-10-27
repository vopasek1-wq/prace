import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:jimmy/app/app.dart';
import 'package:jimmy/app/backend.dart';
import 'package:jimmy/app/providers.dart';
import 'package:jimmy/features/chat/domain/reaction.dart';
import 'package:jimmy/features/chat/presentation/reaction_bar.dart';

/// Projde celou aplikaci v demo režimu: přihlášení -> místnosti -> chat -> reakce -> hledání.
/// Název aplikace i první místnosti je "Movitech" -> místnost se hledá jen v seznamu místností.
final movitechRoom = find.descendant(of: find.byType(ListTile), matching: find.text('Movitech'));

void main() {
  late Backend backend;

  setUp(() async {
    await initializeDateFormatting('cs');
  });

  Future<void> boot(WidgetTester tester) async {
    await tester.runAsync(() async => backend = await createDemoBackend(simulateTeammates: false));
    tester.view.physicalSize = const Size(1080, 2200);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(overrides: [backendProvider.overrideWithValue(backend)], child: const MovitechApp()),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('přihlášení, seznam místností a odeslání zprávy', (tester) async {
    await boot(tester);

    expect(find.text('Vstoupit do demo režimu'), findsOneWidget);
    await tester.tap(find.text('Vstoupit do demo režimu'));
    await tester.pumpAndSettle();

    // 3 místnosti s náhledem poslední zprávy
    expect(movitechRoom, findsOneWidget);
    expect(find.text('Velké nakládky'), findsOneWidget);
    expect(find.text('Nápady'), findsOneWidget);
    expect(find.textContaining('Tomáš: Porada je v 9:30'), findsOneWidget);
    expect(find.text('📷 Fotka'), findsNothing); // fotka není poslední zpráva v Projektu A

    await tester.tap(movitechRoom);
    await tester.pumpAndSettle();
    expect(find.textContaining('Kdo zítra přinese kávu'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Ahoj z testu');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Ahoj z testu'), findsOneWidget);
    expect(
      backend.chat.watchMessages('movitech', limit: 1),
      emits(predicate((l) => (l as List).first.text == 'Ahoj z testu')),
    );
  });

  testWidgets('reakce: dlouhý stisk otevře čtyři tlačítka a klepnutí reakci přepne', (tester) async {
    await boot(tester);
    await tester.tap(find.text('Vstoupit do demo režimu'));
    await tester.pumpAndSettle();
    await tester.tap(movitechRoom);
    await tester.pumpAndSettle();

    await tester.longPress(find.textContaining('Kdo zítra přinese kávu'));
    await tester.pumpAndSettle();
    final sheetButtons = find.descendant(of: find.byType(BottomSheet), matching: find.byType(ReactionButton));
    expect(sheetButtons, findsNWidgets(4));

    // červený čtvereček
    await tester.tap(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.byWidgetPredicate((w) => w is ReactionButton && w.kind == ReactionKind.red),
      ),
    );
    await tester.pumpAndSettle();

    final msgs = await tester.runAsync(() => backend.chat.fetchHistory('movitech'));
    final coffee = msgs!.firstWhere((m) => m.text.contains('kávu'));
    expect(coffee.reactions[ReactionKind.red], ['u-me']);

    // znovu = zrušení (toggle)
    await tester.longPress(find.textContaining('Kdo zítra přinese kávu'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.byWidgetPredicate((w) => w is ReactionButton && w.kind == ReactionKind.red && w.mine),
      ),
    );
    await tester.pumpAndSettle();
    final again = await tester.runAsync(() => backend.chat.fetchHistory('movitech'));
    expect(again!.firstWhere((m) => m.text.contains('kávu')).reactions[ReactionKind.red], isEmpty);
  });

  testWidgets('hledání najde zprávu bez diakritiky a jen v textu', (tester) async {
    await boot(tester);
    await tester.tap(find.text('Vstoupit do demo režimu'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'zlutoucky kun');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.textContaining('Jana Svobodová · Movitech'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'thumbs_up');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.text('Nic nenalezeno'), findsOneWidget);
  });
}
