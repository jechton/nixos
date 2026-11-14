{
  config,
  lib,
  osConfig,
  pkgs,
  ...
}:
let
  c = config.lib.stylix.colors.withHashtag;
  mkPicker = import ./_rofi-picker.nix { inherit lib pkgs; };
in
{
  home.packages = [
    (mkPicker {
      name = "jira";
      help = [
        "jira"
        ""
        "Rofi picker for open Jira issues. Alt+l switches to a saved filter. Pick one to open, copy its"
        "key, move it to another status, or comment (Alt+o/c/t/m act directly)."
        "Ctrl+Enter on typed text creates a new issue."
      ];
      runtimeInputs = [
        pkgs.curl
        pkgs.jq
        pkgs.wl-clipboard
        pkgs.xdg-utils
      ];
      newLabel = "new issue";
      rofiArgs = [ "-markup-rows" ];
      reload = {
        key = "l";
        label = "filter";
        run = "pick_filter";
      };

      setup = ''
        # Credentials file: line 1 is the Jira Cloud URL, line 2 the account
        # email, line 3 an API token.
        creds="${osConfig.age.secrets.jira-credentials.path}"
        base=$(sed -n 1p "$creds")
        user=$(sed -n 2p "$creds")
        token=$(sed -n 3p "$creds")

        api() {
          curl -fsS -u "$user:$token" -H "Content-Type: application/json" "$@"
        }

        # Done issues are always excluded. A saved filter keeps its own ORDER BY.
        jql='statusCategory != Done ORDER BY updated DESC'

        # lazy: only the latest 500 issues are listed (Jira may return fewer per page); rofi filters client-side.
        # TSV per issue: key, pango-markup display line colored by the same rules as the Jira list view.
        load() {
          rows=$(api -G "$base/rest/api/3/search/jql" \
            --data-urlencode "jql=$jql" \
            --data-urlencode 'fields=summary,status,customfield_10104' \
            --data-urlencode 'maxResults=500' \
            | jq -r \
                --arg red "${c.base08}" --arg yellow "${c.base0A}" \
                --arg green "${c.base0B}" --arg blue "${c.base0D}" '
                {"New": $yellow, "Needs Documentation": $blue, "In Review": $green} as $byStatus
                | .issues[]
                | (if (.fields.customfield_10104 | length) > 0 then $red
                   else $byStatus[.fields.status.name] end) as $color
                | "\(.key)  [\(.fields.status.name)]  \(.fields.summary)" as $line
                | [.key, (if $color then "<span foreground=\"\($color)\">\($line | @html)</span>" else ($line | @html) end)]
                | @tsv')
        }

        # Choose one of your saved Jira filters (not the per-board "Filter for X"
        # ones), or all open issues, then reload.
        # Cancelling keeps the current list.
        pick_filter() {
          frows=$(api "$base/rest/api/3/filter/my" | jq -r '.[] | select(.name | startswith("Filter for ") | not) | [.id, (.name | sub(" \\([0-9]+\\)$"; ""))] | @tsv')
          pick=$(printf 'All open issues\n%s\n' "$(printf '%s\n' "$frows" | cut -f2)" \
            | rofi -dmenu -i -no-custom -format i -p "Filter" -l 10) || return 0
          if [ "$pick" -eq 0 ]; then
            jql='statusCategory != Done ORDER BY updated DESC'
          else
            jql="filter = $(printf '%s\n' "$frows" | sed -n "''${pick}p" | cut -f1) AND statusCategory != Done"
          fi
          load
        }

        load

        # Typed text (Ctrl+Enter, or Enter with no match) is the summary of a new
        # issue. Prompts for the project and issue type, then assigns it to you.
        create() {
          prows=$(api -G "$base/rest/api/3/project/search" --data-urlencode 'maxResults=500' \
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

        # Issue actions read $key.
        transition() {
          # Rows are "id<TAB>target status name".
          trows=$(api "$base/rest/api/3/issue/$key/transitions" \
            | jq -r '.transitions[] | [.id, .to.name] | @tsv')
          pick=$(printf '%s\n' "$trows" | cut -f2 | rofi -dmenu -i -no-custom -format i -p "Move $key" -l 8) || exit 0
          id=$(printf '%s\n' "$trows" | sed -n "$((pick + 1))p" | cut -f1)
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
      '';

      onSelect = ''key=$(printf '%s' "$row" | cut -f1)'';

      actions = [
        {
          name = "open";
          key = "o";
          run = ''xdg-open "$base/browse/$key" > /dev/null 2>&1'';
        }
        {
          name = "copy";
          key = "c";
          run = ''printf '%s' "$key" | wl-copy && notify-send "Jira" "Copied $key"'';
        }
        {
          name = "transition";
          key = "t";
          run = "transition";
        }
        {
          name = "comment";
          key = "m";
          run = "comment";
        }
      ];
    })
  ];
}
