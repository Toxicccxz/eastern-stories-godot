# Phase 5B3B1 — `fight()` Decision、Guard 与 Reciprocal Fight

## 范围与权威来源

本阶段迁移 `combatd.c::fight(me, victim)` 在 Phase 5B3A 已选择 opponent 之后的决定逻辑。
它只返回 no-action、QUICK/REGULAR attack intent、进入/保持 guarding 或 typed source failure；
不选择 action、不读取武器、不执行 `do_attack()`，也不组合 friendly stop。

直接依据：

- `reference/es2/mudlib/adm/daemons/combatd.c::fight()`：完整分支、mutation 与 RNG 顺序；
- `reference/es2/mudlib/std/char.c::visible()`：证明可见性依赖 wizard、invisibility、ghost 与
  astral vision，必须由 runtime/world 边界先求值；
- `reference/es2/mudlib/feature/skill.c::query_skill()`：perception effective skill 公式；
- `reference/es2/mudlib/feature/attribute.c`：证明 `query_cor()` / `query_cps()` 会加入 modifier，
  而 `fight()` 实际读取 raw `query("cor")` / `query("cps")`；
- `reference/es2/mudlib/include/combat.h`：`REGULAR=0`、`RIPOSTE=1`、`QUICK=2`。

## Typed 架构

- `CombatAttackType` 保留三个 legacy 数值；本阶段只输出 REGULAR 或 QUICK，RIPOSTE 仅保留给
  Phase 5B3B2；
- `CombatPerceptionSkillProjection` 只接受稳定 skill ID `perception` 和已计算的 effective level；
- `CombatFightDecisionFacts` 保存 stable IDs、living/busy/visible facts、effective perception、
  raw courage/bellicosity/composure；
- `CombatFightDecisionService` 接收 attacker/victim 两份 `CombatRelationshipState` authority，
  但不保存它们；
- `CombatFightDecisionResult` 只保存 scalar evidence、attack intent、ordered RNG evidence、
  mutation evidence 与精确 failure/reached stage。

服务只要求两份 relationship authority 的 owner 与 facts ID 一致且彼此独立；它不要求 attacker
已经把 victim 列为 opponent。直接调用仍可到达 QUICK/REGULAR，此时只按源码补
victim→attacker，绝不补 attacker→victim，也不写 `last_opponent`。

没有 CharacterState、SkillState、Weapon/Equipment、World、Node、Callable、Dictionary payload、
全局 RNG 或 runtime object reference。

## 可见性与 perception 边界

`target_visible` 是 runtime 已求值事实。Combat Core 不复制 `visible()` 的 wizard/invisibility/
ghost/astral rules。

attacker nonliving 是第一门：立即返回，不检查可见性，不消费 RNG，不改 guarding/relationship。
attacker living 后：

```text
if target_visible:
    不消费 perception RNG
else:
    验证 projection.skill_id == "perception"
    bound = 100 + effective_perception
    draw = random(bound)
    if draw < 100: TARGET_NOT_PERCEIVED
    else: continue
```

相等 `draw == 100` 继续。effective perception 保留：

```text
apply/perception + raw perception / 2 + raw(mapped perception skill)
```

服务不查询 `CharacterSkillState`；调用者负责生成 projection。可见路径不会提前验证 perception
identity 或 bound。到达的非正 bound 与越界 draw 在确切位置返回 typed failure，无 clamp、无 mutation。
`CombatRandomSource` 同样只在实际到达 `random()` 时才要求存在；attacker nonliving 与可见
QUICK 可在没有 RNG source 时正常完成。

## QUICK

perception 通过后，只要 `victim_busy || !victim_living` 即进入 QUICK：

1. attacker guarding 设为 false；
2. 若 victim 尚未把 attacker 作为 opponent，则只调用 victim `add_opponent(attacker)`；
3. 返回 `CombatAttackType.QUICK` intent。

不消费 courage 或 guard RNG。victim nonliving 仍可被 QUICK；不新增 lethal marker，也不对 attacker
侧补关系。unexpected reciprocal add failure 发生在 guard clear 之后，故 guard clear 保留并由 result
报告 partial mutation；不产生 attack intent。

这里的 native `victim.add_opponent(attacker)` 只迁移 `fight_ob()` 的关系变更部分。旧
`feature/attack.c::fight_ob()` 还会先执行 `set_heart_beat(1)`；该副作用属于 MudOS/runtime
调度边界，明确延后，不能把当前关系追加误解为完整复刻旧 runtime operation。B1 不引入
Timer、heartbeat 或任何调度 intent。

## REGULAR 与 raw 属性

仅 victim living 且不 busy 时到达：

```text
bound = victim_raw_cps * 3
draw = random(bound)
threshold = attacker_raw_cor + attacker_raw_bellicosity / 50
regular = draw < threshold
```

严格 `<`，相等失败。`bellicosity / 50` 保留 signed integer truncation。这里没有 `query_cps()` 或
`query_cor()`，因此不加入 force_factor、apply/composure 或 apply/courage，也不设置 threshold clamp。

非正 courage bound 在调用位置返回 typed failure；QUICK 不会预验证它。合法 draw 之后才计算
threshold，保持 LPC 左操作数 `random(...)` 先执行的证据顺序。REGULAR 成功后的 mutation 顺序与
QUICK 相同：先清 attacker guard，再只补 victim→attacker，最后返回 REGULAR intent。

## Guard

courage 比较失败时：

- attacker 已 guarding：返回 `REMAIN_GUARDING`，不改关系、不消费 `random(5)`；
- attacker 未 guarding：先设 guarding=true，再消费固定 `random(5)`，返回 presentation index
  `0..4` 与 `ENTERED_GUARDING`。

五条 legacy guard 文本未迁移。guard RNG 缺失/越界时 guarding mutation 保留，不回滚；index 0
通过显式 presence 字段与未到达状态区分。Guard 分支从不建立 victim reciprocal opponent。

## RNG 连续性

B1 使用调用者传入的同一个 `CombatRandomSource`，不拥有私有 RNG。可能序列为：

```text
visible QUICK:                  []
invisible QUICK:                perception
visible REGULAR:                courage
invisible REGULAR:              perception -> courage
visible new guard:              courage -> random(5)
invisible new guard:            perception -> courage -> random(5)
already guarding:               courage
```

未来 Phase 5B3B2 可在同一流上组合：Phase 5B3A `random(4)` → 本阶段 rolls → action/ordinary
attack/progression → friendly winner `random(6)` → later riposte。Result 只记录实际尝试的 draw，
不会复制 RNG authority。

## 明确延后

- Phase 5B3B2：action projection、普通攻击执行、friendly-stop 组合、post_action、guarding riposte、
  reverse/nested attack 与完整 combat step；
- Phase 5B4：authored martial/weapon/NPC policies；
- heartbeat、flee、auto_fight、NPC aggression、World/runtime、Timer、lifecycle、UI/动画/文本渲染。
