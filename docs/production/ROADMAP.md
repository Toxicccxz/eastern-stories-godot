# Productionization Roadmap

Each numbered item below is currently planned as an independent major integration milestone: one
major-phase branch and one final PR, unless a later explicit planning decision changes that boundary.
Internal analysis, implementation slices, and audit fixes remain on that milestone's branch.

1. **Phase 10A — Cross-Platform Repository / Build / CI Foundation — Complete**

   Pin Godot 4.7.2, verify the repository, sanitize one production project, and prove Windows,
   Android, and unsigned iOS build pipelines through CI artifacts.

2. **Phase 10B — Native Save / Load Integration — Complete**

   Connect the existing typed persistence foundations to the playable application/session.

3. **Phase 10C1 — Cross-Platform Game Shell — Next; not started**

   Add the application-level menu, Continue, pause, and settings flow without platform gameplay
   forks.

4. **Phase 10C2 — Mobile Input / Layout / Lifecycle Adaptation**

   Make Android/iOS comfortable to play through touch controls, responsive/safe-area-aware UI, and
   explicit mobile lifecycle behavior.

5. **Phase 10D — Technical Demo Release Gate**

   Establish final technical gates, permanent identity/signing policy, and release-oriented
   packaging/store preparation.

After Phase 10D, perform a new planning review before resuming large-scale authored content. This
roadmap intentionally avoids speculative phase expansion.
