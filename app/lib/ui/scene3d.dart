// Гурван хэмжээст тайзны МАТЕМАТИК — Flutter-ээс хамааралгүй, цэвэр Dart.
//
// ЯАГААД ӨӨРСДӨӨ БИЧИВ: Flutter-т 3D хөдөлгүүрийн сан суулгах шаардлагагүй.
// `dart:ui`-ийн `drawVertices` нь текстуртэй гурвалжинг GPU дээр зурдаг —
// бидэнд хэрэгтэй нь түүнд дамжуулах ОРОЙН БАЙРЛАЛ. Тэрийг энд бодно.
// Сорил (`test/capability_probe_test.dart`) үүнийг ажиллахыг баталсан.
//
// ЭНЭ ФАЙЛ FLUTTER ИМПОРТ ХИЙХГҮЙ. Ингэснээр математикийг виджет барихгүйгээр
// шууд тестлэнэ — хөдөлгүүрийн багцтай ижил зарчим.

import 'dart:math' as math;

/// Гурван тооны вектор. Энгийн, хувиршгүй.
class Vec3 {
  const Vec3(this.x, this.y, this.z);

  final double x;
  final double y;
  final double z;

  static const Vec3 zero = Vec3(0, 0, 0);
  static const Vec3 up = Vec3(0, 1, 0);

  Vec3 operator +(Vec3 o) => Vec3(x + o.x, y + o.y, z + o.z);
  Vec3 operator -(Vec3 o) => Vec3(x - o.x, y - o.y, z - o.z);
  Vec3 operator *(double s) => Vec3(x * s, y * s, z * s);

  double dot(Vec3 o) => x * o.x + y * o.y + z * o.z;

  Vec3 cross(Vec3 o) =>
      Vec3(y * o.z - z * o.y, z * o.x - x * o.z, x * o.y - y * o.x);

  double get length => math.sqrt(x * x + y * y + z * z);

  /// Урт нь тэг бол тэг векторыг буцаана — 0-д хуваахаас сэргийлнэ.
  Vec3 get normalized {
    final double l = length;
    if (l < 1e-9) return Vec3.zero;
    return Vec3(x / l, y / l, z / l);
  }

  @override
  String toString() =>
      'Vec3(${x.toStringAsFixed(3)}, '
      '${y.toStringAsFixed(3)}, ${z.toStringAsFixed(3)})';
}

/// Дэлгэц дээр буусан цэг ба гүн.
class Projected {
  const Projected(this.x, this.y, this.depth, this.visible);

  final double x;
  final double y;

  /// Камераас хүртэлх зай. Их бол хол. Эрэмбэлэхэд хэрэглэнэ.
  final double depth;

  /// Камерын АРД унасан цэгийг зурж болохгүй — перспектив хуваалт
  /// тэрийг дэлгэцийн буруу тал руу «эргүүлж» хаядаг.
  final bool visible;
}

/// Камер. `eye` цэгээс `target` руу харна.
///
/// Тэнхлэгийн гэрээ: камер өөрийн орон зайд −Z рүү харна (OpenGL-ийн уламжлал).
/// Тиймээс урд талын цэгүүдийн `viewZ` СӨРӨГ, гүн нь `-viewZ`.
class Camera3D {
  Camera3D({
    required this.eye,
    required this.target,
    this.fovX = 1.75,
    Vec3 upHint = Vec3.up,
  }) {
    // lookAt-ын суурь. Зөв гарын дүрэм.
    final Vec3 f = (eye - target).normalized; // камерын ард чиглэсэн тэнхлэг
    Vec3 r = upHint.cross(f).normalized;
    if (r.length < 1e-9) {
      // Камер яг дээрээс доош харж байна — өөр түшиг вектор авна.
      r = const Vec3(1, 0, 0).cross(f).normalized;
    }
    _right = r;
    _up = f.cross(r).normalized;
    _back = f;
  }

  final Vec3 eye;
  final Vec3 target;

  /// ХЭВТЭЭ харах өнцөг, радиан.
  ///
  /// ЯАГААД ХЭВТЭЭ: утас БОСОО байрлалтай (360 × 800). Хэрэв өнцгийг
  /// босоогоор нь тодорхойлбол хэвтээ хараа нь `w/h = 0.45` дахин нарийсч,
  /// ширээний хоёр тал дэлгэцээс гарч унана. Хэмжилтээр 12 суудлаас 3 нь л
  /// багтаж байсан. Ширээг харуулах нь энэ тайзны бүх утга учир өнцгийг
  /// ХЭВТЭЭГЭЭР нь барина.
  final double fovX;

  late final Vec3 _right;
  late final Vec3 _up;
  late final Vec3 _back;

  /// Камерын баруун тийш чиглэсэн вектор — самбар дүрс (billboard) эргүүлэхэд.
  Vec3 get right => _right;

  /// Камерын дээш чиглэсэн вектор.
  Vec3 get upVector => _up;

  /// Дэлхийн цэгийг камерын орон зай руу буулгана.
  ///
  /// `_back` нь камерын АРД чиглэнэ. Тиймээс УРД талын цэгийн `z` нь СӨРӨГ
  /// гарна — OpenGL-ийн уламжлал. Энд нэмэлт сөрөг тэмдэг тавьж болохгүй:
  /// тэр алдаа гүнийг урвуу болгож, бүх цэгийг «камерын ард» болгож байв.
  Vec3 toView(Vec3 p) {
    final Vec3 d = p - eye;
    return Vec3(d.dot(_right), d.dot(_up), d.dot(_back));
  }

  /// Дэлхийн цэгийг дэлгэц дээр буулгана.
  ///
  /// [w], [h] нь дэлгэцийн логик хэмжээ. Гаралтын эх нь зүүн дээд булан.
  Projected project(Vec3 p, double w, double h) {
    final Vec3 v = toView(p);
    final double depth = -v.z; // урд талд эерэг
    // Камерын хавтгайд ойрхон, эсвэл ард унасан цэгийг зурахгүй.
    if (depth <= 0.05) {
      return Projected(w / 2, h / 2, depth, false);
    }
    final double f = 1.0 / math.tan(fovX / 2);
    // ХОЁР тэнхлэгийг ИЖИЛ масштабаар (w / 2) буулгана. Ингэснээр пиксел
    // дөрвөлжин үлдэж (дүр сунахгүй), хэвтээ өнцөг нь `fovX` яг болно.
    final double sx = (v.x * f) / depth * (w / 2) + w / 2;
    final double sy = -(v.y * f) / depth * (w / 2) + h / 2;
    return Projected(sx, sy, depth, true);
  }
}

/// Ширээний эргэн тойрны суудлын байрлал.
///
/// Суудлууд XZ хавтгайд, тойргоор. `y = 0` нь ширээний гадаргуу.
/// Суудал №1 нь тойргийн ХАМГИЙН ОЙР талд (камер тэндээс харна).
class TableLayout {
  const TableLayout({
    required this.seatCount,
    this.radius = 2.35,
    this.headHeight = 0.62,
  });

  final int seatCount;

  /// Ширээний голоос суудал хүртэлх зай.
  final double radius;

  /// Ширээний гадаргуугаас толгойн төв хүртэлх өндөр.
  final double headHeight;

  /// [seat] нь 1-ээс эхэлнэ.
  ///
  /// [viewerSeat] нь ХАРЖ БУЙ суудал — тэрийг тойргийн хамгийн ойр цэгт
  /// (камерын дэргэд) байрлуулж, бусдыг түүнээс тоолно. Ингэснээр аль ч
  /// суудлаас харахад зураглал ижил мэдрэгдэнэ.
  double angleOf(int seat, int viewerSeat) {
    final int rel = (seat - viewerSeat) % seatCount;
    final int k = rel < 0 ? rel + seatCount : rel;
    // rel = 0 → камерын байрлал (π). Бусад нь эсрэг тал руу тархана.
    return math.pi + k * 2 * math.pi / seatCount;
  }

  /// Суудлын толгойн байрлал.
  Vec3 headOf(int seat, int viewerSeat) {
    final double a = angleOf(seat, viewerSeat);
    return Vec3(math.sin(a) * radius, headHeight, math.cos(a) * radius);
  }

  /// Суудлын ширээн дээрх цэг — хөзөр, тэмдэг тавихад.
  Vec3 spotOf(int seat, int viewerSeat) {
    final double a = angleOf(seat, viewerSeat);
    final double r = radius * 0.62;
    return Vec3(math.sin(a) * r, 0, math.cos(a) * r);
  }

  /// Харж буй суудлын камер — тухайн суудлын НҮДНЭЭС ширээ рүү.
  ///
  /// ТООНУУД ТААМАГЛААГҮЙ, ГУРВАН УДАА ХЭМЖСЭН:
  ///   1. Камер суудлын дээр байхад 12 суудлаас ердөө 3 нь багтав.
  ///   2. Ард нь татахад бүгд багтсан ч ХЭМЖЭЭ эвдэрсэн — ойр, хол
  ///      суудлын гүн 7.7 дахин зөрч байв.
  ///   3. Хол татаад өндөрт өргөхөд хэмжээ тэгширсэн ч ШИРЭЭ алга болов:
  ///      дээрээс харахад ширээ нимгэн зураас болж хавчуулагдана.
  ///
  /// Эцсийн шийдэл: камерыг ЖИНХЭНЭ СУУГААГИЙН НҮДЭНД тавина —
  /// ширээний ирмэг дээр (0.95 × радиус), ширээнээс 0.75 дээш, бага зэрэг
  /// доош харна. Хэмжсэн үр дүн: ширээний ойр ирмэг y ≈ 622, хол ирмэг
  /// y ≈ 374 (доод хагасыг эзэлнэ), эсрэг талын дүр 246 px өндөр.
  ///
  /// Дөрөв дэх хэмжилт: ширээ хүмүүсээс ХОЛ байж, хооронд нь хоосон шал
  /// үлдэж байв. Бодит амьдрал дээр хүн ширээний ИРМЭГ дээр сууна. Ширээг
  /// суудлын радиусын 0.88 болгож, камерыг 0.75 → 0.45 доошлуулахад
  /// ширээний ойр ирмэг дэлгэцээс давж (y ≈ 827), доод хэсэг дүүрэв.
  ///
  /// Ийм өнцгөөс 12 суудлын 7 нь харагдана — үлдсэн нь хажууд, ард байна.
  /// Тэр бол АЛДАА БИШ: ширээнд сууж байхад хажуудахаа харахын тулд хүн
  /// толгойгоо эргүүлдэг. [yaw] түүнийг хийнэ.
  static const double _backK = 0.95;
  static const double _eyeLift = 0.45;
  static const double _fovX = 1.35;
  static const double _lookY = 0.30;

  /// [yaw] — толгой эргүүлэх өнцөг, радиан. 0 бол ширээний гол руу.
  Camera3D cameraFor(int viewerSeat, {double yaw = 0}) {
    final double a = angleOf(viewerSeat, viewerSeat); // = π
    final Vec3 eye = Vec3(
      math.sin(a) * (radius * _backK),
      headHeight + _eyeLift,
      math.cos(a) * (radius * _backK),
    );
    // Ширээний гол руу харах чиглэл.
    final Vec3 f = (Vec3(0, _lookY, 0) - eye).normalized;
    // Y тэнхлэгээр эргүүлнэ — толгой эргүүлэх нь зөвхөн хэвтээ.
    final double cs = math.cos(yaw);
    final double sn = math.sin(yaw);
    final Vec3 turned = Vec3(f.x * cs + f.z * sn, f.y, -f.x * sn + f.z * cs);
    return Camera3D(eye: eye, target: eye + turned * 3.0, fovX: _fovX);
  }

  /// [yaw]-ийн хязгаар. Хүн хүзүүгээ 360° эргүүлэхгүй — 100° хүртэл.
  static const double maxYaw = 1.75;
}

/// Дээрх чийдэнгийн гэрэлтүүлэг.
///
/// Бодит гэрлийн загвар биш — ХЯМД дөхөлт. Чийдэн ширээний яг дээр өлгөөтэй
/// тул голд ойр байх тусам гэрэлтэй. Гар утасны GPU-д пиксел тутмын
/// гэрэлтүүлэг хэрэггүй: орой тутамд нэг тоо хангалттай.
/// Чийдэн ширээнээс хэр өндөрт өлгөөтэй вэ.
///
/// НЭГ утга: гэрэлтүүлгийн тооцоо ба чийдэнгийн ЗУРАГ хоёул үүнийг уншина.
/// Хоёр газар тус тусад нь бичвэл нэгийг нь өөрчлөхөд гэрэл нь чийдэнгээсээ
/// салж хөвнө.
const double kLampHeight = 1.9;

double lampFalloff(
  Vec3 p, {
  double lampHeight = kLampHeight,
  double reach = 3.1,
}) {
  final double dx = p.x;
  final double dz = p.z;
  final double dy = lampHeight - p.y;
  final double d = math.sqrt(dx * dx + dy * dy + dz * dz);
  final double t = (1.0 - (d / reach)).clamp(0.0, 1.0);
  // Квадрат бууралт — ирмэг рүү хурдан харанхуйлна, төв нь тод.
  return t * t;
}
