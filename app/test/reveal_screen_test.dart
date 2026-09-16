// S06 — Хөзөр нээх ёслолын тестүүд (GDD-06 §S06, GDD-10 §6 ба §7).
//
// Энэ бол бүлгийн хамгийн чухал файл: дөрвөн тоо, хоёр эрхий, дахин харалтын
// зарлал, `FLAG_SECURE` — бүгд энд баригдана.

import 'package:engine/engine.dart';
import 'package:flutter/material.dart' hide Intent;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hotuntlaa/game/game_controller.dart';
import 'package:hotuntlaa/screens/reveal_screen.dart';
import 'package:hotuntlaa/ui/tokens.dart';

import 'deal_test_support.dart';

final Finder _left = find.byKey(const ValueKey<String>('thumbLeft'));
final Finder _right = find.byKey(const ValueKey<String>('thumbRight'));

/// S05-ын хаалтыг нээж, хөзрийн ар тал руу орно.
Future<void> _passHandoff(WidgetTester tester) async {
  await tester.pump(kHandoffLock + const Duration(milliseconds: 20));
  await tester.tapAt(const Offset(180, 400));
  await tester.pump();
}

/// Хоёр эрхий зэрэг — энэ хоёр заагчийг тестийн турш БАРЬЖ байна.
Future<List<TestGesture>> _twoThumbsDown(WidgetTester tester) async {
  final TestGesture a = await tester.startGesture(tester.getCenter(_left));
  final TestGesture b = await tester.startGesture(tester.getCenter(_right));
  await tester.pump();
  return <TestGesture>[a, b];
}

/// Босго + эргэлт. ХОЁР кадр хэрэгтэй: эхнийх нь таймерыг ажиллуулж эргэлтийг
/// эхлүүлнэ, хоёр дахь нь эргэлтийг гүйцээнэ.
Future<void> _holdThroughFlip(WidgetTester tester) async {
  await tester.pump(kHoldThreshold + const Duration(milliseconds: 20));
  await tester.pump(kCardFlip);
}

Future<void> _release(WidgetTester tester, List<TestGesture> g) async {
  for (final TestGesture t in g) {
    await t.up();
  }
  await tester.pump();
}

void main() {
  testWidgets('Ёслол S05-ын хаалтаас эхэлж, дараа нь хөзрийн ар тал гарна',
      (WidgetTester tester) async {
    final GameController c = dealtController();
    await pumpScreen(tester, RevealScreen(controller: c, onAllSeen: () {}));

    expect(find.text('Ширээн дээр тавь. Дараах — №1'), findsOneWidget);
    await _passHandoff(tester);
    expect(find.text('Дүрээ харахын тулд хоёр эрхийгээ дар.'), findsOneWidget);
    expect(find.text('№1'), findsOneWidget);
  });

  testWidgets('НЭГ эрхий хөзрийг нээхгүй', (WidgetTester tester) async {
    final GameController c = dealtController();
    await pumpScreen(tester, RevealScreen(controller: c, onAllSeen: () {}));
    await _passHandoff(tester);

    final RoleCardCopy copy = cardCopyFor(c.roleOf(1)!);
    final TestGesture a = await tester.startGesture(tester.getCenter(_left));
    await tester.pump(kHoldThreshold + kCardFlip + const Duration(seconds: 1));
    expect(find.text(copy.theme), findsNothing);
    expect(c.seen, isEmpty);
    await a.up();
    await tester.pump();
  });

  testWidgets('Хоёр эрхий + 220 мс + эргэлт → дүр, ажил, зөвлөгөө гурав гарна',
      (WidgetTester tester) async {
    final GameController c = dealtController();
    await pumpScreen(tester, RevealScreen(controller: c, onAllSeen: () {}));
    await _passHandoff(tester);

    final RoleCardCopy copy = cardCopyFor(c.roleOf(1)!);
    final List<TestGesture> g = await _twoThumbsDown(tester);

    // 220 мс болтол ЮУ Ч өөрчлөгдөхгүй (`holdingIntent`).
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text(copy.theme), findsNothing);

    await tester.pump(const Duration(milliseconds: 40));
    await tester.pump(kCardFlip);
    expect(find.text(copy.theme), findsOneWidget);
    expect(find.text(copy.mechanic), findsOneWidget);
    expect(find.text(copy.job), findsOneWidget);
    expect(find.text(copy.advice), findsOneWidget);
    expect(c.seen.contains(1), isTrue);

    await _release(tester, g);
  });

  testWidgets('Эрхий тавихад хөзөр ТЭР ДОР НЬ алга болно',
      (WidgetTester tester) async {
    final GameController c = dealtController();
    await pumpScreen(tester, RevealScreen(controller: c, onAllSeen: () {}));
    await _passHandoff(tester);

    final RoleCardCopy copy = cardCopyFor(c.roleOf(1)!);
    final List<TestGesture> g = await _twoThumbsDown(tester);
    await _holdThroughFlip(tester);
    expect(find.text(copy.theme), findsOneWidget);

    await g.first.up();
    await tester.pump(kCardHide);
    expect(find.text(copy.theme), findsNothing);
    expect(find.text('Ширээн дээр тавь'), findsOneWidget);
    await g.last.up();
    await tester.pump();
  });

  testWidgets('2.5 секундын дараа өөрөө нуугдана',
      (WidgetTester tester) async {
    final GameController c = dealtController();
    await pumpScreen(tester, RevealScreen(controller: c, onAllSeen: () {}));
    await _passHandoff(tester);

    final RoleCardCopy copy = cardCopyFor(c.roleOf(1)!);
    final List<TestGesture> g = await _twoThumbsDown(tester);
    await _holdThroughFlip(tester);

    await tester.pump(const Duration(milliseconds: 2000));
    expect(find.text(copy.theme), findsOneWidget, reason: 'эрт хаагдахгүй');
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text(copy.theme), findsNothing);

    await _release(tester, g);
  });

  testWidgets('Эхний гурван тоглолтод авто-нуулт 4000 мс (GDD-11 §2)',
      (WidgetTester tester) async {
    final GameController c = dealtController(gamesPlayed: 0);
    await pumpScreen(tester, RevealScreen(controller: c, onAllSeen: () {}));
    await _passHandoff(tester);

    final RoleCardCopy copy = cardCopyFor(c.roleOf(1)!);
    final List<TestGesture> g = await _twoThumbsDown(tester);
    await _holdThroughFlip(tester);

    await tester.pump(const Duration(milliseconds: 3000));
    expect(find.text(copy.theme), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1100));
    expect(find.text(copy.theme), findsNothing);

    await _release(tester, g);
  });

  testWidgets('Дахин харалт ЗАРЛАГДАЖ, тоологдоно — дэвтэрт бичигдэхгүй',
      (WidgetTester tester) async {
    final GameController c = dealtController();
    await pumpScreen(tester, RevealScreen(controller: c, onAllSeen: () {}));
    await _passHandoff(tester);

    List<TestGesture> g = await _twoThumbsDown(tester);
    await _holdThroughFlip(tester);
    await _release(tester, g);
    expect(c.reviewCount[1], isNull);

    // Хоёр дахь удаа — баннер ЭХЛЭЭД гарна.
    g = await _twoThumbsDown(tester);
    await tester.pump(kHoldThreshold + const Duration(milliseconds: 20));
    expect(find.text('№1 дүрээ аль хэдийн харсан.'), findsWidgets);

    await tester.pump(kAlreadySeenBanner + kCardFlip);
    expect(c.reviewCount[1], 1);
    await _release(tester, g);

    // Гурав дахь удаа — «(2-р удаа)».
    g = await _twoThumbsDown(tester);
    await tester.pump(kHoldThreshold + const Duration(milliseconds: 20));
    expect(find.text('№1 дүрээ аль хэдийн харсан. (2-р удаа)'), findsWidgets);
    await _release(tester, g);
  });

  testWidgets('`FLAG_SECURE` тараалтын route-ын турш асна',
      (WidgetTester tester) async {
    final List<MethodCall> calls = captureGuardCalls();
    final GameController c = dealtController();
    await pumpScreen(tester, RevealScreen(controller: c, onAllSeen: () {}));
    await tester.pump();

    expect(
      calls.any((MethodCall m) =>
          m.method == 'setSecure' &&
          (m.arguments as Map<Object?, Object?>)['on'] == true),
      isTrue,
    );
  });

  testWidgets('Бүх суудал харсны дараа «Бүгд харлаа.» → S07',
      (WidgetTester tester) async {
    final GameController c = dealtController(seats: 6);
    bool allSeen = false;
    await pumpScreen(
        tester, RevealScreen(controller: c, onAllSeen: () => allSeen = true));

    for (int seat = 1; seat <= 6; seat++) {
      await _passHandoff(tester);
      final List<TestGesture> g = await _twoThumbsDown(tester);
      await _holdThroughFlip(tester);
      expect(find.text(cardCopyFor(c.roleOf(seat)!).theme), findsOneWidget);
      await _release(tester, g);
      if (seat < 6) {
        await tester.tap(find.text('Ширээн дээр тавь'));
        await tester.pump();
      }
    }

    expect(find.text('Бүгд харлаа.'), findsOneWidget);
    expect(allSeen, isFalse);
    await tester.pump(kHandoffLock + const Duration(milliseconds: 20));
    expect(allSeen, isTrue);
    expect(c.seen.length, 6);
  });

  testWidgets('320 логик px дээр 12 хөзрийн аль нь ч мөр халиулахгүй',
      (WidgetTester tester) async {
    final GameController c = dealtController();
    await pumpScreen(
      tester,
      RevealScreen(controller: c, onAllSeen: () {}),
      size: kPhoneNarrow,
    );

    for (int seat = 1; seat <= 12; seat++) {
      await _passHandoff(tester);
      final List<TestGesture> g = await _twoThumbsDown(tester);
      await _holdThroughFlip(tester);
      // Хөзөр үнэхээр НЭЭГДСЭН эсэхийг шалгана — эс бөгөөс халилтын тест
      // хоосон дэлгэц харж «дажгүй» гэж хэлэх байсан.
      expect(find.text(cardCopyFor(c.roleOf(seat)!).theme), findsOneWidget);
      expect(tester.takeException(), isNull,
          reason: '№$seat-ийн хөзөр 320px дээр халилаа');
      await _release(tester, g);
      if (seat < 12) {
        await tester.tap(find.text('Ширээн дээр тавь'));
        await tester.pump();
      }
    }
    // 12 суудалд таван дүр бүгд гарсан эсэхийг шалгах шаардлагагүй — гол нь
    // аль ч хуулбар намхан дэлгэцэд халиагүй явдал.
    expect(tester.takeException(), isNull);
  });

  test('Хөзрийн хуулбар нь GDD-02 §5-ын мөрүүд, шинэ текст БАЙХГҮЙ', () {
    expect(cardCopyFor(Role.detective).theme, 'МӨРЧИН');
    expect(cardCopyFor(Role.detective).mechanic, 'Мөрдөгч');
    expect(cardCopyFor(Role.doctor).theme, 'БАРИАЧ');
    expect(cardCopyFor(Role.killer).faction, 'Мафи');
    expect(cardCopyFor(Role.boss).mechanic, 'Ахлагч');
    expect(cardCopyFor(Role.citizen).job, 'Шөнө сэжигтэй суудлаа товш. Өдөр ярь.');
    // Таван дүр тус бүр дөрвөн мөртэй, хоосон мөр БАЙХГҮЙ.
    for (final Role r in Role.values) {
      final RoleCardCopy c = cardCopyFor(r);
      expect(c.theme.isNotEmpty && c.job.isNotEmpty && c.advice.isNotEmpty,
          isTrue);
    }
  });
}
