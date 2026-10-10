# 泓水南岸 + 山烟寺 content (region plan #8)

How the region comes from `reference/es2/mudlib/u/cloud/sunhill/`, `d/sanyen/`,
`daemon/class/bonze/` and `u/cloud/npc/monk_guard.c`, and what the LPC says that the code does
not. Decisions are in [DECISIONS](DECISIONS.md). Package A places the rooms and the people with
the arts they fight with, the boat and the kitchen; B 山烟寺 the family (剃度, 玄智's teaching,
the player's 大乘佛法, 诵经, 流云杖法, 莲华心法 and its 疗伤他人, learning 八识神通); C the player's
神通 (空识, 心识, 游识).

## Placed (A)

| Room | LPC `set("objects")` | Native |
|---|---|---|
| u/cloud/sunhill/northriver, midriver, southriver (泓水北侧, 江心, 泓水南侧) | — | mountain map (日照山): the ford across the river from 绮云镇's 江北渡口 (its south exit opens) |
| sunhill/dukou (江南渡口) | — | the south bank and the jetty where the boat puts in |
| sunhill/road1–4 (山脚小路, 盘山小径 ×3) | — | the yellow-earth path up the hill; road1's east to 乔阴县城's 北门 stays closed (#9) |
| d/sanyen/sroad1, sroad2 (山路) | — | the mossy stone road under the cliff carved 「山烟寺」 |
| gate (山烟寺山门) | 知客僧 ×2 | the clearing before the gate; north into the temple (its own map) |
| tunnele, tunnel (隧道口, 隧道) | — | the tunnel west through the cliff to 晚月庄's sroad5 (its east exit opens) |
| front_yard (山烟寺前广场) | 护寺武僧 ×2 (front_yard.c repaired) | temple map (山烟寺): the yard ringed with poplars, the bricks |
| door (山烟寺寺门), road1 (石板大道) | —; 独眼头陀 | the gate house; the flagstones between peonies to the 金门 |
| road2 (石板小径), drug_field (药圃) | 僧人; — | the small path east and the herb plots |
| temple (大雄宝殿) | 玄智和尚 (daemon/class/bonze/master.c) | the hall: the Buddha on his lotus throne, the censer; the 金门 south |
| inner_yard (庭园), heal_room (流云轩) | 跛僧人; 药僧 | the garden west of the hall, 流云轩 north of it (the plaques: look) |
| corridor, corridor1 (走廊) | — | behind the yellow curtain north, and west along 流云轩's wall |
| kitchen (香积厨) | 烧饭僧 | the stoves, the pot and the steamer |
| back_temple (后殿), tower (塔林) | 小沙弥; 扫地僧 | 药师如来 and the eighteen arhats; the two pagodas |

## LPC → native (A)

| LPC | Native |
|---|---|
| front_yard.c's `__DIR__"npc/monk_guard"` (no such file) | overrides `source_fixes` → /u/cloud/npc/monk_guard (owner, plan Q2) |
| u/cloud/npc/boater.c accept_object() | npcs.json `accept_object` (set cloud.npc.boater): value() of 2 coins and up says his two lines and `move`s the giver to 江南渡口 (sunhill.dukou.ferry_arrival); less is refused with his say() (owner, plan Q1); 过江 and 摆渡 answer 交两文钱 (owner) |
| sunhill/northriver.c init(), cross_river(), no_boat() | nothing: replace_program(ROOM) drops them; the river is waded both ways, as ES2's was |
| road1.c / temple.c create_door() 金门 | world.json doors `sanyen.road1.door`, open |
| heal_room.c item_desc plaque, kitchen.c item_desc pot | look landmarks |
| kitchen.c do_open(), do_take(), reset() | service `sanyen.kitchen.steampot` (kind act, 蒸笼 · 打开) with an act branch `present` the cook; the 蒸笼 landmark (policy take, limit 5, `guard` the cook, `guarded`); a cook lying unconscious stops nobody (默认) |
| accept_fight() by the challenger's class (master.c, monk_guard.c, u/cloud/npc/monk.c) | accept_fight rules `class` (NpcFightRule) |
| cripple.c, monk.c chat_msg_combat `(: random_move :)`, `(: command, "sigh"/"hehe" :)` | chat_msg_combat `random_move` (CombatNpcChat._walk_out(): not while busy, NpcRandomMove.choose_with() on the fight's draws, go.c's 往X落荒而逃了。; CombatEncounterResolution.depart(): out of the fight and in the next room at once; after the fight WorldMapNpcLife.walk_out() walks the body there) and `emote` (nothing) |
| skills cloudstaff, lotusforce, buddhism, chanting, essencemagic | skills.json (their valid_learn policies were already in code); 莲华心法's exert heal is std heal.c's |

## LPC → native (B)

| LPC | Native |
|---|---|
| master.c ask_for_join() (剃度, 出家) | inquiry rules (NpcInquiryRule `asker_class`, `asker_gender`, `temp_asker`): a monk, a woman, else the temp pending/join_bonze |
| master.c init() kneel, do_kneel() | npcs.json `ordination` (NpcOrdination): the 跪下受戒 button on the 打听 panel (asked first), its HIC lines, the say with the 法名, name (WorldPlayerRuntimeState.take_name()) and class bonze |
| master.c attempt_apprentice(), do_recruit(), recruit_apprentice() | apprentice rule: answer_after 2, busy_say, checks gender 男性 then `class` bonze (RequirementCheck.class_id), class bonze |
| std/char/master.c prevent_learn(), learn.c | f_master and the family as in A: he teaches his twelve skills to his own |
| buddhism.c, essencemagic.c, lotusforce.c, cloudstaff.c valid_learn() | SkillLearnPolicyRegistry (already in A) |
| cloudstaff.c, lotusforce.c practice_skill() | skills.json practice (a staff and 60 kee; 莲华心法 refuses) |
| lotusforce/heal.c | heal (fonxanforce's, word for word) |
| lotusforce/lifeheal.c | LifehealExertFunction (`targets_other`): the HUD's 疗伤他人 on the selected NPC (PlayerMartialArts.exert_at()) |

## Source anomalies

- front_yard.c places `d/sanyen/npc/monk_guard`, which does not exist (the 护寺武僧 is
  u/cloud/npc/monk_guard.c): ES2's reset() failed on new() and the yard stood empty, while
  朱鸿雪's quests name 护寺武僧 (qlist3000, 5000, 8000). Repaired (owner, plan Q2).
- monk_guard.c's long is a 知客僧's (「知客僧伫立在佛像前…」), word for word here; so is
  u/cloud/npc/monk_waiter.c (a 知客僧 nothing places).
- northriver.c's ferry is dead: create() ends in replace_program(ROOM), and cross_river() reads
  the room's own marks/船夫, which nothing sets. boater.c's 过江 asks five taels (here
  交两文钱, owner); its accept_object() takes anything worth 2 coins and sets the giver's marks/船夫, read by nothing;
  a second gift while marked was thanked for (多谢这位<the gift's respect>) and unmarked.
- road1.c creates the 金门 open, temple.c DOOR_CLOSED; check_door() gives the second room loaded
  the first one's state, and whoever comes by the road loads road1.c first. The hall's text
  says 两扇敞开的金门.
- The rooms' words and their exits disagree: gate.c 山烟寺在你的西面 (it is north),
  front_yard.c 东边则是山门 (south), sroad1.c's south and north, sroad2.c's east tunnel (the
  tunnel is west of the gate). The maps follow the exits; the words stay.
- monk.c sets `aplpy/defense` (misspelt): no defense bonus. Its `pursuer` is not modelled yet.
- master.c's recruit_apprentice() lowers the misspelt `apprentice_availavble`: his ten a day
  never run out.
- Lost characters: master.c's 请□到尼庵 (妳: 请你), lifeheal.c's 震□ (盪: 震荡), heal_room.c's
  donor 克□□ (written 克某某).
- daemon/class/lama/master.c (龙若法王, placed by nothing) copies master.c's 剃度 word for word
  inside a /* */ block: dead in ES2.
- essencemagic.c has no practice_skill(): practising 八识神通 says 并没有任何进步.
- d/sanyen/obj/ copies npc/obj/ byte for byte; 黄铜禅杖 (brass_staff.c) and monk_waiter.c are
  placed by nothing. The temple's bulletin board (bonze_b) is for players' posts.
- `doc/skill/essencemagic` names eight 识; essencemagic/ holds three (drift, heart, void) (C).
