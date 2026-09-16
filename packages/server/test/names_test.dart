// Нэр цэвэрлэх, харьцуулах, давхардал тайлах.
//
// ЭНЭ ФАЙЛЫН УТГА: мафи бол ИТГЭЛИЙН тоглоом. «Бат мафи» гэж хэлэхэд
// ширээн дээр хоёр «Бат» байвал тоглоом утгагүй болно. Гэтэл хоёр нэр
// өөр БАЙТ-тай атлаа ЯГ ИЖИЛ харагдаж болно. Доорх тестүүд тэр бүх
// аргыг нэг нэгээр нь хаана.

import 'package:protocol/protocol.dart';
import 'package:server/src/names.dart';
import 'package:test/test.dart';

void main() {
  group('Нэр цэвэрлэх', () {
    test('хоёр талын зайг хасна', () {
      expect(cleanName('  Бат  '), 'Бат');
    });

    test('ямар ч зайг энгийн зай болгоно', () {
      expect(cleanName('Бат\tЭрдэнэ'), 'Бат Эрдэнэ');
      expect(cleanName('Бат\nЭрдэнэ'), 'Бат Эрдэнэ');
      // Тасрахгүй зай (U+00A0) — Dart-ын `trim()` дотор талынхыг хөндөхгүй.
      expect(cleanName('Бат Эрдэнэ'), 'Бат Эрдэнэ');
    });

    test('давхар зайг нэг болгоно', () {
      expect(cleanName('Бат   Эрдэнэ'), 'Бат Эрдэнэ');
    });

    test('үл үзэгдэх тэмдэгтийг хасна', () {
      expect(cleanName('​Бат​'), 'Бат');
      expect(cleanName('﻿Бат'), 'Бат');
      expect(cleanName('Б­ат'), 'Бат');
      // Чиглэл дарах тэмдэгтийг эх кодод шууд бичихгүй — дүрслэлийг нь
      // эргүүлдэг тул кодыг уншихад төөрөгдөл үүсгэнэ.
      expect(cleanName('${String.fromCharCode(0x202E)}Бат'), 'Бат');
    });

    test('хоосон нь хоосон хэвээр', () {
      expect(cleanName(''), '');
      expect(cleanName('​ ­'), '');
    });

    test('ТЭМДЭГТЭЭР тайрна, байтаар биш', () {
      final String s = cleanName('А' * 40);
      expect(s.runes.length, kMaxNameRunes);
    });

    test('эможи дундуур нь тасрахгүй', () {
      final String s = cleanName('А' * 15 + '😀😀');
      expect(s.runes.length, kMaxNameRunes);
      expect(s.endsWith('😀'), isTrue);
      // Хос орлуулагч бүтэн үлдсэн эсэх.
      //
      // Эможи нь UTF-16-д ХОЁР нэгжээр бичигддэг. Дундуур нь тайрвал
      // ганцаарчилсан орлуулагч үлдэж, JSON-оор дамжихдаа U+FFFD болж
      // хувирна. `runes`-ээр задалж дахин угсрахад ЯГ өөрөө гарч байвал
      // хос бүр бүтэн гэсэн үг.
      expect(String.fromCharCodes(s.runes), s);
    });

    test('тайрсны дараа төгсгөлд зай үлдэхгүй', () {
      expect(cleanName('А' * 15 + ' Б').endsWith(' '), isFalse);
    });

    test('хоёр удаа цэвэрлэхэд өөрчлөгдөхгүй', () {
      for (final String x in <String>[
        '  Бат  ', 'Бат\tЭрдэнэ', '​Бат', 'А' * 40, 'А' * 15 + '😀😀', '',
      ]) {
        expect(cleanName(cleanName(x)), cleanName(x), reason: x);
      }
    });
  });

  group('Ижил харагдах нэр', () {
    test('том жижиг үсэг ялгахгүй', () {
      expect(nameKey('Болд'), nameKey('болд'));
      expect(nameKey('БОЛД'), nameKey('Болд'));
    });

    test('зай, үл үзэгдэх тэмдэгт ялгахгүй', () {
      expect(nameKey(cleanName('Бат ')), nameKey('Бат'));
      expect(nameKey(cleanName('Бат​')), nameKey('Бат'));
    });

    test('латин үсгээр хуурч чадахгүй', () {
      expect(nameKey('Хулан'), nameKey('Xулан'), reason: 'латин X');
      expect(nameKey('Оюун'), nameKey('Oюун'), reason: 'латин O');
      expect(nameKey('Соёл'), nameKey('Cоёл'), reason: 'латин C');
      expect(nameKey('сарнай'), nameKey('cарнай'), reason: 'латин c');
    });

    test('грек үсгээр хуурч чадахгүй', () {
      expect(nameKey('Роман'), nameKey('Ρоман'));
    });

    test('задарсан үсгийг нэгтгэнэ', () {
      // «Ё» = Е + U+0308, «Й» = И + U+0306.
      expect(nameKey(cleanName('Ёндон')), nameKey('Ёндон'));
      expect(nameKey(cleanName('Йгнат')), nameKey('Йгнат'));
    });

    test('хослох тэмдгээр (залго) хуурч чадахгүй', () {
      expect(nameKey(cleanName('Б̴а̴т̴')), nameKey('Бат'));
    });

    test('түлхүүр нь жижиг үсгээр гардаг', () {
      expect(nameKey('Бат'), 'бат');
    });
  });

  group('ХЭЗЭЭ Ч нэгтгэж болохгүй зүйлс', () {
    // Хэн нэгэн хожим энэ хүснэгтийг «сайжруулж» ерөнхий диакритик
    // хуулагч болговол эдгээр унана. Ө нь О БИШ, Ү нь У БИШ.
    test('Ө ба О тусдаа үсэг', () {
      expect(nameKey('Өнөр'), isNot(nameKey('Онор')));
    });

    test('Ү ба У тусдаа үсэг', () {
      expect(nameKey('Үзэсгэлэн'), isNot(nameKey('Узэсгэлэн')));
    });

    test('давхар үсгийг хураахгүй', () {
      expect(nameKey('Баатар'), isNot(nameKey('Батар')));
      expect(nameKey('Сараа'), isNot(nameKey('Сара')));
    });

    test('өөр нэр өөр хэвээр', () {
      expect(nameKey('Бат'), isNot(nameKey('Бата')));
      expect(nameKey('Бат'), isNot(nameKey('Бат 2')));
    });
  });

  group('Нэр шаардана', () {
    test('хоосон бол нэр шаардана', () {
      expect(nameProblem(''), ErrCode.nameRequired);
    });

    test('хэт богино', () {
      expect(nameProblem('Б'), ErrCode.nameTooShort);
      expect(nameProblem('..'), ErrCode.nameTooShort);
      expect(nameProblem('.-'), ErrCode.nameTooShort);
    });

    test('системийн нэрийг авч болохгүй', () {
      expect(nameProblem('Зочин'), ErrCode.nameReserved);
      expect(nameProblem('зочин'), ErrCode.nameReserved);
      expect(nameProblem('Бот 3'), ErrCode.nameReserved);
      expect(nameProblem('Бот3'), ErrCode.nameReserved);
      // Латин o-той хуурамч «Бот» ч баригдана — шалгалт ТҮЛХҮҮР дээр.
      expect(nameProblem('Бoт 3'), ErrCode.nameReserved);
    });

    test('жинхэнэ үг таслагдахгүй', () {
      expect(nameProblem('Ботго'), isNull, reason: 'бодит монгол үг');
      expect(nameProblem('Бат'), isNull);
      expect(nameProblem('Зочинбат'), isNull);
    });

    test('бот өөрөө өөрийн нэрийг авч болно', () {
      expect(nameProblem('Бот 1', allowReserved: true), isNull);
    });
  });

  group('Давхардвал дугаарлана', () {
    test('чөлөөтэй бол хэвээр', () {
      expect(uniqueName('Бат', <String>{}), 'Бат');
    });

    test('дараалан дугаарлана', () {
      expect(uniqueName('Бат', <String>{'бат'}), 'Бат 2');
      expect(uniqueName('Бат', <String>{'бат', 'бат 2'}), 'Бат 3');
    });

    test('бичсэн хэлбэрийг нь хадгална', () {
      // Түлхүүр нь мөргөлдсөн ч ХАРАГДАХ нэр нь бичсэнээрээ үлдэнэ.
      expect(uniqueName('бат', <String>{'бат'}), 'бат 2');
      expect(uniqueName('Xулан', <String>{'хулан'}), 'Xулан 2');
    });

    test('дугаар нэмэхэд уртаас хэтрэхгүй', () {
      final String got = uniqueName('А' * 16, <String>{'а' * 16});
      expect(got.runes.length, lessThanOrEqualTo(kMaxNameRunes));
      expect(got.endsWith(' 2'), isTrue);
    });

    test('гарсан нэр ХЭЗЭЭ Ч эзэлсэн түлхүүртэй тааралдахгүй', () {
      final List<String> fixtures = <String>['Бат', 'бат', 'Болд', 'А' * 16, 'Хулан'];
      for (final String f in fixtures) {
        for (final Set<String> taken in <Set<String>>[
          <String>{},
          <String>{'бат'},
          <String>{'бат', 'бат 2', 'бат 3'},
          <String>{'а' * 16, 'а' * 13 + ' 2'},
          <String>{'хулан', 'болд', 'бат'},
        ]) {
          final String got = uniqueName(f, taken);
          expect(taken.contains(nameKey(got)), isFalse,
              reason: '$f + $taken -> $got');
        }
      }
    });
  });
}
