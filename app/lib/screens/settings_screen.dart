// S21 — Тохиргоо. GDD-06, GDD-03 §2/§3/§4.
//
// Нэг гүйлгэгддэг жагсаалт, хэсэглэлгүй. Дээд талд дөрвөн preset карт, доор
// гэрийн дүрмийн ДӨРӨВ, доор «Дэлгэрэнгүй» нугалаа, доод мөрөнд `b` бэхлэгдсэн.
//
// ЦАРЦСАН ДҮРЭМ ЭНД ОГТ ГАРАХГҮЙ (GDD-03 §1-ийн Зарчим 2): `nightFirst`,
// `night0Kill`, `winRule`, `votingMode`, `defenceSeconds`, `whisperMinAgree`,
// `hammer`, `deadCanSpeak` … Унтраалттай мөртөө дарагддаггүй toggle бол
// хамгийн хортой UI — хүүхэд түүнийг дараад аппад итгэхээ болино.
//
// `foulWarnings` («Сануулга бүртгэх») БҮХЭЛДЭЭ УСТГАГДСАН — GDD-03 §4.

import 'dart:async';

import 'package:engine/engine.dart' show SelfHeal, b0;
import 'package:flutter/material.dart' hide Intent;

import '../game/game_controller.dart';
import '../game/phase.dart';
import '../game/settings.dart';
import '../ui/tokens.dart';
import '../ui/widgets.dart';
import 'setup_parts.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.controller,
    required this.onClose,
    this.onNarratorPreview,
  });

  final GameController controller;
  final VoidCallback onClose;

  /// «Хөтлөгч юу хэлэх вэ?» — 40 секундын сонсгол. Аудио давхарга
  /// холбогдоогүй бол `null`, мөр нь бүдэг.
  final VoidCallback? onNarratorPreview;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Timer? _copiedTimer;
  Timer? _armTimer;

  /// «Бүх өгөгдлийг устгах» — хоёр товшилт, хоёр дахь товч 3 секунд бүдэг.
  bool _wipeAsked = false;
  bool _wipeArmed = false;

  GameSettings get _s => widget.controller.settings;

  /// Тоглолт явж байх үед дэлгэц НЭЭГДЭНЭ, өөрчлөлт хадгалагдана, гэвч явж
  /// байгаа тоглолт түүнийг уншихгүй (GDD-06 S21, GDD-03 §5).
  bool get _inGame =>
      widget.controller.phase != GamePhase.appOpen &&
      widget.controller.phase != GamePhase.roster &&
      widget.controller.phase != GamePhase.preset &&
      widget.controller.phase != GamePhase.validate;

  @override
  void dispose() {
    _copiedTimer?.cancel();
    _armTimer?.cancel();
    super.dispose();
  }

  void _edit(VoidCallback change) {
    setState(() {
      _s.edit(change);
    });
    if (_s.copiedToSongodog) {
      // «Сонгодог болгож хадгаллаа.» — 1.5 сек, доод мөрөнд, ТОВЧГҮЙ.
      _copiedTimer?.cancel();
      _copiedTimer = Timer(const Duration(milliseconds: 1500), () {
        if (!mounted) return;
        setState(_s.clearCopiedFlag);
      });
    }
  }

  void _askWipe() {
    setState(() {
      _wipeAsked = true;
      _wipeArmed = false;
    });
    _armTimer?.cancel();
    _armTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() => _wipeArmed = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final GameSettings s = _s;
    final int b = b0(
      widget.controller.roster.n,
      widget.controller.roster.mafia,
    );

    return PhoneScaffold(
      title: 'Тохиргоо',
      subtitle: _inGame ? 'Дараагийн тоглолтод хүчинтэй' : null,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          PresetCards(
            selected: s.basePreset,
            onPick: (PresetId id) {
              setState(() => s.apply(id));
            },
          ),
          const SizedBox(height: 20),

          // --- Гэрийн дүрмийн дөрөв (GDD-03 §4) ---------------------------
          const _SectionLabel('Гэрийн дүрэм'),
          ChoiceRow<SelfHeal>(
            label: 'Эмч өөрийгөө аврах',
            hint: 'Эмч шөнө өөрийнхөө дугаарыг сонгож болох уу?',
            options: SelfHeal.values,
            value: s.doctorSelfHeal,
            labelOf: (SelfHeal v) => v.labelMn,
            consequenceOf: (SelfHeal v) => v.consequenceMn,
            onChanged: (SelfHeal v) => _edit(() => s.doctorSelfHeal = v),
          ),
          ToggleRow(
            label: 'Мафи өөрийн хүнээ буудаж болно',
            hint: 'Мафи шөнө нөгөө мафийн дугаарыг сонгож болох уу?',
            value: s.mafiaFriendlyFire,
            consequence: s.mafiaFriendlyFire
                ? 'Худал зарах нүүдэл болдог.'
                : 'Апп тэр дугаарыг хүлээж авахгүй.',
            onChanged: (bool v) => _edit(() => s.mafiaFriendlyFire = v),
          ),
          ToggleRow(
            label: 'Хасагдахад дүрийг нээх',
            hint: 'Хотоос хөөгдсөн хүн юу байснаа тэр даруй мэдэгдэх үү?',
            value: s.revealRoleOnDeath,
            consequence: s.revealRoleOnDeath
                ? 'Тоглоом хурдан бөгөөд хялбар болно.'
                : 'Тоглоом дуусахад «Хөзрөө нээе» болно.',
            onChanged: (bool v) => _edit(() => s.revealRoleOnDeath = v),
          ),
          ChoiceRow<TieRule>(
            label: 'Санал тэнцвэл',
            hint: 'Хоёр дугаар ижил санал авбал юу болох вэ?',
            options: TieRule.values,
            value: s.tieRule,
            labelOf: (TieRule v) => v.labelMn,
            consequenceOf: (TieRule v) => v.consequenceMn,
            onChanged: (TieRule v) => _edit(() => s.tieRule = v),
          ),
          const SizedBox(height: 20),

          // --- Дэлгэрэнгүй -------------------------------------------------
          FoldSection(
            title: 'Дэлгэрэнгүй',
            children: <Widget>[
              _NarratorPreviewRow(onTap: widget.onNarratorPreview),
              ToggleRow(
                label: 'Дуу',
                hint: 'Унтраавал бүх завсар хэвээр барина.',
                value: s.sound,
                onChanged: (bool v) => _edit(() => s.sound = v),
              ),
              ToggleRow(
                label: 'Чичиргээ',
                value: s.haptics,
                onChanged: (bool v) => _edit(() => s.haptics = v),
              ),
              ToggleRow(
                label: 'Хөдөлгөөн багасгах',
                hint: 'Цагираг — тоо, харанхуйлалт унтарна.',
                value: s.reduceMotion,
                onChanged: (bool v) => _edit(() => s.reduceMotion = v),
              ),
              ToggleRow(
                label: 'Том текст',
                hint: '200 % хүртэл, бүх мөр таарна.',
                value: s.largeText,
                onChanged: (bool v) => _edit(() => s.largeText = v),
              ),
              ToggleRow(
                label: 'Нэг хуруугаар нээх',
                hint: 'Барих хугацаа 1200 мс болно.',
                value: s.onePointerReveal,
                onChanged: (bool v) => _edit(() => s.onePointerReveal = v),
              ),
              ToggleRow(
                label: 'Зүүн гар',
                hint: 'Саналын арк доод зүүн булан болж эргэнэ.',
                value: s.leftHanded,
                onChanged: (bool v) => _edit(() => s.leftHanded = v),
              ),
              ToggleRow(
                label: 'Дэлгэц унтраахгүй',
                value: s.keepAwake,
                onChanged: (bool v) => _edit(() => s.keepAwake = v),
              ),
              ToggleRow(
                label: 'Хотын шивнээ',
                value: s.cityWhisper,
                onChanged: (bool v) => _edit(() => s.cityWhisper = v),
              ),
              ToggleRow(
                label: 'Хөтлөгчтэй горим',
                hint: 'Шөнийг хүн хөтөлнө, апп тоолно.',
                value: s.hostMode,
                onChanged: (bool v) => _edit(() => s.hostMode = v),
              ),
              _ValueStepper(
                label: 'Нэг хүний үг',
                options: const <int>[30, 40, 45, 60, 90],
                value: s.speechSeconds,
                suffix: 'сек',
                onChanged: (int v) => _edit(() {
                  s.speechSeconds = v;
                  // GDD-03 §2: `dayMaxMinutes` нь N × үгээс ГАРГАЖ АВНА.
                  s.dayMaxMinutes = ((widget.controller.seatCount * v) / 60)
                      .ceil()
                      .clamp(3, 12);
                }),
              ),
              _ValueStepper(
                label: 'Өдрийн дээд хугацаа',
                options: const <int>[3, 4, 5, 6, 7, 8, 9, 10, 11, 12],
                value: s.dayMaxMinutes,
                suffix: 'мин',
                onChanged: (int v) => _edit(() => s.dayMaxMinutes = v),
              ),
              _ValueStepper(
                label: 'Шөнө нэг суудал',
                hint: 'Тоглолт эхлэхэд царцана.',
                options: const <int>[4, 5, 6, 7, 8, 9, 10],
                value: s.nightSeatSeconds,
                suffix: 'сек',
                onChanged: (int v) => _edit(() => s.nightSeatSeconds = v),
              ),
              _ValueStepper(
                label: 'Танилцах шөнө',
                options: const <int>[45, 60, 75],
                value: s.acquaintSeconds,
                suffix: 'сек',
                onChanged: (int v) => _edit(() => s.acquaintSeconds = v),
              ),
              _ValueStepper(
                label: 'Сүүлчийн үг',
                options: const <int>[0, 15, 30, 45, 60],
                value: s.lastWordsSeconds,
                suffix: 'сек',
                onChanged: (int v) => _edit(() => s.lastWordsSeconds = v),
              ),
              ToggleRow(
                label: 'Шилдэг нүүдэл',
                value: s.bestMove,
                onChanged: (bool v) => _edit(() => s.bestMove = v),
              ),
              ToggleRow(
                label: 'LYLO сануулга',
                value: s.lyloBanner,
                onChanged: (bool v) => _edit(() => s.lyloBanner = v),
              ),
              ToggleRow(
                label: 'Тэмдэглэ',
                value: s.pinMoments,
                onChanged: (bool v) => _edit(() => s.pinMoments = v),
              ),
              const SizedBox(height: kGap),

              // GDD-12 §9 — хоёр товшилт, хоёр дахь товч 3 секунд бүдэг.
              if (!_wipeAsked)
                OutlinedButton(
                  onPressed: _askWipe,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: kDanger,
                    minimumSize: const Size.fromHeight(kMinTouch),
                  ),
                  child: const Text('Бүх өгөгдлийг устгах'),
                )
              else ...<Widget>[
                const Text(
                  'Ангийн дэвтэр, суудлын жагсаалт, бүх тоглолт, бүх цол '
                  '— бүгд устана. Буцаах боломжгүй.',
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.45,
                    color: kTextPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: _wipeArmed
                      ? () {
                          setState(() {
                            widget.controller.seatNames.clear();
                            widget.controller.hasSavedRoster = false;
                            widget.controller.gamesPlayed = 0;
                            s.resetAll();
                            _wipeAsked = false;
                            _wipeArmed = false;
                          });
                        }
                      : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: kDanger,
                    foregroundColor: kTextPrimary,
                  ),
                  child: const Text('Устгах'),
                ),
              ],
            ],
          ),

          if (s.copiedToSongodog)
            const Text(
              'Сонгодог болгож хадгаллаа.',
              style: TextStyle(fontSize: 14, height: 1.45, color: kTextMuted),
            ),
        ],
      ),
      action: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // Доод мөрөнд `b` БЭХЛЭГДСЭН — байнга харагдаж байдаг цорын ганц тоо.
          PipStrip(b),
          const SizedBox(height: 8),
          FilledButton(onPressed: widget.onClose, child: const Text('Хаах')),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text, style: kLabel.copyWith(color: kTextMuted)),
  );
}

class _NarratorPreviewRow extends StatelessWidget {
  const _NarratorPreviewRow({required this.onTap});
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bool on = onTap != null;
    return Semantics(
      button: true,
      enabled: on,
      label: 'Хөтлөгч юу хэлэх вэ? 40 секундын сонсгол',
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: kMinTouch),
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: ExcludeSemantics(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Хөтлөгч юу хэлэх вэ?',
                  style: kBody.copyWith(color: on ? kTextPrimary : kTextMuted),
                ),
                Text(
                  '40 секундын сонсгол.',
                  style: kLabel.copyWith(
                    color: kTextMuted,
                    letterSpacing: 0,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Хэдэн тогтсон утгын дундаас сонгох мөр. Сегментчилсэн товч 360px дээр
/// халина — тиймээс `−` / `+`.
class _ValueStepper extends StatelessWidget {
  const _ValueStepper({
    required this.label,
    required this.options,
    required this.value,
    required this.suffix,
    required this.onChanged,
    this.hint,
  });

  final String label;
  final List<int> options;
  final int value;
  final String suffix;
  final ValueChanged<int> onChanged;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final int i = options.indexOf(value);
    final int cur = i < 0 ? 0 : i;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Stepper48(
        label: label,
        note: hint,
        value: '$value $suffix',
        valueWidth: 80,
        onMinus: cur > 0 ? () => onChanged(options[cur - 1]) : null,
        onPlus: cur < options.length - 1
            ? () => onChanged(options[cur + 1])
            : null,
      ),
    );
  }
}
