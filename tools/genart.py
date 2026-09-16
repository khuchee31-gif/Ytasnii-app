#!/usr/bin/env python3
"""Дүрийн зураг үүсгэх шугам — Хот унтлаа.

ЯАГААД СКРИПТ ВЭ: зургууд нэг л удаа гараар үүсгэгддэг бол дахин давтагдахгүй.
Энд seed бүр тогтмол тул ЯМАР Ч ҮЕД ижил зураг дахин гарна. Загвар солигдоход
эсвэл хэв маягийг өөрчлөхөд бүх ассетыг нэг командаар дахин үүсгэнэ.

USAGE:  python3 tools/genart.py [--only seats|roles] [--force]

УСАН ТЭМДЭГ: үйлчилгээ доод баруун буланд лого тавьдаг. Тиймээс ЗОРИУД ИЛҮҮ
ӨНДРӨӨР үүсгээд доод зурвасыг таслаад хаяна — доорх `_WM_STRIP`.
"""
import argparse
import os
import sys
import time
import urllib.parse
import urllib.request

from PIL import Image
import io

OUT = os.path.join(os.path.dirname(__file__), '..', 'app', 'assets', 'art')
ENDPOINT = 'https://image.pollinations.ai/prompt/'

# Бүх зурганд НЭГ хэв маяг. Энэ мөр өөрчлөгдвөл БҮХ ассет дахин үүснэ.
STYLE = (
    'dark cinematic game character render, SOLID PURE BLACK BACKGROUND, '
    'subject fully isolated on black, dramatic rim light from above, '
    'deep black shadows, heavy film grain, muted palette of rust '
    'orange and bone white and cold teal, moody oppressive atmosphere, '
    'sharp focus on face, no text, no watermark, no logo, no background '
    'detail, studio darkness'
)

# Үүсгэх өндрөөс хэдэн хувийг доороос таслах вэ (усан тэмдэг тэнд).
_WM_STRIP = 0.20

# --- Суудлын хөрөг: ДҮРГҮЙ, саармаг. Дүр алдагдуулж БОЛОХГҮЙ. ---------------
# Бүгд ижил хувцас, ижил өнцөг, ижил гэрэл — зөвхөн царай нь ялгаатай.
SEAT_BASE = (
    'head and shoulders portrait of a mongolian high school student, '
    'plain dark school uniform, neutral calm expression, looking straight at '
    'camera, centered, nothing behind the subject, pure black void'
)
SEAT_VARIANTS = [
    'short black hair, round face',
    'long straight black hair, narrow face',
    'buzz cut, broad jaw',
    'shoulder length hair, freckles',
    'messy hair, thin face, glasses',
    'braided hair, high cheekbones',
    'side parted hair, soft features',
    'short wavy hair, strong brow',
    'ponytail, small nose',
    'cropped hair, square face',
    'curtain bangs, tired eyes',
    'shaved sides, sharp cheekbones',
]

# --- Дүрийн зураг: ЗӨВХӨН хөзрийн нүүрэнд, эзэн нь ганцаараа хардаг --------
ROLES = {
    # ЧУХАЛ: бүгд МОНГОЛ СУРАГЧ. Энэ бол ангийн тоглоом — барууны мафийн
    # хэвшмэл дүр (бүрхүүлтэй хүн, малгайтай гангстер) ЭНД БАЙХГҮЙ.
    # Аймшиг нь хувцаснаас биш, ТАНИЛ ХҮН гэдгээс нь гарна.
    'killer': 'a mongolian teenage student sitting at a classroom desk in '
              'darkness, face half lit from below, calm blank stare directly '
              'at the viewer, hands flat on the desk, school uniform, '
              'unsettling stillness',
    'boss': 'an older mongolian teenage student leaning back at the head of a '
            'classroom table, arms crossed, confident knowing half smile, '
            'school uniform with the collar open, one hard light from above',
    'doctor': 'a mongolian teenage student in a school uniform with a red '
              'cross armband, holding a small first aid tin, kind tired eyes, '
              'soft warm lamp light, classroom at night',
    'detective': 'a mongolian teenage student leaning over a classroom desk '
                 'covered in notes, pen in hand, sharp focused eyes looking '
                 'up at the viewer, single desk lamp, night classroom',
    'citizen': 'an ordinary mongolian teenage student sitting at a classroom '
               'desk, hands folded, worried uncertain expression, plain '
               'school uniform, dim overhead light',
}



def fetch(prompt: str, w: int, h: int, seed: int, tries: int = 3) -> Image.Image:
    """Нэг зураг татна. Амжилтгүй бол дахин оролдоно."""
    url = (ENDPOINT + urllib.parse.quote(prompt)
           + f'?width={w}&height={h}&seed={seed}&nologo=true&model=flux')
    last = None
    for attempt in range(tries):
        try:
            req = urllib.request.Request(url, headers={'User-Agent': 'hotuntlaa/1.0'})
            with urllib.request.urlopen(req, timeout=180) as r:
                data = r.read()
            img = Image.open(io.BytesIO(data))
            img.load()
            return img
        except Exception as e:                      # noqa: BLE001
            last = e
            time.sleep(2 * (attempt + 1))
    raise RuntimeError(f'зураг татаж чадсангүй ({tries} оролдлого): {last}')


# --- Дэвсгэр таслах ---------------------------------------------------------
#
# Зураг үүсгэгчээс «хар дэвсгэр» гэж гуйхад ТОГТВОРТОЙ АЖИЛЛАДАГГҮЙ: заримдаа
# саарал хана, заримдаа өрөө гарч ирнэ. Харанхуй тоглоомын өрөөнд тэр саарал
# дөрвөлжин нь МАНАН мэт тархаж, 12 дүр зэрэг зурагдахад дэлгэц бүхэлдээ
# бүдгэрч байв.
#
# Шийдэл: `rembg` (u2net) нь хүнийг дэвсгэрээс нь ЗӨВ тасална. Энэ нь зөвхөн
# БҮТЭЭХ үед ажиллана — апп дотор орохгүй, гаралт нь энгийн JPEG хэвээр.
#
# Суулгах:  pip install rembg onnxruntime
# Байхгүй бол зууван бүдгэрүүлэлт рүү шилжинэ — чанар муу ч ажиллана.

_SESSION = None
_REMBG_OK = None


def _rembg_session():
    global _SESSION, _REMBG_OK
    if _REMBG_OK is None:
        try:
            from rembg import new_session
            _SESSION = new_session('u2net')
            _REMBG_OK = True
        except Exception as e:                       # noqa: BLE001
            print(f'  (rembg байхгүй: {e}) — зууван маск ашиглана')
            _REMBG_OK = False
    return _SESSION


def _elliptic_matte(img, cx=0.5, cy=0.42, rx=0.50, ry=0.60):
    """Нөөц арга: зууван талбайн гадна харанхуйлна."""
    w, h = img.size
    px = img.load()
    if px is None:
        return img
    for y in range(h):
        ny = (y / h - cy) / ry
        for x in range(w):
            nx = (x / w - cx) / rx
            d = (nx * nx + ny * ny) ** 0.5
            if d <= 1.0:
                continue
            k = max(0.0, 1.0 - (d - 1.0) / 0.35) ** 2
            r, g, b = px[x, y][:3]
            px[x, y] = (int(r * k), int(g * k), int(b * k))
    return img


def cut_out(img):
    """Дэвсгэрийг арилгаж, ХАР болгоно.

    Тоглоомын өрөө хар учраас ил тод давхарга хэрэггүй — хар дэвсгэр төгс
    уусна, файл нь JPEG хэвээр жижиг үлдэнэ.
    """
    sess = _rembg_session()
    if sess is None:
        return _elliptic_matte(img.convert('RGB'))
    from rembg import remove
    cut = remove(img.convert('RGBA'), session=sess)
    out = Image.new('RGB', cut.size, (0, 0, 0))
    out.paste(cut, mask=cut.split()[3])
    return out


def make(prompt: str, seed: int, size: int, path: str, force: bool) -> bool:
    """Үүсгэж, усан тэмдгийг таслаад хадгална. Аль хэдийн байвал алгасна."""
    if os.path.exists(path) and not force:
        print(f'  алгасав (байна): {os.path.basename(path)}')
        return False
    # Усан тэмдгийг таслахын тулд ӨНДРӨӨР үүсгэнэ.
    gen_h = int(size / (1.0 - _WM_STRIP))
    img = fetch(f'{prompt}. {STYLE}', size, gen_h, seed)
    w, h = img.size
    img = img.crop((0, 0, w, int(h * (1.0 - _WM_STRIP))))
    img = img.convert('RGB').resize((size, size), Image.LANCZOS)
    img = cut_out(img)
    img.save(path, 'JPEG', quality=88, optimize=True)
    print(f'  ✓ {os.path.basename(path)}  {os.path.getsize(path)//1024} KB')
    return True


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument('--only', choices=['seats', 'roles'])
    ap.add_argument('--force', action='store_true')
    a = ap.parse_args()

    os.makedirs(os.path.join(OUT, 'seats'), exist_ok=True)
    os.makedirs(os.path.join(OUT, 'roles'), exist_ok=True)

    if a.only != 'roles':
        print('Суудлын хөрөг (саармаг, дүр алдагдуулахгүй):')
        for i, v in enumerate(SEAT_VARIANTS, start=1):
            make(f'{SEAT_BASE}, {v}', seed=1000 + i, size=320,
                 path=os.path.join(OUT, 'seats', f'seat{i:02d}.jpg'),
                 force=a.force)

    if a.only != 'seats':
        print('Дүрийн зураг (зөвхөн хөзрийн нүүрэнд):')
        for i, (k, p) in enumerate(ROLES.items()):
            make(p, seed=2000 + i, size=512,
                 path=os.path.join(OUT, 'roles', f'{k}.jpg'), force=a.force)

    return 0


if __name__ == '__main__':
    sys.exit(main())
