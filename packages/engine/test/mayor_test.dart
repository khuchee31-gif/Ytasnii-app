// Хотын дарга (v2).
//
// ШӨНИЙН ҮЙЛДЭЛ БАЙХГҮЙ — иргэнтэй яг адил. Түүний бүх хүч нь ӨДӨР:
// нэг удаа өөрийгөө илчилж, тэр цагаас хойш гурван саналтай болно.
//
// ХӨДӨЛГҮҮРИЙН ТАЛД ЮУ ХАМААРАХ ВЭ: ЗӨВХӨН ялалтын нөхцөл. Мафийн
// «ялалт» гэдэг нь тоогоороо тэнцээд өдрийн саналыг дийлнэ гэсэн үг.
// Хотод нэмэлт санал байвал тэр дүгнэлт ХУДАЛ болно — эс бөгөөс
// тоглоом илчилсэн дарга байсаар байхад дуусна.

import 'package:engine/src/model.dart';
import 'package:engine/src/resolve.dart';
import 'package:engine/src/rosters.dart';
import 'package:test/test.dart';

/// P1·P2 мафи, P3 дарга, P4…P6 иргэн.
const Map<Seat, Role> k6 = <Seat, Role>{
  1: Role.killer,
  2: Role.killer,
  3: Role.mayor,
  4: Role.citizen,
  5: Role.citizen,
  6: Role.citizen,
};

const Setup s6 = Setup(n: 6, roleBySeat: k6);

void main() {
  group('Ялалтын нөхцөл', () {
    test('илчлээгүй дарга нь энгийн иргэнтэй адил', () {
      // 2 мафи, 2 хотынхон → мафи ялна.
      expect(evaluateWin(<Seat>{1, 2, 3, 4}, s6), WinState.mafi);
    });

    test('ИЛЧИЛСЭН дарга нь мафийн тэнцлийг сарниулна', () {
      // Ижил суудлууд, гэхдээ 3 нь илчилсэн: хотын санал 2 + 2 = 4 > 2.
      expect(evaluateWin(<Seat>{1, 2, 3, 4}, s6, revealedMayors: <Seat>{3}),
          WinState.none);
    });

    test('дарга ҮХСЭН бол нэмэлт саналгүй', () {
      expect(evaluateWin(<Seat>{1, 2, 4}, s6, revealedMayors: <Seat>{3}),
          WinState.mafi);
    });

    test('дарга БИШ суудлыг илчилсэн гэж хэлэхэд нөлөөгүй', () {
      // Хортой оролтоос хамгаална: `revealedMayors` нь СЕРВЕРЭЭС ирэх ч
      // дүрийг заавал шалгана.
      expect(evaluateWin(<Seat>{1, 2, 3, 4}, s6, revealedMayors: <Seat>{4}),
          WinState.mafi);
    });

    test('мафи бүгд үхвэл дарга хамаагүй — хот ялна', () {
      expect(evaluateWin(<Seat>{3, 4, 5}, s6, revealedMayors: <Seat>{3}),
          WinState.hotynhon);
      expect(evaluateWin(<Seat>{3, 4, 5}, s6), WinState.hotynhon);
    });

    test('хоёр нэмэлт санал ХҮРЭЛЦЭХГҮЙ үед мафи ялсаар', () {
      // 3 мафи, 1 дарга: 3 >= 1 + 2 → мафи.
      const Map<Seat, Role> k8 = <Seat, Role>{
        1: Role.killer,
        2: Role.killer,
        3: Role.killer,
        4: Role.mayor,
        5: Role.citizen,
        6: Role.citizen,
        7: Role.citizen,
        8: Role.citizen,
      };
      const Setup s8 = Setup(n: 8, roleBySeat: k8);
      expect(evaluateWin(<Seat>{1, 2, 3, 4}, s8, revealedMayors: <Seat>{4}),
          WinState.mafi);
    });
  });

  group('Шөнө', () {
    test('даргын чадвар нь ИРГЭНИЙХ — шөнө ялгарахгүй', () {
      expect(abilityOf(Role.mayor), abilityOf(Role.citizen));
      expect(bucketOf(abilityOf(Role.mayor)), 135);
    });

    test('дарга нь ХОТЫНХОН', () {
      expect(factionOf(Role.mayor), Faction.hotynhon);
    });
  });

  group('Бүрэлдэхүүн', () {
    test('дарга нэг ИРГЭНИЙ суудлыг орлоно', () {
      for (int n = kMinSeats; n <= kMaxSeats; n++) {
        final Roster plain = rosterFor(n);
        final Roster m = rosterFor(n, mayor: true);
        expect(m.mafia, plain.mafia);
        expect(m.b, plain.b);
        expect(m.citizens, plain.citizens - 1);
        expect(deckFor(m).where((Role r) => r == Role.mayor).length, 1);
        expect(deckFor(m).length, n);
      }
    });

    test('Ажиглагч, дарга ХОЁУЛАА нэг зэрэг', () {
      for (int n = kMinSeats; n <= kMaxSeats; n++) {
        final Roster both = rosterFor(n, watcher: true, mayor: true);
        expect(both.watcher, isTrue);
        expect(both.mayor, isTrue);
        expect(both.citizens, rosterFor(n).citizens - 2);
        expect(deckFor(both).length, n);
      }
    });

    test('иргэн үлдэхгүй бол нэмэлт дүр ОРОХГҮЙ', () {
      // N=6-д гурван иргэн байна: хоёрыг нь сольвол нэг үлдэнэ.
      // Гурав дахийг нь сольж БОЛОХГҮЙ — чимээгүй суудал байхгүй бол
      // дуугүй хүн тэр дороо сэжигтэй болно.
      final Roster r = rosterFor(6).withWatcher().withMayor();
      expect(r.citizens, 1);
      final Roster again = r.withWatcher();
      expect(again.citizens, 1, reason: 'сүүлчийн иргэнийг ч авч одлоо');
    });

    test('анхдагчаар хоёулаа УНТРААЛТТАЙ', () {
      for (int n = kMinSeats; n <= kMaxSeats; n++) {
        expect(rosterFor(n).mayor, isFalse);
        expect(deckFor(rosterFor(n)).contains(Role.mayor), isFalse);
      }
    });
  });
}
