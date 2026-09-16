// «Хот унтлаа» — `resolveNight`-ийн тест.
//
// Эх сурвалж: GDD-05 §11-ийн бодит жишээ, §10.2-ын шинжийн тест,
// §10.3-ын fuzz харнесс; GDD-13 §4-ийн N-цуврал.
//
// Тестийн тайлбар монголоор, танигч ба API нэр англиар.

import 'dart:convert';
import 'dart:typed_data';

import 'package:engine/src/canon.dart';
import 'package:engine/src/hash.dart';
import 'package:engine/src/invariants.dart';
import 'package:engine/src/model.dart';
import 'package:engine/src/resolve.dart';
import 'package:engine/src/rng.dart';
import 'package:engine/src/rosters.dart';
import 'package:engine/src/validate.dart';
import 'package:test/test.dart';

// ---------------------------------------------------------------------------
// Туслахууд
// ---------------------------------------------------------------------------

/// 32 байтын тогтмол seed — тестэд `Random()` хэрэглэхгүй (N2).
Uint8List seedOf(String label) => sha256(utf8.encode('test/$label'));

Intent it(
  Seat actor,
  Ability ability,
  Seat? target, {
  int night = 1,
  int clientSeq = 1,
  String? id,
  int submittedAtMs = 0,
}) =>
    Intent(
      intentId: id ?? '${night}_${actor}_${ability.name}_$clientSeq',
      night: night,
      actor: actor,
      ability: ability,
      target: target,
      clientSeq: clientSeq,
      submittedAtMs: submittedAtMs,
    );

/// Амьд суудал бүр яг нэг санаа илгээх ёстой (N22). Өгөгдөөгүй суудлуудад
/// `noAction` нэмнэ — цонх дуусахад бүртгэгддэг санаатай ЯГ ижил.
List<Intent> fill(NightState s, List<Intent> given) {
  final Set<Seat> have = <Seat>{for (final Intent i in given) i.actor};
  final List<Intent> out = List<Intent>.of(given);
  final List<Seat> seats = s.alive.toList()..sort();
  for (final Seat seat in seats) {
    if (!have.contains(seat)) {
      out.add(it(seat, Ability.noAction, null, night: s.night));
    }
  }
  return out;
}

/// Детерминист сэлгэлт — `Random()` ХЭРЭГЛЭХГҮЙ (N2).
List<T> shuffleWith<T>(List<T> items, String label) =>
    fisherYates(items, Rng(sha256(utf8.encode('shuffle/$label'))));

// ---------------------------------------------------------------------------
// GDD-05 §11-ийн бүрэлдэхүүн MN_12
// ---------------------------------------------------------------------------

/// 3 мафи (P2 Ахлагч, P5 ба P11 Алуурчин), P4 Эмч, P9 Мөрдөгч, үлдсэн нь Иргэн.
const Map<Seat, Role> kMn12 = <Seat, Role>{
  1: Role.citizen,
  2: Role.boss,
  3: Role.citizen,
  4: Role.doctor,
  5: Role.killer,
  6: Role.citizen,
  7: Role.citizen,
  8: Role.citizen,
  9: Role.detective,
  10: Role.citizen,
  11: Role.killer,
  12: Role.citizen,
};

/// §11-ийн `orderPerm`, үг үсгээр.
const List<Seat> kMn12Order = <Seat>[9, 4, 12, 1, 11, 6, 2, 8, 5, 10, 3, 7];

Setup mn12Setup({
  FactionRule factionRule = FactionRule.designatedKiller,
  bool whisperOn = true,
  int whisperMinAgree = 3,
}) =>
    Setup(
      n: 12,
      roleBySeat: kMn12,
      factionRule: factionRule,
      whisperOn: whisperOn,
      whisperMinAgree: whisperMinAgree,
    );

// ---------------------------------------------------------------------------
// N = 8-ийн энгийн ширээ (Ахлагчгүй, `mafiaMajority`)
// ---------------------------------------------------------------------------

/// P1·P2 Алуурчин, P3 Эмч, P4 Мөрдөгч, P5…P8 Иргэн.
const Map<Seat, Role> kMn8 = <Seat, Role>{
  1: Role.killer,
  2: Role.killer,
  3: Role.doctor,
  4: Role.detective,
  5: Role.citizen,
  6: Role.citizen,
  7: Role.citizen,
  8: Role.citizen,
};

NightState mn8State({
  List<Seat> orderPerm = const <Seat>[1, 2, 3, 4, 5, 6, 7, 8],
  Set<Seat>? alive,
  int night = 1,
  Map<Seat, Seat> lastHealTarget = const <Seat, Seat>{},
}) =>
    NightState(
      setup: const Setup(n: 8, roleBySeat: kMn8),
      night: night,
      alive: alive ?? const <Seat>{1, 2, 3, 4, 5, 6, 7, 8},
      seed: seedOf('mn8'),
      orderPerm: orderPerm,
      lastHealTarget: lastHealTarget,
    );

// ---------------------------------------------------------------------------

void main() {
  // =========================================================================
  group('GDD-05 §11 — бодит жишээ: 12 тоглогч, 2-р шөнө', () {
    // Өмнөх түүх: 1-р шөнө P7 хохирсон, 1-р өдөр P3 хотоос хөөгдсөн.
    final NightState s = NightState(
      setup: mn12Setup(),
      night: 2,
      alive: const <Seat>{1, 2, 4, 5, 6, 8, 9, 10, 11, 12},
      seed: seedOf('mn12/§11'),
      orderPerm: kMn12Order,
      lastHealTarget: const <Seat, Seat>{4: 6},
    );

    // §11-ийн 2-р шөнийн санаанууд, хүснэгтээр яг тэр дарааллаар.
    final List<Intent> intents = <Intent>[
      it(1, Ability.suspect, 5, night: 2),
      it(2, Ability.mafiaKill, 9, night: 2),
      it(4, Ability.heal, 9, night: 2),
      it(5, Ability.mafiaKill, 4, night: 2),
      it(6, Ability.suspect, 5, night: 2),
      it(8, Ability.suspect, 2, night: 2),
      it(9, Ability.investigate, 11, night: 2),
      it(10, Ability.suspect, 5, night: 2),
      it(11, Ability.mafiaKill, 9, night: 2),
      it(12, Ability.suspect, 2, night: 2),
    ];

    test('0. Бүрэлдэхүүн: b₀ = ⌊12/2⌋ − 3 − 1 = 2, амьд 10, M = 3, T = 7', () {
      expect(s.setup.mafiaCount, 3);
      expect(b0(12, 3), 2);
      expect(s.alive.length, 10);
      // 2-р өдрийн «Тооны самбар»: 2 − 1 = 1.
      expect(pipsForDay(12, 3, 2), 1);
      // §11-ийн rank хүснэгт.
      expect(s.rank(9), 0);
      expect(s.rank(4), 1);
      expect(s.rank(12), 2);
      expect(s.rank(1), 3);
      expect(s.rank(11), 4);
      expect(s.rank(6), 5);
      expect(s.rank(2), 6);
      expect(s.rank(8), 7);
      expect(s.rank(5), 8);
      expect(s.rank(10), 9);
    });

    test('1. Лацдах: 10 санаа бүгд шалгалтыг давна, dedupe юу ч хасахгүй', () {
      for (final Intent i in intents) {
        expect(validate(i, s), isNull, reason: 'санаа $i татгалзагдлаа');
      }
      // P4-ийн `heal → 9` нь `healRepeat`-д УНАХГҮЙ (өчигдөр 6 байсан).
      expect(validate(it(4, Ability.heal, 6, night: 2), s), RejectCode.healRepeat);
      expect(intents.length, 10);
    });

    test('1b. Бүрэн эрэмбэ: heal → mafiaKill(P11, P2, P5) → investigate → suspect',
        () {
      // Хувин: 90 heal · 100 mafiaKill · 130 investigate · 135 suspect.
      expect(bucketOf(Ability.heal), 90);
      expect(bucketOf(Ability.mafiaKill), 100);
      expect(bucketOf(Ability.investigate), 130);
      expect(bucketOf(Ability.suspect), 135);
      // Мафийн дотоод эрэмбэ нь rank-аар: P11(4) < P2(6) < P5(8).
      expect(s.rank(11) < s.rank(2), isTrue);
      expect(s.rank(2) < s.rank(5), isTrue);
    });

    test('3. 100 attack: `designatedKiller` → (actor: 2, target: 9)', () {
      final List<Intent> kills = intents
          .where((Intent i) => i.ability == Ability.mafiaKill)
          .toList()
        ..sort((Intent a, Intent b) => s.rank(a.actor).compareTo(s.rank(b.actor)));
      // Эрэмбэ нь P11, P2, P5 — гэвч Ахлагчийн салаа `rank`-ыг ОГТ уншихгүй.
      expect(kills.map((Intent i) => i.actor).toList(), <Seat>[11, 2, 5]);
      final ({Seat actor, Seat target})? hit = pickVictim(s, kills);
      expect(hit, isNotNull);
      expect(hit!.actor, 2);
      expect(hit.target, 9);
    });

    test('2·4·5·6·7·8. Бүтэн шийдвэрлэлт §11-ийн заасан үр дүнг гаргана', () {
      final NightReport r = resolveNight(s, intents);

      // 2. 90 protect — P4 → P9 ирмэг.
      expect(
        r.visits
            .where((Visit v) => v.ability == Ability.heal)
            .map((Visit v) => '${v.from}->${v.to}')
            .toList(),
        <String>['4->9'],
      );
      expect(r.nextLastHeal[4], 9);

      // 3. Ирмэг P2 → P9, хортой. P5, P11-ийн товшилт хаягдана.
      final List<Visit> attacks = r.visits
          .where((Visit v) => v.ability == Ability.mafiaKill)
          .toList();
      expect(attacks.length, 1);
      expect(attacks.first.from, 2);
      expect(attacks.first.to, 9);
      expect(attacks.first.harmful, isTrue);

      // 4. 120 deathApply — `lethal(basic, basic)` нь ХУУРАМЧ. P9 амьд.
      expect(lethal(AttackLevel.basic, DefenseLevel.basic), isFalse);
      expect(r.deaths, isEmpty);
      expect(r.aliveAfter.contains(9), isTrue);
      expect(r.aliveAfter.length, 10);

      // 5. 130 info — P11 = Алуурчин → «Мөр олдлоо.»
      expect(r.privateMsgs.keys.toList(), <Seat>[9]);
      expect(r.privateMsgs[9]!.map((Msg m) => m.code).toList(),
          <MsgCode>[MsgCode.traceFound]);
      expect(
        r.visits
            .where((Visit v) => v.ability == Ability.investigate)
            .map((Visit v) => '${v.from}->${v.to}')
            .toList(),
        <String>['9->11'],
      );

      // N17: сэжиглэх товшилт нь зочлол БИШ — visits дотор 3 л ирмэг.
      expect(r.visits.length, 3);
      expect(r.visits.any((Visit v) => v.ability == Ability.suspect), isFalse);

      // 6. 135 whisper — ЗӨВХӨН СЭЖИГЛЭЛ: 5→3 (P1, P6, P10), 2→2
      //    (P8, P12). Босго 3 → `[5]`.
      //
      //    GDD-05 §11 нь энд `[5, 9]` гэж бичдэг байв: 9 нь P2-ийн
      //    алалт, P4-ийн эдгээлт, P11-ийн хаягдсан алалт гурваас
      //    гуравтай болдог байв. Тэр нь ЯГ энэ засварын шалтгаан —
      //    §11-ийн өөрийн тайлбар «Эмч сохроор яг тэр суудлыг
      //    аварсан, шивнээ нь Мөрдөгчийн дугаарыг нийтэлсэн» гэж
      //    бичсэн. Хэмжилтээр тэр нь ховор давхцал БИШ, харин шивнээ
      //    гарсан тохиолдлын 100% нь болж таарав.
      expect(r.whisper, <Seat>[5]);

      // 7. 160 cues — үхэл байхгүй тул 2.5 секундын блок БАЙХГҮЙ.
      expect(r.cues.length, 3);
      expect((r.cues[0] as CueLine).clipId, 'DAWN_NO_KILL');
      expect((r.cues[1] as CueLine).clipId, 'WHISPER');
      expect((r.cues[2] as CueScreenSeats).seats, <Seat>[5]);
      expect(r.cues.any((Cue c) => c is CueSilence), isFalse);

      // 8. 170 winCheck — M = 3, T = 7.
      expect(r.win, WinState.none);

      // Хэш нь бичигдсэн бөгөөд тогтвортой.
      expect(r.inputHash.length, 64);
      expect(r.resultHash.length, 64);
      expect(resolveNight(s, intents).resultHash, r.resultHash);
    });

    test('Шивнээний сан §11-ийн тоогоор яг таарна', () {
      // Суудал бүрийн ЦОРЫН ГАНЦ санааны бай тоологдоно.
      final Map<Seat, int> tally = <Seat, int>{};
      for (final Intent i in intents) {
        tally.update(i.target!, (int v) => v + 1, ifAbsent: () => 1);
      }
      expect(tally[5], 3); // P1, P6, P10
      expect(tally[9], 3); // P2-ийн алалт, P4-ийн эдгээлт, P11-ийн ХАЯГДСАН алалт
      expect(tally[2], 2); // P8, P12
      expect(tally[4], 1); // P5
      expect(tally[11], 1); // P9
      expect(topWhisper(tally, s.alive, s), <Seat>[5, 9]);
    });

    test('Дуудагчийн `NightState` ХЭЗЭЭ Ч өөрчлөгдөхгүй', () {
      final Set<Seat> before = Set<Seat>.of(s.alive);
      final Map<Seat, Seat> lastBefore = Map<Seat, Seat>.of(s.lastHealTarget);
      resolveNight(s, intents);
      expect(s.alive, before);
      expect(s.lastHealTarget, lastBefore);
    });
  });

  // =========================================================================
  group('Эмч — тэнцүү түвшний довтолгоог ЧАНД цуцална', () {
    final NightState s = mn8State();

    List<Intent> night({required Seat healTarget}) => fill(s, <Intent>[
          it(1, Ability.mafiaKill, 5),
          it(2, Ability.mafiaKill, 5),
          it(3, Ability.heal, healTarget),
          it(4, Ability.investigate, 1),
        ]);

    test('Эмч мафийн байг аварвал хохирогч ГАРАХГҮЙ', () {
      final NightReport r = resolveNight(s, night(healTarget: 5));
      expect(r.deaths, isEmpty);
      expect(r.aliveAfter.contains(5), isTrue);
      expect((r.cues.first as CueLine).clipId, 'DAWN_NO_KILL');
    });

    test('Эмч ӨӨР хүнийг аварвал хохирогч гарна', () {
      final NightReport r = resolveNight(s, night(healTarget: 6));
      expect(r.deaths.length, 1);
      expect(r.deaths.first.victim, 5);
      expect(r.deaths.first.tag, DeathTag.mafi);
      expect(r.aliveAfter.contains(5), isFalse);
      // `mafiaMajority`: бай 5, хутга нь rank хамгийн багатай буудагч.
      expect(r.deaths.first.killer, 1);
    });

    test('Хамгаалалтын snapshot нь 100-д ХӨЛДӨНӨ — 120-д дахин уншигдахгүй', () {
      // Эмч хохирогчийг аварсан ч, аваагүй ч, `defSnapshot` нь нэг л удаа
      // уншигдана. Ажиглагдах үр дүн: эдгээлт ҮРГЭЛЖ ажиллана, довтолгооны
      // «дараалал» гэсэн асуулт огт үүсэхгүй.
      final NightReport healed = resolveNight(s, night(healTarget: 5));
      final NightReport other = resolveNight(s, night(healTarget: 6));
      expect(healed.deaths, isEmpty);
      expect(other.deaths.length, 1);
      // N13: `powerful` хэзээ ч гарахгүй — тэнцүү түвшин хүчинтэй хэвээр.
      expect(lethal(AttackLevel.basic, DefenseLevel.basic), isFalse);
      expect(lethal(AttackLevel.basic, DefenseLevel.none), isTrue);
    });
  });

  // =========================================================================
  group('Мафийн шийдвэр — Ахлагч ба `mafiaMajority`', () {
    final NightState s12 = NightState(
      setup: mn12Setup(),
      night: 3,
      alive: const <Seat>{1, 2, 4, 5, 6, 8, 9, 10, 11, 12},
      seed: seedOf('mn12/boss'),
      orderPerm: kMn12Order,
    );

    test('Ахлагчийн товшилт хожино — rank нь ОГТ уншигдахгүй', () {
      // P11-ийн rank (4) нь Ахлагч P2-ынхаас (6) БАГА, гэвч Ахлагч хожино.
      final List<Intent> kills = <Intent>[
        it(11, Ability.mafiaKill, 6, night: 3),
        it(2, Ability.mafiaKill, 8, night: 3),
        it(5, Ability.mafiaKill, 6, night: 3),
      ];
      final ({Seat actor, Seat target})? hit = pickVictim(s12, kills);
      expect(hit!.actor, 2);
      expect(hit.target, 8);

      final NightReport r = resolveNight(s12, fill(s12, kills));
      expect(r.deaths.single.victim, 8);
      expect(r.deaths.single.killer, 2);
    });

    test('Ахлагч хасагдсан бол `mafiaMajority` руу автоматаар унана', () {
      final NightState dead = NightState(
        setup: mn12Setup(),
        night: 3,
        alive: const <Seat>{1, 4, 5, 6, 8, 9, 10, 11, 12}, // P2 байхгүй
        seed: seedOf('mn12/boss-dead'),
        orderPerm: kMn12Order,
      );
      expect(dead.aliveSeatWithRole(Role.boss), isNull);

      final List<Intent> kills = <Intent>[
        it(11, Ability.mafiaKill, 6, night: 3),
        it(5, Ability.mafiaKill, 6, night: 3),
      ];
      final ({Seat actor, Seat target})? hit = pickVictim(dead, kills);
      expect(hit!.target, 6); // хоёр товшилт
      expect(hit.actor, 11); // rank(11)=4 < rank(5)=8

      final NightReport r = resolveNight(dead, fill(dead, kills));
      expect(r.deaths.single.victim, 6);
      expect(r.deaths.single.killer, 11);
    });

    test('`mafiaMajority`-ийн тэнцлийг `orderPerm` тайлна, тогтвортой', () {
      final NightState dead = NightState(
        setup: mn12Setup(),
        night: 3,
        alive: const <Seat>{1, 4, 5, 6, 8, 9, 10, 11, 12},
        seed: seedOf('mn12/tie'),
        orderPerm: kMn12Order,
      );
      // P11 → 1 (rank(1) = 3), P5 → 6 (rank(6) = 5). Тус бүр нэг товшилт.
      final List<Intent> kills = <Intent>[
        it(11, Ability.mafiaKill, 1, night: 3),
        it(5, Ability.mafiaKill, 6, night: 3),
      ];
      expect(pickVictim(dead, kills)!.target, 1); // rank 3 < rank 5

      // Дараалал солигдоход ижил хариу — тэнцэл санамсаргүй БИШ.
      for (int k = 0; k < 8; k++) {
        final List<Intent> mixed = shuffleWith(kills, 'tie$k');
        expect(pickVictim(dead, mixed)!.target, 1);
        expect(pickVictim(dead, mixed)!.actor, 11);
      }
    });

    test('Ахлагч товшоогүй бол (noAction) `mafiaMajority` руу унана', () {
      final List<Intent> kills = <Intent>[
        it(11, Ability.mafiaKill, 1, night: 3),
        it(5, Ability.mafiaKill, 6, night: 3),
      ];
      final List<Intent> all = fill(s12, <Intent>[
        ...kills,
        it(2, Ability.noAction, null, night: 3),
      ]);
      final NightReport r = resolveNight(s12, all);
      // rank(1) = 3 < rank(6) = 5.
      expect(r.deaths.single.victim, 1);
      expect(r.deaths.single.killer, 11);
    });

    test('Нэг ч мафи товшоогүй бол хохирогч байхгүй', () {
      final NightReport r = resolveNight(s12, fill(s12, <Intent>[]));
      expect(r.deaths, isEmpty);
      expect((r.cues.first as CueLine).clipId, 'DAWN_NO_KILL');
    });
  });

  // =========================================================================
  group('GDD-05 §10.2 №1 — илгээх дараалал үр дүнд НӨЛӨӨЛӨХГҮЙ', () {
    final NightState s = NightState(
      setup: mn12Setup(),
      night: 2,
      alive: const <Seat>{1, 2, 4, 5, 6, 8, 9, 10, 11, 12},
      seed: seedOf('mn12/order'),
      orderPerm: kMn12Order,
    );
    final List<Intent> base = fill(s, <Intent>[
      it(1, Ability.suspect, 5, night: 2),
      it(2, Ability.mafiaKill, 9, night: 2),
      it(4, Ability.heal, 9, night: 2),
      it(5, Ability.mafiaKill, 4, night: 2),
      it(6, Ability.suspect, 5, night: 2),
      it(8, Ability.suspect, 2, night: 2),
      it(9, Ability.investigate, 11, night: 2),
      it(10, Ability.suspect, 5, night: 2),
      it(11, Ability.mafiaKill, 9, night: 2),
      it(12, Ability.suspect, 2, night: 2),
    ]);

    test('40 өөр сэлгэлт → ИЖИЛ `resultHash` ба `inputHash`', () {
      final NightReport r0 = resolveNight(s, base);
      for (int k = 0; k < 40; k++) {
        final NightReport rk = resolveNight(s, shuffleWith(base, 'ord$k'));
        expect(rk.inputHash, r0.inputHash, reason: 'сэлгэлт $k');
        expect(rk.resultHash, r0.resultHash, reason: 'сэлгэлт $k');
      }
    });

    test('`submittedAtMs` нь үр дүнд ХЭЗЭЭ Ч нөлөөлөхгүй', () {
      final NightReport r0 = resolveNight(s, base);
      final List<Intent> stamped = <Intent>[
        for (int i = 0; i < base.length; i++)
          it(
            base[i].actor,
            base[i].ability,
            base[i].target,
            night: base[i].night,
            clientSeq: base[i].clientSeq,
            id: base[i].intentId,
            submittedAtMs: 999999 - i * 137,
          ),
      ];
      final NightReport r1 = resolveNight(s, shuffleWith(stamped, 'stamp'));
      expect(r1.inputHash, r0.inputHash);
      expect(r1.resultHash, r0.resultHash);
    });

    test('N19 — `(actor, ability)` тутам хамгийн их `clientSeq` хожино', () {
      final List<Intent> dup = <Intent>[
        ...base.where((Intent i) => i.actor != 2),
        it(2, Ability.mafiaKill, 1, night: 2, clientSeq: 1, id: 'a'),
        it(2, Ability.mafiaKill, 9, night: 2, clientSeq: 7, id: 'b'),
        it(2, Ability.mafiaKill, 6, night: 2, clientSeq: 3, id: 'c'),
      ];
      final NightReport r = resolveNight(s, shuffleWith(dup, 'dup'));
      // Сүүлчийн товшилт (clientSeq 7) нь бай 9 — эдгээгдсэн тул үхэлгүй.
      expect(r.deaths, isEmpty);
      expect(
        r.visits
            .where((Visit v) => v.ability == Ability.mafiaKill)
            .map((Visit v) => v.to)
            .toList(),
        <Seat>[9],
      );
      // Ижил ҮР ДҮН: зөвхөн ялсан санааны `intentId` өөр тул `inputHash`
      // өөр — үр дүн нь харин байт байтаараа ижил.
      final List<Intent> expected = <Intent>[
        ...base.where((Intent i) => i.actor != 2),
        it(2, Ability.mafiaKill, 9, night: 2, clientSeq: 7, id: 'b'),
      ];
      expect(r.resultHash, resolveNight(s, expected).resultHash);
      expect(r.inputHash, resolveNight(s, expected).inputHash);
    });
  });

  // =========================================================================
  group('Шивнээ нь ЗӨВХӨН байнуудын multiset-ийн функц', () {
    final NightState s = mn8State(
      orderPerm: const <Seat>[4, 7, 1, 8, 3, 6, 2, 5],
    );

    test('Хэн товшсон нь хамаарахгүй — иргэдийн байг сэлгэвэл ижил шивнээ', () {
      final NightReport a = resolveNight(
        s,
        fill(s, <Intent>[
          it(5, Ability.suspect, 1),
          it(6, Ability.suspect, 1),
          it(7, Ability.suspect, 1),
          it(8, Ability.suspect, 2),
        ]),
      );
      final NightReport b = resolveNight(
        s,
        fill(s, <Intent>[
          it(5, Ability.suspect, 2),
          it(6, Ability.suspect, 1),
          it(7, Ability.suspect, 1),
          it(8, Ability.suspect, 1),
        ]),
      );
      expect(a.whisper, <Seat>[1]);
      expect(b.whisper, a.whisper);
    });

    test('МӨРДӨГЧИЙН товшилт санг тэжээхгүй — зөвхөн СЭЖИГЛЭЛ', () {
      // A: Мөрдөгч → 1 дээр, гурван сэжиглэл 1 дээр.
      // B: Мөрдөгч → 2 дээр, гурван сэжиглэл 1 дээр.
      // Мөрдөгчийн бай ЯМАР Ч нөлөөгүй тул хоёр хариу ИЖИЛ.
      final NightReport a = resolveNight(
        s,
        fill(s, <Intent>[
          it(4, Ability.investigate, 1),
          it(5, Ability.suspect, 1),
          it(6, Ability.suspect, 1),
          it(8, Ability.suspect, 1),
        ]),
      );
      final NightReport b = resolveNight(
        s,
        fill(s, <Intent>[
          it(4, Ability.investigate, 2),
          it(5, Ability.suspect, 1),
          it(6, Ability.suspect, 1),
          it(8, Ability.suspect, 1),
        ]),
      );
      expect(a.whisper, <Seat>[1]);
      expect(b.whisper, a.whisper);
    });

    test('ЭДГЭЭЛТ ба ХАЯГДСАН АЛАЛТ санг ТЭЖЭЭХГҮЙ', () {
      // ЭНЭ БОЛ ГОЛ ЗАСВАР. Хуучин дүрмээр: хаягдсан алалт (P2 → 6) +
      // эдгээлт (P3 → 6) + нэг сэжиглэл = 3 → босго давна. Тэр нь
      // «эмч хэнийг аварсныг» зарлах зам байв.
      //
      // Одоо зөвхөн сэжиглэл тоологдоно: 6 → 1 товшилт, босго хол.
      final NightReport r = resolveNight(
        s,
        fill(s, <Intent>[
          it(1, Ability.mafiaKill, 7),
          it(2, Ability.mafiaKill, 6),
          it(3, Ability.heal, 6),
          it(5, Ability.suspect, 6),
        ]),
      );
      // rank(7)=1 < rank(6)=5 тул `mafiaMajority` тэнцэлд 7 хожино.
      expect(r.deaths.single.victim, 7);
      expect(r.whisper, isEmpty);
    });

    test('Өнөө шөнө үхсэн суудал шивнээний сангаас ХАСАГДАНА', () {
      final NightReport r = resolveNight(
        s,
        fill(s, <Intent>[
          it(1, Ability.mafiaKill, 6),
          it(2, Ability.mafiaKill, 6),
          it(5, Ability.suspect, 6),
          it(7, Ability.suspect, 6),
          it(8, Ability.suspect, 6),
        ]),
      );
      expect(r.deaths.single.victim, 6);
      expect(r.whisper, isEmpty); // 6 нь ГУРВАН сэжиглэлтэй ч ҮХСЭН
    });

    test('`whisperOn == false` бол шивнээ ба `WHISPER` мөр байхгүй', () {
      final NightState off = NightState(
        setup: const Setup(n: 8, roleBySeat: kMn8, whisperOn: false),
        night: 1,
        alive: const <Seat>{1, 2, 3, 4, 5, 6, 7, 8},
        seed: seedOf('mn8/off'),
        orderPerm: const <Seat>[1, 2, 3, 4, 5, 6, 7, 8],
      );
      final NightReport r = resolveNight(
        off,
        fill(off, <Intent>[
          it(5, Ability.suspect, 1),
          it(6, Ability.suspect, 1),
          it(7, Ability.suspect, 1),
        ]),
      );
      expect(r.whisper, isEmpty);
      expect(r.cues.any((Cue c) => c is CueLine && c.clipId == 'WHISPER'),
          isFalse);
    });

    test('`topWhisper` нь тоогоор сонгож, СУУДЛЫН ДУГААРААР хэвлэнэ', () {
      final NightState s2 = mn8State(
        orderPerm: const <Seat>[8, 7, 6, 5, 4, 3, 2, 1],
      );
      // 3 нь 5 товшилт, 8 нь 4, 1 нь 3, 2 нь 2 (босгонд хүрэхгүй).
      final Map<Seat, int> tally = <Seat, int>{3: 5, 8: 4, 1: 3, 2: 2};
      expect(topWhisper(tally, s2.alive, s2), <Seat>[3, 8]);
      // Тэнцэл: 1 ба 3 тэнцүү бол rank шийднэ — rank(3)=5, rank(1)=7.
      expect(topWhisper(<Seat, int>{1: 3, 3: 3}, s2.alive, s2), <Seat>[1, 3]);
      expect(topWhisper(<Seat, int>{1: 3, 3: 3, 8: 3}, s2.alive, s2),
          <Seat>[3, 8]); // rank(8)=0, rank(3)=5, rank(1)=7
    });
  });

  // =========================================================================
  group('§9.3 — `cues`, чимээгүй нь гаралт', () {
    test('Үхэлгүй шөнө: зөвхөн `DAWN_NO_KILL`', () {
      final List<Cue> c = buildCues(const <Death>[], const <Seat>[]);
      expect(c.length, 1);
      expect((c[0] as CueLine).clipId, 'DAWN_NO_KILL');
    });

    test('Нэг үхэл: `[DAWN_A, silence(2500, −40), DAWN_VICTIM_07]` зэрэгцээ', () {
      final List<Cue> c =
          buildCues(const <Death>[Death(7, 1, DeathTag.mafi)], const <Seat>[]);
      expect(c.length, 3);
      expect((c[0] as CueLine).clipId, 'DAWN_A');
      expect((c[1] as CueSilence).ms, 2500);
      expect((c[1] as CueSilence).duckAmbienceDb, -40);
      expect((c[2] as CueLine).clipId, 'DAWN_VICTIM_07');
    });

    test('Суудлын дугаар хоёр оронтой болж нөхөгдөнө', () {
      expect(dawnVictimClip(1), 'DAWN_VICTIM_01');
      expect(dawnVictimClip(12), 'DAWN_VICTIM_12');
      expect(dawnVictimClip(20), 'DAWN_VICTIM_20');
    });

    test('Шивнээ хоосон бол ЮУ Ч нэмэгдэхгүй — «Хот чимээгүй» мөр байхгүй', () {
      final List<Cue> c = buildCues(const <Death>[], const <Seat>[]);
      expect(c.any((Cue x) => x is CueScreenSeats), isFalse);
      expect(c.length, 1);
    });

    test('Шивнээ нэмэгдэхдээ `[WHISPER, screenSeats]` хосоор', () {
      final List<Cue> c = buildCues(
        const <Death>[Death(3, 5, DeathTag.mafi)],
        const <Seat>[4, 9],
      );
      expect(c.length, 5);
      expect((c[3] as CueLine).clipId, 'WHISPER');
      expect((c[4] as CueScreenSeats).seats, <Seat>[4, 9]);
    });
  });

  // =========================================================================
  group('§9.1 — `infoAnswer` ба N21', () {
    final NightState s = mn8State();

    test('Мафиг шалгавал «Мөр олдлоо», иргэнийг шалгавал «Мөр олдсонгүй»', () {
      expect(infoAnswer(s, it(4, Ability.investigate, 1)).code,
          MsgCode.traceFound);
      expect(infoAnswer(s, it(4, Ability.investigate, 5)).code,
          MsgCode.traceNotFound);
      expect(infoAnswer(s, it(4, Ability.investigate, 3)).code,
          MsgCode.traceNotFound);
    });

    test('N21 — товших мөчийн хариу = тайлан дахь хариу, бүх байд', () {
      for (final Seat t in <Seat>[1, 2, 3, 5, 6, 7, 8]) {
        final Intent q = it(4, Ability.investigate, t);
        final Msg atTap = infoAnswer(s, q); // эргэлтийн дундуур харагдсан мөр
        final NightReport r = resolveNight(
          s,
          fill(s, <Intent>[q, it(1, Ability.mafiaKill, 6)]),
        );
        expect(r.privateMsgs[4]!.single.code, atTap.code, reason: 'бай $t');
      }
    });

    test('Ахлагч шалгалтаас далдлагдахгүй — v1-д хуурамч тал байхгүй', () {
      final NightState s12 = NightState(
        setup: mn12Setup(),
        night: 1,
        alive: <Seat>{for (int i = 1; i <= 12; i++) i},
        seed: seedOf('mn12/info'),
        orderPerm: kMn12Order,
      );
      expect(infoAnswer(s12, it(9, Ability.investigate, 2)).code,
          MsgCode.traceFound);
    });

    test('N15 — хувийн мессеж ЗӨВХӨН Мөрдөгчид', () {
      final NightReport r = resolveNight(
        s,
        fill(s, <Intent>[
          it(1, Ability.mafiaKill, 6),
          it(3, Ability.heal, 6),
          it(4, Ability.investigate, 2),
          it(5, Ability.suspect, 1),
        ]),
      );
      // Эмчид «аварлаа» гэж ХЭЛЭХГҮЙ, хохирогчид «довтолсон» гэж ХЭЛЭХГҮЙ.
      expect(r.privateMsgs.keys.toList(), <Seat>[4]);
    });
  });

  // =========================================================================
  group('§9.4 — `evaluateWin`', () {
    const Setup setup = Setup(n: 8, roleBySeat: kMn8);

    test('M == 0 → хотынхон ялна', () {
      expect(evaluateWin(const <Seat>{3, 4, 5, 6}, setup), WinState.hotynhon);
    });

    test('M >= T → мафи ялна (шөнө-эхэлдэг конвенц)', () {
      expect(evaluateWin(const <Seat>{1, 2, 5, 6}, setup), WinState.mafi);
      expect(evaluateWin(const <Seat>{1, 5}, setup), WinState.mafi);
    });

    test('M < T → тоглоом үргэлжилнэ', () {
      expect(evaluateWin(const <Seat>{1, 3, 4, 5, 6}, setup), WinState.none);
    });

    test('N10 — хоёр ялагч зэрэг ГАРАХГҮЙ', () {
      for (int mask = 1; mask < 256; mask++) {
        final Set<Seat> alive = <Seat>{
          for (int i = 0; i < 8; i++)
            if (mask & (1 << i) != 0) i + 1,
        };
        final WinState w = evaluateWin(alive, setup);
        final int m = alive.where((Seat s) => s <= 2).length;
        final int t = alive.length - m;
        expect(w == WinState.hotynhon, m == 0);
        expect(w == WinState.mafi, m > 0 && m >= t);
      }
    });

    test('Мафи сүүлчийн байг алаад ялна', () {
      final NightState s = mn8State(alive: const <Seat>{1, 2, 5, 6, 7});
      final NightReport r = resolveNight(
        s,
        fill(s, <Intent>[
          it(1, Ability.mafiaKill, 5),
          it(2, Ability.mafiaKill, 5),
        ]),
      );
      expect(r.deaths.single.victim, 5);
      expect(r.win, WinState.mafi); // M = 2, T = 2
    });
  });

  // =========================================================================
  group('Лацдах — хүчингүй санаа ба N6', () {
    test('Үхсэн суудлын үйлдэл лацдалтанд ОРОХГҮЙ (N6)', () {
      final NightState s = mn8State(alive: const <Seat>{1, 3, 4, 5, 6, 7, 8});
      final NightReport r = resolveNight(
        s,
        fill(s, <Intent>[
          it(2, Ability.mafiaKill, 5), // P2 хасагдсан — хаягдана
          it(1, Ability.mafiaKill, 6),
        ]),
      );
      expect(r.deaths.single.victim, 6);
      expect(r.visits.where((Visit v) => v.from == 2), isEmpty);
    });

    test('Өөр шөнийн санаа хаягдана', () {
      final NightState s = mn8State(night: 4);
      final NightReport r = resolveNight(s, <Intent>[
        ...fill(s, const <Intent>[]),
        it(1, Ability.mafiaKill, 6, night: 3), // өөр шөнө — лацдалтанд орохгүй
      ]);
      expect(r.deaths, isEmpty);
      expect(r.visits, isEmpty);
    });

    test('`noAction` нь ҮРГЭЛЖ хүчинтэй, юу ч өөрчлөхгүй (N22)', () {
      final NightState s = mn8State();
      final NightReport all = resolveNight(s, fill(s, const <Intent>[]));
      expect(all.deaths, isEmpty);
      expect(all.visits, isEmpty);
      expect(all.whisper, isEmpty);
      expect(all.privateMsgs, isEmpty);
      expect(all.win, WinState.none);
    });

    test('`inputHash` нь seed, шөнө, лацдсан санаанаас гарна', () {
      final NightState s = mn8State();
      final List<Intent> a = fill(s, <Intent>[it(1, Ability.mafiaKill, 6)]);
      final NightReport r = resolveNight(s, a);
      final NightState other = NightState(
        setup: s.setup,
        night: s.night,
        alive: s.alive,
        seed: seedOf('mn8/other'), // өөр seed
        orderPerm: s.orderPerm,
      );
      expect(resolveNight(other, a).inputHash, isNot(r.inputHash));
      expect(canon(<String, Object?>{'x': 1}).length, greaterThan(0));
    });
  });

  // =========================================================================
  group('GDD-05 §10.3 — fuzz харнесс, инвариант бүр шөнө', () {
    test('2000 seed × санамсаргүй хууль ёсны санаа → инвариант зөрчихгүй', () {
      const int fuzzSeeds = 2000;
      int nights = 0;
      for (int seed = 0; seed < fuzzSeeds; seed++) {
        nights += _playRandomGame(seed);
      }
      expect(nights, greaterThan(fuzzSeeds)); // тоглолтууд үнэхээр явсан
    }, timeout: const Timeout(Duration(minutes: 5)));
  });
}

// ---------------------------------------------------------------------------
// Fuzz харнесс (GDD-05 §10.3, GDD-13 §4.2)
// ---------------------------------------------------------------------------

/// Нэг санамсаргүй тоглолтыг эхнээс нь дуустал тоглоод, шөнө бүр дээр
/// `checkInvariants`-ыг ажиллуулна. Тоглосон шөнийн тоог буцаана.
int _playRandomGame(int seed) {
  final Rng rng = Rng(sha256(utf8.encode('fuzz:$seed')));
  final int n = kMinSeats + rng.below(kMaxSeats - kMinSeats + 1);
  final Roster roster = rosterFor(n);

  final List<Role> deck = fisherYates(deckFor(roster), rng);
  final Map<Seat, Role> roleBySeat = <Seat, Role>{
    for (int i = 0; i < n; i++) i + 1: deck[i],
  };
  final List<Seat> orderPerm =
      fisherYates(<Seat>[for (int i = 1; i <= n; i++) i], rng);

  final Setup setup = Setup(
    n: n,
    roleBySeat: roleBySeat,
    factionRule:
        roster.boss ? FactionRule.designatedKiller : FactionRule.mafiaMajority,
    whisperOn: rng.below(5) != 0,
    whisperMinAgree: 2 + rng.below(3),
    doctorSelfHeal: SelfHeal.values[rng.below(SelfHeal.values.length)],
    mafiaFriendlyFire: rng.below(2) == 0,
  );

  final Uint8List gameSeed = sha256(utf8.encode('fuzz-seed:$seed'));
  Set<Seat> alive = <Seat>{for (int i = 1; i <= n; i++) i};
  Map<Seat, Seat> lastHeal = const <Seat, Seat>{};
  Map<Seat, int> selfHealUsed = const <Seat, int>{};

  int night = 1;
  int played = 0;
  while (night <= 30 && evaluateWin(alive, setup) == WinState.none) {
    final NightState s = NightState(
      setup: setup,
      night: night,
      alive: alive,
      seed: gameSeed,
      orderPerm: orderPerm,
      lastHealTarget: lastHeal,
      selfHealUsed: selfHealUsed,
    );

    final List<Seat> actors = alive.toList()..sort();
    final List<Intent> intents = <Intent>[
      for (final Seat a in actors) _randomLegalIntent(a, s, rng, seed),
    ];

    final NightReport r = resolveNight(s, intents);
    checkInvariants(s, intents, r);

    // Дахин дуудахад ИЖИЛ байт (N1).
    expect(resolveNight(s, intents).resultHash, r.resultHash);

    alive = Set<Seat>.of(r.aliveAfter);
    lastHeal = Map<Seat, Seat>.of(r.nextLastHeal);
    selfHealUsed = Map<Seat, int>.of(r.nextSelfHealUsed);
    played++;
    night++;

    if (r.win != WinState.none) break;

    // Өдрийн хасалт — санамсаргүй нэг суудал (шөнийн эргэлтэд нөлөөлнө).
    if (alive.length > 1 && rng.below(4) != 0) {
      final List<Seat> pool = alive.toList()..sort();
      alive = Set<Seat>.of(pool)..remove(pool[rng.below(pool.length)]);
    }
  }
  return played;
}

/// Тухайн суудлын хууль ёсны санаа. 12% нь `noAction` (GDD-13 §4.2).
Intent _randomLegalIntent(Seat actor, NightState s, Rng rng, int gameSeed) {
  final String id = 'f$gameSeed-n${s.night}-s$actor';
  final Intent none = Intent(
    intentId: id,
    night: s.night,
    actor: actor,
    ability: Ability.noAction,
    target: null,
    clientSeq: 1,
  );
  if (rng.below(100) < 12) return none;

  final Ability ability = abilityOf(s.setup.roleOf(actor)!);
  final List<Seat> candidates = <Seat>[];
  for (int t = 1; t <= s.setup.n; t++) {
    final Intent probe = Intent(
      intentId: id,
      night: s.night,
      actor: actor,
      ability: ability,
      target: t,
      clientSeq: 1,
    );
    if (validate(probe, s) == null) candidates.add(t);
  }
  if (candidates.isEmpty) return none;
  return Intent(
    intentId: id,
    night: s.night,
    actor: actor,
    ability: ability,
    target: candidates[rng.below(candidates.length)],
    clientSeq: 1,
  );
}
