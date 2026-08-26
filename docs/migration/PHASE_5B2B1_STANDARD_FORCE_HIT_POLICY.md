# Phase 5B2B1：Standard Force Hit Policy Integration

## 范围与来源

本阶段只迁移 `std/force.c::hit_ob()` 的通用内功命中规则，并把它接到 Phase 5B2A 已存在的
force hook 位置。实现为纯 typed GDScript；没有 Node、Timer、World/NPC runtime、全局随机数、
通用 `apply` Dictionary、Callable 或按文件路径派发。

直接依据：

- `reference/es2/mudlib/std/force.c:5-37`：force 扣除、伤害公式、负值分支、空手反震、
  `armor_vs_force`、正常随机判断以及隐式 undefined 返回；
- `reference/es2/mudlib/adm/daemons/combatd.c:312-353`：force 进入条件、string/int 返回处理、
  `action["force"]` 及后续 martial/weapon/attacker hook 顺序；
- `reference/es2/mudlib/feature/damage.c:12-68`：反震 kee damage 后 kee wound 的实际突变语义；
- `reference/es2/mudlib/feature/skill.c:56-77`：`query_skill("force")` 的 effective skill 语义；
- 下列 13 个 active FORCE provider，用于确定共享策略与 authored override 边界。

## Provider census

13 个 active FORCE provider 中，12 个继承 `std/force.c::hit_ob()` 且没有 override：

- `reference/es2/mudlib/daemon/skill/bolomiduo.c`
- `reference/es2/mudlib/daemon/skill/fonxanforce.c`
- `reference/es2/mudlib/daemon/skill/juechen-force.c`
- `reference/es2/mudlib/daemon/skill/jin-gang.c`
- `reference/es2/mudlib/daemon/skill/gouyee.c`
- `reference/es2/mudlib/daemon/skill/celestial.c`
- `reference/es2/mudlib/daemon/skill/mystforce.c`
- `reference/es2/mudlib/daemon/skill/lotusforce.c`
- `reference/es2/mudlib/daemon/skill/qidaoforce.c`
- `reference/es2/mudlib/daemon/skill/serpentforce.c`
- `reference/es2/mudlib/daemon/skill/snowshade-force.c`
- `reference/es2/mudlib/daemon/skill/wu-shun.c`

它们统一投影为 `CombatHitPolicyStatus.STANDARD_FORCE`，共享一个
`StandardForceHitPolicy`。

唯一 override 是 `reference/es2/mudlib/daemon/skill/iceforce.c:20-34`。它先调用
`::hit_ob()`，然后可能额外令 defender kee wound，并施加 `iceshock` condition。Phase 5B2B1
不能只执行父级而静默省略这个 authored extension，因此 `iceforce` 整体保持
`AUTHORED_POLICY_UNAVAILABLE`；到达该 seam 时既不扣 force，也不执行父级随机或反震。

## Native 边界

`StandardForceHitInput` 是只读标量投影，包含 provider/双方稳定 ID、factor、进入 hook 时的 B、
是否持主武器、双方 force effective-level 的 skill identity + 数值、defender 当前 force，以及独立的
`armor_vs_force`。它不查询 `CharacterSkillState`，也不持有 Equipment、Armor 或 CharacterState。

攻击者当前 force 是会被源规则修改的 authority，因此以
`CharacterInternalResourceState` 单独传入，而不是放进 snapshot。反震只修改攻击者 kee，但反震后的
threshold evidence 必须观察 gin/kee/sen 三主资源，因此 policy 窄传攻击者 essence、vitality、spirit
三个 `CharacterResourceState`；其中只有 vitality 被修改。defender force、双方 effective force skill
与 `armor_vs_force` 都是本次攻击的不可变投影。

`StandardForceHitResult` 区分：

- `NUMERIC_BONUS`：LPC 返回 int，resolver 才把 contribution 加入 B；
- `REFLECTION`：LPC 返回 string；B 不变，result 保存攻击者 damage/wound 及 threshold evidence；
- `NO_NUMERIC_EFFECT`：正常随机条件为 false，等价于 LPC 函数落尾返回 undefined；
- `INVALID_SOURCE_STATE`：在精确随机位置遇到非正 bound、非法 draw 或缺少必要 authority。

Input、result、反震 mutation result 及嵌入 `CombatAttackResult` 的 getter 都提供 defensive value
snapshot。没有共享可变 policy 状态。

## 精确规则与顺序

Resolver 只有在以下条件全部成立时进入 force policy：

```text
force_factor != 0
&& attacker_current_force > force_factor
&& mapped_force_provider exists
```

条件为 false 时不扣 force、不消耗 policy RNG，并继续 Phase 5B2A 流水线。

进入标准 policy 后首先执行：

```text
attacker_force_after = attacker_force_before - factor
force_damage = attacker_force_after / 20 + factor - defender_force / 25
```

除法保留 LPC 整数截断，数值不增加额外 clamp。扣除早于公式、policy RNG 和其后的所有 typed
failure；后续失败不回滚这次突变。

审计以负 attacker/defender force 验证 Godot typed-int 除法与 LPC 所需语义一致：向零截断；公式仍
保持 `attacker_force_after / 20 + factor - defender_force / 25` 的原次序，没有代数重排。

### 负值与反震

若 `force_damage < 0` 且攻击者持主武器，不取反震随机数。返回 `force_damage`；若
`B + force_damage < 0`，则精确返回 `-B`。

若攻击者空手，按源式执行严格比较：

```text
random(defender_effective_force) > attacker_effective_force / 2
```

相等不反震。反震成功时令 `reflection_damage = -force_damage`，并严格按以下顺序修改攻击者 kee：

```text
apply_damage(reflection_damage * 2)
apply_wound(reflection_damage)
```

随后按三主资源记录攻击者 candidate：任一 effective `< 0` 为 `DEATH`；否则任一 current `< 0`
为 `UNCONSCIOUS`；否则为 `NONE`。不执行 lifecycle，也不终止当前普通攻击。源返回的是 narration
string，所以 resolver 不把反震值加给 defender 的 B 或伤害。

### 非负值、armor 与 undefined

初始 `force_damage >= 0` 时才执行：

```text
force_damage -= defender_armor_vs_force
```

这里不使用普通 `armor`。若 `B + force_damage < 0`，在 attacker force RNG 之前精确返回 `-B`。
否则即使 `armor_vs_force` 已令 `force_damage` 为负，仍执行：

```text
random(attacker_effective_force) < force_damage
```

严格 `<` 成立才返回该数值；相等或更大返回 typed `NO_NUMERIC_EFFECT`，明确表示 LPC 的隐式
undefined，而不是伪造一个 authoritative numeric zero。

`NUMERIC_BONUS(0)` 与 `NO_NUMERIC_EFFECT` 明确不同。两个 `return -damage_bonus` 分支在 B 为零时
仍是 LPC integer return，resolver 会按 `intp(foo)` 路径处理数值 0；只有正常随机比较失败后的函数
落尾才是 undefined/no effect。post-armor `force_damage == 0` 仍先消费 attacker-force RNG，再落入
`NO_NUMERIC_EFFECT`。

对 non-positive random bound，沿用 `DECISIONS.md` 已有决定：在源到达该 random 的精确位置返回
typed legacy-invalid failure，并保留此前的 force/反震突变；没有新兼容性决定。

## Resolver composition 与 RNG

结算顺序保持：

```text
base B = query_str
-> standard force hook
-> 仅把 int-equivalent contribution 加入 B
-> action.force percentage
-> martial hook
-> weapon 或 attacker hook
-> random(B)（B > 0）
-> defense loop
-> defender damage/wound
```

force policy 使用 resolver 已注入的同一 `CombatRandomSource`，没有第二条随机流。典型完整顺序为
limb、dodge、parry、base-damage、需要时的一次 force-policy roll、B roll、defense rolls、wound
roll。负且持武器、combined-negative early return 与 false entry predicate 不消费 force RNG；
post-armor negative 但 `B + force_damage >= 0` 仍消费 attacker-force roll。

整个 resolver 不是事务。force 已扣除后若 martial/weapon seam 返回 unavailable，force 突变仍在；
若已发生反震，攻击者 kee damage/wound 也仍在。Result 保存标准 force evidence，而 defender 的普通
damage 尚未执行。攻击者因反震越过阈值也不会让当前攻击提前停止。

`CombatAttackResult` 不单靠 nullable force result 判断状态：尚未到 force seam 与 predicate false 由
`CombatAttackCalculation.reached_stage` 区分；标准完成/反震/no-effect/invalid 由
`StandardForceHitResult` 区分；authored force unavailable 则由 outer outcome、force failure stage 和
provider ID 区分。

## 正式审计修复

正式审计发现初版反震 threshold 只读取反震所修改的 kee，遗漏攻击者已有 gin/sen 阈值。现已把
攻击者三主资源作为窄 authority 输入，并按 death 优先、unconscious 次之的既有角色规则观察；
反震仍只修改 kee。审计同时补齐 signed division、negative factor entry、integer zero vs undefined、
invalid force draw、跨 seam status rejection、独立 armor 值和 threshold 后继续攻击的回归证据。

## 明确延后

- `iceforce` 的额外 defender wound、`iceshock` condition 与 presentation；
- 其余 martial、weapon、NPC authored `hit_ob()`；
- progression、potential、busy、关系、interrupt 执行、post_action、riposte；
- Combat lifecycle、World/NPC runtime、Timer/heartbeat、UI/VFX；
- Phase 5B2B2 及后续普通攻击组合工作。

Phase 5B2B1 没有实现通用 skill callback/daemon dispatch，也没有扩大到完整 CombatResolver。
