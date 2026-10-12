# 京师 content (region plan #12)

How the region comes from `reference/es2/mudlib/d/city/` (and `u/cp/chater2.c`), and what the LPC
says that the code does not. Decisions are in [DECISIONS](DECISIONS.md) (「京师 A」 holds the plan,
the owner's answers and the defaults). Package A draws the city, its shops and people; B 尚书府
and the city's secrets (the 院墙, the altar's 地下密室, 废园's 出城令牌).

## Placed (A)

40 of the region's 55 rooms, on two maps.

| Map | Rooms | People | Ways |
|---|---|---|---|
| city.main (京师) | nroad1–2, northdoor, street1–17, bank, weapon, biaoju, cloth, jiulou, boots, house1, feiyuan, jitan, shenwumen, wumen, jiaowu, bridge, eastdoor1–2, westdoor1–2, southdoor, xiangguo/gate | 桃X仙, 守城兵 ×18 (three at each gate), 黑你没商量, 万晓生, 收破烂的 ×4 (Snow's), 陈天星, 老板娘, 店小二, 钱掌柜, 行人 ×3, 商人, 李掌柜, 卖艺壮汉, 卖饼大叔, 卖包子的 | north to 玉螺湖村's 三叉路口 (road2); the 太白酒楼's stairs up; 尚书府 (street3 east) drawn shut for B; the five outer gates shut |
| city.upstairs (太白酒楼二楼) | jiulou_2 | — | the stairs down |

Not placed: wall.c and midao1.c (B, own maps), shangshu/*.c (B, on city.main). guardbak.c (a
backup), trader2/3.c and u/cp's chater/drooler/teller are placed by no room. 护国寺, 紫禁城, 监狱
and 刑场 are drawn as walled blocks: their exits are commented out and their rooms were never
written. 相国府 is a gate only (xiangguo/gate.c has one exit).

## LPC → native (A)

| LPC | Native |
|---|---|
| village/road2.c south, nroad2.c north | portals `village.road2.south` / `city.nroad2.north` (玉螺湖村's 三叉路口 opens south) |
| create_door() in nroad1, northdoor and the five gates | std/room.c errors (no such exit): no doors; create() stops before setup(), so the guards came with the first reset() in ES2 (here from the start, 默认) |
| guard.c do_out() | act services `city.<gate>.out` (城门 · 出城) on the five shut gates: with a 守城兵 standing there and no marks/令牌 its say and write() (the stray space before 。 dropped); otherwise go.c's 这个方向没有出路。 (no out exit was ever written). Not at the 北门: the road north is the way out |
| guard.c do_kill() | accept_kill `line` and `fellows`: every guard in the room has the action and each returns 0, so the whole squad kill_ob()s the attacker before kill.c runs; 守城兵大叫：反了！反了！ (never printed in ES2: kill.c went on) is shown once, as meant (默认) |
| guard.c accept_object() | A: 这是什么东西啊！你想偷渡呀？ and nothing taken; the token (marks/令牌) comes with B |
| the gates' valid_leave() | never runs (the out exits are commented out; three of them use \|\| and would have refused everyone) |
| item_desc signs and notices | look landmarks, word for word (the non-wizard's line where look_sign() asks wizardp(); HIY/RED not shown) |
| bank.c (BANK, no_fight) | service `city.bank.counter` (钱庄 · 兑换); the room is no_fight, so 黑你没商量's accept_fight() and chat_msg_combat are never reached |
| waiter.c go_up() | exit rule `city.jiulou.waiter_up` (`no_mark` 酒楼 with `present` 店小二): 闯什么闯 and 上楼的路被店小二挡住了。 (the stray space before 。 dropped); with the mark 店小二高声喊道:你楼上请. query("rank") is set on no player in the mudlib |
| waiter.c accept_object() | value() below 1000 (anything but money is 0): 这点钱，还不够买酒喝。 and the gift lands on the floor (`drops`, owner's plan); 1000 or more: 谢谢这位客官了 and marks/酒楼; with the mark already 真是谢谢你了 |
| boss.c greeting() | always 钱千万皱了皱眉 (no rank) |
| chen.c accept_object(), recruit_apprentice() | rules: 陈剑秋's letter (query("id") == "letter": its blueprint, the only one with that id first; item_master) is asked first, taken, 果然是剑秋侄儿推荐来的 and his recruit (`recruit`): a 拜师 waiting on him is taken at once, else he offers (the offer is saved: 默认); apprentice kind `silent` (no attempt_apprentice()), title 振远镖局第一代弟子, class guardman; assign_apprentice("弟子", 0): privileges 0. M2 (默认): anything else and a letter not the giver's are handed back |
| walker.c create() | gender random(3) (drawn before its age: the factory's order), skill_roll random(4) == 0 (spicyclaw), chat_chance random(20) kept per walker (saved); 买官's closure answers its string |
| trader.c | bloodystrike (密宗大手印, six moves) mapped to unarmed, iron-cloth 50 (铁布衫: nothing reads its absorb lines) |
| chater2.c | 桃 + one of seven drawn names (its drawn id is not modelled); chat: get_all, wear_all, wield_all and four silent drools (its memory fills only from the chat channel); accept_object takes anything |
| d/city/npc/obj/wine.c drunk_bonus | liquid.c reads drunk_apply: nothing reads it (dropped) |

## LPC anomalies

- nroad1.c's yell adds `exit/up` (a typo for exits) to d/city/room, which does not exist.
- The 南门's and two other gates' valid_leave() use `||` where the rest use `&&`: moot, never run.
- passport.c and marks/京师 are used by nothing.
- The 卖饼大叔 sells 雪花糕 (npc/obj/cake.c), kept; 紫铜战盔 inherits ARMOR (an armour, kept).
- chen.c's nickname is 刀拳双绝 while his long says 刀掌双绝: kept.
- jiaowu.c names 淤兰天武 (於兰天武): kept as written.
- Real-world jokes (南大食堂磁卡, 美钞, 华工, 美国的朋友, NT也汉化) are kept (桂花 precedent).
