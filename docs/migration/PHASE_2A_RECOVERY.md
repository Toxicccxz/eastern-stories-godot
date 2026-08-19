# Phase 2A：角色恢复与内部资源

## 范围与实现

本阶段只增加纯领域状态和一次确定性恢复 tick：`force/max_force`、`mana/max_mana`、`atman/max_atman`、`food`、`water`，以及原版 `heal_up()` 的恢复顺序、玩家食水门槛和最小 no-heal 输入。代码均为 typed GDScript / `RefCounted`，不依赖 `Node`、场景或运行时计时器。

## 检查过的 LPC 来源

- `reference/es2/mudlib/feature/damage.c`：容量、`heal_up()` 的全部公式和顺序。
- `reference/es2/mudlib/feature/skill.c`、`reference/es2/mudlib/include/skill.h`：`query_skill(id, 1)` 是原始技能等级；缺失时为 `0`。
- `reference/es2/mudlib/std/char.c`：死亡/昏迷先于恢复、busy 提前返回、condition no-heal 短路、恢复调度。
- `reference/es2/mudlib/include/condition.h`、`reference/es2/mudlib/feature/condition.c`：`CND_NO_HEAL_UP` 的来源。
- `reference/es2/mudlib/adm/daemons/chard.c`、`reference/es2/mudlib/adm/daemons/race/human.c`：角色组成，以及内部资源上限对人类 `max_gin/max_kee/max_sen` 的既有影响。
- `reference/es2/mudlib/adm/daemons/logind.c`：新玩家的 food/water 初始化为容量。
- `reference/es2/mudlib/cmds/std/exercise.c`、`meditate.c`、`respirate.c`、`enable.c`：内部资源训练、超上限状态与技能映射关联。
- `reference/es2/mudlib/feature/food.c`、`feature/liquid.c`：进食/饮水的容量检查和可超容量行为。

## 字段映射

| LPC 字段 | Godot 字段 | 语义 |
|---|---|---|
| `force` / `max_force` | `recovery.inner_force.current` / `.maximum` | 内力；没有 effective 层 |
| `mana` / `max_mana` | `recovery.mana.current` / `.maximum` | 法力；没有 effective 层 |
| `atman` / `max_atman` | `recovery.atman.current` / `.maximum` | 灵力；没有 effective 层 |
| `food` | `recovery.food` | 当前饱食值 |
| `water` | `recovery.water` | 当前饮水值 |
| `query_skill("magic", 1)` | `RecoverySkillLevels.raw_magic` | 被动 atman 恢复输入 |
| `query_skill("force", 1)` | `RecoverySkillLevels.raw_force` | 被动 force 恢复输入 |
| `query_skill("spells", 1)` | `RecoverySkillLevels.raw_spells` | 被动 mana 恢复输入 |
| `CND_NO_HEAL_UP` | `apply_tick(..., recovery_blocked)` | 暂时的已判定恢复阻断；不是 condition 系统 |

内部资源的 `current` 不强制夹到 `[0, maximum]`：原版训练允许它严格超过 `maximum`，其他 LPC 调用也直接增减这些映射值。被动恢复只在 `maximum != 0 && current < maximum` 时发生；已经超上限的值不会被被动恢复拉回。

## 已实现公式

所有除法均保留 LPC 整数除法。

- `max_food_capacity = body_weight / 200`
- `max_water_capacity = body_weight / 200`
- `gin_gain = con / 3 + current_atman / 10`
- `kee_gain = con / 3 + current_force / 10`
- `sen_gain = con / 3 + current_mana / 10`
- `atman_gain = raw_magic / 2`
- `force_gain = raw_force / 2`
- `mana_gain = raw_spells / 2`

这里的 `con` 是基础 `con`，不是包含 modifier 的有效属性；内部资源贡献也使用该 tick 被动恢复之前的 current 值。gin/kee/sen 先恢复 current 到旧 effective；若达到旧 effective 且 effective 仍低于 maximum，则 effective 只增加 `1`，current 不随新 effective 一起增加。

## 单次恢复 tick

1. 若角色已死亡、昏迷或收到 no-heal 阻断，整个 tick 返回，食水也不消耗。
2. water 大于 `0` 时减 `1`，然后 food 大于 `0` 时减 `1`。
3. 玩家扣减后的 water 小于 `1` 时立即退出；NPC 不受此门槛影响。
4. 依次恢复 gin、kee、sen。
5. 玩家扣减后的 food 小于 `1` 时退出；NPC不受此门槛影响。
6. 依次按 raw `magic`、`force`、`spells` 恢复 atman、force、mana，并夹到各自 maximum。

返回值保留原 `update_flag` 计数语义，供未来调度层判断是否仍有恢复活动。原版内部资源分支即使 `raw_skill / 2 == 0`、数值没有变化，也会令 flag 增加；本阶段有意保留此行为。food/water 状态不在赋值时夹到容量，因为原版只在开始进食/饮水前检查容量，一次固定 supply 可以让结果越过容量。

## 临时边界与延期项

- `RecoverySkillLevels` 只携带三个 raw 等级快照，明确不包含 mapped skill、临时 apply 或有效技能值；完整 `SkillSystem` 延后。
- `recovery_blocked` 只接收 condition 层已经作出的 no-heal 判断；condition 存储、持续时间和 `update_condition()` 延至 Phase 2B。
- `std/char.c` 的 `tick = 5 + random(10)`、heartbeat 开关、busy/action 调度、NPC chat、战斗与在线状态属于未来运行时系统；本阶段只执行一次已经到期且可恢复的确定性 tick。busy 时调用方不应触发本服务。
- `exercise`、`meditate`、`respirate` 的主动训练、70% 门槛、消耗、技能瓶颈以及 `current > maximum * 2` 时提升上限的规则均未实现。
- `enable.c` 更换映射技能时清零对应内部资源的行为等待 SkillSystem。
- 食物/饮料物品、饮酒 condition 和摄取动作没有迁移。
- 人类资源上限会读取 `max_atman/max_force/max_mana` 的既有 Phase 1 公式；本阶段没有新增或重算种族派生公式。

## 已知旧实现特性

- no-heal 是短路而非“恢复量为零”，所以连 food/water 都不扣。
- 玩家最后一单位 water 会被扣掉后阻止本次三项生命资源恢复；最后一单位 food 会被扣掉后仍允许本次 gin/kee/sen 恢复，但阻止内部资源恢复。
- 内部资源 raw skill 为 `0` 或 `1` 时可能没有数值变化，`update_flag` 仍报告更新；这是可能导致额外 heartbeat 的旧行为，未静默修复。
