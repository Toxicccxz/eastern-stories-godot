# Phase 10D — Technical Demo Release Gate Final Audit

Date: 2026-09-08. **FINAL_LOCAL_AUDIT = PASS.**
Private/internal engineering gate only. Remote PR/CI results are pending at this document's
commit time and will be recorded in the owner report; this is not merge authorization.

## 1. Audit scope and authorities

Final evidence, source/history, candidate identity, documentation and integration audit;
not gameplay implementation, a new packaging phase, another acceptance playthrough or public release.
Read root/docs AGENTS, repository policy, BUILD, STATUS, ROADMAP, Godot AI development/provenance,
LICENSE_PROVENANCE, THIRD_PARTY_NOTICES and the Shell/Mobile/Native Save contracts.
Read the four historical Phase10D records on the frozen branch, current
[10D3 acceptance](PHASE_10D3_POST_REDESIGN_TECHNICAL_DEMO_ACCEPTANCE.md), and
[CXR10 final boundary](PHASE_COMBAT_CXR10_FINAL_AUDIT.md), including its post-PR correction.
No LPC reread or third full CXR architecture audit was necessary: committed production delta is zero.

## 2. Starting main, branch and HEAD

- Main and merge-base: `0a5f0b49b6797c2a1280ef4198c2060b3cc61e34`.
- Branch: `phase/10d-post-redesign-release-validation`.
- Starting HEAD/upstream: `aab8386184309f2b7c9f460892ade4b3929a2ea8`.
- After fetch/prune: HEAD/upstream 0/0; main/HEAD 0/6. Main has not advanced; no synchronization.
- No existing PR from this head was found. Final commit SHA belongs in the external report,
  avoiding a self-referential hash. This audit stays on the same phase branch.

The owner worktree is intentionally not clean. Exactly three pre-existing modified files were
enumerated, index empty; no untracked source file. SHA-256 baseline:

| Owner-local file | SHA-256 |
| --- | --- |
| `game/project.godot` | `EFAEA1FA56EC0F6A7B391856C9EA7D5DBAA3CBA72348D7C53D5A3C55291CA16C` |
| `game/addons/godot_ai/plugin.cfg` | `BA8C0C6B4235598840B6CE7381030C3C653F025E08F649F9CE13D5137CCD2713` |
| `game/addons/godot_ai/utils/update_manager.gd` | `980337C9302CEB0485DC69F8C453CC64BC4480929F6659440ABFB239B554407D` |

All remain separate from audited tracked source and final staging. No reset, clean, stash,
overwrite or owner-file commit. Local addon 4.0.2 is not qualified or included by this audit.

## 3. Historical Phase10D evidence boundary

Frozen `phase/10d-technical-demo-release-gate` remains at
`26fef9512355eaa851b268d2b2ae7fc955915aa4`; no history rewriting or branch deletion.
Its `PHASE_10D_TECHNICAL_DEMO_RELEASE_GATE_ANALYSIS.md` is a historical proposal, not a newly
imposed repetition budget. Subsequent owner-approved 10D1 and 10D3 scope revisions govern this gate.
The historical qualification, packaging and stabilization documents were read via `git show`;
they are not copied into this branch or relabelled as current candidate evidence.

## 4. Combat redesign integration baseline

CXR PR #8 merged at `7372d9d2ca3d796236ad64c2c6ad817a2508cb91`, main workflow
[34186684857](https://github.com/Toxicccxz/eastern-stories-godot/actions/runs/34186684857).
Independent Godot AI 4.0.1 PR #9 merged at starting main, workflow
[34187852614](https://github.com/Toxicccxz/eastern-stories-godot/actions/runs/34187852614).
All four jobs in each historical run were re-read as completed/success. Git ancestry includes
both merges and CXR's topology/final-hit corrections. Neither old run substitutes for this PR's CI.

## 5. Post-redesign candidate identity

Immutable source: **`000d7b383f1d508aab56e9dcd90273d4a9dd5b85`**.
Clean candidate clone `build/phase10d3-post/source` remains clean at this SHA.
Both manifests identify that source, dirty=false, Godot `4.7.2.stable.official.ed1daf0bf`.
Read-only SHA-256 checks matched all four existing artifacts:

| Artifact | SHA-256 |
| --- | --- |
| Windows ZIP | `40006E9FE96D847EFE6FE204945793EB8E09E7250B4BE95307921228444120A1` |
| Windows EXE | `3D19EE4A764E8BB153BFA7F811F98E0DFB0139C9E0C8BC6B76B93D3ED09185BF` |
| Windows PCK | `25384785653FDAA0B5791B113D24868E691313AC25F281091D11AACB7F1D8D08` |
| Android APK | `DDCE2E2229C9B08786F33826CF8CCDA03917EFC1A47913AC7ABAFEAF46FC9BD2` |

Manifest hashes and companion hashes also match the external candidate record. Extracted Windows
EXE/PCK/manifest bytes match their ZIP members. No rebuilt or newly qualified candidate was created.

## 6. Candidate-source drift audit

**CANDIDATE_DRIFT = NO.** Candidate..HEAD changes only acceptance docs, STATUS, ROADMAP and
the Godot AI notice heading. Final audit adds this document and current-status wording only.
Starting main, candidate and tested audit HEAD have identical Git objects:

| Source boundary | Git tree/blob |
| --- | --- |
| `game/` (including tests/config/data) | `e94e18e1bada1ba2ff4bd34efa05c94555d7632c` |
| `tools/` | `a2d00032e0d272e2f1dbfd65d76e5bb4d6bb7c8e` |
| `.github/` | `91ad324e4701c779e3a9548fbac2f970314df6d3` |
| `reference/es2/` | `4106480ab28cce8cd7b55704f8ae9ae062d42d03` |
| `docs/migration/DECISIONS.md` | `75336e076019395992e221a4e09a0f73e8430db2` |

Thus Session ownership, Save/schema, combat/Flee/SPAR, input/lifecycle, renderer, corpse/loot,
world/content and build/sanitizer/export behavior are unchanged. Owner dirty files are not inputs.

## 7. Full Phase10D branch diff inventory

| Final branch path versus main | Purpose |
| --- | --- |
| `THIRD_PARTY_NOTICES.md` | Stale Godot AI heading 3.2.4 -> integrated 4.0.1; no binary change |
| `docs/migration/PHASE_10D3_POST_REDESIGN_TECHNICAL_DEMO_ACCEPTANCE.md` | Exact candidate and accepted bounded journeys |
| `docs/migration/PHASE_10D_FINAL_AUDIT.md` | This final local evidence/integration gate |
| `docs/production/STATUS.md` | Correct CXR integration history and current pre-merge Phase10D status |
| `docs/production/ROADMAP.md` | Same milestone boundary and current readiness |

All branch files reviewed. Production, tests, build source, CI source, reference/es2 and
DECISIONS deltas: **0 each**. No artifact, profile, screenshot, log, key or owner upgrade is staged.

## 8. Phase10D1 disposition

Historical bounded physical Android qualification remains **PASS in its original scope**:
named OnePlus 8T, real finger directions/multitouch (21 starts/21 releases, maximum 3),
both landscapes, usable controls, Android Back and basic lifecycle. It is not post-redesign
whole-game or broad-device certification. The Xiaomi W/SW report remains a bounded observation,
not a generalized production defect or a proven repair. No further owner gesture test is required.

## 9. Phase10D2 disposition

Historical packaging remains **PASS for source `995736bf37d2917e8c6f9e53a86ab83ecff3b734` only**.
**POST_REDESIGN_CANDIDATE_REFRESH = SATISFIED** by the new clean source, ZIP/EXE/PCK/APK,
manifests, digests, sanitizer/exclusion inventory, signing facts and provenance companions in 10D3.
No new 10D2 slice, rebuild or cross-build upgrade claim is needed.

## 10. Phase10D3 disposition

Old pre-redesign 10D3: **BLOCKED / NEVER PASSED**, unchanged historical record.
Current post-redesign 10D3: **PASS — TECHNICAL DEMO CRITICAL JOURNEY ACCEPTED**.
The evidence distinguishes observations, human-assisted Windows walking, phone OS input,
automated invariants and unavailable internals. No contradictory candidate/result was found.
Final Audit reviews the accepted evidence; it does not repeat or inflate it.

## 11. Windows acceptance evidence audit

10D3 sections 6, 8–14 and its Windows matrix support pristine ZIP cold startup/Menu/New Game,
physical movement, natural Battle, unsafe Save rejection, real queued Flee, physical leave/re-entry,
natural Victory at 127/127/220, corpse range enforcement, short-sword/silver x3 Take,
Inventory, Save/Menu and fresh-process Continue. Settings fullscreen persists across processes.
Concurrent-input attribution on the first New Game click is explicitly limited, not concealed.
Packaged D3D12 / Forward Mobile / RTX 4070 SUPER proof is separate from editor-helper evidence.

## 12. Android physical evidence audit

10D3 sections 7–14 and Android matrix support OnePlus 8T / Android 14 / native Vulkan 1.1.128 /
Forward Mobile / Adreno 650: installed candidate, touch movement, natural aggression, Flee,
Back/Pause, unsafe Save rejection, Home/explicit Resume, natural Victory, loot and Save/Continue.
Representative physical route: Vine -> Waterfall -> river east bank -> Cliff1 -> Cliffside ->
Pine -> stronger natural Victory at 89/89/220. OS-injected touch is real physical-device runtime
input, not new human multitouch/comfort proof. Historical 10D1 supplies the separately bounded
human interaction evidence. No iOS, tablet or general Android claim.

## 13. Save, restart, lifecycle and error evidence

Windows PID56620 Save A -> normal exit -> cold PID21700 Continue A -> unsaved movement B ->
exact process kill/absence -> cold PID49204 Continue A. Save hash unchanged. Android PID8154 ->
cold PID13744 -> unsaved B -> cold PID16777 restores A without uninstall/data clearing.
Same-process Home/Resume keeps observed paused values; cold Continue uses manual Save, not autosave.
Screenshots do not prove exact semantic IDs/RNG; existing canonical tests cover those invariants.

All **57** referenced screenshots remain present. Existing Windows flushed startup log and
committed Android process-filtered observation support no observed release-blocking crash/softlock.
The standalone `android-process3-runtime.log` is absent locally; an empty later log ring is not
exhaustive zero-error proof. Neither absence is newly described as an inspected PASS log.
Historical Adreno Surface teardown warning and inventory scrolling ergonomics remain bounded,
documented observations, not silently fixed or generalized blockers. No live game was launched
for this audit; sanitized artifacts have no Godot AI helper, so helper fields are inapplicable.

## 14. Cave / SouthExit scope

**CONDITIONAL CAPABILITY — NOT PART OF CURRENT FRESH NEW GAME TECHNICAL DEMO CRITICAL JOURNEY.**
Not advertised, not a blocker, not claimed as fresh-player packaged PASS. The established
raw dodge 10 -> effective 5 -> draws 0..4 boundary selects Waterfall; no short reliable natural
prerequisite route is established. Existing conditional tests retain their setup limits.
No new stats, cheated save, guaranteed RNG or reroll-until-Cave was introduced.

## 15. Sanitizer, package and provenance

Read-only Windows inventory is exactly EXE/PCK/manifest. Android inventory has 925 entries,
sole arm64-v8a native ABI and no QA/tests/addon/raw reference/export preset/save/settings file/key.
Production `application/settings` scripts are intentionally retained; they are not user settings.
The disposable audit scanner initially confused these two and was corrected; production was not.
10D3 independently verified v2/v3 RSA-2048 ephemeral QA signing and package
`com.example.easternstoriesgodot`, version `0.0.0-dev`/code 1, APK min/target SDK 24/36.
No permanent signer, reusable update promise or byte-identical rebuild claim.

The new canonical run also validates a fresh sanitized project, excluding QA/addon/debug while
retaining Shell/settings/Battle/save/mobile runtime. Post-export absolute custom-template paths
are builder staging details, not inputs to the pre-export sanitizer invariant or shipped paths.
Existing candidate sanitizer digest is
`78f1365b409f2dca7c0f129bdd808a31e11a3dd80f199c6a7879568ac939e342`.
Notices/provenance remain external companions required for private handoff, not embedded legal UI.
The candidate JSON's old in-progress scope text is its creation checkpoint; the committed 10D3
closeout is acceptance-status authority. No artifact fact is relabelled.

## 16. Release / legal boundary

**Private/internal Technical Demo engineering gate only.** Root native license is absent and ES2
README/license-holder attribution remains unresolved. Excluding raw LPC does not resolve rights
to migrated material. No legal clearance, public download, GitHub release, store/TestFlight upload,
production signing, permanent identity or distribution permission follows from PASS.
The Mobile contract's Phase10C2 unqualified-device paragraph is its original qualification
checkpoint; later bounded 10D1/CXR10/10D3 evidence does not change its behavioral contract.

## 17. Canonical final verification

Executed **once**, without skips, on an independent clean clone of tracked starting audit HEAD:

```text
python tools/ci/verify.py --godot <official Godot 4.7.2 console binary>
```

Clone: `build/phase10d-final-audit-source`; log: `build/phase10d-final-verify.log`.
Owner configuration/addon edits are absent. Result **exit 0**:

- Python tooling: **46 tests PASS**.
- Repository/static: **PASS**.
- Development Godot headless editor: **PASS**, official 4.7.2.
- Complete canonical gameplay: **16,152 assertions PASS, 0 failures**.
- Actual sanitizer and sanitized headless editor: **PASS**.
- No ERROR, SCRIPT ERROR or WARNING lines found in that final verification log.

Final changes are docs only; no second full run is needed for status wording. No local platform
re-export: existing artifacts prove acceptance, while final PR Windows/Android/iOS jobs supply
integration-build confidence. Their outputs are not the immutable 10D3 acceptance artifacts.

## 18. Static / repository validation

Working and main...HEAD `git diff --check` PASS; changed-document trailing whitespace zero;
local Markdown link targets resolve. All 686 tracked UID sidecars have source partners, valid
syntax and unique IDs; resource parsing also passes headless validation. No tracked generated
archive/binary/log/profile/candidate additions. Reference/es2 and DECISIONS local/committed deltas
remain zero. Clean validation and candidate clones remain clean. Owner hashes are preserved.

## 19. Deferred scope

Broad device/tablet/iOS runtime qualification, physical controller, portrait/multiwindow,
long-duration/performance certification, public licensing/signing/distribution, installers,
final art/audio/accessibility/localization, broad balance/combat parity, additional ES2 content
and naturally accessible Cave progression remain separate work. No new content phase begins.
Historical stress proposals are not reported as executed; current owner-approved bounded
acceptance replaces mandatory repetition, with real regressions still blocking acceptance.

## 20. Final local audit result

**PHASE10D_FINAL_LOCAL_AUDIT = PASS.** Candidate source and evidence consistent; no production
drift; all canonical/static/sanitizer gates pass; current 10D3 accepted; owner work preserved.
No product fix or candidate requalification required. Only this audit and STATUS/ROADMAP are
changed by Final Audit. Historical records and artifact bytes remain untouched.

## 21. Integration readiness at commit time

- **FINAL LOCAL AUDIT PASS — FINAL INTEGRATION PR READY**.
- FINAL_PR: **NOT YET CREATED** at this commit.
- PR_CI: **NOT YET RUN** at this commit; externally recorded after PR.
- MERGE: **NOT AUTHORIZED / NOT DONE**.
- POST_MAIN_CI: **NOT RUN** for Phase10D integration.
- Phase10D: **NOT YET FULLY INTEGRATED**.

Create exactly one ready PR from this branch to main, review its complete diff, then require
Godot Verify, Windows Release Build, Android Release Build and iOS Build Validation to succeed
on the same final PR HEAD. No post-green documentation commit merely to add run IDs. Report
PR/head/run/job evidence externally and stop for separate owner merge authorization.
