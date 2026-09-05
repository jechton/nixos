{
  config,
  lib,
  pkgs,
  ...
}:
let
  formatArgs =
    value:
    if value == null || value == { } then
      ""
    else if builtins.isList value then
      lib.concatStringsSep " " (map toString value)
    else
      toString value;

  # The niri CLI mirrors the KDL action names 1:1: `niri msg action <name> [-- <args>]`.
  actionCommand =
    actionName: rawArgs:
    if actionName == "spawn" then
      [
        "niri"
        "msg"
        "action"
        "spawn"
        "--"
      ]
      ++ (if builtins.isList rawArgs then map toString rawArgs else [ (toString rawArgs) ])
    else if rawArgs == { } then
      [
        "niri"
        "msg"
        "action"
        actionName
      ]
    else
      [
        "niri"
        "msg"
        "action"
        actionName
        "--"
        (toString rawArgs)
      ];

  bindLine =
    key: bind:
    let
      props = bind._props or { };
      hasCustomTitle = props ? hotkey-overlay-title;
      title = props.hotkey-overlay-title or null;
      hidden = hasCustomTitle && title == null;
      actionName = builtins.head (builtins.filter (name: name != "_props") (builtins.attrNames bind));
      rawArgs = bind.${actionName};
      argsStr = formatArgs rawArgs;
      label =
        if hasCustomTitle && title != null then
          title
        else if argsStr != "" then
          "${actionName} ${argsStr}"
        else
          actionName;
      # Keep each TSV record on one line: a spawned command may itself embed newlines.
      command = lib.replaceStrings [ "\n" ] [ " " ] (
        lib.escapeShellArgs (actionCommand actionName rawArgs)
      );
    in
    if hidden then null else "${key}\t${label}\t${command}";

  lines = lib.filter (l: l != null) (
    lib.mapAttrsToList bindLine config.wayland.windowManager.niri.settings.binds
  );

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
        data="${cheatsheetData}"

        selection=$(
          cut -f1,2 "$data" \
            | column -t -s $'\t' \
            | fuzzel --dmenu --prompt "Keybind: " --width 80 --lines 20
        )
        [ -z "$selection" ] && exit 0

        key=$(awk '{print $1}' <<<"$selection")
        command=$(awk -F'\t' -v k="$key" '$1 == k { print $3; exit }' "$data")
        [ -z "$command" ] && exit 0

        eval "$command"
      '';
    })
  ];
}
