#!/usr/bin/env bash
# 并行下载依赖闭包到 paccache/（多国内镜像自动回退）
set -uo pipefail
cd "$(dirname "$0")/.."
mkdir -p paccache
command -v parallel >/dev/null && PAR=1 || PAR=0
get(){
  u="$1"; cd paccache || exit 1
  f="${u##*/}"
  [ -s "$f" ] && exit 0
  tmp="$f.part.$$"
  if [[ "$u" == *denialwm.github.io* ]]; then
    try=( "$u" "https://gh-proxy.com/$u" )
  else
    path="${u#*archlinux/}"
    try=( "$u" "https://geo.mirror.archlinux.org/archlinux/$path" \
          "https://mirrors.ustc.edu.cn/archlinux/$path" "https://mirrors.zju.edu.cn/archlinux/$path" \
          "https://mirrors.sdu.edu.cn/archlinux/$path" "https://mirrors.bfsu.edu.cn/archlinux/$path" \
          "https://mirrors.aliyun.com/archlinux/$path" )
  fi
  for c in "${try[@]}"; do
    if curl -fsSL --connect-timeout 10 --max-time 900 -o "$tmp" "$c" 2>/dev/null; then mv -f "$tmp" "$f"; exit 0; fi
    rm -f "$tmp"
  done
  echo "FAIL $f" >> ../download-fail.log; exit 0
}
export -f get
: > download-fail.log
cat urls.txt | xargs -P 24 -I{} bash -c 'get "$@"' _ {}
echo "已下载 $(ls paccache | grep -c '\.pkg\.tar\.zst$') 个包"
(cd paccache && sha256sum -c ../sha256sums.txt 2>&1 | grep -v ': 成功$' | head -5)
grep -q FAIL download-fail.log && { echo "有失败项，重跑本脚本即可续传"; exit 1; } || echo "全部完成"
