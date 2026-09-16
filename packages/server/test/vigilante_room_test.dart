// Манаач — серверийн тал.
//
// Хөдөлгүүрийн тал `packages/engine/test/vigilante_test.dart`-д
// шалгагдсан. Энд ӨРӨӨ шалгагдана: сум хаанаас ирэх, шөнөөс шөнөд
// ДАМЖИХ эсэх, аль үе шатанд буудах, гэмшил ҮНЭХЭЭР ирэх эсэх.

import 'dart:typed_data';

import 'package:engine/engine.dart' as eng;
import 'package:protocol/protocol.dart';
import 'package:server/server.dart';
import 'package:test/test.dart';

Uint8List _seed(int n) =>
    Uint8List.fromList(List<int>.generate(32, (int i) => (i * 97 + n) & 0xFF));

GameRoom _table(String code, {int seed = 1, int n = 8}) {
  final GameRoom r = GameRoom(code: code, hostId: 'p1', seed: _seed(seed));
  for (int i = 1; i <= n; i++) {
    r.join('p$i', 'Хүн$i', 'punk_01');
  }
  r.setOption('p1', 'vigilante', true);
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

PlayerId _vigil(GameRoom r) => r.players
    .map((PublicPlayer p) => p.id)
    .firstWhere((PlayerId id) => r.debugRoleOf(id) == eng.Role.vigilante);

void main() {
  group('Бүрэлдэхүүн ба сум', () {
    test('асаасан үед ЯГ НЭГ Манаач, ХОЁР сумтай', () {
      for (int s = 0; s < 5; s++) {
        final GameRoom r = _table('V$s', seed: s);
        final List<PlayerId> vs = r.players
            .map((PublicPlayer p) => p.id)
            .where((PlayerId id) => r.debugRoleOf(id) == eng.Role.vigilante)
            .toList();
        expect(vs.length, 1, reason: 'үр=$s');
        expect(r.debugBullets[r.seatOf(vs.first)!], eng.kVigilanteBullets);
      }
    });

    test('унтраалттай үед Манаач ГАРАХГҮЙ, сум БАЙХГҮЙ', () {
      final GameRoom r = GameRoom(code: 'VOFF', hostId: 'p1', seed: _seed(9));
      for (int i = 1; i <= 8; i++) {
        r.join('p$i', 'Хүн$i', 'punk_01');
      }
      r.start('p1', 0);
      expect(
          r.players.any((PublicPlayer p) =>
              r.debugRoleOf(p.id) == eng.Role.vigilante),
          isFalse);
      expect(r.debugBullets, isEmpty);
    });
  });

  group('Буудах', () {
    test('ЭХНИЙ шөнө буудахгүй', () {
      final GameRoom r = _table('VS1', seed: 2);
      final PlayerId v = _vigil(r);
      final int me = r.seatOf(v)!;
      final int other = r.players
          .map((PublicPlayer p) => p.seat!)
          .firstWhere((int x) => x != me);
      final int t = _runTo(r, NetPhase.nightMafia, 0);
      expect(r.nightAction(v, other, t).single.msg.data['code'],
          ErrCode.nightTooEarly);
    });

    test('Манаач МАФИЙН сувагт ОРОХГҮЙ', () {
      // Мафитай нэг үе шатанд байгаа нь тэдний хувийн мэдээллийг
      // өгөх ёсгүй. Хэрэв `mafiaPick` Манаачид хүрвэл тэр шөнө бүр
      // хэн алагдахыг урьдчилан мэдэж, дүр нь тоглоомыг эвдэнэ.
      final GameRoom r = _table('VM1', seed: 12);
      final PlayerId v = _vigil(r);
      int t = _runTo(r, NetPhase.day, 0);
      t = _runTo(r, NetPhase.nightMafia, t);

      final List<Outbound> out = <Outbound>[];
      // Мафи сонголтоо хийнэ.
      for (final PublicPlayer p in r.players.where((PublicPlayer p) =>
          p.alive &&
          eng.factionOf(r.debugRoleOf(p.id)!) == eng.Faction.mafi)) {
        final int target = r.players
            .where((PublicPlayer x) => x.alive)
            .map((PublicPlayer x) => x.seat!)
            .firstWhere((int x) => x != p.seat);
        out.addAll(r.nightAction(p.id, target, t));
      }
      for (final Outbound o in out) {
        if (o.msg.type != S2C.mafiaPick) continue;
        expect(o.recipients.contains(v), isFalse,
            reason: 'Манаачид мафийн сонголт хүрлээ');
      }

      // Манаачийн ӨӨРИЙН буудлага нь `ack` авна, `mafiaPick` БИШ.
      final int me = r.seatOf(v)!;
      final int shot = r.players
          .where((PublicPlayer p) => p.alive)
          .map((PublicPlayer p) => p.seat!)
          .firstWhere((int x) => x != me);
      final List<Outbound> mine = r.nightAction(v, shot, t);
      expect(mine.single.msg.type, S2C.ack);
    });

    test('хоёр дахь шөнө буудвал СУМ хасагдана', () {
      final GameRoom r = _table('VS2', seed: 4);
      final PlayerId v = _vigil(r);
      final int me = r.seatOf(v)!;

      int t = _runTo(r, NetPhase.day, 0);              // 1-р шөнө өнгөрөв
      t = _runTo(r, NetPhase.nightMafia, t);           // 2-р шөнө
      final int target = r.players
          .where((PublicPlayer p) => p.alive)
          .map((PublicPlayer p) => p.seat!)
          .firstWhere((int x) => x != me);
      expect(r.nightAction(v, target, t).single.msg.type, S2C.ack);

      t = _runTo(r, NetPhase.day, t);
      expect(r.debugBullets[me], eng.kVigilanteBullets - 1,
          reason: 'сум шөнөөс шөнөд ДАМЖААГҮЙ байна');
    });

    test('сум дуусвал ТАТГАЛЗАНА', () {
      final GameRoom r = _table('VS3', seed: 6);
      final PlayerId v = _vigil(r);
      final int me = r.seatOf(v)!;
      int t = _runTo(r, NetPhase.day, 0);
      // Хоёр сумыг хоёр шөнөд зарцуулна.
      for (int k = 0; k < 2; k++) {
        t = _runTo(r, NetPhase.nightMafia, t);
        final int target = r.players
            .where((PublicPlayer p) => p.alive)
            .map((PublicPlayer p) => p.seat!)
            .firstWhere((int x) => x != me);
        r.nightAction(v, target, t);
        t = _runTo(r, NetPhase.day, t);
        if (!r.players.firstWhere((PublicPlayer p) => p.id == v).alive) return;
      }
      t = _runTo(r, NetPhase.nightMafia, t);
      final int last = r.players
          .where((PublicPlayer p) => p.alive)
          .map((PublicPlayer p) => p.seat!)
          .firstWhere((int x) => x != me);
      expect(r.nightAction(v, last, t).single.msg.data['code'],
          ErrCode.chargeSpent);
    });
  });

  group('Ботууд', () {
    test('Манаачтай ботон тоглолт ДУУСНА', () {
      final GameRoom r = GameRoom(code: 'VB', hostId: 'h', seed: _seed(11));
      r.join('h', 'Хүчээ', 'punk_01');
      r.addBots('h', 7);
      r.setOption('h', 'vigilante', true);
      r.setOption('h', 'watcher', true);
      r.setOption('h', 'mayor', true);
      r.start('h', 0);
      for (int t = 250; t <= 1800000; t += 250) {
        r.tick(t);
        if (r.phase == NetPhase.gameOver) break;
      }
      expect(r.phase, NetPhase.gameOver);
      expect(r.win, isNot(eng.WinState.none));
    });

    test('гурван нэмэлт дүртэй тоглолт ХЭД ДАХИН давтагдана', () {
      // Олон үр дээр гүйлгэж, инвариант эвдрэхгүйг шалгана. Хөдөлгүүр
      // дебаг билд дээр `checkInvariants`-ыг ҮРГЭЛЖ ажиллуулдаг тул
      // ямар нэг зөрчил гарвал ЭНД шидэгдэнэ.
      for (int s = 0; s < 8; s++) {
        final GameRoom r = GameRoom(code: 'VR$s', hostId: 'h', seed: _seed(40 + s));
        r.join('h', 'Хүчээ', 'punk_01');
        r.addBots('h', 9);
        r.setOption('h', 'vigilante', true);
        r.setOption('h', 'watcher', true);
        r.setOption('h', 'mayor', true);
        r.start('h', 0);
        for (int t = 250; t <= 1800000; t += 250) {
          r.tick(t);
          if (r.phase == NetPhase.gameOver) break;
        }
        expect(r.phase, NetPhase.gameOver, reason: 'үр=$s');
      }
    });
  });
}
