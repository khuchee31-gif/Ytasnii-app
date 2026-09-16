// ChaCha20, rejection sampling ба Fisher-Yates-ийн тест.
//
// GDD-05 §7.2: «Хэрэгжүүлэлт нь ~60 мөр, RFC 8439-ийн тест векторуудаар
// шалгагдана — тэр тест нь `flutter test`-ийн хамгийн хямд, хамгийн үнэ
// цэнтэй файл.» Тиймээс доорх векторууд нь RFC 8439-ээс ҮГ ҮСГЭЭР авагдсан,
// өөрийн гаралтаас хуулагдаагүй.

import 'dart:convert';
import 'dart:typed_data';

import 'package:engine/src/hash.dart';
import 'package:engine/src/rng.dart';
import 'package:test/test.dart';

Uint8List _bytes(String hexStr) {
  final String s = hexStr.replaceAll(RegExp(r'[^0-9a-fA-F]'), '');
  final Uint8List out = Uint8List(s.length ~/ 2);
  for (int i = 0; i < out.length; i++) {
    out[i] = int.parse(s.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return out;
}

/// χ² статистик. Тестийн файлд `double` зөвшөөрөгдөнө — хориг нь `lib/`-д.
double _chiSquare(List<int> observed, double expected) {
  double chi = 0;
  for (final int o in observed) {
    final double d = o - expected;
    chi += d * d / expected;
  }
  return chi;
}

void main() {
  group('ChaCha20 — RFC 8439', () {
    test('§2.3.2 түлхүүрийн урсгалын блок', () {
      final Uint8List key = _bytes(
        '000102030405060708090a0b0c0d0e0f'
        '101112131415161718191a1b1c1d1e1f',
      );
      final Uint8List nonce = _bytes('000000090000004a00000000');
      final Uint8List block = chacha20Block(key, nonce, 1);
      expect(
        hex(block),
        '10f1e7e4d13b5915500fdd1fa32071c4'
        'c7d1f4c733c068030422aa9ac3d46c4e'
        'd2826446079faa0914c2d705d98b02a2'
        'b5129cd1de164eb9cbd083e8a2503c4e',
      );
    });

    test('§2.4.2 шифрлэлт — 114 байтын мессеж', () {
      final Uint8List key = _bytes(
        '000102030405060708090a0b0c0d0e0f'
        '101112131415161718191a1b1c1d1e1f',
      );
      final Uint8List nonce = _bytes('000000000000004a00000000');
      final List<int> plain = utf8.encode(
        "Ladies and Gentlemen of the class of '99: If I could offer you "
        'only one tip for the future, sunscreen would be it.',
      );
      expect(plain.length, 114);

      final Uint8List cipher = chacha20Xor(
        key32: key,
        nonce12: nonce,
        counter: 1,
        data: plain,
      );
      expect(
        hex(cipher),
        '6e2e359a2568f98041ba0728dd0d6981'
        'e97e7aec1d4360c20a27afccfd9fae0b'
        'f91b65c5524733ab8f593dabcd62b357'
        '1639d624e65152ab8f530c359f0861d8'
        '07ca0dbf500d6a6156a38e088a22b65e'
        '52bc514d16ccf806818ce91ab7793736'
        '5af90bbf74a35be6b40b8eedf2785e42'
        '874d',
      );

      // XOR нь өөртэйгөө урвуу — тайлбал анхны текст буцаж гарна.
      final Uint8List back = chacha20Xor(
        key32: key,
        nonce12: nonce,
        counter: 1,
        data: cipher,
      );
      expect(utf8.decode(back), startsWith('Ladies and Gentlemen'));
    });

    test('буруу урттай түлхүүр/nonce шиднэ', () {
      expect(
        () => chacha20Block(Uint8List(31), Uint8List(12), 0),
        throwsArgumentError,
      );
      expect(
        () => chacha20Block(Uint8List(32), Uint8List(8), 0),
        throwsArgumentError,
      );
    });
  });

  group('Rng — урсгал', () {
    test('nextU32 нь түлхүүрийн урсгалын 4 байтыг big-endian уншина', () {
      final Uint8List key = sha256(utf8.encode('rng-endianness'));
      final Uint8List block = chacha20Block(key, Uint8List(12), 0);
      final Rng r = Rng(key);
      for (int i = 0; i < 4; i++) {
        final int expected = (block[i * 4] << 24) |
            (block[i * 4 + 1] << 16) |
            (block[i * 4 + 2] << 8) |
            block[i * 4 + 3];
        expect(r.nextU32(), expected, reason: 'үг $i');
      }
    });

    test('блокийн заагийг алгасахгүй (16 үгийн дараа шинэ блок)', () {
      final Uint8List key = sha256(utf8.encode('rng-block-boundary'));
      final Rng r = Rng(key);
      final List<int> got = <int>[for (int i = 0; i < 32; i++) r.nextU32()];
      final Uint8List b0 = chacha20Block(key, Uint8List(12), 0);
      final Uint8List b1 = chacha20Block(key, Uint8List(12), 1);
      final Uint8List all = Uint8List(128)
        ..setRange(0, 64, b0)
        ..setRange(64, 128, b1);
      for (int i = 0; i < 32; i++) {
        final int expected = (all[i * 4] << 24) |
            (all[i * 4 + 1] << 16) |
            (all[i * 4 + 2] << 8) |
            all[i * 4 + 3];
        expect(got[i], expected, reason: 'үг $i');
      }
    });

    test('ижил түлхүүр → ижил урсгал (детерминизм)', () {
      final Uint8List key = sha256(utf8.encode('same'));
      final Rng a = Rng(key);
      final Rng b = Rng(Uint8List.fromList(key));
      for (int i = 0; i < 64; i++) {
        expect(a.nextU32(), b.nextU32());
      }
    });

    test('DEAL ба ORDER нь домэйн тусгаарлагдсан, өөр урсгал', () {
      final Uint8List seed = sha256(utf8.encode('seed'));
      final Rng d = Rng(streamKey(seed, 'DEAL'));
      final Rng o = Rng(streamKey(seed, 'ORDER'));
      final List<int> ds = <int>[for (int i = 0; i < 8; i++) d.nextU32()];
      final List<int> os = <int>[for (int i = 0; i < 8; i++) o.nextU32()];
      expect(ds, isNot(os));
    });

    test('буруу урттай түлхүүр шиднэ', () {
      expect(() => Rng(Uint8List(16)), throwsArgumentError);
    });

    test('nextU32 нь үргэлж 0..2^32-1 дотор', () {
      final Rng r = Rng(sha256(utf8.encode('range')));
      for (int i = 0; i < 4096; i++) {
        final int x = r.nextU32();
        expect(x, greaterThanOrEqualTo(0));
        expect(x, lessThan(0x100000000));
      }
    });
  });

  group('below — modulo хазайлт БАЙХГҮЙ', () {
    test('татгалзлын хил яг тооцоологдсон', () {
      // 2^32 = 4294967296.
      expect(rejectionLimit(1), 4294967296);
      expect(rejectionLimit(2), 4294967296); // 2^32-ыг жигд хуваана
      expect(rejectionLimit(4), 4294967296);
      expect(rejectionLimit(3), 4294967295); // 2^32 mod 3 == 1
      expect(rejectionLimit(7), 4294967292); // 2^32 mod 7 == 4
      expect(rejectionLimit(10), 4294967290); // 2^32 mod 10 == 6
      expect(rejectionLimit(12), 4294967292); // 2^32 mod 12 == 4
      expect(rejectionLimit(20), 4294967280); // 2^32 mod 20 == 16
    });

    test('хил нь bound-д ҮРГЭЛЖ бүхлээр хуваагдана (1..2000)', () {
      // Энэ бол хазайлтгүй байдлын ЯГ тодорхойлолт: хүлээн зөвшөөрөгдсөн
      // муж нь тэнцүү хэмжээтэй `bound` хэсэгт хуваагдана.
      for (int b = 1; b <= 2000; b++) {
        final int limit = rejectionLimit(b);
        expect(limit % b, 0, reason: 'bound $b');
        expect(limit, lessThanOrEqualTo(0x100000000));
        expect(0x100000000 - limit, lessThan(b), reason: 'bound $b');
      }
    });

    test('bound < 1 бол шиднэ', () {
      expect(() => rejectionLimit(0), throwsArgumentError);
      expect(() => rejectionLimit(-3), throwsArgumentError);
    });

    test('below(1) үргэлж 0', () {
      final Rng r = Rng(sha256(utf8.encode('one')));
      for (int i = 0; i < 100; i++) {
        expect(r.below(1), 0);
      }
    });

    test('χ²: below(3) жигд (df=2, p=0.001 → 13.816)', () {
      final Rng r = Rng(sha256(utf8.encode('chi-3')));
      const int draws = 300000;
      final List<int> counts = List<int>.filled(3, 0);
      for (int i = 0; i < draws; i++) {
        counts[r.below(3)]++;
      }
      expect(counts.reduce((int a, int b) => a + b), draws);
      expect(_chiSquare(counts, draws / 3), lessThan(13.816));
    });

    test('χ²: below(7) жигд (df=6, p=0.001 → 22.457)', () {
      final Rng r = Rng(sha256(utf8.encode('chi-7')));
      const int draws = 350000;
      final List<int> counts = List<int>.filled(7, 0);
      for (int i = 0; i < draws; i++) {
        counts[r.below(7)]++;
      }
      expect(_chiSquare(counts, draws / 7), lessThan(22.457));
    });

    test('χ²: below(10) жигд (df=9, p=0.001 → 27.877)', () {
      final Rng r = Rng(sha256(utf8.encode('chi-10')));
      const int draws = 300000;
      final List<int> counts = List<int>.filled(10, 0);
      for (int i = 0; i < draws; i++) {
        counts[r.below(10)]++;
      }
      expect(_chiSquare(counts, draws / 10), lessThan(27.877));
    });
  });

  group('fisherYates', () {
    test('оролтоо ӨӨРЧЛӨХГҮЙ, сэлгэмэл нь multiset-ээ хадгална', () {
      final List<int> src = <int>[1, 2, 3, 4, 5, 6, 7, 8];
      final List<int> copy = List<int>.of(src);
      final List<int> out = fisherYates(src, Rng(sha256(utf8.encode('fy'))));
      expect(src, copy, reason: 'цэвэр функц — оролт хөндөгдөхгүй');
      expect(out.length, src.length);
      expect(List<int>.of(out)..sort(), copy);
    });

    test('хоосон ба нэг элемент', () {
      final Rng r = Rng(sha256(utf8.encode('edge')));
      expect(fisherYates(<int>[], r), <int>[]);
      expect(fisherYates(<int>[42], r), <int>[42]);
    });

    test('ижил түлхүүр → ижил сэлгэмэл', () {
      final Uint8List k = sha256(utf8.encode('det'));
      final List<int> a = fisherYates(<int>[1, 2, 3, 4, 5, 6], Rng(k));
      final List<int> b = fisherYates(<int>[1, 2, 3, 4, 5, 6], Rng(k));
      expect(a, b);
    });

    test('3 элементийн 6 сэлгэмэл бүгд гарч ирнэ', () {
      final Set<String> seen = <String>{};
      for (int s = 0; s < 400; s++) {
        final Rng r = Rng(sha256(utf8.encode('perm3:$s')));
        seen.add(fisherYates(<int>[1, 2, 3], r).join(','));
      }
      expect(seen.length, 6);
    });

    test(
      'жигд: 200,000 seed × 12 суудал, суудал тутмын χ² < 31.264 (p=0.001)',
      () {
        // GDD-05 §10.2 «Fisher-Yates жигд» + GDD-10 §10 `deal_uniformity_test`.
        const int trials = 200000;
        const int n = 12;
        // counts[суудал][хөзрийн индекс]
        final List<List<int>> counts = <List<int>>[
          for (int i = 0; i < n; i++) List<int>.filled(n, 0),
        ];
        final List<int> labels = <int>[for (int i = 0; i < n; i++) i];
        // MN_12 бүрэлдэхүүн: индекс 0,1,2 нь мафи (Ахлагч + 2 Алуурчин),
        // 3 Эмч, 4 Мөрдөгч, 5..11 Иргэн → M/N = 3/12 = 0.25.
        final List<int> mafiaAt = List<int>.filled(n, 0);

        for (int t = 0; t < trials; t++) {
          final Rng r = Rng(sha256(utf8.encode('fy:$t')));
          final List<int> p = fisherYates(labels, r);
          for (int seat = 0; seat < n; seat++) {
            counts[seat][p[seat]]++;
            if (p[seat] < 3) mafiaAt[seat]++;
          }
        }

        const double expected = trials / n;
        for (int seat = 0; seat < n; seat++) {
          final double chi = _chiSquare(counts[seat], expected);
          expect(
            chi,
            lessThan(31.264),
            reason: 'суудал ${seat + 1}: χ² = $chi',
          );
        }

        // GDD-10 §10: суудал тутмын мафийн давтамж 0.25 ± 0.004.
        for (int seat = 0; seat < n; seat++) {
          final double freq = mafiaAt[seat] / trials;
          expect(
            (freq - 0.25).abs(),
            lessThan(0.004),
            reason: 'суудал ${seat + 1}: мафийн давтамж $freq',
          );
        }
      },
      timeout: const Timeout(Duration(seconds: 120)),
    );
  });
}
