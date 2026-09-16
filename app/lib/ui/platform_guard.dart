// Дэлгэцийн хамгаалалт — GDD-10 §5, GDD-08 §8.
//
// Хоёр зүйл, хоёулаа ГАР УТАСНЫ шаардлага:
//   1. `FLAG_SECURE` — дүр харагдах үед дэлгэцийн зураг авахыг хориглоно.
//      Google-ийн өөрийн баримтаар API ≤ 30 дээр ~70% төхөөрөмж дээр л
//      найдвартай (GDD-12 §2.4-ийн залруулга) — тиймээс энэ нь хамгаалалтын
//      цорын ганц давхарга БИШ, зөвхөн нэг давхарга.
//   2. `KEEP_SCREEN_ON` — утас ширээн дунд байх үед унтрахгүй байх.
//      Android Vitals нь 24 цагт 2 цагаас дээш wake lock-ыг «хэтэрхий их»
//      гэж тэмдэглэдэг тул ЗӨВХӨН тоглолтын үед асаана.
//
// Веб дээр хоёулаа хоосон үйлдэл. Нэмэлт пакет ШААРДЛАГАГҮЙ — MethodChannel.

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

abstract final class PlatformGuard {
  static const MethodChannel _ch = MethodChannel('mn.hotuntlaa/guard');

  static bool _secure = false;
  static bool _awake = false;

  static Future<void> setSecure(bool on) async {
    if (kIsWeb || _secure == on) return;
    _secure = on;
    try {
      await _ch.invokeMethod<void>('setSecure', <String, bool>{'on': on});
    } on PlatformException {
      // Тавцан дэмжихгүй бол чимээгүй өнгөрнө — дэлгэц ажиллахаа болихгүй.
    } on MissingPluginException {
      // Тест ба веб.
    }
  }

  static Future<void> setKeepAwake(bool on) async {
    if (kIsWeb || _awake == on) return;
    _awake = on;
    try {
      await _ch.invokeMethod<void>('setKeepAwake', <String, bool>{'on': on});
    } on PlatformException {
      // дэмжихгүй
    } on MissingPluginException {
      // тест
    }
  }

  @visibleForTesting
  static void resetForTest() {
    _secure = false;
    _awake = false;
  }
}
