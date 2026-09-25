# Godot AI Development Boundary

Godot AI **4.2.3**, as identified by the current `plugin.cfg`, is vendored under
`game/addons/godot_ai/` for editor/MCP and live runtime inspection. The development project
retains its editor plugin and `_mcp_game_helper` autoload; production sanitization excludes them.

## Vendor provenance

### Current 4.2.3 evidence

Local `plugin.cfg` declares 4.2.3. Both `game/addons/godot_ai/LICENSE` and
`game/godot-ai-LICENSE.txt` contain MIT License text naming the 2025 Godot AI contributors.
The [official v4.2.3 release](https://github.com/hi-godot/godot-ai/releases/tag/v4.2.3)
points to upstream commit `f58314d9473d11efef94dd68b523e1b52643d736`.
This upstream identity alone does not prove equality of the local vendor files.

Repository update commit `d9f6770a4dddb0b7fdc74e8a50ba6ff50964c150` retained the
owner-authorized 4.0.4 -> 4.2.3 update. The
[Snow Martial Final Audit](../migration/PHASE_SNOW_MARTIAL_PROGRESSION_II_FINAL_AUDIT.md#godot-ai-and-project-configuration)
accepted it as an independent dependency/plugin update under bounded review, not
Liuh-Ken gameplay or P2R2. The separately approved desktop viewport restoration left
final `project.godot` equal to the pre-phase main version.

Current local-to-upstream source/manifest equivalence, release-manifest file count and
release ZIP SHA-256 remain **unverified in this closeout**. No unmodified-upstream or
manifest-equality claim is made for the current 4.2.3 vendor tree. The older evidence below
must not be reused as proof for this version. No plugin files are changed by this docs task.

### Historical 4.0.1 evidence

The earlier vendor verification recorded an unmodified upstream [v4.0.1 release](https://github.com/hi-godot/godot-ai/releases/tag/v4.0.1),
source commit `9b1f13aded0437da4974a2ccf11a9b94f0c15b29`. At that checkpoint, all 283 local
files matched the SHA-256 entries in the official `godot-ai-v4-plugin.manifest.json`:
no missing, differing, or extra files. That was an HTTPS release-manifest comparison,
not an independent signature verification or a fresh comparison in this closeout.
The release's `godot-ai-v4-plugin.zip` SHA-256 is
`3de4e9844ec2511a5646347e10d280b4a6fcf94a05881bd0912cb58968873ec0`.
The historical release required Godot 4.7+, compatible with the project's pinned 4.7.2 editor.

## Development and production separation

The addon is maintained independently of gameplay changes. Production sanitization remains mandatory.

On this Windows workstation, TCP 5940–6039 was reserved and blocked the former Godot remote-debug
port 6007. Port 6107 was validated locally and is currently tracked in `game/project.godot` through:

```text
--remote-debug tcp://127.0.0.1:6107
```

That port is a machine-specific workaround, not a team-wide requirement or release setting.
Developers diagnosing a similar issue should inspect their own excluded TCP port ranges and choose a
locally available port. The migration runtime evidence is recorded in
`docs/migration/GODOT_AI_RUNTIME_VALIDATION_ADDENDUM.md`.

Every production build starts from a fresh sanitized copy. The existing
[release sanitizer](../../tools/build/prepare_release_project.py) removes:

- `addons/godot_ai/`;
- the early development-only `scenes/mcp_test.tscn` smoke scene;
- the `_mcp_game_helper` autoload;
- the active Godot AI editor plugin entry;
- `--remote-debug` and the 6107 loopback argument;
- gameplay tests, after proving production has no test dependency.

Validation fails closed if a forbidden path or textual reference remains. The development checkout
and its MCP configuration are left untouched.

## Live runtime validation policy

`AGENTS.md` is the authoritative project-wide policy for deciding when live evidence is required.
For player-visible behavior, scene lifecycle, physical movement/collision, map traversal, combat
cadence, runtime UI, or packaged startup, headless tests and direct domain/controller calls are not
substitutes for running the canonical game path.

When Godot AI is used, first establish helper health (`helper_live`, `session_active`, and
`game_capture_ready`), inspect current runtime errors, and require non-stale captures whose frame
numbers advance when liveness matters. Exercise the acceptance path with real keyboard/input
actions, framebuffer mouse clicks, actual HUD controls, CharacterBody movement, and real
Area/collision entry as applicable. Directly invoking traversal/combat methods, callbacks, signals,
or teleporting to the expected result does not prove the player path. Deterministic QA setup before
the claimed route is acceptable only when disclosed and when the route itself still uses normal
gameplay.

If the helper does not connect, diagnose whether the game actually launched, helper/service state,
runtime errors, project configuration, and—on Windows—excluded TCP port ranges. Port 6107 is a
validated workaround on one workstation, not a portable project requirement. If required live
evidence remains unavailable, report it as blocked or pending rather than converting a headless
result into a live PASS. Do not change gameplay or domain semantics to accommodate development
tooling.

## Historical editor-only shutdown warning

Godot AI 3.2.4 was observed retaining a `server_version_check.gd` / `server_lifecycle.gd` mutual reference on
interactive editor exit. The isolated diagnosis identified five ObjectDB instances and two resources,
not Shell/Settings/Host/Session objects. See the
[formal audit diagnosis](../migration/PHASE_10C1C_FORMAL_AUDIT.md#editor-only-lifetime-warning-explained-not-hidden).

The vendor plugin was not patched for that diagnosis. This historical finding is not a claim about
whether the current upstream 4.2.3 fixes that warning. Sanitized builds exclude the addon, and the independently validated
no-plugin game and automated runs did not show this warning. This is not permission to ignore other
leaks: inspect resource names and reproduce any new warning before classifying it as tooling-only.
