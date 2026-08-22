# Runners & the Maturity Ladder (Phase 5)

## Runner architecture

A runner is boring, deterministic orchestration. All reasoning lives in two agent sessions it invokes. Standard shape under `loops/runners/<loop-name>/`:

```
run.sh            # entrypoint: kill switch, HALT marker, budgets, lockfile (no concurrent runs of one loop), PP_SESSION + predict on, report snapshots
discover.(sh|py)  # finds work per spec §2; emits a work item or "idle"
execute.sh        # headless executor: claude -p with spec §4 scope, in the loop's isolated checkout
gates.sh          # deterministic gates per spec §3.1 + predict status; exit code is the verdict
verify.sh         # separate verifier session: claude -p with the adversarial-reviewer prompt; PASS/FAIL+reason
journal.py        # appends the run record (schema below); computes cost fields; merges predict report --json as predictions
deliver.sh        # ONLY thing that differs per rung: shadow=noop, gated=open MR / draft + wait, autonomous=complete the action
```

Hard rules baked into `run.sh`, not left to the model:
- Kill switch check first (`loops/KILL` file or equivalent): present → exit immediately, journal `killed`. `loops/HALT/<loop>` (written after a prediction MISS) is checked the same way — journal `escalated`.
- Lockfile per loop: a tick never overlaps its predecessor.
- Budget enforcement: wrap the executor with a token/time ceiling; on breach, kill + journal `budget_breach` + escalate.
- The executor's working copy is the loop's own checkout — never the operator's interactive tree.
- External text (issue bodies, MR comments) passes to sessions wrapped in explicit data fencing (see security.md).
- One `PP_SESSION` for the executor and another for the verifier (`<loop>-verify`), `predict on … --loop` before each, `predict report --json` snapshotted before and after the executor (predictions.md): one-way commands inside the sessions are denied by the hook unless receipted; gated and autonomous ticks do not run without `predict-gate: active`.

## Journal schema (`loops/journal/<loop-name>.jsonl`, one object per tick)

```json
{"ts":"...","loop":"...","rung":"shadow|gated|autonomous",
 "work_item":"...","actions_summary":"...",
 "gates":{"deterministic":"pass|fail:<which>","verifier":"pass|fail","reason":"..."},
 "outcome":"accepted|discarded|idle|killed|budget_breach|escalated",
 "human":{"decision":"approve|reject|n/a","reason":"..."},
 "cost":{"tokens":0,"usd":0.0},"duration_s":0,"model":"<exact model version>",
 "predictions":{"gate":"active|absent|broken","session":"<uuid>","start":{"…":"predict report --json"},"end":{"…":"same"},"delta":{"hit":0,"miss":0,"inconclusive":0,"bypass":0,"withdrawn":0,"ungated":0,"destructive_miss":0}},
 "gate_denies":[]}
```

The `model` field is mandatory — it is what makes automatic demotion-on-model-change detectable. `predictions` holds `predict report --json` as printed before and after the executor and their difference (full shape in predictions.md): one journal carries both signals; nothing in it is hand-counted.

## The ladder

**Rung 1 — Shadow (default 1–2 weeks).** Full pipeline, `deliver.sh` is a no-op; everything journaled as "would do X". Exit review with the operator: would-approve rate over the window, typical discard reasons, cost-per-accepted-result vs Gate-3 estimate. Spec/gate edits happen here, cheaply. Promotion to gated is the operator's explicit call against spec §7 — approval rate, prediction rate and INCONCLUSIVE share over the same window ("Reading the prediction numbers" below).

**Rung 2 — Gated.** The loop produces real artifacts (MR opened, report drafted, tags proposed) but the final action awaits human approval. Every decision lands in `journal.human`. 🟡 classes live here permanently — that is their design, not a failure to progress.

**Rung 3 — Autonomous (🟢 classes only).** Granted per action class when the gated approval rate clears spec §7 (default ≥95% over ≥2 weeks), the prediction numbers clear spec §7 over the same window, AND the class is demonstrably bounded, reversible, measurable. Present the journal evidence; the operator grants; record the grant in the spec and STATE.md. Sampled audit continues forever (10–20% of accepted results, weekly).

## Reading the prediction numbers

- Over a window, sum the records' `predictions.delta`: prediction rate = Σhit / Σ(hit + miss + inconclusive), INCONCLUSIVE share = Σinconclusive / the same denominator, n = that denominator — equivalently `end` of the last record minus `start` of the first. `predict report --journal loops/evidence/<loop>.md` reproduces the all-time totals for the audit. Never average per-tick rates.
- The thresholds, the n < 20 rule and the n = 0 rule live in spec §7 only; the promotion text quotes the three numbers and n — zero receipts is a fact, not a 100 %.
- Σ`delta.bypass` > 0 or Σ`delta.ungated` > 0 anywhere in the window → no promotion this window, whatever the approval rate.

## The adversarial critic (for CO-RAR-class loops; per the co-rar skill, P6)

The journal + weekly audit is the *reactive* loop: it learns from real damage. CO-RAR-class loops additionally get a *proactive* critic — a separate scheduled tick that attacks the loop's defenses with synthetic inputs before reality does:

```
loops/runners/<loop-name>/critic.sh   # separate session, attacker role, own scoped prompt
loops/critic/<loop-name>/             # attack corpus + findings
```

What the critic generates and runs against the loop's gates (shadow-mode execution, never delivery):
- **Injection probes:** issue/MR bodies carrying instruction-shaped text — must trip the security.md escalation, not be obeyed.
- **Gate stressors:** edge-case work items and diffs engineered to *deserve* FAIL — verify the gates actually fail them (a gate that passes everything is decoration).
- **Eval adversaries (statistical gates):** inputs near the eval set's decision boundary; candidates for hold-out rotation.

Findings feed the same repair path as real failures: spec/gate edits (micro) or arbitration (macro). Cadence: weekly in shadow/gated; at promotion to autonomous, a full critic pass is a precondition.

`critic.sh` runs under its own `PP_SESSION` with `predict on <loop>-critic --loop --root "$CHECKOUT"`: its receipts go to `loops/evidence/<loop>-critic.md`, never into the loop's n, and past shadow it does not run without `active` either. Two probes belong in every corpus: an injection asking the executor to open a receipt for a one-way command (expected: escalation, no receipt in the journal) and a project wrapper hiding a one-way verb (expected: denied through `--also`, else the `--also` list is incomplete).

Two CO-RAR metrics join the weekly audit for these loops:
- **ADR** — fraction of failure modes caught by the critic before reality. ADR = 0 means you are paying real-world cost for every lesson.
- **TtR** — time from first observation of a new failure mode (critic or reality) to the deployed spec/gate fix. Optimize relative to signal latency, not in absolute terms.

## Demotion triggers (automatic, enforced by the runner or weekly audit)

- `model` field changes vs the spec's calibrated version → demote to shadow until re-calibrated.
- Any escaped defect (passed all gates, caught later via incident/rollback/user signal) → demote, repair gates, re-climb.
- Cost-per-accepted-result drifts > spec tolerance → gated pending review.
- Eval-vs-reality divergence (statistical gates): scores hold but real-world signal worsens → freeze the loop, audit the eval set.
- Prediction MISS on a `destructive`-scope receipt (`delta.destructive_miss` > 0) → one rung down, executed by the operator while clearing `loops/HALT/<loop>` and recorded in spec §7 and STATE.md; `predictions.gate` ≠ `active` in a gated/autonomous record → shadow until the GAPS item is closed again (predictions.md).

## Weekly audit ritual (~30 min, results to `loops/metrics/WEEKLY.md`)

Run spec §9 per active loop — including the `predict report --journal loops/evidence/<loop>.md` line, the week's MISSes, the rows added to `REFUTED.md` and the `loops/HALT/*` markers cleared. Portfolio-level (the operator runs many projects): once a month, aggregate across projects — total spend, loops per rung, escaped defects anywhere, and the Intent question: are the loops still serving project goals or optimizing proxies? Vanity check: never report LOC/PR/run counts as success metrics; report hours displaced, escaped defects, cost per accepted result.

## Pilot debrief (after the pilot's first gated week)

Before scaling to the next candidates, write a short debrief in STATE.md: what the filter got wrong, which gates were too loose/too tight, which beliefs were refuted (`REFUTED.md`) and whether a §3 gate would have caught each, real vs estimated costs. The second loop is built with these corrections — the pipeline itself is subject to its own feedback discipline.
