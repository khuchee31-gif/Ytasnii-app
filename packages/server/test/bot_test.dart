// Хиймэл тоглогчид.
//
// ХОЁР ЗҮЙЛ БАТЛАХ ЁСТОЙ:
//
//   1. БОТ ХУУРЧ БОЛОХГҮЙ. Сервер бүх дүрийг мэддэг. Хэрэв ботын тархи
//      тэр рүү хүрч чадвал бот үргэлж ялж, туршилтын хэрэгсэл болохоо
//      болино. Түүнээс ч муу нь — хүнтэй хамт тоглоход илрүүлэх аргагүй
//      хууралт болно.
//
//   2. ТОГЛОЛТ ҮНЭХЭЭР ДУУСАХ ЁСТОЙ. Ганцаараа туршиж байгаа хүн
//      эцсийг нь харах ёстой. Санамсаргүй санал өгдөг ботууд өдөр бүр
//      тэнцэж, хэн ч хасагдахгүй, тоглоом мөнхөрнө.

import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:engine/engine.dart' as eng;
import 'package:protocol/protocol.dart';
import 'package:server/server.dart';
import 'package:server/src/bot_brain.dart';
import 'package:test/test.dart';

Uint8List _seed(int n) =>
    Uint8List.fromList(List<int>.generate(32, (int i) => (i * 37 + n) & 0xFF));

/// Нэг хүн + ботууд.
GameRoom _solo(int bots, {int seed = 5}) {
  final GameRoom r = GameRoom(code: 'SOLO', hostId: 'h', seed: _seed(seed));
  r.join('h', 'Хүчээ', 'punk_01');
  r.addBots('h', bots);
  return r;
}

/// Тоглолтыг 250 мс-ийн алхмаар (серверийн жинхэнэ алхам) гүйцэд явуулна.
List<Envelope> _playOut(GameRoom r, {int limitMs = 900000}) {
  final List<Envelope> broadcasts = <Envelope>[];
  void take(List<Outbound> out) {
    for (final Outbound o in out) {
      if (o.broadcast) broadcasts.add(o.msg);
    }
  }

  take(r.start('h', 0));
  for (int t = 250; t <= limitMs; t += 250) {
    take(r.tick(t));
    if (r.phase == NetPhase.gameOver) break;
  }
  return broadcasts;
}

/// Эх кодыг ТАЙЛБАРГҮЙГЭЭР уншина.
///
/// Мөрийн (`//`) ба блокийн (`/* */`) тайлбарыг хоёуланг нь хасна.
/// Зөвхөн мөрийнхийг хассан нь блок тайлбарт бичсэн үгэнд ХУДАЛ
/// унадаг байв.
///
/// Файлыг `package:` хаягаар олно, ажлын хавтсаар БИШ: `dart test`-ийг
/// репогийн язгуураас ажиллуулахад харьцангуй зам олдохгүй бөгөөд тест
/// нь «алдаа олсонгүй» гэж бус, шидэгдэж унадаг байв.
Future<String> _code(String packageUri) async {
  final Uri? u = await Isolate.resolvePackageUri(Uri.parse(packageUri));
  if (u == null) throw StateError('$packageUri олдсонгүй');
  String src = File.fromUri(u).readAsStringSync();
  src = src.replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '');
  return src
      .split('\n')
      .map((String l) {
        final int i = l.indexOf('//');
        return i < 0 ? l : l.substring(0, i);
      })
      .join('\n');
}

const String _brain = 'package:server/src/bot_brain.dart';

/// `import '...'` жагсаалт.
Set<String> _imports(String code) => RegExp(r"import\s+'([^']+)'")
    .allMatches(code)
    .map((RegExpMatch m) => m.group(1)!)
    .toSet();

/// Нэрлэсэн ангийн их биеийг (эхний `{`-ээс тэнцүү `}` хүртэл) авна.
String _classBody(String code, String name) {
  final int at = code.indexOf(RegExp('class\\s+$name\\b'));
  if (at < 0) throw StateError('$name анги олдсонгүй');
  final int open = code.indexOf('{', at);
  int depth = 0;
  for (int i = open; i < code.length; i++) {
    if (code[i] == '{') depth++;
    if (code[i] == '}') {
      depth--;
      if (depth == 0) return code.substring(open + 1, i);
    }
  }
  throw StateError('$name анги хаагдаагүй');
}

/// `final <төрөл> <нэр>;` бүрийг нэр → төрөл болгож цуглуулна.
Map<String, String> _finalFields(String body) {
  final Map<String, String> out = <String, String>{};
  // Эхлүүлэгчтэй талбарыг БАС барина (`final X y = ...;`). Эхний
  // хувилбар нь зөвхөн `;`-ээр төгссөнийг барьдаг байсан тул
  // `final Map<int, eng.Role> table = const <int, eng.Role>{};` гэсэн
  // бүх дүрийн хүснэгтийг чимээгүй өнгөрөөж байв (шалгаж үзсэн).
  final RegExp re =
      RegExp(r'(?:final|late final|var)\s+([\w.<>,\s?]+?)\s+(\w+)\s*(?:=[^;]*)?;');
  for (final RegExpMatch m in re.allMatches(body)) {
    out[m.group(2)!] = m.group(1)!.replaceAll(RegExp(r'\s+'), ' ').trim();
  }
  return out;
}


void main() {
  group('Бот хуурч чадахгүй', () {
    test('ботын тархи ӨРӨӨГ хардаггүй', () async {
      // ЭХ КОДЫН шалгалт. Хэн нэгэн хожим өрөөг тархи руу оруулбал энэ
      // тест тэр дор нь унана.
      final String src = await _code(_brain);
      for (final String banned in <String>[
        'GameRoom',
        '_secrets',
        'debugRoleOf',
        'dart:io',
        'DateTime.',
        'Random(',
      ]) {
        expect(src.contains(banned), isFalse,
            reason: 'bot_brain.dart дотор «$banned» байна — '
                'тархи зөвхөн BotView-ээс уншина');
      }
    });

    test('тархи ЗӨВХӨН хөдөлгүүр, протоколыг оруулна', () async {
      // Тусдаа файл оруулж, түүгээрээ өрөөнд хүрэх зам БАЙХГҮЙ.
      final Set<String> got = _imports(await _code(_brain));
      expect(got, <String>{
        'package:engine/engine.dart',
        'package:protocol/protocol.dart',
      });
    });

    test('BotView-ийн талбарууд ЯГ мэдэгдсэн жагсаалттай таарна', () async {
      // ЯАГААД БИЧВЭР ХАЙХАА БОЛИВ:
      //
      // Өмнө нь «`Map<Seat, Role>` гэж бичихийг хориглов» гэсэн шалгалт
      // байв. Тэр нь ХООСОН: `protocol` нь `typedef Seat = int` гэж
      // зарладаг тул `Map<int, eng.Role>` гэж бичихэд ЯГ ижил зүйл
      // болох атлаа шалгалт өнгөрнө. Бүх дүрийн хүснэгтийг ингэж
      // нэмээд шалгуулж үзэхэд — өнгөрсөн.
      //
      // Одоо ТАЛБАР БҮРИЙГ нэрээр нь, төрлөөр нь тоолно. Ямар ч шинэ
      // талбар — хэрхэн нэрлэсэн ч, ямар төрөлтэй ч — энэ тестийг
      // унагана. Тэгээд хүн «энэ талбар дүрийг задлах уу?» гэж бодох
      // ёстой болно. Яг тэр л бодол хэрэгтэй.
      expect(_finalFields(_classBody(await _code(_brain), 'BotView')),
          <String, String>{
            'mySeat': 'int',
            // ЦОРЫН ГАНЦ дүр — ӨӨРИЙНХ нь. Ганц утга тул цуглуулга
            // болгож ӨРГӨТГӨХ боломжгүй.
            'myRole': 'eng.Role',
            'phase': 'NetPhase',
            'aliveSeats': 'List<int>',
            'myAllies': 'Set<int>',
            'allyPicks': 'Map<int, int>',
            'liveVotes': 'Map<int, int>',
            'mem': 'BotMemory',
          });
    });

    test('BotView-д `Role` ТӨРӨЛ ЯГ НЭГ УДАА гарна', () async {
      // Талбарын жагсаалтаас ГАДНА тоолно: нэрлэсэн параметр, getter,
      // метод, эхлүүлэгч — дүрийг тархи руу зөөх зам олон бий.
      //
      // ЗӨВХӨН ТӨРЛИЙГ тоолно: `myRole` гэсэн НЭР нь бас «Role» гэсэн
      // үсгүүдийг агуулдаг тул урд нь үсэг байгааг хасна. Ингэснээр
      // `eng.Role`, `Map<int, Role>` гэх мэт ТӨРЛИЙН хэрэглээ л
      // тоологдоно.
      final String body = _classBody(await _code(_brain), 'BotView');
      expect(RegExp(r'(?<![A-Za-z_])Role').allMatches(body).length, 1,
          reason: body);
    });

    test('BotMemory-д ч дүр байхгүй', () async {
      final Map<String, String> got =
          _finalFields(_classBody(await _code(_brain), 'BotMemory'));
      for (final MapEntry<String, String> e in got.entries) {
        expect(e.value.contains('Role'), isFalse,
            reason: 'BotMemory.${e.key} нь дүр агуулж байна');
      }
    });

    test('ботын харагдацад ӨӨРИЙНХӨӨС өөр дүр БАЙХГҮЙ', () {
      final GameRoom r = _solo(7);
      r.start('h', 0);
      // Шөнө мафийн үе хүртэл аваачна — тэр үед мафийн санаа `_intents`
      // дотор аль хэдийн сууж эхэлдэг.
      for (int t = 250; t <= 120000; t += 250) {
        r.tick(t);
        if (r.phase == NetPhase.nightDoctor) break;
      }

      for (final PlayerId id in r.debugBotIds) {
        final BotView v = r.debugBotView(id);
        expect(v.myRole, r.debugRoleOf(id), reason: '$id өөрийн дүр');

        final bool mafi = eng.factionOf(v.myRole) == eng.Faction.mafi;
        if (!mafi) {
          expect(v.myAllies, isEmpty,
              reason: '$id мафи биш атлаа хамтрагчтай');
          expect(v.allyPicks, isEmpty,
              reason: '$id мафи биш атлаа мафийн сонголтыг харж байна');
        }
      }
    });

    test('ботууд ӨӨР ӨӨР санамсаргүй урсгалтай', () {
      // Нэг урсгалтай байсан бол бүгд ижил сонголт хийж, мафи хэзээ ч
      // хуваагдахгүй, эмч үргэлж алуурчны барихыг эмчлэх байв.
      final GameRoom r = _solo(7);
      expect(r.debugBotIds.toSet().length, 7);
    });
  });

  group('Ботон тоглолт', () {
    test('бүтэн тоглолт ДУУСНА', () {
      final GameRoom r = _solo(7);
      final List<Envelope> out = _playOut(r);
      expect(r.phase, NetPhase.gameOver, reason: 'тоглолт дуусаагүй');
      expect(r.win, isNot(eng.WinState.none));

      // Санал хураалт ҮНЭХЭЭР хэн нэгнийг хасаж байгаа эсэх. Санамсаргүй
      // ботууд бол өдөр бүр тэнцэж, энэ шалгуур унана.
      final bool anyEliminated = out.any((Envelope e) =>
          e.type == S2C.eliminated && e.data['seat'] != null);
      expect(anyEliminated, isTrue,
          reason: 'өдөр хэнийг ч хасаагүй — ботууд нэг хүн рүү нийлээгүй');
    });

    test('ЯГ давтагдана', () {
      String run(int seed) {
        final GameRoom r = _solo(7, seed: seed);
        return _playOut(r).map((Envelope e) => e.encode()).join('\n');
      }

      expect(run(5), run(5), reason: 'ижил үр ижил тоглолт өгөх ёстой');
      expect(run(5), isNot(run(6)), reason: 'өөр үр өөр тоглолт');
    });

    test('ботон тоглолтын нийтийн мессежид ДҮР ГАРАХГҮЙ', () {
      final GameRoom r = _solo(7);
      final List<Envelope> out = _playOut(r);
      final StringBuffer b = StringBuffer();
      for (final Envelope e in out) {
        // Тоглолт дуусахад дүр ил болох нь ЗӨВ — түүнийг алгасна.
        if (e.type == S2C.gameOver) continue;
        b.write(e.encode());
        b.write('\n');
      }
      final String text = b.toString();
      for (final eng.Role role in eng.Role.values) {
        expect(text.contains(role.name), isFalse,
            reason: 'нийтийн мессежид «${role.name}» гарчээ');
      }
      for (final String word in <String>['mafi', 'hotynhon', 'faction']) {
        expect(text.contains(word), isFalse, reason: '«$word» гарчээ');
      }
    });

    test('мафи ботууд НЭГ хүн рүү нийлнэ', () {
      // Хоёр мафитай ширээ (8 суудал). Тус тусдаа санал өгвөл хөдөлгүүр
      // тэнцлийг дарааллын сэлгэцээр тайлж, шөнө санамсаргүй харагдана.
      final GameRoom r = _solo(7);
      r.start('h', 0);
      for (int t = 250; t <= 120000; t += 250) {
        r.tick(t);
        if (r.phase == NetPhase.nightDoctor) break;
      }
      final Set<int> targets = <int>{};
      for (final PlayerId id in r.debugBotIds) {
        final BotView v = r.debugBotView(id);
        if (eng.factionOf(v.myRole) != eng.Faction.mafi) continue;
        targets.addAll(v.allyPicks.values);
      }
      expect(targets.length, lessThanOrEqualTo(1),
          reason: 'мафи ботууд өөр өөр хүн рүү чиглэжээ: $targets');
    });
  });

  group('Ботын хурд', () {
    test('үе шат богиносно, гэхдээ БҮГД ижил хуваарьтай', () {
      final GameRoom bots = _solo(7);
      final GameRoom humans =
          GameRoom(code: 'HUMA', hostId: 'p1', seed: _seed(5));
      for (int i = 1; i <= 8; i++) {
        humans.join('p$i', 'Тоглогч$i', 'punk_01');
      }

      int firstMs(List<Outbound> out) {
        for (final Outbound o in out) {
          if (o.msg.type == S2C.phase) return o.msg.data['endsInMs']! as int;
        }
        return -1;
      }

      final int botMs = firstMs(bots.start('h', 0));
      final int humanMs = firstMs(humans.start('p1', 0));
      expect(botMs, lessThan(humanMs), reason: 'ботон өрөө хурдан байх ёстой');
      expect(humanMs, PhaseMs.dealing, reason: 'хүний өрөө хөндөгдөөгүй');
    });
  });
}
