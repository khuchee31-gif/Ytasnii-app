// ЧАДВАРЫН СОРИЛ — таамаглал биш, БАТАЛГАА.
//
// Тоглоомыг Buckshot Roulette-ийн түвшинд гаргах төлөвлөгөө хоёр зүйл дээр
// тулна. Аль нэг нь ажиллахгүй бол төлөвлөгөө өөрчлөгдөнө. Тиймээс энд
// тэднийг ЖИНХЭНЭ ажиллуулж шалгана:
//
//   1. `FragmentProgram` — өөрийн GLSL шейдер. Уур амьсгал, эффект бүхэлдээ
//      үүн дээр тулна.
//   2. `drawVertices` — текстуртай гурвалжин. Гадны 3D сангүйгээр ширээ тойрсон
//      дүрүүдийг харуулах цорын ганц зам.
//
// Хоёулаа ажиллавал: Flutter дотор өөрсдийн 3D дүрслэгч бичих боломжтой.

import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('1. GLSL шейдер эмхэтгэгдэж, ажиллаж байна уу?', () async {
    late final ui.FragmentProgram program;
    try {
      program = await ui.FragmentProgram.fromAsset('shaders/probe.frag');
    } catch (e) {
      fail('Шейдер ачаалагдсангүй — төлөвлөгөө өөрчлөгдөнө. Алдаа: $e');
    }

    final ui.FragmentShader shader = program.fragmentShader();
    shader
      ..setFloat(0, 360) // uSize.x
      ..setFloat(1, 800) // uSize.y
      ..setFloat(2, 0.0) // uTime
      ..setFloat(3, 0.9); // uVignette

    // Жинхэнэ зурж, пиксел уншина — «ачаалагдлаа» гэдэг хангалтгүй.
    final ui.PictureRecorder rec = ui.PictureRecorder();
    ui.Canvas(rec).drawRect(
      const Rect.fromLTWH(0, 0, 360, 800),
      Paint()..shader = shader,
    );
    final ui.Image img = await rec.endRecording().toImage(360, 800);
    final ByteData? bytes =
        await img.toByteData(format: ui.ImageByteFormat.rawRgba);

    expect(bytes, isNotNull, reason: 'шейдер пиксел гаргасангүй');
    expect(bytes!.lengthInBytes, 360 * 800 * 4);

    // rawRgba: пиксел тутам R,G,B,A дараалалтай нэг байт тус бүр.
    int red(int x, int y) => bytes.getUint8((y * 360 + x) * 4);
    final int bottomR = red(180, 780);
    final int topR = red(180, 20);

    // Шейдер ҮНЭХЭЭР ажилласны нотолгоо: доод талд хотын зэвэн туяа байгаа
    // тул улаан суваг дээд талаасаа ХАМААГҮЙ их байна. Хэрэв шейдер
    // ажиллаагүй бол бүх пиксел ижил гарна.
    expect(bottomR, greaterThan(topR + 20),
        reason: 'доод тал зэвэн туяатай байх ёстой — үгүй бол шейдер ажиллаагүй');
    // Хар хүрээ: булан нь голоосоо харанхуй.
    expect(red(4, 4), lessThan(red(180, 400) + 1),
        reason: 'хар хүрээ ажиллаагүй');

    shader.dispose();
    img.dispose();
  });

  test('2. drawVertices текстуртэй 3D гурвалжин зурж чадах уу?', () async {
    // Текстур — 64×64 шалмаг хээ.
    final Uint8List texels = Uint8List(64 * 64 * 4);
    for (int y = 0; y < 64; y++) {
      for (int x = 0; x < 64; x++) {
        final bool on = ((x ~/ 8) + (y ~/ 8)).isEven;
        final int i = (y * 64 + x) * 4;
        texels[i] = on ? 232 : 193;
        texels[i + 1] = on ? 228 : 68;
        texels[i + 2] = on ? 218 : 14;
        texels[i + 3] = 255;
      }
    }
    final ui.Image tex = await _decode(texels, 64, 64);

    // --- Жинхэнэ 3D: дөрвөлжинг Y тэнхлэгээр эргүүлж, перспективээр буулгана.
    const double fov = 1.2;
    const double near = 0.1;
    final double angle = 0.6;
    final double ca = math.cos(angle), sa = math.sin(angle);

    // Дэлхийн орон зайн 4 орой (ширээн дээрх хавтгай хөзөр гэж үз).
    const List<List<double>> corners = <List<double>>[
      <double>[-1, -1, 0],
      <double>[1, -1, 0],
      <double>[1, 1, 0],
      <double>[-1, 1, 0],
    ];

    final Float32List positions = Float32List(4 * 2);
    for (int i = 0; i < 4; i++) {
      final double x = corners[i][0], y = corners[i][1], z = corners[i][2];
      // Y эргэлт
      final double rx = x * ca + z * sa;
      final double rz = -x * sa + z * ca;
      // Камер руу шилжүүлэх
      final double cz = rz + 3.5;
      expect(cz, greaterThan(near), reason: 'орой камерын ард унасан');
      // Перспектив хуваалт
      final double px = (rx / cz) * (180 / math.tan(fov / 2)) + 180;
      final double py = (y / cz) * (180 / math.tan(fov / 2)) + 400;
      positions[i * 2] = px;
      positions[i * 2 + 1] = py;
    }

    final Float32List uvs = Float32List.fromList(<double>[
      0, 0, //
      64, 0, //
      64, 64, //
      0, 64, //
    ]);
    final Uint16List indices = Uint16List.fromList(<int>[0, 1, 2, 0, 2, 3]);

    final ui.Vertices vertices = ui.Vertices.raw(
      ui.VertexMode.triangles,
      positions,
      textureCoordinates: uvs,
      indices: indices,
    );

    final ui.PictureRecorder rec = ui.PictureRecorder();
    final ui.Canvas canvas = ui.Canvas(rec);
    canvas.drawColor(const Color(0xFF000000), BlendMode.src);
    canvas.drawVertices(
      vertices,
      BlendMode.srcOver,
      Paint()
        ..shader = ImageShader(
          tex,
          TileMode.clamp,
          TileMode.clamp,
          Matrix4.identity().storage,
        ),
    );
    final ui.Image out = await rec.endRecording().toImage(360, 800);
    final ByteData? bytes =
        await out.toByteData(format: ui.ImageByteFormat.rawRgba);

    expect(bytes, isNotNull);
    // Голд текстурын пиксел байх ёстой — хар биш.
    final int centre = bytes!.getUint32((400 * 360 + 180) * 4);
    expect(centre & 0xFFFFFF00, isNot(0),
        reason: 'гурвалжин зурагдаагүй — дэлгэцийн гол хар хэвээр байна');

    tex.dispose();
    out.dispose();
  });
}

Future<ui.Image> _decode(Uint8List px, int w, int h) {
  final Completer<ui.Image> c = Completer<ui.Image>();
  ui.decodeImageFromPixels(px, w, h, ui.PixelFormat.rgba8888, c.complete);
  return c.future;
}
