// Дохио (эмоци).
//
// ГУРВАН ЗҮЙЛ БАТЛАХ ЁСТОЙ:
//
//   1. ДОХИО ДҮРИЙГ ЗАДЛАХГҮЙ. Дохионы жагсаалт бүгдэд НЭГЭН АДИЛ
//      бөгөөд ботын дохио сонгох тархи дүрийг ОГТ уншдаггүй.
//
//   2. ШӨНӨ ДОХИО ЯВАХГҮЙ. Шөнө бүгд «унтсан» байх ёстой. Хэрэв тэр
//      үед дохио дамжвал «энэ хүн сэрүүн байна» гэдэг нь ил болж,
//      мафи хэн болох нь тэр дороо тодорно.
//
//   3. НЭГ ХҮН ШИРЭЭГ ЭЗЛЭХГҮЙ. Хязгааргүй бол секундэд зуун дохио
//      илгээж, бусдын дэлгэц дээр бүх толгой чичирнэ.

import 'dart:typed_data';

import 'package:engine/engine.dart' as eng;
import 'package:protocol/protocol.dart';
import 'package:server/server.dart';
import 'package:server/src/bot_brain.dart';
import 'package:test/test.dart';

Uint8List _seed(int n) =>
    Uint8List.fromList(List<int>.generate(32, (int i) => (i * 29 + n) & 0xFF));

/// Нэг хүн + ботууд, тоглолт эхэлсэн байдалтай.
GameRoom _room({int bots = 7, int seed = 3}) {
  final GameRoom r = GameRoom(code: 'EMOT', hostId: 'h', seed: _seed(seed));
  r.join('h', 'Хүчээ', 'punk_01');
  r.addBots('h', bots);
  r.start('h', 0);
  return r;
}

/// Өрөөг хүссэн үе шат хүртэл явуулж, ТЭР АГШНЫ цагийг буцаана.
///
/// Цагийг өрөөнөөс асуухгүй, ӨӨРӨӨ тоолно: сервер яг ингэж ажилладаг
/// (`tick(nowMs)`), тиймээс тест жинхэнэ урсгалтай ижил байна.
int _runTo(GameRoom r, NetPhase want, {int limitMs = 400000}) {
  for (int t = 250; t <= limitMs; t += 250) {
    r.tick(t);
    if (r.phase == want) return t;
  }
  fail('$want үе шат ирсэнгүй');
}

List<Envelope> _emotesIn(List<Outbound> out) => out
    .where((Outbound o) => o.broadcast && o.msg.type == S2C.emote)
    .map((Outbound o) => o.msg)
    .toList();

void main() {
  group('Дохионы жагсаалт', () {
    test('зургаан дохио, давхардалгүй', () {
      expect(Emote.all.length, 6);
      expect(Emote.all.toSet().length, 6);
    });

    test('жагсаалтад байхгүй нэрийг хүлээж авахгүй', () {
      expect(Emote.valid(Emote.point), isTrue);
      expect(Emote.valid('kill'), isFalse);
      expect(Emote.valid(''), isFalse);
      expect(Emote.valid('POINT'), isFalse);
    });
  });

  group('Өдөр', () {
    test('дохио БҮГДЭД очно', () {
      final GameRoom r = _room();
      final int t = _runTo(r, NetPhase.day);
      final List<Outbound> out = r.emote('h', Emote.laugh, null, t);
      expect(out.length, 1);
      expect(out.single.broadcast, isTrue, reason: 'бүгд нүдээрээ харна');
      expect(out.single.msg.type, S2C.emote);
      expect(out.single.msg.data['kind'], Emote.laugh);
      expect(out.single.msg.data['seat'], r.seatOf('h'));
      expect(out.single.msg.data['targetSeat'], isNull);
    });

    test('заалт нь бай авна', () {
      final GameRoom r = _room();
      final int t = _runTo(r, NetPhase.day);
      final int me = r.seatOf('h')!;
      final int other = r.players
          .map((PublicPlayer p) => p.seat!)
          .firstWhere((int s) => s != me);
      final List<Envelope> got =
          _emotesIn(r.emote('h', Emote.point, other, t));
      expect(got.single.data['targetSeat'], other);
    });

    test('заалтгүй дохионы бай ХАЯГДАНА', () {
      // «Толгой дохилоо, гэхдээ 4 руу» гэдэг нь нууц суваг болно.
      final GameRoom r = _room();
      final int t = _runTo(r, NetPhase.day);
      final int me = r.seatOf('h')!;
      final int other = r.players
          .map((PublicPlayer p) => p.seat!)
          .firstWhere((int s) => s != me);
      final List<Envelope> got =
          _emotesIn(r.emote('h', Emote.yes, other, t));
      expect(got.single.data['targetSeat'], isNull);
    });

    test('өөр рүүгээ заавал бай хоосон', () {
      final GameRoom r = _room();
      final int t = _runTo(r, NetPhase.day);
      final int me = r.seatOf('h')!;
      final List<Envelope> got =
          _emotesIn(r.emote('h', Emote.point, me, t));
      expect(got.single.data['targetSeat'], isNull);
    });

    test('байхгүй суудал руу заавал бай хоосон', () {
      final GameRoom r = _room();
      int t = _runTo(r, NetPhase.day);
      for (final int bad in <int>[0, -1, 99, 1 << 30]) {
        t += Emote.minGapMs;
        final List<Envelope> got =
            _emotesIn(r.emote('h', Emote.point, bad, t));
        expect(got.single.data['targetSeat'], isNull, reason: 'бай=$bad');
      }
    });

    test('танихгүй дохио ЧИМЭЭГҮЙ хаягдана', () {
      final GameRoom r = _room();
      final int t = _runTo(r, NetPhase.day);
      expect(r.emote('h', 'nuke', null, t), isEmpty);
    });
  });

  group('Шөнө — дохио ЯВАХГҮЙ', () {
    test('бүх шөнийн үе шатанд хаагдана', () {
      for (final NetPhase dark in <NetPhase>[
        NetPhase.nightFalls,
        NetPhase.nightMafia,
        NetPhase.nightDoctor,
        NetPhase.nightDetective,
      ]) {
        final GameRoom r = _room();
        final int t = _runTo(r, dark);
        expect(r.emote('h', Emote.hand, null, t), isEmpty,
            reason: '$dark үед дохио явж БОЛОХГҮЙ');
      }
    });

    test('лоббид дохио байхгүй', () {
      final GameRoom r = GameRoom(code: 'LOBB', hostId: 'h', seed: _seed(9));
      r.join('h', 'Хүчээ', 'punk_01');
      expect(r.emote('h', Emote.laugh, null, 1000), isEmpty);
    });
  });

  group('Хурдны хязгаар', () {
    test('завсар дүүрэхээс өмнөх дохио хаягдана', () {
      final GameRoom r = _room();
      final int t = _runTo(r, NetPhase.day);
      expect(_emotesIn(r.emote('h', Emote.yes, null, t)).length, 1);
      expect(r.emote('h', Emote.no, null, t + Emote.minGapMs - 1), isEmpty);
      expect(
          _emotesIn(r.emote('h', Emote.no, null, t + Emote.minGapMs)).length, 1);
    });

    test('хаягдсан дохио цагийг УРАГШЛУУЛАХГҮЙ', () {
      // Эс бөгөөс тасралтгүй спам нь хязгаарыг мөнхөд хойшлуулна.
      final GameRoom r = _room();
      final int t = _runTo(r, NetPhase.day);
      r.emote('h', Emote.yes, null, t);
      for (int k = 1; k < Emote.minGapMs; k += 100) {
        r.emote('h', Emote.no, null, t + k);
      }
      expect(
          _emotesIn(r.emote('h', Emote.no, null, t + Emote.minGapMs)).length, 1);
    });
  });

  group('Үхсэн хүн', () {
    test('дохио гаргахгүй', () {
      final GameRoom r = _room();
      // Тоглолтыг хэн нэгэн үхэх хүртэл явуулна.
      PlayerId? dead;
      for (int t = 250; t <= 400000 && dead == null; t += 250) {
        r.tick(t);
        for (final PublicPlayer p in r.players) {
          if (!p.alive) dead = p.id;
        }
      }
      expect(dead, isNotNull, reason: 'хэн ч үхсэнгүй — тест утгагүй');
      final int t = _runTo(r, NetPhase.day, limitMs: 900000);
      expect(r.emote(dead!, Emote.hand, null, t), isEmpty);
    });
  });

  group('Ботын дохио ДҮРЭЭС ХАМААРАХГҮЙ', () {
    test('ижил харагдацад дүр солиход хариу ӨӨРЧЛӨГДӨХГҮЙ', () {
      // Хамгийн хүчтэй баталгаа: дүрийг л сольж, бусад бүх оролт ижил
      // үед гаралт ЯГ ИЖИЛ байх ёстой. Хэрэв хожим хэн нэгэн
      // `decideEmote` дотор `v.myRole`-ыг уншвал энэ тест унана.
      const List<eng.Role> roles = <eng.Role>[
        eng.Role.killer,
        eng.Role.doctor,
        eng.Role.detective,
        eng.Role.citizen,
      ];
      for (final NetPhase ph in <NetPhase>[NetPhase.day, NetPhase.vote]) {
        for (int trial = 0; trial < 40; trial++) {
          String? first;
          for (final eng.Role role in roles) {
            final BotView v = BotView(
              mySeat: 3,
              myRole: role,
              phase: ph,
              aliveSeats: const <int>[1, 2, 3, 4, 5, 6],
              myAllies: role == eng.Role.killer ? const <int>{5} : const <int>{},
              allyPicks: const <int, int>{},
              liveVotes: const <int, int>{},
              mem: BotMemory(),
            );
            final BotEmote? e = decideEmote(v, eng.Rng(_seed(trial)));
            final String sig = '${e?.kind}/${e?.targetSeat}';
            first ??= sig;
            expect(sig, first, reason: '$ph дүр=$role туршилт=$trial');
          }
        }
      }
    });

    test('хамтрагч руугаа ч заана', () {
      // Хэрэв мафи бот хамтрагч руугаа ХЭЗЭЭ Ч заахгүй бол хэдэн өдрийн
      // дараа «бие бие рүүгээ заадаггүй хоёр» гэж мафи ялгарна.
      bool pointedAtAlly = false;
      for (int trial = 0; trial < 300 && !pointedAtAlly; trial++) {
        final BotView v = BotView(
          mySeat: 1,
          myRole: eng.Role.killer,
          phase: NetPhase.day,
          aliveSeats: const <int>[1, 2, 3],
          myAllies: const <int>{2},
          allyPicks: const <int, int>{},
          liveVotes: const <int, int>{},
          mem: BotMemory(),
        );
        final BotEmote? e = decideEmote(v, eng.Rng(_seed(trial)));
        if (e?.kind == Emote.point && e?.targetSeat == 2) {
          pointedAtAlly = true;
        }
      }
      expect(pointedAtAlly, isTrue);
    });

    test('өөр рүүгээ заахгүй', () {
      for (int trial = 0; trial < 200; trial++) {
        final BotView v = BotView(
          mySeat: 4,
          myRole: eng.Role.citizen,
          phase: NetPhase.vote,
          aliveSeats: const <int>[1, 2, 3, 4],
          myAllies: const <int>{},
          allyPicks: const <int, int>{},
          liveVotes: const <int, int>{},
          mem: BotMemory(),
        );
        final BotEmote? e = decideEmote(v, eng.Rng(_seed(trial)));
        expect(e?.targetSeat, isNot(4));
      }
    });

    test('шөнө дохио сонгохгүй', () {
      for (final NetPhase dark in <NetPhase>[
        NetPhase.nightFalls,
        NetPhase.nightMafia,
        NetPhase.nightDoctor,
        NetPhase.nightDetective,
        NetPhase.lobby,
        NetPhase.gameOver,
      ]) {
        final BotView v = BotView(
          mySeat: 1,
          myRole: eng.Role.killer,
          phase: dark,
          aliveSeats: const <int>[1, 2, 3],
          myAllies: const <int>{},
          allyPicks: const <int, int>{},
          liveVotes: const <int, int>{},
          mem: BotMemory(),
        );
        expect(decideEmote(v, eng.Rng(_seed(1))), isNull, reason: '$dark');
      }
    });

    test('үхсэн бот дохихгүй', () {
      final BotView v = BotView(
        mySeat: 9,
        myRole: eng.Role.citizen,
        phase: NetPhase.day,
        aliveSeats: const <int>[1, 2, 3],
        myAllies: const <int>{},
        allyPicks: const <int, int>{},
        liveVotes: const <int, int>{},
        mem: BotMemory(),
      );
      expect(decideEmote(v, eng.Rng(_seed(2))), isNull);
    });
  });

  group('Бүтэн тоглолт', () {
    test('ботууд үнэхээр дохино, шөнө нэг ч дохио гарахгүй', () {
      final GameRoom r = _room(bots: 7, seed: 11);
      int day = 0;
      int night = 0;
      for (int t = 250; t <= 900000; t += 250) {
        final bool dark = r.phase == NetPhase.nightFalls ||
            r.phase == NetPhase.nightMafia ||
            r.phase == NetPhase.nightDoctor ||
            r.phase == NetPhase.nightDetective;
        final int got = _emotesIn(r.tick(t)).length;
        if (dark) {
          night += got;
        } else {
          day += got;
        }
        if (r.phase == NetPhase.gameOver) break;
      }
      expect(night, 0, reason: 'шөнө дохио гарвал сэрүүн хүн ил болно');
      expect(day, greaterThan(5), reason: 'ширээ амьгүй байна');
    });
  });
}
