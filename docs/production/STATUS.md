# Productionization Status

## Current milestone

Phase 10C1's shared application shell is **FULLY INTEGRATED** on `main` at
`3a1f993a4258ed246ce820c7a4dc8d2563994aaf` (PR #5), with all four post-merge jobs green in
[workflow 33643056093, attempt 2](https://github.com/Toxicccxz/eastern-stories-godot/actions/runs/33643056093).
It builds on the integrated Phase 10B native Save/Load and Phase 10A build/CI foundations.
Phase 10C2's [final major-phase audit passed](../migration/PHASE_10C2_FINAL_AUDIT.md),
and [PR #6](https://github.com/Toxicccxz/eastern-stories-godot/pull/6) merged at
`05f3f28c17c27d8fda9f56e726ddf6e5d09d3bed`. Its first post-merge workflow exposed stale
PhysicsServer Area contact after resident-map reattachment, not mobile lifecycle/input leakage.
[Stabilization PR #7](https://github.com/Toxicccxz/eastern-stories-godot/pull/7) fixed that
production world-runtime defect and merged at `ae381bf3f3e5f4a28a417295eea680d023cc428c`.
[Post-merge workflow 33714114002](https://github.com/Toxicccxz/eastern-stories-godot/actions/runs/33714114002)
passed Godot Verify, Windows Release Build, Android Release Build and iOS Build Validation
on that exact main commit.

**PHASE 10C2 — FULLY INTEGRATED. PHASE 10D — PARKED / FROZEN PENDING COMBAT
EXPERIENCE REDESIGN.**
Phase 10D's [Technical Demo analysis](../migration/PHASE_10D_TECHNICAL_DEMO_RELEASE_GATE_ANALYSIS.md)
is complete. [10D1 physical qualification](../migration/PHASE_10D1_PHYSICAL_DEVICE_QUALIFICATION.md)
has **PASSED its owner-revised, bounded private/internal Technical Demo gate**. The frozen
pristine ARM64 APK installed and ran the production Mobile/Vulkan path on a Xiaomi 13 Pro
and the primary OnePlus 8T. OnePlus real-human evidence covers all eight directions,
physical multitouch, both supported landscape/SafeArea layouts, Android Back and basic
Home/foreground lifecycle. The Xiaomi-only W/SW sluggishness did not reproduce with the
same APK on OnePlus and is not classified as a generalized application-input defect.
This is not general Android/tablet/store or long-duration certification.

Phase 10D2 [Technical Demo packaging](../migration/PHASE_10D2_TECHNICAL_DEMO_PACKAGING.md)
has also **PASSED**. Clean source `995736bf37d2917e8c6f9e53a86ab83ecff3b734`
produced an unsigned portable Windows x86_64 ZIP and ephemeral-QA-signed Android ARM64
APK. External candidate evidence binds the build manifests, sanitized project digest,
artifact SHA-256 values, Android package/version/ABI/certificate and accompanying notices.
The provisional identity and private/internal distribution boundary remain unchanged.

**PHASE 10D1 — PHYSICAL ANDROID QUALIFICATION PASSED. PHASE 10D2 — TECHNICAL DEMO
PACKAGING PASSED. PHASE 10D3 — BLOCKED / SUSPENDED. PHASE 10D FINAL AUDIT — NOT
STARTED.**

A normal-player 10D3 acceptance attempt established that the existing combat experience is not
suitable enough to continue Technical Demo acceptance. Phase 10D3 never passed, and the old
candidate must not be represented as an accepted Technical Demo. The owner approved a Combat
Experience Redesign before release-gate work resumes.

The 10D1 physical Android record remains usable historical evidence for the platform interaction
layer; it does not qualify a future battle presentation. Requalify only affected physical paths if
the redesign materially changes mobile battle input, lifecycle behavior, renderer, or
SafeArea/layout. The 10D2 artifacts and hashes remain valid evidence for their exact source commit,
but become historical-only after production combat changes and must not be reused as redesigned-game
release candidates.
This is not game completion or store readiness.

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
roundtrip, simultaneous contacts and reverse landscape. Phase10D1 separately qualifies the
bounded physical Android interaction path on the named OnePlus ARM64 configuration, with Xiaomi
as comparative evidence. Full normal-player journey, process-death Save/Continue, representative
Save blocking and final candidate runtime/log acceptance belong to 10D3. Extended soak and detailed
performance/memory/thermal profiling are risk-triggered rather than claimed complete. iPhone/iPad
simulator/device runtime remains unqualified.

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
- iOS simulator/device qualification; broad Android/tablet/store certification and
  portrait/split-screen gameplay are not qualified;
- Combat Experience Redesign analysis, implementation, combat validation and integration before
  Technical Demo release-gate work resumes;
- Phase 10D3 normal-player critical journey, Save/process-death/Continue, representative
  Save blocker and final Technical Demo candidate runtime/log acceptance against a newly built
  post-redesign candidate; Phase 10D3 remains blocked/suspended and never passed;
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

The current Phase 10D2 candidate is traceable by external SHA-256 evidence, not claimed
byte-reproducible. Private handoff must accompany an artifact with `THIRD_PARTY_NOTICES.md`,
`LICENSE_PROVENANCE.md` and its candidate evidence record. There is no installer, reusable Android
signing key, cross-build upgrade promise, store identity or public distribution authorization.

The repository has no root project license. See `LICENSE_PROVENANCE.md` for the unresolved ES2
evidence and verified third-party records.
