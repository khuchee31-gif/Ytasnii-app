// Тараалтын ёслолын тестүүдийн хуваалцсан тулгуур (GDD-13 D1).
//
// Тестийн анхдагч дэлгэц 800 × 600 — жинхэнэ утас (Redmi 9A) 720 × 1600,
// dpr 2, өөрөөр хэлбэл 360 × 800 логик px. Доод талын товч, хоёр эрхийн
// товгор хоёулаа тэр өндөрт л шалгагдана.

import 'package:flutter/material.dart' hide Intent;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hotuntlaa/game/game_controller.dart';
import 'package:hotuntlaa/ui/platform_guard.dart';
import 'package:hotuntlaa/ui/tokens.dart';

/// D1 = Redmi 9A. 320 логик px нь бидний шалгадаг ХАМГИЙН НАРИЙН дэлгэц.
const Size kPhoneD1 = Size(720, 1600);
const Size kPhoneNarrow = Size(640, 1136);

Future<void> pumpScreen(
  WidgetTester tester,
  Widget child, {
  Size size = kPhoneD1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildTheme(),
      debugShowCheckedModeBanner: false,
      home: child,
    ),
  );
  await tester.pump();
}

/// Шударга байдлын кодыг төрүүлсэн, ГЭХДЭЭ хараахан тараагаагүй хянагч.
GameController freshController({int seats = 12, int gamesPlayed = 9}) {
  final GameController c = GameController()
    ..seatCount = seats
    ..gamesPlayed = gamesPlayed;
  c.beginFairness(holderSeat: 1);
  return c;
}

/// Хөзөр тараагдсан хянагч — S06-ын тестүүд эндээс эхэлнэ.
GameController dealtController({int seats = 12, int gamesPlayed = 9}) {
  final GameController c = freshController(
    seats: seats,
    gamesPlayed: gamesPlayed,
  );
  c.dealWithEntropy(Uint8List.fromList(<int>[7, 1, 0, 4]));
  return c;
}

/// `PlatformGuard`-ын MethodChannel-ийг барьж авах — `FLAG_SECURE` үнэхээр
/// асаж байгааг шалгах цорын ганц арга.
List<MethodCall> captureGuardCalls() {
  PlatformGuard.resetForTest();
  final List<MethodCall> calls = <MethodCall>[];
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(const MethodChannel('mn.hotuntlaa/guard'), (
        MethodCall call,
      ) async {
        calls.add(call);
        return null;
      });
  addTearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('mn.hotuntlaa/guard'),
          null,
        );
    PlatformGuard.resetForTest();
  });
  return calls;
}
