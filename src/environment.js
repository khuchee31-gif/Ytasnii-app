// ===================================================================
// environment.js — HDRI sky + IBL, golden-hour sun with cascaded
// shadow maps (CSM), hemisphere fill light, atmospheric fog.
// ===================================================================

import * as THREE from 'three';
import { CSM } from 'three/addons/csm/CSM.js';
import { CONFIG } from './config.js';

export class Environment {
  constructor(scene, camera, { background, envMap }) {
    this.scene = scene;
    const q = CONFIG.quality;

    // sky + image-based lighting
    background.mapping = THREE.EquirectangularReflectionMapping;
    scene.background = background;
    scene.environment = envMap;

    // atmospheric depth
    scene.fog = new THREE.Fog(CONFIG.fog.color, CONFIG.fog.near, CONFIG.fog.far);

    // golden-hour sun direction (low angle → long, warm shadows)
    this.lightDirection = new THREE.Vector3(-0.62, -0.26, -0.74).normalize();

    // cascaded shadow maps for crisp-near / soft-far shadows
    this.csm = new CSM({
      maxFar: q.shadowFar,
      cascades: q.cascades,
      mode: 'practical',
      parent: scene,
      shadowMapSize: q.shadowMapSize,
      lightDirection: this.lightDirection.clone(),
      camera,
      lightNear: 1,
      lightFar: 600,
      lightMargin: 120,
    });
    this.csm.fade = true;

    // warm, intense key light + soft shadow edges
    this.csm.lights.forEach((l) => {
      l.color.setHex(0xffe6c2);
      l.intensity = 2.4;
      l.shadow.bias = -0.0004;
      l.shadow.normalBias = 0.04;
      l.shadow.radius = 3.5;
    });

    // sky/ground hemisphere fill — lifts the shadows with bounced sky light
    this.hemi = new THREE.HemisphereLight(0xaecbff, 0x5a4a32, 0.42);
    scene.add(this.hemi);
  }

  // register a material so it receives cascaded shadows.
  // `inject` is an optional extra onBeforeCompile (e.g. terrain splat / grass
  // wind) composed AFTER CSM's — CSM only adds uniforms, so string-replacing
  // standard chunks here is safe.
  setupMaterial(material, inject) {
    this.csm.setupMaterial(material);
    if (inject) {
      const base = material.onBeforeCompile;
      material.onBeforeCompile = (shader) => { base(shader); inject(shader); };
    }
  }

  update(camera) {
    camera.updateMatrixWorld();
    this.csm.update();
  }

  onResize(camera) {
    this.csm.updateFrustums();
  }
}
