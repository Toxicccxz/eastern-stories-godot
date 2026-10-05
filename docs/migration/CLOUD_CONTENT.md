# 卧龙岗 + 绮云镇 content (region plan #3)

How 卧龙岗 and 绮云镇 come from `reference/es2/mudlib/u/cloud/` (and `u/cloud/dragonhill/`), and
what the LPC says that the code does not. Decisions are in [DECISIONS](DECISIONS.md). Package
3A (streets and shops) places every room and every NPC the rooms name; joining 振远镖局 (3B),
朱鸿雪's quests (3C), betting and marriage (3D) and the ferry (region plan #8) come later.

## Placed

| Room | LPC `set("objects")` | Native |
|---|---|---|
| dragonhill/nroad, nhillfoot, shillfoot, sroad | — | outdoor map: the road over the ridge, north of the town's gate; nroad north to Snow's 雪亭镇街道 |
| dragonhill/hummock (卧龙岗) | 卧龙岗强盗 ×2 | the toll (`attack_unless_mark` 强盗), one fight together |
| entrance, cross, the markets and streets | 县城官兵 ×2 (nwroad3) | outdoor map: the gate, the market street and the main street, one open road |
| butchery | 郑屠夫, 苍蝇 ×6 | vendor: 生牛肉, 牛腿, 牛尾, 熟杂碎, 狗肉 |
| tearoom, tea_corridor (木雕门), tearoom2 | 茶博士; 弈者 (upstairs) | 香茗坊; its second floor on the upstairs map |
| woodboxy, god1 (木门), god2 | 林三爷, 伙计 ×8; 朱鸿雪 | 朱鸿雪 refuses spars; not fightable yet (her arts) |
| tailory, zaihuoy, drugstore, weapony, bookstore | 裁缝, 杂货贩, 药店伙计, 兵器贩子, 潘若秋 | vendors |
| monky (斋院) | 化缘和尚, Snow's 乞丐 ×2, 包子 ×3 | the monk takes donations (keeper.c's formula); not fightable yet |
| jiyuan, jiyuan2 | 鸨母; 李师师 (upstairs) | 李师师 teaches literate after a keepsake |
| duchang, duchang2 | 宝官 | his betting is 3D |
| marry_room | 媒婆 | marriage is 3D |
| park (张家花园) | 飞贼 | steals silver from arrivals (thief.c, steal.c) |
| biaoju | 陈剑秋, 趟子手 | 春风快意刀; joining is 3B |
| rich, m_house | 保镖 ×5; 张百万, 家丁 ×2 | |
| eroad4 (茶场) | 茶工 ×6 | wander |
| dukou (江北渡口) | 船夫 | the crossing waits for #8 |

## Source anomalies

- The u/cloud files are hard-wrapped at 80 columns, line breaks inside strings included
  (gangster.c, butcher.c, room_gua.c); the importer drops them.
- northriver.c's ferry code is dead: `replace_program(ROOM)` in create() discards its init(),
  and it checks the room's own `marks/船夫`. ES2's river is crossed by walking south.
- boater.c's 过江 answer asks for five taels; its accept_object() takes anything worth 2 coins.
- 宝官's betting is accept_object() (押小, 20% wins double); duchang2.c's `bet` is a TODO.
- LPC `value()` exists only for money, so 李师师 refuses money and takes any other thing (from a
  man with per 25 or more) as the keepsake.
- 说文解字 teaches literate, but study.c refuses anyone illiterate (literate 0).
- monk.c's greeting() is never called (no init()); its refusal of a gift without value is
  replaced by give.c's own line.
- gangster.c's greeting() has no presence check; the chess player gives his whole stack of 棋子
  when he loses (`give chess`), saying it is two.
- The seller gains a 飞镖 on half the arrivals (init()); not modelled. The weapon shop lists its
  飞镖 at 0两黄金 (vendor.c price_string(0)), which buy.c then refuses to sell.
- entrance.c's notice asks a gold tael toll that no code takes; m_house.c says 常人可进不来 and
  lets anyone in. room_gua.c's 镇关西 answer speaks of 雪亭镇.
- jiasha.c sets `male_only`, which wear.c does not read. sword_book.c does not compile (and is
  sold by nobody). teacher.c is a copy of butcher.c; goddd.c of god.c; beggar.c of Snow's, with
  a lost glyph; lm_guard.c, monk_guard.c and monk_waiter.c are placed by 晚月庄's entrance
  and 山烟寺's front yard, not by any u/cloud room (26 of the 32 NPC files stand here).
- spring-blade.c's □伤 is the case label combatd.c also has (割伤's branch).

## Deferred

- 牛腿 is a hammer only: food that is also a weapon is not supported yet. Eaten food leaves no
  bones (finish_eat). 极乐逍遥散's pour (slumber_drug) is not modelled; the mother carries it.
- 弈者's 下棋 (a coin flip that hands over his 棋子). A carried 布袋 is not opened (put works on
  a container lying in reach).
- The garrison's vendetta and pursuit, 趟子手's and the thief's wimpy.
