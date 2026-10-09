# 茅山 灵心观 content (region plan #6)

How 茅山 comes from `reference/es2/mudlib/d/temple/` and `daemon/class/taoist/`, and what the
LPC says that the code does not. Decisions are in [DECISIONS](DECISIONS.md). Package A places
the rooms and the people; B 茅山派 (林忌's apprentices, 谷衣心法, 天师剑法, 天师正道; done); C the
player's 茅山道术 in a fight and its practice (观想虫; done); D the zombies and the sheets (驱尸,
桃符纸, 僵尸追魂符; done).

## Placed (A)

| Room | LPC `set("objects")` | Native |
|---|---|---|
| sroad (青石官道) | — | mountain map: the broad road from Snow's mountain road (eroad3 east, its drawn steps north), running on south down the hill |
| ladder5–1 (石英岩石阶) | 进香客 (ladder2), 玄真 (ladder1) | the white quartz stairs zigzagging up between rows of pines |
| entrance (灵心观前) | — | the paving before the 山门 (「灵心观」); through the gate is the next map |
| square (灵心观广场) | — | grounds map: the quartz square, the lions and dragon pillars, the censer; the red door north |
| temple1 (大殿) | 林忌, 僵尸侍者, 僵尸护法 | 真武大帝's statue and the altar; round arches east and west |
| corridor1–7 (回廊), inneryard (天井) | 玄和 (inneryard) | the covered walkways round the courtyard (flowers, the well in its north-west corner) |
| temple2 (后殿), trainroom (练功房), restroom1–2 (厢房) | 老道士 (restroom1), 清虚 + 明心 (trainroom) | the rear hall behind its shut red door, the training hall, two guest rooms, each behind its door |
| road1, road2 (青石小径) | road2: reset() draws its guards | the mossy path under the pines round behind the rear hall; the slab by the 藏经楼's door |
| book_room1 (经楼) | — | the 藏经楼's ground floor on the path (bookshelves, the ladder) |
| book_room2 (经楼) | — | library map: the upper floor, 张天师's portrait and the table under its red cloth |

## LPC → native (A)

| LPC | Native |
|---|---|
| create_door() without DOOR_CLOSED (square, corridor7, corridor3, corridor4) | world.json doors with `open`; corridor5's red door starts shut |
| road2.c reset(): `guard_taoist` + (random(3)+1) and `taoist_guard` + (random(3)+1) | six world.json spawns with `draw` groups (InitialSpawnPolicy.DRAWN): one of each group comes at the world's start and at each reset |
| road2.c valid_leave() | exit rule `not_family` (family.maoshan) with `pass_lines` |
| book_room1.c valid_leave() | exit rule `never` with `pass_lines` |
| road1.c valid_leave() | exit rule `kar_slip` (random(kar) < 3): the line, unconcious(), no way through |
| road2.c item_desc slab | a look-only landmark |
| set("class", "taoist") on the NPCs | npcs.json `class`: rankd.c's query_self (贫道) and query_respect in their spar and 打听 lines |
| necromancy/invocation.c | InvocationSpell (召护法): 100 mana, 60 sen, random(max_mana) < 200 nothing, then !random(3) a 天将, else a 阴鬼卒 |
| obj/npc/hell_guard.c | common.npc.hell_guard: a summoned NPC (name_pick 子–亥阴鬼卒, its lines in HIB), 重钢战甲 and 五股钢叉 |
| skills gouyee, taoism, scratching | skills.json (valid_learn lines of the policies already in code); 谷衣心法 hits with std/force.c |

## LPC → native (B: 茅山派)

| LPC | Native |
|---|---|
| taolord.c attempt_apprentice(): call_out("do_recruit", 2), 慢著，一个一个来 while find_call_out() finds it | apprentice rule `answer_after` 2 and `busy_say` (NpcApprenticeship ANSWER_DUE / MASTER_BUSY); the call_out is an NPC call on world time (NpcAmbience RECRUIT), not saved. 慢著 is heard only after 取消拜师请求 and a new 拜师 within the two seconds (a request still open hears 对方还没有答应) |
| do_recruit(): query("gender") != "男性" says 不便收女徒; else 也好 and command("recruit") | `requires` [{gender, refuse_say}], `accept_say`; NpcApprenticeship.answer() runs recruit.c from his side (the request waiting on him is taken; one withdrawn meanwhile is offered). A woman is not asked first and her request stays after the refusal. Only a player before him reads the answer; one lying there is not taken (!living(ob)), but is offered if they had withdrawn; one who walked off finds the request still waiting. An unconscious 林忌 says nothing (unconcious() disables his commands) |
| attempt_apprentice()'s apprentice_available (3) | not ported: the count never ran out (see the anomalies) |
| recruit_apprentice(): ob->set("class", "taoist") | apprentice `class` taoist (道士; rankd.c) |
| trainer.c, tfighter.c create_family("茅山派", 6, "弟子") | privs -1: learn.c lets every 茅山派 member learn from them, anyone else hears reject_msg |
| gouyee.c valid_learn(), practice_skill(), exert_function_file() | max_mana ≥ query_skill("gouyee") × 5 (ScaledMaximumManaSkillLearnPolicy); practice refuses; exert concentrate and heal |
| gouyee/concentrate.c | ConcentrateExertFunction: 运功灵神诀 on the 武学 page and the battle panel (busy 1 in a fight) |
| gouyee/heal.c | fonxanforce/heal.c is the same file: the one HealExertFunction |
| taoism.c | valid_learn 杀气 ≤ 100; practice refuses; a basic knowledge, never enabled |
| scratching.c | valid_learn max_force 80; practice with a sword in hand, 30 kee and 5 force |
| necromancy.c valid_learn() | learnt from 林忌 (or the two 弟子) with 天师正道 at least half of it; practice_skill() in C |

## LPC → native (C: 茅山道术's practice and the 观想虫)

| LPC | Native |
|---|---|
| necromancy.c practice_skill(): query_temp("mind_bug"), mana 10, sen 30, each with its notify_fail() | skills.json `practice` {mana, mana_fail, sen, sen_fail, done}: VitalityInnerForcePracticePolicy's mana (checked before sen), SkillDefinition's practice_refusal_lines; the 观想虫 still standing refuses first (`conjure.standing`), nothing paid |
| write("你闭目凝神...") then random(sen) < 5 (sen after its 30) | `conjure` (PracticeConjuring) on the world's interaction stream: below 5 conjures and practice.c improves nothing; random(0) is 0, so a practice from 30 sen always conjures |
| random(query_skill("spells", 1)) < 10: mind_bug, else mind_beast | `conjure.npcs` [{npc, below 10}, {npc}] |
| bug->move(environment(me)); bug->kill_ob(me); me->fight(bug); set_temp("mind_bug", bug) | a summoned NPC beside the player (SummonedNpc, never a room's), its kill_ob() a lethal fight in which the player only fights back; the player's `conjured_npc_id` (a temp: not saved). Its lines open the fight, the notify_fail() (缠住) before kill_ob()'s 看起来…想杀死你 |
| mind_bug.c / mind_beast.c create(): this_player()'s query_skill("spells", 1) × 500 (× 2000) combat_exp, their bellicosity | npcs.json `conjured` (NpcConjuring), applied as it comes |
| kill_ob() kept after the fight (attack.c is_killing(): hatred in init()) | FLAG_HUNTS_PLAYER: it attacks the player on sight until the player dies before it (damage.c die()'s remove_killer()) |
| (no heal_up(), unlike the 天将) | it stays when the fight ends, unconscious or not, until it dies |
| die(): last_damage_from is the owner: improve_skill("spells", random(spi / 2) + 1) (the beast random(spi) + 1) and its line | the killer the lifecycle finds (last_damage_from); the lines after the fight's result, before killer_reward()'s; 你的「基本咒文」进步了！ on a level |
| die(): anyone else: its two lines and owner->unconcious() | the player falls at once, in the fight too (the 天将 or 阴鬼卒 of 召护法); an unconscious player reads nothing (block_msg) |
| kill.c at an NPC lying unconscious | 攻击 starts the fight; the first wound kills it (char.c). The HUD offered 攻击 there before and nothing happened |
| combatd.c start_hatred(): catch_hunt_msg, kill_ob() | met again (the player came back into its reach), one of the seven lines (world's interaction stream) and a fight in which it alone kills |

## LPC → native (D: 驱尸 and the sheets)

| LPC | Native |
|---|---|
| necromancy/animate.c cast(): not in a fight, a corpse (is_corpse()), 50 mana, its line, then 50 mana and 30 sen | AnimateSpell, cast outside a fight only: the HUD's 驱尸 on the selected corpse in the player's room (no battle-panel button); $n is 某某的尸体 |
| corpse.c animate(): new("/obj/npc/zombie"), set_name(victim_name + "的僵尸"), moved into the room, destruct(corpse) | NpcDefinition.raised_as(): a summoned NPC (SummonedNpc) where the corpse lay, clear of the player's body; the corpse is gone, what it held falls there (owner) |
| zombie.c animate(): set("possessed", who), set_leader(who) | its summoner (killer_reward() passes its kills to the player); FLAG_FOLLOWS_PLAYER: it walks after the player, onto another map too (owner) |
| zombie.c heal_up(): tell, 10 atman and 1 gin while the master has more than 10, else call_out("dispell", 1); end_tag out of a fight: call_out("dispell", 1) | npcs.json `raised` (NpcRaising), run on each heal_up() of the NPC heart beat (nothing taken from a master lying unconscious: DECISIONS); the dispell an NpcAmbience call (`dispell`) |
| zombie.c dispell(): say(), destruct() | its line to its room; gone, no corpse |
| obj/paper_seal.c; d/snow/temple.c's `"/obj/paper_seal": 2` | es2:obj/paper_seal (a combined item, 叠 of 张, `scribe`); two lie in Snow's 城隍庙, a stack of one on each point |
| cmds/std/scribe.c, then haunt.c scribe() | ScribeService and HauntScribe: 画追魂符 on a 桃符纸 row for the selected NPC (skills.json `scribe`); scribe.c's checks (fight, 30 sen, spells enabled), haunt.c's (fight, 20 mana, a name); 20 mana, 10 + 30 sen, 1 kee wounded; one paper becomes 僵尸追魂符（name） (a catalog item for each NPC) |
| cmds/std/attach.c, do_scribe_haunt(), do_haunt() | 贴到…身上 on the sheet's row: the selected zombie standing here, else the first; the named NPC present() in its room: the sheet is used up, its line (RED), kill_ob() and the named one's fight_ob() (a fight the player stands by in: CombatTriggerCause SERVANT_KILL), end_tag (FLAG_SENT), set_leader(dest) (it follows the player no more) |
| do_haunt()'s is_zombie() and query("possessed") | always so: only zombies take a sheet, and every one is the player's |

## Source anomalies



- broom1.c and broom2.c are copies of book_room1.c/book_room2.c (broom2 an empty 书库) that
  no exit leads into: not placed. `d/temple/obj/` duplicates `npc/obj/` (NPCs carry through
  `__DIR__`, which is `npc/`); jade_hat.c and robe1.c exist only in `npc/obj/`.
- taolord.c's recruit_apprentice() lowers `apprentice_availavble` (misspelt), so
  `apprentice_available` stays 3 and 林忌 never runs out of places (the bonze, dancer, fighter
  and lama masters share the typo). Nothing resets it either.
- trainer.c's `cast manimate on corpse` names no spell of 茅山道术, and `cast animate on
  corpse` is refused in a fight (animate.c): in its chat_msg_combat both draws do nothing.
- zombie.c and hell_guard.c set chat_chance but no chat_chance_combat, so npc.c chat() never
  runs their chat_msg_combat: the 阴鬼卒 never says 孽障！随我赴阴司受审吧, the zombie never
  bites (do_bite()).
- 林忌 has 天师剑法 100 but maps no sword skill: he fights with 基本剑法.
- sword.c's hit_ob() acts only on a ghost (is_ghost()); tools/tests checks that no ghost NPC
  is placed before it is ported.
- necromancy/astral_vision.c sets apply/astral_vision, which nothing in the mudlib reads.
- earth-warp.c's sheet sets `attach_func`, which attach.c does not call (it knows only
  do_scribe_haunt); attach.c moves the sheet to /obj/void first, so the sheet is lost.
- attach.c moves every sheet to /obj/void before do_scribe_haunt() runs: one that finds no
  zombie (你往哪儿贴？) or whose call fails is lost too. do_haunt() finds the name anywhere
  (find_player(), find_living()); a name nobody answers to sends the zombie at whoever
  attached it (杀....杀....杀....). scribe.c draws on any carried item and renames a whole
  stack of 桃符纸.
- scribe.c asks for 30 sen and takes 40 with haunt.c's 10, so a player with 30–39 faints;
  animate.c asks only for mana and takes 30 sen.
- daemon/class/taoist/animate.c and haunt.c (outside necromancy/) and d/skill/necromancy/ are
  older copies nothing reaches: necromancy.c's cast_spell_file() and scribe_spell_file() name
  daemon/class/taoist/necromancy/.
- zombie.c animate()'s `time` (spells × 3 + 30) is never read.
- corpse.c decay()'s first case has no break: every rotten corpse would be 腐烂的尸体 (corpses
  do not decay in the game yet).
- old_taoist.c's long says 观心观 (the temple is 灵心观): kept as written.
- trainroom.c's short 练功\房 and taoist.c's 运功\导气 are Big5 artifacts; MudOS reads `\房`
  as 房.
- npc/obj/magic_book.c and spells_book.c have a lost character in a comment
  (`(difficulty - int)*5%`).
- daemon/class/taoist/sword.c's 王□ is a character outside GB2312: 王禅 (owner, default).
