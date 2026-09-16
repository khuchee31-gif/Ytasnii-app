// S14 · S15 · S16 — Нэр дэвшүүлэлт, өмгөөлөл, гар өргөх (GDD-06 §S14–S16).
//
// Хамгийн чухал тест: САНАЛ УТСАН ДОТОР БАЙХГҮЙ. Дэлгэц зөвхөн ТООГ авна,
// суудал сонгодог саналын гадаргуу нэг ч байхгүй.

import 'package:engine/engine.dart' show Seat;
import 'package:flutter/material.dart' hide Intent;
import 'package:flutter_test/flutter_test.dart';
import 'package:hotuntlaa/game/game_controller.dart';
import 'package:hotuntlaa/game/settings.dart';
import 'package:hotuntlaa/screens/vote_screen.dart';

import 'deal_test_support.dart';

GameController voteController({
  int seats = 12,
  int day = 2,
  Set<Seat>? alive,
  bool reduceMotion = true,
  TieRule tie = TieRule.fsm,
}) {
  final GameController c = dealtController(seats: seats);
  c.dayNo = day;
  if (alive != null) c.alive = alive;
  c.settings.reduceMotion = reduceMotion;
  c.settings.tieRule = tie;
  return c;
}

/// Хөдөлгөөн багасгах горимд арк нь `−`/`+` болно — тестэд тоо оруулах
/// хамгийн тодорхой зам.
Future<void> setDial(WidgetTester tester, int n) async {
  for (int i = 0; i < n; i++) {
    await tester.tap(find.text('+'));
    await tester.pump();
  }
}

/// 600 мс ДАРЖ-ДҮҮРГЭХ. Товшилт биш.
Future<void> holdConfirm(WidgetTester tester) async {
  final TestGesture g =
      await tester.startGesture(tester.getCenter(find.byType(HoldToConfirm)));
  await tester.pump(const Duration(milliseconds: 900));
  await g.up();
  await tester.pump();
}

Future<void> countFor(WidgetTester tester, int hands) async {
  await setDial(tester, hands);
  await holdConfirm(tester);
}

void main() {
  // --- S14 ------------------------------------------------------------------

  testWidgets('S14 `empty`: «Хэнийг хотоос хөөх вэ?» + амьд суудлын тор',
      (WidgetTester tester) async {
    final GameController c = voteController();
    await pumpScreen(
      tester,
      VoteScreen(controller: c, onExile: (_) {}, onNoExile: () {}),
    );
    expect(find.text('Хэнийг хотоос хөөх вэ?'), findsOneWidget);
    expect(find.text('Хэн ч биш'), findsOneWidget);
    expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
        reason: 'нэр дэвшигчгүй бол «Санал хураая» унтарсан');
  });

  testWidgets('S14 `has`: дээд мөр дүүрч, NOM_ADDED + SEAT_nn дуудагдана',
      (WidgetTester tester) async {
    final GameController c = voteController();
    final List<String> cues = <String>[];
    await pumpScreen(
      tester,
      VoteScreen(
          controller: c,
          onExile: (_) {},
          onNoExile: () {},
          onCue: cues.add),
    );

    await tester.tap(find.text('4'));
    await tester.pump();
    await tester.tap(find.text('9'));
    await tester.pump();

    expect(find.text('Нэр дэвшүүлсэн: №4 · №9'), findsOneWidget);
    expect(cues, <String>[
      'NOM_OPEN',
      'NOM_ADDED',
      'SEAT_04',
      'NOM_ADDED',
      'SEAT_09',
    ]);
  });

  testWidgets('S14 `full`: гурваас илүү болохгүй, дөрөв дэх нь дарагдахгүй',
      (WidgetTester tester) async {
    final GameController c = voteController();
    await pumpScreen(
      tester,
      VoteScreen(controller: c, onExile: (_) {}, onNoExile: () {}),
    );

    for (final String s in <String>['1', '2', '3']) {
      await tester.tap(find.text(s));
      await tester.pump();
    }
    expect(find.text('Гурваас илүү болохгүй.'), findsOneWidget);

    await tester.tap(find.text('4'));
    await tester.pump();
    expect(c.nominations.length, 3);
    expect(c.nominations.contains(4), isFalse);

    // Сонгогдсоныг дахин товшвол буцна — операторын ганц гарц.
    await tester.tap(find.text('2'));
    await tester.pump();
    expect(c.nominations, <Seat>{1, 3});
    expect(find.text('Гурваас илүү болохгүй.'), findsNothing);
  });

  testWidgets('S14 `skipAll`: «Хэн ч биш» → NOM_NONE, шөнө рүү',
      (WidgetTester tester) async {
    final GameController c = voteController();
    final List<String> cues = <String>[];
    int night = 0;
    await pumpScreen(
      tester,
      VoteScreen(
        controller: c,
        onExile: (_) {},
        onNoExile: () => night++,
        onCue: cues.add,
      ),
    );

    await tester.tap(find.text('Хэн ч биш'));
    await tester.pump();
    expect(cues.last, 'NOM_NONE');
    expect(night, 1);
  });

  testWidgets('Өдөр 1, нэр дэвшигч ЯГ НЭГ — санал хураахгүй (GDD-01 §1)',
      (WidgetTester tester) async {
    final GameController c = voteController(day: 1);
    int night = 0;
    await pumpScreen(
      tester,
      VoteScreen(
          controller: c, onExile: (_) {}, onNoExile: () => night++),
    );

    await tester.tap(find.text('4'));
    await tester.pump();
    await tester.tap(find.text('Санал хураая'));
    await tester.pump();
    expect(night, 1);
  });

  testWidgets('Өдөр 1 — өмгөөлөл БАЙХГҮЙ, шууд аркны дэлгэц',
      (WidgetTester tester) async {
    final GameController c = voteController(day: 1);
    await pumpScreen(
      tester,
      VoteScreen(controller: c, onExile: (_) {}, onNoExile: () {}),
    );

    await tester.tap(find.text('4'));
    await tester.pump();
    await tester.tap(find.text('9'));
    await tester.pump();
    await tester.tap(find.text('Санал хураая'));
    await tester.pump();

    expect(find.textContaining('Өмгөөлөл'), findsNothing);
    expect(find.text('№4 — хэдэн гар?'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
  });

  // --- S15 ------------------------------------------------------------------

  testWidgets('S15: 20 секунд, DEFENCE_OPEN → DEFENCE_NEXT + SEAT_nn',
      (WidgetTester tester) async {
    final GameController c = voteController();
    final List<String> cues = <String>[];
    await pumpScreen(
      tester,
      VoteScreen(
        controller: c,
        onExile: (_) {},
        onNoExile: () {},
        onCue: cues.add,
        startAt: VoteStage.defence,
        startBallot: const <Seat>[4, 9],
      ),
    );

    expect(cues, <String>['DEFENCE_OPEN', 'DEFENCE_NEXT', 'SEAT_04']);
    expect(find.text('Өмгөөлөл — №4'), findsOneWidget);
    expect(find.text('0:20'), findsOneWidget);

    await tester.pump(const Duration(seconds: 10));
    expect(cues.last, 'UI_TICK_10');

    // 20 секунд дуусав → 1.2 сек завсар → дараагийн нэр дэвшигч.
    await tester.pump(const Duration(seconds: 10));
    expect(find.text('Өмгөөлөл — №9'), findsNothing);
    await tester.pump(const Duration(milliseconds: 1300));
    expect(find.text('Өмгөөлөл — №9'), findsOneWidget);

    // Хоёр дахь нь дуусмагц DEFENCE_END → S16.
    await tester.pump(const Duration(seconds: 21));
    expect(cues.contains('DEFENCE_END'), isTrue);
    expect(find.text('№4 — хэдэн гар?'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('S15 `skip`: хоёр хуруугаар шудрах → шууд S16',
      (WidgetTester tester) async {
    final GameController c = voteController();
    await pumpScreen(
      tester,
      VoteScreen(
        controller: c,
        onExile: (_) {},
        onNoExile: () {},
        startAt: VoteStage.defence,
        startBallot: const <Seat>[4, 9],
      ),
    );

    final TestGesture a = await tester.startGesture(const Offset(120, 400));
    final TestGesture b = await tester.startGesture(const Offset(220, 400));
    await tester.pump();
    await a.moveBy(const Offset(0, 120));
    await b.moveBy(const Offset(0, 120));
    await tester.pump();
    await a.up();
    await b.up();
    await tester.pump();

    expect(find.text('№4 — хэдэн гар?'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
  });

  // --- S16 ------------------------------------------------------------------

  testWidgets('S16: SEAT_nn → 300 мс → VOTE_ASK, суудал сонгох гадаргуу БИШ',
      (WidgetTester tester) async {
    final GameController c = voteController();
    final List<String> cues = <String>[];
    await pumpScreen(
      tester,
      VoteScreen(
        controller: c,
        onExile: (_) {},
        onNoExile: () {},
        onCue: cues.add,
        startAt: VoteStage.voting,
        startBallot: const <Seat>[4],
      ),
    );

    expect(cues, <String>['VOTE_OPEN', 'SEAT_04']);
    expect(find.text('Эсрэг хэн байна? Гараа өргө.'), findsNothing);
    await tester.pump(const Duration(milliseconds: 350));
    expect(cues.last, 'VOTE_ASK');
    expect(find.text('Эсрэг хэн байна? Гараа өргө.'), findsOneWidget);
    expect(find.text('№4 — хэдэн гар?'), findsOneWidget);
  });

  testWidgets('S16 `tooMany`: амьд − 1-ээс их бол улаан, батлагдахгүй',
      (WidgetTester tester) async {
    final GameController c = voteController(alive: <Seat>{1, 2, 3, 4});
    await pumpScreen(
      tester,
      VoteScreen(
        controller: c,
        onExile: (_) {},
        onNoExile: () {},
        startAt: VoteStage.voting,
        startBallot: const <Seat>[4],
      ),
    );

    await setDial(tester, 4); // амьд 4, дээд тал нь 3 — өөртөө санал байхгүй
    expect(find.text('Амьд хүнээс их байна.'), findsOneWidget);
    await holdConfirm(tester);
    expect(c.hands, isEmpty);

    await tester.tap(find.text('−'));
    await tester.pump();
    expect(find.text('Амьд хүнээс их байна.'), findsNothing);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('S16 `confirming`: 600 мс дарж-дүүргэх, ТОВШИЛТ биш',
      (WidgetTester tester) async {
    final GameController c = voteController();
    List<Seat>? exiled;
    await pumpScreen(
      tester,
      VoteScreen(
        controller: c,
        onExile: (List<Seat> s) => exiled = s,
        onNoExile: () {},
        startAt: VoteStage.voting,
        startBallot: const <Seat>[4],
      ),
    );

    await setDial(tester, 5);
    // Товшилт — юу ч бүртгэгдэхгүй.
    await tester.tap(find.byType(HoldToConfirm));
    await tester.pump();
    expect(c.hands, isEmpty);
    expect(exiled, isNull);

    // Богино дарж тавив — «Товшилт биш — дарж барь.»
    final TestGesture g = await tester
        .startGesture(tester.getCenter(find.byType(HoldToConfirm)));
    await tester.pump(const Duration(milliseconds: 250));
    await g.up();
    await tester.pump();
    expect(c.hands, isEmpty);
    expect(find.text('Товшилт биш — дарж барь.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));

    await holdConfirm(tester);
    expect(c.hands[4], 5);
    expect(exiled, <Seat>[4]);
  });

  testWidgets('Plurality — олонх шаардахгүй, хамгийн олон гар ялна',
      (WidgetTester tester) async {
    final GameController c = voteController();
    List<Seat>? exiled;
    await pumpScreen(
      tester,
      VoteScreen(
        controller: c,
        onExile: (List<Seat> s) => exiled = s,
        onNoExile: () {},
        startAt: VoteStage.voting,
        startBallot: const <Seat>[4, 9, 11],
      ),
    );

    await countFor(tester, 3);
    expect(find.text('№9 — хэдэн гар?'), findsOneWidget);
    await countFor(tester, 4);
    await countFor(tester, 2);

    expect(c.hands, <Seat, int>{4: 3, 9: 4, 11: 2});
    expect(exiled, <Seat>[9], reason: '4 нь 12 амьдаас олонх биш ч ялна');
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('Нэг ч гар өргөгдөөгүй — хэн ч хөөгдөхгүй, VOTE_TIE',
      (WidgetTester tester) async {
    final GameController c = voteController();
    final List<String> cues = <String>[];
    int night = 0;
    await pumpScreen(
      tester,
      VoteScreen(
        controller: c,
        onExile: (_) {},
        onNoExile: () => night++,
        onCue: cues.add,
        startAt: VoteStage.voting,
        startBallot: const <Seat>[4],
      ),
    );
    await holdConfirm(tester);
    expect(cues.last, 'VOTE_TIE');
    expect(night, 1);
  });

  // --- Тэнцлийн гинж (GDD-03 §4.5) -----------------------------------------

  testWidgets('Тэнцэл, ФСМ: VOTE_TIE_SPEECH → тэнцсэн бүрт 30 секунд',
      (WidgetTester tester) async {
    final GameController c = voteController();
    final List<String> cues = <String>[];
    await pumpScreen(
      tester,
      VoteScreen(
        controller: c,
        onExile: (_) {},
        onNoExile: () {},
        onCue: cues.add,
        startAt: VoteStage.voting,
        startBallot: const <Seat>[4, 9],
      ),
    );

    await countFor(tester, 3);
    await countFor(tester, 3);

    expect(cues.contains('VOTE_TIE_SPEECH'), isTrue);
    expect(find.text('Нэмэлт үг — №4'), findsOneWidget);
    expect(find.text('0:30'), findsOneWidget);

    // 30 + 1.2 + 30 → дахин санал, зөвхөн тэнцсэн хоёр.
    await tester.pump(const Duration(seconds: 31));
    await tester.pump(const Duration(milliseconds: 1300));
    expect(find.text('Нэмэлт үг — №9'), findsOneWidget);
    await tester.pump(const Duration(seconds: 31));
    expect(find.text('№4 — хэдэн гар?'), findsOneWidget);
    expect(c.hands, isEmpty, reason: 'дахин санал шинээр тоологдоно');
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('Дахиад тэнцвэл «бүгдийн хувь заяа», олонх дэмжвэл БҮГД гарна',
      (WidgetTester tester) async {
    final GameController c = voteController(alive: <Seat>{1, 2, 3, 4, 5, 9});
    List<Seat>? exiled;
    await pumpScreen(
      tester,
      VoteScreen(
        controller: c,
        onExile: (List<Seat> s) => exiled = s,
        onNoExile: () {},
        startAt: VoteStage.allFate,
        startBallot: const <Seat>[4, 9],
      ),
    );

    expect(find.text('Бүгдийн хувь заяа — хэдэн гар?'), findsOneWidget);
    // 6 амьд — 4 гар бол олонх.
    await countFor(tester, 4);
    expect(exiled, <Seat>[4, 9]);
  });

  testWidgets('«Бүгдийн хувь заяа» олонх бүрдээгүй — хэн ч хөөгдөхгүй',
      (WidgetTester tester) async {
    final GameController c = voteController(alive: <Seat>{1, 2, 3, 4, 5, 9});
    final List<String> cues = <String>[];
    int night = 0;
    await pumpScreen(
      tester,
      VoteScreen(
        controller: c,
        onExile: (_) {},
        onNoExile: () => night++,
        onCue: cues.add,
        startAt: VoteStage.allFate,
        startBallot: const <Seat>[4, 9],
      ),
    );

    await countFor(tester, 3); // 3 нь 6-гийн олонх БИШ
    expect(cues.last, 'VOTE_TIE');
    expect(night, 1);
  });

  testWidgets('tieRule = «Хэн ч хөөгдөхгүй» — VOTE_TIE, нэмэлт үг БАЙХГҮЙ',
      (WidgetTester tester) async {
    final GameController c = voteController(tie: TieRule.noElim);
    final List<String> cues = <String>[];
    int night = 0;
    await pumpScreen(
      tester,
      VoteScreen(
        controller: c,
        onExile: (_) {},
        onNoExile: () => night++,
        onCue: cues.add,
        startAt: VoteStage.voting,
        startBallot: const <Seat>[4, 9],
      ),
    );

    await countFor(tester, 2);
    await countFor(tester, 2);
    expect(cues.last, 'VOTE_TIE');
    expect(cues.contains('VOTE_TIE_SPEECH'), isFalse);
    expect(night, 1);
  });

  testWidgets('tieRule = «Санамсаргүй» — апп тэнцсэн хоёрын нэгийг сонгоно',
      (WidgetTester tester) async {
    final GameController c = voteController(tie: TieRule.random);
    List<Seat>? exiled;
    await pumpScreen(
      tester,
      VoteScreen(
        controller: c,
        onExile: (List<Seat> s) => exiled = s,
        onNoExile: () {},
        startAt: VoteStage.voting,
        startBallot: const <Seat>[4, 9],
      ),
    );

    await countFor(tester, 2);
    await countFor(tester, 2);
    expect(exiled, isNotNull);
    expect(exiled!.length, 1);
    expect(<Seat>[4, 9].contains(exiled!.single), isTrue);
  });

  // --- Хэл ба дэлгэцийн хатуу дүрмүүд ---------------------------------------

  testWidgets('«Цаазлах» гэсэн үг S14-т ХААНА Ч БАЙХГҮЙ',
      (WidgetTester tester) async {
    final GameController c = voteController();
    await pumpScreen(
      tester,
      VoteScreen(controller: c, onExile: (_) {}, onNoExile: () {}),
    );
    expect(find.textContaining('аазл'), findsNothing);
    // Оронд нь «Хотоос хөөх» — GDD-00 §11.
    expect(find.text('Хэнийг хотоос хөөх вэ?'), findsOneWidget);
  });

  testWidgets('Зүүн гар: арк доод ЗҮҮН булан болж эргэнэ',
      (WidgetTester tester) async {
    final GameController c = voteController(reduceMotion: false);
    c.settings.leftHanded = true;
    await pumpScreen(
      tester,
      VoteScreen(
        controller: c,
        onExile: (_) {},
        onNoExile: () {},
        startAt: VoteStage.voting,
        startBallot: const <Seat>[4],
      ),
    );
    expect(tester.widget<VoteDial>(find.byType(VoteDial)).leftHanded, isTrue);

    // Арк дээр эрхийгээр татахад тоо өөрчлөгдөнө.
    final Rect box = tester.getRect(find.byType(VoteDial));
    final TestGesture g = await tester.startGesture(
        Offset(box.left + 8, box.bottom - 8));
    await g.moveTo(Offset(box.left + box.width * 0.5, box.center.dy));
    await tester.pump();
    await g.up();
    await tester.pump();
    expect(tester.widget<VoteDial>(find.byType(VoteDial)).value,
        greaterThan(0));
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('320 логик px дээр мөр халихгүй', (WidgetTester tester) async {
    final GameController c = voteController(seats: 20, day: 2);
    await pumpScreen(
      tester,
      VoteScreen(controller: c, onExile: (_) {}, onNoExile: () {}),
      size: kPhoneNarrow,
    );
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('1'));
    await tester.pump();
    await tester.tap(find.text('2'));
    await tester.pump();
    await tester.tap(find.text('Санал хураая'));
    await tester.pump();
    expect(tester.takeException(), isNull, reason: 'S15 халив');

    await tester.pump(const Duration(seconds: 42));
    expect(tester.takeException(), isNull, reason: 'S16 халив');
    await tester.pump(const Duration(seconds: 1));
  });
}
