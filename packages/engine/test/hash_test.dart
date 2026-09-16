// SHA-256 ба каноник цувралчлалын тест.
//
// Тест векторууд: FIPS 180-4 / NIST-ийн стандарт жишээнүүд. Эдгээр нь
// ГАДНЫ эх сурвалжаас ирсэн тоонууд — өөрийн гаралтаа өөртэйгээ
// харьцуулсан «snapshot» БИШ.

import 'dart:convert';
import 'dart:typed_data';

import 'package:engine/src/canon.dart';
import 'package:engine/src/hash.dart';
import 'package:test/test.dart';

void main() {
  group('sha256 — стандарт вектор', () {
    test('хоосон мөр', () {
      expect(
        sha256Hex(<int>[]),
        'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
      );
    });

    test('"abc"', () {
      expect(
        sha256Hex(utf8.encode('abc')),
        'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
      );
    });

    test('448 битийн мессеж (56 байт, нэг блок)', () {
      const String m =
          'abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq';
      expect(m.length, 56);
      expect(
        sha256Hex(utf8.encode(m)),
        '248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1',
      );
    });

    test('896 битийн мессеж (112 байт, хоёр блок)', () {
      const String m = 'abcdefghbcdefghicdefghijdefghijkefghijklfghijklmghijklmn'
          'hijklmnoijklmnopjklmnopqklmnopqrlmnopqrsmnopqrstnopqrstu';
      expect(m.length, 112);
      expect(
        sha256Hex(utf8.encode(m)),
        'cf5b16a778af8380036ce59e7b0492370b249b11e8f07a51afac45037afee9d1',
      );
    });

    test('дүүргэлтийн бүх урт 0..135 дээр 32 байт гарна', () {
      for (int len = 0; len <= 135; len++) {
        final List<int> data = List<int>.generate(len, (int i) => i & 0xFF);
        expect(sha256(data).length, 32, reason: 'урт $len');
      }
    });

    test('нэг тэмдэгтийн өөрчлөлт дайджестыг бүрэн өөрчилнө', () {
      final String a = sha256Hex(utf8.encode('abc'));
      final String b = sha256Hex(utf8.encode('abd'));
      expect(a, isNot(b));
    });
  });

  group('hex', () {
    test('жижиг үсэг, тэгээр нөхөгдсөн', () {
      expect(hex(<int>[0x00, 0x0f, 0xff, 0xa3]), '000fffa3');
    });

    test('хоосон', () {
      expect(hex(<int>[]), '');
    });
  });

  group('canon — детерминист цувралчлал', () {
    test('Map-ийн түлхүүр эрэмбэлэгдэнэ (мөр)', () {
      expect(
        canon(<String, Object?>{'b': 1, 'a': 2, 'c': 3}),
        '{"a":2,"b":1,"c":3}',
      );
      // Оруулах дараалал үр дүнд нөлөөлөхгүй.
      expect(
        canon(<String, Object?>{'c': 3, 'b': 1, 'a': 2}),
        canon(<String, Object?>{'a': 2, 'b': 1, 'c': 3}),
      );
    });

    test('бүхэл тоон түлхүүр ТООГООР эрэмбэлэгдэнэ, мөрөөр биш', () {
      expect(
        canon(<int, Object?>{10: 'x', 2: 'y', 1: 'z'}),
        '{"1":"z","2":"y","10":"x"}',
      );
    });

    test('жагсаалтын дараалал ХАДГАЛАГДАНА', () {
      expect(canon(<int>[3, 1, 2]), '[3,1,2]');
    });

    test('Set нь каноник мөрөөр эрэмбэлэгдэнэ', () {
      expect(canon(<int>{3, 1, 2}), canon(<int>{2, 3, 1}));
      expect(canon(<int>{3, 1, 2}), '[1,2,3]');
    });

    test('Uint8List нь hex мөр болно', () {
      expect(canon(Uint8List.fromList(<int>[0xde, 0xad])), '"dead"');
    });

    test('enum нь нэрээрээ бичигдэнэ', () {
      expect(canon(_Suit.hearts), '"hearts"');
      expect(canon(<Object?>[_Suit.spades, _Suit.hearts]),
          '["spades","hearts"]');
    });

    test('мөрийн escape', () {
      expect(canon('a"b\\c\nd'), r'"a\"b\\c\nd"');
      expect(canon(String.fromCharCode(1)), r'"\u0001"');
    });

    test('`double` нь ХОРИОТОЙ (GDD-05 §0)', () {
      expect(() => canon(1.5), throwsArgumentError);
      expect(() => canon(<Object?>[1, 2.0]), throwsArgumentError);
    });

    test('дэмжигдэхгүй төрөл шиднэ', () {
      expect(() => canon(Object()), throwsArgumentError);
    });

    test('canonHash = sha256Hex(utf8(canon(v)))', () {
      const Map<String, Object?> v = <String, Object?>{'night': 2, 'seed': 'ab'};
      expect(canonHash(v), sha256Hex(utf8.encode(canon(v))));
    });

    test('canonHash нь оруулах дараалалаас ХАМААРАХГҮЙ', () {
      expect(
        canonHash(<String, Object?>{'a': 1, 'b': 2}),
        canonHash(<String, Object?>{'b': 2, 'a': 1}),
      );
    });
  });
}

enum _Suit { hearts, spades }
