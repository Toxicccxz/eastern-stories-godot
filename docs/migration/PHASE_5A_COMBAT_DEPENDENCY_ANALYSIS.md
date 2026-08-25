# Phase 5A：Combat Dependency Analysis

## 1. 范围与结论

本阶段只分析原 ES2 战斗依赖，不实现 Combat GDScript、Resource、运行时调度或测试。
权威行为来自 `reference/es2/mudlib/`；既有 Character、Skill、Equipment、Armor、
Inventory 与 Death/Corpse 领域边界保持不变。

核心结论如下：

1. 旧战斗不是一个单独的 `combatd` 算法。`std/char.c` 负责心跳顺序，
   `feature/action.c` 负责 busy，`feature/attack.c` 保存敌对关系与选择对手，
   `adm/daemons/combatd.c` 决定是否出手并结算一次攻击，`feature/damage.c` 执行
   gin/kee/sen 资源变更和后续生命阈值处理。
2. 最小 native Combat Core 应把“一次明确调用的战斗 step”与“一次攻击 resolution”分开。
   Godot runtime 决定何时请求 step；Game Core 决定守势、命中、闪避、招架、伤害、创伤及
   阈值候选。不能重建 MudOS `heart_beat()`。
3. 普通攻击可以在不迁移全部武学的前提下实现。第一批只需 basic `unarmed`、`dodge`、
   `parry`，一个人类默认动作集，再加一套标准武器动作数据；已映射的 authored martial
   action、`hit_ob`、perform/exert/cast/conjure 可通过窄接口后续加入。
4. `skill_power()`、随机调用顺序、整数除法位置和 damage/wound 顺序必须逐字保留。
   这些规则存在多个看似不合理但可执行的边界，不能用现代化 clamp 或概率简写替代。
5. Combat 只应报告 `unconscious_candidate` / `death_candidate`。它不清条件、不发奖励、
   不转 ghost、不销毁 NPC，也不创建尸体；未来 outer death runtime 再调用已关闭的 Phase 4B5C。
6. Phase 5B 可以安全开始，但应分成至少三个小实现单元；不应一次迁移 `combatd.c` 的普通
   攻击、NPC 自动攻击、死亡奖励和所有 authored specials。

主要证据：`std/char.c:56-131`、`feature/action.c`、`feature/attack.c`、
`adm/daemons/combatd.c:163-500`、`feature/damage.c:12-170`。

## 2. 中央源架构与依赖方向

```text
MudOS heart_beat / room init / command parser          [runtime]
                    |
                    v
std/char.c::heart_beat()                               [ordering]
  death -> unconscious -> busy -> flee -> attack
                    |
                    v
feature/attack.c                                       [relationship state]
  enemy[] / killer[] / guarding / opponent selection
                    |
                    v
combatd.c::fight() -> combatd.c::do_attack()           [combat rules]
  action -> AP/DP/PP -> damage -> wound -> progression
       |             |             |
       |             |             +-> feature/damage.c
       |             +-> feature/skill.c + equipment apply values
       +-> race / weapon / daemon/skill authored action providers
                    |
                    v
future outer lifecycle                                  [not Combat Core]
  unconscious/revive or die/reward/ghost -> Phase 4B5C corpse inventory
```

`adm/daemons/combatd.c` 同时混入四类职责：纯数值规则、authored hook dispatch、中文战斗
文本、NPC 自动战斗及死亡奖励。Native 不应复制这个单体 daemon。建议的最窄职责是：

- `CombatRelationshipState`：一次运行会话中的对手、致死意图目标、last opponent 与 guarding；
- `CombatBusyState`（或更通用的 `ActionLockState`）：整数 step busy；
- `CombatModifierSnapshot`：一次结算所需的已聚合标量，只读、非权威；
- `CombatActionDefinition` 与 selector：typed authored data 与确定性选择；
- `CombatMath`：`skill_power` 等无副作用公式；
- `CombatResolver`：按固定顺序执行一次攻击并返回 structured result；
- `CombatStepService`：选择对手、决定 attack/guard、调用 resolver；
- runtime adapter：地图同场、输入、时间、动画与 NPC encounter 触发。

不要把这些全部塞进 `CharacterState`。当前/有效/最大资源、attributes、progression、skills
仍由现有 closed Character domains 权威持有；Inventory、Equipment 与 Armor 仍为并列 authority。

## 3. Combat state：源事实与 native authority

| 源事实 | LPC 形态与生命周期 | Native 结论 |
|---|---|---|
| `enemy` | `feature/attack.c` 每个角色的 `static object *`；不随角色存档 | `CombatRelationshipState` 中的稳定 CharacterId、有序；不是对象引用 |
| `killer` | 每角色 `static string *`；存的是目标 `id`，离开房间后仍保留 | 同一 relationship state 中的 lethal-target CharacterId；需记录旧版按别名 ID 比较的差异 |
| `biwuer` | 声明后从未读取或写入 | D 类死状态，不迁移 |
| last opponent | `query_temp("last_opponent")` 对象引用 | relationship/session state 的可选 CharacterId |
| guarding | `query_temp("guarding")`；`fight()` 写入，出手或 riposte 时清除 | relationship combat stance/state，不是 Character persistent state |
| last damage source | `query_temp("last_damage_from")` 对象引用 | damage result 中的 source CharacterId；outer lifecycle 保存所需归因 |
| fight vs kill | fight 是相互 `enemy`；kill 另把目标 ID 放入 `killer` | opponent relation 与 unilateral lethal intent 必须分开 |
| busy | `feature/action.c` 的 `static mixed` | 独立 typed action-lock authority；普通 Combat 只需要整数型与 busy bool |
| `actions` | dbase 中的 mapping 或 closure，通常由 `reset_action()` 派生 | 不持久化；攻击时从 loadout + primary weapon + race/default data 派生 |
| `apply/*` | temp dbase，装备和 specials 动态相加 | 不建通用 Dictionary authority；由各 owner 生成一次 `CombatModifierSnapshot` |

旧 `enemy` 用对象身份，而 `killer` 用可重复的显示/命令 `id` 字符串；因此两个不同对象若共享
ID 会被同一 lethal marker 匹配。Native 应使用稳定 CharacterId，保留 legacy ID 作为导入/追踪
metadata；是否刻意复制“同 ID 连坐”属于未来兼容决定，不应在 Phase 5B 默默决定。

`enemy` 没有四人容量限制。限制出现在选择算法：`random(4)` 得到 0..3，索引超出当前数组时
回退 `enemy[0]`。所以两名对手时第一个被选中概率 3/4；三名时第一个为 1/2；超过四名时第
五名以后永不被选中，但仍存在于 `enemy`。证据：`feature/attack.c:8-12,123-147`。

关系清理也是单边的：`remove_enemy(target)` 在本角色仍把 target ID 视为 `killer` 时拒绝；
`remove_all_enemy()` 会请求每个对手反向移除自己，但不检查对方是否因 lethal marker 拒绝，最后仍
无条件清空自己的 enemy。`remove_all_killer()` 才会清自己的 lethal markers，并请求对方
`remove_killer(this)`。因此 relationship authority 必须能表达 A 对 B lethal、B 仅 reciprocal fight
的非对称状态；不能只保存一个 encounter-wide “双方正在战斗” bool。证据：
`feature/attack.c:149-195`。

## 4. 心跳、busy 与显式 combat step

### 4.1 `std/char.c::heart_beat()` 精确顺序

1. 任一 `eff_gin/eff_kee/eff_sen < 0`：清 enemy，调用 `die()`，立即 return。
2. 否则任一 `gin/kee/sen < 0`：清 enemy；非 living 再 `die()`，否则 `unconcious()`；return。
3. 若 busy：只调用 `continue_action()`，然后 return。该次不会逃跑、攻击、NPC chat、推进长 tick、
   更新 condition、恢复或更新年龄。
4. 非 busy 且正在战斗时，若 `env/wimpy > 0` 且任一当前资源百分比 `<= wimpy`，调用 flee。
5. 无论 flee 是否发生都调用 `attack()`；成功移动会在 `go.c` 清 enemy，所以 `attack()` 只清理。
6. NPC 执行一次 chat；chat 可销毁自己。
7. `tick--` 非零则 return；为零时重置为 `5 + random(10)`，然后 condition update。
8. 当前 condition cycle 未返回 `CND_NO_HEAL_UP` 才调用 `heal_up()`；和平且无恢复工作的非交互
   角色可能关掉 heartbeat。
9. 交互玩家最后更新年龄和 idle timeout。

`tick` 初值和重置值为 5..14，但 `if (tick--) return` 在旧值为 0 的那次才继续，因此在没有 busy
冻结的情况下，condition/recovery 间隔是 6..15 次 heartbeat invocation。证据：
`std/char.c:32-131`、`cmds/std/go.c:68-82`。

### 4.2 Native 边界

推荐 runtime 显式调用：

```text
begin_combat_step(combatant_id)
  -> evaluate pending life threshold
  -> if integer busy: advance busy and stop
  -> optional runtime-provided flee request
  -> CombatStepService.select_and_step()
  -> structured events
```

Condition/recovery 不应跟随 Combat step；它们已有独立 deterministic cycle。NPC chat、年龄、idle、
world movement 也不属于 Combat Core。动画结束或碰撞绝不能反过来决定命中；presentation 只消费
result/event。

### 4.3 Busy 的精确语义

`start_busy(new_busy, new_interrupt)` 接受 int 或 function；零直接不做。整数正值每次
`continue_action()` 减 1；从 1 减到 0 的那次仍 return，随后 `is_busy()` 已为 false，正常 heartbeat
不会再调用清理分支，因此旧 `interrupt` 值会留到下次 `start_busy()` 覆盖（但不再生效）。负整数会令
`is_busy()` 为真，并在下一次 continue 同时清零 busy/interrupt。整数 interrupt 规则为：仅当当前 `busy < interrupt`
才清 busy；命中时 `combatd.c` 调用 `interrupt_me(me)`，没有提供 `how`。

Phase 5B 普通战斗只需：`remaining_steps: int`、`is_busy()`、`advance_one_step()` 以及源等价的整数
interrupt threshold。function busy/interrupt 是 authored special 的控制流，必须以后改成显式 typed
effect/state machine；不能保存 Callable 或 LPC closure。`set_heart_beat(1)` 与 `start_call_out()` 全属
runtime。证据：`feature/action.c`、`adm/daemons/combatd.c:430-432`。

## 5. `skill_power()` 精确公式

令：

- `raw(B)` 为 basic/use skill 的 raw level；
- `mapped(B)` 为该 use ID 当前 enable 的 authored skill，若无则 0；
- `apply(B)` 为该 skill ID 的临时 skill modifier；
- `E` 为 `combat_exp`；`Smax` 为 `max_sen`；`S` 为当前 `sen`。

`feature/skill.c::query_skill(B)` 先算：

```text
L0 = apply(B) + raw(B) / 2 + raw(mapped(B))
```

然后 `combatd.c::skill_power()` 按 usage 再加一层：

```text
L = L0 + apply/attack       // attack usage
L = L0 + apply/defense      // defense usage
L = L0                      // other usage
```

完整公式为：

```text
if not living: 0
else if L == 0: E / 2
else if Smax > 0: (((L * L * L) / 3) / Smax) * S + E
else:            (L * L * L) / 3 + E
```

所有 `/` 都是 LPC 整数除法，而且 `(((L³ / 3) / Smax) * S)` 必须保持左结合的中间截断；不能改写
成 `L³ * S / (3 * Smax)`。`Smax <= 0` 不作除法；`S` 可为零或负数；`L` 为负且非零时仍走立方
分支；没有 clamp。之后 `do_attack()` 对 AP 先做 `if ap < 1: ap = 1`。

DP 的顺序不同且很重要：先把 power clamp 至至少 1，再在 busy 时 `/= 3`，之后不再 clamp，故 busy
defender 的 DP 可以成为 0。PP 则先做 busy `/3`，再 clamp 到至少 1。源注释声称双方 power 始终
大于零，但 busy DP 反例证明该注释不成立。

该公式适合一个无状态 `CombatMath.skill_power(input)`，不需要 `CombatPowerService` 或全局 daemon。
输入应是 typed scalar snapshot，不应让公式查询 Character/Armor/Equipment。

证据：`feature/skill.c:56-77`、`adm/daemons/combatd.c:163-190,239-245,277-290`。

## 6. 一次 ordinary `do_attack()` 的精确流水线

以下顺序来自 `adm/daemons/combatd.c:197-463`。`my`/`your` 是直接别名到角色 dbase 的 mapping，
因此旧代码中的 `combat_exp`、`potential` 写入立即改变角色；native 必须用显式状态变更或 typed
result 表达，不能复制 mapping alias。

### 6.1 动作与命中阶段

1. **取得 action**：读取并 evaluate `me.actions`。若不是 mapping，调用 `reset_action()`，但随后错误地
   读取单数 `me.action`；仍非 mapping 就记录系统错误并返回。正常 action 先生成文本。
2. **决定 attack skill**：显式 weapon 非空取 `weapon.skill_type`，否则固定 `unarmed`。只看主武器/
   本次传入武器，不看 secondary。
3. **选择 limb**：从 victim `limbs` 用 `random(sizeof(limbs))` 等概率选一个。
4. **AP**：`skill_power(attacker, attack_skill, ATTACK)`，小于 1 改为 1。
5. **DP**：`skill_power(victim, dodge, DEFENSE)`，小于 1 先改为 1；victim busy 再 `/3`。
6. **dodge roll**：`random(ap + dp) < dp` 即 dodge；否则进入 parry。DP=0 时 dodge 不可能。
7. **dodge progression**：见 6.4。结果设为 `RESULT_DODGE = -1`，不再检查 parry。
8. **PP source**：
   - victim 有 weapon：取 `skill_power(parry, DEFENSE)`；若 attacker 无 weapon，再乘 2；
   - victim 无 weapon、attacker 有 weapon：先设 0；
   - 双方无 weapon：取 `skill_power(unarmed, DEFENSE)`。
9. victim busy 时 PP `/3`，随后 `pp < 1` 改为 1。因此空手 defender 对 armed attacker 仍至少有
   `1/(ap+1)` 的招架机会。
10. **parry roll**：`random(ap + pp) < pp` 即 parry，结果 `RESULT_PARRY = -2`；否则命中。

### 6.2 命中后的伤害与 hook 顺序

11. `D = apply/damage`。
12. `D = (D + random(D)) / 2`。
13. 若 action `damage` truthy：`D += action.damage * D / 100`。
14. `B = me.query_str()`，即 base strength + force_factor + strength modifier。
15. 若 `force_factor` 非零且 `force > force_factor`（严格大于），并且 force use 有 mapped skill，调用
    该 force skill `hit_ob(me, victim, B, force_factor)`。返回 string 只增加 narration；返回 int 才加 B。
16. 若 action `force` truthy：`B += action.force * B / 100`。
17. 若 attack skill 有 mapped martial skill，调用 martial `hit_ob(me, victim, B)`；int 返回加 B。
18. 有 weapon 时调用 weapon `hit_ob`；无 weapon 时调用 attacker 本身 `hit_ob`（NPC/monster hook）；
    int 返回加 B。
19. 若最终 `B > 0`：`D += (B + random(B)) / 2`；B 非正则不加。然后 D 小于 0 clamp 为 0。
20. **combat-exp defense loop**：

    ```text
    factor = victim.combat_exp
    while random(factor) > attacker.combat_exp:
        D -= D / 3
        factor /= 2
    ```

    每轮都按当前 D 和 factor 整数截断；不能推导成单一百分比。

### 6.3 Damage、wound 与结束阶段

21. `victim.receive_damage("kee", D, attacker)`；旧函数返回请求的 D，即使 current kee 已饱和到 -1。
22. 仅当 `(attacker.is_killing(victim) || weapon != null)` 且
    `random(D) > victim.apply/armor` 时，调用
    `receive_wound("kee", D - armor, attacker)`。因此 armed friendly fight 也可能造成 wound；这是
    executable source behavior，与 `fight` 帮助中“只耗体力不受伤”的描述冲突。
23. 生成 damage narration；若 D>0，报告 victim 当前或有效状态，并调用 busy interrupt。
24. 若双方都没有向对方标记 kill、双方仍互为 enemy，任意 D>0 的攻击会从双方 enemy 中移除，
    friendly fight 立即结束；dodge、parry 或零伤害不会结束。
25. 若 action 有 function `post_action`，不论 D 是正数、0、-1 dodge 或 -2 parry，都执行。标准 throwing
    因而每次 action 都减数量；bash 系只在 parry 时进一步判断武器碰撞。
26. 仅普通 `TYPE_REGULAR`、D<1 且 victim 正在 guarding 时，清 guarding 并反击：
    `random(attacker.raw_cps) < 5` 时用 `TYPE_QUICK`，否则 `TYPE_RIPOSTE`。两者都不会再次触发 riposte。

`do_attack()` 声明返回 `int`，成功路径末尾没有 return；其调用者不依赖返回值。这是 legacy API
缺陷，不应成为 native contract。`attack_type` 除是否允许 riposte 外，不改变 AP、伤害或速度。

### 6.4 Combat progression 的精确分支

- **dodge 成功**：若 `dp < ap`、双方不全是 player，并且
  `random(victim.gin*100/victim.max_gin + victim.int) > 50`，victim `combat_exp += 1`，
  `improve_skill("dodge", 1)`。
- **NPC attacker 被 dodge**：若 `ap < dp` 且 attacker 非 player，
  `random(attacker.int) > 15` 时 `combat_exp += 1`；随后无条件调用
  `improve_skill(attack_skill, random(attacker.int))`。传入 0 仍会被既有 Phase 3A 最低 adjusted amount 1
  规则提升进度。
- **parry 成功**：使用与 dodge 相同的 gin/int roll 和 `dp < ap` 比较，而不是 PP；成功后
  `combat_exp += 1` 并 `improve_skill("parry", 1)`。这里使用 DP 很可能是 typo，但可执行。
- **命中后**（双方不全是 player）：若 `ap < dp` 且
  `random(attacker.gin*100/attacker.max_gin + attacker.int) > 30`，attacker 加 1 exp；若
  `potential - learned_points < 100` 再加 1 potential；然后 improve attack skill 1。
- 随后若 `random(victim.max_kee + victim.kee) < D`，victim 加 1 exp，并按同一 potential gap 规则加
  potential。这里没有 improve skill。

Phase 5B 不应重算 `improve_skill()`；应调用已关闭的 `CharacterSkillState` 并传播
`SkillImprovementResult`，再由既有 authored improvement registry 处理 callback。顺序不可移到攻击前。

## 7. Randomness contract 与完整调用顺序

Core 不应使用全局 `randi()`。最小接口只需一个方法，例如：

```text
next_below(exclusive_upper_bound: int) -> int
```

测试实现按队列返回 scripted draws，并验证 `0 <= draw < upper_bound`；生产 adapter 可包装 Godot RNG。
不要建立通用骰子 DSL。对 `upper_bound <= 0` 不要静默改成 1；应返回 typed legacy-invalid-input，
因为 MudOS 对 `random(0)`/负数的具体 driver 行为未由 mudlib 源证明。

一次 `do_attack()` 的潜在随机调用严格按以下顺序出现；未走到的分支不消费 roll：

1. action provider 的 `random(action_count)`；
2. `random(limb_count)`；
3. `random(ap + dp)` dodge；
4. dodge 分支的 victim gin/int progression roll；
5. dodge 分支 NPC attacker 的 int exp roll；
6. 同分支 NPC attacker 的 int improvement-amount roll；
7. 非 dodge 分支的 `random(ap + pp)` parry；
8. parry progression gin/int roll；
9. 命中时 `random(apply_damage)`；
10. force `hit_ob` 内部 rolls（若启用；`std/force.c` 最多两个，authored force 可追加）；
11. martial `hit_ob` 内部 rolls；
12. weapon 或 NPC `hit_ob` 内部 rolls；
13. B>0 时 `random(B)`；
14. defense loop 每轮 `random(current_factor)`；
15. lethal/armed 分支 `random(D)` wound；
16. attacker gin/int progression roll；
17. victim `random(max_kee + kee)` progression roll；
18. friendly winner narration roll（它位于 post-action/riposte 之前；若要求逐 roll parity，resolver 应
    消费并输出 variant index，再由 presentation 渲染，不能未经决定就把它移到独立 RNG）；
19. `post_action` 内部 rolls；
20. guarding riposte 的 `random(attacker.raw_cps)`，随后递归攻击从新的 action roll 重新开始。

在 `do_attack()` 前，`feature/attack.c::select_opponent()` 消费 `random(4)`；`combatd.c::fight()` 可能先
消费 visibility roll，再消费 attack/guard roll。Future step tests 必须把 orchestration rolls 与 resolver
rolls 一起记录，或传入独立但显式的 typed streams；不能只 seed 后比较最终 HP。

## 8. Combat action data

### 8.1 实际字段

`combatd.c` 实际读取的 action 字段只有：

| 字段 | 类型/用途 | 迁移分类 |
|---|---|---|
| `action` | 文本模板，替换 `$l/$w` | presentation token / action identity |
| `damage_type` | 伤害叙事类别；不改变数值公式 | typed damage/narration tag |
| `damage` | 当前随机 base damage 的百分比修正 | integer gameplay data |
| `force` | 当前 damage bonus 的百分比修正 | integer gameplay data |
| `weapon` | 空手招式显示用的身体部位/虚拟武器名 | presentation metadata |
| `post_action` | procedural callback | narrow authored policy ID，不是 Callable |

大量 action 还写有 `dodge`、`parry`，但 `combatd.c` 全程没有读取；它们是可执行数据中的 dead
fields，不能在 native 中擅自让其生效。`cost` 只在 `do_attack()` 声明而从未使用。

结构扫描找到：

- active `daemon/skill` 下 19 个 `query_action()` provider，共 114 个 martial action records；
- human 默认 5 个，beast 可选 4 个，`WEAPON_D` 标准动作 12 个；
- beast 另有一个不经随机 action 表的 generic fallback；
- 合计 135 个 active selectable records，外加 1 个 beast fallback；
- 19 个 active martial provider 全部只是 `action[random(sizeof(action))]`，没有按等级筛选。

跨上述记录的词法字段计数为：`action` 136、`damage_type` 135、`damage` 66、`force` 37、
`dodge` 102、`parry` 58、`weapon` 4、`post_action` 4。计数用于证明结构多样性，不表示所有字段
都生效。

### 8.2 action source

`reset_action()` 只看 primary `query_temp("weapon")`：

1. 取 weapon.skill_type，或无武器时 `unarmed`；
2. 若该 use ID 有 mapped skill，则 action provider 为 mapped skill；
3. 否则有 weapon 用 weapon 自带 actions；
4. 否则用 race/default actions。

Native 不需要缓存一个动态 `actions` property。建议 `CombatActionSelector` 在攻击快照构建时按上述
优先级返回 `CombatActionDefinition`。定义可含稳定 action ID、`damage_percent`、
`force_percent`、damage tag 与 presentation key；procedural `post_action` 只保存显式 policy ID。

证据：`feature/attack.c:197-220`、`adm/daemons/race/human.c:8-24,40-85`、
`adm/daemons/race/beast.c:5-49,84-90`、19 个 active `daemon/skill/*::query_action()`、
`adm/daemons/weapond.c:6-88`。

## 9. Weapon、Armor 与 Skill 依赖

### 9.1 Weapon

当前 closed `WeaponDefinition` 只有 ID、`skill_type`、SECONDARY、TWO_HANDED 与 legacy path；这对
装备槽正确，但不足以进行 armed combat。源证明后续至少需要：

- `weapon_prop/damage`（标准武器 `init_*()` 的 base damage，装备后成为 apply/damage）；
- 标准 action set/verb IDs，映射到 `WEAPON_D` 的 12 个 action definitions；
- 其他 numeric `weapon_prop` 对选定 skill、attack、defense、dodge 或 attributes 的贡献；
- “本次确有 weapon”这一事实，因为它改变 PP、wound 资格和 force 反震；
- 以后才需要的 explicit hit policy ID。

`damage_type` 来自选中的 action，不是武器上的单一字段。force 也不是普通 weapon property。
`rigidity`、weight、throwing amount、bash disarm/break、mutable `weapon_prop=0` 只被 post-action 使用，
可延期到 authored weapon hooks。

建议 Phase 5B 用独立 immutable `WeaponCombatDefinition/Profile`（测试可直接构造），通过稳定
ItemDefinitionId/weapon ID 与现有 hand ref 对齐；不要立刻膨胀 closed hand-slot snapshot，也不要引入
repository。第一批 armed slice 只需 base damage + standard action IDs + 已确认 numeric modifiers。

证据：`std/weapon/*.c`、`feature/equip.c:40-100`、`std/equip.c`、
`adm/daemons/weapond.c`、`daemon/class/taoist/sword.c`。

### 9.2 Armor

普通/force combat 对当前 `ArmorNumericModifiers` 的消费如下：

| Native armor field | LPC path | ordinary use |
|---|---|---|
| `attack` | `apply/attack` | 加在 attacker effective attack skill 之后 |
| `defense` | `apply/defense` | 加在 dodge/parry/unarmed defense power 之后 |
| `dodge` | `apply/dodge` | 作为 `query_skill("dodge")` 的 skill modifier |
| `unarmed` | `apply/unarmed` | 空手 AP 或空手 PP 的 selected-skill modifier |
| `armor` | `apply/armor` | wound roll 阈值及 wound amount 扣减 |
| `armor_vs_force` | 同名 | 只在 `std/force.c::hit_ob()` 中扣内力 bonus |

`magic`、`spells` 属特殊法术；其余属性 modifier 只有在对应 effective attribute 被某规则读取时才
间接相关。尤其 `combatd.c::fight()` 读取 raw `cor`、raw `cps`，不是 `query_cor/query_cps`，所以
Armor 的 courage/composure 不影响 attack-vs-guard 判定。Base damage 使用 `query_str()`，但 active
Armor scan 没有 strength key。

不要把 Armor aggregate 复制进 CharacterState。Snapshot builder 应从 Character、ArmorState、
Equipment/weapon profile 和以后 typed effects 取出本次需要的标量，例如 selected attack skill
modifier、dodge modifier、parry modifier、attack bonus、defense bonus、damage、armor、
armor_vs_force。它不是新的权威状态，也不是任意 `Dictionary[String, Variant]`。

### 9.3 Skill

现有 `CharacterSkillState` 已提供 source-equivalent raw/effective/mapped 语义。Combat adapter 只需：

- `raw_level(use_id)`；
- `mapped_skill(use_id)`；
- `effective_level(use_id, selected_temporary_modifier)`；
- progression 时调用既有 `improve_skill()`，不复制公式。

注意 `skill_power` 的 `apply/attack` / `apply/defense` 是 effective skill 之外再加的第二层标量。
Action provider、dodge message、parry message 不属于 `CharacterSkillState`；它们属于 authored combat
data/presentation registry。

Phase 5B 的最小代表技能：basic `unarmed`、`dodge`、`parry`；armed test 再加 basic `sword`。
一个 synthetic mapped `unarmed` action profile 足以证明 mapped full-level 与 action precedence，
无需先迁移 19 套 martial data。`force` basic + 一个 standard force policy 应在 ordinary parity 阶段
单独测试；iceforce、ts-fist、spicyclaw 留到 authored hooks。

## 10. Fight、kill 与 biwu

### 10.1 `fight_ob` 与普通 reciprocal combat

`fight_ob(ob)` 只做三件事：拒绝空/self、启动 heartbeat、若不在 `enemy` 则 append；它不自动让
对方回打。`combatd.c::fight()` 真正决定出手时，如 victim 尚未把 attacker 视为 enemy，才调用
`victim.fight_ob(attacker)`。

`cmds/std/fight.c` 对 player 使用双向同意 handshake；NPC 可由 `accept_fight()` 决定。不会说话的
character 被 challenge 后，challenger fight，而对方直接 `kill_ob(challenger)`。这属于 encounter/
command adapter，不是一次 attack resolver。

### 10.2 `kill_ob` 与 lethal intent

`kill_ob(ob)` 先把 ob 的 legacy ID 放入 `killer`，发送警告，再 `fight_ob(ob)`。`cmds/std/kill.c`
使 NPC victim 也对 attacker kill；player victim 只 reciprocal fight，直到自己也输入 kill。
Lethal intent 决定无武器攻击是否可 wound，并使 `remove_enemy()` 拒绝单独停止该目标。

最小 Combat Core 需要 unilateral lethal target；不需要 command 文本、玩家确认 UI 或 room
`no_fight` 查询。

### 10.3 `fight()` 的 attack/guard 判定

一次 selected-opponent step：

1. attacker 非 living 则结束；
2. victim 不可见时，若 `random(100 + effective perception skill) < 100` 则不行动；
3. victim busy 或非 living：清 attacker guarding，补 reciprocal fight，执行 `TYPE_QUICK`；
4. 否则若 `random(victim.raw_cps * 3) < attacker.raw_cor + attacker.raw_bellicosity/50`：
   清 guarding，补 reciprocal fight，执行 `TYPE_REGULAR`；
5. 否则首次进入 guarding 并发事件；已经 guarding 则无变化。

这里明确使用 raw dbase `cps/cor`，只有 perception 用 effective skill。世界 visibility 本身由 runtime/
world adapter 提供 bool，Combat 只保留源概率门槛。

### 10.4 Biwu 延期

`feature/attack.c::biwu_ob()` 全库没有调用者，`biwuer` 也未使用，属于 D 类 legacy/dead 路径。
另有 active `cmds/std/biwu.c`，它不是 ordinary step：玩家 handshake 后在一个同步无限 loop 内按双方
`query_cor()` 比例连续调用多次 `do_attack()`，直到 kee 或 eff_kee `<= 0`，再强写为 1。

该命令存在除零风险、`<=` 导致的额外攻击次数、同步长循环，并绕过 normal enemy scheduling。
它应作为后续独立 `BiwuService` 重新表达，不进入 Phase 5B minimal fight/kill；不得用 ordinary
nonlethal flag 粗略代替。

证据：`feature/attack.c`、`cmds/std/fight.c`、`kill.c`、`biwu.c`、`surrender.c`、
wizard-only `cmds/wiz/halt.c`。

## 11. Damage、unconscious、death 与 Phase 4B5C 边界

普通 hit 的资源顺序固定为：

```text
vitality.apply_damage(D)       // kee，current 最低 -1
if wound succeeds:
    vitality.apply_wound(D-A)  // eff_kee，最低 -1，并把 current 压到 effective
```

必须直接复用 closed `CharacterResourceState`，不能在 Combat 复制 clamp。每次 damage/wound 还应在
structured result 中记录 attacker stable ID，等价于 `last_damage_from`。

`do_attack()` 自己不调用 unconscious 或 die。生命检查发生在角色下一次 `heart_beat()` 开头；
`post_action`、riposte 或 scripted 多连击可能在阈值越界后继续执行。Native attack result 可在每次
变更后报告观察值：

- `death_candidate`：任一 effective resource `< 0`；优先级最高；
- `unconscious_candidate`：没有 death candidate 且任一 current resource `< 0`。

“候选”不是立即 lifecycle command。`CombatStepService`/future runtime 应在与旧心跳等价的下一显式
step 开头处理，除非某个 authored caller 像旧 NPC 测试那样主动读取资源。否则立刻造尸体会改变
multi-attack/post-action 行为。

Outer lifecycle 的责任顺序仍来自 `feature/damage.c`：unconscious 清敌、winner reward、禁用与安排
revive；death 清 condition、公告、killer reward、调用 `CHAR_D->make_corpse()`、清 combat/team、
player ghost 或销毁 NPC。Phase 4B5C 只接收已经决定的 death context 并处理 death inventory/corpse；
Combat Core 不得直接构造 `CorpseState`。

## 12. NPC auto-fight 与 World/runtime 延期

`feature/attack.c::init()` 在对象同房/进入时检查 hatred、vendetta、aggressive、berserk，再让
`combatd.c::auto_fight()` 用 `call_out(..., 0)` 延迟启动，使目标有机会离开。它明确禁止 NPC 对 NPC
自动开战，并在延迟 callback 中重新检查同环境、living、not fighting 与 room `no_fight`。

未来 NPC/World adapter 需提供：

- player/NPC kind、living/linkdead、同 map/zone/proximity；
- 当前 encounter 是否允许 combat（旧 `no_fight`）；
- attitude、vendetta mark/flag、既有 lethal hatred；
- raw bellicosity、raw cps、force、score、wizard fact；
- visibility/perception input；
- 一个可取消的“下一 runtime opportunity”请求。

berserk 首门槛是 `random(bellicosity / 40) > raw cps`；延迟启动又用
`force > (random(bellicosity) + bellicosity)/2` 来放弃，随后按 `bellicosity > score` 选择 kill 或
fight。上述规则需以后保留，但触发时机属于 NPC/World runtime，不应进入 minimal Combat Core。

证据：`feature/attack.c:238-272`、`adm/daemons/combatd.c:502-628`。

## 13. Authored combat hooks 清单与分类

本次对 1,777 个 mudlib `.c` 文件进行了结构搜索，并对命中核心路径作定向阅读。分类含义：
A = minimal ordinary combat；B = 后续 authored/special；C = runtime/presentation/world；
D = dead/unreachable/legacy mechanism。

| Hook/形态 | 扫描结果 | 分类与结论 |
|---|---:|---|
| `query_action()` | 28 definitions | A：19 active martial + WEAPON_D + human + beast；D：`d/skill` 下 6 个 shadow copies |
| `actions` token | 26 occurrences / 12 files | A 是 source-selection 语义；closure/dbase 存储本身是 D |
| `reset_action()` | 1 definition，11 occurrences / 7 files | A：优先级；D：动态 closure cache |
| `do_attack()` | 1 definition，33 occurrences / 10 files | A：resolver；B：special multi-hit/NPC tests 的显式调用 |
| `fight()` | 1 combat definition；8 occurrences / 5 files | A：attack-vs-guard step；同名普通文本命中不作为 hook |
| `skill_power()` | 1 definition，8 occurrences / 2 files | A：纯公式；`score.c` 调用是 presentation |
| `hit_ob()` | 7 concrete definitions；13 occurrences / 9 files | B；但 ordered hook seam 与 standard force 是 ordinary parity 所需 |
| `damage_bonus()` / `defense_factor()` | 0 function definitions | D：前者只是 local/parameter 名，后者仅 combatd local loop variable |
| `start_busy()` | 1 definition，43 occurrences / 38 files | A：integer busy contract；B：special callback busy；C：heartbeat/callout |
| `is_busy()` | 1 definition，21 occurrences / 17 files | A：defense penalty 与 step gate |
| `interrupt_me()` | 1 definition + 1 combat call | A：integer interrupt；B：function handler |
| `receive_damage()` | base + 3 NPC overrides；154 occurrences / 114 files | A：closed resource mutation；B/C：3 NPC 自疗/逃跑 overrides |
| `receive_wound()` | 1 base definition；23 occurrences / 21 files | A：closed resource mutation；B：condition/special callers |
| literal `apply/*` | 27 distinct keys | A：选定的 typed scalar projection；D：通用 temp dbase API |
| `perform_action()` | std dispatcher + NPC helper；5 occurrences / 3 files | B；命令、目标解析与消息为 C |
| `exert_function()` | std/NPC + 3 shadow dispatch overrides；10 occurrences / 7 files | B |
| `cast_spell()` | std/NPC + 6 `d/skill` spell wrappers；10 occurrences / 9 files（含 command call） | B/C；动态路径 dispatch 不迁移 |
| `conjure_magic()` | std definition + command call | B/C |
| `query_dodge_msg()` | 11 definitions：8 active、3 shadow | C：只生成 presentation 文本 |
| `query_parry_msg()` | 5 active definitions | C/D：combatd 硬编码调用 basic `parry`，4 个 special message provider 未被使用 |
| action `post_action` | 4 records，2 implementations | B：throw quantity 与 bash weapon control flow |

### 13.1 七个 `hit_ob` provider

- `std/force.c`：扣 force、内力攻防、armor_vs_force、可能反震 attacker；B，standard force 应最先迁移；
- `daemon/skill/iceforce.c`：继承 standard force，额外 wound + `iceshock` condition；B，需 Condition；
- `daemon/skill/ts-fist.c`：damage bonus 门槛和额外 wound；B；
- `daemon/skill/spicyclaw.c`：相似但 wound 公式不同；B；
- `daemon/class/taoist/sword.c`：ghost/atman/spirituality、gin wound 与三资源 heal；B，需 ghost lifecycle；
- `d/oldpine/npc/venomsnake.c`：armor roll 后施 snake poison；B，需 NPC + Condition；
- `d/latemoon/room/npc/shaoin.c`：armor roll 后施 rose poison；B，需 NPC + Condition。

`std/force.c` 的顺序是先 `force -= factor`，再以剩余 force 计算
`remaining_force/20 + factor - victim.force/25`；负值时只有空手攻击可能反震，正值先减
armor_vs_force，再用 `random(effective_force) < damage` 决定是否返回 bonus。这个 policy 不能被一个
静态 “force bonus” 字段近似。

### 13.2 perform/exert/cast/conjure inventory

- `perform()`：5 个 active implementations；fonxansword 3、mysterrier 1、yirong 1。
  `deisword` 与 `nine-moon` 虽声明动态目录，目标目录不存在，调用返回失败。
- `exert()`：18 definitions；其中 active routed 为 `/d/force` 3 + `daemon/class` 9，`d/skill` 6 个为
  shadow copies。
- `cast()`：9 definitions；当前 skill routes 可到 necromancy 6 + magic-array 2；另一个完全相同的
  `daemon/class/taoist/animate.c` 不在声明路由下，是 shadow/legacy copy。
- `conjure()`：essencemagic 下 3 个 active implementations。

这些实现会改 resources、busy、temporary modifiers、conditions、敌对关系、装备、NPC/world、召唤与
presentation，不能用一个通用 callback-name dispatcher。未来按 stable skill/action ID 显式注册窄
policy；纯数值 action records 仍数据化。

### 13.3 其他 authored combat interception

三名 NPC override `receive_damage()`：`d/choyin/npc/oldman.c`、`d/npc/sungoku.c`、
`d/npc/oldman.c`。它们先调用 base damage，再可能 random move，并在三资源低于 20 时消耗 pill
全回复。另有 1 个 `killed_enemy()` 和 3 个 `defeated_enemy()` hooks，涉及尸体命令、文本及移除
killer。它们属于 NPC/reward/runtime policies，不能塞进 resolver。

## 14. 已确认缺陷、怪异点与运行时歧义

| 项目 | 分类 | 处理建议 |
|---|---|---|
| `reset_action()` 后读取不存在的单数 `action` | executable typo | 当前攻击失败；下一次若 `actions` 已有效可恢复。记录兼容测试，不静默“修正” |
| action `dodge/parry` 共大量记录但 resolver 不读 | dead data | Phase 5B 不让其生效；未来若产品要启用需新决定 |
| mapped `parry_skill` 计算后仍调用 basic parry message | executable presentation typo | 数值不受影响；presentation 后续可记录 legacy |
| parry progression 比较 `dp < ap` 而非 PP | likely typo but executable | 保留 exact comparison |
| DP min clamp 在 busy 除法之前，busy DP 可为 0 | executable | 保留；不要根据注释二次 clamp |
| unarmed defender 对 armed attacker 的 PP 最终 clamp 为 1 | executable | 保留微小 parry chance |
| armed friendly fight 可 wound | executable/help contradiction | 核心按代码；UI 文案以后处理 |
| `post_action` 在 dodge/parry/0 damage 后仍执行 | executable | typed result 必须携带负 result code/branch |
| `WEAPON_D` unknown/no verbs fallback 查未定义 `weapon_actions["hit"]` | executable invalid action path | 不发明 hit action；definition validation 应报告缺失 |
| `do_attack()` int 成功路径无 return | API defect | native 用 typed result，不复制未定义 return |
| `cost` 未使用；`biwuer` 未使用 | dead | 不迁移 |
| `feature/attack.c::biwu_ob()` 无调用 | unreachable/dead | 不迁移；active `cmds/std/biwu.c` 另行分析实现 |
| `std/force.c` 一条文本写 `$N` 而非 `$n` | presentation typo | 不影响规则 |
| `random(0)`/负 upper bound | runtime-semantics ambiguity | source 不证明 MudOS driver 行为；native 返回 typed legacy-input failure，需决定后再实现 |
| `max_gin == 0` 的 progression 百分比 | division-by-zero path | 不 clamp；测试/typed failure |
| defense factor 归零且 attacker exp 为负 | 可能无限 loop，取决于 `random(0)` | 不代数化；拒绝无效输入需明确 decision |
| `limbs` 空数组 | invalid random/index path | definition validation 报告，不能默认发明 limb |
| `biwu` courage 为 0、同步无限 loop、`<=` attack count | executable/error-prone | 独立 Biwu phase |
| `swordjab.c` 用 `me->query("weapon")` 而非 temp weapon | likely typo | special phase逐项审计，不在 ordinary resolver 修复 |

以上尚未形成已实现 native 行为，因此不修改 `DECISIONS.md`。

## 15. 推荐 Phase 5B 拆分

### Phase 5B1 — Combat State + Math + Action Foundation

- typed `CombatRelationshipState`，稳定 CharacterId、有序 opponents、lethal targets、guarding、last opponent；
- integer-only busy state；function busy 明确 deferred；
- immutable `CombatModifierSnapshot` / combatant input；
- `CombatActionDefinition`、human default action test data、selector interface；
- scripted `CombatRandomSource.next_below()`；
- exact `skill_power()` 与所有 zero/negative/busy boundary tests；
- 只定义 structured result vocabulary，不改资源。

不在本单元加入 weapon catalog、authored skill tables、world、NPC aggression 或 death runtime。

### Phase 5B2 — Ordinary Attack Resolution

- unarmed + 一个标准 sword combat profile；
- exact limb/AP/DP/dodge/PP/parry/damage/armor/wound pipeline；
- CharacterResourceState 复用；
- progression intent/result 与既有 SkillImprovementResult 集成；
- standard force policy（单独开关测试，含 armor_vs_force/反震）；
- structured presentation facts；
- threshold candidate，不执行 lifecycle；
- exhaustive scripted-roll tests，证明每个分支的 roll 消费顺序。

先不实现 iceforce、martial/NPC/weapon `hit_ob`、bash/throw `post_action`。Resolver 应预留按固定顺序的
窄 typed policy seams，但 registry 中只注册已实现的 standard force；不能放任任意 callable。

### Phase 5B3 — Fight/Kill Combat Step Orchestration

- source-equivalent opponent selection bias；
- visibility fact + perception gate；
- raw cor/cps/bellicosity attack-vs-guard；
- reciprocal fight、unilateral kill、friendly-hit stop；
- integer busy step/interrupt、guarding riposte；
- 显式 step-start threshold handling request；
- 不含 command parser、NPC auto-fight、world flee 或 heartbeat。

### Phase 5B4 — Representative Authored Combat Policies

- 从四类各选一个：martial hit、condition-producing hit、weapon post-action、perform multi-action；
- 逐个 source audit 并显式注册 stable ID；
- function busy 转 typed special state；
- 仍不批量迁移所有 perform/exert/cast/conjure。

随后再分别进行 NPC aggression/runtime bridge、full authored combat actions、death/reward/quest/faction
orchestration 与 UI/presentation。Biwu 应是独立服务，不与 fight/kill 合并。

## 16. 第一条可玩 vertical slice

### REQUIRED

- Phase 5B1-5B3 完成：player vs NPC、unarmed/one sword、dodge/parry、damage/wound、one armor、
  threshold candidate；
- 一个 Player `CharacterState` 与一个最小 NPC `CharacterState`，共享同一 Combat Core；
- 一个小 test map 与 Godot-native player movement/collision；
- 一个 interaction/start-combat bridge，把同场目标 stable ID 交给 relationship service；
- runtime 明确请求 combat step，不依赖 hitbox 决定命中；
- presentation adapter 消费 action、limb、dodge/parry、damage/wound、guard、threshold 等 structured facts；
- threshold outer adapter：unconscious 可先最小禁用/恢复；death 决定后调用 Phase 4B5C，而非 resolver 造尸体；
- corpse 的最小 item interaction bridge，至少能查看/取得已转入的物品。

### NICE-TO-HAVE（不阻塞第一 slice）

- mapped martial art 与花式动作文本；
- standard force 以外的 `hit_ob`；
- perform/exert/cast/conjure；
- bash/throw、断裂、缴械与投掷栈；
- NPC hatred/vendetta/aggressive/berserk；
- flee AI、wimpy、多个对手 UI；
- full death penalties、killer rewards、quest/faction consequences、ghost journey；
- authored VFX、复杂动画、音频与所有 135 个 action records。

这条 slice 的目标是证明“规则决定结果、Godot 表现结果”，不是复刻 MUD heartbeat 或完成全量内容。

## 17. 扫描与阅读范围

### 完整/逐段精读

- 核心：`adm/daemons/combatd.c`、`feature/attack.c`、`feature/action.c`、
  `feature/damage.c`、`std/char.c`；
- state/skill/equipment dependencies：`feature/dbase.c`、`feature/skill.c`、
  `feature/attribute.c`、`feature/equip.c`、`std/equip.c`、`std/skill.c`、`std/force.c`；
- character/race：`adm/daemons/chard.c`、`adm/daemons/race/human.c`、
  `race/beast.c`、`race/monster.c`、`std/char/npc.c`；
- weapon/action：`adm/daemons/weapond.c`、全部 `std/weapon/*.c`；
- commands：`cmds/std/kill.c`、`fight.c`、`biwu.c`、`perform.c`、`exert.c`、
  `cast.c`、`conjure.c`、`surrender.c`、`go.c`、`cmds/wiz/halt.c`、`cmds/usr/score.c`；
- hit hooks：`daemon/skill/iceforce.c`、`ts-fist.c`、`spicyclaw.c`、
  `daemon/class/taoist/sword.c`、`d/oldpine/npc/venomsnake.c`、
  `d/latemoon/room/npc/shaoin.c`；
- direct attack/special examples：`daemon/class/swordsman/fonxansword/swordjab.c`、
  `fakefault.c`、`daemon/class/fighter/champion.c`、`d/choyin/npc/magistra.c`、
  `d/latemoon/room/npc/elon.c`、`aaa.c`、`cmds/wiz/test.c`；
- NPC damage/reward overrides：`d/choyin/npc/oldman.c`、`d/npc/sungoku.c`、
  `d/npc/oldman.c`、`d/oldpine/npc/spy.c`。

### 结构扫描

- 全部 1,777 个 `reference/es2/mudlib/**/*.c`：指定 hook 的 definition/call、`apply/*`、action fields；
- 全部 70 个 `daemon/skill/*.c` 与 47 个 `d/skill/*.c`；
- 19 个 active martial `query_action` bodies：
  `bloodystrike`、`celestrike`、`cloudstaff`、`deisword`、`fonxansword`、
  `jingang-staff`、`liuh-ken`、`meihua-shou`、`mystsword`、`nine-moon`、
  `scratching`、`shortsong-blade`、`six-chaos-sword`、`snowshade-sword`、
  `snowwhip`、`spicyclaw`、`spring-blade`、`tenderzhi`、`ts-fist`；
- 全部 71 个 `daemon/class/*.c` 的 perform/exert/cast/conjure 与 combat hook 路由结构；
- headers：`include/combat.h`、`skill.h`、`weapon.h`、`armor.h`、`globals.h`。

同时复核了当前 native `CharacterState`/resources/attributes/progression、
`CharacterSkillState`/loadout、`EquipmentState`/WeaponDefinition、ArmorState/numeric modifiers 与
Phase 4B5C death context/service 的公开边界。没有把这些 closed domains 重新设计。
