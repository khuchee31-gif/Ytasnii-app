// ===================================================================
// terrain.js — procedural heightfield with PBR grass + slope rock splat
// Geometry is built directly in the XZ plane so object space == world
// space (clean normals & height sampling for collision).
// ===================================================================

import * as THREE from 'three';
import { ImprovedNoise } from 'three/addons/math/ImprovedNoise.js';
import { CONFIG } from './config.js';

const noise = new ImprovedNoise();

// fractal brownian motion — multi-octave rolling hills
function fbm(x, z) {
  let h = 0, amp = 1, freq = 1, norm = 0;
  for (let o = 0; o < 5; o++) {
    h += amp * noise.noise(x * freq, z * freq, 12.34);
    norm += amp;
    amp *= 0.5;
    freq *= 2.0;
  }
  return h / norm; // ~[-1, 1]
}

export class Terrain {
  constructor({ grassTex, rockTex }) {
    const { size, segments, height } = CONFIG.terrain;
    this.size = size;
    this.segments = segments;
    this.maxHeight = height;
    this.half = size / 2;

    // --- heightfield ---
    const cols = segments + 1;
    this.cols = cols;
    this.heights = new Float32Array(cols * cols);

    const positions = new Float32Array(cols * cols * 3);
    const uvs = new Float32Array(cols * cols * 2);
    const rockAttr = new Float32Array(cols * cols);
    const step = size / segments;
    const freq = 0.012; // hill scale

    for (let j = 0; j < cols; j++) {
      for (let i = 0; i < cols; i++) {
        const idx = j * cols + i;
        const x = -this.half + i * step;
        const z = -this.half + j * step;

        // central spawn area flattened with a smooth falloff
        const distC = Math.sqrt(x * x + z * z);
        const flatten = THREE.MathUtils.smoothstep(distC, 18, 70);
        let h = fbm(x * freq, z * freq);
        h = Math.sign(h) * Math.pow(Math.abs(h), 1.25); // sharpen ridges
        h *= height * flatten;

        this.heights[idx] = h;
        positions[idx * 3] = x;
        positions[idx * 3 + 1] = h;
        positions[idx * 3 + 2] = z;
        uvs[idx * 2] = i / segments;
        uvs[idx * 2 + 1] = j / segments;
      }
    }

    const indices = [];
    for (let j = 0; j < segments; j++) {
      for (let i = 0; i < segments; i++) {
        const a = j * cols + i;
        const b = a + 1;
        const c = a + cols;
        const d = c + 1;
        indices.push(a, c, b, b, c, d);
      }
    }

    const geo = new THREE.BufferGeometry();
    geo.setAttribute('position', new THREE.BufferAttribute(positions, 3));
    geo.setAttribute('uv', new THREE.BufferAttribute(uvs, 2));
    geo.setIndex(indices);
    geo.computeVertexNormals();

    // rock weight from slope (post-normals) + altitude
    const nrm = geo.attributes.normal.array;
    for (let k = 0; k < cols * cols; k++) {
      const slope = 1.0 - nrm[k * 3 + 1];            // 0 flat → 1 vertical
      const alt = THREE.MathUtils.clamp(this.heights[k] / height, 0, 1);
      rockAttr[k] = THREE.MathUtils.clamp(
        THREE.MathUtils.smoothstep(slope, 0.12, 0.4) + alt * 0.25, 0, 1);
    }
    geo.setAttribute('aRock', new THREE.BufferAttribute(rockAttr, 1));
    geo.computeBoundingSphere();
    this.geometry = geo;

    // --- material: grass PBR + rock slope splat via onBeforeCompile ---
    const mat = new THREE.MeshStandardMaterial({
      map: grassTex.map,
      normalMap: grassTex.normalMap,
      roughnessMap: grassTex.roughnessMap,
      metalness: 0.0,
      roughness: 1.0,
      normalScale: new THREE.Vector2(1.1, 1.1),
      dithering: true,
    });

    // rock-slope splat injection — composed with CSM via env.setupMaterial()
    const rockUvScale = CONFIG.terrain.rockTiling / CONFIG.terrain.grassTiling;
    this.rockInject = (shader) => {
      shader.uniforms.map2 = { value: rockTex.map };
      shader.uniforms.roughnessMap2 = { value: rockTex.roughnessMap };
      shader.uniforms.rockUvScale = { value: rockUvScale };

      shader.vertexShader = shader.vertexShader
        .replace('#include <common>',
          '#include <common>\nattribute float aRock;\nvarying float vRock;')
        .replace('#include <begin_vertex>',
          '#include <begin_vertex>\nvRock = aRock;');

      shader.fragmentShader = shader.fragmentShader
        .replace('#include <common>',
          `#include <common>
           uniform sampler2D map2;
           uniform sampler2D roughnessMap2;
           uniform float rockUvScale;
           varying float vRock;`)
        // blend albedo (manual sRGB→linear for the extra texture)
        .replace('#include <map_fragment>',
          `#include <map_fragment>
           {
             vec3 rockAlbedo = texture2D( map2, vMapUv * rockUvScale ).rgb;
             rockAlbedo = pow( rockAlbedo, vec3( 2.2 ) );
             diffuseColor.rgb = mix( diffuseColor.rgb, rockAlbedo, vRock );
           }`)
        // blend roughness
        .replace('#include <roughnessmap_fragment>',
          `#include <roughnessmap_fragment>
           {
             float rRock = texture2D( roughnessMap2, vRoughnessMapUv * rockUvScale ).g;
             roughnessFactor = mix( roughnessFactor, rRock, vRock );
           }`);
    };

    this.mesh = new THREE.Mesh(geo, mat);
    this.mesh.castShadow = false;
    this.mesh.receiveShadow = true;
    this.mesh.name = 'terrain';
  }

  // bilinear height sample in world space (matches mesh exactly)
  heightAt(x, z) {
    const { size, segments } = CONFIG.terrain;
    const gx = ((x + this.half) / size) * segments;
    const gz = ((z + this.half) / size) * segments;
    const i = Math.floor(gx), j = Math.floor(gz);
    if (i < 0 || j < 0 || i >= segments || j >= segments) return 0;
    const fx = gx - i, fz = gz - j;
    const c = this.cols;
    const h00 = this.heights[j * c + i];
    const h10 = this.heights[j * c + i + 1];
    const h01 = this.heights[(j + 1) * c + i];
    const h11 = this.heights[(j + 1) * c + i + 1];
    const h0 = h00 * (1 - fx) + h10 * fx;
    const h1 = h01 * (1 - fx) + h11 * fx;
    return h0 * (1 - fz) + h1 * fz;
  }
}
