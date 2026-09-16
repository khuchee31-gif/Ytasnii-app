// Ширээний тайзны зураг гаргах.
//
// Ажиллуулах:
//   flutter test test/table_scene_shot_test.dart --update-goldens
//
// Энэ нь тест бөгөөс ХЭРЭГСЭЛ: жинхэнэ дүрийн зургийг ачаалж, 3D ширээг
// зурж, `test/goldens/` дотор гаргана.

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hotuntlaa/ui/table_scene.dart';
import 'package:hotuntlaa/ui/tokens.dart';

Future<ui.Image> _loadAsset(String path) async {
  final ByteData data = await rootBundle.load(path);
  final ui.Codec codec =
      await ui.instantiateImageCodec(data.buffer.asUint8List());
  final ui.FrameInfo f = await codec.getNextFrame();
  return f.image;
}

Future<void> _loadFonts() async {
  for (final MapEntry<String, List<String>> e in <String, List<String>>{
    'Oswald': <String>[
      'assets/fonts/Oswald-Medium.ttf',
      'assets/fonts/Oswald-Bold.ttf',
    ],
    'Rubik': <String>['assets/fonts/Rubik-Regular.ttf'],
  }.entries) {
    final FontLoader l = FontLoader(e.key);
    for (final String p in e.value) {
      l.addFont(rootBundle.load(p));
    }
    await l.load();
  }
}

void main() {
  late List<ui.Image> faces;

  setUpAll(() async {
    await _loadFonts();
    faces = <ui.Image>[];
    for (int i = 1; i <= 12; i++) {
      faces.add(await _loadAsset(
          'assets/art/seats/seat${i.toString().padLeft(2, '0')}.jpg'));
    }
  });

  Future<void> shot(
    WidgetTester t,
    String name,
    Widget child, {
    Size size = const Size(360, 800),
  }) async {
    t.view.physicalSize = Size(size.width * 2, size.height * 2);
    t.view.devicePixelRatio = 2.0;
    addTearDown(t.view.reset);
    await t.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: Scaffold(backgroundColor: kNight, body: child),
    ));
    await t.pump(const Duration(milliseconds: 60));
    await expectLater(
        find.byType(MaterialApp), matchesGoldenFile('goldens/$name.png'));
  }

  testWidgets('T1 — 12 суудалтай ширээ, №1-ээс харав', (WidgetTester t) async {
    await shot(
      t,
      'table_12',
      TableScene(
        viewerSeat: 1,
        occupants: <SeatOccupant>[
          for (int s = 1; s <= 12; s++)
            SeatOccupant(seat: s, portrait: faces[s - 1], name: null),
        ],
      ),
    );
  });

  testWidgets('T2 — 8 суудал, нэг нь ярьж байна, нэг нь хасагдсан',
      (WidgetTester t) async {
    await shot(
      t,
      'table_8_states',
      TableScene(
        viewerSeat: 1,
        occupants: <SeatOccupant>[
          for (int s = 1; s <= 8; s++)
            SeatOccupant(
              seat: s,
              portrait: faces[s - 1],
              speaking: s == 5,
              alive: s != 3,
              highlighted: s == 7,
            ),
        ],
      ),
    );
  });

  testWidgets('T3 — шөнө, чийдэн бүдэг', (WidgetTester t) async {
    await shot(
      t,
      'table_night',
      TableScene(
        viewerSeat: 4,
        lamp: 0.25,
        occupants: <SeatOccupant>[
          for (int s = 1; s <= 10; s++)
            SeatOccupant(seat: s, portrait: faces[s - 1]),
        ],
      ),
    );
  });
}
