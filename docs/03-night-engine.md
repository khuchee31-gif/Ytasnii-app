# Бүлэг 03 — Шөнийн үйлдэл шийдвэрлэх хөдөлгүүр

> **Гол дүгнэлт**
> - Шөнийн бүх үйлдлийг **хоёр тоон шат** (довтолгооны түвшин ба хамгаалалтын түвшин) дээр буулгаж, ганцхан харьцуулалтаар шийд: `алах эсэх = довтолгоо > хамгаалалт`. Энэ нь «эмч мафиг давах уу?» гэсэн маргааныг бүрмөсөн үгүй болгоно.
> - Үйлдлүүдийг **priority bucket** (эрэмбийн хувин) болгон бүлэглэ. Нэг хувин доторх эрэмбийг **тоглоом эхлэхэд үүсгэсэн seed-тэй солбилцол (`orderPerm`)**-оор тогтоо. **Илгээсэн хугацаагаар (timestamp) ХЭЗЭЭ Ч эрэмбэлэхгүй** — интернэтийн хурд шийдэгч болж хувирна.
> - `resolveNight` нь **цэвэр функц** байх ёстой: `Date.now()` байхгүй, `Math.random()` байхгүй, float байхгүй. Ингэснээр офлайн утас дээр ажиллаж байгаа хөдөлгүүр ба серверийн хөдөлгүүр **яг ижил** үр дүн өгнө — офлайн горим бол «сервер чиний халаасанд» гэсэн үг.
> - **18 парадоксын шийдвэр** (P1–P18) урьдчилан тодорхойлогдсон, кодонд нэртэй тогтмол болж, монгол хэлний дүрмийн дэлгэц дээр гарна. Blood on the Clocktower-ийн «хөтлөгч таамаглаж шийд» загварыг машин хуулж болохгүй — машин **шийдэгдэхүйц (decidable)** байх ёстой.
> - Энэ ноорог дотор **илэрсэн нэг алдаа байна**: `SELF_BUFF` хувин (30) `BLOCK` хувингаас (60) дээгүүр байгаа тул P17 (Veteran-ийг саатуулах) хэрэгжихгүй. Код бичихээсээ өмнө засах ёстой — §3.2-ын (a) хувилбарыг зөвлөж байна.
> - MVP-д ердөө **20/60/90/100/120/130/160/170** гэсэн 8 хувин хангалттай. Дөрвөн дүр (Мафи, Эмч, Мөрдөгч, Иргэн) үүнээс илүүг шаардахгүй, гэхдээ шат нь ирээдүйд өргөжих зайтай.

*Судалгааны огноо: 2026-09-15. Эх тайлан: 03-night-resolution.md*

**Судалгааны огноо: 2026-09-15.** Энд бичигдсэн бүх тоо эх сурвалж болон татаж авсан огноогоо дагуулж яваа. Анхдагч хуудсаас баталгаажуулж чадаагүй зүйлийг **[баталгаажаагүй] / [тооцоолол]** гэж тодорхой тэмдэглэсэн.

---

## 1. Одоо байгаа тоглоомууд бодитоор юу хийдэг вэ (нотолгоо)

### 1.1 Town of Salem 1 ба 2 — довтолгоо/хамгаалалтын шат ба priority bucket

Town of Salem бол хамгийн их хуулбарлагдсан загвар. Учир нь тэр «эмч мафиг давах уу?» гэсэн хүний маргааныг **хоёр тоон шат** болгон хувиргасан. Албан ёсны wiki-ээс (townofsalem.wiki.gg, *Attributes (ToS2)*, 2026-09-15-нд татав):

**Юу гэсэн үг вэ?** «Шат» гэдэг нь 0, 1, 2, 3 гэсэн энгийн бүхэл тоо. Довтолгоо нь хамгаалалтаас **чанга** байвал тоглогч үхнэ. Тэгэхээр код дотор ямар ч онцгой тохиолдол (if-ийн ой) хэрэггүй.

| Довтолгооны түвшин | Утга (wiki-ийн яг үг, товчилсон) |
|---|---|
| None | «you have no means of dealing an attack» — чи хэнийг ч довтлох арга байхгүй |
| Basic | Хамгаалалтгүй (Defense = None) бай-г алдаг |
| Powerful | Basic хамгаалалттай бай-г алдаг; Powerful ба түүнээс дээшийг алж чадахгүй |
| Unstoppable | Invincible хамгаалалтаас бусад бүх бай-г алдаг |
| *(довтолгооны түвшин БИШ)* | Wiki-д тусад нь «Abilities that ignore Defense» гэсэн хэсэг байдаг: Public Hangings, Prosecution, Hex Bomb, Armageddon нь «will kill regardless of a player's Defense level». Эдгээр нь **үйл явдал/чадвар болохоос тавдахь довтолгооны шат БИШ** — wiki яг дөрвөн довтолгооны түвшин тодорхойлдог. (wiki.gg *Attributes (ToS2)*, 2026-09-15-нд татав) |

| Хамгаалалтын түвшин | Утга |
|---|---|
| None | «you will die from any attack» — ямар ч довтолгооноос үхнэ |
| Basic | Basic довтолгооноос бүрэн хамгаална |
| Powerful | Unstoppable-аас доош бүх довтолгоог даана |
| Invincible | «can't die from any form of attack unless faced with an event that ignores defense» |

Шийдвэрийн дүрэм ганцхан харьцуулалт болж хураагдана: **`kills = attack_level > defense_level`**.

Нэг нарийн дэд-нарийвчлалыг анхаар: **Ганцаарчин (Serial Killer)-ийн Counterattack л «зөвхөн төрөлхийн (natural) хамгаалалтыг» тоодог гэж баримтжсан**. Wiki-д хэрэв байны хамгаалалт «natural» бол алагдана, харин өөр тоглогч (Cleric, Trickster) эдгээсэн бол «because their Defense is no longer innate» гээд амьд үлдэнэ гэсэн байдаг. Doomsayer-ийн Doom, Jester-ийн Boredom нь хамгаалалтын түвшнээс үл хамааран алдаг «odd scenarios» жагсаалтад ордог; wiki тэднийг **төрөлхийн хамгаалалтаар хязгаарлаагүй**.

> **Баталгаажуулалт (2026-09-15):** Өмнөх ноороод гурвуулангийн (SK Counterattack, Doom, Boredom) «зөвхөн төрөлхийн хамгаалалт» гэж бүлэглэсэн байсныг залруулав. Зөвхөн SK Counterattack тийм. Эх сурвалж: https://townofsalem.wiki.gg/wiki/Attributes_(ToS2)

Инженерийн дүгнэлт нь хэвээрээ: хөдөлгүүр **төрөлхийн (innate)** хамгаалалт ба **олгогдсон (granted, эмчилгээний)** хамгаалалтыг заавал ялгаж хадгалах ёстой, учир нь SK Counterattack энэ ялгааг шаарддаг.

**Эрэмбэлэлт.** ToS1 дээр дүр бүр өөрийн давтагдашгүй priority дугаартай байсан. ToS2 үүнийг өөрчилсөн. Хөгжүүлэгч *shapesifter13* албан ёсны Steam хэлэлцүүлэгт (app 2140510, «Night priority», 2026-09-15-нд татав) ингэж хэлсэн:

> «In ToS1 each role had their own priority, but in ToS2 we use priority buckets, so there are much less to understand.» … «Roles within the same priority bucket are processed in a psuedo random order» [хөгжүүлэгчийн өөрийнх нь алдаатай бичлэг]. Мөн эрэмбэ нь **тоглоом эхлэхэд тогтоогддог** бөгөөд «it is not list order, hence psuedo random» гэжээ.

> **Баталгаажуулалт (2026-09-15):** Хөгжүүлэгч тэр эрэмбийг **seed-тэй** эсвэл сервер дээр дахин тоглуулж (replay) болдог гэж хэзээ ч хэлээгүй. Тэр бол **бидний дүгнэлт**, бас бидний сонгож авсан дизайн. «Тоглоом эхлэхэд тогтсон seed-тэй солбилцол» гэдгийг ToS2-ын баримтжсан хэрэгжилт биш, **бидний шаардлага** гэж үз. Эх сурвалж: https://steamcommunity.com/app/2140510/discussions/1/4208119548513190883/

Тэр сүүлчийн өгүүлбэр бол энэ бүх хэмжээсийн хамгийн чухал инженерийн санаа: **нэг хувин доторх эрэмбэ бол тоглоом эхлэхэд тогтоогдсон seed-тэй солбилцол** — жагсаалтын дараалал ч биш, илгээсэн дараалал ч биш. Тоглогчийн нүдэнд санамсаргүй харагдана, гэхдээ сервер 100% дахин давтаж чадна.

**Юу гэсэн үг вэ?** *Seed* гэдэг нь санамсаргүй тоо үүсгэгчийн эхлэлийн тоо. Ижил seed → ижил дараалал. Тиймээс тоглоом дууссаны дараа ч гэсэн «яагаад тэр шөнө ингэж шийдэгдсэн бэ?» гэдгийг бүрэн эргүүлж тоглуулж болно.

Өгөгдлийн загварыг хязгаарладаг, баталгаажсан бусад ToS2 механикууд:

| Механик | Дүрэм (wiki.gg, 2026-09-15) |
|---|---|
| Шөнийн урт | **37 сек** стандарт, **10 сек** Rapid Mode дээр |
| Айлчлалын төрөл (Visit types) | **Astral** («will not trigger any mechanic that relies on visiting» — айлчлалд тулгуурласан ямар ч механикийг асаахгүй), **Harmful** (довтолгоо; Bodyguard/Trapper эдгээрийг таслан зогсооно), **Non-Harmful** (Lookout харна, гэхдээ хамгаалалтын чадварыг асаахгүй) |
| Саатуулалт (Roleblock) | Тэр шөнийн чадварыг зогсооно; бай дараа нь **Hungover** болно → **дараагийн** шөнө саатуулалтад дархлаатай |
| Хяналт (Witch/Control) | Хянагч хохирогчийн байг өөрөө сонгоно, тэр тоглогчийн дүр болон түүнд ирэх мэдээллийг мэдэж авна; хянагдсан тоглогч Hungover болно |
| Bodyguard Guard | «Visit a player and Guard them from one direct attack. If a Harmful Visitor attempted to visit your target, you will cancel out their attack and then retaliate the attacker» — Guard нь довтлогчийг холдуулж, түүний шөнийн үйлдлийг цуцална. Олон довтлогч байвал **ToS2 аль нэгийг нь «at random» сонгодог** (wiki-ийн яг үг, 2026-09-15) — энэ нь баримтжсан детерминист дүрэм **биш**. Бидний seed-тэй сонголт бол зориудын хазайлт. Non-Harmful болон Astral айлчлал Guard-ыг асаахгүй; идэвхгүй (passive) довтолгоо (Veteran, Crusader, Jinxes) болон Hex Master үүнийг тойрно |
| Jailor (Шоронгийн дарга) | Хорих нь хоригдлыг үйлдэл хийхээс зогсооно («the prisoner will not be able to perform any action that Night») + тусгаарлана (Astral айлчлал хоригийг тойрно); Execute = **Powerful** довтолгоо; нэг тоглогчийг дараалсан хоёр шөнө хорих боломжгүй; N1-д цаазлах боломжгүй |
| Veteran Alert | Зочин бүрд **Basic хамгаалалт + Powerful довтолгоо**; **«can be Roleblocked, which will prevent your Alert»**; Astral зочид сэрэмжлэлийг бүрэн тойрно |
| Саатуулалтад дархлаатай дүрүүд | Tavern Keeper, Retributionist, Socialite (Town); Necromancer, Poisoner, Witch (Coven); Serial Killer, War, Pestilence (Neutral) — мөн Bestow-д байгаа тоглогчид. *Traits (ToS2)*-той тулгаж шалгав (2026-09-15), тэнд нэмж: **«none of these roles are immune to the Jailor!»** |

> **Баталгаажуулалт (2026-09-15):** ToS2-ын Jailor хуудас хоригдолд **Powerful хамгаалалт олгодоггүй**, бас хоригийг Roleblock гэж тодорхойлдоггүй. Өмнөх ноороод хоёуланг нь ташаа бичсэн байсныг залруулав. Эх сурвалж: https://townofsalem.wiki.gg/wiki/Jailor_(ToS2)

> **Баталгаажуулалт (2026-09-15):** ToS2 нь олон довтлогчтой Bodyguard-ын мөргөлдөөнийг **«at random»** шийддэг, баримтжсан детерминист дүрэм байхгүй. Бидний seed-тэй сонголт бол дахин тоглуулах боломжийн төлөө хийсэн, баримтжуулсан **зориудын хазайлт**. Эх сурвалж: https://townofsalem.wiki.gg/wiki/Bodyguard_(ToS2)

### 1.2 Mafiascum — Natural Action Resolution (NAR) ба түүний уналтын цэгүүд

NAR (wiki.mafiascum.net, XylBot мафи ботод зориулж Xylthixlm зохиосон).

> **⚠ [баталгаажаагүй] (2026-09-15-нд дахин шалгав).** wiki.mafiascum.net нь автомат татах бүх оролдлогод Cloudflare HTTP 403 буцаадаг (шууд хандалт, `action=raw`, текст ялгагч прокси бүгд), бас энэ орчноос web.archive.org руу хандах боломжгүй. **§1.2-ын НЭГ Ч ишлэлийг анхдагч хуудастай тулгаж баталгаажуулж чадаагүй.** Тэдгээр нь хайлтын үр дүнгийн хэсэгчилсэн (snippet) эшлэлээс гаралтай тул *үнэн зөв эсэх нь тодорхойгүй хөрвүүлэлт* гэж үзэх ёстой. Ялангуяа «Golden Rule-ийн эвдрэлийн тохиолдлын талаас бага хувийг» гэсэн тоо бол яг тоо шиг сонсогддог хэрнээ **баталгаажсан эх сурвалжгүй** — хэн нэгэн жинхэнэ browser дээр тэр хуудсыг нээж шалгах хүртэл бүтээгдэхүүний баримт бичиг эсвэл танилцуулгын слайдад бүү бич. **Хэрхэн баталгаажуулах вэ:** ердийн browser-оор https://wiki.mafiascum.net/index.php?title=Natural_Action_Resolution хуудсыг нээж, доорх ишлэл бүрийг үгчлэн тулга. Доорх инженерийн дүгнэлтүүд яг үгнээс хамаардаггүй; ишлэлүүд л хамаардаг.

- **Алтан дүрэм (Golden Rule):** «Apply actions which modify other actions before the actions they modify.» — Бусад үйлдлийг өөрчилдөг үйлдлийг, өөрчлөгдөх үйлдлээсээ өмнө хэрэгжүүл.
- **Журам:** «Find an action (or a passive modifier, such as Bulletproof) such that its effect cannot possibly be modified by any other action, resolve it, and repeat until all actions are resolved.» Энэ бол шууд утгаараа **«өөрчилдөг» граф дээрх топологийн эрэмбэлэлт (topological sort)**.
- **Хүлээн зөвшөөрсөн уналт:** Алтан дүрэм эвдрэх үед (цикл үүсэх үед) NAR тогтмол жагсаалт руу ухарч ордог, бөгөөд wiki өөрөө тэр жагсаалт нь «solves less than half of the Golden Rule breakdown cases that actually come up» гэж хүлээн зөвшөөрдөг.
- **Харилцан саатуулалт:** Саатуулагч дүрүүд бие бие рүүгээ чиглэвэл «all actions from the involved players fail, including both the roleblocking actions themselves and any other actions like the Mafia factional kill.»
- **Ална гэдэг нь зэрэг болдог:** «Kills happen at the end of the night with everyone pulling the trigger simultaneously, which means kills generally do not affect other actions.»
- **Triplicate Action Resolution** нь **Zeus Clause** нэмдэг: «if effects resolving at the same time could paradoxically cause more than one result, all causing roles fail to perform that action.»
- **Reasonable Action Resolution (RAR)** = NAR дээр нэмээд бүрэн эрэмбэ (total tiebreak) тавьсан хувилбар. Ингэснээр «cross-targeting jailkeepers» тогтвортой шийдэгдэнэ.

### 1.3 SC2Mafia — бодит бүтээгдэхүүн дээрх үйлдлийн дараалал (ба нэг анхааруулга)

SC2Mafia ойролцоогоор **30 алхмын** бичигдсэн дараалал нийтэлдэг (Forum Mafia XIII order of operations, 2026-09-15-нд татав):

хорих → шөнийн чат → **хантааз (vest) өмсөх** → veteran alert → урхи (traps) → **саатуулалт** → **witch-ийн удирдлага** → шоронгийн цаазлалт → track/watch → **bus driver** → хоёрдогч саатуулалт → framing/lawyering → мөрдөн шалгах → bodyguard-ын хөдөлгөөн → **бүх алалт** → **эдгээлт** → цэвэрлэх/дүр солих → элсүүлэх → spy-ийн үр дүн.

> **Баталгаажуулалт (2026-09-15):** Өмнөх ноороод «42 алхам» гэж бичсэн байсан нь буруу. **42 бол FAQ-ийн зүйлийн дугаар** — witch-ийн дархлааны шийдвэрийг агуулсан зүйл — алхмын тоо биш. Бодит дараалал ойролцоогоор **30 алхам**. Эх сурвалж: https://sc2mafia.com/forum/showthread.php/9152-Game-Rules-Order-of-Operations-and-FAQ

Хоёр сургамж:

1. Тэд «everybody above the Witch in the Order of Operations is immune to witching» гэдгийг ил бичсэн байдаг — өөрөөр хэлбэл **дархлаа нь эрэмбээс өөрөө урган гардаг**, тусдаа flag биш. Хямд, гоё шийдэл.
2. Тэдний wiki-ийн *Mechanics* хуудас нь swap/block циклийг «repeats that cycle a **random number of times** to deal with complicated webs of events and paradoxes» гэж бичсэн байдаг. **Үүнийг бүү хуулж ав.** Санамсаргүй давталтын тоо гэдэг нь детерминист биш, дахин тоглуулах боломжгүй, тест хийх боломжгүй. Энэ бол яг тэр анти-загвар — энэ бичиг баримт үүнээс зайлсхийхийн тулд оршиж байна.

### 1.4 Blood on the Clocktower — хүн хөтлөгч, зориуд алгоритм биш

BOTC wiki (*Abilities*, 2026-09-15-нд татав) шууд хэлдэг:

> «When used, abilities work immediately.» … «The night sheet order is a guide to remind you to wake players … The ability text on the character token is more important than the order of resolution on the night sheet.»

*Storyteller Advice* хуудас: 200+ дүртэй болохоор «some weird situations will arise», хөтлөгч «use your best guess», «your decision is final», хамгийн гол нь «make sure you tell the players that you're making a ruling. It might not be the best call, but at least it will be a clear one.»

**Дүгнэлт:** «Чи таамаглаад шийд» гэдгийг бүтээгдэхүүн болгож гаргах боломжгүй — машин хөтлөгч заавал *шийдэгдэхүйц* байх ёстой. BOTC-оос бидний хуулж авч болох зүйл бол UX-ийн сургамж: **аль дүрэм ажилласныг тоглогчид үргэлж хэлж өг.**

### 1.5 Epicmafia маягийн эрэмбийн тэнцэл тайлалт (зайлсхий)

Wiki Mafia Wiki (*Priorities*):

> **⚠ [баталгаажаагүй] (2026-09-15).** fandom.com нь автомат татахад HTTP 403 буцаадаг тул доорх хэсэг («day abilities sit at priority 0… higher than 1»; тэнцүү priority-тэй мөргөлдөөнийг «who input their action most recently» гэдгээр шийддэг) **эх хуудастай тулгаж баталгаажаагүй**. Хэн хийдэг гэдэг нь нотлогдоогүй гэж үз. **Хэрхэн баталгаажуулах вэ:** https://wikimafia.fandom.com/wiki/Priorities хуудсыг гараар нээж унш.

Зөвлөмж нь хэнийх болохоос үл хамааран өөрөө зөв: **Үүнийг бүү ав.** Илгээсэн хугацааны тэмдэг (timestamp) нь сүлжээнээс хамаардаг, дахин холбогдсоны дараа сэргээгдэхгүй, бага latency-тэй хүнд шагнал өгдөг.

---

## 2. Парадоксын каталог ба бидний баталсан шийдвэр

Мөр бүр бол **шийдэгдэхүйц дүрэм**. «Ð» багана = бидний сонгосон шийдвэр. Эдгээр нь кодонд нэртэй тогтмол (named constant) болно, ингэснээр монгол хэлний дүрмийн дэлгэц тэдгээрийг тайлбарлаж чадна.

| # | Парадокс | Бидний шийдвэр (Ð) | Үндэслэл |
|---|---|---|---|
| P1 | Саатуулагч A нь саатуулагч B-г саатуулж, B нь A-г саатуулна | **Хоёр саатуулалт хоёулаа бүтэлгүйтнэ; A ба B хоёр өөр юу ч хийхгүй** (Zeus Clause / NAR-ийн харилцан саатуулалт) | Mafiascum-ийн уламжлалтай нийцнэ; тэгш хэмтэй, тайлбарлахад амархан |
| P2 | Саатуулагч нь саатуулалтад дархлаатай дүрийг саатуулна | Саатуулалт «буусан» (айлчлал бүртгэгдэнэ, tracker-ууд харна) гэхдээ **ямар ч үр нөлөөгүй** | ToS2-ын саатуулалтын дархлааны жагсаалт |
| P3 | Эмч яг түүнийг алах гэж байгаа тоглогчийг эдгээнэ | Эдгээлт хэрэгжинэ (PROTECT хувин < ATTACK хувин). Эмч яахав үхнэ. **Эдгээлт эмчийг өөрийг нь хэзээ ч хамгаалахгүй.** | Зэрэг алалтын зарчим |
| P4 | Эмч Ганцаарчин / «болгоомжгүй» алуурчинг эдгээнэ | Эдгээлт хэрэгжинэ, **бас** зочин нь зөвхөн *төрөлхийн* хамгаалалтыг тоодоггүй эсрэг довтолгоо (counterattack) хүлээж авна | ToS2 «SK Counterattack bypasses natural Defense only» |
| P5 | Transporter/bus driver өөрийгөө X-тэй солино | Хууль ёсны. Жолооч руу чиглэсэн бүх айлчлал X рүү, X рүү чиглэсэн бүх айлчлал жолооч руу очно, **харин жолоочийн өөрийнх нь гадагш чиглэсэн айлчлал өөрчлөгдөхгүй** (солилт зөвхөн *ирж буй* байг дахин бичнэ) | Солилтыг цэвэр бай-дахин-буулгах функц хэвээр үлдээнэ |
| P6 | Хоёр солигч давхцсан хосуудыг солино | Солилтуудыг **хувингийн эрэмбээр, seed-тэй солбилцлыг ашиглан**, бай-векторын транспозицийн композиц болгож хэрэглэнэ. Үр дүн нь детерминист, эрэмбээс хамаарна, бүртгэгдэнэ | Функцийн композиц; цикл үүсэх боломжгүй |
| P7 | Солигчийг саатуулна | Солигч нар саатуулагчдаас **дээгүүр** байрлана → солилт аль хэдийн болсон; солигчийг саатуулсан ч үр нөлөөгүй | ToS/SC2Mafia уламжлал: «so fast they cannot be role-blocked» |
| P8 | Redirect (Witch/Control) цикл: A нь B-г A руу чиглүүлнэ, B нь A-г хянах байсан | Хянагчид нэг хувинд ажиллана; хянагчийг **хянах боломжгүй** (эрэмбээр дархлаатай). Хоёр дахь хянагчийн хяналт нь аль хэдийн дахин бичигдсэн байж болох бай дээр хэрэгжинэ. CONTROL хувин руу хэзээ ч эргэж ордоггүй тул цикл үүсэхгүй | SC2Mafia «everybody above the Witch is immune to witching» |
| P9 | Шоронгийн дарга мафийн алуурчинг хорино | Хорих = **хамгийн дээд хувинд** үйлдлийг дарах + хоригдсон тоглогчийг Astral бус айлчлалын графаас хасах. **(Бидний дизайнд хоригдол ямар ч хамгаалалт авахгүй — ToS2 ч бас өгдөггүй; §1.1-ийн залруулгыг үз. Хоригдлыг бамбайлмаар байвал таамаглах биш, ил `JAIL_GRANTS_DEFENSE` flag нэм.)** Фракцийн алалт **бүхэлдээ цуцлагдана** (өөр хүн рүү шилжихгүй), хэрэв `MAFIA_KILL_REASSIGN_ON_JAIL` flag асаагүй бол | ToS-той нийцнэ; энэ flag байгаа шалтгаан нь монгол ширээний энгийн тоглолтод «ямар ч байсан нэг хүн үхэх» нь илүү таалагдаж магадгүй |
| P10 | Шоронгийн дарга эсрэг довтолдог алуурчинг хорино | Хоригдсон «болгоомжгүй» алуурчид цаазлагдаагүй бол шоронгийн даргад эсрэг довтолгоо өгнө | ToS2 Jailor хуудас |
| P11 | Хантааз/хуяг vs Powerful довтолгоо | Хантааз Basic хамгаалалт өгнө. Powerful (2) > Basic (1) → үхнэ. `CHARGE_REFUND_ON_OVERKILL` асаагүй бол хантааз **зарцуулагдсан хэвээр** | Түвшний ил харьцуулалт, онцгой тохиолдол байхгүй |
| P12 | Framing хийгдсэн тоглогчийг шалгана | Framing нь тоглогч руу биш, *мөрдөн шалгах контекст* руу бичнэ. Framer-ууд мөрдөгчөөс дээгүүр байрлана; мөрдөгч `effective_alignment_view(target)`-ыг уншина | Шөнийн турш тоглогчийн төлөв өөрчлөгдөхгүй (immutable) байлгана |
| P13 | Хоёр алуурчин бие бие рүүгээ чиглэнэ | Хоёулаа үхнэ. Довтолгоог **ямар ч довтолгоо хэрэгжихээс өмнө авсан хамгаалалтын хормын хувилбар (snapshot)**-тай тулгаж үнэлнэ | «Kills happen simultaneously» (NAR) |
| P14 | Bodyguard нь 2 алуурчны довтолсон тоглогчийг хамгаална | Bodyguard **яг нэг** довтолгоог зогсооно (детерминистээр: seed-тэй эрэмбээр хамгийн түрүүнд байгаа довтлогчийг), тэр довтлогчийг Powerful довтолгоогоор алж, нөгөө довтлогчид үхнэ | ToS2 Bodyguard нэг довтолгоо зогсооно; ToS2 өөрөө тулалдах довтлогчийг **«at random»** сонгодог — бидний seed-тэй сонголт бол дахин тоглуулах боломжийн төлөөх зориудын, баримтжуулсан хазайлт |
| P15 | Довтлогч нь зөөгдчихсөн (transported) тоглогчийг онилно | Довтлогч **дахин буулгасан** байг дагана. Tracker/watcher нар *солилтын дараах* айлчлалыг мэдээлнэ; довтлогчид *солилтын өмнөх* нэрийг хэлнэ. Энэ зориудын тэгш бус байдал бол сонгодог «хэн хэн дээр очив?» алдаа | SC2Mafia хоёр тал хоёулаа бие бие дээрээ очсон гэж боддог гэж баримтжуулсан |
| P16 | Үхсэн тоглогчийн дараалалд орсон үйлдэл | **Шалгах үед** хаягдана (`ACTOR_DEAD`), шийдвэрлэх үед хэзээ ч биш | Доорх I1 инвариант |
| P17 | Veteran alert + саатуулалт | Саатуулалт alert-ыг дийлнэ → veteran хамгаалалтгүй болж, хэнийг ч алахгүй | ToS2 Veteran хуудас, яг үг: «The Veteran can be Roleblocked, which will prevent your Alert from taking effect that Night» (2026-09-15-нд баталгаажсан). **⚠ Энэ нь ноороод бичсэн шаттай зөрчилдөж байна** — §3.2-ын SELF_BUFF тэмдэглэлийг үз |
| P18 | Astral зочин vs Veteran/Bodyguard/Урхи/Хорих | Astral дөрвүүлэнг нь тойрно | ToS2 Keywords |

---

## 3. Хөдөлгүүрийн техникийн тодорхойлолт

### 3.1 Түвшнүүд

Доорх код нь довтолгоо ба хамгаалалтын түвшнийг бүхэл тоо болгож тодорхойлоод, «алах эсэх»-ийг ганц функцээр шийднэ. `innateOnly` гэсэн тугийг зөвхөн SK-маягийн эсрэг довтолгоонд ашиглана — тэр үед олгогдсон (эмчилгээний) хамгаалалтыг тоохгүй, зөвхөн төрөлхийн хамгаалалтыг үзнэ.

```ts
enum AttackLevel  { NONE=0, BASIC=1, POWERFUL=2, UNSTOPPABLE=3, IGNORES_DEFENSE=4 }
enum DefenseLevel { NONE=0, BASIC=1, POWERFUL=2, INVINCIBLE=3 }
// kill iff  attack > defense,  except IGNORES_DEFENSE which always kills.
function lethal(a: AttackLevel, d: DefenseLevel, innateOnly: boolean, innate: DefenseLevel) {
  if (a === AttackLevel.IGNORES_DEFENSE) return true;
  return a > (innateOnly ? innate : d);   // innateOnly = SK-counterattack style
}
```

MVP-д зөвхөн `BASIC` (мафийн хутга), `POWERFUL` (шоронгийн цаазлалт, bodyguard-ын эсрэг цохилт) болон `NONE`/`BASIC` хамгаалалт хэрэглэгдэнэ. Эмчийг `BASIC` хамгаалалт олгодог болго — ингэснээр ирээдүйд «хүчтэй алуурчин» дүр нэмэх дизайны зай үлдэнэ.

### 3.2 Эрэмбийн шат (priority bucket)

Дугаарын хооронд **10-ын завсар** үлдээсэн — ингэснээр шинэ дүр нэмэхэд бүх зүйлийг дахин дугаарлах шаардлагагүй. Дүр бүр `bucket`, `visitType`, `blockable`, `controllable` гэсэн дөрвөн шинжийг зарлана.

**Юу гэсэн үг вэ?** «Bucket» (хувин) гэдэг нь нэг зэрэг хэрэгжих үйлдлүүдийн бүлэг. Хөдөлгүүр хувингуудыг доороос дээш нэг нэгээр нь дамжина. Нэг хувин доторх үйлдлүүдийн дараалал нь seed-ээс гарсан `orderPerm`-оор тогтоно.

| Хувин | Нэр | Гишүүд (MVP + замын зураглал) | Саатуулагдах уу? |
|---:|---|---|---|
| 10 | `SETUP` | шөнийн тоолуур, бүтэн сарны flag, төлөвийн задрал (Hungover дуусах) | — |
| 20 | `JAIL` | Шоронгийн даргын хорих (өдөр сонгосон) | үгүй |
| 30 | `SELF_BUFF` | Хантааз (Vest), Veteran alert, өөрийгөө эдгээх, Fortify | **Veteran alert-ын хувьд тийм** (тэмдэглэлийг үз) |
| 40 | `CONTROL` | Witch/Control, Puppeteer | үгүй |
| 50 | `SWAP` | Transporter / bus driver | үгүй |
| 60 | `BLOCK` | Escort / Consort / Tavern Keeper (Саатуулагч) | тийм (зөвхөн өөр саатуулалтаар, P1-г үз) |
| 70 | `TRAP_GUARD` | Trapper урхи тавих, Bodyguard-ын хамгаалалт хуваарилах | тийм |
| 80 | `DECEIVE` | Framer, Lawyer, Disguiser, Janitor тэмдэглэх | тийм |
| 90 | `PROTECT` | Эмчийн эдгээлт, Cleric barrier, Crusader | тийм |
| 100 | `ATTACK` | **бүх** алалт энд, зэрэг хэрэгжинэ | тийм |
| 110 | `REACTION` | Bodyguard-ын эсрэг цохилт, Veteran-ий буудлага, SK-ийн эсрэг цохилт, урхи хөдлөх | үгүй |
| 120 | `DEATH_APPLY` | үхлийн олонлогийг хэрэгжүүлэх, `diedNight` тэмдэглэх | — |
| 130 | `INFO` | Мөрдөгч/Sheriff, Lookout, Tracker, Spy, Consigliere | тийм (саатуулалтыг 60-д шалгасан) |
| 140 | `POST_DEATH` | Janitor цэвэрлэх, Disguiser солих, Retributionist, Executioner-ийн ялалт шалгах | — |
| 150 | `RECRUIT` | Cult/Vampire элсүүлэх | тийм |
| 160 | `MESSAGES` | тоглогч бүрийн үр дүнгийн мессежийг угсрах | — |
| 170 | `WIN_CHECK` | фракцийн ялалтыг үнэлэх | — |

Энэ шатыг ажиллуулдаг **хоёр хатуу дүрэм**:

1. **Хувин нь зөвхөн өөрөөсөө ЧАНД доогуур хувингийн бичсэн төлөвийг уншиж болно.** Хөгжүүлэлтийн билд дээр write-barrier assertion-оор албадан шалгана.

2а. **⚠ Энэ ноорог дотор илэрсэн алдаа (2026-09-15-нд олдсон).** `SELF_BUFF` нь 30-р хувинд, `BLOCK`-оос (60) *дээгүүр* сууж байгаа бөгөөд саатуулагдахгүй гэж тэмдэглэгдсэн. Энэ нь P17-г хэрэгжих боломжгүй болгож байна: ToS2-ын Veteran хуудас саатуулалт нь «will prevent your Alert from taking effect that Night» гэж тодорхой хэлдэг, гэтэл 60-д хэрэгжиж байгаа саатуулалт 30-д аль хэдийн олгогдсон buff-ыг буцааж татаж чадахгүй. **Код бичихээсээ өмнө засах ёстой** — аль нэгийг нь сонго:

   - **(a)** Veteran alert-ыг `SELF_BUFF_BLOCKABLE` гэсэн шинэ хувинд, **65** дугаарт (BLOCK-ын дараа) шилжүүл. Хантааз (зарцуулагддаг зүйл, ToS-д саатуулалтад дархлаатай) 30-д үлдэнэ.
   - **(b)** Alert-ыг 30-д үлдээгээд, BLOCK хувин `alert` болон түүний олгосон Basic хамгаалалтыг ил цуцалдаг болго.

   (a) хувилбар «хувин зөвхөн чанд доогуур хувингийн төлөвийг уншина» гэсэн инвариантыг хадгална; (b) хувилбар түүнийг зөрчинө. **(a)-г зөвлөж байна.**

3. **Хувин дотор** үйлдлүүдийг `orderPerm`-оор солбилцуулсан `seatIndex`-ээр эрэмбэлнэ. `orderPerm` бол тоглоом эхлэхэд ганц удаа үүсгэгддэг seed-тэй солбилцол:

   `orderPerm = shuffle(seats, splitmix64(gameSeed ^ 0xN1GHT))`

   бөгөөд энэ нь үйл явдлын бүртгэл (event log) рүү бичигдэнэ. **Илгээсэн хугацаагаар хэзээ ч эрэмбэлэхгүй.**

### 3.3 Өгөгдлийн загвар

Доорх бүтцүүд нь шөнийн хөдөлгүүрийн бүх өгөгдлийг агуулна. `submittedAtMs` талбар байгаа ч тэр нь **зөвхөн аудитын зориулалттай, эрэмбэлэхэд ХЭЗЭЭ Ч ашиглагдахгүй** гэдгийг анхаар.

```ts
type ActionIntent = {
  intentId: string;        // client-generated UUID -> idempotency key
  gameId: string; night: number;
  actorId: PlayerId;       // WHO submitted
  abilityId: AbilityId;    // which of the actor's abilities
  targets: PlayerId[];     // 0, 1 or 2 (swap takes 2)
  submittedAtMs: number;   // audit only, NEVER used for ordering
  clientSeq: number;       // per-device monotonic; last-write-wins per (actor, ability)
};

type ResolvedAction = ActionIntent & {
  bucket: number;
  effTargets: PlayerId[];  // after CONTROL + SWAP rewriting
  blocked: boolean; blockReason?: BlockReason;
  visitType: 'HARMFUL'|'NON_HARMFUL'|'ASTRAL'|'NONE';
};

type NightState = {
  alive: Set<PlayerId>;
  innateDefense: Map<PlayerId, DefenseLevel>;
  grantedDefense: Map<PlayerId, DefenseLevel>;   // from PROTECT bucket
  visitGraph: Array<{from: PlayerId; to: PlayerId; type: VisitType; abilityId: AbilityId}>;
  pendingAttacks: Array<{from: PlayerId; to: PlayerId; level: AttackLevel; innateOnly: boolean; tag: DeathTag}>;
  frames: Map<PlayerId, AlignmentView>;
  statuses: Map<PlayerId, Set<Status>>;          // HUNGOVER, JAILED, DOUSED, ...
  deaths: Array<{victim: PlayerId; killers: PlayerId[]; tags: DeathTag[]}>;
  messages: Map<PlayerId, MessageCode[]>;        // codes + params, localized later
};
```

**Санаа (intent) илгээнэ, үр нөлөө (effect) биш.** Клиент `{abilityId:'MAFIA_KILL', targets:['Бат']}` гэж илгээнэ, хэзээ ч «Бат үхлээ» гэж илгээхгүй. Бүх үр дагаврыг сервер эзэмшинэ. Офлайн, нэг утас дамжуулах горимд «сервер» гэдэг чинь яг тэр төхөөрөмж дээр ажиллаж байгаа **ижил цэвэр функц** — яг үүний улмаас хөдөлгүүр IO-гүй байх ёстой.

**Шалгалт (илгээх мөчид хийгдэж, төрөлжсөн татгалзал буцаана):**

| Код | Нөхцөл |
|---|---|
| `ACTOR_DEAD` | үйлдэгч `alive` дотор байхгүй |
| `NOT_YOUR_ABILITY` | тэр чадвар үйлдэгчийн дүрд байхгүй |
| `PHASE_CLOSED` | шөнө аль хэдийн лацдагдсан |
| `TARGET_DEAD` / `TARGET_SELF_FORBIDDEN` / `TARGET_DUPLICATE` | онилох дүрмүүд |
| `CHARGES_EXHAUSTED` | `uses` тоолуур 0 дээр байна |
| `COOLDOWN` | жишээ нь Шоронгийн дарга дараалсан хоёр шөнө нэг тоглогчийг сонгосон |
| `TARGET_IMMUNE_SETUP` | жишээ нь фракцийн алалтаар өөрийн мафийн гишүүнийг онилох боломжгүй |

Шалгалт нь *цэвэр* бөгөөд клиент дээр (шууд гарах монгол хэлний алдааны бичвэр) болон сервер дээр (эрх мэдэл) хоёуланд нь ажиллана. **Шийдвэрлэх үед хэзээ ч шалгаж болохгүй** — энэ нь I1 инвариантыг эвдэж, дахин тоглуулалтыг зөрүүлнэ.

### 3.4 Фракцийн (мафийн) бүлгийн шийдвэр

Гурван горим байна, тохиргоо тус бүрээр сонгоно. Сонгосон горим шөнийн үйл явдалд бичигдэнэ.

| Горим | Дүрэм | Детерминист тэнцэл тайлалт |
|---|---|---|
| `DESIGNATED_KILLER` (үндсэн, ToS маягийн) | Ахлагчийн (Godfather) сонгосон бай хожино; Ахлагч илгээгээгүй бол Mafioso-гийнх; томилогдсон алуурчин үхсэн/хоригдсон/саатуулагдсан бол алалт цуцлагдана | хамаарахгүй |
| `MAJORITY_VOTE` (Werewolf маягийн) | Мафийн саналыг тоолно; хамгийн олон санал авсан нь хожино | Тэнцвэл → тэнцсэн баруудаас **`orderPerm` индекс нь хамгийн бага**-г сонгоно, санамсаргүйгээр биш. `TIEBREAK_SEEDED` гэж бүртгэнэ |
| `LAST_SUBMITTED` | Ил тодоор **санал болгохгүй** | — (timestamp эрэмбэ дахин үүсгэгдэхгүй) |

Wolfy (бодит бүтээгдэхүүн болсон werewolf тоглоом, тусламжийн хуудсыг 2026-09-15-нд татав): «if the vote at night leads to a tie, a player dies randomly among those who were targeted.» Тэр **мэдрэмжийг** хадгал, гэхдээ санамсаргүй байдлыг seed-тэй бол.

### 3.5 Хугацаа дуусах / автомат алгасалт

Доорх псевдо-код нь шөнийн таймер дуусах үед юу болохыг тодорхойлно. `sealNight` нь идемпотент — хэдэн ч удаа дуудсан ижил үр дүн өгнө.

```
on nightTimerExpire(gameId, night):
   sealNight(gameId, night)                # idempotent; writes NightSealed event
   for each alive player with an unsubmitted mandatory ability:
       record AutoPass{actor, abilityId, reason: 'DEADLINE'}
   resolveNight(gameId, night)
```

Үндсэн тохиргоо: **автомат алгасалт = юу ч хийхгүй**, хэзээ ч автоматаар бай сонгохгүй. Ангийн тоглолтод санамсаргүй автомат алалт нь «утас миний найзыг шалтгаангүй алчихлаа» гэж ойлгогдоно. `FORCE_FACTION_KILL_ON_TIMEOUT` flag (үндсэндээ унтраалттай) нь онлайн зэрэглэлийн тоглолтод зориулагдсан; асаалттай үед бай нь `orderPerm` хамгийн бага амьд мафи бус тоглогч болно, `AUTO_TARGET_SEEDED` гэж бүртгэгдэнэ.

Таймерууд (бидний дизайн, **[тооцоолол]** — телеметрээс хойш тохируулна; баталгаажуулах арга: бодит тоглолтын статистик цуглуулж дундаж эргэлтийн хугацааг хэмжих):

| Горим | Таймер |
|---|---|
| Офлайн, нэг утас дамжуулах | **таймергүй** (утас барьсан хүн «Дууслаа» товч дарна) |
| Нэг өрөө, олон төхөөрөмж | **30 сек** |
| Онлайн | **37 сек** — жанрын нормтой таарна (ToS2 = 37 сек / rapid 10 сек) |

### 3.6 Детерминизм, үйл явдлын бүртгэл, идемпотент дахин шийдвэрлэлт

Үйл явдлын бүртгэл (event log) нь тоглоом бүрээр, зөвхөн нэмэгддэг (append-only):

```
GameCreated{gameId, seed, roster[], setupId, orderPerm[]}
NightOpened{night}
IntentSubmitted{intentId, night, actorId, abilityId, targets[], clientSeq}
IntentWithdrawn{intentId}
NightSealed{night, intentSnapshotHash}
NightResolved{night, resultHash, deaths[], messages[]}
```

`resolveNight` бол **цэвэр функц**: `(setup, rosterState, intents[], seed, night) -> NightResult`. `Date.now()` байхгүй, `Math.random()` байхгүй, map-ийн давталтын дарааллаас хамаарахгүй (давтахаасаа өмнө цуглуулга бүрийг эрэмбэл), хөвөгч таслалтай тоо (float) байхгүй.

Дахин холбогдоход зориулсан идемпотент байдал:

```
function resolveNightIdempotent(gameId, night):
    snap = intentsForNight(gameId, night) sorted by (bucket, orderPerm[actor], abilityId, intentId)
    h    = sha256(canonicalJson(snap) + seed + night)
    cached = store.get(gameId, night)
    if cached && cached.inputHash == h: return cached.result      # no recompute, byte-identical
    result = resolveNight(...)                                     # pure
    store.putIfAbsent(gameId, night, {inputHash: h, result})       # single-writer, CAS
    return store.get(gameId, night).result
```

Дахин холбогдсон утас `NightResolved`-ыг дахин тоглуулж дэлгэцээ дахин зурна; зөвхөн офлайн горимд л локалаар дахин тооцоолно, тэнд hash шалгалт нь таарч байгааг баталгаажуулна.

Nightfall (нээлттэй эхийн TypeScript werewolf хөдөлгүүр, README-г 2026-09-15-нд татав) энэ загварыг батална:

- «the same seed reproduces a match bit-for-bit» — ижил seed тоглолтыг бит-бит давтана;
- ботын RNG нь «counter-based, so one integer reopens the exact stream» — нэг бүхэл тоо яг тэр урсгалыг дахин нээнэ;
- «each settle function is idempotent, so a phase replayed after a restart never turns anyone twice» — дахин эхлүүлсний дараа дахин тоглуулсан үе шат хэнийг ч хоёр дахин эргүүлэхгүй.

*(Гурван ишлэл бүгд нийтийн README дээр 2026-09-15-нд баталгаажсан.)*

> **Баталгаажуулалт (2026-09-15):** Тестийн тооны залруулга — **2,228** гэдэг нь **зөвхөн game-engine багцын** тест. Repo-гийн README нийтдээ **4,739 тест** байгаа гэж бичсэн (158 shared / 2,228 game-engine / 973 server / 1,380 web). Энэ бол төслийн өөрийнх нь мэдүүлсэн тоо, бид өөрсдөө ажиллуулж шалгаагүй. Эх сурвалж: https://github.com/the-nightforge/Nightfall

### 3.7 Шийдвэрлэх алгоритм (псевдо-код)

Энэ бол бүх бүлгийн хамгийн чухал блок. Хөдөлгүүр дуудагчийн төлөвийг **хэзээ ч өөрчилдөггүй** (гүн хуулбар авна), үйлдлүүдийг нэг бүрэн эрэмбэнд оруулаад, хувингуудыг доороос дээш дамжина. `# ---- 20 JAIL ----` гэх мэт тайлбар бүр нь §3.2-ын нэг хувинтай тохирно.

```
function resolveNight(setup, state, intents, seed, night) -> NightResult:
  S = NightState.from(state)                        # deep copy; engine never mutates caller state
  A = [toResolvedAction(i) for i in intents if validate(i, S).ok]
  A = dedupe(A, key = (actorId, abilityId), keep = max clientSeq)
  A.sort(by = (bucket, orderPerm[actorId], abilityId, intentId))   # total order, no timestamps

  # ---- 20 JAIL -------------------------------------------------------------
  for a in A.bucket(JAIL):
      S.status(a.effTargets[0]).add(JAILED)
      if setup.JAIL_GRANTS_DEFENSE:                      # OFF by default; ToS2 grants the prisoner NO defense
          S.grantedDefense[a.target] = max(.., POWERFUL)
      removeAllVisitsTouching(A, a.target, exceptAstral = true)
      markBlocked(A.byActor(a.target), reason = JAILED)

  # ---- 30 SELF_BUFF --------------------------------------------------------
  for a in A.bucket(SELF_BUFF): applySelfBuff(S, a)     # vest, alert

  # ---- 40 CONTROL ----------------------------------------------------------
  for a in A.bucket(CONTROL):                            # controllers are control-immune by ordering
      victim = a.effTargets[0]; newTarget = a.effTargets[1]
      if controlImmune(victim) or isJailed(victim): a.failed = CONTROL_IMMUNE; continue
      for v in A.byActor(victim) where v.bucket > CONTROL: v.effTargets = [newTarget]
      S.status(victim).add(HUNGOVER)

  # ---- 50 SWAP -------------------------------------------------------------
  swapMap = identity()
  for a in A.bucket(SWAP):                               # compose transpositions in total order
      swapMap = compose(swapMap, transpose(a.effTargets[0], a.effTargets[1]))
  for v in A where v.bucket > SWAP:
      v.effTargets = v.effTargets.map(swapMap)           # ONLY incoming targets are remapped (P5)

  # ---- 60 BLOCK ------------------------------------------------------------
  blocks = A.bucket(BLOCK)
  mutual = findMutualPairs(blocks)                       # P1: symmetric cycles of length >= 2
  for pair in mutual: failAll(A.byActor(pair.members))   # Zeus Clause
  for b in blocks if not b.failed:
      t = b.effTargets[0]
      if roleblockImmune(t): b.landedButNoEffect = true
      else: markBlocked(A.byActor(t) where bucket > BLOCK, reason = ROLEBLOCKED)
      S.status(t).add(HUNGOVER)

  # ---- 70 TRAP_GUARD / 80 DECEIVE -----------------------------------------
  for a in A.bucket(TRAP_GUARD) if !a.blocked: S.guards.push({by:a.actorId, on:a.effTargets[0]})
  for a in A.bucket(DECEIVE)    if !a.blocked: S.frames[a.effTargets[0]] = a.framedView

  # ---- 90 PROTECT ----------------------------------------------------------
  for a in A.bucket(PROTECT) if !a.blocked:
      t = a.effTargets[0]
      S.grantedDefense[t] = max(S.grantedDefense[t], a.defenseGranted)
      S.protectors[t].push(a.actorId)
      pushVisit(S, a.actorId, t, NON_HARMFUL)

  # ---- 100 ATTACK (declare, do not apply) ---------------------------------
  defSnapshot = freeze(effectiveDefense(S))              # P13: everyone shoots simultaneously
  for a in A.bucket(ATTACK) if !a.blocked:
      t = a.effTargets[0]
      pushVisit(S, a.actorId, t, HARMFUL)
      S.pendingAttacks.push({from:a.actorId, to:t, level:a.attackLevel, innateOnly:a.innateOnly, tag:a.tag})

  # ---- 110 REACTION --------------------------------------------------------
  for g in S.guards sorted by orderPerm:                 # P14: one attack each, earliest attacker
      hit = S.pendingAttacks.filter(p => p.to == g.on && isHarmful(p)).sortedBy(orderPerm).first()
      if hit:
          S.pendingAttacks.remove(hit)                                        # target saved
          S.pendingAttacks.push({from:g.by, to:hit.from, level:POWERFUL, tag:BODYGUARD})
          S.pendingAttacks.push({from:hit.from, to:g.by, level:POWERFUL, tag:BODYGUARD_FIGHT})
  for v in S.alerts:                                     # Veteran
      for e in S.visitGraph where e.to == v && e.type != ASTRAL:
          S.pendingAttacks.push({from:v, to:e.from, level:POWERFUL, tag:VETERAN})
  applyCounterattacks(S)                                 # SK/uncautious killers, innateOnly = true

  # ---- 120 DEATH_APPLY -----------------------------------------------------
  for p in S.pendingAttacks sorted by (orderPerm[from], tag):
      if lethal(p.level, defSnapshot[p.to], p.innateOnly, S.innateDefense[p.to]):
          S.deaths.addOrMerge(p.to, killer = p.from, tag = p.tag)
      else:
          S.messages[p.to].push(MSG.ATTACKED_BUT_SURVIVED)
          for prot in S.protectors[p.to]: S.messages[prot].push(MSG.YOUR_TARGET_WAS_ATTACKED)
  for d in S.deaths: S.alive.delete(d.victim)

  # ---- 130 INFO ------------------------------------------------------------
  for a in A.bucket(INFO) if !a.blocked:
      S.messages[a.actorId].push(investigate(S, a))      # reads S.frames, not raw roles

  # ---- 140..170 ------------------------------------------------------------
  runPostDeath(S); runRecruit(S); buildMessages(S)
  return { deaths: S.deaths, messages: S.messages, visitGraph: S.visitGraph,
           resultHash: sha256(canonicalJson(...)) }
```

Гол санааг монголоор давтъя: довтолгоо 100-д зөвхөн **зарлагдана**, 120-д л **хэрэгжинэ**. Хооронд нь 110-д хариу үйлдлүүд орж ирнэ. Ингэснээр «хэн хэнийг түрүүлж буудсан бэ?» гэсэн асуулт огт үүсэхгүй — бүгд зэрэг буудсан, хамгаалалтын snapshot 100-д хөлдсөн.

### 3.8 Тоглогч бүрийн мессеж

**Код + параметр** ялгаруул, хэзээ ч бэлэн бичвэр биш. Монгол хэлний давхарга бол тусдаа хүснэгт — ингэснээр үг найруулгыг өөрчлөхөд хөдөлгүүрийг хөндөхгүй.

| Код | Параметр | Монгол (ноорог) |
|---|---|---|
| `MSG.ROLEBLOCKED` | — | «Чамайг хэн нэгэн саатуулсан тул үйлдэл хийж чадсангүй.» |
| `MSG.ATTACKED_BUT_SURVIVED` | — | «Шөнө чам руу довтолсон ч чи амьд үлдлээ.» |
| `MSG.YOU_HEALED_SOMEONE` | — | «Чи өнөө шөнө нэг хүний амийг аварлаа.» |
| `MSG.INVESTIGATE_RESULT` | targetName, view | «{target} — {үр дүн}» |
| `MSG.DIED_BY` | tag | «{нэр} шөнө амь үрэгдэв.» |
| `MSG.JAILED_NO_ACTION` | — | «Чи шоронд хоригдсон тул юу ч хийж чадсангүй.» |

---

## 4. Тестлэлт

### 4.1 Инвариантууд (шийдвэрлэсэн **шөнө бүр** дээр шалгана, прод дээр flag-ийн ард)

**Юу гэсэн үг вэ?** «Инвариант» гэдэг нь ямар ч тохиолдолд үнэн байх ёстой нөхцөл. Зөрчигдвөл энэ бол алдаа — таамаглал биш.

| ID | Инвариант |
|---|---|
| I1 | Лацдах мөчид үхсэн байсан үйлдэгчтэй `ResolvedAction` байхгүй |
| I2 | (үйлдэгч, чадвар) хос тус бүрээр хамгийн ихдээ нэг үйлдэл хэрэгжинэ |
| I3 | `deaths ⊆ alive_at_seal`; `|alive_after| = |alive_at_seal| - |deaths|` |
| I4 | Эдгээлт нь олгогдсон хамгаалалтаас ≤ түвшний довтолгоог чанд цуцална; түүнээс дээш түвшний довтолгоо хэзээ ч цуцлагдахгүй |
| I5 | Үхэл бүр ≥ 1 алуурчинтай, эсвэл ил `tag=ENVIRONMENT` тэмдэгтэй |
| I6 | `visitGraph`-ийн ирмэг бүр саатуулагдаагүй нэг үйлдэлтэй тохирно, Astral дарагдалтаас бусад |
| I7 | `resolveNight`-ыг ижил оролтоор хоёр удаа дуудвал → ижил `resultHash` |
| I8 | Шийдвэрлэлт цаг болон глобал RNG-г уншихгүй (тестэд `Date`/`Math.random`-ыг алдаа шиддэг stub-аар сольж албадан шалгана) |
| I9 | Ямар ч хувин өөрөөсөө доогуур хувингийн уншдаг төлөв рүү бичихгүй (write-barrier) |
| I10 | Саатуулагдсан үйлдэгч ямар ч үр нөлөө үзүүлэхгүй, гэхдээ чадвар нь `landedButNoEffect` үед л айлчлалын ирмэг үлдээж болно |
| I11 | Амьд тоглогч бүр шөнө бүр ≥ 1 мессеж авна (наад зах нь `MSG.QUIET_NIGHT`) |
| I12 | Нийт зарцуулагдсан цэнэг ≤ тоглоом эхлэхэд зарласан цэнэг |

### 4.2 Шинжийн тест (property test — fast-check / Hypothesis маягийн)

Шинжийн тест гэдэг нь ганц жишээ биш, **бүх боломжит оролт дээр үнэн байх ёстой дүрмийг** бичиж, санамсаргүй олон оролт үүсгээд шалгадаг арга.

```
property "resolution is order-independent w.r.t. submission order":
  forall setup, intents:
    resolve(shuffle(intents, k1)).resultHash == resolve(shuffle(intents, k2)).resultHash

property "no attack kills a player whose effective defense >= attack level":
  forall night: for all deaths d: exists attack a on d with a.level > defSnapshot[d]

property "mutual roleblock annihilates":
  forall A,B roleblockers with A->B and B->A: effects(A) == {} and effects(B) == {}

property "swap is an involution on the target vector":
  forall single swapper s(x,y): applyTwice(s) == identity

property "replay equals live":
  forall game: replayFromEventLog(log).finalState == liveState
```

### 4.3 Fuzz харнесс

Fuzz гэдэг нь санамсаргүй тоглоомуудыг олон мянгаар үүсгээд, хөдөлгүүрийг эвдэрдэг эсэхийг шалгах арга. Зориуд **хууль бус тохиргоо** (давхардсан дүр гэх мэт) ч үүсгэдэг гэдгийг анхаар.

```
for seed in 0..1_000_000:
    rng   = splitmix64(seed)
    n     = rng.int(5, 20)
    roles = rng.sampleRoles(n, allRoles, allowDuplicates=true)   # deliberately illegal setups too
    game  = newGame(roles, seed)
    while !game.over && game.night < 30:
        for p in game.alive:
            with prob 0.85: submit(randomLegalIntent(p, rng))    # 15% no-shows exercise auto-pass
        sealAndResolve(game)
        assertAllInvariants(game)
        assert resolveNightIdempotent(game, night) == previousResult
    corpus.record(seed) if crashed or invariant failed
```

PR бүрд **10 мянган seed**, шөнө бүр **1 сая seed** ажиллуул. Дээр нь нэм:

- **Дифференциал тест** — гэнэн (naïve) O(n²) лавлагаа хэрэгжүүлэлтийг оновчилсон хөдөлгүүртэй fuzz тохиолдол бүр дээр харьцуулна.
- **Golden snapshot тест** — 18 парадоксыг fixture болгож, хүлээгдэж буй JSON-ыг repo-д commit хийнэ. Ингэснээр шийдвэрийн аль нэг нь чимээгүйхэн өөрчлөгдөх боломжгүй болно.

Эдгээрийн нийтлэг нэр нь **deterministic simulation testing (DST)**. Antithesis-ийн баримт бичиг (2026-09-15-нд татав) үүнийг ингэж тодорхойлдог: *«Deterministic simulation testing (DST) involves placing software under test in a simulated, deterministic environment.»* Дахин үүсгэх боломжийн давуу талыг ингэж бичсэн: *«bugs found via DST are a lot easier to debug, as execution can be rolled back and inspected at multiple points in time»* — уламжлалт тестлэлттэй харьцуулбал тэнд *«we may see an error, have no information on how to reproduce it, and never see it again.»*

> **Баталгаажуулалт (2026-09-15):** Өмнөх ноороод «you can reliably reproduce a bug that you see on a given run» гэсэн ишлэл байсан нь **тэр хуудсан дээр огт байхгүй**. Жинхэнэ тодорхойлолтоор сольсон. Эх сурвалж: https://antithesis.com/docs/resources/deterministic_simulation_testing/

---

## 5. Бодит жишээ — 12 тоглогч, нэг шөнө

Тохиргоо `MN_CLASSIC_12`: **3 Мафи** (1 Ахлагч `GF`, 2 Алуурчин/Mafioso), **1 Эмч** (Doctor), **1 Мөрдөгч** (Detective), **1 Хамгаалагч** (Bodyguard), **1 Шоронгийн дарга** (Jailor), **1 Саатуулагч** (Escort/roleblocker), **4 Иргэн**.

Суудал 1–12 = P1…P12. `gameSeed=42` → `orderPerm = [P7,P3,P11,P1,P9,P5,P12,P2,P8,P4,P6,P10]` (жишээ болгон).

Дүрүүд: P1 Ахлагч (GF), P2 Алуурчин (Mafioso), P3 Алуурчин (Mafioso), P4 Эмч, P5 Мөрдөгч, P6 Хамгаалагч, P7 Шоронгийн дарга, P8 Саатуулагч, P9–P12 Иргэн.

**2 дахь шөнийн санаанууд (intents):**

| Үйлдэгч | Чадвар | Бай |
|---|---|---|
| P7 Шоронгийн дарга | `JAIL` (өдөр сонгосон) | P3 |
| P8 Саатуулагч | `ROLEBLOCK` | P4 (Эмч) |
| P1 Ахлагч | `MAFIA_KILL` (томилогдсон) | P5 |
| P2 Алуурчин | `MAFIA_KILL` | P9 (тоогдохгүй — Ахлагч томилогдсон) |
| P4 Эмч | `HEAL` | P5 |
| P6 Хамгаалагч | `GUARD` | P5 |
| P5 Мөрдөгч | `INVESTIGATE` | P2 |

**Алхам алхмаар:**

1. **Лацдах (Seal).** 7 санаа шалгалтыг давна. P2-ийн алалт `DESIGNATED_KILLER` фракцийн дүрмээр хаягдана (P2 руу `MSG.FACTION_TARGET_OVERRIDDEN` очно). P3 хоригдсон тул түүний байхгүй үйлдэл ямар ч ач холбогдолгүй.
2. **Хувин 20 JAIL.** P3 → `JAILED`, ирж буй бүх Astral бус айлчлал хасагдана. Шоронгийн дарга өнөө шөнө цаазлахгүй.
3. **Хувин 30 SELF_BUFF.** Байхгүй.
4. **Хувин 40 CONTROL / 50 SWAP.** Байхгүй. `effTargets` өөрчлөгдөхгүй.
5. **Хувин 60 BLOCK.** P8 → P4. Харилцан хос байхгүй. P4 саатуулалтад дархлаагүй → **P4-ийн эдгээлт саатуулагдсан гэж тэмдэглэгдэнэ**. P4 `HUNGOVER` болно (дараа шөнө нь саатуулалтад дархлаатай). Айлчлалын ирмэг P8→P4 (NON_HARMFUL).
6. **Хувин 70 TRAP_GUARD.** P6 нь P5-г хамгаална. Ирмэг P6→P5 (NON_HARMFUL).
7. **Хувин 80 DECEIVE.** Байхгүй.
8. **Хувин 90 PROTECT.** P4-ийн эдгээлт саатуулагдсан → **P5 ямар ч хамгаалалт авахгүй**. Энэ бол драмын оргил мөч: Саатуулагч санаандгүйгээр Эмчийг унтраачихлаа.
9. **Хувин 100 ATTACK.** `defSnapshot = {бүгд: NONE}`. (P3 хоригдсон ч §1.1-ийн залруулгын дагуу хорих нь **ямар ч** хамгаалалт өгдөггүй — тэр зүгээр л хүрэх боломжгүй болсон, учир нь Astral бус айлчлалууд 20-р хувинд хасагдсан.) P1 нь `{from:P1,to:P5,level:BASIC}` зарлана. Ирмэг P1→P5 (HARMFUL).
10. **Хувин 110 REACTION.** P5 дээрх Guard нь P5 рүү чиглэсэн хортой довтолгоог хардаг → `[P1]`. `orderPerm`-оор хамгийн түрүүнд байгаа нь P1. Тэр довтолгоог хасна (P5 аврагдлаа). `{from:P6,to:P1,level:POWERFUL,tag:BODYGUARD}` ба `{from:P1,to:P6,level:POWERFUL,tag:BODYGUARD_FIGHT}` гэсэн хоёрыг нэмнэ.
11. **Хувин 120 DEATH_APPLY.** P1: довтолгоо POWERFUL(2) > хамгаалалт NONE(0) → **P1 үхнэ**. P6: POWERFUL(2) > NONE(0) → **P6 үхнэ**. P5 амьд үлдэж `MSG.ATTACKED_BUT_SURVIVED` + `MSG.BODYGUARD_SAVED_YOU` авна. Амьд: **10**.
12. **Хувин 130 INFO.** P5 нь P2-г шалгана. P2 framing хийгдээгүй → үр дүн `SUSPICIOUS`. P5 нь `MSG.INVESTIGATE_RESULT{P2, SUSPICIOUS}` авна.
13. **Хувин 140 POST_DEATH.** P1 Ахлагч байсан → P2 дэвшинэ (`MSG.PROMOTED_TO_GODFATHER`).
14. **Хувин 170 WIN_CHECK.** Мафи 2 (P2, P3) vs Хотынхон 8 → ялалт байхгүй.

**Тоглогч бүрийн шөнийн тайлан:**

| Тоглогч | Мессеж |
|---|---|
| P1 | «Чи Хамгаалагчтай тулалдаж амь үрэгдлээ» |
| P4 | «Чамайг саатуулсан» |
| P5 | «Чам руу довтолсон ч Хамгаалагч аварлаа» + шалгалтын үр дүн |
| P6 | «Чи хамгаалж байгаад амь үрэгдлээ» |
| P7 | «P3-г шөнөжин хорьсон» |
| P8 | «Чи P4-г саатуулсан» |
| Иргэд | `MSG.QUIET_NIGHT` |

`resultHash` нь үйл явдлын бүртгэлд бичигдэнэ. Дахин холбогдсоны дараа шийдвэрлэлтийг дахин ажиллуулбал **яг энэ** үр дүнг буцаана.

---

## 6. Энэ төсөлд тусгайлан хамаарах зөвлөмжүүд

1. **Зөвхөн 20/60/90/100/120/130/160/170 хувинтай MVP шатыг** гарга — хорих, саатуулах, эдгээх, алах, мэдээлэл. Дөрвөн дүр (**Мафи, Эмч, Мөрдөгч, Иргэн**) үүнээс илүүг шаардахгүй, гэхдээ шат нь ирээдүйд бэлэн.
2. Хөдөлгүүрийг **IO-гүй, цэвэр TypeScript (эсвэл Dart) багц** болгон бич. Офлайн, нэг төхөөрөмжийн хөтлөгч болон онлайн серверийн хооронд **бит-бит ижил** код хуваалцана. Тэгвэл офлайн горим бол «сервер чиний халаасанд», хоёр дахь кодын сан биш.
3. Үйл явдлын бүртгэлийг офлайн үед төхөөрөмж дээрх **SQLite**-д, онлайн үед **Postgres**-д хадгал. «Шөнө юу болсон бэ?» гэсэн эргэн харах дэлгэц бол зүгээр л бүртгэлийн дахин тоглуулалт — үнэгүй боломж, бас 15 настай хүүхэд «утас луйварджээ» гэж зүтгэх үед чиний хамгийн сайн дибаг хийх хэрэгсэл.
4. **Илгээсэн хугацааг эрэмбэлэхэд хэзээ ч бүү ашигла.** `gameSeed`-ээс гарсан `orderPerm`-ыг ашигла, `GameCreated` дээр бүртгэ.
5. Автомат алгасалтын үндсэн утга «юу ч болохгүй» байг. `FORCE_FACTION_KILL_ON_TIMEOUT`-ыг зөвхөн онлайн зэрэглэлийн тоглолтод л нээ.
6. **18 парадоксын шийдвэрийг монгол хэлээр дүрмийн дэлгэцэнд** тавь. BOTC-ын зарчим энд ч хүчинтэй: тодорхой шийдвэр нь төгс шийдвэрээс дээр — гэхдээ зөвхөн аль дүрэм ажилласныг тоглогчид хэлж өгсөн тохиолдолд.

---

## Эх сурвалж

- Town of Salem Wiki (wiki.gg), *Attributes (ToS2)* — https://townofsalem.wiki.gg/wiki/Attributes_(ToS2)
- Town of Salem Wiki (wiki.gg), *Traits (ToS2)* — https://townofsalem.wiki.gg/wiki/Traits_(ToS2)
- Town of Salem Wiki (wiki.gg), *Keywords (ToS2)* — https://townofsalem.wiki.gg/wiki/Keywords_(ToS2)
- Town of Salem Wiki (wiki.gg), *Game Phases (ToS2)* — https://townofsalem.wiki.gg/wiki/Game_Phases_(ToS2)
- Town of Salem Wiki (wiki.gg), *Bodyguard (ToS2)* — https://townofsalem.wiki.gg/wiki/Bodyguard_(ToS2)
- Town of Salem Wiki (wiki.gg), *Jailor (ToS2)* — https://townofsalem.wiki.gg/wiki/Jailor_(ToS2)
- Town of Salem Wiki (wiki.gg), *Veteran (ToS2)* — https://townofsalem.wiki.gg/wiki/Veteran_(ToS2)
- Steam, Town of Salem 2 discussion "Night priority" (dev shapesifter13 on priority buckets) — https://steamcommunity.com/app/2140510/discussions/1/4208119548513190883/
- MafiaWiki, *Natural Action Resolution* — https://wiki.mafiascum.net/index.php?title=Natural_Action_Resolution
- MafiaWiki, *Reasonable Action Resolution* — https://wiki.mafiascum.net/index.php?title=Reasonable_Action_Resolution
- MafiaWiki, *Triplicate Action Resolution* — https://wiki.mafiascum.net/index.php?title=Triplicate_Action_Resolution
- MafiaWiki, *Serial Night Action Resolution Framework* — https://wiki.mafiascum.net/index.php?title=Serial_Night_Action_Resolution_Framework
- MafiaWiki, *Bus Driver* — https://wiki.mafiascum.net/index.php?title=Bus_Driver
- SC2Mafia, *Game Rules, Order of Operations and FAQ* — https://sc2mafia.com/forum/showthread.php/9152-Game-Rules-Order-of-Operations-and-FAQ
- SC2Mafia Wiki, *Mechanics* — http://sc2mafia.com/wiki/Mechanics
- Blood on the Clocktower Wiki, *Abilities* — https://wiki.bloodontheclocktower.com/Abilities
- Blood on the Clocktower Wiki, *Storyteller Advice* — https://wiki.bloodontheclocktower.com/Storyteller_Advice
- Blood on the Clocktower Wiki, *Trouble Brewing* — https://wiki.bloodontheclocktower.com/Trouble_Brewing
- Wolfy help, *Playing the Werewolf* — https://help.wolfy.net/en/article/playing-the-werewolf-3w2rq6/
- Wiki Mafia Wiki, *Priorities* — https://wikimafia.fandom.com/wiki/Priorities
- Nightfall (open-source deterministic werewolf engine) — https://github.com/the-nightforge/Nightfall
- Open Mafia Engine — https://github.com/open-mafia/open_mafia_engine
- Pocket Werewolf — https://github.com/AtaCanYmc/pocket-werewolf
- Antithesis Docs, *Deterministic simulation testing* — https://antithesis.com/docs/resources/deterministic_simulation_testing/
- Antithesis Docs, *Property-based testing* — https://antithesis.com/docs/resources/property_based_testing/
- BotC Tools, Trouble Brewing night order — https://botc-tools.xyz/script.html?page=night&id=178

---

### Баталгаажуулалтын тэмдэглэл (fact-check шалгалт, 2026-09-15)

**Анхдагч хуудастай тулгаж 2026-09-15-нд баталгаажсан зүйлс:** ToS2-ын дөрвөн довтолгооны түвшин ба дөрвөн хамгаалалтын түвшин, тэдгээрийг `attack > defense` болгон хураах; шөнө = 37 сек / Rapid 10 сек; Astral / Harmful / Non-Harmful айлчлалын тодорхойлолт; Hungover («Players who are Hungover cannot be Roleblocked or Controlled that night»); Veteran-ий саатуулалтын өгүүлбэр; Jailor Execute = Powerful довтолгоо, N1-д цаазлахгүй, дараалсан хоёр шөнө хорихгүй, Astral хоригийг тойрно; саатуулалтад дархлаатай дүрүүдийн жагсаалт; Bodyguard Guard-ын бичвэр; SC2Mafia-ийн «repeats that cycle a random number of times» анти-загвар; SC2Mafia-ийн «Everybody above the Witch in the OOP is immune to witching» шийдвэр; BOTC-ийн «abilities work immediately» / шөнийн хуудас бол зөвхөн заавар гэсэн ишлэлүүд; Wolfy-ийн тэнцлийн дүрэм; Nightfall README-ийн ишлэлүүд.

**2026-09-15-нд залруулсан зүйлс (өмнөх ноорог буруу байсан):**

> **Баталгаажуулалт (2026-09-15):** SC2Mafia-ийн үйлдлийн дараалал нь **~30 алхам, 42 биш** — 42 бол FAQ-ийн зүйлийн дугаар. Эх сурвалж: https://sc2mafia.com/forum/showthread.php/9152-Game-Rules-Order-of-Operations-and-FAQ

> **Баталгаажуулалт (2026-09-15):** ToS2-ын хорих нь хоригдолд **ямар ч хамгаалалт олгодоггүй** (ноорог Powerful хамгаалалт гэж бичсэн байсан). Эх сурвалж: https://townofsalem.wiki.gg/wiki/Jailor_(ToS2)

> **Баталгаажуулалт (2026-09-15):** Зөвхөн **SK Counterattack** л «зөвхөн төрөлхийн хамгаалалтыг тоодоггүй» гэж баримтжсан. Doomsayer-ийн Doom ба Jester-ийн Boredom тийм биш — тэдгээр нь хамгаалалтын түвшнээс үл хамааран алдаг «odd scenarios» жагсаалтад ордог. Эх сурвалж: https://townofsalem.wiki.gg/wiki/Attributes_(ToS2)

> **Баталгаажуулалт (2026-09-15):** ToS2 нь олон довтлогчтой Bodyguard-ын мөргөлдөөнийг **«at random»** шийддэг, баримтжсан детерминист дүрмээр биш. Эх сурвалж: https://townofsalem.wiki.gg/wiki/Bodyguard_(ToS2)

> **Баталгаажуулалт (2026-09-15):** Antithesis-ийн «reliably reproduce a bug that you see on a given run» гэсэн өгүүлбэр тэр хуудсан дээр **байхгүй**; жинхэнэ тодорхойлолтоор сольсон. Эх сурвалж: https://antithesis.com/docs/resources/deterministic_simulation_testing/

> **Баталгаажуулалт (2026-09-15):** Nightfall — **2,228** бол game-engine багцын тест; **4,739** бол repo-гийн хэмжээнд өөрсдөө мэдүүлсэн нийт тоо. Эх сурвалж: https://github.com/the-nightforge/Nightfall

> **Баталгаажуулалт (2026-09-15):** Хамгаалалтыг үл тоодог чадварууд нь ToS2-ын ангиллын **тавдахь довтолгооны түвшин БИШ**. Эх сурвалж: https://townofsalem.wiki.gg/wiki/Attributes_(ToS2)

**Хараахан [баталгаажаагүй] — бүтээгдэхүүний материалд бүү ишлэ:**

wiki.mafiascum.net-ийн **бүх** ишлэл (Natural Action Resolution-ийн Алтан дүрэм ба журам, «талаас бага» гэсэн статистик, харилцан саатуулалтын шийдвэр, «kills happen at the end of the night with everyone pulling the trigger simultaneously», Triplicate-ийн Zeus Clause, RAR), wikimafia *Priorities*-ийн «who input their action most recently» тэнцэл тайлалт, мөн Town of Salem 1-ийн *Mafioso*/Godfather томилогдсон алуурчны механик.

wiki.mafiascum.net ба fandom.com хоёул автомат татахад HTTP 403 буцаадаг, энэ орчноос web.archive.org хаалттай. Эдгээр нь зөвхөн хайлтын системийн хэсэгчилсэн эшлэл дээр тулгуурлаж байна.

**Хэрхэн баталгаажуулах вэ:** ердийн browser дээр дараах хуудсуудыг гараар нээж, ишлэл бүрийг үгчлэн тулга — https://wiki.mafiascum.net/index.php?title=Natural_Action_Resolution , https://wiki.mafiascum.net/index.php?title=Triplicate_Action_Resolution , https://wiki.mafiascum.net/index.php?title=Reasonable_Action_Resolution , https://wikimafia.fandom.com/wiki/Priorities .

Эдгээр эх сурвалжаас үүдсэн **дизайны шийдвэрүүд** (P1, P13, `DESIGNATED_KILLER` фракцийн горим, timestamp тэнцэл тайлалтыг хаясан нь) инженерийн үүднээс өөрсдөө зөв бөгөөд эдгээр ишлэлгүйгээр ч зогсоно. Гэхдээ **ишлэлүүдийг өөрсдийг нь** browser дээр шалгалгүйгээр хэн ч баримт мэтээр давтаж болохгүй.

**Бас анхаарах зүйл:**

1. Шатны `SELF_BUFF` хувин нь P17 шийдвэртэй зөрчилдөж байна — §3.2-ын «илэрсэн алдаа» тэмдэглэлийг үз.
2. §3.7-д Bodyguard-ын хариу тулаан нь довтлогчийн өөрийнх нь довтолгооны түвшнээс үл хамааран **хатуу бичсэн `POWERFUL` довтолгоог** довтлогчоос Bodyguard руу нэмж байна. Энэ бол ToS2-ын дүрэм биш, **бидний дизайны сонголт**, бөгөөд үүний улмаас Bodyguard нь Basic хамгаалалттай байсан ч тулаанаас хэзээ ч амьд гарахгүй гэсэн үг. Үүнийг санаатайгаар шийд.
