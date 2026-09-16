// Дизайны токенууд — GDD-08 §7.
//
// ЭНЭ БОЛ ГЭРЭЭ. Дэлгэц өөрөө өнгө, зай, хугацаа зохиохгүй — эндээс авна.
//
// ГАР УТАСНЫ ХАТУУ ХЯЗГААР (GDD-08 §8, GDD-13 D1 = Redmi 9A):
//   • Зорилтот өргөн 360 логик px. 320-д ч эвдрэхгүй байх ёстой.
//   • Хүрэх талбай ХЭЗЭЭ Ч 48dp-ээс бага биш.
//   • Үндсэн үйлдэл дэлгэцийн ДООД гуравны нэгд — нэг гарын эрхий тэнд хүрнэ.
//   • Биеийн текст ≥ 16sp, мөрийн өндөр ≥ 1.45 (кирилл нягт бичигддэг).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ---------------------------------------------------------------------------
// Өнгө — «Улаанбаатар ноар» (GDD-08 §7.4). Контраст харьцаа хэмжигдсэн.
// ---------------------------------------------------------------------------

/// Суурь. AMOLED дээр батерей хэмнэнэ, шөнийн ширээнд нүд гялбуулахгүй.
const Color kSurface = Color(0xFF0E1A2B);
const Color kSurfaceRaised = Color(0xFF16263C);
const Color kSurfaceHigh = Color(0xFF1F3350);

/// Үндсэн өнгө. #EAF0F7 дээр 6.97:1.
const Color kEmber = Color(0xFFF08A2B);

/// Текст. Суурин дээр 15.24:1.
const Color kTextPrimary = Color(0xFFEAF0F7);
const Color kTextMuted = Color(0xFF9DB0C6);

/// Аюул. 4.52:1 — ЗӨВХӨН ≥18sp bold дээр (GDD-08 §7.4).
const Color kDanger = Color(0xFFD55E00);
const Color kOk = Color(0xFF009E73);

/// Шөнө. Дэлгэц ширээн дунд, бараг хар.
const Color kNight = Color(0xFF050B14);

const Color kHairline = Color(0x22FFFFFF);

// ---------------------------------------------------------------------------
// Зай ба хэмжээ
// ---------------------------------------------------------------------------

const double kGutter = 20;
const double kGap = 12;
const double kRadius = 14;

/// Material-ийн доод хязгаар. Үүнээс бага товч ХЭЗЭЭ Ч байхгүй.
const double kMinTouch = 48;

/// Үндсэн товчны өндөр — эрхий хуруунд тохирсон.
const double kPrimaryButtonHeight = 60;

/// Суудлын дугаарын товч. 12 суудал 360px-д гурван баганаар багтана.
const double kSeatTile = 96;

// ---------------------------------------------------------------------------
// Үсэг
// ---------------------------------------------------------------------------

const TextStyle kDisplay = TextStyle(
    fontSize: 34, fontWeight: FontWeight.w700, letterSpacing: 1.5, height: 1.2);
const TextStyle kTitle =
    TextStyle(fontSize: 22, fontWeight: FontWeight.w700, height: 1.3);
const TextStyle kBody = TextStyle(fontSize: 16, height: 1.45);
const TextStyle kLabel = TextStyle(
    fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 1.1, height: 1.4);

/// Суудлын дугаар — ширээний нөгөө талаас уншигдах ёстой.
const TextStyle kSeatNumber =
    TextStyle(fontSize: 64, fontWeight: FontWeight.w700, height: 1.0);

// ---------------------------------------------------------------------------
// Хөдөлгөөн (GDD-08 §7.3)
// ---------------------------------------------------------------------------

const Duration kFast = Duration(milliseconds: 120);
const Duration kMedium = Duration(milliseconds: 240);

/// Хөзөр эргэх. GDD-06 S06-д тогтсон.
const Duration kCardFlip = Duration(milliseconds: 400);

/// Дараад барих босго — санамсаргүй хүрэлтээс хамгаална.
const Duration kHoldThreshold = Duration(milliseconds: 220);

/// Хөзөр өөрөө нуугдах хүртэл. GDD-15-аар 8 сек → 2.5 сек болж зассан:
/// 30 см-т сууж байгаа хөрш 8 секундэд уншиж чадна.
const Duration kCardAutoHide = Duration(milliseconds: 2500);

/// Тавимагц алга болох. Үүнээс удаан бол алдагдал.
const Duration kCardHide = Duration(milliseconds: 100);

/// Дамжуулах хаалт — алгасах боломжгүй.
const Duration kHandoffLock = Duration(milliseconds: 600);

/// ЭДГЭЭР НЬ ХӨДӨЛГҮҮРЭЭС ГАРНА, энд давтагдахгүй:
/// үүрийн 2500 мс чимээгүй нь `NightReport.cues` дотор ирнэ (инвариант N14).

// ---------------------------------------------------------------------------
// Чичиргээ (GDD-08 §7.2)
// ---------------------------------------------------------------------------

/// ХАТУУ ДҮРЭМ: дамжуулах ба нуух дэлгэц дээр чичиргээ ХОРИОТОЙ —
/// буруу гарт мэдрэгдсэн чичиргээ бол мэдээлэл алдагдуулах суваг.
abstract final class Haptic {
  /// Шөнийн эргэлтийн батлалт. Суудал бүрт ЯГ ИЖИЛ.
  static void confirm() => HapticFeedback.selectionClick();

  /// Хасалт ба b = 0 — тоглолтод цөөхөн удаа.
  static void heavy() => HapticFeedback.mediumImpact();
}

// ---------------------------------------------------------------------------
// Сэдэв
// ---------------------------------------------------------------------------

ThemeData buildTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: kSurface,
    colorScheme: const ColorScheme.dark(
      surface: kSurface,
      primary: kEmber,
      onPrimary: kSurface,
      error: kDanger,
    ),
    sliderTheme: const SliderThemeData(
      activeTrackColor: kEmber,
      thumbColor: kEmber,
      inactiveTrackColor: kSurfaceHigh,
    ),
    textTheme: const TextTheme(
      displayLarge: kDisplay,
      titleLarge: kTitle,
      bodyMedium: kBody,
      labelSmall: kLabel,
    ).apply(bodyColor: kTextPrimary, displayColor: kTextPrimary),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: kEmber,
        foregroundColor: kSurface,
        minimumSize: const Size.fromHeight(kPrimaryButtonHeight),
        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(kRadius)),
      ),
    ),
  );
}
