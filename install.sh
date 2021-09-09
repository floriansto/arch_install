#!/bin/bash

set -e
trap 'error_exit $LINENO $?' ERR SIGTERM SIGINT

pacmans="pacman -S --noconfirm --needed"
aur="paru -S --noconfirm --needed"

base_pkg=(acpid acpilight alacritty alsa-utils avahi bat bluez bluez-utils cifs-utils cron cups curl dhcpcd dialog dkms efibootmgr git gvfs-smb htop ifplugd jq libinput linux-headers man netctl noto-fonts-emoji ntp openssh p7zip pipewire-pulse pulseaudio-alsa pulsemixer python python-pip ranger rsync scrot seahorse sshfs sudo ttf-dejavu ttf-font-awesome ttf-nerd-fonts-symbols udevil unzip upower vim wget wpa_supplicant wqy-zenhei zsh)

x11_pkg=(feh redshift xorg-server xorg-xrandr)
x11_aur=()
wayland_pkg=(wayland wayland-protocols wlroots)
wayland_aur=(redshift-wayland-git)

i3_pkg=(arandr dunst feh i3lock i3status-rust i3-wm iw lightdm lightdm-gtk-greeter playerctl rofi xss-lock)
i3_aur=(autotiling xidlehook)
i3_greeter=lightdm

sway_pkg=(sway swaybg swayidle swaylock wofi)
sway_aur=(greetd greetd-gtkgreet sway-audio-idle-inhibit-git)
sway_greeter=greetd

laptop_pkg=(xbindkeys xdotool)
laptop_aur=(libinput-gestures)

desktop_aur=(amdgpu-fan obinskit rtl8814au-aircrack-dkms-git rtl8761b-fw)

user_pkg=(ctags feh file-roller firefox gimp gparted gpicview gvfs-mtp gvfs-gphoto2 imv libreoffice lm_sensors octave qpdfview speedcrunch thunar thunar-volman thunar-archive-plugin thunderbird tumbler vivaldi vlc xfce4-settings zip)
user_aur=(bitwarden-bin nextcloud-client plex-media-player spotify teams zoom ncspot)

is_x11=0

function error_exit() {
  echo "Errorcode $2 in line $1"
}

function aur_helper() {
  cd /tmp
  if [[ -d paru ]]; then
    rm -rf paru
  fi
  git clone https://aur.archlinux.org/paru.git
  chown -R $user:users paru/
  cd paru
  sudo -u $user makepkg -si --noconfirm
}

function bootmethod() {
  read -p 'Bootmethod: UEFI (1): ' boot
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
  read -p 'Windowmanager: i3 (1), sway(2): ' wm_idx
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
while [[ $config != "1" ]]; do
  config
done
root_part
while [[ ! -e $root_part ]]; do
  root_part
done
wm
while [[ $wm_idx != "1"  || $wm_idx != "2" ]]; do
  wm
done
if [[ $wm_idx -eq 1 ]]; then
  wm_pkg=($i3_pkg $x11_pkg)
  wm_aur=($i3_aur $x11_aur)
  is_x11=1
  greeter=$i3_greeter
  wm='i3'
elif [[ $wm_idx -eq 2 ]]; then
  wm_pkg=($sway_pkg $wayland_pkg)
  wm_aur=($sway_aur $wayland_aur)
  greeter=$sway_greeter
  wm='sway'
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

echo "Enable time synchronization"
timedatectl set-ntp on

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

echo "Set zsh for root"
chsh -s $(which zsh)

sed -i 's/^# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/' /etc/sudoers

echo "Install aur helper"
aur_helper

echo "Intall packages for $wm"
$pacmans ${wm_pkg[@]}
sudo -u $user $aur ${wm_aur[@]}

if [[ $config -eq 2 ]]; then
  echo "Start configuration for Laptop"
  $pacmans ${laptop_pkg[@]}
  sudo -u $user $aur ${laptop_aur[@]}

  if [[ $is_x11 -eq 1 ]]; then
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
  fi

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

  cat <<EOF >/etc/netctl/ethernet-dhcp
Description='A basic dhcp ethernet connection'
Interface=enp4s0
Connection=ethernet
IP=dhcp
EOF
  systemctl enable netctl-ifplugd@enp4s0.service
  systemctl enable netctl-auto@wlp2s0.service

fi

if [[ $config -eq 1 ]]; then

  sudo -u $user $aur ${desktop_aur[@]}
  cat <<EOF >/etc/amdgpu-fan.yml
# /etc/amdgpu-fan.yml
# eg:

speed_matrix:  # -[temp(*C), speed(0-100%)]
- [0, 0]
- [65, 0]
- [80, 75]
- [90, 100]

# optional
# cards:  # can be any card returned from
#         # ls /sys/class/drm | grep "^card[[:digit:]]$"
# - card0
EOF
  systemctl enable amdgpu-fan.service
  systemctl start amdgpu-fan.service

  cat <<EOF >/etc/modprobe.d/nobeep.conf
blacklist pcspkr
EOF

  cat <<EOF >/etc/modprobe.d/audio-fixes.conf
options snd_hda_intel power_save=0
EOF

  cat <<EOF >/etc/netctl/ethernet-dhcp
Description='A basic dhcp ethernet connection'
Interface=enp4s0
Connection=ethernet
IP=dhcp
EOF
  systemctl enable netctl-ifplugd@enp4s0.service
  systemctl enable netctl-auto@wlp6s0u2.service

fi

sed -i 's/^#HandlePowerKey=poweroff/HandlePowerKey=suspend/g' /etc/systemd/logind.conf
sed -i 's/^#HandleSuspendKey=suspend/HandleSuspendKey=suspend/g' /etc/systemd/logind.conf
sed -i 's/^#HandleHibernateKey=hibernate/HandleHibernateKey=suspend/g' /etc/systemd/logind.conf

if [[ $is_x11 -eq 1 ]]; then
  echo "Set xorg power options"
  cat <<EOF >/etc/X11/xorg.conf.d/10-disable-xorg-power-options.conf
Section "Monitor"
  Identifier "Monitor1"
  Option "DPMS" "false"
EndSection

Section "ServerFlags"
  Option "BlankTime" "0"
EndSection
EOF
fi

cat <<EOF >/etc/acpi/events/powerbtn
event=button/power
action=/usr/bin/i3lock && sleep 1 && /usr/bin/systemctl suspend
EOF

cat <<EOF >/usr/share/applications/vim-term.desktop
[Desktop Entry]
Encoding=UTF-8
Type=Application
NoDisplay=true
Name=vim-term
Exec=i3-sensible-terminal -e 'vim %F'
Keywords=Text;editor;
Icon=gvim
Categories=Utility;TextEditor;
MimeType=text/english;text/plain;text/x-makefile;text/x-c++hdr;text/x-c++src;text/x-chdr;text/x-csrc;text/x-java;text/x-moc;text/x-pascal;text/x-tcl;text/x-tex;application/x-shellscript;text/x-c;text/x-c++;
EOF

echo "Setup udevil"
line_no=$(grep -noe ^allowed_types /etc/udevil/udevil.conf | cut -f1 -d:)
sed -i "${line_no}s/$/, cifs/" /etc/udevil/udevil.conf

echo "Enable systemd services"
for srv in acpid avahi-daemon cronie.service cups.service bluetooth.service; do
  systemctl enable $srv
  systemctl start $srv
done
set +e
systemctl enable --now fstrim.timer
systemctl enable --now systemd-timesycd.service
set -e

echo "Setup $greeter greeter"
if [[ $wm == "sway" ]]; then
  cat <<EOF >/etc/greetd/config.toml
[terminal]
vt = 1

[default_session]
command = "agreety --cmd sway"
user = "greeter"
EOF
fi
systemctl enable $greeter.service
systemctl start $greeter.service

echo "Install dotfiles for root"
cd /root
if [[ -d dotfiles ]];then
  rm -rf dotfiles
fi
git clone https://github.com/floriansto/dotfiles.git
./dotfiles/install.sh

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
if [[ $config -eq 1 ]]; then
  sudo -u $user ./dotfiles/install.sh -v standard -e backlight -e battery -g -dw wlp6s0u2 -de enp4s0
else
  sudo -u $user ./dotfiles/install.sh -v standard -g -dw wlp2s0 -de enp4s0
fi

cd /opt
git clone https://github.com/markasoftware/bing-wallpaper-linux.git

echo "Set keymap"
cat <<EOF >/etc/X11/xorg.conf.d/00-keyboard.conf
Section "InputClass"
    Identifier "system-keyboard"
    MatchIsKeyboard "on"
    Option "XkbLayout" "us"
    Option "XkbVariant" "altgr-intl"
EndSection
EOF
echo 'KEYMAP=en_US' > /etc/vconsole.conf

echo "smb fixes"
if [[ ! -d /etc/samba ]]; then
  mkdir /etc/samba
fi
cat <<EOF >/etc/samba/smb.conf
[global]
    client min protocol = SMB3
EOF
cat <<EOF >/var/spool/cron/root
@reboot killall gvfsd-smb-browse
EOF

echo "Install user packages"
$pacmans ${user_pkg[@]}
sudo -u $user $aur ${user_aur[@]}

if [[ -d /opt/vivaldi ]]; then
  /opt/vivaldi/update-ffmpeg
  /opt/vivaldi/update-widevine
fi

echo "Clone linux scripts"
cd /opt
git clone https://github.com/floriansto/scripts_linux.git
chown -R $user:users scripts_linux
cat <<EOF >>/var/spool/cron/root
*/30 * * * * /opt/scripts_linux/startBackup.sh $hostname 5176 > /dev/null 2>&1
EOF
cat <<EOF >/var/spool/cron/$user
0 */2 * * * /opt/scripts_linux/backupPacman.sh > /dev/null
EOF
./keychron/install.sh

echo "Setup ssh"
ssh=/etc/ssh/sshd_config
sed -i 's/^#Port 22/Port 5176/' $ssh
sed -i 's/^#PermitRootLogin prohibit-password/PermitRootLogin prohibit-password/' $ssh
sed -i 's/^#PubkeyAuthentication yes/PubkeyAuthentication yes/' $ssh

echo "Install droidcam"
cd /opt
wget -O droidcam_latest.zip https://files.dev47apps.net/linux/droidcam_1.7.2.zip
unzip droidcam_latest.zip -d droidcam
rm droidcam_latest.zip
cd droidcam && ./install-client

