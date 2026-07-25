#!/usr/bin/env bash
# Thin wrapper around `nix run .#install` so the live ISO shell doesn't need
# --extra-experimental-features or an interactive flake-config accept prompt
# typed in by hand every time.
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  exec sudo -H -E "$0" "$@"
fi

FLAKE_DIR="$(dirname "$(readlink -f "$0")")"

export NIX_CONFIG="experimental-features = nix-command flakes
accept-flake-config = true"

exec nix run "${FLAKE_DIR}#install" -- "$@"
