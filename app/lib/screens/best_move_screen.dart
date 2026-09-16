// S12 — Шилдэг нүүдэл (GDD-06 §S12, GDD-01 §1-ийн 10-р мөр).
//
// Зөвхөн **тоглолтын эхний хохирогч**, зөвхөн **нэг удаа**, яг **20 секунд**.
//
// Дэлгэц: «Шилдэг нүүдэл — 20 секунд. Гурван дугаар сонго.» Амьд суудлын тор,
// гурван сонголт, цагираг 20 секундэд дүүрнэ. Дараа нь хөтлөгч уншина:
// «Шилдэг нүүдэл: гурав, долоо, арав.» Тэгээд **МАРТАНА**.
//
// **ОНОО БАЙХГҮЙ. ТЭМДЭГ БАЙХГҮЙ. ЗӨВ ЭСЭХИЙГ ШАЛГАХ ЗҮЙЛ БАЙХГҮЙ. ДЭВТЭРТ
// БИЧИГДЭХГҮЙ.** ФСМ-ийн +0.5 / +0.25 үнэлгээ **ЗОРИУД** хасагдсан — аппыг
// дүгнэмэгц маргаан нь тэргүүлэгчдийн самбар болно (GDD-00-ийн татгалзал).
// Тиймээс энэ файлд оноо тооцох функц БАЙХГҮЙ, дүр уншдаг дуудлага БАЙХГҮЙ,
// сонголтыг хадгалах талбар БАЙХГҮЙ: гурван дугаар нь виджетийн төлөвт
// амьдарч, дэлгэц хаагдахад үхнэ.
//
// **Гурван дугаар зөвхөн ДЭЛГЭЦ ДЭЭР** (≥ 40 sp) — хоолой `BESTMOVE_READ`
// («Шилдэг нүүдэл —») гэж хэлээд зогсоно, ширээ өөрөө чангаар уншина
// (GDD-07 §2.6: кардинал клипүүд v2-т).
//
// ГАР УТАС: тор доод хоёр гуравны хэсэгт, «Уншуулах» нь доод зах, 72 dp.

import 'dart:async';

import 'package:engine/engine.dart' show Seat;
import 'package:flutter/material.dart' hide Intent;

import '../game/game_controller.dart';
import '../ui/platform_guard.dart';
import '../ui/scenery.dart';
import '../ui/tokens.dart';
import '../ui/widgets.dart';

/// Яг хорин секунд. `BESTMOVE_START` клипэд бичигдсэн тоо.
const Duration kBestMoveWindow = Duration(seconds: 20);

/// Дотоод цохилт — тестэд детерминист.
const Duration kBestMoveTick = Duration(milliseconds: 100);

/// Гурав. Нэмэгдэхгүй, хасагдахгүй.
const int kBestMovePicks = 3;

const String kClipBestMoveStart = 'BESTMOVE_START';
const String kClipBestMoveRead = 'BESTMOVE_READ';

enum BestMoveStage {
  /// `picking(0..3)` — сонгогдсон дугаар тодорно, цагираг дүүрнэ.
  picking,

  /// `speaking` — гурван дугаар том, ширээ уншина.
  speaking,
}

class BestMoveScreen extends StatefulWidget {
  const BestMoveScreen({
    super.key,
    required this.controller,
    required this.onDone,
    this.onCue,
  });

  final GameController controller;

  /// Уншигдлаа (эсвэл сонголтгүй өнгөрлөө) — S13 руу.
  final VoidCallback onDone;

  final void Function(String clipId)? onCue;

  /// Энэ дэлгэц харагдах ёстой юу: **эхний хохирогч, нэг л удаа**, бөгөөд
  /// «Шинэ тоглогч» багцад `bestMove = үгүй` (GDD-11 §34).
  static bool isDue(GameController c) =>
      c.settings.bestMove && c.firstVictim != null && !c.bestMoveSpoken;

  @override
  State<BestMoveScreen> createState() => _BestMoveScreenState();
}

class _BestMoveScreenState extends State<BestMoveScreen> {
  Timer? _tick;
  int _elapsedMs = 0;

  /// Гурван дугаар. **Энэ жагсаалт хаанаас ч гарахгүй** — дэлгэц хаагдахад үхнэ.
  final List<Seat> _picks = <Seat>[];

  BestMoveStage _stage = BestMoveStage.picking;

  GameController get _c => widget.controller;

  @override
  void initState() {
    super.initState();
    // `DawnRoute` — FLAG_SECURE унтраалттай (GDD-06 §0). Дүр энд гарахгүй.
    PlatformGuard.setSecure(false);
    widget.onCue?.call(kClipBestMoveStart);
    _tick = Timer.periodic(kBestMoveTick, (_) => _onTick());
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  void _onTick() {
    if (!mounted) return;
    _elapsedMs += kBestMoveTick.inMilliseconds;
    if (_elapsedMs >= kBestMoveWindow.inMilliseconds) {
      // `timeout` — сонгогдсоныг уншина (1 эсвэл 2 байж болно).
      _speak();
      return;
    }
    setState(() {});
  }

  int get _secondsLeft => ((kBestMoveWindow.inMilliseconds - _elapsedMs) / 1000)
      .ceil()
      .clamp(0, 20);

  void _toggle(Seat s) {
    if (_stage != BestMoveStage.picking) return;
    setState(() {
      if (_picks.contains(s)) {
        _picks.remove(s);
      } else if (_picks.length < kBestMovePicks) {
        _picks.add(s);
      }
    });
  }

  /// `none` — сонголтгүй бол **хөтлөгч юу ч хэлэхгүй**, шууд S13 руу.
  void _speak() {
    _tick?.cancel();
    _tick = null;
    _c.bestMoveSpoken = true;
    if (_picks.isEmpty) {
      widget.onDone();
      return;
    }
    _picks.sort();
    widget.onCue?.call(kClipBestMoveRead);
    setState(() => _stage = BestMoveStage.speaking);
  }

  @override
  Widget build(BuildContext context) {
    if (_stage == BestMoveStage.speaking) return _speakingScreen();
    return _pickingScreen();
  }

  Widget _pickingScreen() {
    final bool reduce = _c.settings.reduceMotion;
    final List<Seat> alive = _c.alive.toList()..sort();

    return PhoneScaffold(
      backdrop: const NightBackdrop(glow: 0.45, motes: 16, seed: 47),
      center: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'Шилдэг нүүдэл — 20 секунд. Гурван дугаар сонго.',
            style: kTitle.copyWith(color: kTextPrimary, height: 1.45),
          ),
          const SizedBox(height: kGutter),
          Center(
            child: reduce
                ? BigCountdown(_secondsLeft)
                : _BestMoveRing(
                    progress: (_elapsedMs / kBestMoveWindow.inMilliseconds)
                        .clamp(0.0, 1.0),
                    secondsLeft: _secondsLeft,
                  ),
          ),
          const SizedBox(height: kGutter),
          SeatGrid(
            seats: alive,
            onTap: _toggle,
            // Гурав сонгогдмогц үлдсэн нь бүдгэрнэ — дөрөв дэх сонголт байхгүй.
            enabled: (int s) =>
                _picks.contains(s) || _picks.length < kBestMovePicks,
            selected: (int s) => _picks.contains(s),
          ),
        ],
      ),
      action: SizedBox(
        // GDD-06 S12: «Уншуулах» нь доод зах, 72 dp.
        height: 72,
        child: FilledButton(
          // `ready` — гурав сонгогдмогц асна, 20 секунд ХҮЛЭЭХГҮЙ.
          onPressed: _picks.length == kBestMovePicks ? _speak : null,
          child: const Text('Уншуулах'),
        ),
      ),
    );
  }

  Widget _speakingScreen() {
    return PhoneScaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'Шилдэг нүүдэл —',
            textAlign: TextAlign.center,
            style: kBody.copyWith(color: kTextMuted),
          ),
          const SizedBox(height: kGutter),
          // ≥ 40 sp. 360 (бас 320) логик px-д `FittedBox`-оор багтана —
          // «12 · 17 · 20» нь хэвээрээ бол мөр халина.
          SizedBox(
            width: double.infinity,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                _picks.join(' · '),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 72,
                  height: 1.45,
                  fontWeight: FontWeight.w700,
                  color: kEmber,
                ),
              ),
            ),
          ),
          const SizedBox(height: kGutter),
          Text(
            'Ширээ чангаар уншина. Дараа нь мартана.',
            textAlign: TextAlign.center,
            style: kBody.copyWith(color: kTextMuted),
          ),
        ],
      ),
      action: FilledButton(
        onPressed: widget.onDone,
        child: const Text('Үргэлжлүүлэх'),
      ),
    );
  }
}

/// 20 секундэд дүүрэх цагираг. Хөдөлгөөн багасгах горимд `BigCountdown` болно.
class _BestMoveRing extends StatelessWidget {
  const _BestMoveRing({required this.progress, required this.secondsLeft});

  final double progress;
  final int secondsLeft;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 120,
    height: 120,
    child: CustomPaint(
      painter: _RingPainter(progress),
      child: Center(
        child: Text(
          '$secondsLeft',
          style: TextStyle(
            fontSize: 44,
            height: 1.0,
            fontWeight: FontWeight.w700,
            color: secondsLeft <= 5 ? kEmber : kTextPrimary,
          ),
        ),
      ),
    ),
  );
}

class _RingPainter extends CustomPainter {
  const _RingPainter(this.progress);
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    const double stroke = 8;
    final Rect r = Offset.zero & size;
    final Paint track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = kSurfaceHigh;
    final Paint arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = kEmber;
    canvas.drawArc(r.deflate(stroke / 2), 0, 6.283185, false, track);
    canvas.drawArc(
      r.deflate(stroke / 2),
      -1.570796,
      6.283185 * progress,
      false,
      arc,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress;
}
