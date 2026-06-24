// ===================================================================
// loader.js — async asset loading with weighted progress reporting
// ===================================================================

import * as THREE from 'three';
import { RGBELoader } from 'three/addons/loaders/RGBELoader.js';
import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';
import { ASSETS } from './config.js';

export class Loader {
  constructor(renderer, onProgress) {
    this.renderer = renderer;
    this.onProgress = onProgress || (() => {});
    this.manager = new THREE.LoadingManager();
    this.rgbe = new RGBELoader(this.manager);
    this.tex = new THREE.TextureLoader(this.manager);
    this.gltf = new GLTFLoader(this.manager);
    this.pmrem = new THREE.PMREMGenerator(renderer);
    this.pmrem.compileEquirectangularShader();

    this.manager.onProgress = (url, loaded, total) => {
      const file = url.split('/').pop().split('?')[0];
      this.onProgress(total ? loaded / total : 0, file);
    };
  }

  _load(loader, url) {
    return new Promise((res, rej) => loader.load(url, res, undefined, rej));
  }

  async loadHDRI() {
    let hdr;
    try { hdr = await this._load(this.rgbe, ASSETS.hdri.primary); }
    catch { hdr = await this._load(this.rgbe, ASSETS.hdri.fallback); }
    hdr.mapping = THREE.EquirectangularReflectionMapping;
    const envMap = this.pmrem.fromEquirectangular(hdr).texture;
    return { background: hdr, envMap };
  }

  // load a PBR set: { map, normalMap, roughnessMap, aoMap? } of urls
  async loadPBRSet(set, { repeat = 1, srgbMap = true } = {}) {
    const out = {};
    const entries = Object.entries(set);
    const textures = await Promise.all(entries.map(([, url]) => this._load(this.tex, url)));
    entries.forEach(([key], i) => {
      const t = textures[i];
      t.wrapS = t.wrapT = THREE.RepeatWrapping;
      t.repeat.set(repeat, repeat);
      t.anisotropy = Math.min(8, this.renderer.capabilities.getMaxAnisotropy());
      if (key === 'map' && srgbMap) t.colorSpace = THREE.SRGBColorSpace;
      out[key] = t;
    });
    return out;
  }

  async loadCharacter() {
    const gltf = await this._load(this.gltf, ASSETS.character);
    return gltf;
  }

  dispose() { this.pmrem.dispose(); }
}
