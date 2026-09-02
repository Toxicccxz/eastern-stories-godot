# Godot AI Development Boundary

Godot AI 3.2.4 is vendored under `game/addons/godot_ai/` for editor/MCP and live runtime inspection.
The development project enables its editor plugin and `_mcp_game_helper` autoload. Phase 10A does
not remove or weaken that development workflow.

On this Windows workstation, TCP 5940–6039 was reserved and blocked the former Godot remote-debug
port 6007. Port 6107 was validated locally and is currently tracked in `game/project.godot` through:

```text
--remote-debug tcp://127.0.0.1:6107
```

That port is a machine-specific workaround, not a team-wide requirement or release setting.
Developers diagnosing a similar issue should inspect their own excluded TCP port ranges and choose a
locally available port. The migration runtime evidence is recorded in
`docs/migration/GODOT_AI_RUNTIME_VALIDATION_ADDENDUM.md`.

Every production build starts from a fresh sanitized copy. The sanitizer removes:

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

## Known editor-only shutdown warning

Godot AI 3.2.4 can retain a `server_version_check.gd` / `server_lifecycle.gd` mutual reference on
interactive editor exit. The isolated diagnosis identified five ObjectDB instances and two resources,
not Shell/Settings/Host/Session objects. See the
[formal audit diagnosis](../migration/PHASE_10C1C_FORMAL_AUDIT.md#editor-only-lifetime-warning-explained-not-hidden).

The vendor plugin is unchanged. Sanitized builds exclude it, and the independently validated
no-plugin game and automated runs did not show this warning. This is not permission to ignore other
leaks: inspect resource names and reproduce any new warning before classifying it as tooling-only.
