{ config, pkgs, ... }:
let
  vault = "${config.home.homeDirectory}/Documents/Obsidian/Vault";
  template = "${vault}/_meta/templates/TEMPLATE-daily.md";

  # Render today's daily note from the template if it doesn't exist yet.
  # lazy: this block is duplicated in the daily-note script below; if it
  # changes a third time, factor it into a shared sourced snippet.
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
        pkgs.fuzzel
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
              "arguments, prompts for the entry in a fuzzel popup."
            exit 0
            ;;
        esac

        note="$vault/journal/$(date +%y)/$(date +%m)/$(date +%y%m%d).md"

        # Grab the entry text from the argument, or prompt with a fuzzel popup.
        if [ "$#" -gt 0 ]; then
          entry="$*"
        else
          entry=$(fuzzel --dmenu --prompt "Daily note: " --placeholder "journal entry" --lines 0 --width 60 < /dev/null)
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
        pkgs.fuzzel
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

        # Mode: fuzzel popups when launched without a terminal (keybind), plain
        # stdin/stdout prompts otherwise. --fuzzel / --cli force it either way.
        mode=cli
        [ -t 0 ] || mode=fuzzel

        cmd=""
        args=()
        for a in "$@"; do
          case "$a" in
            -h | --help | help) cmd=help ;;
            --fuzzel) mode=fuzzel ;;
            --cli) mode=cli ;;
            add | list | done | today | schedule | edit | open | menu)
              if [ -z "$cmd" ]; then cmd="$a"; else args+=("$a"); fi
              ;;
            defer)
              if [ -z "$cmd" ]; then cmd=schedule; else args+=("$a"); fi
              ;;
            *) args+=("$a") ;;
          esac
        done
        [ -n "$cmd" ] || cmd=add

        if [ "$cmd" = help ]; then
          printf '%s\n' \
            "task [--cli|--fuzzel] <command> [args]" \
            "" \
            "Commands:" \
            "  add [text] [@when] [!when]" \
            "                     add a task, prompting where to file it" \
            "                     (tasks.md or today's daily note). @when sets a" \
            "                     ⏳ scheduled date, !when a 📅 due date. Prompts" \
            "                     for text if omitted. (default command)" \
            "  list               print every open task in the vault" \
            "  today              open tasks scheduled/due today or earlier, plus" \
            "                     undated tasks in today's daily note (⚠ = overdue)" \
            "  menu [filter]      one picker: choose an open task then an action" \
            "                     (done/schedule/edit/open), or type a new task" \
            "                     name to create it" \
            "  done [filter]      pick an open task, mark it complete in place" \
            "  schedule [filter]  pick an open task, set/replace its ⏳ scheduled" \
            "                     date (blank input unschedules). alias: defer" \
            "  edit [filter]      pick an open task, edit its text in place" \
            "  open [filter]      pick an open task, open its note in Obsidian" \
            "" \
            "Dates (@when / !when / schedule prompt): YYYY-MM-DD, today, tomorrow," \
            "a weekday (friday), a plain number of days (5), or anything GNU date -d" \
            "understands (\"next week\")." \
            "" \
            "Modes: fuzzel popups when run from a keybind, terminal prompts" \
            "otherwise. --fuzzel / --cli force one."
          exit 0
        fi

        ${ensureDaily}

        # Free-text prompt. $1 label, $2 placeholder, $3 optional prefilled value.
        ask() {
          local pre=()
          if [ -n "''${3:-}" ]; then pre=(--search "$3"); fi
          if [ "$mode" = fuzzel ]; then
            fuzzel --dmenu --prompt "$1 " --placeholder "$2" "''${pre[@]}" --lines 0 --width 60 < /dev/null
          else
            printf '%s ' "$1" >&2
            local r
            read -e -r -i "''${3:-}" r < /dev/tty
            printf '%s\n' "$r"
          fi
        }

        # Menu select. $1 label, newline-separated options on stdin, prints the
        # 0-based index of the chosen option.
        choose() {
          if [ "$mode" = fuzzel ]; then
            fuzzel --dmenu --index --prompt "$1 " --width 80 --lines 15
          else
            local opts=() line i=1 sel
            mapfile -t opts
            [ ''${#opts[@]} -gt 0 ] || return 1
            for line in "''${opts[@]}"; do
              printf '%3d  %s\n' "$i" "$line" >&2
              i=$((i + 1))
            done
            printf '%s ' "$1" >&2
            read -r sel < /dev/tty
            [ -n "''${sel:-}" ] && [ "$sel" -ge 1 ] 2>/dev/null && [ "$sel" -le ''${#opts[@]} ] || return 1
            printf '%s\n' "$((sel - 1))"
          fi
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

        # "task text  · location" display line. $1 file, $2 task text.
        fmt() {
          printf '%s  · %s\n' "$2" "$(loc_label "$1")"
        }

        # Earliest 📅/⏳/🛫 date in a task's text, empty if it has none.
        task_date() {
          printf '%s' "$1" \
            | grep -oE '(📅|⏳|🛫) [0-9]{4}-[0-9]{2}-[0-9]{2}' \
            | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}' | sort | head -1
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
        # task matching the filter words in $@) and MENU_LINES (their display
        # lines, newline separated).
        MENU_KEEP=()
        MENU_LINES=""
        scan_menu() {
          local filter="$*" recs=() r f l t line
          MENU_KEEP=()
          MENU_LINES=""
          mapfile -t recs < <(scan_open)
          for r in "''${recs[@]}"; do
            IFS=$'\t' read -r f l t <<< "$r"
            line=$(fmt "$f" "$t")
            case "$line" in *"$filter"*) ;; *) continue ;; esac
            MENU_KEEP+=("$f"$'\t'"$l"$'\t'"$t")
            MENU_LINES+="$line"$'\n'
          done
        }

        # Pick one open task. $1 prompt, rest = filter words.
        # Prints "file<TAB>lineno<TAB>task text" for the choice.
        pick_task() {
          local label="$1" idx
          shift
          scan_menu "$@"
          [ ''${#MENU_KEEP[@]} -gt 0 ] || { echo "no matching open task" >&2; return 1; }
          idx=$(printf '%s' "$MENU_LINES" | choose "$label") || return 1
          printf '%s\n' "''${MENU_KEEP[$idx]}"
        }

        # Menu select that also accepts a typed-in value not on the list.
        # $1 label, options on stdin. Prints the chosen (or typed) line.
        pick_free() {
          if [ "$mode" = fuzzel ]; then
            fuzzel --dmenu --prompt "$1 " --width 80 --lines 15
          else
            local opts=() line i=1 sel
            mapfile -t opts
            for line in "''${opts[@]}"; do
              printf '%3d  %s\n' "$i" "$line" >&2
              i=$((i + 1))
            done
            printf '%s ' "$1" >&2
            read -e -r sel < /dev/tty
            [ -n "''${sel:-}" ] || return 1
            if [ "$sel" -ge 1 ] 2>/dev/null && [ "$sel" -le ''${#opts[@]} ]; then
              printf '%s\n' "''${opts[$((sel - 1))]}"
            else
              printf '%s\n' "$sel"
            fi
          fi
        }

        # Task actions. Each takes: $1 file, $2 lineno, $3 task text.

        act_done() {
          # Mark complete in place and stamp the completion date. Recurring
          # tasks (🔁) are closed without spawning the next occurrence; handle
          # those in Obsidian.
          sed -i "$2s/- \[ \]/- [x]/; $2s/\$/ ✅ $today/" "$1"
          notify-send "Task done" "$3" || echo "done: $3"
        }

        act_schedule() {
          local when d
          when=$(ask "Schedule for:" "date, blank to unschedule")
          if [ -n "''${when:-}" ]; then
            d=$(resolve_date "$when") || { echo "unparsable date: $when" >&2; return 1; }
            sed -i "$2{s/ ⏳ [0-9-]\{10\}//; s/\$/ ⏳ $d/}" "$1"
            notify-send "Task ⏳ $d" "$3" || echo "$3 -> ⏳ $d"
          else
            sed -i "$2s/ ⏳ [0-9-]\{10\}//" "$1"
            notify-send "Task unscheduled" "$3" || echo "$3 -> unscheduled"
          fi
        }

        act_edit() {
          local new esc
          new=$(ask "Edit task:" "task text" "$3")
          if [ -z "''${new:-}" ] || [ "$new" = "$3" ]; then return 0; fi
          # Replace everything after the "- [ ] " marker on that line.
          esc=$(printf '%s' "$new" | sed 's/[&/\]/\\&/g')
          sed -i "$2s/\(^[[:space:]]*- \[ \] \).*/\1$esc/" "$1"
          notify-send "Task edited" "$new" || echo "edited: $new"
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

          dest=$(printf '%s\n' "tasks file" "today's note" | choose "Add to:") || return 1
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
              ;;
          esac
          notify-send "Task added" "$text" || echo "added: $item"
        }

        case "$cmd" in
          list)
            scan_open | while IFS=$'\t' read -r f l t; do fmt "$f" "$t"; done
            ;;

          today)
            scan_open | while IFS=$'\t' read -r f l t; do
              d=$(task_date "$t") || d=""
              if [ -z "$d" ]; then
                if [ "$f" = "$note" ]; then fmt "$f" "$t"; fi
              elif [[ "$d" < "$today" ]]; then
                printf '⚠ '
                fmt "$f" "$t"
              elif [ "$d" = "$today" ]; then
                fmt "$f" "$t"
              fi
            done
            ;;

          done | schedule | edit | open)
            rec=$(pick_task "''${cmd^}:" "''${args[*]:-}") || exit 0
            IFS=$'\t' read -r file ln disp <<< "$rec"
            "act_$cmd" "$file" "$ln" "$disp"
            ;;

          menu)
            scan_menu "''${args[*]:-}"
            sel=$(printf '%s' "$MENU_LINES" | pick_free "Task or new:") || exit 0
            [ -n "''${sel:-}" ] || exit 0
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
            ;;

          add)
            text="''${args[*]:-}"
            [ -n "$text" ] || text=$(ask "New task:" "task text")
            [ -n "''${text:-}" ] || exit 0
            create_task "$text"
            ;;
        esac
      '';
    })
  ];
}
