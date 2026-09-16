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

/// Нийтийн мессежийн бүх текстийг нэг мөр болгож, ЖИЖИГ ҮСГЭЭР буцаана.
///
/// ЖИЖИГ ҮСЭГ ЯАГААД ЧУХАЛ ВЭ: өмнө нь том жижгээр нь шалгадаг байсан
/// тул `"detective"` гэсэн ямар ч ЖИЖИГ үсэгтэй алдагдал баригдах ч,
/// `"Detective"` гэж бичигдсэн бол чимээгүй өнгөрөх байв. Шалгалт нь
/// бичих хэлбэрээс хамаарч болохгүй.
///
/// ҮЕ ШАТНЫ НЭРИЙГ ХАСНА. `{"phase":"nightDoctor"}` нь бүх дэлгэц рүү
/// зориудаар явдаг бөгөөд тэр нь ямар ч ТОГЛОГЧИЙН дүрийг хэлэхгүй:
/// үе шатууд хэн амьд байхаас үл хамааран ижил дараалал, ижил уртаар
/// явдаг (`_fillMissingIntents` яг үүний төлөө оршино). Тэднийг тусад
/// нь, ЦАГААН ЖАГСААЛТААР шалгана.
String _publicText(List<Outbound> out) {
  final StringBuffer b = StringBuffer();
  for (final Outbound o in out) {
    if (!o.broadcast) continue;
    b.write(o.msg.encode().replaceAll(
        RegExp(r'"phase":"[A-Za-z]*"'), '"phase":"_"'));
    b.write('\n');
  }
  return b.toString().toLowerCase();
}

/// Нийтэд явсан БҮХ үе шатны нэр.
Set<String> _publicPhases(List<Outbound> out) {
  final Set<String> got = <String>{};
  for (final Outbound o in out) {
    if (!o.broadcast) continue;
    final Object? p = o.msg.data['phase'];
    if (p is String) got.add(p);
  }
  return got;
}

void main() {
  group('Өрөөнд орох', () {
    test('орсон хүн бүр нийтийн төлөвт гарна', () {
      final GameRoom r = _roomWith(3);
      expect(r.playerCount, 3);
      expect(r.players.map((PublicPlayer p) => p.name),
          containsAll(<String>['Тоглогч1', 'Тоглогч2', 'Тоглогч3']));
    });

    test('ижил нэр дугаарлагдана', () {
      // ТАТГАЛЗДАГ БАЙСАН. Одоо дугаарлана: татгалзал нь санаатай хүнийг
      // зогсоохгүй (тэр латин үсэг сольж дахин оролдоно), зөвхөн шударга
      // хүнд дахин бичүүлж цаг алдуулна.
      final GameRoom r = GameRoom(code: 'AAAA', hostId: 'a', seed: _seed(1));
      r.join('a', 'Бат', 'x');
      final List<Outbound> out = r.join('b', 'Бат', 'y');
      expect(out.any((Outbound o) => o.msg.type == S2C.error), isFalse);
      expect(r.playerCount, 2);
      expect(r.players.map((PublicPlayer p) => p.name),
          <String>['Бат', 'Бат 2']);
    });

    test('хоосон нэрээр орохгүй', () {
      final GameRoom r = GameRoom(code: 'AAAA', hostId: 'a', seed: _seed(1));
      final List<Outbound> out = r.join('a', '', 'x');
      expect(out.single.msg.data['code'], ErrCode.nameRequired);
      expect(r.playerCount, 0);
    });

    test('хоёр хоосон нэр хоёулаа ОЙЛГОМЖТОЙ татгалзана', () {
      // Энэ бол хэрэглэгчийн бодитоор тулгарсан алдаа: нэрээ бичээгүй
      // хоёр хүн хоёулаа «Зочин» болж, хоёр дахь нь өөрийн бичээгүй
      // нэр «давхардлаа» гэсэн мессеж авдаг байв.
      final GameRoom r = GameRoom(code: 'AAAA', hostId: 'a', seed: _seed(1));
      for (final String id in <String>['a', 'b']) {
        final List<Outbound> out = r.join(id, '   ', 'x');
        expect(out.single.msg.data['code'], ErrCode.nameRequired);
        expect(out.single.msg.data['code'], isNot(ErrCode.nameTaken));
      }
      expect(r.playerCount, 0);
    });

    test('үл үзэгдэх тэмдэгтээр хуурч чадахгүй', () {
      final GameRoom r = GameRoom(code: 'AAAA', hostId: 'a', seed: _seed(1));
      r.join('a', 'Бат', 'x');
      r.join('b', 'Бат\u200B', 'y');
      expect(r.players.map((PublicPlayer p) => p.name),
          <String>['Бат', 'Бат 2']);
    });

    test('латин үсгээр хуурч чадахгүй', () {
      final GameRoom r = GameRoom(code: 'AAAA', hostId: 'a', seed: _seed(1));
      r.join('a', 'Хулан', 'x');
      r.join('b', '\u0058улан', 'y');
      expect(r.players.last.name, '\u0058улан 2');
    });

    test('том жижиг үсгээр хуурч чадахгүй', () {
      final GameRoom r = GameRoom(code: 'AAAA', hostId: 'a', seed: _seed(1));
      r.join('a', 'Болд', 'x');
      r.join('b', 'болд', 'y');
      expect(r.players.last.name, 'болд 2');
    });

    test('лоббид нэрээ засаж болно', () {
      final GameRoom r = GameRoom(code: 'AAAA', hostId: 'a', seed: _seed(1));
      r.join('a', 'Бат', 'x');
      r.join('a', 'Болд', 'x');
      expect(r.playerCount, 1);
      expect(r.players.single.name, 'Болд');
    });

    test('нэрээ засахдаа бусадтай мөргөлдөхгүй', () {
      final GameRoom r = GameRoom(code: 'AAAA', hostId: 'a', seed: _seed(1));
      r.join('a', 'Бат', 'x');
      r.join('b', 'Болд', 'y');
      r.join('b', 'Бат', 'y');
      expect(r.players.last.name, 'Бат 2');
    });

    test('тоглолт эхэлсний дараа нэр ХӨЛДӨНӨ', () {
      // Эс бөгөөс үхсэн Батын дараа мафи «Бат» болж, өдрийн яриа
      // утгагүй болно.
      final GameRoom r = _roomWith(6);
      r.start('p1', 0);
      final String before = r.players[2].name;
      r.join('p3', 'ӨӨРСӨН', 'x');
      expect(r.players[2].name, before);
      expect(r.playerCount, 6);
    });

    test('ширээн дээр ижил харагдах хоёр нэр ХЭЗЭЭ Ч байхгүй', () {
      final GameRoom r = GameRoom(code: 'AAAA', hostId: 'a', seed: _seed(1));
      const List<String> tries = <String>[
        'Бат', 'бат', 'БАТ', 'Бат ', 'Бат\u200B', '\u0412ат', 'Болд',
      ];
      for (int i = 0; i < tries.length; i++) {
        r.join('u$i', tries[i], 'x');
      }
      final Set<String> keys =
          r.players.map((PublicPlayer p) => nameKey(p.name)).toSet();
      expect(keys.length, r.playerCount);
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

  group('Бот нэмэх', () {
    GameRoom solo() =>
        GameRoom(code: 'BOTS', hostId: 'h', seed: _seed(9))..join('h', 'Хүчээ', 'x');

    test('эзэн биш хүн бот нэмж чадахгүй', () {
      final GameRoom r = solo()..join('b', 'Болд', 'y');
      final List<Outbound> out = r.addBots('b', 3);
      expect(out.single.msg.data['code'], ErrCode.notHost);
    });

    test('тоглолт эхэлсний дараа бот нэмэхгүй', () {
      final GameRoom r = _roomWith(6);
      r.start('p1', 0);
      final List<Outbound> out = r.addBots('p1', 1);
      expect(out.single.msg.data['code'], ErrCode.gameInProgress);
    });

    test('багтаамжаас хэтрэхгүй', () {
      final GameRoom r = solo();
      r.addBots('h', 1000);
      expect(r.playerCount, kMaxPlayers);
    });

    test('бот бүр тэмдэглэгдэж, бэлэн болно', () {
      final GameRoom r = solo();
      r.addBots('h', 5);
      final List<PublicPlayer> bots =
          r.players.where((PublicPlayer p) => p.isBot).toList();
      expect(bots.length, 5);
      expect(bots.every((PublicPlayer p) => p.ready), isTrue);
      expect(r.humanCount, 1);
      // Ботууд ӨӨР ӨӨР дугаартай — нэг дугаар давхардвал хоёр дахь нь
      // эхнийхийнх нь «дахин холбогдолт» гэж тооцогдоно.
      expect(bots.map((PublicPlayer p) => p.id).toSet().length, 5);
    });

    test('хүн ботын нэрийг авч чадахгүй', () {
      final GameRoom r = solo();
      final List<Outbound> out = r.join('x', 'Бот 1', 'z');
      expect(out.single.msg.data['code'], ErrCode.nameReserved);
      r.addBots('h', 1);
      expect(r.players.last.name, 'Бот 1');
    });

    test('сүүлчийн ботыг хасна, хүнийг ХЭЗЭЭ Ч хасахгүй', () {
      final GameRoom r = solo();
      r.addBots('h', 3);
      r.removeBot('h');
      expect(r.playerCount, 3);
      expect(r.humanCount, 1);
      expect(r.removeBot('b').single.msg.data['code'], ErrCode.notHost);
    });

    test('ЭЗЭН ХЭЗЭЭ Ч БОТ БОЛОХГҮЙ', () {
      // Ботод сокет байхгүй тул эзэн бот болбол `startGame` илгээх хүн
      // үлдэхгүй, өрөө үүрд лоббид гацна.
      final GameRoom r = solo();
      r.addBots('h', 5);
      r.leave('h');
      expect(r.isBot(r.hostId), isFalse);
      r.join('h2', 'Болд', 'y');
      expect(r.hostId, 'h2');
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

      // Үе шатны нэр нь ЦАГААН ЖАГСААЛТААС гарна. Шинэ үе шат нэмэх нь
      // энэ тестийг унагана — тэгээд хүн «энэ нэр юу зарлаж байна?» гэж
      // бодох ёстой болно.
      expect(_publicPhases(beforeEnd).difference(<String>{
        'dealing',
        'nightFalls',
        'nightMafia',
        'nightDoctor',
        'nightDetective',
        'dawn',
        'day',
        'vote',
        'elimination',
      }), isEmpty);
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
