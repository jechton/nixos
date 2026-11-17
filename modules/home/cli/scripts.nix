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

  # Live Mermaid preview for Ghostty: redraws the diagram each time the file is saved.
  mermaidPreview = pkgs.writeShellApplication {
    name = "mermaid-preview";
    runtimeInputs = with pkgs; [
      chafa
      entr
      mermaid-cli
      ncurses
    ];
    text = ''
      file="''${1:-}"
      [ -z "$file" ] && { echo "usage: mermaid-preview file.mmd"; exit 1; }
      out="''${XDG_RUNTIME_DIR:-/tmp}/mermaid-preview.png"

      render() {
        clear
        if mmdc -i "$file" -o "$out" -b white -s 2 -q; then
          chafa -f kitty -s "$(tput cols)x$(tput lines)" "$out"
        fi
      }

      if [ "''${2:-}" = "--once" ]; then
        render
        exit
      fi

      render
      # entr re-runs this script in --once mode on every save.
      echo "$file" | entr -n -s "'$0' '$file' --once"
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

  # Terminal editor for timeline .mmd files, see pkgs/timeline.
  timeline = pkgs.callPackage ../../../pkgs/timeline { mermaid-preview = mermaidPreview; };
  # keep-sorted end
in
{
  imports = [ inputs.nix-index-database.homeModules.nix-index ];

  home = {
    packages = [
      # keep-sorted start
      focusOrSpawnSignal
      mermaidPreview
      niriWorkspaceCycle
      ocrRegion
      timeline
      # keep-sorted end
    ];
  };
}
