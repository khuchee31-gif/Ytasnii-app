// S12 — Шилдэг нүүдлийн тестүүд (GDD-06 §S12, GDD-00-ийн татгалзал).
//
// Хамгийн чухал тест нь ЮУ БАЙХГҮЙГ шалгадаг: оноо байхгүй, тэмдэг байхгүй,
// «зөв/буруу» гэсэн үг байхгүй, хянагчид хадгалагдсан сонголт байхгүй.
// Гурван дугаар нь виджетийн төлөвт амьдарч, дэлгэц хаагдахад ҮХНЭ.

import 'package:engine/engine.dart';
import 'package:flutter/material.dart' hide Intent;
import 'package:flutter_test/flutter_test.dart';
import 'package:hotuntlaa/game/game_controller.dart';
import 'package:hotuntlaa/screens/best_move_screen.dart';
import 'package:hotuntlaa/ui/tokens.dart';

import 'deal_test_support.dart';
import 'night_test_support.dart';

/// Эхний хохирогчтой тоглолт — S12 зөвхөн түүнд олдоно.
GameController afterFirstKill({int seats = 12}) {
  final GameController c = nightController(seats: seats);
  final Seat doctor = seatWithAbility(c, Ability.heal);
  final Seat victim = <Seat>[1, 2, 3].firstWhere((Seat s) => s != doctor);
  resolveWholeNight(c, target: (Seat seat, Ability a) {
    if (a == Ability.mafiaKill) return victim;
    if (a == Ability.heal) return doctor;
    return null;
  });
  return c;
}

void main() {
  test('Зөвхөн эхний хохирогч, зөвхөн НЭГ УДАА', () {
    final GameController c = nightController();
    expect(BestMoveScreen.isDue(c), isFalse, reason: 'хохирогч хараахан байхгүй');

    final GameController d = afterFirstKill();
    expect(d.firstVictim, isNotNull);
    expect(BestMoveScreen.isDue(d), isTrue);

    d.bestMoveSpoken = true;
    expect(BestMoveScreen.isDue(d), isFalse, reason: 'хоёр дахь удаа БАЙХГҮЙ');

    d.bestMoveSpoken = false;
    d.settings.bestMove = false;
    expect(BestMoveScreen.isDue(d), isFalse, reason: '«Шинэ тоглогч» багц');
  });

  testWidgets('«Шилдэг нүүдэл — 20 секунд. Гурван дугаар сонго.»',
      (WidgetTester tester) async {
    final GameController c = afterFirstKill();
    final List<String> cues = <String>[];
    await pumpScreen(tester,
        BestMoveScreen(controller: c, onDone: () {}, onCue: cues.add));

    expect(find.text('Шилдэг нүүдэл — 20 секунд. Гурван дугаар сонго.'),
        findsOneWidget);
    expect(cues, <String>['BESTMOVE_START']);
    // Хохирогч өөрөө торонд БАЙХГҮЙ — тор нь амьд суудлынх.
    expect(find.text('${c.firstVictim}'), findsNothing);

    await tester.pump(const Duration(seconds: 21));
  });

  testWidgets('Гурав сонгогдмогц «Уншуулах» асна — 20 секунд ХҮЛЭЭХГҮЙ',
      (WidgetTester tester) async {
    final GameController c = afterFirstKill();
    final List<Seat> alive = c.alive.toList()..sort();
    final List<String> cues = <String>[];
    await pumpScreen(tester,
        BestMoveScreen(controller: c, onDone: () {}, onCue: cues.add));

    Finder readButton() => find.widgetWithText(FilledButton, 'Уншуулах');
    expect(tester.widget<FilledButton>(readButton()).onPressed, isNull);

    for (int i = 0; i < 2; i++) {
      await tester.tap(find.text('${alive[i]}'));
      await tester.pump();
    }
    expect(tester.widget<FilledButton>(readButton()).onPressed, isNull,
        reason: 'хоёр дугаар хангалтгүй');

    await tester.tap(find.text('${alive[2]}'));
    await tester.pump();
    expect(tester.widget<FilledButton>(readButton()).onPressed, isNotNull);

    // Дөрөв дэх сонголт байхгүй — үлдсэн торны нүд бүдгэрнэ.
    await tester.tap(find.text('${alive[3]}'));
    await tester.pump();

    await tester.tap(readButton());
    await tester.pump();

    expect(cues, <String>['BESTMOVE_START', 'BESTMOVE_READ']);
    expect(c.bestMoveSpoken, isTrue);
    final List<Seat> want = <Seat>[alive[0], alive[1], alive[2]]..sort();
    expect(find.text(want.join(' · ')), findsOneWidget);

    // Оноо байхгүй, тэмдэг байхгүй, «зөв» гэсэн үг байхгүй.
    expect(find.textContaining('оноо'), findsNothing);
    expect(find.textContaining('зөв'), findsNothing);
  });

  testWidgets('20 секунд дуусахад сонгогдсоныг уншина (нэг ч байж болно)',
      (WidgetTester tester) async {
    final GameController c = afterFirstKill();
    final List<Seat> alive = c.alive.toList()..sort();
    final List<String> cues = <String>[];
    bool done = false;
    await pumpScreen(
        tester,
        BestMoveScreen(
            controller: c, onDone: () => done = true, onCue: cues.add));

    await tester.tap(find.text('${alive[0]}'));
    await tester.pump();

    await tester.pump(const Duration(milliseconds: 19000));
    // 19 секундэд цонх ХЭВЭЭР — цагирган дээрх тоо суудлын дугаартай
    // давхцаж болзошгүй тул гарчгаар шалгана.
    expect(find.text('Шилдэг нүүдэл — 20 секунд. Гурван дугаар сонго.'),
        findsOneWidget);
    expect(done, isFalse);

    await tester.pump(const Duration(milliseconds: 1100));
    expect(cues.last, 'BESTMOVE_READ');
    expect(find.text('Шилдэг нүүдэл —'), findsOneWidget);
    expect(done, isFalse, reason: 'уншигдтал S13 руу орохгүй');

    await tester.tap(find.text('Үргэлжлүүлэх'));
    await tester.pump();
    expect(done, isTrue);
  });

  testWidgets('Сонголтгүй — хөтлөгч ЮУ Ч ХЭЛЭХГҮЙ, шууд S13 руу',
      (WidgetTester tester) async {
    final GameController c = afterFirstKill();
    final List<String> cues = <String>[];
    bool done = false;
    await pumpScreen(
        tester,
        BestMoveScreen(
            controller: c, onDone: () => done = true, onCue: cues.add));

    await tester.pump(const Duration(milliseconds: 20100));
    expect(done, isTrue);
    expect(cues, <String>['BESTMOVE_START'], reason: '`BESTMOVE_READ` БАЙХГҮЙ');
    expect(c.bestMoveSpoken, isTrue);
  });

  testWidgets('Цагираг 20 секундэд дүүрнэ, хөдөлгөөн багасгахад тоо болно',
      (WidgetTester tester) async {
    final GameController c = afterFirstKill();
    c.settings.reduceMotion = true;
    await pumpScreen(
        tester, BestMoveScreen(controller: c, onDone: () {}, onCue: (_) {}));

    expect(find.text('20'), findsWidgets);
    await tester.pump(const Duration(milliseconds: 5000));
    expect(find.text('15'), findsWidgets);

    await tester.pump(const Duration(seconds: 16));
  });

  testWidgets('320 логик px — халихгүй, «Уншуулах» ≥ 72 dp',
      (WidgetTester tester) async {
    final GameController c = afterFirstKill(seats: 20);
    await pumpScreen(
      tester,
      BestMoveScreen(controller: c, onDone: () {}),
      size: kPhoneNarrow,
    );
    expect(tester.takeException(), isNull);

    final Size button =
        tester.getSize(find.widgetWithText(FilledButton, 'Уншуулах'));
    expect(button.height, greaterThanOrEqualTo(72));

    final Size tile = tester.getSize(find.byType(InkWell).first);
    expect(tile.width, greaterThanOrEqualTo(kMinTouch));

    await tester.pump(const Duration(seconds: 21));
  });
}
