# Content data format

Items, NPCs, spawns, vendors and the world (rooms, regions, maps, zones, portals, services, doors)
are JSON under `game/data/`, listed in `game/data/content_manifest.json` (load order = manifest
order, then file order). Each file is one object with any of the arrays `items`, `npcs`, `spawns`,
`vendors`, `rooms`, `regions`, `maps`, `zones`, `portals`, `services`, `doors`, `landmarks`; exactly
one file (`common/pacing.json`) holds the `pacing` object.

`GameContent.catalog()` (`game/data/game_content.gd`) reads them once into a `ContentCatalog`.
Parsing lives in `game/core/content/`. Unknown fields, wrong types, non-integer numbers and broken
cross references are errors; a session refuses to start while `GameContent.load_errors()` is
non-empty.

Field names follow the LPC object so an importer can emit them directly. Facts the LPC derives by
rule are **not** authored; the loader applies the rule.

## items

| Field | LPC source | Notes |
|---|---|---|
| `id` | file path | `es2:<path without .c>`; stable, saved in save files |
| `legacy_sources` | file path(s) | first is canonical; identical copies (e.g. `npc/obj/`) are listed after it |
| `name`, `aliases` | `set_name(name, ids)` | |
| `long` | `set("long")` | optional; default is `name(Capitalized first alias)。\n` as in `feature/name.c` |
| `unit`, `material`, `value` | `set(...)` | `value` absent = 0 |
| `weight` | `set_weight()` | omitted for money |
| `weapon` | `init_sword(damage, flags)` etc. | `{skill, damage, flags: ["secondary", "two_handed"]}` |
| `armor` | `inherit CLOTH` + `armor_prop/*` | `{type, props}`; cloth over 3000 weight gets `dodge = -weight/3000` (`std/armor/cloth.c`) |
| `food` | `food_remaining`, `food_supply` | `{remaining, supply}`; not yet combinable with `weapon`, `armor` or `money` |
| `liquid` | `max_liquid` + `set("liquid", ...)` | `{max_liquid, type, name, remaining, drunk_apply}`; only `alcohol` and `water` are modelled; drinking gives +30 water (`feature/liquid.c`) |
| `money` | `money_id`, `base_value`, `base_unit`, `base_weight` | makes the item a stack and a currency; merge key is `/<first legacy source without .c>`; `coin`, `silver` and `gold` must all exist |

The corpse (`obj/corpse.c`) is created by the death rules and is not an item record.

## npcs

| Field | LPC source | Notes |
|---|---|---|
| `id` | — | native ID `<region>.npc.<name>`; saved in save files |
| `legacy_source` | file path | |
| `name`, `aliases`, `long` | `set_name`, `set("long")` | |
| `race` | `set("race")` | `human` (default) or `beast` |
| `gender`, `age` | `set(...)` | absent = not authored |
| `attributes` | `set("str")` … | keys `str cor int spi cps per con kar` |
| `resources` | `set("max_kee")` … | keys `gin kee sen` with `eff_` / `max_` variants |
| `combat_exp`, `score` | `set(...)` | |
| `attitude` | `set("attitude")` | `peaceful` (default) or `aggressive`; others are not modelled yet |
| `skills` | `set_skill(id, level)` | object, authored order kept |
| `carry` | `carry_object(path)->wield()/wear()`, `add_money(id, n)` | `{item, source, amount?, equip?: "wield"\|"wear"}`; `source` is the path the NPC file names |
| `limbs`, `verbs`, `apply` | `set("limbs")`, `set("verbs")`, `set_temp("apply/…")` | `apply` keys `attack damage armor dodge` |
| `capabilities` | — | native behaviour tags, e.g. `aggressive_on_player_presence` |

`chat_msg`, `inquiry` and functions (`call_for_help`, `ask_me`, …) are not data yet.

## spawns

`{id, npc, map, zone, points, legacy_room, legacy_quantity, presence_radius?}` — one entry per
`set("objects")` line of a room. `points` names the scene's spawn markers and must have
`legacy_quantity` entries. `presence_radius` (pixels, default 120) is how close the player must be
for an aggressive NPC to notice them — the native stand-in for "in the same room".
**Order matters**: NPCs are created in spawn order, which fixes their random draws and loadout item
IDs. Append new spawns; do not reorder existing ones without expecting a New Game.

## vendors

`{id, legacy_source, goods: [{key, item}]}` from `set("vendor_goods")`. The price is the item's
`value` (`feature/vendor.c`); goods worth less than 1 are not sold (`cmds/std/buy.c`).

## rooms

`{id, short, long, exits?}` — one ES2 room, copied verbatim from `set("short")`, the `@LONG` block
of `set("long")` (hard line breaks kept; the UI rewraps) and the static `set("exits")`. `id` is
`es2:<path without .c>`; exit targets use the same form and may name rooms that are not migrated.
`tools/tests/test_room_data.py` checks the text against `reference/es2/`.

## regions, maps

`regions`: `{id, name}`. `maps`: `{id, region, scene, entry}` — one Godot scene the player walks
in; `entry` is the spawn marker the player body waits on until the map is entered. Every map scene
uses `WorldMapController` (`map` export = the map ID) and carries one ID-bearing component per
record: `WorldPhysicalZoneArea2D` (zone), `WorldSpawnMarker2D`, `WorldPassageArea2D` (portal; a
portal that stays on its map moves the player directly), `WorldServicePoint` (service), `WorldDoor`
(door), `WorldLandmarkArea2D` (landmark). NPCs are not placed in the scene: the map gives each
spawn point a `WorldNpcBody2D` (`scenes/world/common/world_npc_body.tscn`). A map refuses to
initialize when scene and data disagree.

## zones

`{id, map, rooms}` — a walkable part of a map made of one or more rooms. The **first room is the
primary room**: its `short` is the zone's title and its `long` is what the player reads on entering.
A zone's combat location is its ID. Two zones are neighbours when a room of one has an exit into a
room of the other, or when one lists the other in `links` — a walkable connection no static ES2
exit states (random maze exits, a recorded geography decision); each link needs its DECISIONS entry.
Zone tracking follows the player body's center (half-open rectangles, one owner per point) and
only accepts moves between neighbours. Optional `combat_entry`:
`pair` (default — an aggressive NPC starts a fight with the player alone) or `complete_set` (every
aggressive NPC in contact joins one encounter; Lake, owner decision P2A-M).

## portals

`{id, from_zone, to_zone, to_spawn, legacy_room, legacy_command}` — a way from a zone to a spawn
marker in another zone, same map or not; the maps follow from the zones. `legacy_command` is the
ES2 command it stands for (`"east"`, `"climb pine"`). Cross-region portals live in their source
region's file.

## services

`{id, kind, zone, name, reach, vendor?, legacy_source}` — something the player uses standing within
`reach` pixels of its service point in `zone`. `kind` picks the rules (`WorldServiceKinds`): `bank`
(convert), `work`, `vendor` (needs `vendor`: a vendors[] ID), `hockshop` (value/sell), `teacher`
(apprentice/learn; the teaching facts are still `snow_school_teacher.gd`), `water` (ES2
`set("resource/water", 1)`: a wineskin can be filled here from the supplies panel). The context
button reads `name · verb`, e.g. 钱庄 · 兑换. `hockshop` and `teacher` also require an idle,
non-fighting player.

## doors

`{id, name, zones, reach, closable?, legacy_room}` — an ES2 `create_door()` between two zones of one
map; it starts closed and its state is not saved (a closed doorway is never a valid saved position).
`closable: false` marks the approved open-only pawn-shop door.

## landmarks

`{id, zone, name, long, action, portals, policy?, contact?, messages?, legacy_source}` — an ES2 room
item (`item_desc`) the player selects, looks at (`long`, verbatim) and uses with `action` (`climb`,
`hold`). Every portal must leave from `zone`. `contact: true` means the player must stand inside
the landmark's area in the scene, not just in the zone. `policy` picks the rule (default `portal`,
one portal); `vine` (epath2.c) rolls dodge between two portals `[waterfall, passage]` and prints
`messages` `hold`, `fall`, `fall_observer`, `climb`, `climb_observer`. The roll stays in code.

## pacing

`{combat_round_ms}` — milliseconds between two combat rounds on every map, the native ES2
heart_beat. 1000 reproduces the pre-B2 feel.

## Not data yet

Skills and teachers (`liuh_ken_definition.gd`, `snow_school_teacher.gd`) and the beast bite action
stay in GDScript until their packages. `*_world_definitions.gd` now only hold the IDs the runtime names in code.
