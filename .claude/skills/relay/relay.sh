#!/usr/bin/env bash
# Relay driver (trial) — runs a static reference doc one item per headless Claude Code
# session, feeding each session's hop message to the next. Guide: DOC/guides/relay_sessions.md.
#
# Usage: relay.sh <reference-doc> [--from T3] [--max-hops 20] [--max-turns 60] [--dry-run]
# Env:   RELAY_PERMISSION_MODE  permission mode for every hop (default: auto)
#        RELAY_LOG_DIR          where the per-hop measurement log goes (default: ~/.claude/relay-logs)
#
# Exit codes: 0 relay reached END, 2 stopped for a human decision, 1 usage or setup error.
#
# The log is for FinOps measurement only. No hop ever reads it: the hop message is the only
# thing passed between sessions.
set -euo pipefail

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODELS="opus sonnet haiku"
# Pinned IDs: the bare `haiku` alias resolves to Haiku 4.5, which can't run in auto
# permission mode headless (every tool call is denied). Pinning also keeps variants comparable.
declare -A MODEL_ID=([opus]=claude-opus-5-5 [sonnet]=claude-sonnet-5-5 [haiku]=claude-haiku-5-5)
# AW-26: a headless hop is unattended Claude work, so its commits name Claude as author and
# committer (git log, shortlog, GitHub), not the human whose git config is on the machine.
declare -A MODEL_NAME=([opus]="Claude Opus 5.5" [sonnet]="Claude Sonnet 5.5" [haiku]="Claude Haiku 5.5")
EFFORTS="low medium high xhigh max"

die() { echo "relay: $*" >&2; exit 1; }
stop() { echo; echo "relay: STOPPED — $*" >&2; echo "Continue by hand with /relay and this hop message:"; printf '```relay\n%s\n```\n' "$MSG"; exit 2; }

DOC="" FROM="" MAX_HOPS=20 MAX_TURNS=60 DRY_RUN=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --from) FROM="$2"; shift 2 ;;
    --max-hops) MAX_HOPS="$2"; shift 2 ;;
    --max-turns) MAX_TURNS="$2"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) sed -n '2,13p' "${BASH_SOURCE[0]}"; exit 0 ;;
    -*) die "unknown option $1" ;;
    *) [[ -z "$DOC" ]] || die "one reference doc only"; DOC="$1"; shift ;;
  esac
done
[[ -n "$DOC" ]] || die "usage: relay.sh <reference-doc> [--from ITEM] [--max-hops N] [--max-turns N] [--dry-run]"
command -v jq >/dev/null || die "jq is required"

ROOT="$(git rev-parse --show-toplevel)" || die "run this inside the repo (or a worktree of it)"
cd "$ROOT"
DOC="$(realpath --relative-to="$ROOT" "$DOC")"
[[ -f "$DOC" ]] || die "$DOC not found"
git ls-files --error-unmatch "$DOC" >/dev/null 2>&1 || die "$DOC is not committed — commit the reference doc before starting"
git diff --quiet HEAD -- "$DOC" || die "$DOC has uncommitted changes — the reference doc must be static"
doc_hash() { git hash-object "$DOC" | cut -c1-7; }
HASH="$(doc_hash)"

# Items are "### T<n> — title" headings; each carries "- **Model:** x" and "- **Effort:** y".
mapfile -t ITEMS < <(grep -oE '^### T[0-9]+' "$DOC" | awk '{print $2}')
[[ ${#ITEMS[@]} -gt 0 ]] || die "no items (### T1 — ...) found in $DOC"
field() {  # field <item> <Field> → first word of that field's value inside the item's section
  awk -v id="$1" -v f="$2" '
    /^### / { in_item = ($2 == id) }
    in_item && index($0, "**" f ":**") { sub(/.*\*\*[A-Za-z]+:\*\*[ \t]*/, ""); split($0, w, /[ \t|]/); print w[1]; exit }
  ' "$DOC"
}
for item in "${ITEMS[@]}"; do
  m="$(field "$item" Model)"; e="$(field "$item" Effort)"
  [[ " $MODELS " == *" $m "* ]] || die "$item: Model must be one of: $MODELS (got '$m')"
  [[ " $EFFORTS " == *" $e "* ]] || die "$item: Effort must be one of: $EFFORTS (got '$e')"
done

FIRST="${FROM:-${ITEMS[0]}}"
[[ " ${ITEMS[*]} " == *" $FIRST "* ]] || die "--from $FIRST is not an item in $DOC"
MSG="$(printf 'RELAY %s @ %s\nDONE  -\nNEXT  %s\nDEAD  -\nOPEN  -\nFAILS %s: 0' "$DOC" "$HASH" "$FIRST" "$FIRST")"

# The hop rules are the skill body (frontmatter stripped), so manual and scripted hops match.
RULES="$(awk 'NR == 1 && /^---$/ { fm = 1; next } fm && /^---$/ { fm = 0; next } !fm' "$SKILL_DIR/SKILL.md")"

BRANCH="$(git rev-parse --abbrev-ref HEAD)"
LOG_DIR="${RELAY_LOG_DIR:-$HOME/.claude/relay-logs}"
LOG="$LOG_DIR/${BRANCH//\//_}.tsv"
MODE="${RELAY_PERMISSION_MODE:-auto}"

echo "relay: $DOC @ $HASH on $BRANCH — ${#ITEMS[@]} items, starting at $FIRST, mode=$MODE, max ${MAX_TURNS} turns/hop"
for item in "${ITEMS[@]}"; do echo "  $item  $(field "$item" Model)/$(field "$item" Effort)"; done
if [[ $DRY_RUN -eq 1 ]]; then printf '\nFirst hop message:\n```relay\n%s\n```\n' "$MSG"; exit 0; fi

mkdir -p "$LOG_DIR"
[[ -s "$LOG" ]] || printf 'time\tbranch\tdoc\thop\titem\tmodel\teffort\tsession_id\tsubtype\tturns\tcost_usd\tnext\tfails\n' > "$LOG"

msg_field() { awk -v k="$1" '$1 == k { $1 = ""; sub(/^ +/, ""); print; exit }' <<<"$MSG"; }

for (( hop = 1; hop <= MAX_HOPS; hop++ )); do
  [[ "$(doc_hash)" == "$HASH" ]] || stop "$DOC changed during the relay"
  ITEM="$(msg_field NEXT)"
  [[ "$ITEM" == "END" ]] && { echo; echo "relay: END — all items done. Next: review and merge as usual (guide, step 5)."; exit 0; }
  [[ " ${ITEMS[*]} " == *" $ITEM "* ]] || stop "hop message names unknown item '$ITEM'"
  MODEL="$(field "$ITEM" Model)"; EFFORT="$(field "$ITEM" Effort)"

  echo; echo "── hop $hop: $ITEM on ${MODEL_ID[$MODEL]}/$EFFORT"
  PROMPT="$(printf 'You are hop %d of a relay. Reference doc: %s\n\nHop message from the previous hop:\n\n```relay\n%s\n```\n\nDo item %s following the relay hop rules in your system prompt. End with the relay block.' "$hop" "$DOC" "$MSG" "$ITEM")"
  export GIT_AUTHOR_NAME="${MODEL_NAME[$MODEL]}" GIT_COMMITTER_NAME="${MODEL_NAME[$MODEL]}" \
         GIT_AUTHOR_EMAIL=noreply@anthropic.com GIT_COMMITTER_EMAIL=noreply@anthropic.com
  OUT="$(claude -p "$PROMPT" --model "${MODEL_ID[$MODEL]}" --effort "$EFFORT" --max-turns "$MAX_TURNS" \
           --permission-mode "$MODE" --output-format json --append-system-prompt "$RULES" 2>>"$LOG_DIR/stderr.log")" || true
  [[ -n "$OUT" ]] && jq -e . >/dev/null 2>&1 <<<"$OUT" || stop "hop $hop: claude returned no JSON result"

  SUBTYPE="$(jq -r '.subtype // "?"' <<<"$OUT")"
  SESSION="$(jq -r '.session_id // "?"' <<<"$OUT")"
  TURNS="$(jq -r '.num_turns // 0' <<<"$OUT")"
  COST="$(jq -r '.total_cost_usd // 0' <<<"$OUT")"
  # The hop message is the last ```relay block of the final answer.
  NEW="$(jq -r '.result // ""' <<<"$OUT" | awk '/^```relay[ \t]*$/ { buf = ""; on = 1; next } on && /^```/ { on = 0; last = buf; next } on { buf = buf $0 "\n" } END { printf "%s", last }')"

  NEXT="-" FAILS="-"
  if [[ -n "$NEW" ]]; then MSG="${NEW%$'\n'}"; NEXT="$(msg_field NEXT)"; FAILS="$(msg_field FAILS | awk '{print $NF}')"; fi
  printf '%s\t%s\t%s\t%d\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$(date -Iseconds)" "$BRANCH" "$DOC" "$hop" "$ITEM" \
    "${MODEL_ID[$MODEL]}" "$EFFORT" "$SESSION" "$SUBTYPE" "$TURNS" "$COST" "$NEXT" "$FAILS" >> "$LOG"
  echo "   session $SESSION · $SUBTYPE · $TURNS turns · \$$COST"

  [[ -n "$NEW" ]] || stop "hop $hop ($SUBTYPE) ended without a hop message — resume it with: claude --resume $SESSION"
  printf '```relay\n%s\n```\n' "$MSG"
  [[ "$(msg_field OPEN)" == "-" ]] || stop "hop $hop raised an open question"
  [[ "$FAILS" =~ ^[0-9]+$ ]] || stop "hop $hop wrote an unreadable FAILS line"
  (( FAILS < 2 )) || stop "$NEXT failed on two hops"
done
stop "reached --max-hops $MAX_HOPS"
