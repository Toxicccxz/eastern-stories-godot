# Phase 4B5D: Legacy Autoload Import

## Scope and boundary

Phase 4B5D translates already-extracted ES2 autoload strings into a typed native schema-v1 snapshot candidate plus narrow import evidence. It performs no file I/O, LPC object loading, `call_other()`, inventory transfer, live aggregate mutation, player lookup, scheduling, or generic callback dispatch.

Legacy autoload is an import format, not the native save format. The importer does not replay the executable sequence `new(path) -> move(user) -> autoload(param)`. Supported records are placed directly under `CHARACTER(character_id)` in candidate data and are only materialized later if a caller explicitly invokes the Phase 4B5A trusted restore boundary.

## Authoritative sources inspected

- `reference/es2/mudlib/feature/autoload.c`
- `reference/es2/mudlib/feature/save.c`
- `reference/es2/mudlib/obj/user.c`
- `reference/es2/mudlib/cmds/usr/quit.c`
- `reference/es2/mudlib/std/money.c`
- `reference/es2/mudlib/std/item/combined.c`
- `reference/es2/mudlib/obj/money/coin.c`
- `reference/es2/mudlib/obj/money/gold.c`
- `reference/es2/mudlib/obj/money/silver.c`
- `reference/es2/mudlib/obj/money/thousand-cash.c`
- `reference/es2/mudlib/obj/bandage.c`
- `reference/es2/mudlib/feature/equip.c`
- `reference/es2/mudlib/std/equip.c`
- `reference/es2/mudlib/obj/marry_card.c`
- `reference/es2/mudlib/obj/token.c`
- `reference/es2/mudlib/obj/roommaker.c`
- `reference/es2/mudlib/doc/efuns/sscanf`
- `reference/es2/mudlib/adm/simul_efun/file.c`

A focused mudlib scan found active `query_autoload()` definitions only in `std/money.c`, `obj/bandage.c`, `obj/marry_card.c`, `obj/token.c`, and `obj/roommaker.c`. Matching active `autoload()` definitions exist for the first four, but not roommaker.

## Entry syntax and parsing

`LegacyAutoloadParser` preserves the exact input string and splits on the first colon only:

- `/obj/x` -> path `/obj/x`, `has_parameter=false`
- `/obj/x:` -> path `/obj/x`, `has_parameter=true`, parameter `""`
- `/obj/x:a:b:c` -> path `/obj/x`, parameter `a:b:c`

Path case, slash structure, extension, aliases, and later colons are not normalized. An empty path or a path not beginning with `/` produces a typed malformed-path result. There is no filesystem lookup.

This matches `feature/autoload.c`, whose `sscanf("%s:%s", file, param)` separates the first path segment from the remainder. Restore then calls `ob->autoload(param)` even when no colon existed and `param` is zero.

`base_name()` is the mudlib simul-efun in `adm/simul_efun/file.c`: it returns `file_name(ob)` after removing a numeric `#clone` suffix. Other active callers append `".c"` back to `base_name()`, proving that the runtime identity already omits the source extension; leading-slash comparisons such as `/obj/...` prove the deployed mudlib convention retains the leading slash. Consequently actual saved examples are `/obj/money/coin`, `/obj/bandage`, and `/obj/roommaker`, never repository paths, `.c` paths, clone names, or `/std/money` for a concrete coin clone.

## Explicit binding and instance identity

`LegacyAutoloadBindings` maps an exact concrete legacy program path to:

- a caller-owned native `ItemDefinitionId`;
- one closed decoder kind: `MONEY`, `BANDAGE`, `MARRY_CARD`, `TOKEN`, or `ROOMMAKER`;
- a source-derived initial own weight where that decoder needs it.

The core never derives a native definition ID from an LPC basename. Concrete money paths are `/obj/money/coin`, `/obj/money/gold`, `/obj/money/silver`, and `/obj/money/thousand-cash`; `/std/money` is not a valid concrete identity.

`LegacyAutoloadImportPlan` supplies exactly one reserved `ItemInstanceId` aligned to every legacy input index. The importer generates no UUIDs and uses no global allocator. Before decoding it rejects too few or too many IDs, empty IDs, and duplicates in the imported batch. Unsupported or invalid entries retain their reserved ID as diagnostic evidence; skipping one never shifts the ID assigned to a later supported entry.

## Ordering and batch result

Entries are decoded in original array order because legacy restore is sequential. Per-entry results retain the original index and string. `NativeItemStateSnapshot` then applies Phase 4B5A canonical ordering independently.

`LegacyAutoloadImportResult` is immutable typed data with one of:

- `COMPLETE`: every entry was supported and the candidate passed Phase 4B5A validation;
- `INCOMPLETE_UNSUPPORTED`: supported entries remain in the candidate, but at least one token, roommaker, unknown path, or noncanonical money parameter with unresolved driver parsing was encountered;
- `INVALID_INPUT`: the plan, an entry/parameter/definition, or the candidate validation was invalid.

Incomplete is never reported as faithful success. The caller may reject or inspect a partial candidate; the importer has no `skip_errors` policy and applies nothing to live state.

## Candidate snapshot shape

The candidate uses the unchanged `NativeItemStateSnapshot` schema version 1:

- supported materialized objects produce `NativeItemRecord` values directly parented by the character;
- money also produces a `NativeCombinedStackRecord` with the same instance ID;
- generic equipment records remain empty;
- armor records contain only the source-proven bandage slot;
- bandage/marry-card authored data and deferred intents remain outside the schema.

Every candidate is checked by the existing `NativeItemStateValidator` with caller-supplied `NativeItemDefinitionProjections`. No second containment, stack, or armor validator was introduced.

## Decoder semantics

### Money

`std/money.c::query_autoload()` serializes `query_amount() + ""`, so every source-produced parameter is the canonical unsigned decimal representation of a non-negative LPC integer. The decoder requires that canonical parameter, a mapped item definition, and a mapped `CombinedStackDefinition`.

The callback uses `sscanf(param, "%d", amount)`, but the bundled 1994 MudOS documentation does not fully define whitespace, optional-plus, leading-zero, or trailing-character acceptance. Those spellings cannot be emitted by `query_autoload()`. Phase 4B5D therefore does not invent driver behavior: a non-empty noncanonical string containing digits, such as `"12abc"`, `" 12"`, `"+12"`, or `"0012"`, returns typed `UNSUPPORTED_MONEY_PARAMETER_DRIVER_AMBIGUITY`, produces no item, and makes the batch incomplete. Missing/empty, nonnumeric, and negative source-impossible parameters are typed invalid input. Canonical `"12"` and `"0"` remain exact.

For positive amounts, the candidate amount is exact and own weight is `amount * base_weight`, matching `combined.c::set_amount()`. Source base weights are coin `1`, gold `37`, silver `37`, and thousand-cash `3`.

For parameter `"0"`, every concrete money clone has already executed `set_amount(1)` in `create()`. The subsequent legacy `set_amount(0)` schedules destruction after one second but does not assign zero or recalculate weight. The candidate therefore keeps amount `1` and one unit of base weight, while `LegacyStackDestructionIntent` records the requested zero and exact one-second delay outside schema v1. It creates no timer and does not mutate lifecycle state.

### Bandage

A saved bandage was equipped, because `query_autoload()` otherwise returned false. Its string parameter is the current legacy name. Import produces:

- one direct item record with source own weight `200`;
- `LegacyBandageStateImport` containing the exact saved name and forced `blood_soaked=3`;
- a native `bandage` armor-slot record when the mapped armor definition proves that exact slot.

The first bandage in legacy order establishes the slot. A later collision remains direct inventory and receives a typed unworn/collision result, preserving the fact that LPC ignored the inherited `wear()` result. No bandaged condition is applied. Because import does not replay `move(user)`, it may reconstruct direct placement and wear where legacy capacity rejection would have prevented both; this is an explicit trusted-import difference.

### Marry card

The exact serialized partner/display parameter is retained only in `LegacyMarryCardStateImport`; it is not promoted to universal native identity. The direct item is imported with source own weight `10`. The source's optional `find_player()` notification is represented by `LegacyMarryCardRuntimeIntent` and is not executed. Persistent authored data is therefore complete while its online presentation/runtime effect remains deferred.

### Token

`query_autoload()` serializes `guild_id`, but `autoload(name)` ignores `name` and calls `restore()` using the fresh clone's unset `guild_id`. Failure may delete the holder's family and destroy the token. Import does not repair this defect by using the parameter, mutate `FamilyState`, invoke guild persistence, or guess destruction. It preserves the parameter in diagnostics, materializes no token, and reports `UNSUPPORTED_TOKEN_EXECUTABLE_DEFECT`, making the batch incomplete.

### Roommaker

`query_autoload()` returns non-string `1`, so save writes only `/obj/roommaker`. `restore_autoload()` still calls missing `autoload(0)`. The mudlib and bundled driver documentation do not prove whether the deployed missing-lfun call is a silent no-op or runtime error. Import executes no wizard tooling, materializes no item, and reports `UNSUPPORTED_ROOMMAKER_DRIVER_AMBIGUITY`.

### Unknown paths

An unmapped exact path produces `UNKNOWN_LEGACY_PATH`. The importer neither loads the LPC path nor infers a native ID, preserves index/path/parameter evidence, materializes no item for it, and marks the batch incomplete.

## Relationship to Phase 4B5A

Phase 4B5D stops at validated data. It never calls `InventoryTransferService` or mutates `InventoryState`, `EquipmentState`, `ArmorState`, `CombinedStackCollection`, or `CharacterState`. A later application layer may explicitly pass a complete or deliberately accepted partial candidate to `NativeItemStateRestorer`, which reconstructs fresh aggregates through the already-closed all-or-nothing trusted boundary. Legacy login's partial live mutations, capacity failure, merge behavior, and callback-abort behavior are not replayed.

## Deliberately deferred

- old save-file parsing and all filesystem I/O;
- native serialization and `SaveManager`;
- complete character and guild-save migration;
- marry-card online lookup/notification;
- token family repair or destruction policy;
- roommaker/wizard runtime;
- bandage condition behavior;
- scheduler/timers and execution of zero-money destruction intent;
- corpse persistence, World, NPC, Combat, and schema v2.

`DECISIONS.md` was updated for the trusted pure-import boundary and the observable zero-money mapping.

## Formal audit corrections

The formal audit corrected the import-plan cardinality check from “at least one ID per entry” to exactly one reserved ID per input entry. It also replaced an undocumented blanket strict-parser assumption for noncanonical numeric money parameters with typed driver ambiguity, and added import -> restore -> capture verification proving canonical schema-v1 stability. No earlier closed production subsystem or schema DTO changed.
