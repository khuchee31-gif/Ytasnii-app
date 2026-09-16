// Дууны хүрээ — хоёртын формат ба кодлогч.
//
// ЯАГААД ӨӨРСДӨӨ БИЧСЭН БЭ:
//
// Эхлээд LiveKit / WebRTC-г бодсон. Godot-ийн албан ёсны WebRTC өргөтгөл
// (`godotengine/webrtc-native` 1.2.1) нь ЗӨВХӨН өгөгдлийн суваг өгдөг —
// дуу, дүрсний зам байхгүй. Өөрөөр хэлбэл ямар ч тохиолдолд кодлогчийг
// өөрсдөө хийх шаардлагатай. Godot-ийн цөмд Opus кодлогч БАЙХГҮЙ
// (зөвхөн тайлагч). Тиймээс:
//
//   G.711 μ-law, 8 кГц, моно = 64 кбит/с.
//
// Энэ бол утасны чанар. Мафи тоглоомд ХӨГЖИМ сонсохгүй — хүний өнгө,
// эргэлзээ, түр зогсолтыг л сонсоно. Түүнд 8 кГц бүрэн хангалттай.
// Хариуд нь: гуравдагч талын хоёртын сан хэрэггүй, APK-д 0 байт нэмнэ,
// Redmi 9A дээр кодлох нь дээж тутам хоёр үйлдэл.
//
// ХАМГИЙН ЧУХАЛ: сувагт байхгүй хүн рүү сервер дууны хүрээ ОГТ
// илгээхгүй. Таслах, чагнахыг хориглох биш — ПАКЕТ ӨӨРӨӨ хүрэхгүй.
// Тиймээс өөрчилсөн апп ч сонсох юмгүй.

import 'dart:typed_data';

/// Дээж авалтын давтамж (Гц).
const int kVoiceRate = 8000;

/// Нэг хүрээний урт (мс).
const int kVoiceFrameMs = 20;

/// Нэг хүрээн дэх дээжийн тоо.
const int kVoiceSamples = kVoiceRate * kVoiceFrameMs ~/ 1000;

/// Хоёртын хүрээний эхний байт — «энэ бол дуу».
///
/// Ирээдүйд өөр төрлийн хоёртын хүрээ нэмэгдэж болзошгүй тул шошготой.
const int kVoiceTag = 0x01;

/// G.711 μ-law кодлогч.
abstract final class MuLaw {
  static const int _bias = 0x84;
  static const int _clip = 32635;

  /// PCM16 → нэг байт.
  static int encode(int pcm) {
    int sign = 0;
    int v = pcm;
    if (v < 0) {
      sign = 0x80;
      v = -v;
    }
    if (v > _clip) v = _clip;
    v += _bias;
    // Илтгэгч нь өндөр байрлалын битийн байр. Хүснэгт бичихийн оронд
    // битийн уртаар бодно — ижил үр дүн, алдах зүйлгүй.
    final int idx = (v >> 7) & 0xFF;
    final int exponent = idx == 0 ? 0 : idx.bitLength - 1;
    final int mantissa = (v >> (exponent + 3)) & 0x0F;
    return ~(sign | (exponent << 4) | mantissa) & 0xFF;
  }

  /// Нэг байт → PCM16.
  static int decode(int law) {
    final int u = ~law & 0xFF;
    final int sign = u & 0x80;
    final int exponent = (u >> 4) & 0x07;
    final int mantissa = u & 0x0F;
    int sample = (((mantissa << 3) + _bias) << exponent) - _bias;
    if (sign != 0) sample = -sample;
    return sample;
  }

  static Uint8List encodeAll(Int16List pcm) {
    final Uint8List out = Uint8List(pcm.length);
    for (int i = 0; i < pcm.length; i++) {
      out[i] = encode(pcm[i]);
    }
    return out;
  }

  static Int16List decodeAll(Uint8List law) {
    final Int16List out = Int16List(law.length);
    for (int i = 0; i < law.length; i++) {
      out[i] = decode(law[i]);
    }
    return out;
  }
}

/// Нэг дууны хүрээ.
///
/// Апп → сервер:  `[tag][seq lo][seq hi][μ-law…]`
/// Сервер → апп:  `[tag][seq lo][seq hi][seat][μ-law…]`
///
/// Суудлын дугаар нь ЗӨВХӨН буцах чиглэлд байна: сонсогч хэн ярьж
/// байгааг мэдэх ёстой (ширээн дээр тэр хүн гэрэлтэнэ). Энэ нь нууцыг
/// задрахгүй — өөрийн сувгийн гишүүдийг сонсох эрхтэй хүн тэднийг
/// аль хэдийн мэднэ.
class VoiceFrame {
  const VoiceFrame({required this.seq, required this.audio, this.seat = 0});

  final int seq;
  final int seat;
  final Uint8List audio;

  /// Апп → сервер.
  Uint8List encodeUp() {
    final Uint8List b = Uint8List(3 + audio.length);
    b[0] = kVoiceTag;
    b[1] = seq & 0xFF;
    b[2] = (seq >> 8) & 0xFF;
    b.setRange(3, b.length, audio);
    return b;
  }

  /// Сервер → апп.
  Uint8List encodeDown() {
    final Uint8List b = Uint8List(4 + audio.length);
    b[0] = kVoiceTag;
    b[1] = seq & 0xFF;
    b[2] = (seq >> 8) & 0xFF;
    b[3] = seat & 0xFF;
    b.setRange(4, b.length, audio);
    return b;
  }

  /// Апп → серверийн хүрээг задална. Гажсан бол `null` — сервер унахгүй.
  /// Сүлжээнээс ирсэн ямар ч байт ИТГЭЛГҮЙ.
  static VoiceFrame? decodeUp(List<int> bytes) {
    if (bytes.length < 4 || bytes[0] != kVoiceTag) return null;
    final int payload = bytes.length - 3;
    // Хэт урт хүрээ — санах ой цохих оролдлого байж болно.
    if (payload > kVoiceSamples * 4) return null;
    return VoiceFrame(
      seq: bytes[1] | (bytes[2] << 8),
      audio: Uint8List.fromList(bytes.sublist(3)),
    );
  }

  static VoiceFrame? decodeDown(List<int> bytes) {
    if (bytes.length < 5 || bytes[0] != kVoiceTag) return null;
    final int payload = bytes.length - 4;
    if (payload > kVoiceSamples * 4) return null;
    return VoiceFrame(
      seq: bytes[1] | (bytes[2] << 8),
      seat: bytes[3],
      audio: Uint8List.fromList(bytes.sublist(4)),
    );
  }
}
