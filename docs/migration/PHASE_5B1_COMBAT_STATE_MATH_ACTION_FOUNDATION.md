# Phase 5B1：Combat State + Math + Action Foundation

## 范围与来源

本阶段只建立普通攻击解析之前所需的纯领域基础，不实现攻击解析、伤害、资源变更、战斗步进或运行时调度。权威来源为：

- `reference/es2/mudlib/feature/attack.c`：`enemy` / `killer`、`fight_ob()`、`kill_ob()`、移除关系、`guarding` 使用背景、`last_opponent`、`reset_action()`；
- `reference/es2/mudlib/feature/action.c`：整数 `busy`、`continue_action()`、整数 `interrupt_me()`；
- `reference/es2/mudlib/feature/skill.c`：传入 `skill_power()` 前的 effective skill 含义；
- `reference/es2/mudlib/adm/daemons/combatd.c`：`skill_power()`、action 消费字段、action cache 缺失路径。

未修改既有 Character、Skill、Equipment、Armor 领域，也未修改 `reference/es2/`。

## Native 职责

### CombatRelationshipState

每个实例只拥有一个角色的本地战斗关系：稳定 `owner_character_id`、按插入顺序保存的 opponent IDs、稳定 ID 形式的 lethal target markers、guarding 布尔值及可选 last opponent ID。它不保存对象引用、另一份关系状态、World/environment 或 encounter-wide `is_in_combat` 布尔值。

本地转换对应 `feature/attack.c`：

- `add_opponent()` 拒绝空 ID/self，重复目标不重复追加；
- `mark_lethal_target()` 先增加 lethal marker，再确保 opponent 存在，对应 `kill_ob()` 后调用 `fight_ob()`；
- lethal marker 存在时 `remove_opponent()` 拒绝移除，对应 `remove_enemy()`；
- `remove_lethal_relation()` 对应 `remove_killer()` 的本地部分：先移除 marker，再移除 opponent；没有 marker 时仍尝试普通移除；
- last opponent 不随 opponent 移除而自动清除，因为 LPC 没有这种隐式清理；guarding 只保留布尔值，来源没有 guarded-target 字段。

LPC `enemy[]` 使用对象身份，而 `killer[]` 使用公开 `query("id")` 字符串。当前 storage 只定义 native stable CharacterId 形状；两个 LPC 对象共享 legacy ID 时的“一枚 marker 命中多个对象”兼容行为没有实现，留给 Phase 5B3 的关系编排/legacy adapter。当前尚未接入运行时，因此没有在 `DECISIONS.md` 固化可观察替代行为。

### ActionBusyState

只表达 `feature/action.c` 的整数分支：

- `start_busy(0, ...)` 完全不改变状态；任意非零整数（包括负数）均为 busy；新值替换旧 busy 与 interrupt threshold；
- 正值 `advance()` 仅减一并立即结束：`2 -> 1 -> 0`，`1 -> 0` 时仍保留 threshold；只有显式再次调用 non-positive advance 才会清除两者。正常 `std/char.c` 调度在 `is_busy() == false` 后不会自动再次调用，因此 stale threshold 会一直保留到后续非零 `start_busy()` 覆盖；
- 负值 advance 直接清除 busy 与 threshold；
- integer interrupt 严格使用 `busy < interrupt_threshold`；命中时只清 busy，保留 threshold；默认 threshold 为 0。

LPC function/closure busy、function interrupt、heartbeat 与 callback 全部延后。该类型不含 `Callable`、`Variant`、Timer 或调度责任。

### CombatSkillPowerInput / CombatMath

输入是不可变标量：living、加入 usage bonus 之前的 effective skill、usage bonus、combat experience、maximum/current spirit（legacy `max_sen` / `sen`）。未来 adapter 负责从已关闭领域投影；`CombatMath` 不查询 CharacterState、SkillState、EquipmentState 或 ArmorState。

精确公式为：

```text
L = effective_skill_level + usage_bonus
not living       -> 0
L == 0           -> combat_exp / 2
max_sen > 0      -> (((L * L * L) / 3) / max_sen) * current_sen + combat_exp
otherwise        -> (L * L * L) / 3 + combat_exp
```

每个除法点均保留 LPC 整数截断和从左到右次序；没有代数重排，也不 clamp 负 level、experience、sen 或非正 max_sen。

### CombatRandomSource

Combat Core 只依赖 `next_below(exclusive_upper_bound)`。合法实现必须返回 `0 <= value < upper_bound`；production Godot RNG adapter 留待 runtime integration。测试 queue implementation 记录调用次数和 upper bounds。空/无效 action set 在请求随机数之前失败；越界 scripted draw 返回 typed failure，不会 clamp 或索引数组。

### CombatActionDefinition / CombatActionSet / Selector

Action 定义是不可变快照，只含当前来源可证明的字段：stable action ID、damage/force percent、damage type/tag、presentation key、legacy text metadata、可选 weapon/body token、可选 stable post-action policy ID。`combatd.c` 不读取 authored action 的 `dodge` / `parry` 字段，因此它们没有成为 active gameplay fields；procedural `post_action` 也不保存 `Callable`。

Action set 保持 authored array 顺序、要求非空且 action IDs 非空/不重复，并对输入与输出数组/定义做防御性快照。审计发现原输入错误地用 mapped set 是否为 `null` 同时表示“没有 mapped skill”和“mapped data 不可用”，会让后者落入武器/default。现已分离 `mapped_skill_present` 与可选 mapped action set；primary weapon 同样以既有 `primary_weapon_present` 与可选 action set 分离。Selector 的优先级严格为：

1. mapped skill present 时必须选择 mapped provider；数据缺失返回 `MAPPED_ACTION_DATA_UNAVAILABLE`，不得 fallback；
2. 否则 primary weapon present 时必须选择 primary weapon provider；数据缺失返回 `PRIMARY_WEAPON_ACTION_DATA_UNAVAILABLE`，不得 fallback；
3. 否则取 default/race set。

没有 secondary weapon 输入通道。选定 provider 后恰好请求一次 `next_below(action_count)`，直接按 index 选 authored entry，不做 level filtering。缺 provider、空/无效 set、缺 RNG、越界 draw 都有不可变 typed result；任何较高优先级 provider 的缺失/无效数据都在随机数调用前失败。

`reset_action()` 写 plural `actions`、`do_attack()` 在 reset 后读 singular `action` 的 executable typo 没有被动态 dbase cache 兼容层复刻。Projected input 缺失时返回 `NO_ACTION_SOURCE`，不会虚构拳击、读取另一个 cache key 或调用未定义 fallback。该结果保留“当前攻击没有合法 action”的失败语义；具体 legacy cache 导入/兼容策略仍未决定。

## 测试

`game/tests/core/combat_state_math_action_foundation_test.gd` 使用独立写出的 LPC 期望覆盖：

- relationship owner/self/duplicate/order/removal/re-add append/guarding/last-opponent/lethal local invariant 与实例隔离；
- busy zero、正负值、`2 -> 1 -> 0`、overwrite、严格 interrupt 边界，以及 idle interrupt/zero start 都不清 stale threshold；
- `skill_power()` living、零/正/负 L、正/零/负 max_sen、零/负 current sen、正负 usage bonus、负 experience 及 left-associated truncation；
- mapped/primary/default precedence、mapped/weapon presence 与 data availability 的分离、无 secondary channel、exact one draw、空/无效 source、越界 roll、重复 action ID、不可变快照及 dead dodge/parry fields。

定向 runner 同时执行 Phase 3A Skill Core 与 Phase 4A1 Equipment State 回归。Phase 4B4 没有运行时依赖且 production 未触碰，按本阶段要求未加入定向回归。

## 明确延后

- Phase 5B2：attack resolver、AP/DP/PP clamps、dodge/parry、damage/wound、resource mutation、force/martial/weapon hooks；
- Phase 5B3：opponent selection、双方关系编排、legacy killer-ID collision adapter、visibility、attack-vs-guard、friendly stop、riposte、step scheduling intent；
- Phase 5B4+：function busy 的 typed special action、post-action policies、authored action bulk migration；
- production RNG adapter、CombatantSnapshot/CombatModifierSnapshot、WeaponCombatProfile、NPC/World/death/UI/runtime scheduling。
