// ===================================================================
// player.js — third-person character: rigged GLB with Idle/Walk/Run
// blend, gravity, jump, terrain-following ground collision.
// ===================================================================

import * as THREE from 'three';
import { CONFIG } from './config.js';

export class Player {
  constructor(scene, terrain, env, gltf) {
    this.terrain = terrain;
    this.cfg = CONFIG.player;

    this.root = new THREE.Group();
    this.root.position.set(0, terrain.heightAt(0, 0), 0);
    scene.add(this.root);

    const model = gltf.scene;
    model.traverse((o) => {
      if (o.isMesh) {
        o.castShadow = true;
        o.receiveShadow = true;
        o.frustumCulled = false; // skinned bounds can pop; keep visible
        if (o.material) env.setupMaterial(o.material);
      }
    });
    this.root.add(model);
    this.model = model;

    // animation blend setup
    this.mixer = new THREE.AnimationMixer(model);
    const byName = {};
    for (const clip of gltf.animations) byName[clip.name] = clip;
    this.actions = {
      idle: this._action(byName.Idle),
      walk: this._action(byName.Walk),
      run: this._action(byName.Run),
    };

    this.velY = 0;
    this.grounded = true;
    this.yaw = 0;        // facing
    this.speed = 0;      // planar speed (for camera fov / fx)
    this._tmpDir = new THREE.Vector3();
  }

  _action(clip) {
    if (!clip) return null;
    const a = this.mixer.clipAction(clip);
    a.play();
    a.setEffectiveWeight(0);
    return a;
  }

  get position() { return this.root.position; }

  update(dt, input, basis) {
    const c = this.cfg;
    const pos = this.root.position;

    // --- desired horizontal movement (camera-relative) ---
    const f = input.forward, s = input.strafe;
    const dir = this._tmpDir.set(0, 0, 0);
    if (f || s) {
      dir.addScaledVector(basis.forward, f);
      dir.addScaledVector(basis.right, s);
      dir.normalize();
    }
    const moving = dir.lengthSq() > 0.0001;
    const targetSpeed = moving ? (input.sprint ? c.runSpeed : c.walkSpeed) : 0;

    // smooth speed for nice anim/fov transitions
    this.speed += (targetSpeed - this.speed) * Math.min(1, dt * 10);

    if (moving) {
      pos.x += dir.x * this.speed * dt;
      pos.z += dir.z * this.speed * dt;
      // face travel direction (model forward = +Z)
      this.yaw = Math.atan2(dir.x, dir.z);
    }

    // turn the model smoothly toward yaw
    const cur = this.model.rotation.y;
    let diff = this.yaw - cur;
    diff = Math.atan2(Math.sin(diff), Math.cos(diff));
    this.model.rotation.y = cur + diff * c.turnLerp;

    // --- gravity + terrain collision ---
    this.velY += c.gravity * dt;
    pos.y += this.velY * dt;
    const ground = this.terrain.heightAt(pos.x, pos.z);
    if (pos.y <= ground) {
      pos.y = ground;
      this.velY = 0;
      this.grounded = true;
    } else {
      this.grounded = false;
    }
    if (this.grounded && input.jump) this.velY = c.jumpSpeed;

    // keep inside the world
    const lim = this.terrain.half - 2;
    pos.x = THREE.MathUtils.clamp(pos.x, -lim, lim);
    pos.z = THREE.MathUtils.clamp(pos.z, -lim, lim);

    this._blend(dt);
    this.mixer.update(dt);
  }

  // weight-blend idle/walk/run by planar speed
  _blend(dt) {
    const c = this.cfg;
    let wIdle = 0, wWalk = 0, wRun = 0;
    const sp = this.speed;
    if (sp < c.walkSpeed) {
      wWalk = THREE.MathUtils.clamp(sp / c.walkSpeed, 0, 1);
      wIdle = 1 - wWalk;
    } else {
      wRun = THREE.MathUtils.clamp((sp - c.walkSpeed) / (c.runSpeed - c.walkSpeed), 0, 1);
      wWalk = 1 - wRun;
    }
    const set = (a, w) => a && a.setEffectiveWeight(w);
    set(this.actions.idle, wIdle);
    set(this.actions.walk, wWalk);
    set(this.actions.run, wRun);
    // reduce foot sliding: scale locomotion playback with speed
    if (this.actions.walk) this.actions.walk.timeScale = THREE.MathUtils.clamp(sp / c.walkSpeed, 0.6, 1.4);
    if (this.actions.run) this.actions.run.timeScale = THREE.MathUtils.clamp(sp / c.runSpeed, 0.7, 1.3);
  }
}
