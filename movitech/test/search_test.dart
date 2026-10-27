import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jimmy/features/chat/domain/message.dart';
import 'package:jimmy/features/chat/domain/reaction.dart';
import 'package:jimmy/features/search/presentation/search_screen.dart' show highlightSpans;
import 'package:jimmy/features/search/search.dart';

Message msg(String id, String text, {MessageType type = MessageType.text, PhotoRef? photo, int minutesAgo = 0}) =>
    Message(
      id: id,
      roomId: 'r',
      senderId: 'u',
      type: type,
      text: text,
      photo: photo,
      reactions: emptyReactions(),
      createdAt: DateTime(2026, 10, 25, 12).subtract(Duration(minutes: minutesAgo)),
    );

void main() {
  test('normalizace odstraní diakritiku a velikost písmen', () {
    expect(normalizeForSearch('Příliš ŽLUŤOUČKÝ kůň'), 'prilis zlutoucky kun');
  });

  test('najde zprávu bez ohledu na diakritiku', () {
    final hits = searchMessages([msg('1', 'Příliš žluťoučký kůň'), msg('2', 'něco jiného')], 'prilis');
    expect(hits.map((h) => h.message.id), ['1']);
  });

  test('všechna slova musí být ve zprávě (AND), v libovolném pořadí', () {
    final messages = [msg('1', 'Porada je v 9:30'), msg('2', 'Porada zítra'), msg('3', 'v 9:30 snídaně')];
    expect(searchMessages(messages, 'porada 9:30').map((h) => h.message.id), ['1']);
    expect(searchMessages(messages, '9:30 porada').map((h) => h.message.id), ['1']);
  });

  test('prázdný dotaz nic nevrací', () {
    expect(searchMessages([msg('1', 'ahoj')], '   '), isEmpty);
  });

  test('hledá jen v textu: fotka bez popisku se nenajde, popisek ano', () {
    const photo = PhotoRef(driveFileId: 'abc-soubor', mimeType: 'image/jpeg');
    final messages = [
      msg('1', '', type: MessageType.photo, photo: photo),
      msg('2', 'výkres střechy', type: MessageType.photo, photo: photo),
    ];
    expect(searchMessages(messages, 'abc'), isEmpty); // ID souboru se nehledá
    expect(searchMessages(messages, 'střechy').map((h) => h.message.id), ['2']);
  });

  test('reakce se nehledají', () {
    final m = msg('1', 'ahoj').copyWith(
      reactions: {
        ...emptyReactions(),
        ReactionKind.thumbsUp: ['u1'],
      },
    );
    expect(searchMessages([m], 'thumbs'), isEmpty);
    expect(searchMessages([m], '👍'), isEmpty);
  });

  test('výsledky jsou od nejnovějšího', () {
    final hits = searchMessages([msg('old', 'káva', minutesAgo: 60), msg('new', 'káva', minutesAgo: 1)], 'kava');
    expect(hits.map((h) => h.message.id), ['new', 'old']);
  });

  test('pozice shod odpovídají původnímu textu', () {
    final hit = searchMessages([msg('1', 'Dobrý den, Příliš dobrý')], 'prilis').single;
    expect(hit.ranges.single, const TextRange(start: 11, end: 17));
    expect('Dobrý den, Příliš dobrý'.substring(11, 17), 'Příliš');
  });

  test('zvýraznění spojí překrývající se shody a ořízne dlouhý začátek', () {
    const base = TextStyle();
    const hl = TextStyle(fontWeight: FontWeight.bold);
    final text = '${'x' * 100} auto automat';
    final ranges = searchMessages([msg('1', text)], 'auto automat').single.ranges;
    final spans = highlightSpans(text, ranges, base: base, highlight: hl);
    expect(spans.first.text, '…');
    expect(spans.where((s) => s.style == hl).map((s) => s.text).join(), contains('auto'));
    expect(spans.map((s) => s.text).join().endsWith('automat'), isTrue);
  });
}
