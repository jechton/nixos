{
  pkgs,
  inputs,
  ...
}:
let
  # keep-sorted start block=yes newline_separated=yes
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
      ns
      ocrRegion
      # keep-sorted end
    ];
  };
}
