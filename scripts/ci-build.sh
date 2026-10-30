#!/usr/bin/env bash
# GitHub Actions 构建入口：在 privileged Arch 容器内以 root 运行（仓库挂载于 /build）
set -euo pipefail
cd /build
echo "::group::工具链"
pacman -Sy --noconfirm >/dev/null
pacman -S --noconfirm --needed archiso mkinitcpio-archiso git curl wget python \
  rsync squashfs-tools libisoburn dosfstools mtools e2fsprogs pacman-contrib >/dev/null
mkdir -p /etc/pacman.d/gnupg
echo "::endgroup::"
echo "::group::构建 ISO"
bash scripts/build-iso.sh
echo "::endgroup::"
echo "::group::校验与产物"
(cd out && sha256sum ARCH-DENIAL-RESCUE-*.iso > ARCH-DENIAL-RESCUE-$(date +%Y.%m.%d)-x86_64.iso.sha256 2>/dev/null || true)
ls -lh out/
# pkglist 里提取关键版本，供 Release notes 用
for p in opencode denial gemini-cli; do
  grep -m1 -E "^$p " pkglist*.txt 2>/dev/null || true
done > out/versions.txt 2>/dev/null || true
cat out/versions.txt 2>/dev/null || true
# runner 用户 uid=1000，归还属主避免 checkout 清理失败
chown -R 1000:1000 /build 2>/dev/null || true
echo "::endgroup::"
