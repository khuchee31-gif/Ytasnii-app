// Аппын утаа тест — хөдөлгүүр UI-тай зөв холбогдсон эсэхийг шалгана.
// Дэлгэцийн жинхэнэ тестүүд GDD-06 хэрэгжсэний дараа бичигдэнэ.

import 'package:engine/engine.dart';
import 'package:flutter/material.dart' hide Intent;
import 'package:flutter_test/flutter_test.dart';
import 'package:hotuntlaa/main.dart';

/// Тестийн анхдагч дэлгэц 800×600 тул доод талын товч хүрэлцэхгүй.
/// Жинхэнэ утас (GDD-13 D1 = Redmi 9A) 720×1600 тул түүнтэй ойролцоо болгоно.
Future<void> _pumpApp(WidgetTester tester) async {
  tester.view.physicalSize = const Size(720, 1600);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const HotUntlaaDemo());
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Нүүр дэлгэц ачаалж, 12 суудлын бүрэлдэхүүнийг харуулна',
      (WidgetTester tester) async {
    await _pumpApp(tester);

    expect(find.text('ХОТ УНТЛАА'), findsOneWidget);
    expect(find.text('Тоглогчийн тоо: 12'), findsOneWidget);
    // 12 суудалд 3 мафи, Ахлагчтай (GDD-04-ийн хүснэгт).
    expect(find.text('3 (Ахлагчтай)'), findsOneWidget);
  });

  testWidgets('«Хөзөр тараах» дарахад шударга байдлын код гарна',
      (WidgetTester tester) async {
    await _pumpApp(tester);
    await tester.tap(find.text('Хөзөр тараах'));
    await tester.pumpAndSettle();

    expect(find.text('Шударга байдлын код'), findsOneWidget);
    // «412-995» хэлбэр: гурван цифр, зураас, гурван цифр.
    expect(
      find.byWidgetPredicate((Widget w) =>
          w is Text &&
          w.data != null &&
          RegExp(r'^\d{3}-\d{3}$').hasMatch(w.data!)),
      findsOneWidget,
    );
  });

  testWidgets('Шөнө шийдвэрлэхэд үүрийн клип гарна',
      (WidgetTester tester) async {
    await _pumpApp(tester);
    await tester.tap(find.text('Хөзөр тараах'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('1-р шөнийг шийдвэрлэх'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1-р шөнийг шийдвэрлэх'));
    await tester.pumpAndSettle();

    expect(find.text('Үүрийн үр дүн'), findsOneWidget);
    // Үхэлтэй бол DAWN_A, үхэлгүй бол DAWN_NO_KILL — аль нэг нь заавал байна.
    final bool hasDawn = find.text('DAWN_A').evaluate().isNotEmpty ||
        find.text('DAWN_NO_KILL').evaluate().isNotEmpty;
    expect(hasDawn, isTrue);
  });

  test('Аппын давхарга хөдөлгүүрийн нийтийн API-г зөв уншиж байна', () {
    // Энэ тест нь холболт эвдэрвэл шууд унана.
    expect(rosterFor(12).mafia, 3);
    expect(b0(12, 3), 2);
    expect(kMinSeats, 6);
  });
}
