# Ytasnii — Photoreal WebGL Field (GTA / RDR2-style demo)

Браузер дээр ажиллах **third-person фотореалистик орчны демо**. Нэг үзэсгэлэнтэй
talz/нуга (map slice) дотор дүрээрээ алхаж, гүйж, үсэрч, камераа тойруулан орчноо
үзнэ. Бүтэн тоглоом БИШ — зорилго нь **зураглалын чанар**: HDRI тэнгэр + image-based
lighting, PBR газар, cascaded shadow maps, мод/чулуу/өвсний instancing, болон кино
шиг post-processing.

> Pure HTML/JS + Three.js (r160, CDN, build шаардлагагүй). ES modules + importmap.

![demo](https://img.shields.io/badge/three.js-r160-blue) ![webgl2](https://img.shields.io/badge/WebGL-2-green) ![license](https://img.shields.io/badge/assets-CC0%20%2F%20MIT-lightgrey)

---

## Ажиллуулах

ES module-уудад локал сервер хэрэгтэй (`file://` дээр ажиллахгүй):

```bash
# repo дотор
python3 -m http.server 8000
# дараа нь http://localhost:8000 руу ороорой
```

эсвэл дурын статик сервер (`npx serve`, VS Code "Live Server" г.м.).

Эхний удаа орчны asset-ууд (HDRI ~1–2 MB, PBR texture-ууд, rigged GLB) CDN-ээс
ачаална — ачаалах прогресс дэлгэц дээр харагдана. Дараа нь **дэлгэц дээр дарж**
хулганын заагчийг түгжээд (pointer-lock) орчинд орно.

### Удирдлага
| Товч | Үйлдэл |
|------|--------|
| `W A S D` | алхах / явах |
| `Shift` | гүйх (sprint) |
| `Space` | үсрэх |
| `Mouse` | камер эргүүлэх (over-the-shoulder) |
| `Esc` | хулгана чөлөөлөх |
| `1` / `2` / `3` / `4` | SSAO / Bloom / Depth-of-Field / Motion-blur асаах-унтраах |
| `H` | HUD нуух |

---

## Зураглалын онцлогууд
- **HDRI тэнгэр + IBL** — Poly Haven golden-hour puresky, PMREM-ээр env map болгож
  бүх материалд тусгал/гэрэлтүүлэг өгнө.
- **PBR газрын гадарга** — procedural fBm heightfield дээр өвс + чулууны PBR
  (albedo/normal/roughness) texture, налуу/өндрөөр **rock slope splatting** (custom
  shader injection).
- **Cascaded Shadow Maps (CSM)** — 4 каскад, зөөлөн ирмэгтэй, зайнаас бүдгэрдэг
  чанартай сүүдэр.
- **Instanced ургамал** — 320 нарс, 140 чулуу, ~90k өвсний иш (vertex-shader салхины
  хөдөлгөөнтэй). Бүгд `InstancedMesh`.
- **Atmospheric fog** + golden-hour намхан нар → урт, дулаан сүүдэр.
- **Post-processing stack** (`EffectComposer`): SSAO → Depth-of-Field (bokeh) →
  Bloom → FXAA → optional motion-blur → **cinematic grade pass** (exposure + ACES
  filmic tone mapping + lift/gamma/gain color grade + saturation + vignette + film grain
  + sRGB).
- **Third-person controller** — rigged GLB (Idle/Walk/Run weight-blend), gravity,
  газар дагасан collision, мөрөн дээгүүр зөөлөн дагах + terrain collision-той камер.

---

## Бүтэц

```
index.html          # importmap, loading screen, HUD, hint
style.css           # UI / loader / HUD загвар
src/
  main.js           # bootstrap + asset load + game loop
  config.js         # бүх tunable + CC0 asset URL
  loader.js         # HDRI(RGBE+PMREM) / PBR / GLB ачаалал, прогресс
  environment.js    # тэнгэр, IBL, нар (CSM), hemisphere fill, fog
  terrain.js        # procedural heightfield + rock-splat material + collision
  vegetation.js     # instanced нарс / чулуу / салхитай өвс
  player.js         # дүр, анимац blend, physics
  cameraRig.js      # third-person камер, pointer-lock, collision
  postfx.js         # EffectComposer post-processing stack
  input.js          # keyboard + pointer-lock mouse
```

---

## Asset-ийн эх сурвалж & лиценз
Бүх asset нь **CDN-ээс runtime дээр** ачаалагддаг (repo дотор binary хадгалаагүй).

| Asset | Эх сурвалж | Лиценз |
|-------|-----------|--------|
| HDRI sky `qwantani_puresky` | [Poly Haven](https://polyhaven.com/a/qwantani_puresky) | CC0 |
| Ground PBR `aerial_grass_rock` | [Poly Haven](https://polyhaven.com/a/aerial_grass_rock) | CC0 |
| Rock PBR `rocky_terrain_02` | [Poly Haven](https://polyhaven.com/a/rocky_terrain_02) | CC0 |
| Rigged character `Soldier.glb` (Idle/Walk/Run) | [three.js examples](https://github.com/mrdoob/three.js/tree/dev/examples/models/gltf) | MIT |
| Three.js + addons (r160) | [unpkg / three.js](https://github.com/mrdoob/three.js) | MIT |

Мод/чулуу/өвс нь procedural (instanced) тул нэмэлт download шаардахгүй.

---

## Гүйцэтгэл (60 FPS барих)
- `InstancedMesh` (ургамал), frustum culling, PMREM-cached IBL.
- Pixel ratio `≤ 1.75`-аар хязгаарласан.
- Post-fx pass бүрийг `1`–`4` товчоор унтрааж **FPS-ээ нэмж** болно (SSAO + DoF хамгийн
  үнэтэй). HUD-д бодит FPS харагдана.
- Сул машин дээр: `src/config.js` доторх `quality.shadowMapSize`, `vegetation.grassBlades`,
  эсвэл `quality.maxPixelRatio`-г бууруулна.

> Зөвлөмж: тусдаа GPU-тай хөтөч дээр хамгийн сайхан харагдана. Програм хангамжийн
> (software) WebGL дээр ажиллах боловч удаан.

---

## Цаашид сайжруулах санаа
- Texture-based **detail/blend maps**-аар газрыг илүү баялаг (зам, шавар, элс).
- **GPU grass** (compute/transform-feedback) ба player-г дагасан динамик өвсний талбай.
- **Water plane** (SSR/refraction), цаг агаар (бороо, манан), өдөр-шөнийн cycle.
- Mixamo-гийн **jump / turn / strafe** clip-ууд нэмж locomotion-г баяжуулах.
- **LUT** файлаар (`.cube`) color grading, болон илүү нарийн motion-blur (velocity buffer).
- Барилга/props-ыг GLTF-ээр ачаалж жижиг **хот/суурин** map slice болгох.

---

_Crafted with Claude Code · Three.js r160 · WebGL2_
