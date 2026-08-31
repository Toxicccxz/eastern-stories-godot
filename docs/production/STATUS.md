# Productionization Status

## Current milestone

Phase 10A establishes a cross-platform repository/build/CI foundation around the closed Old Pine
playable milestone. It does not declare the game complete, store-ready, production-ready, or fully
migrated.

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
  one-way Pine route.

The current canonical main scene is
`res://scenes/world/oldpine/oldpine_world_session.tscn`.

## Incomplete work

- Combat Phase 5B4 and later full combat parity;
- Cave expansion, Keep, Lake/serpent, and the remaining ES2 world/content;
- application-level native Save/Load integration;
- main menu, Continue, pause/settings, and cross-platform game shell;
- virtual/touch controls, responsive mobile HUD, safe areas/notches, Android Back behavior,
  orientation and mobile lifecycle policy;
- final UI, art, animation, VFX, audio, balance, accessibility, and localization;
- permanent Android/iOS signing, store metadata, installer/package policy, Steam/Play/App Store/
  TestFlight upload, and final release gates.

The Phase 10A pipeline sends the same sanitized game project to Windows, Android, and iOS targets.
Windows and Android Release exports are locally proven. GitHub Actions workflow run `33350605585`
also proved `Godot Verify`, Windows Release, Android Release, and the unsigned iOS Xcode compile on
the same commit, with all three platform artifact uploads succeeding. None of this means the current
desktop-oriented gameplay UX is comfortable or complete on phones/tablets.

## Release and licensing boundary

Phase 10A Windows output is unsigned. Android uses a per-build ephemeral QA key and is not a Play
Store release. iOS is an unsigned Xcode compile validation and is not an IPA, App Store, or TestFlight
build. The provisional mobile identifier is `com.example.easternstoriesgodot`; it is not a domain-
ownership claim and must be replaced before store signing.

The repository has no root project license. See `LICENSE_PROVENANCE.md` for the unresolved ES2
evidence and verified third-party records.
