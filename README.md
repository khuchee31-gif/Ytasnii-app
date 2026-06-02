# Ytasnii · Immersive Studio

Omma-гийн стилээр хийсэн **3D asset, scroll animation, cursor interaction** бүхий
орчин үеийн dark-theme вэб туршлага. Build хэрэггүй — цэвэр HTML/CSS/JS + Three.js (CDN).

## Онцлог
- 🎯 **Custom cursor** — хулгана дагаж гүйх ба hover үед өргөсдөг (touch төхөөрөмж дээр автоматаар нуугдана)
- 🧊 **3D asset** — Three.js icosahedron + wireframe + particle field, хулгана/scroll-д урвадаг
- 🌀 **Scroll animation** — reveal-on-scroll, progress bar, 3D объектын масштаб/хөдөлгөөн
- 🃏 **Card tilt** — карт дээр хулгана хөдөлгөхөд 3D налуу эффект
- ⏳ **Loader** — 0→100 тоолох эхлэлийн дэлгэц

## Ажиллуулах
Зүгээр л локал сервер дээр нээнэ (ES module-д сервер шаардлагатай):

```bash
# Python
python3 -m http.server 8000
# дараа нь http://localhost:8000 руу орно
```

Эсвэл VS Code дээр "Live Server" extension ашиглаж болно.

## Бүтэц
- `index.html` — бүтэц, контент, importmap
- `style.css` — dark theme, layout, анимацууд
- `main.js` — cursor, scroll, tilt, Three.js scene

## Дараагийн алхам (AI-тай ярилцаж гүнзгийрүүлэх)
Omma-гийн зөвлөмжийн дагуу нарийн анимац/объектыг чаттаар нэмж болно. Жишээ нь:
- "3D объектыг GLTF загвараар солих"
- "Scroll-д текст дагаж гарч ирэх timeline нэмэх"
- "Өнгөний палитрыг өөрчлөх"
