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
