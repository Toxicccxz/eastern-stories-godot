# Phase 6A：First Playable Combat Vertical Slice Runtime + Integration Analysis

## 范围与结论

Phase 5B3 在本分析中视为正式关闭。本阶段不修改 Combat Core，也不实现 Phase 5B4；目标是为一个可见、可操作、可重复验证的单场战斗，定义从场景到闭合领域规则的最短 Runtime 路径。

推荐的第一场战斗是：一个小型封闭竞技场、一个玩家、一个持剑人类 NPC。玩家选中 NPC 后点击“攻击”，双方建立致死关系；场景拥有的 1 秒 `Timer` 每次依稳定顺序给每个角色一次外层战斗机会。每次机会在 Runtime 组装当前投影，依次调用已经关闭的对手选择、`fight()` 决策、正向普通攻击以及最多一次同步反击。Core 完整突变之后，表现层再显示动作、闪避、招架、防守、反击和伤害。生命周期只在角色下一次外层机会开始时检查，绝不插入正向/反向攻击链。

当前仓库没有可复用的 World/Runtime 战斗层：`game/` 下只有 Core、测试、编辑器插件和占位场景 `game/scenes/mcp_test.tscn`；`project.godot` 没有主场景，唯一 autoload 是 Godot AI 编辑器辅助。因而后续需要新增一个场景局部的 Runtime 组合根，但不需要全局 `GameManager`、Combat singleton、ECS 或通用调度器。

直接复核的 LPC 入口：

- `reference/es2/mudlib/std/char.c:56-122`：death → unconscious → busy → flee/attack → condition/recovery 的 heartbeat 顺序；
- `reference/es2/mudlib/feature/attack.c:36-41,113-120,124-191,222-236`：`fight_ob()`、`kill_ob()`、cleanup、selection、全关系清理与 `attack()`；
- `reference/es2/mudlib/adm/daemons/combatd.c:468-505`：`fight()` 的 living、visibility、QUICK/REGULAR/guard 顺序；
- `reference/es2/mudlib/feature/damage.c:91-161`：unconscious、revive 和 die 的实际顺序；
- `reference/es2/mudlib/cmds/std/kill.c`：玩家 kill NPC 时双方致死关系的建立顺序；
- `reference/es2/mudlib/adm/daemons/weapond.c:7-11`、`std/weapon/sword.c`、`d/oldpine/obj/long_sword.c`：本切片选定武器和动作路径；
- `reference/es2/mudlib/daemon/skill/sword.c`：基础 sword skill 没有 authored hit override。

## 1. 当前闭合 Core 能力

现有闭合领域已经具备下列能力，Runtime 不应复制其规则：

| 能力 | 现有权威/API | Runtime 只负责 |
| --- | --- | --- |
| 角色属性、gin/kee/sen、阈值 | `CharacterState`、`CharacterResourceState` | 持有角色 authority，刷新 HUD |
| 技能、成长、authored level-up effects | `CharacterSkillState`、`CombatProgressionService`、`SkillImprovementEffectRegistry` | 提供当前投影和默认 effect registry |
| 主/副武器与 Armor 聚合 | `EquipmentState`、`ArmorState` | 建立切片物品并投影数值；不复制槽位 |
| 整数 busy | `ActionBusyState` | 每个外层机会开始时推进一次 |
| 本地敌对、致死、guard、last opponent | `CombatRelationshipState` | 建立 kill 关系和跨角色编排 |
| 对手 cleanup/偏置选择 | `CombatOpponentSelectionService` | 提供 exists/same-location/living facts |
| visibility/courage/guard/互相 fight | `CombatFightDecisionService` | 提供当前事实 |
| action source 优先级与随机选择 | `CombatActionSelector` | 提供显式切片 action set |
| 普通攻击、force、伤害、伤势、成长、interrupt | `CombatAttackCompletionService` | 组装当前 typed inputs |
| 一次正向攻击与反击请求 | `CombatSingleAttackExecutionService` | 调用并保留同一 RNG |
| 最多一次同步 live reverse attack | `CombatAttackChainCompletionService` | forward 后重建 reverse projection |
| death inventory/corpse/decay intent | `DeathInventoryService`、`CorpseState`、`CorpseDecayService` | 提供 logical world endpoint，生成尸体 Node |

Phase 5B3 的最终结果是“一条攻击链”，不是 heartbeat、CombatStep 或 encounter loop。它故意不拥有 Node、Timer、World、生命周期和表现。

## 2. 精确缺失的 Runtime 部件

第一切片真正缺少的只有：

1. 一个 Node-free、场景生命周期内的角色 Runtime binding；
2. 一组按用途命名的当前投影构造函数；
3. 一个“一名角色的一次外层战斗机会”执行器；
4. 一个 encounter-local Godot RNG adapter；
5. 一个场景局部 `Timer` 和稳定参与者顺序；
6. 一个外层 unconscious/death adapter；
7. 一个 Phase 4B5C death/corpse 到场景 Node 的窄 adapter；
8. 一个把 typed result 转为本场景视觉提示的 presenter；
9. 一个小场景、简单移动、选择/攻击输入和最小 HUD。

不缺、也不应新增：第二套伤害/冷却、通用 CombatManager、全局对象注册表、World hierarchy、通用事件总线、服务定位器或 LPC callback dispatcher。

## 3. 最小场景架构

```text
CombatVerticalSlice (Node2D，唯一 composition root)
├── ArenaFloor / Walls (原生占位几何与碰撞)
├── Player (CharacterBody2D + shared character-view script)
├── Enemy (CharacterBody2D + 同一 shared character-view script)
├── Camera2D
├── OpportunityTimer (1.0 s)
├── CorpseLayer (Node2D)
└── HUD (CanvasLayer)
    ├── PlayerVitality
    ├── EnemyNameAndVitality
    ├── AttackButton
    └── CombatLog
```

场景根拥有本 encounter 的 bindings、共享 `InventoryState`/`CombinedStackCollection`、RNG、机会执行器和 presenter。角色 Node 只处理物理表示、选择命中区、非权威动画和玩家移动。不存在场景外 singleton。

地图使用一个带边界墙的小竞技场。角色在 arena 内可移动；移动不会被 combat root。由于没有出口，两个 live participant 的 location ID 始终是 `&"combat_vertical_slice_arena"`。这比发明 combat rooting 或距离脱战规则更少引入新政策。

## 4. Player/NPC Runtime 所有权

### Node-free binding

`CombatSliceCharacterBinding` 只服务该切片，建议拥有：

- stable `CharacterId`；
- `CharacterState` authority；
- 独立 `CombatRelationshipState`；
- 独立 `ActionBusyState`；
- 独立 `ArmorState`（`CharacterState` 当前不内含 Armor）；
- `CombatSliceContentProfile`，保存本切片已核实的 limbs、action/weapon projection 和 authored-policy status；
- `location_id`；
- `exists_in_encounter`；
- typed life status：`ACTIVE`、`UNCONSCIOUS`、`DEAD`；
- `is_user` 与 `combat_available` 的窄 Runtime 事实。

`CharacterState.equipment` 仍是唯一武器槽 authority；binding 不复制 Equipment。`InventoryState` 与 stack collection 属于 encounter session，因为 containment 是跨角色/尸体关系，不属于单个角色。

### Shared physical representation

玩家与 NPC 使用同一个 `CombatSliceCharacterBody`，Node 持有 binding 引用，binding 不持有 Node。差异由薄 adapter 表达：

- Player：读取移动输入、允许被选目标以外的 UI 操作、发出攻击请求；
- NPC：静止/简单 idle、可被选中，不运行行为树；
- 双方所有战斗、资源、技能、Equipment 和关系规则均调用同一 Core。

NPC 不需要独立 Combat 类、通用 AI controller 或 LPC `NPC` 继承仿制。

## 5. Combat initiation

第一交互固定为：

```text
点击 NPC / 设为当前目标
→ 点击 HUD「攻击」
→ 验证双方存在、同 arena、目标未死且不是自己
→ player.relationship.mark_lethal_target(npc_id)
→ npc.relationship.mark_lethal_target(player_id)
→ 启动 encounter-local OpportunityTimer
```

第二次 mutation 对应 `cmds/std/kill.c` 的 NPC 分支：玩家 `kill_ob(obj)` 后，非 user victim 执行 `obj->kill_ob(me)`。不要实现命令解析、文本 alias 查找或玩家间需要双方确认的规则。

建议返回一个窄 `CombatSliceInitiationResult`，只报告验证结果和两侧关系是否变更；如果第二侧异常失败，保留第一侧已发生的 mutation，不把 initiation 假装成事务。

## 6. Combat cadence

推荐 prototype cadence：一个场景局部、`wait_time = 1.0` 秒的 `Timer`。每次 timeout 按固定注册顺序 `[player, npc]`，分别给仍存在的每名角色一次独立外层机会。

1 秒只是 Runtime/表现调优，不进入 Core、角色属性或 save data。第一切片不从速度、技能或动画长度推导 cadence。稳定顺序使测试和表现可复现；它不是对 MudOS driver 对象调度顺序的兼容声明。

Timer 只在至少有一个未清理的战斗关系时运行。关系结束或参与者死亡且完成清理后停止。Condition/recovery 不挂在这个 1 秒 Timer 上：`std/char.c` 把它们放在独立的 `tick = 5 + random(10)` 路径，第一切片又没有 condition 内容，因此混入 combat cadence 会制造错误语义。

## 7. Busy ordering

一名角色的一次 opportunity 顺序固定为：

```text
外层 lifecycle gate
→ 若该角色已不 ACTIVE，结束本次机会
→ if ActionBusyState.is_busy():
       advance() 恰好一次
       结束本次机会
→ opponent cleanup/selection
→ fight decision
→ 可选完整 attack chain
```

这对应 `std/char.c`：death/unconscious 在 busy 前；busy 时 `continue_action()` 并立即 return；本机会不攻击。正 busy 每次机会减一，负 busy 在第一次推进时清除。不要再增加 cooldown、attack timer 或 animation lock。攻击内 interrupt 仍由闭合 `CombatAttackCompletionService` 按源顺序处理同一个 `ActionBusyState`。

6B1 尚不执行 lifecycle；它在相同第一位置检测阈值，并返回 typed `LIFECYCLE_REQUIRED` opportunity result，且不再处理 busy/selection/attack。6B3 接入 adapter 后消费该结果并执行转换。这样 6B1 就能锁定顺序，而不会偷偷实现半套 death/unconscious。

## 8. Threshold / lifecycle ordering

### 不可跨越的边界

`CombatAttackResult.threshold_candidate` 和 force reflection candidate 只是证据。Runtime 不得在 forward 和 reverse 之间、也不得在 chain 返回前执行 unconscious/death。

精确顺序是：

```text
actor opportunity 开始
→ 检查 actor 上一机会之后留下的 live resources
→ death 优先；其次 unconscious
→ 若无 lifecycle，才处理 busy 和 combat
→ 完整 forward attack
→ 若请求，立即基于 forward 后 live state 重建 reverse projection
→ 完整 reverse attack
→ chain 返回；本次 actor opportunity 结束
→ 被影响角色到达自己的下一次外层 opportunity 时才执行 lifecycle gate
```

因此若 player 的 forward 令 NPC 越过阈值，而本次 Timer 的稳定顺序下一项正好是 NPC，NPC 会在自己的本次外层机会开始时先进入 lifecycle，不会再普通攻击。若 NPC 的同步 riposte 令当前 player 越过阈值，player 要等自己的下一次 opportunity；同一 Timer 中随后到达的 NPC 仍可能观察到 player 的 Runtime `living` 尚未翻转。这正是“同步 reverse 先完成、外层 heartbeat 后处理”的边界，不应提前现代化。

### gate 判定

按 `std/char.c` 保留：

1. 任一 effective gin/kee/sen `< 0`：DEATH；
2. 否则任一 current `< 0`：
   - Runtime 仍 living/ACTIVE：UNCONSCIOUS；
   - Runtime 已 nonliving/UNCONSCIOUS：DEATH；
3. 否则无 lifecycle。

UNCONSCIOUS adapter 把三项 current 置 0、将 Runtime status 设为 `UNCONSCIOUS`/living=false，并终止本机会。第一切片不实现 `call_out(revive, random(100-con)+30)`；如果致死对手仍有 lethal marker，它可以在后续 opportunity 按 QUICK 路径继续攻击 nonliving victim，最终使其死亡。自动苏醒、环境向外移动和 winner reward 留待以后。

DEATH adapter 先处理 source-equivalent 清理/condition/death inventory，再标记 DEAD。第一切片只有两个 reciprocal lethal participants，因此可通过两侧 `remove_lethal_relation()` 完成最终关系清理；不要借此声称已经迁移任意多对手的完整 `remove_all_enemy()`/`remove_all_killer()` 生命周期服务。

这里存在一个应在 6B3 正面处理的窄 API 缺口：`unconcious()` 的 `remove_all_enemy()` 会先让对方尝试普通 `remove_enemy(victim)`，随后无条件清空 victim 本地 enemy，但保留双方 killer markers。当前 `CombatRelationshipState` 没有公开“清本地 opponents、保留 lethal markers”的转换，唯一绕过 lethal gate 的 `_remove_opponent_for_cleanup()` 明确只供 5B3A cleanup 使用。Runtime 不应滥用 underscored seam。推荐 6B3 只为这个已证明的规则增加一个窄、typed、无 Node 的 relationship transition（例如 `clear_opponents_preserving_lethal_targets()`），并为 reciprocal-removal 顺序写 LPC-derived 测试；这是一项缺失生命周期操作，不是重做 Phase 5B3 或通用关系框架。

### Phase 4B5C adapter 可行性

NPC death 可以完整调用现有 `DeathInventoryService.process()`，因为本切片能够提供它要求的全部 authority：

- encounter 共享的 `InventoryState` 和空的 `CombinedStackCollection`；
- NPC 当前 direct inventory 的 `DeathItemFacts`（长剑实例及其 definition）；
- `ItemLifecycleOwnerContext(npc_id, npc.character.equipment, npc.armor_state)`；
- 空 `DeathItemPolicyRegistry` 与空 `DeathRewearPolicyRegistry`（切片物品没有特殊 death hook/armor）；
- arena 的 logical `WORLD` endpoint 和一个显式、足够容纳切片内容的场景容量事实；
- stable corpse `ItemDefinition`/`ItemInstance`，legacy metadata 指向 `obj/corpse.c`；
- human age、gender、body weight 60000 和 max encumbrance 100000 快照。

成功结果中的 `CorpseState` 与 corpse item ID 仍由 Inventory/Corpse domain 权威持有；Runtime 只在 NPC 原物理位置创建 `CombatSliceCorpseView`。NPC 长剑会经现有 transfer 顺序解除 primary wield 并进入 corpse direct contents。返回的 initial decay intent 在第一切片保留但不调度，因为 corpse decay Timer/世界散落不属于首场战斗。若 typed death result 失败，Runtime 报告结果且不从头重放；NPC 的 DEAD/战斗停止与是否成功生成 corpse view 分开处理。

玩家死亡也可复用 normal death inventory/corpse 部分，但玩家 ghost/death-room journey 尚未实现；切片在之后进入 defeat/reset overlay，不把这当成完整 ES2 player death parity。

HUD 可在 chain 后立即反映已突变的 kee，但“昏迷/死亡”提示、禁用和尸体只在上述 gate 真正执行时出现。

## 9. Projection construction timing

建议一个无状态 `CombatSliceProjectionBuilder`，只提供窄命名函数：

- `build_opponent_availability(owner, participants)`；
- `build_fight_facts(attacker, victim)`；
- `build_action_selection_input(attacker)`；
- `build_attack_input(attacker, defender, selected_slice_action)`；
- `build_progression_facts(character, attack_skill_id)`；
- `build_busy_projection(character)`；
- `build_reverse_projection(original_victim, original_attacker, request)`。

不得用 `GenericCombatContext`、Dictionary bag、reflection 或 service locator。

一次 opportunity 的调用时间线：

1. 从 actor 当前 opponent snapshot 建 availability facts，调用 `CombatOpponentSelectionService.prepare()`；
2. 对选中的 live binding 现建 `CombatFightDecisionFacts`，调用 `CombatFightDecisionService.decide()`；
3. 只有 QUICK/REGULAR intent 才现建 selection、attack、progression、busy 和 raw-composure authority，调用 `CombatSingleAttackExecutionService.execute()`；
4. 若 forward 返回 `CombatRiposteRequest`，必须在 forward 完成后重新读取原 victim 的当前 Character/Skill/Equipment/Armor/busy/relationship，构造 `CombatReverseAttackProjection`；
5. 调用 `CombatAttackChainCompletionService.complete()`。无 reverse 时可传 null projection，由闭合服务完成 chain；
6. 返回一个切片专用 `CombatSliceOpportunityResult`，组合 selection/fight/chain/lifecycle-stage evidence，但不复制 authority，也不成为 Core `CombatStep`。

第一切片 action set 只有一个 `slash`，解决了现有 single-attack API 要求 selected action 与 attack template 精确一致的问题；仍会在 selector 位置消费一次 `random(1)`，不会偷看或重复消费 RNG。

### 数值投影

- attack skill：当前 primary weapon 的开放 `skill_type`，否则 `unarmed`；
- effective levels：从当前 `CharacterSkillState` 加已明确的 typed modifier；
- attack/defense usage：来自 typed Armor aggregate 对应字段；本切片无 Armor，均为 0；
- `apply/damage`：本切片长剑已核实的 `weapon_prop/damage = 25`，没有其他 producer；
- armor/armor-vs-force：当前 `ArmorState.aggregate_numeric_modifiers()`；本切片为 0；
- primary weapon facts：只读当前 `CharacterState.equipment.primary_weapon()`；
- standard force：本切片无 mapped force、factor=0、current/max force=0，seam 不到达；
- policy status：每个 provider 都显式投影，不使用 permissive 默认值。

## 10. Opponent availability / visibility / living facts

### Availability

- `exists`：binding 仍注册在 encounter 且没有完成 DEAD/despawn；不等于 Node 是否正在播淡出；
- `same_location`：两 binding 的 `location_id` 相等，第一场景即同一个 arena ID；
- `living`：显式 Runtime status 为 `ACTIVE`。

`CharacterState` 资源越界不会在同步 attack chain 中自动改变 living。只有下一外层 lifecycle gate 才翻转。

### Visibility

本切片没有 wizard、invisibility、ghost 或 astral content，故 `target_visible = true` 是明确的场景/content fact。它不是改写 `visible()` 规则。perception projection仍可合法提供，但 visible 分支不会读取或消费 perception RNG。

### Combat availability

actor 必须 exists、ACTIVE、同场景且关系中有 opponent。UNCONSCIOUS 仍可作为带 lethal marker 的 nonliving victim 被选择，但自己不能执行 fight。DEAD 在关系清理后从 registry 移除。

## 11. RNG adapter boundary

新增 `GodotCombatRandomSource` 应放在 `game/runtime/combat_slice/`，实现现有 `CombatRandomSource.next_below()`，内部拥有一个 encounter-local `RandomNumberGenerator`。生产场景初始化一次种子；测试继续注入 `ScriptedCombatRandomSource`。

同一 encounter、同一条流必须连续覆盖：opponent `random(4)` → fight courage/guard → action `random(1)` → ordinary attack/progression → riposte decision → reverse action/ordinary。不要为 selector、resolver 或反击建立第二个 RNG，也不要调用全局 `randi()`。若收到非正 bound，adapter 返回非法 sentinel 供 Core typed failure 捕获；它不自行 clamp。

## 12. Presentation flow

表现层不触发规则。推荐：

```text
OpportunityResult / LifecycleResult
→ CombatSlicePresenter 顺序读取 typed evidence
→ 立即更新 HUD authority projection
→ 排队/播放非权威提示
```

最小提示映射：

- `CombatFightDecisionResult.ENTERED_GUARDING` → 防守文本/颜色；
- selected action `slash` → 攻击者短促位移或闪色；
- base outcome DODGE/PARRY/HIT → 对应文本和目标闪色；
- wound transition → 伤势标记或加深颜色；
- QUICK/RIPOSTE request/reverse result → “抢攻/反击”提示；
- friendly stop（本致死切片通常不触发） → 停战提示；
- lifecycle gate → 昏迷/死亡提示；
- completed Phase 4B5C result → NPC body 隐藏、尸体 view 出现。

不需要全局 event bus。Presenter 可直接消费 typed opportunity result；如果为了按顺序播放需要中间值，只定义 `CombatSlicePresentationCue` 的封闭 enum 和明确字段，不使用 Dictionary payload。

Core 每个 opportunity 的全部 mutation 先完成；Tween/AnimationPlayer/文字淡出随后播放。下一个 gameplay opportunity 不等待 `animation_finished`。视觉 cue 可以排队或重叠，但不能使半条 Core chain 暂停。

## 13. Minimal HUD

只实现：

- 玩家 kee current/effective/maximum bar；
- NPC 名称与 kee current/effective/maximum bar；
- 当前选中目标；
- “攻击”按钮；
- 一到四行滚动 combat log；
- 玩家死亡时的“失败/重置场景”按钮。

gin/sen 可以用小文本显示，但不阻塞第一切片。不要添加 inventory、skills、perform、quest 或最终 HUD 布局。

## 14. Source-backed sample combat configuration

### Character facts

双方使用确定性的 human-compatible prototype 数值；这些值位于 `race/human.c` 随机属性 10..30 范围内，不代表已经迁移某个 authored NPC：

| Fact | Player | NPC | 来源/目的 |
| --- | ---: | ---: | --- |
| age | 20 | 20 | human 派生公式 |
| str/cor/int/spi/cps/per/con/kar | 各 20 | 各 20 | 合法 human 范围；raw cor/cps 可产生 attack/guard 两分支 |
| force_factor / bellicosity | 0 / 0 | 0 / 0 | 不进入 force，保留 raw fight 门 |
| gin current/effective/max | 220/220/220 | 220/220/220 | `human_maximum_essence(20,0)` |
| kee current/effective/max | 220/220/220 | 220/220/220 | `human_maximum_vitality(20,0)` |
| sen current/effective/max | 100/100/100 | 100/100/100 | `human_maximum_spirit(20,0)` |
| force/mana/atman current/max | 0/0 | 0/0 | 本场不使用内力 policy |
| combat_exp | 10 | 10 | 正值，保持双方公式对称且 defense loop 合法 |
| sword/dodge/parry/unarmed | 各 raw 10 | 各 raw 10 | 允许 hit、dodge、parry；不发明公式 |
| force/perception | raw 0 | raw 0 | visible=true；force seam 不到达 |
| skill mappings | 空 | 空 | 不选择 martial/force daemon |
| Armor | 无 | 无 | armor 与 armor-vs-force 均 0 |
| limbs | human.c 的 16 项 | 同左 | 不发明默认 limb |

双方相同 AP/DP/PP 使 dodge/parry 都有非零概率；`raw cor 20` 对 `raw cps * 3 = 60` 使 REGULAR 与 guard 都可出现。伤害仍完全由既有 resolver 计算，不加 demo multiplier。

### Weapon/action path

双方各持一个不同 `ItemInstanceId`、同一 definition 的：

```text
d/oldpine/obj/long_sword.c
→ inherit SWORD
→ std/weapon/sword.c::init_sword(25)
→ skill_type = sword, weapon_prop/damage = 25
→ WEAPON_D action "slash"
```

切片 action definition 精确投影：

- ID：`es2:adm/daemons/weapond/slash`；
- `damage_percent = 0`；
- `force_percent = 0`；
- `damage_type = 割伤`；
- legacy action text：`$N挥动$w，斩向$n的$l`；
- `post_action_policy_id = empty`。

`slash` 的 legacy `parry = 20` 不进入 active definition，因为 `combatd.c::do_attack()` 从不读取 action 的 `parry`/`dodge` 字段；这是 Phase 5A/5B1 已关闭的语义，不是本阶段删除 bonus。

标准 sword 原本可在 `slash/slice/thrust` 中随机选取。第一切片显式把该内容 profile 限为 exact `slash` 单项：这只是选择一个真实来源路径来证明 Runtime integration，不宣称所有长剑永远只有一个动作。三者在当前 active gameplay fields 中都没有 damage/force/post_action 差异；完整 authored action distribution 属于后续内容迁移。单项 selector 仍消费 `random(1)`。

此路径无需 Phase 5B4，因为：

- action 没有 post_action；
- `long_sword.c`、`std/weapon/sword.c` 没有 `hit_ob()`；weapon status 可明确为 `PROVEN_NO_AUTHORED_EFFECT`；
- `daemon/skill/sword.c` 仅继承基础 `SKILL`；没有 mapped martial hit policy；
- force factor/current/mapping 均不满足 standard或 authored force 入口；
- 无 NPC authored hit provider、perform、exert、cast 或 conjure。

Inventory 初始化时两把剑均为角色 direct child，并通过现有 `EquipmentState` 持为 primary；own weight 取来源 7000。角色 body weight 为 `human_weight(20) = 60000`，max encumbrance 为 `maximum_encumbrance(20) = 100000`。

## 15. Phase 5B4 exclusions/backlog

### A. 第一 playable slice 前必需

无。选定 `slash` 路径已被现有 ordinary contracts 完整覆盖。不能为了“以后可能需要”先实现任何 Phase 5B4 policy。

### B. 更丰富普通武器所需

- `bash/crush/slam` → `WEAPON_D::bash_weapon`：需要 live 双方武器、weight/rigidity、raw str、Equipment 解除、world drop、reset action、武器断裂后的每实例 name/value/weapon_prop mutation；
- `throw` → `WEAPON_D::throw_weapon`：需要 CombinedStack amount、amount==1 时 unequip、递减/零量 destruction 顺序；
- 完整 weapon verb/action 数据和 typed numeric weapon projections；
- 逐个 authored weapon/NPC `hit_ob()` policy，而不是通用 callback。

### C. Authored martial arts 所需

- mapped martial action tables；
- `ts-fist`、`spicyclaw` 等额外 wound policies；
- `iceforce` 的父级 standard force + iceshock/condition 组合；
- 各 perform/exert/cast/conjure 作为独立 typed policy，不并入 ordinary action registry。

### D. 更后期

- NPC aggression/hatred/vendetta/berserk、flee/wimpy；
- 多对手 UI、full lifecycle/revive/ghost、killer rewards/quest/faction consequences；
- corpse decay scheduling、loot UI、世界掉落位置；
- 完整 authored content、VFX/audio 和 animation sets。

## 16. Proposed implementation file list

这是建议清单，不在 Phase 6A 创建：

### 6B1 — Headless Runtime bridge

- `game/runtime/combat_slice/combat_slice_life_status.gd`
- `game/runtime/combat_slice/combat_slice_character_binding.gd`
- `game/runtime/combat_slice/combat_slice_content_profile.gd`
- `game/runtime/combat_slice/combat_slice_initiation_result.gd`
- `game/runtime/combat_slice/combat_slice_projection_builder.gd`
- `game/runtime/combat_slice/combat_slice_opportunity_result.gd`
- `game/runtime/combat_slice/combat_slice_opportunity_executor.gd`
- `game/tests/runtime/combat_slice_opportunity_integration_test.gd`
- 一个对应的 focused test runner

### 6B2 — Scene, cadence and presentation

- `game/runtime/combat_slice/godot_combat_random_source.gd`
- `game/runtime/combat_slice/combat_vertical_slice_controller.gd`
- `game/runtime/combat_slice/combat_slice_character_body.gd`
- `game/runtime/combat_slice/combat_slice_presenter.gd`
- `game/runtime/combat_slice/combat_slice_hud.gd`
- `game/scenes/combat/combat_vertical_slice.tscn`
- `game/tests/runtime/combat_vertical_slice_smoke_test.gd`
- `game/project.godot`：只增加该切片需要的 input actions；是否设为 main scene 在 6B2 明确决定

### 6B3 — Outer lifecycle and corpse

- `game/core/combat/relationship/combat_relationship_state.gd`：仅新增上述 source-backed incapacitation 清理转换（若 6B3 复核确认仍无其他公开组合方式）
- `game/runtime/combat_slice/combat_slice_lifecycle_adapter.gd`
- `game/runtime/combat_slice/combat_slice_death_adapter.gd`
- `game/runtime/combat_slice/combat_slice_corpse_view.gd`
- `game/tests/runtime/combat_slice_lifecycle_corpse_test.gd`

不要新增 autoload、通用 `runtime/entities` 基类、repository、generic scheduler 或 event-bus 文件。

## 17. Proposed test strategy

### 6B1 deterministic headless

- kill initiation 的 player→NPC、NPC→player 顺序；
- 1 个 opportunity 的 lifecycle gate → busy → selection → fight → chain 顺序；
- lifecycle threshold 命中时只返回 `LIFECYCLE_REQUIRED`，不推进 busy、不取 RNG；
- busy 每次推进一次且完全抑制本机会 RNG/攻击；
- availability 的 exists/same-location/living 映射；
- visible=true 不消费 perception RNG；
- guard、DODGE、PARRY、HIT、QUICK 与 RIPOSTE 的 scripted sequences；
- forward 后才构造 reverse projection，且观察 live progression/equipment/resource；
- forward/reverse candidate 不触发生命周期；
- 从 opponent 到 reverse 全程一条 RNG，含单项 action 的 `random(1)`；
- 两名角色不共享 Character/relationship/busy/Armor/content mutable state。

### 6B2 scene integration

- 场景可 headless load；
- 选中 NPC 后 Attack button 建立关系并启动 Timer；
- 玩家移动不改变 arena location；
- 每个 timeout 每名 active actor 最多一次 opportunity；
- HUD 始终读取 live resource，动画 callback 不触发 Core；
- 注入 scripted RNG 时 log/cue 顺序确定。

### 6B3 lifecycle/corpse

- effective `< 0` 优先 death；current `< 0` 且 ACTIVE 才 unconscious；
- candidate 在 chain 内不应用，在下一 actor opportunity 才应用；
- unconscious 把三 current 置 0、living=false，致死对手仍可 QUICK 追击；
- death 清 condition，最终清两侧 lethal relation，Timer 停止；
- NPC 剑由 character direct inventory 卸持并转入 fresh corpse；
- `DeathInventoryService` 的 typed failure 不盲目重放；
- corpse view 仅映射成功返回的 `CorpseState`，不成为 item authority；
- 玩家死亡进入切片 defeat/reset，不伪装完整 ghost journey。

Phase 6A 本身不运行完整回归；后续实现阶段应运行 focused tests、完整既有 suite、Godot headless editor validation 和 `git diff --check`。

## 18. Explicit non-goals

- 不实现 Phase 5B4、bash/throw、martial/perform/exert/cast/conjure；
- 不实现通用 CombatStep Core、heartbeat emulator 或 attack-speed formula；
- 不实现 Condition/recovery 调度、auto-revive、ghost/death room、reward；
- 不实现行为树、NPC aggression、pathfinding 或全世界 location registry；
- 不实现 inventory/skill/perform UI、loot loop 或 corpse decay Timer；
- 不实现 final art、音频、复杂 AnimationTree；
- 不实现 full weapon/action/NPC content migration；
- 不新增 GameManager、CombatManager、ECS、DI container、通用 event bus、service locator 或 LPC compatibility API。

## 19. Recommended implementation slices

### Phase 6B1 — Runtime Character Binding + Current Projection + One Opportunity

建立 Node-free binding、明确的 source-backed content profile、命名 projection builder、kill initiation 和单 actor opportunity executor；使用 scripted RNG 完成端到端 headless 测试。此阶段不得加入 Timer/scene/UI，也不执行生命周期。它首先证明 Runtime 能在正确时间组装闭合 API，而无需修改 Combat Core。

### Phase 6B2 — Playable Arena + Cadence + HUD/Presentation

建立专用场景、shared CharacterBody representation、玩家移动/选择/Attack、encounter-local 1 秒 Timer、Godot RNG adapter、vitality HUD 和直接 presenter。此时 threshold 仍由 6B1 result 保留，场景可演示战斗，但完整终局由 6B3 收尾。

### Phase 6B3 — Outer Lifecycle + Phase 4B5C Corpse Adapter

在 actor opportunity 开头应用 death/unconscious，处理单 encounter 的关系终止，组装现有 `DeathContext`、`DeathItemFacts`、policy/rewear registries、corpse identity 和 WORLD destination，调用 `DeathInventoryService`，再把返回的 `CorpseState` 映射为简单 corpse Node。该拆分确有必要：Phase 4B5C 需要 Inventory/Equipment/Armor/stack/world endpoint 的一致 authority，且玩家 ghost/revive 与 NPC destruction 必须明确区分，塞入 6B2 presenter 会模糊生命周期边界。

Phase 6B1 已具备足够明确的输入、输出、顺序、内容与测试合同，可以开始；Phase 6B2/6B3 不需要先扩展 Phase 5B4。
