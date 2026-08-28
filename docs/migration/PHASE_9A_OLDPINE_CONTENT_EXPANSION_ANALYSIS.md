# Phase 9A：Old Pine Authored Content Expansion 依赖与优先级分析

状态：**READY FOR PHASE 9B1**
性质：**分析 / 设计契约；没有修改 production、场景、项目设置或 `reference/es2/`。**

## 1. 已正式关闭的基线

以下结论保持不变：

- Phase 7B、首个 authored Old Pine world milestone 已正式关闭；
- Phase 8B、第一条完整 RPG loot loop 已正式关闭；
- Phase 6 combat/lifecycle/death/corpse 与 Phase 4 item/inventory/equipment 基础仍是权威实现；
- 当前闭环为：探索 → 土匪主动攻击 → 普通战斗 → 昏迷/死亡 → 尸体 → 拿取短剑/银子 → 玩家物品栏 → 换主手 → 下一场战斗读取当前武器。

Phase 9A 不重开上述公式或 authority。本阶段只回答：哪一组剩余 Old Pine 内容最适合作为下一次可见扩张。

当前磁盘场景 `game/scenes/world/oldpine/oldpine_outdoor.tscn` 有 **123 个持久化节点**，Camera2D limits 为 left `0`、top `-500`、right `2300`、bottom `1100`。场景已有 Central Clearing、South Slope、North Approach、East Bridge、TreeCanopy/tree1、三名土匪、动态尸体与完整 HUD/loot/inventory 接线。依据：

- `docs/migration/PHASE_7B2_OLDPINE_OUTDOOR_PLAYABLE_MAP.md`
- `docs/migration/PHASE_7B3_OLDPINE_PORTAL_AGGRESSION.md`
- `docs/migration/PHASE_8B1_WORLD_CORPSE_LOOT_TAKE.md`
- `docs/migration/PHASE_8B2_PLAYER_INVENTORY_EQUIPMENT_COMBAT_CONTENT.md`
- `game/scenes/world/oldpine/oldpine_outdoor.tscn`
- `game/runtime/world/oldpine_outdoor_controller.gd`

## 2. 剩余 Old Pine 内容总量

Phase 7A 的扫描宇宙仍是 41 个 room、13 个 NPC 定义加一个伪装成 NPC 文件的 `skeleton` ITEM，以及 14 组独立 Old Pine item 语义。当前物理原型已用 12 个 legacy room 作为 Central/North/South/East/tree1 的内容参考；尚未物理或行为化的 unique room reference 为 **29 个**：

| 分组 | room 数 | legacy rooms | 备注 |
|---|---:|---|---|
| Pine Maze / western forest | 8 | `pine1..7`, `cliffdown` | `cliffdown` 也服务 River/Cliff 连接，候选间重叠 |
| River / Cliff / Lake | 8 | `waterfall`, `riverbank1..2`, `lake`, `cliff1`, `cliffside`, `cliffdown`, `cliff2` | `epath2/3` 几何已有，但 vine、maniac、cliff 入边未实现 |
| Cave / secret passage | 9 | `passage`, `secrectpath1`, `path3`, `stone`, `cave1..5` | 应为独立 Cave map |
| Keep | 3 | `keep1..3` | 应为独立 Keep map |
| Tree expansion | 2 | `tree2`, `tree3` | tree1 landing 已有，tree1 的 spy 尚未实现 |

五个候选的 room 计数合计 30，是因为 `cliffdown` 同时是 Pine 出口和 River/Cliff 垂直连接；不能把它算成两个 authored room。

剩余 authored character 定义为 **12 个**：`tall_bandit`、`fat_bandit`、`bandit_chief`、`bandit_guard`、`bandit_leader`、`bandit_commander`、`maniac`、`spy`、`butterfly`、`serpent`、`venomsnake`、`wolf_dog`。静态 placement 为 **28 个实例**（原总数 31 减去已实现的 bandit ×3）；另有 keep2 trap 动态 guard ×5。`bandit_chief` 没有静态 placement。

下一批 active content 依赖 11 个尚未 native 化的物件语义：`blade`、`glaive`、`leather`、`fur_coat`、`robe`、`throwing_knife`、`bamboo_pipe`、`parrybook`、`black_cloth`、外部 `/obj/dust`、`skeleton`。`long_sword`、`short_sword` 与 silver 已有 native content，可直接复用。`black_suit`、普通 `book`、`mask` 在当前 active room/NPC 链中未被使用，不应借 Phase 9 批量迁入。

来源：`reference/es2/mudlib/d/oldpine/*.c`、`d/oldpine/npc/*.c`、`d/oldpine/obj/*.c`、`d/oldpine/npc/obj/*.c`；具体文件见第 27 节。

## 3. 候选内容簇定义与边界修正

### A. Pine Maze / Western Forest

- rooms：`pine1..7`、`cliffdown`；
- 静态 NPC：pine1 的 tall + fat，pine7 的 wolf dog；
- 边界：pine2 → keep1，pine7 → cliffdown → cliff2；
- 主要体验：连续迷林、循环/迷向、两个土匪遭遇、一个兽类遭遇、Keep/悬崖的未来边界。

### B. River / Cliff / Lake Loop

- rooms：`waterfall`、`riverbank1/2`、`lake`、`cliff1`、`cliffside`、`cliffdown`、`cliff2`；
- NPC：lake 的 serpent ×5；
- 主要体验：水域/悬崖连续地形、多个 climb landing、连接 East Bridge、Pine 与 Cave 的大环。

### C. Cave / Secret Passage

- rooms：`passage`、`secrectpath1`、`path3`、`stone`、`cave1..5`；
- NPC/item：venomsnake、skeleton、概率 parrybook；
- 主要体验：跨 scene、秘密通道、洞穴迷阵、毒、bury 奖励、单向瀑布出口。

### D. Keep / Bandit Stronghold

- rooms：`keep1..3`；
- NPC：guard ×6 静态、leader ×4、commander ×1，trap 另生 guard ×5；
- 主要体验：高密度战斗、门陷阱、动态增援、boss、竹管开门与大量武器/护甲 loot。

### E. Tree Canopy Expansion

- rooms：`tree2/3`，并补 tree1 未迁移的 spy；
- NPC：butterfly ×6、spy ×1；
- 主要体验：现有 climb portal 的纵向延伸、首个和平兽类、飞刀/化尸粉/尸体溶解内容。

此外存在一个不宜独立成簇的 East Bridge 内容缺口：`epath3` 的 `maniac`。其 60% combat chat 是真实施法行为，不能用普通空手 NPC 近似，因此不构成“廉价单 NPC”候选。来源：`d/oldpine/epath3.c`、`d/oldpine/npc/maniac.c`、`std/char/npc.c`。

## 4. 剩余 room / interaction 依赖矩阵

分类：A 已关闭直接复用；B 小 content adapter；C 小新 runtime 行为；D 缺少主要系统；E 越过 Phase 5B4/special combat。

| room | cluster | native geometry | portal / interaction | dynamic / spawn | 当前支持与建议 |
|---|---|---|---|---|---|
| `pine1` | Pine | 连续迷林入口 | 无条件迷径 | tall ×1、fat ×1 | geometry B；tall A/B；fat 需 armor C |
| `pine2` | Pine | 迷林/寨门岔口 | → keep1 map boundary | 无 | geometry B；跨 Keep scene D，首切片只做边界 |
| `pine3` | Pine | 连续迷林 | 原 exit 仅 load 时随机 | 无 | fixed maze B；不模拟 ROOM random |
| `pine4` | Pine | 连续迷林 | 固定 north → pine5 | 无 | fixed route B |
| `pine5` | Pine | 连续迷林 | 固定 north → pine6 | 无 | fixed route B |
| `pine6` | Pine | 连续迷林 | 固定 west → pine7 | 无 | fixed route B |
| `pine7` | Pine | 迷林悬崖端 | southwest → cliffdown | wolf dog ×1 | geometry B；wolf D/legacy ambiguity |
| `cliffdown` | Pine/River | 悬崖边界 | `climb down` → cliff2 | 无 | same-map climb adapter A/B；首 Pine 切片只做不可穿越边界 |
| `cliffside` | River | 松林/山壁边 | 仅 north → pine1；没有源码下爬动作 | 无 | geometry B；单向异常必须保留 |
| `cliff1` | River | 狭窄 landing | up → cliffside；down → riverbank1 | 无 | 现有 typed climb/marker 可复用 A/B |
| `cliff2` | River | 狭窄 landing | up → cliffdown；down → epath3 | 无 | 现有 typed climb/marker可复用 A/B；下行单向 |
| `riverbank1` | River | 河谷可行走地表 | `climb cliff` → cliff1 | 无 | geometry/collision B；same-map portal A/B |
| `riverbank2` | River | 河谷可行走地表 | north ↔ waterfall | 无 | geometry B |
| `lake` | River | 水潭 collision/visual zone | 普通 north 出口 | serpent ×5 | scenery B；beast D；不需要游泳系统 |
| `waterfall` | River/Cave | 浅水/瀑布 landing | 接受 passage/cave5/vine 单向落点 | 无 | scenery B；跨 scene portal D |
| `epath2` | 已有 East | 当前桥面已存在 | `hold/grab vine` 条件分流 | 无 | skill/RNG policy C；成功跨 Cave scene D |
| `epath3` | 已有 East | 当前 zone 已存在 | cliff2 单向落点 | maniac ×1 | landing B；maniac spells D/E |
| `passage` | Cave | CaveMap 入口空间 | south → waterfall | 注释 maniac 不生效 | cross-scene D；无 NPC |
| `secrectpath1` | Cave | 连续通道 | passage ↔ path3 | 无 | geometry B；保留拼写 metadata |
| `path3` | Cave | 连续通道 | `climb up` → stone | 无 | portal A/B；源码成功路径缺 return 是 API 缺陷 |
| `stone` | Cave | 特殊高台 | `climb down` → cave1 | venomsnake ×1 | portal A/B；poison hit E |
| `cave1` | Cave | 洞穴迷阵 | random exits，north 固定 cave2 | 无 | fixed maze B |
| `cave2` | Cave | 洞穴迷阵 | random exits，east 固定 cave4 | 无 | fixed maze B |
| `cave3` | Cave | 洞穴迷阵 | 四向 random | 无 | fixed maze B |
| `cave4` | Cave | 洞穴迷阵 | random exits，west 固定 cave5 | 无 | fixed maze B |
| `cave5` | Cave | 洞底/reward room | eastdown → waterfall；`bury skeleton` | skeleton，概率 parrybook | portal D；bury C/D；study D |
| `keep1` | Keep | KeepMap entrance | west ↔ pine2；east ↔ keep2 | guard ×4 | cross-scene D；guard B/C |
| `keep2` | Keep | courtyard | east 时封门、生 5 guards；pipe reopen | guard ×2、leader ×1 | trap state C；动态 spawn C；gate/item C |
| `keep3` | Keep | hall | west → keep2 | leader ×3、commander ×1 | boss content C/D |
| `tree2` | Tree | tree canopy level | up/down typed climb | butterfly ×6 | portal A/B；beast D |
| `tree3` | Tree | tree top level | down → tree2 | 无 | portal A/B；geometry B |

结论：`single parent room graph` 不应复活。River/lake/waterfall 是 visual/collision zones，cliff/tree 是 typed interactions/landings，Pine/Cave 是连续迷宫几何。

## 5. 剩余 NPC special-hook 矩阵

| NPC | race | aggression | equipment | ordinary combat | special hit/death/reinforcement/spells | external dependency | 当前 native 支持 | 推荐 |
|---|---|---|---|---|---|---|---|---|
| tall_bandit | human | aggressive | long sword；silver 6 | sword 15 / parry 15 / dodge 10 | 无 | 已有 long sword/silver | 几乎完整 A；只缺 definition/spawn/body wiring | **9B1 首 NPC** |
| fat_bandit | human | aggressive | short sword；leather；silver 5 | 普通 sword | `call_for_help` 存在但正常 chat 调度不可达 | leather/Armor | human/sword/silver A；WEAR factory 缺 C | 9B2 |
| bandit_chief | human | aggressive | blade；leather；silver 30 | blade + apply attack/dodge | 只有表现型 start_help/chat；正常 reinforcement 入口不可达 | blade/Armor/modifiers | placement 无；apply facts 缺 C | 仅在产品决定修复 fat defect 后 |
| bandit_guard | human | aggressive | short sword；silver 5 | sword；bellicosity 600 | 无 | 现有 items | bellicosity definition/factory 缺 B | Keep 入口阶段 |
| bandit_leader | human | aggressive | blade；leather；silver 30 | blade；force current 1300/max 700/factor 4；apply | combat chat 仅文本 | internal resource/modifier/Armor | typed state能承载，但 NPC content/factory 未投影 C | Keep 后期 |
| bandit_commander | human | aggressive | glaive；leather；fur；pipe；silver 50 | blade；force 1500/max1000/factor3；apply | pipe 是 world gate，不是 hit hook | item-world gate | 多个 content/factory gap C/D | Keep boss阶段 |
| maniac | human | 非 aggressive | unarmed；robe | force/mana/apply | 60% combat chat 调 necromancy spells | spell mapping + casts | D/E；普通空手会严重失真 | 延期至 spell combat |
| spy | human | 非 aggressive | throwing knife ×30；black cloth；dust ×30 | throwing 20 等 | throwing post_action；killed_enemy 延迟 dissolve corpse | `/obj/dust`、corpse destruction | E + runtime death hook D | 延期 |
| butterfly | beast | peaceful | 无 | bite action；apply dodge 50，但 apply damage 未设置 | 非战斗 chat 仅表现 | beast defaults/actions | beast D；攻击时 `random(0)` 语义不明 | 不作为首兽类 |
| serpent | beast | aggressive | 无 | bite；完整 apply attack/damage/armor/dodge | 无 hit hook | beast init/action | 需 beast seam C/D；Combat Core公式足够 | 首个 source-valid beast 候选 |
| venomsnake | beast | aggressive + pursuer | 无 | bite；完整 apply | attacker `hit_ob` 施 snake_poison | Condition 已有，hook 未有 | **E / Phase5B4** | 延期 |
| wolf_dog | beast | aggressive | 无 | random bite/claw；完整 apply | combat chat 因 chance key 不匹配不可达 | beast init/action | D；并有 kee over-cap legacy anomaly | **不进 9B1** |

### 5.1 fat_bandit reinforcement 的源码纠正

`fat_bandit.c` 写入 `chat_chance = 10` 和 `chat_msg_combat`。`std/char/npc.c::chat()` 在战斗中读取 `chat_chance_combat`，非战斗中读取 `chat_msg`。仓库内没有对 `call_for_help()` 的外部调用。因此：

- `call_for_help()` 是可执行函数；
- 但正常 NPC chat 调度无法选中它；
- `bandit_chief` 也没有静态 room placement；
- 正确分类是 **unreachable authored path / likely key typo**，不是当前 executable reinforcement mechanic。

因此未来可以在补齐 leather/WEAR 后实现 fat 的实际 baseline，而不需要假装“暂缓了一个正常会发生的增援”。若产品选择把 `chat_chance` 修成 `chat_chance_combat` 并启用 chief，必须先写 `DECISIONS.md`，再实现显式 typed reinforcement intent；不能静默修复。

同类现象：`bandit_chief` 和 `wolf_dog` 的 combat message 也没有匹配的 `chat_chance_combat`；仅狼狗的非战斗 `chat_msg` 可由 `chat_chance` 到达。来源：上述三个 NPC 文件与 `reference/es2/mudlib/std/char/npc.c`。

## 6. 物件依赖矩阵

分类：A 普通兼容武器；B Armor Core 兼容；C combined 兼容；D item interaction；E study；F special combat。

| item | source facts | 分类 | 当前状态 / 缺口 |
|---|---|---|---|
| long sword | sword，damage 25，weight 7000 | A | 已实现；tall 可直接复用 |
| short sword | sword，damage 15，SECONDARY，weight 3000 | A | 已实现 |
| silver | combined currency，weight 37，value 100 | C | 已实现 |
| blade | blade，damage 25，weight 4000 | A | Combat Core 接受开放 skill ID；content/resolver 增量即可 |
| glaive | blade，damage 45，weight 20000 | A | 同上；不是新 Combat 公式 |
| leather | slot `cloth`；armor +5；因 `cloth.c` 的 key mismatch 另得 dodge -2 | B | Armor Core 可表达；NPC factory 当前拒绝 WEAR；玩家无 Wear UI |
| fur coat | slot `surcoat`；armor +8、attack +1、dodge -3 | B | Armor Core 可表达；同上 |
| robe | slot `cloth`；armor +2、spells +3 | B | Armor Core 可表达；maniac spell行为仍缺 |
| throwing knife | combined amount；base weight 300/value80；throwing damage20 | A+C+F | stack/weapon可表达；每次 action 的 throw post_action 未实现 |
| bamboo pipe | weight100；play/blow 调当前 room `pipe_notify()` | D | 未来 explicit item action → KeepGatePolicy；禁止字符串 dispatch |
| parrybook | parry；exp 15000；sen cost30；difficulty25；max50 | E | `study` 尚未迁移；当前拿到也不能有意义使用 |
| black cloth | slot cloth；armor/dodge +1、personality -1 | B | Armor Core 可表达；spy 仍被 throwing/death hook 阻塞 |
| `/obj/dust` | combined；`dissolve corpse` 后 amount -1 | C+D | 外部内容 + corpse destruction action；不为 spy 偷渡通用 item verbs |
| skeleton | ITEM，weight3500，`no_get`；bury target | D | ITEM target可复用，仍需 source-specific bury policy |

`blade` / `glaive` 不要求修改 Combat Core。`std/weapon/blade.c` 的 verbs 首项是 `slash`，当前 typed action/profile 可以表达普通 slash 与开放 `blade` skill；缺的是 Old Pine content registration、NPC current-primary resolution 与每 NPC modifier facts。来源：`std/weapon/blade.c`、`adm/daemons/weapond.c`、`game/core/combat/action/*`、`combat_slice_content_profile.gd`。

## 7. 既有系统复用矩阵

| dependency | Pine | River/Cliff | Cave | Keep | Tree |
|---|---|---|---|---|---|
| human NPC initialization | A（tall/fat） | — | — | A（guards/leaders） | A（spy） |
| aggression/fight/lifecycle/corpse | A | A（serpent） | A（venom baseline） | A | A（若主动攻击） |
| sword/loot/currency/inventory/equipment | A | — | — | A | A/C（throwing stack） |
| map-local spawn | A | A | A | A；trap dynamic spawn 为 C | A |
| same-map typed portal | B（边界） | A/B（cliff） | A/B（内部 climb） | B | A/B |
| cross-scene state-preserving portal | — | D（source-faithful入口会触及 passage） | D | D | — |
| armor Core | A；factory/UI 为 C | — | — | A；factory/UI 为 C | A；factory/UI 为 C |
| beast initialization/action/modifiers | D（wolf） | D（serpent） | D（venom） | — | D（butterfly） |
| conditional skill/RNG portal | — | C/D（vine入口） | C/D | — | — |
| Phase5B4 combat hook | 无（正常 fat hook不可达） | 无 | **E（venom poison）** | 无必需 hit hook；boss facts仍缺 | **E（throw post_action）** |
| authored runtime special | fixed-maze decision B/C | access/topology C/D | bury/study C/D | trap/gate C | spy corpse dissolve D |

粗略复用比例只用于排序，不是代码度量：完整 Pine 候选约 **70%**，River/Cliff 约 **50%**，Cave 约 **35%**，Keep 约 **45%**，Tree 约 **40%**。把 Pine 第一切片收窄为 fixed maze + tall 后，复用可达约 **90%**：无需新 Core、Armor、beast、Phase5B4 或新 UI。

## 8. Pine Maze native 设计

### 8.1 空间与连接

`pine1..7` 不是七个 Godot room。建议在现有 Outdoor scene 扩出一个连续迷林地形，保留三类空间线索：

1. pine1/2：入口与 Keep 分叉；
2. pine3..6：核心循环、遮挡、相似路径和死端；
3. pine7/cliffdown：悬崖出口与 future cliff landing。

源码中可作为固定可达骨架的边是 pine1 west→pine4、pine4 north→pine5、pine5 north→pine6、pine6 west→pine7、pine7 southwest→cliffdown；pine2 east→keep1 是 future portal boundary。其余随机边的目的不是产生珍贵的离散拓扑数据，而是制造迷失/循环体验。来源：`d/oldpine/pine1..7.c`、`cliffdown.c`。

重要拓扑事实：原 LPC 图没有从当前 Central/North 区直接进入 pine1 的普通边。source-faithful 路径要经过 epath2 vine → passage/waterfall → river/cliff → cliffside → pine1；另一侧 cliffdown → cliff2 → epath3 是单向下行。若 9B1 从当前 North/West 边界直接开放 Pine Maze，这是 RPG 物理世界聚合导致的**可观察拓扑替换**，必须在实现前写 `DECISIONS.md`，不能伪称是原出口。

本分析仍推荐该替换，因为：

- AGENTS.md 已明确 legacy rooms 是 topology/content reference，不是物理 room graph；
- 等到 vine、CaveMap 跨 scene、River/Cliff 全部完成才允许进入 Pine，会把低依赖内容绑在三个高依赖系统后面；
- Pine/Keep/cliff 的真实边界、迷失体验、NPC placement 与 legacy IDs 仍可保留；
- 新连接只是 RPG 地理整合，不创建 ROOM exit simulator。

### 8.2 Random maze recommendation

选择 **C：先用固定 authored geometry 证明内容**，其设计目标是 loops、相似视觉、遮挡、分叉、至少一条可靠主路径和可返回路线。暂不加入 runtime maze randomization。

- 不实现 LPC exit table simulator；
- 不在 reset 时交换 Area2D/portal；
- 不用 RNG 改写导航拓扑；
- 未来若固定迷宫无法产生足够“迷失”体验，再以独立产品需求评估轻量空间变化。

随机 exits → 固定连续迷宫是可观察替换，9B1 应新增 `DECISIONS.md` 条目。`pine3` 只在 load 时抽 exits、其余多数在 reset 重抽的差异在固定 RPG 空间中不应假装保留。

### 8.3 Combat-location granularity

不建议整个 PineMaze 共用一个 combat location。当前没有 chase/nav；若整片迷林共用一个 ID，玩家跑到地图另一端后双方仍会远程执行 cadence attack。

建议三个稳定 combat locations：

- Pine Entrance：pine1/2；tall/fat placement；
- Pine Deep：pine3..6；
- Pine Cliff Edge：pine7/cliffdown；wolf placement（延期）。

这可以通过新增三个 `ZoneDefinition` 或等价的三个 typed subzone 实现；不要让 Combat Core读取物理距离。Area2D 只提交新的 `WorldLocationState`，既有 same-location cleanup 继续工作。

### 8.4 TileMap / art

9B1 继续使用 **plain Node2D placeholder geometry**。理由：现有 123-node prototype 尚未稳定最终地形比例；现在切换 TileMapLayer 会同时承担工具迁移与内容迁移，却没有 final tileset。新增 terrain、StaticBody2D collision、Area2D subzones、Marker2D 与 labels 足够验证迷宫体验。

当 Outdoor 的 Central/Pine/River 三大连续区布局稳定、需要重复地表绘制和统一 collision painting 时，再整体评估 TileMapLayer；不建议只让新 Pine 使用一个孤立 TileMapLayer。最终 sprites/tiles/UI skin/VFX/audio 继续延期。

## 9. 第一 NPC：tall_bandit

`tall_bandit.c` 的完整 gameplay facts：男性、27 岁、combat_exp 900、score 100、aggressive、sword/parry 15、dodge 10、长剑主手、silver 6，无 authored attribute/resource/apply override、无 hook。

当前系统已覆盖：

- human random defaults 和 derived resources；
- aggressive presence；
- sword ordinary combat；
- long sword definition/profile；
- combined silver；
- inventory/equipment/death/corpse/loot/player inventory；
- map-local spawn 与 deterministic NPC initialization RNG。

只需 authored definition、spawn/marker/body 和把已有 long-sword/silver content 暴露给 NPC loadout。无需新 Core 行为。它是下一阶段最便宜且最完整的 NPC。

来源：`d/oldpine/npc/tall_bandit.c`、`d/oldpine/npc/obj/long_sword.c`、`obj/money/silver.c`、`adm/daemons/race/human.c`。

## 10. fat_bandit 与 Armor loadout

fat 的普通来源事实为：男性36、exp500、score80、aggressive、sword20、parry/dodge10、短剑、皮衣、silver5。由于第 5.1 节的 chat key defect，正常 executable path 不会产生 chief；真正缺口只有 armor loadout 与 content。

当前 `NpcLoadoutEntry` 已有 `WEAR` intent，但 `NpcCharacterStateFactory._apply_loadout()` 明确遇到 WEAR 就失败；`NpcLoadoutItemDefinition` 也没有 `ArmorDefinition`。与此同时 `ArmorService`/`ArmorState` 已能按 direct ownership、open slot ID 和 typed modifiers 完成 wear。结论：

- Armor Core 不缺；
- 缺的是 NPC construction composition 和 authored armor projection；
- 不能说当前 factory 已支持 NPC armor；
- leather 还必须保留 `armor +5` 与源码 setup 实际产生的 `dodge -2`。

本分析选择：**9B1 不带 fat；9B2 同时增加 NPC armor loadout、fat/leather 和玩家 Wear/Remove 的最小 UI/adapter。** 这样不会在首个新 loot 中留下只能拿取却不能装备的护甲，也立即为 chief/leader/commander/maniac/spy 提供复用。若实现计划刻意先只完成 NPC armor，leather 可以合法 Take/Inspect 但不能 Wear；这不是规则错误，但不是首选可见里程碑。

来源：`d/oldpine/npc/fat_bandit.c`、`d/oldpine/obj/leather.c`、`std/armor/cloth.c`、`feature/equip.c`、`game/core/npcs/npc_character_state_factory.gd`、`game/core/armor/*`。

## 11. Beast-support 分析与 wolf dog 结论

当前 factory 只接受 `race_id == human`。完整 beast 还需要：

- `race/beast.c` 的缺省 attribute、age、max gin/kee/sen、body weight；
- authored limbs；
- verbs → ordered beast action set；
- typed apply attack/damage/armor/dodge facts；
- beast-specific content profile，而不是 human limbs/punch；
- 独立 deterministic initialization draws。

这些是 narrow content/factory/projection seam，不要求修改普通 Combat 数学。`serpent` 的 bite action、完整正 apply facts 与显式 maxima，理论上可由现有 Combat Core表达；缺的是输入生产者。

但是 wolf dog 还有独立 legacy anomaly：age 4 令 beast default `max_kee = 50`，而 NPC 在 setup 前显式写 `kee = 200`、`eff_kee = 200`。LPC 最终保留 current/effective 200 > maximum 50；当前 closed `CharacterResourceState` 有 `current <= effective <= maximum` invariant，会 clamp 到 50。不能静默把 max 提到 200，也不能为 wolf 重开 Phase 1 invariant。

**明确建议：9B1 不包含 wolf dog；下一内容切片不要求 beast support。** 第一兽类支持应作为单独的、以合法 source state（优先 serpent）证明的切片；wolf 等到兼容性决定明确后再进入。该选择牺牲 pine7 的一个 placement，但避免用一只 NPC 偷渡 race/action/modifier 和 resource-model 决策。

butterfly 也不是更干净的首兽类：它没有设置 apply damage，若被攻击后反击会到达 `random(0)`，随附 MudOS `random` 文档只定义正上界 `[0..n-1]`，没有证明 n=0 行为。

来源：`adm/daemons/race/beast.c`、`include/race/beast.h`、`adm/daemons/chard.c`、`d/oldpine/npc/wolf_dog.c`、`butterfly.c`、`serpent.c`、`game/core/characters/character_resource_state.gd`。

## 12. River / Cliff / Lake 分析

这组内容在物理表达上并不需要 swimming/falling simulator：

- river/lake/waterfall：visual ground/water + collision boundaries；
- riverbank1 ↔ cliff1 ↔ cliffside 与 cliffdown ↔ cliff2 → epath3：typed climb interactions + exact Marker2D landing；
- single-way edges 继续单向；
- `cliffside.c` 描述暗示下爬但没有动作，不能补造；
- 每个落点的 logical location 仍由 zone/combat-location 提交。

现有 `OldPinePortalTraversalAdapter` 足以作为 same-map unconditional climb 的实现样例；当第二组 portal 出现时，可以提取仅覆盖“已验证 portal + marker + location commit”的共享 typed helper，但仍不需要 generic portal scripting engine。

真正成本是**入口**。当前 epath2 vine 成功去 CaveMap `passage`，失败去 Outdoor `waterfall`。要 source-faithfully开放 River，必须同时解决 conditional skill/RNG policy 和至少一个 state-preserving cross-scene passage landing；否则只能发明新的 Outdoor 入口。此成本使 River 排在 Pine 之后。

River combat location 未来至少应拆为 Waterfall/Upper Gorge 与 Lake Basin；Cliff Ledges 另有独立 ID。lake 的 serpent ×5 不能让整个 river zone 都保持远程同场战斗。

## 13. epath2 vine 精确边界

顺序为：参数必须是 vine → 表现消息 → `value = this_player()->query_skill("dodge")`（effective skill）→ `random(value) < 5` 则 waterfall，否则 passage → move。当前 `CharacterSkillState.effective_level()` 可提供值；但 World 尚无 conditional portal policy/random source，且当前 portal adapter 不执行跨 scene。

`value == 0` 时调用 `random(0)`。`reference/es2/mudlib/doc/efuns/random` 没有定义该输入；本阶段不作推断。下一 slice 不应依赖 vine。未来实现应在 exact random 位置返回 typed legacy ambiguity，或在获得 driver 证据后写明确决定，不能 clamp bound。

## 14. Cave / secret passage 分析

Cave 需要一个新 Cave scene、跨 scene state handoff、fixed cave maze、多个 portal、venomsnake hit policy、bury action、item spawn 与 parrybook study。它不是“九个简单房间”。

### Cave maze

`cave1..4` 应用固定连续洞穴 loops，保留 cave1 north→2、cave2 east→4、cave4 west→5 等可靠骨架。与 Pine 相同，先证明 fixed geometry，不做 runtime random topology。CaveMap 的 scene-authoring成本高于 Pine，因为它还要承载 passage/stone/cave5 和对 Outdoor waterfall 的单向 exits。

### Cave5 bury

精确顺序：确认同环境 skeleton → skeleton 先 move 到 void → `ikar = random(kar + 10)` → `ikar > 25` 时生成 parrybook 并留在 cave5；否则 `ikar > 20` 只显示纸片，随后玩家坠到 waterfall；其余也坠落。skeleton removal 发生在 RNG 和落点之前，不应回滚。

依赖：specific ITEM action、source-specific policy、player karma、world RNG、item spawn、cross-scene fall。`kar <= -10` 还会产生非正 random bound ambiguity。复杂度为高，不能用 generic quest engine 解决。

### Parrybook

书籍依赖 `study.c`：direct inventory、非战斗、literate、combat_exp、skill `valid_learn`、sen cost、max skill、`improve_skill`。现有 Learn/Practice/Selflearn 不等于 Study。若现在发放 parrybook，玩家只能拿取/查看，无法取得其核心奖励，因此 bury 不应先于 Study 迁移。

### Venomsnake

普通 bite 能由未来 beast profile表达，但无武器 attacker hook 还要在 `random(damage) > victim armor && snake_poison < 10` 时 apply condition 20。Phase 2B 的 snake_poison effect 已存在，但调用点正是 Phase5B4 的 condition-producing `hit_ob`。不得由 World adapter在战斗后猜测命中并绕过 ordered hook seam。

来源：`cave1..5.c`、`path3.c`、`stone.c`、`npc/venomsnake.c`、`npc/skeleton.c`、`npc/obj/parrybook.c`、`cmds/std/study.c`、`adm/daemons/combatd.c`。

## 15. Keep 分析

普通部分（geometry、guard/leader/commander placements、sword/blade/glaive、armor、silver）能大量复用现有 Core，但 authored encounter 不是普通 spawn room。

### Keep2 trap 精确顺序

`valid_leave(me, "east")` 且 keep2 west exit 仍存在时：

1. 输出表现；
2. 删除 keep2 west；
3. 如果 keep1 已加载，删除 keep1 east；
4. 顺序 `new` 5 个 guard，move 到 keep2，并逐个 `kill_ob(me)`；
5. 返回 1；外层 movement 继续把玩家移到 keep3。

`reset()` 或 `pipe_notify()` 恢复两侧出口。Native 需要一个 **KeepEncounterState / KeepGatePolicy** 级别的窄状态与 ordered spawn/combat intents；不需要通用脚本 VM。现有 SpawnDefinition/map-local collection/aggression/Combat 可执行组成部分，但不能单独表达“封门 + 生五人 + 开战 + 仍完成移动”。

### Bamboo pipe

未来最小边界是：typed item action/capability → explicit KeepGatePolicy request → typed gate result。不能复刻 `environment()->pipe_notify()` 字符串方法派发。该能力只在 Keep gate 立刻有 content payoff，Keep 之前不应预建。

### Guard / leader / commander

- guard 是 Keep 最便宜 NPC，但 `bellicosity=600` 尚未被 NpcDefinition/factory投影；
- blade/glaive ordinary attack 不要求 Combat Core变化；
- leader/commander 的 current force 可高于 max，现有 internal resource type允许，但 NPC definition/factory未承载；
- 两者没有 `map_skill("force", ...)`，所以仅设置 raw force 或 force_factor不会让 standard force `hit_ob` 自动到达；force_factor仍参与 strength/composure；
- apply attack/defense/dodge/armor 和 armor loadout需要 typed content projection；
- commander 的 pipe 是 world interaction，不是 ordinary Combat hook。

因此 minimal armed Combat 技术上能开始这些 NPC 的数值表达，但 full Keep 仍被 authored trap/gate与内容投影挡住；不应只因“Combat Core可算 blade”就提前做 boss。

来源：`keep1..3.c`、`bandit_guard.c`、`bandit_leader.c`、`bandit_commander.c`、`blade.c`、`glaive.c`、`leather.c`、`fur_coat.c`、`bamboo_pipe.c`。

## 16. Tree2 / Tree3 分析

空间成本低：沿用当前 TreeCanopy scene island，增加 tree2/tree3 levels、up/down markers 和 interactions，不需要新 map scene。但 NPC 成本不低：

- butterfly ×6 需要 beast init/actions/modifiers，且反击时有 apply damage 0 ambiguity；
- tree1 的 spy 使用 amount30 throwing weapon，标准 throw action的 `post_action` 在 dodge/parry/0/positive hit 后都会减 amount；这属于 Phase5B4；
- spy 还穿 black cloth、带外部 dust，并在 killed_enemy 后一秒尝试 dissolve corpse；这是 NPC reward/death runtime hook，不是表现文本；
- 省略 throwing/death hook 的“普通 spy”会明显误述来源；
- 把 butterfly 仅画成装饰会把可攻击的 beast NPC 改成 presentation prop，也必须标明设计差异。

所以 Tree 是“场景便宜、NPC昂贵”，排在 River之后或与其接近，但不适合作为第一个 content expansion。

来源：`tree1..3.c`、`npc/spy.c`、`npc/butterfly.c`、`obj/throwing_knife.c`、`npc/obj/black_cloth.c`、`obj/dust.c`、`adm/daemons/weapond.c`。

## 17. Phase5B4 / special-combat 边界

明确会越界的 Old Pine 内容：

| content | exact dependency | 结论 |
|---|---|---|
| venomsnake | attacker/NPC `hit_ob` → snake_poison | Phase5B4 condition-producing hit |
| spy throwing knife | action `post_action` → amount -1 / unequip at last knife | Phase5B4 weapon post-action |
| maniac | combat chat → cast three necromancy spells | spell/special-combat phase，不是普通内容 adapter |
| spy corpse dissolve | `killed_enemy` → call_out → item command/destruct corpse | future NPC reward/runtime hook |
| keep2 trap | dynamic encounter state/spawn/kill | authored world encounter，不是 Combat resolver hook |
| fat call_for_help | 正常 chat path不可达 | legacy defect；不应成为 Phase5B4理由 |

**Phase5B4 继续延期。** Tall、fat（补 Armor 后）、guard、普通 blade/glaive内容，以及 fixed Pine geometry 都不需要它。当前至少还有两个完整的人类 NPC与一大片地图能在不打开 special hook 的情况下增加，因此 content progression 尚未被 Phase5B4实质阻断。

### Quest / Dialogue 边界

下一内容簇不需要 QuestSystem 或 DialogueSystem。Pine 的 tall/fat 没有任务或对话规则；Keep gate、Cave bury 和 spy corpse dissolve 也是各自的 authored interaction / lifecycle policy，不是建立通用任务引擎的依据。Quest/Dialog 应至少继续延期至 9B1–9B3 之后；若未来内容真正出现持久任务状态或对话分支，再从那个具体 payoff 建立边界。

## 18. 候选价值评分与排序

分数是比较辅助，不是客观测量。Gain/reuse/reuse-value 越高越好；cost/risk/scene cost 越低越好。

| rank | cluster | visible gain | reuse | new-system cost | source risk | scene cost | future reuse | 最大风险 |
|---:|---|---:|---:|---:|---:|---:|---:|---|
| 1 | Pine Maze | 5 | 5（收窄 slice） | 2 | 3 | 4 | 5 | 原拓扑没有当前区直连；wolf over-cap |
| 2 | River/Cliff | 4 | 3 | 4 | 4 | 4 | 5 | vine 分流 + CaveMap/跨 scene入口 |
| 3 | Tree2/3 | 3 | 3 | 4 | 4 | 2 | 4 | butterfly beast ambiguity、spy throw/death hooks |
| 4 | Keep | 5 | 3 | 5 | 4 | 4 | 5 | trap/gate动态状态 + 高阶 NPC facts |
| 5 | Cave | 5 | 2 | 5 | 5 | 5 | cross-scene、poison hook、bury、Study 同时出现 |

完整 Pine（含 fat/wolf）复用率只有约70%；推荐的 9B1 不等于完整 Pine parity，而是以约90%复用率先交付 Pine geometry + tall。该 scope shrink 是排名成立的前提。

## 19. 推荐的下一内容簇与精确范围

**推荐：Pine Maze fixed-geometry entry/core + tall_bandit。**

### 9B1 必须包含

- legacy rooms represented：`pine1`、`pine2`、`pine3`、`pine4`、`pine5`、`pine6`、`pine7`、`cliffdown`；
- native subzones/combat locations：Pine Entrance、Pine Deep、Pine Cliff Edge；
- 一个明确记录为 RPG topology consolidation 的 current Outdoor → Pine threshold；
- pine2 的 Keep entrance boundary（不可进入）；
- cliffdown 的 cliff boundary（本切片不执行 climb）；
- tall_bandit ×1，来源 placement `pine1.c`；
- tall loadout：已存在的 long sword ×1、silver amount 6；
- 已有 aggression、combat、death、corpse、loot、inventory、wield 全链复用。

### 9B1 明确不包含

- fat_bandit、leather、bandit_chief；
- wolf dog 或任何 beast support；
- Keep scene/portal；
- cliff climb/River/Cave/vine；
- runtime random maze；
- Phase5B4、new UI、final art。

第一 NPC 的答案是 **tall_bandit**。第一切片没有新 item definition；long sword/silver 已存在，只增加 source-authored NPC loadout 和 amount。

## 20. UI、art、performance 与 data organization

### UI

当前 HUD、Inspect、Attack、Traverse、Loot、Inventory、Wield/Unwield 足够 9B1。tall 只产出 long sword/silver，不需要新按钮或面板。不要以 Pine expansion 名义做 UI work。

### Art

继续 placeholder ColorRect/Polygon2D/labels/collision。最终 art 不应阻塞 authored rules/content。值得开始替换 art 的时点是 Outdoor 的 Pine 与 River 大体布局稳定，能够一次定义复用 tileset、terrain transitions 与 collision palette 后。

### Performance

从 123 nodes、3 NPC、动态 corpse增加一片 placeholder geometry、3 个 Area 和1个 NPC，不需要 pooling、streaming、chunking、ECS或新 spawn manager。现有 scene-local cadence与map-local authorities足够。

### Data organization

`OldPineWorldDefinitions`、`OldPineNpcDefinitions`、`OldPineSpawnDefinitions`、`OldPineItemContentDefinitions` 可以安全承载 9B1。只加一个 NPC/spawn，不能据此创建 repository/catalog。未来 Keep/Cave 各自达到多个专属定义且文件明显难读时，才按 authored cluster拆 provider；map-local composition root仍显式组装。

### Godot 场景工具边界

Phase 9A 只通过场景文本与现有 runtime 代码核对 123 个持久化节点、Camera2D limits、zones/markers 和 UI 接线，未修改场景。9B1 中 Godot 场景工具只应用于：放置 placeholder terrain、collision、三个 zone Area2D、spawn/portal Marker2D 和 tall NPC body；然后 save/reload 并做可视运行验证。不应让编辑器操作生成规则、重写 typed definitions，或越过源码审核自动增加内容。

## 21. Source partial-parity tracking

推荐在迁移文档维护轻量 ledger，而不是为 bookkeeping 增加 runtime state：

| source ID | definition | placement | ordinary combat | loadout | special hook | presentation | status |
|---|---|---|---|---|---|---|---|
| `tall_bandit.c` | migrated | migrated | migrated | migrated | none | minimal | COMPLETE |
| `fat_bandit.c` | deferred | deferred | source-ready | armor deferred | unreachable defect recorded | deferred | DEFERRED |
| `wolf_dog.c` | deferred | deferred | beast deferred | none | resource anomaly recorded | deferred | BLOCKED-BY-DECISION |

每个后续 phase 文档更新该表即可。只有真正影响 runtime gate 的 capability 才进入 definition；不要添加 `migration_status` gameplay 字段。这样 future work 不会把“NPC definition存在”误认为“special hook已 parity”。

## 22. 最大三段后续 implementation slices

### Phase 9B1 — Pine Maze Geometry + Tall Bandit

固定连续迷宫、三个 combat subzones、一个 topology decision、tall ×1、long sword/silver loot、Keep/cliff边界。可见里程碑：第一次离开现有四区，进入可迷路的新林区并完成新 authored 人类遭遇。

### Phase 9B2 — NPC Armor Loadout + Fat Bandit + Leather

只补 typed armor content与NpcCharacterStateFactory WEAR composition、fat ×1、leather exact modifiers，并增加玩家最小 Wear/Remove adapter/UI使 loot可用；确认 unreachable reinforcement不被“修复”。可见里程碑：同一 pine1 area出现第二种来源准确的土匪，玩家可取得并穿戴皮衣。

### Phase 9B3 — River/Cliff Access Contract + First Traversal Segment

先做 conditional vine/cross-scene state handoff 的独立设计与最小实现，开放 passage↔waterfall和 River upper gorge/cliff landings；不同时加入 serpent、Cave maze或 poison。若 cross-scene inventory/state handoff实际需要独立分析 phase，应先分析，不能把它藏在 scene authoring 中。可见里程碑：从现有 East Bridge 通过来源动作到达 waterfall/passage，并沿河谷/悬崖走到 Pine边界。

beast support 不塞入上述第一切片。完成 9B1/9B2 后，再根据实际优先级用 source-valid serpent 建立 beast seam；wolf 先解决 over-cap决定。

## 23. 第一内容扩张 acceptance loop

```text
launch Old Pine
→ 从现有 North/West forest threshold 进入固定连续 Pine Maze
→ 在相似岔路、遮挡与 loops 中寻找可靠主路径
→ 进入 Pine Entrance combat location
→ authored tall bandit 通过既有 presence aggression 开战
→ 普通 sword combat / lifecycle / death
→ 打开尸体并拿取 long sword + silver ×6
→ 在现有 Inventory 中查看/装备长剑
→ 穿过 Pine Deep 到达 cliffdown 与 keep entrance 的封闭 future boundaries
→ 通过迷宫返回现有 Outdoor 区域，场景保持加载
```

这是一条真实玩家流程，不要求新 UI、beast、Armor、special hook 或跨 scene。

## 24. 风险表

| 风险 | cluster | likelihood | cost | mitigation / defer rule |
|---|---|---:|---:|---|
| current area 与 Pine 原图无直接边 | Pine | 高 | 中 | 9B1前写 topology decision；明确 RPG consolidation |
| fixed maze失去随机迷向感 | Pine/Cave | 中 | 中 | loops/遮挡/相似 landmarks/reachability tests；先不做 runtime random |
| 一整个 maze combat location导致远程战斗 | Pine/River | 高 | 中 | 三个 Pine combat subzones；Combat Core不看距离 |
| beast factory/action facts不完整 | Pine/River/Tree/Cave | 高 | 高 | 9B1排除beast；独立 source-valid beast slice |
| wolf kee 200/200/max50违反native invariant | Pine | 确定 | 高 | 不静默clamp/fix；先写兼容决定 |
| NPC armor loadout被误认为已支持 | Pine/Keep/Tree | 确定 | 中 | 9B2显式扩 factory/content；复用 ArmorService |
| Phase5B4 hook creep | Cave/Tree | 高 | 高 | venom/throwing明确延期；World不猜Combat结果 |
| vine导致跨scene/persistence扩张 | River/Cave | 高 | 高 | 独立contract；不先做source-inaccurate单分支 |
| keep trap被泛化为脚本VM | Keep | 中 | 高 | explicit KeepEncounterState/Policy，仅content payoff |
| scene增长诱发过早TileMap/streaming | Pine/River | 低 | 中 | Node2D prototype；测量后再决定 |
| partial NPC被误标complete | 全部 | 中 | 中 | 文档ledger分列 definition/loadout/hook |

## 25. 未来 9B1 可能修改/新增的文件（本阶段未创建）

优先扩展现有 provider/runtime：

- `game/data/oldpine/oldpine_world_definitions.gd`
- `game/data/oldpine/oldpine_npc_definitions.gd`
- `game/data/oldpine/oldpine_spawn_definitions.gd`
- `game/data/oldpine/oldpine_item_content_definitions.gd`（只需确认已存在 long/silver）
- `game/runtime/world/oldpine_outdoor_controller.gd`
- `game/scenes/world/oldpine/oldpine_outdoor.tscn`
- `game/tests/core/npc_spawn_foundation_test.gd`
- `game/tests/runtime/oldpine_pine_maze_content_test.gd`（新）
- `game/tests/runtime/oldpine_outdoor_smoke_test.gd`
- `docs/migration/PHASE_9B1_PINE_MAZE_TALL_BANDIT.md`（未来）
- `docs/migration/DECISIONS.md`（实现时记录 fixed maze 与入口 consolidation）

不建议创建 `WorldRepository`、`NpcManager`、`MazeSystem`、`PortalEngine`、behavior tree或generic action dispatcher。

## 26. 未来测试策略

### authored content

- tall exact age/gender/exp/score/aggressive/skills；
- source placement quantity 1、exact marker mapping；
- human missing fields按既有 deterministic RNG顺序初始化；
- long sword主手、silver amount6、独立 instance identity；
- 无额外 skill/apply/resource被发明。

### maze/world

- 8 legacy room IDs被正确追踪到三 subzones；
- fixed route从入口可到 Pine Deep、pine7/cliffdown boundary并能返回；
- loops/dead ends不让唯一出口不可达；
- Keep/cliff boundary不可误穿越；
- zone Area不重叠产生不确定 location；
- zone change按 typed adapter提交 exact combat_location。

### combat/loot

- tall presence aggression复用当前 gate/order；
- long sword profile是 sword/damage25；
- tall death将同一 long sword instance和silver6送入尸体；
- Take/merge/Inventory/Wield继续使用现有authority；
- 跑入另一个Pine combat subzone后由既有same-location规则清理普通opponent；
- 旧三 bandit、tree1 portal、corpse loot、换短剑后的下一战全不回归。

### deterministic / architecture

- 新 content不消费额外 global RNG；NPC-init与Combat RNG仍分离；
- 无 Phase5B4 status/provider；
- 无 Armor/beast/conditional portal/runtime maze；
- fresh scene恢复原始 placements与空corpse/loot selection。

## 27. 本阶段实际检查的来源

### Migration / native docs

- `AGENTS.md`
- `docs/migration/PHASE_7A_FIRST_WORLD_MAP_NPC_ANALYSIS.md`
- `PHASE_7B1_WORLD_NPC_SPAWN_FOUNDATION.md`
- `PHASE_7B2_OLDPINE_OUTDOOR_PLAYABLE_MAP.md`
- `PHASE_7B3_OLDPINE_PORTAL_AGGRESSION.md`
- `PHASE_8A_PLAYER_INVENTORY_LOOT_EQUIPMENT_ANALYSIS.md`
- `PHASE_8B1_WORLD_CORPSE_LOOT_TAKE.md`
- `PHASE_8B2_PLAYER_INVENTORY_EQUIPMENT_COMBAT_CONTENT.md`
- `PHASE_5A_COMBAT_DEPENDENCY_ANALYSIS.md` 与 Phase5B2A/5B3B2A 的 hook boundaries
- `DECISIONS.md`

### Current native code / scene

- `game/data/oldpine/oldpine_world_definitions.gd`
- `oldpine_npc_definitions.gd`
- `oldpine_spawn_definitions.gd`
- `oldpine_item_content_definitions.gd`
- `game/core/npcs/npc_definition.gd`
- `npc_character_state_factory.gd`
- `npc_loadout_entry.gd`
- `npc_loadout_item_definition.gd`
- `game/core/armor/armor_definition.gd`
- `armor_service.gd`
- `armor_state.gd`
- `armor_numeric_modifiers.gd`
- `game/runtime/combat_slice/combat_slice_content_profile.gd`
- `combat_slice_projection_builder.gd`
- `game/core/combat/action/*` 与相关 attack snapshots
- `game/runtime/world/oldpine_outdoor_controller.gd`
- aggression、portal、loot、equipment、weapon resolver adapters
- `game/scenes/world/oldpine/oldpine_outdoor.tscn`

### LPC rooms

- `d/oldpine/pine1.c` … `pine7.c`
- `cliffdown.c`, `cliffside.c`, `cliff1.c`, `cliff2.c`
- `riverbank1.c`, `riverbank2.c`, `lake.c`, `waterfall.c`
- `epath2.c`, `epath3.c`
- `passage.c`, `secrectpath1.c`, `path3.c`, `stone.c`
- `cave1.c` … `cave5.c`
- `keep1.c`, `keep2.c`, `keep3.c`
- `tree1.c`, `tree2.c`, `tree3.c`

### LPC NPC / items

- 全部剩余 NPC：`tall_bandit.c`, `fat_bandit.c`, `bandit_chief.c`, `bandit_guard.c`, `bandit_leader.c`, `bandit_commander.c`, `maniac.c`, `spy.c`, `butterfly.c`, `serpent.c`, `venomsnake.c`, `wolf_dog.c`
- `npc/skeleton.c`
- `obj/long_sword.c`, `short_sword.c`, `blade.c`, `glaive.c`, `leather.c`, `fur_coat.c`, `robe.c`, `throwing_knife.c`
- `npc/obj/bamboo_pipe.c`, `parrybook.c`, `black_cloth.c`
- 外部依赖 `obj/dust.c`, `obj/money/silver.c`, `std/money.c`

### Direct LPC dependencies

- `adm/daemons/chard.c`
- `adm/daemons/race/human.c`, `race/beast.c`
- `adm/daemons/combatd.c`, `adm/daemons/weapond.c`
- `std/char.c`, `std/char/npc.c`
- `std/weapon/blade.c`, `std/weapon/throwing.c`
- `std/armor/cloth.c`, `std/armor/surcoat.c`, `std/equip.c`, `feature/equip.c`
- `cmds/std/study.c`
- `mudlib/doc/efuns/random`

没有扫描整个 mudlib，也没有使用外部 Eastern Stories port。

## 28. 正式结论

最佳下一 authored content expansion 不是 full Pine、River、Cave、Keep 或 Tree，而是一个严格裁剪的 Pine slice：

```text
fixed continuous Pine Maze
+ tall_bandit
+ existing long sword / silver / aggression / combat / loot loop
− fat armor
− wolf beast
− Keep / cliff traversal
− Phase5B4
```

它提供最大的新可行走空间与一个完全可追踪的新敌人，同时只需要 content、scene和map-local wiring。Pine random exits与新物理入口必须作为显式 RPG translation decision记录。完成该决定后，**Phase 9B1 可以安全开始**。
