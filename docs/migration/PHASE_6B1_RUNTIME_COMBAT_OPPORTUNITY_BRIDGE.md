# Phase 6B1 — Runtime Character Binding + Current Projection + One Combat Opportunity

## 范围与结论

Phase 6B1 增加了第一条无 `Node` 的 Runtime → closed Combat Core 桥接路径：致死关系初始化与一次 actor 外层战斗机会。它不拥有 cadence，不执行昏迷/死亡，不创建场景、UI、尸体或 authored combat policy。

来源依据沿用已关闭的 Phase 6A 分析，并在实现默认徒手投影时直接复核了 `reference/es2/mudlib/adm/daemons/race/human.c:8-24,83-86`。主要可追溯来源：

- `reference/es2/mudlib/std/char.c:56-122`：外层 death → unconscious → busy → fight 顺序；
- `reference/es2/mudlib/feature/damage.c:91-161`：current/effective 阈值及 unconscious/death 分界；
- `reference/es2/mudlib/feature/attack.c`：killer/enemy、guarding、opponent cleanup；
- `reference/es2/mudlib/adm/daemons/combatd.c`：fight/do_attack 顺序和 raw cor/cps 读取；
- `reference/es2/mudlib/adm/daemons/weapond.c:7-11`：slash authored action；
- `reference/es2/mudlib/adm/daemons/race/human.c:8-24,83-86`：human limbs/default unarmed action provider；
- `reference/es2/mudlib/d/oldpine/obj/long_sword.c`、`std/weapon/sword.c`：`sword`、damage 25、无 authored `hit_ob`。

## Node-free Runtime 边界

`CombatSliceCharacterBinding` 只关联第一切片所需 authority：

- stable `CharacterId`；
- `CharacterState`（其 `equipment` 仍是唯一手持槽 authority）；
- `CombatRelationshipState`；
- integer-only `ActionBusyState`；
- `ArmorState`；
- immutable/value-like `CombatSliceContentProfile`；
- `location_id`、encounter existence、runtime life status、user/combat-available facts。

构造一致性要求 non-empty ID/location，relationship owner 必须等于 binding ID。一次机会还拒绝重复 ID，或在参与者之间共享 `CharacterState` 及其 attributes/resources/recovery/skills/progression/equipment、relationship、busy、armor authority。内容 profile 可按值重建，不持有可变角色状态。

Runtime life status 是 `ACTIVE / UNCONSCIOUS / DEAD`。它不由资源 getter 自动同步；资源已经越过阈值而 runtime 仍为 `ACTIVE` 是合法的、且是外层 lifecycle gate 所需的中间状态。

## Content profile

第一切片只声明已核实内容：

```text
d/oldpine/obj/long_sword.c
→ std/weapon/sword.c
→ skill_type sword
→ damage 25
→ es2:adm/daemons/weapond/slash
```

slash action set 恰好一项：damage/force percent 均为 0，damage type 为 `割伤`，legacy text 为 `$N挥动$w，斩向$n的$l`，post-action policy 为空。weapon hit policy 明确为 `PROVEN_NO_AUTHORED_EFFECT`。这只是 slice restriction，不表示所有 sword 只有 slash。

无 primary 时使用 `race/human.c` 第一条真实 default action（挥拳、`瘀伤`）组成一项 slice fallback。它是明确、可追溯的第一切片配置，不宣称已经迁移 human 原始五项随机分布。present 但不匹配 verified long sword 的 primary provider 返回 typed data-unavailable，绝不回退到徒手。

limbs 是 `human.c` 的 16 项快照；数组和 action set 均防御复制。visibility 明确投影为 `true`，同时仍提供结构有效的 effective perception projection；visible 分支不消耗 perception RNG。

## 致死初始化

`initiate_lethal_combat()` 与 opportunity 完全分离。它在任何 mutation 前验证双方 binding、encounter existence、ID 不同、同 location、target 非 `DEAD`，然后保持 NPC kill 顺序：

1. initiator 对 target `mark_lethal_target()`；
2. target 对 initiator `mark_lethal_target()`。

操作不原子化。第二步失败时第一步保留；result 分别记录两步 attempted/changed/succeeded 和 partial-mutation evidence。初始化不接收 RNG，也不自动执行一次战斗机会。

## Lifecycle 与 busy 顺序

每次 opportunity 开头先读取当前资源：

1. 任一 effective gin/kee/sen `< 0` → `LIFECYCLE_REQUIRED_DEATH`；
2. 否则任一 current `< 0`：runtime `ACTIVE` → `LIFECYCLE_REQUIRED_UNCONSCIOUS`，runtime `UNCONSCIOUS` → `LIFECYCLE_REQUIRED_DEATH`；
3. 已为 `DEAD` 且没有待执行阈值时按 `ACTOR_NOT_ACTIVE` 处理。

6B1 只返回证据：不清零资源、不改 life status、不清关系、不建尸体。命中 lifecycle 时不推进 busy、不 selection、不消耗 RNG。

无 lifecycle 后才检查 exists/ACTIVE/combat-available。随后若 `ActionBusyState.is_busy()`，只调用一次 `advance()` 并立即返回；没有第二套 cooldown。当前 authority 有意只能表示 integer busy；legacy function-busy 仍不可执行，未被伪装成 integer busy。

## 当前投影与一次 opportunity

`CombatSliceProjectionBuilder` 无状态、无 registry/service locator。它按调用点构造：availability、fight facts、action source、attack input、progression facts、busy projection、reverse projection。

正式顺序为：

1. lifecycle threshold gate；
2. actor runtime availability；
3. busy advance gate；
4. 从当前 relationship opponent IDs 构造 availability；
5. `CombatOpponentSelectionService.prepare()`；
6. 对已选择 binding 构造当前 fight facts；
7. `CombatFightDecisionService.decide()`；
8. guard/no-action 直接返回；
9. QUICK/REGULAR 才读取当前 primary 并构造 forward projections；
10. `CombatSingleAttackExecutionService.execute()`；
11. 只有 forward 返回 riposte request 时，才从 live post-forward authorities 构造 reverse projection；
12. `CombatAttackChainCompletionService.complete()`；
13. 返回 typed opportunity result，不做 post-chain lifecycle。

availability 的 `exists` 来自 encounter existence 且 status 非 `DEAD`；`same_location` 比较 stable location IDs；`living` 只来自 runtime `ACTIVE`，绝不从资源阈值推导。无法从显式 participants 解析的已知 opponent 投影为 `exists=false`，没有全局 entity/world registry。

Fight projection 使用 raw `cor`、raw `bellicosity`、raw victim `cps`，不会用 effective courage/composure 代换。attack/progression/armor/equipment 数值均由当前 closed authorities 和 typed armor aggregate 生成，没有复制 `query_skill()` 公式。

## Live reverse 与 RNG

Reverse projection 只在 forward 已返回 request 后建立，并重新读取双方：CharacterState、skills/progression、primary equipment、armor、busy、relationships。测试让 forward DODGE progression 将未来 reverse attacker 的 `combat_exp` 从 10 改为 11，并证明 reverse projection 观察到 11 后成功执行，排除了 stale prebuilt reverse snapshot。

调用者提供的同一个 `CombatRandomSource` 连续流经 opponent selection、fight、forward action/resolution/progression/riposte 和 reverse。B1 不提供 Godot RNG adapter。Opportunity result 不保留 RNG authority；它组合 selection 与 chain 已拥有的 defensive RNG evidence，并避免重复计入 chain 内已包含的 fight/forward timeline。

## Result

`CombatSliceOpportunityResult` 显式区分 lifecycle、actor unavailable/inactive、busy advanced、no opponent、selection/fight failure、guard/no-action、chain complete/incomplete。它保存 value-like child snapshots、终止阶段、busy before/after、reverse 是否延迟建立以及建立时 reverse attacker 的 combat experience。

Result 不保留 CharacterState、relationship、equipment、armor、busy、RNG 或 Node authority；所有数组和 nested child results 经防御复制或按需组合。

## 正式审计结果

正式审计修正了两个生产边界问题：

- primary weapon 的“槽位存在”与“slice provider 数据可用”必须分别投影；未知 primary 现在保持 present，并由 closed selector 返回 typed data-unavailable，不会错误落入 human unarmed fallback；
- participant coherence 现在检查 `CharacterState` 内所有会被本机会读取或改变的嵌套 authority，避免两个不同顶层 state 静默共享 attributes、resources/recovery、skills、progression 或 equipment。

测试同时补强了：双方 lethal + opponent 建立顺序、非 `DEAD` 的 nonliving/threshold-crossed target 发起、第二侧部分 mutation、availability gate 不推进 busy、lifecycle/death priority、secondary-only fallback、当前 armor、插入顺序、post-forward live reverse、跨 actor threshold 延迟处理、RNG 精确时间线、result 防御快照，以及前向 mutation 后反向失败不回滚。完整 runner 现已正式注册 Phase 6B1。

Phase 6B1 正式关闭 Node-free Runtime → Combat Core single-opportunity bridge。此结论不表示 scene/runtime cadence、lifecycle/corpse 或 first playable slice 已完成。

## 验证与延期

Godot 4.7.2 验证结果：

- Phase 6B1 focused + closed Phase 4A1/5B1/5B2B2/5B3A/5B3B1/5B3B2A/5B3B2B targeted regressions：1461 assertions PASS；
- complete project suite：5685 assertions PASS；
- headless editor/project load：PASS（项目扫描、脚本类注册及编辑器初始化完成）。

明确延期：

- Phase 6B2：scene、CharacterBody、input/UI/presentation、encounter Timer/cadence、Godot RNG adapter；
- Phase 6B3：unconscious/death transition、relationship lifecycle cleanup、corpse/death inventory、revive/ghost；
- Phase 5B4：authored hit/post_action/perform/exert/cast/conjure policies；
- 完整 human default action distribution、完整 sword action distribution 与 authored content migration。
