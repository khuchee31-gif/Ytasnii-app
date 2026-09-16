// Тоглолтын төлөвийн машин — GDD-01 §1-ийн 19 төлөв.
//
// ЭНЭ БОЛ ГЭРЭЭ. Дэлгэцүүд үүнийг УНШИНА, өөрсдөө дүрэм шийдэхгүй.
// Хөдөлгүүрийн шийдвэрийг (хэн үхэв, хэн шивнэгдэв, хэн ялав) `packages/engine`
// гаргана; энэ класс зөвхөн ДАРААЛЛЫГ хариуцна.
//
// Хатуу дүрэм:
//   • Дүрийн хуваарилалтыг дэлгэц рүү бүтнээр нь хэзээ ч гаргахгүй (GDD-10 §3).
//     `roleOf(seat)` нь зөвхөн тухайн суудлын ээлжинд дуудагдана.
//   • Санамсаргүй тоо зөвхөн ЭНД (`seed0`) үүснэ, хөдөлгүүрт хэзээ ч биш.
//   • Цаг хэмжигч нь тарааж өгөгдөнө (`TickerFactory`) — тестэд хуурамчаар солино.

import 'dart:async';
import 'dart:math' show Random;

import 'package:engine/engine.dart';
import 'package:flutter/foundation.dart';

import 'phase.dart';
import 'settings.dart';

/// Цаг хэмжигчийг тарааж өгөх — тестэд жинхэнэ цаг хүлээхгүйн тулд.
typedef TickerFactory = Timer Function(Duration, void Function(Timer));

class GameController extends ChangeNotifier {
  GameController({TickerFactory? ticker}) : _ticker = ticker ?? _defaultTicker;

  static Timer _defaultTicker(Duration d, void Function(Timer) cb) =>
      Timer.periodic(d, cb);

  final TickerFactory _ticker;
  Timer? _timer;

  // --- Төлөв ---------------------------------------------------------------
  GamePhase _phase = GamePhase.appOpen;
  GamePhase? _pausedFrom;
  GamePhase get phase => _phase;
  bool get isPaused => _phase == GamePhase.paused;

  // --- Тохиргоо ------------------------------------------------------------
  int seatCount = 12;

  /// Дүрмийн тохиргоо — GDD-03. Дэлгэц энд байгаа утгыг УНШИНА (Бүлэг А).
  final GameSettings settings = GameSettings();

  /// S02-ын нэрс. Нэр ЗААВАЛ БИШ — хоосон бол `{n}-р тоглогч` (GDD-06 S02).
  final Map<Seat, String> seatNames = <Seat, String>{};

  /// Суудлын дэлгэцийн нэр. Хоосон нэрийг дэлгэц өөрөө бөглөнө.
  String seatLabel(Seat s) {
    final String? name = seatNames[s];
    return (name == null || name.trim().isEmpty) ? '$s-р тоглогч' : name.trim();
  }

  /// S01-ийн `hasRoster` төлөв — суудлын жагсаалт хадгалагдсан эсэх.
  bool hasSavedRoster = false;

  /// GDD-11 §2: эхний гурван тоглолт зөөлөн, S03-ын хөтлөгчийн холбоос
  /// `gamesPlayed == 0` үед л харагдана.
  int gamesPlayed = 0;

  /// S03-ын чипээр ГАРААР өөрчилсөн бүрэлдэхүүн. `null` бол GDD-04 §2-ын
  /// анхдагч хүснэгт. (Бүлэг А-ийн нэмэлт — `roster` getter-ийн цорын ганц
  /// өөрчлөлт.)
  Roster? _customRoster;
  Roster get roster => _customRoster ?? rosterFor(seatCount);

  /// S03 «Тараая» дарахад чипүүдийн утгыг бүртгэнэ.
  void setComposition(Roster r) {
    _customRoster = r;
    seatCount = r.n;
    notifyListeners();
  }

  /// Анхдагч хүснэгт рүү буцаана (суудлын тоо солигдоход).
  void clearComposition() {
    _customRoster = null;
    notifyListeners();
  }

  SetupCheck get setupCheck => checkSetup(
    n: roster.n,
    mafia: roster.mafia,
    boss: roster.boss,
    doctor: roster.doctor,
    detective: roster.detective,
  );

  // --- Хуваарилалт ---------------------------------------------------------
  DealResult? _deal;
  Setup? _setup;
  DealResult? get dealResult => _deal;
  String get fairCode => _deal?.fairCode ?? '';
  Seat get readerSeat => _deal?.readerSeat ?? 1;

  /// Хөзрөө аль хэдийн харсан суудлууд (GDD-06 S06-ийн `seenMask`).
  final Set<Seat> seen = <Seat>{};

  /// Суудал тутам хэдэн удаа дахин харсан — ил тоологдоно (GDD-10 §6).
  final Map<Seat, int> reviewCount = <Seat, int>{};

  /// ЗӨВХӨН тухайн суудлын ээлжинд дуудна. Бүх дүрийг жагсаах API байхгүй.
  Role? roleOf(Seat s) => _setup?.roleOf(s);

  // --- Шөнө ----------------------------------------------------------------
  NightState? _night;
  NightState? get night => _night;
  int get nightNo => _night?.night ?? 0;

  /// Эргэлтийн одоогийн суудлын индекс (`orderPerm` биш — СУУДЛЫН дугаараар,
  /// GDD-01 §1: «эргэлтийн дараалал = суудлын дугаар»).
  int _circuitIndex = 0;
  final List<Intent> _intents = <Intent>[];

  List<Seat> get circuitSeats =>
      List<Seat>.generate(seatCount, (int i) => i + 1);
  Seat? get currentSeat =>
      _circuitIndex < circuitSeats.length ? circuitSeats[_circuitIndex] : null;
  bool get circuitDone => _circuitIndex >= circuitSeats.length;

  NightReport? _report;
  NightReport? get report => _report;

  // --- Өдөр ----------------------------------------------------------------
  int dayNo = 0;
  Set<Seat> alive = <Seat>{};
  final Set<Seat> nominations = <Seat>{};
  final Map<Seat, int> hands = <Seat, int>{};
  final List<({int dayNo, int elapsedMs, Seat speaker})> pins =
      <({int dayNo, int elapsedMs, Seat speaker})>[];
  Seat? lastEliminated;

  /// S18 «Бүжигт хүлэг» — тоглолтоос ХАМГИЙН ТҮРҮҮНД гарсан суудал(ууд).
  /// Эхний шөнө хоёр хохирогч гарвал хоёулаа энд орно (GDD-06 S18 `tie`).
  final List<Seat> firstOutSeats = <Seat>[];

  /// «№7 · Шөнө 1» гэсэн мөрийн хоёр дахь хэсэг.
  String firstOutWhenMn = '';

  /// Нэг л удаа бичигдэнэ — хоёр дахь хасалт үүнийг дарж бичихгүй.
  void _recordFirstOut(List<Seat> seats, String whenMn) {
    if (firstOutSeats.isNotEmpty || seats.isEmpty) return;
    firstOutSeats.addAll(seats);
    firstOutWhenMn = whenMn;
  }

  /// Эхний шөнийн хохирогч — «Шилдэг нүүдэл» түүнд л олдоно (GDD-01 §1, №10).
  Seat? firstVictim;
  bool bestMoveSpoken = false;

  /// «Алдаж болох санал» — дүрийг ХЭЗЭЭ Ч уншихгүй (GDD-05 §9.4).
  int get pips => pipsForDay(roster.n, roster.mafia, dayNo == 0 ? 1 : dayNo);

  /// Үгийн тойргийн дараалал — GDD-01 §1, №11: суудлын дугаараар, Өдөр 1-д
  /// №1-ээс, дараа нь СҮҮЛД ХАСАГДСАНЫ дараагийн суудлаас.
  List<Seat> get speechOrder {
    final List<Seat> live = alive.toList()..sort();
    final Seat? last = lastEliminated;
    if (live.isEmpty || last == null || dayNo <= 1) return live;
    final int i = live.indexWhere((Seat s) => s > last);
    if (i <= 0) return live;
    return <Seat>[...live.sublist(i), ...live.sublist(0, i)];
  }

  WinState get win =>
      _setup == null ? WinState.none : evaluateWin(alive, _setup!);

  // --- Цаг -----------------------------------------------------------------
  int _secondsLeft = 0;
  int get secondsLeft => _secondsLeft;

  void startCountdown(int seconds, {VoidCallback? onDone}) {
    _timer?.cancel();
    _secondsLeft = seconds;
    notifyListeners();
    _timer = _ticker(const Duration(seconds: 1), (Timer t) {
      _secondsLeft--;
      if (_secondsLeft <= 0) {
        t.cancel();
        _secondsLeft = 0;
        onDone?.call();
      }
      notifyListeners();
    });
  }

  void stopCountdown() {
    _timer?.cancel();
    _timer = null;
  }

  // --- Шилжилтүүд ----------------------------------------------------------

  void go(GamePhase next) {
    stopCountdown();
    _phase = next;
    notifyListeners();
  }

  void pause() {
    if (_phase == GamePhase.paused) return;
    _pausedFrom = _phase;
    stopCountdown();
    _phase = GamePhase.paused;
    notifyListeners();
  }

  void resume() {
    if (_pausedFrom == null) return;
    _phase = _pausedFrom!;
    _pausedFrom = null;
    notifyListeners();
  }

  /// `FAIRNESS` — `seed0` энд төрнө (GDD-10 §2, алхам 1).
  /// Хуваарилалт хараахан хийгдэхгүй: код эхлээд цаасан дээр бичигдэнэ.
  /// [seed0] нь ЗӨВХӨН тестэд дамжуулагдана — жинхэнэ тоглолтод
  /// `Random.secure()` ажиллана. Тогтоосон seed нь тоглолтыг бүрэн
  /// давтагдахуйц болгоно (GDD-10 §10-ын golden вектортой ижил зарчим).
  void beginFairness({Seat holderSeat = 1, Uint8List? seed0}) {
    final Random rnd = Random.secure();
    _pendingSeed0 =
        seed0 ??
        Uint8List.fromList(List<int>.generate(32, (_) => rnd.nextInt(256)));
    _pendingHolder = holderSeat;
    // Код нь `seed0`-оос л гарна, сэгсрэлтээс хамаарахгүй — тиймээс ЭНД мэдэгдэнэ.
    _previewCode = fairnessCode(sha256(_pendingSeed0!));
    go(GamePhase.fairness);
  }

  Uint8List? _pendingSeed0;
  Seat _pendingHolder = 1;
  String? _previewCode;
  String get previewCode => _previewCode ?? '';

  // --- Тараахаас ӨМНӨ мэдэгддэг зүйлс (GDD-10 §2, алхам 2) -----------------
  //
  // `_deal` хараахан БАЙХГҮЙ — S04 нь кодыг, уншигч суудлыг, `dealId`-г
  // хуваарилалтаас ӨМНӨ гаргах ёстой. Тэр гурав нь бүгд `h0 = sha256(seed0)`
  // -оос гарна, сэгсрэлтээс хамаарахгүй.

  Uint8List? get _h0 => _pendingSeed0 == null ? null : sha256(_pendingSeed0!);

  /// Утас барьсан суудал — уншигчийг сонгохоос ХАСАГДАНА.
  Seat get holderSeat => _pendingHolder;

  /// Кодыг чангаар уншиж, дэвтэрт бичих суудал — тараахаас ӨМНӨ мэдэгдэнэ.
  /// Тараалтын дараа `readerSeat`-тай яг тэнцүү (нэг `h0`, нэг `holderSeat`).
  Seat get previewReaderSeat {
    final Uint8List? h = _h0;
    if (h == null) return _pendingHolder == 1 ? 2 : 1;
    return readerSeatOf(h, seatCount, holderSeat: _pendingHolder);
  }

  /// `dealId` — 8 hex, бүх дэлгэцийн доод мөрөнд (GDD-10 §2).
  String get previewDealId {
    final Uint8List? h = _h0;
    return h == null ? '' : dealIdOf(h);
  }

  /// Танилцах шөнийг гурван товшилтоор таслав уу (GDD-06 S07).
  /// Дэвтэрт бичигдэнэ — GDD-00 §13-ын 8-р асуулт яг үүнийг хэмжинэ.
  bool meetCutShort = false;

  /// Сэгсрэлт ирсний дараа л хуваарилна (GDD-10 §2, алхам 6-7).
  void dealWithEntropy(Uint8List userEntropy) {
    final Roster r = roster;
    final DealResult d = deal(
      seed0: _pendingSeed0!,
      userEntropy: userEntropy,
      n: r.n,
      deck: deckFor(r),
      holderSeat: _pendingHolder,
    );
    _deal = d;
    _setup = Setup(
      n: r.n,
      roleBySeat: d.roleBySeat,
      factionRule: r.boss
          ? FactionRule.designatedKiller
          : FactionRule.mafiaMajority,
    );
    alive = <Seat>{for (int i = 1; i <= r.n; i++) i};
    seen.clear();
    reviewCount.clear();
    dayNo = 0;
    firstVictim = null;
    firstOutSeats.clear();
    firstOutWhenMn = '';
    bestMoveSpoken = false;
    pins.clear();
    go(GamePhase.deal);
  }

  void markSeen(Seat s) {
    if (seen.contains(s)) {
      reviewCount.update(s, (int v) => v + 1, ifAbsent: () => 1);
    }
    seen.add(s);
    notifyListeners();
  }

  bool get allSeen => seen.length >= seatCount;

  void beginNight() {
    _night = NightState(
      setup: _setup!,
      night: (_night?.night ?? 0) + 1,
      alive: alive,
      seed: _deal!.seed,
      orderPerm: _deal!.orderPerm,
      lastHealTarget: _report?.nextLastHeal ?? const <Seat, Seat>{},
      selfHealUsed: _report?.nextSelfHealUsed ?? const <Seat, int>{},
    );
    _intents.clear();
    _circuitIndex = 0;
    go(GamePhase.nightCircuit);
  }

  /// Тухайн суудлын санааг бүртгэнэ. Хасагдсан суудал ч утсыг барина —
  /// гэхдээ түүний санаа `noAction` болно (жигд хуурмаг, GDD-10 §4).
  void submitIntent(Seat actor, Ability ability, Seat? target) {
    final NightState s = _night!;
    final bool isAlive = s.alive.contains(actor);
    if (isAlive) {
      // Хүчингүй бай ирвэл `noAction` болгож буулгана. Хөдөлгүүр хүчингүй
      // санааг ЧИМЭЭГҮЙ хаядаг тул шууд нэмбэл тэр суудал огт санаа
      // илгээгээгүй болж, инвариант N22 унана («амьд суудал бүр шөнө бүр
      // ЯГ НЭГ санаа»). Дэлгэцийн алдаа тоглоомыг унагааж болохгүй.
      Intent candidate = Intent(
        intentId: 'n${s.night}-s$actor',
        night: s.night,
        actor: actor,
        ability: ability,
        target: target,
        clientSeq: 1,
      );
      if (ability != Ability.noAction && validate(candidate, s) != null) {
        candidate = Intent(
          intentId: 'n${s.night}-s$actor',
          night: s.night,
          actor: actor,
          ability: Ability.noAction,
          target: null,
          clientSeq: 1,
        );
      }
      _intents.add(candidate);
    }
    _circuitIndex++;
    notifyListeners();
  }

  /// Мөрдөгчийн хариу — товших мөчид, тэр дор нь (GDD-05 §9.1).
  Msg? previewInvestigation(Seat actor, Seat target) {
    final NightState s = _night!;
    if (abilityOf(_setup!.roleOf(actor)!) != Ability.investigate) return null;
    return infoAnswer(
      s,
      Intent(
        intentId: 'preview',
        night: s.night,
        actor: actor,
        ability: Ability.investigate,
        target: target,
        clientSeq: 1,
      ),
    );
  }

  /// Хууль ёсны бай мөн эсэх — дэлгэц үүнийг л асууна.
  RejectCode? checkTarget(Seat actor, Ability ability, Seat target) => validate(
    Intent(
      intentId: 'probe',
      night: _night!.night,
      actor: actor,
      ability: ability,
      target: target,
      clientSeq: 1,
    ),
    _night!,
  );

  void resolveNightNow() {
    final NightState s = _night!;
    final NightReport r = resolveNight(s, _intents);
    assert(() {
      checkInvariants(s, _intents, r);
      return true;
    }());
    _report = r;
    alive = Set<Seat>.of(r.aliveAfter);
    if (firstVictim == null && r.deaths.isNotEmpty) {
      firstVictim = r.deaths.first.victim;
    }
    _recordFirstOut(
      r.deaths.map((Death d) => d.victim).toList()..sort(),
      'Шөнө ${s.night}',
    );
    go(GamePhase.dawn);
  }

  void beginDay() {
    dayNo++;
    nominations.clear();
    hands.clear();
    go(GamePhase.speechRound);
  }

  void addPin(int elapsedMs, Seat speaker) {
    if (pins.length >= 12) return; // GDD-06: тоглолтод дээд тал нь 12
    pins.add((dayNo: dayNo, elapsedMs: elapsedMs, speaker: speaker));
    notifyListeners();
  }

  void nominate(Seat s) {
    if (!alive.contains(s)) return;
    nominations.add(s);
    notifyListeners();
  }

  /// Оператор буруу товшив — нэр дэвшүүлэлтийг буцаана (GDD-06 S14 `full`
  /// төлөвт гацахгүйн тулд). Санал хураалт эхэлсний дараа дуудагдахгүй.
  void denominate(Seat s) {
    if (nominations.remove(s)) notifyListeners();
  }

  void recordHands(Seat s, int count) {
    hands[s] = count;
    notifyListeners();
  }

  /// Тэнцлийн дараагийн тойрог — тоолол шинээр эхэлнэ (GDD-06 S16).
  void clearHands() {
    if (hands.isEmpty) return;
    hands.clear();
    notifyListeners();
  }

  /// `tieRule = Санамсаргүй` — апп сонгоно (GDD-03 §4.5). Санамсаргүй тоо
  /// ЗӨВХӨН энэ класст үүснэ, дэлгэцэд хэзээ ч биш.
  Seat randomTieBreak(List<Seat> tied) {
    if (tied.isEmpty) throw StateError('Тэнцсэн суудал байхгүй');
    return tied[Random.secure().nextInt(tied.length)];
  }

  /// Plurality. Тэнцвэл `null` — тэнцлийн гинжийг дэлгэц шийднэ (GDD-03).
  Seat? get voteWinner {
    if (hands.isEmpty) return null;
    final int best = hands.values.reduce((int a, int b) => a > b ? a : b);
    final List<Seat> top = hands.entries
        .where((MapEntry<Seat, int> e) => e.value == best)
        .map((MapEntry<Seat, int> e) => e.key)
        .toList();
    return top.length == 1 ? top.first : null;
  }

  void eliminate(Seat s) {
    alive.remove(s);
    lastEliminated = s;
    _recordFirstOut(<Seat>[s], 'Өдөр $dayNo');
    go(GamePhase.elimination);
  }

  /// «Бүгдийн хувь заяа» — тэнцсэн БҮГД гарна (GDD-01 §1, GDD-06 S16).
  void eliminateAll(Iterable<Seat> seats) {
    final List<Seat> out = seats.where(alive.contains).toList()..sort();
    if (out.isEmpty) return;
    alive.removeAll(out);
    lastEliminated = out.last;
    _recordFirstOut(out, 'Өдөр $dayNo');
    go(GamePhase.elimination);
  }

  /// `WIN_CHECK` — хасалт бүрийн ДАРАА шууд (GDD-01 §1, №17).
  void checkWin() {
    if (win != WinState.none) {
      go(GamePhase.ceremony);
    } else {
      beginNight();
    }
  }

  void reset() {
    stopCountdown();
    _customRoster = null;
    _deal = null;
    _setup = null;
    _night = null;
    _report = null;
    _intents.clear();
    seen.clear();
    reviewCount.clear();
    alive.clear();
    nominations.clear();
    hands.clear();
    pins.clear();
    dayNo = 0;
    _circuitIndex = 0;
    firstVictim = null;
    firstOutSeats.clear();
    firstOutWhenMn = '';
    bestMoveSpoken = false;
    lastEliminated = null;
    meetCutShort = false;
    _phase = GamePhase.appOpen;
    notifyListeners();
  }

  @override
  void dispose() {
    stopCountdown();
    super.dispose();
  }
}
