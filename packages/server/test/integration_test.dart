// Бүтэн холболтын тест — ЖИНХЭНЭ сервер, ЖИНХЭНЭ сокет.
//
// `room_test.dart` нь логикийг сүлжээгүйгээр шалгадаг. Энэ файл өөр зүйл
// шалгана: сервер ҮНЭХЭЭР ажиллаж, найман утас холбогдож, дүр нь ЗӨВ
// ХҮНД, ЗӨВХӨН ТЭР ХҮНД хүрэх эсэх.
//
// Энэ бол «хаяглалт зөв бичигдсэн» гэдгийн цорын ганц бодит нотолгоо:
// `Outbound` төрөл зөв байсан ч `_dispatch` буруу бичигдсэн бол логикийн
// тест үүнийг барихгүй.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:protocol/protocol.dart';
import 'package:test/test.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Нэг хуурамч утас.
class _Client {
  _Client(this.id, this.channel);

  final String id;
  final WebSocketChannel channel;

  /// Энэ утас руу ирсэн БҮХ мессеж.
  final List<Envelope> inbox = <Envelope>[];

  void send(String type, [Map<String, Object?> data = const <String, Object?>{}]) {
    channel.sink.add(Envelope(type, data).encode());
  }

  List<Envelope> ofType(String t) =>
      inbox.where((Envelope e) => e.type == t).toList();

  Future<void> close() => channel.sink.close();
}

void main() {
  late Process proc;
  late int port;

  setUpAll(() async {
    port = 8791;
    proc = await Process.start(
      Platform.resolvedExecutable,
      <String>['run', 'bin/server.dart', '--port', '$port'],
      workingDirectory: Directory.current.path,
    );
    // Сервер «бэлэн» гэж бичих хүртэл хүлээнэ.
    final Completer<void> ready = Completer<void>();
    proc.stdout.transform(utf8.decoder).listen((String line) {
      if (line.contains('ws://') && !ready.isCompleted) ready.complete();
    });
    proc.stderr.transform(utf8.decoder).listen((String e) {
      if (!ready.isCompleted) ready.completeError(StateError('сервер: $e'));
    });
    await ready.future.timeout(const Duration(seconds: 60));
  });

  tearDownAll(() => proc.kill());

  Future<_Client> connect(String id) async {
    final WebSocketChannel ch =
        WebSocketChannel.connect(Uri.parse('ws://127.0.0.1:$port'));
    await ch.ready;
    final _Client c = _Client(id, ch);
    ch.stream.listen((Object? raw) {
      if (raw is String) {
        final Envelope? e = Envelope.decode(raw);
        if (e != null) c.inbox.add(e);
      }
    });
    c.send(C2S.hello, <String, Object?>{'playerId': id});
    return c;
  }

  /// Мессеж ирэх хүртэл богино хүлээлт. Сүлжээ асинхрон тул шаардлагатай.
  Future<void> settle([int ms = 350]) =>
      Future<void>.delayed(Duration(milliseconds: ms));

  test('найман утас холбогдож, дүр нь ЗӨВХӨН эзэндээ хүрнэ', () async {
    final List<_Client> cs = <_Client>[];
    for (int i = 1; i <= 8; i++) {
      cs.add(await connect('u$i'));
    }
    await settle();

    // Эхнийх нь өрөө үүсгэнэ.
    cs.first.send(C2S.createRoom,
        <String, Object?>{'name': 'Хост', 'avatarId': 'punk_01'});
    await settle();

    final List<Envelope> states = cs.first.ofType(S2C.roomState);
    expect(states, isNotEmpty, reason: 'өрөө үүсээгүй');
    final String code = states.last.data['code']! as String;
    expect(code.length, 4);

    // Бусад нь кодоор орно.
    for (int i = 1; i < cs.length; i++) {
      cs[i].send(C2S.joinRoom, <String, Object?>{
        'code': code,
        'name': 'Тоглогч$i',
        'avatarId': 'punk_0$i',
      });
      await settle(120);
    }
    await settle();

    // Бүгд найман хүнтэй өрөө харж байна.
    for (final _Client c in cs) {
      final List<Envelope> s = c.ofType(S2C.roomState);
      expect(s, isNotEmpty, reason: '${c.id} өрөөний төлөв аваагүй');
      final List<Object?> ps = s.last.data['players']! as List<Object?>;
      expect(ps.length, 8, reason: '${c.id} найман тоглогч харах ёстой');
    }

    // Тоглолт эхэлнэ.
    cs.first.send(C2S.startGame);
    await settle(700);

    // --- ГОЛ ШАЛГУУР ------------------------------------------------------
    for (final _Client c in cs) {
      final List<Envelope> mine = c.ofType(S2C.yourRole);
      expect(mine.length, 1,
          reason: '${c.id} яг НЭГ дүрийн мессеж авах ёстой, '
              '${mine.length} авчээ');
      expect(mine.single.data['role'], isA<String>());
      expect(mine.single.data['seat'], isA<int>());
    }

    // Нийтийн мессежид дүр байхгүй.
    for (final _Client c in cs) {
      for (final Envelope e in c.inbox) {
        if (e.type == S2C.yourRole ||
            e.type == S2C.gameOver ||
            e.type == S2C.investigateResult) {
          continue;
        }
        final String raw = e.encode();
        for (final String w in <String>[
          'killer',
          'doctor',
          'detective',
          'citizen',
          'boss',
        ]) {
          expect(raw.contains(w), isFalse,
              reason: '${c.id} «${e.type}» мессежээс «$w» олдлоо');
        }
      }
    }

    // Найман суудал бүгд өөр — хоёр хүнд ижил суудал өгөгдөөгүй.
    final Set<Object?> seats = cs
        .map((_Client c) => c.ofType(S2C.yourRole).single.data['seat'])
        .toSet();
    expect(seats.length, 8, reason: 'суудал давхардлаа');

    for (final _Client c in cs) {
      await c.close();
    }
  }, timeout: const Timeout(Duration(seconds: 90)));

  test('буруу кодоор орох гэвэл алдаа, сервер унахгүй', () async {
    final _Client c = await connect('bad1');
    await settle();
    c.send(C2S.joinRoom, <String, Object?>{'code': 'ZZZZ', 'name': 'Хэн нэгэн'});
    await settle();
    expect(c.ofType(S2C.error).last.data['code'], ErrCode.roomNotFound);

    // Сервер амьд хэвээр.
    c.send(C2S.ping);
    await settle();
    expect(c.ofType(S2C.pong), isNotEmpty);
    await c.close();
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('хог өгөгдөл серверийг унагаахгүй', () async {
    final _Client c = await connect('junk1');
    await settle();
    for (final String junk in <String>[
      'not json',
      '{"t":',
      '[]',
      '{"v":999,"t":"hello","d":{}}',
    ]) {
      c.channel.sink.add(junk);
    }
    await settle();
    c.send(C2S.ping);
    await settle();
    expect(c.ofType(S2C.pong), isNotEmpty, reason: 'сервер унасан байна');
    await c.close();
  }, timeout: const Timeout(Duration(seconds: 60)));
}
