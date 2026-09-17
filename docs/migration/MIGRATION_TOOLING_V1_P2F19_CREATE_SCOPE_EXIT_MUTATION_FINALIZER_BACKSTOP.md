# Migration Tooling v1 — P2F19

**P2F19 FIX IMPLEMENTED — AWAIT OWNER REVIEW / FINAL RE-AUDIT NOT YET AUTHORIZED**

## Authorization / frozen identities

This implementation addresses only FR18-01 / HIGH / D3-D6 on
`phase/migration-tooling-v1`. The frozen executable parent and preflight origin phase are
`9275db9f8e004ff4fba804106980e0d79e6dfb3b` (`Propagate nested create exit uncertainty`).
Main and merge-base remain `cd07808cb76147d0b8c0dad9b82d078b49fefe64`.
Fresh fetch, clean tracked/index state, 42-entry history inspection, and an all-state
GitHub phase-PR query passed before editing. No phase PR exists.

Exactly five files belong to this change: `tools/migration/room_extractor.py`,
`tools/tests/test_migration_tooling.py`, this implementation report,
`docs/production/STATUS.md`, and `docs/production/ROADMAP.md`.
No historical audit or source archive is part of the commit.

## FR18-01 root cause and statement dispatch coverage hole

An accepted outer `set(literal_key, value)` bypassed the unsupported-region scanner
when the field was text, a flag, an unsupported literal field, or an exits mapping.
A hidden inner whole-exits setter therefore escaped both the early scanner and the
old global scan, which exempted all direct whole setters. A dynamic outer value's
finding did not make the complete create exit sequence uncertain.

The exact multiline primary and independent objects-value examples from the owner
prompt were freshly run in LF and CRLF before editing. All four returned exit0,
PARTIAL, candidate=true, and one incorrectly surviving north exit. The primary
retained inherit/short and reported DYNAMIC_EXPRESSION. Receipts are in ignored
`build/migration-tooling-v1/p2f19/before-primary.json`.
After repair all four retain appropriate independent facts with zero exits and no
quarantine. Neither the outer expression nor the inner setter is executed.

## Why branch-local recognizers were insufficient

Adding one scanner invocation to each currently known dispatch branch would leave
the safety invariant dependent on future branches remembering that invocation.
The finalizer now independently classifies every bounded authored exit-affecting
call in analyzed create scope before any staged exit is turned into a fact.
A focused test disables the early scanner and still proves refusal for wrappers,
nested blocks, and flag-value expressions.

## Finalizer-level safety invariant and reliable flat registration

`flat_exit_setter_starts` records only the authored `set` token start at the direct
flat `set("exits", VALUE);` dispatch into the existing mapping parser. The finalizer
exempts a local whole setter only if that exact start is registered. The inner call
in an outer mapping cannot inherit the outer call's exemption. Nested/skipped,
inherited-qualified, and cross-object calls are not registered.

Registration is evidence of flat-path consumption, not proof that the mapping is
reliable. Computed mappings, actual preprocessing uses, structural uncertainty,
and all existing environment gates still suppress the complete exit sequence.
Single and multiple reliable flat declarations preserve their authored order.
No last-write or duplicate-key execution semantics are introduced.

## Shared exit-call classification

Both early recognition and finalization use `classify_exit_call`. It recognizes
only authored identifier calls `set`, `add`, or `delete` with literal first key
`exits` or `exits/...`, followed by the argument delimiter. It distinguishes:

| Authored call | Sequence policy |
| --- | --- |
| Direct whole set | Exact registered flat call may proceed; otherwise refuse |
| Direct subtree set | Refuse |
| Direct whole/subtree add or delete | Refuse |
| Immediate `other->` receiver | Not a current-room mutation |
| Immediate `::` receiver | Inherited-qualified uncertainty; refuse |

The inherited finding retains the authored `::` prefix. No alias resolution or
inherited body execution is performed. Calls in reset/init/helper functions retain
their historical review treatment without automatically vetoing create exits.
Duplicate create and shadowed-set environment refusals remain intact.

## Text-field, flag-field and unsupported-field values

Fresh LF/CRLF cases cover short/name/long, indoors/outdoors/no_fight/no_clean_up,
and objects/foo. Hidden local whole setters suppress the complete exit sequence
regardless of the outer field. The outer scalar/text policy is unchanged.
Unrelated dynamic flag and text values preserve reliable exits.

## Deep/conditional expressions and mapping-entry hidden calls

Multiple wrapper levels and conditional values are scanned as authored tokens;
no branch truth or value is evaluated. Mapping-entry tests include an outer
literal north entry plus a dynamic inner whole setter. Only the outer token start
is registered; no exit fact is emitted. Computed whole mapping values with hidden
calls remain refused. This repair does not change mapping grammar or SourceError
classification.

## Order independence and nested FR17 preservation

Before/after/between cases all suppress the entire exit sequence. Nested blocks,
deep blocks, wrappers, direct add/delete/subtree setters, and previously repaired
FR17 cases remain safe. The exact original FR17 48 executions and P2F18 expanded
100 executions pass again. Its former 24 omissions remain zero-exit.

## Reliable flat, preprocessing and direct mutation controls

Single and two-flat reliable declarations retain one and two ordered facts,
respectively. Cross-object whole/subtree set/add/delete calls preserve current-room
exits. Registered preprocessing-sensitive and computed mappings still refuse the
sequence; registered declarations followed by direct deletion remain refused.
Comments, strings, characters, heredoc content and raw echo payload do not create
runtime mutation calls or falsely veto the reliable control.

## Fact-ID staging integrity, finding deduplication and provenance

The finalizer scans before `fact('exit', ...)` is called. A spy rejects any exit
fact allocation in the suppressed mapping case; no create-then-delete cleanup is
used. An exact-identity assertion verifies distinct outer/inner byte starts.
Reliable facts preserve the source-path/SHA/field/span ID formula.
`exit_uncertainty_call_starts` deduplicates sequence-refusal findings across the
early scan and finalizer. Existing general review findings remain separate.
LF/CRLF receipts verify authored raw spans, source SHA, line and column. Inherited
provenance includes `::`; nothing is anchored to expanded or synthetic source.

## No execution or scope expansion

No expression/control-flow execution, macro expansion/substitution, include
splicing, mapping execution, runtime mutation, object alias analysis, or AST
interpreter was added. MacroEffect, pairing, header/include classification,
inherit boundaries, create tails, mapping parsing and the CLI/writer are unchanged.
An independent AST comparison limits existing method changes to initialization,
statement registration, the early recognizer and finalization, with two narrow
shared helpers. No Native/gameplay files changed. Live Godot validation is not
applicable to this pure parser correction and was not run.

## Fresh regression and CLI verification

| Gate | Fresh pre-commit result |
| --- | ---: |
| P2F19 focused regression methods | 8 PASS |
| Every P2F1–P2F18 repair regression | 317 PASS |
| Full migration suite | 390 PASS |
| Full Python suite | 436 PASS |
| Original FR18 | 56 PASS; all former 32 violations fixed; 24 previous passes preserved |
| Original FR17 + expanded P2F18 | 48 + 100 PASS |
| Expanded P2F19 handwritten shapes | 55 shapes / 110 LF+CRLF executions PASS |
| Exact multiline primary + independent | 4 PASS |
| FR16/P2F17 mapping atomicity | 156 PASS |
| Header/inherit/pending/tail retained families | 492 PASS |
| P2F12 delimiter matrix | 118 PASS |
| P2F11 directive matrix | 204 PASS |
| Canonical historical version replacement | 20 PASS |

CLI case expectations are handwritten, not product-generated snapshots. The
original FR18 source bytes and expected counts match the preserved audit inputs;
non-exit facts/status/candidate and all safe exit identities remain unchanged.
Evidence records exit code, status, candidate, all facts/IDs, findings/provenance,
source bytes/SHA and LF/CRLF spans. Core family CLI total is
1284; the four multiline reproducers are additional.
Repository static checks and whitespace checks pass. Full test/security logs are
retained under ignored `build/migration-tooling-v1/p2f19/`.

## Version 1.0.19 and output compatibility/security

EXTRACTOR_VERSION is 1.0.19; the recognized version set is 1.0.0–1.0.19 (20).
Schema remains 1 and profile remains static-room-v1. Real CLI replacement accepts
untouched canonical historical outputs for all 20 versions. Unknown, manual,
reviewed, future, malformed and empty output probes return exit2 without calling
the writer or changing bytes. Closed-schema attacks at all
33 discovered nested dictionary locations are refused.
The complete suite covers protected repo/reference/game/docs paths, absolute and
relative escapes, external tracked checkouts, symlink/junction handling, atomic
write failure, approved build output and approved external output. No output
security policy or writer implementation changed.

## Whole corpus A/B and semantic delta audit

Two independent real CLI scans are byte-identical (exit1 because retained source
quarantines remain): scanned 2,336; supported 485; EXTRACTED0/PARTIAL485/
OUT_OF_SCOPE1,838/QUARANTINED13; facts2,736; findings4,296.
Bytes: 9808627; SHA-256: `05cfe4438e54efa5154970d840c2451fa77452416d92f96ac33c6c2ba4812f61`.

Finding distribution:
`CALLBACK_BEHAVIOR=284`, `DRIVER_SEMANTICS_UNKNOWN=408`,
`DYNAMIC_EXPRESSION=10`, `ORDER_SENSITIVE_MUTATION=30`, `OUT_OF_SCOPE=1319`,
`REQUIRES_SEMANTIC_REVIEW=1623`, `RNG_SEMANTICS=58`,
`SOURCE_ENCODING_ISSUE=8`, `SOURCE_SYNTAX_ERROR=5`, `UNRESOLVED_INCLUDE=97`,
`UNRESOLVED_INHERITANCE=14`, `UNSUPPORTED_CONSTRUCT=440`.

The exact-parent corpus receipt names 9275db9f8e004ff4fba804106980e0d79e6dfb3b.
Independent comparison found 0 object/fact/finding/status deltas;
only extractor version differs at document level. This was checked, not assumed.
No new exits/candidates, non-exit changes, or quarantine changes occurred.

## 13 quarantines, 14 ANSI exclusions and ID integrity

The exact 13 source quarantine paths remain: eight positively identified encoding
byte defects and five authored syntax defects. Each retains facts=[], correct
reason/span, and positive raw-byte corruption evidence. These are not inferred
from preprocessing uncertainty. The 14 ANSI exclusions remain candidate=false,
OUT_OF_SCOPE, facts=[], never QUARANTINED.
All corpus fact IDs, references, object finding IDs, summary counts, source
hashes/raw spans/line/columns and normalization inputs are verified, with no ghost,
orphan or duplicate IDs. This retained-source check does not claim completion of
the separately required systematic quarantine-path audit.

## Archive preservation and eight blocked reports

ARCHIVE-01 remains CLOSED. All ten tracked historical audit raw hashes match in
HEAD/index/worktree. P2F10 remains 24,417 bytes / 468 CRLF,
SHA `56e1cd0aa0a573bc4a9505fb5df6bd1cfbd0076849a40f6bd4a4420483cb2213`.
Tracked P2F11 remains
`48f07085604905ef3d603474bae86fb028cff9bbc1088a83769eee16babe9155`.
The unchanged .gitattributes hash is
`b33913bb7279e1ab67762574ab277828a9fd114dae23dceace2f24ae842194d6`.
All eight owner-local reports (P2F11_RERUN and P2F12–P2F18) remain untracked,
unstaged and byte-identical to their owner-frozen hashes. In particular P2F18 is
`81335715cec2aaf87ecd55f3e62e91f56e4d27ea81b8fa69640e4c6f55ad8396`.
Reference tree remains `4106480ab28cce8cd7b55704f8ae9ae062d42d03`; the 2,336-file
raw reference manifest remains
`744e33e1740db7909129a3ae5e295158341b5012a411af953b144a5075bb0a80`.

## Exact-commit gate and residual boundaries

This report records pre-commit implementation evidence. The authorized workflow
requires one commit, `Backstop create exit mutation coverage`, followed by a fresh
rerun of ALL listed gates on that exact commit before push. The final task receipt
and ignored post-* receipts identify its immutable SHA; this report is not amended
to insert its own hash. No pre-commit result substitutes for that gate.

Only bounded authored literal-key calls are classified. Existing unresolved
macro/include/environment refusals remain authoritative; arbitrary LPC semantics
are not interpreted. Native generation, NPC/item migration and P3 remain deferred.
No PR, merge, remote CI or next Final Re-Audit is authorized by this correction.
Migration Tooling v1 is not integrated on main. Previous main CI is historical
integration evidence, not a new P2F19 remote run.

## Owner gate

P2F18 is CLOSED. Final Re-Audit after P2F18 remains historically BLOCKED on
FR18-01 / HIGH / D3-D6. P2F19 is implemented and awaits owner review. A new Complete
Final Re-Audit, including systematic quarantine-path coverage, requires separate
owner authorization after this review. No Final Re-Audit PASS is claimed.
