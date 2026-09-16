// S00 — Splash, S01 — Нүүр. GDD-06.
//
// S01 дээр ХОЁРХОН зүйл байна: нэр, бас НЭГ товч (GDD-00 §7). Онлайн карт,
// «Удахгүй» тэмдэг, зэрэглэл — байхгүй. Энэ сахилга бат нь дэлгэц дүүрэн
// сул зайг зориудаар үлдээж байгаа хэрэг.

import 'dart:async';

import 'package:flutter/material.dart' hide Intent;

import '../game/game_controller.dart';
import '../game/phase.dart';
import '../ui/atmosphere.dart';
import '../ui/tokens.dart';
import 'setup_parts.dart';
import '../ui/glyphs.dart';

// ---------------------------------------------------------------------------
// S00 — Splash. Route БИШ: `main()`-ий барьдаг виджет.
// ---------------------------------------------------------------------------

/// Лого, хамгийн ихдээ 1.0 секунд, ТООЛУУРГҮЙ. Зар, нэвтрэх, эрх хүсэх —
/// байхгүй (GDD-06 S00).
class SplashScreen extends StatefulWidget {
  const SplashScreen({
    super.key,
    required this.onReady,
    this.audioFailed = false,
    this.hold = const Duration(seconds: 1),
  });

  final VoidCallback onReady;

  /// `assetFail` төлөв — аудио ачаалагдсангүй. Тоглоом дуугүй ажиллана.
  final bool audioFailed;
  final Duration hold;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // `assetFail` үед хүн «Үргэлжлүүлэх» дарна — өөрөө шилжихгүй.
    if (!widget.audioFailed) {
      _timer = Timer(widget.hold, widget.onReady);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSurface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(kGutter, kGutter, kGutter, 20),
          child: Column(
            children: <Widget>[
              const Spacer(),
              // Лого нь нүүр дэлгэцийнхтэй ЯГ ИЖИЛ — хоёр мөр, доод мөр нь
              // өнгө хуваасан. Эхний нэг секунд ч гэсэн тоглоомын нүүр.
              ExcludeSemantics(
                child: Text(
                  'ХОТ',
                  textAlign: TextAlign.center,
                  style: kDisplay.copyWith(
                    fontSize: 46,
                    color: kTextPrimary,
                    letterSpacing: 8,
                  ),
                ),
              ),
              ChromaticTitle(
                'УНТЛАА',
                semantics: 'Хот унтлаа',
                style: kDisplay.copyWith(fontSize: 46, letterSpacing: 8),
              ),
              const Spacer(),
              if (widget.audioFailed) ...<Widget>[
                const Text(
                  'Дуу ачаалагдсангүй. Тоглоом дуугүй ажиллана.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    height: 1.45,
                    color: kTextMuted,
                  ),
                ),
                const SizedBox(height: kGap),
                FilledButton(
                  onPressed: widget.onReady,
                  child: const Text('Үргэлжлүүлэх'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// S01 — Нүүр
// ---------------------------------------------------------------------------

/// GDD-06 S01-ийн дөрвөн төлөв.
enum HomeState { firstRun, hasRoster, midGame, bituun }

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.controller,
    required this.onNewGame,
    required this.onSameSeats,
    required this.onSettings,
    required this.onHelp,
    this.onResume,
    this.onLedger,
    this.bituun = false,
  });

  final GameController controller;

  /// «Нэг утсаар тоглох» → S02.
  final VoidCallback onNewGame;

  /// «Дахин — ижил суудлаар» → S03. Тохируулгыг алгасаж шууд бүрэлдэхүүн рүү.
  final VoidCallback onSameSeats;

  final VoidCallback onSettings;
  final VoidCallback onHelp;

  /// «Үргэлжлүүлэх — Шөнө 3» → S08. `null` бол дуусаагүй тоглолт байхгүй.
  final VoidCallback? onResume;

  /// «Ангийн дэвтэр» → S20 (v1.1). `null` бол дэвтэр хоосон.
  final VoidCallback? onLedger;

  /// Битүүний долоо хоног — өнгө цагаан-мөнгөлөг (GDD-00 §8, GDD-08).
  final bool bituun;

  HomeState get state {
    if (bituun) return HomeState.bituun;
    final bool midGame =
        onResume != null &&
        controller.phase != GamePhase.appOpen &&
        controller.phase != GamePhase.roster &&
        controller.phase != GamePhase.preset;
    if (midGame) return HomeState.midGame;
    if (controller.hasSavedRoster) return HomeState.hasRoster;
    return HomeState.firstRun;
  }

  // Битүүний токен солилт — өөр юу ч биш (GDD-08 §7).
  Color get _bg => bituun ? const Color(0xFFE8ECF2) : kSurface;
  Color get _fg => bituun ? const Color(0xFF0E1A2B) : kTextPrimary;
  Color get _muted => bituun ? const Color(0xFF4A5A6E) : kTextMuted;
  Color get _accent => bituun ? const Color(0xFF7E8EA3) : kEmber;

  String get _primaryLabel => switch (state) {
    HomeState.firstRun => 'Нэг утсаар тоглох',
    HomeState.hasRoster => 'Дахин — ижил суудлаар',
    HomeState.midGame => 'Үргэлжлүүлэх — Шөнө ${controller.nightNo}',
    HomeState.bituun => 'Золгоё',
  };

  /// TalkBack: «Дахин тоглох, ижил суудлаар, арван хоёр тоглогч» (GDD-06 S01).
  String get _primarySemantics => switch (state) {
    HomeState.hasRoster =>
      'Дахин тоглох, ижил суудлаар, '
          '${mnNumber(controller.seatCount)} тоглогч',
    HomeState.midGame =>
      'Үргэлжлүүлэх, ${mnNumber(controller.nightNo)} дүгээр шөнө',
    _ => _primaryLabel,
  };

  VoidCallback get _primaryAction => switch (state) {
    HomeState.firstRun => onNewGame,
    HomeState.hasRoster => onSameSeats,
    HomeState.midGame => onResume ?? onNewGame,
    HomeState.bituun => onSameSeats,
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // Дээд зах — «Ангийн дэвтэр». Булан биш, бүтэн мөр: утас ширээн
            // дунд хэвтэж байхад эрхий хүрэхгүй ч гэсэн алдаж дарагдахгүй.
            _LedgerLink(color: _muted, onTap: onLedger),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: kGutter),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      // Гарчиг нь хоёр мөр, тус бүр өөрийн жинтэй — нэг эгнээ
                      // том үсэг бол «апп», эвдэрсэн хэмнэл бол «зурагт хуудас».
                      ExcludeSemantics(
                        child: Text(
                          'ХОТ',
                          textAlign: TextAlign.center,
                          style: kDisplay.copyWith(
                            fontSize: 64,
                            color: _fg,
                            letterSpacing: 10,
                          ),
                        ),
                      ),
                      ChromaticTitle(
                        'УНТЛАА',
                        // Хоёр мөрийг уншигчид НЭГ нэр болгож хэлнэ.
                        semantics: 'Хот унтлаа',
                        style: kDisplay.copyWith(
                          fontSize: 64,
                          letterSpacing: 10,
                        ),
                      ),
                      const SizedBox(height: 18),
                      // Нимгэн зураас — хэвлэмэл хуудасны зүсэлт.
                      SizedBox(
                        width: 140,
                        child: Divider(color: _muted, thickness: 1, height: 1),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'АНГИЙН МАФИ · НЭГ УТСААР',
                        textAlign: TextAlign.center,
                        style: kLabel.copyWith(color: _muted),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Үндсэн үйлдэл — доод гуравны нэг, өндөр 88 dp (GDD-06 S01).
            Padding(
              padding: const EdgeInsets.fromLTRB(kGutter, 0, kGutter, 8),
              child: Semantics(
                button: true,
                label: _primarySemantics,
                child: ExcludeSemantics(
                  child: SizedBox(
                    height: 88,
                    child: FilledButton(
                      onPressed: _primaryAction,
                      style: FilledButton.styleFrom(
                        backgroundColor: _accent,
                        foregroundColor: bituun ? Colors.white : kSurface,
                        // ФОНТЫГ ЗААВАЛ БИЧНЭ: `styleFrom(textStyle:)` нь
                        // сэдвийн `fontFamily`-г бүхлээр нь СОЛИНО. Үлдээвэл
                        // Oswald унаад Ү, Ө үсэг хоосон дөрвөлжин болж байв.
                        textStyle: const TextStyle(
                          fontFamily: kDisplayFont,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(kRadius),
                        ),
                      ),
                      child: Text(_primaryLabel, textAlign: TextAlign.center),
                    ),
                  ),
                ),
              ),
            ),
            // Хадгалагдсан суудалтай үед л — доор нь ЖИЖГЭЭР.
            if (state == HomeState.hasRoster || state == HomeState.bituun)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: kGutter),
                child: TextButton(
                  onPressed: onNewGame,
                  style: TextButton.styleFrom(
                    minimumSize: const Size.fromHeight(kMinTouch),
                    foregroundColor: _muted,
                  ),
                  child: const Text(
                    'Шинэ бүрэлдэхүүн',
                    style: TextStyle(fontSize: 16, height: 1.45),
                  ),
                ),
              ),
            // Доод зах — хоёр жижиг дүрс.
            Padding(
              padding: const EdgeInsets.fromLTRB(kGutter, 4, kGutter, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  MarkButton(
                    shape: MarkShape.gear,
                    semantic: 'Тохиргоо',
                    color: _muted,
                    onTap: onSettings,
                  ),
                  const SizedBox(width: 24),
                  MarkButton(
                    shape: MarkShape.question,
                    semantic: 'Тусламж',
                    color: _muted,
                    onTap: onHelp,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LedgerLink extends StatelessWidget {
  const _LedgerLink({required this.color, required this.onTap});

  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton(
        onPressed: () {
          if (onTap != null) {
            onTap!();
          } else {
            // Дэвтэр хоосон — S20-ын `emptyPins` мөр.
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Өнөөдөр тэмдэглэл байхгүй.')),
            );
          }
        },
        style: TextButton.styleFrom(
          minimumSize: const Size(kMinTouch, kMinTouch),
          padding: const EdgeInsets.symmetric(horizontal: kGutter),
          foregroundColor: color,
        ),
        child: const Text(
          'Ангийн дэвтэр',
          style: TextStyle(fontSize: 16, height: 1.45),
        ),
      ),
    );
  }
}
