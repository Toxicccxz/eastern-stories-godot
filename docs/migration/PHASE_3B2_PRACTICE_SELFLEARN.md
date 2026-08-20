# Phase 3B2：Practice 与 Self-Learning

## 范围与架构

本阶段只实现 `practice`、`selflearn` 的确定性领域转换。`PracticeService` 负责通用命令顺序，`PracticePolicy` 负责选中技能 daemon 的 `valid_learn()` 与 `practice_skill()` 语义；`SelfLearningService` 单独实现自学白名单、潜能、实战经验、gin 消耗和技能提升。全部代码为 typed `RefCounted`，不依赖 Node、场景、战斗系统或调度。

`CharacterProgressionState` 新增本阶段必需的持久字段：`combat_exp` → `combat_experience`、`potential` → `potential`、`learned_points` → `potential_spent`。技能 learned progress 仍由 `CharacterSkillState` 独立保存。

## LPC 来源与结构扫描

- 命令：`reference/es2/mudlib/cmds/std/practice.c`、`cmds/std/selflearn.c`。
- 技能核心：`feature/skill.c`、`std/skill.c`、`include/skill.h`。
- 角色与资源：`feature/attribute.c`、`feature/damage.c`、`feature/attack.c`、`feature/dbase.c`、`std/char.c`。
- selflearn basic daemons：`daemon/skill/dodge.c`、`force.c`、`sword.c`、`blade.c`、`staff.c`、`parry.c`、`unarmed.c`。
- 代表 practice daemons：`fall-steps.c`、`fonxanforce.c`、`fonxansword.c`、`stormdance.c`、`linbo-steps.c`、`serpentforce.c`、`necromancy.c`。

对 `daemon/skill/` 的完整结构扫描发现：45 个 `valid_learn()`、4 个 `valid_effect()`、43 个 `practice_skill()`、9 个 `skill_improved()`，没有 daemon 自己调用 `improve_skill()`。43 个 practice hook 中，15 个始终拒绝直接练习，28 个修改主资源或内部资源，5 个要求武器，2 个读取环境，1 个包含随机召唤/战斗副作用；类别会重叠。`practice.c` 不调用 `valid_effect()`，因此本阶段不迁移该 hook。其余没有自定义 `practice_skill()` 的技能不被虚构为可练习 policy；本阶段显式缺少 policy 时只返回 typed failure，完整 authored policy 覆盖延期。

## Practice 精确语义

验证与执行顺序：

1. fighting；
2. basic/use ID 必须已有 enabled mapping；
3. mapped special 的 raw level 必须至少 1；
4. basic raw level 必须至少 1；
5. mapped skill policy 的 `valid_learn()`；
6. policy 的 `practice_skill()`；
7. hook 成功后调用 `improve_skill(mapped, basic_raw / 5 + 1, weak_mode)`。

`weak_mode` 在 `basic_raw > special_raw` 时为 `0`，否则为 `1`。整数除法保留。资源 mutation 完全发生在 policy 中，并先于 `improve_skill()`；service 不回滚返回失败的 hook 已经执行的 mutation，以保留 LPC hook 合约。通用验证失败不修改资源或技能。

本阶段迁移两个代表 policy：

- `fall-steps`：`valid_learn()` 要求 `max_force >= 50`；practice 要求 `kee >= 30` 且 `force >= 3`，随后扣 kee 30、force 3。
- `fonxanforce`：`valid_learn()` 允许，但 `practice_skill()` 始终返回失败且不消耗资源。

武器、地点、召唤和战斗相关 policy 未迁移。policy 由 stable skill ID 显式配对，替代 `SKILL_D(path)->call_other()`，没有通用字符串分派。

## Selflearn 精确语义

验证与执行顺序：

1. skill 必须是 `dodge/force/sword/blade/staff/parry/unarmed` 之一；
2. fighting；
3. raw level 至少 40；
4. 计算 `gin_cost = 300 / base_int`；
5. `potential_spent >= potential` 时失败；
6. 只有 `gin > gin_cost` 才能继续，否则消耗当前全部 gin 且无进步；
7. 若 `raw_level³ / 10 > combat_experience`，无进步但仍消耗完整 gin cost；
8. 成功路径先令 `potential_spent += 1`，再调用 `improve_skill(skill, random(base_int + raw_level))`，最后消耗 gin cost。

使用基础 `int` 与基础 `spi`，不包含 attribute modifier。实战经验比较是严格 `>`，gin 要求也是严格 `>`；恰好等于 cost 会耗尽 gin 而无进步。`300 / int`、`level³ / 10` 均为整数除法。`int > 300` 可使 cost 为 0，未增加最小 cost。

等级门槛只读取 raw level。即使同一 use 已映射高等级特殊技能，使 `query_skill(skill)` 的 effective 值远高于 40，`query_skill(skill, 1) < 40` 仍会拒绝 selflearn；temporary modifier 同样不参与。

为了确定性，service 接受已经抽取的 `improvement_roll`，并验证 `0 <= roll < base_int + raw_level`；未来随机源只负责提供该值。roll 为 0 仍会由既有 `improve_skill()` 的 `if (!amount) amount = 1` 变成 1 点进度。

## improve_skill 集成

两个服务都直接复用 `CharacterSkillState.improve_skill()`，没有复制严格平方阈值、单次最多一级、learned 清零、不结转、学习技能过多惩罚或 weak-player 逻辑。结果通过调用前后的 raw/learned snapshot 报告普通进步或升级。Phase 3A 已延期的 `skill_improved()` daemon callback 仍未实现；全量扫描找到 9 个此类 hook，selflearn 白名单中的 `force.c` 与 `unarmed.c` 会在特定升级边界改变基础 `con` 或 `str`。这些 authored 副作用不由训练 service 猜测，等待单独的 typed progression-event 设计。

## 旧缺陷、决定与延期

- `selflearn.c` 的 base `int == 0` 会除零；负数会生成负 gin cost，并最终触发 `receive_damage()` 的负伤害错误，且可能已经部分修改进度。Native 对非正 intelligence 返回 typed failure，决定记录于 `DECISIONS.md`。
- `practice` 无参数会转调 `enable` 列表；这是输入/UI 行为，不进入领域服务。
- `necromancy` 可在消耗 mana/sen 后随机召唤敌对对象并返回失败；该 policy 等待战斗/NPC/runtime 阶段，service 的 policy 合约不会自动回滚未来此类 mutation。
- `serpentforce` 的水域要求、五个武器型 policy、性别/装备/家族等 `valid_learn()` 规则等待相应 typed state，不以通用 payload 代替。
- learn、study、teacher/master、faction、book/inventory、perform/exert/cast/conjure、combat、UI、world permission、heartbeat 与 action timing 全部延期。
