// S08 — Шөнийн дамжуулалт ба эргэлтийн жолоодлого (GDD-06 §S08).
//
// S05-ын `HandoffGate` шөнийн хувилбараар: **600 мс**, «Ширээн дээр тавь.
// Дараах — №7». Ялгаа нь хоёр:
//
//   1. Дэлгэцийн гэрэл 10 %-д баригдана, цагаан пиксел хаана ч байхгүй
//      (`kNight` суурь, `kEmber` ганц цэг). Тодролын API `PlatformGuard`-д
//      хараахан БАЙХГҮЙ тул бид хамгийн харанхуй өнгийг ашиглаж байна.
//   2. Дараагийн суудал нь **хасагдсан бол АЛГАСАГДАНА** — «№7 байхгүй.
//      Дараах — №8».
//
// **Яагаад хасагдсан суудал алгасагддаг вэ (GDD-15-ын засвар).** Энэ файлын
// эхний төсөлд хасагдсан суудал ч 6 секунд авах ёстой мэт санагдана — «цагийн
// ул мөр байж болохгүй» гэсэн шалтгаанаар. Тэр шалтгаан ҮНЭН БИШ: **хэн
// хасагдсаныг ширээ бүгд мэднэ**, тиймээс нуух цаг байхгүй. GDD-05-ын N22
// инвариант «**амьд** суудал бүр яг нэг `Intent`» гэдэг, GDD-02 §3 «зөвхөн
// амьд суудал» гэдэг, GDD-10 §5 «Хасагдсан суудал алгасагдана (GDD-06 S08)»
// гэдэг. Хасагдсан суудал тутам 8.7 секунд нэмэх нь GDD-01 §2-ын аль хэдийн
// 110 секунд болсон эргэлт дээр шууд ачаа болно. **Жигд хуурмаг нь ДҮРИЙН
// тухай, АМЬДРАЛЫН тухай биш.**
//
// Энэ файл дүр УНШИХГҮЙ. Дүр уншдаг дуудлага зөвхөн `reveal_screen.dart` ба
// `night_action_screen.dart`-д байна (GDD-10 §4-ийн CI шалгуур).

import 'package:flutter/material.dart' hide Intent;

import 'package:engine/engine.dart' show Ability, Seat;

import '../game/game_controller.dart';
import '../ui/platform_guard.dart';
import '../ui/tokens.dart';
import 'handoff_screen.dart';
import 'night_action_screen.dart';

enum CircuitLeg {
  /// S08 — 600 мс хаалт, дараа нь «утсаа өргө».
  handoff,

  /// S09 — суудлын цонх. Бүх суудалд ижил `nightSeatSeconds`.
  action,

  /// Бүх амьд суудал өнгөрлөө — шөнө лацдагдахад бэлэн.
  done,
}

class NightCircuitScreen extends StatefulWidget {
  const NightCircuitScreen({
    super.key,
    required this.controller,
    required this.onDone,
  });

  final GameController controller;

  /// Эргэлт дуусав. Дуудагч `resolveNightNow()`-г дуудаж, S11 руу орно.
  final VoidCallback onDone;

  @override
  State<NightCircuitScreen> createState() => _NightCircuitScreenState();
}

class _NightCircuitScreenState extends State<NightCircuitScreen> {
  CircuitLeg _leg = CircuitLeg.handoff;

  /// Яг сая алгасагдсан суудал — `HandoffGate`-ын `skip(k)` төлөв.
  Seat? _skipped;

  GameController get _c => widget.controller;

  @override
  void initState() {
    super.initState();
    // `NightRoute` — FLAG_SECURE асна, дэлгэц унтрахгүй (GDD-06 §0).
    PlatformGuard.setSecure(true);
    PlatformGuard.setKeepAwake(_c.settings.keepAwake);
    _seekLivingSeat(firstFrame: true);
  }

  @override
  void dispose() {
    PlatformGuard.setSecure(false);
    super.dispose();
  }

  /// Хасагдсан суудлуудыг алгасаж, дараагийн АМЬД суудал дээр зогсоно.
  ///
  /// Алгасах нь `submitIntent`-ээр хийгдэнэ: хянагч хасагдсан суудлын санааг
  /// бүртгэхгүй (N22), гэхдээ эргэлтийн индексийг урагшлуулна.
  void _seekLivingSeat({bool firstFrame = false}) {
    Seat? skipped;
    while (true) {
      final Seat? s = _c.currentSeat;
      if (s == null) {
        _leg = CircuitLeg.done;
        _skipped = null;
        if (firstFrame) {
          // `initState`-ийн дотор эцэг виджетийг барих үед `setState` дуудаж
          // болохгүй — нэг фрэйм хүлээнэ.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) widget.onDone();
          });
        } else {
          setState(() {});
          widget.onDone();
        }
        return;
      }
      if (_c.alive.contains(s)) break;
      skipped = s;
      _c.submitIntent(s, Ability.noAction, null);
    }

    if (firstFrame) {
      _leg = CircuitLeg.handoff;
      _skipped = skipped;
    } else {
      setState(() {
        _leg = CircuitLeg.handoff;
        _skipped = skipped;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final Seat? seat = _c.currentSeat;
    if (_leg == CircuitLeg.done || seat == null) {
      // Эргэлт дууссан — дуудагч шилжүүлтэл хар дэлгэц. Цагаан пиксел байхгүй.
      return const Scaffold(backgroundColor: kNight, body: SizedBox.expand());
    }

    if (_leg == CircuitLeg.handoff) {
      return HandoffGate(
        key: ValueKey<String>('handoff-$seat'),
        nextSeat: seat,
        skippedSeat: _skipped,
        onLift: () => setState(() => _leg = CircuitLeg.action),
      );
    }

    return NightActionScreen(
      key: ValueKey<String>('action-n${_c.nightNo}-s$seat'),
      controller: _c,
      seat: seat,
      // `NightActionScreen` цонх хаагдахад `submitIntent`-ийг ӨӨРӨӨ дуудна,
      // тиймээс энд индекс аль хэдийн урагшилсан байна.
      onFinished: _seekLivingSeat,
    );
  }
}
