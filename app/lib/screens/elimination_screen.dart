// S17 — Хасалт (GDD-06 §S17, GDD-07 §2.8-ын мөрийн бүтэц).
//
//   ELIM_A     «Ширээ шийдлээ.»
//              2,000 мс ЧИМЭЭГҮЙ — дэлгэц дээр ч юу ч байхгүй
//   SEAT_04    «Дөрөвдүгээр тоглогч.»
//              120 мс
//   ELIM_B     «Хотоос хөөгдлөө.»
//
// ДҮР НЭЭГДЭХГҮЙ. `Тохиргоо → Хасагдахад дүр нээх` анхдагчаар унтраалттай.
// Энэ бол S19-ийг ямар нэг үнэ цэнтэй болгодог зүйл — зургаан шөнийн
// нуугдмал мэдээллийн төлөөс тэнд л төлөгдөнө (GDD-00 §11, GDD-06 S19).
//
// Хасагдсан суудал ШИРЭЭНЭЭС ГАРДАГГҮЙ: өдөр 📌 дарж чадна, ёслолд орно.
// Тиймээс энэ дэлгэц «ялагдал» гэсэн үг агуулахгүй.

import 'dart:async';
import 'dart:math' as math;

import 'package:engine/engine.dart' show Role, Seat;
import 'package:flutter/material.dart' hide Intent;

import '../game/game_controller.dart';
import '../ui/tokens.dart';
import '../ui/widgets.dart';
import 'reveal_screen.dart' show cardCopyFor;

/// `ELIM_A` → `SEAT_nn` (GDD-08 §2-ын чимээгүйн хүснэгт).
const Duration kElimSilence = Duration(seconds: 2);

/// Суудлын дугаар дүүрэх хугацаа (GDD-06 S17).
const Duration kElimFill = Duration(milliseconds: 600);

/// `SEAT_nn` → `ELIM_B`.
const Duration kElimSeatGap = Duration(milliseconds: 120);

enum ElimStage {
  /// `ELIM_A` + 2,000 мс. Дэлгэц ХООСОН.
  hush,

  /// Дугаар(ууд) гарч, зураас татагдана.
  exiled,

  /// `lastWordsSeconds` — зөвхөн ӨДРИЙН саналаар хөөгдсөн хүнд (GDD-01 §1).
  lastWords,
}

class EliminationScreen extends StatefulWidget {
  const EliminationScreen({
    super.key,
    required this.controller,
    required this.seats,
    required this.onDone,
    this.onCue,
  });

  final GameController controller;

  /// Хөөгдсөн суудал(ууд). «Бүгдийн хувь заяа» дээр нэгээс олон.
  final List<Seat> seats;

  /// Сүүлчийн үг дуусав — `WIN_CHECK` руу.
  final VoidCallback onDone;

  final void Function(String clipId)? onCue;

  @override
  State<EliminationScreen> createState() => _EliminationScreenState();
}

class _EliminationScreenState extends State<EliminationScreen> {
  ElimStage _stage = ElimStage.hush;
  int _shown = 0;
  bool _elimB = false;
  int _secondsLeft = 0;

  Timer? _seq;
  Timer? _tick;

  GameController get c => widget.controller;
  List<Seat> get _seats => widget.seats;

  @override
  void initState() {
    super.initState();
    widget.onCue?.call('ELIM_A');
    _seq = Timer(kElimSilence, _showSeats);
  }

  @override
  void dispose() {
    _seq?.cancel();
    _tick?.cancel();
    super.dispose();
  }

  void _showSeats() {
    if (!mounted) return;
    setState(() {
      _stage = ElimStage.exiled;
      _shown = 0;
    });
    _announceNext();
  }

  void _announceNext() {
    if (!mounted) return;
    if (_shown >= _seats.length) {
      _seq = Timer(kElimSeatGap, () {
        if (!mounted) return;
        widget.onCue?.call('ELIM_B');
        _elimB = true;
        // Дүр нээгдэхгүй гэдгийг эхний гурван тоглолтод чангаар хэлнэ.
        if (!c.settings.revealRoleOnDeath && c.gamesPlayed < 3) {
          widget.onCue?.call('ELIM_NO_REVEAL');
        }
        setState(() {});
        _seq = Timer(kElimFill, _startLastWords);
      });
      return;
    }
    final Seat s = _seats[_shown];
    widget.onCue?.call('SEAT_${s.toString().padLeft(2, '0')}');
    setState(() => _shown++);
    _seq = Timer(kElimFill + kElimSeatGap, _announceNext);
  }

  void _startLastWords() {
    if (!mounted) return;
    final int total = c.settings.lastWordsSeconds;
    widget.onCue?.call('ELIM_LASTWORD');
    setState(() {
      _stage = ElimStage.lastWords;
      _secondsLeft = total;
    });
    if (total <= 0) {
      widget.onDone();
      return;
    }
    _tick = Timer.periodic(const Duration(seconds: 1), (Timer t) {
      if (!mounted) return;
      setState(() {
        _secondsLeft--;
        if (_secondsLeft <= 0) {
          t.cancel();
          widget.onDone();
        }
      });
    });
  }

  bool get _elimBSaid => _elimB;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSurface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(kGutter),
          child: switch (_stage) {
            // 2,000 мс — дэлгэц дээр НЭГ Ч ПИКСЕЛ хөдлөхгүй, юу ч байхгүй.
            ElimStage.hush => const SizedBox.expand(),
            ElimStage.exiled => _exiledView(),
            ElimStage.lastWords => _lastWordsView(),
          },
        ),
      ),
    );
  }

  Widget _numbers() => FittedBox(
    fit: BoxFit.scaleDown,
    child: Text(
      _seats.take(math.max(1, _shown)).map((Seat s) => '№$s').join(' · '),
      textAlign: TextAlign.center,
      style: const TextStyle(
        fontSize: 160,
        fontWeight: FontWeight.w700,
        height: 1.0,
        color: kTextPrimary,
      ),
    ),
  );

  Widget _exiledView() => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      Flexible(child: Center(child: _numbers())),
      if (_elimBSaid) ...<Widget>[
        const SizedBox(height: kGap),
        // «Зураас татагдана» — дугаарын доор.
        const Divider(height: 1, thickness: 2, color: kEmber),
        const SizedBox(height: kGap),
        Text(
          'Хотоос хөөгдлөө.',
          textAlign: TextAlign.center,
          style: kTitle.copyWith(color: kTextPrimary, height: 1.45),
        ),
        ..._revealLines(),
      ],
    ],
  );

  /// `revealRoleOnDeath` асаалттай ҮЕД Л. АУДИО БАЙХГҮЙ — `ROLE_*` гэсэн
  /// дүрээ зарлах клип каталогт байхгүй (GDD-07 §2.1).
  List<Widget> _revealLines() {
    if (!c.settings.revealRoleOnDeath) return const <Widget>[];
    return <Widget>[
      const SizedBox(height: kGap),
      for (final Seat s in _seats)
        Builder(
          builder: (BuildContext context) {
            final Role? r = c.roleOf(s);
            if (r == null) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                _seats.length == 1
                    ? 'Тэрээр ${cardCopyFor(r).mechanic} байлаа.'
                    : '№$s — ${cardCopyFor(r).mechanic} байлаа.',
                textAlign: TextAlign.center,
                style: kBody.copyWith(color: kTextMuted),
              ),
            );
          },
        ),
    ];
  }

  Widget _lastWordsView() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      const SizedBox(height: kGap),
      Text(
        _seats.map((Seat s) => '№$s').join(' · '),
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 48,
          fontWeight: FontWeight.w700,
          height: 1.2,
          color: kTextPrimary,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        'Сүүлчийн үг',
        textAlign: TextAlign.center,
        style: kTitle.copyWith(color: kTextPrimary, height: 1.45),
      ),
      Expanded(
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: BigCountdown(math.max(0, _secondsLeft)),
          ),
        ),
      ),
      FilledButton(
        onPressed: () {
          _tick?.cancel();
          widget.onDone();
        },
        child: const Text('Дуусгах'),
      ),
    ],
  );
}
