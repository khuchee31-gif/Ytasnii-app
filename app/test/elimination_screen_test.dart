// S17 — Хасалтын тестүүд (GDD-06 §S17, GDD-07 §2.8, GDD-08 §2).
//
// ХАМГИЙН ЧУХАЛ ТЕСТ: дүр НЭЭГДЭХГҮЙ. Энэ бол S19-ийг үнэ цэнтэй болгодог
// цорын ганц зүйл — тэр тест эвдэрвэл ёслол өөрөө утгагүй болно.

import 'package:engine/engine.dart' show Role, Seat;
import 'package:flutter/material.dart' hide Intent;
import 'package:flutter_test/flutter_test.dart';
import 'package:hotuntlaa/game/game_controller.dart';
import 'package:hotuntlaa/screens/elimination_screen.dart';
import 'package:hotuntlaa/screens/reveal_screen.dart' show cardCopyFor;

import 'deal_test_support.dart';

GameController elimController({int seats = 12, int day = 2}) {
  final GameController c = dealtController(seats: seats);
  c.dayNo = day;
  return c;
}

/// Дэлгэц дээр дүрийн нэр НЭГ Ч удаа гарахгүй.
void expectNoRoleWords(WidgetTester tester) {
  for (final Role r in Role.values) {
    expect(
      find.textContaining(cardCopyFor(r).mechanic),
      findsNothing,
      reason: '«${cardCopyFor(r).mechanic}» хасалтад нээгдэж болохгүй',
    );
    expect(find.textContaining(cardCopyFor(r).theme), findsNothing);
  }
}

void main() {
  testWidgets('ELIM_A → 2,000 мс ЧИМЭЭГҮЙ → SEAT_04 → 120 мс → ELIM_B', (
    WidgetTester tester,
  ) async {
    final GameController c = elimController();
    final List<String> cues = <String>[];
    await pumpScreen(
      tester,
      EliminationScreen(
        controller: c,
        seats: const <Seat>[4],
        onDone: () {},
        onCue: cues.add,
      ),
    );

    expect(cues, <String>['ELIM_A']);
    // Хоёр секунд — дэлгэц дээр НЭГ Ч ҮГ БАЙХГҮЙ.
    expect(find.byType(Text), findsNothing);
    await tester.pump(const Duration(milliseconds: 1900));
    expect(cues, <String>['ELIM_A']);
    expect(find.byType(Text), findsNothing);

    await tester.pump(const Duration(milliseconds: 200));
    expect(cues.last, 'SEAT_04');
    expect(find.text('№4'), findsOneWidget);
    expect(find.text('Хотоос хөөгдлөө.'), findsNothing);

    // 600 мс дүүрэлт + 120 мс → ELIM_B.
    await tester.pump(const Duration(milliseconds: 900));
    expect(cues.contains('ELIM_B'), isTrue);
    expect(find.text('Хотоос хөөгдлөө.'), findsOneWidget);
    expectNoRoleWords(tester);

    await tester.pump(const Duration(seconds: 40));
  });

  testWidgets('Дүр ХЭЗЭЭ Ч нээгдэхгүй — анхдагч тохиргоо', (
    WidgetTester tester,
  ) async {
    final GameController c = elimController();
    expect(c.settings.revealRoleOnDeath, isFalse);
    await pumpScreen(
      tester,
      EliminationScreen(controller: c, seats: const <Seat>[4], onDone: () {}),
    );

    await tester.pump(const Duration(seconds: 3));
    expectNoRoleWords(tester);
    expect(find.textContaining('байлаа'), findsNothing);
    await tester.pump(const Duration(seconds: 40));
  });

  testWidgets('ELIM_NO_REVEAL — зөвхөн эхний гурван тоглолтод', (
    WidgetTester tester,
  ) async {
    final GameController c = elimController()..gamesPlayed = 0;
    final List<String> cues = <String>[];
    await pumpScreen(
      tester,
      EliminationScreen(
        controller: c,
        seats: const <Seat>[4],
        onDone: () {},
        onCue: cues.add,
      ),
    );
    await tester.pump(const Duration(seconds: 3));
    expect(cues.contains('ELIM_NO_REVEAL'), isTrue);
    await tester.pump(const Duration(seconds: 40));

    final GameController old = elimController()..gamesPlayed = 9;
    final List<String> cues2 = <String>[];
    await pumpScreen(
      tester,
      EliminationScreen(
        controller: old,
        seats: const <Seat>[4],
        onDone: () {},
        onCue: cues2.add,
      ),
    );
    await tester.pump(const Duration(seconds: 3));
    expect(cues2.contains('ELIM_NO_REVEAL'), isFalse);
    await tester.pump(const Duration(seconds: 40));
  });

  testWidgets('`revealOn`: «Тэрээр {ДҮР} байлаа.» — АУДИО БАЙХГҮЙ', (
    WidgetTester tester,
  ) async {
    final GameController c = elimController();
    c.settings.revealRoleOnDeath = true;
    final List<String> cues = <String>[];
    await pumpScreen(
      tester,
      EliminationScreen(
        controller: c,
        seats: const <Seat>[4],
        onDone: () {},
        onCue: cues.add,
      ),
    );

    await tester.pump(const Duration(seconds: 3));
    final String role = cardCopyFor(c.roleOf(4)!).mechanic;
    expect(find.text('Тэрээр $role байлаа.'), findsOneWidget);
    // `ROLE_*` гэсэн клип каталогт БАЙХГҮЙ (GDD-07 §2.1).
    expect(cues.any((String s) => s.startsWith('ROLE_')), isFalse);
    await tester.pump(const Duration(seconds: 40));
  });

  testWidgets('Сүүлчийн үг: ELIM_LASTWORD, `lastWordsSeconds` тоологдоно', (
    WidgetTester tester,
  ) async {
    final GameController c = elimController();
    final List<String> cues = <String>[];
    bool done = false;
    await pumpScreen(
      tester,
      EliminationScreen(
        controller: c,
        seats: const <Seat>[4],
        onDone: () => done = true,
        onCue: cues.add,
      ),
    );

    await tester.pump(const Duration(seconds: 4));
    expect(cues.last, 'ELIM_LASTWORD');
    expect(find.text('Сүүлчийн үг'), findsOneWidget);
    expect(find.text('30'), findsOneWidget);

    await tester.pump(const Duration(seconds: 10));
    expect(find.text('20'), findsOneWidget);
    expect(done, isFalse);

    await tester.pump(const Duration(seconds: 21));
    expect(done, isTrue);
  });

  testWidgets('«Дуусгах» дарвал сүүлчийн үг тэр дор нь дуусна', (
    WidgetTester tester,
  ) async {
    final GameController c = elimController();
    bool done = false;
    await pumpScreen(
      tester,
      EliminationScreen(
        controller: c,
        seats: const <Seat>[4],
        onDone: () => done = true,
      ),
    );

    await tester.pump(const Duration(seconds: 4));
    await tester.tap(find.text('Дуусгах'));
    await tester.pump();
    expect(done, isTrue);
  });

  testWidgets('«Бүгдийн хувь заяа» — хоёр суудал зэрэг хөөгдөнө', (
    WidgetTester tester,
  ) async {
    final GameController c = elimController();
    final List<String> cues = <String>[];
    await pumpScreen(
      tester,
      EliminationScreen(
        controller: c,
        seats: const <Seat>[4, 9],
        onDone: () {},
        onCue: cues.add,
      ),
    );

    await tester.pump(const Duration(milliseconds: 2100));
    expect(cues.last, 'SEAT_04');
    await tester.pump(const Duration(milliseconds: 800));
    expect(cues.last, 'SEAT_09');
    expect(find.text('№4 · №9'), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
    expect(cues.contains('ELIM_B'), isTrue);
    expectNoRoleWords(tester);
    await tester.pump(const Duration(seconds: 40));
  });

  testWidgets('«ялагдал» гэсэн үг S17-д БАЙХГҮЙ', (WidgetTester tester) async {
    final GameController c = elimController();
    await pumpScreen(
      tester,
      EliminationScreen(controller: c, seats: const <Seat>[4], onDone: () {}),
    );
    await tester.pump(const Duration(seconds: 4));
    expect(find.textContaining('ялагд'), findsNothing);
    expect(find.textContaining('аазл'), findsNothing);
    await tester.pump(const Duration(seconds: 40));
  });

  testWidgets('320 логик px дээр мөр халихгүй', (WidgetTester tester) async {
    final GameController c = elimController(seats: 20);
    c.settings.revealRoleOnDeath = true;
    await pumpScreen(
      tester,
      EliminationScreen(
        controller: c,
        seats: const <Seat>[18, 19, 20],
        onDone: () {},
      ),
      size: kPhoneNarrow,
    );
    await tester.pump(const Duration(seconds: 5));
    expect(tester.takeException(), isNull, reason: 'Дэлгэц халив');
    await tester.pump(const Duration(seconds: 40));
  });
}
