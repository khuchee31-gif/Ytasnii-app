# Бүлэг 19 — Repo-гийн бүтэц ба веб-эхний хувилбар (PWA)

> **Гол дүгнэлт**
> - **`khuchee31-gif/Ytasnii-app` repo-г хаяхгүй, монорепо болгож хувиргана.** Судалгааны дэвтэр `docs/`-д үлдэнэ, Three.js хуудас `site/legacy-studio/`-д буутгагдана, PWA демо `web/`-д, Flutter хожим `app/`-д орно.
> - **Хамгийн түрүүнд гарах бодит хувилбар бол GitHub Pages дээрх PWA.** Зардал **0 ₮**, дэлгүүрийн хяналт байхгүй, push хийснээс хойш **~90 секундэд** амьд болдог, iOS болон Android хоёуланд ажилладаг, яг чиний хэрэгтэй **офлайн, утас дамжуулах** горимыг бүрэн барьдаг.
> - **iOS дээр PWA гацдаг цорын ганц газар бол дэлгэц унтарсан/түгжигдсэн үеийн дуу.** Утас дамжуулах горимд дэлгэц **асаалттай** байдаг тул энэ хамаагүй. Screen Wake Lock нь суулгасан iOS веб аппад **iOS 18.4 (2025-03-31)**-өөс хойш ажилладаг.
> - **Хамгийн далд хугацаа: Android-ын хөгжүүлэгч баталгаажуулалт.** Хэрэгжилт **2026-09-30**-нд BR/ID/SG/TH-д эхэлж, **2027 онд дэлхий даяар** тархана. Ангийнхандаа үнэгүй APK тараах арга дуусах хугацаатай.
> - **Хамгийн шууд алдаа: repo-д `main` салбар алга.** Үндсэн салбар нь `claude/unclear-request-kgCmA` бөгөөд GitHub API `has_pages: false` гэж хэлж байна — deploy workflow нь өнөөг хүртэл юу ч нийтлээгүй.
> - **Веб код хаягдал болохгүй:** 3-р бүлгийн шөнийн шийдвэрлэлтийн дүрмийг нэг цэвэр, сангаас хамааралгүй модуль болгож бичээд Flutter руу яг тэр хэвээр нь зөөнө.

*Судалгааны огноо: 2026-09-15. Эх тайлан: 15-05-repo-and-web-first.md*

---

## Энэ бүлгийг хэрхэн унших вэ

**Судалгааны огноо: 2026-09-15.** Бүх тоо өөрийн эх сурвалж, огноогоо авч явна. Анхдагч эх сурвалжаас
батлаж чадаагүй зүйлийг **[баталгаажаагүй]** эсвэл **[тооцоолол]** гэж тэмдэглээд, хажууд нь яаж шалгахыг
бичсэн. Эдгээр тэмдэглэгээг арилгаж болохгүй — тэдгээр нь «энэ тоог чи өөрөө хэмжих ёстой» гэсэн даалгавар.

Кодын нэр, файлын зам, API, бүтээгдэхүүний нэр (GitHub Pages, Flutter, Vite, Safari, WebKit гэх мэт) латинаар
хэвээр үлдсэн. Кодын блокууд англиар/кодоор үлдэнэ; блок бүрийн өмнө монголоор тайлбар бий.

> **Юу гэсэн үг вэ?** **PWA** = Progressive Web App. Энэ бол хөтөч дээр ажилладаг, гэхдээ утсандаа
> «нүүр дэлгэцэд нэмэх» замаар жинхэнэ апп шиг дүрс, бүтэн дэлгэцтэй болгож болдог вэб сайт. Дэлгүүрт
> тавих шаардлагагүй, хяналт дамжих шаардлагагүй, мөнгө төлөх шаардлагагүй.

---

## 0. Шийдвэрийн хайрцаг

| Асуулт | Хариулт |
|---|---|
| `khuchee31-gif/Ytasnii-app`-д юу болох вэ? | **Хэвээр үлдээ. Монорепо болго.** Судалгааны дэвтэр `docs/`-д, Three.js хуудас `site/legacy-studio/`-д, PWA демо `web/`-д, Flutter хожим `app/`-д. |
| Хамгийн түрүүнд гаргах боломжтой хувилбар? | **Тийм — GitHub Pages дээрх PWA.** Зардал тэг, хяналт тэг, push бүрд ~90 секундэд амьд, iOS болон Android дээр ажиллана, мөн **яг тэр** офлайн утас дамжуулах мөчлөгийг барина. |
| PWA iOS дээр эвдрэх үү? | Зөвхөн чамд хэрэггүй нэг газар: **дэлгэц унтарсан/түгжигдсэн үеийн дуу.** Утас дамжуулах хөтлөлт дэлгэц **асаалттай** үед болдог, харин Screen Wake Lock нь суулгасан iOS веб аппад **iOS 18.4 (2025-03-31)**-өөс ажиллаж байгаа. |
| Хамгийн том далд хугацаа | **Android-ын хөгжүүлэгч баталгаажуулалт.** Хэрэгжилт 2026-09-30-нд BR/ID/SG/TH-д, **2027 онд дэлхий даяар**. Ангийнхандаа үнэгүй APK тараах арга дуусах хугацаатай. |
| Хамгийн шууд алдаа | Repo-д **`main` салбар байхгүй**, үндсэн салбар нь `claude/unclear-request-kgCmA`, GitHub API **`has_pages: false`** гэж хэлж байна — deploy workflow юу ч нийтэлж үзээгүй. |

---

## 1. Repo өнөөдөр яг ямар байна вэ (2026-09-15-нд аудит хийсэн)

Доорх баримтууд ой санамжаас биш, ажлын мод (working tree) болон GitHub REST API-аас шууд авсан:

| Зүйл | Утга |
|---|---|
| Remote | `https://github.com/khuchee31-gif/Ytasnii-app` |
| Харагдац | нээлттэй (public) |
| Үндсэн салбар | `claude/unclear-request-kgCmA` |
| Origin дээрх салбарууд | `claude/unclear-request-kgCmA`, `claude/mafia-game-rules-gbdh82`, `claude/gta-style-webgl-demo-qv9j0x` — **`main` байхгүй** |
| `has_pages` (API) | `false` — Pages асаагүй; юу ч deploy болоогүй |
| Repo-гийн хэмжээ (API) | 52 KB |
| Үндсэн (root) файлууд | `index.html` (8 KB), `main.js` (16 KB), `style.css` (12 KB) — unpkg importmap-аар Three.js 0.160.0 |
| `docs/` | 14 монгол бүлэг, нийт **27,959 үг** |
| Workflow | `.github/workflows/deploy.yml`, `claude/unclear-request-kgCmA` **ба `main`** салбар руу push хийхэд ажиллана, `configure-pages@v5` дээр `enablement: true`, `upload-pages-artifact@v3` дээр `path: "."` |

> **Баталгаажуулалт (2026-09-15):** Дээрх мөрүүд бол ой санамжийн таамаг биш, тухайн өдөр татсан
> API-гийн хариу. Эх сурвалж: https://api.github.com/repos/khuchee31-gif/Ytasnii-app (2026-09-15-нд татсан).
> Чи өөрөө `curl https://api.github.com/repos/khuchee31-gif/Ytasnii-app | grep has_pages` гэж давтан шалгаж болно.

Энэ тохиргоонд гурван тодорхой согог бий:

1. **`main` байхгүй**, тиймээс workflow-гийн триггерийн тал нь үхмэл, мөн `main` байгаа гэж үздэг бүх хэрэгсэл,
   баримт бичиг, заавар уншигчийг төөрөгдүүлнэ.
2. `upload-pages-artifact` + `deploy-pages` бол **түүхий статик байршуулалт — Jekyll огт ажиллахгүй**.
   Өөрөөр хэлбэл `docs/01-rules.md` нь хөтөч дээр **татаж авах `.md` файл** болж үйлчлэгдэнэ, уншигдах
   хуудас болохгүй. Pages асаалттай байсан ч гэсэн судалгааны дэвтэр одоогийн байдлаар вэб дээр уншигдахгүй.
3. `path: "."` нь `.github/`, git-д бүртгэлтэй бүх модыг, хожим нь Flutter-ийн эх кодыг хүртэл нийтэлнэ.
   Чамд тодорхой заасан build хавтас хэрэгтэй.

> **Юу гэсэн үг вэ?** «Jekyll» бол GitHub Pages-ийн дотор суусан Markdown → HTML хөрвүүлэгч. Хэрэв чи
> Actions-аар түүхий файлаа шууд байршуулбал Jekyll дуудагдахгүй, тиймээс `.md` файл хөрвөхгүй.

---

## 2. Шийдвэр: repo-той юу хийх вэ

### 2.1 Хувилбаруудыг жинлэх

| Хувилбар | Давуу тал | Сул тал | Дүгнэлт |
|---|---|---|---|
| **A. Одоогийн буух хуудсыг үлдээж, repo-гийн root дээр тоглоомын маркетингийн сайт болгох** | Юу ч зөөх шаардлагагүй; Pages аль хэдийн root руу заасан | Three.js хуудас Мафитай огт хамаагүй; хожим root нь аппын эх кодоор дүүрнэ; `path: "."` файл алдсаар байна | Үгүй |
| **B. Сайтыг `docs/` нийтлэх эх сурвалж эсвэл `gh-pages` салбар руу зөөх** | Сонгодог, цэвэр тусгаарлалт | `docs/` аль хэдийн судалгааны дэвтэр — мөргөлдөнө. `gh-pages` гэдэг нь гараар синк барих хоёр дахь салбар, харин Actions дээр суурилсан Pages үүнийг илүүц болгодог | Үгүй |
| **C. Flutter аппад шинэ repo, энэ нь дизайн+маркетинг болж үлдэх** | Цэвэр аппын repo, жижиг clone | Ганц өсвөр насны хөгжүүлэгчид хоёр repo = хоёр issue tracker, хоёр CI тохиргоо, хоёр README, хоорондоо зөрөх баримт бичиг. Дэвтэр ба код нэг сарын дотор салж эхэлнэ | Үгүй |
| **D. Энэ repo дотор монорепо** | Нэг `git clone`, нэг issue tracker, баримт ба код хамт хувилбарждаг, нэг Pages deploy нь маркетинг + дэвтэр + тоглох демог нэг commit-оос нийтэлнэ | Repo томордог; Flutter-ийн build артефактуудыг `.gitignore` хийх ёстой; CI зам (path) шүүлт хийх ёстой | **Тийм** |

GitHub Pages яг гурван нийтлэх эх сурвалжийг дэмждэг: салбарын root, салбар дээрх `/docs` хавтас, эсвэл
**GitHub Actions workflow** ([GitHub Docs](https://docs.github.com/en/pages/getting-started-with-github-pages/configuring-a-publishing-source-for-your-github-pages-site)).
Чи нэг repo-оос гурван өөр зүйл нийтлэх ёстой болохоор **зөвхөн Actions ажиллана** — мөн чамд Actions workflow
аль хэдийн байгаа, зүгээр л жинхэнэ build хавтас хэрэгтэй.

Pages-ийн хязгаарууд бүгд зөөлөн бөгөөд энэ төсөлд хэрэгтэйгээс хамаагүй өндөр
([GitHub Docs, Pages limits](https://docs.github.com/en/pages/getting-started-with-github-pages/github-pages-limits)):
нийтэлсэн сайт **1 GB**, санал болгож буй repo хэмжээ **1 GB**, сарын урсгал **100 GB/сар**, deploy-гийн
хугацаа хэтрэлт 10 минут. Хожим жинхэнэ хамаатай нэг анхааруулга: Pages-ийг **«онлайн бизнес, e-commerce
сайт, эсвэл … арилжааны software as a service»**-ийн хостинг болгохыг **тодорхой хориглосон**. Үнэгүй
тоглоомын демо ба баримт бичгийн сайт асуудалгүй; апп доторх худалдан авалтын backend болохгүй.

> **Баталгаажуулалт (2026-09-15):** «Гурван нийтлэх эх сурвалж» ба «арилжааны хэрэглээг хориглох» заалт
> хоёулаа GitHub-ын албан ёсны баримтаас шууд авсан:
> https://docs.github.com/en/pages/getting-started-with-github-pages/configuring-a-publishing-source-for-your-github-pages-site
> ба https://docs.github.com/en/pages/getting-started-with-github-pages/github-pages-limits

### 2.2 Яг ямар алхмууд хийх вэ

Доорх блок бол терминал дээр яг дарааллаар нь бичих командууд. `git mv` нь файлыг зөөхийн зэрэгцээ git-д
«энэ бол зөөлт, шинэ файл биш» гэж хэлж өгдөг тул түүхийг хадгална. Эхний алхам хамгийн чухал: **дэлхий
нийт байгаа гэж үздэг `main` салбарыг үүсгэх.**

```bash
cd /home/user/Ytasnii-app

# 0. Create the branch the whole world assumes exists.
git checkout claude/mafia-game-rules-gbdh82      # the branch holding the dossier
git checkout -b main
git push -u origin main
# Then in GitHub UI: Settings → General → Default branch → main
# and Settings → Pages → Source: "GitHub Actions"

# 1. Demote the Three.js page. Keep it — it is a decent portfolio piece —
#    but it is not the Mafia marketing site.
mkdir -p site/legacy-studio
git mv index.html  site/legacy-studio/index.html
git mv style.css   site/legacy-studio/style.css
git mv main.js     site/legacy-studio/main.js

# 2. Create the real directories.
mkdir -p site web/public/audio/mn web/public/icons web/src app docs/assets
touch app/.gitkeep

# 3. New root landing page (see §6 for contents).
#    site/index.html  — written fresh, in Mongolian.

# 4. Replace the Pages workflow (see §2.4).
git rm .github/workflows/deploy.yml
# create .github/workflows/pages.yml

git add -A
git commit -m "chore: restructure repo into monorepo (docs/web/app/site)"
git push
```

### 2.3 Гарах мод (бүтэц)

Энэ бол зөөлтийн дараах repo-гийн бүтэн бүтэц. Тайлбарууд (`#`-ийн ард) тухайн хавтас юунд зориулагдсаныг хэлнэ.

```
Ytasnii-app/                       (default branch: main)
├─ README.md                       # bilingual front door, §6
├─ LICENSE
├─ .gitignore                      # app/build, app/.dart_tool, web/dist, node_modules
├─ docs/                           # THE DOSSIER — paths unchanged, 14 chapters
│  ├─ index.md                     # NEW: table of contents
│  ├─ 01-rules.md … 14-legal-safety.md
│  └─ assets/                      # diagrams, night-phase flowcharts
├─ web/                            # THE PWA — first shippable build
│  ├─ index.html
│  ├─ src/                         # game state machine, night resolver, i18n
│  ├─ public/
│  │  ├─ manifest.webmanifest
│  │  ├─ sw.js
│  │  ├─ icons/{192,512,maskable-512}.png
│  │  └─ audio/mn/*.m4a            # pre-recorded narrator lines (AAC)
│  ├─ package.json                 # vite
│  └─ vite.config.ts               # base: '/Ytasnii-app/play/'
├─ app/                            # Flutter client — empty until v1.1
├─ site/
│  ├─ index.html                   # marketing landing page (Mongolian)
│  └─ legacy-studio/               # archived Three.js experiment
└─ .github/workflows/
   ├─ pages.yml                    # builds site + docs + web → one artifact
   └─ flutter-ci.yml               # later; paths-filter on app/**
```

Нийтлэгдэх URL-ууд (төслийн сайтын формат нь GitHub Docs-ын дагуу `https://<owner>.github.io/<repo>`):

| Зам | Агуулга |
|---|---|
| `https://khuchee31-gif.github.io/Ytasnii-app/` | Маркетингийн буух хуудас |
| `https://khuchee31-gif.github.io/Ytasnii-app/docs/` | Уншигдахаар хөрвүүлсэн судалгааны дэвтэр |
| `https://khuchee31-gif.github.io/Ytasnii-app/play/` | **Тоглож болох PWA** |

### 2.4 Чамайг заавал хазах ганц зүйл: дэд замын хамрах хүрээ (subpath scope)

Энэ бол *төслийн* сайт учраас апп нь `/` дээр биш, **`/Ytasnii-app/play/`** дээр амьдарна. Service worker
зөвхөн өөрийн зам болон түүнээс доош байгааг удирдаж чаддаг. Тиймээс доорх бүгд **хоорондоо таарах ёстой**:

| Тохиргоо | Байх ёстой утга |
|---|---|
| Vite `base` | `/Ytasnii-app/play/` |
| `manifest.webmanifest` → `start_url` | `/Ytasnii-app/play/` |
| `manifest.webmanifest` → `scope` | `/Ytasnii-app/play/` |
| Service worker файлын байршил | `/Ytasnii-app/play/sw.js` |
| `navigator.serviceWorker.register(...)` | `('/Ytasnii-app/play/sw.js', { scope: '/Ytasnii-app/play/' })` |

Эдгээрийн аль нэгийг буруу бичвэл сонгодог шинж тэмдэг гарна: апп суудаг, дараа нь нээхэд **хоосон дэлгэц**
эсвэл маркетингийн хуудас гарч ирдэг. Хэрэв чи хожим домэйн худалдаж аваад (жишээ нь `shuniihot.mn`) Pages
руу custom domain болгож заавал, дээрх бүгд `/` рүү буцаж хураагдана — тиймээс замаас хамааралтай олон код
бичихээс **өмнө** үүнийг хий, эсвэл суурь замыг **ганц тогтмолд** (constant) хадгал.

> **Юу гэсэн үг вэ?** «Scope» гэдэг нь service worker-ийн эрх мэдлийн хил. `/Ytasnii-app/play/` scope-той
> worker нь `/Ytasnii-app/docs/` хуудсыг барьж чадахгүй. Энэ бол алдаа биш, аюулгүй байдлын зориудын хязгаар.

---

## 3. PWA офлайн хөтлөгчийг үнэхээр авч явж чадах уу? (2026 оны бодит байдал)

### 3.1 Асуултыг зөв тавихад шийдвэр өөрөө гарч ирнэ

Айлгадаг гарчиг — *«iOS дээрх PWA дэлгэц түгжигдсэн үед дуу тоглуулж чадахгүй»* — нь **үнэн боловч хамаагүй**.
Утас дамжуулах Мафид утас ширээн дээр нүүрээрээ дээшээ хараад байдаг, эсвэл тоглогчийн гарт байдаг, мөн
дэлгэц нь **асаалттай**, учир нь тэр дээр «Та мафи» / таймер / саналын жагсаалт харагдаж байгаа. Шаардлага бол
*арын дэвсгэр* (background) дуу биш. Шаардлага бол **«Хөтлөгч ярьж байх хугацаанд дэлгэц бүүдийж, түгжигдэхгүй
байх»**. Энэ бол Screen Wake Lock бөгөөд ажилладаг.

> **Юу гэсэн үг вэ?** **Screen Wake Lock** бол «дэлгэцээ унтраа» гэсэн системийн таймерыг түр зогсоодог
> веб API. `navigator.wakeLock.request('screen')` гэж дуудна. Баттерей идэвхтэй иддэг тул шөнийн үе дуусмагц
> буцааж суллах ёстой.

### 3.2 Яг энэ хэрэглээний чадварын матриц

| Хэрэгтэй чадвар | Android Chrome (WebAPK) | iOS Safari таб | iOS-д суулгасан Нүүр дэлгэцийн веб апп |
|---|---|---|---|
| Дуут хөтлөлт, дэлгэц **асаалттай**, апп нүүрэн талд | Тийм | Тийм | **Тийм** |
| Эхний тоглуулалт хэрэглэгчийн товшилт шаардана | Тийм (autoplay бодлого) | Тийм | Тийм — `click` боловсруулагч дотор `AudioContext.resume()` ([MDN autoplay guide](https://developer.mozilla.org/en-US/docs/Web/Media/Guides/Autoplay)) |
| 60 сек шөнийн үед дэлгэцийг сэрүүн барих | Тийм, Screen Wake Lock | Тийм, **iOS 16.4+** | **Тийм, iOS/iPadOS 18.4+** — 2025-03-31-нд засагдсан, [WebKit bug 254545](https://bugs.webkit.org/show_bug.cgi?id=254545) |
| Дэлгэц **унтарсан / түгжигдсэн** үеийн дуу | Тийм (Chrome арын дэвсгэрийн медиаг тоглуулна; MediaSession түгжээний дэлгэц дээр удирдлага өгнө) | Хагас, «заримдаа контекстээ алддаг» | **Үгүй.** Жижигрүүлэх/түгжихэд зогсоно; түгжээний дэлгэц дээрх тоглуулалт ~30 сек зогссоны дараа үхнэ ([Apple Dev Forums 762582](https://developer.apple.com/forums/thread/762582), 2024-08, Apple-ээс хариу өгөөгүй) |
| Анх ачаалсны дараа **сүлжээ огт байхгүй** үед ажиллах | Тийм, service worker + Cache API | Тийм | Тийм |
| Хадгалалтын цэвэрлэгээг (storage eviction) даван гарах | Тийм | **Үгүй** — ITP нь 7 хоног харилцаагүй бол скриптээр бичигдэх хадгалалтыг устгана | **Тийм** — нүүр дэлгэцийн веб аппууд **7 хоногийн хязгаараас чөлөөлөгдсөн** ([WebKit Tracking Prevention](https://webkit.org/tracking-prevention/)) |
| Хадгалалтын квот | Их | Хөтчийн түвшний | Хөтчийн түвшний, Safari 17-оос хойш нэг origin-д дискний ~60 % |
| Нэг товшилтоор суулгах урилга | Тийм, `beforeinstallprompt`, жинхэнэ хөтөлбөр эхлүүлэгчийн дүрс | хамаарахгүй | **Үгүй** — хэрэглэгч Share → «Add to Home Screen» гэж гараар дарах ёстой. **iOS 16.4**-өөс хойш iOS дээрх Chrome/Edge/Firefox ч мөн үүнийг хийж чадна |
| Push мэдэгдэл | Тийм | Үгүй | Тийм, **iOS 16.4+** (зөвхөн нүүр дэлгэцэд суусан үед); Declarative Web Push нь **Safari 18.4**-д нэмэгдсэн |
| Албадсан хэвтээ чиглэл / жинхэнэ бүтэн дэлгэц | Тийм | Найдваргүй | Найдваргүй |
| `speechSynthesis`-ээр монгол TTS | Төхөөрөмжийн TTS хөдөлгүүрээс хамаарна | Хэрэглэгчийн үйлдэл шаардана; `mn-MN` хоолой байх баталгаагүй | Мөн адил |

Screen Wake Lock-ийн дэлхийн дэмжлэг **94.92 %** ([caniuse.com/wake-lock](https://caniuse.com/wake-lock),
2026-09-15-нд татсан); Safari iOS 16.4-өөс 27.1 хүртэл бүгд бүрэн дэмжлэгтэй гэж мэдээлдэг.

> **Баталгаажуулалт (2026-09-15):** **94.92 %** гэсэн тоо бол тухайн өдөр caniuse-аас татсан бодит утга,
> дугуйлсан таамаг биш. Эх сурвалж: https://caniuse.com/wake-lock — энэ тоо сар бүр өөрчлөгддөг тул
> шинэчлэхдээ мөн адил татаж шалга.

> **Баталгаажуулалт (2026-09-15):** «iOS дээр суулгасан веб апп Wake Lock-ийг дэмждэг» гэдэг нь WebKit-ийн
> алдааны бүртгэлээр батлагдсан: [WebKit bug 254545](https://bugs.webkit.org/show_bug.cgi?id=254545), мөн
> Safari 18.4-ийн тэмдэглэл: https://webkit.org/blog/16574/webkit-in-safari-18-4/ . Харин «дэлгэц унтарсан
> үеийн дуу» **засагдаагүй** хэвээр — Apple-ийн форумын 762582 дугаартай санал хүсэлтэд (2024-08) Apple
> өнөөг хүртэл хариу өгөөгүй: https://developer.apple.com/forums/thread/762582

### 3.3 Дизайны үр дагавар — эдгээрийг хий, нөгөөг нь бүү хий

1. **Урьдчилан бичсэн монгол дууны файл ачаал, `speechSynthesis` бүү найд.** Монгол сурагчийн утсанд
   `mn-MN` хоолой суусан байх ямар ч баталгаа байхгүй; iOS дээр хоолойн жагсаалт WebKit-ээс ирдэг бөгөөд
   `speak()` нь зөвхөн хэрэглэгчийн үйлдлийн дотор ажилладаг. ~40 мөр хөтлөлтийг AAC/`.m4a` форматаар
   64 kbps моно хийвэл яриа тутмын нэг минут нь ойролцоогоор **500 KB [тооцоолол]** — нэг мөрийг кодлож
   үзээд минутад хэдийг эзлэхийг үржүүлэн шалга. Бүгдийг нь service worker-ийн `install` алхамд урьдчилан
   кэшлэ (precache).
2. **Бүх зүйлийг ганц «Эхлүүлэх» товч нээнэ.** Тэр ганц товшилтын дотор: `audioCtx.resume()`,
   `navigator.wakeLock.request('screen')`, чимээгүй `<audio>` элементийг тайлах, мөн бүтэн дэлгэц рүү орох.
   Энэ бол iOS-ийн стандарт «тайлах» загвар.
3. **`visibilitychange` дээр wake lock-оо дахин ав.** Баримт бичиг нуугдмал болох болгонд түгжээ суларна;
   дахин авахгүй бол эхний удаа таб сольсны дараа дэлгэц бүүдийж эхэлнэ.
4. **iPhone-ийн Ring/Silent (дуугүй) товчийг сануул.** Хонхны тохиргоо чимээгүй/чичиргээ байвал WebKit нь
   Web Audio-г тоглуулахгүй. Эхлэх дэлгэц дээр монголоор нэг мөр бич: «Утасны хажуугийн дуугүй товчийг асаа.»
5. **`<audio>` элементийг байнга холбоотой (mounted) байлга**, мөр болгонд шинээр үүсгэж болохгүй; шаардлагаар
   элемент үүсгэдэг багууд iOS дээр тоглуулах зөвшөөрлөө алддаг.
6. **Тоглоомын төлөвийг зөвхөн `localStorage`-д бүү найд.** Safari-гийн энгийн табд 7 хоног хөдөлгөөнгүй
   байвал устгагдаж мэднэ. Суулгасан бол чөлөөлөгдөнө — энэ нь өөрөө UI дотор «Нүүр дэлгэцэд нэмэх»-ийг
   хүчтэй сурталчлах хамгийн том үндэслэл.
7. **Chrome-ын суулгах шалгуурыг яг таг хангана**, эс бөгөөс Android хэрэглэгчид WebAPK-г хэзээ ч авахгүй:
   HTTPS, `name`, `short_name`, `start_url`, `display: standalone`, `background_color`, `theme_color` бүхий
   manifest, ≥ 512×512 дүрс, дээр нь **хоосон биш** `fetch` боловсруулагчтай бүртгэгдсэн service worker
   (Chrome хоосныг тооцдоггүй).
8. **iOS-д зориулж өөрийн суулгах зааварчлагчийг бич.** iOS дээр `beforeinstallprompt` гэж байхгүй. iOS UA
   дээр `navigator.standalone === false` эсэхийг илрүүлээд Share → «Нүүр дэлгэцэд нэмэх» гэсэн хөдөлгөөнт
   зөвлөмжийг монголоор үзүүл.

> **Баталгаажуулалт (2026-09-15):** **iOS 26**-д «manifest байхгүй ч Нүүр дэлгэцэд нэмсэн аль ч сайт веб
> апп болж нээгддэг» гэсэн мэдээлэл нь **[баталгаажаагүй]** — зөвхөн хоёрдогч эх сурвалжууд байна.
> Шалгах арга: iOS 26 суулгасан бодит iPhone дээр manifest-гүй хуудсыг Нүүр дэлгэцэд нэмээд, Safari-гийн
> хөтчийн хүрээ (chrome) харагдаж байгаа эсэхийг нүдээр шалга. Хоёрдогч эх сурвалжууд:
> https://tips.ojapp.app/en/pwa-ios-2026-complete-guide/ ба
> https://www.magicbell.com/blog/pwa-ios-limitations-safari-support-complete-guide

> **Баталгаажуулалт (2026-09-15):** **500 KB/минут** гэсэн дууны хэмжээ бол **[тооцоолол]**, хэмжилт биш.
> Шалгах арга: нэг мөр хөтлөлтийг 64 kbps моно AAC-аар кодлоод, гарсан файлын байтыг үргэлжлэх хугацаанд
> хуваа, дараа нь 40 мөрөөр үржүүл. Chrome-ын суулгах шалгуурын жагсаалтыг
> https://developer.chrome.com/blog/update-install-criteria ба
> https://developer.mozilla.org/en-US/docs/Web/Progressive_web_apps/Guides/Making_PWAs_installable дээрээс шалга.

Доорх псевдо-код бол дээрх 2, 3 дугаар зөвлөмжийг нэг дор хэрэгжүүлсэн «эхлүүлэх товч»-ийн ясны бүтэц.
Энэ бүхэн **нэг** хэрэглэгчийн товшилтын дотор багтах ёстой гэдгийг анхаар — iOS-д хоёр дахь товшилт
хүртэл хүлээвэл дуу тайлагдахгүй.

```js
// One tap unlocks everything. Do NOT split this across two handlers.
let wakeLock = null;
const audioCtx = new (window.AudioContext || window.webkitAudioContext)();
const narrator = document.querySelector('audio#narrator'); // mounted once, forever

startBtn.addEventListener('click', async () => {
  await audioCtx.resume();                 // iOS autoplay unlock
  narrator.muted = true;
  await narrator.play();                   // prime the element
  narrator.pause(); narrator.muted = false;

  try { wakeLock = await navigator.wakeLock.request('screen'); }
  catch (e) { showHint('Дэлгэц унтарч магадгүй. Тохиргооноос унтрах хугацааг уртасга.'); }

  await document.documentElement.requestFullscreen?.().catch(() => {});
  startNight(1);
});

// The lock dies whenever the page is hidden. Take it back.
document.addEventListener('visibilitychange', async () => {
  if (document.visibilityState === 'visible' && wakeLock === null) {
    try { wakeLock = await navigator.wakeLock.request('screen'); } catch {}
  }
});
```

Service worker-ийн `install` алхамд хөтлөгчийн бүх дууг урьдчилан кэшлэх хэсэг. `fetch` боловсруулагч нь
**хоосон биш** байх ёстой гэдгийг санаарай — Chrome хоосон боловсруулагчтай worker-ийг суулгах шалгуурт
тооцдоггүй.

```js
// web/public/sw.js
const CACHE = 'ytasnii-v1';
const PRECACHE = [
  '/Ytasnii-app/play/',
  '/Ytasnii-app/play/index.html',
  '/Ytasnii-app/play/manifest.webmanifest',
  ...Array.from({ length: 40 }, (_, i) => `/Ytasnii-app/play/audio/mn/line-${i + 1}.m4a`),
];

self.addEventListener('install', (e) => {
  e.waitUntil(caches.open(CACHE).then((c) => c.addAll(PRECACHE)).then(() => self.skipWaiting()));
});

// NON-EMPTY fetch handler — required by Chrome's install criteria.
self.addEventListener('fetch', (e) => {
  e.respondWith(caches.match(e.request).then((hit) => hit || fetch(e.request)));
});
```

### 3.4 PWA-д ямар веб стек сонгох вэ?

*Энэ* хувилбарт Flutter биш. Flutter web-ийн CanvasKit renderer нь чиний өөрийн кодоос өмнө л
**~1.5–2 MB gzip хийсэн** хэмжээтэй, мөн WasmGC/skwasm нь Chrome 119+/Firefox 120+/**Safari 18.2+**
шаарддаг, `--wasm`-аар build хийхэд хажууд нь JS+CanvasKit нөөц хувилбар гардаг. Монгол сурагчийн дунд
зэргийн Android дээр, сургуулийн Wi-Fi-аар хийх анхны тоглолт-туршилтад **~30 KB**-ын vanilla-TS/Vite build
секундээс бага хугацаанд ачаалагдаж бүрэн давуутай ялна.

Дэлгүүрийн апп-д Flutter-ээ үлдээ (08-р бүлгийн дэлгэц унтарсан үеийн хөтлөлт ба кирилл үсгийн рендерийн
үндэслэл хэвээр хүчинтэй); гэхдээ **03-р бүлгийн шөнийн шийдвэрлэлтийн дүрмийг нэг удаа, цэвэр, ямар ч
сангаас хамааралгүй тодорхойлолт болгож бичээд зөөх** ёстой — тэгж байж хоёр хэрэгжүүлэлт «Эмч хэнийг
аварсан бэ» гэдэг дээр хоорондоо зөрөхгүй.

> **Юу гэсэн үг вэ?** «Vanilla-TS» гэдэг нь React/Vue гэх мэт framework-гүй, цэвэр TypeScript. «Vite» бол
> хөгжүүлэлтийн сервер ба багцлагч. Энэ хоёрын build нь маш жижиг гардаг тул удаан сүлжээнд хожино.
