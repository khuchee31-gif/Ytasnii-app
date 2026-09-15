# Бүлэг 20 — Төлбөрийн эцсийн дүгнэлт: Google Play ба App Store, Монгол улс

**Уншсан огноо: 2026-09-15.** Бүх эх сурвалж нь **үйлдвэрлэгчийн өөрийн үндсэн баримт бичиг** (Google Play Console Help, Google Play дэлгүүрийн сервер, Apple Developer / App Store Connect Help, Apple-ийн гэрээний PDF). Блог, шинэ мэдээ, гуравдагч талын нийтлэл ашиглаагүй.

> **Гол дүгнэлт нэг өгүүлбэрээр:** Монгол хэрэглэгчээс **мөнгө авах боломжтой** — Google Play Монголд **төгрөгөөр (MNT)** үнэ тогтоож, худалдаж авах товч харуулдаг. Асуудал нь мөнгө **орох** тал биш, **гарах** тал — хөгжүүлэгч рүү мөнгө хэрхэн ирэх нь нийтийн баримт бичгээс тодорхойгүй.

---

## 0. Дөрвөн ӨӨР асуулт — хооронд нь бүү хольж хутга

Энэ бол доссьегийн зөрчлийн жинхэнэ шалтгаан. Google өөрөө бүртгэлийн хүснэгтийнхээ дээр яг энэ сэрэмжлүүлгийг бичсэн байдаг:

> **«Note: If your location supports merchant registration, Google Play customers must be in a supported location to purchase apps.»**
> — https://support.google.com/googleplay/android-developer/answer/9306917?hl=en (2026-09-15-нд уншив)

Өөрөөр хэлбэл Google өөрөө: *худалдаачны бүртгэл* (Q2), *хэрэглэгч худалдан авах боломж* (Q3), *хөгжүүлэгч рүү мөнгө шилжих* (Q4) — эдгээр нь **гурван бие даасан баримт**. Нэгээс нөгөөг нь дүгнэж болохгүй.

| # | Асуулт | Хариу | Байдал |
|---|--------|-------|--------|
| Q1 | Монголын иргэн Google Play хөгжүүлэгчээр бүртгүүлж чадах уу ($25)? | **ТИЙМ** | Баталгаажсан |
| Q2 | Merchant (худалдаачин) болж чадах уу — төлбөртэй апп / IAP зарах? | **ТИЙМ** | Баталгаажсан |
| Q3 | Монголын ХЭРЭГЛЭГЧ худалдан авч чадах уу? | **ТИЙМ — MNT төгрөгөөр** | Баталгаажсан |
| Q4 | Хөгжүүлэгч ТӨЛБӨРӨӨ авч чадах уу? | **Тодорхойгүй** | **[баталгаажаагүй]** |

---

## Q1. Хөгжүүлэгчийн бүртгэл — ТИЙМ

**Эх сурвалж:** Play Console Help, *«Supported locations for developer and merchant registration»*
https://support.google.com/googleplay/android-developer/answer/9306917?hl=en
(мөн адилхан хүснэгт: https://support.google.com/googleplay/android-developer/table/3539140?hl=en)
**2026-09-15-нд шууд татаж (curl, HTTP 200, 1,653,625 байт) уншив. Хүснэгт нь серверээс бэлэн ирдэг (JS биш), тул найдвартай.**

Баганын гарчиг, үгчлэн:
> `Location | Supports Google Play Developer Registration | Supports Merchant Registration | Developer Default Currency`

Монголын мөр, үгчлэн:
> `Mongolia | ✔ | ✔ | USD`

Хажуугийн мөрүүд (хүснэгт үнэхээр ялгаж байгааг харуулах хяналт):
> `Moldova | ✔ | ✔ | USD`
> `Monaco | ✔ | ✘ | ☆`
> **`Mongolia | ✔ | ✔ | USD`**
> `Montenegro | ✔ | ✘ | ☆`
> `Morocco | ✔ | ✘ | ☆`

Тайлбар (legend), үгчлэн:
> «Supports Google Play developer registration ✔ Location supports Google Play developer registration. ✘ Location does not support Google Play developer registration.»

**Утга:** Монголд оршин суугаа хүн $25-ын Google Play хөгжүүлэгчийн данс нээж болно. Monaco / Montenegro / Morocco мөрүүд ✘ байгаа нь энэ хүснэгт бодитоор ялгаж байгааг батална — Монголын ✔ бол утга учиртай.

---

## Q2. Merchant (худалдаачны) бүртгэл — ТИЙМ

**Мөн адил хуудас, мөн адил татлага (2026-09-15).** Энэ бол **тусдаа багана**, тусдаа уншсан.

Монголын «Supports Merchant Registration» нүд = **✔**.

Тайлбар, үгчлэн:
> «Supports merchant registration ✔ Location supports merchant registration. ✘ Location does not support merchant registration.»

Тэмдгийн тайлбар, үгчлэн:
> «☆ Location does not support merchants.»

Монгол ☆ тэмдэг **үүрээгүй**.

**Утга:** Монголын хөгжүүлэгч payments/merchant профайл үүсгэж, төлбөртэй апп болон апп доторх бүтээгдэхүүн (IAP) **зарах эрхтэй**.

> ⚠️ **Урхи №1 — «Developer Default Currency: USD» гэдгийг буруу уншиж болохгүй.**
> Энэ бол **хөгжүүлэгчид** тайлагнах/төлөх валют. Энэ нь **хэрэглэгчээс авах** валют **БИШ**. Монголын хэрэглэгч **төгрөгөөр** төлдөг (Q3-г үз). Доссье энэ хоёрыг нэг болгож хутгасан нь зөрчлийн нэг эх үүсвэр.

**Иймд 05-р бүлгийн («competitors-online») хүснэгтийн мөр — «Mongolia: developer registration ✔ | merchant registration ✔ | USD» — үгчлэн ЗӨВ.** Гагцхүү энэ нь зөвхөн Q1+Q2-т хариулдаг; Q3, Q4-ийн тухай юу ч хэлэхгүй.

---

## Q3. Монголын хэрэглэгч худалдан авч чадах уу? — ТИЙМ, ТӨГРӨГӨӨР

### (a) Албан ёсны хүснэгтийг уншиж ЧАДААГҮЙ — үүнийг шулуухан хэлье

*«Supported locations for distribution to Google Play users»*
https://support.google.com/googleplay/android-developer/answer/10532353?hl=en (2026-09-15)
дотор **хүснэгт огт байхгүй**. Бүх агуулга нь:
> «Using the tables on this page, you can find app availability information, along with supported currency and price range information for Google Play users.»
— энд «this page» нь https://play.google.com/supported-locations рүү очдог холбоос.

Тэр хуудас нь **бүхэлдээ JS/Flutter-ээр зурагддаг**: статик татахад улсын мөр нэг ч байхгүй (`main.dart.js` 2.6 MB + 90 ширхэг `main.dart.js_N.part.js` хэсгийг шалгасан — «Mongolia» гэсэн цорын ганц тохиолдол нь ерөнхий ICU валютын нэрийн мета өгөгдөл, байршлын хүснэгт биш). 11 хэл дээрх хувилбар (mn, ru, ja, ko, zh-CN, de, fr, es, pt-BR, hi, id) бүгд ижилхэн JS рүү чиглүүлдэг. **web.archive.org энэ орчноос хаалттай** (egress policy / HTTP 429), тул архивын хуулбар ч авах боломжгүй байв.

### (b) Тиймээс Google-ийн ӨӨРИЙН дэлгүүрийн серверээс шийдлээ — энэ бас үндсэн эх сурвалж

`gl=MN` (Монголын дэлгүүр) параметртэйгээр, **2026-09-15-нд миний бие дахин татаж баталгаажуулав** (HTTP 200, 1,280,238 байт):

https://play.google.com/store/apps/details?id=com.mojang.minecraftpe&hl=en&gl=MN

Google-ийн өөрийнх нь schema.org JSON-LD, үгчлэн:
> `"offers":[{"@type":"Offer","price":"21390","priceCurrency":"MNT","availability":"https://schema.org/InStock"}]`

Худалдан авах товчны үнийн объект, үгчлэн:
> `[21390000000,"MNT","MNT 21,390.00"]`

Апп доторх худалдан авалтын үнийн зурвас, Монголын дэлгүүрт үйлчилж байгаа (Blockman Go, https://play.google.com/store/apps/details?id=com.sandboxol.blockymods&hl=en&gl=MN, 2026-09-15):
> `MNT 2,100.00 - MNT 854,124.00 per item`
> `MNT 3,714.00 - MNT 383,324.00 per item`
> `MNT 10,700.00 - MNT 21,500.00 per item`

### (c) Хяналтууд — энэ нь зүгээр нэг валют хөрвүүлэлт биш гэдгийг батлах

Яг нэг минутад, яг нэг апп, зөвхөн `gl=` өөрчилж татав (2026-09-15):

| gl | JSON-LD offer |
|----|----------------|
| **MN** | **`"price":"21390","priceCurrency":"MNT"` — InStock** |
| MM (Мьянмар) | `"price":"15000","priceCurrency":"MMK"` |
| KZ (Казахстан) | `"price":"490","priceCurrency":"KZT"` |
| AF (Афганистан — merchant ✘) | `"price":"6.99","priceCurrency":"USD"` |
| ME (Монтенегро — merchant ✘) | `"price":"6.99","priceCurrency":"USD"` |
| US | `"price":"6.99","priceCurrency":"USD"` |
| NP (Балба) | `"price":"7.9","priceCurrency":"USD"` |
| UZ (Узбекистан) | `"price":"7.83","priceCurrency":"USD"` |

Merchant ✘ улсууд (AF, ME) нь **АНУ-ын суурь үнэ $6.99**-ыг л буцаадаг. Монгол өөрийн **дотоодын валютын үнийн шатлалтай** — MNT бол ямар ч улсад «нөөц/асуултгүй» валют биш, зөвхөн Google бодитоор төлбөр авах чадвартай зах зээлд л дотоодын валют оноодог.

> Нарийн тэмдэглэл: NP, UZ зэрэг улсууд USD-ээр үнэлэгддэг ч бодит худалдан авагч зах зээл (үнэ нь $7.90 / $7.83 — АНУ-ынхаас өөр улс тусгайлсан шатлал). **Иймд «USD үнэ харагдлаа» гэдэг нь худалдан авагч биш гэсэн үг БИШ.** Ялгагч шинж нь: улс тусгайлсан үнийн шатлал байгаа эсэх. Монголд — байгаа, бүр төгрөгөөр.

### (d) 11-р бүлгийн алдааны ЖИНХЭНЭ ЭХ ҮҮСВЭРИЙГ олов

11-р бүлэг (`11-business-mongolia.md`, 35-р мөр) өөрөө ингэж бичсэн: *«Би 2026-09-15-нд Google-ийн өөрийнх нь «Paid app availability» хуудсыг татаж…»*. Тэр хуудас бол:

https://support.google.com/googleplay/answer/143779?hl=en — **«Paid app availability»**, 2026-09-15-нд уншив. Үгчлэн:
> «Paid apps are currently available to users in the following countries:»
— жагсаалт нь `…Mauritius, Mexico, Moldova, Monaco, Morocco, Mozambique, Myanmar, Namibia…` гэж явдаг бөгөөд **Монгол үнэхээр байхгүй.**

**ГЭВЧ ЭНЭ ХУУДСАНД ИТГЭЖ БОЛОХГҮЙ — тэр нь орхигдсон, шинэчлэгдээгүй хуудас.** Миний 2026-09-15-нд татсан хувилбарт дараах нь **одоо ч** байна:
- **«Netherlands Antilles»** — 2010 онд задарч устсан улс
- **«Macedonia»** — 2019 онд «North Macedonia» болж нэрээ сольсон
- **«Turkey»** — одоо «Türkiye»
- **«Russia»** — Google 2022 онд Play-ийн төлбөрт гүйлгээг тэнд зогсоосон
- **«Cote d' Ivore»** — зөв бичгийн алдаатай

Хамгийн багадаа **16 жилийн хуучирсан** өгөгдөл агуулсан хуудас. Энэ бол Google-ийн одоогийн байдал биш, хуучин үлдэгдэл. **Доссьегоос хасах ёстой.**

### (e) Монголын хувьд Google ямар төлбөрийн аргыг жагсаадаг вэ?

https://support.google.com/googleplay/answer/2651410?hl=en — *«Accepted payment methods on Google Play»*, 2026-09-15-нд уншив (HTTP 200, 1,627,229 байт).

Энэ хуудас улс тус бүрээр сонголттой. **Би сонгогчийн бүх кодыг түүхий HTML-ээс гаргаж авав — 72 ширхэг:**
`AE AT AU BE BG BH BR CA CH CL CO CY CZ DE DK EE EG ES FI FR GB GE GH GR HK HR HU ID IE IL IN IQ IT JP KE KH KR KW KZ LK LT LU LV MA MO MX MY NG NL NO NZ OM PE PH PK PL PT QA RO SA SE SG SI SK TH TR TW TZ UA US VN ZA`
**MN байхгүй** (хуудсанд «Mongolia» гэсэн үг 0 удаа тохиолдоно).

> ⚠️ **Урхи №2:** энэ 72 улсын жагсаалтыг «худалдан авагч улсуудын жагсаалт» гэж бүү ойлго. Үүнд Аргентин (AR), Балба (NP), Бангладеш (BD), Армен (AM) бас байхгүй — гэтэл тэд бүгд маргаангүй худалдан авагч зах зээл. Энэ бол **редакцын дэд олонлог**, худалдан авагчийн жагсаалт биш.

Монгол хуудасны өөрийнх нь **«бусад улс» бүлэгт** хамаарна. Үгчлэн:
> «**Other countries** — If your country is not on the list, available payment methods are listed below:»
> «**Credit or debit cards** — You can add the following credit/debit cards to your account: **American Express, Discover, Mastercard, Visa**»
> «Note: The types of cards accepted through Google Play may vary. If your card doesn't work when you think it should, contact your bank or card issuer for help. You may notice temporary authorizations on your account when using a credit or debit card.»

Дэмжигдэхгүй арга, үгчлэн:
> «**Unsupported payment types** — Google Play can't be used with: Wire transfers, Western Union, Money Gram, Virtual Credit Cards (VCC), Health Savings Account (HSA), Transit cards, Any escrow type of payment»

**Монголын хувьд практик дүгнэлт:**

| Арга | Монголд байгаа юу? |
|------|--------------------|
| Visa / Mastercard / Amex / Discover карт | **ТИЙМ** — «Other countries» заалтаар |
| Оператор (Unitel / Mobicom / Skytel) -ын дансаар төлөх (carrier billing) | **ҮГҮЙ** — нэг ч монгол оператор жагсаалтад байхгүй |
| Google Play бэлгийн карт (gift card) | **ҮГҮЙ** — Монгол https://support.google.com/googleplay/answer/3422734 хуудсанд байхгүй |
| PayPal / Google Pay balance | **ҮГҮЙ** — зөвхөн тусгайлан жагсаагдсан улсуудад |
| QPay / SocialPay / Monpay гэх мэт дотоодын хэтэвч | **ҮГҮЙ** — Google эдгээртэй интеграц хийгээгүй |

### (f) Монголын банкны Visa картаар Play-ээс худалдан авч чадах уу?

**ТИЙМ** — (e)-ийн дагуу карт бол Монголын хувьд албан ёсоор баримтжуулсан цорын ганц зам.

> ⚠️ **Урхи №3 — Google Wallet-ийн хуудсыг Play-ийн худалдан авалттай бүү хольж хутга.**
> https://support.google.com/wallet/answer/12059326?hl=en&co=GENIE.CountryCode%3DMN хуудсанд Монголын банкууд (BONUM LLC, Golomt Bank, M Bank JSC, Trade and Development Bank JSC, XACBANK JSC) жагсаагдсан байдаг **боловч тэр нь NFC-ээр утсаа хүрч төлөх тухай**, Play дэлгүүрийн худалдан авалтын тухай биш. Тэр хуудас өөрөө: «Important: To make contactless payments with Google Wallet, you need to have an Android phone with Near Field Communication (NFC).» Мөн **Хаан банк тэр жагсаалтад байхгүй** — энэ бол Wallet-ийн баримт, Play-ийн баримт биш.

**Үлдэж байгаа бодит эрсдэл (аль ч үйлдвэрлэгчийн баримтаас шийдэгдэхгүй):** картыг гаргасан банк **олон улсын / e-commerce (3-D Secure) гүйлгээг идэвхжүүлсэн** байх ёстой. Энэ бол Google-ийн хязгаарлалт биш, банкны тохиргоо. Монголын өсвөр насны хүүхдийн хувьд бодит саад нь ихэвчлэн: (1) картанд онлайн гүйлгээ хаалттай, (2) эцэг эхийн зөвшөөрөл, (3) картны валютын данс.

### (g) User-choice billing — 11-р бүлгийн ганц үнэн хэсэг, гэхдээ ач холбогдолгүй

https://support.google.com/googleplay/android-developer/answer/12570971?hl=en — 2026-09-15-нд уншив. Үгчлэн:
> «Only offer user choice billing to eligible users in announced pilot markets, currently: European Economic Area (EEA) countries, Australia, Brazil, Indonesia, Japan, South Africa, United Kingdom, United States»

Монгол энд **байхгүй** — энэ нь үнэн.

**ГЭВЧ ЭНЭ НЬ ХАМААРАЛГҮЙ.** User choice billing гэдэг нь Google Play Billing-ийн **ХАЖУУГААР** өөр төлбөрийн систем санал болгох эрх. Түүнд байхгүй гэдэг нь «төлбөрийн систем алга» гэсэн үг **БИШ**, харин «Google Play Billing бол цорын ганц сонголт» гэсэн үг. Google Play Billing Монголд ажилладаг. 11-р бүлэг энэ хоёр баримтыг гинжлээд гарахгүй дүгнэлт хийсэн.

---

## Q4. Хөгжүүлэгч ТӨЛБӨРӨӨ авч чадах уу?

### GOOGLE — Монгол wire transfer-ийн жагсаалтад БАЙХГҮЙ (08-р бүлэг ЗӨВ)

**Эх сурвалж:** https://support.google.com/googleplay/android-developer/answer/2700656?hl=en — *«Wire transfer payouts»*, 2026-09-15-нд уншив. **Түүхий HTML-ээс шалгав — жагсаалт нь серверээс бэлэн ирдэг, JS биш.**

Үгчлэн:
> «In certain locations, Google Play merchants can receive payouts through a wire transfer from Google. To receive payouts, merchants must add a bank account to Play Console.»
> «**List of locations** — Developers in the locations listed below can receive payouts through wire transfer: Albania, Algeria, Argentina, Armenia, Azerbaijan, Bahamas, Bahrain, Bangladesh, Belarus, Belize, Benin, Bhutan, Bolivia, Botswana, Burundi, Cambodia, Central African Republic, Chile, China, Colombia, Congo (DRC), Costa Rica, Dominican Republic, Ecuador, Egypt, Equatorial Guinea, Eritrea, Fiji, French Guiana, Gambia, Ghana, Guadeloupe, Guam, Guatemala, Guinea, Guinea-Bissau, Haiti, Honduras, India, Indonesia, Jamaica, Jordan, Kazakhstan, Kenya, Kuwait, Lebanon, Lesotho, Liberia, Libya, Malaysia, Malawi, Mali, Martinique, Mauritania, Mauritius, Mayotte, Moldova, Mozambique, Myanmar, Nicaragua, Niger, Nigeria, North Macedonia, Oman, Pakistan, Palau, Panama, Paraguay, Philippines, Qatar, Réunion, Russia, Saudi Arabia, Serbia, Sierra Leone, Slovakia, Slovenia, Sri Lanka, Taiwan, Tanzania, Thailand, Togo, Trinidad and Tobago, Tunisia, Turkmenistan, Ukraine, United Arab Emirates, Uruguay, U.S. Virgin Islands, Uzbekistan, Venezuela, Vietnam, Yemen, Zambia, and Zimbabwe»

**Монгол БАЙХГҮЙ.** Хуудсан дээрх «Mongolia» гэсэн тоолол = **0**; харьцуулбал «Moldova» = 1, «Myanmar» = 1, «Kazakhstan» = 1 (өөрөөр хэлбэл хайлт ажиллаж байна).

Хөрш орнууд — **Казахстан, Мьянмар, Бутан, Хятад, Орос — бүгд жагсаалтад БАЙНА.** Энэ бол бүс нутгийн бус, **Монголд тусгайлан хамаарах** орхигдол.

Мөн үгчлэн:
> «Google issues wire transfer payouts in USD»
> «Your earned balance must meet the minimum payout amount of US$100 to be eligible for a payout at the end of your payment cycle.»

### Хоёр дахь бие даасан Google эх сурвалж — мөн Монгол байхгүй

https://support.google.com/googleplay/android-developer/answer/7161440?hl=en — *«Enter merchant bank account information»*, 2026-09-15-нд уншив.

Энэ хуудас улс бүрээр банкны дансны шаардлагыг жагсаадаг (Albania, Algeria, Argentina, Armenia, Australia, … Kazakhstan, … Moldova, Malaysia, Malta, Mauritius, Mexico, … Zimbabwe). Жишээ нь Молдовын хэсэг, үгчлэн:
> «Merchants in Moldova receive payments via wire transfer from the United States. Payouts will arrive in US Dollars.»

**Монголын хэсэг БАЙХГҮЙ.** Харагдах бичвэрт «Mongolia» = **0 удаа**. Түүхий HTML-д ганцхан удаа тохиолддог бөгөөд тэр нь Help Center-ийн ерөнхий улс сонгох UI-ийн жагсаалт (`{name:'MN',value:'Mongolia'}`) — Иран, Хойд Солонгос, Сиритэй зэрэгцээ, өөрөөр хэлбэл **тавилга, төлбөрийн бичлэг биш**.

Хамаарах ерөнхий шаардлага, үгчлэн:
> «Your bank account must be: Able to receive Electronic Funds Transfer (EFT) / Wire Transfer / In the same country or region where the merchant account is registered / Denominated in country's currency (EFT) or USD (Wire transfer)»

Google хоёр суваг ажиллуулдаг — **EFT** (дотоодын валют) ба **wire transfer** (USD). Босго нь ялгаатай, https://support.google.com/googleplay/android-developer/answer/137997?hl=en (2026-09-15), үгчлэн:
> «Merchants who receive local-currency payouts: US$1 / Merchants who receive USD wire-transfer payouts: US$100»

### 🔴 **[баталгаажаагүй]** — Монголын хөгжүүлэгч Google-ээс мөнгөө хэрхэн авах нь

Энэ бол төслийн **цорын ганц жинхэнэ тодорхойгүй эрсдэл**, би үүнийг зөөлрүүлэхгүй.

Google-ийн өөрийн баримт бичгүүд хоорондоо зөрчилдөж байна:
- Бүртгэлийн хүснэгт: Монгол **merchant ✔**, «Developer Default Currency: **USD**» — USD бол яг wire transfer-ийн валют
- Гэтэл Монгол **wire transfer-ийн жагсаалтад байхгүй**
- Мөн банкны зааврын хуудсанд **Монголын хэсэг байхгүй**
- Google **EFT дэмжигддэг улсуудын жагсаалтыг хаана ч нийтэлдэггүй**

«Wire жагсаалтад байхгүй» ≠ «мөнгө авч чадахгүй». Гэхдээ ≠ «авч чадна» ч гэсэн үг биш. **Нийтийн баримт бичгээс шийдэгдэхгүй.**

> **🕐 5 минутын шалгалт (Google):** Монголоор бүртгүүлсэн хөгжүүлэгчийн дансаар Play Console руу нэвтэр → **Settings → Payments settings** → «How you get paid» доор **«Choose payment method» → «Add Payment Method»**. Гарч ирэх цонх нь Монголын payments профайлд Google ЯМАР сувгийг (EFT эсвэл wire), ямар банкны талбарыг (SWIFT/IBAN эсвэл дотоодын дансны дугаар), ямар валютын данс (MNT эсвэл USD) хүлээж авахыг **яг таг** харуулна. Энэ ганц дэлгэц асуудлыг бүрэн шийднэ.
> **Хэрэв татгалзвал:** нөөц төлөвлөгөө нь wire жагсаалтад байгаа улсад (жишээ нь Казахстан) payments профайл бүртгүүлэх — гэхдээ энэ нь тэнд хуулийн этгээд БОЛОН банкны данс шаардана, зүгээр формальность биш.

### APPLE — зарах тал БҮРЭН БАТАЛГААЖСАН

**1) Монгол бол Apple-ийн албан ёсны төлбөртэй апп зарах бүс.**
Эх сурвалж: *«Exhibits to Schedule 2 and 3»* (Paid Applications Agreement-ийн хавсралт), англи PDF, **2026 оны 8-р сарын 27-ны огноотой**.
https://developer.apple.com/support/downloads/terms/exhibits/Exhibits-to-Schedule-2-and-3-English.pdf (https://developer.apple.com/terms/ -ээс холбогдоно), 2026-09-15-нд уншив.

Exhibit A, үгчлэн:
> «You appoint Apple Services Pte. Ltd. as Your commissionaire for the marketing and End-User download of the Licensed and Custom Applications by End-Users located in the regions identified below, as updated from time to time via the App Store Connect site: Bhutan | Brunei | Cambodia | Laos | Macau | Maldives | Micronesia, Fed States of | **Mongolia** | Myanmar | Nepal | Palau | Sri Lanka | Korea* | Fiji | Naoero | Papua New Guinea | Solomon Islands | Tonga | Vanuatu»

Ижил жагсаалт Apple Developer Program License Agreement-ийн PDF-д бас бий (130 хуудас).

**2) Санхүүгийн тайлангийн бүс.**
https://developer.apple.com/help/app-store-connect/reference/financial-report-regions-and-currencies/ — 2026-09-15-нд шууд татаж баталгаажуулав (HTTP 200). Үгчлэн:
> «South Asia and Pacific | USD | AP | Bhutan, Brunei, Cambodia, Fiji, Laos, Macau, Maldives, Micronesia, **Mongolia**, Myanmar, Nauru, Nepal, Palau, Papua New Guinea, Solomon Islands, Sri Lanka, Tonga, and Vanuatu»

Монголын борлуулалт **«South Asia and Pacific», бүсийн код AP, тайлангийн валют USD**.

**3) Монголын App Store дэлгүүр амьд ажиллаж байна.** https://apps.apple.com/mn/app/minecraft/id479516143 — HTTP 200, үнэ «USD 6.99».

> **Чухал ялгаа:** Apple Монголын хэрэглэгчээс **USD-ээр** авдаг; Google **төгрөгөөр (MNT)** авдаг. Монголын өсвөр насны хүүхдийн хувьд MNT үнэ **сэтгэл зүйн хувьд хамаагүй хялбар** — энэ бол Android-д давуу тал.

### 🔴 **[баталгаажаагүй]** — Apple Монголын банкны данс руу мөнгө шилжүүлэх үү?

Apple дэмжигддэг банкны нутаг дэвсгэрийн жагсаалтыг **нийтэлдэггүй**. Шалгасан хуудсууд (бүгд 2026-09-15):
- https://developer.apple.com/help/app-store-connect/reference/banking-information/ — үгчлэн: «If you can't identify your bank in App Store Connect, it may be that Apple can't send payments to that bank.» ба «Bank Territory — The country or region for the branch of your bank». Улсын жагсаалт байхгүй.
- https://developer.apple.com/help/app-store-connect/manage-banking-information/enter-banking-information/ — үгчлэн: «Select your bank country or region, then click Next.» ба «In certain regions, additional documentation may be required to receive payments.»

**Эерэг чиглэлийн нэг нотолгоо** (2026-09-15-нд миний бие шууд татаж баталгаажуулав):
https://developer.apple.com/help/app-store-connect/reference/reporting/minimum-payment-threshold/ — үгчлэн:
> «If your bank account currency and the country or region where your bank is based are listed in the table below, you must exceed the minimum payment threshold listed. **All other bank countries or regions and bank account currencies must exceed a minimum payment threshold of 40 USD.**»

Монгол тэр хүснэгтэд байхгүй (тоолол = 0) — иймд **40 USD-ийн анхдагч босгонд** хамаарна. Өөрөөр хэлбэл Apple хүснэгтэд ороогүй банкны улсуудад **төлөх боломжийг тооцсон** байдаг. Энэ нь баталгаа биш, гэхдээ чиглэл нь эерэг.

**Дүгнэлт: [баталгаажаагүй], эерэг талдаа хазайсан.**

> **🕐 5 минутын шалгалт (Apple):** App Store Connect → **Business (Agreements, Tax, and Banking)** → Paid Apps гэрээг зөвшөөр → **Bank Accounts → Add Bank Account** → **«Bank Territory»** унждаг жагсаалтыг нээж «Mongolia» байгаа эсэхийг хар. Байвал Apple монгол банк руу төлнө; байхгүй бол төлөхгүй. Хоёр дахь шалгалт: MNT эсвэл USD-ийн данс хүлээж авдаг эсэх.

---

## Гурван нэхэмжлэлийн шийдвэр

| Бүлэг | Нэхэмжлэл | Шийдвэр |
|-------|-----------|---------|
| **11 (business-mongolia)** | «Монгол Google Play-ийн худалдан авагчийн жагсаалтад байхгүй… ~55–70 % хэрэглэгчээс огт мөнгө авах боломжгүй» | ❌ **БУРУУ — устгах** |
| **08 (client-stack)** | «Монгол developer БА merchant байршил мөн, гэхдээ wire transfer-ийн жагсаалтад байхгүй» | ✅ **ЗӨВ — хоёр хагас нь хоёулаа үнэн** |
| **05 (competitors-online)** | «Mongolia: developer ✔ | merchant ✔ | USD» | ✅ **ҮГЧЛЭН ЗӨВ** (гэхдээ зөвхөн Q1+Q2-т хариулдаг) |

11-р бүлгийн алдааны механизм: (1) хуучирсан `answer/143779` хуудсыг одоогийн байдал гэж уншсан, (2) «Developer Default Currency: USD»-г хэрэглэгчийн валют гэж уншсан, (3) user-choice-billing-д байхгүйг «төлбөр байхгүй» гэж уншсан, (4) төлбөр **гарах** асуудлыг төлбөр **орох** асуудал руу шилжүүлсэн.

---

## Бүтээгдэхүүнд юу гэсэн үг вэ — юу хийх, юу хийхгүй

### ✅ ХИЙХ

1. **Google Play Billing-ийн ердийн in-app purchase (IAP) хийх.** Монголд ажилладаг. `BillingClient`, `queryProductDetailsAsync`, `launchBillingFlow` — стандарт зам.
2. **Үнийг ТӨГРӨГӨӨР тогтоох.** Play Console нь Монголын дэлгүүрт MNT-ийн үнийн шатлал өгдөг. 5,000 ₮ / 10,000 ₮ гэх мэт дугуй тоо нь «$1.99» гэхээс хамаагүй ойлгомжтой.
3. **Үнийг Монголын халаасанд тааруулах.** Дундаж сарын цалин ~3.0 сая ₮ (11-р бүлэг, 2026 II улирал). Өсвөр насны хүүхдийн бодит зарцуулалт хамаагүй бага. Хамгийн доод шатлалаас эхэл (Play-ийн Монгол дахь хамгийн бага IAP шатлал ~360 ₮ хүртэл бууж чадна — жишээ: `MNT 360.00 - MNT 376,775.00 per item` гэсэн зурвасууд бодитоор үйлчилж байна).
4. **Зөвхөн КАРТ дээр тулгуурласан checkout гэж төлөвлө.** Visa / Mastercard / Amex / Discover. Өөр юу ч байхгүй.
5. **Карт татгалзсан үед эвтэйхэн алдааны мессеж бичих** — монголоор, «банкандаа онлайн гүйлгээ асаалгана уу» гэсэн тодорхой зааврын хамт. Энэ бол Монголд checkout-ийн хамгийн түгээмэл унал болно.
6. **Apple тал дээр iOS-ийг зэрэг хөгжүүлэх.** Зарах тал бүрэн шийдэгдсэн (Exhibit A, AP/USD бүс). Зөвхөн банкны данс нь нээлттэй.
7. **Код бичиж эхлэхээс ӨМНӨ дээрх хоёр 5-минутын шалгалтыг хий.** Энэ бол хамгийн өндөр өгөөжтэй 10 минут.

### ❌ ХИЙХГҮЙ / БҮҮ ЗАРЦУУЛ

1. **«Монголчууд төлж чадахгүй» гэсэн таамаг дээр суурилсан ямар ч архитектур бүү барь.** IAP-г тойрч гарах загвар (зөвхөн зар сурталчилгаа, гадаад төлбөрийн вэб хуудас, гар аргаар данс цэнэглэх) — эдгээр нь **буруу баримт** дээр суурилсан нэмэлт хөдөлмөр.
2. **Carrier billing (Unitel / Mobicom / Skytel дансаар төлөх) бүү төлөвлө.** Google Play-д Монголд байхгүй.
3. **Google Play бэлгийн карт бүү тооц.** Монголд байхгүй.
4. **QPay / SocialPay / Monpay-г Play Billing дотор бүү оролд.** Google Play Billing-ийн гадуур төлбөр авах нь Play-ийн бодлогыг зөрчих бөгөөд Монгол user-choice-billing-ийн пилотод БАЙХГҮЙ тул хууль ёсны гарц ч алга. *(Тайлбар: апп доторх дижитал бараанд хамаарна; жинхэнэ ертөнцийн бараа/үйлчилгээнд биш.)*
5. **User choice billing-ийг бүү судал.** Монгол пилотод байхгүй, ойрын хугацаанд орох шинж алга. Google Play Billing ашигла, дуусгав.
6. **Google Wallet-ийн Монголын банкны жагсаалтыг бүү иш тат** — тэр нь NFC-ийн баримт, Play-ийн биш.

### ⚠️ ГАНЦ ЖИНХЭНЭ ХААЛТ

Мөнгө **орох** нь шийдэгдсэн. Мөнгө **гарах** нь шийдэгдээгүй. **Play Console → Payments settings → Add Payment Method** ба **App Store Connect → Bank Territory** — энэ хоёр дэлгэц л орлого бодитоор гарт орох эсэхийг шийднэ. Хэрэв хоёулаа Монголыг татгалзвал, тэр үед л бизнесийн загвараа (зар сурталчилгаа + AdMob, эсвэл гуравдагч улсын хуулийн этгээд) дахин бодох хэрэгтэй — **өмнө нь биш**.

---

## Эх сурвалж (бүгд 2026-09-15-нд уншсан)

**Google — бүртгэл**
- https://support.google.com/googleplay/android-developer/answer/9306917?hl=en — *Supported locations for developer and merchant registration*. «Mongolia | ✔ | ✔ | USD». Шууд curl-ээр баталгаажуулсан (HTTP 200, 1,653,625 байт). Мөн: https://support.google.com/googleplay/android-developer/table/3539140?hl=en

**Google — худалдан авагч**
- https://support.google.com/googleplay/android-developer/answer/10532353?hl=en — хүснэгт агуулаагүй, зөвхөн холбоос
- https://play.google.com/supported-locations — **УНШИГДААГҮЙ**: Flutter апп, өгөгдөл HTML-д байхгүй, `main.dart.js` + 90 хэсэг шалгасан. web.archive.org энэ орчноос **хаалттай**
- https://play.google.com/store/apps/details?id=com.mojang.minecraftpe&hl=en&gl=MN — `"price":"21390","priceCurrency":"MNT","availability":"InStock"`, `[21390000000,"MNT","MNT 21,390.00"]`
- https://play.google.com/store/apps/details?id=com.sandboxol.blockymods&hl=en&gl=MN — `MNT 2,100.00 - MNT 854,124.00 per item`
- Хяналтууд, ижил апп, зөвхөн `gl=` өөрчилсөн: AF/ME → USD 6.99 (merchant ✘); MM → MMK 15000; KZ → KZT 490; NP → USD 7.9; UZ → USD 7.83; US → USD 6.99
- https://support.google.com/googleplay/answer/143779?hl=en — *Paid app availability*. Монгол байхгүй — **ГЭХДЭЭ ХУУЧИРСАН ГЭЖ ТЭМДЭГЛЭВ**: Netherlands Antilles (2010-д устсан), Macedonia, Russia, Turkey, «Cote d' Ivore». 11-р бүлгийн алдааны эх үүсвэр
- https://support.google.com/googleplay/answer/2651410?hl=en — *Accepted payment methods*. 72 улсын код гаргасан, MN байхгүй, «Mongolia» 0 удаа. «Other countries» → American Express, Discover, Mastercard, Visa
- https://support.google.com/googleplay/answer/3422734?hl=en — Play бэлгийн карт. Монгол байхгүй
- https://support.google.com/wallet/answer/12059326?hl=en&co=GENIE.CountryCode%3DMN — Google Wallet Монгол (BONUM, Golomt, M Bank, TDB, XacBank). **NFC-ийн тухай, Play-ийн биш**
- https://support.google.com/googleplay/android-developer/answer/12570971?hl=en — UCB пилот: «EEA countries, Australia, Brazil, Indonesia, Japan, South Africa, United Kingdom, United States». Монгол байхгүй
- https://support.google.com/googleplay/android-developer/answer/13821247?hl=en — UCB тойм

**Google — төлбөр**
- https://support.google.com/googleplay/android-developer/answer/2700656?hl=en — *Wire transfer payouts*. Бүтэн жагсаалт үгчлэн авсан; **Монгол БАЙХГҮЙ** (тоолол 0; Moldova/Myanmar/Kazakhstan = 1). «Google issues wire transfer payouts in USD», «minimum payout amount of US$100»
- https://support.google.com/googleplay/android-developer/answer/7161440?hl=en — *Enter merchant bank account information*. Харагдах бичвэрт Монгол **0 удаа**; түүхий HTML-д 1 удаа, тэр нь UI-ийн улс сонгогч. «Able to receive Electronic Funds Transfer (EFT) / Wire Transfer … Denominated in country's currency (EFT) or USD (Wire transfer)»
- https://support.google.com/googleplay/android-developer/answer/137997?hl=en — «Merchants who receive local-currency payouts: US$1 / Merchants who receive USD wire-transfer payouts: US$100»

**Apple**
- https://developer.apple.com/support/downloads/terms/exhibits/Exhibits-to-Schedule-2-and-3-English.pdf — Exhibit A, **2026-08-27**. Commissionaire бүсэд **Mongolia** нэрлэгдсэн
- https://developer.apple.com/support/downloads/terms/apple-developer-program/Apple-Developer-Program-License-Agreement-English.pdf — ижил жагсаалт
- https://developer.apple.com/terms/ — хоёр PDF-ийн эх индекс
- https://developer.apple.com/help/app-store-connect/reference/financial-report-regions-and-currencies/ — «South Asia and Pacific | USD | AP | … Mongolia …». Шууд татаж баталгаажуулсан
- https://developer.apple.com/help/app-store-connect/reference/reporting/minimum-payment-threshold/ — «All other bank countries or regions … must exceed a minimum payment threshold of 40 USD». Монгол хүснэгтэд байхгүй → анхдагч 40 USD
- https://developer.apple.com/help/app-store-connect/reference/banking-information/ — «If you can't identify your bank in App Store Connect, it may be that Apple can't send payments to that bank»
- https://developer.apple.com/help/app-store-connect/manage-banking-information/enter-banking-information/ — улсын жагсаалт байхгүй
- https://apps.apple.com/mn/app/minecraft/id479516143 — HTTP 200, «USD 6.99»

**Уншиж чадаагүй зүйлс (шударгаар тэмдэглэв)**
- `play.google.com/supported-locations` — JS/Flutter, статикаар өгөгдөл байхгүй
- `web.archive.org` — энэ орчноос egress policy-оор хаалттай, HTTP 429
