# Changelog

All notable changes to this plugin are recorded here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versioning follows
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

The authoritative version lives in
`plugins/loop-foundry/.claude-plugin/plugin.json`; every release below is tagged
`vX.Y.Z` in git. Installs track the default branch, so a tag marks history
rather than a download.

## [1.1.0] — 2026-08-22

### Added
- `references/predictions.md` — the prediction-protocol contract inside a
  tick: one `PP_SESSION` for the executor and another for the verifier
  (`<loop>-verify`, any entry there is a FAIL), `predict on <loop> --loop
  --also …` before each, `predict report --json` snapshotted **before and
  after** the executor (the loop journal is cumulative, so the tick is a
  difference) and both stored in the tick record as `predictions` with a
  `delta` computed by `journal.py`, `predict status` as a deterministic gate,
  `gate_denies` read from the executor's `stream-json`, the MISS →
  `loops/HALT/<loop>` pause, the operator's ack on the runner host as the
  runner user, the pruning rule that never deletes a halted session, the
  artifacts `predict` writes into the checkout and their append-only gate.
- SKILL.md: "Companion plugin: prediction-protocol" — shadow loops run and
  record `predictions.gate = absent` without the plugin; the gated and
  autonomous rungs require `predict-gate: active` for the runner user, proven
  by a `claude -p` canary, not by `selftest` alone. State layout gains
  `evidence/`, `HALT/`, `KILL`; the resume rule reports `loops/HALT/*`.
- `scripts/lint.sh` and a GitHub Actions `check` workflow: manifests, version
  ↔ CHANGELOG, SKILL triggers and a STOP in each of phases 1–4, the reference
  list inside "Reference files" ↔ README ↔ CLAUDE.md, reference size caps, the
  thresholds stated in one file only, and the prediction-protocol contract
  line by line.

### Changed
- SKILL.md orchestrator: doctrine 5 names the prediction rate as the second
  signal; Phase 5 steps 1, 3 and 5 route through the protocol and quote its
  numbers next to the approval rate.
- `ladder.md`: runner shape (`run.sh` owns `PP_SESSION`, the snapshots and
  the HALT marker; `gates.sh` adds `predict status`; `journal.py` subtracts),
  journal schema gains `predictions` and `gate_denies`, new section "Reading
  the prediction numbers" (sum deltas over the window, never average rates;
  thresholds live in spec §7 only), demotion triggers for a destructive-scope
  MISS and for a gate not `active` past shadow, the critic tick under its own
  `<loop>-critic` session with two protocol probes, the weekly audit and the
  pilot debrief read `REFUTED.md`.
- `gaps.md`: `PREDICT` pinned to the installed plugin (nothing puts it on
  `PATH`), `python3`/`jq` for the hook's parser, the platform canary, a
  persistent state root for the GitLab scheduled-pipeline variant, the HALT /
  ack path. `security.md` §4: receipts cover the executor and verifier
  *sessions*, `run.sh`/`deliver.sh` are covered by the rung; undeclared
  wrappers are a silent bypass; `ack`/`withdraw`/`off` are the operator's.
  `loop-spec.md`: §3.1 prediction-gate row, §4 one-way wrappers (→ `--also`),
  §6 field, §7 the single canonical statement of the thresholds (defaults 90 %
  / ≤ 10 % INCONCLUSIVE, the n < 20 and n = 0 rules, no bypass/ungated), §8
  MISS trigger, §9 audit line.
- Manifest descriptions name the companion. Reviewed by a 13-agent panel (41
  findings, 28 survived the 2/3 vote, 6 from the completeness critic — all
  addressed here or in prediction-protocol 1.0.2); the runner contract was
  acceptance-run against the installed plugin.

## [1.0.0] — 2026-06-12

### Added
- Initial release: the loop-engineering pipeline as a Claude Code plugin.
  Takes a project from an applicability assessment, through backlog inventory
  and triage, to written LOOP_SPECs, generated runner scripts, gap analysis and
  a staged launch ladder — shadow → gated → autonomous — with measured approval
  rates at each rung.
- The pipeline **refuses to build loops where the approach does not apply**: a
  NO-GO verdict is a successful outcome, not a failure. That is the property
  that keeps the rest of the ladder meaningful.

### Housekeeping (2026-07-07, no behaviour change)
- Adopted the `anthropics/knowledge-work-plugins` catalog conventions: a single
  source of truth for the version (`plugin.json` only), `displayName` in the
  marketplace entry, and an MIT `LICENSE` file.

[1.1.0]: https://github.com/umar-s/loop-foundry/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/umar-s/loop-foundry/releases/tag/v1.0.0
