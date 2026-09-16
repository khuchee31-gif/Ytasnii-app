// Дүрийн зургийн сан.
//
// ЧУХАЛ: дүрийн зураг нь ТОГЛООМЫН ДҮРТЭЙ ЯМАР Ч ХОЛБООГҮЙ. Хүн өөрийн
// дуртайгаа сонгоно; алуурчин ч, эмч ч ижил зурагтай байж болно. Хэрэв
// зураг дүрийг илтгэвэл тоглоом тэр дор нь үхнэ.
//
// Зургууд `tools/genart.py`-аар үүсдэг. Дэвсгэр нь ХАР (rembg-ээр тасалсан)
// тул харанхуй өрөөнд төгс уусна.

import 'dart:ui' as ui;

import 'package:flutter/services.dart';

/// Боломжит дүрүүдийн жагсаалт.
///
/// Тоо нь суудлын дээд хязгаараас (14) ИХ байх ёстой — эс бөгөөс хоёр хүн
/// ижил дүртэй болж, ширээн дээр хэн хэн болох нь ойлгомжгүй болно.
const List<String> kAvatarIds = <String>[
  'seat01',
  'seat02',
  'seat03',
  'seat04',
  'seat05',
  'seat06',
  'seat07',
  'seat08',
  'seat09',
  'seat10',
  'seat11',
  'seat12',
];

String avatarPath(String id) => 'assets/art/seats/$id.jpg';

/// Дүрийн зургийн кэш.
///
/// Нэг зураг олон дэлгэцэд хэрэглэгдэнэ. Дахин ачаалвал Redmi 9A-ийн 2 ГБ
/// санах ой хурдан дүүрнэ — тиймээс НЭГ УДАА ачаалж, хуваалцана.
class AvatarCache {
  AvatarCache._();

  static final AvatarCache instance = AvatarCache._();

  final Map<String, ui.Image> _images = <String, ui.Image>{};
  final Map<String, Future<ui.Image>> _pending = <String, Future<ui.Image>>{};

  ui.Image? peek(String id) => _images[id];

  Future<ui.Image> load(String id) {
    final ui.Image? got = _images[id];
    if (got != null) return Future<ui.Image>.value(got);
    return _pending[id] ??= _decode(id);
  }

  /// Хэрэгтэй бүх дүрийг зэрэг ачаална.
  Future<void> preload(Iterable<String> ids) async {
    await Future.wait<ui.Image>(ids.toSet().map(load));
  }

  Future<ui.Image> _decode(String id) async {
    final ByteData data = await rootBundle.load(avatarPath(id));
    final ui.Codec codec = await ui.instantiateImageCodec(
      data.buffer.asUint8List(),
    );
    final ui.FrameInfo frame = await codec.getNextFrame();
    _images[id] = frame.image;
    _pending.remove(id);
    return frame.image;
  }

  /// Тестэд кэшийг цэвэрлэх.
  void clear() {
    for (final ui.Image i in _images.values) {
      i.dispose();
    }
    _images.clear();
    _pending.clear();
  }
}
