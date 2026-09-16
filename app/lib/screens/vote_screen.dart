// S14 «Нэр дэвшүүлэлт» · S15 «Өмгөөлөл» · S16 «Гар өргөх»
// (GDD-06 §S14–S16, GDD-01 §1-ийн 13–15-р мөр, GDD-03 §4.5-ын тэнцлийн гинж).
//
// САНАЛ ХУРААЛТ УТСАН ДОТОР БАЙХГҮЙ. Хөтлөгч нэр дэвшигчийг дуудна, ширээ
// гараа өргөнө, оператор ТООГ оруулна. Энэ нь онлайн бүтээгдэхүүнд бүтцийн
// хувьд оршин байх боломжгүй цорын ганц механик (GDD-00 §4) — тиймээс энд
// суудал сонгодог саналын дэлгэцийн бүтэн гэр бүл БАЙХГҮЙ, ганц арк байна.
//
// `Цаазлах` гэсэн үг энэ файлд БАЙХГҮЙ — «Хотоос хөөх» (GDD-00 §11).
//
// ГАР УТАС: S16 бол НЭГ ГАРЫН дэлгэц, зориуд — утас барьсан хүн нөгөө
// гараараа өөрөө гараа өргөж байна. Арк доод булангаас эрхийгээр татагдана,
// `Тохиргоо → Зүүн гар` асаалттай бол доод ЗҮҮН булан болж эргэнэ.

import 'dart:async';
import 'dart:math' as math;

import 'package:engine/engine.dart' show Seat;
import 'package:flutter/material.dart' hide Intent;

import '../game/game_controller.dart';
import '../game/settings.dart';
import '../ui/tokens.dart';
import '../ui/widgets.dart';
import 'day_screen.dart' show TwoFingerSwipe, mmss;
import '../ui/glyphs.dart';

/// Нэг өдөрт дээд тал нь хэдэн нэр дэвшигч (GDD-06 S14; 20 хүний
/// замбараагүй байдлыг зогсооно).
const int kMaxNominations = 3;

/// `defenceSeconds` — GDD-03-д ЦАРЦСАН. Тоо нь `DEFENCE_OPEN` клипэд
/// бичигдсэн («Тоглогч тутамд хорин секунд») тул дэлгэц зөрч чадахгүй.
const int kDefenceSeconds = 20;

/// Тэнцсэн хүн бүрийн нэмэлт үг (GDD-03 §4.5, ФСМ).
const int kTieSpeechSeconds = 30;

/// Нэр дэвшигч хооронд.
const Duration kNomineeGap = Duration(milliseconds: 1200);

/// `SEAT_nn` → `VOTE_ASK` (GDD-07 §2.8).
const Duration kVoteAskGap = Duration(milliseconds: 300);

/// Батлах нь ДАРЖ-ДҮҮРГЭХ, товшилт БИШ (GDD-06 S16).
const Duration kDialConfirmHold = Duration(milliseconds: 600);

/// Аркны шүдний тоо — 0..20.
const int kDialMax = 20;

enum VoteStage {
  /// S14
  nomination,

  /// S15 — зөвхөн Өдөр 2-оос хойш (GDD-01 §1, №14)
  defence,

  /// S16
  voting,

  /// Тэнцлийн 1-р салаа: тэнцсэн хүн бүр +30 сек
  tieSpeech,

  /// Тэнцлийн 3-р салаа: «бүгдийн хувь заяа» — ширээний ганц гар өргөлт
  allFate,
}

class VoteScreen extends StatefulWidget {
  const VoteScreen({
    super.key,
    required this.controller,
    required this.onExile,
    required this.onNoExile,
    this.onCue,
    this.startAt = VoteStage.nomination,
    this.startBallot = const <Seat>[],
  });

  final GameController controller;

  /// Хотоос хөөгдөх суудал(ууд) — S17 руу. «Бүгдийн хувь заяа» дээр олон.
  final void Function(List<Seat> exiled) onExile;

  /// Хэн ч хөөгдөхгүй — шөнө рүү (S08).
  final VoidCallback onNoExile;

  final void Function(String clipId)? onCue;

  /// Зөвхөн тестэд — урт урсгалын дунд шууд орох.
  @visibleForTesting
  final VoteStage startAt;
  @visibleForTesting
  final List<Seat> startBallot;

  @override
  State<VoteScreen> createState() => _VoteScreenState();
}

class _VoteScreenState extends State<VoteScreen> {
  late VoteStage _stage;
  late List<Seat> _ballot;

  /// Тэнцлийн хэддэх тойрог вэ (ФСМ: 1 → нэмэлт үг, 2 → бүгдийн хувь заяа).
  int _tieRound = 0;

  /// S15/S16-ийн одоогийн нэр дэвшигчийн индекс.
  int _at = 0;

  /// S15 ба tieSpeech-ийн тоолуур.
  int _secondsLeft = 0;
  bool _gap = false;

  /// S16-ийн арк.
  int _dial = 0;
  bool _asked = false;

  String? _notice;

  Timer? _tick;
  Timer? _gapTimer;
  Timer? _askTimer;
  Timer? _noticeTimer;

  GameController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    _stage = widget.startAt;
    _ballot = List<Seat>.of(widget.startBallot);
    switch (_stage) {
      case VoteStage.nomination:
        widget.onCue?.call('NOM_OPEN');
      case VoteStage.defence:
        _beginDefence();
      case VoteStage.voting:
        _beginVoting();
      case VoteStage.tieSpeech:
        _beginTieSpeech();
      case VoteStage.allFate:
        _beginAllFate();
    }
  }

  @override
  void dispose() {
    _tick?.cancel();
    _gapTimer?.cancel();
    _askTimer?.cancel();
    _noticeTimer?.cancel();
    super.dispose();
  }

  void _notice3s(String text) {
    _noticeTimer?.cancel();
    setState(() => _notice = text);
    _noticeTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _notice = null);
    });
  }

  // --- S14 ------------------------------------------------------------------

  void _toggleNomination(Seat s) {
    if (c.nominations.contains(s)) {
      // Оператор буруу товшив. Гурав дүүрсэн үед энэ бол ганц гарц.
      setState(() => c.denominate(s));
      return;
    }
    if (c.nominations.length >= kMaxNominations) return;
    setState(() => c.nominate(s));
    widget.onCue?.call('NOM_ADDED');
    widget.onCue?.call('SEAT_${s.toString().padLeft(2, '0')}');
  }

  void _closeNominations() {
    final List<Seat> nominees = c.nominations.toList()..sort();
    if (nominees.isEmpty) {
      widget.onCue?.call('NOM_NONE');
      widget.onNoExile();
      return;
    }
    widget.onCue?.call('NOM_CLOSED');

    // GDD-01 §1: Өдөр 1-д нэр дэвшигч ЯГ НЭГ бол санал хураахгүй.
    if (c.dayNo <= 1 && nominees.length == 1) {
      widget.onNoExile();
      return;
    }

    _ballot = nominees;
    // Өмгөөлөл зөвхөн Өдөр 2-оос хойш (GDD-01 §1, №14).
    if (c.dayNo >= 2) {
      setState(_beginDefence);
    } else {
      setState(_beginVoting);
    }
  }

  void _skipAll() {
    widget.onCue?.call('NOM_NONE');
    widget.onNoExile();
  }

  // --- S15 ------------------------------------------------------------------

  void _beginDefence() {
    _stage = VoteStage.defence;
    _at = 0;
    _secondsLeft = kDefenceSeconds;
    widget.onCue?.call('DEFENCE_OPEN');
    _callDefender();
    _startTick();
  }

  void _beginTieSpeech() {
    _stage = VoteStage.tieSpeech;
    _at = 0;
    _secondsLeft = kTieSpeechSeconds;
    widget.onCue?.call('VOTE_TIE_SPEECH');
    _startTick();
  }

  void _callDefender() {
    widget.onCue?.call('DEFENCE_NEXT');
    widget.onCue?.call('SEAT_${_ballot[_at].toString().padLeft(2, '0')}');
  }

  void _startTick() {
    _tick?.cancel();
    _tick = Timer.periodic(const Duration(seconds: 1), (Timer _) {
      if (!mounted || _gap) return;
      setState(() {
        _secondsLeft--;
        if (_secondsLeft == 10) widget.onCue?.call('UI_TICK_10');
        if (_secondsLeft <= 0) _nextSpeaker();
      });
    });
  }

  void _nextSpeaker() {
    final int total = _stage == VoteStage.defence
        ? kDefenceSeconds
        : kTieSpeechSeconds;
    if (_at + 1 >= _ballot.length) {
      _tick?.cancel();
      if (_stage == VoteStage.defence) widget.onCue?.call('DEFENCE_END');
      _beginVoting();
      return;
    }
    // 1.2 секундын завсар — дараагийн нэр дэвшигч.
    _gap = true;
    _gapTimer = Timer(kNomineeGap, () {
      if (!mounted) return;
      setState(() {
        _gap = false;
        _at++;
        _secondsLeft = total;
        if (_stage == VoteStage.defence) _callDefender();
      });
    });
  }

  /// Хоёр хуруугаар шудрав — шууд S16 руу.
  void _skipSpeeches() {
    if (_stage != VoteStage.defence && _stage != VoteStage.tieSpeech) return;
    _tick?.cancel();
    _gapTimer?.cancel();
    _gap = false;
    if (_stage == VoteStage.defence) widget.onCue?.call('DEFENCE_END');
    setState(_beginVoting);
  }

  // --- S16 ------------------------------------------------------------------

  void _beginVoting() {
    _tick?.cancel();
    _stage = VoteStage.voting;
    _at = 0;
    _dial = 0;
    c.clearHands();
    widget.onCue?.call('VOTE_OPEN');
    _askCurrent();
  }

  void _askCurrent() {
    _asked = false;
    widget.onCue?.call('SEAT_${_ballot[_at].toString().padLeft(2, '0')}');
    _askTimer?.cancel();
    _askTimer = Timer(kVoteAskGap, () {
      if (!mounted) return;
      setState(() => _asked = true);
      widget.onCue?.call('VOTE_ASK');
    });
  }

  int get _maxHands => _stage == VoteStage.allFate
      ? c.alive.length
      : math.max(0, c.alive.length - 1);

  bool get _tooMany => _dial > _maxHands;

  void _confirmDial() {
    if (_tooMany) return;
    if (_stage == VoteStage.allFate) {
      _resolveAllFate(_dial);
      return;
    }
    c.recordHands(_ballot[_at], _dial);
    widget.onCue?.call('VOTE_COUNT_OK');
    if (_at + 1 >= _ballot.length) {
      _decide();
      return;
    }
    setState(() {
      _at++;
      _dial = 0;
      _askCurrent();
    });
  }

  // --- Шийдвэр --------------------------------------------------------------

  List<Seat> get _top {
    if (_ballot.isEmpty) return const <Seat>[];
    final int best = _ballot
        .map((Seat s) => c.hands[s] ?? 0)
        .reduce((int a, int b) => a > b ? a : b);
    if (best <= 0) return const <Seat>[]; // Нэг ч гар өргөгдсөнгүй.
    return _ballot.where((Seat s) => (c.hands[s] ?? 0) == best).toList();
  }

  void _decide() {
    final List<Seat> top = _top;
    if (top.length == 1) {
      widget.onExile(<Seat>[top.first]);
      return;
    }
    if (top.isEmpty) {
      // Нэг ч гар өргөгдөөгүй — хэн ч хөөгдөхгүй.
      widget.onCue?.call('VOTE_TIE');
      widget.onNoExile();
      return;
    }
    switch (c.settings.tieRule) {
      case TieRule.noElim:
        widget.onCue?.call('VOTE_TIE');
        widget.onNoExile();
      case TieRule.random:
        widget.onExile(<Seat>[c.randomTieBreak(top)]);
      case TieRule.fsm:
        _tieRound++;
        _ballot = top;
        if (_tieRound == 1) {
          // +30 сек үг → дахин санал.
          setState(_beginTieSpeech);
        } else {
          // Дахиад тэнцлээ → «бүгдийн хувь заяа».
          setState(_beginAllFate);
        }
    }
  }

  void _beginAllFate() {
    _tick?.cancel();
    _stage = VoteStage.allFate;
    _dial = 0;
    _asked = true;
    widget.onCue?.call('VOTE_OPEN');
  }

  /// Олонх дэмжвэл ТЭНЦСЭН БҮГД гарна (GDD-01 §1, GDD-06 S16).
  void _resolveAllFate(int hands) {
    if (hands * 2 > c.alive.length) {
      widget.onExile(List<Seat>.of(_ballot));
    } else {
      widget.onCue?.call('VOTE_TIE');
      widget.onNoExile();
    }
  }

  // --- Барилга --------------------------------------------------------------

  @override
  Widget build(BuildContext context) => switch (_stage) {
    VoteStage.nomination => _nominationView(),
    VoteStage.defence || VoteStage.tieSpeech => _speechView(),
    VoteStage.voting || VoteStage.allFate => _dialView(),
  };

  // S14
  Widget _nominationView() {
    final List<Seat> nominees = c.nominations.toList()..sort();
    final bool full = nominees.length >= kMaxNominations;
    final List<Seat> seats = c.alive.toList()..sort();

    return PhoneScaffold(
      title: 'Хэнийг хотоос хөөх вэ?',
      subtitle: nominees.isEmpty
          ? null
          : 'Нэр дэвшүүлсэн: ${nominees.map((Seat s) => '№$s').join(' · ')}',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (full)
            Padding(
              padding: const EdgeInsets.only(bottom: kGap),
              child: Text(
                'Гурваас илүү болохгүй.',
                style: kBody.copyWith(color: kEmber),
              ),
            ),
          SeatGrid(
            seats: seats,
            selected: c.nominations.contains,
            // Дүүрсэн үед тор бүдгэрнэ, ГЭХДЭЭ сонгогдсон нь дарагдана —
            // буруу товшилтоос гарах цорын ганц зам.
            enabled: (int s) => !full || c.nominations.contains(s),
            onTap: _toggleNomination,
          ),
        ],
      ),
      action: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          FilledButton(
            onPressed: nominees.isEmpty ? null : _closeNominations,
            child: const Text('Санал хураая'),
          ),
          const SizedBox(height: 4),
          TextButton(
            onPressed: _skipAll,
            style: TextButton.styleFrom(
              foregroundColor: kTextMuted,
              minimumSize: const Size.fromHeight(kMinTouch),
            ),
            child: const Text('Хэн ч биш'),
          ),
        ],
      ),
    );
  }

  // S15 ба тэнцлийн нэмэлт үг
  Widget _speechView() {
    final bool defence = _stage == VoteStage.defence;
    final Seat who = _ballot[_at];
    final int total = defence ? kDefenceSeconds : kTieSpeechSeconds;
    final bool reduce = c.settings.reduceMotion;

    return Scaffold(
      backgroundColor: kSurface,
      body: TwoFingerSwipe(
        onSwipeDown: _skipSpeeches,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(kGutter),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '$who',
                      style: kSeatNumber.copyWith(
                        fontSize: 140,
                        color: kTextPrimary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: kGap),
                if (!reduce)
                  SizedBox(
                    height: 10,
                    child: LinearProgressIndicator(
                      value: (_secondsLeft / total).clamp(0.0, 1.0),
                      backgroundColor: kSurfaceHigh,
                      valueColor: const AlwaysStoppedAnimation<Color>(kEmber),
                    ),
                  ),
                const SizedBox(height: kGap),
                Text(
                  defence ? 'Өмгөөлөл — №$who' : 'Нэмэлт үг — №$who',
                  textAlign: TextAlign.center,
                  style: kTitle.copyWith(color: kTextPrimary, height: 1.45),
                ),
                const SizedBox(height: 4),
                Text(
                  mmss(math.max(0, _secondsLeft)),
                  textAlign: TextAlign.center,
                  style: kBody.copyWith(color: kTextMuted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // S16
  Widget _dialView() {
    final bool allFate = _stage == VoteStage.allFate;
    final Seat? who = allFate ? null : _ballot[_at];
    final String headline = allFate
        ? 'Бүгдийн хувь заяа — хэдэн гар?'
        : '№$who — хэдэн гар?';

    return Scaffold(
      backgroundColor: kSurface,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(kGutter, 16, kGutter, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    headline,
                    style: kTitle.copyWith(color: kTextPrimary, height: 1.45),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    allFate
                        ? 'Олонх дэмжвэл тэнцсэн бүгд гарна: '
                              '${_ballot.map((Seat s) => '№$s').join(' · ')}'
                        : (_asked ? 'Эсрэг хэн байна? Гараа өргө.' : ' '),
                    style: kBody.copyWith(color: kTextMuted),
                  ),
                  if (_tooMany)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Амьд хүнээс их байна.',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          height: 1.45,
                          color: kDanger,
                        ),
                      ),
                    ),
                  if (_notice != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        _notice!,
                        style: kBody.copyWith(color: kEmber),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: VoteDial(
                value: _dial,
                tooMany: _tooMany,
                leftHanded: c.settings.leftHanded,
                reduceMotion: c.settings.reduceMotion,
                haptics: c.settings.haptics,
                onChanged: (int v) => setState(() => _dial = v),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(kGutter, 8, kGutter, kGutter),
              child: HoldToConfirm(
                label: _tooMany ? 'Амьд хүнээс их байна' : 'Дарж барь — батал',
                enabled: !_tooMany,
                onConfirm: _confirmDial,
                onRejected: () => _notice3s('Товшилт биш — дарж барь.'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Арк — 0-ээс 20, доод булангаас эрхийгээр татагдана
// ---------------------------------------------------------------------------

class VoteDial extends StatefulWidget {
  const VoteDial({
    super.key,
    required this.value,
    required this.onChanged,
    this.tooMany = false,
    this.leftHanded = false,
    this.reduceMotion = false,
    this.haptics = true,
  });

  final int value;
  final ValueChanged<int> onChanged;
  final bool tooMany;
  final bool leftHanded;

  /// Хөдөлгөөн багасгах горимд арк нь `−` / `+` хоёр том товч болно.
  final bool reduceMotion;
  final bool haptics;

  @override
  State<VoteDial> createState() => _VoteDialState();
}

class _VoteDialState extends State<VoteDial> {
  void _emit(int v) {
    final int clamped = v.clamp(0, kDialMax);
    if (clamped == widget.value) return;
    // Шүд тутамд богино чичиргээ — харааны бус хариу (GDD-08 §4).
    if (widget.haptics) Haptic.confirm();
    widget.onChanged(clamped);
  }

  void _fromPoint(Offset local, Size size) {
    final Offset pivot = widget.leftHanded
        ? Offset(0, size.height)
        : Offset(size.width, size.height);
    final double dx = local.dx - pivot.dx;
    final double dy = local.dy - pivot.dy;
    if (dy > 0) return;
    // 0 = хэвтээ (булан руу), π/2 = босоо дээш.
    final double a = math.atan2(-dy, widget.leftHanded ? dx : -dx);
    if (a.isNaN) return;
    final double t = (a / (math.pi / 2)).clamp(0.0, 1.0);
    _emit((t * kDialMax).round());
  }

  @override
  Widget build(BuildContext context) {
    final Color colour = widget.tooMany ? kDanger : kEmber;

    if (widget.reduceMotion) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            _number(colour, 96),
            const SizedBox(height: kGap),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                _stepButton(
                  MarkShape.minus,
                  'Хасах',
                  () => _emit(widget.value - 1),
                ),
                const SizedBox(width: kGap),
                _stepButton(
                  MarkShape.plus,
                  'Нэмэх',
                  () => _emit(widget.value + 1),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints box) {
        final Size size = Size(box.maxWidth, box.maxHeight);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (DragStartDetails d) => _fromPoint(d.localPosition, size),
          onPanUpdate: (DragUpdateDetails d) =>
              _fromPoint(d.localPosition, size),
          child: Semantics(
            slider: true,
            value: '${widget.value}',
            child: CustomPaint(
              painter: _DialPainter(
                value: widget.value,
                leftHanded: widget.leftHanded,
                colour: colour,
              ),
              child: Center(
                child: _number(colour, math.min(200, size.shortestSide * 0.62)),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _number(Color colour, double size) => FittedBox(
    fit: BoxFit.scaleDown,
    child: Text(
      '${widget.value}',
      style: TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w700,
        height: 1.0,
        color: colour,
      ),
    ),
  );

  Widget _stepButton(MarkShape shape, String label, VoidCallback onTap) =>
      Semantics(
        button: true,
        label: label,
        child: Material(
          color: kSurfaceRaised,
          borderRadius: BorderRadius.circular(kRadius),
          child: InkWell(
            borderRadius: BorderRadius.circular(kRadius),
            onTap: onTap,
            child: SizedBox(
              width: 88,
              height: 88,
              child: Center(
                child: Mark(shape, size: 40, weight: 3.4, color: kTextPrimary),
              ),
            ),
          ),
        ),
      );
}

class _DialPainter extends CustomPainter {
  const _DialPainter({
    required this.value,
    required this.leftHanded,
    required this.colour,
  });

  final int value;
  final bool leftHanded;
  final Color colour;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset pivot = leftHanded
        ? Offset(0, size.height)
        : Offset(size.width, size.height);
    final double r = size.width * 0.9;
    final Paint track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..color = kSurfaceHigh;
    final Rect rect = Rect.fromCircle(center: pivot, radius: r);
    // Баруун гар: 180°..270°. Зүүн гар: 270°..360°.
    final double start = leftHanded ? -math.pi / 2 : math.pi;
    final double sweep = math.pi / 2;
    canvas.drawArc(rect, start, sweep, false, track);

    if (value <= 0) return;
    final double frac = value / kDialMax;
    final Paint fill = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..color = colour;
    canvas.drawArc(
      rect,
      leftHanded ? start : start + sweep * (1 - frac),
      sweep * frac,
      false,
      fill,
    );
  }

  @override
  bool shouldRepaint(_DialPainter old) =>
      old.value != value ||
      old.colour != colour ||
      old.leftHanded != leftHanded;
}

// ---------------------------------------------------------------------------
// 600 мс дарж-дүүргэх. Товшилт БИШ — санамсаргүй тоо бүртгэгдэхгүй.
// ---------------------------------------------------------------------------

class HoldToConfirm extends StatefulWidget {
  const HoldToConfirm({
    super.key,
    required this.label,
    required this.onConfirm,
    this.enabled = true,
    this.onRejected,
    this.hold = kDialConfirmHold,
  });

  final String label;
  final VoidCallback onConfirm;
  final bool enabled;

  /// Товшсон боловч барьсангүй — мөр гарна.
  final VoidCallback? onRejected;
  final Duration hold;

  @override
  State<HoldToConfirm> createState() => _HoldToConfirmState();
}

class _HoldToConfirmState extends State<HoldToConfirm> {
  static const Duration _step = Duration(milliseconds: 50);
  Timer? _timer;
  double _progress = 0;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _start() {
    if (!widget.enabled) return;
    _timer?.cancel();
    _timer = Timer.periodic(_step, (Timer t) {
      if (!mounted) return;
      setState(() {
        _progress += _step.inMilliseconds / widget.hold.inMilliseconds;
        if (_progress >= 1.0) {
          t.cancel();
          _progress = 0;
          widget.onConfirm();
        }
      });
    });
  }

  void _cancel() {
    _timer?.cancel();
    if (_progress > 0 && _progress < 1.0) widget.onRejected?.call();
    if (mounted) setState(() => _progress = 0);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: widget.enabled,
      label: '${widget.label}. Дарж барина.',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (TapDownDetails _) => _start(),
        onTapUp: (TapUpDetails _) => _cancel(),
        onTapCancel: _cancel,
        child: Container(
          height: kPrimaryButtonHeight,
          decoration: BoxDecoration(
            color: widget.enabled ? kSurfaceRaised : kSurfaceHigh,
            borderRadius: BorderRadius.circular(kRadius),
            border: Border.all(color: kHairline),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: _progress.clamp(0.0, 1.0),
                child: const ColoredBox(color: kEmber),
              ),
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    widget.label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      height: 1.45,
                      color: widget.enabled ? kTextPrimary : kTextMuted,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
