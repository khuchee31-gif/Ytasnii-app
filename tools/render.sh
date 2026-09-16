#!/usr/bin/env bash
# Тайзыг ТОЛГОЙГҮЙ орчинд зурж, PNG гаргана.
#
# Энэ нь зөвхөн хөгжүүлэлтийн хэрэгсэл: дэлгэцгүй сервер дээр тоглоомоо
# ХАРАХ боломж. Ингэснээр «болж байна уу» гэж таамаглахгүй, зургийг нь
# нээж шалгана.
#
#   tools/render.sh [scene] [out.png]
set -euo pipefail

GODOT="${GODOT:-$HOME/.godot/Godot_v4.5-stable_linux.x86_64}"
[ -x "$GODOT" ] || { echo "Godot олдсонгүй: $GODOT"; exit 1; }
command -v xvfb-run >/dev/null || { echo "xvfb-run хэрэгтэй"; exit 1; }

PROJ="$(cd "$(dirname "$0")/../game" && pwd)"
mkdir -p "$PROJ/shots"

xvfb-run -a -s "-screen 0 720x1600x24" "$GODOT" \
  --path "$PROJ" \
  --rendering-driver opengl3 \
  --resolution 720x1600 \
  "$@" 2>&1 | grep -vE "ALSA|audio|PagedAllocator|were leaked|never freed" || true
