// Гарах мессежийн хаяглалт.
//
// ЭНЭ ФАЙЛЫН БҮХ УТГА НЭГ ЗҮЙЛД: онлайн мафид хамгийн аюултай алдаа бол
// «нийтэд илгээх ёсгүй зүйлийг нийтэд илгээх». Тиймээс хаяглалтыг ТӨРӨЛ
// болгож, санамсаргүй нийтлэх боломжгүй болгов.
//
// `Outbound.all(...)` — бүгдэд. Дүр агуулсан зүйл ЭНД ОРОХГҮЙ.
// `Outbound.to(...)` — нэр заасан хүмүүст. Нууц зүйл ЗӨВХӨН ингэж явна.

import 'package:protocol/protocol.dart';

/// Нэг хаяглагдсан мессеж.
class Outbound {
  const Outbound._(this.recipients, this.msg, this.broadcast);

  /// Бүх холбогдсон тоглогчид.
  ///
  /// Энд дамжуулж буй мессеж нь ХЭН Ч ХАРЖ БОЛОХ зүйл байх ёстой.
  /// `room_test.dart` бүтэн тоглолт явуулж, нийтийн бүх мессежийг
  /// шалгаж, дүрийн ул мөр байгаа эсэхийг барина.
  factory Outbound.all(Envelope msg) =>
      Outbound._(const <PlayerId>{}, msg, true);

  /// Зөвхөн нэр заасан тоглогчид.
  factory Outbound.to(Set<PlayerId> who, Envelope msg) =>
      Outbound._(who, msg, false);

  /// Нэг хүнд.
  factory Outbound.one(PlayerId who, Envelope msg) =>
      Outbound._(<PlayerId>{who}, msg, false);

  /// Хоосон бол [broadcast] үнэн байна.
  final Set<PlayerId> recipients;
  final Envelope msg;
  final bool broadcast;

  @override
  String toString() => broadcast
      ? 'Outbound.all(${msg.type})'
      : 'Outbound.to(${recipients.length}, ${msg.type})';
}
