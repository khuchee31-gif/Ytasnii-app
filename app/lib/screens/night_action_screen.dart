// S09 — Шөнийн үйлдэл, ба S10 — Мөрдөгчийн хариу (GDD-06 §S09, §S10).
//
// Багцын хамгийн том инженерийн хэмнэлт: ДӨРВӨН ДҮРД ДӨРВӨН ДЭЛГЭЦ БИШ,
// НЭГ ДЭЛГЭЦ (GDD-00 §10). Байрлал нь суудал бүрт ЯГ ИЖИЛХЭН: дээд захад
// асуулт, дундаа тор, доод захад дарж-дүүргэх батлах зурвас. Зөвхөн асуултын
// МӨР дүрээс хамаарна; өөр юу ч биш.
//
// ЦАГИЙН ХАЖУУГИЙН СУВГИЙН ЭСРЭГ (GDD-10 §5, GDD-06 S09-ийн тайминг):
//
//   0     мс  асуулт гарна, тор дүүрнэ; mediumImpact
//   0…W−600   сонголт (нэг товшилт = сонголт, дахин товшилт = өөрчлөх)
//   батлах    600 мс ДАРЖ-ДҮҮРГЭХ зурвас, товшилтоор БИШ. ЧИМЭЭГҮЙ.
//   5500  мс  mediumImpact — «дамжуул» гэсэн дохио, бүх суудалд ижил
//   W     мс  цонх хаагдана. ЭРТ ХЭЗЭЭ Ч ХААГДАХГҮЙ.
//
// `W` = `settings.nightSeatSeconds × 1000`, тоглолтын турш ЦАРЦСАН (анхдагч
// 6000). Баталгаажуулах товшилт дэлгэцийг ЭРТ ХААХГҮЙ — эс бөгөөс суудал
// 1.2 сек-д эсвэл 5.0 сек-д баталсан нь хөршид мэдрэгдэж, тэр бол цагийн ул
// мөр. Зөвшөөрөгдсөн цорын ганц чичиргээ нь дээрх ХОЁР ТОГТМОЛ ИМПУЛЬС.
//
// Товшоогүй бол `noAction` бүртгэгдэнэ, дэлгэц ӨӨРЧЛӨГДӨХГҮЙ — энэ бол
// харагдах «Алгасах» товчийг орлож байгаа механизм (GDD-02 §3, GDD-05 §1).
//
// ГАР УТАС: тор дэлгэцийн дунд-доод хэсэгт, дээд хэсэг нь зөвхөн асуулт.
// Батлах зурвас доод захад, өргөн нь дэлгэц дүүрэн — эрхийн ямар ч байрлалаас
// хүрнэ. Хүрэх талбай хаана ч ≥ `kMinTouch`.
//
// GDD-10 §4-ийн дүрэм: дүр уншдаг дуудлага ЗӨВХӨН `reveal_screen.dart` ба
// ЭНЭ ФАЙЛД байна. `night_circuit_screen.dart` дүр УНШИХГҮЙ.

import 'dart:async';

import 'package:engine/engine.dart';
import 'package:flutter/material.dart' hide Intent;

import '../game/game_controller.dart';
import '../ui/tokens.dart';
import '../ui/widgets.dart';

// ---------------------------------------------------------------------------
// Хугацааны тогтмолууд — GDD-06 S09 / S10, GDD-10 §5
// ---------------------------------------------------------------------------

/// Батлах зурвас дүүрэх хугацаа. Товшилт БИШ — дарж барина.
const Duration kConfirmHold = Duration(milliseconds: 600);

/// Хоёр дахь импульс — «дамжуул». Бүх суудалд ижил агшинд.
const int kSecondPulseMs = 5500;

/// S10 — Мөрдөгчийн хариу дэлгэцэн дээр байх хугацаа. GDD-05 §9.1-ийн 2.0 сек.
/// Дахин харах боломжгүй: нэг л удаа.
const Duration kTraceReveal = Duration(milliseconds: 2000);

/// Дотоод цохилтын алхам. Бүх хугацаа үүний үржвэр — тестэд детерминист.
const Duration kNightTick = Duration(milliseconds: 50);

// ---------------------------------------------------------------------------
// Асуултын мөрүүд — GDD-06 S09-ийн хүснэгт, ҮГ ҮСГЭЭР
// ---------------------------------------------------------------------------

/// Дүр бүрийн асуулт. **Дэлгэцийн ЦОРЫН ГАНЦ дүрээс хамаарах зүйл.**
String nightQuestionFor(Ability a) => switch (a) {
      Ability.mafiaKill => 'Хэнийг хохироох вэ?',
      Ability.heal => 'Хэнийг аврах вэ?',
      Ability.investigate => 'Хэнийг шалгах вэ?',
      Ability.suspect => 'Хэн сэжигтэй вэ?',
      Ability.noAction => 'Хэн сэжигтэй вэ?',
    };

/// S10-ын хоёр мөр. «Сэжигтэй / Сэжиггүй» БИШ — GDD-00 §6.
/// Дүрийн нарийн нэр ХЭЗЭЭ Ч гарахгүй.
String traceTextFor(MsgCode c) =>
    c == MsgCode.traceFound ? 'Мөр олдлоо.' : 'Мөр олдсонгүй.';

enum NightActionStage {
  /// Тор асаалттай, батлах зурвас бүдэг.
  choosing,

  /// Батлагдсан. Зурвас дүүрэн, тор түгжээтэй. ЧИЧИРГЭЭ, ДУУ, АНИМАЦИ БАЙХГҮЙ.
  confirmed,

  /// S10 — Мөрдөгчийн хариу, зөвхөн 2.0 сек.
  trace,

  /// Хар + «Ширээн дээр тавь». Цонхны үлдсэн хугацаа.
  hidden,

  /// «Би харахгүй байна» дарагдсан — хар дэлгэц + цаг, `noAction`.
  blind,
}

class NightActionScreen extends StatefulWidget {
  const NightActionScreen({
    super.key,
    required this.controller,
    required this.seat,
    required this.onFinished,
  });

  final GameController controller;

  /// Утас барьж байгаа суудал. ЗӨВХӨН энэ суудлын дүр уншигдана.
  final Seat seat;

  /// Цонх хаагдаж, санаа бүртгэгдсэн — дараагийн дамжуулалт руу.
  final VoidCallback onFinished;

  @override
  State<NightActionScreen> createState() => _NightActionScreenState();
}

class _NightActionScreenState extends State<NightActionScreen> {
  Timer? _tick;

  int _elapsedMs = 0;
  int _holdMs = 0;
  bool _holding = false;
  bool _pulsedSecond = false;

  Seat? _target;
  NightActionStage _stage = NightActionStage.choosing;

  MsgCode? _trace;
  int _traceStartedMs = 0;

  /// Батлагдсан эсэх — цонх хаагдахад санаа бүртгэгдэх эсэхийг ЭНЭ шийднэ.
  bool _confirmedOnce = false;

  GameController get _c => widget.controller;

  /// Тоглолтын турш ЦАРЦСАН цонх. Бүх суудалд ижил (GDD-10 §5).
  late final int _windowMs = _c.settings.nightSeatSeconds * 1000;

  /// Тухайн суудлын чадвар. Дүр нь ЭНД л уншигдана.
  late final Ability _ability =
      abilityOf(_c.roleOf(widget.seat) ?? Role.citizen);

  @override
  void initState() {
    super.initState();
    // t = 0 — эхний импульс. Суудал бүрт ЯГ ИЖИЛ.
    if (_c.settings.haptics) Haptic.heavy();
    _tick = Timer.periodic(kNightTick, (_) => _onTick());
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  // --- Цаг ------------------------------------------------------------------

  void _onTick() {
    if (!mounted) return;
    _elapsedMs += kNightTick.inMilliseconds;

    if (_holding && _stage == NightActionStage.choosing) {
      _holdMs += kNightTick.inMilliseconds;
      if (_holdMs >= kConfirmHold.inMilliseconds) {
        _confirm();
      }
    }

    if (!_pulsedSecond && _elapsedMs >= kSecondPulseMs) {
      _pulsedSecond = true;
      // Хоёр дахь импульс — «дамжуул». Баталсан эсэхээс ХАМААРАХГҮЙ.
      if (_c.settings.haptics) Haptic.heavy();
    }

    if (_stage == NightActionStage.trace &&
        _elapsedMs - _traceStartedMs >= kTraceReveal.inMilliseconds) {
      // Хариу нэг л удаа. Дахин харах зам БАЙХГҮЙ.
      _trace = null;
      _stage = NightActionStage.hidden;
    }

    if (_elapsedMs >= _windowMs) {
      _close();
      return;
    }
    setState(() {});
  }

  /// Цонх хаагдана. ЭРТ ХЭЗЭЭ Ч БИШ.
  void _close() {
    _tick?.cancel();
    _tick = null;
    final bool acted =
        _stage != NightActionStage.blind && _target != null && _confirmedOnce;
    // Товшоогүй нь товшсонтой гаднаас ЯЛГАГДАХГҮЙ — ижил агшинд, ижил дуугүй.
    _c.submitIntent(
      widget.seat,
      acted ? _ability : Ability.noAction,
      acted ? _target : null,
    );
    widget.onFinished();
  }

  // --- Сонголт --------------------------------------------------------------

  /// Сонголтын цонх. Сүүлийн 600 мс нь батлахад л үлдэнэ (GDD-06 S09).
  bool get _selectable =>
      _stage == NightActionStage.choosing &&
      _elapsedMs < _windowMs - kConfirmHold.inMilliseconds;

  /// Хууль ёсны бай мөн эсэх — дэлгэц үүнийг л асууна (GDD-05 §2).
  bool _legal(Seat s) =>
      _c.alive.contains(s) && _c.checkTarget(widget.seat, _ability, s) == null;

  void _pick(Seat s) {
    if (!_selectable || !_legal(s)) return;
    // Нэг товшилт = сонголт, дахин товшилт = өөрчлөх.
    setState(() {
      _target = s;
      _holdMs = 0;
    });
  }

  void _holdStart() {
    if (_stage != NightActionStage.choosing || _target == null) return;
    setState(() => _holding = true);
  }

  void _holdEnd() {
    if (!_holding) return;
    setState(() {
      _holding = false;
      _holdMs = 0;
    });
  }

  /// ЧИЧИРГЭЭ БАЙХГҮЙ, ДУУ БАЙХГҮЙ, АНИМАЦИ БАЙХГҮЙ (GDD-10 §5).
  void _confirm() {
    _holding = false;
    _holdMs = kConfirmHold.inMilliseconds;
    _confirmedOnce = true;
    _stage = NightActionStage.confirmed;

    if (_ability == Ability.investigate && _target != null) {
      // S10 — хариу нь ТЭР ДОР НЬ, тэр суудлын ижил цонхны дотор.
      // Хоёр дахь `RevealGate` БАЙХГҮЙ (GDD-15).
      final Msg? m = _c.previewInvestigation(widget.seat, _target!);
      if (m != null) {
        _trace = m.code;
        _traceStartedMs = _elapsedMs;
        _stage = NightActionStage.trace;
      }
    }
  }

  void _goBlind() {
    if (_stage != NightActionStage.choosing) return;
    setState(() {
      _stage = NightActionStage.blind;
      _target = null;
      _holding = false;
      _holdMs = 0;
    });
  }

  // --- Дүрслэл --------------------------------------------------------------

  int get _secondsLeft =>
      ((_windowMs - _elapsedMs) / 1000).ceil().clamp(0, 999);

  @override
  Widget build(BuildContext context) {
    switch (_stage) {
      case NightActionStage.blind:
        return _blackScreen(child: BigCountdown(_secondsLeft));
      case NightActionStage.trace:
        return _traceScreen();
      case NightActionStage.hidden:
        return _blackScreen(
          child: Text(
            'Ширээн дээр тавь',
            textAlign: TextAlign.center,
            style: kBody.copyWith(color: kTextMuted),
          ),
        );
      case NightActionStage.choosing:
      case NightActionStage.confirmed:
        return _chooseScreen();
    }
  }

  Widget _blackScreen({required Widget child}) => Scaffold(
        backgroundColor: kNight,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(kGutter),
            child: Center(child: child),
          ),
        ),
      );

  /// S10 — өнгө БА хэлбэр БА кирилл үг. Гурвуулаа, хэзээ ч зөвхөн өнгө биш.
  Widget _traceScreen() {
    final bool found = _trace == MsgCode.traceFound;
    final Color c = found ? kDanger : kOk;
    return Scaffold(
      backgroundColor: kNight,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(kGutter),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                found ? '✕' : '○',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 96, height: 1.0, color: c, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: kGap),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  traceTextFor(_trace!),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 34,
                      height: 1.45,
                      fontWeight: FontWeight.w700,
                      color: c),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chooseScreen() {
    final bool reduce = _c.settings.reduceMotion;
    final List<Seat> seats =
        List<Seat>.generate(_c.seatCount, (int i) => i + 1);

    return PhoneScaffold(
      background: kNight,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // --- Дээд хэсэг: ЗӨВХӨН асуулт. Товч энд БАЙХГҮЙ. ---------------
          Text('№${widget.seat}',
              style: kLabel.copyWith(color: kTextMuted)),
          const SizedBox(height: 6),
          Text(
            nightQuestionFor(_ability),
            style: kTitle.copyWith(
                color: kTextPrimary, fontSize: 26, height: 1.45),
          ),
          const SizedBox(height: kGap),
          _WindowBar(
            progress: (_elapsedMs / _windowMs).clamp(0.0, 1.0),
            secondsLeft: _secondsLeft,
            reduceMotion: reduce,
          ),
          const SizedBox(height: kGutter),

          // --- Дунд: тор. Бүх дүрд ИЖИЛ хэмжээ, ижил суудлууд. ------------
          SeatGrid(
            seats: seats,
            onTap: _pick,
            enabled: (int s) => _selectable && _legal(s),
            selected: (int s) => _target == s,
            // Амьд/хасагдсан нь өнгө БА шошгоор ялгагдана (GDD-06 S09).
            badge: (int s) => _c.alive.contains(s) ? null : 'хасагдсан',
          ),
          const SizedBox(height: kGutter),

          // «Би харахгүй байна» — дээд гуравны нэгд БИШ, торны дор.
          Align(
            alignment: Alignment.center,
            child: TextButton(
              onPressed:
                  _stage == NightActionStage.choosing ? _goBlind : null,
              style: TextButton.styleFrom(
                foregroundColor: kTextMuted,
                minimumSize: const Size(kMinTouch * 3, kMinTouch),
              ),
              child: const Text('Би харахгүй байна'),
            ),
          ),
        ],
      ),
      action: _ConfirmStrip(
        key: const ValueKey<String>('nightConfirm'),
        label: _target == null
            ? 'Суудал сонго'
            : (_stage == NightActionStage.choosing
                ? '№$_target — дарж батал'
                : '№$_target — батлагдлаа'),
        progress: _holdMs / kConfirmHold.inMilliseconds,
        armed: _stage == NightActionStage.choosing && _target != null,
        reduceMotion: reduce,
        onHoldStart: _holdStart,
        onHoldEnd: _holdEnd,
      ),
    );
  }
}

/// Цонхны цагираг — **хана цагаар** дүүрнэ, оролтоос ХАМААРАХГҮЙ (GDD-10 §5).
/// Хөдөлгөөн багасгах горимд тоо болно.
class _WindowBar extends StatelessWidget {
  const _WindowBar({
    required this.progress,
    required this.secondsLeft,
    required this.reduceMotion,
  });

  final double progress;
  final int secondsLeft;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    if (reduceMotion) {
      return Text('$secondsLeft сек',
          style: kBody.copyWith(color: kTextMuted));
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: SizedBox(
        height: 6,
        child: Stack(
          children: <Widget>[
            Container(color: kSurfaceHigh),
            FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: progress.clamp(0.0, 1.0),
              child: Container(color: kEmber),
            ),
          ],
        ),
      ),
    );
  }
}

/// Батлах зурвас. **600 мс дарж-дүүргэх, товшилтоор биш.**
/// Доод захад, өргөн нь дэлгэц дүүрэн — эрхийн ямар ч байрлалаас хүрнэ.
class _ConfirmStrip extends StatelessWidget {
  const _ConfirmStrip({
    super.key,
    required this.label,
    required this.progress,
    required this.armed,
    required this.reduceMotion,
    required this.onHoldStart,
    required this.onHoldEnd,
  });

  final String label;
  final double progress;
  final bool armed;
  final bool reduceMotion;
  final VoidCallback onHoldStart;
  final VoidCallback onHoldEnd;

  @override
  Widget build(BuildContext context) {
    final Color fg = armed ? kEmber : kTextMuted;
    return Semantics(
      button: true,
      enabled: armed,
      label: '$label. 600 мс дар.',
      child: Listener(
        onPointerDown: armed ? (_) => onHoldStart() : null,
        onPointerUp: (_) => onHoldEnd(),
        onPointerCancel: (_) => onHoldEnd(),
        behavior: HitTestBehavior.opaque,
        child: Container(
          // GDD-06 §0: үндсэн үйлдэл ≥ 72 dp.
          height: 72,
          decoration: BoxDecoration(
            color: kSurfaceRaised,
            borderRadius: BorderRadius.circular(kRadius),
            border: Border.all(color: armed ? kEmber : kHairline),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(kRadius),
            child: Stack(
              children: <Widget>[
                if (!reduceMotion)
                  FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: progress.clamp(0.0, 1.0),
                    child: Container(color: kEmber.withValues(alpha: 0.30)),
                  ),
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: kGap),
                    child: Text(
                      reduceMotion ? '$label — 600 мс дар' : label,
                      textAlign: TextAlign.center,
                      style: kBody.copyWith(
                          color: fg, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
