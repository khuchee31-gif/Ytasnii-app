// S13 — Өдрийн дэлгэцийн тестүүд (GDD-06 §S13, GDD-08 §2 ба §6).
//
// Энэ дэлгэцийн ХАМГИЙН ЧУХАЛ тест нь ЮУ БОЛОХГҮЙГ шалгадаг: цагирган дээрх
// товшилт үг хэлэгчийг ХЭЗЭЭ Ч сольдоггүй.

import 'package:engine/engine.dart' show Seat;
import 'package:flutter/material.dart' hide Intent;
import 'package:flutter_test/flutter_test.dart';
import 'package:hotuntlaa/game/game_controller.dart';
import 'package:hotuntlaa/screens/day_screen.dart';
import 'package:hotuntlaa/ui/tokens.dart';

import 'deal_test_support.dart';

GameController dayController({
  int seats = 12,
  int day = 1,
  Set<Seat>? alive,
  Seat? lastEliminated,
}) {
  final GameController c = dealtController(seats: seats);
  c.dayNo = day;
  if (alive != null) c.alive = alive;
  c.lastEliminated = lastEliminated;
  return c;
}

String speakerOf(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const Key('speakerNumber'))).data!;

/// Доод 45 %-ын дунд цэг (720×1600 @ dpr 2 = 360×800 логик px).
const Offset kInPinZone = Offset(180, 700);

/// Цагирагны дунд — ЭНД товшилт юу ч хийхгүй.
const Offset kOnRing = Offset(180, 250);

void main() {
  testWidgets('Гурван давхарга: Тооны самбар, үг хэлэгчийн цагираг, 📌', (
    WidgetTester tester,
  ) async {
    final GameController c = dayController();
    await pumpScreen(tester, DayScreen(controller: c, onVote: () {}));

    expect(find.text('Алдаж болох санал'), findsOneWidget);
    expect(find.text('Тэмдэглэ'), findsOneWidget);
    // Өдөр 1 — №1-ээс эхэлнэ (GDD-01 §1, №11).
    expect(speakerOf(tester), '1');

    await tester.pump(const Duration(seconds: 45));
  });

  testWidgets('Үгийн тойрог сүүлд хасагдсаны ДАРААГИЙН суудлаас эхэлнэ', (
    WidgetTester tester,
  ) async {
    final GameController c = dayController(
      day: 2,
      alive: <Seat>{1, 2, 3, 5, 6, 7, 8, 9, 10, 11, 12},
      lastEliminated: 4,
    );
    await pumpScreen(tester, DayScreen(controller: c, onVote: () {}));
    expect(speakerOf(tester), '5');
    await tester.pump(const Duration(seconds: 45));
  });

  testWidgets('Доод 45 % нь 📌-ийн хүрэх талбай, дээд хэсэг нь БИШ', (
    WidgetTester tester,
  ) async {
    final GameController c = dayController();
    await pumpScreen(tester, DayScreen(controller: c, onVote: () {}));

    final Size zone = tester.getSize(find.byKey(const Key('pinZone')));
    expect(
      zone.height,
      greaterThan(300),
      reason: '800 логик px-ийн 45 % = 360',
    );
    expect(zone.height, closeTo(800 * 0.45, 40));
    expect(zone.height, greaterThanOrEqualTo(kMinTouch));

    // Цагирган дээрх товшилт — ЮУ Ч БОЛОХГҮЙ, ХЭЗЭЭ Ч.
    await tester.tapAt(kOnRing);
    await tester.pump();
    expect(c.pins, isEmpty);
    expect(speakerOf(tester), '1');

    // Доод 45 %-д алгадав — 📌.
    await tester.tapAt(kInPinZone);
    await tester.pump();
    expect(c.pins.length, 1);
    expect(c.pins.first.speaker, 1);
    expect(c.pins.first.dayNo, 1);
    expect(find.text('Тэмдэглэлээ (1)'), findsOneWidget);

    // 900 мс анивчаад буцна.
    await tester.pump(const Duration(milliseconds: 950));
    expect(find.text('Тэмдэглэ'), findsOneWidget);
    await tester.pump(const Duration(seconds: 45));
  });

  testWidgets('📌 нь 4 секундэд НЭГ — хоёр гар зэрэг цохих нь нэг тэмдэглэл', (
    WidgetTester tester,
  ) async {
    final GameController c = dayController();
    await pumpScreen(tester, DayScreen(controller: c, onVote: () {}));

    await tester.tapAt(kInPinZone);
    await tester.pump();
    await tester.tapAt(kInPinZone);
    await tester.pump(const Duration(seconds: 2));
    await tester.tapAt(kInPinZone);
    await tester.pump();
    expect(c.pins.length, 1, reason: '4 секунд болоогүй');

    await tester.pump(const Duration(seconds: 3));
    await tester.tapAt(kInPinZone);
    await tester.pump();
    expect(c.pins.length, 2);
    await tester.pump(const Duration(seconds: 45));
  });

  testWidgets('Тоглолтод 12 — дараа нь «Хангалттай тэмдэглэлээ.»', (
    WidgetTester tester,
  ) async {
    final GameController c = dayController();
    for (int i = 0; i < 12; i++) {
      c.addPin(i * 5000, 1);
    }
    await pumpScreen(tester, DayScreen(controller: c, onVote: () {}));

    await tester.tapAt(kInPinZone);
    await tester.pump();
    expect(c.pins.length, 12);
    expect(find.text('Хангалттай тэмдэглэлээ.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 45));
  });

  testWidgets('📌 нь ХЭН дарсныг бүртгэхгүй — зөвхөн {өдөр, mm:ss, суудал}', (
    WidgetTester tester,
  ) async {
    final GameController c = dayController(
      day: 2,
      alive: <Seat>{1, 2, 3, 5},
      lastEliminated: 4,
    );
    await pumpScreen(tester, DayScreen(controller: c, onVote: () {}));

    await tester.pump(const Duration(seconds: 6));
    await tester.tapAt(kInPinZone);
    await tester.pump();

    final ({int dayNo, int elapsedMs, Seat speaker}) pin = c.pins.single;
    expect(pin.dayNo, 2);
    expect(pin.elapsedMs, 6000);
    expect(pin.speaker, 5);
    // Бүтэц нь яг гурван талбар — «хэн дарав» гэсэн талбар БАЙХГҮЙ.
    expect(mmss(pin.elapsedMs ~/ 1000), '0:06');
    await tester.pump(const Duration(seconds: 45));
  });

  testWidgets(
    'Гурван чимээ: UI_WARN_30 · UI_TICK_10 · UI_BELL, хоолой БАЙХГҮЙ',
    (WidgetTester tester) async {
      final GameController c = dayController();
      final List<String> cues = <String>[];
      await pumpScreen(
        tester,
        DayScreen(controller: c, onVote: () {}, onCue: cues.add),
      );

      expect(cues, <String>['DISCUSS_START']);

      // `speechSeconds` = 40 (Сонгодог).
      await tester.pump(const Duration(seconds: 10));
      expect(cues.last, 'UI_WARN_30');
      await tester.pump(const Duration(seconds: 20));
      expect(cues.last, 'UI_TICK_10');
      await tester.pump(const Duration(seconds: 10));
      expect(cues.last, 'UI_BELL');
      expect(
        speakerOf(tester),
        '2',
        reason: 'хонх → автоматаар дараагийн суудал',
      );

      // Хоолойн клип нэг ч байхгүй.
      expect(cues.any((String s) => s.startsWith('SEAT_')), isFalse);
      expect(cues.any((String s) => s.startsWith('DAY_')), isFalse);
      await tester.pump(const Duration(seconds: 45));
    },
  );

  testWidgets('Цагирган дээр баруун тийш шудрах — дараагийн үг хэлэгч', (
    WidgetTester tester,
  ) async {
    final GameController c = dayController();
    await pumpScreen(tester, DayScreen(controller: c, onVote: () {}));

    await tester.fling(
      find.byKey(const Key('speakerRing')),
      const Offset(200, 0),
      800,
    );
    await tester.pump();
    expect(speakerOf(tester), '2');

    // Зүүн тийш шудрах нь буцаахгүй — ганц чиглэл.
    await tester.fling(
      find.byKey(const Key('speakerRing')),
      const Offset(-200, 0),
      800,
    );
    await tester.pump();
    expect(speakerOf(tester), '2');
    await tester.pump(const Duration(seconds: 45));
  });

  testWidgets('Хоёр хуруугаар доош шудрах — «Санал хураая»', (
    WidgetTester tester,
  ) async {
    final GameController c = dayController();
    int votes = 0;
    await pumpScreen(tester, DayScreen(controller: c, onVote: () => votes++));

    final TestGesture a = await tester.startGesture(const Offset(120, 300));
    final TestGesture b = await tester.startGesture(const Offset(220, 300));
    await tester.pump();
    await a.moveBy(const Offset(0, 120));
    await b.moveBy(const Offset(0, 120));
    await tester.pump();
    await a.up();
    await b.up();
    await tester.pump();

    expect(votes, 1);
    await tester.pump(const Duration(seconds: 45));
  });

  testWidgets('Нэг хуруугаар доош шудрах нь санал хураалт НЭЭХГҮЙ', (
    WidgetTester tester,
  ) async {
    final GameController c = dayController();
    int votes = 0;
    await pumpScreen(tester, DayScreen(controller: c, onVote: () => votes++));

    await tester.fling(
      find.byKey(const Key('speakerRing')),
      const Offset(0, 200),
      800,
    );
    await tester.pump();
    expect(votes, 0);
    await tester.pump(const Duration(seconds: 45));
  });

  testWidgets('Дээд мөрөнд товшихад сануулга 3 секунд гарна', (
    WidgetTester tester,
  ) async {
    final GameController c = dayController();
    await pumpScreen(tester, DayScreen(controller: c, onVote: () {}));

    expect(c.pips, 2);
    await tester.tapAt(const Offset(180, 30));
    await tester.pump();
    expect(
      find.text('Алдаж болох санал: 2. Хоёр хотынхныг хөөвөл мафи ялна.'),
      findsOneWidget,
    );

    await tester.pump(const Duration(seconds: 4));
    expect(
      find.text('Алдаж болох санал: 2. Хоёр хотынхныг хөөвөл мафи ялна.'),
      findsNothing,
    );
    await tester.pump(const Duration(seconds: 45));
  });

  testWidgets('b = 0 — улаан мөр ба UI_BASS_B0 нэг удаа', (
    WidgetTester tester,
  ) async {
    // 12 суудал, b₀ = 2 → Өдөр 3-т `pipsForDay` = 0.
    final GameController c = dayController(day: 3);
    final List<String> cues = <String>[];
    await pumpScreen(
      tester,
      DayScreen(controller: c, onVote: () {}, onCue: cues.add),
    );

    expect(c.pips, 0);
    expect(cues.first, 'UI_BASS_B0');
    expect(cues.where((String s) => s == 'UI_BASS_B0').length, 1);
    expect(find.text('Нэг л буруу санал — ялагдал.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 45));
  });

  testWidgets('Хөдөлгөөн багасгах: цагираг → «0:40», харанхуйлалт УНТАРНА', (
    WidgetTester tester,
  ) async {
    final GameController c = dayController();
    c.settings.reduceMotion = true;
    await pumpScreen(tester, DayScreen(controller: c, onVote: () {}));

    expect(find.text('0:40'), findsOneWidget);
    await tester.pump(const Duration(seconds: 20));
    expect(find.text('0:20'), findsOneWidget);

    // Гэрэл мэдрэг хүнд харанхуйлалт байхгүй — хар давхарга гарахгүй.
    expect(find.byKey(const Key('dimVeil')), findsNothing);
    await tester.pump(const Duration(seconds: 45));
  });

  testWidgets('15 секунд тутамд харанхуйлна, доод хязгаар 40 %', (
    WidgetTester tester,
  ) async {
    final GameController c = dayController();
    await pumpScreen(tester, DayScreen(controller: c, onVote: () {}));

    expect(find.byKey(const Key('dimVeil')), findsNothing);
    await tester.pump(const Duration(seconds: 16));
    expect(find.byKey(const Key('dimVeil')), findsOneWidget);

    // Хязгаарт хүрсэн ч 📌 ажиллах ёстой — давхарга оролт залгидаггүй.
    await tester.pump(const Duration(seconds: 150));
    await tester.tapAt(kInPinZone);
    await tester.pump();
    expect(c.pins, isNotEmpty);
    await tester.pump(const Duration(seconds: 45));
  });

  testWidgets('Бүх суудал ярьсны дараа «Чөлөөт хэлэлцүүлэг», 📌 хэвээр', (
    WidgetTester tester,
  ) async {
    final GameController c = dayController(alive: <Seat>{1, 2});
    await pumpScreen(tester, DayScreen(controller: c, onVote: () {}));

    await tester.pump(const Duration(seconds: 81));
    expect(find.text('Чөлөөт хэлэлцүүлэг'), findsOneWidget);

    await tester.tapAt(kInPinZone);
    await tester.pump();
    expect(c.pins.length, 1);
    await tester.pump(const Duration(seconds: 45));
  });

  testWidgets('320 логик px дээр мөр халихгүй', (WidgetTester tester) async {
    final GameController c = dayController(seats: 20, day: 1);
    await pumpScreen(
      tester,
      DayScreen(controller: c, onVote: () {}),
      size: kPhoneNarrow,
    );
    expectNoOverflow(tester);
    await tester.tapAt(const Offset(160, 600));
    await tester.pump(const Duration(seconds: 20));
    expectNoOverflow(tester);
    await tester.pump(const Duration(seconds: 45));
  });
}

void expectNoOverflow(WidgetTester tester) {
  expect(tester.takeException(), isNull, reason: 'Дэлгэц халив');
}
