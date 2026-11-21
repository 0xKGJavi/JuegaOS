#!/usr/bin/env bash
# shellcheck disable=SC2034

iso_name="juegaos"
iso_label="JUEGAOS_$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y%m)"
iso_publisher="JuegaOS"
iso_application="JuegaOS Live and Installer"
iso_version="$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y.%m.%d)"
install_dir="juegaos"
bootmodes=('bios.syslinux' 'uefi.systemd-boot')
airootfs_image_type="squashfs"
airootfs_image_tool_options=('-comp' 'xz' '-Xbcj' 'x86' '-b' '1M' '-Xdict-size' '1M')

file_permissions=(
  ["/usr/local/bin/juegaos-live-user"]="0:0:755"
  ["/usr/local/bin/juegaos-install-heroic"]="0:0:755"
  ["/usr/local/bin/juegaos-postinstall"]="0:0:755"
  ["/usr/local/share/applications/juegaos-install.desktop"]="0:0:644"
  ["/etc/calamares/settings.conf"]="0:0:644"
  ["/etc/calamares/modules/unpackfs.conf"]="0:0:644"
  ["/etc/calamares/modules/packages.conf"]="0:0:644"
  ["/etc/calamares/modules/bootloader.conf"]="0:0:644"
  ["/etc/calamares/modules/users.conf"]="0:0:644"
  ["/etc/calamares/modules/removeuser.conf"]="0:0:644"
  ["/etc/calamares/modules/services-systemd.conf"]="0:0:644"
  ["/etc/calamares/modules/shellprocess-juegaos-cleanup.conf"]="0:0:644"
  ["/etc/sddm.conf.d/10-juegaos-live.conf"]="0:0:644"
  ["/etc/sudoers.d/10-juegaos-live"]="0:0:440"
  ["/etc/systemd/system/juegaos-live-user.service"]="0:0:644"
  ["/etc/skel/.config/autostart/juegaos-steam.desktop"]="0:0:644"
  ["/etc/skel/.config/autostart/juegaos-heroic.desktop"]="0:0:644"
  ["/etc/skel/Desktop/juegaos-install.desktop"]="0:0:644"
)
