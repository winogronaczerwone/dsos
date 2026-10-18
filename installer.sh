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
          "device_modifications": [
            {
                "device": "${DISK}",
                "partitions": [
                    {
                        "btrfs": [],
                        "dev_path": null,
                        "flags": [
                            "boot",
                            "esp"
                        ],
                        "fs_type": "fat32",
                        "mount_options": [],
                        "mountpoint": "/boot",
                        "obj_id": "96e5fc66-5956-418b-a8cc-b08037714215",
                        "size": {
                            "sector_size": {
                                "unit": "B",
                                "value": 512
                            },
                            "unit": "GiB",
                            "value": 1
                        },
                        "start": {
                            "sector_size": {
                                "unit": "B",
                                "value": 512
                            },
                            "unit": "MiB",
                            "value": 1
                        },
                        "status": "create",
                        "type": "primary"
                    },
                    {
                        "btrfs": [
                            {
                                "mountpoint": "/",
                                "name": "@"
                            },
                            {
                                "mountpoint": "/home",
                                "name": "@home"
                            },
                            {
                                "mountpoint": "/var/log",
                                "name": "@log"
                            },
                            {
                                "mountpoint": "/var/cache/pacman/pkg",
                                "name": "@pkg"
                            }
                        ],
                        "dev_path": null,
                        "flags": [],
                        "fs_type": "btrfs",
                        "mount_options": [
                            "compress=zstd"
                        ],
                        "mountpoint": null,
                        "obj_id": "9887aad9-4abc-468c-bb01-26f3fec9fc11",
                        "size": {
                            "sector_size": {
                                "unit": "B",
                                "value": 512
                            },
                            "unit": "B",
                            "value": 1023133351936
                        },
                        "start": {
                            "sector_size": {
                                "unit": "B",
                                "value": 512
                            },
                            "unit": "B",
                            "value": 1074790400
                        },
                        "status": "create",
                        "type": "primary"
                    }
                ],
                "wipe": true
            }
        ],
    }
  ]
}
EOF

cat <<EOF>user_credentials.json
{
    "root_enc_password": "$(ESCAPE $(mkpasswd -m yescrypt "${PASSWORD}"))",
}
EOF


gum confirm "Do you want to start the installation?" && archinstall --config user_configuration.json --silent