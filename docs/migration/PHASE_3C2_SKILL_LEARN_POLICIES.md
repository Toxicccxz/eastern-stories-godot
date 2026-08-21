# Phase 3C2：作者技能学习准入策略

> 本文记录 Phase 3C2 关闭时的历史状态。装备依赖接线后的当前分类、12 个新增可执行
> hook 与验证顺序见 `PHASE_4A2_EQUIPMENT_SKILL_LEARN_POLICIES.md`。

## 范围与结论

本阶段重新扫描了 `reference/es2/mudlib/daemon/skill/*.c` 的全部 active
`valid_learn()` 覆盖，确认总数为 **45**。每个 hook 恰好归入一类：

- A：30 个，完整规则只依赖已关闭的 typed character/resource/skill state，已实现；
- B：1 个，只缺窄化的性别事实，明确返回 `DEPENDENCY_UNAVAILABLE`；
- C：13 个，依赖尚未实现的装备/双手状态，明确返回
  `DEPENDENCY_UNAVAILABLE`；
- D：1 个，引用不存在的 active 技能 daemon，按旧缺陷明确阻断。

没有 hook 读取 environment/world、family/faction、当前 gin/kee/sen、当前
force/mana/atman、condition 或 combat state。没有新增这些领域，也没有实现装备、性别
人口学、世界、门派或运行时系统。

审计还逐个枚举了 active `daemon/skill` 的其余定义。另有 **25** 个技能没有覆写
`valid_learn()`，因此继承 `std/skill.c` 的恒允许默认实现：

`axe`、`blade`、`chanting`、`dagger`、`dodge`、`fork`、`hammer`、
`instruments`、`iron-cloth`、`literate`、`magic`、`move`、`music`、`parry`、
`perception`、`spells`、`spider-array`、`staff`、`stealing`、`sword`、
`tao-mystery`、`throwing`、`unarmed`、`whip`、`yirong`。

因此 active skill definition 总数为 **70 = 45 个显式覆写 + 25 个继承默认**。
45 个覆写的 A/B/C/D 数量仍为 **30 + 1 + 13 + 1 = 45**，其中目前可执行
**30** 个。继承默认的 25 个单独报告，不计入显式覆写的分类数。

## 权威来源与依赖

直接检查的共同来源：

- `reference/es2/mudlib/cmds/std/learn.c`
- `reference/es2/mudlib/std/skill.c`
- `reference/es2/mudlib/feature/skill.c`
- `reference/es2/mudlib/feature/attribute.c`
- `reference/es2/mudlib/feature/dbase.c`
- `reference/es2/mudlib/feature/equip.c`
- `reference/es2/mudlib/cmds/std/wield.c`
- `reference/es2/mudlib/std/weapon/sword.c`
- `reference/es2/mudlib/std/weapon/whip.c`
- `reference/es2/mudlib/include/globals.h`

此外直接读取了下表所列全部 45 个 `daemon/skill/*.c` 中完整的
`valid_learn()` 函数；对 `nine-moon-force` 做了全 mudlib 引用/文件搜索。

`include/globals.h` 证明 `SKILL_D(x)` 固定路由到 `/daemon/skill/`。另行发现
`d/skill/` 下 16 个带显式 `valid_learn()` 的旧副本：`celestial`、`celestrike`、
`chaos-steps`、`fonxanforce`、`fonxansword`、`force`、`gouyee`、`liuh-ken`、
`necromancy`、`pyrobat-steps`、`six-chaos-sword`、`snowshade-force`、
`snowshade-sword`、`spring-blade`、`stormdance`、`taoism`。它们不在当前
`SKILL_D` 路由上，所以不计入 45 个 active hook，也没有拿来覆盖 active 源行为。
除 `std/skill.c` 的定义/注释外，其他 `valid_learn` 提及只出现在
`cmds/std/learn.c`、`practice.c`、`study.c` 的调用点；未把这些调用、
`practice_skill()`、`valid_effect()`、`skill_improved()` 或动作表误计为 hook。

所有覆盖函数的共同返回约定是：按源顺序遇到第一项失败即调用 `notify_fail()` 并返回
假；全部通过才返回 `1`。下表的 `eff` 表示不带 raw 参数的
`query_skill(id)`，`raw` 表示 `query_skill(id, 1)`，`mapped` 表示
`query_skill_mapped(use)`。未列出的依赖均未读取。

## 完整 active hook 清单与分类

| skill ID / 精确来源 | 源顺序、状态读取与精确边界 | 类别 / native 处理 |
|---|---|---|
| `bloodystrike` / `daemon/skill/bloodystrike.c` | primary 或 secondary weapon 任一存在即拒绝 | C：装备/双手状态未实现 |
| `bolomiduo` / `daemon/skill/bolomiduo.c` | 无读取，恒返回 1 | A：已实现 |
| `buddhism` / `daemon/skill/buddhism.c` | base `bellicosity > 100` 拒绝；100 允许 | A：已实现 |
| `celestial` / `daemon/skill/celestial.c` | `bellicosity < eff(celestial) * 50` 拒绝；相等允许 | A：已实现 |
| `celestrike` / `daemon/skill/celestrike.c` | 空手 → raw `celestial >= 20` → `max_force >= 100` | C：首项即依赖装备 |
| `chaos-steps` / `daemon/skill/chaos-steps.c` | `max_force < 50` 拒绝 | A：已实现 |
| `cloudstaff` / `daemon/skill/cloudstaff.c` | base `str + max_force / 10 < 50` 拒绝；整数除法 | A：已实现 |
| `deisword` / `daemon/skill/deisword.c` | `max_force >= 50` → primary weapon 必须为 `sword` | C：装备缺失 |
| `essencemagic` / `daemon/skill/essencemagic.c` | eff `buddhism < 10` 或 `buddhism <= essencemagic` 拒绝；第二项要求严格大于 | A：已实现，保留短路顺序 |
| `fall-steps` / `daemon/skill/fall-steps.c` | `max_force < 50` 拒绝 | A：已实现 |
| `fonxanforce` / `daemon/skill/fonxanforce.c` | 无读取，恒返回 1 | A：已实现 |
| `fonxansword` / `daemon/skill/fonxansword.c` | `max_force >= 50` → mapped `force == fonxanforce` → primary `sword` | C：装备缺失 |
| `force` / `daemon/skill/force.c` | 无读取，恒返回 1 | A：已实现 |
| `gouyee` / `daemon/skill/gouyee.c` | `max_mana < eff(gouyee) * 5` 拒绝；相等允许 | A：已实现 |
| `iceforce` / `daemon/skill/iceforce.c` | 无读取，恒返回 1 | A：已实现 |
| `jin-gang` / `daemon/skill/jin-gang.c` | 无读取，恒返回 1 | A：已实现 |
| `jingang-staff` / `daemon/skill/jingang-staff.c` | base `str + max_force / 10 < 50` 拒绝；整数除法 | A：已实现 |
| `juechen-force` / `daemon/skill/juechen-force.c` | 无读取，恒返回 1 | A：已实现 |
| `linbo-steps` / `daemon/skill/linbo-steps.c` | raw `literate < 60` 拒绝；mapping/temporary modifier 不参与 | A：已实现 |
| `liuh-ken` / `daemon/skill/liuh-ken.c` | 任一手持武器存在即拒绝 | C：装备/双手状态未实现 |
| `lotusforce` / `daemon/skill/lotusforce.c` | eff `buddhism < lotusforce` 拒绝；相等允许 | A：已实现 |
| `magic-array` / `daemon/skill/magic-array.c` | eff `tao-mystery <= magic-array` 拒绝；必须严格大于 | A：已实现 |
| `meihua-shou` / `daemon/skill/meihua-shou.c` | 任一手持武器存在即拒绝 | C：装备/双手状态未实现 |
| `mysterrier` / `daemon/skill/mysterrier.c` | mapped `force == mystforce` → eff `music >= mysterrier / 2`；目标先整数除 2 | A：已实现，保留顺序 |
| `mystforce` / `daemon/skill/mystforce.c` | 无读取，恒返回 1 | A：已实现 |
| `mystsword` / `daemon/skill/mystsword.c` | raw `mystforce >= 30` → `max_force >= 100` → primary `sword` | C：装备缺失 |
| `necromancy` / `daemon/skill/necromancy.c` | eff `taoism < necromancy / 2` 拒绝；目标先整数除 2，相等允许 | A：已实现 |
| `nine-moon` / `daemon/skill/nine-moon.c` | `gender == 女性` → `max_force >= 50` → mapped `force == nine-moon-force` → primary `sword` | D：`nine-moon-force` 无 active daemon/source，正常 `set_skill()` 路径不能建立该技能 |
| `notraces` / `daemon/skill/notraces.c` | `max_force < 50` 拒绝 | A：已实现 |
| `pyrobat-steps` / `daemon/skill/pyrobat-steps.c` | 无读取，恒返回 1 | A：已实现 |
| `qidaoforce` / `daemon/skill/qidaoforce.c` | 无读取，恒返回 1 | A：已实现 |
| `scratching` / `daemon/skill/scratching.c` | `max_force < 80` 拒绝 | A：已实现；失败文字称“天师剑法”，代码没有装备检查 |
| `serpentforce` / `daemon/skill/serpentforce.c` | 无读取，恒返回 1 | A：已实现 |
| `shortsong-blade` / `daemon/skill/shortsong-blade.c` | 无读取，恒返回 1 | A：已实现 |
| `six-chaos-sword` / `daemon/skill/six-chaos-sword.c` | `max_force >= 100` → primary `sword` | C：装备缺失 |
| `snowshade-force` / `daemon/skill/snowshade-force.c` | 无读取，恒返回 1 | A：已实现 |
| `snowshade-sword` / `daemon/skill/snowshade-sword.c` | `max_force >= 50` → mapped `force == snowshade-force` → primary `sword` | C：装备缺失 |
| `snowwhip` / `daemon/skill/snowwhip.c` | `max_force >= 150` → primary weapon 必须为 `whip` | C：装备缺失 |
| `spicyclaw` / `daemon/skill/spicyclaw.c` | 空手 → `max_force >= 80` | C：首项即依赖装备 |
| `spring-blade` / `daemon/skill/spring-blade.c` | 无读取，恒返回 1 | A：已实现 |
| `stormdance` / `daemon/skill/stormdance.c` | `gender == 女性` → base `spi >= 20`；读取持久 base 字段，不是 `query_spi()` | B：仅缺窄化 gender state |
| `taoism` / `daemon/skill/taoism.c` | base `bellicosity > 100` 拒绝；100 允许 | A：已实现 |
| `tenderzhi` / `daemon/skill/tenderzhi.c` | `gender == 女性` → 空手 | C：性别加装备，主要系统依赖为装备 |
| `ts-fist` / `daemon/skill/ts-fist.c` | 空手 → `max_force >= 80` | C：首项即依赖装备 |
| `wu-shun` / `daemon/skill/wu-shun.c` | eff `literate < wu-shun` 拒绝；相等允许 | A：已实现 |

## Native policy 架构

`SkillLearnPolicyRegistry` 以稳定 `StringName` skill ID 显式注册全部 45 个 active
hook；完整注册入口还显式加入上列 25 个继承默认的已知 active 技能。它不做文件路径
拼接，不调用 daemon，不把策略塞进 `LearnService` 的 ID switch，未知技能也不会被
猜成默认允许。两个独立 registry 会创建独立 policy 实例。45-hook-only 入口保留给清单
完整性测试，正常已知 legacy 技能查询使用 70 项完整入口。

新增的窄化、可复用 policy primitive：

- 最大 bellicosity；
- `bellicosity >= effective skill * factor`；
- base strength 与 `max_force / divisor` 的组合门槛；
- `max_mana >= effective skill * factor`；
- raw skill 最低门槛；
- effective skill 绝对最低门槛；
- effective prerequisite 对 `effective target / divisor` 的最低比例；
- effective prerequisite 必须严格大于 effective target；
- mapped use 必须等于指定 skill；
- 有序 policy composition，用于 `essencemagic` 和 `mysterrier` 保留源检查顺序。

这些类型只保存固定整数、enum 和稳定 ID，没有自由 `Dictionary` payload、dbase 路径或
可变共享默认实例。`SkillLearnPolicyResult` 返回 typed status、reason、subject ID、
actual/required 数值及 actual/required ID；`LearnResult` 保留该结果供未来表现和诊断，
不保存原 LPC 文本。

审计中移除了原先将“比较方式、可选绝对下限、比例除数”组合在一个类里的通用
effective policy。虽然其计算结果正确，但该形状会逐步演变成小型条件解释器。现在三种
effective 关系各有窄化类型，compound hook 通过有序组合表达，不靠布尔 flag 改写语义。

## raw / effective / mapped 语义

- `linbo-steps` 唯一显式 raw 前置仍调用 `raw_level(literate)`；测试证明即使同一 raw
  配有高等级 mapped special，也不会通过。
- `celestial`、`essencemagic`、`gouyee`、`lotusforce`、`magic-array`、
  `mysterrier`、`necromancy`、`wu-shun` 使用现有 `effective_level()`，即
  `raw basic / 2 + raw mapped special`。Phase 3A 尚无 temporary skill modifier 的
  typed producer，因此当前调用的显式 temporary modifier 为 0；未来 modifier/equipment
  层接入时必须继续从窄化输入补入，不能改读 raw。
- `mysterrier` 先读取 `mapped_skill(force)` 并要求精确等于 `mystforce`，再做 effective
  比例检查。无 mapping、错误 mapping、正确 mapping 三种状态分别测试。
- `max_force`、`max_mana` 读取 maximum，不读取 current。`str` 与 `spi` 是 base 字段；
  当前 attribute modifier 不参与。

所有 `/ 2` 与 `/ 10` 保留整数除法；所有 `<`、`<=`、`>` 与相等边界按源文件逐项测试。
全 mudlib 的 `query_temp("apply/<skill-id>")`/装备属性复扫没有发现本阶段这些 effective
前置 ID 的实际 authored modifier producer；`feature/equip.c` 只提供通用 apply 累加机制。
因此当前 modifier=0 有源内容依据，但 future Equipment/modifier phase 仍应给 policy
提供窄化 modifier 输入，不能把 effective 永久等同于 raw/2+mapped。

## 与 LearnService 的关系

Phase 3C1 的执行顺序没有改变。调用方从 registry 取得请求 skill ID 对应 policy，
`LearnService` 仍在教师 raw 非零、teacher prevention、学生/教师 raw 比较之后，且在
gin 成本、raw-zero entry、potential、教师 sen 和学生 gin 之前执行 policy。

测试证明 `DEPENDENCY_UNAVAILABLE` 在该位置停止，并且不会：

- 创建 raw-zero skill entry；
- 修改 `potential_spent`；
- 支付教师 sen；
- damage 学生 gin。
- 调用 `improve_skill()` 或创建 learned progress。

此外，注册测试分别覆盖：可执行显式 hook、依赖不可用 hook、继承默认 skill 和未知
skill。未知 ID 返回无策略，并在 `LearnService` 的原 valid_learn 位置以 typed policy
mismatch 停止；不会因 `std/skill.c` 的默认实现而对未知/未导入内容全局放行。

## 延期领域与未来输入

- Equipment phase 必须提供 primary/secondary hand 占用、空手事实，以及 primary weapon
  的稳定 `skill_type`（至少 sword/whip）。届时要按上表源顺序补全 13 个 C 类 hook，
  不能只提供一个笼统 `has_weapon`。
- `stormdance` 只需要一个窄化、持久语义明确的 gender 值；本阶段没有为一个 hook
  建立广泛 demographics 系统。
- `nine-moon` 在 gender/equipment 之外还引用缺失的 `nine-moon-force`。在找到权威来源
  或明确迁移决定前，不把它改成其他 force ID，也不伪造 daemon。
- environment/world、family/faction 在这 45 个 hook 中没有读取，因此未来这些系统不需
  为 Phase 3C2 增加 policy 输入。

## Legacy 缺陷与歧义

- `nine-moon.c` 要求 mapped `nine-moon-force`，但全 mudlib 只有这一处字符串引用，且
  `daemon/skill/nine-moon-force.c` 不存在。正常 `feature/skill.c::set_skill()` 会拒绝
  不存在的 skill daemon，所以该准入条件看起来不可达；仍可能存在手工损坏/旧存档
  mapping，不能据此猜测作者原意。
- `scratching.c` 的失败文字称“天师剑法”，实际 hook 只检查 `max_force >= 80`，没有
  weapon、gender 或 taoism 条件。Native 按代码而非文字实现。
- 多个 active hook 直接恒返回 1；没有因为技能看起来高级而补造前置条件。

这些都是源记录，不需要新的 LPC-to-Godot 行为替代，因此本阶段不修改
`DECISIONS.md`。

`nine-moon` 的 active 函数若面对手工损坏/旧存档状态，其确定顺序仍是：女性、
`max_force >= 50`、mapped ID 精确相等、primary sword。正常 API 无法建立缺失技能的 raw
条目，且 gender/equipment 领域也不存在；因此目前保持 D 与
`LEGACY_REQUIRED_SKILL_MISSING`，没有把可疑 ID 静默替换成 `nine-moon-sword` 或其他 force。
