# Phase 3B1：修炼与内部资源训练

## 范围与架构

本阶段只迁移 `exercise`、`meditate`、`respirate` 的确定性领域转换。`CultivationService` 接收现有 `CharacterState`、明确的消耗量、外部提供的 `is_fighting` 事实和对应技能的 temporary modifier；它直接更新主资源与 `CharacterRecoveryState` 中的内部资源，并返回 typed `CultivationResult`。没有文本解析、Node、heartbeat、战斗系统、训练调度或表现逻辑。

## 权威 LPC 来源

- 命令规则：`reference/es2/mudlib/cmds/std/exercise.c`、`meditate.c`、`respirate.c`。
- 主资源扣减与恢复边界：`feature/damage.c`。
- raw/effective skill 与 mapping：`feature/skill.c`、`include/skill.h`。
- 基础/有效属性区别：`feature/attribute.c`。
- fighting 输入来源：`feature/attack.c::is_fighting()`。
- 动态字段加法与无字段 clamp：`feature/dbase.c`、`feature/treemap.c`。
- 组合与延期边界：`std/char.c`、`std/force.c`、`include/globals.h`。
- 世界侧命令拦截边界：`d/wiz/entrance.c`、`d/wiz/courthouse.c`（只作为未来 world permission 证据）。

## 字段与动作映射

| LPC | Godot |
|---|---|
| `gin` / `kee` / `sen` | `essence` / `vitality` / `spirit` current |
| `atman/max_atman` | `recovery.atman.current/maximum` |
| `force/max_force` | `recovery.inner_force.current/maximum` |
| `mana/max_mana` | `recovery.mana.current/maximum` |
| `query("con")` / `query("spi")` | base `constitution` / base `spirituality` |
| `query_skill(id, 1)` | `skills.raw_level(id)` |
| `query_skill(id)` | `skills.effective_level(id, temporary_modifier)` |
| `query_skill_mapped("force")` | `skills.mapped_skill(SkillIds.FORCE)` |

## 精确检查顺序

文本缺失或无法解析整数属于未来输入层；领域服务从已提供的 typed cost 开始，并保留其余命令顺序。

- `exercise`：fighting → 已映射 force style → cost 至少 10 → kee 足够 → `sen/max_sen` 至少 70% → `gin/max_gin` 至少 70% → 扣 kee → 计算收益。
- `meditate`：fighting → cost 至少 10 → sen 足够 → `kee/max_kee` 至少 70% → `gin/max_gin` 至少 70% → 扣 sen → 计算收益。
- `respirate`：fighting → cost 至少 10 → gin 足够 → `kee/max_kee` 至少 70% → `sen/max_sen` 至少 70% → 扣 gin → 计算收益。

百分比使用 `current * 100 / maximum < 70` 的整数除法与严格小于判断；恰好 70 通过。所有正常 validation failure 都不修改状态。LPC 在 percentage maximum 为零时会除零中止；native result 在相同检查位置返回对应 `LEGACY_ZERO_MAXIMUM_*_DIVISOR`，不把它伪装成低生命值，决定记录于 `DECISIONS.md`。

## 收益与上限公式

所有除法均为整数除法。

- exercise gain：`kee_cost * (raw_force + base_con) / 300`
- exercise maximum cap：`(raw_force + effective_force / 5) * 10`
- meditate gain：`sen_cost * (effective_spells + base_spi) / 300`
- meditate maximum cap：`raw_spells * 10`
- respirate gain：`gin_cost * (effective_magic + base_spi) / 300`
- respirate maximum cap：`raw_magic * 10`

`base_con/base_spi` 不包含 attribute modifier。effective skill 包含 temporary modifier、basic raw 的一半与 mapped special raw；raw skill 不包含这些值。三个命令都不调用 `improve_skill()`。

主资源先扣除。若计算收益 `< 1`，动作仍成功并保留消耗，但不改变内部资源，也不执行 over-maximum 检查。收益至少为 1 时先加到 current；只有新 current **严格大于** `maximum * 2` 才进入上限分支：

1. 若旧 maximum `>= skill cap`，maximum 不变；
2. 否则 maximum 只增加 1；
3. 两种情况最后都把 current 设置为最终 maximum。

因此 current 可以位于 maximum 以下、等于 maximum 或高于 maximum 而不被夹取；加成后恰好等于两倍 maximum 也不处理。若动作开始时 current 已等于两倍 maximum，只要正收益使它越界，就会触发分支。内部 resource 与 maximum 沿用 Phase 2A 的任意整数语义，没有新增非负约束。

## Result 语义

`CultivationResult` 记录 action、typed failure reason、completion（无收益、普通收益、maximum +1、技能瓶颈）、请求/实际消耗、计算收益，以及内部资源和 maximum 的前后值。未来表现层可以据此选择说明，不需要把 LPC 输出字符串保存为 gameplay state。

## 旧行为、缺陷与延期

- `exercise` 是三者中唯一要求预先 enable 对应内功的命令；`meditate`、`respirate` 即使没有 mapped school 也会用现有 effective skill 计算。
- `exercise.c` 的注释声称 cost 30 时收益范围 1–15，但代码没有限制属性或技能，因此这不是可执行上限。
- 帮助文字称消耗量有默认值 30，实际三个命令在没有参数时都失败；native domain 不虚构默认值。
- `receive_damage()` 的 heartbeat 唤醒、命令输出、busy/action 时间、房间对命令的拦截属于运行时/世界/表现层，延期。
- learn/practice/selflearn/study、teacher/faction、perform/exert/cast/conjure、战斗和所有技能提升均未实现。
