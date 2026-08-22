# Gap Analysis & Infrastructure (Phase 4)

Goal: everything the approved specs require but the project lacks, converted into approved, tracked, executed work. Gaps are closed by normal supervised Claude Code sessions — never by the loops themselves.

## 1. Diff specs against reality

For each approved spec, walk this checklist against Phase 0 findings:

**Credentials & scopes**
- [ ] YouTrack token with the scope each phase needs (read for triage; write for tagging/task creation)
- [ ] GitLab token scoped to this project only (api/read_repository/write_repository as the spec demands — not a personal full-access PAT)
- [ ] Loop-specific tokens distinct from the operator's interactive tokens (revocable independently)
- [ ] Secrets storage: CI/CD variables (masked, protected) or the host's secret store — never the repo, never the journal

**Runner & trigger**
- [ ] Where does this loop physically run? Options, with trade-offs to present:
  - *GitLab scheduled pipeline* — native to the delivery stack, logs/artifacts for free, secrets via CI variables; needs a runner with `claude` CLI available, and the prediction protocol's state root (`PP_STATE_DIR`) on a persistent volume — an ephemeral `$HOME` destroys receipts before the operator can ack, so without one this variant stays in shadow
  - *cron / systemd timer on the dev or remote host* — simplest, closest to the working copies; needs its own log shipping and kill switch
  - *per-event (webhook / MR pipeline)* — for per-MR loop classes
- [ ] Isolated working copy per loop (own checkout/worktree — loops never share a dirty tree with interactive sessions)
- [ ] `claude` CLI + auth available in the runner environment
- [ ] `predict` CLI (prediction-protocol ≥ 1.0.2) for the runner user: `PREDICT` pinned in the runner's env file to the installed plugin's `bin/predict` (nothing puts it on `PATH`; the path carries the version — re-pin after every plugin update); `python3` or `jq` on that user's `PATH` (the hook's stdin parser — without one `predict selftest` still prints `predict-gate: active` while every one-way command is refused); `~/.local/state` writable
- [ ] Platform canary — the only proof of `active` the gated rung accepts: under an exported `PP_SESSION` and `predict on`, a `claude -p --session-id <uuid>` with a one-way canary (`git push --force` to an empty origin) is denied in the transcript and `predict report --json` shows `gate_seen ≠ never`; repeated after every plugin or Claude Code update, like the kill-switch re-test (predictions.md)

**Verification substrate**
- [ ] Test/benchmark commands runnable headlessly in the runner env
- [ ] Eval set + hold-out partition (for statistical gates) — if missing, this is usually the LARGEST gap and a prerequisite, not an afterthought; building the golden set is operator-expertise work
- [ ] Reference data / synthetic ground truth where the spec calls for numerical gates

**Journal & telemetry**
- [ ] `loops/journal/` plumbing: writer in the runner, JSONL schema (ladder.md)
- [ ] Cost capture per run (tokens/$) → cost-per-accepted-result
- [ ] Escalation channel reachable from the runner (file inbox / YouTrack issue / messenger webhook)

**Safety**
- [ ] Kill switch implemented AND tested in shadow
- [ ] Forbidden-action enforcement (A-5 map) at the runner level where possible (e.g. token simply lacks the scope), not only in the prompt
- [ ] `loops/HALT/<loop>` pause marker honoured by `run.sh`; the operator's ack path (runner host, runner user, `PP_SESSION=<uuid>`) documented in the escalation channel

## 2. Write GAPS.md

```markdown
# Gaps — <project> — <date>
| # | Gap | Blocks (loop/phase) | Proposed solution | Effort | YouTrack |
|---|---|---|---|---|---|
```

## 3. Draft YouTrack tasks

One task per gap, in the project's own tracker — the operator approves work where the backlog lives. Each draft: **summary** (imperative, ≤80 chars), **description** (why: which spec section needs it; what: concrete change; how verified), **acceptance criteria** (machine-checkable where possible). Present the batch; create via API only after approval; tag `loop:infra`.

## 4. Execute

Close gaps one at a time in supervised sessions. Each closure: implement → verify acceptance criteria → commit (reference the YouTrack ID in the message so the GitLab↔YouTrack linkage fires) → resolve the issue. Update STATE.md after each. When all gaps blocking the pilot are closed, Phase 5 may begin for the pilot even if non-pilot gaps remain open.
