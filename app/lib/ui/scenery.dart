// Тайзны эд зүйлс — дэлгэцийг «маягт» биш «тоглоом» болгодог давхарга.
//
// ЯАГААД ЭНЭ ФАЙЛ БАЙНА: 19 дэлгэцийн ихэнх нь хар дэвсгэр дээр нэг мөр
// бичигтэй байсан. Дүрэм зөв, харагдац хоосон. Хүн ширээн дунд утас өргөж
// байхад дэлгэц ямар нэг ЗҮЙЛ харагдах ёстой — хөзөр, тэмдэг, дугаар.
//
// Бүгд кодоор зурагдана. Зургийн файл НЭГ Ч БАЙХГҮЙ (GDD-08 §11).

import 'dart:math' as math;

import 'package:engine/engine.dart' show Role, Faction, factionOf;
import 'package:flutter/material.dart';

import 'tokens.dart';

// ---------------------------------------------------------------------------
// Дүрийн тэмдэг — хөзрийн нүүр дээрх том дүрс
// ---------------------------------------------------------------------------

/// Дүр бүрийн ТЭМДЭГ. Үг уншихаас өмнө дүрс нь хэлнэ — ангид хурдан.
///
///   • Алуурчин, Ахлагч — малгай. Ахлагчид тууз нэмэгдэнэ.
///   • Эмч — тойрогт загалмай.
///   • Мөрдөгч — томруулагч шил.
///   • Иргэн — хүний дүрс.
class RoleSigil extends StatelessWidget {
  const RoleSigil(this.role, {super.key, this.size = 120, this.color});

  final Role role;
  final double size;
  final Color? color;

  /// Дүрийн өнгө — мафи зэв, хотынхон яс.
  static Color colorOf(Role r) => factionOf(r) == Faction.mafi ? kRust : kBone;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: CustomPaint(painter: _SigilPainter(role, color ?? colorOf(role))),
  );
}

class _SigilPainter extends CustomPainter {
  _SigilPainter(this.role, this.color);
  final Role role;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final double s = size.shortestSide;
    final Paint stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.045
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final Paint fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    switch (role) {
      case Role.killer:
      case Role.boss:
        _hat(canvas, s, fill, stroke, band: role == Role.boss);

      case Role.doctor:
        canvas.drawCircle(Offset(s * 0.5, s * 0.5), s * 0.34, stroke);
        canvas.drawLine(
          Offset(s * 0.5, s * 0.30),
          Offset(s * 0.5, s * 0.70),
          stroke,
        );
        canvas.drawLine(
          Offset(s * 0.30, s * 0.5),
          Offset(s * 0.70, s * 0.5),
          stroke,
        );

      case Role.detective:
        canvas.drawCircle(Offset(s * 0.43, s * 0.42), s * 0.25, stroke);
        canvas.drawLine(
          Offset(s * 0.61, s * 0.60),
          Offset(s * 0.80, s * 0.79),
          stroke..strokeWidth = s * 0.075,
        );

      case Role.citizen:
        // Толгой ба мөр — хамгийн энгийн хүн.
        canvas.drawCircle(Offset(s * 0.5, s * 0.33), s * 0.16, stroke);
        canvas.drawArc(
          Rect.fromLTWH(s * 0.22, s * 0.54, s * 0.56, s * 0.52),
          math.pi,
          math.pi,
          false,
          stroke,
        );
    }
  }

  /// Малгай: дугуй оройтой, өргөн хэлхийтэй. Ахлагчид тууз.
  void _hat(
    Canvas canvas,
    double s,
    Paint fill,
    Paint stroke, {
    required bool band,
  }) {
    final Path crown = Path()
      ..moveTo(s * 0.30, s * 0.56)
      ..lineTo(s * 0.30, s * 0.38)
      ..quadraticBezierTo(s * 0.50, s * 0.20, s * 0.70, s * 0.38)
      ..lineTo(s * 0.70, s * 0.56)
      ..close();
    canvas.drawPath(crown, fill);
    // Хэлхий — нимгэн зууван.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(s * 0.5, s * 0.60),
        width: s * 0.84,
        height: s * 0.16,
      ),
      fill,
    );
    if (band) {
      final Paint cut = Paint()
        ..blendMode = BlendMode.clear
        ..style = PaintingStyle.fill;
      canvas.saveLayer(Rect.fromLTWH(0, 0, s, s), Paint());
      canvas.drawPath(crown, fill);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(s * 0.5, s * 0.60),
          width: s * 0.84,
          height: s * 0.16,
        ),
        fill,
      );
      canvas.drawRect(
        Rect.fromLTWH(s * 0.28, s * 0.47, s * 0.44, s * 0.055),
        cut,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_SigilPainter old) =>
      old.role != role || old.color != color;
}

// ---------------------------------------------------------------------------
// Суудлын медаль — том дугаар, гараар зурсан цагираг дотор
// ---------------------------------------------------------------------------

/// Дамжуулах, шөнийн эргэлт, хөзөр харах дэлгэцийн гол дүрс.
/// Ширээний нөгөө талаас ч дугаар нь уншигдана.
class SeatMedallion extends StatelessWidget {
  const SeatMedallion({
    super.key,
    required this.seat,
    this.size = 190,
    this.color = kBone,
    this.accent,
    this.dim = false,
  });

  final int seat;
  final double size;
  final Color color;

  /// Цагирагны өнгө. `null` бол `color`-ын бүдэг хувилбар.
  final Color? accent;

  /// Хасагдсан суудал — бүдэг, зураастай.
  final bool dim;

  @override
  Widget build(BuildContext context) {
    final Color c = dim ? color.withValues(alpha: 0.32) : color;
    // Цагираг нь тоонд ойр жинтэй байх ёстой — хэт бүдгэрвэл «унтарсан»
    // харагдана. Медаль бол ширээн дээрх ганц гэрэлтэй зүйл.
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _MedallionPainter(
          seed: seat,
          ring: (accent ?? c).withValues(alpha: dim ? 0.25 : 0.78),
          slash: dim,
        ),
        child: Center(
          child: Text(
            '$seat',
            style: kSeatNumber.copyWith(color: c, fontSize: size * 0.40),
          ),
        ),
      ),
    );
  }
}

class _MedallionPainter extends CustomPainter {
  _MedallionPainter({
    required this.seed,
    required this.ring,
    required this.slash,
  });

  final int seed;
  final Color ring;
  final bool slash;

  @override
  void paint(Canvas canvas, Size size) {
    final double s = size.shortestSide;
    final Offset c = Offset(s / 2, s / 2);
    // Суудал тутам өөр «гар» — суудлын дугаараар үрждэг тогтмол seed.
    final math.Random rnd = math.Random(seed * 977 + 13);
    final Paint p = Paint()
      ..color = ring
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;

    // Хоёр давхар, тэгш бус цагираг — циркулиар биш, гараар зурсан мэт.
    for (int layer = 0; layer < 2; layer++) {
      final double r = s * (layer == 0 ? 0.42 : 0.455);
      final Path path = Path();
      const int steps = 48;
      for (int i = 0; i <= steps; i++) {
        final double a = i / steps * math.pi * 2;
        final double jitter = 1 + (rnd.nextDouble() - 0.5) * 0.035;
        final Offset q =
            c + Offset(math.cos(a) * r * jitter, math.sin(a) * r * jitter);
        if (i == 0) {
          path.moveTo(q.dx, q.dy);
        } else {
          path.lineTo(q.dx, q.dy);
        }
      }
      path.close();
      canvas.drawPath(path, p..strokeWidth = layer == 0 ? 2.2 : 1.0);
    }

    if (slash) {
      canvas.drawLine(
        c + Offset(-s * 0.32, s * 0.32),
        c + Offset(s * 0.32, -s * 0.32),
        p..strokeWidth = 2.4,
      );
    }
  }

  @override
  bool shouldRepaint(_MedallionPainter old) =>
      old.seed != seed || old.ring != ring || old.slash != slash;
}

// ---------------------------------------------------------------------------
// Шөнийн дэвсгэр — хар боловч амьд
// ---------------------------------------------------------------------------

/// Хоосон хар дэлгэц бол алдаа. Энэ нь маш нам гүм, гэхдээ гүнтэй:
/// доод талд бүдэг зэвэн гэрэл (хотын гэрэл), дээгүүр нь тоосны ширхэг.
///
/// Хөдөлгөөн багасгах горимд ширхэг зогсоно, гэрэл үлдэнэ.
class NightBackdrop extends StatelessWidget {
  const NightBackdrop({
    super.key,
    this.glow = 0.55,
    this.motes = 26,
    this.seed = 11,
  });

  /// Доод гэрлийн хүч. 0 бол цэвэр хар.
  final double glow;
  final int motes;
  final int seed;

  @override
  Widget build(BuildContext context) => Positioned.fill(
    child: IgnorePointer(
      child: CustomPaint(
        painter: _NightPainter(glow: glow, motes: motes, seed: seed),
      ),
    ),
  );
}

class _NightPainter extends CustomPainter {
  _NightPainter({required this.glow, required this.motes, required this.seed});

  final double glow;
  final int motes;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect r = Offset.zero & size;

    if (glow > 0) {
      // Хотын гэрэл — доод ирмэгээс дээш сарних зэвэн туяа.
      canvas.drawRect(
        r,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: <Color>[
              kRust.withValues(alpha: 0.13 * glow),
              kRust.withValues(alpha: 0.035 * glow),
              Colors.transparent,
            ],
            stops: const <double>[0.0, 0.18, 0.52],
          ).createShader(r),
      );
      // Хүйтэн саран туяа — дээд буланд, эсрэг өнгө.
      canvas.drawRect(
        r,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.75, -0.95),
            radius: 1.05,
            colors: <Color>[
              kCold.withValues(alpha: 0.10 * glow),
              Colors.transparent,
            ],
          ).createShader(r),
      );
    }

    // Тоосны ширхэг — маш бүдэг, тогтмол seed тул golden зураг тогтвортой.
    final math.Random rnd = math.Random(seed);
    final Paint dot = Paint()..style = PaintingStyle.fill;
    for (int i = 0; i < motes; i++) {
      final double x = rnd.nextDouble() * size.width;
      final double y = rnd.nextDouble() * size.height;
      final double rad = 0.6 + rnd.nextDouble() * 1.5;
      dot.color = kBone.withValues(alpha: 0.03 + rnd.nextDouble() * 0.07);
      canvas.drawCircle(Offset(x, y), rad, dot);
    }
  }

  @override
  bool shouldRepaint(_NightPainter old) =>
      old.glow != glow || old.motes != motes || old.seed != seed;
}

// ---------------------------------------------------------------------------
// Гарчгийн хавтан — маягт шиг дэлгэцийг хуудас болгоно
// ---------------------------------------------------------------------------

/// Дэлгэцийн толгой: зэвэн зураас, шахмал гарчиг, баруун талд алхмын тоо.
/// «Тохиргоо» биш «бүлэг» гэсэн мэдрэмж өгнө.
class SlabHeader extends StatelessWidget {
  const SlabHeader({
    super.key,
    required this.title,
    this.step,
    this.subtitle,
    this.trailing,
  });

  final String title;

  /// «2 / 4» гэх мэт. `null` бол харагдахгүй.
  final String? step;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(kGutter, 18, kGutter, 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Container(width: 26, height: 3, color: kRust),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title.toUpperCase(),
                style: kTitle.copyWith(fontSize: 22, color: kBone),
              ),
            ),
            if (step != null)
              Text(step!, style: kLabel.copyWith(color: kTextMuted)),
            if (trailing != null) trailing!,
          ],
        ),
        if (subtitle != null) ...<Widget>[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 36),
            child: Text(
              subtitle!,
              style: kBody.copyWith(fontSize: 14, color: kTextMuted),
            ),
          ),
        ],
      ],
    ),
  );
}
