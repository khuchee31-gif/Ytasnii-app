// Гүнзгий шалгалтаар олсон алдаануудын БУЦАЖ ИРЭХГҮЙ гэсэн баталгаа.
//
// Эдгээр нь бүгд «ажиллаж байгаа» мэт харагддаг байсан: тест ногоон,
// зураг зөв, гараар товшиход эвгүй зүйл алга. Алдаа бүр нь ЗӨВХӨН
// зориудаар халдсан үед л гарч ирдэг.

import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:engine/engine.dart' as eng;
import 'package:protocol/protocol.dart';
import 'package:server/server.dart';
import 'package:test/test.dart';

Uint8List _seed(int n) =>
    Uint8List.fromList(List<int>.generate(32, (int i) => (i * 17 + n) & 0xFF));

GameRoom _room(String code, {int seed = 1}) =>
    GameRoom(code: code, hostId: 'h', seed: _seed(seed));

void main() {
  group('Ботын дугаарлалт гацахгүй', () {
    test('«бот» гэсэн хоёр хүн байхад ч бот нэмэгдсээр байна', () {
      // ОЛДСОН АЛДАА: хоёр хүн «бот» гэж бичихэд `uniqueName` хоёр
      // дахийг нь «бот 2» болгодог байв. Тэр нь хоёрдугаар ботын
      // түлхүүр тул бот «Бот 2 2» болж нэрлэгдэнэ. Дугаарлалт нь
      // харагдах нэрээр хайдаг байсан тул «Бот 2»-ыг олохоо больж,
      // 2 дээр ҮҮРД гацна: эзний «+ БОТ НЭМЭХ» товч чимээгүй үхнэ.
      final GameRoom r = _room('BOTN');
      r.join('h', 'Хүчээ', 'x');
      // «бот» нь ОДОО нөөцлөгдсөн — хоёулаа татгалзана.
      expect(r.join('a', 'бот', 'x').single.msg.data['code'],
          ErrCode.nameReserved);
      expect(r.join('b', 'Бот', 'x').single.msg.data['code'],
          ErrCode.nameReserved);
      // Дугаарлагдсан хэлбэр нь ч мөн адил.
      expect(r.join('c', 'Бот 2', 'x').single.msg.data['code'],
          ErrCode.nameReserved);
      expect(r.playerCount, 1);

      for (int i = 0; i < 5; i++) {
        final int before = r.playerCount;
        r.addBots('h', 1);
        expect(r.playerCount, before + 1, reason: '$i дэх даралт юу ч нэмсэнгүй');
      }
    });

    test('«бот» нэр сервер УНАГААХГҮЙ', () {
      // ОЛДСОН АЛДАА (би өөрөө оруулсан): гаралтыг шалгаж эхэлсний
      // дараа «бот» гэсэн хоёр дахь хүнд бүх дугаарлалт нөөцлөгдсөн
      // болж, `uniqueName` `StateError` ШИДДЭГ байв. Тэр нь сүлжээний
      // сонсогч дотор гарах тул БҮХ өрөөтэй хамт сервер унана.
      final GameRoom r = _room('BOTX');
      r.join('h', 'Хүчээ', 'x');
      for (final String n in <String>['бот', 'Бот', 'БОТ', 'бот 5', 'бот3']) {
        expect(() => r.join('u$n', n, 'x'), returnsNormally, reason: n);
      }
    });

    test('ижил нэртэй хүмүүс дугаарлагдана', () {
      final GameRoom r = _room('DUPE');
      r.join('h', 'Бат', 'x');
      r.join('a', 'Бат', 'x');
      r.join('b', 'Бат', 'x');
      expect(r.players.map((PublicPlayer p) => p.name).toList(),
          <String>['Бат', 'Бат 2', 'Бат 3']);
    });

    test('бот бүр ӨӨР дугаартай, ӨӨР нэртэй', () {
      final GameRoom r = _room('BOTU');
      r.join('h', 'Хүчээ', 'x');
      r.addBots('h', 10);
      final List<PublicPlayer> bots =
          r.players.where((PublicPlayer p) => p.isBot).toList();
      expect(bots.length, 10);
      expect(bots.map((PublicPlayer p) => p.id).toSet().length, 10);
      expect(bots.map((PublicPlayer p) => p.name).toSet().length, 10);
    });

    test('ботын нэр нь «Бот N» хэвээр — «Бот N 2» болохгүй', () {
      final GameRoom r = _room('BOTB');
      r.join('h', 'Хүчээ', 'x');
      r.addBots('h', 3);
      final List<String> names = r.players
          .where((PublicPlayer p) => p.isBot)
          .map((PublicPlayer p) => p.name)
          .toList();
      expect(names, <String>['Бот 1', 'Бот 2', 'Бот 3']);
    });
  });

  group('Ботын дугаар — угтвар', () {
    test('бүх ботын дугаар нөөцлөгдсөн угтвартай', () {
      // Сервер энэ угтвартай дугаарыг `hello`-д хүлээж авдаггүй. Хэрэв
      // угтвар алга болвол хамгаалалт чимээгүй унтарна.
      final GameRoom r = _room('PREF');
      r.join('h', 'Хүчээ', 'x');
      r.addBots('h', 6);
      for (final PublicPlayer p in r.players.where((PublicPlayer p) => p.isBot)) {
        expect(p.id.startsWith(kBotIdPrefix), isTrue, reason: p.id);
      }
    });

    test('хүний дугаар тэр угтвартай байж БОЛОХГҮЙ гэж үзнэ', () {
      // Утас санамсаргүй hex үүсгэдэг тул «bot-» гэж эхлэхгүй. Гэхдээ
      // энэ нь гэрээ — шалгаад тавья.
      expect(kBotIdPrefix.isNotEmpty, isTrue);
      expect(kBotIdPrefix, 'bot-');
    });
  });

  group('Өрөөний цэвэрлэгээ', () {
    test('тоглолт дунд бүгд салсан өрөө ЭЦЭСТЭЭ устана', () {
      // ОЛДСОН АЛДАА: `sweepEmpty` нь `humanCount`-оор тоолдог байв.
      // `leave` нь тоглолт эхэлсний дараа суудлыг үлдээдэг (эргэж орох
      // эрх) тул тоо нь хэзээ ч тэг болохгүй. Нэг сокетоор «өрөө үүсгэ
      // → 5 бот нэм → эхлүүл → тасал» гэдгийг 505 удаа давтахад сервер
      // дахин өрөө үүсгэж чадахгүй болсон.
      final Hub hub = Hub(maxRooms: 4);
      for (int i = 0; i < 4; i++) {
        final GameRoom? r = hub.create('h$i');
        expect(r, isNotNull);
        r!.join('h$i', 'Хүн$i', 'x');
        r.addBots('h$i', 5);
        r.start('h$i', 0);
        r.leave('h$i');
      }
      expect(hub.create('late'), isNull, reason: 'багтаамж дүүрсэн байх ёстой');

      // Тэвчээрийн хугацаа дуусаагүй байхад УСТГАХГҮЙ — Wi-Fi саатаж
      // болно.
      expect(hub.sweepEmpty(nowMs: 0), 0);
      expect(hub.sweepEmpty(nowMs: Hub.graceMs - 1), 0);
      expect(hub.roomCount, 4);

      expect(hub.sweepEmpty(nowMs: Hub.graceMs), 4);
      expect(hub.roomCount, 0);
      expect(hub.create('late'), isNotNull);
    });

    test('хүн эргэж орвол тоолуур ТЭГЛЭГДЭНЭ', () {
      final Hub hub = Hub(maxRooms: 4);
      final GameRoom r = hub.create('h')!;
      r.join('h', 'Хүн', 'x');
      r.addBots('h', 5);
      r.start('h', 0);
      r.leave('h');

      hub.sweepEmpty(nowMs: 0);
      hub.sweepEmpty(nowMs: Hub.graceMs - 10);
      r.join('h', 'Хүн', 'x');                 // эргэж орлоо
      hub.sweepEmpty(nowMs: Hub.graceMs + 10);
      expect(hub.roomCount, 1, reason: 'эргэж орсон хүний тоглолт устлаа');

      // Дахин гарвал тэвчээр ШИНЭЭР эхэлнэ.
      r.leave('h');
      hub.sweepEmpty(nowMs: Hub.graceMs + 20);
      expect(hub.roomCount, 1);
      hub.sweepEmpty(nowMs: Hub.graceMs * 2 + 40);
      expect(hub.roomCount, 0);
    });

    test('лоббид хүнгүй үлдсэн ботон өрөө ШУУД устана', () {
      final Hub hub = Hub(maxRooms: 4);
      final GameRoom r = hub.create('h')!;
      r.join('h', 'Хүн', 'x');
      r.addBots('h', 5);
      r.leave('h');
      expect(hub.sweepEmpty(nowMs: 0), 1);
    });

    test('өрөөнүүд бүртгэлээс уншигдана — цаг урагшлуулахад хэрэгтэй', () {
      final Hub hub = Hub();
      hub.create('a');
      hub.create('b');
      expect(hub.rooms.length, 2);
    });
  });

  group('Хэрэгслүүд протоколоос хоцрохгүй', () {
    test('tool/bots.dart нь хувилбарыг ӨӨРӨӨ зарлахгүй', () async {
      // ОЛДСОН АЛДАА: `tool/bots.dart` дотор `const int kProtocolVersion
      // = 1;` гэж ХУУЛБАРЛАСАН байв. Сервер 2 болоход хэрэгсэл чимээгүй
      // хоцорч, бүх бот `badVersion` авдаг болсон — `tools/play.sh`
      // бүхэлдээ ажиллахаа больсон ч бүх тест НОГООН хэвээр байв.
      final String src = await _toolSource('tool/bots.dart');
      expect(src.contains('kProtocolVersion ='), isFalse,
          reason: 'протоколын хувилбарыг ЗӨВХӨН protocol багц эзэмшинэ');
      expect(src.contains("import 'package:protocol/protocol.dart'"), isTrue);
    });

    test('симуляцийн ботууд НӨӨЦЛӨГДСӨН угтвар хэрэглэхгүй', () async {
      // Сервер `bot-` угтвартай дугаарыг сокетоор хүлээж авахаа больсон.
      final String src = await _toolSource('tool/bots.dart');
      expect(src.contains("'$kBotIdPrefix"), isFalse,
          reason: 'эдгээр нь ХҮНИЙГ дүрдэг хэрэгслүүд, өрөөний ботууд биш');
    });
  });

  group('Мөрдөгчийн хариу', () {
    test('ХҮН мөрдөгч ХЭНИЙГ асуусныг буцааж авна', () {
      // ОЛДСОН АЛДАА: `targetSeat` нь ботын САНАХ ОЙгоос уншигддаг
      // байсан тул хүн мөрдөгчид ҮРГЭЛЖ хоосон явдаг байв.
      final GameRoom r = _room('DETE', seed: 4);
      final List<String> ids = <String>['h', 'b', 'c', 'd', 'e', 'f', 'g', 'i'];
      for (final String id in ids) {
        r.join(id, 'Хүн$id', 'x');
      }
      r.start('h', 0);

      final PlayerId det = ids.firstWhere(
          (String id) => r.debugRoleOf(id) == eng.Role.detective);
      final int mySeat = r.seatOf(det)!;
      final int target = r.players
          .map((PublicPlayer p) => p.seat!)
          .firstWhere((int s) => s != mySeat);

      // Мөрдөгчийн үе шат хүртэл явуулна.
      int t = 0;
      while (r.phase != NetPhase.nightDetective && t < 200000) {
        t += 250;
        r.tick(t);
      }
      expect(r.phase, NetPhase.nightDetective);
      r.nightAction(det, target, t);

      // Үүр цайх хүртэл.
      final List<Envelope> mine = <Envelope>[];
      while (r.phase != NetPhase.day && t < 400000) {
        t += 250;
        for (final Outbound o in r.tick(t)) {
          if (!o.broadcast &&
              o.recipients.contains(det) &&
              o.msg.type == S2C.investigateResult) {
            mine.add(o.msg);
          }
        }
      }
      expect(mine, isNotEmpty, reason: 'мөрдөгчид хариу ирсэнгүй');
      expect(mine.single.data['targetSeat'], target);
    });
  });
}

/// Багцын дотор байгаа, гэхдээ `lib/`-д БИШ файлыг уншина.
///
/// Замыг ажлын хавтсаар БИШ, `package:` хаягаар олно: `dart test`-ийг
/// репогийн язгуураас ажиллуулахад харьцангуй зам олдохгүй.
Future<String> _toolSource(String rel) async {
  final Uri? u =
      await Isolate.resolvePackageUri(Uri.parse('package:server/server.dart'));
  if (u == null) throw StateError('server багц олдсонгүй');
  final Directory pkg = File.fromUri(u).parent.parent;
  String src = File('${pkg.path}/$rel').readAsStringSync();
  // ТАЙЛБАРГҮЙ. Эс бөгөөс «ингэж бичиж БОЛОХГҮЙ» гэсэн тайлбар өөрөө
  // шалгалтыг унагана.
  src = src.replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '');
  return src
      .split('\n')
      .map((String l) {
        final int i = l.indexOf('//');
        return i < 0 ? l : l.substring(0, i);
      })
      .join('\n');
}
