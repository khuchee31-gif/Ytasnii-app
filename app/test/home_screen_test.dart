// S00 / S01 — Splash ба Нүүр. GDD-06.

import 'package:flutter/material.dart' hide Intent;
import 'package:flutter_test/flutter_test.dart';
import 'package:hotuntlaa/game/game_controller.dart';
import 'package:hotuntlaa/game/phase.dart';
import 'package:hotuntlaa/screens/home_screen.dart';

import 'phone_viewport.dart';

void main() {
  group('S00 — Splash', () {
    testWidgets('Лого гарна, тоолуур БАЙХГҮЙ', (WidgetTester tester) async {
      await pumpPhone(
        tester,
        SplashScreen(onReady: () {}, hold: const Duration(seconds: 1)),
      );

      // Гарчиг хоёр мөр болсон: «ХОТ» дээр, «УНТЛАА» доор. Сүүлийнх нь
      // өнгө хуваасан тул ГУРВАН хуулбартай — уншигчид нэг л шошго хүрнэ.
      expect(find.text('ХОТ'), findsOneWidget);
      expect(find.text('УНТЛАА'), findsNWidgets(3));
      // Ямар ч тоо, ямар ч товч байхгүй.
      expect(find.byType(FilledButton), findsNothing);
      expectNoOverflow(tester);
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('Нэг секундын дараа S01 руу шилжинэ', (
      WidgetTester tester,
    ) async {
      bool ready = false;
      await pumpPhone(tester, SplashScreen(onReady: () => ready = true));
      expect(ready, isFalse);
      await tester.pump(const Duration(milliseconds: 1000));
      expect(ready, isTrue);
    });

    testWidgets('assetFail — дуугүй үргэлжлүүлнэ', (WidgetTester tester) async {
      bool ready = false;
      await pumpPhone(
        tester,
        SplashScreen(onReady: () => ready = true, audioFailed: true),
      );

      expect(
        find.text('Дуу ачаалагдсангүй. Тоглоом дуугүй ажиллана.'),
        findsOneWidget,
      );
      await tester.pump(const Duration(seconds: 3));
      expect(ready, isFalse, reason: 'assetFail өөрөө шилжихгүй');
      await tester.tap(find.text('Үргэлжлүүлэх'));
      expect(ready, isTrue);
    });
  });

  group('S01 — Нүүр', () {
    Widget home(
      GameController c, {
      VoidCallback? onResume,
      bool bituun = false,
      VoidCallback? onNew,
    }) {
      return HomeScreen(
        controller: c,
        onNewGame: onNew ?? () {},
        onSameSeats: () {},
        onSettings: () {},
        onHelp: () {},
        onResume: onResume,
        bituun: bituun,
      );
    }

    testWidgets('firstRun — НЭГ товч, нэр, өөр юу ч биш', (
      WidgetTester tester,
    ) async {
      final GameController c = GameController();
      addTearDown(c.dispose);
      await pumpPhone(tester, home(c));

      // Гарчиг хоёр мөр болсон: «ХОТ» дээр, «УНТЛАА» доор. Сүүлийнх нь
      // өнгө хуваасан тул ГУРВАН хуулбартай — уншигчид нэг л шошго хүрнэ.
      expect(find.text('ХОТ'), findsOneWidget);
      expect(find.text('УНТЛАА'), findsNWidgets(3));
      expect(find.text('Нэг утсаар тоглох'), findsOneWidget);
      // Үндсэн товч ГАНЦ. «Шинэ бүрэлдэхүүн» энэ төлөвт байхгүй.
      expect(find.byType(FilledButton), findsOneWidget);
      expect(find.text('Шинэ бүрэлдэхүүн'), findsNothing);
      expectNoOverflow(tester);
    });

    testWidgets('Үндсэн товч 88 dp, доод гуравны нэгд', (
      WidgetTester tester,
    ) async {
      final GameController c = GameController();
      addTearDown(c.dispose);
      await pumpPhone(tester, home(c));

      final Finder btn = find.byType(FilledButton);
      expect(tester.getSize(btn).height, 88.0);
      // Доод гуравны нэг: 800 логик px-ийн 533-аас доош.
      expect(tester.getTopLeft(btn).dy, greaterThan(800 / 3 * 2));
    });

    testWidgets('hasRoster — «Дахин — ижил суудлаар» ба жижиг хоёр дахь мөр', (
      WidgetTester tester,
    ) async {
      final GameController c = GameController()..hasSavedRoster = true;
      addTearDown(c.dispose);
      await pumpPhone(tester, home(c));

      expect(find.text('Дахин — ижил суудлаар'), findsOneWidget);
      expect(find.text('Шинэ бүрэлдэхүүн'), findsOneWidget);
    });

    testWidgets('TalkBack: «Дахин тоглох, ижил суудлаар, арван хоёр тоглогч»', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      final GameController c = GameController()
        ..hasSavedRoster = true
        ..seatCount = 12;
      addTearDown(c.dispose);
      await pumpPhone(tester, home(c));

      expect(
        find.bySemanticsLabel(
          'Дахин тоглох, ижил суудлаар, арван хоёр тоглогч',
        ),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('midGame — «Үргэлжлүүлэх — Шөнө N»', (
      WidgetTester tester,
    ) async {
      final GameController c = GameController();
      addTearDown(c.dispose);
      c.go(GamePhase.nightCircuit);
      await pumpPhone(tester, home(c, onResume: () {}));

      expect(find.textContaining('Үргэлжлүүлэх — Шөнө'), findsOneWidget);
    });

    testWidgets('bituun — «Золгоё», цагаан-мөнгөлөг', (
      WidgetTester tester,
    ) async {
      final GameController c = GameController();
      addTearDown(c.dispose);
      await pumpPhone(tester, home(c, bituun: true));

      expect(find.text('Золгоё'), findsOneWidget);
      final Scaffold s = tester.widget(find.byType(Scaffold));
      expect(s.backgroundColor, const Color(0xFFE8ECF2));
    });

    testWidgets('Доод дүрсүүд 48 dp-ээс бага биш', (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      final GameController c = GameController();
      addTearDown(c.dispose);
      await pumpPhone(tester, home(c));

      expectTouchTarget(tester, find.bySemanticsLabel('Тохиргоо'));
      expectTouchTarget(tester, find.bySemanticsLabel('Тусламж'));
      handle.dispose();
    });

    testWidgets('320 px дээр халихгүй', (WidgetTester tester) async {
      final GameController c = GameController()..hasSavedRoster = true;
      addTearDown(c.dispose);
      await pumpNarrow(tester, home(c));
      expectNoOverflow(tester);
    });
  });
}
