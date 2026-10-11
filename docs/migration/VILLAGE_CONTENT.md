# 玉螺湖村 content (region plan #11)

How the region comes from `reference/es2/mudlib/d/village/`, and what the LPC says that the code
does not. Decisions are in [DECISIONS](DECISIONS.md) (「玉螺湖村 A」 holds the plan, the owner's
answers and the defaults; 「玉螺湖村 B」 the 瓜地). Package A draws the village, the lake and the ice cave and places the
people; B the 瓜地 (the pick, the 瓜农's catch, 还瓜钱).

## Placed

All 26 room files, on three maps.

| Map | Rooms | People | Ways |
|---|---|---|---|
| village.main (傅家坡) | road1–9, farmhouse1, fmhousback, littlegarden, home, smallstorage, melonfarm, melonguard, field, lordhouse1–3, lakeside, valley1–2 | 商人 ×2, 农妇, 采花妞 ×5, 刘老农, 大老鼠 ×6, 瓜农 ×3, 渔夫 ×3 | north to 天驼关谷地 (canyon7); the 三叉路口's way south to 京师 and the 黄土大道's spur west to 黑松山 drawn closed; the grass west of road6 into valley2 (five seconds), valley2 east back; valley1 east down into the ice cave; the boat to the lake's middle |
| village.midlake (玉螺湖: the boat) | lake | — | the paddle back ashore; the dive into the ice cave |
| village.icecave (水下岩洞) | lakebottom1–2 | 白鳞冰龙 ×6 | up west to valley1; 放弃 by the 玄冰 (the Inn) |

The lake is no walk: its middle, which only the boat reaches, is a map of its own (as 乔阴's rooms
only verbs reach).

## LPC → native (A)

| LPC | Native |
|---|---|
| road1.c north, canyon7.c south | portals `village.road1.north` / `canyon.canyon7.south` (天驼关's valley opens south) |
| road2.c south (d/city/nroad2) | drawn closed (东南 · 京师（未开放）); village_test fails once 京师 is placed |
| road3.c, lakeside.c item_desc | look landmarks (小牌子: 傅家坡; 木船), word for word |
| home.c / littlegarden.c, road9.c / lordhouse1.c create_door() | doors `village.home.door` (木门) and `village.lordhouse1.door` (田老财家大门), shut |
| road6.c do_pushaside(), roadgone() | `hidden_passage` landmark `village.road6.landmark.grass` (茅草 · 拨开, every_push, one portal; pushed while standing against it, the player is through): exits/west for five seconds of world time, 你拨开茅草，发现了一条向西的路。 each push, the first call_out's 茅草晃了晃，又遮住了向西的路。 seen in road6 only; valley2.c's east is an exit, always open |
| lakeside.c do_paddle(), valid_leave() | act service `village.lakeside.paddle` (木船 · 划向湖心: 你跳上渔船…, 你终于划到湖中心了。, the move); exit rule `village.lakeside.no_wading` (`always`: 这么大的一片湖，你想走过去吗？) on the shore's way west |
| lake.c init(), do_paddle(), do_dive(), valid_leave() | dropped by replace_program(ROOM) in ES2; repaired (owner Q1): act services `village.lake.paddle` (小船 · 划回岸边) and `village.lake.dive` (湖水 · 潜入湖中, asked first), exit rule `village.lake.bow` (`always`: 你正站在船头…); its valid_leave() called itself, not ::valid_leave() |
| lakebottom1.c (the way in frozen over) | landmark `village.lakebottom1.landmark.ice` (玄冰 · 放弃: the Inn, as 绝地) |
| lakebottom2.c objects | six 白鳞冰龙 (1,000,000 exp, aggressive): the hall is `complete_set` and they notice all of it (presence 260): whoever comes in fights all six |
| lordhouse3.c | source_fixes: the stray } that ended do_takeout() goes, so the room loads (ES2 never compiled it); its shelf, take_out and push are not ported (no outcome, placeholder text) |
| oldliu.c greeting() | 刘老农说道：“这位$RESPECT，可否见到小女娟儿？” a second after the player comes in; the thanks (marks/老刘) and revenge (marks/murder, killhim()) wait for 黑松山, whose 小娟 sets them |
| oldliu.c accept_fight() | 老头子哪里是您的对手？, no spar |
| meloner.c greeting(), vendor_goods | 这位$RESPECT要不要买个西瓜解解渴？ (no speaker, as say() wrote it); goods 西瓜 at 60 |
| woman1.c wield_weapon(), converse_one() | the wield action (菜刀, then chat_chance_combat 10) and say_by_age (青石村 A) |
| trader1.c chat_msg_combat | 杀人啦！你难道不怕官府缉拿吗？ and random_move: he walks out of the fight |
| obj/melon.c | food 8 bites × 20 food and 40 water (drink_func); refused once water is full; finish_eat() leaves 西瓜皮 (bone) |

## LPC → native (B: the 瓜地)

| LPC | Native |
|---|---|
| melonfarm.c init(), do_pick() | act service `village.melonfarm.pick` (瓜地 · 摘西瓜), four branches by `kar_above` and `present_in`: random(kar) > random(30) finds the melon (given), then with a 瓜农 standing in the 瓜棚 random(kar) > random(10) brings the first of them over (`comes`), both get melon/catch_thief (`npc_flag`, `set_temp`) and he kill_ob()s the thief (`kill`); otherwise 瓜农似乎正在打瞌睡… or 你真幸运，瓜农没有在瓜棚看瓜。; or 你找来找去，终于还是没找到熟透的西瓜。 Each roll is drawn once, in order, only when reached. Asked first while that 瓜农 is clearly stronger (`stronger`, A10) |
| melonfarm.c valid_leave() | exit rules `village.melonfarm.held_north` / `held_south` (`held`: 你的去路被瓜农拦住了。) while a 瓜农 with the flag stands awake in the 瓜地 |
| meloner.c catch_thief() | chat_msg_combat `say_while_flag` (chat_chance_combat 50): 瓜农说道：你要不还我瓜钱，咱俩就没完！ only from the one catching |
| meloner.c do_return() | `settle`: 还瓜钱 on the HUD (his group) and the battle panel (`combat.settle.village.npc.meloner`): the 西瓜's value (60 文) paid as buying is; 好，咱俩的账就算结了。, both flags go, he walks home (out of the fight) |

## LPC anomalies

- The room directory's flowergirl.c is a stray copy of npc/flowergirl.c: not placed.
- 刘家's rooms and people are copies of d/chuenyu's; 刘老农's two branches need 黑松山's 小娟.
- melon.c comments out F_LIQUID: its 西瓜汁 (`liquid`, `max_liquid`) is never drunk.
- meloner.c's catch_thief() without a thief commands `heihei this_player()`: a name, prints nothing;
  its line has a stray ） (dropped with its command hint).
- melonfarm.c's set_leader(me) has nothing to do: the thief cannot leave while he stands, and
  following needs him standing by; meloner.c's do_return() cleared it again.
- lordhouse2.c's long names a wall and a stick (and a 关公 pointing at the wall) with no item_desc.
