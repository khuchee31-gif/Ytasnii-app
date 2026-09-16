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

  /// СҮҮЛЧИЙН ШӨНИЙН шивнээ. НИЙТИЙН мэдээлэл — `nightResult` нь
  /// үүнийг бүх утас руу илгээдэг.
  ///
  /// ЗӨВХӨН СҮҮЛЧИЙНХ: өмнө нь шөнө бүрийн шивнээг ХУРИМТЛУУЛДАГ
  /// байв. Дөрөв дэх шөнө гэхэд ширээний хагас нь тэр олонлогт орж,
  /// «сэжигтэй» гэдэг үг утгаа алддаг. Хүн ч гэсэн хамгийн сүүлийн
  /// үүрийн нэрийг л санадаг.
  final Set<int> whispered = <int>{};

  /// Саатуулагч: сүүлд хэнийг барьсан. Дараалан давтахаас сэргийлнэ.
  int? lastBlock;

  /// Шинэ тоглолт — БҮГДИЙГ мартана.
  ///
  /// Үлдээвэл бот өнгөрсөн тоглолтын «мөр олдлоо» гэсэн мэдээллээр
  /// шинэ тоглолтод сэжиглэж, ширээнд тайлбарлах боломжгүй зан
  /// гаргана.
  void reset() {
    lastDayVotes.clear();
    nightVictims.clear();
    checked.clear();
    traceFound.clear();
    traceNotFound.clear();
    whispered.clear();
    lastHeal = null;
    lastCheck = null;
    lastBlock = null;
  }
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
    this.iAmRevealed = false,
    this.voteCandidates = const <int>[],
    this.night = 1,
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

  /// Би аль хэдийн илчилсэн үү. НИЙТИЙН мэдээлэл (`roomState.revealed`).
  final bool iAmRevealed;

  /// ДАХИН САНАЛ. Хоосон бол чөлөөт. НИЙТИЙН (`voteState.candidates`).
  final List<int> voteCandidates;

  /// Хэддүгээр шөнө вэ. НИЙТИЙН — үе шатны дараалал бүгдэд ил.
  final int night;

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

/// Өдрийн үйлдэл: дарга өөрийгөө илчилнэ.
class BotReveal extends BotCommand {
  const BotReveal();
}

/// Дохио. `targetSeat` нь зөвхөн заалтад утгатай.
class BotEmote extends BotCommand {
  const BotEmote(this.kind, this.targetSeat);
  final String kind;
  final int? targetSeat;
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

  /// Дохионы хуваарь нь гол үйлдлээс ТУСДАА: гол үйлдэл нь шөнө, дохио
  /// нь өдөр болдог тул нэг цонхонд багтахгүй.
  int emoteAtMs = -1;
  bool emoted = true;

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

    // Дохиог үе шат бүрд гаргахгүй — таван удаагийн гурав нь. Бот бүр
    // үе шат бүрд дохивол ширээ цирк болно.
    emoted = rng.below(5) >= 3;
    final int espan = phaseMs - 1500;
    emoteAtMs = nowMs + 600 + (espan > 1 ? rng.below(espan) : 0);
  }

  bool due(int nowMs) => !acted && seat > 0 && nowMs >= actAtMs;

  bool dueEmote(int nowMs) => !emoted && seat > 0 && nowMs >= emoteAtMs;
}

// --- Шийдвэр -----------------------------------------------------------------

/// Бот юу хийх вэ. Хийх зүйлгүй бол `null`.
BotCommand? decideBot(BotView v, eng.Rng rng) {
  if (!v.aliveSeats.contains(v.mySeat)) return null;

  switch (v.phase) {
    case NetPhase.nightMafia:
      if (eng.factionOf(v.myRole) == eng.Faction.mafi) {
        final int? t = _mafiaPick(v, rng);
        return t == null ? null : BotNight(t);
      }
      // МАНААЧ мафитай нэг үе шатанд буудна.
      if (v.myRole == eng.Role.vigilante) {
        final int? t = _vigilantePick(v, rng);
        return t == null ? null : BotNight(t);
      }
      return null;

    case NetPhase.nightDoctor:
      // Эмч ба Саатуулагч НЭГ үе шатанд сэрнэ.
      if (v.myRole == eng.Role.doctor) {
        final int? t = _doctorPick(v, rng);
        return t == null ? null : BotNight(t);
      }
      if (v.myRole == eng.Role.blocker) {
        final int? t = _blockerPick(v, rng);
        return t == null ? null : BotNight(t);
      }
      return null;

    case NetPhase.nightDetective:
      // Мөрдөгч ба Ажиглагч НЭГ үе шатанд сэрнэ.
      if (v.myRole == eng.Role.detective) {
        final int? t = _detectivePick(v, rng);
        return t == null ? null : BotNight(t);
      }
      if (v.myRole == eng.Role.watcher) {
        final int? t = _watcherPick(v, rng);
        return t == null ? null : BotNight(t);
      }
      // ИРГЭН БА ДАРГА — «хотын шивнээ»-нд товшино. Ботууд ч товших
      // ёстой: эс бөгөөс ботоор дүүрсэн ширээн дээр шивнээ нь зөвхөн
      // хүний товшилтыг тоолж, тэр хүнийг илчилнэ.
      if (v.myRole == eng.Role.citizen || v.myRole == eng.Role.mayor) {
        final int? t = _suspectPick(v, rng);
        return t == null ? null : BotNight(t);
      }
      return null;

    case NetPhase.vote:
      // ДАРГА: над руу санал ирж байвал илчилнэ. Энэ нь яг тэр мөчид
      // хийх ёстой зүйл — илчлэлт нь түүний амийг аврах ганц арга.
      //
      // `myRole`-ыг уншиж байгаа нь ЗӨВ: бот ӨӨРИЙН дүрээр үйлддэг.
      // Хориотой нь БУСДЫН дүрийг унших.
      if (v.myRole == eng.Role.mayor && !v.iAmRevealed && _underFire(v)) {
        return const BotReveal();
      }
      final int? t = _votePick(v, rng);
      return t == null ? null : BotVote(t);

    default:
      return null;
  }
}

/// Над руу хамгийн олон санал ирж байна уу.
///
/// ЗӨВХӨН НИЙТИЙН мэдээллээс: `liveVotes` нь `voteState`-ээр бүх утас
/// руу явдаг.
bool _underFire(BotView v) {
  if (v.liveVotes.isEmpty) return false;
  final Map<int, int> tally = <int, int>{};
  for (final int t in v.liveVotes.values) {
    tally[t] = (tally[t] ?? 0) + 1;
  }
  final int mine = tally[v.mySeat] ?? 0;
  if (mine == 0) return false;
  final int top = tally.values.reduce((int a, int b) => a > b ? a : b);
  return mine >= top;
}

/// Манаач буудах уу, хэн рүү вэ.
///
/// ЗӨВХӨН НИЙТИЙН мэдээллээр шийднэ: өчигдрийн санал (`lastDayVotes`)
/// нь `voteState`-ээр бүх утас руу явсан. Бот нь хүнээс илүү юу ч
/// мэдэхгүй.
///
/// ХЭЗЭЭ БУУДАХГҮЙ ВЭ: гурав дахь шөнөөс өмнө. Эхний шөнө хөдөлгүүр
/// хориглоно (`nightTooEarly`); хоёр дахь шөнө мэдээлэл дутуу байдаг
/// тул буудах нь цэвэр мөрийтэй тоглоом. Хотынхны хүнийг буудвал
/// ХОЁР хүн алдана — хохирогч ба гэмшсэн Манаач.
int? _vigilantePick(BotView v, eng.Rng rng) {
  if (v.night < 3) return null;
  final Map<int, int> tally = <int, int>{};
  for (final int t in v.mem.lastDayVotes.values) {
    if (v.aliveSeats.contains(t) && t != v.mySeat) {
      tally[t] = (tally[t] ?? 0) + 1;
    }
  }
  if (tally.isEmpty) return null;
  final int top = tally.values.reduce((int a, int b) => a > b ? a : b);
  // ХАГАСААС ДЭЭШ санал авсан хүн л зорилт болно. Эргэлзээтэй үед
  // буудахгүй байх нь ХАМГИЙН сайн сонголт.
  if (top * 2 <= v.aliveSeats.length) return null;
  final List<int> best = tally.entries
      .where((MapEntry<int, int> e) => e.value == top)
      .map((MapEntry<int, int> e) => e.key)
      .toList()
    ..sort();
  // Гурван удаагийн нэгд л буудна — өдөр бүр буудвал хоёр сум хоёр
  // шөнөд дуусч, дүр нь утгагүй болно.
  if (rng.below(3) != 0) return null;
  return best[rng.below(best.length)];
}

/// Ажиглагч хэнийг ажиглах вэ.
///
/// Хамгийн олон анхаарал татсан суудлыг ажиглана: мафи тэр хүн рүү
/// очих магадлал өндөр. Санах ойд юу ч байхгүй бол санамсаргүй.
///
/// ӨӨРИЙН ДҮРЭЭС өөр юу ч уншихгүй — `myAllies`, `allyPicks` хоёрт
/// хүрэхгүй (Ажиглагч хэзээ ч мафи биш тул тэд хоосон боловч дүрмээ
/// кодоор барих нь дээр).
/// ИРГЭН: хэнийг сэжиглэх вэ.
///
/// ЗӨВХӨН НИЙТИЙН мэдээллээс: өчигдөр над руу санал өгсөн хүн, өчигдөр
/// шивнээнд гарсан хүн. Бот дотоод төлөв уншвал ширээ түүнийг «хэтэрхий
/// сайн таамагладаг» гэж мэдэрнэ.
int? _suspectPick(BotView v, eng.Rng rng) {
  final List<int> cands =
      v.aliveSeats.where((int s) => s != v.mySeat).toList()..sort();
  if (cands.isEmpty) return null;

  // 1. Өчигдөр НАД РУУ санал өгсөн хүн. Хамгийн хувийн шалтгаан.
  final List<int> hot = <int>[
    for (final MapEntry<int, int> e in v.mem.lastDayVotes.entries)
      if (e.value == v.mySeat && cands.contains(e.key)) e.key,
  ]..sort();
  if (hot.isNotEmpty) return hot[rng.below(hot.length)];

  // 2. Өчигдөр ХАМГИЙН ОЛОН санал авсан хүн.
  //
  // ЯАГААД ЭНЭ ЧУХАЛ ВЭ: шивнээ нь ТОХИРОЛЦОО шаарддаг. Бот бүр
  // санамсаргүй сонговол хэзээ ч тохирохгүй бөгөөд механик нь
  // ботын ширээн дээр огт ажиллахгүй. Өдрийн санал бол НИЙТИЙН
  // мэдээлэл — жинхэнэ ширээ ч яг үүгээр тохирдог («өчигдөр бүгд
  // Батыг сэжиглэж байсан шүү дээ»).
  final Map<int, int> tally = <int, int>{};
  for (final int t in v.mem.lastDayVotes.values) {
    if (cands.contains(t)) tally[t] = (tally[t] ?? 0) + 1;
  }
  if (tally.isNotEmpty) {
    final int best = tally.values.reduce((int a, int b) => a > b ? a : b);
    final List<int> top = <int>[
      for (final MapEntry<int, int> e in tally.entries)
        if (e.value == best) e.key,
    ]..sort();
    return top[rng.below(top.length)];
  }

  // 3. Өчигдөр шивнээнд гарсан хүн.
  final List<int> warm = v.mem.whispered.where(cands.contains).toList()..sort();
  if (warm.isNotEmpty) return warm[rng.below(warm.length)];

  // 4. Эхний шөнө — юу ч мэдэхгүй.
  return cands[rng.below(cands.length)];
}

/// СААТУУЛАГЧ: сэжигтэй хүнийг барина.
///
/// Түүний эрсдэл нь хотынхныг саатуулах — эмчийг барьвал хохирогч үхнэ.
/// Тиймээс өчигдөр УСТГАГДААГҮЙ, гэвч шивнээнд гарсан хүнийг эхэлж
/// авна: шивнээ бол нийтийн мэдээлэл тул бот давуу эрх эдлэхгүй.
///
/// НЭГ ХҮНИЙГ ДАВТАЖ БАРИХГҮЙ: хоёр шөнө дараалан нэг хүн «болсонгүй»
/// гэсэн мессеж авбал тэр хүн өөрийгөө чадвартай гэдгээ мэдээд зогсохгүй
/// хэн саатуулж байгааг таах хүрээ нарийсна.
int? _blockerPick(BotView v, eng.Rng rng) {
  final List<int> cands = v.aliveSeats
      .where((int s) => s != v.mySeat && s != v.mem.lastBlock)
      .toList()
    ..sort();
  if (cands.isEmpty) return null;
  final List<int> hot = v.mem.whispered.where(cands.contains).toList()..sort();
  final int pick =
      hot.isNotEmpty ? hot[rng.below(hot.length)] : cands[rng.below(cands.length)];
  return pick;
}

int? _watcherPick(BotView v, eng.Rng rng) {
  final List<int> cands =
      v.aliveSeats.where((int s) => s != v.mySeat).toList()..sort();
  if (cands.isEmpty) return null;
  // Өчигдөр шивнээнд гарсан хүн байвал түүнийг ажиглана.
  final List<int> hot =
      v.mem.whispered.where(cands.contains).toList()..sort();
  if (hot.isNotEmpty) return hot[rng.below(hot.length)];
  return cands[rng.below(cands.length)];
}

/// Бот ямар дохио гаргах вэ. Гаргахгүй бол `null`.
///
/// ЭНЭ ФУНКЦ ДҮРИЙГ ОГТ УНШИХГҮЙ — `v.myRole`, `v.myAllies` хоёрт
/// хүрэхгүй. Яагаад гэвэл дохио нь БҮХ тоглогчид харагдана: хэрэв мафи
/// бот хамтрагч руугаа хэзээ ч заадаггүй бол хэдхэн өдрийн дараа
/// ажиглагч хүн «хэзээ ч бие бие рүүгээ заадаггүй хоёр» гэж мафиг
/// ялгана. Санамсаргүй заалт нь ХУУРАЛТ — жинхэнэ хүн ч мөн адил
/// хийдэг — бөгөөд ямар ч мэдээлэл алддаггүй.
BotEmote? decideEmote(BotView v, eng.Rng rng) {
  if (!v.aliveSeats.contains(v.mySeat)) return null;
  if (v.phase != NetPhase.day &&
      v.phase != NetPhase.vote &&
      v.phase != NetPhase.dawn) {
    return null;
  }

  final List<int> others =
      v.aliveSeats.where((int s) => s != v.mySeat).toList()..sort();
  // Таван удаагийн хоёр нь заалт — бусад нь ерөнхий дохио.
  if (others.isNotEmpty && rng.below(5) < 2) {
    return BotEmote(Emote.point, others[rng.below(others.length)]);
  }
  const List<String> plain = <String>[
    Emote.yes,
    Emote.no,
    Emote.shrug,
    Emote.hand,
    Emote.laugh,
  ];
  return BotEmote(plain[rng.below(plain.length)], null);
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
  List<int> cands = v.aliveSeats.where((int s) => s != v.mySeat).toList();
  // ДАХИН САНАЛ: зөвхөн тэнцсэн нэрсээс. Сервер ч шалгана — энэ нь
  // зөвхөн бот дэмий татгалзал авахгүйн тулд.
  if (v.voteCandidates.isNotEmpty) {
    cands = cands.where(v.voteCandidates.contains).toList();
    // Бот өөрөө нэр дэвшсэн бол өөрийгөө өгөхгүй — сонголтгүй үлдэнэ.
    if (cands.isEmpty) return null;
  }
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
    // ӨЧИГДРИЙН ШИВНЭЭ. Энэ нь ширээний НИЙТИЙН сэжиг — жинхэнэ
    // тоглогч ч яг үүгээр эхэлдэг («өчигдөр бүгд Батыг сэжиглэсэн
    // шүү дээ»). Бот үүнийг ашиглахгүй бол шивнээ нь ботын ширээн
    // дээр ямар ч үр дагаваргүй чимэглэл болно.
    if (v.mem.whispered.contains(s)) w += 6;
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
