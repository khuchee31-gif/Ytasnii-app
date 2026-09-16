// Сүлжээний мессежүүд — сервер ба апп хоёрын ГЭРЭЭ.
//
// ХАМГИЙН ЧУХАЛ ЗАРЧИМ: онлайн мафи тоглоомд УРВАЛТ нь кодоос эхэлдэг.
// Хэрэв сервер бүх тоглогчийн дүрийг бүх утас руу илгээвэл, хүн утасныхаа
// сүлжээг хараад бусдын дүрийг уншина — тоглоом үхнэ.
//
// Тиймээс энд НИЙТИЙН ба ХУВИЙН мессежийг ТӨРЛӨӨРӨӨ салгасан:
//   • `RoomState`  — бүгдэд очно. Дүр АГУУЛАХГҮЙ. Тэр талбар нь байхгүй.
//   • `YourRole`   — ЗӨВХӨН нэг хүнд. Сервер хаяглаж илгээнэ.
//   • `NightWhisper` — зөвхөн тухайн сувгийнханд.
//
// Ингэснээр «санамсаргүй нэмчихлээ» гэсэн алдаа гарах боломжгүй: нийтийн
// мессежийн ангид дүрийн талбар БАЙХГҮЙ учраас бичих ч аргагүй.

import 'dart:convert';

/// Протоколын хувилбар. Сервер, апп хоёр зөрвөл шууд татгалзана —
/// «хагас ойлголцсон» тоглолт бол хамгийн муу төрлийн алдаа.
const int kProtocolVersion = 1;

/// Тоглогчийн байнгын дугаар. Сүлжээ тасарсан ч үүгээрээ эргэж ороно.
typedef PlayerId = String;

/// Ширээн дэх суудал, 1-ээс эхэлнэ. Тоглолт эхлэх хүртэл `null`.
typedef Seat = int;

// ---------------------------------------------------------------------------
// Үе шат — сервер эзэмшинэ. Апп үүнийг ЗӨВХӨН харуулна, шийддэггүй.
// ---------------------------------------------------------------------------

enum NetPhase {
  /// Өрөөнд хүлээж байна. Хүмүүс орж, гарч байна.
  lobby,

  /// Хөзөр тарааж, дүр өгч байна.
  dealing,

  /// «Хот унтлаа.» Бүгд чимээгүй.
  nightFalls,

  /// Алуурчид сэрсэн. ЗӨВХӨН тэд бие биенээ сонсоно.
  nightMafia,

  /// Эмч сэрсэн.
  nightDoctor,

  /// Мөрдөгч сэрсэн.
  nightDetective,

  /// Үүр цайлаа — шөнийн үр дүн зарлагдана.
  dawn,

  /// Өдөр. БҮГД ярина.
  day,

  /// Санал хураалт.
  vote,

  /// Хасалт зарлагдаж байна.
  elimination,

  /// Тоглолт дууслаа.
  gameOver,
}

/// Тухайн үе шатанд ХЭН ярьж чадах вэ.
///
/// Сервер дууны чиглүүлэлтийг ҮҮГЭЭР шийднэ. Апп өөрөө шийдэхгүй —
/// апп-д итгэвэл өөрчилсөн апп бүхнийг сонсоно.
enum VoiceScope {
  /// Хэн ч ярихгүй. Шөнийн эхэн, үр дүн зарлах үе.
  none,

  /// Бүгд ярина. Өдөр.
  everyone,

  /// Зөвхөн мафи. Бусад нь ОГТ сонсохгүй.
  mafiaOnly,

  /// Зөвхөн тухайн нэг хүн (эмч, мөрдөгч) — үнэндээ хэн ч сонсохгүй,
  /// гэхдээ микрофоноо нээлттэй байлгаж болно.
  selfOnly,
}

// ---------------------------------------------------------------------------
// Нийтийн тоглогчийн харагдац — ЭНД ДҮР БАЙХГҮЙ
// ---------------------------------------------------------------------------

/// Бүх тоглогчид харагддаг мэдээлэл.
///
/// ЭНЭ АНГИД `role` ТАЛБАР БАЙХГҮЙ, БАС БАЙЖ БОЛОХГҮЙ. Хэрэв хэн нэгэн
/// нэмэх гэвэл `test/no_role_leak_test.dart` унана.
class PublicPlayer {
  const PublicPlayer({
    required this.id,
    required this.name,
    required this.avatarId,
    this.seat,
    this.alive = true,
    this.connected = true,
    this.ready = false,
    this.speaking = false,
  });

  final PlayerId id;
  final String name;

  /// Дүрийн зураг. ТОГЛООМЫН ДҮРТЭЙ ХОЛБООГҮЙ — зөвхөн гоо сайхан.
  final String avatarId;

  final Seat? seat;
  final bool alive;
  final bool connected;
  final bool ready;

  /// Яг одоо ярьж байна уу — ширээн дээр дүр нь гэрэлтэнэ.
  final bool speaking;

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'name': name,
        'avatarId': avatarId,
        if (seat != null) 'seat': seat,
        'alive': alive,
        'connected': connected,
        'ready': ready,
        'speaking': speaking,
      };

  static PublicPlayer fromJson(Map<String, Object?> j) => PublicPlayer(
        id: j['id']! as String,
        name: j['name']! as String,
        avatarId: j['avatarId']! as String,
        seat: j['seat'] as int?,
        alive: j['alive'] as bool? ?? true,
        connected: j['connected'] as bool? ?? true,
        ready: j['ready'] as bool? ?? false,
        speaking: j['speaking'] as bool? ?? false,
      );

  PublicPlayer copyWith({
    Seat? seat,
    bool? alive,
    bool? connected,
    bool? ready,
    bool? speaking,
  }) =>
      PublicPlayer(
        id: id,
        name: name,
        avatarId: avatarId,
        seat: seat ?? this.seat,
        alive: alive ?? this.alive,
        connected: connected ?? this.connected,
        ready: ready ?? this.ready,
        speaking: speaking ?? this.speaking,
      );
}

// ---------------------------------------------------------------------------
// Дугтуй — бүх мессеж үүгээр дамжина
// ---------------------------------------------------------------------------

/// Сүлжээгээр явах нэг мессеж.
///
/// `type` нь шошго, `data` нь агуулга. Ингэснээр шинэ мессеж нэмэхэд хуучин
/// үйлчлүүлэгч унахгүй — танихгүй төрлийг зүгээр алгасна.
class Envelope {
  const Envelope(this.type, this.data, {this.v = kProtocolVersion});

  final String type;
  final Map<String, Object?> data;
  final int v;

  String encode() => jsonEncode(<String, Object?>{
        'v': v,
        't': type,
        'd': data,
      });

  /// Буруу хэлбэртэй мессежид `null` буцаана — сервер унахгүй.
  /// Сүлжээнээс ирсэн ямар ч байт ИТГЭЛГҮЙ гэж үзнэ.
  static Envelope? decode(String raw) {
    try {
      final Object? j = jsonDecode(raw);
      if (j is! Map<String, Object?>) return null;
      final Object? t = j['t'];
      if (t is! String || t.isEmpty) return null;
      final Object? d = j['d'];
      return Envelope(
        t,
        d is Map<String, Object?> ? d : const <String, Object?>{},
        v: j['v'] is int ? j['v']! as int : 0,
      );
    } catch (_) {
      return null;
    }
  }
}

// ---------------------------------------------------------------------------
// Үйлчлүүлэгч → Сервер
// ---------------------------------------------------------------------------

abstract final class C2S {
  /// Танилцах. Холболтын ЭХНИЙ мессеж байх ёстой.
  static const String hello = 'hello';

  /// Шинэ өрөө үүсгэх. Хариуд нь `S2C.roomState` ирнэ.
  static const String createRoom = 'createRoom';

  /// Кодоор орох.
  static const String joinRoom = 'joinRoom';

  /// Нээлттэй өрөөний жагсаалт хүсэх.
  static const String listRooms = 'listRooms';

  static const String leaveRoom = 'leaveRoom';
  static const String setReady = 'setReady';

  /// Зөвхөн өрөөний эзэн.
  static const String startGame = 'startGame';

  /// Шөнийн үйлдэл — хэн рүү чиглэв.
  static const String nightAction = 'nightAction';

  static const String nominate = 'nominate';
  static const String vote = 'vote';

  /// Амьд байгаа эсэхийг шалгах. Сүлжээ тасарснаас сэргийлнэ.
  static const String ping = 'ping';
}

// ---------------------------------------------------------------------------
// Сервер → Үйлчлүүлэгч
// ---------------------------------------------------------------------------

abstract final class S2C {
  /// Өрөөний НИЙТИЙН төлөв. Дүр агуулахгүй.
  static const String roomState = 'roomState';

  /// ЗӨВХӨН нэг хүнд. Түүний өөрийн дүр.
  static const String yourRole = 'yourRole';

  /// Үе шат солигдов. Дуу дамжуулалт ч энд шинэчлэгдэнэ.
  static const String phase = 'phase';

  /// Шөнийн үр дүн — нийтийнх.
  static const String nightResult = 'nightResult';

  /// ЗӨВХӨН мөрдөгчид. Шалгасны хариу.
  static const String investigateResult = 'investigateResult';

  /// Санал хураалтын явц.
  static const String voteState = 'voteState';

  /// Тоглолт дууслаа — энд л бүх дүр ил болно.
  static const String gameOver = 'gameOver';

  /// Нээлттэй өрөөнүүд.
  static const String roomList = 'roomList';

  /// Дууны серверт холбогдох түлхүүр. Үе шат бүрд шинэчлэгдэж болно.
  static const String voiceGrant = 'voiceGrant';

  static const String error = 'error';
  static const String pong = 'pong';
}

/// Алдааны кодууд. Апп эдгээрийг монгол бичвэр рүү хөрвүүлнэ —
/// сервер хэлний талаар юу ч мэдэхгүй.
abstract final class ErrCode {
  static const String badVersion = 'badVersion';
  static const String roomNotFound = 'roomNotFound';
  static const String roomFull = 'roomFull';
  static const String gameInProgress = 'gameInProgress';
  static const String notHost = 'notHost';
  static const String notYourTurn = 'notYourTurn';
  static const String invalidTarget = 'invalidTarget';
  static const String tooFewPlayers = 'tooFewPlayers';
  static const String nameTaken = 'nameTaken';
  static const String rateLimited = 'rateLimited';
  static const String malformed = 'malformed';
}
