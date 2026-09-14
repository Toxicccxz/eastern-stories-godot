# Snow Hockshop / Loot Monetization — H3 Physical Runtime

## Result and continuation boundary

**H3 IMPLEMENTATION COMPLETE — AWAIT OWNER REVIEW.** This is the H3 slice verification,
not the separately authorized Final Audit or major-milestone integration.

Branch: `phase/snow-hockshop-loot-monetization`. Recovery began at the approved H2 HEAD
`84fdeb4b5e3c2318b6837183fba4414e088026c2`, with seven modified tracked files and eight
untracked H3 files. Their complete diff/content was reviewed before changes. The existing
room, door, panel and tests were retained; recovery required no further gameplay corrections.
No reset, stash, clean, rebase, branch recreation, main merge or removal of existing work occurred.

[H2](PHASE_SNOW_HOCKSHOP_LOOT_MONETIZATION_CORE.md) is owner approved. Its valuation,
payout and item lifecycle implementation is unchanged. The
[H1 source contract](PHASE_SNOW_HOCKSHOP_LOOT_MONETIZATION_CONTRACT.md) and
[approved decisions](DECISIONS.md#hockshop-valuation--payout--sell-lifecycle-h2) remain authority.

## Implemented boundary

- `snow.hockshop` is a continuous front-room zone in the existing Snow outdoor resident.
  Snow now has thirteen outdoor zones plus the Inn. Physical walls, counter and a two-sided
  local door replace the old inaccessible frontage. The back-room curtain is visibly deferred.
- The authored door starts closed, opens through a local real control from either side, and
  stays open while that resident survives in the live Session. Cold Continue restores closed.
  No Close command, persistent door state, generic door engine or loading portal was added.
- Trade requires the active, available, noncombat Session, Hockshop zone, valid physical position
  and counter proximity. The panel lists current direct Inventory children with exact instance
  IDs and equipment labels; it does not rely on the incomplete Old Pine inventory projection.
- Value delegates to H2. Sell requires fresh confirmation, rechecks location/item/food/liquid/
  equipment state, consumes that confirmation once and delegates to the existing H2 service.
  Receipts report actual delivered money, including partial/zero delivery and technical failure.
  Money is shown as holdings rather than sale goods. No wallet or merchant authority exists here.
- Input is quarantined while the panel is open. Closing or detaching an unopened panel does not
  touch movement ownership: the recovered correction retains the `was_open` guard.
- Placement validation excludes the closed door footprint even when open, preventing a legal
  save from restoring into the closed door. Interior saves retain their exact physical position.
  Root schema2, item schema3 and SOURCE_ENTRY_V1 are unchanged.

Files: Snow definitions, placement validator, Session/Snow controllers, Snow scene, Hockshop UI,
the focused/cold H3 runners and runtime test, canonical runner registration and the north-spine
zone expectations. This report, STATUS and ROADMAP record the slice; DECISIONS is unchanged.

## Source and distinct verification

Recovery reread `reference/es2/mudlib/d/snow/hockshop.c`, `d/snow/mstreet3.c`, inherited
`std/room.c` door creation/open/close/leave behavior, and `std/room/hockshop.c` valuation/sell/
payout order. No external port was consulted; no legacy file changed. H2's full inherited item,
equipment, movement and currency analysis remains in its source report.

Separate inspection after the test run confirmed that UI/geometry own physical permission and
presentation, while H2 retains economic authority. Direct Inventory enumeration preserves exact
identity; no new money/item store was introduced. Door state belongs to the resident, not Save.
The expected closed-door footprint, counter collision, pending-confirmation invalidation and
unopened-panel input guard were reviewed against the actual implementation and acceptance evidence.

## Fresh automated evidence — 2026-09-14

All commands below completed with exit code 0; these are fresh results, not the earlier session's counts.

| Check | Result | Local evidence under ignored `build/` |
| --- | --- | --- |
| H3 focused runner, including fresh-process writer/reader | 107 assertions, 0 failures | `h3-recovery-focused.log` |
| H2 focused regression | 298 assertions, 0 failures | `h3-recovery-h2.log` |
| Complete `res://tests/run_tests.gd` | 19,844 assertions, 0 failures | `h3-recovery-canonical.log` |
| Python tooling suite | 46 tests, OK | `h3-recovery-python.log` |
| Additional old-position restore/input regression | 12 assertions, 0 failures | `h3-recovery-old-continue.log` |
| Repository checks and development headless editor | PASS | `h3-recovery-editor-output.log` |
| Repository-content sanitizer | 1,692 repository files copied; zero validation errors | `h3_recovery_sanitize.py` |
| Fresh sanitized editor and 120-frame headless main startup | PASS | `h3-recovery-sanitized-editor-output.log`, `h3-recovery-sanitized-startup.log` |

The extra recovery probe restores existing Snow and Old Pine positions, checks fresh movement
ownership, confirms unopened-panel close does not alter it, and uses normal input/physics to walk.
Its fixture handoff is a serializer/input regression, not live reachability proof. The canonical
suite includes the unchanged old Snow spine cold-Continue movement regressions. The previous
canonical log's two movement failures did not recur. No test was weakened.

Sanitization used tracked plus nonignored untracked repository content, including H3, so owner-local
ignored addon backups remain untouched and excluded. No packaged artifact or device qualification
is claimed. The Windows sandbox emitted `Failed to read the root certificate store` at headless
startup; the checks exited successfully with no gameplay/script failures. No production workaround
was made for that environmental diagnostic.

## Real-player evidence

The canonical application main scene launched the production `OldPineWorldSession`. Godot AI's
authenticated installed SDK recovered access despite the connector tools being absent from this
recovery session. An editor launch argument aligned the debugger listener with the project's
existing 6107 target. No addon or committed machine configuration changed. The editor's automatic
removal of two viewport defaults was restored exactly before completion.

Successful runs reported `helper_live=true`, `session_active=true`, `game_capture_ready=true`,
and startup `current_run_errors=[]`. Final game logs contained eight informational entries and no
errors. Captures were nonstale and advanced within each run; frame counters reset on cold restart.
One earlier QA-only multiline name-entry expression failed with mixed indentation and required a
restart. Simple Unicode key events then entered the name successfully. One immediate stop/run
attempt remained stopped and was retried successfully. Neither is a production test failure.

The main journey used actual framebuffer clicks, key events and frame-timed movement actions:

1. New Game created 林行 in the Inn. Before physical traversal, a disclosed QA fixture set effective
   strength200 and experience250000 using existing typed state. No items, positions, loot, results,
   formulas or RNG implementation were injected. The temporary strength modifier was removed after
   commerce when the existing Save guard correctly refused to serialize it; experience remains a
   nondefault persisted fixture. This is a commerce/reachability proof, not a new-player combat-balance claim.
2. Walked Inn → Snow square/south road/east roads → actual Old Pine north passage → south slope.
   Selected a production bandit by framebuffer click and used the real Attack button. Normal combat
   cadence defeated it. Selected its corpse, opened Loot and took only its short sword; left silver.
3. Physically returned to Snow/mstreet3. Closed collision stopped at x70.993, y−997.003; trade was
   unavailable. Clicked Open, walked into `snow.hockshop` to x327.660 and opened the counter panel.
4. Selected the exact looted sword. Real movement input left the player stationary while the panel
   was open. Value showed300/240. Sell opened a separate confirmation with no payout yet. A fresh
   confirm click removed that exact ID and delivered silver2 + coin40; receipt said actual240.
5. Closed the panel, physically left for mstreet3, walked to the Inn and bought a dumpling15 and
   wineskin20 through the existing waiter buttons. Real Pause/Save succeeded after QA cleanup.
   Terminated the game process, launched anew and clicked Continue. Complete encoded snapshot
   equality passed, including sale absence, supplies, money, position and allocator7. Snapshot SHA-256:
   `a1213ca459cd498895a8c711c6a7ca06de08894174b74300303db69af60f30fd`.

Separate inside-save route: physically revisited Hockshop, opened its fresh closed door, entered
and used Pause/Save at `(331.3264465, -1001.0021362)`. After process termination and real Continue,
whole-snapshot equality passed, the panel was closed, and the door was closed. Snapshot SHA-256:
`1e653ca7f05c306ac9877ed3c07306463dcd3e5e21dccbb05cf530b0d6cca75c`.
Real left input hit the inside door at x129.007. Clicking Open and walking left reached mstreet3
at x0.674. No teleport, body-entered callback, controller traversal or manual signal supplied this proof.

The old Snow crossroad save also cold-continued and moved from x270.993 to226.925 with fresh input;
quarantine was false. Screenshots and every successful input/read result are retained in
`build/h3-recovery-live-events.jsonl` and `build/h3-recovery-frame-*.png`. Representative frames:
28424 (sale receipt), 36789 (Inn Save), 28 (Inn cold Continue), 111 (inside cold Continue),
1353 (physical inside-door exit). These are local evidence, not committed assets.

## Stop boundary

No known H3 product failure remains. No pawn, executable hockshop2, generic door/merchant system,
new save schema, unrelated service or H2 semantic change was introduced. Exact forbidden-delta,
Markdown file-link, trailing-whitespace and `git diff --check` checks pass at closure.
The exact allowlist contains eighteen changed files; all96 local Markdown file links in the
current Hockshop reports/STATUS/ROADMAP resolve. All1,692 sanitizer input files remain byte-identical
to the final game files, including the restored viewport settings.

No Hockshop PR exists (GitHub branch PR search returned none). No Final Audit or PR was started.
This branch has no new integration CI claim; H3 is not merged. Prior main's recorded green
post-merge run remains historical baseline evidence, not H3 CI. Commit/push this slice only,
then stop for owner review; Final Audit and milestone integration await separate instruction.
