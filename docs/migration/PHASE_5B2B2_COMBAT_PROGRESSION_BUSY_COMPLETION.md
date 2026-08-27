# Phase 5B2B2 — Combat Progression + Ordered Busy Completion

## 范围与来源

本阶段在已关闭的 `CombatAttackResolver` 外组合 ordinary attack 的后半段游戏规则：
base DODGE/PARRY/HIT 完成后，按 LPC 顺序执行成长；只有完整 HIT 且最终请求伤害 `D > 0`
时才依次经过 `report_status()` 边界和 busy interrupt。没有实现关系、friendly stop、winner RNG、post_action、riposte、
opponent、调度、生命周期或表现层。

直接依据：

- `reference/es2/mudlib/adm/daemons/combatd.c`：`do_attack()` 的 DODGE/PARRY/HIT
  progression、`report_status()` 及 `damage > 0` interrupt 顺序；
- `reference/es2/mudlib/feature/action.c`：独立的 mixed-type `busy` / `interrupt`
  分支与 integer 路径严格 `<` 语义；
- `reference/es2/mudlib/feature/skill.c`：技能 daemon/file 存在性检查先于任何
  `improve_skill()` mutation，以及 amount-zero、learned、单次升级规则。

复用的已关闭 Godot domain：`CombatAttackResolver`、`CharacterProgressionState`、
`CharacterSkillState`、`SkillImprovementEffectRegistry`、`ActionBusyState`。

## 组合架构

`CombatAttackCompletionService` 的固定顺序为：

1. 校验 character ID、combat_exp、raw int/spi 与 busy 投影；
2. 调用既有 `CombatAttackResolver`；
3. 仅对完整 DODGE/PARRY/HIT 调用 `CombatProgressionService`；
4. 仅对完整 HIT 且请求 `D > 0` 验证 `report_status(victim, wounded)` 的数值边界；
5. 仅在该边界成功后处理 busy/interrupt；
6. 返回不可变 `CombatOrdinaryAttackResult` 值快照。

`CombatProgressionFacts` 只携带 stable character ID、显式 `userp()` 等价布尔值、raw/base
intelligence/spirituality，以及本次 resolved attack skill 的窄定义可用性事实。它不提供 catalog、
不从类、路径或 ID 推断玩家/NPC，也不读取 effective intelligence。
服务使用同一 `CharacterState` 中的 live resource、progression、skill authorities；不会复制
combat_exp、potential 或 learned state。

组合结果分别保存 base result、progression result、status-report boundary result、busy result、最终失败阶段、合并后的 RNG
序列及失败时是否保留了先前 mutation。各 getter 返回 defensive snapshot；没有 Dictionary
payload、Callable、Node 或 aggregate authority 引用。

## DODGE

defender 分支严格要求：

```text
dp < ap && (!defender_is_user || !attacker_is_user)
bound = defender.current_gin * 100 / defender.max_gin + defender.raw_int
random(bound) > 50
```

成功顺序为 defender `combat_exp += 1`，再调用既有 `improve_skill("dodge", 1)`，最后把
升级结果交给既有 authored effect registry。

随后独立检查 NPC attacker：

```text
ap < dp && !attacker_is_user
roll1 = random(attacker.raw_int)
if roll1 > 15: attacker.combat_exp += 1
roll2 = random(attacker.raw_int)
attacker.improve_skill(resolved_attack_skill, roll2)
```

两个 draw 独立且顺序固定。`roll2 == 0` 原样传入 `improve_skill()`，由 `feature/skill.c`
既有规则转为最小 adjusted amount 1。第二 draw 非法时，第一 draw 已产生的 exp 不回滚。

## PARRY

PARRY 只有 defender 分支，条件与 health-int 公式和 DODGE defender 完全相同，成功后依次
增加 exp 并调用 `improve_skill("parry", 1)`。严格比较仍是 `random(bound) > 50`。
原 LPC 没有 PARRY 的 NPC attacker failed-hit 学习块，因此没有补造。

## HIT

HIT 的总门为 `!attacker_is_user || !defender_is_user`。双方均为 user 时不执行任何成长、
不消耗成长 RNG，但仍继续到后面的 busy 步骤。

总门内 attacker 仅在 `ap < dp` 时执行：

```text
bound = attacker.current_gin * 100 / attacker.max_gin + attacker.raw_int
if random(bound) > 30:
    attacker.combat_exp += 1
    if attacker.potential - attacker.potential_spent < 100:
        attacker.potential += 1
    attacker.improve_skill(resolved_attack_skill, 1)
```

potential 本身不 clamp；gap 恰为 100 时不增加。skill level-up 继续使用已有 authored effect
registry，不在 Combat 内复制 `skill_improved()`。

攻击技能改善到达时才检查 resolved attack skill 的定义可用性，以复现
`feature/skill.c::improve_skill()` 在 mutation 前解析 skill daemon/file 的顺序。缺失定义不会
创建任意 skill 条目：DODGE 先保留两个 NPC RNG 与可能的 exp；HIT 先保留 damage、attacker
roll、exp/potential，再在 defender progression 前返回 typed failure。固定 `dodge` / `parry`
定义由已扫描的标准 skill daemon 证明存在，不引入通用 SkillCatalog。

然后无论 attacker 的 `ap < dp` 是否成立，都执行 defender roll：

```text
bound = defender.max_kee + defender.current_kee
if random(bound) < requested_damage_D:
    defender.combat_exp += 1
    if defender.potential - defender.potential_spent < 100:
        defender.potential += 1
```

这里的 current kee 是 resolver 已执行 damage/wound 后的 live authority 值；比较对象是 LPC
`receive_damage()` 返回的请求 D，而不是 saturation 后的实际 current delta。defender 不改善技能。
DEATH/UNCONSCIOUS candidate 不会截断这些成长，生命周期仍留待后续阶段。

## RNG、非法状态与部分 mutation

成长使用 resolver 的同一 `CombatRandomSource`。顺序为 resolver 的 limb/avoidance/damage/
force/wound draws，随后才是本阶段对应的 defender/attacker draws；没有隐藏 RNG，也没有
friendly winner RNG。

health ratio 保持 `(current_gin * 100) / max_gin + raw_int` 的整数求值顺序。`max_gin == 0`
转为该源码位置的 typed division failure；非正 `random()` bound 不做 `random(1)` clamp，
返回 typed bound failure 并保存确切非法 bound。注入 draw 不满足 `0 <= draw < bound` 时返回
该 draw 位置的 typed failure。所有这些检查只在源码真正到达时发生，所以 HIT 中发生的晚期
失败保留先前 force、damage、wound 与成长 mutation，不 rollback。

## `report_status()` 数值边界

完整 HIT 且 `D > 0` 在 progression 完成后、busy interrupt 前到达该边界。若本次实际执行了
wound transition，按 LPC 的 `wounded` 参数读取 live `effective_kee`；否则读取 live
`current_kee`。保留 `(selected_kee * 100) / max_kee` 的整数顺序。文本分档仍属表现层，未迁移。

`max_kee == 0` 在这里返回 typed `ZERO_MAXIMUM_DIVISOR`，保留此前 base/progression mutation，
且不触碰 busy。不会把这个缺陷提前到 resolver 前，也不会伪造除数。

## Busy

`CombatBusyInterruptProjection` 分别携带 `BusyKind`（not busy / integer / function）与
`InterruptKind`（integer / function），不再把两份独立 LPC 状态压成单一模式。在 resolver 前，
defender snapshot busy 必须与 busy kind 一致；只有 integer busy + integer interrupt 组合绑定
`ActionBusyState` authority。函数事实不保存 `Callable`。

只有 HIT 且请求 D 严格大于 0 才到达 interrupt。NOT_BUSY 返回“已检查但不 busy”；integer
模式调用既有 `ActionBusyState.try_interrupt()`：只有 `busy < interrupt_threshold` 清零 busy，
相等不清，成功后 threshold 保留。D==0、DODGE 与 PARRY 都不尝试 interrupt。

四种到达时的 mixed-type 行为为：integer/integer 执行严格比较；integer/function 与
function/function 因需执行 LPC closure 而返回 typed `FUNCTION_INTERRUPT_POLICY_UNAVAILABLE`；
function/integer 按源码无操作并成功完成。`!busy` 永远先返回，即使 integer interrupt threshold
仍残留。所有晚期失败保留 base/progression mutation；不存储或执行 LPC closure，也不实现
runtime scheduling。

## 正式审计修正

- 补回 `feature/skill.c` 的技能定义存在性边界，禁止任意 weapon `skill_type` 静默创建技能；
- 将旧的单轴 busy mode 改为独立 busy/interrupt 类型投影，覆盖全部四种 mixed-type 组合；
- 补回 progression 与 busy 之间的 `report_status()` 数值边界及 `max_kee == 0` 顺序化失败。

## 明确延后

- Phase 5B3：relationship/friendly stop、winner RNG、opponent、riposte/guard、combat step；
- Phase 5B4+：post_action、authored martial/weapon/NPC hit policies、iceforce 与其他技能动作；
- World/NPC runtime、Timer/heartbeat、UI/presentation、death/unconscious/corpse execution。
