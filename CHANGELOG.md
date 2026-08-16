# Changelog

All notable changes to this plugin are recorded here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versioning follows
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

The authoritative version lives in
`plugins/loop-foundry/.claude-plugin/plugin.json`; every release below is tagged
`vX.Y.Z` in git. Installs track the default branch, so a tag marks history
rather than a download.

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

[1.0.0]: https://github.com/umar-s/loop-foundry/releases/tag/v1.0.0
