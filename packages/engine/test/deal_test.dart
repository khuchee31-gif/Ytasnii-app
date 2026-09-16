// Seed-ийн гарал, шударга байдлын код ба тараалтын тест.
//
// GDD-10 §2 алгоритмыг эзэмшинэ; §10-ийн `deal_golden_test` нь ГУРВАН
// бэхжүүлсэн вектор шаарддаг: `(seed0, userEntropy, N, M)` → ЯГ ТЭР
// суудал-дүрийн жагсаалт. Тараалтыг чимээгүйхэн өөрчилсөн refactor нь
// build-ыг унагана.

import 'dart:convert';
import 'dart:typed_data';

import 'package:engine/src/canon.dart';
import 'package:engine/src/deal.dart';
import 'package:engine/src/hash.dart';
import 'package:engine/src/model.dart';
import 'package:test/test.dart';

Uint8List _b(String hexStr) {
  final Uint8List out = Uint8List(hexStr.length ~/ 2);
  for (int i = 0; i < out.length; i++) {
    out[i] = int.parse(hexStr.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return out;
}

/// GDD-04 §2-ын хүснэгтийн бүрэлдэхүүн. (Жинхэнэ эх сурвалж нь `rosters.dart`;
/// энэ тест `deal`-ыг тусгаарлан шалгах тул өөрийн хөзрийг барина.)
List<Role> _roster(int n, int m, {required bool boss}) => <Role>[
      if (boss) Role.boss,
      for (int i = 0; i < (boss ? m - 1 : m); i++) Role.killer,
      Role.doctor,
      Role.detective,
      for (int i = 0; i < n - m - 2; i++) Role.citizen,
    ];

List<String> _roleNames(Map<Seat, Role> m, int n) =>
    <String>[for (int s = 1; s <= n; s++) m[s]!.name];

void main() {
  group('fairnessCode / fairnessDigits', () {
    test('зургаан цифр, тэгээр нөхөгдөж, 3+3 хэлбэрээр', () {
      // u32be(h0[0..4]) = 42 → 42 % 1000000 = 42 → «000042» → «000-042»
      final Uint8List h0 = Uint8List(32)..[3] = 42;
      expect(fairnessDigits(h0), '000042');
      expect(fairnessCode(h0), '000-042');
    });

    test('u32be-ийн бүтэн утга дээр modulo', () {
      // 0xFFFFFFFF = 4294967295 → % 1000000 = 967295
      final Uint8List h0 = Uint8List(32);
      for (int i = 0; i < 4; i++) {
        h0[i] = 0xFF;
      }
      expect(fairnessDigits(h0), '967295');
      expect(fairnessCode(h0), '967-295');
    });

    test('үргэлж 7 тэмдэгт, дунд нь зураас', () {
      for (int i = 0; i < 200; i++) {
        final Uint8List h0 = sha256(utf8.encode('fc:$i'));
        final String c = fairnessCode(h0);
        expect(c.length, 7);
        expect(c[3], '-');
        expect(fairnessDigits(h0).length, 6);
        expect(int.parse(fairnessDigits(h0)), lessThan(1000000));
      }
    });

    test('богино h0 бол шиднэ', () {
      expect(() => fairnessCode(Uint8List(4)), throwsArgumentError);
    });
  });

  group('dealIdOf', () {
    test('h0[4..8]-ийн hex, 8 тэмдэгт', () {
      final Uint8List h0 = Uint8List(32);
      h0[4] = 0x9f;
      h0[5] = 0x3a;
      h0[6] = 0x1c;
      h0[7] = 0x07;
      expect(dealIdOf(h0), '9f3a1c07');
    });
  });

  group('readerSeatOf', () {
    test('утас барьсан суудлыг ХЭЗЭЭ Ч сонгохгүй', () {
      for (int i = 0; i < 500; i++) {
        final Uint8List h0 = sha256(utf8.encode('reader:$i'));
        for (final int holder in <int>[1, 6, 12]) {
          final Seat r = readerSeatOf(h0, 12, holderSeat: holder);
          expect(r, isNot(holder));
          expect(r, inInclusiveRange(1, 12));
        }
      }
    });

    test('детерминист — ижил h0 → ижил суудал', () {
      final Uint8List h0 = sha256(utf8.encode('stable'));
      expect(
        readerSeatOf(h0, 12, holderSeat: 3),
        readerSeatOf(h0, 12, holderSeat: 3),
      );
    });

    test('бүх боломжит суудал гарч ирнэ (12 суудал, барьсан нь 1)', () {
      final Set<Seat> seen = <Seat>{};
      for (int i = 0; i < 2000; i++) {
        seen.add(readerSeatOf(sha256(utf8.encode('cover:$i')), 12,
            holderSeat: 1));
      }
      expect(seen, <Seat>{2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12});
    });

    test('утас барьсан хүн ширээнд байхгүй бол бүх суудал сонгогдоно', () {
      final Uint8List h0 = sha256(utf8.encode('outsider'));
      expect(readerSeatOf(h0, 6, holderSeat: 99), inInclusiveRange(1, 6));
    });

    test('ганц суудалтай ширээнд гарц байхгүй → шиднэ', () {
      final Uint8List h0 = sha256(utf8.encode('alone'));
      expect(() => readerSeatOf(h0, 1, holderSeat: 1), throwsArgumentError);
    });
  });

  group('deriveSeed', () {
    final Uint8List seed0 = sha256(utf8.encode('s0'));
    final Uint8List ent = Uint8List.fromList(utf8.encode('7104'));

    test('32 байт', () {
      expect(
        deriveSeed(dealId: 'aabbccdd', seed0: seed0, userEntropy: ent).length,
        32,
      );
    });

    test('домэйн шошго ‖ dealId ‖ seed0 ‖ userEntropy (GDD-10 §2)', () {
      final Uint8List expected = sha256(<int>[
        ...utf8.encode('HOTUNTLAA/v1'),
        ...utf8.encode('aabbccdd'),
        ...seed0,
        ...ent,
      ]);
      expect(
        deriveSeed(dealId: 'aabbccdd', seed0: seed0, userEntropy: ent),
        expected,
      );
    });

    test('оролт бүр seed-ыг өөрчилнө', () {
      final Uint8List base =
          deriveSeed(dealId: 'aabbccdd', seed0: seed0, userEntropy: ent);
      expect(
        deriveSeed(dealId: 'aabbccde', seed0: seed0, userEntropy: ent),
        isNot(base),
      );
      expect(
        deriveSeed(
          dealId: 'aabbccdd',
          seed0: sha256(utf8.encode('s1')),
          userEntropy: ent,
        ),
        isNot(base),
      );
      expect(
        deriveSeed(
          dealId: 'aabbccdd',
          seed0: seed0,
          userEntropy: Uint8List.fromList(utf8.encode('7105')),
        ),
        isNot(base),
      );
    });

    test('хоосон userEntropy ч ажиллана (сэгсрэлт бүтэлгүйтсэн тохиолдол)', () {
      expect(
        deriveSeed(
          dealId: 'aabbccdd',
          seed0: seed0,
          userEntropy: Uint8List(0),
        ).length,
        32,
      );
    });
  });

  group('deal — бүтцийн шалгалт', () {
    final Uint8List seed0 = sha256(utf8.encode('deal-structure'));
    final Uint8List ent = Uint8List.fromList(utf8.encode('1234'));

    test('суудал 1..n бүрд яг нэг дүр, multiset нь хөзөртэйгээ ижил', () {
      for (int n = 6; n <= 20; n++) {
        final int m = n >= 12 ? 3 : 2;
        final List<Role> deck = _roster(n, m, boss: n >= 12);
        final DealResult r = deal(
          seed0: seed0,
          userEntropy: ent,
          n: n,
          deck: deck,
          holderSeat: 1,
        );
        expect(r.roleBySeat.length, n, reason: 'n=$n');
        expect(
          r.roleBySeat.keys.toList()..sort(),
          <int>[for (int s = 1; s <= n; s++) s],
        );
        final List<String> got = r.roleBySeat.values.map((Role x) => x.name)
            .toList()
          ..sort();
        final List<String> want = deck.map((Role x) => x.name).toList()..sort();
        expect(got, want, reason: 'n=$n');
      }
    });

    test('orderPerm нь 1..n-ийн сэлгэмэл', () {
      final DealResult r = deal(
        seed0: seed0,
        userEntropy: ent,
        n: 12,
        deck: _roster(12, 3, boss: true),
        holderSeat: 1,
      );
      expect(r.orderPerm.length, 12);
      expect(
        List<Seat>.of(r.orderPerm)..sort(),
        <int>[for (int s = 1; s <= 12; s++) s],
      );
    });

    test('хоёр урсгал тусгаарлагдсан: хөзөр солигдвол orderPerm хэвээр', () {
      // `orderPerm` нь ил бичигдэнэ (GAME_CREATED) — тиймээс тэр нь нуугдмал
      // тараалтын тухай ямар ч мэдээлэл агуулж болохгүй (GDD-05 §7.2).
      final DealResult a = deal(
        seed0: seed0,
        userEntropy: ent,
        n: 12,
        deck: _roster(12, 3, boss: true),
        holderSeat: 1,
      );
      final List<Role> shuffledDeck = _roster(12, 3, boss: true).reversed
          .toList();
      final DealResult b = deal(
        seed0: seed0,
        userEntropy: ent,
        n: 12,
        deck: shuffledDeck,
        holderSeat: 1,
      );
      expect(b.orderPerm, a.orderPerm);
    });

    test('holderSeat нь зөвхөн readerSeat-д нөлөөлнө, тараалтад биш', () {
      final DealResult a = deal(
        seed0: seed0,
        userEntropy: ent,
        n: 12,
        deck: _roster(12, 3, boss: true),
        holderSeat: 1,
      );
      final DealResult b = deal(
        seed0: seed0,
        userEntropy: ent,
        n: 12,
        deck: _roster(12, 3, boss: true),
        holderSeat: 5,
      );
      expect(canon(b.roleBySeat), canon(a.roleBySeat));
      expect(b.orderPerm, a.orderPerm);
      expect(b.readerSeat, isNot(5));
    });

    test('fairCode/dealId/readerSeat нь seed0-оос ГАНЦААРАА гарна', () {
      // userEntropy-г өөрчилсөн ч амлалт (commit) өөрчлөгдөхгүй — эс бөгөөс
      // хөтлөгч кодыг хараад дараа нь сэгсрэлтээр түүнийг хөдөлгөж чадна.
      final DealResult a = deal(
        seed0: seed0,
        userEntropy: ent,
        n: 12,
        deck: _roster(12, 3, boss: true),
        holderSeat: 1,
      );
      final DealResult b = deal(
        seed0: seed0,
        userEntropy: Uint8List.fromList(utf8.encode('9999')),
        n: 12,
        deck: _roster(12, 3, boss: true),
        holderSeat: 1,
      );
      expect(b.fairCode, a.fairCode);
      expect(b.dealId, a.dealId);
      expect(b.readerSeat, a.readerSeat);
      // Гэвч тараалт нь өөр — хүний энтропи ажиллаж байна.
      expect(canon(b.roleBySeat), isNot(canon(a.roleBySeat)));
    });

    test('буруу оролт шиднэ', () {
      expect(
        () => deal(
          seed0: Uint8List(16),
          userEntropy: ent,
          n: 6,
          deck: _roster(6, 1, boss: false),
          holderSeat: 1,
        ),
        throwsArgumentError,
      );
      expect(
        () => deal(
          seed0: seed0,
          userEntropy: ent,
          n: 12,
          deck: _roster(10, 2, boss: false),
          holderSeat: 1,
        ),
        throwsArgumentError,
      );
    });

    test('гаралтын цуглуулгууд ӨӨРЧЛӨГДӨХГҮЙ', () {
      final DealResult r = deal(
        seed0: seed0,
        userEntropy: ent,
        n: 8,
        deck: _roster(8, 2, boss: false),
        holderSeat: 1,
      );
      expect(() => r.roleBySeat[1] = Role.killer, throwsUnsupportedError);
      expect(() => r.orderPerm[0] = 99, throwsUnsupportedError);
    });
  });

  group('deal — детерминизм (N1-ийн үндэс)', () {
    test('ижил оролт → БАЙТ ИЖИЛ үр дүн, хоёр удаа', () {
      final Uint8List seed0 = _b(
        '9a3f1c0d5e7b2a84c6d9f0e1b3a5c7d92f4e6a8b0c1d3e5f7a9b0c2d4e6f8a10',
      );
      final Uint8List ent = Uint8List.fromList(utf8.encode('4213'));
      final List<Role> deck = _roster(12, 3, boss: true);

      final DealResult a = deal(
        seed0: seed0,
        userEntropy: ent,
        n: 12,
        deck: deck,
        holderSeat: 2,
      );
      final DealResult b = deal(
        seed0: Uint8List.fromList(seed0),
        userEntropy: Uint8List.fromList(ent),
        n: 12,
        deck: List<Role>.of(deck),
        holderSeat: 2,
      );

      expect(canon(b.toCanon()), canon(a.toCanon()));
      expect(canonHash(b.toCanon()), canonHash(a.toCanon()));
      expect(hex(b.seed), hex(a.seed));
    });
  });

  // ---------------------------------------------------------------------
  // GOLDEN — GDD-10 §10 `deal_golden_test`.
  // Эдгээр тоог ӨӨРЧЛӨХ нь тараалтыг өөрчилсөн гэсэн үг. Хэрэв энэ тест
  // унавал refactor нь алгоритмыг хөдөлгөсөн — засвар нь ТООГ БИШ, КОДЫГ.
  // ---------------------------------------------------------------------
  group('deal — golden вектор (GDD-10 §10)', () {
    test('V1 · N=12, M=3 (Ахлагчтай) · userEntropy = "7104"', () {
      final DealResult r = deal(
        seed0: _b(
          '000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f',
        ),
        userEntropy: Uint8List.fromList(utf8.encode('7104')),
        n: 12,
        deck: _roster(12, 3, boss: true),
        holderSeat: 1,
      );
      expect(r.fairCode, '848-873');
      expect(r.dealId, '66c43366');
      expect(r.readerSeat, 4);
      expect(
        hex(r.seed),
        'fa7acb8148455e9218c81ab56cd7ebd72823fe3ee2193af42802f45510929e26',
      );
      expect(_roleNames(r.roleBySeat, 12), <String>[
        'doctor',
        'citizen',
        'citizen',
        'detective',
        'killer',
        'citizen',
        'killer',
        'citizen',
        'citizen',
        'citizen',
        'citizen',
        'boss',
      ]);
      expect(r.orderPerm, <int>[12, 10, 6, 2, 11, 7, 1, 5, 4, 8, 3, 9]);
    });

    test('V2 · N=10, M=2 · userEntropy = "4213"', () {
      final DealResult r = deal(
        seed0: _b(
          'ffeeddccbbaa99887766554433221100'
          '0f1e2d3c4b5a69788796a5b4c3d2e1f0',
        ),
        userEntropy: Uint8List.fromList(utf8.encode('4213')),
        n: 10,
        deck: _roster(10, 2, boss: false),
        holderSeat: 7,
      );
      expect(r.fairCode, '657-699');
      expect(r.dealId, 'd76ba082');
      expect(r.readerSeat, 8);
      expect(
        hex(r.seed),
        'ef9b0e97c79934105479fb622bc3ee8105688259298b79a4a7e17eccc99271e1',
      );
      expect(_roleNames(r.roleBySeat, 10), <String>[
        'detective',
        'citizen',
        'doctor',
        'citizen',
        'citizen',
        'citizen',
        'killer',
        'citizen',
        'citizen',
        'killer',
      ]);
      expect(r.orderPerm, <int>[7, 4, 3, 9, 1, 5, 8, 6, 2, 10]);
    });

    test('V3 · N=8, M=2 · seed0 = тэг, userEntropy = сэгсрэлтийн 4 байт', () {
      final DealResult r = deal(
        seed0: _b('00' * 32),
        userEntropy: Uint8List.fromList(<int>[1, 2, 3, 4]),
        n: 8,
        deck: _roster(8, 2, boss: false),
        holderSeat: 3,
      );
      expect(r.fairCode, '123-181');
      expect(r.dealId, 'f862bd77');
      expect(r.readerSeat, 2);
      expect(
        hex(r.seed),
        '5efc3d853a2650f1cd9c70b6a04e8cb4111bff6bebdae1a7e6a643d0ab6d1847',
      );
      expect(_roleNames(r.roleBySeat, 8), <String>[
        'citizen',
        'citizen',
        'citizen',
        'detective',
        'killer',
        'doctor',
        'killer',
        'citizen',
      ]);
      expect(r.orderPerm, <int>[6, 5, 3, 1, 4, 7, 8, 2]);
    });
  });
}
