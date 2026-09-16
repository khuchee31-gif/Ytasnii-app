// Дүрмийн тохиргоо — GDD-03 §2 (түлхүүрүүд), §3 (дөрвөн preset), §4 (гэрийн
// дүрмийн дөрвөн тохируулга).
//
// ЭНЭ БОЛ ГЭРЭЭ. Дэлгэц энд байгаа утгыг УНШИНА, өөрсдөө анхдагч зохиохгүй.
//
// Хатуу дүрэм (GDD-03 §1-ийн Зарчим 2): ЦАРЦСАН дүрэм энд ОГТ байхгүй —
// `nightFirst`, `night0Kill`, `winRule`, `votingMode`, `defenceSeconds`,
// `whisperMinAgree`, `foulWarnings` гэх мэт 18 мөр кодод `const` бөгөөд
// тохиргооны дэлгэцэд гарахгүй. Унтраалттай мөртөө дарагддаггүй toggle бол
// хамгийн хортой UI.

import 'package:engine/engine.dart' show SelfHeal;
import 'package:flutter/foundation.dart';

// ---------------------------------------------------------------------------
// Дөрвөн preset — GDD-03 §3
// ---------------------------------------------------------------------------

enum PresetId { songodog, angi, sport, shine }

extension PresetIdX on PresetId {
  /// Картын гарчиг. Нэрэнд суудлын тоо ОРОХГҮЙ (GDD-06 S03).
  String get labelMn => switch (this) {
        PresetId.songodog => 'Сонгодог',
        PresetId.angi => 'Анги',
        PresetId.sport => 'Спорт',
        PresetId.shine => 'Шинэ тоглогч',
      };

  /// Картын дэд мөр, GDD-03 §3-ын хүснэгтээс үг үсгээр.
  String get subtitleMn => switch (this) {
        PresetId.songodog => 'Ангийнхаа дүрэм. Өөрчилбөл энд хадгалагдана.',
        PresetId.angi => 'Хичээлийн цагт багтана. ~16 минут.',
        PresetId.sport => 'ФСМ-ийн дүрэм. Дүр нээгдэхгүй, үг 60 секунд.',
        PresetId.shine => 'Анх удаа тоглож байгаа ширээнд.',
      };

  /// Цорын ганц бичигдэх слот — «Сонгодог» (GDD-03 §3).
  bool get writable => this == PresetId.songodog;
}

/// Санал тэнцвэл — GDD-03 §4.5.
enum TieRule { fsm, noElim, random }

extension TieRuleX on TieRule {
  String get labelMn => switch (this) {
        TieRule.fsm => 'Нэмэлт үг → дахин санал',
        TieRule.noElim => 'Хэн ч хөөгдөхгүй',
        TieRule.random => 'Санамсаргүй',
      };

  String get consequenceMn => switch (this) {
        TieRule.fsm => 'Тэнцсэн хүн бүр 30 секунд. Дараа нь дахин санал. '
            'Дахиад тэнцвэл бүгдийг хасах ширээний санал.',
        TieRule.noElim => 'Өдөр хохирогчгүй дуусна.',
        TieRule.random => 'Апп сонгоно.',
      };
}

/// Эмч өөрийгөө аврах — GDD-03 §4.1. Гурван байрлал нь хөдөлгүүрийн
/// `SelfHeal`-тэй яг нэг мөр.
extension SelfHealX on SelfHeal {
  String get labelMn => switch (this) {
        SelfHeal.unlimited => 'Хязгааргүй',
        SelfHeal.once => 'Тоглоомд нэг удаа',
        SelfHeal.never => 'Хэзээ ч үгүй',
      };

  String get consequenceMn => switch (this) {
        SelfHeal.unlimited => 'Эмчийг алахад хэцүү болно.',
        SelfHeal.once => 'Нэг л удаа. Дараа нь зөвхөн бусдыг.',
        SelfHeal.never => 'Эмч эхний шөнө хохирч болно.',
      };
}

/// Нэг preset-ийн бүтэн хуулбар. GDD-03 §3.1-ийн зөрүүний хүснэгт.
@immutable
class PresetSpec {
  const PresetSpec({
    required this.seatCount,
    required this.mafiaCount,
    required this.donEnabled,
    required this.acquaintSeconds,
    required this.mafiaFriendlyFire,
    required this.doctorSelfHeal,
    required this.speechSeconds,
    required this.dayMaxMinutes,
    required this.tieRule,
    required this.revealRoleOnDeath,
    required this.lastWordsSeconds,
    required this.bestMove,
    required this.cityWhisper,
    required this.nightSeatSeconds,
    required this.lyloBanner,
  });

  final int seatCount;
  final int mafiaCount;
  final bool donEnabled;
  final int acquaintSeconds;
  final bool mafiaFriendlyFire;
  final SelfHeal doctorSelfHeal;
  final int speechSeconds;
  final int dayMaxMinutes;
  final TieRule tieRule;
  final bool revealRoleOnDeath;
  final int lastWordsSeconds;
  final bool bestMove;
  final bool cityWhisper;
  final int nightSeatSeconds;
  final bool lyloBanner;
}

/// Preset бол кодод байгаа `const` map, өгөгдлийн санд биш (GDD-03 §3.2) —
/// ингэснээр шинэ preset хэзээ ч миграц шаардахгүй.
const Map<PresetId, PresetSpec> kPresets = <PresetId, PresetSpec>{
  PresetId.songodog: PresetSpec(
    seatCount: 12,
    mafiaCount: 3,
    donEnabled: true,
    acquaintSeconds: 60,
    mafiaFriendlyFire: true,
    doctorSelfHeal: SelfHeal.once,
    speechSeconds: 40,
    dayMaxMinutes: 8,
    tieRule: TieRule.fsm,
    revealRoleOnDeath: false,
    lastWordsSeconds: 30,
    bestMove: true,
    cityWhisper: true,
    nightSeatSeconds: 6,
    lyloBanner: true,
  ),
  PresetId.angi: PresetSpec(
    seatCount: 12,
    mafiaCount: 3,
    donEnabled: true,
    acquaintSeconds: 45,
    mafiaFriendlyFire: true,
    doctorSelfHeal: SelfHeal.once,
    speechSeconds: 40,
    dayMaxMinutes: 5,
    tieRule: TieRule.noElim,
    revealRoleOnDeath: false,
    lastWordsSeconds: 15,
    bestMove: true,
    cityWhisper: true,
    nightSeatSeconds: 5,
    lyloBanner: true,
  ),
  PresetId.sport: PresetSpec(
    seatCount: 10,
    mafiaCount: 2,
    donEnabled: false,
    acquaintSeconds: 60,
    mafiaFriendlyFire: true,
    doctorSelfHeal: SelfHeal.never,
    speechSeconds: 60,
    dayMaxMinutes: 8,
    tieRule: TieRule.fsm,
    revealRoleOnDeath: false,
    lastWordsSeconds: 60,
    bestMove: true,
    cityWhisper: false,
    nightSeatSeconds: 6,
    lyloBanner: false,
  ),
  PresetId.shine: PresetSpec(
    seatCount: 8,
    mafiaCount: 2,
    donEnabled: false,
    acquaintSeconds: 60,
    mafiaFriendlyFire: false,
    doctorSelfHeal: SelfHeal.unlimited,
    speechSeconds: 30,
    dayMaxMinutes: 4,
    tieRule: TieRule.noElim,
    revealRoleOnDeath: true,
    lastWordsSeconds: 30,
    bestMove: false,
    cityWhisper: true,
    nightSeatSeconds: 8,
    lyloBanner: true,
  ),
};

// ---------------------------------------------------------------------------
// Амьд тохиргоо
// ---------------------------------------------------------------------------

/// Унтраалга бүр локалд шууд хадгалагдана (GDD-06 S21). v1-д санах ойд —
/// `drift` руу бичих нь GDD-12-ын ажил, энэ классын API өөрчлөгдөхгүй.
class GameSettings extends ChangeNotifier {
  GameSettings() {
    apply(PresetId.songodog);
  }

  PresetId basePreset = PresetId.songodog;

  // --- Гэрийн дүрмийн дөрөв (GDD-03 §4) -----------------------------------
  SelfHeal doctorSelfHeal = SelfHeal.once;
  bool mafiaFriendlyFire = true;
  bool revealRoleOnDeath = false;
  TieRule tieRule = TieRule.fsm;

  // --- «Дэлгэрэнгүй» доорх мөрүүд (GDD-06 S21) ----------------------------
  bool sound = true;
  bool haptics = true;
  bool reduceMotion = false;
  bool largeText = false;
  bool onePointerReveal = false;
  bool leftHanded = false;
  bool keepAwake = true;
  bool cityWhisper = true;
  bool hostMode = false;
  bool bestMove = true;
  bool lyloBanner = true;
  bool pinMoments = true;

  int speechSeconds = 40;
  int dayMaxMinutes = 8;
  int nightSeatSeconds = 6;
  int acquaintSeconds = 60;
  int lastWordsSeconds = 30;

  /// «Нэг хуруугаар нээх» асаалттай үед барих хугацаа 1200 мс (GDD-06 S06).
  Duration get holdDuration => onePointerReveal
      ? const Duration(milliseconds: 1200)
      : const Duration(milliseconds: 220);

  /// Зөвхөн уншигдах preset засагдмагц асна — дэлгэц 1.5 секунд мөр гаргана.
  bool copiedToSongodog = false;

  void clearCopiedFlag() {
    if (!copiedToSongodog) return;
    copiedToSongodog = false;
    notifyListeners();
  }

  /// Preset дарахад чипүүд шууд шилжинэ, баталгаа асуухгүй (GDD-06 S03).
  void apply(PresetId id) {
    final PresetSpec p = kPresets[id]!;
    basePreset = id;
    copiedToSongodog = false;
    doctorSelfHeal = p.doctorSelfHeal;
    mafiaFriendlyFire = p.mafiaFriendlyFire;
    revealRoleOnDeath = p.revealRoleOnDeath;
    tieRule = p.tieRule;
    speechSeconds = p.speechSeconds;
    dayMaxMinutes = p.dayMaxMinutes;
    nightSeatSeconds = p.nightSeatSeconds;
    acquaintSeconds = p.acquaintSeconds;
    lastWordsSeconds = p.lastWordsSeconds;
    bestMove = p.bestMove;
    cityWhisper = p.cityWhisper;
    lyloBanner = p.lyloBanner;
    notifyListeners();
  }

  /// Тохируулга хөдөлмөгц дуудагдана. Зөвхөн уншигдах preset байсан бол
  /// өөрчлөлт «Сонгодог» руу чимээгүйхэн хуулагдана (GDD-03 §3).
  void edit(void Function() change) {
    change();
    if (!basePreset.writable) {
      basePreset = PresetId.songodog;
      copiedToSongodog = true;
    }
    notifyListeners();
  }

  /// GDD-12 §9 — «Бүх өгөгдлийг устгах». v1-д санах ойн төлөвийг эхлэл рүү.
  void resetAll() {
    apply(PresetId.songodog);
    sound = true;
    haptics = true;
    reduceMotion = false;
    largeText = false;
    onePointerReveal = false;
    leftHanded = false;
    keepAwake = true;
    hostMode = false;
    pinMoments = true;
    notifyListeners();
  }
}
