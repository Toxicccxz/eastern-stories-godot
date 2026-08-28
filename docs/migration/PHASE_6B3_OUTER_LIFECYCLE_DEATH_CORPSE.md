# Phase 6B3 — Outer Lifecycle / Death / Corpse

## 范围与权威来源

本阶段关闭 Phase 6B1 留下的 `LIFECYCLE_REQUIRED_UNCONSCIOUS` / `LIFECYCLE_REQUIRED_DEATH` 外层执行缺口，并把已关闭的 Phase 4B5C 死亡库存与尸体规则接到第一个可玩竞技场。没有加入 Phase 5B4 authored combat policy、通用 World/NPC、复活、鬼魂/死亡房、尸体腐烂调度、奖励或战利品 UI。

直接复核的 LPC：

- `reference/es2/mudlib/std/char.c`：每次 actor 外层 heartbeat 的死亡优先级、昏迷/死亡阈值检查、先 `remove_all_enemy()` 再进入 lifecycle；
- `reference/es2/mudlib/feature/damage.c`：`unconcious()` 的脱战、三项 current 归零与延迟复活；`die()` 的 condition/announce/reward、尸体创建后二次 `move(environment())`、致命关系清理及玩家 ghost/NPC destruct 分支；
- `reference/es2/mudlib/feature/attack.c`：`remove_enemy()` 的 lethal 拒绝、`remove_all_enemy()` 的 reciprocal request 与本地清空、`remove_all_killer()`；
- `reference/es2/mudlib/adm/daemons/chard.c`：正常尸体创建/初次放置、direct inventory 快照、`owner_is_killed`、逆序转移、worn 重穿；
- `reference/es2/mudlib/obj/corpse.c`：尸体容器、阶段状态、初始 120 秒 decay intent 与最终内容释放。

复用且未重写的 native authority：`CharacterState`、`CombatRelationshipState`、`EquipmentState`、`ArmorState`、`InventoryState`、`InventoryTransferService`、`CombinedStackCollection`、`DeathInventoryService`、`CorpseState`。

## 外层执行顺序

`CombatVerticalSliceController` 仍按 `[player, enemy]` 给每个 eligible actor 一次机会。B1 返回 lifecycle request 时，controller 不再暂停等待未来系统，而是立即调用纯 `CombatSliceLifecycleAdapter`：

```text
B1 already-decided lifecycle kind
→ snapshot victim ordered opponents
→ each resolved opponent.remove_opponent(victim)
→ victim.clear_opponents_preserving_lethal_targets()
→ unconscious status/resource transition (`disable_player` equivalent first)
  OR DeathInventoryService + corpse second placement
→ only after both death-inventory completion and second-placement success:
  death-only explicit lethal cleanup on both participants
→ only after final cleanup success: DEAD / exists=false commit
→ typed lifecycle result
→ body/HUD/corpse presentation refresh
→ continue later participant in the same cadence tick when complete
```

adapter 不重算阈值；effective 任一项 `< 0` 与“已经 UNCONSCIOUS 后 current 任一项 `< 0`”的优先级继续由已关闭的 B1 决定。lifecycle 不消费 RNG。

## Relationship transition

`CombatRelationshipState.clear_opponents_preserving_lethal_targets()` 是唯一新增 Core seam。它只清本地 ordered opponent list，不做 reciprocal mutation，并保留 lethal targets、guarding 和 last opponent。

每个 reciprocal `remove_opponent(victim)` 仍走既有规则：ordinary opponent 可移除；有 lethal marker 的一方会拒绝。这解释了昏迷后 victim 本地不再 fighting，而 lethal attacker 仍能在之后对 nonliving victim 发起 QUICK attack。死亡库存处理之后，当前 slice 的显式 participants 双向移除 lethal/opponent 关系。

LPC 在 `std/char.c` 外层先清一次，`unconcious()` 内又清一次。第一次调用结束后 victim 的 enemy 数组已经为空，因此第二次调用循环次数为零，只会再次赋空数组；native adapter 把这个可证明的幂等空列表调用折叠为无可观察 gameplay 差异的单一 typed transition。测试还对空列表重复调用 narrow seam，确认 opponent 仍为空且 lethal intent 不变；未建立 callback/heartbeat 仿真。

## Unconscious

确认的 native transition：

- narrow `UNCONSCIOUS` status 先提交，映射 `damage.c::unconcious()` 中先于资源赋值的 `disable_player()`；
- gin/kee/sen 对应的 `essence.current`、`vitality.current`、`spirit.current` 随后精确设为 `0`；
- effective 与 maximum 不变；
- binding status 变为 `UNCONSCIOUS`，`exists_in_encounter` 保持 true；
- `CombatSliceCharacterBody` 每次读取 live binding：玩家移动停止，body 仍显示，但不能被选为新的 Attack 目标；
- 不启动复活 Timer，不实现 `random(100-con)+30`，也不模拟 MUD heartbeat；
- lifecycle 完成后同一 cadence tick 继续后续 participant。

## Death / inventory / corpse

`CombatSliceDeathAdapter` 为当前 slice 构造真实 `DeathContext`：normal non-ghost/non-wizard victim、arena `WORLD` endpoint、live Equipment/Armor owner、age 20、body own weight 60000、maximum encumbrance 100000、无 sword-soul alias。每次死亡使用 encounter instance scope + 单调序号组成新的 `combat-slice-encounter-<instance>-corpse-<N>` instance ID，避免同一运行进程内 player/enemy 尸体以及 Reset/reload 后的新 encounter 发生碰撞；没有引入全局 ID 管理器或 RNG。稳定尸体 definition ID 为 `es2:obj/corpse`，legacy metadata 为 `obj/corpse.c`。

当前 slice 的 direct inventory 只包含已验证的 long sword，因此 factory 只为精确匹配该 participant 稳定 sword instance ID 的实例建立 `DeathItemFacts`；这不是 ItemCatalog，也不会把未知 direct item 猜成长剑。未知项会保留为 Phase 4B5C 的 `INVALID_ITEM_FACTS` / blocked incomplete。policy/rewear registries 为空，普通 KEEP 与 generic behavior 由 Phase 4B5C 负责。正常结果是 long sword 通过既有 transfer authority 自动 unwield，并成为 corpse direct content。

`chard.c::make_corpse()` 已完成第一次 corpse placement；随后 `damage.c::die()` 再调用一次 `corpse->move(environment())`。native 明确再次调用 `InventoryTransferService`。在本竞技场中目标 endpoint 相同，因此结果是成功的 `ALREADY_AT_DESTINATION`、`containment_changed == false`，而不是把两步伪装成一个原子事务。

只有 death inventory 为 `COMPLETED`、第二次 corpse placement `succeeded` 且最终 relationship cleanup 成功后，binding 才变为 `DEAD`、`exists_in_encounter=false`。只有这个 `DEATH_COMPLETE` 提交会令 body 隐藏、不可拾取并停止物理移动。权威 `CorpseState`、Inventory 与初始 decay intent 由 controller 保留。`CombatSliceCorpseView` 仅保存 corpse ID/受害者名称标量并绘制地面尸体提示，不拥有库存或 decay authority。

NPC 死亡和玩家死亡均走 normal corpse/inventory/relationship path。玩家随后进入本 prototype 的 terminal defeat，必须按 Reset 创建全新 encounter；本阶段明确不实现 legacy ghost、death room 或自动复活。

## Typed result 与失败语义

`CombatSliceLifecycleResult` 记录 requested kind、victim ID、旧/新 status、reciprocal cleanup 次数、本地清理、资源转移、partial stage、DeathInventoryResult、尸体 ID 与第二次 placement result。outcome 为：

- `UNCONSCIOUS_COMPLETE`；
- `DEATH_COMPLETE`；
- `DEATH_INVENTORY_BLOCKED`；
- `DEATH_INVENTORY_FAILED`；
- `RELATIONSHIP_CLEANUP_FAILED`；
- `INVALID_CONTEXT` / `INCOHERENT_INPUT`。

死亡库存 blocked/failed 不回滚已经发生的前置关系、尸体、equipment 或 inventory mutation。它也不会提前执行 source-positioned final lethal cleanup、不会写入 `DEAD`，也不会把 `exists_in_encounter` 改为 false。controller 停止 cadence 并设置 encounter-local failure gate；下一 tick 不会从头重跑死亡。若不完整结果已经包含真实 corpse，controller 仍显示并保留该 authority，以反映实际 partial mutation；角色 body 仍按未提交的 live status 保持可见。

正式审计还覆盖了第二次 corpse placement 的真实失败路径：受限 arena 使 `chard.c` 对应的库存/尸体部分变更已经完成，但 `damage.c` 对应的第二次 move 返回 `CAPACITY_EXCEEDED`。结果停留在 `DEATH_INVENTORY` stage，保留 corpse 内的 sword、victim 的原 status/availability 和尚未最终清除的 lethal 关系，并由 failure gate 防止重启。这避免把“已有部分变更”误报成 terminal death。

## Runtime / presentation 边界

- lifecycle/death adapters 是 `RefCounted`，无 Node、Timer、SceneTree、signal 或 RNG；
- controller 是 encounter composition root，拥有 cadence、authorities、corpse collection、decay intents 和 view 创建；
- body/HUD/presenter 只读取 live binding/typed result；
- `OpportunityTimer` 只决定下一次 opportunity 何时发生，不进入 lifecycle 规则；
- `CorpseDecayScheduleIntent` 仅被保留，没有 Timer/调度执行。

## 测试覆盖

定向测试从 LPC 常量与顺序独立断言：ordinary reciprocal removal、lethal refusal、清本地列表但保留 lethal/guard/last、折叠的第二次空列表清理为幂等 no-op；昏迷三 current 精确归零且 effective/maximum 不变；同 tick 后续 actor 与明确的 QUICK decision/attack type；昏迷玩家不可移动；enemy 在 player turn 越阈值后同 tick lifecycle；effective death；已昏迷后的 current death；从普通攻击到 unconscious、后续 QUICK、effective death、own opportunity、corpse 的完整 enemy kill path；对应的完整 player-loss path；NPC/player normal corpse；sword unwield/转入 corpse；二次 corpse move 同 endpoint no-op 以及明确失败；双方 lethal cleanup；terminal defeat；尸体注册 failure 与尸体已创建后的 item-facts blocked 都不重试且保留各自 partial state/status/body/relationships；一个死亡一个 view；reset 清空 authority/view/intents并产生不碰撞的新 corpse identity；fresh participant condition collection 为空；lifecycle 不消费 RNG。

Phase 6B3 + 6B2 + 6B1 + 4B5C + 4B5B + 4B2 + 5B3A/B1/B2A/B2B 定向回归：2112 assertions PASS。

完整项目回归：5953 assertions PASS。Godot 4.7.2 headless editor、项目主场景及显式 `combat_vertical_slice.tscn` 加载均成功；MCP 重载并保存持久化 scene 后启动项目，实际 `Eastern-Stories-Godot (DEBUG)` 窗口确认 arena、两名角色、HUD、Attack/Reset 正常可见。MCP game helper 未在等待窗口内回连，但 editor/game logs 无项目错误，实际窗口和三个 headless 0-exit 检查提供了独立运行证据。

## 正式审计修正

- 修正 death inventory blocked/rejected、第二次 corpse placement 失败时仍提前清除 lethal 关系并提交 `DEAD` / `exists=false` 的错误；terminal state/body 隐藏现在只发生于完整成功链末端。
- 为 source-positioned 第二次 corpse move 增加显式 success gate，并保留其失败前已经发生的 corpse/inventory/equipment 部分变更。
- corpse instance ID 增加 encounter instance scope，避免 Reset/reload 后序号重新从 1 开始造成碰撞。
- 补强 QUICK decision/type、折叠第二次 `remove_all_enemy()` 的幂等性、fresh condition 空集合、失败 body/status/relationship、完整胜负闭环及 reset 后 corpse identity 证据。

## 明确延期

- `unconcious()` winner reward、`die()` killer reward/announce/team/condition clearing：需要未来奖励、presentation、team 与 condition lifecycle integration；当前 slice 没有这些 authored state；
- `revive()`、随机昏迷时间、ghost/death-room/reincarnation：runtime/product lifecycle 后续阶段；
- corpse decay intent 的 Timer 执行、最终散落、animate/zombie：runtime/NPC/world 后续阶段；
- loot interaction/UI、一般 ItemCatalog、任意 authored death policies；
- Phase 5B4 authored combat hooks 与一般 World/NPC systems。

Phase 6B3 只关闭第一个可玩战斗 slice 内“机会请求 → 昏迷/死亡 → death inventory/corpse → presentation”的最小闭环，不宣称完整 ES2 death lifecycle 已完成。
