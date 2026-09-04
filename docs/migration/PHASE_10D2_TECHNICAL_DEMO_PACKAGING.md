# Phase 10D2 — Technical Demo Packaging / Identity Boundary

Status: **TECHNICAL DEMO PACKAGING PASSED** for the exact source commit and artifacts recorded
below. Phase 10D3 is now **BLOCKED / SUSPENDED** pending Combat Experience Redesign and never
passed.

Parking note: the existing artifacts and hashes remain valid historical evidence for their exact
source commit. Once production combat code changes, they are no longer current release candidates
and must not be reused for the redesigned game. A future acceptance cycle requires a newly built
candidate and refreshed packaging evidence.

## Scope

Phase 10D2 proves that the existing sanitized build path can produce individually
identifiable private/internal Technical Demo candidates for Windows and Android. It
does not establish store identity, permanent signing, an installer/updater, public
distribution, gameplay acceptance or general device support.

Production gameplay/runtime, renderer, Session, Save/Load, mobile input/lifecycle,
package ID and technical version inputs are unchanged. The artifacts were built from
clean source commit `995736bf37d2917e8c6f9e53a86ab83ecff3b734` with Godot
`4.7.2.stable.official.ed1daf0bf` and matching standard templates.

## Candidate identity model

Existing per-target `build-manifest.json` files remain authoritative for target,
source commit, dirty state, Godot version, Release type, package ID, signing mode,
timestamp and toolchain facts. They do not contain their enclosing artifact's hash.

Phase 10D2 adds no release database or build service. A generated external record,
`build/phase10d2/candidate/technical-demo-candidate.json`, binds both target manifests
to:

- source commit and clean state;
- exact Godot version;
- sanitized project digest;
- target/release/architecture identity;
- artifact filename, size and SHA-256;
- Android package/version/signing certificate facts;
- accompanying notices and their SHA-256 values.

The external record is intentionally outside both artifacts, avoiding a circular
self-hash. The sanitized evidence copy passed `prepare_release_project.py
--validate-only`; its `source_tree_digest` SHA-256 is
`88b89d323b38e5c3ab636c5d120b5a941dca3baa0478b07d11efe8477fbe4903`.
The digest excludes only generated `.godot` cache content.

This is traceability, not a byte-for-byte reproducibility claim. Build timestamps and
ephemeral Android certificates may produce different bytes on a repeat build.

## Windows candidate

- File: `Eastern-Stories-Godot-windows-x86_64.zip`
- Size: 38,976,754 bytes
- SHA-256: `227f51c8584573823d695544639ea0d5e4dbc76f5d9d4a45ad68bb6d29cebef3`
- Target/type: Windows x86_64, Release
- Signing: none; private/internal unsigned portable ZIP
- Manifest SHA-256:
  `26bfacfc1b31fe5c80548911f6e67933f45811d95ef827f0f25dda4cddb604e7`

The ZIP contains the expected executable, PCK and build manifest. The sanitizer excludes
tests, Godot AI, QA/startup fixtures, remote-debug arguments and developer absolute paths.
No installer, updater or Windows code-signing claim is introduced.

## Android candidate

- File: `android/Eastern-Stories-Godot-android-arm64.apk`
- Size: 27,762,842 bytes
- SHA-256: `9f526aa8e37c6d8e07abb3d1fb72511ae5546f9e1ad1e878d500acd4c0dddf96`
- Target/type: Android ARM64 Technical Release
- ABI: only `arm64-v8a`
- Package: `com.example.easternstoriesgodot`
- Version: `0.0.0-dev`, code `1`
- Minimum/target SDK declared by APK: 24/36
- Signing: one ephemeral QA RSA-2048 signer; APK Signature Scheme v2/v3
- Certificate SHA-256:
  `7b0221973b83b3364d2710bf69854597b34fa9e30477352bf0be6208ad9afc76`
- Certificate validity: `2026-09-03T19:24:43Z` through
  `2026-09-05T19:24:43Z`
- Manifest SHA-256:
  `7729d7d3eccdc05aa8b3a0e41a17a70a9d7179645ebc646766d8faf172402239`

Independent `aapt2` inspection confirms the package, technical version, Vulkan feature
declarations and sole ARM64 ABI. `apksigner` verifies one signer under v2/v3 and supplies
the public certificate fingerprint above. The temporary keystore and isolated editor
settings were deleted by the existing build's `finally` boundary. There is no permanent
key or cross-build upgrade guarantee.

This APK is not the Phase 10D1 physical-device binary. Phase 10D1 used source
`d08ce8fa1fae354b96760fd75707a63063ee1530` and SHA-256
`81ae081fd0c47e674b88148ecbf0045f2b01bc00bd23fecfa3fabfe98eff4393`.
The new hash is expected because the source commit, timestamp and ephemeral signer differ.
Phase 10D2 changes no runtime, renderer, ABI policy, input/lifecycle or export runtime
configuration, so the bounded 10D1 interaction evidence remains applicable to the
unchanged production path; it is not relabeled as proof of the new bytes.

## Signing boundary

Three levels remain distinct:

1. Current private Technical Demo: unsigned Windows, ephemeral-QA Android and unsigned
   iOS build validation. Only this level is in scope.
2. Retained internal distribution with upgrades: a future reusable technical-signing
   decision; not implemented.
3. Store/public distribution: future permanent platform/store signing; not implemented.

No credential for levels 2 or 3 was created.

## Package identity boundary

`com.example.easternstoriesgodot`, `0.0.0-dev` and code `1` remain explicitly
**PROVISIONAL / TECHNICAL**. They are not a final publisher, owned-domain, store or
product-version identity. Replacement requires later owner decisions about the final
name, publisher/developer identity, domain and store strategy. Phase 10D2 deliberately
does not change them.

## Notices / provenance

The candidate directory accompanies both artifacts with `THIRD_PARTY_NOTICES.md` and
`LICENSE_PROVENANCE.md`, and the external evidence record binds their hashes. The notice
covers the shipped Godot Engine runtime and states that Godot AI is development-only and
excluded from sanitized artifacts. ES2 attribution and the absent native-project root
license remain unresolved public-release gates; no root license or clearance claim is
created.

For any private handoff, distribute the selected artifact together with both notice files
and `technical-demo-candidate.json`. The notice files are external companions, not an
in-game legal screen or content embedded into the APK.

## What remains deferred

- permanent package/bundle identity and product version policy;
- reusable Android signing, Windows signing, Apple signing and store credentials;
- installer, updater, Steam/Play/App Store/TestFlight and public download;
- iOS runtime/package/signing work beyond existing unsigned build validation;
- licensing/provenance resolution;
- broad device/store certification and byte-reproducible build claims.

## Historical 10D3 handoff

Phase 10D3 owns the full normal-player critical journey, combat/loot/equipment/Vine
coverage, manual Save and unsaved-process-death-Continue behavior, a representative Save
blocker, final candidate runtime/log acceptance and the Windows pristine-ZIP acceptance
defined by the Technical Demo gate. Extended soak/profiling remains risk-triggered under
the owner-approved 10D1 boundary.

**PHASE 10D2 — TECHNICAL DEMO PACKAGING PASSED. PHASE 10D3 — BLOCKED / SUSPENDED;
ACCEPTANCE NEVER PASSED.**
