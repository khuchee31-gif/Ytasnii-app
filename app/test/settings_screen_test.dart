// S21 — Тохиргоо. GDD-06, GDD-03 §2/§4.

import 'package:engine/engine.dart' show SelfHeal;
import 'package:flutter/material.dart' hide Intent;
import 'package:flutter_test/flutter_test.dart';
import 'package:hotuntlaa/game/game_controller.dart';
import 'package:hotuntlaa/game/phase.dart';
import 'package:hotuntlaa/game/settings.dart';
import 'package:hotuntlaa/screens/settings_screen.dart';

import 'phone_viewport.dart';

void main() {
  late GameController c;

  Future<void> pump(WidgetTester tester, {bool narrow = false}) async {
    c = GameController();
    addTearDown(c.dispose);
    final Widget w = SettingsScreen(controller: c, onClose: () {});
    if (narrow) {
      await pumpNarrow(tester, w);
    } else {
      await pumpPhone(tester, w);
    }
  }

  Future<void> openAdvanced(WidgetTester tester) async {
    await tester.ensureVisible(find.text('Дэлгэрэнгүй'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Дэлгэрэнгүй'));
    await tester.pumpAndSettle();
  }

  testWidgets('Дөрвөн preset карт ба гэрийн дүрмийн дөрөв',
      (WidgetTester tester) async {
    await pump(tester);

    for (final PresetId id in PresetId.values) {
      expect(find.text(id.labelMn), findsOneWidget);
    }
    expect(find.text('Эмч өөрийгөө аврах'), findsOneWidget);
    expect(find.text('Мафи өөрийн хүнээ буудаж болно'), findsOneWidget);
    expect(find.text('Хасагдахад дүрийг нээх'), findsOneWidget);
    expect(find.text('Санал тэнцвэл'), findsOneWidget);
    expectNoOverflow(tester);
  });

  testWidgets('Царцсан дүрэм ОГТ гарахгүй', (WidgetTester tester) async {
    await pump(tester);
    await openAdvanced(tester);

    // GDD-03 §1-ийн Зарчим 2 ба §4-ийн устгал.
    expect(find.textContaining('Сануулга бүртгэх'), findsNothing);
    expect(find.textContaining('Цаазлах'), findsNothing);
    expect(find.textContaining('Танилцах шөнөд хохирогч'), findsNothing);
    expect(find.textContaining('Хэл'), findsNothing);
  });

  testWidgets('«Дэлгэрэнгүй» нугалаа — анхандаа хаалттай',
      (WidgetTester tester) async {
    await pump(tester);
    expect(find.text('Нэг хүний үг'), findsNothing);

    await openAdvanced(tester);
    expect(find.text('Нэг хүний үг'), findsOneWidget);
    expect(find.text('Шөнө нэг суудал'), findsOneWidget);
    expect(find.text('Хөтлөгчтэй горим'), findsOneWidget);
    expectNoOverflow(tester);
  });

  testWidgets('«Нэг хүний үг» 40 сек анхдагч, 30/40/45/60/90-ээр явна',
      (WidgetTester tester) async {
    final SemanticsHandle h = tester.ensureSemantics();
    await pump(tester);
    await openAdvanced(tester);

    expect(find.text('40 сек'), findsOneWidget);
    await tester.ensureVisible(find.text('Нэг хүний үг'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Нэг хүний үг — нэмэх'));
    await tester.pump();
    expect(c.settings.speechSeconds, 45);
    await tester.tap(find.bySemanticsLabel('Нэг хүний үг — хасах'));
    await tester.pump();
    expect(c.settings.speechSeconds, 40);
    h.dispose();
  });

  testWidgets('Гэрийн дүрэм шууд хадгалагдана', (WidgetTester tester) async {
    await pump(tester);
    expect(c.settings.doctorSelfHeal, SelfHeal.once);

    await tester.ensureVisible(find.text('Хэзээ ч үгүй'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Хэзээ ч үгүй'));
    await tester.pump();
    expect(c.settings.doctorSelfHeal, SelfHeal.never);
    expect(find.text('Эмч эхний шөнө хохирч болно.'), findsOneWidget);
  });

  testWidgets('Зөвхөн уншигдах багц засагдвал «Сонгодог» руу хуулагдана',
      (WidgetTester tester) async {
    await pump(tester);
    await tester.tap(find.text('Спорт'));
    await tester.pump();
    expect(c.settings.basePreset, PresetId.sport);

    await tester.ensureVisible(find.text('Хязгааргүй'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Хязгааргүй'));
    await tester.pump();
    expect(c.settings.basePreset, PresetId.songodog);
    expect(find.text('Сонгодог болгож хадгаллаа.'), findsOneWidget);

    // 1.5 секундын дараа мөр өөрөө алга болно, товчгүй.
    await tester.pump(const Duration(milliseconds: 1600));
    expect(find.text('Сонгодог болгож хадгаллаа.'), findsNothing);
  });

  testWidgets('Тоглолт явж байхад «Дараагийн тоглолтод хүчинтэй»',
      (WidgetTester tester) async {
    await pump(tester);
    expect(find.text('Дараагийн тоглолтод хүчинтэй'), findsNothing);

    c.go(GamePhase.speechRound);
    await tester.pumpWidget(MaterialApp(
        home: SettingsScreen(controller: c, onClose: () {})));
    await tester.pump();
    expect(find.text('Дараагийн тоглолтод хүчинтэй'), findsOneWidget);
    // Дэлгэц ХААГДАХГҮЙ — тохируулга засагдсан хэвээр.
    expect(find.text('Хэзээ ч үгүй'), findsOneWidget);
  });

  testWidgets('Доод мөрөнд `b` бэхлэгдсэн', (WidgetTester tester) async {
    await pump(tester);
    expect(find.text('Алдаж болох санал'), findsOneWidget);
    expect(find.text('●●'), findsOneWidget);
  });

  testWidgets('«Бүх өгөгдлийг устгах» — хоёр товшилт, хоёр дахь 3 сек бүдэг',
      (WidgetTester tester) async {
    await pump(tester);
    await openAdvanced(tester);

    await tester.ensureVisible(find.text('Бүх өгөгдлийг устгах'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Бүх өгөгдлийг устгах'));
    await tester.pump();

    expect(
        find.text('Ангийн дэвтэр, суудлын жагсаалт, бүх тоглолт, бүх цол '
            '— бүгд устана. Буцаах боломжгүй.'),
        findsOneWidget);
    FilledButton wipe = tester.widget(find.widgetWithText(FilledButton, 'Устгах'));
    expect(wipe.onPressed, isNull, reason: 'Хоёр дахь товч 3 секунд бүдэг');

    await tester.pump(const Duration(seconds: 3));
    wipe = tester.widget(find.widgetWithText(FilledButton, 'Устгах'));
    expect(wipe.onPressed, isNotNull);
  });

  testWidgets('320 px дээр халихгүй — нугалаа нээлттэй үед ч',
      (WidgetTester tester) async {
    await pump(tester, narrow: true);
    await openAdvanced(tester);
    expectNoOverflow(tester);
  });
}
