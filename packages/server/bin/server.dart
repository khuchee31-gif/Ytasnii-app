// Сүлжээний давхарга — ЗӨВХӨН энд `dart:io` байна.
//
// Тоглоомын логик бүхэлдээ `lib/src/room.dart` дотор, сокетгүйгээр
// тестлэгддэг. Энэ файл нь зөвхөн: сокет нээх, мессеж уншиж өрөө рүү
// дамжуулах, гарсан мессежийг зөв хүмүүс рүү илгээх.
//
// Ажиллуулах:  dart run bin/server.dart [--port 8080]

import 'dart:async';
import 'dart:io';

import 'package:protocol/protocol.dart';
import 'package:server/server.dart';
import 'package:server/src/hub.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Цаг хэмжигчийн алхам. Үе шат энэ нарийвчлалаар солигдоно.
const Duration kTickEvery = Duration(milliseconds: 250);

/// Нэг холболт хэр олон мессеж илгээж болох вэ (секундэд).
/// Хэт олон илгээвэл таслана — нэг хүн серверийг дүүргэж болохгүй.
const int kMaxMsgPerSecond = 20;

void main(List<String> args) async {
  final int port = _intArg(args, '--port') ?? 8080;
  final Hub hub = Hub();
  final Server server = Server(hub);

  // Үе шатын цаг. Нэг таймер БҮХ өрөөг хөдөлгөнө — өрөө тутам таймер
  // үүсгэвэл мянган өрөөнд мянган таймер болно.
  final Stopwatch clock = Stopwatch()..start();
  Timer.periodic(kTickEvery, (_) => server.tickAll(clock.elapsedMilliseconds));

  // Хоосон өрөөг цэвэрлэх.
  Timer.periodic(const Duration(seconds: 30), (_) => hub.sweepEmpty());

  final Handler handler = webSocketHandler(
    (WebSocketChannel socket, String? _) => server.attach(socket, clock),
  );

  final HttpServer http = await io.serve(handler, InternetAddress.anyIPv4, port);
  stdout.writeln('«Хот унтлаа» сервер: ws://${http.address.host}:${http.port}');
}

/// Нэг холбогдсон утас.
class _Conn {
  _Conn(this.socket);

  final WebSocketChannel socket;
  PlayerId? playerId;
  GameRoom? room;

  /// Хурд хязгаарлах цонх.
  int windowStartMs = 0;
  int msgsInWindow = 0;

  void send(Envelope e) {
    try {
      socket.sink.add(e.encode());
    } catch (_) {
      // Хаагдсан сокет — тоохгүй. Цэвэрлэгээ `onDone`-д болно.
    }
  }
}

class Server {
  Server(this._hub);

  final Hub _hub;
  final Set<_Conn> _conns = <_Conn>{};

  /// Тоглогчийн дугаар → холболт. Хаяглагдсан мессеж илгээхэд.
  final Map<PlayerId, _Conn> _byPlayer = <PlayerId, _Conn>{};

  void attach(WebSocketChannel socket, Stopwatch clock) {
    final _Conn c = _Conn(socket);
    _conns.add(c);
    socket.stream.listen(
      (Object? raw) {
        if (raw is! String) return;
        _onMessage(c, raw, clock.elapsedMilliseconds);
      },
      onDone: () => _detach(c),
      onError: (Object _) => _detach(c),
      cancelOnError: true,
    );
  }

  void _detach(_Conn c) {
    final PlayerId? id = c.playerId;
    final GameRoom? room = c.room;
    _conns.remove(c);
    if (id != null) _byPlayer.remove(id);
    if (id != null && room != null) _dispatch(room, room.leave(id));
  }

  void _onMessage(_Conn c, String raw, int nowMs) {
    // --- Хурд хязгаар ------------------------------------------------------
    if (nowMs - c.windowStartMs >= 1000) {
      c.windowStartMs = nowMs;
      c.msgsInWindow = 0;
    }
    if (++c.msgsInWindow > kMaxMsgPerSecond) {
      c.send(const Envelope(
          S2C.error, <String, Object?>{'code': ErrCode.rateLimited}));
      return;
    }

    final Envelope? e = Envelope.decode(raw);
    if (e == null) {
      c.send(const Envelope(
          S2C.error, <String, Object?>{'code': ErrCode.malformed}));
      return;
    }
    if (e.v != kProtocolVersion) {
      c.send(const Envelope(S2C.error, <String, Object?>{
        'code': ErrCode.badVersion,
        'need': kProtocolVersion,
      }));
      return;
    }

    switch (e.type) {
      case C2S.ping:
        c.send(const Envelope(S2C.pong, <String, Object?>{}));

      case C2S.hello:
        final String? id = e.data['playerId'] as String?;
        if (id == null || id.isEmpty) {
          c.send(const Envelope(
              S2C.error, <String, Object?>{'code': ErrCode.malformed}));
          return;
        }
        // Нэг дугаараар хоёр удаа орвол хуучин холболтыг таслана.
        _byPlayer[id]?.socket.sink.close();
        c.playerId = id;
        _byPlayer[id] = c;

      case C2S.listRooms:
        c.send(Envelope(S2C.roomList,
            <String, Object?>{'rooms': _hub.publicRooms()}));

      case C2S.createRoom:
        final PlayerId? id = c.playerId;
        if (id == null) return;
        final GameRoom? r =
            _hub.create(id, isPublic: e.data['isPublic'] as bool? ?? true);
        if (r == null) {
          c.send(const Envelope(
              S2C.error, <String, Object?>{'code': ErrCode.roomFull}));
          return;
        }
        c.room = r;
        _dispatch(
          r,
          r.join(id, e.data['name'] as String? ?? '',
              e.data['avatarId'] as String? ?? 'punk_01'),
        );

      case C2S.joinRoom:
        final PlayerId? id = c.playerId;
        if (id == null) return;
        final GameRoom? r = _hub.byCode(e.data['code'] as String? ?? '');
        if (r == null) {
          c.send(const Envelope(
              S2C.error, <String, Object?>{'code': ErrCode.roomNotFound}));
          return;
        }
        c.room = r;
        _dispatch(
          r,
          r.join(id, e.data['name'] as String? ?? '',
              e.data['avatarId'] as String? ?? 'punk_01'),
        );

      case C2S.leaveRoom:
        final GameRoom? r = c.room;
        final PlayerId? id = c.playerId;
        if (r == null || id == null) return;
        c.room = null;
        _dispatch(r, r.leave(id));

      case C2S.setReady:
        _withRoom(c, (GameRoom r, PlayerId id) =>
            r.setReady(id, e.data['ready'] as bool? ?? false));

      case C2S.startGame:
        _withRoom(c, (GameRoom r, PlayerId id) => r.start(id, nowMs));

      case C2S.nightAction:
        final int? target = e.data['targetSeat'] as int?;
        if (target == null) return;
        _withRoom(
            c, (GameRoom r, PlayerId id) => r.nightAction(id, target, nowMs));

      case C2S.vote:
        _withRoom(c,
            (GameRoom r, PlayerId id) => r.vote(id, e.data['targetSeat'] as int?));

      default:
        // Танихгүй төрөл — алгасна. Шинэ үйлчлүүлэгч хуучин серверт
        // холбогдоход унахгүй байх нь чухал.
        break;
    }
  }

  void _withRoom(
      _Conn c, List<Outbound> Function(GameRoom, PlayerId) action) {
    final GameRoom? r = c.room;
    final PlayerId? id = c.playerId;
    if (r == null || id == null) {
      c.send(const Envelope(
          S2C.error, <String, Object?>{'code': ErrCode.roomNotFound}));
      return;
    }
    _dispatch(r, action(r, id));
  }

  /// Гарсан мессежүүдийг ЗӨВ хүмүүс рүү илгээнэ.
  ///
  /// Хаяглалтыг `Outbound` төрөл нь аль хэдийн шийдсэн. Энд зөвхөн хүргэнэ —
  /// энэ функц ХЭЗЭЭ Ч хаяглалтыг өөрчлөхгүй.
  void _dispatch(GameRoom room, List<Outbound> out) {
    if (out.isEmpty) return;
    final Set<PlayerId> inRoom =
        room.players.map((PublicPlayer p) => p.id).toSet();
    for (final Outbound o in out) {
      final Iterable<PlayerId> targets =
          o.broadcast ? inRoom : o.recipients;
      for (final PlayerId id in targets) {
        _byPlayer[id]?.send(o.msg);
      }
    }
  }

  /// Бүх өрөөний цагийг урагшлуулна.
  void tickAll(int nowMs) {
    // Хуулбар дээр гүйлгэнэ — `tick` дотор өрөө устаж болно.
    final Set<GameRoom> rooms =
        _conns.map((_Conn c) => c.room).whereType<GameRoom>().toSet();
    for (final GameRoom r in rooms) {
      _dispatch(r, r.tick(nowMs));
    }
  }
}

int? _intArg(List<String> args, String name) {
  final int i = args.indexOf(name);
  if (i < 0 || i + 1 >= args.length) return null;
  return int.tryParse(args[i + 1]);
}
