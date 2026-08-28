# Phase 7A：首个 World / Map / NPC / Spawn / Interaction 依赖分析

状态：**READY FOR PHASE 7B1**
性质：分析与设计契约；本阶段不修改生产 GDScript、不创建地图场景、不修改 `reference/es2/`。

## 1. 已正式关闭的前置阶段

- Phase 6B3 已关闭。
- Phase 6B 已关闭。
- First Playable Combat Vertical Slice 已关闭。
- 已关闭的 Combat Core、角色、技能、物品、装备、死亡与尸体领域仍是权威规则层；Phase 7 不复制或改写这些规则。
- 当前 `combat_vertical_slice.tscn` 只是 encounter-local 的可玩验证场。它证明了 `CharacterBody2D`、目标选择、战斗节拍、生命周期和尸体视图可以工作，但不是永久 World 架构。

依据：

- `docs/migration/PHASE_6A_FIRST_PLAYABLE_COMBAT_VERTICAL_SLICE_ANALYSIS.md`
- `docs/migration/PHASE_6B1_RUNTIME_COMBAT_OPPORTUNITY_BRIDGE.md`
- `docs/migration/PHASE_6B2_PLAYABLE_COMBAT_ARENA.md`
- `docs/migration/PHASE_6B3_OUTER_LIFECYCLE_DEATH_CORPSE.md`
- `game/runtime/combat_slice/combat_slice_character_binding.gd`
- `game/runtime/combat_slice/combat_slice_character_body.gd`
- `game/runtime/combat_slice/combat_vertical_slice_controller.gd`
- `game/scenes/combat/combat_vertical_slice.tscn`

## 2. 检查范围与数量

`reference/es2/mudlib/d/oldpine/` 的目标扫描宇宙共有 **80 个 `.c` 文件**：

| 目录 | 文件数 | 实际含义 |
|---|---:|---|
| `d/oldpine/*.c` | 41 | 41 个直接房间文件 |
| `d/oldpine/npc/*.c` | 14 | 13 个 NPC；`skeleton.c` 实际继承 `ITEM` |
| `d/oldpine/obj/*.c` | 11 | 11 个物件文件 |
| `d/oldpine/npc/obj/*.c` | 14 | 11 个与 `obj/` 逐字节相同的副本，另有 3 个独有物件 |

因此 authored item 文件为 25 个，但只有 **14 组独立物件语义**。重复的 11 对文件经 SHA-256 比较完全相同，未来不能因旧目录重复而建立两个 native definition。

为解释继承与运行语义，还检查了：

- `std/room.c`、`include/room.h`、`include/globals.h`
- `cmds/std/go.c`、`feature/move.c`
- `std/char.c`、`std/char/npc.c`
- `feature/attack.c`、`feature/skill.c`
- `adm/daemons/chard.c`
- `adm/daemons/race/human.c`、`adm/daemons/race/beast.c`
- `adm/daemons/combatd.c` 中 `auto_fight()` 相关链路
- `obj/money/silver.c`、`std/money.c`

没有扫描整个 mudlib。

## 3. 完整房间清单

约定：

- `outdoor` / `water` 只记录 LPC 明确设置的标志，不从描述文字补推。Oldpine 中这些标志并不一致，例如 `clearing.c` 描述显然在室外，但没有设置 `outdoors`。
- `setup()` 会动态调用 `reset()`。普通房间的 `reset()` 来自 `std/room.c`；带 `objects` 的房间会补足并追踪对象。
- `R-reset` 表示每次房间 reset 都重抽出口；`R-load` 表示只在房间对象创建时抽一次。

| LPC 房间 | short / 类别 | 出口摘要 | hooks / 限制 | 初始对象与 reset | 环境与 native 解释 |
|---|---|---|---|---|---|
| `cave1.c` | 山洞 / 洞穴迷阵 | 随机四向；北固定可到 `cave2` | 无 | `R-reset` | CaveMap 连续洞穴迷宫 |
| `cave2.c` | 山洞 / 洞穴迷阵 | 随机四向；东固定 `cave4` | 无 | `R-reset` | CaveMap 连续洞穴迷宫 |
| `cave3.c` | 山洞 / 洞穴迷阵 | 四向随机 `cave1..4` | 无 | `R-reset` | CaveMap 连续洞穴迷宫 |
| `cave4.c` | 山洞 / 洞穴迷阵 | 随机三向；西固定 `cave5` | 无 | `R-reset` | CaveMap 连续洞穴迷宫 |
| `cave5.c` | 山洞 / 洞底 | 东下至 `waterfall` | `bury skeleton`；动态 `wall` 描述 | 骸骨 1；埋葬时可生成 `parrybook` | 洞穴深处；到瀑布为出图 portal |
| `clearing.c` | 林间空地 / 中央 hub | 西 `npath3`、北 `spath1`、东 `epath1` | `climb pine`；`valid_leave` 只向树上播报 | 无 | 主要连续地形；松树为 interactable |
| `cliff1.c` | 山壁窄穴 / 垂直落脚点 | 无普通出口 | `climb up/down` | 无 | OutdoorMap 的特殊悬崖 zone |
| `cliff2.c` | 山壁窄穴 / 垂直落脚点 | 无普通出口 | `climb up/down` | 无 | OutdoorMap 的特殊悬崖 zone |
| `cliffdown.c` | 悬崖边 / 松林边界 | 四向随机 `pine1..6`；东北 `pine7` | `climb down` | `R-load` | 松林连续地形边缘 + 互动下降点 |
| `cliffside.c` | 悬崖边 / 松林边界 | 仅北 `pine1` | 无；描述暗示可下爬但没有动作 | 无 | 连续松林边缘；源代码单向异常需保留记录 |
| `epath1.c` | 林间小路 / 东路 | 西 `clearing`、东 `epath2` | 无 | 无 | 连续地形 |
| `epath2.c` | 小石桥 / 东路地标 | 西 `epath1`、东 `epath3` | `hold/grab vine` 条件转移 | 无 | 连续桥面 + 条件 interaction portal |
| `epath3.c` | 林间小路 / 东路尽头 | 西 `epath2` | 无 | 疯老头子 1 | 连续地形死端；另有来自 `cliff2` 的单向落点 |
| `keep1.c` | 老松寨秘密入口 / 寨门 | 西 `pine2`、东 `keep2` | 无 | 土匪喽罗 4 | KeepMap 入口；与松林间是地图 portal |
| `keep2.c` | 老松寨 / 院落陷阱 | 西 `keep1`、东 `keep3` | 向东时封西门并生 5 守卫；`pipe_notify()` 开门 | 守卫 2、首领 1；reset 重开门 | KeepMap；有明确状态化 trap policy |
| `keep3.c` | 老松寨 / 大厅 | 西 `keep2` | 无 | 首领 3、寨主 1 | KeepMap 内部死端 |
| `lake.c` | 水潭 / 水域死端 | 北 `riverbank1` | 无 | 黑冠巨蟒 5 | 明确 `resource/water=1`；OutdoorMap 水域 zone |
| `npath1.c` | 林间小路 / 北界 | 南 `npath2`、北 `/d/snow/eroad3` | 无 | 无 | `outdoor`；北向跨 Region portal |
| `npath2.c` | 林间小路 / 北路 | 东南 `npath3`、北 `npath1` | 无 | 无 | `outdoor`；连续地形 |
| `npath3.c` | 林间小路 / 北路 | 东 `clearing`、西北 `npath2` | 无 | 无 | `outdoor`；连续地形 |
| `passage.c` | 秘密通道入口 / 洞口 | 北 `secrectpath1`、南 `waterfall` | 无 | 注释掉的 maniac 不生效 | CaveMap 入口；南向瀑布单向出图 |
| `path3.c` | 秘密通道 / 洞内 | 南 `secrectpath1` | `climb up` 到 `stone` | 无 | CaveMap；显式互动转移 |
| `pine1.c` | 松树林 / 迷林 | 三向随机 `pine2..6`；西 `pine4` | `valid_leave` 仅输出迷向文本 | 高瘦土匪 1、矮胖土匪 1；`R-reset` | 连续松林迷宫；不保留罗盘房格 |
| `pine2.c` | 松树林 / 迷林与寨入口 | 三向随机 `pine2..6`；东 `keep1` | `valid_leave` 仅文本 | `R-reset` | 连续松林；东为 KeepMap portal |
| `pine3.c` | 松树林 / 迷林 | 四向随机 `pine2..6` | `valid_leave` 仅文本 | `R-load` | 连续松林迷宫 |
| `pine4.c` | 松树林 / 迷林 | 三向随机 `pine2..6`；北 `pine5` | `valid_leave` 仅文本 | `R-reset` | 连续松林迷宫 |
| `pine5.c` | 松树林 / 迷林 | 三向随机 `pine2..6`；北 `pine6` | `valid_leave` 仅文本 | `R-reset` | 连续松林迷宫 |
| `pine6.c` | 松树林 / 迷林 | 三向随机 `pine2..6`；西 `pine7` | `valid_leave` 仅文本 | `R-reset` | 连续松林迷宫 |
| `pine7.c` | 松树林 / 迷林出口 | 四向随机 `pine2..6`；西南 `cliffdown` | `valid_leave` 仅文本 | 狼狗 1；`R-reset` | 连续松林迷宫 |
| `riverbank1.c` | 山涧之中 / 河谷 | 北 `riverbank2`、南 `lake` | `climb cliff` 到 `cliff1` | 无 | `outdoor+water`；连续河谷 + 互动攀爬 |
| `riverbank2.c` | 山涧之中 / 河谷 | 北 `waterfall`、南 `riverbank1` | 无 | 无 | `outdoor+water`；连续河谷 |
| `secrectpath1.c` | 秘密通道 / 洞内 | 北 `path3`、南 `passage` | 无 | 无 | CaveMap；文件名拼写是 legacy metadata |
| `spath1.c` | 林间小路 / 南路 | 南 `clearing`、北 `spath2` | 无 | 土匪探哨 3 | `outdoor`；连续地形，首个 NPC 来源点 |
| `spath2.c` | 下坡道 / 南路 | 南 `spath1`、北 `spath3` | 无 | 无 | `outdoor`；连续地形 |
| `spath3.c` | 下坡道 / 南路 | 南 `spath2`、北 `spath4` | 无 | 无 | `outdoor`；连续地形 |
| `spath4.c` | 下坡道 / 南端死路 | 南 `spath3` | 无 | 无 | `outdoor`；注释掉的 Choyin 边不生效 |
| `stone.c` | 大青石上 / 洞内高台 | 无普通出口 | `climb down` 到 `cave1` | 金银花蛇 1 | CaveMap 特殊落点 |
| `tree1.c` | 大松树上 / 树干 | 上 `tree2`、下 `clearing` | 无 | 黑衣人 1 | OutdoorMap 内 TreeCanopyZone |
| `tree2.c` | 大松树上 / 树冠 | 上 `tree3`、下 `tree1` | 无 | 蝴蝶 6 | OutdoorMap 内 TreeCanopyZone |
| `tree3.c` | 大松树顶 / 树顶 | 下 `tree2` | 无 | 无 | 显式 `outdoor`；TreeCanopyZone 顶端 |
| `waterfall.c` | 瀑布前 / 河谷地标 | 南 `riverbank2` | 无 | 无 | `water`；OutdoorMap，多个单向 portal 落点 |

### 房间描述的去向

- `short`：Zone/landmark 名称与 inspect 标题候选。
- `long`：地图氛围、区域 inspect 文本和美术参考；不自动弹出为每个旧房间的模态框。
- `item_desc`：明确可检查对象的数据，例如 clearing 的 `pine/sign`、epath2 的 `vine/waterfall`、cave5 的 `wall`。
- 能由场景直接表达的树、桥、河、瀑布和悬崖优先视觉化；文本仍保留 legacy source metadata，不能丢弃。

## 4. 旧房间图与逐房间转移

### 4.1 主干结构

```text
/d/snow/eroad3
       ↑
npath1 ↔ npath2 ↔ npath3 ↔ clearing ↔ epath1 ↔ epath2 ↔ epath3
                              │            │ vine
                              │            ├─ success → passage → secrectpath1 → path3
                              │            └─ failure → waterfall
                              │ climb pine                       │ climb up
                              ↓                                  ↓
                         tree1 ↔ tree2 ↔ tree3                 stone
                                                                 │ climb down
                                                                 ↓
                            cave1..4 randomized maze → cave5 ─→ waterfall
                                                                  ↓
spath4 ↔ spath3 ↔ spath2 ↔ spath1 ↔ clearing          waterfall ↔ riverbank2
                                                                  ↕
                                                              riverbank1 ↔ lake
                                                                  │ climb
                                                                  ↓
                                                               cliff1
                                                                  │ up
                                                                  ↓
                                                              cliffside → pine1
                                                                            │
                         pine1..7 randomized maze ─ pine2 → keep1 ↔ keep2 ↔ keep3
                                      │ pine7
                                      ↓
                                  cliffdown
                                      │ climb down
                                      ↓
                                   cliff2 ─ climb down → epath3
```

### 4.2 完整 outbound topology 表

原生分类：`W` 连续步行；`P` map/zone portal；`I` 显式交互 portal；`C` 条件转移；`M` 迷宫语义，需改造成连续几何而非运行时 ROOM 图；`X` 跨当前 Region；`F` 仅表现副作用。

| 来源 | LPC direction/action → 目标 | 原生分类 |
|---|---|---|
| `cave1` | S/E → `cave1..4`；N → `cave2`；W → `cave1..3` | M（CaveMap 连续迷宫） |
| `cave2` | S/N → `cave1..4`；W → `cave1..3`；E → `cave4` | M |
| `cave3` | S/N/W/E → `cave1..4` | M |
| `cave4` | S/N/E → `cave1..4`；W → `cave5` | M |
| `cave5` | eastdown → `waterfall` | P，CaveMap → OutdoorMap |
| `clearing` | W → `npath3`；N → `spath1`；E → `epath1` | W |
| `clearing` | `climb pine` → `tree1` | I，进入 TreeCanopyZone |
| `cliff1` | `climb up` → `cliffside`；`climb down` → `riverbank1` | I |
| `cliff2` | `climb up` → `cliffdown`；`climb down` → `epath3` | I；后者源代码单向 |
| `cliffdown` | S/N/E/W → `pine1..6`；NE → `pine7` | M/W |
| `cliffdown` | `climb down` → `cliff2` | I |
| `cliffside` | N → `pine1` | W；没有回 `cliff1` 的源代码边 |
| `epath1` | W → `clearing`；E → `epath2` | W |
| `epath2` | W → `epath1`；E → `epath3` | W |
| `epath2` | `hold/grab vine`，有效 dodge 随机成功 → `passage`，失败 → `waterfall` | C；typed policy + portal |
| `epath3` | W → `epath2` | W；普通路径死端 |
| `keep1` | W → `pine2`；E → `keep2` | W（KeepMap 内）/ P（与 OutdoorMap 边界） |
| `keep2` | W → `keep1`；E → `keep3` | W；E 经过 trap trigger/policy |
| `keep3` | W → `keep2` | W |
| `lake` | N → `riverbank1` | W |
| `npath1` | S → `npath2`；N → `/d/snow/eroad3` | W / X |
| `npath2` | SE → `npath3`；N → `npath1` | W |
| `npath3` | E → `clearing`；NW → `npath2` | W |
| `passage` | N → `secrectpath1`；S → `waterfall` | W（CaveMap 内）/ P（单向出图） |
| `path3` | S → `secrectpath1` | W |
| `path3` | `climb up` → `stone` | I |
| `pine1` | S/N/E → `pine2..6`；W → `pine4` | M |
| `pine2` | S/N/W → `pine2..6`；E → `keep1` | M / P |
| `pine3` | S/N/W/E → `pine2..6` | M |
| `pine4` | S/W/E → `pine2..6`；N → `pine5` | M |
| `pine5` | S/W/E → `pine2..6`；N → `pine6` | M |
| `pine6` | S/N/E → `pine2..6`；W → `pine7` | M |
| `pine7` | S/N/W/E → `pine2..6`；SW → `cliffdown` | M/W |
| `riverbank1` | N → `riverbank2`；S → `lake` | W |
| `riverbank1` | `climb cliff` → `cliff1` | I |
| `riverbank2` | N → `waterfall`；S → `riverbank1` | W |
| `secrectpath1` | N → `path3`；S → `passage` | W |
| `spath1` | S → `clearing`；N → `spath2` | W |
| `spath2` | S → `spath1`；N → `spath3` | W |
| `spath3` | S → `spath2`；N → `spath4` | W |
| `spath4` | S → `spath3` | W；死端 |
| `stone` | `climb down` → `cave1` | I；进入洞穴迷宫，源代码无反向边 |
| `tree1` | U → `tree2`；D → `clearing` | W/I（树冠 zone 内攀爬） |
| `tree2` | U → `tree3`；D → `tree1` | W/I |
| `tree3` | D → `tree2` | W/I；顶端死路 |
| `waterfall` | S → `riverbank2` | W；没有回 passage/cave5/epath2 的边 |

图中存在：

- 普通双向链与小循环：北路、南路、东路、河谷和树冠。
- 大循环：`epath2` 的藤蔓 → 地下 → 洞穴 → 瀑布 → 河谷 → 悬崖 → 松林 → `cliff2` → `epath3`。
- 两套随机迷宫：`pine*` 与 `cave1..4`。
- 单向边：`passage/cave5 → waterfall`、`cliff1 → cliffside`、`cliff2 → epath3`、`stone → cave1`。
- 死端：`spath4`、`lake`、`tree3`、`keep3`，以及只看普通出口时的 `epath3`。
- 区域外连接：只有 `npath1 north → /d/snow/eroad3` 是有效外部边；`spath4` 的 Choyin 边已注释。

## 5. 推荐的 native Region / Map / Zone 边界

```text
World
└── OldPineRegion                       id: oldpine
    ├── OldPineOutdoorMap               id: oldpine.outdoor
    │   ├── NorthApproachZone
    │   ├── CentralClearingZone
    │   ├── SouthSlopeZone
    │   ├── EastBridgeZone
    │   ├── RiverGorgeZone
    │   ├── PineMazeZone
    │   ├── CliffLedgeZone
    │   └── TreeCanopyZone
    ├── OldPineCaveMap                  id: oldpine.cave
    │   ├── WaterfallPassageZone
    │   ├── SecretPassageZone
    │   └── CaveMazeZone
    └── OldPineKeepMap                  id: oldpine.keep
        ├── KeepEntranceZone
        ├── KeepCourtyardZone
        └── KeepHallZone
```

只建议 **3 个 Godot map scenes**：Outdoor、Cave、Keep。TreeCanopy 与 CliffLedge 是 Outdoor scene 内的非连续 zone/落点，不需要额外场景。这样可保留重要空间边界，又避免一个 LPC ROOM 一个 `.tscn`。

### 5.1 41 个 LPC 房间的归并计数

- **24 个**成为 OutdoorMap 的连续地形/地标：`npath1..3`、`clearing`、`spath1..4`、`epath1..3`、`pine1..7`、`cliffside`、`cliffdown`、`riverbank1..2`、`lake`、`waterfall`。
- **17 个**成为 portal 所连接的特殊 zone 或内部空间：
  - 2 个悬崖落脚点：`cliff1..2`；
  - 3 个树冠层：`tree1..3`；
  - 9 个洞穴/秘密通道空间：`passage`、`secrectpath1`、`path3`、`stone`、`cave1..5`；
  - 3 个山寨空间：`keep1..3`。

这不是 24 个地形节点加 17 个独立场景。房间只用于追踪哪些 authored landmarks/behaviors 被合并。

### 5.2 连续与 portal 的 native 映射

| LPC 边族 | native 表达 | 原因 |
|---|---|---|
| 北路、南路、东路、clearing | 连续步行 | ROOM 边界只是文本导航切段 |
| riverbank/lake/waterfall | OutdoorMap 连续河谷和水域碰撞 | 物理连续，水域/悬崖由碰撞表达 |
| pine1..7 与 cliffdown 随机边 | PineMazeZone 连续迷宫几何；随机换边暂缓为设计 policy | 保留“迷失、循环、隐蔽路线”的意图，不仿真 reset 出口表 |
| cave1..4 随机边 | CaveMap 连续洞穴迷宫；随机换边暂缓 | 同上 |
| `npath1 → /d/snow/eroad3` | Region portal | 真正的区域边界，Snow 不在本阶段 |
| `pine2 ↔ keep1` | OutdoorMap ↔ KeepMap scene portal | 山寨是独立封闭区域且有门陷阱状态 |
| `epath2 vine → passage/waterfall` | 条件 interaction portal | 明确动作、技能随机检查和两个落点 |
| `cave5/passage → waterfall` | CaveMap → OutdoorMap portal | 真实跨图且源代码单向 |
| clearing/tree、riverbank/cliff、path3/stone/cave | 同 scene 或跨 scene 的显式 interaction portal | 必须由 climb/grab 等玩家动作触发，不是普通走路 |
| `keep2 east → keep3` | KeepMap 内 Area trigger + typed trap policy | 移动允许，但先封门并生敌，不是普通无副作用边 |

## 6. 特殊交互、动态行为与遗留异常

| 来源 | 精确语义 | 分类 / 迁移结论 |
|---|---|---|
| `clearing.c` | `climb pine → tree1`；进入/离开 clearing 时向 tree1 输出远处动静 | climb 为 interactable + portal；远处文字为 presentation event |
| `epath2.c` | `hold/grab vine`；使用 `query_skill("dodge")` 的有效值，`random(value) < 5` 失败到 waterfall，否则到 passage | typed conditional portal policy；随机与技能依赖必须后移，不能近似 |
| `riverbank1.c` | `climb cliff → cliff1` | interaction portal |
| `cliff1.c` | up → cliffside；down → riverbank1 | interaction portal |
| `cliffdown.c` / `cliff2.c` | cliffdown down ↔ cliff2 up；cliff2 down → epath3 | interaction portal；最后一条单向 |
| `path3.c` / `stone.c` | path3 up → stone；stone down → cave1 | interaction portal；`path3.do_climb` 成功移动后没有显式 return，属于可执行但返回值异常 |
| `cave5.c` | 埋葬房内 skeleton 后移入 void；`random(kar+10)>25` 掉 `parrybook` 并留在原地；`>20` 仅纸片后坠入 waterfall；其余直接坠落 | 后续 authored quest/interaction policy；不可在首图用通用 callback 仿真 |
| `keep2.c` | 第一次向东且西门仍在：先删除 keep2 西边和 keep1 东边，再原地生成 5 个守卫并 `kill_ob(me)`，随后仍允许去 keep3 | typed trap state + spawn/combat intent；不是 portal 自己执行任意方法 |
| `bamboo_pipe.c` | 使用物件时直接调用当前环境的 `pipe_notify()`；在 keep2 恢复出口 | 未来物件交互能力 + 明确 KeepGatePolicy；不迁移字符串方法派发 |
| `pine*.c` | `valid_leave` 仅输出迷向文字，不阻挡移动 | presentation only |

明确异常/歧义：

- `cliffside.c` 文本声称似乎可爬下，但没有 `init/add_action`，且从 `cliff1` 上来后无反向边。不能静默补边。
- `cliffdown.c` 的下爬文字写成“爬了上去”，是表现文本矛盾。
- `epath2.c` 在有效 dodge 为 0 时会调用 `random(0)`；具体驱动语义需要在迁移该 policy 时确认。
- `path3.c` 成功移动后没有显式返回值；移动已经发生，命令处理返回语义异常。
- `secrectpath1.c` 是源文件拼写；native ID 可正确拼写，但必须保留 legacy path。
- `npc/obj/parrybook.c` 的 `replica_ob` 指向当前目录不存在的 `cola`。
- 多个文件头注释写错文件名，不作为身份来源；真实 source path 才是 metadata。

## 7. 世界定义与运行时状态边界

### 7.1 最小 immutable authored definitions

Phase 7B1 建议只引入：

- `RegionDefinition`
  - `region_id: StringName`
  - `display_name: String`
  - `legacy_source_roots: Array[String]`
- `MapDefinition`
  - `map_id: StringName`
  - `region_id: StringName`
  - `scene_path: String`（内容定位，不保存 Node）
  - zone、portal、spawn 的稳定 ID 列表
- `ZoneDefinition`
  - `zone_id: StringName`
  - `map_id: StringName`
  - `combat_location_id: StringName`
  - `display_name`、legacy room IDs、可选 flavor/inspect metadata
- `PortalDefinition`
  - 见第 11 节
- `NpcDefinition`、`NpcSpawnDefinition`
  - 见第 9、10 节

定义不持有 `Node`、`Marker2D`、`Callable`、任意 payload dictionary 或场景实例。

当前不需要 `ItemRepository` 风格的 WorldRepository，也不需要全局 `WorldManager`。首批 Oldpine definitions 可以由一个窄的 typed content factory/catalog 提供；它是 immutable content lookup，不是状态所有者。

### 7.2 map-local runtime 所有权

每个已加载地图有一个本地 composition root，负责：

- 当前地图的角色运行绑定集合；
- spawn instance ID → NPC runtime/body 的本地映射；
- map-local `InventoryState` / stack authority 的接线；
- 当前地图中的战斗机会节拍适配；
- zone/portal/interaction 信号转为 typed requests；
- 尸体 domain state、物理位置与 corpse view；
- HUD/presenter 的输入输出接线。

它不是 singleton，也不拥有 Character/Combat 公式。离开地图时 scene nodes 可释放；是否保留 NPC/尸体持久状态是未来 persistence 决策。

建议最小运行结构：

```text
OldPineOutdoorRuntime (Node, composition root)
├── MapCharacterRuntimeState (RefCounted, map-local collection)
│   ├── player WorldCharacterRuntimeBinding
│   └── N × NPC runtime bindings
├── local InventoryState / CombinedStackCollection
├── local combat cadence adapter
├── portal + interaction adapters
├── corpse states / corpse views
└── presentation adapters / HUD
```

不建立 global entity registry。

## 8. Location identity 与 Combat same-location

物理 `Vector2` 不能作为 combat same-location：浮点相等既不稳定，也会让相距几像素的对象突然断开关系。

建议继续向 Combat Core 只投影现有三个事实：

- `exists`
- `same_location`
- `living`

World runtime 保存：

- `region_id`
- `map_id`
- `zone_id`
- 一个不解析字符串结构的稳定 `combat_location_id: StringName`
- CharacterBody 自己的 `global_position: Vector2`

`same_location` 仅由两个有效 runtime binding 的 `combat_location_id` 相等得出。Zone 的 Area2D/trigger 更新该 ID；Combat Core 仍只接收 bool projection，不依赖 World 类型。

首图可用例如：

- `oldpine.outdoor.central_clearing`
- `oldpine.outdoor.south_slope`
- `oldpine.outdoor.east_bridge`
- `oldpine.outdoor.pine_maze`

ID 是 opaque stable identity，不靠分隔符解析。它替代 `&"combat_vertical_slice_arena"`，但不模拟 LPC `environment()`。正常跨 combat location 后，下一次 opponent availability cleanup 会移除不再同地点的对象；World runtime 不直接改 Combat 关系内部集合。

## 9. 完整 Oldpine NPC 清单与依赖分类

分类：A 简单静态；B 简单主动战斗；C authored special；D boss/高依赖；E 非人/特殊种族。Oldpine 没有纯 A 的低依赖人类 NPC。

| 文件 / 名称与 IDs | authored 角色事实 | 技能 / apply | 携带、装备、金钱 | hooks 与依赖 | 类别 |
|---|---|---|---|---|---|
| `bandit.c` 土匪探哨 (`bandit`) | 男 19；exp 600；score 60；aggressive | sword/parry/dodge 10 | 短剑 wield；银 3 | 无 special；依赖人类默认属性生成 | B |
| `bandit_guard.c` 土匪喽罗 (`bandit`) | 男 33；exp 3600；score 260；bellicosity 600；aggressive | sword 50、parry/dodge 40 | 短剑 wield；银 5 | 无 special | B |
| `tall_bandit.c` 土匪 (`bandit`) | 男 27；exp 900；score 100；aggressive | sword/parry 15、dodge 10 | 长剑 wield；银 6 | 无 special | B |
| `fat_bandit.c` 土匪 (`bandit`) | 男 36；exp 500；score 80；aggressive | sword 20、parry/dodge 10 | 短剑 wield、皮衣 wear；银 5 | combat chat 可一次性在现场 `new bandit_chief` | C |
| `bandit_chief.c` 土匪老大 (`bandit chief`,`chief`) | 男 39；exp 6000；score 700；aggressive | blade 60、parry/dodge 50；apply attack 50/dodge 30 | 单刀 wield、皮衣 wear；银 30 | reinforcement 的 `start_help` 表现；combat chat | C |
| `bandit_leader.c` 土匪首领 | 男 47；exp 50000；score 7700；bellicosity 3000；aggressive；force 1300/max 700/factor 4 | blade 60、parry/dodge 70；apply attack 70/dodge 50 | 单刀 wield、皮衣 wear；银 30 | force、combat chat、高战力 | D |
| `bandit_commander.c` 常老大 | 男 53；exp 260000；score 17000；bellicosity 6000；aggressive；force 1500/max 1000/factor 3 | force 60、blade/parry 100、dodge 70；apply attack 100/defense 60 | 鬼头刀 wield；皮衣+狼皮披风 wear；竹管；银 50 | boss；竹管连接 KeepGate 行为 | D |
| `maniac.c` 疯老头子 | 男 67；str/cor 30；exp 40000；score 8000；bellicosity 10000；force 600/max 600/factor 2；mana 800/max 800 | unarmed 50、dodge 70、force 100、spells 50、necromancy 70；spells 映射；apply attack 30/damage 20 | 太阴八卦袍 wear | combat chat 施法；无 explicit aggressive | D |
| `spy.c` 黑衣人 (`spy`) | 男 24；exp 6000；score 400；bellicosity 2000 | throwing/unarmed/sword/parry 20、dodge 40 | 飞刀 30 wield、夜行衣 wear、`/obj/dust` 30 | `killed_enemy` 延迟 dissolve corpse；尸体/combined/外部 item 依赖 | C |
| `butterfly.c` 蝴蝶 | 野兽；雌 1；str 6/cor 8/per 33；exp 100；score 10；peaceful | apply dodge 50；bite；自定义 limbs | 无 | 非战斗 chat；beast defaults/action | E |
| `serpent.c` 黑冠巨蟒 | 野兽 400；aggressive；max gin/kee/sen 900/1800/500；str40 cor70 spi20 int10；exp250000 score1000 | bite；apply attack60 damage20 armor90 dodge80 | 无 | 高战力 beast action | E/D |
| `venomsnake.c` 金银花蛇 | 野兽 5；pursuer；aggressive；max 260/260/100；str10 cor50；exp30000 | bite；apply attack70 damage70 armor60 | 无 | `hit_ob` 条件施加 snake_poison | E/C |
| `wolf_dog.c` 狼狗 | 野兽 4；aggressive；显式 kee/eff_kee 200；str26 cor30；exp10000 | bite/claw；apply attack45 damage40 armor45 | 无 | chat；beast default 其余状态 | E |
| `skeleton.c` 一具已经腐朽的骸骨 | **不是 NPC**；继承 `ITEM`；weight 3500；`no_get` | 无 | cave5 房间 prop | `bury` 的目标 | item |

NPC room placements 共 31 个初始角色实例：

- `spath1`: bandit ×3
- `pine1`: tall_bandit ×1、fat_bandit ×1
- `pine7`: wolf_dog ×1
- `epath3`: maniac ×1
- `lake`: serpent ×5
- `stone`: venomsnake ×1
- `tree1`: spy ×1
- `tree2`: butterfly ×6
- `keep1`: bandit_guard ×4
- `keep2`: bandit_guard ×2、bandit_leader ×1
- `keep3`: bandit_leader ×3、bandit_commander ×1

`bandit_chief` 不是常驻 placement，由 fat_bandit 的战斗 hook 动态生成；keep2 trap 另生成 5 个 guard。

所有这些 NPC 都仍依赖种族 setup。人类未显式写出的八项基础属性由 `race/human.c` 各自 `random(21)+10` 生成；野兽有另一组随机默认值和 verb action provider。因此 `NpcDefinition` 必须区分“显式 authored override”和“种族初始化结果”，不能把当前 demo 的固定 20 写成原作事实。未来创建 runtime state 时应使用窄的、可注入/可测试的初始化随机源，不能借用全局 RNG 或 Combat RNG。

## 10. 首个 authored NPC 与 spawn 语义

### 10.1 选择：`bandit.c` 土匪探哨

选择它而不是只看文件最短：

- 它位于 central clearing 直接相邻的 `spath1`，适合首个可见地图子集。
- 是默认人类，Phase 1 已覆盖人类资源派生；不需要 beast action、毒、施法、支援、boss force 或 corpse dissolve。
- 行为仅有 aggressive、exp/score、三个基础技能、短剑和银两。
- 短剑、combined currency、equipment/inventory/death 已有关闭的领域基础；需要的是 authored content binding，而不是新系统。

代价必须公开：`spath1.c` 的原始 placement 数量是 **3**。7B1 的 `NpcSpawnDefinition` 应记录 quantity 3，不应把 source quantity 静默改成 1。若 7B2 为控制可见里程碑只激活一个实例，必须明确标记为 partial-content smoke placement，不能宣称 `spath1` 已 parity。更推荐让三个静态实例共存，但第一轮只开放显式选择/攻击，不实现群体 AI。

### 10.2 NPC definition / runtime / spawn 分离

`NpcDefinition`（immutable content）：

- definition ID、legacy source path、name/aliases；
- race、gender、age 的显式事实；
- authored attribute/resource overrides；
- combat_exp、score、attitude；
- typed skill-level entries；
- typed loadout entries（item definition、quantity、wield/wear intent）；
- 仅源代码证明的 capability IDs，例如 `aggressive_on_player_presence`。

`NpcRuntimeState`（一个活实例）：

- runtime character/spawn instance ID；
- definition ID 与 spawn ID；
- 独立 `CharacterState`、relationship、busy、armor authority；
- shared map-local InventoryState 中的 owner identity；
- life status、当前 logical location、combat availability；
- spawn lifecycle status。

`NpcSpawnDefinition`（authored placement）：

- spawn ID、NPC definition ID；
- map ID、zone ID、Marker2D spawn-point IDs；
- quantity；
- source room path/quantity metadata；
- 初次创建策略；只有源代码证明时才增加 respawn policy。

物理坐标和 facing 来自 scene 中稳定命名的 `Marker2D`，不写入 `NpcDefinition`。

### 10.3 LPC spawn/reset 的准确含义

`std/room.c`：

1. `setup()` 立即调用房间 `reset()`；
2. `objects[path] = amount` 表示房间希望维持的实例数；
3. 缺失/已 destruct 的对象在后续 reset 补建；
4. 活着但离家的 character 会尝试 `return_home(room)`；正在战斗、非 living 或当前环境无 exits 时返回失败；
5. `make_inventory()` 以 `new(file)` 创建、移动进房间并写入 `startroom`。

这不是“每隔 N 秒全局 respawn”。首个 world slice 只需要地图实例加载时按 SpawnDefinition 建立初始 NPC。死亡后的 respawn 时机没有必要在 7B1/B2 猜测；不添加全局 Timer。未来若要还原 room reset 补建，使用 map-local spawn lifecycle policy 与显式调度器。

## 11. aggressive 的实际依赖链

原作链路：

1. MudOS 因玩家与 NPC 同一 `environment` 调用角色 `init()`；
2. `feature/attack.c::init()` 先拒绝 NPC 已在战斗、任一方不 living、不同 environment、玩家 linkdead 等；
3. hatred/vendetta 检查先于 attitude；随后仅当 `userp(ob)` 且 NPC `attitude == "aggressive"` 时调用 `COMBAT_D->auto_fight(..., "aggressive")`；
4. `auto_fight()` 禁止 NPC 对 NPC，使用 `looking_for_trouble` 防重复，并以零延迟 `call_out` 给玩家离开机会；
5. `start_aggressive()` 再次检查对象存在、NPC living、仍同 environment、尚未在战斗、房间非 `no_fight`；
6. 通过 `kill_ob(player)` 建立致命战斗。

native 最小语义不是通用仇恨 AI，而是：

```text
authored aggressive NPC
+ player enters NPC perception/presence Area2D
+ both active/living
+ same combat_location_id
+ zone permits combat
→ map-local runtime requests existing lethal combat initiation
```

Area2D 代表 RPG 中的“看见/接近”，不是 Combat Core 公式，也不是 NPC 寻路。必须去重并在请求执行前重查 co-location。hatred、vendetta、berserk、pursuer 全部暂缓。

结论：自动 aggression 不进入 headless 的 7B1。为控制第一张可见地图与 `spath1 ×3` 的风险，7B2 可先保留玩家显式 Attack；aggressive presence adapter 放入 7B3 的窄集成。它属于首个完整 Oldpine world milestone，但不应阻挡 7B2 地图/战斗接线。

## 12. 最小 interaction 与 portal 模型

### 12.1 Interaction

不建命令解析器。最小 typed 路径：

```text
player enters range / clicks target
→ InteractionTarget identity
→ Array[InteractionOption]
→ selected typed request
→ map-local adapter executes a known service/portal
→ typed result to presentation
```

首批 action kinds：

- `INSPECT`
- `ATTACK`
- `TRAVERSE_PORTAL`（例如 climb pine）

NPC inspect 使用 `NpcDefinition` 的 name/long/legacy metadata；世界 inspect 使用 landmark definition 的文本。定义中不放 Callable 或 LPC command string。

### 12.2 PortalDefinition

最小字段：

- `portal_id`
- `source_map_id` / `source_zone_id`
- `destination_map_id` / `destination_zone_id`
- `destination_spawn_point_id`
- `interaction_kind`（walk trigger、interact、climb 等 closed enum）
- 可选 `policy_id`，只引用明确注册的 typed policy
- legacy source path/action metadata

无条件 portal 是纯数据。条件 portal 的 policy 返回允许/拒绝/替代 destination 等 typed result；portal 不执行任意方法。

首个证明用 portal：`clearing.c: climb pine → tree1.c`。它没有随机、技能或物品依赖，风险低于 vine、bury 和 keep trap。

## 13. 物件清单与首 NPC 依赖

以下 11 组在 `obj/` 与 `npc/obj/` 各有一个逐字节相同副本：bamboo_pipe、black_suit、blade、book、fur_coat、glaive、leather、long_sword、robe、short_sword、throwing_knife。另有 3 个只在 `npc/obj/`：black_cloth、mask、parrybook。

| 独立物件语义 | source paths | 关键 authored 事实 / 用途 |
|---|---|---|
| bamboo_pipe | 两目录 | weight 100；play/blow 调当前房间 `pipe_notify`；commander 携带 |
| black_suit | 两目录 | CLOTH；armor 1；整组 disguise props；当前 active NPC 未使用 |
| blade | 两目录 | BLADE damage 25；chief/leader wield |
| book | 两目录 | phantomforce study mapping；当前房间未生成 |
| fur_coat | 两目录 | SURCOAT；armor 8、attack 1；commander wear |
| glaive | 两目录 | BLADE damage 45；commander wield |
| leather | 两目录 | CLOTH；armor 5；多名土匪 wear |
| long_sword | 两目录 | SWORD damage 25；tall_bandit wield |
| robe | 两目录 | CLOTH；armor 2、spells 3；maniac wear |
| short_sword | 两目录 | SWORD damage 15、SECONDARY；bandit/guard/fat wield |
| throwing_knife | 两目录 | combined THROWING，base weight 300/value 80，damage 20；spy amount 30 |
| black_cloth | `npc/obj/black_cloth.c` | CLOTH；armor/dodge +1、personality -1；spy wear |
| mask | `npc/obj/mask.c` | EQUIP slot `mask`；disguise props；当前 active NPC 未使用 |
| parrybook | `npc/obj/parrybook.c` | parry study：exp 15000、sen 30、difficulty 25、max 50；cave5 奖励 |

银两来自 `obj/money/silver.c`：combined amount，base value 100、base weight 37；土匪探哨 amount 3。7B1 只需把现有 item/currency/equipment domain 与该 authored loadout 接起来，不扩展 Inventory 系统。

## 14. 现有 Combat Slice 的复用边界

### 14.1 可复用概念

- binding 聚合对 `CharacterState`、relationship、busy、armor、location/life/combat availability 的引用；
- `CharacterBody2D` 只做物理移动、碰撞、可选中视图；
- map-local participants 投影给 `CombatOpponentSelectionService`；
- cadence、lifecycle、death/corpse domain 的 typed results；
- HUD/presenter 对 typed results 作表现。

### 14.2 不能机械改名为通用系统的部分

- `CombatSliceCharacterBinding` 的 `exists_in_encounter`、`CombatSliceContentProfile` 和 demo identity 是 arena-specific；
- `CombatSliceDemoFactory` 固定两个人、全 20 属性、长剑和 arena ID；
- `CombatVerticalSliceController` 固定 `Player/Enemy`、一个 SelectedTarget、arena corpse destination 和 scene reload；
- `CombatSliceDeathAdapter` 固定姓名、年龄、体重、corpse definition 与 arena endpoint；
- `CombatSliceCharacterBody` 同时含 player input 与通用 selection/death view 逻辑。

建议先创建 world-facing 的薄 `WorldCharacterBody2D`，保持 slice 回归场不动。它只持 runtime binding reference、physics/selectability 和 view state。等真实第二个用例证明重复后再提取共享基类，不能仅 rename。

Map runtime 的 participant collection 必须支持 N 个 NPC，但第一阶段不做 multi-opponent HUD、NPC navigation 或 behavior tree。现有 opponent service 已接收显式 participants/projections，不需要全局 registry。

## 15. World 中的 combat 与 corpse

Map-local composition root 从 `CombatVerticalSliceController` 提取/复用的是编排顺序，不是建立 `CombatManager`：

```text
map-local characters
→ availability projections (exists/same_location/living)
→ existing fight/opportunity/lifecycle services
→ typed results
→ world HUD/presenter and body refresh
```

尸体：

- domain containment endpoint 为当前 Map/Zone 的 `WORLD` endpoint，而不是 arena 常量；
- corpse domain identity/contents 继续由已关闭系统负责；
- 死亡瞬间 `Vector2` 只由 map runtime 记录，用来放置 `CorpseView`；不写入 immutable definitions；
- 当前 map runtime 持有 corpse state/view；离开或重载地图如何持久化暂缓；
- 首里程碑不实现 loot、decay scheduler 或跨图尸体保存；尸体在当前地图实例存活期间留在物理死亡位置。

world death adapter 必须从 NPC definition/runtime 提供真实 display name、gender、age、weight 和 destination，不能沿用 demo 的 `Human Swordfighter` 与固定 20 岁。它仍调用既有 `DeathInventoryService`，不复制死亡规则。

## 16. 地图 authoring 与 Godot AI/MCP 结论

当前编辑器经 MCP 检查为 Godot **4.7.2-stable**，主场景是 `res://scenes/combat/combat_vertical_slice.tscn`。当前层级证实：

- root `Node2D`；
- arena 用 `ColorRect + StaticBody2D/CollisionShape2D`；
- player/enemy 是 `CharacterBody2D`；
- `Camera2D`、local `Timer`、`CorpseLayer`、`CanvasLayer HUD` 均由本地 controller 编排。

首图建议 **hybrid-ready 的 plain Node2D 原型**：

- 先用 Polygon2D/简单地面、StaticBody2D collision、Area2D zones/portals、Marker2D spawns；
- 不等待最终 tiles/art；
- 地形成熟后再把大面积地表替换为 `TileMapLayer`，特殊交互和 spawn markers 仍保留为节点；
- 不需要 `NavigationAgent2D`，首 NPC 静态即可。

Godot AI/MCP 在 7B2/7B3 最适合：创建/检查 scene hierarchy、Marker2D、Area2D、碰撞体、CharacterBody instances、信号连接、portal destination markers，并运行可见 smoke test。它不负责生成 gameplay formulas 或批量把 41 个 ROOM 转成节点。

## 17. 显式暂缓

- 完整 Oldpine 三张地图与全部 31 个初始 NPC 实例的内容 parity；
- pine/cave reset-time 随机出口的最终 RPG redesign；
- vine 的 dodge/random policy；
- cave5 bury/reward/fall；
- keep trap、竹管开门与动态 5 guard；
- hatred、vendetta、berserk、pursuer；
- beast race 初始化与 beast verb action 的 native 接线；
- snake poison hit hook、spells、combat chat、call-for-help、corpse dissolve；
- NPC wandering、navigation、return-home、respawn scheduling；
- dialogue、quest、loot UI、corpse decay、map persistence、world save、streaming；
- Snow/Choyin 等区域；
- final art、tiles 与完整 TileMapLayer authoring。

## 18. Phase 7B1 建议文件（尚未创建）

建议保持最小、typed、无 Node 的 domain/content foundation：

```text
game/core/world/region_definition.gd
game/core/world/map_definition.gd
game/core/world/zone_definition.gd
game/core/world/portal_definition.gd
game/core/world/world_location_state.gd

game/core/npcs/npc_definition.gd
game/core/npcs/npc_skill_level_definition.gd
game/core/npcs/npc_loadout_entry.gd
game/core/npcs/npc_spawn_definition.gd
game/core/npcs/npc_runtime_state.gd
game/core/npcs/npc_character_state_factory.gd
game/core/npcs/npc_initialization_random_source.gd

game/runtime/world/map_character_runtime_state.gd
game/data/oldpine/oldpine_world_definitions.gd
game/data/oldpine/oldpine_npc_definitions.gd
game/data/oldpine/oldpine_spawn_definitions.gd

game/tests/core/world_definition_test.gd
game/tests/core/npc_spawn_foundation_test.gd
```

可在实现时进一步合并只含一个值的文件；不得为了匹配清单强行增加抽象。7B1 不创建 scene、Node runtime controller 或 save DTO。

## 19. 建议 focused tests

### 7B1 headless/domain

- definition IDs、引用和 legacy paths 有效；definition 不持有 Node/Callable；
- `WorldLocationState` 的 region/map/zone/combat location 不混淆；same-location 由 combat location ID 而非 Vector2 决定；
- bandit definition 精确保留 age 19、exp 600、score 60、aggressive、三项 10 级技能；
- `spath1` spawn quantity 精确为 3，三个 runtime IDs 与所有 mutable authorities 独立；
- 注入固定随机序列后，人类缺省属性使用 LPC 的 `random(21)+10` 范围与顺序，资源用已关闭的人类公式；
- short sword amount/equip intent 与 silver amount 3 精确；
- map-local collection 支持 player + 多 NPC，不硬编码两人；
- availability projection 对 exists/living/location 的边界；
- portal definition 无 policy 时为纯数据，有 policy 时只保存 typed policy ID。

### 7B2 scene/integration

- player 可连续移动且 collision 生效；
- zone trigger 更新 logical location，不改 CharacterState；
- 三个 spawn point/实例或明确 partial smoke placement 与 definition 一致；
- inspect/select/Attack 接到现有 combat；
- 一个 NPC 死亡后 corpse WORLD endpoint 正确，view 留在死亡 Vector2，玩家仍可移动；
- scene 不出现 global manager/autoload。

### 7B3 portal/aggression

- clearing climb portal 只在交互后转移到 tree spawn，返回目标稳定；
- aggressive presence 去重、重查 living/same-location/no-fight，并只调用现有 lethal initiation；
- 未实现 policy 不静默成功；
- 离开 combat location 后 opponent projection 清理；
- map-local corpse/view 在重载前仍一致。

## 20. 推荐后续切片（最多 3 个）

### Phase 7B1 — World/NPC/Spawn typed foundation

- 上述 immutable definitions、world location state、NPC runtime state/factory；
- Oldpine outdoor/clearing/south-path 与 bandit 的最小 authored data；
- map-local character collection；
- 全部 headless deterministic tests；
- 无大场景、无 Node world controller。

### Phase 7B2 — 首个 Old Pine outdoor playable map

- placeholder OutdoorMap 子集：central clearing、north/east/south 的若干连续地形；
- player world body、collision、zone tracking；
- `spath1` bandit authored spawn、Inspect/Select/Attack；
- map-local combat cadence/lifecycle/corpse adapter；
- corpse 留在物理死亡位置；
- 为避免一次引入群体主动战斗，首轮可由玩家主动 Attack。

### Phase 7B3 — 一个 portal + authored aggression

- `climb pine → TreeCanopyZone`，证明 interaction portal；
- bandit `aggressive_on_player_presence` 的窄 Area2D adapter；
- world/corpse presentation 小幅收口；
- 不附带 vine、keep、respawn、AI/navigation 或完整 Oldpine。

## 21. 正式结论

Oldpine 证明当前最小正确分解是：

```text
immutable Region/Map/Zone/Portal/Npc/Spawn definitions
            ↓
map-local runtime state + scene adapters
            ↓
existing Character/Inventory/Combat/Death authorities
            ↓
CharacterBody2D / HUD / CorpseView presentation
```

不需要 LPC ROOM emulator、通用 graph interpreter、WorldManager singleton、EntityManager、behavior tree、NavigationAgent2D、最终 persistence 或一房一场景。Phase 7B1 可以安全开始。

## 22. 实际检查文件清单

Oldpine rooms（41）：

```text
d/oldpine/cave1.c                 d/oldpine/cave2.c
d/oldpine/cave3.c                 d/oldpine/cave4.c
d/oldpine/cave5.c                 d/oldpine/clearing.c
d/oldpine/cliff1.c                d/oldpine/cliff2.c
d/oldpine/cliffdown.c             d/oldpine/cliffside.c
d/oldpine/epath1.c                d/oldpine/epath2.c
d/oldpine/epath3.c                d/oldpine/keep1.c
d/oldpine/keep2.c                 d/oldpine/keep3.c
d/oldpine/lake.c                  d/oldpine/npath1.c
d/oldpine/npath2.c                d/oldpine/npath3.c
d/oldpine/passage.c               d/oldpine/path3.c
d/oldpine/pine1.c                 d/oldpine/pine2.c
d/oldpine/pine3.c                 d/oldpine/pine4.c
d/oldpine/pine5.c                 d/oldpine/pine6.c
d/oldpine/pine7.c                 d/oldpine/riverbank1.c
d/oldpine/riverbank2.c            d/oldpine/secrectpath1.c
d/oldpine/spath1.c                d/oldpine/spath2.c
d/oldpine/spath3.c                d/oldpine/spath4.c
d/oldpine/stone.c                 d/oldpine/tree1.c
d/oldpine/tree2.c                 d/oldpine/tree3.c
d/oldpine/waterfall.c
```

Oldpine NPC directory（14 files；13 NPC + 1 ITEM）：

```text
d/oldpine/npc/bandit.c            d/oldpine/npc/bandit_chief.c
d/oldpine/npc/bandit_commander.c  d/oldpine/npc/bandit_guard.c
d/oldpine/npc/bandit_leader.c     d/oldpine/npc/butterfly.c
d/oldpine/npc/fat_bandit.c        d/oldpine/npc/maniac.c
d/oldpine/npc/serpent.c           d/oldpine/npc/skeleton.c
d/oldpine/npc/spy.c               d/oldpine/npc/tall_bandit.c
d/oldpine/npc/venomsnake.c        d/oldpine/npc/wolf_dog.c
```

Oldpine items（25 files）：

```text
d/oldpine/obj/bamboo_pipe.c        d/oldpine/npc/obj/bamboo_pipe.c
d/oldpine/obj/black_suit.c         d/oldpine/npc/obj/black_suit.c
d/oldpine/obj/blade.c              d/oldpine/npc/obj/blade.c
d/oldpine/obj/book.c               d/oldpine/npc/obj/book.c
d/oldpine/obj/fur_coat.c           d/oldpine/npc/obj/fur_coat.c
d/oldpine/obj/glaive.c             d/oldpine/npc/obj/glaive.c
d/oldpine/obj/leather.c            d/oldpine/npc/obj/leather.c
d/oldpine/obj/long_sword.c         d/oldpine/npc/obj/long_sword.c
d/oldpine/obj/robe.c               d/oldpine/npc/obj/robe.c
d/oldpine/obj/short_sword.c        d/oldpine/npc/obj/short_sword.c
d/oldpine/obj/throwing_knife.c     d/oldpine/npc/obj/throwing_knife.c
d/oldpine/npc/obj/black_cloth.c    d/oldpine/npc/obj/mask.c
d/oldpine/npc/obj/parrybook.c
```

直接依赖与当前 Godot 边界：

```text
std/room.c                         include/room.h
include/globals.h                  cmds/std/go.c
feature/move.c                     std/char.c
std/char/npc.c                     feature/attack.c
feature/skill.c                    adm/daemons/chard.c
adm/daemons/race/human.c           adm/daemons/race/beast.c
adm/daemons/combatd.c              obj/money/silver.c
std/money.c

game/project.godot
game/scenes/combat/combat_vertical_slice.tscn
game/runtime/combat_slice/combat_slice_character_binding.gd
game/runtime/combat_slice/combat_slice_character_body.gd
game/runtime/combat_slice/combat_slice_demo_factory.gd
game/runtime/combat_slice/combat_slice_opportunity_executor.gd
game/runtime/combat_slice/combat_vertical_slice_controller.gd
game/runtime/combat_slice/combat_slice_death_adapter.gd
game/runtime/combat_slice/combat_slice_corpse_view.gd
game/core/combat/relationship/combat_opponent_availability_facts.gd
game/core/combat/relationship/combat_opponent_selection_service.gd
```
