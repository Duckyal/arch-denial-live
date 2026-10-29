#!/usr/bin/env bash
# 准备免 root 构建环境：用 Arch bootstrap 镜像导入 docker 并装 archiso 工具链
# （Docker Hub 不可达时的替代路线；宿主有 root+archiso 则不需要）
set -euo pipefail
M=mirrors.nju.edu.cn
curl -fL -o /tmp/archbootstrap.tar.zst https://$M/archlinux/iso/latest/archlinux-bootstrap-x86_64.tar.zst
mkdir -p /tmp/bsroot && tar -C /tmp/bsroot --strip-components=1 -xf /tmp/archbootstrap.tar.zst --zstd
chmod u+r /tmp/bsroot/usr/lib/dbus-daemon-launch-helper 2>/dev/null || true
( cd /tmp/bsroot && tar -cf - . | docker import - archiso-builder:base )
docker run --privileged --name ab-tools archiso-builder:base bash -c '
printf "Server = https://mirrors.nju.edu.cn/archlinux/\$repo/os/\$arch\n" > /etc/pacman.d/mirrorlist
sed -i "s/^SigLevel.*/SigLevel = Never/" /etc/pacman.conf
mkdir -p /etc/pacman.d/gnupg
pacman -Sy --noconfirm && pacman -S --noconfirm --needed archiso mkinitcpio-archiso e2fsprogs dosfstools mtools squashfs-tools libisoburn rsync git curl python zstd xz'
docker commit --change 'CMD ["/bin/bash"]' ab-tools archiso-builder:tools
docker rm -f ab-tools
echo "archiso-builder:tools 就绪"
