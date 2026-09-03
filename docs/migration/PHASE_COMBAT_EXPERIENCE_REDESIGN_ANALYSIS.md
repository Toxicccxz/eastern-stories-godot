# Combat Experience Redesign Analysis

## 1. Executive Summary

本阶段只分析，不选择战斗交互模型，也不修改战斗规则、UI、场景、数值或测试。

ES2 的普通战斗最准确的描述是：**角色心跳驱动的自动基础攻防，加上玩家随时输入的手动战术动作**。建立 `fight_ob()` / `kill_ob()` 关系后，角色在每次可行动的心跳中自动选敌，由 `COMBAT_D->fight()` 在普通攻击与守势之间判定，再由 `do_attack()` 结算动作、闪避、招架、伤害、伤势、成长、中断及可能的即时反击；玩家仍可在自动循环之间施展外功、内功、法术、逃跑或换装。证据见 `reference/es2/mudlib/std/char.c:56-95`、`feature/attack.c:20-44,112-146,222-235`、`adm/daemons/combatd.c:197-500`。

当前 Godot 已经把大量可复用语义拆成 typed、Node-free 领域对象：角色资源、技能、装备、战斗关系、busy、普通攻击数值、force、成长、反击、昏迷、死亡、尸体和掉落都不应因为展示重做。问题集中在运行时边界：`OldPineOutdoorController` 同时承担世界触发、参与者投影、1 秒节拍、机会执行、生命周期和世界内 HUD 日志，玩家只能在探索画面中选择 NPC 后按 `Attack`，随后看自动日志。证据见 `game/runtime/world/oldpine_outdoor_controller.gd`、`oldpine_outdoor_hud.gd` 和 `game/scenes/world/oldpine/oldpine_outdoor.tscn`。

推荐的架构方向是：

```text
World Exploration
    -> typed CombatTrigger（为什么、以何种意图开始）
    -> CombatEncounter（参与者、阵营、阶段、结果的活动上下文）
    -> Dedicated Battle Presentation（只呈现投影并提交 typed intent）
    -> existing Combat Resolution / Character authorities
    -> typed CombatEncounterResult
    -> Return to World Session
```

该边界不固定为 1v1，也不预先决定半自动、ATB 或传统回合制。现有 Core 多数可以原样复用；现有 `CombatSlice*` 运行时桥接需要在未来实现阶段被包裹或一般化，而不是复制一套战斗规则。

## 2. Why the Current Presentation Needs Reconsideration

当前 Old Pine 的战斗发生在正常探索场景内：NPC 的 `Area2D` 触发侵略队列，或玩家点击 NPC 后按 `Attack`；成功建立双向致死关系后，地图自身的 `OpportunityTimer` 启动。每次 timeout 按当前参与者数组顺序执行机会，结果立即写入同一张地图 HUD 的最多六行 combat log。玩家角色的 `CharacterBody2D` 在 ACTIVE 时仍读取正常移动输入，Inventory、Wield、Unwield、Wear、Remove 也没有战斗关系或 busy 检查。证据见：

- `game/runtime/world/oldpine_outdoor_controller.gd:546-556,689-781,856-955,1148-1178,1536-1542`；
- `game/runtime/world/world_character_body_2d.gd::_physics_process()`；
- `game/runtime/world/oldpine_equipment_interaction_adapter.gd`；
- `game/runtime/world/oldpine_armor_interaction_adapter.gd`；
- `game/runtime/world/oldpine_outdoor_hud.gd:refresh_live_state()`；
- `game/scenes/world/oldpine/oldpine_outdoor.tscn:1027-1029,1100-1148`。

这条路径证明了规则可以从真实世界角色状态完成端到端结算，但它仍是 first playable slice 的展示形态：没有外功、内功、法术、物品或战术防御选择，也没有明确的 encounter 进入、胜负总结和返回边界。玩家面对的是持续走动的世界、少量生命条和文字日志，而不是一个能承载 ES2 大量武学内容的战斗决策空间。

仓库中另有早期 `game/scenes/combat/combat_vertical_slice.tscn` 和 `CombatVerticalSliceController`。它是验证同一 Core 的封闭竞技场原型，不是当前 ApplicationShell 的战斗入口，也不应未经重新设计直接升级为最终 battle scene。

## 3. ES2 Original Combat Model

### 3.1 一句话模型

**ES2 是异步自动基础攻防 + 手动特殊动作的半自动战斗，而不是玩家逐次输入普通攻击，也不是有全局轮次的传统回合制。**

### 3.2 战斗建立后的行为

`fight_ob(ob)` 只做两件关键事情：打开角色 heartbeat，并把对象加入该角色自己的 `enemy` 数组；`kill_ob(ob)` 先把目标的稳定文本 ID 加入 `killer`，再调用 `fight_ob()`。它们不立即结算普通攻击。见 `reference/es2/mudlib/feature/attack.c:10-44,112-121`。

普通攻击随后由每个角色自己的 `std/char.c::heart_beat()` 推进：

1. 先检查 effective gin/kee/sen 的死亡阈值；
2. 再检查 current gin/kee/sen 的昏迷/死亡阈值；
3. busy 时只 `continue_action()` 并立即返回；
4. 非 busy 时先检查 wimpy，再调用 `attack()`；
5. `attack()` 清理失效敌人、选择一个敌人、记录 `last_opponent`，调用 `COMBAT_D->fight()`；
6. condition/recovery 使用另一个 `tick = 5 + random(10)` 分支，不是每次攻击机会的一部分。

证据：`reference/es2/mudlib/std/char.c:45-127`、`feature/attack.c:123-146,222-235`。

因此 ordinary attack 一旦关系建立就是自动的。MudOS heartbeat 是旧运行时的调度手段，不代表新 RPG 必须模拟对象心跳或固定真实秒数；值得保留的是“自主基础攻防机会、busy 会占用机会、特殊动作与基础循环交错”的语义。

## 4. Combat Initiation Paths

| 起因 | LPC 行为 | 持久语义 | 来源 |
|---|---|---|---|
| `fight <target>` | speaking NPC 可接受/拒绝；玩家需双方依次确认；成功时双方 `fight_ob()` | 非致死交手意图、可拒绝或需同意 | `cmds/std/fight.c` |
| `kill <target>` | 发起者 `kill_ob()`；NPC 目标会反向 `kill_ob()`，玩家目标只先 `fight_ob()` | 可不对称的致死意图，目标仍会还手 | `cmds/std/kill.c` |
| aggressive | 同室玩家触发延迟复核后 NPC `kill_ob()` | NPC 侵略触发 | `feature/attack.c:241-272`、`combatd.c:507-627` |
| hatred | NPC 保留 killer ID；再次遇见玩家时尝试致死重启 | 跨相遇仇恨 | 同上 |
| vendetta | NPC `vendetta_mark` 与玩家标记匹配后致死 | authored/scripted 敌意 | 同上 |
| berserk | bellicosity/force/score 判定后可能 `fight_ob()` 或 `kill_ob()` | 非固定致死的冲突触发 | `combatd.c:522-560` |
| special technique | 法术/招式可直接建立 fight/kill 关系 | 动作本身可成为触发器 | 例如 `daemon/class/taoist/necromancy/feeblebolt.c:44-63` |

`auto_fight()` 明确拒绝 NPC 对 NPC，并用零延迟 `call_out()` 给玩家离开当前房间的机会；真正执行前重新检查对象仍存在、仍同室、施袭者可行动且房间允许战斗。这个“先发现、后复核、允许规避”的语义值得保留，但 `call_out()` 和同一 LPC room 是运行时实现，不应直接移植。

`cmds/std/biwu.c` / `feature/attack.c::biwu_ob()` 是另一个同步循环式比武实现，会在一次调用里反复 `do_attack()` 直到资源失败，并含除零、胜负标记和武器引用等明显风险。它不是 ordinary heartbeat combat 的可靠节拍依据；未来 `SPARRING` trigger 应首先承载 `fight.c` 的非致死意图，是否兼容 `biwu` 需另立决策。

## 5. Automatic Combat Loop

`COMBAT_D->fight(me, victim)` 并不等于无条件攻击：

1. attacker 必须 living；
2. 看不见目标时按 perception 随机判定能否发现；
3. victim busy 或不 living 时直接 QUICK attack；
4. 否则以 `random(victim.cps * 3) < attacker.cor + attacker.bellicosity / 50` 决定 REGULAR attack；
5. 失败则首次进入 guarding，已经 guarding 时本机会无动作。

见 `reference/es2/mudlib/adm/daemons/combatd.c:470-500`。

`do_attack()` 的普通流水线为：选择 authored action 与肢体，依据武器类型或 unarmed 计算 AP，以 dodge 计算 DP，尝试闪避和招架，叠加 weapon/mapped force/mapped martial/monster hooks，结算 current kee damage，按 lethal 或持武器条件决定 eff_kee wound，执行成长与 busy interrupt，非致死双方可能结束交手，执行 `post_action`，最后可能触发守势反击。见 `combatd.c:197-463`。

普通攻击不是动画命中驱动的。其命中、闪避、招架、伤害及进度都是规则结果；新 battle presentation 仍只能表现结果，不能让碰撞帧或动画回调成为权威。

## 6. Player Agency During Combat

自动循环并没有锁死玩家命令。玩家可在心跳之间主动做以下事情：

- `perform`：调用当前武器类型或 unarmed 所映射武学的 `perform_action()`；
- `exert`：调用 mapped force 的 `exert_function()`，否则尝试基础 force 功能；
- `cast`：调用 mapped spells 的 `cast_spell()`，可选择同室或自身 inventory 中目标；
- 正常移动：非 busy、不过载且出口允许时可以离开；成功移动后清除 opponents；
- wimpy：心跳在资源比例低于阈值时自动随机选出口尝试移动；
- 换装和 `enable`：相应命令没有通用 fighting/busy gate，低层装备会 `reset_action()`，因此源码可执行行为允许战斗中换武器、护甲或映射，具体物品仍可自行拒绝。

来源：`reference/es2/mudlib/cmds/std/perform.c:5-40`、`exert.c:7-36`、`cast.c:7-35`、`go.c`、`wield.c`、`unwield.c`、`wear.c`、`remove.c`、`enable.c`、`feature/equip.c:55-125`。

这说明玩家 agency 不在“每次点击普通攻击”，而在基础攻防持续进行时选择何时花资源、造成控制、改变映射/装备、逃跑或施展特殊效果。

## 7. Busy / Guard / Timing Semantics

### Busy

`feature/action.c` 的 busy 可以是整数或 function。整数 busy 每次 heartbeat 递减一次并占用整个角色机会；从 1 减到 0 的那次仍立即返回，下一 heartbeat 才恢复普通攻击。function busy 则每次 heartbeat 继续回调直到返回 false。命中造成正 damage 时，`do_attack()` 调用 victim 的 `interrupt_me()`；整数路径只在严格 `busy < interrupt` 时把 busy 清零，且留下 interrupt 值。见 `reference/es2/mudlib/feature/action.c:3-49`、`combatd.c:430-432`。

Busy 的影响不是一个全局命令过滤器。`perform`、`exert`、`cast`、`go` 显式检查 busy；`feature/command.c` 本身没有统一阻止所有命令。Busy 同时使普通 dodge/parry power 除以 3，并让攻击者直接获得 QUICK attack 分支。因此它兼有“失去自身自动机会”和“防御脆弱/可被抢攻”的意义。

当前 Godot 的 `ActionBusyState` 只实现已迁移战斗需要的整数路径，明确没有 closure/callback busy；这是应保留的窄 typed authority，未来战斗交互模型必须决定一个 busy 单位如何映射到 presentation cadence，而不是把它换成任意 UI cooldown。

### Guard

Guard 不是玩家在普通循环中手动选择的 stance。角色 courage 检查失败时自动进入 guarding；其后自己的机会若仍不敢出手就继续守。角色真正出手时 guarding 被清除。若 guarding 角色受到对方 REGULAR attack，而结果为 dodge/parry/零伤害，则其 guarding 清除并立即执行一次 QUICK 或 RIPOSTE 反击。见 `reference/es2/mudlib/adm/daemons/combatd.c:480-499,447-461`。

因此守势包含三项持久语义：自动产生、跨机会保留、对方失手时产生即时反击窗口。传统轮次若只把它改成“防御 +X%”会丢失关键行为。

### Timing

旧系统没有 encounter-wide round authority。每个 living 的 heartbeat 各自调用一次 `attack()`；特殊招式可以在一个命令中立即执行多次 `do_attack()`，也可用 busy/function/call_out 延后阶段。新设计可以改变玩家可理解的节拍，但必须明确哪些顺序规则被保留、哪些是对 MudOS 调度的现代化替代。

## 8. Skills / Perform / Exert / Cast

普通攻击和特殊动作共用角色的真实技能、资源、装备和成长，但不是同一种执行路径。

普通攻击首先由主手武器的 `skill_type`（否则 `unarmed`）确定 usage skill；`reset_action()` 优先使用该 usage 所 mapped 的 martial skill 的 `query_action()`，没有 mapping 时才使用武器 actions 或种族 default actions。Mapped force 可在命中时执行 `hit_ob()`；mapped martial 也可追加 hit effect；武器/怪物自身还有 hit hook。见 `reference/es2/mudlib/feature/attack.c:197-220`、`adm/daemons/combatd.c:213-354`、`adm/daemons/weapond.c`。

特殊动作则是明确的战术命令。代表性源码证明它们并非统一的“技能造成伤害”模板：

- `fonxansword/counterattack.c`：自己 busy 1，成功时令目标 busy `skill / 20 + 2`；
- `fonxansword/swordjab.c`：一次命令立即触发多次 `do_attack()`；
- `fonxansword/fakefault.c`：延迟后临时 modifier 与双方即时攻击；
- `celestial/roar.c`：消耗资源、自 busy 5，对房间多目标造成 sen damage/wound 并建立关系；
- `celestial/powerup.c`：临时 attack/dodge modifier，战斗中 busy 3；
- `necromancy/feeblebolt.c`：直接 sen damage/wound、资源成本、致死关系和 busy；
- `magic-array/dun.c`：控制或脱离/移动；
- `lotusforce/heal.c`：明确禁止战斗中使用。

来源位于 `reference/es2/mudlib/daemon/class/` 对应文件。未来不能为了统一 UI 把这些差异压成一个无类型 `Dictionary` 或单一伤害按钮；应以稳定 policy/action ID 注册 typed 行为，并让 presentation 只显示当前可用命令与结果。

当前 Godot 已有 `CharacterSkillState`、成长、authored skill-improvement effects、学习、practice/self-learning 和 `CultivationService` 的纯领域实现；combat progression 已会调用 `improve_skill()`。但 playable runtime 没有 perform/exert/cast/cultivation 战斗输入，当前 `CombatSliceContentProfile` 只提供一个 verified weapon action 与一个 unarmed action。现有技能领域应保留，特殊战斗 policy 仍是未来工作。

## 9. Kill vs Fight

`enemy`（正在交手的对象引用）与 `killer`（有致死意图的目标 ID）是分开的。致死标记会阻止普通 `remove_enemy()` 清除关系，并影响 wound 与死亡后的清理。见 `reference/es2/mudlib/feature/attack.c:10-32,149-195`。

关键差异为：

- `fight` 建立非致死对手关系；双方均没有 lethal marker 时，一次正 damage 后双方从 enemy 移除并显示胜负；
- `kill` 至少让发起者拥有 unilateral lethal marker；NPC 目标通常反向 kill，玩家目标最初只 fight；
- wound 条件实际是“攻击者正在 kill 目标 **或攻击使用武器**”。因此带武器的 friendly fight 仍可能损伤 effective kee，和 `fight.c` 帮助文本“只耗体力、不真的受伤”不完全一致；这是可执行源码行为，不应被帮助文本覆盖；
- 法术/特殊技能可绕过普通 kee-only 路径直接对 gin/sen 或 effective 值造成影响。

证据：`reference/es2/mudlib/cmds/std/fight.c`、`kill.c`、`adm/daemons/combatd.c:368-441`。

当前 Godot playable world 只暴露 `initiate_lethal_combat()`，并一次把双方都标记为 lethal。它尚未呈现 ES2 的非致死 fight、玩家同意或不对称 kill 意图。因此新的 `CombatTrigger` 必须显式表达 encounter intent，而不能把所有入口继续折叠成 `Attack == reciprocal lethal`。

## 10. NPC Aggression / Vendetta / Auto Fight

ES2 的 NPC 自动交战入口在对象同室 `init()` 时检查 hatred、vendetta、aggressive、berserk，再交给 `COMBAT_D->auto_fight()` 做一次延迟复核。NPC-NPC 自动交战被禁止，但特殊脚本仍可直接建立关系。见 `reference/es2/mudlib/feature/attack.c:238-272`、`adm/daemons/combatd.c:502-627`。

当前 Old Pine 只迁移了 narrow authored aggression：有 `AGGRESSIVE_ON_PLAYER_PRESENCE` capability 的 NPC 进入 Area 后排队，下一 `_process()` 再按 authored NPC 顺序复核角色有效、ACTIVE、同 combat location、NPC 未在战斗及地点允许战斗，随后走同一个 reciprocal lethal initiation。见 `game/runtime/world/oldpine_bandit_aggression_adapter.gd` 和 `oldpine_outdoor_controller.gd:856-902`。

这个 adapter 的“触发与关系建立分离”值得复用，但它不应直接打开 battle scene。未来所有 aggression、vendetta、quest 和 scripted paths 应先产生同一种 typed `CombatTrigger`，再由 encounter coordinator 统一验证、冻结/切换 world presentation 并建立 encounter。

## 11. Flee / Wimpy

手动 flee 在 ES2 本质上是正常 `go`：战斗中只改变离开/进入文字，成功 move 后调用 `remove_all_enemy()`。Killer IDs 不在这里清除，因此敌意可在再次相遇时重启。Busy、过载、无出口或 `valid_leave()` 拒绝都会阻止逃跑。见 `reference/es2/mudlib/cmds/std/go.c`。

Wimpy 在 heartbeat 中检查任一 current gin/kee/sen 百分比是否低于阈值，然后随机选择当前房间出口调用同一个 `go`。但源码存在明确字段不一致：`std/char.c:87` 读取 `env/wimpy`，而玩家命令 `cmds/usr/wimpy.c:12,19` 查询/写入 `wimpy`。全库搜索未发现把这两个字段同步的通用路径；大量 NPC 直接 author `env/wimpy`。因此“NPC authored wimpy 可生效”有源码支持，而“玩家 wimpy 命令能控制 heartbeat”是疑似 legacy defect，不能无声移植为确定规则。

Dedicated encounter 中不能再把 flee 等同于任意世界移动。未来需明确：逃跑成功率、选择出口/返回点、是否保留 vendetta/lethal intent、队友/召唤物如何处理，以及失败是否消耗行动机会。自动 wimpy 可以作为可选战术 policy 的灵感，但不是必须照搬的 UI。

## 12. Multi-Opponent Semantics

`enemy` 数组本身没有四人容量限制。`select_opponent()` 每次固定 `random(4)`：draw 小于数组长度时取该索引，否则取第一个。因此最多只有插入顺序前四名会被普通自动攻击选中；第五名以后仍存在于关系中，但 ordinary selection 不会直接选到。每个角色有自己的数组和 heartbeat，所以关系不要求对称，也没有全局“我方回合/敌方回合”。见 `reference/es2/mudlib/feature/attack.c:8-24,35-44,123-146`。

特殊动作还可显式选择目标、随机从 offensive targets 中选目标，或遍历同室 living 做 AoE（例如 `celestial/roar.c`）。因此新 API 必须从一开始使用 participant collection、stable CharacterId 和 side/faction relation，不能使用固定 `player` / `enemy` 两字段。首个 battle prototype 可以只放 1v1，但不能让 encounter state、result 或 presentation contract 阻止 1vN、NvN、伙伴、召唤物和增援。

## 13. Legacy MUD Mechanics vs Durable Gameplay Rules

### A. 应保留的核心游戏规则

- gin/kee/sen 的 current/effective/maximum、damage/wound、昏迷/死亡阈值；
- 技能、mapped martial/force/spells、武器类型、护甲和角色属性对结算的影响；
- fight 与 lethal intent 分离，包括不对称关系；
- busy 占用自身机会、降低防御、可能被命中中断；
- 自动守势和失手后的即时反击；
- 普通攻击目标从多名 opponents 中选择，而非强制永久锁定一个目标；
- 特殊技能可多击、控制、AoE、直接资源/伤势、临时 modifier、逃脱；
- 结算后成长、昏迷、死亡、尸体、掉落的既有顺序；
- RNG 顺序是可复现 gameplay state，而不是 presentation randomness。

### B. 文本 MUD 接口产物

- `kill/fight/perform/exert/cast` 的字符串解析、`present()` 名称查找和命令路径；
- 玩家双方重复输入 command 的同意 handshake；
- `$N/$n/$l/$w` message token 和 room broadcast；
- wizard combat verbose、help 文本、同室 room 文案；
- 用 `enable` 命令名暴露 mapping。

这些行为的意图可转成 RPG 选择/确认/targeting，但不应移植命令解释器。

### C. MudOS / heartbeat 架构产物

- 每个对象的 `set_heart_beat(1)`；
- `call_out(..., 0)`、function busy closure 和 daemon path dispatch；
- `environment()` 同室检查与运行时对象引用 enemy 数组；
- temp dbase 的 `apply/*`、`guarding`、`weapon`；
- `COMBAT_D`、`SKILL_D`、`WEAPON_D` service locator。

新设计需要明确调度器和 typed policies，但不应仿制这些机制。

### D. 可作设计灵感、并非必须逐字复现

- 自动基础攻击作为“武侠高手持续拆招”的节奏；
- courage/bellicosity 决定攻守倾向；
- wimpy 自动撤退阈值；
- aggressive 的短暂逃脱窗口；
- ordinary enemy selection 的前四名偏置；
- `biwu` 的同步连续交换攻击。

这些特征可帮助保持 ES2 气质，但具体时间、UI、动画和概率可在明确产品决策后重构。

## 14. Current Godot Combat Architecture

### 14.1 权威状态与纯领域结算

当前实现的主要层次为：

```text
CharacterState / Skills / Equipment / Armor / Progression
    + CombatRelationshipState / ActionBusyState
    -> CombatSliceProjectionBuilder（当前事实投影）
    -> OpponentSelection + FightDecision
    -> CombatActionSelector
    -> CombatAttackResolver
    -> Force / Progression / Busy / Relationship completion
    -> optional synchronous reverse attack
    -> typed results
```

关键文件：

- 角色权威：`game/core/characters/character_state.gd`；
- 关系与 busy：`game/core/combat/relationship/combat_relationship_state.gd`、`game/core/combat/busy/action_busy_state.gd`；
- 选敌与 fight/guard：`combat_opponent_selection_service.gd`、`combat_fight_decision_service.gd`；
- 数值与攻击：`combat_math.gd`、`combat_attack_resolver.gd`；
- force/成长/中断：`standard_force_hit_policy.gd`、`combat_attack_completion_service.gd`、`combat_progression_service.gd`；
- 正向/反向链：`combat_single_attack_execution_service.gd`、`combat_attack_chain_completion_service.gd`；
- runtime 投影：`game/runtime/combat_slice/combat_slice_projection_builder.gd`、`combat_slice_opportunity_executor.gd`。

这些 Core 类型是 typed `RefCounted`，没有 Node、SceneTree、Timer 或 HUD 权威。结算直接变更现有 `CharacterState` 资源/成长和关系/busy，而 structured result 保存发生过什么。这与 dedicated battle presentation 的边界兼容。

### 14.2 当前世界运行流

```text
NPC Area presence 或玩家点击 NPC + Attack
    -> OldPineOutdoorController._initiate_lethal_combat()
    -> CombatSliceOpportunityExecutor.initiate_lethal_combat()
    -> 双方 reciprocal lethal/opponent
    -> map-local OpportunityTimer（默认 1 秒）
    -> 每 tick 重新构建 [player, all existing NPC] bindings
    -> 按数组顺序给 fighting actor 各一次 opportunity
    -> lifecycle gate / busy / select / fight / attack chain
    -> lifecycle adapter（下一 actor opportunity）
    -> HUD vitality + text log
    -> 关系全部结束时 Timer 停止
```

证据：`game/runtime/world/oldpine_outdoor_controller.gd:878-955,1148-1225`、`game/runtime/combat_slice/combat_slice_opportunity_executor.gd`、`game/scenes/world/oldpine/oldpine_outdoor.tscn:1027-1029,1371`。

`CombatSliceCharacterBinding` 引用 exact `CharacterState`、relationship、busy、armor 和 content，而不复制 authority；`WorldCombatBindingAdapter` 从 Player/NPC runtime 构造 binding，并只在 lifecycle 需要时同步 existence/life status。世界 inventory、equipment、corpse 与 loot 继续使用既有实例。

### 14.3 胜负、死亡、尸体和掉落

`CombatSliceOpportunityExecutor` 在每个 actor opportunity 开始先检查 `CharacterState.life_threshold()`；只有外层 lifecycle adapter 才清关系、设置 UNCONSCIOUS/DEAD、执行 death inventory、分配 corpse item、同步 World runtime 并创建 `CombatSliceCorpseView`。正向攻击与同步 reverse attack 中间不会插入死亡。见 `game/runtime/combat_slice/combat_slice_lifecycle_adapter.gd`、`combat_slice_death_adapter.gd` 和 `oldpine_outdoor_controller.gd:1181-1225`。

尸体随后仍是 `InventoryState` 中的真实 item/container authority，Old Pine loot adapter 通过现有 transfer service 取物。见 `game/runtime/world/oldpine_corpse_loot_adapter.gd`、`oldpine_outdoor_controller.gd:582-686`。

当前 integrated world 没有独立 encounter outcome/summary/return；NPC 死亡后尸体留在同一地图，关系清空后 timer 停止。玩家死亡则通过同一 lifecycle 变成不在 world 的 DEAD runtime，尚不是完整 ES2 ghost journey。

### 14.4 存档与应用生命周期

`OldPineSaveEligibility` 在 combat cadence 运行、任一 opponent/lethal relation、busy、interrupt threshold 或 guarding 存在时拒绝 Save；active combat transient state 因而不进入当前 native save snapshot。Combat RNG 本身会由 world save capture 持久化，但只能在符合 eligibility 的稳定点保存。见 `game/runtime/persistence/oldpine_save_eligibility.gd`、`oldpine_world_save_capture.gd`。

ApplicationShell pause 和移动端 lifecycle gate 通过暂停 SceneTree 冻结当前世界/TImer；恢复需显式 Resume。这是应用生命周期策略，不是 combat rule。Dedicated encounter 需要接入同一 Host/Session 生命周期，而不是自建第二套 pause/save authority。

## 15. Existing Systems That Should Be Preserved

### 可原样保留的 authority / rules

- `CharacterState`、base attributes、gin/kee/sen、internal resources、conditions；
- `CharacterSkillState`、mapping、progression、skill-improvement effects；
- cultivation/practice/self-learning/learn 的现有领域服务；
- `EquipmentState`、`ArmorState`、`InventoryState`、item identity/index；
- `CombatRelationshipState` 与整数 `ActionBusyState`；
- `CombatMath`、action selection、ordinary resolver、standard force policy；
- combat progression、busy interrupt、post-relationship 和 reverse attack ordering；
- death inventory、corpse、loot 和 item lifecycle services；
- session-owned RNG authority及其 save continuation；
- `OldPineBanditAggressionAdapter` 的延迟复核思想。

### 可复用但未来需一般化命名/边界的 runtime

- `CombatSliceCharacterBinding` / `WorldCombatBindingAdapter`：保留 exact authority reference 原则，但命名和字段需适应通用 encounter；
- `CombatSliceProjectionBuilder` / `CombatSliceOpportunityExecutor`：可作为 ES2 semi-auto opportunity policy 的基础，不应直接成为所有交互模型唯一 scheduler；
- `CombatSliceLifecycleAdapter` / `DeathAdapter`：保留严格顺序，改由 encounter orchestration 调用；
- `GodotCombatRandomSource`：继续使用 session-owned stream，不让 battle scene 自行 randomize；
- `CombatSlicePresenter`：可复用结果到 cue 的部分思想，但当前英文 log 和直接 HUD 写入不是最终 presentation contract。

## 16. Systems That Need a New Boundary

以下职责目前集中在 `OldPineOutdoorController`，应从 map controller 移出：

- 把玩家 attack、NPC aggression、未来 scripted/quest/vendetta/sparring 统一成 trigger；
- 选择 encounter participants 与 side；
- 决定何时冻结探索、打开 battle presentation；
- 持有活动 encounter phase 和结束条件；
- 根据最终选择的交互模型安排普通机会与玩家命令；
- 把 typed combat result 转成 presentation cues；
- 结束后恢复同一个 World Session，并应用尸体、loot、位置、仇恨等结果。

Map controller 仍应负责 Area/proximity、物理角色与触发事实；Application Host 仍应是 current Session 唯一 owner；Character/Inventory 等现有对象仍是权威。新增边界不能通过复制 CharacterState 或把战斗状态藏进 battle scene nodes 实现。

## 17. Proposed CombatEncounter Architecture

### 17.1 Typed CombatTrigger

建议 trigger 是不可变 typed value，至少表达：

- stable trigger/correlation ID；
- cause：player attack、NPC aggression、scripted、quest、vendetta、sparring 等封闭原因；
- intent：lethal、nonlethal/sparring；
- initiator CharacterId；
- candidate participant IDs 与初始 side IDs；
- source World location / encounter anchor；
- 可选 authored policy ID，而非 `Callable` 或脚本路径；
- 已验证的触发元数据（例如 aggression、quest encounter ID），不用任意 payload dictionary。

World 只生成 trigger；它不创建 Timer、不结算攻击，也不选择最终战斗 UI。Trigger handler 必须重新验证参与者仍存在、可战斗、位置有效及规则允许，保留 ES2 auto-fight 的二次复核语义。

### 17.2 CombatEncounterState

Encounter 是活动战斗上下文，建议只拥有：

- encounter ID、原始 trigger snapshot、phase；
- `Array[CombatParticipantRef]`，每项含 CharacterId、side ID、role/tags 和 exact authority binding；
- 当前仍在场/可行动/逃离/投降/死亡状态；
- chosen interaction policy ID；
- ordered typed combat events/results；
- completion reason 和最终 `CombatEncounterResult`。

它不复制 CharacterState、Inventory、Equipment、Armor 或 Corpse authority。每个 participant 通过 stable ID 解析并绑定同一个 Session-owned runtime/domain对象。`CombatRelationshipState` 可以继续作为角色本地 transient combat authority；Encounter 负责其参与范围、建立/清理顺序和完整性，不再用 map Timer 是否运行推断“是否有 encounter”。

Participants 必须是集合且 side ID 为开放 stable ID；不要创建 `player`、`enemy` 两个固定字段，也不要假设双方人数相等。Targeting、AoE、guard/riposte 和 outcome 都使用 CharacterId 集合。

### 17.3 CombatEncounterCoordinator

一个 runtime/application orchestration service 负责：

1. 接收并验证 `CombatTrigger`；
2. 从 current World Session 解析 exact character authorities；
3. 选择/确认 participant roster 和 sides；
4. 安全暂停探索输入与 encounter 外 NPC runtime，而不销毁 resident maps；
5. 建立 Encounter 并交给 Battle Presentation；
6. 接收 presentation 的 typed intent，调用选定 flow policy 和现有 Combat Core；
7. 在完整 attack chain 后执行既有 lifecycle/death/corpse；
8. 形成 typed result，关闭 presentation；
9. 把同一个 Session 恢复到有效世界状态。

Coordinator 不是全局 Combat singleton，也不拥有数值公式。其 owner 应与当前 `OldPineGameRuntimeHost` / Session 生命周期协调；具体节点放置留待下一设计阶段。

### 17.4 Flow policy seam

由于交互模型未定，Encounter 不应内建 1 秒 timer 或 round counter。可预留一个 typed `CombatFlowPolicy` 边界：给定 encounter 当前投影与玩家/NPC intent，产生下一批“谁获得什么机会”的请求；每个实际 attack 仍委托现有 resolver/completion chain。

Semi-auto policy 可以复用现有 opportunity executor；ATB policy 可拥有 readiness；turn-based policy 可拥有 turn order。三者都不得重算 AP/DP/damage，也不得直接修改 UI。这个 seam 只是架构位置，不是本阶段要创建的接口。

## 18. Dedicated Battle Presentation Boundary

Battle Presentation 是 SceneTree/UI/animation owner，只做：

- 显示 participant projections、side、target、资源、busy/guard/status；
- 显示当前 policy 允许的 typed actions；
- 收集 mouse/keyboard/controller/touch intent；
- 播放由 structured results 生成的 animation/VFX/audio/log/camera cues；
- 显示 encounter start、victory/defeat/flee/sparring summary；
- 请求 coordinator 完成返回，不直接移动世界角色或生成尸体。

它不得：

- 拥有或复制 HP/skills/equipment authority；
- 通过动画碰撞决定命中；
- 在 animation finished 回调中偷偷推进规则，除非 flow policy 明确把 presentation acknowledgement 当作非数值节奏 gate；
- 直接调用 `receive_damage()`、改关系或构造 corpse；
- 自己创建 gameplay RNG；
- 假设永远只有一个 enemy。

World presentation 在 encounter 期间应被冻结、隐藏或降级显示，但具体是替换场景、overlay 还是 Host 下并列 scene 尚未决定。无论视觉实现如何，current Session 与 resident map authority 必须保持同一实例，以避免 Save/Load、NPC ledger、corpse 和 map handoff 分叉。

## 19. Three Candidate Interaction Models

### Model A — ES2-derived semi-auto combat

基础攻击和源码式自动 guarding 按 encounter cadence 继续发生；玩家手动选择 martial special、force、spells、items、战术防御、目标与 flee，可考虑 queued action、清晰资源成本和 busy/casting 展示。

优点是最接近 ES2 的身份：基础拆招持续、玩家决策集中在特殊能力，现有 `CombatSliceOpportunityExecutor` 复用率最高，busy 与即时反击也最自然。风险是玩家可能觉得“角色自己玩”，且必须解决输入窗口、排队、自动攻击日志噪声和多目标可读性。

### Model B — ATB / semi-real-time command combat

参与者积累 readiness；就绪时自动普通攻击或等待/短暂暂停玩家命令，特殊动作和 busy 消耗/延迟 readiness。

它能把 ES2 的异步 heartbeat 和 busy 转成更可见的现代节奏，适合动画、多角色和技能排队。但 speed/attribute 如何影响条速是新公式，源码没有现成答案；若让玩家等待输入还会改变 ES2 的持续攻防与 quick-on-busy 时序。实现和 balance 成本高于 A。

### Model C — conventional turn-based combat

明确的 player/enemy turns，玩家每回合选择动作，敌人按 policy 行动。

它最容易解释、暂停、触控和做精确策略 UI，也便于多目标选择和 boss telegraph。但普通自动攻击、独立 heartbeat、busy vulnerable window、自动 guard、miss 后即时 riposte、异步 manual command 和多次即时攻击都要重新解释为 turn economy/reaction/status；若处理不慎，ES2 会变成只保留名称与公式的普通回合制 RPG。

### 对比矩阵

| 评价项 | A：ES2 半自动 | B：ATB / 半实时 | C：传统回合制 |
|---|---|---|---|
| ES2 忠实度 | 高；直接保留自动基础攻防 | 中高；保留异步感但重定义 readiness | 中低；时序需大量重释 |
| 易上手 | 中；需解释自动与手动层 | 中；可视条清楚但节奏忙 | 高；一轮一选择最直观 |
| Mobile UX | 中高；少量大按钮 + queue 可行 | 中；时间压力和多目标触控需谨慎 | 高；无时间压力 |
| Desktop UX | 高；快捷键/鼠标都自然 | 高；实时反馈丰富 | 高；传统成熟 |
| 有意义的玩家 agency | 中高；special timing/target/resource | 高；timing + command | 高；每回合显式决策，但普通攻击也占选择 |
| 实现复杂度 | 中；现有 cadence 可复用 | 高；readiness、暂停、queue、AI | 中；turn state/AI 明确 |
| 动画表现 | 高；持续拆招 | 很高；条速与动作演出易结合 | 高；镜头和招式逐段清楚 |
| 大量武学支持 | 高；按 policy 注册 | 高；能力与 readiness 组合 | 高；action catalog 直观 |
| 内功/法术支持 | 高；手动 tactical layer 符合源码 | 高；cast/readiness 可视化 | 高；成本与效果清晰 |
| 多对手 | 高，但 UI/日志易拥挤 | 高，但 gauge 数量复杂 | 高；目标和顺序最清楚 |
| Boss 潜力 | 高；interrupt/guard/timing | 很高；telegraph 与 gauge 丰富 | 高；阶段/机制清楚 |
| Balance 难度 | 中高；自动频率与 special 强度耦合 | 很高；速度是强乘区 | 中；离散 turn 更易估算 |
| 现有 Godot Core 兼容 | 很高；opportunity pipeline 直接适配 | 高；结算可复用，scheduler 新增 | 高；结算可复用，时序重编排 |
| Save/Load | encounter 中仍建议禁存；边界明确 | readiness/queue 增加 transient 状态 | turn/intent 状态最容易序列化，但仍是新范围 |
| App lifecycle | pause/resume cadence 即可 | 必须精确冻结 readiness/time | 最简单；停在 turn boundary |
| 内容扩展 | 高；最贴 legacy actions | 高但每个动作还要节奏 tuning | 高；内容模板成熟，但 legacy 异步特例较多 |

现有证据没有强迫选择唯一模型。A 最忠实且复用当前 opportunity runtime 最多；B 提供最强现代半实时表达但引入最多新节奏规则；C 最易用、尤其适合移动端，但需要最明确的兼容性取舍。

## 20. Migration Risks

1. **复制权威状态**：battle scene 若创建第二份 Character/Equipment/Inventory，将破坏死亡、尸体、成长和存档一致性。
2. **把 presentation 变成规则 owner**：动画时长、hitbox 或 UI cooldown 若决定结果，会违反现有 Core 边界。
3. **RNG 顺序漂移**：换 scheduler 会改变选敌、guard、damage、growth 和 special 的 draw 次序；需为每个 flow policy 明确随机契约。
4. **生命周期顺序回归**：现有 forward/reverse chain 完成后、下一 outer opportunity 才检查阈值；新演出很容易提前死亡并截断合法反击。
5. **多对手被 1v1 原型固化**：固定 player/enemy 字段、单目标 HUD 或二元 result 会阻塞伙伴、召唤和群攻。
6. **关系语义被简化**：当前 playable reciprocal lethal 已比 LPC 更窄；新 trigger 若继续只有 bool `hostile`，会永久丢失 fight、不对称 kill、vendetta。
7. **busy 单位偷换**：heartbeat count、ATB seconds、turn skip 和 animation lock 不是同一概念。
8. **特殊技能被过度统一**：多击、delayed modifier、direct wound、AoE、escape、control 不能安全塞入一个 generic damage DTO。
9. **World/Session 分叉**：切 battle scene 若销毁 resident map、重建 NPC 或改变 Host ownership，会破坏 Phase 10B/10C 已关闭的 save/load 与 lifecycle invariants。
10. **存档边界扩大**：当前 active combat 明确不可保存；若未来允许 encounter save，需要另行版本化 participant/flow/RNG/transient state，不能顺手扩展现有 snapshot。
11. **源码缺陷误当设计要求**：`wimpy` 字段不一致、armed friendly wound、`biwu` 同步循环都需要显式 compatibility decision。
12. **旧 slice 名称/职责泄漏**：`CombatSlice*` 是阶段性桥接，未来应渐进包裹/一般化，不能大爆炸重写已验证 Core。

## 21. Open Design Decisions

- 首个 dedicated battle prototype 采用 A、B、C，还是只做 A/B 两个可比较的交互原型？
- 普通攻击在 A/B 中无条件自动，还是允许玩家将它设为默认/hold？
- Busy 在各模型中的单位是什么，如何显示，命中中断后何时恢复？
- Guard 保持源码自动行为，还是另加“主动防御”；两者如何区分？
- 哪些特殊动作进入第一批：一个 martial、一个 exert、一个 spell，还是先只证明 typed intent seam？
- 战斗触发时如何确定 participant roster、side、附近援军和迟到增援？
- NPC-NPC、伙伴、召唤物是否在第一 encounter API 即可表达但暂不展示？
- 非致死 sparring 的结束条件采用 `fight.c` 首次正 damage，还是另行 RPG 规则？如何处理源码“武器仍 wound”的矛盾？
- 玩家受到单方面 kill 时，能否选择 flee/surrender/fight back；何时升级为 reciprocal lethal？
- Flee 成功率、行动成本、返回 world 的位置和追击/vendetta 如何定义？
- 战斗中是否允许换装、使用 inventory、改变 skill mapping；这些动作是否消耗 opportunity？
- Encounter 期间 world 是隐藏、冻结 overlay，还是由 Host 切换 presentation slot？
- 胜利后 loot 在 battle summary 处理，还是返回 world 后从实体 corpse 处理？现有 authority 倾向后者，但产品体验未定。
- 玩家昏迷/死亡后的 defeat、ghost 或恢复流程是什么？
- Active encounter 是否继续禁止 Save；若允许，在哪个稳定 boundary 保存？
- Conditions/recovery 是否按独立 world time、encounter opportunity 或完全冻结推进？
- Battle animation 是否可以等待用户 acknowledgement，但永远不改变已提交规则顺序？

## 22. Recommended Next Design Questions

下一步仍应是设计验证，不是全面实现：

1. 用同一场 1v2 示例画出 A、B、C 的 20 秒/三轮纸面时间线，逐项放入 ordinary attack、guard、busy、perform、flee 和 lifecycle；
2. 明确玩家每 5 秒实际需要做几次决定，以及 mobile 上同时显示多少 action/target 才可读；
3. 选择一个现有 ordinary attack + 一个已核实 martial special，验证 typed intent 到现有 Core 的最小缺口；
4. 先定 trigger/encounter/result ownership，再决定 battle scene 是替换还是 overlay；
5. 为 1vN、unilateral lethal、sparring、flee 各写一条无 UI acceptance scenario；
6. 明确 Phase 10B Save 与 Phase 10C lifecycle 在 encounter ACTIVE、presentation suspended、result applying 三个阶段的允许矩阵；
7. 用户审阅三种模型后再选择交互方向，并为选择记录新的 phase scope 与 compatibility decisions。

## 23. Inspected Sources

### LPC：核心精读

- `reference/es2/mudlib/feature/attack.c`
- `reference/es2/mudlib/std/char.c`
- `reference/es2/mudlib/adm/daemons/combatd.c`
- `reference/es2/mudlib/feature/action.c`
- `reference/es2/mudlib/feature/damage.c`
- `reference/es2/mudlib/feature/command.c`
- `reference/es2/mudlib/feature/equip.c`
- `reference/es2/mudlib/std/char/npc.c`
- `reference/es2/mudlib/std/skill.c`
- `reference/es2/mudlib/std/sserver.c`
- `reference/es2/mudlib/adm/daemons/weapond.c`
- `reference/es2/mudlib/include/combat.h`
- `reference/es2/mudlib/include/action.h`
- `reference/es2/mudlib/include/skill.h`
- `reference/es2/mudlib/include/globals.h`

### LPC：命令与代表性 authored behavior

- `reference/es2/mudlib/cmds/std/kill.c`
- `reference/es2/mudlib/cmds/std/fight.c`
- `reference/es2/mudlib/cmds/std/biwu.c`
- `reference/es2/mudlib/cmds/std/perform.c`
- `reference/es2/mudlib/cmds/std/exert.c`
- `reference/es2/mudlib/cmds/std/cast.c`
- `reference/es2/mudlib/cmds/std/go.c`
- `reference/es2/mudlib/cmds/usr/wimpy.c`
- `reference/es2/mudlib/cmds/std/wield.c`
- `reference/es2/mudlib/cmds/std/unwield.c`
- `reference/es2/mudlib/cmds/std/wear.c`
- `reference/es2/mudlib/cmds/std/remove.c`
- `reference/es2/mudlib/cmds/std/enable.c`
- `reference/es2/mudlib/daemon/skill/force.c`
- `reference/es2/mudlib/daemon/skill/fonxansword.c`
- `reference/es2/mudlib/daemon/skill/iceforce.c`
- `reference/es2/mudlib/daemon/skill/celestial.c`
- `reference/es2/mudlib/daemon/skill/magic-array.c`
- `reference/es2/mudlib/daemon/skill/necromancy.c`
- `reference/es2/mudlib/daemon/class/swordsman/fonxansword/fakefault.c`
- `reference/es2/mudlib/daemon/class/swordsman/fonxansword/counterattack.c`
- `reference/es2/mudlib/daemon/class/swordsman/fonxansword/swordjab.c`
- `reference/es2/mudlib/daemon/class/fighter/celestial/roar.c`
- `reference/es2/mudlib/daemon/class/fighter/celestial/powerup.c`
- `reference/es2/mudlib/daemon/class/taoist/necromancy/feeblebolt.c`
- `reference/es2/mudlib/daemon/class/juechen/magic-array/dun.c`
- `reference/es2/mudlib/daemon/class/bonze/lotusforce/heal.c`
- `reference/es2/mudlib/d/oldpine/npc/` 中 aggression/bellicosity authored facts（结构搜索）

### Godot：Core 与 runtime

- `game/core/characters/character_state.gd`
- `game/core/combat/` 下 action、busy、math、resolution、force、completion、execution、fight、relationship 实现
- `game/core/skills/character_skill_state.gd`
- `game/core/cultivation/cultivation_service.gd`
- `game/core/training/practice_service.gd`
- `game/core/training/self_learning_service.gd`
- `game/runtime/combat_slice/` 下 binding、projection、opportunity、lifecycle、death、presenter、HUD、RNG 和 vertical slice controller
- `game/runtime/characters/world_player_runtime_state.gd`
- `game/runtime/characters/world_combat_binding_adapter.gd`
- `game/runtime/world/oldpine_outdoor_controller.gd`
- `game/runtime/world/oldpine_bandit_aggression_adapter.gd`
- `game/runtime/world/oldpine_aggression_decision.gd`
- `game/runtime/world/world_character_body_2d.gd`
- `game/runtime/world/oldpine_outdoor_hud.gd`
- `game/runtime/world/oldpine_equipment_interaction_adapter.gd`
- `game/runtime/world/oldpine_armor_interaction_adapter.gd`
- `game/runtime/world/oldpine_corpse_loot_adapter.gd`
- `game/runtime/world/oldpine_world_session_controller.gd`
- `game/runtime/persistence/oldpine_save_eligibility.gd`
- `game/runtime/persistence/oldpine_world_save_capture.gd`
- `game/runtime/persistence/oldpine_session_load_coordinator.gd`
- `game/runtime/application/application_shell_controller.gd`
- `game/scenes/world/oldpine/oldpine_outdoor.tscn`
- `game/scenes/combat/combat_vertical_slice.tscn`

### Godot：历史设计/验证文档

- `docs/migration/PHASE_5A_COMBAT_DEPENDENCY_ANALYSIS.md`
- `docs/migration/PHASE_5B1_COMBAT_STATE_MATH_ACTION_FOUNDATION.md`
- `docs/migration/PHASE_5B2A_ORDINARY_ATTACK_CORE_RESOLUTION.md`
- `docs/migration/PHASE_5B2B1_STANDARD_FORCE_HIT_POLICY.md`
- `docs/migration/PHASE_5B2B2_COMBAT_PROGRESSION_BUSY_COMPLETION.md`
- `docs/migration/PHASE_5B3A_RELATIONSHIP_OPPONENT_FRIENDLY_STOP.md`
- `docs/migration/PHASE_5B3B1_FIGHT_DECISION_GUARD.md`
- `docs/migration/PHASE_5B3B2A_SINGLE_ATTACK_POST_ACTION_RIPOSTE_DECISION.md`
- `docs/migration/PHASE_5B3B2B_SYNCHRONOUS_REVERSE_ATTACK_EXECUTION.md`
- `docs/migration/PHASE_6A_FIRST_PLAYABLE_COMBAT_VERTICAL_SLICE_ANALYSIS.md`
- `docs/migration/PHASE_6B1_RUNTIME_COMBAT_OPPORTUNITY_BRIDGE.md`
- `docs/migration/PHASE_6B2_PLAYABLE_COMBAT_ARENA.md`
- `docs/migration/PHASE_6B3_OUTER_LIFECYCLE_DEATH_CORPSE.md`
- `docs/production/STATUS.md`
- `docs/production/ROADMAP.md`

## 24. Analysis Boundary

本文件没有选择 A/B/C，没有创建 `CombatTrigger`、`CombatEncounter`、flow policy、battle scene 或 UI，没有修改 combat balance、Tall Bandit/NPC 数值、现有 tests、Save contract 或 `reference/es2`。所有“建议”均为未来实现边界；所有“源码行为”均来自本节列出的实际文件。
