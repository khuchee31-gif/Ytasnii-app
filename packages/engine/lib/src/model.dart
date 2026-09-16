// «Хот унтлаа» — хөдөлгүүрийн төрлүүд.
//
// Эх сурвалж: docs/gdd/05-engine.md §2. Энэ файл бол ГЭРЭЭ — бусад бүх файл
// үүн дээр тогтоно. Өөрчлөх бол эхлээд GDD-05-ыг өөрчил.
//
// ХАТУУ ДҮРЭМ (GDD-05 §0):
//   • IO байхгүй, `DateTime.now()` байхгүй, `Random()` байхгүй, `double` байхгүй.
//   • Flutter-ээс хамаарахгүй, `dart:io`-гүй.
//   • Бүх класс immutable.
//
// ENUM-Д ЗӨВХӨН АРААС НЬ НЭМНЭ, ДУНД НЬ ХЭЗЭЭ Ч ОРУУЛАХГҮЙ.
//
//   • `deckFor` (rosters.dart) нь `Role`-ын дарааллаар хөзөр угсардаг;
//     дунд нь оруулбал бүх тоглолт өөр тарагдаж, `deal_test.dart`-ийн
//     гурван АЛТАН ВЕКТОР зэрэг улаан болно.
//   • `_byTuple` (resolve.dart) нь `ability.index`-ыг гурав дахь түлхүүр
//     болгон уншдаг.
//
// Араас нь нэмэх нь hash-д АЮУЛГҮЙ: `canon` нь enum-ыг `.name`-ээр
// бичдэг тул индекс байтад ордоггүй.

import 'dart:typed_data';

/// Дэлгэцэн дээрх суудлын дугаар, 1..20. **Индекс биш.**
typedef Seat = int;

/// Дүрүүд. ШИНИЙГ ЗӨВХӨН АРААС НЬ нэмнэ (файлын толгойг үз).
///
/// МАФИЙН ТАЛД ШИНЭ ДҮР НЭМЭХГҮЙ — хүчтэй мафи дүр нь энгийн алуурчны
/// СУУДЛЫГ ОРЛОНО, тоог нь нэмэхгүй (GDD-02). `boss` яг ингэж орсон.
enum Role {
  killer,
  boss,
  doctor,
  detective,
  citizen,

  /// v2 — Ажиглагч. Нэг суудлыг сонгоод, тэр шөнө ХЭН ТҮҮН РҮҮ ОЧСОНЫГ
  /// үүрээр мэднэ. Өөрөө зочлолын бүртгэлд ОРОХГҮЙ (resolve.dart §130).
  watcher,

  /// v3 — Саатуулагч. Шөнө нэг хүний ҮЙЛДЛИЙГ зогсооно.
  ///
  /// Хамгийн хүчтэй хотын дүр: мафийн алалтыг ч зогсоож чадна. Гэхдээ
  /// буруу хүнийг саатуулбал эмчийг зогсоож, хотынхныг өөрсдөөр нь
  /// алуулна.
  blocker,

  /// v3 — Манаач. Шөнө хоёр удаа буудаж чадна (эхний шөнө БИШ).
  ///
  /// ХОТЫНХНЫ ХҮНИЙГ буудвал дараагийн шөнө ГЭМШЛЭЭСЭЭ үхнэ, бөгөөд
  /// тэр үхлийг ЭМЧЛЭХ БОЛОМЖГҮЙ. Эрсдэл ба үр дагаврыг ширээнд заах
  /// цорын ганц дүр.
  vigilante,

  /// v2 — Хотын дарга. ШӨНИЙН ҮЙЛДЭЛ БАЙХГҮЙ (иргэнтэй яг адил тул
  /// шөнийн цагаар ялгарахгүй). Өдөр НЭГ УДАА өөрийгөө илчилж болно;
  /// тэр цагаас хойш түүний санал ГУРАВ болно.
  ///
  /// Илчлэлт нь НИЙТИЙНХ — тиймээс ялалтын нөхцөл түүнийг мэдэх ёстой
  /// (`evaluateWin`). Эс бөгөөс мафи тоогоороо тэнцсэн ч дарга саналаар
  /// тэднийг дийлсээр байх бөгөөд тоглоом дуусахгүй.
  mayor,
}

enum Faction { mafi, hotynhon }

enum Ability {
  mafiaKill,
  heal,
  investigate,
  suspect,
  noAction,

  /// v2 — Ажиглагч. Хувин 130, зочлол БИЧИХГҮЙ.
  watch,

  /// v3 — Манаачийн буудлага. Хувин 100 — мафитай ЗЭРЭГ буудна.
  vigilanteKill,

  /// v3 — Саатуулалт. Хувин 60 — БҮХ бусад үйлдлээс ӨМНӨ.
  roleblock,
}

/// v1-д зөвхөн `none` ба `basic` ажиллана. `powerful` нь v2-ын зай —
/// хөдөлгүүр түүнийг хэзээ ч гаргахгүй (инвариант N13).
enum AttackLevel { none, basic, powerful }

enum DefenseLevel { none, basic }

/// Үхлийн ЭХ СУРВАЛЖ. Дэлгэц дээр ХЭЗЭЭ Ч харагдахгүй — зөвхөн
/// хөдөлгүүрийн дотоод, инвариантын шалгалтад.
enum DeathTag {
  /// Мафийн алалт.
  mafi,

  /// Манаачийн буудлага.
  vigilante,

  /// Манаач хотынхны хүнийг буудсны дараах өөрийн үхэл. ЭМЧЛЭГДЭХГҮЙ.
  remorse,
}

enum WinState {
  none,
  mafi,
  hotynhon,

  /// БҮГД ҮХЭВ. Манаач сүүлчийн хотынхны хүнийг буудаж, мафи түүнийг
  /// алаад, гэмшил нь гурав дахийг авах зэрэг тохиолдол. Ховор боловч
  /// БОДИТОЙ — тэр үед «мафи ялав» гэж хэлэх нь худал.
  draw,
}

/// Мафи хэнийг алахаа хэрхэн шийдэх вэ (GDD-05 §4).
enum FactionRule { mafiaMajority, designatedKiller }

/// Эмч өөрийгөө аврах эрх (GDD-03-ын гэрийн дүрэм).
enum SelfHeal { unlimited, once, never }

enum RejectCode {
  actorDead,
  targetDead,
  targetSelf,
  targetSameFaction,
  notYourAbility,
  healRepeat,
  nightSealed,
  seatNotInGame,

  /// Манаачийн сум дууссан.
  chargeSpent,

  /// Манаач ЭХНИЙ шөнө буудаж болохгүй — өдрийн яриа болоогүй байхад
  /// буудах нь цэвэр мөрийтэй тоглоом.
  nightTooEarly,
}

/// Хувийн мессежийн кодууд (GDD-05 §9.2, инвариант N15).
enum MsgCode {
  /// Мөрдөгч: бай нь мафи.
  traceFound,

  /// Мөрдөгч: бай нь мафи БИШ.
  traceNotFound,

  /// Ажиглагч: `{'seat': n}` — тэр шөнө байг зочилсон нэг хүн.
  /// Хэдэн зочин байвал төдөн мессеж гарна.
  watchSaw,

  /// Ажиглагч: хэн ч очсонгүй.
  watchNobody,

  /// Саатуулагдсан хүнд: «чиний үйлдэл болсонгүй».
  ///
  /// ХЭН саатуулсныг ХЭЛЭХГҮЙ. Хэлбэл Саатуулагч эхний шөнөдөө
  /// илчлэгдэх бөгөөд мафийн эхний бай болно.
  roleblocked,
}

/// Дүрээс фракц. Цэвэр функц — хөдөлгүүрийн хаанаас ч дуудагдана.
///
/// МАФИЙГ НЭРЛЭЖ ЖАГСААНА, хотынхныг биш. Ингэснээр шинэ дүр нэмэхэд
/// АНХДАГЧААР хотынхон болно: мартагдсан дүр нь тоглоомыг тэнцвэргүй
/// болгохоос илүү, санамсаргүй мафи болох нь ХАВЬГҮЙ аюултай.
Faction factionOf(Role r) =>
    (r == Role.killer || r == Role.boss) ? Faction.mafi : Faction.hotynhon;

/// Дүр бүрийн шөнийн чадвар (GDD-05 §1-ийн хүснэгт).
Ability abilityOf(Role r) => switch (r) {
      Role.killer => Ability.mafiaKill,
      Role.boss => Ability.mafiaKill,
      Role.doctor => Ability.heal,
      Role.detective => Ability.investigate,
      Role.citizen => Ability.suspect,
      Role.watcher => Ability.watch,
      // ЯГ ИРГЭНИЙНХ. Шөнийн үйлдэл нэмбэл дарга шөнийн цагаар ялгарч,
      // түүний хүч нь ӨДРИЙНХ байхаа болино.
      Role.mayor => Ability.suspect,
      Role.vigilante => Ability.vigilanteKill,
      Role.blocker => Ability.roleblock,
    };

/// Эрэмбийн шатны хувин (GDD-05 §3.2).
/// 20–80, 110, 140–150 нь v1-д ХООСОН — N13 шалгана.
int bucketOf(Ability a) => switch (a) {
      // СААТУУЛАЛТ БҮХ ЗҮЙЛЭЭС ӨМНӨ. Тэр нь бусад хувингийн уншдаг
      // «хэн саатуулагдсан» гэсэн олонлогийг бэлдэнэ.
      Ability.roleblock => 60,
      Ability.heal => 90,
      Ability.mafiaKill => 100,
      Ability.investigate => 130,
      // Манаач МАФИТАЙ ЗЭРЭГ буудна. Хэн нэгнийг хоёулаа онивол
      // хоёр удаа үхэхгүй (N20) — 120-р хувин үүнийг барина.
      Ability.vigilanteKill => 100,
      // Ажиглагч нь Мөрдөгчтэй ИЖИЛ хувинд. Тиймээс тэр Мөрдөгчийг
      // ХЭЗЭЭ Ч харахгүй: 130-д орох мөчид зочлолын жагсаалт ХӨЛДӨНӨ
      // (resolve.dart). Эс бөгөөс Ажиглагч 2 дахь өдөр Мөрдөгчийн
      // суудлыг сайн санаагаар ширээнд зарлаж, 3 дахь шөнө нь мафи
      // түүнийг алах болно.
      Ability.watch => 130,
      Ability.suspect => 135,
      Ability.noAction => 135,
    };

/// Саатуулж БОЛОХ чадварууд.
///
/// `suspect`, `noAction` хоёр нь энд БАЙХГҮЙ: тэд юу ч хийдэггүй тул
/// саатуулах зүйл байхгүй. Иргэнд «саатуулагдлаа» гэж хэлбэл тэр
/// өөрийгөө чадвартай гэж эндүүрч, ширээнд худал мэдээлэл тарина.
///
/// `roleblock` нь мөн БАЙХГҮЙ — саатуулагчийг саатуулж болохгүй
/// (`resolve.dart` §60-ын тайлбарыг үз).
const Set<Ability> kBlockableAbilities = <Ability>{
  Ability.heal,
  Ability.investigate,
  Ability.watch,
  Ability.mafiaKill,
  Ability.vigilanteKill,
};

/// `1 > 1` худал тул эдгээлт нь `basic` довтолгоог ЧАНД цуцална (GDD-05 §3.1).
bool lethal(AttackLevel a, DefenseLevel d) => a.index > d.index;

// ---------------------------------------------------------------------------
// Оролт
// ---------------------------------------------------------------------------

/// Суудал илгээдэг зүйл. **Санаа, үр нөлөө биш** (GDD-05 §2).
/// Утас `{ability: mafiaKill, target: 7}` илгээнэ, «7 үхлээ» гэж хэзээ ч илгээхгүй.
class Intent {
  /// Идемпотентын түлхүүр. Клиент үүсгэнэ.
  final String intentId;
  final int night;
  final Seat actor;
  final Ability ability;

  /// `ability == noAction` үед л `null`.
  final Seat? target;

  /// Суудал тутам монотон; `(actor, ability)` тутам сүүлийнх нь хожино (N19).
  final int clientSeq;

  /// ЗӨВХӨН аудит. Эрэмбэлэхэд ХЭЗЭЭ Ч ашиглагдахгүй.
  final int submittedAtMs;

  const Intent({
    required this.intentId,
    required this.night,
    required this.actor,
    required this.ability,
    required this.target,
    required this.clientSeq,
    this.submittedAtMs = 0,
  });

  @override
  String toString() =>
      'Intent($intentId, n$night, $actor -> ${ability.name} ${target ?? "-"})';
}

/// Тоглолт эхлэхэд царцдаг тохиргоо (GDD-03 §6: `ROLE_DEAL` руу орох мөчид).
class Setup {
  final int n;

  /// НУУЦ. UI хэзээ ч бүтнээр рендерлэхгүй (GDD-10 §3).
  final Map<Seat, Role> roleBySeat;

  final FactionRule factionRule;
  final bool whisperOn;
  final bool narration;
  final int whisperMinAgree;
  final SelfHeal doctorSelfHeal;
  final bool mafiaFriendlyFire;

  /// Суудал бүрт ИЖИЛ. Жигд хуурмагийн үндэс (GDD-10 §4).
  final int nightSeatMs;

  const Setup({
    required this.n,
    required this.roleBySeat,
    this.factionRule = FactionRule.mafiaMajority,
    this.whisperOn = true,
    this.narration = true,
    this.whisperMinAgree = 3,
    this.doctorSelfHeal = SelfHeal.once,
    this.mafiaFriendlyFire = true,
    this.nightSeatMs = 6000,
  });

  int get mafiaCount =>
      roleBySeat.values.where((r) => factionOf(r) == Faction.mafi).length;

  Role? roleOf(Seat s) => roleBySeat[s];
}

/// Нэг шөнийн эхэн дэх төлөв. `resolveNight` үүнийг ХЭЗЭЭ Ч өөрчлөхгүй.
class NightState {
  final Setup setup;
  final int night;
  final Set<Seat> alive;

  /// Эмч тутам, өнгөрсөн шөнийн бай (`healRepeat`-ыг шалгахад).
  final Map<Seat, Seat> lastHealTarget;

  /// Эмч тутам, аль хэдийн хэдэн удаа өөрийгөө аварсан (`SelfHeal.once`).
  final Map<Seat, int> selfHealUsed;

  final Uint8List seed;

  /// seed-ээс гарсан, `GAME_CREATED`-д ил бичигдсэн бүрэн эрэмбэ.
  /// Тэнцэл тайлах ЦОРЫН ГАНЦ эх сурвалж — санамсаргүй тэнцэл хориотой.
  final List<Seat> orderPerm;

  /// Манаач тус бүрийн үлдсэн сум.
  final Map<Seat, int> bullets;

  /// ӨНӨӨ ШӨНӨ гэмшлээсээ үхэх суудлууд. Эмчлэгдэхгүй.
  final Set<Seat> remorse;

  /// Өөрийгөө ИЛЧИЛСЭН Хотын даргын суудлууд.
  ///
  /// НИЙТИЙН мэдээлэл — илчлэлт нь өдөр, бүх хүний өмнө болдог. Ялалтын
  /// нөхцөлд хэрэгтэй: илчилсэн дарга гурван саналтай тул мафи
  /// тоогоороо тэнцсэн ч өдрийг дийлэхгүй.
  final Set<Seat> revealedMayors;

  const NightState({
    required this.setup,
    required this.night,
    required this.alive,
    required this.seed,
    required this.orderPerm,
    this.lastHealTarget = const {},
    this.selfHealUsed = const {},
    this.revealedMayors = const {},
    this.bullets = const {},
    this.remorse = const {},
  });

  int rank(Seat s) => orderPerm.indexOf(s);

  Seat? aliveSeatWithRole(Role r) {
    for (final s in orderPerm) {
      if (alive.contains(s) && setup.roleOf(s) == r) return s;
    }
    return null;
  }
}

// ---------------------------------------------------------------------------
// Гаралт
// ---------------------------------------------------------------------------

class Death {
  final Seat victim;
  final Seat killer;
  final DeathTag tag;
  const Death(this.victim, this.killer, this.tag);
}

class Visit {
  final Seat from;
  final Seat to;
  final Ability ability;
  final bool harmful;
  const Visit(this.from, this.to, this.ability, {required this.harmful});
}

class Msg {
  final MsgCode code;
  final Map<String, int> params;
  const Msg(this.code, [this.params = const {}]);
}

/// Хөтлөгчийн дохио. **Чимээгүй нь хөдөлгүүрийн гаралт, UI-ийн код биш**
/// (GDD-05 §9.3, инвариант N14).
sealed class Cue {
  const Cue();

  /// Клипийн ID-г GDD-07 §2 эзэмшинэ.
  factory Cue.line(String clipId) = CueLine;

  factory Cue.silence(int ms, {int duckAmbienceDb}) = CueSilence;

  /// Дугаарууд ЗӨВХӨН дэлгэц дээр — хоолой хэзээ ч уншихгүй.
  factory Cue.screenSeats(List<Seat> seats) = CueScreenSeats;
}

class CueLine extends Cue {
  final String clipId;
  const CueLine(this.clipId);
}

class CueSilence extends Cue {
  final int ms;
  final int duckAmbienceDb;
  const CueSilence(this.ms, {this.duckAmbienceDb = 0});
}

class CueScreenSeats extends Cue {
  final List<Seat> seats;
  const CueScreenSeats(this.seats);
}

class NightReport {
  final int night;

  /// v1: 0 эсвэл 1 (инвариант N3).
  final List<Death> deaths;

  /// 0..2, СУУДЛЫН ДУГААРААР өсөхөөр (инвариант N8).
  final List<Seat> whisper;

  /// v1: ≤ 1 бичлэг, зөвхөн Мөрдөгч (инвариант N15).
  final Map<Seat, List<Msg>> privateMsgs;

  final List<Cue> cues;
  final List<Visit> visits;
  final WinState win;

  /// Лацдсаны дараах оролтын hash — идемпотентын түлхүүр (GDD-05 §8).
  final String inputHash;

  final String resultHash;

  /// Шийдвэрлэсний дараах амьд суудлууд.
  final Set<Seat> aliveAfter;

  /// Дараагийн шөнийн `lastHealTarget`.
  final Map<Seat, Seat> nextLastHeal;

  /// Дараагийн шөнийн `selfHealUsed`.
  final Map<Seat, int> nextSelfHealUsed;

  /// Дараагийн шөнийн `bullets`.
  final Map<Seat, int> nextBullets;

  /// Дараагийн шөнө гэмшлээсээ үхэх суудлууд.
  final Set<Seat> nextRemorse;

  const NightReport({
    required this.night,
    required this.deaths,
    required this.whisper,
    required this.privateMsgs,
    required this.cues,
    required this.visits,
    required this.win,
    required this.inputHash,
    required this.resultHash,
    required this.aliveAfter,
    required this.nextLastHeal,
    required this.nextSelfHealUsed,
    this.nextBullets = const {},
    this.nextRemorse = const {},
  });
}

/// `inputHash` таарахгүй бол ШИДНЭ. Чимээгүйхэн засах нь хамгийн хортой алдаа
/// байх болно (GDD-05 §8) — бүртгэлээс бүтнээр дахин тоглуулах ёстой.
class EngineStateCorrupt implements Exception {
  final int night;
  final String expected;
  final String actual;
  const EngineStateCorrupt(this.night, this.expected, this.actual);

  @override
  String toString() =>
      'EngineStateCorrupt(night $night: expected $expected, got $actual)';
}
