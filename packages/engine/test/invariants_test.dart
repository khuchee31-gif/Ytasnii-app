// «Хот унтлаа» — инвариантуудын тест.
//
// Эх сурвалж: GDD-13 §4-ийн N-цуврал, GDD-05 §10.1-ийн зураглал.
//
// Арга: цэвэр шөнийг `resolveNight`-ээр гаргаж, дараа нь тайланг (эсвэл
// лацдсан жагсаалтыг) НЭГ ЛЭ ЗҮЙЛЭЭР эвдээд `checkInvariants` тухайн
// N-дугаараараа шидэж байгаа эсэхийг шалгана. Мутаци бүр нэг инвариант.
//
// Тестийн тайлбар монголоор, танигч ба API нэр англиар.

import 'dart:convert';
import 'dart:typed_data';

import 'package:engine/src/hash.dart';
import 'package:engine/src/invariants.dart';
import 'package:engine/src/model.dart';
import 'package:engine/src/resolve.dart';
import 'package:test/test.dart';

// ---------------------------------------------------------------------------
// Туслахууд
// ---------------------------------------------------------------------------

Uint8List seedOf(String label) => sha256(utf8.encode('test/$label'));

Intent it(
  Seat actor,
  Ability ability,
  Seat? target, {
  int night = 1,
  int clientSeq = 1,
  String? id,
}) =>
    Intent(
      intentId: id ?? '${night}_${actor}_${ability.name}_$clientSeq',
      night: night,
      actor: actor,
      ability: ability,
      target: target,
      clientSeq: clientSeq,
    );

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

/// Тайланг НЭГ талбараар нь солино — бусад нь хэвээр.
NightReport tweak(
  NightReport r, {
  List<Death>? deaths,
  List<Seat>? whisper,
  Map<Seat, List<Msg>>? privateMsgs,
  List<Cue>? cues,
  List<Visit>? visits,
  WinState? win,
  Set<Seat>? aliveAfter,
}) =>
    NightReport(
      night: r.night,
      deaths: deaths ?? r.deaths,
      whisper: whisper ?? r.whisper,
      privateMsgs: privateMsgs ?? r.privateMsgs,
      cues: cues ?? r.cues,
      visits: visits ?? r.visits,
      win: win ?? r.win,
      inputHash: r.inputHash,
      resultHash: r.resultHash,
      aliveAfter: aliveAfter ?? r.aliveAfter,
      nextLastHeal: r.nextLastHeal,
      nextSelfHealUsed: r.nextSelfHealUsed,
    );

/// `checkInvariants` нь ЯГ тэр N-дугаараар шидэх ёстой.
Matcher violates(String id) => throwsA(
      isA<InvariantViolation>().having((InvariantViolation e) => e.id, 'id', id),
    );

void main() {
  // Суурь шөнө: P1·P2 → 6 (P6 үхнэ), P3 → 5 аварна, P4 → 1 шалгана,
  // P5·P6 → 1 сэжиглэнэ, P7 → 8, P8 → 7.
  final NightState s0 = NightState(
    setup: const Setup(n: 8, roleBySeat: kMn8),
    night: 1,
    alive: const <Seat>{1, 2, 3, 4, 5, 6, 7, 8},
    seed: seedOf('inv/base'),
    orderPerm: const <Seat>[1, 2, 3, 4, 5, 6, 7, 8],
  );

  final List<Intent> sealed = <Intent>[
    it(3, Ability.heal, 5),
    it(1, Ability.mafiaKill, 6),
    it(2, Ability.mafiaKill, 6),
    it(4, Ability.investigate, 1),
    it(5, Ability.suspect, 1),
    it(6, Ability.suspect, 1),
    it(7, Ability.suspect, 8),
    it(8, Ability.suspect, 7),
  ];

  final NightReport base = resolveNight(s0, sealed);

  // =========================================================================
  group('Суурь шөнө өөрөө бүх инвариантыг давна', () {
    test('Суурь тайлан цэвэр', () {
      expect(() => checkInvariants(s0, sealed, base), returnsNormally);
    });

    test('Суурь шөнийн агуулга хүлээлттэй таарна', () {
      expect(base.deaths.single.victim, 6);
      expect(base.deaths.single.killer, 1); // rank(1) = 0
      expect(base.whisper, <Seat>[1]); // 1 → 3 товшилт (P4, P5, P6)
      expect(base.privateMsgs[4]!.single.code, MsgCode.traceFound);
      expect(base.aliveAfter, <Seat>{1, 2, 3, 4, 5, 7, 8});
      expect(base.visits.length, 3); // сэжиглэлт зочлол БИШ
      expect(base.cues.length, 5);
    });

    test('Дарааллаас үл хамаарна — лацдсан жагсаалтыг эргүүлэв', () {
      expect(
        () => checkInvariants(s0, sealed.reversed.toList(), base),
        returnsNormally,
      );
    });
  });

  // =========================================================================
  group('N3 — `deaths.length ≤ 1`', () {
    test('Хоёр үхэл шидэгдэнэ', () {
      final NightReport bad = tweak(base, deaths: const <Death>[
        Death(6, 1, DeathTag.mafi),
        Death(7, 2, DeathTag.mafi),
      ]);
      expect(() => checkInvariants(s0, sealed, bad), violates('N3'));
    });
  });

  // =========================================================================
  group('N5 — эдгээгдсэн бай ҮХЭХГҮЙ', () {
    test('Эмч хохирогчийг аварсан байхад үхэл бүртгэгдвэл шидэгдэнэ', () {
      final NightReport bad = tweak(base, visits: <Visit>[
        ...base.visits,
        const Visit(3, 6, Ability.heal, harmful: false),
      ]);
      expect(() => checkInvariants(s0, sealed, bad), violates('N5'));
    });

    test('Довтолгоогүй үхэл шидэгдэнэ', () {
      final NightReport bad = tweak(
        base,
        deaths: const <Death>[Death(7, 1, DeathTag.mafi)],
        aliveAfter: const <Seat>{1, 2, 3, 4, 5, 6, 8},
        cues: <Cue>[
          const CueLine('DAWN_A'),
          const CueSilence(2500, duckAmbienceDb: -40),
          const CueLine('DAWN_VICTIM_07'),
        ],
        whisper: const <Seat>[1],
      );
      expect(() => checkInvariants(s0, sealed, bad), violates('N5'));
    });

    test('Хөдөлгүүр өөрөө N5-ыг хэзээ ч зөрчихгүй — эдгээлт чанд цуцална', () {
      final List<Intent> healed = <Intent>[
        for (final Intent i in sealed)
          if (i.actor == 3) it(3, Ability.heal, 6) else i,
      ];
      final NightReport r = resolveNight(s0, healed);
      expect(r.deaths, isEmpty);
      expect(() => checkInvariants(s0, healed, r), returnsNormally);
    });
  });

  // =========================================================================
  group('N6 — лацдах мөчид үхсэн үйлдэгч', () {
    test('Үхсэн суудлын үйлдэл лацдсан жагсаалтад байвал шидэгдэнэ', () {
      final NightState dead = NightState(
        setup: s0.setup,
        night: 1,
        alive: const <Seat>{1, 3, 4, 5, 6, 7, 8}, // P2 хасагдсан
        seed: s0.seed,
        orderPerm: s0.orderPerm,
      );
      expect(() => checkInvariants(dead, sealed, base), violates('N6'));
    });

    test('`noAction` нь үйлдэл БИШ — үхсэн суудлаас ирсэн ч N6 унахгүй', () {
      final NightState dead = NightState(
        setup: s0.setup,
        night: 1,
        alive: const <Seat>{1, 2, 3, 4, 5, 6, 7},
        seed: s0.seed,
        orderPerm: s0.orderPerm,
      );
      final List<Intent> withNoop = <Intent>[
        ...sealed.where((Intent i) => i.actor != 8),
        it(8, Ability.noAction, null),
      ];
      // N6 давна; унах бол өөр инвариант дээр (энд N20/N8 таарна).
      try {
        checkInvariants(dead, withNoop, base);
      } on InvariantViolation catch (e) {
        expect(e.id, isNot('N6'));
      }
    });
  });

  // =========================================================================
  group('N8 — шивнээ', () {
    test('Гурваас олон суудал шидэгдэнэ', () {
      expect(
        () => checkInvariants(s0, sealed, tweak(base, whisper: const <Seat>[1, 5, 7])),
        violates('N8'),
      );
    });

    test('Суудлын дугаараар өсөөгүй бол шидэгдэнэ', () {
      expect(
        () => checkInvariants(s0, sealed, tweak(base, whisper: const <Seat>[5, 1])),
        violates('N8'),
      );
    });

    test('Өнөө шөнө үхсэн суудал шивнэгдвэл шидэгдэнэ', () {
      expect(
        () => checkInvariants(s0, sealed, tweak(base, whisper: const <Seat>[6])),
        violates('N8'),
      );
    });

    test('Босго хүрээгүй суудал шивнэгдвэл шидэгдэнэ', () {
      expect(
        () => checkInvariants(s0, sealed, tweak(base, whisper: const <Seat>[7])),
        violates('N8'),
      );
    });

    test('Босго давсан суудал орхигдвол шидэгдэнэ', () {
      expect(
        () => checkInvariants(s0, sealed, tweak(base, whisper: const <Seat>[])),
        violates('N8'),
      );
    });

    test('`whisperOn == false` байхад шивнээ гарвал шидэгдэнэ', () {
      final NightState off = NightState(
        setup: const Setup(n: 8, roleBySeat: kMn8, whisperOn: false),
        night: 1,
        alive: s0.alive,
        seed: s0.seed,
        orderPerm: s0.orderPerm,
      );
      final NightReport r = resolveNight(off, sealed);
      expect(r.whisper, isEmpty);
      expect(
        () => checkInvariants(off, sealed, tweak(r, whisper: const <Seat>[1])),
        violates('N8'),
      );
    });
  });

  // =========================================================================
  group('N10 — ялалт', () {
    test('Буруу ялагч шидэгдэнэ', () {
      expect(
        () => checkInvariants(s0, sealed, tweak(base, win: WinState.mafi)),
        violates('N10'),
      );
      expect(
        () => checkInvariants(s0, sealed, tweak(base, win: WinState.hotynhon)),
        violates('N10'),
      );
    });

    test('`aliveAfter` хоосон байвал шидэгдэнэ', () {
      final NightState solo = NightState(
        setup: s0.setup,
        night: 1,
        alive: const <Seat>{6},
        seed: s0.seed,
        orderPerm: s0.orderPerm,
      );
      final NightReport bad = tweak(
        base,
        deaths: const <Death>[Death(6, 1, DeathTag.mafi)],
        aliveAfter: const <Seat>{},
        whisper: const <Seat>[],
        privateMsgs: const <Seat, List<Msg>>{},
      );
      expect(
        () => checkInvariants(
            solo, <Intent>[it(6, Ability.noAction, null)], bad),
        violates('N10'),
      );
    });

    test('Мафи ба хотынхон ХЭЗЭЭ Ч зэрэг ялахгүй', () {
      for (int mask = 1; mask < 256; mask++) {
        final Set<Seat> alive = <Seat>{
          for (int i = 0; i < 8; i++)
            if (mask & (1 << i) != 0) i + 1,
        };
        final WinState w = evaluateWin(alive, s0.setup);
        expect(w == WinState.mafi && w == WinState.hotynhon, isFalse);
      }
    });
  });

  // =========================================================================
  group('N13 — хоосон хувингууд ба `powerful`', () {
    test('Бүх `Ability` нь АМЬД хувинд буудаг', () {
      expect(() => checkInvariants(s0, sealed, base), returnsNormally);
      // Дүр нэмэгдэх бүрд ЭНЭ ЖАГСААЛТ өснө. 20–50, 70–80, 110,
      // 140–150 нь ХООСОН хэвээр: тэнд ямар нэг чадвар буувал хэн нэгэн
      // GDD-05 §3.2-ыг тойрч шинэ шат нээсэн байна.
      const List<int> live = <int>[60, 90, 100, 130, 135];
      for (final Ability a in Ability.values) {
        expect(live.contains(bucketOf(a)), isTrue, reason: a.name);
      }
      expect(bucketOf(Ability.roleblock), 60);
      expect(bucketOf(Ability.heal), 90);
      expect(bucketOf(Ability.mafiaKill), 100);
      expect(bucketOf(Ability.vigilanteKill), 100);
      expect(bucketOf(Ability.investigate), 130);
      expect(bucketOf(Ability.watch), 130);
      expect(bucketOf(Ability.suspect), 135);
      expect(bucketOf(Ability.noAction), 135);
    });

    test('135-аас зочлол гарвал шидэгдэнэ (N17-ийн ах дүү нөхцөл)', () {
      final NightReport bad = tweak(base, visits: <Visit>[
        ...base.visits,
        const Visit(5, 1, Ability.suspect, harmful: false),
      ]);
      expect(() => checkInvariants(s0, sealed, bad), violates('N13'));
    });

    test('Хөдөлгүүр сэжиглэлтийн зочлол ХЭЗЭЭ Ч гаргахгүй', () {
      expect(
        base.visits.any((Visit v) => v.ability == Ability.suspect),
        isFalse,
      );
      expect(
        base.visits.map((Visit v) => v.ability).toSet(),
        <Ability>{Ability.heal, Ability.mafiaKill, Ability.investigate},
      );
    });

    test('`lethal` нь `powerful`-гүйгээр тодорхойлогдоно', () {
      expect(lethal(AttackLevel.basic, DefenseLevel.basic), isFalse);
      expect(lethal(AttackLevel.basic, DefenseLevel.none), isTrue);
      expect(lethal(AttackLevel.none, DefenseLevel.none), isFalse);
      // v2-ын зай: хөдөлгүүр үүнийг ХЭЗЭЭ Ч гаргахгүй.
      expect(lethal(AttackLevel.powerful, DefenseLevel.basic), isTrue);
    });
  });

  // =========================================================================
  group('N14 — үүрийн 2500 мс', () {
    test('Чимээгүй богиносвол шидэгдэнэ', () {
      final NightReport bad = tweak(base, cues: <Cue>[
        const CueLine('DAWN_A'),
        const CueSilence(800, duckAmbienceDb: -40),
        const CueLine('DAWN_VICTIM_06'),
        const CueLine('WHISPER'),
        const CueScreenSeats(<Seat>[1]),
      ]);
      expect(() => checkInvariants(s0, sealed, bad), violates('N14'));
    });

    test('Уур амьсгалын даралт өөрчлөгдвөл шидэгдэнэ', () {
      final NightReport bad = tweak(base, cues: <Cue>[
        const CueLine('DAWN_A'),
        const CueSilence(2500),
        const CueLine('DAWN_VICTIM_06'),
      ]);
      expect(() => checkInvariants(s0, sealed, bad), violates('N14'));
    });

    test('Гурвал зэрэгцээгүй бол шидэгдэнэ', () {
      final NightReport bad = tweak(base, cues: <Cue>[
        const CueLine('DAWN_A'),
        const CueLine('WHISPER'),
        const CueSilence(2500, duckAmbienceDb: -40),
        const CueLine('DAWN_VICTIM_06'),
      ]);
      expect(() => checkInvariants(s0, sealed, bad), violates('N14'));
    });

    test('Буруу хохирогчийн клип шидэгдэнэ', () {
      final NightReport bad = tweak(base, cues: <Cue>[
        const CueLine('DAWN_A'),
        const CueSilence(2500, duckAmbienceDb: -40),
        const CueLine('DAWN_VICTIM_07'),
      ]);
      expect(() => checkInvariants(s0, sealed, bad), violates('N14'));
    });

    test('Үхэлтэй шөнөд `DAWN_NO_KILL` гарвал шидэгдэнэ', () {
      final NightReport bad = tweak(base, cues: <Cue>[
        const CueLine('DAWN_A'),
        const CueSilence(2500, duckAmbienceDb: -40),
        const CueLine('DAWN_VICTIM_06'),
        const CueLine('DAWN_NO_KILL'),
      ]);
      expect(() => checkInvariants(s0, sealed, bad), violates('N14'));
    });

    test('Үхэлгүй шөнөд `DAWN_NO_KILL` байхгүй бол шидэгдэнэ', () {
      final List<Intent> healed = <Intent>[
        for (final Intent i in sealed)
          if (i.actor == 3) it(3, Ability.heal, 6) else i,
      ];
      final NightReport r = resolveNight(s0, healed);
      expect(
        () => checkInvariants(s0, healed, tweak(r, cues: const <Cue>[])),
        violates('N14'),
      );
      // Үхэлгүй шөнөд `DAWN_A` гарах нь ч зөрчил.
      expect(
        () => checkInvariants(s0, healed,
            tweak(r, cues: const <Cue>[CueLine('DAWN_NO_KILL'), CueLine('DAWN_A')])),
        violates('N14'),
      );
    });
  });

  // =========================================================================
  group('N15 — хувийн мессеж зөвхөн Мөрдөгчид', () {
    test('Иргэн мессеж авбал шидэгдэнэ', () {
      final NightReport bad = tweak(base, privateMsgs: <Seat, List<Msg>>{
        ...base.privateMsgs,
        5: const <Msg>[Msg(MsgCode.traceNotFound)],
      });
      expect(() => checkInvariants(s0, sealed, bad), violates('N15'));
    });

    test('Эмч «аварлаа» гэсэн мессеж авахгүй', () {
      expect(base.privateMsgs.containsKey(3), isFalse);
      final NightReport bad = tweak(base, privateMsgs: <Seat, List<Msg>>{
        ...base.privateMsgs,
        3: const <Msg>[Msg(MsgCode.traceNotFound)],
      });
      expect(() => checkInvariants(s0, sealed, bad), violates('N15'));
    });

    test('Хохирогч «чам руу довтолсон» гэсэн мессеж авахгүй', () {
      expect(base.privateMsgs.containsKey(6), isFalse);
    });

    test('Лацдах мөчид үхсэн байсан суудал мессеж авбал шидэгдэнэ', () {
      final NightState dead = NightState(
        setup: s0.setup,
        night: 1,
        alive: const <Seat>{1, 2, 3, 5, 6, 7, 8}, // P4 Мөрдөгч хасагдсан
        seed: s0.seed,
        orderPerm: s0.orderPerm,
      );
      final List<Intent> noDetective =
          sealed.where((Intent i) => i.actor != 4).toList();
      expect(
        () => checkInvariants(dead, noDetective,
            tweak(base, aliveAfter: const <Seat>{1, 2, 3, 5, 7, 8})),
        violates('N15'),
      );
    });
  });

  // =========================================================================
  group('N19 — `(actor, ability)` тутам нэг үйлдэл', () {
    test('Давхардсан хос шидэгдэнэ', () {
      final List<Intent> dup = <Intent>[
        ...sealed,
        it(1, Ability.mafiaKill, 7, clientSeq: 9, id: 'x'),
      ];
      expect(() => checkInvariants(s0, dup, base), violates('N19'));
    });

    test('Хөдөлгүүр давхардлыг ӨӨРӨӨ цэвэрлэнэ — хамгийн их `clientSeq`', () {
      final List<Intent> dup = <Intent>[
        ...sealed,
        it(1, Ability.mafiaKill, 7, clientSeq: 9, id: 'x'),
      ];
      final NightReport r = resolveNight(s0, dup);
      // Сүүлчийн товшилт нь бай 7 → мафийн дийлэнх 6(1) ба 7(1) тэнцэнэ,
      // rank(6) = 5 < rank(7) = 6 тул 6 хожино.
      expect(r.deaths.single.victim, 6);
      expect(
        r.visits.where((Visit v) => v.ability == Ability.mafiaKill).length,
        1,
      );
    });
  });

  // =========================================================================
  group('N20 — тооллого', () {
    test('Үхсэн хүн `aliveAfter`-т үлдвэл шидэгдэнэ', () {
      expect(
        () => checkInvariants(
            s0, sealed, tweak(base, aliveAfter: s0.alive)),
        violates('N20'),
      );
    });

    test('Лацдах мөчид амьд биш байсан хүн үхвэл шидэгдэнэ', () {
      final NightState without = NightState(
        setup: s0.setup,
        night: 1,
        alive: const <Seat>{1, 2, 3, 4, 5, 7, 8}, // P6 аль хэдийн хасагдсан
        seed: s0.seed,
        orderPerm: s0.orderPerm,
      );
      final List<Intent> noP6 = <Intent>[
        for (final Intent i in sealed)
          if (i.actor != 6) i,
      ];
      expect(() => checkInvariants(without, noP6, base), violates('N20'));
    });

    test('Тооллого зөрвөл шидэгдэнэ', () {
      expect(
        () => checkInvariants(
            s0, sealed, tweak(base, aliveAfter: const <Seat>{1, 2, 3, 4, 5, 7})),
        violates('N20'),
      );
    });
  });

  // =========================================================================
  group('N21 — `infoAnswer` товших мөчид = тайланд', () {
    test('Хариу зөрвөл шидэгдэнэ', () {
      final NightReport bad = tweak(base, privateMsgs: <Seat, List<Msg>>{
        4: const <Msg>[Msg(MsgCode.traceNotFound)],
      });
      expect(() => checkInvariants(s0, sealed, bad), violates('N21'));
    });

    test('Мөрдөгч шалгасан ч хариугүй бол шидэгдэнэ', () {
      final NightReport bad =
          tweak(base, privateMsgs: const <Seat, List<Msg>>{});
      expect(() => checkInvariants(s0, sealed, bad), violates('N21'));
    });

    test('Бүх байд товших мөчийн хариу тайлантай таарна', () {
      for (final Seat t in <Seat>[1, 2, 3, 5, 6, 7, 8]) {
        final List<Intent> a = <Intent>[
          for (final Intent i in sealed)
            if (i.actor == 4) it(4, Ability.investigate, t) else i,
        ];
        final NightReport r = resolveNight(s0, a);
        expect(r.privateMsgs[4]!.single.code,
            infoAnswer(s0, it(4, Ability.investigate, t)).code,
            reason: 'бай $t');
        expect(() => checkInvariants(s0, a, r), returnsNormally);
      }
    });
  });

  // =========================================================================
  group('N22 — амьд суудал бүр яг нэг санаа', () {
    test('Санаа дутвал шидэгдэнэ', () {
      final List<Intent> missing =
          sealed.where((Intent i) => i.actor != 7).toList();
      expect(() => checkInvariants(s0, missing, base), violates('N22'));
    });

    test('`noAction` нь бүрэн хүчинтэй санаа', () {
      final List<Intent> withNoop = <Intent>[
        for (final Intent i in sealed)
          if (i.actor == 7) it(7, Ability.noAction, null) else i,
      ];
      final NightReport r = resolveNight(s0, withNoop);
      expect(() => checkInvariants(s0, withNoop, r), returnsNormally);
    });

    test('Бүгд `noAction` илгээсэн шөнө ч инвариантыг давна', () {
      final List<Intent> allNoop = <Intent>[
        for (final Seat seat in s0.alive) it(seat, Ability.noAction, null),
      ];
      final NightReport r = resolveNight(s0, allNoop);
      expect(r.deaths, isEmpty);
      expect(r.visits, isEmpty);
      expect(() => checkInvariants(s0, allNoop, r), returnsNormally);
    });
  });

  // =========================================================================
  group('`InvariantViolation` нь инвариантаа НЭРЛЭНЭ', () {
    test('`id` ба `detail` нь мессежэд гарна', () {
      const InvariantViolation v = InvariantViolation('N14', 'чимээгүй 800 мс');
      expect(v.id, 'N14');
      expect(v.detail, 'чимээгүй 800 мс');
      expect(v.toString(), contains('N14'));
      expect(v.toString(), contains('чимээгүй 800 мс'));
      expect(v, isA<Exception>());
    });
  });
}
