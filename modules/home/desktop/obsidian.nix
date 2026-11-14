{ config, pkgs, ... }:
let
  vault = "${config.home.homeDirectory}/Documents/Obsidian/Vault";
  template = "${vault}/_meta/templates/TEMPLATE-daily.md";

  # Render today's daily note from the template if it doesn't exist yet.
  # Interpolated into both the daily-note and task scripts.
  ensureDaily = ''
    ensure_daily() {
      [ -f "$note" ] && return
      local day suffix header
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
          "${template}" > "$note"
    }
  '';
in
{
  home.packages = [
    (pkgs.writeShellApplication {
      name = "daily-note";
      runtimeInputs = [
        pkgs.coreutils
        pkgs.rofi
        pkgs.gawk
        pkgs.gnused
        pkgs.libnotify
      ];
      text = ''
        vault="${vault}"

        case "''${1:-}" in
          -h | --help)
            printf '%s\n' \
              "daily-note [entry text]" \
              "" \
              "Append a timestamped line to the '## Journal' section of today's" \
              "daily note, creating it from the template if needed. With no" \
              "arguments, prompts for the entry in a rofi popup."
            exit 0
            ;;
        esac

        note="$vault/journal/$(date +%y)/$(date +%m)/$(date +%y%m%d).md"

        # Grab the entry text from the argument, or prompt with a rofi popup.
        if [ "$#" -gt 0 ]; then
          entry="$*"
        else
          entry=$(rofi -dmenu -p "Daily note" -l 0 -theme-str 'entry { placeholder: "journal entry"; }' < /dev/null)
        fi
        [ -n "''${entry:-}" ] || exit 0

        ${ensureDaily}
        ensure_daily

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

    (pkgs.writeShellApplication {
      name = "task";
      runtimeInputs = [
        pkgs.coreutils
        pkgs.rofi
        pkgs.gawk
        pkgs.gnugrep
        pkgs.gnused
        pkgs.libnotify
        pkgs.xdg-utils
      ];
      text = ''
        vault="${vault}"
        today=$(date +%F)
        note="$vault/journal/$(date +%y)/$(date +%m)/$(date +%y%m%d).md"
        tasks_file="$vault/tasks/tasks.md"
        ${ensureDaily}

        # Free-text prompt. $1 label, $2 placeholder, $3 optional prefilled value.
        ask() {
          local pre=()
          if [ -n "''${3:-}" ]; then pre=(-filter "$3"); fi
          rofi -dmenu -p "$1" -l 0 -theme-str "entry { placeholder: \"$2\"; }" "''${pre[@]}" < /dev/null
        }

        # Menu select. $1 label, newline-separated options on stdin, prints the
        # 0-based index of the chosen option.
        choose() {
          rofi -dmenu -i -no-custom -format i -p "$1" -l 15
        }

        # All open tasks in the vault as "file<TAB>lineno<TAB>text".
        scan_open() {
          grep -rn --include='*.md' --exclude-dir=.trash --exclude-dir=.obsidian \
            -- '- \[ \] ' "$vault" 2>/dev/null \
            | while IFS=: read -r f l rest; do
                text=$(printf '%s' "$rest" | sed 's/^[[:space:]]*- \[ \] //')
                printf '%s\t%s\t%s\n' "$f" "$l" "$text"
              done
        }

        # A file path as a short human location: a daily note becomes its date,
        # the tasks file becomes "tasks", anything else its bare filename.
        loc_label() {
          local rel="''${1#"$vault"/}" base out
          case "$rel" in
            journal/*/*/*.md)
              base="''${rel##*/}"
              base="''${base%.md}"
              out="20''${base:0:2}-''${base:2:2}-''${base:4:2}"
              if [ "''${out:0:4}" = "''${today:0:4}" ]; then
                date -d "$out" '+%b %-d' 2>/dev/null || printf '%s' "$rel"
              else
                date -d "$out" '+%b %-d, %Y' 2>/dev/null || printf '%s' "$rel"
              fi
              ;;
            tasks/tasks.md | tasks.md) printf 'tasks' ;;
            *)
              base="''${rel##*/}"
              printf '%s' "''${base%.md}"
              ;;
          esac
        }

        # Render a wikilink for display: [[Link|Alias]] -> Alias, [[Link]] -> Link.
        strip_wikilinks() {
          printf '%s' "$1" | sed -E 's/\[\[[^]|]*\|([^]]*)\]\]/\1/g; s/\[\[([^]]*)\]\]/\1/g'
        }

        # "task text  · location" display line. $1 file, $2 task text.
        fmt() {
          printf '%s  · %s\n' "$(strip_wikilinks "$2")" "$(loc_label "$1")"
        }

        # Resolve a human date token to YYYY-MM-DD, fail if unparsable.
        # A bare number is read as "that many days from now".
        resolve_date() {
          local s="$1"
          case "$s" in
            "") return 1 ;;
            [0-9] | [0-9][0-9]) s="$s days" ;;
          esac
          date -d "$s" +%F 2>/dev/null
        }

        # Populate MENU_KEEP (array of "file<TAB>lineno<TAB>text", one per open
        # task) and MENU_LINES (their display lines, newline separated).
        MENU_KEEP=()
        MENU_LINES=""
        scan_menu() {
          local recs=() r f l t
          mapfile -t recs < <(scan_open)
          for r in "''${recs[@]}"; do
            IFS=$'\t' read -r f l t <<< "$r"
            MENU_KEEP+=("$r")
            MENU_LINES+="$(fmt "$f" "$t")"$'\n'
          done
        }
        # Task actions. Each takes: $1 file, $2 lineno, $3 task text.

        act_done() {
          # Mark complete in place and stamp the completion date. Recurring
          # tasks (🔁) are closed without spawning the next occurrence; handle
          # those in Obsidian.
          sed -i "$2s/- \[ \]/- [x]/; $2s/\$/ ✅ $today/" "$1"
          notify_open "Task done" "$3" "$1"
        }

        act_schedule() {
          local when d
          when=$(ask "Schedule for" "date, blank to unschedule")
          if [ -n "''${when:-}" ]; then
            d=$(resolve_date "$when") || { echo "unparsable date: $when" >&2; return 1; }
            sed -i "$2{s/ ⏳ [0-9-]\{10\}//; s/\$/ ⏳ $d/}" "$1"
            notify_open "Task ⏳ $d" "$3" "$1"
          else
            sed -i "$2s/ ⏳ [0-9-]\{10\}//" "$1"
            notify_open "Task unscheduled" "$3" "$1"
          fi
        }

        act_edit() {
          local new esc
          new=$(ask "Edit task" "task text" "$3")
          if [ -z "''${new:-}" ] || [ "$new" = "$3" ]; then return 0; fi
          # Replace everything after the "- [ ] " marker on that line.
          esc=$(printf '%s' "$new" | sed 's/[&/\]/\\&/g')
          sed -i "$2s/\(^[[:space:]]*- \[ \] \).*/\1$esc/" "$1"
          notify_open "Task edited" "$new" "$1"
        }

        act_open() {
          # lazy: only spaces and & are percent-encoded; other URI-reserved
          # characters in a note name would need a real urlencode.
          local rel="''${1#"$vault"/}"
          rel="''${rel%.md}"
          rel="''${rel// /%20}"
          rel="''${rel//&/%26}"
          xdg-open "obsidian://open?vault=''${vault##*/}&file=$rel" >/dev/null 2>&1
        }

        # Send a notification whose click opens $3's note in Obsidian, falling
        # back to plain notify-send if the daemon doesn't support actions.
        # Runs in the background since --action blocks until clicked/dismissed.
        notify_open() {
          local title="$1" body file="$3"
          body=$(strip_wikilinks "$2")
          (
            action=$(notify-send --action="default=Open in Obsidian" "$title" "$body" 2>/dev/null) || exit 0
            [ "$action" = "default" ] && act_open "$file"
          ) &
          disown
        }

        # Create a new open task from $1. Trailing "@when" sets a ⏳ scheduled
        # date, "!when" a 📅 due date. Prompts for the destination file.
        create_task() {
          local text="$1" tok d item dest
          tok=''${text##* @}
          if [ "$tok" != "$text" ] && d=$(resolve_date "$tok"); then
            text="''${text% @*} ⏳ $d"
          fi
          tok=''${text##* !}
          if [ "$tok" != "$text" ] && d=$(resolve_date "$tok"); then
            text="''${text% !*} 📅 $d"
          fi
          item="- [ ] $text"

          dest=$(printf '%s\n' "tasks file" "today's note" | choose "Add to") || return 1
          case "$dest" in
            1)
              ensure_daily
              awk -v add="$item" '
                /^## Goals$/ { in_s = 1; print; next }
                in_s && /^[[:space:]]*$/ { held++; next }
                in_s && /^#/ { print add; print ""; in_s = 0; held = 0 }
                in_s { while (held-- > 0) print ""; held = 0 }
                { print }
                END { if (in_s) print add }
              ' "$note" > "$note.tmp" && mv "$note.tmp" "$note"
              notify_open "Task added" "$text" "$note"
              ;;
            *)
              awk -v add="$item" '
                /^[[:space:]]*$/ && !placed { held++; next }
                /^# Completed/ && !placed {
                  while (held-- > 0) print ""; held = 0
                  print add; print ""; print; placed = 1; next
                }
                { while (held-- > 0) print ""; held = 0; print }
                END { if (!placed) { while (held-- > 0) print ""; print add } }
              ' "$tasks_file" > "$tasks_file.tmp" && mv "$tasks_file.tmp" "$tasks_file"
              notify_open "Task added" "$text" "$tasks_file"
              ;;
          esac
        }

        scan_menu
        sel=$(printf '%s' "$MENU_LINES" | rofi -dmenu -i -p "Task or new" -l 15) || exit 0
        [ -n "$sel" ] || exit 0
        # Match the selection against the listed tasks; no match means the
        # text was typed in, so create a task from it.
        idx=-1
        i=0
        while IFS= read -r line; do
          if [ "$line" = "$sel" ]; then
            idx=$i
            break
          fi
          i=$((i + 1))
        done <<< "$MENU_LINES"
        if [ "$idx" -lt 0 ]; then
          create_task "$sel"
          exit 0
        fi
        IFS=$'\t' read -r file ln disp <<< "''${MENU_KEEP[$idx]}"
        act=$(printf '%s\n' "done" "schedule" "edit" "open" | choose "$disp") || exit 0
        case "$act" in
          0) act_done "$file" "$ln" "$disp" ;;
          1) act_schedule "$file" "$ln" "$disp" ;;
          2) act_edit "$file" "$ln" "$disp" ;;
          3) act_open "$file" "$ln" "$disp" ;;
        esac
      '';
    })
  ];
}
