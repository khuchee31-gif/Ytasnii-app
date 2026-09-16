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
///
/// 2 — `hello` нь `token` шаардана. Хуучин апп нь `badVersion` авна.
const int kProtocolVersion = 2;

/// `hello`-д заавал ирэх НУУЦ түлхүүрийн хамгийн бага урт (арван зургаа
/// тэмдэгт = 64 бит). Үүнээс богино бол хэн нэгэн таах боломжтой.
const int kMinTokenLength = 16;

/// Ботын дугаарын угтвар. Энэ угтвартай дугаарыг СОКЕТООР ХЭЗЭЭ Ч
/// нэхэж болохгүй — эс бөгөөс ботын `yourRole` хулгайлагдана.
const String kBotIdPrefix = 'bot-';

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
    this.isBot = false,
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

  /// Хиймэл тоглогч мөн үү.
  ///
  /// ЭНЭ НЬ ДҮР БИШ. Бот эсэх нь өрөөнд ОРОХ үед тогтоогддог, дүр нь
  /// хожим САНАМСАРГҮЙ тарагддаг тул энэ талбар дүрийн тухай ЮУ Ч
  /// хэлэхгүй. Ботыг ил тэмдэглэх нь шударга: тэмдэглэхгүй бол чимээгүй
  /// суудал «сэжигтэй дуугүй хүн» мэт харагдаж, эхний өдөр хасагдана.
  final bool isBot;

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'name': name,
        'avatarId': avatarId,
        if (seat != null) 'seat': seat,
        'alive': alive,
        'connected': connected,
        'ready': ready,
        'speaking': speaking,
        'isBot': isBot,
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
        isBot: j['isBot'] as bool? ?? false,
      );

  /// ЭНЭ ЖАГСААЛТАД ШИНЭ ТАЛБАР НЭМЭХЭЭ БҮҮ МАРТ.
  ///
  /// `copyWith` нь объектыг талбар бүрээр нь ДАХИН БАРЬДАГ. Жагсаалтад
  /// нэмэхгүй орхивол код хэвийн хөрвөж, тестүүд ногоон хэвээр үлдэнэ —
  /// гэхдээ тэр талбар дуудагдах болгонд чимээгүйхэн анхны утга руугаа
  /// буцна. `isBot`-ыг орхивол ботууд лоббид тэмдэглэгдээд, тоглолт
  /// эхэлмэгц хүнээс ялгагдахаа болино.
  PublicPlayer copyWith({
    Seat? seat,
    bool? alive,
    bool? connected,
    bool? ready,
    bool? speaking,
    bool? isBot,
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
        isBot: isBot ?? this.isBot,
      );

  /// Нэр солих. `copyWith`-д оруулаагүй нь ЗОРИУДААР: нэр солих нь ховор
  /// бөгөөд эмзэг үйлдэл тул тусад нь нэрлэж, grep-ээр олдохоор байлгав.
  PublicPlayer renamed(String newName) => PublicPlayer(
        id: id,
        name: newName,
        avatarId: avatarId,
        seat: seat,
        alive: alive,
        connected: connected,
        ready: ready,
        speaking: speaking,
        isBot: isBot,
      );
}

// ---------------------------------------------------------------------------
// Дохио (эмоци)
// ---------------------------------------------------------------------------

/// Тоглогчийн ДОХИО — ярианаас гадуурх харилцааны суваг.
///
/// ЯАГААД ХЭРЭГТЭЙ ВЭ: ангийн найман хүн нэг зэрэг ярихад хэн хэн рүү
/// «чи мафи» гэж байгаа нь алдагддаг. Хуруугаараа заасан дүр нь тэр
/// утгыг НЭГ агшинд, эргэлзээгүй дамжуулна.
///
/// ДҮРТЭЙ ХОЛБООГҮЙ: хэн ч аль ч дохиог хэрэглэж чадна. Хэрэв зарим
/// дохио зөвхөн зарим дүрд байвал ажиглагч тоглогч тэрхүү жагсаалтыг
/// хараад дүрийг таана — тоглоом үхнэ. Тиймээс энэ жагсаалт НЭГ бөгөөд
/// бүгдэд НЭГЭН АДИЛ.
abstract final class Emote {
  /// Тодорхой хүн рүү заана. ГАНЦ бай шаарддаг дохио.
  static const String point = 'point';

  /// Толгой дохих — «тийм».
  static const String yes = 'yes';

  /// Толгой сэгсрэх — «үгүй».
  static const String no = 'no';

  /// Мөр хавчих — «мэдэхгүй».
  static const String shrug = 'shrug';

  /// Гар өргөх — «би ярья».
  static const String hand = 'hand';

  /// Инээх.
  static const String laugh = 'laugh';

  static const List<String> all = <String>[point, yes, no, shrug, hand, laugh];

  static bool valid(String kind) => all.contains(kind);

  /// Хоёр дохионы ХАМГИЙН БАГА завсар (мс).
  ///
  /// Хязгаарлалт нь ЗӨВХӨН эелдэг байдлын төлөө биш: хязгааргүй бол нэг
  /// хүн секундэд 100 дохио илгээж, бусдын дэлгэц дээр бүх толгой
  /// чичирч, тоглоомыг ашиглах боломжгүй болгоно. Мөн бүх хүнд ИЖИЛ —
  /// хэн нэгэнд илүү түргэн зөвшөөрвөл тэр нь ялгарах тэмдэг болно.
  static const int minGapMs = 1200;
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
  ///
  /// Ачаалал: `{"playerId": "...", "token": "...", "name": "..."}`.
  ///
  /// ТҮЛХҮҮР ЯАГААД ХЭРЭГТЭЙ ВЭ: `roomState` нь тоглогч бүрийн `id`-г
  /// НИЙТЭД цацдаг (апп өөрийгөө таних, дахин холбогдоход хэрэгтэй).
  /// Хэрэв `hello` зөвхөн `playerId` шаарддаг байсан бол өрөөнд байгаа
  /// хэн ч бусдын дугаарыг хуулж, `hello` + `joinRoom` илгээхэд сервер
  /// «дахин холбогдов» гэж үзээд ТҮҮНИЙ `yourRole`-ыг буцаана. Ботод
  /// сокет байхгүй тул үүнийг хэн ч анзаарахгүй: найман суудлын бүх
  /// дүрийг чимээгүйхэн цуглуулж болно. (Гараар шалгасан: 7 ботын
  /// дүрийг бүгдийг нь гаргаж авсан.)
  ///
  /// Түлхүүр нь утсанд л үлдэнэ, хэзээ ч нийтлэгдэхгүй.
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

  /// Өрөөнд бот нэмэх. Ачаалал: `{"count": n}`.
  ///
  /// ЗӨВХӨН эзэн, ЗӨВХӨН лоббид. Тоог сервер хязгаарлана — апп «мянга
  /// нэм» гэж хэлсэн ч өрөөний багтаамжаас хэтрэхгүй.
  ///
  /// Апп нь ХЭДИЙГ л хэлнэ. Хэн болох, хаана суух, ямар дүр авахыг
  /// СЕРВЕР шийднэ — яг л хүний суудлыг апп сонгодоггүйтэй адил.
  static const String addBots = 'addBots';

  /// Сүүлчийн ботыг хасах. Ачаалал хоосон.
  static const String removeBot = 'removeBot';

  /// Өрөөний тохиргоо. Ачаалал: `{"key": "watcher", "on": true}`.
  ///
  /// ЗӨВХӨН эзэн, ЗӨВХӨН лоббид. ЯМАР ДҮРҮҮД тоглоомд байгаа нь
  /// НИЙТИЙН мэдээлэл (хүн бүр хөзрөө хараад л мэднэ) тул `roomState`-д
  /// цацагдана — нуух ёстой нь ХЭН аль дүртэй гэдэг.
  static const String setOption = 'setOption';

  /// Дохио гаргах. Ачаалал: `{"kind": "point", "targetSeat": n|null}`.
  ///
  /// `targetSeat` нь зөвхөн `point`-д утгатай. Бусад дохионд сервер
  /// үүнийг ҮЛ ТООМСОРЛОНО — «толгой дохисон, гэхдээ 4 дүгээр суудал
  /// руу» гэсэн нууц суваг үүсгэхгүйн тулд.
  static const String emote = 'emote';

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

  /// ШӨНИЙН ХУВИЙН МЭДЭЭЛЭЛ. ЗӨВХӨН түүнийг олж авсан хүнд.
  ///
  /// Хоёр дүр ашиглана:
  ///   • Мөрдөгч — `traceFound` / `traceNotFound`
  ///   • Ажиглагч — `watchSaw` (`params.seat`) / `watchNobody`
  ///
  /// Нэг суваг байгаа нь ЗОРИУДААР: мессежийн ТӨРӨЛ нь дүрийг хэлэх
  /// ёсгүй. Хэрэв Ажиглагчид тусдаа төрөл байсан бол сүлжээгээ
  /// ажиглаж буй хүн «энэ утас Ажиглагчийнх» гэж уншина.
  static const String investigateResult = 'investigateResult';

  /// Санал хураалтын явц.
  static const String voteState = 'voteState';

  /// Тоглолт дууслаа — энд л бүх дүр ил болно.
  static const String gameOver = 'gameOver';

  /// Нээлттэй өрөөнүүд.
  static const String roomList = 'roomList';

  /// Дууны серверт холбогдох түлхүүр. Үе шат бүрд шинэчлэгдэж болно.
  static const String voiceGrant = 'voiceGrant';

  /// Хасагдсан хүн зарлагдав. `{"seat": n|null}` — тэнцвэл `null`.
  static const String eliminated = 'eliminated';

  /// ЗӨВХӨН мафид: хамтрагч хэн рүү чиглэснийг харуулна.
  static const String mafiaPick = 'mafiaPick';

  /// Хэн нэг дохио гаргав. НИЙТИЙНХ — өрөөнд байгаа бүх хүн ЯГ үүнийг
  /// нүдээрээ харах ёстой тул нууцлах зүйлгүй.
  /// `{"seat": n, "kind": "point", "targetSeat": n|null}`.
  static const String emote = 'emote';

  /// Хүлээж авлаа. Агуулгагүй.
  static const String ack = 'ack';

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
  /// ХЭРЭГЛЭГДЭХГҮЙ — одоо давхардсан нэрийг дугаарлана (`uniqueName`).
  /// Тогтмолыг утасны хуучин хувилбартай тохирохын тулд үлдээв.
  static const String nameTaken = 'nameTaken';

  /// Нэр огт бичээгүй.
  static const String nameRequired = 'nameRequired';

  /// Нэр хэт богино.
  static const String nameTooShort = 'nameTooShort';

  /// «Зочин», «Бот 3» гэх мэт систем эзэмшдэг нэр.
  static const String nameReserved = 'nameReserved';
  /// `hello`-гийн түлхүүр буруу — өөр хүний дугаарыг нэхэж байна.
  static const String badToken = 'badToken';

  static const String rateLimited = 'rateLimited';
  static const String malformed = 'malformed';
}
