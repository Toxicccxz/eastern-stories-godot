# 晚月庄 content (region plan #7)

How 晚月庄 comes from `reference/es2/mudlib/d/latemoon/`, `daemon/class/dancer/` and
`u/cloud/npc/lm_guard.c`, and what the LPC says that the code does not. Decisions are in
[DECISIONS](DECISIONS.md). Package A places the rooms and the people with the arts they fight
with, and the dances in the two 密室 (the only way out of the second one); B the women's
quarters and the rooms' own commands; C the secrets (竹蜻蜓 and 玛瑙手镯, 舞曲谱, 杀手令牌,
芙云's 密函); D 晚月庄 (蓝止萍 and 瑷伦, the teachers, the player's arts).

## Placed (A)

| Room | LPC `set("objects")` | Native |
|---|---|---|
| entrance (碎石小径) | 彩衣少女 ×2 (u/cloud) | manor map: the cobbled path from 绮云镇's west end (wroad0) to the 拱门 |
| gate (晚月庄大门) | — | the forecourt inside the pale green wall, the lanterns (look) before the red main door |
| front_yard (前庭) | — | the front garden, its rockery and flowers; south to the 湘园 (its own map) |
| latemoon1 (大厅), latemoon3 (傍厅) | 婢女 ×2, 蓝止萍; 蓝雨梅 | the hall (tables, screen), the reception room (the teapot: water) |
| latemoonc (大厅后院), latemoon5/7 (后院走道) | — | the plum courtyard and the galleries round it |
| latemoon6 (禁闭房), latebook (后院书房), latemoon8 (密室) | 芳绫; 昭仪 | behind the 铜门 (the wall: look); the study (the 湘绣舞曲图: look, names both dances); behind the 石门 the 密室 (its 八卦图: the dances) |
| latemoon4 (内厅穿堂), latemoon2 (内厅) | —; 昭蓉 | the passage; behind the 仪门 the inner hall (the closet: look) |
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
- tguest.c wears the 杀手令牌 (an ITEM: wear() is not there and nothing happens): carried.
- master.c's recruit_apprentice() lowers `apprentice_availavble` (misspelt): her ten a day
  never run out (D, as 林忌's).
- annihi.c is 东方神教's 教主 but refuses every apprentice and is no F_MASTER; u/cloud's 朱鸿雪 is
  its other member: 东方神教 has no master who takes apprentices.
- elon.c (瑷伦) is generation 0 of 晚月庄 (its founder).
- bracelet.c's pray tells its arrival to /d/snow/inn and moves the player to /d/snow/temple
  (C).
- The two 密室 (latemoon8.c, miroom.c) share their text; miroom2.c shares corridor7.c's.

## Waits for B, C and D

`tests/runtime/latemoon_test.gd` `_test_waiting()` fails once each of these is ported:
the women's quarters' greetings (阮欣郁, 龙韶吟, 虞琼衣, 苗郁淑, 凤凰, 区冥), the bath, the
powder, the closet, the 海棠's pistils, 缀芳阁's ponder and the skirts' own wear() (B); 芳绫's,
筱薇's and 无名老妇's accept_object() and 莫欣芳's 舞曲谱 (C); 蓝止萍's and 瑷伦's apprentices (D).
