// Ботын ТАРХИ — ЦЭВЭР.
//
// ЭНЭ ФАЙЛ `GameRoom`-ЫГ НЭРЛЭЖ БОЛОХГҮЙ. Сервер бүх тоглогчийн дүрийг
// мэддэг; хэрэв бот түүн рүү хүрч чадвал энэ нь илрүүлэх аргагүй хууран
// мэхлэлт болно — бас бот үргэлж ялдаг тул туршилтын хэрэгсэл болохоо
// болино.
//
// Тиймээс тархи нь ГАНЦ [BotView]-ээс өөр юу ч хардаггүй бөгөөд тэр нь
// жинхэнэ утас харах ЯГ ТЭР мэдээллийг агуулна. `myRole` нь ГАНЦ утга,
// `Map<Seat, Role>` БИШ — өөр суудлын дүр орох ГАЗАР БАЙХГҮЙ.
//
// Үүнийг `test/bot_test.dart` доторх эх кодын шалгалт хамгаална: энэ файл
// `GameRoom`, `_secrets`, `debugRoleOf` гэсэн мөр агуулбал тест унана.
//
// Санамсаргүй тоог `eng.Rng`-ээс авна, `dart:math`-аас БИШ: ингэснээр
// нэг үртэй тоглолт ЯГ давтагдаж, тест найдвартай болно.

import 'package:engine/engine.dart' as eng;
import 'package:protocol/protocol.dart';

/// Бот юу санаж байгаа вэ.
///
/// Бүгд ӨӨРТ НЬ ИРСЭН мессежээс бүрдэнэ — жинхэнэ утас ижил зүйлийг
/// мэдэж чадна. Энд серверийн нууц хуримтлуулахгүй.
class BotMemory {
  /// Өчигдрийн санал: саналлагчийн суудал → түүний бай.
  final Map<int, int> lastDayVotes = <int, int>{};

  /// Шөнө алагдсан суудлууд.
  final Set<int> nightVictims = <int>{};

  /// Мөрдөгч: аль хэдийн шалгасан суудлууд.
  final Set<int> checked = <int>{};

  /// Мөрдөгч: «мөр олдсон» гэсэн хариу авсан суудлууд.
  final Set<int> traceFound = <int>{};

  /// Мөрдөгч: «мөр олдсонгүй».
  final Set<int> traceNotFound = <int>{};

  /// Эмч: сүүлд хэнийг эмчилсэн.
  int? lastHeal;

  /// Мөрдөгч: сүүлд хэнийг асуусан (хариу ирэхээр нь бүртгэнэ).
  int? lastCheck;
}

/// Бот юу ХАРАХ вэ.
class BotView {
  const BotView({
    required this.mySeat,
    required this.myRole,
    required this.phase,
    required this.aliveSeats,
    required this.mem,
    this.myAllies = const <int>{},
    this.allyPicks = const <int, int>{},
    this.liveVotes = const <int, int>{},
  });

  final int mySeat;

  /// ЗӨВХӨН ӨӨРИЙН дүр. Ганц утга — өөр хүний дүр энд багтахгүй.
  final eng.Role myRole;

  final NetPhase phase;

  /// Амьд суудлууд, ӨСӨХ дарааллаар.
  final List<int> aliveSeats;

  /// Зөвхөн мафид дүүрнэ.
  final Set<int> myAllies;

  /// Хамтрагчийн сонголт: үйлдэгчийн суудал → бай. ЗӨВХӨН мафид.
  ///
  /// Энэ нь өрөө аль хэдийн `mafiaPick` мессежээр мафид илгээдэг ЯГ ТЭР
  /// мэдээлэл (`room.dart`). Шинэ суваг нээгээгүй.
  final Map<int, int> allyPicks;

  /// Өнөөдрийн санал: саналлагчийн суудал → бай. НИЙТИЙН мэдээлэл.
  final Map<int, int> liveVotes;

  final BotMemory mem;
}

/// Ботын гаргах шийдвэр.
sealed class BotCommand {
  const BotCommand();
}

class BotNight extends BotCommand {
  const BotNight(this.targetSeat);
  final int targetSeat;
}

class BotVote extends BotCommand {
  const BotVote(this.targetSeat);
  final int targetSeat;
}

/// Нэг ботын хувийн байдал — өрөө үүнийг хадгална.
class BotSeat {
  BotSeat(this.id, this.rng);

  final PlayerId id;
  final eng.Rng rng;
  final BotMemory mem = BotMemory();

  int seat = -1;
  int actAtMs = -1;
  bool acted = false;

  /// Үе шат эхлэхэд хэзээ үйлдэхээ шийднэ.
  ///
  /// Бот ТЭР ДОР НЬ хариулахгүй: шууд товшилт нь «энэ бол бот» гэж
  /// хэлээд өгнө, бас ширээ амьгүй санагдана. Гэхдээ эцсийн хугацаанаас
  /// өмнө заавал амжина.
  void schedule(int nowMs, int phaseMs) {
    final int span = phaseMs - 2200;
    final int jitter = span > 1 ? rng.below(span) : 0;
    final int latest = nowMs + (phaseMs > 1400 ? phaseMs - 1200 : 0);
    final int wanted = nowMs + 800 + jitter;
    actAtMs = wanted > latest ? latest : wanted;
    acted = false;
  }

  bool due(int nowMs) => !acted && seat > 0 && nowMs >= actAtMs;
}

// --- Шийдвэр -----------------------------------------------------------------

/// Бот юу хийх вэ. Хийх зүйлгүй бол `null`.
BotCommand? decideBot(BotView v, eng.Rng rng) {
  if (!v.aliveSeats.contains(v.mySeat)) return null;

  switch (v.phase) {
    case NetPhase.nightMafia:
      if (eng.factionOf(v.myRole) != eng.Faction.mafi) return null;
      final int? t = _mafiaPick(v, rng);
      return t == null ? null : BotNight(t);

    case NetPhase.nightDoctor:
      if (v.myRole != eng.Role.doctor) return null;
      final int? t = _doctorPick(v, rng);
      return t == null ? null : BotNight(t);

    case NetPhase.nightDetective:
      if (v.myRole != eng.Role.detective) return null;
      final int? t = _detectivePick(v, rng);
      return t == null ? null : BotNight(t);

    case NetPhase.vote:
      final int? t = _votePick(v, rng);
      return t == null ? null : BotVote(t);

    default:
      return null;
  }
}

/// Мафи ХАМТАРНА.
///
/// Хамтрагч аль хэдийн сонгосон бол ТҮҮНИЙГ дагана. Салангид санал өгвөл
/// `pickVictim` тэнцлийг дарааллын сэлгэцээр тайлж, шөнө санамсаргүй
/// харагдана — хоёр алуурчин хамтарч шийддэг гэсэн дүрмийн утга алдагдана.
int? _mafiaPick(BotView v, eng.Rng rng) {
  final List<int> cands = v.aliveSeats
      .where((int s) => s != v.mySeat && !v.myAllies.contains(s))
      .toList();
  if (cands.isEmpty) return null;

  // Хамгийн бага суудалтай хамтрагчийн сонголт давамгайлна — тогтмол
  // дүрэм байвал хоёулаа ижил дүгнэлтэд хүрнэ.
  final List<int> actors = v.allyPicks.keys.toList()..sort();
  for (final int a in actors) {
    final int t = v.allyPicks[a]!;
    if (cands.contains(t)) return t;
  }

  final Map<int, int> score = <int, int>{};
  for (final int s in cands) {
    int w = 1;
    // Өчигдөр бидний эсрэг санал өгсөн хүн аюултай.
    final int? voted = v.mem.lastDayVotes[s];
    if (voted != null && (voted == v.mySeat || v.myAllies.contains(voted))) {
      w += 5;
    }
    score[s] = w;
  }
  return _weightedPick(score, rng);
}

/// Эмч: өчигдөр хамгийн их дайрагдсан хүнийг хамгаална.
int? _doctorPick(BotView v, eng.Rng rng) {
  final List<int> cands =
      v.aliveSeats.where((int s) => s != v.mem.lastHeal).toList();
  if (cands.isEmpty) return null;

  final Map<int, int> against = <int, int>{};
  for (final int target in v.mem.lastDayVotes.values) {
    against[target] = (against[target] ?? 0) + 1;
  }

  final Map<int, int> score = <int, int>{};
  for (final int s in cands) {
    int w = 2 + (against[s] ?? 0) * 3;
    if (s == v.mySeat) w = w > 1 ? w - 1 : 1;
    score[s] = w;
  }
  return _weightedPick(score, rng);
}

/// Мөрдөгч: давтаж асуухгүй, чимээгүй хүнийг эхэлж шалгана.
int? _detectivePick(BotView v, eng.Rng rng) {
  final List<int> cands = v.aliveSeats
      .where((int s) => s != v.mySeat && !v.mem.checked.contains(s))
      .toList();
  if (cands.isEmpty) return null;

  final Map<int, int> score = <int, int>{};
  for (final int s in cands) {
    score[s] = 2 + (v.mem.lastDayVotes.containsKey(s) ? 0 : 2);
  }
  return _weightedPick(score, rng);
}

/// Санал.
///
/// ТЭНЦВЭЛ ХЭН Ч ХАСАГДАХГҮЙ (`room.dart`-ын санал тоолох хэсэг). Тиймээс
/// тэргүүлэгчийг ДАГАХ нь заавал байх ёстой дүрэм — эс бөгөөс санамсаргүй
/// саналууд хэзээ ч нийлэхгүй, өдөр бүр тэнцэж, тоглоом урагшлахгүй.
int? _votePick(BotView v, eng.Rng rng) {
  final List<int> cands =
      v.aliveSeats.where((int s) => s != v.mySeat).toList();
  if (cands.isEmpty) return null;

  final Map<int, int> here = <int, int>{};
  for (final int t in v.liveVotes.values) {
    here[t] = (here[t] ?? 0) + 1;
  }

  final Map<int, int> score = <int, int>{};
  for (final int s in cands) {
    if (v.myAllies.contains(s)) {
      score[s] = 0;                         // хамтрагчаа өгөхгүй
      continue;
    }
    if (v.mem.traceNotFound.contains(s)) {
      score[s] = 0;                         // цэвэр гэж мэдсэн
      continue;
    }
    int w = 1;
    if (v.mem.traceFound.contains(s)) w += 50;
    if (!v.mem.lastDayVotes.containsKey(s)) w += 1;
    w += (here[s] ?? 0) * 2;
    score[s] = w;
  }

  // Тэргүүлэгч бий бол дагана.
  int? leader;
  int best = 1;
  final List<int> sorted = here.keys.toList()..sort();
  for (final int s in sorted) {
    if (here[s]! > best) {
      best = here[s]!;
      leader = s;
    }
  }
  if (leader != null && (score[leader] ?? 0) > 0) return leader;

  return _weightedPick(score, rng);
}

/// Жинтэй сонголт. Дараалал нь ТОГТМОЛ — тест давтагдахуйц байх ёстой.
int? _weightedPick(Map<int, int> score, eng.Rng rng) {
  final List<int> keys = score.keys.toList()..sort();
  int total = 0;
  for (final int k in keys) {
    total += score[k]!;
  }
  if (total <= 0) {
    return keys.isEmpty ? null : keys[rng.below(keys.length)];
  }
  int roll = rng.below(total);
  for (final int k in keys) {
    roll -= score[k]!;
    if (roll < 0) return k;
  }
  return keys.last;
}
