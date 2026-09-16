#!/usr/bin/env bash
# Гар аргаар шалгах: сервер + хиймэл тоглогчид + Godot үйлчлүүлэгч.
#
# Долоон бот ширээг дүүргэж, НЭЭЛТТЭЙ өрөө үүсгэнэ. Godot нь жагсаалтаас
# тэр өрөөг олж, найм дахь суудалд орно. Ингэснээр нэг машин дээр бүтэн
# тоглолт явуулж, шинэ дэлгэц, шинэ мессежийг жинхэнэ сокетээр шалгана.
#
#   tools/play.sh           — 40 секунд ажиллаад зураг авна
#   tools/play.sh 120       — 120 секунд
set -euo pipefail

HOLD="${1:-40}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export PATH="/opt/dart-sdk/bin:$PATH"

SERVER_PID=""
BOTS_PID=""

# ЯАГААД PID-ЭЭР АЛНА, `pkill -f`-ЭЭР БИШ:
# `pkill -f` нь ажиллаж буй БҮХ тушаалын мөрийг шалгадаг бөгөөд үүнд
# өөрийг нь эхлүүлсэн бүрхүүл ч багтана. Скриптийн мөрөнд «bin/server.dart»
# гэсэн бичвэр байгаа тул pkill өөрийгөө таньж алдаг — энэ нь хөгжүүлэлтийн
# явцад хоёр удаа тохиолдож, бүрхүүл дундаа унтарсан.
cleanup() {
  [ -n "$SERVER_PID" ] && kill "$SERVER_PID" 2>/dev/null || true
  [ -n "$BOTS_PID" ] && kill "$BOTS_PID" 2>/dev/null || true
}
trap cleanup EXIT

cd "$ROOT/packages/server"
dart run bin/server.dart > /tmp/mafia_server.log 2>&1 &
SERVER_PID=$!
sleep 4

dart run tool/bots.dart --count 7 --wait 18 > /tmp/bots.log 2>&1 &
BOTS_PID=$!
sleep 10

cd "$ROOT"
bash tools/render.sh -- \
  "server=ws://127.0.0.1:8080" "room=*" "name=Хүчээ" \
  verbose=1 "hold=$HOLD" out=net.png

echo "--- ботууд ---"
tail -20 /tmp/bots.log
