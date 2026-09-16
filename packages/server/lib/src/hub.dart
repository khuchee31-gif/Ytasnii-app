// Өрөөний бүртгэл — код үүсгэх, олох, цэвэрлэх.
//
// Сүлжээний давхаргаас ТУСДАА. Энд ч гэсэн `dart:io` байхгүй тул тестлэгдэнэ.

import 'dart:math';
import 'dart:typed_data';

import 'package:protocol/protocol.dart';

import 'room.dart';

/// Өрөөний кодын үсэг.
///
/// `O`/`0`, `I`/`1`, `S`/`5` зэрэг ЭНД БАЙХГҮЙ: анги дотор кодоо чангаар
/// хэлэхэд «О юу тэг үү?» гэж асуух нь тоглоомын эхлэлийг удаашруулна.
const String kCodeAlphabet = 'ABCDEFGHJKMNPQRTUVWXY2346789';
const int kCodeLength = 4;

class Hub {
  Hub({Random? rng, int maxRooms = 500})
      : _rng = rng ?? Random.secure(),
        _maxRooms = maxRooms;

  final Random _rng;
  final int _maxRooms;
  final Map<String, GameRoom> _rooms = <String, GameRoom>{};

  int get roomCount => _rooms.length;

  GameRoom? byCode(String code) => _rooms[code.toUpperCase()];

  /// Нээлттэй, хүлээж байгаа өрөөнүүд — шинэ ороход харагдах жагсаалт.
  List<Map<String, Object?>> publicRooms({int limit = 30}) => _rooms.values
      .where((GameRoom r) =>
          r.isPublic && r.inLobby && r.playerCount < kMaxPlayers)
      .take(limit)
      .map((GameRoom r) => <String, Object?>{
            'code': r.code,
            'players': r.playerCount,
            'max': kMaxPlayers,
          })
      .toList();

  /// Шинэ өрөө. Багтаамж дүүрсэн бол `null`.
  GameRoom? create(PlayerId hostId, {bool isPublic = true}) {
    if (_rooms.length >= _maxRooms) return null;
    final String code = _freeCode();
    final GameRoom r = GameRoom(
      code: code,
      hostId: hostId,
      seed: _seed(),
      isPublic: isPublic,
    );
    _rooms[code] = r;
    return r;
  }

  /// Нэг өрөөг шууд устгана. Үүсгэх үйлдэл бүтэлгүйтэхэд хэрэгтэй.
  void drop(String code) => _rooms.remove(code.toUpperCase());

  /// Хоосон болсон өрөөг устгана. Сервер үүнийг тогтмол дуудна.
  int sweepEmpty() {
    final List<String> dead = _rooms.entries
        // ХҮНЭЭР тоолно, тоглогчоор БИШ. Бот `_players` дотор үлддэг тул
        // эзэн нь гарсан ботон өрөө ХЭЗЭЭ Ч цэвэрлэгдэхгүй байсан: өрөө
        // үүсгээд бот нэмээд гарахыг 500 удаа давтвал сервер дээр шинэ
        // өрөө үүсэхээ болино (`_maxRooms`).
        .where((MapEntry<String, GameRoom> e) => e.value.humanCount == 0)
        .map((MapEntry<String, GameRoom> e) => e.key)
        .toList();
    for (final String c in dead) {
      _rooms.remove(c);
    }
    return dead.length;
  }

  /// Давхардаагүй код. Бүх код дүүрсэн тохиолдол практикт гарахгүй
  /// (28^4 ≈ 614 мянга) ч хязгааргүй давталтаас сэргийлж тоолно.
  String _freeCode() {
    for (int attempt = 0; attempt < 1000; attempt++) {
      final String c = String.fromCharCodes(
        List<int>.generate(
          kCodeLength,
          (_) => kCodeAlphabet.codeUnitAt(_rng.nextInt(kCodeAlphabet.length)),
        ),
      );
      if (!_rooms.containsKey(c)) return c;
    }
    // Энд хүрвэл өрөө хэт олон байна — дээд хязгаар үүнээс сэргийлдэг.
    throw StateError('өрөөний код дууслаа');
  }

  Uint8List _seed() =>
      Uint8List.fromList(List<int>.generate(32, (_) => _rng.nextInt(256)));
}
