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

4. **Phase 10C2 — Mobile Input / Layout / Lifecycle Adaptation — Complete / Fully Integrated**

   Shared responsive/safe-area presentation and sensor landscape, touch pad/Android Back,
   lifecycle freeze/explicit Resume and manual-save-only durability have passed A/B/C and
   the [final major-phase audit](../migration/PHASE_10C2_FINAL_AUDIT.md). PR #6 and the
   resident-map contact stabilization PR #7 are integrated at
   `ae381bf3f3e5f4a28a417295eea680d023cc428c`, with all four post-merge jobs green in
   [workflow 33714114002](https://github.com/Toxicccxz/eastern-stories-godot/actions/runs/33714114002).
   The [mobile contract](contracts/MOBILE_APPLICATION_CONTRACT.md) records consumer boundaries
   and the still-open hardware qualification gaps.

5. **Phase 10D — Technical Demo Release Gate — IN PROGRESS / 10D1 + 10D2 PASSED**

   Analyze the current Old Pine slice's installable Technical Demo boundary: real hardware,
   production renderer, critical-journey durability, packaging and release-process gates.
   Assess identity/signing owner decisions and the iOS runtime gap without presuming permanent
   store configuration is required. No implementation or publication is authorized by this
   planning step. Emulator proof is not hardware or store certification.
   The [analysis](../migration/PHASE_10D_TECHNICAL_DEMO_RELEASE_GATE_ANALYSIS.md) is complete.
   The owner-revised [10D1 physical qualification](../migration/PHASE_10D1_PHYSICAL_DEVICE_QUALIFICATION.md)
   has **PASSED** its bounded private/internal Technical Demo gate: the frozen ARM64 APK ran
   the production Mobile/Vulkan path on Xiaomi 13 Pro and primary OnePlus 8T hardware, with
   OnePlus real touch/multitouch, both supported landscapes/SafeArea, Android Back and basic
   lifecycle evidence. The Xiaomi-only W/SW observation did not reproduce with the same APK
   on OnePlus and is not a generalized production defect. This is not broad Android/tablet,
   store or long-duration certification.

   [Phase 10D2 packaging](../migration/PHASE_10D2_TECHNICAL_DEMO_PACKAGING.md) has also
   **PASSED**. Clean-source sanitized Windows x86_64 and Android ARM64 artifacts now have
   external candidate evidence binding source/toolchain/digest, artifact SHA-256 values,
   Android technical identity and ephemeral certificate, plus accompanying notice/provenance
   files. No build-tool, package-ID, version, permanent-signing or store decision changed.

   **PHASE 10D3 — READY TO BEGIN.** Full normal-player critical journey,
   Save/unsaved-process-death/Continue, a representative Save blocker, Windows pristine-ZIP
   acceptance and final candidate runtime/log acceptance belong to 10D3. Long soak and
   detailed performance, memory and thermal profiling are risk-triggered unless normal use
   exposes degradation. No public distribution or permanent signing is authorized.

After Phase 10D, perform a new planning review before resuming large-scale authored content. This
roadmap intentionally avoids speculative phase expansion.
