# P2R2 — Generalized Player Display Name Policy

## Status and authority

Bounded implementation and local verification COMPLETE; owner review pending. Phase branch:
`phase/snow-martial-progression-liuh-ken`. Starting local/origin HEAD:
`3cf9c67e4514e9131f1492a36454ebc625376608`; integrated main:
`36a26b13e2bdebeb44c14c0a013d509000c29476`.

The prompt's older expected HEAD `4af0878692ad07c0e96f115d5ca18b00b0d0b58e`
predated the owner's subsequent commits. After preflight identified that difference,
the owner explicitly directed continuation on the current state. The Godot AI update
at `d9f6770a4dddb0b7fdc74e8a50ba6ff50964c150` is retained. No claim is made that
all intervening commits were documentation-only. P2R1's approved executable/test
freeze remains `798842879ebea52b33e7e2136f606a3741659590`; P2R2 becomes a new
candidate freeze only after owner review. Initial branch/origin matched, worktree/index
were clean and any-state phase PR lookup returned no PR.

## Source and compatibility

[ES2 logind.c](../../reference/es2/mudlib/adm/daemons/logind.c),
`check_legal_name` lines 450–474, requires Chinese text, checks legacy byte length
2–12 and rejects controls/banned names. The prior Native policy used Unicode
code-point length 1–6 and `\p{Han}+`. The owner intentionally replaces that script
restriction for international single-player display identity. This is the concise
[Type B product decision](DECISIONS.md#generalized-player-display-names).
Reference source and historical New Game Entry reports remain unchanged.

ASCII names such as Alice/Xavier incidentally work with input environments lacking
arbitrary Unicode transport. That is not the policy's semantic motivation or a
claim that an acceptance-tool transport limitation is fixed.

## Rules and reusable API

[NewPlayerNamePolicy](../../game/application/new_game/new_player_name_policy.gd)
remains the one authoritative application boundary. `default_rules()` returns fresh
typed `Rules`; `validate(value, rules = null)` returns `ValidationResult`, with
`succeeded` and `reason`; `is_valid(value, rules = null)` is the compatibility wrapper.

| Setting | Default and contract |
| --- | --- |
| `minimum_length` / `maximum_length` | 1 / 24 Unicode code points; marks/separators also count, not UTF-8 bytes, UTF-16 units or graphemes |
| Letters | Unicode category L across scripts |
| Marks | Unicode category M only following an uninterrupted letter/mark sequence; no orphan mark or mark after separator/digit |
| `allowed_separators` | Exact ASCII space, hyphen-minus, straight apostrophe, curly apostrophe U+2019, middle dot U+00B7; internal only, no adjacent separators |
| `allow_digits` | false; explicit opt-in permits Unicode decimal digits Nd, not all number categories |
| `reserved_names` | Empty by default; optional exact, case-sensitive comparison without normalization |

Godot's built-in RegEx Unicode categories provide classification. Default-ignorable
code points and extended pictographic characters are explicitly excluded, including
L/M exceptions such as Hangul fillers, variation selectors and pictographic letter
U+2139. Controls, formats, private-use, symbols and arbitrary whitespace cannot
enter through the letter/mark/digit categories. The default separator allowlist
rejects slashes, underscores, colons, semicolons, brackets and markup punctuation.
Developer-configured separators must themselves be punctuation or ASCII space;
letters, marks, digits, controls and arbitrary whitespace are invalid rules.

Reasons: `VALID`, `INVALID_RULES`, `EMPTY`, `TOO_SHORT`, `TOO_LONG`,
`INVALID_CHARACTER`, `LEADING_SEPARATOR`, `TRAILING_SEPARATOR`,
`CONSECUTIVE_SEPARATOR`, `RESERVED_NAME`. Validation rejects instead of silently
trimming, filtering, rewriting case/punctuation, transliterating or normalizing.
This is syntax validation, not profanity filtering, uniqueness or network moderation.

Examples accepted: 雪, 凌雪, 一二三四五六, 𠮷雪, Alice, Xavier, José, Élodie,
Jean-Luc, O'Connor, O’Connor, Mary Jane, 山田太郎, 김민수, Αλέξανδρος, Алексей,
阿依古丽·买买提, decomposed Jose + U+0301, Arabic and Devanagari names.
Examples rejected: empty/space-only text, leading/trailing spaces, Alice1, 雪1,
雪😀, 😀, ℹ, A/B, A\\B, A_B, Jean--Luc, Mary  Jane, O''Connor, -Alice,
Alice-, ·Alice, Alice·, newline/tab, zero-width and bidi-format characters,
orphan marks and 25 supplementary-plane letters.

## Callers, presentation and identity

[ApplicationShell submission](../../game/runtime/application/application_shell_controller.gd)
and [Host request_new_game](../../game/runtime/persistence/oldpine_game_runtime_host.gd)
both call the same policy before requesting a Session. No Host adaptation/bypass
was necessary. The setup prompt and
[scene placeholder](../../game/scenes/application/application_shell.tscn) now say
1–24 characters across languages. The error describes attached marks, exact internal
separators, no adjacent separators, and the digit/emoji/symbol restrictions.

[World Session](../../game/runtime/world/oldpine_world_session_controller.gd) still
uses `PLAYER_ID = &"oldpine.player"` independently of the exact entered name.
Source-entry composition stores the accepted display string without transformation.
Automated public journeys verify PlayerIdentityFacts, rendered NameLabel, encounter
display name, Save payload, fresh Continue runtime and DeathContext all preserve it
exactly. Tested additional journeys: Alice, José·凌雪 and decomposed `José O’雪`.
DeathContext projection does not execute a death. Save root schema 2, item schema 3
and SOURCE_ENTRY_V1 remain unchanged.

## Preserved contracts and scope review

Public birth remains Snow Inn, age 14, eight attributes 30, EXP 0, potential 99,
gin/kee/sen 100 current/effective/maximum, food/water 400, source cloth only,
empty hands, no skills, no money and no autosave; gender selection stays explicit.
Existing birth/confirmation/unsupported-save regressions remain in the suite.

Only name policy, two setup messages and one placeholder change production naming
behavior. Tests extend the existing public-source test instead of adding a runner.
P2R1 death composition, DeathInventoryService, death/corpse facts, Liuh, Learn,
Enable, combat resolution/action selection, Flee, EXP, RNG and balance are untouched.
All `game/core`, `game/data`, `game/runtime/world`, persistence and P2R1 tests are
unchanged from the approved P2R1 freeze. No source, fixture, tools or CI code changed.

The full Python run exposed an existing failure introduced by the accepted Godot AI
update: two explicit desktop viewport entries were removed while the release test
still required them. The owner separately authorized restoring only
`window/size/viewport_width=1152` and `window/size/viewport_height=648` in
`game/project.godot`. Mobile entries, plugin update and test expectations remain intact.

## Validation evidence

| Gate | Fresh final result |
| --- | --- |
| Existing NGE5B focused runner | 2,303 assertions, 0 failures, exit 0 |
| Complete canonical gameplay suite | 20,945 assertions PASS; 337 more than the P2R1 baseline of 20,608 |
| Full Python tooling suite | 656 tests, OK; 0 failures/errors/skips |
| Repository/static checks | PASS |
| Development Godot headless/editor validation | exit 0; no script/runtime errors |
| Actual release sanitizer | PASS with unchanged confinement rules |
| Sanitized-project Godot headless/editor validation | exit 0; no script/runtime errors |
| Complete verify.py | All five stages PASS, exit 0; no skip flags |
| git diff --check | PASS |
| Changed-document relative links/anchors | 5 documents, 226 occurrences, 0 errors |

Focused runner: `res://tests/run_nge5b_tests.gd`, 2,303 assertions, 0 failures,
exit 0. Covers name policy/configuration, public Shell/Host, mobile lifecycle,
source Save/Continue, body facts and legacy integration. Configuration tests change
both bounds, enable cross-script decimal digits, remove/replace separators and
exercise exact reserved names with independent default collections. Supplementary
letters test the 24/25 boundary; decomposed marks test code points versus graphemes.
The initial test used String.chr(0), which Godot reports as invalid Unicode and
replaces; that noisy test construction was removed. Other controls and replacement
characters remain tested, and the final focused log has no runtime/script errors.

Full-gate commands use the pinned Godot 4.7.2 console executable and
`python tools/ci/verify.py --godot <pinned executable>`, with no skip flags.
The first complete invocation ran all 656 Python tests with one pre-existing
viewport-config failure. A fresh complete invocation passed after the authorized repair;
the original failure is retained in ignored local evidence.

Local evidence remains ignored under `build/`: focused log, full-gate logs and
sanitized projects. The successful Godot AI updater's inactive old-version backup
was moved from `game/addons/.godot_ai_update` to
`build/p2r2-preserved-godot-ai-update`; all 286 files were compared by relative path
and SHA-256 before/after, byte-identical. Nothing was deleted and no sanitizer,
plugin or release-security rule was weakened.

An additional diagnostic continuation, launched while the viewport authorization
was pending, mistakenly passed a relative test-environment path. Its editor emitted
cache/user-directory I/O errors and its sanitizer correctly rejected generated
editor settings containing an absolute path. It is not the certifying run. Its
21 generated files under `game/build/p2r2-test-environment` were preserved byte-for-byte
under ignored `build/p2r2-preserved-diagnostic-data`; unrelated older directories
were untouched. The final canonical `verify.py` uses its established absolute
environment path. No failing test or security gate was disabled.

Final evidence: `build/p2r2-focused-final.log` and
`build/p2r2-full-verify-final.log`. The final full log contains the 656-test OK,
20,945-assertion PASS and `Phase 10A verification PASS`, with no ERROR/SCRIPT ERROR.
Complete production/test diff was separately reviewed after validation. The
generalized-name policy uses Unicode property tables bundled with the pinned engine,
not an added dependency or a handwritten table of accepted names.

## Exact changed files

- `game/application/new_game/new_player_name_policy.gd`
- `game/runtime/application/application_shell_controller.gd`
- `game/scenes/application/application_shell.tscn`
- `game/tests/application/public_source_new_game_test.gd`
- `game/project.godot` (separately authorized two-line restoration)
- `docs/migration/DECISIONS.md`
- `docs/migration/PHASE_NEW_GAME_GENERALIZED_NAME_POLICY.md`
- `docs/migration/PHASE_SNOW_MARTIAL_PROGRESSION_II_RUNTIME.md`
- `docs/production/STATUS.md`
- `docs/production/ROADMAP.md`

## Narrow actual UI validation

Canonical ApplicationShell was launched with autosave=false through Godot AI 4.2.3.
Real framebuffer mouse press/release opened New Game, its existing-save warning,
then setup. With name empty and gender unset, real Start Journey displayed the new
validation error; the complete message wrapped within the panel with both action
buttons visible. Frames 2264, 7986 and 10071 advanced with `stale_frame=false`.
`helper_live=true`, `session_active=true`, `game_capture_ready=true`; launch
`current_run_errors=[]`. Retained game log run `r4951712-1` has six informational
entries, no errors, and `session_count=0`, `staging_count=0`. Editor inspection found
56 existing warnings and no error rows. The game was then stopped.

This was pre-birth UI validation only: no fixture, game_eval, state setter, live
Player, Save/Continue click, combat or progression. Existing Save was not consumed.
Automated Save/Continue journeys above use isolated in-memory test storage and are
not P2 changed-path live acceptance. Physical mobile devices were not requalified.

## Owner gate

P2R1 remains approved/closed. P2 live acceptance remains OPEN / BLOCKED; EXP6,
Flee and cold gameplay Continue are not newly accepted by this work. No historical
attempt or New Game Entry report was rewritten. No PR, merge, Final Audit, P3 or
Migration Tooling P3. The new commit is for owner review; stop before live acceptance.

**GENERALIZED PLAYER NAME POLICY COMPLETE — AWAIT OWNER REVIEW**
