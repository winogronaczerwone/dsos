#/bin/zsh
say() {
  gum style --padding "0 0 0 $PADDING_LEFT" "$@"
}

ESCAPE() {
    echo "${1//$/\\$}"
}

pacman -Sy --noconfirm whois gum

clear
say "Welcome to the installer!"

say "Please select the disk you want to install Arch Linux on:"
DISK=$(gum choose $(lsblk -dno NAME | grep -v "loop" | grep -v "sr0" | sed 's/^/\/dev\//'))

say "Please select the disk encryption and root password:"
PASSWORD=$(gum input --password)

  cat <<EOF>user_configuration.json
{
  "archinstall-language": "Polish",
  "additional-repositories": ["multilib"],
  "audio_config": { "audio": "pulseaudio" },
  "bootloader_config": {
    "bootloader": "limine",
    "uki": false,
    "removable": false
  },
  "hostname": "dsos",
  "kernels": ["linux"],
  "ntp": true,
  "packages": ["gnome-initial-setup", "gnome", "prismlauncher"],
  "swap": true,
  "timezone": "UTC",
  "custom-commands": ["systemctl enable NetworkManager", "systemctl enable gdm"],
  "network_config": {
    "type": "iso"
  },
}
EOF

cat <<EOF>user_credentials.json
{
    "root_enc_password": "$(ESCAPE $(mkpasswd -m yescrypt "${PASSWORD}"))",
}
EOF


archinstall --config user_configuration.json --creds user_credentials.json --script only_hd