# Snow First Progression — P2B Fresh Combat Zero-EXP Blocker Analysis

日期：2026-09-14。范围：分析、文档、同一分支提交；**不实施修复**。

结论：这是 main 已存在、被 P2 的真实新角色旅程暴露的零经验防守边界，非 P2 新引入的战斗公式回归。
最内层为 `CombatAttackResult.FailureStage.DEFENSE_FACTOR_RANDOM_BOUND`（21）。
ES2 明确执行 `random(defense_factor)`，但仓库不能证明历史驱动对 `random(0)` 的返回值或随机状态消耗。
建议 owner 单独批准本文件第 8 节的狭义 Type B 处理；本文件不是该批准。
P2 implementation 已获 owner 批准，P2 acceptance 仍为 **BLOCKED**。

## 1. 冻结身份、权限与 preflight

| 身份 | 冻结值 |
| --- | --- |
| Repository | `Toxicccxz/eastern-stories-godot` |
| 当前 major phase branch | `phase/snow-first-progression-loop` |
| main / `origin/main` 比较基准 | `88be5c0e9e297b8f92d38b1f14a131a0cb8abf4e` |
| P1 | `5780139b82fad932f6bc7786ea295c20602ae0a5` |
| P2 / 本次文档提交的 parent | `611535dfe10ce858206574c5494bc5e9a2accbe7` |
| P2 subject | `Add Snow first progression runtime` |
| 开始时 HEAD / `origin/phase/snow-first-progression-loop` | 均为上述 P2 SHA |
| PR | GitHub 按本分支、所有状态查询，无 PR |

修改前已执行 `git fetch origin`，检查分支、三个 ref、提交 subject、worktree/index；冻结身份相符，工作区及暂存区干净。
没有 rebase、merge、reset、stash、clean 或删除操作。P1/P2 历史保持原样。

按要求重读 [root AGENTS](../../AGENTS.md)、[DECISIONS](DECISIONS.md)、
[STATUS](../production/STATUS.md)、[ROADMAP](../production/ROADMAP.md)、
[P1](PHASE_SNOW_FIRST_PROGRESSION_SOURCE_ANALYSIS.md)、
[P2 runtime report](PHASE_SNOW_FIRST_PROGRESSION_RUNTIME.md)，并遵守 [docs AGENTS](../AGENTS.md)。
本文件是 phase-scoped 分析，因此放在 `docs/migration/`。不修改决定账本或当前状态文件。

## 2. 历史实机观察与本次推导的界线

P2 已记录的真实输入路线：New Game → School → 拜柳淳风 → 正常 Learn 到 basic unarmed raw3
→ 实际步行到 Old Pine → 选择现有 bandit3 → Attack。没有注入 EXP、修改敌人或替换 Combat RNG。
玩家正向攻击被 dodge，随后源式反击失败，EXP 留在 0；继续等待未推进，真实 Flee 也未解除失败 encounter。

P2 记录的外层链：

```text
CombatEncounterResolution.Failure.INCOMPLETE_ATTACK_CHAIN (1)
  CombatSliceOpportunityResult.Outcome.ATTACK_CHAIN_INCOMPLETE (13)
    CombatAttackChainResult: REVERSE_ORDINARY_FAILED (6)
      failure stage: REVERSE_ORDINARY (6)
      CombatOrdinaryAttackResult: BASE_ATTACK_INCOMPLETE (1), BASE_ATTACK (9)
        CombatAttackResult: INVALID_SOURCE_STATE (3)
```

本次只读核对了工作站保留的 ignored P2 诊断日志 `build/p2-live-combat-diagnosis.log`、
`build/p2-live-cold-launch.log` 及 School 保存文件
`build/p2-live-env/Roaming/Godot/app_userdata/Eastern-Stories-Godot/save-data/development/default-v1.json`。
它们不是本次新增或提交的 fixture，也不是跨机器必备文件；关键证据摘录如下，便于独立复核。

| 证据 | 值 |
| --- | --- |
| actor | `oldpine.player` |
| target | `oldpine.outdoor.south_slope.spath1.bandit.3.character` |
| 调度位置 | logical cycle 2，events 3 |
| 当前攻击链 bounds | `[54, 1, 16, 601, 30, 1, 16, 601, 601, 15, 22]` |
| 同序 draws | `[2, 0, 8, 339, 29, 0, 1, 52, 124, 0, 17]` |
| Player 保存状态 | EXP 0；raw unarmed 3 / learned 0；gin 43/100；kee 100/100；无主手武器 |
| bandit3 保存状态 | EXP 600；raw sword/parry/dodge 各 10；str 22、cps 18；kee 200/200；主手 short sword，base damage 15 |

日志 JSON 的整数显示为浮点形式，此处仅规范为整数。上述 11 次是这条攻击链的证据，不能冒充整个会话 RNG 总计。
P2 原诊断只取到 base outcome，没有保存最内层 `failure_stage`；本次通过未改动的生产路径、角色状态及完整前缀推导出 21，
并用已有明确断言交叉核对。**这不是声称 P2B 又进行了一次实机采样。** P2 报告无需改写。

## 3. Native 完整调用、数据与失败顺序

### 3.1 角色权威与反向投影

1. [fresh initialization](../../game/core/characters/new_player_initialization_policy.gd) 第 16 行建立
   `CharacterProgressionState.new(0, 99, 0)`。拜师更新归属/称号，Learn 更新技能与潜能开销；没有赠送战斗经验。
2. [Old Pine controller](../../game/runtime/world/oldpine_outdoor_controller.gd) 的 `_initialize_bandits()`
   使用生产 spawn 与 [bandit definition](../../game/data/oldpine/oldpine_npc_definitions.gd)，交给
   [NPC factory](../../game/core/npcs/npc_character_state_factory.gd) 创建；factory 第 238 行直接复制 definition EXP 600。
   主手 short sword 的 damage 15 来自同一 content definition。三个 bandit 是独立状态；这里确为 bandit3。
3. controller 的 `_build_participants()` → [WorldCombatBindingAdapter](../../game/runtime/characters/world_combat_binding_adapter.gd)
   把 Player `state`、NPC `character_state`、equipment/armor/relationships/busy 等现有权威交给 combat binding，没有创建另一份战斗 EXP。
4. [opportunity executor](../../game/runtime/combat_slice/combat_slice_opportunity_executor.gd)
   → fight decision → [single attack execution](../../game/core/combat/execution/combat_single_attack_execution_service.gd)
   → ordinary completion。正向是 Player 攻击 bandit3。
5. 正向普通攻击完成为 DODGE（legacy damage -1）；REGULAR、damage<1、victim guarding 满足反击条件。
   先清除 bandit3 guarding，再以原攻击者 Player 的 raw cps 30 抽取 29，故生成 **RIPOSTE** 请求，而非 QUICK。
6. executor 按请求交换 ID，重新取得 live binding；[projection builder](../../game/runtime/combat_slice/combat_slice_projection_builder.gd)
   `build_reverse_projection()` → `build_attack_input()`，直接读取各方当前 `state.progression.combat_experience`。
   [reverse projection](../../game/core/combat/execution/combat_reverse_attack_projection.gd) 保留正确角色的权威引用并复制证据快照；
   chain 验证当前权威与投影的一致性。它不是拿正向 EXP 字段硬套反向角色。
7. [chain completion](../../game/core/combat/execution/combat_attack_chain_completion_service.gd)
   用同一 Combat RNG 选择反击动作，然后调用同一个
   [ordinary completion](../../game/core/combat/completion/combat_attack_completion_service.gd)
   → [CombatAttackResolver](../../game/core/combat/resolution/combat_attack_resolver.gd)。
   **反击 attacker = bandit3 / EXP600；反击 defender = Player / EXP0。**

### 3.2 数值前缀与精确停止点

| 顺序 | bound → draw | 含义 |
| --- | --- | --- |
| 1 | 54 → 2 | 正向 fight courage：victim bandit3 raw cps18 ×3 |
| 2–4 | 1→0，16→8，601→339 | 正向 action、limb、dodge；Player AP1，bandit DP600，339<600 |
| 5 | 30 → 29 | 清 guarding 后的 riposte 分型；29≥5，因此 RIPOSTE |
| 6–9 | 1→0，16→1，601→52，601→124 | 反向 action、limb、dodge、parry；反向 AP600，Player DP/PP 均为1；两次均未闪避/招架 |
| 10–11 | 15→0，22→17 | short sword base damage 随机项，然后正 strength 随机项 |
| 下一源位置 | defender EXP = 0 | resolver 在调用 RNG **之前**返回 typed failure；不存在记录中的 `next_below(0)` 调用 |

resolver 第 431–449 行：

```gdscript
var defense_factor: int = defender.combat_experience
while true:
    calculation._defense_factor_at_exit = defense_factor
    if defense_factor <= 0:
        # returns INVALID_SOURCE_STATE / DEFENSE_FACTOR_RANDOM_BOUND
        ...
    var defense_roll: int = _draw(random_source, defense_factor, calculation)
```

这里确切 `defense_factor=0`，`defense_iterations=0`，calculation 到达 `STRENGTH_DAMAGE_READY`。
最终 [FailureStage](../../game/core/combat/resolution/combat_attack_result.gd) 是
**`DEFENSE_FACTOR_RANDOM_BOUND = 21`**，不是 APPLY_DAMAGE、FORCE、RIPOSTE 或 RANDOM_DRAW 失败。
short sword 的 base15 与 str22 已成功抽取；该敌人没有进入内力 hit 分支。
在这个返回点尚未执行第 470 行的 defender `apply_damage`、wound 或后续 hit progression。

ordinary completion 检查 base `succeeded()`，失败立即包装成 `BASE_ATTACK_INCOMPLETE`；
chain 再包装为 `REVERSE_ORDINARY_FAILED`；opportunity 返回 `ATTACK_CHAIN_INCOMPLETE`。
[encounter resolution](../../game/runtime/combat_encounter/combat_encounter_resolution.gd) 第 41–43 行锁存 `INCOMPLETE_ATTACK_CHAIN`；
[coordinator](../../game/runtime/combat_encounter/combat_encounter_coordinator.gd) 第 177–205 行停止调度并 hold failed resolution，
`complete()` 的失败 gate 和 `accept_tactical()` 的失败 gate 阻止 Flee 替换失败结果。这解释“等待也不前进”。
不是 Camera、Timer 速度或 School UI 造成的停顿。

前向已消费的 RNG、guard clear/关系变化保持；一般情况下更早的 force 扣除也必须保持，不能把整个攻击倒回。
本次没有反向 kee 伤害/伤势或 hit EXP 突变。非 REGULAR 反击不会继续递归申请第三层 riposte。

### 3.3 raw3 是否间接造成失败

[CombatMath](../../game/core/combat/math/combat_math.gd) 保留整数求值顺序。此角色 raw3 得到 effective unarmed1；
`1³/3=0`，加 EXP0 后 attack power 最终仍被既有最小值规则设为1。raw0 时 skill power 为 `EXP/2=0`，也得到 AP1。
反向 Player 的 dodge 不来自 unarmed；无武器的 Player 对持剑 bandit 招架走 `weapon != null` → PP0 → 既有下限1，
根本不取 Player 的 unarmed power。到了经验减伤位置，仅取 defender EXP，完全不取 raw3、family、class 或 title。

因此同样装备/资源条件下，未训练 fresh Player 也可到达此零经验边界；P2 只是增加了合法抵达 raw3 的旅程。
这不等于“每次 fresh fight 必定卡死”：其他随机轨迹可能先通过 Player 对正经验敌人的命中获得经验。
结论是 **EXP0 防守者一旦走到该 hit 边界就必定失败**；普通敌人正向攻击 fresh Player 同样可触发，不以 riposte 为必要条件。

## 4. main / P1 / P2 的精确 Git 归因

以第 1 节三个完整 SHA 执行 `git rev-parse <sha>:<path>`。下表每一行在 main、P1、P2 **三者相同**。
目录列的是 Git tree ID（包含所有子树/blob）；单文件列的是 blob ID，所以是字节及内容树一致的证据，不是提交摘要印象。

| 路径 | 三个版本共同的 Git object ID |
| --- | --- |
| `game/core/combat` | `328900a32129a4bf961586301ee0f37f7bc5cc73` |
| `game/runtime/combat_slice` | `36d8fb220a0c6c717f036a42be96ba57f8d3cd6b` |
| `game/runtime/combat_encounter` | `73bc7d2b4176ffcb3f6e4861996867e02d8eae6e` |
| `game/data/oldpine` | `3438707fac23a89f578a54911924ac8237bbf1a4` |
| `game/core/npcs` | `91fc8aaab37ab03885ac7fd41df54a918c6a8a3f` |
| `game/runtime/npcs` | `46b445e09df5fee852b4fed263bb64aaac818464` |
| `game/core/characters/new_player_initialization_policy.gd` | `956534c846468b126c69794ac46a193a3bfc70ef` |
| `game/core/characters/character_progression_state.gd` | `aec8e0b1da0e51e2e27aed5298731056974f2ab9` |
| `game/runtime/world/oldpine_outdoor_controller.gd` | `84ac7a9ca2f8bcd38292bf8b27670272b94c323c` |
| `game/runtime/world/oldpine_bandit_aggression_adapter.gd` | `6486ba1459b591b12a57ce5afa8a467bc06f09dd` |
| `game/runtime/characters/world_combat_binding_adapter.gd` | `2c033224a74de2d50ec234d2012e799966fce078` |
| `game/tests/core/combat_ordinary_attack_core_resolution_test.gd` | `46b315ccf4bab12599d5520e31992326c189272e` |
| `reference/es2/mudlib/adm/daemons/combatd.c` | `7277d1df0008ed5bacfc18ca6302e1b920f603e0` |

核心树覆盖 hit/damage policies、普通/反击公式、各 failure enums、CombatRandomSource；slice 树覆盖 Godot RNG adapter；
encounter 树覆盖 scheduler/coordinator。Old Pine definitions 树覆盖 EXP、装备、spawn 内容。

另对确实变化的共享文件逐行检查 `git diff <main> <P2> -- <path>`（P1 与 main 在这些文件相同）：

| 文件 | main/P1 blob → P2 blob | 实际变化及归因 |
| --- | --- | --- |
| `game/core/characters/character_state.gd` | `a720b4523cd60bb823c9888a252782998b9e0b64` → `9bfe11abab23e4adbcf82831a06ca0ec7a6e7304` | 增加 affiliation 属性、末尾可选构造参数及默认归属对象；EXP/equipment 初始化不变 |
| `game/runtime/characters/world_player_runtime_state.gd` | `09f176302982f35085701aa9d16d4b529d14e501` → `bacc9875661957e80d34d41d810b251526543b44` | 增加拜师入口与成功后的称号更新；保留同一 CharacterState/ID/body |
| `game/runtime/world/oldpine_world_session_controller.gd` | `3ffd70aa562906403bbc7ed283e495b1f482be50` → `20fcd613cbcf44780da3acf97428b5f0c97b355b` | 唯一新增 `snow.configure_school(self)`；未改战斗调度或 RNG |

P1→P2 完整 stat 为 43 files、4761 additions、29 deletions，已检查其范围，不能笼统说“P2 没有任何共享文件改动”。
Learn、affiliation 与 save 扩展没有修改本次 New Game 的 EXP0；该事实还有实机保存值支撑。
**归因：main 已有的 fail-closed 战斗语义边界，P2 暴露；不是 P2 公式/RNG/敌人/初始 EXP 回归。**
本次未切换 main 重新运行游戏；“main 可达”是上述字节相同及输入依赖一致的结论。

## 5. ES2 源码顺序与零值可达性（证据 A）

权威 [combatd.c](../../reference/es2/mudlib/adm/daemons/combatd.c) 中：

| 源位置 | 实际语义 |
| --- | --- |
| 165–190 | `skill_power()`：没有有效 skill 时 EXP/2，否则立方/精神比例项加 EXP；不把角色 EXP 改成正数 |
| 237–268 | limb → AP/DP → dodge；只有其条件成立才做 dodge progression |
| 277–304 | 根据双方武器选 parry power → parry → 条件式 progression |
| 312–359 | `(damage + random(damage))/2` → action percent → strength/force/martial/weapon 或 attacker hooks → 正 strength 的 random → 负 damage 归零 |
| **362–366** | **直接读取 defender EXP，反复经验减伤；没有 defender EXP>0 的先决条件** |
| 372–380 | receive_damage，再按 lethal/weapon 条件尝试 `random(damage)` 与 wound |
| 390–412 | NPC 在场等条件下，处理攻击者/防守者 EXP、potential、skill improvement；不是固定每 hit 赠送 EXP |
| 430–444 | 状态文本、busy interruption、友好关系处理、post_action |
| 447–463 | REGULAR + damage<1 + victim guarding → 先清 guarding → `random(my["cps"])` → 交换攻守、QUICK 或 RIPOSTE |

中心原表达式：

```c
defense_factor = your["combat_exp"];
while( random(defense_factor) > my["combat_exp"] ) {
        damage -= damage / 3;
        defense_factor /= 2;
}
```

`your` 是 `victim->query_entire_dbase()`，`my` 是 `me` 的映射；反击时 `victim` 就是 fresh Player。
[logind.c](../../reference/es2/mudlib/adm/daemons/logind.c) `init_new_player()` 设置 potential99、八项属性30，未赠送 EXP；
继承链 [obj/user.c](../../reference/es2/mudlib/obj/user.c) → [std/char.c](../../reference/es2/mudlib/std/char.c)
→ [chard.c](../../reference/es2/mudlib/adm/daemons/chard.c) → [race/human.c](../../reference/es2/mudlib/adm/daemons/race/human.c)
也没有建立正的初始 EXP。[dbase.c](../../reference/es2/mudlib/feature/dbase.c) 提供映射/default 查询，
Native 把这个已迁移的出生状态明确保存为0。
[bandit.c](../../reference/es2/mudlib/d/oldpine/npc/bandit.c) 明确 EXP600、三项 raw10、short sword。

当 EXP0 角色仍 living，攻击通过 dodge/parry，且此前 hooks 未中止，就能抵达 `random(0)`。
AP/DP 的既有下限不会改变该映射值。源没有“先升 EXP 再受击”的条件。
先前其他攻击可能已增 EXP，但这条反击的伤害后 progression 不能用来修复自己尚未通过的零上界。

## 6. 历史 `random(0)` 的证据边界与既有 precedent

### 6.1 搜索范围与驱动证据 B

对整个 `reference/es2` 使用 `rg --hidden --no-ignore` 搜索字面 `random(0)`（含空白）、
`random` 函数定义/声明、宏、`efun::random`、`f_random`、`random_number`、`secure_random`，
并检索 driver/config/README、simul_efun/include、所有 `random(` 调用；不排除 HTML 或隐藏文本。
文件清单为2336个；`random(` 模式在214个文件中有559处文本匹配（包括注释/手册，不代表559个可执行调用）。
实际根目录只有 `LICENSE`、`README`、`mudlib`。

- 未发现字面 `random(0)` 调用；关键零值来自运行时字段，故这个负搜索不能否定零值可达。
- 未发现 `random` 替代实现、包装宏或 efun shim。唯一匹配的 `int random(int n)` 声明来自随附手册。
  [config.ES2](../../reference/es2/mudlib/adm/etc/config.ES2) 指向
  [adm/obj/simul_efun.c](../../reference/es2/mudlib/adm/obj/simul_efun.c)；其 include 的八个 helper 无 random 实现。
- [doc/efuns/random](../../reference/es2/mudlib/doc/efuns/random) 标有 MudOS (5 Sep 1994)、printed 3/16/95，
  写明返回 `[0 .. (n - 1)]` inclusive；没有 n=0、负数、是否推进 RNG 的说明。
  [MudOSdriver](../../reference/es2/mudlib/doc/concepts/MudOSdriver)、
  [simul_efun](../../reference/es2/mudlib/doc/concepts/simul_efun)、driver 的 done-mudos/done-lars/adding_efuns
  没有补上该契约；done-lars 的 random 文本是编译器类型/地址问题，不是 efun 行为证据。
- [顶层 README](../../reference/es2/README) 虽提到 FluffOS binaries、webapp 和外部编译链接，
  本仓库实际 reference snapshot 没有那些 driver binaries/source；
  [mudlib README](../../reference/es2/mudlib/README) 的外部 fork 链接也不能证明当年 ES2 部署版本。
  没有执行外部 driver、下载依赖或浏览公开网络。

**B 的结论：有历史手册，但没有足以证明历史 `random(0)` 返回值、错误行为或状态消耗的仓库证据。**
不能把 `[0,-1]` 当成合法范围，再从空范围推导出“必定返回0”。

### 6.2 Native precedent C 与未证实推论 D

已检索 migration docs/DECISIONS 与 tests 中零/非正上界处理，并与当前实现核对：

| 既有决定/记录 | 当前意义；与本问题的关系 |
| --- | --- |
| DECISIONS “Combat invalid random bounds become ordered typed failures”；[Phase5A](PHASE_5A_COMBAT_DEPENDENCY_ANALYSIS.md) | 在实际到达的位置 typed failure，不 clamp、不提前搬移 gate、不撤销早先突变；本次 defense failure 正是这个已有选择 |
| [Standard force](PHASE_5B2B1_STANDARD_FORCE_HIT_POLICY.md) | 沿用上项；零 force skill bound 在 force 扣除后失败，未新增兼容语义 |
| DECISIONS “Unarmed zero base damage”；[CXR9](PHASE_COMBAT_CXR9_PLAYABILITY_BALANCE.md) | owner 只批准无主手且 base apply damage==0 时该 base random 项为0且不抽取；armed0、negative、其他上界继续失败。不能扩成 defense EXP0 的既有授权 |
| [Phase7A](PHASE_7A_FIRST_WORLD_MAP_NPC_ANALYSIS.md)、[9A](PHASE_9A_OLDPINE_CONTENT_EXPANSION_ANALYSIS.md)、[9B3A](PHASE_9B3A_RIVER_CLIFF_CROSS_SCENE_ANALYSIS.md)、[9B3B1](PHASE_9B3B1_OLDPINE_WORLD_SESSION_MAP_LIFETIME.md)、[9B3B2](PHASE_9B3B2_VINE_WORLD_RNG_CROSS_MAP_TRAVERSAL.md) | Vine/zero-damage ambiguity 的发现与原 fail-closed 历史；当前解释需读后来的限定 supersession |
| DECISIONS S6B、[Water source analysis](PHASE_SNOW_TOWN_CORE_HUB_WATER_DRINK_SOURCE_CONTRACT.md)、[S6B implementation](PHASE_SNOW_TOWN_CORE_HUB_FRESH_WATER_SUPPLY_LOOP.md)、[Town audit](PHASE_SNOW_TOWN_CORE_HUB_FINAL_AUDIT.md) | 仅 SOURCE_ENTRY_V1 effective dodge<=0 明确选既有 Waterfall，零 World RNG。Type B 的具体分支授权，不是驱动证明或全游戏 `random(0)=0` |
| [Beast foundation](PHASE_BEAST_FOUNDATION_SERPENT_ANALYSIS.md) | 沿用 CXR9 base0 决定，未另立全局规则 |
| Combat progression、fight、riposte；Learn/SelfLearning；RNG smoke tests | 继续检查 exact-stage 非正 bound / 除零 / 非法 draw；没有默默统一为0 |

[ordinary resolver test](../../game/tests/core/combat_ordinary_attack_core_resolution_test.gd) 第430–457行
同时覆盖 defender EXP0 的精确失败阶段和 attacker EXP-1/defender EXP1 经一次折半后归零的失败，后者专门防止无限循环。
[force tests](../../game/tests/core/standard_force_hit_policy_test.gd) 保留扣 force 后失败；
[progression tests](../../game/tests/core/combat_progression_busy_completion_test.gd) 保留 hit damage 后的 late failure；
[riposte tests](../../game/tests/core/combat_single_attack_post_action_riposte_decision_test.gd) 保留 guard clear 后 cps0 failure；
[reverse tests](../../game/tests/core/combat_synchronous_reverse_attack_execution_test.gd) 覆盖角色交换、过期投影和共享 RNG 连续顺序。
已有测试证明 Native 现有合同，**不能证明历史驱动合同，也不能代替 fresh 实机验收**。

[出生测试](../../game/tests/core/new_player_initialization_test.gd) 明确断言 EXP0；
[P2 tests](../../game/tests/runtime/snow_first_progression_test.gd) 的 `combat_tests()` 检查 raw0/1/2 与 EXP0/1/2 的 AP投影，
没有执行命中/反击闭环。Old Pine smoke 验证 bandit独立装备及 binding 与角色权威引用相同；
[opportunity integration](../../game/tests/runtime/combat_slice_opportunity_integration_test.gd) 检查 incomplete chain、不可用provider和先前guard突变保留。
这些分别有价值，但不能把它们组合宣称“零经验首次实战已通过”；P2实机阻塞恰好暴露了该验收缺口。

D（尚未证实）：历史驱动可能返回0、抛错或有不同消耗；“零经验不应产生经验减伤”是合理的局部迁移建议，
不是从未定义 efun 行为推导出的 Type A。CXR9 和 S6B 只证明项目采用过 owner 审批的局部决定流程。

## 7. 有界零上界风险清单

这里只判断局部/全局修改范围，不构建静态分析器、不迁移邻近内容。源码字段可为0与某生产路径必定可达分开表述。

| 源边界 / Native 对应 | 零值风险与现有处理 |
| --- | --- |
| combatd defense EXP / `CombatAttackResolver` | fresh EXP0 实际可达；当前在 RNG 前失败。此文核心 |
| combatd apply damage / 同 resolver | unarmed base0 自然可达；CXR9 唯一限定例外。armed0、negative 仍失败 |
| combatd wound `random(damage)` / 同 resolver | 源把负最终伤害归零，符合 wound predicate 后可遇0；当前在 apply_damage 之后 exact-stage 失败，不能随 defense 修改一并放宽 |
| [std/force.c](../../reference/es2/mudlib/std/force.c) 的双方 `query_skill("force")` / `StandardForceHitPolicy` | 无有效技能可为0；是否抵达取决于内力/反震分支；当前保留先扣 force 再拒绝上界 |
| combatd fight perception、victim cps×3、terminal riposte cps | 新角色 cps30 本次无此问题，但受状态/内容影响可非正；各 guard 位置拒绝，不能更改关系突变顺序 |
| combatd progression：gin比例+int、int、max_kee+kee / `CombatProgressionService` | 消耗/受伤/异常属性可触发非正值；max_gin0 是独立除零问题。当前分阶段拒绝，部分路径已完成伤害 |
| [epath2.c](../../reference/es2/mudlib/d/oldpine/epath2.c) dodge / `VineTraversalPolicy` | fresh dodge0 可达；SOURCE_ENTRY 限定 Waterfall 无 draw，其他 profile 保留 ambiguity |
| [learn.c](../../reference/es2/mudlib/cmds/std/learn.c) `int + EXP/(1000+EXP/1000)` / `LearnService` | fresh int30/EXP0 给正 bound30，不是本次阻塞；通用异常输入仍单独验证非正 bound |
| [selflearn.c](../../reference/es2/mudlib/cmds/std/selflearn.c) `int+level` / `SelfLearningService` | Native 先要求 raw≥40、int>0，故可达正常 bound 为正；不能把所有参数表达式都报成现存零值 bug |
| limb/action/message/opponent 选择、NPC birth/recovery cadence | 有数组非空 gate 或固定正 bound；仍应保留非法输入测试。NPC birth 默认21等正上界不需要新规则 |
| 未迁移的 combatd `random(bellicosity)`、quest bonus/2；venomsnake `random(damage)` hook | 源调用点无统一正数替代；缺省好斗值、整数折半或传入伤害存在零候选。此处未证明所有上游可达状态；作为未来迁移审查点，禁止纳入本修复 |

[GodotCombatRandomSource](../../game/runtime/combat_slice/godot_combat_random_source.gd) `next_below(bound<=0)` 返回-1且不推进 generator；
NPC/world adapters 也保留拒绝约定。[combat smoke](../../game/tests/runtime/combat_vertical_slice_smoke_test.gd) 与
[NPC smoke](../../game/tests/runtime/oldpine_outdoor_smoke_test.gd) 已明确测试零上界不是 clamp。
**仅修改 RNG adapter 不会修复本阻塞**：resolver 的 `<=0` gate 根本没有调用它。全局方案还得修改各 domain gate，
将波及互不相同的突变顺序、分支与 streams。风险分布广不代表必须全局统一；相反需要保留局部语义边界。

## 8. 候选方案与唯一建议

| 选项 | 语义/忠实性 | RNG 消耗 | 持久化与兼容性 | 回归范围与必要验证 |
| --- | --- | --- | --- | --- |
| A：combat-local zero-defense 处理 | **待批准的狭义 Type B**；保留正经验源循环，在未证实的零边界作明确本地选择，不能声称 Type A 历史复现 | 该零边界不抽取、不补抽；之前 draws 不变；之后正常 wound/progression 才继续消费 | 无 schema/stream 变化；旧存档可载入。同一修复版本 Save/Continue 必须确定性一致；与旧版本在该失败点之后不再行为相同 | 公共 ordinary hit，包含正向/反向、LETHAL/SPAR、Player/NPC 的零经验防守者；需要下面完整矩阵 |
| B：全局 `random(0)=>0` | 当前没有足够 A/B 证据支持；全局兼容假设不获授权，不可冒充 Type A | 返回0是否推进也未知；人为多抽或不抽都会改多域合同 | schema 可不变，但既有 seeds 的后续行为/失败顺序广泛改变；adapter 单改还无效 | Combat/NPC/World、Learn、force、Vine及未来内容；需全域逐调用审计，远超本任务，不推荐 |
| C：赠 EXP、初始 EXP>0、clamp、改 unarmed/敌人 | **Type C** 数值/进度重设计；无相应源码依据，掩盖原字段语义 | 改 AP/DP/progression/bounds；clamp1 还可能增加一次 draw | 改新游戏与旧存档行为分歧，可能牵涉迁移/平衡；schema 不变也不代表兼容 | 出生、成长、学习门槛、敌人、收益和存档；需专门 owner 重设计批准，不推荐 |
| D：维持 fail-closed | 保留当前 Native ambiguity 防护，未解决历史未知；不是已证实的 ES2正常零值结果 | 维持本次到停止点的11次，无之后 draw | 旧行为不变，但 fresh loop 仍可卡住，Flee 不能恢复该失败；P2 acceptance继续BLOCKED | 无修复回归；继续保留精确失败测试并收集驱动证据，不能宣布可玩闭环已通过 |

**唯一推荐 owner decision（尚待批准）：**

> 仅在普通命中 resolver 到达 combatd 第362–366行对应边界时，若原防守者 combat EXP 恰为0，
> 且攻击者 combat EXP 非负，将此处经验减伤处理为零次减伤迭代；不调用 RNG、不制造 draw、不修改 EXP，
> 继续既有 damage → wound → progression → busy/post-action/relationship 顺序。
> 防守经验正数时保留原循环、严格 `>`、逐步整数减伤与折半以及所有实际 draws；
> 防守经验负数、负攻击经验导致因子归零等异常仍在原位置 fail-closed。
> 其余随机边界、出生、敌人、raw技能、反击机制和 Save/RNG schema 完全不在该批准范围内。

分类为 **narrow Type B compatibility translation**，有未解决的历史 runtime 歧义，不能标成 Type A；
不属于获准平衡重设计 Type C。选择零次迭代的理由是不用赠值即可让 EXP0 防守者继续源式受击与条件式成长，
且保留全部已知正经验语义。适用的是普通伤害公式的这一字段边界，不能只硬编码 Player/bandit3/riposte ID。

后续实现最小生产落点应为 `CombatAttackResolver` 的该边界，加对应验证和获准后的 DECISIONS 记录。
不要修改随机抽象、scheduler 的合法失败防护或学堂代码来绕开原因。现有真正非法情况的 encounter fail-closed 行为仍保持。
本建议不保证打赢、每次必得 EXP 或不会遇到另一个尚未批准的零值边界；遇到新边界必须独立报告。

## 9. 后续修复的验证设计（本次不实施、不执行）

### 9.1 确定性 domain / integration 矩阵

1. defender EXP0，attacker 正 EXP：明确让 dodge/parry 通过，观察原11次或对应受控前缀不变；
   因子保持0、减伤迭代0、此位置没有 random call，继续真正 damage/wound/条件式 progression。
2. attacker EXP0 / defender EXP0：同一命中边界可完成；包括 armed hit 与 CXR9 合法 unarmed base0。
   选择正最终伤害隔离本边界；另测最终伤害0的既有 wound failure 仍保留，不能把后者顺带修复。
3. defender EXP1：**仍抽取一次 bound1**，draw0，然后退出；不能为“优化”把它也变成零抽取。
   defender EXP>1 用既有多轮序列验证 `15→10→7` 等截断、bounds折半顺序及退出条件完全相同。
4. attacker EXP0 / defender 正 EXP：按合法 scripted draws 实际收敛；D≥1 且 A≥0 时，最迟 factor1 的 draw0
   满足 `0<=A` 而退出，不会继续折半到0。附大正因子案例验证有限迭代。
5. defender负 EXP；attacker负 EXP / defender0；attacker-1 / defender1：原失败阶段与先前突变保留。
   特别维持已有 factor1 → 一次减伤 → factor0 typed failure；不要实现对所有 factor0 无条件 break。
6. 完整正向 single attack + production-like fresh Player 反向防守 integration：覆盖 QUICK 与 RIPOSTE，
   guard先清、角色ID/当前状态投影正确、同一 RNG 连续推进、没有递归第三次反击。
   再覆盖普通敌人正向攻击零经验 Player，排除只修 riposte 的实现。
7. partial mutation：前向关系/guard/RNG、先前 force扣除、以及 damage 后 wound/progression失败均不回滚；
   更早的缺 RNG、错误 limb/draw、未实现 hook 等仍在原位置失败，不能提前为 EXP0 绕过它们。
8. RNG adapter的0/负数依然返回-1且state不动；A方案不向它发送该零 bound；
   正数路径 bounds/draws/state exact match，World/NPC streams 在 combat 操作中不受扰动。
9. 复用 existing ordinary、force、fight、progression/busy、post-action/riposte、synchronous reverse、
   encounter scheduler/lifecycle/Flee、beast/unarmed、random persistence 回归；有获准代码变更时再跑 canonical suite 和 parse/editor检查。
   不以新增“返回成功”断言取代真实资源/关系/RNG证据。
10. Save兼容：修复版本读取未修复版本的合法 precombat save；同状态分叉为 uninterrupted 与 cold Continue，
    比较下一次实际合法 RNG 操作结果和 state。跨修复版本的零边界之后轨迹变化应明确记录，而不伪装成兼容相同结果。

### 9.2 必须完成的真实 runtime 验收

在 canonical OldPineWorldSession 运行，并确认 `helper_live=true`、`session_active=true`、
`game_capture_ready=true`、`current_run_errors=[]`。截图要求 `stale_frame=false`，多次观测 frame递增。
连接失败先排查启动/helper/端口排除/development配置；持续失败则记录 BLOCKED，不能换成 controller调用宣称PASS。

用真实键盘、HUD、点击与 CharacterBody/Area 路线执行：

```text
New Game → 实际走到 School → 拜柳淳风 → 自然 Learn 到 raw3
→ 实际走到 Old Pine → 选择现有生产敌人并战斗
→ 自然 combat EXP≥2 → 返回柳 → source-valid 下一次 Learn/成长观察
→ 真实 Save → 终止游戏进程 → 新进程 Cold Continue
→ 对比保存状态及后续 RNG 连续性
```

不得注入 EXP、削弱敌人、替换/重置 RNG、直接调用期望分支、teleport 或伪造胜利。
正常战斗不保证单次获胜/得到2 EXP；允许的重试只能通过玩家实际能进行的玩法操作，逐次记录战斗、恢复、Flee/失败与重试理由，
不能为了命中预定随机结果挑选内部 state。收集首次 EXP变化来源与值，验证仍来自原条件式成长。
raw3 的 `3³/10` 整数门槛为2；下一次 Learn 是否立即升 raw仍由原进度随机项决定，只要求源式条件和状态变化正确。

Save前/Cold Continue后精确比较 Character（属性、资源、EXP、potential/spent、raw/learned、归属）、items/stack/装备、
关系/生命周期保存事实、map/zone/物理位置，以及全部已保存 streams：Combat、NPC initialization、World interaction。
Cold Continue不要求进程内对象指针相同；要求重建后的共享权威关系正确。随后从相同保存点、同一修复版本的受控连续路径比较
后续真实操作的 RNG 输出/state；仅比较 load瞬间seed不够。
确认 encounter 正常结束/可正常Flee，UI输入恢复，流程没有新的 stuck encounter 或 runtime errors。

## 10. 本次独立核验、范围与停止边界

本次 source/data/call-path 复核与 main/P1/P2 object比较构成独立分析核验；明确区分历史实机记录和本次静态推导。
现有测试仅只读检查其断言，本轮不重跑20k+游戏套件，不新增测试/fixture，不启动新的实机验收。
纯分析文档验证：65个本地 Markdown 链接均可解析；`tools/ci/repository_checks.py --repository .` PASS；
13组共同 Git object ID ×3个冻结版本逐项匹配。提交前另检查 staged `git diff --check` 与精确变更范围；
最终提交/remote SHA、检查结果与干净工作区证据在 owner completion report 中记录，避免自指提交哈希。

本次唯一交付文件是本文件。相对 P2 parent，production/test/reference/project/editor/CI delta均必须为0；
`DECISIONS.md`、STATUS、ROADMAP、P2报告保持不变。P2B提交推送至原 phase branch，仅表示分析完成。
没有 PR、没有 merge、本 milestone 尚未完整集成 main；本轮没有触发或宣称 PR/post-merge CI。

未解决问题：历史 MudOS零输入/负输入和状态消耗契约、owner是否批准第8节局部 Type B、修复后的自然成长完整实机结果。
若 owner要求 Type A历史复现，需另行授权并取得与 ES2实际部署对应的驱动证据；现代外部实现不能自动作为历史权威。

明确非目标：实现任何候选方案、扩充战斗/成长内容、平衡调优、修改存档schema或RNG streams、兼容层、迁移工具、
P3、Final Audit、PR、merge、仓库设置。**推送本分析后停止，等待 owner decision；P2 acceptance 保持 BLOCKED。**
