// Нэг тоглоомын өрөө — ЦЭВЭР ЛОГИК.
//
// `dart:io` БАЙХГҮЙ, сокет БАЙХГҮЙ, `DateTime.now()` БАЙХГҮЙ. Команд орж,
// хаяглагдсан мессеж гарна. Ингэснээр бүтэн тоглолтыг сүлжээгүйгээр,
// секундын дотор, давтагдахаар тестлэнэ.
//
// ДҮР ЭНД АМЬДАРНА. Утас руу хэзээ ч бүтнээр нь явахгүй:
//   • `Outbound.all(...)` — нийтийнх. Дүрийн ул мөр байж БОЛОХГҮЙ.
//   • `Outbound.one(...)` — хувийнх. Дүр зөвхөн ингэж явна.
// `test/room_test.dart` бүтэн тоглолт явуулж, нийтийн БҮХ мессежийг
// шалгаад дүр алдагдсан эсэхийг барина.

import 'dart:typed_data';

import 'package:engine/engine.dart' as eng;
import 'package:protocol/protocol.dart';

import 'bot_brain.dart';
import 'names.dart';
import 'outbound.dart';

/// Үе шат бүр хэдэн миллисекунд үргэлжлэх вэ.
///
/// Эдгээрийг СЕРВЕР эзэмшинэ. Утас өөрөө тоолвол цагаа хойшлуулсан хүн
/// илүү удаан бодох боломжтой болно.
abstract final class PhaseMs {
  static const int dealing = 6000;
  static const int nightFalls = 3000;
  static const int mafia = 30000;
  static const int doctor = 15000;
  static const int detective = 15000;
  static const int dawn = 6000;
  static const int day = 120000;
  static const int vote = 30000;
  static const int elimination = 5000;
}

const int kMinPlayers = 6;
const int kMaxPlayers = 14;

/// Тоглогчийн НУУЦ хэсэг. Энэ ангийн утга сүлжээнд ХЭЗЭЭ Ч бүтнээрээ гарахгүй.
class _Secret {
  _Secret(this.seat, this.role);
  final int seat;
  final eng.Role role;
}

/// Нэг өрөө.
class GameRoom {
  GameRoom({
    required this.code,
    required this.hostId,
    required Uint8List seed,
    this.isPublic = true,
  }) : _seed = seed;

  final String code;
  final bool isPublic;

  /// Өрөөг үүсгэсэн хүн. Гарвал дараагийн хүнд шилжинэ.
  PlayerId hostId;

  final Uint8List _seed;

  final Map<PlayerId, PublicPlayer> _players = <PlayerId, PublicPlayer>{};

  /// НУУЦ. Тоглолт эхэлмэгц дүүрнэ.
  final Map<PlayerId, _Secret> _secrets = <PlayerId, _Secret>{};
  final Map<int, PlayerId> _bySeat = <int, PlayerId>{};

  NetPhase _phase = NetPhase.lobby;
  int _phaseEndsAtMs = 0;

  eng.Setup? _setup;

  /// Тараалтаас гарсан тэнцэл тайлах эрэмбэ. Шөнө бүр ижил.
  List<int> _orderPerm = const <int>[];

  /// Өмнөх шөнөөс ДАМЖИХ төлөв.
  ///
  /// Эмчийн хоёр дүрэм — «хоёр шөнө дараалж нэг хүнийг эмчлэхгүй» ба
  /// «өөрийгөө нэг л удаа» — ЗӨВХӨН эдгээрээр ажилладаг. Сервер тэднийг
  /// хаядаг байсан тул онлайн тоглолтод хоёр дүрэм НЭГ Ч УДАА
  /// хэрэгжиж байгаагүй: эмч шөнө бүр өөрийгөө эмчилж болох байв.
  Map<int, int> _lastHeal = const <int, int>{};
  Map<int, int> _selfHealUsed = const <int, int>{};
  eng.NightState? _night;
  int _nightNo = 0;
  final List<eng.Intent> _intents = <eng.Intent>[];
  int _seq = 0;

  /// Хэн хэзээ сүүлд дохио гаргав (мс). Хурдны хязгаарт.
  final Map<PlayerId, int> _lastEmoteMs = <PlayerId, int>{};

  /// ДАХИН САНАЛ. Хоосон бол чөлөөт санал; эс бөгөөс зөвхөн эдгээр
  /// суудлын нэгийг сонгож болно.
  ///
  /// Өмнө нь тэнцвэл ХЭН Ч хасагдахгүй байв. Тэр нь зөв дүрэм боловч
  /// ширээнд «юу ч болсонгүй» гэсэн хоосон мэдрэмж үлдээдэг. Нэг удаа
  /// дахин санал авбал шийдвэр гарах магадлал өндөр, мөн хоёр
  /// нэрийн хооронд ХУРЦ маргаан үүснэ — тоглоомын хамгийн сайн хэсэг.
  List<int> _revoteSeats = const <int>[];

  List<int> get revoteSeats => _revoteSeats;

  /// Өдрийн санал хураалт: хэн хэн рүү.
  final Map<PlayerId, int> _votes = <PlayerId, int>{};

  eng.WinState _win = eng.WinState.none;

  /// Хиймэл тоглогчид. Хоосон бол өрөө бүхэлдээ хүнийх.
  final Map<PlayerId, BotSeat> _bots = <PlayerId, BotSeat>{};

  /// Ажиглагчтай тоглох уу. ЗӨВХӨН эзэн лоббид асаана.
  ///
  /// Нэг ИРГЭНИЙ суудлыг орлоно — мафийн тоо, балансын төсөв хоёулаа
  /// хөдлөхгүй.
  bool _optWatcher = false;

  bool get optWatcher => _optWatcher;

  /// Хотын даргатай тоглох уу.
  bool _optMayor = false;

  /// Манаачтай тоглох уу.
  bool _optVigilante = false;

  bool get optVigilante => _optVigilante;

  /// Манаач тус бүрийн үлдсэн сум, дараагийн шөнө гэмшлээсээ үхэх нар.
  /// Хоёулаа ШӨНӨӨС ШӨНӨД дамжина.
  Map<int, int> _bullets = const <int, int>{};
  Set<int> _remorse = const <int>{};

  bool get optMayor => _optMayor;

  /// Өөрийгөө ИЛЧИЛСЭН даргын суудлууд. НИЙТИЙН мэдээлэл.
  final Set<int> _revealed = <int>{};

  Set<int> get revealedSeats => Set<int>.unmodifiable(_revealed);

  /// Тухайн суудлын саналын ЖИН.
  ///
  /// Илчилсэн дарга гурав, бусад нэг. Сервер Л үүнийг мэднэ — апп
  /// тоолж харуулж болох ч эцсийн тоолол ЭНД болно.
  int voteWeightOf(int seat) => _revealed.contains(seat) ? 3 : 1;

  /// Ботын өрөөнд үе шатыг богиносгоно.
  ///
  /// Нэг өдөр-шөнийн бүтэн эргэлт 230 секунд. Ганцаараа туршиж байгаа
  /// хүн эргэлт тутамд дөрвөн минут хүлээж, «энэ горим эвдэрсэн» гэж
  /// дүгнэнэ.
  ///
  /// ЯАГААД БҮГД ҮЙЛДМЭГЦ ДУУСГАДАГГҮЙ ВЭ: `_enter` нь `endsInMs`-ыг
  /// НИЙТЭД илгээдэг. Эрт дуусвал «тэр дүр амьд бөгөөд үйлдсэн» гэдэг
  /// нь, бүтэн хугацаа явбал «тэр дүр үхсэн» гэдэг нь ил болно. Үе шатны
  /// урт нь ХЭН ЮУ ХИЙСНЭЭС хамаарч БОЛОХГҮЙ — яг энэ шалтгаанаар
  /// `_fillMissingIntents` оршдог. Тиймээс БҮХ үе шатыг ИЖИЛ хуваарьтай
  /// богиносгож, хуваарийг `start`-д НЭГ УДАА шийднэ.
  bool _fast = false;

  int _ms(int base) {
    if (!_fast) return base;
    final int cut = base ~/ 3;
    return cut < 2000 ? 2000 : cut;
  }

  // --- Уншигчид ------------------------------------------------------------

  NetPhase get phase => _phase;
  int get playerCount => _players.length;
  bool get inLobby => _phase == NetPhase.lobby;
  eng.WinState get win => _win;
  List<PublicPlayer> get players => _players.values.toList(growable: false);

  /// Тоглогчийн суудал. Тоглолт эхлээгүй бол `null`.
  ///
  /// Дууны хүрээнд «хэн ярьж байна» гэж бичихэд хэрэгтэй. Суудал нь
  /// НИЙТИЙН мэдээлэл (`PublicPlayer.seat`) тул үүнийг гаргах нь юу ч
  /// задлахгүй — дүрийг ХЭЗЭЭ Ч ингэж гаргахгүй.
  int? seatOf(PlayerId id) => _players[id]?.seat;

  /// Тестэд л хэрэгтэй — жинхэнэ урсгалд дүрийг ХЭЗЭЭ Ч ингэж уншихгүй.
  eng.Role? debugRoleOf(PlayerId id) => _secrets[id]?.role;

  /// Тэнцэл тайлах эрэмбэ. НУУЦ БИШ — `GAME_CREATED`-д ил бичигддэг
  /// (GDD-05). Тестэд серверийн хаядаг байсан эрэмбийг шалгана.
  List<int> get debugOrderPerm => _orderPerm;

  /// ЯГ ОДООГИЙН шөнийн эрэмбэ. Тестэд л хэрэгтэй: тараалтын эрэмбийг
  /// хадгалах нь хангалтгүй, түүнийг ХЭРЭГЛЭХ ёстой.
  List<int> get debugNightOrder => _night?.orderPerm ?? const <int>[];

  /// Манаачийн үлдсэн сум. Тестэд л хэрэгтэй.
  Map<int, int> get debugBullets => _bullets;

  /// Өмнөх шөнөөс дамжсан эмчийн төлөв. Тестэд л хэрэгтэй.
  Map<int, int> get debugLastHeal => _lastHeal;
  Map<int, int> get debugSelfHealUsed => _selfHealUsed;

  /// Тестэд л хэрэгтэй: ботын дугаарууд.
  List<PlayerId> get debugBotIds => _bots.keys.toList(growable: false);

  /// Тестэд л хэрэгтэй: бот ЮУ ХАРАХ вэ.
  ///
  /// `_botsTick` ЯГ ижил замаар байгуулдаг тул тест нь жинхэнэ урсгалыг
  /// шалгаж байна — өөр хувилбарыг биш.
  BotView debugBotView(PlayerId id) => _botView(_bots[id]!);

  Set<PlayerId> get _mafiaIds => _secrets.entries
      .where((MapEntry<PlayerId, _Secret> e) =>
          eng.factionOf(e.value.role) == eng.Faction.mafi &&
          (_players[e.key]?.alive ?? false))
      .map((MapEntry<PlayerId, _Secret> e) => e.key)
      .toSet();

  // --- Тухайн үе шатны дууны суваг -----------------------------------------

  /// СЕРВЕР шийднэ. Апп-д итгэвэл өөрчилсөн апп бүхнийг сонсоно.
  VoiceScope get voiceScope => switch (_phase) {
        NetPhase.day || NetPhase.vote => VoiceScope.everyone,
        NetPhase.nightMafia => VoiceScope.mafiaOnly,
        NetPhase.nightDoctor || NetPhase.nightDetective => VoiceScope.selfOnly,
        _ => VoiceScope.none,
      };

  /// Тухайн үе шатанд бие биенээ СОНСОХ ЁСТОЙ хүмүүс.
  ///
  /// Дууны серверт яг үүнийг дамжуулна. Жагсаалтад байхгүй хүнд дуу
  /// хүрэхгүй — чагнах ч боломжгүй.
  Set<PlayerId> get voiceMembers => switch (voiceScope) {
        VoiceScope.everyone => _players.values
            .where((PublicPlayer p) => p.alive)
            .map((PublicPlayer p) => p.id)
            .toSet(),
        VoiceScope.mafiaOnly => _mafiaIds,
        VoiceScope.selfOnly || VoiceScope.none => const <PlayerId>{},
      };

  // --- Командууд -----------------------------------------------------------

  List<Outbound> join(PlayerId id, String name, String avatarId,
      {bool isBot = false}) {
    final String clean = cleanName(name);

    if (_players.containsKey(id)) {
      // Дахин холбогдов — суудал, дүр нь хэвээр.
      _players[id] = _players[id]!.copyWith(connected: true);
      // ТОГЛОЛТ ЯВЖ БАЙХАД НЭР ХӨЛДӨНӨ. Эс бөгөөс үхсэн Батын дараа
      // мафи «Бат» болж, өдрийн яриа утгагүй болно.
      if (_phase == NetPhase.lobby &&
          nameProblem(clean, allowReserved: isBot) == null) {
        _players[id] = _players[id]!.renamed(uniqueName(
            clean, _takenKeys(except: id),
            allowReserved: isBot));
      }
      return <Outbound>[..._stateForAll(), ..._privateResend(id)];
    }

    if (_phase != NetPhase.lobby) {
      return <Outbound>[_err(id, ErrCode.gameInProgress)];
    }
    if (_players.length >= kMaxPlayers) {
      return <Outbound>[_err(id, ErrCode.roomFull)];
    }

    final String? bad = nameProblem(clean, allowReserved: isBot);
    if (bad != null) return <Outbound>[_err(id, bad)];

    _players[id] = PublicPlayer(
      id: id,
      // `allowReserved`-ыг ДАМЖУУЛНА. Үгүй бол `uniqueName` нь ботын
      // өөрийнх нь нэрийг «нөөцлөгдсөн» гэж үзээд «Бот 1» → «Бот 1 2»
      // болгоно.
      name: uniqueName(clean, _takenKeys(), allowReserved: isBot),
      avatarId: avatarId,
      isBot: isBot,
    );

    // ӨРӨӨ ХҮНГҮЙ ЭЗЭНТЭЙ ҮЛДЭЖ БОЛОХГҮЙ. Эзэн нь явсан, эсвэл зөвхөн
    // ботууд үлдсэн бол орж ирсэн анхны ХҮН эзэн болно — эс бөгөөс
    // `startGame` илгээх хүн байхгүй тул өрөө үүрд лоббид гацна.
    if (!isBot && (!_players.containsKey(hostId) || this.isBot(hostId))) {
      hostId = id;
    }
    return _stateForAll();
  }

  /// Одоо эзэлсэн бүх нэрийн ХАРЬЦУУЛАХ түлхүүр.
  ///
  /// Жагсаалтыг дуудах бүрд шинээр гаргана — 14-аас цөөн тоглогчтой тул
  /// хямд, бас `leave`-тэй хэзээ ч зөрөхгүй. `leave` нь тоглолт явж
  /// байхад тоглогчийг үлдээдэг тул тэдний нэр эзэлсэн хэвээр байна —
  /// яг зөв.
  Set<String> _takenKeys({PlayerId? except}) => _players.values
      .where((PublicPlayer p) => p.id != except)
      .map((PublicPlayer p) => nameKey(p.name))
      .toSet();

  bool has(PlayerId id) => _players.containsKey(id);

  bool isBot(PlayerId id) => _players[id]?.isBot ?? false;

  /// Ботыг тооцохгүй. `Hub.sweepEmpty` үүгээр өрөө хоосорсныг мэднэ.
  int get humanCount =>
      _players.values.where((PublicPlayer p) => !p.isBot).length;

  /// ЯГ ОДОО холбоотой байгаа хүн хэд вэ.
  ///
  /// `humanCount` нь тоглолт эхэлсний дараа гарсан хүнийг ч тоолдог
  /// (`leave` нь суудлыг үлдээдэг — эргэж орж болно). Тиймээс түүгээр
  /// цэвэрлэвэл сүүлчийн хүн нь тоглолт дунд гарсан өрөө ҮҮРД үлдэнэ.
  int get connectedHumans => _players.values
      .where((PublicPlayer p) => !p.isBot && p.connected)
      .length;

  /// Өрөөнд бот нэмнэ. ЗӨВХӨН эзэн, ЗӨВХӨН лоббид.
  ///
  /// Ботыг `_players` руу ШУУД бичихгүй, `join`-оор оруулна: тэгж байж
  /// лобби, багтаамж, нэрийн бүх шалгалт хэвээр ажиллана. Шууд бичвэл
  /// суудалгүй тоглогч үүсч, шөнө эхлэхэд `p.seat!` дээр сервер унана.
  List<Outbound> addBots(PlayerId by, int count) {
    if (by != hostId) return <Outbound>[_err(by, ErrCode.notHost)];
    if (_phase != NetPhase.lobby) {
      return <Outbound>[_err(by, ErrCode.gameInProgress)];
    }
    final int room = kMaxPlayers - _players.length;
    final int n = count < 0 ? 0 : (count > room ? room : count);
    for (int i = 0; i < n; i++) {
      // Давталт БҮРД дахин асууна: нэр бүртгэгдсэний дараа дараагийн
      // чөлөөт дугаар өөрчлөгдөнө.
      final int next = _nextBotNumber();
      if (next < 0) return <Outbound>[_err(by, ErrCode.roomFull)];
      final PlayerId id = _botId(next);
      // `join` алдаа буцаавал тэр нь БОТЫН хаягаар явна — ботод сокет
      // байхгүй тул чимээгүй алга болно. Тиймээс шалгаад эзэн рүү дахин
      // хаяглана, эс бөгөөс эзэн товч дараад юу ч болохгүйг хардаг.
      final List<Outbound> r =
          join(id, botName(next), 'punk_0${next % 9}', isBot: true);
      if (!has(id)) {
        return <Outbound>[
          for (final Outbound o in r)
            if (o.msg.type == S2C.error) Outbound.one(by, o.msg),
        ];
      }
      _bots[id] = BotSeat(id, eng.Rng(eng.streamKey(_seed, 'BOT:$next')));
      setReady(id, true);
    }
    return _stateForAll();
  }

  /// Сүүлчийн ботыг хасна.
  List<Outbound> removeBot(PlayerId by) {
    if (by != hostId) return <Outbound>[_err(by, ErrCode.notHost)];
    if (_phase != NetPhase.lobby) {
      return <Outbound>[_err(by, ErrCode.gameInProgress)];
    }
    PlayerId? last;
    for (final PublicPlayer p in _players.values) {
      if (p.isBot) last = p.id;
    }
    if (last == null) return const <Outbound>[];
    _players.remove(last);
    _bots.remove(last);
    return _stateForAll();
  }

  /// Дараагийн ЧӨЛӨӨТ ботын дугаар. Чөлөөт дугаар байхгүй бол `-1`.
  ///
  /// ХАРАГДАХ НЭРЭЭР ХАЙХГҮЙ. Өмнө нь `p.name == botName(n)` гэж хайдаг
  /// байв. Хоёр хүн «бот» гэж бичихэд `uniqueName` хоёр дахийг нь
  /// «бот 2» болгодог; дараа нь хоёрдугаар бот «Бот 2 2» болж нэрлэгдэх
  /// тул хайлт «Бот 2»-ыг ОЛОХОО БОЛЬЖ, дугаар 2 дээр ҮҮРД гацдаг байв
  /// — эзний «+ БОТ НЭМЭХ» товч чимээгүй үхнэ (гараар шалгахад 6 удаа
  /// дарахад нэг ч бот нэмэгдээгүй).
  ///
  /// Одоо ДУГААР (хаяг) ба НЭР хоёулаа чөлөөтэй эсэхийг шалгана.
  int _nextBotNumber() {
    final Set<String> taken = _takenKeys();
    for (int n = 1; n <= kMaxPlayers * 4; n++) {
      if (_players.containsKey(_botId(n))) continue;
      if (taken.contains(nameKey(botName(n)))) continue;
      return n;
    }
    return -1;
  }

  /// Ботын дугаарыг ӨРӨӨНИЙ ҮРЭЭС гаргана, КОДООС БИШ.
  ///
  /// Код нь нээлттэй өрөөний жагсаалтаар нийтэд ил явдаг.
  ///
  /// ГЭХДЭЭ ЭНЭ НЬ ХАНГАЛТГҮЙ: `roomState` нь тоглогч бүрийн `id`-г
  /// нийтэд цацдаг тул ботын дугаарыг ТААХ шаардлагагүй, зүгээр л
  /// хуулна. Жинхэнэ хамгаалалт нь `kBotIdPrefix`: сервер энэ
  /// угтвартай дугаарыг `hello`-д ХЭЗЭЭ Ч хүлээж авахгүй.
  PlayerId _botId(int n) {
    final List<int> key = eng.streamKey(_seed, 'BOTID:$n');
    final String hex =
        key.take(8).map((int b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '$kBotIdPrefix$hex';
  }

  List<Outbound> leave(PlayerId id) {
    if (!_players.containsKey(id)) return const <Outbound>[];
    if (_phase == NetPhase.lobby) {
      _players.remove(id);
      _secrets.remove(id);
    } else {
      // Тоглолт явж байхад суудал нь үлдэнэ — эргэж орж болно.
      _players[id] = _players[id]!.copyWith(connected: false);
    }
    // ЭЗЭН ХЭЗЭЭ Ч БОТ БОЛОХГҮЙ. Ботод сокет байхгүй тул `startGame`
    // илгээхгүй, өрөө үүрд лоббид гацна (`start` нь зөвхөн эзнийх).
    if (id == hostId) {
      for (final PublicPlayer p in _players.values) {
        if (!p.isBot) {
          hostId = p.id;
          break;
        }
      }
    }
    return _stateForAll();
  }

  /// Өрөөний тохиргоо. ЗӨВХӨН эзэн, ЗӨВХӨН лоббид.
  List<Outbound> setOption(PlayerId by, String key, bool on) {
    if (by != hostId) return <Outbound>[_err(by, ErrCode.notHost)];
    if (_phase != NetPhase.lobby) {
      return <Outbound>[_err(by, ErrCode.gameInProgress)];
    }
    switch (key) {
      case 'watcher':
        _optWatcher = on;
      case 'mayor':
        _optMayor = on;
      case 'vigilante':
        _optVigilante = on;
      default:
        return const <Outbound>[];
    }
    return _stateForAll();
  }

  List<Outbound> setReady(PlayerId id, bool ready) {
    final PublicPlayer? p = _players[id];
    if (p == null || _phase != NetPhase.lobby) return const <Outbound>[];
    _players[id] = p.copyWith(ready: ready);
    return _stateForAll();
  }

  List<Outbound> start(PlayerId id, int nowMs) {
    if (id != hostId) return <Outbound>[_err(id, ErrCode.notHost)];
    if (_phase != NetPhase.lobby) {
      return <Outbound>[_err(id, ErrCode.gameInProgress)];
    }
    if (_players.length < kMinPlayers) {
      return <Outbound>[_err(id, ErrCode.tooFewPlayers)];
    }
    _fast = _players.values.any((PublicPlayer p) => p.isBot);
    return _deal(nowMs);
  }

  /// Шөнийн үйлдэл. Аль үе шат мөн бол тухайн дүр л илгээж чадна.
  List<Outbound> nightAction(PlayerId id, int targetSeat, int nowMs) {
    final _Secret? me = _secrets[id];
    final PublicPlayer? p = _players[id];
    if (me == null || p == null || !p.alive) {
      return <Outbound>[_err(id, ErrCode.notYourTurn)];
    }
    if (!_mayActNow(me.role)) {
      return <Outbound>[_err(id, ErrCode.notYourTurn)];
    }
    final eng.NightState? s = _night;
    if (s == null) return <Outbound>[_err(id, ErrCode.notYourTurn)];

    final eng.Ability ability = eng.abilityOf(me.role);
    final eng.Intent intent = eng.Intent(
      intentId: '${code}_${_nightNo}_${me.seat}_${_seq++}',
      night: _nightNo,
      actor: me.seat,
      ability: ability,
      target: targetSeat,
      clientSeq: _seq,
      submittedAtMs: nowMs,
    );
    // Хөдөлгүүрээр шалгуулна — сервер өөрөө дүрэм зохиохгүй.
    //
    // ШАЛТГААНЫГ ДАМЖУУЛНА. Өмнө нь бүх татгалзал `invalidTarget` болж
    // нэгддэг байсан тул Манаач «сум дууссан» ба «энэ хүнийг сонгож
    // болохгүй» хоёрыг ялгаж чадахгүй байв.
    final eng.RejectCode? why = eng.validate(intent, s);
    if (why != null) {
      return <Outbound>[_err(id, _rejectText(why))];
    }
    _intents
      ..removeWhere((eng.Intent i) =>
          i.actor == me.seat && i.ability == ability && i.night == _nightNo)
      ..add(intent);

    // Ботын санах ойг ЯГ ЭНД бичнэ. Санах ой нь утас руу явсан зүйлээс
    // хэтэрч болохгүй тул бичлэгийг мессеж гарах цэгт нь холбоно.
    final BotSeat? bot = _bots[id];
    if (bot != null) {
      if (ability == eng.Ability.heal) bot.mem.lastHeal = targetSeat;
      if (ability == eng.Ability.investigate) {
        bot.mem.lastCheck = targetSeat;
        bot.mem.checked.add(targetSeat);
      }
    }

    // Мафи хоорондоо сонголтоо ХАРНА — хамтдаа шийдэх нь тэдний давуу тал.
    if (ability == eng.Ability.mafiaKill) {
      return <Outbound>[
        Outbound.to(
          _mafiaIds,
          Envelope(S2C.mafiaPick, <String, Object?>{
            'bySeat': me.seat,
            'targetSeat': targetSeat,
          }),
        ),
      ];
    }
    return <Outbound>[_ack(id)];
  }

  List<Outbound> vote(PlayerId id, int? targetSeat) {
    final PublicPlayer? p = _players[id];
    if (p == null || !p.alive || _phase != NetPhase.vote) {
      return <Outbound>[_err(id, ErrCode.notYourTurn)];
    }
    if (targetSeat == null) {
      _votes.remove(id);
    } else {
      final PlayerId? target = _bySeat[targetSeat];
      if (target == null || !(_players[target]?.alive ?? false)) {
        return <Outbound>[_err(id, ErrCode.invalidTarget)];
      }
      // ДАХИН САНАЛ: зөвхөн тэнцсэн хоёрын нэг.
      if (_revoteSeats.isNotEmpty && !_revoteSeats.contains(targetSeat)) {
        return <Outbound>[_err(id, ErrCode.invalidTarget)];
      }
      _votes[id] = targetSeat;
    }
    return <Outbound>[_voteState()];
  }

  /// ӨДРИЙН үйлдэл. Одоогоор ганц: дарга өөрийгөө илчилнэ.
  ///
  /// НЭГ УДАА, БУЦААХГҮЙ. Илчилсэн хүн мафийн эхний бай болно — тэр нь
  /// эрсдэл; хариуд нь түүний санал гурав болно. Тэр солилцоо нь дүрийн
  /// бүх утга учир тул «буцаах» товч байж БОЛОХГҮЙ.
  List<Outbound> dayAction(PlayerId id, String kind, int nowMs) {
    final PublicPlayer? p = _players[id];
    final _Secret? me = _secrets[id];
    if (p == null || me == null || !p.alive) {
      return <Outbound>[_err(id, ErrCode.notYourTurn)];
    }
    // ӨДӨР эсвэл САНАЛ ХУРААЛТЫН үед. Санал хураалтын дундуур илчлэх нь
    // тоглоомын хамгийн хурц мөч — түүнийг хаах шалтгаан байхгүй.
    if (_phase != NetPhase.day && _phase != NetPhase.vote) {
      return <Outbound>[_err(id, ErrCode.notYourTurn)];
    }
    if (kind != 'reveal') return const <Outbound>[];
    if (me.role != eng.Role.mayor) {
      return <Outbound>[_err(id, ErrCode.notYourAbility)];
    }
    if (!_revealed.add(me.seat)) {
      return <Outbound>[_err(id, ErrCode.notYourTurn)];
    }
    return <Outbound>[
      Outbound.all(Envelope(S2C.voteWeight, <String, Object?>{
        'seat': me.seat,
        'weight': voteWeightOf(me.seat),
      })),
      ..._stateForAll(),
      if (_phase == NetPhase.vote) _voteState(),
    ];
  }

  /// Дохио (эмоци) гаргах.
  ///
  /// НИЙТИЙНХ: өрөөнд байгаа бүх хүн үүнийг НҮДЭЭРЭЭ харах ёстой зүйл
  /// тул `Outbound.all`. Дүрийн ул мөр агуулахгүй — `kind` нь бүх
  /// тоглогчид нээлттэй НЭГ жагсаалтаас гарна (`Emote.all`).
  ///
  /// Буруу хүсэлтэд алдаа БУЦААХГҮЙ, чимээгүй хаяна. Алдааны хариу нь
  /// «яагаад болохгүй байна» гэдгээр дамжуулан үе шат, амьд эсэхийг
  /// тандах суваг болно.
  List<Outbound> emote(PlayerId id, String kind, int? targetSeat, int nowMs) {
    final PublicPlayer? p = _players[id];
    if (p == null || !p.alive || p.seat == null) return const <Outbound>[];
    if (!_emotesAllowed || !Emote.valid(kind)) return const <Outbound>[];

    // Хурдны хязгаар. БҮХ хүнд ИЖИЛ — хэн нэгэнд илүү түргэн зөвшөөрвөл
    // тэр нь ялгарах тэмдэг болно.
    final int? last = _lastEmoteMs[id];
    if (last != null && nowMs - last < Emote.minGapMs) {
      return const <Outbound>[];
    }
    _lastEmoteMs[id] = nowMs;

    // Бай нь ЗӨВХӨН заалтад утгатай. Бусад дохионы бай чимээгүй
    // хаягдана: «толгой дохилоо, гэхдээ 4 руу» гэсэн нууц суваг
    // үүсгэхгүйн тулд.
    int? at;
    if (kind == Emote.point && targetSeat != null && targetSeat != p.seat) {
      final PlayerId? who = _bySeat[targetSeat];
      if (who != null && (_players[who]?.alive ?? false)) at = targetSeat;
    }
    return <Outbound>[
      Outbound.all(Envelope(S2C.emote, <String, Object?>{
        'seat': p.seat,
        'kind': kind,
        'targetSeat': at,
      })),
    ];
  }

  /// Дохио зөвшөөрөгдөх үе шатууд.
  ///
  /// ШӨНӨ ЗӨВШӨӨРӨХГҮЙ. Шөнө бүх дэлгэц харанхуй, хүн бүр «унтсан»
  /// байх ёстой. Хэрэв тэр үед дохио дамжвал «энэ хүн сэрүүн байна»
  /// гэдэг нь ил болж, мафи хэн болох нь тэр дороо тодорно. Энэ бол
  /// гоо сайхны биш, ТОГЛООМЫН шийдвэр.
  bool get _emotesAllowed =>
      _phase == NetPhase.dawn ||
      _phase == NetPhase.day ||
      _phase == NetPhase.vote ||
      _phase == NetPhase.elimination;

  /// Цаг хэмжигч. Сервер үүнийг тогтмол дуудна.
  List<Outbound> tick(int nowMs) {
    if (_phase == NetPhase.lobby || _phase == NetPhase.gameOver) {
      return const <Outbound>[];
    }
    // БОТУУД ЭХЛЭЭД — үе шат урагшлахаас ӨМНӨ. Эс бөгөөс сүүлийн tick
    // дээр ирсэн ботын үйлдэл аль хэдийн өөр үе шатанд буух тул
    // `notYourTurn` болно.
    final List<Outbound> out = _botsTick(nowMs);
    if (nowMs < _phaseEndsAtMs) return out;
    return <Outbound>[...out, ..._advance(nowMs)];
  }

  /// Хугацаа нь болсон ботуудыг үйлдүүлнэ.
  ///
  /// Ботыг ЗӨВХӨН ЦАГ сэрээнэ — ирсэн мессеж сэрээдэггүй. Тиймээс хоёр
  /// мафи бот бие биенийхээ сонголтод хариу үйлдэж, нэг tick дотор
  /// хязгааргүй давтагдах боломж БАЙХГҮЙ.
  List<Outbound> _botsTick(int nowMs) {
    if (_bots.isEmpty) return const <Outbound>[];
    final List<BotSeat> due =
        _bots.values.where((BotSeat b) => b.due(nowMs)).toList()
          ..sort((BotSeat a, BotSeat b) => a.seat.compareTo(b.seat));
    if (due.isEmpty) return const <Outbound>[];

    final List<Outbound> out = <Outbound>[];
    for (final BotSeat b in due) {
      b.acted = true;
      final BotCommand? c = decideBot(_botView(b), b.rng);
      // ЖИНХЭНЭ ХААЛГААР ордог. `_intents` рүү шууд бичвэл хөдөлгүүрийн
      // шалгалт болон давхардал арилгах алхам алгасагдаж, нэг суудал
      // хоёр санаатай болж N22 инвариант эвдэрнэ.
      switch (c) {
        case BotNight(:final int targetSeat):
          out.addAll(nightAction(b.id, targetSeat, nowMs));
        case BotVote(:final int targetSeat):
          out.addAll(vote(b.id, targetSeat));
        case BotEmote(:final String kind, :final int? targetSeat):
          out.addAll(emote(b.id, kind, targetSeat, nowMs));
        case BotReveal():
          out.addAll(dayAction(b.id, 'reveal', nowMs));
        case null:
          break;
      }
    }

    // Дохио нь ТУСДАА хуваарьтай: гол үйлдэл нь шөнө, дохио нь өдөр
    // болдог тул нэг цонхонд багтахгүй. Мөн дохиогүй бол бот нь
    // хөшсөн харагдаж, «энэ бол бот» гэдэг нь нэг харцаар тодорно.
    for (final BotSeat b in _bots.values.toList()
      ..sort((BotSeat a, BotSeat c) => a.seat.compareTo(c.seat))) {
      if (!b.dueEmote(nowMs)) continue;
      b.emoted = true;
      final BotEmote? em = decideEmote(_botView(b), b.rng);
      if (em != null) out.addAll(emote(b.id, em.kind, em.targetSeat, nowMs));
    }
    return out;
  }

  /// Бот ЮУ ХАРАХ вэ.
  ///
  /// ЭНЭ ФУНКЦ Л нууцад хүрнэ, тэр ч ЗӨВХӨН ӨӨРИЙНХӨД НЬ. Өөр суудлын
  /// `_secrets` рүү хандахгүй. Тархи нь `BotView`-ээс өөр юу ч хардаггүй
  /// тул бусдын дүр түүнд хүрэх зам БАЙХГҮЙ.
  BotView _botView(BotSeat b) {
    final _Secret me = _secrets[b.id]!;
    final bool mafi = eng.factionOf(me.role) == eng.Faction.mafi;

    final List<int> alive = _players.values
        .where((PublicPlayer p) => p.alive && p.seat != null)
        .map((PublicPlayer p) => p.seat!)
        .toList()
      ..sort();

    // Хамтрагчийн сонголт — өрөө үүнийг `mafiaPick`-ээр мафид аль хэдийн
    // илгээдэг. Мафи биш бот энд ХООСОН авна.
    final Map<int, int> picks = <int, int>{};
    if (mafi) {
      for (final eng.Intent i in _intents) {
        final int? t = i.target;
        if (t != null &&
            i.night == _nightNo &&
            i.ability == eng.Ability.mafiaKill) {
          picks[i.actor] = t;
        }
      }
    }

    final Map<int, int> votes = <int, int>{};
    for (final MapEntry<PlayerId, int> e in _votes.entries) {
      final int? s = _players[e.key]?.seat;
      if (s != null) votes[s] = e.value;
    }

    return BotView(
      mySeat: me.seat,
      myRole: me.role,
      phase: _phase,
      aliveSeats: alive,
      myAllies: mafi
          ? _mafiaIds
              .where((PlayerId id) => id != b.id)
              .map((PlayerId id) => _players[id]?.seat)
              .whereType<int>()
              .toSet()
          : const <int>{},
      allyPicks: picks,
      liveVotes: votes,
      iAmRevealed: _revealed.contains(me.seat),
      voteCandidates: _revoteSeats,
      night: _nightNo,
      mem: b.mem,
    );
  }

  // --- Дотоод урсгал -------------------------------------------------------

  bool _mayActNow(eng.Role r) => switch (_phase) {
        // МАНААЧ мафитай НЭГ үе шатанд буудна: хоёулаа 100-р хувинд,
        // хоёулаа «энэ шөнө хэн үхэх вэ» гэсэн асуултыг хариулна.
        // Дуут суваг нь мафийнх хэвээр тул Манаач тэднийг СОНСОХГҮЙ.
        NetPhase.nightMafia => eng.factionOf(r) == eng.Faction.mafi ||
            r == eng.Role.vigilante,
        NetPhase.nightDoctor => r == eng.Role.doctor,
        // Ажиглагч нь МӨРДӨГЧТЭЙ НЭГ үе шатанд сэрнэ.
        //
        // Дүр бүрд тусдаа үе шат нэмэх нь хоёр зүйлийг эвдэнэ: шөнө
        // уртсаж (63 сек → 108), мөн нийтэд цацагдах үе шатны жагсаалт
        // нь тоглоомд ЯМАР ДҮРҮҮД байгаагийн тоолол болно. Хоёулаа
        // «харах» дүр тул нэг хувинд (130) багтана.
        NetPhase.nightDetective =>
          r == eng.Role.detective || r == eng.Role.watcher,
        _ => false,
      };

  List<Outbound> _deal(int nowMs) {
    final int n = _players.length;
    final eng.Roster roster = eng.rosterFor(n,
        watcher: _optWatcher, mayor: _optMayor, vigilante: _optVigilante);
    final List<eng.Role> deck = eng.deckFor(roster);

    final eng.DealResult d = eng.deal(
      seed0: _seed,
      userEntropy: Uint8List.fromList(code.codeUnits),
      n: n,
      deck: deck,
      holderSeat: 1,
    );

    // Суудлыг тогтмол дарааллаар өгнө — орсон дараалал.
    final List<PlayerId> ids = _players.keys.toList();
    for (int i = 0; i < ids.length; i++) {
      final int seat = i + 1;
      final eng.Role role = d.roleBySeat[seat]!;
      _secrets[ids[i]] = _Secret(seat, role);
      _bySeat[seat] = ids[i];
      _players[ids[i]] = _players[ids[i]]!.copyWith(seat: seat, alive: true);
    }

    // МАНААЧИЙН СУМ. Шөнө бүр `NightState`-д дамжина.
    _bullets = <int, int>{
      for (final _Secret sec in _secrets.values)
        if (sec.role == eng.Role.vigilante) sec.seat: eng.kVigilanteBullets,
    };
    _remorse = const <int>{};

    for (final BotSeat b in _bots.values) {
      b.seat = _secrets[b.id]?.seat ?? -1;
    }

    _setup = eng.Setup(n: n, roleBySeat: d.roleBySeat);
    // ТЭНЦЭЛ ТАЙЛАХ ЭРЭМБЭ. Өмнө нь шөнө бүр `[1..n]` гэж ЗОХИОДОГ
    // байв — тэр нь тараалтын үрийг бүхэлд нь хаяна. Үр дагавар нь
    // жижиг мэт боловч ТОГЛООМЫН ШУДАРГА БАЙДАЛ: хоёр мафи өөр хүн
    // сонговол `pickVictim` тэнцлийг ЭРЭМБЭЭР тайлдаг (resolve.dart
    // §430) тул 1-р суудал үргэлж ялдаг болно. Эрэмбэ нь `GAME_CREATED`
    // -д ИЛ бичигддэг тул нууцлах зүйл байхгүй — зүгээр л ашиглах ёстой.
    _orderPerm = d.orderPerm;
    _nightNo = 0;
    _win = eng.WinState.none;

    final List<Outbound> out = <Outbound>[];
    _enter(NetPhase.dealing, nowMs, _ms(PhaseMs.dealing), out);

    // ДҮРИЙГ ЗӨВХӨН ЭЗЭНД НЬ. Мафид хамтрагчдынх нь суудлыг ч өгнө.
    for (final MapEntry<PlayerId, _Secret> e in _secrets.entries) {
      final bool isMafia = eng.factionOf(e.value.role) == eng.Faction.mafi;
      out.add(Outbound.one(
        e.key,
        Envelope(S2C.yourRole, <String, Object?>{
          'seat': e.value.seat,
          'role': e.value.role.name,
          'faction': isMafia ? 'mafi' : 'hotynhon',
          if (isMafia)
            'allySeats': _secrets.values
                .where((_Secret s) =>
                    eng.factionOf(s.role) == eng.Faction.mafi &&
                    s.seat != e.value.seat)
                .map((_Secret s) => s.seat)
                .toList()
              ..sort(),
        }),
      ));
    }
    return out;
  }

  List<Outbound> _advance(int nowMs) {
    final List<Outbound> out = <Outbound>[];
    switch (_phase) {
      case NetPhase.dealing:
        _beginNight(nowMs, out);

      case NetPhase.nightFalls:
        _enter(NetPhase.nightMafia, nowMs, _ms(PhaseMs.mafia), out);

      case NetPhase.nightMafia:
        _enter(NetPhase.nightDoctor, nowMs, _ms(PhaseMs.doctor), out);

      case NetPhase.nightDoctor:
        _enter(NetPhase.nightDetective, nowMs, _ms(PhaseMs.detective), out);

      case NetPhase.nightDetective:
        _resolveNight(nowMs, out);

      case NetPhase.dawn:
        if (_win != eng.WinState.none) {
          _finish(nowMs, out);
        } else {
          _enter(NetPhase.day, nowMs, _ms(PhaseMs.day), out);
        }

      case NetPhase.day:
        _votes.clear();
        _revoteSeats = const <int>[];
        _enter(NetPhase.vote, nowMs, _ms(PhaseMs.vote), out);

      case NetPhase.vote:
        _tallyAndEliminate(nowMs, out);

      case NetPhase.elimination:
        if (_win != eng.WinState.none) {
          _finish(nowMs, out);
        } else {
          _beginNight(nowMs, out);
        }

      case NetPhase.lobby:
      case NetPhase.gameOver:
        break;
    }
    return out;
  }

  /// Хөдөлгүүрийн татгалзлыг протоколын кодод буулгана.
  ///
  /// Ихэнх нь `invalidTarget` руу нийлнэ — тоглогчид «энэ хүнийг
  /// сонгож болохгүй» гэхээс өөр мэдээлэл ХЭРЭГГҮЙ, бас өгөх ёсгүй:
  /// «энэ хүн үхсэн» гэж хэлэх нь үхлийг баталгаажуулж өгнө.
  static String _rejectText(eng.RejectCode c) => switch (c) {
        eng.RejectCode.chargeSpent => ErrCode.chargeSpent,
        eng.RejectCode.nightTooEarly => ErrCode.nightTooEarly,
        _ => ErrCode.invalidTarget,
      };

  /// Тухайн суудал энэ шөнө ХЭНИЙГ сонгосон бэ.
  ///
  /// Чадвараар шүүхгүй: инвариант N22-оор амьд суудал бүр шөнөдөө ЯГ
  /// НЭГ санаа илгээдэг тул үйлдэгчээр хайхад хангалттай. Чадвараар
  /// шүүх нь дүр нэмэх бүрд өргөжих жагсаалт болно — Ажиглагч нэмэхэд
  /// түүний хариу нь суудалгүй явж эхэлсэн байх байв.
  int? _askedSeat(int actorSeat) {
    for (final eng.Intent i in _intents) {
      if (i.actor == actorSeat && i.night == _nightNo) return i.target;
    }
    return null;
  }


  void _beginNight(int nowMs, List<Outbound> out) {
    _nightNo++;
    _intents.clear();
    _night = eng.NightState(
      setup: _setup!,
      night: _nightNo,
      alive: _players.values
          .where((PublicPlayer p) => p.alive)
          .map((PublicPlayer p) => p.seat!)
          .toSet(),
      seed: _seed,
      orderPerm: _orderPerm.isEmpty
          ? List<int>.generate(_setup!.n, (int i) => i + 1)
          : _orderPerm,
      lastHealTarget: _lastHeal,
      selfHealUsed: _selfHealUsed,
      revealedMayors: _revealed,
      bullets: _bullets,
      remorse: _remorse,
    );
    _enter(NetPhase.nightFalls, nowMs, _ms(PhaseMs.nightFalls), out);
  }

  /// Хөдөлгүүрийн N22 инвариант: АМЬД СУУДАЛ БҮР яг нэг санаа илгээнэ.
  ///
  /// Энэ нь нэг утасны хувилбарын «жигд хуурмаг» — суудал бүр утсыг ижил
  /// хугацаанд барьдаг тул хэн ч цагаар нь дүрийг таахгүй. Онлайнд иргэд
  /// шөнө үйлддэггүй, эмч, мөрдөгч ч заримдаа сонголт хийхгүй өнгөрдөг.
  /// Тиймээс дутуу санааг СЕРВЕР `noAction`-оор нөхнө — эс бөгөөс хөдөлгүүр
  /// зогсоно.
  void _fillMissingIntents() {
    final eng.NightState s = _night!;
    for (final int seat in s.alive) {
      final bool acted = _intents.any((eng.Intent i) => i.actor == seat);
      if (acted) continue;
      _intents.add(eng.Intent(
        intentId: '${code}_${_nightNo}_${seat}_auto',
        night: _nightNo,
        actor: seat,
        ability: eng.Ability.noAction,
        target: null,
        clientSeq: 0,
        submittedAtMs: 0,
      ));
    }
  }

  void _resolveNight(int nowMs, List<Outbound> out) {
    _fillMissingIntents();
    final eng.NightReport r = eng.resolveNight(_night!, _intents);
    // ДАМЖИХ ТӨЛӨВИЙГ ХАДГАЛНА. Хөдөлгүүр үүнийг тооцоод буцаадаг ч
    // сервер хаядаг байв.
    _lastHeal = r.nextLastHeal;
    _selfHealUsed = r.nextSelfHealUsed;
    _bullets = r.nextBullets;
    _remorse = r.nextRemorse;

    for (final eng.Death d in r.deaths) {
      final PlayerId? victim = _bySeat[d.victim];
      if (victim != null) {
        _players[victim] = _players[victim]!.copyWith(alive: false);
      }
      for (final BotSeat b in _bots.values) {
        b.mem.nightVictims.add(d.victim);
      }
    }
    _win = r.win;

    // Мөрдөгчийн хариу — ЗӨВХӨН ТҮҮНД. Хөдөлгүүр өөрөө хаяглачихсан.
    for (final MapEntry<int, List<eng.Msg>> e in r.privateMsgs.entries) {
      final PlayerId? who = _bySeat[e.key];
      if (who == null) continue;
      // ХЭНИЙГ асуусныг ТУХАЙН ШӨНИЙН САНААНААС уншина.
      //
      // Өмнө нь ботын САНАХ ОЙгоос уншдаг байв (`b?.mem.lastCheck`).
      // Тэр нь ботод ажиллаж, ХҮНД ажиллахгүй: хүн мөрдөгчид
      // `_bots[who]` нь `null` тул `targetSeat` нь үргэлж хоосон явдаг
      // байв — яг тэр алдааг «зассан» гэж бичсэн хэрнээ. Мөн энэ нь
      // буруу тал руугаа: ботын мэдлэг нь мессежээс БИШ, серверийн
      // дотоод төлөвөөс гардаг болно.
      //
      // Одоо хоёулаа НЭГ эх сурвалжтай: ботын санах ой нь утас руу
      // явсан мессежийн ТУСГАЛ.
      final int? asked = _askedSeat(e.key);
      for (final eng.Msg m in e.value) {
        final BotSeat? b = _bots[who];
        if (b != null && asked != null) {
          if (m.code == eng.MsgCode.traceFound) {
            b.mem.traceFound.add(asked);
          } else {
            b.mem.traceNotFound.add(asked);
          }
        }
        out.add(Outbound.one(
          who,
          Envelope(S2C.investigateResult, <String, Object?>{
            // ХЭНИЙГ асуусныг буцаана. Хөдөлгүүрийн хариу нь зөвхөн
            // «олдсон/олдсонгүй» гэдгийг хэлдэг тул суудалгүй бол
            // мөрдөгч хүн ч, бот ч хариуг нь хэнд хамаатуулахаа мэдэхгүй.
            'targetSeat': asked,
            'code': m.code.name,
            'params': m.params,
          }),
        ));
      }
    }

    // Шивнээ нь НИЙТИЙНХ — ботын санах ойд ч бичигдэнэ. Энэ нь шинэ
    // суваг нээхгүй: яг ижил тоо бүх утас руу явна.
    for (final BotSeat b in _bots.values) {
      b.mem.whispered.addAll(r.whisper);
    }
    out.add(Outbound.all(Envelope(S2C.nightResult, <String, Object?>{
      'night': _nightNo,
      'deaths': r.deaths.map((eng.Death d) => d.victim).toList(),
      'whisper': r.whisper,
    })));
    _enter(NetPhase.dawn, nowMs, _ms(PhaseMs.dawn), out);
  }

  void _tallyAndEliminate(int nowMs, List<Outbound> out) {
    // Ботууд өдрийн саналыг САНАНА — энэ нь нийтэд явсан мэдээлэл
    // (`_voteState`), тиймээс тэдний мэдлэг хүнийхээс хэтрэхгүй.
    if (_bots.isNotEmpty) {
      final Map<int, int> bySeat = <int, int>{};
      for (final MapEntry<PlayerId, int> e in _votes.entries) {
        final int? s = _players[e.key]?.seat;
        if (s != null) bySeat[s] = e.value;
      }
      for (final BotSeat b in _bots.values) {
        b.mem.lastDayVotes
          ..clear()
          ..addAll(bySeat);
      }
    }

    // ЖИНТЭЙ тоолол. Илчилсэн дарга гурван санал.
    final Map<int, int> tally = <int, int>{};
    for (final MapEntry<PlayerId, int> e in _votes.entries) {
      final int? from = _players[e.key]?.seat;
      if (from == null) continue;
      tally[e.value] = (tally[e.value] ?? 0) + voteWeightOf(from);
    }
    int? outSeat;
    List<int> tied = const <int>[];
    if (tally.isNotEmpty) {
      final int top = tally.values.reduce((int a, int b) => a > b ? a : b);
      tied = tally.entries
          .where((MapEntry<int, int> e) => e.value == top)
          .map((MapEntry<int, int> e) => e.key)
          .toList()
        ..sort();
      if (tied.length == 1) outSeat = tied.first;
    }

    // ТЭНЦВЭЛ НЭГ УДАА ДАХИН САНАЛ АВНА.
    //
    // Санамсаргүй сонголт хийхгүй — «апп шийдчихлээ» гэсэн мэдрэмж
    // тоглоомыг үхүүлнэ. Харин тэнцсэн нэрсийн хооронд дахин санал
    // авах нь ширээнд ХУРЦ маргаан үүсгэдэг бөгөөд шийдвэр гарах
    // магадлалыг өсгөнө. Хоёр дахь тэнцэлд хэн ч хасагдахгүй.
    if (outSeat == null && tied.length >= 2 && _revoteSeats.isEmpty) {
      _revoteSeats = tied;
      _votes.clear();
      out.add(Outbound.all(Envelope(S2C.eliminated, <String, Object?>{
        'seat': null,
        'tally': tally.map((int k, int v) => MapEntry<String, int>('$k', v)),
        'revote': tied,
      })));
      _enter(NetPhase.vote, nowMs, _ms(PhaseMs.vote), out);
      out.add(_voteState());
      return;
    }
    _revoteSeats = const <int>[];

    if (outSeat != null) {
      final PlayerId? id = _bySeat[outSeat];
      if (id != null) _players[id] = _players[id]!.copyWith(alive: false);
    }
    _recomputeWin();

    out.add(Outbound.all(Envelope(S2C.eliminated, <String, Object?>{
      'seat': outSeat,
      'tally': tally.map((int k, int v) => MapEntry<String, int>('$k', v)),
    })));
    _enter(NetPhase.elimination, nowMs, _ms(PhaseMs.elimination), out);
  }

  /// Өдрийн хасалтын дараа ялалт шалгах.
  ///
  /// Хөдөлгүүрийн `resolveNight` нь ШӨНИЙН дараа шалгадаг. Өдрийн хасалт
  /// нь түүний гадна болдог тул ижил дүрмийг энд хэрэглэнэ.
  void _recomputeWin() {
    // ХӨДӨЛГҮҮРЭЭС АСУУНА, энд дахин бичихгүй.
    //
    // Өмнө нь ижил дүрэм хоёр газар бичигдсэн байв. Илчилсэн дарга
    // гэх мэт тэнцлийг өөрчилдөг дүр нэмэгдэхэд тэр хоёр нь чимээгүй
    // салж, өдрийн хасалтын дараа өөр, шөнийн дараа өөр хариу гарна.
    final Set<int> alive = _players.values
        .where((PublicPlayer p) => p.alive && p.seat != null)
        .map((PublicPlayer p) => p.seat!)
        .toSet();
    final eng.WinState w = eng.evaluateWin(alive, _setup!,
        revealedMayors: _revealed);
    if (w != eng.WinState.none) _win = w;
  }

  void _finish(int nowMs, List<Outbound> out) {
    _phase = NetPhase.gameOver;
    _phaseEndsAtMs = nowMs;
    // ЭНД Л бүх дүр ил болно — тоглолт дууссаны дараа.
    out.add(Outbound.all(Envelope(S2C.gameOver, <String, Object?>{
      'winner': _win.name,
      'reveal': _secrets.map((PlayerId k, _Secret v) =>
          MapEntry<String, Object?>('${v.seat}', v.role.name)),
    })));
  }

  void _enter(NetPhase p, int nowMs, int ms, List<Outbound> out) {
    _phase = p;
    _phaseEndsAtMs = nowMs + ms;
    for (final BotSeat b in _bots.values) {
      b.schedule(nowMs, ms);
    }
    out
      ..add(Outbound.all(Envelope(S2C.phase, <String, Object?>{
        'phase': p.name,
        'endsInMs': ms,
      })))
      ..addAll(_stateForAll())
      ..addAll(_voiceGrants());
  }

  /// Дууны эрхийг ХҮН БҮРД ТУСАД НЬ илгээнэ.
  ///
  /// ЯАГААД НИЙТЭД БИШ: өмнө нь үе шатын нийтийн мессежид `voice: mafiaOnly`
  /// гэж явж байв. Тэр нь хэн мафи болохыг хэлэхгүй ч иргэнд хэрэггүй
  /// мэдээлэл — түүнд зөвхөн «чи одоо ярьж чадахгүй» гэж хэлэх ёстой.
  /// Хувиар илгээснээр аппад «бусад хэн ярьж байна» гэсэн мэдээлэл огт
  /// хүрэхгүй, өөрчилсөн апп ч гэсэн олох юмгүй болно.
  List<Outbound> _voiceGrants() {
    final Set<PlayerId> members = voiceMembers;
    return _players.values.map((PublicPlayer p) {
      final bool can = members.contains(p.id);
      return Outbound.one(
        p.id,
        Envelope(S2C.voiceGrant, <String, Object?>{
          // Ярьж чадах уу — микрофон нээх эсэх.
          'canSpeak': can,
          // Хэдэн хүнтэй нэг сувагт байна. Нэрсийг илгээхгүй: мафи хэн
          // болохыг тоогоор ч гэсэн таахгүй байхын тулд зөвхөн өөрийн
          // сувгийнхаа хэмжээг мэднэ.
          // Ботыг ТООЦОХГҮЙ: ботод сокет байхгүй тул түүнийг тоолвол
          // хүн байхгүй хоолойг хүлээж суух болно. Гэхдээ бот нь
          // `voiceMembers` дотор ҮЛДЭНЭ — дамжуулах зам байт тутмаараа
          // хэвээр байх ёстой.
          'channelSize': can
              ? members
                  .where((PlayerId m) => !(_players[m]?.isBot ?? false))
                  .length
              : 0,
        }),
      );
    }).toList();
  }

  // --- Мессеж бүтээгчид ----------------------------------------------------

  List<Outbound> _stateForAll() => <Outbound>[
        Outbound.all(Envelope(S2C.roomState, <String, Object?>{
          'code': code,
          'phase': _phase.name,
        // ЯМАР ДҮРҮҮД тоглоомд байна — НИЙТИЙН мэдээлэл. ХЭН аль дүртэй
        // гэдэг нь нууц; тэр хоёр огт өөр зүйл. Ширээн дээр мафи
        // тоглохдоо бүрэлдэхүүнээ үргэлж чангаар зарладаг.
        //
        // Анхдагчаас ГАДУУР нэмэгдсэн дүрүүдийг л жагсаана. Энэ талбар
        // нь дүрийн НЭР агуулдаг цорын ганц нийтийн талбар тул
        // алдагдлын тест түүнийг ТУСАД НЬ, цагаан жагсаалтаар шалгана.
        'setupRoles': <String>[
          if (_optWatcher) eng.Role.watcher.name,
          if (_optMayor) eng.Role.mayor.name,
          if (_optVigilante) eng.Role.vigilante.name,
        ],
        // Илчилсэн суудлууд — НИЙТИЙНХ. Дүрийн нэр агуулахгүй, зөвхөн
        // суудлын дугаар.
        'revealed': _revealed.toList()..sort(),
          'hostId': hostId,
          'isPublic': isPublic,
          'players':
              _players.values.map((PublicPlayer p) => p.toJson()).toList(),
        })),
      ];

  /// Дахин холбогдсон хүнд ХУВИЙН мэдээллийг нь эргүүлж өгнө.
  List<Outbound> _privateResend(PlayerId id) {
    final _Secret? s = _secrets[id];
    if (s == null) return const <Outbound>[];
    final bool isMafia = eng.factionOf(s.role) == eng.Faction.mafi;
    return <Outbound>[
      Outbound.one(
        id,
        Envelope(S2C.yourRole, <String, Object?>{
          'seat': s.seat,
          'role': s.role.name,
          'faction': isMafia ? 'mafi' : 'hotynhon',
          // ХАМТРАГЧИЙГ БАС ЭРГҮҮЛЖ ӨГНӨ. Эс бөгөөс сүлжээ тасарч
          // дахин орсон мафи хамтрагчаа үүрд мартаж, шөнө тус тусдаа
          // санал өгч, алалт нь тэнцэж, шөнө санамсаргүй харагдана.
          if (isMafia)
            'allySeats': _secrets.values
                .where((_Secret o) =>
                    eng.factionOf(o.role) == eng.Faction.mafi &&
                    o.seat != s.seat)
                .map((_Secret o) => o.seat)
                .toList()
              ..sort(),
        }),
      ),
    ];
  }

  Outbound _voteState() => Outbound.all(
        Envelope(S2C.voteState, <String, Object?>{
          'votes': _votes.map((PlayerId k, int v) =>
              MapEntry<String, Object?>(_secrets[k]?.seat.toString() ?? k, v)),
          // Жинтэй тоолол — апп өөрөө тоолохгүй. Илчилсэн дарга байхад
          // «гурван санал» гэдгийг ширээн дээр ХАРАХ ёстой.
          'weights': <String, Object?>{
            for (final int s in _revealed) '$s': voteWeightOf(s),
          },
          // Хоосон бол чөлөөт санал. Эс бөгөөс ЗӨВХӨН эдгээрээс.
          'candidates': _revoteSeats,
        }),
      );

  Outbound _err(PlayerId id, String code) =>
      Outbound.one(id, Envelope(S2C.error, <String, Object?>{'code': code}));

  Outbound _ack(PlayerId id) =>
      Outbound.one(id, const Envelope(S2C.ack, <String, Object?>{}));

  /// Нэр — 1..16 тэмдэгт, эхний ба сүүлийн зай авна.
}
