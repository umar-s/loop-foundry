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
  - *GitLab scheduled pipeline* — native to the delivery stack, logs/artifacts for free, secrets via CI variables; needs a runner with `claude` CLI available
  - *cron / systemd timer on the dev or remote host* — simplest, closest to the working copies; needs its own log shipping and kill switch
  - *per-event (webhook / MR pipeline)* — for per-MR loop classes
- [ ] Isolated working copy per loop (own checkout/worktree — loops never share a dirty tree with interactive sessions)
- [ ] `claude` CLI + auth available in the runner environment

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
