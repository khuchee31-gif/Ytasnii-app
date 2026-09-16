// ШӨНӨӨС ШӨНӨД ДАМЖИХ ТӨЛӨВ.
//
// Хөдөлгүүр нь эмчийн хоёр дүрмийг («хоёр шөнө дараалж нэг хүнийг
// эмчлэхгүй», «өөрийгөө нэг л удаа») зөвхөн `NightState.lastHealTarget`
// ба `selfHealUsed` дээр тулгуурлан хэрэгжүүлдэг. Хэрэв сервер тэднийг
// дамжуулахгүй бол хоёр дүрэм НЭГ Ч УДАА хэрэгжихгүй — тест нь
// хөдөлгүүр дээр ногоон хэвээр байх боловч жинхэнэ тоглолтод эмч шөнө
// бүр өөрийгөө эмчилж чадна.
//
// Мөн `orderPerm`: тараалтын үрээс гарсан эрэмбийг сервер хаяж, `[1..n]`
// гэж зохиодог байв. Тэр нь тэнцлийг ҮРГЭЛЖ 1-р суудлын талд тайлна.

import 'dart:typed_data';

import 'package:engine/engine.dart' as eng;
import 'package:protocol/protocol.dart';
import 'package:server/server.dart';
import 'package:test/test.dart';

Uint8List _seed(int n) =>
    Uint8List.fromList(List<int>.generate(32, (int i) => (i * 53 + n) & 0xFF));

/// Найман ХҮНТЭЙ өрөө (ботгүй — үе шат бүтэн урттай, хяналт бидэнд).
GameRoom _table(String code, {int seed = 1}) {
  final GameRoom r = GameRoom(code: code, hostId: 'p1', seed: _seed(seed));
  for (int i = 1; i <= 8; i++) {
    r.join('p$i', 'Хүн$i', 'punk_01');
  }
  return r;
}

/// Хүссэн үе шат хүртэл явуулж, тэр агшны цагийг буцаана.
int _runTo(GameRoom r, NetPhase want, int from, {int limitMs = 900000}) {
  for (int t = from + 250; t <= limitMs; t += 250) {
    r.tick(t);
    if (r.phase == want) return t;
  }
  fail('$want ирсэнгүй (одоо ${r.phase})');
}

PlayerId _who(GameRoom r, eng.Role role) => r.players
    .map((PublicPlayer p) => p.id)
    .firstWhere((PlayerId id) => r.debugRoleOf(id) == role);

void main() {
  group('Тэнцэл тайлах эрэмбэ', () {
    test('тараалтаас гарсан эрэмбийг ХЭРЭГЛЭНЭ', () {
      final GameRoom r = _table('ORDR');
      r.start('p1', 0);
      final List<int> perm = r.debugOrderPerm;
      expect(perm.length, 8);
      expect(perm.toSet(), <int>{1, 2, 3, 4, 5, 6, 7, 8},
          reason: 'эрэмбэ нь суудлуудын сэлгэмэл байх ёстой');
    });

    test('эрэмбэ нь ҮРЭЭС хамаарна — үргэлж [1..n] БИШ', () {
      // Хэрэв сервер эрэмбийг зохиовол бүх өрөөнд ижил гарна. Тэр үед
      // `pickVictim` тэнцлийг ҮРГЭЛЖ хамгийн бага суудлын талд тайлж,
      // 1-р суудал системтэйгээр илүү олон удаа үхнэ.
      final Set<String> seen = <String>{};
      for (int s = 0; s < 12; s++) {
        final GameRoom r = _table('OR$s', seed: s);
        r.start('p1', 0);
        seen.add(r.debugOrderPerm.join(','));
      }
      expect(seen.length, greaterThan(1),
          reason: 'бүх өрөөнд ижил эрэмбэ — үр ашиглагдаагүй байна');
      expect(seen.contains('1,2,3,4,5,6,7,8') && seen.length == 1, isFalse);
    });

    test('ШӨНӨ тэр эрэмбээр шийдвэрлэнэ', () {
      // Тараалтаас эрэмбэ гаргах нь хангалтгүй — шөнө бүр түүнийг
      // ХЭРЭГЛЭХ ёстой. Сервер өмнө нь `[1..n]` гэж ЗОХИОДОГ байв.
      final GameRoom r = _table('NORD', seed: 3);
      r.start('p1', 0);
      _runTo(r, NetPhase.nightMafia, 0);
      expect(r.debugNightOrder, r.debugOrderPerm);
    });
  });

  group('Эмчийн дамжих төлөв', () {
    test('хоёр шөнө дараалж НЭГ хүнийг эмчилж чадахгүй', () {
      final GameRoom r = _table('HEAL');
      r.start('p1', 0);
      final PlayerId doc = _who(r, eng.Role.doctor);
      final int me = r.seatOf(doc)!;
      final int other = r.players
          .map((PublicPlayer p) => p.seat!)
          .firstWhere((int s) => s != me);

      int t = _runTo(r, NetPhase.nightDoctor, 0);
      expect(r.nightAction(doc, other, t).single.msg.type, S2C.ack);

      // Шөнө дуустал, дараагийн шөнийн эмчийн үе хүртэл.
      t = _runTo(r, NetPhase.day, t);
      expect(r.debugLastHeal[me], other,
          reason: 'сервер дамжих төлөвийг хадгалсангүй');

      t = _runTo(r, NetPhase.nightDoctor, t);
      final List<Outbound> again = r.nightAction(doc, other, t);
      expect(again.single.msg.data['code'], ErrCode.invalidTarget,
          reason: 'нэг хүнийг хоёр шөнө дараалж эмчлэв');
      // Өөр хүнийг эмчлэх нь ЗӨВ.
      final int third = r.players
          .map((PublicPlayer p) => p.seat!)
          .firstWhere((int s) => s != me && s != other);
      expect(r.nightAction(doc, third, t).single.msg.type, S2C.ack);
    });

    test('өөрийгөө НЭГ л удаа эмчилнэ', () {
      final GameRoom r = _table('SELF', seed: 7);
      r.start('p1', 0);
      final PlayerId doc = _who(r, eng.Role.doctor);
      final int me = r.seatOf(doc)!;

      int t = _runTo(r, NetPhase.nightDoctor, 0);
      expect(r.nightAction(doc, me, t).single.msg.type, S2C.ack,
          reason: 'эхний өөрийгөө эмчлэх нь зөвшөөрөгдөнө');

      t = _runTo(r, NetPhase.day, t);
      expect(r.debugSelfHealUsed[me], 1);

      t = _runTo(r, NetPhase.nightDoctor, t);
      expect(r.nightAction(doc, me, t).single.msg.data['code'],
          ErrCode.invalidTarget,
          reason: 'өөрийгөө хоёр дахь удаа эмчлэв');
    });
  });
}
