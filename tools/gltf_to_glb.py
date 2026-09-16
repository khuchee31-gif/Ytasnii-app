#!/usr/bin/env python3
"""`.gltf` (JSON + base64) → `.glb` (хоёртын сав).

ЯАГААД: Quaternius-ийн загварууд `.gltf` хэлбэрээр тархдаг бөгөөд
хоёртын өгөгдлөө base64-ээр ДОТРОО агуулдаг. base64 нь 33 % илүү зай
эзэлдэг. GLB нь яг ижил өгөгдлийг шууд хоёртоор хадгална — APK жижиг,
утсан дээр задлах нь хурдан.

    python3 tools/gltf_to_glb.py in.gltf out.glb
"""
from __future__ import annotations

import base64
import json
import struct
import sys
import urllib.parse

GLB_MAGIC = 0x46546C67
JSON_CHUNK = 0x4E4F534A
BIN_CHUNK = 0x004E4942


def _pad(data: bytes, fill: bytes) -> bytes:
    rem = (-len(data)) % 4
    return data + fill * rem


def convert(src: str, dst: str) -> tuple[int, int]:
    doc = json.load(open(src, encoding="utf-8"))
    blobs: list[bytes] = []
    for buf in doc.get("buffers", []):
        uri = buf.get("uri")
        if uri is None:
            raise SystemExit(f"{src}: буфер аль хэдийн хоёртын — GLB байх магадлалтай")
        if not uri.startswith("data:"):
            raise SystemExit(f"{src}: гадаад буфер дэмжигдэхгүй: {uri[:40]}")
        blobs.append(base64.b64decode(urllib.parse.unquote(uri.split(",", 1)[1])))

    # GLB нь ГАНЦ хоёртын хэсэгтэй. Олон буфертай бол нийлүүлж, шилжилтийг
    # нь дүрслэгч бүрт нэмнэ.
    merged = bytearray()
    offsets = []
    for b in blobs:
        offsets.append(len(merged))
        merged += b
        merged += b"\x00" * ((-len(b)) % 4)
    if len(blobs) > 1:
        for view in doc.get("bufferViews", []):
            idx = view.get("buffer", 0)
            view["byteOffset"] = view.get("byteOffset", 0) + offsets[idx]
            view["buffer"] = 0
    doc["buffers"] = [{"byteLength": len(merged)}]

    body = _pad(bytes(merged), b"\x00")
    head = _pad(json.dumps(doc, separators=(",", ":")).encode("utf-8"), b" ")
    total = 12 + 8 + len(head) + 8 + len(body)

    with open(dst, "wb") as fh:
        fh.write(struct.pack("<III", GLB_MAGIC, 2, total))
        fh.write(struct.pack("<II", len(head), JSON_CHUNK))
        fh.write(head)
        fh.write(struct.pack("<II", len(body), BIN_CHUNK))
        fh.write(body)
    return total, len(body)


if __name__ == "__main__":
    if len(sys.argv) != 3:
        print(__doc__)
        raise SystemExit(2)
    size, binsz = convert(sys.argv[1], sys.argv[2])
    print(f"{sys.argv[2]}: {size} bytes (bin {binsz})")
