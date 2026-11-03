#!/usr/bin/env bash
# Show base16 palettes in the terminal with color names.
# Usage: palette.sh [-l|--list] [scheme-name | path/to/scheme.yaml|json]...
# No arguments: the active stylix palette (~/.config/stylix/palette.json).
set -euo pipefail

schemes_dir() {
  local current
  current=$(nix eval --raw /etc/nixos#nixosConfigurations.floptop.config.stylix.base16Scheme)
  dirname "$current"
}

names=(
  "Background" "Lighter BG" "Selection" "Comments"
  "Dark FG" "Foreground" "Light FG" "Lightest"
  "Red" "Orange" "Yellow" "Green"
  "Cyan" "Blue" "Purple" "Brown"
)

# Neutral gray panel so the terminal's own background doesn't skew perception.
width=46
panel=$'\e[48;2;128;128;128m\e[38;2;0;0;0m'
reset=$'\e[0m'
row() { printf '%s%-*s%s\n' "$panel" "$width" "$1" "$reset"; }

show() {
  local file=$1 title i key hex r g b fg
  title=$(sed -nE 's/^ *"?(scheme|name)"?: *"?([^"]*)"?,?$/\2/p' "$file" | head -1)
  echo
  row ""
  row "  ${title:-$file}"
  row ""
  for i in {0..15}; do
    key=$(printf 'base%02X' "$i")
    hex=$(sed -nE "s/^ *\"?$key\"?: *\"?#?([0-9a-fA-F]{6}).*/\1/p" "$file" | head -1)
    [[ -n $hex ]] || continue
    r=$((16#${hex:0:2})) g=$((16#${hex:2:2})) b=$((16#${hex:4:2}))
    # Pick black or white text by luminance.
    if (( (r * 299 + g * 587 + b * 114) / 1000 > 128 )); then fg=0; else fg=255; fi
    printf '%s  \e[48;2;%d;%d;%dm\e[38;2;%d;%d;%dm  %s  Aa  %s  #%s  %-*s%s\n' \
      "$panel" "$r" "$g" "$b" "$fg" "$fg" "$fg" "$key" "$panel" "$hex" 19 "${names[i]}" "$reset"
  done
  row ""
  echo
}

if [[ ${1:-} == -l || ${1:-} == --list ]]; then
  for f in "$(schemes_dir)"/*.yaml; do basename "$f" .yaml; done
  exit
fi

if (( $# == 0 )); then
  show ~/.config/stylix/palette.json
  exit
fi

dir=
for arg in "$@"; do
  if [[ -f $arg ]]; then
    show "$arg"
  else
    dir=${dir:-$(schemes_dir)}
    [[ -f $dir/$arg.yaml ]] || { echo "no scheme '$arg'" >&2; exit 1; }
    show "$dir/$arg.yaml"
  fi
done
