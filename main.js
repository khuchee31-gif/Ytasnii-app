import * as THREE from "three";
import { EffectComposer } from "three/addons/postprocessing/EffectComposer.js";
import { RenderPass } from "three/addons/postprocessing/RenderPass.js";
import { UnrealBloomPass } from "three/addons/postprocessing/UnrealBloomPass.js";
import { OutputPass } from "three/addons/postprocessing/OutputPass.js";

const reduce = matchMedia("(prefers-reduced-motion: reduce)").matches;
const lerp = (a, b, t) => a + (b - a) * t;
document.body.classList.add("is-loading");

/* =========================================================
   1. SPLIT TEXT — wrap each char for staggered reveal
   ========================================================= */
document.querySelectorAll("[data-split]").forEach((el) => {
  const text = el.textContent;
  el.textContent = "";
  [...text].forEach((ch) => {
    const span = document.createElement("span");
    span.className = "char";
    span.textContent = ch === " " ? " " : ch;
    el.appendChild(span);
  });
});
document.querySelectorAll("[data-words]").forEach((el) => {
  el.innerHTML = el.textContent
    .trim().split(/\s+/)
    .map((w) => `<span class="word">${w}</span>`)
    .join(" ");
});

/* =========================================================
   2. CUSTOM CURSOR (trailing ring + label, hover states)
   ========================================================= */
const cursor = document.querySelector("[data-cursor]");
const cursorLabel = document.querySelector("[data-cursor-label]");
const dot = document.querySelector("[data-cursor-dot]");
const pointer = { x: innerWidth / 2, y: innerHeight / 2 };
const ring = { ...pointer };

addEventListener("pointermove", (e) => {
  pointer.x = e.clientX; pointer.y = e.clientY;
  if (dot) dot.style.transform = `translate(${e.clientX}px,${e.clientY}px) translate(-50%,-50%)`;
});
document.querySelectorAll("[data-hover]").forEach((el) => {
  el.addEventListener("pointerenter", () => {
    cursor?.classList.add("is-hover");
    const txt = el.getAttribute("data-cursor-text");
    if (txt && cursorLabel) { cursor.classList.add("is-text"); cursorLabel.textContent = txt; }
  });
  el.addEventListener("pointerleave", () => cursor?.classList.remove("is-hover", "is-text"));
});

/* =========================================================
   3. SMOOTH SCROLL (inertia) — translates inner wrapper
   ========================================================= */
const smooth = document.querySelector("[data-smooth-inner]");
const scrollState = { current: 0, target: 0, ease: 0.08 };
let docHeight = 0;

function setHeight() {
  docHeight = smooth.getBoundingClientRect().height;
  document.body.style.height = `${docHeight}px`;
}
setHeight();
addEventListener("resize", setHeight);

/* =========================================================
   4. SCROLL-DRIVEN: progress, reveal, words, counters, bento spotlight
   ========================================================= */
const progress = document.querySelector("[data-progress]");

const io = new IntersectionObserver((entries) => {
  entries.forEach((e) => { if (e.isIntersecting) { e.target.classList.add("is-visible"); io.unobserve(e.target); } });
}, { threshold: 0.15 });
document.querySelectorAll("[data-reveal]").forEach((el, i) => {
  el.style.transitionDelay = `${(i % 4) * 0.07}s`; io.observe(el);
});

// progressive word highlight (scrub)
const wordEls = [...document.querySelectorAll(".big-text .word")];
// animated counters
const counters = [...document.querySelectorAll("[data-count]")].map((el) => ({ el, to: +el.dataset.count, done: false }));
const countIO = new IntersectionObserver((entries) => {
  entries.forEach((e) => {
    if (!e.isIntersecting) return;
    const c = counters.find((x) => x.el === e.target);
    if (!c || c.done) return; c.done = true;
    const start = performance.now(), dur = 1600;
    const step = (now) => {
      const p = Math.min(1, (now - start) / dur);
      const eased = 1 - Math.pow(1 - p, 3);
      c.el.textContent = Math.round(c.to * eased);
      if (p < 1) requestAnimationFrame(step);
    };
    requestAnimationFrame(step);
  });
}, { threshold: 0.6 });
counters.forEach((c) => countIO.observe(c.el));

// bento spotlight follow
document.querySelectorAll("[data-tilt]").forEach((card) => {
  card.addEventListener("pointermove", (e) => {
    const r = card.getBoundingClientRect();
    const px = (e.clientX - r.left) / r.width - 0.5;
    const py = (e.clientY - r.top) / r.height - 0.5;
    card.style.setProperty("--mx", `${e.clientX - r.left}px`);
    card.style.setProperty("--my", `${e.clientY - r.top}px`);
    card.style.transform = `perspective(900px) rotateY(${px * 8}deg) rotateX(${-py * 8}deg) translateZ(12px)`;
  });
  card.addEventListener("pointerleave", () => (card.style.transform = ""));
});

/* =========================================================
   5. MAGNETIC BUTTONS
   ========================================================= */
document.querySelectorAll("[data-magnetic]").forEach((el) => {
  const strength = 0.4;
  el.addEventListener("pointermove", (e) => {
    const r = el.getBoundingClientRect();
    const x = e.clientX - r.left - r.width / 2;
    const y = e.clientY - r.top - r.height / 2;
    el.style.transform = `translate(${x * strength}px, ${y * strength}px)`;
  });
  el.addEventListener("pointerleave", () => (el.style.transform = ""));
});

/* =========================================================
   6. INFINITE MARQUEE
   ========================================================= */
const marquee = document.querySelector("[data-marquee]");
let marqX = 0;

/* =========================================================
   7. THREE.JS — shader blob + bloom
   ========================================================= */
const canvas = document.querySelector("[data-scene]");
const scene = new THREE.Scene();
const camera = new THREE.PerspectiveCamera(42, innerWidth / innerHeight, 0.1, 100);
camera.position.z = 6;

const renderer = new THREE.WebGLRenderer({ canvas, antialias: true, alpha: true });
renderer.setPixelRatio(Math.min(devicePixelRatio, 2));
renderer.setSize(innerWidth, innerHeight);

// --- GLSL: simplex noise (Ashima) + fresnel iridescent blob ---
const noiseGLSL = `
vec3 mod289(vec3 x){return x-floor(x*(1.0/289.0))*289.0;}
vec4 mod289(vec4 x){return x-floor(x*(1.0/289.0))*289.0;}
vec4 permute(vec4 x){return mod289(((x*34.0)+1.0)*x);}
vec4 taylorInvSqrt(vec4 r){return 1.79284291400159-0.85373472095314*r;}
float snoise(vec3 v){
  const vec2 C=vec2(1.0/6.0,1.0/3.0); const vec4 D=vec4(0.0,0.5,1.0,2.0);
  vec3 i=floor(v+dot(v,C.yyy)); vec3 x0=v-i+dot(i,C.xxx);
  vec3 g=step(x0.yzx,x0.xyz); vec3 l=1.0-g; vec3 i1=min(g.xyz,l.zxy); vec3 i2=max(g.xyz,l.zxy);
  vec3 x1=x0-i1+C.xxx; vec3 x2=x0-i2+C.yyy; vec3 x3=x0-D.yyy;
  i=mod289(i);
  vec4 p=permute(permute(permute(i.z+vec4(0.0,i1.z,i2.z,1.0))+i.y+vec4(0.0,i1.y,i2.y,1.0))+i.x+vec4(0.0,i1.x,i2.x,1.0));
  float n_=0.142857142857; vec3 ns=n_*D.wyz-D.xzx;
  vec4 j=p-49.0*floor(p*ns.z*ns.z);
  vec4 x_=floor(j*ns.z); vec4 y_=floor(j-7.0*x_);
  vec4 x=x_*ns.x+ns.yyyy; vec4 y=y_*ns.x+ns.yyyy; vec4 h=1.0-abs(x)-abs(y);
  vec4 b0=vec4(x.xy,y.xy); vec4 b1=vec4(x.zw,y.zw);
  vec4 s0=floor(b0)*2.0+1.0; vec4 s1=floor(b1)*2.0+1.0; vec4 sh=-step(h,vec4(0.0));
  vec4 a0=b0.xzyw+s0.xzyw*sh.xxyy; vec4 a1=b1.xzyw+s1.xzyw*sh.zzww;
  vec3 p0=vec3(a0.xy,h.x); vec3 p1=vec3(a0.zw,h.y); vec3 p2=vec3(a1.xy,h.z); vec3 p3=vec3(a1.zw,h.w);
  vec4 norm=taylorInvSqrt(vec4(dot(p0,p0),dot(p1,p1),dot(p2,p2),dot(p3,p3)));
  p0*=norm.x; p1*=norm.y; p2*=norm.z; p3*=norm.w;
  vec4 m=max(0.6-vec4(dot(x0,x0),dot(x1,x1),dot(x2,x2),dot(x3,x3)),0.0); m=m*m;
  return 42.0*dot(m*m,vec4(dot(p0,x0),dot(p1,x1),dot(p2,x2),dot(p3,x3)));
}`;

const uniforms = {
  uTime: { value: 0 },
  uMouse: { value: new THREE.Vector2(0, 0) },
  uScroll: { value: 0 },
  uColorA: { value: new THREE.Color(0xff3d20) },
  uColorB: { value: new THREE.Color(0x4d7dff) },
};

const blobMat = new THREE.ShaderMaterial({
  uniforms,
  vertexShader: noiseGLSL + `
    uniform float uTime; uniform vec2 uMouse; uniform float uScroll;
    varying vec3 vNormal; varying vec3 vView; varying float vNoise;
    void main(){
      vec3 p = position;
      float t = uTime * 0.35;
      float n = snoise(p * 1.1 + vec3(t));
      n += 0.5 * snoise(p * 2.3 - vec3(t * 1.4));
      float disp = n * (0.45 + length(uMouse) * 0.35 + uScroll * 0.3);
      p += normal * disp;
      vNoise = n;
      vNormal = normalize(normalMatrix * normal);
      vec4 mv = modelViewMatrix * vec4(p, 1.0);
      vView = normalize(-mv.xyz);
      gl_Position = projectionMatrix * mv;
    }`,
  fragmentShader: `
    uniform vec3 uColorA; uniform vec3 uColorB; uniform float uTime;
    varying vec3 vNormal; varying vec3 vView; varying float vNoise;
    void main(){
      float fres = pow(1.0 - max(dot(vNormal, vView), 0.0), 2.2);
      vec3 base = mix(uColorB, uColorA, smoothstep(-0.6, 0.6, vNoise));
      vec3 col = mix(vec3(0.02,0.02,0.03), base, fres * 1.4);
      col += fres * 0.6;
      gl_FragColor = vec4(col, 1.0);
    }`,
});

const blob = new THREE.Mesh(new THREE.IcosahedronGeometry(1.7, 64), blobMat);
scene.add(blob);

// wire halo
const halo = new THREE.LineSegments(
  new THREE.WireframeGeometry(new THREE.IcosahedronGeometry(2.4, 2)),
  new THREE.LineBasicMaterial({ color: 0xffffff, transparent: true, opacity: 0.06 })
);
scene.add(halo);

// particle field
const COUNT = 700;
const pos = new Float32Array(COUNT * 3);
for (let i = 0; i < COUNT * 3; i++) pos[i] = (Math.random() - 0.5) * 22;
const particles = new THREE.Points(
  new THREE.BufferGeometry().setAttribute("position", new THREE.BufferAttribute(pos, 3)),
  new THREE.PointsMaterial({ color: 0xffffff, size: 0.018, transparent: true, opacity: 0.5 })
);
scene.add(particles);

// --- Post-processing: bloom ---
const composer = new EffectComposer(renderer);
composer.addPass(new RenderPass(scene, camera));
const bloom = new UnrealBloomPass(new THREE.Vector2(innerWidth, innerHeight), 0.55, 0.5, 0.2);
composer.addPass(bloom);
composer.addPass(new OutputPass());

const mouse = { x: 0, y: 0 };
addEventListener("pointermove", (e) => {
  mouse.x = (e.clientX / innerWidth) * 2 - 1;
  mouse.y = (e.clientY / innerHeight) * 2 - 1;
});
addEventListener("resize", () => {
  camera.aspect = innerWidth / innerHeight; camera.updateProjectionMatrix();
  renderer.setSize(innerWidth, innerHeight); composer.setSize(innerWidth, innerHeight);
});

/* =========================================================
   8. MAIN LOOP
   ========================================================= */
const clock = new THREE.Clock();
function tick() {
  const t = clock.getElapsedTime();

  // smooth scroll integration
  scrollState.target = scrollY;
  scrollState.current = lerp(scrollState.current, scrollState.target, scrollState.ease);
  if (Math.abs(scrollState.target - scrollState.current) < 0.05) scrollState.current = scrollState.target;
  smooth.style.transform = `translate3d(0, ${-scrollState.current}px, 0)`;

  const max = docHeight - innerHeight || 1;
  const scrollN = Math.min(1, scrollState.current / max);
  if (progress) progress.style.width = `${scrollN * 100}%`;

  // progressive word highlight
  if (wordEls.length) {
    const section = document.querySelector(".section--about");
    const r = section.getBoundingClientRect();
    const prog = 1 - Math.min(1, Math.max(0, (r.bottom - innerHeight * 0.4) / r.height));
    const active = Math.floor(prog * wordEls.length * 1.3);
    wordEls.forEach((w, i) => w.classList.toggle("is-on", i < active));
  }

  // marquee
  if (marquee) { marqX = (marqX - 0.6) % (marquee.scrollWidth / 2); marquee.style.transform = `translateX(${marqX}px)`; }

  // cursor ring follow
  ring.x = lerp(ring.x, pointer.x, 0.18); ring.y = lerp(ring.y, pointer.y, 0.18);
  if (cursor) cursor.style.transform = `translate(${ring.x}px,${ring.y}px) translate(-50%,-50%)`;

  // shader uniforms
  uniforms.uTime.value = t;
  uniforms.uMouse.value.set(lerp(uniforms.uMouse.value.x, mouse.x, 0.05), lerp(uniforms.uMouse.value.y, mouse.y, 0.05));
  uniforms.uScroll.value = scrollN;

  // blob motion
  blob.rotation.y += 0.0025;
  blob.rotation.x = lerp(blob.rotation.x, mouse.y * 0.4, 0.04);
  blob.scale.setScalar(1 - scrollN * 0.35);
  blob.position.y = scrollN * 2.2;
  blob.position.x = lerp(blob.position.x, 1.4 + mouse.x * 0.4, 0.04);
  halo.rotation.copy(blob.rotation); halo.position.copy(blob.position); halo.scale.copy(blob.scale);

  particles.rotation.y = t * 0.02; particles.rotation.x = t * 0.01;

  camera.position.x = lerp(camera.position.x, mouse.x * 0.5, 0.04);
  camera.position.y = lerp(camera.position.y, -mouse.y * 0.5, 0.04);
  camera.lookAt(0, 0, 0);

  composer.render();
  requestAnimationFrame(tick);
}
tick();

/* =========================================================
   9. LOADER → reveal hero chars
   ========================================================= */
const loader = document.querySelector("[data-loader]");
const num = document.querySelector("[data-loader-num]");
const bar = document.querySelector("[data-loader-bar]");
let n = 0;
const counter = setInterval(() => {
  n = Math.min(100, n + Math.floor(Math.random() * 7) + 3);
  if (num) num.textContent = String(n).padStart(2, "0");
  if (bar) bar.style.width = `${n}%`;
  if (n >= 100) {
    clearInterval(counter);
    setTimeout(reveal, 500);
  }
}, 80);

function reveal() {
  loader?.classList.add("is-done");
  document.body.classList.remove("is-loading");
  // staggered char reveal
  const chars = document.querySelectorAll(".hero .char");
  chars.forEach((c, i) => {
    c.style.transition = "transform 1s var(--ease)";
    c.style.transitionDelay = `${0.3 + i * 0.02}s`;
    requestAnimationFrame(() => (c.style.transform = "translateY(0)"));
  });
}
