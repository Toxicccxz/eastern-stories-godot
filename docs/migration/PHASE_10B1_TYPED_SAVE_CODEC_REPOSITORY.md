# Phase 10B1 — Typed Save Codec and Repository

## Scope and accepted baseline

Phase 10B1 implements the pure value, JSON, file-storage, and RNG-continuation foundation selected
by `PHASE_10B_NATIVE_SAVE_LOAD_ANALYSIS.md`. It does not capture a live Session, restore a
`CharacterState`, bind maps/NPCs/corpses, decide save eligibility, or expose UI. The existing Phase
4B5A item schema remains the only inventory/equipment/armor persistence authority.

The native game format ID is `eastern-stories-native-save`; game schema version 1 is independent of
`NativeItemStateSnapshot.CURRENT_SCHEMA_VERSION == 1`. The only v1 Session kind is `oldpine`, and
the only slot ID is `default-v1`.

## Typed value model

`GameSaveSnapshot` is a defensive value root containing:

- metadata, Session kind, and item-ID allocator scope/continuation;
- one typed `PlayerRuntime` record;
- sorted typed `NpcSpawnState` and `Corpse` structural records;
- the existing `NativeItemStateSnapshot` directly;
- distinct Combat, NPC-initialization, and WorldInteraction `RandomStreamSnapshot` records.

`GameSaveValueTypes` groups cohesive data-only subordinate records, including
`PlayerRuntimeSnapshot`, `CharacterStateSnapshot`, `WorldLocationSnapshot`,
`MapPositionSnapshot`, `NpcSpawnStateSnapshot`, and `CorpseSnapshot`. Character persistence explicitly
stores gender; eight base attributes plus force factor and bellicosity; exact gin/kee/sen
current/effective/maximum tracks; force/mana/atman current/maximum pairs; food/water; represented
progression; skills; conditions; family; and apprenticeship. Equipment and Armor do not occur in the
Character record.

Skills use sorted typed `(skill_id, value)` records for raw and learned mappings, typed
`(use_id, skill_id)` enabled mappings, and both lazy mapping-presence booleans. Nonempty open skill
IDs remain structurally valid; mapped targets require a raw record. Conditions use only tagged
`duration` and `poison` records. Their exact fields are strict, and open nonempty condition IDs are
preserved without claiming an effect implementation. Known IDs must use their matching represented
payload kind. There is no generic payload Dictionary. Player and NPC Character IDs are unique across
the runtime records in one root snapshot.

`WorldLocation` stores region, map, zone, and combat-location IDs independently. `MapPosition`
stores finite numeric `x`/`y`; it never serializes a `Vector2`, Transform, or NodePath. NPC and corpse
records are immutable structural data only; no capture/reconstruction or authored-content lookup was
added in this slice.

Temporary attribute modifiers are absent. No Player age, body weight, score, quest state, or other
currently nonexistent durable field was invented.

## Native Item embedding

The root codec projects the existing item schema v1 to JSON and back. It preserves exact
`ItemInstanceId`, `ItemDefinitionId`, own weight, nullable direct parent, combined amount, hand
records, and open armor-slot records. Game schema and embedded item schema failures have distinct
typed outcomes. No `GameSaveItemSnapshot`, second Inventory graph, movement replay, wield/wear
replay, stack merge, or live item restore exists here.

## JSON contract

`GameSaveJsonCodec` is handwritten. Raw `Dictionary`/`Array[Variant]` values exist only while
encoding or decoding JSON. Decode constructs only known snapshot records and never calls
`str_to_var`, loads a script/resource path, reconstructs a Callable, or traverses arbitrary objects.
Every v1 structural object rejects unknown and missing fields; scalar types and tagged payload shapes
are exact. Stable-ID collections are sorted before encoding and duplicate authorities are rejected.

All arbitrary gameplay integers are canonical signed decimal JSON strings. Accepted grammar is
`0` or `-?[1-9][0-9]*`; `+1`, leading zeros, `-0`, whitespace, decimals, exponents, hexadecimal,
non-strings, and values outside signed int64 reject. Parsing is digit-by-digit and never passes
through float. Small bounded schema versions remain JSON numbers. Positions remain JSON numbers and
reject nonfinite or numeric-string values.

UTF-8 is validated byte-by-byte before JSON decode, including overlong sequences, surrogate ranges,
out-of-range code points, truncation, and invalid continuation bytes. Invalid UTF-8 and malformed
JSON are separate results.

`GameSaveResult` provides stable outcomes for success, no-save/read/UTF-8/size/JSON failures,
root/format/schema/field/integer/finite/duplicate/RNG failures, write/temp-validation/recovery/replace
failures, and operation reentry. Diagnostics contain a stable field/file path and concise detail,
not a stack trace or presentation message.

## RNG persistence seam

`RandomStreamSnapshot` stores the stable adapter ID
`godot-random-number-generator-pcg32-v1`, seed, and state as typed int64 values. The three concrete
Godot RNG adapters gained only `capture_random_state()` and `restore_random_state()` (plus the
previously missing symmetric WorldInteraction seed configurator). Gameplay interfaces remain
unchanged. Restore verifies the adapter ID, assigns seed first and state second, exposes no
`RandomNumberGenerator`, and performs no draw. Exact continuation tests independently cover all
three domains.

## Storage profiles and repository

Typed profiles resolve only to:

- development: `user://save-data/development/default-v1.json`;
- release: `user://save-data/release/default-v1.json`;
- tests: `user://save-data/tests/<validated-suite-run-id>/default-v1.json`.

The production API accepts no slot name or arbitrary filesystem path. Test child names permit only
ASCII letters, digits, hyphen, and underscore, and are revalidated as a single child beneath the
test root. Tests never touch development or release saves and remove only their exact child after
removing known fixed files.

`GameSaveRepository` uses synchronous `FileAccess`/`DirAccess`, a 16 MiB pre-decode read limit, and
a narrow synchronous operation gate. Its successful replace protocol is:

1. validate and encode the typed snapshot in memory;
2. write `default-v1.json.tmp` in the same directory and flush/close;
3. reopen, byte-bound, UTF-8 validate, decode, and structurally validate the temp;
4. remove only the fixed stale `.bak`;
5. rename an existing canonical file to `.bak`;
6. rename the verified temp to canonical;
7. retain the prior canonical as the one backup.

If the final rename fails after rotation, the repository attempts `.bak -> canonical` and always
returns failure, with an explicit rollback-failed bit when restoration also fails. It leaves
recovery files in place rather than deleting them blindly. Missing/invalid canonical plus a fully
decodable backup or temp returns `BACKUP_AVAILABLE`; it never auto-loads recovery data. Corrupt temp
validation occurs before any canonical rotation.

This is a bounded replace/backup protocol, not transactional-database or power-loss-proof atomicity;
Godot exposes no portable directory fsync guarantee.

## Godot 4.7.2 rename findings

The repository tests exercised `DirAccess.rename_absolute()` through the production adapter on the
current Windows Godot 4.7.2 editor:

- a normal same-directory rename succeeds and removes the source name;
- a missing source returns failure;
- when the destination file already exists, the destination is replaced and contains the source
  bytes;
- repository-injected canonical-rotation, final-replace, and rollback failures still return precise
  typed results and preserve the documented recovery files.

The protocol nevertheless removes the known stale backup before rotation and does not depend on
destination replacement behavior for its normal path.

## Verification and explicit non-goals

Tests cover int64 boundaries/invalid grammar, nontrivial typed round-trip, deterministic ordering,
strict/malicious shapes, finite coordinates, duplicate IDs, all three RNG continuations and
zero-draw seams, storage profiles, operation reentry, real and injected I/O, first/second save,
temp corruption, write/rename/rollback failure, bounded reads, invalid UTF-8, recovery evidence,
actual Godot rename behavior, and Phase 4B5A regression. All new tests are registered in
`tests/run_tests.gd` and have a focused `tests/run_phase_10b1_tests.gd` runner.

Live player validation is not applicable: this slice changes no Session, SceneTree, map, NPC,
corpse view, gameplay state, or UI behavior. Phase 10B2/10B3 will own live capture/composition and
Session restoration. Save eligibility, NEW_GAME/RESTORE bootstrap, stable-ID allocator integration,
candidate Session swap, physical placement validation, QA/UI triggers, process-restart proof,
autosave, mobile lifecycle, and cloud saves remain deferred.
