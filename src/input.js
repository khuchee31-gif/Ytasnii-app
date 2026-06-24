// ===================================================================
// input.js — keyboard + pointer-lock mouse-look state
// ===================================================================

export class Input {
  constructor(domElement) {
    this.dom = domElement;
    this.keys = Object.create(null);
    this.mouseDX = 0;
    this.mouseDY = 0;
    this.locked = false;

    // toggle flags consumed once per frame
    this._pressed = Object.create(null);

    addEventListener('keydown', (e) => {
      const k = e.code;
      if (!this.keys[k]) this._pressed[k] = true;
      this.keys[k] = true;
      if (['Space', 'ShiftLeft', 'KeyW', 'KeyA', 'KeyS', 'KeyD'].includes(k)) e.preventDefault();
    });
    addEventListener('keyup', (e) => { this.keys[e.code] = false; });

    this.dom.addEventListener('click', () => {
      if (!this.locked) this.dom.requestPointerLock?.();
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
  }

  // movement axes relative to facing
  get forward() { return (this.keys.KeyW ? 1 : 0) - (this.keys.KeyS ? 1 : 0); }
  get strafe()  { return (this.keys.KeyD ? 1 : 0) - (this.keys.KeyA ? 1 : 0); }
  get sprint()  { return !!this.keys.ShiftLeft; }
  get jump()    { return !!this.keys.Space; }

  // returns true exactly once per physical key press
  pressed(code) {
    if (this._pressed[code]) { this._pressed[code] = false; return true; }
    return false;
  }

  // consume accumulated mouse delta for this frame
  consumeMouse() {
    const d = { x: this.mouseDX, y: this.mouseDY };
    this.mouseDX = 0; this.mouseDY = 0;
    return d;
  }
}
