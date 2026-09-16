// Хиймэл тоглогчид.
//
// ХОЁР ЗҮЙЛ БАТЛАХ ЁСТОЙ:
//
//   1. БОТ ХУУРЧ БОЛОХГҮЙ. Сервер бүх дүрийг мэддэг. Хэрэв ботын тархи
//      тэр рүү хүрч чадвал бот үргэлж ялж, туршилтын хэрэгсэл болохоо
//      болино. Түүнээс ч муу нь — хүнтэй хамт тоглоход илрүүлэх аргагүй
//      хууралт болно.
//
//   2. ТОГЛОЛТ ҮНЭХЭЭР ДУУСАХ ЁСТОЙ. Ганцаараа туршиж байгаа хүн
//      эцсийг нь харах ёстой. Санамсаргүй санал өгдөг ботууд өдөр бүр
//      тэнцэж, хэн ч хасагдахгүй, тоглоом мөнхөрнө.

import 'dart:io';
import 'dart:typed_data';

import 'package:engine/engine.dart' as eng;
import 'package:protocol/protocol.dart';
import 'package:server/server.dart';
import 'package:server/src/bot_brain.dart';
import 'package:test/test.dart';

Uint8List _seed(int n) =>
    Uint8List.fromList(List<int>.generate(32, (int i) => (i * 37 + n) & 0xFF));

/// Нэг хүн + ботууд.
GameRoom _solo(int bots, {int seed = 5}) {
  final GameRoom r = GameRoom(code: 'SOLO', hostId: 'h', seed: _seed(seed));
  r.join('h', 'Хүчээ', 'punk_01');
  r.addBots('h', bots);
  return r;
}

/// Тоглолтыг 250 мс-ийн алхмаар (серверийн жинхэнэ алхам) гүйцэд явуулна.
List<Envelope> _playOut(GameRoom r, {int limitMs = 900000}) {
  final List<Envelope> broadcasts = <Envelope>[];
  void take(List<Outbound> out) {
    for (final Outbound o in out) {
      if (o.broadcast) broadcasts.add(o.msg);
    }
  }

  take(r.start('h', 0));
  for (int t = 250; t <= limitMs; t += 250) {
    take(r.tick(t));
    if (r.phase == NetPhase.gameOver) break;
  }
  return broadcasts;
}

void main() {
  group('Бот хуурч чадахгүй', () {
    test('ботын тархи ӨРӨӨГ хардаггүй', () {
      // ЭХ КОДЫН шалгалт. Хэн нэгэн хожим өрөөг тархи руу оруулбал энэ
      // тест тэр дор нь унана — дараагийн `dart test` дээр.
      //
      // ЗӨВХӨН КОД дээр шалгана: тайлбар дотор «GameRoom» гэж бичих нь
      // зөв (яг энэ файлын толгойд тэгж бичсэн). Хориотой нь түүн рүү
      // ХАНДАХ явдал.
      final String src = File('lib/src/bot_brain.dart')
          .readAsLinesSync()
          .map((String l) {
            final int i = l.indexOf('//');
            return i < 0 ? l : l.substring(0, i);
          })
          .join('\n');
      for (final String banned in <String>[
        'GameRoom',
        '_secrets',
        'debugRoleOf',
        'Map<Seat, Role>',
        'dart:io',
        'DateTime.',
        'Random(',
      ]) {
        expect(src.contains(banned), isFalse,
            reason: 'bot_brain.dart дотор «$banned» байна — '
                'тархи зөвхөн BotView-ээс уншина');
      }
    });

    test('ботын харагдацад ӨӨРИЙНХӨӨС өөр дүр БАЙХГҮЙ', () {
      final GameRoom r = _solo(7);
      r.start('h', 0);
      // Шөнө мафийн үе хүртэл аваачна — тэр үед мафийн санаа `_intents`
      // дотор аль хэдийн сууж эхэлдэг.
      for (int t = 250; t <= 120000; t += 250) {
        r.tick(t);
        if (r.phase == NetPhase.nightDoctor) break;
      }

      for (final PlayerId id in r.debugBotIds) {
        final BotView v = r.debugBotView(id);
        expect(v.myRole, r.debugRoleOf(id), reason: '$id өөрийн дүр');

        final bool mafi = eng.factionOf(v.myRole) == eng.Faction.mafi;
        if (!mafi) {
          expect(v.myAllies, isEmpty,
              reason: '$id мафи биш атлаа хамтрагчтай');
          expect(v.allyPicks, isEmpty,
              reason: '$id мафи биш атлаа мафийн сонголтыг харж байна');
        }
      }
    });

    test('ботууд ӨӨР ӨӨР санамсаргүй урсгалтай', () {
      // Нэг урсгалтай байсан бол бүгд ижил сонголт хийж, мафи хэзээ ч
      // хуваагдахгүй, эмч үргэлж алуурчны барихыг эмчлэх байв.
      final GameRoom r = _solo(7);
      expect(r.debugBotIds.toSet().length, 7);
    });
  });

  group('Ботон тоглолт', () {
    test('бүтэн тоглолт ДУУСНА', () {
      final GameRoom r = _solo(7);
      final List<Envelope> out = _playOut(r);
      expect(r.phase, NetPhase.gameOver, reason: 'тоглолт дуусаагүй');
      expect(r.win, isNot(eng.WinState.none));

      // Санал хураалт ҮНЭХЭЭР хэн нэгнийг хасаж байгаа эсэх. Санамсаргүй
      // ботууд бол өдөр бүр тэнцэж, энэ шалгуур унана.
      final bool anyEliminated = out.any((Envelope e) =>
          e.type == S2C.eliminated && e.data['seat'] != null);
      expect(anyEliminated, isTrue,
          reason: 'өдөр хэнийг ч хасаагүй — ботууд нэг хүн рүү нийлээгүй');
    });

    test('ЯГ давтагдана', () {
      String run(int seed) {
        final GameRoom r = _solo(7, seed: seed);
        return _playOut(r).map((Envelope e) => e.encode()).join('\n');
      }

      expect(run(5), run(5), reason: 'ижил үр ижил тоглолт өгөх ёстой');
      expect(run(5), isNot(run(6)), reason: 'өөр үр өөр тоглолт');
    });

    test('ботон тоглолтын нийтийн мессежид ДҮР ГАРАХГҮЙ', () {
      final GameRoom r = _solo(7);
      final List<Envelope> out = _playOut(r);
      final StringBuffer b = StringBuffer();
      for (final Envelope e in out) {
        // Тоглолт дуусахад дүр ил болох нь ЗӨВ — түүнийг алгасна.
        if (e.type == S2C.gameOver) continue;
        b.write(e.encode());
        b.write('\n');
      }
      final String text = b.toString();
      for (final eng.Role role in eng.Role.values) {
        expect(text.contains(role.name), isFalse,
            reason: 'нийтийн мессежид «${role.name}» гарчээ');
      }
      for (final String word in <String>['mafi', 'hotynhon', 'faction']) {
        expect(text.contains(word), isFalse, reason: '«$word» гарчээ');
      }
    });

    test('мафи ботууд НЭГ хүн рүү нийлнэ', () {
      // Хоёр мафитай ширээ (8 суудал). Тус тусдаа санал өгвөл хөдөлгүүр
      // тэнцлийг дарааллын сэлгэцээр тайлж, шөнө санамсаргүй харагдана.
      final GameRoom r = _solo(7);
      r.start('h', 0);
      for (int t = 250; t <= 120000; t += 250) {
        r.tick(t);
        if (r.phase == NetPhase.nightDoctor) break;
      }
      final Set<int> targets = <int>{};
      for (final PlayerId id in r.debugBotIds) {
        final BotView v = r.debugBotView(id);
        if (eng.factionOf(v.myRole) != eng.Faction.mafi) continue;
        targets.addAll(v.allyPicks.values);
      }
      expect(targets.length, lessThanOrEqualTo(1),
          reason: 'мафи ботууд өөр өөр хүн рүү чиглэжээ: $targets');
    });
  });

  group('Ботын хурд', () {
    test('үе шат богиносно, гэхдээ БҮГД ижил хуваарьтай', () {
      final GameRoom bots = _solo(7);
      final GameRoom humans =
          GameRoom(code: 'HUMA', hostId: 'p1', seed: _seed(5));
      for (int i = 1; i <= 8; i++) {
        humans.join('p$i', 'Тоглогч$i', 'punk_01');
      }

      int firstMs(List<Outbound> out) {
        for (final Outbound o in out) {
          if (o.msg.type == S2C.phase) return o.msg.data['endsInMs']! as int;
        }
        return -1;
      }

      final int botMs = firstMs(bots.start('h', 0));
      final int humanMs = firstMs(humans.start('p1', 0));
      expect(botMs, lessThan(humanMs), reason: 'ботон өрөө хурдан байх ёстой');
      expect(humanMs, PhaseMs.dealing, reason: 'хүний өрөө хөндөгдөөгүй');
    });
  });
}
