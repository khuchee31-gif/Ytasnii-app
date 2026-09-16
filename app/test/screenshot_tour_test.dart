// Дэлгэцийн зураг авах аялал.
//
// Энэ бол ТЕСТ БИШ — хэрэглэгчид харуулах зураг гаргах хэрэгсэл. Ажиллуулах:
//   flutter test test/screenshot_tour_test.dart --update-goldens
// Зургууд `test/goldens/` дотор гарна.
//
// Жинхэнэ утасны хэмжээ: 360×800 логик, dpr 2 → 720×1600 px.

import 'dart:io';

import 'package:engine/engine.dart' hide Intent;
import 'package:flutter/material.dart' hide Intent;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hotuntlaa/game/game_controller.dart';
import 'package:hotuntlaa/game/phase.dart';
import 'package:hotuntlaa/screens/ceremony_screen.dart';
import 'package:hotuntlaa/screens/dawn_screen.dart';
import 'package:hotuntlaa/screens/day_screen.dart';
import 'package:hotuntlaa/screens/fairness_screen.dart';
import 'package:hotuntlaa/screens/handoff_screen.dart';
import 'package:hotuntlaa/screens/help_screen.dart';
import 'package:hotuntlaa/screens/home_screen.dart';
import 'package:hotuntlaa/screens/night0_screen.dart';
import 'package:hotuntlaa/screens/night_circuit_screen.dart';
import 'package:hotuntlaa/screens/preset_screen.dart';
import 'package:hotuntlaa/screens/reveal_screen.dart';
import 'package:hotuntlaa/screens/roster_screen.dart';
import 'package:hotuntlaa/screens/settings_screen.dart';
import 'package:hotuntlaa/screens/vote_screen.dart';
import 'package:hotuntlaa/ui/atmosphere.dart';
import 'package:hotuntlaa/ui/tokens.dart';

const Size kPhone = Size(360, 800);

Uint8List _seed(int n) =>
    Uint8List.fromList(List<int>.generate(32, (int i) => (i * 31 + n) & 0xFF));

/// Аппын ЖИНХЭНЭ фонтыг ачаална — golden зураг нь бодит байдлыг харуулна.
Future<void> _loadFont() async {
  const Map<String, List<String>> families = <String, List<String>>{
    'Oswald': <String>[
      'assets/fonts/Oswald-Medium.ttf',
      'assets/fonts/Oswald-Bold.ttf',
    ],
    'Rubik': <String>[
      'assets/fonts/Rubik-Regular.ttf',
      'assets/fonts/Rubik-Medium.ttf',
      'assets/fonts/Rubik-Bold.ttf',
    ],
  };
  for (final MapEntry<String, List<String>> e in families.entries) {
    final FontLoader loader = FontLoader(e.key);
    for (final String path in e.value) {
      final File f = File(path);
      if (f.existsSync()) {
        loader.addFont(Future<ByteData>.value(
            ByteData.view(f.readAsBytesSync().buffer)));
      }
    }
    await loader.load();
  }
}

Future<void> _shot(
  WidgetTester tester,
  String name,
  Widget screen, {
  Duration settle = const Duration(milliseconds: 400),
}) async {
  tester.view.physicalSize = Size(kPhone.width * 2, kPhone.height * 2);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: buildTheme(),
    // Жинхэнэ аппын нэгэн адил уур амьсгалыг дээр нь тавина.
    home: Atmosphere(animate: false, child: screen),
  ));
  await tester.pump(settle);
  await expectLater(
      find.byType(MaterialApp), matchesGoldenFile('goldens/$name.png'));
}

GameController _dealt({int seats = 12, int seedN = 7}) {
  final GameController c = GameController();
  c.seatCount = seats;
  c.beginFairness(seed0: _seed(seedN));
  c.dealWithEntropy(Uint8List.fromList(<int>[1, 2, 3, 4]));
  return c;
}

void main() {
  setUpAll(_loadFont);

  testWidgets('01 нүүр', (WidgetTester t) async {
    final GameController c = GameController();
    addTearDown(c.dispose);
    await _shot(t, '01_home', HomeScreen(
      controller: c,
      onNewGame: () {},
      onSameSeats: () {},
      onSettings: () {},
      onHelp: () {},
    ));
  });

  testWidgets('02 суудал', (WidgetTester t) async {
    final GameController c = GameController();
    addTearDown(c.dispose);
    await _shot(t, '02_roster', RosterScreen(controller: c, onContinue: () {}));
  });

  testWidgets('03 бүрэлдэхүүн', (WidgetTester t) async {
    final GameController c = GameController();
    addTearDown(c.dispose);
    c.seatCount = 12;
    await _shot(t, '03_preset', PresetScreen(controller: c, onDeal: () {}));
  });

  testWidgets('04 шударгын код', (WidgetTester t) async {
    final GameController c = GameController();
    addTearDown(c.dispose);
    c.seatCount = 12;
    c.beginFairness(seed0: _seed(7));
    await _shot(t, '04_fairness',
        FairnessScreen(controller: c, onSealed: () {}));
  });

  testWidgets('05 дамжуулах', (WidgetTester t) async {
    await _shot(t, '05_handoff',
        HandoffScreen(nextSeat: 7, onLift: () {}));
  });

  testWidgets('06 хөзөр харах', (WidgetTester t) async {
    final GameController c = _dealt();
    addTearDown(c.dispose);
    await _shot(t, '06_reveal', RevealScreen(controller: c, onAllSeen: () {}));
  });

  testWidgets('07 танилцах шөнө', (WidgetTester t) async {
    final GameController c = _dealt();
    addTearDown(c.dispose);
    for (int s = 1; s <= 12; s++) {
      c.markSeen(s);
    }
    await _shot(t, '07_night0', Night0Screen(controller: c, onDone: () {}));
  });

  testWidgets('09 шөнийн үйлдэл', (WidgetTester t) async {
    final GameController c = _dealt();
    addTearDown(c.dispose);
    for (int s = 1; s <= 12; s++) {
      c.markSeen(s);
    }
    c.beginNight();
    await _shot(t, '09_night_circuit',
        NightCircuitScreen(controller: c, onDone: () {}),
        settle: const Duration(seconds: 1));
  });

  testWidgets('11 үүр', (WidgetTester t) async {
    final GameController c = _dealt();
    addTearDown(c.dispose);
    for (int s = 1; s <= 12; s++) {
      c.markSeen(s);
    }
    c.beginNight();
    for (final int seat in c.circuitSeats) {
      final Ability a = abilityOf(c.roleOf(seat)!);
      int? target;
      for (int x = 1; x <= 12; x++) {
        if (c.checkTarget(seat, a, x) == null) {
          target = x;
          break;
        }
      }
      c.submitIntent(seat, a, target);
    }
    c.resolveNightNow();
    await _shot(t, '11_dawn', DawnScreen(controller: c, onDone: () {}),
        settle: const Duration(seconds: 2));
  });

  testWidgets('13 өдөр', (WidgetTester t) async {
    final GameController c = _dealt();
    addTearDown(c.dispose);
    c.dayNo = 1;
    c.go(GamePhase.speechRound);
    await _shot(t, '13_day', DayScreen(controller: c, onVote: () {}),
        settle: const Duration(seconds: 1));
  });

  testWidgets('16 санал хураалт', (WidgetTester t) async {
    final GameController c = _dealt();
    addTearDown(c.dispose);
    c.dayNo = 1;
    c.nominate(3);
    c.nominate(8);
    c.go(GamePhase.nomination);
    await _shot(t, '16_vote',
        VoteScreen(controller: c, onExile: (List<Seat> _) {}, onNoExile: () {}),
        settle: const Duration(seconds: 1));
  });

  testWidgets('19 хөзрөө нээе', (WidgetTester t) async {
    final GameController c = _dealt();
    addTearDown(c.dispose);
    c.alive.removeWhere((Seat s) => s > 3);
    await _shot(t, '19_ceremony',
        CeremonyScreen(controller: c, onAgain: () {}, onLedger: () {}),
        settle: const Duration(seconds: 2));
  });

  testWidgets('21 тохиргоо', (WidgetTester t) async {
    final GameController c = GameController();
    addTearDown(c.dispose);
    await _shot(t, '21_settings',
        SettingsScreen(controller: c, onClose: () {}));
  });

  testWidgets('22 тусламж', (WidgetTester t) async {
    await _shot(t, '22_help', HelpScreen(onClose: () {}));
  });
}
