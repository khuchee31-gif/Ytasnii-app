// S18 «Бүжигт хүлэг» · S19 «Хөзрөө нээе» (GDD-06 §S18–S19, GDD-07 §2.9–2.10).
//
// Дараалал нь ГДД-06 S18-ынх: ЯЛАЛТЫН МӨР → 3,000 мс → «Бүжигт хүлэг» →
// «Хөзрөө нээе». (GDD-01 §1-ийн 18-р мөр хүлгийг ялалтын өмнө бичсэн байв;
// GDD-06 S18 ба GDD-07 §2.9 хоёул түүнийг ялалтын ДАРАА тавьдаг — хоёр эх
// нэгтэй тул тэрийг барив.)
//
// S18 — ХАМГИЙН ТҮРҮҮНД хасагдсан хүүхдэд. Ялагдлын дэлгэцийн ОРОНД. Морин
// уралдаанд сүүлчийн хүлгийг цоллож, ирэх жил түрүүлэхийг ерөөдөг ёслол.
// Энэ дэлгэц АЛГАСАГДАХГҮЙ, бас «ялагдал» гэсэн үг АГУУЛАХГҮЙ.
//
// S19 — зургаан шөнийн нуугдмал мэдээллийн төлөөс. ХӨЗРИЙН ТОР ХЭЗЭЭ Ч
// БАЙХГҮЙ: дэлгэц дээр ганц суудал, том, 1.2 секунд тутамд нэг. Алгасах товч
// байхгүй. Энэ бол багцын хамгийн өндөр сэтгэл хөдлөл ÷ хөгжүүлэлтийн цаг.

import 'dart:async';
import 'dart:math' as math;

import 'package:engine/engine.dart' show Role, Seat, WinState;
import 'package:flutter/material.dart' hide Intent;

import '../game/game_controller.dart';
import '../ui/tokens.dart';
import 'day_screen.dart' show TwoFingerSwipe;
import 'reveal_screen.dart' show cardCopyFor;

/// Ялалтын мөр → `HORSE` (GDD-07 §2.9).
const Duration kWinLineHold = Duration(milliseconds: 3000);

/// «Бүжигт хүлэг» ХААГДАХГҮЙ хугацаа (GDD-06 S18).
const Duration kHorseLock = Duration(milliseconds: 4000);

/// `SEAT_nn` → `REVEAL_ROLE_*` (GDD-07 §2.10).
const Duration kRevealFlip = Duration(milliseconds: 400);

/// Дүр гарснаас дараагийн суудал хүртэл (GDD-08 §2-ын чимээгүйн хүснэгт).
const Duration kRevealGap = Duration(milliseconds: 1200);

/// Дүрийн клипийн ID — GDD-07 §2.10. Каталогт яг таван мөр.
String revealClipFor(Role r) => switch (r) {
      Role.citizen => 'REVEAL_ROLE_CITIZEN',
      Role.killer => 'REVEAL_ROLE_KILLER',
      Role.boss => 'REVEAL_ROLE_BOSS',
      Role.doctor => 'REVEAL_ROLE_DOCTOR',
      Role.detective => 'REVEAL_ROLE_DETECTIVE',
    };

enum CeremonyStage {
  /// «Хотынхон ялалаа!» / «Мафи ялалаа!»
  winLine,

  /// S18
  horse,

  /// S19 — `flipping(k)`
  reveal,

  /// S19 — `done`
  done,
}

class CeremonyScreen extends StatefulWidget {
  const CeremonyScreen({
    super.key,
    required this.controller,
    required this.onAgain,
    required this.onLedger,
    this.onCue,
    this.startAt = CeremonyStage.winLine,
  });

  final GameController controller;

  /// «Дахин — ижил суудлаар» — `ROSTER`+`PRESET`-ыг хоёуланг нь алгасна.
  final VoidCallback onAgain;

  /// «Өнөөдрийн тэмдэглэл» — S20.
  final VoidCallback onLedger;

  final void Function(String clipId)? onCue;

  /// Зөвхөн тестэд.
  @visibleForTesting
  final CeremonyStage startAt;

  @override
  State<CeremonyScreen> createState() => _CeremonyScreenState();
}

class _CeremonyScreenState extends State<CeremonyScreen> {
  late CeremonyStage _stage;

  /// S18-ын 4.0 секунд хаагдсан эсэх.
  bool _horseArmed = false;

  /// S19: аль суудал дээр явж байна, дүр нь нээгдсэн эсэх.
  int _at = 0;
  bool _roleShown = false;
  bool _paused = false;

  Timer? _seq;

  GameController get c => widget.controller;
  List<Seat> get _seats =>
      List<Seat>.generate(c.seatCount, (int i) => i + 1);

  @override
  void initState() {
    super.initState();
    _stage = widget.startAt;
    switch (_stage) {
      case CeremonyStage.winLine:
        widget.onCue?.call(_winClip);
        _seq = Timer(kWinLineHold, _afterWinLine);
      case CeremonyStage.horse:
        _enterHorse();
      case CeremonyStage.reveal:
        _enterReveal();
      case CeremonyStage.done:
        break;
    }
  }

  @override
  void dispose() {
    _seq?.cancel();
    super.dispose();
  }

  String get _winClip =>
      c.win == WinState.mafi ? 'WIN_MAFIA' : 'WIN_TOWN';

  String get _winLineMn =>
      c.win == WinState.mafi ? 'Мафи ялалаа!' : 'Хотынхон ялалаа!';

  void _afterWinLine() {
    if (!mounted) return;
    // `skipped` — хэн ч хасагдаагүй бол хүлэг байхгүй, шууд S19 руу.
    if (c.firstOutSeats.isEmpty) {
      setState(_enterReveal);
    } else {
      setState(_enterHorse);
    }
  }

  void _enterHorse() {
    _stage = CeremonyStage.horse;
    _horseArmed = false;
    widget.onCue?.call('HORSE');
    _seq = Timer(kHorseLock, () {
      if (mounted) setState(() => _horseArmed = true);
    });
  }

  // --- S19 ------------------------------------------------------------------

  void _enterReveal() {
    _stage = CeremonyStage.reveal;
    _at = 0;
    _roleShown = false;
    widget.onCue?.call('REVEAL_OPEN');
    _announceSeat();
  }

  void _announceSeat() {
    final Seat s = _seats[_at];
    widget.onCue?.call('SEAT_${s.toString().padLeft(2, '0')}');
    _seq = Timer(kRevealFlip, _flipRole);
  }

  void _flipRole() {
    if (!mounted || _paused) return;
    final Seat s = _seats[_at];
    final Role? r = c.roleOf(s);
    if (r != null) widget.onCue?.call(revealClipFor(r));
    // Амьд гарсан хүнд нэмэлт мөр — «— амьд гарлаа.»
    if (c.alive.contains(s)) widget.onCue?.call('REVEAL_SURVIVOR');
    setState(() => _roleShown = true);
    _seq = Timer(kRevealGap, _nextSeat);
  }

  void _nextSeat() {
    if (!mounted || _paused) return;
    if (_at + 1 >= _seats.length) {
      widget.onCue?.call('REVEAL_END');
      setState(() => _stage = CeremonyStage.done);
      return;
    }
    setState(() {
      _at++;
      _roleShown = false;
    });
    _announceSeat();
  }

  /// Товшилт = завсарлага (хэн нэг нь хашгирч байна). Дахин товшилт = үргэлж.
  void _togglePause() {
    if (_stage != CeremonyStage.reveal) return;
    setState(() => _paused = !_paused);
    if (_paused) {
      _seq?.cancel();
      return;
    }
    // Үргэлжлүүлэх: хаана зогссоноо мэдэж, тэндээс нь эхэлнэ.
    _seq = Timer(_roleShown ? kRevealGap : kRevealFlip,
        _roleShown ? _nextSeat : _flipRole);
  }

  /// Алгасах ТОВЧ байхгүй — хоёр хуруугаар шудрах нь дараагийн суудал.
  void _pushNext() {
    if (_stage != CeremonyStage.reveal) return;
    _seq?.cancel();
    if (!_roleShown) {
      _flipRole();
    } else {
      _nextSeat();
    }
  }

  // --- Барилга --------------------------------------------------------------

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: kSurface,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(kGutter),
            child: switch (_stage) {
              CeremonyStage.winLine => _winView(),
              CeremonyStage.horse => _horseView(),
              CeremonyStage.reveal => _revealView(),
              CeremonyStage.done => _doneView(),
            },
          ),
        ),
      );

  Widget _winView() => Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(_winLineMn,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 44,
                  fontWeight: FontWeight.w700,
                  height: 1.45,
                  color: kEmber)),
        ),
      );

  // S18. «ялагдал» гэсэн үг энэ мод дотор БАЙХГҮЙ.
  Widget _horseView() {
    final String seats =
        c.firstOutSeats.map((Seat s) => '№$s').join(' · ');
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _horseArmed ? () => setState(_enterReveal) : null,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              'Бүжигт хүлэг — ирэх удаа түрүүлээрэй.',
              textAlign: TextAlign.center,
              style: kTitle.copyWith(
                  fontSize: 28, color: kTextPrimary, height: 1.45),
            ),
            const SizedBox(height: kGap),
            Text(
              c.firstOutWhenMn.isEmpty
                  ? seats
                  : '$seats · ${c.firstOutWhenMn}',
              textAlign: TextAlign.center,
              style: kBody.copyWith(color: kTextMuted),
            ),
            const SizedBox(height: kGutter),
            SizedBox(
              height: kMinTouch,
              child: Center(
                child: Text(
                  _horseArmed ? 'Товшиж үргэлжлүүл' : '',
                  style: kBody.copyWith(color: kEmber),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // S19 — ГАНЦ суудал, том. Тор ХЭЗЭЭ Ч БАЙХГҮЙ.
  Widget _revealView() {
    final Seat s = _seats[_at];
    final Role? r = c.roleOf(s);
    return TwoFingerSwipe(
      onSwipeAny: _pushNext,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _togglePause,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text('Хөзрөө нээе',
                textAlign: TextAlign.center,
                style: kLabel.copyWith(color: kTextMuted)),
            const SizedBox(height: kGutter),
            // Суудлын дугаар 48 sp.
            Text('№$s',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                    color: kTextMuted)),
            const SizedBox(height: kGap),
            // Дүрийн нэр 96 sp — нарийн дэлгэц дээр өөрөө багасна.
            SizedBox(
              height: 120,
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    _roleShown && r != null ? cardCopyFor(r).mechanic : '—',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 96,
                        fontWeight: FontWeight.w700,
                        height: 1.0,
                        color: _roleShown ? kEmber : kSurfaceHigh),
                  ),
                ),
              ),
            ),
            const SizedBox(height: kGap),
            SizedBox(
              height: 28,
              child: Center(
                child: Text(
                  _paused
                      ? 'Түр зогсоов — товшиж үргэлжлүүл'
                      : (_roleShown && c.alive.contains(s)
                          ? 'амьд гарлаа'
                          : ''),
                  style: kBody.copyWith(color: kTextMuted),
                ),
              ),
            ),
            const SizedBox(height: kGap),
            Text(
              '${math.min(_at + 1, _seats.length)} / ${_seats.length}',
              textAlign: TextAlign.center,
              style: kLabel.copyWith(color: kTextMuted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _doneView() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const Spacer(),
          Text('Хөзөр бүгд нээгдлээ.',
              textAlign: TextAlign.center,
              style: kTitle.copyWith(color: kTextPrimary, height: 1.45)),
          const Spacer(),
          FilledButton(
            onPressed: widget.onAgain,
            child: const Text('Дахин — ижил суудлаар'),
          ),
          const SizedBox(height: kGap),
          TextButton(
            onPressed: widget.onLedger,
            style: TextButton.styleFrom(
              foregroundColor: kEmber,
              minimumSize: const Size.fromHeight(kMinTouch),
            ),
            child: const Text('Өнөөдрийн тэмдэглэл'),
          ),
        ],
      );
}
