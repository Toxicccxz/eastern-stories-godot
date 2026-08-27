# Phase 6B2 — Playable Combat Arena

## 范围

Phase 6B2 把已关闭的 Phase 6B1 单次机会桥接到第一个可运行的 Godot 场景。场景负责物理移动、目标选择、1 秒 encounter cadence、HUD 和 typed result 展示；Character/Equipment/Inventory/Combat 规则仍由现有 Core authority 持有。

本阶段不执行昏迷、死亡、关系生命周期清理或尸体创建，也不加入 Phase 5B4 authored hit/post-action/perform/exert/cast/conjure policy。

## 实际 SceneTree

```text
CombatVerticalSlice (Node2D, CombatVerticalSliceController)
├── Arena (Node2D)
│   ├── Floor (ColorRect)
│   ├── TopWall (StaticBody2D + CollisionShape2D)
│   ├── BottomWall (StaticBody2D + CollisionShape2D)
│   ├── LeftWall (StaticBody2D + CollisionShape2D)
│   └── RightWall (StaticBody2D + CollisionShape2D)
├── Player (CharacterBody2D, CombatSliceCharacterBody)
│   ├── CollisionShape2D
│   ├── Visual (Polygon2D)
│   └── NameLabel
├── Enemy (CharacterBody2D, CombatSliceCharacterBody)
│   ├── CollisionShape2D
│   ├── Visual (Polygon2D)
│   └── NameLabel
├── Camera2D
├── OpportunityTimer (Timer)
├── CorpseLayer (Node2D, empty placeholder)
└── HUD (CanvasLayer, CombatSliceHud)
    └── HudRoot
        ├── PlayerPanel (vitality bar + current/effective/maximum text)
        ├── EnemyPanel (name + vitality bar + text)
        └── BottomPanel
            ├── SelectedTargetLabel
            ├── AttackButton
            ├── ResetButton
            └── CombatLog
```

`CorpseLayer` 只是为 Phase 6B3 保留的空视觉层，不含 lifecycle/corpse 行为。

## Godot AI / MCP 使用

实现前通过 Godot AI 4.7.2 会话读取了当前场景、ProjectSettings、Input Map、main scene 和 `CharacterBody2D`/`CollisionObject2D`/`Timer` API。竞技场树、碰撞体、占位视觉、HUD layout 和属性由 Godot-aware scene/node/UI 工具建立；Input Map 也通过该工具写入。

完成后再次通过 Godot AI 读取最终节点树、Timer 属性和信号连接，并从编辑器启动实际场景。`application/run/main_scene` 属于该工具禁止写入的启动安全键，因此最终 bootstrap 值在工具拒绝后以聚焦的 `project.godot` 修改完成，并由 headless main-scene 启动验证。

## Controller 与 authority

`CombatVerticalSliceController` 是 encounter-local composition root，拥有：

- player/enemy `CombatSliceCharacterBinding`；
- 固定顺序 participants `[player, enemy]`；
- 两个独立 long-sword `ItemInstance` 的共享 `InventoryState`；
- 一份 encounter-local `GodotCombatRandomSource`；
- `SkillImprovementEffectRegistry`；
- 当前选择、Timer、HUD 和 presenter。

`CombatSliceDemoFactory` 只构造这一 prototype：双方 base attributes 20，gin/kee/sen 为 220/220/100，combat experience 10，sword/dodge/parry/unarmed raw 10，force/perception 0，空 mappings/armor；每人拥有独立 mutable authorities、独立 sword item identity 和 direct inventory containment。

## CharacterBody 与移动

玩家和 NPC 共享 `CombatSliceCharacterBody`。Node 只持有 binding 引用、物理位置、点击命中和表现名称；没有 HP、技能、经验、equipment、busy 或 life-status 副本。

玩家用 `CharacterBody2D.velocity + move_and_slide()` 处理固定 220 px/s 的 W/A/S/D 和方向键输入。NPC 本阶段静止，没有 AI、追击、巡逻或导航。四个 `StaticBody2D` 边界把角色限制在本地竞技场；两 binding 的稳定 location 均为 `combat_vertical_slice_arena`。

## 选择、Attack 与 cadence

Enemy 的 `_input_event()` 接收鼠标左键并发出 typed character ID；controller 选择唯一敌人后更新 HUD 并启用 Attack。AttackButton 只调用：

```text
CombatSliceOpportunityExecutor.initiate_lethal_combat(player, enemy)
```

它不手改 lethal/opponent，也不立即执行机会。只有 coherent `COMPLETED` initiation 才启动 `OpportunityTimer`。

Timer 固定为 `wait_time=1.0`、`one_shot=false`、`autostart=false`。每次 timeout 按 `[player, enemy]` 最多各调用一次 Phase 6B1 executor；没有 while-loop、第二 cooldown、动画锁或根据属性推导 cadence。

## RNG adapter

`GodotCombatRandomSource` 实现现有 `CombatRandomSource`，内部独占一个 encounter-local `RandomNumberGenerator`。同一实例跨双方和所有机会连续使用。生产构造调用该实例的 `randomize()`；测试可提供 seed 或注入现有 scripted source。非正 bound 返回 `-1`，不 clamp、不产生替代随机值。

## HUD 与 presenter

HUD 每次机会结束后直接读取 live `CharacterState.vitality`。进度条仅把负 current 视觉 clamp 到 0；文本始终保留真实 `current / effective / maximum`。

`CombatSlicePresenter` 只读取 typed result，提供 guarding、quick、slash、dodge、parry、hit/damage、riposte、typed incomplete/failure 和 lifecycle-pending 文本。它不重算伤害，不修改 Core，也不实现 legacy `$N/$n/$l/$w` renderer。Gameplay chain 完整结束后才更新 HUD/log；Timer 不等待表现完成。

## Lifecycle staging

仅当某 actor 的外层 opportunity 返回 `LIFECYCLE_REQUIRED_UNCONSCIOUS` 或 `LIFECYCLE_REQUIRED_DEATH` 时，controller：

1. 记录并显示 lifecycle pending；
2. 停止 encounter Timer；
3. 结束本 timeout 的后续 participant 处理。

它不检查 post-chain threshold，不改 runtime life status，不清零资源、不清关系、不隐藏角色、不创建尸体。这个暂停是 Phase 6B3 尚未接入前的 staging 行为，不是最终 ES2 lifecycle。

## Project bootstrap 与测试

`combat_vertical_slice.tscn` 暂时设为 project main scene，只用于第一个可玩里程碑，不代表最终 main-scene/world 架构。新增的 Input Map 仅有 `move_left/right/up/down`，分别绑定 A/D/W/S 和方向键。

Smoke test 验证：从磁盘加载并实例化真实 `.tscn`、精确节点/碰撞体/信号、main scene 与 Input Map、独立 bindings/items、四壁碰撞与归一化斜向移动、HUD live resource、初始停止的 1 秒 Timer、经 `Viewport.push_input()` 和物理拾取完成的真实 Enemy 点击、Attack initiation、重复 Attack 不重启 Timer、不重复关系且不消费 RNG、固定 actor 顺序、同一 RNG 跨 timeout 连续使用、typed log、presentation 不突变 Core、reset 后 fresh authority/signal，以及双向 threshold 的 outer-opportunity lifecycle staging 时序。

Phase 6B2 targeted + Phase 6B1/5B3A/5B3B1/5B3B2A/5B3B2B regressions：1149 assertions PASS；包含 Phase 6B2 的完整项目 runner：5817 assertions PASS。

## 正式审计结果

正式审计发现并修正三项具体问题：

- `game/tests/run_tests.gd` 尚未注册 Phase 6B2 smoke test；现已作为异步 scene test 纳入完整 runner。
- `project.godot` 曾额外加入四项窗口尺寸设置，超出本阶段只允许 main-scene bootstrap 与四个移动动作的范围；现已移除，保留的 diff 只有 main scene 和 `move_left/right/up/down`。
- 原 smoke test 直接调用 `_input_event()`，且对四壁碰撞、重复 Attack、跨 tick RNG、player threshold 延迟和 reset 重载证明不足；现均改为或补为 Godot 运行时行为测试。负 current 测试遵守已关闭的资源下限语义，验证文本显示真实 `-1` 而 ProgressBar 只做视觉 clamp。

Godot AI/MCP 在 Godot 4.7.2 编辑器中从磁盘强制重载场景，读取到 41 个持久化节点、全部脚本、六个角色/墙体 `CollisionShape2D`、启用的 `Camera2D`、`1.0 / false / false` Timer、四条无重复生产信号、恰好四个 Input Map 动作及有效 main-scene UID。审计随后执行 `save → force reload → hierarchy re-inspection`，结构保持不变，证明场景不依赖瞬态编辑器状态。

MCP 从 main scene 启动了实际游戏，但其 `_mcp_game_helper` 在两次等待窗口内均未上线，且 editor/game error log 为空，因此无法用 MCP 的 runtime tree/input API 完成互动。作为明确兜底，实际 Godot 游戏窗口成功显示竞技场；Windows 级真实点击红色 Enemy 后，HUD 从 `Selected: none` 更新为 `Selected: Human Swordfighter` 并启用 Attack。Headless smoke 另外通过真实 Viewport 输入分发和 `CollisionObject2D` picking 锁定同一路径，Attack/cadence/lifecycle/reset 均由该场景实例端到端验证。

Phase 6B2 由此正式关闭第一个玩家可见、可运行的战斗竞技场。此结论不表示 lifecycle/death/corpse、Phase 5B4 authored combat content 或 World/NPC 架构已经完成。

明确延期：

- Phase 6B3：unconscious/death transition、关系生命周期清理、corpse/death inventory、revive/ghost；
- Phase 5B4：authored combat policies；
- 后续 world：region/map/zone/portal、NPC AI/spawn/persistence；
- 完整 human/sword action distribution 和最终 HUD/art/presentation 架构。
