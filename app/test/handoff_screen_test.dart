// S05 — Дамжуулах завсрын дэлгэцийн тестүүд (GDD-06 §S05, GDD-10 §5).

import 'package:flutter/material.dart' hide Intent;
import 'package:flutter_test/flutter_test.dart';
import 'package:hotuntlaa/screens/handoff_screen.dart';
import 'package:hotuntlaa/ui/tokens.dart';

import 'deal_test_support.dart';

void main() {
  testWidgets('Мөр нь яг «Ширээн дээр тавь. Дараах — №7»', (
    WidgetTester tester,
  ) async {
    await pumpScreen(tester, HandoffGate(nextSeat: 7, onLift: () {}));
    expect(find.text('Ширээн дээр тавь. Дараах — №7'), findsOneWidget);
  });

  testWidgets('600 мс дотор товшилт ҮЛ ХАМААРНА', (WidgetTester tester) async {
    int lifts = 0;
    await pumpScreen(tester, HandoffGate(nextSeat: 7, onLift: () => lifts++));

    await tester.tapAt(const Offset(180, 400));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tapAt(const Offset(180, 400));
    await tester.pump(const Duration(milliseconds: 200));
    expect(lifts, 0, reason: 'Хаалт 600 мс хаагдахгүй');
    expect(find.text('№7 — утсаа өргө'), findsNothing);

    await tester.pump(const Duration(milliseconds: 150));
    expect(find.text('№7 — утсаа өргө'), findsOneWidget);

    await tester.tapAt(const Offset(180, 400));
    await tester.pump();
    expect(lifts, 1);
  });

  testWidgets('Гурван секундын дараа «Товшиж нээ» товч гарна', (
    WidgetTester tester,
  ) async {
    int lifts = 0;
    await pumpScreen(tester, HandoffGate(nextSeat: 7, onLift: () => lifts++));

    await tester.pump(kHandoffLock + const Duration(milliseconds: 50));
    expect(find.text('Товшиж нээ'), findsNothing);
    await tester.pump(kLiftTimeout);
    expect(find.text('Товшиж нээ'), findsOneWidget);

    await tester.tap(find.text('Товшиж нээ'));
    await tester.pump();
    expect(lifts, 1);
  });

  testWidgets('Хасагдсан суудал алгасагдана: «№7 байхгүй. Дараах — №8»', (
    WidgetTester tester,
  ) async {
    await pumpScreen(
      tester,
      HandoffGate(nextSeat: 8, skippedSeat: 7, onLift: () {}),
    );
    expect(find.text('№7 байхгүй. Дараах — №8'), findsOneWidget);

    // 600 мс алгасалт, дараа нь ХЭВИЙН 600 мс хаалт.
    await tester.pump(kHandoffLock + const Duration(milliseconds: 20));
    expect(find.text('Ширээн дээр тавь. Дараах — №8'), findsOneWidget);
    expect(find.text('№8 — утсаа өргө'), findsNothing);
    await tester.pump(kHandoffLock);
    expect(find.text('№8 — утсаа өргө'), findsOneWidget);
  });

  testWidgets('Дэлгэц бүрэн хар — цагаан суурь ХАААНА Ч БАЙХГҮЙ', (
    WidgetTester tester,
  ) async {
    await pumpScreen(tester, HandoffGate(nextSeat: 7, onLift: () {}));
    final Scaffold s = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(s.backgroundColor, kNight);
  });

  testWidgets('320 логик px дээр мөр халихгүй', (WidgetTester tester) async {
    await pumpScreen(
      tester,
      HandoffGate(nextSeat: 20, onLift: () {}),
      size: kPhoneNarrow,
    );
    await tester.pump(kHandoffLock + kLiftTimeout);
    expect(tester.takeException(), isNull);
  });
}
