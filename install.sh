#!/usr/bin/env bash
# /usr/local/bin/amos-r-install.sh
# Instalator amos-r: partycjonowanie + hasło roota + archinstall
set -euo pipefail

CONFIG_SRC="${1:-/etc/amos-r/config.json}"
CONFIG_OUT="/tmp/amos-r-config.json"
MP="/mnt/archinstall"
DRY_RUN="${DRY_RUN:-0}"

die()  { printf '\033[31mBŁĄD:\033[0m %s\n' "$*" >&2; exit 1; }
info() { printf '\033[36m==>\033[0m %s\n' "$*"; }

# --- zależności ---------------------------------------------------------
for cmd in sgdisk mkfs.fat mkfs.btrfs python3 lsblk; do
  command -v "$cmd" >/dev/null || die "brak polecenia: $cmd"
done
[[ -f "$CONFIG_SRC" ]] || die "nie znaleziono $CONFIG_SRC"

# --- wybór dysku --------------------------------------------------------
info "Dostępne dyski:"
lsblk -dpno NAME,SIZE,MODEL | grep -v loop || true
read -rp "Dysk docelowy [/dev/nvme0n1]: " DISK
DISK="${DISK:-/dev/nvme0n1}"
[[ -b "$DISK" ]] || die "$DISK nie jest block device"

read -rp "UWAGA: cały $DISK zostanie wyczyszczony. Kontynuować? [t/N]: " OK
[[ "${OK,,}" == t* ]] || die "przerwano"

# --- hasło roota --------------------------------------------------------
read -rsp "Hasło roota: " ROOT_PASS; echo
read -rsp "Powtórz hasło: " ROOT_PASS2; echo
[[ "$ROOT_PASS" == "$ROOT_PASS2" ]] || die "hasła się różnią"
[[ -n "$ROOT_PASS" ]] || die "hasło nie może być puste"

read -rp "Szyfrować root przez LUKS2? [t/N]: " ENC

# --- nazwy partycji (nvme/mmc vs sd/vd) ---------------------------------
part() {
  local disk="$1" num="$2"
  if [[ "$disk" =~ [0-9]$ ]]; then echo "${disk}p${num}"; else echo "${disk}${num}"; fi
}
ESP="$(part "$DISK" 1)"
ROOT_PART="$(part "$DISK" 2)"

if [[ "$DRY_RUN" == 1 ]]; then
  info "[dry-run] ESP=$ESP ROOT=$ROOT_PART LUKS=${ENC:-n}"
  exit 0
fi

# --- partycjonowanie ----------------------------------------------------
info "Czyszczę tablicę partycji..."
wipefs -a "$DISK"
sgdisk --zap-all "$DISK"
sgdisk -n 1:0:+512M -t 1:ef00 -c 1:ESP  "$DISK"
sgdisk -n 2:0:0     -t 2:8304 -c 2:ROOT "$DISK"
udevadm settle

mkfs.fat -F32 -n ESP "$ESP"

# --- opcjonalny LUKS ----------------------------------------------------
if [[ "${ENC,,}" == t* ]]; then
  info "Szyfruję $ROOT_PART (LUKS2)..."
  cryptsetup luksFormat --type luks2 "$ROOT_PART"
  cryptsetup open "$ROOT_PART" cryptroot
  ROOT_DEV="/dev/mapper/cryptroot"
else
  ROOT_DEV="$ROOT_PART"
fi

mkfs.btrfs -f -L ROOT "$ROOT_DEV"

# --- subwolumeny btrfs --------------------------------------------------
info "Tworzę subwolumeny..."
mount "$ROOT_DEV" "$MP"
btrfs subvolume create "$MP/@"     >/dev/null
btrfs subvolume create "$MP/@home" >/dev/null
btrfs subvolume create "$MP/@log"  >/dev/null
btrfs subvolume create "$MP/@pkg"  >/dev/null
umount "$MP"

OPTS="compress=zstd,noatime"
mount -o "$OPTS,subvol=@"     "$ROOT_DEV" "$MP"
mkdir -p "$MP/home" "$MP/var/log" "$MP/var/cache/pacman/pkg" "$MP/boot"
mount -o "$OPTS,subvol=@home" "$ROOT_DEV" "$MP/home"
mount -o "$OPTS,subvol=@log"  "$ROOT_DEV" "$MP/var/log"
mount -o "$OPTS,subvol=@pkg"  "$ROOT_DEV" "$MP/var/cache/pacman/pkg"
mount "$ESP" "$MP/boot"

info "Zamontowane:"
findmnt -R "$MP" || true

# --- sprzątanie przy błędzie -------------------------------------------
cleanup() {
  local rc=$?
  if (( rc != 0 )); then
    info "Błąd — odmontowuję..."
    umount -R "$MP" 2>/dev/null || true
    cryptsetup close cryptroot 2>/dev/null || true
  fi
  rm -f "$CONFIG_OUT"
}
trap cleanup EXIT

# --- wstrzyknięcie disk_config + hasła roota ---------------------------
info "Generuję konfigurację archinstall..."
python3 - "$CONFIG_SRC" "$CONFIG_OUT" "$ROOT_PASS" <<'PY'
import json, shlex, sys

src, dst, root_pass = sys.argv[1], sys.argv[2], sys.argv[3]

with open(src, encoding="utf-8") as f:
    cfg = json.load(f)

# tryb zweryfikowany w dokumentacji: nic nie partycjonujemy,
# instalujemy na tym, co zamontowane pod /mnt/archinstall
cfg["disk_config"] = {
    "config_type": "pre_mounted_config",
    "mountpoint": "/mnt/archinstall",
}

cmds = cfg.get("custom-commands") or []
if isinstance(cmds, str):
    cmds = [cmds]

# chpasswd działa w chroot; shlex chroni przed apostrofami w haśle
payload = shlex.quote("root:" + root_pass)
cmds.append(f"printf '%s\\n' {payload} | chpasswd")

cfg["custom-commands"] = cmds

with open(dst, "w", encoding="utf-8") as f:
    json.dump(cfg, f, indent=2, ensure_ascii=False)

print(f"  disk_config: pre_mounted_config -> /mnt/archinstall")
print(f"  custom-commands: {len(cmds)} wpis(ów)")
PY

# --- odpalenie archinstall ---------------------------------------------
info "Startuję archinstall..."
archinstall --config "$CONFIG_OUT" --silent

info "Gotowe. Zanim zrestartujesz, sprawdź /var/log/archinstall/install.log"