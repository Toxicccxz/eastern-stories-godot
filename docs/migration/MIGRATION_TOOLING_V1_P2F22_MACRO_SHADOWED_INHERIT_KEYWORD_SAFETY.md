# Migration Tooling v1 — P2F22

**P2F22 FIX IMPLEMENTED — AWAIT OWNER REVIEW / FINAL RE-AUDIT NOT YET AUTHORIZED**

## Authorization / frozen identities

Only FR21-01 / blocking MEDIUM / D9 is repaired on `phase/migration-tooling-v1`.
Pre-fix HEAD and fetched origin phase: `1697ab9f511878205300d2f31758356f59efeb95`, subject
`Preserve chained create-tail macro continuations`. Main/merge-base remain
`cd07808cb76147d0b8c0dad9b82d078b49fefe64`. Fresh fetch, all-state PR search (none),
clean tracked worktree/index and archived evidence checks passed before product edits.
The earlier game/project.godot working change was absent; no restoration command was used.

Five authorized files only: room_extractor.py, test_migration_tooling.py, this phase report,
STATUS and ROADMAP. No new branch, PR, merge, remote CI, P3 or next Complete Final Re-Audit.

## P2F21 rerun evidence formalization

Before any product edit, the existing ignored report-draft.md was copied byte-for-byte to
`docs/migration/MIGRATION_TOOLING_V1_FINAL_RE_AUDIT_AFTER_P2F21_RERUN.md`, after checking the destination
did not exist. Its original wording remains frozen, including the historical statement that the
filename clarification was pending when the draft was written. This P2F22 authorization resolves
that clarification; the evidence report itself was not rewritten.

The semantic rerun remains historically BLOCKED on FR21-01. Its 118 CLI executions comprised
72 original FR20 checks, 2 FR21 primary, 2 independent header, 2 handwritten completion controls,
and 40 same-family sibling runs. It reported 36 false-quarantine outcomes overall, including
32 in the 40-run sibling sweep. An additional independent direct extractor reproduced the error.

## P2F21 preflight-report preservation

The earlier `MIGRATION_TOOLING_V1_FINAL_RE_AUDIT_AFTER_P2F21.md` remains unchanged, untracked and
unstaged. Raw SHA-256: `af57dadfda71f66015f83ef25e80375ee2326922129fc2f8537dbffa7ad6bdf9`.
Its dirty runtime-configuration preflight failure was operational, not a numbered semantic blocker.

## P2F21_RERUN hash

Raw SHA-256 frozen before product edits: `1db04d337f0b9a0a7268b704630565616492ff5427d2d8a98fc03ec14589f4e6`.

The copied report remains untracked, unstaged and byte-identical.

## FR21-01 root cause

The exact primary was recreated through the actual CLI before editing, under LF and CRLF:

```c
#define inherit(x)
inherit(unused_identifier)
void create() {}
```

Both returned QUARANTINED / SOURCE_SYNTAX_ERROR / `unterminated inherit` / exit1, facts=[].
After repair both return OUT_OF_SCOPE / exit0 with no inherited facts or category/admission state.
Original authority consulted: [preprocessor manual](../../reference/es2/mudlib/doc/concepts/preprocessor),
[define](../../reference/es2/mudlib/doc/lpc/preprocessor/define) and
[include](../../reference/es2/mudlib/doc/lpc/preprocessor/include). No external port or runtime was used.

## Why authored keyword itself was excluded from pending-inherit uncertainty

The old branch trusted the initial token spelling `inherit`, then searched for a semicolon.
Its uncertainty input began at `ts[i + 1]`, omitting the keyword token itself. Empty/alias macro
uses of that token could therefore be blamed as malformed LPC before actual-use classification.

## Actual macro-use classification

A narrow `inherit_keyword_preprocessing_use(index, matching)` helper consults the existing
root/resolved-header MacroSummary definitions. Object-like definitions require only the authored
identifier. Function-like definitions require the immediately following authored opening parenthesis
to have a matching boundary in the existing root pairing map. No replacement is interpreted.
The check runs before semicolon search, declaration metadata or fact emission.

## Object-like inherit macros

Empty, nonempty, alias, cycle, compound, token-paste and competing object/function definitions
all make the authored token unreliable as an LPC keyword. The object-like possibility alone is
sufficient for conservative refusal; no replacement-derived declaration is recovered.

## Function-like invoked inherit macros

Zero/one/multiple unused parameters, opaque arguments, whitespace/comments/newlines, invalid or
competing definitions, parameter-dependent replacements and returned callable chains are refused
without source quarantine. A trailing authored semicolon does not make a macro invocation into
a trusted inherit declaration. No empty-call argument reuse or continuation expansion is involved.

## Function-like uninvoked controls

A definition such as `#define inherit(x)` does not replace `inherit ROOM;`. Normal supported
inherit parsing and literal facts remain available. Without the semicolon the genuine
`unterminated inherit` error remains. Unused structural replacement contents do not waive or
invalidate that keyword. Handwritten controls check candidate state, values and original diagnostics.

## Header/nested/standard/cross-header definitions

Definitions are collected by existing traversal, never include splicing. The fresh original
FR21 family and expanded cases cover local, nested, standard and cross-header context.
Findings anchor to the authored root keyword, not a replacement token in a header.
Missing-include policy is not redesigned: existing valid-root unresolved-include refusal and
pending-include regressions remain intact; known actual keyword uses are refused even alongside
an unresolved dependency. Historical unrelated-missing-include syntax controls remain unchanged.

## Conservative refusal policy

The gate clears earlier direct-inherit declarations and category candidates, then returns before
candidate admission or facts. Result: candidate=false, OUT_OF_SCOPE, facts=[], direct_inherits=[],
category_candidates=[]. Two truthful findings describe keyword shadowing and driver/preprocessing
uncertainty. Tests spy on fact allocation to ensure no partial inheritance fact subset survives.

## No inheritance recovery

The tool does not guess an inherited file, expanded declaration or post-preprocessing translation
unit. It stops at the observed actual use. Empty replacements do not cause synthetic semicolons.

## No macro expansion

No Token creation, argument substitution, alias execution, general preprocessor, expression
evaluation or include concatenation was added. Existing create-tail, pairing, pending-inherit,
mapping, property-key, receiver, registration and exit-finalizer methods are AST-identical.

## macro_regions interaction

`macro_regions()` is unchanged. The keyword gate exits before downstream admission when the
keyword is an actual macro use. One narrow adjustment in `macro_structure_hazards()` is required
for the opposite case: skip only the leading inherit keyword in an inherit region when all its
definitions are function-like and that authored token has no following call. Otherwise the old
hazard scan would incorrectly reject the explicitly required uninvoked valid-declaration control.
Other declaration tokens and global MacroEffect semantics are unchanged; this is not a region-parser redesign.

## True normal inherit controls

Normal ROOM, additional authored literal inheritance, original literal-only exclusion policy,
and uninvoked same-name function macro controls pass. Safe real-corpus inheritance facts/IDs and
provenance are unchanged. No preprocessing-sensitive source becomes a new supported candidate.

## True unterminated inherit controls

No participating macro, an unrelated unused macro, and an uninvoked same-name function macro
all preserve QUARANTINED / SOURCE_SYNTAX_ERROR / `unterminated inherit` / exit1. The eight original
sibling controls and two independent completion controls retain exact object/finding records.

## Original FR21 and expanded P2F22 evidence

Exact semantic-audit sources were replayed with their original handwritten expectations:
46 CLI = the 40 sibling runs plus primary2, independent header2 and completion2. All 36 former
false quarantines are now conservative refusal/exit0; all 10 controls are unchanged.
The required subset is 32 former false quarantines removed and 8 controls unchanged.

Expanded P2F22: 41 handwritten shapes × LF/CRLF = 82 CLI PASS. They include all macro/header
forms above, valid/missing terminators, additional and earlier/later inherits, typed/untyped
boundaries and missing dependency controls. Separate tests cover root UTF-8 provenance,
fact-allocation refusal and 1,100 alias edges without expansion.

## P2F14/P2F15 regression closure

All historical repair methods passed. The retained 492-CLI header/inherit/pending/tail suite
also freshly covers include terminators and expression fragments, object/function terminators,
aliases/cycles, declaration and TAIL-style function boundaries, normal typed/untyped boundaries
and multiple inherits. Existing expectations are unchanged.

## P2F21 continuation regression

Original FR20: 72 CLI PASS, with all 40 former false quarantines still absent and 32 controls
exact. Expanded P2F21: 84 CLI PASS, including long iterative alias/callable chains. All eight
P2F21 unit methods pass; its enum and both create-tail methods remain unchanged.

## P2F20 key regression

Original FR19 94 CLI, independent key matrix 500 CLI, expanded key family 294 CLI and
40 disabled-early-scanner finalizer probes all pass. Hidden create-expression, nested-exit and
mapping atomicity families also pass. Key/classifier/finalizer/receiver code is unchanged.

## Fresh validation

Focused P2F22: **7 PASS**. P2F1–P2F21 repair methods: **341 PASS**.
Complete migration suite: **413 PASS**. Complete Python suite: **459 PASS**.
Repository/static checks and git diff --check pass.

| Actual CLI matrix | Runs |
| --- | ---: |
| FR21 exact semantic family | 46 |
| P2F22 expanded | 82 |
| FR20 original / P2F21 expanded / primary | 72 / 84 / 4 |
| FR19 / independent key / expanded key / primary | 94 / 500 / 294 / 4 |
| Independent P2F19 create / expanded / FR18 | 270 / 110 / 56 |
| FR17 + P2F18 nested | 148 |
| P2F17 mapping | 156 |
| Historical header/inherit/pending/tail | 492 |
| P2F11 directives / P2F12 delimiters | 204 / 118 |
| Total repair/historical CLI | 2734 |

Separate probes: 40 key-finalizer and 12 hidden-expression finalizer-independence checks.
All 29 pre-commit gate groups passed. These are implementation validation, not a Complete Final Re-Audit.

## Version 1.0.22

EXTRACTOR_VERSION=1.0.22; known versions 1.0.0 through 1.0.22 (23). Schema1 and profile static-room-v1 are unchanged.

## Compatibility

All 23 preserved historical/current canonical versions pass actual CLI replacement.
Unknown/manual/reviewed/future/malformed/empty output is rejected with exit2, no writer call
and unchanged bytes. Historical output inputs remain unchanged.

## Output security

Existing full confinement/protected path/relative escape/tracked checkout/link-junction/atomic
failure/approved output/raw_hex checks pass. All 33 nested dictionary metadata attack positions
are rejected. CLI, writer and lexer files are unchanged; no security delta was observed.

## Corpus A/B

Two fresh independent complete scans both return exit1; A and B bytes are equal.
Scanned 2336; supported 485.
Statuses: `{"EXTRACTED": 0, "PARTIAL": 485, "OUT_OF_SCOPE": 1838, "QUARANTINED": 13}`.
Facts 2736; findings 4296.

Bytes each: 9808627. SHA-256: `b1a8ec2362fb8d0dbfbd67ebb35d5ba99e8f7a47b90db08a44e49840e3959205`.

Finding distribution: `{"CALLBACK_BEHAVIOR": 284, "DRIVER_SEMANTICS_UNKNOWN": 408, "DYNAMIC_EXPRESSION": 10, "ORDER_SENSITIVE_MUTATION": 30, "OUT_OF_SCOPE": 1319, "REQUIRES_SEMANTIC_REVIEW": 1623, "RNG_SEMANTICS": 58, "SOURCE_ENCODING_ISSUE": 8, "SOURCE_SYNTAX_ERROR": 5, "UNRESOLVED_INCLUDE": 97, "UNRESOLVED_INHERITANCE": 14, "UNSUPPORTED_CONSTRUCT": 440}`.

## Semantic delta

Measured full-document comparison against P2F21 output bound to exact parent
`1697ab9f511878205300d2f31758356f59efeb95`: **zero semantic delta except extractor_version**.
Object/candidate/status/inherits/facts/IDs/findings/manifest data are identical. No real source
required reclassification; no changed quarantine or exit was accepted without explanation.

## 13 real quarantines

Fresh exact set remains 8 encoding and 5 syntax. Actual raw bytes, original error spans/reasons
and facts=[] were checked. No quarantine changed. This bounded regression review does not claim
completion of the mandatory next systematic all-path quarantine audit.

## 14 ANSI exclusions

All fourteen remain candidate=false / OUT_OF_SCOPE / facts=[] / not QUARANTINED. No ANSI expression evaluation was added.

## Provenance / ID integrity

Fresh corpus checks validate source SHA, byte ranges, raw/raw_hex, line/column, normalization
inputs, fact-ID formula/uniqueness, finding references, ordering, exact summary and UNREVIEWED.
Coverage: `{"provenance_records": 9587, "direct_inherit_provenance": 1799, "unreviewed_records": 7032, "fact_provenance": 2736, "unicode_span_records": 1239, "normalization_input_provenance": 756, "crlf_source_records": 3, "finding_provenance": 4296}`.
Keyword-shadow findings use only the root authored inherit token. Earlier unreliable inherits
are cleared before any fact allocation. No synthetic replacement span, ghost or orphan ID is emitted.

## ARCHIVE-01

CLOSED. Ten tracked historical raw hashes match HEAD/index/worktree. P2F10 remains
24,417 bytes / 468 CRLF / `56e1cd0aa0a573bc4a9505fb5df6bd1cfbd0076849a40f6bd4a4420483cb2213`.
Tracked P2F11: `48f07085604905ef3d603474bae86fb028cff9bbc1088a83769eee16babe9155`.
.gitattributes: `b33913bb7279e1ab67762574ab277828a9fd114dae23dceace2f24ae842194d6`.
No historical archive normalization or modification.

## Twelve owner-local report preservation

All twelve reports from P2F11_RERUN through P2F21 and P2F21_RERUN remain untracked, unstaged
and byte-identical to their frozen hashes. No owner-local report enters the five-file commit.
Reference Git tree remains `4106480ab28cce8cd7b55704f8ae9ae062d42d03`; raw 2,336-file manifest
remains `744e33e1740db7909129a3ae5e295158341b5012a411af953b144a5075bb0a80`.
No reference/game/runtime/schema/.github/DECISIONS change.

## Exact-commit verification

This report records pre-commit evidence. The one authorized commit is
`Guard macro-shadowed inherit keywords`, with parent 1697ab9. All 29 required gate groups
must run afresh on that immutable commit before push, including the full suites, matrices,
security/23-version compatibility, corpus A/B, semantics, provenance and preservation.
Post-* receipts bind those results to the final SHA; this report is not amended to embed its own hash.

## Residual boundaries

The bounded macro summary still unions possible definitions without conditional evaluation,
execution or include splicing. The new gate only refuses an observed actual macro use; it is
not an LPC validity proof. General missing-include policy and unrelated quarantine paths remain
outside this repair. No contract defect is accepted as residual risk.

Distinct AST self-audit confirms only extract_structure among existing methods changed; one
keyword-use helper was added. The only module-function change is the narrowly required leading
uninvoked-keyword filter in macro_structure_hazards. macro_regions, MacroEffect, CreateTailEffect,
P2F21 continuation and P2F17–P2F20 exit safety remain unchanged. No imports or dependencies added.
Pure parser/tooling repair: live Godot gameplay validation is not required or claimed.

## Owner gate

P2F21 is CLOSED. Its initial operational preflight report and FR21-01 semantic rerun remain
historical blocked evidence. P2F22 is implemented and awaits owner review.
The systematic quarantine-path audit remains **INCOMPLETE** and mandatory in the next separately
authorized Complete Final Re-Audit. No milestone Final Re-Audit PASS is claimed here.

No PR, merge, remote CI or P3. Phase branch retained; main remains frozen and Migration Tooling v1
is not integrated on main. Stop after the authorized verified implementation commit/push.
