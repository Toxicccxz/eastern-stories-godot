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
(`{record id: …}`), `review` (`{lpc source: {finding: decision}}`) and `source_fixes`
(`{lpc source: [{find, replace, why}]}`: a file ES2 could not compile, repaired before it is
read; each `find` must occur exactly once, and each fix is a recorded deviation). A finding is an LPC fact
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
| `female_only`, `wear_refusal` | `set("female_only", 1)`; an own wear() (d/latemoon/obj/skirt.c) | `true`: wear.c lets only a 女性 character wear it; `wear_refusal` is the item's own wear() line instead of wear.c's |
| `no_drop` | `set("no_drop", 1 \| "line")` | `true` or drop.c's own line: drop.c, give.c and put.c refuse it |
| `max_encumbrance` | `set_max_encumbrance(n)` | a container: put.c puts things in while their weight fits, get.c takes them out (功德箱 10000) |
| `weight` | `set_weight()` | omitted for money; 0 when the LPC never sets it (`feature/move.c`) |
| `weapon` | `init_sword(damage, flags)` etc. | `{skill, damage, flags: ["secondary", "two_handed"], apply?, weight_dodge?}`; `apply` is `weapon_prop/*` other than damage (attack, defense, dodge, courage, intelligence, karma, personality, spells, spirituality), added to the wielder's `apply/*` (equip.c); `weight_dodge: "equip"` when create() calls std/equip.c's setup() (std/weapon/<kind>.c, not throwing.c): from 3000 weight a weapon without its own dodge gets `dodge = -weight/3000`; `rigidity` (`set("rigidity")`) is added to the weapon's side in weapond.c bash_weapon() |
| `armor` | `inherit CLOTH` + `armor_prop/*`, or `inherit EQUIP` + `set("armor_type")` | `{type, props, weight_dodge?}`; the setup() create() calls: `"armor"` (the eleven `std/armor/<type>.c`): over 3000 weight `dodge = -weight/3000`, replacing the armor's own; `"equip"` (`std/equip.c`): from 3000 weight, only without its own dodge; absent: no setup() call, no cost |
| `food` | `food_remaining`, `food_supply` | `{remaining, supply}`; not yet combinable with `weapon`, `armor` or `money` |
| `hang` | rope.c `add_action("hang_self", "hang")` | `true`: the 上吊 button (asked first): refused in an `outdoors` room, else die() |
| `scribe` | cmds/std/scribe.c's paper (obj/paper_seal.c) | `true`: 符 are drawn on it (owner: only on it). The catalog makes a 僵尸追魂符 of it for every NPC that is not raised (`<id>#haunt=<npc id>`, haunt.c), stacking only with sheets for the same name. Hand-written in `set` |
| `liquid` | `max_liquid` + `set("liquid", ...)` | `{max_liquid, type, name, remaining, drunk_apply}`; only `alcohol` and `water` are modelled; drinking gives +30 water (`feature/liquid.c`) |
| `study` | `set("skill", ([...]))` | `{skill, exp_required, sen_cost, difficulty, max_skill}`: study.c teaches the skill from it (the LPC `name` key is `skill`) |
| `money` | `money_id`, `base_value`, `base_unit`, `base_weight` | makes the item a stack and a currency; merge key is `/<first legacy source without .c>`; `coin`, `silver` and `gold` must all exist |

The corpse (`obj/corpse.c`) is created by the death rules and is not an item record.

## npcs

| Field | LPC source | Notes |
|---|---|---|
| `id` | — | native ID `<region>.npc.<name>`, `<region>.npc.<subdirectory>.<name>` for a file under a region's subdirectory (d/latemoon/room/npc/servant.c: `latemoon.npc.room.servant`); saved in save files |
| `legacy_source` | file path | |
| `name`, `aliases`, `long` | `set_name`, `set("long")` | |
| `title` | `set("title")` | shown before the name, as `short()` does |
| `nickname` | `set("nickname")` | e.g. 风雨双侠 |
| `rank_info` | `set("rank_info/respect")` | `{respect}`: how others address it (rankd.c), e.g. 小二哥 |
| `class` | `set("class")` | e.g. `taoist`: rankd.c's words for it (query_self() 贫道, query_respect()) |
| `race` | `set("race")` | `human` (default) or `beast` (`野兽`) |
| `gender`, `age` | `set(...)` | absent = not authored |
| `attributes` | `set("str")` … | keys `str cor int spi cps per con kar` |
| `resources` | `set("max_kee")` … | keys `gin kee sen` with `eff_` / `max_` variants; `force atman mana` with `max_` (race/human.c adds a quarter of `max_atman`/`max_force`/`max_mana` to `max_gin`/`max_kee`/`max_sen`) |
| `force_factor` | `set("force_factor")` | 加力: adds to strength (query_str) and drives the force hit of a mapped force skill |
| `combat_exp`, `score` | `set(...)` | |
| `attitude` | `set("attitude")` | `peaceful` (default), `friendly`, `heroism` or `aggressive`; decides spars (`npc.c accept_fight`) and aggression. A function (kid2.c) is `{"random", "below", "then", "else"}`, drawn from the world-interaction stream each time a spar asks |
| `skills` | `set_skill(id, level)` | object, authored order kept |
| `skill_map` | `map_skill(use, skill)` | `{use: skill}`; the skill must be in `skills` |
| `carry` | `carry_object(path)->wield()/wear()`, `add_money(id, n)` | `{item, source, amount?, equip?: "wield"\|"wear"}`; `source` is the path the NPC file names. A stack's `amount` may be a rule (`{"base", "plus_random"}`); an entry may be `{"random": n, "below": k, "then": entry, "else": entry}` (worker2.c). These draw after setup(), in entry order |
| `limbs`, `verbs`, `apply` | `set("limbs")`, `set("verbs")`, `set_temp("apply/…")` | `apply` keys `attack damage armor dodge defense parry`, for any race; a value may be a rule create() draws (`{"base", "plus_random"}`, after combat_exp), kept per NPC in CharacterState `applies` and saved |
| `capabilities` | — | native behaviour tags, e.g. `aggressive_on_player_presence` |
| `accept_fight` | the NPC's own `accept_fight()` | ordered rules `{family?, gender?, emote?, say?, accept, kill?}`; the first matching rule decides; `kill` (with `accept`): the NPC answers with `kill_ob()` (annihir.c) and fights to kill, the challenger only fights back; `say` may use `$RESPECT`/`$SELF` (rankd.c). Hand-written in the override file's `set` |
| `inquiry` | `set("inquiry")` | `{topic: [line, ...]}` in authored order; ask.c says each line as `<name>说道：<line>`. Strings of an answer array only (ask.c skips 0 and functions); a topic answered by a function is a finding `inquiry <topic>`. A topic may instead be `{eff_kee_percent: [{at_least, say}]}` (herbalist.c heal_me(), judged on the asker; none matching leaves ask.c's own answer) |
| `chat_chance`, `chat_msg` | `set("chat_chance")`, `set("chat_msg")` | npc.c chat(): `chat_msg` entries are lines (said as written), `{"action": "random_move"}`, `{"action": "drink", sated_water, dry_say, dry_clears?}` (drunk.c do_drink()) or `{"action": "emote", "verb"}` (an emote: prints nothing). Generated only when every entry is a line or random_move; otherwise both stay findings. `chat_msg_combat` also takes `{"action": "wield", "item", "say"?, "chat_chance_combat"?}`, `{"action": "call_partner", "partner", "emote"\|"say"\|"line"}` (ask_for_help()), `{"action": "say_by_age", "younger", "otherwise"}` and `{"action": "poison", "condition", "duration", "tell"}` (daemon/class/dancer/master.c use_poison(): a random enemy without the condition is told, and random(the NPC's combat_exp) over its own sets it) |
| `greeting` | the NPC's init()/greeting() | `{say}` (said as `<name>说道：<say>`), `{one_of: [{say} \| {emote} \| {line} \| act]}`, one drawn when it is said (waiter.c `random(3)`; an `emote` follows the name), or `{rules: [act]}`, the first act for the player; one second after the player arrives (`$RESPECT` the player). An act is `{gender?, not_gender?, not_class?, ask?, choice?, steps}` (ScriptedAct): each step one of a line (`say`, `emote`, `line`, `whisper`, with an optional `color`), `damage` `{gin, kee, sen}`, `heal` (`gin`/`kee`/`sen`, `base`, `random`), `condition` with `duration`, `calm` (bellicosity above 0 less random(kar) + n), `npc_force`, `close_door` (the door the player came by), `move` (a zone) with `point`, `kill`, `give` (an item) with `unless_temp` and `lines`. Hand-written in the override file's `set` |
| `vendor` | the override's `vendors` | a vendors[] ID: the NPC sells these goods from its body (buy.c finds it with `present()`) |
| `accept_object` | the NPC's own `accept_object()` | ordered rules, first match decides; conditions `value_at_least`, `value_at_most`, `liquid` (`alcohol`/`water`), `liquid_remaining_at_most`, `npc_flag`, `giver_mark`; outcome `say`/`emote`, `accept`, `mark_giver` (marks/<name>), `set_npc_flag`, `effect` (`temple_donation`: keeper.c). No rule matching, or no rules, refuses (give.c). Hand-written in `set` |
| `flags` | object variables `create()` sets | e.g. `["has_alcohol"]` (drunk.c); rules test and set them; not saved |
| `fight_deferred` | — | why the NPC cannot be fought yet (its mapped skills have no ported actions); no 攻击/切磋 |
| `family` | `create_family(name, generation, title)` | `{name, generation, title}`; the name must be in `families.json`; privileges -1; generation 0 is a founder's (瑷伦) |
| `f_master` | `inherit F_MASTER` | `true`: std/char/master.c prevent_learn() limits what it teaches |
| `recognize_apprentice` | the NPC's own `recognize_apprentice()` | ordered rules `{family?, giver_mark?, say?, emote?, fail?, accept}`; `fail` replaces learn.c's polite refusal. Hand-written in `set` |
| `apprentice` | the master's `attempt_apprentice()`/`recruit_apprentice()` | `{requires: {cor?, cps?}, refuse_say, accept_say, class}` (effective attributes); needs `family`. Hand-written in `set` |
| `conjured` | mind_bug.c's `create()` reading `this_player()` and `die()` | `{skill, combat_exp_per_level, spi_divisor, killed_by_owner: [line], killed_by_other: [line]}`: an NPC a skill's practice conjures (never placed by a room, carries nothing). Hand-written in `set` |
| `raised` | corpse.c `animate()` and zombie.c `heal_up()`, `dispell()` | `{name, drain: {above, atman, gin}, tell, color?, dissolve}`: an NPC a spell raises from a corpse, named `name` with `{name}` the victim's; each heal_up() it `tell`s its master and takes `atman` and `gin` while they have more than `above` atman, else it `dissolve`s a second later ($N its name). Never placed by a room, not saved. Hand-written in `set` |

`age`, `combat_exp` and `score` may be a rule `create()` draws: `{"base": 600, "plus_random": 400}`
is `600+random(400)`, `"minus_random"` subtracts. `gender` may be
`{"random": 10, "below": 7, "then": "男性", "else": "女性"}`. Draws happen at creation, before the
race's own draws; a save keeps the drawn values.

An NPC teaches every skill it has that `skills.json` defines when its `family` or
`recognize_apprentice` can admit a student (`NpcTeacher`); the map gives such an NPC, and a
`vendor`, a service on its body (`NpcService`). Combat talk (`chat_msg_combat`) and functions
(`call_for_help`, `ask_me`, …) are not data yet.

## spawns

`{id, npc, map, zone, points, legacy_room, legacy_quantity, presence_radius?, summoned?, draw?}` — one entry per
`set("objects")` line of a room; world.json may author more (a `summoned` spawn: keep2.c's guards,
house3.c's spiders), whose NPCs wait absent until a room rule calls them in. Spawns sharing a
`draw` group (road2.c's guards on duty) are absent too: when the world is made and at each reset
of their room one of the group is drawn and comes; the others stay as they are. The override's
`npcs` lists NPC files no room places that such a spawn needs. `points` names the scene's spawn markers and must have
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
that item no longer exists. A combined item lies as a stack of its `amount` (combined.c's
set_amount(): one 桃符纸 a point); one merged into another stack is gone, so a reset lays it again.
Dropped items lie there too (drop.c), and a save keeps every dropped item's zone and position
(`floor_items`).

## vendors

`{id, legacy_source, goods: [{key, item, price?}]}` from `set("vendor_goods")`, or from the
override's `vendor_goods`. The price is the item's `value` (`feature/vendor.c`) unless the goods
carry `price`, what the vendor's own `buy_object()` asks (`d/snow/npc/smith.c`: 300 for a hammer
worth 3). A price below 1 is not sold (`cmds/std/buy.c`); an authored `price` below 1 is an error.

## rooms

`{id, short, long, exits?, no_fight?, outdoors?}` — one ES2 room, copied verbatim from `set("short")`, the
`@LONG` block of `set("long")` (hard line breaks kept; the UI rewraps) and the static
`set("exits")`. `no_fight: true` (`set("no_fight")`) refuses attacks from or into every zone
holding the room ("这里不准战斗。", kill.c) and stops NPC aggression there (combatd.c).
`outdoors: true` is `set("outdoors")` with any area name (rope.c finds nowhere to hang a rope). `id` is
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

`{id, from_zone, to_zone, to_spawn, legacy_room, legacy_command, set_mark?}` — a way from a zone to a spawn
marker in another zone (or back into the same one: the 迷阵), same map or not; the maps follow from
the zones. `set_mark` names a mark (CharacterState `marks`) the room's valid_leave() gives whoever
takes it (eight7.c's 八卦阵). `legacy_command` is the
ES2 command it stands for (`"east"`, `"climb pine"`). Cross-region portals live in their source
region's file.

## services

`{id, kind, zone, name, reach, legacy_source}` — a room's own command, used standing within
`reach` pixels of its service point in `zone`. `kind` picks the rules (`WorldServiceKinds`): `bank`
(convert), `work`, `hockshop` (value/sell), `water` (ES2 `set("resource/water", 1)`: a wineskin
can be filled here from the supplies panel), `dance` (d/latemoon/latemoon8.c and miroom.c
do_dancing(), with its `dance`: `{costs: [{gender, at_least, sen}], tired, clumsy, steps:
[{name, mark, sen?, always?, portal, line}]}`: the gender's sen check and cost, then a step the
player knows (its mark, or `always`: the room's only way out) plays its line, spends its sen and moves them through its portal, which leaves
the service's zone; the player's own dance is `clumsy`), `act` (bathroom.c take bath, uproom3.c ponder,
with its `act`: `{verb, acts: [act]}` as a greeting's acts: the first for the player runs; one with
`ask` is asked first, and so is one whose `damage` would knock the player out). The context button reads `name · verb`, e.g. 钱庄 ·
兑换; `hockshop` also requires an idle, non-fighting player. Goods and teaching belong to NPCs
(`vendor`, teaching fields): the map binds them to the NPC's body, reached within 96 pixels of it
(店小二 · 购买, 柳淳风 · 请教).

## doors

`{id, name, zones, reach, closable?, open?, legacy_room}` — an ES2 `create_door()` between two zones of one
map; it starts closed (`open: true`: create_door() without DOOR_CLOSED) and its state is not saved
(a closed doorway is never a valid saved position).
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
`push_stone` (closed.c): below the record's `force`, `max_force` or `force_factor` the push is
`weak`; else it costs `gin`, `kee` and `sen` (`push`) and random(`random`) 0 rolls the stone away
(`rolled`) through its one portal. `search` (water.c): with the record's `mark`, random(`random`)
other than 0 gives the `reward` item (`found`, the mark stays), else the mark goes (`search`,
`nothing`). A `look` landmark may `teach` marks (`teaches`: d/latemoon/latebook.c's picture names two
dances). `look_spawn` (house3.c) has no action: looking calls one NPC of its summoned `spawn`
in (`spawn`) while fewer than `limit` came since its room's reset and a point is free; else the
look reads `long`. `take` (moonc.c do_pick(), latemoon2.c do_take()) gives the `reward` item
(`take`) while fewer than `limit` were taken since the room's reset, then says `empty`.

## exit_rules

`{id, room, from_zone, to_zone, when, lines, pass_lines?, legacy_source}` — a room's valid_leave() refusing a
walk into the next zone or a passage between the two: `when` `weapon_in_hand` (with `present`, an
NPC that must stand in the room), `combat_exp_below` (with `value`), `not_apprentice_of` (with
`npc`, the master's definition), `not_family` (with `family`), `kar_slip` (random(kar) below
`value`: the leaver also falls unconscious) or `never` (refuses nobody, only says `pass_lines`).
The player stays and reads `lines`; one who goes through reads `pass_lines`. Two are not refusals:
`ask` (with `unless_gender`, `ask`, `choice`, `point`; no `lines`) stops anyone else and asks
(owner's rule on choices that can kill); one who goes on is put at `point` in `to_zone`.
`takes_back` (latemoon3.c, with `item`, `temp`, `taken`, `without`) lets everyone through: one
carrying the item with the temp flag hands it back (`taken`), one carrying none reads `without`.

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
LPC. `hit_ob: true` marks a skill with its own `hit_ob()` (spicyclaw, ts-fist): not
ported, so a fight that would call it stops. `force_hit_wound` `{condition, factor_divisor,
message}` (iceforce.c, with `standard_force_hit`): after std/force.c's number, random(the
skill's query_skill()) over damage_bonus plus it wounds the victim's kee by that sum, sets the
condition to force_factor / `factor_divisor` and adds nothing (its line joins the blow's). `dodge_messages` (query_dodge_msg) and `parry_messages` `{armed, unarmed}`
(parry.c, which combatd.c always asks) are its lines. `standard_force_hit`: it inherits
std/force.c and keeps its `hit_ob()`. `practice` is its `practice_skill()` (practice.c):
`{kee?, force?, mana?, sen?, done?, fail?, mana_fail?, sen_fail?, conjure?, refuses?}` — each at
least the amount, then all spent; `done` what it writes, `fail` its notify_fail() (`mana_fail`,
`sen_fail` a check's own); `conjure` `{below, skill, npcs: [{npc, below?}], came, caught,
standing}` is necromancy.c's 观想虫 (random(sen) under `below` conjures one of the `conjured`
NPCs instead); `refuses: true` never lets it happen (fonxanforce). No `practice`: the daemon has none and practice never progresses.
`exert`, `perform`, `cast` and `scribe` list the files its exert_function_file(),
perform_action_file(), cast_spell_file() and scribe_spell_file() reach (ExertFunctions,
SpecialFunctions: `animate` is cast at a corpse outside a fight, `haunt` drawn on a `scribe` paper).
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
`post_action` names a ported weapond.c function: `throw_weapon` (the thrown weapon loses one of
its amount) and `bash_weapon` (hammers' and staffs' bash, crush and slam: a parried blow may knock
the parrying weapon away or break it; every weapon has a `<id>#broken` form in the catalog).

## Not data yet

The beast actions stay in GDScript (`beast_combat_action_definitions.gd`).
`*_world_definitions.gd` now only hold the IDs the runtime names in code.
