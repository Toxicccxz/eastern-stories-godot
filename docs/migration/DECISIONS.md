# Migration Decisions

## Pacing knobs and 卧龙岗's second (2026-10-06)

Measured at ES2's pace on the native game (real session, combat scheduler and heal_up cadence; a
new character's attributes are all 30, as logind.c sets them): 打坐 from max_force 0 to 50 takes
6.4 h of play (11.6 h at con 20), almost all of it waiting for kee; combat_exp 0 to 1001 takes
some 30-60 h: sparring the six 武馆弟子 gives 120-140 an hour up to about 150, then nothing in the
game gives more than about 30 an hour (combatd.c gives exp only to the weaker side of a blow, a kill
gives none, and a spar is two blows and a minute's rest); the 40 and 50 s tasks lie 9-17 ES2 rooms
from 朱鸿雪, 14-25 s on foot plus the fight.
- **Owner: three knobs in `common/pacing.json`**, integers; left out, each is ES2's pace
  (PacingDefinition). No ported formula changed:
  - `player_exp_gain` 3: every 1 combat_exp do_attack() gives the player (a dodge, a parry, a hit
    either way) is 3, and so is a hit's 1 potential (still only up to 100 unspent). NPCs, quest
    rewards and skill improvement are unchanged.
  - `player_recovery_gain` 3: heal_up() restores three times as much to the player (gin, kee,
    sen, the effective repair, atman, force, mana); the tick's timing and its food and water are
    ES2's. NPCs are unchanged.
  - `quest_time_percent` 150: 朱鸿雪 gives one and a half times god.c's time (40 s becomes 60 s)
    and says so; the save keeps the time she gave.
  - Suites that pin ES2's own numbers end to end run with the knobs at ES2's pace
    (`tests/support/es2_pacing.gd`); `tests/core/pacing_knobs_test.gd` shows a gain of 1 is ES2.
- **Owner: 卧龙岗 lets a newcomer walk through.** gangster.c's greeting comes a second after the
  player arrives (init(): call_out("greeting", 1)), time for one command out of the room, and go.c
  leaves a fight without a roll, so in ES2 a newcomer walked past; natively the robbers attacked the
  moment the player came into reach and killed a newcomer in 4-5 rounds. Now a robber attacks a
  player still in its reach `toll_attack_delay_ms` after the player came into it: 2000, because
  crossing the native ridge takes 1.2-1.5 s and the way to 南坡 passes within 70 px of the second
  robber (about 1 s in his reach; at 1000 every route tried was caught). Walking on passes both;
  stopping, or walking into one, does not, and the other robber in reach then joins (both
  greetings come from the same arrival). **Deviation:** ES2's greeting kill_ob()s a passer-by who
  has gone, so the robber attacks at once next time; here walking past makes no grudge, and the way
  back has the same time. A fight (stopping in reach, a refused toll, 攻击 or 切磋) still makes one
  until the robber is made anew.

## Modern fixes: ES2 behaviour that reads as a bug (2026-10-06)

Owner: the game is for today's players (AGENTS.md, Deviations). ES2's behaviour, then ours:
- give.c's refusal 你只能把东西送给其他玩家操纵的人物。 speaks of other players: the player reads
  X没有收下。 (the thing stays with them, as since 4E).
- b_header.c's accept_object() returns 1 in every branch, so 陈剑秋 kept what he refused (money
  destructed): his 你拿什么东西唬我？ and 这不是你得到的吧 hand the gift back. He keeps his own
  忘忧草 from an outsider (你是何人？为什么有我的忘忧草？).
- vendor.c lists goods priced 0 (the weapon shop's 飞镖, 0两黄金) that buy.c refuses: the shop
  does not list them.
- steal.c tells the robbed player nothing: the player reads 你忽然觉得身上一轻，X不见了！ (HIR), not
  who took it; one robbed while unconscious reads 你昏迷不醒的时候，身上的X被人拿走了！ on waking.
- snake_drug.c lowers the poison by one per dose against a bite's 20, so a dose seemed to do
  nothing: after each dose the player reads what is left, and that each bout wears one off too.
- Kept: study.c's 你是个文盲，先学学读书识字(literate)吧。 already tells an illiterate reader of 说文解字
  what to do.
- With 3C (#60): the quest reward's cap on unspent potential only stops the gain, and a surrender
  before the first blow is refused by a standing killer.

## 绮云镇 3C: 朱鸿雪's quests, killer_reward() for the player, surrender (2026-10-06)

- **The quest command is 朱鸿雪's** (god.c init(): `quest_giver`): beside her, 任务 runs
  give_quest(); when it returns 0 (combat_exp 1000 or less, a task still running) quest.c's lines
  follow, as the command goes on to cmds/usr/quest.c. quest.c's lines also stand on the 角色 page.
  The 15 levels and 220 qlist entries are `common/quests.json` (qlist10000, 13000 and 17000.c
  comment out 11 entries each; they are left out); the player keeps a copy of the task.
- **Owner: she draws only targets the game has.** The draw is among the tier's entries whose
  target is an NPC placed somewhere that can be fought (by name, as killer_reward() compares
  name(1)); a tier with none gives way to the next lower one. With all 84 names in the game it is
  god.c's own draw. `tests/fixtures/quest_targets.json` lists the 41 available and 43 missing
  names; a region package that places one re-records it (UPDATE_QUEST_TARGETS=1).
- **Owner: the task's time runs on play time** (fights, map changes and lying unconscious
  included); pause and a closed game stop it, and the save keeps the time left. In ES2 task_time
  is time() + the quest's seconds, and time() also runs while the player is offline.
- **killer_reward() for a player who kills an NPC**: MKS + 1; the task done when the victim's name
  is its target and its time has not run out (the exp, potential and score rolls, quest_factor,
  unspent potential capped at 100, a negative score's reward negated, tfinished); bellicosity + 1;
  the victim's vendetta_mark marks the killer; killing one's own master (the generation above)
  gives title 普通百姓 and no family, master or rank (the class stays).
- **Owner: killing one's own master counts as betraying the family.** ES2 lowers betrayer by
  one, so the kill washed out a betrayal (or banked one for later), and an expelled player joins
  any family without a betrayal: killing the master was the cheapest way to change families.
  Here it costs what recruit.c's betrayal costs (betrayer + 1, score 0), and the player reads
  why (你亲手杀了自己的师父，被逐出了…！ and the cost; ES2 says nothing).
- **Owner: no ES2 quirk that reads as a bug.** The quest reward's cap on unspent potential (100)
  only stops the gain: ES2 lowered a player above 100. A surrender before the first blow (no
  last_opponent yet) is refused when a standing enemy is killing the surrenderer: ES2 took it, and
  the score, while the killer fought on.
- **vendetta**: an NPC with a vendetta_mark (garrison.c: authority) attacks a player who holds
  vendetta/<mark> on sight (attack.c init(), start_vendetta()); a death with a killer clears it.
  garrison.c's `pursuer` (following who flees) is not ported.
- **Owner: score is shown**: the 角色 page shows score.c's 杀气, 综合评价 and 总共杀过 N 个人.
  Deviation: its 其中有 N 个是其他玩家 is left out (there are no other players).
- **Owner: surrender.c for the player**: 投降 on the battle panel beside 逃跑. A last opponent
  that stands and is killing the player refuses (the 求饶 line); otherwise every enemy that is
  not killing the player stops, the player stops fighting them all and loses 50 score (to 0).
  It waits while the player is busy, as exert and perform (surrender.c has no busy check). In a
  fight to the death whose killers all lie down, an accepted surrender ends the fight as 逃跑
  does: ES2 would go on when a killer came to, which the port's fight cannot wait for. NPCs that
  surrender lose score the same way (their score lives on the definition, so nothing changes).

## 绮云镇 3B: joining 振远镖局 (2026-10-05)

- **Changing family is ported** (the Snow entry's deferred betrayal): an NPC master recruits
  through recruit.c, so a member of another family who is taken says 你决定背叛师门, gets score 0
  and betrayer + 1, and the new family, master, title, class and entry time replace the old ones.
  A member of the same family is recruited as anyone else (new master, generation, title,
  class and entry time), without the betrayal's lines and penalties.
- **Owner: betrayal asks first** (a UI deviation). In a master's panel, 拜师 by a member of
  another family shows what recruit.c will do (score 0, the new number of betrayals and
  master.c's limit, the new family; skills kept) and needs 确定改投; apprentice.c runs at once
  (only its help warns). The rule itself is unchanged.
- **The player's score** (综合评价) is kept and saved (only when it is not 0); betrayal sets it to
  0. Nothing shows it or adds to it before 3C's quests.
- **look.c's relation** (他是你的师父, 同门师兄, 师叔 …) is the last line of 目标详情 for an NPC
  of the player's family; an NPC has no master and enter_time 0 (create_family()).
- **practice_skill() may ask for a weapon in hand** (`practice.weapon`, spring-blade.c's blade),
  checked before kee and with its own line.
- **Owner: Q1 A.** The 忘忧草 is defined but not placed. 陈剑秋's three answers are rules
  (`item_name`, `giver_family`); the letter waits for 乔阴县城's lion (CLOUD_CONTENT, Deferred).
- **Owner: killing one's own master comes with 3C** (killer_reward()'s player side).

## 卧龙岗 + 绮云镇 3A: the streets and shops (2026-10-05)

The region plan's #3; what is placed where is in [CLOUD_CONTENT](CLOUD_CONTENT.md).
- **Two maps, drawn as a town** (owner: not a grid of boxes): the outdoor map holds the road
  from Snow's 雪亭镇街道 winding over 卧龙岗 to the gate, the market street (北, 西, 中, 东, 南市场)
  turning down to the crossroad and the main street across the town; street rooms are stretches
  of one open road with no walls between them, shops and houses are buildings of their own sizes
  along it with their door onto the street their exit names. The three upper floors (香茗坊,
  怡红院, 赌场) are one map of three separate rooms, reached by their stairs. Diagonal exits become
  straight; 南坡 and the second 黄土路 both open onto the gate, as the three lead to each other;
  a cliff keeps 卧龙岗 from the second 黄土路. Closed: south across 泓水 (#8), west to 晚月庄 (#7).
- **Owner: the later packages' NPCs stand now** as ordinary NPCs (陈剑秋 and 趟子手, 3B; 朱鸿雪,
  3C; 宝官 and 媒婆, 3D; 船夫, #8). 朱鸿雪 and 化缘和尚 cannot be fought until their arts are
  ported; 春风快意刀 is, for the 家丁 (and so 陈剑秋 and 趟子手).
- **The toll** (gangster.c): a robber attacks a player without marks/强盗 on sight (its greeting's
  kill_passenger()); giving it something worth ten gold taels sets the mark; less, and that robber
  attacks. The native presence (radius 100 here) is the room, and the greeting's call_out a second
  in it (two seconds natively: pacing knobs above), so the toll is paid from the edge of the room. A robber that has
  fought the player attacks on sight from then on, mark or not (kill_passenger()'s attitude,
  attack.c's hatred, after its aggression, a refused toll, the player's 攻击 or 切磋), until it is
  made anew. Its chat and fight lines are set from the start where ES2 sets them at that first
  meeting.
- **Owner: the thief steals** (thief.c, cmds/std/steal.c), the NPC side only (the player's steal
  waits for #9): an arriving player (or the thief arriving) is tried when random(kar) < 2, one
  second later steal.c picks present("silver") or a random carried thing, three seconds later it
  rolls. The player reads nothing when robbed, only when caught; then they fight (fight_ob both
  ways: a spar). An NPC is not robbed, nor is a thing the player dropped in those three seconds
  (steal.c would take it off the floor). His `thief` count and a robber's having fought the
  player are object variables: Continue forgets them, as drunk.c's has_alcohol.
- **Rules as data**: accept_object rules test the giver's gender and raw per (李师师's keepsake)
  and may attack on a refusal (`kill`); greetings draw `out_of` n (switch(random(4)) with fewer
  cases says nothing on the rest); a `line` is shown as written (the say() efun naming its
  speaker). A `->wield()` that finds no free hand leaves the weapon carried (the robber's 飞镖).
- **The archive's hard wrap**: a raw line break inside an LPC string is dropped on import (the
  u/cloud files and daemon/class/fighter/celestial are wrapped at 80 columns).
- **For the owner**: 牛腿 (sold by the butcher) is a hammer only, since food that is also a weapon
  is not supported yet; food eaten up leaves no bones (finish_eat); 弈者's 下棋 is not ported.
- World content revision `SOURCE_ENTRY_CLOUD_V1`: older development saves need a New Game.

## 野羊山: the mountain road, the caverns, two hands, bash_weapon (2026-10-05)

The region plan's #2; what is placed where is in [GOATHILL_CONTENT](GOATHILL_CONTENT.md).
- **Two maps**: the mountain (mroad1-6, temple1, slope1, canyon1-3, a room each on a 256 px
  grid) and the caverns (cavern1-4), entered east from canyon3; Snow's crossroad leads north
  in. Diagonal exits become straight ones (mroad2 northeast, cavern1 northeast and southeast);
  mroad5's northeast to mroad6 runs through slope1. mroad4's four bandits join one fight
  (`complete_set`).
- **The second hand** (equip.c wield()): a second one-handed SECONDARY weapon goes to the other
  hand, for NPCs as for the player, and every wielded weapon's weapon_prop counts in apply/*,
  damage too (黄霸: 45 and 45); only the primary attacks (combatd.c). A player's second weapon
  counted for nothing before.
- **bash_weapon** (weapond.c; hammers' and staffs' bash, crush, slam): a blow the victim parried
  with a weapon pits weight / 500 + rigidity + str against the victim's: random(wap) over twice
  knocks the weapon to the floor, over once nearly, over half breaks it, else sparks. A broken
  one is 断掉的<name> from then on (value / 10, weapon_prop 0: not wieldable); every weapon has a
  `#broken` form in the catalog and the object keeps its identity (and its place in its
  NPC's loadout). A broken stack (飞刀) stays one, of broken ones, which no longer merge with
  whole ones (combined.c would merge them by file: **for the owner**). No ported item sets
  rigidity (0). The draw comes after the riposte's, where combatd.c draws it before: the attack
  decides the riposte before the runtime runs post_actions (**for the owner**). A special
  file's attacks (fakefault.c's 奋力一击) show their post_actions too. Snow's 铁锤 bashes too.
- **bash's line keeps the source's □** (用力一□, a character lost in its conversion), as
  combat lines keep 血肉□糊.
- **伏蛟功** (serpentforce.c) is a force skill with std/force.c's hit; its exert functions (the
  beggar class) and practice by water are not ported (no teacher in reach).
- **Owner: as LPC**: 银色岩蛭 (no room places it), 死岩蛭 (no code reads `corpse_ob`: leeches leave
  plain corpses), 护心镜 (nobody carries it). 黄霸's pursuer is not modelled (as 安惜迩's).
- World content revision `SOURCE_ENTRY_GOATHILL_V1`: older development saves need a New Game.

## Old Pine remainder B: conditions, combined items, 金银花蛇 and 黑衣人 (2026-10-05)

What is placed where is in [OLDPINE_CONTENT](OLDPINE_CONTENT.md).
- **Conditions update on the heart beat** (supersedes S5B E): on the `5 + random(10)` tick
  update_condition() runs before heal_up(), which CND_NO_HEAL_UP skips (char.c), for the player
  and the active map's NPCs. **Owner: not in a fight** — the world stands still there (S5B D),
  conditions too, where ES2 ticks them; nor while the player lies unconscious (S5B L). The lines
  print in their colour (HIG added). Below zero after a tick the player falls or dies at once
  (char.c heart_beat); the killer is whoever last landed a blow (damage.c `last_damage_from`,
  0 damage too, kept from the fight, not saved) while that NPC still stands on the map, so dying of a bite after
  fleeing costs the death penalty. The HUD names 蛇毒 after 精/气/神 (**owner: keep**):
  presentation only, ES2 shows conditions only through their lines; each condition opts in
  (`shown_name`), so one meant to go unnoticed (slumber_drug) can stay hidden.
- **hit_ob is data** (venomsnake.c; shaoin.c's rose_poison has the same shape): `{condition,
  duration, below, message, color}`. random(damage_bonus) is drawn from the combat stream between
  the martial hit_ob and the strength draw, only for an NPC that has one.
- **Combined items** (`combined` `{base_unit, base_weight, amount}`) are the money stack
  generalized: a new one has create()'s amount, a carried one its carry `amount`
  (`->set_amount()`), and a stack at 0 is destroyed at once (S3B G). drop.c destructs 飞刀 on the
  floor (it has no value); hockshop.c values a stack by `query("value")`, whatever its amount.
  get.c's `get N x` leaves N on the floor and takes the rest: the floor pickup still takes the
  whole stack.
- **weapond.c throw_weapon** runs after the attack and before the riposte: the thrown weapon
  loses one; the last one is unwielded first and its thrower told 你的飞刀用完了！. bash_weapon
  (hammers) is still not ported.
- **killed_enemy is data** (`{say, dissolve_after_ms}`): 黑衣人 laughs and a second of world time
  later dissolves the newest corpse in his room with his 化尸粉 (present() finds the object moved
  in last). **Owner: as ES2**, also the player's own corpse with all it holds. The pending
  dissolve is not saved (a call_out). The death screen's native line on where the corpse lies
  becomes 你的尸体已经不在了。 once it is gone (**owner**; ES2 tells the dead nothing).
- **apply** (snake_drug.c, hurt_drug.c; **owner: 金疮药 too**) is the inventory's 使用, used
  outside a fight as eating is. One 蛇药 lowers snake_poison by one (a bite gives 20) and the last
  leaves it at 0, where snake_poison.c strikes once more before it ends.
- World content revision `SOURCE_ENTRY_OLDPINE_VENOM_V1`: older development saves need a New Game.

## Old Pine remainder A: the keep, the caves and cliff2 (2026-10-04)

The region plan's first package (owner confirmed the order); what is placed where is in
[OLDPINE_CONTENT](OLDPINE_CONTENT.md).
- **One map per height level, as in 3B5.** The stone over path3, the caves below it (cave1-5) and
  cliff2 are maps of their own; path3 `climb up`, stone `climb down`, cliffdown `climb down` and
  cliff2's `climb up`/`climb down` are landmarks that say the room's own line.
- **The caves' random exits become one fixed maze** (as the pine maze): cave1-4 are one zone with
  forks, loops and dead ends and one way on to cave5, whose `eastdown` leads to the waterfall.
- **keep2.c's gate** is a door only its room rule operates (`traps[]`): it starts open; leaving
  keep2 east while it is open shouts, shuts it and brings five 土匪喽罗 into keep2; 常老大's 竹管
  played in keep2 (pipe_notify()) or keep2's reset opens it. ES2 adds five more guards every time
  it shuts; the native trap brings back those of its five that are gone and leaves the living
  ones. Like every door its state is not saved: a Continue finds it open, as a login would.
  The summoned guards' absence is saved; only a summoned spawn's NPC may be alive and absent.
- **The keep's three rooms enter fights as the Lake does** (`combat_entry: complete_set`, P2A-M):
  every aggressive guard in contact joins one encounter, as each one's init() kill_ob()s the
  player on arrival in ES2; a pair entry left guards standing beside the player after a fight.
- **A beast's authored kee above its race's maximum raises the maximum** (wolf_dog.c: kee and
  eff_kee 200 at age 4, max_kee 50). LPC keeps eff_kee over max_kee; a resource state cannot.
  The dog fights with 200 kee as in ES2; it heals back to 200, not to 50.
- **Berserk** (attack.c init(), combatd.c start_berserk()): an NPC that is not aggressive but has
  bellicosity rolls on the player's arrival and, above its score, attacks to kill (疯老头子). Its
  spar branch (fight_ob(), bellicosity not above score) is not ported; the loader refuses such an
  NPC. Bellicosity also counts as courage in a fight (attribute.c query_cor()).

## The player's perform: 封山剑法's 封, 逐, 缺 (2026-10-04)

Owner-approved plan ("四条都照建议做"), second PR of combat talk and specials:
- **perform.c on the battle panel**: one button per perform file the wielded weapon's enabled
  skill reaches (a sword with 封山剑法: 「封」「逐」「缺」; 「点」 powerfocus has no file), against
  the current target (`perform <action> <target>`: no offensive_target() draw), or with none
  while the player has none yet (before their first round: `perform <action>`, the file's
  offensive_target()). Like exert it is queued and waits while the player is busy (perform.c
  refuses) and runs between rounds, as a command does. Use is practice: random(120) <
  query_skill(skill) in weak mode.
- **A special's do_attack()** is a direct TYPE_REGULAR attack through the ordinary attack chain
  (a riposte may follow), with no fight() step (guarding, courage) and whoever is busy, also on a
  killer's unconscious victim (「逐」 and 「封」 only ask is_fighting(); 「缺」 refuses); its lines
  are an ordinary blow's. Nobody falls in the middle of a special: the fight's lifecycle check runs
  after it (char.c heart_beat()), and the victim's last_damage_from is its last landed blow.
- **Owner, obvious slips fixed** (as the reflection line): swordjab.c's attacks use the wielded
  weapon (it passes query("weapon"), never set) and its line comes before them (the source prints
  it after); fakefault.c's 你已经在运用中了。 stops a second 「缺」 (it checks the temp flag and sets
  the permanent one). PR A's two (surrender.c's $N/$n, guard.c's 刘安录) are confirmed.
- **Owner: 「逐」 has no busy**, as in ES2; eff_kee − 10 per use is its only limit.
- **Owner: 「缺」 strikes only in its fight.** Its applies are a timed apply (a round is
  combat_round_ms); ending in the fight against the target still conscious and there, remove_effect()
  strikes both ways. When the fight ends the entry forgets its target: ending on world time after
  it (a decided spar, both standing), in a later fight, or with the performer unconscious, it only
  takes the applies back; ES2 would trade two blows wherever both still stand.
- Codex on #49: several NPC beats in one step fall below zero before each beat's chat.

## Combat talk and NPC specials (2026-10-04)

Owner-approved plan, first of two PRs (the second is the player's perform); what each NPC
does is in [SNOW_CONTENT](SNOW_CONTENT.md#combat-talk-and-specials).
- **npc.c chat() in a fight** runs after an NPC's attack on a beat it is not busy, while it still
  fights, with draws from the fight's random source; after the blow that ends the fight it says
  nothing. A beat whose attack found nobody to fight chats outside a fight in ES2; the world
  stands still during a fight, so it says nothing.
- **Timed applies** (powerup's call_out): a fight's round is combat_round_ms of their time, world
  time counts the rest for the NPCs of the active map (as heal_up and revive). Saved only while
  one runs: older saves still load.
- Outside a fight an NPC below zero gin, kee or sen falls on its next beat (std/char.c), so
  powerfade's 100 sen can knock 安惜迩 out. Not ported: powerfade's faint in a fight (only his
  peaceful chat uses it), the farmer's score loss on surrender (NPC score is not tracked).
- **Owner (confirmed in PR B)**: obvious slips fixed, as with the reflection line: surrender.c's
  swapped $N/$n (the farmer begs, the player refuses) and guard.c's 刘安录 (an override).

## How a fight opens (2026-10-04)

- feature/attack.c kill_ob() tells its victim 看起来X想杀死你！ (HIR) every time: after
  kill.c's line (obj->kill_ob(me)), from combatd.c start_aggressive() and from 安惜迩's
  accept_fight(). The player now sees it for each NPC that fights them to the death; the
  aggressive NPC's native `<name>向你发动攻击！` is gone.
- **Owner:** the battle panel covers the log, so a fight's opening lines (fight.c's or kill.c's
  words, the NPC's answer, the warnings) also open the battle log, and the warnings stay pinned
  under the title for the whole fight. No confirmation dialog: ES2 has none, an NPC's answer is
  content, and Flee is already on the panel.

## Internal power in combat: enforce, exert, the force hit (2026-10-03)

Owner-approved plan ("按你的建议"):
- **enforce.c** on the 武学 page and the battle panel: 0 (none) to query_skill("force") / 2,
  an enabled force needed, no busy or fight check, so in a fight it is set at once (not
  queued) and its Ok. joins the battle log. Ok. stays English, as enable.c's (#46 review).
- **exert.c** with the function files skills.json lists under `exert`: fonxanforce's heal
  (`daemon/class/swordsman/fonxanforce/heal.c`), the basic force's recover, refresh and
  regenerate (`/d/force`), tried in exert.c's order; the last notify_fail() is the line a
  refusal shows. Use is practice: random(120) for the enabled force (weak mode: a player
  never gains a level from it), random(force * 4) for the basic force. The target is always
  oneself, so the files' `target != me` lines never show.
- **Owner:** in a fight 运功 is queued like 逃跑 and waits while the player is busy (等你空下来);
  ES2 refuses with exert.c's ( 你上一个动作还没有完成，不能施用内功。). Out of a fight a busy
  player gets that line.
- **Owner:** powerup and powerfade (天邪神功, `daemon/class/fighter/celestial`) wait for the
  combat specials package with 安惜迩's exert; the player cannot learn 天邪神功 in Snow.
- std/force.c's reflection is told between the move and the damage line (combatd.c adds the
  hit_ob() string there). **Owner:** its third line, 「$N被$N以内力一震」 in the source, shows $n.
- **Owner (#46 review):** Continue is ES2's login: race/human.c runs again for the player and
  max gin, kee and sen are recomputed with a quarter of max atman, force and mana. Eff and
  current stay unless a maximum falls below them: our tracks keep current ≤ eff ≤ max, where
  ES2 leaves them above until they drop (no maximum shrinks in the game yet). A save made after
  max_force grew is therefore not restored bit for bit.
- **Owner (#46 review):** exercise pace, option B: the pacing knobs package adds a data
  multiplier for exercise gain or kee recovery, default ES2's; the value is set from playtest.

## Offense/defense routes B: the player's own training (2026-10-03)

Owner-approved plan (the package's second PR):
- **enable.c anywhere outside a fight**, on the character panel's 武学 page, for every use a
  special skill can be enabled for (封山剑法: sword and parry). Supersedes D-SMP2-02 (enable only
  beside 柳淳风) and the teacher panel's 启用/停用 (first use only, no reset). enable.c also works
  in a fight; the page closes in one like every portable action. No busy check (enable.c has
  none). Every enable for force (magic, spells) empties force (atman, mana) with enable.c's line,
  the same skill again too; the page does not offer the skill already enabled.
- practice.c, exercise.c, selflearn.c and study.c run from the page with their lines.
  practice_skill() and valid_learn()'s lines are skills.json data; learn.c, practice.c and study.c
  print valid_learn()'s own line (the last notify_fail wins; PR A printed learn.c's).
- study.c reads items.json `study` (obj/old_book.c: force to 10; the scavenger carries it). It
  spends sen and no potential; a negative cost (int over 40 for the book) changes nothing
  (receive_damage() raises an error).
- Lines keep ES2's colours in the log and on the HUD: practice.c HIY, improve_skill() HIC,
  skill_improved() HIW.
- exercise.c lost characters in the source's encoding: 全身□麻 is shown as 全身酸麻 (痠), the
  bottleneck line ends 瓶颈。 The page's 打坐 amount starts at 30 (exercise.c's help), minimum 10.
- **Owner:** ES2's pace stays. Measured: max_force 0 → 50 takes about 8–16 hours of play (kee
  comes back every heal_up, about 21 s); see the pacing knobs package.
  `tests/runtime/run_with_max_force.gd` (opt-in) gives a playtest max_force 49.
- Where the driver would stop the command with an error (a zero maximum in exercise.c, int 0 in
  selflearn.c, a negative study cost) nothing changes and the page says 你现在无法练功 / 自学 / 研读.
- Not yet: the move use (chaos-steps) has no basic skill, so it is not offered; race/human.c adds
  max_force/4 to max kee in setup() (at login in ES2), and the player's maxima are not recomputed.

## Offense/defense routes A: moves as data, apply/* in combat, 柳淳风 and 安惜迩 fought (2026-10-03)

Owner-approved plan (two PRs; this is the first):
- Skill moves, dodge.c/chaos-steps lines and parry.c lines are skills.json data
  (`liuh_ken_definition.gd` is gone); a move's `dodge`/`parry` stay in the LPC (D-SMP2-05). A
  skill with its own hit_ob() is marked `hit_ob` and stops the fight (not ported).
- A weapon without a mapped skill draws its kind's verbs (weapond.c, std/weapon/*.c); hammers,
  staffs and throwing weapons keep `slash` until weapond.c's post_action is ported. Unarmed
  humans draw race/human.c's five moves.
- Every apply/* reaches combat: armor_prop, the primary weapon's weapon_prop (a secondary
  weapon's is not added yet) and the NPC's own set_temp, for any race.
- NPC internal power (force/atman/mana, force_factor) as create() sets it; race/human.c's
  quarter to max gin/kee/sen. fonxanforce and celestial take std/force.c's force hit; its
  reflection line is not narrated yet (needs an unarmed attacker).
- 安惜迩's accept_fight() answers with kill_ob(): he fights to kill, the challenger only fights
  back, so an unconscious 安惜迩 ends it. 柳绘心 refuses every spar; wear.c female_only.
- **Owner:** combat talk with perform/cast/exert waits for its own package (柳淳风's and 柳绘心's
  sword.counterattack, 安惜迩's spells): they fight weaker than in ES2.
- **Owner (PR review):** the verbs of every weapon kind without a post_action and race/human.c's
  moves stay; an NPC whose learn.c always refuses (柳绘心) keeps its 请教, so players find out by
  trying; kill_ob()'s 看起来X想杀死你！ shows in ES2's HIR red (log and HUD), no native warning.
- Revision `SOURCE_ENTRY_SNOW_ROUTES_V1`: older development saves need a New Game.

## Localization: the source text is the key (2026-10-03)

Package 5, owner-approved; rules and how to add a language: [LOCALIZATION](../production/LOCALIZATION.md).
- Simplified Chinese is the source language and a message's ID is its source text (gettext);
  `tools/l10n/extract_pot.py` is the one extractor (Godot's misses `TranslationServer.translate()`,
  const tables and the content files).
- Authored text stays authored in definitions, state and saves (logic compares it) and is
  translated where it is shown or put into a sentence. A family title is saved as
  assign_apprentice() wrote it and shown put together again. Multi-slot templates name their slots.
- The language follows the system unless chosen in Settings (settings schema 2). The game matches
  Chinese by script and loads only that catalog: Godot would give zh_CN and zh_SG the Traditional
  one. A language not listed reads Simplified; a switch applies at once, old log lines stay.
- Fonts are the system's, listed per language; no font is bundled yet. The title reads 东方故事;
  `config/name` stays (it names the user data folder).
- The player's attack now prints cmds/std/kill.c's line (was a native English line); an aggressive
  NPC's kept a native line, replaced by kill_ob()'s warning (How a fight opens, 2026-10-04).

## Busy wears off on the heart beat (2026-10-02)

`std/char.c` heart_beat(): a busy character spends the beat in `continue_action()` (busy − 1;
a non-positive busy clears) and does nothing else that beat. Outside a fight this now runs on
the S5B 2-second beat, for the player and the NPCs of the active map; inside one the encounter
scheduler does it as before. Supersedes S5B C ("existing busy authority remains the only
advancement owner"), under which busy left by a pickup in a fight (get.c `start_busy(1)`) stopped
recovery and Save for good. The beat still stands still with a condition (S5B E) or while the
player is not ACTIVE (S5B L), where char.c would wear busy down too.

## Give, drop and put; shops and teachers on their NPCs (2026-10-02)

Package 4E, from the owner-approved plan:
- **give, drop, put and get from are `cmds/std/give.c`, `drop.c`, `put.c` and `get.c`** on the
  player's own items, from the inventory panel (给<NPC> when an NPC here is selected, 丢下, 放进<容器>
  beside a container; a stack takes an amount). give.c asks the NPC's `accept_object()`, data
  rules (`accept_object`, first match), and prints the NPC's lines, then destructs money
  (`你拿出十文钱给庙祝。`) and moves anything else to the NPC (`你给收破烂的一件布衣。`): `value()`
  exists only in `std/money.c`, so give.c, keeper.c and teacher.c count money alone. No rule, or a
  refusal, prints 你只能把东西送给其他玩家操纵的人物。 drop.c destructs what has neither a value
  nor a money value (因为这样东西并不值钱…). The world stands still in a fight, so these are used
  outside one, as eating and drinking. A container (`set_max_encumbrance()`, the 功德箱) takes what fits;
  拾取 on it lists its contents, each taken out with get.c's 你从功德箱中拿出一些钱。 Stacks merge
  into the player's (combined.c). Corpses are not put targets yet.
- **Deviation (proposed in the 4E PR, for the owner to confirm): a refused part of a stack stays
  with the player.** give/drop/put with an amount
  split the stack before asking (`new(base_name(obj))`); when the NPC or the container then
  refused, ES2's new object had no environment and the money was lost. The port asks first.
- **ES2 oddities kept:** the drunk's "我还有酒" refusal returns 0 (no `return 1`); the wine he
  takes is moved to him and he drinks it. The keeper's 庙祝不收物品的捐献。 never shows: give.c's
  notify_fail replaces it (driver rule below).
  keeper.c's donation eases bellicosity over 100 (`random(val/10) > kar`, then
  `random(kar) + val/1000`), drawn from the world-interaction stream.
- **Dropped items are saved with their place** (`floor_items`: item, zone, position; written only
  when there are some), laid just before the dropper's feet on a spot a save accepts. A
  floor-spawn item carried off and dropped elsewhere, on any map, is a dropped item.
  A living NPC may have lost loadout items (given, dropped, sold) but lists those that exist.
- **drunk.c do_drink() is a chat action** (`drink`): sated at 380 water it sings; else it drinks
  from its alcohol (liquid.c: water +30, the line), drops the emptied wineskin where it stands
  (drop.c's line) and, with none left, clears `has_alcohol` and asks for wine. **Owner:** the
  drunk condition waits for conditions (the player's wine is deferred too); `has_alcohol` is an
  object variable, not saved (Continue starts it at 1, as create()). The 玉佩/蒙汗药 whispers need
  d/green's temp flags.
- **Owner: emotes print nothing** (sing, sigh, shake, grin, smile, hmm, pat): `data/emoted.o` is
  not in the mudlib. 4A's nod (点了点头。) stays.
- **Shops go with their NPCs.** 店小二, 杨掌柜 and 王铁匠 stand in their shops; their goods
  (`vendor` on the NPC) are bought beside the body (buy.c `present()`), also from an unconscious
  vendor (buy.c does not ask `living()`); a dead one sells nothing until its room resets. The bank
  (`bank.c` convert) and the pawn shop (`HOCKSHOP`) stay the rooms' commands; 安惜迩 stands in the
  bank. The waiter's greeting is one of three lines (`greeting.one_of`); `rank_info/respect`
  (小二哥, 柳馆主) is how the player addresses them.
- **Teachers are data.** `skills.json` names the skills the game models (unarmed, liuh-ken,
  literate); an NPC whose family (`create_family()`, `families.json`) or `recognize_apprentice`
  rules admit a student teaches the ones it has, beside its body (X · 请教), with learn.c's lines.
  柳淳风's `attempt_apprentice()` is the `apprentice` rule (cor and cps 20, class swordsman);
  F_MASTER's prevent_learn() applies. 李火狮 teaches 封山剑派 students (his refusal's
  notify_fail, 李火狮不愿意教你拳法。, wins); 魏无极 teaches whoever paid five taels (marks/魏无极,
  saved with the character). learn.c draws its reject_msg before recognize_apprentice() from the
  world-interaction stream, as ask.c's msg_dunno. dodge, parry, sword and force wait for the
  offense/defense package. The master's ID is his NPC definition (`common.npc.swordsman.master`).
- **heal_me() is judged on the asker (as 4D's owner decision; for the owner to confirm).** dbase.c evaluates herbalist.c's 治伤/疗伤/开药 closure with
  the herbalist himself, as guard.c's ask_me (4D); following that owner decision, the asker's
  eff_kee decides (`eff_kee_percent` answers).
- **Owner: 柳淳风 and 安惜迩 cannot be fought yet** (`fight_deferred`): they map sword to
  fonxansword and dodge to chaos-steps, whose actions are not ported, so every fight would abort.
  No 攻击/切磋 until the 封山剑法/乱七星步 package; 安惜迩's accept_fight (a spar becomes a kill)
  comes with it.
- **Deferred:** the dog's bone (no chicken leg yet; following is not ported), the waiter's cake
  (say), vendor.c's and smith.c's purchase lines, betrayal (change of family), combat talk.
- World content revision `SOURCE_ENTRY_SNOW_SERVICES_V1`: older development saves need a New Game.

## MudOS notify_fail(): the last call wins (2026-10-02)

One driver rule for every command the port runs: when a command fails, the player reads the last
`notify_fail()` set before it returned 0. A message an NPC function sets is replaced by a later
one in the command (give.c's 你只能把东西送给其他玩家操纵的人物。 over keeper.c's), and an NPC's own
`return notify_fail(...)` replaces the command's earlier one (fist_trainer.c over learn.c's
reject_msg). say() and command("say") lines print at once and stay.

## NPCs talk and wander; rooms reset (2026-10-02)

Package 4D, from the owner-approved plan:
- **打听 is `cmds/std/ask.c`** on a selected speaking NPC in the player's place (`present()`):
  ES2's own listing (这里, 名字, 传闻, then the NPC's `set("inquiry")` keys) stands in for typing a
  topic; an answer the NPC files under English `here`/`name`/`rumors` sits behind the Chinese topic
  instead of a second entry. The lines follow ask.c and `inquiryd.c` (the question, then the
  answer, the name answer by attitude with rankd.c's rude words, the room's title, `msg_dunno`
  from the world-interaction stream); the `sigh` after a polite name answer prints nothing
  (`data/emoted.o` is not in the mudlib). Beasts get no 打听, as no 切磋. An answer array keeps
  its strings; ask.c skips its 0s and functions.
- **Topics answered by a function are not data.** 刘安禄's 刘老三/血手刘三 are not listed until his
  reveal is ported. guard.c's `ask_me(who)` receives the NPC itself (dbase.c `evaluate(data,
  this_object())`), so in ES2 anyone who asks has a 50% chance to unmask him; owner: when ported,
  the asker's combat_exp gates it, as the code means. 杜宽's 寄信/收信 go with player mail.
- **Chat is `npc.c` chat()** on the S5B 2-second beat for NPCs in the player's place: `char.c`
  turns a healed NPC's heart beat off when no player shares its room. Not ported: that it never
  comes back on until the NPC is hurt (an efficiency artifact ES2's clean_up hid). Lines go to the
  log as written; an unconscious player reads none (damage.c `block_msg/all`). **Deviation:** an
  unconscious NPC says nothing, neither chat (char.c still runs chat()) nor its greeting. Beats
  and their draws are transient, as heal cadences.
- **Owner: an NPC wanders only at home and next door.** `random_move()` draws one of its room's
  exits; the move happens when the place is its home zone or a zone next to home on the same map,
  no closed door is in the way (`room.c` valid_leave()) and the room is migrated; otherwise nothing
  does, as a failed `go`. ES2's random_move is unbounded until reset calls NPCs home. The
  travellers' Inn exits all leave the Inn's map, so they stay in for now (cross-map wandering
  later). go.c's line (旅客往东离开。) shows where it left. The body walks a path over the map's
  tiles (`AStarGrid2D`, a body's width from walls); its place changes at once, a save takes the
  walk's end, and a fight or leaving the map puts walking NPCs there. On the way it passes through
  the player and notices nobody (ES2 moved it in one step); an aggressive one notices whoever is
  where it arrives, as its init() did.
- **The keeper's greeting is data** (`greeting.say`, `$RESPECT` the player): keeper.c's
  `call_out("greeting", 1)` from init() runs one second of world time after the player comes in,
  or after the keeper comes to where the player is (reset), if the player is still there.
- **Room reset is `std/room.c` reset()** on world time, each room on its own schedule: MudOS's
  `TIME_TO_RESET / 2 + random(TIME_TO_RESET / 2)` seconds, with config.ES2's 1800 as
  `pacing.json` `room_reset_seconds` (a knob; the default is ES2's). A dead NPC is made anew on
  its marker (`make_inventory()` for a destructed object; its ID gets the next generation,
  `<point>.character.<n>`); a living one away from home and conscious, not fighting, hurries home
  (急急忙忙地离开了。); weapon_storage.c's reset() clears the shelf's pushes. Every map resets
  (native rooms are always loaded); Old Pine's bandits and serpents come back too. Schedules are
  not saved: Continue starts them afresh.
- **Owner: an item comes back only once it is gone.** reset() remakes a floor item only when the
  one it laid down no longer exists (sold, eaten): one the player carries is not replaced. ES2's
  `clean_up()` (MudOS memory management: an unvisited room was destructed and reloaded with
  everything new) is not ported.
- **Save:** no new fields. An NPC record may name a later generation and stand away from its home
  zone; a corpse may belong to an earlier generation, checked against the NPC's definition. The world
  content revision stays `SOURCE_ENTRY_SNOW_INNER_V1`: 4C saves load.
- **Deferred:** 醉汉's do_drink (its empty wineskin is dropped and he asks for wine: with give and
  drop, 4E), the waiter's greeting and the shopkeepers' answers (with their bodies, 4E), the
  血手刘三 reveal, combat chat (`chat_msg_combat`), cross-map wandering, corpse decay (corpses of
  respawned NPCs stay), speech bubbles.

## Snow's inner rooms (2026-10-02)

Package 4C, from the owner-approved plan:
- **Maps.** The Inn's upper floor (inn_2f and its three guest rooms behind 房门, `DOOR_CLOSED`)
  is its own map up the Inn's stairs; the secret storage is its own map below the weapon storage
  (one map per height level, as Old Pine). The school's inner yard (天井), study, guest room,
  inner hall and weapon storage are zones of the outdoor map, walked into through their ES2 exits.
- **Items lie on the floor.** A room's `set("objects")` naming an item becomes an item spawn:
  the item lies on its marker when the world is created and is picked up with 拾取, as
  `cmds/std/get.c` (busy, no_get 这个东西拿不起来。, move.c's 太重了). Its identity follows from the
  spawn point, so a save keeps no floor position; there is no drop yet. Room reset (items and
  NPCs coming back) is 4D (above).
- **The weapon storage's shelf** (`weapon_storage.c`) is a landmark whose button is ES2's
  `push <direction>` (往左推); `push shelf`'s hint line is not shown. Three pushes open the way
  down and the way up for ten seconds of world time (stopped in a fight). Opening adds an exit,
  as `set("exits/down")` does: a player standing on the opening is not dropped until they step
  onto it again. Pushes while it is
  open keep counting, so the count can pass three and the shelf then does nothing until the room
  resets, as in the LPC; the count is not saved (ES2 room state), so Continue clears it.
- **Deviation: nobody is shut in below.** `secret_storage.c` has no exits; the way up exists
  only while the passage is open, and only if the room happened to be loaded
  (`find_object`). ES2 players escaped by quitting. Native rooms are always loaded, so both ways
  open together, and the passage does not close while the player is below: once the ten
  seconds are up it closes as soon as nobody is down there. Continue below finds the way up
  open. The far-side lines (天花板…) are never seen and are not data.
- **Deferred:** 柳绘心 (`girl.c`, the study) maps sword to fonxansword, whose actions are not
  ported, so every fight with her would abort; she comes with the 封山剑法/乱七星步 package.
  桃符纸 (`/obj/paper_seal`) is a combined item and waits for combined items, with 蛇药 and
  飞刀. The 功德箱 lies in the temple and cannot be taken; putting things in and taking them out
  (`put`, `get from`) come with give (4E). Its `insert_object()` never runs in MudOS (no such
  apply), so a donation changes nothing.
- **Driver rule:** an object without `set_weight()` weighs 0 (`feature/move.c`); the importer
  writes it.
- World content revision `SOURCE_ENTRY_SNOW_INNER_V1`: older development saves need a New Game.

## Snow's south road and shops (2026-10-02)

Package 4B, from the owner-approved plan:
- **Nine rooms, nine zones of the outdoor map**: sroad2-5, the school (书院), the smithy, the
  herbshop, the post office and the Hockshop storage room, walked into through their ES2 exits
  (the storage room through the curtain, no door). sroad4's southwest (`d/canyon`) and sroad5's
  west (`d/waterfog`) end at a boundary with a sign until those regions exist. `herbshop1.c`
  (药铺密室) has no entrance anywhere in the mudlib and is not migrated.
- **Shops are services until 4E**: 杨掌柜 (`herbalist.c`) and 王铁匠 (`smith.c`) are their
  counters' vendor services without bodies, as the waiter and 安惜迩 in 4A.
- **A vendor's own price.** `smith.c` sells through its own `buy_object()` (300 coins for a
  hammer worth 3), not `vendor_goods`: the override file holds such goods with their price, and
  a goods record may carry `price` (absent = the item's value, `feature/vendor.c`). The shop
  panel shows prices as `vendor.c`'s `price_string()` (3两银子, 15文钱); its button reads 购买.
  The smithy's panel lists the hammer too, although `smith.c` has no `list`: in ES2 the price
  is learned by asking him (4D).
- **Deferred:** 蛇药 (a combined item; each dose lowers snake_poison by 1) and applying 金疮药
  (`apply`: refused in a fight or unhurt, restores up to 20 eff_kee, used up) wait for the
  treatment package; the medicine can be bought and sold. NPC wimpy (farmer, woodcutter) and combat talk wait for a later combat package; ask, chat
  and random_move are 4D; 魏无极's tuition and literate are 4E.
- **Omitted:** player mail (杜宽's 寄信/收信, the mailbox, `postoffice.c` `valid_leave`) is a
  multiplayer feature.
- World content revision `SOURCE_ENTRY_SNOW_SOUTH_V1`: older development saves need a New Game.

## Battle narration in ES2's words (2026-10-01)

Owner decisions for the new-player combat package:
- **The battle log prints `combatd.c`'s lines** as `message_vision()` shows them to the player
  (你 for the player, names and `gender.c` pronouns for the others): the action, the dodge line
  of the victim's mapped dodge skill (only `dodge.c` is ported; no content maps another), the
  `parry.c` line chosen by the attacker's weapon, `damage_msg`, `report_status`, `winner_msg`,
  `guard_msg` and the two riposte lines. The damage follows its line as a small grey number.
- **Deviation: dodge and parry wording draws nothing from the combat random source.** The LPC
  picks them with the driver's `random()`; the port's combat stream never had those draws, so
  the presentation picks the line with its own generator. `winner_msg` and `guard_msg` use the
  index Core already draws.
- **Source text as written:** the Big5 `□` stays (血肉□糊, the `□伤` case), and `$w` stays in a
  line whose unarmed action names no weapon (a beast's 刺伤 of 80 or more).
- **Native lines, ES2 has none:** the end-of-fight line (切磋结束。, 你赢了这场战斗。…), the
  player's target, a queued, refused or given-up Flee. Skipped turns and busy print nothing.
- **Deferred:** `std/force.c`'s reflection lines (nobody can enforce yet) and `announce()`
  (昏倒, 死亡) in the battle log.

## 切磋: fight.c, accept_fight and armed spars (2026-10-01)

Owner decisions for the new-player combat package:
- **The 切磋 button runs `cmds/std/fight.c`** on the selected NPC: 这里禁止战斗。 in a `no_fight`
  room, 加油！加油！加油！ when it already fights you, …已经无法战斗了。 when it is down, the
  challenger's line in `rankd.c` words, then the NPC's `accept_fight()`: `npc.c` by attitude and
  health (gin, kee and sen at 90% or more), or the NPC's own rules as data (`accept_fight` in the
  NPC definition, written in the override file). A refusal prints the NPC's line and
  看起来…并不想跟你较量。. The spar ends on the first blow that draws kee (`combatd.c`).
- **Deviation: beasts are not asked.** `fight.c` makes a non-speaking target `kill_ob` you while
  you only fight; that needs a mixed encounter shape and NPCs coming to afterwards. Beasts get
  no 切磋 button for now; the dog can only be attacked.
- **Armed spars as in ES2.** Replaces "Active Semi-Auto V1 SPAR establishment is unarmed-only":
  a weapon on either side wounds (`combatd.c`: `is_killing || weapon`), so a spar can knock out
  or kill, through the normal lifecycle (corpse, gargoyle, temple). A native line, ES2 has none,
  warns when an armed spar starts: 刀剑无眼，持兵刃比试可能真的受伤。.
- **The killer is `last_damage_from`.** Replaces the 2026-09-30 deviation "the penalty applies
  when a lethal opponent is found": whoever landed the last blow is the killer for
  `killer_reward` and the corpse, in a spar too. A kill mark stands in only when no blow is known.
- **NPCs heal and come to.** Extends S5B's "None for NPCs": the NPCs of the active map run
  `heal_up()` on the `char.c` tick between fights (transient cadence, as the player's), also
  while unconscious, as `char.c` does. An unconscious NPC comes to after `damage.c`'s
  `random(100 - con) + 30` s of world time; the countdown is saved (`revive_in_ms`, written only
  while one is pending) and dropped when the NPC dies. Inactive maps stay frozen.

## A failed fight ends instead of freezing (2026-10-01)

Owner decision for the new-player combat package:
- An attack chain that cannot complete, an opportunity whose opponent selection or fight decision
  fails, or a lifecycle that fails now ends the encounter with an `ABORTED` result. Damage dealt
  stays, anyone below zero kee falls or dies (`char.c` heart_beat does that outside a fight), every
  participant drops its fight and kill marks on the others, the world returns and the log shows
  战斗出错，已中止。. It replaces holding the encounter in RESOLVING for good, which refused Flee
  and never ended. A partial death still blocks Save, and later falls on that map abort too,
  until the cause is fixed.
- Development builds `push_error` the cause (failure, opportunity, attack and progression stages).
  A test suite during which a fight aborts fails (`SuiteResult`) unless it takes the count itself.

## MudOS random(n <= 0) is 0, everywhere (2026-10-01)

Owner decision for the new-player combat package:
- **One driver rule.** MudOS `random(n)` returns 0 for `n <= 0` and draws nothing. Every LPC
  `random()` the port runs calls `legacy_random(n)` on its random source (combat, NPC creation,
  world interaction; 16 call sites). A source that answers out of range is still an error.
- **It replaces the per-site exceptions** recorded below: "Combat invalid random bounds become
  ordered typed failures", "Non-positive authored world random bounds become ordered typed
  ambiguities", P2B-ZE1's zero-EXP defense boundary, CXR9's unarmed zero base damage (armed zero
  base and negative apply/damage now follow the formula as well) and S6B's Vine waterfall
  exception (the technical fixture now falls too).
- **In play:** a zero-damage blow that may wound (armed or killing) no longer stalls the fight
  (`random(0) > armor` is false: no wound); zero cps rolls 0 and attacks or ripostes; zero dodge
  falls from the vine; an NPC with no int learns nothing from a miss.
- **Not random(0):** a negative attacker exp would loop `combatd.c`'s defense loop for ever and
  stays an invalid-state failure; `beast.c` leaves spi and kar unset (0), not `random(0) + 5`.

## Content importer and Snow's first NPCs (2026-10-01)

Package 4A, from the owner-approved Package 4 plan:
- **Imported data.** `tools/migration/content_importer.py` writes rooms, items, NPCs, spawns and
  vendors under `game/data/` from the LPC plus `tools/migration/overrides/<region>.json`. Those
  files are generated and never edited by hand (`tools/tests/test_content_import.py`); every LPC
  fact that does not become data is a finding with a recorded decision in the override file.
  Migration Tooling v1 (`room_extractor.py`, `cli.py`) is retired; its lexer (`es2_source.py`)
  stays.
- **Driver rules, applied once:** a string escape MudOS does not know, `\X`, yields `X` (the Big5
  conversion left `功\德`); colour macros (`CYN`, `NOR`, …) are presentation and leave the text.
- **Random `create()` values** (`600+random(400)`, `if (random(10)<7) set("gender", …)`) are data
  rules, drawn when the NPC is created and before its race's draws; saves keep the drawn values.
- **`no_fight` rooms** (temple, workplace): attacking from or into one prints kill.c's
  这里不准战斗。, and aggressive NPCs start nothing there (combatd.c). A zone is no-fight when any of
  its rooms is.
- **Beasts** use every `beast.c` verb they author, one drawn per attack (`query_action`): the
  dogs bite and claw.
- **Deferred, not changed:** the waiter and 安惜迩 stay services without bodies until services are
  bound to their NPC (4E); the square's three 飞刀 travellers wait for combined throwing weapons;
  items lying in rooms (the temple's paper seals and donation box) come with 4C.
- World content revision `SOURCE_ENTRY_SNOW_NPCS_V1`: older development saves need a New Game.

## Snow: walls on the tile grid, collision on tiles (2026-10-01)

Owner decisions for Package 3B6:
- **Snow collides through its tiles**, as Old Pine does since 3B5. The 24 px off-grid wall shapes
  are gone; every wall, town boundary and shop wall is redrawn as one 32 px band (two tiles, the
  Inn's thickness) on the 16 px grid, so a wall blocks exactly where it is drawn. Walkable widths
  move by up to 8 px. Doors, the closed Old Pine exit (`SouthBlocker`), the counters and the teacher
  stay nodes; doors and `SouthBlocker` fill their tile openings exactly.

## Old Pine: one map per height level, collision on tiles (2026-09-30)

Owner decisions for Package 3B5:
- **One map per height level.** ES2 joins Old Pine's levels mostly by actions: climb pine
  (`clearing.c` → tree1), hold vine (`epath2.c` → waterfall or passage), climb cliff
  (`riverbank1.c` → cliff1), climb up/down (`cliff1.c`); tree1 `down` and passage `south` are
  exits. They used to sit side by side in one scene, joined by same-map teleports. Now the forest,
  the gorge (waterfall, riverbank1-2, lake), the tree top and the cliff niche are separate maps,
  and each of those moves is a scene transition. No Old Pine portal stays on its map. This
  replaces B2's "waterfall pool is walled from above". Nobody climbs mid-fight (an encounter
  freezes the world), but after a Flee the separated opponent mark used to wait for the next round
  (as LPC's `clean_up_enemy` on the next heart_beat); a transition now clears it on arrival.
  Lethal (killer) marks stay.
- **The forest follows the ES2 exits.** spath1-4 lie north of the clearing (`clearing.c`
  north → spath1), npath enters from the west (`clearing.c` west → npath3), and cliffside is
  walked into pine1 (`cliffside.c` north). The walk works both ways although pine1 has no exit
  back: cliffside is a dead end with no way down, so this opens no route. The maze keeps B2's
  native link from the clearing, now on its south side, where ES2 has no exit.
- **Static terrain collides through its tiles.** Walls, forest, water, cliffs and chasms carry a
  TileSet physics shape; the map's walkable area is what is painted with walkable tiles. Doors,
  exits closed in one world (e.g. `SnowBlocker`) and other switchable blockers stay nodes. Old Pine
  uses this from 3B5, Snow from 3B6. This replaces 3B4's "collision waits for art".
- **A corpse lies where its body fell**, shifted sideways (at most 40 px, same zone) when its wider
  footprint would overlap a wall, so a save always holds a position Continue accepts.
- **Tile data stays inline.** Large maps keep their `tile_map_data` in the scene file (about 1 MB
  for Old Pine). Terrain layers move into a per-map sub-scene when real art arrives.

## Terrain on TileMapLayer, collision unchanged (2026-09-30)

Owner decisions for Package 3B4:
- **Tiles are visuals only.** Terrain is drawn with 16 px tiles from one placeholder TileSet
  ([TERRAIN_TILES](TERRAIN_TILES.md)). Collision stays in `StaticBody2D` shapes, so routes and
  spawns are unchanged. The old geometry is off-grid, so a painted edge may sit up to 8 px from
  its collision. Aligning collision to the grid (or moving it into a physics layer) waits for art.
- **Tiles name terrain kinds, not zones.** About 20 kinds (grass, path, water, wall…) replace the
  per-zone grey-box shades. Neighbouring Old Pine zones no longer differ in colour.

## One map runtime: zone ownership, Old Pine geometry and the combat round (2026-09-30)

Owner decisions for Package 3B2 (Old Pine on `WorldMapController`):
- **Zones follow the body's center.** A zone owns the player when its half-open rectangle holds the
  body's center, and the player only moves between neighbouring zones (an ES2 exit, or a `links`
  entry). Old Pine used to switch as soon as the body's edge touched a zone, in any direction.
  Only the player is tracked; NPCs do not walk between zones.
- **Recorded native connections become data.** Central Clearing ↔ Pine Entrance ("Old Pine Outdoor
  directly connects to the Pine Maze") and the fixed maze (Entrance ↔ Deep ↔ Cliff Edge, "Random Pine
  room exits become one fixed continuous maze") are zone `links`.
- **The waterfall pool is walled from above.** `waterfall.c` has only `south`; ES2 reaches it by the
  `epath2.c` vine, `passage.c` south or riverbank2 north. The scene let the player walk down from the
  East Bridge and the South Slope; both edges are now cliffs.
- **Global rule — one combat round per heart_beat.** Every living object ran on one driver
  heart_beat; the encounter scheduler's interval is `common/pacing.json` `combat_round_ms` (1000, the
  previous feel) on every map. It used to come from an unset Timer on Old Pine only (0 elsewhere).
- The Lake's complete-set entry (P2A-M) is the zone's `combat_entry`, unchanged in behaviour.

## Player unconsciousness and death follow ES2 (2026-09-30)

Owner decision after playtest: a defeated player is no longer a terminal state.
- **Killers finish the job:** an encounter continues while an active enemy still holds the unconscious
  player as a lethal target (`feature/attack.c` `remove_enemy`, `std/char.c` heart_beat). Replaces the
  CXR8 rule that player unconsciousness always ended the encounter as DEFEAT.
- **Waking and dying:** unconscious players wake after `random(100 - con) + 30` s (`damage.c`); dead
  players get the `killer_reward` penalty, the white gargoyle lines and reincarnate at `/d/snow/temple`.
  The technical fixture revision keeps its terminal defeat.
- **Save:** blocked while unconscious or on the way back from death (the player cannot act,
  `disable_player`). This narrows "Native saves require a restart-stable gameplay boundary": UNCONSCIOUS
  and DEAD players are no longer eligible. Older saves holding such a player resume the flow on
  Continue without a second penalty.
- **Deviations:** waking up waits until no encounter is active (LPC's call_out fires regardless; an
  unconscious victim cannot dodge, so killers finish within a few blows). The penalty applies when a
  lethal opponent is found, not from LPC `last_damage_from`. The death realm walk, corpse decay, NPC
  revival and healing while unconscious are not implemented yet.

## Old Pine Lake — owner-revised engineering acceptance scope

Owner decision (2026-09-26), after [P2C acceptance](PHASE_OLDPINE_LAKE_SERPENT_PRODUCTION_P2C_ACCEPTANCE.md):
accept the recorded desktop fifth-target mouse input, manual complete-set Attack, five-alive
and mixed death/corpse cross-process Save/Continue, exact durable state/three-RNG equality,
non-resurrection on return, and complete `verify.py` PASS on
`ef8b7d601983c80d817bf28a93e554f2472a49a6` (543.86s).

**TOUCH DEVICE QUALIFICATION — PENDING — NON-BLOCKING FOR LAKE ENGINEERING INTEGRATION.**
This defers missing device evidence only; it is not touch PASS, all-platform acceptance,
or a blanket exemption for later milestones. Actual touch defects, if found, remain separately
reportable. The [existing platform scope row](../production/PROJECT_SCOPE.md#presentation-platforms-tooling-and-release-boundaries)
retains Lake touch movement, horizontal scrolling, fifth-target selection, Flee, and applicable
safe-area, focus, Pause/Back/background/resume checks. Qualify the then-target devices before
claiming verified Lake touch support or external long-term testing/formal release of the related
mobile version. Later device qualification may be completed directly without reopening all Lake
work or creating a prerequisite development phase, test platform or plugin upgrade.

P2C's original PENDING conclusion and all P1/P2A/P2B reports retain their historical meaning.
M/W/R and product behavior are unchanged. This decision authorized one bounded
[Final Audit](PHASE_OLDPINE_LAKE_SERPENT_PRODUCTION_FINAL_AUDIT.md), not PR creation, merge,
or the next milestone. Engineering acceptance under this revised scope does not mean integrated main.

## Old Pine Lake — owner-locked P2A foundations

Owner authorization (2026-09-26), following [Lake P1](PHASE_OLDPINE_LAKE_SERPENT_PRODUCTION_SOURCE_ANALYSIS.md):

- **M: complete-set admission before freeze.** Revalidate coherent current physical contact,
  identity, existence, ACTIVE/available state, combat location and permission. Include every
  actually eligible aggressive enemy; Player plus five is legal. Same map/zone alone is not
  contact, and LPC `MAX_OPPONENT=4` is selection behavior, not encounter capacity. Manual Attack
  retains its own target policy and also includes eligible aggressive contacts. Use stable ID
  ordering, one transaction, one existing encounter/scheduler and full relationship rollback.
  No signal-order selection, delay-to-collect, mid-combat joining, replacement or reinforcements.
- **W: bounded shore Fill.** Reuse direct-held wineskin, ACTIVE, busy/combat, location/distance
  and liquid-service checks. Lake geometry and UI hookup belong to P2B; no environmental Drink,
  general river water, poison or swimming.
- **R: CURRENT WORLD ONLY.** Follow the [development save policy](../production/contracts/NATIVE_SAVE_LOAD_CONTRACT.md#development-save-policy).
  No old/new product-world branches or save migration. Reject incompatible files explicitly;
  never delete, rewrite, respawn, reroll or silently start New Game. P2A retains current public
  SOURCE_ENTRY_V1 with five humans. The future content-marker cutover must be atomic with P2B
  Lake geometry, five additional production slots and complete persistence. Root/item schemas
  change only for a real format change, not a content publication or a Git commit.

This locks M/W and authorizes P2A foundations only. P2B/P2C, Final Audit and integration require
separate owner instructions; historical P1 alternatives remain historical.

## Migration Tooling v1 P2 — owner-locked extraction boundary

**OWNER APPROVED / LOCKED D1–D9.** P1 analysis is OWNER APPROVED / CLOSED at
`0e5ff6a5cbc8d4091102e280c66868ba8763b4bb`. P2 is authorized on
`phase/migration-tooling-v1`, based on green main `cd07808cb76147d0b8c0dad9b82d078b49fefe64`.
The owner explicitly requested this tooling contract here; it is not a new gameplay substitution.
The [P1 analysis](MIGRATION_TOOLING_V1_P1_ANALYSIS.md) remains historical analysis, not rewritten approval.

- **D1 — Language/location:** Python 3.12 standard library only under `tools/migration/`.
  No Godot runtime or third-party parser dependency.
- **D2 — Objects:** Only `reference/es2/mudlib/d/**/*.c` reliably identified as direct
  `inherit ROOM` in code after excluding comments, strings and multiline text. BANK, HOCKSHOP,
  CLASS_GUILD, NPC, ITEM, weapons, armor, food, containers, daemons, commands, skills, vendors
  and masters are OUT_OF_SCOPE for fact extraction; discovery/dependency findings may retain them.
- **D3 — Facts:** Source identity/path, direct inherit declarations, literal short/name,
  literal long as TEXT_ONLY, ordered static exit entries, and explicit static outdoors/indoors/
  no_clean_up/no_fight values only. No runtime, reachability, door, population or callback semantics.
- **D4 — IR:** Independent Migration IR schema version 1, deterministic UTF-8 JSON.
  Ordered source declarations remain arrays. Player, item and Godot runtime schemas do not change.
- **D5 — Provenance:** Each fact retains source-relative path, raw-byte SHA-256, function/top-level
  scope, construct, raw source/expression, ordinal, zero-based byte start/end-exclusive,
  1-based line/column, classification, and normalization rule/version when applicable.
  Source hash and byte span are primary; CRLF is not normalized before indexing.
- **D6 — Unsupported:** Explicit findings, never execution or guesses. Beyond literals only
  narrow `__DIR__` plus literal-string exit normalization is approved. No arbitrary macro,
  variable, function, closure, RNG, arithmetic, inherited-default or driver evaluation.
- **D7 — Output:** Whole-corpus output is ephemeral under ignored `build/migration-tooling-v1/`.
  Only small hand-reviewed fixtures/goldens may be committed; never generated output in `game/`.
- **D8 — Tests:** Standard-library unittest; expected outputs independently hand-authored/reviewed,
  never generated by the extractor under test. Real ES2 samples remain read-only; copied snippets
  retain provenance. No whole-source copies or bulk generated goldens.
- **D9 — Failure:** Exit0 means complete scan without quarantined syntax/encoding errors;
  expected OUT_OF_SCOPE/semantic findings are allowed and never mean semantic PASS. Exit1 means
  completed scan with object-level syntax/encoding quarantine and safe diagnostic output.
  Exit2 means fatal argument/root/path/I/O/schema/internal/output failure. No silent skipping,
  truncation, source repair or incomplete output masquerading as a complete manifest.

All emitted records start UNREVIEWED. Extraction is not migration approval. Reference source is
read-only; no LPC execution/emulation, NPC/item support, Native generation, gameplay/save changes,
PR, merge or P3 is authorized. P2 implementation and local verification must stop for owner review.

## Snow First Progression P2B-ZE1 — zero-EXP combat defense boundary

**OWNER APPROVED — narrow Type B compatibility translation.** P2B analysis
`affbe5030a5a2f03c2bff2ab14195f9f86c5f53c` is approved/closed. This decision authorizes
only the existing combat defense-factor boundary on `phase/snow-first-progression-loop`.

Source: `reference/es2/mudlib/adm/daemons/combatd.c:362–366`:
`defense_factor = your["combat_exp"]`, then `while (random(defense_factor) > my["combat_exp"])`
reduces damage by integer damage/3 and halves the factor. Repository evidence does not prove
historical MudOS `random(0)` return/error behavior or RNG-state consumption.

Only when execution actually reaches this stage, **original defender EXP == 0 and attacker EXP >= 0**
means **zero experience-reduction iterations and zero RNG draws**. Continue normal requested damage,
damage mutation, wound, progression, status, busy, relationship/post-action and chain completion.
Do not move the gate before earlier source stages, roll back mutations, or promise later success.

Positive defender EXP retains every existing draw, strict comparison, integer reduction/halving
and ordering. Negative defender/attacker cases remain fail-closed, including attacker -1 with
defender 1 that performs the existing iteration before factor becomes0 and fails at its old stage.
No clamp0→1, fake draw, generator advance or new observation/API surface is required.

This specifically supersedes the older combat invalid-bound decision for this one condition only.
It is not Type A historical-driver evidence or a global `random(0)=0` rule. Generic Combat/World/NPC
RNG adapters and all other nonpositive-bound policies remain unchanged, including wound, force,
progression, riposte cps, perception, Vine and Learn. No EXP gift, initialization/enemy/skill tuning,
source edit, new RNG stream or Save schema change is authorized. Apply equally to Player/NPC
defenders and forward/QUICK/RIPOSTE ordinary attacks without ID-specific exceptions.

Implementation and P2 real-input acceptance rerun are authorized; a new semantic blocker must be
reported without another fix. Final Audit, PR, merge, P3 and Migration Tooling remain unauthorized.
See [historical analysis](PHASE_SNOW_FIRST_PROGRESSION_COMBAT_ZERO_EXP_BLOCKER.md).

## Snow First Progression P2 — owner-approved bounded teaching embodiment

**Authority:** Owner approved/closed P1 `5780139b82fad932f6bc7786ea295c20602ae0a5`
and authorized P2 A–F on `phase/snow-first-progression-loop` only.

**Decision:** Embody school1 → school2 → schoolhall as three continuous Snow outdoor zones.
The red gate supports physical Open/Close from both sides, defaults closed on cold start/Continue,
and is transient. Its closed collision footprint remains save-invalid even while open; no relocation
on load. Side routes, guard, fist trainer, trainees and the inner school remain deferred.

Liu Chunfeng is a bounded teaching contact, not a combat/persistent NPC. Preserve his authored
identity, all eleven skill levels and source teaching facts; expose only basic unarmed Learn.
Use existing LearnService, F_MASTER, improvement and combat formulas. One request makes at most
one gameplay draw from the existing saved world-interaction stream at the source progress point;
presentation text consumes none. No gifted experience, balance changes or advanced skill UI.

The public first-apprenticeship chain retains effective cor/cps ≥20, failed pending intent,
Cancel/retry, and idempotent master acknowledgement. Pending is transient per Player. Cross-family,
reverse recruitment and betrayal interfaces remain deferred. Correct active Session/map/zone,
placement, proximity, active life, noncombat/nonbusy and input quarantine are approved Type B
contact gates, not claims about LPC busy restrictions.

First recruitment records the complete source family/master/generation14, distinct family title
and privileges, swordsman class, actual UTC entry seconds, and source display title through a
controlled recruitment seam. No skills or rewards are granted. Owner permits the smallest strict
versioned relationship extension within root2; item3 and SOURCE_ENTRY_V1 remain unchanged.
Historical absent fields remain absent; historical nonempty relationships without an entry time
retain UNKNOWN/NOT_RECORDED, never load time. Old valid root2 saves must remain readable.

**Compatibility impact:** Narrow physical/contact staging only; not full school or Liu NPC parity.
Type C: none. Natural combat evidence may be BLOCKED; no gameplay correction is authorized to
manufacture success. Sources: `d/snow/school1.c`, `school2.c`, `schoolhall.c`,
`daemon/class/swordsman/master.c`, `cmds/std/{apprentice,recruit,learn}.c`,
`feature/{apprentice,skill,attribute}.c`, relative to `reference/es2/mudlib/`.

## Hockshop valuation / payout / sell lifecycle (H2)

**OWNER APPROVED — H2.** H1 is OWNER APPROVED / CLOSED at
`7dc3efcdbe7a27fd0d39ee648053dff6f7c612b7`. This A–N package is recorded in a
standalone decision-only commit before production implementation. It supersedes H1's
recommendations, not its source archaeology. No Type C redesign is approved.

- **A — Type B scope:** Value/appraisal and irreversible sell only. Defer pawn and its60%
  transaction, tickets, retrieve, custody, loan and auction; no dormant production pawn API.
- **B — Type B truthful omission:** Do not repeat the source ticket/redeem promise or invent
  redemption. The contradictory prose and low-value pawn formatting remain documented defects;
  reconsidering pawn requires a separate owner decision.
- **C — Type A ownership / Type B selection:** Exact ItemInstanceId replaces textual aliases.
  Appraisal and execution independently require current index/inventory existence, Player direct
  ownership and supported leaf content. Wielded/worn items remain eligible. Reject stale, ground,
  nested, other-character, corpse-held, container, living and unknown items; no recursive sale.
- **D — Type B typed representation carrying Type A facts:** Narrow hybrid: exact dumpling
  FoodState.current_value (fresh15, bitten0); valid wineskin Liquid association with existing
  immutable value20; static source projections cloth0, short sword300, long sword700, leather200.
  No universal mutable price, dbase dictionary, query emulator or merchant inventory. Known-zero
  and unsupported are distinct. Current swords have no new depreciation state.
- **E — Type A zero / Type B invalid-state boundary:** Zero appraises WORTHLESS and rejects
  sale with no allocation, payout or destruction. Negative/malformed/unsupported values fail
  closed explicitly; no abs, clamp-to-one or emulated broken coercion for invalid Native state.
- **F — Type A payout / Type B checked boundary:** Checked integer source_value*80 then /100;
  for positive valid values preserve pay_player's result<1→1. Overflow fails before allocation
  or mutation. Quote actual payout; no floating point or pawn calculation API. Fresh dumpling12,
  wineskin16, leather160, short sword240, long sword560.
- **G — Type A physical money:** Silver first (N/100), then coin (N%100), skipping zero.
  Never gold or wallet. Each attempt allocates a new canonical full-quantity stack BEFORE move.
  Do not reuse Bank's amount1 admission or directly grow an existing target. Normal merge retains
  the incoming ID and destroys old same-denomination stacks.
- **H — Type A ordered partial capacity result:** Sold item remains held/equipped during
  admission. Ordinary capacity refusal continues after its required cleanup; retain earlier
  delivered money and destroy the sold item after normal attempts complete, even if both fail.
  No refund, rollback, ground drop, final-total/net-weight preflight or existing-stack bypass.
- **I — NEW Hockshop-specific Type B cleanup:** Immediately after each ordinary capacity
  refusal, destroy that parentless clone through authoritative ItemLifecycle, retaining consumed
  allocator sequence/ID, BEFORE attempting the next denomination. No orphan persistence, ID reuse,
  cleanup timer or compensation. This deliberately replaces later MudOS cleanup, NOT its exact
  timing, and is separately approved, NOT inherited from Work/Bank/Vendor. Cleanup failure returns
  AUTHORITY_FAILURE, retains reached effects and stops: no later denomination or sold-item
  destruction. This supersedes H1's suggested all-attempts-before-cleanup order.
- **J — Type A payout-before-destruction / Type B authority errors:** After normal attempts and
  cleanups, use existing lifecycle with LIVE Player Equipment/Armor/Inventory/Combined authorities.
  Clear the exact hand/worn slot without invented secondary promotion; remove Inventory/stack,
  then Food/Liquid associations, then derived index. Allocation/registration/merge/cleanup or
  final detach/destruction errors stop with typed AUTHORITY_FAILURE and prior effects retained,
  never rollback or false success. Current non-money stack commerce remains unsupported.
- **K — Type B future physical scope:** H3 front room /d/snow/hockshop only; hockshop2 deferred.
  Narrow authored-closed reopenable local door, no generic door engine or persistent door state;
  fresh Session/cold Continue may restore the closed default. No H2 scene/topology/door changes.
- **L — Type B future interaction:** H3 physical room/proximity-scoped exact-instance Value/Sell
  panel, not global Inventory Sell, merchant NPC, stock/cash or anywhere-commerce. H2 provides
  no world permission or player-facing UI; physical gates belong to the separately authorized H3.
- **M — unchanged Save:** Root schema2 / embedded item schema3 / SOURCE_ENTRY_V1. No saved
  transaction, account, stock, ticket, door or sale history. Existing money, item absence,
  equipment/armor and Food/Liquid absence plus allocator continuation carry settled full/partial/
  zero-delivery sales. Restore allocates zero gameplay IDs; legal baseline saves remain supported.
- **N — staged authorization:** H1 closed; H2 typed core current. H3, distinct Final Audit and
  the one final milestone PR are NOT authorized now. Commit/push H2 then stop for owner review.

Sources: `reference/es2/mudlib/std/room/hockshop.c`, `feature/move.c`,
`std/item/combined.c`, `adm/simul_efun/object.c`, `feature/equip.c`, `feature/food.c`,
`feature/liquid.c`, `obj/cloth.c`, `obj/example/dumpling.c`, `obj/example/wineskin.c`,
`d/oldpine/obj/{short_sword,long_sword,leather}.c`, `obj/money/{coin,silver,gold}.c`.
See [H1 archaeology](PHASE_SNOW_HOCKSHOP_LOOT_MONETIZATION_CONTRACT.md). Prior service
failure policies, PlayerBodyFacts, economy, recovery and owner-local tooling remain unchanged.

## Snow north public spine and Core Hub finish line (S7B)

**OWNER APPROVED — S7B.** S7A is OWNER APPROVED / CLOSED at
`04c77650ea72d48cae1173a422a78c3c0188abd5`. Record these decisions separately before
production implementation. They approve the bounded S7A A–L recommendations, not a final
Snow audit/PR/merge. Source semantics remain Type A; the observable staged omissions and
physical embodiment below are **Type B milestone scope**, not authored source closures.

- **A — extent:** Extend the existing `snow.outdoor` resident continuously from mstreet2
  through distinct `snow.mstreet3`, `snow.mstreet4`, `snow.crossroad` zones. Preserve exact
  reciprocal north/south source adjacency; no new map, ordinary-walking portal or shortcut.
  Southwestern sroad2–5 and other optional branches remain deferred.
- **B — external boundaries:** Crossroad itself is required. Its north Goathill and east
  Green directions remain visible static closed content boundaries, with no destination
  definition, travel action, portal, guard, key or invented authored lock.
- **C — Hockshop:** Static east frontage only. No interior, NPC, appraisal, pawn/sell,
  payout/destruction, custody/ticket/retrieve or persistence. Source doors do not authorize
  generic door runtime. No failed-transfer cleanup decision is generalized to Hockshop.
- **D — Herbshop:** Static west frontage only. No interior, herbalist/woodcutter, medicine,
  inquiry, healing or poison cure. Frontage is not service parity.
- **E — Postoffice:** Static west frontage on mstreet4 only. No interior, officer, mailbox,
  mail fees, accounts, online/offline mail or fake local inbox.
- **F — School:** Later progression; mstreet1 east remains closed. No teachers, training,
  faction/apprenticeship or free weapon access.
- **G — Smithy:** Later commerce/weapon content; mstreet2 west remains closed. No hammer,
  repair or crafting.
- **H — ordinary interiors:** Exposed source services receive honest facades/signs and
  collision boundaries, not empty accessible interiors or unusable service buttons.
  These closures are staging, not claims that ES2 permanently closes the shops. mstreet4
  has no executable east exit: add no alley route, zone, interaction or future-region gate.
- **I — secret/storage:** herbshop1, secret_storage, weapon-storage puzzle and unrelated
  storerooms do not block this bounded milestone; no invented secret entrance.
- **J — healing:** Accept existing eligible S5B slow effective-resource recovery as the
  current healing finish line. Preserve cadence, food/water, condition freezes and lifecycle;
  no new recovery Timer, combat recovery, poison scheduling or medicine.
- **K — loot:** Excess-loot monetization remains an acknowledged high-value later commerce
  gap, not a Snow Core blocker. Do not add selling/value projections in S7B.
- **L — completion:** Source New Game, Work, Bank, dumpling, wineskin/water, eligible recovery,
  Old Pine link, north spine, honest deferred frontages/regions and old/new-position Save/
  Continue must work within existing authority. Keep root2/item3/SOURCE_ENTRY_V1; no new
  mutable street/door/NPC state or gameplay RNG use. All38 rooms are not required. A distinct
  Final Snow Audit is the next possible phase **only after S7B owner approval and separate
  authorization**; implementation completion does not close the milestone or authorize PR.

Sources: `reference/es2/mudlib/d/snow/mstreet2.c`, `mstreet3.c`, `mstreet4.c`, `crossroad.c`,
`hockshop.c`, `herbshop.c`, `postoffice.c`, `d/green/path6.c`, `d/goathill/mroad1.c`.
See [S7A analysis](PHASE_SNOW_TOWN_CORE_HUB_NORTH_STREET_CORE_SERVICES_REBASELINE.md).
No Type C redesign is approved; existing PlayerBodyFacts, item authority, prior service
failure policies and owner-local tooling remain unchanged.

## Fresh water supply loop (S6B only)

**OWNER APPROVED — S6B.** S6A is OWNER APPROVED / CLOSED at
`945a8bde0d8d2734f737b51fb6619cf42e8ff5cd`. These A–M decisions are committed separately
before implementation. They authorize no final Snow PR, alcohol runtime or next slice.

- **A — source selection:** First source is `d/oldpine/waterfall.c`, resource/water1,
  represented by `oldpine.outdoor.waterfall_basin`. Unlimited; no depletion, reset or cooldown.
- **B — narrow Type B Vine supersession:** For playable SOURCE_ENTRY_V1 only, effective dodge<=0
  selects the existing Waterfall branch through normal presentation/movement with zero World RNG
  draws. No clamp, fake draw, dodge mutation, skill grant or reverse cliff edge. Historical
  random(0) behavior is still unproven; this resolves the monotonic low-dodge intent, not new
  Type A evidence. Positive bounds retain exactly one existing draw, range [0,bound), <5 Waterfall,
  otherwise Passage; invalid draws remain typed failure. Other revisions and authored random-bound
  policies retain their previous ambiguity behavior.
- **C — canonical content:** Waiter sells `es2:obj/example/wineskin` from `obj/example/wineskin.c`:
  牛皮酒袋, aliases wineskin/skin, unit个, weight700, value/price20, max15, fresh alcohol/红酒15,
  drunk_apply6. Ordinary ITEM+F_LIQUID, not combined/food/weapon/armor. Unlimited fresh-ID purchases.
- **D — truthful fresh wine:** Preserve RED_WINE15, including through Save/Continue. No empty,
  clear-water or renamed substitute. Staged UI must explain incomplete alcohol support honestly.
- **E — Type B alcohol omission:** Alcohol Drink returns typed ALCOHOL_DEFERRED before mutations:
  zero portions/water/busy/conditions/RNG. No harmless wine substitute. ConditionSystem, drunk,
  missing receive_healing, recovery condition freeze and unconscious/revive remain untouched.
- **F — Type A fill and identity:** Full/partial/empty wine or water can be discarded/refilled
  to CLEAR_WATER15 on the SAME item/definition/parent/weight, zero allocation. No empty-first rule,
  poured-wine item or replacement. Authored drunk_apply6 remains; water never applies drunk.
- **G — water semantics and valid-state boundary:** Validate action/item, ACTIVE/in-world ordinary
  availability, busy, direct ownership, staged combat exclusion, valid positive remaining, then
  Player water<capacity. Success decrements one portion then adds30 water without clamping or
  immediate healing. Body80000 capacity400:400 refuses unchanged,399→429,0→30. Empty0 survives,
  with same ID/parent/weight700/value20/content. No food/condition/busy/RNG mutation. Native legal
  liquid states are remaining0..15; source arbitrary negative truthiness is not normalized.
- **H — Type B reachability:** Specific Player-direct-held instance only, no ground/nested/NPC/
  other-holder use. Distinct wineskins remain independent. This is not full LPC add_action reach.
- **I — Type B noncombat/ACTIVE staging:** Reject active encounter/fighting without busy or other
  mutation. Existing busy blocks but is not advanced/cleared. Successful noncombat use adds no
  busy; source fighting-success busy2 is deferred. Require published active Session, ACTIVE world
  Player and ordinary interaction availability; paused/staged/nonworld/dead/ghost use is excluded.
- **J — wineskin-specific Vendor extension:** Explicitly extend S4B waiter A–D ONLY to this offer.
  Resolve/validate item/liquid/persistence facts and canonical price before affordability/payment;
  malformed static facts reject free. Preserve S3B0/1/2 and ordered payment. After payment allocate
  → full-weight registration → index → fresh liquid state → post-payment capacity transfer.
  No pre-payment final-weight preflight. Paid failure retains money and sequence/ID consumption;
  destroy only safe parentless product through authoritative ItemLifecycle, then liquid association,
  then derived index. No refund/drop/orphan Save/timer/fallback. Cleanup failure is authority failure.
  Truthful paid=true/delivered=false. Dumpling remains unchanged; no generic Vendor/Bank policy.
- **K — Type B typed composition:** Session owns one LiquidCollection keyed by ItemInstanceId;
  LiquidState holds typed RED_WINE/CLEAR_WATER plus remaining. Definitions own max/hydration/drunk
  metadata/display/weight/value. Inventory owns existence/parent/weight. No UI text/dictionary/
  Callable/parent/price in mutable payload, duplicate inventory or generic consumable engine.
  Do not infer universal liquid-versus-food/weapon/armor/stack role exclusivity from this one item.
- **L — Type B embedded format:** Item schema2→3, deterministic typed liquid_consumables records
  of ID/content/remaining. Root schema2, SOURCE_ENTRY_V1, root keys and three saved RNG streams
  unchanged. Strict item1 five historical keys; item2 adds food_consumables; item3 also requires
  liquid_consumables. Unknown/missing/extra keys reject. Legal old1/2 decode with empty liquid
  records then current validation; explicit resave writes3, not old JSON byte equality. Never
  recreate fresh wine for missing state. Reject duplicate/dangling/non-liquid/missing records,
  unknown content, negative/>15 remaining, wrong weight/identity. Both content kinds0..15 valid,
  including empty live items. Restore fresh collection with exact IDs/parents/allocator, no draw
  or allocation/refill. Preserve supported root2/item1 food-validation behavior; root1 unsupported.
- **M — Type B bounded physical/UI scope:** Only Waterfall exposes environmental Fill, requiring
  current active-map/authoritative zone/valid placement/near-marker proof and selected direct-held
  instance. No map-ID-only access or direct environmental Drink. Static marker is not saved/item/NPC.
  Fill validates availability → ownership → busy/combat → water source → liquid facts, then sets
  CLEAR_WATER and max15; Player water unchanged. Held clear-water Drink is map-independent via one
  Session UI. Show contents/remaining and truthful wine-discard action. Riverbanks remain authored
  but staged; no Green/Snow north/Lake or new return shortcut. Work/Bank/dumpling and S5B unchanged.

Source facts: `reference/es2/mudlib/feature/liquid.c`, `obj/example/wineskin.c`,
`d/snow/npc/waiter.c`, `d/oldpine/epath2.c`, `d/oldpine/waterfall.c`, `feature/damage.c`,
`feature/vendor.c`, `feature/finance.c`, `feature/move.c`. See
[S6A archaeology](PHASE_SNOW_TOWN_CORE_HUB_WATER_DRINK_SOURCE_CONTRACT.md).
S4B wine deferral and single-offer boundary are superseded only as explicitly scoped above;
its historical evidence and unrelated decisions remain unchanged. S5B's embedded item2 checkpoint
is historical after L; its recovery behavior, independent body facts and timing remain unchanged.

## Player recovery / metabolism cadence (S5B only)

**OWNER APPROVED — S5B.** S1/S2/S3A/S3B/S3C/S4A/S4B/S5A are OWNER APPROVED / CLOSED.
These A–M choices supersede S5A's recommendations, not its source findings. This ledger is
committed separately before production implementation; it does not authorize a final Snow PR.

- **A — Type A count shape:** Preserve `5 + random(10)` stored countdown5–14 and source
  post-decrement semantics: reset5/6/14 yields recovery on eligible pulse6/7/15. At old0,
  draw/store the next reset before applying recovery. No fixed mean or reroll after a failure.
- **B — Type B timing:** Native S5B uses an owner-approved **2.0-second base pulse because
  the original wall-clock heartbeat period is not proven**. The bundled manual's usual2s
  is supporting context, not proof of ES2 deployment. Unblocked opportunities take6–15
  pulses (12–30 seconds of eligible Native time). Process all complete active-delta pulses
  synchronously in order and retain remainder; reject non-finite/negative time, no silent cap.
- **C — source busy ordering:** At each due base pulse inspect busy at entry. Consume the
  pulse's time but do not decrement countdown, recover, update conditions, advance busy or
  draw RNG. Busy1 still blocks. Existing busy authority remains the only advancement owner.
- **D — Type B staged combat omission:** Source permits nonbusy fighting recovery. S5B
  freezes accumulator/countdown during any active encounter or fighting relationship,
  consuming no recovery RNG/metabolism. Resume the same phase after combat. Do not change
  combat timing or use its scheduler as heartbeat; noncombat world-gate freezes also freeze time.
- **E — staged condition dependency:** Any active condition payload (including unsupported
  IDs or zero/negative durations) freezes the entire S5B phase. No handlers, duration mutation,
  expiry or RNG. Source condition→no-heal→recovery order cannot be partially activated by
  healing while its conditions are frozen. This is not source condition behavior/parity.
- **F — Player-only staged scope:** Exactly one Session-owned cadence for SOURCE_ENTRY_V1
  Player. None for NPCs, inactive residents, corpses or LEGACY_OLDPINE_V1 technical sessions.
  Invalid/unpublished/staged candidates cannot tick; unsafe handoff/swap freezes time.
- **G — Type B Pause:** Freeze the complete phase and resume its exact in-memory remainder
  and countdown, without catch-up or reroll. Menus never grant rest/recovery time.
- **H — no offline simulation:** Closed-app time causes zero recovery/metabolism. No clock,
  login/save timestamp, elapsed offline calculation or bounded catch-up is introduced.
- **I — transient phase:** LPC `tick` is static and not saved. Native Save does not reset the
  live phase; fresh Source Session/Continue creates accumulator0 and draws one initial tick.
  Do not save countdown, accumulator or cadence RNG. Map activation/handoff/rollback, Pause,
  combat and condition appearance/removal retain the same live authority without reroll.
- **J — independent transient RNG:** One typed private recovery random source, with injectable
  deterministic tests and dedicated production RNG; no global random state or use of combat,
  NPC-initialization or world-interaction streams. Continue draws only the new transient stream;
  the three persisted streams restore exactly with zero draws. No RNG field is added to Save.
- **K — unchanged Save contract:** Root schema2, embedded item schema2 and SOURCE_ENTRY_V1
  remain exact. Pre-S5B saves load without migration or new optional keys. Only existing
  character facts mutated by recovery persist. Capture is synchronous at a settled boundary;
  ordinary counting does not itself block Save. No cadence section or recovery timestamp.
- **L — ACTIVE-only staged life scope:** Freeze for UNCONSCIOUS/DEAD/other non-ACTIVE state;
  no recovery, metabolism, revive, ghost behavior or new lifecycle reconciliation. Only an
  existing legitimate return to ACTIVE resumes the retained phase. This omits source paths.
- **M — deferred age/idle:** No age/mud_age clock, idle timeout, user_dump, netdead/login
  heartbeat, age gifts or idle rewards/penalties. This is not a general heartbeat emulator.

Implementation must borrow existing `CharacterRecovery.apply_tick` with current raw magic,
force and spells, Player=true/no-heal=false only after the staging guards. No formula, food,
Work, Bank or Vendor changes. Water remains a real supply limit; no refill/starvation system.
Sources: `reference/es2/mudlib/std/char.c`, `feature/damage.c`, `feature/condition.c`,
`include/condition.h`, `doc/efuns/random`, `set_heart_beat`, `save_object`.
Archaeology: [S5A contract](PHASE_SNOW_TOWN_CORE_HUB_RECOVERY_METABOLISM_CONTRACT.md).

## Snow waiter / dumpling supply loop (S4B only)

**OWNER APPROVED — S4B.** These decisions take effect under the owner's S4B instruction.
S1/S2/S3A/S3B/S3C and S4A analysis are OWNER APPROVED / CLOSED. The historical S4A
recommendation table is not rewritten. This does not authorize a final Snow PR or later goods.

- **A — Vendor-specific Type B:** Resolve/quote, affordability, successful ordered payment,
  allocate/create goods, then attempt full-weight delivery. Ordinary capacity failure keeps all
  payment/depletion and consumed IDs/sequences. Immediately remove the provably parentless
  product through authoritative ItemLifecycle, remove associated food state only after removal,
  then update the derived index. No refund, ground drop, orphan persistence, timer or retry.
  Cleanup failure is an explicit authority failure; no fallback. This is separately approved
  for Vendor, not inherited from Workplace S2 or Bank S3B and not a general failed-transfer policy.
- **B — static validation / ordered failure:** Validate the supported offer, source price,
  item/food/persistence definitions before affordability/payment. Missing/malformed content
  rejects without payment or allocation, never substitutes a product/price. After successful
  payment, allocation/creation/registration failures retain reached money/sequence mutations.
  A known safe parentless live partial product may be cleaned using A's ordered lifecycle.
  Unknown ownership is not destroyed; cleanup failure has no fallback or compensation.
  Capacity admission still uses post-payment inventory, never an earlier final-weight preflight.
- **C — Type B truthful presentation:** Report paid=true/delivered=false when paid goods
  are not received. Suppress LPC Vendor's unconditional success text without changing money order.
  Preserve underlying affordability, payment, allocation, transfer and cleanup evidence.
- **D — Type A stock:** Unlimited clone-on-demand offers; every purchase creates a fresh ID.
  No stock counts, restock, cooldown, merchant money/inventory, sold-out state or stock Save.
- **E — Type B staged omission:** Waiter's missing /obj/example/cake remains deferred.
  No substitute cake, free supplies, birthday relay or persistent gift entitlement.
- **F — deferred wine contract:** No wineskin/red wine, water-only substitute, drunk,
  receive_healing repair or intoxication/lifecycle scheduling. Liquid/condition semantics
  require a later explicit contract.
- **G — Type B initial use reachability:** Eat only the specific Player-direct-held food
  instance, ACTIVE and outside combat with ordinary world interaction available. No ground,
  nested, NPC-held or combat use; no new busy2/timer. Preserve an existing applicable busy
  block. Use remains map-independent, never Inn-only or waiter-proximity-dependent.
- **H — typed state / exact semantics:** Session owns one typed food collection keyed by
  ItemInstanceId, associated with the existing item graph, not CombinedStack/scene/UI/payload.
  Dumpling starts portions3/value15; accepted bite adds food60 without clamping, sets value0
  and decrements one portion. Body-fact weight determines capacity; reject at food>=capacity.
  Final bite uses authoritative immediate item destruction, then removes food association
  and index. If removal fails, already-reached food/value/portion mutations remain, with
  authority failure, no rollback or fallback, and no legal successful Save checkpoint.
- **H1 — bounded embedded format evolution:** NativeItemStateSnapshot current version1→2;
  captures encode item schema2 and deterministic typed food records. Decoder accepts exact
  old schema1 keys as empty food state, or exact schema2 keys including food records.
  Unknown versions/keys, duplicate/dangling/non-food records and missing required food state
  reject. A schema1 dumpling without food state fails, never receives fresh portions.
  Legal live dumpling states are only 3/15, 2/0, 1/0. Root schema2 and SOURCE_ENTRY_V1 stay
  unchanged; root schema1 remains unsupported. Pre-S4B semantic continuation is preserved;
  resaving necessarily changes embedded representation1→2, not byte-identical old JSON.
- **I — deferred authored weapon goods:** No dagger/sword-action substitution, chicken/hammer,
  bone variant or their persistence. These remain real deferred waiter offers, not placeholders.
- **J — Type B staged contact:** One deterministic scene-owned 店小二 commerce contact in
  existing Inn main floor, with only the dumpling offer. No NPC character/body/equipment,
  RNG greeting, combat/death, reset/respawn ledger, AI, birthday relay or dialogue system.
  Static contact reappears as scene content on Continue; no mutable waiter Save record.
  Full waiter parity is explicitly not claimed.

**K — sequencing only:** Owner-approved S3C supplies natural Work→Bank→Inn denomination
access. No starter coins, Vendor change-making or denomination normalization is authorized.
S3B's exact affordability/payment anomalies and source price15 remain unchanged.

Sources: `reference/es2/mudlib/d/snow/inn.c`, `d/snow/npc/waiter.c`,
`obj/example/dumpling.c`, `cmds/std/buy.c`, `feature/vendor.c`, `feature/finance.c`,
`feature/food.c`, `feature/move.c`, `feature/clean_up.c`, `std/item.c`.
These are owner-selected boundaries, not a general consumables/commerce authorization.

## Currency exchange / payment core (S3B only)

**OWNER APPROVED — S3B.** The following A–H decisions are locked by the owner's S3B instruction,
not proposals. S3A is OWNER APPROVED / CLOSED. These decisions do not authorize Bank world/UI,
Vendor purchasing or a general economy framework.

- **A — Type A:** Preserve executable `can_afford()` presence checks, strict `<` comparisons and
  distinct 0/1/2 meanings, including false rejections and false-positive1. Coin100 paying100 is2;
  silver1 paying100 and gold1 paying10000 are1; gold1+silver1 paying9900 is1 although payment fails.
- **B — source order / typed errors:** Payment processes gold → silver → coin. Preserve mutations
  completed before a later error; return a typed failure at that stage. No rollback, refund,
  auto-change, new denomination minting or seller credit. Results expose completed mutations.
- **C — Bank-only Type B:** New target allocation and authored amount1 creation precede its
  one-unit-weight transfer attempt. On ordinary failed delivery, establish the converted target
  amount, debit source in source order, then immediately destroy the parentless target through
  ItemLifecycle. Forget index state only after authoritative removal. Keep consumed sequence;
  no refund/source restoration/drop/persistent orphan/timer/retry. Cleanup failure is an authority
  failure with no fallback. This is separately approved for Bank, not inherited from S2 or applicable
  to Vendor. Exact MudOS cleanup timing is deliberately not preserved.
- **D — Type A:** Existing target growth has no transfer/capacity admission. New targets move at
  amount1 before full growth and before source debit. No final/net/gross weight preflight or
  post-growth veto; over-cap results and strict-cap equality are retained.
- **E — Type A:** Payment and Bank are ordered, non-atomic operations. No generic transaction,
  compensation engine or rollback snapshot. Transactional native Save reconstruction is unrelated.
- **F — Type B:** Finance selects at most one stack per denomination from direct Player inventory
  only. No ground, NPC, bag/recursive or world fallback. Duplicate direct stacks use ascending
  stable-instance-ID selection without summing or merging. Presence remains distinct from amount0.
  Bank retains its source direct-only scope. Removing finance's ground-money fallback is explicit.
- **G — S3B-only Type B:** At each full-consumption point, complete denomination arithmetic,
  invoke existing lifecycle immediately and forget the index only after success before continuing.
  No stale-positive one-second window, timer or pending-destruction save state. Stop on lifecycle
  failure, retaining earlier mutations, without fallback deletion. Global Combined semantics and
  the existing item-schema1 omission remain unchanged outside this composition.
- **H — bounded Type B representation:** Only canonical coin(value1/weight1/unit文), shared
  silver(100/37/两), gold(10000/37/两). Exact source-path stack compatibility; no duplicate silver.
  Same-type exchange retains temporary target growth then source subtraction, not a shortcut.
  Reject unsupported denominations/aliases/custom per-instance values explicitly; use checked
  arithmetic, never overflow/clamp to success. Genuine thousand-cash content remains deferred.

**I — boundary, not a Vendor failure decision:** Vendor fulfillment remains deferred. S2, Bank
cleanup and payment decisions must not be generalized to future goods delivery or other commerce.

Sources: `reference/es2/mudlib/feature/finance.c`, `cmds/std/buy.c`, `feature/vendor.c`,
`std/room/bank.c`, `d/snow/bank.c`, `obj/money/{coin,silver,gold,thousand-cash}.c`,
`std/money.c`, `std/item/combined.c`, `feature/move.c`, `feature/clean_up.c`.
Reviewed archaeology: [S3A contract](PHASE_SNOW_TOWN_CORE_HUB_CURRENCY_EXCHANGE_PAYMENT_CONTRACT.md).

## Snow Workplace undeliverable reward cleanup (S2 only)

**Decision (owner-approved):** When the source work reward is created but cannot be moved to
Player because of capacity, Native preserves the already-applied sen30 then gin30 costs and
consumed SessionItemIdAllocator sequence, then immediately destroys the undelivered reward
through the existing ItemLifecycle authority. Its derived index snapshot is removed only after
authoritative destruction. Native does not refund the work cost, drop the reward, persist the
orphan or introduce a cleanup timer.

**Compatibility impact:** `d/snow/workplace.c` ignores `silver->move(me)` failure; source leaves
a transient ownerless object for later MudOS/driver cleanup (`feature/move.c`, `feature/clean_up.c`).
Immediate deterministic cleanup replaces only that infrastructure lifetime, not eligibility,
resource order, reward amount, inventory outcome or allocator consumption. Exact cleanup-timing
parity is not claimed. Cleanup failure is an authority error with no alternate destruction or
persistent-orphan fallback. This decision applies only to the audited Snow Workplace path; it is
not a general policy for future failed transfers.

### Native Character Entry

**Decision (owner-authorized NGE5B):** Native single-player New Game collects only display name
and an explicit legacy male/female gender selection. MUD account ID/password/email and account
security are not migrated. Name preserves the source meaning of 1–6 Chinese/Han characters,
counted as Unicode code points rather than old-encoding bytes. Invalid input is rejected without
renaming or trimming. Internal stable CharacterId and save keys remain separate from display name.

**Source / impact:** `reference/es2/mudlib/adm/daemons/logind.c::check_legal_name` (called by `get_name`) expresses 1–6 Chinese
characters through 2–12 bytes. The native validator uses Unicode Han membership and does not
recreate multiplayer account or banned-name infrastructure. Birth stats, explicit-save policy and
existing gender-dependent rules are unchanged; no other character creation choices are added.

## Pre-Cutover Development Save Compatibility

**Decision (owner-approved NGE5A1):** Development saves produced before the NGE5B public source
New Game cutover carry no compatibility promise. The project has not publicly released and has
no real-player save compatibility obligation. Schema1 is unsupported: no reader, migration,
upgrade, missing-field interpretation or guaranteed restoration is retained.

Current schema2 + `LEGACY_OLDPINE_V1` remains only as the pre-cutover technical New Game test
profile; it is not a historical-save compatibility contract and has no long-term stability
promise. It may be removed at NGE5B unless the owner establishes a new reason to retain it.
Schema2 + `SOURCE_ENTRY_V1` is the forward save baseline.

Unsupported files are rejected, not automatically deleted, rewritten or archived. Existing
New Game confirmation, explicit Save, primary/tmp/bak transactions, recovery and Session rollback
remain. No second slot or migration UI. NGE5A0 independent body authority and exact schema2
continuation are unchanged. This supersedes old-save A and only the v1 interpretation portion of
the body decision below; it does not authorize NGE5B or public New Game cutover.

## Player Body Facts and Native Continue

**Decision (owner-approved NGE5A0):** Player own body weight and maximum encumbrance are independent
typed runtime facts. Ordinary strength growth, including registered unarmed improvement, does not
refresh either value. Carry and death use those stored facts. Fresh Human initialization reuses the
existing source formulas once. NPC body authority is not merged with Player authority.

**Native continuation:** Future schema2 explicitly saves both facts and cold Continue restores them
exactly. Native Save/Continue does not emulate LPC full-login body reconstruction. Only a future
explicit source-backed body rebuild/transformation event may re-derive established facts.

**Legacy v1 interpretation — SUPERSEDED by NGE5A1 (historical record):** Existing saved maximum_encumbrance is authoritative even when it differs
from current strength*5000. v1 has no Player body_weight: derive that missing field once from saved
current strength, then retain it as runtime authority. Until schema2 exists, v1 capture fails closed
if runtime body weight differs from human_weight(current strength); it cannot silently lose that fact.

**Reason / compatibility impact:** In the same LPC body, unarmed's str+=2 does not invoke setup;
Human weight and chard capacity initialize only when zero, and corpse copies existing facts.
On a full new-body login, static move fields begin at zero and setup may derive them again from
saved strength. Native exact continuation deliberately does not reproduce that login-induced change.
This is a native save-continuation compatibility substitution plus a v1 missing-field interpretation,
not a new growth formula or a legacy world/profile upgrade.

Sources: `reference/es2/mudlib/daemon/skill/unarmed.c`, `feature/skill.c`, `feature/dbase.c`,
`feature/move.c`, `adm/daemons/race/human.c`, `adm/daemons/chard.c`, `adm/daemons/logind.c`,
`obj/user.c`, `std/char.c`, `feature/save.c`.

## New Player Delayed Gift Randomization

**Decision (NGE1 owner-approved B):** Fresh native Human Player starts at age14 with all eight
base attributes30. Do not implement `gift_tag`, a pending gift allocation, a gift RNG stream, or
the delayed age15 login overwrite. This is a **compatibility substitution**, not a claim of exact
legacy execution. Other authorized gameplay attribute progression remains allowed.

**Legacy:** `adm/daemons/logind.c::init_new_player` sets attributes30 and gift_tag; the later full
`enter_world` with age>=15 overwrites them with `10 + random(21)`. `obj/user.c::update_age`
establishes age14 initially. Future native age/mud_age progression MUST NOT automatically reintroduce
this overwrite; a fresh source analysis and owner decision are required first.

## Fresh Food / Water Initialization

**Decision (NGE1 owner-approved B):** Only fresh NEW_GAME birth establishes the body, derives food
and water capacity, then initializes them once to capacity: at weight80000, **400/400**.
This is a **legacy initialization-order compatibility correction**.

**Legacy execution:** `adm/daemons/logind.c` queries capacities before body setup;
`feature/move.c` initially has weight0 and `feature/damage.c` divides weight by200, producing
**0/0**, not400/400. `adm/daemons/race/human.c` later establishes body weight.
Continue, Restore, map transition, respawn/revive, load-failure recovery, returning from Old Pine,
opening menus and general recovery MUST NOT invoke this birth refill. No recovery formula changes.

## Legacy Native Save Preservation

**Status: SUPERSEDED by Pre-Cutover Development Save Compatibility (NGE5A1).** The following
records the previously approved old-save A decision, not the current branch policy.

**Decision (NGE1 owner-approved A):** Legal native saves created before Snow cutover remain
Legacy Native Technical-Demo Saves and restore their actual stored values. New Game revisions do
not rewrite existing saves. This is a **save compatibility policy**.

Do not relocate the player to Snow, reset attributes/experience, remove the starter weapon, grant
cloth, replenish food/water, rerun birth, revive NPCs/rebuild tombstones, alter corpses, redraw RNG,
or change allocator continuation. Existing native schema1 itself identifies the technical profile;
never infer it from experience, inventory or timestamps. Its absent Player metadata is interpreted
as the existing Player/age20 facts without recalculating saved gameplay values. This approves no
schema2, world revision implementation, Snow geometry, shops or training work.

## Active Semi-Auto V1 SPAR establishment is unarmed-only

**Decision:** CXR9 owner authorization restricts SPAR establishment to participants
without a wielded primary weapon. A weapon yields typed `SPAR_WEAPON_NOT_ALLOWED`
before Encounter activation/freezing. No automatic unwield, damage suppression,
HP clamp, revive, lethal conversion or corpse is introduced. Existing
`SPAR_MORTAL_WOUND` remains defense-in-depth for invalid/future states.

**Reason:** `cmds/std/fight.c` establishes reciprocal friendly intent, but
`adm/daemons/combatd.c::do_attack` allows wounds when either lethal intent OR a
weapon is present, before positive friendly damage removes the relationships.
`std/char.c` treats negative effective resources as mortal. That conflicts with
the native non-corpse SPAR contract.

**Compatibility impact:** Legacy armed friendly fights are deliberately unsupported
in V1; future armed/practice-weapon spar needs a separate policy. The newly exposed
unarmed zero-base-damage conflict is resolved by the separate owner authorization
below, not by inventing a positive damage floor.

## Unarmed zero base damage contributes zero without a random draw

**Decision:** Following the reproduced CXR9 unarmed-SPAR blocker, the owner
explicitly authorized only this exception: when the attacker has no primary
weapon and projected base damage equals zero, its base random term is zero and
consumes no RNG. Continue the unchanged source-ordered action/strength/armor
calculation. Negative base damage and armed zero base damage still fail at
`APPLY_DAMAGE_RANDOM_BOUND`; all other non-positive random-bound rules remain.

**Reason:** `adm/daemons/combatd.c::do_attack` calculates
`(damage + random(damage)) / 2` before adding strength. Human unarmed action and
`chard.c::setup_char` do not establish a positive base damage; the native empty-hand
projection is zero. Local `doc/efuns/random` does not establish historical driver
semantics for zero. Rejecting that ordinary unarmed path prevented the approved
unarmed-only SPAR from concluding.

**Compatibility impact:** This is an explicit narrow substitution, not a claim
that the old driver consumed no RNG for `random(0)`. It supersedes the earlier
non-positive-bound decision only at this empty-primary-hand base-damage stage.
It applies equally to unarmed LETHAL and SPAR; it does not grant damage, suppress
wounds, alter skills, clamp HP, or generally redefine the random adapter.
Sources: `reference/es2/mudlib/adm/daemons/combatd.c`, `adm/daemons/chard.c`,
`adm/daemons/race/human.c`, `doc/efuns/random`.

## Active Semi-Auto V1 Flee is same-position disengagement

**Decision:** The owner authorizes queued, busy-blocked Flee for LETHAL/SPAR,
deterministically successful when execution validation passes. It consumes no
resource or RNG and returns control at the unchanged physical position. Included
opponent and lethal relations are reconciled; V1 retains no cross-Encounter
pursuit/vendetta. No teleport, reward, healing, corpse or timed immunity is added.

**Reason:** `cmds/std/go.c::do_flee` randomizes a room exit, not a general escape
success roll. Continuous native world has no equivalent in-Encounter exit list.
Source `feature/attack.c::remove_all_enemy` leaves killer markers, but persistent
pursuit and killer Save serialization are not represented by this V1 boundary.

**Compatibility impact:** This explicitly differs from legacy killer preservation
and room-exit movement; it does not change ordinary portal/handoff policy. Physical
leave/reenter controls subsequent aggression. Implementation and acceptance
progress are recorded in CXR9; this approved decision is not a validation PASS.

## Native saves require a restart-stable gameplay boundary

**Decision:** A native Save is accepted only when every represented character and Old Pine runtime
authority is restart-stable. Ordinary opponents, lethal intent, busy/interrupt state, guarding, pending
aggression, active or committed-partial handoff, pending Cave exit, incomplete death lifecycle, active
combat cadence, and unrepresented temporary attribute modifiers block capture. Stable ACTIVE,
fully committed UNCONSCIOUS, and coherent completed DEAD states remain eligible; non-authoritative UI
state and the schema-v1 combined-stack delayed-destruction omission do not block Save.

**Reason:** These facts either describe an ordered transition that cannot be resumed by the closed save
schema or depend on runtime opportunities intentionally rebuilt fresh after Load. Persisting them merely
to allow Save would turn transient scheduling into durable gameplay state. Capturing after the current
event/frame preserves synchronous mutation ordering without adding a heartbeat or transaction runtime.

**Compatibility impact:** Native Save may reject states in which the LPC runtime could serialize user
fields. It never clears combat/busy state to make a save possible. Once eligible, the complete represented
world is captured all-or-nothing through the native repository; Load reconstructs fresh transient combat,
Area, UI, and cadence state. This is a native process-restart safety policy, not an LPC quit emulation.

## Inactive resident Old Pine maps freeze outside the SceneTree

**Decision:** Phase 9B3B1 retains instantiated Old Pine map Nodes for the lifetime of one
`OldPineWorldSession`, but only the active map is attached to the SceneTree. An inactive resident map is
detached without being freed and receives no physics, Area overlap, input, Camera, `_process()`,
`_physics_process()`, OpportunityTimer, combat, recovery, condition, or aggression progression.

**Reason:** The original MUD can continue processing objects outside the player's current room, but the
native prototype has no proven off-screen scheduling contract. Keeping a detached map instance preserves
NPC, corpse, loot, item, signal, and physical-view identity across a map round trip without prematurely
building persistence or a global heartbeat simulator.

**Compatibility impact:** Inactive Old Pine maps are frozen rather than globally simulated. They resume
from their retained runtime state when reattached; no elapsed off-screen combat, recovery, condition, or
NPC activity is synthesized. This is an in-memory session-lifetime rule, not save persistence.

## Non-positive authored world random bounds become ordered typed ambiguities

**S6B supersession:** The owner-approved SOURCE_ENTRY_V1 playable Vine exception above now selects
Waterfall for effective dodge<=0 with zero draws. The original policy/evidence below is historical
for that case and remains current for other revisions/interactions. Positive Vine behavior is unchanged.

**Decision:** When a future authored world interaction reaches an LPC `random(bound)` call with
`bound <= 0`, native code returns a typed legacy ambiguity/failure at that exact source position, consumes
no RNG draw, applies no clamp, and selects no invented branch. Phase 9B3B1 records this boundary but does
not yet implement or execute Vine randomness.

**Reason:** `d/oldpine/epath2.c` calls `random(query_skill("dodge"))`, while the locally available MudOS
documentation does not define zero or negative bounds. The existing Combat decision already uses ordered
typed failures for the same missing driver evidence; authored world interactions require an explicit scope
extension before the Vine path is implemented.

**Compatibility impact:** Positive authored bounds will retain their exact range and source ordering.
Non-positive states become diagnosable instead of crashing, clamping, or silently choosing waterfall or
passage. Presentation and mutations completed before the random position remain observable. Sources:
`reference/es2/mudlib/d/oldpine/epath2.c`, `reference/es2/mudlib/doc/efuns/random`.

## Cross-map ordinary exits use location availability reconciliation

**Decision:** Native cross-map ordinary exits commit the destination `WorldLocationState` and then run a
typed combat-opponent availability reconciliation. They do not reproduce `cmds/std/go.c`'s immediate
`remove_all_enemy()` inside portal or map-handoff code. Ordinary opponent membership can be removed as
out-of-location while independent lethal-target markers continue to follow the closed relationship rules.

**Reason:** Godot physical/world movement is not routed through the LPC directional-command runtime, and
the existing world slice already translates separation into current-location availability facts. Keeping
that boundary avoids hiding command-specific relationship mutation in a generic portal callback and also
allows a busy player to be reconciled without executing an attack or decrementing busy.

**Compatibility impact:** A cross-map ordinary exit such as the future Passage-to-Waterfall transition
cleans ordinary opponents through the explicit post-commit availability opportunity rather than at the
exact `go.c` move-return statement. Lethal intent is not erased merely by handoff. Sources:
`reference/es2/mudlib/cmds/std/go.c`, `game/core/combat/relationship/combat_opponent_selection_service.gd`.

## Combat invalid random bounds become ordered typed failures

**Decision:** Phase 5B2A returns a typed legacy-invalid result when ordinary attack resolution reaches
`random()` with a non-positive apply-damage, defense-factor, or wound-damage bound. The failure occurs at
the exact source position. Mutations already completed before that position are retained; in particular,
kee damage is not rolled back when the later wound `random(D)` bound is invalid.

Phase 5B2B2 extends the same decision to post-attack progression. A reached health-ratio expression
whose `max_gin` is zero becomes a typed division failure at that exact branch; a reached non-positive
progression `random()` bound or out-of-contract injected draw becomes a typed ordered failure. No
maximum is invented and no prevalidation moves the failure ahead of resolver mutations. Consequently,
late HIT failures preserve prior force, damage/wound, combat-exp, potential, and skill mutations exactly
as far as source order had completed. Sources: `reference/es2/mudlib/adm/daemons/combatd.c`,
`feature/skill.c`.

The Phase 5B2B2 formal audit extends this to the later `report_status(victim, wounded)` expression.
When a positive-damage HIT reaches `selected_kee * 100 / max_kee` with `max_kee == 0`, native code
returns a typed failure at that position, after progression and before busy interruption. Earlier mutations
remain, while busy remains untouched. This avoids both a Godot crash and an invented divisor. Source:
`reference/es2/mudlib/adm/daemons/combatd.c:149-160,390-432`.

Phase 5B3B1 extends the same ordered policy to reached `fight()` perception and courage calls.
`100 + effective perception <= 0` fails only when the target is invisible; visible targets never validate
that bound. `raw cps * 3 <= 0` fails only after perception has passed and only when the victim is living
and not busy; QUICK never validates it. A prior perception draw remains consumed when the later courage
bound fails. Guarding is set before the fixed `random(5)` presentation draw, so an invalid guard draw
retains that mutation. Source: `reference/es2/mudlib/adm/daemons/combatd.c::fight()`.

Phase 5B3B2A extends the policy to the terminal guarding-riposte call
`random(my["cps"])`. The exact REGULAR/negative-or-zero-damage/live-guard predicate is evaluated first;
the victim's guarding flag is then cleared, and only then is the original attacker's current raw cps read
as the random bound. A non-positive bound or out-of-range injected draw returns a typed failure while the
guard clear and all earlier attack/relationship mutations remain committed. No minimum cps is introduced.
Sources: `reference/es2/mudlib/adm/daemons/combatd.c::do_attack()`,
`reference/es2/mudlib/feature/dbase.c::query_entire_dbase()`.

**Reason:** The mudlib does not prove the deployed MudOS/FluffOS behavior for `random(0)` or a negative
bound. Clamping to one, prevalidating all later bounds, or allowing a defense loop to hang would each alter
observable source ordering. A typed result keeps the Godot domain safe while preserving all preceding
integer calculations, random consumption, loop iterations, and resource transitions.

**Compatibility impact:** Valid positive-bound attacks are unchanged. Invalid legacy states return a
diagnosable failure instead of a driver-specific error or hang. A wound-bound failure is explicitly a
partial mutation, not an atomic attack rollback. Sources:
`reference/es2/mudlib/adm/daemons/combatd.c:312-380`,
`reference/es2/mudlib/feature/damage.c:12-68`.

## Condition update order

**Decision:** A single native condition update uses a snapshot of active condition IDs sorted by stable ID string in ascending order.

**Reason:** `feature/condition.c` obtains `keys(conditions)` from an LPC mapping and iterates that array backwards. The mudlib does not define mapping key order as gameplay data, yet multiple conditions can mutate the same resource and therefore need a deterministic native order. Stable ID order is independent of insertion order, hash layout, and save/restore behavior.

**Compatibility impact:** Multiple simultaneous conditions may resolve in a different order from a particular MudOS/FluffOS process. Individual condition formulas, flag aggregation, snapshot behavior, and post-update removal semantics remain unchanged. Source: `reference/es2/mudlib/feature/condition.c`.

## Cultivation percentage division by zero

**Decision:** If a Phase 3B1 health-percentage check reaches a primary resource whose maximum is zero, return a typed `LEGACY_ZERO_MAXIMUM_*_DIVISOR` failure at that exact validation position, without mutation.

**Reason:** `exercise.c`, `meditate.c`, and `respirate.c` calculate `current * 100 / maximum` without guarding zero. The LPC command therefore aborts with a driver division error rather than producing a gameplay failure string. A pure domain transition must not crash the application, and treating zero as merely “below 70%” would hide the source defect and alter validation evidence.

**Compatibility impact:** The native call returns a diagnosable failure instead of throwing a MudOS/FluffOS runtime error. It preserves validation order and the absence of mutation. No positive minimum is imposed on internal-resource current or maximum values. Sources: `reference/es2/mudlib/cmds/std/exercise.c`, `meditate.c`, `respirate.c`.

## Self-learning with non-positive intelligence

**Decision:** Phase 3B2 rejects `selflearn` with a typed `LEGACY_NON_POSITIVE_INTELLIGENCE` failure when base `int` is zero or negative, without mutation.

**Reason:** `selflearn.c` computes `300 / int` without a zero guard. Zero aborts immediately. Negative intelligence produces a negative gin cost and later passes it to `receive_damage()`, which raises an error for negative damage; the LPC path may already have modified potential/skill progress before that error. A native domain transition must not crash or leave a partially applied transaction.

**Compatibility impact:** Normal positive-intelligence behavior is unchanged. Invalid legacy states receive a deterministic typed failure instead of a driver error or partial mutation. This is not a new gameplay minimum for valid characters. Sources: `reference/es2/mudlib/cmds/std/selflearn.c`, `feature/damage.c`.

## Learn legacy runtime errors preserve completed mutations

**Decision:** Phase 3C1 converts division-by-zero, invalid `random()` input, and negative `receive_damage()` points into typed `LearnResult` legacy errors at the exact LPC execution position. Unlike the earlier Selflearn substitution, Learn does not roll back mutations already completed before that point.

**Reason:** `learn.c` has observable mutation-sensitive errors: the raw-zero entry is later than the two intelligence divisions; `learned_points` increments before `random()`; an NPC teacher with a negative gin cost can reach `improve_skill()` and `skill_improved()` before the final negative gin damage errors. Crashing the Godot application is unacceptable, while validating everything before mutation would also change behavior.

**Compatibility impact:** Ordinary Learn behavior is unchanged. Invalid legacy states return a diagnosable result instead of a driver exception, but retain only the raw skill, teacher sen, potential, learned progress, level, or authored effect mutations which LPC had already performed. No minimum intelligence or silent clamp is introduced. Sources: `reference/es2/mudlib/cmds/std/learn.c`, `feature/damage.c`, `feature/skill.c`.

## Learn teacher identity keeps one narrow legacy name field

**Decision:** Native relationships use a stable `TeacherId` (`StringName`) as primary identity, while `ApprenticeshipState` also retains `legacy_master_name` solely for the F_MASTER direct-apprentice predicate.

**Reason:** `learn.c::is_appr_of()` compares master ID plus generation, whereas `feature/apprentice.c::is_apprentice_of()` compares master ID plus persisted master display name and is called by `std/char/master.c::prevent_learn()`. Replacing both with one modern predicate would silently erase a real source discrepancy.

**Compatibility impact:** New content does not use display names as identity, but migrated saves can reproduce the second legacy comparison. The two predicates remain intentionally separate. Sources: `reference/es2/mudlib/cmds/std/learn.c`, `feature/apprentice.c`, `std/char/master.c`.

## Learn runtime facts and randomness are explicit projections

**Decision:** Inventory-based spouse discovery, `present()`/`living()`/`userp()` checks, and `random()` are replaced by typed `TeachingContext` facts plus a deterministic roll supplied by the caller.

**Reason:** These operations belong to LPC inventory/world/runtime infrastructure. The gameplay semantics needed by Learn are only whether this teacher is the spouse, available, a character, awake, and player-style for sen payment, plus a roll satisfying the MudOS range contract.

**Compatibility impact:** Learn retains the original validation order, strict thresholds, player/NPC sen distinction, and random upper-bound formula. The caller is responsible for producing world/relationship facts and a roll `0 <= roll < upper`; Phase 3C1 does not implement their runtime sources. Source: `reference/es2/mudlib/cmds/std/learn.c`.

## Missing Learn policies are explicit

**Decision:** A teacher with no `prevent_learn()` policy has `NO_ADDITIONAL_POLICY` and continues. If relationship fallback requires recognition, a teacher with no recognition policy returns `RECOGNITION_POLICY_ABSENT`; an authored recognition policy whose known dependency is not migrated returns `RECOGNITION_DEPENDENCY_UNAVAILABLE`. An unimplemented authored `valid_learn()` similarly returns `SKILL_LEARN_DEPENDENCY_UNAVAILABLE`.

**Reason:** The mudlib dynamically calls methods which many objects do not define, and does not document the deployed driver's missing-lfun behavior. Prevention is a negative veto and can have an explicit no-veto default; recognition is a positive authorization and cannot be manufactured. Treating every unknown skill hook as the permissive `std/skill.c` default would also erase known authored overrides.

**Compatibility impact:** Teachers and skills whose rules are understood receive explicit policies. “No authored method,” “authored allow,” “authored reject,” and “known dependency unavailable” remain distinguishable. Driver-dependent or not-yet-migrated paths stop with a typed result instead of crashing, silently allowing, or masquerading as a normal authored rejection. Sources: `reference/es2/mudlib/cmds/std/learn.c`, `std/char/master.c`, `std/skill.c`, and the representative teacher/skill daemons listed in `PHASE_3C1_LEARN_CORE.md`.

## Hand-slot state has one native authority

**Decision:** `EquipmentState` exclusively owns the native primary and secondary weapon slots. `EquippedWeaponRef` uses a stable runtime instance ID plus an immutable scalar definition snapshot; the migration does not reproduce the LPC combination of character `query_temp()` object references and a separate mutable item-side `equipped` marker.

**Reason:** The duplicated LPC representation is tied to object environments and dbase/runtime APIs. Recreating both halves would add a compatibility layer and permit divergence without adding gameplay meaning. Stable identity and one authoritative typed state preserve all confirmed slot selection, duplicate, wield-order, and unwield behavior.

**Compatibility impact:** Phase 4A1 transition outcomes match `feature/equip.c`, including secondary-only and two-handed quirks. Later Inventory must enforce cross-owner instance identity and translate move/transfer into an explicit unwield transition; it must not introduce a second authoritative equipped flag. Sources: `reference/es2/mudlib/feature/equip.c`, `cmds/std/wield.c`, `cmds/std/unwield.c`, `feature/move.c`, `std/item.c`.

## Native item persistence preserves the complete represented domain state

**Decision:** Native item schema version 1 snapshots every represented live `ItemInstance`, its exact `InventoryState` own weight and direct parent, `CombinedStackState.amount`, and per-character Equipment/Armor instance references. Restore validates the complete snapshot and reconstructs fresh aggregates all-or-nothing. It does not reproduce LPC's autoload-only inventory loss or replay gameplay transfer/wield/wear operations.

**Reason:** Legacy `F_SAVE` serializes user fields but not ordinary inventory objects. `feature/autoload.c` separately recreates only selected direct inventory objects, and generic hand/armor slot state is not restored. The native domains already own stable instance identity, recursive containment, stack amount, and equipment references; discarding them would make native saves incomplete and would reproduce a runtime limitation rather than gameplay semantics.

**Compatibility impact:** Native saves retain ordinary and nested items plus generic hand/armor state that LPC logout did not retain. Immutable weapon, armor, and stack facts are rebuilt from current definition projections, while saved current own weight is preserved exactly. Legacy autoload is handled by the separate Phase 4B5D one-way importer. Sources: `reference/es2/mudlib/feature/autoload.c`, `feature/save.c`, `obj/user.c`, `cmds/usr/quit.c`, `std/money.c`, `obj/bandage.c`.

## Schema v1 omits pending combined-stack destruction intents

**Decision:** Native item schema version 1 does not persist a pending one-second combined-stack destruction intent. It snapshots only the amount and own weight observable at capture time and restores the stack as an ordinary live instance without synthesizing a new intent.

**Reason:** `std/item/combined.c::set_amount(0)` leaves the old amount and weight observable and schedules destruction through a non-durable `call_out`. Legacy money autoload therefore saves the old visible amount during that window, and the pending callout does not survive reload. Runtime scheduling is deliberately outside Phase 4B5A.

**Compatibility impact:** A pending positive stack can survive reload with its old positive amount and weight; a raw-zero stack restores with amount zero and its exact saved own weight, without automatically scheduling destruction. A future durable scheduler policy would require a new explicit schema decision. Sources: `reference/es2/mudlib/std/item/combined.c`, `std/money.c`, `feature/autoload.c`.

## Legacy autoload import builds validated data instead of replaying login

**Decision:** Phase 4B5D translates legacy autoload strings in original order into an immutable schema-v1 snapshot candidate and typed evidence, then stops. It does not execute `new()`, `move()`, or `autoload()`, does not replay capacity/merge/callback failures, and does not mutate live aggregates. Source-proven bandage wear is represented in candidate Armor data after direct placement; unsupported entries leave the batch explicitly incomplete.

**Reason:** Executing LPC paths would require a compatibility runtime and could leave partial live mutations before a later failure. Phase 4B5A already defines trusted structural reconstruction as the native persistence boundary. A pure importer can preserve traceable data and sequential authored semantics while allowing application policy to reject or inspect incomplete migrations before explicitly restoring anything.

**Compatibility impact:** Imported direct items can reconstruct even where legacy `move(user)` capacity would have failed, and supported entries remain inspectable without reproducing a prior callback abort. No live state changes until a caller separately accepts the candidate and invokes native restore. Sources: `reference/es2/mudlib/feature/autoload.c`, `obj/bandage.c`, `std/item/combined.c`.

## Legacy zero-money import keeps clone state plus a transient intent

**Decision:** Importing a source-produced money parameter `"0"` creates a candidate stack with amount `1` and one unit of the concrete currency's base weight, then emits a typed one-second destruction intent outside schema v1. The importer does not start a timer.

**Reason:** Each concrete money clone executes `set_amount(1)` in `create()`. Its later `autoload("0")` calls `set_amount(0)`, which schedules destruction but does not assign zero or update weight. Saving raw zero in the candidate would invent a state the executable restore path never exposed.

**Compatibility impact:** If an application accepts this unusual candidate but does not later execute the external intent, the one-unit stack remains live. Schema v1 itself is unchanged and still does not durably persist pending destruction. Sources: `reference/es2/mudlib/std/money.c`, `std/item/combined.c`, `obj/money/coin.c`, `gold.c`, `silver.c`, `thousand-cash.c`.

## Item destruction stops on an unexpected native equipment-detach failure

**Decision:** Phase 4B5B prevalidates structure, then attempts exact hand cleanup followed by exact Armor cleanup. If a referenced instance unexpectedly cannot be removed from one of those native authorities, lifecycle returns a typed failure and does not remove the item's Inventory/stack registration. Any earlier successful hand cleanup is not rolled back and is reported in the result.

**Reason:** `feature/move.c::remove()` logs an `unequip()` failure and continues to driver destruction. Reproducing that continuation in the native split-authority model would remove the item while leaving an impossible authoritative Equipment/Armor reference. Current typed transitions normally succeed whenever their identity predicate was true, so this is an invariant-defense path rather than a new gameplay rejection.

**Compatibility impact:** Structurally valid current states preserve LPC's ordinary cleanup-then-destruction behavior. A corrupted or future custom aggregate that reports an item equipped but refuses exact detach keeps the item live instead of reproducing a dangling-reference defect. The result honestly exposes any cleanup already completed; no invented rollback occurs. A composed multi-sibling stack merge commits each successfully destroyed sibling's positive quantity before attempting the next lifecycle transition, so a later injected detach failure cannot erase an earlier sibling's quantity; normal successful final totals and survivor identity are unchanged. Direct-character lifecycle context must contain both authoritative aggregates—explicit empty states mean empty, while `null` means the authority was omitted and is rejected. Sources: `reference/es2/mudlib/feature/move.c`, `feature/equip.c`, `std/item/combined.c`.

## Death and corpse inventory ordering uses stable instance IDs

**Decision:** Phase 4B5C snapshots a victim's direct item IDs in ascending stable-ID order, evaluates `owner_is_killed` policies in that order, and processes survivors in descending snapshot order to preserve `chard.c`'s reverse loop. Corpse final scatter uses ascending direct-child order.

**Reason:** `adm/daemons/chard.c` snapshots `all_inventory(victim)`, invokes hooks over that array, then walks survivors backwards; `obj/corpse.c` walks its `all_inventory()` array forwards. The mudlib does not define object-chain allocation order as authored gameplay data, but policy destruction and ignored transfer failures make order observably affect partial results. `InventoryState.direct_children()` already supplies deterministic stable-ID snapshots, so the death domain must state how legacy forward/reverse traversal maps to that native order.

**Compatibility impact:** A particular MudOS process may have evaluated or moved items in a different object-chain order. Direct-only membership, policy-before-transfer ordering, reverse survivor concept, per-item partial mutations, final forward scatter concept, and all item formulas remain unchanged. Sources: `reference/es2/mudlib/adm/daemons/chard.c`, `obj/corpse.c`.

## Incomplete synchronous death hooks cannot restart the whole death flow

**Decision:** A death-item hook that requires unavailable native runtime work, or a destruction failure after observable cleanup, returns a typed incomplete result with `DO_NOT_RESTART_FROM_BEGINNING`. Phase 4B5C deliberately provides no generic continuation token or scheduler.

**Reason:** `owner_is_killed()` runs synchronously over one direct-inventory snapshot before survivor movement. By the time a native boundary is encountered, a normal death may already have created/placed a corpse and earlier policies may already have destroyed items or detached equipment. Re-running the complete operation would duplicate or reorder those mutations.

**Compatibility impact:** Future NPC/runtime orchestration must continue from the recorded boundary using current authoritative aggregates; it must not call the whole Phase 4B5C process again. This preserves the LPC ordering without introducing callback dispatch or a runtime workflow engine. Sources: `reference/es2/mudlib/adm/daemons/chard.c`, `daemon/class/scholar/windspring.c`, `feature/move.c`.

## Combat lethal relationships use stable character identity

**Decision:** Native combat opponent, lethal-target, and last-opponent identities use stable `CharacterId` values; guarding remains a targetless boolean. Legacy public `id()` strings remain migration metadata and are not used as the authoritative lethal relationship key.

**Reason:** `feature/attack.c` stores live enemy objects but stores `killer` entries as public ID strings. Different live entities can share a public ID, so reproducing that mixed identity model would let one entity's lethal marker accidentally match another entity and would conflict with the stable identity already used by native relationship state.

**Compatibility impact:** Simultaneous legacy entities with the same public ID no longer share or collide on a lethal marker. Cleanup, selection, friendly-stop eligibility, and all local relation mutations remain source-ordered; only the ambiguous public-ID collision is not reproduced. Sources: `reference/es2/mudlib/feature/attack.c`, `reference/es2/mudlib/adm/daemons/combatd.c`.

## Corpse loot requires a near-corpse spatial range

**Decision:** Phase 8B1 replaces LPC same-room corpse reachability with a map-local circular `LootInteractionRange Area2D` of radius 96 Godot pixels, centered on each runtime corpse view. Corpse selection and Inspect may occur by clicking, but Open Loot and every Take re-evaluate the player's current physical presence in that range. The range fact belongs only to the Old Pine scene/world interaction adapter; Inventory, Corpse, stack, and item Core receive no position or distance rule.

**Reason:** `cmds/std/get.c` and `present(arg, environment(me))` make source reachability depend on sharing one discrete room. The native map is continuous and the current player/corpse bodies are roughly 36 pixels wide, so a 96-pixel circle permits deliberate nearby interaction without extending across the 150-pixel spacing between authored bandit spawn centers. `Area2D` supplies the physical representation and enter/exit notifications; execution also checks current corpse/player positions so a corpse created while already overlapping the player cannot miss its initial range fact.

**Compatibility impact:** A player on the same continuous Godot map but farther than 96 pixels from the corpse cannot Open Loot or Take until approaching it. Once admitted, all item ownership, capacity, corpse-worn, stack merge, and fighting/busy results remain governed by the migrated source rules. Source: `reference/es2/mudlib/cmds/std/get.c`; native scene scale: `game/scenes/world/oldpine/oldpine_outdoor.tscn`.

## Old Pine Outdoor directly connects to the Pine Maze

**Decision:** Phase 9B1 adds one bidirectional, continuously walkable physical threshold between the existing Old Pine Outdoor prototype and the native Pine Entrance zone. It is an RPG geography consolidation, not a `PortalDefinition` and not a claim that the LPC rooms have a direct exit.

**Reason:** The LPC graph has no ordinary edge from the currently embodied Central/North Outdoor area to `pine1`. Its source route is `epath2` vine → `passage` or `waterfall` → River/Cliff → `cliffside` → `pine1`. Requiring that entire chain would block the low-dependency Pine content on conditional skill/RNG traversal, Cave/River authoring, and cross-scene state handoff. Native RPG geography may cluster legacy rooms into continuous maps while retaining their authored identities and meaningful boundaries.

**Compatibility impact:** Players can enter Pine Entrance directly from the current Outdoor map earlier than the LPC topology permits. The Pine-side `pine2 → keep1` and `cliffdown → cliff2` boundaries remain represented but closed, all eight Phase 9B1 legacy room IDs remain traceable, and no new LPC exit is recorded. Sources: `reference/es2/mudlib/d/oldpine/epath2.c`, `passage.c`, `waterfall.c`, `riverbank1.c`, `cliff1.c`, `cliffside.c`, `pine1.c`.

## Random Pine room exits become one fixed continuous maze

**Decision:** Phase 9B1 translates `pine1` through `pine7` and `cliffdown` into one fixed continuous spatial maze with repeated forks, occlusion, a traversable loop, a safe dead end, a reliable route to Pine Cliff Edge, and a reliable return route. There is no ROOM exit emulator, reset-time topology mutation, or navigation RNG.

**Reason:** The Pine rooms use random exit targets to create disorientation within a text-room runtime. `pine1`, `pine2`, and `pine4` through `pine7` rebuild those exits during reset, while `pine3` selects them during create; several fixed links provide an authored skeleton: `pine1 west → pine4`, `pine4 north → pine5`, `pine5 north → pine6`, `pine6 west → pine7`, `pine7 southwest → cliffdown`, plus `pine2 east → keep1`. Reproducing mutable exit tables would port the LPC runtime representation instead of its maze intent and would make physical collision/navigation unstable.

**Compatibility impact:** A given playthrough and scene reload use the same Pine geometry instead of source reset/load randomization. The native layout preserves getting-lost pressure through physical loops, similar branches, barriers, and dead ends while guaranteeing reachability and return. Pine navigation consumes no random source. Sources: `reference/es2/mudlib/d/oldpine/pine1.c`, `pine2.c`, `pine3.c`, `pine4.c`, `pine5.c`, `pine6.c`, `pine7.c`, `cliffdown.c`.


## Snow Martial Progression II — owner-locked P2 boundary

P1 at `c44658ef0e9b557b7a002f4d79ca7bef0fd6b4bd` is OWNER APPROVED / CLOSED.
P2 is authorized on `phase/snow-martial-progression-liuh-ken` only.
The [approved source analysis](PHASE_SNOW_MARTIAL_PROGRESSION_II_SOURCE_ANALYSIS.md)
remains planning authority; this section records the subsequent owner decisions.

| Decision | Locked contract |
| --- | --- |
| D-SMP2-01 | Natural combat_exp >=6, basic unarmed raw >=4, liuh-ken raw >=5, enabled for unarmed. Product acceptance finish, not a source unlock. No automatic reduction. |
| D-SMP2-02 | Explicit Enable/Disable only at valid physical Liu contact: ACTIVE, in range, not paused/fighting/busy. Approved Type B availability substitution, not a source enable restriction. |
| D-SMP2-03 | All four source actions: 古松挂月, 傲雪冬梅, 孤崖听涛, 荒山虎吟; no level unlock. |
| D-SMP2-04 | Full authored text, using committed attacker/victim/limb facts; presentation draws no RNG. |
| D-SMP2-05 | Source dodge/parry metadata is evidence only. No effect on AP/DP/PP, rates, damage or temporary modifiers; CombatActionDefinition and CombatMath do not gain these fields. |
| D-SMP2-06 | Exact reviewed liuh-ken only: known no authored hit effect. Narrow Type B classification; unknown mapped skills remain unavailable. No generic missing-lfun or hook framework. |
| D-SMP2-07 | Reuse generic skill/progression/relation/equipment and three-stream RNG persistence. Root schema2, item schema3, SOURCE_ENTRY_V1 unchanged. Missing required durable state requires owner review. |
| D-SMP2-08 | Attempt full natural EXP6 route on immutable pushed implementation, then mapped combat and full-process Save/cold Continue. No grants, injected XP/stats, favorable production RNG, teleport, enemy/damage/recovery rebalance. If impractical, stop and report the actual acceptance blocker. |

Source-exact Learn ordering, effective skill and primary/secondary weapon distinctions remain Type A.
Select exactly once per attack from the validated current action set, retain all live authority checks,
and compose that selected action into the existing resolver. Each genuine reverse attack reprojects
post-forward live state and draws independently. No singleton-draw optimization or presentation reroll.
Shared responsive/input/layout regressions are required; physical Android/iOS qualification is deferred
to the later owner-authorized Final Audit. No PR, merge, automatic Final Audit, P3 or Migration Tooling
expansion is authorized. All other arts, practice/study, force/techniques, full school/faction systems,
Phase5B4, Lake/serpent and Native generation remain deferred. Type C = 0.

## Snow Martial Progression II — automated functional acceptance

**Owner decision (2026-09-25):** P2 engineering closure uses deterministic automated
production-path verification. This supersedes the live-grind/full-process acceptance
method in D-SMP2-01/08 above, not the gameplay finish or source rules. Genuine prior
[production combat](PHASE_SNOW_MARTIAL_PROGRESSION_II_CHANGED_PATH_LIVE_ACCEPTANCE.md)
already observed EXP0→1; stochastic time-to-EXP6 is deferred to balance/pacing and
usability qualification. Test fixtures may construct exact prerequisite checkpoints
(EXP6/basic unarmed4); these are test-only and never naturally earned live evidence.
No gameplay formula, EXP probability/rule, EXP6 Learn threshold, or unarmed4/liuh5
finish changes. Public Save/Continue with fresh graph reconstruction closes the
functional persistence loop; later human play/Final Audit smoke remains separate.
See the [automated acceptance report](PHASE_SNOW_MARTIAL_PROGRESSION_II_AUTOMATED_ACCEPTANCE.md).

## Generalized Player display names

**Decision (Type B, owner-authorized P2R2):** Replace the historical Chinese-only
display-name restriction with bounded, safe Unicode letter-based names across languages.
Default length is 1–24 code points; attached marks and explicit internal separators
are allowed. Preserve accepted display text exactly, without normalization. Semantic
Character ID remains independent. This is international single-player product compatibility,
not multiplayer uniqueness, account naming or moderation. Source:
[logind.c::check_legal_name](../../reference/es2/mudlib/adm/daemons/logind.c).
The [policy report](PHASE_NEW_GAME_GENERALIZED_NAME_POLICY.md) records rules,
configuration and verification. Birth, gameplay and Save schemas are unchanged.
