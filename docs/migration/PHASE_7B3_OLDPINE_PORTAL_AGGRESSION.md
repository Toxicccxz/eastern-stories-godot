# Phase 7B3：老松树传送与狭窄主动攻击

状态：**FORMALLY CLOSED**

## 范围与结论

本阶段只完成两个 map-local runtime 接线：

1. 玩家选择并检查林间空地的古松，执行 `Climb` 后落到同一 Old Pine Outdoor map 中持久化的 `TreeCanopyZone / Tree1Landing`；树上可通过来源明确的 `down` 返回空地。
2. 三名 `spath1` 土匪探哨各自用持久化、可重叠的 `Area2D` 表达 RPG 的玩家在场；进入只排入下一次 process opportunity，重查仍然有效后才复用既有致命战斗启动路径。

没有加入通用 NPC AI、追逐、寻路、仇恨/复仇、重生、ROOM reset、心跳模拟器或 Phase 5B4 authored combat hooks。

## 权威 LPC 来源

- `reference/es2/mudlib/d/oldpine/clearing.c`
  - `climb pine` 精确移动到 `tree1`；古松 `item_desc` 是 inspect 文本来源。
- `reference/es2/mudlib/d/oldpine/tree1.c`
  - `down -> clearing` 是返回边；`long` 是树上 landmark inspect 文本来源。
- `reference/es2/mudlib/d/oldpine/npc/bandit.c`
  - `attitude = aggressive`，对应已存在的 `aggressive_on_player_presence` capability。
- `reference/es2/mudlib/feature/attack.c`
  - `init()` 的初次 living、同环境、已在战斗和 aggressive 检查。
- `reference/es2/mudlib/adm/daemons/combatd.c`
  - `auto_fight()` 的 `looking_for_trouble` 去重、零延迟 `call_out` 逃离窗口；`start_aggressive()` 的再次存在/存活/同环境/未战斗/非 `no_fight` 检查；最终调用 `kill_ob(player)`。
- `reference/es2/mudlib/feature/move.c`
  - `move()` 不因正在战斗而拒绝角色移动。
- `reference/es2/mudlib/std/room.c`
  - 通用 `valid_leave()` 没有战斗禁行；当前三个相关房间没有 authored `no_fight`。

## Typed interaction 与 authored landmarks

`WorldInteractionTarget` 是最小 closed target identity：

- `CHARACTER + CharacterId`
- `LANDMARK + landmark_id`

它不保存 `Node`、`Vector2`、`Callable` 或 dictionary context。`WorldLandmarkDefinition` 保存 authored name、description、portal ID、action label 与 legacy source path。当前两个定义由 `OldPineLandmarkDefinitions` 显式提供：

- `oldpine.outdoor.landmark.ancient_pine`
- `oldpine.outdoor.landmark.tree1_descent`

HUD/controller 不内嵌古松描述。`WorldLandmarkArea2D` 只把实际点击转换为稳定 landmark ID；它不执行 portal 或游戏规则。

## Portal 数据与执行顺序

已有正向 portal 保持唯一稳定 ID：

```text
oldpine.outdoor.climb_pine
central_clearing -> tree_canopy / tree1_landing
```

本阶段增加来源明确的返回 portal：

```text
oldpine.outdoor.descend_tree1
tree_canopy -> central_clearing / pine_landing
legacy action: down
```

`OldPinePortalTraversalAdapter` 的单次确定性顺序是：

1. 验证 player runtime/body/portal；
2. 验证玩家仍存在且为 `ACTIVE`；
3. 验证当前 map + source zone；
4. 拒绝未实现的 `policy_id`；
5. 以 `destination_spawn_point_id` 验证 exact `WorldSpawnMarker2D`；
6. 验证 typed destination `WorldLocationState`；
7. 先更新 `CharacterBody2D.global_position`；
8. 再提交 player logical location；
9. 返回 `WorldPortalTraversalResult`。

正式审计将第 6 步收紧为 Old Pine region、目标 map/zone 与该 authored zone 的 `combat_location_id` 必须同时一致；错误 region 或 combat-location 与 missing/wrong marker 一样，在任何物理/逻辑 mutation 前返回 typed failure。标准 `WorldPlayerRuntimeState.set_world_location()` 对已验证的位置必然成功；结果仍保留 `LOGICAL_LOCATION_UPDATE_FAILED` 与物理/逻辑两项提交标记，以诚实表示未来替代 runtime 拒绝逻辑提交时已经发生的物理 partial commit。

结果只保存 portal ID、前后 logical location snapshot 及两项提交标记；没有 `Node`/`Vector2` 泄漏。传送不读取或修改 `CharacterState`，也不消费 RNG。

### 战斗中攀爬规则

原作 `clearing.c::do_climb()` 不检查 `is_fighting()`/busy，直接调用角色 `move(tree1)`；`feature/move.c::move()` 和当前房间 `valid_leave()` 也没有战斗禁行。因此 native 实现允许战斗中攀爬，不新增产品规则。转移后双方关系不会被 portal 立即强制删除；下一次既有 combat opportunity 通过 same-location availability 清理普通 opponent membership，保持与原作延迟到后续战斗清理相同的语义。

## 主动攻击接线

`OldPineBanditAggressionAdapter` 仅拥有 map-instance-local 的两组 typed ID：当前在场 NPC 与待决 NPC。Area enter 当下验证：

- NPC 具有 `aggressive_on_player_presence` capability；
- player/NPC runtime 有效、存在、`ACTIVE`、`combat_available`；
- NPC 尚未在战斗；
- 双方共享 `combat_location_id`；
- 当前位置允许战斗。

通过后只记为 pending；不修改关系、不启动 Timer、不消费 RNG。下一次 controller `_process()` 按 `_all_npcs` 的 spawn insertion order 再次执行相同检查。只有 `READY` decision 才调用：

```text
CombatSliceOpportunityExecutor.initiate_lethal_combat(npc, player)
```

这是 Phase 6B/5B 已关闭的致命关系入口；controller 不手工添加 opponent/lethal marker。成功后仅在现有 `OpportunityTimer` 已停止时启动它。多个重叠土匪分别排队、每 NPC 去重，并按 spawn 顺序启动；target 始终是 player。退出 Presence 会取消未执行 pending，但不会清理已经建立的战斗关系。

`Area2D` 半径是 native RPG 的“近距离在场”适配，不声称还原 LPC 整个 ROOM 的无限范围。hatred、vendetta、berserk、pursuer、wander/chase/return-home 均未迁移。

正式审计明确锁定 Godot timing：`body_entered` 同步调用只建立 map-local pending；controller 不在该回调内 drain。后续 `_process()` opportunity 才重读当前 authority。真实物理测试在暂停 controller process 时把 `CharacterBody2D` 移入 Presence，确认 pending/零关系，再在 process opportunity 前移出实际 Area，确认 pending 被 `body_exited` 取消、Timer/RNG/关系均不变。

## 场景内容

`oldpine_outdoor.tscn` 新增并持久化：

- `TreeCanopyPlatform`、tree trunk/path visual、标签；
- `TreeCanopyBounds` 四边 collision；
- `TreeCanopyZone` 与 logical-location signal；
- `Tree1Landing` 与 `ClearingPineLanding` exact marker；
- Pine/Tree1 descent 两个 typed landmark `Area2D`；
- 三个 bandit child `AggressionPresence` Area（半径 120，可重叠）；
- HUD `PortalButton`；
- Camera2D 右边界扩展到 2300。

场景仍是同一张 Outdoor map；没有一 LPC room 一 scene，也没有 `NavigationAgent2D`。

## 验证覆盖

`oldpine_portal_aggression_test.gd` 覆盖：

- authored landmark/portal/legacy metadata；
- CHARACTER/LANDMARK typed target 与 Node-free result；
- 实际 Area picking、HUD Inspect/Climb、Attack 对 landmark 禁用；
- Bandit → Pine → Bandit 切换、错误 source 时 Traverse disabled、死亡 target 的 stale Attack 拒绝；
- source map+zone、exact marker、destination region/map/zone/combat-location、正向攀爬与返回；
- validate-before-mutate、missing/wrong marker 零 mutation、逻辑提交拒绝时诚实 partial physical commit；
- 物理位置与 logical snapshot 防御复制、完整 CharacterState/Equipment/relationship 不变；
- Inspect/portal 的 Combat RNG 与 NPC-init RNG 都为零；
- 树冠 collision 与 camera coverage；
- 战斗中攀爬及既有 same-location cleanup；
- enter 当下零关系 mutation、下一 process 才启动、每 NPC 去重；
- 真实物理 Area enter/exit 的 escape window，exit cancellation 且不清理已建立战斗；
- capability、存在、ACTIVE、combat availability、same-location、combat-allowed gates；
- deferred pass 对 unregister、availability、life status、另一入口已开战的当前 authority 重查；
- unconscious/dead NPC、unconscious player、非玩家 body；玩家已有另一 opponent 不构成额外阻断；
- 三个重叠 NPC 的稳定 spawn 顺序、player-only target、零 combat RNG；
- Timer 已运行时不重启、manual Attack 在 aggression 后仍幂等；
- aggression 启动后的 unconscious/death/corpse/map continuation 与 dead Presence 不重触发；
- fresh scene 清 target/pending/presence/relations/corpse/RNG authority，scene signals 仍恰好一次。

Phase 7B3 定向 runner 同时回归 Phase 7B2、7B1、6B1、6B2、6B3 与 Phase 5B3 relationship/fight/execution/reverse boundaries；完整 runner 已正式注册本测试。

## 显式延期

- 通用 InteractionOption/action catalog；
- 条件 portal policy、跨 scene portal、vine/keep/cave；
- 通用 combat-allowed zone definition；当前接线只覆盖来源证明可战斗的 Old Pine 当前 map；
- NPC AI、感知属性、视线、追逐、NavigationAgent、wander/return-home；
- hatred/vendetta/berserk/pursuer；
- respawn、ROOM reset、Timer/heartbeat 调度；
- tree2/tree3 内容与黑衣人/蝴蝶 spawn；
- 最终美术、动画、VFX、音频与 UI。

## 正式验证记录

- Godot 4.7.2 Phase 7B3 正式审计定向回归：2182 assertions PASS。
- 完整项目套件（审计修复稳定后仅运行一次）：6850 assertions PASS。
- Godot AI/MCP：scene save、force reload 后检查到 102 个持久化节点；新增 zone/landmark/Presence/HUD signals 均按预期存在且无重复。
- Godot AI/MCP 启动主项目；game-helper 未在 20 秒等待窗口内回连，但没有报告当前 run 项目错误；Windows 实际 Godot 内嵌 Game 画面显示 Old Pine HUD、玩家、古松与 `Traverse` control。实际 picking、往返 portal 和真实物理 Presence 由 headless runtime tests 独立证明。

## 正式审计结论

审计发现并修复两个生产问题：

1. landmark 被选中后离开 portal 来源 zone，HUD 仍保留可点击的旧 `Climb/Descend`；现在 controller 以当前 map+zone 刷新一个窄的 presentation availability fact，执行仍由 portal adapter 再次权威验证。
2. destination validation 原先只比较 map+zone；现在同时拒绝错误 Old Pine region 与不匹配 authored zone 的 combat-location，且保持 validate-before-mutate。

未修改 Combat Core、Phase 6、Character/Skill/Equipment/Armor authority 或 `DECISIONS.md`。战斗中攀爬是 `clearing.c::do_climb()`、`feature/move.c::move()` 与 `std/room.c::valid_leave()` 直接证明的源行为，不是新的兼容性决定。

**Phase 7B3 正式关闭。Phase 7B 正式关闭。第一个 authored Old Pine world milestone 正式关闭。**

这里的“关闭”只覆盖首个 Old Pine Outdoor 可玩里程碑、古松 tree1 往返和狭窄 authored aggression；不表示完整 Old Pine、通用 AI、通用 portal、respawn、最终美术/UI 或 Phase 5B4 已完成。
