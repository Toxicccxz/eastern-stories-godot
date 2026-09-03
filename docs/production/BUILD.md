# Build and CI

## Supported toolchain

- Python 3.12 (standard library only; local validation used 3.12.13).
- Godot **4.7.2** exactly, with matching `4.7.2.stable` standard export templates.
- Windows target: Windows x86_64, unsigned Release ZIP.
- Android target: Temurin JDK 17.0.18+8; Android SDK Platform-Tools 35.0.0 or newer,
  Build-Tools 35.0.1, Platform 35, Command-line Tools 20.0, CMake 3.10.2.4988404, and NDK r28b
  (28.1.13356709). These are the Godot 4.7 requirements pinned by Phase 10A.
- iOS target: macOS with Xcode. CI uses `macos-15` and explicitly selects Xcode 26.3
  (iOS 26.2 SDK). The recorded remote proof is listed under GitHub Actions below.

The project renderer, feature version, Jolt configuration, scenes, and gameplay settings do not
diverge per platform. Phase 10A enabled the shared ETC2/ASTC texture import required by the Android
exporter.

## Official Godot bootstrap

CI and clean environments can download the pinned official editor/templates with:

```text
python tools/ci/bootstrap_godot.py --platform windows --output build/toolchain
python tools/ci/bootstrap_godot.py --platform linux --output build/toolchain
python tools/ci/bootstrap_godot.py --platform macos --output build/toolchain
```

The script downloads from the official `godotengine/godot-builds` 4.7.2-stable release, verifies each
archive against its entry in the release's official `SHA512-SUMS.txt`, and prints the resolved
`godot` and `templates` paths. This detects corruption or a mismatch within that release boundary;
because the archive and checksum are obtained from the same unsigned publication boundary, it is not
an independent proof of publisher authenticity. The script does not commit downloaded files.

## Verify the repository

```text
python tools/ci/verify.py --godot <path-to-godot-4.7.2>
```

The stable order is:

1. Python tooling unit tests;
2. repository/static checks;
3. development-project headless editor validation;
4. canonical `game/tests/run_tests.gd` gameplay suite;
5. real sanitizer plus sanitized-project headless validation.

Platform exports are intentionally separate from routine verification.

## One sanitized production project

All targets use the same flow:

```text
development game/
    -> tools/build/prepare_release_project.py
    -> build/release-project/
    -> Windows / Android / iOS export
```

The staging directory is deleted and recreated. The sanitizer removes the Godot AI addon, helper
autoload, editor plugin activation, early `mcp_test.tscn` smoke scene, remote-debug/6107 argument,
`.godot` cache, `game/tests/`, and QA bridge/startup configuration. Test fixtures and fake capabilities
must not be production dependencies. It retains the canonical
`res://scenes/application/application_shell.tscn`, production Shell/settings/capability code, persistent
Runtime Host, and native Save/Continue/recovery runtime. It also retains responsive presentation,
SafeArea, touch capture/adapter, Android Back/exit, typed lifecycle/activity and explicit Resume-gate
logic, mobile logical-size overrides and sensor-landscape configuration. All mobile test fakes and
lifecycle observers remain excluded. It verifies required production paths, scans
for forbidden references and local absolute paths in shipped source, and checks that the source tree
digest is unchanged. No repository-level
`reference/es2`, migration docs, CI scripts, or build tools are copied.

To inspect the sanitizer alone:

```text
python tools/build/prepare_release_project.py --source game --output build/release-project
python tools/build/prepare_release_project.py --output build/release-project --validate-only
```

Never run a production export directly from the development `game/` checkout. The build entrypoint
injects absolute custom-template paths only into the temporary staging preset.

## Runtime save storage

The production Runtime Host uses one fixed release slot at
`user://save-data/release/default-v1.json`. Development and isolated test profiles use separate child
directories. A Save verifies a temporary file before replacement and retains the prior canonical file as
`.bak`; Load reports a valid recovery candidate but does not automatically select it. The canonical
ApplicationShell starts at Main Menu with no Session. Continue re-reads the canonical slot; Save is
an explicit Pause-menu action. Recovery requires the player to select BACKUP or TEMP and does not
promote files. See the [native Save/Load contract](contracts/NATIVE_SAVE_LOAD_CONTRACT.md) and
[Application Shell contract](contracts/APPLICATION_SHELL_CONTRACT.md).

Mobile background/focus loss causes **zero new Save requests**. An already-requested manual Save
may finish through the normal transaction; lifecycle does not cancel, duplicate or retry it. Same-
process return preserves memory; cold Continue restores the last completed manual Save. There is no
lifecycle/termination autosave or promised background-time reservation. See the
[Mobile Application contract](contracts/MOBILE_APPLICATION_CONTRACT.md).

## Application settings storage

Typed application settings use `user://settings/application-v1.cfg`, independently of gameplay saves,
profiles, schema, and recovery. Settings load before Menu and are available from Menu and Pause.
Windowed/Fullscreen is editable only through the native desktop capability; embedded, headless, and
platform-managed windows show no editable mode control. Unusable settings do not block Continue;
failed preference persistence is reported separately from gameplay Save. Mobile adds no new
preference or autosave setting; its lifecycle policy is defined by the separate mobile contract.

## Unified builds

Windows:

```text
python tools/build/build.py --target windows --godot <path-to-godot-4.7.2> --templates <path-to-4.7.2.stable-templates>
```

Output:

```text
dist/windows/Eastern-Stories-Godot.exe
dist/windows/Eastern-Stories-Godot.pck (when emitted separately)
dist/windows/build-manifest.json
dist/Eastern-Stories-Godot-windows-x86_64.zip
```

Android:

```text
python tools/build/build.py --target android --godot <path-to-godot-4.7.2> --templates <path-to-4.7.2.stable-templates> --android-sdk <android-sdk> --java-sdk <temurin-jdk-17.0.18+8>
```

The build writes Android SDK/JDK paths to an isolated generated EditorSettings tree instead of
reading a developer's normal Godot settings. It generates a random ephemeral QA keystore, supplies it
through Godot's documented export environment variables, validates the APK/package ID with `aapt2`
when available, and deletes both the QA key and the isolated generated EditorSettings/keystore tree
in a `finally` boundary.

Output:

```text
dist/android/Eastern-Stories-Godot-android-arm64.apk
dist/android/build-manifest.json
```

This is a **TECHNICAL / QA BUILD**, not a Play Store release. A later build signed with another
ephemeral key may require uninstall/reinstall. No permanent Play signing credential exists here.
Preserve existing app data and obtain approval before uninstalling a test package to resolve a
signature mismatch.

For an x86_64 Android emulator, explicitly append `--android-technical-abi x86_64` to the Android
command above. The option is Android-only and changes only the disposable staging preset. Output is
`dist/android-technical-x86_64/Eastern-Stories-Godot-android-technical-x86_64.apk` with a manifest
marking the technical ABI. Without that option, normal Android remains ARM64; CI uses the normal
command. The ABI option does not change renderer, signing policy or package identity.

A separately disclosed emulator renderer override such as `gl_compatibility`, isolated package ID
or test observer belongs only to disposable technical staging, never the shared production project
or normal CI. Validate a pristine sanitized stage before such instrumentation and do not describe
the instrumented artifact as a pristine release or ARM64/Vulkan hardware qualification.

iOS (macOS only):

```text
python tools/build/build.py --target ios --godot <path-to-godot-4.7.2> --templates <path-to-4.7.2.stable-templates>
```

The command fails clearly on non-macOS hosts. On macOS it exports the generated Xcode project,
discovers the actual project/workspace and scheme through `xcodebuild -list -json`, then compiles the
Release target for generic iOS with signing disabled. It packages the Xcode project, manifest, and
compile log. GitHub Actions workflow run `33350605585` proved the exact generated project and
command on commit `557a678c991d1509ed2d10b1c6053493ae5b74a4`.

Godot 4.7.2's official iOS template was built against the Xcode 26 SDK surface and does not link
against Xcode 16.4/iOS 18.5 (`CADynamicRange*` and `MTLTensorDomain` remain unresolved). The same
template also references `SDL_IsIPad` and `SDL_IsAppleTV` without defining them, matching upstream
[Godot issue #122549](https://github.com/godotengine/godot/issues/122549). Phase 10A therefore pins
Xcode 26.3 and compiles the narrow `tools/build/ios_sdl_compat_shim.m` object into the unsigned
validation build. Remove this compatibility shim when a pinned Godot release provides the symbols.

No certificate, Provisioning Profile, Apple secret, IPA, App Store, or TestFlight claim is involved.

## Identity and technical versions

No pre-existing Android package or iOS bundle ID was found. Phase 10A therefore uses:

```text
com.example.easternstoriesgodot
```

Status: **PROVISIONAL_NON_STORE_ID**. It is not a domain/publisher claim and must be replaced before
permanent signing or store submission. Mobile version name `0.0.0-dev` and numeric build/code `1` are
technical exporter inputs, not a product version policy.

The iOS exporter requires a syntactically non-empty ten-character Team ID; the preset uses the
obvious placeholder `XXXXXXXXXX` only to generate an unsigned Xcode project. It is not a Team ID or
signing identity.

## Build manifests and clean output

Each target manifest records target, full Godot version string, Git commit, dirty status, Release
type, UTC timestamp, package ID where relevant, signing mode, and toolchain evidence. It contains no
secret or private local path. Local dirty builds are allowed; `--require-clean` is available and is
used in CI.

Each target rebuild removes only its controlled staging/output directory. The tooling never runs
`git clean` and never mutates `game/`. Generated output lives under ignored `build/` and `dist/`.

## Private Technical Demo candidate evidence

For a private/internal Technical Demo handoff, keep each target's existing
`build-manifest.json` and create one external candidate evidence record after export. The record
binds the clean source commit and Godot version to the sanitized-project digest, target/release
identity, final artifact filename/size/SHA-256 and target-specific identity. For Android it also
records package/version/ABI, ephemeral signing mode, public certificate SHA-256 and certificate
validity. Keeping this record outside the artifact avoids a circular artifact self-hash.

Phase 10D2's concrete record is `build/phase10d2/candidate/technical-demo-candidate.json`;
generated `build/` output remains ignored and is not a new repository service or automatic
`build.py` output. Its [phase record](../migration/PHASE_10D2_TECHNICAL_DEMO_PACKAGING.md) retains
the exact values. Candidate artifacts are traceable to documented source/toolchain/build inputs and
individually identified by SHA-256; byte-for-byte reproducibility is not claimed because timestamps
and ephemeral Android certificates may change repeated-build bytes.

Private handoff must accompany the selected artifact and evidence record with the repository's
`THIRD_PARTY_NOTICES.md` and `docs/production/LICENSE_PROVENANCE.md`. This represents the shipped
Godot notice, confirms Godot AI is excluded from sanitized runtime output and preserves the
unresolved ES2/native-project public-release boundary. It does not create a project license.

The current signing levels are deliberately separate:

1. private Technical Demo: unsigned Windows, ephemeral-QA Android, unsigned iOS validation;
2. retained internal upgrades: future reusable technical-signing decision;
3. public/store distribution: future permanent platform/store signing.

Only level 1 exists. Do not infer an upgrade promise, final package/publisher identity or store
readiness from a successful technical build.

## GitHub Actions

`.github/workflows/ci.yml` implements two integration gates. A ready pull request targeting `main`
runs on open, reopen, synchronization, and transition from draft to ready; merging then runs the
same workflow again through `push: main`. Ordinary pushes to a phase branch before a PR exists do
not trigger it. Draft pull requests may exist for explicitly requested collaboration, but the
expensive jobs are skipped while the PR remains draft. Manual dispatch remains available for an
intentional diagnostic run.

The repository's recommended remote ruleset requires PR-only integration into `main` and all four
stable PR checks. The workflow does not infer merges from commit messages. See
`docs/production/REPOSITORY_POLICY.md` for the complete branch lifecycle, CI event matrix, failure
handling, and the distinction between implementation completion and full integration closure.

The workflow contains:

- `Godot Verify` on `ubuntu-24.04`;
- `Windows Release Build` on `windows-2025`;
- `Android Release Build` on `ubuntu-24.04` with Temurin JDK 17.0.18+8 and pinned SDK packages;
- `iOS Build Validation` on `macos-15`; the job enumerates installed Xcode applications, requires
  `/Applications/Xcode_26.3.app`, selects it explicitly, and prints the Xcode/iPhoneOS SDK versions.

Build jobs depend on `Godot Verify`; the complete gameplay suite runs only in that job. All jobs use
Godot 4.7.2 and repository scripts. No project secret is required.

Artifact names:

- `eastern-stories-godot-windows-x86_64`;
- `eastern-stories-godot-android-arm64`;
- `eastern-stories-godot-ios-build-validation`.

Workflow presence alone is not evidence that GitHub Actions passed. Workflow run `33350605585` on
commit `557a678c991d1509ed2d10b1c6053493ae5b74a4` completed successfully with all four required jobs
green: `Godot Verify`, `Windows Release Build`, `Android Release Build`, and
`iOS Build Validation`. All three platform artifact uploads also succeeded.

## Local proof recorded for Phase 10A

On the implementation workstation, the official checksum-verified Godot
`4.7.2.stable.official.ed1daf0bf` editor and matching templates produced:

- an unsigned Windows x86_64 Release ZIP;
- an Android ARM64 technical Release APK (27,490,697 bytes), signed with the per-build ephemeral QA
  key and independently confirmed as `com.example.easternstoriesgodot` by Build-Tools 35.0.1
  `aapt2`;
- a clean-checkout simulation containing repository verification, all 8,719 gameplay assertions,
  the real sanitizer, sanitized-project validation, and a Windows Release export.

The successful local Android SDK had Platform-Tools 37.0.1. Build-Tools 35.0.1, Platform 35,
Command-line Tools 20.0, CMake 3.10.2.4988404, and NDK 28.1.13356709 were all explicitly validated.
The workstation also contained newer SDK packages, so the Godot exporter selected its compatible
36.0.0 signer internally; Phase 10A requires the documented Godot 4.7 baseline packages and records
tool availability rather than claiming that every extra package on a developer machine is absent.

iOS cannot be compiled on this Windows host. Its Godot export plus unsigned Xcode Release compile
was proven remotely on `macos-15`/Xcode 26.3 in workflow run `33350605585`; it is not claimed as a
local PASS.

## Clean rebuild and diagnostics

If Godot is missing, resolution priority is `--godot`, `GODOT_BIN`, then `godot`/`godot4` on PATH.
The build rejects any version other than 4.7.2 and reports the exact missing target template. Android
also reports each missing pinned SDK/JDK dependency. iOS reports the macOS/Xcode requirement.

The committed-HEAD clean-checkout simulation is:

```text
python tools/ci/clean_checkout_smoke.py --godot <path-to-godot-4.7.2> --templates <path-to-4.7.2.stable-templates>
```

It creates only `build/clean-checkout/` from `git archive HEAD`, so untracked files, dirty working-tree
edits, local `.godot` imports, and existing generated state are excluded. It refuses output outside a
child of the repository's controlled `build/` directory and does not touch or clean the primary
workspace.

## Mobile product boundary

The shared mobile layer now provides responsive Shell/HUD/item panels, SafeArea, a fixed digital
pad, Android Back and lifecycle freeze/explicit Resume, with manual saves only. It keeps desktop
1152x648, mobile logical 960x540, canvas_items/expand and both sensor-landscape directions. See the
[Mobile Application contract](contracts/MOBILE_APPLICATION_CONTRACT.md) for supported boundaries.

Installed x86_64 Android emulator evidence does not qualify physical Android multitouch, ARM64,
production Vulkan or general device compatibility. The shared iOS source/export path does not
qualify iPhone/iPad simulator/device runtime; unsigned iOS Xcode compilation remains required in
integration CI. Permanent identity/signing, hardware qualification and store-oriented release gates
belong to Phase 10D or an explicitly planned later release phase, not a successful build alone.
