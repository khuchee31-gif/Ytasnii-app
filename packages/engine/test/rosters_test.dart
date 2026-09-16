// Бүрэлдэхүүн, `b₀` ба тохиргооны шалгагчийн тест.
// GDD-05 §10.2-ын **P7**, GDD-13 §4-ийн **N9** ба **N16**.

import 'package:engine/src/model.dart';
import 'package:engine/src/rosters.dart';
import 'package:test/test.dart';

// ---------------------------------------------------------------------------
// P7 — `b₀`-ийн бүтэн хайлт (GDD-05 §10.2, GDD-04 §2.3)
// ---------------------------------------------------------------------------
//
// Конвенц, кодонд хатуу түгжигдсэн (GDD-04 §1):
//   • `PHASE_ORDER = NIGHT_FIRST` — шөнө эхэлнэ, мафи нэг хотынхныг ална.
//   • `PARITY_RULE = M >= T`      — мафийн тоо хотынхны тоотой тэнцмэгц мафи хожно.
//   • `TIE_BREAK = NONE`.
//
// Симуляцийн загвар — БҮРЭН ХАЙЛТ, ГЭНЭН, томьёог огт уншихгүй:
//   төлөв = (M, T), шөнийн эхэнд.
//   1. M == 0        → хотынхон аль хэдийн хожсон.
//   2. M >= T        → мафи хожсон, энэ зам бүтэлгүй.
//   3. Шөнө: T -= 1. Дараа нь дахин 2-ыг шалгана.
//   4. Өдөр, ХОЁР салаа: (а) зөв санал → M -= 1, (б) алдаатай санал → T -= 1.
//
// `_townBudget` нь хотынхон хожих БҮХ замын дундаас хамгийн олон алдаатай
// саналыг буцаана; ямар ч хожих зам байхгүй бол `null`.
//
// Нэхэмжлэл: `b₀(n, m) >= 0` бол `_townBudget == b₀`, эс бөгөөс `null`.
// **Зөрүү тэг.** Энэ бол «Тооны самбар»-ын бүх нэхэмжлэлийн цорын ганц баталгаа.

int? _townBudget(int m, int t, Map<int, int?> memo) {
  if (m == 0) return 0; // хотынхон бүх мафиг хотоос хөөсөн
  if (m >= t) return null; // мафи хожсон
  final key = m * 128 + t;
  if (memo.containsKey(key)) return memo[key];

  final afterNight = t - 1; // шөнө: мафи нэг хотынхныг ална
  int? best;
  if (m < afterNight) {
    // (а) зөв санал — нэг мафи хотоос хөөгдөнө
    final right = _townBudget(m - 1, afterNight, memo);
    if (right != null) best = right;
    // (б) алдаатай санал — нэг хотынхон хотоос хөөгдөнө
    final wrong = _townBudget(m, afterNight - 1, memo);
    if (wrong != null && (best == null || wrong + 1 > best)) best = wrong + 1;
  }
  memo[key] = best;
  return best;
}

void main() {
  group('P7 — b₀-ийн бүтэн хайлт, N = 4…60', () {
    test('томьёо ба симуляцийн зөрүү ТЭГ', () {
      final memo = <int, int?>{};
      var checked = 0;
      final mismatches = <String>[];

      for (var n = 4; n <= 60; n++) {
        for (var m = 1; m * 2 < n; m++) {
          // зөвхөн хотынхон олонх байх бүрэлдэхүүн: T = n − m > m
          final t = n - m;
          final searched = _townBudget(m, t, memo);
          final formula = b0(n, m);
          checked++;
          if (formula >= 0) {
            if (searched != formula) {
              mismatches.add('N=$n M=$m: томьёо $formula, хайлт $searched');
            }
          } else {
            if (searched != null) {
              mismatches.add('N=$n M=$m: томьёо $formula (<0), хайлт $searched');
            }
          }
        }
      }

      expect(mismatches, isEmpty, reason: mismatches.join('\n'));
      expect(checked, greaterThan(800), reason: 'хайлт бодитоор ажилласан эсэх');
    });

    test('симуляци бие даан ажиллаж байна — хяналтын гурван утга', () {
      // Хэрэв `_townBudget` зүгээр л томьёог давтаж байсан бол энэ тест
      // утгагүй болно. Тиймээс гараар бодсон гурван утгыг тавьж байна.
      expect(_townBudget(3, 9, <int, int?>{}), 2); // N=12, M=3 → b₀ = 2
      expect(_townBudget(1, 19, <int, int?>{}), 8); // N=20, M=1 → b₀ = 8
      expect(_townBudget(2, 4, <int, int?>{}), 0); // N=6,  M=2 → b₀ = 0
    });

    test('хотынхон олонх боловч хожиж чадахгүй тохиолдол (N = 2M+1)', () {
      // T = M + 1 — олонх, гэвч эхний үүрээр M >= T болно.
      for (var m = 1; m <= 25; m++) {
        final n = 2 * m + 1;
        expect(b0(n, m), -1, reason: 'N=$n M=$m');
        expect(_townBudget(m, n - m, <int, int?>{}), isNull, reason: 'N=$n M=$m');
      }
    });
  });

  group('b₀ ба pipsForDay', () {
    test('b₀ = ⌊N/2⌋ − M − 1', () {
      expect(b0(12, 3), 2);
      expect(b0(10, 2), 2);
      expect(b0(20, 5), 4);
      expect(b0(8, 4), -1);
    });

    test('pipsForDay нь өдөр тутам нэгээр буурна', () {
      expect(pipsForDay(12, 3, 1), 2);
      expect(pipsForDay(12, 3, 2), 1); // GDD-05 §11-ийн жишээ
      expect(pipsForDay(12, 3, 3), 0);
      expect(pipsForDay(12, 3, 4), -1);
    });

    test('N16 — pipsForDay нь дүрийг уншихгүй, зөвхөн гурван бүхэл тоо', () {
      // Гарын үсгийн шалгалт нь компайлын үед болно: доорх `Function` төрөл
      // `Map<Seat, Role>`-ыг АГУУЛААГҮЙ. Хэрэв хэн нэг нь `roleBySeat` нэмвэл
      // энэ хуваарилалт компайл болохоо болино.
      const int Function(int, int, int) sig = pipsForDay;
      expect(sig(12, 3, 2), 1);
    });
  });

  group('Бүрэлдэхүүний хүснэгт — GDD-04 §2, N = 6…20', () {
    test('kMinSeats ба kMaxSeats', () {
      expect(kMinSeats, 6);
      expect(kMaxSeats, 20);
    });

    for (var n = kMinSeats; n <= kMaxSeats; n++) {
      test('N = $n мөр бүрэн бөгөөд зөв', () {
        final r = rosterFor(n);
        expect(r.n, n);

        // Суудлын нийлбэр яг N.
        expect(
          r.mafia + (r.doctor ? 1 : 0) + (r.detective ? 1 : 0) + r.citizens,
          n,
          reason: 'суудлын нийлбэр',
        );

        // Хөзрийн багцын урт нь N.
        final deck = deckFor(r);
        expect(deck.length, n, reason: 'хөзрийн багцын урт');

        // Мафийн тоо таарна.
        final mafiaInDeck =
            deck.where((role) => factionOf(role) == Faction.mafi).length;
        expect(mafiaInDeck, r.mafia, reason: 'багц дахь мафийн тоо');

        // Ахлагч зөвхөн M >= 3 үед, бөгөөд ЯГ НЭГ.
        final bossInDeck = deck.where((role) => role == Role.boss).length;
        if (r.mafia >= 3) {
          expect(r.boss, isTrue, reason: 'M >= 3 → Ахлагч');
          expect(bossInDeck, 1);
        } else {
          expect(r.boss, isFalse, reason: 'M < 3 → Ахлагчгүй');
          expect(bossInDeck, 0);
        }

        // Ахлагч Алуурчны суудлыг ОРЛОНО, мафийн тоо нэмэгдэхгүй.
        expect(deck.where((role) => role == Role.killer).length, r.killers);
        expect(r.killers + bossInDeck, r.mafia);

        // Эмч, Мөрдөгч тус бүр яг нэг.
        expect(deck.where((role) => role == Role.doctor).length, 1);
        expect(deck.where((role) => role == Role.detective).length, 1);
        expect(deck.where((role) => role == Role.citizen).length, r.citizens);

        // Хүснэгтэд хэвлэгдсэн `b` нь томьёотой таарна.
        expect(r.b, b0(n, r.mafia), reason: 'хүснэгтийн b vs томьёо');

        // Шалгагч ногоон.
        final check = checkSetup(
          n: n,
          mafia: r.mafia,
          boss: r.boss,
          doctor: r.doctor,
          detective: r.detective,
        );
        expect(check.verdict, SetupVerdict.green, reason: 'N=$n ногоон байх ёстой');
        expect(check.code, isNull);
      });
    }

    test('Ахлагч N = 12-оос эхэлнэ', () {
      for (var n = kMinSeats; n < 12; n++) {
        expect(rosterFor(n).boss, isFalse, reason: 'N=$n');
      }
      for (var n = 12; n <= kMaxSeats; n++) {
        expect(rosterFor(n).boss, isTrue, reason: 'N=$n');
      }
    });

    test('хүснэгтийн M багана GDD-04 §2-той үг үсгээр таарна', () {
      const expected = <int, int>{
        6: 1, 7: 1, 8: 2, 9: 2, 10: 2, 11: 2, 12: 3, 13: 3,
        14: 4, 15: 4, 16: 4, 17: 4, 18: 5, 19: 5, 20: 5,
      };
      for (final e in expected.entries) {
        expect(rosterFor(e.key).mafia, e.value, reason: 'N=${e.key}');
      }
    });

    test('хүснэгтийн b багана GDD-04 §2-той үг үсгээр таарна', () {
      const expected = <int, int>{
        6: 1, 7: 1, 8: 1, 9: 1, 10: 2, 11: 2, 12: 2, 13: 2,
        14: 2, 15: 2, 16: 3, 17: 3, 18: 3, 19: 3, 20: 4,
      };
      for (final e in expected.entries) {
        expect(rosterFor(e.key).b, e.value, reason: 'N=${e.key}');
      }
    });

    test('багцын дараалал тогтвортой — дахин дуудахад ижил байт', () {
      for (var n = kMinSeats; n <= kMaxSeats; n++) {
        final a = deckFor(rosterFor(n));
        final b = deckFor(rosterFor(n));
        expect(a, b);
      }
      expect(deckFor(rosterFor(12)), <Role>[
        Role.boss, Role.killer, Role.killer,
        Role.doctor, Role.detective,
        Role.citizen, Role.citizen, Role.citizen, Role.citizen,
        Role.citizen, Role.citizen, Role.citizen,
      ]);
    });

    test('хамрах хүрээнээс гадуур rosterFor нь шиднэ', () {
      expect(() => rosterFor(5), throwsArgumentError);
      expect(() => rosterFor(21), throwsArgumentError);
      expect(() => rosterFor(0), throwsArgumentError);
    });
  });

  group('checkSetup — GDD-04 §3.1-ийн шийдвэрийн дүрэм', () {
    SetupCheck run(int n, int m, {bool boss = false, bool night0Kill = false}) =>
        checkSetup(
          n: n,
          mafia: m,
          boss: boss,
          doctor: true,
          detective: true,
          night0Kill: night0Kill,
        );

    test('N < kMinSeats → татгалзал', () {
      for (var n = 0; n < kMinSeats; n++) {
        final c = run(n, 1);
        expect(c.verdict, SetupVerdict.reject, reason: 'N=$n');
        expect(c.code, kCodeSeatsTooFew);
      }
      expect(run(5, 1).messageMn, 'Зургаан хүнээс доош ширээнд мафи тоглоом болохгүй.');
    });

    test('N > kMaxSeats → татгалзал', () {
      for (var n = kMaxSeats + 1; n <= 30; n++) {
        final c = run(n, 5);
        expect(c.verdict, SetupVerdict.reject, reason: 'N=$n');
        expect(c.code, kCodeSeatsTooMany);
      }
    });

    test('M < 1 → татгалзал, мафигүй тоглоом байхгүй', () {
      final c = run(12, 0);
      expect(c.verdict, SetupVerdict.reject);
      expect(c.code, kCodeNoMafia);
    });

    test('Ахлагч M < 3 үед татгалзана', () {
      for (var m = 1; m <= 2; m++) {
        final c = run(12, m, boss: true);
        expect(c.verdict, SetupVerdict.reject, reason: 'M=$m');
        expect(c.code, kCodeBossNeedsThree);
      }
      expect(run(12, 3, boss: true).verdict, SetupVerdict.green);
    });

    test('b < 0 → ҮРГЭЛЖ хатуу татгалзал, гарц байхгүй (GDD-04 §3.2)', () {
      // GDD-04 §3.2-ын тестийн хэлбэрийг үг үсгээр давтав.
      for (var n = 4; n <= 22; n++) {
        if (n < kMinSeats || n > kMaxSeats) {
          expect(run(n, 1).verdict, SetupVerdict.reject, reason: 'N=$n');
          continue;
        }
        for (var m = 1; m <= n; m++) {
          if (b0(n, m) < 0) {
            final c = run(n, m);
            expect(c.verdict, SetupVerdict.reject, reason: 'N=$n M=$m');
            expect(c.code, kCodeBudgetNegative, reason: 'N=$n M=$m');
          }
        }
      }
    });

    test('b < 0 -ийн мөр нь GDD-04-ийн текст үг үсгээрээ', () {
      expect(
        run(8, 4).messageMn,
        'Энэ бүрэлдэхүүнээр мафи эхний шөнөдөө яллаа. Тоглогч нэм эсвэл мафи хас.',
      );
    });

    test('b == 0 → анхааруулга, гарцтай (GDD-04 §3.3)', () {
      for (var n = kMinSeats; n <= kMaxSeats; n++) {
        for (var m = 1; m <= n; m++) {
          if (b0(n, m) == 0 && !(m < 1)) {
            final c = run(n, m);
            expect(c.verdict, SetupVerdict.warn, reason: 'N=$n M=$m');
            expect(c.code, kCodeBudgetZero, reason: 'N=$n M=$m');
          }
        }
      }
      expect(run(6, 2).code, kCodeBudgetZero);
      expect(
        run(6, 2).messageMn,
        'Алдаж болох санал байхгүй. Эхний өдрөөс онох ёстой.',
      );
    });

    test('b >= 5 → анхааруулга, тоглоом сунжирна', () {
      expect(b0(20, 4), 5);
      final c = run(20, 4);
      expect(c.verdict, SetupVerdict.warn);
      expect(c.code, kCodeBudgetLong);
    });

    test('night0Kill нь төсвийг нэгээр бууруулна (GDD-03 §7-ын онцгой тохиолдол)', () {
      // N = 6, M = 2: b₀ = 0 → анхааруулга. night0Kill-тэй бол b = −1 → татгалзал.
      expect(run(6, 2).code, kCodeBudgetZero);
      expect(run(6, 2, night0Kill: true).verdict, SetupVerdict.reject);
      expect(run(6, 2, night0Kill: true).code, kCodeBudgetNegative);

      // N = 12, M = 3: b₀ = 2 → ногоон. night0Kill-тэй бол b = 1 → ногоон хэвээр.
      expect(run(12, 3, boss: true).verdict, SetupVerdict.green);
      expect(run(12, 3, boss: true, night0Kill: true).verdict, SetupVerdict.green);

      // N = 10, M = 2: b₀ = 2 → ногоон. night0Kill-тэй бол b = 1 → ногоон.
      expect(run(10, 2, night0Kill: true).verdict, SetupVerdict.green);

      // b₀ = 1 бүхий мөр night0Kill-тэй бол b = 0 → анхааруулга.
      expect(run(8, 2).verdict, SetupVerdict.green);
      expect(run(8, 2, night0Kill: true).code, kCodeBudgetZero);
    });

    test('N хязгаарын шалгалт нь b-ийн шалгалтаас ДЭЭГҮҮР', () {
      // N = 4, M = 1 дээр b₀ = 0 боловч шал нь 6 тул татгалзана.
      expect(b0(4, 1), 0);
      expect(run(4, 1).code, kCodeSeatsTooFew);
    });

    test('ногоон үед код байхгүй', () {
      final c = run(12, 3, boss: true);
      expect(c.code, isNull);
      expect(c.isGreen, isTrue);
      expect(c.isReject, isFalse);
      expect(c.messageMn, isNotEmpty);
    });
  });
}
