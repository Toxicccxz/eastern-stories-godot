# Migration Decisions — 历史

这里是已被后来的决定取代、或只有历史意义的条目，原文照录，顺序同原文件；每条第一行说明为什么在这里。
现行规则以 [DECISIONS](DECISIONS.md) 为准。引用写作 DECISIONS_HISTORY「条目名」。

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
