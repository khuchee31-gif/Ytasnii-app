// Серверийн холболт — аппын тал.
//
// ХАРИУЦЛАГЫН ХИЛ: энэ файл ДҮРЭМ МЭДЭХГҮЙ. Хэн ялсан, хэн юу хийж болохыг
// сервер шийднэ. Энд зөвхөн: холбогдох, мессеж илгээх, ирсэн мессежийг
// төлөв болгон хадгалах, холболт тасрахад дахин оролдох.
//
// ЯАГААД ЧУХАЛ: апп дүрэм давхардуулж бичвэл сервертэй зөрөх өдөр ирнэ.
// Тэр үед аль нь зөв болох нь тодорхойгүй болно. Тиймээс апп бол ЗӨВХӨН
// ЦОНХ — серверийн хэлснийг харуулна.

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:protocol/protocol.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Холболтын байдал — дэлгэцэд шууд харуулна.
enum LinkState {
  /// Хараахан холбогдоогүй.
  idle,

  connecting,
  connected,

  /// Тасарсан, дахин оролдож байна.
  reconnecting,

  /// Дахин оролдохоо больсон (хувилбар зөрсөн гэх мэт).
  failed,
}

/// Миний ӨӨРИЙН нууц мэдээлэл. Зөвхөн энэ утсанд.
class MyRole {
  const MyRole({
    required this.seat,
    required this.role,
    required this.faction,
    this.allySeats = const <int>[],
  });

  final int seat;

  /// Хөдөлгүүрийн `Role.name` — `killer`, `doctor`, `detective`, `citizen`, `boss`.
  final String role;

  /// `mafi` эсвэл `hotynhon`.
  final String faction;

  /// Мафийн хамтрагчдын суудал. Хотынхонд ҮРГЭЛЖ хоосон.
  final List<int> allySeats;

  bool get isMafia => faction == 'mafi';
}

/// Серверийн үйлчлүүлэгч.
class GameClient extends ChangeNotifier {
  GameClient({required this.url, String? playerId})
    : playerId = playerId ?? _newId();

  final String url;

  /// Байнгын дугаар. Сүлжээ тасарсан ч үүгээрээ эргэж ороно.
  final PlayerId playerId;

  WebSocketChannel? _sock;
  StreamSubscription<dynamic>? _sub;
  Timer? _retry;
  Timer? _ping;
  int _attempt = 0;
  bool _closedByUs = false;

  // --- Төлөв ---------------------------------------------------------------

  LinkState _link = LinkState.idle;
  LinkState get link => _link;

  String? _roomCode;
  String? get roomCode => _roomCode;

  NetPhase _phase = NetPhase.lobby;
  NetPhase get phase => _phase;

  /// Тухайн үе шат хэзээ дуусах вэ — серверээс ирсэн үлдсэн хугацаа.
  int _phaseEndsInMs = 0;
  int get phaseEndsInMs => _phaseEndsInMs;

  List<PublicPlayer> _players = const <PublicPlayer>[];
  List<PublicPlayer> get players => _players;

  PlayerId? _hostId;
  bool get isHost => _hostId != null && _hostId == playerId;

  MyRole? _me;
  MyRole? get me => _me;

  /// Микрофоноо нээж болох уу. СЕРВЕР шийднэ.
  bool _canSpeak = false;
  bool get canSpeak => _canSpeak;

  /// Нээлттэй өрөөнүүд.
  List<({String code, int players, int max})> _rooms =
      const <({String code, int players, int max})>[];
  List<({String code, int players, int max})> get rooms => _rooms;

  /// Сүүлийн алдааны код. Дэлгэц үүнийг монгол бичвэр рүү хөрвүүлнэ.
  String? _lastError;
  String? get lastError => _lastError;

  /// Мафийн сонголтууд — зөвхөн мафид ирнэ (суудал → бай).
  final Map<int, int> mafiaPicks = <int, int>{};

  /// Шөнийн үр дүн: сүүлийн шөнө хэн нас барав.
  List<int> _lastDeaths = const <int>[];
  List<int> get lastDeaths => _lastDeaths;

  /// Мөрдөгчийн хариу — зөвхөн мөрдөгчид.
  String? _traceResult;
  String? get traceResult => _traceResult;

  /// Тоглолт дуусахад бүх дүр ил болно (суудал → дүр).
  Map<int, String> _reveal = const <int, String>{};
  Map<int, String> get reveal => _reveal;

  String? _winner;
  String? get winner => _winner;

  // --- Холболт -------------------------------------------------------------

  Future<void> connect() async {
    _closedByUs = false;
    _set(LinkState.connecting);
    try {
      final WebSocketChannel c = WebSocketChannel.connect(Uri.parse(url));
      await c.ready;
      _sock = c;
      _attempt = 0;
      _set(LinkState.connected);
      _sub = c.stream.listen(
        _onRaw,
        onDone: _onDropped,
        onError: (Object _) => _onDropped(),
        cancelOnError: true,
      );
      _send(C2S.hello, <String, Object?>{'playerId': playerId});
      // Хэрэв өрөөнд байсан бол эргэж ороно.
      final String? code = _roomCode;
      if (code != null) {
        _send(C2S.joinRoom, <String, Object?>{'code': code});
      }
      _ping?.cancel();
      _ping = Timer.periodic(
        const Duration(seconds: 20),
        (_) => _send(C2S.ping),
      );
    } catch (_) {
      _onDropped();
    }
  }

  void _onDropped() {
    _sub?.cancel();
    _ping?.cancel();
    _sock = null;
    if (_closedByUs || _link == LinkState.failed) return;
    _set(LinkState.reconnecting);
    // Экспоненциал ухралт, дээд тал нь 15 секунд. Санамсаргүй нэмэлт —
    // 12 утас нэг зэрэг холбогдох гэж сервер рүү дайрахаас сэргийлнэ.
    _attempt = (_attempt + 1).clamp(1, 6);
    final int base = 500 * (1 << (_attempt - 1));
    final int jitter = Random().nextInt(400);
    _retry?.cancel();
    _retry = Timer(
      Duration(milliseconds: (base + jitter).clamp(500, 15000)),
      connect,
    );
  }

  @override
  void dispose() {
    _closedByUs = true;
    _retry?.cancel();
    _ping?.cancel();
    _sub?.cancel();
    _sock?.sink.close();
    super.dispose();
  }

  // --- Илгээх --------------------------------------------------------------

  void _send(
    String type, [
    Map<String, Object?> d = const <String, Object?>{},
  ]) {
    final WebSocketChannel? s = _sock;
    if (s == null) return;
    try {
      s.sink.add(Envelope(type, d).encode());
    } catch (_) {
      _onDropped();
    }
  }

  void listRooms() => _send(C2S.listRooms);

  void createRoom({
    required String name,
    required String avatarId,
    bool isPublic = true,
  }) => _send(C2S.createRoom, <String, Object?>{
    'name': name,
    'avatarId': avatarId,
    'isPublic': isPublic,
  });

  void joinRoom({
    required String code,
    required String name,
    required String avatarId,
  }) {
    _roomCode = code.toUpperCase();
    _send(C2S.joinRoom, <String, Object?>{
      'code': _roomCode,
      'name': name,
      'avatarId': avatarId,
    });
  }

  void leaveRoom() {
    _send(C2S.leaveRoom);
    _roomCode = null;
    _me = null;
    _players = const <PublicPlayer>[];
    notifyListeners();
  }

  void setReady(bool r) => _send(C2S.setReady, <String, Object?>{'ready': r});
  void startGame() => _send(C2S.startGame);

  void nightAction(int targetSeat) =>
      _send(C2S.nightAction, <String, Object?>{'targetSeat': targetSeat});

  void vote(int? targetSeat) =>
      _send(C2S.vote, <String, Object?>{'targetSeat': targetSeat});

  // --- Хүлээн авах ---------------------------------------------------------

  void _onRaw(Object? raw) {
    if (raw is! String) return;
    final Envelope? e = Envelope.decode(raw);
    if (e == null) return;

    switch (e.type) {
      case S2C.roomState:
        _roomCode = e.data['code'] as String? ?? _roomCode;
        _hostId = e.data['hostId'] as String?;
        _phase = _phaseOf(e.data['phase'] as String?) ?? _phase;
        final Object? ps = e.data['players'];
        if (ps is List<Object?>) {
          _players = ps
              .whereType<Map<String, Object?>>()
              .map(PublicPlayer.fromJson)
              .toList();
        }

      case S2C.yourRole:
        final Object? allies = e.data['allySeats'];
        _me = MyRole(
          seat: e.data['seat']! as int,
          role: e.data['role']! as String,
          faction: e.data['faction']! as String,
          allySeats: allies is List<Object?>
              ? allies.whereType<int>().toList()
              : const <int>[],
        );

      case S2C.phase:
        _phase = _phaseOf(e.data['phase'] as String?) ?? _phase;
        _phaseEndsInMs = e.data['endsInMs'] as int? ?? 0;
        // Шинэ үе шат — өмнөх шөнийн түр зуурын мэдээлэл цэвэрлэгдэнэ.
        if (_phase == NetPhase.nightFalls) {
          mafiaPicks.clear();
          _traceResult = null;
        }

      case S2C.voiceGrant:
        _canSpeak = e.data['canSpeak'] as bool? ?? false;

      case 'mafiaPick':
        final int? by = e.data['bySeat'] as int?;
        final int? t = e.data['targetSeat'] as int?;
        if (by != null && t != null) mafiaPicks[by] = t;

      case S2C.nightResult:
        final Object? d = e.data['deaths'];
        _lastDeaths = d is List<Object?>
            ? d.whereType<int>().toList()
            : const <int>[];

      case S2C.investigateResult:
        _traceResult = e.data['code'] as String?;

      case S2C.roomList:
        final Object? rs = e.data['rooms'];
        if (rs is List<Object?>) {
          _rooms = rs
              .whereType<Map<String, Object?>>()
              .map(
                (Map<String, Object?> m) => (
                  code: m['code']! as String,
                  players: m['players']! as int,
                  max: m['max']! as int,
                ),
              )
              .toList();
        }

      case S2C.gameOver:
        _winner = e.data['winner'] as String?;
        final Object? rv = e.data['reveal'];
        if (rv is Map<String, Object?>) {
          _reveal = <int, String>{
            for (final MapEntry<String, Object?> m in rv.entries)
              if (int.tryParse(m.key) != null && m.value is String)
                int.parse(m.key): m.value! as String,
          };
        }

      case S2C.error:
        _lastError = e.data['code'] as String?;
        // Хувилбар зөрвөл дахин оролдох утгагүй — хүн аппаа шинэчлэх ёстой.
        if (_lastError == ErrCode.badVersion) {
          _closedByUs = true;
          _set(LinkState.failed);
        }

      case S2C.pong:
        return; // төлөв өөрчлөгдөөгүй, дэлгэц дахин зурах шаардлагагүй

      default:
        return;
    }
    notifyListeners();
  }

  void _set(LinkState s) {
    if (_link == s) return;
    _link = s;
    notifyListeners();
  }

  static NetPhase? _phaseOf(String? name) {
    if (name == null) return null;
    for (final NetPhase p in NetPhase.values) {
      if (p.name == name) return p;
    }
    return null;
  }

  /// Давхардахгүй дугаар. Криптографийн зориулалтгүй — зөвхөн таних.
  static String _newId() {
    final Random r = Random.secure();
    final List<int> b = List<int>.generate(12, (_) => r.nextInt(256));
    return base64Url.encode(b).replaceAll('=', '');
  }
}
