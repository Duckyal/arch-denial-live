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
# 根治启动刷屏：loop 挂载已由 initramfs 完成，rootfs 里 systemd 重复 attach sr0
# 会反复报 "Attach File ... to Loopback Block Device FAILED"（即用户看到的 magic 报错）
ln -sf /dev/null /etc/systemd/system/systemd-losetup@.service
echo "trim done"


# 救援快捷方式装进系统应用列表（denial 启动器从这里读）
for d in /etc/skel/Desktop/*.desktop; do
  [ -f "$d" ] && install -m 644 "$d" /usr/share/applications/
done
desktop-file-utils-update() { command -v update-desktop-database >/dev/null && update-desktop-database -q /usr/share/applications; }
desktop-file-utils-update || true


# ===== 会话定制（必须在装包后做，否则被包文件覆盖）=====
# 1) denial.desktop 指向带日志/软渲染重试的包装器
sed -i 's|^Exec=.*|Exec=/usr/local/bin/denial-launch|' /usr/share/wayland-sessions/denial.desktop
# 2) 软件渲染版 denial 会话（SDDM 菜单可选，治 NVIDIA/异常 GPU）
cat > /usr/share/wayland-sessions/denial-soft.desktop <<'DESK'
[Desktop Entry]
Name=Denial 桌面（软件渲染）
Comment=LLVMpipe 软渲染，兼容异常 GPU
Exec=env LIBGL_ALWAYS_SOFTWARE=1 /usr/local/bin/denial-launch
TryExec=/usr/bin/denial-session
Type=Application
DesktopNames=Denial
DESK
# 3) Openbox X11 兜底会话（万能，任何 GPU 都能进）
mkdir -p /usr/share/xsessions
cat > /usr/share/xsessions/openbox.desktop <<'DESK'
[Desktop Entry]
Name=Openbox 兼容桌面
Comment=X11 兜底会话（denial 启动失败时用）
Exec=openbox-session
TryExec=openbox-session
Type=Application
DesktopNames=Openbox
DESK
mkdir -p /etc/xdg/openbox
cat > /etc/xdg/openbox/environment <<'OB'
export GTK_IM_MODULE=fcitx
export QT_IM_MODULE=fcitx
export XMODIFIERS=@im=fcitx
OB
cat > /etc/xdg/openbox/autostart <<'OB'
#!/bin/sh
(xterm -fa 'Source Han Sans CN' -fs 11 -geometry 100x30+80+80 &)
OB
chmod +x /etc/xdg/openbox/autostart
cat > /etc/xdg/openbox/menu.xml <<'OB'
<?xml version="1.0" encoding="UTF-8"?>
<openbox_menu xmlns="http://openbox.org/">
<menu id="root-menu" label="救援">
  <item label="终端 (xterm)"><action name="Execute"><execute>xterm -fa 'Source Han Sans CN' -fs 11</execute></action></item>
  <item label="修 Windows 引导"><action name="Execute"><execute>xterm -e sudo fixboot win</execute></action></item>
  <item label="修 Linux 引导"><action name="Execute"><execute>xterm -e sudo fixboot linux</execute></action></item>
  <item label="离线安装系统"><action name="Execute"><execute>xterm -e sudo install-live</execute></action></item>
  <item label="AI 救援 (opencode)"><action name="Execute"><execute>xterm -e sudo -i opencode</execute></action></item>
  <separator/>
  <item label="退出登录"><action name="Exit"/></item>
</menu>
</openbox_menu>
OB

# ===== iwlwifi 固件裁剪：每个网卡型号只留最新 2 个 API 版本 =====
# 内核 iwlwifi 驱动只加载该型号可用的最高版本固件，旧版本纯占体积(~96M→~30M)
python3 - <<'TRIM'
import os, re, collections
d='/usr/lib/firmware/intel/iwlwifi'
groups=collections.defaultdict(list)
for f in os.listdir(d):
    m=re.match(r'^(iwlwifi-.+?)-(\d+)\.ucode\.zst$', f)
    if m: groups[m.group(1)].append((int(m.group(2)), f))
removed=0
for prefix, items in groups.items():
    items.sort(reverse=True)
    for api, f in items[2:]:
        try: os.remove(os.path.join(d,f)); removed+=1
        except OSError: pass
print(f'iwlwifi trim: removed {removed} old firmware files')
TRIM
echo "sessions customized"
chmod +x /usr/local/bin/denial-launch /usr/local/bin/fixboot /usr/local/bin/install-live /usr/local/bin/live-de 2>/dev/null || true

echo "customize done"
# 壁纸与 denial 状态（skel -> /home/live）
mkdir -p /home/live/.local/state/denial
cp -a /etc/skel/.local/state/denial/wallpaper /home/live/.local/state/denial/ 2>/dev/null || true
mkdir -p /root/.local/state/denial
cp -a /etc/skel/.local/state/denial/wallpaper /root/.local/state/denial/ 2>/dev/null || true
chown -R 1000:1000 /home/live/.local
