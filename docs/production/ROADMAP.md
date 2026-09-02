# Productionization Roadmap

Each numbered item below is currently planned as an independent major integration milestone: one
major-phase branch and one final PR, unless a later explicit planning decision changes that boundary.
Internal analysis, implementation slices, and audit fixes remain on that milestone's branch.

1. **Phase 10A — Cross-Platform Repository / Build / CI Foundation — Complete**

   Pin Godot 4.7.2, verify the repository, sanitize one production project, and prove Windows,
   Android, and unsigned iOS build pipelines through CI artifacts.

2. **Phase 10B — Native Save / Load Integration — Complete**

   Connect the existing typed persistence foundations to the playable application/session.

3. **Phase 10C1 — Cross-Platform Game Shell — Complete**

   Shared application menu, New Game/Continue, Pause/Save, explicit recovery, Return to Menu, settings,
   and focus/input boundaries are fully integrated at `3a1f993a4258ed246ce820c7a4dc8d2563994aaf`
   through PR #5, with all four post-merge main CI jobs green.

4. **Phase 10C2 — Mobile Input / Layout / Lifecycle Adaptation — Analysis complete; implementation not started**

   Analysis is based on green integrated Phase 10C1. Planned slices are 10C2A responsive presentation/
   safe area/orientation, 10C2B touch/Android Back, and 10C2C lifecycle/mobile release validation,
   all on `phase/10c2-mobile-input-layout-lifecycle`. See the
   [analysis and acceptance plan](../migration/PHASE_10C2_MOBILE_INPUT_LAYOUT_LIFECYCLE_ANALYSIS.md).

5. **Phase 10D — Technical Demo Release Gate**

   Establish final technical gates, permanent identity/signing policy, and release-oriented
   packaging/store preparation.

After Phase 10D, perform a new planning review before resuming large-scale authored content. This
roadmap intentionally avoids speculative phase expansion.
