# Productionization Status

## Current milestone

Phase 10C1's shared application shell is **FULLY INTEGRATED** on `main` at
`3a1f993a4258ed246ce820c7a4dc8d2563994aaf` (PR #5). Phase 10C2 and its resident-map
contact stabilization are also fully integrated at
`ae381bf3f3e5f4a28a417295eea680d023cc428c` through PR #6 and PR #7; all four
post-merge jobs passed in
[workflow 33714114002](https://github.com/Toxicccxz/eastern-stories-godot/actions/runs/33714114002).
These build on the integrated Phase 10B native Save/Load and Phase 10A build/CI foundations.

Phase 10D is **PARKED / FROZEN pending Combat Experience Redesign**. Its bounded Phase 10D1
physical Android qualification and Phase 10D2 Technical Demo packaging passed, but Phase 10D3
normal-player acceptance exposed that the current combat experience was not suitable enough to
continue release acceptance. Phase 10D3 never passed; Phase 10D Final Audit was not started. The
owner approved the redesign before any new Technical Demo candidate or resumed acceptance.

The completed [CXR0 analysis](../migration/PHASE_COMBAT_EXPERIENCE_REDESIGN_ANALYSIS.md)
established the source/current-system evidence. The
[CXR1 Active Semi-Auto V1 design](../migration/PHASE_COMBAT_ACTIVE_SEMI_AUTO_V1_DESIGN.md)
is now complete and locks automatic ordinary combat plus player-triggered tactical intervention,
with a dedicated encounter, frozen world, one-slot action queue, typed events, and replaceable
battle presentation. **CXR2 — CombatEncounter Core is ready to begin, but has not started.**

Phase 10D1 remains conditional historical evidence for platform interaction only; it does not
qualify the future battle presentation. Repeat only affected device evidence if the redesign
materially changes mobile battle input, lifecycle, renderer, or SafeArea/layout. Phase 10D2
artifacts and hashes remain evidence for their exact source commit, not release candidates after
combat changes. This is not game completion or store readiness.

Completed local shell capabilities are Main Menu, explicit New Game/Continue, Pause/Resume and Save,
explicit backup/temp recovery, confirmed Return to Menu, and independent Settings with desktop
Windowed/Fullscreen. Shared keyboard/mouse/controller semantic navigation has desktop runtime proof;
this does not claim physical controller or mobile-device qualification. See the
[Application Shell contract](contracts/APPLICATION_SHELL_CONTRACT.md) and
[final integration audit](../migration/PHASE_10C1_FINAL_AUDIT.md).

The mobile shell provides shared responsive Shell/HUD/Inventory/Loot, SafeArea, sensor landscape,
eight-direction touch pad, Android Back, lifecycle freeze and explicit Resume. Save remains
manual-only: background triggers no Save. The [Mobile Application contract](contracts/MOBILE_APPLICATION_CONTRACT.md)
defines these extensions without replacing Shell/Host or native persistence authority.
Installed Android emulator evidence covers touch/Back, lifecycle, restart durability, Cave
roundtrip, simultaneous contacts and reverse landscape. Phase 10D1 separately provides bounded
physical ARM64/Vulkan/touch/multitouch evidence on the named Android devices; it is not broad
Android/tablet/store certification. iPhone/iPad simulator/device runtime remains unqualified.

Formally closed gameplay foundations include:

- typed character attributes/resources, recovery, conditions, and lifecycle thresholds;
- Skill Core, cultivation, Practice, Selflearn, Learn, and authored progression effects/policies;
- item identity, containment, stacks/currency, inventory transfer, equipment, and armor;
- native item save DTO/validation foundation, item destruction, death/corpse, loot, and legacy
  autoload import boundary;
- ordinary combat math, attack resolution, force policy, progression/busy completion,
  relationships, reciprocal attack composition, and the first playable combat slice;
- NPC/world/spawn typed foundations and authored Old Pine bandits/loadouts;
- one resident Old Pine Session with Outdoor/Cave map lifetime;
- Vine traversal, Passage Cave/SouthExit roundtrip, Waterfall, River, Cliff, and source-faithful
  one-way Pine route;
- typed native Save snapshots/JSON/repository, exact item and RNG continuation, fresh world/NPC/corpse
  reconstruction, restart-stable Save eligibility, transactional Session replacement, and fresh-process
  Outdoor/Cave restore proof.

The current canonical main scene is
`res://scenes/application/application_shell.tscn`. It owns one persistent Runtime Host, which alone
owns zero or one replaceable Old Pine Session. Cold start shows Menu, not hidden gameplay.

## Runtime contact invariant

Outdoor zone notifications must match the current character/zone collision shapes before
changing typed location. A reattached resident body can briefly have a previous transform
in PhysicsServer; its resulting Area notification and `overlaps_body()` cache are not
current-position authority. Revalidate actual shape contact, including body-edge overlap,
without delaying traversal, moving the player again, or changing Shell/Host ownership.

The reported mobile lifecycle stack was the full runner's final error aggregation, not
the assertion site: the earlier Vine test failed even with zero input and no Shell.
Logical-only test fixtures use existing typed location setters, not fabricated Area entry.
Mobile held-action clearing, echo quarantine, pause and manual-save behavior are unchanged.

## Incomplete work

- Combat Phase 5B4 and later full combat parity;
- Cave expansion, Keep, Lake/serpent, and the remaining ES2 world/content;
- CXR2-CXR10 Combat Experience Redesign implementation, validation, audit, integration, and a new
  post-redesign Technical Demo candidate before Phase 10D3 may resume;
- broader physical Android/tablet qualification and iOS simulator/device qualification;
  portrait/split-screen gameplay is not qualified;
- final UI, art, animation, VFX, audio, balance, accessibility, and localization;
- permanent Android/iOS signing, store metadata, installer/package policy, Steam/Play/App Store/
  TestFlight upload, and final release gates.

The Phase 10A pipeline sends the same sanitized game project to Windows, Android, and iOS targets.
Windows and Android Release exports are locally proven. GitHub Actions workflow run `33350605585`
also proved `Godot Verify`, Windows Release, Android Release, and the unsigned iOS Xcode compile on
the same commit, with all three platform artifact uploads succeeding. The current mobile phase's
emulator evidence is separate from those historical build results; neither establishes broad
phone/tablet hardware usability or store readiness.

## Release and licensing boundary

Phase 10A Windows output is unsigned. Android uses a per-build ephemeral QA key and is not a Play
Store release. iOS is an unsigned Xcode compile validation and is not an IPA, App Store, or TestFlight
build. The provisional mobile identifier is `com.example.easternstoriesgodot`; it is not a domain-
ownership claim and must be replaced before store signing.

The repository has no root project license. See `LICENSE_PROVENANCE.md` for the unresolved ES2
evidence and verified third-party records.
