# 乔阴县城 content (region plan #9)

How the region comes from `reference/es2/mudlib/d/choyin/`, `d/jail/`, `daemon/class/scholar/`
(步玄派) and `daemon/class/beggar/` (花紫会), and what the LPC says that the code does not.
Decisions are in [DECISIONS](DECISIONS.md) (「乔阴 A」 holds the plan, the owner's answers and the
defaults). Package A draws every map and places the people with the arts they fight with; B the
town's secrets and 姑射山 (the lion, the hole under the 树王坟, the ghosts, the vines, the 缚仙绳,
the 云台 and the 丹炉, the 寒谷's orchid, the hermit's books, the 荷包); C 步玄派 (the 桃林's poem
maze, 骆云舟's teaching, the player's arts and 玄羽乱舞); D 花紫会, stealing and the 县衙.

## Placed (A)

61 of the 62 room files, on fourteen maps (the 石室, stonehole.c, has no way in and is not drawn).
Rooms that only a verb or a maze reaches are drawn now; their ways in come with B, C and D.

| Map | Rooms | People (A) | Ways |
|---|---|---|---|
| choyin.town (乔阴县城) | n_gate, n_street1–3, nw_street, w_street1–4, tree_tomb, e_street1, e_gate, s_street1–5, crossroad, court1, s_gate, dragon_temple, sw_road1, bridge1–5, entrance, taolin | 守城官兵 ×6, 县城官兵 ×2, 卖饼大叔, 陆得财, 卖包子的 ×2, 汤掌柜, 武官, 卖糖葫芦的, 衙役 ×4, 带刀侍卫 ×2, 乾瘪老太婆, 游客 ×8, 书生 ×2, 官家小姐, 丫鬟 ×2, 骆云舟; 风泉剑灵 waits absent | west from the 北门 to 泓水南岸; the 东城门 and 南门 out; stairs up in the 福林楼 and the 火龙将军庙; east from the 曼雩台 into the 桃林 only with marks/书生 |
| choyin.yamen_compound (县府衙门) | yamen_yard, yamen, yamen_iner | 带刀侍卫 ×6, 程不平 | south out to the 衙门口 (court1.c has no way in: D) |
| choyin.temple_altar, hotel_2f, hotel_3f | altar; hotel2; hotel3 | 妇人 (功德箱 on the floor); 贵公子, 家丁 ×3; 酒楼守卫 ×3 | stairs |
| choyin.tree_hollow (树洞) | tomb1–3 | — (朦胧鬼影 and the 桃木箱: B) | up to the 树王坟 (the way down: B, plan Q2) |
| choyin.lion_cave (神秘洞穴) | lionroom | — (护草神兽: B) | none (the lift and the 忘忧草: B) |
| choyin.east (乔阴东郊) | solidpath1–2, cloudpool, rockpath1–2, rockyu, fence, club, yard, tongbhill | 黑冠巨蟒 ×4, 采药老者 | west to the 东城门; the 柴门 shut |
| choyin.furnace (丹炉) | stove | — (仙丹: B) | out to 桐柏山 (the way in from the 云台: B) |
| choyin.guye (姑射山) | spath, rockroad, guyehill | — | north to the 南门 |
| choyin.crown, cliff_cave, summit, valley | craneroom; halfhole; platform; hollow, hollow1–3 | 仙鹤 ×4; —; 紫衣童子 ×2; — | down to the 绝壁 (crown, cliff_cave); none yet (B) |

Not placed in A: the 孤魂野鬼 and 朦胧鬼影 (unseen, plan Q3: B), the 护草神兽 (B), the 巡捕 (D:
they draw their names, a placed NPC cannot yet, and patrol), 北冥大鹏 (roc.c: no room places it),
d/jail/cityguard.c (a copy of the 守城官兵 no room places), daemon/class/beggar/wineskin.c.

## LPC → native (A)

| LPC | Native |
|---|---|
| u/cloud/sunhill/road1.c east, n_gate.c west | portals `sunhill.road1.east` / `choyin.n_gate.west` |
| n_gate.c `// "north" : "/d/oldpine/spath4"`, spath4.c `// "south"` | nothing: both ends commented out (owner: as ES2) |
| yamen_yard.c south (court1.c has no north) | portal `choyin.yamen_yard.south` on the 衙门's own map: out only |
| entrance.c valid_leave() | exit rule `choyin.entrance.taolin` (`no_mark` 书生); its taolin_steps = 3: C |
| s_street1.c resource/water, do_drink() | services `choyin.s_street1.well` (water) and `choyin.s_street1.drink` (act 喝水: `thirsty`, then the cup's line and a `water` 20 step; full: its refusal) |
| cloudpool.c resource/water | service `choyin.cloudpool.water` (no drink command in that room) |
| w_street1.c, tree_tomb.c, fence.c, club.c, guyehill.c, platform.c, hollow3.c item_desc | look landmarks; the statue's lost 「□」 reads 「举」 (默认, uncertain) |
| yamen.c / yamen_yard.c, fence.c, club.c create_door() | doors 铜钉大门, 柴门 ×2, shut |
| vendors' `(: do_vendor_list :)` topics | inquiry rule `vendor_list`: the goods and price_string() prices after ask.c's line (the English ids `list` printed are left out) |
| crone.c relay_ask() | NpcTalk `relay_ask` (owner: said as meant): her ? (an emote, nothing), the deaf line, the basket |
| cake_vendor.c rank_info/self 小的 | `rank_info.self` (NpcDefinition.query_self()) |
| guard.c accept_kill(), help_hotel_guard() | dealings `accept_kill` (NpcAcceptKill; owner: as meant): the others of its kind here say 干什么？！ and join, the report, vendetta/authority, a native hint |
| d/waterfog/npc/elite_guard.c accept_kill() | the same (owner): his line, his powerup, the other guard joins, vendetta/waterfog_guard (vendetta_mark: every 红衣武士 attacks on sight, a killer of one is marked too), a hint |
| oldman.c create() inside `if (!restore())` | its fields in set (his save file is not ported: a new one at each reset starts fresh) |
| oldman.c init(), greeting() | greeting rules: carries tomatoo → 我给你的山药蛋好吃吗??; else the long line (its doubled 说道 one), give the 山药蛋, set_temp choyin/山药蛋 |
| oldman.c receive_damage() | NpcHooks `receive_damage` (CombatNpcChat.hurt() after a blow, in the fight's log): the hurt line above max_kee / 5 and random_move() on random(kee) < damage; a pill below 20 gin, kee or sen (nine, counted anew at his room's reset and when he wakes) |
| oldman.c kill_ob() | NpcHooks `kill_ob`: the attack shows kill.c's line and his ghost story ($N 你; the full-width ＄N reads 你) instead of a fight; WorldMapNpcs.vanish(): no corpse, his room makes him anew |
| oldman.c revive(), reset() | NpcHooks `revive`: combat_exp + /3 + 10, the pills, a third of new potential each to apply attack, dodge, damage (save() not ported) |
| oldman.c defeated_enemy() (winner_reward() from damage.c unconcious()) | NpcHooks `defeated_enemy`: his line after the fight when the player falls with him the last to hurt them |
| oldman.c accept_fight() | an accept rule; his refusal while he fights someone else cannot happen in single player |
| windspring.c owner_is_killed() (chard.c make_corpse()) | item `owner_is_killed`: the sword is destroyed before the corpse takes the rest, the summoned spawn `choyin.town.entrance.sword_soul` comes in with its lines (after the fight) |
| sword_soul.c chant(), chant_sword() | NpcHooks `chant` (NpcAmbience CHANT call_out): the four sayings 20 s apart, +100000 combat_exp with the fourth, again 60 s later; leaving the map drops it (DECISIONS 茅山 B) |
| scholar/mysterrier/hasten.c (骆云舟's fight chat `perform move.hasten`) | HastenPerform; an NPC chat special's attacks run through CombatSpecialAttackSource (fight(), select_opponent()) and are told and judged as the player's perform's |
| spicyclaw.c hit_ob() | skills.json `hit_wound` (MartialHitWound; CombatHitPolicyStatus MARTIAL_WOUND): the bone line after the force hit's |
| d/choyin/obj/book.c set_name(names[random(sizeof(names))]) | item `name_pick`: a named form per name in the catalog (`<id>#name=<n>`), drawn as an NPC's loadout is made, saved by its ID |
| silver_clasp.c inherit HEAD + F_DAGGER | worn on the head only (armor in set, weapon dropped) |
| sword_soul.c apply/armor_vs_force | NPC `apply` takes armor_vs_force |

## Not done in A (and where it goes)

- B: lift (w_street1.c) and the 神秘洞穴, the lion's die() and the 忘忧草's smell; the hole into
  the 树王坟 (plan Q2) and its 朦胧鬼影, the 桃木箱 for the 武官 (白杨经); the ghosts unseen (Q3);
  climb, hold (random(dodge) < 30 falls into the 寒谷), the 缚仙绳's tie (only where a 仙鹤 is),
  the 云台's flag, the 丹炉's 仙丹, the 寒谷's orchid to 晚月庄; the hermit's books (scratch,
  pray and dancing failing there); 游晋 and the 荷包; the cranes' fights (a beast without verbs:
  beast.c's default action has two unfilled %s; `fight_deferred` until then); stove.c's flame
  told to 桐柏山.
- C: 骆云舟's attempt_apprentice() (marks 书生 and 桃林), the 桃林's notes and ways, his teaching,
  the player's 步玄七诀 (practice, valid_learn), 小步玄剑, 步玄心法, 玄羽乱舞 on the battle panel.
- D: 陆得财's attempt_apprentice() (can_afford(100)), his teaching, 油流麻香手 and 伏蛟功 for the
  player, steal, the 巡捕's patrol and arrest, 程不平's boards (plan Q1).

## Source anomalies

- n_gate.c's north and oldpine/spath4.c's south are both commented out; the 1995 map and the
  newbie help still put 乔阴 south of the pine forest.
- guard.c's and elite_guard.c's accept_kill(), crone.c's relay_ask() are called by no mudlib
  code (owner: run as meant).
- hasten.c tests the void COMBAT_D->fight(): 但是$N找不到机会出手！ after every round.
- shortsong-blade.c's parry lines are never asked (combatd.c asks parry.c's).
- fall-steps.c's effective_level(), learn_bonus() and the like are read by nothing.
- oldman.c's chat_msg_coombat is misspelt (never said); his greeting says 说道 twice; his ghost
  story has a full-width ＄N; set("short") changes are not shown.
- girl.c deletes 游晋 after return (B: given once, 默认).
- stove.c's no-magic is misspelt (magic works there).
- e_gate.c's arch says 「北门」.
- red_guay.c in obj/ lost a character (红龟□); the crone sells npc/obj's 红龟.
- sergeant.c sets pursuer (following who flees is not modelled yet).
