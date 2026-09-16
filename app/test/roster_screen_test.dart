// S02 — Ангийн суудал. GDD-06.

import 'package:flutter/material.dart' hide Intent;
import 'package:flutter_test/flutter_test.dart';
import 'package:hotuntlaa/game/game_controller.dart';
import 'package:hotuntlaa/screens/roster_screen.dart';

import 'phone_viewport.dart';

/// Дээд захын том тоо — мөрийн дугаараас ялгахын тулд түлхүүрээр.
String bigCount(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const ValueKey<String>('seat-count'))).data!;

void main() {
  Future<GameController> pump(
    WidgetTester tester, {
    bool narrow = false,
    void Function()? onContinue,
  }) async {
    final GameController c = GameController();
    addTearDown(c.dispose);
    final Widget w = RosterScreen(
      controller: c,
      onContinue: onContinue ?? () {},
    );
    if (narrow) {
      await pumpNarrow(tester, w);
    } else {
      await pumpPhone(tester, w);
    }
    return c;
  }

  testWidgets('empty — 10 суудал өөрөө үүсгэгдэнэ, нэр хоосон', (
    WidgetTester tester,
  ) async {
    await pump(tester);

    expect(find.text('Хэдүүлээ вэ?'), findsOneWidget);
    expect(bigCount(tester), '10');
    // Нэр заавал биш — сануулга мөр байна.
    expect(
      find.text('Нэр заавал биш. Хоосон бол дугаараараа явна.'),
      findsOneWidget,
    );
    expectNoOverflow(tester);
  });

  testWidgets('Сондгой тоо дээр сануулга гарна — ТАТГАЛЗАЛ БИШ', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await pump(tester);

    expect(find.text('Сондгой тоо мафид ашигтай.'), findsNothing);
    await tester.tap(find.bySemanticsLabel('Суудал нэмэх'));
    await tester.pump();

    expect(bigCount(tester), '11');
    expect(find.text('Сондгой тоо мафид ашигтай.'), findsOneWidget);
    // Товч ХЭВЭЭР асаалттай — сондгой тоо бол сануулга.
    final FilledButton b = tester.widget(find.byType(FilledButton));
    expect(b.onPressed, isNotNull);
    handle.dispose();
  });

  testWidgets('tooFew — зургаагаас доош бол товч түгжигдэнэ', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await pump(tester);

    // Тоон нэмэгч 6-д зогсоно — доош унах зам нь «Байхгүй хүн».
    for (int i = 0; i < 6; i++) {
      await tester.tap(find.bySemanticsLabel('Суудал хасах'));
      await tester.pump();
    }
    expect(bigCount(tester), '6');
    await tester.tap(find.bySemanticsLabel('Байхгүй хүн').first);
    await tester.pump();
    expect(bigCount(tester), '5');
    expect(
      find.text('Зургаан хүнээс доош ширээнд мафи тоглоом болохгүй.'),
      findsOneWidget,
    );
    final FilledButton b = tester.widget(find.byType(FilledButton));
    expect(b.onPressed, isNull, reason: 'N < 6 үед гарц байхгүй');
    handle.dispose();
  });

  testWidgets('absent — «Байхгүй хүн» дарахад N автоматаар буурна', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await pump(tester);

    await tester.tap(find.bySemanticsLabel('Байхгүй хүн').first);
    await tester.pump();

    expect(bigCount(tester), '9');
    // Тэр суудал жагсаалтаас алга болохгүй — буцааж суулгаж болно.
    expect(find.bySemanticsLabel('Буцааж суулгах'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('Нэр хадгалагдана, хоосон нэр дугаараараа үлдэнэ', (
    WidgetTester tester,
  ) async {
    bool went = false;
    final GameController c = await pump(tester, onContinue: () => went = true);

    await tester.enterText(find.byType(TextField).first, 'Болд');
    await tester.pump();
    await tester.tap(find.text('Үргэлжлүүлэх'));
    await tester.pump();

    expect(went, isTrue);
    expect(c.seatCount, 10);
    expect(c.seatLabel(1), 'Болд');
    expect(c.seatLabel(2), '2-р тоглогч');
    expect(c.hasSavedRoster, isTrue);
  });

  testWidgets('Дараалал солих бариул 48 dp-ээс бага биш', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await pump(tester);
    expectTouchTarget(tester, find.bySemanticsLabel('Дараалал солих').first);
    expectTouchTarget(tester, find.bySemanticsLabel('Байхгүй хүн').first);
    handle.dispose();
  });

  testWidgets('20 суудалтай, 320 px дээр нэг ч мөр халихгүй', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await pump(tester, narrow: true);
    for (int i = 0; i < 10; i++) {
      await tester.tap(find.bySemanticsLabel('Суудал нэмэх'));
      await tester.pump();
    }
    expect(bigCount(tester), '20');
    expectNoOverflow(tester);
    handle.dispose();
  });
}
