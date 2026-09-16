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

/// Тестийн НУУЦ түлхүүр.
///
/// Жинхэнэ апп санамсаргүй 16 байт үүсгэдэг. Тестэд дугаараас нь
/// гаргах нь хангалттай: чухал нь ӨӨР дугаар ӨӨР түлхүүртэй байх, мөн
/// нэг дугаар дахин холбогдоход ИЖИЛ түлхүүр өгөх хоёр.
String _token(String id) => 'token-for-$id-0123456789';


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
    c.send(C2S.hello, <String, Object?>{'playerId': id, 'token': _token(id)});
    return c;
  }

  /// `hello`-г ӨӨРӨӨ бичих холболт. Түлхүүрийн шалгалтыг шалгахад
  /// хэрэгтэй — `connect` нь үргэлж зөв түлхүүр илгээдэг.
  Future<_Client> connectRaw(String id, Map<String, Object?> hello) async {
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
    c.send(C2S.hello, hello);
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

  test('бот гэж өөрийгөө зарлаж чадахгүй', () async {
    // Хүн өөрийгөө бот гэж зарлаж чаддаг байсан бол өдрийн яриан дээр
    // «энэ бол бот» гэж тоомсоргүй орхигдох — жинхэнэ мафийн заль.
    final _Client a = await connect('cheat1');
    await settle();
    a.send(C2S.createRoom, <String, Object?>{'name': 'Заль', 'isBot': true});
    await settle();

    final List<Object?> ps =
        a.ofType(S2C.roomState).last.data['players']! as List<Object?>;
    final Map<Object?, Object?> me = ps.first as Map<Object?, Object?>;
    expect(me['isBot'], isFalse);
    await a.close();
  });

  test('буруу ТӨРӨЛТЭЙ талбар серверийг унагаахгүй', () async {
    // Хэлбэр нь зөв атлаа доторх утга нь буруу төрөлтэй мессеж.
    // `e.data['x'] as int?` нь 1.5 дээр `TypeError` шиддэг бөгөөд тэр нь
    // сокетын дотор, барихгүй асинхрон алдаа болж БҮХ өрөөтэй хамт
    // серверийг унагана.
    final _Client a = await connect('junk2');
    await settle();
    a.send(C2S.createRoom, <String, Object?>{'name': 'Хог'});
    await settle();

    for (final Map<String, Object?> bad in <Map<String, Object?>>[
      <String, Object?>{'t': C2S.vote, 'd': <String, Object?>{'targetSeat': 1.5}},
      <String, Object?>{'t': C2S.addBots, 'd': <String, Object?>{'count': 'x'}},
      <String, Object?>{'t': C2S.addBots, 'd': <String, Object?>{'count': 1.5}},
      <String, Object?>{'t': C2S.nightAction, 'd': <String, Object?>{'targetSeat': <int>[1]}},
    ]) {
      a.channel.sink.add(jsonEncode(<String, Object?>{
        'v': kProtocolVersion, 't': bad['t'], 'd': bad['d'],
      }));
      await settle(80);
    }

    // Сервер амьд байх ёстой.
    a.send(C2S.ping);
    await settle();
    expect(a.ofType(S2C.pong), isNotEmpty, reason: 'сервер унасан байна');
    await a.close();
  });

  test('татгалзсан нэрийн дараа өрөөнд ОРООГҮЙ байна', () async {
    // Хоосон нэр одоо алдаа тул `createRoom` бүтэлгүйтэж болно. Тэр үед
    // холболтыг өрөөнд хавсаргавал хүн ороогүй атлаа `setReady` нь тэр
    // өрөө рүү очно.
    final _Client a = await connect('noname3');
    await settle();
    a.send(C2S.createRoom, <String, Object?>{'name': '   '});
    await settle();
    expect(a.ofType(S2C.error).last.data['code'], ErrCode.nameRequired);

    a.send(C2S.setReady, <String, Object?>{'ready': true});
    await settle();
    expect(a.ofType(S2C.roomState), isEmpty,
        reason: 'ороогүй атлаа өрөөний төлөв авчээ');
    await a.close();
  });

  // --- Дүр хулгайлах оролдлогууд ---------------------------------------------
  //
  // ЭНЭ БҮЛЭГ ХАМГИЙН ЧУХАЛ. Гүнзгий шалгалтаар олсон бодит халдлага:
  // `roomState` нь тоглогч бүрийн `id`-г нийтэд цацдаг. Өмнө нь тэр
  // дугаарыг хуулж `hello` + `joinRoom` илгээхэд сервер «дахин
  // холбогдов» гэж үзээд ТҮҮНИЙ `yourRole`-ыг буцаадаг байв. Ботод
  // сокет байхгүй тул хохирогч юу ч анзаарахгүй: найман суудлын бүх
  // дүрийг чимээгүйхэн цуглуулж болно.

  test('түлхүүргүй `hello` татгалзагдана', () async {
    final _Client a = await connectRaw('notoken1',
        <String, Object?>{'playerId': 'notoken1'});
    await settle();
    expect(a.ofType(S2C.error).last.data['code'], ErrCode.badToken);
    // Дугаар нь холбогдоогүй тул цаашид юу ч хийж чадахгүй.
    a.send(C2S.createRoom, <String, Object?>{'name': 'Хулгайч'});
    await settle();
    expect(a.ofType(S2C.roomState), isEmpty);
    await a.close();
  });

  test('хэт богино түлхүүр татгалзагдана', () async {
    final _Client a = await connectRaw('shorttok',
        <String, Object?>{'playerId': 'shorttok', 'token': 'abc'});
    await settle();
    expect(a.ofType(S2C.error).last.data['code'], ErrCode.badToken);
    await a.close();
  });

  test('өөр түлхүүрээр бусдын дугаарыг нэхэж чадахгүй', () async {
    final _Client real = await connect('victim1');
    await settle();
    final _Client thief = await connectRaw('victim1',
        <String, Object?>{'playerId': 'victim1', 'token': 'WRONG-0123456789'});
    await settle();
    expect(thief.ofType(S2C.error).last.data['code'], ErrCode.badToken);
    // ХОХИРОГЧ ТАСРАХГҮЙ. Эс бөгөөс хэн ч хэнийг ч гаргаж чадна.
    real.send(C2S.ping);
    await settle();
    expect(real.ofType(S2C.pong), isNotEmpty,
        reason: 'хулгайч хохирогчийг таслав');
    await thief.close();
    await real.close();
  });

  test('БОТЫН дугаарыг нэхэхэд дүр гарахгүй', () async {
    final _Client host = await connect('bh1');
    await settle();
    host.send(C2S.createRoom, <String, Object?>{'name': 'Эзэн'});
    await settle();
    final String code =
        host.ofType(S2C.roomState).last.data['code']! as String;
    host.send(C2S.addBots, <String, Object?>{'count': 7});
    await settle();
    host.send(C2S.startGame);
    await settle(700);

    // Ботын дугаарыг НИЙТИЙН мессежээс шууд хуулна.
    final List<Object?> players =
        host.ofType(S2C.roomState).last.data['players']! as List<Object?>;
    final List<String> botIds = players
        .cast<Map<String, Object?>>()
        .where((Map<String, Object?> p) => p['isBot'] == true)
        .map((Map<String, Object?> p) => p['id']! as String)
        .toList();
    expect(botIds.length, 7, reason: 'ботын дугаар нийтэд харагдсаар байна');

    for (final String id in botIds.take(3)) {
      final _Client thief = await connectRaw(id,
          <String, Object?>{'playerId': id, 'token': 'ANY-TOKEN-0123456789'});
      await settle(120);
      thief.send(C2S.joinRoom,
          <String, Object?>{'code': code, 'name': 'Хулгайч', 'avatarId': 'x'});
      await settle(120);
      expect(thief.ofType(S2C.yourRole), isEmpty,
          reason: '$id-ийн дүр хулгайлагдлаа');
      expect(thief.ofType(S2C.error).first.data['code'], ErrCode.badToken);
      await thief.close();
    }

    // Тоглолт эвдрээгүй.
    host.send(C2S.ping);
    await settle();
    expect(host.ofType(S2C.pong), isNotEmpty);
    await host.close();
  });

  test('ХҮНИЙ дугаарыг нэхэхэд ч дүр гарахгүй', () async {
    final _Client host = await connect('hh1');
    final _Client mate = await connect('hh2');
    await settle();
    host.send(C2S.createRoom, <String, Object?>{'name': 'Эзэн'});
    await settle();
    final String code =
        host.ofType(S2C.roomState).last.data['code']! as String;
    mate.send(C2S.joinRoom,
        <String, Object?>{'code': code, 'name': 'Хоёр', 'avatarId': 'x'});
    await settle();

    final _Client thief = await connectRaw('hh2',
        <String, Object?>{'playerId': 'hh2', 'token': 'STOLEN-0123456789'});
    await settle(120);
    thief.send(C2S.joinRoom,
        <String, Object?>{'code': code, 'name': 'Хулгайч', 'avatarId': 'x'});
    await settle(150);
    expect(thief.ofType(S2C.yourRole), isEmpty);
    expect(thief.ofType(S2C.roomState), isEmpty);
    await thief.close();
    await mate.close();
    await host.close();
  });

  test('НЭГ утас дахин холбогдоход суудалдаа ЭРГЭЖ ОРНО', () async {
    // Түлхүүр нь хулгайг зогсоох ёстой, ЖИНХЭНЭ дахин холболтыг биш.
    final _Client host = await connect('rj1');
    await settle();
    host.send(C2S.createRoom, <String, Object?>{'name': 'Эзэн'});
    await settle();
    final String code =
        host.ofType(S2C.roomState).last.data['code']! as String;
    await host.close();
    await settle(200);

    final _Client again = await connect('rj1');
    await settle(150);
    again.send(C2S.joinRoom,
        <String, Object?>{'code': code, 'name': 'Эзэн', 'avatarId': 'x'});
    await settle(200);
    expect(again.ofType(S2C.roomState), isNotEmpty,
        reason: 'жинхэнэ эзэн эргэж орж чадсангүй');
    await again.close();
  });

  test('нэрийн оронд тоо явуулахад ӨРӨӨ ЭЗЭНГҮЙ ҮЛДЭХГҮЙ', () async {
    // `createRoom` нь эхлээд өрөө үүсгэдэг. Нэрийн хөрвүүлэлт шидэгдвэл
    // `r.has(id)` шалгалт хүртэл хүрэхгүй тул өрөө бүртгэлд үлдэнэ.
    // Зургаан сокетоор давтвал сервер дахин өрөө үүсгэхээ болино.
    final _Client a = await connect('badname1');
    await settle();
    for (int i = 0; i < 4; i++) {
      a.channel.sink.add(jsonEncode(<String, Object?>{
        'v': kProtocolVersion,
        't': C2S.createRoom,
        'd': <String, Object?>{'name': 12345, 'avatarId': 'punk_01'},
      }));
      await settle(100);
    }
    // Сервер амьд, өрөө үүсгэх боломжтой хэвээр.
    a.send(C2S.createRoom, <String, Object?>{'name': 'Зөв'});
    await settle();
    expect(a.ofType(S2C.roomState), isNotEmpty,
        reason: 'өрөө үүсгэх боломжгүй болжээ');
    await a.close();
  });
}
