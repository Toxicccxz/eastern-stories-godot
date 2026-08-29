# Phase 9B3A：河谷、悬崖、藤蔓与跨场景状态交接分析

## 1. 已关闭基线与本阶段边界

Phase 9B2 以及首个护甲玩法闭环保持正式关闭；Phase 9B1、8B、7B、6 的既有契约也不重开。本阶段只形成下一实现阶段的设计契约，没有修改生产 GDScript、场景、`project.godot`、`DECISIONS.md` 或 `reference/es2`，也没有创建 Cave 场景。

当前运行基线是一个 `oldpine.outdoor` 场景兼任应用主场景与 runtime composition root。Godot MCP 只读检查确认：

- `application/run/main_scene = res://scenes/world/oldpine/oldpine_outdoor.tscn`；
- 场景完整层级为 180 个节点，根 `/OldPineOutdoor` 挂载 `res://runtime/world/oldpine_outdoor_controller.gd`；
- 根下直接拥有 Terrain、8 个 Zone、8 个 SpawnPoint、Player 与 5 个 NPC body、CorpseLayer、OpportunityTimer、HUD、Interactions 和 MazeEvidence；
- Player body 同时拥有启用的 Camera2D；OpportunityTimer 为 1 秒、非 one-shot、非 autostart；
- EastBridge Zone 当前启用 monitoring，场景没有 River/Cave 几何；
- `game/data/oldpine/oldpine_world_definitions.gd` 已定义 `oldpine.outdoor`、`oldpine.cave`、`oldpine.keep`，但 `res://scenes/world/oldpine/oldpine_cave.tscn` 尚不存在。

当前 `OldPineOutdoorController.initialize_world()` 每次创建新的 player、InventoryState、CombinedStackCollection、WorldItemInstanceIndex、map NPC state、NPC RNG 与 Combat RNG；`reset_world()` 直接 reload 当前场景。若直接切换或重建场景，现有玩家、装备、尸体、死亡 NPC、战斗关系、物品 ID 与 RNG 序列都会被重建。这不是可接受的跨 Map 语义。

主要 native 证据：

- `game/runtime/world/oldpine_outdoor_controller.gd:52-91,109-128,623-686`
- `game/runtime/characters/world_player_runtime_state.gd`
- `game/core/npcs/npc_runtime_state.gd`
- `game/runtime/world/map_character_runtime_state.gd`
- `game/data/oldpine/oldpine_world_definitions.gd`

## 2. LPC 精确拓扑

以下只列本阶段所需的实际可执行边；注释掉的边不计入：

```text
epath1 <-west- epath2 -east-> epath3 -west-> epath2
                    |
                    | hold/grab vine（条件分支）
                    +-- random(effective dodge) < 5 --> waterfall
                    +-- 否则 -------------------------> passage

passage -north-> secrectpath1（本阶段封闭）
passage -south-> waterfall

waterfall -south-> riverbank2
riverbank2 -north-> waterfall
riverbank2 -south-> riverbank1
riverbank1 -north-> riverbank2
riverbank1 -south-> lake（本阶段封闭；serpent 也延期）
riverbank1 --climb cliff--> cliff1
cliff1 --climb down--> riverbank1
cliff1 --climb up--> cliffside
cliffside -north-> pine1

cliffdown --climb down--> cliff2
cliff2 --climb up--> cliffdown
cliff2 --climb down--> epath3
```

明确的单向性：

- `cliffside -> pine1` 有 north exit；`pine1` 没有因此获得一个通往 cliffside 的反向边。
- `cliff2 -> epath3` 有 down action；`epath3` 只有 west -> epath2，没有返回 cliff2 的边。
- `cliffdown -> cliff2` 只有 down action；其文字却写“爬了上去”，这是可执行分支中的表现文本疑似笔误，不能改成反向移动。
- `cliffdown` 的四个普通方向在 room create 时分别取 `pine1..pine6`，另有固定 northeast -> pine7；Phase 9B1 已将这类随机迷阵改成固定 Pine 迷宫，本阶段不重开该决定。
- `cliffside.c` 中 south/east 两项被注释，不能据描述补成可走边。

来源：

- `reference/es2/mudlib/d/oldpine/epath2.c:25-28,34-57`
- `reference/es2/mudlib/d/oldpine/epath3.c:18-24`
- `reference/es2/mudlib/d/oldpine/passage.c:17-20`
- `reference/es2/mudlib/d/oldpine/waterfall.c:22-25`
- `reference/es2/mudlib/d/oldpine/riverbank2.c:19-24`
- `reference/es2/mudlib/d/oldpine/riverbank1.c:21-43`
- `reference/es2/mudlib/d/oldpine/cliff1.c:19-38`
- `reference/es2/mudlib/d/oldpine/cliffside.c:15-19`
- `reference/es2/mudlib/d/oldpine/cliffdown.c:15-21,33-46`
- `reference/es2/mudlib/d/oldpine/cliff2.c:19-38`

这些 LPC rooms 是拓扑与内容依据，不是一房一 scene 的指令。River/Cliff 仍属于 `oldpine.outdoor`；`passage` 属于既有 `oldpine.cave`。不得新增 `oldpine.passage` Map，也不得用 waterfall shortcut、Cave bypass 或无来源的 reverse cliff portal 改写拓扑。

## 3. 藤蔓动作的精确执行顺序

`epath2.c::do_hold_vine()` 的实际顺序是：

1. `arg` 必须存在且严格等于 `"vine"`；否则 `notify_fail`，无表现、技能读取或随机消费。
2. 向来源房间表现玩家爬上桥栏并伸手抓藤。
3. 调用玩家的有效 `query_skill("dodge")`。
4. 立即把该值作为 `random(value)` 上界。
5. 以严格 `< 5` 比较随机结果。
6. 失败分支先做来源表现，再对 waterfall 房间 `tell_room`，最后 `move(waterfall)`。
7. 成功分支先做来源表现，再对 passage 房间 `tell_room`，最后 `move(passage)`。
8. 两分支后返回 1；move 后没有额外表现。

这不是 busy、战斗或负重 gate。动作直接调用 `feature/move.c::move()`；它没有 `is_fighting()`/busy 检查，也不清战斗关系。`cmds/std/go.c` 的 busy、负重与成功后 `remove_all_enemy()` 只属于普通方向命令，藤蔓动作没有经过它。因此未来 vine 必须允许战斗中使用，且不能在 handoff commit 内直接清关系。

来源：`reference/es2/mudlib/d/oldpine/epath2.c:39-57`、`reference/es2/mudlib/feature/move.c:46-95`、`reference/es2/mudlib/cmds/std/go.c:36-83`。

## 4. 有效 dodge 的唯一 native 来源

LPC `feature/skill.c::query_skill(skill)` 的已迁移等价物是：

```gdscript
player.state.skills.effective_level(
    &"dodge",
    player.armor.aggregate_numeric_modifiers().dodge,
)
```

`CharacterSkillState.effective_level()` 计算“raw/2 + 已 enable 特殊技能的完整 raw + 显式 temporary modifier”；Combat 投影已经以 ArmorState 的 dodge aggregate 作为该显式 modifier。World interaction 应复用同一 API 和同一 armor modifier，不复制 raw/2、enable 或护甲算法。证据：`game/core/skills/character_skill_state.gd:68-75`、`game/runtime/combat_slice/combat_slice_projection_builder.gd:171`。

当前 demo player 的 raw dodge 为 10、没有映射 dodge，未穿皮衣时有效值为 5；因此 `random(5)` 只能得到 0..4，当前角色必然走 waterfall。穿皮衣的 dodge -2 会使有效值成为 3，仍必然失败。成功至少需要有效值大于 5，并实际抽到 5 或以上。该结论来自源公式与当前 fixture，不是新增成功率公式。

## 5. `random(0)` 结论

本地 `reference/es2/mudlib/doc/efuns/random` 只声明 `int random(int n)` 及正上界返回范围，没有定义 `n == 0` 或负数。仓库没有随附能证明部署版本行为的 MudOS/FluffOS driver 源码；项目笔记也没有额外证据。因此歧义仍未解决。

未来 vine policy 在到达随机位置时应：

- 先保留已经发生的目标验证与来源表现；
- 若 effective dodge `<= 0`，不调用 RNG，不 clamp、不默认成败，返回 typed `LEGACY_NON_POSITIVE_RANDOM_BOUND`，记录原始 bound 与 exact failure stage；
- 正 bound 时才调用 `next_below(bound)`，并验证注入 draw 在 `[0, bound)`。

这不阻塞正上界实现，也不阻塞当前玩家内容：当前未穿甲 bound 为 5，属于定义明确的正上界。它只使非正状态显式 unsupported。`DECISIONS.md` 现有“Combat invalid random bounds”已建立同类安全原则，但标题与范围只覆盖 Combat；进入实现前应增加一项明确延伸到 authored world interaction 的决定，而不是假定 Combat 决定自动覆盖 Vine。

来源：`reference/es2/mudlib/doc/efuns/random`、`reference/es2/mudlib/d/oldpine/epath2.c:45`、`docs/migration/DECISIONS.md`。

## 6. WorldInteractionRandomSource

新增边界应是一个 Node-free、可注入的 `WorldInteractionRandomSource`，唯一最小方法为 `next_below(upper_bound: int) -> int`。另有一个 Godot RNG 实现和一个测试脚本实现即可。

所有权与规则：

- 生命周期为 Old Pine world session，而非单个 Map；来回切换不得重播 seed。
- 与 Combat RNG、NPC initialization RNG 严格分流；vine 不能消耗后二者。
- policy 负责判断 non-positive bound，random source 不替 policy 发明 fallback。
- scripted source 记录每个 requested bound 与 draw，测试可证明只在 LPC 的 exact random 位置消费一次。
- 不使用全局 `rand*`、Autoload RNG 或静态 mutable RNG。

## 7. 当前跨场景所有权问题

当前 Outdoor controller 同时是四种角色：

```text
场景根
├── session authority creator（player、inventory、stack、item index、RNG）
├── map authority owner（NPC、corpse、aggression、cadence）
├── physical map/controller（body、zone、portal、camera）
└── presentation owner（target、HUD、loot/inventory panel）
```

第一张地图时这种合并可工作；第二张真实 Map 出现后，任何 scene reload/change 都会把 session authority 当作 map state 销毁。正确改变不是建立全局 WorldManager，而是把“一个 Old Pine 游玩会话”的寿命提升到各 Map 之上。

## 8. 玩家 authority 生命周期

推荐由一个 region/session-local `OldPineWorldSessionController` Node 持有同一个 `WorldPlayerRuntimeState` 引用，整个 Outdoor -> Cave -> Outdoor 往返不替换该对象。

同一个 runtime 已包含或引用：

- CharacterId；
- CharacterState（属性、gin/kee/sen、内部资源、conditions、skills/progression、family/apprenticeship、EquipmentState）；
- CombatRelationshipState；
- ActionBusyState；
- ArmorState；
- committed life status、exists/combat availability；
- maximum encumbrance；
- 当前 WorldLocationState snapshot。

因此只要交接同一个 `WorldPlayerRuntimeState`，装备与角色状态自然保留；绝不能从 HUD row、definition ID 或新的 CharacterState 重建。现阶段不需要再增加一个平行的 Node-free `OldPineWorldSessionState`；已有纯 domain authorities 足够，新增 Node 只负责生命周期和场景编排。

## 9. InventoryState 生命周期与替代方案

推荐把当前 `InventoryState` 的 runtime 所有权提升为 Old Pine session-local，并让所有已加载 Old Pine maps 注入同一个实例。

| 方案 | 结论 |
|---|---|
| A. 一个 session InventoryState | 推荐。保留同一个 ItemInstanceId、direct parent、祖先重量与装备引用；不改变任何 Phase 4/8 domain 规则。 |
| B. player 与各 map 分拆多个 InventoryState | 不推荐。角色拿取/丢弃、尸体转移和跨 map WORLD endpoint 需要跨 authority 搬运，出现双重 liveness owner。 |
| C. 在 MapState 间 reconstruct/transfer | 拒绝。会制造新 ItemInstance、stack amount 与 equipment refs 重建问题，实质提前做保存恢复。 |
| D. 只把 source map 保留并继续借用其 InventoryState | 比重建安全，但所有 Cave 操作仍依赖“Outdoor 拥有世界库存”的错误方向；应把 ownership 提升到 session。 |

`InventoryState` 不知道 Map，只认识 CHARACTER、ITEM、WORLD 三种 opaque stable endpoint。它可以同时容纳多个 Map 的 WORLD endpoint；只要 endpoint ID 全局稳定且不冲突，domain semantics 不变。现有 combat-location ID 都带 `oldpine.<map>.` 前缀，天然区分 Outdoor 与 Cave。Map/runtime adapter 负责构造 endpoint，不在 InventoryState 内解析字符串。

证据：`game/core/inventory/inventory_state.gd`、`game/core/inventory/containment_endpoint.gd`、`game/runtime/world/oldpine_outdoor_controller.gd:988-1001`。

## 10. CombinedStackCollection 生命周期

`CombinedStackCollection` 必须和共享 InventoryState 同寿命、同 owner。它按稳定 ItemInstanceId 保存 amount/definition 关联，没有 Map 语义；每 Map 重建会改变银两和堆叠身份。session 只创建一次，Map adapter 只能使用注入引用，不能 reconstruct amount。

证据：`game/core/items/combined/combined_stack_collection.gd`。

## 11. WorldItemInstanceIndex 生命周期

最小方案是一个 session-level `WorldItemInstanceIndex`：

- 同时保存 player、resident NPC、corpse 与 world item 的 metadata snapshot；
- 继续只作 metadata lookup，InventoryState 仍是 registered/liveness 与 containment authority；
- destroyed item 的 liveness 必须继续由既有 lifecycle 从 InventoryState 移除；当前 index 没有 remove API，允许保留不可变的 stale metadata snapshot，但任何查询都必须先以 InventoryState 证明确实存活，不能因旧 map resident 或 stale snapshot 而复活；
- item ID scope 应由 session 创建一次，并含稳定 map/owner 前缀；不能继续用会随 Outdoor scene 重建的 map Node instance scope；
- 不需要 ItemRepository、全局 entity registry 或 Map ID 字符串解析。

分成“每 Map index + player index”会令一次装备/尸体转移跨越多个 metadata owner，没有收益。当前类注释中的 map-instance-local 定位应在未来 ownership 提升时同步更正，但无需改 domain shape。

证据：`game/runtime/world/world_item_instance_index.gd`、`game/runtime/world/oldpine_outdoor_controller.gd:112-121,659-680`。

## 12. source Map 的 NPC、corpse 与 item 状态

Outdoor 的以下状态继续由其 Map runtime instance 持有：NpcRuntimeState/MapCharacterRuntimeState、NPC bodies、corpse domain state 与 views、map-local aggression queue/presence、map selection，以及 map-specific lifecycle counters。进入 Cave 时不销毁、不重新 initialize。

因此已经死亡的 Tall 仍死亡；已拿走的皮衣不会回到 Fat 尸体；尸体、剩余 loot、NPC current resources/relationships 和位置保持原对象；返回时不会重复 spawn 或重复注册 item ID。Cave 的 map state 同理，第一次建立后往返保留。

共享 InventoryState 持有 corpse/item containment；resident Map runtime 持有 corpse 的地图归属与 physical view。两者是互补 owner，不是重复 authority。未来如果 unload，需要完整 map-runtime snapshot 契约；本阶段明确不做。

## 13. 常驻实例与 snapshot 比较

第一轮多 Map proof 推荐保持 Outdoor 与最小 Cave 的场景实例常驻内存：

- source scene 从 SceneTree 的 active slot 移除但不 `queue_free()`，由 session 的 loaded-map table 保持强引用；
- destination scene 加入 active slot；
- 非活动实例处于 SceneTree 外，天然没有渲染、physics、Area overlap、input、Camera 或 `_process()`；
- Map domain/runtime Node fields、NPC/corpse views、Timer 对象和 signal setup 仍留在同一个实例；`_ready()` 不应再次初始化已完成 Map。

这比仅设 `visible=false` 安全；隐藏 CanvasItem 不会自动禁用 collision/Area/Timer。也比为每个 map 建 SubViewport、collision-layer bank 或 streaming framework 小。Outdoor + tiny Passage Cave（以后最多加 Keep）对当前 placeholder 规模很便宜。

卸载加 snapshot 现在需要设计 NPC、corpse、relationship、RNG、item view 和 physical position DTO，是 persistence scope creep。完全 reload/reset 会明确复活 NPC/loot，拒绝。

## 14. Old Pine world-session root

第二个真实 `MapDefinition` 已足以证明一个窄 session composition root。未来主场景应改为类似：

```text
OldPineWorldSession (Node)
├── session authorities（非 Node 引用）
├── ActiveMapSlot (Node)
└── 一个既有 HUD/transition presentation owner（可选迁移，不扩展 UI）

loaded map table（强引用，不是全局 registry）
├── oldpine.outdoor scene instance
└── oldpine.cave scene instance
```

最小职责：创建一次 session authorities/RNG/item ID scope；按既有 MapDefinition scene path 实例化 Old Pine Map；只激活一个 Map；注入共享 authority；执行 typed transition gate/handoff；fresh reset 时销毁整个 session 并重建。它不是 Autoload、singleton、跨 region WorldManager、service locator 或通用 entity registry。

现有 `OldPineWorldDefinitions`、Npc/Spawn/Item definitions 足够；不用加 repository。该结构日后可增加已定义的 `oldpine.keep`，不要求当前实现 Keep。

## 15. active/inactive Map 处理规则

第一切片采用“仅 active Map 推进”的明确规则：

| 项目 | active Map | inactive resident Map |
|---|---|---|
| SceneTree | 在 ActiveMapSlot | 脱离 SceneTree但不释放 |
| visible/camera | 开启唯一 active camera | 无渲染、camera inactive |
| physics/Area/input | 开启 | 无 SceneTree physics/input |
| `_process`/`_physics_process` | 开启 | 不执行 |
| OpportunityTimer | 只由 active map 驱动 | 不推进、不产生机会 |
| NPC/condition/recovery | 当前已接线的 active cadence 才推进 | 冻结，不发明 off-screen heartbeat |

这与 MUD 全局 heartbeat 的“全世界持续运行”存在可观察差异，应在实现前记入 `DECISIONS.md`。不应在本阶段偷偷实现 off-screen simulation。

Map deactivation 时清除/作废只依赖 Area overlap 的 pending aggression 与 Node-bound current target；已建立的 CombatRelationshipState、NPC state、corpse state不清。Map reactivation 在任何 aggression/attack 前重新从真实 overlap 建立 presence。

## 16. 玩家 physical body 绑定

每个 Map 保留自己的 local `WorldCharacterBody2D`、Camera2D 与 landing markers；跨 Map 共享的是同一个 `WorldPlayerRuntimeState`，不是同一个 physics Node。

约束：

1. 任何时刻只有 active Map 的 player body 在 SceneTree、`player_controlled=true`、collision/input/camera enabled。
2. source body 随 source Map 脱离 SceneTree后仍可保留旧绑定，但不可控制；destination body 调用 `bind_player(same_runtime)`。
3. destination body 在 map-local marker 上定位；Node/Vector2 不进入 domain result。
4. destination activation 后才允许 input；source signal 不重复连接，Map `_ready()` 不重复 initialize。
5. WorldCharacterBody2D 的 Node identity 不是 CharacterId；测试必须断言两个 body 不同而 runtime/CharacterState 引用相同。

证据：`game/runtime/world/world_character_body_2d.gd`、当前 MCP Player/Camera hierarchy。

## 17. 跨 Map 战斗关系清理

Vine 的 LPC direct `move()` 不清 enemy。正确路径是：

```text
handoff commit location
→ destination active
→ 排队一次 active-player availability reconciliation
→ CombatOpponentSelectionService.prepare() 读取所有既有 opponent 的
   exists/same_location/living facts
→ 异 Map ordinary opponent 从 opponent list 移除
→ lethal target marker 独立保留
```

这不是 transition 直接编辑关系，也不是执行一次攻击。它复用现有 typed availability cleanup seam；当全部 opponent 异地时不会到达 selection RNG。它必须独立于 busy 倒计时，否则保留下来的 busy 可能令清理永远没有机会。session 不建立全局 character registry，而是向 resident Map runtime 询问每个稳定 CharacterId 并形成 facts。

inactive source NPC 不执行机会，关系保持冻结；其 Map 再激活时，在 attack/aggression 前先做相同 availability reconciliation。这样不会产生离屏攻击，也不会因 frozen NPC 阻塞玩家清理。

`passage -> waterfall` 在 LPC 是普通 `go` exit，而 `go.c` 成功 move 后会调用 mover 的 `remove_all_enemy()`；这与 vine/custom climb 的 direct move 不同。Godot 已决定物理走路不模拟 go command，Phase 7B3 又采用 location availability cleanup。为避免 shared portal helper 暗藏不同清理，第一实现应统一使用 availability cleanup，并在 `DECISIONS.md` 明确记录“跨 Map 的普通 exit 也采用 native location cleanup，不复制 go.c 的即时 remove_all_enemy”这一可观察适配；若产品选择精确保留 Passage 特例，则必须是一个显式 typed post-commit relationship policy，不能是 portal callback。

证据：`game/core/combat/relationship/combat_opponent_selection_service.gd`、`game/core/combat/relationship/combat_relationship_state.gd:93-97`、`reference/es2/mudlib/cmds/std/go.c:76-82`。

## 18. Timer 与 RNG ownership

- OpportunityTimer：Map-local；只 active Map 推进。activation 若发现 persistent player 仍有 opponent，先安排 availability reconciliation，再决定是否启动普通 combat cadence。
- Combat RNG：提升为 Old Pine session-local 单一 stream，注入 active Map；换 Map 不 reseed。Cave 没有 combat 时不消费。
- NPC initialization RNG：session-local stream；每个 Map 只在第一次创建其 authored NPC 时消费。最小 Cave 没有 NPC，消费为零；返回 Outdoor 不再 initialize。
- World interaction RNG：另一个 session-local stream，只供 vine 等 authored world random decision。

分开三条 stream 能证明 vine 的一个 draw 不改变后续 Combat/NPC 序列。不存在 global RNG。

## 19. 条件 portal policy

不要让一个 PortalDefinition 同时承担随机决策和两个 destination。推荐模型：

```text
VineTraversalPolicy（显式 authored policy ID）
├── source map/zone 与 legacy hold|grab vine metadata
├── failure_portal_id -> Outdoor waterfall landing
└── success_portal_id -> Cave passage landing

evaluate(same player runtime, WorldInteractionRandomSource)
→ VineTraversalDecision
   - effective_dodge
   - random_bound / draw presence
   - selected branch
   - selected PortalDefinition ID
   - typed failure stage
```

两条 branch 各自仍是普通、单 destination 的 `PortalDefinition`。policy 只选择 portal，不移动 body、不 set location、不操作关系、不发 signal、不呈现文本。Old Pine controller/session 显式持有这一 policy；只有一个用例时不需要通用 policy repository 或脚本 VM。`PortalDefinition.InteractionKind` 可新增窄 `VINE`/`TRAVERSE` 值表达 UI 行为，不能把 `hold/grab` command dispatcher 搬进 runtime。

未来 presentation 在 policy 前后按 LPC order 发结构化事件；命令字符串只保留 legacy trace metadata。

## 20. 跨 scene validate/commit 顺序

动作层与 handoff 层分开后，完整顺序为：

1. 验证当前 active Map/zone、vine landmark 与 `vine` target；失败零 mutation/零 RNG。
2. 发出 LPC 的 pre-branch source presentation。
3. 用 CharacterSkillState + ArmorState 读取 effective dodge。
4. 到达 exact random stage；non-positive 返回 typed ambiguity，正 bound 消费一次 world-interaction RNG。
5. 严格 `<5` 选择 failure/success PortalDefinition。
6. 发出对应 source/destination-before-move presentation event。
7. traversal helper 验证 transition gate 空闲、portal source 与当前 WorldLocation 一致、destination Region/Map/Zone/combat-location 定义一致、destination scene instance 可用、landing marker identity 正确、destination body 可绑定。
8. 设 transition-in-progress；关闭 source 的 Node-bound selection/panels/pending aggression，禁止新增 input。
9. 将 destination scene 以 disabled/hidden 状态临时放入 slot，给 destination body 绑定同一个 runtime 并定位；此时仍不可控制。
10. source scene 脱离 active slot但保留实例；保证 source body 不再参与 physics/input。
11. 一次性提交有效的 destination WorldLocation，这是 domain commit point。
12. 激活 destination map/body/camera，保持同一 inventory/equipment/armor/RNG authority。
13. 清 transition gate，并排队 active-player availability reconciliation；最后返回 typed result。

为了保留 source order，不能把 skill/random branch 移到 destination validation 之后。可以在 session 初始化时提前实例化并验证两个已知 Map 以降低失败概率，但动作发生时仍要重验当前 marker/body contract。

## 21. partial transition failure

整个 gameplay transition 不能宣称 atomic。结果至少应记录：policy/RNG 是否已到达、destination 是否 validated、destination body 是否 bound/placed、source 是否 deactivated、logical location 是否 committed、destination 是否 activated，以及 failure stage。

- 第 7 步前失败：可能已有表现与 RNG 消费，但 containment、body、location、active map 都未变。
- 第 8-10 步异常且 location 未 commit：保持 gate，撤下 destination，重新激活 source；typed result诚实记录中间 physical preparation，不能回滚 RNG/表现。
- 第 11 步 commit 后异常：权威位置已经是 destination；不得谎称 source active 或回滚 gameplay state。保持两边 player control 关闭，以 destination 为恢复目标，返回 committed-partial failure。
- 任一失败都不能让两个 player bodies 同时可控制，也不能重建 player/inventory。

同 Map portal 也可使用相同 validate/commit helper；现有 adapter 的“physical first、logical second”证据字段可保留，但新的共享 helper 应预验所有可证明条件并报告 ordered partial，而不是承诺事务式原子性。

## 22. 最小 CaveMap

第一张 Cave scene 只代表 `passage.c`：

- 一个 waterfall-passage zone 和稳定 combat-location；
- vine success landing marker；
- 可见的岩石通道、南侧帘幕/瀑布边界与 north boundary；
- south interaction/portal 回到 Outdoor waterfall landing；
- north 明确封闭并标注 secret passage 尚未迁移；
- 一个 local player body/Camera 接受 persistent runtime binding；
- 不创建 secrectpath1、path3、stone、cave maze、maniac、venomsnake、skeleton、book、study 或 NPC。

它只完成 Passage partial parity，不能称 Cave 已迁移完成。

建议 ID：

- zone/combat location：`oldpine.cave.waterfall_passage`（复用既有 ID）；
- landing：`oldpine.cave.waterfall_passage.vine_landing`；
- return portal：`oldpine.cave.passage_to_waterfall`；
- north boundary 只有 presentation evidence，不建可穿越 portal。

## 23. 最小 River/Cliff segment

Outdoor 最小连贯段为：

```text
waterfall basin
  ↕ continuous south/north walking
riverbank2
  ↕ continuous south/north walking
riverbank1
  └─ explicit climb cliff portal -> cliff1 ledge
cliff1
  ├─ climb down -> riverbank1
  └─ climb up -> cliffside
cliffside
  └─ one-way north portal -> existing Pine Entrance
```

waterfall 是 vine failure 与 Passage return 的同一 authored landing。riverbank1 南侧 lake 保持有碰撞与明确延期标识；不创建 lake shortcut、serpent 或 beast support。cliffside 与 Pine Entrance 必须物理隔离，通过单向 portal 落点连接，以免玩家走回一个 LPC 不存在的 reverse edge。

River 的普通 north/south 路段用连续物理步行；climb 仍用 typed interaction/portal。River/Cliff 只迁移这一走廊，不宣称整个 river/cave 完整。

## 24. cliffdown/cliff2 结论

不纳入前三个实现 slice。它是 Pine cliff edge 到 East Bridge 的第二条、独立单向链，对证明 Outdoor <-> Cave state handoff 没有依赖；同时需要三个不同 combat locations、两次 climb landing、`cliffdown` 固定迷宫边界和 epath3 单向出口的物理隔离。把它塞入 River roundtrip 会降低首个多 Map proof 的可审计性。

后续独立小 slice 可实现：PineCliffEdge/cliffdown --down--> cliff2 --up--> cliffdown、--down--> EastBridge/epath3；绝不能给 epath3 添加 reverse cliff2 action。`cliffdown` 的“down 却写爬上去”保留为 presentation legacy defect 记录，不改变方向。

## 25. logical combat locations

WorldLocation 继续包含 region/map/zone/combat-location 四个稳定 ID，不使用 Node path 或坐标。建议最小集合：

| legacy area | map | zone / combat_location_id |
|---|---|---|
| epath1/2/3 | `oldpine.outdoor` | `oldpine.outdoor.east_bridge`（既有） |
| waterfall | `oldpine.outdoor` | 新增 `oldpine.outdoor.waterfall_basin` |
| riverbank1/2 | `oldpine.outdoor` | `oldpine.outdoor.river_gorge`（既有 ID，移出 waterfall/lake metadata 时需更新定义） |
| cliff1/cliffside | `oldpine.outdoor` | `oldpine.outdoor.cliff_ledge`（既有） |
| pine1 landing | `oldpine.outdoor` | `oldpine.outdoor.pine_entrance`（既有） |
| cliffdown | `oldpine.outdoor` | `oldpine.outdoor.pine_cliff_edge`（延期） |
| cliff2 | `oldpine.outdoor` | `oldpine.outdoor.cliff_ledge`（延期；与 west ledge 共 ID 是否过宽应在该 slice 重审） |
| passage | `oldpine.cave` | `oldpine.cave.waterfall_passage`（既有） |

waterfall 单列是为了避免玩家/NPC在整个 riverbank corridor 隔空交战。每个 ID 带 map 前缀，WORLD containment endpoint 跨 Map 不冲突。现有 `_zone()` 把 zone ID 同时作为 combat ID；第一实现应继续用明确 zone，而不是引入另一套位置 repository。

## 26. shared portal traversal helper

现在有第二个真实用例（跨 Map）与多条 same-Map cliff portal，提取一个小型 shared helper 已经成立，但边界必须窄：

- 输入：persistent player runtime、单 destination PortalDefinition、source/destination Map adapters、typed marker resolution；
- 负责：定义与 source/destination 验证、同 Map physical relocation或跨 Map handoff、WorldLocation commit、ordered result；
- 不负责：条件决策、随机、技能公式、关系 mutation、presentation strings、Map loading registry、save、通用 callbacks。

Vine policy 先选择一条 portal；shared helper 只执行所选 portal。same-Map waterfall/cliff 与 cross-Map passage 可以共用验证/result shape，但 cross-Map activation由 session controller编排。不要创建 universal portal scripting engine、`Callable` hook 或 daemon-style dispatch。

## 27. 实现前可能需要的 DECISIONS 条目

本阶段不编辑 `DECISIONS.md`。实现前应记录三项真实的可观察适配：

1. **非活动 resident Map 冻结**：不模拟 MudOS 全局 heartbeat；只有 active Map cadence 推进。
2. **World interaction 非正 random bound**：把现有 Combat typed-failure 原则显式延伸到 Vine 的 `random(effective dodge)` exact stage。
3. **跨 Map ordinary exit 的关系清理**：推荐统一使用 location availability cleanup，而不是在 Passage portal 内复制 `go.c::remove_all_enemy()`；这必须明说。

“Old Pine maps 在当前 session 常驻内存”本身是 runtime lifetime 方案，不改变游戏结果，不必单独成为兼容决定；若未来因 resident/frozen 导致可观察计时差异，已经由第 1 项覆盖。若 vine 的 native proximity area 令玩家可从 LPC epath2 以外触发，则必须另记 reachability 决定；正确几何应先避免这种差异。

## 28. source partial-parity ledger

| 内容 | 首轮状态 |
|---|---|
| epath2 hold/grab vine target | 实现 exact source zone + proximity interaction；不做 command parser |
| pre-branch presentation | 结构化 presentation event，顺序保留 |
| effective dodge | 复用 CharacterSkillState + ArmorState modifier |
| RNG | 独立 WorldInteractionRandomSource；正 bound exact；非正 typed ambiguity |
| failure branch | same-Map Outdoor waterfall landing |
| success branch | cross-Map Cave passage landing |
| passage south | cross-Map return waterfall |
| passage north | 明确 blocked/deferred；不创建 secret passage |
| waterfall/riverbank2/riverbank1 | 连续 Outdoor geometry；lake 南边 deferred |
| riverbank1/cliff1/cliffside | typed climb portals；cliffside -> Pine 单向 |
| cliffdown/cliff2/epath3 | 后续独立 slice 延期 |
| lake/serpent/venomsnake | 延期；不建立 beast/poison 支撑 |

## 29. Phase 9B3 风险表

| 风险 | 可能性 | 成本 | 缓解 |
|---|---:|---:|---|
| player inventory identity 丢失 | 高（若重建） | 极高 | session 只持有一个 InventoryState 与同一 player runtime |
| Outdoor NPC 回来后 reset | 高（若 change_scene） | 极高 | resident Map instance，不重复 initialize |
| duplicate ItemInstance IDs | 中 | 高 | session ID scope + shared index/register rejection + roundtrip test |
| 两个可控 player bodies | 中 | 极高 | transition gate；source 脱树；destination commit 后才启用 input |
| inactive physics/Area 泄漏 | 高（仅隐藏） | 高 | inactive Map 脱离 SceneTree，不只 visible=false |
| inactive Timer 继续跑 | 中 | 高 | inactive Map 无 SceneTree process；activation/cadence tests |
| 战斗关系 cleanup deadlock | 中 | 高 | destination 排队 active-player availability reconciliation；不依赖 source NPC tick |
| Combat/NPC/world RNG reseed或串流 | 中 | 高 | 三条 session-local 独立 stream；记录 bounds/calls |
| `random(0)` 被悄悄 clamp | 中 | 高 | exact-stage typed ambiguity + DECISIONS entry + zero test |
| cross-scene partial failure | 中 | 极高 | validate/commit stages、单 control gate、pre/post-commit recovery target |
| 提前做 persistence/save | 中 | 高 | resident in-memory maps；不建 DTO/serializer |
| generic WorldManager 膨胀 | 中 | 高 | Old Pine-local Node、无 Autoload/registry/service locator |
| stale target/Loot UI 指向旧 Node | 中 | 中 | transition 时清 Node-bound selection并关闭 panels，authority 不变 |
| corpse/world endpoint Map 冲突 | 低 | 高 | map-prefixed combat IDs；Inventory 不解析 ID |
| 默认玩家永远无法成功抓藤 | 高（当前 fixture） | 中 | 诚实记录；测试用真实高 dodge state，不改公式或伪造成功 |

## 30. 最多三个实现 slice

### Phase 9B3B1：Old Pine session 与 Map lifetime foundation

- 新 OldPineWorldSession composition root 与 ActiveMapSlot；
- 提升同一 player、InventoryState、CombinedStackCollection、item index、RNG 的 ownership；
- Outdoor controller 改成 dependency injection 且只初始化一次；
- 最小 Passage Cave scene 与 inactive/active Map contract；
- 用 typed handoff integration test证明同一 runtime/CharacterState 与 Outdoor state roundtrip；
- 不接 vine random、不扩 River geometry。

### Phase 9B3B2：Vine policy + cross-Map portal + waterfall landing

- WorldInteractionRandomSource 与 scripted source；
- 两条 vine branch portal、exact effective dodge/random/order；
- Cave passage south return；
- Outdoor waterfall basin 与 landing；
- active-player availability reconciliation、typed partial failure；
- 默认 demo 玩家可见失败落水；高 dodge deterministic QA fixture证明 success与 Outdoor -> Cave -> Outdoor。

### Phase 9B3B3：Riverbank 与 west cliff 到 Pine

- waterfall -> riverbank2 -> riverbank1 连续几何；
- riverbank1 <-> cliff1、cliff1 -> cliffside、cliffside -> Pine1 单向 portal；
- lake 南边明确封闭；
- 不含 serpent、cliffdown/cliff2、Cave north/maze。

## 31. 未来测试计划

### Session identity

- Outdoor/Cave/Outdoor 三段都返回完全相同的 WorldPlayerRuntimeState 与 CharacterState object identity。
- attributes/resources/conditions/skills/progression/family/apprenticeship、busy、life、maximum encumbrance 不变。
- 同一个 EquipmentState/ArmorState 权威仍指向相同 ItemInstanceIds；primary/secondary 与 WORN leather 不重建。
- silver amount、starting/looted weapon IDs、stack associations 精确不变。

### Outdoor/Cave preservation

- 先杀 Tall、改变 Fat、保留/拾取尸体物品，再往返 Cave；死者不复活、尸体与剩余 loot 不变、没有 duplicate spawn/item/corpse。
- Cave scene 第二次进入是同一 resident instance，Map state 不重建。
- fresh session reset 才恢复初始 authored state。

### Map activation

- 任意时刻只有一个 Map 在 SceneTree；只有一个 player body 可控制、一个 Camera enabled。
- inactive Map `_process`、physics、Area、aggression、cadence 都不推进；返回后 state 原样续用。
- target 与 Loot/Inventory panels 切换时安全清除，gameplay inventory authority 不变。

### Portal/handoff

- source map/zone、destination map/zone/combat location、marker ID 全部精确；wrong/missing marker 在 commit 前失败。
- same-Map failure 到 waterfall；cross-Map success 到 passage；passage south 返回同一 waterfall landing。
- pre-commit failure reactivates source；post-commit failure零双重控制并指向 destination recovery。
- same-Map cliff portals保持单向拓扑，不产生 shortcut。

### Vine/RNG

- effective dodge 来自 `effective_level(&"dodge", armor_dodge)`，包含 raw-half、mapped skill 与护甲 modifier。
- bound 1/5 时 draw 均 `<5` 失败；bound 6 时 draw 4 失败、draw 5 成功；比较严格边界独立来自 LPC。
- 每次合法动作 world RNG 恰好一次；invalid target 零次；non-positive 返回 exact typed ambiguity且零 RNG call。
- Vine 对 Combat RNG 与 NPC RNG 调用数均为零；roundtrip 不 reseed world RNG。
- 当前 demo raw dodge 10 的 effective 5 必然失败；测试不得从 GDScript 实现反算期望。

### Combat relationship

- 战斗中 vine 合法，busy 与 conditions 原样保留。
- handoff 不直接 mutate relationship；destination 的 explicit availability reconciliation 移除异地 opponent、保留 lethal marker，且全移除时零 Combat selection RNG。
- inactive source NPC 不攻击；重新 active 时先 reconciliation 再可能 attack/aggression。

### Godot/MCP 实现验证

未来用 Godot MCP 创建/检查 session root 与最小 Cave scene，验证 hierarchy、Map slot、player/Camera/Timer/CorpseLayer、Zone/Area、landing markers 和 signals；保存后 reload editor，再启动真实场景完成 Outdoor -> Cave -> Outdoor 与失败 waterfall 两条路径。MCP 只负责 scene/runtime 连接与可视验证，公式和 authority 仍由 headless domain/runtime tests 证明。

## 32. 首个精确可见验收闭环

Phase 9B3B2 的可见闭环为：

```text
Outdoor East Bridge / epath2 vine area
→ Inspect/Traverse（目标 vine）
→ exact pre-branch presentation
→ 高 dodge QA session 中 scripted world draw 5 / bound 6
→ 同一个 player runtime 进入 Cave Passage landing
→ Cave 中可行走；north boundary 明确封闭
→ 选择 south curtain traversal
→ 同一个 player runtime 返回 Outdoor Waterfall landing
→ inventory 中原 ItemInstanceIds、silver amount、双手武器状态、WORN leather、
   CharacterState、skills/progression、life/busy/armor 全部不变
→ 返回原 resident Outdoor，已死亡/已 loot NPC 与 corpse state 不重置
```

高 dodge QA session 必须通过真实 CharacterSkillState（例如 raw dodge 12、无 modifier得到 effective 6）与注入 RNG 建立，不能向 policy 直接塞伪造“成功”布尔值。当前默认 demo effective 5 的玩家会可见地落入 waterfall；不能为了展示成功而修改 `<5` 或 clamp/加 bonus。

## 33. 十八项正式架构答案

| 问题 | 明确答案 |
|---|---|
| 1. 谁跨 Map 持有 player runtime？ | 非全局的 OldPineWorldSessionController，持有同一 WorldPlayerRuntimeState。 |
| 2. 谁持有 InventoryState？ | Old Pine session；所有 resident maps 注入同一实例。 |
| 3. 谁持有 CombinedStackCollection？ | 与 InventoryState 相同的 session owner。 |
| 4. 谁持有 WorldItemInstanceIndex？ | session-level 单一 metadata index；Inventory 仍为 liveness authority。 |
| 5. inactive NPC/corpse 怎么办？ | 原 Map runtime instance 保留并冻结，不重建、不 decay。 |
| 6. 旧 Map scene 是否常驻？ | 是；实例有强引用，inactive 时脱离 SceneTree。 |
| 7. 谁持有 Combat RNG？ | Old Pine session 的单一独立 stream。 |
| 8. 谁持有 world interaction RNG？ | Old Pine session 的另一独立、可注入 stream。 |
| 9. 玩家 body 如何交接？ | 每 Map local body；destination 绑定同一 runtime；只一个 body 在树中可控制。 |
| 10. Map timer 如何禁用？ | inactive Map 脱离 SceneTree；不 process/physics/cadence。 |
| 11. 关系如何清理？ | commit 后 explicit active-player availability reconciliation；不在 Vine transition 直接删。 |
| 12. 如何返回且不 respawn Outdoor？ | 重新挂回同一个 resident Outdoor instance，绝不 rerun initialize。 |
| 13. 条件 portal 如何选 destination？ | VineTraversalPolicy 根据 effective dodge + 独立 RNG 返回一个 selected ordinary PortalDefinition。 |
| 14. random(0) 怎么办？ | exact-stage typed legacy ambiguity；不消费 RNG、不 clamp、不默认分支。 |
| 15. 最小 Cave 是什么？ | 只有 Passage zone、vine landing、south return 与 blocked north boundary。 |
| 16. 最小 River/Cliff 是什么？ | waterfall、riverbank2/1、cliff1、cliffside 到 Pine1；lake blocked。 |
| 17. 是否提取 shared portal helper？ | 是，第二个真实 use case 已成立；只做 validation/handoff/location commit。 |
| 18. 实现前 DECISIONS 是否新增？ | 是：inactive freeze、world random invalid bound、Passage/go relationship cleanup适配。 |

## 34. 结论与实现准入

第一条实现 slice（9B3B1）可以开始，但须严格先记录第 27 节三项兼容决定，并维持以下禁止项：无 global WorldManager/Autoload、无 save DTO、无 Cave maze/NPC、无 serpent/poison、无 off-screen heartbeat、无全局 RNG、无 production shortcut。

Phase 9B3B1 的成功标准不是“能换 scene”，而是：同一个 player/domain/item authority 在两个 resident Map scenes 间交接，Outdoor 的死亡、尸体、loot 与 NPC state 往返后保持原样，且 inactive Map 完全不参与 physics/input/cadence。

## 检查清单

### Authoritative LPC

- `reference/es2/mudlib/d/oldpine/epath2.c`
- `reference/es2/mudlib/d/oldpine/epath3.c`
- `reference/es2/mudlib/d/oldpine/passage.c`
- `reference/es2/mudlib/d/oldpine/waterfall.c`
- `reference/es2/mudlib/d/oldpine/riverbank1.c`
- `reference/es2/mudlib/d/oldpine/riverbank2.c`
- `reference/es2/mudlib/d/oldpine/cliff1.c`
- `reference/es2/mudlib/d/oldpine/cliffside.c`
- `reference/es2/mudlib/d/oldpine/cliffdown.c`
- `reference/es2/mudlib/d/oldpine/cliff2.c`
- `reference/es2/mudlib/feature/move.c`
- `reference/es2/mudlib/cmds/std/go.c`
- `reference/es2/mudlib/doc/efuns/random`

### Native ownership/API

- `game/core/skills/character_skill_state.gd`
- `game/runtime/characters/world_player_runtime_state.gd`
- `game/core/npcs/npc_runtime_state.gd`
- `game/runtime/world/map_character_runtime_state.gd`
- `game/core/world/world_location_state.gd`
- `game/core/world/portal_definition.gd`
- `game/runtime/world/oldpine_portal_traversal_adapter.gd`
- `game/runtime/world/world_spawn_marker_2d.gd`
- `game/runtime/world/world_character_body_2d.gd`
- `game/core/inventory/inventory_state.gd`
- `game/core/inventory/containment_endpoint.gd`
- `game/core/items/combined/combined_stack_collection.gd`
- `game/runtime/world/world_item_instance_index.gd`
- `game/core/corpses/corpse_state.gd`
- `game/core/combat/relationship/combat_opponent_selection_service.gd`
- `game/core/combat/relationship/combat_relationship_state.gd`
- `game/runtime/combat_slice/combat_slice_projection_builder.gd`
- `game/runtime/world/oldpine_outdoor_controller.gd`
- `game/data/oldpine/oldpine_world_definitions.gd`
- `game/scenes/world/oldpine/oldpine_outdoor.tscn`（Godot MCP 只读层级/属性检查）
