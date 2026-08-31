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
- `game/addons/godot_ai/plugin.cfg` identifies addon version 3.2.4.
- It is retained in the development repository but removed from the sanitized production project and
  is not shipped in Phase 10A runtime artifacts.

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
