{
  config,
  lib,
  osConfig,
  pkgs,
  ...
}:
let
  inherit (config.lib.stylix) colors;
  palette = lib.concatMapStringsSep " " (n: colors.${n}) [
    "base00"
    "base01"
    "base02"
    "base03"
    "base04"
    "base05"
    "base06"
    "base07"
    "base08"
    "base09"
    "base0A"
    "base0B"
    "base0C"
    "base0D"
    "base0E"
    "base0F"
  ];

  secret = osConfig.age.secrets.wallpapers.path;
  outDir = "${config.home.homeDirectory}/Pictures/Wallpapers";

  # All wallpapers live in the agenix-encrypted archive (edit it with
  # `secret wallpapers` in the devshell), so their plaintext only exists once
  # the secret is decrypted to /run. This unit rebuilds outDir from the archive
  # at login: images under recolor/ are remapped to the active base16 palette
  # with lutgen, everything else is copied through. The baked-in palette makes
  # the unit's script change when burrow.theme.colorScheme does, so a switch
  # re-runs it.
  refresh = pkgs.writeShellApplication {
    name = "wallpapers-refresh";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gnutar
      pkgs.lutgen
    ];
    text = ''
      src=${lib.escapeShellArg secret}
      out=${lib.escapeShellArg outDir}
      if [ ! -r "$src" ]; then
        echo "wallpapers: $src not readable, skipping" >&2
        exit 0
      fi
      work=$(mktemp -d)
      trap 'rm -rf "$work"' EXIT
      tar -C "$work" -xf "$src"
      rm -rf "$out"
      mkdir -p "$out"
      cd "$work" || exit 1
      find . -type f -print0 | while IFS= read -r -d "" f; do
        mkdir -p "$out/$(dirname "$f")"
        case "$f" in
          ./recolor/*.png | ./recolor/*.jpg | ./recolor/*.jpeg | ./recolor/*.webp)
            lutgen apply -o "$out/$f" "$f" -- ${palette}
            ;;
          *)
            cp "$f" "$out/$f"
            ;;
        esac
      done
    '';
  };
in
{
  systemd.user.services.wallpapers = {
    Unit = {
      Description = "Decrypt and recolor wallpapers into Pictures/Wallpapers";
      After = [ "graphical-session.target" ];
    };
    Service = {
      Type = "oneshot";
      ExecStart = lib.getExe refresh;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
