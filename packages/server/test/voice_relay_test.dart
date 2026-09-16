// Дуу хаашаа явахыг шалгана — сүлжээгүйгээр.
//
// «Хоёр алуурчин сэрэхэд ЗӨВХӨН тэр хоёр л ярьж болно, бусад нь тэдний
// яриаг ОГТ сонсохгүй» гэдэг нь энэ тоглоомын гол шаардлага. Түүнийг
// хамгаалах хоёр давхарга: энэ тест (шийдвэр зөв үү) ба
// `voice_socket_test.dart` (утас руу ҮНЭХЭЭР хүрэхгүй байна уу).

import 'package:protocol/protocol.dart';
import 'package:server/src/voice_relay.dart';
import 'package:test/test.dart';

void main() {
  const Set<PlayerId> mafia = <PlayerId>{'m1', 'm2'};
  const Set<PlayerId> town = <PlayerId>{'m1', 'm2', 'c1', 'c2', 'c3'};

  test('сувгийн гишүүн бусад гишүүдэд хүрнэ', () {
    expect(VoiceRelay.recipients(from: 'm1', channel: mafia), <PlayerId>['m2']);
  });

  test('өөрөө өөрийгөө сонсохгүй', () {
    expect(VoiceRelay.recipients(from: 'm1', channel: mafia), isNot(contains('m1')));
  });

  test('сувагт байхгүй хүн ярьвал ХЭН Ч сонсохгүй', () {
    // Иргэн шөнө микрофоноо хүчээр нээсэн ч — өөрчилсөн апп — хүрээ
    // хаашаа ч явахгүй.
    expect(VoiceRelay.recipients(from: 'c1', channel: mafia), isEmpty);
  });

  test('иргэд мафийн яриаг СОНСОХГҮЙ', () {
    // Хамгийн чухал шалгуур. Мафийн сувгаас гарах бүх хүрээг цуглуулаад
    // иргэдийн нэр орсон эсэхийг шалгана.
    final Set<PlayerId> reached = <PlayerId>{};
    for (final PlayerId m in mafia) {
      reached.addAll(VoiceRelay.recipients(from: m, channel: mafia));
    }
    for (final PlayerId c in <PlayerId>['c1', 'c2', 'c3']) {
      expect(reached, isNot(contains(c)), reason: '$c мафийг сонсож байна');
    }
    expect(reached, mafia);
  });

  test('өдөр бүгд бие биенээ сонсоно', () {
    final List<PlayerId> got = VoiceRelay.recipients(from: 'c1', channel: town);
    expect(got.toSet(), town.difference(<PlayerId>{'c1'}));
  });

  test('ганцаараа байгаа эмчийн дуу хаашаа ч явахгүй', () {
    expect(VoiceRelay.recipients(from: 'd', channel: <PlayerId>{'d'}), isEmpty);
  });

  test('хоосон суваг — шөнө эхлэх үе', () {
    expect(VoiceRelay.recipients(from: 'm1', channel: const <PlayerId>{}), isEmpty);
  });

  test('үхсэн хүн сувгаас гарсан бол сонсохгүй', () {
    // `voiceMembers` нь зөвхөн АМЬД хүмүүсийг өгдөг (`room.dart`).
    // Энд түүний үр дагаврыг шалгана: жагсаалтад байхгүй бол хүрэхгүй.
    const Set<PlayerId> aliveOnly = <PlayerId>{'m1'};
    expect(VoiceRelay.recipients(from: 'm2', channel: aliveOnly), isEmpty);
    expect(VoiceRelay.recipients(from: 'm1', channel: aliveOnly), isEmpty);
  });
}
