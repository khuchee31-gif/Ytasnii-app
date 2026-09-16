// S05 — Дамжуулах завсрын дэлгэц (GDD-06 §S05).
//
// Бүтээгдэхүүний хамгийн хямд аюулгүйн механик. Тараалтын үед (S05) ба шөнийн
// эргэлтийн үед (S08) ЯГ ИЖИЛ виджет — тиймээс энэ нь дэлгэц биш, `HandoffGate`
// гэдэг дахин ашиглагдах хаалт.
//
// ХАТУУ ДҮРЭМ:
//   • `kHandoffLock` (600 мс) хаагдахгүй. Товшилт, шудрах, буцах — бүгд үл
//     хамаарна. Ингэснээр дараагийн хүн өмнөх илчлэлтийн сүүлийг харахгүй.
//   • ЧИЧИРГЭЭ БАЙХГҮЙ. Буруу гарт мэдрэгдсэн чичиргээ бол мэдээллийн суваг
//     (GDD-08 §7.2, tokens.dart-ын `Haptic`-ийн толгойн тайлбар).
//   • Дэлгэц 100% хар, ганц улбар шар дугаар. ЯМАР Ч ДҮРИЙН ҮГ БАЙХГҮЙ.
//
// ГАР УТАС: бүтэн дэлгэц нь хүрэх талбай — утас ширээн дээр нүүрээрээ доош
// хэвтэж байхад хүн түүнийг харалгүй өргөнө.

import 'dart:async';

import 'package:flutter/material.dart' hide Intent;

import '../ui/scenery.dart';
import '../ui/tokens.dart';

/// Акселерометргүй утсанд «өргөв» гэдгийг мэдэх боломжгүй — GDD-10 §5-ын
/// `LIFT_TIMEOUT_MS`. Энэ хугацааны дараа ил товч гарна, бүх суудалд ижил.
const Duration kLiftTimeout = Duration(milliseconds: 3000);

enum HandoffStage {
  /// 0–600 мс. Юу ч хүлээж авахгүй.
  locked,

  /// Товшилт эсвэл хөдөлгөөн → дараагийн дэлгэц.
  armed,
}

class HandoffGate extends StatefulWidget {
  const HandoffGate({
    super.key,
    required this.nextSeat,
    required this.onLift,
    this.skippedSeat,
    this.lock = kHandoffLock,
    this.liftTimeout = kLiftTimeout,
  });

  /// Дараагийн суудлын дугаар — дэлгэц дээрх цорын ганц улбар шар зүйл.
  final int nextSeat;

  /// Утас өргөгдсөн (эсвэл товшигдсон) — дараагийн гадаргуу руу.
  final VoidCallback onLift;

  /// Хасагдсан суудал алгасагдсан бол (GDD-06 S08): «№7 байхгүй. Дараах — №8».
  /// Энэ мөр 600 мс гарч, дараа нь хэвийн `locked` эхэлнэ.
  final int? skippedSeat;

  final Duration lock;
  final Duration liftTimeout;

  @override
  State<HandoffGate> createState() => _HandoffGateState();
}

class _HandoffGateState extends State<HandoffGate> {
  late bool _skipping = widget.skippedSeat != null;
  HandoffStage _stage = HandoffStage.locked;
  bool _showLiftButton = false;
  Timer? _skipTimer;
  Timer? _lockTimer;
  Timer? _liftTimer;

  @override
  void initState() {
    super.initState();
    if (_skipping) {
      _skipTimer = Timer(widget.lock, () {
        if (!mounted) return;
        setState(() => _skipping = false);
        _startLock();
      });
    } else {
      _startLock();
    }
  }

  void _startLock() {
    _lockTimer = Timer(widget.lock, () {
      if (!mounted) return;
      setState(() => _stage = HandoffStage.armed);
      // Өргөхийг мэдрэх сенсор байхгүй тул гурван секундын дараа ил товч.
      _liftTimer = Timer(widget.liftTimeout, () {
        if (!mounted) return;
        setState(() => _showLiftButton = true);
      });
    });
  }

  @override
  void dispose() {
    _skipTimer?.cancel();
    _lockTimer?.cancel();
    _liftTimer?.cancel();
    super.dispose();
  }

  void _lift() {
    if (_stage != HandoffStage.armed) return; // 600 мс дотор бүх оролт үхнэ.
    widget.onLift();
  }

  @override
  Widget build(BuildContext context) {
    final int n = widget.nextSeat;
    // Яг GDD-06 S05-ын мөр. Хоёр хэсэгт хуваагдсан ч `toPlainText()` нь
    // «Ширээн дээр тавь. Дараах — №7» хэвээр — тестийн шалгуур энэ.
    // ДУГААР НЬ МЕДАЛЬ ДОТОР том харагдана (доор), тиймээс өгүүлбэр дэх
    // «№7» нь ЖИЖИГ — хоёр удаа хашгирахгүй. Өгүүлбэрийн үг GDD-06 S05-аар
    // тогтсон тул үсэг бүр хэвээр.
    final Widget headline = Text.rich(
      TextSpan(
        style: kBody.copyWith(color: kTextMuted, height: 1.45),
        children: <InlineSpan>[
          const TextSpan(text: 'Ширээн дээр тавь. Дараах — '),
          TextSpan(
            text: '№$n',
            style: kBody.copyWith(
              color: kEmber,
              fontWeight: FontWeight.w700,
              height: 1.45,
            ),
          ),
        ],
      ),
      textAlign: TextAlign.center,
    );

    return PopScope(
      // Хаалт хаагдахгүй: буцах товч ч 600 мс дотор үл хамаарна.
      canPop: _stage == HandoffStage.armed,
      child: Scaffold(
        backgroundColor: kNight,
        body: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _lift,
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              // Хоосон хар дэлгэц бол алдаа. Маш нам гүм гэрэл, тоосны ширхэг —
              // ширээн дунд хэвтэх утас «унтарсан» биш «хүлээж буй» харагдана.
              const NightBackdrop(glow: 0.5, motes: 22),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: kGutter,
                    vertical: kGutter,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      if (_skipping)
                        Text(
                          '№${widget.skippedSeat} байхгүй. Дараах — №$n',
                          style: kBody.copyWith(color: kTextMuted),
                          textAlign: TextAlign.center,
                        )
                      else ...<Widget>[
                        // ГОЛ ДҮРС: суудлын медаль. Ширээний нөгөө талаас ч
                        // уншигдана — хэний ээлж болохыг хүн бүр шалгаж чадна.
                        Center(child: SeatMedallion(seat: n, size: 196)),
                        const SizedBox(height: 26),
                        headline,
                        const SizedBox(height: kGap),
                        // `armed` болтол энэ мөр хоосон — өндөр нь хэвээр тул
                        // текст гарахад дэлгэц үсрэхгүй.
                        SizedBox(
                          height: 56,
                          child: Center(
                            child: Text(
                              _stage == HandoffStage.armed
                                  ? '№$n — утсаа өргө'
                                  : '',
                              style: kBody.copyWith(color: kTextMuted),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                        SizedBox(
                          height: kPrimaryButtonHeight,
                          child: _showLiftButton
                              ? Center(
                                  child: TextButton(
                                    onPressed: _lift,
                                    style: TextButton.styleFrom(
                                      foregroundColor: kEmber,
                                      minimumSize: const Size(
                                        kMinTouch * 3,
                                        kPrimaryButtonHeight,
                                      ),
                                    ),
                                    child: const Text('Товшиж нээ'),
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ),
                      ],
                    ],
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

/// S05-ыг ганцаараа route болгон ашиглах бүрхүүл. Тараалтын ёслолын дотор
/// `RevealScreen` нь `HandoffGate`-ыг шууд ашиглана.
class HandoffScreen extends StatelessWidget {
  const HandoffScreen({
    super.key,
    required this.nextSeat,
    required this.onLift,
    this.skippedSeat,
  });

  final int nextSeat;
  final int? skippedSeat;
  final VoidCallback onLift;

  @override
  Widget build(BuildContext context) =>
      HandoffGate(nextSeat: nextSeat, skippedSeat: skippedSeat, onLift: onLift);
}
