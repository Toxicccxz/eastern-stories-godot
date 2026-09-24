# Migration Tooling v1 — P2F16

**P2F16 FIX IMPLEMENTED — AWAIT OWNER REVIEW / FINAL RE-AUDIT NOT YET AUTHORIZED**

## Authorization / frozen identities

Only FR15-01 / blocking MEDIUM / D9 is addressed, on `phase/migration-tooling-v1`.
Frozen pre-fix executable and required commit parent:
`65416c1b9c02e8dc9796c7eae252ceec951ffa51` (`Preserve preprocessing-sensitive inherit boundaries`).
Main, origin/main and merge base remain `cd07808cb76147d0b8c0dad9b82d078b49fefe64`.
Fresh fetch, branch/ref/merge-base/status/history checks passed; all-state phase PR search was empty.
Tracked tree and index were clean, with exactly five expected owner-local blocked reports.

Authorized files: `tools/migration/room_extractor.py`, `tools/tests/test_migration_tooling.py`,
this phase-scoped report under `docs/migration/`, and production STATUS/ROADMAP. No other tracked
file is changed. This is implementation verification, not the next complete Final Re-Audit.

## FR15-01 root cause

Before editing, fresh actual CLI executions with independently written LF and CRLF sources confirmed:

```c
#define NOTHING
inherit ROOM;
void create(){ NOTHING }
```

Both returned QUARANTINED / SOURCE_SYNTAX_ERROR / `unterminated create statement` / facts=[] / exit1.
Independent literal empty-body controls returned EXTRACTED / exit0. The error was caused by treating
nonempty authored macro text as positive evidence of an unfinished runtime statement.
After the repair both macro forms return PARTIAL / exit0 without SOURCE_SYNTAX_ERROR, retaining
only the authored inherit fact and suppressing create-derived facts.

Local authority consulted: [preprocessor concepts](../../reference/es2/mudlib/doc/concepts/preprocessor),
[define semantics](../../reference/es2/mudlib/doc/lpc/preprocessor/define), and the previously
confirmed local empty-definition examples. The ES2 corpus remains read-only; no LPC runtime or
external port was used. No gameplay mechanic was migrated.

## Why INERT macro classification was insufficient

INERT is a shared effect classification, not proof that authored text survives preprocessing.
Both an empty replacement and a neutral atom can be INERT, but only the atom leaves an unfinished
runtime expression. Global `MacroSummary.effect()` and the MacroEffect enum retain their semantics.
The repair adds a separate tail-specific summary using the existing definition store.

## Create-tail decision order

Existing directive handling and create segmentation run first. Only the existing would-be
`unterminated create statement` branch invokes the new helper. Already complete bodies remain lazy;
mock-based tests prove that the helper is not called for empty bodies or completed setters.

The helper examines actual identifiers in that unfinished tail. Proven-empty uses are accounted for
individually. If any genuine residual runtime token remains and no uncertain actual use can change
the boundary, the existing SourceError is preserved. Otherwise a finding at the authored macro use
refuses create extraction before any planned create segment emits facts.

## Tail-specific preprocessing summary

`MacroSummary.create_tail_effect` returns EMPTY, NONEMPTY_NEUTRAL or UNCERTAIN, together with whether
the actual use consumes its following authored invocation. A non-macro or uninvoked function macro
remains nonempty. Only empty or single-atom replacements and single-identifier aliases are classified
as proven; competing definitions, invalid shapes, cycles or complex/parameter-dependent replacement
remain uncertain. Traversal is iterative and visited-state bounded.

`RoomExtractor.create_tail_uncertain_use` reuses `macro_context()`, the existing lexer tokens and
matched parentheses. It does not create a second macro collector or replace source text.

## Proven-empty actual uses

Empty object uses and multiple consecutive empty uses no longer falsely quarantine. Each use is
accounted for separately; simply defining an empty macro elsewhere never waives an error. Empty
object macros followed by parentheses leave those parentheses as residual authored text, so `E()`
with object-like empty `E` still quarantines. This guards against erasing more than the actual use.

## Empty aliases

Single-identifier aliases to empty definitions follow the same rule. A 1,100-link object alias chain
and an object-alias chain ending in a parameterized empty function macro pass in both newline forms.
No recursion-depth dependency or expanded token stream is introduced.

## Function-like empty uses

An invoked empty function macro accounts for its identifier and complete matched argument range.
Parameterized empty replacements may discard their authored argument range without evaluating or
substituting it. Whitespace and multiline invocation forms use existing tokenization.
Uninvoked empty function macros remain genuine residual identifiers.

Invocation ownership is explicit: object-to-function aliases keep the following call; once a
function invocation is consumed, its replacement identifier does not inherit that same invocation.
Function-to-object-empty works, while function-to-uninvoked-function and extra authored `()` controls
retain quarantine. Function arguments and signatures in the stress controls are handwritten.

## Header / nested / standard definitions

Empty definitions in local, nested and standard headers are reached through existing compilation
context traversal. The actual root use is recognized; headers remain OUT_OF_SCOPE / fact-free.
Nested-header provenance tests require the root identifier, never the header replacement bytes.

## Cross-header aliases

An alias in one resolved header reaching an empty definition in another passes with conservative
PARTIAL status. Include sources remain separate; no splicing or generated translation unit occurs.

## Residual runtime-token negatives

`EMPTY ordinary_identifier`, the reversed order and `A ordinary_identifier B` still quarantine.
So do an empty function invocation next to a genuine identifier, ordinary unfinished identifiers,
balanced calls/setters without semicolons, literals, and empty macros used only earlier in the body.
The helper does not apply a file-wide or any-empty-use waiver.

## Neutral nonempty macro negatives

Numbers, strings, characters, aliases to neutral atoms and neutral function-like macro replacements
still leave positive unfinished-tail evidence. Their controls retain SOURCE_SYNTAX_ERROR / exit1.
Macro spellings in comments, strings, characters, quoted symbols, heredocs and raw echo payloads
are not actual uses. Original unfinished-runtime-plus-pragma/undef/define controls retain quarantine.

## Unknown / structural macro handling

Existing global structural refusal still handles semicolon macros, complete return/setter macros,
cycles, competing definitions, token paste, invalid signatures, parameter-dependent and unknown
complex replacements: OUT_OF_SCOPE / facts=[] / exit0. The tail helper also treats an uncertain
actual use as insufficient corruption evidence, even beside a residual identifier, because that
use may supply a terminator. No macro-derived facts are recovered.

## Directive policy preservation

P2F11's segmentation, directive issue collection and include/unknown-tail policy are unchanged.
Fresh raw-include-semicolon, safe include, missing include, unknown directive, pragma, undef and
define-only controls preserve their results. The new helper is confined to the existing runtime-tail
error branch. All prior directive regression methods pass.

## No macro expansion

No replacement substitution, argument evaluation/substitution, synthetic Token, invented semicolon,
source rewriting, include splicing, #if evaluation or runtime execution is introduced. Accounting
for an authored invocation range affects only whether corruption is provable; it does not produce
an expanded body or extracted macro content.

## Inherit-family preservation

Distinct AST/diff review confirms that only `RoomExtractor.create_body` changed among existing
methods. Added methods are `MacroSummary.create_tail_effect` and
`RoomExtractor.create_tail_uncertain_use`. Imports are unchanged. `extract_structure`, pending-inherit
slicing, the inherit uncertainty helper, declaration/function boundary handling, pairing helpers,
global macro effect and statement/mapping methods are unchanged. P2F12–P2F15 families were freshly
rerun through historical methods and the retained real CLI matrix.

## Mapping category-C explicitly NOT fixed

Mapping parsing was not changed or newly declared complete. The systematic quarantine-path audit
and mapping category-C challenges remain for the next owner-authorized complete Final Re-Audit.
This repair does not silently close those pending audit obligations.

## P2F1–P2F15 regressions

Fresh pre-commit verification: focused P2F16 5/5, all prior repair methods 300/300,
complete migration suite 370/370, complete Python suite 416/416, repository checks and diff check PASS.
The focused matrix contains 75 handwritten cases under LF/CRLF, with additional long-alias,
root-provenance, prior-fact suppression and lazy-path assertions. A stress fixture was refined to
match its explicit one-argument function-macro signature, then focused tests and the actual CLI
matrix were rerun. Product behavior did not change in that refinement. Complete exact-commit suites
are required again after commit, independently of these pre-commit results.

Old product-test edits are limited to current-version expectations and extending known-version
coverage. No historical semantic expectation was relaxed. No cosmetic test-count target was used.

## Original 62-case matrix

The original 31 handwritten input pairs were recreated and executed through actual CLI processes.
All 12 former FR15 false quarantines now return PARTIAL / exit0 without a syntax-error finding.
All 18 genuine unfinished controls still quarantine / exit1. The remaining 32 prior exit0 controls
retain their results. New totals: PARTIAL30 / EXTRACTED6 / OUT_OF_SCOPE8 / QUARANTINED18;
exit0=44, exit1=18. Expected results were fixed before execution, not autoaccepted from product output.

## Expanded real CLI matrix

492 actual CLI executions pass: retained P2F12–P2F15/control matrix338, original FR15 matrix62,
and new P2F16 causal-tail matrix92 (44 additional handwritten pairs plus two long-alias pairs).
Overall exit0=306, expected exit1=186, no false root/header quarantine or unsafe facts in the checks.
Per-case evidence retains exits, status, candidate, facts, direct inheritance, categories, full
findings/provenance, input byte hashes and header statuses. `set`-before-empty and empty-before-`set`
controls explicitly retain only the authored inherit fact, not an invented or unsafe setter fact.

## Version 1.0.16

EXTRACTOR_VERSION is 1.0.16; KNOWN_EXTRACTOR_VERSIONS includes 1.0.0 through 1.0.16.
Schema version remains 1 and profile remains `static-room-v1`. No IR/runtime schema change.

## Output compatibility

Seventeen genuine canonical historical/current outputs passed real CLI replacement to 1.0.16.
Unknown, manual, reviewed, future-version, malformed and empty targets remain exit2 with writer not
called and original bytes preserved. Closed-schema validation was not relaxed.

## Output security

Complete existing output-security tests and independent probes pass. Probes cover eight protected
path forms, 33 nested metadata dictionary layers, six unsafe-output variants, tracked targets in
another checkout, approved external/build output and invalid-UTF8 raw_hex provenance.
`cli.py` and writer code are unchanged; no writer behavior delta was found.

## Corpus A/B

Two independent complete scans returned expected exit1 from the existing thirteen corrupt sources.

| Measurement | Both runs |
| --- | ---: |
| Scanned | 2,336 |
| Supported | 485 |
| EXTRACTED | 0 |
| PARTIAL | 485 |
| OUT_OF_SCOPE | 1,838 |
| QUARANTINED | 13 |
| Facts | 2,736 |
| Findings | 4,296 |
| Bytes | 9,808,627 |

Both SHA-256 values are `2b023761a00eadc1920fc9b828c566c73014794e2f1699d7ce2fbe40598e17fe`.
Bytes are identical. Full-document comparison against exact P2F15 evidence at frozen
`65416c1b9c02e8dc9796c7eae252ceec951ffa51`, excluding only extractor_version, yields zero differences.

Finding distribution: CALLBACK_BEHAVIOR284, DRIVER_SEMANTICS_UNKNOWN408, DYNAMIC_EXPRESSION10,
ORDER_SENSITIVE_MUTATION30, OUT_OF_SCOPE1319, REQUIRES_SEMANTIC_REVIEW1623, RNG_SEMANTICS58,
SOURCE_ENCODING_ISSUE8, SOURCE_SYNTAX_ERROR5, UNRESOLVED_INCLUDE97,
UNRESOLVED_INHERITANCE14, UNSUPPORTED_CONSTRUCT440.

## 13 quarantines

Exact set unchanged: eight encoding and five syntax errors. Fresh actual-byte checks verify
NUL/replacement bytes, malformed quote lines or unmatched closures at recorded error spans;
facts=[] throughout. No source was downgraded because an unused empty macro happened to exist.
Per-source bytes, hashes, reasons and contexts are retained in the ignored self-audit/corpus receipts.

## 14 ANSI exclusions

The exact existing fourteen remain candidate=false / OUT_OF_SCOPE / facts=[] / not QUARANTINED.
No ANSI expression evaluation or admission change was made.

## Provenance

New uncertainty findings point to the actual authored root macro identifier with create scope.
Tests explicitly cover nested headers, LF/CRLF and suppression of earlier create facts.
Whole-corpus checks validate 9,587 provenance records: 1,799 inherit, 2,736 fact, 4,296 finding and
756 normalization-input records, including 1,239 Unicode spans and three CRLF source records.
All 7,032 facts/findings remain UNREVIEWED. No expanded/synthetic provenance is emitted.

## Archive preservation

ARCHIVE-01 remains CLOSED. All ten tracked historical audit hashes match frozen values.
P2F10 remains 24,417 bytes / 468 CRLF, SHA-256
`56e1cd0aa0a573bc4a9505fb5df6bd1cfbd0076849a40f6bd4a4420483cb2213`.
Tracked P2F11 remains `48f07085604905ef3d603474bae86fb028cff9bbc1088a83769eee16babe9155`.
`.gitattributes` and its P2F10 exception are unchanged. No archival work was performed.
Reference tree remains `4106480ab28cce8cd7b55704f8ae9ae062d42d03`; the 2,336-file raw-byte manifest
remains `744e33e1740db7909129a3ae5e295158341b5012a411af953b144a5075bb0a80`.

## Five blocked-report preservation

All five owner-local reports remain untracked, unstaged and byte-identical:

| Report suffix | SHA-256 |
| --- | --- |
| P2F11_RERUN | `8fc46327ca954ad0089e3ee4fb496bfe8cfe21f497b43ae77432e76ff2bc170b` |
| P2F12 | `a0847fdd481867b45e0c1d0b4b4dfdea7e0995a2bb607130fceeff0d8effc04a` |
| P2F13 | `adbdaddd424dcebed66ef0e984969fa7d2a949325c184a944d764950ccf9febb` |
| P2F14 | `450a982195d670ac7ebc1c38e7afb88cf9a41d52d1bc574d95e605c5ef90a38e` |
| P2F15 | `6de33c7bef47e42c4897d6a52858ca6a4e1a97a357e51b1738ac376bd16d3da8` |

## Residual boundaries

Tail summaries remain bounded, not an LPC grammar, full preprocessor or macro expansion engine.
Unknown replacement structures conservatively refuse extraction. No Native consumer, NPC/item
extraction, gameplay or Save behavior is added. Pure parser work requires no live Godot gameplay
validation; none is claimed. Independent complete Final Re-Audit remains required and not yet
authorized, especially the previously stopped quarantine-path and mapping challenges.

## Owner gate

This report records pre-commit verification. The sole authorized commit must have frozen parent
`65416c1b9c02e8dc9796c7eae252ceec951ffa51` and subject
`Fix preprocessing-sensitive create tail completion`. After commit, every required focused,
historical/full-suite, CLI, security, compatibility, corpus/provenance and integrity gate must run
again on that exact SHA before pushing. Ignored `post-*` receipts bind those results to the commit;
the completion response identifies the verified/pushed SHA without embedding a self-referential hash.

Evidence is under ignored `build/migration-tooling-v1/p2f16/`; no generated whole-corpus output is
tracked. P2F15 is CLOSED; P2F16 awaits owner review. No PR, merge, new remote CI or post-merge CI
claim is made. Main remains frozen. Do not run the next complete Final Re-Audit, repair mapping
category-C paths, or start P3 without new owner authorization.
