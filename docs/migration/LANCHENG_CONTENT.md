# 岚城 content notes

What the code and the PRs do not record about the region (DECISIONS「第十章 A」「第十章 B」「第十章 C」「风」「拿走」
hold the rules). ES2 has no room, NPC or item of 岚城: three lines name it — doc/help/theme:28–38 (仙人住著，凡夫俗眼
瞧不见，一个樵夫撞进去过), doc/help/history:66–76 (烟霞霓岚四仙城，寻风而至，寻风而逝；旋芒属岚城中一位仙人) and
daemon/class/fighter/master.c (萧辟尘自幼生长於岚城之中). Everything in `game/data/lancheng/` is the outline's (剧情总纲
§3 第十章, §6 岚城卡), the `legacy_source` fields saying which line each thing continues.

## The way in: the mirror's upper way

`d/canyon/fantasy1.c` has three ways; its `up` leads to `d/canyon/dream/tmp.c`「幻影道入口」, whose long is only
「整修中，请往回走:P」. The 幻影道 zone of `lancheng.wilds` keeps `es2:d/canyon/dream/tmp` as its room's legacy id; its
text is native. The down way (`evil/tmp.c`「妖魔道入口」) stays unplaced. The portal is `canyon.fantasy1.up` on the
`canyon.bamboo` map, open once the ninth chapter is done.

## Sources by thing

| Thing | Continues |
|---|---|
| the guiding wind, 伏地 where it stops | the woodcutter's page and the late emperor's reading (第九章 C items): 风大不能行，伏地良久；风停处即是城 / 逆风而行，风止之处，城见 |
| 卜风坛, its three 逆灵宫 diviners, the 卜风签 | 剧情总纲 §2 逆灵宫替庾子建用魔道卜算剑的去向 |
| 兵部旧营 and its frozen scout | the reading's margin 「试过三次，未果」 |
| the 石匣's bell, the 萧家 hook | 序章 白道长「岚城的风铃，寻风的人才用得上」; master.c (萧辟尘, 岚城 born); 计划 §7 Q3 (the bell is his) |
| 岚翁 | history:75 (属岚城中一位仙人所有); the name is the outline's |
| 岚童, 铃匠老蔺, 扫云的老妪, 岚城人 | master.c 不食人间烟火 (no stove, no chimney anywhere) |
| 旋芒 (numbers as 穿灵's) | doc/help/myth:3–23 (寒於携穿灵、旋芒二剑) |
| 於兰天武 drawing it | history:30–34 (君违嫁於兰攸: the 寒於 blood in the 於兰 line) |

## The trust table (十铃架, 计划 §4)

Each bell rings while any one of its marks holds; five of ten let the player draw 旋芒 (the 云台's 自己拔 counts the
same groups with `at_least`). The marks live in three places that must agree: the bells' stage props in
`tools/maps/layouts/lancheng.json` (pavilion), the bell landmarks' `looks` in `world.json`, and the 自己拔 act's
`at_least` groups — `lancheng_town_test` checks the first two bell by bell, `lancheng_terrace_test` the gate.

| Bell | Marks |
|---|---|
| 雪亭 | 放过了刘安禄 |
| 老松岭 | 安葬无名人 |
| 水烟阁 | 替南危水保密, 卫沧澜出了尚书府 |
| 野羊山 | 霍铮回了寨 |
| 晚月庄 | 宝衣给了安妮儿, 瑷伦守到决战 |
| 乔阴 | 陈显祖作了证 |
| 关北 | 关北的骑兵欠你一阵, 王府干净 |
| 番坊 | 火前说了真话, 大秦人留下了 |
| 玉螺湖村 | 查清了封物, 村口的鬼卒退了 |
| 京师 | 冯策随你下湖, 皇叔入朝 |

## Deferred

- The drawer carries no sword on their back afterwards (person looks do not change by marks).
- 岚城's people keep the street day and night.
- From the plan's A package: walking downwind off the map's edge does not blow one back to the 幻影道 (the gale is the cost), and the woodcutter's page and the reading have no 「读」 act.
