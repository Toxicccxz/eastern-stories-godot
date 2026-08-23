# Phase 4B2：Inventory Containment + Transfer Core

## 范围与权威来源

本阶段只迁移物品容纳图、重量聚合、容量门槛与低层移动的有序副作用。权威实现来自：

- `reference/es2/mudlib/feature/move.c`
- `reference/es2/mudlib/feature/equip.c`
- `reference/es2/mudlib/std/item.c`
- `reference/es2/mudlib/std/equip.c`
- `reference/es2/mudlib/std/char.c`
- `reference/es2/mudlib/include/move.h`
- `reference/es2/mudlib/cmds/std/get.c`
- `reference/es2/mudlib/cmds/std/drop.c`
- `reference/es2/mudlib/cmds/std/give.c`
- `reference/es2/mudlib/cmds/std/put.c`
- `reference/es2/mudlib/adm/daemons/chard.c`
- `reference/es2/mudlib/obj/corpse.c`
- `reference/es2/mudlib/adm/simul_efun/object.c`
- `reference/es2/mudlib/doc/efuns/environment`
- `reference/es2/mudlib/doc/efuns/present`
- `reference/es2/mudlib/doc/efuns/all_inventory`
- `reference/es2/mudlib/doc/efuns/first_inventory`
- `reference/es2/mudlib/doc/efuns/next_inventory`
- `reference/es2/mudlib/doc/efuns/deep_inventory`
- `reference/es2/mudlib/doc/efuns/move_object`
- `reference/es2/mudlib/doc/applies/move_or_destruct`

强制跨阶段 Practice 复核另使用：`cmds/std/practice.c`、`feature/skill.c`、`std/skill.c`，以及 `daemon/skill/fall-steps.c`、`stormdance.c`、`bloodystrike.c` 等当前 registry 所代表的 authored `valid_learn()` hooks。

命令文件仅用于确认未来调用低层 `move()` 的边界；Phase 4B2 没有实现命令解析、`no_get`、`no_drop`、`accept_object`、数量拆分或物品销毁。

## 状态所有权与 endpoint

`InventoryState` 是直接父级与 own-weight 的唯一权威所有者。`ItemInstance` 仍是 Phase 4B1 的不可变身份对象，不增加 `parent`、`environment` 或通用状态容器，因而没有双重父级权威。

`ContainmentEndpoint` 是 `{ kind, stable endpoint_id }` 的窄值对象。当前仅有：

- `CHARACTER`：角色直接物品栏；
- `ITEM`：可作为目标的物品实例；
- `WORLD`：房间或未来 World Runtime 提供的逻辑放置点。

LPC 尸体继承 `ITEM`（`obj/corpse.c`），所以尸体容纳使用尸体 `ItemInstanceId` 的 `ITEM` endpoint；本阶段不需要伪造独立 Corpse 类型。endpoint 不接受 `Object`、`Variant`、`Node` 或 LPC 路径。

`register_item()` 只在一个 `InventoryState` 聚合内登记 live instance ID 与 own-weight；它不是全局注册表、Catalog、Repository 或对象工厂。空 instance ID、重复 ID、空 endpoint ID、未登记的 item endpoint 都在权威变更边界被拒绝。具有稳定 instance ID 但尚未解析 definition ID 的物品不使容纳关系产生歧义，因此容纳层不读取 definition ID。

新 clone 可暂时没有 LPC `environment()`，所以已登记但无父级的状态合法。销毁/注销生命周期仍然延后。

## 直接成员、祖先与 root holder

父图为单父有向树/森林：每个 live item 最多一个直接 endpoint。`direct_children()` 与 `is_direct_child()` 只回答一层关系；`ancestry()` 从直接父级向外返回；`root_holder()` 返回最外层 endpoint；`is_ancestor()` / `is_descendant_of()` 明确回答递归关系。

例如 `Character C -> Bag B -> Item I`：I 的直接父级是 B，I 不是 C 的直接子项，但 C 是 I 的 root holder。返回的 endpoint、祖先数组和子项数组都是快照/副本。子项查询使用稳定 ID 字典序，避免依赖 MudOS 对象链表次序；命令层若需要 authored 顺序，需在未来单独定义。

所有重挂都会拒绝：

- item 放入自身；
- item 放入任一直接或深层后代；
- 任何会形成循环的关系。

失败不改变父图。

循环检查是 native 图不变量，并非 MudOS `move_object()` 自身提供的规则。唯一写入 seam 是下划线标记的内部 `_apply_reparent()`；它仍会重新验证 item、destination 与 cycle，外部转移一律经 `InventoryTransferService`。查询 ancestry/subtree 时另有 visited guard，因此即使调试期内部状态被破坏，也不会无限循环；正常公开转换无法构造这种状态。

## 重量与容量

来自 `feature/move.c`：

```text
item subtree weight = item own weight + direct contents subtree weights
endpoint contents weight = sum(direct child subtree weights)
```

`CHARACTER`/`WORLD` 等非 item endpoint 自身没有 item own-weight；`ITEM` endpoint 的 own-weight 属于该 endpoint ID 对应的登记物品，而 `contents_weight(item_endpoint)` 只计算其直接内容物及后代。例如 bag own=10、内含 item own=3 时，bag subtree 为 13，但 bag endpoint contents 为 3。

`InventoryState` 从父图即时计算上述值，不缓存第二份 encumbrance；因此后代重量在每层祖先中恰好出现一次，也不会产生手工增减不同步。`update_own_weight()` 对应 `set_weight()` 的窄状态能力：不会因超容量而拒绝，也不夹紧负值。LPC 的 underflow 日志和 `over_encumbrance()` 文本属于运行时/呈现，不在本阶段模拟。

`InventoryTransferDestination` 是一次移动尝试的显式投影：已解析 endpoint、是否可用、是否声明可容纳、最大 contents weight。当前 contents weight 从 `InventoryState` 权威父图计算，容量公式严格为：

```text
current destination contents weight + moving subtree weight > capacity
    => reject
```

等于上限允许。容量不强制为正；负 weight/容量保留 LPC 数值结果。显式声明可容纳且容量为 0 的目标仍可接受 0-weight item，未把“零容量”误当作通用非容器标记。真正的 authored Container policy 延后。

若目标已经位于移动物祖先链，完全跳过容量比较。这保留 `feature/move.c` 的例外：`C -> Bag -> I` 中把 I 从 Bag 提到 C，不把 I 当作 C 的新增负荷；重挂后 C 的总重量不变。

## 有序 transfer 与 Equipment

`InventoryTransferService` 不持有状态，也不是 singleton。其边界顺序为：

1. 检查原 LPC 中由 live object 隐含保证的 native item ID / registration 前置条件；
2. 记录旧 parent/root；
3. 若物品直接位于 `CHARACTER` 下，且调用方提供的该直接持有者 `EquipmentState` 引用了该 instance ID，调用现有 `unwield()`；
4. 验证 typed destination 的 ID、可用性与容纳投影；
5. 验证 item endpoint 与循环；
6. 若目标不是祖先，执行严格容量比较；
7. 重挂单一父图；派生重量随新父图体现 LPC 的旧祖先减重与新祖先增重；
8. 返回不可变 typed snapshot result。

第 3 步严格先于目标验证与容量检查，保留 LPC 的局部变更：已装备物品目标无效或超重时，父级不变，但武器引用已清除且不会回滚。同父级低层移动也会先解除装备，再由祖先规则跳过容量；结果为成功、父图不变、装备已解除。

`InventoryState` 不依赖 `EquipmentState`。外层 service 仅在当前直接父级为 character 时读取调用方提供的直接持有者装备状态；嵌套物品和移动装有普通武器的 bag 不触碰 Equipment。移走 primary 不提升 secondary，沿用 Phase 4A1 行为。Armor/worn detach 明确延后。

## Typed result

`InventoryTransferResult` 保存：

- `outcome` 与 `succeeded`；
- `item_instance_id`；
- previous/requested/resulting parent；
- previous/resulting root holder；
- `equipment_detached`；
- `containment_changed`。

失败类型区分空 item ID、未登记 item、无效/不可用/不可容纳 destination、cycle、capacity exceeded、equipment detach failure 与内部重挂失败。结果只保存标量和 endpoint 快照，不保存 mutable Inventory/Equipment 引用。

## 与既有架构的关系

- `ItemDefinition` 未扩展；weight、container、display、value 等仍不属于 Phase 4B1 definition。
- `ItemInstance` 未修改；其 ID 是父图的 item key。
- `CharacterState` 未自动组合 `InventoryState`；session/aggregate 归属仍待应用层出现后决定。
- `EquipmentState` 未修改；transfer 通过已有 instance ID 和 `unwield()` 协调，不产生 `InventoryState <-> EquipmentState` 循环。
- 原 `move_object()` / `environment()` 对象关系被稳定 ID 父图替代；字符串目标加载由外层解析为 typed destination，本 core 不加载 LPC 路径。
- 权重由图派生而非保存 MudOS 的增量 `encumb` 缓存。这是 native 状态归一化，不改变已实现的最终重量、容量门槛或局部装备副作用。

未发生需要写入 `DECISIONS.md` 的兼容性替换。

## 正式审计结论与跨阶段纠正

审计再次逐行核对 `feature/move.c`：装备解除确实早于字符串/object destination 解析；容量拒绝发生在旧 parent 减重与 `move_object()` 之前。因此失败可保留原 containment，却已经清除 primary/secondary 装备引用。测试覆盖 invalid、unavailable 与 capacity failure，且不回滚该局部 mutation；unequipped failure 不产生装备变化。父图本身只有一个 `item_instance_id -> endpoint` 映射，没有可失步的反向 children cache，重挂会覆盖唯一旧 parent。

审计也覆盖四层 cycle、祖先顺序、同 root 与跨 root（含 nested leaf）重量守恒、sibling capacity 不享受祖先例外、Character→Bag 解除装备，以及 Room/Bag→Character 不自动装备。`ItemDefinition`、`ItemInstance`、`CharacterState` 与 Phase 4A1 `EquipmentState` 均未因 Inventory 模型扩张。

强制跨阶段检查发现并纠正一个非 Inventory 的既有问题：Practice 曾由代表性 `PracticePolicy.valid_learn()` 维护重复规则，不能覆盖后来已经迁移到 `SkillLearnPolicyRegistry` 的全部 authored 限制。现在 `PracticeService` 严格按 `practice.c` 顺序，在 fighting/mapping/raw checks 后评估与 Learn 共用的 `SkillLearnPolicy`，再调用独立 `PracticePolicy.practice_skill` 等价 hook，最后 improve。性别与装备拒绝会先于 practice hook，允许结果才会进入 hook；两类 policy 不合并，也没有引入 TeachingContext。

## 明确延后

Phase 4B2 不含：get/drop/give/put adapter、busy/living/present 查找、`no_get`/`no_drop`、NPC `accept_object`、stack/amount/split/merge、money、food/liquid、Armor、Combat、corpse/death/decay、autoload/save、destruction/unregister、World Node/位置、UI、Catalog/Repository、authored container 数据与任意 LPC callback dispatch。
