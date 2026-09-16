// «Хот унтлаа» — шийдвэрлэсэн шөнө бүр дээр ажилладаг инвариантууд.
//
// Эх сурвалж: GDD-13 §4-ийн N-цуврал (ЦОРЫН ГАНЦ дугаарлалт), GDD-05
// §10.1-ийн зураглалын хүснэгт. Хуучин `I`-дугаарыг иш татахгүй.
//
// Энэ модуль нь `resolveNight`-ийн **дараа** ажиллана: `assert(...)`-ийн
// дотроос дебаг билд дээр үргэлж, fuzz харнесс дээр илэн далангүй.
// Зөрчил бүр өөрийн N-ID-тайгаа шидэгдэнэ — унасан тест инвариантаа НЭРЛЭНЭ.
//
// ХАТУУ ДҮРЭМ (GDD-05 §0): IO байхгүй, `double` байхгүй, цэвэр функц.

import 'model.dart';
import 'resolve.dart';

/// Инвариант зөрчигдлөө. `id` нь GDD-13 §4-ийн N-дугаар («N14»).
class InvariantViolation implements Exception {
  final String id;
  final String detail;
  const InvariantViolation(this.id, this.detail);

  @override
  String toString() => 'InvariantViolation($id): $detail';
}

Never _fail(String id, String detail) => throw InvariantViolation(id, detail);

void _require(bool ok, String id, String detail) {
  if (!ok) _fail(id, detail);
}

/// Шийдвэрлэсэн шөнийг бүтнээр нь шалгана.
///
/// [sealed] нь **лацдсан** (шалгалт давсан, давхардал цэвэрлэгдсэн) санааны
/// жагсаалт — `resolveNight` өөрийн дотоод `a`-г дамжуулна. Дараалал нь
/// хамаарахгүй: шалгалт бүр дарааллаас үл хамааран бичигдсэн.
///
/// Шалгагдах инвариантууд (GDD-05 §10.1-ийн зураглал):
/// N3, N5, N6, N8, N10, N13, N14, N15, N19, N20, N21, N22.
void checkInvariants(NightState s0, List<Intent> sealed, NightReport r) {
  _checkN6(s0, sealed);
  _checkN19(sealed);
  _checkN22(s0, sealed);
  _checkN13(s0, sealed, r);
  _checkN3(r);
  _checkN20(s0, r);
  _checkN5(r);
  _checkN14(r);
  _checkN15(s0, r);
  _checkN21(s0, sealed, r);
  _checkN8(s0, sealed, r);
  _checkN10(s0, r);
}

// ---------------------------------------------------------------------------
// N3 — `deaths.length ∈ {0, 1}`
// ---------------------------------------------------------------------------

/// ЭХ СУРВАЛЖ БҮРЭЭС ХАМГИЙН ИХДЭЭ НЭГ ҮХЭЛ.
///
/// Мафи нэг бай сонгодог (`pickVictim`), Манаач нэг сум хэрэглэдэг,
/// гэмшил нь өөрийг нь л авдаг. Тиймээс шошго бүр ≤ 1, нийт ≤ 3.
///
/// Өмнө нь «нийт ≤ 1» гэж байсан. Тэр нь v1-д зөв байсан ч Манаач
/// нэмэгдэхэд ҮНЭН ШӨНИЙГ унагах байв: мафи нэгийг, Манаач нөгөөг
/// алахад хоёр үхэл гарна.
///
/// `deaths` нь СУУДЛЫН ДУГААРААР эрэмбэлэгдэнэ. Эрэмбэлэхгүй бол
/// дараалал нь хувингийн дотоод давталтаас хамаарч, «хэн түрүүлж
/// үхсэн» гэдгээр эх сурвалжийг таах боломж үүснэ.
void _checkN3(NightReport r) {
  final Map<DeathTag, int> byTag = <DeathTag, int>{};
  for (final Death d in r.deaths) {
    byTag.update(d.tag, (int v) => v + 1, ifAbsent: () => 1);
  }
  for (final MapEntry<DeathTag, int> e in byTag.entries) {
    _require(e.value <= 1, 'N3',
        '`${e.key.name}` эх сурвалжаас ${e.value} үхэл — хамгийн ихдээ 1');
  }
  _require(r.deaths.length <= 3, 'N3',
      'шөнөд ${r.deaths.length} үхэл гарлаа, хамгийн ихдээ 3');

  final Set<Seat> seen = <Seat>{};
  for (final Death d in r.deaths) {
    _require(seen.add(d.victim), 'N3',
        '${d.victim} нэг шөнөд хоёр удаа үхлээ');
  }
  for (int i = 1; i < r.deaths.length; i++) {
    _require(r.deaths[i - 1].victim < r.deaths[i].victim, 'N3',
        '`deaths` суудлын дугаараар эрэмбэлэгдээгүй');
  }
}

// ---------------------------------------------------------------------------
// N5 — Эмчийн бай = мафийн бай бол `deaths` хоосон
// ---------------------------------------------------------------------------

/// Эдгээлт нь ТЭНЦҮҮ түвшний довтолгоог **чанд** цуцална (`1 > 1` худал).
/// Энэ бол Эмчийн цорын ганц үүрэг.
void _checkN5(NightReport r) {
  final Set<Seat> healed = <Seat>{
    for (final Visit v in r.visits)
      if (v.ability == Ability.heal) v.to,
  };

  for (final Death d in r.deaths) {
    if (d.tag == DeathTag.remorse) {
      // ГЭМШЛИЙН ҮХЭЛ нь `powerful` — `lethal(powerful, basic)` нь
      // `2 > 1` тул ҮРГЭЛЖ үнэн. «Эмчилж болохгүй» гэдэг нь тусгай
      // тохиолдол БИШ, АРИФМЕТИК. Мөн энэ үхэлд зочлол байхгүй:
      // гэмшил нь хэн нэгэн рүү ОЧИХГҮЙ.
      _require(d.victim == d.killer, 'N5',
          'гэмшлийн үхлийн хохирогч, эх сурвалж хоёр зөрлөө');
      continue;
    }
    _require(!healed.contains(d.victim), 'N5',
        'хохирогч ${d.victim} эдгээгдсэн байтал үхлээ');
    _require(
        r.visits.any((Visit v) =>
            v.to == d.victim && v.harmful && v.from == d.killer),
        'N5',
        'хохирогч ${d.victim} руу ${d.killer}-аас хортой довтолгоо байхгүй');
  }

  // Эдгээгдсэн хүн рүү `basic` довтолгоо очсон бол ТЭР ХҮН үхээгүй
  // байх ёстой. Бусад хүн үхсэн эсэх нь хамаагүй — өмнөх хувилбар
  // «бүх `deaths` хоосон» гэж шалгадаг байсан нь Манаач нэмэгдэхэд
  // ҮНЭН шөнийг унагах байв.
  for (final Visit atk in r.visits) {
    if (!atk.harmful || !healed.contains(atk.to)) continue;
    _require(
        !r.deaths.any((Death d) =>
            d.victim == atk.to && d.tag != DeathTag.remorse),
        'N5',
        'Эмч ${atk.to}-г аварсан ч тэр үхлээ');
  }
}

// ---------------------------------------------------------------------------
// N6 — Лацдах мөчид үхсэн үйлдэгчийн үйлдэл хэрэгжихгүй
// ---------------------------------------------------------------------------

/// Шалгах үед хаягдана (`actorDead`), шийдвэрлэх үед ХЭЗЭЭ Ч биш.
/// `noAction` нь үйлдэл БИШ тул энэ дүрэмд ороогүй (N22-ыг үз).
void _checkN6(NightState s0, List<Intent> sealed) {
  for (final Intent i in sealed) {
    if (i.ability == Ability.noAction) continue;
    _require(s0.alive.contains(i.actor), 'N6',
        'үхсэн суудал ${i.actor} лацдсан жагсаалтад ${i.ability.name} хийлээ');
  }
}

// ---------------------------------------------------------------------------
// N8 — Шивнээ
// ---------------------------------------------------------------------------

/// Шивнээний санг лацдсан санаанаас ДАХИН тооцно (GDD-05 §5: 100, 130, 135
/// гурвуулаа тэжээнэ — хаягдсан алалт, эдгээлт, шалгалт ч орно).
Map<Seat, int> _rebuildTally(List<Intent> sealed) {
  final Map<Seat, int> t = <Seat, int>{};
  for (final Intent i in sealed) {
    switch (i.ability) {
      case Ability.mafiaKill:
      case Ability.investigate:
      case Ability.suspect:
      case Ability.heal:
      // Ажиглагч ч ТОВШИЛТ хийсэн — ширээн дээр дугаар болж гарна.
      // Хэрэв түүний товшилт санд ордоггүй байсан бол Ажиглагчтай
      // тоглолт нь шивнээ цөөнтэй болж, тэр өөрөө ялгарах байв.
      case Ability.watch:
      // Манаачийн товшилт ч санд орно — мафийнхтай яг адил. Хэрэв
      // ордоггүй байсан бол Манаач буудсан шөнө шивнээ нэгээр дутуу
      // гарч, тэр өөрөө ялгарах байв.
      case Ability.vigilanteKill:
        t.update(i.target!, (int v) => v + 1, ifAbsent: () => 1);
      case Ability.noAction:
        break;
    }
  }
  return t;
}

/// `whisper.length ≤ 2`, бүх гишүүн `aliveAfter`, тоолол ≥ `whisperMinAgree`,
/// жагсаалт **суудлын дугаараар өсөх**, бөгөөд сонголт нь дээд хоёр байна.
void _checkN8(NightState s0, List<Intent> sealed, NightReport r) {
  final List<Seat> w = r.whisper;
  _require(w.length <= 2, 'N8', 'шивнээнд ${w.length} суудал, дээд тал нь 2');

  for (int i = 1; i < w.length; i++) {
    _require(w[i - 1] < w[i], 'N8',
        'шивнээ суудлын дугаараар өсөх ёстой: $w');
  }
  for (final Seat s in w) {
    _require(r.aliveAfter.contains(s), 'N8',
        'шивнэгдсэн $s нь шийдвэрлэсний дараа амьд биш');
  }

  if (!s0.setup.whisperOn) {
    _require(w.isEmpty, 'N8', 'шивнээ унтраалттай байтал $w гарлаа');
    return;
  }

  final Map<Seat, int> tally = _rebuildTally(sealed);
  final int minAgree = s0.setup.whisperMinAgree;
  for (final Seat s in w) {
    final int c = tally[s] ?? 0;
    _require(c >= minAgree, 'N8', 'шивнэгдсэн $s-ийн тоолол $c < $minAgree');
  }

  final List<Seat> pool = <Seat>[
    for (final MapEntry<Seat, int> e in tally.entries)
      if (r.aliveAfter.contains(e.key) && e.value >= minAgree) e.key,
  ];
  final int expected = pool.length < 2 ? pool.length : 2;
  _require(w.length == expected, 'N8',
      'босго давсан $pool-оос $expected гарах ёстой байтал $w гарлаа');

  // Дээд хоёр мөн эсэх: сонгогдоогүй бүр нь сонгогдсон бүрээс МУУ байх ёстой
  // (тоо буурахаар, дараа нь `rank` — санамсаргүй тэнцэл хориотой).
  for (final Seat out in pool) {
    if (w.contains(out)) continue;
    for (final Seat inn in w) {
      final int ci = tally[inn]!;
      final int co = tally[out]!;
      final bool better =
          ci > co || (ci == co && s0.rank(inn) < s0.rank(out));
      _require(better, 'N8',
          '$out ($co) нь $inn ($ci)-ээс дээр байтал сонгогдсонгүй');
    }
  }
}

// ---------------------------------------------------------------------------
// N10 — Ялалт
// ---------------------------------------------------------------------------

/// Мафи `M ≥ T`, хотынхон `M == 0`. Хоёулаа зэрэг үнэн байж ЧАДАХГҮЙ.
void _checkN10(NightState s0, NightReport r) {
  _require(r.aliveAfter.isNotEmpty, 'N10', '`aliveAfter` хоосон байж болохгүй');

  int m = 0;
  for (final Seat s in r.aliveAfter) {
    final Role? role = s0.setup.roleOf(s);
    if (role != null && factionOf(role) == Faction.mafi) m++;
  }
  final int t = r.aliveAfter.length - m;

  final bool mafiWins = m > 0 && m >= t;
  final bool townWins = m == 0;
  _require(!(mafiWins && townWins), 'N10',
      'хоёр ялагч зэрэг гарлаа (M=$m, T=$t)');

  final WinState expected = evaluateWin(r.aliveAfter, s0.setup);
  _require(r.win == expected, 'N10',
      'ялалт ${r.win.name}, тооцоо ${expected.name} (M=$m, T=$t)');
}

// ---------------------------------------------------------------------------
// N13 — 20–80, 110, 140–150 хувин хоосон; `powerful` хэзээ ч гарахгүй
// ---------------------------------------------------------------------------

/// v1-д ажиллах ЦОРЫН ГАНЦ хувингууд. Бусад бүх хувин хоосон.
const Set<int> _kLiveBuckets = <int>{90, 100, 130, 135};

/// Төлөв (зочлол) БИЧДЭГ хувингууд: 90 `heal`, 100 `mafiaKill`, 130
/// `investigate`. **135 нь зөвхөн шивнээний санг тэжээнэ** — тэндээс зочлол
/// гарвал 20–80/110/140–150-ын аль нэг чимээгүйхэн амилсан гэсэн үг
/// (GDD-13 §4-ийн N17-ийн ах дүү нөхцөл).
const Set<Ability> _kVisitingAbilities = <Ability>{
  Ability.heal,
  Ability.mafiaKill,
  Ability.vigilanteKill,
  Ability.investigate,
};

void _checkN13(NightState s0, List<Intent> sealed, NightReport r) {
  // Enum өөрөө хоосон хувин руу ургаагүй эсэх (компайлын дараах хамгаалалт).
  for (final Ability a in Ability.values) {
    _require(_kLiveBuckets.contains(bucketOf(a)), 'N13',
        '`${a.name}` нь ${bucketOf(a)} хувинд буулаа — тэр хувин v1-д ХООСОН');
  }
  for (final Intent i in sealed) {
    final int b = bucketOf(i.ability);
    _require(_kLiveBuckets.contains(b), 'N13',
        '${i.ability.name} нь $b хувинд буулаа — v1-д тэр хувин ХООСОН');
  }
  for (final Visit v in r.visits) {
    _require(_kVisitingAbilities.contains(v.ability), 'N13',
        'зочлол `${v.ability.name}` — төлөв бичдэггүй хувингаас гарлаа');
  }
  // `AttackLevel.powerful`-ийн цорын ганц ажиглагдах ул мөр нь эдгээгдсэн
  // (`basic`) байг алсан үхэл — түүнийг N5 барина. Энд шошгыг шалгана:
  // v1-д `DeathTag.mafi`-аас өөр эх сурвалж байхгүй.
  // `AttackLevel.powerful` нь ГЭМШЛИЙН үхэлд л гарна. Өөр шошготой
  // үхэл `powerful` байвал хэн нэгэн эмчийг тойрох шинэ зам нээсэн
  // байна.
  for (final Death d in r.deaths) {
    _require(DeathTag.values.contains(d.tag), 'N13',
        '`${d.tag.name}` гэсэн үхлийн шошго байхгүй');
  }
}

// ---------------------------------------------------------------------------
// N14 — Үүрийн чимээгүй
// ---------------------------------------------------------------------------

/// `deaths.length == 1` бол `cues` дотор `[DAWN_A, silence(2500), DAWN_VICTIM_nn]`
/// **зэрэгцээ, тэр дарааллаар**. Чимээгүй нь хөдөлгүүрийн гаралт.
void _checkN14(NightReport r) {
  final List<Cue> c = r.cues;

  if (r.deaths.isEmpty) {
    _require(
        c.any((Cue x) => x is CueLine && x.clipId == kClipDawnNoKill), 'N14',
        'үхэлгүй шөнөд `$kClipDawnNoKill` байхгүй');
    _require(!c.any((Cue x) => x is CueLine && x.clipId == kClipDawnA), 'N14',
        'үхэлгүй шөнөд `$kClipDawnA` гарч ирлээ');
    return;
  }

  final int i = c.indexWhere((Cue x) => x is CueLine && x.clipId == kClipDawnA);
  _require(i >= 0, 'N14', 'үхэлтэй шөнөд `$kClipDawnA` байхгүй');
  _require(i + 2 < c.length, 'N14', '`$kClipDawnA`-ийн дараа гурвал дуусаагүй');

  final Cue mid = c[i + 1];
  _require(mid is CueSilence, 'N14',
      '`$kClipDawnA`-ийн дараа чимээгүй байх ёстой, олдсон нь $mid');
  mid as CueSilence;
  _require(mid.ms == kDawnSilenceMs, 'N14',
      'чимээгүй ${mid.ms} мс, ХАТУУ $kDawnSilenceMs байх ёстой');
  _require(mid.duckAmbienceDb == kDawnDuckDb, 'N14',
      'уур амьсгалын даралт ${mid.duckAmbienceDb} дБ, $kDawnDuckDb байх ёстой');

  final Cue last = c[i + 2];
  final String want = dawnVictimClip(r.deaths.first.victim);
  _require(last is CueLine && last.clipId == want, 'N14',
      'чимээгүйн дараа `$want` байх ёстой');
  _require(
      !c.any((Cue x) => x is CueLine && x.clipId == kClipDawnNoKill), 'N14',
      'үхэлтэй шөнөд `$kClipDawnNoKill` гарч ирлээ');
}

// ---------------------------------------------------------------------------
// N15 — `privateMsgs.keys ⊆ {амьд Мөрдөгчийн суудал}`
// ---------------------------------------------------------------------------

/// Хувийн мессеж хүлээн авах ЭРХ нь ДҮРЭЭС биш, МЕССЕЖИЙН КОДООС гарна.
///
/// Өмнө нь «зөвхөн Мөрдөгч» гэж суудлын дүрээр шалгадаг байв. Тэр нь дүр
/// нэмэх бүрд өргөжих жагсаалт болох бөгөөд ЯГ ЮУГ хориглож байгаагаа
/// хэлдэггүй. Одоо код бүрд түүнийг авах эрхтэй ГАНЦ дүрийг нэрлэнэ:
/// шинэ код нэмэх нь энэ хүснэгтэд мөр нэмэхийг шаардана, эс бөгөөс
/// тест унана.
const Map<MsgCode, Role> _kMsgOwner = <MsgCode, Role>{
  MsgCode.traceFound: Role.detective,
  MsgCode.traceNotFound: Role.detective,
  MsgCode.watchSaw: Role.watcher,
  MsgCode.watchNobody: Role.watcher,
};

void _checkN15(NightState s0, NightReport r) {
  for (final MapEntry<Seat, List<Msg>> e in r.privateMsgs.entries) {
    _require(s0.alive.contains(e.key), 'N15',
        'лацдах мөчид үхсэн байсан ${e.key} хувийн мессеж авлаа');
    for (final Msg m in e.value) {
      final Role? owner = _kMsgOwner[m.code];
      _require(owner != null, 'N15',
          '`${m.code.name}` мессежийн эзэн дүр тодорхойгүй');
      _require(s0.setup.roleOf(e.key) == owner, 'N15',
          '${e.key} нь ${owner!.name} биш атлаа `${m.code.name}` авлаа');
    }
  }
}

// ---------------------------------------------------------------------------
// N19 — `(actor, ability)` хос тутамд хамгийн ихдээ нэг үйлдэл
// ---------------------------------------------------------------------------

void _checkN19(List<Intent> sealed) {
  final Set<String> seen = <String>{};
  for (final Intent i in sealed) {
    final String key = '${i.actor}/${i.ability.name}';
    _require(seen.add(key), 'N19',
        '($key) хос хоёр удаа лацдагдлаа — давхардал цэвэрлэгдээгүй');
  }
}

// ---------------------------------------------------------------------------
// N20 — Тооллого
// ---------------------------------------------------------------------------

/// `deaths ⊆ aliveAtSeal`, `aliveAfter.length == aliveAtSeal.length − deaths.length`.
void _checkN20(NightState s0, NightReport r) {
  final Set<Seat> victims = <Seat>{};
  for (final Death d in r.deaths) {
    _require(s0.alive.contains(d.victim), 'N20',
        'лацдах мөчид амьд биш байсан ${d.victim} үхлээ');
    _require(victims.add(d.victim), 'N20', '${d.victim} хоёр удаа үхлээ');
  }
  _require(r.aliveAfter.length == s0.alive.length - r.deaths.length, 'N20',
      'тооллого зөрлөө: ${s0.alive.length} − ${r.deaths.length} ≠ '
      '${r.aliveAfter.length}');

  final Set<Seat> expected = <Seat>{...s0.alive}..removeAll(victims);
  _require(
      expected.length == r.aliveAfter.length &&
          expected.every(r.aliveAfter.contains),
      'N20',
      '`aliveAfter` нь `alive \\ deaths`-тэй тэнцэхгүй байна');
}

// ---------------------------------------------------------------------------
// N21 — `infoAnswer` товших мөчид өгсөн хариу = тайлан дахь хариу
// ---------------------------------------------------------------------------

void _checkN21(NightState s0, List<Intent> sealed, NightReport r) {
  final Map<Seat, List<MsgCode>> want = <Seat, List<MsgCode>>{};
  for (final Intent q in sealed) {
    if (q.ability != Ability.investigate) continue;
    want.putIfAbsent(q.actor, () => <MsgCode>[]).add(infoAnswer(s0, q).code);
  }

  for (final MapEntry<Seat, List<MsgCode>> e in want.entries) {
    final List<Msg>? got = r.privateMsgs[e.key];
    _require(got != null, 'N21',
        'Мөрдөгч ${e.key} шалгасан ч тайланд хариу байхгүй');
    // ЗӨВХӨН мөрдөгчийн кодуудыг харьцуулна: нэг суудал хоёр дүртэй
    // байж чадахгүй тул энд өөр код орж ирэхгүй, гэхдээ шүүлт нь
    // шалгалтыг ирээдүйн дүрүүдээс хамгаална.
    final List<MsgCode> gotCodes = got!
        .map((Msg m) => m.code)
        .where((MsgCode c) =>
            c == MsgCode.traceFound || c == MsgCode.traceNotFound)
        .toList()
      ..sort(_byCode);
    final List<MsgCode> wantCodes = List<MsgCode>.of(e.value)..sort(_byCode);
    _require(
        gotCodes.length == wantCodes.length &&
            List<int>.generate(gotCodes.length, (int i) => i)
                .every((int i) => gotCodes[i] == wantCodes[i]),
        'N21',
        'товших мөчийн хариу $wantCodes ≠ тайлангийн $gotCodes');
  }

  // N25 — Ажиглагчийн хариу нь ТАЙЛАНГААС дахин тооцогдоно.
  //
  // Энэ нь зүгээр нэг давхардсан тооцоо биш: хариу нь `visits`-ээс
  // гардаг гэдгийг батална. Хэрэв хэн нэгэн хожим `watchAnswer`-ыг
  // дотоод төлөв уншдаг болговол (жишээ нь «хэн хэнийг эмчилсэн» гэдгийг
  // шууд) тэр нь ТАЙЛАНД ГАРААГҮЙ мэдээллийг тоглогчид өгнө — тэгээд
  // дахин тоглуулалт нь шалгах чадваргүй болно.
  final List<Visit> frozen = r.visits
      .where((Visit v) => bucketOf(v.ability) < 130)
      .toList();
  for (final Intent q in sealed) {
    if (q.ability != Ability.watch) continue;
    final List<Msg> want2 = watchAnswer(frozen, q);
    final List<Msg> got = (r.privateMsgs[q.actor] ?? const <Msg>[])
        .where((Msg m) =>
            m.code == MsgCode.watchSaw || m.code == MsgCode.watchNobody)
        .toList();
    _require(got.length == want2.length, 'N25',
        'Ажиглагч ${q.actor}: ${want2.length} мессеж хүлээсэн, ${got.length} ирлээ');
    for (int i = 0; i < got.length; i++) {
      _require(got[i].code == want2[i].code, 'N25',
          'Ажиглагчийн $i дэх код зөрлөө');
      _require(got[i].params['seat'] == want2[i].params['seat'], 'N25',
          'Ажиглагчийн $i дэх суудал зөрлөө');
    }
  }

  final Set<Seat> answered = <Seat>{
    ...want.keys,
    for (final Intent q in sealed)
      if (q.ability == Ability.watch) q.actor,
  };
  for (final Seat k in r.privateMsgs.keys) {
    _require(answered.contains(k), 'N21',
        '$k шалгалт хийгээгүй атлаа тайланд хариутай');
  }
}

int _byCode(MsgCode a, MsgCode b) => a.index.compareTo(b.index);

// ---------------------------------------------------------------------------
// N22 — Амьд суудал бүр яг нэг `Intent`
// ---------------------------------------------------------------------------

/// «Алгасах» товч байхгүй, гэвч `noAction` нь ЗӨВШӨӨРӨГДӨНӨ — цонх дуусахад
/// бүртгэгдэх, гаднаас нь товшсонтой ялгагдахгүй санаа (GDD-05 §1).
void _checkN22(NightState s0, List<Intent> sealed) {
  final Map<Seat, int> count = <Seat, int>{};
  for (final Intent i in sealed) {
    count.update(i.actor, (int v) => v + 1, ifAbsent: () => 1);
  }
  for (final Seat s in s0.alive) {
    final int c = count[s] ?? 0;
    _require(c == 1, 'N22',
        'амьд суудал $s яг нэг санаа илгээх ёстой, илгээсэн нь $c');
  }
}
