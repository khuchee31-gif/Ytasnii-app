// ДАХИН ТОГЛОХ — тоглолт дууссаны дараа өрөө ЛОББИ руу буцна.
//
// ЯАГААД ЭНЭ ЧУХАЛ ВЭ: өмнө нь өрөө `gameOver` дээр ҮҮРД зогсдог байв.
// Дахин тоглохын тулд шинэ өрөө үүсгэж, шинэ кодыг ангид дахин хэлэх
// хэрэгтэй болно — хэдэн удаа тоглох ангид тэр нь тоглолт хоорондын
// хамгийн урт саатал.
//
// ЭРСДЭЛ: цэвэрлэлт дутуу бол ӨНГӨРСӨН тоглолтын дүр шинэ тоглолт руу
// дамжина. Тэр нь чимээгүй бөгөөд хамгийн ноцтой алдаа — хоёр дахь
// тоглолтод хүн буруу дүрээр тоглоно.

import 'dart:typed_data';

import 'package:engine/engine.dart' as eng;
import 'package:protocol/protocol.dart';
import 'package:server/server.dart';
import 'package:test/test.dart';

Uint8List _seed(int n) =>
    Uint8List.fromList(List<int>.generate(32, (int i) => (i * 53 + n) & 0xFF));

/// Тоглолтыг эхнээс нь дуустал, ДАРАА нь лобби хүртэл ажиллуулна.
int _play(GameRoom r, List<Outbound> out, int from, {int limitMs = 1500000}) {
  for (int t = from + 250; t <= limitMs; t += 250) {
    out.addAll(r.tick(t));
    if (r.phase == NetPhase.lobby && t > from + 1000) return t;
  }
  fail('лобби руу буцсангүй (одоо ${r.phase})');
}

GameRoom _solo(String code, int seed) {
  final GameRoom r = GameRoom(code: code, hostId: 'p1', seed: _seed(seed));
  r.join('p1', 'Хүн1', 'punk_01');
  r.addBots('p1', 7);
  return r;
}

void main() {
  group('Лобби руу буцна', () {
    test('тоглолт дууссаны дараа ЛОББИ, код нь ХЭВЭЭР', () {
      final GameRoom r = _solo('R1', 1);
      r.start('p1', 0);
      final List<Outbound> out = <Outbound>[];
      _play(r, out, 0);
      expect(r.phase, NetPhase.lobby);
      expect(r.code, 'R1', reason: 'код солигдвол ангид дахин хэлэх хэрэгтэй');
      expect(r.inLobby, isTrue);
    });

    test('ДҮРҮҮД бүрэн УСТАНА', () {
      final GameRoom r = _solo('R2', 2);
      r.start('p1', 0);
      expect(r.debugRoleOf('p1'), isNotNull);
      final List<Outbound> out = <Outbound>[];
      _play(r, out, 0);
      for (final PublicPlayer p in r.players) {
        expect(r.debugRoleOf(p.id), isNull,
            reason: '${p.name} хуучин дүрээ хадгалсаар байна');
        expect(p.seat, isNull);
        expect(p.alive, isTrue, reason: 'бүгд дахин амьд');
        expect(p.ready, isFalse, reason: 'дахин тоглохоо зориуд хэлнэ');
      }
    });

    test('ДАМЖИХ ТӨЛӨВ бүрэн цэвэрлэгдэнэ', () {
      final GameRoom r = GameRoom(code: 'R3', hostId: 'p1', seed: _seed(3));
      r.join('p1', 'Хүн1', 'punk_01');
      r.addBots('p1', 7);
      r.setOption('p1', 'vigilante', true);
      r.setOption('p1', 'mayor', true);
      r.start('p1', 0);
      expect(r.debugBullets, isNotEmpty);
      final List<Outbound> out = <Outbound>[];
      _play(r, out, 0);
      expect(r.debugBullets, isEmpty, reason: 'сум дараагийн тоглолт руу дамжив');
      expect(r.revealedSeats, isEmpty, reason: 'илчилсэн дарга дамжив');
      expect(r.debugLastHeal, isEmpty);
      expect(r.debugIntentActors, isEmpty);
    });

    test('ХОЁР ДАХЬ тоглолт бүрэн явна — дүр ШИНЭЭР тарагдана', () {
      final GameRoom r = _solo('R4', 4);
      r.start('p1', 0);
      final List<Outbound> out = <Outbound>[];
      final int t = _play(r, out, 0);

      // Хоёр дахь тоглолт.
      final List<Outbound> err = r.start('p1', t);
      expect(err.any((Outbound o) => o.msg.type == S2C.error), isFalse,
          reason: 'лоббид эхлүүлэх боломжтой байх ёстой');
      expect(r.debugRoleOf('p1'), isNotNull, reason: 'дүр шинээр тарагдсангүй');
      final int t2 = _play(r, out, t);
      expect(t2, greaterThan(t));
      expect(r.phase, NetPhase.lobby);
    });

    test('ТОХИРУУЛГА ХЭВЭЭР — эзэн дахин асаах шаардлагагүй', () {
      // Дүрийн сонголт бол ӨРӨӨНИЙ тохиргоо, тоглолтынх биш.
      final GameRoom r = GameRoom(code: 'R5', hostId: 'p1', seed: _seed(5));
      r.join('p1', 'Хүн1', 'punk_01');
      r.addBots('p1', 7);
      r.setOption('p1', 'watcher', true);
      r.setOption('p1', 'blocker', true);
      r.start('p1', 0);
      final List<Outbound> out = <Outbound>[];
      _play(r, out, 0);
      expect(r.optWatcher, isTrue);
      expect(r.optBlocker, isTrue);
    });
  });

  group('Юу АЛДАГДАХГҮЙ вэ', () {
    test('лобби руу буцахад НИЙТИЙН мессежид дүр ГАРАХГҮЙ', () {
      final GameRoom r = _solo('R6', 6);
      r.start('p1', 0);
      final List<Outbound> out = <Outbound>[];
      _play(r, out, 0);
      // `gameOver` нь дүрийг ЗОРИУД илчилдэг — түүнээс ХОЙШХИ
      // мессежүүдийг шалгана.
      final int over = out.indexWhere(
          (Outbound o) => o.msg.type == S2C.gameOver);
      expect(over, greaterThanOrEqualTo(0));
      final StringBuffer b = StringBuffer();
      for (final Outbound o in out.skip(over + 1)) {
        if (!o.broadcast) continue;
        b.write(o.msg
            .encode()
            .replaceAll(RegExp(r'"phase":"[A-Za-z]*"'), '"phase":"_"')
            .replaceAll(RegExp(r'"setupRoles":\[[^\]]*\]'), '"setupRoles":[]'));
      }
      final String text = b.toString().toLowerCase();
      for (final eng.Role role in eng.Role.values) {
        expect(text.contains(role.name), isFalse,
            reason: 'лобби руу буцах мессежид «${role.name}» олдлоо');
      }
    });
  });
}
