// S22 — Тусламж. GDD-06, GDD-11 §5.

import 'package:flutter/material.dart' hide Intent;
import 'package:flutter_test/flutter_test.dart';
import 'package:hotuntlaa/screens/help_screen.dart';

import 'phone_viewport.dart';

void main() {
  Future<void> open(WidgetTester tester, String title) async {
    await tester.ensureVisible(find.text(title));
    await tester.pumpAndSettle();
    await tester.tap(find.text(title));
    await tester.pumpAndSettle();
  }

  testWidgets('Дөрвөн мөр, бүгд нугалагдсан', (WidgetTester tester) async {
    await pumpPhone(tester, HelpScreen(onClose: () {}));

    expect(find.text('Хөтлөгчийн дуу тасарч байна уу?'), findsOneWidget);
    expect(find.text('Хэрхэн тоглох вэ'), findsOneWidget);
    expect(find.text('Дүрүүд'), findsOneWidget);
    expect(find.text('Хот гэж юу вэ?'), findsOneWidget);
    // Анхандаа бүгд хаалттай.
    expect(find.text(kHowToPlay.first), findsNothing);
    expectNoOverflow(tester);
  });

  testWidgets('«Хэрхэн тоглох вэ» — арван мөр, дүрэм биш ДАРААЛАЛ',
      (WidgetTester tester) async {
    await pumpPhone(tester, HelpScreen(onClose: () {}));
    await open(tester, 'Хэрхэн тоглох вэ');

    expect(kHowToPlay.length, 10);
    for (final String line in kHowToPlay) {
      expect(find.text(line), findsOneWidget);
    }
    // Ялалтын хоёр нөхцөл ес, аравдугаарт — зориуд.
    expect(kHowToPlay[8], 'Мафи хотынхонтой тэнцвэл мафи ялна.');
    expect(kHowToPlay[9], 'Бүх мафи хотоос гарвал хотынхон ялна.');
    expectNoOverflow(tester);
  });

  testWidgets('«Дүрүүд» — дөрвөн дүр ба Ахлагч, тус бүр нэг өгүүлбэр',
      (WidgetTester tester) async {
    await pumpPhone(tester, HelpScreen(onClose: () {}));
    await open(tester, 'Дүрүүд');

    expect(kRoleLines.length, 5);
    expect(find.text('ИРГЭН'), findsOneWidget);
    expect(find.text('АХЛАГЧ'), findsOneWidget);
    expect(find.text('Шөнө бүр нэг хүнийг алалтаас авар.'), findsOneWidget);
    // Хамтрагчдын суудлын дугаар хаана ч байхгүй.
    expect(find.textContaining('Хамтрагчид:'), findsNothing);
    expectNoOverflow(tester);
  });

  testWidgets('Брэнд тус бүрийн батарейн заавар', (WidgetTester tester) async {
    await pumpPhone(tester, HelpScreen(onClose: () {}));
    await open(tester, 'Хөтлөгчийн дуу тасарч байна уу?');

    expect(find.text('Xiaomi · Redmi (MIUI)'), findsOneWidget);
    expect(find.text('Huawei'), findsOneWidget);
    expect(find.text('Samsung'), findsOneWidget);
    expect(find.text('Oppo · Realme'), findsOneWidget);
    expectNoOverflow(tester);
  });

  testWidgets('«Хот» — соёлын цорын ганц тайлбар', (WidgetTester tester) async {
    await pumpPhone(tester, HelpScreen(onClose: () {}));
    await open(tester, 'Хот гэж юу вэ?');

    expect(find.textContaining('хот айл'), findsOneWidget);
  });

  testWidgets('Одоогийн тоглолтын ЮУ Ч байхгүй', (WidgetTester tester) async {
    await pumpPhone(tester, HelpScreen(onClose: () {}));
    for (final String t in const <String>[
      'Хөтлөгчийн дуу тасарч байна уу?',
      'Хэрхэн тоглох вэ',
      'Дүрүүд',
      'Хот гэж юу вэ?',
    ]) {
      await open(tester, t);
    }

    // `b`, амьд суудал, шөнийн дугаар — нэг нь ч биш (GDD-11 §5).
    expect(find.textContaining('Алдаж болох санал'), findsNothing);
    expect(find.textContaining(RegExp(r'Шөнө \d')), findsNothing);
    expect(find.textContaining(RegExp(r'№\d')), findsNothing);
    expect(find.textContaining('Амьд'), findsNothing);
    // Аппын дотор эдгээр үг ХЭЗЭЭ Ч гарахгүй (GDD-00 §12.4).
    expect(find.textContaining('ёслол'), findsNothing);
    expect(find.textContaining('атмосфер'), findsNothing);
    expectNoOverflow(tester);
  });

  testWidgets('Нугалаа бүрийн толгой 48 dp-ээс бага биш, 320-д халихгүй',
      (WidgetTester tester) async {
    await pumpNarrow(tester, HelpScreen(onClose: () {}));
    expectTouchTarget(
        tester, find.ancestor(
            of: find.text('Дүрүүд'), matching: find.byType(InkWell)).first);
    await open(tester, 'Хөтлөгчийн дуу тасарч байна уу?');
    expectNoOverflow(tester);
  });
}
