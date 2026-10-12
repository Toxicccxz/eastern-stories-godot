# 京师 content (region plan #12)

How the region comes from `reference/es2/mudlib/d/city/` (and `u/cp/chater2.c`), and what the LPC
says that the code does not. Decisions are in [DECISIONS](DECISIONS.md) (「京师 A」 holds the plan,
the owner's answers and the defaults; 「京师 B」 what B follows). Package A drew the city, its shops
and people; B 尚书府 and the city's secrets (the 院墙, the altar's 地下密室, 废园's 出城令牌).

## Placed

All 55 rooms, on four maps.

| Map | Rooms | People | Ways |
|---|---|---|---|
| city.main (京师) | nroad1–2, northdoor, street1–17, bank, weapon, biaoju, cloth, jiulou, boots, house1, feiyuan, jitan, shenwumen, wumen, jiaowu, bridge, eastdoor1–2, westdoor1–2, southdoor, xiangguo/gate | 桃X仙, 守城兵 ×18 (three at each gate), 黑你没商量, 万晓生, 收破烂的 ×4 (Snow's), 陈天星, 老板娘, 店小二, 钱掌柜, 行人 ×3, 商人, 李掌柜, 卖艺壮汉, 卖饼大叔, 卖包子的 | north to 玉螺湖村's 三叉路口 (road2); the 太白酒楼's stairs up; east to 尚书府 and 院墙 · 爬上去 (street3); the five outer gates shut |
| city.upstairs (太白酒楼二楼) | jiulou_2 | — | the stairs down |
| city.main (B: 尚书府) | shangshu/gate, yuan, keting, road1–4, kefang, xiaowu, chufang, huayuan, neizhai, feiwu | 门房, 庾子建, 护院 ×3 (two huyuan, one huyuan1), 丫鬟, 花匠, 庾清尘 | east from street3; doors 大铁门, 小木门, 木门, 帘子 (shut) |
| city.wall_top (院墙) | wall | — | 爬上去 from street3; 跳进去 to the 废屋, 跳回去 to street3 |
| city.cellar (地下密室) | midao1 | — | the stairs up under the 祭坛 (open three seconds at a time) |

Not placed: guardbak.c (a backup), trader2/3.c and u/cp's chater/drooler/teller are placed by no room. 护国寺, 紫禁城, 监狱
and 刑场 are drawn as walled blocks: their exits are commented out and their rooms were never
written. 相国府 is a gate only (xiangguo/gate.c has one exit).

## LPC → native (A)

| LPC | Native |
|---|---|
| village/road2.c south, nroad2.c north | portals `village.road2.south` / `city.nroad2.north` (玉螺湖村's 三叉路口 opens south) |
| create_door() in nroad1, northdoor and the five gates | std/room.c errors (no such exit): no doors; create() stops before setup(), so the guards came with the first reset() in ES2 (here from the start, 默认) |
| guard.c do_out() | act services `city.<gate>.out` (城门 · 出城) on the five shut gates: with a 守城兵 standing there and no marks/令牌 its say and write() (the stray space before 。 dropped); otherwise go.c's 这个方向没有出路。 (no out exit was ever written). Not at the 北门: the road north is the way out |
| guard.c do_kill() | accept_kill `line` and `fellows`: every guard in the room has the action and each returns 0, so the whole squad kill_ob()s the attacker before kill.c runs; 守城兵大叫：反了！反了！ (never printed in ES2: kill.c went on) is shown once, as meant (默认) |
| guard.c inquiry out | the typed English alias of 出城 (the same answer): only 出城 is offered as a topic, as here/name/rumors fold into 这里/名字/传闻 |
| guard.c accept_object() | A: 这是什么东西啊！你想偷渡呀？ and nothing taken; the token (marks/令牌) comes with B |
| the gates' valid_leave() | never runs (the out exits are commented out; three of them use \|\| and would have refused everyone) |
| item_desc signs and notices | look landmarks, word for word (the non-wizard's line where look_sign() asks wizardp(); HIY/RED not shown) |
| bank.c (BANK, no_fight) | service `city.bank.counter` (钱庄 · 兑换); the room is no_fight, so 黑你没商量's accept_fight() and chat_msg_combat are never reached |
| waiter.c go_up() | exit rule `city.jiulou.waiter_up` (`no_mark` 酒楼 with `present` 店小二): 闯什么闯 and 上楼的路被店小二挡住了。 (the stray space before 。 dropped); with the mark 店小二高声喊道:你楼上请. query("rank") is set on no player in the mudlib |
| waiter.c accept_object() | value() below 1000 (anything but money is 0): 这点钱，还不够买酒喝。 and the gift lands on the floor (`drops`, owner's plan); 1000 or more: 谢谢这位客官了 and marks/酒楼; with the mark already 真是谢谢你了 |
| boss.c greeting() | always 钱千万皱了皱眉 (no rank) |
| chen.c accept_object(), recruit_apprentice() | rules: 陈剑秋's letter (query("id") == "letter": its blueprint, the only one with that id first; item_master) is asked first, taken, 果然是剑秋侄儿推荐来的 and his recruit (`recruit`): a 拜师 waiting on him is taken at once, else he offers (the offer is saved: 默认); apprentice kind `silent` (no attempt_apprentice()), title 振远镖局第一代弟子, class guardman; assign_apprentice("弟子", 0): privileges 0. M2 (默认): anything else and a letter not the giver's are handed back |
| walker.c create() | age random(45), then gender random(3) (`age_first`), skill_roll random(4) == 0 (spicyclaw), chat_chance random(20) kept per walker (saved); 买官's closure answers its string |
| trader.c | bloodystrike (密宗大手印, six moves) mapped to unarmed, iron-cloth 50 (铁布衫: nothing reads its absorb lines) |
| chater2.c | 桃 + one of seven drawn names (its drawn id is not modelled); chat: get_all, wear_all, wield_all and four silent drools (its memory fills only from the chat channel); accept_object takes anything |
| d/city/npc/obj/wine.c drunk_bonus | liquid.c reads drunk_apply: nothing reads it (dropped) |

## LPC → native (B)

| LPC | Native |
|---|---|
| gate.c valid_leave() | exit rule `city.shangshu.gate.porter`: no_mark 尚书 while the 门房 stands there (闯什么闯); the mark is spent going in (`spends`, M3) |
| shangshu/npc/guard.c accept_object() | give rules: with marks/尚书 大人太客气了 (kept); value() 30000 and more (three taels of gold) 这位大人，里面请！ and the mark; less, 鼻子里哼了一声 (no speaker, as written) and handed back (M1) |
| road2.c valid_leave() | exit rules `city.shangshu.road2.trainer_north`, `trainer_east`: no_mark 尚书 while either kind of 护院 is in the room (present("trainer")) |
| yuan.c valid_leave() | !userp(): nothing to port (the 护院 keep to their rooms and the neighbours) |
| create_door() ×8 | four doors in world.json (each pair of rooms one door), shut at the start |
| huyuan.c, huyuan1.c create() | `name_parts` (two draws) and `create_rolls` (str, int, cor, con, force, max_force, force_factor, chat_chance or chat_chance_combat, combat_exp, seven skills, in create()'s order); huyuan wanders (random_move), huyuan1 heals (lotusforce) |
| kefang.c item_desc book | look landmark |
| street3.c do_climb() | landmark 院墙 · 爬上去 (portal to city.wall_top), its item_desc as its look |
| wall.c do_jump() | act services 尚书府 · 跳进去 (to the 废屋) and 京师东街 · 跳回去 (to street3) |
| jitan.c item_desc, do_turn(), do_press(), close_passage(), reset() | look landmarks 祭坛 and 台子; the dial 凸起: 顺时针转, 逆时针转 (counted, their message_vision() lines), 按下 (forward 1 and backward 3 with the way shut: 3 s open; M4: any press clears the turns); reset() clears them |
| midao1.c | the 天花板 (dial_below, owner Q2 (a)): opens the same way from below |
| feiyuan.c valid_leave(), do_find() | exit rule `city.feiyuan.flash` (never: its line, the (find) hint gone); act service 草丛 · 寻找: carrying a token 忙活了半天; random(kar + 30) >= 35 the 出城令牌; else 白忙了半天 |
| guard.c accept_object() | the token (`item_alias` token) taken and destructed (`destroys`) with 原来是官府中人 and marks/令牌; 出城 then says 这个方向没有出路。 |

## LPC anomalies

- nroad1.c's yell adds `exit/up` (a typo for exits) to d/city/room, which does not exist.
- The 南门's and two other gates' valid_leave() use `||` where the rest use `&&`: moot, never run.
- passport.c and marks/京师 are used by nothing.
- The 卖饼大叔 sells 雪花糕 (npc/obj/cake.c), kept; 紫铜战盔 inherits ARMOR (an armour, kept).
- chen.c's nickname is 刀拳双绝 while his long says 刀掌双绝: kept.
- jiaowu.c names 淤兰天武 (於兰天武): kept as written.
- Real-world jokes (南大食堂磁卡, 美钞, 华工, 美国的朋友, NT也汉化) are kept (桂花 precedent).
- gate.c deletes marks/尚书 on any way out of the gate and road2.c asks for it: in ES2 nobody got
  past the 护院 on a paid leave (kept, M3 only moves where it is spent).
- midao1.c is a copy of Snow's secret_storage.c (its header names it) and has no way out but the
  altar's three seconds (owner Q2 (a): opened from below).
- The 门房's long ends in 的n (fixed); his refusal says without a speaker (kept).
- xiaowu.c's 杀气, huyuan1.c's 客人 and gardener.c's 清尘出事了 lead nowhere.
- query("id") == "token" is also true of 晚月庄's 杀手令牌 (its first id): a 守城兵 takes it as an
  出城令牌, and the 废园 finds nothing new while one is carried (as ES2).
