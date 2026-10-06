# 水烟阁 content (region plan #4)

How 水烟阁 comes from `reference/es2/mudlib/d/waterfog/` and `daemon/class/fighter/`, and what the
LPC says that the code does not. Decisions are in [DECISIONS](DECISIONS.md). Package A places
every room and every NPC the rooms name; B makes 天邪派 joinable (萧辟尘's oath, 於兰天武's
three-blow test) and teaches its arts; C gives the player 天邪神功.

## Placed

| Room | LPC `set("objects")` | Native |
|---|---|---|
| sroad1-3 (青石官道) | 水烟阁武士 ×2 (sroad3) | mountain map: the road from Snow's sroad5 west, bending west under the maples to the stairs' foot |
| stair1-5 (白石阶梯), clifftop (半山亭) | 水烟阁司事, 天邪虎 (clifftop) | the stairs up the mountainside, the white stone pavilion on the cliff's edge |
| frontyard (水烟阁前) | — | the platform; the gate north into the pavilion map |
| wpath1-5, swordtomb (葬剑亭) | — | the west path along the gorge; 虹谷's stone tablet (wpath2) and the monolith (葬剑亭) are looked at |
| entrance (正门) | 水烟阁武士 ×2 | pavilion map; its valid_leave() keeps weapons out of the 正厅 (`exit_rules`) |
| guildhall (正厅) + daemon/class/fighter/guildhall.c | 於兰天武, 萧辟尘, 潘军禅 | the sign is looked at; join (武者) comes with B |
| westhall, easthall, weststair, eaststair, kitchen, storage, servroom | 仆役 ×2 (storage) | the halls; the stairs up from both 侧厅 |
| west_2f, east_2f, forehall (聆啸厅) | 红衣武士 ×2 each; 南危水, 陈坚石, 颜违 | upstairs map; the five stones on the terrace are props |

## Source anomalies

- d/waterfog/guildhall.c's `CLASS_D("fighter") + "champion"` (and master, executioner) lacks
  the slash (DECISIONS 水烟阁 A).
- elite_guard.c's accept_kill() is never called, and its return_home() runs `guard <dir>`
  (west_2f/east_2f's `waterfog_guard_dir`), a command the mudlib does not have.
- Every 天邪神功 NPC's chat_msg_combat has `exert_function("recover")`; celestial.c's
  exert_function_file() names daemon/class/fighter/celestial/recover, which does not exist, so
  it does nothing (npc.c calls the skill directly, without exert.c's fallback to /d/force).
- master.c's recruit_apprentice() adds to `apprentice_availavble` (misspelt; nothing reads it)
  and returns nothing.
- d/waterfog/npc/obj and d/waterfog/obj are byte-identical copies: one item each.
- npc/little_tiger.c (小天邪虎) is placed by no room.
- Room texts name places without rooms: 春秋水色斋 (聆啸厅 north), 虹台 (葬剑亭 south, wpath1/2),
  西侧厅's 阳台 (west).

## Deferred

- B: 萧辟尘's attempt_apprentice() and swear (owner: a fixed 发誓恪守门规 button), 於兰天武's
  accept test (owner: asked first), teaching both masters' skills, celestial learned by
  bellicosity, stormdance (practice costs sen), join (武者, class fighter).
- C: the player's 天邪神功 (powerup, powerfade and its faint in a fight, 天邪虎啸), 杀气's
  berserk for the player (owner: with a warning when it first becomes possible).
