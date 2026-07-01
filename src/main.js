// ===================================================================
// main.js — bootstrap, asset loading, game loop.
// ===================================================================

import * as THREE from 'three';
import { CONFIG, ASSETS } from './config.js';
import { Loader } from './loader.js';
import { Environment } from './environment.js';
import { Terrain } from './terrain.js';
import { Vegetation } from './vegetation.js';
import { Player } from './player.js';
import { CameraRig } from './cameraRig.js';
import { PostFX } from './postfx.js';
import { Input } from './input.js';

const canvas = document.getElementById('scene');
const ui = {
  loader: document.querySelector('[data-loader]'),
  bar: document.querySelector('[data-bar]'),
  pct: document.querySelector('[data-pct]'),
  status: document.querySelector('[data-status]'),
  hint: document.querySelector('[data-hint]'),
  fps: document.querySelector('[data-fps]'),
  dev: document.querySelector('[data-dev]'),
};

// ---- mobile performance profile -------------------------------------------
// Phones can't sustain the full desktop pipeline, so scale the world and
// disable the most expensive passes BEFORE anything reads CONFIG.
const IS_MOBILE = matchMedia('(pointer: coarse)').matches || /Android|iPhone|iPad|iPod|Mobile/i.test(navigator.userAgent);
if (IS_MOBILE) {
  CONFIG.quality.maxPixelRatio = 1.0;
  CONFIG.quality.shadowMapSize = 1024;
  CONFIG.quality.cascades = 3;
  CONFIG.quality.shadowFar = 150;
  CONFIG.vegetation.trees = 170;
  CONFIG.vegetation.rocks = 80;
  CONFIG.vegetation.grassBlades = 26000;
  CONFIG.vegetation.grassRadius = 40;
  CONFIG.fog.far = 260;
  ASSETS.hdri.primary = ASSETS.hdri.fallback; // 1k sky
}

// ---- renderer ----
const renderer = new THREE.WebGLRenderer({ canvas, antialias: false, powerPreference: 'high-performance' });
renderer.setPixelRatio(Math.min(devicePixelRatio, CONFIG.quality.maxPixelRatio));
renderer.setSize(innerWidth, innerHeight);
renderer.shadowMap.enabled = true;
renderer.shadowMap.type = THREE.PCFSoftShadowMap;

// ---- device diagnostics (browser can only report approximate RAM) ----
(function showDeviceInfo() {
  let gpu = 'unknown';
  try {
    const gl = renderer.getContext();
    const ext = gl.getExtension('WEBGL_debug_renderer_info');
    if (ext) gpu = gl.getParameter(ext.UNMASKED_RENDERER_WEBGL);
  } catch (e) { /* ignore */ }
  const ram = navigator.deviceMemory ? `~${navigator.deviceMemory} GB` : 'N/A';
  const cores = navigator.hardwareConcurrency || '?';
  const dpr = Math.min(devicePixelRatio, CONFIG.quality.maxPixelRatio).toFixed(2);
  const profile = IS_MOBILE ? 'Mobile' : 'Desktop';
  ui.dev.innerHTML =
    `RAM ${ram} · CPU ${cores} core · DPR ${dpr}<br>` +
    `GPU ${gpu}<br>` +
    `${screen.width}×${screen.height} · ${profile} profile`;
})();

const scene = new THREE.Scene();
const camera = new THREE.PerspectiveCamera(CONFIG.camera.fov, innerWidth / innerHeight, 0.1, 1200);
camera.position.set(0, 5, 10);

const input = new Input(canvas);

let env, terrain, vegetation, player, rig, postfx;
let running = false;

// ---- load ----
(async function boot() {
  const loader = new Loader(renderer, (frac, file) => {
    const p = Math.round(frac * 100);
    ui.bar.style.width = p + '%';
    ui.pct.textContent = p;
    if (file) ui.status.textContent = file;
  });

  try {
    const [hdr, grassTex, rockTex, character] = await Promise.all([
      loader.loadHDRI(),
      loader.loadPBRSet(ASSETS.groundGrass, { repeat: CONFIG.terrain.grassTiling }),
      loader.loadPBRSet(ASSETS.groundRock, { repeat: CONFIG.terrain.grassTiling }),
      loader.loadCharacter(),
    ]);

    env = new Environment(scene, camera, hdr);

    terrain = new Terrain({ grassTex, rockTex });
    env.setupMaterial(terrain.mesh.material, terrain.rockInject);
    scene.add(terrain.mesh);

    vegetation = new Vegetation(scene, terrain, env);
    player = new Player(scene, terrain, env, character);
    rig = new CameraRig(camera, terrain);
    postfx = new PostFX(renderer, scene, camera);

    // mobile: drop the two most expensive passes, keep bloom + grade + FXAA
    if (IS_MOBILE) {
      postfx.ssao.enabled = false;
      postfx.bokeh.enabled = false;
    }

    loader.dispose();

    // reveal
    ui.loader.classList.add('hidden');
    ui.hint.classList.add('show');
    const startPlay = () => {
      ui.hint.classList.add('hidden');
      if (!input.isTouch) canvas.requestPointerLock?.();
    };
    ui.hint.addEventListener('click', startPlay);
    ui.hint.addEventListener('touchstart', (e) => { e.preventDefault(); startPlay(); }, { passive: false });
    running = true;
    clock.start();
  } catch (err) {
    console.error(err);
    ui.status.textContent = 'Load error: ' + (err?.message || err);
  }
})();

// ---- input toggles ----
addEventListener('keydown', (e) => {
  if (!postfx) return;
  switch (e.code) {
    case 'Digit1': postfx.toggle('ssao'); break;
    case 'Digit2': postfx.toggle('bloom'); break;
    case 'Digit3': postfx.toggle('dof'); break;
    case 'Digit4': postfx.toggle('motionblur'); break;
    case 'KeyH': document.body.classList.toggle('hud-off'); break;
  }
});

// ---- resize ----
addEventListener('resize', () => {
  camera.aspect = innerWidth / innerHeight;
  camera.updateProjectionMatrix();
  renderer.setSize(innerWidth, innerHeight);
  renderer.setPixelRatio(Math.min(devicePixelRatio, CONFIG.quality.maxPixelRatio));
  postfx?.setSize(innerWidth, innerHeight, renderer.getPixelRatio());
  env?.onResize(camera);
});

// ---- loop ----
const clock = new THREE.Clock(false);
let fpsAccum = 0, fpsFrames = 0, fpsTimer = 0;

function frame() {
  requestAnimationFrame(frame);
  if (!running) return;

  let dt = clock.getDelta();
  dt = Math.min(dt, 0.05); // clamp after tab-switch

  rig.applyMouse(input);
  player.update(dt, input, rig.getMoveBasis());
  rig.follow(player.position, dt);
  env.update(camera);
  vegetation.update(dt);

  const focus = camera.position.distanceTo(player.position);
  postfx.render(dt, focus);

  // fps readout
  fpsTimer += dt; fpsFrames++; fpsAccum += dt;
  if (fpsTimer >= 0.5) {
    const fps = Math.round(fpsFrames / fpsAccum);
    ui.fps.textContent = fps;
    fpsTimer = 0; fpsFrames = 0; fpsAccum = 0;
  }
}
frame();
