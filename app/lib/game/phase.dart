// Тоглолтын 19 төлөв — GDD-01 §1.
//
// Дүрэм нэмэх нь төлөв нэмэхгүй: шинэ дүрэм өдрийн дэд төлөв дотор амьдарна.
// Тойрог давтагддаг хэсэг нь яг дөрөв: NIGHT_CIRCUIT → DAWN → өдөр → WIN_CHECK.

enum GamePhase {
  appOpen,
  roster,
  preset,
  validate,
  fairness,
  deal,
  night0,
  nightCircuit,
  dawn,
  bestMove,
  speechRound,
  freeTalk,
  nomination,
  defence,
  handsVote,
  elimination,
  winCheck,
  ceremony,
  ledger,

  /// Ямар ч төлөвөөс орж, яг тэр төлөв рүүгээ буцна (GDD-01 §6).
  paused,
}

extension GamePhaseX on GamePhase {
  /// Дэлгэц ширээн дунд байх үед үнэн — утас нэг хүний гарт биш.
  bool get isTableFacing => switch (this) {
    GamePhase.night0 ||
    GamePhase.dawn ||
    GamePhase.speechRound ||
    GamePhase.freeTalk ||
    GamePhase.defence ||
    GamePhase.elimination ||
    GamePhase.ceremony => true,
    _ => false,
  };

  /// Нууц мэдээлэл дэлгэцэн дээр гарч болзошгүй — `FLAG_SECURE` асаана
  /// (GDD-06, GDD-10 §5).
  bool get needsSecureFlag =>
      this == GamePhase.deal || this == GamePhase.nightCircuit;

  String get labelMn => switch (this) {
    GamePhase.appOpen => 'Нүүр',
    GamePhase.roster => 'Суудал',
    GamePhase.preset => 'Бүрэлдэхүүн',
    GamePhase.validate => 'Шалгалт',
    GamePhase.fairness => 'Шударга байдлын код',
    GamePhase.deal => 'Хөзөр тараах',
    GamePhase.night0 => 'Танилцах шөнө',
    GamePhase.nightCircuit => 'Шөнийн эргэлт',
    GamePhase.dawn => 'Үүр',
    GamePhase.bestMove => 'Шилдэг нүүдэл',
    GamePhase.speechRound => 'Үгийн тойрог',
    GamePhase.freeTalk => 'Чөлөөт хэлэлцүүлэг',
    GamePhase.nomination => 'Нэр дэвшүүлэлт',
    GamePhase.defence => 'Өмгөөлөл',
    GamePhase.handsVote => 'Санал хураалт',
    GamePhase.elimination => 'Хасалт',
    GamePhase.winCheck => 'Ялалт шалгах',
    GamePhase.ceremony => 'Хөзрөө нээе',
    GamePhase.ledger => 'Өнөөдрийн тэмдэглэл',
    GamePhase.paused => 'Түр зогсоов',
  };
}
