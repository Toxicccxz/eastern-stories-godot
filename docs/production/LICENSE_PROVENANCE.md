# License and Provenance Evidence

This file is an evidence ledger, not legal advice or a commercial-clearance opinion.

## Native Eastern Stories Godot code

- Root `LICENSE`: **absent** at the Phase 10A baseline.
- No repository file grants a license for the native project as a whole.
- Decision: do not create a root license without an explicit owner decision.
- Status: **UNRESOLVED**.

## Authoritative `reference/es2`

- `reference/es2/README` says: “Created by Raymond Xie, published under MIT license.”
- `reference/es2/LICENSE` is MIT text but names “Copyright (c) 2014-2016 The Wekan Team.”
- Those holder/attribution statements do not reconcile on the available evidence.
- The reference tree remains read-only and is outside the Godot export root.
- Status: **UNRESOLVED**. No ownership reconciliation or commercial-clearance claim is made.

## Godot AI addon

- Vendored locations: `game/addons/godot_ai/` and duplicate repository evidence at
  `game/godot-ai-LICENSE.txt`.
- Both local license texts are MIT License, “Copyright (c) 2025 Godot AI contributors.”
- `game/addons/godot_ai/plugin.cfg` currently identifies addon version **4.2.3**.
  The [official v4.2.3 release](https://github.com/hi-godot/godot-ai/releases/tag/v4.2.3)
  points to upstream commit `f58314d9473d11efef94dd68b523e1b52643d736`; this identifies
  the upstream release, not verified equality of the current local vendor tree.
- Current local-to-upstream source/manifest equivalence, release-manifest file count and
  ZIP SHA-256 have **not been independently verified** in this closeout. The old 4.0.1
  hashes and 283-file comparison are historical only; see
  [vendor provenance](GODOT_AI_DEVELOPMENT.md#vendor-provenance).
- The retained 4.0.4 -> 4.2.3 update received a bounded independent dependency review in
  the [Snow Martial Final Audit](../migration/PHASE_SNOW_MARTIAL_PROGRESSION_II_FINAL_AUDIT.md#godot-ai-and-project-configuration).
  It is not Liuh-Ken gameplay or part of P2R2.
- The existing [release sanitizer](../../tools/build/prepare_release_project.py) removes the
  development addon, duplicate license file and helper/plugin activation from production output.
  Local MIT notices do not establish a license or commercial clearance for the project as a whole.

## Godot Engine/runtime

- CI downloads the official Godot 4.7.2 editor/templates from the `godotengine/godot-builds`
  release and verifies the official `SHA512-SUMS.txt` entry.
- Godot 4.7.2 `LICENSE.txt` is MIT and identifies “Copyright (c) 2014-present Godot Engine
  contributors” and “Copyright (c) 2007-2014 Juan Linietsky, Ariel Manzur.”
- Exported platform artifacts contain the Godot runtime even though engine binaries/templates are not
  committed to this repository. A future distributable release must carry the required notice.

## Other current assets

The only tracked non-code visual asset under `game/` at the Phase 10A baseline is `game/icon.svg`,
the Godot project icon. No external authored art/audio pack was found in the current game tree. This
inventory is not a guarantee about future content.
