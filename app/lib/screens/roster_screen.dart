// S02 — Ангийн суудал. GDD-06.
//
// Нэр ЗААВАЛ БИШ: хоосон бол `{n}-р тоглогч` гэж өөрөө бөглөгдөнө. Нэр оруулах
// нь хоёрдогч урсгал — хэн нэг нь тавтай суугаад бөглөх ажил. Тиймээс дэлгэц
// нэр асуухгүй, зөвхөн зай үлдээнэ.
//
// Дараалал = ӨДРИЙН ҮГ ХЭЛЭХ ДАРААЛАЛ. Тиймээс мөрийн зүүн талын дугаар
// хөдөлдөггүй, харин НЭР нь суудлын хооронд шилждэг.

import 'package:engine/engine.dart';
import 'package:flutter/material.dart' hide Intent;

import '../game/game_controller.dart';
import '../ui/tokens.dart';
import '../ui/widgets.dart';
import 'setup_parts.dart';

class RosterScreen extends StatefulWidget {
  const RosterScreen({
    super.key,
    required this.controller,
    required this.onContinue,
  });

  final GameController controller;

  /// S03 руу. Суудал бүртгэгдсэний дараа л дуудагдана.
  final VoidCallback onContinue;

  @override
  State<RosterScreen> createState() => _RosterScreenState();
}

class _SeatRow {
  _SeatRow(this.name) : key = UniqueKey();
  final Key key;
  final TextEditingController name;
  bool absent = false;
}

class _RosterScreenState extends State<RosterScreen> {
  final List<_SeatRow> _rows = <_SeatRow>[];

  @override
  void initState() {
    super.initState();
    // `empty` — 10 суудал өөрөө үүсгэгдэнэ, нэр хоосон.
    // `restored` — сүүлийн суудлын жагсаалт.
    final int start =
        widget.controller.hasSavedRoster ? widget.controller.seatCount : 10;
    for (int i = 1; i <= start; i++) {
      _rows.add(_SeatRow(
          TextEditingController(text: widget.controller.seatNames[i] ?? '')));
    }
  }

  @override
  void dispose() {
    for (final _SeatRow r in _rows) {
      r.name.dispose();
    }
    super.dispose();
  }

  /// Ширээнд бодитоор сууж байгаа хүн — «Байхгүй хүн» хасагдсаны дараа.
  int get _present => _rows.where((_SeatRow r) => !r.absent).length;

  void _add() {
    if (_present >= kMaxSeats) return;
    setState(() => _rows.add(_SeatRow(TextEditingController())));
  }

  void _remove() {
    if (_present <= 1) return;
    final int i = _rows.lastIndexWhere((_SeatRow r) => !r.absent);
    if (i < 0) return;
    setState(() {
      _rows.removeAt(i).name.dispose();
    });
  }

  void _toggleAbsent(int i) =>
      setState(() => _rows[i].absent = !_rows[i].absent);

  void _reorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      _rows.insert(newIndex, _rows.removeAt(oldIndex));
    });
  }

  void _commit() {
    final GameController c = widget.controller;
    c.seatNames.clear();
    int seat = 1;
    for (final _SeatRow r in _rows) {
      if (r.absent) continue;
      final String t = r.name.text.trim();
      if (t.isNotEmpty) c.seatNames[seat] = t;
      seat++;
    }
    c.seatCount = _present;
    c.clearComposition();
    c.hasSavedRoster = true;
    widget.onContinue();
  }

  @override
  Widget build(BuildContext context) {
    final int n = _present;
    final bool even = n.isEven;
    // n < 6 үед `rosterFor` шиднэ — тиймээс шалгагчийг ШУУД дуудна.
    final SetupCheck check = checkSetup(
        n: n, mafia: 1, boss: false, doctor: true, detective: true);
    final bool tooFew = n < kMinSeats;

    return PhoneScaffold(
      title: 'Хэдүүлээ вэ?',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // Дээд зах — зөвхөн унших зай. Тоо нь ширээний нөгөө талаас
          // уншигдана; тэгш тоо дээр цайрч, сондгой дээр бүдгэрнэ.
          Semantics(
            label: '${mnNumber(n)} тоглогч',
            child: ExcludeSemantics(
              child: Center(
                child: Text('$n',
                    style: kSeatNumber.copyWith(
                        color: tooFew
                            ? kDanger
                            : (even ? kTextPrimary : kTextMuted))),
              ),
            ),
          ),
          const SizedBox(height: 4),
          if (!even && !tooFew)
            // Сануулга, ТАТГАЛЗАЛ БИШ (GDD-06 S02).
            const Text('Сондгой тоо мафид ашигтай.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, height: 1.45, color: kEmber)),
          if (tooFew)
            Text(check.messageMn,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 16,
                    height: 1.45,
                    fontWeight: FontWeight.w700,
                    color: kDanger)),
          const SizedBox(height: kGap),
          const Text('Нэр заавал биш. Хоосон бол дугаараараа явна.',
              style: TextStyle(fontSize: 14, height: 1.45, color: kTextMuted)),
          const SizedBox(height: 8),
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            itemCount: _rows.length,
            onReorder: _reorder,
            itemBuilder: (BuildContext context, int i) => _SeatLine(
              key: _rows[i].key,
              index: i,
              seatNumber: _seatNumberAt(i),
              row: _rows[i],
              onAbsent: () => _toggleAbsent(i),
            ),
          ),
        ],
      ),
      action: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // Нэг гараар: `+` / `−` доод БАРУУН булан, 56 dp.
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: <Widget>[
              _BigStep(
                  glyph: '−',
                  semantic: 'Суудал хасах',
                  onTap: _present > 1 ? _remove : null),
              const SizedBox(width: kGap),
              _BigStep(
                  glyph: '+',
                  semantic: 'Суудал нэмэх',
                  onTap: _present < kMaxSeats ? _add : null),
            ],
          ),
          const SizedBox(height: kGap),
          FilledButton(
            onPressed: tooFew ? null : _commit,
            child: const Text('Үргэлжлүүлэх'),
          ),
        ],
      ),
    );
  }

  /// Хасагдаагүй суудлуудын дугаар 1..N. «Байхгүй хүн» дугаар эзлэхгүй.
  int? _seatNumberAt(int i) {
    if (_rows[i].absent) return null;
    int seat = 0;
    for (int k = 0; k <= i; k++) {
      if (!_rows[k].absent) seat++;
    }
    return seat;
  }
}

class _SeatLine extends StatelessWidget {
  const _SeatLine({
    super.key,
    required this.index,
    required this.seatNumber,
    required this.row,
    required this.onAbsent,
  });

  final int index;
  final int? seatNumber;
  final _SeatRow row;
  final VoidCallback onAbsent;

  @override
  Widget build(BuildContext context) {
    final bool absent = row.absent;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 30,
            child: Text(absent ? '—' : '${seatNumber ?? ''}',
                style: kBody.copyWith(
                    fontWeight: FontWeight.w700,
                    color: absent ? kTextMuted : kEmber)),
          ),
          const SizedBox(width: 8),
          // Уян хатан — урт нэр мөрийг халихгүй.
          Expanded(
            child: TextField(
              controller: row.name,
              enabled: !absent,
              style: kBody.copyWith(
                  color: absent ? kTextMuted : kTextPrimary,
                  decoration:
                      absent ? TextDecoration.lineThrough : TextDecoration.none),
              decoration: InputDecoration(
                isDense: true,
                hintText: seatNumber == null
                    ? 'Байхгүй хүн'
                    : '$seatNumber-р тоглогч',
                hintStyle: kBody.copyWith(color: kTextMuted),
                border: const UnderlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Semantics(
            button: true,
            label: absent ? 'Буцааж суулгах' : 'Байхгүй хүн',
            child: InkWell(
              onTap: onAbsent,
              borderRadius: BorderRadius.circular(kRadius),
              child: SizedBox(
                width: kMinTouch,
                height: kMinTouch,
                child: Center(
                  child: ExcludeSemantics(
                    child: Text(absent ? '↺' : '⊘',
                        style: TextStyle(
                            fontSize: 20,
                            height: 1.0,
                            color: absent ? kEmber : kTextMuted)),
                  ),
                ),
              ),
            ),
          ),
          ReorderableDragStartListener(
            index: index,
            child: Semantics(
              label: 'Дараалал солих',
              child: const SizedBox(
                width: kMinTouch,
                height: kMinTouch,
                child: Center(
                  child: ExcludeSemantics(
                    child: Text('≡',
                        style: TextStyle(
                            fontSize: 20, height: 1.0, color: kTextMuted)),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BigStep extends StatelessWidget {
  const _BigStep(
      {required this.glyph, required this.semantic, required this.onTap});

  final String glyph;
  final String semantic;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bool on = onTap != null;
    return Semantics(
      button: true,
      enabled: on,
      label: semantic,
      child: Material(
        color: on ? kSurfaceHigh : kSurfaceRaised.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(kRadius),
        child: InkWell(
          borderRadius: BorderRadius.circular(kRadius),
          onTap: onTap,
          child: SizedBox(
            width: 56,
            height: 56,
            child: Center(
              child: ExcludeSemantics(
                child: Text(glyph,
                    style: TextStyle(
                        fontSize: 28,
                        height: 1.0,
                        fontWeight: FontWeight.w700,
                        color: on ? kTextPrimary : kTextMuted)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
