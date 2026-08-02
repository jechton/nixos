{
  config,
  lib,
  pkgs,
  ...
}:
let
  formatArgs =
    value:
    if value == null then
      ""
    else if builtins.isList value then
      lib.concatStringsSep " " (map toString value)
    else
      toString value;

  bindLine =
    key: bind:
    let
      hidden = bind.hotkey-overlay.hidden or false;
      title = bind.hotkey-overlay.title or null;
      actionName = builtins.head (builtins.attrNames bind.action);
      argsStr = formatArgs bind.action.${actionName};
      label =
        if title != null then
          title
        else if argsStr != "" then
          "${actionName} ${argsStr}"
        else
          actionName;
    in
    if hidden then null else "${key}\t${label}";

  lines = lib.filter (l: l != null) (lib.mapAttrsToList bindLine config.programs.niri.settings.binds);

  cheatsheetData = pkgs.writeText "niri-keybind-cheatsheet.tsv" (
    lib.concatStringsSep "\n" lines + "\n"
  );
in
{
  programs.fuzzel = {
    enable = true;
    settings = {
      main.font = lib.mkForce "${config.burrow.theme.fonts.monospace.name}:size=10";
      border.radius = 0;
    };
  };

  home.packages = [
    (pkgs.writeShellApplication {
      name = "niri-keybind-cheatsheet";
      runtimeInputs = [
        pkgs.fuzzel
        pkgs.util-linux
      ];
      text = ''
        column -t -s $'\t' "${cheatsheetData}" \
          | fuzzel --dmenu --prompt "Keybind: " --width 80 --lines 20 >/dev/null
      '';
    })
  ];
}
