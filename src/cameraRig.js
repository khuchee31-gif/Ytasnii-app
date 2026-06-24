// ===================================================================
// cameraRig.js — over-the-shoulder third-person camera.
// Pointer-lock mouse look, smoothed follow, terrain collision pull-in.
// ===================================================================

import * as THREE from 'three';
import { CONFIG } from './config.js';

export class CameraRig {
  constructor(camera, terrain) {
    this.camera = camera;
    this.terrain = terrain;
    this.cfg = CONFIG.camera;

    this.yaw = Math.PI;     // start looking toward -Z (across the valley)
    this.pitch = 0.12;
    this.distance = this.cfg.distance;

    this.target = new THREE.Vector3();
    this.desired = new THREE.Vector3();
    this.curPos = new THREE.Vector3();

    this.forward = new THREE.Vector3(0, 0, -1);
    this.right = new THREE.Vector3(1, 0, 0);
    this._euler = new THREE.Euler(0, 0, 0, 'YXZ');
    this._ray = new THREE.Raycaster();
    this._initialized = false;
  }

  applyMouse(input) {
    const d = input.consumeMouse();
    this.yaw -= d.x * this.cfg.sensitivity;
    this.pitch -= d.y * this.cfg.sensitivity;
    this.pitch = THREE.MathUtils.clamp(this.pitch, this.cfg.minPitch, this.cfg.maxPitch);

    this._euler.set(this.pitch, this.yaw, 0);
    this.forward.set(0, 0, -1).applyEuler(this._euler);

    // horizontal movement basis
    const fh = this.forward.clone(); fh.y = 0; fh.normalize();
    this.forward.copy(fh); // expose flattened forward for movement
    this.right.set(fh.z, 0, -fh.x);
  }

  getMoveBasis() { return { forward: this.forward, right: this.right }; }

  follow(playerPos, dt) {
    const c = this.cfg;
    // aim point: shoulder height, slightly offset toward camera-right
    this.target.copy(playerPos);
    this.target.y += c.height;
    this.target.addScaledVector(this.right, 0.5);

    // full look direction (with pitch) for the orbit offset
    this._euler.set(this.pitch, this.yaw, 0);
    const look = new THREE.Vector3(0, 0, -1).applyEuler(this._euler);

    this.desired.copy(this.target).addScaledVector(look, -this.distance);

    // terrain collision: pull camera in if ground blocks the view
    const dir = this.desired.clone().sub(this.target);
    const len = dir.length();
    dir.normalize();
    this._ray.set(this.target, dir);
    this._ray.far = len;
    const hit = this._ray.intersectObject(this.terrain.mesh, false);
    let dist = len;
    if (hit.length) dist = Math.max(c.minDistance, hit[0].distance - 0.3);
    this.desired.copy(this.target).addScaledVector(dir, dist);

    // keep camera above terrain everywhere
    const gy = this.terrain.heightAt(this.desired.x, this.desired.z) + 0.4;
    if (this.desired.y < gy) this.desired.y = gy;

    if (!this._initialized) { this.curPos.copy(this.desired); this._initialized = true; }
    this.curPos.lerp(this.desired, 1 - Math.pow(1 - c.lerp, dt * 60));

    this.camera.position.copy(this.curPos);
    this.camera.lookAt(this.target);
  }
}
