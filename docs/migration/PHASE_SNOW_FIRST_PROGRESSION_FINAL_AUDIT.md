# Snow First Progression Loop / 淳风武馆 — Final Milestone Audit

## 1. Executive verdict

**PASS WITH RESIDUAL RISKS — READY FOR OWNER PR AUTHORIZATION.**
This is the distinct audit of the complete five-commit milestone, not only ZE1.
Approved source semantics and Native substitutions match the implementation. Type C=0;
HIGH blockers within the approved integration scope=0. No production or test correction
is made. One low-severity fixture-document hash transcription defect is recorded in §16.

P1, P2 implementation, P2B, ZE1 and P2 live acceptance are owner approved/closed as
specified by the final-audit instruction. That instruction supersedes their historical
authorization checkpoints. Implementation and formal local audit are complete; integration
on main is not. Only one audit documentation commit/push is authorized. PR creation,
merge, P3 and Migration Tooling v1 require later owner instructions.

## 2. Frozen identities and authority

Audit date: 2026-09-15. Repository: `Toxicccxz/eastern-stories-godot`.

| Identity | Verified value |
| --- | --- |
| Branch | `phase/snow-first-progression-loop` |
| Main/base and merge base | `88be5c0e9e297b8f92d38b1f14a131a0cb8abf4e` |
| Pre-audit local HEAD and origin phase | `6379af74faa3a6cb4190cc4cccdb89cf9c9df2f4` |
| Pre-audit subject | `Record Snow progression live acceptance` |
| Initial worktree/index | Clean/clean |
| Phase history | Five expected commits, linear, no merge inside the phase |
| GitHub branch PR search | No PR, including open PRs |

Fresh fetch/preflight matched the owner freeze. No reset, stash, clean, rebase, merge,
cherry-pick, force push, squash, deletion or rewrite. The final audit commit is identified
without a self-referential hash by its parent above and subject
`Audit Snow first progression milestone`. Its exact SHA, matching remote SHA, clean status
and post-commit verification are reported after commit/push. No second audit commit follows.

Authority reread: [root AGENTS](../../AGENTS.md), [docs AGENTS](../AGENTS.md),
[DECISIONS](DECISIONS.md), [STATUS](../production/STATUS.md),
[ROADMAP](../production/ROADMAP.md), [README](../../README.md),
[P1](PHASE_SNOW_FIRST_PROGRESSION_SOURCE_ANALYSIS.md),
[P2](PHASE_SNOW_FIRST_PROGRESSION_RUNTIME.md),
[P2B](PHASE_SNOW_FIRST_PROGRESSION_COMBAT_ZERO_EXP_BLOCKER.md),
[ZE1](PHASE_SNOW_FIRST_PROGRESSION_COMBAT_ZERO_EXP_FIX.md).
Prior [Snow audit](PHASE_SNOW_TOWN_CORE_HUB_FINAL_AUDIT.md) and
[Hockshop audit](PHASE_SNOW_HOCKSHOP_LOOT_MONETIZATION_FINAL_AUDIT.md) establish the
complete-diff, evidence/claim separation and one documentation-commit convention.
Current code is Native authority; read-only LPC is semantic authority. No external port used.

## 3. Complete commit history

| Commit | Subject | Audited purpose |
| --- | --- | --- |
| `5780139b82fad932f6bc7786ea295c20602ae0a5` | Analyze Snow first progression source contract | P1 source/dependency analysis and status |
| `611535dfe10ce858206574c5494bc5e9a2accbe7` | Add Snow first progression runtime | P2 approved rules, physical school/contact/UI, persistence, fixtures/tests |
| `affbe5030a5a2f03c2bff2ab14195f9f86c5f53c` | Analyze fresh combat zero-exp boundary | Analysis only of the inherited fresh-combat blocker |
| `315d3863a5b72fbbb3f84006440d7b9e796bf512` | Handle zero-exp combat defense boundary | Approved four-line resolver guard, regression tests and decision/evidence |
| `6379af74faa3a6cb4190cc4cccdb89cf9c9df2f4` | Record Snow progression live acceptance | Four docs only; completed fresh E2/return/Learn/cold Continue evidence |

No hidden/unrelated implementation commit, generated editor commit, merge from main or
migration-tooling implementation. P1/P2B/live-evidence commits are documentation checkpoints;
P2 and ZE1 carry the executable changes. The subsequent sole audit commit changes docs only.

## 4. Full milestone diff and per-file classification

Range: `88be5c0e9e297b8f92d38b1f14a131a0cb8abf4e...6379af74faa3a6cb4190cc4cccdb89cf9c9df2f4`.
**50 files, +6,267 / -26**, five commits. Categories below are disjoint; UID companions
belong to their owning category. Fixtures include four JSON files and their provenance README.
World/content includes the physical scene. Persistence includes Core and Runtime persistence.

| Category | Files | Added | Deleted |
| --- | ---: | ---: | ---: |
| Core production | 7 | 114 | 3 |
| Runtime production | 5 | 105 | 0 |
| Presentation | 2 | 213 | 0 |
| World/content data and scene | 4 | 246 | 4 |
| Persistence | 6 | 55 | 9 |
| Tests | 14 | 463 | 8 |
| Fixtures/provenance | 5 | 3,412 | 0 |
| Docs | 7 | 1,659 | 2 |
| Project/config | 0 | 0 | 0 |
| CI/build | 0 | 0 | 0 |
| Reference source | 0 | 0 | 0 |

Thus production=24 paths, tests=14, fixtures=5, docs=7. The final documentation commit
adds this report and minimally updates STATUS/ROADMAP: three audit paths, production/test/
fixture/config/reference delta0. Base to final audit is six commits and 51 unique paths,
with docs increasing to8 and all other category counts unchanged. Final additions/deletions
are reported from Git after the documentation is finalized, rather than guessed in advance.

| Changed path | Category |
| --- | --- |
| `docs/migration/DECISIONS.md` | docs |
| `docs/migration/PHASE_SNOW_FIRST_PROGRESSION_COMBAT_ZERO_EXP_BLOCKER.md` | docs |
| `docs/migration/PHASE_SNOW_FIRST_PROGRESSION_COMBAT_ZERO_EXP_FIX.md` | docs |
| `docs/migration/PHASE_SNOW_FIRST_PROGRESSION_RUNTIME.md` | docs |
| `docs/migration/PHASE_SNOW_FIRST_PROGRESSION_SOURCE_ANALYSIS.md` | docs |
| `docs/production/ROADMAP.md` | docs |
| `docs/production/STATUS.md` | docs |
| `game/core/characters/character_state.gd` | Core production |
| `game/core/combat/resolution/combat_attack_resolver.gd` | Core production |
| `game/core/learning/learn_service.gd` | Core production |
| `game/core/persistence/character_state_snapshot_restorer.gd` | persistence |
| `game/core/persistence/game_save_json_codec.gd` | persistence |
| `game/core/persistence/game_save_snapshot_validator.gd` | persistence |
| `game/core/persistence/game_save_value_types.gd` | persistence |
| `game/core/relationships/character_affiliation_state.gd` | Core production |
| `game/core/relationships/character_affiliation_state.gd.uid` | Core production |
| `game/core/relationships/swordsman_apprenticeship.gd` | Core production |
| `game/core/relationships/swordsman_apprenticeship.gd.uid` | Core production |
| `game/data/snow/snow_school_teacher.gd` | world/content data |
| `game/data/snow/snow_school_teacher.gd.uid` | world/content data |
| `game/data/snow/snow_world_definitions.gd` | world/content data |
| `game/runtime/characters/world_player_runtime_state.gd` | Runtime production |
| `game/runtime/persistence/oldpine_map_placement_validator.gd` | persistence |
| `game/runtime/persistence/oldpine_world_save_capture.gd` | persistence |
| `game/runtime/world/oldpine_world_session_controller.gd` | Runtime production |
| `game/runtime/world/snow_outdoor_controller.gd` | Runtime production |
| `game/runtime/world/snow_school_contact.gd` | Runtime production |
| `game/runtime/world/snow_school_contact.gd.uid` | Runtime production |
| `game/scenes/world/snow/snow_outdoor.tscn` | world/content data |
| `game/tests/core/combat_ordinary_attack_core_resolution_test.gd` | tests |
| `game/tests/fixtures/snow_progression/README.md` | fixtures |
| `game/tests/fixtures/snow_progression/pre_p2_hockshop.json` | fixtures |
| `game/tests/fixtures/snow_progression/pre_p2_legacy_relation.json` | fixtures |
| `game/tests/fixtures/snow_progression/pre_p2_oldpine.json` | fixtures |
| `game/tests/fixtures/snow_progression/pre_p2_snow.json` | fixtures |
| `game/tests/run_snow_progression_cold_process.gd` | tests |
| `game/tests/run_snow_progression_cold_process.gd.uid` | tests |
| `game/tests/run_snow_progression_tests.gd` | tests |
| `game/tests/run_snow_progression_tests.gd.uid` | tests |
| `game/tests/run_tests.gd` | tests |
| `game/tests/runtime/combat_slice_opportunity_integration_test.gd` | tests |
| `game/tests/runtime/combat_vertical_slice_smoke_test.gd` | tests |
| `game/tests/runtime/hockshop_runtime_test.gd` | tests |
| `game/tests/runtime/snow_bank_access_test.gd` | tests |
| `game/tests/runtime/snow_first_progression_test.gd` | tests |
| `game/tests/runtime/snow_first_progression_test.gd.uid` | tests |
| `game/tests/runtime/snow_north_spine_test.gd` | tests |
| `game/tests/runtime/snow_work_income_test.gd` | tests |
| `game/ui/snow/snow_school_interaction.gd` | Presentation |
| `game/ui/snow/snow_school_interaction.gd.uid` | Presentation |

`reference/es2` delta=0. Project settings, addons, export presets, CI and build tools all
have delta0. Each new UID has its script; no generated screenshots/logs/saves are in this diff.

## 5. Fresh source-fidelity findings

LPC paths in this section are relative to `reference/es2/mudlib/`.

| Area | Source rechecked | Finding |
| --- | --- | --- |
| World | `d/snow/mstreet1.c`, `school1.c`, `school2.c`, `schoolhall.c`; `std/room.c` | West/east chain retained; school1 east and school2 west share the authored initially closed red gate. No key/member requirement invented. school2 north storage and hall east inner yard remain staged boundaries. `school.c` is the separate academy. |
| Teacher | `daemon/class/swordsman/master.c`; `std/char/npc.c`, `std/char.c`, `adm/daemons/chard.c`, `race/human.c` | Liu, male44, int24, generation13; all11 raw skills retained. Human age44 implies sen170. NPC teaching checks but does not debit sen. Mutable combat identity/equipment/lifecycle are explicitly outside contact scope. |
| Apprenticeship | `cmds/std/apprentice.c`, `recruit.c`, `feature/apprentice.c`, teacher override, `feature/attribute.c` | Effective cor/cps >=20; failed pending/cancel; first recruitment, unchanged betrayer, exact generation/master/class/title/time; existing-master acknowledgement is idempotent. Reverse/player/cross-family recruitment is unavailable. |
| Learn | `cmds/std/learn.c`, `std/char/master.c`, `feature/skill.c`, `daemon/skill/unarmed.c` | Ordered admission/prevention/skill/cost/raw0/potential/fatigue/gin/EXP/spent/random/improvement/callback/gin debit retained. No invented cap or guaranteed level. |
| Combat | `adm/daemons/combatd.c::skill_power/do_attack/fight` | Existing authoritative skills and integer combat/progression remain; reverse guard clear/type selection and shared RNG preserved. ZE1 is the sole combat production delta. |

Teacher knowledge is exactly: unarmed40, parry120, dodge80, sword150, force40,
literate60, fonxanforce60, fonxansword150, liuh-ken60, chaos-steps100, spider-array85.
Source mappings are unarmed→liuh-ken, sword/parry→fonxansword, dodge→chaos-steps;
no authored force or array mapping. They remain source facts in P1, not functioning
contact combat/mapping UI. Only unarmed is publicly teachable in P2; no claim Liu only knows it.

Historical MudOS zero-bound output/state consumption is still unproven. The repository's
`doc/efuns/random` states only the positive range contract. ZE1 is explicitly a narrow
owner-approved Type B translation, never Type A driver reproduction.

## 6. Architecture and authority

[SwordsmanApprenticeship](../../game/core/relationships/swordsman_apprenticeship.gd)
owns the bounded rule and changes the existing CharacterState family/apprenticeship/affiliation.
It does not create a second character or duplicate relationship registry.
[WorldPlayerRuntimeState](../../game/runtime/characters/world_player_runtime_state.gd)
replaces read-only identity facts only after RECRUITED, retaining body, CharacterState and ID.

[SnowSchoolContact](../../game/runtime/world/snow_school_contact.gd) owns physical availability,
local door and calls the existing [LearnService](../../game/core/learning/learn_service.gd).
Its RNG parameter is the existing Node-free Core `WorldInteractionRandomSource` abstraction,
not a dependency on a scene or Godot generator. `liquid_interaction_available()` supplies the
existing session/application/life/restore/world-gate predicate despite its older name.

[SnowSchoolInteraction](../../game/ui/snow/snow_school_interaction.gd) displays structured
results and routes one activation to one request. It recomputes a read-only cost preview,
but no preview grants permission or mutates rules; execution always recalculates in Core.
This small duplicate display formula is a future maintenance risk, not forked Learn authority.
No UI EXP, gin, skill, reward, healing or RNG authority was introduced.

Save capture/restoration extends the existing graph. Session registration retains the same
four residents and one attached active map. Stable IDs are used; legacy master name remains
only the deliberately distinct source predicate. No general trainer/dialogue/door framework,
LPC interpreter, scheduler emulator or broad new singleton appears.

## 7. Definitive Type A / Type B / Type C ledger

Counts are numbered contract groups, not counts of lines, files or every scalar. Reused
mechanics are listed where this milestone newly exposes them; unrelated historical decisions
(such as existing Flee/recovery/base-unarmed-zero policies) are not counted as new translations.

| Type A | Source-backed contract exposed or preserved |
| --- | --- |
| A1 | Exact mstreet1/school1/school2/hall adjacency, red gate identity/directions/closed source default |
| A2 | Liu identity, age/int/generation, all11 knowledge levels, source-derived teaching sen and NPC payment distinction |
| A3 | Effective cor/cps >=20 qualification; no age/EXP/fee/skill gate on fresh NPC recruitment |
| A4 | Player-initiated request, failed pending, same-request waiting, explicit cancel then retry |
| A5 | First family/master/generation14/rank/privileges/class/title/actual entry time; no skill/EXP/betrayal gift |
| A6 | Existing-master ID/name acknowledgement preserves original time and betrayer count |
| A7 | Learn admission and F_MASTER predicates, teacher raw/prevention/valid_learn order |
| A8 | Integer cost11/raw0cost22, raw0 before potential, total-versus-spent, strict teacher sen and student gin ordering |
| A9 | Martial raw-cube/10 EXP gate; E0 raw3 needs E2, consumes gin but no spent/progress draw |
| A10 | Spent before one progress draw; exact bound, spiritual penalty, zero amount→1, strict square threshold, one level, callback then gin |
| A11 | Same raw/learned/mapping state feeds effective unarmed and existing combat/AP/conditional EXP progression |
| A12 | Persistent first-recruitment and learned/progression/resource values retain their semantic identity across capture/restore |

| Type B | Approved Native representation/substitution and boundary |
| --- | --- |
| B1 | One continuous physical three-zone school cluster; honest staged side routes/population instead of room-loading runtime |
| B2 | Teaching-only Liu contact with full knowledge facts; no combat/spawn/equipment/death/respawn NPC parity |
| B3 | Active session/map/zone/life/placement/proximity/noncombat/nonbusy/UI quarantine checks replace same-room command context |
| B4 | One local two-sided transient physical gate; cold closed, closed footprint save-invalid even while open, no load relocation |
| B5 | Per-Player typed transient pending and synchronous first-NPC chain; reverse/cross-family/player recruitment interfaces omitted |
| B6 | Stable IDs, controlled title seam and typed outcomes/native panel replace textual command/object identity and feedback |
| B7 | Existing persisted world-interaction RNG drawn at actual Learn progress point; presentation/rejection text consumes no gameplay draw |
| B8 | Strict optional affiliation v1 block within root2; current writer/old reader-shape compatibility through existing snapshot graph |
| B9 | Old nonempty relationships missing entry time become UNKNOWN; no invented time/class/rank; no-family stays ABSENT |
| B10 | ZE1: only reached original defender EXP0 + attacker EXP>=0 gives zero reductions/zero draws; all other boundaries retained |

**Type A:12; Type B:10; Type C:0 (authorized0, implemented0).** No balancing, free EXP,
hidden stat gifts, global random(0) reinterpretation or unauthorized advanced-skill behavior found.
Authorizations are the two Snow First Progression entries in DECISIONS and the current owner freeze.

## 8. Physical world audit

Production [Snow definitions](../../game/data/snow/snow_world_definitions.gd) and
[Snow scene](../../game/scenes/world/snow/snow_outdoor.tscn) match:
Inn→Square→mstreet1→school1→school2→schoolhall. Snow outdoor has16 zones, plus Inn=17.
The old east wall is split to admit the school entrance; only the SchoolDoor shape toggles.
Gate at `(400,-400)` uses real collision. Teacher marker/body is at `(1080,-400)`.
Teacher reach is96; door reach90 on school1 or school2. Other walls remain active.

Canonical physical tests exercise CharacterBody input, west/east collision and both-side
Open/Close. Those tests also call contact methods as integration boundaries; they alone
are not player-UI proof. P2's original live school/cold-door route separately used real
buttons for both-side Open/Close and movement; the final fresh journey confirms the route
under ZE1. The four-line combat change does not invalidate the earlier door evidence.

Cold sessions/Continue start closed; same resident session keeps its open state across maps.
The placement validator always excludes the closed school/Hockshop footprints, preventing
load relocation and closing onto Player. Hall position is save-valid and restores exactly.
Storage north, inner yard east and academy remain unavailable, without fictitious source locks.

## 9. Apprenticeship audit

`SwordsmanApprenticeship.request()` checks authority, existing master, other relationship,
pending, then sets pending and evaluates effective attributes. 19 rejects;20 and fresh30/30
accept. Bellicosity/50 and force_factor/2 modifiers participate. Cancel is necessary after
a failed pending request. Other-family and other-master paths stop before replacement.

Successful first recruitment records `family.fonxan`, generation14,
`teacher.liu_chunfeng`/柳淳风, rank弟子/privileges0, swordsman, recorded UTC seconds and
封山剑派第十四代弟子. Existing apprenticeship object and betrayer count survive; no initial
skill/EXP grant. Runtime takes the timestamp only for a request; ACKNOWLEDGED does not rewrite it.
Pending belongs to the Player's transient request object and never enters the save schema.

Tests cover all boundaries above, title seam and identity retention. The fresh live run
records first entry1789446817 and preserves it through natural combat, return and cold Continue.
The missing source cross-family score mutation is not a bug here: that route is unavailable.

## 10. Learn semantics audit

One public basic-unarmed request passes current state/context/policy and the session's world
stream to LearnService. Admission and F_MASTER remain separate ID/generation versus ID/name
checks. Teacher skill40, int24, sen170, privileges-1 and generation13 are source facts.

Integer `150/24 + 150/30 = 6+5 = 11`; raw0 doubles to22 and writes explicit zero before
potential/no-teach/fatigue. Potential total is not decremented; spent increments only in
the progress branch. Teacher needs sen>5 at raw0, >3 afterward, and NPC sen is not charged.
Student needs gin>22 or >11; equality drains available gin without progress.

For martial skills, `raw*raw*raw/10 > EXP` rejects progress after the gin check. At E0,
raw0/1/2 can advance; raw3 needs2, raw4 needs6. EXP rejection still charges full gin.
No artificial level3 cap exists. After spent increments, bound is
`int + EXP/(1000 + EXP/1000)`, using integers; fresh/E2 bound30. Exactly one draw feeds
existing `CharacterSkillState.improve_skill()` and authored improvement effects. Zero roll
becomes1 progress; threshold is strict `>`; overflow is discarded and at most one level rises.
Unarmed's existing periodic strength callback is preserved, not a new flat combat bonus.

No pre-gate draw, pre-roll, automatic loop or UI reroll. Invalid draws retain earlier spent/
raw0 mutations and fail before gin debit; other established late-failure ordering remains.

## 11. Combat integration audit

Trace: Learn's `player.state.skills` →
[WorldCombatBindingAdapter.from_player](../../game/runtime/characters/world_combat_binding_adapter.gd)
→ [CombatSliceProjectionBuilder](../../game/runtime/combat_slice/combat_slice_projection_builder.gd)
→ effective unarmed → [CombatMath.skill_power](../../game/core/combat/math/combat_math.gd)
→ ordinary attack. These shared production files have no milestone delta.

No primary weapon selects unarmed; effective value uses base raw/2 plus mapped raw/modifier
when legitimately present. L0 uses EXP/2, otherwise source-ordered cubic/spirit arithmetic
plus EXP; AP's existing floor is1. At E2 raw2 can produce AP2 versus raw0/1 AP1 in controlled
same-EXP projection tests. E0/E1 raw3 observed live still gives AP1. EXP gain remains the
existing conditional combat progression, not kill reward or teaching bonus.

After live E2 Learn raw4, production authority references the exact same CharacterState and
CharacterSkillState, effective2. **No post-Learn attack/AP2 live experiment is claimed.**

## 12. ZE1 boundary audit

[CombatAttackResolver](../../game/core/combat/resolution/combat_attack_resolver.gd):431–438
adds two comments, the original-defender/nonnegative-attacker condition and `break` at the
existing loop. No early shortcut before hooks/draws. Zero defense reductions and zero calls
occur only at the approved boundary. Later damage/wound/progression may still fail normally.

EXP1 retains actual random(1)/draw0. Positive loop retains exact bounds40→20→10 and
damage15→10→7. Negative defender fails; attacker-1/defender0 fails; attacker-1/defender1
retains its draw and one reduction before halved-zero failure. No ID/player/enemy/riposte
special case. QUICK/RIPOSTE and ordinary forward paths share the same resolver.

Generic RNG adapters are unchanged; invalid0/negative calls still return-1 without advancing.
Wound-zero remains a failure after damage stage, force and other bounds remain independently
guarded. Tests preserve earlier guard/relationship/draw mutations and forbid a third reverse.

## 13. Persistence and old-save compatibility

Public contract remains **root schema2 / item schema3 / SOURCE_ENTRY_V1**.
[Codec](../../game/core/persistence/game_save_json_codec.gd),
[value types](../../game/core/persistence/game_save_value_types.gd),
[validator](../../game/core/persistence/game_save_snapshot_validator.gd),
[restorer](../../game/core/persistence/character_state_snapshot_restorer.gd) and
[capture](../../game/runtime/persistence/oldpine_world_save_capture.gd) extend one graph.

Existing family/master/generation/betrayer, player title, raw/learned/mappings, EXP, potential/
spent and resources remain. Affiliation v1 adds class, rank-known flag/title/privileges,
entry-time status and int64 UTC seconds. New output includes the block. Exact old shape
remains readable; present malformed/unknown-version blocks cannot silently fall back to old.
Snapshot and restored affiliation copies prevent aliasing with the mutable live object.

Old no-family is ABSENT, with no class/rank/time. Old nonempty relation retains old fields
and gets UNKNOWN, no fabricated historical data. Unknown/absent cannot carry a timestamp;
unrecorded rank cannot pretend that privileges0 was known. Re-saving old data emits the new
block: semantic preservation is claimed, not byte equality with old JSON shape.

Four actual frozen-P1 fixtures, raw0 late failure, partial progress and hall saves pass
full graph restoration comparisons. Items/food/liquid/equipment/money/body/allocators and
RNG keep existing codecs. Pending, panel, gate and recovery phase are transient. Cold hall
Continue closes gate while preserving the exact safe physical point.

## 14. RNG contract

Learn borrows the already persisted World interaction stream exactly once at progress;
opening/refreshing the panel, rejection text, apprentice/cancel and door use no gameplay draw.
Combat uses its separate existing stream; ZE1 suppresses no positive-bound call. NPC birth
stream is unchanged. Existing transient recovery cadence is not a fourth persisted stream.

Fresh live Save/Continue exactly matched adapter IDs, seeds and all persisted states:

| Stream | State |
| --- | --- |
| Combat | `4754167863713160086` |
| NPC initialization | `440029765285268016` |
| World interaction | `-4028637667228911038` |

No arbitrary next draw was consumed in that live timeline; raw4/E2 is below next Learn E6.
The separate deterministic cold-process test compares a next World draw under constructed
test state. It is not relabeled as a live next-operation experiment.

## 15. Existing fresh live acceptance audit

Accepted as valid; no reason found to repeat the full journey. Production/test/config tree
is unchanged between ZE1 and the evidence commit, and this audit makes no executable edits.
Durable evidence is [P2 fresh acceptance](PHASE_SNOW_FIRST_PROGRESSION_RUNTIME.md#fresh-live-acceptance-2026-09-15-utc).
This audit independently inspected the retained JSONL, read-only queries, snapshots, logs
and post-Learn/cold screenshots. Local evidence is ignored, not a shipped test fixture.

| Acceptance | Rechecked evidence |
| --- | --- |
| Fresh birth | Real Unicode New Game, E0, no family/master/skills, Snow Inn |
| Physical school | CharacterBody route via Square/mstreet1; closed collision x370.993; real Open, yard, hall |
| Apprentice/Learn | Real UI; exact first relationship; three requests to raw3; next E0 rejection gin76→65, no spent increase |
| Old Pine | Physical production portal and existing spath1 Bandit03, no enemy/EXP/RNG setup |
| Encounters/Flee | Nine ordinary production encounters; each real Flee, failure NONE, ACTIVE; natural recovery between them |
| Natural EXP | 0 through6, 0→1 in7, stays1 in8, 1→2 in9; retained final progression bound143/draw16 |
| Return/state identity | Physical return to hall; same Character and apprenticeship objects before Save; within-session gate still open |
| Post-E2 Learn | One click, raw3→4, progress0, spent3→4, gin100→89, roll21/bound30; no fake bonus |
| Combat consumption | Existing binding points to same learned state; no extra post-Learn attack claimed |
| Save/restart | Actual Save feedback; PID57284 stopped/absent; new PID63804, normal Continue |
| Cold graph | Entire encoded state exact; new Session/Character objects with preserved authoritative values |
| Cold runtime | One active Snow map/correct Player Camera2D; gate closed/collision on; no teaching panel/encounter residue |
| Health | Helper/session/capture ready; both launch error arrays empty;24 captures all stale_frame=false with advancing frames |

Audit counted884 retained tool events. All254 `editor_manage/game_eval` requests were reviewed:
two deliver real Unicode InputEventKey events; the others observe existing state/results or
capture/encode snapshots. No direct gameplay callbacks, location/EXP setters, RNG reset/draw,
seed search or timing acceleration replaced the player path. Real input uses `game_manage`.
The rejected redundant launch did not change the running process; startup readiness delay and
one movement while normally paused do not rewind the timeline. No cleared error buffer.

Frames include18→387098→410264; cold7→2538→5531→11199. First-game log158 entries had
157 info/one desktop virtual-keyboard warning, no gameplay errors; cold7 entries all info.
Checkpoint and cold JSON are both24,579 bytes and SHA-256
`51908582cd0e762a8d08d67362840c54f6c9a3a0ffdaa89c9ec7506109118ba1`.
Checkpoint E2/raw4/spent4/potential101, entry1789446817, schoolhall position
`(1008.33404541016,-399.333709716797)` and all12 item records match exactly.
This is desktop game evidence, not a packaged/mobile qualification or pacing approval.

## 16. Test coverage and fixture audit

| New/changed tests | Production invariant |
| --- | --- |
| `snow_first_progression_test.gd::apprenticeship_tests` | Effective19/20/30, pending/cancel, first fields, no rewards, idempotency and no switching |
| `learn_tests` | Raw0/1/2/3 × E0/2 × roll0/1/29; strict costs/fatigue, explicit zero before failure, spent/invalid draw order, no pre-gate/UI draws |
| `combat_tests` | Real production projection/CombatMath, same-EXP raw comparisons, no mapping/bonus |
| `persistence_tests` | Four frozen old shapes, ABSENT/UNKNOWN, exact graph, raw0/partial skills, schema identity, invalid affiliation |
| `physical_tests` | Input/collision, both-side door, footprint validity, zone/range/session/busy/combat/pause recheck, panel quarantine, no NPC slot |
| `run_snow_progression_cold_process.gd` | Separate writer/reader processes and Host Continue, entire snapshot, title/class/location, transient closure and next World draw |
| `combat_ordinary_attack_core_resolution_test.gd` | ZE1 zero/positive/negative matrix, exact bounds/draws/damage, later wound failure retained |
| `combat_slice_opportunity_integration_test.gd` | Forward/QUICK/RIPOSTE, guard order, swapped authority, real damage/progression and shared stream |
| `combat_vertical_slice_smoke_test.gd` | Generic invalid-bound state unchanged and next positive continuation |
| Existing Snow/Hockshop/Bank/Work tests | Exact new zone count, relocated honest barrier/deferred academy; unrelated assertions retained |
| Runner/UID changes | Canonical registration and independent focused/cold entry points; no skipped suite |

Old defender0 failure expectation is specifically superseded by ZE1; negative coverage is
retained/expanded and new zero-success assertions check mutations, not merely a success flag.
Old school-wall assertions now test the actual inner gate or remaining wall;17 total zones
replace14. No unrelated weakened assertion or central registry refactor found.
The few structural assertions (11 offers/no added NPC slot/exact schema) protect scope and
compatibility. Constructed state, scripted RNG and direct contact calls are tests, not live proof.

Fixture provenance: inspected ignored frozen-P1 writer and successful log; it used the archived
P1 codec/capture and typed setup, not deletion of new keys. All four JSONs have no affiliation.
**LOW finding F1:** [fixture README](../../game/tests/fixtures/snow_progression/README.md)
mistypes the Old Pine SHA-256 (61 hex characters). The actual unchanged file's correct64-character
hash is `3b41a7e2150a7c6d419dfe1c3079995a779b19da78dcd10b85d224be0f6c7e8a`.
Other three hashes match their README. The fixture itself is valid and passes canonical old-save
restore; the error affects manual provenance checking, not save compatibility or executable behavior.
No fixture/test edit is authorized here; this report records the correction for owner review.

## 17. Fresh canonical local verification

The established [verify entrypoint](../../tools/ci/verify.py) five stages are executed using
the same commands/functions, with the established repository-content sanitizer staging used
by P2/ZE1. Ignored owner-local addon backups remain untouched; direct-worktree sanitizer PASS
is not claimed. Godot is4.7.2.stable.steam.ed1daf0bf; no gameplay tests are skipped.

| Fresh pre-commit check | Result |
| --- | --- |
| Full canonical `res://tests/run_tests.gd` | 20,261 assertions / 0 failures, exit0 |
| Python unittest discover, tools/tests | 46 PASS |
| Repository/static | PASS |
| Development headless editor | PASS, exit0 |
| Repository-content release sanitizer | PASS;1,713 repository game files staged;0 validation errors |
| Sanitized validation/editor/main120 | PASS; editor/startup exit0; no script errors |
| Local documentation links/anchors | PASS;245 local targets across10 reviewed documents |
| `git diff --check` | PASS |

Local logs use ignored `build/sfpa-pre-*`. Environment diagnostics remain visible: Windows
root certificate read, configured adb process launch and sandbox-denied external Steam editor
settings write. These are not GDScript parse/test failures. No config change hides them.

After the single documentation commit, the complete canonical/Python/static/development-editor/
sanitizer/sanitized validation sequence MUST pass again on that exact committed HEAD before
push. Post-commit logs use `build/sfpa-post-*`; the completion report supplies exact SHA/results.
Any failure prevents pushing a false PASS and must be returned to owner without production fixes.
The report is not amended merely to insert its own SHA or later execution timestamp.

## 18. Build and PR-CI readiness

[ci.yml](../../.github/workflows/ci.yml) remains unchanged. Ready PRs targeting main run
Godot Verify, Windows Release Build, Android Release Build and iOS Build Validation; the
three builds depend on verification. Normal phase pushes without PR do not run the full matrix.
Main push runs it again; draft PR full validation is skipped. Required gates are not weakened.

**Remote PR CI NOT YET RUN for the final audited head.** No PR/manual dispatch/merge occurs
here. Local sanitized import/startup is not an exported artifact test. Existing platform build
foundations do not prove current Android/iOS physical-device operation. Owner-authorized PR,
four green same-final-head checks, explicit merge and four green post-main checks remain required.

## 19. Security, sanitizer and artifact review

Complete added production/test diff inspected for debug hooks, QA overrides, absolute machine
paths, credentials/tokens, generated files and user saves. No new such production artifact found.
`res://`/`uid://` are legitimate engine references, not machine paths. Existing development
Godot AI remains baseline, unchanged; release sanitizer removes development addon/tests/hooks.
Four intentional test JSONs use isolated fixture state and no account credentials/APPDATA path.
Local live JSONL/logs/screenshots/save and this audit's orchestration remain ignored under build.
No external port, new dependency, packaging config, secret or runtime acceptance backdoor added.

## 20. Current documentation consistency

STATUS and ROADMAP now identify Final Audit PASS WITH RESIDUAL RISKS / awaiting owner PR
authorization,17 Snow zones and unintegrated phase. P1 recommendations, P2 original blocker,
P2B proposed remedy and ZE1 failed first attempt remain historical checkpoint records; their
then-current authorization sentences do not override the later owner decisions or this audit.
The accepted fresh-evidence section supersedes those old live-blocked conclusions.

DECISIONS audit delta=0: both approved durable substitutions were already recorded correctly.
README audit delta=0: it describes integrated main's Hockshop slice and links current status,
not a false claim that main contains unmerged progression. No broad historical text rewrite.
Root2/item3/revision, teacher-contact limitation, all11 knowledge facts and deferred advanced
skills remain consistent. F1 is the disclosed nonmaterial provenance-text exception, not a
claim that the source fixture or historical acceptance was replaced.

## 21. Delivered versus deferred

| Area | Final state |
| --- | --- |
| school1/school2/schoolhall, local gate | Delivered with physical traversal/Open/Close |
| Liu teaching | Bounded contact delivered, all11 knowledge facts retained, unarmed only exposed |
| First apprenticeship | Delivered with exact persisted source result and transient pending |
| Basic unarmed Learn | Existing source rules connected to actual input/RNG/state |
| Natural combat EXP loop | One fresh E0→E2/Flee/recovery/return journey proven |
| Save/Continue | Real process restart and full encoded-state/RNG match proven |
| ZE1 | Narrow Type B delivered and independently audited |
| liuh-ken/fonxanforce/fonxansword/chaos-steps/spider-array | New public gameplay/advanced actions deferred; teacher facts are not implementations |
| enable/mapping UI, practice/exercise/selflearn/study/exert/perform | Deferred; earlier reusable Core is not a newly exposed school service |
| Full Liu combat/equipment/drop/death/respawn | Deferred |
| Guard/李火狮/trainees/full population | Deferred |
| Inner yard, weapon/secret storage, academy/board | Deferred |
| Generic trainer/dialogue/door engine | Not introduced |
| Migration Tooling v1 | Deferred until integrated milestone and separate next-major authorization |

Production diff and runtime entry points were checked, not only prose. Deferred source IDs
appear in knowledge/traceability data, not new selectable techniques or reachable side maps.

## 22. Severity-ranked residual risks

| ID | Severity | Finding / boundary | Integration disposition |
| --- | --- | --- | --- |
| R1 | MEDIUM | Fresh natural recovery/progression is lengthy; nine encounters and substantial idle recovery were required | Bounded reachability passed; pacing/usability qualification and any balance change need separate owner scope |
| R2 | MEDIUM | Historical MudOS random(0) behavior unknown; wound/force/other zero bounds remain separately guarded | ZE1 resolves only the approved observed defense boundary; no new in-scope failure found, no global fix implied |
| R3 | MEDIUM | Project license/provenance remains unresolved in existing ledger | No commercial/store/public-release clearance; does not newly block this internal integration audit |
| R4 | MEDIUM | Final PR and post-main four-job remote gates remain outstanding | Required later integration gates, not local CI claims or permission to merge |
| R5 | LOW | Current progression route not physically qualified on Android/iOS or exported packages | Desktop evidence only; CI builds will not substitute for device acceptance |
| F1 | LOW | Fixture README Old Pine digest transcription error | Exact correct hash recorded in §16; fixture unchanged and restoration passes; owner can authorize documentation correction |
| R6 | LOW | UI repeats read-only Learn cost preview | Currently matches Core; future formula changes must update preview; no duplicate mutation authority |
| R7 | LOW | Full Liu/advanced skills/population/side interiors intentionally absent | Honest staged scope, not promises for this PR |
| R8 | LOW | Remote branch-protection enforcement is separate governance | Existing local policy reviewed; no remote-settings change or fresh enforcement claim |
| R9 | LOW | Workstation headless diagnostics and ignored addon backups affect direct worktree packaging | Established repository-content sanitizer validates shipped content; no owner-local files removed |

License evidence: [LICENSE_PROVENANCE](../production/LICENSE_PROVENANCE.md). Root license is
absent and reference attribution remains inconsistent; no legal determination is made here.
Governance: [REPOSITORY_POLICY](../production/REPOSITORY_POLICY.md).
**HIGH release/integration blockers within the approved milestone scope:0.**

## 23. PR readiness verdict

**READY FOR OWNER PR AUTHORIZATION**, conditional on the mandatory exact-committed-HEAD
local verification completing successfully before push. Approved semantics, physical scope,
save compatibility, critical tests and accepted real-input evidence support PASS WITH RESIDUAL
RISKS. F1 is disclosed as a documentation transcription defect with correct evidence provided;
it does not weaken an executable assertion or conceal a compatibility failure.

The single final PR may be opened only after independent owner review and explicit authorization.
The milestone is implementation-complete and locally audited, not fully integrated on main.

## 24. Exact next owner gate

Finalize this documentation, inspect docs-only delta from frozen6379af74, commit exactly once,
run all required local checks on that commit, push the same phase branch only if PASS, verify
local=origin phase and clean index/worktree, report exact frozen SHA, then STOP.
No PR creation, merge, deletion, history cleanup, next slice or Migration Tooling starts here.
The next owner action is review of this Final Audit and separate authorization for the one
milestone PR. Later CI/merge/main gates remain governed by the repository integration policy.
