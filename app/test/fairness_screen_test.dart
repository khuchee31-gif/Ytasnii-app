// S04 — Шударга байдлын кодын дэлгэцийн тестүүд (GDD-06 §S04, GDD-10 §2).

import 'package:flutter/material.dart' hide Intent;
import 'package:flutter_test/flutter_test.dart';
import 'package:hotuntlaa/game/game_controller.dart';
import 'package:hotuntlaa/screens/fairness_screen.dart';

import 'deal_test_support.dart';

void main() {
  testWidgets('Код нь «412-995» хэлбэрээр, тараахаас ӨМНӨ гарна',
      (WidgetTester tester) async {
    final GameController c = freshController();
    await pumpScreen(
        tester, FairnessScreen(controller: c, onSealed: () {}));

    expect(find.text('Шударга байдлын код'), findsOneWidget);
    expect(
      find.byWidgetPredicate((Widget w) =>
          w is Text &&
          w.data != null &&
          RegExp(r'^\d{3}-\d{3}$').hasMatch(w.data!)),
      findsOneWidget,
    );
    // ХАМГИЙН ЧУХАЛ МӨР: код гарсан ч хуваарилалт ХИЙГДЭЭГҮЙ.
    expect(c.dealResult, isNull);
  });

  testWidgets('Уншигч суудал нь утас барьсан хүн БИШ, hash-аас гарна',
      (WidgetTester tester) async {
    final GameController c = freshController();
    await pumpScreen(
        tester, FairnessScreen(controller: c, onSealed: () {}));

    expect(c.previewReaderSeat, isNot(c.holderSeat));
    expect(find.text('№${c.previewReaderSeat} — уншаарай.'), findsOneWidget);
    expect(find.text('Утас барихгүй хүн уншиж, дэвтрийнхээ буланд бич.'),
        findsOneWidget);
  });

  testWidgets('Сэгсрэлт 2.0 секунд хуримтлагдаж, дараа нь л тараана',
      (WidgetTester tester) async {
    final GameController c = freshController();
    bool sealed = false;
    await pumpScreen(
        tester, FairnessScreen(controller: c, onSealed: () => sealed = true));

    await tester.tap(find.text('Бичиж авлаа'));
    await tester.pump();
    expect(find.text('№${c.previewReaderSeat} — утсаа хоёр секунд сэгсэр.'),
        findsOneWidget);

    final TestGesture g = await tester
        .startGesture(tester.getCenter(find.byKey(const ValueKey<String>('shakePad'))));
    // Нэг секунд хангалтгүй — хуваарилалт хараахан үгүй.
    await tester.pump(const Duration(milliseconds: 1000));
    expect(c.dealResult, isNull);

    await tester.pump(const Duration(milliseconds: 1100));
    await g.up();
    await tester.pump();

    expect(find.text('Түгжигдлээ.'), findsOneWidget);
    expect(c.dealResult, isNotNull);
    expect(sealed, isFalse); // 600 мс зогсоно
    await tester.pump(const Duration(milliseconds: 650));
    expect(sealed, isTrue);
  });

  testWidgets('Мэдрэгчгүй утасны гарц — дөрвөн цифр',
      (WidgetTester tester) async {
    final GameController c = freshController();
    await pumpScreen(
        tester, FairnessScreen(controller: c, onSealed: () {}));

    await tester.tap(find.text('Бичиж авлаа'));
    await tester.pump();
    await tester.tap(find.text('Дөрвөн цифр оруул.'));
    await tester.pump();

    expect(find.text('Түгжих'), findsOneWidget);
    for (final String d in <String>['7', '1', '0', '4']) {
      await tester.tap(find.text(d));
      await tester.pump();
    }
    await tester.tap(find.text('Түгжих'));
    await tester.pump();

    expect(c.dealResult, isNotNull);
    // Тараалтын дараах уншигч суудал нь урьдчилсан утгатай ЯГ ТЭНЦҮҮ.
    expect(c.dealResult!.readerSeat, c.previewReaderSeat);
    expect(c.dealResult!.fairCode, c.previewCode);
  });

  testWidgets('320 логик px дээр мөр халихгүй (96 sp код ч)',
      (WidgetTester tester) async {
    final GameController c = freshController(seats: 20);
    await pumpScreen(
      tester,
      FairnessScreen(controller: c, onSealed: () {}),
      size: kPhoneNarrow,
    );
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Бичиж авлаа'));
    await tester.pump();
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Дөрвөн цифр оруул.'));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
