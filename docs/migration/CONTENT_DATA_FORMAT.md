# Content data format

Items, NPCs, spawns, vendors and the world (rooms, regions, maps, zones, portals, services, doors)
are JSON under `game/data/`, listed in `game/data/content_manifest.json` (load order = manifest
order, then file order). Each file is one object with any of the arrays `items`, `npcs`, `spawns`,
`item_spawns`, `vendors`, `rooms`, `regions`, `maps`, `zones`, `portals`, `services`, `doors`,
`landmarks`, `skills`, `families`, `race_actions`, `weapon_actions`; exactly one file
(`common/pacing.json`) holds the `pacing` object.

`GameContent.catalog()` (`game/data/game_content.gd`) reads them once into a `ContentCatalog`.
Parsing lives in `game/core/content/`. Unknown fields, wrong types, non-integer numbers and broken
cross references are errors; a session refuses to start while `GameContent.load_errors()` is
non-empty.

Field names follow the LPC object so an importer can emit them directly. Facts the LPC derives by
rule are **not** authored; the loader applies the rule.

## Generated and hand-authored files

`rooms`, `items`, `npcs`, `spawns`, `item_spawns` and `vendors` files are **generated** by
`python -m tools.migration.content_importer` and never edited by hand; `world.json`,
`common/pacing.json` and the manifest are hand-authored. For each region with an override file
(`tools/migration/overrides/<region>.json`) the importer reads the rooms of the region's zones,
the NPCs and items their `set("objects")` place, what those NPCs carry and the goods of the named
vendors.
Records already in a file keep their order (spawn order fixes NPC draws); new ones are appended.

The override file holds every hand decision: `vendors` and `items` (extra roots), `spawn_skip`
(`{room: {object: why}}`), `vendor_skip` (`{vendor: {goods key: why}}`), `vendor_goods`
(`{vendor: {goods key: {item, price}}}`: goods a vendor sells through its own `buy_object()`
instead of `set("vendor_goods")`, read by hand), `set`/`drop`
(`{record id: …}`) and `review` (`{lpc source: {finding: decision}}`). A finding is an LPC fact
that did not become data — another function, a closure, a condition, a field the game does not
model yet. `--check` (and `tools/tests/test_content_import.py`) fails when a generated file
differs or a finding has no decision; `build/import/review.md` lists findings and per-NPC counts.
`common/skills.json`, `common/combat_actions.json` and `common/families.json` are hand-authored too.

A room's `set("objects")` may name a class daemon's NPC (`CLASS_D("swordsman") + "/master"`, from
`include/globals.h`); its record lives in `common/npcs.json` with the ID
`common.npc.<class>.<file>` (`common.npc.swordsman.master`).

## items

| Field | LPC source | Notes |
|---|---|---|
| `id` | file path | `es2:<path without .c>`; stable, saved in save files |
| `legacy_sources` | file path(s) | first is canonical; identical copies (e.g. `npc/obj/`) are listed after it |
| `name`, `aliases` | `set_name(name, ids)` | |
| `long` | `set("long")` | optional; default is `name(Capitalized first alias)。\n` as in `feature/name.c` |
| `unit`, `material`, `value` | `set(...)` | `value` absent = 0 |
| `no_get` | `set("no_get", 1)` | `true`: get.c refuses it (这个东西拿不起来。) |
| `female_only` | `set("female_only", 1)` | `true`: wear.c lets only a 女性 character wear it |
| `max_encumbrance` | `set_max_encumbrance(n)` | a container: put.c puts things in while their weight fits, get.c takes them out (功德箱 10000) |
| `weight` | `set_weight()` | omitted for money; 0 when the LPC never sets it (`feature/move.c`) |
| `weapon` | `init_sword(damage, flags)` etc. | `{skill, damage, flags: ["secondary", "two_handed"], apply?}`; `apply` is `weapon_prop/*` other than damage (attack, defense, dodge, courage, intelligence, karma, personality, spells, spirituality), added to the wielder's `apply/*` (equip.c) |
| `armor` | `inherit CLOTH` + `armor_prop/*`, or `inherit EQUIP` + `set("armor_type")` | `{type, props}`; cloth over 3000 weight gets `dodge = -weight/3000` (`std/armor/cloth.c`) |
| `food` | `food_remaining`, `food_supply` | `{remaining, supply}`; not yet combinable with `weapon`, `armor` or `money` |
| `liquid` | `max_liquid` + `set("liquid", ...)` | `{max_liquid, type, name, remaining, drunk_apply}`; only `alcohol` and `water` are modelled; drinking gives +30 water (`feature/liquid.c`) |
| `study` | `set("skill", ([...]))` | `{skill, exp_required, sen_cost, difficulty, max_skill}`: study.c teaches the skill from it (the LPC `name` key is `skill`) |
| `money` | `money_id`, `base_value`, `base_unit`, `base_weight` | makes the item a stack and a currency; merge key is `/<first legacy source without .c>`; `coin`, `silver` and `gold` must all exist |

The corpse (`obj/corpse.c`) is created by the death rules and is not an item record.

## npcs

| Field | LPC source | Notes |
|---|---|---|
| `id` | — | native ID `<region>.npc.<name>`; saved in save files |
| `legacy_source` | file path | |
| `name`, `aliases`, `long` | `set_name`, `set("long")` | |
| `title` | `set("title")` | shown before the name, as `short()` does |
| `nickname` | `set("nickname")` | e.g. 风雨双侠 |
| `rank_info` | `set("rank_info/respect")` | `{respect}`: how others address it (rankd.c), e.g. 小二哥 |
| `race` | `set("race")` | `human` (default) or `beast` (`野兽`) |
| `gender`, `age` | `set(...)` | absent = not authored |
| `attributes` | `set("str")` … | keys `str cor int spi cps per con kar` |
| `resources` | `set("max_kee")` … | keys `gin kee sen` with `eff_` / `max_` variants; `force atman mana` with `max_` (race/human.c adds a quarter of `max_atman`/`max_force`/`max_mana` to `max_gin`/`max_kee`/`max_sen`) |
| `force_factor` | `set("force_factor")` | 加力: adds to strength (query_str) and drives the force hit of a mapped force skill |
| `combat_exp`, `score` | `set(...)` | |
| `attitude` | `set("attitude")` | `peaceful` (default), `friendly`, `heroism` or `aggressive`; decides spars (`npc.c accept_fight`) and aggression |
| `skills` | `set_skill(id, level)` | object, authored order kept |
| `skill_map` | `map_skill(use, skill)` | `{use: skill}`; the skill must be in `skills` |
| `carry` | `carry_object(path)->wield()/wear()`, `add_money(id, n)` | `{item, source, amount?, equip?: "wield"\|"wear"}`; `source` is the path the NPC file names |
| `limbs`, `verbs`, `apply` | `set("limbs")`, `set("verbs")`, `set_temp("apply/…")` | `apply` keys `attack damage armor dodge defense parry`, for any race |
| `capabilities` | — | native behaviour tags, e.g. `aggressive_on_player_presence` |
| `accept_fight` | the NPC's own `accept_fight()` | ordered rules `{family?, gender?, emote?, say?, accept, kill?}`; the first matching rule decides; `kill` (with `accept`): the NPC answers with `kill_ob()` (annihir.c) and fights to kill, the challenger only fights back; `say` may use `$RESPECT`/`$SELF` (rankd.c). Hand-written in the override file's `set` |
| `inquiry` | `set("inquiry")` | `{topic: [line, ...]}` in authored order; ask.c says each line as `<name>说道：<line>`. Strings of an answer array only (ask.c skips 0 and functions); a topic answered by a function is a finding `inquiry <topic>`. A topic may instead be `{eff_kee_percent: [{at_least, say}]}` (herbalist.c heal_me(), judged on the asker; none matching leaves ask.c's own answer) |
| `chat_chance`, `chat_msg` | `set("chat_chance")`, `set("chat_msg")` | npc.c chat(): `chat_msg` entries are lines (said as written), `{"action": "random_move"}` or `{"action": "drink", sated_water, dry_say, dry_clears?}` (drunk.c do_drink()). Generated only when every entry is a line or random_move; otherwise both stay findings |
| `greeting` | the NPC's init()/greeting() | `{say}` (said as `<name>说道：<say>`) or `{one_of: [{say} \| {emote}]}`, one drawn when it is said (waiter.c `random(3)`; an `emote` follows the name), one second after the player arrives (`$RESPECT` the player). Hand-written in the override file's `set` |
| `vendor` | the override's `vendors` | a vendors[] ID: the NPC sells these goods from its body (buy.c finds it with `present()`) |
| `accept_object` | the NPC's own `accept_object()` | ordered rules, first match decides; conditions `value_at_least`, `value_at_most`, `liquid` (`alcohol`/`water`), `liquid_remaining_at_most`, `npc_flag`, `giver_mark`; outcome `say`/`emote`, `accept`, `mark_giver` (marks/<name>), `set_npc_flag`, `effect` (`temple_donation`: keeper.c). No rule matching, or no rules, refuses (give.c). Hand-written in `set` |
| `flags` | object variables `create()` sets | e.g. `["has_alcohol"]` (drunk.c); rules test and set them; not saved |
| `fight_deferred` | — | why the NPC cannot be fought yet (its mapped skills have no ported actions); no 攻击/切磋 |
| `family` | `create_family(name, generation, title)` | `{name, generation, title}`; the name must be in `families.json`; privileges -1 |
| `f_master` | `inherit F_MASTER` | `true`: std/char/master.c prevent_learn() limits what it teaches |
| `recognize_apprentice` | the NPC's own `recognize_apprentice()` | ordered rules `{family?, giver_mark?, say?, emote?, fail?, accept}`; `fail` replaces learn.c's polite refusal. Hand-written in `set` |
| `apprentice` | the master's `attempt_apprentice()`/`recruit_apprentice()` | `{requires: {cor?, cps?}, refuse_say, accept_say, class}` (effective attributes); needs `family`. Hand-written in `set` |

`age`, `combat_exp` and `score` may be a rule `create()` draws: `{"base": 600, "plus_random": 400}`
is `600+random(400)`, `"minus_random"` subtracts. `gender` may be
`{"random": 10, "below": 7, "then": "男性", "else": "女性"}`. Draws happen at creation, before the
race's own draws; a save keeps the drawn values.

An NPC teaches every skill it has that `skills.json` defines when its `family` or
`recognize_apprentice` can admit a student (`NpcTeacher`); the map gives such an NPC, and a
`vendor`, a service on its body (`NpcService`). Combat talk (`chat_msg_combat`) and functions
(`call_for_help`, `ask_me`, …) are not data yet.

## spawns

`{id, npc, map, zone, points, legacy_room, legacy_quantity, presence_radius?}` — one entry per
`set("objects")` line of a room. `points` names the scene's spawn markers and must have
`legacy_quantity` entries. `zone` is the NPC's home: it wanders only there and in the zones next
to it, and `legacy_room`'s reset brings it home or makes a new one when it died. `presence_radius` (pixels, default 120) is how close the player must be
for an aggressive NPC to notice them — the native stand-in for "in the same room".
**Order matters**: NPCs are created in spawn order, which fixes their random draws and loadout item
IDs. Append new spawns; do not reorder existing ones without expecting a New Game.

## item_spawns

`{id, item, map, zone, points, legacy_room, legacy_quantity}` — an item a room's `set("objects")`
places (room.c `make_inventory()`): one item lies on each of `points` when the world is created.
The item instance ID follows from the point, so a save records only that the item is still in that
zone's WORLD (Continue puts it back on its marker). `legacy_room`'s reset lays it there again once
that item no longer exists. Combined items cannot be authored on a floor; dropped ones lie there
(drop.c), and a save keeps every dropped item's zone and position (`floor_items`).

## vendors

`{id, legacy_source, goods: [{key, item, price?}]}` from `set("vendor_goods")`, or from the
override's `vendor_goods`. The price is the item's `value` (`feature/vendor.c`) unless the goods
carry `price`, what the vendor's own `buy_object()` asks (`d/snow/npc/smith.c`: 300 for a hammer
worth 3). A price below 1 is not sold (`cmds/std/buy.c`); an authored `price` below 1 is an error.

## rooms

`{id, short, long, exits?, no_fight?}` — one ES2 room, copied verbatim from `set("short")`, the
`@LONG` block of `set("long")` (hard line breaks kept; the UI rewraps) and the static
`set("exits")`. `no_fight: true` (`set("no_fight")`) refuses attacks from or into every zone
holding the room ("这里不准战斗。", kill.c) and stops NPC aggression there (combatd.c). `id` is
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

Terrain is not data: each scene paints it on `TileMapLayer`s with the shared placeholder TileSet
([TERRAIN_TILES](TERRAIN_TILES.md)); on Old Pine the tiles are also the collision. Tiles carry no IDs.

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

`{id, kind, zone, name, reach, legacy_source}` — a room's own command, used standing within
`reach` pixels of its service point in `zone`. `kind` picks the rules (`WorldServiceKinds`): `bank`
(convert), `work`, `hockshop` (value/sell), `water` (ES2 `set("resource/water", 1)`: a wineskin
can be filled here from the supplies panel). The context button reads `name · verb`, e.g. 钱庄 ·
兑换; `hockshop` also requires an idle, non-fighting player. Goods and teaching belong to NPCs
(`vendor`, teaching fields): the map binds them to the NPC's body, reached within 96 pixels of it
(店小二 · 购买, 柳淳风 · 请教).

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
`hidden_passage` (weapon_storage.c) moves nobody: each use is one push (`messages.push`); the
`pushes`-th opens its portals `[down, up]` for `open_seconds` of world time (`open`, `close`).
`up` leads from where `down` arrives back to `zone`; both stay shut (their scene passages off)
until the landmark opens them, and no other landmark may use them.

## pacing

`{combat_round_ms, room_reset_seconds?}` — milliseconds between two combat rounds on every map,
the native ES2 heart_beat (1000 reproduces the pre-B2 feel), and MudOS's `time to reset`: a room
resets half to all of this many seconds of world time after its last reset (default 1800,
config.ES2; lower it locally to playtest resets).

## skills, families

`skills`: `{id, name, kind: basic|specialized, type: martial|knowledge, enable?: [use], legacy_source,
actions?, dodge_messages?, parry_messages?, standard_force_hit?, hit_ob?, practice?, valid_learn?,
improved_line?, improved_color?}` — a skill the game models (learn,
enable, the character panel's name; to_chinese()'s dictionary is not in the mudlib, so `name` is
authored). A specialized skill names the uses it can be enabled for. `actions` is the skill's
`action` table (query_action): `{id, action, damage_type, damage?, force?, weapon?}`, the ID being
`es2:<legacy_source without .c>/<id>`; combatd.c reads no other key, so `dodge`/`parry` stay in the
LPC. `hit_ob: true` marks a skill with its own `hit_ob()` (iceforce, spicyclaw, ts-fist): not
ported, so a fight that would call it stops. `dodge_messages` (query_dodge_msg) and `parry_messages` `{armed, unarmed}`
(parry.c, which combatd.c always asks) are its lines. `standard_force_hit`: it inherits
std/force.c and keeps its `hit_ob()`. `practice` is its `practice_skill()` (practice.c):
`{kee?, force?, done?, fail?, refuses?}` — kee and force each at least the amount, then both
spent; `done` what it writes, `fail` its notify_fail(); `refuses: true` never lets it happen
(fonxanforce). No `practice`: the daemon has none and practice never progresses.
`valid_learn` maps the rule that refused (`max_force`, `mapped`, `weapon`, `empty_hands`) to
valid_learn()'s notify_fail(), which learn.c, practice.c and study.c then print. `improved_line`
and `improved_color` (HIR/HIY/HIC/HIW): `skill_improved()`'s line when its effect applies.
`families`: `{id, name}` — a family by its ES2
`family_name`; characters keep the ID.

## race_actions, weapon_actions

`common/combat_actions.json`. `race_actions`: `{race, legacy_source, actions}` — a race's own
moves (race/human.c `combat_action`, its default_actions). `weapon_actions`: one record
`{legacy_source: weapond.c, actions, verbs}` — weapond.c's verbs as actions (ID = verb) and
`verbs: [{skill, verbs, legacy_source}]`, the verbs each weapon kind sets (std/weapon/<kind>.c).
A wielded weapon without a mapped skill draws one of its kind's verbs. An action's
`post_action` names a ported weapond.c function (`throw_weapon`: the thrown weapon loses one
of its amount). Hammers and staffs have no verbs yet: bash, crush and slam run bash_weapon,
which is not ported, so they attack with `slash`.

## Not data yet

The beast actions stay in GDScript (`beast_combat_action_definitions.gd`).
`*_world_definitions.gd` now only hold the IDs the runtime names in code.
