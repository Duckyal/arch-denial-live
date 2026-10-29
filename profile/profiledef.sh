#!/usr/bin/env bash
# shellcheck disable=SC2034

iso_name="ARCH-DENIAL-RESCUE"
iso_label="ADR_$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y%m)"
iso_publisher="denial rescue live <https://github.com/denialwm/denial>"
iso_application="Arch + Denial Rescue Live"
iso_version="$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y.%m.%d)"
install_dir="arch"
kernel_params_x86_64="console=tty0 console=ttyS0,115200n8 quiet"
buildmodes=('iso')
bootmodes=('bios.syslinux' 'uefi.systemd-boot')
pacman_conf="pacman.conf"
airootfs_image_type="squashfs"
airootfs_image_tool_options=('-comp' 'zstd' '-Xcompression-level' '19' '-b' '1M')
bootstrap_tarball_compression=('zstd' '-c' '-T0' '--auto-threads=logical' '--long' '-19')
file_permissions=(
  ["/etc/shadow"]="0:0:400"
  ["/root"]="0:0:750"
  ["/root/.automated_script.sh"]="0:0:755"
  ["/root/customize_airootfs.sh"]="0:0:755"

  ["/usr/local/bin/choose-mirror"]="0:0:755"
  ["/usr/local/bin/live-de"]="0:0:755"
  ["/usr/local/bin/fixboot"]="0:0:755"
  ["/usr/local/bin/install-live"]="0:0:755"
  ["/usr/local/bin/denial-launch"]="0:0:755"
)
