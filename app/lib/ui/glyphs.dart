// Тэмдэгүүд — фонтоос ХАМААРАХГҮЙ, бүгд зурагддаг.
//
// ЯАГААД: `→ ● ○ ◉ ▲ ▾ ✕ ⊘ ↺ ≡ ⌫ ⚙ 📌` зэрэг тэмдэгт Oswald, Rubik хоёрын
// аль алинд БАЙХГҮЙ. Утсан дээр систем өөр фонт руу унана — жин, өндөр нь
// зөрж, зарим ROM дээр огт байхгүй бол хоосон дөрвөлжин гарна. Golden
// зурагт яг тэр дөрвөлжингүүд илэрсэн.
//
// Тиймээс тэмдэг бүрийг `CustomPainter`-аар зурна. Ашиг:
//   • ямар ч төхөөрөмж дээр ижил,
//   • өнгө, жин, хэмжээг бид бүрэн удирдана,
//   • Material-ийн дүрсний «апп» дүр төрхгүй — гараар зурсан аястай.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'tokens.dart';

enum MarkShape {
  /// Тоолуурын хасах/нэмэх.
  minus,
  plus,

  /// Дүүрэн цэг — «алдаж болох санал» нэг нэгж, эсвэл иргэний тэмдэг.
  discFilled,

  /// Хоосон цэг — сонгогдоогүй.
  discHollow,

  /// Голтой цэг — сонгогдсон (радио товч).
  discTarget,

  /// Гурвалжин — мафийн тэмдэг. Хурц, тогтворгүй.
  triangle,

  /// Загалмай — үгүй, олдсонгүй, хаагдсан.
  cross,

  /// Чагт — тийм, батлагдсан.
  check,

  caretDown,
  caretRight,
  arrowRight,

  /// Араа — тохиргоо.
  gear,

  /// Асуулт — тусламж.
  question,

  /// Устгах товч — тоо оруулах гар дээр.
  backspace,

  /// Гурван зураас — чирэх бариул.
  bars,

  /// Эргүүлэх сум — буцаах.
  undo,

  /// Зурсан дугуй — оролцохгүй.
  block,

  /// Тэмдэглэгээ — өдрийн дэвтэрт хадах.
  pin,
}

/// Зурагдсан тэмдэг. `size` нь дөрвөлжин талбайн хэмжээ.
class Mark extends StatelessWidget {
  const Mark(
    this.shape, {
    super.key,
    this.size = 20,
    this.color = kBone,
    this.weight = 2,
  });

  final MarkShape shape;
  final double size;
  final Color color;

  /// Зураасны зузаан. Жижиг хэмжээнд 1.5, том хэмжээнд 2.5 тохиромжтой.
  final double weight;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: CustomPaint(
      painter: _MarkPainter(shape: shape, color: color, weight: weight),
    ),
  );
}

class _MarkPainter extends CustomPainter {
  _MarkPainter({
    required this.shape,
    required this.color,
    required this.weight,
  });

  final MarkShape shape;
  final Color color;
  final double weight;

  @override
  void paint(Canvas canvas, Size size) {
    final double s = size.shortestSide;
    // Нэгж хайрцагт (0..1) зураад хэмжээгээр нь үржүүлнэ.
    Offset p(double x, double y) => Offset(x * s, y * s);

    final Paint stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = weight
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final Paint fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    switch (shape) {
      case MarkShape.minus:
        canvas.drawLine(p(0.22, 0.5), p(0.78, 0.5), stroke);

      case MarkShape.plus:
        canvas.drawLine(p(0.22, 0.5), p(0.78, 0.5), stroke);
        canvas.drawLine(p(0.5, 0.22), p(0.5, 0.78), stroke);

      case MarkShape.discFilled:
        canvas.drawCircle(p(0.5, 0.5), s * 0.30, fill);

      case MarkShape.discHollow:
        canvas.drawCircle(p(0.5, 0.5), s * 0.28, stroke);

      case MarkShape.discTarget:
        canvas.drawCircle(p(0.5, 0.5), s * 0.30, stroke);
        canvas.drawCircle(p(0.5, 0.5), s * 0.14, fill);

      case MarkShape.triangle:
        canvas.drawPath(
          Path()
            ..moveTo(s * 0.5, s * 0.16)
            ..lineTo(s * 0.88, s * 0.82)
            ..lineTo(s * 0.12, s * 0.82)
            ..close(),
          fill,
        );

      case MarkShape.cross:
        canvas.drawLine(p(0.24, 0.24), p(0.76, 0.76), stroke);
        canvas.drawLine(p(0.76, 0.24), p(0.24, 0.76), stroke);

      case MarkShape.check:
        canvas.drawPath(
          Path()
            ..moveTo(s * 0.20, s * 0.53)
            ..lineTo(s * 0.42, s * 0.74)
            ..lineTo(s * 0.80, s * 0.26),
          stroke,
        );

      case MarkShape.caretDown:
        canvas.drawPath(
          Path()
            ..moveTo(s * 0.26, s * 0.40)
            ..lineTo(s * 0.50, s * 0.64)
            ..lineTo(s * 0.74, s * 0.40),
          stroke,
        );

      case MarkShape.caretRight:
        canvas.drawPath(
          Path()
            ..moveTo(s * 0.40, s * 0.26)
            ..lineTo(s * 0.64, s * 0.50)
            ..lineTo(s * 0.40, s * 0.74),
          stroke,
        );

      case MarkShape.arrowRight:
        canvas.drawLine(p(0.16, 0.5), p(0.82, 0.5), stroke);
        canvas.drawPath(
          Path()
            ..moveTo(s * 0.58, s * 0.28)
            ..lineTo(s * 0.84, s * 0.50)
            ..lineTo(s * 0.58, s * 0.72),
          stroke,
        );

      case MarkShape.gear:
        // Араа: гол дугуй + 8 шүд. Material-ийн дүрс биш, нимгэн зурсан.
        canvas.drawCircle(p(0.5, 0.5), s * 0.24, stroke);
        canvas.drawCircle(p(0.5, 0.5), s * 0.08, stroke);
        for (int i = 0; i < 8; i++) {
          final double a = i * math.pi / 4;
          canvas.drawLine(
            p(0.5 + math.cos(a) * 0.30, 0.5 + math.sin(a) * 0.30),
            p(0.5 + math.cos(a) * 0.42, 0.5 + math.sin(a) * 0.42),
            stroke,
          );
        }

      case MarkShape.question:
        // Асуултын тэмдгийг ч зурна — фонтын жинтэй зөрөхгүй.
        canvas.drawPath(
          Path()
            ..moveTo(s * 0.32, s * 0.34)
            ..cubicTo(
              s * 0.33,
              s * 0.14,
              s * 0.70,
              s * 0.14,
              s * 0.68,
              s * 0.36,
            )
            ..cubicTo(
              s * 0.66,
              s * 0.52,
              s * 0.50,
              s * 0.50,
              s * 0.50,
              s * 0.66,
            ),
          stroke,
        );
        canvas.drawCircle(p(0.50, 0.82), weight * 0.9, fill);

      case MarkShape.backspace:
        canvas.drawPath(
          Path()
            ..moveTo(s * 0.08, s * 0.50)
            ..lineTo(s * 0.32, s * 0.22)
            ..lineTo(s * 0.90, s * 0.22)
            ..lineTo(s * 0.90, s * 0.78)
            ..lineTo(s * 0.32, s * 0.78)
            ..close(),
          stroke,
        );
        canvas.drawLine(p(0.46, 0.38), p(0.74, 0.62), stroke);
        canvas.drawLine(p(0.74, 0.38), p(0.46, 0.62), stroke);

      case MarkShape.bars:
        for (final double y in <double>[0.32, 0.50, 0.68]) {
          canvas.drawLine(p(0.20, y), p(0.80, y), stroke);
        }

      case MarkShape.undo:
        canvas.drawArc(
          Rect.fromCircle(center: p(0.5, 0.54), radius: s * 0.28),
          -math.pi * 0.55,
          math.pi * 1.55,
          false,
          stroke,
        );
        canvas.drawPath(
          Path()
            ..moveTo(s * 0.34, s * 0.20)
            ..lineTo(s * 0.34, s * 0.40)
            ..lineTo(s * 0.54, s * 0.40),
          stroke,
        );

      case MarkShape.block:
        canvas.drawCircle(p(0.5, 0.5), s * 0.32, stroke);
        canvas.drawLine(p(0.27, 0.73), p(0.73, 0.27), stroke);

      case MarkShape.pin:
        // Дарцаг хэлбэр — дэвтэрт хадсан тэмдэглэл.
        canvas.drawPath(
          Path()
            ..moveTo(s * 0.28, s * 0.16)
            ..lineTo(s * 0.72, s * 0.16)
            ..lineTo(s * 0.72, s * 0.84)
            ..lineTo(s * 0.50, s * 0.64)
            ..lineTo(s * 0.28, s * 0.84)
            ..close(),
          fill,
        );
    }
  }

  @override
  bool shouldRepaint(_MarkPainter old) =>
      old.shape != shape || old.color != color || old.weight != weight;
}

/// Хүрэх талбайтай тэмдэг-товч. Хамгийн бага 48dp (GDD-08 §8).
class MarkButton extends StatelessWidget {
  const MarkButton({
    super.key,
    required this.shape,
    required this.semantic,
    required this.onTap,
    this.color = kTextMuted,
    this.size = 22,
    this.box = kMinTouch,
    this.weight = 2,
  });

  final MarkShape shape;
  final String semantic;

  /// `null` бол идэвхгүй — өнгө нь бүдгэрнэ.
  final VoidCallback? onTap;
  final Color color;
  final double size;
  final double box;
  final double weight;

  @override
  Widget build(BuildContext context) {
    final bool on = onTap != null;
    return Semantics(
      button: true,
      enabled: on,
      label: semantic,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: box,
          height: box,
          child: Center(
            child: Mark(
              shape,
              size: size,
              weight: weight,
              color: on ? color : color.withValues(alpha: 0.30),
            ),
          ),
        ),
      ),
    );
  }
}

/// Цэгийн эгнээ — «алдаж болох санал» гэх мэт тоог ЗУРГААР үзүүлнэ.
/// Тоо биш, харагдах хэмжээ: 3 цэг бол гурван алдаа гэдэг нь шууд ойлгогдоно.
class MarkPips extends StatelessWidget {
  const MarkPips({
    super.key,
    required this.count,
    this.color = kBone,
    this.size = 12,
    this.gap = 6,
    this.max = 8,
  });

  final int count;
  final Color color;
  final double size;
  final double gap;

  /// Үүнээс олон бол «●●● ×12» болгож богиносгоно — 360px-д багтаана.
  final int max;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) {
      return Mark(MarkShape.cross, size: size + 2, color: color, weight: 2);
    }
    final int shown = count > max ? max : count;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (int i = 0; i < shown; i++) ...<Widget>[
          if (i > 0) SizedBox(width: gap),
          Mark(MarkShape.discFilled, size: size, color: color),
        ],
        if (count > max)
          Padding(
            padding: EdgeInsets.only(left: gap),
            child: Text(
              '+${count - max}',
              style: kLabel.copyWith(color: color, fontSize: 12),
            ),
          ),
      ],
    );
  }
}
