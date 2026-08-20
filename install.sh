#!/usr/bin/env bash
# Self-contained installer entrypoint for the live ISO shell.
#
# Networking uses nmcli, guaranteed present on NixOS installer images
# (unlike iw/wpa_supplicant), since `nix run .#install` needs network first.
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  exec sudo -H -E "$0" "$@"
fi

FLAKE_DIR="$(dirname "$(readlink -f "$0")")"

RED='\033[0;31m'; GRN='\033[0;32m'; YLW='\033[1;33m'; BLU='\033[0;34m'; NC='\033[0m'
info() { printf '%b\n' "${BLU}[INFO]${NC}  $*"; }
ok()   { printf '%b\n' "${GRN}[OK]${NC}    $*"; }
warn() { printf '%b\n' "${YLW}[WARN]${NC}  $*"; }
die()  { printf '%b\n' "${RED}[ERROR]${NC} $*" >&2; exit 1; }

usage() {
  printf '%s\n' \
    "Usage: install.sh --hostname <name> --age-key <path> [options]" \
    "" \
    "Required:" \
    "  --hostname  <name>   Must match flake.nix key and networking.hostName" \
    "  --age-key   <path>   Path to age private key file (e.g. on a USB drive)" \
    "" \
    "Optional:" \
    "  --flake     <path>   Path to flake directory (default: this script's directory)" \
    "  --wifi-ssid <ssid>   WiFi network name (skip if Ethernet is already connected;" \
    "                       otherwise you'll be prompted interactively)" \
    "  --wifi-pass <pass>   WiFi password" \
    "  --cores     <n>      Nix 'cores' setting, for constrained builders" \
    "  --max-jobs  <n>      Nix 'max-jobs' setting, for constrained builders" \
    "  --yes-wipe-all-disks Skip disko's interactive confirmation before wiping disks" \
    "  --help               Show this help"
  exit 0
}

HOSTNAME=""
AGE_KEY_FILE=""
WIFI_SSID=""
WIFI_PASS=""
CORES=""
MAX_JOBS=""
YES_WIPE_ALL_DISKS=""

PARSED=$(getopt \
  --options h \
  --longoptions help,hostname:,age-key:,flake:,wifi-ssid:,wifi-pass:,cores:,max-jobs:,yes-wipe-all-disks \
  --name "install.sh" \
  -- "$@") || usage

eval set -- "$PARSED"

while true; do
  case "$1" in
    --hostname)           HOSTNAME="$2";        shift 2 ;;
    --age-key)            AGE_KEY_FILE="$2";    shift 2 ;;
    --flake)              FLAKE_DIR="$2";       shift 2 ;;
    --wifi-ssid)          WIFI_SSID="$2";       shift 2 ;;
    --wifi-pass)          WIFI_PASS="$2";       shift 2 ;;
    --cores)              CORES="$2";           shift 2 ;;
    --max-jobs)           MAX_JOBS="$2";        shift 2 ;;
    --yes-wipe-all-disks) YES_WIPE_ALL_DISKS=1;  shift ;;
    -h|--help)            usage ;;
    --)                   shift; break ;;
    *)                    die "Unknown argument: $1" ;;
  esac
done

[[ -n "$HOSTNAME" ]]     || die "Missing --hostname"
[[ -n "$AGE_KEY_FILE" ]] || die "Missing --age-key"
[[ -f "$AGE_KEY_FILE" ]] || die "Age key file '$AGE_KEY_FILE' not found."

if [[ -n "$WIFI_SSID" && -z "$WIFI_PASS" ]]; then
  die "--wifi-ssid given but --wifi-pass is missing."
fi

WIFI_PROFILE=""

# Carried into the installed system's /etc/NetworkManager/system-connections
# (see modules/system/impermanence.nix) so it's online on first boot.
write_nm_profile() {
  local ssid="$1" pass="$2" uuid
  uuid=$(cat /proc/sys/kernel/random/uuid)
  WIFI_PROFILE=$(mktemp --suffix=.nmconnection)
  cat > "$WIFI_PROFILE" <<EOF
[connection]
id=$ssid
uuid=$uuid
type=wifi

[wifi]
mode=infrastructure
ssid=$ssid

[wifi-security]
key-mgmt=wpa-psk
psk=$pass

[ipv4]
method=auto

[ipv6]
method=auto
addr-gen-mode=default
EOF
  chmod 600 "$WIFI_PROFILE"
}

has_wifi_device() {
  nmcli -t -f TYPE device status 2>/dev/null | grep -q '^wifi$'
}

connect_wifi() {
  local ssid="$1" pass="$2"
  info "Connecting to WiFi: $ssid"
  systemctl start NetworkManager
  nmcli device wifi rescan &>/dev/null || true
  sleep 2

  nmcli device wifi connect "$ssid" password "$pass" || return 1

  info "Waiting for network..."
  for _ in {1..20}; do
    ping -c1 -W1 1.1.1.1 &>/dev/null && return 0
    sleep 1
  done
  return 1
}

if [[ -n "$WIFI_SSID" ]]; then
  connect_wifi "$WIFI_SSID" "$WIFI_PASS" \
    || die "No network. Check --wifi-ssid / --wifi-pass."
  write_nm_profile "$WIFI_SSID" "$WIFI_PASS"
  ok "Network connected."
else
  info "Checking for an existing network connection (e.g. Ethernet) ..."
  if ping -c1 -W2 1.1.1.1 &>/dev/null; then
    ok "Network already up."
  else
    warn "No network detected."

    [[ -t 0 ]] || die "No network, and no --wifi-ssid given in a non-interactive session."

    systemctl start NetworkManager
    has_wifi_device \
      || die "No network and no wireless interface found. Connect Ethernet and retry."

    info "Scanning for WiFi networks ..."
    nmcli device wifi rescan &>/dev/null || true
    sleep 2
    mapfile -t NETWORKS < <(
      nmcli -t -f SSID device wifi list 2>/dev/null \
        | grep -v '^$' | sort -u
    )

    CHOSEN=""
    if [[ ${#NETWORKS[@]} -gt 0 ]]; then
      echo "Available networks:"
      select opt in "${NETWORKS[@]}" "Enter manually"; do
        if [[ "$opt" == "Enter manually" || -z "$opt" ]]; then
          read -rp "SSID: " CHOSEN
        else
          CHOSEN="$opt"
        fi
        break
      done
    else
      warn "No networks found in scan."
      read -rp "SSID: " CHOSEN
    fi
    [[ -n "$CHOSEN" ]] || die "No SSID given."

    read -rsp "Password for '$CHOSEN': " CHOSEN_PASS
    echo

    connect_wifi "$CHOSEN" "$CHOSEN_PASS" || die "WiFi connection failed."
    write_nm_profile "$CHOSEN" "$CHOSEN_PASS"
    ok "Network connected."
  fi
fi

export NIX_CONFIG="experimental-features = nix-command flakes
accept-flake-config = true"

ARGS=(--hostname "$HOSTNAME" --age-key "$AGE_KEY_FILE" --flake "$FLAKE_DIR")
[[ -n "$WIFI_PROFILE" ]] && ARGS+=(--wifi-profile "$WIFI_PROFILE")
[[ -n "$CORES" ]]    && ARGS+=(--cores "$CORES")
[[ -n "$MAX_JOBS" ]] && ARGS+=(--max-jobs "$MAX_JOBS")
[[ -n "$YES_WIPE_ALL_DISKS" ]] && ARGS+=(--yes-wipe-all-disks)

exec nix run "${FLAKE_DIR}#install" -- "${ARGS[@]}"
