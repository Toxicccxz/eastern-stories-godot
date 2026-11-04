# 番坊 content notes

What the code and the PRs do not record about the region (DECISIONS「番坊 A」 holds the rules). ES2 has no
coast at all (剧情总纲 §6: 海岸原作零提及): no room, NPC or item of 番坊. What it does have is a line of world
setting — doc/help/theme:3 「西方还在蛮荒时代」, theme:4 「航海技术并不受重视」 — and two masters it wrote and
never placed (`daemon/class/lama/master.c` 龙若法王, `daemon/class/ronin/master.c` 早川直义; 番坊 B–D). Everything in
`game/data/fanfang/` is the outline's (剧情总纲 §3 第七章, §6 番坊卡) or the plan's (`build/plans/番坊_计划.md`), the
`legacy_source` fields saying which line each thing continues.

## The way in: the south end of the path outside 忘情谷

The outline put 番坊 「玉螺湖村东」, but ES2's path outside 忘情谷 (valley1.c, valley2.c) lies on the lake's **west**
shore — valley1.c: 东面是有名的玉螺湖 — and runs 「向着南和北延伸」 with no room at its south end. The owner chose
(plan Q1) to leave the village alone and go on south from there: the brush that closed the path's south end on the
village map parts (two thicket boxes either side, the path between them), and the portal `village.valley1.south`
leads down to `fanfang.cliff_top` (marking 到了番坊, the chapter's first step); `fanfang.cliff_top.north` comes back.
The sea is south-west of the village. The story never names a side: 卢卡, the sixth chapter's last step and the
seventh chapter's objective say 「出忘情谷，顺着小路往南，走海崖道」.

## The sea in the voxel view

* On the 海崖道 the sea is far below the road: on the 2D map the drop is `chasm` (it blocks, as the sea would), and
  the voxel config raises nothing there but sinks it (cliffs `sink`, depth 6, the sea `deep_water` at its foot).
* `water.open_sea` carries the sea on past the map's edge: its rects' cells that the landmass left bare become open
  water (or more of the drop, with the sea at its foot), and the slab under them is dropped with no cut-away side
  toward them, so the view looks out over the sea to the sky. The 沙盘's bake strips it (its own land has the sea:
  the bay `BAY` in `bake_land.gd`, beside 番坊's three places), as it strips far scenery and props marked
  `"atlas": false` (the far-off roofs of 番坊 seen from the cliff road and the dock).

## Sources by thing (A)

| Thing | Continues |
|---|---|
| 海崖口, 海崖道, 崖脚, the sea god's niche, the salt porters | 剧情总纲 §6 番坊卡 (位置：忘情谷外的小路……海崖道到海边); 计划 §1 |
| the port, its jetties, the three flat-bottomed boats that are others' | theme:4 航海技术并不受重视 (港口小，船是别人的) |
| the bazaar's four 胡商 and their goods, the old storyteller | 剧情总纲 §6 番坊卡 (丝路尽头的番坊：胡商市集); theme:3 (大秦 fallen, its people exiles — Rome is never named) |
| 市舶司, 冯禄, the clerk and the runners | 剧情总纲 §3 第七章 ④ (市舶吏奉兵部令要清走大秦人), 要加「市舶吏冯禄」 |
| the wanted notice | d/city/eastdoor2.c look_notice() word for word, 「京师东二门原告，番坊照抄」 |
| the 兵部文书 and its false seal | 关北 A's 印色 (the mould's 比印, the mark 学过印色); 剧情总纲 §3 第七章 ④ |
| 卢卡 at 铁盾会's gate | 关北 A (他去番坊), DECISIONS「关北 D」 (the stub); 计划 §2 (第六章完就搬到这里) |
| 铁盾会's two great shields | 剧情总纲 §6 番坊卡「大秦剑会『铁盾会』」; 计划 §1 |
