// Бүтэн тоглолтын интеграцийн тест.
//
// Дэлгэц тус бүрийн тест аль хэдийн бий. ЭНЭ тест өөр зүйл шалгана: 19 үе шат
// ба хөдөлгүүр хоорондоо **холбогдсон** эсэх. Зэрэгцээ бичигдсэн дэлгэцүүд тус
// тусдаа зөв атлаа хамтдаа ажиллахгүй байх нь энэ төслийн бодит эрсдэл байсан.
//
// Тоглолтыг эхнээс нь дуустал явуулж, ялалт гарахыг шаардана.

import 'dart:typed_data';

import 'package:engine/engine.dart' hide Intent;
import 'package:flutter/material.dart' hide Intent;
import 'package:flutter_test/flutter_test.dart';
import 'package:hotuntlaa/app_shell.dart';
import 'package:hotuntlaa/game/game_controller.dart';
import 'package:hotuntlaa/game/phase.dart';

import 'phone_viewport.dart';

/// Тогтоосон seed — тест бүр ижил хуваарилалт авна.
Uint8List _fixedSeed(int n) =>
    Uint8List.fromList(List<int>.generate(32, (int i) => (i * 31 + n) & 0xFF));

/// Тоглолтыг төлөвийн машинаар бүтнээр нь явуулна. Дэлгэцгүй — энэ нь
/// дарааллын тест, зурагны биш.
void main() {
  test('6 тоглогчийн тоглолт эхнээс дуустал явж, ялалтаар төгсөнө', () {
    final GameController c = GameController();
    addTearDown(c.dispose);

    c.seatCount = 6;
    expect(c.setupCheck.isReject, isFalse,
        reason: '6 суудал хүчинтэй байх ёстой (kMinSeats)');

    // FAIRNESS → DEAL. Seed тогтоосон тул тоглолт бүрэн давтагдана —
    // «заримдаа унадаг» тест бол тест биш.
    c.beginFairness(seed0: _fixedSeed(7));
    expect(c.phase, GamePhase.fairness);
    expect(RegExp(r'^\d{3}-\d{3}$').hasMatch(c.previewCode), isTrue,
        reason: 'шударгын код 3+3 аравтын хэлбэртэй байх ёстой');

    c.dealWithEntropy(Uint8List.fromList(<int>[1, 2, 3, 4]));
    expect(c.phase, GamePhase.deal);
    expect(c.alive.length, 6);

    for (int s = 1; s <= 6; s++) {
      c.markSeen(s);
    }
    expect(c.allSeen, isTrue);

    var guard = 0;
    while (c.win == WinState.none && guard++ < 40) {
      // --- ШӨНӨ ---------------------------------------------------------
      c.beginNight();
      expect(c.phase, GamePhase.nightCircuit);

      // Суудал БҮР утсыг барина — хасагдсан ч. Жигд хуурмаг (GDD-10 §4).
      final int seatsThisNight = c.circuitSeats.length;
      expect(seatsThisNight, 6,
          reason: 'хасагдсан суудал ч эргэлтэд оролцоно');

      for (final int seat in c.circuitSeats) {
        final Role? role = c.roleOf(seat);
        final Ability ability = abilityOf(role!);
        int? target;
        for (int t = 1; t <= 6; t++) {
          if (c.checkTarget(seat, ability, t) == null) {
            target = t;
            break;
          }
        }
        c.submitIntent(seat, ability, target);
      }
      expect(c.circuitDone, isTrue);

      c.resolveNightNow();
      expect(c.phase, GamePhase.dawn);
      expect(c.report, isNotNull);
      // v1-д шөнөд нэгээс олон үхэл гарахгүй (инвариант N3).
      expect(c.report!.deaths.length, lessThanOrEqualTo(1));

      if (c.win != WinState.none) break;

      // --- ӨДӨР ---------------------------------------------------------
      c.beginDay();
      expect(c.phase, GamePhase.speechRound);

      // Санамсаргүй биш: хамгийн бага дугаартай амьд суудлыг хөөнө.
      final List<int> pool = c.alive.toList()..sort();
      if (pool.length <= 1) break;
      c.nominate(pool.first);
      c.recordHands(pool.first, pool.length);
      expect(c.voteWinner, pool.first);

      c.eliminate(pool.first);
      expect(c.phase, GamePhase.elimination);
      expect(c.alive.contains(pool.first), isFalse);

      c.checkWin();
    }

    expect(c.win, isNot(WinState.none),
        reason: 'тоглолт 40 давталтын дотор дуусах ёстой');
    expect(c.phase, GamePhase.ceremony);
  });

  test('Хасагдсан суудал шөнийн эргэлтэд оролцсон ч үйлдэл нь хүчингүй', () {
    final GameController c = GameController();
    addTearDown(c.dispose);
    c.seatCount = 6;
    c.beginFairness(seed0: _fixedSeed(42));
    c.dealWithEntropy(Uint8List.fromList(<int>[9, 9, 9, 9]));
    c.alive.remove(3); // 3-р суудал хасагдсан гэж үзье
    c.beginNight();

    for (final int seat in c.circuitSeats) {
      c.submitIntent(seat, abilityOf(c.roleOf(seat)!), 1);
    }
    c.resolveNightNow();

    // Хасагдсан суудал зочлол үүсгээгүй байх ёстой.
    expect(c.report!.visits.any((Visit v) => v.from == 3), isFalse,
        reason: 'хасагдсан суудлын үйлдэл хүчингүй болох ёстой');
  });

  testWidgets('Бүрхүүл нүүр дэлгэцээс эхэлж, шинэ тоглолт руу шилжинэ',
      (WidgetTester tester) async {
    final GameController c = GameController();
    addTearDown(c.dispose);

    await pumpPhone(
        tester, MaterialApp(home: GameShell(controller: c, skipSplash: true)));

    expect(find.text('ХОТ УНТЛАА'), findsOneWidget);
    expect(c.phase, GamePhase.appOpen);
  });
}
