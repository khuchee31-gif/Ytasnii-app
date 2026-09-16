// 3D тайзны математикийн тест. Flutter хэрэггүй — цэвэр Dart, хурдан.
//
// Энэ математик буруу бол дүрүүд буруу газар, буруу хэмжээтэй гарна. Нүдээр
// «болж байна» гэж шалгах боломжгүй тул ЧАНАРЫГ ЭНД БЭХЛЭНЭ.

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:hotuntlaa/ui/scene3d.dart';

void main() {
  group('Vec3', () {
    test('тэг векторыг нормчлоход 0-д хуваахгүй', () {
      expect(Vec3.zero.normalized.length, 0);
    });

    test('хөндлөн үржвэр зөв гарын дүрмийг баримтална', () {
      const Vec3 x = Vec3(1, 0, 0);
      const Vec3 y = Vec3(0, 1, 0);
      final Vec3 z = x.cross(y);
      expect(z.x, closeTo(0, 1e-9));
      expect(z.y, closeTo(0, 1e-9));
      expect(z.z, closeTo(1, 1e-9));
    });
  });

  group('Camera3D', () {
    test('харж буй цэг яг дэлгэцийн голд буна', () {
      final Camera3D c = Camera3D(eye: const Vec3(0, 1, 5), target: Vec3.zero);
      final Projected p = c.project(Vec3.zero, 360, 800);
      expect(p.visible, isTrue);
      expect(p.x, closeTo(180, 0.001));
      expect(p.y, closeTo(400, 0.001));
    });

    test('камерын АРД байгаа цэг харагдахгүй гэж тэмдэглэгдэнэ', () {
      final Camera3D c = Camera3D(eye: const Vec3(0, 0, 5), target: Vec3.zero);
      // Камер −Z рүү харж байна. z = 9 нь түүний ард.
      final Projected p = c.project(const Vec3(0, 0, 9), 360, 800);
      expect(
        p.visible,
        isFalse,
        reason: 'ард унасан цэгийг зурвал дэлгэцийн буруу талд эргэж гарна',
      );
    });

    test('хол цэгийн гүн их, ойрынх бага', () {
      final Camera3D c = Camera3D(eye: const Vec3(0, 0, 5), target: Vec3.zero);
      final Projected near = c.project(const Vec3(0, 0, 1), 360, 800);
      final Projected far = c.project(const Vec3(0, 0, -3), 360, 800);
      expect(near.depth, lessThan(far.depth));
    });

    test('ижил биет хол байх тусам ЖИЖИГ харагдана (перспектив)', () {
      final Camera3D c = Camera3D(eye: const Vec3(0, 0, 5), target: Vec3.zero);
      // Нэг метр өргөн биетийн ирмэгүүд, хоёр өөр зайд.
      double widthAt(double z) {
        final Projected l = c.project(Vec3(-0.5, 0, z), 360, 800);
        final Projected r = c.project(Vec3(0.5, 0, z), 360, 800);
        return (r.x - l.x).abs();
      }

      expect(
        widthAt(0),
        greaterThan(widthAt(-4)),
        reason: 'хол биет жижиг харагдах ёстой',
      );
    });

    test('баруун ба дээш вектор нь харах чиглэлд перпендикуляр', () {
      final Camera3D c = Camera3D(
        eye: const Vec3(2, 1.4, 2),
        target: const Vec3(0, 0.2, 0),
      );
      expect(c.right.dot(c.upVector), closeTo(0, 1e-9));
      expect(c.right.length, closeTo(1, 1e-9));
      expect(c.upVector.length, closeTo(1, 1e-9));
    });
  });

  group('TableLayout', () {
    test('харж буй суудал камерын дэргэд, эсрэг тал нь хамгийн хол', () {
      const TableLayout t = TableLayout(seatCount: 12);
      final Camera3D c = t.cameraFor(1);

      final double dViewer = (t.headOf(1, 1) - c.eye).length;
      final double dOpposite = (t.headOf(7, 1) - c.eye).length;

      expect(
        dViewer,
        lessThan(dOpposite),
        reason: 'өөрийн суудал хамгийн ойр байх ёстой',
      );
      // 12 суудлын эсрэг тал нь №7.
      for (int s = 2; s <= 12; s++) {
        expect(
          (t.headOf(s, 1) - c.eye).length,
          lessThanOrEqualTo(dOpposite + 1e-9),
          reason: '№7 хамгийн хол байх ёстой, №$s түүнээс хол байна',
        );
      }
    });

    test('аль ч суудлаас харахад зураглал ИЖИЛ мэдрэгдэнэ', () {
      const TableLayout t = TableLayout(seatCount: 8);
      // №3-аас харахад №3 нь камерын дэргэд, яг л №1-ээс харахад №1 шиг.
      final double a1 = t.angleOf(1, 1);
      final double a3 = t.angleOf(3, 3);
      expect(a1, closeTo(a3, 1e-9));
      // Дараагийн суудал хоёр тохиолдолд ижил өнцгөөр зөрнө.
      expect(t.angleOf(2, 1) - a1, closeTo(t.angleOf(4, 3) - a3, 1e-9));
    });

    test('бүх суудал тойргийн радиус дээр байна', () {
      const TableLayout t = TableLayout(seatCount: 10, radius: 2.0);
      for (int s = 1; s <= 10; s++) {
        final Vec3 h = t.headOf(s, 1);
        final double r = math.sqrt(h.x * h.x + h.z * h.z);
        expect(r, closeTo(2.0, 1e-9));
        expect(h.y, closeTo(t.headHeight, 1e-9));
      }
    });

    test('толгой эргүүлэхэд суудал БҮР хэзээ нэгэн цагт харагдана', () {
      // Камер одоо ЖИНХЭНЭ суугаагийн нүдэнд байгаа тул бүх суудал зэрэг
      // харагдахгүй — хажуу, ард байгаа хүмүүс дэлгэцээс гарна. Энэ нь
      // алдаа БИШ, ширээнд сууж байгаа хүний бодит хараа.
      //
      // ХАРИН шаардлага нь: толгойгоо эргүүлэхэд хүн бүр олдох ёстой.
      // Эс бөгөөс тоглогч зарим хүнийг ХЭЗЭЭ Ч харахгүй болно.
      for (final int n in <int>[6, 8, 10, 12]) {
        final TableLayout t = TableLayout(seatCount: n);
        final Set<int> everSeen = <int>{};
        for (
          double yaw = -TableLayout.maxYaw;
          yaw <= TableLayout.maxYaw;
          yaw += 0.1
        ) {
          final Camera3D c = t.cameraFor(1, yaw: yaw);
          for (int s = 2; s <= n; s++) {
            final Projected p = c.project(t.headOf(s, 1), 360, 800);
            if (p.visible && p.x > 10 && p.x < 350 && p.y > 0 && p.y < 800) {
              everSeen.add(s);
            }
          }
        }
        expect(
          everSeen.length,
          n - 1,
          reason:
              'n=$n үед ${everSeen.length} суудал л олдлоо, '
              '${n - 1} байх ёстой (өөрийнхөө суудлыг хасаад)',
        );
      }
    });

    test('yaw = 0 үед эсрэг талын суудал дэлгэцийн голд ойр', () {
      // Толгойгоо эргүүлээгүй үед хүн ширээний ЭСРЭГ талыг харна.
      const TableLayout t = TableLayout(seatCount: 12);
      final Camera3D c = t.cameraFor(1);
      final Projected opp = c.project(t.headOf(7, 1), 360, 800);
      expect(opp.visible, isTrue);
      expect(opp.x, closeTo(180, 30), reason: 'эсрэг тал голдоо байх ёстой');
    });

    test('6-аас 12 суудлын аль ч тоонд эвдрэхгүй', () {
      for (int n = 6; n <= 12; n++) {
        final TableLayout t = TableLayout(seatCount: n);
        final Camera3D c = t.cameraFor(1);
        for (int s = 1; s <= n; s++) {
          final Projected p = c.project(t.headOf(s, 1), 360, 800);
          expect(p.x.isFinite, isTrue, reason: 'n=$n, суудал=$s');
          expect(p.y.isFinite, isTrue, reason: 'n=$n, суудал=$s');
        }
      }
    });
  });

  group('lampFalloff', () {
    test('ширээний төв хамгийн гэрэлтэй', () {
      final double centre = lampFalloff(Vec3.zero);
      final double edge = lampFalloff(const Vec3(2.4, 0, 0));
      expect(centre, greaterThan(edge));
      expect(centre, lessThanOrEqualTo(1.0));
      expect(edge, greaterThanOrEqualTo(0.0));
    });

    test('чийдэнгийн хүрээнээс гадуур бүрэн харанхуй', () {
      expect(lampFalloff(const Vec3(50, 0, 0)), 0.0);
    });
  });
}
