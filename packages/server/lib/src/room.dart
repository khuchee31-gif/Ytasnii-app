// Нэг тоглоомын өрөө — ЦЭВЭР ЛОГИК.
//
// `dart:io` БАЙХГҮЙ, сокет БАЙХГҮЙ, `DateTime.now()` БАЙХГҮЙ. Команд орж,
// хаяглагдсан мессеж гарна. Ингэснээр бүтэн тоглолтыг сүлжээгүйгээр,
// секундын дотор, давтагдахаар тестлэнэ.
//
// ДҮР ЭНД АМЬДАРНА. Утас руу хэзээ ч бүтнээр нь явахгүй:
//   • `Outbound.all(...)` — нийтийнх. Дүрийн ул мөр байж БОЛОХГҮЙ.
//   • `Outbound.one(...)` — хувийнх. Дүр зөвхөн ингэж явна.
// `test/room_test.dart` бүтэн тоглолт явуулж, нийтийн БҮХ мессежийг
// шалгаад дүр алдагдсан эсэхийг барина.

import 'dart:typed_data';

import 'package:engine/engine.dart' as eng;
import 'package:protocol/protocol.dart';

import 'outbound.dart';

/// Үе шат бүр хэдэн миллисекунд үргэлжлэх вэ.
///
/// Эдгээрийг СЕРВЕР эзэмшинэ. Утас өөрөө тоолвол цагаа хойшлуулсан хүн
/// илүү удаан бодох боломжтой болно.
abstract final class PhaseMs {
  static const int dealing = 6000;
  static const int nightFalls = 3000;
  static const int mafia = 30000;
  static const int doctor = 15000;
  static const int detective = 15000;
  static const int dawn = 6000;
  static const int day = 120000;
  static const int vote = 30000;
  static const int elimination = 5000;
}

const int kMinPlayers = 6;
const int kMaxPlayers = 14;

/// Тоглогчийн НУУЦ хэсэг. Энэ ангийн утга сүлжээнд ХЭЗЭЭ Ч бүтнээрээ гарахгүй.
class _Secret {
  _Secret(this.seat, this.role);
  final int seat;
  final eng.Role role;
}

/// Нэг өрөө.
class GameRoom {
  GameRoom({
    required this.code,
    required this.hostId,
    required Uint8List seed,
    this.isPublic = true,
  }) : _seed = seed;

  final String code;
  final bool isPublic;

  /// Өрөөг үүсгэсэн хүн. Гарвал дараагийн хүнд шилжинэ.
  PlayerId hostId;

  final Uint8List _seed;

  final Map<PlayerId, PublicPlayer> _players = <PlayerId, PublicPlayer>{};

  /// НУУЦ. Тоглолт эхэлмэгц дүүрнэ.
  final Map<PlayerId, _Secret> _secrets = <PlayerId, _Secret>{};
  final Map<int, PlayerId> _bySeat = <int, PlayerId>{};

  NetPhase _phase = NetPhase.lobby;
  int _phaseEndsAtMs = 0;

  eng.Setup? _setup;
  eng.NightState? _night;
  int _nightNo = 0;
  final List<eng.Intent> _intents = <eng.Intent>[];
  int _seq = 0;

  /// Өдрийн санал хураалт: хэн хэн рүү.
  final Map<PlayerId, int> _votes = <PlayerId, int>{};

  eng.WinState _win = eng.WinState.none;

  // --- Уншигчид ------------------------------------------------------------

  NetPhase get phase => _phase;
  int get playerCount => _players.length;
  bool get inLobby => _phase == NetPhase.lobby;
  eng.WinState get win => _win;
  List<PublicPlayer> get players => _players.values.toList(growable: false);

  /// Тестэд л хэрэгтэй — жинхэнэ урсгалд дүрийг ХЭЗЭЭ Ч ингэж уншихгүй.
  eng.Role? debugRoleOf(PlayerId id) => _secrets[id]?.role;

  Set<PlayerId> get _mafiaIds => _secrets.entries
      .where((MapEntry<PlayerId, _Secret> e) =>
          eng.factionOf(e.value.role) == eng.Faction.mafi &&
          (_players[e.key]?.alive ?? false))
      .map((MapEntry<PlayerId, _Secret> e) => e.key)
      .toSet();

  // --- Тухайн үе шатны дууны суваг -----------------------------------------

  /// СЕРВЕР шийднэ. Апп-д итгэвэл өөрчилсөн апп бүхнийг сонсоно.
  VoiceScope get voiceScope => switch (_phase) {
        NetPhase.day || NetPhase.vote => VoiceScope.everyone,
        NetPhase.nightMafia => VoiceScope.mafiaOnly,
        NetPhase.nightDoctor || NetPhase.nightDetective => VoiceScope.selfOnly,
        _ => VoiceScope.none,
      };

  /// Тухайн үе шатанд бие биенээ СОНСОХ ЁСТОЙ хүмүүс.
  ///
  /// Дууны серверт яг үүнийг дамжуулна. Жагсаалтад байхгүй хүнд дуу
  /// хүрэхгүй — чагнах ч боломжгүй.
  Set<PlayerId> get voiceMembers => switch (voiceScope) {
        VoiceScope.everyone => _players.values
            .where((PublicPlayer p) => p.alive)
            .map((PublicPlayer p) => p.id)
            .toSet(),
        VoiceScope.mafiaOnly => _mafiaIds,
        VoiceScope.selfOnly || VoiceScope.none => const <PlayerId>{},
      };

  // --- Командууд -----------------------------------------------------------

  List<Outbound> join(PlayerId id, String name, String avatarId) {
    if (_players.containsKey(id)) {
      // Дахин холбогдов — суудал, дүр нь хэвээр.
      _players[id] = _players[id]!.copyWith(connected: true);
      return <Outbound>[..._stateForAll(), ..._privateResend(id)];
    }
    if (_phase != NetPhase.lobby) {
      return <Outbound>[_err(id, ErrCode.gameInProgress)];
    }
    if (_players.length >= kMaxPlayers) {
      return <Outbound>[_err(id, ErrCode.roomFull)];
    }
    final String clean = _sanitizeName(name);
    if (_players.values.any((PublicPlayer p) => p.name == clean)) {
      return <Outbound>[_err(id, ErrCode.nameTaken)];
    }
    _players[id] = PublicPlayer(id: id, name: clean, avatarId: avatarId);
    return _stateForAll();
  }

  List<Outbound> leave(PlayerId id) {
    if (!_players.containsKey(id)) return const <Outbound>[];
    if (_phase == NetPhase.lobby) {
      _players.remove(id);
      _secrets.remove(id);
    } else {
      // Тоглолт явж байхад суудал нь үлдэнэ — эргэж орж болно.
      _players[id] = _players[id]!.copyWith(connected: false);
    }
    if (id == hostId && _players.isNotEmpty) hostId = _players.keys.first;
    return _stateForAll();
  }

  List<Outbound> setReady(PlayerId id, bool ready) {
    final PublicPlayer? p = _players[id];
    if (p == null || _phase != NetPhase.lobby) return const <Outbound>[];
    _players[id] = p.copyWith(ready: ready);
    return _stateForAll();
  }

  List<Outbound> start(PlayerId id, int nowMs) {
    if (id != hostId) return <Outbound>[_err(id, ErrCode.notHost)];
    if (_phase != NetPhase.lobby) {
      return <Outbound>[_err(id, ErrCode.gameInProgress)];
    }
    if (_players.length < kMinPlayers) {
      return <Outbound>[_err(id, ErrCode.tooFewPlayers)];
    }
    return _deal(nowMs);
  }

  /// Шөнийн үйлдэл. Аль үе шат мөн бол тухайн дүр л илгээж чадна.
  List<Outbound> nightAction(PlayerId id, int targetSeat, int nowMs) {
    final _Secret? me = _secrets[id];
    final PublicPlayer? p = _players[id];
    if (me == null || p == null || !p.alive) {
      return <Outbound>[_err(id, ErrCode.notYourTurn)];
    }
    if (!_mayActNow(me.role)) {
      return <Outbound>[_err(id, ErrCode.notYourTurn)];
    }
    final eng.NightState? s = _night;
    if (s == null) return <Outbound>[_err(id, ErrCode.notYourTurn)];

    final eng.Ability ability = eng.abilityOf(me.role);
    final eng.Intent intent = eng.Intent(
      intentId: '${code}_${_nightNo}_${me.seat}_${_seq++}',
      night: _nightNo,
      actor: me.seat,
      ability: ability,
      target: targetSeat,
      clientSeq: _seq,
      submittedAtMs: nowMs,
    );
    // Хөдөлгүүрээр шалгуулна — сервер өөрөө дүрэм зохиохгүй.
    if (eng.validate(intent, s) != null) {
      return <Outbound>[_err(id, ErrCode.invalidTarget)];
    }
    _intents
      ..removeWhere((eng.Intent i) =>
          i.actor == me.seat && i.ability == ability && i.night == _nightNo)
      ..add(intent);

    // Мафи хоорондоо сонголтоо ХАРНА — хамтдаа шийдэх нь тэдний давуу тал.
    if (ability == eng.Ability.mafiaKill) {
      return <Outbound>[
        Outbound.to(
          _mafiaIds,
          Envelope('mafiaPick', <String, Object?>{
            'bySeat': me.seat,
            'targetSeat': targetSeat,
          }),
        ),
      ];
    }
    return <Outbound>[_ack(id)];
  }

  List<Outbound> vote(PlayerId id, int? targetSeat) {
    final PublicPlayer? p = _players[id];
    if (p == null || !p.alive || _phase != NetPhase.vote) {
      return <Outbound>[_err(id, ErrCode.notYourTurn)];
    }
    if (targetSeat == null) {
      _votes.remove(id);
    } else {
      final PlayerId? target = _bySeat[targetSeat];
      if (target == null || !(_players[target]?.alive ?? false)) {
        return <Outbound>[_err(id, ErrCode.invalidTarget)];
      }
      _votes[id] = targetSeat;
    }
    return <Outbound>[_voteState()];
  }

  /// Цаг хэмжигч. Сервер үүнийг тогтмол дуудна.
  List<Outbound> tick(int nowMs) {
    if (_phase == NetPhase.lobby || _phase == NetPhase.gameOver) {
      return const <Outbound>[];
    }
    if (nowMs < _phaseEndsAtMs) return const <Outbound>[];
    return _advance(nowMs);
  }

  // --- Дотоод урсгал -------------------------------------------------------

  bool _mayActNow(eng.Role r) => switch (_phase) {
        NetPhase.nightMafia => eng.factionOf(r) == eng.Faction.mafi,
        NetPhase.nightDoctor => r == eng.Role.doctor,
        NetPhase.nightDetective => r == eng.Role.detective,
        _ => false,
      };

  List<Outbound> _deal(int nowMs) {
    final int n = _players.length;
    final eng.Roster roster = eng.rosterFor(n);
    final List<eng.Role> deck = eng.deckFor(roster);

    final eng.DealResult d = eng.deal(
      seed0: _seed,
      userEntropy: Uint8List.fromList(code.codeUnits),
      n: n,
      deck: deck,
      holderSeat: 1,
    );

    // Суудлыг тогтмол дарааллаар өгнө — орсон дараалал.
    final List<PlayerId> ids = _players.keys.toList();
    for (int i = 0; i < ids.length; i++) {
      final int seat = i + 1;
      final eng.Role role = d.roleBySeat[seat]!;
      _secrets[ids[i]] = _Secret(seat, role);
      _bySeat[seat] = ids[i];
      _players[ids[i]] = _players[ids[i]]!.copyWith(seat: seat, alive: true);
    }

    _setup = eng.Setup(n: n, roleBySeat: d.roleBySeat);
    _nightNo = 0;
    _win = eng.WinState.none;

    final List<Outbound> out = <Outbound>[];
    _enter(NetPhase.dealing, nowMs, PhaseMs.dealing, out);

    // ДҮРИЙГ ЗӨВХӨН ЭЗЭНД НЬ. Мафид хамтрагчдынх нь суудлыг ч өгнө.
    for (final MapEntry<PlayerId, _Secret> e in _secrets.entries) {
      final bool isMafia = eng.factionOf(e.value.role) == eng.Faction.mafi;
      out.add(Outbound.one(
        e.key,
        Envelope(S2C.yourRole, <String, Object?>{
          'seat': e.value.seat,
          'role': e.value.role.name,
          'faction': isMafia ? 'mafi' : 'hotynhon',
          if (isMafia)
            'allySeats': _secrets.values
                .where((_Secret s) =>
                    eng.factionOf(s.role) == eng.Faction.mafi &&
                    s.seat != e.value.seat)
                .map((_Secret s) => s.seat)
                .toList()
              ..sort(),
        }),
      ));
    }
    return out;
  }

  List<Outbound> _advance(int nowMs) {
    final List<Outbound> out = <Outbound>[];
    switch (_phase) {
      case NetPhase.dealing:
        _beginNight(nowMs, out);

      case NetPhase.nightFalls:
        _enter(NetPhase.nightMafia, nowMs, PhaseMs.mafia, out);

      case NetPhase.nightMafia:
        _enter(NetPhase.nightDoctor, nowMs, PhaseMs.doctor, out);

      case NetPhase.nightDoctor:
        _enter(NetPhase.nightDetective, nowMs, PhaseMs.detective, out);

      case NetPhase.nightDetective:
        _resolveNight(nowMs, out);

      case NetPhase.dawn:
        if (_win != eng.WinState.none) {
          _finish(nowMs, out);
        } else {
          _enter(NetPhase.day, nowMs, PhaseMs.day, out);
        }

      case NetPhase.day:
        _votes.clear();
        _enter(NetPhase.vote, nowMs, PhaseMs.vote, out);

      case NetPhase.vote:
        _tallyAndEliminate(nowMs, out);

      case NetPhase.elimination:
        if (_win != eng.WinState.none) {
          _finish(nowMs, out);
        } else {
          _beginNight(nowMs, out);
        }

      case NetPhase.lobby:
      case NetPhase.gameOver:
        break;
    }
    return out;
  }

  void _beginNight(int nowMs, List<Outbound> out) {
    _nightNo++;
    _intents.clear();
    _night = eng.NightState(
      setup: _setup!,
      night: _nightNo,
      alive: _players.values
          .where((PublicPlayer p) => p.alive)
          .map((PublicPlayer p) => p.seat!)
          .toSet(),
      seed: _seed,
      orderPerm: List<int>.generate(_setup!.n, (int i) => i + 1),
    );
    _enter(NetPhase.nightFalls, nowMs, PhaseMs.nightFalls, out);
  }

  /// Хөдөлгүүрийн N22 инвариант: АМЬД СУУДАЛ БҮР яг нэг санаа илгээнэ.
  ///
  /// Энэ нь нэг утасны хувилбарын «жигд хуурмаг» — суудал бүр утсыг ижил
  /// хугацаанд барьдаг тул хэн ч цагаар нь дүрийг таахгүй. Онлайнд иргэд
  /// шөнө үйлддэггүй, эмч, мөрдөгч ч заримдаа сонголт хийхгүй өнгөрдөг.
  /// Тиймээс дутуу санааг СЕРВЕР `noAction`-оор нөхнө — эс бөгөөс хөдөлгүүр
  /// зогсоно.
  void _fillMissingIntents() {
    final eng.NightState s = _night!;
    for (final int seat in s.alive) {
      final bool acted = _intents.any((eng.Intent i) => i.actor == seat);
      if (acted) continue;
      _intents.add(eng.Intent(
        intentId: '${code}_${_nightNo}_${seat}_auto',
        night: _nightNo,
        actor: seat,
        ability: eng.Ability.noAction,
        target: null,
        clientSeq: 0,
        submittedAtMs: 0,
      ));
    }
  }

  void _resolveNight(int nowMs, List<Outbound> out) {
    _fillMissingIntents();
    final eng.NightReport r = eng.resolveNight(_night!, _intents);

    for (final eng.Death d in r.deaths) {
      final PlayerId? victim = _bySeat[d.victim];
      if (victim != null) {
        _players[victim] = _players[victim]!.copyWith(alive: false);
      }
    }
    _win = r.win;

    // Мөрдөгчийн хариу — ЗӨВХӨН ТҮҮНД. Хөдөлгүүр өөрөө хаяглачихсан.
    for (final MapEntry<int, List<eng.Msg>> e in r.privateMsgs.entries) {
      final PlayerId? who = _bySeat[e.key];
      if (who == null) continue;
      for (final eng.Msg m in e.value) {
        out.add(Outbound.one(
          who,
          Envelope(S2C.investigateResult, <String, Object?>{
            'code': m.code.name,
            'params': m.params,
          }),
        ));
      }
    }

    out.add(Outbound.all(Envelope(S2C.nightResult, <String, Object?>{
      'night': _nightNo,
      'deaths': r.deaths.map((eng.Death d) => d.victim).toList(),
      'whisper': r.whisper,
    })));
    _enter(NetPhase.dawn, nowMs, PhaseMs.dawn, out);
  }

  void _tallyAndEliminate(int nowMs, List<Outbound> out) {
    final Map<int, int> tally = <int, int>{};
    for (final int seat in _votes.values) {
      tally[seat] = (tally[seat] ?? 0) + 1;
    }
    int? outSeat;
    if (tally.isNotEmpty) {
      final int top = tally.values.reduce((int a, int b) => a > b ? a : b);
      final List<int> tied = tally.entries
          .where((MapEntry<int, int> e) => e.value == top)
          .map((MapEntry<int, int> e) => e.key)
          .toList();
      // Тэнцвэл ХЭН Ч ХӨӨГДӨХГҮЙ. Санамсаргүй сонголт хийхгүй —
      // «апп шийдчихлээ» гэсэн мэдрэмж тоглоомыг үхүүлнэ.
      if (tied.length == 1) outSeat = tied.first;
    }

    if (outSeat != null) {
      final PlayerId? id = _bySeat[outSeat];
      if (id != null) _players[id] = _players[id]!.copyWith(alive: false);
    }
    _recomputeWin();

    out.add(Outbound.all(Envelope('eliminated', <String, Object?>{
      'seat': outSeat,
      'tally': tally.map((int k, int v) => MapEntry<String, int>('$k', v)),
    })));
    _enter(NetPhase.elimination, nowMs, PhaseMs.elimination, out);
  }

  /// Өдрийн хасалтын дараа ялалт шалгах.
  ///
  /// Хөдөлгүүрийн `resolveNight` нь ШӨНИЙН дараа шалгадаг. Өдрийн хасалт
  /// нь түүний гадна болдог тул ижил дүрмийг энд хэрэглэнэ.
  void _recomputeWin() {
    int mafi = 0;
    int town = 0;
    for (final MapEntry<PlayerId, _Secret> e in _secrets.entries) {
      if (!(_players[e.key]?.alive ?? false)) continue;
      if (eng.factionOf(e.value.role) == eng.Faction.mafi) {
        mafi++;
      } else {
        town++;
      }
    }
    if (mafi == 0) {
      _win = eng.WinState.hotynhon;
    } else if (mafi >= town) {
      _win = eng.WinState.mafi;
    }
  }

  void _finish(int nowMs, List<Outbound> out) {
    _phase = NetPhase.gameOver;
    _phaseEndsAtMs = nowMs;
    // ЭНД Л бүх дүр ил болно — тоглолт дууссаны дараа.
    out.add(Outbound.all(Envelope(S2C.gameOver, <String, Object?>{
      'winner': _win.name,
      'reveal': _secrets.map((PlayerId k, _Secret v) =>
          MapEntry<String, Object?>('${v.seat}', v.role.name)),
    })));
  }

  void _enter(NetPhase p, int nowMs, int ms, List<Outbound> out) {
    _phase = p;
    _phaseEndsAtMs = nowMs + ms;
    out
      ..add(Outbound.all(Envelope(S2C.phase, <String, Object?>{
        'phase': p.name,
        'endsInMs': ms,
      })))
      ..addAll(_stateForAll())
      ..addAll(_voiceGrants());
  }

  /// Дууны эрхийг ХҮН БҮРД ТУСАД НЬ илгээнэ.
  ///
  /// ЯАГААД НИЙТЭД БИШ: өмнө нь үе шатын нийтийн мессежид `voice: mafiaOnly`
  /// гэж явж байв. Тэр нь хэн мафи болохыг хэлэхгүй ч иргэнд хэрэггүй
  /// мэдээлэл — түүнд зөвхөн «чи одоо ярьж чадахгүй» гэж хэлэх ёстой.
  /// Хувиар илгээснээр аппад «бусад хэн ярьж байна» гэсэн мэдээлэл огт
  /// хүрэхгүй, өөрчилсөн апп ч гэсэн олох юмгүй болно.
  List<Outbound> _voiceGrants() {
    final Set<PlayerId> members = voiceMembers;
    return _players.values.map((PublicPlayer p) {
      final bool can = members.contains(p.id);
      return Outbound.one(
        p.id,
        Envelope(S2C.voiceGrant, <String, Object?>{
          // Ярьж чадах уу — микрофон нээх эсэх.
          'canSpeak': can,
          // Хэдэн хүнтэй нэг сувагт байна. Нэрсийг илгээхгүй: мафи хэн
          // болохыг тоогоор ч гэсэн таахгүй байхын тулд зөвхөн өөрийн
          // сувгийнхаа хэмжээг мэднэ.
          'channelSize': can ? members.length : 0,
        }),
      );
    }).toList();
  }

  // --- Мессеж бүтээгчид ----------------------------------------------------

  List<Outbound> _stateForAll() => <Outbound>[
        Outbound.all(Envelope(S2C.roomState, <String, Object?>{
          'code': code,
          'phase': _phase.name,
          'hostId': hostId,
          'isPublic': isPublic,
          'players':
              _players.values.map((PublicPlayer p) => p.toJson()).toList(),
        })),
      ];

  /// Дахин холбогдсон хүнд ХУВИЙН мэдээллийг нь эргүүлж өгнө.
  List<Outbound> _privateResend(PlayerId id) {
    final _Secret? s = _secrets[id];
    if (s == null) return const <Outbound>[];
    final bool isMafia = eng.factionOf(s.role) == eng.Faction.mafi;
    return <Outbound>[
      Outbound.one(
        id,
        Envelope(S2C.yourRole, <String, Object?>{
          'seat': s.seat,
          'role': s.role.name,
          'faction': isMafia ? 'mafi' : 'hotynhon',
        }),
      ),
    ];
  }

  Outbound _voteState() => Outbound.all(
        Envelope(S2C.voteState, <String, Object?>{
          'votes': _votes.map((PlayerId k, int v) =>
              MapEntry<String, Object?>(_secrets[k]?.seat.toString() ?? k, v)),
        }),
      );

  Outbound _err(PlayerId id, String code) =>
      Outbound.one(id, Envelope(S2C.error, <String, Object?>{'code': code}));

  Outbound _ack(PlayerId id) =>
      Outbound.one(id, const Envelope('ack', <String, Object?>{}));

  /// Нэр — 1..16 тэмдэгт, эхний ба сүүлийн зай авна.
  static String _sanitizeName(String raw) {
    final String t = raw.trim();
    if (t.isEmpty) return 'Зочин';
    return t.length <= 16 ? t : t.substring(0, 16);
  }
}
