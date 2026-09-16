// S22 — Тусламж. GDD-06, GDD-11 §5.
//
// Дөрвөн мөр, бүгд нугалагддаг. ЭНЭ ДЭЛГЭЦ ДЭЭР ОДООГИЙН ТОГЛОЛТЫН ЮУ Ч
// БАЙХГҮЙ: амьд суудал, өөрийн дүр, `b`, шөнийн дугаар — нэг нь ч биш.
// Зөвхөн статик текст (GDD-11 §5). Тиймээс энэ виджет `GameController`-ыг
// ОГТ АВАХГҮЙ — задлахын аргагүй баталгаа.
//
// Тусламж бол PULL, хэзээ ч PUSH биш: апп S22-ыг өөрөө хэзээ ч нээхгүй.
// Аппын дотор «ёслол», «чимээгүй бол бүтээгдэхүүн», «атмосфер» гэсэн үг
// хэзээ ч гарахгүй (GDD-00 §12.4).

import 'package:flutter/material.dart' hide Intent;

import '../ui/tokens.dart';
import '../ui/widgets.dart';
import 'setup_parts.dart';

/// «Хэрхэн тоглох вэ» — дүрэм биш ДАРААЛАЛ (GDD-11 §5, арван мөр).
const List<String> kHowToPlay = <String>[
  'Шөнө эхэлнэ. Бүгд нүдээ анина.',
  'Мафи бие биеэ таньдаг. Хотынхон танихгүй.',
  'Шөнө бүр утас ширээгээр явна. Дуудсан хүн л утсаа авна.',
  'Утас чам дээр ирэхэд нэг дугаар товш. Юу товшихыг хөзөр чинь хэлсэн.',
  'Үүрээр апп хэн хохирсныг хэлнэ. Яагаад гэдгийг хэлэхгүй.',
  'Өдөр апп чимээгүй болно. Ярих нь та бүхний ажил.',
  'Санал гараар өгнө. Утас зөвхөн гарыг тоолно.',
  'Хотоос хөөгдсөн хүний дүр нээгдэхгүй.',
  'Мафи хотынхонтой тэнцвэл мафи ялна.',
  'Бүх мафи хотоос гарвал хотынхон ялна.',
];

/// Дүрийн нэг мөрийн ажил — GDD-02 §5-ын хөзрийн «Ажил» баганатай ЯГ ИЖИЛ
/// `String`. Сургалтын гадаргуу нь хувийн хөзөр, өөр юу ч биш (GDD-11).
const List<({String name, String faction, String job})> kRoleLines =
    <({String name, String faction, String job})>[
  (
    name: 'Иргэн',
    faction: 'Хотынхон',
    job: 'Шөнө сэжигтэй суудлаа товш. Өдөр ярь.'
  ),
  (
    name: 'Эмч',
    faction: 'Хотынхон',
    job: 'Шөнө бүр нэг хүнийг алалтаас авар.'
  ),
  (
    name: 'Мөрдөгч',
    faction: 'Хотынхон',
    job: 'Шөнө бүр нэг суудлыг шалга. Хариу нь тэр дороо гарна.'
  ),
  (
    name: 'Алуурчин',
    faction: 'Мафи',
    job: 'Шөнө хохирогчоо сонго. Хамтрагчид чинь ширээн дээр байна.'
  ),
  (
    name: 'Ахлагч',
    faction: 'Мафи',
    job: 'Санал зөрвөл чиний сонголт хүчинтэй.'
  ),
];

/// Брэнд тус бүрийн батарейн оновчлол — түр нөхөөс биш, БҮТЭЭГДЭХҮҮНИЙ
/// БОЛОМЖ (GDD-00 §9). Манай нөхцөлд дэлгэц бараг байнга унтарсан байдаг тул
/// энэ нь захын тохиолдол биш, үндсэн тохиолдол.
const List<({String brand, String steps})> kBatterySteps =
    <({String brand, String steps})>[
  (
    brand: 'Xiaomi · Redmi (MIUI)',
    steps: 'Тохиргоо → Апп → Аппуудыг удирдах → Хот унтлаа → '
        'Батерей хэмнэх → «Хязгаарлалтгүй».'
  ),
  (
    brand: 'Huawei',
    steps: 'Тохиргоо → Батерей → Аппын эхлүүлэлт → Хот унтлаа → '
        'гараар удирдаад гурвууланг нь асаа.'
  ),
  (
    brand: 'Samsung',
    steps: 'Тохиргоо → Батерей → Арын хязгаарлалт → '
        '«Хэзээ ч унтраахгүй апп» дотор Хот унтлаа-г нэм.'
  ),
  (
    brand: 'Oppo · Realme',
    steps: 'Тохиргоо → Батерей → Эрчим хүч хэмнэх → Хот унтлаа → '
        'арын ажиллагааг зөвшөөр.'
  ),
];

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key, required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return PhoneScaffold(
      title: 'Тусламж',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          FoldSection(
            title: 'Хөтлөгчийн дуу тасарч байна уу?',
            children: <Widget>[
              const _P('Утасны батерейн менежер аппыг чимээгүй болгодог. '
                  'Доорх зам брэнд тусдаа өөр.'),
              for (final ({String brand, String steps}) b in kBatterySteps)
                Padding(
                  padding: const EdgeInsets.only(bottom: kGap),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(b.brand,
                          style: kBody.copyWith(
                              fontWeight: FontWeight.w700,
                              color: kTextPrimary)),
                      Text(b.steps,
                          style: kBody.copyWith(color: kTextMuted)),
                    ],
                  ),
                ),
              const _P('Тохиргоо → «Дэлгэц унтраахгүй» асаалттай байг.'),
            ],
          ),
          FoldSection(
            title: 'Хэрхэн тоглох вэ',
            children: <Widget>[
              for (int i = 0; i < kHowToPlay.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      SizedBox(
                        width: 26,
                        child: Text('${i + 1}.',
                            style: kBody.copyWith(color: kEmber)),
                      ),
                      // Уян хатан — 360px дээр мөр халихгүй.
                      Expanded(
                        child: Text(kHowToPlay[i],
                            style: kBody.copyWith(color: kTextPrimary)),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          FoldSection(
            title: 'Дүрүүд',
            children: <Widget>[
              for (final ({String name, String faction, String job}) r
                  in kRoleLines)
                Padding(
                  padding: const EdgeInsets.only(bottom: kGap),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: <Widget>[
                          Flexible(
                            child: Text(r.name.toUpperCase(),
                                style: kBody.copyWith(
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.1,
                                    color: kTextPrimary)),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(r.faction,
                                style: kLabel.copyWith(
                                    color: kTextMuted, letterSpacing: 0)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(r.job, style: kBody.copyWith(color: kTextMuted)),
                    ],
                  ),
                ),
            ],
          ),
          const FoldSection(
            title: 'Хот гэж юу вэ?',
            children: <Widget>[
              _P('«Хот» гэдэг нь зөвхөн орос «мирный город» биш, '
                  'хот айл гэдэг хоёроос таван өрх хамт буусан монгол бууц юм.'),
            ],
          ),
        ],
      ),
      action: FilledButton(onPressed: onClose, child: const Text('Хаах')),
    );
  }
}

class _P extends StatelessWidget {
  const _P(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: kGap),
        child: Text(text, style: kBody.copyWith(color: kTextMuted)),
      );
}

/// Ямар ч route дээрээс, доорхыг dispose ХИЙЛГЭЛГҮЙ нээнэ (GDD-11 §5).
Future<void> showHelpSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: kSurface,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (BuildContext sheet) => FractionallySizedBox(
      heightFactor: 0.92,
      child: HelpScreen(onClose: () => Navigator.of(sheet).pop()),
    ),
  );
}
