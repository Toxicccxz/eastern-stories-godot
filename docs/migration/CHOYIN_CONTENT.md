# 乔阴县城 content (region plan #9)

How the region comes from `reference/es2/mudlib/d/choyin/`, `d/jail/`, `daemon/class/scholar/`
(步玄派) and `daemon/class/beggar/` (花紫会), and what the LPC says that the code does not.
Decisions are in [DECISIONS](DECISIONS.md) (「乔阴 A」 holds the plan, the owner's answers and the
defaults; 「乔阴 B」 its own). Package A draws every map and places the people with the arts they
fight with; B the town's secrets and 姑射山 (the lion, the hole under the 树王坟, the ghosts, the
vines, the 缚仙绳, the 云台 and the 丹炉, the 寒谷's orchid, the hermit's books, the 荷包); C 步玄派
(the 桃林's poem maze, 骆云舟's teaching, the player's arts and 玄羽乱舞); D 花紫会, stealing and the
县衙.

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
| vendors' `(: do_vendor_list :)` topics | inquiry rule `vendor_list` (as the code means: ES2 printed nothing, see DECISIONS): the goods and price_string() prices after ask.c's line (the English ids `list` printed are left out) |
| youngman.c inquiry `trouble` | topic 心事 (an English topic would show in the list); B's 荷包 removes it |
| crone.c relay_ask() | NpcTalk `relay_ask` (owner: said as meant): her ? (an emote, nothing), the deaf line (its (list) dropped), the basket |
| cake_vendor.c rank_info/self 小的 | `rank_info.self` (NpcDefinition.query_self()) |
| guard.c accept_kill(), help_hotel_guard() | dealings `accept_kill` (NpcAcceptKill; owner: as meant): the others of its kind here say 干什么？！ and join, the report, vendetta/authority, a native hint |
| d/waterfog/npc/elite_guard.c accept_kill() | the same (owner): his line, his powerup, the other guard joins, vendetta/waterfog_guard (vendetta_mark: every 红衣武士 attacks on sight, a killer of one is marked too), a hint |
| oldman.c create() inside `if (!restore())` | its fields in set (his save file is not ported: a new one at each reset starts fresh) |
| oldman.c init(), greeting() | greeting rules: carries tomatoo → 我给你的山药蛋好吃吗??; else the long line (its doubled 说道 one), give the 山药蛋, set_temp choyin/山药蛋 |
| oldman.c receive_damage() | NpcHooks `receive_damage` (CombatNpcChat.hurt() inside each blow, a perform's too, before the fight is judged: a spar ends after it; a spell's harm checks the pill only, its kee unreported): the hurt line above max_kee / 5 and random_move() on random(kee) < damage; a pill below 20 gin, kee or sen (nine, counted anew at his room's reset and when he wakes) |
| oldman.c kill_ob() | NpcHooks `kill_ob`: the attack shows kill.c's line and his ghost story ($N 你; the full-width ＄N reads 你; the fake room's exits and 黑无常 without English) instead of a fight; WorldMapNpcs.vanish(): no corpse, his room makes him anew |
| oldman.c revive(), reset() | NpcHooks `revive`: combat_exp + /3 + 10, the pills, a third of new potential each to apply attack, dodge, damage (save() not ported) |
| oldman.c defeated_enemy() (winner_reward() from damage.c unconcious()) | NpcHooks `defeated_enemy`: his line after the fight when the player falls with him the last to hurt them |
| oldman.c accept_fight() | an accept rule; his refusal while he fights someone else cannot happen in single player |
| windspring.c owner_is_killed() (chard.c make_corpse()) | item `owner_is_killed` (an NPC's or the player's death in a fight): the sword is destroyed before the corpse takes the rest, the summoned spawn `choyin.town.entrance.sword_soul` comes in with its lines (after the fight); while it stands, or off the town map, the sword stays with the dead (默认) |
| sword_soul.c chant(), chant_sword() | NpcHooks `chant` (NpcAmbience CHANT call_out): the four sayings 20 s apart, +100000 combat_exp with the fourth, again 60 s later; leaving the map drops it (DECISIONS 茅山 B) |
| scholar/mysterrier/hasten.c (骆云舟's fight chat `perform move.hasten`) | HastenPerform; an NPC chat special's attacks run through CombatSpecialAttackSource (fight(), select_opponent()) and are told and judged as the player's perform's |
| spicyclaw.c hit_ob() | skills.json `hit_wound` (MartialHitWound; CombatHitPolicyStatus MARTIAL_WOUND): the bone line after the force hit's |
| d/choyin/obj/book.c set_name(names[random(sizeof(names))]) | item `name_pick`: a named form per name in the catalog (`<id>#name=<n>`), drawn as an NPC's loadout is made, saved by its ID |
| silver_clasp.c inherit HEAD + F_DAGGER | worn on the head only (armor in set, weapon dropped) |
| sword_soul.c apply/armor_vs_force | NPC `apply` takes armor_vs_force |

## Placed (B)

| Map | What B adds | Ways |
|---|---|---|
| choyin.town | 孤魂野鬼 at the 北门 and the 东城门 (unseen, wandering) | the 石狮's 举 down to the 神秘洞穴; the stump's hole (爬下去) to the hollow |
| choyin.lion_cave | 护草神兽 (its reach is the cave), the 忘忧草 in its corpse | 闻忘忧草 to 振远镖局 (u/cloud/biaoju); 放弃: the Inn |
| choyin.tree_hollow | 朦胧鬼影 ×3 (unseen), the 桃木箱 in tomb3 | up the 洞壁 (A) |
| choyin.east | the 草堂's books (拿书), put back on leaving; pray and dancing refused | — |
| choyin.guye | — | 爬树 to the 树冠; 抓住藤蔓: the 寒谷 or the 山洞 |
| choyin.crown, cliff_cave | the cranes fought; the 缚仙绳 in the 山洞 | 缚 on a 仙鹤 to the 云台 |
| choyin.summit, furnace | five 仙丹 | 碰云幡 down to the 丹炉, out to 桐柏山 (A) |
| choyin.valley | the 寒谷幽兰 | 插幽兰 at the vase to 晚月庄's bamboo grove |

People elsewhere: 武官 (the chest, the 白杨经), 官家小姐 (the 荷包), 贵公子 (takes it), 陈剑秋 in
绮云镇 (his letter for 陈天星).

## LPC → native (B)

| LPC | Native |
|---|---|
| w_street1.c do_lift(), check_trigger(), reset() | landmark policy `lift` (LiftLandmarkPolicy): each lift told and counted since the reset; count + str / 5 reaching 10 opens portal `choyin.w_street1.lift`; the lines told to the faller (默认) |
| lionroom.c do_smell() | act service `choyin.lionroom.smell` (洞穴 · 闻忘忧草): carrying `grass`, the wind and cloud.biaoju.wind_arrival; else 你身上没有忘忧草啊。 (braces fixed) |
| 放弃 in the 神秘洞穴 (plan default, 绝地 precedent) | landmark `choyin.lionroom.landmark.dark`: portal `choyin.lionroom.give_up` to the Inn |
| lion.c die() | NpcHooks `die_carries` (WorldMapCombatLifecycle._die_carries): the 忘忧草 made into it before the corpse; its master form when the player struck last |
| grass.c / letter.c set("master_id") | item `master`: the catalog's master form `<id>#master` is the player's (NpcObjectRule `item_master`, `gives_master`) |
| b_header.c accept_object() | first rule: a 振远镖局 member's own 忘忧草: his four lines and the letter (the giver's); someone else's: 这不是你得到的吧 (handed back, modern fixes) |
| tree_tomb.c (no way down: plan Q2) | landmark hole, policy portal `choyin.tree_tomb.down` (爬下去, a native line) |
| ghost.c, shadow.c is_ghost(); char.c visible(); combatd.c fight(); chard.c make_corpse() | NpcHooks `ghost`: body hidden and passed through, not picked (WorldCharacterBody2D, select_npc()) nor chosen as the battle target (CombatEncounterScheduler.can_target()); CombatSliceContentProfile.sees() → fight()'s perception roll; BattleNarrator's 你看不见对手，无从下手。 (owner); DeathContext ghost branch: no corpse, its things fall (CombatSliceLifecycleAdapter skips the corpse move) |
| shadow.c set_temp("apply/blade", 80) | NPC `apply` takes `blade` (query_skill()) |
| sergeant.c accept_object() | accept_object rule: `peach chest` unless chest_found; three says, give.c's line, the 白杨经 (magic to 20); `forgets` rumors, 箱子, 桃木箱子 |
| girl.c ask_youngman() | inquiry rule 游晋: say, the 荷包 (give.c's line), `forgets` 游晋 (默认: once) |
| youngman.c accept_object() | accept_object rule `###silk bag###`: two lines, his say, `forgets` 心事 (jump prints nothing) |
| club.c do_scratch() | act service `choyin.club.scratch` (书卷 · 拿书): the line, `give_one_of` book1, book1, book2 (random(3)), set_temp choyin/书 |
| book1.c, book2.c set_name(names[random()]) | `name_pick`; place_new_floor_item() draws the name |
| club.c valid_leave() | exit_rules `choyin.club.east_books` / `west_books`: `takes_back` `items` (owner: only the hermit's books, without the flag) |
| club.c do_pray(), do_dance() | zone `refuses` pray and dancing (RoomActDefinition.command of the 玛瑙手镯 and the 舞曲谱) |
| guyehill.c do_climb() | landmark tree, policy portal `choyin.guyehill.climb` (爬树) |
| guyehill.c do_hold() | landmark vine, policy vine with `below` 30: `hold_fall` to the 寒谷 or `hold_climb` to the 山洞 |
| goldenrope.c do_tie() | item act 缚 (command tie): `present` a 仙鹤: the line, 50 sen (asked first when it knocks out), the 云台; else 你要缚何物? |
| platform.c do_touch(), close_passage(), thounder() | landmark flag, policy portal `choyin.platform.touch` (碰云幡): its two lines, the 丹炉 |
| tablet.c do_eat() | ItemApplyFunctions `tablet` (吃): the line, receive_heal 5 gin, 30 kee, 5 sen, one gone |
| hollow3.c do_interject() | landmark vase, policy portal `choyin.hollow3.interject` (插幽兰) to latemoon.bamboo.dance_arrival |
| crane.c (no verbs), beast.c default_actions | BeastCombatActionDefinitions.default_action(): $N攻击$n的$l (owner) |
| taoist/sword.c hit_ob() | item `ghost_bane` (WeaponGhostBane, CombatHitPolicyStatus.GHOST_BANE) |

## Not done (and where it goes)

- C: 骆云舟's attempt_apprentice() (marks 书生 and 桃林), the 桃林's notes and ways, his teaching,
  the player's 步玄七诀 (practice, valid_learn), 小步玄剑, 步玄心法, 玄羽乱舞 on the battle panel.
- D: 陆得财's attempt_apprentice() (can_afford(100)), his teaching, 油流麻香手 and 伏蛟功 for the
  player, steal, the 巡捕's patrol and arrest, 程不平's boards (plan Q1).
- #12: 陈天星 takes 陈剑秋's letter (reminder test in choyin_secrets_test).
- #13: the 孤魂野鬼's 布条 (a ghost sees ghosts).

## Source anomalies

- n_gate.c's north and oldpine/spath4.c's south are both commented out; the 1995 map and the
  newbie help still put 乔阴 south of the pine forest.
- guard.c's and elite_guard.c's accept_kill(), crone.c's relay_ask() are called by no mudlib
  code (owner: run as meant).
- The vendors' do_vendor_list() topics print nothing (dbase.c passes the vendor as `arg`).
- hasten.c tests the void COMBAT_D->fight(): 但是$N找不到机会出手！ after every round.
- shortsong-blade.c's parry lines are never asked (combatd.c asks parry.c's).
- fall-steps.c's effective_level(), learn_bonus() and the like are read by nothing.
- oldman.c's chat_msg_coombat is misspelt (never said); his greeting says 说道 twice; his ghost
  story has a full-width ＄N; set("short") changes are not shown.
- girl.c deletes 游晋 after return (B: given once, 默认).
- lionroom.c's do_smell() and goldenrope.c's do_tie() lack braces: the move happens for anything
  (the first item of any pack; any word), the line only for the grass or the crane.
- club.c's valid_leave() clears set_temp("choyin/\112\151") (octal for another flag): choyin/书
  stays, so every later `book` is taken, and one carried without it loops forever.
- hollow3.c's interject asks for no orchid; hollow1.c's south leads into itself.
- beast.c's default action for a beast without verbs (crane.c) keeps two %s nobody fills.
- platform.c's thunder strikes only one still on the 云台 15 s after the flag.
- stove.c tells 桐柏山 of the flame in create(), loaded only by the one walking in from the 云台.
- stove.c's no-magic is misspelt (magic works there).
- e_gate.c's arch says 「北门」.
- red_guay.c in obj/ lost a character (红龟□); the crone sells npc/obj's 红龟.
- sergeant.c sets pursuer (following who flees is not modelled yet).
