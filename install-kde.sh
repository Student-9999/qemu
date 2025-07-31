#!/bin/bash
set -e

# ------------------------ 用户自定义 ------------------------
disk="/dev/nvme1n1"
hostname="archkk"
username="kk"
userpass="kk123"
rootpass="root123"
locale_lang="en_US.UTF-8"
timezone="Asia/Shanghai"
# ------------------------------------------------------------

echo "[1/6] 分区 $disk"
parted -s $disk mklabel gpt
parted -s $disk mkpart ESP fat32 1MiB 513MiB
parted -s $disk set 1 esp on
parted -s $disk mkpart primary ext4 513MiB 100%

echo "[2/6] 格式化并挂载"
mkfs.fat -F32 ${disk}p1
mkfs.ext4 ${disk}p2
mount ${disk}p2 /mnt
mkdir -p /mnt/boot
mount ${disk}p1 /mnt/boot

echo "[3/6] 安装基础系统和 KDE 桌面"
pacstrap /mnt base linux linux-firmware sudo vim \
  networkmanager systemd-boot \
  xorg plasma kde-applications sddm firefox \
  noto-fonts noto-fonts-cjk noto-fonts-emoji \
  fcitx5-im fcitx5-chinese-addons fcitx5-configtool \
  pipewire pipewire-pulse

echo "[4/6] 生成 fstab"
genfstab -U /mnt >> /mnt/etc/fstab

echo "[5/6] 系统配置"
arch-chroot /mnt /bin/bash <<EOF
# 基础设置
ln -sf /usr/share/zoneinfo/$timezone /etc/localtime
hwclock --systohc
echo "$hostname" > /etc/hostname
sed -i 's/#$locale_lang/$locale_lang/' /etc/locale.gen
locale-gen
echo "LANG=$locale_lang" > /etc/locale.conf

# 中文支持
echo "export GTK_IM_MODULE=fcitx5" >> /etc/profile
echo "export QT_IM_MODULE=fcitx5" >> /etc/profile
echo "export XMODIFIERS=@im=fcitx" >> /etc/profile

# Hosts
cat > /etc/hosts <<EOL
127.0.0.1 localhost
::1       localhost
127.0.1.1 $hostname.localdomain $hostname
EOL

# 创建用户
echo "root:$rootpass" | chpasswd
useradd -m -G wheel $username
echo "$username:$userpass" | chpasswd
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

# 启用服务
systemctl enable NetworkManager
systemctl enable sddm

# 安装 bootloader
bootctl --path=/boot install
cat > /boot/loader/entries/arch.conf <<EOL
title   Arch Linux
linux   /vmlinuz-linux
initrd  /initramfs-linux.img
options root=PARTUUID=$(blkid -s PARTUUID -o value ${disk}p2) rw
EOL
echo "default arch" > /boot/loader/loader.conf
EOF

echo "[6/6] 安装完成！可以 reboot 进入图形界面！"
