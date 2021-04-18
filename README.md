My installation script for arch linux

# Functionality
Before the script starts, it asks for the following options for your installation:
* root password
* new user to add
* password for the new user
* bootmethod: UEFI
    * Currently only UEFI is supported using the systemd bootloader
* Select between `laptop` or `desktop` installation
    * There are some differences, like touchpad drivers or display brightness configuration for the laptop
* Root partition `/dev/sdXY`
* Selector for the windowmanager
    * Currently only i3 is supported
The goal is to automatically install all needed packages and do all configuration to have a fully functional arch linux system running on your machine, ready to work with.

# Usage
Clone this repo to your freshly installed arch
 You already need to be logged in via `arch-chroot`.
Then simply call as root user
```sh
./install.sh
```

# Configuration
## Locale
The locale configuration (language, keyboard layourt, ...) is currently hardcoded in the script and needs to be changed manually.

**Current Settings**
* German system language and locale
* US international keyboard layout
* Europe/Berlin as timezone

## Installed packages
You can simply add/remove packages at the beginning of the script to the desired arrays.

## User parameters
The user is added to the following groups
```
wheel audio video input
```
The default shell is `zsh`.

## Network
Currently `netctl` is used to manage your network connections.
The network devices (WiFi and Ethernet) are also hardcoded for both, laptop and desktop configurations.

## Laptop
For the laptop, the following special configuration is done
* Touchpad configuration for `libinput`
* Touchpad gestures using `libinput-gestures`
* `udev` and `acpi` rules for adjusting display brighness (`intel-backlight` driver is used)

## Desktop
Special configuration for the desktop
* Configure AMD graphics card fan speeds (using `amdgpu-fan`)
* Disable hardware speaker
* Fixes for audio noise

## AUR helper
As AUR helper `paru` is installed.

## Droidcam
Droidcam is installed using their installation instructions
* Get the latest `droidcam.zip` from their website
* Run the installation script (`./install-client`)
To install video and dkms scripts a reboot is needed

