# Content data format

Items, NPCs, spawns, vendors and the world (rooms, regions, maps, zones, portals) are JSON under
`game/data/`, listed in `game/data/content_manifest.json` (load order = manifest order, then file
order). Each file is one object with any of the arrays `items`, `npcs`, `spawns`, `vendors`,
`rooms`, `regions`, `maps`, `zones`, `portals`.

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

`{id, npc, map, zone, points, legacy_room, legacy_quantity}` — one entry per `set("objects")` line
of a room. `points` names the scene's spawn markers and must have `legacy_quantity` entries.
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

`regions`: `{id, name}`. `maps`: `{id, region, scene}` — one Godot scene the player walks in.

## zones

`{id, map, rooms}` — a walkable part of a map made of one or more rooms. The **first room is the
primary room**: its `short` is the zone's title and its `long` is what the player reads on entering.
A zone's combat location is its ID. Two zones are neighbours when a room of one has an exit into a
room of the other; Snow's zone tracking only accepts moves between neighbours.

## portals

`{id, from_zone, to_zone, to_spawn, legacy_room, legacy_command}` — a way from a zone to a spawn
marker in another zone, same map or not; the maps follow from the zones. `legacy_command` is the
ES2 command it stands for (`"east"`, `"climb pine"`). Cross-region portals live in their source
region's file.

## Not data yet

Landmarks and the Vine (`oldpine_landmark_definitions.gd`), skills and teachers
(`liuh_ken_definition.gd`, `snow_school_teacher.gd`), and the beast bite action stay in GDScript
until their packages. `*_world_definitions.gd` now only hold the IDs the runtime names in code.
