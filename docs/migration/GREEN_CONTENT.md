# 青石村 content (region plan #5)

How 青石村 comes from `reference/es2/mudlib/d/green/` and `daemon/class/juechen/`, and what the
LPC says that the code does not. Decisions are in [DECISIONS](DECISIONS.md). Package A places
every room and the villagers; B the 玉佩 and 蒙汗药 (村长, 醉汉, 沈万年); C 绝尘派 (绝尘子, his
arts and spells, joining, 法力); D the player's spells (遁, 困, 召天将).

## Placed (A)

| Room | LPC `set("objects")` | Native |
|---|---|---|
| path6, path5 (石板路) | — | village map: the stone road from 山坳, cart ruts, shrubs south |
| station0, station1 (工作站) | 采石工 ×3, ×2 | the station at the village's mouth (well: a water service, carts, the hut) and up the slope by the quarry (huts, stable, hay) |
| path4, path3, path2 (碎石路, 三叉路口) | 小孩 ×2 (path2) | the gravel street north; 沈记商行 east of path4, 民宅 west of path3, 土地庙 west of path2 |
| path1, path0 (小路) | — | the overgrown path north to the cave (a passage to the mountain map) |
| path8 (小巷子) | 小孩 ×2 (kid3) | the lane east between 工匠的家 (north) and 沈记商行's back wall |
| field0 (小广场) | — | the square with its great banyan; 民宅 north, 村长的家 south |
| field1 (采石场的空地) | 工匠的小孩 | the quarry yard under the cut cliff; the empty 民宅 north |
| house0–4, shop0, temple0 | 妇人 ×2, 工匠, 老公公 + 老婆婆, 村长, 沈万年 + 妇人 | buildings with their doors on the street their exit names |
| house3 (民宅) | — (call_spider()) | the web: a look calls in one of three summoned spiders |
| cave0 (洞口) | 小孩 ×2 (kid4) | mountain map: the hill's foot, the chained wooden door north |
| cave1, cave2, mpath0–2 | — | the low, freezing cave; the road between the cliff and the chasm |
| entrance (山路尽头) | — | the painting (look), the cave east into the 迷阵 (100000 combat_exp), the great stone door north |
| outdoor, cavehall, stoneroom, water | 绝尘子 (cavehall, C) | the stone rooms (the hall sealed but to 绝尘子's apprentices), the stream and its search |
| eight0–7, closed | — | 迷阵 map: eight clearings drawn after their texts, each 路牌 looked at; 绝地's stone and 放弃 |

## The 玉佩 and the 蒙汗药 (B)

| LPC | Native |
|---|---|
| oldman2.c 玉佩, set_flag() | the answer's `mark_asker` (elder_info); relay_say 必有妖孽: the 打听 panel's 接话 |
| d/snow/npc/drunk.c accept_object() | accept_object rules: elder_info → the 玉佩 whisper (give_alcohol), give_alcohol → the 蒙汗药 whisper (know_drug); `whisper` lines in GRN |
| shen.c give_jade(), sell_drug() | inquiry `rules`: give_alcohol gives the unique jade (had_jade; 你真贪心耶; 刚刚有人来要过了 while one exists), know_drug whispers the price (can_buy_drug) |
| shen.c accept_object() | 10 taels give a 蒙汗药 (`gives`); 想骗我啊? deletes give_alcohol and know_drug and hands the gift back; a stranger's money is kept |
| shen.c list_item(), buy_item() | `shop_front`: 看货 (list) and 购买 (他不卖) |
| jade.c | 玉佩: `unique`, studied for force up to 40 |
| obj/slumber_drug.c, obj/toy/poison_dust.c | `pour` (the 背包's 倒进): 100 slumber_drug a sip / the drink's slumber_effect, + 100 a pour |
| daemon/condition/drunk.c, slumber_drug.c | the drunk and slumber_drug conditions, for the player and NPCs (the Snow drunk gets drunk on his wine) |

## Source anomalies

- The 迷阵's room files make one maze with eight7 south → stoneroom → (west) the hall: the only
  way in for one who is not yet 绝尘子's apprentice. stoneroom → cavehall and water → outdoor
  are one-way exits (passages here).
- station0.c sets `outdoors` "snow"; field0.c, the mountain road, entrance and the stone rooms
  set none, so rope.c lets one hang oneself there.
- The 玉佩 chain did not work in ES2 (B, made to work as the code means, DECISIONS): oldman2.c's
  set_flag() sits in its answer array, which ask.c skips, and nothing sets `last_asker`; jade.c
  inherits F_UNIQUE, which the mudlib does not define, so it does not compile; powder.c's pour
  makes the drink call effect_in_liquid(), which slumber_drug.c lacks (it has drink_drug()).
  liquid.c does call a drink_func (dbase.c query() evaluates it), so 极乐逍遥散 worked.
- shen.c's give_jade() and sell_drug() return 0, so ask.c also said a 没听说过 line after them.
- drunk.c's receive_healing() calls reach no function (damage.c has receive_heal()).
- shen.c's list text has 摆\著 (a Big5 artifact): 摆著.
- npc/master.c (龙若法王) does not compile (`map_skill("spells",magic-array)`); no room places
  him, kid5.c, s.c or shen1.c.
- woman1.c's knife line has a stray backslash (菜刀神功\是吧, a Big5 artifact): dropped.
- d/green/cave/README: "files in /u/e/elon/cave*.c, will move when finished" — the cave is
  d/green/cave0-2.

## Deferred

- C: 绝尘子 in the hall (spawn_skip in tools/migration/overrides/green.json until then); his
  arts, 遁/召天将 in a fight, joining, teaching, 冥思 and 修行.
- D: the player's cast.
