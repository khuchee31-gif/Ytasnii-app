// Дууны кодлогч ба хүрээний тест.
//
// Кодлогчийг ХОЁР ХЭЛ дээр бичсэн: энд Dart (сервер), `game/scripts/
// voice.gd` дотор GDScript (апп). Хоёулаа G.711 μ-law стандартыг
// дагана. Хэрэв нэг нь өөр бол дуу нь шуугиан болж сонсогдоно — тиймээс
// энэ тест нь стандартын ТОДОРХОЙ утгуудыг шалгана, зөвхөн өөртэйгөө
// таарч байгааг биш.

import 'dart:typed_data';

import 'package:protocol/protocol.dart';
import 'package:test/test.dart';

void main() {
  group('μ-law', () {
    test('0x7F-ээс бусад байт бүр эргээд өөрөө болно', () {
      // 0x7F бол G.711-ийн «сөрөг тэг»: 0xFF ба 0x7F хоёулаа 0 дохио
      // илэрхийлдэг. Тиймээс 0x7F эргэж өөрөө болохгүй — энэ нь алдаа
      // биш, стандартын шинж. (Энэ тестийг бичих үед яг үүн дээр
      // унасан: хүлээсэн 127, гарсан 255.)
      for (int u = 0; u < 256; u++) {
        if (u == 0x7F) continue;
        final int pcm = MuLaw.decode(u);
        expect(MuLaw.encode(pcm), u, reason: 'μ-law $u');
      }
    });

    test('чимээгүйн хоёр дүрслэл хоёулаа тэг болно', () {
      // Кодлогч ҮРГЭЛЖ 0xFF гаргана; хүлээж авахдаа хоёуланг нь ойлгоно.
      // GDScript тал ч яг ийм байх ёстой — эс бөгөөс чимээгүй хэсэгт
      // хоёр апп өөр өөр байт илгээж, шуугиан гарна.
      expect(MuLaw.encode(0), 0xFF);
      expect(MuLaw.decode(0xFF), 0);
      expect(MuLaw.decode(0x7F), 0);
    });

    test('тэмдэг хадгалагдана', () {
      for (final int v in <int>[100, 1000, 8000, 20000, 32000]) {
        expect(MuLaw.decode(MuLaw.encode(v)) > 0, isTrue, reason: '+$v');
        expect(MuLaw.decode(MuLaw.encode(-v)) < 0, isTrue, reason: '-$v');
      }
    });

    test('алдаа нь дохионы хэмжээтэй пропорциональ', () {
      // μ-law бол логарифм: чимээгүй хэсэгт нарийн, чанга хэсэгт бүдүүн.
      // Харьцангуй алдаа хаана ч 8 %-иас хэтрэхгүй байх ёстой.
      for (int v = 256; v < 32000; v += 137) {
        final int back = MuLaw.decode(MuLaw.encode(v));
        expect((back - v).abs() / v, lessThan(0.08), reason: 'v=$v back=$back');
      }
    });

    test('хязгаараас хальсан утга тасрахгүй', () {
      expect(() => MuLaw.encode(40000), returnsNormally);
      expect(() => MuLaw.encode(-40000), returnsNormally);
      expect(MuLaw.decode(MuLaw.encode(40000)) > 30000, isTrue);
    });

    test('бүхэл хүрээ хөрвүүлнэ', () {
      final Int16List pcm = Int16List.fromList(
          List<int>.generate(kVoiceSamples, (int i) => (i * 211) % 20000 - 10000));
      final Uint8List law = MuLaw.encodeAll(pcm);
      expect(law.length, kVoiceSamples);
      final Int16List back = MuLaw.decodeAll(law);
      expect(back.length, kVoiceSamples);
      for (int i = 0; i < pcm.length; i++) {
        expect((back[i] - pcm[i]).abs(), lessThan(1100), reason: 'дээж $i');
      }
    });
  });

  group('VoiceFrame', () {
    final Uint8List audio =
        Uint8List.fromList(List<int>.generate(kVoiceSamples, (int i) => i & 0xFF));

    test('апп → сервер эргэж задарна', () {
      final VoiceFrame? got =
          VoiceFrame.decodeUp(VoiceFrame(seq: 9999, audio: audio).encodeUp());
      expect(got, isNotNull);
      expect(got!.seq, 9999);
      expect(got.audio, audio);
    });

    test('сервер → апп суудлыг авч явна', () {
      final VoiceFrame? got = VoiceFrame.decodeDown(
          VoiceFrame(seq: 7, seat: 5, audio: audio).encodeDown());
      expect(got, isNotNull);
      expect(got!.seat, 5);
      expect(got.seq, 7);
      expect(got.audio, audio);
    });

    test('дараалал 16 битэд эргэнэ', () {
      // 65535-аас хойш 0 болно. Апп үүнийг мэдэж байх ёстой.
      final VoiceFrame? got =
          VoiceFrame.decodeUp(VoiceFrame(seq: 65535, audio: audio).encodeUp());
      expect(got!.seq, 65535);
    });

    test('гажсан байт серверийг унагаахгүй', () {
      expect(VoiceFrame.decodeUp(<int>[]), isNull);
      expect(VoiceFrame.decodeUp(<int>[0x01]), isNull);
      expect(VoiceFrame.decodeUp(<int>[0x99, 1, 2, 3, 4]), isNull, reason: 'буруу шошго');
      expect(VoiceFrame.decodeDown(<int>[0x01, 1, 2]), isNull);
    });

    test('хэт урт хүрээг татгалзана', () {
      // Санах ой дүүргэх оролдлогоос хамгаална.
      final List<int> huge = <int>[kVoiceTag, 0, 0, ...List<int>.filled(kVoiceSamples * 8, 7)];
      expect(VoiceFrame.decodeUp(huge), isNull);
    });
  });
}
