# Phase 5B3B2A — 单次攻击组合、Post-Action 边界与反击决定

## 范围与权威来源

本阶段只组合一条已确认的 B1 `QUICK` / `REGULAR` 攻击意图，并在需要反向攻击时返回终端请求；
不执行反向攻击，不实现 authored `post_action`，也不建立 CombatStep、递归器或运行时调度。

- `reference/es2/mudlib/adm/daemons/combatd.c::do_attack()`：action、ordinary attack、
  friendly stop、`post_action` 与 guarding riposte 的完整顺序；
- `reference/es2/mudlib/include/combat.h`：`REGULAR=0`、`RIPOSTE=1`、`QUICK=2`、
  `RESULT_DODGE=-1`、`RESULT_PARRY=-2`；
- `reference/es2/mudlib/feature/dbase.c::query_entire_dbase()`：返回底层 dbase mapping 本身，证明
  `my["cps"]` 在反击位置观察的是 forward attack 后的实时原攻击者 raw cps；
- `reference/es2/mudlib/adm/daemons/weapond.c`：实际 action `post_action` 是 bash/throw 等尚未
  迁移的程序闭包，不能当成 no-op。

本阶段复用已关闭的 `CombatActionSelector`、`CombatAttackCompletionService`、
`CombatPostRelationshipService` 和 `CombatFightDecisionResult`，不复制其公式或关系谓词。

## 单次组合顺序

```text
B1 QUICK / REGULAR intent
→ CombatActionSelector
→ selected action 与 CombatAttackInput projection 精确一致性检查
→ CombatAttackCompletionService
→ legacy damage 映射
→ CombatPostRelationshipService
→ post_action seam
→ REGULAR + damage < 1 + live victim guarding
→ clear victim guard
→ random(live original attacker raw cps)
→ optional CombatRiposteRequest
```

`REGULAR` 的数值为 0；能否执行只看显式 `has_attack_intent`。B1 已完成的 guard 清除或
victim→attacker opponent 追加均已提交，后续任何 failure 都不回滚。

正式审计同时收紧 B1 terminal evidence：合法 REGULAR/QUICK 必须同时匹配 outcome、attack type、
`has_attack_intent` 与 completed stage；合法 non-attack outcome 也必须匹配其原始 reached stage 且没有
attack type。互相矛盾的 outcome/type 不能被当成普通 no-op。

正式审计补入一个窄的 `CombatRawComposureAuthority` 输入：它只把 stable attacker ID 绑定到同一
forward `CharacterState.attributes` 实例，并提供当前位置的 raw composure。组合器在 action selection
之前同时核对 B1 IDs、attack projection IDs、progression facts IDs、relationship owner IDs 与该实例
绑定；不一致时保留已提交的 B1 mutation，但不消费 B2A RNG、不执行 ordinary attack。该 live authority
不会进入 result 或 reverse request，也不是通用 character/provider 接口。

Action selection 保持 mapped martial → primary weapon → default actions，且继续使用同一
caller-owned `CombatRandomSource`。为组合完整 RNG 证据，`CombatActionSelectionResult` 只增补了
选择位置的 bound/draw 快照，算法未改变。选中的 `CombatActionDefinition` 必须逐字段等于现有
`CombatAttackInput` action projection，否则在 resolver RNG 与 mutation 之前 typed failure。

## Legacy damage、friendly stop 与 post_action

完成 ordinary attack 后产生显式 presence/value：

```text
DODGE  → -1
PARRY  → -2
HIT    → resolver requested D
```

HIT 使用 requested D，不使用被 `-1` 下限截断后的实际 kee 差值。HIT `D == 0` 是已到达的 0；
ordinary incomplete 则没有 legacy damage。

随后先调用既有 friendly-stop 服务。DODGE、PARRY、HIT 0 得到既有 non-applicable 结果并继续；
正伤害 bilateral nonlethal fight 可依次移除双方关系并消费 winner `random(6)`。任何 typed
relationship failure 都在此停止并保留先前 mutation。

对所有完成的 DODGE、PARRY、HIT 0、HIT 正伤害，`post_action` 都在 friendly-stop 后到达：

- 空 `post_action_policy_id`：源码 action 没有函数，继续；
- 非空 ID：返回 `AUTHORED_POST_ACTION_POLICY_UNAVAILABLE`，保留 policy/action/双方 ID、legacy
  damage 与稳定 weapon ID 证据；不读取或清除 guarding，也不产生反击请求。

weapon ID 来自传入 ordinary resolver 的同一 forward `CombatAttackerSnapshot.weapon_profile`，不是
post-action 时重新查询 Equipment，也不是未来 reverse attack 的武器 projection。

Result 不保存 CharacterState、RelationshipState、Attributes、Equipment、weapon object、Callable
或 RNG authority。

## Guarding riposte

精确谓词为：

```text
original attack type == REGULAR
and legacy damage < 1
and live victim relationship is guarding
```

因此 REGULAR DODGE、PARRY、零伤 HIT 可触发；正伤 HIT 和所有 QUICK 不能触发。进入分支后严格
先把 victim guarding 清为 false，再读取原攻击者当前 `CharacterBaseAttributes.composure`（raw cps）。
它不是 victim cps、`effective_composure()` 或 B1 的旧 projection；此前 progression 及 authored
skill-improvement effect 对 raw cps 的修改会立即影响 bound。

```text
bound = live original attacker raw cps
draw = random(bound)
draw < 5  → QUICK request
draw >= 5 → RIPOSTE request
```

`draw == 5` 为 RIPOSTE；bound 1..5 的合法 draw 全为 QUICK。不 clamp。bound 非正或 injected draw
越界会在源码位置 typed failure，且已经完成的 victim guard clear 保留。

## 反向请求与同步边界

`CombatRiposteRequest` 只含显式 presence、交换后的 stable character IDs、QUICK/RIPOSTE type、
forward action ID、legacy damage 与 riposte bound/draw。它不含 reverse `CombatAttackInput`、
attacker/defender snapshots、reverse action、weapon profile 或 mutable authority，因为反向攻击必须
观察 forward attack 完成后的实时状态。

Phase 5B3B2B consumer 必须同步走直接 `do_attack` 等价执行，不能重新调用 `fight()`，所以不重跑
visibility/perception、courage、guard decision 或 reciprocal establishment。请求 type 只能是
QUICK/RIPOSTE，而源码仅 REGULAR 可再次进入 riposte，故深度最多一层。反向调用之后源码没有父调用
的后续 gameplay mutation；请求是终端 continuation，无需通用递归或 scheduler。

## RNG 时间线与延后项

Result 按 B1 → action selection → ordinary resolver → progression → optional winner `random(6)` →
optional riposte random 合并，每个真实调用恰好一次，不重复嵌套 ordinary 证据。正伤害 friendly
winner 与 riposte RNG 因 `damage > 0` / `damage < 1` 自然互斥。

明确延后：Phase 5B3B2B 的实时 reverse projection 与同步执行；Phase 5B4 的 bash/throw 等 authored
`post_action`；完整 CombatStep、heartbeat、flee、auto_fight、World/NPC、Timer、UI/动画与文本。
