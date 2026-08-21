# Phase 3C1：最小关系状态、教师投影与 Learn 核心

## 范围与结论

本阶段实现一次纯领域、确定性的 Learn 事务。权威规则来自
`reference/es2/mudlib/cmds/std/learn.c`；没有建立 LPC dbase、动态方法分派、NPC、
场景、库存、婚姻、门派招募或完整 `valid_learn()` 系统。

核心入口为 `LearnService.learn()`。它接收学生 `CharacterState`、一次尝试专用的
`TeachingContext`、请求技能的 `SkillDefinition`、显式 `SkillLearnPolicy` 以及可选的
既有 `SkillImprovementEffectRegistry`，返回 `LearnResult`。

## 检查的 LPC 来源

完整重查的核心来源：

- `reference/es2/mudlib/cmds/std/learn.c`
- `reference/es2/mudlib/feature/apprentice.c`
- `reference/es2/mudlib/std/char/master.c`
- `reference/es2/mudlib/feature/skill.c`
- `reference/es2/mudlib/std/skill.c`
- `reference/es2/mudlib/feature/damage.c`
- `reference/es2/mudlib/feature/attribute.c`
- `reference/es2/mudlib/std/char.c`
- `reference/es2/mudlib/include/globals.h`
- `reference/es2/mudlib/include/skill.h`

用于验证教师/认可/F_MASTER 形状的代表来源：

- `reference/es2/mudlib/daemon/class/swordsman/master.c`
- `reference/es2/mudlib/d/snow/npc/fist_trainer.c`
- `reference/es2/mudlib/d/snow/npc/teacher.c`

用于代表性 `valid_learn()` policy 的来源：

- `reference/es2/mudlib/daemon/skill/chaos-steps.c`
- `reference/es2/mudlib/daemon/skill/fall-steps.c`

45 个显式 `valid_learn()` hook 的完整结构扫描与依赖分类沿用已关闭的
`PHASE_3C0_LEARN_DEPENDENCY_ANALYSIS.md`；本阶段没有批量移植它们。

## 原生关系模型与稳定 ID

- `FamilyState.family_id`：稳定 `StringName`；空 ID 表示无门派。
- `FamilyState.generation`：只保存 Learn 会读取的学生辈分。
- `ApprenticeshipState.master_teacher_id`：稳定 `StringName` 教师 ID，是原生主身份。
- `ApprenticeshipState.legacy_master_name`：仅为
  `feature/apprentice.c::is_apprentice_of()` 的第二个兼容比较保留，不是主身份。
- `ApprenticeshipState.betrayer_count`：只供 `F_MASTER::prevent_learn()` 使用。

没有加入称号、权限、招募历史、每日名额、任务 mark 或故事状态。教师的 family、
generation 与 `privs` 属于教学投影，不属于学生关系状态。

原作两套不同“嫡传”判断被分别保留：

1. `learn.c::is_appr_of()`：master ID 相等，且学生 generation 恰为教师加一。
2. `feature/apprentice.c::is_apprentice_of()`：master ID 与持久化 master name 都相等，
   不检查 generation；`std/char/master.c` 的三倍限制使用这一套。

审计确认私有 `is_appr_of()` 本身不读取 `family_name`。因此 native 私有嫡传判断也不
要求非空 `family_id`；只要稳定 master ID 与 generation 关系成立即可。`family_id`
只参与后续同门 `privs == -1` 豁免。

## 教师定义与尝试投影

`TeacherDefinition` 只保存不可变 authored 元数据：稳定教师 ID、只读教学 offer 集合
以及 legacy 来源/首要别名/显示名。它不保存当前 sen、当前技能状态、位置、AI 或
`Node`。

审计后 `TeacherDefinition` 与 `TeachingContext` 都按 skill ID 重建传入的
`TeachingOffer`，而不是只复制外层数组或保留调用方对象引用，避免 definition、
context 与调用方共享可变 `RefCounted` offer 状态。

`TeachingOffer` 只投影一个稳定 skill ID。`TeachingContext` 是一次 Learn 尝试的窄
动态投影，保存教师当前 raw skill、base int、current sen、family/generation/privs、
可用/角色/清醒事实、玩家式教师是否支付 sen、伴侣事实、`env/no_teach`、确定性 roll
和 policy。Learn 不接收教师的可变 `CharacterSkillState`。

玩家式教师的 sen 在尝试专用 context 中按原作时点更新，同时在 `LearnResult` 中返回
before/after；未来教师运行时可据此提交权威状态。NPC 式教师同样必须通过 sen 阈值，
但不支付 sen。

## 精确保留的执行与 mutation 顺序

以下顺序直接对应 `cmds/std/learn.c`，实现没有改成“先验证、后统一提交”：

1. 学生是否战斗。
2. 教师是否可达、是否 character、是否清醒。
3. Learn 私有嫡传判定；否则依次尝试伴侣豁免、同门且教师 `privs == -1`、authored
   recognition policy。
4. 教师请求技能 raw 必须非零；负数仍按 LPC truthiness 继续。
5. teacher prevention policy；代表实现保留完整 F_MASTER 规则。
6. 学生 raw 必须严格小于教师 raw。
7. 请求 skill/definition/policy ID 一致，并执行 `valid_learn()` typed policy。
8. 按“教师项先、学生项后”计算 gin 成本。
9. 学生 raw 为 0 时先把成本翻倍，并立即建立显式 raw 0 条目。
10. `potential_spent >= potential` 拒绝。
11. `env/no_teach` 拒绝。
12. 教师 current sen 必须严格大于 `gin_cost / 5 + 1`。
13. 玩家式教师此时支付 sen；NPC 式教师不支付。
14. 只有学生 current gin 严格大于成本才进入进度分支。
15. martial 技能检查 `student_raw^3 / 10 <= combat_experience`。
16. 实际进度路径先令 `potential_spent += 1`。
17. 验证调用方提供的确定性 roll 后，调用 `improve_skill()` 恰好一次。
18. 把 `SkillImprovementResult` 交给既有 `SkillImprovementEffectRegistry`。
19. authored effect 完成后才伤害学生 gin。
20. gin 不足或恰好等于成本时不进步，把实际成本改为当前 gin 并全部消耗。

初学技能在步骤 9 的显式 raw 0 条目会在后续 potential、no-teach 或教师疲劳失败后
保留；这是有测试保护的 legacy 副作用，不是新设计。

`LearnResult` 分别记录调用前是否已有 raw entry、raw-zero 分支是否执行了
`set_skill(skill, 0)` 等价写入，以及该写入是否真正新建了 entry。因此“缺失”和
“已显式为 0”不会因二者读取值都为 0 而混同；两者仍都会按 LPC 翻倍成本并写 0。

## 公式与严格边界

```text
gin_cost = 150 / teacher_base_int + 150 / student_base_int
new_skill_gin_cost = gin_cost * 2
teacher_sen_cost = gin_cost / 5 + 1
martial_required_exp = student_raw^3 / 10
random_upper = student_base_int
             + combat_exp / (1000 + combat_exp / 1000)
valid_roll: 0 <= roll < random_upper
```

所有除法均保留整数除法。没有发明 intelligence、资源或技能等级的上下限；sen 与
gin 的比较都严格使用 `>`。随机数不在 `LearnService` 内生成。

## Policy 边界

- `TeacherRecognitionPolicy`：只负责未被关系豁免时的 affirmative authored 认可；
  无该 policy、policy 明确允许、明确拒绝、以及已知 policy 依赖尚不可用是四种独立
  typed 状态。无 policy 在 fallback 路径返回 `RECOGNITION_POLICY_ABSENT`；已知但未
  可执行的依赖返回 `DEPENDENCY_UNAVAILABLE`。
- `TeacherPreventionPolicy`：缺省表示教师没有额外拒绝函数。
- `FMasterTeacherPreventionPolicy`：逐字保留 betrayer 阈值以及非嫡传三倍规则；
  通过时显式返回 `ALLOWED`，与“没有 prevention policy”区分。
- `SkillLearnPolicy`：缺省为 `DEPENDENCY_UNAVAILABLE`，不能把未知 hook 静默放行。
- `DefaultSkillLearnPolicy`：显式对应 `std/skill.c::valid_learn() == 1`。
- `MinimumInnerForceSkillLearnPolicy`：代表 `chaos-steps.c` / `fall-steps.c` 的
  `max_force >= 50` 形状，可同时产生 authored allow 与 rejection。
- `DependencyUnavailableSkillLearnPolicy`：证明未迁移的装备、世界或其他依赖有独立
  typed 结果。

这些 policy 都是纯 `RefCounted` 领域对象；没有 `call_other()`、daemon 路径分派、
service locator、自由 payload 或大 ID `match`。

## 进度与 authored effect 集成

Learn 直接复用 `CharacterProgressionState.potential_spent`、
`CharacterSkillState.improve_skill()`、`SkillImprovementResult` 与
`SkillImprovementEffectRegistry`。没有复制 learned penalty、严格平方阈值、单次最多
一级、清零不结转或 callback 逻辑。测试同时证明：无升级时不执行 callback、有升级时
只执行一次、无 hook 返回 `NO_AUTHORED_EFFECT`，且 effect 观察到的是 gin 扣除前的
角色状态。

## Legacy 缺陷与兼容替代

- 双方 base int 为 0 会在成本计算中产生除零；native 返回精确位置的 typed legacy
  error，且不创建稍后的 raw 0 条目。
- 负 intelligence 可产生负成本。玩家教师会在 sen damage 点失败；NPC 教师可能已
  增加 potential、修改技能并执行 effect，随后才在学生 gin damage 点失败。native
  结果保留这些已发生 mutation，不回滚。
- random 分母为 0、上界非正或注入 roll 越界时返回 typed legacy error。由于原作先
  增加 `learned_points` 再调用 `random()`，该 potential mutation 会保留，而 gin 尚未
  扣除。
- 教师负 raw 非零在 LPC 中为真；本阶段没有静默校正。
- 婚约卡扫描/名称解析/在线对象查找替换为调用方提供的 `teacher_is_spouse` 事实。
- MudOS 对 `random(n <= 0)` 的具体异常形式不属于 mudlib 源码；本阶段保留“调用点为
  legacy error”而不模拟驱动崩溃文本。

上述行为选择同步记录于 `DECISIONS.md`。

## 明确延期

延期到后续阶段：完整 45 个 `valid_learn()` policy、完整 authored 教师/认可规则、
任务 mark 的取得、拜师/招募/叛师/逐出、称号与配额、伴侣状态来源、教师 NPC/玩家
运行时状态提交、世界目标解析、对话与 UI、combat、inventory/equipment、study、
runtime scheduling。Phase 3C1 没有为这些系统建立假状态。

## Phase 3C1 审计结论

审计修正了四项具体问题：移除私有嫡传判断中 LPC 不存在的非空 family ID 条件；把
“无 recognition policy”与“已有 policy 但依赖未迁移”拆成不同结果；将教师 offer
从浅层 collection copy 加固为逐项值复制；修正 raw 0 结果元数据以区分缺失 entry
与既有显式 0。补充测试同时覆盖 exemption 不调用
recognition、玩家教师支付后学生失败不回滚、成本整数边界、martial 经验上/下边界、
potential 最后一单位、`random(1)`、嵌套随机整数除法和 policy/offer 隔离。
