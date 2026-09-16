// Ертөнцийн аялал — ширээг ӨӨР ӨӨР өнцгөөс харуулна.
//
// Толгой эргүүлэхэд ЯГ НЭГЭН тайз өөр өнцгөөс харагдаж байгаа нь энэ нь
// зураг биш, ЖИНХЭНЭ 3D ОРОН ЗАЙ гэдгийн нотолгоо.
//
//   flutter test test/world_tour_test.dart --update-goldens

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hotuntlaa/ui/scene3d.dart';
import 'package:hotuntlaa/ui/table_scene.dart';
import 'package:hotuntlaa/ui/tokens.dart';

Future<ui.Image> _img(String path) async {
  final ByteData d = await rootBundle.load(path);
  final ui.Codec c = await ui.instantiateImageCodec(d.buffer.asUint8List());
  return (await c.getNextFrame()).image;
}

void main() {
  late List<ui.Image> faces;

  setUpAll(() async {
    for (final MapEntry<String, List<String>> e in <String, List<String>>{
      'Oswald': <String>['assets/fonts/Oswald-Medium.ttf'],
      'Rubik': <String>['assets/fonts/Rubik-Regular.ttf'],
    }.entries) {
      final FontLoader l = FontLoader(e.key);
      for (final String p in e.value) {
        l.addFont(rootBundle.load(p));
      }
      await l.load();
    }
    faces = <ui.Image>[];
    for (int i = 1; i <= 12; i++) {
      faces.add(await _img(
          'assets/art/seats/seat${i.toString().padLeft(2, '0')}.jpg'));
    }
  });

  Future<void> shot(WidgetTester t, String name, double yaw) async {
    t.view.physicalSize = const Size(720, 1600);
    t.view.devicePixelRatio = 2.0;
    addTearDown(t.view.reset);
    await t.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: Scaffold(
        backgroundColor: kNight,
        body: TableScene(
          viewerSeat: 1,
          yaw: yaw,
          occupants: <SeatOccupant>[
            for (int s = 1; s <= 12; s++)
              SeatOccupant(seat: s, portrait: faces[s - 1]),
          ],
        ),
      ),
    ));
    await t.pump(const Duration(milliseconds: 60));
    await expectLater(
        find.byType(MaterialApp), matchesGoldenFile('goldens/$name.png'));
  }

  testWidgets('зүүн тийш эргэв', (WidgetTester t) async {
    await shot(t, 'world_left', -TableLayout.maxYaw * 0.55);
  });

  testWidgets('шууд урагш', (WidgetTester t) async {
    await shot(t, 'world_front', 0);
  });

  testWidgets('баруун тийш эргэв', (WidgetTester t) async {
    await shot(t, 'world_right', TableLayout.maxYaw * 0.55);
  });
}
