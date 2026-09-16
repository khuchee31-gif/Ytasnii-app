// «Хот унтлаа» — шөнийн шийдвэрлэлт. Хөдөлгүүрийн зүрх.
//
// Эх сурвалж: GDD-05 §5-ын псевдо-код, ҮГ ҮСГЭЭР. §3.2-ын эрэмбийн шат,
// §4-ийн `pickVictim`, §9.1-ийн `infoAnswer`, §9.3-ын `buildCues`,
// §9.4-ийн `evaluateWin`. Инвариантууд: GDD-13 §4 (N-цуврал).
//
// ХАТУУ ДҮРЭМ (GDD-05 §0):
//   • IO байхгүй, `dart:io` байхгүй, Flutter байхгүй.
//   • `DateTime.now()` байхгүй, `Random()` байхгүй, `double` байхгүй.
//   • Цэвэр функц: дуудагчийн `NightState`-ыг ХЭЗЭЭ Ч өөрчлөхгүй.
//   • Ижил оролт → ижил байт (инвариант N1).
//
// Хувингийн дараалал (§3.2), v1-д ажилладаг найм:
//   10 setup · 90 protect · 100 attack · 120 deathApply · 130 info ·
//   135 whisper · 160 messages · 170 winCheck.
// 20–80, 110, 140–150 нь ХООСОН — инвариант N13 шалгана.

import 'canon.dart';
import 'invariants.dart';
import 'model.dart';
import 'validate.dart';

// ---------------------------------------------------------------------------
// Клипийн ID ба цагийн тогтмолууд (GDD-07 §2-ын каталог эзэмшинэ)
// ---------------------------------------------------------------------------

/// «Өнөө шөнө хохирогч гарсангүй.» — аврагдсаныг ХЭЗЭЭ Ч зарлахгүй ганц мөр.
const String kClipDawnNoKill = 'DAWN_NO_KILL';

/// «Өнөө шөнө…» — хохирогчийн мөрийн өмнөх хагас.
const String kClipDawnA = 'DAWN_A';

/// «Хот шивнэж байна.» — ДУГААРГҮЙ. Дугаарууд зөвхөн дэлгэц дээр.
const String kClipWhisper = 'WHISPER';

/// `DAWN_A` ба `DAWN_VICTIM_nn`-ийн хоорондох чимээгүй. **ХАТУУ 2500 мс.**
/// Энэ тоо нь UI-ийн сонголт биш, хөдөлгүүрийн гаралт (инвариант N14).
const int kDawnSilenceMs = 2500;

/// Чимээгүйн үед уур амьсгалыг дарах хэмжээ, децибелээр.
const int kDawnDuckDb = -40;

/// `DAWN_VICTIM_01` … `DAWN_VICTIM_20` — 20 бүтэн өгүүлбэр, залгаа биш.
String dawnVictimClip(Seat victim) =>
    'DAWN_VICTIM_${victim.toString().padLeft(2, '0')}';

// ---------------------------------------------------------------------------
// Дотоод хувирамтгай ажлын талбар
// ---------------------------------------------------------------------------

/// Зарлагдсан, гэвч хараахан хэрэгжээгүй довтолгоо (100 → 120).
class _Pending {
  final Seat from;
  final Seat to;
  final AttackLevel level;
  final DeathTag tag;
  const _Pending(this.from, this.to, this.level, this.tag);
}

/// `_Work` — `resolveNight`-ийн дотоод, хувирамтгай хуулбар.
///
/// **Бичих хаалт (write-barrier, GDD-05 §3.2-ын 1-р дүрэм):** мутатор бүр
/// одоогийн хувингийн дугаарыг `assert`-ээр шалгана. Хувин нь зөвхөн
/// өөрөөсөө ЧАНД доогуур хувингийн бичсэнийг уншина; дээшээ л шилжинэ.
class _Work {
  _Work.from(NightState s0)
      : alive = <Seat>{...s0.alive},
        nextLastHeal = <Seat, Seat>{...s0.lastHealTarget},
        nextSelfHealUsed = <Seat, int>{...s0.selfHealUsed};

  /// Одоогийн хувин. 10-аас эхэлж зөвхөн ӨСНӨ.
  int bucket = 10;

  final Set<Seat> alive;
  final Map<Seat, Seat> nextLastHeal;
  final Map<Seat, int> nextSelfHealUsed;

  final Map<Seat, DefenseLevel> grantedDefense = <Seat, DefenseLevel>{};
  final Map<Seat, List<Seat>> protectors = <Seat, List<Seat>>{};
  final List<Visit> visits = <Visit>[];
  final Map<Seat, int> whisperTally = <Seat, int>{};
  final List<_Pending> pending = <_Pending>[];
  final List<Death> deaths = <Death>[];
  final Map<Seat, List<Msg>> msgs = <Seat, List<Msg>>{};

  List<Seat> whisper = const <Seat>[];
  List<Cue> cues = const <Cue>[];
  WinState win = WinState.none;
  String inputHash = '';

  /// Дараагийн хувин руу шилжинэ. Буцаж ХЭЗЭЭ Ч орохгүй.
  void enter(int next) {
    assert(next > bucket, 'хувин буцаж орлоо: $bucket -> $next');
    bucket = next;
  }

  /// 90 `protect` — Эмчийн олгосон хамгаалалт.
  void grantDefense(Seat target, Seat actor) {
    assert(bucket == 90, 'grantDefense нь 90-д л бичигдэнэ (одоо $bucket)');
    grantedDefense[target] = DefenseLevel.basic;
    protectors.putIfAbsent(target, () => <Seat>[]).add(actor);
  }

  /// 130 `info` — хөлдөөсөн ЗОЧЛОЛЫН snapshot. **Уншихад л зориулсан.**
  ///
  /// 130-аас ЧАНД доогуур хувингийн бичсэн зочлолыг л агуулна: 90
  /// эдгээлт, 100 алалт. Ижил хувингийнх (Мөрдөгч) ОРОХГҮЙ — тэр нь
  /// давталтын дарааллаас хамаарах болно.
  List<Visit> visitSnapshot() {
    assert(bucket == 130, 'зочлолын snapshot нь 130-д хөлдөнө (одоо $bucket)');
    return List<Visit>.unmodifiable(
      visits.where((Visit v) => bucketOf(v.ability) < 130),
    );
  }

  /// 100 `attack` — хөлдөөсөн хамгаалалтын snapshot. **Уншихад л зориулсан.**
  Map<Seat, DefenseLevel> effectiveDefense() {
    assert(bucket == 100, 'snapshot нь 100-д хөлдөнө (одоо $bucket)');
    return Map<Seat, DefenseLevel>.unmodifiable(
      Map<Seat, DefenseLevel>.of(grantedDefense),
    );
  }

  /// Шивнээний сан. 100, 130, 135 гурвуулаа тэжээнэ.
  void bump(Seat target) {
    assert(bucket >= 100, 'шивнээний сан 100-аас өмнө дүүрэхгүй');
    whisperTally.update(target, (int v) => v + 1, ifAbsent: () => 1);
  }

  void addVisit(Visit v) {
    assert(
      v.ability != Ability.suspect && v.ability != Ability.noAction,
      'инвариант N17: сэжиглэх товшилт нь зочлол БИШ',
    );
    visits.add(v);
  }
}

// ---------------------------------------------------------------------------
// Лацдах — шалга, давхардлыг цэвэрл, бүрэн эрэмбэ тавь
// ---------------------------------------------------------------------------

/// `(actor, ability)` хос тутамд хамгийн их `clientSeq`-тэйг үлдээнэ (N19).
/// Тэнцвэл `intentId`-ийн лексик дарааллаар — тогтмол хугарал, санамсаргүй бус.
List<Intent> _dedupeKeepMaxClientSeq(List<Intent> a) {
  final Map<String, Intent> best = <String, Intent>{};
  for (final Intent i in a) {
    final String key = '${i.actor}/${i.ability.name}';
    final Intent? cur = best[key];
    if (cur == null ||
        i.clientSeq > cur.clientSeq ||
        (i.clientSeq == cur.clientSeq && i.intentId.compareTo(cur.intentId) > 0)) {
      best[key] = i;
    }
  }
  return best.values.toList();
}

/// GDD-05 §5-ын бүрэн эрэмбэ: хувин → `rank(actor)` → `ability.index` →
/// `intentId`. **`submittedAtMs` нь ЭНД ХЭЗЭЭ Ч ОРОХГҮЙ** (§2).
int _byTuple(NightState s0, Intent x, Intent y) {
  int c = bucketOf(x.ability).compareTo(bucketOf(y.ability));
  if (c != 0) return c;
  c = s0.rank(x.actor).compareTo(s0.rank(y.actor));
  if (c != 0) return c;
  c = x.ability.index.compareTo(y.ability.index);
  if (c != 0) return c;
  return x.intentId.compareTo(y.intentId);
}

/// Лацдсан санааны каноник дүрслэл. **`submittedAtMs` ЗОРИУД байхгүй** —
/// тэр нь зөвхөн аудит, `inputHash`-д орвол ижил шөнө хоёр өөр hash өгнө.
Map<String, Object?> _intentJson(Intent i) => <String, Object?>{
      'intentId': i.intentId,
      'night': i.night,
      'actor': i.actor,
      'ability': i.ability.name,
      'target': i.target,
      'clientSeq': i.clientSeq,
    };

// ---------------------------------------------------------------------------
// Гаралтын каноник дүрслэл (`resultHash`-д зориулсан)
// ---------------------------------------------------------------------------

Map<String, Object?> _cueJson(Cue c) => switch (c) {
      CueLine(clipId: final String id) => <String, Object?>{
          'cue': 'line',
          'clipId': id,
        },
      CueSilence(ms: final int ms, duckAmbienceDb: final int db) =>
        <String, Object?>{'cue': 'silence', 'ms': ms, 'duckAmbienceDb': db},
      CueScreenSeats(seats: final List<Seat> seats) => <String, Object?>{
          'cue': 'screenSeats',
          'seats': List<Seat>.of(seats),
        },
    };

Map<String, Object?> _reportJson({
  required int night,
  required List<Death> deaths,
  required List<Seat> whisper,
  required Map<Seat, List<Msg>> privateMsgs,
  required List<Cue> cues,
  required List<Visit> visits,
  required WinState win,
  required String inputHash,
  required Set<Seat> aliveAfter,
  required Map<Seat, Seat> nextLastHeal,
  required Map<Seat, int> nextSelfHealUsed,
}) =>
    <String, Object?>{
      'night': night,
      'deaths': <Object?>[
        for (final Death d in deaths)
          <String, Object?>{
            'victim': d.victim,
            'killer': d.killer,
            'tag': d.tag.name,
          },
      ],
      'whisper': List<Seat>.of(whisper),
      'privateMsgs': <Seat, Object?>{
        for (final MapEntry<Seat, List<Msg>> e in privateMsgs.entries)
          e.key: <Object?>[
            for (final Msg m in e.value)
              <String, Object?>{
                'code': m.code.name,
                'params': Map<String, int>.of(m.params),
              },
          ],
      },
      'cues': <Object?>[for (final Cue c in cues) _cueJson(c)],
      'visits': <Object?>[
        for (final Visit v in visits)
          <String, Object?>{
            'from': v.from,
            'to': v.to,
            'ability': v.ability.name,
            'harmful': v.harmful,
          },
      ],
      'win': win.name,
      'inputHash': inputHash,
      // Олонлогийг эрэмбэлсэн жагсаалт болгоно — canon-ы олонлогийн
      // мөрөн эрэмбээс («10» < «2») хамаарахгүй байхын тулд.
      'aliveAfter': (aliveAfter.toList()..sort()),
      'nextLastHeal': Map<Seat, Seat>.of(nextLastHeal),
      'nextSelfHealUsed': Map<Seat, int>.of(nextSelfHealUsed),
    };

// ---------------------------------------------------------------------------
// §5 — `resolveNight`
// ---------------------------------------------------------------------------

/// Нэг шөнийг бүтнээр нь шийдвэрлэнэ. **Цэвэр функц.**
///
/// `s0`-ыг ХЭЗЭЭ Ч өөрчлөхгүй: дотроо `_Work` хуулбар барина, хувингуудыг
/// доороос дээш дамжина, `NightReport` буцаана (GDD-05 §5).
NightReport resolveNight(NightState s0, List<Intent> intents) {
  final _Work w = _Work.from(s0);

  // ---- Лацдах: шалга, давхардлыг цэвэрл, бүрэн эрэмбэ тавь ----------------
  // Шалгалт нь ИЛГЭЭХ мөчид болсон; энд зөвхөн лацдах цэвэрлэгээ (§2).
  List<Intent> a = intents
      .where((Intent i) => i.night == s0.night && validate(i, s0) == null)
      .toList();
  a = _dedupeKeepMaxClientSeq(a); // N19
  a.sort((Intent x, Intent y) => _byTuple(s0, x, y));

  w.inputHash = canonHash(<String, Object?>{
    'seed': s0.seed,
    'night': s0.night,
    'intents': <Object?>[for (final Intent i in a) _intentJson(i)],
  });

  // ---- 90 protect ---------------------------------------------------------
  w.enter(90);
  for (final Intent h in a.where((Intent i) => i.ability == Ability.heal)) {
    final Seat t = h.target!;
    w.grantDefense(t, h.actor);
    w.addVisit(Visit(h.actor, t, Ability.heal, harmful: false));
    w.nextLastHeal[h.actor] = t;
    if (h.actor == t) {
      w.nextSelfHealUsed[h.actor] = (w.nextSelfHealUsed[h.actor] ?? 0) + 1;
    }
  }

  // ---- 100 attack (ЗАРЛАНА, хэрэгжүүлэхгүй) -------------------------------
  w.enter(100);
  // P13: бүгд ЗЭРЭГ буудна — хамгаалалт энд ХӨЛДӨНӨ, 120-д дахин уншигдахгүй.
  final Map<Seat, DefenseLevel> defSnapshot = w.effectiveDefense();
  final List<Intent> kills =
      a.where((Intent i) => i.ability == Ability.mafiaKill).toList();
  final ({Seat actor, Seat target})? hit = pickVictim(s0, kills);
  if (hit != null) {
    w.pending.add(_Pending(hit.actor, hit.target, AttackLevel.basic, DeathTag.mafi));
    w.addVisit(Visit(hit.actor, hit.target, Ability.mafiaKill, harmful: true));
  }
  for (final Intent k in kills) {
    // ХАЯГДСАН товшилтууд ч шивнээний санд орно — мафийн санал зөрөх нь
    // ширээнд дугаар болж гарна.
    w.bump(k.target!);
  }

  // ---- 120 deathApply -----------------------------------------------------
  w.enter(120);
  for (final _Pending p in w.pending) {
    // v1: 0 эсвэл 1 элемент.
    if (lethal(p.level, defSnapshot[p.to] ?? DefenseLevel.none)) {
      w.deaths.add(Death(p.to, p.from, p.tag));
      w.alive.remove(p.to);
    }
    // ЯМАР Ч хувийн мессеж байхгүй — §9.2. Эмчид «аварлаа» гэж хэлэхгүй,
    // хохирогчид «чам руу довтолсон» гэж хэлэхгүй.
  }

  // ---- 130 info -----------------------------------------------------------
  w.enter(130);
  // ЗОЧЛОЛЫГ ЭНД ХӨЛДӨӨНӨ, хувинд орох яг тэр мөчид.
  //
  // Энэ бол GDD-05 §3.2-ын бичих хаалт: хувин нь зөвхөн өөрөөсөө ЧАНД
  // доогуур хувингийн бичсэнийг уншина. Үр дагавар нь дүрийн шийдвэр:
  // Ажиглагч ба Мөрдөгч хоёр ижил хувинд байгаа тул Ажиглагч Мөрдөгчийг
  // ХЭЗЭЭ Ч харахгүй. Эс бөгөөс Ажиглагч 2 дахь өдөр Мөрдөгчийн суудлыг
  // сайн санаагаар зарлаж, 3 дахь шөнө нь мафи түүнийг алах болно.
  final List<Visit> frozen = w.visitSnapshot();
  for (final Intent q in a.where((Intent i) => i.ability == Ability.investigate)) {
    final Msg m = infoAnswer(s0, q); // цэвэр, §9.1 — товших мөчийнхтэй ИЖИЛ
    w.msgs.putIfAbsent(q.actor, () => <Msg>[]).add(m);
    w.addVisit(Visit(q.actor, q.target!, Ability.investigate, harmful: false));
    w.bump(q.target!);
  }
  for (final Intent q in a.where((Intent i) => i.ability == Ability.watch)) {
    w.msgs.putIfAbsent(q.actor, () => <Msg>[]).addAll(watchAnswer(frozen, q));
    // ЗОЧЛОЛ БИЧИХГҮЙ (§N17): Ажиглагч нь харж байгаа болохоос
    // ОЧООГҮЙ. Бичвэл хоёр Ажиглагч бие биеэ үнэгүй баталгаажуулах
    // бөгөөд 140-өөс доош ямар ч хожмын дүр бүртгэлийг уншмагц
    // бохирдоно.
    w.bump(q.target!);
  }

  // ---- 135 whisper --------------------------------------------------------
  w.enter(135);
  for (final Intent t in a.where((Intent i) => i.ability == Ability.suspect)) {
    w.bump(t.target!);
    // ЗОЧЛОЛ БИЧИГДЭХГҮЙ. Инвариант N17/N7: сэжиглэх товшилт нь зочлол БИШ —
    // эс бөгөөс v2-ын Ажиглагч шөнө бүр бүгдийг харж, дүр өөрөө үхнэ.
  }
  for (final Intent h in a.where((Intent i) => i.ability == Ability.heal)) {
    w.bump(h.target!);
  }
  if (s0.setup.whisperOn) {
    w.whisper = topWhisper(w.whisperTally, w.alive, s0);
  }

  // ---- 160 messages + cues ------------------------------------------------
  w.enter(160);
  // `narration == false` (Хөтлөгчтэй горим) нь АУДИОГИЙН давхаргын шийдвэр:
  // хөдөлгүүр `cues`-ыг үргэлж гаргана, аппын хоолой л дуугарахгүй.
  // Эс бөгөөс инвариант N14 (2500 мс-ийн блок) шалгагдах зүйлгүй болно.
  w.cues = buildCues(w.deaths, w.whisper);

  // ---- 170 winCheck -------------------------------------------------------
  w.enter(170);
  w.win = evaluateWin(w.alive, s0.setup);

  // ---- Тайлан угсрах ------------------------------------------------------
  final List<Death> deaths = List<Death>.unmodifiable(w.deaths);
  final List<Seat> whisper = List<Seat>.unmodifiable(w.whisper);
  final Map<Seat, List<Msg>> privateMsgs = Map<Seat, List<Msg>>.unmodifiable(
    <Seat, List<Msg>>{
      for (final MapEntry<Seat, List<Msg>> e in w.msgs.entries)
        e.key: List<Msg>.unmodifiable(e.value),
    },
  );
  final List<Cue> cues = List<Cue>.unmodifiable(w.cues);
  final List<Visit> visits = List<Visit>.unmodifiable(w.visits);
  final Set<Seat> aliveAfter = Set<Seat>.unmodifiable(w.alive);
  final Map<Seat, Seat> nextLastHeal =
      Map<Seat, Seat>.unmodifiable(w.nextLastHeal);
  final Map<Seat, int> nextSelfHealUsed =
      Map<Seat, int>.unmodifiable(w.nextSelfHealUsed);

  final String resultHash = canonHash(_reportJson(
    night: s0.night,
    deaths: deaths,
    whisper: whisper,
    privateMsgs: privateMsgs,
    cues: cues,
    visits: visits,
    win: w.win,
    inputHash: w.inputHash,
    aliveAfter: aliveAfter,
    nextLastHeal: nextLastHeal,
    nextSelfHealUsed: nextSelfHealUsed,
  ));

  final NightReport r = NightReport(
    night: s0.night,
    deaths: deaths,
    whisper: whisper,
    privateMsgs: privateMsgs,
    cues: cues,
    visits: visits,
    win: w.win,
    inputHash: w.inputHash,
    resultHash: resultHash,
    aliveAfter: aliveAfter,
    nextLastHeal: nextLastHeal,
    nextSelfHealUsed: nextSelfHealUsed,
  );

  // Дебаг билд дээр ҮРГЭЛЖ (GDD-05 §10.1).
  assert(() {
    checkInvariants(s0, a, r);
    return true;
  }());

  return r;
}

// ---------------------------------------------------------------------------
// §9.1b — Ажиглагчийн хариу
// ---------------------------------------------------------------------------

/// Тэр шөнө `q.target` руу ХЭН ОЧСОН бэ.
///
/// ЦЭВЭР ФУНКЦ: зөвхөн хөлдөөсөн зочлолын жагсаалтаас уншина. Тиймээс
/// хариу нь тайлангаас ДАХИН ТООЦОГДОНО — инвариант N25 үүнийг шалгана.
///
/// Зочин бүрд НЭГ мессеж. Хэн ч очоогүй бол ганц `watchNobody`. Ажиглагч
/// өөрөө жагсаалтад орохгүй (өөрийгөө ажиглах нь хүчингүй).
List<Msg> watchAnswer(List<Visit> frozen, Intent q) {
  final List<Seat> seen = frozen
      .where((Visit v) => v.to == q.target && v.from != q.actor)
      .map((Visit v) => v.from)
      .toSet()
      .toList()
    ..sort();
  if (seen.isEmpty) return const <Msg>[Msg(MsgCode.watchNobody)];
  return <Msg>[
    for (final Seat s in seen) Msg(MsgCode.watchSaw, <String, int>{'seat': s}),
  ];
}

// ---------------------------------------------------------------------------
// §4 — Мафи хэнийг алахаа хэрхэн шийдэх вэ
// ---------------------------------------------------------------------------

/// Хэн шийдсэн (`actor`) ба хэн хохирсон (`target`) хоёрыг ХОЁУЛАНГ буцаана.
///
/// `actor` нь `Death.killer` ба `visits` дотор орно, тиймээс түүнийг таах
/// БОЛОХГҮЙ. Санамсаргүй тэнцэл тайлалт **хориотой** — зөвхөн `orderPerm`
/// (GDD-05 §4).
({Seat actor, Seat target})? pickVictim(NightState s, List<Intent> kills) {
  if (s.setup.factionRule == FactionRule.designatedKiller) {
    final Seat? boss = s.aliveSeatWithRole(Role.boss);
    if (boss != null) {
      for (final Intent k in kills) {
        if (k.actor == boss) {
          // Ахлагчийн үг = дүрэм. Энэ салаа `rank`-ыг ОГТ уншихгүй.
          return (actor: boss, target: k.target!);
        }
      }
    }
    // Ахлагч хасагдсан (эсвэл товшоогүй) бол `mafiaMajority` руу унана.
  }

  // mafiaMajority: тоол, дараа нь ДЕТЕРМИНИСТ тэнцэл тайлалт.
  final Map<Seat, int> tally = <Seat, int>{};
  for (final Intent k in kills) {
    tally.update(k.target!, (int v) => v + 1, ifAbsent: () => 1);
  }
  if (tally.isEmpty) return null;

  int best = 0;
  for (final int v in tally.values) {
    if (v > best) best = v;
  }
  final List<Seat> tied = tally.keys.where((Seat t) => tally[t] == best).toList()
    ..sort((Seat x, Seat y) => s.rank(x).compareTo(s.rank(y))); // orderPerm
  final Seat target = tied.first; // TIEBREAK_SEEDED бүртгэгдэнэ

  final List<Intent> shooters =
      kills.where((Intent i) => i.target == target).toList()
        ..sort((Intent x, Intent y) => s.rank(x.actor).compareTo(s.rank(y.actor)));
  return (actor: shooters.first.actor, target: target); // rank бага нь хутга барина
}

// ---------------------------------------------------------------------------
// §5 — «Хотын шивнээ»
// ---------------------------------------------------------------------------

/// Шивнээний хоёр суудал.
///
/// **Хоёр давхар эрэмбэ, зориудаар өөр** (GDD-05 §5): аль хоёр суудал гарахыг
/// **тоогоор** шийднэ (rank нь зөвхөн тэнцэл тайлна), харин **хэвлэх дарааллыг
/// суудлын дугаараар**. «Гурав, ес» гэсэн мөр аль нь илүү товшигдсоныг
/// ХЭЛЭХГҮЙ — хөтлөгч тоог хэзээ ч уншихгүй.
List<Seat> topWhisper(Map<Seat, int> tally, Set<Seat> aliveAfter, NightState s) {
  final List<MapEntry<Seat, int>> pool = tally.entries
      .where((MapEntry<Seat, int> e) => aliveAfter.contains(e.key))
      .where((MapEntry<Seat, int> e) => e.value >= s.setup.whisperMinAgree)
      .toList()
    ..sort((MapEntry<Seat, int> x, MapEntry<Seat, int> y) {
      final int c = y.value.compareTo(x.value); // тоо БУУРАХААР
      return c != 0 ? c : s.rank(x.key).compareTo(s.rank(y.key)); // дараа rank
    });
  return pool.take(2).map((MapEntry<Seat, int> e) => e.key).toList()..sort();
}

// ---------------------------------------------------------------------------
// §9.1 — Мөрдөгчийн хариу
// ---------------------------------------------------------------------------

/// v1-д хуурах дүр **байхгүй** тул шалгалт нь хуваарилалтын цэвэр функц.
///
/// Энэ функц шөнийн бусад ямар ч үйлдлээс хамаарахгүй — тиймээс үйлдлийн
/// дэлгэц хариуг ТЭР ДОР НЬ харуулж болно, 130-р хувин нь ЯГ энэ функцийг
/// дахин дуудна. Хоёр хариу зөрвөл инвариант N21 унана.
Msg infoAnswer(NightState s, Intent q) {
  final Seat? t = q.target;
  if (t == null) {
    throw ArgumentError('infoAnswer: `investigate` нь байгүй байж болохгүй');
  }
  final Role? r = s.setup.roleOf(t);
  if (r == null) {
    throw ArgumentError('infoAnswer: $t суудалд дүр байхгүй');
  }
  return factionOf(r) == Faction.mafi
      ? const Msg(MsgCode.traceFound) // «Мөр олдлоо.»
      : const Msg(MsgCode.traceNotFound); // «Мөр олдсонгүй.»
}

// ---------------------------------------------------------------------------
// §9.3 — `cues`, чимээгүй нь гаралт
// ---------------------------------------------------------------------------

/// Хөтлөгчийн дохионы дараалал. **2500 мс-ийн блок нь хатуу** (N14).
///
/// Шивнээ хоосон бол ЮУ Ч нэмэгдэхгүй: «Хот чимээгүй байна» гэсэн мөр
/// ЗОРИУД байхгүй — тэр нь шивнээ ажиллаагүйг зарлах болно (`WHISPER_NONE`
/// каталогоос хасагдсан).
List<Cue> buildCues(List<Death> deaths, List<Seat> whisper) {
  final List<Cue> c = <Cue>[];
  if (deaths.isEmpty) {
    c.add(const CueLine(kClipDawnNoKill)); // «Өнөө шөнө хохирогч гарсангүй.»
  } else {
    c.add(const CueLine(kClipDawnA)); // «Өнөө шөнө…»
    c.add(const CueSilence(kDawnSilenceMs, duckAmbienceDb: kDawnDuckDb)); // ХАТУУ
    c.add(CueLine(dawnVictimClip(deaths.first.victim))); // бүтэн өгүүлбэр
  }
  if (whisper.isNotEmpty) {
    c.add(const CueLine(kClipWhisper)); // «Хот шивнэж байна.» — ДУГААРГҮЙ
    c.add(CueScreenSeats(List<Seat>.unmodifiable(whisper))); // ЗӨВХӨН дэлгэц
  }
  return c;
}

// ---------------------------------------------------------------------------
// §9.4 — Ялалт
// ---------------------------------------------------------------------------

/// `M == 0` → хотынхон; `M >= T` → мафи (шөнө-эхэлдэг конвенц); бусад → `none`.
/// Хоёулаа зэрэг үнэн байж ЧАДАХГҮЙ — инвариант N10.
WinState evaluateWin(Set<Seat> alive, Setup setup) {
  int m = 0;
  for (final Seat s in alive) {
    final Role? r = setup.roleOf(s);
    if (r != null && factionOf(r) == Faction.mafi) m++;
  }
  final int t = alive.length - m;
  if (m == 0) return WinState.hotynhon;
  if (m >= t) return WinState.mafi;
  return WinState.none;
}
