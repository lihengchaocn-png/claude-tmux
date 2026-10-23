#!/usr/bin/env bash
# 重新生成 README 用的展示图：Chrome 无头截图 scene.html 的各个场景，再用 Pillow 合成 GIF / 压缩 PNG
# 输出 docs/img/en/ 和 docs/img/zh/ 两套
# 用法：bash docs/src/render.sh   （需要 Google Chrome 和 uv）
set -euo pipefail
SRC="$(cd "$(dirname "$0")" && pwd)"; OUT="$SRC/../img"; TMP="$(mktemp -d)"
C="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
cp "$SRC/scene.html" "$TMP/"
shot(){ "$C" --headless=new --disable-gpu --hide-scrollbars --force-device-scale-factor=2 --window-size="$2" --screenshot="$TMP/$3" "file://$TMP/scene.html?$1" >/dev/null 2>&1; }
for L in en zh; do
  rm -f "$TMP"/*.png
  shot "scene=states&lang=$L" 1200,400 states.png
  shot "scene=picker&lang=$L" 1200,710 picker.png
  shot "scene=menu&lang=$L"   1200,520 menu.png
  for f in $(seq 0 11); do shot "scene=hero&f=$f&lang=$L" 1200,720 "frame-$f.png"; done
  mkdir -p "$OUT/$L"
  uv run -q --with pillow python -I "$SRC/mkgif.py" "$TMP" "$OUT/$L/hero.gif"
done
rm -rf "$TMP"; ls -la "$OUT"/*
