// «Хот унтлаа» — бүрэлдэхүүний хүснэгт, «алдаж болох саналын» төсөв ба
// тохиргооны шалгагч.
//
// Эх сурвалж: GDD-04 §1 (конвенц ба `b` томьёо), §2 (N = 6…20-ын хүснэгт),
// §3 (шалгагчийн зан төлөв); GDD-05 §9.4 (`b0`, `pipsForDay`);
// GDD-13 §4-ийн инвариант N9 ба N16.
//
// ХАТУУ ДҮРЭМ (GDD-05 §0): IO байхгүй, `DateTime.now()` байхгүй,
// `Random()` байхгүй, `double` байхгүй, Flutter-ээс хамаарахгүй.

import 'model.dart';

// ---------------------------------------------------------------------------
// Хязгаар ба томьёо
// ---------------------------------------------------------------------------

/// Ширээний шал. GDD-04 §2: «Зургаан хүнээс доош ширээнд мафи тоглоом
/// болохгүй.» (GDD-15-аар эвлэрүүлсэн дөрвөн өөр шалнаас ялсан нь.)
const int kMinSeats = 6;

/// Ширээний тааз. 21–25 нь v2 — тэнд хоёр дахь Мөрдөгч хэрэгтэй (GDD-04 §2).
const int kMaxSeats = 20;

/// Алдаж болох саналын төсөв: `b = ⌊N/2⌋ − M − 1` (GDD-04 §1).
///
/// Энэ ганц бүхэл тоо бүх балансыг тээнэ — тохиргооны шалгагч, өдрийн дээд
/// мөр, дэвтрийн бичлэг гурвуулаа. Томьёо нь ЗӨВХӨН `nightFirst` ба `M ≥ T`
/// конвенцийн дор зөрүүгүй; P7 тест үүнийг N = 4…60 дээр бүтэн хайлтаар
/// баталдаг. Аппад өөр ямар ч балансын хөдөлгүүр байхгүй.
int b0(int n, int m) => (n ~/ 2) - m - 1;

/// Өдөр тутмын «Тооны самбар»: `pips = b₀ − (dayIndex − 1)` (GDD-05 §9.4).
///
/// **Гарын үсэг нь `roleBySeat`-ыг АВДАГГҮЙ — инвариант N16.** Хасагдсан
/// хүний талыг уншиж буулгавал апп нь хасагдсан хүний дүрийг чимээгүйхэн
/// зарлана; тэр нь GDD-00 §11-ийн 1-р татгалзлыг зөрчинө. Өдрийн дугаараар
/// хасах нь консерватив бөгөөд алдагдал тэг.
int pipsForDay(int n, int m, int dayIndex) => b0(n, m) - (dayIndex - 1);

// ---------------------------------------------------------------------------
// Бүрэлдэхүүний хүснэгт
// ---------------------------------------------------------------------------

/// N бүрийн анхдагч бүрэлдэхүүн. GDD-04 §2-ын шилжүүлэх хүснэгтийн нэг мөр.
///
/// GDD-04 нь GDD-02-оос ДЭЭГҮҮР — бүрэлдэхүүний цорын ганц эх сурвалж
/// (GDD-15 §1). `mafia` дотор Ахлагч аль хэдийн багтсан: тэр нэг Алуурчны
/// суудлыг ОРЛОНО, мафийн тоо хэзээ ч нэмэгдэхгүй.
class Roster {
  /// Суудлын тоо, 6..20.
  final int n;

  /// Мафийн НИЙТ тоо — Ахлагч багтсан.
  final int mafia;

  /// Ахлагч гарах уу. Зөвхөн `mafia >= 3` үед (GDD-04 §2.1 → N = 12-оос).
  final bool boss;

  final bool doctor;
  final bool detective;

  /// v2 — Ажиглагч гарах уу.
  ///
  /// АНХДАГЧААР УНТРААЛТТАЙ. Эзэн нь лоббид зориудаар асаана. Тэр нь
  /// нэг ИРГЭНИЙ суудлыг ОРЛОНО — мафийн тоо, `b` хоёулаа хөдлөхгүй тул
  /// GDD-04-ийн балансын хүснэгт хүчинтэй хэвээр.
  final bool watcher;

  /// v2 — Хотын дарга гарах уу. Мөн нэг ИРГЭНИЙ суудлыг орлоно.
  final bool mayor;

  /// v3 — Саатуулагч гарах уу. Мөн нэг ИРГЭНИЙ суудлыг орлоно.
  final bool blocker;

  /// v3 — Манаач гарах уу. Мөн нэг ИРГЭНИЙ суудлыг орлоно.
  ///
  /// БАЛАНСАД НӨЛӨӨЛНӨ: хотод хоёр сум нэмэгдэнэ, гэхдээ буруу
  /// буудвал хотынхон ХОЁР хүн алдана (хохирогч ба гэмшсэн Манаач).
  /// Тиймээс `b` хөдлөхгүй — эрсдэл, ашиг хоёр нь тэнцэнэ гэж үзнэ.
  final bool vigilante;

  /// Үлдсэн суудлууд: `n - mafia - doctor - detective - нэмэлтүүд`.
  final int citizens;

  /// GDD-04 §2-ын хүснэгтэд хэвлэгдсэн `b`. Үргэлж `b0(n, mafia)`-тай тэнцүү.
  final int b;

  const Roster({
    required this.n,
    required this.mafia,
    required this.boss,
    required this.doctor,
    required this.detective,
    required this.citizens,
    required this.b,
    this.watcher = false,
    this.mayor = false,
    this.vigilante = false,
    this.blocker = false,
  });

  /// Нэг иргэнийг нэмэлт дүр болгоно. Иргэн үлдэхгүй бол ӨӨРЧЛӨХГҮЙ.
  ///
  /// ДОР ХАЯЖ НЭГ ИРГЭН ҮЛДЭНЭ. Бүх иргэнийг чадвартай дүр болговол
  /// «юу ч хийгээгүй хүн» гэсэн ойлголт алга болж, шөнийн жигд хуурмаг
  /// эвдэрнэ: чимээгүй суудал байхгүй бол дуугүй хүн нь тэр дороо
  /// сэжигтэй болно.
  Roster _swapCitizen(
      {bool? watcher, bool? mayor, bool? vigilante, bool? blocker}) {
    if (citizens < 2) return this;
    return Roster(
      n: n,
      mafia: mafia,
      boss: boss,
      doctor: doctor,
      detective: detective,
      citizens: citizens - 1,
      b: b,
      watcher: watcher ?? this.watcher,
      mayor: mayor ?? this.mayor,
      vigilante: vigilante ?? this.vigilante,
      blocker: blocker ?? this.blocker,
    );
  }

  Roster withWatcher() => watcher ? this : _swapCitizen(watcher: true);

  Roster withMayor() => mayor ? this : _swapCitizen(mayor: true);

  Roster withVigilante() =>
      vigilante ? this : _swapCitizen(vigilante: true);

  Roster withBlocker() => blocker ? this : _swapCitizen(blocker: true);

  /// Мафийн дотор хэдэн энгийн Алуурчин байх вэ (Ахлагч суудлыг хассан).
  int get killers => mafia - (boss ? 1 : 0);

  @override
  String toString() => 'Roster(n: $n, M: $mafia, boss: $boss, '
      'watcher: $watcher, mayor: $mayor, vigilante: $vigilante, '
      'blocker: $blocker, b: $b)';
}

/// GDD-04 §2-ын шилжүүлэх хүснэгт, үг үсгээр. **15 мөр, N = 6…20.**
/// Энэ бол `assets/balance.json`-ы эх хувилбар.
const Map<int, Roster> _kRosterTable = <int, Roster>{
  6: Roster(n: 6, mafia: 1, boss: false, doctor: true, detective: true, citizens: 3, b: 1),
  7: Roster(n: 7, mafia: 1, boss: false, doctor: true, detective: true, citizens: 4, b: 1),
  8: Roster(n: 8, mafia: 2, boss: false, doctor: true, detective: true, citizens: 4, b: 1),
  9: Roster(n: 9, mafia: 2, boss: false, doctor: true, detective: true, citizens: 5, b: 1),
  10: Roster(n: 10, mafia: 2, boss: false, doctor: true, detective: true, citizens: 6, b: 2),
  11: Roster(n: 11, mafia: 2, boss: false, doctor: true, detective: true, citizens: 7, b: 2),
  12: Roster(n: 12, mafia: 3, boss: true, doctor: true, detective: true, citizens: 7, b: 2),
  13: Roster(n: 13, mafia: 3, boss: true, doctor: true, detective: true, citizens: 8, b: 2),
  14: Roster(n: 14, mafia: 4, boss: true, doctor: true, detective: true, citizens: 8, b: 2),
  15: Roster(n: 15, mafia: 4, boss: true, doctor: true, detective: true, citizens: 9, b: 2),
  16: Roster(n: 16, mafia: 4, boss: true, doctor: true, detective: true, citizens: 10, b: 3),
  17: Roster(n: 17, mafia: 4, boss: true, doctor: true, detective: true, citizens: 11, b: 3),
  18: Roster(n: 18, mafia: 5, boss: true, doctor: true, detective: true, citizens: 11, b: 3),
  19: Roster(n: 19, mafia: 5, boss: true, doctor: true, detective: true, citizens: 12, b: 3),
  20: Roster(n: 20, mafia: 5, boss: true, doctor: true, detective: true, citizens: 13, b: 4),
};

/// N-ийн анхдагч бүрэлдэхүүн. Тоглогчийн тоо сонгогдмогц шууд хэрэгжинэ,
/// баталгаажуулах дэлгэц байхгүй (GDD-04 §2).
///
/// `n` нь [kMinSeats]..[kMaxSeats] гадна байвал [ArgumentError] шиднэ —
/// инвариант N9-ийн «`startGame` хаягдана» гэдгийн хөдөлгүүрийн тал.
/// [watcher] нь ЗӨВХӨН эзний зориудын сонголт. Анхдагч бүрэлдэхүүн
/// хөдлөхгүй тул GDD-04 §2-ын хүснэгт, `deal_test`-ийн алтан векторууд
/// хүчинтэй хэвээр.
Roster rosterFor(int n,
    {bool watcher = false,
    bool mayor = false,
    bool vigilante = false,
    bool blocker = false}) {
  Roster? r = _kRosterTable[n];
  if (r == null) {
    throw ArgumentError.value(n, 'n', 'Суудлын тоо $kMinSeats..$kMaxSeats байх ёстой');
  }
  if (watcher) r = r.withWatcher();
  if (mayor) r = r.withMayor();
  if (vigilante) r = r.withVigilante();
  if (blocker) r = r.withBlocker();
  return r;
}

/// Манаач тус бүрийн ЭХНИЙ сум.
const int kVigilanteBullets = 2;

/// Хуваарилахын өмнөх канон хөзрийн багц — ХАТУУ, ТОГТМОЛ дараалалтай.
///
/// `fisherYates(canonicalDeck(setup), deal)` нь үүнийг холино (GDD-05 §7.2,
/// GDD-10 §2), тиймээс дараалал нь зөвхөн детерминизмын төлөө чухал:
/// Ахлагч → Алуурчид → Эмч → Мөрдөгч → Иргэд.
///
/// Урт нь ҮРГЭЛЖ `r.n`.
List<Role> deckFor(Roster r) {
  final deck = <Role>[];
  if (r.boss) deck.add(Role.boss);
  for (var i = 0; i < r.killers; i++) {
    deck.add(Role.killer);
  }
  if (r.doctor) deck.add(Role.doctor);
  if (r.detective) deck.add(Role.detective);
  // Ажиглагч нь Мөрдөгчийн ДАРАА, иргэдийн ӨМНӨ. Дараалал нь зөвхөн
  // детерминизмын төлөө чухал — `fisherYates` дараа нь холино.
  if (r.watcher) deck.add(Role.watcher);
  if (r.mayor) deck.add(Role.mayor);
  if (r.vigilante) deck.add(Role.vigilante);
  if (r.blocker) deck.add(Role.blocker);
  for (var i = 0; i < r.citizens; i++) {
    deck.add(Role.citizen);
  }
  return deck;
}

// ---------------------------------------------------------------------------
// Тохиргооны шалгагч (GDD-04 §3)
// ---------------------------------------------------------------------------

enum SetupVerdict { green, warn, reject }

/// Шалгагчийн хариу. `code` нь ногоон үед `null`.
/// `messageMn` нь GDD-04 §3.2/§3.3-ын дэлгэцийн мөр, үг үсгээр.
class SetupCheck {
  final SetupVerdict verdict;
  final String? code;
  final String messageMn;

  const SetupCheck(this.verdict, this.code, this.messageMn);

  bool get isReject => verdict == SetupVerdict.reject;
  bool get isGreen => verdict == SetupVerdict.green;

  @override
  String toString() => 'SetupCheck(${verdict.name}, ${code ?? "-"})';
}

/// Суудлын тоо хамрах хүрээнээс гадуур — доод хил.
const String kCodeSeatsTooFew = 'SEATS_TOO_FEW';

/// Суудлын тоо хамрах хүрээнээс гадуур — дээд хил.
const String kCodeSeatsTooMany = 'SEATS_TOO_MANY';

/// Мафигүй тоглоом байхгүй (GDD-04 §3.1-ийн 2-р дүрэм).
const String kCodeNoMafia = 'NO_MAFIA';

/// Ахлагч `mafia < 3` үед гарч ирж болохгүй (GDD-04 §2.1).
const String kCodeBossNeedsThree = 'BOSS_NEEDS_THREE';

/// `b < 0` — хатуу татгалзал (GDD-04 §3.2).
const String kCodeBudgetNegative = 'BUDGET_NEGATIVE';

/// `b == 0` — анхааруулга, гарцтай (GDD-04 §3.3).
const String kCodeBudgetZero = 'BUDGET_ZERO';

/// `b >= 5` — тоглоом сунжирна (GDD-04 §3.1-ийн 7-р дүрэм).
const String kCodeBudgetLong = 'BUDGET_LONG';

/// Тохиргооны шалгагч — цэвэр функц, дэлгэцээс салангид (GDD-04 §3).
///
/// Дүрэм нь **дээрээс доош, эхний таарсан нь хүчинтэй**:
///
/// 1. `n < kMinSeats` эсвэл `n > kMaxSeats` → **reject**
/// 2. `mafia < 1` → **reject**
/// 3. `boss` бөгөөд `mafia < 3` → **reject**
/// 4. `b < 0` → **reject** (гарц БАЙХГҮЙ — «Ямар ч байсан эхлэх» товч байхгүй)
/// 5. `b == 0` → **warn**
/// 6. `b >= 5` → **warn**
/// 7. Бусад → **green**
///
/// GDD-04 §3.1-ийн 5, 6-р дүрэм (`E > 70`, `E < 45`) нь `assets/balance.json`-ы
/// `E` баганаас хамаардаг тул энэ модулийн API-д ОРООГҮЙ — тэр хоёр нь
/// хүлээгдэж буй хотын хожлын таамаглал бөгөөд хөдөлгүүрийн шийдвэрт
/// нөлөөлдөггүй. [doctor] ба [detective] нь яг тэр хоёр дүрмийн (`E`-г
/// интерполяцлах) оролт тул гарын үсэгт үлдэнэ; 4-р дүрэм (`b < 0`) нь
/// суудалд багтахгүй бүх бүрэлдэхүүнийг аль хэдийн татгалздаг
/// (`b ≥ 0 ⟹ mafia + 2 ≤ n`), тиймээс тусдаа «багтахгүй» дүрэм хэрэггүй.
///
/// [night0Kill] нь GDD-03 §7-ын тэмдэглэсэн онцгой тохиолдол: танилцах шөнөд
/// алалт гарвал `b` томьёоны батлагдсан урьдчилсан нөхцөл (шөнө-эхлэх,
/// хохирогчгүй) эвдэрч, төсөв нэгээр буурна → `b = b0 − 1`. v1-д энэ
/// унтраалга `const false` (GDD-15 №24), гэвч шалгагч түүнийг зөв тооцно.
SetupCheck checkSetup({
  required int n,
  required int mafia,
  required bool boss,
  required bool doctor,
  required bool detective,
  bool night0Kill = false,
}) {
  if (n < kMinSeats) {
    return const SetupCheck(
      SetupVerdict.reject,
      kCodeSeatsTooFew,
      'Зургаан хүнээс доош ширээнд мафи тоглоом болохгүй.',
    );
  }
  if (n > kMaxSeats) {
    return const SetupCheck(
      SetupVerdict.reject,
      kCodeSeatsTooMany,
      'Хорин хүнээс дээш ширээ энэ хувилбарт байхгүй.',
    );
  }
  if (mafia < 1) {
    return const SetupCheck(
      SetupVerdict.reject,
      kCodeNoMafia,
      'Мафигүй тоглоом байхгүй. Дор хаяж нэг мафи хэрэгтэй.',
    );
  }
  if (boss && mafia < 3) {
    return const SetupCheck(
      SetupVerdict.reject,
      kCodeBossNeedsThree,
      'Ахлагч гурав ба түүнээс дээш мафитай үед л гарна.',
    );
  }

  // GDD-03 §7-ын салаа: танилцах шөнөд алалт гарвал төсөв нэгээр буурна.
  final b = night0Kill ? b0(n, mafia) - 1 : b0(n, mafia);

  if (b < 0) {
    return const SetupCheck(
      SetupVerdict.reject,
      kCodeBudgetNegative,
      'Энэ бүрэлдэхүүнээр мафи эхний шөнөдөө яллаа. '
          'Тоглогч нэм эсвэл мафи хас.',
    );
  }
  if (b == 0) {
    return const SetupCheck(
      SetupVerdict.warn,
      kCodeBudgetZero,
      'Алдаж болох санал байхгүй. Эхний өдрөөс онох ёстой.',
    );
  }
  if (b >= 5) {
    return const SetupCheck(
      SetupVerdict.warn,
      kCodeBudgetLong,
      'Алдаж болох санал хэт олон — тоглоом сунжирна.',
    );
  }
  return const SetupCheck(SetupVerdict.green, null, 'Бүрэлдэхүүн бэлэн.');
}
