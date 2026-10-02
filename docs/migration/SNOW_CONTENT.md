# Snow content (Package 4)

How Snow's rooms, NPCs and shops come from `reference/es2/mudlib/d/snow/`, what the LPC says that
the code does not, and what each NPC cost. The data format and the importer are described in
[CONTENT_DATA_FORMAT](CONTENT_DATA_FORMAT.md); decisions are in [DECISIONS](DECISIONS.md).

## Placed so far (4A–4C)

| Room | LPC `set("objects")` | Native |
|---|---|---|
| inn | 旅客 ×2, 店小二 | travellers placed; the waiter stays the Inn's vendor service until 4E |
| eroad2 | 野狗 ×2 | placed |
| temple | 庙祝, 桃符纸 ×2, 功德箱 | keeper placed; 功德箱 on the floor (no_get, 4C); 桃符纸 waits for combined items |
| mstreet2 | 醉汉, 收破烂的 | placed |
| bank | 安惜迩 | the bank service until 4E |
| school1 | 刘安禄 | placed |
| school2 | 武馆弟子 ×6, 李火狮 | placed |
| schoolhall | 柳淳风 (`CLASS_D("swordsman")`) | the teacher service |
| square | 旅客 (飞刀) ×3 | waits for combined throwing weapons |
| sroad2 | 农夫 ×2 | placed (4B) |
| sroad4 | 疯狗 | placed, aggressive (4B) |
| school | 魏无极 | placed; tuition and literate in 4E |
| herbshop | 杨掌柜, 樵夫 | the herbshop's vendor service until 4E; the woodcutter placed |
| postoffice | 杜宽 | placed; mail omitted (multiplayer) |
| smithy | 王铁匠 | the smithy's vendor service (300 for a hammer) until 4E |
| sroad3, sroad5, hockshop2 | — | rooms only |
| inn_2f | 老鼠 ×6 | placed (4C), upstairs map; 房门 to n_room, e_room, w_room |
| nyard | 柳绘心 | waits for the 封山剑法/乱七星步 package (sword maps to fonxansword) |
| weapon_storage | 竹剑 | on the floor (4C); the shelf opens the way down |
| secret_storage | 牛皮盾 | on the floor (4C), cellar map |
| n_room, e_room, w_room, inneryard, innerhall, guestroom | — | rooms only |

## Talk and wandering (4D)

| NPC | LPC | Native |
|---|---|---|
| 旅客 | chat 40: random_move | stays in the Inn: its exits all leave the Inn's map |
| 野狗 | chat 6: random_move, four lines | eroad1-3 |
| 庙祝 | init()/greeting() | greets one second after the player comes in |
| 醉汉 | chat 10: do_drink | with give and drop (4E) |
| 收破烂的 | chat 20: three lines, random_move | mstreet1-3, the smithy, the workplace |
| 刘安禄 | inquiry 刘老三, 血手刘三 (`ask_me`) | not listed until the reveal is ported |
| 李火狮 | inquiry here, name, 柳家拳法 | here/name behind 这里/名字 |
| 疯狗 | chat 15: random_move | sroad3-5 |
| 魏无极 | inquiry 学费, 读书识字, 刘安禄 | |
| 樵夫 | chat 15: three lines, random_move | the herbshop and mstreet3 |
| 杜宽 | inquiry 驿站, 寄信, 收信 | 驿站 (mail omitted) |
| 店小二, 杨掌柜, 王铁匠, 安惜迩 | greeting, inquiry, chat | with their bodies (4E) |

## Source anomalies

- `square.c` comments out its four 苦力; only the 飞刀 travellers remain. `hockshop.c` comments
  out 陆得财 (the beggar master).
- `herbshop1.c` (药铺密室) has no exit leading into it anywhere in the mudlib.
- `school.c` describes a west door to a side room and `sroad2.c` an inn to the north; neither
  room has that exit.
- `teacher.c`'s `学费`/`刘安禄` inquiry calls `follow_player`, whose body is commented out.
- `crazy_dog.c` sets `chat_msg_combat` but no `chat_chance_combat`, so its fight lines and its
  fleeing `random_move` never fire (`npc.c` `chat()`).
- `smith.c` is no `F_VENDOR`: `list` does not work on him, and he sells a hammer worth 3 for 300
  through his own `buy_object()`.
- `npc/herbalist.c` `heal_me()` stops after the 95% case; below that the NPC gives the default
  answer.
- `obj/drug/snake_drug.c` sets `base_weiht` (typo): the combined item has no base weight.
- `d/snow/npc/obj/*.c` are byte-identical copies of `d/snow/obj/*.c`, except `old_book.c`; the
  importer merges identical copies into one item.
- `guestroom.c` says its way out is west; its only exit is north. `innerhall.c` describes ways
  east, north and south (祠堂, the bedrooms, the kitchen); it has only the west exit. The
  secret storage's bed (`bed`) has no `item_desc`.
- `secret_storage.c` has no exits; `weapon_storage.c` sets its `up` only while the passage is
  open and only if the room is loaded (DECISIONS 4C). `do_push()` counts any argument but
  `shelf` (`push right` too) as a push to the left.
- `obj/denotation.c` defines `insert_object()`, which MudOS never calls: the box is a plain
  container and donations change nothing. `d/chuenyu/tunnel4.c` is a copy of `weapon_storage.c`.
- `guard.c`'s `ask_me(who)` is called by `dbase.c` query() with the NPC itself, so its
  `combat_exp < 20000` check never refuses (刘安禄 has exactly 20000) and anyone who asks about
  刘老三 unmasks him half the time. `teacher.c`'s 学费 answer holds three `0` pauses ask.c skips.
- `std/char.c` keeps calling chat() for an unconscious NPC, and turns a healed NPC's heart beat
  off when no player is in its room; only a fight or a wound turns it on again.
- `std/room.c` reset() remakes only objects that were destructed: a picked-up item is not
  replaced. Items seemed to respawn in ES2 because MudOS `clean_up()` destructed unvisited rooms,
  which then loaded with everything new. `d/oldpine/npc/fat_bandit.c` sets `chat_chance` with no
  `chat_msg`.

## Cost per NPC (baseline for later regions)

Measured in 4A by the agent, wall clock from the session's timestamps. Every 4A NPC is data
only: no NPC needed its own script. The counts come from `build/import/review.md`.

| NPC | Tier | Fields from LPC | Overrides | Findings decided | Spawn markers | Needed first |
|---|---|---|---|---|---|---|
| 旅客 traveller | data + draws | 10 | 0 | 2 | 2 | random `create()` values |
| 野狗 dog | data | 9 | 0 | 3 | 2 | beast verbs beyond bite |
| 庙祝 keeper | data | 7 | 0 | 3 | 1 | `no_fight` (its temple) |
| 醉汉 drunk | data | 9 | 0 | 5 | 1 | NPC-carried liquid state |
| 收破烂的 scavenger | data | 8 | 0 | 7 | 1 | — |
| 刘安禄 guard | data | 11 | 0 | 4 | 1 | `title` |
| 武馆弟子 trainee | data | 7 | 0 | 0 | 6 | — |
| 李火狮 fist trainer | data | 11 | 0 | 6 | 1 | `skill_map` |

Time (4A, 2026-10-01, 11:58 → PR, about 95 minutes of agent wall clock):

| Work | Minutes | Per NPC? |
|---|---|---|
| Importer, its tests, zero-diff regeneration of Old Pine and Snow | ~10 | one-off |
| Loader rules: title, skill_map, attitudes, random values, `no_fight`, beast verbs | ~7 | one-off |
| What Snow's first NPCs broke: NPC-carried liquid state, rolled age on restore, technical-world restore, unstable NPC save order, bodies on walked routes, about 20 suites asserting "no Snow NPCs" | ~30 | one-off |
| New suite, docs, live smoke, full gate, review and its fixes | ~45 | one-off |
| Per NPC type: decide its findings, place its markers | ~1 each, 8 in all | yes |

Baseline for later regions: a data-only NPC type costs about one minute plus one decision per
finding; an NPC that needs a new generic rule pays for that rule once, and then the rule is free.

4B (2026-10-02) confirms the baseline: no 4B NPC needed a new rule; only the smith's shop did.

| NPC / vendor | Tier | Fields from LPC | Overrides | Findings decided | Spawn markers | Needed first |
|---|---|---|---|---|---|---|
| 农夫 farmer | data | 8 | 0 | 3 | 2 | — |
| 疯狗 crazy dog | data | 12 | 0 | 3 | 1 | — |
| 魏无极 teacher | data | 9 | 0 | 4 | 1 | — |
| 樵夫 woodcutter | data | 8 | 0 | 3 | 1 | — |
| 杜宽 post officer | data | 10 | 0 | 3 | 1 | — |
| 杨掌柜 herbalist | vendor service | goods | 1 skip | — | — | — |
| 王铁匠 smith | vendor service | — | goods by hand | — | — | vendor `price` |

Time (4B, agent wall clock, about 30 minutes to a full local test pass): nine rooms painted and
zoned ~10, the vendor price rule ~5, existing suites that counted Snow's rooms, NPCs and draws
~8, the new suite ~5, the smoke ~5; per NPC type ~1 minute, as in 4A.

4C (2026-10-02) added one NPC type and two generic rules, items on the floor and the hidden
passage; 柳绘心 needs ported skills first (the "Needed first" column).

| NPC | Tier | Fields from LPC | Overrides | Findings decided | Spawn markers | Needed first |
|---|---|---|---|---|---|---|
| 老鼠 rat | data | 8 | 0 | 0 | 6 | — |
| 柳绘心 girl | not placed | — | spawn_skip | — | — | fonxansword, chaos-steps |

Time (4C, agent wall clock, about 45 minutes from the merged 4B to a windowed smoke, after ~20 of
reading and planning): floor items (data, map, pickup, Continue) and the hidden passage ~12,
importer and data ~3, three scenes painted ~5, the new suite and the suites that count Snow
~20, the smoke ~7.

4D (2026-10-02) made talk and wandering data and added no NPC type: each talking NPC's cost was
its importer findings turning into `inquiry`/`chat_msg` (no new decisions but the five function
answers). Time (agent wall clock, about 35 minutes from the branch to a full local test pass,
after ~25 of reading and planning): ask and chat as data ~10, wandering (the walk on tiles) ~8,
room reset with NPC generations and the corpse check ~12, the new suite ~5.
