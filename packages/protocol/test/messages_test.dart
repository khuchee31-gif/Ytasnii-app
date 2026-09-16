// Протоколын тест.
//
// Хоёр зүйлийг бэхэлнэ:
//   1. Сүлжээнээс ирсэн ЯМАР Ч байт серверийг унагаахгүй.
//   2. Нийтийн мессежээр дүр ХЭЗЭЭ Ч гарахгүй.
//
// Хоёр дахь нь энэ төслийн хамгийн чухал аюулгүйн шаардлага: онлайн мафид
// урвалт кодоос эхэлдэг.

import 'dart:convert';
import 'dart:math';

import 'package:protocol/protocol.dart';
import 'package:test/test.dart';

void main() {
  group('Envelope', () {
    test('бичээд буцааж уншихад ижил гарна', () {
      const Envelope e = Envelope('hello', <String, Object?>{
        'name': 'Батаа',
        'avatarId': 'punk_03',
        'n': 12,
      });
      final Envelope? back = Envelope.decode(e.encode());
      expect(back, isNotNull);
      expect(back!.type, 'hello');
      expect(back.v, kProtocolVersion);
      expect(back.data['name'], 'Батаа');
      expect(back.data['n'], 12);
    });

    test('кирилл үсэг гэмтэхгүй', () {
      const String s = 'Өнөө шөнө хохирогч гарсангүй. Ү ү Ө ө';
      const Envelope e = Envelope('x', <String, Object?>{'s': s});
      expect(Envelope.decode(e.encode())!.data['s'], s);
    });

    test('гэмтсэн оролт `null` буцаана, УНАХГҮЙ', () {
      final List<String> junk = <String>[
        '',
        '{',
        'null',
        '[]',
        '"just a string"',
        '{"v":1}',
        '{"t":""}',
        '{"t":123}',
        String.fromCharCodes(<int>[0, 1, 2]),
      ];
      for (final String s in junk) {
        expect(Envelope.decode(s), isNull, reason: 'оролт: ${jsonEncode(s)}');
      }
    });

    test('`d` дутуу эсвэл буруу төрөлтэй бол ХООСОН МАП болно, унахгүй', () {
      // ЗОРИУДЫН ШИЙДВЭР: энд татгалзахын оронд тэсвэрлэнэ. Учир нь
      // боловсруулагч нь шаардлагатай талбараа олохгүй тул ямар ч байсан
      // татгалзана — харин холболт нь тасрахгүй үлдэнэ.
      for (final String raw in <String>[
        '{"v":1,"t":"ping"}',
        '{"v":1,"t":"ping","d":"not a map"}',
        '{"v":1,"t":"ping","d":42}',
        '{"v":1,"t":"ping","d":null}',
      ]) {
        final Envelope? e = Envelope.decode(raw);
        expect(e, isNotNull, reason: raw);
        expect(e!.data, isEmpty, reason: raw);
      }
    });

    test('санамсаргүй хог байт серверийг унагаахгүй (fuzz)', () {
      // Тогтмол seed — тест давтагдана.
      final Random r = Random(20260916);
      for (int i = 0; i < 2000; i++) {
        final int len = r.nextInt(64);
        final String s = String.fromCharCodes(
          List<int>.generate(len, (_) => r.nextInt(0x2000)),
        );
        // Унахгүй л бол хангалттай — үр дүн нь `null` ч байж болно.
        Envelope.decode(s);
      }
    });
  });

  group('ДҮР АЛДАГДАХГҮЙ', () {
    test('`PublicPlayer` нь дүртэй холбоотой ЯМАР Ч талбар агуулахгүй', () {
      const PublicPlayer p = PublicPlayer(
        id: 'p1',
        name: 'Сараа',
        avatarId: 'punk_07',
        seat: 3,
      );
      final Map<String, Object?> j = p.toJson();

      // Түлхүүрийн нэрсийг шалгана. Хэн нэгэн `role`, `faction`, `isMafia`
      // гэх мэт талбар нэмвэл ЭНЭ ТЕСТ УНАНА — тэр нь зорилго.
      const List<String> forbidden = <String>[
        'role',
        'faction',
        'mafia',
        'ability',
        'team',
        'card',
        'secret',
      ];
      for (final String key in j.keys) {
        for (final String bad in forbidden) {
          expect(
            key.toLowerCase().contains(bad),
            isFalse,
            reason: 'НИЙТИЙН мессежид «$key» талбар байна — дүр алдагдаж '
                'магадгүй. Хувийн мессеж (`S2C.yourRole`) ашигла.',
          );
        }
      }
    });

    test('`PublicPlayer` бичээд уншихад бүх талбар хадгалагдана', () {
      const PublicPlayer p = PublicPlayer(
        id: 'p9',
        name: 'Дорж',
        avatarId: 'punk_01',
        seat: 7,
        alive: false,
        connected: false,
        ready: true,
        speaking: true,
      );
      final PublicPlayer back = PublicPlayer.fromJson(
        jsonDecode(jsonEncode(p.toJson())) as Map<String, Object?>,
      );
      expect(back.id, p.id);
      expect(back.name, p.name);
      expect(back.avatarId, p.avatarId);
      expect(back.seat, p.seat);
      expect(back.alive, isFalse);
      expect(back.connected, isFalse);
      expect(back.ready, isTrue);
      expect(back.speaking, isTrue);
    });

    test('суудалгүй тоглогчийн JSON-д `seat` түлхүүр огт байхгүй', () {
      const PublicPlayer p = PublicPlayer(id: 'x', name: 'n', avatarId: 'a');
      expect(p.toJson().containsKey('seat'), isFalse);
      expect(PublicPlayer.fromJson(p.toJson()).seat, isNull);
    });
  });

  group('VoiceScope', () {
    test('шөнийн мафийн суваг нь `everyone` БИШ', () {
      // Энэ нь жирийн шалгалт мэт боловч: хэрэв хэн нэгэн `mafiaOnly`-г
      // `everyone` рүү буруу зураглавал бүх анги алуурчдыг сонсоно.
      expect(VoiceScope.mafiaOnly, isNot(VoiceScope.everyone));
      expect(VoiceScope.values.length, 4);
    });
  });
}
