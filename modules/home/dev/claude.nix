{ pkgs, ... }:
let
  statusline = pkgs.writeShellApplication {
    name = "claude-statusline";
    runtimeInputs = with pkgs; [
      coreutils
      jq
    ];
    text = ''
      input="$(cat)"

      model="$(jq -r '.model.display_name // "Claude"' <<<"$input")"
      dir="$(basename "$(jq -r '.workspace.current_dir // .cwd // "~"' <<<"$input")")"

      # Formats seconds-until-reset as e.g. "2h15m" or "3d4h".
      fmt_reset() {
        local epoch="$1"
        local now diff days hours mins
        now="$(date +%s)"
        diff=$(( epoch - now ))
        if (( diff < 0 )); then
          diff=0
        fi
        days=$(( diff / 86400 ))
        hours=$(( (diff % 86400) / 3600 ))
        mins=$(( (diff % 3600) / 60 ))
        if (( days > 0 )); then
          printf '%dd%dh' "$days" "$hours"
        elif (( hours > 0 )); then
          printf '%dh%dm' "$hours" "$mins"
        else
          printf '%dm' "$mins"
        fi
      }

      # Prints "<pct>% (resets in <duration>)" for a rate_limits.<key> window,
      # or nothing if that window isn't in the statusline payload yet.
      fmt_window() {
        local key="$1"
        local pct reset
        pct="$(jq -r ".rate_limits.''${key}.used_percentage // empty" <<<"$input")"
        if [[ -z "$pct" ]]; then
          return
        fi
        reset="$(jq -r ".rate_limits.''${key}.resets_at // empty | floor" <<<"$input")"
        printf '%.0f%%' "$pct"
        if [[ -n "$reset" ]]; then
          printf ' (resets in %s)' "$(fmt_reset "$reset")"
        fi
      }

      five="$(fmt_window five_hour)"
      week="$(fmt_window seven_day)"

      out="$model · 📁 $dir"
      if [[ -n "$five" ]]; then
        out="$out · 5h $five"
      fi
      if [[ -n "$week" ]]; then
        out="$out · 7d $week"
      fi
      printf '%s' "$out"
    '';
  };
in
{
  programs.claude-code = {
    enable = true;
    settings = {
      env.CLAUDE_CODE_EFFORT_LEVEL = "medium";
      statusLine = {
        type = "command";
        command = "${statusline}/bin/claude-statusline";
        padding = 0;
      };
    };
  };

  home.persistence."/persist" = {
    directories = [ ".claude" ];
    files = [ ".claude.json" ];
  };
}
