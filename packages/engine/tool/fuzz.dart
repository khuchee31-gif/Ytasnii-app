// Хаалганы fuzz — GDD-05 §10.3.
//
// `dart test` дотор 2,000 seed ажиллана (PR бүрд, < 10 сек). Энэ хэрэгсэл нь
// **200,000 seed** ажиллуулна (~3 минут), хаалга бүрийн ӨМНӨ нэг удаа.
//
//   dart run tool/fuzz.dart              # 200,000
//   FUZZ_SEEDS=5000 dart run tool/fuzz.dart
//
// Энэ файл `tool/`-д байгаа тул `dart:io` ашиглаж БОЛНО. `lib/` хэзээ ч болохгүй.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:engine/src/hash.dart';
import 'package:engine/src/invariants.dart';
import 'package:engine/src/model.dart';
import 'package:engine/src/resolve.dart';
import 'package:engine/src/rng.dart';
import 'package:engine/src/rosters.dart';
import 'package:engine/src/validate.dart';

void main(List<String> args) {
  final int seeds =
      int.tryParse(Platform.environment['FUZZ_SEEDS'] ?? '') ?? 200000;

  var nights = 0;
  var games = 0;
  final List<String> broken = <String>[];

  for (var seed = 0; seed < seeds; seed++) {
    try {
      nights += _playGame(seed);
      games++;
    } on InvariantViolation catch (e) {
      broken.add('seed $seed: ${e.id} — ${e.detail}');
      if (broken.length >= 20) break;
    } catch (e) {
      broken.add('seed $seed: $e');
      if (broken.length >= 20) break;
    }
    if (seed % 20000 == 19999) {
      stdout.writeln('  … ${seed + 1} seed, $nights шөнө');
    }
  }

  stdout.writeln('$games тоглолт, $nights шөнө шийдвэрлэгдэв.');
  if (broken.isEmpty) {
    stdout.writeln('✓ Инвариант зөрчигдөөгүй.');
    return;
  }
  stderr.writeln('✗ ${broken.length} зөрчил:');
  for (final String b in broken) {
    stderr.writeln('  $b');
  }
  exit(1);
}

/// Нэг тоглолтыг эхнээс нь дуустал тоглоод шийдвэрлэсэн шөнийн тоог буцаана.
int _playGame(int seed) {
  final Rng rng = Rng(sha256(utf8.encode('fuzz:$seed')));

  // 4..22 — хууль бус хязгаарыг ЗОРИУД оролдоно (GDD-05 §10.3).
  final int n = 4 + rng.below(19);
  if (n < kMinSeats || n > kMaxSeats) {
    final SetupCheck c = checkSetup(
      n: n,
      mafia: 1,
      boss: false,
      doctor: true,
      detective: true,
    );
    if (!c.isReject) {
      throw StateError('n=$n татгалзах ёстой байсан, гарсан нь ${c.verdict}');
    }
    return 0;
  }

  final Roster roster = rosterFor(n);
  final List<Role> deck = deckFor(roster);
  final List<Seat> seats = <Seat>[for (int i = 1; i <= n; i++) i];
  final List<Seat> orderPerm =
      fisherYates(seats, Rng(sha256(utf8.encode('fuzz-order:$seed'))));
  final List<Role> shuffled =
      fisherYates(deck, Rng(sha256(utf8.encode('fuzz-deal:$seed'))));

  final Setup setup = Setup(
    n: n,
    roleBySeat: <Seat, Role>{
      for (int i = 0; i < n; i++) seats[i]: shuffled[i],
    },
    factionRule:
        roster.boss ? FactionRule.designatedKiller : FactionRule.mafiaMajority,
    whisperOn: rng.below(5) != 0,
    whisperMinAgree: 2 + rng.below(3),
    doctorSelfHeal: SelfHeal.values[rng.below(SelfHeal.values.length)],
    mafiaFriendlyFire: rng.below(2) == 0,
  );

  final Uint8List gameSeed = sha256(utf8.encode('fuzz-seed:$seed'));
  Set<Seat> alive = <Seat>{...seats};
  Map<Seat, Seat> lastHeal = const <Seat, Seat>{};
  Map<Seat, int> selfHealUsed = const <Seat, int>{};

  var night = 1;
  var played = 0;
  while (night <= 30 && evaluateWin(alive, setup) == WinState.none) {
    final NightState s = NightState(
      setup: setup,
      night: night,
      alive: alive,
      seed: gameSeed,
      orderPerm: orderPerm,
      lastHealTarget: lastHeal,
      selfHealUsed: selfHealUsed,
    );

    final List<Intent> intents = <Intent>[
      for (final Seat a in alive.toList()..sort())
        _randomLegalIntent(a, s, rng, seed),
    ];

    final NightReport r = resolveNight(s, intents);
    checkInvariants(s, intents, r);

    // N1 — дахин дуудахад ижил байт.
    if (resolveNight(s, intents).resultHash != r.resultHash) {
      throw StateError('N1: resultHash тогтворгүй, seed $seed шөнө $night');
    }

    alive = Set<Seat>.of(r.aliveAfter);
    lastHeal = Map<Seat, Seat>.of(r.nextLastHeal);
    selfHealUsed = Map<Seat, int>.of(r.nextSelfHealUsed);
    played++;
    night++;

    if (r.win != WinState.none) break;

    // Өдрийн хасалт.
    if (alive.length > 1 && rng.below(4) != 0) {
      final List<Seat> pool = alive.toList()..sort();
      alive = Set<Seat>.of(pool)..remove(pool[rng.below(pool.length)]);
    }
  }
  return played;
}

Intent _randomLegalIntent(Seat actor, NightState s, Rng rng, int gameSeed) {
  final String id = 'f$gameSeed-n${s.night}-s$actor';
  final Intent none = Intent(
    intentId: id,
    night: s.night,
    actor: actor,
    ability: Ability.noAction,
    target: null,
    clientSeq: 1,
  );
  if (rng.below(100) < 12) return none;

  final Ability ability = abilityOf(s.setup.roleOf(actor)!);
  final List<Seat> candidates = <Seat>[];
  for (int t = 1; t <= s.setup.n; t++) {
    final Intent probe = Intent(
      intentId: id,
      night: s.night,
      actor: actor,
      ability: ability,
      target: t,
      clientSeq: 1,
    );
    if (validate(probe, s) == null) candidates.add(t);
  }
  if (candidates.isEmpty) return none;
  return Intent(
    intentId: id,
    night: s.night,
    actor: actor,
    ability: ability,
    target: candidates[rng.below(candidates.length)],
    clientSeq: 1,
  );
}
