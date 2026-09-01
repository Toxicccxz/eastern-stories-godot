# Phase 10B1 — Formal Audit

## Audit identity and scope

- Branch: `phase/10b-native-save-load`.
- Analysis baseline: `dd604be` (`docs: analyze Phase 10B native save load boundary`).
- Implementation commit: `21e3452` (`feat: add Phase 10B1 save codec foundation`).
- Main synchronization: `8ed736f`, including repository/documentation policy through `aaa5b3a`.
- Documentation relocation: `71f8e29` (`docs: move Phase 10B records under migration`).
- Pre-audit implementation range reviewed: `dd604be..71f8e29` (with `dd604be` reviewed as the accepted Analysis baseline).
- The audit did not start Phase 10B2 and made no Session, gameplay, world, scene, UI, or physics changes.
- Remote PR refs contained only PRs 1–3; none pointed at this Phase 10B branch. This audit did not create a PR.

## Files reviewed

Instructions and records:

- `AGENTS.md`, `docs/AGENTS.md`;
- `docs/migration/PHASE_10B_NATIVE_SAVE_LOAD_ANALYSIS.md`;
- `docs/migration/PHASE_10B1_TYPED_SAVE_CODEC_REPOSITORY.md`;
- `docs/production/REPOSITORY_POLICY.md`;
- `docs/migration/DECISIONS.md`;
- `docs/migration/PHASE_4B5A_NATIVE_ITEM_SAVE_RESTORE.md`.

Phase 10B1 production and tests:

- all seven Phase 10B1 core persistence files: `decimal_int64_codec.gd`, the five
  `game_save_*.gd` files, and `random_stream_snapshot.gd`;
- all five `game/runtime/persistence/*.gd` files;
- the Combat, NPC-initialization, and WorldInteraction Godot RNG adapters;
- `game/tests/core/game_save_json_codec_test.gd`;
- `game/tests/runtime/game_save_repository_test.gd` and `random_stream_persistence_test.gd`;
- `game/tests/support/game_save_test_fixture.gd`;
- `game/tests/run_phase_10b1_tests.gd` and the Phase 10B1 registration/result aggregation in `game/tests/run_tests.gd`.

Relevant closed-domain authority and regression files were cross-checked, including `CharacterState`,
Skill and Condition state/payload classes, `ConditionIds`, the Phase 4B5A native item snapshot,
validator, records and definition projections, and the existing Phase 5/6/7/9 focused runners.
The accepted Analysis did not reveal a legacy contradiction, so the LPC tree was not rescanned or
modified during this audit.

## Findings and fixes

Three concrete defects were found and corrected:

1. `GameSaveSnapshotValidator` accepted a represented but incompatible payload kind for a known
   condition ID. Known `poison` now requires the typed poison record; the six known duration IDs
   require the typed duration record. Open nonempty IDs still accept either represented typed shape.
2. NPC Character IDs were not checked against the Player or other NPC records. The validator now
   rejects duplicate Character authority across Player/NPC runtime records instead of permitting
   ambiguous last-consumer behavior.
3. The Analysis still said the phase record belonged under `docs/production`. That stale prose now
   follows the repository-wide `docs/migration` placement policy.

The implementation already had correct behavior but insufficient adversarial proof for several
formal-audit requirements. Tests were expanded for canonical ordering from differently ordered
source arrays, caller-array/payload alias resistance, nested missing/unknown JSON fields, inert
path-like text, non-ASCII int64 digits, the complete UTF-8 boundary matrix, path traversal variants,
stale-backup removal, corrupt-temp preservation of both canonical and backup, invalid recovery
files, and operation-gate release after failure. RNG continuation now covers prefixes 0, 1, 2, 7,
and 31 independently for all three adapters, including mismatch non-mutation and zero-draw capture
and restore.

No broader architecture change was needed. `DECISIONS.md` remained unchanged.

## Architecture and security conclusions

- `GameSaveSnapshot` remains the sole typed game-save root. Raw Dictionary/Array shapes are confined
  to the handwritten JSON codec boundary; no LPC-style path database or reflection persistence was
  introduced.
- Game schema v1 and embedded item schema v1 are independently checked and produce distinct typed
  failures. The root directly embeds defensive `NativeItemStateSnapshot`; no second Inventory,
  Equipment, Armor, or Combined Stack persistence model exists.
- The Character snapshot contains the accepted durable v1 fields exactly once. Equipment and Armor
  remain owned by the embedded Phase 4 item snapshot, and generic temporary modifiers remain absent.
- Skills preserve raw/learned/mapping presence distinctions, uniqueness, target requirements, open
  IDs, defensive values, and stable ordering. Conditions expose only duration/poison typed records,
  strict shapes, known-ID compatibility, and open-ID structural preservation.
- Region, map, zone, and combat-location IDs are independent fields. Position contains only finite
  numeric x/y values; no zone/combat-location inference occurs.
- Every arbitrary gameplay integer in JSON uses a canonical decimal string. The exact grammar,
  signed int64 limits, INT64_MIN special case, overflow/underflow, and non-string rejection passed;
  no integer parse passes through float.
- UTF-8 validation accepts ASCII and valid 2/3/4-byte sequences (including U+0000 as valid UTF-8)
  and rejects truncation, bad continuation, overlong forms, surrogates, values above U+10FFFF, and
  stray continuation bytes. Valid U+0000 followed by JSON parsing is correctly reported as malformed
  JSON rather than invalid UTF-8.
- Every v1 structural object rejects missing and unknown fields. Save input cannot select scripts,
  resources, classes, Callables, NodePaths, or Objects; path-like strings remain inert field data.
- Snapshot constructors and getters prevent caller array/payload alias mutation. ID-addressed
  collections encode canonically, and all required duplicate authorities reject.

## RNG audit

All three adapters retain the pre-10B1 `next_below()` implementation. Their added persistence seam
uses the stable `godot-random-number-generator-pcg32-v1` ID, captures seed/state without drawing,
rejects an incompatible adapter without mutation, restores seed before state, and consumes no draw.
Exact continuation passed after prefixes 0, 1, 2, 7, and 31 for Combat, NPC initialization, and
WorldInteraction independently. Signed seed/state values remain represented by the same canonical
int64 codec.

## Repository and storage audit

- Development, release, and isolated-test paths are fixed and disjoint. Test child IDs accept only
  ASCII letters, digits, hyphen, and underscore; traversal, slash/backslash, drive, UNC, colon,
  Unicode separator-lookalike, empty, and surrounding-whitespace inputs reject.
- Cleanup tests remove only known files beneath a validated exact test child and then that child;
  they never recursively remove a save root or another profile.
- `GodotSaveFileOperations` checks file length before `get_buffer`, enforcing the 16 MiB bound before
  UTF-8 or JSON decode.
- First save produces only a valid canonical file. Second save produces canonical=new,
  backup=old, no temp; both decode independently.
- Temp is reopened and decoded before stale-backup removal or canonical rotation. Corrupt temp leaves
  canonical and old backup byte-identical. Stale-backup removal and rotation failures are typed and
  cannot report success.
- Final replacement failure always reports failure and attempts rollback after a completed rotation.
  Successful rollback restores canonical; failed rollback is explicit and retains backup/temp
  recovery evidence.
- `BACKUP_AVAILABLE` requires a fully decodable backup or temp and never auto-restores. Invalid
  recovery files do not count; missing canonical with no valid recovery returns `NO_SAVE`.
- The synchronous operation gate rejects reentry and was proven released after injected save/load
  failures. Repository code remains below Session/gameplay and has no Node, Autoload, SceneTree, UI,
  Character mutation, or live restore behavior.
- The production Godot adapter test reconfirmed Windows 4.7.2 same-directory rename, missing-source
  failure, and existing-destination replacement behavior.

## Verification

- Phase 10B1 focused: **563 assertions passed**.
- Phase 4B5A regression in that runner: **291 assertions passed**; combined focused total: **854**.
- Character/Skill/Condition focused audit: **177 / 118 / 96**, total **391 assertions passed**.
- Phase 5B1 focused: **414 assertions passed**.
- Phase 6B2 focused: **1,153 assertions passed**.
- Phase 7B1 focused: **1,983 assertions passed**.
- Phase 9B3B2 focused: **4,584 assertions passed**.
- Canonical complete suite (run once after fixes): **9,282 assertions passed**. The known Old Pine
  timing flake did not occur.
- Godot **4.7.2** development headless editor validation: passed with zero parse errors.
- Fresh sanitizer staging: production persistence remained; tests and Godot AI development helper
  artifacts were absent; sanitized-project Godot 4.7.2 headless editor validation passed.
- Python tooling: **40 tests passed**.
- Repository/static checks, forbidden absolute-path/generated-artifact checks, `git diff --check`,
  and trailing-whitespace check: passed.
- `reference/es2` modifications: **0**.
- `docs/migration/DECISIONS.md` modifications: **0**.
- Session/gameplay/world/scene/UI behavior modifications made by the audit: **0**.

Live player runtime validation is not applicable to this slice: Phase 10B1 does not capture or load
a live Session and changes no SceneTree, traversal, combat, UI, or physics behavior.

## Formal status

All Phase 10B1 formal-close blockers passed. Phase 10B1 is **FORMALLY CLOSED** and Phase 10B2 may
begin from this typed codec/repository boundary.
