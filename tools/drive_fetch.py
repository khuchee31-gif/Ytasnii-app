#!/usr/bin/env python3
"""Нийтэд нээлттэй Google Drive хавтсыг жагсааж, файл татна.

ЯАГААД ХЭРЭГТЭЙ: Quaternius-ийн CC0 загварын багцууд itch.io биш,
Google Drive дээр тавигдсан. API түлхүүр шаардлагагүй — хавтасны HTML
хуудсанд файлын жагсаалт `_DRIVE_ivd` хувьсагчид шууд суулгагдсан
байдаг. Түүнийг задалж уншина.

    python3 tools/drive_fetch.py ls  <folder_id>
    python3 tools/drive_fetch.py get <file_id> <out_path>
"""
from __future__ import annotations

import codecs
import json
import re
import sys
import urllib.parse
import urllib.request

UA = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120 Safari/537.36"
FOLDER_MIME = "application/vnd.google-apps.folder"


def _open(url: str):
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    return urllib.request.urlopen(req, timeout=90)


def list_folder(folder_id: str) -> list[dict]:
    """[{id, name, mime, size}] буцаана. Дэд хавтас ч орно."""
    url = f"https://drive.google.com/drive/folders/{folder_id}"
    html = _open(url).read().decode("utf-8", "replace")
    m = re.search(r"_DRIVE_ivd'\]\s*=\s*'([^']+)'", html)
    if not m:
        return []
    data = json.loads(codecs.decode(m.group(1), "unicode_escape"))
    out = []
    for row in data[0]:
        # row: [id, [parent_ids], name, mime, ..., size?]
        try:
            size = int(row[13]) if len(row) > 13 and str(row[13]).isdigit() else 0
        except (TypeError, ValueError):
            size = 0
        out.append({"id": row[0], "name": row[2], "mime": row[3], "size": size})
    return out


def walk(folder_id: str, depth: int = 0, limit: int = 3):
    """Хавтсыг мөчиртэй нь дүрсэлнэ."""
    for e in list_folder(folder_id):
        yield depth, e
        if e["mime"] == FOLDER_MIME and depth < limit:
            yield from walk(e["id"], depth + 1, limit)


def download(file_id: str, out: str) -> int:
    """Нэг файл татна. Том файлд Drive «вирус шалгаагүй» баталгаа
    гуйдаг тул токеныг нь барьж, дахин хүснэ."""
    url = f"https://drive.google.com/uc?export=download&id={file_id}"
    r = _open(url)
    body = r.read()
    head = body[:800].decode("utf-8", "replace")
    if "confirm=" in head or "download_warning" in head:
        page = body.decode("utf-8", "replace")
        tok = re.search(r'name="confirm"\s+value="([^"]+)"', page)
        uuid = re.search(r'name="uuid"\s+value="([^"]+)"', page)
        params = {"export": "download", "id": file_id}
        if tok:
            params["confirm"] = tok.group(1)
        if uuid:
            params["uuid"] = uuid.group(1)
        url2 = "https://drive.usercontent.google.com/download?" + urllib.parse.urlencode(params)
        body = _open(url2).read()
    with open(out, "wb") as fh:
        fh.write(body)
    return len(body)


def main() -> int:
    if len(sys.argv) < 3:
        print(__doc__)
        return 2
    cmd = sys.argv[1]
    if cmd == "ls":
        for depth, e in walk(sys.argv[2], limit=int(sys.argv[3]) if len(sys.argv) > 3 else 2):
            kind = "DIR " if e["mime"] == FOLDER_MIME else "    "
            print(f"{'  ' * depth}{kind}{e['name']:<52} {e['size']:>10}  {e['id']}")
        return 0
    if cmd == "get":
        n = download(sys.argv[2], sys.argv[3])
        print(f"{n} bytes -> {sys.argv[3]}")
        return 0
    print(__doc__)
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
