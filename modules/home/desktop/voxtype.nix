{
  config,
  lib,
  pkgs,
  ...
}:
let
  # voxtype requires every field in the config, it doesn't fall back to
  # defaults for a partial file, so merge our overrides onto its own
  # shipped defaults rather than writing a bare partial one
  defaultConfig = (pkgs.formats.toml { }).generate "voxtype-config.toml" (
    lib.recursiveUpdate
      (builtins.fromTOML (builtins.readFile "${pkgs.voxtype}/share/voxtype/default-config.toml"))
      {
        # the niri bind toggles recording instead of the built-in evdev hotkey,
        # see modules/home/desktop/niri/binds.nix
        hotkey.enabled = false;
        whisper.language = "en";
      }
  );
in
{
  home.packages = [ pkgs.voxtype ];

  # voxtype rewrites its own config.toml (e.g. `voxtype setup --download`
  # resolves model names to absolute paths), so it can't be a read-only
  # symlink into the store: seed it once on first activation and leave it
  # alone after that, same as any other self-configuring app.
  home.activation.voxtypeConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [[ ! -e "${config.xdg.configHome}/voxtype/config.toml" ]]; then
      $DRY_RUN_CMD mkdir -p "${config.xdg.configHome}/voxtype"
      $DRY_RUN_CMD install -m644 "${defaultConfig}" "${config.xdg.configHome}/voxtype/config.toml"
    fi
  '';

  systemd.user.services.voxtype = {
    Unit = {
      Description = "VoxType push-to-talk voice-to-text daemon";
      PartOf = [ "graphical-session.target" ];
      After = [
        "graphical-session.target"
        "pipewire.service"
        "pipewire-pulse.service"
      ];
    };

    Service = {
      Type = "simple";
      ExecStart = "${pkgs.voxtype}/bin/voxtype daemon";
      Restart = "on-failure";
      RestartSec = 5;
    };

    Install.WantedBy = [ "graphical-session.target" ];
  };

  # ".local/share/voxtype" holds the downloaded whisper model (fetched with
  # `voxtype setup --download`); ".config/voxtype" is the seeded config.toml,
  # which voxtype then edits in place
  home.persistence."/persist".directories = [
    ".config/voxtype"
    ".local/share/voxtype"
  ];
}
