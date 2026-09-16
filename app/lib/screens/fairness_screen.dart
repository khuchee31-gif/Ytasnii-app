// S04 — Шударга байдлын код (GDD-06 §S04, GDD-10 §2 ба §3).
//
// Амлалтын алхам. Дараалал нь ХАТУУ бөгөөд нэг ч шат сэлгэгдэхгүй:
//
//   1. `seed0` (32 байт) аль хэдийн төрсөн (`GameController.beginFairness`),
//      түүний hash-аас зургаан цифрийн код ГАРНА — хөзөр хараахан тараагдаагүй.
//   2. Утас БАРИХГҮЙ хүн (hash-аас сонгогдсон `readerSeat`) кодыг чангаар
//      уншиж, дэвтрийн буланд бичнэ. Гараар өөрчлөх UI БАЙХГҮЙ.
//   3. Тэр суудал хүний энтропи өгнө.
//   4. ЗӨВХӨН ТЭГЭЭД хуваарилалт хийгдэнэ (`dealWithEntropy`).
//
// СЕНСОРЫН ТУХАЙ ШУДАРГА ТЭМДЭГЛЭЛ: v1-д акселерометрийн пакет НЭМЭГДЭЭГҮЙ
// (GDD-14-ийн хамаарлын төсөв). Тиймээс «сэгсрэлт» нь дараад-барих талбай
// болж хэрэгжсэн: хүний хуруу 2.0 секунд дарж, гулсуулж, тавина. Энтропи нь
// хүрэлтийн байрлалын дээж БА тавьсан агшны микросекундээс бүрдэнэ — аль аль
// нь ХҮНИЙХ, аппын `Random` БИШ. Мэдрэгч ажиллахгүй утасны гарц (дөрвөн цифр)
// нь GDD-10 §2-ын `noSensor` замтай үг үсгээр ижил.
//
// ГАР УТАС: код нь 96 sp — 360px өргөнд долоон тэмдэгт багтахгүй тул
// `FittedBox` жижигрүүлнэ. Үндсэн үйлдэл доод талд, `PhoneScaffold`-оор.

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart' hide Intent;

import '../game/game_controller.dart';
import '../ui/platform_guard.dart';
import '../ui/tokens.dart';
import '../ui/widgets.dart';
import '../ui/glyphs.dart';

/// GDD-06 S04-ийн төлөвийн хүснэгт.
enum FairnessStage { showCode, askShake, noSensor, sealed }

/// Сэгсрэлтийн хуримтлал — GDD-06 S04: «2.0 сек хуримтлал».
const Duration kShakeTarget = Duration(milliseconds: 2000);

/// «Түгжигдлээ.» мөр хэдэн хугацаа зогсох вэ (GDD-06 S04).
const Duration kSealedHold = Duration(milliseconds: 600);

class FairnessScreen extends StatefulWidget {
  const FairnessScreen({
    super.key,
    required this.controller,
    required this.onSealed,
  });

  final GameController controller;

  /// Хуваарилалт хийгдсэний дараа — S05 руу.
  final VoidCallback onSealed;

  @override
  State<FairnessScreen> createState() => _FairnessScreenState();
}

class _FairnessScreenState extends State<FairnessScreen> {
  FairnessStage _stage = FairnessStage.showCode;

  // --- Сэгсрэлт ------------------------------------------------------------
  final List<int> _entropy = <int>[];
  final Stopwatch _shakeWatch = Stopwatch();
  Timer? _shakeTicker;
  int _shakeMs = 0;
  bool _holding = false;

  // --- Дөрвөн цифр ---------------------------------------------------------
  String _digits = '';

  Timer? _sealTimer;

  @override
  void initState() {
    super.initState();
    // `DealRoute` бүхэлдээ хамгаалагдана (GDD-06 §0-ын route хүснэгт).
    PlatformGuard.setSecure(true);
    PlatformGuard.setKeepAwake(widget.controller.settings.keepAwake);
  }

  @override
  void dispose() {
    _shakeTicker?.cancel();
    _sealTimer?.cancel();
    super.dispose();
  }

  // --- Сэгсрэлтийн хуримтлал ----------------------------------------------

  void _holdStart(Offset p) {
    if (_holding) return;
    _holding = true;
    _shakeWatch.start();
    _sample(p);
    _shakeTicker = Timer.periodic(const Duration(milliseconds: 50), (Timer t) {
      if (!mounted) return;
      setState(() => _shakeMs += 50);
      if (_shakeMs >= kShakeTarget.inMilliseconds) {
        _holdEnd();
        _seal(Uint8List.fromList(_entropyBytes()));
      }
    });
  }

  void _holdEnd() {
    _shakeTicker?.cancel();
    _shakeTicker = null;
    _shakeWatch.stop();
    _holding = false;
  }

  /// Хүрэлтийн байрлалын дээж. Хүний гар чичрэх нь энтропийн эх сурвалж.
  void _sample(Offset p) {
    if (_entropy.length >= 60) return;
    _entropy.add(p.dx.round() & 0xFF);
    _entropy.add(p.dy.round() & 0xFF);
  }

  /// Дээж + тавьсан агшны микросекунд. `Random` ЭНД ОРОХГҮЙ — энтропи нь
  /// хүнийх байх ёстой, эс бөгөөс ёслол нь жүжиг болно.
  List<int> _entropyBytes() {
    final int us = _shakeWatch.elapsedMicroseconds;
    return <int>[
      ..._entropy,
      (us >> 24) & 0xFF,
      (us >> 16) & 0xFF,
      (us >> 8) & 0xFF,
      us & 0xFF,
    ];
  }

  // --- Түгжих --------------------------------------------------------------

  void _seal(Uint8List userEntropy) {
    if (_stage == FairnessStage.sealed) return;
    setState(() => _stage = FairnessStage.sealed);
    if (widget.controller.settings.haptics) {
      Haptic.heavy(); // GDD-06 S04: «чичиргээ 40 мс».
    }
    // Хуваарилалт ЯГ ЭНЭ МӨЧИД — өмнө ч биш, хойно ч биш (GDD-10 §3).
    widget.controller.dealWithEntropy(userEntropy);
    _sealTimer = Timer(kSealedHold, () {
      if (mounted) widget.onSealed();
    });
  }

  void _pressDigit(String d) {
    if (_digits.length >= 4) return;
    setState(() => _digits += d);
  }

  void _backspace() {
    if (_digits.isEmpty) return;
    setState(() => _digits = _digits.substring(0, _digits.length - 1));
  }

  // --- Бүтэц ---------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final GameController c = widget.controller;
    final int reader = c.previewReaderSeat;

    return switch (_stage) {
      FairnessStage.showCode => _buildShowCode(c, reader),
      FairnessStage.askShake => _buildShake(c, reader),
      FairnessStage.noSensor => _buildDigits(reader),
      FairnessStage.sealed => _buildSealed(),
    };
  }

  Widget _buildShowCode(GameController c, int reader) {
    return PhoneScaffold(
      title: 'Шударга байдлын код',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const SizedBox(height: kGap),
          // 96 sp (GDD-06 S04). 360px-д долоон тэмдэгт багтахгүй тул
          // `FittedBox` нь ХЭМЖЭЭГ БУУРУУЛНА, мөрийг ХЭЗЭЭ Ч таслахгүй.
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              c.previewCode,
              maxLines: 1,
              style: const TextStyle(
                fontSize: 96,
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
                height: 1.15,
                color: kTextPrimary,
              ),
            ),
          ),
          const SizedBox(height: 8),
          // `dealId`: 8 hex, монобичгээр, 10% тунгалаг (GDD-10 §2).
          Text(
            c.previewDealId,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.45,
              fontFamily: 'monospace',
              color: kTextPrimary.withValues(alpha: 0.10),
            ),
          ),
          const SizedBox(height: kGutter),
          InfoCard(
            children: <Widget>[
              Text(
                'Утас барихгүй хүн уншиж, дэвтрийнхээ буланд бич.',
                style: kBody.copyWith(color: kTextPrimary),
              ),
              const SizedBox(height: kGap),
              Text(
                '№$reader — уншаарай.',
                style: kTitle.copyWith(color: kEmber, height: 1.45),
              ),
            ],
          ),
          const SizedBox(height: kGap),
          Text(
            'Зургаан цифрийг апп хэлэхгүй. №$reader өөрөө чангаар уншина.',
            style: kBody.copyWith(color: kTextMuted),
          ),
        ],
      ),
      action: FilledButton(
        onPressed: () => setState(() => _stage = FairnessStage.askShake),
        child: const Text('Бичиж авлаа'),
      ),
    );
  }

  Widget _buildShake(GameController c, int reader) {
    final double t = (_shakeMs / kShakeTarget.inMilliseconds)
        .clamp(0.0, 1.0)
        .toDouble();
    return PhoneScaffold(
      title: '№$reader — утсаа хоёр секунд сэгсэр.',
      subtitle: 'Утсыг барьж, дарж, хоёр секунд сэг.',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const SizedBox(height: kGap),
          Listener(
            key: const ValueKey<String>('shakePad'),
            onPointerDown: (PointerDownEvent e) => _holdStart(e.localPosition),
            onPointerMove: (PointerMoveEvent e) => _sample(e.localPosition),
            onPointerUp: (PointerUpEvent _) => _holdEnd(),
            onPointerCancel: (PointerCancelEvent _) => _holdEnd(),
            child: Semantics(
              button: true,
              label: 'Сэгсрэх талбай. Дарж хоёр секунд бариарай.',
              child: Container(
                height: 180,
                decoration: BoxDecoration(
                  color: kSurfaceRaised,
                  borderRadius: BorderRadius.circular(kRadius),
                  border: Border.all(color: kEmber.withValues(alpha: 0.6)),
                ),
                alignment: Alignment.center,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Text(
                      _holding ? 'Бариад сэг…' : 'Энд дараад сэгс',
                      style: kTitle.copyWith(color: kTextPrimary, height: 1.45),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: kGap),
                    // Хөдөлгөөн багасгах горимд цагираг нь ТОО болно
                    // (GDD-06 §0-ын хүртээмжийн дүрэм 2).
                    if (c.settings.reduceMotion)
                      Text(
                        '${(t * 100).round()} %',
                        style: kBody.copyWith(color: kTextMuted),
                      )
                    else
                      SizedBox(
                        height: 10,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(5),
                          child: LinearProgressIndicator(
                            value: t,
                            backgroundColor: kSurfaceHigh,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              kEmber,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: kGutter),
          Text(
            'Энэ утсанд хөдөлгөөний мэдрэгч байхгүй бол дөрвөн цифр оруул.',
            style: kBody.copyWith(color: kTextMuted),
          ),
        ],
      ),
      action: TextButton(
        onPressed: () {
          _holdEnd();
          setState(() => _stage = FairnessStage.noSensor);
        },
        style: TextButton.styleFrom(
          foregroundColor: kEmber,
          minimumSize: const Size.fromHeight(kPrimaryButtonHeight),
        ),
        child: const Text('Дөрвөн цифр оруул.'),
      ),
    );
  }

  Widget _buildDigits(int reader) {
    return PhoneScaffold(
      title: 'Дөрвөн цифр оруул.',
      subtitle: '№$reader — өөрийн мэдэх дөрвөн цифрийг шив.',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const SizedBox(height: kGap),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              for (int i = 0; i < 4; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Container(
                    width: 56,
                    height: 72,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: kSurfaceRaised,
                      borderRadius: BorderRadius.circular(kRadius),
                      border: Border.all(
                        color: i == _digits.length ? kEmber : kHairline,
                        width: i == _digits.length ? 2 : 1,
                      ),
                    ),
                    child: Text(
                      i < _digits.length ? _digits[i] : '',
                      style: const TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                        color: kTextPrimary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: kGutter),
          _Keypad(onDigit: _pressDigit, onBackspace: _backspace),
        ],
      ),
      action: FilledButton(
        onPressed: _digits.length == 4
            ? () => _seal(Uint8List.fromList(utf8.encode(_digits)))
            : null,
        child: const Text('Түгжих'),
      ),
    );
  }

  Widget _buildSealed() {
    return Scaffold(
      backgroundColor: kSurface,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(kGutter),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  'Түгжигдлээ.',
                  style: kDisplay.copyWith(color: kEmber, height: 1.2),
                ),
                const SizedBox(height: kGap),
                Text(
                  'Хөзөр тараагдлаа.',
                  style: kBody.copyWith(color: kTextMuted),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Цифрийн товчлуур. Системийн гар дуудахгүй — утас ширээн дунд, товчлуур нь
/// том байх ёстой. Товч бүр ≥ `kMinTouch`.
class _Keypad extends StatelessWidget {
  const _Keypad({required this.onDigit, required this.onBackspace});

  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;

  /// Устгах товчны дотоод тэмдэглэгээ. ҮСЭГ БИШ — зурагддаг тэмдэг тул
  /// фонтод байхын шаардлагагүй (`glyphs.dart`-ын тайлбарыг үз).
  static const String _kBackspace = 'BS';

  @override
  Widget build(BuildContext context) {
    const List<String> keys = <String>[
      '1', '2', '3', //
      '4', '5', '6', //
      '7', '8', '9', //
      '', '0', _kBackspace, //
    ];
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: kGap,
      crossAxisSpacing: kGap,
      childAspectRatio: 1.5,
      children: <Widget>[
        for (final String k in keys)
          if (k.isEmpty)
            const SizedBox.shrink()
          else
            Material(
              color: kSurfaceRaised,
              borderRadius: BorderRadius.circular(kRadius),
              child: InkWell(
                borderRadius: BorderRadius.circular(kRadius),
                onTap: () => k == _kBackspace ? onBackspace() : onDigit(k),
                child: Container(
                  constraints: const BoxConstraints(
                    minWidth: kMinTouch,
                    minHeight: kMinTouch,
                  ),
                  alignment: Alignment.center,
                  child: k == _kBackspace
                      ? const Mark(
                          MarkShape.backspace,
                          size: 28,
                          color: kTextPrimary,
                          weight: 2.2,
                        )
                      : Text(
                          k,
                          style: const TextStyle(
                            fontFamily: kDisplayFont,
                            fontSize: 28,
                            fontWeight: FontWeight.w600,
                            height: 1.2,
                            color: kTextPrimary,
                          ),
                        ),
                ),
              ),
            ),
      ],
    );
  }
}
