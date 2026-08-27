# Phase 5B3A — Combat Relationship Orchestration、Opponent Selection 与 Friendly Stop

## 范围与权威来源

本阶段只迁移普通攻击周围已经可独立证明的关系规则：攻击前清理对手、按 `random(4)`
选择一个对手、在后续攻击前记录 `last_opponent`，以及 Phase 5B2B2 完整正伤害 HIT 后的
双向非致死 friendly stop。没有实现 fight 决策、互相开战、guard/riposte、post_action、
combat step、自动战斗、NPC 主动攻击、世界查询、heartbeat、Timer 或表现文本。

直接依据：

- `reference/es2/mudlib/feature/attack.c`：`enemy` / `killer` / `last_opponent` 的关系语义、
  `clean_up_enemy()` 的删除谓词与旁路删除、`select_opponent()` 的固定 `random(4)` 偏置，以及
  `attack()` 中 cleanup → selection → `last_opponent` → 后续 fight 的顺序；
- `reference/es2/mudlib/adm/daemons/combatd.c`：完整 HIT 的 `damage > 0` 后，双方均为普通
  opponent 且互不为 killer 时，先删除 attacker 一侧、再删除 defender 一侧，最后
  `winner_msg[random(6)]`；源码中 `winner_msg` 恰有六项；
- 已关闭的 `CombatRelationshipState`、`CombatAttackCompletionService` 与
  `CombatOrdinaryAttackResult`：本阶段只在这些既有权威和结果之后组合规则。

## 关系状态与可用性投影

`CombatRelationshipState` 继续唯一持有有序 opponent ID、lethal target ID、targetless guarding 布尔值和
`last_opponent`。内部 seam `_remove_opponent_for_cleanup()` 只从 opponent 顺序中删除目标，故意不
清除 lethal marker；它以下划线和 cleanup 专用名称限制为本阶段选择服务的源码等价编排入口，
ordinary transition 仍必须调用 `remove_opponent()`。这对应 `clean_up_enemy()` 直接改写
`enemy` 数组而不调用 `remove_enemy()` 的行为。

`CombatOpponentAvailabilityFacts` 是调用者提供的一次性窄投影，只包含：

- stable opponent `CharacterId`；
- 对象是否仍存在；
- 是否与关系 owner 位于同一位置；
- 是否仍为 living。

它不是 World/NPC authority。服务要求该批投影与清理开始时的 opponent 快照一一对应，拒绝
缺项、多项、重复 ID 或未知 ID，并且在拒绝时不修改关系、不消耗 RNG。

清理按 opponent 插入顺序执行。下列任一条件成立即删除：

```text
!exists
|| !same_location
|| (!living && !has_lethal_target(opponent_id))
```

因此，同位置、非 living、仍带本地 lethal marker 的目标继续保留；不存在或异地目标即使带
marker 也从 opponent 列表删除，但 marker 本身保留。若中途出现关系不变量失败，已完成的前序
删除不回滚，并由 typed result 报告。

## 对手选择与 `last_opponent`

清理后无对手时，不调用 RNG，也不改 `last_opponent`。有对手时严格执行一次：

```text
draw = random(4)
selected_index = draw < opponent_count ? draw : 0
```

这保留原始固定上界和对首项的偏置，而不是按列表长度均匀采样。结果记录 RNG 是否到达、是否
尝试、上界 `4`、draw、选择索引和 stable ID。缺少 RNG 或 draw 越界发生在 cleanup 之后，故
已完成的清理保留，`last_opponent` 不变。

只有成功选出目标后才写入 `last_opponent`。这对应 `attack()` 在进入尚未迁移的后续 fight
逻辑之前记录目标的顺序；本阶段不调用或模拟该 fight。

## Phase 5B2B2 后的 friendly stop

`CombatPostRelationshipService` 只接受已完成的 `CombatOrdinaryAttackResult`。它不会重新计算
Phase 5B2A/5B2B1/5B2B2 规则。只有以下门成立才检查关系：

```text
base outcome == HIT
&& requested_damage > 0
```

这里使用 resolver 记录的请求伤害 `D`，而不是 current-resource 的实际饱和 delta；DODGE、
PARRY、`D == 0` 或未完整完成的 ordinary attack 均不修改关系、不消耗 winner RNG。

friendly stop 的完整谓词为：

```text
!attacker.has_lethal_target(defender)
&& !defender.has_lethal_target(attacker)
&& attacker.has_opponent(defender)
&& defender.has_opponent(attacker)
```

命中后顺序严格为：

1. 从 attacker 的 opponent 中删除 defender；
2. 从 defender 的 opponent 中删除 attacker；
3. 调用一次 `random(6)`，仅返回 `0..5` 的 presentation index 证据。

没有迁移六条文本。winner RNG 缺失或越界发生在双方删除之后，因此两侧关系删除仍保留；第二侧
删除失败时，第一侧删除同样不回滚。结果显式报告失败阶段和 partial mutation。guarding、
`last_opponent`、lethal marker 及无关 opponent 均不被修改。busy 是否在 Phase 5B2B2 被清除不是
额外门：integer busy cleared、integer busy remained 和 function-busy/integer-interrupt no-op 只要
ordinary result 完整完成，都继续执行本阶段规则；function-interrupt unavailable 则仍是 prior failure。

## 身份、结果与依赖边界

所有关系比较使用 native stable `CharacterId`。原 LPC `killer` 字符串使用 public `id`，可能让
同 public ID 的不同实例互相命中；本阶段不复制该身份碰撞。legacy public ID 只适合作为迁移
元数据或导入证据。

选择结果与 post-relationship 结果都是不可变值快照；数组 getter 返回 defensive copy，
ordinary attack 子结果也重新快照。post-relationship 调用者必须把完成前序 ordinary attack 后的同一
`CombatRandomSource` 继续传入；结果只拼接既有 RNG evidence 与本阶段一次 winner draw，不复制
历史 draw，也不持有 RNG。selection 服务使用相同接口，使 5B3B 可按 select `random(4)` → attack
draws → winner `random(6)` 组成单一顺序流。服务不持有 authority，不使用 Dictionary payload、Callable、
Node、signal、Timer、SceneTree、全局 RNG 或隐式共享状态。

## 测试覆盖

定向测试以 LPC 常量和分支独立写出期望，覆盖：

- 全保留、全部/部分清理、lethal/non-living 例外、异地 lethal marker 保留；
- 可用性批次缺项、多项、重复、乱序，以及确定性插入顺序；
- 1、2、3、4、5+ 对手下 `random(4)` 的精确映射和首项偏置；
- 空列表不取 RNG、非法/缺失 RNG 的 cleanup 后 partial state、`last_opponent` 顺序；
- 双向 friendly stop、双方删除顺序、六个 winner index、缺失/非法 winner RNG；
- DODGE、PARRY、零伤害、单向关系、任一 lethal 方向和未完成 ordinary attack；
- 请求伤害与实际资源 delta 的区别、death threshold 不提前截断；
- 两个独立角色、stable ID 隔离、无关关系/guard/last 保留及 defensive snapshots。

定向 runner 同时回归 Phase 5B1 foundation 与 Phase 5B2B2 completion，当前共通过 512 条断言。

## 明确延后

- Phase 5B3B 或后续：是否/何时开始 fight、互相建敌、guard/riposte、combat step 和自动战斗；
- post_action、authored martial/weapon/NPC hooks 与高级 hit policies；
- World/NPC/runtime 提供真实存在性、位置与 living 投影的适配器；
- heartbeat、Timer、循环调度、表现文本、动画、UI 与 winner message 渲染；
- death/unconscious/corpse 生命周期执行。
