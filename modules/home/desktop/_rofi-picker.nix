{ lib, pkgs }:
# Builds a rofi picker script over a list of rows.
#
# - help: lines printed by --help.
# - setup: shell run first. Must define `create TEXT` and set $rows (TSV, last
#   column is the text shown in rofi). May exit early.
# - onSelect: shell run once a row is picked, with the row in $row.
# - actions: { name, key, run }; `run` is a shell command. `key` is the Alt+key
#   that triggers it directly, plain Enter asks which action to run.
# - newLabel: what Ctrl+Enter on typed text creates.
# - rofiArgs: extra rofi arguments.
{
  name,
  help,
  runtimeInputs,
  setup,
  onSelect,
  actions,
  newLabel,
  rofiArgs ? [ ],
}:
let
  keyFlags = lib.concatImapStringsSep " " (i: a: "-kb-custom-${toString i} Alt+${a.key}") actions;

  # Alt+key exits rofi with 10 + index; map each code to its action name.
  codeCases = lib.concatImapStringsSep "\n" (i: a: "  ${toString (9 + i)}) act=${a.name} ;;") actions;

  runCases = lib.concatMapStringsSep "\n" (a: "  ${a.name}) ${a.run} ;;") actions;

  keys = lib.concatMapStringsSep "/" (a: a.key) actions;
  names = lib.concatMapStringsSep "/" (a: a.name) actions;
in
pkgs.writeShellApplication {
  inherit name;
  runtimeInputs = [
    pkgs.coreutils
    pkgs.gnused
    pkgs.libnotify
    pkgs.rofi
  ]
  ++ runtimeInputs;
  text = ''
    case "''${1:-}" in
      -h | --help)
        printf '%s\n' ${lib.escapeShellArgs help}
        exit 0
        ;;
    esac

    # Keybind launches have no terminal, so surface failures as a notification.
    trap 'notify-send -u critical "${name} failed" "line $LINENO"' ERR

    ${setup}

    # Enter picks the highlighted row (index >= 0) and asks for an action.
    # Alt+key runs an action directly (rofi exits 10 and up). Ctrl+Enter, or
    # Enter with no match, gives index -1 and the typed text, which creates one.
    rc=0
    res=$(printf '%s\n' "$rows" | sed 's/.*\t//' \
      | rofi -dmenu -i -format 'i|f' -p "${name}" -l 15 ${keyFlags} \
          ${lib.escapeShellArgs rofiArgs} \
          -mesg "Alt+${keys}: ${names}  |  Ctrl+Enter: ${newLabel}") || rc=$?
    [ "$rc" -eq 0 ] || [ "$rc" -ge 10 ] || exit 0
    idx=''${res%%|*}
    if [ "$idx" -lt 0 ]; then
      [ "$rc" -eq 0 ] && [ -n "''${res#*|}" ] && create "''${res#*|}"
      exit 0
    fi

    row=$(printf '%s\n' "$rows" | sed -n "$((idx + 1))p")
    ${onSelect}

    case "$rc" in
    ${codeCases}
      *) act=$(printf '%s\n' ${
        lib.concatMapStringsSep " " (a: a.name) actions
      } | rofi -dmenu -i -no-custom -p "Action" -l ${toString (lib.length actions)}) || exit 0 ;;
    esac
    case "$act" in
    ${runCases}
    esac
  '';
}
