#!/usr/bin/env bash
# GitHub Actions 构建入口：在 privileged Arch 容器内以 root 运行（仓库挂载于 /build）
set -euo pipefail
cd /build
echo "::group::工具链"
# 官方容器默认 mirrorlist 全注释 + keyring 未初始化，先修好
printf 'Server = https://geo.mirror.pkgbuild.com/$repo/os/$arch\n' > /etc/pacman.d/mirrorlist
pacman-key --init >/dev/null 2>&1 || true
pacman-key --populate archlinux >/dev/null 2>&1 || true
pacman -Sy --noconfirm >/dev/null
pacman -S --noconfirm --needed archiso mkinitcpio-archiso git curl wget python \
  rsync squashfs-tools libisoburn dosfstools mtools e2fsprogs pacman-contrib >/dev/null
command -v mkarchiso >/dev/null || { echo "::error::mkarchiso 未安装"; exit 1; }
echo "::endgroup::"
export ARCH_MIRROR=https://geo.mirror.pkgbuild.com   # 海外 runner 走官方 CDN
echo "::group::构建 ISO"
bash scripts/build-iso.sh
echo "::endgroup::"
echo "::group::产物校验"
ls -lh out/
ISO=$(ls out/ARCH-DENIAL-RESCUE-*.iso 2>/dev/null | head -1)
[ -n "$ISO" ] && [ -s "$ISO" ] || { echo "::error::构建未产出 ISO"; exit 1; }
echo "ISO: $ISO ($(stat -c %s "$ISO") bytes)"
sha256sum "$ISO" | sed "s|out/||" > "$ISO.sha256"
# 关键包版本清单（Release notes 用）
for p in opencode denial linux sddm fcitx5; do
  grep -h -E "^$p " packages.lock 2>/dev/null || true
done > out/versions.txt || true
cat out/versions.txt || true
echo "::endgroup::"
BASE=$(basename "$ISO" .iso)
{
  echo "滚动构建：含上游最新 opencode/denial 等全部包（自动跟随更新）"
  echo
  echo '```'
  grep -E "^(opencode|denial|linux|sddm|fcitx5) " packages.lock || true
  echo '```'
  echo
  echo "SHA256:"
  echo '```'
  cat "$ISO.sha256"
  echo '```'
  echo
  echo "写盘: sudo dd if=$BASE.iso of=/dev/sdX bs=4M status=progress oflag=sync"
  echo "或 Ventoy 直接拷入。首次使用双击桌面『U盘持久化设置』，重启选『持久模式』。"
} > release-notes.md
test -s release-notes.md || { echo "::error::release-notes 生成失败"; exit 1; }
# runner 用户 uid=1000，归还属主避免 checkout 清理失败
chown -R 1000:1000 /build 2>/dev/null || true
echo "CI BUILD OK"
