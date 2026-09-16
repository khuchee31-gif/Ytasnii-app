// «Хотын шивнээ» — серверийн тал.
//
// ЭНЭ ФАЙЛЫН БҮХ УТГА НЭГ АЛДААНД: шивнээний сан нь ТОВШИЛТ тоолдог.
// Хэрэв зөвхөн ЧАДВАРТАЙ дүрүүд товшдог байсан бол зарлагдсан хоёр
// суудал нь «хэн рүү очсон» гэсэн утгатай болно — хоёр алуурчин ба
// эмч нэг хүн дээр таарвал босго давж, «эмч хэнийг аварсныг» бүх
// ширээнд ҮНЭГҮЙ зарлана. Тэр нь Ажиглагчийн чадварыг хэн ч
// төлөөгүй байж авна гэсэн үг.
//
// Засвар нь: БҮХ АМЬД ХҮН товшино (Иргэн, Дарга нар мөн).

import 'dart:typed_data';

import 'package:engine/engine.dart' as eng;
import 'package:protocol/protocol.dart';
import 'package:server/server.dart';
import 'package:test/test.dart';

Uint8List _seed(int n) =>
    Uint8List.fromList(List<int>.generate(32, (int i) => (i * 37 + n) & 0xFF));

GameRoom _table(String code, {int seed = 1, int n = 8}) {
  final GameRoom r = GameRoom(code: code, hostId: 'p1', seed: _seed(seed));
  for (int i = 1; i <= n; i++) {
    r.join('p$i', 'Хүн$i', 'punk_01');
  }
  r.start('p1', 0);
  return r;
}

int _runTo(GameRoom r, NetPhase want, int from, {int limitMs = 900000}) {
  for (int t = from + 250; t <= limitMs; t += 250) {
    r.tick(t);
    if (r.phase == want) return t;
  }
  fail('$want ирсэнгүй (одоо ${r.phase})');
}

List<PlayerId> _all(GameRoom r, eng.Role role) => r.players
    .map((PublicPlayer p) => p.id)
    .where((PlayerId id) => r.debugRoleOf(id) == role)
    .toList();

void main() {
  group('Хэн товшиж чадах вэ', () {
    test('ИРГЭН шөнө товшиж ЧАДНА', () {
      final GameRoom r = _table('W1', seed: 3);
      final PlayerId c = _all(r, eng.Role.citizen).first;
      final int me = r.seatOf(c)!;
      final int other = r.players
          .map((PublicPlayer p) => p.seat!)
          .firstWhere((int x) => x != me);
      final int t = _runTo(r, NetPhase.nightDetective, 0);
      final List<Outbound> out = r.nightAction(c, other, t);
      expect(out.any((Outbound o) => o.msg.type == S2C.error), isFalse,
          reason: 'иргэн сэжиглэж чадах ёстой');
    });

    test('ИРГЭН МАФИЙН болон ЭМЧИЙН шатанд товшиж ЧАДАХГҮЙ', () {
      final GameRoom r = _table('W2', seed: 4);
      final PlayerId c = _all(r, eng.Role.citizen).first;
      final int me = r.seatOf(c)!;
      final int other = r.players
          .map((PublicPlayer p) => p.seat!)
          .firstWhere((int x) => x != me);
      int t = _runTo(r, NetPhase.nightMafia, 0);
      expect(r.nightAction(c, other, t).single.msg.data['code'],
          ErrCode.notYourTurn);
      t = _runTo(r, NetPhase.nightDoctor, t);
      expect(r.nightAction(c, other, t).single.msg.data['code'],
          ErrCode.notYourTurn);
    });

    test('ИРГЭН ӨӨРИЙГӨӨ сэжиглэж БОЛОХГҮЙ', () {
      final GameRoom r = _table('W3', seed: 5);
      final PlayerId c = _all(r, eng.Role.citizen).first;
      final int me = r.seatOf(c)!;
      final int t = _runTo(r, NetPhase.nightDetective, 0);
      expect(r.nightAction(c, me, t).single.msg.type, S2C.error);
    });
  });

  group('Юуг АЛДАГДУУЛАХГҮЙ вэ', () {
    test('СЭЖИГЛЭХ нь ЗОЧЛОЛ БИШ — Ажиглагч түүнийг ХАРАХГҮЙ', () {
      // Хэрэв сэжиглэх нь зочлол бол Ажиглагч шөнө бүр бараг бүх
      // ширээг «зочилсон» гэж харах бөгөөд түүний хариу утгагүй болно.
      final GameRoom r = GameRoom(code: 'W4', hostId: 'p1', seed: _seed(6));
      for (int i = 1; i <= 8; i++) {
        r.join('p$i', 'Хүн$i', 'punk_01');
      }
      r.setOption('p1', 'watcher', true);
      r.start('p1', 0);

      final PlayerId w = _all(r, eng.Role.watcher).first;
      final List<PlayerId> cits = _all(r, eng.Role.citizen);
      expect(cits, isNotEmpty);
      final int victim = r.seatOf(cits.first)!;

      final int t = _runTo(r, NetPhase.nightDetective, 0);
      r.nightAction(w, victim, t);
      // Бүх иргэн ТЭР хүнийг сэжиглэнэ.
      for (final PlayerId c in cits) {
        if (r.seatOf(c) == victim) continue;
        r.nightAction(c, victim, t);
      }

      final List<Outbound> out = <Outbound>[];
      for (int u = t + 250; u <= t + 300000; u += 250) {
        out.addAll(r.tick(u));
        if (r.phase == NetPhase.day || r.phase == NetPhase.gameOver) break;
      }
      final Iterable<Outbound> seen = out.where((Outbound o) =>
          o.msg.type == S2C.investigateResult &&
          o.msg.data['code'] == eng.MsgCode.watchSaw.name);
      for (final Outbound o in seen) {
        final Map<String, Object?> pr =
            o.msg.data['params'] as Map<String, Object?>? ?? <String, Object?>{};
        final int who = int.tryParse('${pr['seat']}') ?? -1;
        expect(r.debugRoleOf(r.players
                .firstWhere((PublicPlayer p) => p.seat == who)
                .id),
            isNot(eng.Role.citizen),
            reason: 'сэжиглэсэн иргэн ЗОЧЛОГЧ болж харагдав');
      }
    });

    test('шивнээ нь НИЙТИЙНХ — бүх утас ИЖИЛ жагсаалт авна', () {
      final GameRoom r = GameRoom(code: 'W5', hostId: 'p1', seed: _seed(7));
      r.join('p1', 'Хүн1', 'punk_01');
      r.addBots('p1', 7);
      r.start('p1', 0);
      final List<Outbound> out = <Outbound>[];
      for (int t = 250; t <= 300000; t += 250) {
        out.addAll(r.tick(t));
        if (r.phase == NetPhase.day || r.phase == NetPhase.gameOver) break;
      }
      final Iterable<Outbound> nr =
          out.where((Outbound o) => o.msg.type == S2C.nightResult);
      expect(nr, isNotEmpty);
      for (final Outbound o in nr) {
        expect(o.broadcast, isTrue,
            reason: 'шивнээг нэг хэсэгт нь илгээвэл тэр нь ДАВУУ ЭРХ болно');
      }
    });
  });

  group('Босго нь СЭЖИГЛЭГЧДИЙН тооноос гарна', () {
    test('нэмэлт дүр асаахад босго БУУРНА', () {
      // Ажиглагч, Дарга хоёр иргэний суудлыг иддэг. Хэрэв босго
      // тогтмол 3 байсан бол наймтай ширээнд гурван сэжиглэгч
      // үлдэж, гурвуулаа ЯГ нэг суудал сонгох магадлал ~2% болно —
      // жинхэнэ ботын тоглолтоор хэмжихэд 61 шөнөд ганц ч шивнээ
      // гараагүй.
      final GameRoom plain = _table('T1', seed: 21);
      final GameRoom rich = GameRoom(code: 'T2', hostId: 'p1', seed: _seed(21));
      for (int i = 1; i <= 8; i++) {
        rich.join('p$i', 'Хүн$i', 'punk_01');
      }
      rich.setOption('p1', 'watcher', true);
      rich.setOption('p1', 'mayor', true);
      rich.setOption('p1', 'blocker', true);
      rich.start('p1', 0);
      expect(rich.debugMinAgree, lessThanOrEqualTo(plain.debugMinAgree));
      expect(rich.debugMinAgree, greaterThanOrEqualTo(2),
          reason: 'нэг хүний товшилт ХЭЗЭЭ Ч шивнээ гаргаж болохгүй');
    });

    test('босго нь ХЭЗЭЭ Ч нэг болохгүй', () {
      // Нэг л сэжиглэгчтэй ширээ гарвал түүний товшилт нь ШУУД
      // нийтлэгдэж, тэр хүнийг илчилнэ.
      for (int n = 6; n <= 14; n++) {
        final GameRoom r = GameRoom(code: 'M$n', hostId: 'p1', seed: _seed(n));
        for (int i = 1; i <= n; i++) {
          r.join('p$i', 'Хүн$i', 'punk_01');
        }
        r.setOption('p1', 'watcher', true);
        r.setOption('p1', 'mayor', true);
        r.setOption('p1', 'vigilante', true);
        r.setOption('p1', 'blocker', true);
        r.start('p1', 0);
        expect(r.debugMinAgree, greaterThanOrEqualTo(2), reason: 'n=$n');
      }
    });
  });

  group('Бүх ширээ товшино', () {
    test('ботоор дүүрсэн ширээнд шөнө БҮХ амьд суудал санаа илгээнэ', () {
      // Хэрэв зөвхөн хүн товшдог байсан бол шивнээ нь тэр ганц хүний
      // сэжгийг шууд зарлана.
      final GameRoom r = GameRoom(code: 'W6', hostId: 'p1', seed: _seed(8));
      r.join('p1', 'Хүн1', 'punk_01');
      r.addBots('p1', 7);
      r.setOption('p1', 'watcher', true);
      r.setOption('p1', 'mayor', true);
      r.start('p1', 0);

      _runTo(r, NetPhase.nightDetective, 0);
      // Мөрдөгчийн шатны төгсгөлд бүх бот товшсон байх ёстой.
      for (int t = 250; t <= 300000; t += 250) {
        r.tick(t);
        if (r.phase != NetPhase.nightDetective) break;
      }
      final Set<int> acted = r.debugIntentActors;
      final Set<int> botSeats = r.players
          .where((PublicPlayer p) => p.isBot && p.alive)
          .map((PublicPlayer p) => p.seat!)
          .toSet();
      expect(acted.containsAll(botSeats), isTrue,
          reason: 'товшсон=$acted ботууд=$botSeats');
    });
  });
}
