// S09 / S10 — Шөнийн үйлдэл ба Мөрдөгчийн хариуны тестүүд (GDD-06 §S09, §S10).
//
// Энэ дэлгэцийн тестүүд нь ЖИГД БАЙДЛЫГ шалгадгаараа онцлог: дөрвөн дүр,
// нэг байрлал, нэг цонх, нэг чичиргээний хэв маяг. Цонх ЭРТ ХААГДВАЛ тэр нь
// цагийн хажуугийн суваг (GDD-10 §5) — тиймээс энд хамгийн чухал баталгаа нь
// «баталсан ч 6.0 секунд хүлээнэ» гэсэн мөр.

import 'package:engine/engine.dart';
import 'package:flutter/material.dart' hide Intent;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hotuntlaa/game/game_controller.dart';
import 'package:hotuntlaa/screens/night_action_screen.dart';
import 'package:hotuntlaa/ui/tokens.dart';
import 'package:hotuntlaa/ui/widgets.dart';

import 'deal_test_support.dart';
import 'night_test_support.dart';

/// Эргэлтийг тухайн суудал хүртэл `noAction`-оор түлхэнэ.
void advanceTo(GameController c, Seat seat) {
  while (c.currentSeat != null && c.currentSeat != seat) {
    c.submitIntent(c.currentSeat!, Ability.noAction, null);
  }
}

/// Үлдсэн суудлуудыг `noAction`-оор дүүргээд шөнийг шийдвэрлэнэ.
void finishNight(GameController c) {
  while (!c.circuitDone) {
    c.submitIntent(c.currentSeat!, Ability.noAction, null);
  }
  c.resolveNightNow();
}

Widget actionFor(GameController c, Seat seat, {VoidCallback? onFinished}) =>
    NightActionScreen(
      key: ValueKey<String>('seat-$seat'),
      controller: c,
      seat: seat,
      onFinished: onFinished ?? () {},
    );

void main() {
  testWidgets('Дүр бүрийн асуулт — дэлгэцийн ЦОРЫН ГАНЦ ялгаа',
      (WidgetTester tester) async {
    final GameController c = nightController();
    const Map<Ability, String> want = <Ability, String>{
      Ability.mafiaKill: 'Хэнийг хохироох вэ?',
      Ability.heal: 'Хэнийг аврах вэ?',
      Ability.investigate: 'Хэнийг шалгах вэ?',
      Ability.suspect: 'Хэн сэжигтэй вэ?',
    };

    for (final MapEntry<Ability, String> e in want.entries) {
      final Seat s = seatWithAbility(c, e.key);
      await pumpScreen(tester, actionFor(c, s));
      expect(find.text(e.value), findsOneWidget,
          reason: '${e.key.name} суудалд буруу асуулт');
      // Байрлал бүх дүрд ижил: дугаар, асуулт, тор, батлах зурвас.
      expect(find.text('№$s'), findsOneWidget);
      expect(find.byType(SeatGrid), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('nightConfirm')), findsOneWidget);
      await tester.pump(const Duration(seconds: 7));
    }
  });

  testWidgets('Баталсан ч цонх 6.0 секундээс ЭРТ ХААГДАХГҮЙ',
      (WidgetTester tester) async {
    final GameController c = nightController(seats: 10);
    final Seat seat = seatWithAbility(c, Ability.suspect);
    advanceTo(c, seat);
    final Seat target = seat == 1 ? 2 : 1;

    bool finished = false;
    await pumpScreen(
        tester, actionFor(c, seat, onFinished: () => finished = true));

    expect(find.text('Суудал сонго'), findsOneWidget);
    await tester.tap(find.text('$target'));
    await tester.pump();
    expect(find.text('№$target — дарж батал'), findsOneWidget);

    await holdConfirm(tester); // ~650 мс
    expect(find.text('№$target — батлагдлаа'), findsOneWidget);
    expect(finished, isFalse);

    await tester.pump(const Duration(milliseconds: 4000)); // ~4650 мс
    expect(finished, isFalse, reason: 'цонх эрт хаагдвал тэр бол цагийн ул мөр');

    await tester.pump(const Duration(milliseconds: 2000)); // ~6650 мс
    expect(finished, isTrue);
  });

  testWidgets('Товшилт батлахгүй — 600 мс ДАРЖ-ДҮҮРГЭНЭ',
      (WidgetTester tester) async {
    final GameController c = nightController(seats: 10);
    final Seat killer = seatsWithAbility(c, Ability.mafiaKill).first;
    advanceTo(c, killer);
    final Seat target = killer == 1 ? 2 : 1;

    await pumpScreen(tester, actionFor(c, killer));
    await tester.tap(find.text('$target'));
    await tester.pump();

    // Ганц товшилт — доош, дээш. Зурвас дүүрэхгүй.
    await tester.tap(find.byKey(const ValueKey<String>('nightConfirm')));
    await tester.pump();
    expect(find.text('№$target — дарж батал'), findsOneWidget);
    expect(find.text('№$target — батлагдлаа'), findsNothing);

    await tester.pump(const Duration(seconds: 7));
    finishNight(c);
    expect(c.report!.deaths, isEmpty,
        reason: 'батлаагүй сонголт нь `noAction` — товшоогүйтэй ижил');
  });

  testWidgets('Дарж-дүүргэсэн бай хөдөлгүүрт хүрнэ',
      (WidgetTester tester) async {
    final GameController c = nightController(seats: 10);
    final Seat killer = seatsWithAbility(c, Ability.mafiaKill).first;
    advanceTo(c, killer);
    final Seat target = killer == 1 ? 2 : 1;

    await pumpScreen(tester, actionFor(c, killer));
    await tester.tap(find.text('$target'));
    await tester.pump();
    await holdConfirm(tester);
    await tester.pump(const Duration(seconds: 7));

    finishNight(c);
    expect(c.report!.deaths.length, 1);
    expect(c.report!.deaths.first.victim, target);
  });

  testWidgets('S10 — «Мөр олдлоо.» 2.0 секунд, дараа нь ХЭЗЭЭ Ч дахин гарахгүй',
      (WidgetTester tester) async {
    final GameController c = nightController(seats: 10);
    final Seat det = seatWithAbility(c, Ability.investigate);
    final Seat mafia = seatsWithAbility(c, Ability.mafiaKill).first;
    advanceTo(c, det);

    await pumpScreen(tester, actionFor(c, det));
    await tester.tap(find.text('$mafia'));
    await tester.pump();
    await holdConfirm(tester); // батлагдах агшин ≈ 600 мс

    // Хариу нь ТЭР ДОР НЬ, тэр суудлын ижил цонхны дотор. Хоёр дахь
    // `RevealGate` БАЙХГҮЙ (GDD-15).
    expect(find.text('Мөр олдлоо.'), findsOneWidget);
    expect(find.text('✕'), findsOneWidget, reason: 'өнгө БА хэлбэр БА үг');

    await tester.pump(const Duration(milliseconds: 1900)); // ≈ 1950 мс харагдав
    expect(find.text('Мөр олдлоо.'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 200)); // ≥ 2000 мс
    expect(find.text('Мөр олдлоо.'), findsNothing);
    expect(find.text('Ширээн дээр тавь'), findsOneWidget);

    // Дахин харах зам БАЙХГҮЙ — товшилт ч, буцалт ч.
    await tester.tapAt(const Offset(180, 400));
    await tester.pump();
    expect(find.text('Мөр олдлоо.'), findsNothing);

    await tester.pump(const Duration(seconds: 7));
  });

  testWidgets('S10 — мафи биш бол «Мөр олдсонгүй.», ногоон ○',
      (WidgetTester tester) async {
    final GameController c = nightController(seats: 10);
    final Seat det = seatWithAbility(c, Ability.investigate);
    final Seat doctor = seatWithAbility(c, Ability.heal);
    advanceTo(c, det);

    await pumpScreen(tester, actionFor(c, det));
    await tester.tap(find.text('$doctor'));
    await tester.pump();
    await holdConfirm(tester);

    expect(find.text('Мөр олдсонгүй.'), findsOneWidget);
    expect(find.text('○'), findsOneWidget);
    await tester.pump(const Duration(seconds: 7));
  });

  testWidgets('Иргэн баталсан ч ямар ч хариу ГАРАХГҮЙ',
      (WidgetTester tester) async {
    final GameController c = nightController(seats: 10);
    final Seat citizen = seatWithAbility(c, Ability.suspect);
    advanceTo(c, citizen);
    final Seat target = citizen == 1 ? 2 : 1;

    await pumpScreen(tester, actionFor(c, citizen));
    await tester.tap(find.text('$target'));
    await tester.pump();
    await holdConfirm(tester);

    expect(find.text('Мөр олдлоо.'), findsNothing);
    expect(find.text('Мөр олдсонгүй.'), findsNothing);
    expect(find.text('Хэн сэжигтэй вэ?'), findsOneWidget);
    await tester.pump(const Duration(seconds: 7));
  });

  testWidgets('Хасагдсан суудал торонд «хасагдсан» шошготой, дарагдахгүй',
      (WidgetTester tester) async {
    final GameController c = dealtController(seats: 10);
    c.alive.remove(4);
    c.beginNight();
    final Seat seat = c.currentSeat!;

    await pumpScreen(tester, actionFor(c, seat));
    expect(find.text('хасагдсан'), findsOneWidget);

    await tester.tap(find.text('4'));
    await tester.pump();
    expect(find.text('№4 — дарж батал'), findsNothing);
    expect(find.text('Суудал сонго'), findsOneWidget);

    await tester.pump(const Duration(seconds: 7));
  });

  testWidgets('«Би харахгүй байна» — хар дэлгэц, цаг, `noAction`',
      (WidgetTester tester) async {
    final GameController c = nightController(seats: 10);
    final Seat killer = seatsWithAbility(c, Ability.mafiaKill).first;
    advanceTo(c, killer);

    bool finished = false;
    await pumpScreen(
        tester, actionFor(c, killer, onFinished: () => finished = true));
    await tester.tap(find.text('Би харахгүй байна'));
    await tester.pump();

    expect(find.text('Хэнийг хохироох вэ?'), findsNothing);
    expect(find.byType(SeatGrid), findsNothing);
    expect(find.byType(BigCountdown), findsOneWidget);

    await tester.pump(const Duration(seconds: 7));
    expect(finished, isTrue);
    finishNight(c);
    expect(c.report!.deaths, isEmpty);
  });

  testWidgets('Хоёр дахь импульс 5500 мс-д — сонголтоос ХАМААРАХГҮЙ',
      (WidgetTester tester) async {
    final List<MethodCall> haptics = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform,
            (MethodCall call) async {
      if (call.method == 'HapticFeedback.vibrate') haptics.add(call);
      return null;
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));

    final GameController c = nightController(seats: 10);
    final Seat seat = c.currentSeat!;
    await pumpScreen(tester, actionFor(c, seat));
    await tester.pump();
    final int t0 = haptics.length;
    expect(t0, greaterThanOrEqualTo(1), reason: 't = 0 импульс');

    await tester.pump(const Duration(milliseconds: 5400));
    expect(haptics.length, t0, reason: '5500-аас өмнө өөр импульс байхгүй');
    await tester.pump(const Duration(milliseconds: 200));
    expect(haptics.length, t0 + 1, reason: 't = 5500 «дамжуул» импульс');

    await tester.pump(const Duration(seconds: 7));
  });

  testWidgets('360 ба 320 логик px — мөр халихгүй, хүрэх талбай ≥ 48',
      (WidgetTester tester) async {
    for (final Size size in <Size>[kPhoneD1, kPhoneNarrow]) {
      final GameController c = nightController(seats: 20);
      final Seat seat = c.currentSeat!;
      await pumpScreen(tester, actionFor(c, seat), size: size);
      expect(tester.takeException(), isNull, reason: '$size дээр дэлгэц халив');

      final Size strip = tester
          .getSize(find.byKey(const ValueKey<String>('nightConfirm')));
      expect(strip.height, greaterThanOrEqualTo(72));

      // Торны хүрэх талбай хэзээ ч `kMinTouch`-ээс бага биш.
      final Size tile = tester.getSize(find.byType(InkWell).first);
      expect(tile.width, greaterThanOrEqualTo(kMinTouch));
      expect(tile.height, greaterThanOrEqualTo(kMinTouch));

      final Size blind =
          tester.getSize(find.ancestor(
        of: find.text('Би харахгүй байна'),
        matching: find.byType(TextButton),
      ));
      expect(blind.height, greaterThanOrEqualTo(kMinTouch));

      await tester.pump(const Duration(seconds: 7));
    }
  });
}
