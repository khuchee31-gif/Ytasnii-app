// ШИРЭЭ — тоглоомын гол тайз.
//
// Buckshot Roulette, Liar's Bar хоёрыг судалснаас гарсан гурван дүрэм:
//   1. ШИРЭЭ дэлгэцийн доод хагасыг эзэлнэ. Тэр бол тайзны шал.
//   2. Дүрүүд эсрэг талд, цээжнээс дээш, ширээний ирмэгээс ургана.
//   3. Дээрээс ГАНЦ хатуу гэрэл. Бусад нь харанхуй.
//
// БҮТЭЭХ АРГА:
//   • Ширээ — `drawVertices` (жинхэнэ 3D хавтгай, орой тутам гэрэлтүүлэгтэй).
//   • Дүрүүд — БИЛБОРД, өөрөөр хэлбэл гүнээр нь хэмжээ нь тодорхойлогддог
//     энгийн 2D зураг. Үргэлж камер руу харна.
//
// ЯАГААД ДҮРД `drawVertices` АШИГЛААГҮЙ ВЭ: билбордын дөрвөлжин үргэлж
// дэлгэцтэй параллель тул перспектив гажилт хэрэггүй. 2D-ээр зурснаар
// ирмэгийг нь зөөлрүүлэх маск тавих боломжтой болно — AI-аар үүсгэсэн
// зураг тэгш өнцөгт дэвсгэртэй ирдэг тул энэ нь ЗААВАЛ хэрэгтэй.

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'scene3d.dart';
import 'tokens.dart';

/// Ширээнд сууж буй нэг хүн.
class SeatOccupant {
  const SeatOccupant({
    required this.seat,
    this.portrait,
    this.name,
    this.alive = true,
    this.speaking = false,
    this.highlighted = false,
  });

  final int seat;

  /// Дүрийн зураг. `null` бол зөвхөн дугаартай сүүдэр зурагдана.
  final ui.Image? portrait;

  final String? name;
  final bool alive;

  /// Яг одоо ярьж байна — гэрэл нэмэгдэнэ.
  final bool speaking;

  /// Сонгогдсон (санал өгөх, шөнийн бай).
  final bool highlighted;
}

/// Ширээний тайз.
class TableScene extends StatelessWidget {
  const TableScene({
    super.key,
    required this.occupants,
    required this.viewerSeat,
    this.seatCount,
    this.lamp = 1.0,
    this.onTapSeat,
    this.yaw = 0,
  });

  final List<SeatOccupant> occupants;

  /// Камер аль суудлаас харах вэ.
  final int viewerSeat;

  /// `null` бол `occupants`-ын тоогоор.
  final int? seatCount;

  /// Чийдэнгийн хүч. Шөнө багасна.
  final double lamp;

  final void Function(int seat)? onTapSeat;

  /// Толгой эргүүлэх өнцөг. Хэрэглэгч хөндлөн чирэхэд өөрчлөгдөнө.
  final double yaw;

  @override
  Widget build(BuildContext context) {
    final int n = seatCount ?? occupants.length;
    if (n < 2) return const ColoredBox(color: kNight);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints box) {
        final TableLayout layout = TableLayout(seatCount: n);
        final Camera3D cam = layout.cameraFor(viewerSeat, yaw: yaw);
        final Size size = Size(box.maxWidth, box.maxHeight);

        return GestureDetector(
          onTapUp: onTapSeat == null
              ? null
              : (TapUpDetails d) {
                  final int? s = _seatAtPoint(
                    d.localPosition,
                    size,
                    layout,
                    cam,
                    occupants,
                    viewerSeat,
                  );
                  if (s != null) onTapSeat!(s);
                },
          child: CustomPaint(
            size: size,
            painter: _ScenePainter(
              occupants: occupants,
              viewerSeat: viewerSeat,
              layout: layout,
              cam: cam,
              lamp: lamp,
            ),
          ),
        );
      },
    );
  }
}

/// Дэлгэцийн цэг аль суудал дээр буув.
///
/// Билбордууд давхарлаж болох тул ХАМГИЙН ОЙРЫГ нь сонгоно — хүн урд
/// байгаа дүрийг дарах гэж байгаа нь ойлгомжтой.
int? _seatAtPoint(
  Offset p,
  Size size,
  TableLayout layout,
  Camera3D cam,
  List<SeatOccupant> occupants,
  int viewerSeat,
) {
  int? best;
  double bestDepth = double.infinity;
  for (final SeatOccupant o in occupants) {
    if (o.seat == viewerSeat) continue;
    final Vec3 head = layout.headOf(o.seat, viewerSeat);
    final Projected pr = cam.project(head, size.width, size.height);
    if (!pr.visible || pr.depth < _kMinDepth || !_inView(cam, head)) continue;
    final double h = math.min(
      _billboardHeight(pr.depth, size),
      size.height * _kMaxHeightFrac,
    );
    final double w = h * _kPortraitAspect;
    final Rect r = Rect.fromCenter(
      center: Offset(pr.x, pr.y),
      width: w,
      height: h,
    );
    if (r.contains(p) && pr.depth < bestDepth) {
      bestDepth = pr.depth;
      best = o.seat;
    }
  }
  return best;
}

/// Дүрийн зургийн харьцаа (өргөн ÷ өндөр).
const double _kPortraitAspect = 0.82;

/// Гүнээс билбордын өндрийг гаргана.
///
/// Тогтмолыг ХЭМЖИЖ сонгосон: 12 суудалтай ширээнд эсрэг талын дүр ~240 px.
double _billboardHeight(double depth, Size size) => (size.width * 3.05) / depth;

/// Үүнээс ойр суудлыг ОГТ ЗУРАХГҮЙ.
///
/// ЯАГААД ЗААВАЛ: камер жинхэнэ суугаагийн нүдэнд байгаа тул хажуу талын
/// суудал ердөө 1 нэгжийн зайд байна. Тэр нь билбордыг 1000 px болгож,
/// дэлгэцийг БҮХЭЛД НЬ халхалж байв — ширээ, бусад дүр бүгд алга болсон.
///
/// Бодит амьдрал дээр ч ширээнд сууж байхад хажуудах хүн ХАРАГДДАГГҮЙ:
/// тэр бол хараанаас гадуур. Толгойгоо эргүүлбэл (`yaw`) гүн нь нэмэгдэж,
/// энэ хязгаарыг давж, ХАРАГДАНА.
const double _kMinDepth = 1.75;

/// Билбордын дээд хязгаар — дэлгэцийн өндрийн хувиар.
///
/// Зүсэлтийн дараа ч нэг дүр дэлгэцийн ихэнхийг эзлэх ёсгүй.
const double _kMaxHeightFrac = 0.46;

/// Хараанаас ХЭР ХОЛ суудлыг зурах вэ — харах өнцгийн хувиар.
///
/// Гүнээр зүсэх нь хангалтгүй байв: хажуугийн суудал гүн нь хангалттай ч
/// дэлгэцийн ирмэг дээр ТАЛААР нь тасарч, хагас нүүр өлгөөтэй байв.
/// Өнцгөөр зүсэхэд тэр нь цэвэр алга болно.
const double _kFovMargin = 1.05;

/// Суудал камерын хараанд байна уу.
bool _inView(Camera3D cam, Vec3 world) {
  final Vec3 v = cam.toView(world);
  final double depth = -v.z;
  if (depth <= 0.01) return false;
  return (v.x.abs() / depth) <= math.tan(cam.fovX / 2) * _kFovMargin;
}

class _ScenePainter extends CustomPainter {
  _ScenePainter({
    required this.occupants,
    required this.viewerSeat,
    required this.layout,
    required this.cam,
    required this.lamp,
  });

  final List<SeatOccupant> occupants;
  final int viewerSeat;
  final TableLayout layout;
  final Camera3D cam;
  final double lamp;

  @override
  void paint(Canvas canvas, Size size) {
    _paintRoom(canvas, size);
    _paintTable(canvas, size);
    _paintPlates(canvas, size);
    _paintOccupants(canvas, size);
    _paintLampGlow(canvas, size);
  }

  // --- Өрөө ---------------------------------------------------------------

  void _paintRoom(Canvas canvas, Size size) {
    final Rect r = Offset.zero & size;
    canvas.drawRect(r, Paint()..color = kNight);

    // Ард хана — дээрээс доош бага зэрэг гэрэлтэй, тэгээд гүн харанхуй.
    canvas.drawRect(
      r,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(size.width / 2, 0),
          Offset(size.width / 2, size.height),
          <Color>[
            const Color(0xFF13151A),
            const Color(0xFF0A0B0D),
            kNight,
            kNight,
          ],
          <double>[0.0, 0.30, 0.55, 1.0],
        ),
    );
  }

  // --- Ширээ: ЖИНХЭНЭ 3D --------------------------------------------------

  void _paintTable(Canvas canvas, Size size) {
    const int rim = 48;
    final List<double> pos = <double>[];
    final List<Color> col = <Color>[];

    // Төв орой.
    final Projected c = cam.project(Vec3.zero, size.width, size.height);
    if (!c.visible) return;
    pos.addAll(<double>[c.x, c.y]);
    col.add(_tableColour(Vec3.zero));

    // Ирмэгийн оройнууд. Ширээ нь суудлын тойргоос бага зэрэг дотогш.
    // ХЭМЖСЭН: 0.74 үед ширээ дүрүүдээс ХОЛ байж, хооронд нь хоосон шал
    // үлдэж байв; 0.60 үед бүр холдов. Бодит ширээнд хүн ИРМЭГ дээр нь
    // сууна — 0.88 нь тэр зайг хаана. Хосолсон камерын өөрчлөлттэй хамт
    // ширээний ойр ирмэг дэлгэцээс давж, доод хэсэг дүүрнэ.
    final double tableR = layout.radius * 0.88;
    bool anyVisible = false;
    for (int i = 0; i <= rim; i++) {
      final double a = i / rim * math.pi * 2;
      final Vec3 w = Vec3(math.sin(a) * tableR, 0, math.cos(a) * tableR);
      final Projected p = cam.project(w, size.width, size.height);
      // Камерын ард унасан оройг төв рүү унагаана — ингэснээр гурвалжин
      // эвдрэхгүй, зүгээр л нарийсна.
      pos.addAll(p.visible ? <double>[p.x, p.y] : <double>[c.x, c.y]);
      // Модны ааз — орой тутам бага зэрэг хэлбэлзэл. Тогтмол тул
      // кадр болгонд чичрэхгүй; хавтгай диск мэт харагдахаас сэргийлнэ.
      col.add(_tableColour(w, grain: 0.88 + 0.24 * _hash(i)));
      anyVisible |= p.visible;
    }
    if (!anyVisible) return;

    canvas.drawVertices(
      ui.Vertices(ui.VertexMode.triangleFan, <Offset>[
        for (int i = 0; i < pos.length; i += 2) Offset(pos[i], pos[i + 1]),
      ], colors: col),
      BlendMode.srcOver,
      Paint(),
    );

    // Ирмэгийн гэрэл — ширээний зах чийдэнгийн доор гялалзана.
    final Path edge = Path();
    for (int i = 0; i <= rim; i++) {
      final double a = i / rim * math.pi * 2;
      final Vec3 w = Vec3(math.sin(a) * tableR, 0, math.cos(a) * tableR);
      final Projected p = cam.project(w, size.width, size.height);
      if (!p.visible) continue;
      if (edge.getBounds().isEmpty) {
        edge.moveTo(p.x, p.y);
      } else {
        edge.lineTo(p.x, p.y);
      }
    }
    canvas.drawPath(
      edge,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = kBone.withValues(alpha: 0.10 * lamp),
    );
  }

  /// Ширээний оройн өнгө — чийдэнгээс хол байх тусам харанхуй.
  ///
  /// ӨСГӨЛТ: `lampFalloff` нь бодит физикийн бууралт тул ширээний төвд
  /// ердөө 0.15 орчим утга өгдөг — тэр нь дэлгэц дээр бараг хар. Бууралтын
  /// ХЭЛБЭРИЙГ хэвээр үлдээж (ирмэг рүү хурдан харанхуйлна), утгыг нь
  /// өсгөнө. Ингэснээр ширээ ХАРАГДАНА, гэхдээ хавтгай биш.
  Color _tableColour(Vec3 w, {double grain = 1.0}) {
    final double l = math.min(1.0, lampFalloff(w) * lamp * 1.85);
    // Модны дулаан өнгө, гэрлээр үржүүлсэн. Ханалтыг БУУРУУЛСАН: өмнө нь
    // хуванцар диск шиг тод улбар шар болж, дүрүүдээс илүү анхаарал татаж
    // байв. Ширээ бол ТАЙЗ, гол дүр биш.
    return Color.from(
      alpha: 1.0,
      red: (0.045 + 0.20 * l) * grain,
      green: (0.033 + 0.125 * l) * grain,
      blue: (0.027 + 0.080 * l) * grain,
    );
  }

  // --- Дүрүүд: билборд ----------------------------------------------------

  void _paintOccupants(Canvas canvas, Size size) {
    // Хол байгаагаас нь эхэлж зурна — ойрынх нь дээр гарна (зураачийн арга).
    final List<({SeatOccupant o, Projected p})> drawable =
        <({SeatOccupant o, Projected p})>[];
    for (final SeatOccupant o in occupants) {
      if (o.seat == viewerSeat) continue; // өөрийгөө харахгүй
      final Projected p = cam.project(
        layout.headOf(o.seat, viewerSeat),
        size.width,
        size.height,
      );
      final Vec3 head = layout.headOf(o.seat, viewerSeat);
      if (!p.visible || p.depth < _kMinDepth || !_inView(cam, head)) continue;
      drawable.add((o: o, p: p));
    }
    drawable.sort(
      (({SeatOccupant o, Projected p}) a, ({SeatOccupant o, Projected p}) b) =>
          b.p.depth.compareTo(a.p.depth),
    );

    for (final ({SeatOccupant o, Projected p}) d in drawable) {
      _paintOne(canvas, size, d.o, d.p);
    }
  }

  void _paintOne(Canvas canvas, Size size, SeatOccupant o, Projected p) {
    final double h = math.min(
      _billboardHeight(p.depth, size),
      size.height * _kMaxHeightFrac,
    );
    final double w = h * _kPortraitAspect;
    final Rect dst = Rect.fromCenter(
      center: Offset(p.x, p.y - h * 0.10),
      width: w,
      height: h,
    );

    // Гэрэлтүүлэг: чийдэнгээс хол суудал бүдэг. Ярьж байвал нэмэгдэнэ.
    // Толгой ширээнээс дээш тул чийдэнд ОЙР — гэрэлтүүлэг нь ширээнийхээс
    // хүчтэй. Доод хязгаарыг 0.55 болгосон: түүнээс бага бол нүүр танигдахаа
    // больж, 12 дүр бүгд нэг ижил хар сүүдэр болно.
    double lit = math.min(
      1.0,
      lampFalloff(layout.headOf(o.seat, viewerSeat)) * lamp * 2.2,
    );
    lit = 0.55 + lit * 0.45;
    if (o.speaking) lit = math.min(1.0, lit + 0.30);
    if (!o.alive) lit *= 0.35;

    // НЭМЭЛТ ХОЛИЛТ. Хөргийн дэвсгэр ХАР (rembg-ээр тасалсан) тул нэмэлт
    // холилтод тэр нь ЮУ Ч НЭМЭХГҮЙ — өөрөөр хэлбэл бүрэн ил тод болно.
    //
    // Өмнө нь энгийн `srcOver`-оор зурахад хар дэвсгэр нь ханыг ХАЛХАЛЖ,
    // билбордуудын дээд ирмэг нэг шугам болж харагдаж байв. Нэмэлт
    // холилтод дүр харанхуйгаас ГЭРЭЛТЭЖ гарах мэт болно — харанхуй
    // өрөөнд яг тохирно.
    canvas.saveLayer(dst.inflate(2), Paint()..blendMode = BlendMode.plus);

    if (o.portrait != null) {
      canvas.drawImageRect(
        o.portrait!,
        Rect.fromLTWH(
          0,
          0,
          o.portrait!.width.toDouble(),
          o.portrait!.height.toDouble(),
        ),
        dst,
        Paint()
          ..filterQuality = FilterQuality.medium
          // Гэрэлтүүлгийг ҮРЖҮҮЛЭЭД тавина — харанхуй өрөөнд зураг
          // өөрөө гэрэлтэж болохгүй.
          ..colorFilter = ColorFilter.mode(
            Color.from(alpha: 1.0, red: lit, green: lit, blue: lit),
            BlendMode.modulate,
          ),
      );
    } else {
      canvas.drawRect(dst, Paint()..color = kSurfaceRaised);
    }

    // ИРМЭГИЙГ ЗӨӨЛРҮҮЛЭХ МАСК — РАДИАЛ.
    //
    // ЯАГААД РАДИАЛ: AI-аар үүсгэсэн хөрөг нь ЦАЙВАР СААРАЛ дэвсгэртэй
    // ирдэг. Шугаман маск нь дээд, доод талыг л уусгадаг тул хажуугийн
    // саарал үлдэж, харанхуй өрөөнд МАНАН мэт тархаж байв — 12 дүр зэрэг
    // зурагдахад дэлгэц бүхэлдээ саарал болов.
    //
    // Радиал маск нь нүүрний эргэн тойрноос ГАДНАХ бүхнийг арилгана.
    // Төв нь нүүр дээр (дээд гуравны нэгд), тиймээс мөр, цээж үлдэж,
    // дэвсгэр бүрэн уусна.
    final Offset focus = Offset(dst.center.dx, dst.top + dst.height * 0.34);
    canvas.drawRect(
      dst,
      Paint()
        ..blendMode = BlendMode.dstIn
        ..shader = ui.Gradient.radial(
          focus,
          dst.height * 0.52,
          <Color>[
            const Color(0xFF000000),
            const Color(0xFF000000),
            const Color(0x00000000),
          ],
          <double>[0.0, 0.58, 1.0],
        ),
    );
    // Доод талыг нэмж уусгана — дүр ширээний харанхуйгаас УРГАЖ гарна.
    canvas.drawRect(
      dst,
      Paint()
        ..blendMode = BlendMode.dstIn
        ..shader = ui.Gradient.linear(
          dst.topCenter,
          dst.bottomCenter,
          <Color>[
            const Color(0xFF000000),
            const Color(0xFF000000),
            const Color(0x00000000),
          ],
          <double>[0.0, 0.62, 1.0],
        ),
    );
    canvas.restore();
  }

  /// Нэрийн хуудас — ЭЗНИЙХЭЭ ӨМНӨ, ширээн дээр.
  ///
  /// Өмнө нь билбордын доод ирмэгт зурагдаж байсан тул ширээний голд
  /// цуглаж, хэн хэнийх нь болох нь ойлгомжгүй байв. Одоо суудал тутмын
  /// ширээн дээрх цэгт (`spotOf`) буух тул нэр бүр эзнийхээ өмнө байна.
  void _paintPlates(Canvas canvas, Size size) {
    for (final SeatOccupant o in occupants) {
      if (o.seat == viewerSeat) continue;
      final Vec3 spot = layout.spotOf(o.seat, viewerSeat);
      if (!_inView(cam, spot)) continue;
      final Projected p = cam.project(spot, size.width, size.height);
      if (!p.visible) continue;
      final double lit = math.min(1.0, lampFalloff(spot) * lamp * 2.1);
      _plateAt(canvas, o, Offset(p.x, p.y), lit, p.depth);
    }
  }

  void _plateAt(
    Canvas canvas,
    SeatOccupant o,
    Offset at,
    double lit,
    double depth,
  ) {
    final double scale = (2.6 / depth).clamp(0.55, 1.35);
    final double y = at.dy;
    final Color ink = o.alive
        ? kBone.withValues(alpha: 0.25 + 0.55 * lit)
        : kTextMuted.withValues(alpha: 0.35);

    final TextPainter tp = TextPainter(
      text: TextSpan(
        text: o.name == null ? '№${o.seat}' : '${o.seat} · ${o.name}',
        style: TextStyle(
          fontFamily: kDisplayFont,
          fontSize: 15 * scale,
          letterSpacing: 1.2,
          fontWeight: FontWeight.w500,
          color: ink,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 200);
    tp.paint(canvas, Offset(at.dx - tp.width / 2, y - tp.height / 2));

    if (o.highlighted) {
      canvas.drawRect(
        Rect.fromLTWH(
          at.dx - tp.width / 2 - 6,
          y - tp.height / 2 - 4,
          tp.width + 12,
          tp.height + 8,
        ),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = kRust,
      );
    }
    if (!o.alive) {
      canvas.drawLine(
        Offset(at.dx - tp.width / 2, y),
        Offset(at.dx + tp.width / 2, y),
        Paint()
          ..strokeWidth = 1.4
          ..color = kDanger,
      );
    }
  }

  // --- Чийдэн -------------------------------------------------------------

  /// Чийдэн — ДЭЛХИЙН орон зайд бэхлэгдсэн.
  ///
  /// АЛДАА БАЙСАН: чийдэнг дэлгэцийн голд (`size.width / 2`) зурж байв.
  /// Тиймээс толгойгоо эргүүлэхэд ширээ, хүмүүс хөдлөх атлаа чийдэн
  /// дэлгэцэнд наалдсан хэвээр үлдэж, орон зайн мэдрэмж эвдэрч байв.
  ///
  /// Одоо чийдэнгийн БОДИТ байрлалыг (ширээний голоос дээш) буулгана —
  /// эргэхэд хамт хөдөлнө, ширээнээс хол харвал дэлгэцээс гарна.
  void _paintLampGlow(Canvas canvas, Size size) {
    final Projected p = cam.project(
      const Vec3(0, kLampHeight, 0),
      size.width,
      size.height,
    );
    if (!p.visible) return;
    final double cx = p.x;
    final double cy = p.y;
    // Хэмжээ нь гүнээс хамаарна — хол байвал жижиг.
    final double k = (3.2 / p.depth).clamp(0.5, 1.8);
    final double shadeW = size.width * 0.16 * k;

    // Гэрлийн конус — чийдэнгээс ширээ рүү.
    final Projected floor = cam.project(
      const Vec3(0, 0, 0),
      size.width,
      size.height,
    );
    if (floor.visible) {
      canvas.drawPath(
        Path()
          ..moveTo(cx - shadeW * 0.35, cy)
          ..lineTo(cx + shadeW * 0.35, cy)
          ..lineTo(floor.x + size.width * 0.80, floor.y)
          ..lineTo(floor.x - size.width * 0.80, floor.y)
          ..close(),
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(cx, cy),
            Offset(floor.x, floor.y),
            <Color>[
              kRust.withValues(alpha: 0.055 * lamp),
              kRust.withValues(alpha: 0.018 * lamp),
              Colors.transparent,
            ],
            <double>[0.0, 0.30, 1.0],
          ),
      );
    }

    // Чийдэнгийн хүрээ.
    canvas.drawPath(
      Path()
        ..moveTo(cx - shadeW, cy + 8 * k)
        ..lineTo(cx + shadeW, cy + 8 * k)
        ..lineTo(cx + shadeW * 0.30, cy - 14 * k)
        ..lineTo(cx - shadeW * 0.30, cy - 14 * k)
        ..close(),
      Paint()..color = const Color(0xFF0E0F11),
    );
    // Гэрэл.
    canvas.drawCircle(
      Offset(cx, cy + 8 * k),
      size.width * 0.20 * k,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(cx, cy + 8 * k),
          size.width * 0.20 * k,
          <Color>[
            const Color(0xFFFFE6C4).withValues(alpha: 0.55 * lamp),
            kRust.withValues(alpha: 0.18 * lamp),
            Colors.transparent,
          ],
          <double>[0.0, 0.35, 1.0],
        ),
    );
  }

  /// Тогтмол хуурмаг санамсаргүй — 0..1.
  static double _hash(int i) {
    final double x = math.sin(i * 12.9898) * 43758.5453;
    return x - x.floor();
  }

  @override
  bool shouldRepaint(_ScenePainter old) =>
      old.occupants != occupants ||
      old.viewerSeat != viewerSeat ||
      old.lamp != lamp;
}

// ---------------------------------------------------------------------------
// Толгой эргүүлэх бүрхүүл
// ---------------------------------------------------------------------------

/// Ширээг харах бүтэн виджет — хөндлөн чирэхэд ТОЛГОЙ ЭРГЭНЭ.
///
/// ЯАГААД ХЭРЭГТЭЙ: камер жинхэнэ суугаагийн нүдэнд байгаа тул 12 суудлын
/// 7 нь л зэрэг харагдана. Ширээнд сууж байгаа хүн хажуудахаа харахын тулд
/// толгойгоо эргүүлдэг — энэ виджет яг түүнийг хийнэ.
///
/// ТООЛУУР БИШ, ШУУД ХЯНАЛТ: хуруу хөдөлсөн зайд шууд пропорциональ эргэнэ.
/// Инерц, хойшлолт байхгүй — хүн хаана хартлаа тэндээ шууд хүрнэ.
class TableView extends StatefulWidget {
  const TableView({
    super.key,
    required this.occupants,
    required this.viewerSeat,
    this.seatCount,
    this.lamp = 1.0,
    this.onTapSeat,
    this.focusSeat,
  });

  final List<SeatOccupant> occupants;
  final int viewerSeat;
  final int? seatCount;
  final double lamp;
  final void Function(int seat)? onTapSeat;

  /// Энэ суудал руу ӨӨРӨӨ эргэнэ — «үг хэлэгч рүү хар» гэх мэт.
  final int? focusSeat;

  @override
  State<TableView> createState() => _TableViewState();
}

class _TableViewState extends State<TableView> {
  double _yaw = 0;

  @override
  void didUpdateWidget(TableView old) {
    super.didUpdateWidget(old);
    if (widget.focusSeat != null && widget.focusSeat != old.focusSeat) {
      _turnTo(widget.focusSeat!);
    }
  }

  /// Тухайн суудлыг дэлгэцийн голд авчрах өнцөг.
  void _turnTo(int seat) {
    final int n = widget.seatCount ?? widget.occupants.length;
    if (n < 2) return;
    final TableLayout layout = TableLayout(seatCount: n);
    // Суудлын өнцгийг камерын «урагшаа» (π) чиглэлээс хэмжинэ.
    final double rel = layout.angleOf(seat, widget.viewerSeat) - math.pi;
    // −π..π болгож хураана — богино талаараа эргэнэ.
    double d = (rel + math.pi) % (2 * math.pi) - math.pi;
    if (d < -math.pi) d += 2 * math.pi;
    setState(() => _yaw = d.clamp(-TableLayout.maxYaw, TableLayout.maxYaw));
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragUpdate: (DragUpdateDetails d) {
        // Дэлгэцийн бүтэн өргөн ≈ 1.2 радиан эргэлт. Хэмжсэн: үүнээс их
        // бол хүн «гулсаж» байгаа мэт, бага бол «хүнд» санагдана.
        final double perPx = 1.2 / MediaQuery.sizeOf(context).width;
        setState(() {
          _yaw = (_yaw - d.delta.dx * perPx).clamp(
            -TableLayout.maxYaw,
            TableLayout.maxYaw,
          );
        });
      },
      child: TableScene(
        occupants: widget.occupants,
        viewerSeat: widget.viewerSeat,
        seatCount: widget.seatCount,
        lamp: widget.lamp,
        yaw: _yaw,
        onTapSeat: widget.onTapSeat,
      ),
    );
  }
}
