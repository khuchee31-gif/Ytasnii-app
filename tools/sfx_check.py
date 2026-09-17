#!/usr/bin/env python3
# Синтезлэсэн дууг ХЭМЖИНЭ.
#
# Толгойгүй серверт дуут төхөөрөмж байхгүй тул дууг СОНСОХ боломжгүй.
# Гэхдээ долгионыг хэмжиж болно: урт, оргил, RMS, спектрийн төв,
# тэг гаталт. Эдгээр нь «чимээгүй», «хазсан», «зөвхөн шуугиан» гэсэн
# гурван нийтлэг алдааг барина.
#
#   tools/render.sh -- demo=1 sfxdump=1 hold=0.5 out=sfx.png
#   python3 tools/sfx_check.py

import math
import pathlib
import sys
import wave

import numpy as np

DIR = pathlib.Path(__file__).resolve().parent.parent / "game" / "shots" / "sfx"

# Дуу бүрийн ХҮЛЭЭГДЭЖ БУЙ шинж. `lo`/`hi` нь спектрийн төвийн (Гц)
# хүрээ — «энэ дуу нам уу, өндөр үү» гэдгийг барина.
WANT = {
    "room":      (3.5, 4.5, 30, 700),
    "night":     (1.5, 2.2, 30, 600),
    "dawn":      (2.0, 2.8, 150, 900),
    "tap":       (0.03, 0.12, 1200, 5000),
    "select":    (0.10, 0.25, 150, 2500),
    # Түгжээний «так» нь ГЭГЭЭТЭЙ байх ЁСТОЙ — 3400 Гц-ийн товшилт нь
    # дуунд «төмөр» шинж өгдөг. Хэмжсэн: 3019 Гц.
    "lock":      (0.35, 0.60, 2200, 3800),
    "death":     (1.5, 2.2, 40, 900),
    # Хоёр шатат 1250 Гц-ийн шүүлтүүрийн ОНОЛЫН төв нь 1539 Гц
    # (numpy-аар тооцсон). Түүнээс дээш гарвал `_wav`-ын хувьчлал
    # эвдэрч, шүүлтүүрийн ажил устсан гэсэн үг.
    "whisper":   (1.0, 1.6, 900, 2000),
    "heart":     (0.8, 1.1, 30, 300),
    # Цаасны шувтралт нь бүр илүү гэгээтэй: зурвасын төв 5 кГц хүртэл
    # гулсдаг. Хэмжсэн: 6106 Гц.
    "card":      (0.20, 0.40, 4500, 7500),
    "win_town":  (1.5, 2.0, 200, 1200),
    "win_mafia": (1.8, 2.3, 100, 1200),
    "emote":     (0.08, 0.20, 300, 1600),
    "tick":      (0.02, 0.10, 1500, 7000),
    "deny":      (0.20, 0.35, 150, 1800),
}


def centroid(x, rate):
    """Спектрийн төв — «өнгө»-ний нэг тоон хэмжүүр."""
    w = np.abs(np.fft.rfft(x * np.hanning(len(x))))
    f = np.fft.rfftfreq(len(x), 1.0 / rate)
    s = w.sum()
    return float((w * f).sum() / s) if s > 0 else 0.0


def loops(report: pathlib.Path):
    """`SFXLOOP` мөрүүдийг уншиж давталтын хилийг шалгана.

    ЯАГААД ЭНД ХЭРЭГТЭЙ ВЭ: .wav файл нь давталтын мэдээллийг авч
    явдаггүй тул долгионоос үүнийг мэдэх боломжгүй. Godot-ийн
    `loop_end` нь дээжийн ТОО биш, СҮҮЛЧИЙН ИНДЕКС — хэтэрвэл холигч
    буферээс гадуур уншина. Энэ серверт дуут төхөөрөмж байхгүй тул
    холигч ажилладаггүй бөгөөд алдаа нь ЗӨВХӨН УТСАН дээр илэрнэ.
    Нэг удаа ингэж хохирсон.
    """
    bad = []
    seen = 0
    if not report.is_file():
        return ["SFXLOOP бүртгэл алга: %s" % report], 0
    for line in report.read_text(encoding="utf-8", errors="replace").splitlines():
        if not line.startswith("SFXLOOP "):
            continue
        seen += 1
        parts = dict(p.split("=", 1) for p in line.split()[2:] if "=" in p)
        name = line.split()[1]
        mode = int(parts.get("mode", 0))
        end = int(parts.get("end", 0))
        frames = int(parts.get("frames", 0))
        if mode != 0 and end >= frames:
            bad.append("%s: loop_end %d нь %d дээжийн хилээс хэтэрсэн"
                       % (name, end, frames))
    return bad, seen


def main() -> int:
    if not DIR.is_dir():
        print("sfx хавтас алга: эхлээд sfxdump=1-ээр гаргана уу")
        return 1
    bad = []
    for path in sorted(DIR.glob("*.wav")):
        name = path.stem
        with wave.open(str(path)) as w:
            rate = w.getframerate()
            n = w.getnframes()
            raw = w.readframes(n)
        x = np.frombuffer(raw, dtype="<i2").astype(np.float64) / 32768.0
        sec = n / rate
        peak = float(np.abs(x).max()) if n else 0.0
        rms = float(np.sqrt((x * x).mean())) if n else 0.0
        c = centroid(x, rate) if n else 0.0
        # Хазалт: 32000-аас дээш дээж хэдэн хувь вэ.
        clip = float((np.abs(x) > 0.985).mean())
        print(f"{name:10s} {sec:5.2f}с  оргил={peak:.3f} rms={rms:.4f} "
              f"төв={c:7.1f}Гц хаз={clip*100:.2f}%")

        if name not in WANT:
            bad.append(f"{name}: WANT дотор байхгүй")
            continue
        lo_s, hi_s, lo_c, hi_c = WANT[name]
        if not (lo_s <= sec <= hi_s):
            bad.append(f"{name}: урт {sec:.2f}с нь [{lo_s},{hi_s}] дотор биш")
        if peak < 0.25:
            bad.append(f"{name}: оргил {peak:.3f} — хэт нам, сонсогдохгүй")
        if rms < 0.008:
            bad.append(f"{name}: rms {rms:.4f} — бараг чимээгүй")
        if clip > 0.02:
            bad.append(f"{name}: {clip*100:.1f}% хазсан — гажилт сонсогдоно")
        if not (lo_c <= c <= hi_c):
            bad.append(f"{name}: төв {c:.0f}Гц нь [{lo_c},{hi_c}] дотор биш")

    loop_bad, loop_seen = loops(pathlib.Path("/tmp/sfxdump.log"))
    print("\nдавталтын шалгалт: %d дуу" % loop_seen)
    bad.extend(loop_bad)
    if loop_seen == 0:
        bad.append("SFXLOOP мөр олдсонгүй — гаралтыг /tmp/sfxdump.log руу "
                   "чиглүүлсэн эсэхээ шалгана уу")

    missing = set(WANT) - {p.stem for p in DIR.glob("*.wav")}
    for m in sorted(missing):
        bad.append(f"{m}: дуу гараагүй")

    print()
    if bad:
        for b in bad:
            print("АЛДАА:", b)
        return 1
    print("БҮГД ЗӨВ — %d дуу" % len(WANT))
    return 0


if __name__ == "__main__":
    sys.exit(main())
