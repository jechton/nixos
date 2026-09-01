{ config, pkgs, ... }:
let
  vault = "${config.home.homeDirectory}/Documents/Obsidian/Vault";
in
{
  home.packages = [
    (pkgs.writeShellApplication {
      name = "daily-note";
      runtimeInputs = [
        pkgs.coreutils
        pkgs.fuzzel
        pkgs.gawk
        pkgs.gnused
        pkgs.libnotify
      ];
      text = ''
        vault="${vault}"
        template="$vault/_meta/templates/TEMPLATE-daily.md"

        note="$vault/journal/$(date +%y)/$(date +%m)/$(date +%y%m%d).md"

        # Grab the entry text from the argument, or prompt with a fuzzel popup.
        if [ "$#" -gt 0 ]; then
          entry="$*"
        else
          entry=$(fuzzel --dmenu --prompt "Daily note: " --placeholder "journal entry" --lines 0 --width 60 < /dev/null)
        fi
        [ -n "''${entry:-}" ] || exit 0

        if [ ! -f "$note" ]; then
          day=$(date +%-d)
          case "$day" in
            1 | 21 | 31) suffix=st ;;
            2 | 22) suffix=nd ;;
            3 | 23) suffix=rd ;;
            *) suffix=th ;;
          esac
          header=$(date "+%A, %B $day$suffix, %Y")
          mkdir -p "$(dirname "$note")"
          sed -e "s|{{date:dddd, MMMM Do, YYYY}}|$header|g" \
              -e "s|{{date:YYYY-MM-DD}}|$(date +%F)|g" \
              -e "/<% tp\.file\.cursor/d" \
              "$template" > "$note"
        fi

        time=$(date '+%-I:%M %p')
        line="- $time $entry"

        # Append the entry to the end of the "## Journal" section, keeping a
        # single blank line before the following heading. Blank lines inside the
        # section are buffered so they don't accumulate across runs.
        awk -v line="$line" '
          /^## Journal$/ { in_journal = 1; print; next }
          in_journal && /^[[:space:]]*$/ { held++; next }
          in_journal && /^## / {
            print line; print ""; in_journal = 0; held = 0
          }
          in_journal { while (held-- > 0) print ""; held = 0 }
          { print }
          END { if (in_journal) print line }
        ' "$note" > "$note.tmp" && mv "$note.tmp" "$note"

        notify-send "Daily note" "$time  $entry" || echo "added: $line"
      '';
    })
  ];
}
