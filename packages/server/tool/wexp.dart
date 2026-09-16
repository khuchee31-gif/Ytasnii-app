// ХЭМЖИЛТ: «Хотын шивнээ» эмчийн аврааг зарладаг уу.
//
// ЯАГААД ЭНЭ ХЭРЭГСЭЛ БАЙДАГ ВЭ: шивнээний дүрмийг өөрчлөх нь
// амархан, ЗӨВ эсэхийг мэдэх нь хэцүү. Энэ нь хамгийн муу
// тохиолдлыг олон удаа тоглоно — мафи нэг байг сонгож, эмч сохроор
// ЯГ тэр хүнийг аварсан шөнө — тэгээд шивнээ тэр суудлыг нийтэлсэн
// эсэхийг тоолно.
//
//   dart run --define=agree=0  tool/wexp.dart   # тохиролцоогүй анги
//   dart run --define=agree=55 tool/wexp.dart   # өдөр тохиролцсон анги
//
// `agree` нь иргэдийн хэдэн хувь нь өдрийн яриагаар НЭГ суудал дээр
// тохирсныг дуурайлгана.
//
// ХЭМЖСЭН ҮР ДҮН (400 тоглолт × тохиргоо тус бүр):
//
//   ХУУЧИН дүрэм (бүх товшилт тоологдоно):
//     босго 3 → шивнээ гарсан 100%, ГАРСАН БҮРД нь эмчийн аврааг
//     зарласан. Босго 4, 5 болгоход давтамж 52%, 11% болж буурсан ч
//     ХАМААРАЛ хэвээр — босго энэ алдааг засахгүй, зөвхөн ховордуулна.
//
//   ШИНЭ дүрэм (зөвхөн сэжиглэл), босго 3:
//     тохиролцоогүй: гарсан 4% (n=8) / 14% (n=11), аврааг зарласан 0%
//     тохиролцсон: гарсан 32% / 82%, аврааг зарласан 5% / 9%
//
// Өөрөөр хэлбэл шивнээ нь одоо ЗӨВХӨН ширээ үнэхээр тохиролцсон үед
// гарч, зарлагдсан суудал нь тэдний сэжиг — эмчийн шийдвэр биш.
import 'dart:typed_data';
import 'package:engine/engine.dart' as eng;

const int kAgree = int.fromEnvironment('agree', defaultValue: 0);

void main() {
  print('--- тохиролцооны хувь: \$kAgree% ---');
  for (final int minAgree in <int>[2, 3, 4]) {
    for (final int n in <int>[8, 11]) {
      int fired = 0, saved = 0, savedAndTold = 0, total = 0;
      for (int s = 0; s < 400; s++) {
        final eng.Rng rng = eng.Rng(
            Uint8List.fromList(List<int>.generate(32, (int i) => (i * 7 + s) & 0xFF)));
        final eng.Roster ros = eng.rosterFor(n);
        final List<eng.Role> deck = eng.deckFor(ros);
        final eng.DealResult d = eng.deal(
          seed0: Uint8List.fromList(List<int>.generate(32, (int i) => (i * 5 + s) & 0xFF)),
          userEntropy: Uint8List.fromList(<int>[s]),
          n: n,
          deck: deck,
          holderSeat: 1,
        );
        final eng.Setup setup = eng.Setup(
            n: n, roleBySeat: d.roleBySeat, whisperMinAgree: minAgree);
        final Set<int> alive = <int>{for (int i = 1; i <= n; i++) i};
        final eng.NightState st = eng.NightState(
          setup: setup,
          night: 2,
          alive: alive,
          seed: Uint8List.fromList(List<int>.generate(32, (int i) => (i * 3 + s) & 0xFF)),
          orderPerm: List<int>.generate(n, (int i) => i + 1),
        );
        // Мафи нэг байг сонгоно, эмч ТЭР л хүнийг аварна (хамгийн
        // муу тохиолдол: яг таарсан шөнө).
        final List<int> mafia = <int>[
          for (int i = 1; i <= n; i++)
            if (eng.factionOf(d.roleBySeat[i]!) == eng.Faction.mafi) i,
        ];
        final List<int> town = <int>[
          for (int i = 1; i <= n; i++) if (!mafia.contains(i)) i,
        ];
        final int victim = town[rng.below(town.length)];
        final int focus = town[rng.below(town.length)];
        final List<eng.Intent> ins = <eng.Intent>[];
        int seq = 0;
        for (int i = 1; i <= n; i++) {
          final eng.Role r = d.roleBySeat[i]!;
          final eng.Ability a = eng.abilityOf(r);
          int t;
          if (a == eng.Ability.mafiaKill) {
            t = victim;
          } else if (a == eng.Ability.heal) {
            t = victim; // ХАМГИЙН МУУ тохиолдол
          } else if (a == eng.Ability.suspect && rng.below(100) < kAgree) {
            // ХЭСЭГ ИРГЭН тохиролцоно (өдрийн яриаг дуурайлгана).
            t = focus == i ? (focus % n) + 1 : focus;
          } else {
            // Бусад бүгд САНАМСАРГҮЙ (өөрөөсөө өөр).
            do {
              t = 1 + rng.below(n);
            } while (t == i);
          }
          ins.add(eng.Intent(
            intentId: '2_${i}_$seq',
            night: 2,
            actor: i,
            ability: a,
            target: t,
            clientSeq: ++seq,
          ));
        }
        final eng.NightReport rep = eng.resolveNight(st, ins);
        total++;
        if (rep.deaths.isEmpty) saved++;
        if (rep.whisper.isNotEmpty) fired++;
        if (rep.deaths.isEmpty && rep.whisper.contains(victim)) savedAndTold++;
      }
      print('minAgree=$minAgree n=$n  шивнээ гарсан=${fired * 100 ~/ total}%  '
          'аварсан=${saved * 100 ~/ total}%  '
          'АВАРСНЫГ ЗАРЛАСАН=${saved == 0 ? 0 : savedAndTold * 100 ~/ saved}%');
    }
  }
}
