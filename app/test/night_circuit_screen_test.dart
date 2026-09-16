// S08 — Шөнийн дамжуулалт ба эргэлтийн тестүүд (GDD-06 §S08).
//
// Хоёр зүйлийг батална: (1) хаалт 600 мс-ээс өмнө ЮУ Ч хүлээж авахгүй,
// (2) хасагдсан суудал АЛГАСАГДАНА — «№k байхгүй. Дараах — №k+1». Гуравдугаарт,
// бүтэн эргэлт нь инвариант N22-ыг хангана: амьд суудал бүр ЯГ НЭГ санаа.

import 'package:engine/engine.dart';
import 'package:flutter/material.dart' hide Intent;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hotuntlaa/game/game_controller.dart';
import 'package:hotuntlaa/screens/night_action_screen.dart';
import 'package:hotuntlaa/screens/night_circuit_screen.dart';
import 'package:hotuntlaa/ui/tokens.dart';

import 'deal_test_support.dart';
import 'night_test_support.dart';

/// Нэг суудлын бүтэн ээлж: хаалт → өргөх → цонх дуустал.
Future<void> passOneSeat(WidgetTester tester) async {
  await liftPhone(tester);
  await tester.pump(const Duration(milliseconds: 6100));
}

void main() {
  testWidgets('Хаалт 600 мс — товшилт ҮЛ ХАМААРНА, дараа нь суудлын цонх',
      (WidgetTester tester) async {
    final GameController c = nightController(seats: 10);
    await pumpScreen(
        tester, NightCircuitScreen(controller: c, onDone: () {}));

    expect(find.text('Ширээн дээр тавь. Дараах — №1'), findsOneWidget);

    // 600 мс дотор бүх оролт үхнэ.
    await tester.tapAt(const Offset(180, 400));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tapAt(const Offset(180, 400));
    await tester.pump();
    expect(find.byType(NightActionScreen), findsNothing);

    await tester.pump(const Duration(milliseconds: 200));
    await tester.tapAt(const Offset(180, 400));
    await tester.pump();
    expect(find.byType(NightActionScreen), findsOneWidget);

    await tester.pump(const Duration(seconds: 7));
  });

  testWidgets('Хасагдсан суудал АЛГАСАГДАНА — «№2 байхгүй. Дараах — №3»',
      (WidgetTester tester) async {
    final GameController c = dealtController(seats: 10);
    c.alive.remove(2);
    c.beginNight();

    await pumpScreen(
        tester, NightCircuitScreen(controller: c, onDone: () {}));

    // №1 хэвийн.
    expect(c.currentSeat, 1);
    await passOneSeat(tester);

    // №2 хасагдсан тул алгасагдаж, мөр гарна.
    expect(c.currentSeat, 3);
    expect(find.text('№2 байхгүй. Дараах — №3'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Ширээн дээр тавь. Дараах — №3'), findsOneWidget);
    await tester.pump(const Duration(seconds: 8));
  });

  testWidgets('Бүтэн эргэлт — амьд суудал бүр яг нэг санаа (N22)',
      (WidgetTester tester) async {
    final GameController c = dealtController(seats: 10);
    c.alive.removeAll(<Seat>{3, 7});
    c.beginNight();

    bool done = false;
    await pumpScreen(
        tester, NightCircuitScreen(controller: c, onDone: () => done = true));

    // 8 амьд суудал. Хасагдсан хоёр нь дамжуулалтад ч ороогүй өнгөрнө.
    for (int i = 0; i < 8; i++) {
      expect(done, isFalse, reason: '$i-р суудлын дараа эргэлт дуусах ёсгүй');
      expect(c.alive.contains(c.currentSeat), isTrue);
      await passOneSeat(tester);
    }
    expect(done, isTrue);
    expect(c.circuitDone, isTrue);

    // `resolveNightNow` нь `checkInvariants`-ыг debug билд дээр ҮРГЭЛЖ ажиллуулна
    // — N22 зөрчигдвөл энд шидэгдэнэ.
    c.resolveNightNow();
    expect(c.report, isNotNull);
    expect(c.report!.deaths, isEmpty, reason: 'хэн ч батлаагүй');
  });

  testWidgets('Дэлгэц 10 % — цагаан пиксел хаана ч байхгүй',
      (WidgetTester tester) async {
    final GameController c = nightController(seats: 10);
    await pumpScreen(
        tester, NightCircuitScreen(controller: c, onDone: () {}));
    expect(
        tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor, kNight);
    await tester.pump(const Duration(seconds: 8));
  });

  testWidgets('`FLAG_SECURE` эргэлтийн турш асаалттай',
      (WidgetTester tester) async {
    final List<MethodCall> calls = captureGuardCalls();
    final GameController c = nightController(seats: 10);
    await pumpScreen(
        tester, NightCircuitScreen(controller: c, onDone: () {}));
    await tester.pump();

    expect(
      calls.any((MethodCall m) =>
          m.method == 'setSecure' &&
          (m.arguments as Map<Object?, Object?>)['on'] == true),
      isTrue,
    );
    await tester.pump(const Duration(seconds: 8));
  });

  testWidgets('320 логик px дээр эргэлт халихгүй',
      (WidgetTester tester) async {
    final GameController c = nightController(seats: 20);
    await pumpScreen(
      tester,
      NightCircuitScreen(controller: c, onDone: () {}),
      size: kPhoneNarrow,
    );
    expect(tester.takeException(), isNull);
    await liftPhone(tester);
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 7));
  });
}
