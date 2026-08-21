# Phase 4A1：最小装备与手持状态基础

## 范围与结论

本阶段只迁移 `valid_learn()` 当前需要的武器手持事实，以及
`feature/equip.c` 已确认的最小确定性转移。未建立 Inventory、Armor、Combat、UI、
世界物件或 LPC `query/set/query_temp` 兼容层。

原实现并不是常规 RPG 的“左右手”：角色临时状态保存 `weapon`（主武器）与
`secondary_weapon`（副武器）两个对象引用，物件另有 `equipped == "wielded"` 标记。
Godot 侧把权威槽位集中到 `EquipmentState`，以稳定实例 ID 和定义快照代替 LPC 对象
引用；不复制双边 dbase 状态。

## 检查的 LPC 来源

核心装备、命令与角色依赖：

- `reference/es2/mudlib/feature/equip.c`
- `reference/es2/mudlib/cmds/std/wield.c`
- `reference/es2/mudlib/cmds/std/unwield.c`
- `reference/es2/mudlib/std/item.c`
- `reference/es2/mudlib/std/equip.c`
- `reference/es2/mudlib/std/char.c`
- `reference/es2/mudlib/feature/dbase.c`
- `reference/es2/mudlib/feature/move.c`
- `reference/es2/mudlib/feature/attack.c`（只确认主武器消费边界）
- `reference/es2/mudlib/cmds/std/get.c`（只确认移动/持有关系边界）
- `reference/es2/mudlib/doc/mudlib/feature/equip`
- `reference/es2/mudlib/include/weapon.h`
- `reference/es2/mudlib/include/armor.h`
- `reference/es2/mudlib/std/armor/shield.c`
- `reference/es2/mudlib/cmds/std/wear.c`
- `reference/es2/mudlib/cmds/std/remove.c`

仓库不存在单一的 `std/weapon.c`；实际武器基类位于：

- `reference/es2/mudlib/std/weapon/axe.c`、`blade.c`、`dagger.c`、`fork.c`
- `reference/es2/mudlib/std/weapon/hammer.c`、`staff.c`、`sword.c`
- `reference/es2/mudlib/std/weapon/throwing.c`、`whip.c`
- 上述目录中的 `_axe.c`、`_blade.c`、`_dagger.c`、`_fork.c`、`_hammer.c`、
  `_staff.c`、`_sword.c`、`_whip.c` 组合包装文件

为确认 authored flags，另检查：

- `reference/es2/mudlib/d/goathill/obj/hand_axe.c`
- `reference/es2/mudlib/d/goathill/obj/sledge_hammer.c`
- `reference/es2/mudlib/d/oldpine/obj/short_sword.c`
- `reference/es2/mudlib/d/snow/obj/lumber_axe.c`
- `reference/es2/mudlib/d/goathill/npc/bandit_leader.c`
- `reference/es2/mudlib/d/goathill/npc/bandit_hwang.c`
- `reference/es2/mudlib/obj/example/chicken_leg.c`

重新逐个检查的学习钩子：

- `reference/es2/mudlib/daemon/skill/bloodystrike.c`
- `reference/es2/mudlib/daemon/skill/celestrike.c`
- `reference/es2/mudlib/daemon/skill/deisword.c`
- `reference/es2/mudlib/daemon/skill/fonxansword.c`
- `reference/es2/mudlib/daemon/skill/liuh-ken.c`
- `reference/es2/mudlib/daemon/skill/meihua-shou.c`
- `reference/es2/mudlib/daemon/skill/mystsword.c`
- `reference/es2/mudlib/daemon/skill/six-chaos-sword.c`
- `reference/es2/mudlib/daemon/skill/snowshade-sword.c`
- `reference/es2/mudlib/daemon/skill/snowwhip.c`
- `reference/es2/mudlib/daemon/skill/spicyclaw.c`
- `reference/es2/mudlib/daemon/skill/tenderzhi.c`
- `reference/es2/mudlib/daemon/skill/ts-fist.c`
- `reference/es2/mudlib/daemon/skill/nine-moon.c`（仅分析装备依赖）

同时全 mudlib 搜索了 `query/set/delete_temp` 对 `weapon`、`secondary_weapon` 的
全部读写，以及 `query/set("skill_type")`、`weapon_prop`、`wielded`、`wield()`、
`unwield()`、`SECONDARY` 与 `TWO_HANDED` 的用法。

## 原始手持语义

### 表示与所有权

- `feature/equip.c` 在角色上写入临时对象引用 `weapon` 和
  `secondary_weapon`；武器对象记录 `equipped = "wielded"`。
- 它们是两个武器引用，不是有左右方向的物理手槽。`weapon` 是主武器/当前攻击与
  技能类型来源，`secondary_weapon` 是第二引用；`include/weapon.h` 的
  `DEFAULT_WEAPON_LIMB == "右手"` 只是默认攻击部位文字，不能证明左右槽模型。
- `wield()` 不检查武器继承或对象路径，只要求物件在 character 环境中且
  `weapon_prop` 是 mapping。因此任意满足该协议的 `F_EQUIP` 物件理论上都可进入两个
  引用；`WeaponDefinition` 在 native 中表示已经由未来内容边界确认可持用的定义，
  不是按 LPC class path 判定。
- `cmds/std/wield.c` 在调用 `wield()` 前拒绝已经装备的物件；底层
  `wield()` 对已装备物件返回成功但不改变槽位。
- 同一对象正常情况下不能同时占两个槽；相同定义的两个不同对象可以分别占槽。
- `feature/move.c` 在移动已装备物件前先 `unequip()`。物件持有、移动与跨角色所有权
  属于后续 Inventory 阶段，本阶段只使用稳定运行时实例 ID。

### 主副手与顺序

`feature/equip.c` 的实际选择顺序如下：

| 当前状态/新武器 | 结果 |
|---|---|
| 主武器空；新武器为单手 | 始终成为主武器，即使带 `SECONDARY` |
| 主武器已占；副武器空；新武器带 `SECONDARY` | 新武器成为副武器 |
| 主武器已占且带 `SECONDARY`；副武器空；新武器不带 `SECONDARY` | 旧主武器先卸下，新武器成为主武器，旧主武器再成为副武器 |
| 主武器与新武器均不能作副武器 | 拒绝，要求先卸主武器 |
| 副武器已占，或盾牌已装备，再尝试第二把单手武器 | 拒绝，无空手 |
| 卸下主武器且副武器仍在 | 主位保持空；不会自动提升副武器 |
| 主空、副在时再持单手武器 | 新武器进入主位，副位不变 |
| 旧主同时带 `TWO_HANDED | SECONDARY`，再持非副手武器 | 旧主先卸下，新武器成为主；旧主重持因主位已占而失败，且失败被外层忽略，副位为空 |

因此持用顺序会影响主/副 designation，且“仅副武器存在”是合法可达状态。

没有任何技能或角色属性作为双持前置。第二引用只要求副位为空、盾牌为空，并且新武器
带 `SECONDARY`，或旧主武器带 `SECONDARY` 而可按上述顺序换位。

### 精确调用和 mutation 顺序

- 命令层先要求物件在角色 inventory 中，并拒绝已有任意 `equipped` 标记的物件。
- `feature/equip.c::wield()` 再检查 environment 是 character、已有标记、
  `weapon_prop` mapping、flag 与槽位。
- 普通成功先写角色武器引用，再加 `weapon_prop`、调用 `reset_action()`，最后写物件
  `equipped = "wielded"`。
- 换主武器时依次执行：旧主 `unequip()` → 写入新主引用 → 尝试旧主 `wield()` →
  加新武器属性 → reset action → 标记新武器。旧主重持的返回值没有检查。
- 标准验证失败发生在该次调用的槽位/属性 mutation 前；上表“组合 flag 重持失败”是
  唯一确认的内部失败后仍由外层返回成功的边界。
- `unequip()` 由物件 identity 发起。对 `wielded` 物件先按 identity 删除主引用，
  否则删除副引用；不会提升或重排。然后 reset action、减去物件属性，最后删除
  `equipped` 标记。Phase 4A1 只迁移引用转移，属性、action reset 和物件 marker 延后。

### 双手与盾牌的旧版边界

`include/weapon.h` 定义 `TWO_HANDED = 1`、`SECONDARY = 2`。双手武器只在其
持用瞬间检查主武器、副武器和盾牌都为空，随后仅写入主武器引用，并不占用或标记
副武器槽。因此旧代码允许之后再把带 `SECONDARY` 的武器放入副位；本阶段原样保留，
不按现代 RPG 常识修正。

盾牌会阻止首次持用双手武器以及增加副武器，但不会阻止在空主位持用第一把单手
武器。Phase 4A1 没有 ArmorState；`wield()` 只接收一次操作时的窄型
`shield_equipped: bool` 投影，以保留已证实的转移规则。

## `skill_type` 语义

标准武器基类在初始化/setup 时直接写入 `skill_type` 字符串；它不是由对象路径、对象
identity 或继承检查动态推导。全库 `set("skill_type")` 搜索只发现这些标准基类，当前
内容值为：`axe`、`blade`、`dagger`、`fork`、`hammer`、`staff`、`sword`、
`throwing`、`whip`，未发现 authored override。但 dbase/持用协议本身不保证该字段存在，
也不限制未来/custom 值。Godot 侧因此使用开放的 `StringName`；空值与未知值都可保存，
不使用封闭 enum。与现有 `SkillIds` 相同的已知基本技能只共用其稳定字符串值。

13 个 Category C 钩子的武器类型判断只读取主武器的 `query("skill_type")`；没有读取
副武器类型。空手钩子则同时检查两个武器引用。盾牌和其他穿戴物不参与这些检查。

## Godot 原生模型

- `WeaponDefinition`：只含稳定武器 ID、`skill_type`、`SECONDARY` 能力、
  `TWO_HANDED` 事实及旧源路径。公开属性只读；不含伤害、价格、重量、耐久、表现或
  攻击动作。
- `EquippedWeaponRef`：稳定运行时实例 ID，加上从 definition 复制出的上述标量快照；
  不保留 Inventory instance 或 Node 引用。GDScript 的下划线字段只具约定式私有性，
  因此 `EquipmentState` 在写入和返回时都再复制标量快照；修改调用方对象或查询结果
  不能静默改变内部槽位。
- `EquipmentState`：角色拥有的两个可空 typed ref；提供窄查询与确定性
  `wield/unwield`。没有可变槽位集合或通用属性 Dictionary。没有当前来源需求的
  “副武器 skill_type”公开 API。
- `EquipmentTransitionResult`：返回明确 outcome、`succeeded`、`changed`、请求的稳定
  实例 ID、受影响槽位，以及换主时的旧主实例 ID；领域层不输出 LPC 命令文字或通用
  mutation payload。
- `CharacterState.equipment`：每个角色默认创建独立 `EquipmentState`，也允许测试或
  组装时显式注入；没有共享默认实例。

`are_both_hands_empty()` 特指两个旧武器引用均为空，而不是“角色完全没有任何穿戴”。
这是所有相关 `valid_learn()` 钩子的实际语义。

### Native identity 与无效输入

`weapon_id` 是稳定 definition ID，`instance_id` 是该运行时物件实例的稳定 ID；二者都
不是 LPC 文件路径、显示名或 Godot Node ID。旧源路径只保留在 migration metadata。
Phase 4A1 没有 ItemDefinition repository，因此“是否具有 LPC `weapon_prop` mapping”
由未来定义转换/验证边界负责；一旦构造 `WeaponDefinition`，EquipmentState 只处理
已验证的可持用定义。缺失稳定 definition/instance ID 的 native ref 会在任何槽位
mutation 前返回 `INVALID_WEAPON_REFERENCE`。空或自定义 `skill_type` 不会被误判为无效。

## Phase 3C2 兼容矩阵与源检查顺序

| 钩子 | 主/副读取 | 装备事实 | 完整 `valid_learn()` 顺序 | 当前状态 |
|---|---|---|---|---|
| `bloodystrike` | 两者 | 两引用均空 | equipment only | 仍 deferred |
| `celestrike` | 两者 | 两引用均空 | equipment → raw `celestial >= 20` → `max_force >= 100` | 仍 deferred |
| `deisword` | 仅主；副忽略 | 主存在且 `sword` | `max_force >= 50` → primary sword | 仍 deferred |
| `fonxansword` | 仅主；副忽略 | 主存在且 `sword` | `max_force >= 50` → mapped force `fonxanforce` → primary sword | 仍 deferred |
| `liuh-ken` | 两者 | 两引用均空 | equipment only | 仍 deferred |
| `meihua-shou` | 两者 | 两引用均空 | equipment only | 仍 deferred |
| `mystsword` | 仅主；副忽略 | 主存在且 `sword` | raw `mystforce >= 30` → `max_force >= 100` → primary sword | 仍 deferred |
| `six-chaos-sword` | 仅主；副忽略 | 主存在且 `sword` | `max_force >= 100` → primary sword | 仍 deferred |
| `snowshade-sword` | 仅主；副忽略 | 主存在且 `sword` | `max_force >= 50` → mapped force `snowshade-force` → primary sword | 仍 deferred |
| `snowwhip` | 仅主；副忽略 | 主存在且 `whip` | `max_force >= 150` → primary whip | 仍 deferred |
| `spicyclaw` | 两者 | 两引用均空 | equipment → `max_force >= 80` | 仍 deferred |
| `tenderzhi` | 两者 | 两引用均空 | gender 女性 → equipment | gender 仍不可用 |
| `ts-fist` | 两者 | 两引用均空 | equipment → `max_force >= 80` | 仍 deferred |

测试另证明模型能区分：双空、仅主、仅副、双占、主剑、主鞭、主非剑/鞭，以及副武器
存在。`nine-moon` 的主剑事实也能表达，但仍被 gender 与缺失的
`nine-moon-force` 权威技能 ID/daemon 阻塞；本阶段未尝试修复。
其源顺序为 gender 女性 → `max_force >= 50` → mapped force
`nine-moon-force` → primary sword。

## 遗留怪异点、缺陷与边界

- 双手武器不占副武器引用，导致可追加 `SECONDARY` 武器；按源代码保留。
- 卸主武器不会提升副武器；按源代码保留。
- 第一把带 `SECONDARY` 的武器仍进入主位；随后持不带 `SECONDARY` 的武器会触发
  旧主换到副位；按源代码保留。
- `flag` 是 bitmask；若旧主同时含 `TWO_HANDED|SECONDARY`，换主过程会先卸旧主，
  但旧主重持因主位已占而失败，外层仍成功。native 以独立 typed outcome 保留。
- 源实现同时在角色与物件维护装备标记。Godot 侧以 `EquipmentState` 单点拥有槽位，
  避免复制易失配的 dbase 双写；这是运行时架构替换，不改变已实现的转移结果。
- 没有 Inventory ownership 时，领域本身不能证明同一实例 ID 未被另一个角色状态引用。
  当前仅保证单个 `EquipmentState` 内不重复；跨角色归属必须由后续物品转移边界负责。
- LPC 的 unrestricted `set_temp()` 可制造同一对象同时出现在两个引用、引用与物件
  `equipped` marker 不一致、或非对象值等损坏状态。正常 `wield/unwield` 路径不会这样
  做。Native 不开放 raw 状态写入，也不尝试兼容这些 dbase 损坏形状；它保留正常路径
  可达的 secondary-only 等非对称状态。
- `std/armor/shield.c` 的属性命名/检查存在可疑不一致，但与本阶段武器槽事实无关，未
  修正也未迁移。

## 明确延后

- Inventory container、get/drop/move、重量、容量、stack、currency、shop、loot。
- Item instance 生命周期、跨角色 ownership、存档/import、authoring pipeline。
- Armor/穿戴槽、盾牌状态来源、armor 计算。
- 武器伤害、`weapon_prop` 数值、攻击动作、combat bonus、`reset_action()` 消费。
- UI、Node/Scene/World item、文本命令与表现。
- 13 个 Category C `SkillLearnPolicy` 的真正接线；gender、`tenderzhi` 完成、
  `stormdance` 和 `nine-moon`。

## Phase 4A2 接线需求

Phase 4A2 可把 `EquipmentState` 作为 Learn 输入的窄只读事实来源，并按各 LPC 钩子的
原验证顺序读取：空手政策只需 `are_both_hands_empty()`；剑/鞭政策只需主武器
`skill_type`。不得让 Equipment 依赖 Learn，也不应让政策取得可变槽位。

若 Phase 4A2 仍不建立 Armor，只需传递装备快照/查询接口；不要为 `valid_learn()`
引入 Inventory。`tenderzhi`、`stormdance` 与 `nine-moon` 的非装备依赖继续延后。
