# Phase 4B4：Armor Foundation + Equipment / Inventory Integration

## 范围与结论

本阶段实现纯 typed GDScript 护甲领域基础：不可变 `ArmorDefinition`、开放槽位的
`ArmorState`、数值 `armor_prop` 投影、确定性 wear/remove，以及
`InventoryTransferService` 的 worn detach。没有 Combat、命令/UI、World Node、Catalog、
Repository、持久化、尸体或 authored 护甲数据库。

Armor 与 Inventory 保持分权：`InventoryState` 唯一拥有 parent/root/weight；`ArmorState`
唯一拥有 worn 槽位和由槽位派生的数值 aggregate；`ArmorService` 只验证实例/定义/直接持有并
发起低层穿戴；`InventoryTransferService` 按旧顺序协调卸装与 containment transfer。

## 权威 LPC 来源

逐行复核：

- `reference/es2/mudlib/feature/equip.c`
- `reference/es2/mudlib/std/equip.c`
- `reference/es2/mudlib/feature/move.c`
- `reference/es2/mudlib/include/armor.h`
- `reference/es2/mudlib/include/weapon.h`
- `reference/es2/mudlib/cmds/std/wear.c`
- `reference/es2/mudlib/cmds/std/remove.c`
- `reference/es2/mudlib/cmds/std/wield.c`
- `reference/es2/mudlib/cmds/std/unwield.c`
- `reference/es2/mudlib/std/armor/armor.c`
- `reference/es2/mudlib/std/armor/boots.c`
- `reference/es2/mudlib/std/armor/cloth.c`
- `reference/es2/mudlib/std/armor/finger.c`
- `reference/es2/mudlib/std/armor/hands.c`
- `reference/es2/mudlib/std/armor/head.c`
- `reference/es2/mudlib/std/armor/neck.c`
- `reference/es2/mudlib/std/armor/shield.c`
- `reference/es2/mudlib/std/armor/surcoat.c`
- `reference/es2/mudlib/std/armor/waist.c`
- `reference/es2/mudlib/std/armor/wrists.c`

代表性 authored/custom 来源：

- `reference/es2/mudlib/obj/bandage.c`
- `reference/es2/mudlib/obj/weapon/shield.c`
- `reference/es2/mudlib/obj/prize/black_vest.c`
- `reference/es2/mudlib/d/oldpine/obj/black_suit.c`
- `reference/es2/mudlib/d/oldpine/npc/obj/mask.c`
- `reference/es2/mudlib/daemon/class/dancer/snake_sandal.c`
- `reference/es2/mudlib/d/latemoon/obj/skirt.c`、`skirt4.c`、`skirt5.c`
- `reference/es2/mudlib/d/latemoon/npc/obj/skirt.c`、`skirt4.c`、`skirt5.c`
- `reference/es2/mudlib/obj/magic_seal.c`
- modifier 消费边界：`feature/attribute.c`、`feature/skill.c`、`std/force.c`、
  `adm/daemons/combatd.c`

另对全部 mudlib `.c` 复扫 `armor_type`、`armor_prop`、`armor_apply`、`female_only`、
`armor/*` temp refs、`apply/*`、`equipped`、`worn`、`shield`、`wear()` 和 `unequip()`。

## 活动 armor_type 与开放槽位

`include/armor.h` 定义的 11 个标准值：

`head`、`neck`、`cloth`、`armor`、`surcoat`、`waist`、`wrists`、`shield`、
`finger`、`hands`、`boots`。

活动 authored 额外值：

- `bandage`：`obj/bandage.c`
- `mask`：`d/oldpine/npc/obj/mask.c`
- `feet`：`daemon/class/dancer/snake_sandal.c`、`daemon/class/taoist/shoe.c`

最终活动集合共 14 项。全库没有发现其他 literal 或动态 `armor_type` setter。协议本身仍不限制
未来值，所以 native 使用非空、开放的 `StringName`；不把 `feet` 归一成 `boots`，也不把
`bandage`/`mask` 归入标准槽。测试证明 `boots` 与 `feet` 可同时占用，自定义非空槽同样可用。

## Native 类型与权威状态

`ArmorDefinition` 只含：

- `item_definition_id: StringName`
- `armor_type: StringName`
- `numeric_modifiers: ArmorNumericModifiers` 的不可变快照

它与 `ItemDefinition.item_definition_id` 使用同一稳定身份；不含显示名、aliases、价格、重量、
耐久、回调或 generic Variant mapping。

`EquippedArmorRef` 只含：

- `item_instance_id`
- `item_definition_id`
- 精确 `armor_type`
- 穿戴时的不可变 `ArmorNumericModifiers` 快照

`ArmorState` 私有保存 `armor_type -> EquippedArmorRef`，每个精确槽最多一个实例，并按稳定
instance ID 阻止同一实例占多个槽。查询返回副本，不暴露可变 Dictionary。aggregate 每次从
当前槽位快照派生，因此没有第二份可变 modifier cache；remove 后贡献精确消失，无 clamp。

本阶段没有把 `ArmorState` 加入 `CharacterState`。与现有外置 `InventoryState` 的组装一致，
application/character aggregate 以后可并列持有 Character、Inventory、Equipment 与 Armor；
它们彼此不拥有对方，避免 `InventoryState <-> ArmorState` 循环。

## 数值 modifier 域

完整活动 `armor_prop` 键分类如下：

| 分类 | typed 数值键 | 代表来源 |
| --- | --- | --- |
| Combat | `armor`, `armor_vs_force`, `attack`, `defense`, `dodge` | `black_suit.c`, `black_vest.c`, `bandage.c`, `combatd.c`, `std/force.c` |
| Character attribute | `composure`, `courage`, `intelligence`, `karma`, `personality` | `d/choyin/obj/amulet.c`, `d/goathill/obj/breast_mirror.c`, `d/canyon/npc/obj/hat.c`, `feature/attribute.c` |
| Skill | `magic`, `move`, `spells`, `unarmed` | `d/temple/obj/hat.c`, `d/temple/obj/boots.c`, `daemon/class/taoist/robe.c`, `obj/bandage.c`, `feature/skill.c` |
| Presentation/identity | `id`, `name`, `short`, `long`（arrays） | `d/oldpine/obj/black_suit.c`, `d/oldpine/npc/obj/mask.c`, `feature/name.c` |
| 其他 active | 无 | 全库结构扫描 |

`ArmorNumericModifiers` 对 14 个活动数值键使用显式 `int` 字段。`id/name/short/long` 没有进入
数值结构；未来 importer 必须把它们报告/路由到 authored presentation effect，不能静默丢弃。

Phase 4B0 的跨 equipment 总表曾列出 `spirituality`。本次独立扫描确认它只作为
`weapon_prop/spirituality` 出现在 `daemon/class/taoist/sword.c`，没有活动
`armor_prop/spirituality`，所以未凭空加入 Armor 数值域。类似地，weapon `damage` 仍归武器/
未来 Combat，不属于 Armor aggregate。

## Wear / remove 精确语义

正常新 wear 的 native 顺序对应 `feature/equip.c`：

1. `ArmorService` 验证 ArmorState、ItemInstance 与 ArmorDefinition 身份；
2. 验证 item 是指定 character endpoint 的直接 child（不是 root-owned descendant）；
3. 已由该 ArmorState 穿戴的实例返回成功但 `changed == false`，不重复加值；
4. 新穿戴要求非空 exact slot；
5. exact slot 必须为空；
6. `ArmorState` 写入 immutable ref；该 ref 立即成为 aggregate 的唯一贡献来源。

definition mismatch 在任何 ArmorState mutation 前拒绝。空 slot 是 native construction 边界的显式
typed rejection；没有模拟 LPC 的空字符串 dbase path。底层 LPC 对已有任意 `equipped` marker
直接返回 1；在正常 native 可达状态中，对应 `ALREADY_WORN` success/no-op。

remove 按 instance ID 找到 exact slot，先删除 slot ref；派生 aggregate 因此同时失去其完整
snapshot 贡献。物品 parent、root 与 weight 不变。负 modifier 原值累计和反转，没有 clamp。

LPC item-side `equipped = "worn"` 没有复制到 `ItemInstance`；`ArmorState` 是单一权威。

## Shield 与 Phase 4A1

`shield` 是普通 exact armor slot。权威事实为：

```text
ArmorState.is_slot_occupied(&"shield")
```

没有第二个 `shield_equipped` 状态。现有 `EquipmentState.wield()` 仍消费窄 bool，但集成调用必须
由上述查询投影。Armor 不拥有 Equipment，Equipment 也不拥有 Armor。

源码只在 `wield()` 当下检查盾牌以阻止双手武器或第二武器；`wear()` 不检查现有双手武器。
因此保留非对称怪异点：先持双手武器，再穿盾牌可成功，且不会自动卸下武器。没有发明现代槽位
互斥规则。

全库没有发现一个 active authored 文件同时具有 `armor_prop` 与 `weapon_prop`，也没有同时
设置 armor type 与武器 property 的对象；`obj/weapon/shield.c` 虽位于 weapon 目录，实际只继承
`SHIELD`。所以本阶段不为不存在的 active 双协议物件重构 Equipment API。未来内容验证若允许
双协议定义，外层装备 orchestration 必须按 stable instance ID 保留 LPC 单 marker 的跨类型互斥。

## Inventory transfer 集成

`InventoryTransferService.transfer()` 新增可选的 direct-owner `ArmorState`，并按 stable instance
ID 查询/调用 `ArmorState.remove()`。顺序为：

1. 若 direct character child 正在 hand-equipped，调用 `EquipmentState.unwield()`；
2. 若 exact instance 正在 armor-worn，调用 `ArmorState.remove()`；
3. 解析并验证 destination；
4. 验证 containment/cycle/capacity；
5. 成功才改变 parent。

正常 LPC 一个实例只有一个 `equipped` marker，因此前两项至多一项发生；native 没有用 definition
type 猜测 detach。nested child 不递归卸装；移动进 character 不自动恢复穿戴。

结果保留旧 `equipment_detached` 兼容 union，并新增明确只读字段：

- `weapon_detached`
- `armor_detached`

因此调用方可区分无卸装、手持卸装和护甲卸装。若 worn item 后续遇到 invalid/unavailable
destination、cycle 或 capacity failure：parent 不变，但 slot 与 modifiers 已移除，
`armor_detached == true`，且绝不 rollback。这精确保留 `feature/move.c` 的 detach-before-
destination/capacity partial mutation。成功移到 World 或 carried bag 也先卸装；即使 bag 的 root
holder 仍是同一 character，也因不再是 direct child 而不能保持 worn。

## 源怪异点与 authored hook 延后

- `std/equip.c`：weight `>= 3000` 且没有 `armor_prop/dodge` 时写负 dodge。
- 11 个 `std/armor/*.c`：使用严格 `weight > 3000`，却检查不存在的
  `armor_apply/dodge` 后写 `armor_prop/dodge`。这是可执行 key mismatch；本阶段没有实现或静默
  修正 definition setup/import 公式。
- `obj/bandage.c` 的 `wear()` 固定返回 0；真正 `do_bandage()` 先做伤势、战斗、目标与移动检查，
  再显式 `::wear()`、施加 condition 并增加 blood state。分类为 authored eligibility + post-effect，
  依赖 Condition/动作层，未塞进通用 ArmorState。
- 六份 `d/latemoon/{obj,npc/obj}/skirt{,4,5}.c` 覆盖 `wear()`：以
  `this_player()->gender == "女性"` 为前置，但忽略 `::wear()` 返回值并最终总返回 1。分类为
  authored precondition 加确定性 success-reporting quirk；没有迁移或静默修正。
- `obj/magic_seal.c` 是唯一额外 `unequip()` override，清除 `equipped="sealed"`；它不是 armor/
  hand 槽，属于未来 typed attach effect。
- `cmds/std/wear.c` 的 `female_only` 使用精确 `gender == "女性"`，属于命令 eligibility，未放入
  ArmorState/ArmorService，也没有复制已有 gender 语义。
- black_suit/mask 的数组伪装、bandage condition/autoload/blood、cloth tear、wear/unequip 文本均
  明确延后。

## 明确延后

Combat 及伤害公式、authored Armor definitions/importer、presentation disguise、female-only command
adapter、custom wear policies/effects、Inventory get/drop/give/put adapters、stack 改动、corpse/death、
autoload/save、World/UI/Node、NPC/economy、Catalog/Repository 与 runtime scheduling。

本阶段没有改变已实现的 LPC 可观察行为，不需要更新 `DECISIONS.md`。

## 正式审计结论

正式审计逐行重查 `feature/equip.c`、`feature/move.c`、四个装备命令、全部 11 个
`std/armor/*.c`，并重新全库扫描 `armor_type`、`armor_prop`、`armor_apply`、armor temp
refs、`apply/`、`equipped`、`worn`、`shield`、`wear()` 与 `unequip()`。生产实现未发现
公式、状态权威、依赖方向或转移顺序错误，因此没有修改 production GDScript，也没有新增
兼容性决定。

审计补强了此前证据不足的边界测试：两件具有正、负、零及重叠键的护甲全部移除后 aggregate
精确回到零基线；wear/remove 全程不改变 Inventory weight；合法 endpoint 但 unavailable 的目标
同样在失败前卸甲且不回滚；Bag→Character 与 World→Character 都不自动穿戴。另以明确标注的
malformed native 双协议状态证明 transfer 依次清除 hand 与 armor ref，并分别报告
`weapon_detached`/`armor_detached`；活动 authored 内容没有这种双协议物件，因此该测试不是新玩法，
也没有引入统一 Equipment 子系统。

公开转换仍阻止空 slot、exact-slot collision 与同一 instance 多槽占用。GDScript 下划线成员仅是
约定式私有，因此防御性快照测试继续作为不可变边界的必要证据；没有建立通用损坏状态修复器。
