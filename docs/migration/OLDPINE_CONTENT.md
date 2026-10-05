# Old Pine content (region plan #1)

How Old Pine's last rooms and NPCs come from `reference/es2/mudlib/d/oldpine/`, what the LPC says
that the code does not, and what the package cost. Decisions are in [DECISIONS](DECISIONS.md);
the data format in [CONTENT_DATA_FORMAT](CONTENT_DATA_FORMAT.md).

## Placed (remainder A)

| Room | LPC `set("objects")` / rule | Native |
|---|---|---|
| keep1 | 土匪喽罗 ×4 | outdoor map, east of pine2 |
| keep2 | 土匪喽罗 ×2, 土匪首领; valid_leave() shuts the gate and new()s five 土匪喽罗; pipe_notify(), reset() open it | the gate is a rule's door; five summoned guards (`traps[]`) |
| keep3 | 土匪首领 ×3, 常老大 (apply/defense 60, 竹管) | the hall |
| secrectpath1, path3 | — | cave map, north of the passage; path3 `climb up` the stone |
| stone | 金银花蛇 | its own map; `climb down` to cave1; the snake waits for remainder B (蛇毒) |
| cave1-4 | random exits | one fixed maze on the caves map |
| cave5 | skeleton; do_bury(), look_wall() | the wall is the bury landmark; `eastdown` to the waterfall |
| cliff2 | climb up / down | its own map, between cliffdown and epath3 |
| epath3 | 疯老头子 | berserk, three necromancy bolts |
| pine7 | 狼狗 | aggressive |
| tree1 | 黑衣人 | waits for remainder B (飞刀, 化尸粉 are combined items) |
| tree2 | 蝴蝶 ×6 | peaceful |

## Source anomalies

- `fat_bandit.c` calls `call_for_help()` only from `chat_msg_combat` and sets no
  `chat_chance_combat`, so 土匪老大 (`bandit_chief.c`) never comes: it is not placed.
- `bandit_leader.c` and `bandit_chief.c` say their 武功 "is not done yet" and use apply/attack
  and apply/dodge instead; 土匪首领 talks of 毒爪 he does not have.
- `passage.c` comments out its 疯老头子 and `epath3.c` its two 金银花蛇; `path3.c` still
  describes the snake on the stone.
- `wolf_dog.c` sets kee and eff_kee 200 over beast.c's max_kee 50 (DECISIONS), and
  `chat_msg_combat` without `chat_chance_combat` (never said).
- `cliffdown.c`'s `climb down` says 爬了上去; the file's header names it cliffside.c.
- `cave5.c` drops through to the fall after the paper (no `return`), and `look_wall()` is
  reachable only through `item_desc`. `parrybook.c` comments out F_UNIQUE (its `replica_ob` is
  never read). The keep's `fur_coat.c` is a 狼皮披风 whose header says leather.c.
- keep2.c's trap adds five guards each time the gate shuts; nothing removes the ones from before.

## Cost (calibration for the next regions)

Agent wall clock, 2026-10-04. Region census and ROADMAP: 15:32–15:45 (13 minutes), then waiting
for the owner's answer. Remainder A: 16:37 to a full local test pass at about 17:45 (about 70
minutes), before the full gate and the PR:

| Work | Minutes | Per NPC? |
|---|---|---|
| Reading the LPC and the runtime (three parallel read-only agents) | ~12 | one-off |
| Importer run, findings decided, bellicosity field | ~5 | — |
| Rules: rule doors, room traps, summoned spawns, bury, berserk, netherbolt, 吹奏 | ~15 | one-off |
| world.json and four scenes painted by script | ~8 | — |
| The new suite; 30 old suites that pinned Old Pine's counts, routes and draws | ~20 | one-off |
| Windowed walk (twice) and the fresh-context review's fixes | ~10 | one-off |
| Per data-only NPC type (findings, markers) | ~1 each | yes |

The expensive part was not the NPCs but what they first needed (a trap, a summoned spawn, berserk)
and the old suites that hard-code Old Pine's NPC and item counts.
