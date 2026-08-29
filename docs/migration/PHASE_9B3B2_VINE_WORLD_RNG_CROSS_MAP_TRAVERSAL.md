# Phase 9B3B2：藤蔓策略、世界交互随机数与玩家可见跨地图往返

## 范围与前置边界

Phase 9B3B1 的 `OldPineWorldSessionController`、常驻 Outdoor/Cave 地图、单一活动地图槽、跨图 handoff 与最小 Passage 场景保持为已关闭基础。本阶段只接通 `d/oldpine/epath2.c` 的藤蔓交互、Waterfall 落点、Passage 南出口，以及该路径所需的独立世界交互随机源；没有加入 Riverbank、悬崖、湖、蛇、秘密通道北行、洞穴迷宫/NPC、存档、全局 WorldManager、Phase 5B4、TileMap 或通用事件脚本框架。

## 权威 LPC 行为

直接依据：

- `reference/es2/mudlib/d/oldpine/epath2.c`
- `reference/es2/mudlib/d/oldpine/passage.c`
- `reference/es2/mudlib/d/oldpine/waterfall.c`
- `reference/es2/mudlib/feature/move.c`
- `reference/es2/mudlib/cmds/std/go.c`
- `reference/es2/mudlib/doc/efuns/random`

`do_hold_vine()` 只接受非空且严格等于 `"vine"` 的目标。确认的执行顺序是：

1. 校验目标；
2. 向源房间/玩家输出攀栏抓藤蔓文本；
3. 读取玩家当前 `query_skill("dodge")`；
4. 执行一次 `random(effective_dodge)`；
5. 严格比较抽签值 `< 5`；
6. 输出所选分支的玩家/源房间文本，并向目的房间 `tell_room()`；
7. `move()` 到 `waterfall` 或 `passage`；
8. 没有来源可证的移动后文本或额外效果。

源码没有在这条路径上读取 fighting/busy，也没有伤害、创伤、昏迷、死亡、条件、资源消耗或物品丢失调用。因此百丈坠落在本阶段被忠实解释为“展示 + 移动”，不凭描述文字发明跌落伤害。`feature/move.c` 说明这是对象移动边界；普通方向命令 `cmds/std/go.c` 的敌对关系清理由现有 Godot 位置可用性协调规则承接，而不是塞进藤蔓策略。

## 原生数据与策略

`OldPineVineInteractionDefinition` 是不可变 authored data，保留稳定交互 ID、严格目标别名 `vine`、`d/oldpine/epath2.c` 路径、Inspect/动作/两分支展示文本及两个 Portal ID。藤蔓以 `WorldInteractionTarget.Kind.LANDMARK` 参与既有选择/Inspect 边界；没有命令解析器，也没有把 authored 文本硬编码进 controller 或 HUD。

执行时重新验证玩家仍处于：

- region：`oldpine`
- map：Outdoor
- zone：East Bridge
- combat location：East Bridge

当前有效轻功值只通过现有权威状态计算：

```gdscript
player.state.skills.effective_level(
    &"dodge",
    player.armor.aggregate_numeric_modifiers().dodge,
)
```

因此选择藤蔓后再穿/脱皮衣或改变 skill，下一次执行会读取最新值。默认玩家有效 dodge 恰为 5；合法抽签只能是 0..4，所以默认状态必定落入 Waterfall。只有正上界大于 5 且抽签值至少 5 时才可进入 Passage；测试用有效 dodge 6、抽签 5 证明成功分支，没有改动默认数值。

纯 `VineTraversalPolicy` 只进行随机边界与分支决策，不依赖 Node/HUD/地图，不移动角色也不修改状态。`VineTraversalPolicyResult` 明确记录有效 dodge、上界、是否抽签、抽签值、严格 `< 5` 的分支、Portal ID、到达阶段、非正上界歧义和非法注入值证据。

## WorldInteraction RNG

`WorldInteractionRandomSource.next_below(exclusive_upper_bound)` 是独立于 Combat RNG 和 NPC 初始化 RNG 的窄接口。`OldPineWorldSessionController` 在一个 session 内拥有一个 `GodotWorldInteractionRandomSource`，同时注入两个常驻地图；测试可换成 scripted/observing 实现。它不是 Autoload、全局随机源或通用随机服务。

正上界的契约是仅抽取一次且必须满足 `0 <= draw < bound`。Inspect、来源校验失败、actor 非 ACTIVE 均为零抽签。`bound <= 0` 在源码随机调用位置返回已记录的 typed ambiguity：保留此前源文本、零抽签、无分支、无移动，不 clamp，也不猜测 MudOS 未记载行为。测试随机源若返回区间外值，则返回 typed invalid-draw；不重抽、不输出分支、不移动。

同一 session 的 Passage 往返不替换或重置 World RNG；测试在成功抽签 5 后返回 Outdoor，再消费同一 scripted source 的下一个值 4。session reset 会创建新 RNG、新常驻地图与新 authored NPC/物品状态。藤蔓有效尝试的调用计数证据为 World +1、Combat +0、NPC +0。

## Portal、地图和可见交互

新增三个窄 `PortalDefinition`：

- East Bridge Vine → 同一 Outdoor 的 `oldpine.outdoor.waterfall_basin` / `oldpine.outdoor.waterfall_basin.landing`；
- East Bridge Vine → Cave `oldpine.cave.waterfall_passage` / `oldpine.cave.waterfall_passage.vine_landing`；
- Cave Passage 南出口 → Outdoor Waterfall Basin 的同一 landing。

Waterfall 失败分支调用已有 same-map portal adapter，因此保持同一 Outdoor Node，只提交位置/身体落点并清除过期选择。新增 Waterfall Basin 只包含可辨识的瀑布水潭、逻辑 Area、命名 landing 与南侧物理边界；`waterfall.c` 的南行 Riverbank2 刻意阻断，未迁移河岸。

Passage 成功分支只调用已关闭 B1 的 `handoff_to()`，到达常驻 Cave 的 VineLanding。Cave 的物理 `SouthExit` Area 每次 overlap/transition 只产生一次 typed portal 请求；session 延迟到物理 flush 后执行 B1 handoff，再回到同一 Outdoor Waterfall landing。VineLanding 与 SouthExit 不重叠，避免到达后立即弹回；北侧秘密通道继续由边界阻断。

场景增量为 Outdoor 13 个 Node、Cave 6 个 Node；预期完整节点数分别为 193 和 25。关键场景连接各一条：Vine `selection_requested`、Waterfall Basin `body_entered`、Cave SouthExit `body_entered`。这些节点由 Godot AI/MCP 创建、保存并在最终验证中重新加载检查，而不是用文本批量伪造整个场景。

## 外层编排、关系与部分完成

`OldPineVineTraversalAdapter` 是唯一有序编排层：先验证，写源文本，读取当前 dodge，调用纯策略，写分支文本，再选择 same-map adapter 或 session handoff。`OldPineVineTraversalResult` 保留 source/policy/branch/movement 到达阶段、两种底层移动结果及 `location_committed`，不会谎称整个交互原子。

如果 Waterfall marker 缺失或 handoff 失败，已消费的随机值和已输出的源/分支展示不会回滚；未提交的位置不做任意 fallback。多观察者 `message_vision`/`tell_room` 尚无完整表现层，当前只保存 authored 玩家文本及 typed 阶段证据，这是展示层部分对齐，不是规则缺失。

藤蔓在 fighting 或 busy 时仍可执行，因为 LPC 没有对应 gate。它不递减/重置 busy，也不直接改 combat relationship。Waterfall 同图后，普通对手在下一次可用性机会按既有位置规则移除；lethal marker 保留。Passage handoff 在位置提交后的既有 reconciliation 中移除不可用普通对手、保留 lethal marker；不会发动攻击、推进 busy 或消费 Combat RNG。

## Session 身份与状态证明

真实 Vine → Passage → Cave SouthExit → Waterfall 往返保持同一：

- `WorldPlayerRuntimeState`、`CharacterState`、Equipment/Armor；
- relationship、busy；
- `InventoryState`、`CombinedStackCollection`、`WorldItemInstanceIndex`；
- 装备中的确切 `ItemInstanceId`；
- Combat/NPC/World 三个 RNG 对象及各自流；
- Outdoor/Cave 常驻 Node、唯一活动地图子节点、唯一可控 body/Camera；
- 被修改的活 NPC vitality；
- 已生成的 `CorpseState`、corpse view Node 与尸体中未取走物品的直接 containment。

非活动地图仍遵守 B1 决策：脱离 SceneTree、冻结但不释放。session reset 后旧地图释放，新 session 没有旧尸体/loot，并重新得到五个 authored Outdoor NPC。

## 来源部分对齐账本与延期

已对齐：严格 `vine` 目标、源文本在随机前、实时有效 dodge、一次正上界随机、严格 `< 5`、两个目的地、分支文本在移动前、无来源可证的坠落伤害、Waterfall 同图移动、Passage/南出口跨图往返、busy/fighting 与关系边界。

刻意延期：

- `message_vision`/`tell_room` 的多观察者呈现、动画、音效和最终美术；
- Waterfall 南侧 Riverbank1/2、河流、悬崖、湖、蛇和后续世界内容；
- Passage 北侧秘密通道、洞穴迷宫/NPC/学习内容；
- save persistence、全局世界管理、离屏 heartbeat；
- Phase 5B4 或任何新战斗规则；
- 对非正 `random()` 上界的具体 MudOS driver 行为（继续按 `DECISIONS.md` 的 typed ambiguity 处理）。

## 正式审计结论

正式审计发现并修正了三处窄生产一致性问题：

- `OldPineWorldDefinitions.validate()` 原先未拒绝同一 LPC room metadata 被多个原生 Zone 重复声明；现在所有非空 legacy room ID 必须全局唯一，`waterfall.c` 只属于 Waterfall Basin；
- Cave `VineLanding` 原先在 Portal 与 controller 中重复硬编码；现在由一个稳定 authored 常量引用；
- Vine/Passage handoff 原先以 `zone_id` 兼作 `combat_location_id`；当前数据二者相同，行为未错，但已改为从对应 `ZoneDefinition.combat_location_id` 投影，避免隐藏的身份等同假设。

审计同时把完整 runner 中仍停留在 9B3B2 之前的 WorldDefinition 数量期望更新为 17 zones / 5 portals，并把该测试注册到 9B3B2 聚焦 runner。专项回归还新增了实际 HUD 文本顺序、三个 Portal 的唯一源地图成员关系、Waterfall legacy-room 唯一性、Vine post-commit partial、SouthExit pre-commit 失败恢复/再次激活、真实 `CharacterBody2D` 向南移动触发、玩家 weapon/silver/WORN leather 身份、尸体剩余 loot、旧地图释放与 fresh-session 边界证明。

验证结果：

- Phase 9B3B2 聚焦及所列关闭回归：`4574/4574` assertions PASS；
- 完整项目：`8499/8499` assertions PASS；
- Godot 4.7.2 headless editor、main Session、显式 Outdoor、显式 Cave：退出码均为 0；
- Godot AI 保存并强制从磁盘重载后：Outdoor `193` nodes、Cave `25` nodes；Vine selection、Waterfall body-entered、SouthExit body-entered 各恰好一条正确连接；
- `git diff --check`、尾随空白、权威 `reference/es2` 与关闭的 Character/Skill/Inventory/Equipment/Armor/Combined/Combat/Corpse Core 修改检查通过；
- `DECISIONS.md` 无修改，因为没有新增行为替代决策。

因此 **Phase 9B3B2 正式关闭**，并且**第一条玩家可见、由原作内容驱动的老松岭跨地图往返正式关闭**。Waterfall 仍是等待 Phase 9B3B3 接通 River/Cliff 后续的阶段性端点；本结论不代表 River、Cave、Cliff、世界遍历、最终表现层或 Phase 5B4 已完成。
