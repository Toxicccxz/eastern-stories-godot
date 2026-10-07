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
| guildhall (正厅) + daemon/class/fighter/guildhall.c | 於兰天武, 萧辟尘, 潘军禅 | the sign: looked at, and its action joins the 武者 (B) |
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

## Joining and teaching (B)

| LPC | Native |
|---|---|
| master.c attempt_apprentice(), do_swear() | apprentice rule `oath`; the 发誓恪守门规 button (TeacherPanel) swears 守门规 |
| champion.c attempt_apprentice(), do_accept("test") | apprentice rule `trial` (three blows with their lines); TeacherService.take_trial(), each blow WorldMapController.attack_player_outside_fight() |
| recruit.c run by an NPC | NpcApprenticeship.npc_recruit(): taken at once when the request waits on it, else an offer |
| champion.c assign_apprentice("弟子", 0) | family `privileges` 0: learn.c teaches only his own |
| std/char/master.c prevent_learn() | `f_master` (as 柳淳风) |
| daemon/skill celestial, celestrike, six-chaos-sword, pyrobat-steps, stormdance | skills.json `practice` (kee, force, sen and their lines) and `valid_learn` lines; the rules were already in SkillLearnPolicyRegistry |
| std/room/class_guild.c do_join() | the 樟木匾's `join_class` action (class fighter) |

- 七宝天岚舞's practice costs sen; its level line raises per (skill_improved()).
- 萧辟尘 does not map 七宝天岚舞, so he never dodges with it.

## C: the player's 天邪神功 and 杀气

| LPC | Port |
|---|---|
| daemon/class/fighter/celestial/powerup.c, powerfade.c | PowerupExertFunction, PowerfadeExertFunction (the faint in a fight: CharacterState.fall_unconscious()) |
| daemon/class/fighter/celestial/roar.c | RoarExertFunction over ExertContext.room (WorldMapController.exert_room()); its kill_ob()s are CombatTacticalExecutionResult.joiners, taken in by CombatEncounterResolution.admit() (CombatEncounter.admit(), escalate_to_lethal()) |
| cmds/std/exert.c | ExertService (weak-mode practice, as since #47); roar only offered in a fight |
| feature/attack.c init(), combatd.c start_berserk(), cmds/std/look.c | Berserk (core); WorldMapController._player_init(), _player_berserk(), _look_berserk(), _npc_berserk() (its fight_ob(): cause NPC_SPAR) |

- Nothing deferred: the region's three packages are done.
