// Ажиглагч — серверийн тал.
//
// Хөдөлгүүрийн тал `packages/engine/test/watcher_test.dart`-д шалгагдсан.
// Энд ӨРӨӨ шалгагдана: эзэн дүрийг асаах, тараалт, аль үе шатанд
// үйлдэх, хариу нь ЗӨВХӨН түүнд хүрэх.

import 'dart:typed_data';

import 'package:engine/engine.dart' as eng;
import 'package:protocol/protocol.dart';
import 'package:server/server.dart';
import 'package:test/test.dart';

Uint8List _seed(int n) =>
    Uint8List.fromList(List<int>.generate(32, (int i) => (i * 61 + n) & 0xFF));

GameRoom _table(String code, {int seed = 1, int n = 8}) {
  final GameRoom r = GameRoom(code: code, hostId: 'p1', seed: _seed(seed));
  for (int i = 1; i <= n; i++) {
    r.join('p$i', 'Хүн$i', 'punk_01');
  }
  return r;
}

int _runTo(GameRoom r, NetPhase want, int from, {int limitMs = 900000}) {
  for (int t = from + 250; t <= limitMs; t += 250) {
    r.tick(t);
    if (r.phase == want) return t;
  }
  fail('$want ирсэнгүй (одоо ${r.phase})');
}

List<Object?> _setupRoles(List<Outbound> out) {
  for (final Outbound o in out.reversed) {
    if (!o.broadcast || o.msg.type != S2C.roomState) continue;
    return (o.msg.data['setupRoles'] as List<Object?>?) ?? const <Object?>[];
  }
  return const <Object?>[];
}

void main() {
  group('Эзний тохиргоо', () {
    test('анхдагчаар УНТРААЛТТАЙ', () {
      final GameRoom r = _table('W0');
      expect(r.optWatcher, isFalse);
      expect(_setupRoles(r.setReady('p1', true)), isEmpty);
    });

    test('эзэн асаавал БҮГДЭД харагдана', () {
      final GameRoom r = _table('W1');
      final List<Outbound> out = r.setOption('p1', 'watcher', true);
      expect(r.optWatcher, isTrue);
      expect(out.any((Outbound o) => o.broadcast), isTrue,
          reason: 'бүрэлдэхүүн нь НИЙТИЙН мэдээлэл');
      expect(_setupRoles(out), <String>['watcher']);
    });

    test('эзэн БИШ хүн асааж чадахгүй', () {
      final GameRoom r = _table('W2');
      expect(r.setOption('p3', 'watcher', true).single.msg.data['code'],
          ErrCode.notHost);
      expect(r.optWatcher, isFalse);
    });

    test('тоглолт эхэлсний дараа солиж чадахгүй', () {
      final GameRoom r = _table('W3');
      r.start('p1', 0);
      expect(r.setOption('p1', 'watcher', true).single.msg.data['code'],
          ErrCode.gameInProgress);
    });

    test('танихгүй тохиргоо ЧИМЭЭГҮЙ хаягдана', () {
      final GameRoom r = _table('W4');
      expect(r.setOption('p1', 'fly', true), isEmpty);
    });
  });

  group('Тараалт', () {
    test('асаасан үед ЯГ НЭГ Ажиглагч гарна', () {
      for (int s = 0; s < 6; s++) {
        final GameRoom r = _table('D$s', seed: s);
        r.setOption('p1', 'watcher', true);
        r.start('p1', 0);
        final int count = r.players
            .where((PublicPlayer p) => r.debugRoleOf(p.id) == eng.Role.watcher)
            .length;
        expect(count, 1, reason: 'үр=$s');
      }
    });

    test('унтраалттай үед Ажиглагч ГАРАХГҮЙ', () {
      for (int s = 0; s < 6; s++) {
        final GameRoom r = _table('E$s', seed: s);
        r.start('p1', 0);
        expect(
            r.players.any(
                (PublicPlayer p) => r.debugRoleOf(p.id) == eng.Role.watcher),
            isFalse,
            reason: 'үр=$s');
      }
    });

    test('мафийн тоо ХӨДЛӨХГҮЙ', () {
      final GameRoom a = _table('F1', seed: 2);
      a.start('p1', 0);
      final int mafiaPlain = a.players
          .where((PublicPlayer p) =>
              eng.factionOf(a.debugRoleOf(p.id)!) == eng.Faction.mafi)
          .length;

      final GameRoom b = _table('F2', seed: 2);
      b.setOption('p1', 'watcher', true);
      b.start('p1', 0);
      final int mafiaWatch = b.players
          .where((PublicPlayer p) =>
              eng.factionOf(b.debugRoleOf(p.id)!) == eng.Faction.mafi)
          .length;
      expect(mafiaWatch, mafiaPlain);
    });
  });

  group('Шөнийн үйлдэл', () {
    test('Ажиглагч МӨРДӨГЧИЙН үе шатанд үйлдэнэ', () {
      final GameRoom r = _table('G1', seed: 4);
      r.setOption('p1', 'watcher', true);
      r.start('p1', 0);
      final PlayerId eye = r.players
          .map((PublicPlayer p) => p.id)
          .firstWhere((PlayerId id) => r.debugRoleOf(id) == eng.Role.watcher);
      final int me = r.seatOf(eye)!;
      final int other = r.players
          .map((PublicPlayer p) => p.seat!)
          .firstWhere((int s) => s != me);

      // Мафийн үе шатанд УРЬДЧИЛЖ үйлдэж болохгүй.
      int t = _runTo(r, NetPhase.nightMafia, 0);
      expect(r.nightAction(eye, other, t).single.msg.data['code'],
          ErrCode.notYourTurn);

      t = _runTo(r, NetPhase.nightDetective, t);
      expect(r.nightAction(eye, other, t).single.msg.type, S2C.ack);
    });

    test('хариу нь ЗӨВХӨН Ажиглагчид хүрнэ', () {
      final GameRoom r = _table('G2', seed: 9);
      r.setOption('p1', 'watcher', true);
      r.start('p1', 0);
      final PlayerId eye = r.players
          .map((PublicPlayer p) => p.id)
          .firstWhere((PlayerId id) => r.debugRoleOf(id) == eng.Role.watcher);
      final int me = r.seatOf(eye)!;
      final int other = r.players
          .map((PublicPlayer p) => p.seat!)
          .firstWhere((int s) => s != me);

      int t = _runTo(r, NetPhase.nightDetective, 0);
      r.nightAction(eye, other, t);

      final List<Outbound> dawn = <Outbound>[];
      while (r.phase != NetPhase.day && t < 900000) {
        t += 250;
        dawn.addAll(r.tick(t));
      }
      final List<Outbound> mine = dawn
          .where((Outbound o) =>
              o.msg.type == S2C.investigateResult && !o.broadcast)
          .toList();
      expect(mine, isNotEmpty, reason: 'Ажиглагчид хариу ирсэнгүй');
      for (final Outbound o in mine) {
        expect(o.broadcast, isFalse);
      }
      final List<String> codes = mine
          .where((Outbound o) => o.recipients.contains(eye))
          .map((Outbound o) => o.msg.data['code']! as String)
          .toList();
      expect(codes, isNotEmpty);
      for (final String c in codes) {
        expect(<String>{'watchSaw', 'watchNobody'}.contains(c), isTrue,
            reason: 'Ажиглагчид «$c» ирлээ');
      }
    });
  });

  group('Ботууд', () {
    test('Ажиглагчтай ботон тоглолт ДУУСНА', () {
      final GameRoom r = GameRoom(code: 'BW', hostId: 'h', seed: _seed(3));
      r.join('h', 'Хүчээ', 'punk_01');
      r.addBots('h', 7);
      r.setOption('h', 'watcher', true);
      r.start('h', 0);
      for (int t = 250; t <= 900000; t += 250) {
        r.tick(t);
        if (r.phase == NetPhase.gameOver) break;
      }
      expect(r.phase, NetPhase.gameOver);
      expect(r.win, isNot(eng.WinState.none));
    });
  });
}
