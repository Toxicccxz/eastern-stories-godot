# 晚月庄 content (region plan #7)

How 晚月庄 comes from `reference/es2/mudlib/d/latemoon/`, `daemon/class/dancer/` and
`u/cloud/npc/lm_guard.c`, and what the LPC says that the code does not. Decisions are in
[DECISIONS](DECISIONS.md). Package A places the rooms and the people with the arts they fight
with, and the dances in the two 密室 (the only way out of the second one); B the women's
quarters and the rooms' own commands (done); C the secrets (竹蜻蜓 and 玛瑙手镯, 舞曲谱, 杀手令牌,
芙云's 密函; done); D 晚月庄 (蓝止萍 and 瑷伦, the teachers, the player's arts; done).

## Placed (A)

| Room | LPC `set("objects")` | Native |
|---|---|---|
| entrance (碎石小径) | 彩衣少女 ×2 (u/cloud) | manor map: the cobbled path from 绮云镇's west end (wroad0) to the 拱门 |
| gate (晚月庄大门) | — | the forecourt inside the pale green wall, the lanterns (look) before the red main door |
| front_yard (前庭) | — | the front garden, its rockery and flowers; south to the 湘园 (its own map) |
| latemoon1 (大厅), latemoon3 (傍厅) | 婢女 ×2, 蓝止萍; 蓝雨梅 | the hall (tables, screen), the reception room (the teapot: water) |
| latemoonc (大厅后院), latemoon5/7 (后院走道) | — | the plum courtyard and the galleries round it |
| latemoon6 (禁闭房), latebook (后院书房), latemoon8 (密室) | 芳绫; 昭仪 | behind the 铜门 (the wall: look); the study (the 湘绣舞曲图: look, names both dances); behind the 石门 the 密室 (its 八卦图: the dances) |
| latemoon4 (内厅穿堂), latemoon2 (内厅) | —; 昭蓉 | the passage; behind the 仪门 the inner hall (the closet: B) |
| room/twoc (仪门), two1/two2 (夹道), guest1/guest2 | 芙云; 梦玉楼 | the crossing; the guest wing |
| room/eat1, eat2, kitchen | 宫保鸡丁, 水饺 ×2; 女儿红, 脆皮烤鸭; 曲馥琪, 火摺 | the dining halls and the kitchen |
| room/lcenter (后厅), lstudio, room4 (内书房) | 圆春, 苗郁淑; 无名老妇, 杀手; 婢女, 惜春 | the rear hall behind its great door, the two studies |
| room/lroad1, lroad3, eroad1–2, wroad1–2 | — | the corridors to the wings; stairs up (lroad3 northup, wroad2 southup) |
| room/eastroom, westroom | 婢女 + 瑷伦; 婢女 + 安妮儿 | the wings behind their carved doors |
| room/corridor7 (内厅), flower1 (内厅穿堂) | 虞琼衣; 龙韶吟 | behind the 垂花门 the women's passage; south one way into the secret rooms |
| room/bathroom1 (沐浴更衣室), bathroom (小花池) | 阮欣郁 (no_fight); 凤凰, 金仪彤 | behind the 小帘门, the changing room and the pool (water) |
| miroom2 (内厅), miroom (密室) | 蓝筱薇; 丝罗巾 | secret map: one way in from flower1; the second 密室 behind its 垂花门, its 八卦图 (西出阳关 out) |
| park/yard1 … moondoor (16 rooms) | 金丝雀 ×2 + 美珊 (moon4), 采花少女 ×4 (moon5), 上官钰翎 + 小金鼠 (moroom), 小白兔 ×2 (paroad2), 袭人 (pavilion1) | garden map: the pond with its bridges and pavilion, the osmanthus garden, 稻香榭 (the sign: look), 暖香榭, the back gate |
| upstar/ (10 rooms) | 金丝雀 ×2 (uplook), 区冥 (uproom), 莫欣芳 (uproom2), 邢千慧 + 雪花糕 (uproom3) | upper map: the galleries, the 佛堂, 翠湘阁, 缀芳阁, the 前堂楼 and the 观景台 (jump: down to the 湘园's forecourt) |
| sroad1–5, bamboo, bamboo1–4 | 蝴蝶 (sroad4, sroad5), 竹子 (bamboo4) | hills map: the path from the back gate (sroad1.c repaired), the closed tunnel east to 山烟寺 (#8); the grove's five clearings, each way out a passage |

## LPC → native (A)

| LPC | Native |
|---|---|
| sroad1.c's missing quote | overrides `source_fixes` (owner, plan Q1); the importer repairs the source before lexing |
| upcenter.c's replacement character | a lost character inside a string is □ (es2_source.py); text_replacements.json decides it |
| d/latemoon/npc/ and room/npc/ files of one name (servant, guest, shinyu, shiren, bird) | NPC ids keep the subdirectory (`latemoon.npc.room.servant`); a clash is an import error |
| create_door() (14 doors in 27 rooms) | world.json doors, all DOOR_CLOSED; eastroom's and westroom's side call theirs 雕饰房门, named from the corridor (雕饰厢门) |
| latemoon8.c, miroom.c do_dancing() | world.json services of kind `dance` (DanceDefinition, DanceService): the gender's check and cost first, then the dance or 不得要领 |
| latebook.c item_desc dragon-dance | a look landmark that `teaches` the marks dance_out and dance_yu_fong |
| yumay.c inquiry 学舞, girl.c inquiry 有凤来仪 | the same answers with `mark_asker` (dance_out, dance_yu_fong) |
| girl.c show_dance(), show_dragon() | inquiry rules: the tell_object() lines, then ask.c says the return |
| yumay.c, zauron.c, shaowei.c greeting() | `greeting` one_of the two lines (the tea cup: B) |
| master.c use_poison() | chat_msg_combat `poison` (NpcFightChat.Poison) |
| master.c exert chillgaze, daemon/class/dancer/iceforce/chillgaze.c | ChillgazeExertFunction (ExertContext.offensive, vision_at/vision_by) |
| iceforce.c hit_ob() | skills.json `force_hit_wound` (ForceHitWound), after StandardForceHitPolicy in CombatAttackResolver |
| daemon/condition/rose_poison.c, iceshock.c | RosePoisonConditionEffect, IceShockConditionEffect |
| shaoin.c hit_ob() | npcs.json `hit_ob` (NpcHitCondition) |
| set("rigidity") on the whips | items.json `weapon.rigidity`, read by bash_weapon() |
| set("no_drop") (丝罗巾; 舞曲谱, 玛瑙手镯 in C) | items.json `no_drop`: drop.c, give.c, put.c refuse |
| resource/water (latemoon3, bathroom) | water services |
| skills tenderzhi, snowwhip, iceforce, snowshade-force, snowshade-sword, whip | skills.json (their valid_learn policies were already in code) |

## LPC → native (B)

| LPC | Native |
|---|---|
| greeting() by gender and class (shinyu.c, shaoin.c, yuchoun.c, yushou.c, fireangel.c, upstar/npc/statue.c) | npcs.json `greeting.rules`: the first branch for the player (ScriptedAct: `gender`, `not_gender`, `not_class`) and its steps in order, run by WorldMapActs one second after the player arrives |
| say() in HIY/HIR/HIM | a step's `line` with its `color` (NpcLine) |
| receive_damage(), apply_condition(), this_object()->add("force") | steps `damage`, `condition` (replaces the one there), `npc_force` |
| command("close door") (cmds/std/close.c) | step `close_door`: the door between the room and the one the player came from, else the room's first; one already shut stays so |
| ob->move("/d/latemoon/room/flower1") | step `move` to the spot `latemoon.room.flower1.kicked_out` |
| kill_ob(ob); ob->fight_ob() | step `kill` (WorldMapHostilities.npc_kills) |
| yumay.c's teacup and set_temp("latemoon/茶") | step `give` with `unless_temp`; the player's `temp_marks` (not saved) |
| latemoon3.c valid_leave() | world.json `exit_rules` `takes_back` (the cup and the flag; 你起身往南离开! without a cup) |
| bathroom.c do_takebath(), upstar/uproom3.c do_ponder() | world.json services of kind `act` (RoomActDefinition, ActService): the branch for the player; a man asked before bathing; a cost that would knock the player out asked first |
| moonc.c do_pick(), latemoon2.c do_take("cloth") with reset()'s counts | landmarks of policy `take` (`limit` 2 since the room's reset, `reward`, `take`, `empty`); a room with such a landmark is on the reset schedule (moonc.c has no objects) |
| flower.c do_eat() | items.json `apply: rose_pistil` (ItemApplyFunctions, the 吃 button) |
| skirt.c, skirt4.c, skirt5.c wear() | items.json `female_only` with `wear_refusal` (只有女生才可穿哦!你变态呀!) |
| a man walking into bathroom1 (owner, plan Q2) | world.json `exit_rules` `ask`: stopped in 内厅穿堂, asked with 此处是禁止男性进入, put at `latemoon.room.bathroom1.curtain_arrival` on 确定进去 |

## LPC → native (C)

| LPC | Native |
|---|---|
| shaowei.c accept_object() and make_stage() | npcs.json `accept_object` (set latemoon.npc.shaowei): a 竹子 sets the temp moon/竹子 and starts the rule's `make` (NpcMaking: five HIY lines two seconds apart, the 竹蜻蜓 with the last; WorldMapNpcLife call_out kind `make`); a second 竹子 goes back; anything else is thanked for and kept |
| funlin.c accept_object() | `accept_object` (set latemoon.npc.funlin): the 竹蜻蜓 for her four lines and the temps moon/问题二, moon/竹蜻蜓 (`set_temps`) |
| latemoon2.c do_search("bracelet") | world.json service `latemoon.latemoon2.search` (kind act, 碧纱橱 · 翻找): branches `not_temp` moon/问题二, `temp` latemoon/手镯, then `give` the 玛瑙手镯 `unless_temp` latemoon/手镯 |
| bracelet.c do_pray("start") | items.json `act` (祈祷): the line, 50 sen, `move` to Snow's temple (a handoff from another map) |
| shinfun.c do_reply() | `inquiry` 舞曲谱 with `mark_asker` dance-book (a saved mark) |
| latemoon8.c do_search("bed") | world.json service `latemoon.latemoon8.bed` (kind act, 石床 · 翻找): with the mark the 舞曲谱 and `unmark` dance-book |
| obj/book.c set("skill"), do_dance("home") | items.json `study` (music, 音律, to 60) and `act` (跳「春宫怨」): the line, 50 sen, `move` to the hall (latemoon.latemoon1.dance_arrival) |
| obj/hankie.c set("skill") | `study` (move, 基本行动, to 50) |
| old.c accept_object() | `accept_object` (set latemoon.npc.room.old): `item_alias` ###token###; a 晚月庄 member below 160 max_force gets `effect: pass_force` (NpcObjectRule.passed_force(): random(50) or random(what is short), at most 20, times kar / 30; force 0), anyone else the 寒雪鞭法 (`gives`) |
| room/npc/obj/letter.c do_fire() | items.json `act` (用火烧): `carries` fire (the 火摺) for the HIY and HIM lines, else 你身上没有火没法烧。 |
| daemon/skill/music.c, move.c | skills.json `music` (音律, knowledge; skill_improved(): spi +2, as the registry already had) and `move` (基本行动) |

## LPC → native (D)

| LPC | Native |
|---|---|
| master.c attempt_apprentice(), do_recruit(), recruit_apprentice() | npcs.json `apprentice` (set common.npc.dancer.master): `answer_after` 2 with `busy_say` (as 林忌's), the 女性 check with its say, `accept_say`, `accept_vision` (message_vision() for per above 25 under 20), class dancer |
| master.c reset() | nothing: temp learned is read by nothing, and apprentice_available never runs out |
| elon.c attempt_apprentice() | `apprentice` kind trial (set latemoon.npc.room.elon): `requires` 100000 combat_exp, then 女性, each with its say; then `commoners_only` (要叛师！！！ shouted, kill_ob(); the panel asks first); then `ask_say`, `ask_tell` |
| elon.c do_accept(), init() | the panel's 接受测试 for whom the checks pass (asked first): three `blows` (the first's `fail` empty), `success`, the recruit; `title` 晚月庄第一代弟子 (NpcApprenticeship.member_title(), 默认) |
| annihi.c attempt_apprentice() | `apprentice` kind refuses: its say |
| std/char/master.c prevent_learn() | FMasterTeacherPreventionPolicy (already): both masters are F_MASTERs; the fourteen other members (privs -1) teach any member |
| tenderzhi.c practice_skill() | skills.json practice `sen_first` (VitalityInnerForcePracticePolicy: sen right after the weapon) |
| chillgaze.c for the player | ExertFunction `aims`: CombatExertTacticalPolicy takes the current target (CURRENT_HOSTILE, none accepted: offensive_target()); ExertContext `name_of` names it in the player's lines |
| iceforce.c hit_ob() for the player | the player's attacks carry the mapped force's `force_hit_wound` as an NPC's do |

## Source anomalies


- sroad1.c does not compile (a missing quote): ES2's back gate and the path's north-west led
  nowhere, and the paths and the grove were reached only by dancing out (repaired, plan Q1).
- flower1.c's south exit leads into miroom2.c, which has no exit back north: the secret rooms
  are entered one way and left by dancing 「西出阳关」 in miroom.c.
- `npc/obj/` copies `obj/` byte for byte except book.c: npc/obj/book.c is a 舞曲谱 of
  stormdance (max 10) that dances one to latemoon8; nothing places it. obj/book.c (music, max
  60, back to the hall) is the one latemoon8.c's search gives (C).
- npc/sell.c and sell1.c (颜慧如, a vendor) are placed by nothing; their order list names
  /d/latemoon/sell/skirt, boots and pill, which do not exist.
- Placed by nothing: npc/shaode.c (蓝小蝶), room/npc/fong.c, jane.c, tenlon.c, aaa.c (a copy of
  於兰天武), npc/fuyun.c, guest.c, shinyu.c, shiren.c, bird.c, dodo.c; obj/dress.c, gold_token.c.
- latemoon2.c's do_take() makes a 大蟑螂 only for `take` with another word than cloth: nothing
  in the game types one (owner: not placed).
- tenlon.c's greeting() calls itself 芙云 (copied from fuyun.c).
- skirt2.c sets `rmor_prop/dodge` (misspelt): the 青绫绸裙 gives no dodge. obj/wine.c sets
  `drunk_bonus`, which liquid.c does not read (it reads drunk_apply): the 女儿红 makes nobody
  drunk. girl.c sets `san`, fireangel.c `nick`: nothing reads either.
- tguest.c wears the 杀手令牌 (an ITEM: wear() is not there and nothing happens): carried. It is
  the same token.c as the 杀手's, so 无名老妇 takes 梦玉楼's too; she takes every token, each time
  force or another 寒雪鞭法 (old.c deletes nothing: the delete_temp lines are comments).
- bracelet.c's init() adds do_pray (and letter.c's do_fire) without checking that the player
  carries it (the braces are missing): anyone in a room where one lay could pray with it. Here
  only its carrier has the button.
- obj/book.c's skill sets `class` dancer, which study.c does not read: anyone with 5000 combat_exp
  reads 音律 from it. Its 『 春宫怨 』 takes the reader home to the hall; npc/obj/book.c's (not
  placed) to the 密室.
- miroom.c's do_get() costs 50 sen only for `get dance-book`, which names nothing there.
- book.c's init() adds `dancing` for anyone in its room too, and its do_dance() swallows every
  word but `home`: right after the bed gave the book, latemoon8.c's `dancing out`/`yu-fong` did
  nothing (MudOS runs the newest add_action first). Here the floor's dances and the book's
  「春宫怨」 are separate buttons.
- Inline colours are printed plain (one colour a line, 晚月庄 A): the HIC 玛瑙手镯 in
  latemoon2.c's $n, the HIM 『 春宫怨 』 in book.c.
- old.c's inquiry key `trouble` is English: asked as 心事 (默认).
- master.c's recruit_apprentice() lowers `apprentice_availavble` (misspelt): her ten a day
  never run out (as 林忌's).
- elon.c and annihi.c send whom they refuse to 「芷萍」 (蓝止萍 misspelt): word for word.
- elon.c sets its title after command("recruit"), which only offers to one who had not asked
  her (默认: the title comes with her taking them); a later 拜师 renamed her first generation
  晚月庄开山祖师.
- elon.c's do_accept() checks gender and combat_exp again but not the title: a member of a
  family can take her test and be offered (then 拜师 takes the offer, as recruit.c's first
  branch comes before attempt_apprentice()).
- annihi.c is 东方神教's 教主 but refuses every apprentice and is no F_MASTER; u/cloud's 朱鸿雪 is
  its other member: 东方神教 has no master who takes apprentices.
- elon.c (瑷伦) is generation 0 of 晚月庄 (its founder).
- bracelet.c's pray tells its arrival to /d/snow/inn and moves the player to /d/snow/temple
  (C).
- The two 密室 (latemoon8.c, miroom.c) share their text; miroom2.c shares corridor7.c's.
- bathroom1.c's valid_leave() (rose_poison 5 for whoever is not a 女性 leaving) is dead:
  create() ends in replace_program(ROOM), which drops the file's own functions. ES2 never
  powdered anyone leaving the changing room (owner: not ported).
- flower.c sets rose_poison to 0 for anyone below 10, and rose_poison.c makes a 0 flare once:
  eaten by one not poisoned, the cure gave a bout (the native default leaves them unpoisoned).
- shaoin.c's apply_condition() replaces: a man kicked out by 阮欣郁 (rose_poison 10) and
  greeted by 龙韶吟 after is left with 2.
- skirt.c's wear() reads this_player(): an NPC that wears one at its creation in a room a man
  loaded would have gone without it. The wearer is the one who wears it here.
