// «Хот унтлаа» — хөдөлгүүрийн үзүүлэн.
//
// ЭНЭ БОЛ ТОГЛООМ БИШ. Энэ бол `packages/engine` нь жинхэнэ утсан дээр
// ажиллаж байгааг нотлох хамгийн жижиг дэлгэц — хуваарилалт, шударга байдлын
// код, нэг шөнө шийдвэрлэх. Дэлгэцүүдийн жинхэнэ тодорхойлолт нь GDD-06.
//
// Өнгө, үсгийн хэмжээ: GDD-08 §7.

import 'dart:math' show Random;
import 'dart:typed_data';

import 'package:engine/engine.dart';
// Flutter-ийн `Intent` (Shortcuts/Actions-д зориулсан) нь хөдөлгүүрийн
// `Intent`-тэй мөргөлддөг. Энэ апп Flutter-ийнхийг ашигладаггүй тул нууна.
// Хөдөлгүүрийн нэр GDD-05 §2-т тогтсон тул түүнийг өөрчлөхгүй.
import 'package:flutter/material.dart' hide Intent;

void main() => runApp(const HotUntlaaDemo());

// GDD-08 §7.4 — Улаанбаатар ноар.
const Color kSurface = Color(0xFF0E1A2B);
const Color kSurfaceRaised = Color(0xFF16263C);
const Color kEmber = Color(0xFFF08A2B);
const Color kTextPrimary = Color(0xFFEAF0F7);
const Color kTextMuted = Color(0xFF9DB0C6);
const Color kDanger = Color(0xFFD55E00);
const Color kOk = Color(0xFF009E73);

class HotUntlaaDemo extends StatelessWidget {
  const HotUntlaaDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Хот унтлаа',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: kSurface,
        colorScheme: const ColorScheme.dark(
          surface: kSurface,
          primary: kEmber,
          onPrimary: kSurface,
        ),
        textTheme: const TextTheme(
          bodyMedium: TextStyle(fontSize: 16, height: 1.45, color: kTextPrimary),
        ),
      ),
      home: const DemoPage(),
    );
  }
}

class DemoPage extends StatefulWidget {
  const DemoPage({super.key});

  @override
  State<DemoPage> createState() => _DemoPageState();
}

class _DemoPageState extends State<DemoPage> {
  int _n = 12;
  DealResult? _deal;
  NightState? _state;
  NightReport? _report;
  String? _error;

  SetupCheck get _check {
    final Roster r = rosterFor(_n.clamp(kMinSeats, kMaxSeats));
    return checkSetup(
      n: r.n,
      mafia: r.mafia,
      boss: r.boss,
      doctor: r.doctor,
      detective: r.detective,
    );
  }

  /// Хуваарилалт. `seed0` нь аппын давхаргад үүснэ (GDD-10 §2, алхам 1) —
  /// хөдөлгүүр өөрөө хэзээ ч санамсаргүй тоо үүсгэхгүй.
  void _dealCards() {
    final Random rnd = Random.secure();
    final Uint8List seed0 =
        Uint8List.fromList(List<int>.generate(32, (_) => rnd.nextInt(256)));
    final Uint8List shake =
        Uint8List.fromList(List<int>.generate(4, (_) => rnd.nextInt(256)));

    final Roster roster = rosterFor(_n);
    final DealResult d = deal(
      seed0: seed0,
      userEntropy: shake,
      n: roster.n,
      deck: deckFor(roster),
      holderSeat: 1,
    );

    final Setup setup = Setup(
      n: roster.n,
      roleBySeat: d.roleBySeat,
      factionRule: roster.boss
          ? FactionRule.designatedKiller
          : FactionRule.mafiaMajority,
    );

    setState(() {
      _deal = d;
      _report = null;
      _error = null;
      _state = NightState(
        setup: setup,
        night: 1,
        alive: <Seat>{for (int i = 1; i <= roster.n; i++) i},
        seed: d.seed,
        orderPerm: d.orderPerm,
      );
    });
  }

  /// Суудал бүр өөрийн дүрийн чадвараар хамгийн эхний хууль ёсны байг сонгоно.
  /// Жинхэнэ тоглоомд үүнийг хүн товшино (GDD-06 S09).
  void _resolve() {
    final NightState s = _state!;
    final List<Intent> intents = <Intent>[];
    for (final Seat actor in s.alive.toList()..sort()) {
      final Ability ability = abilityOf(s.setup.roleOf(actor)!);
      Seat? target;
      for (int t = 1; t <= s.setup.n; t++) {
        final Intent probe = Intent(
          intentId: 'demo-n${s.night}-s$actor',
          night: s.night,
          actor: actor,
          ability: ability,
          target: t,
          clientSeq: 1,
        );
        if (validate(probe, s) == null) {
          target = t;
          break;
        }
      }
      intents.add(Intent(
        intentId: 'demo-n${s.night}-s$actor',
        night: s.night,
        actor: actor,
        ability: target == null ? Ability.noAction : ability,
        target: target,
        clientSeq: 1,
      ));
    }

    try {
      final NightReport r = resolveNight(s, intents);
      checkInvariants(s, intents, r);
      setState(() {
        _report = r;
        _error = null;
        _state = NightState(
          setup: s.setup,
          night: s.night + 1,
          alive: r.aliveAfter,
          seed: s.seed,
          orderPerm: s.orderPerm,
          lastHealTarget: r.nextLastHeal,
          selfHealUsed: r.nextSelfHealUsed,
        );
      });
    } on InvariantViolation catch (e) {
      setState(() => _error = 'Инвариант зөрчигдлөө: ${e.id} — ${e.detail}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final SetupCheck check = _check;
    final Roster roster = rosterFor(_n);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text('ХОТ УНТЛАА',
                  style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2,
                      color: kTextPrimary)),
              const SizedBox(height: 4),
              const Text('Хөдөлгүүрийн үзүүлэн — тоглоом биш',
                  style: TextStyle(fontSize: 14, color: kTextMuted)),
              const SizedBox(height: 28),

              // --- Тоглогчийн тоо -------------------------------------------
              _Label('Тоглогчийн тоо: $_n'),
              Slider(
                value: _n.toDouble(),
                min: kMinSeats.toDouble(),
                max: kMaxSeats.toDouble(),
                divisions: kMaxSeats - kMinSeats,
                activeColor: kEmber,
                label: '$_n',
                onChanged: (double v) => setState(() {
                  _n = v.round();
                  _deal = null;
                  _report = null;
                }),
              ),
              _Card(children: <Widget>[
                _Row('Мафи', '${roster.mafia}${roster.boss ? " (Ахлагчтай)" : ""}'),
                _Row('Эмч · Мөрдөгч', '${roster.doctor ? "тийм" : "үгүй"} · '
                    '${roster.detective ? "тийм" : "үгүй"}'),
                _Row('Иргэн', '${roster.citizens}'),
                const Divider(height: 24, color: Color(0x22FFFFFF)),
                _Pips(roster.b),
                const SizedBox(height: 8),
                Text(check.messageMn,
                    style: TextStyle(
                        fontSize: 14,
                        color: switch (check.verdict) {
                          SetupVerdict.green => kOk,
                          SetupVerdict.warn => kEmber,
                          SetupVerdict.reject => kDanger,
                        })),
              ]),
              const SizedBox(height: 20),

              FilledButton(
                onPressed: check.isReject ? null : _dealCards,
                style: FilledButton.styleFrom(
                    backgroundColor: kEmber,
                    foregroundColor: kSurface,
                    minimumSize: const Size.fromHeight(52)),
                child: const Text('Хөзөр тараах',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
              ),

              if (_deal != null) ...<Widget>[
                const SizedBox(height: 24),
                _Label('Шударга байдлын код'),
                const SizedBox(height: 6),
                Text(_deal!.fairCode,
                    style: const TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 4,
                        color: kEmber)),
                const SizedBox(height: 6),
                Text('${_deal!.readerSeat}-р тоглогч уншина. '
                    'Хуваарилахын ӨМНӨ цаасан дээр бич.',
                    style: const TextStyle(fontSize: 14, color: kTextMuted)),
                const SizedBox(height: 20),
                FilledButton.tonal(
                  onPressed: _state!.alive.length > 1 ? _resolve : null,
                  style: FilledButton.styleFrom(
                      backgroundColor: kSurfaceRaised,
                      foregroundColor: kTextPrimary,
                      minimumSize: const Size.fromHeight(52)),
                  child: Text('${_state!.night}-р шөнийг шийдвэрлэх',
                      style: const TextStyle(fontSize: 17)),
                ),
              ],

              if (_error != null) ...<Widget>[
                const SizedBox(height: 20),
                Text(_error!, style: const TextStyle(color: kDanger)),
              ],

              if (_report != null) ...<Widget>[
                const SizedBox(height: 24),
                _Label('Үүрийн үр дүн'),
                const SizedBox(height: 8),
                _Card(children: <Widget>[
                  for (final Cue c in _report!.cues) _CueRow(c),
                  const Divider(height: 24, color: Color(0x22FFFFFF)),
                  _Row('Амьд', '${_report!.aliveAfter.length}'),
                  _Row('Ялалт', switch (_report!.win) {
                    WinState.none => '—',
                    WinState.mafi => 'Мафи ялалаа',
                    WinState.hotynhon => 'Хотынхон ялалаа',
                  }),
                  _Row('resultHash', _report!.resultHash.substring(0, 16)),
                ]),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          fontSize: 13,
          letterSpacing: 1.2,
          fontWeight: FontWeight.w600,
          color: kTextMuted));
}

class _Card extends StatelessWidget {
  const _Card({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: kSurfaceRaised, borderRadius: BorderRadius.circular(12)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
      );
}

class _Row extends StatelessWidget {
  const _Row(this.k, this.v);
  final String k;
  final String v;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Хамгийн нарийн зорилтот төхөөрөмж 360 логик px (GDD-13 D1).
            // Хоёр талыг уян хатан болгосон — эс бөгөөс урт утга мөрийг халина.
            Expanded(
              flex: 5,
              child: Text(k,
                  style: const TextStyle(fontSize: 15, color: kTextMuted)),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 6,
              child: Text(v,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: kTextPrimary)),
            ),
          ],
        ),
      );
}

/// «Алдаж болох санал» (GDD-04). Дүрийг ХЭЗЭЭ Ч уншихгүй — зөвхөн n, m, өдөр.
class _Pips extends StatelessWidget {
  const _Pips(this.b);
  final int b;
  @override
  Widget build(BuildContext context) {
    final Color c = b >= 2 ? kOk : (b == 1 ? kEmber : kDanger);
    return Row(
      children: <Widget>[
        const Expanded(
          child: Text('Алдаж болох санал',
              style: TextStyle(fontSize: 15, color: kTextMuted)),
        ),
        const SizedBox(width: 12),
        if (b <= 0)
          Text(b == 0 ? 'ӨНӨӨДӨР ОНОХ ЁСТОЙ' : 'боломжгүй',
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w700, color: c))
        else
          Text('●' * b, style: TextStyle(fontSize: 18, color: c)),
      ],
    );
  }
}

class _CueRow extends StatelessWidget {
  const _CueRow(this.cue);
  final Cue cue;
  @override
  Widget build(BuildContext context) {
    final (String label, String value) = switch (cue) {
      CueLine(clipId: final String id) => ('клип', id),
      CueSilence(ms: final int ms) => ('чимээгүй', '$ms мс'),
      CueScreenSeats(seats: final List<Seat> s) => ('дэлгэц', s.join(' · ')),
    };
    return _Row(label, value);
  }
}
