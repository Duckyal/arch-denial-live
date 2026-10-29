#!/usr/bin/env bash
set -e
export LANG=C.UTF-8 LC_ALL=C.UTF-8
# live 用户（免密 sudo + 自动登录）
useradd -m -u 1000 -G wheel,audio,video,input,seat,render,floppy,lp -s /usr/bin/bash live 2>/dev/null || {
  usermod -aG wheel,audio,video,input,seat,render,floppy,lp live
  usermod -s /usr/bin/bash live
}
passwd -d live
echo 'live ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/live
chmod 440 /etc/sudoers.d/live
# root 空密码（救援场景）
echo 'root::14871::::::' >/etc/shadow.chg && [ -f /etc/shadow ] && sed -i 's|^root:[^:]*:|root::|' /etc/shadow
# 中文 locale
sed -i 's/^# *zh_CN.UTF-8/zh_CN.UTF-8/; s/^# *en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen
locale-gen
echo 'LANG=zh_CN.UTF-8' >/etc/locale.conf
echo 'KEYMAP=us' > /etc/vconsole.conf
# 时区
ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
# SDDM 自动登录进 Denial 桌面
mkdir -p /etc/sddm.conf.d
cat >/etc/sddm.conf.d/10-autologin.conf <<'SDDM'
[Autologin]
User=live
Session=denial
Relogin=true

[General]
DisplayMode=Query
Language=zh_CN
SDDM
# 服务
systemctl set-default graphical.target
systemctl enable sddm.service NetworkManager.service sshd.service getty@tty1.service getty@tty2.service 2>/dev/null || true
systemctl disable systemd-networkd systemd-resolved 2>/dev/null || true
# live/root skel 同步（桌面图标、agent 配置、输入法环境）
for h in /home/live /root; do
  [ -d "$h" ] || continue
  [ -f /etc/skel/.xprofile ] && cp -f /etc/skel/.xprofile "$h/.xprofile"
  [ -d /etc/skel/Desktop ] && cp -rf /etc/skel/Desktop "$h/"
  mkdir -p "$h/.config/opencode" && cp -f /etc/skel/.config/opencode/opencode.json "$h/.config/opencode/" 2>/dev/null || true
  mkdir -p "$h/.config/fcitx5/conf" && cp -rf /etc/skel/.config/fcitx5/. "$h/.config/fcitx5/" 2>/dev/null || true
  mkdir -p "$h/.config/environment.d" && cp -f /etc/skel/.config/environment.d/im.conf "$h/.config/environment.d/" 2>/dev/null || true
  chown -R 1000:1000 /home/live 2>/dev/null || true
done
# 开机自动进 X（tty1 无需手动 startx；sddm 已接管）。为纯文本应急保留 root tty2 autologin。
mkdir -p /etc/systemd/system/getty@tty2.service.d
printf '[Service]\nExecStart=\nExecStart=-/usr/bin/agetty --autologin root --noclear %%I $TERM\n' >/etc/systemd/system/getty@tty2.service.d/override.conf
# 提示文件
ln -sf /usr/local/share/README-使用说明.txt /root/README.txt 2>/dev/null || true
ln -sf /usr/local/share/README-使用说明.txt /home/live/Desktop/README.txt 2>/dev/null || true

# ===== 体积裁剪：救援盘用不到的文档/本地化/开发文件 =====
# 多语言 .mo（保留 zh_CN/zh_TW/en）
find /usr/share/locale -mindepth 1 -maxdepth 1 \( -name '??' -o -name '??_*' \) \
  ! -name 'zh_CN' ! -name 'zh_TW' ! -name 'en_US' ! -name 'zh' ! -name 'en' -exec rm -rf {} + 2>/dev/null || true
find /usr/share/man -mindepth 1 -maxdepth 1 ! -name 'zh_CN*' ! -name 'man*' -exec rm -rf {} + 2>/dev/null || true
rm -rf /usr/share/man/zh_TW /usr/share/man/ja 2>/dev/null || true
rm -rf /usr/share/gir-1.0 /usr/share/doc /usr/share/gtk-doc /usr/include 2>/dev/null || true
# i18n 只留需要 locale 的数据源（保留 zh_CN/en_US，其余删）
find /usr/share/i18n/locales -mindepth 1 ! -name 'zh_CN*' ! -name 'en_US*' ! -name 'POSIX*' ! -name 'i18n*' ! -name 'translit*' -delete 2>/dev/null || true
# 字体：删掉拉丁装饰字体（保留 CJK + terminus + vera）
find /usr/share/fonts -type d -name '*noto*' -prune -exec rm -rf {} + 2>/dev/null || true
rm -rf /usr/share/fonts/TTF-nonexistent 2>/dev/null || true
ldconfig
echo "trim done"


# 救援快捷方式装进系统应用列表（denial 启动器从这里读）
for d in /etc/skel/Desktop/*.desktop; do
  [ -f "$d" ] && install -m 644 "$d" /usr/share/applications/
done
desktop-file-utils-update() { command -v update-desktop-database >/dev/null && update-desktop-database -q /usr/share/applications; }
desktop-file-utils-update || true

echo "customize done"
# 壁纸与 denial 状态（skel -> /home/live）
mkdir -p /home/live/.local/state/denial
cp -a /etc/skel/.local/state/denial/wallpaper /home/live/.local/state/denial/ 2>/dev/null || true
mkdir -p /root/.local/state/denial
cp -a /etc/skel/.local/state/denial/wallpaper /root/.local/state/denial/ 2>/dev/null || true
chown -R 1000:1000 /home/live/.local
