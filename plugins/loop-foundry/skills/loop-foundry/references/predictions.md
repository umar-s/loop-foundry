# Prediction Protocol in Loops (Phase 5, read with ladder.md)

A second, tool-graded signal on the ladder. With the `prediction-protocol` plugin (≥ 1.0.2) installed for the runner user, every **classified** one-way command a tick's sessions run (migration, force-push / branch delete, PR/MR merge — a local `git merge` is reversible and not classified — deploy, restart, mutating HTTP, remote exec, secrets, recursive delete) and every project wrapper declared through `--also` is **denied by a PreToolUse hook** unless the session holds a receipt for that exact command — hypothesis, read-only measurement, falsifiable claim — and `predict close` runs the measurement and grades HIT / MISS / INCONCLUSIVE. Loop-foundry consumes the tool's numbers; `journal.py` only subtracts them. How the ladder reads them is in ladder.md; the thresholds live in spec §7 only.

## Runner contract (`run.sh`, per tick)

```bash
PREDICT="${PREDICT:-$(ls -d "$HOME"/.claude/plugins/cache/*/prediction-protocol/*/bin/predict 2>/dev/null | sort -V | tail -1)}"  # nothing puts predict on PATH: pin it in the runner's env file (GAPS)
gate=absent
if [ -n "$PREDICT" ]; then
  export PP_SESSION="$(uuidgen)"                                  # one id per tick; the CLI and the hook key the same state by it
  on="$("$PREDICT" on "$LOOP" --loop --root "$CHECKOUT" --also '<wrapper from spec §4>' …)" && gate=active || gate=broken   # rc ≠ 0 after an "active" line = state not written = broken
  start="$("$PREDICT" report --json)" || true                     # snapshot BEFORE the executor: the loop journal is cumulative, the tick is a difference
fi
[ "$gate" = active ] || [ "$RUNG" = shadow ] || { journal_escalated "predict-gate: $gate"; exit 0; }   # gated and autonomous never tick ungated
claude -p --session-id "$PP_SESSION" --output-format stream-json … "$EXECUTOR_PROMPT" > "$TICK/executor.jsonl"
if [ "$gate" = active ]; then
  "$PREDICT" status --json > "$TICK/status.json"; halted=$?      # snapshot of the executor session, taken BEFORE the verifier; exit ≠ 0 = halted
  end="$("$PREDICT" report --json)" || true                       # rc 1 = lint findings in the journal (an un-acked MISS); the JSON is printed either way
  vs="$(uuidgen)"; PP_SESSION="$vs" "$PREDICT" on "$LOOP-verify" --loop --root "$CHECKOUT" >/dev/null   # the verifier's own session: it cannot fire the executor's receipt
fi
PP_SESSION="$vs" claude -p --session-id "$vs" … "$VERIFIER_PROMPT"
```

Rules baked into the runner, not left to the model:

- **`gate` is the word on the `predict on` line** — `active` or `broken` — or `absent` when no CLI resolves; the line comes from `predict selftest`, a runner cannot print `active` by itself, and `selftest` proves the hook *script*, not its registration in the runner user's Claude Code — that proof is `gate_seen` (the canary in gaps.md). Shadow ticks may run with `absent`/`broken` and record it — they then run **ungated** (outside the protocol the hook passes everything in headless mode), tolerable only on the read-only tokens shadow has (security.md §2). **Gated and autonomous ticks do not run without `active`:** outcome `escalated`, reason `predict-gate: absent|broken`, `deliver.sh` never reached.
- **Two snapshots, one subtraction.** `journal.py` stores `start` and `end` verbatim and computes `delta = end − start` for `hit miss inconclusive bypass withdrawn ungated` and `destructive_miss` — a subtraction of two tool outputs, never a hand count. `open`, `inflight` and `gate_seen` are per session: read them from `end` and `status.json`.
- **`gates.sh` reads the tool, not the transcript:** `status` exit ≠ 0 → `fail:prediction-halt`; `delta.miss > 0`, `delta.withdrawn > 0` or `delta.bypass > 0` → `escalated`, whatever the executor did afterwards (under `--loop` the plugin refuses `ack`, `withdraw` and `off` inside a Claude session; an `env -u CLAUDE_CODE_SESSION_ID` bypass still shows in the deltas and is named in the reason); `inflight > 0` in `status.json` (a receipt fired, no verdict) → `escalated`, reason `fired-without-verdict`; `open > 0` → `run.sh` runs `"$PREDICT" withdraw <id> --reason 'executor ended'` **after** the `end` snapshot, so the withdrawal lands in no tick's delta. `retry` stays the executor's.
- **A deny leaves no trace in the journal**, so `run.sh` greps the executor's `stream-json` tool results for `prediction-protocol v` lines carrying a deny and writes the normalised commands as `gate_denies` (runner-read, outside `predictions`). The verifier receives that list as an artifact: a deny with no later closed receipt for the same command is a FAIL finding — the executor attempted a one-way action and did not measure it.
- **A MISS pauses the loop:** `run.sh` writes `loops/HALT/<loop>` — `<uuid> <receipt-id> <utc>` and the exact ack command — and checks it first, next to `loops/KILL`. The operator acts **on the runner host as the runner user** (the state is that user's `~/.local/state`, created with `umask 077`; an operator account sees nothing): `sudo -u <runner> env PP_SESSION=<uuid> "$PREDICT" ack <id> --refuted '<belief>' --where '<paths>'` — the full uuid is `predictions.session`, `predict` itself prints only its 8-char hash. "Already acknowledged" means the executor bypassed the rule: `delta.miss` already escalated the tick; read the `REFUTED.md` row it wrote and append a corrected row by hand if it is wrong. Then review the spec (a false belief about the system is a §3 gate gap or a §1 proxy) and remove the marker. Not automated, not skippable.
- **State and pruning.** Receipt state lives under the runner user's `~/.local/state/prediction-protocol/`, one directory per session uuid; `run.sh` prunes sessions older than 7 days **only** when the uuid is named in no `loops/HALT/*` and the session's `state` carries no `halted=` — never the directory as a whole: it is shared by every loop and by that user's interactive sessions.
- **Artifacts `predict` writes into the checkout:** `loops/evidence/<loop>.md`, `<loop>-verify.md`, `<loop>-critic.md` (ladder.md) and `docs/evidence/REFUTED.md` of the checkout root. Only `predict` writes them: exclude them from the §3.1 diff allowlist, and let `gates.sh` snapshot the `### predict` headers before the executor and require append-only afterwards (`fail:journal-tamper`). They are persisted in the same step as `loops/journal/<loop>.jsonl`, whatever that step is for this runner; one checkout per loop means one ledger per loop — the weekly audit reads every loop's `REFUTED.md`, and the executor prompt reads its own before touching the paths it names. **Any entry in `<loop>-verify.md` means the verifier wrote a receipt: FAIL.**
- **Headless means silent.** In `claude -p` the hook passes receipt-backed and out-of-scope commands without a prompt and denies the rest with a recipe; `run.sh` and `deliver.sh` run outside the hook — their one-way action is covered by the rung (gated approval, the granted class), not by a receipt. The gate never widens permissions — it only refuses.

## Journal field (`loops/journal/<loop-name>.jsonl`)

```json
"predictions":{"gate":"active","session":"<uuid>",
 "start":{"hit":0,"miss":0,"inconclusive":0,"bypass":0,"withdrawn":0,"ungated":0,"open":0,
          "destructive":{"hit":0,"miss":0,"inconclusive":0},"n":0,"rate":"insufficient (n<20)",
          "window":"<loop>","journal":"<abs path of loops/evidence/<loop>.md on the runner>",
          "lint_failures":0,"gate_seen":"<utc>|never","contract":1,"version":"<predict version>"},
 "end":{"…":"same shape"},
 "delta":{"hit":0,"miss":0,"inconclusive":0,"bypass":0,"withdrawn":0,"ungated":0,"destructive_miss":0}},
"gate_denies":[]
```

`start`/`end` are `predict report --json` as printed — `journal` is the runner-side absolute path and stays: it is the reproduction pointer for `predict report --journal`. With `gate` ≠ `active` the object is `{"gate":"absent|broken","session":"<uuid>|null"}` — no zeros invented.

## What the protocol is not

- **Not the verifier.** HIT means the measurement matched the claim. Whether the result is good is still the verifier's verdict plus §3.1.
- **Not a permission system.** A deny is recoverable by a receipt; scope (§4 allowlist, token scopes, protected branches) is what makes an action impossible.
- **Not a licence for `deliver.sh`.** Rung 3 performs exactly the granted action class; a receipt makes an action measurable, not permitted.
