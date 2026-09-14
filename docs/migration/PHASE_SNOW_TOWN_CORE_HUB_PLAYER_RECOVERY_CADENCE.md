# S5B — Player Recovery / Metabolism Cadence

Current owner-review status: **OWNER APPROVED / CLOSED** at
`add93fcf17aba82ebc05bbf5c3eb9972feb73e4d`. Recorded during authorized
[S6A analysis](PHASE_SNOW_TOWN_CORE_HUB_WATER_DRINK_SOURCE_CONTRACT.md).
S6B implementation and the final Snow PR remain unauthorized. The implementation/evidence body
below preserves its original checkpoint; S5B A–M decisions are unchanged.

## Scope and authority

Implementation on `phase/snow-town-core-hub`, starting at exact local/remote
`f52cb69041125b12b8b9121aa2cc4125b54b3778`. Main remains
`047f29083e881156abbdad6ed480bffc1350dfa8`. S5A is OWNER APPROVED / CLOSED.
The separate, pre-implementation decision commit is
`1f515b4d9585fb8d45b419237768eedfbe698441` — `Record owner-approved S5B recovery decisions`.
The implementation commit is titled `Add player recovery metabolism cadence`.
No final PR, merge, or next slice is authorized. This is implementation evidence for owner review,
not a declaration of major-milestone integration.

[S5A source contract](PHASE_SNOW_TOWN_CORE_HUB_RECOVERY_METABOLISM_CONTRACT.md) and
[DECISIONS](DECISIONS.md) distinguish source semantics from the approved A–M substitutions.
Rechecked primary LPC: `reference/es2/mudlib/std/char.c`, `feature/damage.c`,
`feature/condition.c`, `include/condition.h`; the bundled `doc/efuns/random`,
`doc/efuns/set_heart_beat`, and `doc/efuns/save_object` explain bounds/transient timing.
No driver was executed and no external port was used. Existing raw-skill, busy, condition payload,
Session/map handoff, combat gate, Host publication, and Save/Restore dependencies were inspected.

**2.0 seconds is an owner-approved Type B Native base period, not a proven ES2 wall-clock period.**
ES2 supplies the post-decrement count and heal semantics. Native active delta supplies embodiment.
Combat/condition/life exclusions below are explicit staged omissions, not full source parity.

## Smallest authority chain

`Session._process(delta)` → eligibility → `PlayerRecoveryCadence`
→ fresh `RecoverySkillLevels(raw magic, force, spells)` → unchanged `CharacterRecovery.apply_tick`.

- `PlayerRecoveryCadence` is a typed `RefCounted`, with one float remainder and one source count.
  It owns no Player, Node, Timer, world graph, persistent state or callback dispatcher.
- `RecoveryCadenceRandomSource` supplies one typed 5–14 draw. Production
  `GodotRecoveryCadenceRandomSource` owns a private, per-Session `RandomNumberGenerator`.
  It does not use the global RNG or any of the three existing saved gameplay streams.
- `PlayerRecoveryCadenceResult` reports typed outcome, processed/busy pulse counts, opportunity
  count and the last source update count. It is diagnostic output, never gameplay authority.
- Only the existing Session adapter changes. It advances recovery before the combat scheduler,
  so a frame which began in combat cannot become recovered world time because combat ended later.
  Combat scheduling itself is untouched. No per-map cadence or new UI is added.

## Exact pulse and eligibility contract

One eligible initialization draw stores 5–14; remainder starts at zero. Every complete 2.0s is
processed, retaining the tail. Busy at pulse entry consumes that time pulse but neither decrements
the source count nor draws/heals; S5B never advances/clears busy itself. Otherwise a positive count
decrements. On old zero, draw/store the next count **before** exactly one heal opportunity.
Thus resets 5, 6, 14 produce opportunities on pulses **6, 7, 15**, respectively. There is no
extra recovery because the newly drawn count happens to be small. Update count zero does not stop
the Player cadence.

Negative/non-finite delta and arithmetic which cannot represent subtracting one pulse are rejected
without changing the prior phase. There is no arbitrary delta/pulse cap, dropped tail, deferred
backlog, wall-clock reconstruction or offline catch-up. The representability check avoids an
unexecutable floating-point subtraction loop; it is not a gameplay timing maximum.

Full phase freeze (no delta, count, RNG or heal):

- non-`SOURCE_ENTRY_V1`, missing/non-live Player, non-ACTIVE life status;
- paused/non-processing Session, restore staging, suspended candidate swap/reparent;
- active encounter **or** fighting relationships, even if a gate is accidentally open;
- **any** condition payload, including unsupported IDs and zero/negative values;
- closed world simulation gate, in-progress map handoff, detached/invalid active map;
- committed partial handoff, or failed location commit whose source was detached and not restored.

A successfully restored old map owner may resume the exact old phase. Successful Inn ↔ Snow ↔
Old Pine handoffs do not recreate/reroll cadence. Bank and Workplace remain zones of the same Snow
resident. Fresh source Session creates one authority; restore staging creates none and draws none;
successful activation creates its fresh authority synchronously before publication. Staging cannot
tick. No asynchronous publication window or save hook is added.

## Existing formulas and observable results

`CharacterRecovery` remains unchanged: decrement positive water, then positive food. Post-decrement
water below one blocks all Player recovery; post-decrement food below one blocks only internal
resources. In between, gin/kee/sen recover with integer `con/3 + atman/10`, `con/3 + force/10`,
`con/3 + mana/10`, respectively. Current caps at the **old effective**, then effective gains one
when below maximum. Internal atman/force/mana use **current raw** magic/force/spells divided by two,
not mapped/effective skill values. No formula, capacity, effective/current/max or rounding change.

Deterministic integration expectations, calculated from LPC and executed through existing services:

| Case | Verified result |
| --- | --- |
| Fresh first opportunity | food/water 400→399; full gin/kee/sen unchanged; update count 2 |
| Work once / twice | 70→80 / 40→50 gin and sen on one opportunity |
| Work three times | 10→20 (still too tired)→30→Work succeeds, costs leave 0 |
| Six opportunities after two Work | 40→100, without changing Work |
| Natural first bite | real Work/Bank/purchase, first metabolism399, Eat459; portions2/value0 |
| Overshoot | 59 more opportunities459→400, Eat refused; 60th→399 permits another bite |
| water1, food positive | water0/food decremented; no primary or internal recovery |
| food1, water positive | food0/water decremented; primaries recover, internal resources do not |
| raw levels3, then force9 | internal gains1, then force gains4; mapped999 irrelevant |

Food has no automatic capacity clamp; eating cannot refill water. Water remains a real eventual
limit. No new drink, thirst damage, starvation, food floor, recovery buff or rate multiplier exists.
Conditions remain dormant: no update, expiry, poison damage or `CND_NO_HEAL_UP` aggregation occurs.
The existing no-heal argument remains false only after proving an empty condition collection.

## Save / RNG contract

Root schema2, embedded item schema2 and `SOURCE_ENTRY_V1` stay exact. There are no new JSON keys,
timestamps, RNG fields, migration or revision. Player resources/items retain existing Save authority.
Live Save does not reset phase. Pause, handoff, combat/condition freeze and failed swap resume draw
zero times. New Session/Continue draws once; old count/remainder and recovery RNG are not restored.
Each reached opportunity draws once before healing. Tests compare all three persisted RNG streams
through substantial recovery and restore, with no extra draws.

An archive of **exact f52cb69041125b12b8b9121aa2cc4125b54b3778** generated a legal pre-S5B file
using its existing dumpling cold-process writer. Current code cold-Continued it in another process:
all persisted snapshot facts equal, file bytes unchanged, schema/revision unchanged, new count5–14
and remainder0 before the first pulse. That historical writer's controlled food fixture is old-save
compatibility evidence only, not the natural player journey below.

## Desktop acceptance — actual canonical ApplicationShell

Godot 4.7.2 Steam, isolated **test save profile only** `s5b-live-20260913` selected before each
journey. No Player resource, skill, condition, RNG, inventory, position or portal state was injected.
Unicode key events entered `雪息`; mouse selected female and Start Journey. Keyboard action events
drove CharacterBody movement and actual Area entry; button coordinates came from the visible UI.
No controller/portal/Work/Bank/Eat callbacks were called to substitute for player actions.

1. New Game, Inn→Square→mstreet1→mstreet2→Workplace. Two actual Work clicks produced silver2;
   first observed gin/sen70 with food/water396, then50/50 with395/395 (an actual recovery occurred
   between observations). This is elapsed live behavior; exact synchronous Work costs are proved
   separately above.
2. Walk to Bank, Convert silver1→coin100; physically return through Square into Inn, approach waiter,
   buy one dumpling. Remaining money: silver1 + coin85. At purchase observation gin/sen80 and
   food/water392. Subsequent natural recovery reached gin/sen100.
3. Actual Eat click: **food390→450**, portions3→2, stored current_value0; no water refill. Fresh
   food400 and subsequent392/390 were observed without QA edits. Exact399→459 is the deterministic
   source-derived fixture, not a fabricated desktop observation.
4. Real Escape Pause exceeded2s: food450/water390, gin/sen100, count6, remainder
   `1.7690450000005` remained exactly unchanged across observations. Actual Save button wrote a
   valid file. Process32728 terminated; fresh canonical process62728 used real Continue.
5. Before its first pulse, the **entire recaptured gameplay snapshot** equaled the saved snapshot,
   including money/food/allocator5 and Inn position `(-240.3333435,-102.6666489)`. Initial phase was
   **count9/remainder0**, not6/1.769. File bytes remained identical; no instant duplicate/offline heal.
   The test's hex-bytes SHA256-text fingerprint was
   `9b6ba35f21e892ce3ddc9702d50aed9005052ace10461dfbee256547bd4cbaa2`.
6. After another long Pause, actual Resume for2.2s advanced count9→8 and remainder
   0.013636→0.226970 only; food stayed450. Real Escape paused again. No accumulated pause catch-up.

Helper health was live/session_active/capture_ready true. Non-stale captures advanced (first
process frame22360; fresh process3800→9162). Fresh process launch `current_run_errors=[]` and
current game log contained no errors. The previous editor had stale new-class metadata; editor
restart fixed it without gameplay changes. A later **QA-only read expression** referenced nonexistent
`CharacterStateSnapshot.recovery`, causing a debugger error; it did not mutate/save resources.
The next fresh-process comparison used the typed capture/codec and passed. Neither tooling incident
is counted as gameplay success or hidden as a production defect. No combat/conditions on this route.

## Validation and distinct self-audit

- Focused `res://tests/run_snow_recovery_tests.gd`: **184 assertions, 0 failures, exit0**, including
  process-separated file Save/Continue, all count traces, raw-skill refresh, zero update count,
  busy versus freeze, map/encounter/condition/life/staging/swap cases and independent authorities.
- Canonical `res://tests/run_tests.gd`: **19,018 assertions, 0 failures, exit0** on final code.
- Python unit suite: **46 PASS**. Repository static checks PASS; Godot4.7.2 development editor
  headless, repository-content release sanitizer/validation, sanitized editor headless and sanitized
  canonical-main120-frame smoke PASS/exit0. Isolated Windows headless runs emit the existing OS
  root-certificate-store diagnostic; no script/parse failure. These are local checks, not PR CI.
- Final `git diff --check`, changed-file trailing whitespace and relative documentation link checks:
  PASS. `reference/es2`, project settings, builds/CI/exports, existing recovery/condition/combat/
  economy/Save implementations have zero delta. Only Session's new recovery composition touches
  an existing production file. No owner-local tooling/config/backups are included in either commit.
- Initial canonical run found one obsolete NGE4 route assertion: fixed food400 after a long walk.
  Its portal fixture now disables **only Session process-owned schedulers**, leaving physics/input
  and all exact identity/resource assertions intact. S5B explicitly tests cadence + map continuity;
  the desktop route above proves simultaneous live metabolism. No production suppression for tests.
- Separate self-audit identified failed location commit **plus failed source rollback** as a missing
  eligibility rejection. Corrected only the S5B guard, adding failed/fully-restored/partial-commit
  cases. Map transition behavior, resource formulas and combat scheduler remain untouched.

No generic heartbeat, Timer, global RNG, Save extension, NPC recovery, busy owner, condition runner,
combat-loop modification, off-line simulator or economy/food rule is introduced. Owner-local
ignored Godot AI update backups remain untouched; sanitized validation uses tracked/nonignored
repository content, not a misleading claim that those local backups pass production allowlisting.

## Deferred / stop

Combat recovery, shared condition/recovery cadence, NPC recovery, unconscious/ghost recovery,
revival, drinking sources, age, idle/logout and offline simulation remain deferred. Integrating
conditions/combat later must revisit their explicit full-freeze omissions, not silently weaken the
guard or reuse Combat cadence as a MudOS heartbeat. Existing `RecoverySkillLevels` remains a narrow
raw-value input; there is no additional SkillSystem or condition abstraction.

Next slice is not authorized. Await owner review; Snow is not yet integrated on main.
