# Phase 10C1A Formal Audit

## Result

Phase 10C1A satisfies its formal-close gate after three narrow lifecycle corrections and one historical
test-expectation correction. The production hierarchy remains:

```text
ApplicationShell (ALWAYS)
└── exactly one persistent OldPineGameRuntimeHost (ALWAYS)
    ├── SessionSlot (PAUSABLE) -> zero or one committed Session (INHERIT)
    └── StagingSlot (PAUSABLE) -> empty outside the existing restore transaction
```

The Host is the sole current-Session authority. The Shell stores only its Host reference, typed shell
state, typed slot metadata, and a typed product result. Static inspection found no `GameSaveSnapshot`,
repository, file path, or second current-Session pointer in the application layer.

## Audit corrections

1. MANUAL Host startup previously reported success without first proving that both runtime slots were
   empty. It now reports `SESSION_INVARIANT_FAILED` for a pre-contaminated graph.
2. Slot inspection, New Game, and Continue previously checked only `_current_session == null`. They now
   require the complete empty-Host invariant, so an orphan committed/staging child cannot be mistaken
   for an empty Host.
3. The Shell previously passed a nominal runtime success through the product mapper even if its own
   post-operation Session invariant check failed. Such contradictions now become the stable typed
   `SESSION_FAILURE` result and never display success.
4. Four historical Phase 9 scene tests still expected 226 Outdoor nodes after Phase 10C1A intentionally
   removed the Reset button. Their exact structural expectation was corrected to 225. No production
   scene was changed for this test correction.

No save schema, restore composition, gameplay rule, map, combat, item, or NPC behavior changed.

## Authority and operation proof

- Shell configuration precedes Host construction. A configured Shell cannot be configured again.
- The development QA bridge observes the Shell during tree entry, supplies the development profile,
  and the Shell configures its Host once before adding it to the tree. A sanitized production Shell has
  no QA bridge and independently defaults to the release profile.
- MANUAL startup publishes no Session and queues advisory slot inspection only after the empty Host has
  reported success.
- Inspection returns metadata through `ApplicationSlotInspection`; the loaded snapshot is discarded at
  that boundary.
- Continue calls the existing `OldPineSessionLoadCoordinator.load_replacing()` with no current Session.
  It therefore performs a fresh canonical repository read and uses the closed Phase 10B restore path.
- New Game initializes a candidate only after explicit intent, publishes the Host pointer only after
  complete validation, and detaches/queues a partial graph for freeing on failure.
- Inspection, New Game, Continue, Save, Load, and end-Session share one Host request gate. Adversarial
  tests prove concurrent rejection and gate release after success and failure.
- Confirmed New Game with canonical, backup, and temporary material mutates none of those bytes.

## Product and UI boundary

Every `GameSaveResult` outcome maps to one typed slot availability without inspecting `path`, `detail`,
or log text. Runtime busy, repository, restore, and Session failures map to stable product outcomes and
message keys. A valid inspection is advisory: if canonical bytes change before the click, Continue
fails from the fresh read, leaves both slots empty, and never falls back to New Game.

Busy and Result overlays use full-rect `MOUSE_FILTER_STOP` Controls and disable the underlying menu
buttons. New Game receives deterministic first focus. A disabled Continue click was inert; a fresh
process accepted keyboard Enter on New Game; a separate fresh process accepted a real mouse Continue.
With zero Session there is no gameplay map, player body, or gameplay input target.

The production Old Pine path contains no Reset button, `reset_requested`, `reset_world`,
`reset_session`, or `reload_current_scene()`. The historical standalone combat demo remains outside the
production Shell path.

## Automated verification

- Phase 10C1A focused plus targeted Phase 10B/Session/Outdoor regressions: **859 assertions passed**.
- Canonical complete Godot suite: **10,133 assertions passed**. Its first audit run exposed only the four
  stale 226-node expectations described above; the required post-fix rerun passed.
- Python tooling: **40 tests passed**.
- Repository/static checks: passed.
- Godot `4.7.2.stable.steam.ed1daf0bf` development headless editor validation: passed.
- Fresh release sanitizer and sanitized-project editor validation: passed.
- Explicit sanitizer `--validate-only`: passed.
- Sanitized canonical main-scene 60-frame headless smoke: exit 0.
- `git diff --check`, trailing-whitespace, reference, and scope checks are recorded in the final audit
  report after commit.

## Live validation

Godot AI 3.2.4 and Godot 4.7.2 reported `helper_live=true`, `session_active=true`,
`game_capture_ready=true`, `current_run_errors=[]`, advancing frame counters, and
`stale_frame=false` captures.

- Valid-save cold start: canonical root was `ApplicationShell`; one Host; zero committed/staging
  Sessions; real mouse Continue restored one Cave Session. Real movement changed Player from
  `(0, 120)` to approximately `(58.67, 120)`.
- Valid advisory inspection followed by QA corruption of canonical: real mouse Continue reported the
  typed recovery-required failure. SessionSlot and StagingSlot both remained empty; no New Game graph
  appeared.
- No-save cold start: one Shell and Host, both slots empty, Main Menu visible, New Game enabled, Continue
  disabled. A real mouse click on disabled Continue created no Session.
- A fresh no-save process accepted real keyboard Enter on the focused New Game button, created exactly
  one Outdoor Session with twelve bootstrap items, and left staging empty. Real movement changed Player
  from `(450, 300)` to approximately `(450, 241.33)`.
- Four independent application processes retained one Shell/Host and zero-or-one Session without signal
  or node duplication. Existing development save material was copied before destructive QA, restored
  byte-for-byte afterward, and all temporary preservation directories were removed.

## Deferrals

Phase 10C1B retains Pause/Resume, Save UI, explicit recovery selection, and Return to Main Menu.
Phase 10C1C retains Settings, focus/input hardening, sanitizer/release integration, and final shell
validation. Android Back, touch controls, safe-area/notch behavior, orientation, and mobile lifecycle
remain Phase 10C2. No 10C1B or 10C2 behavior was implemented by this audit.

No LPC source was needed or scanned because this phase audits application lifecycle and presentation
composition rather than a legacy gameplay rule.
