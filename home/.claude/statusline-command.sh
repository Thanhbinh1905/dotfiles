#!/bin/bash
# Claude Code status line
# Shows model, context-window usage, and both rate-limit windows.

input=$(cat)

DIM='\033[2m'
GREEN='\033[2;32m'
YELLOW='\033[2;33m'
RED='\033[2;31m'
RESET='\033[0m'

bar() {
  local pct=${1%.*} filled i out color
  [ -n "$pct" ] || return 1
  filled=$(( (pct + 10) / 20 ))
  [ "$filled" -gt 5 ] && filled=5
  [ "$filled" -lt 0 ] && filled=0
  color="$GREEN"
  if [ "$pct" -ge 80 ]; then color="$RED"
  elif [ "$pct" -ge 50 ]; then color="$YELLOW"
  fi
  out=""
  for ((i = 0; i < 5; i++)); do
    if [ "$i" -lt "$filled" ]; then out+="▰"; else out+="▱"; fi
  done
  printf "%b%s %d%%%b" "$color" "$out" "$pct" "$RESET"
}

compact() {
  local n=$1
  if [ "$n" -ge 1000000 ]; then awk -v n="$n" 'BEGIN{printf "%.3g M", n/1000000}' | tr -d ' '
  elif [ "$n" -ge 1000 ]; then awk -v n="$n" 'BEGIN{printf "%dk", n/1000}'
  else printf "%d" "$n"
  fi
}

countdown() {
  local target=$1 now left
  now=$(date +%s)
  left=$(( target - now ))
  [ "$left" -gt 0 ] || return 1
  if [ "$left" -ge 86400 ]; then printf "%dd" $(( left / 86400 ))
  elif [ "$left" -ge 3600 ]; then printf "%dh" $(( left / 3600 ))
  else printf "%dm" $(( left / 60 ))
  fi
}

eval "$(printf '%s' "$input" | jq -r '
  @sh "model=\(.model.display_name // "")",
  @sh "ctx_pct=\(.context_window.used_percentage // "")",
  @sh "ctx_used=\(.context_window.total_input_tokens // "")",
  @sh "ctx_size=\(.context_window.context_window_size // "")",
  @sh "h5_pct=\(.rate_limits.five_hour.used_percentage // "")",
  @sh "h5_reset=\(.rate_limits.five_hour.resets_at // "")",
  @sh "d7_pct=\(.rate_limits.seven_day.used_percentage // "")",
  @sh "d7_reset=\(.rate_limits.seven_day.resets_at // "")"
')"

segments=()

[ -n "$model" ] && segments+=("$(printf "%b%s%b" "$DIM" "$model" "$RESET")")

if [ -n "$ctx_pct" ]; then
  seg=$(bar "$ctx_pct")
  if [ -n "$ctx_used" ] && [ -n "$ctx_size" ]; then
    seg+=$(printf "%b (%s/%s)%b" "$DIM" "$(compact "$ctx_used")" "$(compact "$ctx_size")" "$RESET")
  fi
  segments+=("$seg")
fi

window_segment() {
  local label=$1 pct=$2 reset=$3 seg left
  [ -n "$pct" ] || return 1
  seg=$(printf "%b%s%b " "$DIM" "$label" "$RESET")
  seg+=$(bar "$pct")
  if [ -n "$reset" ] && left=$(countdown "$reset"); then
    seg+=$(printf "%b ↻%s%b" "$DIM" "$left" "$RESET")
  fi
  printf '%s' "$seg"
}

if seg=$(window_segment 5h "$h5_pct" "$h5_reset"); then segments+=("$seg"); fi
if seg=$(window_segment 7d "$d7_pct" "$d7_reset"); then segments+=("$seg"); fi

sep=$(printf "%b · %b" "$DIM" "$RESET")
out=""
for s in "${segments[@]}"; do
  [ -n "$out" ] && out+="$sep"
  out+="$s"
done
printf "%b" "$out"
