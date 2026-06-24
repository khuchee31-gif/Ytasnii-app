// ===================================================================
// config.js — central tunables & CC0 asset sources
// All assets are CC0 (Poly Haven) or three.js example models (MIT).
// Loaded at runtime from CDN; see README for full credits.
// ===================================================================

const PH = 'https://dl.polyhaven.org/file/ph-assets';
const THREE_CDN = 'https://cdn.jsdelivr.net/gh/mrdoob/three.js@r160';

export const ASSETS = {
  // --- HDRI sky / image-based lighting (golden hour) ---
  hdri: {
    primary: `${PH}/HDRIs/hdr/2k/qwantani_puresky_2k.hdr`,
    fallback: `${PH}/HDRIs/hdr/1k/qwantani_puresky_1k.hdr`,
  },

  // --- Ground PBR (grass+rock detail, tiled) ---
  groundGrass: {
    map:       `${PH}/Textures/jpg/1k/aerial_grass_rock/aerial_grass_rock_diff_1k.jpg`,
    normalMap: `${PH}/Textures/jpg/1k/aerial_grass_rock/aerial_grass_rock_nor_gl_1k.jpg`,
    roughnessMap: `${PH}/Textures/jpg/1k/aerial_grass_rock/aerial_grass_rock_rough_1k.jpg`,
  },
  // --- Rocky layer for steep slopes (slope splatting) ---
  groundRock: {
    map:       `${PH}/Textures/jpg/1k/rocky_terrain_02/rocky_terrain_02_diff_1k.jpg`,
    normalMap: `${PH}/Textures/jpg/1k/rocky_terrain_02/rocky_terrain_02_nor_gl_1k.jpg`,
    roughnessMap: `${PH}/Textures/jpg/1k/rocky_terrain_02/rocky_terrain_02_rough_1k.jpg`,
  },

  // --- Rigged character w/ Idle / Walk / Run clips (three.js example, MIT) ---
  character: `${THREE_CDN}/examples/models/gltf/Soldier.glb`,
};

// World / gameplay tunables -------------------------------------------------
export const CONFIG = {
  terrain: {
    size: 400,         // world units (meters) per side
    segments: 256,     // grid resolution
    height: 26,        // max elevation amplitude
    grassTiling: 90,   // texture repeats across terrain
    rockTiling: 140,
  },

  player: {
    walkSpeed: 2.6,
    runSpeed: 7.2,
    jumpSpeed: 8.5,
    gravity: -22,
    height: 1.7,
    turnLerp: 0.18,
  },

  camera: {
    distance: 6.2,
    height: 2.4,
    minDistance: 1.6,
    sensitivity: 0.0024,
    lerp: 0.12,
    minPitch: -0.55,
    maxPitch: 0.95,
    fov: 55,
  },

  vegetation: {
    trees: 320,
    rocks: 140,
    grassBlades: 90000,
    grassRadius: 52,   // grass only near the player area for perf
  },

  fog: { color: 0xcfc0a8, near: 60, far: 340 },

  quality: {
    maxPixelRatio: 1.75,
    shadowMapSize: 2048,
    cascades: 4,
    shadowFar: 220,
  },
};
