// Хуваалцсан жижиг хэсгүүд — GDD-06-ийн бүх дэлгэц эдгээрийг ашиглана.
//
// ГАР УТАСНЫ ДҮРЭМ: үндсэн үйлдэл ҮРГЭЛЖ доод талд. `PhoneScaffold` нь
// агуулгыг гүйлгэж, үйлдлийг доор бэхэлнэ — 360px өргөн, жижиг дэлгэц дээр
// товч хэзээ ч нугалаанаас доош унахгүй.

import 'package:flutter/material.dart';

import 'tokens.dart';
import 'glyphs.dart';

/// Бүх дэлгэцийн суурь. Агуулга дээр, үйлдэл доор.
class PhoneScaffold extends StatelessWidget {
  const PhoneScaffold({
    super.key,
    this.title,
    this.subtitle,
    required this.body,
    this.action,
    this.background = kSurface,
    this.padded = true,
  });

  final String? title;
  final String? subtitle;
  final Widget body;

  /// Доод талд бэхлэгдэх үндсэн үйлдэл. Эрхий хуруунд хүрэхээр.
  final Widget? action;
  final Color background;
  final bool padded;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (title != null || subtitle != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(kGutter, 20, kGutter, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    if (title != null)
                      Text(title!, style: kTitle.copyWith(color: kTextPrimary)),
                    if (subtitle != null) ...<Widget>[
                      const SizedBox(height: 4),
                      Text(subtitle!, style: kBody.copyWith(color: kTextMuted)),
                    ],
                  ],
                ),
              ),
            Expanded(
              child: SingleChildScrollView(
                padding: padded
                    ? const EdgeInsets.fromLTRB(kGutter, 20, kGutter, 20)
                    : EdgeInsets.zero,
                child: body,
              ),
            ),
            if (action != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(kGutter, 8, kGutter, 20),
                child: action,
              ),
          ],
        ),
      ),
    );
  }
}

/// Мэдээллийн хайрцаг. Хоёр тал уян хатан — 360px дээр мөр халихгүй.
class InfoCard extends StatelessWidget {
  const InfoCard({super.key, required this.children, this.color});
  final List<Widget> children;
  final Color? color;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: color ?? kSurfaceRaised,
      borderRadius: BorderRadius.circular(kRadius),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    ),
  );
}

class InfoRow extends StatelessWidget {
  const InfoRow(this.label, this.value, {super.key, this.valueColor});
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          flex: 5,
          child: Text(label, style: kBody.copyWith(color: kTextMuted)),
        ),
        const SizedBox(width: kGap),
        Expanded(
          flex: 6,
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: kBody.copyWith(
              fontWeight: FontWeight.w600,
              color: valueColor ?? kTextPrimary,
            ),
          ),
        ),
      ],
    ),
  );
}

/// «Алдаж болох санал» (GDD-04 §3, GDD-05 §9.4).
/// Дүрийг ХЭЗЭЭ Ч уншихгүй — зөвхөн үлдсэн тоо.
class PipStrip extends StatelessWidget {
  const PipStrip(this.pips, {super.key});
  final int pips;

  @override
  Widget build(BuildContext context) {
    final Color c = pips >= 2 ? kOk : (pips == 1 ? kEmber : kDanger);
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            'Алдаж болох санал',
            style: kBody.copyWith(color: kTextMuted),
          ),
        ),
        const SizedBox(width: kGap),
        if (pips <= 0)
          Flexible(
            child: Text(
              pips == 0 ? 'ӨНӨӨДӨР ОНОХ ЁСТОЙ' : 'боломжгүй',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: c,
              ),
            ),
          )
        else
          MarkPips(count: pips, color: c, size: 13, gap: 7),
      ],
    );
  }
}

/// Суудал сонгох тор. Хүрэх талбай хэзээ ч 48dp-ээс бага биш.
class SeatGrid extends StatelessWidget {
  const SeatGrid({
    super.key,
    required this.seats,
    required this.onTap,
    this.enabled,
    this.selected,
    this.badge,
  });

  final List<int> seats;
  final ValueChanged<int> onTap;

  /// Хууль бус бай — саарал, дарагдахгүй. Шалтгааныг дэлгэц өөрөө бичнэ.
  final bool Function(int seat)? enabled;
  final bool Function(int seat)? selected;
  final String? Function(int seat)? badge;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints c) {
        // 360px дээр 3 багана, өргөн дэлгэц дээр 4-5.
        final int cols = (c.maxWidth / 110).floor().clamp(3, 5);
        return GridView.count(
          crossAxisCount: cols,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: kGap,
          crossAxisSpacing: kGap,
          childAspectRatio: 1.0,
          children: <Widget>[
            for (final int s in seats)
              _SeatTile(
                seat: s,
                enabled: enabled?.call(s) ?? true,
                selected: selected?.call(s) ?? false,
                badge: badge?.call(s),
                onTap: () => onTap(s),
              ),
          ],
        );
      },
    );
  }
}

class _SeatTile extends StatelessWidget {
  const _SeatTile({
    required this.seat,
    required this.enabled,
    required this.selected,
    required this.badge,
    required this.onTap,
  });

  final int seat;
  final bool enabled;
  final bool selected;
  final String? badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: enabled,
      label: '$seat-р тоглогч',
      child: Material(
        color: selected
            ? kEmber
            : (enabled
                  ? kSurfaceRaised
                  : kSurfaceRaised.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(kRadius),
        child: InkWell(
          borderRadius: BorderRadius.circular(kRadius),
          onTap: enabled ? onTap : null,
          child: Container(
            constraints: const BoxConstraints(
              minWidth: kMinTouch,
              minHeight: kMinTouch,
            ),
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(
                  '$seat',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    color: selected
                        ? kSurface
                        : (enabled ? kTextPrimary : kTextMuted),
                  ),
                ),
                if (badge != null)
                  Text(
                    badge!,
                    style: TextStyle(
                      fontSize: 12,
                      color: selected ? kSurface : kTextMuted,
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

/// Том тоолуур — ширээний нөгөө талаас уншигдана.
class BigCountdown extends StatelessWidget {
  const BigCountdown(this.seconds, {super.key, this.warnAt = 10});
  final int seconds;
  final int warnAt;

  @override
  Widget build(BuildContext context) {
    final bool warn = seconds <= warnAt;
    return Text(
      '$seconds',
      style: TextStyle(
        fontSize: 88,
        fontWeight: FontWeight.w700,
        height: 1.0,
        color: warn ? kEmber : kTextPrimary,
      ),
    );
  }
}
