# model·effort · dir branch +ins -del · ctx used% · 5h used% ↻rem · 7d used% ↻rem
#   dir     = folder name inside a git repo, fish-style abbreviated path outside
#   used%   = colored by burn pace (used% vs time-elapsed%): blue ok, yellow tight, red too fast
#   ↻rem    = time left until the window resets
#
# Customize via env: CC_SL_PACE_FLOOR (used% below which pace color stays blue; default 5).

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

# --- colors -------------------------------------------------------------------
BLUE=$'\033[94m'; YELLOW=$'\033[33m'; RED=$'\033[31m'; GREEN=$'\033[32m'
DIM=$'\033[2;37m'; RESET=$'\033[0m'
MODELC=$'\033[35m'; EFFORTC=$'\033[93m'; CYAN=$'\033[36m'
GITC=$'\033[31m'
SEP=" ${DIM}·${RESET} "

is_set() { [ -n "$1" ] && [ "$1" != "null" ]; }

join() { # appends $1 to $out with a separator
  [ -n "$1" ] || return 0
  if [ -n "$out" ]; then out+="${SEP}$1"; else out=$1; fi
}

# --- model·effort -------------------------------------------------------------
# "Opus 5.5" -> "opus"; effort abbreviated so medium and max stay distinct.
is_set "$model" || model="Claude"
model=${model%% *}
model=${model,,}
case "$effort" in
  low) effort=l ;;
  medium) effort=m ;;
  high) effort=h ;;
  xhigh) effort=xh ;;
esac
modelseg="${MODELC}${model}${RESET}"
is_set "$effort" && modelseg+="${DIM}·${RESET}${EFFORTC}${effort}${RESET}"

# --- dir + git ----------------------------------------------------------------
fish_path() { # ~/Projects/foo/bar -> ~/P/f/bar, keeping the leading dot of hidden dirs
  local p="${1/#$HOME/\~}" out="" part last
  last=${p##*/}
  [ "$p" = "$last" ] || [ "$p" = "/" ] && { printf '%s' "$p"; return; }
  [ "$p" = "/$last" ] && { printf '/%s' "$last"; return; }
  IFS=/ read -ra parts <<< "${p%/*}"
  for part in "${parts[@]}"; do
    if [ "${part:0:1}" = "." ]; then out+="${part:0:2}/"; else out+="${part:0:1}/"; fi
  done
  printf '%s%s' "$out" "$last"
}

dirseg=""
if [ -n "$cwd" ] && git -C "$cwd" --no-optional-locks -c core.useBuiltinFSMonitor=false rev-parse --git-dir >/dev/null 2>&1; then
  G=(git -C "$cwd" --no-optional-locks -c core.useBuiltinFSMonitor=false)
  dirseg="${CYAN}${cwd##*/}${RESET}"
  br=$("${G[@]}" symbolic-ref --short HEAD 2>/dev/null || "${G[@]}" rev-parse --short HEAD 2>/dev/null || true)
  stats=$("${G[@]}" diff --shortstat HEAD 2>/dev/null || true)
  ins=$(printf '%s' "$stats" | grep -oE '[0-9]+ insertion' | grep -oE '[0-9]+' || true)
  del=$(printf '%s' "$stats" | grep -oE '[0-9]+ deletion' | grep -oE '[0-9]+' || true)
  if [ -n "$br" ]; then
    dirseg+=" ${GITC}${br}${RESET}"
    if [ -n "$ins" ] || [ -n "$del" ]; then
      dirseg+=" ${GREEN}+${ins:-0}${RESET} ${RED}-${del:-0}${RESET}"
    fi
  fi
elif [ -n "$cwd" ]; then
  dirseg="${CYAN}$(fish_path "$cwd")${RESET}"
fi

# --- context + rate limits ----------------------------------------------------
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

render_window() { # $1=label $2=windowSec $3=daily $4=used $5=reset
  local label=$1 win=$2 daily=$3 used=$4 reset=$5
  is_set "$reset" || return 0
  reset=${reset%.*}
  case "$reset" in ''|*[!0-9]*) return 0 ;; esac
  local elapsed=$(( now - (reset - win) ))
  [ "$elapsed" -lt 0 ] && elapsed=0
  [ "$elapsed" -gt "$win" ] && elapsed=$win
  local u; u=$(round "$used"); u=${u:-0}
  [ "$u" -lt 0 ] && u=0; [ "$u" -gt 100 ] && u=100
  # Color = burn pace: usage % vs the share of the window's time already elapsed.
  # Just after a reset elapsed≈0, so the ratio explodes and even 1% reads as
  # "too fast". Below PACE_FLOOR% used you can't exhaust the window regardless of
  # pace, so stay blue and skip the unstable ratio entirely.
  local col=$DIM pct=""
  if is_set "$used"; then
    if [ "$u" -lt "${CC_SL_PACE_FLOOR:-5}" ]; then col=$BLUE
    elif [ $(( u * win )) -le $(( elapsed * 100 )) ]; then col=$BLUE
    elif [ $(( 2 * u * win )) -le $(( 3 * elapsed * 100 )) ]; then col=$YELLOW
    else col=$RED; fi
    pct=" ${col}${u}%${RESET}"
  fi
  printf '%s%s %s↻%s%s' "$label" "$pct" "$DIM" "$(fmt_remaining $(( reset - now )) "$daily")" "$RESET"
}

ctxseg=""
if is_set "$ctx"; then
  cpct=$(round "$ctx"); cpct=${cpct:-0}
  [ "$cpct" -lt 0 ] && cpct=0; [ "$cpct" -gt 100 ] && cpct=100
  if [ "$cpct" -lt 60 ]; then cc=$GREEN; elif [ "$cpct" -le 80 ]; then cc=$YELLOW; else cc=$RED; fi
  ctxseg="ctx ${cc}${cpct}%${RESET}"
fi

out=""
join "$modelseg"
join "$dirseg"
join "$ctxseg"
join "$(render_window "5h" 18000 0 "$fh_used" "$fh_reset")"
join "$(render_window "7d" 604800 1 "$sd_used" "$sd_reset")"
printf '%s\n' "$out"
