# Content data format

Items, NPCs, spawns, vendors and the world (rooms, regions, maps, zones, portals, services, doors)
are JSON under `game/data/`, listed in `game/data/content_manifest.json` (load order = manifest
order, then file order). Each file is one object with any of the arrays `items`, `npcs`, `spawns`,
`item_spawns`, `vendors`, `rooms`, `regions`, `maps`, `zones`, `portals`, `services`, `doors`,
`landmarks`, `traps`, `hazards`, `exit_rules`, `skills`, `families`, `race_actions`, `weapon_actions`,
`quest_tiers`, `journal_chains`, `codex_topics`; exactly one file holds each of the objects `pacing`
(`common/pacing.json`, required), `progression` (`common/progression.json`) and `bounty_board`
(`native/bounties.json`).

`GameContent.catalog()` (`game/data/game_content.gd`) reads them once into a `ContentCatalog`.
`ContentCatalogBuilder` (`game/core/content/content_catalog_builder.gd`) dispatches each array to
its definition's `from_record()` (under `game/core/`) and cross-checks the results. Unknown fields, wrong types, non-integer numbers and broken
cross references are errors; a session refuses to start while `GameContent.load_errors()` is
non-empty.

Field names follow the LPC object so an importer can emit them directly. Facts the LPC derives by
rule are **not** authored; the loader applies the rule.

## Generated and hand-authored files

The `rooms`, `items`, `npcs`, `spawns`, `item_spawns` and `vendors` files of the ES2 regions and
`common/` are **generated** by `python -m tools.migration.content_importer` and never edited by hand; each region's `world.json`, the manifest and the rest of `common/`
(`pacing`, `skills`, `combat_actions`, `families`, `quests`, `journal`, `progression`, `codex`) are
hand-authored. `game/data/native/` is hand-authored new content that is not in ES2 (the 武馆's 木人,
the 雪亭驿 bounty board and its outlaws): its records say so in `legacy_source`/`legacy_room`/`source`
(`native: <plan>`), and NPCs there carry `native`. For each region with an override file
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

A room's `set("objects")` may name a class daemon's NPC (`CLASS_D("swordsman") + "/master"`, from
`include/globals.h`); its record lives in `common/npcs.json` with the ID
`common.npc.<class>.<file>` (`common.npc.swordsman.master`).

## items

| Field | LPC source | Notes |
|---|---|---|
| `id` | file path | `es2:<path without .c>`; stable, saved in save files |
| `legacy_sources` | file path(s) | first is canonical; identical copies (e.g. `npc/obj/`) are listed after it |
| `name`, `aliases` | `set_name(name, ids)` | |
| `name_pick` | `set_name(names[random(sizeof(names))], ids)` (d/choyin/obj/book.c) | the names create() draws from, `name` among them; the catalog makes a form `<id>#name=<n>` of each (a plain item only), and an NPC's loadout draws one as it is made (after the entry's own draws). Hand-written in `set` |
| `owner_is_killed` | the item's own `owner_is_killed()` (daemon/class/scholar/windspring.c) | `{npc, lines, unless_holder?}`: when its holder dies (chard.c make_corpse()) the item is destroyed before the corpse takes the rest and the summoned spawn of `npc` on that map comes in, the room reading `lines`; nothing when the holder is `unless_holder`. Hand-written in `set` |
| `long` | `set("long")` | optional; default is `name(Capitalized first alias)。\n` as in `feature/name.c` |
| `unit`, `material`, `value` | `set(...)` | `value` absent = 0 |
| `no_get` | `set("no_get", 1)` | `true`: get.c refuses it (这个东西拿不起来。) |
| `female_only`, `wear_refusal` | `set("female_only", 1)`; an own wear() (d/latemoon/obj/skirt.c) | `true`: wear.c lets only a 女性 character wear it; `wear_refusal` is the item's own wear() line instead of wear.c's |
| `no_drop` | `set("no_drop", 1 \| "line")` | `true` or drop.c's own line: drop.c, give.c and put.c refuse it |
| `max_encumbrance` | `set_max_encumbrance(n)` | a container: put.c puts things in while their weight fits, get.c takes them out (功德箱 10000) |
| `weight` | `set_weight()` | omitted for money; 0 when the LPC never sets it (`feature/move.c`) |
| `weapon` | `init_sword(damage, flags)` etc. | `{skill, damage, flags: ["secondary", "two_handed"], apply?, weight_dodge?}`; `apply` is `weapon_prop/*` other than damage (attack, defense, dodge, courage, intelligence, karma, personality, spells, spirituality), added to the wielder's `apply/*` (equip.c); `weight_dodge: "equip"` when create() calls std/equip.c's setup() (std/weapon/<kind>.c, not throwing.c): from 3000 weight a weapon without its own dodge gets `dodge = -weight/3000`; `rigidity` (`set("rigidity")`) is added to the weapon's side in weapond.c bash_weapon() |
| `armor` | `inherit CLOTH` + `armor_prop/*`, or `inherit EQUIP` + `set("armor_type")` | `{type, props, weight_dodge?}`; the setup() create() calls: `"armor"` (the eleven `std/armor/<type>.c`): over 3000 weight `dodge = -weight/3000`, replacing the armor's own; `"equip"` (`std/equip.c`): from 3000 weight, only without its own dodge; absent: no setup() call, no cost |
| `food` | `food_remaining`, `food_supply`, `drink_func` + `water_supply` | `{remaining, supply, water?, leaves?}`; `water` (food.c's drink_func, d/village's 西瓜): each bite also adds it to water, and a bite is refused once water is full; `leaves` `{name, aliases, weight, long, unit?}` is finish_eat()'s leftover (`<id>#eaten`). A `weapon` may be food too (d/chuenyu/obj/pigmeat.c, 牛腿: inherit HAMMER and F_FOOD): eaten up it leaves the same weapon, broken it stays food; not yet combinable with `armor`, `money` or a stack |
| `hang` | rope.c `add_action("hang_self", "hang")` | `true`: the 上吊 button (asked first): refused in an `outdoors` room, else die() |
| `scribe` | cmds/std/scribe.c's paper (obj/paper_seal.c) | `true`: 符 are drawn on it (owner: only on it). The catalog makes a 僵尸追魂符 of it for every NPC that is not raised (`<id>#haunt=<npc id>`, haunt.c), stacking only with sheets for the same name. Hand-written in `set` |
| `liquid` | `max_liquid` + `set("liquid", ...)` | `{max_liquid, type, name, remaining, drunk_apply}`; only `alcohol` and `water` are modelled; drinking gives +30 water (`feature/liquid.c`) |
| `study` | `set("skill", ([...]))` | `{skill, exp_required, sen_cost, difficulty, max_skill}`: study.c teaches the skill from it (the LPC `name` key is `skill`) |
| `act` | the item's own add_action() that acts on its carrier (d/latemoon/obj/bracelet.c pray, book.c dancing home, room/npc/obj/letter.c fire) | `{verb, command?, acts: [act]}` as a room's `act` service (`command`: the LPC verb, which a zone's `refuses` may answer): a button with the verb in the inventory for an item carried directly; the first act for the player runs (`carries`: present(id, me)), asked first as a room's command is; a `move` to another map's zone is a handoff. Hand-written in `set` |
| `money` | `money_id`, `base_value`, `base_unit`, `base_weight` | makes the item a stack and a currency; merge key is `/<first legacy source without .c>`; `coin`, `silver` and `gold` must all exist |
| `combined` | `inherit COMBINED_ITEM` (also throwing.c, powder.c): `set_amount`, `base_unit`, `base_weight` | `{amount, base_unit, base_weight}`: a stack (merge key as `money`) that a new one starts at `amount` of; no `weight` |
| `contains` | create()'s `new(...)->move(this_object())` (d/canyon/bamboo/obj/slipcase.c) | `[item]`: a new container (`max_encumbrance`) holds one of each |
| `unique` | `inherit F_UNIQUE` | `true`: only one may exist in the world (violate_unique()) |
| `master` | `set("master_id")` (d/choyin/obj/grass.c via lion.c die()) | `true`: the item records who got it; the catalog adds its master form (`<id>` + `ItemContentDefinition.MASTER_SUFFIX`), the player's. Plain items of one name only |
| `apply` | the item's own do_apply()/do_eat() | an `ItemApplyFunctions` ID (`snake_drug`, `hurt_drug`, `rose_pistil`, `tablet`) |
| `dissolve` | obj/dust.c | `true`: it dissolves a corpse |
| `pour` | std/medicine/powder.c, poison_dust.c do_pour() | `{condition, dose?, adds_to_liquid?}` (PourDefinition): poured into a drink, each sip adds `dose` (or what the liquid holds, each pour adding `adds_to_liquid`) to the condition |
| `play` | bamboo_pipe.c do_play() | what its room hears when played (`pipe`: pipe_notify(); a trap's `opens_on`) |
| `ghost_bane` | daemon/class/taoist/sword.c hit_ob() | `{line, color?}` (WeaponGhostBane), weapons only: against a ghost, random(max_atman) over its atman / 2 wounds its gin by the wielder's spi and heals the wielder as much; else random(spi) adds to the damage bonus |

The corpse (`obj/corpse.c`) is created by the death rules and is not an item record.

## npcs

| Field | LPC source | Notes |
|---|---|---|
| `id` | — | native ID `<region>.npc.<name>`, `<region>.npc.<subdirectory>.<name>` for a file under a region's subdirectory (d/latemoon/room/npc/servant.c: `latemoon.npc.room.servant`); saved in save files |
| `legacy_source` | file path | |
| `name`, `aliases`, `long` | `set_name`, `set("long")` | |
| `title` | `set("title")` | shown before the name, as `short()` does |
| `nickname` | `set("nickname")` | e.g. 风雨双侠 |
| `rank_info` | `set("rank_info/respect")`, `set("rank_info/self")` | `{respect?, self?}`: how others address it and how it calls itself (rankd.c), e.g. 小二哥, 小的 |
| `class` | `set("class")` | e.g. `taoist`: rankd.c's words for it (query_self() 贫道, query_respect()) |
| `race` | `set("race")` | `human` (default) or `beast` (`野兽`) |
| `gender`, `age` | `set(...)` | absent = not authored |
| `attributes` | `set("str")` … | keys `str cor int spi cps per con kar` |
| `resources` | `set("max_kee")` … | keys `gin kee sen` with `eff_` / `max_` variants; `force atman mana` with `max_` (race/human.c adds a quarter of `max_atman`/`max_force`/`max_mana` to `max_gin`/`max_kee`/`max_sen`) |
| `force_factor` | `set("force_factor")` | 加力: adds to strength (query_str) and drives the force hit of a mapped force skill |
| `combat_exp`, `score` | `set(...)` | |
| `attitude` | `set("attitude")` | `peaceful` (default), `friendly`, `heroism`, `aggressive` or `killer` (d/chuenyu/npc/wolfdog.c: answers spars and its name as aggressive does, but attack.c init() attacks only for aggressive, so only its berserk does); decides spars (`npc.c accept_fight`) and aggression. A function (kid2.c) is `{"random", "below", "then", "else"}`, drawn from the world-interaction stream each time a spar asks |
| `skills` | `set_skill(id, level)` | object, authored order kept |
| `skill_roll` | `if (random(n) == 0) set_skill() …` in create() (d/city/npc/walker.c) | `{random, below, skills, skill_map?}`: random(`random`) below `below` adds the skills and maps (drawn after `apply` rules, before a `chat_chance` rule) |
| `create_rolls` | create()'s own `set("str", 20 + random(15))` … `set_skill("blade", 30 + random(50))` (d/city/shangshu/npc/huyuan.c) | `[{key \| skill, base, plus_random}]` in create()'s order, drawn right after the name and age: `key` an attribute, `force`/`max_force`/`atman`/`max_atman`/`mana`/`max_mana`/`force_factor`, `combat_exp`, `chat_chance` or `chat_chance_combat` (the NPC's own, saved); `skill` a skill level. A field drawn here is not authored elsewhere |
| `name_parts` | `set_name(first_name[random(n)] + name_word[random(m)], ids)` (huyuan.c) | `[[words], [words]]`: drawn part by part, the first slowest; every combination is a name (a form `<id>#name=<n>` each, as `name_pick`), `name` among them |
| `skill_map` | `map_skill(use, skill)` | `{use: skill}`; the skill must be in `skills` (or drawn by `create_rolls`) |
| `carry` | `carry_object(path)->wield()/wear()`, `add_money(id, n)` | `{item, source, amount?, equip?: "wield"\|"wear"}`; `source` is the path the NPC file names. A stack's `amount` may be a rule (`{"base", "plus_random"}`); an entry may be `{"random": n, "below": k, "then": entry, "else": entry}` (worker2.c). These draw after setup(), in entry order |
| `limbs`, `verbs`, `apply` | `set("limbs")`, `set("verbs")`, `set_temp("apply/…")` | `apply` keys `attack damage armor dodge defense parry armor_vs_force`, for any race; a value may be a rule create() draws (`{"base", "plus_random"}`, after combat_exp), kept per NPC in CharacterState `applies` and saved |
| `capabilities` | — | native behaviour tags, e.g. `aggressive_on_player_presence` |
| `accept_fight` | the NPC's own `accept_fight()` | ordered rules `{family?, gender?, class?, emote?, say?, accept, kill?}` (`class`: the challenger's query("class"), d/sanyen's monks); the first matching rule decides; `kill` (with `accept`): the NPC answers with `kill_ob()` (annihir.c) and fights to kill, the challenger only fights back; `say` may use `$RESPECT`/`$SELF` (rankd.c). Hand-written in the override file's `set` |
| `inquiry` | `set("inquiry")` | `{topic: [line, ...]}` in authored order; ask.c says each line as `<name>说道：<line>`. Strings of an answer array (ask.c skips 0 and functions), and `{"mark_asker": mark}` for a function among them that marks the asker (oldman2.c set_flag()); any other function answering a topic is a finding `inquiry <topic>`. A topic may instead be `{eff_kee_percent: [{at_least, say}]}` (herbalist.c heal_me(), judged on the asker; none matching leaves ask.c's own answer), or `{rules: [...]}` (NpcInquiryRule; `vendor_list: true` is feature/vendor.c do_vendor_list(): the NPC's goods and prices; `make` `{every, lines}` is a story told a line every `every` seconds to the asker, d/canyon/npc/captain.c tell_story()). `relay_ask` `[line]` (d/choyin/npc/crone.c, owner) is said to a topic it has no answer for, in place of ask.c's own lines |
| `chat_chance`, `chat_msg` | `set("chat_chance")`, `set("chat_msg")` | npc.c chat(): `chat_chance` may be a rule each NPC draws when made (`{"base", "plus_random"}`: d/city/npc/walker.c's random(20), kept in its saved memory); `chat_msg` entries are lines (said as written), `{"action": "get_all" \| "wear_all" \| "wield_all"}` (u/cp/chater2.c: get.c on everything lying in its room but corpses, wear.c and wield.c on what it carries), `{"action": "random_move"}`, `{"action": "patrol"}` (a step along its `patrol`), `{"action": "drink", sated_water, dry_say, dry_clears?}` (drunk.c do_drink()) or `{"action": "emote", "verb"}` (an emote: prints nothing). Both lists also take `{"say", "color"}` (a coloured line) and npc.c's specials `{"action": "perform" \| "cast" \| "exert" \| "surrender", …}` (NpcSpecialAction); `chat_msg_combat` also `{"action": "match_weapon", …}` (萧辟尘's consider()). In `chat_msg_combat` a random_move walks out of the fight through go.c (`往X落荒而逃了。`; the fight goes on without it, and it is in the next room once the fight is over) and an emote prints nothing. Generated only when every entry is a line or random_move; otherwise both stay findings. `chat_msg_combat` also takes `{"action": "wield", "item", "say"?, "chat_chance_combat"?}`, `{"action": "call_partner", "partner", "emote"\|"say"\|"line"}` (ask_for_help()), `{"action": "say_by_age", "younger", "otherwise"}`, `{"action": "poison", "condition", "duration", "tell"}` (daemon/class/dancer/master.c use_poison(): a random enemy without the condition is told, and random(the NPC's combat_exp) over its own sets it) and `{"action": "say_while_flag", "flag", "say"}` (d/village/npc/meloner.c catch_thief(): said only while the NPC holds that object flag) |
| `settle` | the NPC's own do_return() (d/village/npc/meloner.c) | `{temp, item, label, hint, say}` (NpcSettle): one it caught (both hold the set_temp() flag `temp`) pays it the `item`'s value as buying does, on the HUD while it stands by and on the battle panel (`label`, its hover `hint`); it says `say`, both flags go and it goes home (out of the fight). Hand-written in `set` |
| `greeting` | the NPC's init()/greeting() | `{say}` (said as `<name>说道：<say>`), `{one_of: [{say} \| {emote} \| {line} \| act], out_of?}`, one drawn when it is said (waiter.c `random(3)`; an `emote` follows the name; `out_of` n: switch(random(n)), a draw past the choices says nothing), or `{rules: [act]}`, the first act for the player; one second after the player arrives (`$RESPECT` the player). An act is `{gender?, not_gender?, not_class?, temp?, not_temp?, mark?, not_mark?, carries?, present?, ask?, choice?, steps}` (ScriptedAct; `temp`/`not_temp` a set_temp() flag the player has or lacks, `mark`/`not_mark` a saved mark they have or lack, `carries` an id something carried answers to, `present` an NPC definition standing (conscious) where the player stands: present(), but one lying unconscious says nothing, 默认), `present_in` `{npc, zone}` one standing in another room (d/village/melonfarm.c's 瓜棚), `kar_above` `[n…]` rolls random(kar) > random(n) that must all come up (drawn once each, in order, only when reached; the branch is chosen when the command runs, and asks nothing of its own), `kar_draw` `{plus, at_least}` one roll of random(kar + plus) >= at_least (d/city/feiyuan.c's find), drawn the same way, `per_below` n one roll of random(per) < n (d/chuenyu/npc/jiading3.c's checklooking(): the raw attribute), drawn the same way (a greeting's rolls draw from the NPCs' stream): each step one of a line (`say`, `emote`, `line`, `whisper`, with an optional `color`), `damage` `{gin, kee, sen}`, `hurt` `{gin?, kee?, sen?: {base, random}}` (set("eff_kee", query("eff_kee") - n) and set("kee", query("kee") - n) with n = base + random(random): d/chuenyu/trap_castle.c's arrows), `heal` (`gin`/`kee`/`sen`, `base`, `random`), `condition` with `duration`, `calm` (bellicosity above 0 less random(kar) + n), `npc_force`, `close_door` (the door the player came by), `move` (a zone; a room's or an item's act may move to another map, as its last step, a greeting's only on its own map) with `point`, `kill`, `give` (an item) with `unless_temp` and `lines`, `set_temp` (a flag), `unmark` (a mark), `water` n (add("water", n): d/choyin/s_street1.c's well; an act `thirsty` is for one below max_water_capacity()), `mark` (set("marks/…", 1): xiaojuan2.c's marks/老刘), `npc_mood` (one of the NPC's `moods`), `npc_wield` (a new weapon in the NPC's hand: carry_object()->wield()), `leave` (`true`: the NPC leaves for good, oldliu.c's destruct(); an NPC definition: the first of them standing by leaves with it), `reincarnate` (`true`: damage.c reincarnate() and the move to REVIVE_ROOM, d/death's gargoyles and inn1.c; the act's last step, the move made by the session the same frame), `comes` (an NPC) with `from` (a zone): the first of them standing there comes beside the player and is the act's NPC from then on, so a room's act may `kill` and `npc_flag` (its own set_temp(), saved) after it. `close_door`, `kill`, `npc_force` and `npc_flag` belong to greetings, or follow a `comes`. Hand-written in the override file's `set` |
| `vendor` | the override's `vendors` | a vendors[] ID: the NPC sells these goods from its body (buy.c finds it with `present()`) |
| `accept_object` | the NPC's own `accept_object()` | ordered rules, first match decides; conditions `value_at_least`, `value_at_most`, `liquid` (`alcohol`/`water`), `liquid_remaining_at_most`, `npc_flag`, `giver_mark`, `giver_temp` (a set_temp() flag of the giver), `giver_max_force_below`, `item_name`, `item_alias`, `giver_family`, `tally` (a name: what the giver paid before under it counts with this gift toward the value bounds, d/canyon/npc/captain.c's toll, owner; a rule with it that takes the gift adds it, one that also marks the giver settles it); outcome `say`/`emote`, `lines` (ordered, each a line record with its `color`), `accept`, `mark_giver` (marks/<name>), `set_temps` (set_temp() flags, not saved), `set_npc_flag`, `gives`, `make` `{every, lines, gives}` (shaowei.c make_stage(): a line every `every` seconds, the item with the last), `move` with `point` (a zone on any map: the giver is taken there once the gift is taken; the boater's boat, owner: 山烟寺 plan Q1), `effect` (`temple_donation`: keeper.c; `pass_force`: old.c, with `giver_max_force_below` 160), `drops` (taken and put on the floor at the giver's feet: d/city/npc/waiter.c's drop all), `recruit` (the NPC's own command("recruit") after taking it: d/city/npc/chen.c; a 拜师 waiting on it is taken at once, else it offers), `destroys` (taken and destructed: d/city/npc/guard.c's 出城令牌) and `ask` (the 背包 asks it before such a gift; for a `recruit` that takes the player at once, the 拜师 question instead). No rule matching, or no rules, refuses (give.c). Hand-written in `set` |
| `accept_kill` | the NPC's own `accept_kill()` (d/choyin/npc/guard.c, d/waterfog/npc/elite_guard.c; no mudlib code calls it, owner: as meant) | `{line?, say?, exert?, fellows?: {say?}, report?: {say, vendetta?}, grudge?, hint?}` (NpcAcceptKill): when the player attacks it, its `line` as written (d/city/npc/guard.c do_kill(): 守城兵大叫：反了！反了！), its say and exert; the others of its kind standing there say `fellows.say` and join against the player; when one did, `report.say` and vendetta/`report.vendetta`; `grudge` marks vendetta/<grudge> either way; `hint` tells the player of the mark. Hand-written in `set` |
| `receive_damage`, `kill_ob`, `revive`, `defeated_enemy`, `chant` | the NPC's own functions (d/choyin/npc/oldman.c, daemon/class/scholar/sword_soul.c) | NpcHooks: `receive_damage` `{hurt?: {divisor, line, color?}, pills?: {count, below, line, color?}}` after a blow drew kee (the hurt line above max_kee / divisor and random_move() on random(kee) < damage; a pill below `below` gin, kee or sen); `kill_ob` `{lines}` read by one who attacks it instead of a fight, the NPC gone (no corpse) till its room's reset; `revive` `{exp_divisor, exp_plus, apply_divisor}` on waking; `defeated_enemy` `{line, color?}` when the player falls with it the last to hurt them; `chant` `{stages: [{after, say, line?, combat_exp?}], repeat_after}`, call_outs from the moment it is made. Hand-written in `set` |
| `calls` | init()'s call_outs (d/chuenyu/xiaojuan2.c, npc/chuenyu.c) | `[{after, ...act}]`: when the player comes into the NPC's room each starts anew (remove_call_out()); `after` seconds of NPC time later, if the player is still there, the act (a greeting's ScriptedAct: its conditions, `npc_in` a zone the NPC must stand in, and steps; no move, no rolls) runs. `after` 0 is a plain init(). `calls_hold` (`true`, owner 鬼门关 Q2): while they are to come the NPC does not wander (d/death's gargoyles) |
| `moods` | a function that changes the NPC for the rest of the story (d/village/npc/oldliu.c killhim()) | `{name: {title?, applies?: {key: n}, flags?, chat_chance?, chat_msg?}}` (NpcMood), put on by an act's `npc_mood`: its title shown, the applies added (set_temp("apply/…"): only what combat reads matters), the NPC flags held, its chat instead of the NPC's; all of it ends at the room's reset (owner M7). Held as the NPC flag `mood/<name>` |
| `die_marks_killer` | the NPC's die() (xiaojuan2.c) | a mark the player gets when they struck last (query_temp("last_damage_from")->set("marks/…", 1)) |
| `attack_ask`, `attack_choice` | — (owner's modern fix, 黑松山 F3) | 攻击 on the NPC asks this first, `attack_choice` its button |
| `follows_every_way` | team.c set_leader() (owner, 黑松山 F2) | `true`: following the player (npc_flag follows_player) it comes along every way they lead (an act's move, a passage, a landmark's portal, another map) and is put beside them where no walk leads; saved on whatever map it stands |
| `bellicosity` | `set("bellicosity")` | 杀气: courage in a fight (query_cor()) and, for an NPC that is not aggressive, attack.c init()'s berserk roll |
| `hit_ob` | the NPC's own poisoning hit_ob() (venomsnake.c, shaoin.c) | `{condition, duration, below, message, color}` (NpcHitCondition): a bare-handed blow not dodged or parried, with random(damage_bonus) over the victim's apply/armor, sets the condition to `duration` while it is below `below` |
| `killed_enemy` | the NPC's killed_enemy() (d/oldpine/npc/spy.c) | `{say, dissolve_after_ms}` (NpcKilledEnemy): said over its kill; then it dissolves the newest corpse in the room (0: none) |
| `ghost` | is_ghost() (d/choyin/npc/ghost.c, shadow.c) | `true`: hidden from one who is no ghost (not drawn nor picked; fighting it may miss a turn); leaves no corpse, what it carried falls where it died |
| `die_carries` | the NPC's die() (d/choyin/npc/lion.c) | `{item, master?}`: the item is made in it as it dies, so its corpse holds it; `master` gives the player who struck last its master form |
| `relay_say` | the NPC's own relay_say() (d/green/npc/oldman2.c) | `{phrase: [line]}`: its answer when the player says the phrase beside it |
| `attack_unless_mark`, `toll_attack_delay_ms`, `toll_shout` | u/cloud gangster.c greeting(), kill_passenger() | a toll-taker: it attacks a passer-by without marks/<mark> (and on sight once it has fought them), `toll_attack_delay_ms` after they come into reach, shouting its `chat_msg` line `toll_shout` at once (DECISIONS「响应性」) |
| `vendetta_mark` | attack.c init() vendetta | a killer of its kind is marked with it, and it attacks whoever is |
| `steal` | u/cloud thief.c init() with cmds/std/steal.c | `{what, chance_below}` (NpcSteal): an arriving player with random(kar) below the chance has `what` (else a random thing) stolen by steal.c's rolls |
| `quest_giver` | u/cloud/npc/god.c give_quest() | `true`: it hands out `quest_tiers` tasks |
| `wager` | u/cloud/npc/judge.c | `{lose_below, out_of, payout, lose, win}` (NpcWager), with an `accept_object` rule `effect: wager`: random(`out_of`) below `lose_below` keeps the stake, else it pays `payout` times it |
| `shop_front` | d/green/npc/shen.c list_item(), buy_item() | `{list, buy: [line]}` (NpcShopFront): its own list and buy where it sells nothing; not with `vendor` |
| `patrol` | d/choyin/npc/yamen_po.c BigWay, patrol() | `{route: [zone], arrest}` (NpcPatrol): its chat's `{"action": "patrol"}` walks one zone along the route and back, catching thieves there |
| `sentence` | d/choyin/npc/judgeman.c settle_lawsuit() | `{after, beat_line, faint_lines, warn_line, sorry_line, out: {zone, point}}` (NpcSentence): the beating for one brought before it, then they are put out at `out` |
| `ordination` | daemon/class/bonze/master.c do_kneel() | `{temp, prefixes, lines, color?, say, class}` (NpcOrdination): the 跪下受戒 button for one it marked with `temp`; they take a new name (a prefix + their name's first character) and the class |
| `summoned` | obj/npc/heaven_soldier.c invocation(), leave() | `{arrive, leave, color?}` (NpcSummoning): an NPC a spell calls to its caster's fight, gone when the fight ends. Never placed by a room |
| `native` | — (new content) | `{role}`: `training_dummy` (the 武馆's 木人: it only spars) or `bounty_target` (a bounty board outlaw: not kept by a save) |
| `flags` | object variables `create()` sets | e.g. `["has_alcohol"]` (drunk.c); rules test and set them; not saved |
| `fight_deferred` | — | why the NPC cannot be fought yet (its mapped skills have no ported actions); no 攻击/切磋 |
| `family` | `create_family(name, generation, title)` | `{name, generation, title}`; the name must be in `families.json`; privileges -1; generation 0 is a founder's (瑷伦) |
| `f_master` | `inherit F_MASTER` | `true`: std/char/master.c prevent_learn() limits what it teaches |
| `recognize_apprentice` | the NPC's own `recognize_apprentice()` | ordered rules `{family?, giver_mark?, say?, emote?, fail?, accept}`; `fail` replaces learn.c's polite refusal. Hand-written in `set` |
| `apprentice` | the master's `attempt_apprentice()`/`recruit_apprentice()` | `{requires: {cor?, cps?}, refuse_say, accept_say, class}` (effective attributes); `kind` `oath`, `trial`, `refuses` or `silent` (d/city/npc/chen.c: no attempt_apprentice(), a request only waits for its own recruit; `class`, `title`); needs `family`. Hand-written in `set` |
| `conjured` | mind_bug.c's `create()` reading `this_player()` and `die()` | `{skill, combat_exp_per_level, spi_divisor, killed_by_owner: [line], killed_by_other: [line]}`: an NPC a skill's practice conjures (never placed by a room, carries nothing). Hand-written in `set` |
| `raised` | corpse.c `animate()` and zombie.c `heal_up()`, `dispell()` | `{name, drain: {above, atman, gin}, tell, color?, dissolve}`: an NPC a spell raises from a corpse, named `name` with `{name}` the victim's; each heal_up() it `tell`s its master and takes `atman` and `gin` while they have more than `above` atman, else it `dissolve`s a second later ($N its name). Never placed by a room, not saved. Hand-written in `set` |

`age`, `combat_exp` and `score` may be a rule `create()` draws: `{"base": 600, "plus_random": 400}`
is `600+random(400)`, `"minus_random"` subtracts. `gender` may be
`{"random": 10, "below": 7, "then": "男性", "else": "女性"}`; the gender is drawn before the age unless
`age_first` (d/city/npc/walker.c). Draws happen at creation, before the
race's own draws; a save keeps the drawn values.

An NPC teaches every skill it has that `skills.json` defines when its `family` or
`recognize_apprentice` can admit a student (`NpcTeacher`); the map gives such an NPC, and a
`vendor`, a service on its body (`NpcService`). An NPC function no field above models stays a
finding of the importer, decided in the override's `review`.

## spawns

`{id, npc, map, zone, points, legacy_room, legacy_quantity, presence_radius?, summoned?, draw?, once?, pacing?}` — one entry per
`set("objects")` line of a room; world.json may author more (a `summoned` spawn: keep2.c's guards,
house3.c's spiders), whose NPCs wait absent until a room rule calls them in. Spawns sharing a
`draw` group (road2.c's guards on duty) are absent too: when the world is made and at each reset
of their room one of the group is drawn and comes; the others stay as they are. The override's
`npcs` lists NPC files no room places that such a spawn needs. `points` names the scene's spawn markers and must have
`legacy_quantity` entries. `zone` is the NPC's home: it wanders only there and in the zones next
to it, and `legacy_room`'s reset brings it home or makes a new one when it died. `presence_radius` (pixels, default 120) is how close the player must be
for an aggressive NPC to notice them — the native stand-in for "in the same room" (in an `indoors`
zone it notices the whole room). `once` (owner,
黑松山 Q2 (a): 小娟) makes the NPC once in the world's life: dead, no reset makes it anew. Neither
does one gone for good (an act's `leave`: the NPC flag `gone`). `pacing` names the pacing knob
that places a native spawn at all (`training_dummies`); with the knob off the world has none.
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

`{id, short, long, exits?, no_fight?, no_magic?, outdoors?}` — one ES2 room, copied verbatim from `set("short")`, the
`@LONG` block of `set("long")` (hard line breaks kept; the UI rewraps) and the static
`set("exits")`. `no_fight: true` (`set("no_fight")`) refuses attacks from or into every zone
holding the room ("这里不准战斗。", kill.c) and stops NPC aggression there (combatd.c).
`no_magic: true` (`set("no_magic")`): cast.c refuses there ("这里不准念咒文。").
`outdoors: true` is `set("outdoors")` with any area name (rope.c finds nowhere to hang a rope). `id` is
`es2:<path without .c>`; exit targets use the same form and may name rooms that are not migrated.
`tools/tests/test_room_data.py` checks the text against `reference/es2/`.

## regions, maps

`regions`: `{id, name, recommended_exp?}`; `recommended_exp` (native, DECISIONS「经验节奏」) is the
combat_exp the region is meant for: below it the player's gains are larger (ProgressionGain).
`maps`: `{id, region, scene, entry, interior?}` — one Godot scene the player walks
in; `entry` is the spawn marker the player body waits on until the map is entered; `interior: true`
marks a building's own map, entered and left through a door (feel `door_fade_*`, no banner). Every map scene
uses `WorldMapController` (`map` export = the map ID) and carries one ID-bearing component per
record: `WorldPhysicalZoneArea2D` (zone), `WorldSpawnMarker2D`, `WorldPassageArea2D` (portal; a
portal that stays on its map moves the player directly), `WorldServicePoint` (service), `WorldDoor`
(door), `WorldLandmarkArea2D` (landmark). NPCs are not placed in the scene: the map gives each
spawn point a `WorldNpcBody2D` (`scenes/world/common/world_npc_body.tscn`). A map refuses to
initialize when scene and data disagree.

Terrain is not content data: `python -m tools.maps.paint` writes every map scene, its
`TileMapLayer`s included, from `tools/maps/layouts/<region>.json` ([TERRAIN_TILES](TERRAIN_TILES.md)).
On every map the tiles are the collision. Tiles carry no IDs.

A map shown in 3D (the layout's `scene.presentation`) has a `MapView` node (`WorldVoxelView`) naming its voxel config,
`game/data/<region>/voxel/<map>.json` (not in the manifest; read by
`game/presentation/voxel/world_voxel_view.gd` and `voxel_map_geometry.gd` `make()`, which hold
each key's shape). It holds only what blocks nothing:

* `indoor`, `camera_size`; `light` (day/night profile: ambient, sun, carried lamp, fog);
* `props` (`kind`, `at`, `size`, `rotation`, colours), `buildings` (outward shape of buildings
  with maps of their own), `actors` (looks by NPC id, `default`), `entrances` (labels by portal
  id), `door_looks` (by door id), `items` (looks by item id);
* walls: `cutaway_rooms` (`true`: every zone's near walls, south and side, cut low), or `low_walls` /
  `low_walls_left` (pixel rects cut low), `wall_looks` (rock or earth walls in rects), `palette`
  (wall, wood colours), `courtyard` (an indoor map with grass);
* ground: `ground` (style per terrain kind, e.g. scree), `ground_tints`, `surfaces` (a zone's
  floor drawn as another kind), `reshape` (rects drawn as another kind), `exit_trails` (a road
  shown running on past an exit), `water`, `cliffs` (raised rock and sunk pits), `edge` (the
  landmass's sides), `weather` (mud and puddle patches), `flora` (grass, flowers, trees, per zone or area),
  `ambience` (birds, dust, falling leaves).

What blocks is not here: a layout fill row ends with `{"look": {...}}` and the painter writes it
as a `Furnishings` child (position = the box's centre, `metadata/look`, `metadata/footprint`) —
see AGENTS.md「Maps and art」.

## zones

`{id, map, rooms, links?, distinct?, indoors?, refuses?}` (`ZoneDefinition`) — a walkable part of
a map made of one or more rooms. The **first room is the primary room**: its `short` is the zone's
title and its `long` is what the player reads on entering. Fights happen per zone, as per room in
ES2: the NPCs there that attack on sight fall on the player together (DECISIONS「进门一起上」).
Two zones are neighbours when a room of one has an exit into a
room of the other, or when one lists the other in `links` — a walkable connection no static ES2
exit states (random maze exits, a recorded geography decision); each link needs its DECISIONS entry.
Zone tracking follows the player body's center (half-open rectangles, one owner per point) and
only accepts moves between neighbours. `distinct: true`: a room of its own that shares its name with
a neighbour (老松寨's hall, cave5): its text shows on arrival even from that neighbour.
`indoors: true`: a room inside (a building, tent, cave or dungeon): an aggressive NPC there notices
whoever is in the room (ES2 init()), not only who comes near (DECISIONS「室内察觉」). `refuses`
`{command: line}`: a carried item's command (its `act`'s `command`, the LPC verb) the room's own add_action()
answers with its line instead (d/choyin/club.c: pray and dancing fail in the hermit's hall).

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
latemoon2.c search bracelet, latemoon8.c search bed, with its `act`: `{verb, acts: [act]}` as a
greeting's acts: the first for the player runs; one with `ask` is asked first, and so is one whose
`damage` would knock the player out; `stronger` `{npc, zone, ask, choice}` asks first while the first
of that NPC standing in that zone is clearly stronger: d/village/melonfarm.c's pick), `bounty`
(native: the 雪亭驿 board's panel of `bounty_board` postings; none while pacing `bounty_board` is
off). The context button reads `name · verb`, e.g. 钱庄 ·
兑换; `hockshop` also requires an idle, non-fighting player. Goods and teaching belong to NPCs
(`vendor`, teaching fields): the map binds them to the NPC's body, reached within 96 pixels of it
(店小二 · 购买, 柳淳风 · 请教).

## doors

`{id, name, zones, reach, closable?, open?, operable?, legacy_room}` — an ES2 `create_door()`
between two zones of one map, or of two maps a portal joins (a building's door onto its street:
both scenes place a `WorldDoor` of this ID over the passage, and they open and shut together).
It starts closed (`open: true`: create_door() without DOOR_CLOSED) and its state is not saved
(a closed doorway is never a valid saved position).
`closable: false` marks the approved open-only pawn-shop door; `operable: false` a door only a
room rule opens and shuts (a `traps` exit).

## traps

`{id, room, door, from_zone, to_zone, summon?, opens_on?, messages: {shout, shut, open}, legacy_source}`
(`RoomTrapDefinition`) — a room that shuts its way out behind the player (keep2.c): leaving
`from_zone` for `to_zone` while `door` (open at start, `operable: false`) stands open shouts and
shuts it and calls in the `summon` spawn (summoned, in `from_zone`); the room's reset, or an item
whose `play` is `opens_on` played in `from_zone`, opens it again. Not saved.

## landmarks

`{id, zone, name, long, action, portals, policy?, contact?, messages?, legacy_source}` — an ES2 room
item (`item_desc`) the player selects, looks at (`long`, verbatim) and uses with `action` (`climb`,
`hold`). Every portal must leave from `zone`. `contact: true` means the player must stand inside
the landmark's area in the scene, not just in the zone. `policy` picks the rule
(`WorldLandmarkDefinition.POLICIES` lists each one's portals, messages and settings; default
`portal`, one portal, which may say its LPC line `use`); `vine` (epath2.c) rolls dodge between two portals `[waterfall, passage]` and prints
`messages` `hold`, `fall`, `fall_observer`, `climb`, `climb_observer` (`below`: the dodge draw
that falls, default 5). The roll stays in code.
`bury` (cave5.c do_bury()) buries the `buried` item lying in the zone and rolls kar: the `reward`
falls, or the player falls through its portal. `join_class` (class_guild.c join) gives a player
with no class its `class` (`joined`), else `refused`. `lift` (d/choyin/w_street1.c) counts lifts
since the room's reset (`lift`); once that count and str / `divisor` reach `limit` it opens
(`open`) and the player falls through (`closed`). `note_maze` (d/choyin/taolin.c) is a note whose
line (`read`) names the way out of a room whose ways lead back into it, one of its `notes` drawn
anew after each way: its `enter` portal sets the counter `counter` to `steps`, the named way
brings the way out `nearer`, any other `further`, and the right way with no more than `nearer`
left leads out (`out`, the `mark` given).
`hidden_passage` (weapon_storage.c) moves nobody: each use is one push (`messages.push`, said when
authored); the `pushes`-th opens its portals `[down, up]` for `open_seconds` of world time (`open`,
`close`). `up` leads from where `down` arrives back to `zone`; both stay shut (their scene passages
off) until the landmark opens them, and no other landmark may use them. With `[down]` alone the
way back is an ordinary exit, the passage closes whoever stands beyond it, and opening it under the
player takes them through; `every_push` 1 has no count: every push opens it, again while open,
without putting the closing off (d/village/road6.c's grass). `closes_on_time` 1 shuts it when the
time is up even on a player beyond it (d/chuenyu/tunnel4.c's slab), who reads `messages.close_beyond`.
`push_stone` (closed.c): below the record's `force`, `max_force` or `force_factor` the push is
`weak`; else it costs `gin`, `kee` and `sen` (`push`) and random(`random`) 0 rolls the stone away
(`rolled`) through its one portal. `search` (water.c): with the record's `mark`, random(`random`)
other than 0 gives the `reward` item (`found`, the mark stays), else the mark goes (`search`,
`nothing`). A `look` landmark may `teach` marks (`teaches`: d/latemoon/latebook.c's picture names two
dances). `look_spawn` (house3.c) has no action: looking calls one NPC of its summoned `spawn`
in (`spawn`) while fewer than `limit` came since its room's reset and a point is free; else the
look reads `long`. `dial` (d/city/jitan.c's button) is a hidden passage worked by `turns` `[{action, count, line}]`, each a button of its own that counts its `count` and says its `line`; its own `action` (press) opens `portals` `[down, up]` for `open_seconds` (`open`) when the counts are its `combination` `{count: n}` and the way is shut, and clears the counts either way (M4); the room's reset clears them; it closes on time even on a player below (`close` at the dial, `close_below` below). `dial_below` (owner, 京师 Q2 (a)) stands where its dial's way up leaves and `opens` it from there for the same time (the dial's `open_below`). `take` (moonc.c do_pick(), latemoon2.c do_take()) gives the `reward` item
(`take`) while fewer than `limit` were taken since the room's reset, then says `empty`; with
a `guard` (an NPC definition: d/sanyen/kitchen.c's cook) standing in the zone it says
`guarded` first and gives nothing.

## hazards

`{id, zone, room, first_seconds, every_seconds, act: {steps}, legacy_source}` — a room that acts
on the player again and again while they stay (d/chuenyu/trap_castle.c: init()'s
call_out("arrowing", 15), then every 5 seconds while the player is there): the act (lines and
hurts on whoever stands there: no conditions, rolls, question, NPC or move) comes `first_seconds` of
world time after the player comes in, then every `every_seconds`; one that fells the player or
starts a fight ends that moment's volleys. Leaving clears the wait; it is not saved (a Continue there waits the first time
again). One hazard a zone.

## exit_rules

`{id, room, from_zone, to_zone, when, lines, pass_lines?, legacy_source}` — a room's valid_leave() refusing a
walk into the next zone or a passage between the two: `when` `weapon_in_hand` (with `present`, an
NPC that must stand in the room), `combat_exp_below` (with `value`), `not_apprentice_of` (with
`npc`, the master's definition), `not_family` (with `family`), `no_mark` (with `mark`, a saved mark one needs: d/choyin/entrance.c; with `present`, only while that NPC is in the room, and its `pass_lines` only then: d/city/npc/waiter.c go_up(); `present` may list several kinds, any of them there: d/city/shangshu/road2.c's present("trainer"); `spends` deletes the mark of one who goes through: gate.c), `always` (everyone: d/village/lakeside.c's lake), `held` (with `present` and `temp`: one with the set_temp() flag while an NPC of `present` holding the same flag stands awake in the room: d/village/melonfarm.c), `tries` (with `temp`, `value` and `point`: d/death/road2.c's long road; each refused try adds one to the set_temp() counter `temp` and puts the player at `point` in `from_zone`, the `value`-th goes through, and leaving `from_zone` any way deletes the counter; a walk on one map only), `kar_slip` (random(kar) below
`value`: the leaver also falls unconscious) or `never` (refuses nobody, only says `pass_lines`).
The player stays and reads `lines`; one who goes through reads `pass_lines`. Two are not refusals:
`ask` (with `unless_gender`, `ask`, `choice`, `point`; no `lines`) stops anyone else and asks
(owner's rule on choices that can kill); one who goes on is put at `point` in `to_zone`. It
guards a walk between two zones of one map, never a passage.
`takes_back` (latemoon3.c, with `item`, `temp`, `taken`, `without`) lets everyone through: one
carrying the item with the temp flag hands it back (`taken`), one carrying none reads `without`;
with `items` instead (d/choyin/club.c's books) every one carried goes back, no flag needed.

## pacing

`{combat_round_ms, room_reset_seconds?}` — milliseconds between two combat rounds on every map,
the native ES2 heart_beat in a fight, and MudOS's `time to reset`: a room
resets half to all of this many seconds of world time after its last reset (default 1800,
config.ES2; lower it locally to playtest resets). The other knobs (gains, responsiveness, away
catch-up, corpse decay and the native `milestone_rewards`, `staged_potential_cap`, `bounty_board`,
`training_dummies`; each left out is ES2's) are listed in `PacingDefinition`;
`feel` `{map_fade_out_ms?, map_fade_in_ms?, map_banner_ms?, door_fade_out_ms?, door_fade_in_ms?,
camera_follow_speed?, move_accel_ms?, move_stop_ms?, speech_bubble_ms?, speech_bubble_char_ms?,
speech_reach_px?, room_text_ms?, room_text_char_ms?, menu_fade_ms?, battle_slow_percent?,
battle_fast_percent?, battle_line_ms?, bar_tween_ms?, hit_flash_ms?, battle_end_hold_ms?,
training_step_ms?, corner_slide_px?}` holds the presentation's (`FeelDefinition`, which says what
each does; DECISIONS「手感」; each left out is 0: none of it).

## skills, families

`skills`: `{id, name, kind: basic|specialized, type: martial|knowledge, enable?: [use], legacy_source,
actions?, dodge_messages?, parry_messages?, standard_force_hit?, hit_ob?, practice?, valid_learn?,
improved_line?, improved_color?}` — a skill the game models (learn,
enable, the character panel's name; to_chinese()'s dictionary is not in the mudlib, so `name` is
authored). A specialized skill names the uses it can be enabled for. `actions` is the skill's
`action` table (query_action): `{id, action, damage_type, damage?, force?, weapon?}`, the ID being
`es2:<legacy_source without .c>/<id>`; combatd.c reads no other key, so `dodge`/`parry` stay in the
LPC. `hit_ob: true` marks a skill with its own `hit_ob()` that is not
ported (ts-fist), so a fight that would call it stops; `hit_wound` `{at_least, messages}` is spicyclaw.c's
(MartialHitWound): from a damage_bonus of `at_least`, random(bonus / 2) over the victim's query_str()
wounds kee by (bonus - at_least) / 2 and adds one of the lines (random(3)) after the force hit's. `force_hit_wound` `{condition, factor_divisor,
message}` (iceforce.c, with `standard_force_hit`): after std/force.c's number, random(the
skill's query_skill()) over damage_bonus plus it wounds the victim's kee by that sum, sets the
condition to force_factor / `factor_divisor` and adds nothing (its line joins the blow's). `dodge_messages` (query_dodge_msg) and `parry_messages` `{armed, unarmed}`
(parry.c, which combatd.c always asks) are its lines. `standard_force_hit`: it inherits
std/force.c and keeps its `hit_ob()`. `practice` is its `practice_skill()` (practice.c):
`{kee?, force?, mana?, sen?, sen_first?, weapon?, done?, fail?, force_fail?, mana_fail?, sen_fail?,
weapon_fail?, water_fail?, conjure?, refuses?}` — the `weapon` in hand first, then each at
least the amount (`sen_first`: sen before kee and force, tenderzhi.c), then all spent; `done` what it writes, `fail` its notify_fail() (`force_fail`, `mana_fail`,
`sen_fail`, `weapon_fail` a check's own; `water_fail`: the room must have water, serpentforce.c); `conjure` `{below, skill, npcs: [{npc, below?}], came, caught,
standing}` is necromancy.c's 观想虫 (random(sen) under `below` conjures one of the `conjured`
NPCs instead); `refuses: true` never lets it happen (fonxanforce). No `practice`: the daemon has none and practice never progresses.
`exert`, `perform`, `cast` and `scribe` list the files its exert_function_file(),
perform_action_file(), cast_spell_file() and scribe_spell_file() reach (ExertFunctions,
SpecialFunctions: `animate` is cast at a corpse outside a fight, `haunt` drawn on a `scribe` paper).
`valid_learn` maps the rule that refused (`max_force`, `mapped`, `weapon`, `empty_hands`) to
valid_learn()'s notify_fail(), which learn.c, practice.c and study.c then print. `improved_line`
and `improved_color` (HIR/HIY/HIC/HIW): `skill_improved()`'s line when its effect applies
(`improved_every` n: only on levels divisible by n, six-chaos-sword.c).
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

## quest_tiers

`common/quests.json`. `{min_exp, legacy_source, quests: [{target, quest_type, time, exp_bonus,
pot_bonus, score}]}` (`QuestTier`, `QuestDefinition`) — one of god.c's levels: the tasks
quest/qlist<level>.c lists for a combat_exp of at least `min_exp` (`quest_type` 杀 or 寻; a name
listed twice is drawn twice as often), handed out by a `quest_giver`.

## journal_chains, codex_topics

`common/journal.json`: `{id, title, region, sources, entries: [{id, text, when, quote?, final?}]}`
(`JournalChainDefinition`) — one story on the 任务 page, shown once an entry is recorded. `when` is
one of `{mark}`, `{temp}`, `{item}`, `{seen}` (an NPC met in its room) or `{heard: {npc, topic}}`;
`quote` `{npc, topic}` shows that answer under the text; a `final` entry completes the chain (its
历练 reward). `common/codex.json`: `{id, title, paragraphs, byline?, source}` (`CodexTopicDefinition`)
— a 百科 entry from an ES2 help file; a paragraph is a string or `{heading}`.

## progression, bounty_board

Native, one object each (DECISIONS「经验节奏」), used only while their pacing knobs are on.
`progression` (`common/progression.json`, `ProgressionRules`): `{source, potential_percent, stages:
[{min_exp, unit, potential_cap}], rewards: {kind: percent}, chain_percent, notable_npcs, places}` —
one-time 历练 rewards worth `unit` × the kind's percent at the player's stage. `bounty_board`
(`native/bounties.json`, `BountyRules`): `{source, postings, tiers: [{min_exp, npc, silver}],
places: [{map, zone}]}` — the 雪亭驿 board's postings: the outlaw (`native.role` `bounty_target`)
a player of that combat_exp is offered and where it comes out.

## Not data yet

The beast actions stay in GDScript (`game/data/combat/beast_combat_action_definitions.gd`).
`game/data/<region>/<region>_world_definitions.gd` (snow, oldpine, death) only hold the IDs the
runtime names in code. `game/data/new_game/names.json` (new-character names) is read by
`new_player_random_name.gd`, not the catalog.
