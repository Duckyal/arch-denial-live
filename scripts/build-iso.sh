#!/usr/bin/env bash
# 一键构建：壁纸占位(若无) -> 生成闭包 -> 下载 -> 本地仓库 -> mkarchiso
# 依赖: archiso(宿主或容器内), pacman 同步库已刷新
set -euo pipefail
cd "$(dirname "$0")/.."
WP=profile/airootfs/usr/share/backgrounds/arch-denial/default.jpg
if [ ! -f "$WP" ]; then
  echo ">> 壁纸不存在，生成渐变占位图（可提前放入你自己的 jpg 替换）"
  mkdir -p "$(dirname "$WP")"
  if command -v convert >/dev/null 2>&1; then
    convert -size 1920x1080 gradient:'#0f2027-#2c5364' "$WP"
  else
    python3 - "$WP" <<'INNERPY'
import zlib, struct, sys
w, h = 1920, 1080
def chunk(t, d):
    c = struct.pack('>I', len(d)) + t + d
    return c + struct.pack('>I', zlib.crc32(t + d) & 0xffffffff)
rows = []
for y in range(h):
    row = b'\x00'
    for x in range(w):
        row += bytes((15 + (x * 35) // w, 32 + (y * 40) // h, 60 + ((x + y) * 30) // (w + h)))
    rows.append(row)
data = zlib.compress(b''.join(rows), 9)
png = (b'\x89PNG\r\n\x1a\n'
       + chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 2, 0, 0, 0))
       + chunk(b'IDAT', data) + chunk(b'IEND', b''))
open(sys.argv[1], 'wb').write(png)
print("placeholder wallpaper written:", sys.argv[1])
INNERPY
  fi
fi
echo ">> 解析依赖闭包（每次重新解析，滚动拿上游最新版）"
python3 scripts/deps.py profile/packages.x86_64
bash scripts/fetch-packages.sh
bash scripts/make-repo.sh
mkdir -p work out
# pacman.conf 里的 /build 前缀按实际构建根改写（构建结束后还原，保持工作区干净）
cp profile/pacman.conf /tmp/pacman.conf.orig
trap 'cp /tmp/pacman.conf.orig profile/pacman.conf' EXIT
sed -i "s|/build/paccache|$PWD/paccache|; s|file:///build/repo|file://$PWD/repo|" profile/pacman.conf
# 宿主有 root 就直接跑，否则用 docker 特权容器
if [ "$(id -u)" = 0 ] && command -v mkarchiso >/dev/null; then
  mkdir -p /etc/pacman.d/gnupg
  mkarchiso -v -w work -o out profile
else
  docker run --rm --privileged -v "$PWD":/build archiso-builder:tools \
    bash -c 'mkdir -p /etc/pacman.d/gnupg && mkarchiso -v -w /build/work -o /build/out /build/profile'
fi
ls -lh out/*.iso
