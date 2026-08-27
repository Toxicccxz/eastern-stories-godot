# Phase 5B2A：Ordinary Attack Core Resolution

## 范围与权威来源

本阶段实现一次已选定 action 的普通攻击核心结算，范围止于 kee damage、可选 kee wound 与
三主资源 threshold candidate。实现是纯 typed GDScript，不依赖 Node、SceneTree、Timer、World、
NPC runtime、全局随机数或通用 `apply` Dictionary。

直接依据：

- `reference/es2/mudlib/adm/daemons/combatd.c:163-190`：`skill_power()`；
- `reference/es2/mudlib/adm/daemons/combatd.c:197-382`：limb、AP/DP、dodge、PP、parry、
  damage、ordered hit hooks、defense loop、damage/wound；
- `reference/es2/mudlib/feature/damage.c:12-68`：kee damage/wound 的返回值、饱和与顺序；
- `reference/es2/mudlib/feature/attribute.c:5-9`：`query_str()`；
- `reference/es2/mudlib/feature/skill.c:56-77`：传给 `skill_power()` 的 effective skill 语义；
- `reference/es2/mudlib/std/force.c`：标准 force `hit_ob()` 的资源、随机数与反震依赖，仅用于确定
  deferred boundary；本阶段没有实现该 policy；
- `reference/es2/mudlib/feature/equip.c`、`std/equip.c`：装备时把 weapon `damage` 加入角色
  `apply/damage`，卸下时移除；证明 `do_attack()` 读取的是已经聚合的角色标量；
- `reference/es2/mudlib/include/combat.h`：attack/defense usage 与 dodge/parry legacy constants。

为证明普通对象缺少 `hit_ob()` 时的驱动行为，还核对了仓库随附的 MudOS 文档：
`reference/es2/doc/efuns/call_other`、`reference/es2/doc/efuns/undefinedp`、
`reference/es2/doc/driver/done-mudos`。缺失方法返回 `undefined`；`combatd.c` 仅处理 string/int 返回值，
因此普通武器、普通角色或已映射但没有 override 的武功在该调用点是“已证明无 authored effect”，
不是“尚未迁移的 authored policy”。

## Native 输入边界

`CombatAttackInput` 防御性复制三个不可变投影：

- `CombatAttackerSnapshot`：稳定角色 ID、living、combat experience、sen current/max、已投影的
  attack skill type + effective level 与 usage bonus、当前已聚合的 `apply/damage`、
  `CombatStrengthProjection`、force effective-level 投影、对 defender 的 lethal intent、映射 force/martial 的稳定
  provider ID + typed hit-policy status、attacker hit-policy status，以及可选主武器 profile；
- `CombatDefenderSnapshot`：稳定角色 ID、living、busy、combat experience、sen current/max、
  dodge/parry/unarmed effective levels、defense usage bonus、`apply/armor`、主武器存在事实与 limbs；
- 已由 Phase 5B1 选择的 `CombatActionDefinition`。Resolver 不查询或重选 action，也不消费 action
  selection RNG。

`WeaponCombatProfile` 仅含稳定 weapon ID、开放 `skill_type` 与 typed hit-policy status。它故意不含
weapon base damage：`feature/equip.c` 已把该贡献加入角色 `apply/damage`，resolver 再加一次会重复。
它也不保存 Item、Equipment、Catalog、动作表、耐久或 procedural hook。

`CombatHitPolicyStatus` 明确区分 `NOT_APPLICABLE`、`PROVEN_NO_AUTHORED_EFFECT`、
`AUTHORED_POLICY_UNAVAILABLE` 和 `DRIVER_AMBIGUITY`。Result 对停止的 policy 同时返回 hook kind、
精确 failure stage 与稳定 provider ID；没有 `call_other()`、Callable 或 callback-name dispatcher。
weapon 与无武器 attacker 的 status 没有 permissive 默认值：构造攻击输入时必须显式投影来源结论，
避免遗漏一个真实 authored override 时被静默当作 no-op。

输入不保存 CharacterState、CharacterSkillState、EquipmentState、ArmorState 或关系对象引用。
defender 的 essence/vitality/spirit `CharacterResourceState` 作为独立 authority 参数传入，仅 vitality
被本阶段修改。

## 已实现流水线

1. weapon 存在时 attack skill 为其 `skill_type`，否则为 `unarmed`；它必须与 effective attack
   projection 携带的 skill type 相同，否则在任何 RNG 或资源 mutation 前 typed-fail。
2. 要求非空 limbs；按 `random(limb_count)` 的 index 选择，不发明默认 body。
3. `AP = skill_power(attacker, attack skill, ATTACK)`，随后 `AP = max(AP, 1)`。
4. `DP = skill_power(defender, dodge, DEFENSE)`；先 clamp 至 1，再在 busy 时 `/ 3`，不二次 clamp。
   因此 busy DP 可以为 0。
5. `random(AP + DP) < DP` 为 dodge；成功立即返回，不再取 parry/damage rolls，不改资源。
6. PP 来源严格为：defender armed 用 parry；attacker unarmed 时先乘 2；defender unarmed 且
   attacker armed 时先置 0；双方 unarmed 时用 unarmed。随后 busy `/ 3`，最后 clamp 至 1。
7. `random(AP + PP) < PP` 为 parry；成功立即返回，不改资源。
8. `D = attacker projected current apply/damage`，armed/unarmed 使用同一最终聚合契约；再执行
   `D = (D + random(D)) / 2`。若原始 D 非正，在该 random 位置返回
   typed legacy-invalid failure，不把 bound 改成 1。
9. action damage 非零时：`D += action.damage * D / 100`，保留整数次序与负百分比。
10. `B = query_str = base str + force_factor + apply/strength`，无 clamp。
11. ordered hook seam 按源位置处理：仅在 `force_factor != 0 && current_force > force_factor &&
    mapped_force_id exists` 时到达 force hook；随后 action force percentage；有映射时到达 martial
    hook；最后 weapon hook 或 attacker/NPC hook。已证明没有 authored override 的 provider 正常通过；
    已知 override 尚未实现时返回 `AUTHORED_HIT_POLICY_UNAVAILABLE`；真正无法确定的驱动语义另返
    `HIT_POLICY_DISPATCH_AMBIGUOUS`。停止结果保留已完成计算/RNG，不继续或假设返回 0。
12. action force 非零时：`B += action.force * B / 100`。注意可执行源码把它放在 force hook 与
    martial hook之间（`combatd.c:319-342`）。
13. B 正数时 `D += (B + random(B)) / 2`；B 非正不取随机数。之后仅 D 负数 clamp 为 0。
14. `factor = defender.combat_exp`；每次先要求 factor 正数，再按当前 factor 取 random。只要
    `roll > attacker.combat_exp`，就依次 `D -= D / 3`、`factor /= 2`。没有闭式化。
15. 调用既有 `vitality.apply_damage(D)`；result 保留请求 D，即使 current kee 实际饱和到 -1。
16. 仅 lethal unarmed 或任何 armed attack 进入 wound 分支。friendly unarmed 不取 wound roll；
    armed friendly 仍可 wound。
17. wound 分支在 damage 后执行 `random(D) > armor`。成立时 wound amount 为 `D - armor`，再调用
    `vitality.apply_wound()`。由于合法 roll 满足 `0 <= roll < D` 且 `roll > armor`，可推出
    `D > armor`，故 amount 严格为正，不需额外 clamp。
18. mutation 后观察三资源：任一 effective `< 0` 为 DEATH；否则任一 current `< 0` 为
    UNCONSCIOUS；否则 NONE。这只是 candidate，不执行 lifecycle。

## RNG 契约

完整 hook-free HIT 的 resolver-owned 顺序为：

1. limb；
2. dodge；
3. parry；
4. `random(apply_damage)`；
5. B 正数时 `random(B)`；
6. defense loop 的零或多次 current-factor rolls（实际至少需要一次终止检查）；
7. lethal-or-armed 时 wound roll。

结果保存每次已请求的 exclusive upper bound 与实际 draw 的 defensive copies。draw 必须满足
`0 <= draw < bound`；缺失/越界 test source 有 typed failure，不 clamp。dodge/parry 和 unavailable hook
都不会消费其后随机数。

## 非法旧状态与部分 mutation

- empty limbs 在任何 random 前失败；
- `apply/damage <= 0` 在其 `random(D)` 位置失败，不改资源；
- defense factor 在一次必需 draw 前非正时失败。特别是 attacker combat_exp 为负时，factor=1 的
  roll 可能必然令循环再迭代并把 factor 除为 0；native 保留已执行循环轮次，再 typed-fail，避免挂死；
- wound-qualified 且最终 D 为 0 时，damage transition 已经完成，随后在 wound `random(D)` 位置失败；
  不预检、不 rollback；
- 合法正 bound 上由注入 RNG 返回越界值，也在对应精确阶段失败。若发生在 wound draw，已经完成的
  damage 同样保留。

`CombatResourceMutationResult` 分别记录 damage/wound transition 是否完成、请求值，以及 vitality
current/effective 的前后快照，避免把整个 resolver 伪装成事务。

## Typed result

`CombatAttackResult` 是 defensive immutable result，outcome 可表示 DODGE、PARRY、HIT、
INVALID_SOURCE_STATE、AUTHORED_HIT_POLICY_UNAVAILABLE、HIT_POLICY_DISPATCH_AMBIGUOUS。它还保存
exact failure stage、authored policy kind/provider ID、stable attacker/defender/action IDs、
interrupt request、threshold candidate、
`CombatAttackCalculation` 与 `CombatResourceMutationResult` 的值快照。

Calculation 包含 limb、attack skill、AP/DP/PP、base/current/final damage、初始/最终 strength B、
armor、defense iterations/factor、wound eligibility/roll/amount 和 RNG evidence。没有 Dictionary
payload、presentation text、Callable 或 authoritative aggregate reference。`ReachedStage` 记录最后
完成的计算阶段，`has_reached()` 可区分“来源真正计算出 0”和“默认 0 但尚未到达”；wound evaluation
另由实际 wound draw 标记，避免 friendly-unarmed 跳过分支后伪称已计算。

DODGE/PARRY 的 threshold 为 `NOT_OBSERVED`，而非 NONE：源在这些返回路径不执行本阶段的
mutation 后阈值观察，不能把角色已有的死亡/昏迷状态解释成已被检查并清除。完整 HIT 在 damage/
wound 后观察 gin/kee/sen，DEATH 优先于 UNCONSCIOUS。wound RNG 的 typed failure发生在 damage 后，
但不会继续执行 threshold observation 或未来 interrupt。

正数 HIT 只输出 `interrupt_requested = true`；本阶段不修改 `ActionBusyState`。

## 明确延后

- Phase 5B2B1：standard force policy（已关闭）；
- Phase 5B2B2：dodge/parry/hit progression、potential/skills mutation，以及 ordered
  busy/interrupt composition；
- Phase 5B3：opponent selection、fight/kill relationship orchestration、friendly stop、guard/riposte、
  explicit combat step；
- Phase 5B4+：authored martial/weapon/NPC hit policies、post_action、perform/exert/cast/conjure；
- World/NPC runtime、Timer/heartbeat、presentation、death/unconscious execution与尸体流程。

本阶段不是完整 `do_attack()` parity；准确名称是“through damage/wound/threshold observation 的
ordinary core resolution”。

## Phase 5B2B1 composition note

Phase 5B2B1 已在原有 force seam 接入 `std/force.c` 的 shared standard policy。攻击者当前 force 因为
是该 policy 的可变 authority，现由 resolver 参数传入，不再作为 attacker snapshot 标量；snapshot
只携带带有 `force` identity 的 effective skill 投影。defender snapshot 增加当前 force、force effective
level 与独立 `armor_vs_force` 投影。`CombatHitPolicyStatus.STANDARD_FORCE` 只允许用于 force seam；
`iceforce` 仍整体为 `AUTHORED_POLICY_UNAVAILABLE`。反震后 threshold observation 窄传攻击者
gin/kee/sen 三个资源 authority，但只有 kee 会被标准 force policy 修改。Phase 5B2A 的其余流水线与
已审计公式未改变。
