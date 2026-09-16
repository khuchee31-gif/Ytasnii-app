// Тестийн утасны дэлгэц — GDD-13 D1 = Redmi 9A, 720×1600 @ dpr 2 = 360 логик px.
//
// Дэлгэц бүр 360-д ажиллаж, 320-д ч ЭВДРЭХГҮЙ байх ёстой. Нэг дэлгэц яг ийм
// тестээр 78px-ээр халж баригдсан тул энэ туслах файл байна.

import 'package:flutter/material.dart' hide Intent;
import 'package:flutter_test/flutter_test.dart';
import 'package:hotuntlaa/ui/glyphs.dart';
import 'package:hotuntlaa/ui/tokens.dart';

/// Зорилтот утас: 360 логик px.
Future<void> pumpPhone(WidgetTester tester, Widget child) =>
    _pump(tester, child, const Size(720, 1600), 2.0);

/// Хамгийн нарийн дэмжигдэх дэлгэц: 320 логик px.
Future<void> pumpNarrow(WidgetTester tester, Widget child) =>
    _pump(tester, child, const Size(640, 1400), 2.0);

Future<void> _pump(
  WidgetTester tester,
  Widget child,
  Size size,
  double dpr,
) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = dpr;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(theme: buildTheme(), home: child));
  await tester.pump();
}

/// Мөр халих нь `FlutterError` болж гарна — тэрийг барина.
void expectNoOverflow(WidgetTester tester) {
  expect(tester.takeException(), isNull, reason: 'Дэлгэц халив');
}

/// Хүрэх талбай ХЭЗЭЭ Ч [kMinTouch]-ээс бага биш.
void expectTouchTarget(
  WidgetTester tester,
  Finder f, {
  double min = kMinTouch,
}) {
  final Size s = tester.getSize(f);
  expect(s.height, greaterThanOrEqualTo(min));
  expect(s.width, greaterThanOrEqualTo(min));
}

/// Зурагдсан тэмдгийг олно. Тэмдгүүд ТЕКСТ БИШ болсон тул (`ui/glyphs.dart`)
/// `find.text('○')` ажиллахаа больсон — түүний оронд энэ.
Finder findMark(MarkShape shape) => find.byWidgetPredicate(
  (Widget w) => w is Mark && w.shape == shape,
  description: 'Mark($shape)',
);
