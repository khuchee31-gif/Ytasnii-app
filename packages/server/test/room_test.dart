// Өрөөний тест — сүлжээгүйгээр, бүтэн тоглолт.
//
// Энд хоёр зүйлийг батлана:
//
//   1. ДҮР АЛДАГДАХГҮЙ. Бүтэн тоглолт явуулж, БҮХ нийтийн мессежийг цуглуулж,
//      дотор нь дүрийн нэр байгаа эсэхийг хайна. Хэрэв хэн нэгэн хожим
//      «энэ талбарыг нэмчихье» гэвэл энэ тест тэр дор нь унана.
//
//   2. ДУУ ЗӨВ ХААГДАНА. Шөнө мафийн үед зөвхөн мафи бие биенээ сонсоно.
//      Энэ тоо буруу бол бүх анги алуурчдыг сонсоно — тоглоом үхнэ.

import 'dart:typed_data';

import 'package:engine/engine.dart' as eng;
import 'package:protocol/protocol.dart';
import 'package:server/server.dart';
import 'package:test/test.dart';

/// Тогтмол seed — тоглолт бүрэн давтагдана.
Uint8List _seed(int n) =>
    Uint8List.fromList(List<int>.generate(32, (int i) => (i * 37 + n) & 0xFF));

/// Тоглогчидтой өрөө үүсгэнэ.
GameRoom _roomWith(int n, {int seed = 5}) {
  final GameRoom r = GameRoom(code: 'K7M2', hostId: 'p1', seed: _seed(seed));
  for (int i = 1; i <= n; i++) {
    r.join('p$i', 'Тоглогч$i', 'punk_0${i % 9}');
  }
  return r;
}

/// Нийтийн мессежийн бүх текстийг нэг мөр болгож буцаана.
String _publicText(List<Outbound> out) {
  final StringBuffer b = StringBuffer();
  for (final Outbound o in out) {
    if (!o.broadcast) continue;
    b.write(o.msg.encode());
    b.write('\n');
  }
  return b.toString();
}

void main() {
  group('Өрөөнд орох', () {
    test('орсон хүн бүр нийтийн төлөвт гарна', () {
      final GameRoom r = _roomWith(3);
      expect(r.playerCount, 3);
      expect(r.players.map((PublicPlayer p) => p.name),
          containsAll(<String>['Тоглогч1', 'Тоглогч2', 'Тоглогч3']));
    });

    test('ижил нэр хоёр удаа орохгүй', () {
      final GameRoom r = GameRoom(code: 'AAAA', hostId: 'a', seed: _seed(1));
      r.join('a', 'Бат', 'x');
      final List<Outbound> out = r.join('b', 'Бат', 'y');
      expect(out.single.msg.type, S2C.error);
      expect(out.single.msg.data['code'], ErrCode.nameTaken);
      expect(r.playerCount, 1);
    });

    test('хэт олон хүн орохгүй', () {
      final GameRoom r = _roomWith(kMaxPlayers);
      final List<Outbound> out = r.join('extra', 'Илүү', 'z');
      expect(out.single.msg.data['code'], ErrCode.roomFull);
    });

    test('эзэн биш хүн тоглолт эхлүүлж чадахгүй', () {
      final GameRoom r = _roomWith(8);
      final List<Outbound> out = r.start('p3', 0);
      expect(out.single.msg.data['code'], ErrCode.notHost);
      expect(r.phase, NetPhase.lobby);
    });

    test('хүн цөөн бол эхлэхгүй', () {
      final GameRoom r = _roomWith(kMinPlayers - 1);
      final List<Outbound> out = r.start('p1', 0);
      expect(out.single.msg.data['code'], ErrCode.tooFewPlayers);
    });
  });

  group('Дүр тараах', () {
    test('дүр ЗӨВХӨН эзэнд нь, нэг хүнд нэг удаа', () {
      final GameRoom r = _roomWith(8);
      final List<Outbound> out = r.start('p1', 0);

      final List<Outbound> roleMsgs = out
          .where((Outbound o) => o.msg.type == S2C.yourRole)
          .toList();
      expect(roleMsgs.length, 8, reason: 'найман хүнд найман дүр');

      for (final Outbound o in roleMsgs) {
        expect(o.broadcast, isFalse, reason: 'дүр нийтэд явж БОЛОХГҮЙ');
        expect(o.recipients.length, 1, reason: 'дүр яг нэг хүнд');
      }
      // Хүн бүр яг нэг л дүрийн мессеж авсан.
      final Set<PlayerId> got =
          roleMsgs.expand((Outbound o) => o.recipients).toSet();
      expect(got.length, 8);
    });

    test('мафи хамтрагчийнхаа суудлыг мэднэ, хотынхон МЭДЭХГҮЙ', () {
      final GameRoom r = _roomWith(8);
      final List<Outbound> out = r.start('p1', 0);
      for (final Outbound o in out.where((Outbound o) =>
          o.msg.type == S2C.yourRole)) {
        final bool isMafia = o.msg.data['faction'] == 'mafi';
        final bool hasAllies = o.msg.data.containsKey('allySeats');
        expect(hasAllies, isMafia,
            reason: 'хамтрагчийн жагсаалт ЗӨВХӨН мафид очно');
      }
    });
  });

  group('ДҮР АЛДАГДАХГҮЙ — бүтэн тоглолт', () {
    test('нийтийн НЭГ Ч мессежид дүрийн нэр гарахгүй (дуустал)', () {
      final GameRoom r = _roomWith(8);
      final List<Outbound> everything = <Outbound>[];
      int t = 0;

      everything.addAll(r.start('p1', t));

      // Тоглолтыг дуустал явуулна. Үе шат бүрд бүх дүр үйлдлээ хийнэ.
      int guard = 0;
      while (r.phase != NetPhase.gameOver && guard++ < 300) {
        // Тухайн үе шатанд үйлдэх ёстой хүмүүс үйлднэ.
        for (final PublicPlayer p in r.players) {
          if (!p.alive) continue;
          final int? target = _firstOtherAliveSeat(r, p.seat);
          if (target == null) continue;
          if (r.phase == NetPhase.vote) {
            everything.addAll(r.vote(p.id, target));
          } else {
            everything.addAll(r.nightAction(p.id, target, t));
          }
        }
        t += 200000; // аль ч үе шатыг дуусгахад хангалттай
        everything.addAll(r.tick(t));
      }

      expect(r.phase, NetPhase.gameOver,
          reason: 'тоглолт дуусах ёстой, $guard давталтын дотор');
      expect(r.win, isNot(eng.WinState.none));

      // --- ГОЛ ШАЛГУУР ------------------------------------------------------
      // Тоглолт дуусахаас ӨМНӨХ бүх нийтийн мессежийг шалгана.
      // `gameOver` нь дүрийг ил гаргах ЦОРЫН ГАНЦ зөвшөөрөгдсөн мессеж.
      final List<Outbound> beforeEnd = everything
          .where((Outbound o) => o.msg.type != S2C.gameOver)
          .toList();
      final String text = _publicText(beforeEnd);

      for (final eng.Role role in eng.Role.values) {
        expect(text.contains(role.name), isFalse,
            reason: 'нийтийн мессежид «${role.name}» гэсэн үг олдлоо — '
                'дүр алдагдаж байна');
      }
      for (final String word in <String>['mafi', 'hotynhon', 'faction']) {
        expect(text.contains(word), isFalse,
            reason: 'нийтийн мессежид «$word» олдлоо');
      }
    });

    test('`gameOver` дээр л бүх дүр ил болно', () {
      final GameRoom r = _roomWith(6);
      int t = 0;
      r.start('p1', t);
      int guard = 0;
      List<Outbound> last = const <Outbound>[];
      while (r.phase != NetPhase.gameOver && guard++ < 300) {
        for (final PublicPlayer p in r.players) {
          if (!p.alive) continue;
          final int? target = _firstOtherAliveSeat(r, p.seat);
          if (target == null) continue;
          if (r.phase == NetPhase.vote) {
            r.vote(p.id, target);
          } else {
            r.nightAction(p.id, target, t);
          }
        }
        t += 200000;
        last = r.tick(t);
      }
      final Outbound over =
          last.firstWhere((Outbound o) => o.msg.type == S2C.gameOver);
      final Map<String, Object?> reveal =
          over.msg.data['reveal']! as Map<String, Object?>;
      expect(reveal.length, 6, reason: 'зургаан суудал бүгд ил болно');
    });
  });

  group('ДУУ — шөнө зөвхөн алуурчид сонсоно', () {
    test('мафийн үе шатанд дууны гишүүд ЗӨВХӨН мафи', () {
      final GameRoom r = _roomWith(8);
      int t = 0;
      r.start('p1', t);
      t += PhaseMs.dealing + 1;
      r.tick(t); // dealing → nightFalls
      t += PhaseMs.nightFalls + 1;
      r.tick(t); // nightFalls → nightMafia

      expect(r.phase, NetPhase.nightMafia);
      expect(r.voiceScope, VoiceScope.mafiaOnly);

      final Set<PlayerId> heard = r.voiceMembers;
      expect(heard, isNotEmpty);
      for (final PlayerId id in heard) {
        final eng.Role? role = r.debugRoleOf(id);
        expect(eng.factionOf(role!), eng.Faction.mafi,
            reason: 'мафийн сувагт «${role.name}» орчихлоо — '
                'бүх анги алуурчдыг сонсоно');
      }
      // Хотынхон НЭГ Ч ХҮН сувагт байхгүй.
      for (final PublicPlayer p in r.players) {
        if (eng.factionOf(r.debugRoleOf(p.id)!) == eng.Faction.hotynhon) {
          expect(heard.contains(p.id), isFalse);
        }
      }
    });

    test('өдөр бүгд сонсоно, шөнийн эхэн хэн ч сонсохгүй', () {
      final GameRoom r = _roomWith(8);
      int t = 0;
      r.start('p1', t);
      t += PhaseMs.dealing + 1;
      r.tick(t);
      expect(r.phase, NetPhase.nightFalls);
      expect(r.voiceScope, VoiceScope.none);
      expect(r.voiceMembers, isEmpty, reason: '«Хот унтлаа» — чимээгүй');

      // Шөнийг дуустал гүйлгэнэ.
      for (final int ms in <int>[
        PhaseMs.nightFalls,
        PhaseMs.mafia,
        PhaseMs.doctor,
        PhaseMs.detective,
        PhaseMs.dawn,
      ]) {
        t += ms + 1;
        r.tick(t);
      }
      expect(r.phase, NetPhase.day);
      expect(r.voiceScope, VoiceScope.everyone);
      expect(r.voiceMembers.length, r.players.where((PublicPlayer p) => p.alive).length);
    });

    test('үхсэн хүн өдрийн сувагт ОРОХГҮЙ', () {
      final GameRoom r = _roomWith(8);
      int t = 0;
      r.start('p1', t);
      t += PhaseMs.dealing + 1;
      r.tick(t);
      t += PhaseMs.nightFalls + 1;
      r.tick(t);
      // Мафи нэгийг онилно.
      final PlayerId mafia = r.players
          .firstWhere((PublicPlayer p) =>
              eng.factionOf(r.debugRoleOf(p.id)!) == eng.Faction.mafi)
          .id;
      final PublicPlayer victim = r.players.firstWhere((PublicPlayer p) =>
          eng.factionOf(r.debugRoleOf(p.id)!) == eng.Faction.hotynhon);
      r.nightAction(mafia, victim.seat!, t);

      for (final int ms in <int>[
        PhaseMs.mafia,
        PhaseMs.doctor,
        PhaseMs.detective,
        PhaseMs.dawn,
      ]) {
        t += ms + 1;
        r.tick(t);
      }
      expect(r.phase, NetPhase.day);
      // Эмч аварсан байж болзошгүй — зөвхөн үхсэн бол шалгана.
      final PublicPlayer after =
          r.players.firstWhere((PublicPlayer p) => p.id == victim.id);
      if (!after.alive) {
        expect(r.voiceMembers.contains(victim.id), isFalse,
            reason: 'үхсэн хүн өдрийн яриаг сонсож БОЛОХГҮЙ');
      }
    });
  });

  group('Үйлдлийн эрх', () {
    test('мафийн үе шатанд эмч үйлдэж ЧАДАХГҮЙ', () {
      final GameRoom r = _roomWith(8);
      int t = 0;
      r.start('p1', t);
      t += PhaseMs.dealing + 1;
      r.tick(t);
      t += PhaseMs.nightFalls + 1;
      r.tick(t);
      expect(r.phase, NetPhase.nightMafia);

      final PublicPlayer doc = r.players
          .firstWhere((PublicPlayer p) => r.debugRoleOf(p.id) == eng.Role.doctor);
      final List<Outbound> out = r.nightAction(doc.id, 1, t);
      expect(out.single.msg.data['code'], ErrCode.notYourTurn);
    });

    test('өрөөнд байхгүй хүн юу ч хийж чадахгүй', () {
      final GameRoom r = _roomWith(8);
      r.start('p1', 0);
      final List<Outbound> out = r.nightAction('stranger', 1, 0);
      expect(out.single.msg.data['code'], ErrCode.notYourTurn);
    });
  });

  group('Дахин холбогдох', () {
    test('тасарсан хүн эргэж орохад дүрээ дахин авна', () {
      final GameRoom r = _roomWith(8);
      r.start('p1', 0);
      r.leave('p4');
      expect(r.players.firstWhere((PublicPlayer p) => p.id == 'p4').connected,
          isFalse);
      expect(r.playerCount, 8, reason: 'тоглолт явж байхад суудал үлдэнэ');

      final List<Outbound> out = r.join('p4', 'Тоглогч4', 'punk_04');
      final Outbound role =
          out.firstWhere((Outbound o) => o.msg.type == S2C.yourRole);
      expect(role.recipients, <PlayerId>{'p4'});
      expect(role.broadcast, isFalse);
    });
  });

  group('Санал хураалт', () {
    test('тэнцвэл ХЭН Ч хөөгдөхгүй — апп санамсаргүй шийдэхгүй', () {
      final GameRoom r = _roomWith(8);
      int t = 0;
      r.start('p1', t);
      // Өдөр хүртэл гүйлгэнэ.
      for (final int ms in <int>[
        PhaseMs.dealing,
        PhaseMs.nightFalls,
        PhaseMs.mafia,
        PhaseMs.doctor,
        PhaseMs.detective,
        PhaseMs.dawn,
      ]) {
        t += ms + 1;
        r.tick(t);
      }
      if (r.phase != NetPhase.day) return; // тоглолт эрт дууссан бол алгасна
      t += PhaseMs.day + 1;
      r.tick(t);
      expect(r.phase, NetPhase.vote);

      final List<PublicPlayer> alive =
          r.players.where((PublicPlayer p) => p.alive).toList();
      // Яг хоёр хүн тус бүр нэг санал авна — тэнцэл.
      r.vote(alive[0].id, alive[2].seat);
      r.vote(alive[1].id, alive[3].seat);

      t += PhaseMs.vote + 1;
      final List<Outbound> out = r.tick(t);
      final Outbound e =
          out.firstWhere((Outbound o) => o.msg.type == 'eliminated');
      expect(e.msg.data['seat'], isNull, reason: 'тэнцвэл хэн ч хөөгдөхгүй');
    });
  });
}

/// Тухайн суудлаас ӨӨР, амьд суудлын дугаар.
int? _firstOtherAliveSeat(GameRoom r, int? mySeat) {
  for (final PublicPlayer p in r.players) {
    if (p.alive && p.seat != null && p.seat != mySeat) return p.seat;
  }
  return null;
}
