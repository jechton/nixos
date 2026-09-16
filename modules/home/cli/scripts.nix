{
  pkgs,
  inputs,
  ...
}:
let
  # keep-sorted start block=yes newline_separated=yes
  focusOrSpawnSignal = pkgs.writeShellApplication {
    name = "focus-or-spawn-signal";
    runtimeInputs = with pkgs; [
      jq
      niri
      signal-desktop
    ];
    text = ''
      id="$(niri msg -j windows | jq 'map(select(.app_id == "signal")) | first | .id')"
      if [ "$id" != "null" ]; then
        niri msg action focus-window --id "$id"
      else
        signal-desktop &
        disown
      fi
    '';
  };

  niriWorkspaceCycle = pkgs.writeShellApplication {
    name = "niri-workspace-cycle";
    runtimeInputs = with pkgs; [
      jq
      niri
    ];
    text = ''
      direction="$1" # down or up

      data="$(niri msg -j workspaces)"
      output="$(jq -r '.[] | select(.is_focused) | .output' <<<"$data")"
      current="$(jq -r '.[] | select(.is_focused) | .idx' <<<"$data")"

      mapfile -t idxs < <(jq -r --arg output "$output" \
        '[.[] | select(.output == $output)] | sort_by(.idx) | .[].idx' <<<"$data")

      for i in "''${!idxs[@]}"; do
        if [ "''${idxs[$i]}" = "$current" ]; then
          pos=$i
          break
        fi
      done

      count=''${#idxs[@]}
      if [ "$direction" = "down" ]; then
        next=$(( (pos + 1) % count ))
      else
        next=$(( (pos - 1 + count) % count ))
      fi

      niri msg action focus-workspace "''${idxs[$next]}"
    '';
  };

  ns = pkgs.writeShellApplication {
    name = "ns";
    runtimeInputs = [
      pkgs.fzf
      pkgs.nix-search-tv
    ];
    text = builtins.readFile "${pkgs.nix-search-tv.src}/nixpkgs.sh";
  };

  ocrRegion = pkgs.writeShellApplication {
    name = "ocr-region";
    runtimeInputs = with pkgs; [
      coreutils
      gnused
      grim
      libnotify
      slurp
      tesseract
      wl-clipboard
    ];
    text = ''
      image="$(mktemp --suffix=.png)"
      trap 'rm -f "$image"' EXIT

      geometry="$(slurp)" || exit 0
      grim -g "$geometry" "$image"

      text="$(tesseract "$image" stdout --psm 6 2>/dev/null | sed '/^[[:space:]]*$/d')"
      if [ -n "$text" ]; then
        printf '%s' "$text" | wl-copy
        notify-send "OCR copied" "$text"
      else
        notify-send "OCR empty" "No text was recognized in the selected region."
      fi
    '';
  };
  # keep-sorted end
in
{
  imports = [ inputs.nix-index-database.homeModules.nix-index ];

  home = {
    packages = [
      # keep-sorted start
      focusOrSpawnSignal
      niriWorkspaceCycle
      ns
      ocrRegion
      # keep-sorted end
    ];
  };
}
