# Migration Tooling v1 - P2F21

**P2F21 FIX IMPLEMENTED — AWAIT OWNER REVIEW / FINAL RE-AUDIT NOT YET AUTHORIZED**

## Authorization / frozen identities

Only FR20-01 / blocking MEDIUM / D9 is repaired on phase/migration-tooling-v1.
Pre-fix HEAD/origin phase: `129150d8c51043202ae864dce6f3fa5d144d79e2`, subject
`Harden create exit mutation key classification`. Main/merge-base remain
`cd07808cb76147d0b8c0dad9b82d078b49fefe64`. Fresh fetch, 26-commit linear chain,
all-state PR search (none), tracked/index cleanliness, ten blocked-report hashes,
ten tracked archive hashes and source manifest were checked before product edits.

Exactly five files: room_extractor.py, test_migration_tooling.py, this report,
STATUS and ROADMAP. No CLI/lexer/game/reference/.github/DECISIONS/attributes or older
report changes. No new milestone or branch.

## FR20-01 root cause

Fresh primary A()() and independent NEXT(7)(unused_identifier) with resolved finish.h
were recreated before editing in LF/CRLF: four exit1/QUARANTINED/facts=[] results,
SOURCE_SYNTAX_ERROR / unterminated create statement. Receipts are in
`build/migration-tooling-v1/p2f21/before-primary.json`.

After repair, all four are PARTIAL/exit0 and retain only authored inherit facts;
earlier create-derived facts are suppressed. The cause was lost identity of a
returned function macro that could consume a separate following argument list.
Original authority: [preprocessor manual](../../reference/es2/mudlib/doc/concepts/preprocessor)
and [define reference](../../reference/es2/mudlib/doc/lpc/preprocessor/define).
No external port or runtime implementation was used.

## Why clearing old invocation state is correct

A function-like macro consumes its own authored matched argument list. Its replacement
must not receive that same list again. The existing invoked-state clearing remains.
A() returning function macro B with no second list still leaves residual B and quarantines.

## Why continuation state was missing

Previously the summary could return only an effect and consumes-call flag. After
clearing the first invocation it classified the returned uninvoked function name
as final residue, losing the possibility of a new immediately following authored call.

## Callable continuation summary

CreateTailEffect adds CALLABLE_CONTINUATION. The narrow create_tail_effect result is
(effect, consumes_current_authored_call, continuation_macro_name_or_None).
The name is metadata, not a Token. Only a consumed function invocation followed
through safe single-identifier object aliases to an uninvoked function macro produces
this state. Unknown/complex/invalid/ambiguous summaries remain UNCERTAIN.
Global MacroEffect and all its methods retain their original semantics.

## Separate authored-call consumption

The tail scanner carries a pending name only while the next runtime token is an
opening parenthesis with an existing matching boundary. Each iteration consumes that
new list and advances the authored cursor. Whitespace/comments disappear lexically;
an unrelated runtime token breaks continuation. No later unrelated call is captured.

## Object-alias behavior

Object aliases before the first function retain its immediately available invocation:
A -> B, B() empty means authored A() can disappear. After a consumed function,
object aliases may resolve toward a returned callable, but cannot borrow old arguments.
A() -> LINK -> B, followed by a new (), is recognized without replacement tokens.

## Function-returned-function behavior

For A() -> B and B() -> empty, A()() becomes conservatively removable. A() alone
leaves the uninvoked B residual. The continuation step is anchored to the original A.

## Multiple-call chains

Three/four-call chains, multiple object aliases between stages, two independent
removable chains, and empty object/function prefix/suffix cases pass. The scanner
finishes one chain and resumes on original authored tokens. Complete statement
boundaries retain the existing dispatcher behavior.

## Parameter-independent cases

NEXT(value) -> ERASE and ERASE(value) -> empty consume their separate matched lists.
Unused argument contents are not substituted or evaluated; nested argument expressions
remain opaque. Local/nested/standard/cross-header definitions use existing context lookup.

## Parameter-dependent uncertainty

A(x) -> x or A(x) -> B(x) is not resolved by argument substitution. Parameter-dependent,
complex and structural replacements retain conservative uncertainty/global refusal.
No facts are derived from uncertain replacement contents.

## True residual controls

Uninvoked result, bare function, runtime prefix/suffix, unused macro definitions,
neutral actual use, unfinished call and unfinished setter remain quarantined.
A() identifier () cannot use the later list as the returned macro's invocation.
No blanket macro-tail waiver was added.

## Extra-parentheses controls

A() -> empty leaves the second list in A()() as genuine residue. Likewise A() -> B
with object-like empty B cannot own an extra list. An extra list after an otherwise
completed removable chain also remains residual. Original invocation arguments are
never reused by a returned macro.

## Neutral-result controls

A() -> B and B() -> number/string/character leave a nonempty runtime atom even with
both calls supplied; these tails retain SOURCE_SYNTAX_ERROR. Unknown returned names
also remain nonempty unless an existing uncertainty rule applies.

## Cycle / invalid / competing definitions

The tail-specific summary checks conflicting definitions and invalid signatures before
selecting a callable continuation. Object-alias visited states and repeated continuation
names bound traversal; cycles produce uncertainty. Object/function ambiguity, invalid
macros, token paste and compound replacements remain refused without execution.

## Iterative depth safety

Fresh LF/CRLF tests and real CLI runs include 1,100 object-alias edges after a function
stage and 1,101 separate authored calls across a function chain. No recursion or generated
stream is used. Each continuation advances the authored cursor; identity sets bound cycles.

## No macro expansion

No replacement token stream, include splicing, stringification, token-paste execution,
CPP/LPC engine or source rewriting was introduced. Macro replacement inspection stays
within the existing definitions store and atomic/alias summary policy.

## No argument substitution

Arguments supply only authored matched-list boundaries. Parameter dependence becomes
UNCERTAIN; values and expressions are never substituted or executed.

## No synthetic provenance

Continuation names receive no source coordinates. Findings retain the original authored
root use A/START/NEXT and original source SHA/byte span/line/column. A header-returned B
never appears as a synthetic root token. Focused tests inspect token lists and provenance.

## Original FR20 72 CLI matrix

Fresh exact blocked-audit source bytes and handwritten oracles were rerun: 36 shapes /
72 LF/CRLF CLI executions PASS. All 40 previous false quarantines are now non-quarantined;
all 32 controls preserve their complete object and finding records. Twelve genuine
residual shapes (24 runs) stay quarantined; four valid controls (8 runs) remain non-quarantined.
No expectations were changed after execution.

## Expanded P2F21 continuation matrix

Fresh 42 shapes / 84 CLI executions PASS, covering legal continuations,
residuals, callable versus empty results, neutral atoms, argument-independent/dependent
macros, alias/function cycles, ambiguity/invalid definitions, depth stress and a completed
statement boundary. Input cases and expectations were handwritten before running.

## P2F16 / FR15 regressions

All five P2F16 regression methods passed, including the original empty-tail family and
directive controls. The full retained historical CLI suite includes the FR15/P2F16 tail
matrix, preserving define/undef/pragma/echo/include/unknown-directive behavior.
No create_body directive segmentation or SourceError rule was edited.

## P2F20 property-key regressions

Fresh original FR19 94 CLI PASS, independent additional key matrix 500 CLI PASS,
40 disabled-early-scanner/fact-spy traces PASS, and retained P2F20 expanded 294 CLI PASS.
The property-key, call/receiver classification, exact setter registration and finalizer
methods are AST-identical to the parent. No suppressed exit receives a fact ID.

## P2F1-P2F20 regressions

Fresh focused P2F21 methods: 8 PASS. Historical P2F1-P2F20 methods:
333 PASS. Full migration suite: 406 PASS. Full Python suite: 452 PASS.
Repository/static and whitespace checks pass.

| CLI gate | Fresh pre-commit executions |
| --- | ---: |
| FR20 | 72 |
| Expanded P2F21 | 84 |
| New primary/header replay | 4 |
| FR19 original | 94 |
| Independent P2F20 key audit | 500 |
| Retained P2F20 expanded | 294 |
| P2F19 independent create-call matrix | 270 |
| P2F19 expanded | 110 |
| Original FR18 | 56 |
| Original FR17 + P2F18 expanded | 48 + 100 |
| P2F17 mapping | 156 |
| Header/inherit/pending/tail families | 492 |
| P2F11 directives | 204 |
| P2F12 delimiters | 118 |
| Retained P2F20 primary replay | 4 |
| Total repair/historical CLI per gate run | 2606 |

Separately retained: 40 P2F20 finalizer traces and 12 P2F19 finalizer-independence probes.
The 27 pre-commit gate groups all passed. These are implementation gates, not the next
Complete Final Re-Audit.

## Version 1.0.21

EXTRACTOR_VERSION=1.0.21; KNOWN=1.0.0 through 1.0.21 (22). Schema1 and static-room-v1 unchanged.

## Compatibility

Fresh real CLI canonical replacement accepts all 22 preserved historical/current versions.
Unknown/future/manual/reviewed/malformed/empty outputs are refused with exit2, no writer call
and unchanged bytes. Historical receipts are read as inputs, never modified.

## Output security

Full existing confinement/relative escape/protected target/external tracked checkout/
link-junction/atomic failure/approved output/raw_hex suite passed. All 33
nested metadata attack positions remain refused. No CLI/writer implementation or security
behavior changed.

## Corpus A/B

Two fresh complete CLI scans return exit1 for the retained actual corrupt sources and are
byte-identical. Scanned 2336; supported 485;
statuses {'EXTRACTED': 0, 'PARTIAL': 485, 'OUT_OF_SCOPE': 1838, 'QUARANTINED': 13}; facts 2736; findings 4296.
Bytes: 9808627. SHA-256:
`b11bc3c84bee3e82a8efd04fa44917a210fb2cf5282d9d8f2288764a5242362c`.

Fresh finding-code distribution: {"CALLBACK_BEHAVIOR": 284, "DRIVER_SEMANTICS_UNKNOWN": 408, "DYNAMIC_EXPRESSION": 10, "ORDER_SENSITIVE_MUTATION": 30, "OUT_OF_SCOPE": 1319, "REQUIRES_SEMANTIC_REVIEW": 1623, "RNG_SEMANTICS": 58, "SOURCE_ENCODING_ISSUE": 8, "SOURCE_SYNTAX_ERROR": 5, "UNRESOLVED_INCLUDE": 97, "UNRESOLVED_INHERITANCE": 14, "UNSUPPORTED_CONSTRUCT": 440}.

## Semantic delta

Independent projection against exact P2F20 parent
`129150d8c51043202ae864dce6f3fa5d144d79e2` found zero object/fact/finding/status/admission
changes; only extractor_version differs. No real corpus path needed reclassification.
This was measured, not assumed. Any nonzero change would have required path-by-path inspection.

## 13 quarantines

Fresh exact set: 8 encoding + 5 syntax. Actual source bytes, original reasons/spans and
facts=[] checked. No historical quarantine changed under P2F21. These checks do not replace
the next systematic all-path quarantine audit.

## 14 ANSI exclusions

All fourteen remain candidate=false / OUT_OF_SCOPE / facts=[] / not QUARANTINED. No ANSI evaluation.

## Provenance / ID integrity

Fresh corpus validation covers source SHA/raw/raw_hex/byte range/line/column, normalization
inputs, fact-ID formula/uniqueness, finding references, exact summary counts and UNREVIEWED
states. All safe corpus facts/IDs remain identical to the parent. New chain findings use
root authored anchors, never replacement-derived spans.

## ARCHIVE-01

CLOSED. All ten tracked historical audit raw hashes match HEAD/index/worktree. P2F10:
24,417 bytes / 468 CRLF /
`56e1cd0aa0a573bc4a9505fb5df6bd1cfbd0076849a40f6bd4a4420483cb2213`.
Tracked P2F11: `48f07085604905ef3d603474bae86fb028cff9bbc1088a83769eee16babe9155`.
.gitattributes: `b33913bb7279e1ab67762574ab277828a9fd114dae23dceace2f24ae842194d6`.
No archival edit or normalization.

## Ten blocked-report preservation

P2F11_RERUN and P2F12-P2F20 remain untracked, unstaged and byte-identical.
P2F20 raw SHA: `aaba69dcec9047e4f9ac17c83f19c57053a16048276aa28ce5fb5af464393f3d`.
Reference tree: `4106480ab28cce8cd7b55704f8ae9ae062d42d03`.
2,336-file source manifest:
`744e33e1740db7909129a3ae5e295158341b5012a411af953b144a5075bb0a80`.
Complete preservation receipts are retained with the implementation gate evidence.

## Exact-commit gate

This report records pre-commit results. The single authorized commit is
`Preserve chained create-tail macro continuations`, parent 129150d. All 27 gate groups must
run afresh on its immutable SHA before normal phase-branch push. Post-* evidence and the
final task receipt identify that SHA without amending this report to insert its own hash.
No pre-commit result substitutes for exact-commit verification.

## Residual boundaries

This remains a bounded tail-specific summary, not a preprocessor. Complex/parameter-dependent
or ambiguous replacements are conservatively refused. Global macro policy is unchanged.
AST self-audit confirms only create_tail_effect and create_tail_uncertain_use existing
methods changed; no added executable method/import. CreateTailEffect alone adds a state.
Pairing/include/inherit/mapping/key/finalizer/receiver/registration logic is untouched.
Pure parser repair: no Godot live session required or launched. No gameplay/schema change.

## Owner gate

P2F20 is CLOSED. Its historical Final Re-Audit remains BLOCKED on FR20-01 / blocking MEDIUM /
D9. P2F21 is implemented and awaits owner review. Systematic quarantine-path audit remains
INCOMPLETE and mandatory, including mapping category-C coverage, in the next separately
authorized Complete Final Re-Audit. No Final Re-Audit PASS is claimed.

No phase PR, merge, remote CI or P3 initiated. Frozen main unchanged; Migration Tooling v1
is not integrated on main. Retain phase branch and all ten owner-local reports. Stop after
authorized implementation commit verification/push for owner review.
