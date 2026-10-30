#!/usr/bin/env bash
# 检测上游包是否有新版本。有变化输出新锁文件到 stdout 并 exit 0；无变化 exit 1。
# 用法（CI）: 先刷新同步库 → 本脚本比对 packages.lock
set -uo pipefail
cd "$(dirname "$0")/.."
LOCK=packages.lock
[ -f "$LOCK" ] || { echo "::error::缺 $LOCK"; exit 2; }

python3 - <<'PY'
import gzip, io, tarfile, os, sys
SYNC='/var/lib/pacman/sync'
pkgs={}; provides={}; vers={}
for r in ['core','extra','denial']:
    p=f'{SYNC}/{r}.db'
    if not os.path.exists(p): continue
    raw=open(p,'rb').read(); data=gzip.decompress(raw) if raw[:2]==b'\x1f\x8b' else raw
    try: t=tarfile.open(fileobj=io.BytesIO(data))
    except Exception: continue
    for m in t.getmembers():
        if not m.name.endswith('/desc'): continue
        L=t.extractfile(m).read().decode(errors='replace').split('\n')
        d={}; i=0
        while i<len(L):
            if L[i].startswith('%') and L[i].endswith('%') and L[i][1:-1].isupper():
                j=i+1
                while j<len(L) and L[j].strip(): j+=1
                d[L[i]]=L[i+1:j]; i=j
            else: i+=1
        n=d.get('%NAME%',[None])[0]
        if not n: continue
        import re
        deps=[]
        for x in d.get('%DEPENDS%',[]):
            x=x.split()[0] if x.strip() else ''
            if x: deps.append(re.split(r'>=|<=|=|:', x)[0].strip())
        pv=[]
        for x in d.get('%PROVIDES%',[]):
            x=re.split(r'>=|<=|=|:', x)[0].strip() if x.strip() else ''
            if x: pv.append(x)
        pkgs[n]={'repo':r,'depends':deps}
        vers[n]=d.get('%VERSION%',['?'])[0]
        for v in pv: provides.setdefault(v,[]).append(n)
def res(d):
    if d in pkgs: return d
    for x in provides.get(d,[]):
        if x in pkgs: return x
if len(pkgs) < 1000:
    print(f"::error::同步库异常（仅解析到 {len(pkgs)} 个包），pacman -Sy 可能失败"); sys.exit(2)
req=[l.strip() for l in open('profile/packages.x86_64') if l.strip() and not l.startswith('#')]
seen=set(); st=[res(r) for r in req]; st=[x for x in st if x]
while st:
    n=st.pop()
    if n in seen: continue
    seen.add(n)
    for dd in pkgs[n]['depends']:
        x=res(dd)
        if x and x not in seen: st.append(x)
new={n:vers.get(n,'?') for n in seen}
old={}
for line in open('packages.lock'):
    parts=line.split(None,1)
    if len(parts)==2: old[parts[0]]=parts[1].strip()
changed=[(n,old.get(n,'∅'),v) for n,v in sorted(new.items()) if old.get(n)!=v]
if not changed:
    print("NOCHANGES"); sys.exit(1)
print("== 版本变化 ==")
for n,a,b in changed: print(f"  {n}: {a} -> {b}")
with open('packages.lock.new','w') as f:
    for n in sorted(new): f.write(f"{n} {new[n]}\n")
print("WROTE packages.lock.new")
PY
RC=$?
[ $RC -eq 1 ] && exit 1
[ $RC -eq 0 ] && mv packages.lock.new packages.lock && exit 0
exit $RC
