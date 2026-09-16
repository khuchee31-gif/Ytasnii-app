// Шөнийн дэлгэцүүдийн (S08–S12) хуваалцсан тулгуур.
//
// ЗӨВХӨН ТЕСТЭД. Апп дүрийн бүтэн жагсаалт хэзээ ч гаргахгүй (GDD-10 §4);
// энд `roleOf` дуудагдах нь зөвшөөрөгдөнө, учир нь `rg 'roleOf\(' lib/ui/`
// гэсэн CI шалгуур `lib/`-ийг л хардаг.

import 'package:engine/engine.dart';
import 'package:flutter/material.dart' hide Intent;
import 'package:flutter_test/flutter_test.dart';
import 'package:hotuntlaa/game/game_controller.dart';

import 'deal_test_support.dart';

/// Шөнө 1 эхэлсэн, эргэлт нь эхний суудал дээр зогссон хянагч.
GameController nightController({int seats = 12}) {
  final GameController c = dealtController(seats: seats);
  c.beginNight();
  return c;
}

/// Тухайн чадвартай ЭХНИЙ суудал.
Seat seatWithAbility(GameController c, Ability a) {
  for (int s = 1; s <= c.seatCount; s++) {
    final Role? r = c.roleOf(s);
    if (r != null && abilityOf(r) == a) return s;
  }
  throw StateError('$a чадвартай суудал олдсонгүй');
}

/// Тухайн чадвартай БҮХ суудал.
List<Seat> seatsWithAbility(GameController c, Ability a) => <Seat>[
      for (int s = 1; s <= c.seatCount; s++)
        if (c.roleOf(s) != null && abilityOf(c.roleOf(s)!) == a) s,
    ];

/// Эргэлтийг бүтнээр нь гүйцээж, шөнийг шийдвэрлэнэ.
///
/// `target` нь `null` буцаавал (эсвэл хууль бус бай өгвөл) тэр суудал
/// `noAction` бүртгэнэ — яг цонх дуусахтай ижил. Инвариант N22 (амьд суудал
/// бүр ЯГ НЭГ санаа) энд хамгаалагдана.
void resolveWholeNight(
  GameController c, {
  Seat? Function(Seat seat, Ability ability)? target,
}) {
  while (!c.circuitDone) {
    final Seat s = c.currentSeat!;
    if (!c.alive.contains(s)) {
      c.submitIntent(s, Ability.noAction, null);
      continue;
    }
    final Ability a = abilityOf(c.roleOf(s)!);
    final Seat? t = target?.call(s, a);
    if (t == null || c.checkTarget(s, a, t) != null) {
      c.submitIntent(s, Ability.noAction, null);
    } else {
      c.submitIntent(s, a, t);
    }
  }
  c.resolveNightNow();
}

/// Батлах зурвасыг **дарж-дүүргэнэ**. Товшилт хангалтгүй — 600 мс хэрэгтэй.
Future<void> holdConfirm(
  WidgetTester tester, {
  Duration hold = const Duration(milliseconds: 650),
}) async {
  final Finder strip = find.byKey(const ValueKey<String>('nightConfirm'));
  final TestGesture g = await tester.startGesture(tester.getCenter(strip));
  await tester.pump(hold);
  await g.up();
  await tester.pump();
}

/// Дамжуулах хаалтыг нээж, суудлын цонх руу орно.
///
/// 1300 мс нь хоёр тохиолдлыг зэрэг хамарна: хэвийн хаалт (600 мс) ба
/// хасагдсан суудал алгасагдсан хаалт (600 + 600 мс).
Future<void> liftPhone(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 1300));
  await tester.tapAt(const Offset(180, 400));
  await tester.pump();
}
