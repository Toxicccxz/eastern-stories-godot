# Phase 4A2：装备驱动的技能学习策略接线

## 范围与结论

本阶段只把已关闭的 `CharacterState.equipment` 只读事实接入既有
`SkillLearnPolicyRegistry`。12 个原先只因武器引用/类型不可用而阻断的 active
`valid_learn()` hook 现已完整可执行；`LearnService` 的调用顺序及
`EquipmentState` 本身均未修改。

45 个显式 active hook 的当前分类为：**42 个完整可执行 + 2 个 gender 阻断 + 1 个
legacy 缺陷阻断**。两个 gender 阻断项是 `stormdance` 与 `tenderzhi`；legacy 缺陷项是
`nine-moon`，它还依赖不存在的 active `nine-moon-force` 权威来源。另有 25 个继承
`std/skill.c` 默认允许的已知 active 技能，仍由注册表显式登记；未知 ID 仍不自动取得
默认策略。

## 直接复核的 LPC 来源

共同调用、技能与装备语义：

- `reference/es2/mudlib/cmds/std/learn.c`
- `reference/es2/mudlib/feature/skill.c`
- `reference/es2/mudlib/std/skill.c`
- `reference/es2/mudlib/feature/equip.c`
- `reference/es2/mudlib/std/weapon/sword.c`
- `reference/es2/mudlib/std/weapon/whip.c`
- `reference/es2/mudlib/include/weapon.h`
- `reference/es2/mudlib/include/globals.h`

逐文件重查的 authored hook：

- `daemon/skill/bloodystrike.c`
- `daemon/skill/celestrike.c`
- `daemon/skill/deisword.c`
- `daemon/skill/fonxansword.c`
- `daemon/skill/liuh-ken.c`
- `daemon/skill/meihua-shou.c`
- `daemon/skill/mystsword.c`
- `daemon/skill/six-chaos-sword.c`
- `daemon/skill/snowshade-sword.c`
- `daemon/skill/snowwhip.c`
- `daemon/skill/spicyclaw.c`
- `daemon/skill/stormdance.c`
- `daemon/skill/tenderzhi.c`
- `daemon/skill/ts-fist.c`
- `daemon/skill/nine-moon.c`

以上 `daemon/skill/` 路径均相对于 `reference/es2/mudlib/`。

## 装备事实与策略原语

策略只读取两个窄事实：

1. `EquipmentState.are_both_hands_empty()`：精确表示 legacy `weapon` 与
   `secondary_weapon` 两个引用均为空；不读取盾牌、护甲、穿戴物或 inventory。
2. `is_primary_hand_empty()` 与 `primary_weapon_skill_type()`：只表示 legacy
   `weapon` 引用及其 `query("skill_type")`；完全忽略副武器类型。

新增两个 typed、无状态 policy primitive：

- `RequireBothWeaponRefsEmptySkillLearnPolicy`
- `RequirePrimaryWeaponSkillTypeSkillLearnPolicy`

前者以 `WEAPON_REFERENCES_NOT_EMPTY` 区分武器引用占用；后者以
`PRIMARY_WEAPON_MISSING` 和 `PRIMARY_WEAPON_SKILL_TYPE_MISMATCH` 区分主引用缺失与
类型错误，并通过 typed `actual_id/required_id` 保存类型证据。没有 LPC 文本、通用
`Dictionary` payload、条件解释器或 ID switch。

policy 不取得 `EquippedWeaponRef`，不修改装备，也不把装备事实复制成
`CharacterState` 的额外布尔字段。`EquipmentState` 不依赖 Learn 或任何技能 ID。

## 解锁的 12 个 hook 与验证顺序

| skill ID | 原始短路顺序 |
|---|---|
| `bloodystrike` | 两个武器引用均空 |
| `celestrike` | 两引用均空 → raw `celestial >= 20` → `max_force >= 100` |
| `deisword` | `max_force >= 50` → 主武器 `skill_type == sword` |
| `fonxansword` | `max_force >= 50` → mapped `force == fonxanforce` → 主剑 |
| `liuh-ken` | 两个武器引用均空 |
| `meihua-shou` | 两个武器引用均空 |
| `mystsword` | raw `mystforce >= 30` → `max_force >= 100` → 主剑 |
| `six-chaos-sword` | `max_force >= 100` → 主剑 |
| `snowshade-sword` | `max_force >= 50` → mapped `force == snowshade-force` → 主剑 |
| `snowwhip` | `max_force >= 150` → 主武器 `skill_type == whip` |
| `spicyclaw` | 两引用均空 → `max_force >= 80` |
| `ts-fist` | 两引用均空 → `max_force >= 80` |

复合规则继续使用既有 `OrderedSkillLearnPolicy`，每一步沿用 Phase 3C2 的 raw、mapped
及 `max_force` typed primitive。返回第一个失败结果，不提前计算或报告后续门槛。

## secondary-only 与开放类型语义

Phase 4A1 已证明“主空、副在”是正常可达状态；本阶段测试直接通过正常
`wield/unwield` 转移构造该状态：

- 对空手规则，它失败，因为 `secondary_weapon` 非空；
- 对剑/鞭规则，它以 `PRIMARY_WEAPON_MISSING` 失败；
- 不会把副武器提升为主武器，也不读取副武器 `skill_type`。

主武器类型继续使用开放 `StringName`。`sword`/`whip` 精确匹配；空字符串、自定义类型
和其他已知类型均作为类型不匹配。主剑外加任意副武器仍通过只检查主类型的剑法规则。

## 注册表与 LearnService 边界

`register_active_legacy_policies()` 仍显式注册全部 45 个覆盖；12 个装备 hook 现由真实
policy/有序组合替代 dependency placeholder。阻断项仍显式注册：

- `stormdance`：`GENDER_STATE_UNAVAILABLE`；
- `tenderzhi`：原始第一项是 gender，因此即使装备事实存在仍返回
  `GENDER_STATE_UNAVAILABLE`，不先评价空手；
- `nine-moon`：保持 `LEGACY_REQUIRED_SKILL_MISSING`，不因主剑事实可表达而改为可执行。

`register_known_legacy_policies()` 仍在上述 45 项之外加入 25 个明确的 inherited
default。两个 registry 各自创建独立 policy 实例；未知 skill ID 仍无策略。

`LearnService` 没有装备分支。它仍在教师技能、prevention 和学生/教师 raw 比较之后，
成本、raw-zero 写入、potential、教师 sen、学生 gin 与 `improve_skill()` 之前调用
`SkillLearnPolicy.evaluate()`。端到端测试证明装备拒绝会在此处停止，不创建 raw-zero
entry、不扣 potential、不支付教师 sen、不伤害学生 gin，也不调用
`improve_skill()`；满足 `deisword` 装备与 `max_force` 条件时可完成原有正常 Learn
路径。审计另以 `bloodystrike` 证明空手型策略也可完成同一 Learn 路径；两条成功路径都
产生原有 typed improvement/effect 结果，不绕过既有 progression 层。

## 审计补强

Phase 4A2 复核没有发现生产策略的公式、短路顺序或依赖方向错误。补充测试覆盖了此前
证据不足、但由 Phase 4A1 正常转移可达的状态：带 `SECONDARY` 标记的主武器、双手主
武器，以及 LPC 遗留转移可形成的“双手主武器 + 副武器”组合。学习策略只读取当前两个
引用和主武器开放 `skill_type`，不会自行解释这些装备标记。

同时新增以下可追溯边界证明：主鞭加任意副武器；`deisword`、`mystsword`、
`six-chaos-sword`、`snowwhip` 在精确 `max_force` 门槛处的缺主武器/错误类型组合；
`fonxansword` 与 `snowshade-sword` 的 mapped ID 仍存在但 raw 目标已删除时仍按 LPC 只
比较映射身份；策略评价前后装备引用保持不变。注册表测试独立核实 45/42/2/1、25、70
及未知 ID 拒绝，不从实现循环或注册表内部数据反推预期集合。

## 遗留缺陷、歧义与阻断

- `tenderzhi` 的顺序是 female gender → 两引用均空。gender 尚不存在，不能用装备结果
  代替第一项，也不能把它降级成普通装备 rejection。
- `nine-moon` 的顺序是 female gender → `max_force >= 50` → mapped
  `nine-moon-force` → 主剑。全 mudlib 仍没有 active
  `daemon/skill/nine-moon-force.c`；本阶段没有发明、替换或修复该 ID。
- `nine-moon.c::skill_improved()` 读取另一个不存在的 `nine-moon-sword` raw ID，是既有
  Phase 3B3 记录的独立缺陷；与本阶段准入接线无关。
- LPC 允许 dbase 临时状态被任意写坏；native policy 只支持 Phase 4A1 正常转移可达的
  typed 状态，不重建损坏 dbase 兼容面。

## 明确延期

Inventory、get/drop/move、物件 ownership、Armor/盾牌系统、装备 modifiers、武器伤害与
攻击、Combat、gender、NPC/World runtime、study、UI、批量物品迁移及
`nine-moon-force` 修复全部延期。本阶段没有引入 Node、SceneTree、Timer、场景、表现或
运行时调度依赖。
