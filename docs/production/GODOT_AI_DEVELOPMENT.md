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
