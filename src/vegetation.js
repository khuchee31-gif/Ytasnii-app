// ===================================================================
// vegetation.js — instanced pines, rocks & wind-animated grass.
// All scatter is deterministic (seeded RNG) and terrain-aware.
// ===================================================================

import * as THREE from 'three';
import { mergeGeometries } from 'three/addons/utils/BufferGeometryUtils.js';
import { CONFIG } from './config.js';

// deterministic RNG so the world is identical every load
function mulberry32(seed) {
  return function () {
    seed |= 0; seed = (seed + 0x6D2B79F5) | 0;
    let t = Math.imul(seed ^ (seed >>> 15), 1 | seed);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

export class Vegetation {
  constructor(scene, terrain, env) {
    this.scene = scene;
    this.terrain = terrain;
    this.env = env;
    this.rng = mulberry32(1337);
    this.grassMat = null;
    this.time = 0;

    this._buildTrees();
    this._buildRocks();
    this._buildGrass();
  }

  // approximate terrain slope via finite differences
  _slope(x, z) {
    const h = this.terrain.heightAt.bind(this.terrain);
    const e = 1.5;
    const dx = h(x + e, z) - h(x - e, z);
    const dz = h(x, z + e) - h(x, z - e);
    return Math.sqrt(dx * dx + dz * dz) / (2 * e);
  }

  // ---- pine tree (trunk + 3 stacked cones, merged, vertex-colored) ----
  _pineGeometry() {
    const parts = [];
    const trunk = new THREE.CylinderGeometry(0.16, 0.26, 2.0, 6);
    trunk.translate(0, 1.0, 0);
    paint(trunk, 0x5a3d23);
    parts.push(trunk);

    const tiers = [
      { y: 2.0, r: 1.5, h: 2.2 },
      { y: 3.2, r: 1.1, h: 1.9 },
      { y: 4.3, r: 0.7, h: 1.5 },
    ];
    for (const t of tiers) {
      const cone = new THREE.ConeGeometry(t.r, t.h, 8);
      cone.translate(0, t.y + t.h * 0.3, 0);
      paint(cone, 0x33591f);
      parts.push(cone);
    }
    const geo = mergeGeometries(parts, false);
    geo.computeVertexNormals();
    return geo;

    function paint(g, hex) {
      const c = new THREE.Color(hex);
      const n = g.attributes.position.count;
      const col = new Float32Array(n * 3);
      for (let i = 0; i < n; i++) { col[i * 3] = c.r; col[i * 3 + 1] = c.g; col[i * 3 + 2] = c.b; }
      g.setAttribute('color', new THREE.BufferAttribute(col, 3));
    }
  }

  _buildTrees() {
    const geo = this._pineGeometry();
    const mat = new THREE.MeshStandardMaterial({
      vertexColors: true, roughness: 0.85, metalness: 0.0, envMapIntensity: 0.6,
    });
    this.env.setupMaterial(mat);

    const count = CONFIG.vegetation.trees;
    const mesh = new THREE.InstancedMesh(geo, mat, count);
    mesh.castShadow = true; mesh.receiveShadow = true;
    mesh.instanceMatrix.setUsage(THREE.StaticDrawUsage);

    const m = new THREE.Matrix4();
    const q = new THREE.Quaternion();
    const s = new THREE.Vector3();
    const p = new THREE.Vector3();
    const half = this.terrain.half - 8;
    let placed = 0, attempts = 0;
    while (placed < count && attempts < count * 12) {
      attempts++;
      const x = (this.rng() * 2 - 1) * half;
      const z = (this.rng() * 2 - 1) * half;
      if (Math.hypot(x, z) < 16) continue;            // keep spawn clear
      if (this._slope(x, z) > 0.45) continue;          // no trees on cliffs
      const y = this.terrain.heightAt(x, z);
      const sc = 0.7 + this.rng() * 0.9;
      p.set(x, y - 0.2, z);
      q.setFromAxisAngle(new THREE.Vector3(0, 1, 0), this.rng() * Math.PI * 2);
      s.set(sc, sc * (0.9 + this.rng() * 0.4), sc);
      m.compose(p, q, s);
      mesh.setMatrixAt(placed, m);
      placed++;
    }
    mesh.count = placed;
    mesh.instanceMatrix.needsUpdate = true;
    this.scene.add(mesh);
    this.trees = mesh;
  }

  _buildRocks() {
    const geo = new THREE.IcosahedronGeometry(1, 1);
    // jitter vertices for a natural boulder
    const pos = geo.attributes.position;
    const r = mulberry32(99);
    for (let i = 0; i < pos.count; i++) {
      const f = 0.78 + r() * 0.5;
      pos.setXYZ(i, pos.getX(i) * f, pos.getY(i) * (f * 0.8), pos.getZ(i) * f);
    }
    geo.computeVertexNormals();

    const mat = new THREE.MeshStandardMaterial({
      color: 0x8d877c, roughness: 0.92, metalness: 0.0,
      flatShading: true, envMapIntensity: 0.7,
    });
    this.env.setupMaterial(mat);

    const count = CONFIG.vegetation.rocks;
    const mesh = new THREE.InstancedMesh(geo, mat, count);
    mesh.castShadow = true; mesh.receiveShadow = true;

    const m = new THREE.Matrix4();
    const q = new THREE.Quaternion();
    const e = new THREE.Euler();
    const s = new THREE.Vector3();
    const p = new THREE.Vector3();
    const half = this.terrain.half - 5;
    for (let i = 0; i < count; i++) {
      const x = (this.rng() * 2 - 1) * half;
      const z = (this.rng() * 2 - 1) * half;
      const y = this.terrain.heightAt(x, z);
      const sc = 0.4 + this.rng() * 1.8;
      p.set(x, y - sc * 0.25, z);
      e.set(this.rng() * 0.5, this.rng() * Math.PI * 2, this.rng() * 0.5);
      q.setFromEuler(e);
      s.set(sc, sc * (0.6 + this.rng() * 0.5), sc);
      m.compose(p, q, s);
      mesh.setMatrixAt(i, m);
    }
    mesh.instanceMatrix.needsUpdate = true;
    this.scene.add(mesh);
    this.rocks = mesh;
  }

  // ---- single grass blade: tapered, ~0.5 units tall, dark base → light tip
  _bladeGeometry() {
    const h = 1.0, w = 0.06;
    const g = new THREE.BufferGeometry();
    // 3 stacked quads worth of vertices as a simple bending strip
    const verts = [
      -w, 0, 0,  w, 0, 0,  -w * 0.7, h * 0.5, 0,
      w * 0.7, h * 0.5, 0,  0, h, 0,
    ];
    const idx = [0, 1, 2, 2, 1, 3, 2, 3, 4];
    const colors = [];
    const base = new THREE.Color(0x3a5520);
    const tip = new THREE.Color(0xa6bb55);
    const heights = [0, 0, 0.5, 0.5, 1];
    for (const t of heights) {
      const c = base.clone().lerp(tip, t);
      colors.push(c.r, c.g, c.b);
    }
    g.setAttribute('position', new THREE.Float32BufferAttribute(verts, 3));
    g.setAttribute('color', new THREE.Float32BufferAttribute(colors, 3));
    g.setIndex(idx);
    g.computeVertexNormals();
    return g;
  }

  _buildGrass() {
    const geo = this._bladeGeometry();
    const mat = new THREE.MeshStandardMaterial({
      vertexColors: true, roughness: 0.95, metalness: 0.0,
      side: THREE.DoubleSide, envMapIntensity: 0.5,
    });

    // wind animation via shader injection — composed with CSM shadows
    this._grassTime = { value: 0 };
    const windInject = (shader) => {
      shader.uniforms.uTime = this._grassTime;
      shader.vertexShader = shader.vertexShader
        .replace('#include <common>', '#include <common>\nuniform float uTime;')
        .replace('#include <begin_vertex>', `#include <begin_vertex>
          float bH = position.y;
          vec3 iPos = vec3(instanceMatrix[3][0], instanceMatrix[3][1], instanceMatrix[3][2]);
          float ph = iPos.x * 0.3 + iPos.z * 0.3;
          float w = sin(uTime * 1.6 + ph) * 0.14 + sin(uTime * 3.3 + ph * 1.7) * 0.05;
          transformed.x += w * bH;
          transformed.z += w * 0.5 * bH;`);
    };
    this.env.setupMaterial(mat, windInject);
    this.grassMat = mat;

    const count = CONFIG.vegetation.grassBlades;
    const radius = CONFIG.vegetation.grassRadius;
    const mesh = new THREE.InstancedMesh(geo, mat, count);
    mesh.castShadow = false; mesh.receiveShadow = true;
    mesh.frustumCulled = false;

    const m = new THREE.Matrix4();
    const q = new THREE.Quaternion();
    const up = new THREE.Vector3(0, 1, 0);
    const s = new THREE.Vector3();
    const p = new THREE.Vector3();
    for (let i = 0; i < count; i++) {
      // dense disc around the spawn/explorable area
      const ang = this.rng() * Math.PI * 2;
      const rad = Math.sqrt(this.rng()) * radius;
      const x = Math.cos(ang) * rad;
      const z = Math.sin(ang) * rad;
      if (this._slope(x, z) > 0.5) { mesh.setMatrixAt(i, m.makeScale(0, 0, 0)); continue; }
      const y = this.terrain.heightAt(x, z);
      // short, lush blades (~0.25–0.5 m) for a dense lawn rather than spikes
      const sc = 0.28 + this.rng() * 0.22;
      p.set(x, y, z);
      q.setFromAxisAngle(up, this.rng() * Math.PI * 2);
      s.set(sc * 1.2, sc * (0.85 + this.rng() * 0.4), sc * 1.2);
      m.compose(p, q, s);
      mesh.setMatrixAt(i, m);
    }
    mesh.instanceMatrix.needsUpdate = true;
    this.scene.add(mesh);
    this.grass = mesh;
  }

  update(dt) {
    this.time += dt;
    if (this._grassTime) this._grassTime.value = this.time;
  }
}
