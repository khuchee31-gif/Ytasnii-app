// «Хот унтлаа» — ChaCha20 урсгал ба хазайлтгүй санамсаргүй тоо.
//
// Эх сурвалж: GDD-05 §7.2, GDD-10 §2. Алгоритмыг GDD-10 эзэмшинэ.
//
// Яагаад ChaCha20, splitmix64 биш: 20 суудлын сэлгэмэл нь 20! ≈ 62 бит —
// 64 битийн төлөвт нүцгэн багтана. 256 битийн түлхүүр нь төлвийг хэзээ ч
// хязгаарлагч болгохгүй (GDD-05 §7.2).
//
// ХАТУУ ДҮРЭМ: `double` байхгүй, `Random()` байхгүй, бүх арифметик 32 битийн
// маскаар. RFC 8439 §2.3.2 ба §2.4.2-ын вектороор тестлэгдэнэ.

import 'dart:convert';
import 'dart:typed_data';

import 'hash.dart';

const int _mask32 = 0xFFFFFFFF;

/// "expand 32-byte k" — ChaCha20-ийн тогтмол үгс.
const List<int> _sigma = <int>[0x61707865, 0x3320646e, 0x79622d32, 0x6b206574];

int _rotl32(int x, int n) => ((x << n) | (x >> (32 - n))) & _mask32;

void _quarterRound(Int32List x, int a, int b, int c, int d) {
  int xa = x[a] & _mask32;
  int xb = x[b] & _mask32;
  int xc = x[c] & _mask32;
  int xd = x[d] & _mask32;

  xa = (xa + xb) & _mask32;
  xd = _rotl32(xd ^ xa, 16);
  xc = (xc + xd) & _mask32;
  xb = _rotl32(xb ^ xc, 12);
  xa = (xa + xb) & _mask32;
  xd = _rotl32(xd ^ xa, 8);
  xc = (xc + xd) & _mask32;
  xb = _rotl32(xb ^ xc, 7);

  x[a] = xa;
  x[b] = xb;
  x[c] = xc;
  x[d] = xd;
}

int _le32(List<int> b, int i) =>
    (b[i] & 0xFF) |
    ((b[i + 1] & 0xFF) << 8) |
    ((b[i + 2] & 0xFF) << 16) |
    ((b[i + 3] & 0xFF) << 24);

/// ChaCha20-ийн НЭГ блок (64 байт), RFC 8439 §2.3.
///
/// `key32` — 32 байт, `nonce12` — 12 байт, `counter` — блокийн дугаар.
/// Энэ функц нь RFC-ийн тест вектортой шууд харьцуулагдахын тулд нээлттэй.
Uint8List chacha20Block(List<int> key32, List<int> nonce12, int counter) {
  if (key32.length != 32) {
    throw ArgumentError('chacha20: түлхүүр 32 байт байх ёстой');
  }
  if (nonce12.length != 12) {
    throw ArgumentError('chacha20: nonce 12 байт байх ёстой');
  }
  final Int32List s = Int32List(16);
  for (int i = 0; i < 4; i++) {
    s[i] = _sigma[i];
  }
  for (int i = 0; i < 8; i++) {
    s[4 + i] = _le32(key32, i * 4);
  }
  s[12] = counter & _mask32;
  for (int i = 0; i < 3; i++) {
    s[13 + i] = _le32(nonce12, i * 4);
  }

  final Int32List x = Int32List(16);
  for (int i = 0; i < 16; i++) {
    x[i] = s[i];
  }
  for (int r = 0; r < 10; r++) {
    _quarterRound(x, 0, 4, 8, 12);
    _quarterRound(x, 1, 5, 9, 13);
    _quarterRound(x, 2, 6, 10, 14);
    _quarterRound(x, 3, 7, 11, 15);
    _quarterRound(x, 0, 5, 10, 15);
    _quarterRound(x, 1, 6, 11, 12);
    _quarterRound(x, 2, 7, 8, 13);
    _quarterRound(x, 3, 4, 9, 14);
  }

  final Uint8List out = Uint8List(64);
  for (int i = 0; i < 16; i++) {
    final int w = ((x[i] & _mask32) + (s[i] & _mask32)) & _mask32;
    out[i * 4] = w & 0xFF;
    out[i * 4 + 1] = (w >> 8) & 0xFF;
    out[i * 4 + 2] = (w >> 16) & 0xFF;
    out[i * 4 + 3] = (w >> 24) & 0xFF;
  }
  return out;
}

/// ChaCha20 урсгалын шифр — RFC 8439 §2.4. `data`-г түлхүүрийн урсгалтай
/// XOR хийнэ. Зөвхөн тест векторыг шалгахад хэрэглэгдэнэ; хөдөлгүүр өөрөө
/// шифрлэлт хийхгүй.
Uint8List chacha20Xor({
  required List<int> key32,
  required List<int> nonce12,
  required int counter,
  required List<int> data,
}) {
  final Uint8List out = Uint8List(data.length);
  int block = counter;
  int i = 0;
  while (i < data.length) {
    final Uint8List ks = chacha20Block(key32, nonce12, block);
    final int take = (data.length - i) < 64 ? (data.length - i) : 64;
    for (int j = 0; j < take; j++) {
      out[i + j] = (data[i + j] & 0xFF) ^ ks[j];
    }
    i += take;
    block = (block + 1) & _mask32;
  }
  return out;
}

/// `below(bound)`-ийн ТАТГАЛЗЛЫН ХИЛ (GDD-05 §7.2, GDD-10 §2):
/// `limit = 2^32 − (2^32 mod bound)`. Үүнээс дээш гарсан татацыг хаяна —
/// нүцгэн `%` нь хазайдаг, хөвөгч цэг бүр хазайдаг.
int rejectionLimit(int bound) {
  if (bound < 1) {
    throw ArgumentError.value(bound, 'bound', 'эерэг байх ёстой');
  }
  return 0x100000000 - (0x100000000 % bound);
}

/// ChaCha20-д суурилсан детерминист RNG. `nonce = 0`, тоолуур 0-ээс.
///
/// Байтын урсгалыг 4-өөр нь уншиж big-endian u32 болгоно
/// (GDD-10 §2: `x = u32be(rng.nextBytes(4))`).
class Rng {
  Rng(List<int> key32) : _key = Uint8List.fromList(key32) {
    if (key32.length != 32) {
      throw ArgumentError('Rng: түлхүүр 32 байт байх ёстой');
    }
  }

  final Uint8List _key;
  static final Uint8List _zeroNonce = Uint8List(12);

  Uint8List _block = Uint8List(0);
  int _counter = 0;
  int _pos = 0;

  int _nextByte() {
    if (_pos >= _block.length) {
      _block = chacha20Block(_key, _zeroNonce, _counter);
      _counter = (_counter + 1) & _mask32;
      _pos = 0;
    }
    return _block[_pos++];
  }

  /// Дараагийн 32 битийн үг, 0..2^32−1.
  int nextU32() {
    final int b0 = _nextByte();
    final int b1 = _nextByte();
    final int b2 = _nextByte();
    final int b3 = _nextByte();
    return ((b0 << 24) | (b1 << 16) | (b2 << 8) | b3) & _mask32;
  }

  /// `0 <= r < bound`, ХАЗАЙЛТГҮЙ (rejection sampling).
  int below(int bound) {
    final int limit = rejectionLimit(bound);
    int x;
    do {
      x = nextU32();
    } while (x >= limit);
    return x % bound;
  }
}

/// Fisher–Yates — БУУРАХ давталт, `below()` ашиглана (GDD-05 §7.2).
/// Цэвэр: `items`-ийг ХЭЗЭЭ Ч өөрчлөхгүй, шинэ жагсаалт буцаана.
List<T> fisherYates<T>(List<T> items, Rng rng) {
  final List<T> a = List<T>.of(items);
  for (int i = a.length - 1; i > 0; i--) {
    final int j = rng.below(i + 1);
    final T tmp = a[i];
    a[i] = a[j];
    a[j] = tmp;
  }
  return a;
}

/// `sha256(key ‖ utf8(label))` — домэйн тусгаарласан урсгалын түлхүүр.
/// `DEAL` ба `ORDER` хоёр урсгалыг салгахад хэрэглэгдэнэ (GDD-05 §7.2).
Uint8List streamKey(List<int> seed, String label) {
  final List<int> buf = <int>[...seed, ...utf8.encode(label)];
  return sha256(buf);
}
