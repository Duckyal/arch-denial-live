#!/usr/bin/env bash
# 把 paccache 里的包按仓库分类到 repo/ 并生成 pacman 数据库（离线构建用）
set -euo pipefail
cd "$(dirname "$0")/.."
rm -rf repo && mkdir -p repo
python3 - <<'PY'
import os, shutil, gzip, io, tarfile
SYNC='/var/lib/pacman/sync'
repo={}
for r in ['core','extra','denial']:
    p=f'{SYNC}/{r}.db'
    if not os.path.exists(p): continue
    raw=open(p,'rb').read(); data=gzip.decompress(raw) if raw[:2]==b'\x1f\x8b' else raw
    t=tarfile.open(fileobj=io.BytesIO(data))
    for m in t.getmembers():
        if not m.name.endswith('/desc'): continue
        L=t.extractfile(m).read().decode(errors='replace').split('\n')
        if '%FILENAME%' in L: repo[L[L.index('%FILENAME%')+1]]=r
for f in (l.strip() for l in open('files.txt') if l.strip()):
    r=repo.get(f) or ('denial' if f.startswith('denial') else 'extra')
    d=f'repo/{r}/os/x86_64'; os.makedirs(d, exist_ok=True)
    src=f'paccache/{f}'
    if os.path.exists(src): shutil.copy2(src, f'{d}/{f}')
    else: print('MISSING', f)
PY
for r in core extra denial; do
  d=repo/$r/os/x86_64; [ -d "$d" ] || continue
  (cd "$d" && rm -f $r.db $r.db.tar.gz && repo-add -q $r.db.tar.gz *.pkg.tar.zst >/dev/null && ln -sf $r.db.tar.gz $r.db)
done
echo "repo 就绪: $(find repo -name '*.pkg.tar.zst' | wc -l) 个包"
