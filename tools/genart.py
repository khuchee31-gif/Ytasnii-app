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
    'dark cinematic game art, harsh single overhead light source, deep black '
    'shadows, heavy film grain, desaturated muted palette of rust orange and '
    'bone white and cold teal, plain near-black background, moody oppressive '
    'atmosphere, sharp focus on face, no text, no watermark, no logo'
)

# Үүсгэх өндрөөс хэдэн хувийг доороос таслах вэ (усан тэмдэг тэнд).
_WM_STRIP = 0.20

# --- Суудлын хөрөг: ДҮРГҮЙ, саармаг. Дүр алдагдуулж БОЛОХГҮЙ. ---------------
# Бүгд ижил хувцас, ижил өнцөг, ижил гэрэл — зөвхөн царай нь ялгаатай.
SEAT_BASE = (
    'head and shoulders portrait of a mongolian high school student, '
    'plain dark school uniform, neutral calm expression, looking straight at '
    'camera, centered, night classroom background'
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
            make(f'{SEAT_BASE}, {v}', seed=1000 + i, size=256,
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
