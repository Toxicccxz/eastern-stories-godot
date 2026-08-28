# Phase 8B2：玩家物品栏、武器交互与当前战斗内容

状态：**FORMALLY CLOSED**

本阶段只补齐 Old Pine 首个可玩 loot loop：玩家查看实时 direct inventory、Inspect、显式 Wield/Unwield，并让下一次世界战斗机会按当前主手解析长剑、短剑或空手。没有修改 Inventory、Equipment、Combined Stack、Armor、Combat 或 Corpse Core。

## 权威与投影

玩家物品权威仍是 map-local `InventoryState`：

```text
ContainmentEndpoint.CHARACTER(oldpine.player)
→ InventoryState.direct_children()
→ WorldItemInstanceIndex（只解析 definition identity）
→ OldPineItemContentDefinitions（只解析当前 authored content）
→ CombinedStackCollection（只解析 live amount）
→ CharacterState.equipment / ArmorState（只解析当前装备状态）
→ PlayerInventoryRowProjection
```

`PlayerInventoryProjection` 不保存列表，也不递归查询 nested/root-owned item。每次打开 Inventory、Take 成功/失败后的可见刷新、Inspect、Wield、Unwield 都从 live authority 重建。稳定顺序沿用 `InventoryState.direct_children()` 的 `ItemInstanceId` 字典序；index 中残留的 absorbed/stale metadata 不会出现。

row 只保存值快照：instance/definition identity、name、description、amount、category、`NONE/PRIMARY/SECONDARY`、weapon skill/damage、currency total value 与可用动作。所有按钮始终携带 exact `ItemInstanceId`，UI 不持有 authoritative `ItemInstance`、parent、stack 或 EquipmentState。

## Inventory UI 与 Inspect

Godot 场景持久化层级为：

```text
HUD/Overlay
├── StatusPanel/.../Actions/InventoryButton
└── PlayerInventoryPanel
    └── Margin/VBox
        ├── Title
        ├── Separator
        ├── Scroll/PlayerInventoryRows
        ├── PlayerInventoryEmptyLabel
        ├── PlayerInventoryInspectText
        └── PlayerInventoryCloseButton
```

Inventory 与 Loot panel 采用最小互斥表现规则：打开一个会关闭另一个；这不改变任何 gameplay authority。非 `ACTIVE` 玩家不能打开本阶段含主动装备操作的 Inventory panel。

Inspect 重新按 exact ID 投影当前 direct-owned item，并显示：

- 长剑：`长剑`、LPC long 文本、`sword`、damage `25`、当前手位；
- 短剑：`短剑`、LPC long 文本、`sword`、damage `15`、当前手位；
- 银子：`银子`、LPC long 文本、live amount 与 `100 * amount` 当前总值。

Inspect、打开/关闭与投影均不修改 state，也不接触 Combat/NPC RNG。

## Wield / Unwield 适配器

`OldPineEquipmentInteractionAdapter` 是 world-runtime 授权边界；它不复制 `EquipmentState` 的手位规则。

Wield 顺序：request coherence → player exists → committed `ACTIVE` → item registered → exact player direct child → index/content resolve → weapon category → definition/ref identity match → live shield projection → `EquipmentState.wield()`。

Unwield 顺序：request coherence → player exists → committed `ACTIVE` → item registered → exact player direct child → exact current PRIMARY/SECONDARY → `EquipmentState.unwield()`。Unwield 不依赖 content lookup，符合 LPC 命令只检查 owned object 与 `equipped == "wielded"` 的结构。

没有新增 busy/fighting gate；`cmds/std/wield.c` 与 `cmds/std/unwield.c` 没有这种限制。Wield/Unwield 只修改现有 EquipmentState，不移动、销毁或自动替换物品。

保持的手位行为：

- fresh：长剑 PRIMARY；
- 长剑 PRIMARY + Wield 短剑：短剑 SECONDARY；
- 卸下 PRIMARY：SECONDARY 不自动晋升；
- 短剑要成为 PRIMARY：先显式卸短剑、卸长剑，再 Wield 短剑；
- 已 wield 的短剑返回既有 `ALREADY_WIELDED`；
- Take 短剑后仍为 `NONE`，不自动装备。

## 当前主手武器解析

`OldPineWeaponContentResolver` 位于 world participant construction 边界，不进入 Combat Core：

```text
每次 _build_participants()
→ current EquipmentState.primary_weapon()
→ live Inventory direct ownership
→ WorldItemInstanceIndex definition identity
→ OldPine authored content
→ fresh CombatSliceContentProfile
→ WorldCombatBindingAdapter
```

解析结果是 narrow typed `OldPineWeaponContentResolution`：

- 长剑 PRIMARY → verified long profile，apply damage `25`；
- 短剑 PRIMARY → verified short profile，apply damage `15`；
- PRIMARY null → unarmed-only profile；
- PRIMARY null + 短剑 SECONDARY → 仍是 unarmed；
- 长剑 PRIMARY + 短剑 SECONDARY → 仍是 long `25`；
- stale/non-owned/mismatched/unsupported PRIMARY →显式 unresolved outcome、无 profile，不回退到长剑或短剑。

`CombatSliceContentProfile` 只增加了可验证的 unarmed-only 配置（空 verified weapon IDs 且 damage 0）；默认 arena 长剑 profile 和既有行为不变。resolver 每次返回新 profile，不缓存或突变共享 content。

Bandit 仍使用既有来源明确的固定短剑 profile；本阶段没有泛化 NPC equipment resolver。

## 完整 loop 与战斗证据

`oldpine_full_loot_loop_test.gd` 从真实 `.tscn` 启动：第一名 authored bandit 经既有 combat/lifecycle 死亡，`DEATH_COMPLETE` 尸体进入 Open Loot，短剑与 amount-3 银子经既有 corpse-aware Take 成为玩家 direct children，尸体刷新为 Empty。Inventory 随后显示长剑、短剑、银子，Inspect 读取 authored 短剑 facts。

测试先锁定“长 PRIMARY + 短 SECONDARY”，再卸长剑证明 secondary 不晋升，最后通过显式合法序列令短剑成为 PRIMARY。下一名存活 bandit 通过真实 world combat initiation 与 `process_cadence_tick()` 进入现有 attack composition；返回的实际 `CombatAttackCalculation.base_apply_damage` 为 `15`。世界仍保持加载，第三名 bandit 仍存在。

fresh scene/reset 边界重新创建 prototype 长剑 PRIMARY、三名 bandit、零 corpse、零 acquired short/silver，并关闭 Loot/Inventory panel；下一次 resolver 恢复 long `25`。

## Godot AI / MCP

Godot AI 4.7.2 会话先读取了当前 112-node Old Pine hierarchy 和 HUD/Loot panel 布局。工具随后实际创建 InventoryButton 与十节点 PlayerInventoryPanel 子树、设置 layout、附加脚本、连接五条持久化 typed signals、扩展 StatusPanel 宽度、保存场景，并在实现后强制 reload/层级与 signal 复核。最终场景共 123 个持久化节点。

## 直接复核的 LPC

- `reference/es2/mudlib/cmds/std/wield.c`
- `reference/es2/mudlib/cmds/std/unwield.c`
- `reference/es2/mudlib/feature/equip.c`
- `reference/es2/mudlib/std/equip.c`
- `reference/es2/mudlib/d/oldpine/obj/long_sword.c`
- `reference/es2/mudlib/d/oldpine/obj/short_sword.c`

实现继续复用 Phase 8B1 已核实的 Old Pine item content 与 corpse Take 边界，没有重新解释 `get.c`、combined/currency 或 death/corpse Core。

## 正式审计结果

正式审计未发现 Phase 8B2 production 规则错误，也没有修改 Inventory、Equipment、Combined Stack、Combat、Corpse 或 Character Core。审计逐行确认：投影只枚举 live direct children；index 仅作 metadata lookup；Wield/Unwield 最终调用既有 `EquipmentState`；unsupported primary 在 controller 层不生成 player combat binding，因此不会静默回退为空手；`CombatSliceContentProfile` 的默认长剑和普通 verified-weapon 合同保持不变，只有精确的 empty IDs + damage 0 能启用 unarmed-only seam。

审计补强了以下缺失证据：root-owned nested item 拒绝、stale/missing/mismatched primary、stale dynamic Wield/Unwield row、重复 UI refresh 无重复连接、amount-8 银子 survivor 投影、非 ACTIVE 时已有 row 仍不能绕过 gate、战斗关系已建立后换短剑且下一 opportunity 实际使用 damage 15、controller 层 unsupported primary 不建立关系且零 RNG，以及 Phase 7B1 明确纳入聚焦 runner。

完整 runner 首次运行暴露了一个测试确定性缺口：既有完整场景测试序列可能在尸体 physics frame 后投递重叠 zone callback，使第二场战斗前的 logical zone 偶发不是 `south_slope`。测试现在在第二场 initiation 前显式经过 production SouthSlope zone-entry adapter，固定 world-location 前提；没有直接写 location、关系或 combat state。修正后 Phase 8B2 聚焦回归为 **3822 assertions PASS**，完整项目套件为 **7336 assertions PASS**。

Godot AI/MCP 从磁盘执行 save → force reload 后再次读取到 123 个持久化节点；Inventory panel、Scroll、Inspect、Close、六个主操作按钮与五条业务 signal 均存在且无重复，panel 位于当前 960×600 Overlay 内。MCP 实际启动并停止主项目，`was_running=true` 且当前 run 没有项目错误；game helper 仍未在等待窗口内回连。Godot 4.7.2 headless editor、显式 Old Pine scene 与 main scene 均以 exit 0 完成。

**Phase 8B2 正式关闭。Phase 8B 正式关闭。第一条完整 RPG loot loop 正式关闭。** 这不表示完整 Inventory、Take All、Drop、Armor/Wear、persistence 或最终 UI 已完成。

## 明确延期

- Take All、Drop、Put/Give；
- Wear/Remove 与 Armor UI；
- save/persistence 与跨 scene inventory；
- universal ItemCatalog、通用 item component/callback framework；
- weapon swap/make-primary convenience action；
- Phase 5B4 authored combat hooks、最终战斗平衡；
- 最终 UI art、drag/drop、grid、sort/filter、比较面板与快捷键。
