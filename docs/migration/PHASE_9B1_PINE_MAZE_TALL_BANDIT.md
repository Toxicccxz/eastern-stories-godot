# Phase 9B1：固定松林迷宫与高瘦土匪内容扩张

状态：**FORMALLY CLOSED**

本阶段只扩张 Old Pine 的可玩内容：在现有 `oldpine.outdoor` 场景中加入固定连续松林、三个逻辑战斗区域、一名 `tall_bandit`，并复用已关闭的 aggression、ordinary combat、death/corpse、loot、inventory 与 equipment 链路。没有修改 Character、Skill、Inventory、Equipment、Combined Stack、Armor、Combat 或 Corpse Core。

## 范围与翻译决定

`DECISIONS.md` 已在场景创作前记录两项兼容性决定：

1. **Old Pine Outdoor 直接连接 Pine Maze**：LPC 中当前已实现 Outdoor 与 `pine1` 没有普通直连；原路线依赖 `epath2` vine → Cave/Waterfall → River/Cliff → `cliffside` → `pine1`。原生地图以一个双向、连续步行的 Outdoor ↔ Pine Entrance 门槛提前连接两片内容；它不是 `PortalDefinition`，也不伪称 LPC exit。
2. **随机 Pine room exits 转为固定连续迷宫**：保留迷向、相似岔路、遮挡、循环、死路、可靠主路线与可靠返回路；不实现 ROOM 图解释器、reset-time topology mutation 或 navigation RNG。

这两项决定依据 `d/oldpine/epath2.c`、`passage.c`、`waterfall.c`、`riverbank1.c`、`cliff1.c`、`cliffside.c`、`pine1.c` 以及 `pine1.c` 至 `pine7.c`、`cliffdown.c`。

## Legacy room 覆盖与原生区域

八个 legacy room reference 各出现一次：

| 原生区域 / combat location | legacy metadata |
|---|---|
| `oldpine.outdoor.pine_entrance` | `d/oldpine/pine1.c`, `pine2.c` |
| `oldpine.outdoor.pine_deep` | `d/oldpine/pine3.c`, `pine4.c`, `pine5.c`, `pine6.c` |
| `oldpine.outdoor.pine_cliff_edge` | `d/oldpine/pine7.c`, `cliffdown.c` |

三个 zone 的 `combat_location_id` 都等于各自稳定 zone ID。Area2D 内部互不重叠，并通过现有 zone-entry adapter 更新 `WorldLocationState`。移动不更换或修改 `CharacterState`。跨 Pine zone 后，下一次既有 combat availability 会移除不同 location 的 ordinary opponent membership、保留独立 lethal marker；world controller 不直接编辑关系。

## 固定迷宫场景

`oldpine_outdoor.tscn` 由 123 个节点扩张到 **173 个持久化节点**。新增内容均是 Node2D 原型结构：ColorRect、Label、StaticBody2D、CollisionShape2D、Area2D、Marker2D 与既有 CharacterBody2D；没有 TileMapLayer、外部素材或运行时生成迷宫。

物理布局包含：

- 现有 Outdoor 到 Pine Entrance 的 120 像素双向通道；
- Entrance、Deep、Cliff Edge 三片连续、无未分配普通通路间隙的区域；
- 中央树岛形成可走的南、北两条分支和实际循环；
- 两道相似树墙形成可进入、可返回的误导死路；
- 固定主路线贯通 entrance → deep → cliff edge，并可原路返回 Outdoor；
- Pine-side Keep 路径标记可到达，但由北边界碰撞封闭；
- `pine7/cliffdown` 端可到达，但由西侧悬崖边界碰撞封闭，不提供 `climb down → cliff2`；
- Camera2D 左边界仅扩展到 `-2100`，其余范围不变。

固定连通性借鉴 LPC 的 `pine1 → pine4 → pine5 → pine6 → pine7 → cliffdown` 骨架，以及 `pine2 → keep1` 未来边界；物理方向没有机械复制文本指令的 compass direction。

## Tall Bandit authored content

`OldPineNpcDefinitions.tall_bandit_definition()` 精确保存 `d/oldpine/npc/tall_bandit.c` 的 gameplay facts：

- ID `oldpine.npc.tall_bandit`，显示名“土匪”，alias `bandit`；
- human、男性、27 岁、combat exp 900、score 100、aggressive；
- raw skills：sword 15、parry 15、dodge 10；
- long sword ×1，`WIELD_PRIMARY`；silver ×6；
- 无 authored base attribute/resource override、apply modifier、combat/death/reinforcement/spell hook。

初始化继续经过 `NpcCharacterStateFactory` 的关闭 human 路径。年龄 27 为 authored 值，不消费年龄随机数；缺省八属性仍按 str/cor/int/spi/cps/per/con/kar 顺序各消费一次 `NpcInitializationRandomSource.random(21)`。测试用独立脚本流确认八次 draw、age-27 的 gin/kee/sen `220/220/100`，以及既有 strength-based body weight/maximum encumbrance。没有 tall-specific 公式或 RNG。

## Spawn、武器、货币与 map-local wiring

`OldPineSpawnDefinitions.pine1_tall_bandit_spawn()` 表示 `pine1` 中 exact quantity 1，并由稳定 ID `oldpine.outdoor.pine_entrance.pine1.tall_bandit.1` 精确解析到一个持久化 `WorldSpawnMarker2D`。runtime 在首次 combat opportunity 前已位于 Pine Entrance；没有 fallback 坐标、respawn、return_home 或 room reset。

Tall Bandit 复用现有 NPC CharacterBody2D 与 `aggressive_on_player_presence` adapter，按既有 explicit insertion 顺序排在三名 south-slope bandit 后。场景仍只有一个 map-local `OpportunityTimer`。远处 idle tall 不消费 Combat RNG；进入 Presence 后仍执行 pending → deferred live recheck → lethal initiation，离开 zone 后的 recheck 会取消，返回后可按同一 authored rule 再次评估。

长剑只有一个 canonical native definition ID `es2:d/oldpine/obj/long_sword`，同时保留 `d/oldpine/obj/long_sword.c` 与 `d/oldpine/npc/obj/long_sword.c` source metadata。Tall 拥有独立 live `ItemInstance`，主手为 real `EquippedWeaponRef`；world participant 使用窄的 tall content profile，skill `sword`、damage 25。没有泛化 universal NPC equipment resolver。

正式审计发现 `OldPineNpcDefinitions` 仍复制了一组 Tall 专用长剑 weight/damage 常量。审计已移除该重复事实：NPC loadout 与 runtime combat profile 现在都从 `OldPineItemContentDefinitions.long_sword()` 投影 ID、weight、skill type、flags、damage 与双 LPC source metadata；实际装备存活性仍由当前 InventoryState/EquipmentState 验证。

银子仍是一件 combined stack instance：amount 6、base weight 37、live weight 222、base value 100、live value 600。长剑和银子都进入现有 map-local `WorldItemInstanceIndex`；index 仍只保存 presentation/lookup metadata。

## Combat、死亡、尸体与 loot loop

实际场景测试覆盖：physical tall Presence → authored aggression → ordinary long-sword combat → unconscious/death lifecycle → `DEATH_COMPLETE` corpse。DeathContext 从 live tall runtime 读取显示名、gender、age 27、当前 derived body facts、EquipmentState、ArmorState 与 Pine world endpoint，没有 bandit/demo 常量。

死亡通过既有 transfer 自动卸下同一把长剑，并把它与 amount-6 的同一 silver association 移入 corpse。现有 Open Loot 投影显示“长剑”和“银子 ×6”；两个 exact instance 经既有 corpse-aware Take 成为 player direct inventory。测试随后卸下玩家原长剑并 wield loot long sword，下一份 combat participant projection 仍返回 damage 25。没有新 Loot/Inventory/Equipment UI 或 Pine 专用物品路径。

既有三名 `bandit` 的 short sword、silver ×3、corpse、Take、Inventory、Wield/Unwield 与 dynamic long/short combat content 回归保持通过。Fresh scene 会恢复三名原 bandit 和一名 Pine tall、全新 item instances、tall silver ×6、零 corpse、零 stale target/关系以及唯一持久化 signals；固定几何不受 reset 影响。

## Godot AI / MCP

场景创作使用正在运行的 Godot **4.7.2-stable Steam** MCP 会话完成：先检查原 123-node hierarchy 与 viewport，停止运行项目，扩张 terrain/collision/zone/spawn/body/presence/camera，校正 duplicated node 的 signals，保存场景；随后从脚本符号表确认新 zone/tall callbacks，并读取持久化层级为 173 nodes。最终验证阶段再次执行 save → force reload → hierarchy/signal inspection，并启动实际 main scene。

## Source partial-parity ledger

| 内容 | 状态 | 说明 |
|---|---|---|
| `tall_bandit` definition | COMPLETE | 精确 authored facts，无虚构 override/hook |
| `tall_bandit` placement | COMPLETE | pine1 ×1 → Pine Entrance exact marker |
| ordinary combat | COMPLETE | real primary long sword，world projection damage 25 |
| loadout / corpse / loot | COMPLETE | same long-sword instance；silver amount 6 |
| special hook | NONE | source没有此类 hook |
| presentation | MINIMAL | 共用 body，仅 label/color 区分 |
| `fat_bandit` | DEFERRED | 等待 leather/Armor/WEAR seam |
| `wolf_dog` | BLOCKED-BY-DECISION / DEFERRED | 等待 beast defaults/action 与 kee anomaly 决定 |
| Pine geometry | COMPLETE FOR 9B1 | 固定连续迷宫替代 random ROOM exits |
| Pine random-exit runtime | INTENTIONALLY TRANSLATED | 依 `DECISIONS.md`，无 runtime RNG |
| wolf placement | DEFERRED | 不在本阶段 |
| Keep traversal | DEFERRED | 可达但封闭边界 |
| cliff/River traversal | DEFERRED | 可达但封闭边界；无 cliff2 teleport |

## 直接检查的 LPC

- `reference/es2/mudlib/d/oldpine/pine1.c`
- `reference/es2/mudlib/d/oldpine/pine2.c`
- `reference/es2/mudlib/d/oldpine/pine3.c`
- `reference/es2/mudlib/d/oldpine/pine4.c`
- `reference/es2/mudlib/d/oldpine/pine5.c`
- `reference/es2/mudlib/d/oldpine/pine6.c`
- `reference/es2/mudlib/d/oldpine/pine7.c`
- `reference/es2/mudlib/d/oldpine/cliffdown.c`
- `reference/es2/mudlib/d/oldpine/npc/tall_bandit.c`
- `reference/es2/mudlib/d/oldpine/obj/long_sword.c`
- `reference/es2/mudlib/d/oldpine/npc/obj/long_sword.c`
- `reference/es2/mudlib/obj/money/silver.c`
- `reference/es2/mudlib/std/money.c`

连接拓扑决定还引用 `d/oldpine/epath2.c`、`passage.c`、`waterfall.c`、`riverbank1.c`、`cliff1.c`、`cliffside.c`；human 初始化沿用此前关闭且本阶段复核的 `adm/daemons/race/human.c`。没有读取或采用外部 Eastern Stories port。

## 验证与明确延期

Phase 9B1 focused runner 包含 Phase 9B1、8B2、8B1、7B3、7B2、7B1、6B1/B2/B3、相关 ordinary combat、NPC、Equipment、Inventory 与 Combined Stack tests，并以封闭回归在前、Phase 9B1 物理验证在后的顺序证明测试隔离，结果为 **4135 assertions PASS**。完整项目套件最终结果为 **7649 assertions PASS**。

完整 runner 首次暴露 Phase 6B2/6B3 reset tests 遗留 `SceneTree.current_scene` 的测试清理缺陷：旧 CombatVerticalSlice Arena 碰撞体会与随后实例化的 Old Pine 场景共存。只修正测试 teardown，显式 `unload_current_scene()` 并等待 process/physics frame；未修改任何封闭生产 Core。修正后的 focused 与 complete runner 均通过。

Godot 4.7.2 正式验证包括：无头 editor load、显式 Old Pine scene、main scene 均退出码 0；Godot AI 对场景执行 save → force reload 后仍读取 **173 nodes**，三个 Pine zone、Tall body/marker/presence、Camera limits 与每条新增 signal 都持久化且各连接一次。MCP main launch 确认编辑器实际进入 playing 状态并可正常 stop，当前 run 未产生新错误；game helper 未在等待窗内连接，因此运行时正确性同时由独立 headless main/scene smoke 与完整测试证明。

正式审计结论：**Phase 9B1 已关闭，第一段 authored Pine content-expansion slice 已关闭。** 这不表示完整 Pine source parity；后续内容仍按下述 ledger 与明确延期处理。

明确延期：fat bandit、leather/Armor/WEAR、wolf dog/beast、Keep traversal、cliff/River/Cave/vine、runtime randomized maze、Phase 5B4 hooks、new gameplay UI、TileMapLayer、最终 art/VFX/audio、追击/导航/仇恨记忆。Pine geometry 不等于完整 legacy random-exit parity，八个 room ID 只作为 authored trace metadata。
