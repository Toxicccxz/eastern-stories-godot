# 卧龙岗 + 绮云镇 content (region plan #3)

How 卧龙岗 and 绮云镇 come from `reference/es2/mudlib/u/cloud/` (and `u/cloud/dragonhill/`), and
what the LPC says that the code does not. Decisions are in [DECISIONS](DECISIONS.md). Package
3A (streets and shops) places every room and every NPC the rooms name; 3B makes 振远镖局
joinable; 3C brings 朱鸿雪's quests, 3D the 宝官's betting; the ferry (region plan #8) comes later.

## Placed

| Room | LPC `set("objects")` | Native |
|---|---|---|
| dragonhill/nroad, nhillfoot, shillfoot, sroad | — | outdoor map: the road over the ridge, north of the town's gate; nroad north to Snow's 雪亭镇街道 |
| dragonhill/hummock (卧龙岗) | 卧龙岗强盗 ×2 | the toll (`attack_unless_mark` 强盗), one fight together |
| entrance, cross, the markets and streets | 县城官兵 ×2 (nwroad3) | outdoor map: the gate, the market street and the main street, one open road |
| butchery | 郑屠夫, 苍蝇 ×6 | vendor: 生牛肉, 牛腿, 牛尾, 熟杂碎, 狗肉 |
| tearoom, tea_corridor (木雕门), tearoom2 | 茶博士; 弈者 (upstairs) | 香茗坊; its second floor on the upstairs map |
| woodboxy, god1 (木门), god2 | 林三爷, 伙计 ×8; 朱鸿雪 | 3C: 朱鸿雪 gives quests (任务, god.c give_quest()); she refuses spars and is not fightable yet (her arts) |
| tailory, zaihuoy, drugstore, weapony, bookstore | 裁缝, 杂货贩, 药店伙计, 兵器贩子, 潘若秋 | vendors |
| monky (斋院) | 化缘和尚, Snow's 乞丐 ×2, 包子 ×3 | the monk takes donations (keeper.c's formula); not fightable yet |
| jiyuan, jiyuan2 | 鸨母; 李师师 (upstairs) | 李师师 teaches literate after a keepsake |
| duchang, duchang2 | 宝官 | 3D: money given to him is a bet (押小: 20% pays double) |
| marry_room | 媒婆 | 3D: no marriage (it needs a second player); she answers about 婚约 |
| park (张家花园) | 飞贼 | steals silver from arrivals (thief.c, steal.c) |
| biaoju | 陈剑秋, 趟子手 | 3B: 陈剑秋 takes apprentices with cor 25 (class guardman) and teaches his seven skills; 趟子手 teaches the family's members; 春风快意刀 is practised with a blade |
| rich, m_house | 保镖 ×5; 张百万, 家丁 ×2 | |
| eroad4 (茶场) | 茶工 ×6 | wander |
| dukou (江北渡口) | 船夫 | the crossing waits for #8 |

## Source anomalies

- The u/cloud files are hard-wrapped at 80 columns, line breaks inside strings included
  (gangster.c, butcher.c, room_gua.c); the importer drops them.
- northriver.c's ferry code is dead: `replace_program(ROOM)` in create() discards its init(),
  and it checks the room's own `marks/船夫`. ES2's river is crossed by walking south.
- boater.c's 过江 answer asks for five taels; its accept_object() takes anything worth 2 coins.
- 宝官's betting is accept_object() (押小, 20% wins double); duchang2.c's `bet` is a TODO that does
  nothing, though its sign promises two taels for one.
- mei_po.c's do_unmarry() tests `if (have_marry = 0)` (an assignment, never true), so a partner
  without a 婚约 is still asked to agree.
- LPC `value()` exists only for money, so 李师师 refuses money and takes any other thing (from a
  man with per 25 or more) as the keepsake.
- 说文解字 teaches literate, but study.c refuses anyone illiterate (literate 0).
- monk.c's greeting() is never called (no init()); its refusal of a gift without value is
  replaced by give.c's own line.
- gangster.c's greeting() has no presence check; the chess player gives his whole stack of 棋子
  when he loses (`give chess`), saying it is two.
- The seller gains a 飞镖 on half the arrivals (init()); not modelled. The weapon shop lists its
  飞镖 at 0两黄金 (vendor.c price_string(0)), which buy.c then refuses to sell (the port does not
  list it: DECISIONS, modern fixes).
- entrance.c's notice asks a gold tael toll that no code takes; m_house.c says 常人可进不来 and
  lets anyone in. room_gua.c's 镇关西 answer speaks of 雪亭镇.
- jiasha.c sets `male_only`, which wear.c does not read. sword_book.c does not compile (and is
  sold by nobody). teacher.c is a copy of butcher.c; goddd.c of god.c; beggar.c of Snow's, with
  a lost glyph; lm_guard.c, monk_guard.c and monk_waiter.c are placed by 晚月庄's entrance
  and 山烟寺's front yard, not by any u/cloud room (26 of the 32 NPC files stand here).
- spring-blade.c's □伤 is the case label combatd.c also has (割伤's branch).
- apprentice.c's help says a betrayer's skills are halved; neither apprentice.c nor recruit.c
  does it (only score 0 and betrayer + 1). An NPC master recruits through recruit.c.
- b_header.c's accept_object() returns 1 in every branch, so give.c hands the thing over: 陈剑秋
  keeps whatever he is given (money is destructed). The port hands back what he refuses
  (DECISIONS, modern fixes). His 淳风武馆 answer is 柳淳风's, word for word.
- grass.c's 忘忧草 gets its master_id only in lion.c's die() (乔阴县城); until then every 忘忧草 a
  member gives him is 这不是你得到的吧. 柳绘心 (d/snow girl.c) is of 封山剑派北宗, not 封山剑派,
  so look.c names no relation between her and 柳淳风's disciples.

- qlist10000.c, qlist13000.c and qlist17000.c comment out 11 entries each (/* */): 220 entries
  and 84 names are live (书生, 仆役 and 后备兵 appear only in the comments).
- quest/qqqq.c is a fourth list no code reads (QUEST_D only names the 15 qlist files). god.c's
  random tier shift (factor 15) is commented out, so quest_factor is always 10; its accept_object()
  for 寻 tasks is commented out too (all 220 entries are 杀). tfinished never goes below 0 in
  practice: only an expired task at -10 or less lowers it. The quest reward caps unspent potential
  at 100, so a player above 100 loses some (the port only stops the gain, DECISIONS 3C).
- surrender.c reads last_opponent, set once blows are exchanged: before the first one a surrender
  is accepted even against a killer, who fights on (the player has lost 50 score). The port
  refuses it then (DECISIONS 3C).

## Deferred

- 牛腿 is a hammer only: food that is also a weapon is not supported yet. Eaten food leaves no
  bones (finish_eat). 极乐逍遥散's pour (slumber_drug) is not modelled; the mother carries it.
- 弈者's 下棋 (a coin flip that hands over his 棋子). A carried 布袋 is not opened (put works on
  a container lying in reach).
- The garrison's vendetta and pursuit, 趟子手's and the thief's wimpy.
- 陈剑秋's letter (u/cloud/npc/obj/letter.c, master_id) for a 忘忧草 that is the giver's: with the
  lion of 乔阴县城 (#9), which gives the grass its master_id; 陈天星 takes the letter in 京师 (#12).
- The garrison's pursuit (garrison.c `pursuer`): following who flees. Its vendetta came with 3C.
