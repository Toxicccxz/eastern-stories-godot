# Phase 8B1：世界尸体交互、Open Loot 与单件 Take

状态：**FORMALLY CLOSED**

## 范围

本阶段关闭首个 loot loop 的前半段：Old Pine 土匪死亡后，玩家可按真实尸体实例选择 `ITEM` 目标，在近距离打开实时 Loot panel，并逐件拿取短剑和银子。没有实现玩家 Inventory/Wield UI、Take All、Drop、持久化、尸体 decay runtime、Armor loot 或 Combat 公式修改。

## 来源与关闭合同

直接复核的 LPC：

- `reference/es2/mudlib/cmds/std/get.c`
- `reference/es2/mudlib/std/item/combined.c`
- `reference/es2/mudlib/feature/move.c`
- `reference/es2/mudlib/obj/money/silver.c`
- `reference/es2/mudlib/std/money.c`
- `reference/es2/mudlib/obj/corpse.c`
- `reference/es2/mudlib/d/oldpine/obj/short_sword.c`
- `reference/es2/mudlib/d/oldpine/obj/long_sword.c`

实现复用 Phase 4B2/4B3/4B5C 的 `InventoryTransferService`、`CombinedStackService`、`CorpseContentTransferService` 和 `ItemLifecycleOwnerContext`；这些关闭 Core 均未修改。

## ITEM target 与 map-local identity

`WorldInteractionTarget` 增加 `ITEM + ItemInstanceId`。尸体不引入假 `CORPSE` kind，也不以 Node、显示名、definition ID 或 row index 作为规则身份。

`WorldItemInstanceIndex` 是每个 Old Pine map instance 独有的只读身份索引：

```text
ItemInstanceId -> immutable ItemInstance snapshot
```

它登记玩家原型长剑、三名土匪的短剑/银子以及死亡时产生的尸体实例。它不拥有 liveness、parent、weight、amount 或 equipment；所有调用先以 `InventoryState.is_registered()` 重验 live authority。Transfer 后同一 snapshot/instance ID 保持不变；被 merge 吸收的旧银子可留下 stale metadata，但不能复活。

## authored item provider

`OldPineItemContentDefinitions` 只覆盖当前三种内容：

| definition | 显示 | 关键事实 |
| --- | --- | --- |
| `es2:d/oldpine/obj/long_sword` | 长剑 | sword、damage 25、weight 7000；仍是 prototype player content |
| `es2:d/oldpine/obj/short_sword` | 短剑 | sword、damage 15、weight 3000、SECONDARY capable 由既有定义保留 |
| `es2:obj/money/silver` | 银子 | base weight 37、base value 100 |

名称与描述来自上述 LPC 文件，不在 HUD/controller 硬编码。Amount 始终从 `CombinedStackCollection` 读取。

## 玩家容量

`WorldPlayerRuntimeState` 保存初始化时的一次性 `maximum_encumbrance`：

```text
setup-time strength * 5000
```

Old Pine 初始化使用 `CharacterDerivedValues.maximum_encumbrance()` 写入一次；后续 strength 变化不会令 Take 重算。玩家 destination 使用该值，不能再使用 world 的 `1_000_000` capacity。等于容量成功，超一失败，stack amount 3 的银子按当前 111 weight 检查。

## 尸体 picking 与空间决定

每个动态 `CombatSliceCorpseView` 创建：

- `PickingArea`：鼠标点击只发出 exact corpse `ItemInstanceId`；
- `LootInteractionRange`：collision mask 1、半径 96 的圆形 `Area2D`。

范围只属于 scene adapter。选择/Inspect 可在范围外完成；Open Loot 和 Take 都重新检查当前 range。LPC same-room 到 native near-corpse 的替换已记录于 `DECISIONS.md`。CorpseView 不保存 contents、amount、transfer result 或 Inventory 引用，物理位置仍是死亡时捕获的 `global_position`。

## Live Loot projection 与 UI

每次打开及每次 Take 后按以下链重建：

```text
InventoryState.direct_children(ITEM(corpse_id))
-> WorldItemInstanceIndex
-> OldPineItemContentDefinitions
-> CombinedStackCollection amount
-> CorpseState worn projection
-> WorldItemRowProjection
```

Row 保存 exact instance/definition ID、名称、描述、amount、category、`can_take` 与 corpse-worn/locked facts。未知 live definition 返回 typed unavailable，不伪造 Unknown Item。

UI 使用持久化的 `Open Loot` button 与 `PanelContainer / ScrollContainer / VBoxContainer / HBoxContainer / Label / Button`。Panel 只发 `Take(ItemInstanceId)`，不修改 Inventory、stack、corpse 或 busy。空尸体显示 Empty，但仍注册、可见、可选、可 Inspect。

## 单件 Take 顺序

`OldPineCorpseLootAdapter` 在 mutation 前依次重验：请求、player exists、committed ACTIVE、busy、corpse live/current WORLD parent、range、item live、exact corpse direct parent、index/content coherence。随后构造 player capacity destination，并且所有尸体内容无条件经过：

```text
CorpseContentTransferService.transfer_out()
```

短剑保持同一 instance ID，从 `ITEM(corpse)` 变为 `CHARACTER(player)`；不会自动 Wield 或替换原型长剑。

银子没有既有 player sibling 时，amount 3、weight 111、value 300 的同一实例直接存活。若 player 已有 amount 5：先完成 corpse-aware transfer，再以 incoming amount-3 实例调用 `transfer_and_merge()`；incoming 实例存活，旧 player silver 被 lifecycle 移除，结果 amount 8、weight 296、value 800。

若 ownership transfer 成功但 merge 失败，结果为 `PARTIAL_MERGE_FAILED`：物品保持 player-owned，不回滚尸体。`CorpseLootTransferResult` 同时保存 actor/corpse/item ID、底层 corpse transfer、可选 merge、survivor ID 与 busy evidence。

若此时玩家仍在 fighting，busy 仍为 1：LPC `get.c::do_get()` 的 busy 门槛跟随已经成功的 item move，而不是跟随外层 merge 是否完整成功。审计测试固定了 `ownership complete + merge failure + fighting -> PARTIAL_MERGE_FAILED + busy 1`。

## busy、fighting 与 corpse-worn

- player 已 busy：mutation 前拒绝；
- 单件 Take 不因 fighting 被拒绝；成功后调用现有 `start_busy(1)`；
- failed Take 不增加 busy；
- UNCONSCIOUS/DEAD player 通过 committed `CharacterRuntimeLifeStatus` 拒绝；
- fresh stage-0 corpse-worn item 先 release，再 transfer；之后容量失败不恢复 release；
- stage >= 1 corpse-worn item 返回 `CORPSE_WORN_LOCKED`。

Loot path 不读取 Combat/NPC RNG，也不启动新的 Timer/cooldown。

## Godot AI/MCP

实现前用 Godot MCP 检查了当前 main scene、102 节点层级、空 `CorpseLayer`、player collision 与旧 HUD。随后用 MCP 创建并保存 `OpenLootButton` 和 9 节点 Loot panel hierarchy；正式审计再次 save、force reload 并检查 hierarchy、属性和信号。动态 picking/range child 由 CorpseView 脚本生成。最终持久化层级为 112 个节点，Loot panel 的运行时矩形位于视口内。

## 验证

`oldpine_corpse_loot_interaction_test.gd` 加上 Phase 7B3/7B2/7B1、6B3、4B5C、4B3、4B2 定向回归共 **2092 assertions PASS**；完整项目套件共 **7116 assertions PASS**。覆盖 exact ITEM identity、索引/内容、live rows、stale/range/life/busy gates、短剑、银3、5+3 incoming survivor、fighting partial merge busy、已有负重 exact/+1 capacity、corpse-worn、动态 Area、多尸体 view/contents/range、部分死亡门禁、空尸体、target switch、RNG、map continuation 与 fresh scene reset。

## 正式审计修正

审计发现并修复四个 Phase 8B1 接线/表现问题：

1. `death_inventory_result` 只要含 corpse 就会登记 index 并连接 picking/range，可能把 Phase 6B3 的 blocked partial corpse 暴露成普通 loot target。现在仍保留关闭合同要求的 partial `CorpseState` 和 presentation view，但只有 `DEATH_COMPLETE` 才登记 Phase 8B1 corpse metadata、连接交互信号并进入可拾取 view index。
2. 完整死亡后的 map-local index 登记冲突会返回一个新的空 lifecycle result，掩盖已经完成的死亡和 mutation。现在始终返回原始 lifecycle evidence；登记失败只让该 view 保持非交互，不伪造 rollback 或完成失败。
3. 已选择尸体失去 `InventoryState` liveness 后只关闭 panel，却保留 ITEM target 和 Open Loot HUD 状态。现在下一次 scene refresh 会清除 target、按钮、inspection 与 panel；stale metadata 仍可留在 index，但不能恢复交互。
4. Loot panel 的右锚点 offsets 原先宽度为零，最小尺寸会按默认增长方向伸到视口外。现在使用明确的 360px 左右 offsets；MCP 与场景测试均确认 panel 完整位于视口内。

完整 runner 还暴露并修复一个测试类型缺口：Phase 8B1 `run_all()` 现明确返回 `Dictionary[String, Variant]`，与项目 runner 的强类型合同一致。没有因此修改 production 规则。

审计没有修改 Inventory、Combined Stack、Corpse、Equipment 或 Combat Core。`DECISIONS.md` 仍只新增 same-room 到 96px near-corpse Area2D 这一条可观察兼容性决定。

## 明确延期到 Phase 8B2 或以后

- player Inventory/Inspect/Wield/Unwield UI 与 current weapon combat resolver；
- Take All、部分数量 Take、Drop 和 loose world item；
- Armor loot UI、corpse decay runtime、save/load；
- universal ItemCatalog/Repository、global Item/Inventory/Loot manager；
- 最终美术、主题、拖放、筛选和 rarity。

**Phase 8B1 正式关闭：corpse ITEM interaction、Open Loot、live corpse projection、single corpse-aware Take 与 silver combined merge 已完成。**
