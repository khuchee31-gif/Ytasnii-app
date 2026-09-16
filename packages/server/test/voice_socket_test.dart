// Дуу ҮНЭХЭЭР хаашаа хүрч байна вэ — жинхэнэ сервер, жинхэнэ сокет.
//
// `voice_relay_test.dart` нь ШИЙДВЭР зөв эсэхийг шалгана. Энэ файл өөр
// зүйл шалгана: тэр шийдвэр утас руу зөв хэрэгжиж байна уу.
//
// Логикийн тест бүх зүйлийг барихгүй: `VoiceRelay` төгс байсан ч
// `bin/server.dart` доторх дамжуулалт буруу бичигдвэл иргэн мафийн
// яриаг сонсоно. Тиймээс энд БАЙТ тоолно.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:protocol/protocol.dart';
import 'package:test/test.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Тестийн НУУЦ түлхүүр.
///
/// Жинхэнэ апп санамсаргүй 16 байт үүсгэдэг. Тестэд дугаараас нь
/// гаргах нь хангалттай: чухал нь ӨӨР дугаар ӨӨР түлхүүртэй байх, мөн
/// нэг дугаар дахин холбогдоход ИЖИЛ түлхүүр өгөх хоёр.
String _token(String id) => 'token-for-$id-0123456789';


class _Client {
  _Client(this.id, this.channel);

  final String id;
  final WebSocketChannel channel;
  final List<Envelope> inbox = <Envelope>[];

  /// Энэ утас руу ирсэн ДУУНЫ хүрээнүүд.
  final List<VoiceFrame> heard = <VoiceFrame>[];

  String role = '';
  int seat = -1;

  void send(String type, [Map<String, Object?> d = const <String, Object?>{}]) =>
      channel.sink.add(Envelope(type, d).encode());

  /// Танигдахуйц дуу: бүх дээж нь илгээгчийн тэмдэг.
  void speak(int mark, int seq) {
    final Uint8List audio = Uint8List(kVoiceSamples)..fillRange(0, kVoiceSamples, mark);
    channel.sink.add(VoiceFrame(seq: seq, audio: audio).encodeUp());
  }

  Future<void> close() => channel.sink.close();
}

void main() {
  late Process proc;
  const int port = 8793;
  final List<_Client> cs = <_Client>[];

  setUpAll(() async {
    proc = await Process.start(
      Platform.resolvedExecutable,
      <String>['run', 'bin/server.dart', '--port', '$port'],
      workingDirectory: Directory.current.path,
    );
    final Completer<void> ready = Completer<void>();
    proc.stdout.transform(utf8.decoder).listen((String l) {
      if (l.contains('ws://') && !ready.isCompleted) ready.complete();
    });
    await ready.future.timeout(const Duration(seconds: 60));
  });

  tearDownAll(() async {
    for (final _Client c in cs) {
      await c.close();
    }
    proc.kill();
  });

  Future<_Client> connect(String id) async {
    final WebSocketChannel ch =
        WebSocketChannel.connect(Uri.parse('ws://127.0.0.1:$port'));
    await ch.ready;
    final _Client c = _Client(id, ch);
    ch.stream.listen((Object? raw) {
      if (raw is String) {
        final Envelope? e = Envelope.decode(raw);
        if (e == null) return;
        c.inbox.add(e);
        if (e.type == S2C.yourRole) {
          c.role = (e.data['role'] ?? '') as String;
          c.seat = (e.data['seat'] ?? -1) as int;
        }
      } else if (raw is List<int>) {
        final VoiceFrame? f = VoiceFrame.decodeDown(raw);
        if (f != null) c.heard.add(f);
      }
    });
    c.send(C2S.hello, <String, Object?>{'playerId': id, 'token': _token(id)});
    return c;
  }

  Future<void> settle([int ms = 300]) =>
      Future<void>.delayed(Duration(milliseconds: ms));

  /// Тухайн үе шат эхлэх хүртэл хүлээнэ.
  Future<void> waitPhase(_Client c, String phase, {int seconds = 40}) async {
    final DateTime until = DateTime.now().add(Duration(seconds: seconds));
    while (DateTime.now().isBefore(until)) {
      final bool got = c.inbox.any((Envelope e) =>
          e.type == S2C.phase && e.data['phase'] == phase);
      if (got) return;
      await settle(200);
    }
    fail('«$phase» үе шат эхэлсэнгүй');
  }

  test('шөнө мафийн дууг ЗӨВХӨН мафи сонсоно', () async {
    for (int i = 1; i <= 8; i++) {
      cs.add(await connect('v$i'));
    }
    await settle();

    cs.first.send(C2S.createRoom, <String, Object?>{'name': 'Хост'});
    await settle();
    final String code = cs.first
        .inbox
        .lastWhere((Envelope e) => e.type == S2C.roomState)
        .data['code']! as String;
    for (int i = 1; i < cs.length; i++) {
      cs[i].send(C2S.joinRoom, <String, Object?>{'code': code, 'name': 'Т$i'});
      await settle(100);
    }
    await settle();

    cs.first.send(C2S.startGame);
    await waitPhase(cs.first, 'nightMafia');
    await settle(400);

    // Дүрийг тест мэдэж байна — найман сокетыг бүгдийг нь барьж байгаа
    // тул. Жинхэнэ тоглогч хэзээ ч ингэж мэдэхгүй.
    final List<_Client> mafia = cs
        .where((_Client c) => c.role == 'killer' || c.role == 'boss')
        .toList();
    final List<_Client> town = cs
        .where((_Client c) => !(c.role == 'killer' || c.role == 'boss'))
        .toList();
    expect(mafia.length, greaterThanOrEqualTo(2), reason: 'мафи хэд байх ёстой');
    expect(town, isNotEmpty);

    // БҮГД ярихыг оролдоно — иргэд ч гэсэн. Өөрчилсөн апп яг ингэнэ.
    for (int i = 0; i < cs.length; i++) {
      for (int f = 0; f < 5; f++) {
        cs[i].speak(i + 1, f);
      }
      await settle(40);
    }
    await settle(700);

    // --- ГОЛ ШАЛГУУР ------------------------------------------------------
    for (final _Client c in town) {
      expect(c.heard, isEmpty,
          reason: 'иргэн ${c.id} (${c.role}) ${c.heard.length} дууны хүрээ '
              'сонсчээ — мафийн ярианд нэвтэрсэн байна');
    }

    final Set<int> mafiaMarks =
        mafia.map((_Client c) => cs.indexOf(c) + 1).toSet();
    for (final _Client c in mafia) {
      expect(c.heard, isNotEmpty, reason: 'мафи ${c.id} хамтрагчаа сонсоогүй');
      final int me = cs.indexOf(c) + 1;
      for (final VoiceFrame f in c.heard) {
        final int mark = f.audio.first;
        expect(mafiaMarks, contains(mark),
            reason: 'мафи ${c.id} иргэний дууг ($mark) сонсчээ');
        expect(mark, isNot(me), reason: 'өөрийн дуу цуурай болж буцжээ');
        expect(f.seat, greaterThan(0), reason: 'суудал дамжаагүй');
      }
    }

    // Хүрээ бүр бүтэн ирсэн үү — дуу тасархай болох нь хамгийн түгээмэл
    // эвдрэл.
    for (final _Client c in mafia) {
      for (final VoiceFrame f in c.heard) {
        expect(f.audio.length, kVoiceSamples);
      }
    }
  }, timeout: const Timeout(Duration(seconds: 120)));
}
