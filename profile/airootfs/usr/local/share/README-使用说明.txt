Arch + Denial 救援 Live —— 使用说明
════════════════════════════════════

  桌面进不去？ 登录界面左下角『会话』可切换：
    Denial 桌面（软件渲染）  → GPU 异常/独显直连黑屏时用
    Openbox 兼容桌面         → 万能 X11 兜底，右键出救援菜单
  denial 崩溃日志: ~/.local/state/denial/launch.log

一、写盘启动
  方法1 直接 dd:  sudo dd if=xxx.iso of=/dev/sdX bs=4M status=progress oflag=sync
  方法2 Ventoy:   装 Ventoy 后把 ISO 拖进 exFAT 分区即可（支持 legacy+UEFI）
  启动菜单：
    · 启动救援 Live —— 进 SDDM/桌面（root 空密码直接回车；live 用户免密 sudo）
    · Memtest86+   —— 测内存
    · 中文输入法已默认启用（fcitx5 拼音，Shift 切换中英文）

二、修 Windows 引导不启动（C盘进不去）
  sudo fixboot win        # UEFI 机型：从 Windows 分区把 bootmgfw.efi/BCD 复制回 ESP 并重建启动项
  sudo fixboot win /dev/sda
  sudo fixboot win-mbr /dev/sda   # 老 BIOS 机型：重写 MBR 引导代码并激活 NTFS 分区
  * 若 BCD 损坏严重：桌面图标 "修复 Windows 引导" 或 AI 助手（见下）能帮你逐步处理；
    最兜底办法是 Windows 安装介质 bootrec /rebuildbcd。

三、修 Linux 进不去（内核挂了/grub坏了/initramfs坏了）
  sudo fixboot linux            # 自动扫描 Arch 系根分区并重装 内核+mkinitcpio+grub/systemd-boot
  sudo fixboot linux /dev/sda2  # 手动指定根分区
  * 手动党：挂载后 `arch-chroot /mnt/sys`，效果等同。

四、AI 救援助手（自带，免费额度）
  opencode —— 终端里跑 `sudo -i opencode`
    · 内置 opencode/* 模型（OpenCode Zen）有免费额度，无需 API key 即可登录使用
    · 也支持 GitHub Copilot 免费额度、以及自定义 API key
    · 直接对它说："这台机器 grub 坏了进不去系统，帮我修" 
  gemini-cli —— Google 个人账号免费额度（未预装省体积）：
    sudo pacman -S gemini-cli && gemini   （登录 Gemini 账号即可）
  qwen-code —— 阿里通义免费额度：sudo pacman -S qwen-code
  注：AI 需要联网才能推理；离线时它们仍是好终端助手(opencode /status 看登录状态)。

五、装系统（在线 / 离线都行）
  sudo install-live /dev/sda   # 离线整盘安装：把 live 系统原样复制到硬盘（含 denial 桌面+全部救援工具+agent）
                               # 自动 GPT 分区(ESP/swap/root)，不需要网络！
  archinstall                  # 官方引导式安装器（在线，需网络）
  live-de gnome / kde / xfce / hyprland / sway / i3 ...
                               # 给 live 或已挂载系统补装其它桌面：
                               #   有网 → 自动走国内镜像; 断网 → --offline 用 ISO 内置包
  注：ISO 内置包 = 当前 live 已安装的全部软件（在线安装任意新软件需要联网）。

六、断网装桌面？
  断网时能装的就是 ISO 里已有的：denial(已默认)、以及 live-de --offline 可重复装配。
  其它桌面(GNOME/KDE...)想离线装，可先在有网机器下载好包放 U 盘 extra/ 目录，
  然后 pacman -U 安装。

七、磁盘/数据救援工具清单
  gparted(桌面版) / parted / fdisk / gdisk      分区
  testdisk / photorec                            找回分区与文件
  ddrescue                                       坏盘镜像克隆
  fsarchiver                                     分区整存整取
  chntpw                                         清 Windows 密码/改引导
  wimlib-imagex                                  读写 Windows WIM/BCD
  smartmontools nvme-cli hdparm                  磁盘健康
  lvm2 mdadm cryptsetup thin-provisioning-tools  LVM/RAID/加密
  ntfs-3g exfatprogs dosfstools btrfs xfs jfs f2fs 全文件系统读写
  os-prober efibootmgr refind grub               引导链修复
  memtest86+                                     内存检测

八、自定义
  live 用户家目录有桌面图标（安装/修复快捷方式）。
  镜像源在 /etc/pacman.d/mirrorlist（南大/中科大/浙大/山大优先）。


十一、U 盘数据持久化（重启不丢改动）
  第一次用（任意模式启动进桌面后）：
    桌面图标『U盘持久化设置』或终端执行: sudo persist-make
    （自动在 U 盘尾部建 CASPER_RW 分区, ext4）
  以后开机在菜单选：
    · 持久模式（改动保存到 U 盘 CASPER_RW 分区）
      → 系统+软件+家目录全部保存（dm-snapshot cow 文件，默认 2G 上限，FAT32 单文件最大 4G，
        可在启动项里改 cow_spacesize=8G）
    · 默认普通模式 = 每次全新（适合借别人电脑临时用）
  说明：
    - 没建分区就选"持久模式"不会坏，自动降级为普通模式
    - Ventoy 同样支持：把 ISO 拖进 Ventoy 盘 → 启动选"持久模式" →
      第一次进系统先跑 persist-make（它会把分区建在 Ventoy 的 exFAT 盘尾部，
      若空间不足，也可另插一个 U 盘，手动把它格式化成标签 CASPER_RW 再启动）
    - 想换回干净系统：删掉 CASPER_RW 分区里的 persistent_* 目录即可
    - CASPER_RW 是 ext4（cow 持久化机制要求，Windows 不能直接读）；
    要给 Windows 拷数据：另插一只 exFAT U 盘，或用 Ventoy 盘自带的 exFAT 分区

九、远程救援（另一台电脑 SSH 进来操作）
  live 里 root 空密码只能本机串口/TTY 用；要 SSH 先设密码：
    sudo passwd root        # 输两次密码
  然后另一台机器: ssh root@<live机IP>  （live 里 ip a 看 IP，或 nmcli -t -f IP.ADDR4 dev）
  插网线直连最稳；没网线就手机 USB 共享后两台都在同网段。

十、没网也能让 AI 干活？
  事实：opencode/gemini-cli 的模型在云端，纯离线无法推理。但——
  1) 手机 USB 共享上网（推荐）：数据线插电脑 → 手机开"USB网络共享"
     → live 里自动出现 usb0/rndis 网卡，NetworkManager 自动获取 IP。
     验证：nmcli -t -f STATE g  或  curl -sI https://mirrors.nju.edu.cn | head -1
  2) 有线网口直插即通；WiFi 用 nmtui 或 denial 桌面右上角网络面板。
  3) 纯离线救援：不靠 AI，用 fixboot / install-live / chntpw / testdisk /
     ddrescue / fsarchiver（全部内置，见上面各节）。
  4) 想要真·离线本地模型（自备 ≥3G 空间，不占 ISO）：
     在有网机器上执行：
       curl -L -o llama.zip https://github.com/ggml-org/llama.cpp/releases/download/b????/llama-b????-bin-ubuntu-x64.zip
       curl -L -o qwen-coder.gguf https://hf-mirror.com/Qwen/Qwen2.5-Coder-3B-Instruct-GGUF/resolve/main/qwen2.5-coder-3b-instruct-q4_k_m.gguf
     解压到 U 盘某分区，离线时挂上：
       llama-cli -m qwen-coder.gguf -p "我的 /etc/fstab 挂了，grub 报 no such device，帮我逐步排查"
     3B 小模型能读懂日志/写配置/讲步骤，救砖够用，别指望它写大段代码。
