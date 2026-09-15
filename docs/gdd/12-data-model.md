# GDD-12 — Өгөгдлийн модель, хадгалалт ба сэргээлт

> **Шийдвэрийн хураангуй**
> - **Нэг файл, нэг хөдөлгүүр: `sqflite` дээрх гараар бичсэн SQL.** `drift` байхгүй, codegen байхгүй, `shared_preferences` байхгүй. Хүснэгт 11, миграц 30 мөр — харин гацсан `build_runner` нэг удаадаа ~2 цаг авдаг, тэр нь долоо хоногийн төсвийн 20%.
> - **Үнэн бол `events` хүснэгт; `games` ба `game_seats` бол кэш**, `fold(events)`-оос хэзээ ч дахин бүтээгдэнэ. Бүртгэл зөвхөн нэмэгдэнэ: `UPDATE`/`DELETE` нь цэвэрлэгээнээс өөр газар код review-д хориотой.
> - **`no-paint-before-commit`.** Атом үйлдэл бүр нэг транзакц; `await` эргэж ирсний **дараа** л дэлгэц зурагдана. `WAL` + `synchronous=FULL` — батерей дуусахад хамгийн сүүлийн **нэг** үйлдэл л алдагдана.
> - **Сэргээлт хэзээ ч хөзрийг дахин нээхгүй, шөнийн үйлдлээ хийсэн суудлыг дахин асуухгүй.** Алдагдсан 6 секунд нь алдагдсан нууцаас зуу дахин хямд.
> - **Тоглолт бүрт дүрэм хөлддөг:** `games.config_json` + 12 тэмдэгтийн `config_hash`.
> - **Нэг тоглолт ≈ 30 КБ. Бүтэн бүртгэлтэй сүүлийн 50 тоглолт** (≈1.5 МБ) хадгалагдана, дараа нь дэвтрийн нэг мөр болж хумигдана. Хатуу тааз 8 МБ.
> - **`allowBackup="false"` хүртэл.** Google Drive-ийн авто-нөөцлөлт ч унтраасан — ингэснээр Data safety-ийн **«Ямар ч өгөгдөл цуглуулдаггүй»** нь үгчилсэн үнэн болно.
> - **SQL-ийн шал = SQLite 3.9** (`minSdk 24`). `UPSERT`, `json_extract`, цонхны функц, `DROP COLUMN` — байхгүй гэж үз.

*Хамаарал: GDD-00 §3 (4-р багана), §8 (Ангийн дэвтэр), §11 (1 ба 5-р татгалзал); судалгааны 06 §6–7, 08 §2, 10 §5 (P2), 14 §3, 17 §0.*

---

## 0. Нэг зөрчлийг ил тавья

00-vision §8 нь «хүн тус бүрийн ялалтын хувь байхгүй» гэж хэлээд, тэр дороо «ганц хадгалагдах тоо бол мафигаар тоглоход хэдэн санал давж гарсан» гэдэг. Тэр тоо **хүнд** хавсрагдвал яг хориглосон статистик болно. Тиймээс: тоо нь `game_ledger`-т **тоглолтод** хамаарч бичигдэнэ, хүнд хэзээ ч биш. Схемд `roster_members`-ийг ялалтаар нийлбэрлэх индекс, харагдац, query **байхгүй**, бөгөөд код review-ийн дүрэм нь — `roster_members × games` нийлбэр query PR-д орж болохгүй. Анги тэр тоог өөрөө хэлж байх болно; өгөгдлийн сан түүнийг хэлэхгүй.

---

## 1. Хөдөлгүүр, файл, PRAGMA

| Шийдвэр | Юу вэ | Яагаад |
|---|---|---|
| Сан | **`sqflite: ^2`** | Хамгийн уйтгартай, хамгийн сайн баримтжсан. Codegen тэг. |
| DDL | **`assets/db/ddl_v1.sql`** — доорх текст яг өөрөө | Баримт бичиг нь схем өөрөө. Хоёр эх сурвалж байхгүй. |
| Файл | `getDatabasesPath()/khot.db` (+ `-wal`, `-shm`) | Апп устгагдвал OS устгана. |
| Диалект | **SQLite 3.9 шал** (Android 7.0) | `INSERT OR REPLACE` хэрэглэ, JSON-ыг **зөвхөн Dart-д** унш. |
| Тохиргоо | `settings` хүснэгт | Нэг store = нэг экспорт, нэг миграц, нэг устгах товч. |

```dart
// DbOpener.open() — дарааллыг бүү сольж бич
await db.execute('PRAGMA auto_vacuum = INCREMENTAL'); // ЗӨВХӨН хоосон файл дээр ажиллана
await db.execute('PRAGMA journal_mode = WAL');
await db.execute('PRAGMA synchronous = FULL');        // §4-ийн батерейн шийдвэр
await db.execute('PRAGMA foreign_keys = ON');
await db.execute('PRAGMA busy_timeout = 3000');
```

`auto_vacuum` нь **хүснэгт үүсэхээс өмнө** тавигдана, эс бөгөөс бүтэн `VACUUM`-аас өөр арга үлдэхгүй. `synchronous=FULL` нь commit тутамд WAL-ыг fsync хийнэ; бичилт нь frame дотор биш тул төлбөр нь тэвчихийн. **Зорилт: Redmi 9A дээр commit тутам < 25 мс** (§13-ийн 1-р асуулт).

---

## 2. Схем — жинхэнэ DDL

```sql
-- 1) Мета. Схемын хувилбар нь PRAGMA user_version, энд БИШ.
CREATE TABLE meta (k TEXT PRIMARY KEY, v TEXT NOT NULL);
-- 'db_created_at' | 'app_build_at_create' | 'last_prune_at' | 'last_crash_note'

-- 2) Ангийн суудлын жагсаалт. Хэд ч байж болно: 10А, гэр бүл, Наадмын айл.
CREATE TABLE rosters (
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  title        TEXT    NOT NULL,        -- «10А», «Манай айл»
  seat_count   INTEGER NOT NULL,
  created_at   INTEGER NOT NULL,        -- ms, ханын цаг
  last_used_at INTEGER NOT NULL
);

CREATE TABLE roster_members (
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  roster_id    INTEGER NOT NULL REFERENCES rosters(id) ON DELETE CASCADE,
  seat_no      INTEGER NOT NULL,        -- 1..20
  display_name TEXT,                    -- NULL зөвшөөрөгдөнө: суудлын дугаар хангалттай
  UNIQUE (roster_id, seat_no)
);

-- 3) Тоглолт. config_json нь хөлдөөсөн дүрэм (§5).
CREATE TABLE games (
  id            INTEGER PRIMARY KEY AUTOINCREMENT,
  roster_id     INTEGER REFERENCES rosters(id) ON DELETE SET NULL,
  state         TEXT    NOT NULL,       -- 'in_progress' | 'finished' | 'abandoned'
  host_mode     TEXT    NOT NULL,       -- 'APP' | 'HUMAN' (Хөтлөгчтэй горим)
  seat_count    INTEGER NOT NULL,
  mafia_count   INTEGER NOT NULL,
  b_initial     INTEGER NOT NULL,       -- b = floor(N/2) - M - 1
  config_json   TEXT    NOT NULL,
  config_hash   TEXT    NOT NULL,       -- sha256(canonical)[0..12]
  fairness_code TEXT    NOT NULL,       -- 6 hex, чангаар уншигдсан (10 §5, P2)
  seed_commit   TEXT    NOT NULL,       -- SHA256(seed0)
  seed_hex      TEXT,                   -- ЗӨВХӨН тоглолт дуусахад бичигдэнэ
  started_at    INTEGER NOT NULL,
  updated_at    INTEGER NOT NULL,
  ended_at      INTEGER,
  winner        TEXT,                   -- 'TOWN' | 'MAFIA' | NULL
  nights        INTEGER NOT NULL DEFAULT 0,
  resume_seq    INTEGER NOT NULL DEFAULT 0,   -- §4.1 сэргээх цэг
  events_pruned INTEGER NOT NULL DEFAULT 0    -- 1 = бүртгэл хумигдсан
);
CREATE INDEX idx_games_state ON games(state, updated_at DESC);

-- 4) Суудал × тоглолт — fold(events)-оос дахин бүтээгддэг ПРОЕКЦ.
CREATE TABLE game_seats (
  game_id      INTEGER NOT NULL REFERENCES games(id) ON DELETE CASCADE,
  seat_no      INTEGER NOT NULL,
  member_id    INTEGER REFERENCES roster_members(id) ON DELETE SET NULL,
  role_code    TEXT    NOT NULL,   -- 'KILLER'|'BOSS'|'DOCTOR'|'DETECTIVE'|'CITIZEN'
  card_seen_at INTEGER,            -- NULL = хөзрөө хараагүй
  card_reseen  INTEGER NOT NULL DEFAULT 0,
  out_at_phase TEXT,               -- 'N3' | 'D2' | NULL
  out_cause    TEXT,               -- 'NIGHT' | 'VOTE' | NULL
  PRIMARY KEY (game_id, seat_no)
);

-- 5) БҮРТГЭЛ. Зөвхөн нэмэгдэнэ.
CREATE TABLE events (
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  game_id      INTEGER NOT NULL REFERENCES games(id) ON DELETE CASCADE,
  seq          INTEGER NOT NULL,   -- 1-ээс тасралтгүй, тоглолт тус бүрт
  at_ms        INTEGER NOT NULL,   -- ханын цаг. ЗӨВХӨН харуулахад.
  mono_ms      INTEGER NOT NULL,   -- Stopwatch. ЗӨВХӨН үргэлжлэх хугацаанд.
  phase_kind   TEXT    NOT NULL,   -- 'SETUP'|'NIGHT0'|'NIGHT'|'DAY'|'VOTE'|'END'
  phase_no     INTEGER NOT NULL,
  type         TEXT    NOT NULL,
  actor_seat   INTEGER,
  target_seat  INTEGER,
  payload_json TEXT    NOT NULL DEFAULT '{}',
  UNIQUE (game_id, seq)
);
CREATE INDEX idx_events_game ON events(game_id, seq);
CREATE INDEX idx_events_type ON events(game_id, type);

-- 6) Дэвтрийн хуудас. Бүртгэл хумигдсан ч ЭНЭ ҮЛДЭНЭ.
CREATE TABLE game_ledger (
  game_id        INTEGER PRIMARY KEY REFERENCES games(id) ON DELETE CASCADE,
  played_on      TEXT    NOT NULL,    -- 'YYYY-MM-DD' локал
  seat_count     INTEGER NOT NULL,
  mafia_seats    TEXT    NOT NULL,    -- '2,5,9'
  survivor_seats TEXT    NOT NULL,
  nights         INTEGER NOT NULL,
  b_initial      INTEGER NOT NULL,
  b_spent        INTEGER NOT NULL,    -- алдааны нөөцөөс хэд зарцуулсан
  winner         TEXT    NOT NULL,
  pin_count      INTEGER NOT NULL,
  first_out_seat INTEGER,             -- «Бүжигт хүлэг» хэн авсан
  duration_ms    INTEGER NOT NULL
);

-- 7) Цол (v2). Нэмэгдэнэ, ХУМИГДАХГҮЙ, буцааж авагдахгүй.
CREATE TABLE titles (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  member_id  INTEGER NOT NULL REFERENCES roster_members(id) ON DELETE CASCADE,
  code       TEXT    NOT NULL,  -- 'NACHIN'|'HARTSAGA'|'ZAAN'|'GARID'|'ARSLAN'|'AVRAGA'
  awarded_at INTEGER NOT NULL,
  game_id    INTEGER REFERENCES games(id) ON DELETE SET NULL,
  UNIQUE (member_id, code)
);

-- 8) Тохиргоо. shared_preferences-ийн орлуулагч.
CREATE TABLE settings (
  k TEXT PRIMARY KEY, v TEXT NOT NULL, updated_at INTEGER NOT NULL);

-- 9) Аудио багц. «Чимээгүйн хүснэгт» өгөгдөл болж амьдарна.
CREATE TABLE audio_packs (
  id           TEXT PRIMARY KEY,      -- 'mn_human_v1' | 'mn_bataa_v1'
  title        TEXT    NOT NULL,      -- «Монгол хоолой (бичлэг)»
  voice_kind   TEXT    NOT NULL,      -- 'HUMAN' | 'TTS_PRERENDERED'
  clip_count   INTEGER NOT NULL,
  bytes        INTEGER NOT NULL,
  pack_version INTEGER NOT NULL,
  installed_at INTEGER NOT NULL,
  is_active    INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE audio_clips (
  pack_id      TEXT    NOT NULL REFERENCES audio_packs(id) ON DELETE CASCADE,
  clip_id      TEXT    NOT NULL,      -- 'NIGHT_KILL_A' | 'SEAT_07' | 'ROLE_DOCTOR'
  asset_path   TEXT    NOT NULL,
  duration_ms  INTEGER NOT NULL,
  gap_after_ms INTEGER NOT NULL,      -- 00-vision §9-ийн хүснэгт, өгөгдөл болсон
  PRIMARY KEY (pack_id, clip_id)
);
```

`audio_clips.gap_after_ms` бол дизайны шийдвэрийн кодчилол: `NIGHT_START` → **4000**, `NIGHT_KILL_A` → **2500**, дүрийн сэрэх/унтах хос хооронд → **1200**, «Хөзрөө нээе»-гийн суудал хооронд → **1200**. Тест эдгээр тоог хатуу шалгана, тиймээс яарсан хөгжүүлэгч завсрыг «сайжруулж» чадахгүй.

---

## 3. Үйл явдлын төрлүүд

`type` бол үүрд хөлдсөн текст. **Хуучин төрөл утгаа хэзээ ч сольдоггүй; шинэ утга = шинэ нэр.** Уншигч танихгүй төрлийг **алгасаад тоолно** (`unknown_event_count` нь Тусламж дэлгэцэд гарна).

| `type` | Хэзээ | `payload_json` |
|---|---|---|
| `GAME_CREATED` | Тохиргоо батлагдахад | `{}` — дүрэм нь `config_json`-д |
| `SEED_COMMITTED` | Тараахын өмнө | `{"code":"a3f19c","commit":"<64hex>"}` |
| `ENTROPY_ADDED` | Утас сэгсрэгдэхэд | `{"src":"shake","seat":9,"ms":2000}` |
| `DEAL_COMPLETED` | Холилт бодогдоход | `{"roles_hash":"<12hex>"}` |
| `CARD_SEEN` / `CARD_RESEEN` | Хөзөр тавигдах / дахин нээгдэхэд | `{"held_ms":2480}` / `{"n":2}` |
| `PHASE_ENTERED` | Үе шат солигдоход | `{"kind":"NIGHT","no":3}` |
| `INTRO_NIGHT_DONE` | 60 сек дуусахад | `{"actual_ms":60000}` |
| `NIGHT_ACTION` | Суудал товшиход | `{"kind":"KILL"\|"HEAL"\|"CHECK"\|"WHISPER"}` |
| `NIGHT_RESOLVED` | Үүрээр | `{"victim":7,"healed":null,"check":"FOUND"}` |
| `WHISPER_PUBLISHED` | Үүрээр | `{"seats":[3,10],"agree":[4,3]}` |
| `BEST_MOVE_SPOKEN` | Хохирогч 3 дугаар нэрлэхэд | `{"n":3}` — **дугаарууд бичигдэхгүй** |
| `PIN` | 📌 дарагдахад | `{"elapsed_ms":74000,"speaking_seat":5}` |
| `HANDS_COUNTED` | Гар тоологдоход | `{"hands":7}` |
| `EXILED` / `SEAT_ELIMINATED` | Хотоос хөөх / аль ч хасалт | `{}` / `{"cause":"NIGHT"\|"VOTE"}` |
| `BUDGET_SPENT` | Иргэн хасагдахад | `{"b_left":1}` |
| `PAUSED` / `RESUMED` | Дуудлага, хонх, ар тал | `{"reason":"CALL"\|"BACKGROUND"\|"MANUAL"}` |
| `RESUMED_AFTER_KILL` | Сэргээлтээр эхлэхэд | `{"gap_ms":184000,"lost_actions":1}` |
| `GAME_ENDED` / `ABANDONED` | Ялалт / «Хаях» | `{"winner":"TOWN","nights":5}` / `{"at_phase":"D3"}` |
| `AUDIO_FALLBACK` | Клип тоглоогүй | `{"clip":"NIGHT_KILL_B","reason":"PLAYER_DEAD"}` |

`actor_seat` ба `target_seat` нь тусдаа багана — суудлын дугаараар query хийх нь `payload_json`-ыг задлахаас хямд, бөгөөд SQLite 3.9-д `json_extract` байхгүй.

**Яагаад `DEAL_COMPLETED` дүрүүдийг бичихгүй вэ.** Дүр аль хэдийн `game_seats.role_code`-д байна. Бүртгэлд хоёр дахь хуулбар байх нь экспортын файлд дүрүүдийг эрт зөөнө — хэн нэг нь тоглолтын дунд дэвтрээ экспортлоод тараавал нууц урсана. Нэг л газар, нэг л уншигч.

---

## 4. «Атом үйлдэл бүрийн дараа хадгал»

**Атом үйлдэл** = ширээ түүнийг маргалдахгүйгээр дахин хийж чадахгүй ямар ч зүйл: хөзрөө харах, шөнийн товшилт, гар тоолох, 📌, үе шат солих. Frame, дууны эхлэл, товчны товшилтын анимац — атом биш.

```dart
// Бүх бичилт ЭНЭ ганц функцээр явна. Өөр замаар events-д бичих PR татгалзана.
Future<int> commit(GameEvent e) async {
  return _db.transaction<int>((t) async {
    final s = (await t.rawQuery(
      'SELECT COALESCE(MAX(seq),0)+1 AS s FROM events WHERE game_id=?', [e.gameId]
    )).first['s'] as int;
    await t.insert('events', e.toRow(s));
    await t.rawUpdate('UPDATE games SET resume_seq=?, updated_at=? WHERE id=?',
                      [s, e.atMs, e.gameId]);
    await _applyProjection(t, e);   // game_seats / games.nights / winner
    return s;
  });                               // <-- дэлгэц ба аудио ЗӨВХӨН үүний дараа
}
```

**Код review-ийн дүрэм: `no-paint-before-commit`.** Үе шатыг урагшлуулдаг `setState`, `Navigator.push`, `player.play()` — гурвуулаа `await commit(...)`-ийн доор. Тест нь `commit`-ыг 500 мс саатуулж, дэлгэц хөдөлгөөнгүй байгааг шалгана.

**Хэлэлцүүлгийн цаг үйл явдал биш** — тэр урсаж байдаг. **5 секунд тутам** `settings['live_clock_ms']`-д бичигдэнэ; хамгийн муу алдагдал **5 секунд**. Сэргэхэд цагийг ханын цагаас **дахин бодохгүй** — батерей гурван цаг унтарсан байж мэднэ.

### 4.1 Сэргээлтийн гэрээ

Хүйтэн эхлэхэд: `SELECT * FROM games WHERE state='in_progress' ORDER BY updated_at DESC LIMIT 1`. Байвал нүүр хуудсын оронд:

> **«Дуусаагүй тоглоом байна.»** · «10А · 12 суудал · 3-р шөнө · 14 минутын өмнө»
> **«Үргэлжлүүлэх»** · «Хаях»

«Хаях» нь `ABANDONED` бичээд `state='abandoned'` болгоно, **өгөгдлийг устгахгүй** — дэвтэрт «дуусаагүй» хуудас болж үлдэнэ.

| Хаана унасан | Сэргэх цэг | Юуг ХЭЗЭЭ Ч дахин хийхгүй |
|---|---|---|
| Тохиргооны дунд | Тоглолт үүсээгүй; суудал хадгалагдсан | — |
| Тараалтын дунд | `card_seen_at IS NULL` хамгийн бага суудал | Холилтыг дахин бодохгүй; `seed` хөлдсөн |
| Танилцах шөнийн 60 сек-д | Шөнө 0-ийн эхнээс, бүтэн 60 сек | — |
| Шөнийн эргэлтийн 7 дахь суудал | №7-ийн «утсаа өргө» дэлгэц | 1–6-ийн товшилтыг асуухгүй, харуулахгүй |
| `NIGHT_RESOLVED` бичигдсэний дараа | `NIGHT_KILL_A`-аас бүтнээр | Шөнийг дахин бодохгүй; хохирогч бичигдсэн |
| Хэлэлцүүлгийн дунд | `live_clock_ms`-аас | Тэглэхгүй, ханын цагаар нэмэхгүй |
| Гар тоолохын дунд | Тэр нэр дэвшигчийн дугуйнаас | Өмнөх нэр дэвшигчдийг дахин асуухгүй |
| «Хөзрөө нээе»-гийн дунд | Нээгээгүй хамгийн бага суудлаас | Нээгдсэнийг дахин нээхгүй |

**Хамгийн чухал дүрэм:** сэргээлт мэдээллийг дахин **харуулахгүй**. №7 товшилтоо хийчихсэн бол апп «дахин батлаач» гэж асуухгүй — тэр асуулт өөрөө №7 юу хийснийг хажуугийн хүнд шивнэнэ.

**Дахин бүтээлт.** `rebuildProjection(gameId)` нь дериватив талбарыг устгаж, `events`-ийг `seq`-ээр дахин нугална. Проекц эвдэрсэн байж магадгүй ямар ч сэжиг (апп хувилбар сольсон, миграц хийгдсэн, `unknown_event_count > 0`) — дахин нугалаад л болоо. **Дараалал нь `seq`-ээр, `at_ms`-ээр хэзээ ч биш:** ханын цаг хоцорч, ухарч, цагийн хэлтэс солиж чадна.

---

## 5. Тоглолтод хөлдөх тохиргоо

`GAME_CREATED`-ийн үед бүрэн дүрмийн багц JSON болно. **Тоглолтын явцад хөдөлгүүр `settings`-ийг уншихгүй.**

```json
{"cfg_v":3,"seats":12,"mafia":3,"boss":true,"doctor":1,"detective":1,"b":2,
 "night_first":true,"mafia_wins_at":"M>=T","doctor_self_heal":false,
 "reveal_on_elimination":false,"intro_night_ms":60000,"night_seat_ms":6000,
 "discussion_ms":480000,"whisper_min_agree":3,"best_move_ms":20000,
 "host_mode":"APP","theme":"ub_noir","audio_pack":"mn_human_v1","strings_v":7}
```

`config_hash = sha256(canonicalJson)[0..12]`. Хоёр ажил: дэвтэр «ижил дүрмээр тоглосон» хуудсуудыг бүлэглэж чадна, бөгөөд алдааны мэдээлэл 12 тэмдэгтээр дүрмийн багцыг бүрэн нэрлэнэ. Тоглолтын дунд Тохиргоо нээгдвэл дэлгэц **«Дараагийн тоглолтод хүчинтэй»** гэж бичнэ.

`cfg_v` (тохиргоо) ба `user_version` (схем) бие даан өснө. Танихгүй `cfg_v`-тэй тоглолт зөвхөн дэвтрийн мөр болж үзүүлэгдэнэ, сэргээгдэхгүй.

---

## 6. Хэмжээ — яг тоогоор

Нэг **12 суудал, 5 шөнө** ажилласан тоглолт:

| Хэсэг | Мөр | Нийт |
|---|---|---|
| Тохиргоо + тараалт | 18 | 2.2 КБ |
| Шөнө × 5 (үе шат + 12 `NIGHT_ACTION` + `NIGHT_RESOLVED` + `WHISPER`) | 75 | 8.3 КБ |
| Өдөр × 5 (үе шат + ~3 `PIN` + ~2 гар + хасалт + нөөц) | 45 | 5.6 КБ |
| Хаалт | 7 | 0.8 КБ |
| **`events` дүн (~115 Б/мөр)** | **~145** | **~17 КБ** |
| `events`-ийн хоёр индекс (290 бичлэг × ~20 Б) | | 5.8 КБ |
| `games` 1 мөр (`config_json` ~420 Б) + `game_seats` 12 + `game_ledger` 1 | 14 | 1.6 КБ |
| **4 КБ хуудсын тоймлолттой** | | **≈ 30 КБ** |

**Төлөвлөлтийн тоо: тоглолт тутам 30 КБ.** 20 суудал, 8 шөнийн хамгийн том тоглолт ≈ **58 КБ**. Долоо хоногт хоёр тоглодог анги хичээлийн жилд ~70 тоглолт = **~2.1 МБ**. Аудио багц нь 40–60 МБ — өөрөөр хэлбэл **бүртгэл бол хадгалалтын асуудал биш**.

## 7. Хураах (pruning)

Тиймээс хураалт нь дискний биш, **уншигдах чанарын** шийдвэр: анги гуравдугаар сард 200 хуудастай дэвтэр гүйлгэхгүй.

| Дүрэм | Тоо |
|---|---|
| Бүтэн бүртгэлтэй хадгалагдах | **сүүлийн 50 тоглолт** (≈1.5 МБ ≈ **хагас хичээлийн жил**) |
| 51-ээс хойш | `events` устгагдана, `game_ledger` **үлдэнэ**, `events_pruned=1` |
| `game_ledger`-ийн тааз | **1000 мөр** (≈300 КБ); давбал хамгийн хуучнаас устгана |
| Сангийн хатуу тааз | **8 МБ**; давбал 50 → **25** болж яаралтай хурааж `incremental_vacuum(64)` |
| Хэзээ ч хураагдахгүй | `rosters`, `roster_members`, `titles`, `settings` |
| Хураалт хэзээ | Хүйтэн эхлэхэд **ба** `GAME_ENDED`-ийн дараа. **Тоглолтын дунд хэзээ ч биш.** |
| `state='in_progress'` | **Хэзээ ч хүрэхгүй** — I5 тест шалгана |

```sql
DELETE FROM events WHERE game_id IN (
  SELECT id FROM games WHERE state <> 'in_progress' AND events_pruned = 0
  ORDER BY started_at DESC LIMIT -1 OFFSET 50);
-- дараа: UPDATE games SET events_pruned=1 ...; PRAGMA incremental_vacuum(64);
```

Хумигдсан хуудсыг нээвэл: **«Хуудас хураагдсан — хураангуй л үлдсэн.»** 📌-ийн мөчүүд алга болно. Тиймээс экспорт (§9) бол бүрэн бүртгэлийг үүрд барих цорын ганц зам, бөгөөд экспортын дэлгэц үүнийг нэг өгүүлбэрээр хэлнэ.

## 8. Схемын хувилбар ба миграц

**`PRAGMA user_version` бол цорын ганц үнэн.** v1 нээлт = **`user_version = 1`**.

```dart
const int kSchema = 1;
final v = await _userVersion();
if (v == 0)           { await _runDdl('ddl_v1.sql'); await _setUserVersion(kSchema); }
else if (v < kSchema) { await _migrate(from: v); }
else if (v > kSchema) { throw DbTooNewError(); }   // <-- хамгийн чухал салаа
```

| Дүрэм | Юу гэсэн үг |
|---|---|
| **Зөвхөн урагш** | `user_version > kSchema` (хуучин APK буулгасан) бол өгөгдөлд **хүрэхгүй**: «Апп хуучирсан. Шинэчилнэ үү.» → зөвхөн-унших. Хагас миграцлагдсан файл бол алдагдсан дэвтэр. |
| Нэг транзакц | Унавал бүхэлдээ ухарна. |
| Өмнө нь `khot.db.bak` | Амжилттай бол шууд устгагдана; амжилтгүй бол сэргээгээд зөвхөн-унших. |
| Зөвхөн `ADD COLUMN … DEFAULT` | 3.9-д `DROP`/`RENAME COLUMN` байхгүй. Хэрэггүй багана — зүгээр л уншихаа болино. |
| `payload_json` **миграцлагдахгүй** | Шинэ утга = шинэ `type`. Энэ бол «зөвхөн нэмэгддэг»-ийн жинхэнэ гэрээ. |
| Дэлгэц | 2 сек-ээс урт бол «Дэвтрээ шинэчилж байна…», өөр текст байхгүй. |

## 9. Экспорт ба «Миний өгөгдлийг устга»

Тохиргоо → **«Дэвтэр ба өгөгдөл»** дотор дөрвөн мөр, өөр юу ч биш.

| Мөр | Хэрхэн |
|---|---|
| **«Дэвтрээ файл болгож хадгал»** → `khot-devter-2027-02-14.json` | `flutter_file_dialog`-ийн `ACTION_CREATE_DOCUMENT`. **Storage зөвшөөрөл шаардахгүй** — хэрэглэгч хавтас сонгоно. |
| **«Уншиж болох текстээр хадгал»** → `.txt` | «Өдөр 2 · 1:14 · 5-р тоглогч ярьж байв» хэлбэрээр. JSON-ыг хэн ч уншихгүй. |
| **«Нэг тоглолтыг устгах»** | Дэвтрийн хуудсан дээрээс: `events` + `game_ledger` + `games` мөр. |
| **«Бүх өгөгдлийг устгах»** | §9.1 |

JSON: `{"app":"khot_untlaa","export_v":1,"schema":1,"exported_at":…,"rosters":[…],"games":[{…,"config":{…},"seats":[…],"events":[…]}],"titles":[…]}`. 70 тоглолт ≈ **1.9 МБ**. **`in_progress` тоглолт экспортлогдохгүй** — явж байгаа тоглолтын дүрүүдийг файл болгох нь хууран мэхлэлтийн хамгийн хямд зам. Товч бүдэг болж: «Тоглолт дуусахад хадгалж болно.»

### 9.1 «Бүх өгөгдлийг устгах»

Хоёр товшилт; хоёр дахь товч **3 секунд бүдэг** байж дараа нь дарагдана (бичиж батлах зүйл байхгүй — 13 настай хүүхэд тэрийг хэрүүл болгоно). Бичвэр яг ингэж:

> **«Ангийн дэвтэр, суудлын жагсаалт, бүх тоглолт, бүх цол — бүгд устана. Буцаах боломжгүй.»**

Хэрэгжилт: сангаа **хаах** → `khot.db`, `-wal`, `-shm` **гурвууланг файлын системээс устгах** → хоосон сан дахин үүсгэх. **`DELETE FROM` хэзээ ч биш** — тэр нь мөрүүдийг freelist хуудсанд байтаараа үлдээдэг. Аудио багц устахгүй (asset, хэрэглэгчийн өгөгдөл биш).

**Данс устгах товч байхгүй, учир нь данс байхгүй.** Apple 5.1.1(v) ба Play-ийн шаардлага «supports account creation» дээр хамаарна; бид үүсгэхгүй. Гэсэн ч устгах товчийг нийлүүлнэ — шаардлага биш, зөв учраас.

## 10. Нэг ч байт гарахгүй

`AndroidManifest.xml`-д **`INTERNET` зөвшөөрөл огт байхгүй**. Дээр нь `android:allowBackup="false"` ба бүгдийг deny хийсэн `dataExtractionRules`.

**`allowBackup="false"` бол зориудын, өртөгтэйгээ хамт.** Android-ийн авто-нөөцлөлт `khot.db`-г хэрэглэгчийн Google Drive-д хуулна. Тэр бидний цуглуулалт биш — гэхдээ «нэг ч байт гарахгүй» гэдэг өгүүлбэрийг **үгчилсэн үнэн** байлгах нь 4-р баганын гол зүйл. Өртөг: утас сольсон хүүхэд дэвтрээ алдана; хариулт нь §9-ийн экспорт.

**CI-ийн 3 шалгуур, build унагана:** (1) нэгтгэсэн манифестад `android.permission.INTERNET`; (2) `pubspec.lock`-д `http`, `dio`, `web_socket_channel`, `firebase_*`, `posthog*`, `flutter_tts`; (3) Dart кодод `HttpClient`, `Socket.connect`, `NetworkInterface`.

**Play Data safety (v1):** цуглуулдаг/хуваалцдаг уу — **Үгүй**. Гүйцэтгэл/эвдрэлийн бүртгэл — **Үгүй**. Төхөөрөмжийн танигч, `AD_ID` — **Үгүй, ямар ч build дээр**. Устгах хүсэлтийн зам — шаардлагагүй, гэхдээ апп дотор товч байна. Эрхийг Google өөрөө өгсөн: *«User data … only processed locally on the user's device and not sent off device does not need to be disclosed»* (17 §0.5).

**v1-д Crashlytics ч байхгүй.** Оронд нь `FlutterError.onError` + `runZonedGuarded` нь сүүлийн эвдрэлийн 20 мөрийг `meta['last_crash_note']`-д бичиж, Тохиргоо → Тусламж дотор **«Сүүлчийн алдаа»** болж харагдана. Туршилтын ангид хүүхэд түүнийг чангаар уншиж чадна — тэр бол сүлжээгүй телеметр.

## 11. Тест болж хувирсан инвариантууд

| # | Инвариант |
|---|---|
| I1 | `fold(events) == (games, game_seats)` бүх тоглолтод |
| I2 | `seq` нь 1-ээс тасралтгүй, цоорхойгүй |
| I3 | `finished` тоглолтод шинэ үйл явдал бичигдэхгүй; I4: нэг шөнөд нэг суудал `NIGHT_ACTION`-ыг хоёр удаа бичихгүй |
| I5 | Хураалт `in_progress` тоглолтод хүрэхгүй (500 санамсаргүй сан дээр) |
| I6 | `finished` бүр `game_ledger` мөртэй |
| **I7** | **`kill -9` fuzz:** бүтэн тоглолтыг **200 санамсаргүй `await` цэгт** тасалж, сэргээгээд төлөв нь тасалтын өмнөхтэй **± нэг үйлдлээр** таарч байгааг шалгана |

I1–I6 бол SQL. **I7 бол энэ бүлгийн жинхэнэ тест** — батерей дуусахыг дуурайдаг цорын ганц зүйл.

---

## v1-д юу орох вэ

*1 хөгжүүлэлтийн өдөр = **5 төлөвлөсөн цаг**. Доорхийн ~18 цаг нь 00-vision §10-ийн «Ангийн дэвтэр» (≈8 ц) ба M3-ийн бэхжилтийн блокт аль хэдийн төсөвлөгдсөн; үлдсэн ~26 цаг бол «тоглолт хэзээ ч алдагдахгүй»-гийн шударга үнэ.*

| Ажил | v1 | v2 | v3 | Өдөр |
|---|---|---|---|---|
| Схем, `ddl_v1.sql`, `Db` класс, PRAGMA-ууд | ✅ | | | **1.0** |
| `events` + `commit()` + `no-paint-before-commit` | ✅ | | | **1.0** |
| Проекц ба `rebuildProjection` | ✅ | | | **0.75** |
| Сэргээлтийн дэлгэц + §4.1-ийн хүснэгт бүхэлдээ | ✅ | | | **1.0** |
| I7 `kill -9` fuzz (200 цэг) + I1–I6 | ✅ | | | **1.0** |
| Тохиргооны хормын хувилбар + `config_hash` | ✅ | | | **0.25** |
| `game_ledger` + дэвтрийн хуудас унших | ✅ | | | **0.5** |
| Хураалт (50 / 1000 / 8 МБ) + `incremental_vacuum` | ✅ | | | **0.5** |
| Экспорт: JSON + TXT, SAF-аар | ✅ | | | **0.75** |
| «Бүх өгөгдлийг устгах» + нэг тоглолт устгах | ✅ | | | **0.5** |
| Миграцийн суурь (`user_version`, `.bak`, `DbTooNewError`) | ✅ | | | **0.5** |
| `audio_packs`/`audio_clips` + чимээгүйн хугацааны тест | ✅ | | | **0.5** |
| CI-ийн 3 шалгуур + `allowBackup=false` + `last_crash_note` | ✅ | | | **0.5** |
| **v1 дүн** | | | | **8.75 ≈ 44 ц** |
| `titles` — дараалсан ялалт, бөхийн цол | | ✅ | | 0.75 |
| «Таалт» — хос хүний хүснэгт + цонхны функц | | ✅ | | 1.0 |
| `sqlite3_flutter_libs` (SQLite 3.46, +1.2 МБ APK) | | ✅ | | 0.5 |
| Олон `roster` + суудлын зураглал; аудио багц солих | | ✅ | | 1.25 |
| Синк-д бэлэн бүртгэл: `device_id` + Lamport, зөрчлийн бодлого | | | ✅ | 2.0 |
| Асинхрон онлайн тоглолтын хүснэгтүүд | | | ✅ | 3.0 |

**Хоцорвол хасагдах гурав, дарааллаар нь:** TXT экспорт (0.25), `last_crash_note` (0.25), I7-ийн цэг 200 → 50 (0.5). **Хэзээ ч хасагдахгүй:** `commit()`, сэргээлтийн дэлгэц, CI-ийн сүлжээний шалгуур.

## Нээлттэй асуулт

1. **`synchronous=FULL` хэр үнэтэй вэ?** Redmi 9A ба Huawei дээр M1-д хэмж. **< 25 мс** бол шийдвэр хүчинтэй. 25–60 мс бол `NORMAL` + үе шатны заагт `wal_checkpoint(TRUNCATE)` — алдагдал нэг үйлдлээс нэг үе шат болж өснө. **> 60 мс** бол шөнийн 6 секундын хэмнэл эвдэрнэ: `commit`-ыг товшилтын дараа биш, дараагийн суудал рүү шилжих анимацтай **зэрэгцүүлж** гүйцэтгэ.
2. **50 тоглолт хэтэрхий олон уу?** M2.5-ийн таван суултын дараа асуу: хэн нэг нь дэвтрээ **10 хуудаснаас** гүйлгэж хараа юу? Үгүй бол таазыг **20** болго, гүйлгэх дэлгэцийг хая — 0.5 өдөр хэмнэнэ.
3. **Экспортыг хэн нэг нь дарах уу?** Альфад **тэг** бол экспорт v2 руу шилжинэ (0.75 өдөр), TXT үүрд үхнэ.
4. **Сэргээлтийн дэлгэц хэдэн удаа гарав?** Таван суултад **нэгээс** олон бол унаж байгаа шалтгаан нь сэргээлтийн өнгөлгөөнөөс чухал — `last_crash_note`-ыг унш, алдааг зас.
5. **Дэвтэр нэр санах уу, суудлын дугаар л санах уу?** `display_name` нь `NULL` зөвшөөрдөг. Анги нэр бичихийг хүсвэл экспортын файл 12 хүүхдийн нэртэй болно — тэр үед экспортод **«Нэргүй хадгалах»** сонголт нэмнэ (+0.25 өдөр).
6. **`BEST_MOVE_SPOKEN`-д зөвхөн тоо бичих нь хүлээн зөвшөөрөгдөх үү?** Хэн нэг нь «би юу гэж хэлсэн бэ?» гэж асуувал v2-т дугааруудыг бичиж, **оноолохгүйгээр** дэвтэрт харуулна. Хэн ч асуухгүй бол одоогийн шийдвэр зөв.
7. **`allowBackup=false` хэнийг гомдоох вэ?** Ангиасаа асуу: сүүлийн жилд утсаа хэд хүн сольсон бэ? Тав дээр дөрөв бол v2-т «Дэвтрээ шинэ утас руу зөө» гэсэн замыг төсөвлө — **сүлжээгээр биш, файлаар.**
