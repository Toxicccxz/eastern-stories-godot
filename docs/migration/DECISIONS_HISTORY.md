# Migration Decisions — 历史

这里是已被后来的决定取代、或只有历史意义的条目，原文照录，顺序同原文件；每条第一行说明为什么在这里。
现行规则以 [DECISIONS](DECISIONS.md) 为准。引用写作 DECISIONS_HISTORY「条目名」。

## 主线必打的仗（第一轮） (owner 2026-11-10「按这个调」：主线必打的仗按「只走主线的角色约六成能赢」，有剧情帮手在场约九成；能绕开的不动；暂定)

(已被「主线必打的仗」第二轮（owner 2026-11-12「按推荐调」）改写：剑、拳两种角色都量，模拟换了打法、到达经验从历练推，玄冥子和第五章护送算必打，数值重定。)

- **之前：** 两小时之后的对手是凭感觉写的。只走主线的角色（各章进章经验取只走主线那条路线：第三章 4695、第五章 8442、第六章 11625、终章 37275；`tests/support/grown_character.gd` 的剑系成长角色，终章拿旋芒）照游戏的真实打法对打（`tests/sim/mainline_fight_sim.gd`：真的协调器和调度器，玩家每回合 2 手、对手按各自的手数，整组一起上，保证在场的帮手照实），每档 40 局，结果见 PR 的前后对照表：后期的仗几乎打不过（踏平工地有七个帮手也 0%），前面的又白送（狱卒、树洞、终章湖畔）。
- **我们（只改对手的数据，都是原生的；武功等级、气不动，除了下面写的）：** 第三章的鬼卒经验 6000 → 5000；带钥匙的狱卒 4500 → 8500；守夜武官 10 万 → 2.5 万；工地的白衣武官 10 万 → 1.3 万、裴照 25 万 → 3.5 万、吕隼 10 万 → 1.3 万；商玦（四处）50 万 → 17 万；冰龙厅的黑冠道士 12 万 → 2.5 万；侮天鬼——穿宝衣没拔过 60 万 → 29.5 万，没宝衣、拔过各一项的两种 80 万 → 20 万，没宝衣又拔过 100 万 → 7.5 万（它气最多、武功最高，经验压得最低才排在最难；四种形态的气 2400 / 3000 / 3000 / 3800 照旧）。鬼卒在第三、五、八章和终章都是同一个定义，一个数没法三处都落在六成：第五章树洞的两只另成 `native.npc.hell_runner_tomb`（1.25 万经验），终章湖畔没人守时那三只另成 `native.npc.hell_runner_finale`（9 万经验，叉 88、招架和闪躲 78，气 850——旋芒一下一个，光加经验没用）；外观、立绘、台词、闲逛都沿用原来的鬼卒（`same_as`），第八章和终章别处的鬼卒仍是原来那个（跟着第三章一起降到 5000，那几仗都能绕开）。
- **之后（同样的角色、同样的打法，每档 40 局）：** 祭坛 64%、狱卒 56%、树洞 56%、踏平 92%、潜入 85%、湖畔 64%、商玦 69%（仍两回合定胜负）、带四个道士 69%、侮天鬼 77% / 72% / 72% / 67%（宝衣和没拔过仍让它好打）；顺手探索的那一档（第三章 8837 起）全部 95–100%。第九章揭发冯策并肩打庾子建是选择的仗、没调：只走主线（32234）约 36%。
- **没动：** 能绕开的仗（追宫主的玄冥子、第七章四个浪人、第八章拔剑之夜、第九章的武举和揭发——庾子建那一仗是冯策并肩的选择，按「主线人物的武功」照旧）；第一章山洞的黑衣道士（1820 经验 100%，前两小时的套件守着）；玩家的成长、`exp_power_divisor`、各区的 `recommended_exp`、移植来的公式。
- **为什么只是暂定：** 成长角色假设潜能（经验的一半）全花在武功上，实际玩家受精的回复限制只会更弱；模拟的打法是固定的（每手打第一个还站着的敌人、默认姿态、不用绝招和守势），会用绝招和克制的玩家更强。对手强弱几乎全由经验项决定，胜率在经验上很陡、一档 40 局也有约 ±8% 的噪声，成长节奏定了要重量。侮天鬼一仗要打二十回合上下、商玦两回合就分胜负：前者是玩家的气不长，后者是旋芒和商玦都一下见血，调对手的经验都治不了，等 owner 定。
- **测试：** `boss_strength_test`（第三到六章、第九章揭发）、`boss_strength_finale_test`（湖畔、冰龙厅）、`boss_strength_demon_test`（侮天鬼四形态，最好打的不比最难打的难）：固定种子、成长角色、每场 16 局、宽区间（没帮手的 35–90%、帮手在场的 70–100%）；`story_chapter6_test` 和 `story_finale_b_test` 不再给 100 万气、不再把敌人的气压到 1，改用成长角色真打（第六章 17432 经验、终章 15 万经验，空手柳家拳，剧情测试照旧是自动打法——自动打法要过 ES2 的勇气关又空手，比模拟弱得多：终章 8 万经验在「再封」那条路上输给商玦和四个道士）。模拟只让剧情里在场的人上（`away`）：冰龙厅的六条冰龙、甬道里没钥匙的两个狱卒先撤下地图——模拟的玩家先动手、一动手整间屋子一起上，冰龙曾在每档第一局跟着上，一局拖到一千五百多步（这一个套件六分钟）；阵容检查也数「别的人」，再有外人上场就报。

## 条件看模式 (势力线第一批 封山 B)

(已被「取消经典模式」取代：游戏只有一种节奏，条件 `{"pace"}` 删掉；大黄石的推法和「点」字诀学了就有。)

- **我们：** 条件多一种 `{"pace": "modern"}`／`{"pace": "classic"}`，读存档里开局选的模式。用在大黄石的推法和「点」字诀上。
- **为什么：** 经典模式答应的是 ES2 的规则原样；给今天的玩家加的捷径和新招，要有一个写在数据里的地方把经典留在原样，而不是各写一个开关。

## 经典模式总开关 (前两小时 E, owner 批准 2026-10-26; Q6 现在做)

(已被「取消经典模式」取代，owner 2026-11-10：新游戏面板不再有「节奏」，`PacePresets` 和 `CharacterState.pace` 删掉；各开关和它们的 ES2 原值照留。)

- **ES2：** 没有难度或节奏的选择；本项目的每个节奏开关各自留着 ES2 原值作经典值，但没有一处能一起切（STATUS 的已知问题）。
- **我们：** 新游戏面板性别下面一行「节奏：现代（推荐）/ 经典」。经典 = 把 A2 的六个进度开关一起按回 ES2：`milestone_rewards` 关、
  `catch_up_max_percent` 0、`staged_potential_cap` 关、`player_exercise_gain` 1、`bounty_board` 关、`training_dummies` 关
  （`PacePresets`，和套件用的 `Es2Pacing.use_without_progression()` 同一套）；手感类（淡入淡出、气泡、战斗速度、连续修炼）不动。
  选择存进 `CharacterState.pace`（存档可选字段，旧存档读作现代，不升修订号）；会话建世界前先按它设好目录的 pacing（木人、悬赏榜
  从第一张图起就对），会话结束时还原。开局后不能改：设置页没有这一项，角色页「修为」里写明「节奏：经典（开局选定）」。
- **为什么：** 活侠传的教训——难度要在第一屏选；经典的玩家一开始就知道自己玩的是原来的数。中途切会让木人、榜、历练账本对不上。

## 首发只做桌面 (owner, 2026-10-24)

(已被「手机端暂停」取代：手机端从「发售后看评价再定」改为暂停，CI 不再跑 Android / iOS；只发桌面、不为手机帧率减配、PR #161 封存照旧。)

- **之前：** 桌面和手机一起做；PR #161 为手机的帧率给体素视图加了一套手机画质档（低分辨率渲染、少阴影、
  只点最近的灯、草丛减半），另有单遍遮挡物和同色合批。
- **owner 决定：** 第一版只发桌面端。手机版等发售后看评价再决定要不要移植。
- **所以：** 画面不为手机帧率减配，各区域的体素地图按桌面定丰富程度；不改画面的优化（合批、少画看不见的
  东西）照常可做。PR #161 不合并，转成草稿封存；分支 `phase/mobile-voxel-perf` 保留，移植手机时从那里
  接着做（先合入最新 main，再在手机上重新量帧率）。CI 照旧跑 Android 和 iOS 两个必需作业（AGENTS.md
  「Git and CI」），只当构建门槛，手机帧率不再是区域的验收条件。

## Snow: walls on the tile grid, collision on tiles (2026-10-01)

(已被「雪亭镇's maps drawn by the painter」和「Old Pine: one map per height level, collision on tiles」取代：3B6 手画的墙带和 SouthBlocker 随画家地图去掉，按瓦片碰撞见后者。)

Owner decisions for Package 3B6:
- **Snow collides through its tiles**, as Old Pine does since 3B5. The 24 px off-grid wall shapes
  are gone; every wall, town boundary and shop wall is redrawn as one 32 px band (two tiles, the
  Inn's thickness) on the 16 px grid, so a wall blocks exactly where it is drawn. Walkable widths
  move by up to 8 px. Doors, the closed Old Pine exit (`SouthBlocker`), the counters and the teacher
  stay nodes; doors and `SouthBlocker` fill their tile openings exactly.

## Terrain on TileMapLayer, collision unchanged (2026-09-30)

(已被「Old Pine: one map per height level, collision on tiles」和「固定俯视体素地图」取代：瓦片负责碰撞，2D 色块不再显示。)

Owner decisions for Package 3B4:
- **Tiles are visuals only.** Terrain is drawn with 16 px tiles from one placeholder TileSet
  ([TERRAIN_TILES](TERRAIN_TILES.md)). Collision stays in `StaticBody2D` shapes, so routes and
  spawns are unchanged. The old geometry is off-grid, so a painted edge may sit up to 8 px from
  its collision. Aligning collision to the grid (or moving it into a physics layer) waits for art.
  (Collision superseded by「Old Pine: one map per height level, collision on tiles」, 2026-09-30:
  static terrain collides through its tiles.)
- **Tiles name terrain kinds, not zones.** About 20 kinds (grass, path, water, wall…) replace the
  per-zone grey-box shades. Neighbouring Old Pine zones no longer differ in colour.

## Old Pine Lake — owner-revised engineering acceptance scope

(历史记录：老松林水潭阶段的工程验收范围；触屏设备验收现属以后的手机移植。)

Owner decision (2026-09-26), after [P2C acceptance](PHASE_OLDPINE_LAKE_SERPENT_PRODUCTION_P2C_ACCEPTANCE.md):
accept the recorded desktop fifth-target mouse input, manual complete-set Attack, five-alive
and mixed death/corpse cross-process Save/Continue, exact durable state/three-RNG equality,
non-resurrection on return, and complete `verify.py` PASS on
`ef8b7d601983c80d817bf28a93e554f2472a49a6` (543.86s).

**TOUCH DEVICE QUALIFICATION — PENDING — NON-BLOCKING FOR LAKE ENGINEERING INTEGRATION.**
This defers missing device evidence only; it is not touch PASS, all-platform acceptance,
or a blanket exemption for later milestones. Actual touch defects, if found, remain separately
reportable. The mobile port in [ROADMAP「Later — release readiness」](../production/ROADMAP.md#later--release-readiness)
retains Lake touch movement, horizontal scrolling, fifth-target selection, Flee, and applicable
safe-area, focus, Pause/Back/background/resume checks. Qualify the then-target devices before
claiming verified Lake touch support or external long-term testing/formal release of the related
mobile version. Later device qualification may be completed directly without reopening all Lake
work or creating a prerequisite development phase, test platform or plugin upgrade.

P2C's original PENDING conclusion and all P1/P2A/P2B reports retain their historical meaning.
M/W/R and product behavior are unchanged. This decision authorized one bounded
[Final Audit](PHASE_OLDPINE_LAKE_SERPENT_PRODUCTION_FINAL_AUDIT.md), not PR creation, merge,
or the next milestone. Engineering acceptance under this revised scope does not mean integrated main.

## Migration Tooling v1 P2 — owner-locked extraction boundary

(已被「Content importer and Snow's first NPCs」取代：Migration Tooling v1 已退役，只留词法器。)

**OWNER APPROVED / LOCKED D1–D9.** P1 analysis is OWNER APPROVED / CLOSED at
`0e5ff6a5cbc8d4091102e280c66868ba8763b4bb`. P2 is authorized on
`phase/migration-tooling-v1`, based on green main `cd07808cb76147d0b8c0dad9b82d078b49fefe64`.
The owner explicitly requested this tooling contract here; it is not a new gameplay substitution.
The [P1 analysis](MIGRATION_TOOLING_V1_P1_ANALYSIS.md) remains historical analysis, not rewritten approval.

- **D1 — Language/location:** Python 3.12 standard library only under `tools/migration/`.
  No Godot runtime or third-party parser dependency.
- **D2 — Objects:** Only `reference/es2/mudlib/d/**/*.c` reliably identified as direct
  `inherit ROOM` in code after excluding comments, strings and multiline text. BANK, HOCKSHOP,
  CLASS_GUILD, NPC, ITEM, weapons, armor, food, containers, daemons, commands, skills, vendors
  and masters are OUT_OF_SCOPE for fact extraction; discovery/dependency findings may retain them.
- **D3 — Facts:** Source identity/path, direct inherit declarations, literal short/name,
  literal long as TEXT_ONLY, ordered static exit entries, and explicit static outdoors/indoors/
  no_clean_up/no_fight values only. No runtime, reachability, door, population or callback semantics.
- **D4 — IR:** Independent Migration IR schema version 1, deterministic UTF-8 JSON.
  Ordered source declarations remain arrays. Player, item and Godot runtime schemas do not change.
- **D5 — Provenance:** Each fact retains source-relative path, raw-byte SHA-256, function/top-level
  scope, construct, raw source/expression, ordinal, zero-based byte start/end-exclusive,
  1-based line/column, classification, and normalization rule/version when applicable.
  Source hash and byte span are primary; CRLF is not normalized before indexing.
- **D6 — Unsupported:** Explicit findings, never execution or guesses. Beyond literals only
  narrow `__DIR__` plus literal-string exit normalization is approved. No arbitrary macro,
  variable, function, closure, RNG, arithmetic, inherited-default or driver evaluation.
- **D7 — Output:** Whole-corpus output is ephemeral under ignored `build/migration-tooling-v1/`.
  Only small hand-reviewed fixtures/goldens may be committed; never generated output in `game/`.
- **D8 — Tests:** Standard-library unittest; expected outputs independently hand-authored/reviewed,
  never generated by the extractor under test. Real ES2 samples remain read-only; copied snippets
  retain provenance. No whole-source copies or bulk generated goldens.
- **D9 — Failure:** Exit0 means complete scan without quarantined syntax/encoding errors;
  expected OUT_OF_SCOPE/semantic findings are allowed and never mean semantic PASS. Exit1 means
  completed scan with object-level syntax/encoding quarantine and safe diagnostic output.
  Exit2 means fatal argument/root/path/I/O/schema/internal/output failure. No silent skipping,
  truncation, source repair or incomplete output masquerading as a complete manifest.

All emitted records start UNREVIEWED. Extraction is not migration approval. Reference source is
read-only; no LPC execution/emulation, NPC/item support, Native generation, gameplay/save changes,
PR, merge or P3 is authorized. P2 implementation and local verification must stop for owner review.

## Snow First Progression P2B-ZE1 — zero-EXP combat defense boundary

(已被「MudOS random(n <= 0) is 0, everywhere」取代。)

(Superseded by「MudOS random(n <= 0) is 0, everywhere」, 2026-10-01: every non-positive `random()`
bound rolls 0 and draws nothing.)

**OWNER APPROVED — narrow Type B compatibility translation.** P2B analysis
`affbe5030a5a2f03c2bff2ab14195f9f86c5f53c` is approved/closed. This decision authorizes
only the existing combat defense-factor boundary on `phase/snow-first-progression-loop`.

Source: `reference/es2/mudlib/adm/daemons/combatd.c:362–366`:
`defense_factor = your["combat_exp"]`, then `while (random(defense_factor) > my["combat_exp"])`
reduces damage by integer damage/3 and halves the factor. Repository evidence does not prove
historical MudOS `random(0)` return/error behavior or RNG-state consumption.

Only when execution actually reaches this stage, **original defender EXP == 0 and attacker EXP >= 0**
means **zero experience-reduction iterations and zero RNG draws**. Continue normal requested damage,
damage mutation, wound, progression, status, busy, relationship/post-action and chain completion.
Do not move the gate before earlier source stages, roll back mutations, or promise later success.

Positive defender EXP retains every existing draw, strict comparison, integer reduction/halving
and ordering. Negative defender/attacker cases remain fail-closed, including attacker -1 with
defender 1 that performs the existing iteration before factor becomes0 and fails at its old stage.
No clamp0→1, fake draw, generator advance or new observation/API surface is required.

This specifically supersedes the older combat invalid-bound decision for this one condition only.
It is not Type A historical-driver evidence or a global `random(0)=0` rule. Generic Combat/World/NPC
RNG adapters and all other nonpositive-bound policies remain unchanged, including wound, force,
progression, riposte cps, perception, Vine and Learn. No EXP gift, initialization/enemy/skill tuning,
source edit, new RNG stream or Save schema change is authorized. Apply equally to Player/NPC
defenders and forward/QUICK/RIPOSTE ordinary attacks without ID-specific exceptions.

Implementation and P2 real-input acceptance rerun are authorized; a new semantic blocker must be
reported without another fix. Final Audit, PR, merge, P3 and Migration Tooling remain unauthorized.
See [historical analysis](PHASE_SNOW_FIRST_PROGRESSION_COMBAT_ZERO_EXP_BLOCKER.md).

## Snow First Progression P2 — owner-approved bounded teaching embodiment

(已被「Give, drop and put; shops and teachers on their NPCs」取代：柳淳风是完整的 NPC 师父，教学是数据；激发、战斗见「Offense/defense routes A」「Offense/defense routes B」。)

**Authority:** Owner approved/closed P1 `5780139b82fad932f6bc7786ea295c20602ae0a5`
and authorized P2 A–F on `phase/snow-first-progression-loop` only.

**Decision:** Embody school1 → school2 → schoolhall as three continuous Snow outdoor zones.
The red gate supports physical Open/Close from both sides, defaults closed on cold start/Continue,
and is transient. Its closed collision footprint remains save-invalid even while open; no relocation
on load. Side routes, guard, fist trainer, trainees and the inner school remain deferred.

Liu Chunfeng is a bounded teaching contact, not a combat/persistent NPC. Preserve his authored
identity, all eleven skill levels and source teaching facts; expose only basic unarmed Learn.
Use existing LearnService, F_MASTER, improvement and combat formulas. One request makes at most
one gameplay draw from the existing saved world-interaction stream at the source progress point;
presentation text consumes none. No gifted experience, balance changes or advanced skill UI.

The public first-apprenticeship chain retains effective cor/cps ≥20, failed pending intent,
Cancel/retry, and idempotent master acknowledgement. Pending is transient per Player. Cross-family,
reverse recruitment and betrayal interfaces remain deferred. Correct active Session/map/zone,
placement, proximity, active life, noncombat/nonbusy and input quarantine are approved Type B
contact gates, not claims about LPC busy restrictions.

First recruitment records the complete source family/master/generation14, distinct family title
and privileges, swordsman class, actual UTC entry seconds, and source display title through a
controlled recruitment seam. No skills or rewards are granted. Owner permits the smallest strict
versioned relationship extension within root2; item3 and SOURCE_ENTRY_V1 remain unchanged.
Historical absent fields remain absent; historical nonempty relationships without an entry time
retain UNKNOWN/NOT_RECORDED, never load time. Old valid root2 saves must remain readable.

**Compatibility impact:** Narrow physical/contact staging only; not full school or Liu NPC parity.
Type C: none. Natural combat evidence may be BLOCKED; no gameplay correction is authorized to
manufacture success. Sources: `d/snow/school1.c`, `school2.c`, `schoolhall.c`,
`daemon/class/swordsman/master.c`, `cmds/std/{apprentice,recruit,learn}.c`,
`feature/{apprentice,skill,attribute}.c`, relative to `reference/es2/mudlib/`.

## Snow north public spine and Core Hub finish line (S7B)

(历史记录：雪亭镇北街里程碑的分期范围；店铺和房间此后由 4B、4C、4E 和画家地图、「地图重构」做完。)

**OWNER APPROVED — S7B.** S7A is OWNER APPROVED / CLOSED at
`04c77650ea72d48cae1173a422a78c3c0188abd5`. Record these decisions separately before
production implementation. They approve the bounded S7A A–L recommendations, not a final
Snow audit/PR/merge. Source semantics remain Type A; the observable staged omissions and
physical embodiment below are **Type B milestone scope**, not authored source closures.

- **A — extent:** Extend the existing `snow.outdoor` resident continuously from mstreet2
  through distinct `snow.mstreet3`, `snow.mstreet4`, `snow.crossroad` zones. Preserve exact
  reciprocal north/south source adjacency; no new map, ordinary-walking portal or shortcut.
  Southwestern sroad2–5 and other optional branches remain deferred.
- **B — external boundaries:** Crossroad itself is required. Its north Goathill and east
  Green directions remain visible static closed content boundaries, with no destination
  definition, travel action, portal, guard, key or invented authored lock.
- **C — Hockshop:** Static east frontage only. No interior, NPC, appraisal, pawn/sell,
  payout/destruction, custody/ticket/retrieve or persistence. Source doors do not authorize
  generic door runtime. No failed-transfer cleanup decision is generalized to Hockshop.
- **D — Herbshop:** Static west frontage only. No interior, herbalist/woodcutter, medicine,
  inquiry, healing or poison cure. Frontage is not service parity.
- **E — Postoffice:** Static west frontage on mstreet4 only. No interior, officer, mailbox,
  mail fees, accounts, online/offline mail or fake local inbox.
- **F — School:** Later progression; mstreet1 east remains closed. No teachers, training,
  faction/apprenticeship or free weapon access.
- **G — Smithy:** Later commerce/weapon content; mstreet2 west remains closed. No hammer,
  repair or crafting.
- **H — ordinary interiors:** Exposed source services receive honest facades/signs and
  collision boundaries, not empty accessible interiors or unusable service buttons.
  These closures are staging, not claims that ES2 permanently closes the shops. mstreet4
  has no executable east exit: add no alley route, zone, interaction or future-region gate.
- **I — secret/storage:** herbshop1, secret_storage, weapon-storage puzzle and unrelated
  storerooms do not block this bounded milestone; no invented secret entrance.
- **J — healing:** Accept existing eligible S5B slow effective-resource recovery as the
  current healing finish line. Preserve cadence, food/water, condition freezes and lifecycle;
  no new recovery Timer, combat recovery, poison scheduling or medicine.
- **K — loot:** Excess-loot monetization remains an acknowledged high-value later commerce
  gap, not a Snow Core blocker. Do not add selling/value projections in S7B.
- **L — completion:** Source New Game, Work, Bank, dumpling, wineskin/water, eligible recovery,
  Old Pine link, north spine, honest deferred frontages/regions and old/new-position Save/
  Continue must work within existing authority. Keep root2/item3/SOURCE_ENTRY_V1; no new
  mutable street/door/NPC state or gameplay RNG use. All38 rooms are not required. A distinct
  Final Snow Audit is the next possible phase **only after S7B owner approval and separate
  authorization**; implementation completion does not close the milestone or authorize PR.

Sources: `reference/es2/mudlib/d/snow/mstreet2.c`, `mstreet3.c`, `mstreet4.c`, `crossroad.c`,
`hockshop.c`, `herbshop.c`, `postoffice.c`, `d/green/path6.c`, `d/goathill/mroad1.c`.
See [S7A analysis](PHASE_SNOW_TOWN_CORE_HUB_NORTH_STREET_CORE_SERVICES_REBASELINE.md).
No Type C redesign is approved; existing PlayerBodyFacts, item authority, prior service
failure policies and owner-local tooling remain unchanged.

## Legacy Native Save Preservation

(已被「Pre-Cutover Development Save Compatibility」取代。)

**Status: SUPERSEDED by Pre-Cutover Development Save Compatibility (NGE5A1).** The following
records the previously approved old-save A decision, not the current branch policy.

**Decision (NGE1 owner-approved A):** Legal native saves created before Snow cutover remain
Legacy Native Technical-Demo Saves and restore their actual stored values. New Game revisions do
not rewrite existing saves. This is a **save compatibility policy**.

Do not relocate the player to Snow, reset attributes/experience, remove the starter weapon, grant
cloth, replenish food/water, rerun birth, revive NPCs/rebuild tombstones, alter corpses, redraw RNG,
or change allocator continuation. Existing native schema1 itself identifies the technical profile;
never infer it from experience, inventory or timestamps. Its absent Player metadata is interpreted
as the existing Player/age20 facts without recalculating saved gameplay values. This approves no
schema2, world revision implementation, Snow geometry, shops or training work.

## Active Semi-Auto V1 SPAR establishment is unarmed-only

(已被「切磋: fight.c, accept_fight and armed spars」取代。)

(Superseded by「切磋: fight.c, accept_fight and armed spars」, 2026-10-01: armed spars as in ES2.)

**Decision:** CXR9 owner authorization restricts SPAR establishment to participants
without a wielded primary weapon. A weapon yields typed `SPAR_WEAPON_NOT_ALLOWED`
before Encounter activation/freezing. No automatic unwield, damage suppression,
HP clamp, revive, lethal conversion or corpse is introduced. Existing
`SPAR_MORTAL_WOUND` remains defense-in-depth for invalid/future states.

**Reason:** `cmds/std/fight.c` establishes reciprocal friendly intent, but
`adm/daemons/combatd.c::do_attack` allows wounds when either lethal intent OR a
weapon is present, before positive friendly damage removes the relationships.
`std/char.c` treats negative effective resources as mortal. That conflicts with
the native non-corpse SPAR contract.

**Compatibility impact:** Legacy armed friendly fights are deliberately unsupported
in V1; future armed/practice-weapon spar needs a separate policy. The newly exposed
unarmed zero-base-damage conflict is resolved by the separate owner authorization
below, not by inventing a positive damage floor.

## Unarmed zero base damage contributes zero without a random draw

(已被「MudOS random(n <= 0) is 0, everywhere」取代。)

(Superseded by「MudOS random(n <= 0) is 0, everywhere」, 2026-10-01: every non-positive `random()`
bound rolls 0 and draws nothing.)

**Decision:** Following the reproduced CXR9 unarmed-SPAR blocker, the owner
explicitly authorized only this exception: when the attacker has no primary
weapon and projected base damage equals zero, its base random term is zero and
consumes no RNG. Continue the unchanged source-ordered action/strength/armor
calculation. Negative base damage and armed zero base damage still fail at
`APPLY_DAMAGE_RANDOM_BOUND`; all other non-positive random-bound rules remain.

**Reason:** `adm/daemons/combatd.c::do_attack` calculates
`(damage + random(damage)) / 2` before adding strength. Human unarmed action and
`chard.c::setup_char` do not establish a positive base damage; the native empty-hand
projection is zero. Local `doc/efuns/random` does not establish historical driver
semantics for zero. Rejecting that ordinary unarmed path prevented the approved
unarmed-only SPAR from concluding.

**Compatibility impact:** This is an explicit narrow substitution, not a claim
that the old driver consumed no RNG for `random(0)`. It supersedes the earlier
non-positive-bound decision only at this empty-primary-hand base-damage stage.
It applies equally to unarmed LETHAL and SPAR; it does not grant damage, suppress
wounds, alter skills, clamp HP, or generally redefine the random adapter.
Sources: `reference/es2/mudlib/adm/daemons/combatd.c`, `adm/daemons/chard.c`,
`adm/daemons/race/human.c`, `doc/efuns/random`.

## Inactive resident Old Pine maps freeze outside the SceneTree

(已被「别的地图时间补算」取代。)

(Superseded by「别的地图时间补算」, 2026-10-23: a map the player left catches up to the present before
it is next used; every map stays resident and the session is `WorldSessionController`.)

**Decision:** Phase 9B3B1 retains instantiated Old Pine map Nodes for the lifetime of one
`OldPineWorldSession`, but only the active map is attached to the SceneTree. An inactive resident map is
detached without being freed and receives no physics, Area overlap, input, Camera, `_process()`,
`_physics_process()`, OpportunityTimer, combat, recovery, condition, or aggression progression.

**Reason:** The original MUD can continue processing objects outside the player's current room, but the
native prototype has no proven off-screen scheduling contract. Keeping a detached map instance preserves
NPC, corpse, loot, item, signal, and physical-view identity across a map round trip without prematurely
building persistence or a global heartbeat simulator.

**Compatibility impact:** Inactive Old Pine maps are frozen rather than globally simulated. They resume
from their retained runtime state when reattached; no elapsed off-screen combat, recovery, condition, or
NPC activity is synthesized. This is an in-memory session-lifetime rule, not save persistence.

## Non-positive authored world random bounds become ordered typed ambiguities

(已被「MudOS random(n <= 0) is 0, everywhere」取代。)

(Superseded by「MudOS random(n <= 0) is 0, everywhere」, 2026-10-01: every non-positive `random()`
bound rolls 0 and draws nothing.)

**S6B supersession:** The owner-approved SOURCE_ENTRY_V1 playable Vine exception above now selects
Waterfall for effective dodge<=0 with zero draws. The original policy/evidence below is historical
for that case and remains current for other revisions/interactions. Positive Vine behavior is unchanged.

**Decision:** When a future authored world interaction reaches an LPC `random(bound)` call with
`bound <= 0`, native code returns a typed legacy ambiguity/failure at that exact source position, consumes
no RNG draw, applies no clamp, and selects no invented branch. Phase 9B3B1 records this boundary but does
not yet implement or execute Vine randomness.

**Reason:** `d/oldpine/epath2.c` calls `random(query_skill("dodge"))`, while the locally available MudOS
documentation does not define zero or negative bounds. The existing Combat decision already uses ordered
typed failures for the same missing driver evidence; authored world interactions require an explicit scope
extension before the Vine path is implemented.

**Compatibility impact:** Positive authored bounds will retain their exact range and source ordering.
Non-positive states become diagnosable instead of crashing, clamping, or silently choosing waterfall or
passage. Presentation and mutations completed before the random position remain observable. Sources:
`reference/es2/mudlib/d/oldpine/epath2.c`, `reference/es2/mudlib/doc/efuns/random`.

## Old Pine Outdoor directly connects to the Pine Maze

(已被「老松林按原文方位排布」取代。)

(Superseded by「老松林按原文方位排布」, 2026-10-25: the native way in is epath3's plank road from the
East Bridge into pine1. `pine2 → keep1` and `cliffdown → cliff2` are open since「Old Pine remainder A:
the keep, the caves and cliff2」, 2026-10-04.)

**Decision:** Phase 9B1 adds one bidirectional, continuously walkable physical threshold between the existing Old Pine Outdoor prototype and the native Pine Entrance zone. It is an RPG geography consolidation, not a `PortalDefinition` and not a claim that the LPC rooms have a direct exit.

**Reason:** The LPC graph has no ordinary edge from the currently embodied Central/North Outdoor area to `pine1`. Its source route is `epath2` vine → `passage` or `waterfall` → River/Cliff → `cliffside` → `pine1`. Requiring that entire chain would block the low-dependency Pine content on conditional skill/RNG traversal, Cave/River authoring, and cross-scene state handoff. Native RPG geography may cluster legacy rooms into continuous maps while retaining their authored identities and meaningful boundaries.

**Compatibility impact:** Players can enter Pine Entrance directly from the current Outdoor map earlier than the LPC topology permits. The Pine-side `pine2 → keep1` and `cliffdown → cliff2` boundaries remain represented but closed, all eight Phase 9B1 legacy room IDs remain traceable, and no new LPC exit is recorded. Sources: `reference/es2/mudlib/d/oldpine/epath2.c`, `passage.c`, `waterfall.c`, `riverbank1.c`, `cliff1.c`, `cliffside.c`, `pine1.c`.

## Snow Martial Progression II — automated functional acceptance

(历史记录：一个已关闭阶段的验收方法，不描述任何现行规则。)

**Owner decision (2026-09-25):** P2 engineering closure uses deterministic automated
production-path verification. This supersedes the live-grind/full-process acceptance
method in D-SMP2-01/08 above, not the gameplay finish or source rules. Genuine prior
[production combat](PHASE_SNOW_MARTIAL_PROGRESSION_II_CHANGED_PATH_LIVE_ACCEPTANCE.md)
already observed EXP0→1; stochastic time-to-EXP6 is deferred to balance/pacing and
usability qualification. Test fixtures may construct exact prerequisite checkpoints
(EXP6/basic unarmed4); these are test-only and never naturally earned live evidence.
No gameplay formula, EXP probability/rule, EXP6 Learn threshold, or unarmed4/liuh5
finish changes. Public Save/Continue with fresh graph reconstruction closes the
functional persistence loop; later human play/Final Audit smoke remains separate.
See the [automated acceptance report](PHASE_SNOW_MARTIAL_PROGRESSION_II_AUTOMATED_ACCEPTANCE.md).

## Random Pine room exits become one fixed continuous maze

(已被「老松林的林径与藏起来的寨门」取代，2026-10-28：崖上的松林不再是迷宫，是一条林径；老松寨的路藏在灌木后，跟着刀痕才开。)

**Decision:** Phase 9B1 translates `pine1` through `pine7` and `cliffdown` into one fixed continuous spatial maze with repeated forks, occlusion, a traversable loop, a safe dead end, a reliable route to Pine Cliff Edge, and a reliable return route. There is no ROOM exit emulator, reset-time topology mutation, or navigation RNG.

**Reason:** The Pine rooms use random exit targets to create disorientation within a text-room runtime. `pine1`, `pine2`, and `pine4` through `pine7` rebuild those exits during reset, while `pine3` selects them during create; several fixed links provide an authored skeleton: `pine1 west → pine4`, `pine4 north → pine5`, `pine5 north → pine6`, `pine6 west → pine7`, `pine7 southwest → cliffdown`, plus `pine2 east → keep1`. Reproducing mutable exit tables would port the LPC runtime representation instead of its maze intent and would make physical collision/navigation unstable.

**Compatibility impact:** A given playthrough and scene reload use the same Pine geometry instead of source reset/load randomization. The native layout preserves getting-lost pressure through physical loops, similar branches, barriers, and dead ends while guaranteeing reachability and return. Pine navigation consumes no random source. Sources: `reference/es2/mudlib/d/oldpine/pine1.c`, `pine2.c`, `pine3.c`, `pine4.c`, `pine5.c`, `pine6.c`, `pine7.c`, `cliffdown.c`.
