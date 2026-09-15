# GDD-05 — Шөнийн хөдөлгүүр — техникийн тодорхойлолт

> **Шийдвэрийн хураангуй**
> - **v1-ийн бүх шөнө нь `resolveNight(NightState, List<Intent>) -> NightReport` гэсэн ганц цэвэр функцээр шийдэгдэнэ.** IO байхгүй, `DateTime.now()` байхгүй, `Random()` байхгүй, `double` байхгүй. Хөдөлгүүр нь Flutter-ээс хамаарахгүй, `dart:io`-гүй тусдаа багц.
> - **Эрэмбийн шат 17 хувингаас 8 болж хумигдав.** v1-д зөвхөн `10 setup · 90 protect · 100 attack · 120 deathApply · 130 info · 135 whisper · 160 messages · 170 winCheck` ажиллана. 20–80 ба 140–150 нь **хоосон байх нь тестээр шалгагдана** — тэнд v2-ын дүрүүд суух зай.
> - **Мөрдөгчийн хариу товших мөчид өгөгдөнө, үүрээр биш.** v1-д хуурах дүр байхгүй тул `INFO` бусад бүх хувинтай коммутатив болж, шалгалтын үр дүн шөнийн бусад үйлдлээс үл хамаарна. Энэ ганц дүгнэлт үүрийн хувийн дэлгэцийн бүхэл давхаргыг устгав.
> - **v1-д хувийн мессеж ЗӨВХӨН нэг л байна: Мөрдөгчийн «Мөр олдлоо».** Эмчид «аварлаа» гэж хэлэхгүй, хохирогчид «чам руу довтолсон» гэж хэлэхгүй — нийтийн `NIGHT_NO_KILL` мөр хоёуланг нь үнэгүй хийж байна (§9.2-ын баталгаа).
> - **«Тооны самбар» нь дүрийг хэзээ ч уншихгүй.** `pips = b₀ − (dayIndex − 1)`, бөгөөд `b₀ = ⌊N/2⌋ − M − 1`. Хасагдсан хүний талыг уншиж буулгавал апп нь хасагдсан хүний дүрийг чимээгүйхэн зарлана — тэр нь §11-ийн татгалзлыг зөрчинө.
> - **Шударга байдлын код: `seed0` (32 байт) → SHA-256 → зургаан аравтын тоо, `412-995` хэлбэрээр**, хуваарилахаас **өмнө** утас барихгүй байгаа тоглогч цаасан дээр бичнэ. Дараа `seed = SHA256(seed0 ‖ shake ‖ dealId)`, ChaCha20 урсгал, rejection sampling-тай Fisher–Yates.
> - **Дахин шийдвэрлэлт идемпотент, санамсаргүй бус.** `inputHash` таарвал кэшлэгдсэн байтыг буцаана; таарахгүй бол **дахин тооцоолохгүй**, бүртгэлээс бүтнээр дахин тоглуулна.
> - **Чимээгүйн хүснэгт нь UI-ийн код биш, хөдөлгүүрийн гаралт.** `NightReport.cues` дотор `pause2500` нь `killA` ба `killB`-ийн хооронд байх нь **инвариант I11**.

*Уг баримт: `docs/03-night-engine.md` (17 хувин, 18 парадокс) — тэндээс v1-ийн бүрэлдэхүүн хүртэл нарийсгав. Нэр томьёо: `docs/13-language-culture.md` §1. Шударга байдал: `docs/10-anticheat.md` §3 протокол P2.*

---

## 1. Хамрах хүрээ — юуг шийдвэрлэх хөдөлгүүр вэ

v1-д таван дүр байна, дөрөв нь шөнө үйлдэл хийнэ. **Иргэн ч үйлдэл хийнэ** — түүний товшилт нь механикийн хувьд хоосон биш, «Хотын шивнээ»-г тэжээнэ.

| Дүр (монгол) | `Role` | Фракц | `Ability` | Хувин | Суудал |
|---|---|---|---|---:|---|
| Алуурчин | `killer` | `mafi` | `mafiaKill` | 100 | бүгд |
| Ахлагч | `boss` | `mafi` | `mafiaKill` | 100 | **зөвхөн N ≥ 10** |
| Эмч | `doctor` | `hotynhon` | `heal` | 90 | бүгд |
| Мөрдөгч | `detective` | `hotynhon` | `investigate` | 130 | бүгд |
| Иргэн | `citizen` | `hotynhon` | `suspect` | 135 | бүгд |

**Гурван хатуу дүрэм, эндээс гарч ирдэг:**

1. **Суудал бүр шөнө бүр яг нэг л бай сонгоно.** Алгасах товч байхгүй, таймер байхгүй, автомат алгасалт байхгүй. Утас чиний гарт байхад дэлгэц нээгдэхгүй бол чи товших хэрэгтэй. Энэ нь `docs/03` §3.5-ын бүхэл `AutoPass` давхаргыг v1-ээс хаслаа — офлайн дамжуулгад «хугацаа дуусах» гэсэн зүйл байхгүй.
2. **Бүх дүр ижилхэн 6 секунд, ижил чичиргээ, ижил чимээ.** Хөдөлгүүрийн хувьд энэ нь: `Intent`-ийн хэлбэр дүрээс хамаарахгүй — `(actor, ability, target)`. Дэлгэцийн асуулт л өөр.
3. **Хөдөлгүүр хэзээ ч худлаа хэлэхгүй.** Хорлогч (framer), Согтуу, Даяанч байхгүй. Тиймээс `frames` map нь v1-д **байхгүй**, `investigate` нь дүрийн фракцийг шууд уншина.

---

## 2. Төрлүүд (Dart)

Хөдөлгүүр бол `packages/engine` — цэвэр Dart, `pubspec.yaml` дотор `flutter` ч, `dart:io` ч байхгүй. Ингэснээр CLI дээр (M1) ба апп дотор (M2) **ижил байт** ажиллана.

```dart
typedef Seat = int;            // 1..20. Дэлгэцэн дээрх дугаартай ЯГ ижил. Индекс биш.

enum Role     { killer, boss, doctor, detective, citizen }
enum Faction  { mafi, hotynhon }
enum Ability  { mafiaKill, heal, investigate, suspect }

enum AttackLevel  { none, basic, powerful }   // v1: none, basic
enum DefenseLevel { none, basic }             // v1: none, basic

enum RejectCode {
  actorDead, targetDead, targetSelf, targetSameFaction,
  notYourAbility, healRepeat, nightSealed, seatNotInGame,
}

@immutable
class Intent {
  final String  intentId;     // uuid v4, клиент үүсгэнэ — идемпотентын түлхүүр
  final int     night;        // 1-ээс
  final Seat    actor;
  final Ability ability;
  final Seat    target;       // v1-д ЯГ нэг, null хэзээ ч биш
  final int     clientSeq;    // суудал тутам монотон; (actor, ability) тутам сүүлийнх нь хожино
  final int     submittedAtMs;// ЗӨВХӨН аудит. Эрэмбэлэхэд хэзээ ч биш.
}

@immutable
class Setup {
  final int n;                          // 8..20, тэгш тоо зөвлөмжтэй
  final Map<Seat, Role> roleBySeat;     // НУУЦ. UI хэзээ ч бүтнээр рендерлэхгүй.
  final FactionRule factionRule;        // §4
  final bool whisperOn;                 // анхдагч true (ангийн багц)
  final bool narration;                 // false = «Хөтлөгчтэй горим»
  final int  whisperMinAgree;           // анхдагч 3
}

@immutable
class NightState {
  final Setup      setup;
  final int        night;
  final Set<Seat>  alive;
  final Map<Seat, Seat> lastHealTarget;  // Эмч тутам, өнгөрсөн шөнийн бай
  final Uint8List  seed;                 // 32 байт
  final List<Seat> orderPerm;            // seed-ээс гарсан, GameCreated-д бичигдсэн
  int rank(Seat s) => orderPerm.indexOf(s);   // n ≤ 20, O(n) хангалттай
}

@immutable
class Death   { final Seat victim; final Seat killer; final DeathTag tag; }
@immutable
class Visit   { final Seat from, to; final Ability ability; final bool harmful; }
@immutable
class Msg     { final MsgCode code; final Map<String,int> params; }

@immutable
class NightReport {
  final int              night;
  final List<Death>      deaths;        // v1: 0 эсвэл 1
  final List<Seat>       whisper;       // 0..2, суудлын дугаараар ӨСӨХӨӨР
  final Map<Seat,List<Msg>> privateMsgs;// v1: ≤ 1 бичлэг (Мөрдөгч)
  final List<Cue>        cues;          // хөтлөгчийн дохио + чимээгүйн блокууд
  final List<Visit>      visits;        // эргэн харах дэлгэц + дибаг
  final WinState         win;
  final String           inputHash;     // sha256(canon(sealed input))
  final String           resultHash;    // sha256(canon(this))
}
```

**Санаа илгээнэ, үр нөлөө биш.** Утас `{ability: mafiaKill, target: 7}` илгээнэ, хэзээ ч «7 үхлээ» гэж илгээхгүй. Хэн үхсэнийг **зөвхөн** `resolveNight` шийднэ. Офлайн горимд «сервер» гэдэг чинь яг тэр утсан дээр ажиллаж байгаа тэр л функц — яг үүний улмаас хөдөлгүүр IO-гүй байх ёстой.

**Шалгалт нь илгээх мөчид болно, шийдвэрлэх үед хэзээ ч биш.** `validate(Intent, NightState) -> RejectCode?` бол цэвэр функц, дэлгэц нь түүний кодыг монгол текст болгоно. Шийдвэрлэх үед дахин шалгавал инвариант I1 эвдэрч, дахин тоглуулалт зөрнө.

| `RejectCode` | Нөхцөл | Дэлгэцийн текст |
|---|---|---|
| `targetSelf` | Эмч, Мөрдөгч, Иргэн өөрийгөө онилов | «Өөрийгөө сонгож болохгүй.» |
| `targetSameFaction` | Мафи мафиг онилов | «Өөрийнхнөө сонгож болохгүй.» |
| `healRepeat` | Эмч өнгөрсөн шөнийн байгаа нь дахин онилов | «Өчигдөр аварсан хүнээ дахин аварч болохгүй.» |
| `targetDead` | Бай `alive` дотор байхгүй | «Тэр тоглогч хасагдсан.» |
| `nightSealed` | Шөнө аль хэдийн лацдагдсан | «Энэ шөнө хаагдсан.» |

---

## 3. Түвшин ба эрэмбийн шат

### 3.1 Довтолгоо / хамгаалалтын түвшин

```dart
bool lethal(AttackLevel a, DefenseLevel d) => a.index > d.index;
```

v1-д яг **хоёр** утга ажиллана: мафийн хутга = `basic` (1), Эмчийн олгосон хамгаалалт = `basic` (1). `1 > 1` нь хуурамч тул **эдгээлт нь мафийн алалтыг чанд цуцална**. `powerful` нь v2-д (Манаач, Хамгаалагч) зориулж enum дотор сууж байна, гэхдээ **v1-д хөдөлгүүр `powerful` хэзээ ч гаргахгүй** — инвариант I9 үүнийг шалгана.

Яагаад тэнцүү түвшин гэж? Хэрэв Эмчийг `powerful` олгодог болговол ирээдүйн «хүчтэй алуурчин» дүр Эмчийг дийлэхгүй болно. Тэнцүү түвшин нь дизайны зайг үлдээнэ.

### 3.2 Эрэмбийн шат — зөвхөн манай дүрүүд

| Хувин | Нэр | v1-д хэн байна | Тайлбар |
|---:|---|---|---|
| 10 | `setup` | — | шөнийн тоолуур, `lastHealTarget` шинэчлэл |
| 20–80 | *(хоосон)* | — | хорих, солих, саатуулах, хуурах — **v1-д хоосон, I9 шалгана** |
| 90 | `protect` | **Эмч** | `grantedDefense[t] = basic` |
| 100 | `attack` | **Мафи** | довтолгоог **зарлана**, хэрэгжүүлэхгүй |
| 110 | *(хоосон)* | — | хариу цохилт (v2 Хамгаалагч) |
| 120 | `deathApply` | — | хөлдөөсөн snapshot-оор үхлийг хэрэгжүүлнэ |
| 130 | `info` | **Мөрдөгч** | шалгалтын үр дүн (§9.1-ийн preview-тэй тэнцэнэ) |
| **135** | `whisper` | **Иргэн + бүгд** | «Хотын шивнээ» — **манай шинэ хувин** |
| 140–150 | *(хоосон)* | — | 140 нь v2-ын «Өв»-д нөөцлөгдсөн. `recruit` (150) нь **үүрд хоосон** — гуравдагч тал байхгүй. |
| 160 | `messages` | — | мессеж ба `cues` угсрах |
| 170 | `winCheck` | — | `M ≥ T` / `M == 0` |

Хоёр хатуу дүрэм хүчинтэй хэвээр:

1. **Хувин нь зөвхөн өөрөөсөө ЧАНД доогуур хувингийн бичсэн төлөвийг уншина.** Дебаг билд дээр `_Work` классын setter-үүд одоогийн хувингийн дугаарыг шалгаад `assert` шиднэ (write-barrier).
2. **Хувин дотор** `rank(actor)` буюу `orderPerm`-ийн индексээр эрэмбэлнэ. **Илгээсэн хугацаагаар хэзээ ч биш.**

**135 яагаад 130-ын дараа вэ.** Шивнээ нь үхлийг (120) ба шалгалтыг (130) хоёуланг нь уншина: өнөө шөнө үхсэн суудал шивнээний сангаас **хасагдана**. Тиймээс тэр нь хоёуланаас дээгүүр байх ёстой. 131 биш 135 гэсэн нь `docs/03`-ын 10-ын завсрын конвенцийг эвдэхгүйн тулд — 140 нь «Өв»-д хэрэгтэй.

---

## 4. Мафи хэнийг алахаа хэрхэн шийдэх вэ

Жигд эргэлтийн дор мафи шөнө тохирч чадахгүй — гурван мафи гурван өөр суудалд, гурван өөр мөчид, тус тусдаа товшино. Тиймээс фракцийн дүрэм бол **тоглоомын дүрэм**, техникийн нарийн ширийн зүйл биш. Ширээ түүнийг сурах ёстой.

| N | `FactionRule` | Дүрэм |
|---|---|---|
| 8 (мафи 2) | `mafiaMajority` | Хамгийн олон товшилт авсан бай хожино |
| **10, 12, 16 (Ахлагчтай)** | **`designatedKiller`** | **Ахлагчийн товшилт хожино. Ахлагч хасагдсан бол `mafiaMajority` руу автоматаар унана.** |

```dart
Seat? pickVictim(NightState s, List<Intent> kills) {
  if (s.setup.factionRule == FactionRule.designatedKiller) {
    final boss = s.aliveSeatWithRole(Role.boss);
    if (boss != null) {
      final k = kills.firstWhereOrNull((i) => i.actor == boss);
      if (k != null) return k.target;                    // Ахлагчийн үг = дүрэм
    }
  }
  // mafiaMajority: тоол, дараа нь ДЕТЕРМИНИСТ тэнцэл тайлалт
  final tally = <Seat,int>{};
  for (final k in kills) tally.update(k.target, (v) => v + 1, ifAbsent: () => 1);
  if (tally.isEmpty) return null;
  final best = tally.values.reduce(max);
  final tied = tally.keys.where((t) => tally[t] == best).toList()
      ..sort((a, b) => s.rank(a).compareTo(s.rank(b)));   // orderPerm, НЕ санамсаргүй
  return tied.first;                                      // TIEBREAK_SEEDED бүртгэгдэнэ
}
```

**Санамсаргүй тэнцэл тайлалт хориотой.** Wolfy тэнцэл дээр санамсаргүй нэгийг алдаг; тэр **мэдрэмжийг** авсан, гэхдээ `orderPerm`-ээр л. Шалтгаан нь: 15 настай хүүхэд «яагаад над руу явчихав?» гэж асуухад хариулт нь тоглолтын эхэнд бүртгэгдсэн, шалгаж болох сэлгэмэл байх ёстой.

**Ахлагч яагаад ялгарах вэ.** `00-vision` §6: «мафийн санал зөрөх мухардлыг дүрмээр биш, **эрх мэдлээр** шийднэ — хөтлөгч юу ч тайлбарлах шаардлагагүй.» Кодын хувьд энэ бол **6 мөр** ба нэг л дэлгэцийн шошго: Ахлагчийн үйлдлийн дэлгэцэн дээр «Чиний сонголт шийднэ.»

---

## 5. `resolveNight` — псевдо-код

Дуудагчийн `NightState`-ыг **хэзээ ч өөрчлөхгүй**. Дотроо `_Work` гэсэн хувирамтгай хуулбар барина, хувингуудыг доороос дээш дамжина, `NightReport` буцаана.

```dart
NightReport resolveNight(NightState s0, List<Intent> intents) {
  final w = _Work.from(s0);                                  // deep copy

  // ---- Лацдах: шалга, давхардлыг цэвэрл, бүрэн эрэмбэ тавь --------------
  var a = intents.where((i) => i.night == s0.night && validate(i, s0) == null)
                 .toList();
  a = dedupeKeepMaxClientSeq(a, by: (i) => (i.actor, i.ability));   // I2
  a.sort(byTuple([
    (i) => bucketOf(i.ability),
    (i) => s0.rank(i.actor),
    (i) => i.ability.index,
    (i) => i.intentId,                                       // тогтмол хугарал
  ]));
  w.inputHash = sha256(canon({'seed': s0.seed, 'night': s0.night, 'intents': a}));

  // ---- 90 protect --------------------------------------------------------
  for (final h in a.where((i) => i.ability == Ability.heal)) {
    w.grantedDefense[h.target] = DefenseLevel.basic;
    w.protectors.putIfAbsent(h.target, () => []).add(h.actor);
    w.visits.add(Visit(h.actor, h.target, Ability.heal, harmful: false));
    w.nextLastHeal[h.actor] = h.target;
  }

  // ---- 100 attack (ЗАРЛАНА, хэрэгжүүлэхгүй) ------------------------------
  final defSnapshot = Map.unmodifiable(w.effectiveDefense());  // P13: бүгд зэрэг буудна
  final kills = a.where((i) => i.ability == Ability.mafiaKill).toList();
  final victim = pickVictim(s0, kills);
  if (victim != null) {
    final shooter = kills.firstWhere((i) => i.target == victim).actor;
    w.pending.add(Pending(shooter, victim, AttackLevel.basic, DeathTag.mafi));
    w.visits.add(Visit(shooter, victim, Ability.mafiaKill, harmful: true));
  }
  for (final k in kills) {                                    // хаягдсан товшилтууд ч
    w.whisperTally.bump(k.target);                            // шивнээний санд орно
  }

  // ---- 120 deathApply ----------------------------------------------------
  for (final p in w.pending) {                                 // v1: 0 эсвэл 1 элемент
    if (lethal(p.level, defSnapshot[p.to] ?? DefenseLevel.none)) {
      w.deaths.add(Death(p.to, p.from, p.tag));
      w.alive.remove(p.to);
    }
    // ЯМАР Ч хувийн мессеж байхгүй — §9.2-ыг үз
  }

  // ---- 130 info ----------------------------------------------------------
  for (final q in a.where((i) => i.ability == Ability.investigate)) {
    final m = infoAnswer(s0, q);                               // цэвэр, §9.1
    w.msgs.putIfAbsent(q.actor, () => []).add(m);
    w.visits.add(Visit(q.actor, q.target, Ability.investigate, harmful: false));
    w.whisperTally.bump(q.target);
  }

  // ---- 135 whisper -------------------------------------------------------
  for (final t in a.where((i) => i.ability == Ability.suspect)) {
    w.whisperTally.bump(t.target);
    w.visits.add(Visit(t.actor, t.target, Ability.suspect, harmful: false));
  }
  for (final h in a.where((i) => i.ability == Ability.heal)) w.whisperTally.bump(h.target);
  if (s0.setup.whisperOn) w.whisper = topWhisper(w.whisperTally, w.alive, s0);

  // ---- 160 messages + cues ----------------------------------------------
  w.cues = buildCues(w);                                       // §9.3, чимээгүй нь дотор

  // ---- 170 winCheck ------------------------------------------------------
  w.win = evaluateWin(w);

  final r = w.toReport();
  assert(allInvariants(s0, a, r));                             // дебаг билд дээр
  return r;
}

List<Seat> topWhisper(Tally t, Set<Seat> aliveAfter, NightState s) {
  final pool = t.entries
      .where((e) => aliveAfter.contains(e.key))                // өнөө шөнө үхсэн нь хасагдана
      .where((e) => e.value >= s.setup.whisperMinAgree)        // анхдагч 3
      .toList()
      ..sort((x, y) {                                          // тоо буурахаар, дараа rank
        final c = y.value.compareTo(x.value);
        return c != 0 ? c : s.rank(x.key).compareTo(s.rank(y.key));
      });
  return pool.take(2).map((e) => e.key).toList()..sort();      // СУУДЛЫН ДУГААРААР өсөхөөр
}
```

**Гол санааг монголоор:** довтолгоо 100-д зөвхөн **зарлагдана**, 120-д л **хэрэгжинэ**, хамгаалалтын snapshot нь 100-д **хөлдөнө**. Ингэснээр «хэн хэнийг түрүүлж буудсан бэ?» гэсэн асуулт огт үүсэхгүй. v1-д довтолгоо нэг л байдаг тул энэ нь илүүц юм шиг харагдана — гэвч snapshot-ын хэлбэрийг одоо барих нь v2-д Манаач нэмэхэд хөдөлгүүрийг дахин бичихээс хамгаална.

**Шивнээний эрэмбэ хоёр давхар байгааг анзаар:** аль хоёр суудал гарахыг **тоогоор** шийднэ (rank нь зөвхөн тэнцэл тайлна), харин **хэвлэх дарааллыг суудлын дугаараар** шийднэ. Хоёр дахь эрэмбэ нь зориудын: «гурав, ес» гэсэн мөр аль нь илүү товшигдсоныг **хэлэхгүй**. Хөтлөгч тоог хэзээ ч уншихгүй.

> **Нэг маркчилсан зөрчил `00-vision` §4-тэй.** Тэнд «Иргэдийн шөнийн товшилт нь **механикийн хувьд хоосон**» гэж бичсэн. Энэ хөдөлгүүрийн дор тэр нь үнэн биш: `whisperMinAgree = 3` нь 12 суудалд мафийн тоотой тэнцүү тул **мафи өдөр тохиролцоод шивнээг хуурамчаар үүсгэж чадна**. Би үүнийг зориуд ингэж үлдээж байна — хоосон механик нь ширээнд хэрэггүй, харин «мафи шивнээг үйлдвэрлэж чадна» гэдэг нь өдрийн хэлэлцүүлэгт нэмэлт давхарга нэмнэ. Хэрэв ангид хэт хүчтэй болж хэмжигдвэл тохируулга нь **нэг бүхэл тоо** (§13-ын асуулт 2).

---

## 6. Үйл явдлын бүртгэл

Нэг тоглолт = зөвхөн нэмэгддэг (append-only) мөрүүд, төхөөрөмж дээрх SQLite-д. Хүснэгт: `event(seq INTEGER PRIMARY KEY AUTOINCREMENT, game_id TEXT, kind TEXT, payload TEXT)`.

| Төрөл | Агуулга |
|---|---|
| `GameCreated` | `gameId, n, setupId, seedCommit, orderPerm[], b0` |
| `DealRevealed` | `seed0, shakeBytes, dealId` — **тоглолт ДУУССАНЫ дараа** бичигдэнэ (§7) |
| `NightOpened` | `night` |
| `IntentSubmitted` | `intentId, night, actor, ability, target, clientSeq, submittedAtMs` |
| `IntentWithdrawn` | `intentId` — v1-д зөвхөн «Буцах» товчоор |
| `NightSealed` | `night, inputHash` |
| `NightResolved` | `night, resultHash, deaths[], whisper[]` |
| `DayOpened` | `day, pips` |
| `HandVoteResolved` | `day, seat, hands` — «Гар өргөх»-ийн дугуйнаас |
| `PinMarked` | `day, msSinceDayStart, speakingSeat?` — 📌 |
| `BestMoveSpoken` | `night, seats[3]` — **хэзээ ч оноологдохгүй** |
| `GameEnded` | `winner, nights, resultHash` |

**Хамгийн чухал хэрэгжүүлэлтийн дүрэм:** `IntentSubmitted` нь **«Ширээн дээр тавь. Дараах — №8» гэсэн дэлгэц рендерлэгдэхээс өмнө**, синхроноор SQLite-д бичигдэнэ. Хэрэв утас 8-р суудлын гар дээр унтарвал, дахин нээхэд бүртгэлд долоон санаа байгаа тул апп **8-р суудлаас үргэлжилнэ**. Async бичээд дэлгэц урьдчилж явбал тэр суудал хоёр дахин товшино — шөнийн эргэлтэд энэ нь тоглоомыг эвдэнэ.

**Дүрийн хуваарилалт бүртгэлд ОРОХГҮЙ** тоглолт дуусах хүртэл. `GameCreated` дотор зөвхөн `seedCommit` (зургаан аравтын тоо) байна. Аппын файлыг ухаж үзсэн хөтлөгч юу ч олж чадахгүй — `docs/10` §3-ын тохиролцоошгүй дүрэм.

---

## 7. Seed, ChaCha20 ба шударга байдлын код

### 7.1 Кодын гарал

```
1. seed0  <- Random.secure().nextBytes(32)
2. digest <- sha256(seed0)
3. code   <- (digest[0..3] big-endian uint32) % 1000000, зургаан оронтой болгож 0 нэм
              → «412-995» гэж 3+3 хэлбэрээр харуулна
4. Утас барихГҮЙ, санамсаргүй сонгогдсон тоглогч кодыг цаасан дээр бичнэ / чангаар уншина
5. Тэр л тоглогч утсыг 2 секунд сэгсэрнэ → shake = 16 байт
              (акселерометрийн сүүлийн 32 дээд·доод байт, 8 битээр квантчилсан)
6. seed   <- sha256(seed0 ‖ shake ‖ utf8(dealId))
7. dealId <- "$gameId:$n:$dealCounter"
```

**Зургаан аравтын тоо ≈ 20 бит. Хэн ч «хангалтгүй» гэж хэлэх болов уу — үгүй.** Халдагч бол ангийн хүүхэд, GPU биш. Амлалт нь зөвхөн нэг зүйлээс хамгаалах ёстой: **хөтлөгч мафи болтлоо дахин дахин хуваарилах.** Код нь хуваарилахаас **өмнө** цаасан дээр байгаа тул дахин хуваарилвал код таарахгүй. Дээрээс нь seed нь хөтлөгчийн хяналтгүй хоёр дахь эх сурвалжтай (сэгсрэлт). Аравтын тоо гэж сонгосон нь: зургаан hex тэмдэгтийг («a3f0c1») монголоор чангаар уншихад анги гацна, «дөрөв, нэг, хоёр — ес, ес, тав» гэдэг нь гацахгүй.

### 7.2 RNG

```dart
class Rng {                          // ChaCha20, nonce = 0, counter = 0-ээс
  Rng(Uint8List key32);
  int nextU32();
  int below(int bound) {              // rejection sampling — modulo хазайлт БАЙХГҮЙ
    final limit = 0x100000000 - (0x100000000 % bound);
    int x;
    do { x = nextU32(); } while (x >= limit);
    return x % bound;
  }
}
```

**Яагаад ChaCha20, splitmix64 биш.** 20 суудлын хуваарилалт бол `20! ≈ 2.4×10¹⁸` = **62 бит** — splitmix64-ийн 64 битийн төлөвт нүцгэн багтана. 256 битийн key нь төлвийг хэзээ ч хязгаарлагч хүчин зүйл болгохгүй. Хэрэгжүүлэлт нь ~60 мөр, RFC 8439-ийн тест векторуудаар шалгагдана — тэр тест нь `flutter test`-ийн хамгийн хямд, хамгийн үнэ цэнтэй файл.

**Хоёр урсгал, домэйн тусгаарлалттай:**

```dart
final deal  = Rng(sha256(concat(seed, utf8('DEAL'))));
final order = Rng(sha256(concat(seed, utf8('ORDER'))));
final roles = fisherYates(canonicalDeck(setup), deal);   // буурах давталт, below() ашиглана
final orderPerm = fisherYates(seatsAscending(n), order);
```

`orderPerm`-ыг тусдаа урсгалаас гаргах нь **инженерийн шийдвэр биш, аюулгүй байдлын шийдвэр**: `orderPerm` нь `GameCreated`-д ил бичигдэнэ. Нэг урсгалаас дараалан гаргавал ил байгаа сэлгэмэл нь нуугдмал хуваарилалтын тухай мэдээлэл өгнө.

### 7.3 Тоглолтын дараах шалгагч

Хамгийн сүүлийн дэлгэцүүдийн нэг: **«Шударга байдлын шалгалт»**. Харуулах зүйл: `seed0` (hex), `shake` (hex), `dealId`, `seed` (hex), кодыг дахин бодсон нь, ба хуваарилалтыг дахин гаргасан нь.

> «Цаасан дээрх код: **412-995**. Аппын код: **412-995**. Таарлаа.»
> «Дахин хуваарилахад ижил гарлаа: 1-Иргэн, 2-Ахлагч, 3-Иргэн…»

Энэ дэлгэц нь «Хөзрөө нээе»-ийн **дараа** гарна, тусдаа товчны цаана. Хэн ч харахгүй байж болно — гол нь **харж болдог** гэдэг нь.

---

## 8. Идемпотент дахин шийдвэрлэлт

Офлайн нэг утсан дээр хамгийн бодит эвдрэл бол: шөнийн эргэлтийн дундуур апп үхэх (MIUI-ийн батерейны менежер), эсвэл шийдвэрлэсний дараа дэлгэц зурагдахаас өмнө үхэх.

```dart
NightReport resolveIdempotent(Store st, NightState s, List<Intent> sealed) {
  final h = sha256(canon({'seed': s.seed, 'night': s.night, 'intents': sortSealed(sealed)}));
  final cached = st.nightResult(s.night);
  if (cached != null) {
    if (cached.inputHash == h) return cached.report;          // дахин тооцоолохгүй
    throw EngineStateCorrupt(s.night, cached.inputHash, h);   // ЧИМЭЭГҮЙХЭН БҮҮ ЗАС
  }
  final r = resolveNight(s, sealed);
  st.putNightResultIfAbsent(s.night, h, r);                   // нэг бичигч, CAS
  return st.nightResult(s.night)!.report;
}
```

**`EngineStateCorrupt`-ыг чимээгүйхэн засах нь хамгийн хортой алдаа байх болно.** Хэрэв `inputHash` зөрвөл өгөгдлийн сан ба бүртгэл зөрчилдсөн гэсэн үг. Тэр үед хийх зөв зүйл нь: `GameCreated`-аас эхлээд бүх `IntentSubmitted`-ыг дахин тоглуулж, шөнө бүрийг дахин шийдвэрлэж, `resultHash`-уудыг харьцуулах. Дэлгэц: **«Тоглолтыг эхнээс нь дахин уншиж байна.»** ~1 секунд, 20 суудал, 10 шөнө.

**Гурван кэшийн давхарга, тодорхой:**

| Давхарга | Хаана | Хэзээ бичигдэнэ |
|---|---|---|
| `event` хүснэгт | SQLite | суудал товших мөчид, синхроноор |
| `night_result(night PK, input_hash, report_json)` | SQLite | лацдсаны дараа, нэг л удаа |
| `NightReport` объект | RAM | дэлгэц зурахад |

Дахин нээхэд апп **үргэлж** `event`-ээс `NightState`-ыг дахин барина, `night_result`-аас тайланг авна. RAM-д хадгалсан зүйлд хэзээ ч итгэхгүй.
