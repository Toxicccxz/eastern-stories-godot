# Phase 8A：玩家物品栏、战利品与装备交互依赖分析

状态：**ANALYSIS COMPLETE — READY FOR PHASE 8B1**

本阶段只分析从当前 Old Pine 世界、战斗、死亡和尸体实现通往首个 RPG loot loop 的最短路径。没有修改生产 GDScript、场景、UI 或 `reference/es2/`，也没有重开 Combat、Inventory、Equipment、Combined Stack 或 Corpse Core。

## 1. 已正式关闭的前置条件

- Phase 4A1：`EquipmentState` 的主/副武器语义。
- Phase 4B1：`ItemDefinitionId` / `ItemInstanceId` 分离。
- Phase 4B2：单父 containment、重量、容量与有序 transfer。
- Phase 4B3：combined amount、split、character destination merge 与 currency。
- Phase 4B4：开放 armor slot、wear/remove 与 transfer detach。
- Phase 4B5B：物品销毁和 stack association 清理。
- Phase 4B5C：死亡物品、尸体、corpse-worn compatibility gate。
- Phase 6B：可玩战斗、外层 lifecycle、死亡与尸体接线。
- Phase 7B：首个 Old Pine authored world、三名土匪、古松 portal 与狭窄 aggression。

这些阶段继续保持正式关闭。Phase 8 不复制其公式或权威状态，只增加 world/UI 请求适配。

## 2. 当前玩家物品权威

Old Pine controller 在每次 scene 初始化时创建一组 map-local authority：

```text
InventoryState
CombinedStackCollection
WorldPlayerRuntimeState
NpcRuntimeState × 3
CorpseState collection
```

玩家、三名 NPC、尸体和 WORLD endpoint 全部使用同一个 `InventoryState`。不存在也不应增加 `PlayerInventoryState`、`NpcInventoryState` 或 `CorpseInventoryState`。

同一个 map-local `CombinedStackCollection` 也供所有这些 owner 使用。玩家初始没有 combined item association；三名土匪各有一个 amount-3 silver association，之后 Take 仍使用这一集合。

玩家当前确实拥有真实原型长剑，不只是 combat profile：

1. `_initialize_player()` 建立 scoped `ItemInstanceId`；
2. 建立 definition ID `es2:d/oldpine/obj/long_sword` 的 `ItemInstance`；
3. 以 own weight 7000 注册到 map-local `InventoryState`；
4. transfer 到 `ContainmentEndpoint.CHARACTER(player)`；
5. 同一个 instance ID 位于 `CharacterState.equipment.primary_weapon()`。

Reset 使用 scene reload，因而重新创建 Inventory、stack collection、ItemInstance scope、玩家长剑、NPC loadout、尸体集合和 UI/runtime state。不会保留上一次 scene 的 looted IDs。

当前缺口：`WorldPlayerRuntimeState` 没有像 `NpcRuntimeState` 一样保存 setup-time `maximum_encumbrance`。初始化长剑时暂时使用 `WORLD_CAPACITY = 1_000_000`，这不能作为玩家 Take 的容量。Phase 8B1 应在 player runtime 保存一次来源明确的最大负重快照：

```text
maximum_encumbrance = setup-time strength * 5000
```

不要在每次 Take 时按可能已经变化的 strength 重算；LPC `setup_char()` 是设置一次 `max_encumb`，不是动态 getter。

## 3. 当前尸体与物品栏权威

NPC 死亡后：

- `DeathInventoryService` 注册真实 corpse `ItemInstance`；
- corpse parent 是当前 zone 的 `WORLD` endpoint；
- corpse contents endpoint 是 `ContainmentEndpoint.ITEM(corpse_id)`；
- 短剑和银子仍是原来的 ItemInstance identity；
- 短剑由 transfer 自动 unwield 后成为 corpse direct child；
- 银子仍关联同一个 `CombinedStackState(amount = 3)`；
- `CorpseState` 只保存尸体 metadata、decay stage、capacity 与 corpse-worn projection；
- `CombatSliceCorpseView` 只保存 corpse ID、victim display name 和物理位置，不拥有内容副本。

权威内容查询已经存在：

```text
InventoryState.direct_children(
    ContainmentEndpoint.ITEM(corpse_item_instance_id)
)
```

返回顺序是稳定的 ItemInstanceId 字典序，不声称复现 MudOS object-chain order。stack amount 从 `CombinedStackCollection.stack_state(id).amount` 读取，不在 Inventory 或 UI 再存一份。

## 4. 当前可用领域 API 矩阵

| 能力 | 分类 | 现有权威 / 说明 |
| --- | --- | --- |
| 枚举 corpse direct contents | A READY | `InventoryState.direct_children(ITEM(corpse_id))` |
| 查询 direct parent / root holder | A READY | `direct_parent()` / `root_holder()` |
| corpse → player 普通物品 | B RUNTIME ADAPTER | 必须经 `CorpseContentTransferService.transfer_out()` |
| combined amount 随 ownership transfer | A READY | amount association 不因 reparent 改变 |
| character destination stack merge | A READY | `CombinedStackService.transfer_and_merge()` |
| corpse Take 后 stack merge | B RUNTIME ADAPTER | corpse-aware transfer 后，对已在 player 的 moved stack 调同一 destination 的 `transfer_and_merge()` |
| split combined stack | A READY / D FIRST LOOP OUT | `CombinedStackService.split()`；首 loop 不需要部分数量 Take |
| currently wielded item transfer | A READY | `InventoryTransferService` 先 unwield 再验证 destination |
| currently worn armor transfer | A READY | 同一 service 先 remove Armor，再验证 destination |
| corpse-worn release/lock | A READY | `CorpseContentTransferService`；stage 0 release，stage ≥ 1 locked |
| 防止 stale corpse-worn projection | A READY IF GATED | 外部不得绕过 corpse-aware service |
| player-owned weapon wield | B RUNTIME ADAPTER | ownership/definition/shield 验证后调用 `EquipmentState.wield()` |
| unwield | B RUNTIME ADAPTER | 验证当前玩家 direct ownership 后调用 `EquipmentState.unwield()` |
| 主/副武器转移规则 | A READY | Phase 4A1 `EquipmentState` |
| armor wear/remove | A READY / D FIRST LOOP OUT | `ArmorService` / `ArmorState`，首内容没有 armor loot |
| capacity / subtree weight | A READY | `InventoryTransferService`；等于 cap 允许 |
| 玩家真实 capacity 投影 | C MISSING NARROW FACT | player runtime 缺 setup-time maximum encumbrance |
| 物品销毁 | A READY | `ItemLifecycleService` |
| live ItemInstanceId → definition ID | C MISSING MAP-LOCAL INDEX | Inventory 只存 ID/weight/parent，不存 definition |
| definition ID → UI/content facts | C MISSING NARROW PROVIDER | 当前 `ItemDefinition` 没有 name/description/category |
| 当前武器 → world combat profile | C MISSING NARROW RESOLVER | player content 目前只验证原型长剑 |

## 5. Corpse 与 ITEM interaction identity

将 `WorldInteractionTarget.Kind` 最小扩展为：

```text
CHARACTER
LANDMARK
ITEM
```

corpse 使用 `ITEM + corpse ItemInstanceId`。不增加假 `CORPSE` kind，不使用 Node identity，也不引入通用 `EntityId`。

运行时按当前 authority 分类 ITEM：

- ID 解析为 live `CorpseState`：Inspect + Open Loot；
- live item 的 direct parent 是 WORLD：未来 Inspect + Take；
- direct parent 是 player CHARACTER：由 Inventory panel 提供 Inspect/Wield/Unwield；
- stale/unregistered ID：无动作并刷新选择。

Phase 8B1 不需要通用 callback action catalog。World HUD 继续显式处理 target kind，仅增加 `Open Loot`。Take/Wield 是 panel 内 typed requests，不放入 world target 的 arbitrary action array。第三种 target 尚不足以证明 `InteractionOption` 框架的必要性。

## 6. CorpseView 到领域尸体的解析

推荐执行链：

```text
CombatSliceCorpseView click
→ signal(corpse ItemInstanceId)
→ WorldInteractionTarget.ITEM(id)
→ controller 按 ID 查找当前 CorpseState
→ InventoryState.is_registered(corpse_id)
→ 验证 corpse 当前 WORLD parent / 交互范围
→ live direct-contents projection
```

`CombatSliceCorpseView` 可以增加只负责 picking/range 的 `Area2D`，但不得保存 item list、stack amount 或 transfer result authority。Controller 当前只有 `_corpse_states` 数组；按稳定 ID 查找已经足够，首阶段不需要 CorpseManager。

## 7. Live corpse-content projection

Loot panel 每次打开、每次 Take 完成以及任何 typed failure 后都重新生成：

1. 从 live corpse endpoint 取 `direct_children()`；
2. 由 map-local instance index 把 ID 解析为 immutable `ItemInstance` snapshot；
3. 用窄 content provider 解析 display name、description、category 与 weapon/currency facts；
4. 若 stack collection 含该 ID，读取 current amount；
5. 从 `CorpseState` 读取 corpse-worn/locked presentation fact；
6. 生成不含 authority reference 的 value-like rows。

建议 row 最小字段：

```text
item_instance_id
item_definition_id
display_name
description
category
amount             # non-stack 可为 1
equipment_slot     # NONE/PRIMARY/SECONDARY/WORN
can_take / can_wield / can_unwield
```

UI row index、名称和 definition ID 都不能代替 ItemInstanceId。

## 8. ItemInstance 与 authored content 解析

`InventoryState` 故意不保存 definition ID，因此 Phase 8B1 需要一个 map-instance-local、typed 的 immutable identity index：

```text
WorldItemInstanceIndex
ItemInstanceId → ItemInstance snapshot
```

它不拥有 liveness、parent、weight 或 amount。所有操作仍以 `InventoryState.is_registered()` 作为 live authority；index 中保留被销毁 ID 的旧 snapshot 也不能使其重新可用。

UI/content 需要一个窄 Old Pine provider，而不是 universal `ItemRepository`：

- 玩家原型长剑；
- 土匪短剑；
- 银子；
- corpse presentation 从 `CorpseState` 取得。

推荐 `OldPineItemContentDefinitions` 返回 immutable presentation projection，并复用既有 `NpcLoadoutItemDefinition` / `WeaponDefinition` / stack / currency facts。新增的 authored 文本为：

- 长剑：`长剑` 与 `d/oldpine/obj/long_sword.c` 的 long；
- 短剑：`短剑` 与两份 byte-identical short_sword source 的 long；
- 银子：`银子` 与 `obj/money/silver.c` 的 long。

不要把 name/description 硬编码在 HUD/controller，也不要把它们塞入 mutable ItemInstance。

## 9. Take 的 LPC 与 native 语义

`cmds/std/get.c` 的相关顺序：

1. 缺参数失败；
2. actor busy 时失败；
3. 解析显式 `from` source；
4. 查找 source direct child；
5. 单件路径拒绝 living/no_get；
6. `do_get()` 记录旧 environment/equipped；
7. 调 item `move(me)`；
8. 成功且 actor 正在战斗时 `start_busy(1)`；
9. presentation。

Native 不迁移 parser、`present()` 或消息字符串。Phase 8B1 的一次 Take request 应验证：player exists、committed ACTIVE、not busy、corpse/item live、in range、item 仍是 exact corpse direct child，然后调用现有服务。单件 Take 在 fighting 时并未被 LPC 禁止；成功后应通过现有 `ActionBusyState.start_busy(1)` 保留 source busy 结果。`get all` 才在 fighting 时明确拒绝。

首批短剑与银子都没有 authored `no_get`。Phase 8B1 不需要为了不存在的首批 gate 扩展通用 ItemDefinition；未来 loose/quest item 首次需要时再迁移 typed pickup policy。

## 10. Corpse-aware transfer 是强制路径

所有 corpse direct child 都先经过：

```text
CorpseContentTransferService.transfer_out(
    corpse,
    inventory,
    item_instance_id,
    player_destination,
)
```

不能直接对尸体内容调用 `InventoryTransferService`。否则 stage-0 corpse-worn projection 不会 release，stage ≥ 1 lock 也会被绕过，造成 stale `CorpseState`。

精确 compatibility 行为：

- fresh stage 0 corpse-worn item：先 release projection，再尝试 transfer；后续容量失败不恢复 projection；
- stage ≥ 1 corpse-worn item：`CORPSE_WORN_LOCKED`，containment 不变；
- 普通短剑没有 corpse-worn projection，直接走低层 transfer。

## 11. 短剑 loot path

```text
Bandit primary short sword
→ death transfer 先 unwield
→ same ItemInstance becomes corpse direct child
→ Take via CorpseContentTransferService
→ same ItemInstance becomes player direct child
```

definition ID、instance ID、own weight 3000 均保持。Take 不自动 wield。corpse row 消失，player inventory row 出现。

## 12. 银子 amount 3 与 merge

死亡和普通 reparent 都不会复制或改变 stack amount。没有玩家银子时：

```text
corpse silver instance amount 3
→ corpse-aware transfer
→ player direct child, same instance, amount 3
→ own weight 3 * 37 = 111
→ value 3 * 100 = 300
```

若玩家已经有 compatible silver amount 5：

1. corpse-aware transfer 先把 amount-3 instance 移到 player；
2. runtime adapter 对该 moved instance 和同一 player destination 调用 `CombinedStackService.transfer_and_merge()`；
3. 第二次低层 transfer 合法返回 `ALREADY_AT_DESTINATION`；
4. moved corpse-silver instance 是 survivor；
5. 旧 player-silver instance 被 `ItemLifecycleService` 移除；
6. survivor amount 变为 8、weight 296、value 800。

这与 LPC `combined.c::move()` 的“正在移动对象存活，吸收 living direct siblings”一致。merge 失败发生在 Take 已完成之后时不回滚 ownership；typed result 必须保留 corpse transfer 与 merge 的部分结果。

## 13. Capacity

Take destination 为：

```text
ContainmentEndpoint.CHARACTER(player_id)
available = player exists and ACTIVE
containment capable = true
maximum contents weight = player setup-time max_encumbrance
```

`InventoryTransferService` 权威计算：

```text
current player contents weight + moving item subtree weight > maximum
    → CAPACITY_EXCEEDED
```

等于上限允许。Combined amount 已经反映在 own weight 中；merge 前后 player 总负重不重复计算。UI 只展示 typed failure，不复制公式。

## 14. Take All

首个实现切片只做单件 `Take`，明确延期 `Take All`。理由：两件物品已经能关闭 loot loop；Take All 还需要 source 的 fighting gate、稳定批处理结果与 partial-success UX。

未来实现应：

```text
snapshot corpse direct children in stable ID order
→ sequential Take
→ no rollback
→ ordered per-item results
→ COMPLETE / PARTIAL / FAILED summary
```

不得伪造事务原子性。LPC `get all` 跳过 character/no_get 项，逐项执行且忽略单项失败；战斗中整体拒绝。数量参数的旧 `get` split/reversal 缺陷不属于首 loop。

## 15. 最小 Loot UI

推荐桌面 RPG 流程：

```text
click corpse
→ select ITEM target
→ Inspect / Open Loot enabled
→ press Open Loot
→ panel shows live contents
```

不在单击时自动弹出 panel，避免误触并保持与当前 Inspect/Attack/Traverse 的显式 action 风格。

Panel 最小内容：corpse title、纵向 rows、每行 name/amount/Take、Close。Take 后立即从 authority 重建；空尸体显示“空”，但尸体仍可选择、仍留在 scene，直到未来 decay/destruction。首版不需要 Take All、拖放、排序、过滤或 rarity。

## 16. 玩家 Inventory presentation 与最小 UI

玩家物品栏投影来自：

```text
InventoryState.direct_children(CHARACTER(player))
+ WorldItemInstanceIndex
+ CombinedStackCollection
+ CharacterState.equipment
+ ArmorState
+ authored content provider
```

首版只显示 direct player items。Panel 使用 `PanelContainer + ScrollContainer + VBox/HBox + Label + Button`：

- 每行 name；
- stack 显示 amount；
- PRIMARY / SECONDARY / WORN 状态；
- Inspect；
- 可用时 Wield 或 Unwield。

Panel、rows 和 selected ItemInstanceId 都是 presentation state；每次动作重新验证 current authority。

## 17. Item Inspect

- 长/短剑：authored name、long、weapon skill type、damage、当前 hand slot；
- 银子：authored name、long、amount，可选择显示总 value；
- corpse：victim display name 与当前 direct-content count。

普通玩家 UI 不显示 definition ID、instance ID 或 legacy path。UI 不自行计算最终 combat effectiveness。

## 18. Wield / Unwield 的 source/native 行为

`wield.c` 要求 item 是 actor direct inventory，拒绝已有 equipped marker，再调用 item `wield()`。命令没有 busy/fighting gate。Native 需要一个窄 world equipment adapter：

1. 验证 player exists 且 committed ACTIVE；
2. 按 ItemInstanceId 解析 live ItemInstance；
3. 验证它是 player direct child；
4. 解析 exact `WeaponDefinition`，definition ID 必须一致；
5. 从 `ArmorState.is_slot_occupied("shield")` 投影 shield fact；
6. 构造 `EquippedWeaponRef`；
7. 调 `EquipmentState.wield()`；
8. 返回原 typed transition，不直接写 slot。

Unwield 同样按 exact instance ID 验证 direct ownership 和当前 hand reference，再调用 `EquipmentState.unwield()`。卸下主武器不会提升副武器。

## 19. 主/副手、短剑与现有长剑

当前原型长剑：单手、不能作为 secondary、已占 primary。短剑：单手、带 `SECONDARY`。

精确结果：

| 初始 hand state | 请求 | 结果 |
| --- | --- | --- |
| 双空 | Wield 短剑 | 短剑进入 primary |
| 长剑 primary、secondary 空 | Wield 短剑 | 短剑进入 secondary，长剑仍 primary |
| 短剑已 secondary | 再 Wield 短剑 | `ALREADY_WIELDED`，不提升 |
| secondary 已占 | Wield 短剑 | `NO_FREE_HAND` |
| 卸下长剑、短剑仍 secondary | 无后续动作 | primary 空，short 仍 secondary |

因此“拿到短剑后点击 Wield”不会自动替换长剑。要证明下一场 Combat 使用短剑，确定性 UI/test 顺序必须是：

```text
Unwield long sword
Wield short sword while primary is empty
```

如果短剑已经先进入 secondary，则还必须先 Unwield short sword，再按上述顺序 Wield。首版不增加 `Make Primary` 或隐式换槽规则。

## 20. Dynamic combat weapon-profile resolution

当前 world combat 不足以支持玩家运行时换成短剑：

- `_player_content` 是只验证长剑 ID、sword、damage 25 的 `CombatSliceContentProfile`；
- `_bandit_content` 是只验证短剑 ID、sword、damage 15 的另一 profile；
- `_build_participants()` 永远把 `_player_content` 传给 player binding。

若玩家 primary 变为短剑，当前 player profile 会把它视为未验证 primary，projected weapon apply damage 为 0。Combat Core 本身正确读取 CURRENT `EquipmentState.primary_weapon()`；缺的是 world content resolution。

Phase 8B2 应增加一个 narrow resolver：

```text
current primary EquippedWeaponRef
→ exact definition ID
→ Old Pine verified CombatSliceContentProfile / weapon combat facts
```

只注册当前真实的长剑与短剑；未知 weapon 返回 typed unresolved/fallback，不建立 universal ItemCatalog，也不改 Combat 公式。`_build_participants()` 每次机会重新解析 current primary，不能缓存第一次装备。

## 21. Empty / unarmed

若 primary 为 null，现有 `CombatSliceContentProfile` 已提供 human punch action 和 unarmed action set，weapon apply damage 为 0。只要 resolver 对 null 明确选择 unarmed content，卸下全部武器不会继续使用 stale long-sword damage。Secondary 独自存在时仍不成为 primary attack weapon，符合已关闭 Equipment/Combat 语义。

## 22. World loose item future reuse

ITEM identity、instance index、content projection和玩家 destination 可直接复用。唯一区别是 source gate：

- corpse child：`CorpseContentTransferService`；
- WORLD direct child：普通 `InventoryTransferService`；
- 两者成功后若是 combined stack，都进入 character destination merge。

Phase 8B1 不创建 loose item views 或 Drop。Drop 需要 WORLD endpoint、物理生成位置和 ItemView 生命周期，首 loot loop 不依赖它；即使 hand replacement 也只需 Unwield，物品仍留在 player inventory。

## 23. Interaction range 与战斗中 looting

### Interaction range

LPC 的“同一 room”必须转换为 RPG 空间规则。推荐 corpse view 增加独立 `LootInteractionRange Area2D`，只检测 player body；选择可以发生，但 Open/Take 执行时必须重新验证 player 仍在 range。该 bool 由 scene adapter 产生，不进入 Inventory Core。具体碰撞半径是 prototype spatial tuning，应在 Phase 8B1 以 scene/test fixture 固定，并在实现时把这一可观察 RPG 替代记录到 `DECISIONS.md`。

### Combat looting

不新增“战斗中禁止 looting”规则。来源行为是：

- 已 busy：所有 get 立即拒绝；
- 正在 fighting：单件 get 可成功，之后 `start_busy(1)`；
- fighting 时 `get all` 拒绝。

推荐允许 Inspect/Open panel；单件 Take 走上述 busy 规则。Player 非 ACTIVE、已不存在或 stale corpse/item 一律拒绝。

## 24. Runtime result type

首阶段只需要一个 `CorpseLootTransferResult`，不同时创建多个泛化结果。建议保存：

```text
outcome
succeeded
actor_character_id
corpse_item_instance_id
requested_item_instance_id
CorpseContentTransferResult
optional CombinedStackMergeResult
resulting/surviving item_instance_id
busy_started
```

如果 corpse transfer 成功而 merge 失败，outcome 必须表达 partial completion，item 保持 player-owned。Nested typed results 已保存 source/destination、capacity、corpse-worn release、absorbed IDs 和 survivor evidence，因此外层不复制 mutable authority。

Take All 若未来实现，另加 ordered batch result；本阶段不要预建。

## 25. Authority 与 UI 边界

```text
Button
→ typed request(ItemInstanceId / corpse ID)
→ runtime revalidation
→ existing domain service(s)
→ typed result
→ authoritative mutation
→ projection rebuilt
→ UI refresh
```

UI 绝不 reparent item、写 amount、写 equipment slots、清 corpse-worn state或修改 life status。Take 与 Wield 保持两个动作；Take 成功、随后 Wield 失败时，物品仍属于玩家。

## 26. Reset 与 persistence

Reset 继续 scene reload：恢复玩家原型长剑、三名 bandit loadout、fresh stack collection、零尸体和关闭 panels；旧 selected ITEM/row ID 不得跨 scene 保存。

Phase 8 首 loop 不改 save schema。未来 persistence 至少需要 player-owned ItemInstances、parents、combined amounts 和 equipment instance IDs；corpse/world state是否保存另行决定。现有 `NativeItemDomainState` 是 restore output，不适合作为可变 world item manager，不能为方便 lookup 而把它提升成 global runtime authority。

`DECISIONS.md` 本阶段不修改。显式 Open Loot panel 是表现/交互形式替换，底层 Take 语义不变；combined money 聚合本身就是来源行为。近距离 corpse interaction 会改变 LPC 同-room reachability，Phase 8B1 选定实际 Area shape/range 时才应记录一条真实可观察的 RPG spatial decision。

## 27. Godot AI / MCP 结论

磁盘场景检查确认：

- main scene 是 `res://scenes/world/oldpine/oldpine_outdoor.tscn`；
- 当前场景 102 个持久化节点；
- `CorpseLayer` 是无脚本的 Node2D，corpse views 运行时添加；
- corpse view 当前没有 picking/range child；
- HUD 只有 Inspect、Attack、Reset、Portal 四个 action button；
- player 是 collision layer/mask 1 的 `WorldCharacterBody2D`；
- map root、HUD 与 current target wiring 都是 scene-local。

Phase 8B 实现时 Godot AI/MCP 应仅用于：增加 corpse picking/range Area、Loot/Inventory panels、typed signals、layout、保存/force reload、节点/信号复核和真实运行检查。领域规则仍由 headless tests 验证。

## 28. UI assets

首版不需要外部 UI asset。使用 Godot 原生 Control、PanelContainer、ScrollContainer、VBox/HBox、Label、Button 和简单 StyleBox 即可。最终主题可以后替换，不能阻塞 loot loop。

## 29. 明确延期

- Take All 与部分数量 Take；
- Drop 与 loose world ItemView；
- full armor loot/UI；
- corpse decay runtime；
- shop、trade、bank、stash；
- crafting、durability、rarity、random loot；
- drag/drop、grid inventory、hotbar、comparison UI；
- quest items、全部 Old Pine authored items；
- persistence/save/load；
- multiplayer/networking；
- universal ItemRepository、InventoryManager、LootManager、EquipmentManager；
- 通用 callback/policy/action dispatcher。

## 30. 建议未来文件（本阶段未创建）

### Phase 8B1

- 修改 `game/runtime/world/world_interaction_target.gd`：增加 ITEM。
- `game/runtime/world/world_item_instance_index.gd`
- `game/data/oldpine/oldpine_item_content_definitions.gd`
- `game/runtime/world/oldpine_corpse_loot_adapter.gd`
- `game/runtime/world/corpse_loot_transfer_result.gd`
- `game/runtime/world/world_item_row_projection.gd`
- 修改 `game/runtime/combat_slice/combat_slice_corpse_view.gd`：picking/range signal only。
- `game/ui/world/oldpine_loot_panel.gd`
- 修改 Old Pine controller/HUD/scene 做窄接线。
- `game/tests/runtime/oldpine_corpse_loot_interaction_test.gd`

### Phase 8B2

- `game/runtime/world/oldpine_equipment_interaction_adapter.gd`
- `game/runtime/world/oldpine_weapon_content_resolver.gd`
- `game/runtime/world/player_inventory_projection.gd`
- `game/ui/world/player_inventory_panel.gd`
- `game/tests/runtime/oldpine_player_inventory_equipment_test.gd`
- `game/tests/runtime/oldpine_full_loot_loop_test.gd`

不要创建 singleton manager、universal repository、generic MVC 或 component map。

## 31. 建议测试

### Corpse / Take

- CorpseView click 产生 exact ITEM target ID；
- corpse ID 解析为 current CorpseState；
- rows 来自 live direct children，精确显示短剑与银子 ×3；
- stale corpse/item、错误 parent、out-of-range、non-ACTIVE、busy 均拒绝；
- short sword corpse → player 保持 same ItemInstanceId；
- capacity exact cap 成功，超一失败；
- corpse-worn stage 0 release/partial failure 与 stage ≥ 1 lock；
- empty corpse 仍留 scene/selectable；
- Take 在 fighting 成功后 busy = 1；
- loot 消耗 0 Combat RNG、0 NPC-init RNG。

### Silver

- amount 3、weight 111、value 300；
- player 无 silver 时 same instance move；
- player amount 5 时 incoming corpse instance survives、amount 8、weight 296、value 800；
- absorbed player instance 被 lifecycle/stack collection 同时移除；
- merge partial failure不回滚已经完成的 Take/absorption。

### Inventory / Equipment

- player direct contents 从 InventoryState 得出；
- projection defensive/value-like；
- Wield 必须 direct-own exact ItemInstance；
- 长剑 primary + 短剑 Wield → short secondary；
- 双空 + short → short primary；
- Unwield primary 不提升 secondary；
- shield/two-handed边界继续复用 Phase 4A1/4B4；
- non-ACTIVE player不能 wield；
- Wield/Unwield 消耗 0 Combat/NPC RNG。

### Combat / lifecycle / reset

- 明确 Unwield long → Wield short 后，下一攻击解析 short damage 15；
- primary null 时走 unarmed，不残留 long damage 25；
- short 仅 secondary 时 Combat 仍使用 primary long；
- aggressively initiated death → loot → inventory → equip → 第二场战斗完整闭环；
- Reset 恢复原型长剑、土匪短剑/银3、零尸体/loot selection/panel state。

## 32. 推荐实现切片

### Phase 8B1 — World Item / Corpse Interaction + Take

- ITEM target；
- corpse picking、range 与 Open Loot；
- map-local ItemInstance index 和三件内容的窄 provider；
- live corpse rows；
- player maximum encumbrance snapshot；
- single Take；
- corpse-aware transfer；
- silver transfer/merge；
- stale/life/busy/capacity gates；
- 无大型 player inventory UI。

### Phase 8B2 — Player Inventory + Inspect + Wield / Unwield + Current Combat Content

- live player inventory panel；
- item inspect；
- ownership-validated equipment adapter；
- current primary weapon content resolver；
- explicit long/short/unarmed行为；
- 第二场战斗观察当前短剑；
- 完整 loot loop integration test。

不建议另设 Phase 8B3 implementation。Take All、Drop 和 polish 不阻塞首个完整 loop，应留给以后按产品优先级选择。8B2 完成后直接进行正式实现审计即可；若实际 UI 集成暴露无法在 B2 收口的独立问题，再建立窄 8B3，而不是预先扩张。

## 33. 第一完整 RPG loot loop 定义

```text
launch Old Pine
→ aggressive bandit attacks
→ player kills bandit
→ select exact corpse ITEM
→ open live Loot panel
→ see short sword + silver ×3
→ Take both
→ corpse remains but contents become empty
→ open player Inventory
→ see long sword + acquired short sword + silver
→ inspect short sword
→ explicitly Unwield long sword
→ Wield short sword as primary
→ fight another bandit
→ next Combat projection resolves current short sword damage 15
→ continue in the same world scene
```

## 34. 实际检查来源

### Native docs / code

- `docs/migration/PHASE_7A_FIRST_WORLD_MAP_NPC_ANALYSIS.md`
- `PHASE_7B1_WORLD_NPC_SPAWN_FOUNDATION.md`
- `PHASE_7B2_OLDPINE_OUTDOOR_PLAYABLE_MAP.md`
- `PHASE_7B3_OLDPINE_PORTAL_AGGRESSION.md`
- `PHASE_4A1_EQUIPMENT_HAND_STATE.md`
- `PHASE_4B1_ITEM_IDENTITY_FOUNDATION.md`
- `PHASE_4B2_INVENTORY_CONTAINMENT_TRANSFER.md`
- `PHASE_4B3_COMBINED_STACK_CURRENCY.md`
- `PHASE_4B4_ARMOR_FOUNDATION.md`
- `PHASE_4B5B_ITEM_LIFECYCLE_DESTRUCTION.md`
- `PHASE_4B5C_DEATH_INVENTORY_CORPSE.md`
- `game/core/items/**`、`inventory/**`、`equipment/**`、`armor/**`、`corpses/**` 与相关 death APIs；
- `NpcCharacterStateFactory`、`NpcRuntimeState`、`OldPineNpcDefinitions`；
- `OldPineOutdoorController`、HUD、WorldInteractionTarget、WorldCharacterBody2D、WorldPlayerRuntimeState；
- `CombatSliceCorpseView`、`CombatSliceContentProfile` 与 current world combat binding path；
- 相关 closed-domain/runtime tests。

### LPC

- `reference/es2/mudlib/feature/move.c`
- `reference/es2/mudlib/feature/equip.c`
- `reference/es2/mudlib/std/equip.c`
- `reference/es2/mudlib/cmds/std/get.c`
- `reference/es2/mudlib/cmds/std/drop.c`
- `reference/es2/mudlib/cmds/std/wield.c`
- `reference/es2/mudlib/cmds/std/unwield.c`
- `reference/es2/mudlib/cmds/std/wear.c`
- `reference/es2/mudlib/cmds/std/remove.c`
- `reference/es2/mudlib/std/item/combined.c`
- `reference/es2/mudlib/std/money.c`
- `reference/es2/mudlib/obj/money/silver.c`
- `reference/es2/mudlib/obj/corpse.c`
- `reference/es2/mudlib/std/char/npc.c`
- `reference/es2/mudlib/adm/daemons/chard.c`
- `reference/es2/mudlib/d/oldpine/npc/bandit.c`
- 两份 `d/oldpine/**/short_sword.c`
- 两份 `d/oldpine/**/long_sword.c`（当前玩家原型内容的直接依赖）。

## 正式结论

第一 loot loop 不需要新 Inventory authority、Combat Core 修改或大规模 item migration。现有 Core 已覆盖 containment、capacity、corpse compatibility、stack merge、lifecycle 与 hand rules。Phase 8B1 的最小真实工作是 ITEM/corpse interaction、live projection、player capacity、map-local identity/content lookup 和 corpse-aware Take orchestration。

**Phase 8B1 可以安全开始。**
