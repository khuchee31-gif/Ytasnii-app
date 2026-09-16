// Манаач (v3) — эрсдэл ба ҮР ДАГАВАР.
//
// Хотынхны цорын ганц алагч. Шөнө хоёр удаа буудна (эхний шөнө БИШ).
// ХОТЫНХНЫ ХҮНИЙГ буудвал дараагийн шөнө гэмшлээсээ үхэх бөгөөд тэр
// үхлийг ЭМЧЛЭХ БОЛОМЖГҮЙ.
//
// «Эмчилж болохгүй» гэдэг нь тусгай тохиолдол БИШ, АРИФМЕТИК:
// `DefenseLevel`-д `powerful` хос БАЙХГҮЙ тул
// `lethal(powerful, basic)` = `2 > 1` = ҮРГЭЛЖ үнэн.

import 'dart:convert';
import 'dart:typed_data';

import 'package:engine/src/hash.dart';
import 'package:engine/src/model.dart';
import 'package:engine/src/resolve.dart';
import 'package:engine/src/rosters.dart';
import 'package:engine/src/validate.dart';
import 'package:test/test.dart';

Uint8List seedOf(String label) => sha256(utf8.encode('vig/$label'));

Intent it(Seat actor, Ability ability, Seat? target,
        {int night = 2, int clientSeq = 1}) =>
    Intent(
      intentId: '${night}_${actor}_${ability.name}_$clientSeq',
      night: night,
      actor: actor,
      ability: ability,
      target: target,
      clientSeq: clientSeq,
    );

/// P1·P2 Алуурчин, P3 Эмч, P4 Мөрдөгч, P5 Манаач, P6…P8 Иргэн.
const Map<Seat, Role> kV8 = <Seat, Role>{
  1: Role.killer,
  2: Role.killer,
  3: Role.doctor,
  4: Role.detective,
  5: Role.vigilante,
  6: Role.citizen,
  7: Role.citizen,
  8: Role.citizen,
};

NightState night({
  List<Seat> alive = const <Seat>[1, 2, 3, 4, 5, 6, 7, 8],
  int no = 2,
  Map<Seat, int> bullets = const <Seat, int>{5: 2},
  Set<Seat> remorse = const <Seat>{},
}) =>
    NightState(
      setup: const Setup(n: 8, roleBySeat: kV8),
      night: no,
      alive: alive.toSet(),
      seed: seedOf('base'),
      orderPerm: const <Seat>[1, 2, 3, 4, 5, 6, 7, 8],
      bullets: bullets,
      remorse: remorse,
    );

List<Intent> fill(List<Intent> given, NightState s) {
  final Set<Seat> acted = given.map((Intent i) => i.actor).toSet();
  return <Intent>[
    ...given,
    for (final Seat x in s.alive)
      if (!acted.contains(x)) it(x, Ability.noAction, null, night: s.night),
  ];
}

void main() {
  group('Буудлага', () {
    test('мафитай ЗЭРЭГ хоёр хүн үхнэ', () {
      final NightState s = night();
      final NightReport r = resolveNight(
        s,
        fill(<Intent>[
          it(1, Ability.mafiaKill, 7),
          it(2, Ability.mafiaKill, 7),
          it(5, Ability.vigilanteKill, 1),
        ], s),
      );
      expect(r.deaths.map((Death d) => d.victim).toList(), <Seat>[1, 7],
          reason: 'суудлын дугаараар эрэмбэлэгдэх ёстой');
      expect(r.deaths.firstWhere((Death d) => d.victim == 1).tag,
          DeathTag.vigilante);
      expect(r.deaths.firstWhere((Death d) => d.victim == 7).tag, DeathTag.mafi);
    });

    test('сум ХАСАГДАНА', () {
      final NightState s = night();
      final NightReport r = resolveNight(
        s,
        fill(<Intent>[
          it(1, Ability.mafiaKill, 7),
          it(2, Ability.mafiaKill, 7),
          it(5, Ability.vigilanteKill, 1),
        ], s),
      );
      expect(r.nextBullets[5], 1);
    });

    test('Эмч Манаачийн байг ч аварна', () {
      final NightState s = night();
      final NightReport r = resolveNight(
        s,
        fill(<Intent>[
          it(1, Ability.mafiaKill, 8),
          it(2, Ability.mafiaKill, 8),
          it(3, Ability.heal, 6),
          it(5, Ability.vigilanteKill, 6),
        ], s),
      );
      expect(r.deaths.map((Death d) => d.victim).toList(), <Seat>[8]);
      expect(r.nextRemorse, isEmpty, reason: 'аврагдсан бол гэмшил үүсэхгүй');
    });

    test('НЭГ хохирогчийг хоёул онивол НЭГ л үхэл', () {
      final NightState s = night();
      final NightReport r = resolveNight(
        s,
        fill(<Intent>[
          it(1, Ability.mafiaKill, 6),
          it(2, Ability.mafiaKill, 6),
          it(5, Ability.vigilanteKill, 6),
        ], s),
      );
      expect(r.deaths.length, 1);
      expect(r.deaths.single.tag, DeathTag.mafi,
          reason: 'мафи эхэлдэг — тогтмол дараалал');
      expect(r.nextRemorse, isEmpty,
          reason: 'Манаачийн сум онtoo ч үхлийг МАФИ бүртгүүлсэн');
    });
  });

  group('Гэмшил', () {
    test('хотынхны хүнийг буудвал ГЭМШИЛ зэвсэглэнэ', () {
      final NightState s = night();
      final NightReport r = resolveNight(
        s,
        fill(<Intent>[
          it(1, Ability.mafiaKill, 8),
          it(2, Ability.mafiaKill, 8),
          it(5, Ability.vigilanteKill, 6),
        ], s),
      );
      expect(r.nextRemorse, <Seat>{5});
    });

    test('МАФИГ буудвал гэмшил БАЙХГҮЙ', () {
      final NightState s = night();
      final NightReport r = resolveNight(
        s,
        fill(<Intent>[
          it(1, Ability.mafiaKill, 8),
          it(2, Ability.mafiaKill, 8),
          it(5, Ability.vigilanteKill, 2),
        ], s),
      );
      expect(r.nextRemorse, isEmpty);
    });

    test('гэмшлийн үхлийг ЭМЧЛЭХ БОЛОМЖГҮЙ', () {
      final NightState s = night(remorse: <Seat>{5});
      final NightReport r = resolveNight(
        s,
        fill(<Intent>[
          it(1, Ability.mafiaKill, 8),
          it(2, Ability.mafiaKill, 8),
          it(3, Ability.heal, 5),
        ], s),
      );
      expect(r.deaths.map((Death d) => d.victim).toList(), <Seat>[5, 8]);
      expect(r.deaths.firstWhere((Death d) => d.victim == 5).tag,
          DeathTag.remorse);
    });

    test('гэмшил ЗОЧЛОЛ бичихгүй', () {
      final NightState s = night(remorse: <Seat>{5});
      final NightReport r = resolveNight(s, fill(<Intent>[], s));
      expect(r.visits.any((Visit v) => v.from == 5), isFalse);
      expect(r.deaths.single.victim, 5);
    });

    test('аль хэдийн үхсэн Манаачийг гэмшил дахин авахгүй', () {
      final NightState s = night(alive: const <Seat>[1, 2, 3, 4, 6, 7, 8],
          remorse: <Seat>{5});
      final NightReport r = resolveNight(s, fill(<Intent>[], s));
      expect(r.deaths, isEmpty);
    });
  });

  group('Шалгалт', () {
    test('ЭХНИЙ шөнө буудахгүй', () {
      final NightState s = night(no: 1);
      expect(validate(it(5, Ability.vigilanteKill, 6, night: 1), s),
          RejectCode.nightTooEarly);
    });

    test('сум дууссан бол буудахгүй', () {
      final NightState s = night(bullets: const <Seat, int>{5: 0});
      expect(validate(it(5, Ability.vigilanteKill, 6), s),
          RejectCode.chargeSpent);
    });

    test('өөрийгөө буудахгүй', () {
      expect(validate(it(5, Ability.vigilanteKill, 5), night()),
          RejectCode.targetSelf);
    });

    test('өөр дүр буудаж чадахгүй', () {
      expect(validate(it(6, Ability.vigilanteKill, 7), night()),
          RejectCode.notYourAbility);
    });
  });

  group('Ялалт', () {
    test('БҮГД үхвэл ТЭНЦЭЭ', () {
      expect(evaluateWin(const <Seat>{}, const Setup(n: 8, roleBySeat: kV8)),
          WinState.draw);
    });
  });

  group('Бүрэлдэхүүн', () {
    test('Манаач нэг ИРГЭНИЙ суудлыг орлоно', () {
      for (int n = kMinSeats; n <= kMaxSeats; n++) {
        final Roster plain = rosterFor(n);
        final Roster v = rosterFor(n, vigilante: true);
        expect(v.mafia, plain.mafia);
        expect(v.b, plain.b);
        expect(v.citizens, plain.citizens - 1);
        expect(deckFor(v).where((Role r) => r == Role.vigilante).length, 1);
        expect(deckFor(v).length, n);
      }
    });

    test('Манаач нь ХОТЫНХОН', () {
      expect(factionOf(Role.vigilante), Faction.hotynhon);
    });

    test('анхдагчаар УНТРААЛТТАЙ', () {
      for (int n = kMinSeats; n <= kMaxSeats; n++) {
        expect(rosterFor(n).vigilante, isFalse);
      }
    });
  });
}
