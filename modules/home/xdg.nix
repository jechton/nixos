{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.xdg;
in
{
  xdg.configFile = {
    "npm/npmrc".text = ''
      prefix=${cfg.dataHome}/npm
      cache=${cfg.cacheHome}/npm
      init-module=${cfg.configHome}/npm/config/npm-init.js
    '';

    "python/pythonrc".text = ''
      import os
      import atexit
      import readline
      from pathlib import Path

      if readline.get_current_history_length() == 0:

          state_home = os.environ.get("XDG_STATE_HOME")
          if state_home is None:
              state_home = Path.home() / ".local" / "state"
          else:
              state_home = Path(state_home)

          history_path = state_home / "python_history"
          if history_path.is_dir():
              raise OSError(f"'{history_path}' cannot be a directory")

          history = str(history_path)

          try:
              readline.read_history_file(history)
          except OSError: # Non existent
              pass

          def write_history():
              try:
                  readline.write_history_file(history)
              except OSError:
                  pass

          atexit.register(write_history)
    '';
  };

  home.sessionVariables = {
    LESSHISTFILE = "${cfg.dataHome}/less/history";
    INPUTRC = "${cfg.configHome}/readline/inputrc";
    SQLITE_HISTORY = "${cfg.cacheHome}/sqlite_history";
    IPYTHONDIR = "${cfg.configHome}/ipython";
    JUPYTER_CONFIG_DIR = "${cfg.configHome}/jupyter";

    NPM_CONFIG_CACHE = "${cfg.cacheHome}/npm";
    NPM_CONFIG_TMP = "/run/user/$UID/npm";
    NPM_CONFIG_USERCONFIG = "${cfg.configHome}/npm/config";

    PNPM_HOME = "${cfg.dataHome}/pnpm";

    ANDROID_HOME = "${cfg.dataHome}/android";
    ANDROID_USER_HOME = "${cfg.dataHome}/android";
    GRADLE_USER_HOME = "${cfg.dataHome}/gradle";
  };

  home.sessionPath = [ "${cfg.dataHome}/pnpm" ];

  home.persistence."/persist".directories = [
    ".cache/npm"
    ".local/share/npm"
    ".local/share/pnpm"
  ];

  xdg.mimeApps =
    let
      # mimeapps.list matching is literal, globs like "image/*" are not
      # expanded by xdg-mime or gio, so every concrete type must be listed.
      # Enumerate them from the shared-mime-info database at build time.
      typesInClass =
        class:
        map (name: "${class}/${lib.removeSuffix ".xml" name}") (
          builtins.filter (lib.hasSuffix ".xml") (
            builtins.attrNames (builtins.readDir "${pkgs.shared-mime-info}/share/mime/${class}")
          )
        );

      imageTypes = typesInClass "image";
      videoTypes = typesInClass "video";
      audioTypes = typesInClass "audio";
      # Keep markup out of the editor default so the browser keeps html/xml.
      isMarkup =
        t: lib.hasInfix "xml" t || lib.hasInfix "html" t || lib.hasSuffix "wml" t || t == "text/x-uri";
      textTypes = builtins.filter (t: !isMarkup t) (
        typesInClass "text"
        ++ [
          "application/json"
          "application/toml"
          "application/x-shellscript"
          "application/x-yaml"
        ]
      );

      forEach = types: app: builtins.listToAttrs (map (t: lib.nameValuePair t app) types);
    in
    {
      enable = true;
      defaultApplications =
        forEach imageTypes "imv.desktop"
        // forEach videoTypes "mpv.desktop"
        // forEach audioTypes "mpv.desktop"
        // forEach textTypes "Helix.desktop"
        // {
          "inode/directory" = "org.gnome.Nautilus.desktop";
        };
    };
}
