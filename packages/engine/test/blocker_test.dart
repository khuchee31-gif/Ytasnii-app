// Саатуулагч (v3) — шөнийн үйлдлийг зогсоох дүр.
//
// ХАМГИЙН ЭМЗЭГ ДҮР. Түүний нэмэх гурван эрсдэл:
//
//   1. Саатуулагдсан ТОВШИЛТЫГ шивнээний сангаас хасвал шивнээний
//      жагсаалт хэн саатуулагдсаныг чимээгүйхэн зарлана.
//   2. Санааг УСТГАВАЛ `inputHash` нь шийдвэрлэлтийн функц болж,
//      идемпотент дахин шийдвэрлэлт үхнэ.
//   3. «Хэн саатуулсан» гэж хэлбэл Саатуулагч эхний шөнөдөө
//      илчлэгдэж, мафийн эхний бай болно.
//
// Гурвууланг нь энд шалгана.

import 'dart:convert';
import 'dart:typed_data';

import 'package:engine/src/hash.dart';
import 'package:engine/src/model.dart';
import 'package:engine/src/resolve.dart';
import 'package:engine/src/rosters.dart';
import 'package:engine/src/validate.dart';
import 'package:test/test.dart';

Uint8List seedOf(String label) => sha256(utf8.encode('blk/$label'));

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

/// P1·P2 Алуурчин, P3 Эмч, P4 Мөрдөгч, P5 Саатуулагч, P6 Ажиглагч,
/// P7·P8 Иргэн.
const Map<Seat, Role> kB8 = <Seat, Role>{
  1: Role.killer,
  2: Role.killer,
  3: Role.doctor,
  4: Role.detective,
  5: Role.blocker,
  6: Role.watcher,
  7: Role.citizen,
  8: Role.citizen,
};

NightState night({int no = 2}) => NightState(
      setup: const Setup(n: 8, roleBySeat: kB8),
      night: no,
      alive: const <Seat>{1, 2, 3, 4, 5, 6, 7, 8},
      seed: seedOf('base'),
      orderPerm: const <Seat>[1, 2, 3, 4, 5, 6, 7, 8],
    );

List<Intent> fill(List<Intent> given, NightState s) {
  final Set<Seat> acted = given.map((Intent i) => i.actor).toSet();
  return <Intent>[
    ...given,
    for (final Seat x in s.alive)
      if (!acted.contains(x)) it(x, Ability.noAction, null, night: s.night),
  ];
}

bool blockedMsg(NightReport r, Seat s) =>
    (r.privateMsgs[s] ?? const <Msg>[])
        .any((Msg m) => m.code == MsgCode.roleblocked);

void main() {
  group('Саатуулах', () {
    test('МАФИЙН алалтыг зогсооно', () {
      final NightState s = night();
      final NightReport r = resolveNight(
        s,
        fill(<Intent>[
          it(1, Ability.mafiaKill, 7),
          it(2, Ability.mafiaKill, 7),
          it(5, Ability.roleblock, 1),
        ], s),
      );
      // Хоёр алуурчны НЭГИЙГ нь саатуулсан — нөгөө нь буудсан хэвээр.
      expect(r.deaths.length, 1);

      final NightReport both = resolveNight(
        s,
        fill(<Intent>[
          it(1, Ability.mafiaKill, 7),
          it(2, Ability.mafiaKill, 7),
          it(5, Ability.roleblock, 1),
          it(4, Ability.investigate, 8),
        ], s),
      );
      expect(both.deaths.length, 1, reason: 'нэг алуурчин үлдсэн');
    });

    test('ЭМЧИЙГ зогсоовол хохирогч үхнэ', () {
      final NightState s = night();
      final NightReport saved = resolveNight(
        s,
        fill(<Intent>[
          it(1, Ability.mafiaKill, 7),
          it(2, Ability.mafiaKill, 7),
          it(3, Ability.heal, 7),
        ], s),
      );
      expect(saved.deaths, isEmpty);

      final NightReport lost = resolveNight(
        s,
        fill(<Intent>[
          it(1, Ability.mafiaKill, 7),
          it(2, Ability.mafiaKill, 7),
          it(3, Ability.heal, 7),
          it(5, Ability.roleblock, 3),
        ], s),
      );
      expect(lost.deaths.single.victim, 7,
          reason: 'эмч саатуулагдсан ч хохирогч амьд үлдлээ');
      expect(blockedMsg(lost, 3), isTrue);
    });

    test('МӨРДӨГЧ хариу авахгүй', () {
      final NightState s = night();
      final NightReport r = resolveNight(
        s,
        fill(<Intent>[
          it(1, Ability.mafiaKill, 8),
          it(2, Ability.mafiaKill, 8),
          it(4, Ability.investigate, 1),
          it(5, Ability.roleblock, 4),
        ], s),
      );
      expect(blockedMsg(r, 4), isTrue);
      expect(
          (r.privateMsgs[4] ?? const <Msg>[]).any((Msg m) =>
              m.code == MsgCode.traceFound || m.code == MsgCode.traceNotFound),
          isFalse);
      expect(r.visits.any((Visit v) => v.ability == Ability.investigate),
          isFalse,
          reason: 'саатуулагдсан Мөрдөгч ОЧООГҮЙ');
    });

    test('АЖИГЛАГЧ юу ч харахгүй', () {
      final NightState s = night();
      final NightReport r = resolveNight(
        s,
        fill(<Intent>[
          it(1, Ability.mafiaKill, 8),
          it(2, Ability.mafiaKill, 8),
          it(5, Ability.roleblock, 6),
          it(6, Ability.watch, 8),
        ], s),
      );
      expect(blockedMsg(r, 6), isTrue);
      expect(
          (r.privateMsgs[6] ?? const <Msg>[])
              .any((Msg m) => m.code == MsgCode.watchSaw),
          isFalse);
    });
  });

  group('Юуг АЛДАГДУУЛАХГҮЙ вэ', () {
    test('ШИВНЭЭНИЙ тоо саатуулснаар ӨӨРЧЛӨГДӨХГҮЙ', () {
      // Хэрэв саатуулагдсан товшилт санд ордоггүй байсан бол шивнээний
      // жагсаалт хэн саатуулагдсаныг чимээгүйхэн зарлана.
      //
      // ЯГ ЮУГ ХЭМЖИХ ВЭ: шивнээ нь зөвхөн ХОЁР суудал хэвлэдэг тул
      // «жагсаалтад байна уу» гэдгийг шууд харьцуулж болохгүй —
      // Саатуулагчийн ӨӨРИЙН товшилт өөр суудлыг түлхэж гаргаж
      // мэднэ. Тиймээс НЭГ суудлыг яг босгон дээр (3 товшилт)
      // байрлуулж, түүний нэг товшилт саатуулагдсан хүнийх байхаар
      // тохируулна. Товшилт санд хэвээр байвал 7 жагсаалтад үлдэнэ;
      // хасагдвал 2 болж босго алдаж, жагсаалт ХООСОН болно.
      for (final ({Seat actor, String who}) victim in <({Seat actor, String who})>[
        (actor: 3, who: 'Эмч'),
        (actor: 4, who: 'Мөрдөгч'),
        (actor: 6, who: 'Ажиглагч'),
      ]) {
        final NightState s = night();
        final List<Intent> base = <Intent>[
          it(3, Ability.heal, 7),
          it(4, Ability.investigate, 7),
          it(6, Ability.watch, 7),
        ];
        final NightReport free = resolveNight(s, fill(base, s));
        expect(free.whisper, contains(7),
            reason: 'гурван товшилт нь босго (whisperMinAgree=3)');

        final NightReport held = resolveNight(
            s, fill(<Intent>[...base, it(5, Ability.roleblock, victim.actor)], s));
        expect(blockedMsg(held, victim.actor), isTrue,
            reason: '${victim.who} үнэхээр саатуулагдсан байх ёстой');
        expect(held.whisper, contains(7),
            reason: '${victim.who}-ийн ТОВШИЛТ санд ҮЛДЭНЭ — эс бөгөөс '
                'шивнээ хэн саатуулагдсаныг зарлана');
      }
    });

    test('Саатуулагчийн ӨӨРИЙН товшилт санд ОРНО', () {
      // Саатуулагч бол зочлогч: түүний товшилт бусадтай адил тоологдоно.
      // Эс бөгөөс «шивнээнд байхгүй хүн» гэдэг нь Саатуулагчийн байг
      // ялгаж өгнө.
      final NightState s = night();
      final NightReport r = resolveNight(
        s,
        fill(<Intent>[
          it(3, Ability.heal, 7),
          it(4, Ability.investigate, 7),
          it(5, Ability.roleblock, 7),
        ], s),
      );
      expect(r.whisper, contains(7),
          reason: 'хоёр товшилт + Саатуулагчийнх = босго 3');
    });

    test('ИДЕМПОТЕНТ — нэг жагсаалт хоёр удаа ИЖИЛ хариу', () {
      // Эрсдэл №2: хэрэв Саатуулагч санааг УСТГАДАГ бол `inputHash` нь
      // лацдсан жагсаалтын БУС, шийдвэрлэлтийн үр дүнгийн функц болно.
      // Тэгвэл сервер дахин шийдвэрлэхэд өөр hash гарч, GDD-05 §8-ын
      // «ижил оролт → ижил гаралт» батлагаа унана.
      final NightState s = night();
      final List<Intent> list = fill(<Intent>[
        it(1, Ability.mafiaKill, 7),
        it(2, Ability.mafiaKill, 7),
        it(3, Ability.heal, 7),
        it(4, Ability.investigate, 1),
        it(5, Ability.roleblock, 3),
        it(6, Ability.watch, 7),
      ], s);
      final NightReport a = resolveNight(s, list);
      final NightReport b = resolveNight(s, list);
      expect(b.inputHash, a.inputHash);
      expect(b.resultHash, a.resultHash);

      // Дараалал нь ялгаа гаргахгүй: жагсаалт ЛАЦДАХААС ӨМНӨ эрэмбэлэгдэнэ.
      final NightReport c = resolveNight(s, list.reversed.toList());
      expect(c.inputHash, a.inputHash);
      expect(c.resultHash, a.resultHash);
    });

    test('СААТУУЛАЛТ `inputHash`-ыг ӨӨРЧЛӨХГҮЙ — зөвхөн үр дүнг', () {
      // Саатуулагчийн санаа бол ЖАГСААЛТЫН нэг мөр. Тэр нь оролтыг
      // өөрчилнө (нэг санаа нэмэгдсэн) — гэвч БУСДЫН санаа хэвээр
      // үлдсэн эсэхийг шалгана: устгагдсан бол хоёр жагсаалтын
      // ялгаа нэг мөрөөс ИХ болно.
      final NightState s = night();
      final List<Intent> plain = fill(<Intent>[
        it(3, Ability.heal, 7),
        it(4, Ability.investigate, 1),
      ], s);
      final List<Intent> held = <Intent>[
        for (final Intent i in plain)
          if (!(i.actor == 5)) i,
        it(5, Ability.roleblock, 3),
      ];
      expect(held.length, plain.length, reason: 'зөвхөн 5-ийн мөр СОЛИГДСОН');
      final NightReport r = resolveNight(s, held);
      // Эмч саатуулагдсан ч түүний САНАА жагсаалтад БАЙНА — хөдөлгүүр
      // үүнийг зочлолоор бус, `blocked` олонлогоор шийддэг.
      expect(blockedMsg(r, 3), isTrue);
      expect(r.inputHash, isNotEmpty);
      expect(resolveNight(s, held).inputHash, r.inputHash);
    });

    test('ХЭН саатуулсныг ХЭЛЭХГҮЙ', () {
      final NightState s = night();
      final NightReport r = resolveNight(
        s,
        fill(<Intent>[
          it(3, Ability.heal, 7),
          it(5, Ability.roleblock, 3),
        ], s),
      );
      final List<Msg> mine = r.privateMsgs[3]!;
      expect(mine.single.code, MsgCode.roleblocked);
      expect(mine.single.params, isEmpty,
          reason: 'мессеж ямар ч суудал агуулах ёсгүй');
    });

    test('ИРГЭН «саатуулагдлаа» гэсэн мессеж АВАХГҮЙ', () {
      // Авбал өөрийгөө чадвартай гэж эндүүрч, ширээнд худал мэдээлэл
      // тарина.
      final NightState s = night();
      final NightReport r = resolveNight(
        s,
        fill(<Intent>[
          it(5, Ability.roleblock, 7),
          it(7, Ability.suspect, 1),
        ], s),
      );
      expect(r.privateMsgs.containsKey(7), isFalse);
    });

    test('СААТУУЛАГЧ ЗОЧИЛНО — Ажиглагч түүнийг харна', () {
      final NightState s = night();
      final NightReport r = resolveNight(
        s,
        fill(<Intent>[
          it(5, Ability.roleblock, 3),
          it(6, Ability.watch, 3),
        ], s),
      );
      expect(
          (r.privateMsgs[6] ?? const <Msg>[])
              .where((Msg m) => m.code == MsgCode.watchSaw)
              .map((Msg m) => m.params['seat'])
              .toList(),
          <int>[5]);
    });

    test('СААТУУЛАГЧИЙГ саатуулж болохгүй', () {
      // Хоёр саатуулагч бие бие рүүгээ чиглэвэл хоёулаа хүчинтэй —
      // эс бөгөөс «аль нь түрүүлэв» гэсэн тойрог үүснэ.
      const Map<Seat, Role> two = <Seat, Role>{
        1: Role.killer,
        2: Role.killer,
        3: Role.doctor,
        4: Role.blocker,
        5: Role.blocker,
        6: Role.citizen,
        7: Role.citizen,
        8: Role.citizen,
      };
      final NightState s = NightState(
        setup: const Setup(n: 8, roleBySeat: two),
        night: 2,
        alive: const <Seat>{1, 2, 3, 4, 5, 6, 7, 8},
        seed: seedOf('two'),
        orderPerm: const <Seat>[1, 2, 3, 4, 5, 6, 7, 8],
      );
      final NightReport r = resolveNight(
        s,
        fill(<Intent>[
          it(4, Ability.roleblock, 3),
          it(5, Ability.roleblock, 4),
          it(1, Ability.mafiaKill, 7),
          it(2, Ability.mafiaKill, 7),
          it(3, Ability.heal, 7),
        ], s),
      );
      // 4 саатуулагдсан ч түүний саатуулалт хүчинтэй → эмч зогссон →
      // 7 үхнэ.
      expect(r.deaths.single.victim, 7);
      expect(blockedMsg(r, 3), isTrue);
      expect(blockedMsg(r, 4), isFalse,
          reason: '`roleblock` нь саатуулагддаггүй тул мессеж хэрэггүй');
    });
  });

  group('Манаачтай хамт', () {
    test('саатуулагдсан Манаачийн СУМ хасагдахгүй', () {
      const Map<Seat, Role> mix = <Seat, Role>{
        1: Role.killer,
        2: Role.killer,
        3: Role.doctor,
        4: Role.vigilante,
        5: Role.blocker,
        6: Role.citizen,
        7: Role.citizen,
        8: Role.citizen,
      };
      final NightState s = NightState(
        setup: const Setup(n: 8, roleBySeat: mix),
        night: 2,
        alive: const <Seat>{1, 2, 3, 4, 5, 6, 7, 8},
        seed: seedOf('mix'),
        orderPerm: const <Seat>[1, 2, 3, 4, 5, 6, 7, 8],
        bullets: const <Seat, int>{4: 2},
      );
      final NightReport r = resolveNight(
        s,
        fill(<Intent>[
          it(4, Ability.vigilanteKill, 7),
          it(5, Ability.roleblock, 4),
        ], s),
      );
      expect(r.nextBullets[4], 2, reason: 'буугаа гаргаж ч амжаагүй');
      expect(r.deaths, isEmpty);
      expect(blockedMsg(r, 4), isTrue);
    });
  });

  group('Шалгалт ба бүрэлдэхүүн', () {
    test('өөрийгөө саатуулж болохгүй', () {
      expect(validate(it(5, Ability.roleblock, 5), night()),
          RejectCode.targetSelf);
    });

    test('Саатуулагч нэг ИРГЭНИЙ суудлыг орлоно', () {
      for (int n = kMinSeats; n <= kMaxSeats; n++) {
        final Roster plain = rosterFor(n);
        final Roster b = rosterFor(n, blocker: true);
        expect(b.mafia, plain.mafia);
        expect(b.citizens, plain.citizens - 1);
        expect(deckFor(b).where((Role r) => r == Role.blocker).length, 1);
        expect(deckFor(b).length, n);
      }
    });

    test('Саатуулагч нь ХОТЫНХОН', () {
      expect(factionOf(Role.blocker), Faction.hotynhon);
    });
  });
}
