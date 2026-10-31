# 关北 content notes

What the code and the PRs do not record about the region (DECISIONS「关北 A」 holds the rules). ES2 has
no room, NPC or item of 关北: doc/help/plan:19 names it (关北是槐阳王的封国，关内则是王畿之地), canyon7.c
calls the land north of 雪亭镇 异族的领地, and d/canyon/README says of 严廷殷's garrison 收取过路费. Everything
in `game/data/guanbei/` is the outline's (剧情总纲 §3 第六章, §6 关北卡), the `legacy_source` fields saying
which line each thing continues.

## The way in: the valley's east wall

The pass map (`canyon_pass.tscn`) runs north–south — the chain to 雪亭 at the north end, canyon7's valley at
the south end on the way to 玉螺湖村 — and canyon7's own north is canyon6 behind the iron gate. The outline's
「从 canyon.canyon7 谷地北面出关」 is therefore a gate in the valley's **east wall** (the east hump's foot): the
layout opens a 96 px doorway in the cliff rows there, a stone gate as a `buildings` facade, the portal
`canyon.canyon7.east` into `guanbei.gate_road` (and `guanbei.gate_road.south` back). The story keeps calling it
北出关 — the military road bends north behind the hump on the 关北 side — and the map's caption reads
「东 · 关门 · 关北」. The two 关门兵 stand in canyon7 (`native/spawns.json`, placed by the canyon layout).

## Sources by thing (A)

| Thing | Continues |
|---|---|
| 关门兵, the toll of five taels, the roll | README 收取过路费; the 大队长's 军营 roll (captain.c, DECISIONS「天驼关 A」) |
| 严廷殷's 「信」「程不平」「印鉴丢过」「关北」 | general.c (傲, 与皇叔同拜一师; his 印鉴 lost and found, DECISIONS「天驼关 B」); 剧情总纲 §3 第六章 ① |
| 赫造基's mould for eight taels | adviser.c accept_object() (≥ 800 buys a secret); the mould is the outline's (真印被军师拓了模子卖出去) |
| the 后备兵's 「印色」, the real seal's HIY name | seller.c, seal.c (HIY in the name), fake_seal.c |
| 界碑, 槐阳城, the 王府's notice | plan:19; 剧情总纲 §2 槐阳王 (老王爷拒绝了兵部征民夫的令); DECISIONS「第五章 人证」 (带刀侍卫: 老王爷拒了) |
| 马市, 巴朗, the ponies and camels | 剧情总纲 §3 第六章 ② (边城槐阳城、草原、马市、帐篷) |
| 卢卡, his sword, 会首安敦 in 番坊 | 剧情总纲 §3 第六章 ⑤, 第七章 ①②; doc/help/theme:3 (西方还在蛮荒时代: an exile, no envoy) |
| 塞外酒肆, 胡三娘, 秦婆子, 秦小六 | 剧情总纲 §3 第六章 ④ (the men taken to the 工地); the lived-in layer (美术规划 §2 第 6 条) |
| 老秦 | 逆灵宫 B/C's two 关北民夫 in the dungeon's third cell (DECISIONS「逆灵宫 C」: 开门就走，「俺们回关北」) |

## Sources by thing (B)

| Thing | Continues |
|---|---|
| 程朔, the 王府, its hall and court | 剧情总纲 §2 槐阳王 (name the outline's), §6 关北卡; elder5.c, court1.c, magistra.c:22 (the three ES2 lines that make one family) |
| the 王府大门 knocked open with the letter | DECISIONS「第五章 人证」's drum (空口无凭); a `found_by` door wants a landmark, a scene or an act behind its mark |
| 郭承, the drill yard, the posts hacked on the left shoulder | magistra.c:22 骁将; 剧情总纲 §6 马上刀法 (the 《马刀谱》 is D's) |
| 南危水 home in the hall (保密 ledger) | elder5.c 槐阳王的弟弟; DECISIONS「第二章旧案」's two marks; his 水烟阁 greeting 到了关北，老夫替你引见槐阳王 |
| the side hall's map with the 工地 ringed | 剧情总纲 §3 第六章 ④ (where C's 工地 lies) |

## Sources by thing (C)

| Thing | Continues |
|---|---|
| the camp's yurts, the fire where the families wait, the sheep | 剧情总纲 §6 关北卡「塞外——草原、马市、帐篷」; 关北 A's 秦婆子 waiting in the 酒肆 |
| the 敖包's tally of carts, the shepherd | 剧情总纲 §3 第六章 ④「挖不动的人被逆灵宫的车接走」, seen from the steppe |
| the 工地: 吕隼's roll, 裴照's white, the posts and the 枷 | 剧情总纲 §3 第六章 ④ 兵部的工地; 陈显祖's 抄本 (the 二十三 in white, their successors); 逆灵宫 B's ledger 「关北民夫七名」 |
| the raid: 吕隼's three beats, the riders beside the player | 剧情总纲 §3 第六章 选择「借兵踏平」, 终章「关北出骑兵」; heaven_soldier.c's rule as `fights_beside_player` (DECISIONS「青石村 C」) |
| the sneak: 等到天黑, the two dozing watchers, four 枷, 走！ | 剧情总纲 §3 第六章 选择「夜里潜入……救一半」; owner's 默认: a real night (`phase`, `until_phase`) |
| the 古冢口: the lined pit, the stone door's three-legged bird, the covered cart | 剧情总纲 §2「金乌遗民」, §3 第六章 ④; red_suit.c:15's 金乌徽; the 第三章 escort's look for the taoists |

## Sources by thing (D)

| Thing | Continues |
|---|---|
| the notice's second text 兵部文书至：槐阳反 | 剧情总纲 §3 第九章「槐阳王反了」; 关北 A's notice |
| 程朔's moods 反名／干净, the marks 关北的骑兵欠你一阵 (终章) and 王府干净 (第九章) | 剧情总纲 §3 第六章 选择的后果, 终章「关北出骑兵」 |
| the 民夫 home at the camp, the families' words | 剧情总纲 §3 第六章 ④; 关北 A's 秦婆子 |
| the cart passing once on the steppe | owner Q2 ②; 剧情总纲 §3 第六章 ④ 挖不动的人被逆灵宫的车接走 |
| 《马刀谱》 and 关北马刀 | 剧情总纲 §6 关北卡「马上刀法（一门）」; d/canyon/npc/obj/old_sword.c's 研读 (`study`); daemon/skill/shortsong-blade.c's form |
| the seventh chapter's stub | 剧情总纲 §3 第七章 ①; 关北 A's 卢卡 (会首安敦在番坊) |
| 玄冥子's and 刘老农's word on 关北 | 逆灵宫 C's spared 玄冥子; 玉螺湖村 has no headman, so the farmer by the road speaks |

Not made: the plan's `room_life` presets `work_camp` and `nomad_camp` — an outdoor canvas has no walls to hang
things on, so the camp's and the 工地's clutter is written per map; the 工地名册 is a landmark, not an item;
the passing cart is told by its two taoists, not drawn.
