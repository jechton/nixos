{
  config,
  osConfig,
  pkgs,
  ...
}:
{
  home.packages = [
    (pkgs.writeShellApplication {
      name = "memo";
      runtimeInputs = [
        pkgs.coreutils
        pkgs.curl
        pkgs.rofi
        pkgs.jq
        pkgs.libnotify
        pkgs.wl-clipboard
        pkgs.xdg-utils
      ];
      text = ''
        case "''${1:-}" in
          -h | --help)
            printf '%s\n' \
              "memo [text]" \
              "" \
              "Rofi picker for Memos. Pick a recent memo to open, edit, copy, or" \
              "archive (Alt+o/e/c/a act directly). Ctrl+Enter on typed text" \
              "creates one. With text arguments, creates the memo directly."
            exit 0
            ;;
        esac

        # Keybind launches have no terminal, so surface failures as a notification.
        trap 'notify-send -u critical "memo failed" "line $LINENO"' ERR

        # Credentials file: line 1 is the Memos URL, line 2 an access token.
        creds="${osConfig.age.secrets.memos-credentials.path}"
        base=$(sed -n 1p "$creds")
        token=$(sed -n 2p "$creds")

        api() {
          curl -fsS -H "Authorization: Bearer $token" -H "Content-Type: application/json" "$@"
        }

        create() {
          api -X POST "$base/api/memos" \
            -d "$(jq -n --arg c "$1" '{content: $c, visibility: "PRIVATE"}')" > /dev/null
          notify-send "Memo added" "$1"
        }

        if [ "$#" -gt 0 ]; then
          create "$*"
          exit 0
        fi

        # Memo actions read $name (resource) and $sel (first lines, for notifications).
        open_memo() { xdg-open "$base/$name" > /dev/null 2>&1; }

        # Edits the content in Helix inside a terminal, then saves it back.
        edit_memo() {
          tmp=$(mktemp --suffix=.md)
          api "$base/api/$name" | jq -j '.content' > "$tmp"
          ghostty --gtk-single-instance=false -e hx "$tmp"
          api -X PATCH "$base/api/$name?updateMask=content" \
            -d "$(jq -n --rawfile c "$tmp" '{content: $c}')" > /dev/null
          rm -f "$tmp"
          notify-send "Memo updated" "$sel"
        }

        copy_memo() {
          api "$base/api/$name" | jq -j '.content' | wl-copy
          notify-send "Memo copied" "$sel"
        }

        archive_memo() {
          api -X PATCH "$base/api/$name?updateMask=state" -d '{"state":"ARCHIVED"}' > /dev/null
          notify-send "Memo archived" "$sel"
        }

        # lazy: only the latest 100 are listed; rofi filters client-side.
        # Raise pageSize or add a server-side filter if older memos matter.
        # TSV per memo: resource name, first two non-empty lines, the same line
        # escaped for pango with #tags colored and links shortened (no scheme or www., cut at 30 characters).
        memos=$(api "$base/api/memos?pageSize=100" \
          | jq -r '.memos[] | (.content | split("\n") | map(select(test("\\S")))[:2] | join(" · ")) as $line
              | [.name, $line, ($line | gsub("https?://(www\\.)?(?<u>\\S+)"; .u | if length > 30 then .[:30] + "…" else . end) | @html | gsub("(?<t>(?<![^\\s])#[^\\s#]+)"; "<span foreground=\"${config.lib.stylix.colors.withHashtag.base0E}\">\(.t)</span>"))]
              | @tsv')

        # Enter picks the highlighted memo (index >= 0) and asks for an action.
        # Alt+o/e/c/a run an action on it directly (rofi exits 10 to 13).
        # Ctrl+Enter, or Enter with no match, gives index -1 and the typed
        # text, which becomes a new memo.
        rc=0
        res=$(printf '%s\n' "$memos" | cut -f3 \
          | rofi -dmenu -i -markup-rows -format 'i|f' -p "Memo" -l 15 \
              -kb-custom-1 "Alt+o" -kb-custom-2 "Alt+e" \
              -kb-custom-3 "Alt+c" -kb-custom-4 "Alt+a" \
              -mesg "Alt+o/e/c/a: open/edit/copy/archive  |  Ctrl+Enter: new") || rc=$?
        [ "$rc" -eq 0 ] || [ "$rc" -ge 10 ] || exit 0
        idx=''${res%%|*}
        if [ "$idx" -lt 0 ]; then
          [ "$rc" -eq 0 ] && [ -n "''${res#*|}" ] && create "''${res#*|}"
          exit 0
        fi

        row=$(printf '%s\n' "$memos" | sed -n "$((idx + 1))p")
        name=$(printf '%s' "$row" | cut -f1)
        sel=$(printf '%s' "$row" | cut -f2)

        case "$rc" in
          10) act=open ;;
          11) act=edit ;;
          12) act=copy ;;
          13) act=archive ;;
          *) act=$(printf '%s\n' open edit copy archive | rofi -dmenu -i -no-custom -p "Action" -l 4) || exit 0 ;;
        esac
        case "$act" in
          open) open_memo ;;
          edit) edit_memo ;;
          copy) copy_memo ;;
          archive) archive_memo ;;
        esac
      '';
    })
  ];
}
