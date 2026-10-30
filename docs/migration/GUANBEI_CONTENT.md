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

## Deferred to B–D

The 王府 (its door, 程朔, 郭承, the 保密线 reunion with 南危水, the 借兵／潜入 choice), the market's 东门, the
camp, the steppe, the 工地 and the 古冢口, the notice's second text and the other consequences, the
`chapter7.json` stub and 《马刀谱》 (the plan `build/plans/关北_计划.md` §6).
