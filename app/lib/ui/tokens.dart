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

/// Суурь — бараг хар. AMOLED дээр пиксел унтарна, ширээн дунд нүд гялбуулахгүй.
/// Material-ийн «цэнхэрдүү саарал» биш: энэ бол ШӨНӨ.
const Color kSurface = Color(0xFF0A0A0B);
const Color kSurfaceRaised = Color(0xFF131315);
const Color kSurfaceHigh = Color(0xFF1C1C1F);

/// Зэв — цорын ганц дулаан өнгө. Хэт олон газар хэрэглэвэл хүчээ алдана.
const Color kRust = Color(0xFFC1440E);
const Color kEmber = kRust;

/// Хүйтэн ногоон — мөрдөгчийн хариу, батлагдсан зүйл.
const Color kCold = Color(0xFF4A7C74);

/// Яс — цаасан цагаан, цэвэр цагаан биш. Нүдэнд зөөлөн, хэвлэмэл мэдрэмжтэй.
const Color kBone = Color(0xFFE8E4DA);
const Color kTextPrimary = kBone;
const Color kTextMuted = Color(0xFF8A867E);

/// Цус — зөвхөн хасалт ба `b = 0`. Тоглолтод хэдхэн удаа л гарна.
const Color kDanger = Color(0xFF8E1F0B);
const Color kOk = kCold;

/// Шөнө. Утас ширээн дунд, бүрэн хар.
const Color kNight = Color(0xFF000000);

const Color kHairline = Color(0x1AE8E4DA);

// ---------------------------------------------------------------------------
// Зай ба хэмжээ
// ---------------------------------------------------------------------------

const double kGutter = 20;
const double kGap = 12;
const double kRadius = 3;

/// Material-ийн доод хязгаар. Үүнээс бага товч ХЭЗЭЭ Ч байхгүй.
const double kMinTouch = 48;

/// Үндсэн товчны өндөр — эрхий хуруунд тохирсон.
const double kPrimaryButtonHeight = 60;

/// Суудлын дугаарын товч. 12 суудал 360px-д гурван баганаар багтана.
const double kSeatTile = 96;

// ---------------------------------------------------------------------------
// Үсэг
// ---------------------------------------------------------------------------

/// Гарчиг — Oswald. Шахмал, өндөр, шөнийн зурагт хуудас шиг.
const String kDisplayFont = 'Oswald';

/// Бие — Rubik. Кирилл дээр цэвэр, жижиг хэмжээнд уншигдана.
const String kBodyFont = 'Rubik';

const TextStyle kDisplay = TextStyle(
  fontFamily: kDisplayFont,
  fontSize: 40,
  fontWeight: FontWeight.w700,
  letterSpacing: 4,
  height: 1.05,
);
const TextStyle kTitle = TextStyle(
  fontFamily: kDisplayFont,
  fontSize: 26,
  fontWeight: FontWeight.w700,
  letterSpacing: 1.6,
  height: 1.2,
);
const TextStyle kBody = TextStyle(
  fontFamily: kBodyFont,
  fontSize: 16,
  height: 1.5,
);
const TextStyle kLabel = TextStyle(
  fontFamily: kDisplayFont,
  fontSize: 13,
  fontWeight: FontWeight.w500,
  letterSpacing: 2.4,
  height: 1.4,
);

/// Суудлын дугаар — ширээний нөгөө талаас уншигдах ёстой.
const TextStyle kSeatNumber = TextStyle(
  fontFamily: kDisplayFont,
  fontSize: 72,
  fontWeight: FontWeight.w700,
  height: 1.0,
);

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
    fontFamily: kBodyFont,
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
        textStyle: const TextStyle(
          fontFamily: kDisplayFont,
          fontSize: 19,
          fontWeight: FontWeight.w700,
          letterSpacing: 2.2,
        ),
        // Дугуй биш. Дугуйлсан булан нь «апп», шулуун булан нь «эд зүйл».
        shape: const RoundedRectangleBorder(),
      ),
    ),
  );
}
