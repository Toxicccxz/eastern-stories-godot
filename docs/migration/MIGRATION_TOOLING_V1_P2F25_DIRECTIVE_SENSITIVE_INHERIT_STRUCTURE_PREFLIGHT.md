# Migration Tooling v1 — P2F25 Directive-Sensitive Inheritance Structural Preflight

**P2F25 FIX IMPLEMENTED — AWAIT OWNER REVIEW / FINAL RE-AUDIT NOT YET AUTHORIZED**

## Authorization / frozen identities

This is the owner-authorized repair of FR24-01 / HIGH / D2-D3, not a milestone
Final Re-Audit. Branch: `phase/migration-tooling-v1`. Frozen main:
`cd07808cb76147d0b8c0dad9b82d078b49fefe64`. Pre-fix executable HEAD and required
single-commit parent: `c4335beba2412e628932f76efa099e2b9fd7f442`
(`Consolidate preprocessing-sensitive critical function structure`). Initial fetch,
branch, local/remote phase, main, merge-base, clean tracked/index state and all-state
phase PR absence were verified. P2F24 is CLOSED under the owner's current instruction.
The Final Re-Audit after P2F24 remains historically BLOCKED by FR24-01.

Exactly five tracked files are authorized: the extractor, its existing test module,
this report, [STATUS](../production/STATUS.md), and [ROADMAP](../production/ROADMAP.md).
[DECISIONS](DECISIONS.md#migration-tooling-v1-p2--owner-locked-extraction-boundary)
and D1-D9 remain locked. No lexer, CLI, source, game, workflow, schema or archive edits.

## FR24-01 root cause

There were two independent admission failures. Raw segmentation reset its statement
start at a directive and lost the connection between a macro prefix, authored
`inherit`, and a later semicolon. Separately, the direct-inherit parser could swallow
directive tokens into a multi-token base expression, set `symbol=None`, miss the NPC
exclusion and retain ROOM-derived facts. Both require full-object refusal, not a
reconstructed declaration or a partially retained fact set.

## Why post-segmentation safety was insufficient

The old shared structural gate ran after the raw root loop. At that point the prefix
fragment could already have been discarded and direct-inherit metadata allocated.
Adding another check to `unknown_top` would not cover the polluted direct-inherit
path. The shared gate now runs first inside `extract_structure`.

## Pre-segmentation structural preflight

The existing `macro_context` supplies bounded macro definitions, separate authored
units and root include origins. Each inspectable unit passes through the same
`preprocessing_admission_structure_use` scanner before raw inheritance/function
segmentation. On a hit, the extractor clears inheritance/category metadata and
returns with `supported_candidate=false`, `OUT_OF_SCOPE`, and `facts=[]` before
candidate calculation, inheritance facts, create parsing or exit staging.

Only two existing production methods changed, plus the extractor version and known
version set. AST comparison confirms no added production methods, imports, module
functions or changes to macro-effect, pairing, tail, mapping, key, receiver or exit
finalizer methods. No lexer or writer change was required.

## Root/reached dependency authored-unit model

Root and recursively reached local/nested/standard/cross-header units use the same
scanner and global bounded macro context. Units are never concatenated. Unreferenced
headers do not enter this check. A dependency with incomplete delimiter pairing
defers to the existing include/fragment safety policy; it is not parsed as a repaired
translation unit. P2F24's critical `set`/`create` adjacency checks remain in this gate.

## Inheritance state machine

The bounded state is represented by authored prefix, directive and inherit witnesses,
plus prefix eligibility. It does not parse the inherited base.

| State / evidence | Transition |
| --- | --- |
| No active structure; standalone directive | Preserve normal independent directive behavior |
| Pure preprocessing prefix | Preserve actual macro-use witness and opaque matched call groups |
| Prefix followed by directive | Retain prefix and first directive witness; do not reset it |
| Eligible authored, non-macro-shadowed `inherit` | Enter active inheritance state |
| Active inherit followed by any directive | Refuse the complete object |
| Prefix/directive followed by authored inherit | Refuse the complete object |
| Authored top-level semicolon | End/reset inheritance and prefix state |
| Definite unrelated authored material | End prefix eligibility; do not guess that it disappears |
| Matched group / function body | Skip its interior; do not promote nested tokens to top level |

### Pure preprocessing prefix state

Actual object/function macro uses, aliases, multiple uses and authored callable
continuations preserve a prefix witness. Arguments remain opaque. Uninvoked
function-only macros do not count as an actual use. Ambiguous definitions are treated
conservatively. Definite non-preprocessor prefixes remain unsupported rather than
being stitched into a hidden declaration.

### Direct inherit state and directive participation rule

An eligible non-shadowed top-level `inherit` begins a pending declaration. Every
directive family inside that declaration causes refusal, including apparently inert
pragma/echo/define directives. No whitelist, conditional evaluation or base recovery
is used. Actual macro-shadowed `inherit` retains P2F22's existing protection.

### Semicolon boundary rule

The authored top-level `;` completes the state. Directives wholly before a normal
declaration or after its completion do not contaminate it. An ordinary subsequent
NPC inheritance still follows the existing excluded-class policy.

## No declaration recovery / no macro or directive execution

No synthetic token, inserted semicolon, parameter substitution, expansion,
include-spliced translation unit, interpreted directive or LPC runtime was added.
Tests disable macro effect/reach/tail interpretation during positive preflight cases.
The scanner records only authored witnesses and refuses uncertainty.

## Root primary closure / direct-inherit symbol=None closure

Fresh pre-edit LF/CRLF execution reproduced the original broken primary and the
independent unprefixed `inherit NPC` / directive / `;` path, matching frozen prior
objects and findings. After the repair both return exit0, candidate false,
OUT_OF_SCOPE, empty direct inherits/categories/facts. No polluted multi-token
inherit reaches ordinary allocation. All positive handwritten fixtures use a failing
`fact()` spy; separate tests also make raw inherit parsing, list append and dependency
fallback fail, proving the shared preflight itself wins before segmentation.

## Directive family matrix / conditional directive matrix

Handwritten fixtures cover define, undef, pragma, raw echo, include, unknown, if,
ifdef, ifndef, elif, else and endif at keyword/base, base/semicolon,
prefix/inherit/directive and prefix/directive/inherit positions in root and header
units. Additional cases cover multiple directives, dangerous inheritance before or
after ROOM, missing includes inside the declaration, and multiple reached headers.
Conditionals wholly before complete inheritance remain negative controls for this
new rule; the existing conditional policy still applies independently.

## Dependency inheritance closure / root include provenance

Local, nested, standard, cross and nested-cross contexts refuse equivalently to root
cases. Both dependency findings use the real root include from `origins[path]`, not
dependency offsets against root bytes. Root findings use the authored directive and
inherit witnesses. Unicode and LF/CRLF tests validate path/hash/raw bytes/line/column;
no header replacement or recovered inheritance gets synthetic provenance.

## Original FR24 90 valid CLI / 36-shape sibling replay

The exact 45-shape audit family was freshly run before editing and again against the
candidate: 90 valid LF/CRLF CLI executions. All 22 formerly violating executions now
fully refuse; all 68 previously satisfying executions remain safe. B01-B36 account
for 72 executions; former violating B01/B03/B05/B07/B09/B29/B31/B33/B35 are all safe.
Four historical erroneous `/std/npc` executions remain archived and excluded.
The authoritative NPC path is `/std/char/npc` from
[globals.h](../../reference/es2/mudlib/include/globals.h), not a guessed alias.

Of the 68 old safe outputs, 46 remain object/finding-identical. B02/B04/B06/B08/B10/
B11/B12/B30/B32/B34/B36 (22 LF/CRLF runs) were already OUT_OF_SCOPE with no facts;
the earlier gate now also clears direct inherits/category metadata and emits its
two truthful refusal findings. This is the owner-authorized stronger refusal, not a
new supported candidate, fact or quarantine. The old audit/oracles were not edited.

## Expanded P2F25 matrix / independent preflight sweep

The product's handwritten 157-shape matrix plus three stress forms gives 160 shapes /
320 fresh CLI executions. The 20 negative shapes match the frozen parent's complete
object/finding outputs in both newline modes. Stress covers about 1100 aliases,
call groups and independent prefix uses without recursion dependence.
A separately authored sweep imports no product case list: 24 shapes / 48 CLI,
including direct and nested excluded/custom bases, cross-header definitions,
opaque arguments, missing include, competing headers, critical functions, completed
declarations, definite prefixes, nested code, unreferenced headers and fragments.

## P2F24 critical-function regression

Original FR23 replay 84 CLI, root expansion 348 CLI, independent root sweep 58 CLI,
dependency expansion 216 CLI and independent dependency sweep 64 CLI all pass.
Name-to-parameters and parameters-to-body gaps for set/create retain full-object
refusal across root and reached dependencies. Moving the gate earlier does not
replace its bounded logic or let header fallback mask it.

## P2F23 hidden-inherit / P2F22 keyword / P2F21 tail regression

P2F23 original 46 and expanded 98 CLI; P2F22 original 46 and expanded 82 CLI; P2F21
original 72, expanded 84 and primary 4 CLI all pass. Original arguments are not
reused as a continuation, true runtime tails remain quarantined, and matched groups
do not expose nested inheritance. Six P2F23 directive-prefix shapes now refuse with
empty metadata/facts rather than retaining partial facts: define, undef, pragma,
echo, include and unknown. This directly follows the authorized prefix-preservation
rule; their previous result is documented rather than silently called unchanged.

## P2F17-P2F20 exit regressions

The retained key matrix 500 CLI, FR19 94 CLI, expanded key matrix 294 CLI and
40 finalizer-independence probes pass. The create-expression family 270 CLI,
FR18 sibling family 56 CLI, expanded expression family 110 CLI and 12 separate
finalizer probes pass. Nested family 148 and mapping family 156 CLI retain atomic
exit refusal; primary regression 4 CLI passes. Unrelated/cross-object controls retain
their facts. No exit parser or allocation architecture was modified.

## P2F11-P2F16 structural regressions and authorized expectation changes

Retained aggregate CLI family 492, directive matrix 204 and delimiter matrix 118
pass. All prior repair unit classes are rerun. The any-directive-inside-inherit rule
intentionally converts nine P2F14 fixtures and one P2F15 fixture from quarantine to
conservative OUT_OF_SCOPE: P2F14 include-neutral-invocation, empty-include,
safe-include, safe-data, untyped-helper, unused-define-at-boundary, raw-echo, pragma,
undef; P2F15 raw-echo-only. Candidate remains false and facts remain empty.
P2F14 directive finding expectations now reflect the real inherit/directive witnesses;
the missing-include case stops at the earlier refusal instead of a later include
finding. Genuine malformed non-directive controls remain unchanged.

The first development full-suite log retained 22 assertion failures from these stale
expectations (20 newline assertions and two finding assertions). These were inspected
and updated only within the explicitly authorized stricter policy. Historical audit
files and historical harnesses remain byte-identical; only new ignored harness copies
carry the documented expectation changes. The subsequent complete gates below pass.

## Version 1.0.25 / compatibility / output security

Extractor version is 1.0.25; schema_version=1 and profile=static-room-v1 are unchanged.
All 26 versions 1.0.0 through 1.0.25 pass actual canonical replacement. Manual,
reviewed, unknown/future, malformed, empty and discovered nested unknown metadata
refuse with exit2, no writer call and unchanged target bytes. Protected destinations,
relative escape, tracked outputs, external checkout, symlink/junction where supported,
approved build/external output, invalid UTF-8 raw_hex and atomic writer failure remain
covered by the retained full security matrix and suites. No CLI/writer code changed.

## Fresh local checks and exact-commit gate

Pre-commit results: 39 complete groups; focused 6,
prior repair 365, migration 436 and full Python
482 tests PASS. Standalone matrix total: 4106 fresh CLI
executions (excluding unit-internal CLI calls, full corpus runs and compatibility
replacements). Compatibility: 26; discovered nested-schema positions:
33. Repository checks and `git diff --check` pass.

The single commit is `Preflight directive-sensitive inherit structure`, with the frozen
parent above. All 39 groups MUST run again on the immutable resulting SHA before
push; pre-commit evidence is not a substitute. This report records completed
pre-commit evidence and the mandatory post-commit gate, not a self-referential commit
hash or a premature post-commit claim. Ignored `p2f25/post-verification.json`,
`post-receipt.json` and `exact-commit-receipt.json` bind the completed rerun to its SHA.

## Corpus A/B

Two independent full scans both exit1 because of the retained 13 corrupt sources.
Each scans 2336 unique files: supported485; EXTRACTED0 / PARTIAL485 /
OUT_OF_SCOPE1838 / QUARANTINED13; facts2736; findings4296.
Both outputs contain 9808627 bytes and SHA-256
`caa55b857a86c5badc9c227edae19f33403de02d9754b0dcc1d61c82ea380431`. Bytes are identical.

| Finding code | Count |
| --- | ---: |
| CALLBACK_BEHAVIOR | 284 |
| DRIVER_SEMANTICS_UNKNOWN | 408 |
| DYNAMIC_EXPRESSION | 10 |
| ORDER_SENSITIVE_MUTATION | 30 |
| OUT_OF_SCOPE | 1319 |
| REQUIRES_SEMANTIC_REVIEW | 1623 |
| RNG_SEMANTICS | 58 |
| SOURCE_ENCODING_ISSUE | 8 |
| SOURCE_SYNTAX_ERROR | 5 |
| UNRESOLVED_INCLUDE | 97 |
| UNRESOLVED_INHERITANCE | 14 |
| UNSUPPORTED_CONSTRUCT | 440 |

## Semantic delta

The exact parent corpus was SHA-bound to its c4335be commit receipt, then compared
object-by-object, fact-by-fact and finding-by-finding. Removing only the top-level
extractor_version gives complete document equality: zero semantic changes, zero
affected real paths, no new candidate, fact, exit or quarantine. The synthetic
directive cases demonstrate the repair; no real-corpus delta is invented.

## 13 quarantines

All 13 remain identical to the exact parent with facts=[]. Fresh raw-byte checks
verify the eight NUL/replacement-character defects and five syntax defects with
their exact spans; quoted source contexts were separately inspected. P2F25 does not
claim completion of the still-pending systematic quarantine-path Final Audit.

| Source | Positive defect | Byte interval |
| --- | --- | --- |
| `cmds/std/exercise.c` | NUL or replacement character in source | [2033, 2036) |
| `d/choyin/npc/yamen_po.c` | NUL or replacement character in source | [4382, 4385) |
| `d/latemoon/sroad1.c` | unterminated string | [402, 457) |
| `d/latemoon/upstar/upcenter.c` | NUL or replacement character in source | [337, 340) |
| `d/npc/oldman.c` | mismatched delimiter | [4819, 4820) |
| `d/temple/npc/obj/magic_book.c` | NUL or replacement character in source | [863, 866) |
| `d/temple/npc/obj/spells_book.c` | NUL or replacement character in source | [840, 843) |
| `d/temple/obj/magic_book.c` | NUL or replacement character in source | [863, 866) |
| `d/temple/obj/spells_book.c` | NUL or replacement character in source | [840, 843) |
| `d/village/lordhouse3.c` | mismatched delimiter | [1737, 1738) |
| `u/cloud/npc/goddd.c` | unterminated string | [4255, 4280) |
| `u/cloud/obj/npc/flower_girl/guihua.c` | NUL or replacement character in source | [4, 5) |
| `u/cloud/obj/sword_book.c` | mismatched delimiter | [907, 908) |

The syntax sources contain an odd/unclosed quote at sroad1/goddd, an unmatched
closing parenthesis at oldman, an extra brace at lordhouse3, and a missing closing
call before sword_book's brace. They are unchanged by the admission preflight.

## 14 ANSI exclusions

All fourteen exact historical paths are freshly checked against the new corpus;
each remains candidate=false, OUT_OF_SCOPE, facts=[], not QUARANTINED. No ANSI macro
interpretation or widened admission was introduced.

- `d/canyon/canyon4.c`
- `d/choyin/club.c`
- `d/chuenyu/trap_castle.c`
- `d/city/boots.c`
- `d/city/cloth.c`
- `d/green/water.c`
- `d/latemoon/gate.c`
- `d/latemoon/latemoon3.c`
- `d/latemoon/latemoon8.c`
- `d/latemoon/miroom.c`
- `d/latemoon/park/paroad2.c`
- `d/latemoon/room/bathroom.c`
- `d/latemoon/room/bathroom1.c`
- `d/oldpine/keep2.c`

## Provenance / IDs / summaries

Exhaustive corpus walk validated 9587 provenance
records, including normalization inputs, byte slices, raw/raw_hex, UTF-8 source
hashes, line and column. Fact IDs are recomputed from source identity/field/span;
finding IDs and object references are checked in order. No duplicate, ghost or orphan
IDs; summary/finding-code counts match actual records; all review states remain
UNREVIEWED. All 2336 paths are represented once. Unaffected facts and IDs are exactly
parent-equal. Structural refusals allocate no facts or exit IDs.

## ARCHIVE-01 and source immutability

ARCHIVE-01 remains CLOSED. All ten tracked historical audit raw hashes are verified
against working files, index and HEAD. P2F10 remains 24417 bytes / 468 CRLF with SHA
`56e1cd0aa0a573bc4a9505fb5df6bd1cfbd0076849a40f6bd4a4420483cb2213`.
Tracked P2F11 remains
`48f07085604905ef3d603474bae86fb028cff9bbc1088a83769eee16babe9155`;
`.gitattributes` remains
`b33913bb7279e1ab67762574ab277828a9fd114dae23dceace2f24ae842194d6`.
Reference tree: `4106480ab28cce8cd7b55704f8ae9ae062d42d03`.
Raw 2336-file manifest:
`744e33e1740db7909129a3ae5e295158341b5012a411af953b144a5075bb0a80`.
Every tracked file outside the five-path authorization is byte-checked against
the frozen preflight manifest. Generated corpus and audit harnesses stay ignored.

## Sixteen owner-local evidence hashes

All sixteen remain untracked, unstaged and byte-identical. Names below are relative
to docs/migration; they are plain evidence identifiers, not tracked-document links.

| File | Raw SHA-256 |
| --- | --- |
| `MIGRATION_TOOLING_V1_FINAL_RE_AUDIT_AFTER_P2F11_RERUN.md` | `8fc46327ca954ad0089e3ee4fb496bfe8cfe21f497b43ae77432e76ff2bc170b` |
| `MIGRATION_TOOLING_V1_FINAL_RE_AUDIT_AFTER_P2F12.md` | `a0847fdd481867b45e0c1d0b4b4dfdea7e0995a2bb607130fceeff0d8effc04a` |
| `MIGRATION_TOOLING_V1_FINAL_RE_AUDIT_AFTER_P2F13.md` | `adbdaddd424dcebed66ef0e984969fa7d2a949325c184a944d764950ccf9febb` |
| `MIGRATION_TOOLING_V1_FINAL_RE_AUDIT_AFTER_P2F14.md` | `450a982195d670ac7ebc1c38e7afb88cf9a41d52d1bc574d95e605c5ef90a38e` |
| `MIGRATION_TOOLING_V1_FINAL_RE_AUDIT_AFTER_P2F15.md` | `6de33c7bef47e42c4897d6a52858ca6a4e1a97a357e51b1738ac376bd16d3da8` |
| `MIGRATION_TOOLING_V1_FINAL_RE_AUDIT_AFTER_P2F16.md` | `29ac334bfd5e648e92a3845997e50a6c03cc1ab17a99b6b902f15fdb28f899c0` |
| `MIGRATION_TOOLING_V1_FINAL_RE_AUDIT_AFTER_P2F17.md` | `3e4d4a6c8955cb81da7d236360e43f743cd38610d9cdc20e0c3c3f08e9170703` |
| `MIGRATION_TOOLING_V1_FINAL_RE_AUDIT_AFTER_P2F18.md` | `81335715cec2aaf87ecd55f3e62e91f56e4d27ea81b8fa69640e4c6f55ad8396` |
| `MIGRATION_TOOLING_V1_FINAL_RE_AUDIT_AFTER_P2F19.md` | `3a06d404419551833c4afa2b22afee6ecb58b217b279348f69f5906a910d835f` |
| `MIGRATION_TOOLING_V1_FINAL_RE_AUDIT_AFTER_P2F20.md` | `aaba69dcec9047e4f9ac17c83f19c57053a16048276aa28ce5fb5af464393f3d` |
| `MIGRATION_TOOLING_V1_FINAL_RE_AUDIT_AFTER_P2F21.md` | `af57dadfda71f66015f83ef25e80375ee2326922129fc2f8537dbffa7ad6bdf9` |
| `MIGRATION_TOOLING_V1_FINAL_RE_AUDIT_AFTER_P2F21_RERUN.md` | `1db04d337f0b9a0a7268b704630565616492ff5427d2d8a98fc03ec14589f4e6` |
| `MIGRATION_TOOLING_V1_FINAL_RE_AUDIT_AFTER_P2F22.md` | `8f18f5f0afe438c117554fd35b4f2bcb229c13fd3b6a11db47ec3f3a91372bc9` |
| `MIGRATION_TOOLING_V1_FINAL_RE_AUDIT_AFTER_P2F23.md` | `3bea0358bd4a86f8e0bfc7644248491c247d337b03e913ee638ecf572c3fa3f3` |
| `MIGRATION_TOOLING_V1_P2F24_CRITICAL_FUNCTION_STRUCTURE_PREPROCESSING_CONSOLIDATION_ATTEMPT1_BLOCKED.md` | `eaecb3308a3086f01e1fe2232f9105dc8600e168a60658dd89fc9cad4ed93c71` |
| `MIGRATION_TOOLING_V1_FINAL_RE_AUDIT_AFTER_P2F24.md` | `9766f5c7c65b7dafcd9263d3ddcc00b1156ba9331d123be8cbca865cb2048f7d` |

## Residual boundaries

This remains bounded conservative static extraction. Inert directives inside pending
inheritance may be over-refused by design; this is an authorized false negative, not
permission to emit unsafe facts. Macro summaries are not expansion; separate header
units are not an expanded translation unit; matched-group skipping is not LPC grammar.
No declaration, receiver, runtime, inheritance or conditional execution is attempted.
Python 3.12 stdlib remains sufficient. Pure parser changes do not require live Godot
validation, and no live gameplay result is claimed.

P2F25 addresses its authorized blocker family. The Structural-Preprocessing
Consolidation Final Audit is still REQUIRED and the Systematic Quarantine-Path Audit
is still INCOMPLETE. These are material remaining milestone acceptance gates; this
repair report does not promote them to accepted residual risks or claim PR readiness.

## Owner gate

After the exact-commit gates pass, push only this phase commit and verify local/remote
identity, frozen main, clean tracked/index state, no phase PR in any state and all
sixteen local hashes again. The required post-main CI for the previous integrated
milestone remains historical evidence only; no new remote CI is run or claimed here.
No PR, merge, P3 or next Complete Final Re-Audit is authorized in this task.

**READY FOR OWNER REVIEW / FINAL RE-AUDIT AUTHORIZATION — STOP**
