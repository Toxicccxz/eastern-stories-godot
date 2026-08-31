# Documentation Instructions

These instructions supplement the root `AGENTS.md` and apply to everything under `docs/`.

## Phase-scoped documents

All documents whose primary purpose is to record a specific development phase or subphase MUST live under `docs/migration/`, regardless of whether that phase concerns gameplay migration, runtime architecture, persistence, productionization, build tooling, or release engineering.

This includes:

- phase analysis and dependency studies;
- implementation reports;
- formal-audit reports and corrections;
- phase-specific validation/evidence records;
- phase close/closure records.

Any document whose filename begins with `PHASE_` MUST be created under `docs/migration/`.

Examples:

- `docs/migration/PHASE_10B_NATIVE_SAVE_LOAD_ANALYSIS.md`
- `docs/migration/PHASE_10B1_TYPED_SAVE_CODEC_REPOSITORY.md`
- `docs/migration/PHASE_10B4_PROCESS_RESTART_VALIDATION.md`

Do NOT place `PHASE_*.md` under `docs/production/` merely because the phase belongs to Productionization / Stabilization.

## Long-lived production documents

`docs/production/` is reserved for durable, current project-operational documentation whose meaning survives individual phase boundaries, such as:

- `STATUS.md`;
- `ROADMAP.md`;
- `BUILD.md`;
- `REPOSITORY_POLICY.md`;
- `GODOT_AI_DEVELOPMENT.md`;
- `LICENSE_PROVENANCE.md`;
- `DOCUMENTATION_POLICY.md`;
- similar long-lived build, repository, release, or developer policies.

If a phase creates a lasting project policy, keep the phase-specific analysis/audit record under `docs/migration/` and update or create the corresponding long-lived document under `docs/production/` separately. Do not use a phase document as the permanent operational policy.

## Migration decisions

`docs/migration/DECISIONS.md` remains the ledger for explicit gameplay/source-compatibility substitutions. Do not move general repository/build/developer policy into that file.

## Misplaced phase documents

Do not interrupt an actively running implementation slice solely to move a misplaced document. At the next safe phase boundary, before starting the next subphase or before the final integration PR, move any current active-phase document to the correct directory and update all repository references.

Prefer a real move/rename so history remains understandable. Do not duplicate the same phase document in both `docs/production/` and `docs/migration/`.

Historical closed-phase files are not bulk-reorganized unless the user explicitly asks. The rule applies prospectively, and any misplaced document in the current active major phase should be corrected before that major phase is integrated.

## Before creating a document

Before creating any new phase document, Codex MUST determine whether it is phase-scoped or long-lived operational documentation and choose the directory accordingly. When uncertain:

- specific phase/subphase evidence/history -> `docs/migration/`;
- current durable project policy/status/how-to -> `docs/production/`.
