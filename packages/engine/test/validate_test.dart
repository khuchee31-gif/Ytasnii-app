// `validate` — GDD-05 §2-ын `RejectCode` хүснэгтийн тест.
// Татгалзлын код тутамд нэг тест, дээр нь `doctorSelfHeal`-ийн гурван горим
// ба `mafiaFriendlyFire`-ийн хоёр байрлал.

import 'dart:typed_data';

import 'package:engine/src/model.dart';
import 'package:engine/src/validate.dart';
import 'package:test/test.dart';

// ---------------------------------------------------------------------------
// Fixture — GDD-05 §11-ийн 12 суудалтай ширээ
// ---------------------------------------------------------------------------
//   1 Ахлагч · 2, 3 Алуурчин · 4 Эмч · 5 Мөрдөгч · 6…12 Иргэн
// ---------------------------------------------------------------------------

const Map<Seat, Role> _roles = <Seat, Role>{
  1: Role.boss,
  2: Role.killer,
  3: Role.killer,
  4: Role.doctor,
  5: Role.detective,
  6: Role.citizen,
  7: Role.citizen,
  8: Role.citizen,
  9: Role.citizen,
  10: Role.citizen,
  11: Role.citizen,
  12: Role.citizen,
};

NightState _state({
  int night = 2,
  Set<Seat>? alive,
  SelfHeal doctorSelfHeal = SelfHeal.once,
  bool mafiaFriendlyFire = true,
  Map<Seat, Seat> lastHealTarget = const <Seat, Seat>{},
  Map<Seat, int> selfHealUsed = const <Seat, int>{},
}) {
  return NightState(
    setup: Setup(
      n: 12,
      roleBySeat: _roles,
      factionRule: FactionRule.designatedKiller,
      doctorSelfHeal: doctorSelfHeal,
      mafiaFriendlyFire: mafiaFriendlyFire,
    ),
    night: night,
    alive: alive ?? <Seat>{1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12},
    seed: Uint8List(32),
    orderPerm: const <Seat>[9, 4, 12, 1, 11, 6, 2, 8, 5, 10, 3, 7],
    lastHealTarget: lastHealTarget,
    selfHealUsed: selfHealUsed,
  );
}

Intent _i(Seat actor, Ability ability, Seat? target, {int night = 2}) => Intent(
      intentId: 'i-$actor-${ability.name}-${target ?? "x"}',
      night: night,
      actor: actor,
      ability: ability,
      target: target,
      clientSeq: 1,
    );

void main() {
  group('Хүчинтэй санаанууд', () {
    test('дүр бүрийн ердийн товшилт хүчинтэй', () {
      final s = _state();
      expect(validate(_i(1, Ability.mafiaKill, 9), s), isNull); // Ахлагч
      expect(validate(_i(2, Ability.mafiaKill, 9), s), isNull); // Алуурчин
      expect(validate(_i(4, Ability.heal, 9), s), isNull); // Эмч
      expect(validate(_i(5, Ability.investigate, 3), s), isNull); // Мөрдөгч
      expect(validate(_i(6, Ability.suspect, 2), s), isNull); // Иргэн
    });
  });

  group('RejectCode — GDD-05 §2-ын хүснэгт', () {
    test('actorDead — лацдах мөчид үхсэн суудлын үйлдэл (N6)', () {
      final s = _state(alive: <Seat>{1, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12});
      expect(validate(_i(2, Ability.mafiaKill, 9), s), RejectCode.actorDead);
    });

    test('targetDead — «Тэр тоглогч хасагдсан.»', () {
      final s = _state(alive: <Seat>{1, 2, 3, 4, 5, 6, 8, 9, 10, 11, 12});
      expect(validate(_i(2, Ability.mafiaKill, 7), s), RejectCode.targetDead);
      expect(validate(_i(4, Ability.heal, 7), s), RejectCode.targetDead);
      expect(validate(_i(5, Ability.investigate, 7), s), RejectCode.targetDead);
    });

    test('targetSelf — «Өөрийгөө сонгож болохгүй.»', () {
      final s = _state();
      expect(validate(_i(5, Ability.investigate, 5), s), RejectCode.targetSelf);
      expect(validate(_i(6, Ability.suspect, 6), s), RejectCode.targetSelf);
    });

    test('targetSameFaction — «Өөрийнхнөө сонгож болохгүй.»', () {
      final s = _state(mafiaFriendlyFire: false);
      expect(validate(_i(2, Ability.mafiaKill, 3), s), RejectCode.targetSameFaction);
      expect(validate(_i(2, Ability.mafiaKill, 1), s), RejectCode.targetSameFaction);
      expect(validate(_i(1, Ability.mafiaKill, 2), s), RejectCode.targetSameFaction);
    });

    test('notYourAbility — дүрдээ үл хамаарах чадвар', () {
      final s = _state();
      expect(validate(_i(4, Ability.mafiaKill, 9), s), RejectCode.notYourAbility);
      expect(validate(_i(2, Ability.heal, 9), s), RejectCode.notYourAbility);
      expect(validate(_i(6, Ability.investigate, 2), s), RejectCode.notYourAbility);
      expect(validate(_i(5, Ability.suspect, 2), s), RejectCode.notYourAbility);
    });

    test('healRepeat — «Өчигдөр аварсан хүнээ дахин аварч болохгүй.»', () {
      final s = _state(lastHealTarget: const <Seat, Seat>{4: 9});
      expect(validate(_i(4, Ability.heal, 9), s), RejectCode.healRepeat);
      // Өөр бай асуудалгүй — GDD-05 §11-ийн 2-р шөнийн жишээ.
      expect(validate(_i(4, Ability.heal, 6), s), isNull);
    });

    test('nightSealed — «Энэ шөнө хаагдсан.»', () {
      final s = _state(night: 2);
      expect(validate(_i(2, Ability.mafiaKill, 9, night: 1), s), RejectCode.nightSealed);
      expect(validate(_i(2, Ability.mafiaKill, 9, night: 3), s), RejectCode.nightSealed);
      expect(validate(_i(2, Ability.mafiaKill, 9, night: 2), s), isNull);
    });

    test('seatNotInGame — ширээнээс гадуурх дугаар', () {
      final s = _state();
      expect(validate(_i(13, Ability.suspect, 2), s), RejectCode.seatNotInGame);
      expect(validate(_i(0, Ability.suspect, 2), s), RejectCode.seatNotInGame);
      expect(validate(_i(6, Ability.suspect, 13), s), RejectCode.seatNotInGame);
      expect(validate(_i(6, Ability.suspect, 0), s), RejectCode.seatNotInGame);
      // `noAction` биш санаа заавал байтай — байгүй бол суудал заагаагүй.
      expect(validate(_i(6, Ability.suspect, null), s), RejectCode.seatNotInGame);
    });
  });

  group('doctorSelfHeal — гурван горим (GDD-03 §4)', () {
    test('unlimited — Эмч өөрийгөө хэдэн ч удаа аварна', () {
      final s = _state(doctorSelfHeal: SelfHeal.unlimited);
      expect(validate(_i(4, Ability.heal, 4), s), isNull);

      final used = _state(
        doctorSelfHeal: SelfHeal.unlimited,
        selfHealUsed: const <Seat, int>{4: 3},
      );
      expect(validate(_i(4, Ability.heal, 4), used), isNull);
    });

    test('once — эхнийх нь хүчинтэй, хоёр дахь нь targetSelf (анхдагч)', () {
      final fresh = _state(doctorSelfHeal: SelfHeal.once);
      expect(validate(_i(4, Ability.heal, 4), fresh), isNull);

      final used = _state(
        doctorSelfHeal: SelfHeal.once,
        selfHealUsed: const <Seat, int>{4: 1},
      );
      expect(validate(_i(4, Ability.heal, 4), used), RejectCode.targetSelf);
      // Бусад байд нөлөөлөхгүй.
      expect(validate(_i(4, Ability.heal, 9), used), isNull);
    });

    test('never — өөрийгөө хэзээ ч аврахгүй', () {
      final s = _state(doctorSelfHeal: SelfHeal.never);
      expect(validate(_i(4, Ability.heal, 4), s), RejectCode.targetSelf);

      final used = _state(
        doctorSelfHeal: SelfHeal.never,
        selfHealUsed: const <Seat, int>{4: 0},
      );
      expect(validate(_i(4, Ability.heal, 4), used), RejectCode.targetSelf);
    });

    test('өөрийгөө аврах эрхтэй ч өчигдрийн бай бол healRepeat', () {
      final s = _state(
        doctorSelfHeal: SelfHeal.unlimited,
        lastHealTarget: const <Seat, Seat>{4: 4},
      );
      expect(validate(_i(4, Ability.heal, 4), s), RejectCode.healRepeat);
    });
  });

  group('mafiaFriendlyFire — хоёр байрлал (GDD-03 §4)', () {
    test('true (анхдагч) — мафи өөрийн хүнээ буудаж болно', () {
      final s = _state(mafiaFriendlyFire: true);
      expect(validate(_i(2, Ability.mafiaKill, 3), s), isNull);
      expect(validate(_i(2, Ability.mafiaKill, 1), s), isNull);
      expect(validate(_i(1, Ability.mafiaKill, 2), s), isNull);
      // Хотынхон руу чиглэсэн ердийн товшилт ч хүчинтэй хэвээр.
      expect(validate(_i(2, Ability.mafiaKill, 9), s), isNull);
    });

    test('false — мафи руу чиглэсэн товшилт татгалзагдана', () {
      final s = _state(mafiaFriendlyFire: false);
      expect(validate(_i(2, Ability.mafiaKill, 3), s), RejectCode.targetSameFaction);
      // Хотынхон руу чиглэсэн товшилт нөлөөлөхгүй.
      expect(validate(_i(2, Ability.mafiaKill, 9), s), isNull);
      expect(validate(_i(1, Ability.mafiaKill, 12), s), isNull);
    });

    test('унтраалга нь зөвхөн mafiaKill-д хамаарна', () {
      final s = _state(mafiaFriendlyFire: false);
      expect(validate(_i(4, Ability.heal, 2), s), isNull);
      expect(validate(_i(5, Ability.investigate, 2), s), isNull);
      expect(validate(_i(6, Ability.suspect, 2), s), isNull);
    });
  });

  group('noAction — ҮРГЭЛЖ хүчинтэй (GDD-05 §1-ийн 1-р дүрэм, N22)', () {
    test('дүр бүрээс, байгүйгээр', () {
      final s = _state();
      for (final seat in _roles.keys) {
        expect(validate(_i(seat, Ability.noAction, null), s), isNull,
            reason: 'суудал $seat');
      }
    });

    test('гэрийн дүрмийн ямар ч тохиргоонд хүчинтэй', () {
      for (final mode in SelfHeal.values) {
        for (final ff in <bool>[true, false]) {
          final s = _state(doctorSelfHeal: mode, mafiaFriendlyFire: ff);
          expect(validate(_i(4, Ability.noAction, null), s), isNull);
          expect(validate(_i(2, Ability.noAction, null), s), isNull);
        }
      }
    });

    test('цонх дуусахад бүртгэгдсэн noAction нь товшсонтой ялгагдахгүй', () {
      // Хоосон товшилт нь хэзээ ч татгалзлын дэлгэц гаргахгүй — эс бөгөөс
      // «хэн алгассан» нь ширээнд харагдана.
      final s = _state(
        alive: <Seat>{1, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12},
        lastHealTarget: const <Seat, Seat>{4: 9},
        doctorSelfHeal: SelfHeal.never,
      );
      expect(validate(_i(4, Ability.noAction, null), s), isNull);
      expect(validate(_i(2, Ability.noAction, null), s), isNull);
      expect(validate(_i(2, Ability.noAction, null, night: 1), s), isNull);
    });
  });

  group('Цэвэр байдал', () {
    test('validate нь дуудагчийн NightState-ыг ӨӨРЧЛӨХГҮЙ', () {
      final alive = <Seat>{1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12};
      final lastHeal = <Seat, Seat>{4: 9};
      final used = <Seat, int>{4: 1};
      final s = NightState(
        setup: const Setup(n: 12, roleBySeat: _roles),
        night: 2,
        alive: alive,
        seed: Uint8List(32),
        orderPerm: const <Seat>[1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12],
        lastHealTarget: lastHeal,
        selfHealUsed: used,
      );

      validate(_i(4, Ability.heal, 9), s);
      validate(_i(4, Ability.heal, 4), s);
      validate(_i(2, Ability.mafiaKill, 9), s);
      validate(_i(13, Ability.suspect, 1), s);

      expect(alive.length, 12);
      expect(lastHeal, <Seat, Seat>{4: 9});
      expect(used, <Seat, int>{4: 1});
      expect(s.night, 2);
    });

    test('ижил оролт → ижил хариу', () {
      final s = _state(mafiaFriendlyFire: false);
      final intent = _i(2, Ability.mafiaKill, 3);
      expect(validate(intent, s), validate(intent, s));
    });
  });
}
