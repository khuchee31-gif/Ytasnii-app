// S06 — Хөзөр нээх, тараалтын ёслол (GDD-06 §S06, GDD-10 §6 ба §7).
//
// ЭНЭ БОЛ БҮТЭЭГДЭХҮҮНИЙ ГАРЫН ҮСЭГ. Жинхэнэ хөзрөөс сайн байх ёстой цорын
// ганц дэлгэц. Тиймээс дөрвөн тоог ХАТУУ барина:
//
//   `kHoldThreshold`  — санаархлын хугацаа, санамсаргүй хүрэлтийг үл хэрэгсэнэ
//   `kCardFlip`       — эргэлт
//   `kCardAutoHide`   — авто-нуулт (эхний гурван тоглолтод 4000 мс, GDD-11 §2)
//   `kCardHide`       — тавихад алга болох. Эргэлт БАЙХГҮЙ, шууд хар.
//
// Хоёр эрхий, нэг биш: хоёр гар банзал болмогц утсыг хажуу тийш хазайлгах ч,
// хөршид дамжуулах ч боломжгүй болно. Дээрээс нь хоёр эрхийн байрлал нь
// ширээн дээгүүр ХАРАГДАНА — хэн хөзрөө харж байгааг арван нэгэн хүн нэг
// харцаар мэднэ. Энэ бол хамгаалалт биш, БИЕИЙН ХЭЛ (GDD-10 §6).
//
// Дахин харах нь ХОРИГЛОГДООГҮЙ — «Би дүрээ мартчихлаа» бол бодит бүтэлгүйтэл.
// Гэхдээ үнэгүй биш: бүх ширээний өмнө зарлагдаж, `reviewCount` нэмэгдэнэ.
// Дэвтэрт ХЭЗЭЭ Ч бичигдэхгүй (GDD-10 §7, GDD-00 §11.3).
//
// Энэ файл `DealRoute`-ын бүтэн ёслолыг эзэмшинэ: суудал бүрт S05-ын
// `HandoffGate` → S06-ын хөзөр → дараагийн суудал. `FLAG_SECURE` нь route-ын
// турш асаалттай.

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show PathMetric;

import 'package:engine/engine.dart';
import 'package:flutter/material.dart' hide Intent;
import 'package:flutter/semantics.dart';

import '../game/game_controller.dart';
import '../ui/platform_guard.dart';
import '../ui/scenery.dart';
import '../ui/tokens.dart';
import 'handoff_screen.dart';
import '../ui/glyphs.dart';

// ---------------------------------------------------------------------------
// Хөзрийн хуулбар — GDD-02 §5. ШИНЭ ТЕКСТ БИЧИХ ХОРИОТОЙ.
// Шөнийн сануулга (GDD-11 §2) нь энэ `job` мөрийг ЯГ ИЖЛЭЭР ашиглана —
// нэг `String`, хоёр газар.
// ---------------------------------------------------------------------------

@immutable
class RoleCardCopy {
  const RoleCardCopy({
    required this.theme,
    required this.mechanic,
    required this.faction,
    required this.job,
    required this.advice,
  });

  /// Сэдэвчилсэн нэр — ЗӨВХӨН хувийн хөзөр ба дэлгэцийн шошго дээр.
  /// Хоолой үүнийг ХЭЗЭЭ Ч хэлэхгүй (GDD-00 §5.1, GDD-02 §6).
  final String theme;

  /// Механик нэр — хөтлөгчийн царцаасан толь.
  final String mechanic;

  final String faction;
  final String job;
  final String advice;
}

/// GDD-02 §5-ын хүснэгт, үг үсгээр. Сэдэвчилсэн нэрс нь 13 §4.1-ийн
/// «ШӨНИЙН ЧОНО» арьснаас.
RoleCardCopy cardCopyFor(Role r) => switch (r) {
  Role.citizen => const RoleCardCopy(
    theme: 'МАЛЧИН',
    mechanic: 'Иргэн',
    faction: 'Хотынхон',
    job: 'Шөнө сэжигтэй суудлаа товш. Өдөр ярь.',
    advice: 'Чамд чадвар байхгүй — чиний зэвсэг бол үг.',
  ),
  Role.doctor => const RoleCardCopy(
    theme: 'БАРИАЧ',
    mechanic: 'Эмч',
    faction: 'Хотынхон',
    job: 'Шөнө бүр нэг хүнийг алалтаас авар.',
    advice:
        'Дүрээ зарласан Мөрдөгчийг хамгаал. '
        'Нэг хүнийг хоёр шөнө дараалж аврахгүй.',
  ),
  Role.detective => const RoleCardCopy(
    theme: 'МӨРЧИН',
    mechanic: 'Мөрдөгч',
    faction: 'Хотынхон',
    job: 'Шөнө бүр нэг суудлыг шалга. Хариу нь тэр дороо гарна.',
    advice: 'Хэзээ дүрээ зарлах нь чиний хамгийн том шийдвэр.',
  ),
  Role.killer => const RoleCardCopy(
    theme: 'ЧОНО',
    mechanic: 'Алуурчин',
    faction: 'Мафи',
    job: 'Шөнө хохирогчоо сонго. Хамтрагчид чинь ширээн дээр байна.',
    advice:
        'Эхний өдөр хамгийн эрт хэн нэгнийг заасан хүн '
        'үргэлж сэжигтэй.',
  ),
  Role.boss => const RoleCardCopy(
    theme: 'ЦӨВҮҮН ЧОНО',
    mechanic: 'Ахлагч',
    faction: 'Мафи',
    job: 'Санал зөрвөл чиний сонголт хүчинтэй.',
    advice: 'Хамтрагчид чинь чамайг мэдэхгүй. Тэр нь чиний давуу тал.',
  ),
};

/// Эхний гурван тоглолтод авто-нуулт 4000 мс (GDD-11 §2-ын тодорхой
/// үл хамаарах зүйл — анх уншиж байгаа хүүхдийн хугацаа шагайлтаас үнэтэй).
const Duration kCardAutoHideNew = Duration(milliseconds: 4000);

/// Дахин харсныг зарлах баннерын хугацаа (GDD-06 S06, GDD-10 §7).
const Duration kAlreadySeenBanner = Duration(milliseconds: 1500);

// ---------------------------------------------------------------------------
// Дэлгэц
// ---------------------------------------------------------------------------

enum RevealStage {
  /// S05 — «Ширээн дээр тавь. Дараах — №7»
  handoff,

  /// Хөзрийн ар тал + «хоёр эрхийгээ дар»
  back,

  /// «№5 дүрээ аль хэдийн харсан.» — илчлэхийн ӨМНӨ, бүх ширээний өмнө
  announce,

  /// Хөзрийн нүүр + гадуур дүүрэх цагираг
  revealed,

  /// Хар, доор «Ширээн дээр тавь»
  hidden,

  /// «Бүгд харлаа.» 600 мс → S07
  done,
}

class RevealScreen extends StatefulWidget {
  const RevealScreen({
    super.key,
    required this.controller,
    required this.onAllSeen,
  });

  final GameController controller;

  /// Бүх суудал хөзрөө харсан — S07 (Танилцах шөнө) руу.
  final VoidCallback onAllSeen;

  @override
  State<RevealScreen> createState() => _RevealScreenState();
}

class _RevealScreenState extends State<RevealScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  RevealStage _stage = RevealStage.handoff;
  int _index = 0;

  bool _leftDown = false;
  bool _rightDown = false;

  Timer? _holdTimer;
  Timer? _announceTimer;
  Timer? _autoHideTimer;
  Timer? _doneTimer;

  String _banner = '';

  // `late final ... = AnimationController(...)` БИШ: залхуу эхлэл нь хэзээ ч
  // нээгээгүй дэлгэц хаагдахад `dispose()`-ийн дотор `Ticker` үүсгэж унана.
  late final AnimationController _flip;
  late final AnimationController _ring;

  Seat get _seat => _index + 1;
  int get _seatCount => widget.controller.seatCount;
  bool get _isLastSeat => _index >= _seatCount - 1;

  /// GDD-11 §2 — эхний гурван тоглолтод дөрвөн мөрийг уншихад 2.5 сек багадна.
  Duration get _autoHide =>
      widget.controller.gamesPlayed < 3 ? kCardAutoHideNew : kCardAutoHide;

  bool get _reduceMotion => widget.controller.settings.reduceMotion;

  @override
  void initState() {
    super.initState();
    _flip = AnimationController(vsync: this, duration: kCardFlip);
    _ring = AnimationController(vsync: this, duration: kCardAutoHide);
    WidgetsBinding.instance.addObserver(this);
    // `DealRoute` — FLAG_SECURE route-ын ТУРШ асаалттай (GDD-06 §0).
    PlatformGuard.setSecure(true);
    // Утас ширээн дунд аялж байх тул унтрахгүй. Шөнийн эргэлт үүнийг
    // үргэлжлүүлэн ашиглах тул ЭНД унтраахгүй.
    PlatformGuard.setKeepAwake(widget.controller.settings.keepAwake);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    PlatformGuard.setSecure(false);
    _holdTimer?.cancel();
    _announceTimer?.cancel();
    _autoHideTimer?.cancel();
    _doneTimer?.cancel();
    _flip.dispose();
    _ring.dispose();
    super.dispose();
  }

  /// Апп ард гарах, фокус алдагдах — хөзөр ТЭР ДОР НЬ алга болно.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _leftDown = false;
      _rightDown = false;
      _holdTimer?.cancel();
      _hide();
    }
  }

  // --- Хоёр эрхий ----------------------------------------------------------

  /// «Нэг хуруугаар нээх» (Тохиргоо) үед нэг товгор хангалттай, гэхдээ барих
  /// хугацаа 1200 мс болж нэмэгдэнэ — санамсаргүй нээлтийг орлоно (GDD-06 S06).
  bool get _engaged => widget.controller.settings.onePointerReveal
      ? (_leftDown || _rightDown)
      : (_leftDown && _rightDown);

  void _padChanged() {
    setState(() {}); // товгорын харагдах байдал шинэчлэгдэнэ
    if (_engaged) {
      if (_stage == RevealStage.back || _stage == RevealStage.hidden) {
        _holdTimer?.cancel();
        _holdTimer = Timer(widget.controller.settings.holdDuration, _afterHold);
      }
    } else {
      _holdTimer?.cancel();
      _holdTimer = null;
      if (_stage == RevealStage.announce) {
        _announceTimer?.cancel();
        setState(() => _stage = RevealStage.back);
      } else if (_stage == RevealStage.revealed) {
        _hide();
      }
    }
  }

  void _afterHold() {
    if (!mounted) return;
    final GameController c = widget.controller;
    if (!c.seen.contains(_seat)) {
      _reveal();
      return;
    }
    // Дахин харалт — ЗАРЛАГДАНА, тоологдоно, дэвтэрт БИЧИГДЭХГҮЙ.
    final int nth = (c.reviewCount[_seat] ?? 0) + 1;
    final String base = c.gamesPlayed < 3
        ? '№$_seat дахин харлаа.'
        : '№$_seat дүрээ аль хэдийн харсан.';
    _banner = nth >= 2 ? '$base ($nth-р удаа)' : base;
    SemanticsService.announce(_banner, TextDirection.ltr);
    setState(() => _stage = RevealStage.announce);
    _announceTimer = Timer(kAlreadySeenBanner, () {
      if (mounted && _stage == RevealStage.announce) _reveal();
    });
  }

  void _reveal() {
    widget.controller.markSeen(_seat);
    setState(() => _stage = RevealStage.revealed);
    if (_reduceMotion) {
      _flip.value = 1;
    } else {
      _flip.forward(from: 0);
    }
    // Авто-нуултын цаг нь ТАЙМЕР, анимаци биш: «хөдөлгөөн багасгах» горим
    // хугацааг өөрчилж болохгүй.
    _ring.duration = _autoHide;
    _ring.forward(from: 0);
    _autoHideTimer?.cancel();
    _autoHideTimer = Timer(_autoHide, _hide);
  }

  void _hide() {
    if (_stage != RevealStage.revealed && _stage != RevealStage.announce) {
      return;
    }
    _autoHideTimer?.cancel();
    _announceTimer?.cancel();
    _ring.stop();
    _flip.value = 0;
    // Хөзрийн нүүр модын мод дотроос ТЭР ДОР НЬ хасагдана — TalkBack
    // хоцрогдсон мөр уншиж болохгүй (GDD-06 §0-ын хүртээмжийн дүрэм 3).
    if (_isLastSeat && widget.controller.allSeen) {
      setState(() => _stage = RevealStage.done);
      _doneTimer = Timer(kHandoffLock, () {
        if (mounted) widget.onAllSeen();
      });
    } else {
      setState(() => _stage = RevealStage.hidden);
    }
  }

  void _advance() {
    setState(() {
      _index++;
      _leftDown = false;
      _rightDown = false;
      _stage = RevealStage.handoff;
    });
  }

  // --- Бүтэц ---------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (_stage == RevealStage.handoff) {
      return HandoffGate(
        nextSeat: _seat,
        onLift: () => setState(() => _stage = RevealStage.back),
      );
    }
    if (_stage == RevealStage.done) {
      return Scaffold(
        backgroundColor: kNight,
        body: SafeArea(
          child: Center(
            child: Text(
              'Бүгд харлаа.',
              style: kDisplay.copyWith(color: kEmber, height: 1.2),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: kNight,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // Дээд зах — суудлын дугаар, том. Дээд гуравны нэгд ХҮРЭХ ЮМ
            // БАЙХГҮЙ (GDD-06 §0-ын нэг гарын дүрэм).
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 4),
              child: Text(
                '№$_seat',
                textAlign: TextAlign.center,
                style: kSeatNumber.copyWith(color: kEmber, fontSize: 48),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: kGutter),
                child: _cardArea(),
              ),
            ),
            _hintLine(),
            _thumbRow(),
            Padding(
              padding: const EdgeInsets.fromLTRB(kGutter, 8, kGutter, 16),
              child: SizedBox(
                height: kPrimaryButtonHeight,
                child: _stage == RevealStage.hidden
                    ? FilledButton(
                        onPressed: _advance,
                        child: const Text('Ширээн дээр тавь'),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cardArea() {
    if (_stage == RevealStage.hidden) {
      // Хар. Ямар ч дүрийн үг байхгүй.
      return const SizedBox.expand();
    }
    return AnimatedBuilder(
      animation: _flip,
      builder: (BuildContext context, Widget? _) {
        final double t = _flip.value;
        final bool face = _stage == RevealStage.revealed && t >= 0.5;
        return Stack(
          fit: StackFit.expand,
          children: <Widget>[
            Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.001)
                ..rotateY(math.pi * t),
              child: Transform(
                alignment: Alignment.center,
                transform: face
                    ? (Matrix4.identity()..rotateY(math.pi))
                    : Matrix4.identity(),
                child: face ? _cardFace() : _cardBack(),
              ),
            ),
            if (_stage == RevealStage.revealed) _ringOverlay(),
          ],
        );
      },
    );
  }

  /// Хөзрийн ар тал — улзий хүрээтэй. ХАС ХЭЗЭЭ Ч БИШ (13 §4.1-ийн
  /// мэдрэг зүйлсийн анхааруулга 2).
  Widget _cardBack() => Container(
    decoration: BoxDecoration(
      color: kSurfaceRaised,
      borderRadius: BorderRadius.circular(kRadius),
      border: Border.all(color: kEmber.withValues(alpha: 0.45), width: 2),
    ),
    child: CustomPaint(
      painter: _UlziiPainter(color: kEmber.withValues(alpha: 0.35)),
      child: _stage == RevealStage.announce
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(kGutter),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: kSurface,
                    borderRadius: BorderRadius.circular(kRadius),
                  ),
                  child: Text(
                    _banner,
                    textAlign: TextAlign.center,
                    style: kTitle.copyWith(color: kEmber, height: 1.45),
                  ),
                ),
              ),
            )
          : const SizedBox.expand(),
    ),
  );

  /// Хөзрийн нүүр — дөрвөн мөр, өөр юу ч биш (GDD-02 §5).
  Widget _cardFace() {
    final Role? role = widget.controller.roleOf(_seat);
    if (role == null) return _cardBack();
    final RoleCardCopy copy = cardCopyFor(role);
    final bool mafi = factionOf(role) == Faction.mafi;
    final Color accent = mafi ? kDanger : kOk;

    return Semantics(
      // TalkBack ганц мөр уншина. Нуугдмагц энэ модны мод устана.
      label: 'Дүр: ${copy.mechanic}',
      child: Container(
        decoration: BoxDecoration(
          color: kSurfaceRaised,
          borderRadius: BorderRadius.circular(kRadius),
          border: Border.all(color: accent, width: 2),
        ),
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints c) {
            // Намхан дэлгэц дээр ч мөр ХЭЗЭЭ Ч халихгүй: агуулга бүхэлдээ
            // жижигрэнэ. 320 × 568-д ч эвдрэхгүй.
            return FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.center,
              child: SizedBox(
                width: c.maxWidth,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    // ДҮРИЙН ТЭМДЭГ — хөзрийн нүүр. Хүн үгийг уншихаас
                    // өмнө дүрсийг хардаг; 2.5 секунд дотор тэр л чухал.
                    Align(
                      alignment: Alignment.centerLeft,
                      child: RoleSigil(role, size: 64, color: accent),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      copy.theme,
                      style: kDisplay.copyWith(color: kTextPrimary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      copy.mechanic,
                      style: kBody.copyWith(color: kTextMuted),
                    ),
                    const SizedBox(height: 8),
                    // Утга нь ӨНГӨ БА ХЭЛБЭР БА КИРИЛЛ ШОШГО.
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Mark(
                          mafi ? MarkShape.triangle : MarkShape.discFilled,
                          size: 13,
                          color: accent,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          copy.faction,
                          style: kLabel.copyWith(color: accent),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      copy.job,
                      style: kBody.copyWith(
                        color: kTextPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(copy.advice, style: kBody.copyWith(color: kTextMuted)),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// Цагираг хөзрийн ГАДУУР дүүрнэ. Хөдөлгөөн багасгах горимд — тоо.
  Widget _ringOverlay() {
    if (_reduceMotion) {
      return Align(
        alignment: Alignment.topRight,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: AnimatedBuilder(
            animation: _ring,
            builder: (BuildContext context, Widget? _) {
              final int left =
                  ((1 - _ring.value) * _autoHide.inMilliseconds / 1000)
                      .ceil()
                      .clamp(0, 9);
              return Text(
                '$left',
                style: kTitle.copyWith(color: kTextMuted, height: 1.2),
              );
            },
          ),
        ),
      );
    }
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _ring,
        builder: (BuildContext context, Widget? _) =>
            CustomPaint(painter: _RingPainter(_ring.value, kEmber)),
      ),
    );
  }

  Widget _hintLine() {
    final String text = switch (_stage) {
      RevealStage.back => 'Дүрээ харахын тулд хоёр эрхийгээ дар.',
      RevealStage.announce => _banner,
      _ => '',
    };
    return SizedBox(
      height: 56,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: kGutter),
        child: Center(
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: kBody.copyWith(
              color: _stage == RevealStage.announce ? kEmber : kTextPrimary,
            ),
          ),
        ),
      ),
    );
  }

  /// Доод хоёр булан, тус бүр 96 × 96 dp, хооронд нь дэлгэцийн өргөний
  /// ≥ 40 % зай (GDD-06 S06 / GDD-10 §6). 320px дээр зай нь багасна ч
  /// товгорууд ХЭЗЭЭ Ч жижгэрэхгүй — халилт гарахгүй.
  Widget _thumbRow() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        _ThumbPad(
          key: const ValueKey<String>('thumbLeft'),
          label: 'Зүүн эрхий',
          active: _leftDown,
          onChanged: (bool down) {
            _leftDown = down;
            _padChanged();
          },
        ),
        _ThumbPad(
          key: const ValueKey<String>('thumbRight'),
          label: 'Баруун эрхий',
          active: _rightDown,
          onChanged: (bool down) {
            _rightDown = down;
            _padChanged();
          },
        ),
      ],
    ),
  );
}

/// 96 × 96 dp эрхийн товгор. `Listener` ашиглана — хоёр хуруу ЗЭРЭГ дарагдсан
/// эсэхийг мэдэх цорын ганц найдвартай арга (`GestureDetector` нь нэг
/// заагчийн ялалтыг шаарддаг).
class _ThumbPad extends StatelessWidget {
  const _ThumbPad({
    super.key,
    required this.label,
    required this.active,
    required this.onChanged,
  });

  final String label;
  final bool active;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (PointerDownEvent _) => onChanged(true),
      onPointerUp: (PointerUpEvent _) => onChanged(false),
      onPointerCancel: (PointerCancelEvent _) => onChanged(false),
      child: Semantics(
        label: label,
        button: true,
        child: Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            color: active ? kEmber.withValues(alpha: 0.30) : kSurfaceRaised,
            borderRadius: BorderRadius.circular(48),
            border: Border.all(
              color: active ? kEmber : kHairline,
              width: active ? 3 : 1,
            ),
          ),
        ),
      ),
    );
  }
}

/// Улзий хээний хүрээ — тэгш хэмтэй сүлжмэл зангилаа. Дөрвөн эргэлтийн
/// хэлбэр ЗОРИУД ашиглаагүй: тийм хээ нь хас мэт уншигдана (13 §4.1).
/// Эцсийн урлаг GDD-08-ын урлагийн шатнаас ирнэ; энэ нь байрлалыг барина.
class _UlziiPainter extends CustomPainter {
  const _UlziiPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = color;
    final Offset c = Offset(size.width / 2, size.height / 2);
    final double u = math.min(size.width, size.height) * 0.30;
    for (final List<double> r in <List<double>>[
      <double>[u * 1.9, u * 0.8],
      <double>[u * 0.8, u * 1.9],
      <double>[u * 1.35, u * 1.35],
    ]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: c, width: r[0] * 2, height: r[1] * 2),
          const Radius.circular(10),
        ),
        p,
      );
    }
  }

  @override
  bool shouldRepaint(_UlziiPainter old) => old.color != color;
}

/// Хөзрийн гадуур дүүрэх цагираг — авто-нуултын үлдсэн хугацаа.
class _RingPainter extends CustomPainter {
  const _RingPainter(this.t, this.color);
  final double t;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (t <= 0) return;
    final Path path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          const Radius.circular(kRadius),
        ),
      );
    final Paint p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..color = color;
    for (final PathMetric m in path.computeMetrics()) {
      canvas.drawPath(m.extractPath(0, m.length * t.clamp(0.0, 1.0)), p);
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.t != t || old.color != color;
}
