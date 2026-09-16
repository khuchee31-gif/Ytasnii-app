// S11 — Үүрийн тестүүд (GDD-06 §S11, инвариант N14).
//
// Энэ файлын хамгийн чухал тест нь «2500 мс нь БОДИТ» гэсэн мөр. Тэр завсар
// бол тоглоомын хамгийн хурцадмал агшин бөгөөд код review-ийн шалгуур —
// сэтгэл санаа биш. Яарсан хөгжүүлэгч түүнийг хаавал энэ тест улаан болно.

import 'package:engine/engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hotuntlaa/game/game_controller.dart';
import 'package:hotuntlaa/screens/dawn_screen.dart';

import 'deal_test_support.dart';
import 'night_test_support.dart';

/// Хохирогчтой шөнө: бүх мафи нэг байг онилно, Эмч ӨӨРИЙГӨӨ аварна (тиймээс
/// хохирогч аврагдахгүй), Мөрдөгч ба Иргэд нэг суудлыг товшиж шивнээ төрүүлнэ.
GameController dawnWithVictim({int seats = 12}) {
  final GameController c = nightController(seats: seats);
  final Seat doctor = seatWithAbility(c, Ability.heal);
  final Seat victim = <Seat>[1, 2, 3].firstWhere((Seat s) => s != doctor);
  final Seat gossip =
      <Seat>[9, 10, 11, 8].firstWhere((Seat s) => s != doctor && s != victim);

  resolveWholeNight(c, target: (Seat seat, Ability a) {
    if (a == Ability.mafiaKill) return victim;
    if (a == Ability.heal) return doctor; // өөрийгөө — `SelfHeal.once`
    return gossip;
  });
  return c;
}

/// Хохирогчгүй шөнө: хэн ч товшоогүй.
GameController dawnNoKill({int seats = 12}) {
  final GameController c = nightController(seats: seats);
  resolveWholeNight(c);
  return c;
}

void main() {
  testWidgets('N14 — `DAWN_A` ба хохирогчийн хооронд БОДИТ 2500 мс',
      (WidgetTester tester) async {
    final GameController c = dawnWithVictim();
    final Seat victim = c.report!.deaths.first.victim;
    final List<String> cues = <String>[];

    await pumpScreen(
        tester, DawnScreen(controller: c, onDone: () {}, onCue: cues.add));

    // Мөр 1 — нүүрс 1.5 секунд. Хохирогчийн дугаар хараахан БАЙХГҮЙ.
    expect(cues, isEmpty);
    await tester.pump(const Duration(milliseconds: 1400));
    expect(cues, isEmpty);

    await tester.pump(const Duration(milliseconds: 200));
    expect(cues, <String>['DAWN_A']);
    expect(find.text('№$victim'), findsNothing, reason: 'мөр 2–3 нь ХООСОН');

    // Мөр 3 — 2500 мс. `DAWN_A` нь t = 1500-д хэлэгдсэн тул хохирогч нь
    // t = 4000-аас өмнө ХЭЗЭЭ Ч гарахгүй. t = 3900 дээр дэлгэц хоосон хэвээр.
    await tester.pump(const Duration(milliseconds: 2300));
    expect(cues, <String>['DAWN_A'], reason: 'завсрыг хаах зам байхгүй');
    expect(find.text('№$victim'), findsNothing);

    await tester.pump(const Duration(milliseconds: 200));
    expect(cues.last, 'DAWN_VICTIM_${victim.toString().padLeft(2, '0')}');
    expect(find.text('№$victim'), findsOneWidget);

    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('`DAY_START` нь хохирогчийн ДАРАА, 1800 мс-д «Өдөр 1»',
      (WidgetTester tester) async {
    final GameController c = dawnWithVictim();
    final List<String> cues = <String>[];
    await pumpScreen(
        tester, DawnScreen(controller: c, onDone: () {}, onCue: cues.add));

    await tester.pump(const Duration(milliseconds: 4000)); // 1500 + 2500
    expect(cues.length, 2);
    expect(find.text('Өдөр 1'), findsNothing);

    await tester.pump(const Duration(milliseconds: 1700));
    expect(find.text('Өдөр 1'), findsNothing);
    await tester.pump(const Duration(milliseconds: 200));
    expect(cues.last, 'DAY_START');
    expect(find.text('Өдөр 1'), findsOneWidget);

    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('Шивнээ — дугаарууд ЗӨВХӨН дэлгэц дээр, хоолойгоор ХЭЗЭЭ Ч үгүй',
      (WidgetTester tester) async {
    final GameController c = dawnWithVictim();
    expect(c.report!.whisper, isNotEmpty,
        reason: 'тестийн урьдчилсан нөхцөл: шивнээ төрсөн байх ёстой');
    final List<Seat> whisper = c.report!.whisper;
    final List<String> cues = <String>[];

    await pumpScreen(
        tester, DawnScreen(controller: c, onDone: () {}, onCue: cues.add));
    // 1500 + 2500 + 1800 + 2000 + 600 = 8400 мс.
    await tester.pump(const Duration(seconds: 6));
    await tester.pump(const Duration(milliseconds: 2500));

    expect(find.text('Хот шивнэж байна.'), findsOneWidget);
    expect(find.text('Шивнээ: ${whisper.join(' · ')}'), findsOneWidget);

    // Клипийн урсгалд дугаар БАЙХГҮЙ.
    expect(cues, <String>[
      'DAWN_A',
      'DAWN_VICTIM_${c.report!.deaths.first.victim.toString().padLeft(2, '0')}',
      'DAY_START',
      'WHISPER',
    ]);
    for (final Seat s in whisper) {
      expect(cues.contains('$s'), isFalse);
      expect(cues.contains('SEAT_${s.toString().padLeft(2, '0')}'), isFalse);
    }
  });

  testWidgets('Хохирогчгүй — «Өнөө шөнө хохирогч гарсангүй.», яагаад гэж ХЭЛЭХГҮЙ',
      (WidgetTester tester) async {
    final GameController c = dawnNoKill();
    final List<String> cues = <String>[];
    await pumpScreen(
        tester, DawnScreen(controller: c, onDone: () {}, onCue: cues.add));

    await tester.pump(const Duration(milliseconds: 1600));
    expect(cues, <String>['DAWN_NO_KILL']);
    expect(find.text('Өнөө шөнө хохирогч гарсангүй.'), findsOneWidget);
    // Эмч таарсан уу, мафи товшоогүй юу — апп аль нь болохыг ХЭЗЭЭ Ч хэлэхгүй.
    expect(find.textContaining('Эмч'), findsNothing);
    expect(find.textContaining('аврагд'), findsNothing);

    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('Урсгал дуустал «Үргэлжлүүлэх» товч ГАРАХГҮЙ',
      (WidgetTester tester) async {
    final GameController c = dawnWithVictim();
    bool done = false;
    await pumpScreen(
        tester, DawnScreen(controller: c, onDone: () => done = true));

    // Чимээгүйн дунд алгасах товч байх ёсгүй.
    await tester.pump(const Duration(milliseconds: 2500));
    expect(find.text('Үргэлжлүүлэх'), findsNothing);

    await tester.pump(const Duration(seconds: 8));
    expect(find.text('Үргэлжлүүлэх'), findsOneWidget);
    await tester.tap(find.text('Үргэлжлүүлэх'));
    await tester.pump();
    expect(done, isTrue);
  });

  testWidgets('160 sp хохирогчийн дугаар 320 логик px дээр ч халихгүй',
      (WidgetTester tester) async {
    // 20 суудал — «№20» бол хамгийн өргөн тохиолдол.
    final GameController c = nightController(seats: 20);
    final Seat doctor = seatWithAbility(c, Ability.heal);
    final Seat victim = doctor == 20 ? 19 : 20;
    resolveWholeNight(c, target: (Seat seat, Ability a) {
      if (a == Ability.mafiaKill) return victim;
      if (a == Ability.heal) return doctor;
      return null;
    });
    expect(c.report!.deaths.first.victim, victim);

    await pumpScreen(
      tester,
      DawnScreen(controller: c, onDone: () {}),
      size: kPhoneNarrow,
    );
    await tester.pump(const Duration(seconds: 5));
    expect(find.text('№$victim'), findsOneWidget);
    expect(tester.takeException(), isNull, reason: 'Дэлгэц халив');
    await tester.pump(const Duration(seconds: 6));
  });
}
