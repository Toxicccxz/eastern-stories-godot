# Phase 7B2：Old Pine Outdoor Playable Map

## 范围与结果

本阶段建立第一个 authored-world 可玩闭环：项目启动进入 Old Pine 户外原型，玩家在中央林地连续移动，经 `Area2D` 更新逻辑 zone，在南坡选择并检查三名土匪探哨，显式 Attack 后复用已关闭的 Combat / lifecycle / death / corpse 系统。NPC 死亡只移除该 NPC 的 active-world embodiment；地图、玩家、其余 NPC 与尸体继续存在。

本阶段没有实现门户、主动攻击、重生、AI、导航、完整 Old Pine、Phase 5B4 或 authored action tables。视觉全部使用 Godot 内置节点和占位色块。

## 权威来源与既有边界

直接使用 Phase 7B1 已迁移且可追踪的 authored content：

- `reference/es2/mudlib/d/oldpine/clearing.c`：中央林地与古松来源；
- `reference/es2/mudlib/d/oldpine/spath1.c`：南坡三名土匪 spawn；
- `reference/es2/mudlib/d/oldpine/npc/bandit.c`：土匪探哨身份、年龄、性别、技能、装备、银子和 inspect long；
- `reference/es2/mudlib/d/oldpine/obj/short_sword.c`；
- `reference/es2/mudlib/d/oldpine/npc/obj/short_sword.c`：两份等价短剑 authored source；
- `reference/es2/mudlib/obj/money/silver.c`、`reference/es2/mudlib/std/money.c`：银子 combined/currency facts；
- `reference/es2/mudlib/adm/daemons/race/human.c`、`reference/es2/mudlib/adm/daemons/chard.c`：Phase 7B1 已关闭的人类初始化与派生值。

Combat、lifecycle 与 death/corpse 公式没有重开或复制；运行时直接复用 Phase 6B1/B2/B3 和 Phase 4B5C 的 typed authorities/services。

## 持久化 SceneTree

`res://scenes/world/oldpine/oldpine_outdoor.tscn` 保存的主要结构为：

```text
OldPineOutdoor (Node2D; map-local composition root)
├── Terrain
│   ├── NorthApproach / CentralClearing / SouthSlope / EastBridge
│   ├── path and bridge placeholder ColorRects
│   ├── ancient-pine landmark and zone labels
│   └── Boundaries
│       ├── four world-edge StaticBody2D collisions
│       └── forest-obstacle StaticBody2D collisions
├── Zones
│   ├── NorthApproachZone (Area2D + CollisionShape2D)
│   ├── CentralClearingZone (Area2D + CollisionShape2D)
│   ├── SouthSlopeZone (Area2D + CollisionShape2D)
│   └── EastBridgeZone (Area2D + CollisionShape2D)
├── SpawnPoints
│   ├── PlayerStart
│   ├── Spath1Bandit01
│   ├── Spath1Bandit02
│   └── Spath1Bandit03
├── Characters
│   ├── Player (CharacterBody2D + Camera2D)
│   ├── Bandit01
│   ├── Bandit02
│   └── Bandit03
├── CorpseLayer
├── OpportunityTimer
└── HUD (CanvasLayer + vitality/selection/Inspect/Attack/log/Reset)
```

Terrain、四个 zone、全部 collision、四个 Marker2D、四个 CharacterBody2D、Timer、HUD 与信号连接均在 `.tscn` 持久化，不由 controller 动态建造。四个矩形 zone 只在边界相接、不相互覆盖；普通可行走位置因此只有一个 authoritative `combat_location_id`，不会依赖 Area 信号顺序决定归属。

场景是 prototype-sized 连续空间：中央林地连接北向林道、南坡和东桥视觉子区；古松仅为不可交互 landmark。松林迷宫、峡谷、洞穴、山寨与悬崖网络没有迁入。

## Player runtime 与 CharacterBody 边界

第二个真实运行用例采用窄的 world-specific `WorldPlayerRuntimeState`，而未重命名或复制整个 `CombatSliceCharacterBinding`。它是 Node-free authority composition，持有：

- CharacterId；
- `CharacterState`；
- `CombatRelationshipState`；
- `ActionBusyState`；
- `ArmorState`；
- committed `CharacterRuntimeLifeStatus`；
- `WorldLocationState`；
- world existence 与 combat availability。

`WorldCombatBindingAdapter` 只在一个 combat opportunity 周期把 player/NPC authority 投影为现有 `CombatSliceCharacterBinding`，并把 lifecycle 提交后的 status/existence 同步回 world runtime。它不是全局 entity、service locator 或通用 Entity abstraction。

`WorldCharacterBody2D` 只拥有物理位置、velocity、collision、Godot input、点击选择以及对 runtime state 的窄引用。它不复制 HP/kee、属性、技能、装备、关系或生命状态。玩家输入仍为 normalized `Input.get_vector()` → 固定 prototype speed → `move_and_slide()`；速度尚不依赖角色属性。

## Zone 与 same-location

玩家初始逻辑位置为：

```text
region_id          = oldpine
map_id             = oldpine.outdoor
zone_id            = oldpine.outdoor.central_clearing
combat_location_id = oldpine.outdoor.central_clearing
```

物理位置只来自 `PlayerStart.global_position`。CharacterBody 进入持久化 `Area2D` 时，scene adapter 用 `OldPineWorldDefinitions` 构造新的 typed `WorldLocationState`；不修改 `CharacterState`，也不在 combat call 中用坐标范围反推 zone。

每次建立 combat participants 时，adapter 只投影 `WorldLocationState.combat_location_id` 给既有 Combat availability。same-location 因而是 stable logical ID 相等，而不是距离、Vector2 equality 或只比较 map。

## Marker2D 与三名 authored bandit

`oldpine.outdoor.spath1.bandits` 保持 quantity 3 和 definition-order spawn。runtime 对定义中的每个 point ID 做无 fallback 的精确 Marker 查找：

| 定义顺序 | Spawn-point ID | 持久化 Marker2D | Body |
| --- | --- | --- | --- |
| 1 | `oldpine.outdoor.south_slope.spath1.bandit.1` | `Spath1Bandit01` | `Bandit01` |
| 2 | `oldpine.outdoor.south_slope.spath1.bandit.2` | `Spath1Bandit02` | `Bandit02` |
| 3 | `oldpine.outdoor.south_slope.spath1.bandit.3` | `Spath1Bandit03` | `Bandit03` |

三个 `NpcRuntimeState` 由 `NpcCharacterStateFactory` 使用同一 map-local `InventoryState` / `CombinedStackCollection` 构造；Character、relationship、busy、armor 与 loadout instance state 各自独立。每名 NPC 都是 `oldpine.npc.bandit`：名称“土匪探哨”，男性，19 岁，sword/parry/dodge 10，主手短剑，银子 amount 3。inspect 文本从 `NpcDefinition.description` 读取，严格为 `bandit.c` 的 long，不在 HUD/controller 硬编码。

`GodotNpcInitializationRandomSource` 包装 map-local `RandomNumberGenerator`，支持测试 seed 注入。它与独立的 `GodotCombatRandomSource` 是两个对象、两条随机流；Inspect 不消费任一随机源，项目也未使用 global RNG。

## Inspect、Attack 与 cadence

点击任意 living bandit 的实际 collision shape 发出 typed CharacterId selection；HUD 从该 `NpcRuntimeState` 读取名称、描述和 vitality。Inspect 只更新展示，不改关系、资源或 RNG。

Attack 只针对当前选择且仍存在的 NPC，调用已关闭的 `CombatSliceOpportunityExecutor.initiate_lethal_combat()`。controller 不手工修改 relationship；未选择的另外两名 NPC 不建立 lethal/opponent 关系。`aggressive_on_player_presence` 仍只是 authored capability data，本阶段没有任何读取/执行路径，因此移动接近或等待多个 tick 都不会自动开战。

地图只有一个 1.0 秒 `OpportunityTimer`。每次 timeout 重新从 map-local authority 形成稳定 participants：player 在前，其后为仍存在的 NPC spawn insertion order；仅 fighting actor 执行，idle actor 在进入 opportunity/RNG 路径前即被跳过，每名 actor 每 tick 至多一次 opportunity。重复 Attack 不重复关系，也不重启已经运行的 Timer。没有 per-NPC timer、heartbeat emulator、全局 CombatManager 或 attack-speed 公式。

## Lifecycle、World DeathContext 与尸体

资源跨越阈值时，`NpcRuntimeState.life_status` 仍保持 `ACTIVE`，直到该 NPC 自己的下一次 outer opportunity 交给现有 `CombatSliceLifecycleAdapter` 提交 `UNCONSCIOUS` / `DEAD`。world controller 不从 `CharacterState.life_threshold()` 直接推导 body living 状态。

World death context 从 live world facts 构造，不沿用 arena 常量。Bandit context 使用：

- display name：土匪探哨；
- age：19；gender：男性；
- 死亡机会当下从 `CharacterState.attributes.strength` 重新计算的 body weight / maximum encumbrance；
- 当前 `CharacterState`、Equipment/Armor owner；
- 当前 `WorldLocationState.combat_location_id` 对应的 WORLD containment endpoint。

Core containment identity 不包含 Vector2。死亡执行前另行捕获 NPC body 的 `global_position`；`CorpseState` 与真实 contents 由 `InventoryState` / `DeathInventoryService` 持有，`CombatSliceCorpseView` 只在该捕获位置做物理呈现。

确定性端到端测试证明：被选 bandit 先越过昏迷阈值但 status 尚为 ACTIVE；在自己的机会提交昏迷；后续 QUICK 可致死；短剑经既有 transfer 自动 unwield 并进入尸体，amount 3 的银子也进入同一 corpse direct inventory。该 NPC body 隐藏、不可选、collision 关闭，尸体留在死亡 Vector2；另外两名 NPC 仍存在且可选，玩家仍可移动，场景不会因 NPC death reload 或终止。

正式审计补齐了 Phase 6B3 的失败边界：只有 `UNCONSCIOUS_COMPLETE` / `DEATH_COMPLETE` 才把 projected status/existence 同步回 world runtime。若 death inventory、第二次尸体移动或最终关系清理未完成，world status/existence 与 body 不会被错误提交为死亡；scene-level lifecycle gate 会停止 Timer、立即终止当前 actor 循环，并禁止从头重跑已经产生部分 mutation 的死亡流程。已生成的 partial corpse 仍作为真实部分状态保留，而不是伪装成原子失败。

离开南坡进入其他 zone 时，world adapter 只更新 `WorldLocationState`。下一次已关闭的 opponent availability 以 `same_location=false` 清除双方普通 opponent membership，但保留双方 lethal marker；返回南坡不会自动恢复 combat。7B2 未增加任何 world-side 关系清理或 aggression policy。

玩家死亡沿用 prototype terminal/reset 限制；未实现 ghost、death room 或 revive。Reset 使用 `reload_current_scene()`，创建新的 scene-local player/NPC/item authorities、RNG、relations 和空 corpse collection，并恢复初始 Marker 位置。CharacterId 与 authored spawn-point ID 保持稳定；ItemInstance ID 额外包含本次 scene instance scope，因此 reload 后也是新的 ID，不会跨 scene 保留 ItemInstance、关系、信号或 mutable authority。`NpcCharacterStateFactory` 的 scope 参数是可选且默认空，Phase 7B1 的 Node-free 默认 identity 语义不变。

## Godot AI / MCP 与验证

Godot AI/MCP 用于检查项目与旧主场景、创建并配置持久化 scene hierarchy、StaticBody2D/Area2D/Marker2D/CharacterBody2D/HUD/Timer、设置属性与信号、保存、filesystem scan、force reload、重查 SceneTree/信号及主场景。重载后场景仍含 78 个持久化节点和所需连接。项目主场景已改为 `res://scenes/world/oldpine/oldpine_outdoor.tscn`；旧 `combat_vertical_slice.tscn` 保留为回归 fixture。

实际 `Eastern-Stories-Godot (DEBUG)` 窗口已启动并显示 Old Pine 连续地图、玩家与 world HUD，并接受真实窗口输入。MCP game helper 未在 20 秒等待窗口内回连，但此次 run 的 game log 为空且没有新增项目错误；真实窗口和 Godot 4.7.2 headless scene/main/editor 的 0-exit 检查共同作为运行证据。

Phase 7B2 正式审计定向套件覆盖 scene/hierarchy、collision/zones/signals、spawn mapping、三名 authored NPC、独立 RNG、实际 input picking、多目标切换、Inspect 无 mutation、单目标及重复 Attack、idle NPC 零 combat RNG、无 aggression、双向 Area2D zone transition、WorldLocation same-location、离区后的 closed relationship cleanup、stable cadence order、成功与 blocked lifecycle、死亡当下派生值/zone、短剑/银子尸体、物理尸体位置、死亡后第二名 bandit 可开战、无 respawn 以及 fresh scene reset authority。

最终 Phase 7B2 定向回归通过 2868 个断言；完整项目套件通过 6584 个断言。

## 正式审计结论

审计发现并修复：重复 Attack 会重启 cadence；world controller 会在未成功 lifecycle 后同步 projection；部分死亡缺少 Phase 6B3 scene-level retry gate；NPC death context 使用初始化缓存而非死亡当下派生值；可注入 death context 未验证 live Equipment/Armor/destination authority 一致性；新增 weapon profile damage 未拒绝负值；以及本文件早期表格使用了错误的 spawn-point ID 拼写。修复没有改变 Combat 公式、机会顺序、resource/progression mutation 或 default arena 路径。

Phase 7B2 正式关闭首个 authored Old Pine Outdoor 可玩世界切片；此结论不表示 Old Pine、aggression、portal、NPC AI、respawn、最终 UI/美术或 Phase 5B4 已完成。

## 显式延期

- Phase 7B3：古松 portal traversal、presence aggression 与对应 interaction/runtime policy；
- NPC navigation、wander/chase/return-home、`NavigationAgent2D`；
- respawn、ROOM reset、spawn timer；
- 完整 Old Pine 地形、TileMap/final art、其他 NPC/content；
- corpse decay runtime、loot UI、inventory/quest/map UI；
- ghost/death room/revive 与持久化；
- Phase 5B4、authored combat hooks、attack-speed progression；
- 全局 WorldManager/EntityManager、generic callback/Dictionary context。

Phase 7B2 只关闭“首个 authored OutdoorMap + 三名 authored bandit + 显式 world combat + corpse 留场”的最小闭环。
