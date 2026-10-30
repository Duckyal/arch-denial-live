#!/usr/bin/env python3
"""从本地 pacman 同步库解析 profile/packages.x86_64 的完整依赖闭包。
用法: python3 deps.py <packages文件> [输出目录]
需要: /var/lib/pacman/sync/{core,extra}.db （先 sudo pacman -Sy 刷新）
denial 仓库 db 可选（denial 包本身直接下载即可）。"""
import gzip, io, tarfile, os, re, sys
SYNC='/var/lib/pacman/sync'
# denial 仓库 db 本地没有就拉一份（denial 包及其依赖需要它解析）
if not os.path.exists(f'{SYNC}/denial.db'):
    try:
        import urllib.request
        os.makedirs(SYNC, exist_ok=True)
        urllib.request.urlretrieve('https://denialwm.github.io/denial/x86_64/denial.db', f'{SYNC}/denial.db')
    except Exception as e:
        print('warn: denial.db 下载失败，denial 相关包需手工处理:', e)
pkgs={}; provides={}
for r in ['core','extra','denial','multilib']:
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
        def deps(key):
            out=[]
            for x in d.get(key,[]):
                x=x.split()[0] if x.strip() else ''
                if not x: continue
                x=re.split(r'>=|<=|=|:', x)[0].strip()
                if x: out.append(x)
            return out
        pkgs[n]={'repo':r,'file':d.get('%FILENAME%',[''])[0],
                 'csize':int(d.get('%CSIZE%',['0'])[0] or 0),'isize':int(d.get('%ISIZE%',['0'])[0] or 0),
                 'sha':d.get('%SHA256SUM%',[''])[0],
                 'depends':deps('%DEPENDS%')}
        for pv in deps('%PROVIDES%'): provides.setdefault(pv,[]).append(n)
def res(dep):
    if dep in pkgs: return dep
    for x in provides.get(dep,[]):
        if x in pkgs: return x
def closure(req):
    seen=set(); st=[]; miss=[]
    for r in req:
        x=res(r)
        if x: st.append(x)
        else: miss.append(r)
    while st:
        n=st.pop()
        if n in seen: continue
        seen.add(n)
        for dd in pkgs[n]['depends']:
            x=res(dd)
            if x and x not in seen: st.append(x)
    return seen, miss
if __name__=='__main__':
    reqf=sys.argv[1]
    outdir=sys.argv[2] if len(sys.argv)>2 else '.'
    req=[l.strip() for l in open(reqf) if l.strip() and not l.startswith('#')]
    S,miss=closure(req); mb=1048576
    dl=sum(pkgs[x]['csize'] for x in S); ins=sum(pkgs[x]['isize'] for x in S)
    print(f"闭包 {len(S)} 包  下载 {dl/mb:.0f}MB  安装 {ins/mb:.0f}MB")
    if miss: print("未解析:", sorted(set(miss))[:10])
    M=os.environ.get('ARCH_MIRROR','https://mirrors.nju.edu.cn/archlinux')
    os.makedirs(outdir, exist_ok=True)
    with open(f'{outdir}/urls.txt','w') as f, open(f'{outdir}/sha256sums.txt','w') as g, open(f'{outdir}/files.txt','w') as w:
        for n in sorted(S):
            e=pkgs[n]
            if not e['file']: continue
            url=(f"https://denialwm.github.io/denial/x86_64/{e['file']}" if e['repo']=='denial'
                 else f"{M}/{e['repo']}/os/x86_64/{e['file']}")
            f.write(url+'\n'); g.write(f"{e['sha']}  {e['file']}\n"); w.write(e['file']+'\n')
