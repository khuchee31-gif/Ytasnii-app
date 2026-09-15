# GDD-12 — Өгөгдлийн модель, хадгалалт ба сэргээлт

> **Шийдвэрийн хураангуй**
> - **Нэг файл, нэг хөдөлгүүр: `sqflite` дээрх гараар бичсэн SQL.** `drift` байхгүй, `build_runner` байхгүй, `shared_preferences` байхгүй. Тохиргоо, дэвтэр, бүртгэл — бүгд `khot.db` дотор. Учир нь хүснэгт 11, миграц 30 мөр, харин гацсан codegen нэг удаадаа ~2 цаг авдаг — энэ бол долоо хоногийн төсвийн 20%.
> - **Үнэн бол `events` хүснэгт, бусад бүх зүйл кэш.** `games` ба `game_seats` нь `fold(events)`-оос хэзээ ч, хаанаас ч дахин бүтээгдэнэ. Бүртгэл нь **зөвхөн нэмэгддэг** — `UPDATE`, `DELETE` хоёр код review-д хориотой (цэвэрлэгээнээс бусад).
> - **`no-paint-before-commit`.** Атом үйлдэл бүр нэг транзакцаар бичигдэж, `await` нь эргэж ирсний **дараа** л дэлгэц зурагдана, аудио тоглоно. `PRAGMA synchronous=FULL` + WAL — батерей дуусахад хамгийн сүүлийн үйлдэл л алдагдана, тойрог биш.
> - **Сэргээлтийн үнэ: 5 секунд, нэг үйлдэл.** Сэргээлт хэзээ ч хөзрийг дахин нээхгүй, шөнийн үйлдлээ хийчихсэн суудлыг дахин асуухгүй. Мэдээлэл алдагдуулахаас алдагдсан 6 секунд нь зуу дахин хямд.
> - **Тоглолт бүрт тохиргоо хөлдөнө.** `games.config_json` + 12 тэмдэгтийн `config_hash`. Тоглолтын дунд Тохиргоо нээгдвэл ч дүрэм өөрчлөгдөхгүй.
> - **Нэг тоглолт ≈ 30 КБ. Бүтэн бүртгэлтэйгээр сүүлийн 50 тоглолт хадгалагдана** (≈1.5 МБ), дараа нь дэвтрийн нэг мөр болж хумигдана. Хатуу тааз 8 МБ.
> - **Нэг ч байт төхөөрөмжөөс гарахгүй, `allowBackup="false"` ч гэсэн.** Google Drive-ийн авто-нөөцлөлт хүртэл унтраасан — ингэснээр Play-ийн Data safety маягтын **«Ямар ч өгөгдөл цуглуулдаггүй»** нь маркетинг биш, үгчилсэн үнэн болно.
> - **SQL-ийн диалектын шал = SQLite 3.9** (`minSdk 24`, Android 7.0). `UPSERT` байхгүй, `json_extract` байхгүй, цонхны функц байхгүй, `DROP COLUMN` байхгүй. JSON-ыг зөвхөн Dart тал дээр уншина.

*Хамаарал: GDD-00 §3 (4-р багана «Сүлжээгүй, зөвшөөрөлгүй»), §8 (Ангийн дэвтэр), §11 (1 ба 5-р татгалзал); судалгааны 06 §6–7, 08 §2, 10 §5 (P2 протокол), 13 §1, 14 §3, 17 §0.*

---

## 0. Нэг зөрчлийг ил тавья

00-vision §8 хоёр зүйлийг зэрэг хэлдэг: «хүн тус бүрийн ялалтын хувь **байхгүй**», бас «ганц хадгалагдах тоо бол мафигаар тоглоход хэдэн санал давж гарсан». Хоёр дахь нь хэрэв **хүнд** хавсрагдвал энэ нь яг тэр хориглосон статистик болно — «Тэмүүлэн: 4/7». Тиймээс би үзэл баримтлалыг ингэж хэрэгжүүлнэ: **тэр тоо `game_ledger`-ийн мөрөнд, тоглолтод хамаарч бичигдэнэ, хүнд хэзээ ч хамаарахгүй.** Схемд `roster_member_id` → ялалт/ялагдлын нийлбэрийг гаргах индекс, харагдац, query огт байхгүй. Хүсвэл SQL бичээд гаргаж болно — гэхдээ тэр SQL аппын дотор байхгүй, бөгөөд код review-ийн дүрэм нь: **`roster_members`-ийг `games`-тэй нэгтгэсэн (`JOIN`) нийлбэр query PR-д орж болохгүй.** Үзэл баримтлалын хүсэл (анги өөрөө хэлж байх) хадгалалтын шийдвэрээр хангагдана.

---

## 1. Хөдөлгүүр, файл, PRAGMA

| Шийдвэр | Юу вэ | Яагаад |
|---|---|---|
| Сан | **`sqflite`** (`sqflite: ^2`) | Flutter-ийн хамгийн хуучин, хамгийн уйтгартай, хамгийн сайн баримтжсан SQLite холбогч. Codegen байхгүй. |
| DDL | Repo-д **`assets/db/ddl_v1.sql`** — доорх текст яг өөрөө | Баримт бичиг нь схем өөрөө байна. Хоёр эх сурвалж байхгүй. |
| Файл | `getDatabasesPath()/khot.db` (+ `-wal`, `-shm`) | Апп устгагдвал OS өөрөө устгана. |
| Диалект | **SQLite 3.9 шал** | `minSdk 24` = Android 7.0 = SQLite 3.9.2. `UPSERT` (3.24), цонхны функц (3.25), `RENAME/DROP COLUMN` (3.25/3.35), `STRICT` (3.37), JSON1 — **аль нь ч байхгүй гэж үз.** `INSERT OR REPLACE` хэрэглэ, JSON-ыг Dart-д унш. |
| Тохиргоо | `settings` хүснэгт, **`shared_preferences` биш** | Нэг л store: нэг экспорт, нэг миграц, нэг устгах товч. |

```dart
// DbOpener.open() — дарааллыг бүү сольж бич
await db.execute('PRAGMA auto_vacuum = INCREMENTAL');  // ЗӨВХӨН хоосон файл дээр ажиллана
await db.execute('PRAGMA journal_mode = WAL');
await db.execute('PRAGMA synchronous = FULL');         // §4-ийн батерейн шийдвэр
await db.execute('PRAGMA foreign_keys = ON');
await db.execute('PRAGMA busy_timeout = 3000');
```

`auto_vacuum` нь **хүснэгт үүсэхээс өмнө** тавигдах ёстой, эс бөгөөс `VACUUM` бүтнээр хийхээс өөр арга үлдэхгүй. `synchronous = FULL` нь commit тутамд WAL-ыг fsync хийнэ — бидний бичилт нь хөдөлгөөнт дүрсний frame дотор биш тул төлбөр нь тэвчихийн. **Зорилт: Redmi 9A дээр commit тутам < 25 мс.** Хэрэв дээш давбал `NORMAL` руу буугаад үе шатны заагт `PRAGMA wal_checkpoint(TRUNCATE)` дуудна (§13-ийн 1-р асуулт).

---

## 2. Схем — жинхэнэ DDL

```sql
-- 1) Мета: зөвхөн аппын түвшний нэг мөрүүд. Схемын хувилбар нь PRAGMA user_version.
CREATE TABLE meta (
  k            TEXT PRIMARY KEY,
  v            TEXT NOT NULL
);  -- 'db_created_at', 'app_build_at_create', 'last_prune_at', 'last_crash_note'

-- 2) Ангийн суудлын жагсаалт. Хэд ч байж болно: 10А, гэр бүл, Наадмын айл.
CREATE TABLE rosters (
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  title        TEXT    NOT NULL,              -- «10А», «Манай айл»
  seat_count   INTEGER NOT NULL,
  created_at   INTEGER NOT NULL,              -- ms, wall clock
  last_used_at INTEGER NOT NULL
);

CREATE TABLE roster_members (
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  roster_id    INTEGER NOT NULL REFERENCES rosters(id) ON DELETE CASCADE,
  seat_no      INTEGER NOT NULL,              -- 1..20
  display_name TEXT,                          -- NULL зөвшөөрөгдөнө: суудлын дугаар хангалттай
  UNIQUE (roster_id, seat_no)
);

-- 3) Тоглолт. config_json нь хөлдөөсөн дүрэм (§5).
CREATE TABLE games (
  id             INTEGER PRIMARY KEY AUTOINCREMENT,
  roster_id      INTEGER REFERENCES rosters(id) ON DELETE SET NULL,
  state          TEXT    NOT NULL,            -- 'in_progress' | 'finished' | 'abandoned'
  host_mode      TEXT    NOT NULL,            -- 'APP' | 'HUMAN'   (Хөтлөгчтэй горим)
  seat_count     INTEGER NOT NULL,
  mafia_count    INTEGER NOT NULL,
  b_initial      INTEGER NOT NULL,            -- b = floor(N/2) - M - 1
  config_json    TEXT    NOT NULL,
  config_hash    TEXT    NOT NULL,            -- sha256(canonical)[0..12]
  fairness_code  TEXT    NOT NULL,            -- 6 hex, чангаар уншигдсан
  seed_commit    TEXT    NOT NULL,            -- SHA256(seed0)
  seed_hex       TEXT,                        -- тоглолт дуусахад л бичигдэнэ
  started_at     INTEGER NOT NULL,
  updated_at     INTEGER NOT NULL,
  ended_at       INTEGER,
  winner         TEXT,                        -- 'TOWN' | 'MAFIA' | NULL
  nights         INTEGER NOT NULL DEFAULT 0,
  resume_seq     INTEGER NOT NULL DEFAULT 0,  -- §4: сэргээх цэг
  events_pruned  INTEGER NOT NULL DEFAULT 0   -- 1 бол бүртгэл хумигдсан
);
CREATE INDEX idx_games_state ON games(state, updated_at DESC);

-- 4) Суудал × тоглолт — fold(events)-оос дахин бүтээгддэг ПРОЕКЦ.
CREATE TABLE game_seats (
  game_id        INTEGER NOT NULL REFERENCES games(id) ON DELETE CASCADE,
  seat_no        INTEGER NOT NULL,
  member_id      INTEGER REFERENCES roster_members(id) ON DELETE SET NULL,
  role_code      TEXT    NOT NULL,            -- 'KILLER'|'BOSS'|'DOCTOR'|'DETECTIVE'|'CITIZEN'
  card_seen_at   INTEGER,                     -- NULL = хөзрөө хараагүй
  card_reseen    INTEGER NOT NULL DEFAULT 0,
  out_at_phase   TEXT,                        -- 'N3' | 'D2' | NULL
  out_cause      TEXT,                        -- 'NIGHT' | 'VOTE' | NULL
  PRIMARY KEY (game_id, seat_no)
);
```

```sql
-- 5) БҮРТГЭЛ. Зөвхөн нэмэгддэг. UPDATE/DELETE нь цэвэрлэгээнээс өөр газар хориотой.
CREATE TABLE events (
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  game_id      INTEGER NOT NULL REFERENCES games(id) ON DELETE CASCADE,
  seq          INTEGER NOT NULL,              -- 1-ээс тасралтгүй, тоглолт тус бүрт
  at_ms        INTEGER NOT NULL,              -- ханын цаг. ЗӨВХӨН харуулахад.
  mono_ms      INTEGER NOT NULL,              -- Stopwatch. ЗӨВХӨН үргэлжлэх хугацаанд.
  phase_kind   TEXT    NOT NULL,              -- 'SETUP'|'NIGHT0'|'NIGHT'|'DAY'|'VOTE'|'END'
  phase_no     INTEGER NOT NULL,
  type         TEXT    NOT NULL,
  actor_seat   INTEGER,
  target_seat  INTEGER,
  payload_json TEXT    NOT NULL DEFAULT '{}',
  UNIQUE (game_id, seq)
);
CREATE INDEX idx_events_game ON events(game_id, seq);
CREATE INDEX idx_events_type ON events(game_id, type);

-- 6) Дэвтрийн хуудас — нэг тоглолт, нэг мөр. Бүртгэл хумигдсан ч ЭНЭ ҮЛДЭНЭ.
CREATE TABLE game_ledger (
  game_id       INTEGER PRIMARY KEY REFERENCES games(id) ON DELETE CASCADE,
  played_on     TEXT    NOT NULL,             -- 'YYYY-MM-DD' локал
  seat_count    INTEGER NOT NULL,
  mafia_seats   TEXT    NOT NULL,             -- '2,5,9'
  survivor_seats TEXT   NOT NULL,
  nights        INTEGER NOT NULL,
  b_initial     INTEGER NOT NULL,
  b_spent       INTEGER NOT NULL,             -- алдааны нөөцөөс хэд зарцуулсан
  winner        TEXT    NOT NULL,
  pin_count     INTEGER NOT NULL,
  first_out_seat INTEGER,                     -- «Бүжигт хүлэг» хэн авсан
  duration_ms   INTEGER NOT NULL
);

-- 7) Цол (v2). Нэмэгддэг, ХУМИГДАХГҮЙ, буцааж авагдахгүй.
CREATE TABLE titles (
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  member_id    INTEGER NOT NULL REFERENCES roster_members(id) ON DELETE CASCADE,
  code         TEXT    NOT NULL,              -- 'NACHIN'|'HARTSAGA'|'ZAAN'|'GARID'|'ARSLAN'|'AVRAGA'
  awarded_at   INTEGER NOT NULL,
  game_id      INTEGER REFERENCES games(id) ON DELETE SET NULL,
  UNIQUE (member_id, code)
);

-- 8) Тохиргоо. shared_preferences-ийн орлуулагч.
CREATE TABLE settings (
  k            TEXT PRIMARY KEY,
  v            TEXT NOT NULL,
  updated_at   INTEGER NOT NULL
);

-- 9) Аудио багц ба клип. «Чимээгүйн хүснэгт» өгөгдөл болж амьдарна.
CREATE TABLE audio_packs (
  id           TEXT PRIMARY KEY,              -- 'mn_human_v1' | 'mn_bataa_v1'
  title        TEXT    NOT NULL,              -- «Монгол хоолой (бичлэг)»
  voice_kind   TEXT    NOT NULL,              -- 'HUMAN' | 'TTS_PRERENDERED'
  clip_count   INTEGER NOT NULL,
  bytes        INTEGER NOT NULL,
  pack_version INTEGER NOT NULL,
  installed_at INTEGER NOT NULL,
  is_active    INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE audio_clips (
  pack_id      TEXT    NOT NULL REFERENCES audio_packs(id) ON DELETE CASCADE,
  clip_id      TEXT    NOT NULL,              -- 'NIGHT_KILL_A', 'SEAT_07', 'ROLE_DOCTOR'
  asset_path   TEXT    NOT NULL,
  duration_ms  INTEGER NOT NULL,
  gap_after_ms INTEGER NOT NULL,              -- 00-vision §9-ийн хүснэгт, өгөгдөл болсон
  PRIMARY KEY (pack_id, clip_id)
);
```

`audio_clips.gap_after_ms` бол дизайны шийдвэрийн кодчилол: `NIGHT_KILL_A` → **2500**, дүрийн хос хооронд **1200**, `NIGHT_START` → **4000**, «Хөзрөө нээе»-гийн суудал хооронд **1200**. Тест нь эдгээр тоог хатуу шалгана — тиймээс яарсан хөгжүүлэгч завсрыг «сайжруулж» чадахгүй.

---

## 3. Үйл явдлын төрлүүд

`type` бол үүрд хөлдсөн текст. **Хуучин төрөл хэзээ ч утгаа сольдоггүй; шинэ утга = шинэ нэр.** Уншигч танихгүй төрлийг **алгасах ба тоолох** ёстой (`unknown_event_count` нь тусламжийн дэлгэцэд гарна).

| `type` | Хэзээ | `payload_json` |
|---|---|---|
| `GAME_CREATED` | Тохиргоо батлагдмагц | `{}` (дүрэм нь `games.config_json`-д) |
| `SEED_COMMITTED` | Тараахын өмнө | `{"code":"a3f19c","commit":"<64hex>"}` |
| `ENTROPY_ADDED` | Утас сэгсрэгдэхэд | `{"src":"shake","seat":9,"ms":2000}` |
| `DEAL_COMPLETED` | Холилт бодогдмогц | `{"roles_hash":"<12hex>"}` — **дүр өөрөө бүртгэлд бичигдэхгүй** |
| `CARD_SEEN` | Суудал хөзрөө тавихад | `{"held_ms":2480}` |
| `CARD_RESEEN` | Дахин нээхэд | `{"n":2}` |
| `PHASE_ENTERED` | Үе шат солигдоход | `{"kind":"NIGHT","no":3}` |
| `INTRO_NIGHT_DONE` | 60 сек дуусахад | `{"actual_ms":60000}` |
| `NIGHT_ACTION` | Суудал товшилт хийхэд | `{"kind":"KILL"\|"HEAL"\|"CHECK"\|"WHISPER"}` + `actor_seat`, `target_seat` |
| `NIGHT_RESOLVED` | Үүрээр | `{"victim":7,"healed":null,"check":"FOUND"}` |
| `WHISPER_PUBLISHED` | Үүрээр | `{"seats":[3,10],"agree":[4,3]}` |
| `BEST_MOVE_SPOKEN` | Хохирогч 3 дугаар нэрлэхэд | `{"n":3}` — **дугаарууд бүртгэгдэхгүй** (§0-ийн логик) |
| `PIN` | 📌 дарагдахад | `{"elapsed_ms":74000,"speaking_seat":5}` |
| `HANDS_COUNTED` | Гар тоологдоход | `{"hands":7}` + `target_seat` |
| `EXILED` | Хотоос хөөгдөхөд | `{}` + `target_seat` |
| `SEAT_ELIMINATED` | Аль ч хасалтад | `{"cause":"NIGHT"\|"VOTE"}` + `target_seat` |
| `BUDGET_SPENT` | Иргэн хасагдахад | `{"b_left":1}` |
| `PAUSED` / `RESUMED` | Дуудлага, хонх, апп унтрахад | `{"reason":"BACKGROUND"\|"CALL"\|"MANUAL"}` |
| `RESUMED_AFTER_KILL` | Сэргээлтээр эхлэхэд | `{"gap_ms":184000,"lost_actions":1}` |
| `GAME_ENDED` | Ялалтын нөхцөл хангагдахад | `{"winner":"TOWN","nights":5}` |
| `ABANDONED` | «Хаях» дарагдахад | `{"at_phase":"D3"}` |
| `AUDIO_FALLBACK` | Клип тоглоогүй | `{"clip":"NIGHT_KILL_B","reason":"PLAYER_DEAD"}` |

**Яагаад `DEAL_COMPLETED` дүрүүдийг бичихгүй вэ.** `game_seats.role_code` нь дүрийг аль хэдийн хадгалдаг, тэр нь `FLAG_SECURE` ба «Хөзрөө нээе»-д хэрэгтэй. Бүртгэлд **хоёр дахь** хуулбар байх нь экспортын файлд дүрүүдийг эрт зөөнө — хэн нэг нь тоглолтын дунд дэвтрээ экспортлоод тараачихвал нууц урсана. Нэг л газар, нэг л уншигч.

---

## 4. «Атом үйлдэл бүрийн дараа хадгал» — яг ямар дүрэм вэ

**Атом үйлдэл** гэдэг нь: *ширээ түүнийг маргалдахгүйгээр дахин хийж чадахгүй ямар ч зүйл.* Хөзрөө харах, шөнийн товшилт, гар тоолох, 📌 дарах, үе шат солих — бүгд атом. Хөдөлгөөнт дүрсийн frame, дууны эхлэл, товчны hover — атом биш.

```dart
// Repo дотор ЭНЭ ганц функцээр бүх бичилт явна. Өөр замаар events-д бичих PR татгалзана.
Future<int> commit(GameEvent e) async {
  final seq = await _db.transaction<int>((t) async {
    final s = (await t.rawQuery(
      'SELECT COALESCE(MAX(seq),0)+1 AS s FROM events WHERE game_id=?', [e.gameId]
    )).first['s'] as int;
    await t.insert('events', e.toRow(s));
    await t.rawUpdate(
      'UPDATE games SET resume_seq=?, updated_at=? WHERE id=?', [s, e.atMs, e.gameId]);
    await _applyProjection(t, e);          // game_seats / games.nights / winner
    return s;
  });
  return seq;                              // <-- дэлгэц ба аудио ЗӨВХӨН үүний дараа
}
```

**Код review-ийн дүрэм: `no-paint-before-commit`.** Үе шатыг урагшлуулдаг `setState`, `Navigator.push`, `player.play()` — гурвуулаа `await commit(...)`-ийн **доор** байх ёстой. Тест нь `commit`-ыг 500 мс саатуулж, дэлгэц хөдөлгөөнгүй хэвээр байгааг шалгана.

**Хэлэлцүүлгийн цаг** нь үйл явдал биш — тэр урсаж байдаг. Түүнийг **5 секунд тутам** `settings['live_clock_ms']`-д бичнэ. Хамгийн муу алдагдал: **5 секунд**. Цагийг ханын цагаас **дахин бодохгүй** — батерей гурван цаг унтарсан байж болно; сэргэхэд цаг нь хадгалагдсан тоогоор үргэлжилнэ.

### 4.1 Сэргээлтийн гэрээ

Хүйтэн эхлэхэд: `SELECT * FROM games WHERE state='in_progress' ORDER BY updated_at DESC LIMIT 1`. Байвал нүүр хуудсын оронд нэг дэлгэц, хоёр товч:

> **«Дуусаагүй тоглоом байна.»**
> «10А · 12 суудал · 3-р шөнө · 14 минутын өмнө»
> **«Үргэлжлүүлэх»** · «Хаях»

«Хаях» нь `ABANDONED` бичээд `state='abandoned'` болгоно — **өгөгдлийг устгахгүй**, дэвтэрт «дуусаагүй» хуудас болж үлдэнэ (анги хэдэн тоглолт үхсэнээ өөрөө харна).

| Хаана унасан | Сэргэх цэг | Юуг ХЭЗЭЭ Ч дахин хийхгүй |
|---|---|---|
| Тохиргооны дунд (`GAME_CREATED`-аас өмнө) | Тоглолт үүсээгүй. Тохиргооны дэлгэц, суудал хадгалагдсан. | — |
| Тараалтын дунд | `card_seen_at IS NULL` байгаа **хамгийн бага** суудал | Холилтыг дахин бодохгүй. `seed` аль хэдийн хөлдсөн. |
| Танилцах шөнийн 60 сек дотор | Шөнө 0-ийн **эхнээс**, бүтэн 60 секунд | — |
| Шөнийн эргэлтийн 12-оос 7 дахь суудал дээр | №7-ийн «утсаа өргө» дэлгэц | 1–6-ийн товшилтыг дахин асуухгүй, харуулахгүй, зөвлөхгүй |
| Үүрийн зарлалын дунд (`NIGHT_RESOLVED` бичигдсэн) | `NIGHT_KILL_A`-аас **бүтнээр дахин** | Шөнийг дахин бодохгүй — хохирогч аль хэдийн бичигдсэн |
| Хэлэлцүүлгийн дунд | Хадгалагдсан `live_clock_ms`-аас | Цагийг тэглэхгүй, ханын цагаар нэмэхгүй |
| Гар тоолохын дунд | Тэр нэр дэвшигчийн дугуйнаас | Өмнөх нэр дэвшигчдийн тоог дахин асуухгүй |
| «Хөзрөө нээе»-гийн дунд | Нээгээгүй **хамгийн бага** суудлаас | Нээгдсэн суудлыг дахин нээхгүй |

**Хамгийн чухал дүрэм:** сэргээлт нь мэдээллийг **хэзээ ч** дахин харуулахгүй. Хэрэв №7 өөрийн шөнийн товшилтоо хийчихсэн бол апп түүнийг «дахин батлаач» гэж асуухгүй — тэр асуулт өөрөө №7 юу хийснийг хажуугийн хүнд шивнэнэ. Алдагдсан **6 секунд** нь алдагдсан нууцаас зуу дахин хямд.

**Дахин бүтээлт.** `rebuildProjection(gameId)` нь `game_seats` ба `games`-ийн бүх дериватив талбарыг устгаж, `events`-ийг `seq`-ээр дараалуулан дахин нугална. Проекц эвдэрсэн байж магадгүй ямар ч сэжиг (апп хувилбар сольсон, миграц хийгдсэн, `unknown_event_count > 0`) — дахин нугалаад л болоо. **Дараалал нь `seq`-ээр, `at_ms`-ээр хэзээ ч биш** — ханын цаг цаг хэлтэс сольж, хоцорч, ухарч чадна.

---

## 5. Тоглолтод хөлдөөх тохиргооны хормын хувилбар

`GAME_CREATED`-ийн үед бүрэн хүчинтэй дүрмийн багц JSON болж `games.config_json`-д бичигдэнэ. **Тоглолтын явцад хөдөлгүүр `settings`-ийг хэзээ ч уншихгүй.**

```json
{"cfg_v":3,"seats":12,"mafia":3,"boss":true,"doctor":1,"detective":1,"b":2,
 "night_first":true,"mafia_wins_at":"M>=T","doctor_self_heal":false,
 "reveal_on_elimination":false,"intro_night_ms":60000,"night_seat_ms":6000,
 "discussion_ms":480000,"whisper_min_agree":3,"best_move_ms":20000,
 "host_mode":"APP","theme":"ub_noir","audio_pack":"mn_human_v1","strings_v":7}
```

`config_hash = sha256(canonicalJson)[0..12]`, `games.config_hash`-д бичигдэнэ. Хоёр ажил хийнэ: дэвтэр нь «ижил дүрмээр тоглосон» хуудсуудыг нэг бүлэг болгож чадна, бөгөөд алдааны мэдээлэл 12 тэмдэгтээр дүрмийн багцыг бүрэн нэрлэнэ. Хэрэв хэн нэг нь тоглолтын дунд Тохиргоо нээвэл дэлгэц **«Дараагийн тоглолтод хүчинтэй»** гэж бичнэ — өөрчлөлт хадгалагдана, гэхдээ явж байгаа тоглолт мэдэхгүй.

`cfg_v` нь **тохиргооны** хувилбар, `user_version` нь **схемын** хувилбар. Хоёр нь бие даан өснө. Уншигч танихгүй `cfg_v`-тэй тоглолтыг зөвхөн дэвтрийн мөр болгож үзүүлнэ, дахин сэргээхийг оролдохгүй.

---

## 6. Хэмжээ — яг тоогоор

Нэг **12 суудал, 5 шөнө** ажилласан тоглолт:

| Хэсэг | Мөр | Мөр тутам | Нийт |
|---|---|---|---|
| Тохиргоо + тараалт (`GAME_CREATED`…`CARD_RESEEN`) | 18 | ~120 Б | 2.2 КБ |
| Шөнө (`PHASE_ENTERED` + 12 `NIGHT_ACTION` + `NIGHT_RESOLVED` + `WHISPER_PUBLISHED`) × 5 | 75 | ~110 Б | 8.3 КБ |
| Өдөр (үе шат + ~3 `PIN` + ~2 `HANDS_COUNTED` + хасалт + нөөц) × 5 | 45 | ~125 Б | 5.6 КБ |
| Хаалт (`GAME_ENDED`, `REVEAL`, `PAUSED/RESUMED`) | 7 | ~110 Б | 0.8 КБ |
| **`events` дүн** | **~145** | | **~17 КБ** |
| `events`-ийн хоёр индекс | 290 бичлэг | ~20 Б | 5.8 КБ |
| `games` 1 мөр (`config_json` ~420 Б) | 1 | ~640 Б | 0.6 КБ |
| `game_seats` 12 мөр | 12 | ~60 Б | 0.7 КБ |
| `game_ledger` 1 мөр | 1 | ~300 Б | 0.3 КБ |
| **Нийт, 4 КБ хуудсын тоймлолттой** | | | **≈ 30 КБ** |

**Төлөвлөлтийн тоо: тоглолт тутам 30 КБ.** 20 суудал, 8 шөнийн хамгийн том тоглолт ≈ **58 КБ**. Долоо хоногт хоёр тоглодог анги хичээлийн жилд ~70 тоглолт = **~2.1 МБ**. Аудио багц нь 40–60 МБ (M4a+M4b) — өөрөөр хэлбэл **бүртгэл бол хадгалалтын асуудал биш**.

## 7. Хураах (pruning) — байтын төлөө биш

Тиймээс хураах нь дискний шийдвэр биш, **уншигдах чанарын ба шударга байдлын** шийдвэр: анги гуравдугаар сард 200 хуудастай дэвтэр гүйлгэхгүй, бөгөөд бид «нэг ч байт гарахгүй» гэж хэлэхдээ тэр байтууд хязгааргүй хуримтлагдаж байх нь буруу.

| Дүрэм | Тоо |
|---|---|
| Бүтэн бүртгэлтэйгээр хадгалагдах тоглолт | **сүүлийн 50** (≈1.5 МБ ≈ **хагас хичээлийн жил**) |
| 51-ээс хойшхи тоглолт | `events` устгагдана, `game_ledger` мөр **үлдэнэ**, `games.events_pruned=1` |
| `game_ledger`-ийн хатуу тааз | **1000 мөр** (≈300 КБ). Давбал хамгийн хуучнаас устгана |
| Өгөгдлийн сангийн хатуу тааз | **8 МБ**. Давбал 50 → **25** тоглолт болж яаралтай хурааж, `incremental_vacuum(64)` дуудна |
| Хэзээ ч хураагдахгүй | `rosters`, `roster_members`, `titles`, `settings` |
| Хураалт хэзээ ажиллах | Апп хүйтэн эхлэхэд **ба** `GAME_ENDED`-ийн дараа. **Тоглолтын дунд хэзээ ч биш.** |
| `state='in_progress'` тоглолт | **Хэзээ ч хураагдахгүй** — тест шалгана |

```sql
DELETE FROM events WHERE game_id IN (
  SELECT id FROM games WHERE state <> 'in_progress' AND events_pruned = 0
  ORDER BY started_at DESC LIMIT -1 OFFSET 50);
-- дараа нь UPDATE games SET events_pruned=1 ..., PRAGMA incremental_vacuum(64);
```

Хумигдсан тоглолтын хуудсыг нээвэл: **«Хуудас хураагдсан — хураангуй л үлдсэн.»** 📌-ийн мөчүүд алга болно. Тиймээс экспорт (§9) бол тоглолтын бүрэн бүртгэлийг **үүрд** барих цорын ганц зам, бөгөөд экспортын дэлгэц үүнийг нэг өгүүлбэрээр хэлнэ.

## 8. Схемын хувилбар ба миграц

**`PRAGMA user_version` бол цорын ганц үнэн.** v1 нээлт = **`user_version = 1`**.

```dart
const int kSchema = 1;
final v = await _userVersion();
if (v == 0)        { await _runDdl('ddl_v1.sql'); await _setUserVersion(kSchema); }
else if (v < kSchema) { await _migrate(from: v); }
else if (v > kSchema) { throw DbTooNewError(); }   // <-- хамгийн чухал салаа
```

| Дүрэм | Юу гэсэн үг |
|---|---|
| **Зөвхөн урагш.** Буцах миграц бичихгүй. | Хэрэв `user_version > kSchema` (хэрэглэгч хуучин APK буулгасан) — **өгөгдөлд хүрэхгүй**, «Апп хуучирсан. Шинэчилнэ үү.» гэж гаргаад зөвхөн-унших болно. Хагас миграцлагдсан файл бол алдагдсан дэвтэр. |
| Миграц бүр **нэг транзакц** | Унавал бүхэлдээ ухарна. |
| Миграцын өмнө **файлын хуулбар** `khot.db.bak` | Амжилттай бол шууд устгагдана. Амжилтгүй бол сэргээгээд дээрх «зөвхөн-унших» төлөв. |
| Зөвхөн `ALTER TABLE … ADD COLUMN … DEFAULT` | SQLite 3.9 дээр `DROP`/`RENAME COLUMN` байхгүй. Багана хэрэггүй болбол **зүгээр л уншихаа болино**. |
| `payload_json` **хэзээ ч миграцлагдахгүй** | Шинэ утга = шинэ `type`. Хуучин мөр хуучин уншигчаараа уншигдана. Энэ бол «зөвхөн нэмэгддэг» гэдгийн жинхэнэ гэрээ. |
| Миграц дэлгэц | 2 секундээс урт бол «Дэвтрээ шинэчилж байна…» — үүнээс өөр текст байхгүй. |

---

## 9. Экспорт ба «Миний өгөгдлийг устга»

Тохиргоо → **«Дэвтэр ба өгөгдөл»** дотор дөрвөн мөр, өөр юу ч биш.

| Мөр | Юу болох | Хэрхэн |
|---|---|---|
| **«Дэвтрээ файл болгож хадгал»** | `khot-devter-2027-02-14.json` | `flutter_file_dialog`-ийн `ACTION_CREATE_DOCUMENT`. **Ямар ч storage зөвшөөрөл шаардахгүй** — хэрэглэгч өөрөө хавтас сонгоно. |
| **«Уншиж болох текстээр хадгал»** | `.txt` — «Өдөр 2 · 1:14 · 5-р тоглогч ярьж байв» хэлбэрээр | 16 настай хүүхэд нээгээд уншина, багш хэвлэнэ. JSON-ыг хэн ч уншихгүй. |
| **«Нэг тоглолтыг устгах»** | Тэр хуудас, түүний `events`, `game_ledger` | Дэвтрийн хуудсан дээрээс. |
| **«Бүх өгөгдлийг устгах»** | Бүгд. Буцаах боломжгүй. | §9.1 |

Экспортын JSON-ы хэлбэр: `{"app":"khot_untlaa","export_v":1,"schema":1,"exported_at":…,"rosters":[…],"games":[{…,"config":{…},"seats":[…],"events":[…]}],"titles":[…]}`. 70 тоглолт ≈ **1.9 МБ**. `state='in_progress'` тоглолт **экспортлогдохгүй** — явж байгаа тоглолтын дүрүүдийг файл болгож тараах нь хууран мэхлэлтийн хамгийн хямд зам. Экспортын товч тоглолтын дунд **бүдэг** болно: «Тоглолт дуусахад хадгалж болно.»

### 9.1 «Бүх өгөгдлийг устгах» — яг хэрхэн

Хоёр товшилт. Хоёр дахь товч **3 секунд бүдэг** байж, дараа нь л дарагдана (санамсаргүй дарахаас хамгаалах; бичиж батлах зүйл байхгүй — 13 настай хүүхдэд тэр нь хэрүүл л дагуулна). Бичвэр яг ингэж:

> **«Ангийн дэвтэр, суудлын жагсаалт, бүх тоглолт, бүх цол — бүгд устана. Буцаах боломжгүй.»**

Хэрэгжилт: сангаа **хаана** → `khot.db`, `khot.db-wal`, `khot.db-shm` **гурвууланг файлын системээс устгана** → хоосон сан дахин үүсгэнэ. **`DELETE FROM` хэзээ ч биш** — тэр нь мөрүүдийг freelist хуудсанд байтаараа үлдээдэг. Аудио багц устахгүй (тэр бол asset, хэрэглэгчийн өгөгдөл биш).

**Данс устгах товч байхгүй, учир нь данс байхгүй.** Apple 5.1.1(v) ба Play-ийн данс устгах шаардлага нь «supports account creation» дээр л хамаарна — бид үүсгэдэггүй. Гэсэн хэдий ч устгах товчийг нийлүүлнэ: шаардлага биш, зөв учраас.

## 10. Нэг ч байт гарахгүй — үүнийг яаж баталгаажуулах вэ

`AndroidManifest.xml`-д **`INTERNET` зөвшөөрөл огт байхгүй**. Дээр нь:

```xml
<application android:allowBackup="false"
             android:dataExtractionRules="@xml/data_extraction_rules"> <!-- бүгд deny -->
```

**`allowBackup="false"` бол зориудын, өртөгтэйгээ хамт.** Android-ийн авто-нөөцлөлт нь `khot.db`-г хэрэглэгчийн Google Drive-д хуулна. Тэр нь бидний цуглуулалт биш — гэхдээ «нэг ч байт төхөөрөмжөөс гарахгүй» гэдэг өгүүлбэрийг **үгчилсэн үнэн** байлгах нь энэ баримт бичгийн 4-р баганын гол зүйл. Өртөг: утас сольсон хүүхэд дэвтрээ алдана. Түүний хариулт бол §9-ийн экспорт.

**CI-д шалгагдана (3 шалгуур, build унагана):**

1. Нэгтгэсэн манифестад `android.permission.INTERNET` байвал — унана.
2. `pubspec.lock`-д `http`, `dio`, `web_socket_channel`, `firebase_*`, `posthog*`, `flutter_tts` байвал — унана.
3. Dart эх кодод `HttpClient`, `Socket.connect`, `NetworkInterface` байвал — унана.

**Play-ийн Data safety маягт (v1-ийн хариултууд):**

| Асуулт | Хариулт |
|---|---|
| Өгөгдөл цуглуулдаг эсвэл хуваалцдаг уу? | **Үгүй** |
| Аппын гүйцэтгэл / эвдрэлийн бүртгэл | **Үгүй** (v1-д crash reporting огт байхгүй) |
| Төхөөрөмжийн танигч, `AD_ID` | **Үгүй**, ямар ч build дээр |
| Устгах хүсэлтийн зам | Шаардлагагүй (цуглуулалт тэг), гэхдээ апп дотор товч байна |

Эрхийг нь Google өөрөө өгсөн: *«User data accessed by your app that is only processed locally on the user's device and not sent off device does not need to be disclosed»* (17 §0.5-ын иш татсан хэллэг). **v1-д Crashlytics ч байхгүй** — түүний оронд `FlutterError.onError` + `runZonedGuarded` нь сүүлийн эвдрэлийн 20 мөрийг `meta['last_crash_note']`-д бичиж, Тохиргоо → Тусламж дотор **«Сүүлчийн алдаа»** болж харагдана. Туршилтын ангид хүүхэд түүнийг чангаар уншиж чадна — тэр бол сүлжээгүй телеметр.

## 11. Тест болж хувирсан инвариантууд

| # | Инвариант | Тест |
|---|---|---|
| I1 | `fold(events) == (games, game_seats)` бүх тоглолтод | Бүртгэлээс проекц бүтээж мөр мөрөөр тулгана |
| I2 | `seq` нь 1-ээс тасралтгүй, цоорхойгүй | SQL тоолуур |
| I3 | `state='finished'` тоглолтод шинэ үйл явдал бичигдэхгүй | `commit` хамгаалалт + тест |
| I4 | Нэг шөнөд нэг суудал `NIGHT_ACTION`-ыг хоёр удаа бичихгүй | Индексээр шалгах query |
| I5 | Хураалт `in_progress` тоглолтод хүрэхгүй | 500 санамсаргүй өгөгдлийн санд prune гүйлгэнэ |
| I6 | `state='finished'` бүр `game_ledger` мөртэй | Гадаад холбоосын тест |
| **I7** | **`kill -9` fuzz** | Бүтэн тоглолтыг **200 санамсаргүй `await` цэгт** тасалж, сэргээгээд төлөв нь тасалтын өмнөхтэй **± нэг үйлдлээр** таарч байгааг шалгана |

I7 бол энэ бүлгийн жинхэнэ тест. Бусад зургаа нь SQL; I7 нь батерей дуусахыг дуурайдаг цорын ганц зүйл.

---

## v1-д юу орох вэ

*1 хөгжүүлэлтийн өдөр = **5 төлөвлөсөн цаг**. Доорх ~18 цаг нь 00-vision §10-ийн «Ангийн дэвтэр» (≈8 ц) ба M3-ийн «мэдээлэл алдагдахаас бэхжилт» блокт аль хэдийн төсөвлөгдсөн; үлдсэн ~24 цаг бол «тоглолт хэзээ ч алдагдахгүй» гэдгийн шударга үнэ.*

| Ажил | v1 | v2 | v3 | Өдөр |
|---|---|---|---|---|
| Схем, `ddl_v1.sql`, `Db` класс, PRAGMA-ууд | ✅ | | | **1.0** |
| `events` + `commit()` + `no-paint-before-commit` | ✅ | | | **1.0** |
| Проекц ба `rebuildProjection` | ✅ | | | **0.75** |
| Сэргээлтийн дэлгэц + §4.1-ийн хүснэгт бүхэлдээ | ✅ | | | **1.0** |
| I7 `kill -9` fuzz (200 цэг) + I1–I6 | ✅ | | | **1.0** |
| Тохиргооны хормын хувилбар + `config_hash` | ✅ | | | **0.25** |
| `game_ledger` + дэвтрийн хуудас унших | ✅ | | | **0.5** |
| Хураалт (50 тоглолт, 8 МБ тааз, `incremental_vacuum`) | ✅ | | | **0.5** |
| Экспорт: JSON + TXT, SAF-аар | ✅ | | | **0.75** |
| «Бүх өгөгдлийг устгах» + нэг тоглолт устгах | ✅ | | | **0.5** |
| Миграцийн суурь (`user_version`, `.bak`, `DbTooNewError`) | ✅ | | | **0.5** |
| `audio_packs` / `audio_clips` + чимээгүйн хугацааны тест | ✅ | | | **0.5** |
| CI-ийн 3 сүлжээний шалгуур + `allowBackup=false` | ✅ | | | **0.25** |
| Локал `last_crash_note` | ✅ | | | **0.25** |
| **v1 дүн** | | | | **8.75 ≈ 44 ц** |
| `titles` — дараалсан ялалт тоолох, бөхийн цол | | ✅ | | 0.75 |
| «Таалт» — хос хүний хүснэгт + цонхны функц | | ✅ | | 1.0 |
| `sqlite3_flutter_libs` (SQLite 3.46, +1.2 МБ APK) | | ✅ | | 0.5 |
| Олон `roster` + суудлын зураглал | | ✅ | | 0.75 |
| Сэдэв/аудио багц солих, багц устгах | | ✅ | | 0.5 |
| Синк-д бэлэн бүртгэл: `device_id` + Lamport, зөрчлийн бодлого | | | ✅ | 2.0 |
| Асинхрон онлайн тоглолтын хүснэгтүүд | | | ✅ | 3.0 |

**Хоцорвол хамгийн түрүүнд хасагдах гурав, дарааллаар нь:** TXT экспорт (0.25), `last_crash_note` (0.25), I7-ийн цэгийн тоо 200 → 50 (0.5). **Хэзээ ч хасагдахгүй:** `commit()`, сэргээлтийн дэлгэц, CI-ийн сүлжээний шалгуур.

## Нээлттэй асуулт

1. **`synchronous=FULL` хэр үнэтэй вэ?** Зээлсэн Redmi 9A ба Huawei дээр commit-ийн хугацааг M1-д хэмж. **< 25 мс** бол шийдвэр хүчинтэй. 25–60 мс бол `NORMAL` + үе шатны заагт `wal_checkpoint(TRUNCATE)` руу ух — алдагдлын хамгийн муу тохиолдол нэг үйлдлээс нэг үе шат болж өснө. **> 60 мс** бол шөнийн 6 секундын хэмнэл өөрөө эвдэрнэ, тэр үед `commit`-ыг товшилтын **дараа** биш, дараагийн суудал рүү шилжих хөдөлгөөнт дүрстэй **зэрэгцүүлж** гүйцэтгэнэ.
2. **50 тоглолт хэтэрхий олон уу?** M2.5-ийн таван суултын дараа асуу: хэн нэг нь дэвтрээ **10 хуудаснаас** гүйлгэж хараа юу? Хэрэв үгүй бол таазыг **20** болго, гүйлгэх дэлгэцийг хая — 0.5 өдөр хэмнэнэ.
3. **Экспортыг хэн нэг нь үнэхээр дарах уу?** Альфа таван суултад **тэг** бол экспорт v2 руу шилжинэ (0.75 өдөр), TXT хувилбар үүрд үхнэ. Нэгээс дээш бол суудлын нэрсийг файлд бичих эсэх нь шинэ асуулт болж гарна (доорх 5).
4. **Сэргээлтийн дэлгэц хэдэн удаа гарав?** Таван суултад **нэгээс** олон бол унаж байгаа шалтгаан нь сэргээлтийн өнгөлгөөнөөс чухал — `last_crash_note`-ыг унш, I7-г хая, алдааг зас.
5. **Дэвтэр нэр санах уу, суудлын дугаар л санах уу?** `roster_members.display_name` нь `NULL` зөвшөөрдөг. Анги нэр бичихийг хүсвэл экспортын файл нь 12 хүүхдийн нэртэй болно — тэр үед экспортод **«Нэргүй хадгалах»** сонголт нэмнэ (+0.25 өдөр). Хүсэхгүй бол багана үүрд `NULL` хэвээр, асуудал өөрөө байхгүй.
6. **`BEST_MOVE_SPOKEN`-д зөвхөн тоо бичих нь хүлээн зөвшөөрөгдөх үү?** Хэрэв хэн нэг нь «би юу гэж хэлсэн бэ?» гэж асуувал механик нь хүссэнээсээ илүү үнэтэй байсан гэсэн үг — v2-т дугааруудыг бичиж, дэвтэрт **оноолохгүйгээр** харуулна. Хэн ч асуухгүй бол одоогийн шийдвэр зөв.
7. **`allowBackup=false` хэнийг гомдоох вэ?** Хичээлийн жилийн дотор утас солих хүүхэд гарвал дэвтрээ алдана. M2.5-д ангиасаа асуу: сүүлийн жилд утсаа хэд хүн сольсон бэ? Тав дээр дөрөв бол v2-т «Дэвтрээ шинэ утас руу зөө» гэсэн QR/файл замыг төсөвлө — **сүлжээгээр биш, файлаар.**
