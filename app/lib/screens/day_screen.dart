// S13 — Өдөр, хэлэлцүүлэг (GDD-06 §S13, GDD-01 §1-ийн 11–12-р мөр).
//
// Тоглолтын 80 %-ийг эзэлдэг дэлгэц, бөгөөд аппын ЮУ Ч ХИЙДЭГГҮЙ цорын ганц
// дэлгэц. Өдөр бол ангийнх. Апп гурван чимээ л эзэмшинэ — `UI_WARN_30`,
// `UI_TICK_10`, `UI_BELL` (GDD-08 §2). Хоолой БАЙХГҮЙ.
//
// ХАРИЛЦАН ҮЙЛДЭЛ ЯГ ХОЁР (GDD-06 S13-ын хуваалт):
//   • Доод 45 %-д ТОВШИЛТ           → 📌 Тэмдэглэ
//   • Цагирган дээр БАРУУН ШУДРАХ   → дараагийн үг хэлэгч
//   • Цагирган дээр ТОВШИЛТ         → ЮУ Ч БОЛОХГҮЙ, ХЭЗЭЭ Ч. Зориуд.
//   • Дээд мөрөнд товшилт           → Тооны самбарын сануулга, 3 сек
//   • Хоёр хуруугаар доош шудрах    → «Санал хураая» → S14
//
// Товшилт үг хэлэгчийг ХЭЗЭЭ Ч сольдоггүй: 📌-г харалгүй дарах боломжтой
// байх нь дарааллыг санамсаргүй эвдэх боломжтой байхтай нэг дэлгэц дээр
// орших боломжгүй.
//
// ГАР УТАС: энэ дэлгэц гар шаарддаггүй. Утас ширээн дунд хэвтэнэ, хүн бөхийж
// алгадана. Тиймээс `PhoneScaffold` ашиглаагүй — доод 45 % нь ҮНЭХЭЭР 45 %
// байх ёстой, гүйлгэдэг биед тэр хувь алдагдана.

import 'dart:async';
import 'dart:math' as math;

import 'package:engine/engine.dart' show Seat;
import 'package:flutter/material.dart' hide Intent;

import '../game/game_controller.dart';
import '../ui/atmosphere.dart';
import '../ui/glyphs.dart';
import '../ui/tokens.dart';
import '../ui/widgets.dart';

/// 📌 хоёр дарааллын хооронд (GDD-06 S13-ын хүснэгт).
const Duration kPinCooldown = Duration(seconds: 4);

/// «Тэмдэглэлээ (3)» хэр удаан анивчих вэ.
const Duration kPinFlash = Duration(milliseconds: 900);

/// Тоглолтод дээд тал нь хэдэн 📌 (`GameController.addPin` мөн хамгаална).
const int kPinBudget = 12;

/// Дээд мөрийн сануулга хэр удаан харагдах вэ.
const Duration kBudgetHint = Duration(seconds: 3);

/// Дэлгэц харанхуйлах алхам ба доод хязгаар (GDD-08 §6).
const Duration kDimStep = Duration(seconds: 15);
const double kDimPerStep = 0.08;
const double kDimFloor = 0.40;

/// Доод хэдэн хувь нь 📌-ийн хүрэх талбай вэ.
const double kPinZoneFraction = 0.45;

// ---------------------------------------------------------------------------
// Монгол тоон үг — TalkBack-ийн шошгод. «Одоо гурван тэмдэглэл.»
// ---------------------------------------------------------------------------

const List<String> _kAttrNumbers = <String>[
  'тэг',
  'нэг',
  'хоёр',
  'гурван',
  'дөрвөн',
  'таван',
  'зургаан',
  'долоон',
  'найман',
  'есөн',
  'арван',
  'арван нэгэн',
  'арван хоёр',
];

/// Тооны тэмдэг нэрийн хэлбэр. Хязгаараас хэтэрвэл цифрээр буцаана.
String mnAttrNumber(int n) =>
    (n >= 0 && n < _kAttrNumbers.length) ? _kAttrNumbers[n] : '$n';

String mmss(int seconds) {
  final int m = seconds ~/ 60;
  final int s = seconds % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}

// ---------------------------------------------------------------------------
// Хоёр хуруугаар шудрах — S13, S15, S19 гуравт хуваалцана.
// ---------------------------------------------------------------------------

/// Хоёр ба түүнээс олон хуруу нэг зэрэг [threshold] пикселээр хөдлөхөд нэг
/// удаа асна. `GestureDetector`-ийн `onVerticalDrag` нь нэг хурууны танигч
/// тул үүнийг `Listener` дээр гараар барьсан.
class TwoFingerSwipe extends StatefulWidget {
  const TwoFingerSwipe({
    super.key,
    required this.child,
    this.onSwipeDown,
    this.onSwipeAny,
    this.threshold = 48,
  });

  final Widget child;

  /// Доош шудрав — S13-ын «Санал хураая», S15-ын «алгас».
  final VoidCallback? onSwipeDown;

  /// Чиглэл хамаарахгүй — S19-ийн «дараагийн суудал».
  final VoidCallback? onSwipeAny;

  final double threshold;

  @override
  State<TwoFingerSwipe> createState() => _TwoFingerSwipeState();
}

class _TwoFingerSwipeState extends State<TwoFingerSwipe> {
  final Map<int, Offset> _down = <int, Offset>{};
  bool _fired = false;

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (PointerDownEvent e) {
        _down[e.pointer] = e.position;
      },
      onPointerMove: (PointerMoveEvent e) {
        if (_fired || _down.length < 2) return;
        final Offset? start = _down[e.pointer];
        if (start == null) return;
        final Offset d = e.position - start;
        if (d.distance < widget.threshold) return;
        if (widget.onSwipeAny != null) {
          _fired = true;
          widget.onSwipeAny!.call();
        } else if (widget.onSwipeDown != null && d.dy >= widget.threshold) {
          _fired = true;
          widget.onSwipeDown!.call();
        }
      },
      onPointerUp: (PointerUpEvent e) => _release(e.pointer),
      onPointerCancel: (PointerCancelEvent e) => _release(e.pointer),
      child: widget.child,
    );
  }

  void _release(int pointer) {
    _down.remove(pointer);
    if (_down.isEmpty) _fired = false;
  }
}

// ---------------------------------------------------------------------------
// S13
// ---------------------------------------------------------------------------

enum DayStage {
  /// `speaking(k)` — суудал тутамд `speechSeconds`.
  speaking,

  /// Бүх суудал ярьсны дараа. Цагираг тоологдохоо болино.
  freeTalk,
}

class DayScreen extends StatefulWidget {
  const DayScreen({
    super.key,
    required this.controller,
    required this.onVote,
    this.onCue,
  });

  final GameController controller;

  /// Хоёр хуруугаар доош шудрав — S14 руу.
  final VoidCallback onVote;

  /// `UI_WARN_30`, `UI_TICK_10`, `UI_BELL`, `UI_BASS_B0`, `DISCUSS_START`.
  /// Эдгээр нь `bus.ui`-ийн SFX, хоолойн клип БИШ (GDD-08 §2).
  final void Function(String cueId)? onCue;

  @override
  State<DayScreen> createState() => _DayScreenState();
}

class _DayScreenState extends State<DayScreen> {
  late List<Seat> _order;
  int _index = 0;
  DayStage _stage = DayStage.speaking;

  int _secondsLeft = 0;
  int _dayElapsed = 0;

  Timer? _tick;
  Timer? _pinFlashTimer;
  Timer? _hintTimer;

  String? _pinFlash;
  bool _hintShown = false;
  int _lastPinAtMs = -1 << 30;

  GameController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    _order = c.speechOrder;
    _secondsLeft = c.settings.speechSeconds;
    if (_order.isEmpty) _stage = DayStage.freeTalk;

    // `b` нь өдөр ЭХЛЭХ агшинд л өөрчлөгддөг — дэд басс нь хэлэлцүүлгийн
    // секунд биш, хөтлөгчийн секунд (GDD-08 §2).
    if (c.pips <= 0) widget.onCue?.call('UI_BASS_B0');
    widget.onCue?.call('DISCUSS_START');

    _tick = Timer.periodic(const Duration(seconds: 1), _onSecond);
  }

  @override
  void dispose() {
    _tick?.cancel();
    _pinFlashTimer?.cancel();
    _hintTimer?.cancel();
    super.dispose();
  }

  void _onSecond(Timer _) {
    if (!mounted) return;
    setState(() {
      _dayElapsed++;
      if (_stage != DayStage.speaking) return;
      _secondsLeft--;
      if (_secondsLeft == 30) widget.onCue?.call('UI_WARN_30');
      if (_secondsLeft == 10) widget.onCue?.call('UI_TICK_10');
      if (_secondsLeft <= 0) {
        widget.onCue?.call('UI_BELL');
        _advance();
      }
    });
  }

  /// Дараагийн үг хэлэгч. Хонх ч, баруун тийш шудрах ч энд ирнэ.
  void _advance() {
    if (_index + 1 >= _order.length) {
      _stage = DayStage.freeTalk;
      _secondsLeft = 0;
    } else {
      _index++;
      _secondsLeft = c.settings.speechSeconds;
    }
  }

  void _swipeNext() {
    if (_stage != DayStage.speaking) return;
    setState(_advance);
  }

  Seat? get _speaker =>
      _order.isEmpty ? null : _order[math.min(_index, _order.length - 1)];

  // --- 📌 -------------------------------------------------------------------

  void _pin() {
    if (!c.settings.pinMoments) return;

    if (c.pins.length >= kPinBudget) {
      _flash('Хангалттай тэмдэглэлээ.');
      return;
    }
    final int nowMs = _dayElapsed * 1000;
    if (nowMs - _lastPinAtMs < kPinCooldown.inMilliseconds) return;
    _lastPinAtMs = nowMs;

    final Seat speaker = _speaker ?? (_order.isEmpty ? 0 : _order.last);
    c.addPin(nowMs, speaker);
    if (c.settings.haptics) Haptic.confirm();
    _flash('Тэмдэглэлээ (${c.pins.length})');
  }

  void _flash(String text) {
    _pinFlashTimer?.cancel();
    setState(() => _pinFlash = text);
    _pinFlashTimer = Timer(kPinFlash, () {
      if (mounted) setState(() => _pinFlash = null);
    });
  }

  void _showBudgetHint() {
    _hintTimer?.cancel();
    setState(() => _hintShown = true);
    _hintTimer = Timer(kBudgetHint, () {
      if (mounted) setState(() => _hintShown = false);
    });
  }

  /// GDD-11 §4-ийн арван үг — үр дагавартай, формулгүй.
  String get _budgetHintMn {
    final int b = c.pips;
    if (b <= 0) return 'Алдаж болох санал: 0. Өнөөдөр онох ёстой.';
    return 'Алдаж болох санал: $b. '
        '${mnAttrNumber(b)[0].toUpperCase()}${mnAttrNumber(b).substring(1)} '
        'хотынхныг хөөвөл мафи ялна.';
  }

  /// 15 секунд тутамд 8 %, доод хязгаар 40 % (GDD-08 §6).
  /// Хөдөлгөөн багасгах горимд УНТАРНА — гэрэл мэдрэг хүнд.
  double get _dimAlpha {
    if (c.settings.reduceMotion) return 0;
    final int steps = _dayElapsed ~/ kDimStep.inSeconds;
    final double level = math.max(kDimFloor, 1.0 - kDimPerStep * steps);
    return 1.0 - level;
  }

  @override
  Widget build(BuildContext context) {
    final bool reduce = c.settings.reduceMotion;

    return Scaffold(
      backgroundColor: kSurface,
      body: TwoFingerSwipe(
        onSwipeDown: widget.onVote,
        child: Stack(
          children: <Widget>[
            SafeArea(
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints box) {
                  final double pinHeight = box.maxHeight * kPinZoneFraction;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      _topRow(),
                      Expanded(child: _ring(reduce)),
                      SizedBox(
                        key: const Key('pinZone'),
                        height: pinHeight,
                        child: _pinZone(),
                      ),
                    ],
                  );
                },
              ),
            ),
            if (_dimAlpha > 0)
              Positioned.fill(
                key: const Key('dimVeil'),
                child: IgnorePointer(
                  child: ColoredBox(
                    color: Colors.black.withValues(alpha: _dimAlpha),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // --- 1. Дээд мөр — Тооны самбар ------------------------------------------

  Widget _topRow() {
    final int b = c.pips;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _showBudgetHint,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(kGutter, 12, kGutter, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Semantics(
              label: 'Алдаж болох санал: ${mnAttrNumber(math.max(0, b))}',
              child: PipStrip(b),
            ),
            if (b <= 0)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Нэг л буруу санал — ялагдал.',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    height: 1.45,
                    color: kDanger,
                  ),
                ),
              ),
            if (_hintShown)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  _budgetHintMn,
                  style: kBody.copyWith(color: kTextMuted),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // --- 2. Дунд — үг хэлэгчийн цагираг --------------------------------------

  Widget _ring(bool reduce) {
    final Seat? speaker = _speaker;
    final int total = c.settings.speechSeconds;
    final double progress = _stage == DayStage.speaking && total > 0
        ? (_secondsLeft / total).clamp(0.0, 1.0)
        : 0.0;
    final bool warn = _stage == DayStage.speaking && _secondsLeft <= 30;

    return GestureDetector(
      key: const Key('speakerRing'),
      // ТОВШИЛТ ЭНД БҮРТГЭГДЭХГҮЙ. `onTap` БАЙХГҮЙ нь алдаа биш, шийдвэр.
      behavior: HitTestBehavior.opaque,
      onHorizontalDragEnd: (DragEndDetails d) {
        if ((d.primaryVelocity ?? 0) > 0) _swipeNext();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: kGutter),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Expanded(
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints box) {
                  // 200 sp бол зорилт; 360 (бүр 320) логик px дээр цагираг
                  // өөрөө хязгаар болно — тоо хэзээ ч мөрөө халихгүй.
                  final double d = math.max(
                    48,
                    math.min(box.maxWidth, box.maxHeight) - 8,
                  );
                  return Center(
                    child: SizedBox(
                      width: d,
                      height: d,
                      child: CustomPaint(
                        painter: reduce
                            ? null
                            : _RingPainter(
                                progress: progress,
                                color: warn ? kEmber : kTextMuted,
                              ),
                        child: Center(child: _ringLabel(speaker, d, reduce)),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            _aliveDots(),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _ringLabel(Seat? speaker, double d, bool reduce) {
    if (_stage == DayStage.freeTalk) {
      return Semantics(
        label: 'Чөлөөт хэлэлцүүлэг',
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'Чөлөөт хэлэлцүүлэг',
            textAlign: TextAlign.center,
            style: kTitle.copyWith(color: kTextPrimary, height: 1.45),
          ),
        ),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              key: const Key('speakerNumber'),
              '${speaker ?? ''}',
              style: TextStyle(
                fontSize: math.min(200, d * 0.55),
                fontWeight: FontWeight.w700,
                height: 1.0,
                color: kTextPrimary,
              ),
            ),
          ),
        ),
        // Хөдөлгөөн багасгах горимд цагираг нь «0:47» болно.
        if (reduce)
          Text(
            mmss(math.max(0, _secondsLeft)),
            style: kTitle.copyWith(color: kEmber, height: 1.45),
          ),
      ],
    );
  }

  /// Амьд суудлууд жижиг цагирган дээр дараалсан, ярьсан нь бүдэг.
  Widget _aliveDots() {
    if (_order.isEmpty) return const SizedBox.shrink();
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 6,
      runSpacing: 4,
      children: <Widget>[
        for (int i = 0; i < _order.length; i++)
          Text(
            '${_order[i]}',
            style: TextStyle(
              fontSize: 13,
              height: 1.45,
              fontWeight: i == _index && _stage == DayStage.speaking
                  ? FontWeight.w700
                  : FontWeight.w400,
              color: i < _index
                  ? kTextMuted.withValues(alpha: 0.45)
                  : (i == _index && _stage == DayStage.speaking
                        ? kEmber
                        : kTextMuted),
            ),
          ),
      ],
    );
  }

  // --- 3. Доод 45 % — 📌 Тэмдэглэ -------------------------------------------

  Widget _pinZone() {
    if (!c.settings.pinMoments) return const SizedBox.expand();
    final int n = c.pins.length;
    return Semantics(
      button: true,
      label: 'Тэмдэглэх товч. Одоо ${mnAttrNumber(n)} тэмдэглэл.',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _pin,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(kGutter, 8, kGutter, kGutter),
          // Энэ талбай дэлгэцийн 45 % — тиймээс ХООСОН ХАЙРЦАГ мэт харагдаж
          // болохгүй. Гараар зурсан хүрээ, тэмдэг, тайлбар гурав нь энэ нь
          // зориуд том товч гэдгийг хэлнэ.
          child: SizedBox.expand(
            child: InkFrame(
              color: kTextMuted.withValues(alpha: 0.45),
              thickness: 1.4,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Mark(MarkShape.pin, size: 30, color: kTextMuted),
                    const SizedBox(height: 14),
                    // Ямар ч ripple, ямар ч масштаб — бичиг БҮТНЭЭРЭЭ
                    // солигдоно (GDD-08 §5-ын «хэзээ ч анимац хийхгүй»).
                    Text(
                      _pinFlash ?? 'Тэмдэглэ',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: kDisplayFont,
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2,
                        height: 1.3,
                        color: kTextPrimary,
                      ),
                    ),
                    if (_pinFlash == null) ...<Widget>[
                      const SizedBox(height: 8),
                      Text(
                        'Энэ агшныг дэвтэрт хадна',
                        textAlign: TextAlign.center,
                        style: kBody.copyWith(fontSize: 14, color: kTextMuted),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Цагираг — дүүрч БУУРНА.
class _RingPainter extends CustomPainter {
  const _RingPainter({required this.progress, required this.color});
  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset centre = size.center(Offset.zero);
    final double r = math.min(size.width, size.height) / 2 - 6;
    final Paint track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..color = kSurfaceHigh;
    canvas.drawCircle(centre, r, track);
    if (progress <= 0) return;
    final Paint arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawArc(
      Rect.fromCircle(center: centre, radius: r),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      arc,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.color != color;
}
