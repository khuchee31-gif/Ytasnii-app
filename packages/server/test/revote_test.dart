// ТЭНЦЭЛ → ДАХИН САНАЛ.
//
// Өмнө нь тэнцвэл хэн ч хасагдахгүй байв. Тэр нь зөв дүрэм боловч
// ширээнд «юу ч болсонгүй» гэсэн хоосон мэдрэмж үлдээдэг. Нэг удаа
// дахин санал авбал хоёр нэрийн хооронд ХУРЦ маргаан үүснэ.
//
// ХОЁР ДАХЬ ТЭНЦЭЛД хэн ч хасагдахгүй — эс бөгөөс өдөр мөнхөрнө.

import 'dart:typed_data';

import 'package:protocol/protocol.dart';
import 'package:server/server.dart';
import 'package:test/test.dart';

Uint8List _seed(int n) =>
    Uint8List.fromList(List<int>.generate(32, (int i) => (i * 83 + n) & 0xFF));

GameRoom _table(String code, {int n = 8, int seed = 1}) {
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

/// Санал хураалтыг ХАСАЛТЫН МЕССЕЖ гартал нь гүйлгэнэ.
///
/// Үе шатаар зогсоож БОЛОХГҮЙ: тэнцвэл сервер дахин `vote` руу ордог
/// тул «үе шат солигдтол» гэсэн нөхцөл нь ХОЁР санал хураалтыг нэг
/// болгож нийлүүлээд, дүн нь алга болно.
({int t, List<Outbound> out}) _finishVote(GameRoom r, int t) {
  final List<Outbound> out = <Outbound>[];
  while (t < 900000) {
    t += 250;
    final List<Outbound> step = r.tick(t);
    out.addAll(step);
    if (step.any((Outbound o) => o.msg.type == S2C.eliminated)) break;
  }
  return (t: t, out: out);
}

/// АМЬД хүмүүсийг хоёр АМЬД нэр рүү ТЭНЦҮҮ хуваана.
///
/// Сонгосон хоёр нэр нь саналлагчдын дунд ч байж болно — өөрийгөө
/// өгөх нь хориотой биш. Сонгогчийн тоо сондгой бол нэг нь ТАТГАЛЗАНА
/// (санал өгөхгүй), эс бөгөөс тэнцэл гарахгүй.
({int a, int b}) _splitTie(GameRoom r) {
  final List<PublicPlayer> alive =
      r.players.where((PublicPlayer p) => p.alive).toList();
  final int a = alive[0].seat!;
  final int b = alive[1].seat!;
  final int pairs = alive.length ~/ 2;
  for (int i = 0; i < pairs * 2; i++) {
    r.vote(alive[i].id, i < pairs ? a : b);
  }
  return (a: a, b: b);
}

Envelope? _lastElim(List<Outbound> out) {
  Envelope? got;
  for (final Outbound o in out) {
    if (o.msg.type == S2C.eliminated) got = o.msg;
  }
  return got;
}

void main() {
  test('тэнцвэл ДАХИН САНАЛ болно', () {
    final GameRoom r = _table('RV1');
    int t = _runTo(r, NetPhase.vote, 0);
    final ({int a, int b}) tie = _splitTie(r);
    final ({int t, List<Outbound> out}) a = _finishVote(r, t);
    t = a.t;

    final Envelope elim = _lastElim(a.out)!;
    expect(elim.data['seat'], isNull);
    expect(elim.data['revote'], <int>[tie.a, tie.b]..sort());
    expect(r.phase, NetPhase.vote, reason: 'дахин санал эхлээгүй');
    expect(r.revoteSeats, <int>[tie.a, tie.b]..sort());
  });

  test('дахин саналд ЗӨВХӨН тэнцсэн нэрсээс сонгоно', () {
    final GameRoom r = _table('RV2', seed: 2);
    int t = _runTo(r, NetPhase.vote, 0);
    final ({int a, int b}) tie = _splitTie(r);
    t = _finishVote(r, t).t;

    final int outsider = r.players
        .where((PublicPlayer p) => p.alive)
        .map((PublicPlayer p) => p.seat!)
        .firstWhere((int x) => x != tie.a && x != tie.b);
    final PlayerId voter = r.players.firstWhere((PublicPlayer p) => p.alive).id;
    expect(r.vote(voter, outsider).single.msg.data['code'],
        ErrCode.invalidTarget,
        reason: 'тэнцээгүй нэр рүү санал явлаа');
    expect(r.vote(voter, tie.a).single.msg.type, S2C.voteState);
  });

  test('дахин саналаар ШИЙДВЭР гарна', () {
    final GameRoom r = _table('RV3', seed: 3);
    int t = _runTo(r, NetPhase.vote, 0);
    final ({int a, int b}) tie = _splitTie(r);
    t = _finishVote(r, t).t;

    // Одоо бүгд эхнийх рүү.
    for (final PublicPlayer p in r.players.where((PublicPlayer p) => p.alive)) {
      r.vote(p.id, tie.a);
    }
    final ({int t, List<Outbound> out}) b = _finishVote(r, t);
    expect(_lastElim(b.out)!.data['seat'], tie.a);
    expect(r.players.firstWhere((PublicPlayer p) => p.seat == tie.a).alive,
        isFalse);
    expect(r.revoteSeats, isEmpty);
  });

  test('ХОЁР ДАХЬ тэнцэлд хэн ч хасагдахгүй', () {
    final GameRoom r = _table('RV4', seed: 4);
    int t = _runTo(r, NetPhase.vote, 0);
    final int before =
        r.players.where((PublicPlayer p) => !p.alive).length;
    _splitTie(r);
    t = _finishVote(r, t).t;
    _splitTie(r);                       // дахин тэнцүүлнэ
    final ({int t, List<Outbound> out}) b = _finishVote(r, t);
    expect(_lastElim(b.out)!.data['seat'], isNull);
    expect(_lastElim(b.out)!.data['revote'], isNull,
        reason: 'хоёр дахь дахин санал болов — өдөр мөнхөрнө');
    expect(r.phase, NetPhase.elimination);
    expect(r.players.where((PublicPlayer p) => !p.alive).length, before);
  });

  test('шинэ өдөр эхлэхэд дахин саналын жагсаалт ЦЭВЭРЛЭГДЭНЭ', () {
    final GameRoom r = _table('RV5', seed: 5);
    int t = _runTo(r, NetPhase.vote, 0);
    _splitTie(r);
    t = _finishVote(r, t).t;
    expect(r.revoteSeats, isNotEmpty);
    // Хоёр дахь тэнцэл → хэн ч хасагдахгүй → шөнө → дараагийн өдөр.
    _splitTie(r);
    t = _finishVote(r, t).t;
    t = _runTo(r, NetPhase.vote, t);
    expect(r.revoteSeats, isEmpty);
    final List<PublicPlayer> live =
        r.players.where((PublicPlayer p) => p.alive).toList();
    expect(r.vote(live.first.id, live.last.seat!).single.msg.type,
        S2C.voteState,
        reason: 'шинэ өдөр чөлөөт санал байх ёстой');
  });

  test('ботууд дахин саналд ЗӨВ сонгоно', () {
    final GameRoom r = GameRoom(code: 'RVB', hostId: 'h', seed: _seed(9));
    r.join('h', 'Хүчээ', 'punk_01');
    r.addBots('h', 7);
    r.start('h', 0);
    int bad = 0;
    for (int t = 250; t <= 900000; t += 250) {
      for (final Outbound o in r.tick(t)) {
        if (o.msg.type == S2C.error &&
            o.msg.data['code'] == ErrCode.invalidTarget) {
          bad++;
        }
      }
      if (r.phase == NetPhase.gameOver) break;
    }
    expect(r.phase, NetPhase.gameOver);
    expect(bad, 0, reason: 'бот тэнцээгүй нэр рүү санал өглөө');
  });
}
