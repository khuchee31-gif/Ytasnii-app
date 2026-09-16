// «Хот унтлаа» — хөдөлгүүрийн төрлүүд.
//
// Эх сурвалж: docs/gdd/05-engine.md §2. Энэ файл бол ГЭРЭЭ — бусад бүх файл
// үүн дээр тогтоно. Өөрчлөх бол эхлээд GDD-05-ыг өөрчил.
//
// ХАТУУ ДҮРЭМ (GDD-05 §0):
//   • IO байхгүй, `DateTime.now()` байхгүй, `Random()` байхгүй, `double` байхгүй.
//   • Flutter-ээс хамаарахгүй, `dart:io`-гүй.
//   • Бүх класс immutable.

import 'dart:typed_data';

/// Дэлгэцэн дээрх суудлын дугаар, 1..20. **Индекс биш.**
typedef Seat = int;

enum Role { killer, boss, doctor, detective, citizen }

enum Faction { mafi, hotynhon }

enum Ability { mafiaKill, heal, investigate, suspect, noAction }

/// v1-д зөвхөн `none` ба `basic` ажиллана. `powerful` нь v2-ын зай —
/// хөдөлгүүр түүнийг хэзээ ч гаргахгүй (инвариант N13).
enum AttackLevel { none, basic, powerful }

enum DefenseLevel { none, basic }

enum DeathTag { mafi }

enum WinState { none, mafi, hotynhon }

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
}

/// v1-д ЗӨВХӨН эдгээр хоёр мессеж гарна (GDD-05 §9.2, инвариант N15).
enum MsgCode { traceFound, traceNotFound }

/// Дүрээс фракц. Цэвэр функц — хөдөлгүүрийн хаанаас ч дуудагдана.
Faction factionOf(Role r) =>
    (r == Role.killer || r == Role.boss) ? Faction.mafi : Faction.hotynhon;

/// Дүр бүрийн шөнийн чадвар (GDD-05 §1-ийн хүснэгт).
Ability abilityOf(Role r) => switch (r) {
      Role.killer => Ability.mafiaKill,
      Role.boss => Ability.mafiaKill,
      Role.doctor => Ability.heal,
      Role.detective => Ability.investigate,
      Role.citizen => Ability.suspect,
    };

/// Эрэмбийн шатны хувин (GDD-05 §3.2).
/// 20–80, 110, 140–150 нь v1-д ХООСОН — N13 шалгана.
int bucketOf(Ability a) => switch (a) {
      Ability.heal => 90,
      Ability.mafiaKill => 100,
      Ability.investigate => 130,
      Ability.suspect => 135,
      Ability.noAction => 135,
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

  const NightState({
    required this.setup,
    required this.night,
    required this.alive,
    required this.seed,
    required this.orderPerm,
    this.lastHealTarget = const {},
    this.selfHealUsed = const {},
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
