# The Applicability Filter

Two levels. Section A decides whether the *project* is ready for any loops at all (Phase 1). Section B decides per *task class* (Phase 2). A loop is built only when A passes and the task class passes B.

The filter's job is to say "no" often. Expected base rate: in a healthy backlog, most tasks are red. If your triage says otherwise, re-check Gate-2 honesty first.

## A. Project-level preconditions (Phase 1)

**A-1. Recurring work exists at all.** The backlog contains task *classes* that recur in recognizable form (CI maintenance, dependency updates, regression runs, triage, report generation). A backlog of purely unique feature work has nothing to loop — verdict NO-GO, revisit when maintenance load appears.

**A-2. Verification substrate exists or is buildable.** The project has (or can cheaply get) tests, typecheck, CI, benchmarks, or eval sets. A project with no automated checks of any kind must build them first — that is supervised work, not loop work. Verdict GO-WITH-GAPS if buildable.

**A-3. The operator can absorb discarded runs.** 10–20% of loop runs will be thrown away. Token/infra budget at the expected cadence, ×1.2 waste factor, must be acceptable. Compute the monthly number; do not hand-wave it.

**A-4. Tooling reachability.** The agent can actually reach what a senior engineer would use: repo, test runner, YouTrack API, GitLab API, the deployment target if relevant. Missing pieces → GAPS, not blockers — unless the critical path (e.g. tests only runnable on hardware the agent can't touch) is unreachable, which is NO-GO for the affected classes.

**A-5. Blast-radius map exists.** The operator can name, explicitly, the actions that are irreversible in this project (prod data migrations, billing, auth, user-data deletion, force-push to protected branches, releases). These go into every spec's forbidden list. If the operator cannot enumerate them, stop and enumerate them together — proceeding without the map is how A2-class accidents happen.

## B. Per-task-class gates (Phase 2)

A task class must pass ALL four gates and trip NO anti-condition.

### The four gates

**Gate-1 — Repetition.** The class recurs ≥ ~10×/month in recognizable form, OR is on a natural schedule (nightly, per-MR, per-release). One-offs fail here regardless of how automatable they look.

**Gate-2 — A machine check exists.** There is an `is_done()` the runner can evaluate without a human. Three admissible forms:

- *Boolean gates:* tests pass, build compiles, lint clean, diff within allowlist, benchmark within tolerance.
- *Numerical gates:* metric within ε of a reference; synthetic input with known ground truth recovered within bounds.
- *Statistical gates (AI-quality outputs only):* score on a golden/eval set ≥ baseline − allowed delta, **with a hold-out partition the loop never sees**. No eval set yet → the task class fails Gate-2 *today*; building the eval set becomes a GAPS item, and the class re-enters triage afterwards. Never substitute "the executor says it looks good" for a gate.

Honesty test: if the true answer is "a human will eyeball it," Gate-2 fails. Write that down.

**Gate-3 — Economics.** cost(run) × cadence × 1.2 < value of the human time displaced. Use real numbers from Phase 0 / first shadow runs. Track cost-per-*accepted*-result, not per run.

**Gate-4 — Tools in place.** Everything the executor needs for this class is reachable with the scopes the spec will grant. Otherwise: GAPS first.

### Anti-conditions (any one → red)

**X-1 Audit determinism required.** The output must be explainable by a rule for an external audit (compliance, GDPR data handling, financial records). Reasoning-in-execution fails the audit by construction.

**X-2 Irreversibility.** Worst-case output causes damage that cannot be rolled back: prod schema/data migrations, billing mutations, auth changes, user-data deletion, public releases. These task classes may *feed* a loop (the loop prepares, drafts, verifies) but the irreversible action itself is always a human act. Classify as 🟡 at best.

**X-3 One-shot.** No recurrence, no iteration. Do it interactively, well, once.

**X-4 Judgment-dominant.** The core of the task is a value call, architectural direction, or stakeholder communication. Loops can assemble the materials; the call is human.

### Classification output

- 🟢 green — passes all gates, no anti-conditions: candidate for the full ladder up to autonomy.
- 🟡 yellow — passes gates but trips X-2 or X-4 in its final step: loop prepares + verifies, human approves, **forever**.
- 🔴 red — fails a gate or trips X-1/X-3: name the exact failing condition in TRIAGE.md.

## Statistical gates — extra rules

When the gate is an eval-set threshold (AI features, generated content, retrieval quality):

1. Hold-out is mandatory: ≥25% of the eval set is invisible to the loop and used only by the verifier. The known proxy-risk is the loop overfitting the golden set — scores rise, product degrades.
2. The eval set is a living artifact: schedule its rotation/expansion from real production cases (itself a fine 🟡 loop).
3. Regression semantics: a drop vs baseline is FAIL even if the absolute score is "fine."
4. Divergence alarm: if eval scores hold but real-world signal (support tickets, user retries) worsens, the eval set has rotted. Audit it, don't trust it.
