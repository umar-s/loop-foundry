#!/usr/bin/env bash
# Repository-side invariants as greps. The skill is prose; a rule that lives
# only in CLAUDE.md is protected only by memory — every written rule that can
# be a grep lives here and runs in CI.
set -u
cd "$(dirname "$0")/.."
P=plugins/loop-foundry; S=$P/skills/loop-foundry; R=$S/references; fail=0
err() { echo "lint: $*"; fail=1; }
section() { awk -v h="$2" 'index($0, h)==1 {f=1; next} /^## / {f=0} f' "$1"; }   # body of a "## " section

# manifests parse; the version lives only in plugin.json and matches the CHANGELOG top section
python3 -c "import json; json.load(open('.claude-plugin/marketplace.json')); json.load(open('$P/.claude-plugin/plugin.json'))" 2>/dev/null || err "a manifest does not parse"
v="$(sed -n 's/.*"version": *"\([^"]*\)".*/\1/p' $P/.claude-plugin/plugin.json)"
[ -n "$v" ] || err "plugin.json has no version"
grep -q '"version"' .claude-plugin/marketplace.json && err "marketplace.json must not carry a version (plugin.json is the only source)"
grep -q "^## \[$v\]" CHANGELOG.md || err "CHANGELOG.md has no section for $v"
grep -q "\[$v\]: https://github.com/umar-s/loop-foundry/compare/" CHANGELOG.md || err "CHANGELOG.md has no compare link for $v"
grep -q 'prediction-protocol' $P/.claude-plugin/plugin.json && grep -q 'prediction-protocol' .claude-plugin/marketplace.json || err "manifest descriptions must name the companion"

# SKILL.md: triggers, resume signal, a STOP inside each of phases 1–4, reference list complete and inside its section
d="$(awk '/^description:/{print; exit}' $S/SKILL.md)"
for t in 'лупы' 'луп-подход' 'loops/STATE.md' 'loop engineering'; do printf '%s' "$d" | grep -q -- "$t" || err "SKILL.md description lost the trigger: $t"; done
for n in 1 2 3 4; do awk -v n="$n" '$0 ~ "^### Phase "n" " {f=1; next} /^### Phase / {f=0} f' $S/SKILL.md | grep -q '^\*\*STOP' || err "SKILL.md: phase $n does not end in a hard STOP"; done
grep -q 'every `loops/HALT/\*`' $S/SKILL.md || err "SKILL.md resume rule lost the HALT report"
reflist="$(section $S/SKILL.md '## Reference files')"
for f in $R/*.md; do b="$(basename "$f")"
  printf '%s' "$reflist" | grep -q "references/$b" || err "SKILL.md 'Reference files' misses $b"
  section README.md '## Layout' | grep -q "$b" || err "README.md layout misses $b"
  grep -q "$b" CLAUDE.md || err "CLAUDE.md phase map misses $b"
  [ "$(wc -l < "$f")" -le 110 ] || err "$b exceeds 110 lines — references stay compact"
  [ "$(wc -c < "$f")" -le 9500 ] || err "$b exceeds 9500 bytes — references stay compact"
done
comp="$(section $S/SKILL.md '## Companion plugin: prediction-protocol')"
[ -n "$comp" ] || err "SKILL.md lost the prediction-protocol companion section"
printf '%s' "$comp" | grep -q 'the gated and autonomous rungs require `active`' || err "companion section lost the gate requirement past shadow"
printf '%s' "$comp" | grep -q "are the operator's acts" || err "companion section lost the operator-only acts"
printf '%s' "$comp" | grep -q 'canary' || err "companion section lost the platform canary"
grep -q 'Companion skill: co-rar' $S/SKILL.md || err "SKILL.md lost the co-rar companion section"
grep -q 'under the prediction protocol, prediction rate' $S/SKILL.md || err "doctrine 5 lost the second signal"
grep -q 'evidence/<loop-name>.md' $S/SKILL.md && grep -q 'HALT/<loop-name>' $S/SKILL.md && grep -q '^├── KILL' $S/SKILL.md || err "SKILL.md state layout lost evidence/, HALT/ or KILL"

# prediction-protocol contract (spec §7 of task-flow's prediction-protocol design): the runner, the journal, the ladder, the halt
X=$R/predictions.md
for pin in \
  'export PP_SESSION="$(uuidgen)"' \
  '"$PREDICT" on "$LOOP" --loop --root "$CHECKOUT" --also' \
  'start="$("$PREDICT" report --json)" || true' \
  'end="$("$PREDICT" report --json)" || true' \
  'claude -p --session-id "$PP_SESSION" --output-format stream-json' \
  '"$PREDICT" status --json > "$TICK/status.json"' \
  'on "$LOOP-verify" --loop --root "$CHECKOUT"' \
  '[ "$gate" = active ] || [ "$RUNG" = shadow ]' \
  'Gated and autonomous ticks do not run without `active`' \
  'never a hand count' \
  'whatever the executor did afterwards' \
  'fired-without-verdict' \
  '**after** the `end` snapshot' \
  'gate_denies' \
  'loops/HALT/<loop>' \
  'sudo -u <runner> env PP_SESSION=<uuid>' \
  'never the directory as a whole' \
  'fail:journal-tamper' \
  'wrote a receipt: FAIL' \
  'no zeros invented' \
  '"destructive_miss"' \
  '≥ 1.0.2' \
  'the thresholds live in spec §7 only' ; do grep -qF -- "$pin" $X || err "predictions.md lost: $pin"; done
grep -q '"predictions":{"gate":"active|absent|broken","session":"<uuid>","start"' $R/ladder.md || err "ladder.md journal schema lost predictions start/end"
grep -q '"gate_denies":\[\]' $R/ladder.md || err "ladder.md journal schema lost gate_denies"
grep -q '^## Reading the prediction numbers' $R/ladder.md || err "ladder.md lost the reading section"
grep -q 'Never average per-tick rates' $R/ladder.md || err "ladder.md lost the aggregation rule"
grep -q 'zero receipts is a fact, not a 100' $R/ladder.md || err "ladder.md lost the n=0 rule"
grep -q 'loops/HALT/<loop>' $R/ladder.md || err "ladder.md run.sh rules lost the HALT check"
grep -q 'delta.destructive_miss' $R/ladder.md || err "ladder.md lost the destructive-MISS demotion"
grep -q '<loop>-critic' $R/ladder.md || err "ladder.md critic lost its own session"
grep -q 'predict report --journal loops/evidence/<loop>.md' $R/ladder.md || err "ladder.md audit lost the report line"
grep -q 'gate_seen ≠ never' $R/gaps.md || err "gaps.md lost the platform canary"
grep -q '`python3` or `jq`' $R/gaps.md || err "gaps.md lost the parser prerequisite"
grep -q 'PP_STATE_DIR' $R/gaps.md || err "gaps.md lost the persistent state root for CI runners"
grep -q 'never a receipt it writes' $R/security.md || err "security.md lost the deny-is-a-finding rule"
grep -q 'undeclared wrapper is a silent bypass' $R/security.md || err "security.md lost the --also rule"
grep -q 'predict on --also' $R/loop-spec.md || err "loop-spec.md §4 lost the wrappers row"
grep -q 'predictions.gate = active' $R/loop-spec.md || err "loop-spec.md §3.1 lost the prediction gate row"
grep -q 'prediction rate ≥ __% (default 90)' $R/loop-spec.md || err "loop-spec.md §7 lost the prediction thresholds"
grep -q 'n = 0 (no one-way actions' $R/loop-spec.md || err "loop-spec.md §7 lost the n=0 rule"
grep -q 'prediction MISS' $R/loop-spec.md || err "loop-spec.md §8 lost the MISS trigger"
grep -q 'REFUTED.md` rows added' $R/loop-spec.md || err "loop-spec.md §9 lost the audit line"
# the numeric defaults for the prediction thresholds are stated in exactly one file
for t in 'default 90' 'default 10'; do n="$(grep -l -- "$t" $R/*.md $S/SKILL.md | wc -l)"; [ "$n" -eq 1 ] && grep -q -- "$t" $R/loop-spec.md || err "'$t' must appear in loop-spec.md only (found in $n files)"; done
grep -nE 'advisory only|may override|optional past shadow' $R/*.md $S/SKILL.md >/dev/null && err "a pinned rule was softened"

# doctrine invariants that are greps
grep -q 'executor never grades its own homework' $S/SKILL.md || err "SKILL.md lost the self-grading doctrine"
grep -q 'data, never instructions' $S/SKILL.md || err "SKILL.md lost the external-text doctrine"
grep -rn '/home/' $P README.md >/dev/null && err "personal path under $P or README.md"
grep -rn 'Co-Authored-By' $P >/dev/null && err "trailer text in the payload"

[ "$fail" -eq 0 ] && echo "lint: OK ($v)"; exit "$fail"
