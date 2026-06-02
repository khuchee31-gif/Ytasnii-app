import * as THREE from "three";

/* =========================================================
   1. CUSTOM CURSOR (mouse follower + hover state)
   ========================================================= */
const cursor = document.querySelector("[data-cursor]");
const dot = document.querySelector("[data-cursor-dot]");
const pointer = { x: innerWidth / 2, y: innerHeight / 2 };
const ring = { x: pointer.x, y: pointer.y };

addEventListener("pointermove", (e) => {
  pointer.x = e.clientX;
  pointer.y = e.clientY;
  // dot moves instantly, ring lerps for smooth trailing feel
  if (dot) dot.style.transform = `translate(${e.clientX}px, ${e.clientY}px) translate(-50%,-50%)`;
});

document.querySelectorAll("[data-hover]").forEach((el) => {
  el.addEventListener("pointerenter", () => cursor?.classList.add("is-hover"));
  el.addEventListener("pointerleave", () => cursor?.classList.remove("is-hover"));
});

/* =========================================================
   2. SCROLL: progress bar + reveal-on-scroll
   ========================================================= */
const progress = document.querySelector("[data-progress]");
const onScroll = () => {
  const max = document.body.scrollHeight - innerHeight;
  const p = max > 0 ? scrollY / max : 0;
  if (progress) progress.style.width = `${p * 100}%`;
};
addEventListener("scroll", onScroll, { passive: true });
onScroll();

const io = new IntersectionObserver(
  (entries) => {
    entries.forEach((entry) => {
      if (entry.isIntersecting) {
        entry.target.classList.add("is-visible");
        io.unobserve(entry.target);
      }
    });
  },
  { threshold: 0.15 }
);
document.querySelectorAll("[data-reveal]").forEach((el, i) => {
  el.style.transitionDelay = `${(i % 4) * 0.08}s`;
  io.observe(el);
});

/* =========================================================
   3. CARD TILT (cursor-reactive 3D tilt)
   ========================================================= */
document.querySelectorAll("[data-tilt]").forEach((card) => {
  card.addEventListener("pointermove", (e) => {
    const r = card.getBoundingClientRect();
    const px = (e.clientX - r.left) / r.width - 0.5;
    const py = (e.clientY - r.top) / r.height - 0.5;
    card.style.transform = `perspective(800px) rotateY(${px * 12}deg) rotateX(${-py * 12}deg) translateZ(10px)`;
  });
  card.addEventListener("pointerleave", () => {
    card.style.transform = "";
  });
});

/* =========================================================
   4. THREE.JS — 3D asset reacting to mouse + scroll
   ========================================================= */
const canvas = document.querySelector("[data-scene]");
const scene = new THREE.Scene();

const camera = new THREE.PerspectiveCamera(45, innerWidth / innerHeight, 0.1, 100);
camera.position.z = 6;

const renderer = new THREE.WebGLRenderer({ canvas, antialias: true, alpha: true });
renderer.setPixelRatio(Math.min(devicePixelRatio, 2));
renderer.setSize(innerWidth, innerHeight);

// --- Lighting ---
scene.add(new THREE.AmbientLight(0xffffff, 0.4));
const key = new THREE.DirectionalLight(0xff4d2e, 2.5);
key.position.set(4, 4, 5);
scene.add(key);
const rim = new THREE.DirectionalLight(0x4d7dff, 1.5);
rim.position.set(-5, -2, 3);
scene.add(rim);

// --- Hero object: faceted icosahedron ---
const geo = new THREE.IcosahedronGeometry(1.6, 0);
const mat = new THREE.MeshStandardMaterial({
  color: 0x111114,
  metalness: 0.9,
  roughness: 0.2,
  flatShading: true,
});
const mesh = new THREE.Mesh(geo, mat);
scene.add(mesh);

// --- Wireframe overlay for that "studio" look ---
const wire = new THREE.LineSegments(
  new THREE.WireframeGeometry(geo),
  new THREE.LineBasicMaterial({ color: 0xff4d2e, transparent: true, opacity: 0.25 })
);
mesh.add(wire);

// --- Particle field ---
const COUNT = 600;
const positions = new Float32Array(COUNT * 3);
for (let i = 0; i < COUNT * 3; i++) positions[i] = (Math.random() - 0.5) * 20;
const particles = new THREE.Points(
  new THREE.BufferGeometry().setAttribute("position", new THREE.BufferAttribute(positions, 3)),
  new THREE.PointsMaterial({ color: 0xffffff, size: 0.02, transparent: true, opacity: 0.6 })
);
scene.add(particles);

// --- Resize ---
addEventListener("resize", () => {
  camera.aspect = innerWidth / innerHeight;
  camera.updateProjectionMatrix();
  renderer.setSize(innerWidth, innerHeight);
});

// --- Mouse parallax target (normalized -1..1) ---
const mouse = { x: 0, y: 0 };
addEventListener("pointermove", (e) => {
  mouse.x = (e.clientX / innerWidth) * 2 - 1;
  mouse.y = (e.clientY / innerHeight) * 2 - 1;
});

// --- Animation loop ---
const clock = new THREE.Clock();
function tick() {
  const t = clock.getElapsedTime();

  // smooth cursor ring follow (lerp)
  ring.x += (pointer.x - ring.x) * 0.15;
  ring.y += (pointer.y - ring.y) * 0.15;
  if (cursor) cursor.style.transform = `translate(${ring.x}px, ${ring.y}px) translate(-50%,-50%)`;

  // mesh idle spin + mouse reactive rotation
  mesh.rotation.y += 0.003;
  mesh.rotation.x += (mouse.y * 0.5 - mesh.rotation.x) * 0.05;
  mesh.rotation.z += (mouse.x * 0.3 - mesh.rotation.z) * 0.05;

  // scroll-driven scale & vertical drift
  const scrollN = scrollY / (document.body.scrollHeight - innerHeight || 1);
  mesh.scale.setScalar(1 - scrollN * 0.4);
  mesh.position.y = scrollN * 3;
  mesh.position.x = scrollN * 2;

  // particle slow rotation
  particles.rotation.y = t * 0.02;
  particles.rotation.x = t * 0.01;

  // camera subtle parallax toward cursor
  camera.position.x += (mouse.x * 0.6 - camera.position.x) * 0.05;
  camera.position.y += (-mouse.y * 0.6 - camera.position.y) * 0.05;
  camera.lookAt(0, 0, 0);

  renderer.render(scene, camera);
  requestAnimationFrame(tick);
}
tick();

/* =========================================================
   5. LOADER (counts to 100, then reveals)
   ========================================================= */
const loader = document.querySelector("[data-loader]");
const num = document.querySelector("[data-loader-num]");
let n = 0;
const counter = setInterval(() => {
  n = Math.min(100, n + Math.floor(Math.random() * 8) + 2);
  if (num) num.textContent = n;
  if (n >= 100) {
    clearInterval(counter);
    setTimeout(() => loader?.classList.add("is-done"), 400);
  }
}, 80);
