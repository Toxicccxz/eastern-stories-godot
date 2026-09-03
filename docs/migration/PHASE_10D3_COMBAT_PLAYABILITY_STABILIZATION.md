# Phase 10D3 — Fresh New Game Combat Playability Stabilization

Status: **IMPLEMENTATION AND AUTOMATED VALIDATION COMPLETE; REBUILT WINDOWS
CANDIDATE AND NORMAL-PLAYER COMBAT/LOOT REVALIDATION PENDING.** Phase 10D3
acceptance remains blocked until that player-visible path passes.

## Blocker and diagnosis

The owner could not defeat any encountered enemy from a Fresh New Game in the
pristine Phase 10D2 Windows candidate, so the required combat -> corpse -> loot
journey was not accepted.

The production path was reproduced without QA state, injected randomness or
direct combat calls. The starting long sword was equipped, ordinary attacks were
accepted, cadence/busy and reciprocal fight relationships operated normally, and
contact with the centre South Slope scout established one opponent rather than an
automatic three-opponent fight. Runtime evidence included ordinary dodges, a
riposte and a 19-point hit; the player died while the selected scout remained
unhurt.

The mismatch was the product bootstrap, not an attack-resolution defect:

- `CombatSliceDemoFactory.create_player()` is a reusable symmetric Phase 6
  prototype with combat experience 10. Its raw sword 10 is effective sword 5;
  integer division makes the staged skill term zero at spirit 100, so its actual
  sword power is 10.
- The ordinary authored Old Pine bandit has combat experience 600 and raw sword
  10, hence actual sword power 600. The pre-fix non-busy hit comparison was
  therefore approximately 0.027% for the player versus 96.75% for the bandit.
- Tall and fat bandits are stronger comparison content and are not treated as
  starter targets.
- The bounded demo exposes no natural prerequisite progression route comparable
  to the broader legacy game before the player reaches this authored Old Pine
  content.

Root-cause classification is **B + C**: the Fresh New Game Technical Demo state
was unsuitable for the selected authored region, and the bounded demo omits the
broader progression route that the region can assume. No authored NPC statistic,
spawn, aggression rule, combat formula or RNG ordering was changed.

## Approved narrow product decision

The owner approved a New Game-only Old Pine bootstrap of combat experience 600.
`OldPineWorldSessionController` applies it after creating the reusable prototype
and before constructing the authoritative `WorldPlayerRuntimeState`.

This keeps the boundaries explicit:

- the generic Phase 6 prototype remains combat experience 10;
- RESTORE uses the exact saved player state and does not reapply the bootstrap;
- all player attributes, skills, resources and starting equipment are unchanged;
- ordinary, tall and fat bandit definitions and loadouts are unchanged;
- the three South Slope spawns, relationship logic, attack cadence, formulas and
  random sources are unchanged.

With raw sword 10/effective sword 5 on both sides, the New Game player and the
ordinary bandit now each have LPC-derived sword power 600. This is a bounded
Technical Demo entry decision, not a claim that combat balance is complete.

## Regression coverage

`oldpine_world_session_test.gd` now proves that:

- a Fresh New Game Session receives combat experience 600;
- the reusable Phase 6 player factory remains at 10;
- the New Game player and first ordinary authored bandit each calculate sword
  power 600 through the production `CombatMath` path;
- the existing twelve-item bootstrap invariant remains in the same test.

Validation after the stable change:

- Phase 9B3B3 focused runner: **2,471 assertions PASS**;
- Phase 9B1 focused runner: **4,181 assertions PASS**;
- canonical verification: Python tooling **46 tests PASS**, complete Godot suite
  **14,928 assertions PASS**, development editor validation PASS, release
  sanitizer and sanitized-project editor validation PASS.

The Windows candidate used for the failed Phase 10D3 combat journey is invalid
for further combat acceptance because it predates this bootstrap correction. A
new clean-source Windows candidate must be built and the normal-player
combat -> corpse -> loot -> continue-playing segment must pass before the blocker
is cleared. Android physical qualification is not repeated because the change is
platform-independent starting data and does not alter input, lifecycle, renderer
or packaging behavior.

## Authoritative and native sources checked

Authoritative LPC:

- `reference/es2/mudlib/d/oldpine/npc/bandit.c`
- `reference/es2/mudlib/d/oldpine/npc/tall_bandit.c`
- `reference/es2/mudlib/d/oldpine/npc/fat_bandit.c`
- `reference/es2/mudlib/d/oldpine/spath1.c`
- `reference/es2/mudlib/d/oldpine/clearing.c`
- `reference/es2/mudlib/d/oldpine/npath1.c`
- `reference/es2/mudlib/d/snow/eroad3.c`
- `reference/es2/mudlib/d/oldpine/obj/long_sword.c`
- `reference/es2/mudlib/d/oldpine/npc/obj/short_sword.c`
- `reference/es2/mudlib/adm/daemons/combatd.c`
- `reference/es2/mudlib/std/char.c`
- `reference/es2/mudlib/include/login.h`

Native paths traced include the Phase 6 demo factory, Old Pine Session bootstrap,
NPC/spawn definitions, combat math/resolution, relationship orchestration,
equipment binding, cadence, death/corpse and loot paths.

## Deferred

- broad combat balance or full LPC combat parity;
- a difficulty system, tutorial, new starter enemy or new training/progression UX;
- changes to authored NPCs, aggression or encounter composition;
- Phase 10D3 final acceptance and Final Audit.

