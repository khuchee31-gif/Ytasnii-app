// «Хот унтлаа» — seed-ийн гарал, шударга байдлын код ба тараалт.
//
// АЛГОРИТМЫГ GDD-10 §2 ЭЗЭМШИНЭ (GDD-05 §7.1 зөвхөн давтаж бичсэн; зөрвөл
// GDD-10 ялна):
//
//   1. seed0      <- Random.secure().nextBytes(32)      // хөдөлгүүрээс ГАДНА
//   2. h0         <- sha256(seed0)
//   3. fairCode   <- u32be(h0[0..4]) % 1000000, 6 орон болгож тэгээр нөхнө
//   4. dealId     <- hex(h0[4..8])
//   5. readerSeat <- pickSeat(u16be(h0[8..10]), N, exclude: holderSeat)
//   6. userEntropy — хүний оролт (4 цифр эсвэл 2.0 сек сэгсрэлт)
//   7. seed       <- sha256(utf8("HOTUNTLAA/v1") ‖ hex(dealId) ‖ seed0 ‖ userEntropy)
//
// Хоёр урсгал, домэйн тусгаарлалттай: `DEAL` (дүр) ба `ORDER` (`orderPerm`).
// `orderPerm` нь `GAME_CREATED`-д ИЛ бичигдэнэ — тиймээс тэр нь нуугдмал
// тараалттай ижил урсгалаас гарч БОЛОХГҮЙ (GDD-05 §7.2).

import 'dart:convert';
import 'dart:typed_data';

import 'hash.dart';
import 'model.dart';
import 'rng.dart';

/// Домэйн тусгаарлалтын шошго. Хувилбар өөрчлөгдвөл ЭНЭ мөр өөрчлөгдөнө.
const String kSeedDomain = 'HOTUNTLAA/v1';

/// `DEAL` урсгалын шошго — дүрийн тараалт.
const String kDealStream = 'DEAL';

/// `ORDER` урсгалын шошго — `orderPerm`.
const String kOrderStream = 'ORDER';

/// Тараалтын бүрэн үр дүн. Бүх талбар детерминист: ижил `(seed0, userEntropy,
/// n, deck, holderSeat)` → ижил байт.
class DealResult {
  /// Зургаан цифр, 3+3 хэлбэрээр: «412-995» (GDD-05 §0, GDD-10 §3).
  final String fairCode;

  /// 8 hex тэмдэгт, `hex(h0[4..8])`.
  final String dealId;

  /// Кодыг чангаар уншиж, дэвтэрт бичих суудал. Утас барьсан хүн БИШ.
  final Seat readerSeat;

  /// 32 байт. `NightState.seed` болж очно.
  final Uint8List seed;

  /// НУУЦ. Зөвхөн санах ойд; дискэнд хэзээ ч бичигдэхгүй (GDD-10 §4).
  final Map<Seat, Role> roleBySeat;

  /// Тэнцэл тайлах цорын ганц эх сурвалж; `GAME_CREATED`-д ил бичигдэнэ.
  final List<Seat> orderPerm;

  const DealResult({
    required this.fairCode,
    required this.dealId,
    required this.readerSeat,
    required this.seed,
    required this.roleBySeat,
    required this.orderPerm,
  });

  /// `canon`/`canonHash`-д өгөх каноник дүрслэл. Тестийн детерминизмын
  /// шалгалт ба golden вектор үүнийг ашиглана.
  Map<String, Object?> toCanon() => <String, Object?>{
        'fairCode': fairCode,
        'dealId': dealId,
        'readerSeat': readerSeat,
        'seed': seed,
        'roleBySeat': roleBySeat,
        'orderPerm': orderPerm,
      };
}

int _u32be(List<int> b, int i) =>
    ((b[i] & 0xFF) << 24) |
    ((b[i + 1] & 0xFF) << 16) |
    ((b[i + 2] & 0xFF) << 8) |
    (b[i + 3] & 0xFF);

int _u16be(List<int> b, int i) => ((b[i] & 0xFF) << 8) | (b[i + 1] & 0xFF);

/// Шударга байдлын код: `u32be(h0[0..4]) % 1000000`, зургаан орон болгож
/// тэгээр нөхөөд «412-995» гэсэн 3+3 хэлбэрээр буцаана.
///
/// Аравтын тоо гэж сонгосон нь: зургаан hex тэмдэгтийг монголоор чангаар
/// уншихад анги гацна, «дөрөв, нэг, хоёр — ес, ес, тав» гэдэг нь гацахгүй
/// (GDD-05 §7.1).
String fairnessCode(Uint8List h0) {
  final String d = fairnessDigits(h0);
  return '${d.substring(0, 3)}-${d.substring(3)}';
}

/// Зураасгүй зургаан цифр («412995») — дэлгэцэнд биш, тооцоололд.
String fairnessDigits(Uint8List h0) {
  if (h0.length < 10) {
    throw ArgumentError('h0 нь 32 байт байх ёстой (sha256(seed0))');
  }
  final int v = _u32be(h0, 0) % 1000000;
  return v.toString().padLeft(6, '0');
}

/// `dealId = hex(h0[4..8])` — 8 hex тэмдэгт.
String dealIdOf(Uint8List h0) {
  if (h0.length < 10) {
    throw ArgumentError('h0 нь 32 байт байх ёстой (sha256(seed0))');
  }
  return hex(h0.sublist(4, 8));
}

/// `pickSeat(u16be(h0[8..10]), n, exclude: holderSeat)`.
///
/// Утас барьсан хүн уншигчийг сонгодог бол хамсаатнаа сонгоно — тиймээс
/// уншигч нь `h0`-оос, кодыг мэдэхээс өмнө тодорхойлогдоно (GDD-10 §2).
Seat readerSeatOf(Uint8List h0, int n, {required Seat holderSeat}) {
  if (h0.length < 10) {
    throw ArgumentError('h0 нь 32 байт байх ёстой (sha256(seed0))');
  }
  if (n < 1) {
    throw ArgumentError.value(n, 'n', 'дор хаяж 1 суудал');
  }
  final List<Seat> pool = <Seat>[
    for (int s = 1; s <= n; s++)
      if (s != holderSeat) s,
  ];
  if (pool.isEmpty) {
    throw ArgumentError('readerSeatOf: утас барьсан хүнээс өөр суудал алга');
  }
  return pool[_u16be(h0, 8) % pool.length];
}

/// `seed = sha256(utf8("HOTUNTLAA/v1") ‖ hex(dealId) ‖ seed0 ‖ userEntropy)`.
///
/// `dealId` нь аль хэдийн hex мөр тул түүний UTF-8 байтууд орно.
Uint8List deriveSeed({
  required String dealId,
  required Uint8List seed0,
  required Uint8List userEntropy,
}) {
  final List<int> buf = <int>[
    ...utf8.encode(kSeedDomain),
    ...utf8.encode(dealId),
    ...seed0,
    ...userEntropy,
  ];
  return sha256(buf);
}

/// Бүрэн тараалт. `deck` нь `n` элементтэй байх ЁСТОЙ — бүрэлдэхүүнийг
/// GDD-04 §2-ын хүснэгт эзэмшинэ, энэ функц түүнийг зөвхөн холино.
DealResult deal({
  required Uint8List seed0,
  required Uint8List userEntropy,
  required int n,
  required List<Role> deck,
  required Seat holderSeat,
}) {
  if (seed0.length != 32) {
    throw ArgumentError('seed0 нь 32 байт байх ёстой');
  }
  if (deck.length != n) {
    throw ArgumentError('deck.length (${deck.length}) != n ($n)');
  }

  final Uint8List h0 = sha256(seed0);
  final String code = fairnessCode(h0);
  final String dealId = dealIdOf(h0);
  final Seat reader = readerSeatOf(h0, n, holderSeat: holderSeat);
  final Uint8List seed = deriveSeed(
    dealId: dealId,
    seed0: seed0,
    userEntropy: userEntropy,
  );

  final Rng dealRng = Rng(streamKey(seed, kDealStream));
  final Rng orderRng = Rng(streamKey(seed, kOrderStream));

  final List<Role> shuffled = fisherYates(deck, dealRng);
  final Map<Seat, Role> roleBySeat = <Seat, Role>{};
  for (int k = 0; k < n; k++) {
    roleBySeat[k + 1] = shuffled[k];
  }

  final List<Seat> seats = <Seat>[for (int s = 1; s <= n; s++) s];
  final List<Seat> orderPerm = fisherYates(seats, orderRng);

  return DealResult(
    fairCode: code,
    dealId: dealId,
    readerSeat: reader,
    seed: seed,
    roleBySeat: Map<Seat, Role>.unmodifiable(roleBySeat),
    orderPerm: List<Seat>.unmodifiable(orderPerm),
  );
}
