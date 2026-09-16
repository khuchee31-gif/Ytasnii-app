// Хотын дарга — серверийн тал.
//
// Хөдөлгүүрийн тал `packages/engine/test/mayor_test.dart`-д шалгагдсан:
// илчилсэн дарга байхад мафийн тэнцэл хүрэхгүй. Энд ӨРӨӨ шалгагдана:
// хэн илчилж чадах, хэзээ, саналын жин хэрхэн тоологдох.

import 'dart:typed_data';

import 'package:engine/engine.dart' as eng;
import 'package:protocol/protocol.dart';
import 'package:server/server.dart';
import 'package:test/test.dart';

Uint8List _seed(int n) =>
    Uint8List.fromList(List<int>.generate(32, (int i) => (i * 71 + n) & 0xFF));

GameRoom _table(String code, {int seed = 1, int n = 8, bool mayor = true}) {
  final GameRoom r = GameRoom(code: code, hostId: 'p1', seed: _seed(seed));
  for (int i = 1; i <= n; i++) {
    r.join('p$i', 'Хүн$i', 'punk_01');
  }
  if (mayor) r.setOption('p1', 'mayor', true);
  return r;
}

int _runTo(GameRoom r, NetPhase want, int from, {int limitMs = 900000}) {
  for (int t = from + 250; t <= limitMs; t += 250) {
    r.tick(t);
    if (r.phase == want) return t;
  }
  fail('$want ирсэнгүй (одоо ${r.phase})');
}

PlayerId _mayorOf(GameRoom r) => r.players
    .map((PublicPlayer p) => p.id)
    .firstWhere((PlayerId id) => r.debugRoleOf(id) == eng.Role.mayor);

void main() {
  group('Илчлэх эрх', () {
    test('ЗӨВХӨН дарга илчилнэ', () {
      final GameRoom r = _table('M1');
      r.start('p1', 0);
      final int t = _runTo(r, NetPhase.day, 0);
      final PlayerId mayor = _mayorOf(r);
      final PlayerId other = r.players
          .map((PublicPlayer p) => p.id)
          .firstWhere((PlayerId id) => id != mayor);

      expect(r.dayAction(other, 'reveal', t).single.msg.data['code'],
          ErrCode.notYourAbility);
      expect(r.revealedSeats, isEmpty);

      final List<Outbound> out = r.dayAction(mayor, 'reveal', t);
      expect(out.first.msg.type, S2C.voteWeight);
      expect(out.first.broadcast, isTrue, reason: 'илчлэлт нь НИЙТИЙНХ');
      expect(out.first.msg.data['weight'], 3);
      expect(r.revealedSeats, <int>{r.seatOf(mayor)!});
    });

    test('ХОЁР УДАА илчилж болохгүй', () {
      final GameRoom r = _table('M2', seed: 2);
      r.start('p1', 0);
      final int t = _runTo(r, NetPhase.day, 0);
      final PlayerId mayor = _mayorOf(r);
      r.dayAction(mayor, 'reveal', t);
      expect(r.dayAction(mayor, 'reveal', t).single.msg.data['code'],
          ErrCode.notYourTurn);
    });

    test('ШӨНӨ илчилж болохгүй', () {
      final GameRoom r = _table('M3', seed: 3);
      r.start('p1', 0);
      final PlayerId mayor = _mayorOf(r);
      for (final NetPhase dark in <NetPhase>[
        NetPhase.nightFalls,
        NetPhase.nightMafia,
        NetPhase.nightDoctor,
        NetPhase.nightDetective,
      ]) {
        final int t = _runTo(r, dark, 0);
        expect(r.dayAction(mayor, 'reveal', t).single.msg.data['code'],
            ErrCode.notYourTurn,
            reason: '$dark');
      }
    });

    test('САНАЛ ХУРААЛТЫН дундуур илчилж БОЛНО', () {
      // Тоглоомын хамгийн хурц мөч — хаах шалтгаан байхгүй.
      final GameRoom r = _table('M4', seed: 5);
      r.start('p1', 0);
      final int t = _runTo(r, NetPhase.vote, 0);
      final PlayerId mayor = _mayorOf(r);
      expect(r.dayAction(mayor, 'reveal', t).first.msg.type, S2C.voteWeight);
    });

    test('ҮХСЭН дарга илчилж чадахгүй', () {
      // Даргыг САНАЛААР хасна — энэ нь бүрэн хяналттай зам.
      final GameRoom r = _table('M5', seed: 8);
      r.start('p1', 0);
      final PlayerId mayor = _mayorOf(r);
      final int seat = r.seatOf(mayor)!;
      int t = _runTo(r, NetPhase.vote, 0);
      for (final PublicPlayer p in r.players) {
        if (p.id != mayor) r.vote(p.id, seat);
      }
      while (r.phase == NetPhase.vote && t < 900000) {
        t += 250;
        r.tick(t);
      }
      expect(
          r.players.firstWhere((PublicPlayer p) => p.id == mayor).alive, isFalse,
          reason: 'дарга хасагдсангүй');
      t = _runTo(r, NetPhase.day, t);
      expect(r.dayAction(mayor, 'reveal', t).single.msg.data['code'],
          ErrCode.notYourTurn);
    });

    test('танихгүй өдрийн үйлдэл ЧИМЭЭГҮЙ хаягдана', () {
      final GameRoom r = _table('M6', seed: 6);
      r.start('p1', 0);
      final int t = _runTo(r, NetPhase.day, 0);
      expect(r.dayAction(_mayorOf(r), 'fly', t), isEmpty);
    });
  });

  group('Саналын жин', () {
    test('илчилсэн даргын санал ГУРАВ', () {
      final GameRoom r = _table('W1', seed: 11);
      r.start('p1', 0);
      int t = _runTo(r, NetPhase.day, 0);
      final PlayerId mayor = _mayorOf(r);
      r.dayAction(mayor, 'reveal', t);
      expect(r.voteWeightOf(r.seatOf(mayor)!), 3);

      t = _runTo(r, NetPhase.vote, t);
      // Дарга нэг хүн рүү, өөр хоёр хүн ӨӨР хүн рүү.
      final List<PublicPlayer> alive =
          r.players.where((PublicPlayer p) => p.alive).toList();
      final int a = alive.firstWhere((PublicPlayer p) => p.id != mayor).seat!;
      final int bSeat = alive
          .firstWhere((PublicPlayer p) => p.id != mayor && p.seat != a)
          .seat!;
      r.vote(mayor, a);
      int given = 0;
      for (final PublicPlayer p in alive) {
        if (p.id == mayor || p.seat == a) continue;
        r.vote(p.id, bSeat);
        given++;
        if (given == 2) break;
      }

      final List<Outbound> out = <Outbound>[];
      while (r.phase == NetPhase.vote && t < 900000) {
        t += 250;
        out.addAll(r.tick(t));
      }
      final Envelope elim = out
          .map((Outbound o) => o.msg)
          .lastWhere((Envelope e) => e.type == S2C.eliminated);
      final Map<String, Object?> tally =
          (elim.data['tally']! as Map<String, Object?>);
      expect(tally['$a'], 3, reason: 'даргын санал гурав байх ёстой');
      expect(tally['$bSeat'], 2);
      expect(elim.data['seat'], a, reason: 'дарга дийллээ');
    });

    test('илчлээгүй бол санал НЭГ', () {
      final GameRoom r = _table('W2', seed: 12);
      r.start('p1', 0);
      _runTo(r, NetPhase.day, 0);
      expect(r.voteWeightOf(r.seatOf(_mayorOf(r))!), 1);
    });
  });

  group('Ялалт', () {
    test('ИЛЧИЛСЭН дарга байхад мафи тоогоороо тэнцээд ЯЛАХГҮЙ', () {
      // Хоёр газар бичигдсэн дүрэм чимээгүй салах эрсдэлтэй байсан:
      // хөдөлгүүр `evaluateWin`-ээр, сервер өөрийн хуулбараар шалгадаг
      // байв. Илчилсэн дарга нь яг тэр хоёрыг ялгаж харуулна.
      //
      // Найман суудал: 2 мафи, 6 хотынхон. Иргэдийг санал зарган хасаж
      // 2:2 болгоно.
      GameRoom build(int seed, {required bool reveal}) {
        final GameRoom r = _table('V$seed', seed: seed);
        r.start('p1', 0);
        int t = 0;
        if (reveal) {
          t = _runTo(r, NetPhase.day, 0);
          r.dayAction(_mayorOf(r), 'reveal', t);
        }
        // Иргэдийг нэг нэгээр нь хасна (мафи, дарга хоёрыг АЛГАСНА).
        while (true) {
          final List<PublicPlayer> alive =
              r.players.where((PublicPlayer p) => p.alive).toList();
          final int mafi = alive
              .where((PublicPlayer p) =>
                  eng.factionOf(r.debugRoleOf(p.id)!) == eng.Faction.mafi)
              .length;
          if (alive.length - mafi <= mafi) break;
          // ДАРГЫГ АМЬД ҮЛДЭЭНЭ — түүний нэмэлт санал л шалгагдаж
          // байна. Бусад хотынхныг дарааллаар нь хасна.
          final PublicPlayer victim = alive.firstWhere((PublicPlayer p) =>
              r.debugRoleOf(p.id) != eng.Role.mayor &&
              eng.factionOf(r.debugRoleOf(p.id)!) == eng.Faction.hotynhon);
          t = _runTo(r, NetPhase.vote, t);
          for (final PublicPlayer p in alive) {
            if (p.id != victim.id) r.vote(p.id, victim.seat!);
          }
          while (r.phase == NetPhase.vote && t < 1800000) {
            t += 250;
            r.tick(t);
          }
          if (r.phase == NetPhase.gameOver) break;
        }
        return r;
      }

      final GameRoom plain = build(31, reveal: false);
      expect(plain.win, eng.WinState.mafi,
          reason: 'илчлэлтгүй бол тэнцэхэд мафи ялна');

      final GameRoom withMayor = build(31, reveal: true);
      expect(withMayor.win, eng.WinState.none,
          reason: 'илчилсэн дарга байхад мафи саналаар дийлэхгүй');
      expect(withMayor.phase, isNot(NetPhase.gameOver));
    });
  });

  group('Ботууд', () {
    test('даргатай ботон тоглолт ДУУСНА', () {
      final GameRoom r = GameRoom(code: 'BM', hostId: 'h', seed: _seed(4));
      r.join('h', 'Хүчээ', 'punk_01');
      r.addBots('h', 7);
      r.setOption('h', 'mayor', true);
      r.setOption('h', 'watcher', true);
      r.start('h', 0);
      for (int t = 250; t <= 1800000; t += 250) {
        r.tick(t);
        if (r.phase == NetPhase.gameOver) break;
      }
      expect(r.phase, NetPhase.gameOver);
      expect(r.win, isNot(eng.WinState.none));
    });
  });
}
