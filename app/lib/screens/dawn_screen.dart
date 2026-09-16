// S11 — Үүр (GDD-06 §S11). Чимээгүйн хүснэгтийн гол дэлгэц.
//
// | # | Юу | Хугацаа | Дэлгэц |
// |---|---|---|---|
// | 1 | Салхи зогсоно, морин хуурын ганц нот | 1.5 сек | 40 % гэрэл, нүүрс дүүрнэ |
// | 2 | `DAWN_A` «Өнөө шөнө…» | — | Хоосон |
// | 3 | **Чимээгүй** | **2.5 сек** | Хоосон, уур амьсгал −40 дБ |
// | 4 | `DAWN_VICTIM_07` | — | **№7** 160 sp, 600 мс дүүрнэ |
// | 5 | `DAY_START` | 1800 мс дараа | «Өдөр 2» |
// | 6 | `WHISPER` «Хот шивнэж байна.» | 2.0 сек дараа | «Шивнээ: 3 · 10» |
//
// **ХОЁР-ГУРАВ-ДӨРӨВ БОЛ ИНВАРИАНТ N14.** `DAWN_A` ба `DAWN_VICTIM_nn` нь
// хоёр ТУСДАА аудио файл; хоорондох 2500 мс-ийг кодек ч, яарсан хөгжүүлэгч ч
// хааж чадахгүй. Энэ дэлгэц тэр завсрыг **дэлгэц дээрх бодит өнгөрсөн цаг**
// болгоно — алгасах зам байхгүй, товч байхгүй, урагшлуулах дохио байхгүй.
// Аудио унтраалттай байсан ч завсар хэвээр: завсар нь дуунд биш, УРСГАЛД
// байна.
//
// Дараалал нь энэ файлын шийдвэр БИШ — `NightReport.cues`-ыг ЯГ ТЭР
// ДАРААЛЛААР нь гүйцэтгэнэ (GDD-05 §9.3). Клипийн ID-г GDD-07 §2.6 эзэмшинэ.
//
// **Шивнээний дугаарууд аудиогоор ХЭЗЭЭ Ч хэлэгдэхгүй** (GDD-07 §2.6,
// `CueScreenSeats`) — хоолой «Хот шивнэж байна.» гэж хэлээд зогсоно, ширээнээс
// хэн нэг нь дэлгэцээс уншина. Мафи бас товшдог тул энэ мэдээлэл
// БАТЛАГДАШГҮЙ — өрөө захирагдахын оронд маргах ёстой.
//
// ГАР УТАС: хохирогчийн дугаар 160 sp бөгөөд 360 (бас 320) логик px-д
// `FittedBox`-оор багтана — «№12» нь хэвээрээ бол мөр халина.

import 'dart:async';

import 'package:engine/engine.dart';
import 'package:flutter/material.dart' hide Intent;

import '../game/game_controller.dart';
import '../ui/platform_guard.dart';
import '../ui/tokens.dart';
import '../ui/widgets.dart';

// ---------------------------------------------------------------------------
// Хугацаа — GDD-06 S11-ийн хүснэгт
// ---------------------------------------------------------------------------

/// Мөр 1 — салхи зогсож, нүүрс дүүрнэ.
const Duration kDawnEmber = Duration(milliseconds: 1500);

/// Мөр 4 — хохирогчийн дугаар дүүрэх.
const Duration kDawnVictimFill = Duration(milliseconds: 600);

/// Мөр 5 — `DAY_START` хохирогчийн ДАРАА (GDD-07 §3-ын мөр 14).
const Duration kDawnDayDelay = Duration(milliseconds: 1800);

/// Мөр 6 — «Хот шивнэж байна.»
const Duration kDawnWhisperDelay = Duration(milliseconds: 2000);

/// Мөр 6 — дугаарууд мөрийн дараа.
const Duration kDawnWhisperSeats = Duration(milliseconds: 600);

/// «Хот сэрлээ. Бүгд нүдээ нээ.» — GDD-07 §2.
const String kClipDayStart = 'DAY_START';

class DawnScreen extends StatefulWidget {
  const DawnScreen({
    super.key,
    required this.controller,
    required this.onDone,
    this.onCue,
  });

  final GameController controller;

  /// Үүр дуусав — S12 (эхний хохирогч бол) эсвэл S13 руу.
  final VoidCallback onDone;

  /// Аудио давхарга холбогдох цэг. Энэ дэлгэц дуу тоглуулахгүй, зөвхөн дуудна.
  /// **Шивнээний дугаарууд энд ХЭЗЭЭ Ч дамжихгүй.**
  final void Function(String clipId)? onCue;

  @override
  State<DawnScreen> createState() => _DawnScreenState();
}

/// Нэг алхам: `delay` хүлээгээд `run`-г гүйцэтгэнэ. Хүлээлт нь БОДИТ.
typedef _DawnStep = ({Duration delay, VoidCallback run});

class _DawnScreenState extends State<DawnScreen> {
  final List<_DawnStep> _script = <_DawnStep>[];
  int _step = 0;
  Timer? _timer;

  Seat? _victim;
  bool _noKill = false;
  String? _dayLabel;
  bool _whisperLine = false;
  List<Seat> _whisperSeats = const <Seat>[];
  bool _finished = false;

  GameController get _c => widget.controller;

  @override
  void initState() {
    super.initState();
    // `DawnRoute` — FLAG_SECURE УНТРААЛТТАЙ (GDD-06 §0-ын route хүснэгт).
    PlatformGuard.setSecure(false);
    _buildScript();
    _runStep();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // --- Скрипт нь `cues`-аас ГАРНА, энд зохиогдохгүй -------------------------

  void _buildScript() {
    // Мөр 1 — салхи зогсоно, нүүрс 1.5 секундэд дүүрнэ. Дэлгэц дээр өөр юу ч
    // байхгүй тул энэ алхам нь ЗӨВХӨН хүлээлт.
    _script.add((delay: kDawnEmber, run: () {}));

    final NightReport? r = _c.report;
    if (r == null) {
      _script.add((delay: Duration.zero, run: _finish));
      return;
    }

    for (final Cue cue in r.cues) {
      switch (cue) {
        case CueSilence(ms: final int ms):
          // Мөр 3 — **БОДИТ** 2500 мс. Энэ бол N14, алгасах зам байхгүй.
          _script.add((
            delay: Duration(milliseconds: ms),
            run: () {},
          ));

        case CueLine(clipId: final String id):
          // Мөр 6 — «Хот шивнэж байна.» нь `DAY_START`-аас 2.0 секундын дараа.
          _script.add((
            delay: id == kClipWhisper ? kDawnWhisperDelay : Duration.zero,
            run: () {
              widget.onCue?.call(id);
              setState(() {
                if (id == kClipDawnA) {
                  // Мөр 2 — дэлгэц ХООСОН.
                  _victim = null;
                  _noKill = false;
                } else if (id == kClipDawnNoKill) {
                  _noKill = true;
                } else if (id == kClipWhisper) {
                  _whisperLine = true;
                } else if (id.startsWith('DAWN_VICTIM_')) {
                  _victim = r.deaths.isEmpty ? null : r.deaths.first.victim;
                }
              });
            },
          ));
          // Мөр 5 — хохирогч (эсвэл хохирогчгүй) мөрийн 1800 мс ДАРАА.
          if (id == kClipDawnNoKill || id.startsWith('DAWN_VICTIM_')) {
            _script.add((
              delay: kDawnDayDelay,
              run: () {
                widget.onCue?.call(kClipDayStart);
                setState(() => _dayLabel = 'Өдөр ${_c.dayNo + 1}');
              },
            ));
          }

        case CueScreenSeats(seats: final List<Seat> seats):
          // Мөр 6 — ЗӨВХӨН дэлгэц. `onCue` энд дуудагдахгүй.
          _script.add((
            delay: kDawnWhisperSeats,
            run: () => setState(() => _whisperSeats = List<Seat>.of(seats)),
          ));
      }
    }

    _script.add((delay: Duration.zero, run: _finish));
  }

  void _runStep() {
    if (_step >= _script.length) return;
    final _DawnStep s = _script[_step];
    _timer?.cancel();
    final Duration d = s.delay;
    if (d == Duration.zero) {
      s.run();
      _step++;
      _runStep();
      return;
    }
    _timer = Timer(d, () {
      if (!mounted) return;
      s.run();
      _step++;
      _runStep();
    });
  }

  void _finish() {
    if (_finished) return;
    setState(() => _finished = true);
  }

  // --- Дүрслэл --------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final bool reduce = _c.settings.reduceMotion;

    return PhoneScaffold(
      // 40 % гэрэл — тодролын API байхгүй тул суурь өнгөөр дүйцүүлнэ.
      background: kSurface,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const SizedBox(height: kGutter),
          _Ember(reduceMotion: reduce),
          const SizedBox(height: kGutter),

          // Мөр 2–3: дэлгэц ХООСОН. Тэр хоосон нь тоглоомын хамгийн
          // хурцадмал агшин — түүнийг юугаар ч дүүргэхгүй.
          if (_victim != null)
            _VictimNumber(seat: _victim!, reduceMotion: reduce)
          else if (_noKill)
            Text(
              'Өнөө шөнө хохирогч гарсангүй.',
              textAlign: TextAlign.center,
              style: kTitle.copyWith(color: kTextPrimary, height: 1.45),
            ),

          if (_dayLabel != null) ...<Widget>[
            const SizedBox(height: kGutter),
            Text(
              _dayLabel!,
              textAlign: TextAlign.center,
              style: kDisplay.copyWith(color: kEmber, height: 1.45),
            ),
          ],

          if (_whisperLine) ...<Widget>[
            const SizedBox(height: kGutter),
            Text(
              'Хот шивнэж байна.',
              textAlign: TextAlign.center,
              style: kBody.copyWith(color: kTextMuted),
            ),
          ],

          if (_whisperSeats.isNotEmpty) ...<Widget>[
            const SizedBox(height: kGap),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                'Шивнээ: ${_whisperSeats.join(' · ')}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 44,
                  height: 1.45,
                  fontWeight: FontWeight.w700,
                  color: kTextPrimary,
                ),
              ),
            ),
          ],
        ],
      ),
      // Товч нь урсгал ДУУСМАГЦ л гарна — чимээгүйн дунд алгасах зам байхгүй.
      action: _finished
          ? FilledButton(
              onPressed: widget.onDone,
              child: const Text('Үргэлжлүүлэх'),
            )
          : null,
    );
  }
}

/// Улбар шар нүүрс — 1.5 секундэд дүүрнэ. Хөдөлгөөн багасгах горимд шууд асна.
class _Ember extends StatelessWidget {
  const _Ember({required this.reduceMotion});
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    final Widget coal = Container(
      height: 8,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        gradient: const LinearGradient(
          colors: <Color>[kSurfaceHigh, kEmber, kSurfaceHigh],
        ),
      ),
    );
    if (reduceMotion) return coal;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: kDawnEmber,
      builder: (BuildContext context, double t, Widget? child) =>
          Align(alignment: Alignment.centerLeft, widthFactor: 1.0,
              child: Opacity(opacity: t, child: child)),
      child: coal,
    );
  }
}

/// Хохирогчийн дугаар — 160 sp, хоёр метрээс уншигдана.
/// `FittedBox` нь 320 логик px дээр «№12»-ыг багтаана.
class _VictimNumber extends StatelessWidget {
  const _VictimNumber({required this.seat, required this.reduceMotion});
  final Seat seat;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    final Widget number = SizedBox(
      width: double.infinity,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          '№$seat',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 160,
            height: 1.0,
            fontWeight: FontWeight.w700,
            color: kTextPrimary,
          ),
        ),
      ),
    );
    if (reduceMotion) return number;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: kDawnVictimFill,
      builder: (BuildContext context, double t, Widget? child) =>
          Opacity(opacity: t, child: child),
      child: number,
    );
  }
}
