// ===================================================================
// input.js — keyboard + pointer-lock mouse-look (desktop)
//            + virtual joystick / drag-look / jump button (touch)
// Exposes one unified interface: forward / strafe / sprint / jump
// and consumeMouse() (camera delta), used the same way on both.
// ===================================================================

export class Input {
  constructor(domElement) {
    this.dom = domElement;
    this.keys = Object.create(null);
    this.mouseDX = 0;
    this.mouseDY = 0;
    this.locked = false;
    this._pressed = Object.create(null);

    // touch state (null on desktop)
    this.touchVec = null;
    this._touchSprint = false;
    this._touchJumpHeld = false;

    addEventListener('keydown', (e) => {
      const k = e.code;
      if (!this.keys[k]) this._pressed[k] = true;
      this.keys[k] = true;
      if (['Space', 'ShiftLeft', 'KeyW', 'KeyA', 'KeyS', 'KeyD'].includes(k)) e.preventDefault();
    });
    addEventListener('keyup', (e) => { this.keys[e.code] = false; });

    this.dom.addEventListener('click', () => {
      if (!this.isTouch && !this.locked) this.dom.requestPointerLock?.();
    });

    document.addEventListener('pointerlockchange', () => {
      this.locked = document.pointerLockElement === this.dom;
      document.body.classList.toggle('locked', this.locked);
    });

    document.addEventListener('mousemove', (e) => {
      if (!this.locked) return;
      this.mouseDX += e.movementX;
      this.mouseDY += e.movementY;
    });

    this.isTouch = matchMedia('(pointer: coarse)').matches || 'ontouchstart' in window;
    if (this.isTouch) this._setupTouch();
  }

  _setupTouch() {
    document.body.classList.add('touch');
    this.touchVec = { x: 0, y: 0 };

    const stick = document.querySelector('[data-stick]');
    const knob = document.querySelector('[data-knob]');
    const jumpBtn = document.querySelector('[data-jump]');
    const radius = 56;
    let moveId = null, lookId = null, origin = null, lookPrev = null;

    // jump button — its own touches, don't bubble into look/move
    const jDown = (e) => { this._touchJumpHeld = true; e.preventDefault(); e.stopPropagation(); };
    const jUp = () => { this._touchJumpHeld = false; };
    jumpBtn.addEventListener('touchstart', jDown, { passive: false });
    jumpBtn.addEventListener('touchend', jUp);
    jumpBtn.addEventListener('touchcancel', jUp);

    // bottom-left quadrant drives the joystick; anything else looks
    const inStickZone = (x, y) => x < innerWidth * 0.45 && y > innerHeight * 0.45;

    addEventListener('touchstart', (e) => {
      for (const t of e.changedTouches) {
        if (t.target === jumpBtn) continue;
        if (moveId === null && inStickZone(t.clientX, t.clientY)) {
          moveId = t.identifier;
          origin = { x: t.clientX, y: t.clientY };
          stick.style.left = t.clientX + 'px';
          stick.style.top = t.clientY + 'px';
          stick.classList.add('active');
        } else if (lookId === null) {
          lookId = t.identifier;
          lookPrev = { x: t.clientX, y: t.clientY };
        }
      }
    }, { passive: false });

    addEventListener('touchmove', (e) => {
      for (const t of e.changedTouches) {
        if (t.identifier === moveId) {
          const dx = t.clientX - origin.x, dy = t.clientY - origin.y;
          const len = Math.hypot(dx, dy);
          const m = Math.min(len, radius) / radius;
          const a = Math.atan2(dy, dx);
          knob.style.transform = `translate(${Math.cos(a) * m * radius}px, ${Math.sin(a) * m * radius}px)`;
          this.touchVec.x = Math.cos(a) * m;
          this.touchVec.y = Math.sin(a) * m;
          this._touchSprint = m > 0.8;
        } else if (t.identifier === lookId) {
          this.mouseDX += (t.clientX - lookPrev.x) * 0.7;
          this.mouseDY += (t.clientY - lookPrev.y) * 0.7;
          lookPrev = { x: t.clientX, y: t.clientY };
        }
      }
      e.preventDefault();
    }, { passive: false });

    const end = (e) => {
      for (const t of e.changedTouches) {
        if (t.identifier === moveId) {
          moveId = null; this.touchVec.x = 0; this.touchVec.y = 0; this._touchSprint = false;
          knob.style.transform = ''; stick.classList.remove('active');
        } else if (t.identifier === lookId) {
          lookId = null;
        }
      }
    };
    addEventListener('touchend', end);
    addEventListener('touchcancel', end);
  }

  // movement axes (keyboard + joystick combined)
  get forward() {
    return (this.keys.KeyW ? 1 : 0) - (this.keys.KeyS ? 1 : 0) - (this.touchVec ? this.touchVec.y : 0);
  }
  get strafe() {
    return (this.keys.KeyD ? 1 : 0) - (this.keys.KeyA ? 1 : 0) + (this.touchVec ? this.touchVec.x : 0);
  }
  get sprint() { return !!this.keys.ShiftLeft || this._touchSprint; }
  get jump() { return !!this.keys.Space || this._touchJumpHeld; }

  pressed(code) {
    if (this._pressed[code]) { this._pressed[code] = false; return true; }
    return false;
  }

  consumeMouse() {
    const d = { x: this.mouseDX, y: this.mouseDY };
    this.mouseDX = 0; this.mouseDY = 0;
    return d;
  }
}
