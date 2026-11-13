{
  osConfig,
  pkgs,
  ...
}:
{
  home.packages = [
    (pkgs.writeShellApplication {
      name = "jira";
      runtimeInputs = [
        pkgs.coreutils
        pkgs.curl
        pkgs.jq
        pkgs.libnotify
        pkgs.rofi
        pkgs.wl-clipboard
        pkgs.xdg-utils
      ];
      text = ''
        case "''${1:-}" in
          -h | --help)
            printf '%s\n' \
              "jira" \
              "" \
              "Rofi picker for your open Jira issues. Pick one to open, copy its" \
              "key, move it to another status, or comment (Alt+o/c/t/m act directly)." \
              "Ctrl+Enter on typed text creates a new issue."
            exit 0
            ;;
        esac

        # Keybind launches have no terminal, so surface failures as a notification.
        trap 'notify-send -u critical "jira failed" "line $LINENO"' ERR

        # Credentials file: line 1 is the Jira Cloud URL, line 2 the account
        # email, line 3 an API token.
        creds="${osConfig.age.secrets.jira-credentials.path}"
        base=$(sed -n 1p "$creds")
        user=$(sed -n 2p "$creds")
        token=$(sed -n 3p "$creds")

        api() {
          curl -fsS -u "$user:$token" -H "Content-Type: application/json" "$@"
        }

        # lazy: only the latest 100 are listed; rofi filters client-side.
        # TSV per issue: key, display line.
        issues=$(api -G "$base/rest/api/3/search/jql" \
          --data-urlencode 'jql=assignee = currentUser() AND statusCategory != Done ORDER BY updated DESC' \
          --data-urlencode 'fields=summary,status' \
          --data-urlencode 'maxResults=100' \
          | jq -r '.issues[] | [.key, "\(.key)  [\(.fields.status.name)]  \(.fields.summary)"] | @tsv')

        # Typed text (Ctrl+Enter, or Enter with no match) is the summary of a new
        # issue. Prompts for the project and issue type, then assigns it to you.
        create_issue() {
          prows=$(api -G "$base/rest/api/3/project/search" --data-urlencode 'maxResults=100' \
            | jq -r '.values[] | [.key, "\(.key)  \(.name)"] | @tsv')
          # A single project is used without asking.
          if [ "$(printf '%s\n' "$prows" | wc -l)" -eq 1 ]; then
            pick=0
          else
            pick=$(printf '%s\n' "$prows" | cut -f2 | rofi -dmenu -i -no-custom -format i -p "Project" -l 10) || exit 0
          fi
          project=$(printf '%s\n' "$prows" | sed -n "$((pick + 1))p" | cut -f1)

          trows=$(api "$base/rest/api/3/issue/createmeta/$project/issuetypes" \
            | jq -r '(.issueTypes // .values)[] | select(.subtask | not) | [.id, .name] | @tsv')
          pick=$(printf '%s\n' "$trows" | cut -f2 | rofi -dmenu -i -no-custom -format i -p "Type" -l 8) || exit 0
          type=$(printf '%s\n' "$trows" | sed -n "$((pick + 1))p" | cut -f1)

          me=$(api "$base/rest/api/3/myself" | jq -r '.accountId')
          new=$(api -X POST "$base/rest/api/3/issue" \
            -d "$(jq -n --arg p "$project" --arg t "$type" --arg s "$1" --arg me "$me" \
              '{fields: {project: {key: $p}, issuetype: {id: $t}, summary: $s, assignee: {accountId: $me}}}')" \
            | jq -r '.key')
          notify-send "Jira" "Created $new: $1"
        }

        rc=0
        res=$(printf '%s\n' "$issues" | cut -f2 \
          | rofi -dmenu -i -format 'i|f' -p "Jira" -l 15 \
              -kb-custom-1 "Alt+o" -kb-custom-2 "Alt+c" \
              -kb-custom-3 "Alt+t" -kb-custom-4 "Alt+m" \
              -mesg "Alt+o/c/t/m: open/copy key/transition/comment  |  Ctrl+Enter: new issue") || rc=$?
        [ "$rc" -eq 0 ] || [ "$rc" -ge 10 ] || exit 0
        idx=''${res%%|*}
        if [ "$idx" -lt 0 ]; then
          [ "$rc" -eq 0 ] && [ -n "''${res#*|}" ] && create_issue "''${res#*|}"
          exit 0
        fi

        key=$(printf '%s\n' "$issues" | sed -n "$((idx + 1))p" | cut -f1)

        transition() {
          # Rows are "id<TAB>target status name".
          rows=$(api "$base/rest/api/3/issue/$key/transitions" \
            | jq -r '.transitions[] | [.id, .to.name] | @tsv')
          pick=$(printf '%s\n' "$rows" | cut -f2 | rofi -dmenu -i -no-custom -format i -p "Move $key" -l 8) || exit 0
          id=$(printf '%s\n' "$rows" | sed -n "$((pick + 1))p" | cut -f1)
          api -X POST "$base/rest/api/3/issue/$key/transitions" \
            -d "$(jq -n --arg id "$id" '{transition: {id: $id}}')" > /dev/null
          notify-send "Jira" "$key moved"
        }

        comment() {
          text=$(rofi -dmenu -p "Comment on $key" -l 0 < /dev/null) || exit 0
          [ -n "$text" ] || exit 0
          # The v3 API takes Atlassian Document Format, so wrap the text in one paragraph.
          api -X POST "$base/rest/api/3/issue/$key/comment" \
            -d "$(jq -n --arg t "$text" \
              '{body: {type: "doc", version: 1, content: [{type: "paragraph", content: [{type: "text", text: $t}]}]}}')" > /dev/null
          notify-send "Jira" "Commented on $key"
        }

        case "$rc" in
          10) act=open ;;
          11) act=copy ;;
          12) act=transition ;;
          13) act=comment ;;
          *) act=$(printf '%s\n' open copy transition comment | rofi -dmenu -i -no-custom -p "Action" -l 4) || exit 0 ;;
        esac
        case "$act" in
          open) xdg-open "$base/browse/$key" > /dev/null 2>&1 ;;
          copy) printf '%s' "$key" | wl-copy && notify-send "Jira" "Copied $key" ;;
          transition) transition ;;
          comment) comment ;;
        esac
      '';
    })
  ];
}
