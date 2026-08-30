# Phase 9B3B3：山涧、悬崖路线与来源一致的松林入口

## 范围与关闭基线

Phase 9B3B2 的藤蔓策略、Waterfall 落点、Passage 往返、独立 WorldInteraction RNG，以及 Phase 9B3B1 的常驻双地图 Session 均保持关闭。本阶段只把默认藤蔓失败落点继续接到 Riverbank2、Riverbank1、Cliff1、Cliffside 与 Pine1；没有改动 Session/Cave 行为、关闭的 Core 公式或既有 Vine RNG，也没有加入 Lake、蛇、Cliff2、Cave 北路、Phase 5B4、NPC/物品内容或通用攀爬框架。

## 权威 LPC 拓扑

直接依据：

- `reference/es2/mudlib/d/oldpine/waterfall.c`
- `reference/es2/mudlib/d/oldpine/riverbank2.c`
- `reference/es2/mudlib/d/oldpine/riverbank1.c`
- `reference/es2/mudlib/d/oldpine/cliff1.c`
- `reference/es2/mudlib/d/oldpine/cliffside.c`
- `reference/es2/mudlib/d/oldpine/pine1.c`

边界核对：

- `reference/es2/mudlib/d/oldpine/lake.c`
- `reference/es2/mudlib/d/oldpine/cliffdown.c`
- `reference/es2/mudlib/d/oldpine/cliff2.c`
- `reference/es2/mudlib/feature/move.c`
- `reference/es2/mudlib/cmds/std/go.c`

可执行拓扑为：

```text
waterfall <-> riverbank2 <-> riverbank1 --climb cliff--> cliff1
                                      cliff1 --climb down--> riverbank1
                                      cliff1 --climb up----> cliffside
                                      cliffside --north----> pine1
riverbank1 --south--> lake（本阶段阻断）
```

`cliffside.c` 中被注释的 south/east 不是可执行出口；`pine1.c` 没有回到 Cliffside 的反向边，因此新增路线严格单向。Phase 9B1 已关闭的 Outdoor ↔ Pine 原生双向捷径继续独立存在，它不是这条来源边的反向实现，`DECISIONS.md` 无需变更。

## 普通行走、Zone 与物理地形

Waterfall ↔ Riverbank2 ↔ Riverbank1 被翻译为一个连续可行走的原生地形，而不是方向按钮或 Portal。只移除了 B2 的 `WaterfallSouthBoundary` 临时阻挡；Waterfall Zone、两个既有目的落点、Vine/Cave handoff 均未改变。Waterfall landing `(1200, 780)` 与 River threshold 保持距离，测试经过正常 process + physics frame 后仍处于 `oldpine.outdoor.waterfall_basin`，必须由玩家主动南行。

Riverbank2 与 Riverbank1 同属：

- zone：`oldpine.outdoor.river_gorge`
- combat location：`oldpine.outdoor.river_gorge`

因此二者之间的物理行走不因旧 LPC 房间边界清除普通战斗关系。Waterfall → River Gorge、River Gorge → Cliff Ledge、Cliff Ledge → Pine Entrance 则分别改变 combat location。Zone Area 连续覆盖代表点，测试证明 Waterfall/River 双向物理进入稳定，没有可走的 zone gap 或二义 overlap。

River Gorge 使用占位地面、河道和收窄路线。正式审计发现原实现只有 `RiverStream` 视觉、没有水体碰撞，测试反而从水体中央直穿，无法支持当时文档中的“阻止横切”结论。审计通过 Godot AI 在 `RiverStream` 的 `(1030, 1100)` 至 `(1370, 2200)` 范围内加入完全对齐的 `RiverWaterBoundary`（`340 × 1100`），东岸仍保持可行走；真实 `CharacterBody2D` 横向输入停在约 `x=1387`，而东岸可一路走到 Riverbank1。南端 Lake 边界可以步行抵达、碰撞阻挡且可以退回，但没有 Lake Zone、Portal、蛇或伪造的 Lake `WorldLocation`。River Gorge 的 legacy metadata 只记录 `riverbank2.c` 与 `riverbank1.c`；未把延期的 `lake.c` 冒充为已迁移内容。

## Authored 攀爬与 Cliff Ledge

新增三个 typed LANDMARK：Riverbank1 的山涧石壁、Cliff1 向下的山壁、Cliff1 向上的山壁。稳定 ID、展示/Inspect 文本、动作标签、目标别名与 legacy path 位于 `OldPineLandmarkDefinitions`，没有硬编码进 HUD 或建立命令解析器。

`riverbank1.c` 与 `cliff1.c` 的相关函数顺序都是目标校验、展示、`move()`、返回。源码没有 skill check、RNG、busy gate、fighting gate、资源消耗或伤害，因此原生交互也不添加这些规则；busy/fighting 状态保持不变，攀爬本身不会发动攻击或消费 RNG。

四个窄 same-map Portal 为：

- Riverbank1 Cliff → Cliff1 landing；
- Cliff1 Down → Riverbank1 landing；
- Cliff1 Up → Cliffside landing；
- Cliffside north spatial edge → Pine1/Pine Entrance landing。

前三个由既有选择 + `OldPinePortalTraversalAdapter` 执行；controller 在执行时额外核对玩家仍处于对应物理 landmark，避免 stale selection。Cliff1 与 Cliffside 共享 `oldpine.outdoor.cliff_ledge` zone/combat location。Cliffside 北缘使用玩家身体进入的窄 Area，仍调用既有 same-map adapter；没有按钮、通用 one-way 系统、反向 Area 或 Pine → Cliffside Portal。

Pine landing `Pine1CliffsideLanding` 位于 Pine Entrance 内，避开墙、迷宫障碍、Phase 9B1 阈值与 Tall/Fat 身体/Presence。到达回调只提交来源定义的 Portal，不制造 aggression；之后进入既有 Presence 才会按 Phase 7B3 行为开战。

## 权威状态、随机数与部分提交

整条 B3 路线始终使用同一 Outdoor Node 与同一 `WorldPlayerRuntimeState`、`CharacterState`、Inventory/Equipment/Armor、ItemInstance 身份、关系状态、NPC/corpse 状态和三个 RNG 对象。只有 B2 Vine 在路线开头消费一次 World RNG；从 Waterfall 开始的 B3 路线额外消费 World/Combat/NPC RNG 均为 0。攀爬和单向边不直接改 CombatRelationshipState，位置可用性仍由已关闭的外层机会处理；lethal marker 规则不变。

## 自动化物理路线与回归

`oldpine_river_cliff_route_test.gd` 通过实际 `CharacterBody2D.move_and_collide()` 与 physics frame 走完整路线，不在各游戏阶段直接改位置。覆盖：

- fresh Session → Vine 默认 Waterfall → Riverbank2/1 → Cliff1 → Cliffside → 单向 Pine Entrance → Pine Deep；
- Waterfall 到达帧稳定、Waterfall/River/Cliff/Pine typed location；
- Riverbank1/2 与 Cliff1/Cliffside 的 combat-location 连续性；
- Cliff1 Down → Riverbank1 → 物理北返 Waterfall；
- Pine 侧同一边界不能返回 Cliffside，而 Phase 9B1 捷径仍双向；
- 水体横切、Lake 泄漏、zone gap/overlap、落点碰撞与递归触发均不存在；
- fighting/busy 攀爬可用且不改变 busy；
- Riverbank Cliff 以及共享 Cliff Ledge zone 的 Cliff1 Up/Down 都在执行时重新核对当前物理 Area，拒绝同 zone 内的 stale selection；
- Pine 精确落点不接触 Tall/Fat Presence、不改变生命或关系；之后实际走入 Presence 才触发既有 aggression；
- inactive actor、whole-Session 边界、身份/资源/NPC/corpse/RNG 不变；
- WorldDefinition 唯一性、legacy room 全局唯一、无 playable Lake/Cliff2。

Phase 9B3B3 聚焦 runner 包含 B3、B2/B1、9B2/9B1、8B2/B1、7B3、WorldDefinition 与 relationship regressions，正式审计结果为 `2419/2419` assertions PASS。完整历史套件的首次正式运行只暴露一个测试账本遗漏：9B3B3 新增四个 Portal ID 后，`npc_spawn_foundation_test.gd` 仍断言跨类别 ID 总数为 34；修正为来源结构实际的 38 后，9B3B2 聚焦回归为 `4584/4584`，获准的唯一一次干净完整复跑为 `8719/8719` assertions PASS。

## Godot AI 场景与实时验收

Godot AI/MCP 从 B2 的 Outdoor 193 nodes 基线开始创建地形、碰撞、Zone、landmark、landing、单向 Area、Camera 边界与信号。正式审计补入缺失的水体 `StaticBody2D + CollisionShape2D` 后，再次保存并强制从磁盘重载得到：

- Session：2 nodes；
- Outdoor：226 nodes；
- Cave：25 nodes，未修改。

River Zone、Riverbank Cliff、Cliff1 Down、Cliff1 Up、Cliffside Pine Exit 的新增 gameplay signal 均恰好连接一次，且没有误连 Vine callback。

正式审计重新启动真实主项目；debugger 6107 的本机环境、Godot 4.7.2 与 Godot AI 3.2.4 返回 `helper_live=true`、`session_active=true`、`game_capture_ready=true`、`current_run_errors=[]`。运行树始终为：

```text
OldPineWorldSession
└── ActiveMapSlot
    └── OldPineOutdoor
```

通过真实键盘/逐帧 gameplay input 与 framebuffer mouse click 完成：East Bridge → Vine → Hold vine → Waterfall → 东岸 River Gorge → 点击 Riverbank Cliff → Climb cliff → 点击 Climb up → Cliffside 北缘 → Pine Entrance。没有用 controller 方法、直接 callback、直接 `body_entered` 或位置赋值推进路线。只读 live checkpoint 为：

- Waterfall：`oldpine.outdoor / waterfall_basin / waterfall_basin`，body `(1200, 780)`；
- River：`oldpine.outdoor / river_gorge / river_gorge`，body 约 `(1420, 1337)`；横向尝试穿水后停在约 `x=1387`；
- Cliff：`oldpine.outdoor / cliff_ledge / cliff_ledge`，Cliff1 body `(435, 1900)`；
- Pine：`oldpine.outdoor / pine_entrance / pine_entrance`，精确安全 body `(−80, 550)`。

Waterfall 与最终 Pine 截图分别为 `frames_drawn=8564` 和 `40814`，两者 `stale_frame=false`，证明帧持续增长。第一次到 Pine 的输入持续过长，角色在落点后继续走入 Fat Presence 并按既有节奏受伤；随后用真实 Reset 按钮重置，验证 fresh player、五个 NPC、零 corpse、空选择与 Central Clearing，再完整重跑。第二次在精确 landing 停下时玩家仍为 ACTIVE、`220/220`、零 opponent，且 Tall/Fat Presence 均不 overlap；继续八帧物理步行后仍保持安全。自动化路线另行证明继续到 Pine Deep，并证明只有实际进入既有 Presence 才产生 aggression。

正式审计的 game log 只有 game helper 注册信息，没有运行时错误；编辑器仍显示 12 条来自已关闭 Character Skill、Armor、Inventory 与既有 Outdoor 代码的静态 warning，它们不是本阶段新增错误，也不在本次范围内。验收后项目干净 stop。

6107 的 `run/main_run_args` 是本机避开 Windows 保留端口的调试配置。本阶段没有改写 `game/project.godot`；除非团队明确统一该开发配置，否则不应把机器相关端口当作 gameplay 变更提交。

## 来源部分对齐账本与延期

- `waterfall.c`：zone/landing、south → Riverbank2 完成；
- `riverbank2.c`：物理 north/south 完成；
- `riverbank1.c`：north 到 Riverbank2 完成，climb cliff 完成，south → Lake 延期并物理阻断；
- `cliff1.c`：物理表现、climb down、climb up 完成；
- `cliffside.c`：物理表现、north → Pine1 完成；注释出口保持不存在；
- `pine1.c`：接收来源一致的单向入口完成；Pine1 → Cliffside 不存在；
- Lake、serpent、cliffdown、Cliff2、Cliff2 → epath3、Cave 北路/迷宫、Phase 5B4：全部延期。

因此 Phase 9B3B3 已通过正式实现审计并 **FORMALLY CLOSED**。Phase 9B3 的 Vine / cross-map / Waterfall / River / Cliff / Pine traversal milestone 同时正式关闭；下一步应停止内容扩张，单独规划项目级 Productionization / Stabilization milestone。
