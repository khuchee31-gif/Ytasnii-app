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

  /// Хэзээнээс хойш нэг ч хүн холбоогүй байна (мс).
  final Map<String, int> _emptySinceMs = <String, int>{};

  /// Бүх хүн салсны дараа өрөөг хэр удаан хадгалах вэ.
  ///
  /// Ангийн Wi-Fi нэг мөчид тасарч болно. Тэр дороо устгавал бүх
  /// тоглолт алга болно. Гурван минут нь «сүлжээ саатав» ба «бүгд явлаа»
  /// хоёрыг ялгахад хангалттай.
  static const int graceMs = 180000;

  int get roomCount => _rooms.length;

  /// Бүх өрөө. Сервер цагийг ЭНДЭЭС урагшлуулна.
  ///
  /// Өмнө нь холболтоос гаргадаг байв (`_conns.map((c) => c.room)`).
  /// Тэгэхэд сүүлчийн хүн нь салсан тоглолт цаашид ХЭЗЭЭ Ч алхахгүй,
  /// `gameOver` хүрэхгүй, цэвэрлэгдэхгүй үлддэг байв.
  Iterable<GameRoom> get rooms => _rooms.values;

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
  void drop(String code) {
    _rooms.remove(code.toUpperCase());
    _emptySinceMs.remove(code.toUpperCase());
  }

  /// Хүнгүй болсон өрөөг устгана. Сервер үүнийг тогтмол дуудна.
  ///
  /// ХОЛБООТОЙ хүнээр тоолно.
  ///
  /// Өмнө нь `humanCount`-оор тоолдог байсан бөгөөд тэр нь `_players`
  /// дотор ҮЛДСЭН хүнийг ч тоолдог: `leave` нь тоглолт эхэлсний дараа
  /// суудлыг хадгалдаг (эргэж орох эрх). Иймд сүүлчийн хүн нь тоглолт
  /// дунд салсан өрөө `humanCount == 1` хэвээр үүрд үлдэнэ.
  ///
  /// Гараар шалгасан халдлага: нэг сокетоор «өрөө үүсгэ → 5 бот нэм →
  /// эхлүүл → сокетоо тасал» гэдгийг 505 удаа давтахад сервер дахин
  /// хэзээ ч өрөө үүсгэж чадахгүй болсон (`roomFull`, дахин асаах
  /// хүртэл). Нийт зардал нь ~30 секунд.
  int sweepEmpty({int nowMs = 0}) {
    final List<String> dead = <String>[];
    for (final MapEntry<String, GameRoom> e in _rooms.entries) {
      if (e.value.connectedHumans > 0) {
        _emptySinceMs.remove(e.key);
        continue;
      }
      // Лоббид хүнгүй бол шууд — эргэж орох тоглолт байхгүй.
      if (e.value.inLobby) {
        dead.add(e.key);
        continue;
      }
      final int since = _emptySinceMs.putIfAbsent(e.key, () => nowMs);
      if (nowMs - since >= graceMs) dead.add(e.key);
    }
    for (final String c in dead) {
      _rooms.remove(c);
      _emptySinceMs.remove(c);
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
