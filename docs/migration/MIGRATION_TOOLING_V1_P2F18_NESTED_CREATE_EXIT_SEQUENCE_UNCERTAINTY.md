# Migration Tooling v1 — P2F18 nested create exit sequence uncertainty

**P2F18 FIX IMPLEMENTED — AWAIT OWNER REVIEW / FINAL RE-AUDIT NOT YET AUTHORIZED**

## Authorization / frozen identities

Only FR17-01 / HIGH / D3-D6 is repaired on `phase/migration-tooling-v1`.
Executable parent: `4ae432a9be43c7555612078be9710511787f477d`, subject
`Suppress exit facts for preprocessing-uncertain mappings`.
Main and merge-base: `cd07808cb76147d0b8c0dad9b82d078b49fefe64`.
Fresh fetch, refs, clean tracked/index preflight and all-state phase PR search matched the prompt.
The [locked contract](DECISIONS.md#migration-tooling-v1-p2--owner-locked-extraction-boundary)
remains unchanged. No PR, merge, remote CI, P3 or next Final Re-Audit is authorized.

## FR17-01 root cause

P2F17 staged reliable flat exits and committed them only after checking sequence uncertainty.
However, `create_body()` skipped nested segments with a general unsupported finding and never
sent their whole `set("exits", ...)` calls through `statement()` / `exits()`.

### Why the direct sequence scan missed nested whole setters

The final token scan covered subtree setters and whole/subtree add/delete, but intentionally
excluded whole `set("exits", ...)` to preserve reliable flat declarations. Consequently a skipped
nested whole setter did not set the uncertainty flag, leaving earlier or later literal candidates
eligible for commitment. PARTIAL / UNREVIEWED did not meet the owner's zero-exit requirement.

Before product edits, the exact original 48 CLI cases and 100 independently authored expanded
cases were executed against the frozen parent. The prompt-shaped LF/CRLF example had exit0,
PARTIAL, candidate=true and one surviving north exit beside a nested computed setter. Expected
safe exits were handwritten as zero. Evidence: `build/migration-tooling-v1/p2f18/before-nested.json`.

## Nested create segment model

The existing complete-create segmentation plan is reused. A nested segment now receives a
bounded authored-token mutation check before the existing unsupported finding. Unsupported
receiver/control/expression statements and unanalysed call arguments also receive that check.
No nested declaration is extracted. The original segmentation, pairing, directive reliability,
inherit boundary, create-tail completion and mapping-parser algorithms are unchanged.

## Local exit-affecting call classification

The recognizer requires an identifier `set`, `add` or `delete`, an immediate opening parenthesis,
a literal text first argument, and a following comma or closing parenthesis. Only `exits` and
`exits/` subpaths qualify. An immediate authored receiver prefix determines a separate path:

| Authored shape | Classification and result |
| --- | --- |
| Direct local call in a skipped create region | ORDER_SENSITIVE_MUTATION; veto complete sequence |
| `other->set/add/delete(...)` | Receiver-qualified cross-object control; no local veto |
| `::set/add/delete(...)` | Inherited-qualified uncertainty; separate UNSUPPORTED_CONSTRUCT and sequence veto |
| Reliable flat direct literal exits setter | Existing parser/staging; preserve declarations |

The final direct mutation scan also guards `->` and `::`; it does not mislabel either receiver
as direct local. `::` is handled only through its separate skipped-region finding, whose authored
provenance includes the prefix. No receiver alias or object-identity analysis is introduced.

### Receiver requirements and authoritative source

Prompt sections 23/24 exclude `::` from the **direct local** classification; section 35 requires
all 24 historical omissions, including four inherited-qualified executions, to yield zero exits.
Both requirements are retained by the separate inherited uncertainty path. An initial clarification
question was withdrawn after verifying this distinction; no owner answer or changed acceptance
criterion is claimed. The initially pending inherited expectations were frozen as zero before
executing the completed receiver implementation. Other handwritten expectations were unchanged.

Sources consulted: [LPC inheritance](../../reference/es2/mudlib/doc/lpc/constructs/inherit),
[ROOM](../../reference/es2/mudlib/std/room.c),
[dbase](../../reference/es2/mudlib/feature/dbase.c), and
[treemap](../../reference/es2/mudlib/feature/treemap.c).
The inheritance document describes dispatch to inherited code and per-object inherited variables;
ROOM inherits F_DBASE, whose set/add/delete operate on that object's database. Inherited dispatch
therefore cannot be assumed harmless to this room, but is not represented as a direct local call.
Its implementation is neither resolved nor executed by the extractor.

## Nested literal / computed / preprocessing setters, add/delete and deep nesting

Nested literal, computed and macro-dependent whole setters all veto exits without evaluating
their values. Nested whole/subtree add/delete and subtree setters do likewise. Tests cover
before, after and between reliable setters, bare blocks, one/two/three nested levels, if, while,
switch and unbraced control flow. Mutation presence suffices; branch truth, reachability, loop
counts, dominance and last-write behavior are not interpreted.

Nested includes and actual macro hazards retain the existing refusal mechanisms. Duplicate
create, shadowed set, missing include and true malformed source controls retain prior behavior.

## Cross-object and unrelated nested-code controls

Six handwritten `other->` whole/subtree set/add/delete controls retain the reliable flat exit.
Five pairs previously lost it under P2F17's unguarded global mutation scan; guarding the receiver
now prevents those false local classifications. This deliberate synthetic-control change is
required by the receiver negative controls; the real corpus has no resulting added exit facts.

Nested short/name/long/indoors setters, unrelated calls/expressions, comments, quoted call text,
and a mutation in another callback do not veto create exits. Existing general review findings
remain. The implementation does not equate every nested block with an uncertain exit sequence.

## Sequence-level veto and fact-ID staging integrity

Any qualifying skipped-region mutation sets the existing `exit_sequence_uncertain` flag before
`commit_exit_facts()`. The gate emits all reliable declarations in source order or none of them.
It never picks a final setter, emits a subset, creates then deletes facts, or invents runtime state.

A spy on `RoomExtractor.fact()` rejects any exit-ID construction in vetoed before/after/between
sequences. Independent inherit and short facts remain. Candidate tuples are cleared by the
existing finalizer. CLI checks independently validate the SHA-based identity formula, unique IDs,
exact raw spans/source hashes, line/column, finding references and summary counts.

## Independent non-exit facts and reliable flat setter preservation

All nested-matrix non-exit facts are compared byte-for-byte as structured records with the parent
output. Reliable single/multiple flat setters retain exact facts, IDs and provenance; source-order
declarations and literal `__DIR__` normalization survive. Receiver controls that formerly had no
exit are checked against their handwritten north-to-/a expectation and authored span/ID formula.
The whole corpus additionally preserves every inherit/text/flag/exit record and ID exactly.

## No control-flow, macro or mapping execution

There is no control-flow engine, preprocessing expansion, include splicing, mapping execution,
alias identity analysis, synthetic token stream, source concatenation, new dependency or runtime
integration. Only the extractor and its tests change executable behavior. AST comparison limits
existing method changes to `create_body`, `statement`, `commit_exit_facts`, with one new bounded
helper. `exits`, macro effects, inheritance and tail logic remain unchanged.

## Original FR17 and expanded P2F18 CLI matrices

The original 48 executions reuse exact authored LF/CRLF bytes from the owner-local audit evidence.
All 24 former omissions now produce zero exits, including the four inherited-qualified cases.
The separate nested-literal pair also correctly produces zero exits. Original direct FR16 controls
stay at zero; literal/callback/unrelated/two-flat controls retain their prior records.

The expanded matrix contains 50 handwritten cases in LF and CRLF: 100 executions. Together these
148 runs record exit code, status, candidate flag, complete facts, exits, finding codes/reasons,
IDs, provenance and source hashes. Final receipts are `pre-nested.json` and `post-nested.json`;
the earlier provisional receipt explicitly records unresolved receiver cases and is not a PASS.

## FR16/P2F17 and historical regression matrices

The full mapping matrix reruns 156 cases: 86 original FR16 executions plus 70 P2F17 expansions,
covering macro key/value, header/alias/function forms, empty/whole-entry/separator macros, includes,
missing include, uncertain entry order, duplicates, normalization, multiple setters and mutations.
All prior expected outcomes and independent facts are preserved.

Historical CLI coverage additionally reruns 492 header/include/inherit/pending-boundary/create-tail
cases, 204 P2F11 directive-position cases, and 118 P2F12 delimiter cases. The P2F11 historical
unterminated header-body case uses the already-locked P2F13 header-fragment result (OUT_OF_SCOPE,
exit0), not the obsolete P2F11 quarantine expectation. Root malformed controls remain quarantined.
Total external CLI matrix executions per full gate: **1,118**.

## Version 1.0.18 / output compatibility / output security

Extractor 1.0.18, known versions 1.0.0 through 1.0.18, schema1, profile `static-room-v1`.
Nineteen canonical historical/current outputs passed real CLI replacement. Manual, unknown,
reviewed, future-version, malformed and empty outputs returned exit2, never called the writer, and
retained their bytes. The existing output-security suite also checked protected paths, external tracked
checkouts, all 33 nested dictionary positions and raw-hex provenance. CLI/writer code is unchanged.

## Corpus A/B and semantic delta audit

Two independent complete scans are compared with exact parent output, without allowing newly
supported candidates, new exits, unrelated fact/status changes or quarantine changes.

| Metric | P2F18 pre-commit A and B |
| --- | ---: |
| CLI exit | 1 |
| Scanned / supported | 2,336 / 485 |
| EXTRACTED / PARTIAL | 0 / 485 |
| OUT_OF_SCOPE / QUARANTINED | 1,838 / 13 |
| Facts / findings | 2,736 / 4,296 |
| Output bytes | 9,808,627 |

A/B SHA-256: `083259705abf3db35ba6614708a235da135390fb0012f2d5946bdfd993dfab00`.
Objects, facts, IDs, findings, categories, statuses and summaries have **zero semantic delta** from
the exact parent. Only extractor_version changes. No real source path requires an allowed removal.
Finding distribution: CALLBACK_BEHAVIOR284, DRIVER_SEMANTICS_UNKNOWN408, DYNAMIC_EXPRESSION10,
ORDER_SENSITIVE_MUTATION30, OUT_OF_SCOPE1319, REQUIRES_SEMANTIC_REVIEW1623, RNG_SEMANTICS58,
SOURCE_ENCODING_ISSUE8, SOURCE_SYNTAX_ERROR5, UNRESOLVED_INCLUDE97,
UNRESOLVED_INHERITANCE14, UNSUPPORTED_CONSTRUCT440.

## Thirteen quarantines, fourteen ANSI exclusions and provenance

The exact 13 quarantines remain: eight positive NUL/replacement-character cases and five positive
authored quote/delimiter defects. Raw-byte positions/reasons and source hashes are freshly checked;
no header/preprocessing uncertainty is accepted as substitute proof of source corruption.
All fourteen locked ANSI exclusions remain candidate=false, OUT_OF_SCOPE, facts=[], not quarantined.

Corpus verification covers 9,587 provenance records, 2,736 facts, 4,296 findings, 756 normalization
inputs, manifest uniqueness, stable order, complete references and exact summaries. No ghost IDs,
orphan references or synthetic source spans appear. LF/CRLF matrix checks supplement the corpus.

## Archive preservation

ARCHIVE-01 remains CLOSED. Ten tracked historical audit hashes match the frozen values.
P2F10 remains 24,417 bytes / 468 CRLF, SHA-256
`56e1cd0aa0a573bc4a9505fb5df6bd1cfbd0076849a40f6bd4a4420483cb2213`.
Tracked P2F11: `48f07085604905ef3d603474bae86fb028cff9bbc1088a83769eee16babe9155`.
`.gitattributes` remains unchanged, including the P2F10 `-text` exception; its hash remains
`b33913bb7279e1ab67762574ab277828a9fd114dae23dceace2f24ae842194d6`.
Reference tree: `4106480ab28cce8cd7b55704f8ae9ae062d42d03`; 2,336 raw source files retain manifest
`744e33e1740db7909129a3ae5e295158341b5012a411af953b144a5075bb0a80`.

## Seven blocked-report preservation

All seven reports remain owner-local, untracked, unstaged and byte-identical. P2F17 was frozen
locally before any product edit, not inferred from a supplied value:

`P2F17_BLOCKED_SHA=3e4d4a6c8955cb81da7d236360e43f743cd38610d9cdc20e0c3c3f08e9170703`

| Report | SHA-256 |
| --- | --- |
| P2F11_RERUN | `8fc46327ca954ad0089e3ee4fb496bfe8cfe21f497b43ae77432e76ff2bc170b` |
| P2F12 | `a0847fdd481867b45e0c1d0b4b4dfdea7e0995a2bb607130fceeff0d8effc04a` |
| P2F13 | `adbdaddd424dcebed66ef0e984969fa7d2a949325c184a944d764950ccf9febb` |
| P2F14 | `450a982195d670ac7ebc1c38e7afb88cf9a41d52d1bc574d95e605c5ef90a38e` |
| P2F15 | `6de33c7bef47e42c4897d6a52858ca6a4e1a97a357e51b1738ac376bd16d3da8` |
| P2F16 | `29ac334bfd5e648e92a3845997e50a6c03cc1ab17a99b6b902f15fdb28f899c0` |

## Local validation and exact-commit gate

Pre-commit gate PASS: focused6 / historical311 / migration382 / Python428; repository checks,
diff check, all 1,118 CLI cases, 19 canonical replacements, output security, corpus A/B, zero semantic
delta, 13 quarantines, 14 ANSI exclusions, provenance and archive/source integrity all PASS.
Markdown validation checked 334 local links and 12 anchors, with no failures. Ignored receipts live
under `build/migration-tooling-v1/p2f18/`; directive/delimiter matrices have separate pre-commit
receipts because those independent runs were added while the other gate runner was already active.
The single commit must rerun all prescribed gates on its actual SHA before push; pre-commit
evidence does not substitute. Post-commit receipts record HEAD, without amending this document
to insert its own hash. No live gameplay validation is applicable to this pure parser repair.

## Residual boundaries / owner gate

The recognizer remains bounded to authored literal-key calls. It does not evaluate arbitrary
expressions, aliases, indirect calls, macros, control flow or runtime state. Existing conservative
hazard findings remain. This implementation verification is not a new Final Re-Audit.

Exactly five authorized files: extractor, migration tests, this report, STATUS and ROADMAP.
P2F17 is CLOSED; Final Re-Audit after P2F17 was BLOCKED on FR17-01 / HIGH / D3-D6. P2F18 addresses
the nested sequence blocker and awaits owner review. A complete Final Re-Audit requires separate
owner authorization. No PR, merge, remote CI, P3, branch deletion or history rewriting. The phase
remains implementation work on its existing branch and is not fully integrated on main.
