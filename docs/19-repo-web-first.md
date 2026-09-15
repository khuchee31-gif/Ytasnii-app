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
