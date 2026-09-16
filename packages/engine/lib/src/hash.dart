// «Хот унтлаа» — SHA-256, цэвэр Dart-аар.
//
// Эх сурвалж: GDD-05 §7, GDD-10 §2. Гуравдагч талын багц ХЭРЭГЛЭХГҮЙ —
// хөдөлгүүр нь `flutter`-гүй, `dart:io`-гүй, хамааралгүй байх ёстой.
//
// ХАТУУ ДҮРЭМ (GDD-05 §0): IO байхгүй, `DateTime.now()` байхгүй,
// `Random()` байхгүй, `double` байхгүй. Бүх арифметик нь 32 битийн маскаар.

import 'dart:typed_data';

/// FIPS 180-4-ийн 64 дугуйн тогтмолууд (эхний 64 анхны тооны кубын язгуурын
/// бутархай хэсгийн эхний 32 бит).
const List<int> _k = <int>[
  0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, //
  0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
  0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3,
  0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
  0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc,
  0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
  0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7,
  0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
  0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13,
  0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
  0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3,
  0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
  0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5,
  0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
  0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208,
  0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
];

const int _mask32 = 0xFFFFFFFF;

/// 32 битийн баруун эргэлт. `x` нь ЗААВАЛ 0..2^32−1 дотор байна.
int _rotr32(int x, int n) => ((x >> n) | (x << (32 - n))) & _mask32;

/// SHA-256. 32 байтын дайджест буцаана.
///
/// `data` нь дурын урттай байж болно; элемент бүр 0..255 гэж үзэгдэнэ
/// (`& 0xFF` хийгдэнэ, `Uint8List`-тэй ижил үр дүн).
Uint8List sha256(List<int> data) {
  final int msgLen = data.length;

  // --- Дүүргэлт: 0x80, дараа нь тэг, сүүлийн 8 байт нь битийн урт (big-endian).
  final int padded = ((msgLen + 9 + 63) ~/ 64) * 64;
  final Uint8List m = Uint8List(padded);
  for (int i = 0; i < msgLen; i++) {
    m[i] = data[i] & 0xFF;
  }
  m[msgLen] = 0x80;
  final int bitLen = msgLen * 8;
  for (int i = 0; i < 8; i++) {
    m[padded - 1 - i] = (bitLen >> (8 * i)) & 0xFF;
  }

  int h0 = 0x6a09e667;
  int h1 = 0xbb67ae85;
  int h2 = 0x3c6ef372;
  int h3 = 0xa54ff53a;
  int h4 = 0x510e527f;
  int h5 = 0x9b05688c;
  int h6 = 0x1f83d9ab;
  int h7 = 0x5be0cd19;

  final Int32List w = Int32List(64); // 32 бит, тэмдэгтэй — доор маскаар уншина.

  for (int off = 0; off < padded; off += 64) {
    for (int t = 0; t < 16; t++) {
      final int j = off + t * 4;
      w[t] = (m[j] << 24) | (m[j + 1] << 16) | (m[j + 2] << 8) | m[j + 3];
    }
    for (int t = 16; t < 64; t++) {
      final int w15 = w[t - 15] & _mask32;
      final int w2 = w[t - 2] & _mask32;
      final int s0 = _rotr32(w15, 7) ^ _rotr32(w15, 18) ^ (w15 >> 3);
      final int s1 = _rotr32(w2, 17) ^ _rotr32(w2, 19) ^ (w2 >> 10);
      w[t] = ((w[t - 16] & _mask32) + s0 + (w[t - 7] & _mask32) + s1) & _mask32;
    }

    int a = h0;
    int b = h1;
    int c = h2;
    int d = h3;
    int e = h4;
    int f = h5;
    int g = h6;
    int h = h7;

    for (int t = 0; t < 64; t++) {
      final int s1 = _rotr32(e, 6) ^ _rotr32(e, 11) ^ _rotr32(e, 25);
      final int ch = (e & f) ^ ((~e & _mask32) & g);
      final int t1 = (h + s1 + ch + _k[t] + (w[t] & _mask32)) & _mask32;
      final int s0 = _rotr32(a, 2) ^ _rotr32(a, 13) ^ _rotr32(a, 22);
      final int maj = (a & b) ^ (a & c) ^ (b & c);
      final int t2 = (s0 + maj) & _mask32;
      h = g;
      g = f;
      f = e;
      e = (d + t1) & _mask32;
      d = c;
      c = b;
      b = a;
      a = (t1 + t2) & _mask32;
    }

    h0 = (h0 + a) & _mask32;
    h1 = (h1 + b) & _mask32;
    h2 = (h2 + c) & _mask32;
    h3 = (h3 + d) & _mask32;
    h4 = (h4 + e) & _mask32;
    h5 = (h5 + f) & _mask32;
    h6 = (h6 + g) & _mask32;
    h7 = (h7 + h) & _mask32;
  }

  final Uint8List out = Uint8List(32);
  final List<int> hs = <int>[h0, h1, h2, h3, h4, h5, h6, h7];
  for (int i = 0; i < 8; i++) {
    out[i * 4] = (hs[i] >> 24) & 0xFF;
    out[i * 4 + 1] = (hs[i] >> 16) & 0xFF;
    out[i * 4 + 2] = (hs[i] >> 8) & 0xFF;
    out[i * 4 + 3] = hs[i] & 0xFF;
  }
  return out;
}

const String _hexDigits = '0123456789abcdef';

/// Байтуудыг ЖИЖИГ үсгийн hex болгоно. Детерминист, локалиас хамаарахгүй.
String hex(List<int> bytes) {
  final StringBuffer sb = StringBuffer();
  for (final int b in bytes) {
    final int v = b & 0xFF;
    sb.writeCharCode(_hexDigits.codeUnitAt((v >> 4) & 0x0F));
    sb.writeCharCode(_hexDigits.codeUnitAt(v & 0x0F));
  }
  return sb.toString();
}

/// `hex(sha256(data))` — 64 тэмдэгтийн мөр.
String sha256Hex(List<int> data) => hex(sha256(data));
