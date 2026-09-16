// «Хот унтлаа» — санааны шалгалт.
//
// Эх сурвалж: GDD-05 §2-ын `RejectCode` хүснэгт, GDD-02 §4.1-ийн бай сонгох
// хязгаарууд, GDD-03 §4-ийн гэрийн дүрмийн toggle-ууд.
//
// **Шалгалт нь ИЛГЭЭХ мөчид болно, шийдвэрлэх үед ХЭЗЭЭ Ч БИШ** (GDD-05 §2).
// Шийдвэрлэх үед дахин шалгавал инвариант N6 эвдэрч, дахин тоглуулалт зөрнө.
//
// ХАТУУ ДҮРЭМ (GDD-05 §0): цэвэр функц, IO байхгүй, `NightState`-ыг
// ХЭЗЭЭ Ч өөрчлөхгүй.

import 'model.dart';

/// Санаа хүчинтэй бол `null`, эс бөгөөс татгалзлын код.
/// Дэлгэц нь кодыг монгол текст болгоно.
///
/// Шалгалтын дараалал (эхний таарсан нь хүчинтэй):
///
/// 1. `noAction` → **ҮРГЭЛЖ хүчинтэй** (GDD-05 §1-ийн 1-р дүрэм, инвариант
///    N22). Товшихгүй өнгөрөх нь товшсонтой ялгагдахгүй байх ёстой, тиймээс
///    энэ салаа бусад бүх шалгалтаас ДЭЭГҮҮР байна. `target` нь `null`.
/// 2. `nightSealed` — санаа өөр шөнийнх. Тэр шөнө аль хэдийн лацдагдсан.
/// 3. `seatNotInGame` — үйлдэгч (эсвэл бай) 1..n-д байхгүй, эсвэл дүргүй.
/// 4. `actorDead` — үйлдэгч `alive` дотор байхгүй (инвариант N6).
/// 5. `notYourAbility` — `abilityOf(role)`-той таарахгүй.
/// 6. `seatNotInGame` — бай `null` эсвэл ширээнээс гадуур.
/// 7. `targetDead` — бай `alive` дотор байхгүй.
/// 8. `targetSelf` — §2-ын хүснэгтийн дагуу (доор).
/// 9. `targetSameFaction` — мафи мафиг онилов БӨГӨӨД `mafiaFriendlyFire` унтарсан.
/// 10. `healRepeat` — Эмч өнгөрсөн шөнийн байгаа нь дахин онилов.
RejectCode? validate(Intent i, NightState s) {
  // --- 1. Хоосон товшилт үргэлж хүчинтэй -----------------------------------
  // «Алгасах» товч байхгүй, гэвч цонх дуусахад `noAction` бүртгэгдэнэ.
  // Гаднаас нь товшсонтой ЯЛГАГДАХГҮЙ байх нь жигд хуурмагийн нөхцөл.
  if (i.ability == Ability.noAction) return null;

  // --- 2. Лацдагдсан шөнө --------------------------------------------------
  if (i.night != s.night) return RejectCode.nightSealed;

  // --- 3. Үйлдэгчийн суудал ------------------------------------------------
  final n = s.setup.n;
  if (i.actor < 1 || i.actor > n) return RejectCode.seatNotInGame;
  final actorRole = s.setup.roleOf(i.actor);
  if (actorRole == null) return RejectCode.seatNotInGame;

  // --- 4. Үхсэн үйлдэгч (инвариант N6) -------------------------------------
  if (!s.alive.contains(i.actor)) return RejectCode.actorDead;

  // --- 5. Дүрийн чадвар ----------------------------------------------------
  if (i.ability != abilityOf(actorRole)) return RejectCode.notYourAbility;

  // --- 6. Байн суудал ------------------------------------------------------
  final t = i.target;
  if (t == null || t < 1 || t > n) return RejectCode.seatNotInGame;
  final targetRole = s.setup.roleOf(t);
  if (targetRole == null) return RejectCode.seatNotInGame;

  // --- 7. Үхсэн бай --------------------------------------------------------
  if (!s.alive.contains(t)) return RejectCode.targetDead;

  // --- 8. Өөрийгөө онилов --------------------------------------------------
  // GDD-05 §2: «Мөрдөгч, Иргэн өөрийгөө онилов; Эмч нь `doctorSelfHeal`-ээс
  // хамаарна». Мафи энэ мөрөнд БАЙХГҮЙ — түүний хувьд өөрөө нь бас «өөрийн
  // хүн» тул `mafiaFriendlyFire` (9-р алхам) шийднэ (GDD-02 §4.1-ийн
  // «Өөрийгөө сонгох ба хамтрагчаа сонгох нь тохиргооноос хамаарна»).
  if (t == i.actor) {
    if (i.ability == Ability.heal) {
      final mode = s.setup.doctorSelfHeal;
      if (mode == SelfHeal.never) return RejectCode.targetSelf;
      if (mode == SelfHeal.once && (s.selfHealUsed[i.actor] ?? 0) >= 1) {
        return RejectCode.targetSelf;
      }
    } else if (i.ability == Ability.investigate ||
        i.ability == Ability.suspect ||
        i.ability == Ability.watch) {
      // Ажиглагч өөрийгөө ажиглаж БОЛОХГҮЙ: тэгвэл «хэн над руу очив»
      // гэсэн үнэгүй хамгаалалт болж, эмч, мөрдөгчийн хоёуланг нь
      // нэг шөнөд илчилнэ.
      return RejectCode.targetSelf;
    }
  }

  // --- 9. Өөрийнхнөө онилов ------------------------------------------------
  if (i.ability == Ability.mafiaKill &&
      !s.setup.mafiaFriendlyFire &&
      factionOf(targetRole) == Faction.mafi) {
    return RejectCode.targetSameFaction;
  }

  // --- 10. Өчигдөр аварсан хүнээ дахин аварлаа -----------------------------
  // Дараалсан хамгаалалтын хориг нь ЦАРЦСАН — гэрийн дүрмийн toggle биш
  // (GDD-02 §2).
  if (i.ability == Ability.heal && s.lastHealTarget[i.actor] == t) {
    return RejectCode.healRepeat;
  }

  return null;
}
