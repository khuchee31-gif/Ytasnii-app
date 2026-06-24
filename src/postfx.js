// ===================================================================
// postfx.js — cinematic EffectComposer stack:
//   SSAO → DoF (bokeh) → bloom → FXAA → motion blur →
//   custom grade (exposure + ACES + color grade + vignette + grain)
// Renderer tone mapping is disabled; the grade pass owns tone mapping.
// ===================================================================

import * as THREE from 'three';
import { EffectComposer } from 'three/addons/postprocessing/EffectComposer.js';
import { RenderPass } from 'three/addons/postprocessing/RenderPass.js';
import { ShaderPass } from 'three/addons/postprocessing/ShaderPass.js';
import { SSAOPass } from 'three/addons/postprocessing/SSAOPass.js';
import { BokehPass } from 'three/addons/postprocessing/BokehPass.js';
import { UnrealBloomPass } from 'three/addons/postprocessing/UnrealBloomPass.js';
import { AfterimagePass } from 'three/addons/postprocessing/AfterimagePass.js';
import { FXAAShader } from 'three/addons/shaders/FXAAShader.js';

const GradeShader = {
  uniforms: {
    tDiffuse: { value: null },
    uExposure: { value: 1.12 },
    uTime: { value: 0 },
    uResolution: { value: new THREE.Vector2(1, 1) },
    uVignette: { value: 1.15 },
    uGrain: { value: 0.04 },
    uSaturation: { value: 1.16 },
    uContrast: { value: 1.08 },
    uLift: { value: new THREE.Vector3(0.005, 0.004, 0.012) },
    uGain: { value: new THREE.Vector3(1.14, 1.0, 0.84) },
    uGamma: { value: new THREE.Vector3(0.97, 1.0, 1.05) },
  },
  vertexShader: /* glsl */`
    varying vec2 vUv;
    void main(){ vUv = uv; gl_Position = projectionMatrix * modelViewMatrix * vec4(position,1.0); }`,
  fragmentShader: /* glsl */`
    varying vec2 vUv;
    uniform sampler2D tDiffuse;
    uniform float uExposure, uTime, uVignette, uGrain, uSaturation, uContrast;
    uniform vec2 uResolution;
    uniform vec3 uLift, uGain, uGamma;

    vec3 ACESFilmic(vec3 x){
      float a=2.51,b=0.03,c=2.43,d=0.59,e=0.14;
      return clamp((x*(a*x+b))/(x*(c*x+d)+e),0.0,1.0);
    }
    vec3 toSRGB(vec3 c){
      return mix(1.055*pow(max(c,0.0),vec3(1.0/2.4))-0.055, c*12.92, step(c,vec3(0.0031308)));
    }
    float hash(vec2 p){ return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }

    void main(){
      vec3 col = texture2D(tDiffuse, vUv).rgb;

      // exposure + filmic tone mapping (HDR linear -> display)
      col *= uExposure;
      col = ACESFilmic(col);

      // lift / gamma / gain color grade
      col = col * uGain + uLift;
      col = pow(max(col, 0.0), uGamma);

      // contrast around mid grey
      col = (col - 0.5) * uContrast + 0.5;

      // saturation
      float luma = dot(col, vec3(0.2126, 0.7152, 0.0722));
      col = mix(vec3(luma), col, uSaturation);

      // vignette
      vec2 q = vUv - 0.5;
      float vig = 1.0 - dot(q, q) * uVignette;
      col *= clamp(vig, 0.0, 1.0);

      // film grain
      float g = hash(vUv * uResolution + uTime) - 0.5;
      col += g * uGrain;

      col = clamp(col, 0.0, 1.0);
      gl_FragColor = vec4(toSRGB(col), 1.0);
    }`,
};

export class PostFX {
  constructor(renderer, scene, camera) {
    this.renderer = renderer;
    this.scene = scene;
    this.camera = camera;
    renderer.toneMapping = THREE.NoToneMapping; // grade pass tone maps

    const size = renderer.getSize(new THREE.Vector2());
    const rt = new THREE.WebGLRenderTarget(size.x, size.y, {
      type: THREE.HalfFloatType,
      samples: 0,
    });
    this.composer = new EffectComposer(renderer, rt);
    this.composer.setPixelRatio(renderer.getPixelRatio());

    // base scene render (always on)
    this.renderPass = new RenderPass(scene, camera);
    this.composer.addPass(this.renderPass);

    // SSAO re-renders the scene compositing ambient occlusion on top.
    // It must follow a RenderPass (used as the composer's base render).
    this.ssao = new SSAOPass(scene, camera, size.x, size.y);
    this.ssao.kernelRadius = 0.9;
    this.ssao.minDistance = 0.002;
    this.ssao.maxDistance = 0.08;
    this.composer.addPass(this.ssao);

    // depth of field
    this.bokeh = new BokehPass(scene, camera, {
      focus: 6.0, aperture: 0.0008, maxblur: 0.006,
      width: size.x, height: size.y,
    });
    this.composer.addPass(this.bokeh);

    // bloom on bright highlights (sun, sky, rim light)
    this.bloom = new UnrealBloomPass(new THREE.Vector2(size.x, size.y), 0.45, 0.5, 0.85);
    this.composer.addPass(this.bloom);

    // anti-aliasing
    this.fxaa = new ShaderPass(FXAAShader);
    this.composer.addPass(this.fxaa);

    // subtle motion blur (trailing) — toggleable
    this.afterimage = new AfterimagePass(0.82);
    this.afterimage.enabled = false;
    this.composer.addPass(this.afterimage);

    // final cinematic grade (tone map + color + vignette + grain)
    this.grade = new ShaderPass(GradeShader);
    this.composer.addPass(this.grade);

    this.setSize(size.x, size.y, renderer.getPixelRatio());
  }

  setSize(w, h, pr) {
    this.composer.setSize(w, h);
    this.composer.setPixelRatio(pr);
    const rw = w * pr, rh = h * pr;
    this.ssao.setSize(w, h);
    this.bokeh.setSize?.(w, h);
    this.bloom.setSize(w, h);
    this.fxaa.material.uniforms.resolution.value.set(1 / rw, 1 / rh);
    this.grade.uniforms.uResolution.value.set(rw, rh);
  }

  // toggles
  toggle(name) {
    const map = {
      ssao: () => { this.ssao.enabled = !this.ssao.enabled; },
      dof: () => { this.bokeh.enabled = !this.bokeh.enabled; },
      bloom: () => { this.bloom.enabled = !this.bloom.enabled; },
      motionblur: () => { this.afterimage.enabled = !this.afterimage.enabled; },
    };
    map[name]?.();
  }

  render(dt, focusDistance) {
    this.grade.uniforms.uTime.value += dt;
    if (this.bokeh.enabled) {
      // keep the character in focus, blur the distance
      this.bokeh.uniforms['focus'].value = THREE.MathUtils.lerp(
        this.bokeh.uniforms['focus'].value, focusDistance, 0.1);
    }
    this.composer.render(dt);
  }
}
