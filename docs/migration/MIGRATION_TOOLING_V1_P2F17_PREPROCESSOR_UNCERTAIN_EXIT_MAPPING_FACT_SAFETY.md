# Migration Tooling v1 — P2F17 preprocessing-uncertain exit mapping fact safety

**P2F17 FIX IMPLEMENTED — AWAIT OWNER REVIEW / FINAL RE-AUDIT NOT YET AUTHORIZED**

## Authorization / frozen identities

Only FR16-01 / HIGH / D3-D6 fact safety is repaired on `phase/migration-tooling-v1`.
Parent/executable baseline: `4f4c5b4e691741932fd514e5979587714e4830b6`.
Main: `cd07808cb76147d0b8c0dad9b82d078b49fefe64`.
Fresh fetch/ref checks matched; all-state phase PR search returned no results.
The [locked contract](DECISIONS.md#migration-tooling-v1-p2--owner-locked-extraction-boundary)
is unchanged. No PR, merge, remote CI, P3 or next Final Re-Audit is authorized by this slice.

## FR16-01 root cause

Previously `exits()` emitted an approved literal entry immediately. A later macro-dependent
entry produced a dynamic finding and continued, leaving a literal subset of the same mapping.
The supplied multiline KEY reproducer was freshly confirmed under LF/CRLF before editing:
PARTIAL, candidate=true, exit0, one exit fact plus inherit. The one-line original audit case and
all original sibling sources were also rerun on the frozen baseline.

## Why PARTIAL / UNREVIEWED was insufficient for this gate

The old literal record accurately quoted authored bytes and remained UNREVIEWED, with blocking
findings. It was not fabricated or approved. The owner's FR16 rule specifically requires zero
exit records from a preprocessing-uncertain mapping, so those existing flags were insufficient.

## Mapping-level atomic fact contract

An actual preprocessing use anywhere in an exits mapping prevents all exit facts from that
mapping, independent of entry order. Independent inherit, short and other reliable non-exit
facts remain governed by the existing contract. Multiple exits declarations additionally follow
the conservative sequence policy below; no final mapping or runtime graph is inferred.

## Two-phase/staged extraction design

[room_extractor.py](../../tools/migration/room_extractor.py) stages `(value, authored tokens,
normalization)` candidates without creating fact IDs. Mapping parsing and all positive syntax
checks still run. After create analysis, `commit_exit_facts()` checks sequence reliability and
calls the existing fact builder only when safe. It then clears the staging buffer. No emitted
fact is deleted or rewritten. SourceError still clears authoritative facts before quarantine.

The only changed existing methods are construction, the extraction coordinator's one finalization
call, and exits parsing. Two narrow mapping/exit helpers are added. Shared macro effects, pairing,
header classification, inherit, create segmentation/tail and statement parsing remain unchanged.

## Actual preprocessing-use classification

`mapping_preprocessing_use()` reuses the existing resolved macro context. Only identifier tokens
inside this mapping are considered. Object-like uses count; function-like definitions count only
with an authored invocation opening token. Aliases and resolved local/nested/standard headers use
the existing definition set. Unused definitions, unreferenced headers, literal strings and bare
uninvoked function macro names do not count. The context remains conservative across definition
order/undef as before; no new temporal preprocessor model is introduced.

An actual use finding anchors the root KEY/TARGET/EMPTY token, never replacement bytes. Raw
include/unknown directives already prevent extraction through earlier admission/create gates;
those mechanisms and their authored directive provenance are preserved.

## Macro key/value cases

Direct/alias/function/local-header/nested-header/standard-header/cross-header keys and direct,
function/header/alias values now yield zero exits. Parameter-dependent macros remain conservatively
refused without argument substitution. Macro key before/after/between literal entries behaves equally.

## Empty preprocessing fragments

Empty object/function/alias/header prefixes and suffixes suppress the complete mapping, including
otherwise literal entries. DROP argument fragments remain unevaluated. An actual neutral macro
cannot waive an unrelated empty entry or other positively malformed region.

## Whole-entry / comma / colon controls

Whole-entry object/function, comma object/function and colon object/alias cases retain safe refusal.
Their earlier structural gates remain intact; this repair does not reconstruct separators.

## Raw include mapping controls

Entry/comma/key/value/colon includes, nested and standard entry includes, missing includes and
unknown directives retain zero exits and the previous status. No textual source splicing occurs.

## Mapping order independence

Uncertain-first, uncertain-last and uncertain-middle cases all emit zero exits. Sole uncertain
entries retain findings. No decision depends on which entry the loop encounters first.

## No partial fact leakage

A dedicated test intercepts `fact()` and fails if any exit identity is ever created for the uncertain
sequence. Independent inherit/short facts remain. CLI manifest IDs, summary counts, finding links,
UNREVIEWED states and authored spans are checked separately from expected exit counts.

## Literal mapping preservation

Reliable north/south mappings still emit two ordered declarations. Safe CLI outputs are compared
against frozen P2F16 for exact retained facts, IDs and provenance. Two reliable setters preserve all
four source-ordered declarations. No final-value interpretation is introduced.

## Duplicate direction controls

Two literal duplicate directions retain two ordered facts and DUPLICATE_DECLARATION. A macro-dependent
duplicate causes refusal of the exit sequence. No last-wins rule is implemented.

## __DIR__ normalization controls

Unshadowed `__DIR__` with the existing literal concatenation rule remains STATIC_NORMALIZED with
identical normalization provenance. If a sibling mapping entry is preprocessing-uncertain, the
normalized exit is also suppressed. No new normalization is introduced.

## Independent non-mapping facts

The short-plus-uncertain-exits probe retains inherit and short. No global object-fact wipe was
added. Earlier create/admission refusal continues to follow its established policy.

## Multiple setter / mutation safety

One uncertain mapping vetoes exits from the complete analyzed create exit sequence, including
reliable mappings before or after it. All-reliable repeated setters keep ordered source declarations.
A computed whole mapping also prevents commitment of other exits in that sequence.

Per the owner's sections27/28, recognized create-scope add/delete of exits and set/add/delete of
`exits/...` veto staged exits with ORDER_SENSITIVE_MUTATION. This is conservative refusal, not mutation
execution. A pre-existing test that combined literal exits with create-time delete previously
expected one fact; its expectation is now zero under that explicit new requirement. Its existing
callback findings remain, plus the new refusal finding. A separate control proves mutations in
other callback functions remain historical review dependencies and do not suppress create facts.
Other-field mutations remain unchanged. Arbitrary computed property names, indirect calls and
runtime alias analysis remain outside this bounded profile; no general mutation engine is added.

Relevant authority read: [dbase.c](../../reference/es2/mudlib/feature/dbase.c) and
[treemap.c](../../reference/es2/mudlib/feature/treemap.c). No source behavior is executed.

## True malformed mapping preservation

Empty middle, missing colon, empty key/value and unfinished literal entries retain QUARANTINED,
exit1 and facts=[]. Unused structural definitions, unreferenced fragment headers and unrelated
safe includes do not waive these errors. All 18 original malformed newline cases remain quarantined;
two additional actual-neutral-macro/empty-middle cases do likewise. The unfamiliar missing-comma
multi-colon case keeps its existing PARTIAL/exit0/zero-exit bounded refusal.

## Non-preprocessor dynamic scope controls

Ordinary runtime-key and conditional `?` entries next to a literal entry were freshly locked on
P2F16: PARTIAL/exit0/one literal exit. Both remain byte-equivalent object/finding records in P2F17.
The bare uninvoked function-macro control also preserves that behavior. This does not redefine
all dynamic entries as atomic mappings.

## No macro expansion

The local [define documentation](../../reference/es2/mudlib/doc/lpc/preprocessor/define) supplies
the source basis for actual preprocessing dependence. No replacement-token synthesis, expansion,
argument substitution, include splicing or #if evaluation was added.

## No runtime mapping semantics

No LPC execution, duplicate-key resolution, last-write interpretation or Native/game consumer.
The output remains source declarations and refusal findings, never an authoritative gameplay graph.

## P2F1–P2F16 regressions

Fresh local gate: focused6, prior repair305, migration376 and full Python422 tests PASS. Repair classes include all
prior audit fixes and specifically directive segmentation, macro/include delimiters, header
classification, inherit boundaries and create-tail completion. Godot live gameplay is not applicable
to this pure parser change and was not run.

## Original 86-case matrix

43 handwritten LF/CRLF pairs rerun through actual CLI processes. All 30 former leaking cases now
emit zero exit facts; false quarantines remain zero; 18 true malformed cases retain quarantine.
Valid literal controls remain intact. Baseline sources/output and new results are retained separately.

## Expanded CLI matrix

35 additional handwritten LF/CRLF pairs (70 CLI runs) cover the formatted primary, runtime/conditional/
uninvoked scope controls, independent short, reliable/uncertain setter order, unsupported mutations,
duplicates, normalization, headers, empty fragments, actual invocation whitespace, opaque strings,
and genuine malformed controls. Combined mapping matrix: 156 runs. The separate historical
CLI matrix covers 492 runs, including the P2F12–P2F16 repaired families.

## Version 1.0.17

EXTRACTOR_VERSION is 1.0.17; recognized versions are exactly 1.0.0 through 1.0.17.
Schema remains 1 and profile remains static-room-v1.

## Output compatibility

Eighteen canonical historical/current versions are replaced via fresh CLI processes using copies;
original historical outputs remain unchanged. Unknown/manual/reviewed/future/malformed/empty outputs
must return exit2 without calling the writer or changing bytes. Closed-schema nested attacks remain.

## Output security

No CLI/writer/security implementation changed. Existing confinement, external tracked checkout,
symlink/junction, atomic-write-failure and nested metadata tests remain required. Disposable security
checks additionally verify protected paths, approved external/build outputs and writer non-invocation.

## Corpus A/B

Fresh double scan: exit1 (the known quarantines), scanned2336, supported485, EXTRACTED0, PARTIAL485,
OUT_OF_SCOPE1838, QUARANTINED13, facts2736, findings4296. A/B bytes equal: 9,808,627 each.
SHA-256: `3634ac095943f292c7de6024ec49983ef7a7484b1ac4774ef57a5a558fc5f7c3`.
Finding-code distribution and full provenance receipts are stored in ignored corpus evidence.

## Semantic delta audit

Compared against exact P2F16 post-commit corpus evidence: zero object/fact/finding/status/admission
changes, including all inherit/text/flag declarations. Only extractor_version differs. No real-corpus
mapping requires removal under the new rule. No quarantine delta or new supported candidate.

## 13 quarantines

The exact eight encoding and five syntax cases remain. Fresh source-byte checks confirm NUL/replacement
bytes, malformed quotes and unmatched delimiter locations; facts remain empty. This is P2F17 regression
evidence, not authorization or completion of a new milestone Final Re-Audit.

## 14 ANSI exclusions

All fourteen exact historical paths remain candidate=false, OUT_OF_SCOPE, facts=[], not QUARANTINED.
ANSI preprocessing is not evaluated.

## Provenance / fact-ID integrity

Fresh whole-corpus checks cover 9,587 provenance records, including 2,736 facts, 4,296 findings and
756 normalization inputs. Hashes, raw spans, line/column, source order, fact identity formula,
finding references, manifest uniqueness and summaries are checked. Mapping CLI probes separately
cover CRLF and removed-fact absence. No expanded or synthetic provenance is emitted.

## Archive preservation

ARCHIVE-01 remains CLOSED. All ten tracked historical audit hashes match frozen values. P2F10 remains
24,417 bytes / 468 CRLF, SHA-256 `56e1cd0aa0a573bc4a9505fb5df6bd1cfbd0076849a40f6bd4a4420483cb2213`.
Tracked P2F11 remains `48f07085604905ef3d603474bae86fb028cff9bbc1088a83769eee16babe9155`.
Attributes exception unchanged. Reference tree remains `4106480ab28cce8cd7b55704f8ae9ae062d42d03`;
all 2,336 source files retain their frozen raw-byte manifest.

## Six blocked-report preservation

P2F11_RERUN/P2F12/P2F13/P2F14/P2F15/P2F16 blocked reports remain owner-local, untracked and unstaged.
All six supplied SHA-256 values match, including P2F16
`29ac334bfd5e648e92a3845997e50a6c03cc1ab17a99b6b902f15fdb28f899c0`.
They are neither normalized nor included in this commit.

## Local validation and exact-commit gate

Pre-commit gate PASS: focused6 / historical305 / migration376 / Python422; repository checks and
`git diff --check` PASS; 156 mapping + 492 historical CLI runs PASS; 18 canonical replacement
versions PASS; security, corpus A/B, semantic delta, 13 quarantines, 14 ANSI exclusions, source/ID
integrity and archive preservation PASS. Markdown validation: 327 local links, no failures.
Ignored evidence lives under `build/migration-tooling-v1/p2f17/`.
The single implementation commit must subsequently rerun every prescribed gate on its exact SHA
before push. Pre-commit results do not count as exact-commit evidence. Post-commit receipts record
their actual HEAD; this report will not be amended to insert its own commit hash.

## Residual boundaries

The parser remains bounded; macro context is conservative, and runtime expressions/indirect mutations
are review dependencies. No full grammar, driver or preprocessing execution. Mapping atomicity can
suppress otherwise literal exits across a create sequence deliberately, without dropping independent
facts. Full milestone audit and PR CI remain pending, with no PASS claim for either.

## Owner gate

Exactly five authorized files: extractor, migration tests, this report, STATUS and ROADMAP.
P2F16 is CLOSED; Final Re-Audit after P2F16 was BLOCKED on FR16-01. P2F17 addresses that gate and
awaits owner review. Another complete Final Re-Audit requires separate owner authorization.
No PR, merge, P3, branch deletion or history rewriting. Phase is not integrated on main.
