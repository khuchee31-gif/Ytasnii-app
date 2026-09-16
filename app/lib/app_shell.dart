// Бүрхүүл — 19 үе шатыг 19 дэлгэцтэй холбоно.
//
// ЭНЭ ФАЙЛ ЛОГИК АГУУЛАХГҮЙ. Дүрмийг `packages/engine`, дарааллыг
// `GameController`, харагдах байдлыг дэлгэцүүд эзэмшинэ. Энд зөвхөн
// «аль үе шатанд аль дэлгэц» гэсэн зураглал ба дэлгэцийн хамгаалалт.
//
// ГАР УТАСНЫ ХОЁР ТУГ, ҮЕ ШАТААР (GDD-10 §5, GDD-08 §8):
//   • `FLAG_SECURE` — зөвхөн дүр харагдаж болох үе шатанд.
//   • Дэлгэц унтраахгүй — тоглолт явж байх хугацаанд, дуусмагц тавина.

import 'package:engine/engine.dart' show Seat;
import 'package:flutter/material.dart' hide Intent;

import 'game/game_controller.dart';
import 'game/phase.dart';
import 'screens/best_move_screen.dart';
import 'screens/ceremony_screen.dart';
import 'screens/dawn_screen.dart';
import 'screens/day_screen.dart';
import 'screens/elimination_screen.dart';
import 'screens/fairness_screen.dart';
import 'screens/help_screen.dart';
import 'screens/home_screen.dart';
import 'screens/night0_screen.dart';
import 'screens/night_circuit_screen.dart';
import 'screens/preset_screen.dart';
import 'screens/reveal_screen.dart';
import 'screens/roster_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/vote_screen.dart';
import 'ui/platform_guard.dart';
import 'ui/tokens.dart';

class HotUntlaaApp extends StatelessWidget {
  const HotUntlaaApp({super.key, this.controller});

  /// Тестэд хуурамч цаг хэмжигчтэй controller дамжуулна.
  final GameController? controller;

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Хот унтлаа',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        home: GameShell(controller: controller),
      );
}

/// Хажуугийн дэлгэцүүд — үе шатаас гадуур, түр нээгддэг.
enum _Overlay { none, settings, help }

class GameShell extends StatefulWidget {
  const GameShell({super.key, this.controller, this.skipSplash = false});

  final GameController? controller;
  final bool skipSplash;

  @override
  State<GameShell> createState() => _GameShellState();
}

class _GameShellState extends State<GameShell> {
  late final GameController _c = widget.controller ?? GameController();
  late bool _splashDone = widget.skipSplash;
  _Overlay _overlay = _Overlay.none;

  /// Хасалтын дэлгэц рүү дамжуулах суудал(ууд) — «бүгдийн хувь заяа» үед олон.
  List<Seat> _exiled = const <Seat>[];

  @override
  void initState() {
    super.initState();
    _c.addListener(_onPhase);
  }

  @override
  void dispose() {
    _c.removeListener(_onPhase);
    if (widget.controller == null) _c.dispose();
    super.dispose();
  }

  /// Үе шат солигдох бүрд хоёр тугийг тааруулна. Дэлгэц өөрсдөө хариуцахгүй —
  /// нэг дэлгэц мартвал нүхтэй болно.
  void _onPhase() {
    PlatformGuard.setSecure(_c.phase.needsSecureFlag);
    PlatformGuard.setKeepAwake(_inMatch(_c.phase));
    if (mounted) setState(() {});
  }

  static bool _inMatch(GamePhase p) => switch (p) {
        GamePhase.appOpen ||
        GamePhase.roster ||
        GamePhase.preset ||
        GamePhase.ledger =>
          false,
        _ => true,
      };

  void _closeOverlay() => setState(() => _overlay = _Overlay.none);

  @override
  Widget build(BuildContext context) {
    if (!_splashDone) {
      return SplashScreen(onReady: () => setState(() => _splashDone = true));
    }
    return switch (_overlay) {
      _Overlay.settings =>
        SettingsScreen(controller: _c, onClose: _closeOverlay),
      _Overlay.help => HelpScreen(onClose: _closeOverlay),
      _Overlay.none => _phaseScreen(),
    };
  }

  Widget _phaseScreen() {
    switch (_c.phase) {
      case GamePhase.appOpen:
        return HomeScreen(
          controller: _c,
          onNewGame: () => _c.go(GamePhase.roster),
          // «Дахин — ижил суудлаар» нь ROSTER-ыг алгасна (GDD-01 §1, №2).
          onSameSeats: () => _c.go(GamePhase.preset),
          onSettings: () => setState(() => _overlay = _Overlay.settings),
          onHelp: () => setState(() => _overlay = _Overlay.help),
        );

      case GamePhase.roster:
        return RosterScreen(
            controller: _c, onContinue: () => _c.go(GamePhase.preset));

      case GamePhase.preset:
        return PresetScreen(
            controller: _c, onDeal: () => _c.beginFairness());

      // VALIDATE нь дэлгэцгүй: S03 өөрөө `checkSetup`-ыг уншаад товчоо түгжинэ.
      case GamePhase.validate:
        return PresetScreen(
            controller: _c, onDeal: () => _c.beginFairness());

      case GamePhase.fairness:
        return FairnessScreen(controller: _c, onSealed: () {});

      case GamePhase.deal:
        return RevealScreen(
          controller: _c,
          onAllSeen: () => _c.go(GamePhase.night0),
        );

      case GamePhase.night0:
        return Night0Screen(controller: _c, onDone: _c.beginNight);

      case GamePhase.nightCircuit:
        return NightCircuitScreen(
            controller: _c, onDone: _c.resolveNightNow);

      case GamePhase.dawn:
        return DawnScreen(
          controller: _c,
          onDone: () {
            // «Шилдэг нүүдэл» — тоглолтын ХАМГИЙН эхний хохирогчид, нэг л удаа.
            final bool owed = _c.firstVictim != null && !_c.bestMoveSpoken;
            _c.go(owed ? GamePhase.bestMove : GamePhase.speechRound);
            if (!owed) _c.beginDay();
          },
        );

      case GamePhase.bestMove:
        return BestMoveScreen(
          controller: _c,
          onDone: () {
            _c.bestMoveSpoken = true;
            _c.beginDay();
          },
        );

      case GamePhase.speechRound:
      case GamePhase.freeTalk:
        return DayScreen(
            controller: _c, onVote: () => _c.go(GamePhase.nomination));

      case GamePhase.nomination:
      case GamePhase.defence:
      case GamePhase.handsVote:
        return VoteScreen(
          controller: _c,
          onExile: (List<Seat> seats) {
            _exiled = seats;
            for (final Seat s in seats) {
              _c.alive.remove(s);
            }
            _c.lastEliminated = seats.isEmpty ? null : seats.last;
            _c.go(GamePhase.elimination);
          },
          // Нэр дэвшигч байхгүй эсвэл тэнцсэн — хэн ч хөөгдөхгүй, шөнө рүү.
          onNoExile: _c.checkWin,
        );

      case GamePhase.elimination:
        return EliminationScreen(
          controller: _c,
          seats: _exiled,
          onDone: _c.checkWin,
        );

      // WIN_CHECK нь агшин зуурын — `checkWin()` шууд цааш явуулна.
      case GamePhase.winCheck:
        return const ColoredBox(color: kNight);

      case GamePhase.ceremony:
        return CeremonyScreen(
          controller: _c,
          onAgain: () {
            _c.reset();
            _c.go(GamePhase.preset);
          },
          onLedger: () => _c.go(GamePhase.ledger),
        );

      // S20 «Өнөөдрийн тэмдэглэл» нь v1.1 (GDD-15-ын хасалт).
      case GamePhase.ledger:
        return _NotYet(onBack: _c.reset);

      case GamePhase.paused:
        return _PausedScreen(
          onResume: _c.resume,
          onHelp: () => setState(() => _overlay = _Overlay.help),
          onQuit: _c.reset,
        );
    }
  }
}

class _NotYet extends StatelessWidget {
  const _NotYet({required this.onBack});
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: kSurface,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(kGutter),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text('Ангийн дэвтэр',
                    style: kTitle.copyWith(color: kTextPrimary)),
                const SizedBox(height: 8),
                Text('Энэ хэсэг дараагийн хувилбарт нэмэгдэнэ.',
                    textAlign: TextAlign.center,
                    style: kBody.copyWith(color: kTextMuted)),
                const SizedBox(height: 28),
                FilledButton(onPressed: onBack, child: const Text('Нүүр рүү')),
              ],
            ),
          ),
        ),
      );
}

class _PausedScreen extends StatelessWidget {
  const _PausedScreen({
    required this.onResume,
    required this.onHelp,
    required this.onQuit,
  });

  final VoidCallback onResume;
  final VoidCallback onHelp;
  final VoidCallback onQuit;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: kNight,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(kGutter),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text('Түр зогслоо',
                    textAlign: TextAlign.center,
                    style: kTitle.copyWith(color: kTextPrimary)),
                const SizedBox(height: 8),
                Text('Дэлгэц нуугдсан. Тоглоом хэвээрээ хүлээж байна.',
                    textAlign: TextAlign.center,
                    style: kBody.copyWith(color: kTextMuted)),
                const SizedBox(height: 32),
                FilledButton(
                    onPressed: onResume, child: const Text('Үргэлжлүүлэх')),
                const SizedBox(height: kGap),
                TextButton(onPressed: onHelp, child: const Text('Дүрэм')),
                TextButton(
                  onPressed: onQuit,
                  child: Text('Тоглолтыг цуцлах',
                      style: kBody.copyWith(color: kDanger)),
                ),
              ],
            ),
          ),
        ),
      );
}
