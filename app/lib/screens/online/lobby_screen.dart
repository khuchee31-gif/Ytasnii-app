// Хүлээлгийн өрөө — хүмүүс орж ирж, ширээ тойрон суух хэсэг.
//
// Энэ бол тоглогчийн хардаг ХАМГИЙН АНХНЫ 3D дэлгэц. Тиймээс энд тоглоомын
// амлалт бүхэлдээ багтана: харанхуй өрөө, ганц чийдэн, ширээ, бас хүн орох
// бүрд НЭГ СУУДАЛ ДҮҮРНЭ.
//
// Хоёр зүйлийг зориуд хийсэн:
//   • Хоосон суудал ч ХАРАГДАНА — «бид хэдэн хүн хүлээж байна» гэдэг
//     тоогоор биш, ЗУРГААР ойлгогдоно.
//   • Өрөөний код ТОМ. Ангид чангаар хэлэхэд нэг л удаа уншина.

import 'package:flutter/material.dart' hide Intent;
import 'package:protocol/protocol.dart';

import '../../net/client.dart';
import '../../ui/avatars.dart';
import '../../ui/glyphs.dart';
import '../../ui/table_scene.dart';
import '../../ui/tokens.dart';

class LobbyScreen extends StatefulWidget {
  const LobbyScreen({super.key, required this.client, this.onLeave});

  final GameClient client;
  final VoidCallback? onLeave;

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  bool _ready = false;

  GameClient get c => widget.client;

  @override
  void initState() {
    super.initState();
    c.addListener(_onChange);
    _preload();
  }

  @override
  void dispose() {
    c.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
    _preload();
  }

  /// Шинэ хүн орох бүрд түүний дүрийг ачаална.
  void _preload() {
    final Set<String> ids = c.players
        .map((PublicPlayer p) => p.avatarId)
        .toSet();
    if (ids.isEmpty) return;
    AvatarCache.instance.preload(ids).then((_) {
      if (mounted) setState(() {});
    });
  }

  /// Ширээн дээрх суудлууд. Хүн байхгүй суудал ХООСОН гэж зурагдана.
  List<SeatOccupant> get _occupants {
    final List<PublicPlayer> ps = c.players;
    return <SeatOccupant>[
      for (int i = 0; i < ps.length; i++)
        SeatOccupant(
          // Хүлээлгийн өрөөнд суудал хараахан хуваарилагдаагүй тул орсон
          // дарааллаар нь тавина.
          seat: ps[i].seat ?? (i + 1),
          portrait: AvatarCache.instance.peek(ps[i].avatarId),
          name: ps[i].name,
          alive: ps[i].connected,
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final int have = c.players.length;
    const int need = 6;
    final bool enough = have >= need;
    final int mySeatGuess =
        c.me?.seat ??
        (c.players.indexWhere((PublicPlayer p) => p.id == c.playerId) + 1);

    return Scaffold(
      backgroundColor: kNight,
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          // --- Тайз ------------------------------------------------------
          if (have >= 2)
            TableView(
              occupants: _occupants,
              viewerSeat: mySeatGuess < 1 ? 1 : mySeatGuess,
              // Хүн цөөн байхад ч ширээ БҮТЭН харагдана — суудал нь
              // хоосон гэдэг нь ойлгогдоно.
              seatCount: have < need ? need : have,
              lamp: 0.85,
            )
          else
            const _EmptyRoom(),

          // --- Дээд зах: өрөөний код -------------------------------------
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _CodeBar(
                  code: c.roomCode,
                  link: c.link,
                  onLeave: widget.onLeave,
                ),
                const Spacer(),
                _Footer(
                  have: have,
                  need: need,
                  enough: enough,
                  isHost: c.isHost,
                  ready: _ready,
                  onReady: () {
                    setState(() => _ready = !_ready);
                    c.setReady(_ready);
                  },
                  onStart: c.startGame,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Хүн хараахан ороогүй — ганцаардмал өрөө.
class _EmptyRoom extends StatelessWidget {
  const _EmptyRoom();

  @override
  Widget build(BuildContext context) => const ColoredBox(
    color: kNight,
    child: Center(
      child: Text(
        'Хэн ч ороогүй байна.',
        style: TextStyle(
          fontFamily: kBodyFont,
          fontSize: 16,
          color: kTextMuted,
        ),
      ),
    ),
  );
}

class _CodeBar extends StatelessWidget {
  const _CodeBar({required this.code, required this.link, this.onLeave});

  final String? code;
  final LinkState link;
  final VoidCallback? onLeave;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(kGutter, 10, kGutter, 0),
      child: Row(
        children: <Widget>[
          if (onLeave != null)
            MarkButton(
              shape: MarkShape.arrowRight,
              semantic: 'Гарах',
              color: kTextMuted,
              onTap: onLeave,
            ),
          Expanded(
            child: Column(
              children: <Widget>[
                Text(
                  'ӨРӨӨНИЙ КОД',
                  style: kLabel.copyWith(color: kTextMuted, fontSize: 11),
                ),
                const SizedBox(height: 2),
                Text(
                  code ?? '····',
                  style: kDisplay.copyWith(
                    fontSize: 40,
                    letterSpacing: 10,
                    color: kBone,
                  ),
                ),
              ],
            ),
          ),
          // Холболтын байдал — жижиг цэг. Тасарвал улаан.
          Mark(
            MarkShape.discFilled,
            size: 10,
            color: switch (link) {
              LinkState.connected => kOk,
              LinkState.connecting || LinkState.reconnecting => kEmber,
              LinkState.failed || LinkState.idle => kDanger,
            },
          ),
          const SizedBox(width: kMinTouch - 10),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({
    required this.have,
    required this.need,
    required this.enough,
    required this.isHost,
    required this.ready,
    required this.onReady,
    required this.onStart,
  });

  final int have;
  final int need;
  final bool enough;
  final bool isHost;
  final bool ready;
  final VoidCallback onReady;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(kGutter, 14, kGutter, 18),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0x00000000), Color(0xCC000000)],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            enough
                ? '$have хүн — эхлэхэд бэлэн'
                : 'Дахиад ${need - have} хүн хэрэгтэй  ($have / $need)',
            textAlign: TextAlign.center,
            style: kBody.copyWith(
              color: enough ? kBone : kTextMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          if (isHost)
            FilledButton(
              onPressed: enough ? onStart : null,
              child: const Text('Тараая'),
            )
          else
            OutlinedButton(
              onPressed: onReady,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(kPrimaryButtonHeight),
                side: BorderSide(color: ready ? kOk : kHairline),
                foregroundColor: ready ? kOk : kTextPrimary,
                shape: const RoundedRectangleBorder(),
              ),
              child: Text(ready ? 'Бэлэн ✓' : 'Би бэлэн'),
            ),
        ],
      ),
    );
  }
}
