{ pkgs, ... }:
let
  statusline = pkgs.writeShellApplication {
    name = "claude-statusline";
    runtimeInputs = with pkgs; [
      coreutils
      gawk
      git
    ];
    text = ''
      # Line 1: model [effort] cwd  git-branch (+changes)
      # Line 2: context bar | 5h <dots> <used%> ↻rem | 7d <dots> <used%> ↻rem
      #   dots FILL  = usage % consumed (5h: 5 dots, 7d: 7 dots; in-progress dot = quarter steps)
      #   dots COLOR = burn pace (used% vs time-elapsed%): blue ok, yellow tight, red too fast
      #   ↻rem       = time left until the window resets
      #
      # Customize via env: CC_SL_FULL CC_SL_HALF CC_SL_EMPTY (dot glyphs),
      # CC_SL_PACE_FLOOR (used% below which pace color stays blue; default 5).

      input=$(cat)

      # --- parse the JSON once (path-aware scalar extraction) -----------------------
      read_fields() {
        printf '%s' "$input" | awk '
          { rec = rec $0 "\n" }
          function ws() { while (pos <= len) { c = substr(S, pos, 1)
              if (c == " " || c == "\t" || c == "\n" || c == "\r") pos++; else break } }
          function str(   out, c, nc) { pos++; out = ""
            while (pos <= len) { c = substr(S, pos, 1)
              if (c == "\\") { nc = substr(S, pos + 1, 1)
                if (nc == "n") out = out "\n"; else if (nc == "t") out = out "\t"
                else out = out nc; pos += 2; continue }
              if (c == "\"") { pos++; break }
              out = out c; pos++ }
            return out }
          function prim(   out, c) { out = ""
            while (pos <= len) { c = substr(S, pos, 1)
              if (c == "," || c == "}" || c == "]" || c == " " || c == "\t" || c == "\n" || c == "\r") break
              out = out c; pos++ }
            return out }
          function value(path,   c) { ws(); c = substr(S, pos, 1)
            if (c == "{") obj(path)
            else if (c == "[") arr(path)
            else if (c == "\"") V[path] = str()
            else V[path] = prim() }
          function obj(path,   k) { pos++; ws()
            if (substr(S, pos, 1) == "}") { pos++; return }
            while (1) { ws(); k = str(); ws(); pos++   # skip :
              value(path "." k); ws(); c = substr(S, pos, 1); pos++
              if (c == ",") continue; else break } }   # skip , or }
          function arr(path,   i) { pos++; ws()
            if (substr(S, pos, 1) == "]") { pos++; return }
            i = 0
            while (1) { value(path "." i); i++; ws(); c = substr(S, pos, 1); pos++
              if (c == ",") continue; else break } }
          END {
            S = rec; len = length(S); pos = 1; value("")
            eff = (V[".effort.level"] != "") ? V[".effort.level"] : V[".effort"]
            print V[".model.display_name"]
            print eff
            print V[".workspace.current_dir"]
            print V[".context_window.used_percentage"]
            print V[".rate_limits.five_hour.used_percentage"]
            print V[".rate_limits.five_hour.resets_at"]
            print V[".rate_limits.seven_day.used_percentage"]
            print V[".rate_limits.seven_day.resets_at"]
          }'
      }

      {
        IFS= read -r model
        IFS= read -r effort
        IFS= read -r cwd
        IFS= read -r ctx
        IFS= read -r fh_used
        IFS= read -r fh_reset
        IFS= read -r sd_used
        IFS= read -r sd_reset
      } < <(read_fields)

      now=$(date +%s)

      # --- colors / glyphs ----------------------------------------------------------
      BLUE=$'\033[94m'; YELLOW=$'\033[33m'; RED=$'\033[31m'; GREEN=$'\033[32m'
      DIM=$'\033[2;37m'; RESET=$'\033[0m'
      MODELC=$'\033[35m'; EFFORTC=$'\033[93m'; CYAN=$'\033[36m'
      GITC=$'\033[31m'
      FULL=''${CC_SL_FULL:-●}; EMPTY=''${CC_SL_EMPTY:-○}
      Q1=''${CC_SL_Q1:-◔}; HALF=''${CC_SL_HALF:-◑}; Q3=''${CC_SL_Q3:-◕}

      is_set() { [ -n "$1" ] && [ "$1" != "null" ]; }

      # --- line 1 -------------------------------------------------------------------
      [ -z "$model" ] || [ "$model" = "null" ] && model="Claude"
      cwd_tilde="''${cwd/#$HOME/\~}"
      line1="''${MODELC}''${model}''${RESET}"
      is_set "$effort" && line1+=" ''${EFFORTC}[''${effort}]''${RESET}"
      is_set "$cwd_tilde" && line1+=" ''${CYAN}''${cwd_tilde}''${RESET}"

      if [ -n "$cwd" ] && git -C "$cwd" --no-optional-locks -c core.useBuiltinFSMonitor=false rev-parse --git-dir >/dev/null 2>&1; then
        G=(git -C "$cwd" --no-optional-locks -c core.useBuiltinFSMonitor=false)
        br=$("''${G[@]}" symbolic-ref --short HEAD 2>/dev/null || "''${G[@]}" rev-parse --short HEAD 2>/dev/null || true)
        stats=$("''${G[@]}" diff --shortstat HEAD 2>/dev/null || true)
        ins=$(printf '%s' "$stats" | grep -oE '[0-9]+ insertion' | grep -oE '[0-9]+' || true)
        del=$(printf '%s' "$stats" | grep -oE '[0-9]+ deletion' | grep -oE '[0-9]+' || true)
        if [ -n "$br" ]; then
          line1+=" ''${GITC}''${br}''${RESET}"
          if [ -n "$ins" ] || [ -n "$del" ]; then
            line1+=" ''${GREEN}+''${ins:-0}''${RESET} ''${RED}-''${del:-0}''${RESET}"
          fi
        fi
      fi
      # --- line 2 -------------------------------------------------------------------
      round() { printf '%.0f' "$1" 2>/dev/null; }

      fmt_remaining() { # $1=sec $2=daily(1/0) — rounds to nearest unit
        local sec=$1 daily=$2 h m d rh
        [ "$sec" -lt 0 ] && sec=0
        if [ "$daily" -eq 1 ]; then
          h=$(( (sec + 1800) / 3600 ))           # nearest hour
          d=$(( h / 24 )); rh=$(( h % 24 ))
          if [ "$d" -gt 0 ]; then
            if [ "$rh" -gt 0 ]; then printf '%dd%dh' "$d" "$rh"; else printf '%dd' "$d"; fi
            return
          fi
          # <1 day left: fall through to h/m so we never show "0h"
        fi
        m=$(( (sec + 30) / 60 ))                  # nearest minute
        h=$(( m / 60 )); m=$(( m % 60 ))
        if [ "$h" -gt 0 ]; then printf '%dh%dm' "$h" "$m"; else printf '%dm' "$m"; fi
      }

      render_window() { # $1=label $2=windowSec $3=units $4=daily $5=used $6=reset
        local label=$1 win=$2 units=$3 daily=$4 used=$5 reset=$6
        is_set "$reset" || return 0
        reset=''${reset%.*}
        case "$reset" in '''|*[!0-9]*) return 0 ;; esac
        local elapsed=$(( now - (reset - win) ))
        [ "$elapsed" -lt 0 ] && elapsed=0
        [ "$elapsed" -gt "$win" ] && elapsed=$win
        local u; u=$(round "$used"); u=''${u:-0}
        [ "$u" -lt 0 ] && u=0; [ "$u" -gt 100 ] && u=100
        # Dots track usage %, not the clock. Floor to the last fully-consumed quarter so a
        # part never claims usage you haven't reached (each part = a quarter of one dot).
        local maxq=$(( units * 4 ))
        local quarters=$(( u * maxq / 100 ))
        [ "$quarters" -gt "$maxq" ] && quarters=$maxq
        local full=$(( quarters / 4 )) rem=$(( quarters % 4 ))
        local partial=""
        case "$rem" in
          1) partial="$Q1" ;;
          2) partial="$HALF" ;;
          3) partial="$Q3" ;;
        esac
        local pcount=0; [ -n "$partial" ] && pcount=1
        local empty=$(( units - full - pcount ))
        # Color = burn pace: usage % vs the share of the window's time already elapsed.
        # Just after a reset elapsed≈0, so the ratio explodes and even 1% reads as
        # "too fast". Below PACE_FLOOR% used you can't exhaust the window regardless of
        # pace, so stay blue and skip the unstable ratio entirely.
        local col=$DIM pct=""
        if is_set "$used"; then
          if [ "$u" -lt "''${CC_SL_PACE_FLOOR:-5}" ]; then col=$BLUE
          elif [ $(( u * win )) -le $(( elapsed * 100 )) ]; then col=$BLUE
          elif [ $(( 2 * u * win )) -le $(( 3 * elapsed * 100 )) ]; then col=$YELLOW
          else col=$RED; fi
          pct=" ''${col}''${u}%''${RESET}"
        fi
        local dots="" i=0
        while [ $i -lt $full ]; do dots+="$FULL"; i=$((i+1)); done
        [ -n "$partial" ] && dots+="$partial"
        i=0; while [ $i -lt $empty ]; do dots+="$EMPTY"; i=$((i+1)); done
        printf '%s %s%s%s%s %s↻%s%s' "$label" "$col" "$dots" "$RESET" "$pct" "$DIM" "$(fmt_remaining $(( reset - now )) "$daily")" "$RESET"
      }

      ctxseg=""
      if is_set "$ctx"; then
        cpct=$(round "$ctx"); cpct=''${cpct:-0}
        [ "$cpct" -lt 0 ] && cpct=0; [ "$cpct" -gt 100 ] && cpct=100
        filled=$(( (cpct + 5) / 10 )); [ "$filled" -gt 10 ] && filled=10
        if [ "$cpct" -lt 60 ]; then cc=$GREEN; elif [ "$cpct" -le 80 ]; then cc=$YELLOW; else cc=$RED; fi
        bar="" i=0
        while [ $i -lt $filled ]; do bar+="█"; i=$((i+1)); done
        while [ $i -lt 10 ]; do bar+="░"; i=$((i+1)); done
        ctxseg="⛁ ''${cc}''${bar} ''${cpct}%''${RESET}"
      fi

      seg5=$(render_window "5h" 18000 5 0 "$fh_used" "$fh_reset")
      seg7=$(render_window "7d" 604800 7 1 "$sd_used" "$sd_reset")
      usage="$seg5"
      [ -n "$seg7" ] && { [ -n "$usage" ] && usage="$usage | $seg7" || usage="$seg7"; }

      line2="$ctxseg"
      if [ -n "$usage" ]; then
        [ -n "$line2" ] && line2="$line2 | $usage" || line2="$usage"
      fi

      printf '%s\n%s\n' "$line1" "$line2"
    '';
  };
in
{
  programs.claude-code = {
    enable = true;
    settings = {
      # keep-sorted start block=yes
      autoUpdates = false;
      effortLevel = "medium";
      hooks.Notification = [
        {
          matcher = "permission_prompt";
          hooks = [
            {
              type = "command";
              command = ''
                msg=$(sed -n 's/.*"message":"\([^"]*\)".*/\1/p')
                ${pkgs.libnotify}/bin/notify-send "Claude Code" "''${msg:-Permission requested}" 2>/dev/null || true
              '';
            }
          ];
        }
      ];
      includeCoAuthoredBy = false;
      lspServers = {
        python = {
          command = "${pkgs.pyright}/bin/pyright-langserver";
          args = [ "--stdio" ];
          extensionToLanguage = {
            ".py" = "python";
          };
        };
        typescript = {
          command = "${pkgs.typescript-language-server}/bin/typescript-language-server";
          args = [ "--stdio" ];
          extensionToLanguage = {
            ".ts" = "typescript";
            ".tsx" = "typescriptreact";
            ".js" = "javascript";
            ".jsx" = "javascriptreact";
          };
        };
      };
      outputStyle = "Concise";
      permissions = {
        deny = [
          "Bash(chmod -R 000 /*)"
          "Bash(chmod -R 777 /*)"
          "Bash(dd *)"
          "Bash(halt*)"
          "Bash(mkfs*)"
          "Bash(poweroff*)"
          "Bash(reboot*)"
          "Bash(rm -rf .*)"
          "Bash(rm -rf /*)"
          "Bash(rm -rf /)"
          "Bash(rm -rf ~*)"
          "Bash(shutdown*)"
          "Bash(sudo *)"
        ];
      };
      # The built-in OS notification channel is all-or-nothing across notification
      # types, so it's disabled here and permission prompts get their own desktop
      # notification via a hook scoped to just that type, leaving out idle_prompt
      # ("Claude is waiting for your input").
      preferredNotifChannel = "notifications_disabled";
      statusLine = {
        type = "command";
        command = "$HOME/.claude/claude-statusline";
        padding = 0;
      };
      # keep-sorted end
    };
  };

  home.file.".claude/claude-statusline" = {
    source = "${statusline}/bin/claude-statusline";
    executable = true;
  };

  home.persistence."/persist" = {
    directories = [ ".claude" ];
    files = [ ".claude.json" ];
  };
}
