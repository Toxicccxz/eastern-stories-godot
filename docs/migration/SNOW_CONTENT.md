# Snow content (Package 4)

How Snow's rooms, NPCs and shops come from `reference/es2/mudlib/d/snow/`, what the LPC says that
the code does not, and what each NPC cost. The data format and the importer are described in
[CONTENT_DATA_FORMAT](CONTENT_DATA_FORMAT.md); decisions are in [DECISIONS](DECISIONS.md).

## Placed so far (4A)

| Room | LPC `set("objects")` | Native |
|---|---|---|
| inn | 旅客 ×2, 店小二 | travellers placed; the waiter stays the Inn's vendor service until 4E |
| eroad2 | 野狗 ×2 | placed |
| temple | 庙祝, 桃符纸 ×2, 功德箱 | keeper placed; the items lie on the floor in 4C |
| mstreet2 | 醉汉, 收破烂的 | placed |
| bank | 安惜迩 | the bank service until 4E |
| school1 | 刘安禄 | placed |
| school2 | 武馆弟子 ×6, 李火狮 | placed |
| schoolhall | 柳淳风 (`CLASS_D("swordsman")`) | the teacher service |
| square | 旅客 (飞刀) ×3 | waits for combined throwing weapons |

## Source anomalies

- `square.c` comments out its four 苦力; only the 飞刀 travellers remain. `hockshop.c` comments
  out 陆得财 (the beggar master).
- `herbshop1.c` (药铺密室) has no exit leading into it anywhere in the mudlib.
- `npc/herbalist.c` `heal_me()` stops after the 95% case; below that the NPC gives the default
  answer.
- `obj/drug/snake_drug.c` sets `base_weiht` (typo): the combined item has no base weight.
- `d/snow/npc/obj/*.c` are byte-identical copies of `d/snow/obj/*.c`, except `old_book.c`; the
  importer merges identical copies into one item.

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
