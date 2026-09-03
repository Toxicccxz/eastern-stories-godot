# Eastern Stories Godot

Eastern Stories Godot is a native Godot RPG migration of classic Eastern Stories / ES2. The
project preserves meaningful legacy rules and authored content while rebuilding movement, maps,
runtime interaction, and presentation as a real RPG. It is not an LPC interpreter, a FluffOS
compatibility layer, or a graphical MUD client.

The supported Phase 10A engine is exactly **Godot 4.7.2**. Open
`game/project.godot`; the current playable milestone is the Old Pine session with combat, loot,
inventory/equipment, the Vine and Cave Passage roundtrip, Waterfall, River, Cliff, and Pine route.
Phase 10C2 is fully integrated: the shared mobile layer implements responsive layout, SafeArea,
sensor landscape, a fixed touch movement pad, Android Back, lifecycle freeze, explicit Resume,
and manual-save-only durability. Android emulator evidence is not qualification of physical
Android devices, ARM64 hardware, production Vulkan or physical multitouch. iPhone/iPad runtime
remains unqualified. The game is incomplete and is not store-ready or production-ready.

## Repository layout

- `game/`: native Godot project, gameplay tests, and development-only Godot AI addon.
- `reference/es2/`: read-only authoritative LPC source; never part of release staging.
- `docs/migration/`: source-traceable migration records and compatibility decisions.
- `docs/production/`: current status, roadmap, build/CI, repository, and provenance evidence.
- `tools/`: standard-library Python verification, sanitizer, and build tooling.

## Verify and build

With Python 3.12 and Godot 4.7.2:

```text
python tools/ci/verify.py --godot <path-to-godot-4.7.2>
python tools/build/build.py --target windows --godot <path-to-godot-4.7.2> --templates <path-to-4.7.2.stable-templates>
python tools/build/build.py --target android --godot <path-to-godot-4.7.2> --templates <path-to-4.7.2.stable-templates> --android-sdk <android-sdk> --java-sdk <temurin-jdk-17.0.18+8>
python tools/build/build.py --target ios --godot <path-to-godot-4.7.2> --templates <path-to-4.7.2.stable-templates>
```

iOS export and compilation require macOS and Xcode. See
[BUILD.md](docs/production/BUILD.md) before using these commands.

## Project evidence

- [Current status](docs/production/STATUS.md)
- [Roadmap](docs/production/ROADMAP.md)
- [Build and CI](docs/production/BUILD.md)
- [Major-phase branch, PR, and integration policy](docs/production/REPOSITORY_POLICY.md)
- [Godot AI development and live-runtime evidence](docs/production/GODOT_AI_DEVELOPMENT.md)
- [License and provenance evidence](docs/production/LICENSE_PROVENANCE.md)

The repository currently has no root project license. ES2 attribution/license evidence contains an
unresolved discrepancy; no commercial-clearance claim is made.
