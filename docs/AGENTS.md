# Documentation Instructions

Supplements the root `AGENTS.md` for everything under `docs/`.

* `docs/production/` holds current, long-lived documents: `STATUS.md` (one page, overwritten),
  `ROADMAP.md` (forward plan only), `BUILD.md`, `REPOSITORY_POLICY.md`, `GODOT_AI_DEVELOPMENT.md`,
  `LICENSE_PROVENANCE.md`, `PROJECT_SCOPE.md` and `contracts/`.
* `docs/migration/` holds `DECISIONS.md` and, when useful, one short note per content package
  (LPC→native mapping, source anomalies, deferred items). Name new notes by content, e.g.
  `SNOW_SHOPS.md`, not by phase code.
* Existing `PHASE_*` and `MIGRATION_TOOLING_V1_*` files are historical records. Keep them; do not
  extend, re-audit or reorganize them.
* Do not add audit reports, re-audits, blocker write-ups, evidence logs, screenshots or tool output
  to the repository. Commit SHAs, CI run IDs and assertion counts belong in PRs, not in docs.
* Prefer updating an existing current document over creating a new one.
