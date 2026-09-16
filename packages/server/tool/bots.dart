// Хиймэл тоглогчид — ЖИНХЭНЭ сервер рүү жинхэнэ сокетээр холбогдоно.
//
// ЯАГААД: Godot дээрх шинэ үйлчлүүлэгчийг шалгахад жинхэнэ тоглолт
// хэрэгтэй. Гар аргаар долоон утас цуглуулах боломжгүй тул ботууд
// ширээг дүүргэж, тоглолтыг эхлүүлнэ. Хүн (Godot) нээлттэй өрөөг
// жагсаалтаас олж орно.
//
// Энэ нь ТЕСТИЙН хэрэгсэл, тоглоомын хэсэг биш. Ботууд серверт ямар ч
// давуу эрхгүй: бусад тоглогчтой яг ижил мессеж илгээнэ, өөрсдийн
// дүрээсээ өөр юу ч мэдэхгүй.
//
//   dart run tool/bots.dart [--count 7] [--wait 20] [--url ws://127.0.0.1:8080]

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:protocol/protocol.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

// ХУВИЛБАРЫГ ЭНД БҮҮ БИЧ. Өмнө нь `const int kProtocolVersion = 1;` гэж
// хуулбарласан байв. Сервер 2 болоход энэ хэрэгсэл чимээгүй хоцорч,
// бүх бот `badVersion` авдаг болсон — `tools/play.sh` бүхэлдээ ажиллахаа
// больсон ч тестүүд ногоон хэвээр байв (тэд протоколыг ЗӨВ импортолдог).


class Bot {
  Bot(this.index, this.url, this.rng);

  final int index;
  final String url;
  final Random rng;

  late final WebSocketChannel ch;
  // `bot-` УГТВАР БАЙЖ БОЛОХГҮЙ: сервер тэр угтвартай дугаарыг
  // сокетоор хүлээж авахаа больсон (жинхэнэ ботын дүрийг хулгайлахаас
  // сэргийлнэ). Эдгээр нь ХҮНИЙГ дүрдэг хэрэгслүүд, өрөөний ботууд биш.
  final String id = 'sim-${DateTime.now().microsecondsSinceEpoch}-${_n++}';
  static int _n = 0;

  String name = '';
  String role = '';
  int seat = -1;
  bool alive = true;
  String phase = 'lobby';
  List<int> aliveSeats = <int>[];

  void _send(String type, Map<String, Object?> data) {
    ch.sink.add(jsonEncode(<String, Object?>{
      'v': kProtocolVersion,
      't': type,
      'd': data,
    }));
  }

  Future<void> connect(void Function(Bot, String, Map<String, Object?>) onMsg) async {
    name = 'Бот-${index + 1}';
    ch = WebSocketChannel.connect(Uri.parse(url));
    await ch.ready;
    ch.stream.listen((Object? raw) {
      final Object? j = jsonDecode(raw as String);
      if (j is! Map) return;
      final String t = (j['t'] ?? '') as String;
      final Map<String, Object?> d =
          (j['d'] is Map) ? Map<String, Object?>.from(j['d'] as Map) : <String, Object?>{};
      _handle(t, d);
      onMsg(this, t, d);
    }, onError: (Object e) => print('bot$index error $e'));
    _send('hello',
        <String, Object?>{'playerId': id, 'token': 'tok-$id-0123456789', 'name': name});
  }

  void _handle(String t, Map<String, Object?> d) {
    switch (t) {
      case 'yourRole':
        role = (d['role'] ?? '') as String;
        seat = (d['seat'] ?? -1) as int;
      case 'roomState':
        final List<Object?> ps = (d['players'] as List<Object?>? ?? <Object?>[]);
        aliveSeats = ps
            .whereType<Map<Object?, Object?>>()
            .where((Map<Object?, Object?> p) => p['alive'] == true && p['seat'] != null)
            .map((Map<Object?, Object?> p) => p['seat']! as int)
            .toList();
        for (final Object? p in ps) {
          if (p is Map && p['id'] == id) alive = p['alive'] == true;
        }
      case 'phase':
        phase = (d['phase'] ?? '') as String;
        _act();
    }
  }

  /// Дүрдээ тохирсон үед л үйлдэнэ. Санамсаргүй сонгоно — ботууд ухаантай
  /// байх шаардлагагүй, зөвхөн тоглолтыг урагшлуулна.
  void _act() {
    if (!alive || seat < 0) return;
    final List<int> others =
        aliveSeats.where((int s) => s != seat).toList(growable: false);
    if (others.isEmpty) return;
    final int pick = others[rng.nextInt(others.length)];
    final bool mine = switch (phase) {
      'nightMafia' => role == 'killer' || role == 'boss',
      'nightDoctor' => role == 'doctor',
      'nightDetective' => role == 'detective',
      _ => false,
    };
    if (mine) {
      Timer(Duration(milliseconds: 400 + rng.nextInt(900)),
          () => _send('nightAction', <String, Object?>{'targetSeat': pick}));
    } else if (phase == 'vote') {
      Timer(Duration(milliseconds: 600 + rng.nextInt(1800)),
          () => _send('vote', <String, Object?>{'targetSeat': pick}));
    }
  }

  /// Төрх — зөвхөн гоо сайхан, дүртэй ямар ч холбоогүй.
  ///
  /// Хиймэл тоглогчид ч өөр өөр харагдах ёстой: бүгд ижил байвал
  /// ширээн дээрх төрхийн систем ажиллаж байгаа эсэхийг шалгах
  /// боломжгүй.
  String get _look {
    const List<String> keys = <String>[
      'punk', 'hoodie', 'worker', 'casual', 'suit', 'swat',
    ];
    return '${keys[index % keys.length]}/${(index * 3) % 6}';
  }

  void createRoom() => _send('createRoom', <String, Object?>{
        'name': name,
        'isPublic': true,
        'avatarId': _look,
      });
  void joinRoom(String code) => _send('joinRoom',
      <String, Object?>{'code': code, 'name': name, 'avatarId': _look});
  void ready() => _send('setReady', <String, Object?>{'ready': true});
  void start() => _send('startGame', const <String, Object?>{});
  void close() => ch.sink.close();
}

Future<void> main(List<String> args) async {
  String url = 'ws://127.0.0.1:8080';
  int count = 7;
  int waitSec = 20;
  for (int i = 0; i < args.length - 1; i++) {
    if (args[i] == '--url') url = args[i + 1];
    if (args[i] == '--count') count = int.tryParse(args[i + 1]) ?? count;
    if (args[i] == '--wait') waitSec = int.tryParse(args[i + 1]) ?? waitSec;
  }

  final Random rng = Random(7);
  final List<Bot> bots = <Bot>[];
  String? code;
  final Completer<String> gotCode = Completer<String>();

  void onMsg(Bot b, String t, Map<String, Object?> d) {
    if (t == 'roomState' && !gotCode.isCompleted) {
      final String c = (d['code'] ?? '') as String;
      if (c.isNotEmpty) gotCode.complete(c);
    }
    if (t == 'error') print('bot${b.index} ERROR ${d['code']}');
    if (b.index == 0 && t == 'phase') print('PHASE ${d['phase']}');
    if (b.index == 0 && t == 'nightResult') print('NIGHT ${jsonEncode(d)}');
    if (b.index == 0 && t == 'gameOver') print('OVER ${d['winner']}');
  }

  for (int i = 0; i < count; i++) {
    final Bot b = Bot(i, url, rng);
    bots.add(b);
    await b.connect(onMsg);
    if (i == 0) {
      b.createRoom();
      code = await gotCode.future;
      print('ROOM $code');
    } else {
      b.joinRoom(code!);
    }
    await Future<void>.delayed(const Duration(milliseconds: 120));
  }
  for (final Bot b in bots) {
    b.ready();
  }

  print('WAITING ${waitSec}s — хүн орох зай');
  await Future<void>.delayed(Duration(seconds: waitSec));
  print('START');
  bots.first.start();

  await Future<void>.delayed(const Duration(seconds: 150));
  for (final Bot b in bots) {
    b.close();
  }
}
