// S03 — Бүрэлдэхүүн ба хүчинтэй эсэх. GDD-06, GDD-04 §3.

import 'package:engine/engine.dart' show Roster;
import 'package:flutter/material.dart' hide Intent;
import 'package:flutter_test/flutter_test.dart';
import 'package:hotuntlaa/game/game_controller.dart';
import 'package:hotuntlaa/game/settings.dart';
import 'package:hotuntlaa/screens/preset_screen.dart';
import 'package:hotuntlaa/ui/widgets.dart';

import 'phone_viewport.dart';

void main() {
  late GameController c;
  late int dealt;

  Future<void> pump(WidgetTester tester, {bool narrow = false}) async {
    c = GameController();
    addTearDown(c.dispose);
    dealt = 0;
    final Widget w = PresetScreen(controller: c, onDeal: () => dealt++);
    if (narrow) {
      await pumpNarrow(tester, w);
    } else {
      await pumpPhone(tester, w);
    }
  }

  Future<void> tapMafia(WidgetTester tester, int times,
      {bool plus = true}) async {
    for (int i = 0; i < times; i++) {
      await tester
          .tap(find.bySemanticsLabel(plus ? 'Алуурчин — нэмэх' : 'Алуурчин — хасах'));
      await tester.pump();
    }
  }

  testWidgets('Дөрвөн багц, «Сонгодог» анхдагчаар сонгогдсон',
      (WidgetTester tester) async {
    await pump(tester);

    for (final PresetId id in PresetId.values) {
      expect(find.text(id.labelMn), findsOneWidget);
    }
    // Нэрэнд суудлын тоо ОРОХГҮЙ.
    expect(find.text('Сонгодог 10'), findsNothing);
    expect(find.text('Ангийнхаа дүрэм. Өөрчилбөл энд хадгалагдана.'),
        findsOneWidget);
    expect(c.settings.basePreset, PresetId.songodog);
    expectNoOverflow(tester);
  });

  testWidgets('12 суудал → b = 2, «Тараая» асаалттай',
      (WidgetTester tester) async {
    await pump(tester);

    // `b >= 2` үед тайлбар нэмэх зүйлгүй тул зөвхөн PipStrip гарна
    // (давхардсан текст мөрийг устгав).
    expect(find.byType(PipStrip), findsOneWidget);
    expect(find.text('● ●'), findsNothing);
    expect(find.text('Бүрэлдэхүүн бэлэн.'), findsOneWidget);
    expect(find.text('Ахлагч нэг суудлыг эзэлнэ'), findsOneWidget);
    final FilledButton b = tester.widget(find.byType(FilledButton));
    expect(b.onPressed, isNotNull);
  });

  testWidgets('b = 1 — шаргал «сүүлчийн нэг» мөр',
      (WidgetTester tester) async {
    final SemanticsHandle h = tester.ensureSemantics();
    await pump(tester);
    // 12 → 3 мафи бол b = 2; нэг мафи нэмбэл b = 1.
    await tapMafia(tester, 1);

    expect(find.text('Алдаж болох санал: ● — сүүлчийн нэг.'), findsOneWidget);
    final FilledButton b = tester.widget(find.byType(FilledButton));
    expect(b.onPressed, isNotNull);
    h.dispose();
  });

  testWidgets('b = 0 — улаан «дууслаа» мөр, гэхдээ товч асаалттай',
      (WidgetTester tester) async {
    final SemanticsHandle h = tester.ensureSemantics();
    await pump(tester);
    await tapMafia(tester, 2);

    expect(find.text('Алдаж болох санал: ○ — дууслаа. Өнөөдөр онох ёстой.'),
        findsOneWidget);
    expect(find.text('Алдаж болох санал байхгүй. Эхний өдрөөс онох ёстой.'),
        findsOneWidget);
    final FilledButton b = tester.widget(find.byType(FilledButton));
    expect(b.onPressed, isNotNull);
    h.dispose();
  });

  testWidgets('b < 0 — ХАТУУ ТАТГАЛЗАЛ: товч түгжээтэй, гарц байхгүй',
      (WidgetTester tester) async {
    final SemanticsHandle h = tester.ensureSemantics();
    await pump(tester);
    await tapMafia(tester, 3);

    expect(
        find.text('Энэ бүрэлдэхүүнээр мафи эхний шөнөдөө яллаа. '
            'Тоглогч нэм эсвэл мафи хас.'),
        findsOneWidget);
    final FilledButton b = tester.widget(find.byType(FilledButton));
    expect(b.onPressed, isNull);

    // «Ямар ч байсан эхлэх» товч БАЙХГҮЙ, удаан дарах гарц БАЙХГҮЙ.
    expect(find.textContaining('Ямар ч байсан'), findsNothing);
    await tester.longPress(find.text('Тараая'));
    await tester.pump(const Duration(seconds: 2));
    expect(dealt, 0);
    h.dispose();
  });

  testWidgets('«Спорт» — 10 суудал, 2 мафи, Хотын шивнээ унтарна',
      (WidgetTester tester) async {
    await pump(tester);
    await tester.tap(find.text('Спорт'));
    await tester.pump();

    expect(c.settings.basePreset, PresetId.sport);
    expect(c.settings.cityWhisper, isFalse);
    // `b >= 2` үед тайлбар нэмэх зүйлгүй тул зөвхөн PipStrip гарна
    // (давхардсан текст мөрийг устгав).
    expect(find.byType(PipStrip), findsOneWidget);
    expect(find.text('● ●'), findsNothing);
    await tester.tap(find.text('Тараая'));
    await tester.pump();
    expect(c.roster.n, 10);
    expect(c.roster.mafia, 2);
    expect(c.roster.boss, isFalse);
  });

  testWidgets('Зөвхөн уншигдах багц засагдвал «Сонгодог» руу хуулагдана',
      (WidgetTester tester) async {
    final SemanticsHandle h = tester.ensureSemantics();
    await pump(tester);
    await tester.tap(find.text('Анги'));
    await tester.pump();
    expect(c.settings.basePreset, PresetId.angi);

    await tapMafia(tester, 1, plus: false);
    expect(c.settings.basePreset, PresetId.songodog);
    expect(find.text('Сонгодог болгож хадгаллаа.'), findsOneWidget);
    h.dispose();
  });

  testWidgets('«Тараая» бүрэлдэхүүнийг хөдөлгүүрт бүртгэнэ',
      (WidgetTester tester) async {
    final SemanticsHandle h = tester.ensureSemantics();
    await pump(tester);
    await tapMafia(tester, 1, plus: false); // 3 → 2 мафи, Ахлагчгүй
    await tester.tap(find.text('Тараая'));
    await tester.pump();

    expect(dealt, 1);
    final Roster r = c.roster;
    expect(r.n, 12);
    expect(r.mafia, 2);
    expect(r.boss, isFalse, reason: 'Ахлагч зөвхөн M ≥ 3 үед');
    expect(r.citizens, 12 - 2 - 2);
    h.dispose();
  });

  testWidgets('Хөдөлгөөн багасгах горимд цэг нь тоо болно',
      (WidgetTester tester) async {
    c = GameController();
    addTearDown(c.dispose);
    c.settings.reduceMotion = true;
    await pumpPhone(tester, PresetScreen(controller: c, onDeal: () {}));

    expect(find.text('Алдаж болох санал: 2'), findsOneWidget);
    expect(find.text('Алдаж болох санал: ● ●'), findsNothing);
  });

  testWidgets('Чипийн товчнууд 48 dp, 320 px дээр халихгүй',
      (WidgetTester tester) async {
    final SemanticsHandle h = tester.ensureSemantics();
    await pump(tester, narrow: true);

    expectTouchTarget(tester, find.bySemanticsLabel('Алуурчин — нэмэх'));
    expectTouchTarget(tester, find.bySemanticsLabel('Эмч — хасах'));
    expectNoOverflow(tester);
    h.dispose();
  });
}
