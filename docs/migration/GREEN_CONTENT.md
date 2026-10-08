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
| outdoor, cavehall, stoneroom, water | 绝尘子 (cavehall) | the stone rooms (the hall sealed but to 绝尘子's apprentices), the stream and its search |
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

## 绝尘派 (C)

| LPC | Native |
|---|---|
| daemon/class/juechen/master.c | common.npc.juechen.master in the hall (cavehall.c): 金刚杖 wielded, 紫金冠 worn, mana 4000 of 2000, atman 2000 |
| master.c chat_msg_combat | cast dun, cast saveme and his two lines at 40 |
| master.c attempt_apprentice() | apprentice rule: `commoners_only` (the 【闲聊】 line and kill_ob(), asked first), then spi 24 and combat_exp 100000 with their says; class taoist |
| magic-array/dun.c | DunSpell: at an enemy, busy mana / 200 − its max_mana / 100 + 2 |
| magic-array/saveme.c, obj/npc/heaven_soldier.c | SavemeSpell and a summoned NPC (SummonedNpc): it comes beside its caster against the caster's enemies and leaves when the fight ends |
| skills magic, spells, tao-mystery, magic-array, juechen-force, jingang-staff | skills.json (valid_learn: 小天魔道 above 奇门遁甲; str + max_force / 10 ≥ 50; tao-mystery's 100 bellicosity a level) |
| cmds/std/meditate.c, respirate.c | 武学 page: 冥思 (sen → 法力), 修行 (gin → 灵力) |

## The player's spells (D)

| LPC | Native |
|---|---|
| cmds/std/cast.c | CastService (busy, no_magic, the enabled spells skill, std/skill.c's 你所选用的咒文系中没有这种咒文); CombatCastTacticalPolicy, one per file, plus one at oneself for dun |
| magic-array/dun.c, `target == me` | DunSpell: 80 mana, 30 sen, random(spells) < 30 fails, five lights; the fight ends for the player (DISENGAGED) and the session moves them to /d/snow/temple |
| magic-array/saveme.c, heaven_soldier.c invocation(who) | the soldier admitted on the player's side (CombatEncounterResolution): lethal both ways with each living enemy, from the last; an NPC's soldier: CombatJoin with its caster's enemies |
| combatd.c killer_reward(), `possessed` | WorldMapController keeps each summoned NPC's caster: the player's soldier's kill is the player's |
| oldman.c kill_ob() / ask_for_help() | the partner's CombatJoin targets the caller's last kill_ob() |
| feature/attack.c select_opponent() | an NPC with several enemies draws random(4) each attack (CombatEncounterScheduler) |
| set("no_magic") | rooms.json `no_magic`, ContentCatalog.zone_forbids_magic() |

## Source anomalies

- combatd.c killer_reward() tests `!killer->is_living()` before handing a possessed killer's
  reward to its caller; is_living() is defined nowhere, so the test always holds (whoever calls
  a heaven_soldier, hell_guard or zombie gets its kills).

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
- jingang-staff.c is a copy of cloudstaff.c (its header says so) with the same four moves.
- npc/master.c (龙若法王) does not compile (`map_skill("spells",magic-array)`); no room places
  him, kid5.c, s.c or shen1.c.
- woman1.c's knife line has a stray backslash (菜刀神功\是吧, a Big5 artifact): dropped.
- d/green/cave/README: "files in /u/e/elon/cave*.c, will move when finished" — the cave is
  d/green/cave0-2.
