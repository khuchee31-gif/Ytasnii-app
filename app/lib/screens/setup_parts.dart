// Бүлэг А-ийн (S00–S03, S21, S22) хуваалцсан жижиг хэсгүүд.
//
// `lib/ui/widgets.dart` бол бүх бүлгийн гэрээ — түүнийг өөрчлөхгүй. Энд зөвхөн
// тохируулгын дэлгэцүүдэд хэрэгтэй хэсгүүд байна.
//
// ГАР УТАСНЫ ДҮРЭМ: мөр бүрийн хоёр тал уян хатан. Тогтмол өргөнтэй Row нь
// 360px дээр халина — тэр алдаа энэ багцад аль хэдийн нэг удаа гарсан.

import 'package:flutter/material.dart' hide Intent;

import '../game/settings.dart';
import '../ui/tokens.dart';

/// TalkBack-ийн тоо — «арван хоёр тоглогч» (GDD-06 S01). 0..20 хангалттай:
/// ширээ 20 суудлаар тагласан (`kMaxSeats`).
const List<String> _kWords = <String>[
  'тэг', 'нэг', 'хоёр', 'гурав', 'дөрөв', 'тав', 'зургаа', 'долоо', 'найм',
  'ес', 'арав', 'арван нэг', 'арван хоёр', 'арван гурав', 'арван дөрөв',
  'арван тав', 'арван зургаа', 'арван долоо', 'арван найм', 'арван ес', 'хорь',
];

String mnNumber(int n) => (n >= 0 && n < _kWords.length) ? _kWords[n] : '$n';

/// Дөрвөн preset карт, хоёр хоёроор, хэвтээ гулсалтгүй (GDD-03 §3).
class PresetCards extends StatelessWidget {
  const PresetCards({
    super.key,
    required this.selected,
    required this.onPick,
  });

  final PresetId selected;
  final ValueChanged<PresetId> onPick;

  @override
  Widget build(BuildContext context) {
    const List<PresetId> ids = PresetId.values;
    return Column(
      children: <Widget>[
        for (int row = 0; row < 2; row++) ...<Widget>[
          if (row > 0) const SizedBox(height: kGap),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Expanded(
                  child: _PresetCard(
                      id: ids[row * 2],
                      selected: ids[row * 2] == selected,
                      onTap: () => onPick(ids[row * 2])),
                ),
                const SizedBox(width: kGap),
                Expanded(
                  child: _PresetCard(
                      id: ids[row * 2 + 1],
                      selected: ids[row * 2 + 1] == selected,
                      onTap: () => onPick(ids[row * 2 + 1])),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _PresetCard extends StatelessWidget {
  const _PresetCard(
      {required this.id, required this.selected, required this.onTap});

  final PresetId id;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '${id.labelMn}. ${id.subtitleMn}',
      child: Material(
        color: selected ? kSurfaceHigh : kSurfaceRaised,
        borderRadius: BorderRadius.circular(kRadius),
        child: InkWell(
          borderRadius: BorderRadius.circular(kRadius),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: kMinTouch + 24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(kRadius),
              border: Border.all(
                  color: selected ? kEmber : kHairline,
                  width: selected ? 2 : 1),
            ),
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    // Утга нь өнгө БА хэлбэр БА кирилл шошгоор (GDD-06 §0).
                    Text(selected ? '◉' : '○',
                        style: TextStyle(
                            fontSize: 16,
                            color: selected ? kEmber : kTextMuted)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(id.labelMn,
                          style: kBody.copyWith(
                              fontWeight: FontWeight.w700,
                              color: kTextPrimary)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(id.subtitleMn,
                    style: kLabel.copyWith(
                        color: kTextMuted,
                        letterSpacing: 0,
                        fontWeight: FontWeight.w400)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// `−` / `+` тоон нэмэгч. Товч тус бүр 48dp, хооронд 8dp (GDD-06 S03).
class Stepper48 extends StatelessWidget {
  const Stepper48({
    super.key,
    required this.label,
    required this.value,
    required this.onMinus,
    required this.onPlus,
    this.note,
    this.valueColor,
    this.big = false,
    this.valueWidth,
  });

  final String label;
  final String value;

  /// `null` бол тэр тал нь түгжээтэй — товч байрандаа үлдэнэ, дарагдахгүй.
  final VoidCallback? onMinus;
  final VoidCallback? onPlus;
  final String? note;
  final Color? valueColor;
  final bool big;

  /// Утгын хайрцгийн өргөн. Урт утга («90 сек») тоон дээр халихгүй.
  final double? valueWidth;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label: $value',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    ExcludeSemantics(
                      child: Text(label,
                          style: kBody.copyWith(color: kTextPrimary)),
                    ),
                    if (note != null)
                      ExcludeSemantics(
                        child: Text(note!,
                            style: kLabel.copyWith(
                                color: kTextMuted,
                                letterSpacing: 0,
                                fontWeight: FontWeight.w400)),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: kGap),
              _SquareButton(
                  glyph: '−', onTap: onMinus, semantic: '$label — хасах'),
              const SizedBox(width: 8),
              ExcludeSemantics(
                child: SizedBox(
                  width: valueWidth ?? (big ? 64 : 44),
                  child: Text(value,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: big ? 30 : 20,
                          height: 1.2,
                          fontWeight: FontWeight.w700,
                          color: valueColor ?? kTextPrimary)),
                ),
              ),
              const SizedBox(width: 8),
              _SquareButton(
                  glyph: '+', onTap: onPlus, semantic: '$label — нэмэх'),
            ],
          ),
        ],
      ),
    );
  }
}

class _SquareButton extends StatelessWidget {
  const _SquareButton(
      {required this.glyph, required this.onTap, required this.semantic});

  final String glyph;
  final VoidCallback? onTap;
  final String semantic;

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
            width: kMinTouch,
            height: kMinTouch,
            child: Center(
              child: ExcludeSemantics(
                child: Text(glyph,
                    style: TextStyle(
                        fontSize: 24,
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

/// Тийм/Үгүй тохируулга: шошго, нэг мөр тайлбар, сонгогдсон мөчид үр дагавар.
/// Тайлбар нь дүрмийг хэлнэ, зөвлөгөө ХЭЗЭЭ Ч хэлэхгүй (GDD-03 §4).
class ToggleRow extends StatelessWidget {
  const ToggleRow({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.hint,
    this.consequence,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final String? hint;
  final String? consequence;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(label, style: kBody.copyWith(color: kTextPrimary)),
                    if (hint != null)
                      Text(hint!,
                          style: kLabel.copyWith(
                              color: kTextMuted,
                              letterSpacing: 0,
                              fontWeight: FontWeight.w400)),
                  ],
                ),
              ),
              const SizedBox(width: kGap),
              // Switch-ийн хүрэх талбай Material-ийн дүрмээр 48dp.
              Switch(
                value: value,
                activeTrackColor: kEmber,
                onChanged: onChanged,
              ),
            ],
          ),
          if (consequence != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(consequence!,
                  style: kLabel.copyWith(
                      color: kEmber,
                      letterSpacing: 0,
                      fontWeight: FontWeight.w400)),
            ),
        ],
      ),
    );
  }
}

/// Хэд хэдэн байрлалтай сонголт. Мөр бүр бүтэн өргөнтэй — 360px дээр
/// сегментчилсэн товч халина.
class ChoiceRow<T> extends StatelessWidget {
  const ChoiceRow({
    super.key,
    required this.label,
    required this.hint,
    required this.options,
    required this.value,
    required this.labelOf,
    required this.consequenceOf,
    required this.onChanged,
  });

  final String label;
  final String? hint;
  final List<T> options;
  final T value;
  final String Function(T) labelOf;
  final String Function(T) consequenceOf;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: kBody.copyWith(color: kTextPrimary)),
          if (hint != null)
            Text(hint!,
                style: kLabel.copyWith(
                    color: kTextMuted,
                    letterSpacing: 0,
                    fontWeight: FontWeight.w400)),
          const SizedBox(height: 6),
          for (final T o in options)
            _ChoiceTile(
              text: labelOf(o),
              consequence: consequenceOf(o),
              selected: o == value,
              onTap: () => onChanged(o),
            ),
        ],
      ),
    );
  }
}

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    required this.text,
    required this.consequence,
    required this.selected,
    required this.onTap,
  });

  final String text;
  final String consequence;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '$text. $consequence',
      child: Material(
        color: selected ? kSurfaceHigh : Colors.transparent,
        borderRadius: BorderRadius.circular(kRadius),
        child: InkWell(
          borderRadius: BorderRadius.circular(kRadius),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: kMinTouch),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            margin: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                ExcludeSemantics(
                  child: Text(selected ? '◉' : '○',
                      style: TextStyle(
                          fontSize: 16,
                          height: 1.45,
                          color: selected ? kEmber : kTextMuted)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ExcludeSemantics(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(text,
                            style: kBody.copyWith(
                                color: kTextPrimary,
                                fontWeight: selected
                                    ? FontWeight.w700
                                    : FontWeight.w400)),
                        if (selected)
                          Text(consequence,
                              style: kLabel.copyWith(
                                  color: kEmber,
                                  letterSpacing: 0,
                                  fontWeight: FontWeight.w400)),
                      ],
                    ),
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

/// Нугалаа. S21-ийн «Дэлгэрэнгүй» ба S22-ын дөрвөн мөр хоёулаа үүнийг хэрэглэнэ.
class FoldSection extends StatefulWidget {
  const FoldSection({
    super.key,
    required this.title,
    required this.children,
    this.initiallyOpen = false,
  });

  final String title;
  final List<Widget> children;
  final bool initiallyOpen;

  @override
  State<FoldSection> createState() => _FoldSectionState();
}

class _FoldSectionState extends State<FoldSection> {
  late bool _open = widget.initiallyOpen;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Semantics(
          button: true,
          expanded: _open,
          child: Material(
            color: kSurfaceRaised,
            borderRadius: BorderRadius.circular(kRadius),
            child: InkWell(
              borderRadius: BorderRadius.circular(kRadius),
              onTap: () => setState(() => _open = !_open),
              child: Container(
                constraints: const BoxConstraints(minHeight: kMinTouch + 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(widget.title,
                          style: kBody.copyWith(
                              fontWeight: FontWeight.w700,
                              color: kTextPrimary)),
                    ),
                    const SizedBox(width: kGap),
                    ExcludeSemantics(
                      child: Text(_open ? '▾' : '▸',
                          style: const TextStyle(
                              fontSize: 18, color: kTextMuted)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (_open)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: widget.children,
            ),
          ),
        const SizedBox(height: kGap),
      ],
    );
  }
}
