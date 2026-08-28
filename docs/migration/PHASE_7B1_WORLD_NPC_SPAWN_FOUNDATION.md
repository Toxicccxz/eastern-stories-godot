# Phase 7B1：World / NPC / Spawn Typed Foundation

## 范围与边界

本阶段建立首个 Old Pine 可玩地图所需的纯 typed、Node-free 基础，不创建场景或运行时控制器。权威状态仍由既有 `CharacterState`、`InventoryState`、`CombinedStackCollection`、`EquipmentState`、`CombatRelationshipState`、`ActionBusyState` 和 `ArmorState` 持有；World/NPC 层只组合这些已关闭系统。

定义和状态中没有 `Node`、`NodePath`、`Marker2D`、`Area2D`、`Vector2`、`Callable`、Timer 或任意 payload Dictionary。所有定义数组在构造和读取时均作防御复制。

## World 定义

`RegionDefinition → MapDefinition → ZoneDefinition` 是 authored content 边界，不是 LPC ROOM 运行时：

- Region：`oldpine`
- Maps：`oldpine.outdoor`、`oldpine.cave`、`oldpine.keep`
- Outdoor zones：`north_approach`、`central_clearing`、`south_slope`、`east_bridge`、`river_gorge`、`pine_maze`、`cliff_ledge`、`tree_canopy`
- Cave zones：`waterfall_passage`、`secret_passage`、`maze`
- Keep zones：`entrance`、`courtyard`、`hall`

41 个 LPC room path 仅作为 14 个 ZoneDefinition 的合并追踪 metadata；没有 `RoomDefinition × 41`、ROOM emulator 或 room graph interpreter。Phase 7A 的 24 个连续户外地形与 17 个特殊空间划分保持不变。

`WorldLocationState` 明确分开 `region_id`、`map_id`、`zone_id` 和 `combat_location_id`，不解析 ID 分隔符，也不包含物理坐标。后续 World runtime 只把：

```text
actor.combat_location_id == target.combat_location_id
```

投影为 Combat Core 所需的 `same_location` bool；Combat Core 不依赖 World 类型。

## Portal 数据

首个 portal 为：

```text
oldpine.outdoor.central_clearing
  -- climb pine -->
oldpine.outdoor.tree_canopy / tree1_landing
```

来源为 `d/oldpine/clearing.c`。`PortalDefinition` 保存 typed `CLIMB` interaction kind、源/目标 map+zone、目标 spawn-point ID、legacy verb/argument；该 portal 不需要 policy ID。它不执行命令、场景切换或 teleport。

## NPC 三层分离

- `NpcDefinition`：不可变 authored NPC 内容；
- `NpcSpawnDefinition`：地图、zone、spawn-point 顺序和初始数量；
- `NpcRuntimeState`：一个 live NPC 的 CharacterId、独立角色/战斗/忙碌/护甲状态、逻辑位置和实例 loadout IDs。

`NpcDefinition` 用 typed attribute/resource override 对象区分“作者明确提供”与“缺失后由种族初始化提供”，没有通用 dbase 或 skill Dictionary。`NpcSkillLevelDefinition` 和 `NpcLoadoutEntry` 均是明确 typed entry。

审计后，运行态生命状态使用共享的 `CharacterRuntimeLifeStatus`，其含义是已提交的 `ACTIVE / UNCONSCIOUS / DEAD` 生命周期状态；`CharacterState.life_threshold()` 仍只报告资源阈值证据。两者不会自动同步，因此可合法表示“资源已越过昏迷/死亡阈值，但外层生命周期机会尚未提交状态”。既有 `CombatSliceLifeStatus` 保留为同一共享类型的兼容外观，Phase 6 数值与转换规则未改变。

## 土匪 authored 内容

`d/oldpine/npc/bandit.c` 被迁移为：

- definition ID：`oldpine.npc.bandit`
- 姓名：土匪探哨；alias：`bandit`
- race：human；gender：男性；age：19
- `combat_exp = 600`；`score = 60`
- attitude：aggressive
- skills：sword/parry/dodge 各 10
- capability：`aggressive_on_player_presence`（仅数据）
- loadout：短剑 ×1，`WIELD_PRIMARY`；银子 amount 3，`NONE`
- 无 authored str/cor/int/spi/cps/per/con/kar override
- 无 authored gin/kee/sen override

没有从 combat demo 注入全 20 属性，也没有增加 unarmed、force 或 perception。

## Human 初始化与随机边界

`NpcInitializationRandomSource` 与 `CombatRandomSource` 分离。纯 factory 不调用全局 `randi()`、`randf()` 或 `randomize()`。

Human 缺省初始化严格按 `adm/daemons/race/human.c`：

```text
str → cor → int → spi → cps → per → con → kar
每个缺失字段 = next_below(21) + 10
```

只有缺失字段消耗一次 draw。Bandit age 19 已 authored，所以不会先消耗 `random(30)+15`。三个 spawn instance 按 spawn-point definition 顺序共享并连续消费同一个注入随机流；不会复制第一个随机化后的 CharacterState，也不会逐 NPC reseed。

注入随机源返回 `< 0` 或 `>= bound` 时不会 clamp；单实例构造明确返回 `null`，批量构造明确返回空数组。Factory 是一次性顺序 composition 操作，不承诺事务回滚或 retry-safe：若已进入 loadout 注册/转移阶段，失败前由既有服务完成的 mutation 会保留。当前 Old Pine 内容在所有可变操作前已完成 definition、location、RNG 与 loadout-content 验证；后续如需要通用失败恢复，应引入 typed construction result/lifecycle cleanup，而不是假装存在回滚。

资源与身体派生复用已关闭 API：

- age 19：max/current/effective gin = 200；kee = 200；sen = 100；
- body weight：`CharacterDerivedValues.human_weight(str)`；
- max encumbrance：`CharacterDerivedValues.maximum_encumbrance(str)`；
- combat experience 写入 `CharacterProgressionState`；
- authored skills 通过 `CharacterSkillState.set_raw_level()` 写入。

## Loadout 与既有物品系统

两份 byte-identical 短剑源：

- `d/oldpine/obj/short_sword.c`
- `d/oldpine/npc/obj/short_sword.c`

合并为一个 native item/weapon identity：`es2:d/oldpine/obj/short_sword`，同时保留两条 source metadata。其 source facts 为 weight 3000、skill type sword、damage 15、可 `SECONDARY`、非双手。Bandit 的 intent 仍是主手；`SECONDARY` 不是“默认装备副手”。

银子使用既有 combined/currency domain：一个 `ItemInstance` + 一个 amount 3 的 `CombinedStackState`，base weight 37、base value 100；不是三个 coin instances。

Factory 通过 `InventoryState.register_item()`、`InventoryTransferService.transfer()`、`CombinedStackService.register_stack()` 和 `EquipmentState.wield()` 建立 live loadout，没有绕过已关闭 authority。Map composition root 可显式共享一个 map-local InventoryState/CombinedStackCollection；共享不是隐藏 global state，而每个 NPC 的 Character/Equipment/relationship/busy/armor authority 均独立。

## Spawn 与地图本地集合

`d/oldpine/spath1.c` 对应 spawn ID `oldpine.outdoor.spath1.bandits`：

- map：`oldpine.outdoor`
- zone：`oldpine.outdoor.south_slope`
- quantity / legacy quantity：3
- 三个稳定、按定义排序的 spawn-point IDs
- policy：`INITIAL_ONLY`

一次构造会产生三个不同 CharacterId、三个不同短剑 ItemInstance ID，以及三组互不共享的 CharacterState、attributes/resources/recovery/skills/progression/equipment、relationship、busy 和 armor 状态。

`MapCharacterRuntimeState` 是 map-local、Node-free、有确定插入顺序的 NPC runtime collection，支持稳定 CharacterId lookup、重复拒绝、显式 existence/removal 和超过两个角色。Phase 7B1 没有足够的第二个真实用例来永久化 player runtime shape，因此未把 `CombatSliceCharacterBinding` 提升或改名；7B2 将提供 player binding 的实际边界。

审计强化了窄内容完整性检查：map/zone/portal 必须恰好归属一次且所有引用可解析；spawn 必须恰好列于来源 map；NPC/loadout 引用必须解析；Region、Map、Zone、Portal、NPC、Spawn、Item 的 native ID 跨类别无冲突。该检查仍是三个 Old Pine provider 内的显式 typed 验证，不是通用 graph engine。

## LPC 来源

实现期直接复核：

- `reference/es2/mudlib/d/oldpine/npc/bandit.c`
- `reference/es2/mudlib/d/oldpine/spath1.c`
- `reference/es2/mudlib/d/oldpine/clearing.c`
- `reference/es2/mudlib/d/oldpine/tree1.c`
- `reference/es2/mudlib/d/oldpine/obj/short_sword.c`
- `reference/es2/mudlib/d/oldpine/npc/obj/short_sword.c`
- `reference/es2/mudlib/obj/money/silver.c`
- `reference/es2/mudlib/std/money.c`
- `reference/es2/mudlib/adm/daemons/race/human.c`
- `reference/es2/mudlib/adm/daemons/chard.c`

并沿用 Phase 7A 对 `std/room.c` reset/初始 spawn、完整 Old Pine 41 rooms 与 map/zone 聚类的已关闭分析。

## 7B2 可直接消费的结果

- Old Pine Region/Outdoor/Cave/Keep definitions；
- 14 个 stable zone definitions 与 legacy merged-room metadata；
- climb-pine portal data；
- exact bandit definition；
- spath1 quantity-3 spawn definition；
- deterministic NPC runtime factory；
- canonical short-sword/silver loadout content；
- 三个独立 runtime states；
- map-local ordered character collection；
- logical world/combat location state。

7B2 因而可以只处理 Scene、Marker2D、CharacterBody2D、collision、Inspect/Select/Attack 和既有 combat/corpse 接线，不把 authored content 写死在 scene controller。

## 显式暂缓

- Old Pine playable `.tscn`、物理坐标、Marker2D、Area2D、TileMapLayer、world body/HUD；
- portal traversal 与 interaction policy executor；
- aggressive presence 检测与 lethal combat initiation；
- respawn、ROOM reset emulator、return_home、Timer/heartbeat；
- player world binding 的最终形态；
- beast/monster race 初始化及其他 Old Pine NPC；
- NPC AI/navigation/wandering、dialogue、quests、loot、persistence；
- Phase 5B4 和任何 closed Combat/Character/Inventory 规则修改。

## 正式审计结论

Phase 7B1 正式关闭 Node-free World / NPC / Spawn typed foundation。此结论不表示 Old Pine scene、player world binding、portal execution、aggression、respawn 或完整 Old Pine 内容已经实现。
