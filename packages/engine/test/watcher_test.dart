// Ажиглагч (v2).
//
// ГУРВАН ЗҮЙЛ БАТЛАХ ЁСТОЙ:
//
//   1. АЖИГЛАГЧ МӨРДӨГЧИЙГ ХЭЗЭЭ Ч ХАРАХГҮЙ. Хоёулаа 130-р хувинд
//      байдаг бөгөөд зочлолын жагсаалт тэр хувинд ОРОХ мөчид хөлддөг.
//      Эс бөгөөс Ажиглагч 2 дахь өдөр Мөрдөгчийн суудлыг сайн санаагаар
//      ширээнд зарлаж, 3 дахь шөнө нь мафи түүнийг алах болно.
//
//   2. АЖИГЛАГЧ ӨӨРӨӨ ЗОЧЛОХГҮЙ. Бичвэл хоёр Ажиглагч бие биеэ үнэгүй
//      баталгаажуулж, хожмын ямар ч дүр бүртгэлийг уншмагц бохирдоно.
//
//   3. ХАРИУ НЬ ТАЙЛАНГААС ДАХИН ТООЦОГДОНО (N25). Хэрэв хариу нь
//      дотоод төлөвөөс гардаг байсан бол дахин тоглуулалт нь шалгах
//      чадваргүй болно.

import 'dart:convert';
import 'dart:typed_data';

import 'package:engine/src/hash.dart';
import 'package:engine/src/model.dart';
import 'package:engine/src/resolve.dart';
import 'package:engine/src/rosters.dart';
import 'package:engine/src/validate.dart';
import 'package:test/test.dart';

Uint8List seedOf(String label) => sha256(utf8.encode('watch/$label'));

Intent it(Seat actor, Ability ability, Seat? target,
        {int night = 1, int clientSeq = 1}) =>
    Intent(
      intentId: '${night}_${actor}_${ability.name}_$clientSeq',
      night: night,
      actor: actor,
      ability: ability,
      target: target,
      clientSeq: clientSeq,
    );

/// P1·P2 Алуурчин, P3 Эмч, P4 Мөрдөгч, P5 Ажиглагч, P6…P8 Иргэн.
const Map<Seat, Role> kW8 = <Seat, Role>{
  1: Role.killer,
  2: Role.killer,
  3: Role.doctor,
  4: Role.detective,
  5: Role.watcher,
  6: Role.citizen,
  7: Role.citizen,
  8: Role.citizen,
};

NightState night(List<Seat> alive) => NightState(
      setup: const Setup(n: 8, roleBySeat: kW8),
      night: 1,
      alive: alive.toSet(),
      seed: seedOf('base'),
      orderPerm: const <Seat>[1, 2, 3, 4, 5, 6, 7, 8],
    );

/// Амьд бүрийг нэг санаатай болгоно (N22).
List<Intent> fill(List<Intent> given, List<Seat> alive) {
  final Set<Seat> acted = given.map((Intent i) => i.actor).toSet();
  return <Intent>[
    ...given,
    for (final Seat s in alive)
      if (!acted.contains(s)) it(s, Ability.noAction, null),
  ];
}

List<Msg> msgsFor(NightReport r, Seat s) => r.privateMsgs[s] ?? const <Msg>[];

void main() {
  const List<Seat> all = <Seat>[1, 2, 3, 4, 5, 6, 7, 8];

  group('Ажиглагчийн хариу', () {
    test('эмчилсэн, алсан хүн хоёуланг нь ХАРНА', () {
      // 1 нь 7-г алахаар очно, 3 нь 7-г эмчилнэ. 5 нь 7-г ажиглана.
      final NightReport r = resolveNight(
        night(all),
        fill(<Intent>[
          it(1, Ability.mafiaKill, 7),
          it(2, Ability.mafiaKill, 7),
          it(3, Ability.heal, 7),
          it(5, Ability.watch, 7),
        ], all),
      );
      final List<Msg> got = msgsFor(r, 5);
      expect(got.map((Msg m) => m.code).toSet(), <MsgCode>{MsgCode.watchSaw});
      // Алуурчин НЭГ л зочлол бичнэ (`pickVictim`-ийн сонгосон нь),
      // эмч нэг. Хаягдсан алуурчин ОЧООГҮЙ.
      expect(got.map((Msg m) => m.params['seat']).toList(), <int>[1, 3]);
    });

    test('хэн ч очоогүй бол `watchNobody`', () {
      final NightReport r = resolveNight(
        night(all),
        fill(<Intent>[
          it(1, Ability.mafiaKill, 6),
          it(2, Ability.mafiaKill, 6),
          it(5, Ability.watch, 8),
        ], all),
      );
      expect(msgsFor(r, 5).single.code, MsgCode.watchNobody);
    });

    test('МӨРДӨГЧИЙГ ХЭЗЭЭ Ч ХАРАХГҮЙ', () {
      // 4 (Мөрдөгч) нь 7-г шалгана, 5 (Ажиглагч) нь 7-г ажиглана.
      // Хоёулаа 130-р хувинд — зочлол тэнд ОРОХ мөчид хөлддөг.
      final NightReport r = resolveNight(
        night(all),
        fill(<Intent>[
          it(1, Ability.mafiaKill, 6),
          it(2, Ability.mafiaKill, 6),
          it(4, Ability.investigate, 7),
          it(5, Ability.watch, 7),
        ], all),
      );
      expect(msgsFor(r, 5).single.code, MsgCode.watchNobody,
          reason: 'Ажиглагч Мөрдөгчийг харлаа — дүр илчлэгдэнэ');
      // Гэхдээ Мөрдөгчийн зочлол ТАЙЛАНД байгаа — зөвхөн ИЖИЛ хувинд
      // байгаа уншигчид л харагдахгүй.
      expect(
          r.visits.any((Visit v) =>
              v.from == 4 && v.to == 7 && v.ability == Ability.investigate),
          isTrue);
    });

    test('ӨӨР АЖИГЛАГЧИЙГ ч харахгүй', () {
      // Хоёр Ажиглагчийн нэг нь нөгөөгийнхөө байг ажиглана.
      const Map<Seat, Role> two = <Seat, Role>{
        1: Role.killer,
        2: Role.killer,
        3: Role.doctor,
        4: Role.detective,
        5: Role.watcher,
        6: Role.watcher,
        7: Role.citizen,
        8: Role.citizen,
      };
      final NightState s = NightState(
        setup: const Setup(n: 8, roleBySeat: two),
        night: 1,
        alive: all.toSet(),
        seed: seedOf('two'),
        orderPerm: const <Seat>[1, 2, 3, 4, 5, 6, 7, 8],
      );
      final NightReport r = resolveNight(
        s,
        fill(<Intent>[
          it(1, Ability.mafiaKill, 4),
          it(2, Ability.mafiaKill, 4),
          it(5, Ability.watch, 8),
          it(6, Ability.watch, 8),
        ], all),
      );
      expect(msgsFor(r, 5).single.code, MsgCode.watchNobody);
      expect(msgsFor(r, 6).single.code, MsgCode.watchNobody);
    });

    test('Ажиглагч ЗОЧЛОЛ бичихгүй', () {
      final NightReport r = resolveNight(
        night(all),
        fill(<Intent>[
          it(1, Ability.mafiaKill, 6),
          it(2, Ability.mafiaKill, 6),
          it(5, Ability.watch, 7),
        ], all),
      );
      expect(r.visits.any((Visit v) => v.ability == Ability.watch), isFalse);
      expect(r.visits.any((Visit v) => v.from == 5), isFalse);
    });

    test('товшилт нь ШИВНЭЭНИЙ САНД ОРОХГҮЙ', () {
      // ХУУЧИН ДҮРЭМ: «Ажиглагчийн товшилт санд орно, эс бөгөөс
      // Ажиглагчтай тоглолт нь шивнээ цөөнтэй болж тэр өөрөө
      // ялгарна».
      //
      // ШИНЭ ДҮРЭМ: ЯМАР Ч чадварын бай санд ордоггүй (зөвхөн
      // сэжиглэл). Тиймээс «цөөнтэй болох» гэсэн харьцуулалт хийх
      // суурь байхгүй — Ажиглагч байгаа ба байхгүй тоглолт ЯГ ИЖИЛ
      // шивнээ гаргана. Хуучин дүрэм нь үүнээс хамаагүй том нүх
      // нээж байсан: хоёр алуурчин + эмч = гурав, тэр нь эмчийн
      // аврааг зарладаг (`blocker_test.dart`-ын гол шалгалтыг үз).
      final NightReport r = resolveNight(
        night(all),
        fill(<Intent>[
          it(1, Ability.mafiaKill, 7),
          it(2, Ability.mafiaKill, 7),
          it(3, Ability.heal, 7),
          it(5, Ability.watch, 7),
        ], all),
      );
      expect(r.deaths, isEmpty);
      expect(r.whisper, isEmpty);

      // Ажиглагчгүй бол ЯГ ИЖИЛ — түүний товшилт ямар ч ул мөр
      // үлдээхгүй.
      final NightReport without = resolveNight(
        night(all),
        fill(<Intent>[
          it(1, Ability.mafiaKill, 7),
          it(2, Ability.mafiaKill, 7),
          it(3, Ability.heal, 7),
        ], all),
      );
      expect(without.whisper, r.whisper);
    });
  });

  group('Ажиглагчийн шалгалт', () {
    test('өөрийгөө ажиглаж болохгүй', () {
      expect(validate(it(5, Ability.watch, 5), night(all)),
          RejectCode.targetSelf);
    });

    test('өөр дүр `watch` илгээж чадахгүй', () {
      expect(validate(it(6, Ability.watch, 7), night(all)),
          RejectCode.notYourAbility);
    });

    test('үхсэн хүнийг ажиглаж болохгүй', () {
      final NightState s = night(<Seat>[1, 2, 3, 4, 5, 6, 8]);
      expect(validate(it(5, Ability.watch, 7), s), RejectCode.targetDead);
    });
  });

  group('Бүрэлдэхүүн', () {
    test('Ажиглагч нэг ИРГЭНИЙ суудлыг орлоно', () {
      for (int n = kMinSeats; n <= kMaxSeats; n++) {
        final Roster plain = rosterFor(n);
        final Roster w = rosterFor(n, watcher: true);
        expect(w.mafia, plain.mafia, reason: 'N=$n мафийн тоо хөдөллөө');
        expect(w.b, plain.b, reason: 'N=$n балансын төсөв хөдөллөө');
        expect(w.citizens, plain.citizens - 1, reason: 'N=$n');
        expect(deckFor(w).length, n, reason: 'N=$n хөзрийн тоо');
        expect(deckFor(w).where((Role r) => r == Role.watcher).length, 1);
      }
    });

    test('анхдагчаар УНТРААЛТТАЙ', () {
      for (int n = kMinSeats; n <= kMaxSeats; n++) {
        expect(rosterFor(n).watcher, isFalse);
        expect(deckFor(rosterFor(n)).contains(Role.watcher), isFalse);
      }
    });

    test('Ажиглагч нь ХОТЫНХОН', () {
      expect(factionOf(Role.watcher), Faction.hotynhon);
    });
  });
}
