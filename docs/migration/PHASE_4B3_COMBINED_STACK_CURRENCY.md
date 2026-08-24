# Phase 4B3：Combined / Stack / Currency Instance Semantics

## 范围与权威来源

本阶段只迁移显式可堆叠物品的 definition/state、数量与 own-weight 联动、拆分、移动后合并、货币数量价值，以及零数量的一秒延迟销毁意图。权威来源为：

- `reference/es2/mudlib/std/item/combined.c`
- `reference/es2/mudlib/std/item.c`
- `reference/es2/mudlib/feature/move.c`
- `reference/es2/mudlib/feature/equip.c`
- `reference/es2/mudlib/adm/simul_efun/object.c`
- `reference/es2/mudlib/std/money.c`
- `reference/es2/mudlib/obj/money/coin.c`
- `reference/es2/mudlib/obj/money/silver.c`
- `reference/es2/mudlib/obj/money/gold.c`
- `reference/es2/mudlib/obj/money/thousand-cash.c`
- `reference/es2/mudlib/feature/finance.c`
- `reference/es2/mudlib/std/room/bank.c`
- `reference/es2/mudlib/std/room/hockshop.c`
- `reference/es2/mudlib/cmds/std/get.c`
- `reference/es2/mudlib/cmds/std/drop.c`
- `reference/es2/mudlib/cmds/std/give.c`
- `reference/es2/mudlib/cmds/std/put.c`
- `reference/es2/mudlib/std/weapon/throwing.c`
- `reference/es2/mudlib/adm/daemons/weapond.c`
- `reference/es2/mudlib/std/medicine/pill.c`
- `reference/es2/mudlib/std/medicine/powder.c`
- `reference/es2/mudlib/obj/drug/snake_drug.c`

另对整个 `reference/es2/mudlib/` 扫描了 `inherit COMBINED_ITEM`、`inherit MONEY`、`query_amount`、`set_amount`、`add_amount`、`base_weight`、`base_value`、`value()`、`new(base_name(...))`、`base_name()`、`call_out()` 与 `destruct()` 的使用。命令、药品、投掷、金融代码只用于证明本阶段边界，没有迁移其命令流程或 authored 行为。

## 状态与定义所有权

`CombinedStackDefinition` 只保存不可变堆叠事实：

- `item_definition_id`：与 Phase 4B1 definition 对齐；
- `stack_compatibility_id`：精确合并策略键；未来 importer 可由 canonical LPC program `base_name()` 派生；
- `base_weight`：每单位重量。

`stack_compatibility_id` 不是第三种物品身份，也不是显示名称。比较不做大小写、标点或路径归一化；相同 `ItemDefinitionId` 不自动意味着可合并。

`CombinedStackState` 只保存 `item_instance_id` 与唯一权威 `amount`。数量没有加入通用 `ItemInstance`，因此普通物品不会偶然获得堆叠能力。`CombinedStackCollection` 是调用方持有的局部 typed aggregate，用 stable instance ID 关联 state 与 definition；它不是 Catalog、Repository、autoload singleton 或通用 component map，公开查询返回快照。

Containment 与当前 own-weight 仍唯一归 `InventoryState` 所有。数量只能经 `CombinedStackService` 修改，service 同步 `InventoryState.update_own_weight()`，没有第二份可独立修改的 current-weight。

## `set_amount()`、`add_amount()` 与初始零

严格对应 `std/item/combined.c:11-31`：

| 请求 | 数量结果 | own-weight 结果 | typed 结果 |
|---|---|---|---|
| `v > 0` | 存储 `v` | `v * base_weight` | `UPDATED` |
| `v == 0` | 保留旧数量 | 保留旧重量 | `DELAYED_DESTRUCTION_REQUESTED`，delay `1` 秒 |
| `v < 0` | 不改变 | 不改变 | `LEGACY_NEGATIVE_AMOUNT_ERROR` |

LPC 的负数路径以 `error()` 中止；native core 用 typed failure 表达相同的未成功 mutation，不让整个游戏 core 崩溃。没有 clamp-to-zero。

零结果只是不可变 lifecycle intent：包含 instance ID、请求值、前后数量/重量、动作和延迟秒数；不保存 `Timer`、`Callable`、`Node`、Inventory 引用，也不负责何时执行销毁。`add_amount(delta)` 先计算 `current + delta`，再走完全相同的 `set_amount()` 分支。

`combined.c` 的静态 `amount` 初值可为 0，且 `setup()` 不赋初值；money 与代表性 subclass 都依赖 authored caller 后续 `set_amount()`。所以注册时的 raw zero 是合法、仍存活、不产生 lifecycle intent，也不凭空执行正数分支的重量重算；它与显式调用 `set_amount(0)` 不同。正常新 LPC object 的 `feature/move.c` own-weight 默认同样为 0，但 native 注册仍保留调用方提供的既有权威 own-weight，而不是假装发生过 `set_amount()`。若 raw-zero stack 移入 living，`combined.c` 仍无条件调用 `set_amount(total)`，因此 total 为 0 时会产生延迟销毁意图并继续保留当时旧重量。

## 重量同步

正数量的 own-weight 为：

```text
amount * CombinedStackDefinition.base_weight
```

正初值注册、正数 set/add、拆分和合并均经一个 orchestration path 同步 `InventoryState`。Raw-zero 注册不模拟 `set_amount()`，因而保留既有 own-weight。Inventory 的 subtree/contents 派生与容量模型未被替换。零请求保留旧重量；负请求不改重量。`base_weight == 0` 的正数量 stack 仍为零重量，没有凭空添加最小重量。

## 拆分

纯 stack split 只接受 `0 < A < N`，由调用方提供一个不同且未登记的 `ItemInstanceId`：

```text
source: N -> N - A
new:             A
```

新 stack 保留同一 definition identity 与 compatibility definition，但拥有独立 instance ID；source/new own-weight 分别同步为 `(N-A)*base_weight` 与 `A*base_weight`。新实例先登记为无 parent，之后的命令/应用层再决定放置，因此当前 root 的 contents weight 暂时只反映 source。没有内部 ID generator 或全局 factory。

这对应命令中的 `new(base_name(original))`：创建同 program 的新默认 clone，并不复制尚未建模的任意 mutable LPC dbase。

`get.c` 的确定性缺陷没有写入通用 split：非 living source 的 partial get 会先把 original 改为 `N-A`，把新 clone `A` 放回 source，却把被缩减的 original 传给 `do_get()`，所以成功时取走 `N-A`、留下 `A`。

Living source 的路径更异常，且同样明确延后：新 clone 先 move 回 living source，触发 combined merge；被缩减的 original `N-A` 会被吸收/销毁，clone 暂时得到合计数量，随后命令又执行 `clone.set_amount(A)` 把数量覆盖为 `A`，最后 `do_get()` 仍拿着已销毁 original 引用。结果可只剩 `A`，其他数量丢失。未来 get adapter 可用本阶段 split primitive 按命令顺序保留或经产品决策修正；本阶段没有自动回滚未来命令门槛失败。

Split 还要求 source 同时存在于调用方提供的 `CombinedStackCollection` 和同一次操作的 `InventoryState`。正式审计补上了这个聚合一致性前置条件；否则误配两份 aggregate 会让 source amount 在一处改变、权威 own-weight 留在另一处。拒绝发生在 source amount、新 instance registration 和 weight mutation 之前。

## 移动后合并

`CombinedStackService.transfer_and_merge()` 保留 `combined.c:39-61` 的顺序：

1. 先调用已审计的 `InventoryTransferService`；失败不合并；
2. 只有 resulting endpoint 为 `CHARACTER`（本阶段对 `living()` 的 typed 映射）才扫描；
3. 只扫描 character 的直接子项，不递归 nested contents；
4. 只吸收 compatibility key 精确相等的 sibling；
5. 当前正在移动的 instance 永远存活；循环中先读取 sibling amount，再立即销毁/移除 sibling；
6. 全部 sibling 处理完后，调用 survivor 的 `set_amount(total)` 更新数量/重量。

`WORLD`、`ITEM` bag 和 corpse `ITEM` 都不自动合并。多个 sibling 的数量相加是交换律运算；`InventoryState.direct_children()` 使用 stable instance ID 顺序，使 typed result 的 absorbed ID 顺序确定，但不声称 MudOS `all_inventory()` 的对象链表顺序具有 gameplay 含义。

即使 character 内没有 compatible sibling，LPC 仍调用 survivor 的 `set_amount(total)`；实现保留此行为，尤其是 raw-zero 的延迟销毁边界。

## 被吸收实例与 Equipment

合并吸收是立即生命周期变化，与 `set_amount(0)` 的延迟意图不同。每个 absorbed leaf 会同时从：

- `InventoryState` live registration / direct parent / own-weight；
- `CombinedStackCollection` state / definition association

移除，避免 ghost child 与重量双算。为此只给 `InventoryState` 增加了 `_remove_registered_leaf()` 窄内部 seam；它不是通用 destruction API，不处理尸体、contents 转移、decay 或 runtime callback。

MudOS simul-efun `destruct()` 先调用 `feature/move.c::remove()`；若 absorbed throwing stack 的 `equipped` marker 存在，`remove()` 会调用 `unequip()`。Native orchestration 因此接收 Phase 4B2 已建立的窄 `EquipmentState` 输入，并只通过 `unwield()` 清理被吸收 instance 的 hand reference；不直接写 slot，不提升 secondary，也不把 B 的装备状态转移给 survivor A。若 moved A 自身原已装备，Phase 4B2 transfer 会在移动/验证前按 instance ID 解除它。

主动扫描确认现有 `COMBINED_ITEM` / `MONEY` / throwing / pill / powder 后代没有 `is_container`、`set_max_encumbrance` 或 `query_max_encumbrance` 容器声明。仍不假定任意 malformed native stack 绝不含 children：若将被吸收的 stack 有直接子项，合并在已完成 move 后返回 `ABSORBED_STACK_HAS_CONTENTS`，保留 parent 与 children，不静默 orphan。支持 arbitrary contained-child destruction 需完整生命周期系统，明确延后。

## 货币与普通 CombinedItem

只有 `std/money.c` 覆盖 `value()` 为 `base_value * query_amount()`。因此 `CurrencyDefinition` 只保存与 stack definition 对齐的 `item_definition_id` 与 `base_value`，提供数量价值计算；调用方使用该实例的权威 `CombinedStackState.amount`。普通 `CombinedStackDefinition` 没有 `base_value` 或 `value_for_amount()`。

因为显式 `set_amount(0)` 在销毁执行前仍返回旧 `query_amount()`，货币在该一秒窗口内也继续保持旧 `base_value * amount`，并保留旧重量。测试固定了这个派生结果；没有另存一份 currency amount。

逐文件确认的 authored 数值为：

| denomination | `base_value` | `base_weight` |
|---|---:|---:|
| coin | 1 | 1 |
| silver | 100 | 37 |
| gold | 10,000 | 37 |
| thousand-cash | 100,000 | 3 |

这些数值只作为 LPC-derived test facts，没有建立 denomination registry、wallet 或 economy service。`feature/finance.c` 只识别 gold/silver/coin；bank 的整数兑换、hockshop 定价与 thousand-cash 差异留给未来交易层。

## 源行为怪异点

- `obj/drug/snake_drug.c` 写成 `base_weiht`，不是 `base_weight`；有效继承值仍为 0。通用逻辑没有静默修正，测试证明正数量、零 base-weight 仍为零重量。
- `std/weapon/throwing.c` 是 combined + equip；真正的消费调用位于 `adm/daemons/weapond.c::throw_weapon()`：当旧 amount 恰为 1 时，先显式 `unequip()`，再 `add_amount(-1)`。后一步得到显式零请求，旧 amount/weight 保持并安排一秒后销毁。Phase 4B3 只实现/测试可复用的 stack 零边界；前置 unequip 属于明确延后的 throwing Combat `post_action` orchestration，没有在通用 `add_amount()` 内伪造。
- `set_amount(0)` 可以被重复请求并产生多个 LPC `call_out`；本阶段只返回每次请求各自的 intent，不做去重或 runtime scheduling。

## Native substitution 与明确延后

本阶段唯一结构性替换是以 typed result 表达 LPC `error()` 与 `call_out()`，并以 stable ID 局部 aggregate 取代运行时对象查找；已实现的数量、重量、合并 survivor 与生命周期可观察边界不变。contained stack guard 是对未出现在 active authored stacks 中、且需要完整 driver destruction 语义的非法/未支持形状所设 native invariant，不是对现有内容规则的重写。

明确延后：get/drop/give/put adapters、parser、busy/living/present、`no_get`/`no_drop`、NPC `accept_object`、food/liquid/通用 consumable、Conditions、Armor/wear/remove、Combat、throwing combat、weapon break/bash、corpse/death、autoload/save、World Node、UI、Catalog/Repository、bank/wallet/economy、runtime scheduler 与 generic callback/lifecycle dispatcher。

没有需要更新 `DECISIONS.md` 的已实现兼容性偏离。

## 正式审计结论

正式审计发现并修复一项生产一致性问题：`split()` 原先没有验证 source 仍登记在所提供的 `InventoryState`，误配 aggregate 时可能改变 stack amount、在另一 Inventory 创建 split instance，却无法同步原 source weight。现在该路径返回 `INVALID_SOURCE_INSTANCE`，且不发生任何 mutation。

审计测试另补充：重复零请求各自返回独立一秒 intent；零/负请求保持 parent/root；nested stack 的 own-weight 更新只经 `InventoryState` 一次并自动反映到 bag subtree 与 character load；货币在延迟销毁窗口仍按旧 amount 保持 value；错误 aggregate split 不产生部分状态。未发现需要扩大到命令、Combat、Armor 或 runtime scheduler 的问题。
