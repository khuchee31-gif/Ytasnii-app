// S03 — Бүрэлдэхүүн ба хүчинтэй эсэх. GDD-06.
//
// ЭНЭ ДЭЛГЭЦИЙН ЦОРЫН ГАНЦ ХАТУУ ТАТГАЛЗАЛ: `b < 0` бол «Тараая» ТҮГЖИГДЭНЭ.
// «Ямар ч байсан эхлэх» товч БАЙХГҮЙ, удаан дарах гарц БАЙХГҮЙ (GDD-04 §3,
// GDD-00 §4). Энэ ганц түгжээ нь эхний тоглолтоо аль хэдийн алдсан ангийг
// аварна.

import 'package:engine/engine.dart';
import 'package:flutter/material.dart' hide Intent;

import '../game/game_controller.dart';
import '../game/settings.dart';
import '../ui/tokens.dart';
import '../ui/widgets.dart';
import 'setup_parts.dart';

class PresetScreen extends StatefulWidget {
  const PresetScreen({
    super.key,
    required this.controller,
    required this.onDeal,
  });

  final GameController controller;

  /// «Тараая» → S04. `b < 0` үед ХЭЗЭЭ Ч дуудагдахгүй.
  final VoidCallback onDeal;

  @override
  State<PresetScreen> createState() => _PresetScreenState();
}

class _PresetScreenState extends State<PresetScreen> {
  late int _n;
  late int _mafia;
  late bool _doctor;
  late bool _detective;

  @override
  void initState() {
    super.initState();
    final Roster r = widget.controller.roster;
    _n = r.n;
    _mafia = r.mafia;
    _doctor = r.doctor;
    _detective = r.detective;
  }

  /// Ахлагч нь Алуурчны НЭГ суудлыг эзэлнэ — тусдаа суудал биш. `M >= 3`
  /// (12+ суудал) үед өөрөө гарна, гараар асаах товч байхгүй (GDD-04 §2.1).
  bool get _boss => _mafia >= 3;

  int get _citizens => _n - _mafia - (_doctor ? 1 : 0) - (_detective ? 1 : 0);
  int get _b => b0(_n, _mafia);

  SetupCheck get _check => checkSetup(
        n: _n,
        mafia: _mafia,
        boss: _boss,
        doctor: _doctor,
        detective: _detective,
      );

  void _pickPreset(PresetId id) {
    final PresetSpec p = kPresets[id]!;
    setState(() {
      widget.controller.settings.apply(id);
      _n = p.seatCount;
      _mafia = p.mafiaCount;
      _doctor = true;
      _detective = true;
    });
  }

  void _edit(VoidCallback change) {
    // Чип хөдөлмөгц зөвхөн уншигдах багц «Сонгодог» руу хуулагдана.
    setState(() {
      widget.controller.settings.edit(change);
    });
  }

  void _deal() {
    final Roster r = Roster(
      n: _n,
      mafia: _mafia,
      boss: _boss,
      doctor: _doctor,
      detective: _detective,
      citizens: _citizens,
      b: _b,
    );
    widget.controller.setComposition(r);
    widget.onDeal();
  }

  @override
  Widget build(BuildContext context) {
    final GameSettings s = widget.controller.settings;
    final SetupCheck check = _check;

    return PhoneScaffold(
      title: 'Бүрэлдэхүүн',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // Дээд зах — дөрвөн урьдчилсан багц (GDD-03 §3).
          PresetCards(selected: s.basePreset, onPick: _pickPreset),
          if (s.copiedToSongodog)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('Сонгодог болгож хадгаллаа.',
                  style:
                      TextStyle(fontSize: 14, height: 1.45, color: kTextMuted)),
            ),
          const SizedBox(height: 20),

          // --- Чипүүд ---------------------------------------------------
          Stepper48(
            label: 'Суудал',
            value: '$_n',
            big: true,
            onMinus: _n > kMinSeats
                ? () => _edit(() => _n--)
                : null,
            onPlus:
                _n < kMaxSeats ? () => _edit(() => _n++) : null,
          ),
          const SizedBox(height: 8),
          Stepper48(
            label: 'Алуурчин',
            note: _boss ? 'Ахлагч нэг суудлыг эзэлнэ' : null,
            value: '$_mafia',
            valueColor: _b < 0 ? kDanger : null,
            onMinus:
                _mafia > 0 ? () => _edit(() => _mafia--) : null,
            onPlus: _mafia < _n - 1
                ? () => _edit(() => _mafia++)
                : null,
          ),
          const SizedBox(height: 8),
          Stepper48(
            label: 'Эмч',
            value: _doctor ? '1' : '0',
            onMinus: _doctor ? () => _edit(() => _doctor = false) : null,
            onPlus: _doctor ? null : () => _edit(() => _doctor = true),
          ),
          const SizedBox(height: 8),
          Stepper48(
            label: 'Мөрдөгч',
            value: _detective ? '1' : '0',
            onMinus: _detective
                ? () => _edit(() => _detective = false)
                : null,
            onPlus: _detective
                ? null
                : () => _edit(() => _detective = true),
          ),
          const SizedBox(height: 8),
          // Иргэн нь ТООЦООЛОГДДОГ — гараар өөрчлөгдөхгүй тул `+`/`−` байхгүй.
          Row(
            children: <Widget>[
              Expanded(
                child: Text('Иргэн',
                    style: kBody.copyWith(color: kTextMuted)),
              ),
              const SizedBox(width: kGap),
              Flexible(
                child: Text('$_citizens',
                    textAlign: TextAlign.right,
                    style: kBody.copyWith(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: _citizens < 0 ? kDanger : kTextPrimary)),
              ),
            ],
          ),

          const SizedBox(height: 20),
          // --- Тооны самбар ---------------------------------------------
          InfoCard(children: <Widget>[
            _ScoreBoard(b: _b, reduceMotion: s.reduceMotion),
            const SizedBox(height: 8),
            Text(
              check.messageMn,
              style: TextStyle(
                  fontSize: 15,
                  height: 1.45,
                  fontWeight: check.isReject ? FontWeight.w700 : FontWeight.w400,
                  color: switch (check.verdict) {
                    SetupVerdict.green => kOk,
                    SetupVerdict.warn => kEmber,
                    SetupVerdict.reject => kDanger,
                  }),
            ),
          ]),
          const SizedBox(height: kGap),

          // --- Суудлын уншилт -------------------------------------------
          InfoCard(children: <Widget>[
            InfoRow('Суудал', '$_n'),
            InfoRow('Мафи', '$_mafia${_boss ? " (Ахлагчтай)" : ""}'),
            InfoRow('Эмч · Мөрдөгч',
                '${_doctor ? "тийм" : "үгүй"} · ${_detective ? "тийм" : "үгүй"}'),
            InfoRow('Иргэн', '$_citizens'),
          ]),

          // GDD-11 §8 — зөвхөн хамгийн анхны тоглолтод, блоклохгүй нэг мөр.
          if (widget.controller.gamesPlayed == 0) ...<Widget>[
            const SizedBox(height: kGap),
            TextButton(
              onPressed: () => setState(() => s.hostMode = true),
              style: TextButton.styleFrom(
                  alignment: Alignment.centerLeft,
                  minimumSize: const Size.fromHeight(kMinTouch),
                  foregroundColor: kTextMuted),
              child: Text(
                s.hostMode
                    ? 'Хөтлөгчтэй горим асаалттай.'
                    : 'Ангид мафи тоглож үзсэн хүн байна уу? → Тэр хөтөлж болно',
                style: TextStyle(
                    fontSize: 14,
                    height: 1.45,
                    color: s.hostMode ? kEmber : kTextMuted),
              ),
            ),
          ],
        ],
      ),
      // `b < 0` — товч ТҮГЖЭЭТЭЙ. Өөр гарц байхгүй.
      action: FilledButton(
        onPressed: check.isReject ? null : _deal,
        child: const Text('Тараая'),
      ),
    );
  }
}

/// Бүх урсгалын хамгийн хямд механик (GDD-06 S03, GDD-04 §5.1).
/// Дүрийг ХЭЗЭЭ Ч уншихгүй — зөвхөн `n` ба `M`.
class _ScoreBoard extends StatelessWidget {
  const _ScoreBoard({required this.b, required this.reduceMotion});

  final int b;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    final Color c = b >= 2 ? kOk : (b == 1 ? kEmber : kDanger);
    // Утга нь ӨНГӨ БА ХЭЛБЭР БА КИРИЛЛ ШОШГО-оор — хэзээ ч зөвхөн өнгөөр биш.
    final String line = switch (b) {
      < 0 => 'Алдаж болох санал: ✕',
      0 => 'Алдаж болох санал: ○ — дууслаа. Өнөөдөр онох ёстой.',
      1 => 'Алдаж болох санал: ● — сүүлчийн нэг.',
      _ => 'Алдаж болох санал: ${'● ' * b}'.trimRight(),
    };
    return Semantics(
      label: 'Алдаж болох санал: ${b < 0 ? "боломжгүй" : mnNumber(b)}',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Хуваалцсан виджет — өдрийн дээд мөртэй ИЖИЛ харагдана.
            if (reduceMotion)
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text('Алдаж болох санал',
                        style: kBody.copyWith(color: kTextMuted)),
                  ),
                  const SizedBox(width: kGap),
                  Flexible(
                    child: Text('$b',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: c)),
                  ),
                ],
              )
            else
              PipStrip(b),
            const SizedBox(height: 6),
            Text(line,
                style: TextStyle(
                    fontSize: 15,
                    height: 1.45,
                    fontWeight: FontWeight.w600,
                    color: c)),
          ],
        ),
      ),
    );
  }
}
