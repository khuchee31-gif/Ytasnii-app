// S07 — Танилцах шөнө (GDD-06 §S07, GDD-01 §1-ийн 7-р мөр).
//
// ДЭЛГЭЦ 100 % ХАР. Ямар ч товч, ямар ч тоолуур, ямар ч текст.
//
//   NIGHT_START   «Хот унтлаа. Бүгд нүдээ ань.»      4.0 сек
//   MAFIA_MEET    «Мафи сэр. Бие биеэ хараарай.»    60.0 сек ҮНЭМЛЭХҮЙ ЧИМЭЭГҮЙ
//   MAFIA_SLEEP   «Мафи унт.»                        1.2 сек
//
// АПП ЮУ Ч ХИЙХГҮЙ. ТЭР НЬ ЯГ ЗОРИЛГО НЬ. Жаран секунд бол ТОО, мэдрэмж биш —
// дэлгэц дээр тоолуур ГАРГАВАЛ арван хоёр хүүхэд нүдээ анихын оронд тоо хараад
// суух болно. Гурван хос нүд бодит ширээн дээгүүр бие биеэ олох тэр минут бол
// зургаан баримт бичгийн хамгийн хөгжилтэй агшин (GDD-02 §5).
//
// Хохирогч БАЙХГҮЙ (GDD-00 §5.4). `rescue` нь зөвхөн хөгжүүлэгчийн авралт:
// анги 40 секундэд бувтнаж эхэлбэл гурван товшилтоор гарна, бөгөөд тэр нь
// дэвтэрт `meetCutShort` болж бичигдэнэ (GDD-00 §13-ын 8-р асуулт).
//
// ГАР УТАС: утас ширээн дунд нүүрээрээ дээшээ хэвтэнэ. Дэлгэцийн гэрэл 10 %
// байх ёстой (GDD-06 §0) — тодролын API `PlatformGuard`-д хараахан БАЙХГҮЙ
// тул бид хамгийн харанхуй өнгийг (`kNight`) ашиглаж байна.

import 'dart:async';

import 'package:flutter/material.dart' hide Intent;

import '../game/game_controller.dart';
import '../ui/platform_guard.dart';
import '../ui/tokens.dart';

enum Night0Stage { nightStart, mafiaMeet, mafiaSleep }

/// GDD-01 §1: `NIGHT_START` дараах 4.0 секунд уур амьсгал ОРЖ ирнэ.
const Duration kNightStartHold = Duration(seconds: 4);

/// «Мафи унт.» — 1.2 сек.
const Duration kMafiaSleepHold = Duration(milliseconds: 1200);

/// Гурван товшилт энэ цонхны дотор орвол авралт гарна.
const Duration kRescueTapWindow = Duration(milliseconds: 1500);

class Night0Screen extends StatefulWidget {
  const Night0Screen({
    super.key,
    required this.controller,
    required this.onDone,
    this.onCue,
  });

  final GameController controller;

  /// Танилцах шөнө дуусав — шөнийн эргэлт рүү (S08).
  final VoidCallback onDone;

  /// Аудио давхарга холбогдох цэг: `NIGHT_START`, `MAFIA_MEET`, `MAFIA_SLEEP`.
  /// Клипийн ID нь GDD-07 §2-ынх; энэ дэлгэц дуу тоглуулахгүй, зөвхөн дуудна.
  final void Function(String clipId)? onCue;

  @override
  State<Night0Screen> createState() => _Night0ScreenState();
}

class _Night0ScreenState extends State<Night0Screen> {
  Night0Stage _stage = Night0Stage.nightStart;
  bool _askRescue = false;

  Timer? _stageTimer;
  Timer? _tapTimer;
  int _taps = 0;

  @override
  void initState() {
    super.initState();
    // `NightRoute` — FLAG_SECURE асаалттай (GDD-06 §0-ын route хүснэгт).
    PlatformGuard.setSecure(true);
    PlatformGuard.setKeepAwake(widget.controller.settings.keepAwake);
    widget.onCue?.call('NIGHT_START');
    _stageTimer = Timer(kNightStartHold, _startMeet);
  }

  @override
  void dispose() {
    _stageTimer?.cancel();
    _tapTimer?.cancel();
    PlatformGuard.setSecure(false);
    super.dispose();
  }

  void _startMeet() {
    if (!mounted) return;
    setState(() => _stage = Night0Stage.mafiaMeet);
    widget.onCue?.call('MAFIA_MEET');
    // `acquaintSeconds` нь тоглолт эхлэхэд царцсан (GDD-03 §2, анхдагч 60).
    _stageTimer = Timer(
      Duration(seconds: widget.controller.settings.acquaintSeconds),
      _startSleep,
    );
  }

  void _startSleep({bool cutShort = false}) {
    if (!mounted) return;
    if (cutShort) widget.controller.meetCutShort = true;
    _stageTimer?.cancel();
    setState(() {
      _askRescue = false;
      _stage = Night0Stage.mafiaSleep;
    });
    widget.onCue?.call('MAFIA_SLEEP');
    _stageTimer = Timer(kMafiaSleepHold, () {
      if (mounted) widget.onDone();
    });
  }

  /// Гурван товшилт — зөвхөн танилцах минутын дотор.
  void _onTap() {
    if (_stage != Night0Stage.mafiaMeet || _askRescue) return;
    _taps++;
    _tapTimer?.cancel();
    _tapTimer = Timer(kRescueTapWindow, () => _taps = 0);
    if (_taps >= 3) {
      _taps = 0;
      _tapTimer?.cancel();
      setState(() => _askRescue = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kNight,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _onTap,
        child: Semantics(
          // Дэлгэц дээр текст БАЙХГҮЙ — энэ шошго зөвхөн дэлгэц уншигчид.
          label: 'Танилцах шөнө. Дэлгэц хар. Утсаа ширээн дээр тавь.',
          child: SafeArea(
            child: _askRescue ? _rescueSheet() : const SizedBox.expand(),
          ),
        ),
      ),
    );
  }

  /// Хөгжүүлэгчийн авралт. Хар дэлгэцэн дээр гарах ЦОРЫН ГАНЦ гадаргуу.
  Widget _rescueSheet() => Center(
    child: Padding(
      padding: const EdgeInsets.all(kGutter),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'Танилцах шөнийг дуусгах уу?',
            textAlign: TextAlign.center,
            style: kTitle.copyWith(color: kTextPrimary, height: 1.45),
          ),
          const SizedBox(height: kGutter),
          FilledButton(
            onPressed: () => _startSleep(cutShort: true),
            child: const Text('Тийм — дуусга'),
          ),
          const SizedBox(height: kGap),
          TextButton(
            onPressed: () => setState(() => _askRescue = false),
            style: TextButton.styleFrom(
              foregroundColor: kTextMuted,
              minimumSize: const Size.fromHeight(kMinTouch),
            ),
            child: const Text('Үгүй — үргэлжлүүл'),
          ),
        ],
      ),
    ),
  );
}
