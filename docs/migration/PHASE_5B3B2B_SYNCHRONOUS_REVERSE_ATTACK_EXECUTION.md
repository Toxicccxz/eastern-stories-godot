# Phase 5B3B2B — 同步实时反向攻击执行

## 范围与来源

本阶段只消费 Phase 5B3B2A 的终端 `CombatRiposteRequest`，同步执行一次源码等价的 reverse
`do_attack()`，然后返回完整 forward/reverse chain 结果。直接依据：

- `reference/es2/mudlib/adm/daemons/combatd.c::do_attack()`：递归调用位置、reverse weapon 求值、
  普通攻击 body、friendly-stop、post_action 与最终 riposte 谓词；
- `reference/es2/mudlib/include/combat.h`：`REGULAR=0`、`RIPOSTE=1`、`QUICK=2` 与
  DODGE/PARRY sentinels；
- `reference/es2/mudlib/feature/equip.c`：`query_temp("weapon")` 对应当前 primary weapon，且
  wield/unequip 会替换或删除该引用。

没有实现 authored post_action、第二次 riposte、`fight()`、CombatStep、递归器、heartbeat、World/NPC
或 runtime scheduling。

## Source-equivalent chain

```text
closed forward CombatSingleAttackExecutionResult
→ validate terminal reverse request
→ validate post-forward live reverse projection
→ CombatActionSelector
→ CombatAttackCompletionService
→ reverse legacy damage
→ CombatPostRelationshipService
→ reverse post_action seam
→ REVERSE_COMPLETE
```

如果 forward 是 `COMPLETED_WITHOUT_RIPOSTE`，projection 和 RNG 都可以为空且不会被读取。任何 forward
failure/incomplete 也原样成为 `FORWARD_INCOMPLETE`，不会被 reverse 输入错误覆盖。只有 coherent
`REVERSE_ATTACK_REQUIRED` 加合法 request 才进入 reverse。

Reverse 路径直接对应：

```text
do_attack(original_victim, original_attacker,
          original_victim current primary weapon,
          QUICK or RIPOSTE)
```

它不调用 `CombatFightDecisionService`，因此没有 cleanup/select、visibility/perception、courage、guard
decision、reciprocal establishment 或 last-opponent 更新。它也不要求双方仍在 fighting。

## Forward request contract

进入 reverse 前核对：

- request attacker/victim 必须精确等于 forward victim/attacker；
- type 只能 QUICK/RIPOSTE；
- forward 必须是 REGULAR、`legacy_damage < 1`、guard 已清除、riposte RNG 已完成；
- action ID、legacy damage、riposte bound/draw 必须与 forward result 完全一致；
- forward ordinary/post-relationship 已完成、没有 post_action dependency，也没有 winner random。

矛盾 evidence 在 reverse action-selection RNG 前返回 `REVERSE_REQUEST_INCOHERENT`。

## Post-forward live projection

`CombatReverseAttackProjection` 必须在 forward B2A 返回后构造。它只作为同步输入存在，不进入 result。
本阶段不增加 generation counter、version clock 或 provider callback；任意旧 immutable snapshot 的真实构造
时间无法由领域层证明，但会核对所有当前可验证事实。

- `CombatCharacterAuthority` 将 stable CharacterId 绑定到当前 `CharacterState`，使 resources、skills、
  progression 与 Equipment 的归属明确；
- combat_exp、spirit current/max、base intelligence/spirituality、strength/force-factor/modifier、inner force、
  busy 与 relationship owner 必须匹配当前 authority；
- 当前 `CharacterSkillState` 加 typed `CombatReverseModifierProjection` 会重新验证 attack、dodge、parry、
  unarmed、force effective levels，以及 attack/defense usage bonus；该投影还携带双方 stable CharacterId，
  防止把另一角色的 apply/armor 标量与正确的 CharacterState/relationship/equipment 拼接；
- 同一 modifier projection 明确核对 apply damage、armor、armor-vs-force；它不是通用 Dictionary；
- 当前 skill mappings 必须匹配 mapped attack/force IDs 和 action-provider presence；
- 当前 `EquipmentState.primary_weapon()` 的 instance ID、weapon/profile ID 与 skill type 必须匹配 reverse
  attacker snapshot，reverse defender 的 primary-weapon presence 也必须匹配当前 Equipment。

limbs、living、authored policy availability 等由当前 caller/runtime/content adapter 在 forward 后投影；现有
authority 没有版本信息，本阶段不伪造时间证明。尤其 `living()` 是独立 runtime fact：current/effective
resource 已越过 unconscious/death threshold 不会在同步 reverse 中被自动改写成 nonliving，也不会触发
`unconcious()` / `die()`；这些生命周期操作仍发生在未来 outer heartbeat/step 边界。

CharacterState 当前没有 Armor aggregate；apply damage、usage bonus、armor 与 armor-vs-force 因而仍由
caller 在同一 post-forward opportunity 构建。B2B 能核对它们的双方 owner ID、与 attack snapshot 的值一致性，
以及所有能从当前 CharacterSkillState 重算的 effective skill；无法从现有 authority 重算的聚合值不被伪装成
已验证的 CharacterState 字段。

## Reverse weapon、action 与 progression

Reverse weapon 在 chain service 开始 reverse call 时从原 victim 的当前 primary Equipment 读取；request
不含 weapon。Result 只保存该时刻的 stable weapon instance ID 和 profile ID，不在 reverse attack 完成后
重新查询 Equipment。

只读取 primary。若当前只有 secondary weapon，reverse weapon 参数仍为 null，攻击与 action provider 都按
unarmed/default 处理，secondary 保持原位且不会自动提升；reverse defender 的 parry weapon presence 同样只看
primary。审计回归还锁定了 pre-forward OLD primary 在 forward 后被 NEW 替换或被移除时分别使用 NEW 与
unarmed 的时序。

Action acquisition 重新调用已关闭 selector，保持 mapped martial → current primary weapon → default 的
优先级。Request 不保存 forward action 以外的 reverse action。选中的 reverse action 必须逐字段等于
`CombatAttackInput` projection，否则在 resolver RNG/mutation 前失败。

普通攻击完全复用 `CombatAttackCompletionService`。Reverse combat_exp 与 current skill/attribute projection
在 action selection 前验证，因此 forward progression 或 authored skill effect 已改变的状态必须由新的
projection 观察；旧 combat_exp/effective skill/attribute projection 会被拒绝。

QUICK 与 RIPOSTE 使用完全相同的 AP/DP/PP、force、damage/wound、progression、status 与 busy body；
attack type 不进入这些公式。

## Reverse tail semantics

完成 ordinary attack 后保存：

```text
DODGE → -1
PARRY → -2
HIT   → requested D
```

随后始终调用已关闭 `CombatPostRelationshipService`。DODGE/PARRY/HIT 0 不触发 friendly-stop；reverse
正伤 HIT 若仍是 bilateral nonlethal fight，会依次移除 reverse attacker、reverse defender relation，
再消费 exact `random(6)`。任一失败保留已经完成的 damage/progression/relationship mutation。

Reverse selected action 的空 `post_action_policy_id` 直接完成；非空则在 friendly-stop 后返回
`REVERSE_POST_ACTION_UNAVAILABLE`。结果保留 reverse action/policy/双方 IDs、legacy damage 及 reverse
call 起始 weapon IDs，但不保存 Callable 或 mutable weapon。

Reverse type 只可能 QUICK/RIPOSTE，所以源码末尾的 `attack_type == TYPE_REGULAR` 立即为 false。本服务不
读取 reverse victim guarding、不清 guard、不读 raw cps、不消费第二个 riposte RNG，也不产生第二个
request。最大 guarding-riposte 深度严格为一。

## RNG 与 partial mutation

同一个 caller-owned `CombatRandomSource` 从 forward riposte decision 后继续：

```text
forward B1/action/ordinary/progression/riposte decision
→ reverse action selection
→ reverse ordinary/force/progression
→ optional reverse winner random(6)
```

`CombatAttackChainResult` 先复制一次 forward combined evidence，再追加 reverse-local selector、ordinary
与 winner evidence；不会从 forward nested result 重建或重复历史，也没有 reverse perception/courage/
guard/riposte draw。

Forward 与 reverse 之间不是 transaction。Forward guard clear、resources、force、progression、busy 和
relationships 已提交；reverse action failure 不回滚它们。Reverse late failure 也保留此前 damage/wound/
progression，friendly second-removal 或 winner failure保留已完成的 relationship removal，unavailable
post_action 保留全部先前 mutation。

## Final result 与 runtime 边界

`CombatAttackChainResult` 显式区分 forward incomplete/no-reverse、request/context failure、reverse action/
ordinary/relationship/post_action failure 和 reverse complete。它防御性保存 forward/request、reverse
selection/ordinary/relationship 快照、reverse legacy damage presence、起始 weapon IDs、stages 与 combined
RNG evidence。

Result 不持有 CharacterState、attributes、Equipment、relationship、busy、skill/resource authority、RNG 或
CombatAttackInput。它是“一条明确 attack chain”的结果，不是 CombatStep：未来 runtime 仍需在外层按源码
顺序提供 opponent availability、fight decision、当前 projection 与显式 step timing。

## 延后

- Phase 5B4：bash/throw 等 authored `post_action` policies；
- runtime：CombatStep orchestration、heartbeat、flee/auto_fight、World/NPC、presentation 与 lifecycle；
- vertical slice：场景交互、连续 step 请求、动画/UI 与 threshold outer adapter。

本阶段没有发现新的 LPC-to-Godot observable substitution，因此不修改 `DECISIONS.md`。

## 正式审计结论

正式审计修复了一项 native caller-coherence 缺陷：最初的 `CombatReverseModifierProjection` 没有 owner
identity，可能把另一角色的同形 modifier/armor 标量与正确 authority 组合。现以双方 stable CharacterId
绑定并在 reverse action-selection RNG 前拒绝错配；没有增加 Dictionary、provider registry 或新权威状态。

审计同时以确定性回归确认：forward failure/no-request 惰性、完整 request/winner coherence、无需 fighting
前置、threshold 与 lifecycle 分离、primary/secondary 精确区别、current action/weapon/progression freshness、
QUICK/RIPOSTE 共用 ordinary body、reverse friendly orientation、所有非正 damage 分支的 post_action seam、
单一连续 RNG、partial mutation 和最大反击深度一。

Phase 5B3 的 relationship、opponent selection、fight decision、forward attack、friendly-stop、guarding
riposte decision 与一次同步 reverse attack 至此在纯 Combat Core 层正式关闭。该结论不包含 heartbeat、
CombatStep/runtime orchestration、World/NPC、lifecycle 或 presentation 集成。
