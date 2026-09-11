# NGE5B — Public Source-valid New Game Cutover

## RESULT

Implementation on `phase/source-valid-new-game-entry`, from approved
`3eb83badb8f92bdaa2f3910012f60ec0aaca8e34`. Focused, complete canonical and desktop validation PASS.
Android packaged startup/input/validation/Back/Cancel smoke also PASS within the boundary below.
NGE5B is implementation complete / await owner review, not formally audited or integrated.
No PR/merge, NGE6 or further Snow content is authorized.

## PUBLIC NEW GAME FLOW

Canonical ApplicationShell: Main Menu -> existing-save confirmation when material exists ->
New Journey -> valid name and explicit gender -> Host -> source Session -> Snow Inn.
Recovery's Start New Game converges on the same confirmation/setup. Neither confirmation,
draft editing nor cancellation creates a Session or writes/deletes a save. Only explicit Save
writes the journey. Continue and successful recovery bypass setup.

## NATIVE CHARACTER ENTRY DECISION

Single-player entry collects display name and the two existing legacy genders only. It omits
account ID, password, email and multiplayer security. See **Native Character Entry** in
`DECISIONS.md`. Stable Player identity and save keys are not derived from the name.

## NAME VALIDATION

`NewPlayerNamePolicy` is a Node-free typed validator: String code-point length 1–6 and a fully
anchored Unicode Han match (`\A\p{Han}+\z`). It rejects whitespace, controls (including a final
newline), Latin, digits and emoji without trimming, substituting or truncating input. Supplementary
Han code points are supported. Invalid drafts stay visible and unchanged.

Direct source inspected: `reference/es2/mudlib/adm/daemons/logind.c::check_legal_name`, called by
`get_name`, expresses 1–6 Chinese
characters through the old 2–12-byte encoding-era check. Native code does not copy its account
workflow or multiplayer banned-name service. No other gameplay formula is introduced here.

## GENDER

No default selection. Two explicit buttons map only to `CharacterState.GENDER_MALE` and
`GENDER_FEMALE`. No attributes/race/class/portrait customization is added.

## PUBLIC SOURCE BOOTSTRAP

`OldPineGameRuntimeHost.request_new_game(display_name, gender)` has no no-argument path and
independently validates both fields before queuing work. It calls `configure_source_entry` on the
fresh Session before attaching to SessionSlot. Failure discards the candidate and uses the existing
failure result; there is no technical fallback. Existing Host pending/invariant guards and Shell
STARTING guard prevent duplicate submissions.

ApplicationShell always configures a manual Host. Existing explicit auto-start technical fixtures
remain internal; they are not an alternate menu/profile option.

## SOURCE PLAYER FACTS

The existing NGE1 initialization authority supplies Human, age14, title普通百姓, eight attributes30,
potential99, exp0, gin/kee/sen100/100/100, food/water400, body80000/cap150000, one worn cloth with
armor+1, empty hands, no money and no skills. Application code does not duplicate these values.
No starting long/short/bamboo sword or dagger. Name and gender feed the same existing facts,
body label, DeathContext and schema2 continuation authorities.

Source formulas and owner-approved food/gift choices remain as recorded in NGE1 and NGE5A1;
this slice changes entry composition, not initialization formulas or save serialization.

## SNOW START

The first authoritative location is region `snow`, map `snow.inn`, zone `snow.inn.main_floor`,
birth marker `(0, 0)`. Four resident maps exist immediately. No temporary Old Pine birth/handoff.
Inn east door -> Square -> Snow south/east road -> Old Pine North Approach reuses NGE2–NGE4.
The menu subtitle now says 雪亭镇, without claiming full Snow content.

## SAVE / CONTINUE

Public-created source Sessions write schema2 + explicit `SOURCE_ENTRY_V1`; the revision is not
inferred from position. Existing valid NGE5A source saves continue through the unchanged codec,
restore builder and transactional Host. Both genders and 1/2/6-code-point names are exercised
through public birth -> explicit Save -> fresh Shell/Host Continue with new object identities.

## PRE-CUTOVER SAVE POLICY

Schema1 is unsupported. Pre-cutover technical saves have no compatibility guarantee. Unsupported
material still invokes the ordinary New Game confirmation and is not deleted/migrated. Setup and
birth leave all existing bytes intact until the player explicitly saves.

## TECHNICAL FIXTURE STATUS

Public technical New Game is retired. Explicit technical regression Sessions remain for existing
Combat/CXR/Old Pine/Beast assertions. `TechnicalShellFixture` is tests-only: it attaches a technical
graph to a manual Host for tests whose subject is already-running combat/HUD behavior, not public
birth. `PublicNewGameTestFixture` submits a valid source name/gender for shell lifecycle tests.
Neither helper is shipped by the sanitizer or used as real-input acceptance evidence.

The cutover exposed one missed Battle test: it assumed one New Game tap immediately created the
old graph, then returned early without restoring viewport size. That contaminated later picking
coordinates. The test now explicitly uses the technical fixture and restores dimensions even on
failure. No production picking, movement, combat or HUD rules were changed to accommodate tests.
Mobile layout regression waits for deferred fixture layout before comparing node stability.

## APPLICATION STATE MACHINE

Dedicated `NEW_GAME_SETUP` is a non-busy state with Operation.NONE. Only valid submission enters
STARTING_SESSION/NEW_GAME. Cancel/Escape/Android Back return to Main Menu. Escape is intercepted
before LineEdit can swallow it; existing activity/input quarantine still precedes handling. Name
uses native LineEdit/IME/software keyboard. The existing safe-area responsive panel machinery and
explicit focus cycle include name, gender, Start and Cancel. No draft is saved in settings/gameplay.

## DESKTOP LIVE ACCEPTANCE

PASS through canonical production ApplicationShell, Godot AI runs22/23. Before the player route,
only storage was redirected to isolated test profile `nge5b-live-public` to protect owner saves;
FPS was capped for measurement. No source launcher, direct birth, teleport or traversal callback
substituted for the route. The Chinese name 凌雪 was typed as real InputEventKey Unicode events
(20940/38634), not assigned to LineEdit.text. Gender and Start used framebuffer clicks.

Verified source Inn facts above, then real movement through the east door to Square. Real Pause
and Save wrote SOURCE_ENTRY/schema2 at `(-192.666656494141, 0)`. The game process was stopped;
fresh canonical main + real Continue restored the exact name/gender/location/body, cloth semantic
ID, allocator scope/sequence and three RNG states. Player object identity changed from
`-9223371782377960860` to `-9223371646482511051`, while semantic identity remained exact.
Continued real movement along the roads reached Old Pine North Approach `(450, -332.3335)`.

Helper was live, session active, capture ready, current runtime errors empty. Captures were
non-stale with advancing frames (Old Pine frame16883). An initial stale editor class-name cache
error was resolved by explicit policy preloads; runs22/23 were clean. This is route/continuation
proof, not combat victory or full Snow content acceptance.

## MOBILE / RESPONSIVE VALIDATION

Desktop embedded runtime was evaluated at a logical 420x740 viewport. Physical embedded output
stayed1152x648: this is logical narrow-layout proof, not a portrait physical-device claim. Field,
gender and Start/Cancel were within the safe content area; touch buttons were64px tall. Actual
cancel input returned to Main Menu with no Session and an unchanged save hash.

Additional canonical runs24/25 verified narrow input: real Start with empty name stayed in setup
with a local error and no Session; real name input produced 凌雪, real male-button input selected
only male, and real Cancel returned to Main Menu with no pending request/Session. Run25 capture
frame5946 was non-stale; helper/session/capture were healthy. A temporary multiline QA input
probe failed to compile in run24 and paused the debugger, so that run was stopped and the valid
input/cancel sequence repeated in clean run25. This did not change production code.

Android arm64 sanitized candidate builds successfully using official Godot4.7.2/Temurin17 and
the existing build pipeline. With explicit owner permission, only `com.example.easternstoriesgodot`
was uninstalled (including that test package's local saves) and replaced on OnePlus8T/KB2005.
APK SHA256: `b18f2b2c302705da5b7f2b4e459d07bba3800d73815ebd487a99e27ece15b9e8`.
Production source matches its staging copy. No other app was replaced.

Packaged startup and actual Android input smoke: canonical main shows 雪亭镇 and no save;
New Game opens the complete setup panel; tapping LineEdit opens native Gboard; system text input
reaches LineEdit; keyboard Back hides the IME while retaining the draft. Selecting female then
Start with `Alice` correctly retains input and shows local validation rather than starting a
Session. With IME hidden, Android Back returns to Main Menu rather than exiting; reopening setup
then tapping Cancel does the same. Menu still reports no saved journey.
Captures: `build/nge5b-android-{menu,setup,keyboard,text,invalid,back,cancel}.png`.
Renderer is Vulkan1.1.128 / Forward Mobile / Adreno650. Current-process log contains no GDScript
error, parse error or fatal exception. Android's 4x4 AHardwareBuffer probe warnings are present
but did not prevent rendering/input; they are not claimed to be absent.

This is a bounded device smoke, not full Android end-to-end qualification. Chinese IME composition
and successful Android birth are NOT claimed: the currently selected keyboard is English and the
optional owner Chinese-input request was not completed during this smoke. No keyboard configuration,
additional IME installation or game-state injection was used to bypass that evidence gap. Desktop
real Chinese birth/cold Continue and automated Unicode tests are separate evidence; Chinese mobile
IME candidate composition and iOS device behavior remain future device-qualification coverage.

## TESTS

- Focused NGE5B + Shell10C1A/B/C + mobile lifecycle + source save/body: **1,636 assertions PASS**.
- Expanded Battle/CXR/Old Pine/mobile UI regression: **6,027 assertions PASS**.
- Development headless editor, sanitized headless editor and sanitized canonical main startup PASS
  with Godot4.7.2. Sanitization uses a repository-file staging copy because ignored owner-local
  plugin update backups are intentionally preserved; test/QA/addon code is excluded.
- Reference, build/CI/export and project.godot changes: zero. `git diff --check` PASS;
  changed/untracked text files have zero trailing-whitespace findings.

## COMPLETE CANONICAL

`res://tests/run_tests.gd`: **18,192 assertions PASS, zero failures, exit0**, official Godot4.7.2;
log `build/nge5b-canonical-complete.log`. Earlier failed/incomplete runs are not PASS evidence;
they exposed the missed old Battle fixture and consequent viewport contamination. A subsequent
test-label-only clarification identifies the old initialization subject as an internal fixture;
it changes no test execution or assertion count.

## OUT OF SCOPE

No new Snow population/services/training, character customization, autosave, old-save migration,
recovery heartbeat, Lake/serpents, Phase5B4, art, PR or merge. Technical fixture removal is deferred
to an independently authorized final audit.

## NGE6 READINESS

Ready for NGE5B owner review, with the mobile qualification limits explicitly recorded above.
NGE6 may be considered only after owner authorization; no NGE6 work has started. No PR or merge.
