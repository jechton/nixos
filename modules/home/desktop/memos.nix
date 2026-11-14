{
  config,
  lib,
  osConfig,
  pkgs,
  ...
}:
let
  mkPicker = import ./_rofi-picker.nix { inherit lib pkgs; };
in
{
  home.packages = [
    (mkPicker {
      name = "memo";
      help = [
        "memo [text]"
        ""
        "Rofi picker for Memos. Pick a recent memo to open, edit, copy, or"
        "archive (Alt+o/e/c/a act directly). Ctrl+Enter on typed text"
        "creates one. With text arguments, creates the memo directly."
      ];
      runtimeInputs = [
        pkgs.curl
        pkgs.jq
        pkgs.wl-clipboard
        pkgs.xdg-utils
      ];
      newLabel = "new";
      rofiArgs = [ "-markup-rows" ];

      setup = ''
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

        # lazy: only the latest 100 are listed; rofi filters client-side.
        # Raise pageSize or add a server-side filter if older memos matter.
        # TSV per memo: resource name, first two non-empty lines, the same line
        # escaped for pango with #tags colored and links shortened (no scheme or www., cut at 30 characters).
        rows=$(api "$base/api/memos?pageSize=100" \
          | jq -r '.memos[] | (.content | split("\n") | map(select(test("\\S")))[:2] | join(" · ")) as $line
              | [.name, $line, ($line | gsub("https?://(www\\.)?(?<u>\\S+)"; .u | if length > 30 then .[:30] + "…" else . end) | @html | gsub("(?<t>(?<![^\\s])#[^\\s#]+)"; "<span foreground=\"${config.lib.stylix.colors.withHashtag.base0E}\">\(.t)</span>"))]
              | @tsv')

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
      '';

      onSelect = ''
        name=$(printf '%s' "$row" | cut -f1)
        sel=$(printf '%s' "$row" | cut -f2)
      '';

      actions = [
        {
          name = "open";
          key = "o";
          run = "open_memo";
        }
        {
          name = "edit";
          key = "e";
          run = "edit_memo";
        }
        {
          name = "copy";
          key = "c";
          run = "copy_memo";
        }
        {
          name = "archive";
          key = "a";
          run = "archive_memo";
        }
      ];
    })
  ];
}
