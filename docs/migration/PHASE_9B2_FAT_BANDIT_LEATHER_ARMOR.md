# Phase 9B2：胖土匪、皮衣与穿脱闭环

## 范围与权威来源

本阶段只迁移旧松林 `pine1` 的胖土匪和皮衣所需的首个护甲闭环。行为依据：

- `reference/es2/mudlib/d/oldpine/npc/fat_bandit.c`
- `reference/es2/mudlib/d/oldpine/obj/leather.c`
- `reference/es2/mudlib/d/oldpine/npc/obj/leather.c`
- `reference/es2/mudlib/std/armor/cloth.c`
- `reference/es2/mudlib/feature/equip.c`
- `reference/es2/mudlib/std/equip.c`
- `reference/es2/mudlib/cmds/std/wear.c`
- `reference/es2/mudlib/cmds/std/remove.c`
- `reference/es2/mudlib/d/oldpine/obj/short_sword.c`
- `reference/es2/mudlib/obj/money/silver.c`
- `reference/es2/mudlib/std/money.c`
- `reference/es2/mudlib/std/char/npc.c`

另检查了 `std/item.c`、`feature/name.c`，并只做了证明援军可达性所需的最小 `bandit_chief` / `call_for_help` 搜索。不存在 `std/armor.c`；实际相关继承是 `std/armor/cloth.c -> EQUIP`。

## 胖土匪基线

`fat_bandit.c` 的原样事实为：名称“土匪”，别名 `bandit`，人类男性，36 岁，`combat_exp=500`，`score=80`，主动攻击；技能为 `sword=20`、`parry=10`、`dodge=10`；携带并主手持有短剑一把、穿皮衣一件、持银子五两。未增加基础属性、资源覆盖、内功或特殊伤害。

原 NPC 的 `call_for_help()` 虽存在，但对象写入的是 `chat_chance=10` 和 `chat_msg_combat`，`std/char/npc.c` 的战斗聊天路径读取的是 `chat_chance_combat`。泥库内没有正常外部调用令其可达。因此本阶段没有修复拼写、没有生成寨主，也没有建立伪“延期 hook”。若未来要恢复预期援军，必须另作兼容性决策。

## 规范皮衣内容

两个旧松林皮衣文件视为同一语义定义，原路径均保留为追溯元数据：

- native definition ID：`es2:d/oldpine/obj/leather`
- 名称：`皮衣`
- 旧运行时默认 long：`皮衣(Leather)。\n`
- 重量：`6000`
- 分类：`armor`
- 开放槽 ID：`cloth`
- `armor=+5`
- `dodge=-2`

`dodge=-2` 是可执行旧行为：`cloth.c` 检查 `armor_apply/dodge`，而皮衣没有该键；重量严格大于 3000 时写入 `armor_prop/dodge = -weight()/3000`，故 `6000/3000=2`。没有把它“修正”为更美观的数值。

## NPC WEAR 组合接缝

`NpcLoadoutItemDefinition` 可携带只读快照式 `ArmorDefinition`。`NpcCharacterStateFactory` 为每个 NPC 建立独立 `ArmorState`，并严格按以下顺序处理 `WEAR`：解析内容、创建唯一 `ItemInstance`、注册、转移到 NPC 直接背包、解析并核对护甲定义身份、调用既有 `ArmorService.wear()`、最后记录运行时物品身份。工厂没有直接写护甲槽，也没有复制 Armor Core 规则。

工厂仍是顺序式一次性组合器而非事务框架。注册或转移已经成功后若护甲缺失、定义不匹配或槽位冲突，构造返回失败，但先前注册/转移不会回滚；容量拒绝发生在注册之后、转移之前。测试明确锁定这些部分变更。原 `WIELD_PRIMARY`、`NONE`、合并货币和 NPC 初始化随机顺序不变。

## 运行时与战斗权威

胖土匪固定生成于 `Pine Entrance` 的持久 `Marker2D`，运行时顺序为三个探哨、Tall、Fat。Tall 与 Fat 各自拥有独立的角色、关系、忙碌、装备、护甲和物品实例。两者的 Presence 可重叠，待处理攻击仍按 map-local 插入顺序确定性解析；没有增加 AI、计时器、群体规则或求援系统。

胖土匪的皮衣同时满足：直接父级是 `CHARACTER(fat)`，`ArmorState` 的 `cloth` 槽指向同一 `ItemInstanceId`。现有 `CombatSliceProjectionBuilder` 每次从当前 `ArmorState.aggregate_numeric_modifiers()` 建立输入：皮衣在身时防御输入为 `armor=5`，`dodge` 对有效技能贡献 `-2`；移除后下一次投影立即不再包含它。短剑攻击仍使用现有伤害 15，护甲没有进入武器解析器。

死亡事实生成只为当前 authored item 解析对应 `ArmorDefinition`，以便既有死亡/尸体服务执行原有“先脱离受害者护甲，再在新鲜尸体上保留 worn 投影”的语义。没有修改 Corpse Core。成功死亡后尸体直接包含同一短剑、皮衣和银子五两；新鲜尸体 `cloth` worn 投影指向皮衣。单件 Take 先释放该投影，再把同一物品实例转移给玩家，不会自动穿戴。

## 玩家库存与穿脱

玩家库存投影增加独立 `WORN` 状态和只读护甲事实。皮衣 Inspect 显示名称、旧 long、`cloth`、`Armor +5`、`Dodge -2` 和当前穿戴状态。武器仍只显示 Wield/Unwield，银子仍只有 Inspect。

`OldPineArmorInteractionAdapter` 是窄运行时边界。Wear 重新验证请求、玩家存在且已提交 ACTIVE、物品注册且为玩家直接子项、内容与护甲定义身份一致，然后调用 `ArmorService.wear()`；Remove 也重新解析实时物品与规范护甲定义，核对定义身份和该定义所声明槽位中的精确实例引用，再调用 `ArmorState.remove()`。这避免过期实例请求移除同槽中的替代护甲。两者均返回 typed result 并触发完整投影刷新。没有新增战斗中禁止穿脱或 busy 规则，因为 `wear.c` / `remove.c` 没有这些限制；Remove 不移动物品。

穿戴玩家皮衣后，下一份世界战斗 defender input 读取 `armor=5` 和 `dodge=-2`；同场景 Remove 后下一份输入恢复无护甲值。Inspect、投影、Take、Wear、Remove 均不消耗 Combat RNG 或 NPC 初始化 RNG。

## Godot 场景与验证

通过 Godot AI/MCP 在现有场景中添加并保存 `Pine1FatBanditSpawn`、`FatBandit` 及其 Presence，随后强制从磁盘重载。场景总计 180 个节点；Fat 的 marker 与 body 均固定在 `(-200, 400)`，位于 Pine Entrance、与 Tall 不重合，也不与 `EntranceNorth` 障碍碰撞或阻塞已关闭的迷宫路径。Fat selection、presence enter/exit 以及 Inventory 的 Wear/Remove 各只有一个持久连接。编辑器内实际启动了当前场景，未产生本次运行的新脚本错误；Godot 4.7.2 的定向、Old Pine 场景、主场景和 headless editor 验证均通过。

## 正式审计修正

正式审计发现并修正两项具体问题：初始 Fat marker/body `(-300, 100)` 与 `EntranceNorth` 碰撞体重叠，改为经几何和物理回归验证的 `(-200, 400)`；Remove 原先只检查实例是否出现在任意护甲槽，现按实时内容重新核对定义身份与期望槽位，拒绝过期实例移除同槽替代品。没有修改关闭的 Armor、Equipment、Inventory、Combat、Character 或 Skill Core。

审计测试补齐独立皮衣公式、胖土匪人类初始化边界、NPC WEAR 部分失败、双 Presence 确定性顺序、实际普通攻击读写、尸体 worn 释放后容量失败不回滚、银子合并、玩家战斗中 Wear/Remove、动态 UI 信号唯一性和完整重置。Phase 9B2 聚焦回归为 `3522` 条断言通过；完整项目为 `7960` 条断言通过。

## 部分对等台账

| 内容 | 状态 |
|---|---|
| `fat_bandit` 定义、pine1 放置、普通战斗、完整 loadout、护甲 | COMPLETE |
| `fat_bandit` 援军 | UNREACHABLE-SOURCE-PATH / NOT IMPLEMENTED |
| `fat_bandit` 表现 | MINIMAL |
| `fat_bandit` 可执行基线 | COMPLETE |
| `leather` 规范内容、NPC 穿戴、死亡/拾取、玩家穿脱 | COMPLETE |
| `bandit_chief` | DEFERRED；旧正常聊天路径不可达 |
| wolf / beast | DEFERRED；仍受 Phase 9A 的种族/内容依赖阻塞 |

## 明确延期

寨主援军、狼/兽类、Keep、River、Cave、藤蔓、Phase 5B4、通用战斗聊天、Take All、Drop、护甲比较 UI、最终美术/UI、其他护甲和通用物品目录均未进入本阶段。
