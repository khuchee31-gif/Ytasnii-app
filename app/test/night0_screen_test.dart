// S07 — Танилцах шөнийн тестүүд (GDD-06 §S07, GDD-01 §1-ийн 7-р мөр).
//
// Энэ дэлгэцийн тестүүд нь ЮУ БАЙХГҮЙГ шалгадгаараа онцлог: тоолуур байхгүй,
// текст байхгүй, товч байхгүй. Апп юу ч хийхгүй — тэр нь яг зорилго нь.

import 'package:flutter/material.dart' hide Intent;
import 'package:flutter_test/flutter_test.dart';
import 'package:hotuntlaa/game/game_controller.dart';
import 'package:hotuntlaa/screens/night0_screen.dart';
import 'package:hotuntlaa/ui/tokens.dart';

import 'deal_test_support.dart';

void main() {
  testWidgets('Дэлгэц 100 % хар, ямар ч текст, тоолуур, товч БАЙХГҮЙ', (
    WidgetTester tester,
  ) async {
    final GameController c = dealtController();
    await pumpScreen(tester, Night0Screen(controller: c, onDone: () {}));

    expect(
      tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
      kNight,
    );
    expect(find.byType(Text), findsNothing);

    // Танилцах минутын дунд ч — тоолуур ГАРАХГҮЙ.
    await tester.pump(const Duration(seconds: 20));
    expect(find.byType(Text), findsNothing);
    await tester.pump(const Duration(seconds: 40));
    expect(find.byType(Text), findsNothing);

    await tester.pump(const Duration(seconds: 25));
  });

  testWidgets('4.0 сек → 60.0 сек → 1.2 сек, дараа нь шөнийн эргэлт рүү', (
    WidgetTester tester,
  ) async {
    final GameController c = dealtController();
    final List<String> cues = <String>[];
    bool done = false;
    await pumpScreen(
      tester,
      Night0Screen(controller: c, onDone: () => done = true, onCue: cues.add),
    );

    expect(cues, <String>['NIGHT_START']);
    await tester.pump(const Duration(milliseconds: 3900));
    expect(cues.length, 1, reason: 'уур амьсгал 4.0 секунд ОРЖ ирнэ');

    await tester.pump(const Duration(milliseconds: 200));
    expect(cues, <String>['NIGHT_START', 'MAFIA_MEET']);

    // 60 секунд ҮНЭМЛЭХҮЙ ЧИМЭЭГҮЙ — эрт хаагдахгүй.
    await tester.pump(const Duration(milliseconds: 59000));
    expect(cues.length, 2);
    await tester.pump(const Duration(milliseconds: 1100));
    expect(cues.last, 'MAFIA_SLEEP');

    expect(done, isFalse);
    await tester.pump(const Duration(milliseconds: 1300));
    expect(done, isTrue);
    expect(c.meetCutShort, isFalse);
  });

  testWidgets('Гурван товшилт — хөгжүүлэгчийн авралт, дэвтэрт тэмдэглэгдэнэ', (
    WidgetTester tester,
  ) async {
    final GameController c = dealtController();
    bool done = false;
    await pumpScreen(
      tester,
      Night0Screen(controller: c, onDone: () => done = true),
    );

    // `nightStart`-ын дотор товшилт ҮЛ ХАМААРНА.
    await tester.tapAt(const Offset(180, 400));
    await tester.tapAt(const Offset(180, 400));
    await tester.tapAt(const Offset(180, 400));
    await tester.pump();
    expect(find.text('Танилцах шөнийг дуусгах уу?'), findsNothing);

    await tester.pump(const Duration(seconds: 5));
    for (int i = 0; i < 3; i++) {
      await tester.tapAt(const Offset(180, 400));
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Танилцах шөнийг дуусгах уу?'), findsOneWidget);

    // «Үгүй» — минут үргэлжилнэ.
    await tester.tap(find.text('Үгүй — үргэлжлүүл'));
    await tester.pump();
    expect(find.byType(Text), findsNothing);
    expect(c.meetCutShort, isFalse);

    for (int i = 0; i < 3; i++) {
      await tester.tapAt(const Offset(180, 400));
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.tap(find.text('Тийм — дуусга'));
    await tester.pump();
    expect(c.meetCutShort, isTrue);
    await tester.pump(const Duration(milliseconds: 1300));
    expect(done, isTrue);
  });

  testWidgets('Хоёр товшилт авралт гаргахгүй', (WidgetTester tester) async {
    final GameController c = dealtController();
    await pumpScreen(tester, Night0Screen(controller: c, onDone: () {}));
    await tester.pump(const Duration(seconds: 5));

    await tester.tapAt(const Offset(180, 400));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tapAt(const Offset(180, 400));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Танилцах шөнийг дуусгах уу?'), findsNothing);

    await tester.pump(const Duration(seconds: 62));
  });

  testWidgets('320 логик px дээр авралтын мөр халихгүй', (
    WidgetTester tester,
  ) async {
    final GameController c = dealtController();
    await pumpScreen(
      tester,
      Night0Screen(controller: c, onDone: () {}),
      size: kPhoneNarrow,
    );
    await tester.pump(const Duration(seconds: 5));
    for (int i = 0; i < 3; i++) {
      await tester.tapAt(const Offset(160, 400));
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Танилцах шөнийг дуусгах уу?'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 62));
  });
}
