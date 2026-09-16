// Уур амьсгал — зураачгүйгээр «тоглоом шиг» харагдуулах давхарга.
//
// Зургийн файл НЭГ Ч БАЙХГҮЙ. Бүгд кодоор үүснэ: мөхлөг (grain), хар хүрээ
// (vignette), скан шугам, өнгөний хазайлт. Ингэснээр:
//   • апп-ын хэмжээ өсөхгүй (GDD-08 §11-ийн 4 МБ хязгаар),
//   • ямар ч дэлгэцийн нягтралд цэвэр,
//   • сэдэв солиход зураг дахин зурах шаардлагагүй.
//
// ГАР УТАСНЫ ЗАРДАЛ: мөхлөг нь 128×128 текстурыг давтан зурна — Redmi 9A дээр
// нэг кадрт 1 drawImageNine. Хөдөлгөөн багасгах горимд бүрэн унтарна.

import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'tokens.dart';

/// 128×128 мөхлөгний текстур — нэг удаа үүсээд бүх дэлгэцэд хуваалцагдана.
class _GrainTexture {
  static ui.Image? _image;
  static Future<ui.Image>? _pending;

  static ui.Image? get image => _image;

  static Future<ui.Image> ensure() {
    if (_image != null) return Future<ui.Image>.value(_image);
    return _pending ??= _build();
  }

  static Future<ui.Image> _build() {
    const int n = 128;
    final Uint8List px = Uint8List(n * n * 4);
    // Тогтмол seed — мөхлөг ажиллуулах болгонд ижил, golden зураг тогтвортой.
    final math.Random rnd = math.Random(20260916);
    for (int i = 0; i < n * n; i++) {
      final int v = 118 + rnd.nextInt(72);
      px[i * 4] = v;
      px[i * 4 + 1] = v;
      px[i * 4 + 2] = v;
      px[i * 4 + 3] = 255;
    }
    final Completer<ui.Image> c = Completer<ui.Image>();
    ui.decodeImageFromPixels(px, n, n, ui.PixelFormat.rgba8888, (ui.Image img) {
      _image = img;
      c.complete(img);
    });
    return c.future;
  }
}

/// Дэлгэц бүрийг ороох бүрхүүл. `Atmosphere(child: ...)`.
class Atmosphere extends StatefulWidget {
  const Atmosphere({
    super.key,
    required this.child,
    this.grain = 0.055,
    this.vignette = 0.85,
    this.scanlines = true,
    this.animate = true,
  });

  final Widget child;

  /// Мөхлөгний хүч. 0 бол огт зурахгүй.
  final double grain;

  /// Хар хүрээний хүч. Ширээн дунд байх дэлгэцэд илүү хүчтэй.
  final double vignette;

  final bool scanlines;
  final bool animate;

  @override
  State<Atmosphere> createState() => _AtmosphereState();
}

class _AtmosphereState extends State<Atmosphere>
    with SingleTickerProviderStateMixin {
  // `late final` БОЛОХГҮЙ: `animate: false` үед хэзээ ч хүрэлгүй үлдээд,
  // `dispose()` дотор сая үүсэхэд устгагдсан модноос `TickerMode` хайж унана.
  late final AnimationController _t;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _t = AnimationController(vsync: this, duration: const Duration(seconds: 1));
    _GrainTexture.ensure().then((_) {
      if (mounted) setState(() => _ready = true);
    });
    if (widget.animate) _t.repeat();
  }

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        widget.child,
        if (widget.grain > 0 && _ready)
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _t,
                builder: (BuildContext context, Widget? _) => CustomPaint(
                  painter: _AtmospherePainter(
                    grain: widget.grain,
                    vignette: widget.vignette,
                    scanlines: widget.scanlines,
                    // Хөдөлгөөн багасгах горимд мөхлөг зогсоно, гэхдээ
                    // ХЭВЭЭР БАЙНА — уур амьсгал нь чимэглэл биш, сэдэв.
                    phase: reduce || !widget.animate ? 0 : _t.value,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _AtmospherePainter extends CustomPainter {
  _AtmospherePainter({
    required this.grain,
    required this.vignette,
    required this.scanlines,
    required this.phase,
  });

  final double grain;
  final double vignette;
  final bool scanlines;
  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect r = Offset.zero & size;

    // --- Мөхлөг ------------------------------------------------------------
    final ui.Image? tex = _GrainTexture.image;
    if (tex != null && grain > 0) {
      // Кадр бүрд текстурыг шилжүүлж «амьд» мөхлөг гаргана.
      final double dx = (phase * 128) % 128;
      final double dy = ((phase * 79) % 1.0) * 128;
      final Matrix4 m = Matrix4.identity()..translateByDouble(-dx, -dy, 0, 1);
      final Paint p = Paint()
        ..shader = ImageShader(
          tex,
          TileMode.repeated,
          TileMode.repeated,
          m.storage,
        )
        ..blendMode = BlendMode.overlay
        ..color = Colors.white.withValues(alpha: grain);
      canvas.drawRect(r, p);
    }

    // --- Скан шугам --------------------------------------------------------
    if (scanlines) {
      final Paint line = Paint()
        // 0.10 байхад том цагаан тоо, тэмдэг дээр зураас хэт тод харагдаж,
        // унших чанарыг мууТгаж байв. Бүтэц үлдэнэ, хашгирахаа болино.
        ..color = Colors.black.withValues(alpha: 0.055)
        ..strokeWidth = 1;
      for (double y = 0; y < size.height; y += 3) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
      }
    }

    // --- Хар хүрээ ---------------------------------------------------------
    // ХЭМЖҮҮР: хүрээ нь АГУУЛГЫГ БҮДГЭРҮҮЛЭХГҮЙ. Эхний хувилбарт радиус
    // хэтэрхий жижиг байсан тул дэлгэцийн голд байсан гарчиг саарал болж,
    // доод талын үндсэн товч хагас унтарсан харагдаж байв. Одоо:
    //   • гол 58% бүрэн цэвэр,
    //   • зөвхөн ирмэг рүү гүнзгийрнэ,
    //   • ҮЙЛДЛИЙН ТУУЗ (доод 20%) нь нэмэлт багасгалтай.
    if (vignette > 0) {
      canvas.saveLayer(r, Paint());
      canvas.drawRect(
        r,
        Paint()
          ..shader = RadialGradient(
            center: Alignment.center,
            radius: 1.05,
            colors: <Color>[
              Colors.transparent,
              Colors.black.withValues(alpha: vignette * 0.20),
              Colors.black.withValues(alpha: vignette * 0.70),
            ],
            stops: const <double>[0.58, 0.84, 1.0],
          ).createShader(r),
      );
      // Доод тууз руу бүдгэрүүлэх маск — эрхий хүрэх товч бүрэн тод үлдэнэ.
      canvas.drawRect(
        r,
        Paint()
          ..blendMode = BlendMode.dstIn
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: const <Color>[
              Colors.black,
              Colors.black,
              Color(0x26000000),
            ],
            stops: const <double>[0.0, 0.80, 1.0],
          ).createShader(r),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_AtmospherePainter old) =>
      old.phase != phase ||
      old.grain != grain ||
      old.vignette != vignette ||
      old.scanlines != scanlines;
}

/// Өнгө хуваагдсан гарчиг — хямд, гэхдээ шууд «хэвлэмэл, элэгдсэн» мэдрэмж өгнө.
class ChromaticTitle extends StatelessWidget {
  const ChromaticTitle(
    this.text, {
    super.key,
    this.style,
    this.offset = 1.6,
    this.textAlign = TextAlign.center,
    this.semantics,
  });

  final String text;
  final TextStyle? style;
  final double offset;
  final TextAlign textAlign;

  /// Дэлгэц уншигчид хэлэх бүтэн өгүүлбэр. `null` бол `text` өөрөө.
  final String? semantics;

  @override
  Widget build(BuildContext context) {
    final TextStyle base = (style ?? kDisplay).copyWith(color: kBone);
    // ХҮРТЭЭМЖ: гурван хуулбар давхарлаж байгаа тул дэлгэц уншигч үгийг
    // ГУРВАН УДАА уншиж болзошгүй. Бүгдийг нь хаагаад НЭГ шошго өгнө.
    // `semantics` нь бүтэн гарчгийг («Хот унтлаа») дамжуулна.
    return Semantics(
      label: semantics ?? text,
      header: true,
      child: ExcludeSemantics(
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            Transform.translate(
              offset: Offset(-offset, 0),
              child: Text(
                text,
                textAlign: textAlign,
                style: base.copyWith(color: kRust.withValues(alpha: 0.85)),
              ),
            ),
            Transform.translate(
              offset: Offset(offset, 0),
              child: Text(
                text,
                textAlign: textAlign,
                style: base.copyWith(color: kCold.withValues(alpha: 0.65)),
              ),
            ),
            Text(text, textAlign: textAlign, style: base),
          ],
        ),
      ),
    );
  }
}

/// Элэгдсэн ирмэгтэй хүрээ — хөзрийн ар тал, картанд.
class InkFrame extends StatelessWidget {
  const InkFrame({
    super.key,
    required this.child,
    this.color = kBone,
    this.thickness = 2,
  });

  final Widget child;
  final Color color;
  final double thickness;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _InkFramePainter(color: color, thickness: thickness),
    child: Padding(padding: const EdgeInsets.all(14), child: child),
  );
}

class _InkFramePainter extends CustomPainter {
  _InkFramePainter({required this.color, required this.thickness});
  final Color color;
  final double thickness;

  @override
  void paint(Canvas canvas, Size size) {
    // Тогтмол seed — хүрээ кадр болгонд «чичрэхгүй».
    final math.Random rnd = math.Random(7);
    final Paint p = Paint()
      ..color = color
      ..strokeWidth = thickness
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final List<Offset> pts = <Offset>[
      const Offset(0, 0),
      Offset(size.width, 0),
      Offset(size.width, size.height),
      Offset(0, size.height),
    ];
    for (int i = 0; i < 4; i++) {
      final Offset a = pts[i];
      final Offset b = pts[(i + 1) % 4];
      // Шулуун биш — гараар зурсан мэт бага зэрэг мушгина.
      final Path path = Path()..moveTo(a.dx, a.dy);
      const int seg = 6;
      for (int s = 1; s <= seg; s++) {
        final double t = s / seg;
        final double jx = (rnd.nextDouble() - 0.5) * 2.2;
        final double jy = (rnd.nextDouble() - 0.5) * 2.2;
        path.lineTo(
          a.dx + (b.dx - a.dx) * t + jx,
          a.dy + (b.dy - a.dy) * t + jy,
        );
      }
      canvas.drawPath(path, p);
    }
  }

  @override
  bool shouldRepaint(_InkFramePainter old) =>
      old.color != color || old.thickness != thickness;
}
