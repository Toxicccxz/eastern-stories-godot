# Migration Tooling v1 — P2F15

**P2F15 FIX IMPLEMENTED — AWAIT OWNER REVIEW / FINAL RE-AUDIT NOT YET AUTHORIZED**

## Authorization / frozen identities

Only FR14-01 / blocking MEDIUM / D9 is addressed on `phase/migration-tooling-v1`.
The pre-fix executable HEAD and required commit parent are
`cbb5a598deeea44fde5febb1485f0e35797f09c9` (`Fix preprocessor inherit declaration boundary`).
Frozen main and merge base are `cd07808cb76147d0b8c0dad9b82d078b49fefe64`.
Fresh fetch, identity/status/history checks and all-state phase PR search passed before editing;
no phase PR existed. The index and tracked tree were clean, with exactly four expected owner-local reports.

The five authorized files are the extractor, its tests, this report, STATUS and ROADMAP.
This is a phase implementation report under `docs/migration/`, not a new Final Re-Audit.
Lexer, CLI/writer, source, game, workflows, attributes, DECISIONS and historical audits are unchanged.

## FR14-01 root cause

Fresh actual-CLI pre-fix reproduction:

```c
#define TAIL() ; void create()
inherit ROOM TAIL() {}
```

This returned QUARANTINED / SOURCE_SYNTAX_ERROR / `unterminated inherit` / exit1.
The handwritten `inherit ROOM; void create() {}` control returned EXTRACTED / exit0.
After the fix the macro-dependent root is OUT_OF_SCOPE / exit0, with candidate=false,
direct_inherits=[], category_candidates=[], facts=[] and no SOURCE_SYNTAX_ERROR.
Ignored fresh evidence is under `build/migration-tooling-v1/p2f15/`.

## Why P2F14 lost preprocessing evidence

The existing scanner stopped before a declaration starter or an identifier whose following
parenthesized tokens and brace resembled an untyped function. Its pending slice therefore excluded
the very `TAIL` invocation needed by the existing uncertainty helper. Checking only `ROOM` could
not distinguish an authored missing semicolon from a preprocessing-dependent declaration tail.

## Correct boundary decision order

The scanner still discovers the same candidate boundaries. Before deciding that a missing semicolon
is genuine, the pending evidence now includes a boundary-leading authored identifier and, when
present, its immediate `(` invocation marker. The existing `inherit_boundary_uncertain` helper
checks that evidence using the existing compilation-context MacroSummary.

Sensitive or unprovable actual use follows the existing conservative refusal path. A non-macro or
provably neutral boundary leaves the genuine `unterminated inherit` error intact. Arguments and
the following function body are not swept into the evidence slice. Already terminated declarations
do not invoke the helper; explicit mocks prove this lazy behavior.

## Function-shaped macro uses

Direct function macros, parameter macros, whitespace-separated and multiline invocations now retain
actual invocation evidence. Independent FINISH/CLOSE spellings and a 1,100-link alias chain are covered.
No TAIL-specific branch or shape-specific exemption was added.

## Declaration-starter macro uses

Actual macro uses spelled `int`, `void`, `private` and `static` are checked before treating their
spelling as reliable boundary evidence. The implementation uses identifier kind and existing macro
lookup, not a new keyword whitelist. Keyword finding provenance points to the authored identifier.

## Normal authored boundary controls

Ordinary `void create()`, `int x;`, `string foo;`, `private void helper()` and `static int value;`
after an unterminated inherit still quarantine with `unterminated inherit`. Normal terminated
inherits and literal room facts retain their prior results.

## Untyped real function controls

`inherit ROOM` followed by a genuine `create() {}` still quarantines. The untyped-function heuristic
remains enabled. Structural macros used only in that following body do not waive the inherit error.

## Neutral / unused macro controls

Provably neutral function macros, neutral function-to-object aliases and a neutral keyword macro
retain quarantine. Unused structural macros, unused cycles and unused unknown replacements do not
count. Macro spellings in comments, strings, characters, quoted symbols, heredocs and raw echo
payloads do not become actual uses.

## Header / nested / standard / cross-header macros

Definitions from local, nested and standard includes, and aliases across separate headers, are
handled through existing traversal. Headers remain HEADER / OUT_OF_SCOPE / fact-free. Nested-header
root findings anchor to the authored root use, not the header replacement. P2F14 raw inherit-tail
include behavior and P2F13 standalone-header classification were rerun unchanged.

## Alias / cycles / competing definitions

Object-to-function and function-to-object aliases reuse iterative MacroSummary dependency traversal.
Used cycles, competing definitions, token paste, invalid signatures and parameter-dependent unknown
structure conservatively refuse extraction when neutrality cannot be proved. Unused equivalents
do not excuse malformed source. No second macro collector was introduced.

## Multiple inherits

Valid-before-uncertain, uncertain-before-valid and excluded-base-before-uncertain controls all refuse
the root. Multiple completely authored valid inherits preserve their prior result. The uncertainty
path does not retain admission evidence collected before the ambiguous declaration.

## Metadata / fact suppression

Every FR14/P2F15 uncertain root checks candidate=false, direct_inherits=[], category_candidates=[]
and facts=[]. Refusal occurs before fact extraction, using the existing clear-and-return path.
No expanded inherit or recovered fact is emitted.

## Provenance

New positive/negative tests validate source hashes and exact raw byte spans under LF and CRLF.
Dedicated nested-header and keyword probes require the authored root macro identifier. Real CLI
receipts retain exits, status, candidate, inheritance/category metadata, facts, findings, provenance,
source bytes/hashes and header statuses. Whole-corpus verification validates 9,587 provenance records:
1,799 inherit, 2,736 fact, 4,296 finding and 756 normalization-input records, including 1,239 Unicode
spans and three CRLF source records. All 7,032 facts/findings remain UNREVIEWED.

## Why no macro expansion

The change retains existing authored tokens; it creates no synthetic token, replacement semicolon,
function signature or expanded source. There is no substitution, include splicing, expression or
conditional evaluation, execution or new grammar. Only `RoomExtractor.extract_structure` changed
among existing methods; imports and all other existing methods are unchanged by AST comparison.

## Create-tail unconfirmed observation explicitly NOT fixed

```c
#define NOTHING
inherit ROOM;
void create(){ NOTHING }
```

This earlier parallel observation remains **UNCONFIRMED / NOT YET NUMBERED / NOT FIXED**.
No new product test asserts a changed outcome. Create segmentation, statement extraction, unfinished
statement policy and create-tail waivers are unchanged. Existing FR10/P2F11 regressions pass.

## P2F1–P2F14 regressions

Fresh pre-commit results: P2F15 focused 5/5; P2F1–P2F14 repair methods 295/295;
complete migration suite 365/365; complete Python suite 411/411; repository checks and diff check PASS.
The focused matrix contains 54 handwritten cases in both LF/CRLF forms, plus alias-depth,
provenance and lazy-path assertions. Historical tests changed only where version expectations
and the known-version coverage necessarily gained 1.0.15.

## Real CLI matrix

338 independent CLI executions passed: the 48-case FR14 family, 62 additional P2F15 forms and
228 prior delimiter/include/header/inherit-boundary/control cases. All 26 legal false-quarantine
FR14 cases now return OUT_OF_SCOPE / exit0. Valid and genuinely malformed controls retain their
expected behavior. Totals: 218 exit0, 120 expected exit1; zero false root/header quarantines or
unsafe facts. Expectations are handwritten, not snapshot-autoaccepted.

## Version 1.0.15

EXTRACTOR_VERSION is 1.0.15; known versions are 1.0.0 through 1.0.15. Schema remains 1 and profile
remains `static-room-v1`. No IR schema change was made.

## Output compatibility

Sixteen genuine canonical historical/current outputs passed replacement through the real writer.
Unknown, manual, reviewed, future-version, empty and malformed output controls return exit2,
never call the writer and preserve target bytes.

## Output security

The complete suite and fresh independent probes passed: eight protected-path forms, 33 nested
metadata dictionary layers, six unsafe-output variants, tracked output in another checkout,
approved build/external output and invalid-UTF8 raw_hex preservation. CLI and writer source are
unchanged; there is no output behavior delta beyond recognizing the new canonical version.

## Corpus A/B

Two independent full scans each returned expected exit1 due to the existing real corrupt sources.

| Measurement | A and B |
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

Both SHA-256 values are `ffc5394056c69630deabbae9ff9932576c7d47234f530d0cf187016cdb949e06`.
A bytes == B bytes. Full-document comparison with exact P2F14 evidence at the frozen parent,
excluding only extractor_version, yields zero differences. Object, direct-inherit, finding and
quarantine data are unchanged.

Finding distribution: CALLBACK_BEHAVIOR284, DRIVER_SEMANTICS_UNKNOWN408, DYNAMIC_EXPRESSION10,
ORDER_SENSITIVE_MUTATION30, OUT_OF_SCOPE1319, REQUIRES_SEMANTIC_REVIEW1623, RNG_SEMANTICS58,
SOURCE_ENCODING_ISSUE8, SOURCE_SYNTAX_ERROR5, UNRESOLVED_INCLUDE97,
UNRESOLVED_INHERITANCE14, UNSUPPORTED_CONSTRUCT440.

## 13 quarantines

The exact set remains eight encoding and five syntax errors. Fresh inspection validates actual
NUL/replacement bytes or positive unterminated-string/mismatched-delimiter evidence at the recorded
spans. No genuine corrupt source was downgraded. Per-source contexts and byte evidence are retained
in the ignored corpus and self-audit receipts.

## 14 ANSI exclusions

The exact P2F10 exclusion inventory remains candidate=false / OUT_OF_SCOPE / facts=[] and is never
quarantined. No ANSI expression evaluation was added.

## Archive preservation

ARCHIVE-01 remains CLOSED. All ten tracked historical audit hashes match their frozen values.
P2F10 stays 24,417 bytes / 468 CRLF with SHA-256
`56e1cd0aa0a573bc4a9505fb5df6bd1cfbd0076849a40f6bd4a4420483cb2213`.
Tracked P2F11 remains `48f07085604905ef3d603474bae86fb028cff9bbc1088a83769eee16babe9155`.
`.gitattributes` is unchanged, including the P2F10 `-text` exception.
Reference tree remains `4106480ab28cce8cd7b55704f8ae9ae062d42d03`; the 2,336-file raw-byte manifest
remains `744e33e1740db7909129a3ae5e295158341b5012a411af953b144a5075bb0a80`.
Authoritative inputs were inspected through the read-only ES2 corpus; no gameplay rule was ported.

## Four blocked-report preservation

All four reports remain owner-local, untracked, unstaged and byte-identical:

| Report suffix | SHA-256 |
| --- | --- |
| P2F11_RERUN | `8fc46327ca954ad0089e3ee4fb496bfe8cfe21f497b43ae77432e76ff2bc170b` |
| P2F12 | `a0847fdd481867b45e0c1d0b4b4dfdea7e0995a2bb607130fceeff0d8effc04a` |
| P2F13 | `adbdaddd424dcebed66ef0e984969fa7d2a949325c184a944d764950ccf9febb` |
| P2F14 | `450a982195d670ac7ebc1c38e7afb88cf9a41d52d1bc574d95e605c5ef90a38e` |

## Residual boundaries

This bounded repair does not establish complete LPC preprocessing or grammar validity. It preserves
uncertainty instead of deriving preprocessed facts. The independent complete Final Re-Audit remains
required and is not authorized by this implementation. The create-tail observation is deferred.
Pure parser changes require no live Godot gameplay validation; none is claimed.

## Owner gate

This report records pre-commit verification. The authorized single commit must have the frozen
parent and subject `Preserve preprocessing-sensitive inherit boundaries`. Before pushing, the exact
new commit must independently rerun every focused, historical, full-suite, CLI, compatibility,
security, corpus, provenance and integrity gate; ignored `post-*` receipts bind results to that SHA.
The completion response identifies the verified/pushed SHA without rewriting this report to embed
its own commit hash. P2F14 is CLOSED; P2F15 awaits owner review. No phase PR, merge or new remote CI
result is claimed; main remains frozen. P3 and another Final Re-Audit require owner authorization.
