#!/bin/bash

pacmans="pacman -S --noconfirm"
yays="yay -S --noconfirm"

base_pkg=(acpid acpilight alsa-utils avahi bluez bluez-utils cifs-utils cups curl dhcpcd dialog dkms git gvfs-smb htop ifplugd libinput linux-headers man netctl openssh p7zip pulseaudio pulseaudio-alsa pulsemixer python python-pip ranger redshift rsync scrot seahorse sshfs sudo terminator ttf-dejavu ttf-font-awesome ttf-nerd-fonts-symbols udevil unzip upower vim wget wpa_supplicant wqy-zenhei xorg-server xorg-xrandr zsh)

i3_pkg=(i3lock i3status-rust i3-wm iw lightdm lightdm-gtk-greeter playerctl rofi xss-lock)
i3_aur=(autotiling xidlehook)

laptop_pkg=(xbindkeys xdotool xf86-video-intel)
laptop_aur=(libinput-gestures)

desktop_aur=(rtl8814au-aircrack-dkms-git)

user_pkg=(firefox gimp gparted gpicview libreoffice nemo nemo-fileroller nemo-share octave qpdfview speedcrunch thunderbird vivaldi vlc)
user_aur=(bitwarden nextcloud-client plex-media-player spotify teams zoom)

function aur_helper() {
  cd /tmp
  if [[ -d yay ]]; then
    rm -rf yay
  fi
  git clone https://aur.archlinux.org/yay.git
  chown -R $user:users yay/
  cd yay
  sudo -u $user makepkg -si --noconfirm
}

function bootmethod() {
  read -p 'Bootmethod: UEFI (1), BIOS (2): ' boot
}

function config() {
  read -p 'Configuration: Desktop (1), Laptop (2): ' config
}

function root_part() {
  read -p 'Root partition /dev/sdXY: ' root_part
}

function vga() {
  read -p 'Graphics driver :' vga
}

function wm() {
  read -p 'Window manager: i3 (1): ' wm_idx
}

read -p 'Hostname: ' hostname
read -sp 'Root password: ' root_pw
echo ""
read -p 'User: ' user
read -sp 'Password for flo: ' user_pw
echo ""
bootmethod
while [[ $boot != "1" && $boot != "2" ]]; do
  bootmethod
done
config
while [[ $config != "1" && $config != "2" ]]; do
  config
done
root_part
while [[ ! -e $root_part ]]; do
  root_part
done
wm
while [[ $wm_idx != "1" ]]; do
  wm
done
if [[ $wm_idx -eq 1 ]]; then
  wm='i3'
fi

if [[ $(lspci | grep VGA | grep -i intel | wc -l) -gt 0 ]]; then
  vga="xf86-video-intel"
elif [[ $(lspci | grep VGA | grep -i amd | wc -l) -gt 0 ]]; then
  vga="xf86-video-amdgpu"
elif [[ $(lspci | grep VGA | grep -i nvidia | wc -l) -gt 0 ]]; then
  vga="xf86-video-nouveau"
else
  vga
  while [[ $(pacman -Ss ^$vga\$ | wc -l) -eq 0 ]]; do
    vga
  done
fi

echo "Install base packages"
$pacmans ${base_pkg[@]}
$pacmans $vga

echo "$hostname" > /etc/hostname

echo "Set locales"
echo "LANG=de_DE.UTF-8" > /etc/locale.conf

sed -i 's/^#de_DE.UTF-8 UTF-8/de_DE.UTF-8 UTF-8/g' /etc/locale.gen
sed -i 's/^#de_DE ISO-8859-1/de_DE ISO-8859-1/g' /etc/locale.gen
sed -i 's/^#de_DE@euro ISO-8859-15/de_DE@euro ISO-8859-15/g' /etc/locale.gen
sed -i 's/^#en_US.UTF-8/en_US.UTF-8/g' /etc/locale.gen

locale-gen

echo "Set timezone"
ln -sf /usr/share/zoneinfo/Europe/Berlin /etc/localtime

mkinitcpio -p linux

echo "Set root password"
(echo "$root_pw"; echo "$root_pw") | passwd

echo "Setup bootloader"
if [[ $boot -eq 1 ]]; then
  bootctl install
  t='Arch Linux'
  t_f="$t Fallback"
  l='/vmlinuz-linux'
  i='/initramfs-linux.img'
  i_f='/initramfs-linux-fallback.img'
  o="root=$root_part rw lang=de init=/usr/lib/systemd/systemd locale=de_DE.UTF-8"
  f='/boot/loader/entries/arch-uefi.conf'
  f_f='/boot/loader/entries/arch-uefi-fallback.conf'
  echo "title   $t" > $f
  echo "linux   $l" >> $f
  echo "initrd  $i" >> $f
  echo "options $o" >> $f

  echo "title   $t_f" > $f_f
  echo "linux   $l" >> $f_f
  echo "initrd  $i_f" >> $f_f
  echo "options $o" >> $f_f

  echo 'default arch-uefi.conf' > /boot/loader/loader.conf
  echo 'timeout 5' >> /boot/loader/loader.conf

  bootctl update
fi

echo "Add user $user"
set +e
id -u $user
ret=$?
set -e
if [[ $ret -ne 0 ]]; then
  useradd -m -g users -s $(which zsh) $user
  (echo "$user_pw"; echo "$user_pw") | passwd $user
  for group in wheel audio video input; do
    gpasswd -a $user $group
  done
fi

sed -i 's/^# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/' /etc/sudoers

echo "Install aur helper"
aur_helper

echo "Intall packages for $wm"
if [[ $wm == "i3" ]]; then
  $pacmans ${i3_pkg[@]}
  sudo -u $user $yays ${i3_aur[@]}
fi

if [[ $config -eq 2 ]]; then
  echo "Start configuration for Laptop"
  $pacmans ${laptop_pkg[@]}
  sudo -u $user $yays ${laptop_aur[@]}

  sed -i 's/^#HandlePowerKey=poweroff/HandlePowerKey=suspend/g' /etc/systemd/logind.conf
  sed -i 's/^#HandleSuspendKey=suspend/HandleSuspendKey=suspend/g' /etc/systemd/logind.conf
  sed -i 's/^#HandleHibernateKey=hibernate/HandleHibernateKey=suspend/g' /etc/systemd/logind.conf

  cat <<EOF >/etc/X11/xorg.conf.d/40-libinput.conf
Section "InputClass"
  Identifier "/dev/input/event6"
  MatchIsTouchpad "on"
  Driver "libinput"
  Option "Tapping" "off"
  Option "TappingButtonMap" "lrm"
  Option "NaturalScrolling" "true"
  Option "ClickMethod" "clickfinger"
EndSection
EOF

  cat <<EOF >/etc/udev/rules.d/backlight.rules
ACTION=="add", SUBSYSTEM=="backlight", KERNEL=="intel_backlight", GROUP="video", MODE="0664"
EOF
  cat <<EOF >/etc/udev/rules.d/99-lowbat.rules
SUBSYSTEM=="power_supply", ATTR{status}=="Discharging", ATTR{capacity}=="[0-5]", RUN+="/usr/bin/systemctl suspend"
EOF

  if [[ ! -d /etc/acpi/handlers ]]; then
    mkdir -p /etc/acpi/handlers
  fi
  cat <<EOF >/etc/acpi/handlers/bl
#!/bin/sh
step=5

# for this to work you have to install the package acpilight
case \$1 in
    -) /usr/bin/xbacklight -dec \$step;;
    +) /usr/bin/xbacklight -inc \$step;;
esac
EOF
  chmod 755 /etc/acpi/handlers/bl

  cat <<EOF >/etc/acpi/events/bl_u
event=video/brightnessup
action=/etc/acpi/handlers/bl +
EOF

  cat <<EOF >/etc/acpi/events/bl_d
event=video/brightnessdown
action=/etc/acpi/handlers/bl -
EOF
else
  sudo -u $user $yays ${desktop_aur[@]}
fi

echo "Set xorg power options"
cat <<EOF >/etc/xorg.conf.d/10-disable-xorg-power-options.conf
Section "Monitor"
  Identifier "Monitor1"
  Option "DPMS" "false"
EndSection

Section "ServerFlags"
  Option "BlankTime" "0"
EndSection
EOF

cat <<EOF >/etc/acpi/events/powerbtn
event=button/power
action=/usr/bin/i3lock && sleep 1 && /usr/bin/systemctl suspend
EOF

line_no=$(grep -noe ^allowed_types /etc/udevil/udevil.conf | cut -f1 -d:)
sed -i "$line_nos/$/, cifs/" /etc/udevil/udevil.conf

echo "Setup netctl"
cp /etc/netctl/examples/wireless-wpa /etc/netctl/wireless-wpa
cp /etc/netctl/examples/ethernet-dhcp /etc/netctl/ethernet-dhcp

echo "Enable systemd services"
for srv in acpid avahi-daemon cups.servce bluetooth.service netctl-ifplugd@eth0.service netctl-auto@wlp2s0.service; do
  systemctl enable $srv
done
for usr_srv in pulseaudio.service pulseaudio.socket; do
  sudo -u $user systemctl enable $usr_srv
done
systemctl enable --now fstrim.timer
systemctl enable --now systemd-timesycd.service

if [[ $wm == "i3" ]]; then
  systemctl enable lightdm.service
fi

echo "Install dotfiles for root"
cd /root
if [[ -d dotfiles ]];then
  rm -rf dotfiles
fi
git clone https://github.com/floriansto/dotfiles.git
./dotfiles/install.sh noconfirm

echo "Install dotfiles for $user"
cd /home/$user
if [[ ! -d Development ]]; then
  sudo -u $user mkdir Development
fi
cd Development
if [[ -d dotfiles ]];then
  rm -rf dotfiles
fi
sudo -u $user git clone https://github.com/floriansto/dotfiles.git
sudo -u $user ./dotfiles/install.sh noconfirm

echo "Set keymap"
cat <<EOF >/etc/X11/xorg.conf.d/00-keyboard.conf
Section "InputClass"
    Identifier "system-keyboard"
    MatchIsKeyboard "on"
    Option "XkbLayout" "us"
    Option "XkbVariant" "ïntl"
EndSection
EOF
echo 'KEYMAP=en_US' > /etc/vconsole.conf

echo "Install user packages"
$pacmans ${user_pkg[@]}
sudo -u $user $yays ${user_aur[@]}

if [[ $(which vivialdi-stable) ]]; then
  /opt/vivaldi-stable/update-ffmpeg
  /opt/vivaldi-stable/update-widevine
fi

echo "Install droidcam"
cd /tmp
wget -O droidcam_latest.zip https://files.dev47apps.net/linux/droidcam_1.7.2.zip
unzip droidcam_latest.zip -d droidcam
cd droidcam && ./install-client
./install-video
./install-dkms

