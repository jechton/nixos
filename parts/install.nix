{ inputs, ... }: {
  perSystem =
    {
      pkgs,
      system,
      ...
    }:
    {
      packages.install = pkgs.writeShellApplication {
        name = "install";
        runtimeInputs = with pkgs; [
          # keep-sorted start
          btrfs-progs
          coreutils
          cryptsetup
          gawk
          gnugrep
          iputils
          iw
          nixos-facter
          nixos-install-tools
          util-linux
          wpa_supplicant
          # keep-sorted end
          inputs.disko.packages.${system}.disko
        ];
        text = ''
          RED='\033[0;31m'; GRN='\033[0;32m'; YLW='\033[1;33m'; BLU='\033[0;34m'; NC='\033[0m'
          info() { printf '%b\n' "''${BLU}[INFO]''${NC}  $*"; }
          ok()   { printf '%b\n' "''${GRN}[OK]''${NC}    $*"; }
          warn() { printf '%b\n' "''${YLW}[WARN]''${NC}  $*"; }
          die()  { printf '%b\n' "''${RED}[ERROR]''${NC} $*" >&2; exit 1; }

          usage() {
            printf '%s\n' \
              "Usage: install --hostname <name> --age-key <path> [options]" \
              "" \
              "Required:" \
              "  --hostname  <name>   Must match flake.nix key and networking.hostName" \
              "  --age-key   <path>   Path to age private key file (e.g. on a USB drive)" \
              "" \
              "Optional:" \
              "  --flake     <path>   Path to flake directory (default: current directory)" \
              "  --wifi-ssid <ssid>   WiFi network name (skip if Ethernet is already connected;" \
              "                       otherwise you'll be prompted interactively)" \
              "  --wifi-pass <pass>   WiFi password" \
              "  --cores     <n>      Nix 'cores' setting, for constrained builders" \
              "  --max-jobs  <n>      Nix 'max-jobs' setting, for constrained builders" \
              "  --help               Show this help"
            exit 0
          }

          HOSTNAME=""
          AGE_KEY_FILE=""
          FLAKE_DIR="$PWD"
          WIFI_SSID=""
          WIFI_PASS=""
          CORES=""
          MAX_JOBS=""

          PARSED=$(getopt \
            --options h \
            --longoptions help,hostname:,age-key:,flake:,wifi-ssid:,wifi-pass:,cores:,max-jobs: \
            --name "install" \
            -- "$@") || usage

          eval set -- "$PARSED"

          while true; do
            case "$1" in
              --hostname)  HOSTNAME="$2";     shift 2 ;;
              --age-key)   AGE_KEY_FILE="$2"; shift 2 ;;
              --flake)     FLAKE_DIR="$2";    shift 2 ;;
              --wifi-ssid) WIFI_SSID="$2";    shift 2 ;;
              --wifi-pass) WIFI_PASS="$2";    shift 2 ;;
              --cores)     CORES="$2";        shift 2 ;;
              --max-jobs)  MAX_JOBS="$2";     shift 2 ;;
              -h|--help)   usage ;;
              --)          shift; break ;;
              *)           die "Unknown argument: $1" ;;
            esac
          done

          [[ $EUID -eq 0 ]]        || die "Run as root: sudo install [args]"
          [[ -n "$HOSTNAME" ]]     || die "Missing --hostname"
          [[ -n "$AGE_KEY_FILE" ]] || die "Missing --age-key"
          [[ -f "$AGE_KEY_FILE" ]] || die "Age key file '$AGE_KEY_FILE' not found."

          grep -q "^AGE-SECRET-KEY-" "$AGE_KEY_FILE" \
            || die "'$AGE_KEY_FILE' doesn't look like an age private key."

          if [[ -n "$WIFI_SSID" && -z "$WIFI_PASS" ]]; then
            die "--wifi-ssid given but --wifi-pass is missing."
          fi

          NIX_CONFIG='experimental-features = nix-command flakes
          accept-flake-config = true'
          [[ -n "$CORES" ]] && NIX_CONFIG="$NIX_CONFIG
          cores = $CORES"
          [[ -n "$MAX_JOBS" ]] && NIX_CONFIG="$NIX_CONFIG
          max-jobs = $MAX_JOBS"
          export NIX_CONFIG

          # Networking
          connect_wifi() {
            local ssid="$1" pass="$2"
            info "Connecting to WiFi: $ssid"
            systemctl start wpa_supplicant

            WIFI_IFACE=$(iw dev 2>/dev/null | awk '/Interface/{print $2}' | head -1)
            [[ -n "$WIFI_IFACE" ]] || die "No wireless interface found."
            info "Wireless interface: $WIFI_IFACE"

            wpa_passphrase "$ssid" "$pass" \
              | tee "/etc/wpa_supplicant/wpa_supplicant-''${WIFI_IFACE}.conf" >/dev/null
            systemctl restart "wpa_supplicant@''${WIFI_IFACE}.service"
            sleep 3

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
            ok "Network connected."
          else
            info "Checking for an existing network connection (e.g. Ethernet) ..."
            if ping -c1 -W2 1.1.1.1 &>/dev/null; then
              ok "Network already up."
            else
              warn "No network detected."

              [[ -t 0 ]] || die "No network, and no --wifi-ssid given in a non-interactive session."

              SCAN_IFACE=$(iw dev 2>/dev/null | awk '/Interface/{print $2}' | head -1)
              [[ -n "$SCAN_IFACE" ]] \
                || die "No network and no wireless interface found. Connect Ethernet and retry."

              info "Scanning for WiFi networks on $SCAN_IFACE ..."
              ip link set "$SCAN_IFACE" up
              mapfile -t NETWORKS < <(
                iw dev "$SCAN_IFACE" scan 2>/dev/null \
                  | awk -F'SSID: ' '/SSID: /{print $2}' \
                  | grep -v '^$' | sort -u
              )

              CHOSEN=""
              if [[ ''${#NETWORKS[@]} -gt 0 ]]; then
                echo "Available networks:"
                select opt in "''${NETWORKS[@]}" "Enter manually"; do
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
              ok "Network connected."
            fi
          fi

          # Partition and format
          info "Running disko ($HOSTNAME) ..."
          disko --mode destroy,format,mount --flake "$FLAKE_DIR#$HOSTNAME"
          ok "Disko complete."

          # agenix: copy age private key before first boot so secrets can be decrypted
          info "Installing age private key → /mnt/persist/age/key.txt ..."
          mkdir -p /mnt/persist/age
          chmod 700 /mnt/persist/age
          cp "$AGE_KEY_FILE" /mnt/persist/age/key.txt
          chmod 400 /mnt/persist/age/key.txt
          ok "Age key installed."

          # Impermanence: take blank btrfs snapshots before any writes land
          info "Preparing blank btrfs snapshots for impermanence ..."

          if [[ -e /dev/disk/by-partlabel/luks ]]; then
            if ! [[ -e /dev/mapper/cryptroot ]]; then
              cryptsetup open /dev/disk/by-partlabel/luks cryptroot
            fi
            BTRFS_DEV=/dev/mapper/cryptroot
          else
            BTRFS_DEV=/dev/disk/by-partlabel/nixos
          fi

          umount /mnt 2>/dev/null || true
          mount -o subvolid=5 "$BTRFS_DEV" /mnt

          btrfs subvolume snapshot -r /mnt/root /mnt/root-blank
          btrfs subvolume list /mnt | grep -E "\broot-blank\b" \
            || die "Snapshot verification failed — root-blank not found."
          ok "root-blank created."

          btrfs subvolume snapshot -r /mnt/home /mnt/home-blank
          btrfs subvolume list /mnt | grep -E "\bhome-blank\b" \
            || die "Snapshot verification failed — home-blank not found."
          ok "home-blank created."

          umount /mnt

          # Re-mount with disko
          info "Re-mounting partitions under /mnt ..."
          disko --mode mount --flake "$FLAKE_DIR#$HOSTNAME"

          # Installer environments often have no swap at all, so a heavy
          # nixos-install (large closures, kernel builds) can get OOM-killed
          # outright. Borrow space on the already-mounted target's swap
          # subvolume (nodatacow, uncompressed) for the duration of the install.
          INSTALL_SWAP=/mnt/persist/swap/install-swapfile
          if [[ -d /mnt/persist/swap ]]; then
            info "Setting up temporary install-time swap ..."
            # plain truncate leaves holes, which the kernel refuses to swap
            # on; mkswapfile allocates real extents and formats it in one go
            btrfs filesystem mkswapfile --size 4G "$INSTALL_SWAP"
            swapon "$INSTALL_SWAP"
            trap 'swapoff "$INSTALL_SWAP" 2>/dev/null; rm -f "$INSTALL_SWAP"' EXIT
            ok "Temporary install swap active (4G)."
          else
            warn "No /mnt/persist/swap subvolume found — skipping temporary install swap."
          fi

          # Generate facter.json if the host profile is new
          FACTER_DST="$FLAKE_DIR/hosts/$HOSTNAME/facter.json"

          if [[ -f "$FACTER_DST" ]]; then
            info "Existing host profile found at '$FACTER_DST'."
            warn "Skipping hardware report generation to preserve existing config."
          else
            info "No existing profile found. Generating facter.json ..."
            mkdir -p "$(dirname "$FACTER_DST")"
            nixos-facter -o "$FACTER_DST"
            ok "facter.json saved → hosts/$HOSTNAME/"
          fi

          # Copy flake so nixos-install can reference it
          info "Copying flake to /mnt/etc/nixos ..."
          mkdir -p /mnt/etc/nixos
          cp -r "$FLAKE_DIR"/. /mnt/etc/nixos/
          ok "Flake copied."

          # Install
          info "Running nixos-install --flake /mnt/etc/nixos#$HOSTNAME ..."
          nixos-install --no-root-passwd \
            --flake "/mnt/etc/nixos#$HOSTNAME" \
            --option accept-flake-config true

          printf '\n'
          ok "============================================================"
          ok "  Installation complete!"
          ok "============================================================"
          printf '\n'
          warn "Rebooting in 10 seconds... (Ctrl-C to cancel)"
          for i in {10..1}; do printf '\r  %ds...' "$i"; sleep 1; done
          printf '\n'
          reboot
        '';
      };
    };
}
