// «Хот унтлаа» — каноник цувралчлал (hash хийхэд зориулсан).
//
// Эх сурвалж: GDD-05 §2 (`inputHash = sha256(canon(...))`), §8.
// Зорилго нь ганц: ИЖИЛ утга → ИЖИЛ БАЙТ, машин, хувилбар, ажиллуулалт бүрд.
// Тиймээс:
//   • Map-ийн түлхүүрүүд ЭРЭМБЭЛЭГДЭНЭ (бүхэл тоон түлхүүр — тоогоор,
//     бусад нь — түлхүүрийн мөрийн код нэгжээр).
//   • `Set` нь гишүүдийнхээ каноник мөрөөр эрэмбэлэгдэж массив болно.
//   • `double` БҮРЭН ХОРИОТОЙ (GDD-05 §0) — `ArgumentError` шиднэ.
//   • `Uint8List` нь hex мөр болно (seed нь ингэж бичигдэнэ).
//   • Enum нь `.name` мөр болно.
// Хоосон зай, мөр таслалт байхгүй — JSON-той төстэй ч ЯГ JSON гэсэн амлалт
// өгөхгүй; амлалт нь зөвхөн детерминизм.

import 'dart:convert';
import 'dart:typed_data';

import 'hash.dart';

/// Дурын утгыг каноник мөр болгоно.
///
/// Дэмжигдэх төрлүүд: `null`, `bool`, `int`, `String`, `Enum`, `Uint8List`,
/// `Iterable`, `Set`, `Map`. Бусад бүх зүйл — `ArgumentError`.
String canon(Object? value) {
  final StringBuffer sb = StringBuffer();
  _write(sb, value);
  return sb.toString();
}

/// `sha256Hex(utf8.encode(canon(value)))` — hash-ийн цорын ганц зам.
String canonHash(Object? value) => sha256Hex(utf8.encode(canon(value)));

void _write(StringBuffer sb, Object? v) {
  if (v == null) {
    sb.write('null');
    return;
  }
  if (v is bool) {
    sb.write(v ? 'true' : 'false');
    return;
  }
  if (v is double) {
    // GDD-05 §0: хөдөлгүүрт `double` БАЙХГҮЙ. Чимээгүй дугуйлалт нь
    // машин хооронд байт зөрүүлэх хамгийн нууцлаг эх сурвалж.
    throw ArgumentError('canon: `double` хориотой (GDD-05 §0): $v');
  }
  if (v is int) {
    sb.write(v.toString());
    return;
  }
  if (v is String) {
    _writeString(sb, v);
    return;
  }
  if (v is Uint8List) {
    _writeString(sb, hex(v));
    return;
  }
  if (v is Enum) {
    _writeString(sb, v.name);
    return;
  }
  if (v is Set) {
    // Олонлог эрэмбэгүй тул гишүүдийн каноник мөрөөр эрэмбэлнэ.
    final List<String> parts = v.map<String>(canon).toList()..sort();
    sb.write('[');
    for (int i = 0; i < parts.length; i++) {
      if (i > 0) sb.write(',');
      sb.write(parts[i]);
    }
    sb.write(']');
    return;
  }
  if (v is Map) {
    _writeMap(sb, v);
    return;
  }
  if (v is Iterable) {
    sb.write('[');
    int i = 0;
    for (final Object? e in v) {
      if (i > 0) sb.write(',');
      _write(sb, e);
      i++;
    }
    sb.write(']');
    return;
  }
  throw ArgumentError('canon: дэмжигдэхгүй төрөл ${v.runtimeType}');
}

void _writeMap(StringBuffer sb, Map<Object?, Object?> m) {
  final List<Object?> keys = m.keys.toList();
  final bool allInt = keys.every((Object? k) => k is int);
  if (allInt) {
    keys.sort((Object? a, Object? b) => (a! as int).compareTo(b! as int));
  } else {
    keys.sort((Object? a, Object? b) => _keyString(a).compareTo(_keyString(b)));
  }
  sb.write('{');
  for (int i = 0; i < keys.length; i++) {
    if (i > 0) sb.write(',');
    _writeString(sb, _keyString(keys[i]));
    sb.write(':');
    _write(sb, m[keys[i]]);
  }
  sb.write('}');
}

String _keyString(Object? k) {
  if (k is String) return k;
  if (k is int) return k.toString();
  if (k is Enum) return k.name;
  throw ArgumentError('canon: Map-ийн түлхүүр нь String|int|Enum байх ёстой, '
      'олдсон нь ${k.runtimeType}');
}

void _writeString(StringBuffer sb, String s) {
  sb.write('"');
  for (int i = 0; i < s.length; i++) {
    final int c = s.codeUnitAt(i);
    switch (c) {
      case 0x22:
        sb.write(r'\"');
      case 0x5C:
        sb.write(r'\\');
      case 0x08:
        sb.write(r'\b');
      case 0x0C:
        sb.write(r'\f');
      case 0x0A:
        sb.write(r'\n');
      case 0x0D:
        sb.write(r'\r');
      case 0x09:
        sb.write(r'\t');
      default:
        if (c < 0x20) {
          sb.write(r'\u');
          sb.write(c.toRadixString(16).padLeft(4, '0'));
        } else {
          sb.writeCharCode(c);
        }
    }
  }
  sb.write('"');
}
