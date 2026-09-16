// Саатуулагч — серверийн тал.
//
// Хөдөлгүүрийн тал `packages/engine/test/blocker_test.dart`-д шалгагдсан:
// хэн саатуулагдав, шивнээ юу болов, зочлол бичигдэв үү. Энд ӨРӨӨ
// шалгагдана — тэдгээрийн аль нь ч утас руу буруу хэлбэрээр хүрэхгүй
// байх ёстой.
//
// ГУРВАН эрсдэл ЭНД байна:
//   1. Саатуулагч ЭМЧТЭЙ нэг үе шатанд сэрдэг. Тэр үе шатны дуут суваг
//      нээгдвэл эмч, саатуулагч хоёр бие биеэ таана.
//   2. Үе шатны жагсаалт нь тоглоомд ЯМАР ДҮРҮҮД байгааг зарлаж
//      болохгүй — шинэ үе шат нэмэх нь яг тэр алдаа.
//   3. «Чамайг барив» гэсэн мессежид ХЭН барьсан нь орвол Саатуулагч
//      эхний шөнөдөө илчлэгдэнэ.

import 'dart:typed_data';

import 'package:engine/engine.dart' as eng;
import 'package:protocol/protocol.dart';
import 'package:server/server.dart';
import 'package:test/test.dart';

Uint8List _seed(int n) =>
    Uint8List.fromList(List<int>.generate(32, (int i) => (i * 61 + n) & 0xFF));

GameRoom _table(String code, {int seed = 1, int n = 8, bool blocker = true}) {
  final GameRoom r = GameRoom(code: code, hostId: 'p1', seed: _seed(seed));
  for (int i = 1; i <= n; i++) {
    r.join('p$i', 'Хүн$i', 'punk_01');
  }
  if (blocker) r.setOption('p1', 'blocker', true);
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

PlayerId _who(GameRoom r, eng.Role role) => r.players
    .map((PublicPlayer p) => p.id)
    .firstWhere((PlayerId id) => r.debugRoleOf(id) == role);

void main() {
  group('Бүрэлдэхүүн', () {
    test('асаасан үед ЯГ НЭГ Саатуулагч гарна', () {
      for (int s = 0; s < 5; s++) {
        final GameRoom r = _table('B$s', seed: s);
        final int count = r.players
            .where((PublicPlayer p) => r.debugRoleOf(p.id) == eng.Role.blocker)
            .length;
        expect(count, 1, reason: 'үр=$s');
      }
    });

    test('унтраалттай үед Саатуулагч ГАРАХГҮЙ', () {
      final GameRoom r = _table('BOFF', seed: 9, blocker: false);
      expect(
          r.players
              .any((PublicPlayer p) => r.debugRoleOf(p.id) == eng.Role.blocker),
          isFalse);
    });

    test('НЭГ ИРГЭНИЙ суудлыг орлоно — мафийн тоо ХӨДЛӨХГҮЙ', () {
      // Хэрэв Саатуулагч мафийн суудлыг иддэг бол түүнийг асаах нь
      // балансыг чимээгүйхэн хотынхон тал руу хэлбийлгэнэ.
      int mafiaOf(GameRoom r) => r.players
          .where((PublicPlayer p) =>
              eng.factionOf(r.debugRoleOf(p.id)!) == eng.Faction.mafi)
          .length;
      for (int s = 0; s < 4; s++) {
        expect(mafiaOf(_table('BN$s', seed: 20 + s)),
            mafiaOf(_table('BF$s', seed: 20 + s, blocker: false)),
            reason: 'үр=$s');
      }
    });

    test('лоббид `setupRoles` дотор гарна — ДҮР нь биш', () {
      final GameRoom r = GameRoom(code: 'BSR', hostId: 'p1', seed: _seed(3));
      for (int i = 1; i <= 8; i++) {
        r.join('p$i', 'Хүн$i', 'punk_01');
      }
      final List<Outbound> out = r.setOption('p1', 'blocker', true);
      final Map<String, Object?> st = out
          .map((Outbound o) => o.msg)
          .firstWhere((Envelope e) => e.type == S2C.roomState)
          .data;
      expect(st['setupRoles'], contains('blocker'));
      // Хэн нь Саатуулагч бэ гэдэг нь лоббид БАЙХГҮЙ — тараалт хийгээгүй.
      expect(st.toString().contains('"role"'), isFalse);
    });
  });

  group('Үе шат ба дуут суваг', () {
    test('ШИНЭ үе шат НЭМЭГДЭХГҮЙ — эмчтэй НЭГ шатанд', () {
      final GameRoom r = _table('BP1', seed: 6);
      final Set<NetPhase> seen = <NetPhase>{};
      for (int t = 250; t <= 300000; t += 250) {
        r.tick(t);
        seen.add(r.phase);
        if (r.phase == NetPhase.gameOver) break;
      }
      expect(seen.contains(NetPhase.nightDoctor), isTrue);
      // v3-д ямар ч ШИНЭ шөнийн шат БАЙХГҮЙ. Гарсан шатууд нь
      // v1-ийн гурвын ДЭД ОЛОНЛОГ байх ёстой (богино тоглолтод
      // мөрдөгчийн шат хүртэл хүрэхгүй байж болно).
      expect(
          seen.where((NetPhase p) => p.name.startsWith('night')).toSet(),
          everyElement(isIn(<NetPhase>[
            NetPhase.nightFalls,
            NetPhase.nightMafia,
            NetPhase.nightDoctor,
            NetPhase.nightDetective,
          ])));
    });

    test('эмчийн шатанд ХЭН Ч бие биеэ СОНСОХГҮЙ', () {
      // Хэрэв энэ шат нээлттэй суваг болбол эмч, Саатуулагч хоёр
      // нэг шөнийн дотор бие биеэ таана.
      final GameRoom r = _table('BV1', seed: 8);
      final int t = _runTo(r, NetPhase.nightDoctor, 0);
      expect(r.phase, NetPhase.nightDoctor, reason: 't=$t');
      expect(r.voiceScope, VoiceScope.selfOnly);
      expect(r.voiceMembers, isEmpty);
    });

    test('Саатуулагч ЭМЧИЙН шатанд л үйлдэнэ', () {
      final GameRoom r = _table('BA1', seed: 10);
      final PlayerId b = _who(r, eng.Role.blocker);
      final int me = r.seatOf(b)!;
      final int other =
          r.players.map((PublicPlayer p) => p.seat!).firstWhere((int x) => x != me);

      int t = _runTo(r, NetPhase.nightMafia, 0);
      expect(r.nightAction(b, other, t).single.msg.data['code'],
          ErrCode.notYourTurn,
          reason: 'мафийн шатанд БАЙХГҮЙ');

      t = _runTo(r, NetPhase.nightDoctor, t);
      final List<Outbound> ok = r.nightAction(b, other, t);
      expect(ok.any((Outbound o) => o.msg.type == S2C.error), isFalse);
    });

    test('Саатуулагч МАФИЙН сувагт ОРОХГҮЙ', () {
      final GameRoom r = _table('BM2', seed: 11);
      final PlayerId b = _who(r, eng.Role.blocker);
      expect(r.voiceMembers.contains(b), isFalse);
      final int t = _runTo(r, NetPhase.nightMafia, 0);
      expect(r.phase, NetPhase.nightMafia, reason: 't=$t');
      expect(r.voiceMembers.contains(b), isFalse);
    });
  });

  group('Юу ЗАРЛАГДАХГҮЙ вэ', () {
    test('«барив» гэсэн мессежид ХЭН барьсан нь БАЙХГҮЙ', () {
      final GameRoom r = _table('BR1', seed: 13);
      final PlayerId b = _who(r, eng.Role.blocker);
      final PlayerId doc = _who(r, eng.Role.doctor);
      final int docSeat = r.seatOf(doc)!;
      final int bSeat = r.seatOf(b)!;

      int t = _runTo(r, NetPhase.nightDoctor, 0);
      r.nightAction(b, docSeat, t);
      final int victim = r.players
          .map((PublicPlayer p) => p.seat!)
          .firstWhere((int x) => x != docSeat && x != bSeat);
      r.nightAction(doc, victim, t);

      final List<Outbound> out = <Outbound>[];
      for (int u = t + 250; u <= t + 300000; u += 250) {
        out.addAll(r.tick(u));
        if (r.phase == NetPhase.day || r.phase == NetPhase.gameOver) break;
      }
      final Iterable<Outbound> told = out.where((Outbound o) =>
          o.msg.type == S2C.investigateResult &&
          o.msg.data['code'] == eng.MsgCode.roleblocked.name);
      expect(told, isNotEmpty, reason: 'эмчид «болсонгүй» гэж хэлнэ');
      for (final Outbound o in told) {
        expect(o.recipients, <PlayerId>{doc},
            reason: 'ЗӨВХӨН саатуулагдсан хүнд');
        final Map<String, Object?> params =
            o.msg.data['params'] as Map<String, Object?>? ?? <String, Object?>{};
        expect(params.values.contains(bSeat), isFalse,
            reason: 'Саатуулагчийн СУУДАЛ мессежид байж БОЛОХГҮЙ');
        expect(o.msg.data.toString().contains('blocker'), isFalse);
      }
    });

    test('Саатуулагдсан хүнийг бусад тоглогч МЭДЭХГҮЙ', () {
      final GameRoom r = _table('BR2', seed: 14);
      final PlayerId b = _who(r, eng.Role.blocker);
      final PlayerId doc = _who(r, eng.Role.doctor);
      final int t = _runTo(r, NetPhase.nightDoctor, 0);
      r.nightAction(b, r.seatOf(doc)!, t);

      final List<Outbound> out = <Outbound>[];
      for (int u = t + 250; u <= t + 300000; u += 250) {
        out.addAll(r.tick(u));
        if (r.phase == NetPhase.day || r.phase == NetPhase.gameOver) break;
      }
      for (final Outbound o in out.where((Outbound o) => o.broadcast)) {
        // `setupRoles` нь ЛОББИД зориудаар нийтийнх: ямар дүрүүд
        // тоглоомд байгаа нь бүгдийн мэддэг зүйл. ХЭН нь гэдэг л нууц.
        final String text = o.msg
            .encode()
            .replaceAll(RegExp(r'"setupRoles":\[[^\]]*\]'), '"setupRoles":[]')
            .toLowerCase();
        expect(text.contains('roleblock'), isFalse);
        expect(text.contains('blocker'), isFalse);
      }
    });
  });

  group('Тоглолт явна', () {
    test('Саатуулагчтай өрөө ДУУСНА — ботоор бүрэн тоглуулна', () {
      for (int s = 0; s < 4; s++) {
        final GameRoom r = GameRoom(code: 'BG$s', hostId: 'p1', seed: _seed(40 + s));
        r.join('p1', 'Хүн1', 'punk_01');
        r.addBots('p1', 7);
        r.setOption('p1', 'blocker', true);
        r.setOption('p1', 'watcher', true);
        r.setOption('p1', 'vigilante', true);
        r.start('p1', 0);
        bool over = false;
        for (int t = 250; t <= 1200000; t += 250) {
          r.tick(t);
          if (r.phase == NetPhase.gameOver) {
            over = true;
            break;
          }
        }
        expect(over, isTrue, reason: 'үр=$s дуусаагүй');
      }
    });
  });
}
