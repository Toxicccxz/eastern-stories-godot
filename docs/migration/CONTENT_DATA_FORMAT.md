# Content data format

How game content is loaded, how errors show, which files are generated and where to edit what. The
fields of each kind are defined by the reader of that kind (the table below: its `from_record()`
and the comments on the definition class); the loader rejects anything it does not know, so the
reader is the authority. The old per-field tables (written up to mid-October, never covering the
story, factions, winds or the native regions) are in git history up to `9246edb9`.

## Loading and errors

Content is JSON under `game/data/`, listed in `game/data/content_manifest.json` (load order =
manifest order, then file order). Each file is one object holding arrays of records (`items`,
`npcs`, `rooms`, `quests`, …) and, in exactly one file each, the single objects `pacing`
(`common/pacing.json`, required), `progression`, `bounty_board`, `opening`, `loading_screen` and
`title_screen`.

`GameContent.catalog()` (`game/data/game_content.gd`) reads them once into a `ContentCatalog`.
`ContentCatalogBuilder.add_document()` (`game/core/content/content_catalog_builder.gd`) hands each
array to its definition's `from_record()` through a `ContentRecordReader`, then `build()`
cross-checks the results (references between records, conditions, marks, items carried and worn,
story reachability helpers). Unknown fields, wrong types, non-integer numbers, duplicate IDs and
broken references are errors with the file and record in the message; a session refuses to start
while `GameContent.load_errors()` is non-empty, and the content suites fail on them.

Field names of ES2-derived records follow the LPC object, so the importer can emit them directly.
Facts the LPC derives by rule are **not** authored; the loader applies the rule.

| Key in a file | Read by |
|---|---|
| `items` | `ItemContentDefinition` |
| `npcs`, `spawns` | `NpcContentRecords` (`npc_from_record`, `spawn_from_record`) |
| `item_spawns`, `vendors` | `ItemSpawnDefinition`, `VendorDefinition` |
| `rooms`, `regions`, `maps`, `zones`, `portals` | `RoomDefinition`, `RegionDefinition`, `MapDefinition`, `ZoneDefinition`, `PortalDefinition` |
| `services`, `doors`, `landmarks`, `traps`, `hazards`, `winds`, `exit_rules` | `ServiceDefinition`, `DoorDefinition`, `WorldLandmarkDefinition`, `RoomTrapDefinition`, `RoomHazardDefinition`, `WindDefinition`, `ZoneExitRuleDefinition` |
| `skills`, `families` | `SkillDefinition`, `FamilyDefinition` |
| `race_actions`, `weapon_actions`, `combat_styles` | the combat action tables, `CombatStyle` |
| `quests`, `conditions`, `factions`, `epilogues` | `StoryQuestDefinition`, the named conditions (`JournalEntryDefinition.read_when`), `FactionDefinition`, `EpilogueDefinition` |
| `journal_chains`, `codex_topics`, `quest_tiers` | `JournalChainDefinition`, `CodexTopicDefinition`, `QuestTier` |
| `day_phases`, `sky_levels`, `stats_display`, `atlas` | `DayPhaseDefinition`, the sky list, `StatDisplayDefinition`, `AtlasCell` |
| `pacing`, `progression`, `bounty_board` | `PacingDefinition` (with `FeelDefinition`, `NpcIdleTuning`), `ProgressionRules`, `BountyRules` |
| `opening`, `loading_screen`, `title_screen` | `OpeningDefinition`, `LoadingScreenDefinition`, `TitleScreenDefinition` |

Outside the catalog, with their own readers: a person's look `game/data/<region>/appearances.json`
(the voxel person cards), `<region>/npc_life.json` (who idles, works or goes home at night),
`<region>/voxel/*.json` and the `common/` voxel tables (`room_life.json`, `item_looks.json`,
`voxel_prop_keys.json`, `graphics_quality.json`), and `game/data/new_game/names.json` (read by
`new_player_random_name.gd`). The beast actions stay in GDScript
(`game/data/combat/beast_combat_action_definitions.gd`); `game/data/<region>/<region>_world_definitions.gd`
(snow, oldpine, death) only hold IDs the runtime names in code.

## Generated and hand-authored files

**Generated — never edit by hand:** the `rooms`, `items`, `npcs`, `spawns`, `item_spawns` and
`vendors` files of the fifteen ES2 regions (`snow`, `oldpine`, `goathill`, `cloud`, `waterfog`,
`green`, `temple`, `latemoon`, `sanyen`, `choyin`, `canyon`, `village`, `city`, `chuenyu`, `death`)
and of `common/`, written by `python -m tools.migration.content_importer`. To change one of them,
edit the region's override file `tools/migration/overrides/<region>.json` and rerun the importer:

- `set` / `drop` (`{record id: …}`) change or remove a generated field — the place for hand-made
  changes to an ES2 record, including the native additions an ES2 NPC gets for the story (topics,
  moods, `present`/`until`);
- `vendors`, `items` (extra roots), `spawn_skip`, `vendor_skip`, `vendor_goods`;
- `review` (`{lpc source: {finding: decision}}`): every LPC fact that did not become data needs a
  decision here (the 「not data yet」 decisions are text the game does not show);
- `source_fixes` (`{lpc source: [{find, replace, why}]}`): a file ES2 could not compile, repaired
  before it is read; each `find` must occur exactly once, and each fix is a recorded deviation.

`--check` (and `tools/tests/test_content_import.py`) fails when a generated file differs from a fresh
run or a finding has no decision; `build/import/review.md` lists the findings. Records already in a
file keep their order (spawn order fixes NPC draws); new ones are appended. A room's `set("objects")`
may name a class daemon's NPC; its record lives in `common/npcs.json` as `common.npc.<class>.<file>`.

**Hand-authored:**

- Each ES2 region's `world.json` (regions, maps, zones, portals, doors, services, landmarks, exit
  rules), `appearances.json`, `npc_life.json` and `voxel/`.
- `common/`: `pacing`, `skills`, `combat_actions`, `combat_styles`, `families`, `progression`,
  `codex`, `day_phases`, `stats_display`, `journal`, `quests`, the screens and the voxel tables.
- `game/data/native/`: new content placed in ES2 regions (the 武馆's 木人, the bounty board, the
  story's people and things that stand in ES2 rooms); records carry `native` and say where they come
  from in `legacy_source` / `source` (`native: <plan or DECISIONS entry>`).
- The five native regions, every file of them: `niling` (逆灵宫), `guanbei` (关北), `fanfang`
  (番坊), `imperial` (皇城), `lancheng` (岚城); IDs are `native:<region>/<name>`.
- `game/data/story/`: the main story and faction quests (`prologue.json`, `chapter1.json` …
  `chapter10.json`, `finale.json`, `faction_*.json`), named conditions (`conditions.json`), the
  faction roll (`factions.json`) and the ending (`epilogue.json`).

Maps are drawn, not hand-edited: `tools/maps/layouts/<region>.json` is the map's source and
`python -m tools.maps.paint <region>` writes the scene (AGENTS.md「Maps and art」).
