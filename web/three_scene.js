import * as THREE from 'three';
import { RoundedBoxGeometry } from 'three/addons/geometries/RoundedBoxGeometry.js';

let renderer, scene, camera, animFrameId, cleanupFn;
let mouseX = 0, mouseY = 0;
const rects = [];

// Three placeholder rectangles — user will swap in render object screenshots later
const RECT_CONFIGS = [
  // Large rect, slightly left and back
  {
    // Square footprint to match the (535x535) thermostat screenshot's aspect
    // ratio 1:1, so `fitTextureCover` doesn't need to crop any of it.
    w: 3.14, h: 3.14, d: 0.08,
    x: -3.4, y: 0.4, z: -2.5,
    rx: 0.08, ry: 0.3, rz: -0.06,
    color: 0x4C85F5,
    emissive: 0x091530,
    sensitivity: 1.0,
    texture: 'images/nest-thermostat_paint.png',
  },
  // Medium rect, center-right and slightly forward
  {
    w: 2.8, h: 1.9, d: 0.08,
    x: 2.6, y: -0.5, z: -1.0,
    rx: -0.06, ry: -0.35, rz: 0.04,
    color: 0x2D5ED4,
    emissive: 0x060b1c,
    sensitivity: 0.75,
  },
  // Smaller rect, far right and behind
  {
    w: 2.0, h: 1.4, d: 0.08,
    x: 3.8, y: 1.8, z: -3.5,
    rx: 0.12, ry: -0.5, rz: -0.08,
    color: 0x5E91F6,
    emissive: 0x091530,
    sensitivity: 1.25,
  },
];

function initScene(container) {
  renderer = new THREE.WebGLRenderer({ antialias: true, alpha: true });
  renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
  renderer.setSize(container.clientWidth, container.clientHeight);
  renderer.toneMapping = THREE.ACESFilmicToneMapping;
  renderer.toneMappingExposure = 1.1;
  container.appendChild(renderer.domElement);
  renderer.domElement.style.cssText =
    'position:absolute;inset:0;width:100%;height:100%;pointer-events:none;';

  scene = new THREE.Scene();

  camera = new THREE.PerspectiveCamera(
    52, container.clientWidth / container.clientHeight, 0.1, 100
  );
  camera.position.set(0, 0, 9);

  // Ambient + two colored point lights
  scene.add(new THREE.AmbientLight(0xffffff, 0.4));

  const blueLight = new THREE.PointLight(0x7aa8f8, 80, 20);
  blueLight.position.set(-5, 4, 5);
  scene.add(blueLight);

  const deepBlueLight = new THREE.PointLight(0x4c85f5, 60, 18);
  deepBlueLight.position.set(5, -3, 4);
  scene.add(deepBlueLight);

  // Build the three rectangles
  const textureLoader = new THREE.TextureLoader();
  for (const cfg of RECT_CONFIGS) {
    const geo = new RoundedBoxGeometry(cfg.w, cfg.h, cfg.d, 4, 0.12);
    let mat;
    if (cfg.texture) {
      const tex = textureLoader.load(cfg.texture, (loaded) => fitTextureCover(loaded, cfg.w, cfg.h));
      tex.colorSpace = THREE.SRGBColorSpace;
      mat = new THREE.MeshStandardMaterial({
        map: tex,
        metalness: 0.08,
        roughness: 0.52,
      });
    } else {
      mat = new THREE.MeshStandardMaterial({
        color: cfg.color,
        emissive: cfg.emissive,
        emissiveIntensity: 0.38,
        metalness: 0.08,
        roughness: 0.52,
      });
    }
    const mesh = new THREE.Mesh(geo, mat);
    mesh.position.set(cfg.x, cfg.y, cfg.z);
    mesh.rotation.set(cfg.rx, cfg.ry, cfg.rz);

    mesh.userData = {
      baseRx: cfg.rx,
      baseRy: cfg.ry,
      sensitivity: cfg.sensitivity,
    };

    scene.add(mesh);
    rects.push(mesh);
  }

  // Mouse tracking for parallax
  function onMouseMove(e) {
    mouseX = (e.clientX / window.innerWidth - 0.5) * 2;
    mouseY = -(e.clientY / window.innerHeight - 0.5) * 2;
  }
  window.addEventListener('mousemove', onMouseMove);

  // Resize handler
  function onResize() {
    const w = container.clientWidth;
    const h = container.clientHeight;
    camera.aspect = w / h;
    camera.updateProjectionMatrix();
    renderer.setSize(w, h);
  }
  window.addEventListener('resize', onResize);

  cleanupFn = () => {
    window.removeEventListener('mousemove', onMouseMove);
    window.removeEventListener('resize', onResize);
  };

  animate();
}

function clamp(v, min, max) {
  return Math.max(min, Math.min(max, v));
}

// Crops a texture's UV rect to match the target box face's aspect ratio
// (like CSS `object-fit: cover`), so a non-matching source image isn't
// stretched when mapped onto the face.
function fitTextureCover(tex, boxW, boxH) {
  const img = tex.image;
  if (!img || !img.width || !img.height) return;
  const imgAspect = img.width / img.height;
  const boxAspect = boxW / boxH;
  if (boxAspect > imgAspect) {
    tex.repeat.set(1, imgAspect / boxAspect);
    tex.offset.set(0, (1 - tex.repeat.y) / 2);
  } else {
    tex.repeat.set(boxAspect / imgAspect, 1);
    tex.offset.set((1 - tex.repeat.x) / 2, 0);
  }
  tex.needsUpdate = true;
}

function animate() {
  animFrameId = requestAnimationFrame(animate);

  // Mouse drives a small, clamped rotation offset shared across all rects.
  // Max ±0.18 rad (~10°) so they never flip far from their resting pose.
  const MAX_ROT = 0.18;
  const targetRotX = clamp(-mouseY * 0.22, -MAX_ROT, MAX_ROT);
  const targetRotY = clamp( mouseX * 0.22, -MAX_ROT, MAX_ROT);

  for (const r of rects) {
    const ud = r.userData;
    const s = ud.sensitivity;
    // Lerp each rect's rotation toward (base + mouse offset × sensitivity)
    r.rotation.x += (ud.baseRx + targetRotX * s - r.rotation.x) * 0.06;
    r.rotation.y += (ud.baseRy + targetRotY * s - r.rotation.y) * 0.06;
  }

  renderer.render(scene, camera);
}

// Public API consumed by Dart via window
function realInitHeroScene(containerId) {
  const container = document.getElementById(containerId);
  if (!container) return;
  initScene(container);
}

function realDisposeHeroScene() {
  if (animFrameId) cancelAnimationFrame(animFrameId);
  if (renderer) {
    cleanupFn?.();
    renderer.dispose();
    renderer.domElement.remove();
    renderer = null;
  }
  scene = null;
  camera = null;
  rects.length = 0;
}

// Expose to window and drain any calls that arrived before this module loaded
window.initHeroScene = realInitHeroScene;
window.disposeHeroScene = realDisposeHeroScene;

if (Array.isArray(window._heroQueue)) {
  window._heroQueue.forEach(id => realInitHeroScene(id));
  window._heroQueue = null;
}
