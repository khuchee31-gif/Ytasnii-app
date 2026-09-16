// S18 «Бүжигт хүлэг» · S19 «Хөзрөө нээе» — тестүүд (GDD-06 §S18–S19).
//
// S19-ийн ХАМГИЙН ЧУХАЛ тест: ХӨЗРИЙН ТОР БАЙХГҮЙ. Дэлгэц дээр нэг агшинд
// ганц суудал, ганц дүр. Тор гарвал зургаан шөнийн төлөөс алга болно.

import 'package:engine/engine.dart' show Ability, Role, Seat, abilityOf;
import 'package:flutter/material.dart' hide Intent;
import 'package:flutter_test/flutter_test.dart';
import 'package:hotuntlaa/game/game_controller.dart';
import 'package:hotuntlaa/screens/ceremony_screen.dart';
import 'package:hotuntlaa/screens/reveal_screen.dart' show cardCopyFor;

import 'deal_test_support.dart';

/// Өдрийн саналаар нэг хүн гарсан тоглолт.
GameController endedController({int seats = 12}) {
  final GameController c = dealtController(seats: seats);
  c.dayNo = 1;
  c.eliminate(4);
  return c;
}

String roleNameOf(GameController c, Seat s) =>
    cardCopyFor(c.roleOf(s)!).mechanic;

void main() {
  test('Эхний шөнийн хохирогч «Шөнө 1» болж бүртгэгдэнэ', () {
    final GameController c = dealtController();
    c.beginNight();
    for (final Seat s in c.circuitSeats) {
      final Ability ab = abilityOf(c.roleOf(s)!);
      if (ab == Ability.mafiaKill) {
        // Эмч юу ч хийхгүй тул хохирогч баталгаатай.
        final Seat target = c.circuitSeats.firstWhere(
          (Seat t) => c.checkTarget(s, ab, t) == null,
        );
        c.submitIntent(s, ab, target);
      } else {
        c.submitIntent(s, Ability.noAction, null);
      }
    }
    c.resolveNightNow();

    expect(c.firstOutSeats, isNotEmpty);
    expect(c.firstOutWhenMn, 'Шөнө 1');

    // Хоёр дахь хасалт эхний мөрийг ДАРЖ БИЧИХГҮЙ.
    final List<Seat> first = List<Seat>.of(c.firstOutSeats);
    c.dayNo = 1;
    c.eliminate(c.alive.first);
    expect(c.firstOutSeats, first);
    expect(c.firstOutWhenMn, 'Шөнө 1');
  });

  testWidgets('Ялалтын мөр → 3,000 мс → «Бүжигт хүлэг»', (
    WidgetTester tester,
  ) async {
    final GameController c = endedController();
    final List<String> cues = <String>[];
    await pumpScreen(
      tester,
      CeremonyScreen(
        controller: c,
        onAgain: () {},
        onLedger: () {},
        onCue: cues.add,
      ),
    );

    expect(find.text('Хотынхон ялалаа!'), findsOneWidget);
    expect(cues, <String>['WIN_TOWN']);

    await tester.pump(const Duration(milliseconds: 3100));
    expect(cues.last, 'HORSE');
    expect(find.text('Бүжигт хүлэг — ирэх удаа түрүүлээрэй.'), findsOneWidget);
    expect(find.text('№4 · Өдөр 1'), findsOneWidget);
    await tester.pump(const Duration(seconds: 25));
  });

  testWidgets('Мафи ялбал мөр нь «Мафи ялалаа!»', (WidgetTester tester) async {
    final GameController c = dealtController();
    // Зөвхөн мафи амьд үлдэв.
    c.alive = <Seat>{
      for (int s = 1; s <= 12; s++)
        if (c.roleOf(s) == Role.killer || c.roleOf(s) == Role.boss) s,
    };
    final List<String> cues = <String>[];
    await pumpScreen(
      tester,
      CeremonyScreen(
        controller: c,
        onAgain: () {},
        onLedger: () {},
        onCue: cues.add,
      ),
    );
    expect(find.text('Мафи ялалаа!'), findsOneWidget);
    expect(cues, <String>['WIN_MAFIA']);
    await tester.pump(const Duration(seconds: 25));
  });

  testWidgets('S18 нь 4.0 секунд ХААГДАХГҮЙ, дараа нь товшилтоор гарна', (
    WidgetTester tester,
  ) async {
    final GameController c = endedController();
    await pumpScreen(
      tester,
      CeremonyScreen(
        controller: c,
        onAgain: () {},
        onLedger: () {},
        startAt: CeremonyStage.horse,
      ),
    );

    await tester.tapAt(const Offset(180, 400));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Бүжигт хүлэг — ирэх удаа түрүүлээрэй.'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 3900));
    expect(find.text('Бүжигт хүлэг — ирэх удаа түрүүлээрэй.'), findsOneWidget);
    expect(find.text('Товшиж үргэлжлүүл'), findsOneWidget);

    await tester.tapAt(const Offset(180, 400));
    await tester.pump();
    expect(find.text('Хөзрөө нээе'), findsOneWidget);
    await tester.pump(const Duration(seconds: 25));
  });

  testWidgets('S18-д «ялагдал» гэсэн үг БАЙХГҮЙ', (WidgetTester tester) async {
    final GameController c = endedController();
    await pumpScreen(
      tester,
      CeremonyScreen(
        controller: c,
        onAgain: () {},
        onLedger: () {},
        startAt: CeremonyStage.horse,
      ),
    );
    expect(find.textContaining('ялагд'), findsNothing);
    await tester.pump(const Duration(seconds: 25));
  });

  testWidgets('S18 `skipped`: хэн ч хасагдаагүй бол шууд S19 руу', (
    WidgetTester tester,
  ) async {
    final GameController c = dealtController();
    final List<String> cues = <String>[];
    await pumpScreen(
      tester,
      CeremonyScreen(
        controller: c,
        onAgain: () {},
        onLedger: () {},
        onCue: cues.add,
      ),
    );
    expect(c.firstOutSeats, isEmpty);
    await tester.pump(const Duration(milliseconds: 3100));
    expect(find.textContaining('Бүжигт хүлэг'), findsNothing);
    expect(cues.contains('HORSE'), isFalse);
    expect(cues.last, 'SEAT_01');
    await tester.pump(const Duration(seconds: 25));
  });

  testWidgets('S19: суудал тутамд SEAT_nn → 400 мс → дүр → 1.2 сек зай', (
    WidgetTester tester,
  ) async {
    final GameController c = dealtController(seats: 6);
    final List<String> cues = <String>[];
    await pumpScreen(
      tester,
      CeremonyScreen(
        controller: c,
        onAgain: () {},
        onLedger: () {},
        onCue: cues.add,
        startAt: CeremonyStage.reveal,
      ),
    );

    expect(cues, <String>['REVEAL_OPEN', 'SEAT_01']);
    expect(find.text('№1'), findsOneWidget);
    expect(find.text('—'), findsOneWidget, reason: 'дүр хараахан нээгдээгүй');

    await tester.pump(const Duration(milliseconds: 450));
    expect(find.text(roleNameOf(c, 1)), findsOneWidget);
    expect(cues.contains('REVEAL_SURVIVOR'), isTrue);

    // 1.2 секундын зай — дараагийн суудал.
    await tester.pump(const Duration(milliseconds: 1000));
    expect(find.text('№1'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('№2'), findsOneWidget);
    expect(find.text('№1'), findsNothing, reason: 'тор БИШ — ганц суудал');
    expect(cues.last, 'SEAT_02');

    // Бүх суудал дуустал — REVEAL_END ба хоёр товч.
    await tester.pump(const Duration(milliseconds: 1600 * 5));
    expect(cues.last, 'REVEAL_END');
    expect(find.text('Хөзөр бүгд нээгдлээ.'), findsOneWidget);
    expect(find.text('Дахин — ижил суудлаар'), findsOneWidget);
    expect(find.text('Өнөөдрийн тэмдэглэл'), findsOneWidget);
  });

  testWidgets('S19: нэг агшинд ганцхан дүрийн нэр — ТОР ХЭЗЭЭ Ч БАЙХГҮЙ', (
    WidgetTester tester,
  ) async {
    final GameController c = dealtController(seats: 6);
    await pumpScreen(
      tester,
      CeremonyScreen(
        controller: c,
        onAgain: () {},
        onLedger: () {},
        startAt: CeremonyStage.reveal,
      ),
    );

    for (int i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 450));
      // Ямар ч агшинд суудлын дугаар ЯГ НЭГ.
      final Iterable<Widget> numbers = tester
          .widgetList<Text>(find.byType(Text))
          .where((Text t) => (t.data ?? '').startsWith('№'));
      expect(numbers.length, 1);
      await tester.pump(const Duration(milliseconds: 1150));
    }
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('S19 `paused`: товшилт зогсооно, дахин товшилт үргэлжлүүлнэ', (
    WidgetTester tester,
  ) async {
    final GameController c = dealtController(seats: 6);
    await pumpScreen(
      tester,
      CeremonyScreen(
        controller: c,
        onAgain: () {},
        onLedger: () {},
        startAt: CeremonyStage.reveal,
      ),
    );

    await tester.pump(const Duration(milliseconds: 450));
    await tester.tapAt(const Offset(180, 400));
    await tester.pump();
    expect(find.text('Түр зогсоов — товшиж үргэлжлүүл'), findsOneWidget);

    await tester.pump(const Duration(seconds: 5));
    expect(find.text('№1'), findsOneWidget, reason: 'завсарлага барьж байна');

    await tester.tapAt(const Offset(180, 400));
    await tester.pump(const Duration(milliseconds: 1300));
    expect(find.text('№2'), findsOneWidget);
    await tester.pump(const Duration(seconds: 12));
  });

  testWidgets('S19: алгасах ТОВЧ байхгүй, хоёр хуруу нь дараагийн суудал', (
    WidgetTester tester,
  ) async {
    final GameController c = dealtController(seats: 6);
    await pumpScreen(
      tester,
      CeremonyScreen(
        controller: c,
        onAgain: () {},
        onLedger: () {},
        startAt: CeremonyStage.reveal,
      ),
    );

    expect(find.text('Алгасах'), findsNothing);
    expect(find.byType(FilledButton), findsNothing);

    await tester.pump(const Duration(milliseconds: 450));
    final TestGesture a = await tester.startGesture(const Offset(120, 400));
    final TestGesture b = await tester.startGesture(const Offset(220, 400));
    await tester.pump();
    await a.moveBy(const Offset(0, 120));
    await b.moveBy(const Offset(0, 120));
    await tester.pump();
    await a.up();
    await b.up();
    await tester.pump();

    expect(find.text('№2'), findsOneWidget);
    await tester.pump(const Duration(seconds: 12));
  });

  testWidgets('S19 `done`: хоёр товч ажиллана', (WidgetTester tester) async {
    final GameController c = dealtController(seats: 6);
    int again = 0;
    int ledger = 0;
    await pumpScreen(
      tester,
      CeremonyScreen(
        controller: c,
        onAgain: () => again++,
        onLedger: () => ledger++,
        startAt: CeremonyStage.done,
      ),
    );

    await tester.tap(find.text('Дахин — ижил суудлаар'));
    await tester.pump();
    await tester.tap(find.text('Өнөөдрийн тэмдэглэл'));
    await tester.pump();
    expect(again, 1);
    expect(ledger, 1);
  });

  testWidgets('320 логик px дээр мөр халихгүй', (WidgetTester tester) async {
    final GameController c = dealtController(seats: 20);
    c.dayNo = 1;
    c.eliminate(20);
    await pumpScreen(
      tester,
      CeremonyScreen(controller: c, onAgain: () {}, onLedger: () {}),
      size: kPhoneNarrow,
    );
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(milliseconds: 3100));
    expect(tester.takeException(), isNull, reason: 'S18 халив');
    await tester.pump(const Duration(seconds: 5));
    await tester.tapAt(const Offset(160, 400));
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull, reason: 'S19 халив');
    await tester.pump(const Duration(seconds: 40));
  });
}
