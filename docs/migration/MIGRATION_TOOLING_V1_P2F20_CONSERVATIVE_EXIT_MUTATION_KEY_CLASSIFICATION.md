# Migration Tooling v1 — P2F20

**P2F20 FIX IMPLEMENTED — AWAIT OWNER REVIEW / FINAL RE-AUDIT NOT YET AUTHORIZED**

## Authorization / frozen identities

Only FR19-01 / HIGH / D3-D6 is addressed on `phase/migration-tooling-v1`.
The frozen executable parent is `53dd575fa5f391568e1426abbf5140dc8b46fa32`
(`Backstop create exit mutation coverage`). Preflight local/origin phase matched it;
frozen main/merge-base remained `cd07808cb76147d0b8c0dad9b82d078b49fefe64`.
Fresh fetch, decorated 44-entry history, all-state PR search, tracked/index
cleanliness, nine report hashes and source immutability checks passed before edits.
No phase PR exists. The separate PowerShell Get-FileHash check of P2F19's blocked
report matched the owner's raw SHA before product edits.

Exactly five files are authorized: extractor, migration tests, this report,
STATUS and ROADMAP. Reference/game/.github/DECISIONS/CLI/lexer/attributes and all
historical reports remain unchanged. No branch or integration milestone was created.

## FR19-01 root cause

The old shared classifier inspected only `literal(ts[index + 2])`, requiring the
very next token to be an argument delimiter. Grouped keys began with `(` and
returned no classification before receiver analysis. Both early recognition and
the finalizer consequently missed a definite current-room mutation.

Fresh LF/CRLF primary and independently resolved-target deletion fixtures were
run before editing: four exit0/PARTIAL/candidate=true results each retained one
exit fact; direct inspection confirmed classifier=None, refusal identities=[],
and uncertainty=false. Raw sources, facts/IDs, findings and call identities are
preserved under ignored `build/migration-tooling-v1/p2f20/before-primary.json`.
The same four sources after repair return exit0, no quarantine, and zero exits.

## Why single-token literal classification was insufficient

Fixing only one parenthesized spelling would leave variables, function results,
concatenations and other unresolved property keys as another route around the
sequence veto. The new policy proves a key non-exit before allowing an otherwise
unsupported current-object property mutation to coexist with reliable exits.
It does not evaluate the unknown key to guess its runtime property.

## Parentheses-only static key reduction and iterative grouping logic

`classify_property_key` returns `(text, authored_argument_end)` for STATIC_TEXT or
`(None, authored_argument_end)` for UNKNOWN. An iterative delimiter-depth scan
locates the first argument's boundary. A second iterative loop strips only matching
outer parentheses. Exactly one remaining text literal token is required for a
static result; its decoding uses the existing bounded literal helper.

Zero, one, two, three and 1,100 grouping levels are covered. Concatenation,
comma expressions, variables, macros, indexing, conditionals, numeric keys and
function calls remain UNKNOWN. There is no recursive grouping peel, replacement
token, expression interpreter, macro expansion or argument substitution.
Delimiter scanning does not establish new syntax validity; existing structural
and quarantine policies still own malformed source decisions.

## Static text versus unknown keys and conservative safety invariant

| Receiver / key | Current-create exit policy |
| --- | --- |
| Local known whole exits set | Only the exact registered flat call may proceed through existing mapping gates |
| Local known subtree set / whole or subtree add/delete | Veto complete exit sequence |
| Local UNKNOWN key | Veto complete exit sequence |
| Local STATIC_TEXT non-exit key | No exit veto |
| Inherited known exit or UNKNOWN key | Inherited-qualified uncertainty; veto |
| Inherited STATIC_TEXT non-exit key | No exit veto |
| Immediate cross-object call, known or UNKNOWN key | Does not veto current-room exits |

The inherited non-exit policy is explicit: `::set("short", value)` and
`::delete("objects")` do not target exits and do not automatically veto them.
`::set(variable, value)` remains uncertain. No inheritance execution or object
alias inference is performed. Only analyzed create scope participates in this veto;
reset/init/helper mutations retain their separate review role.

## Direct local, cross-object and inherited-qualified classification

The existing shared `classify_exit_call` remains the sole classification path
used by both `unsupported_exit_mutations` and `commit_exit_facts`. Known exit keys
retain existing kinds. Unknown keys receive local-unknown-key or inherited-unknown-key.
Known non-exit keys return no exit-affecting classification; immediate `->` keeps
cross-object calls separate. Receiver classification does not manufacture a local
mutation from another object's property call.

Original [dbase](../../reference/es2/mudlib/feature/dbase.c) and
[treemap](../../reference/es2/mudlib/feature/treemap.c) authority underlies the
whole/subtree set/add/delete safety policy. The locked
[D3/D6 boundary](DECISIONS.md#migration-tooling-v1-p2--owner-locked-extraction-boundary)
permits conservative refusal without evaluating keys. No gameplay mechanic or
legacy source was changed.

## Exact flat setter registration preservation

`statement()` and its single-token key dispatch are unchanged. Only the authored
`set("exits", VALUE);` actually consumed by the supported flat declaration path
registers its token start. Grouped whole setters remain unsupported/unregistered,
so the classifier's ability to recognize their key never expands fact admission.

Reliable single and two-flat declarations preserve order and existing fact-ID
formula. Registration does not override computed/preprocessed mapping refusal.
Neither mapping grammar nor inherit/create-tail/macro/include/pairing logic changed.
Independent AST comparison confirms only two existing methods changed
(classify_exit_call and refuse_exit_call), plus the new narrow property-key helper.

## Grouped set/add/delete and unknown-key matrices

The focused and real CLI matrices cover all six operation variants at multiple
grouping depths in LF/CRLF. Grouped/unknown local and inherited calls are exercised
as flat/nested statements, outer setter values, generic arguments, mapping values,
and before/after/between reliable setters. Every unsafe case suppresses the complete
sequence, not just its own candidate entries.

Unknown keys include variable, grouped variable, foo(), string concatenation,
mapping indexing, conditional expressions, comma expressions, string indexing,
macro identifiers and integers. No result is executed or guessed.

## Static proven non-exit, receiver and opaque controls

Grouped short/name/indoors, objects/inventory and exits_other do not veto reliable
exits. Immediate cross-object unknown/grouped calls also preserve room exits.
Inherited static non-exit controls pass. Comments, strings, heredoc, characters
and raw echo payload remain opaque to call classification.

Macro K and grouped K, defined or unresolved, use the existing hazard machinery;
no macro expansion was introduced. Where the create sequence remains eligible,
its authored key is UNKNOWN and local/inherited calls receive sequence-refusal
findings. Cross-object grouped macro-key controls do not independently veto room
exits. Exact findings and authored provenance are retained in the CLI receipts.

## Finalizer-only independence

The focused gate disables the early scanner for grouped whole set, grouped delete,
unknown local mutation and inherited grouped/unknown calls. The finalizer alone
refuses all five cases. Cross-object controls preserve the reliable exit.
The retained P2F19 direct-key independence matrix also passes (12 LF/CRLF in-process
checks). No dispatch branch is required to remember a new grouping exception.

## Finding deduplication and provenance

Existing authored-start deduplication remains. One call seen by both scans receives
one sequence-refusal finding. For grouped and unknown keys, refusal provenance
extends from the authored call through the complete first argument, including
its grouping. Inherited spans retain the `::` prefix. Direct literal-key spans
stay unchanged. Unknown-key reasons explicitly describe uncertainty rather than
asserting a definitely executed mutation. All provenance comes from root bytes.

## Fact-ID staging integrity

A fact() spy rejects any exit allocation for suppressed grouped/unknown cases.
No emit-then-remove rollback is used. Uncertainty is set before staged candidates
are committed. Reliable exits retain their existing IDs/order/provenance; corpus
and CLI integrity checks verify no duplicate/ghost/orphan IDs or summary mismatch.

## Fresh repair regressions and CLI gates

| Gate | Fresh pre-commit result |
| --- | ---: |
| P2F20 focused methods | 8 PASS |
| Every P2F1–P2F19 repair method | 325 PASS |
| Full migration suite | 398 PASS |
| Full Python suite | 444 PASS |
| Original FR19 grouped-key matrix | 94 PASS; former 68 violations fixed; 26 controls preserved |
| Original FR18 | 56 PASS |
| Original FR17 + P2F18 expanded | 48 + 100 PASS |
| P2F19 expanded implementation matrix | 110 PASS |
| P2F19 independent create-call matrix | 270 PASS |
| P2F20 expanded key matrix | 147 shapes / 294 LF/CRLF executions PASS |
| Primary + independent before/after fixtures | 4 post-fix CLI PASS |
| P2F17 mapping family | 156 PASS |
| P2F13–P2F16 header/inherit/pending/tail families | 492 PASS |
| P2F12 delimiter family | 118 PASS |
| P2F11 directive family | 204 PASS |
| Total repair/historical CLI executions per gate run | 1946 PASS |

Expectations are handwritten and fixed before product execution. The original
FR19 94 source bytes and oracles match the preserved audit matrix; safe control
IDs and all independent non-exit facts are preserved. Original FR18 source bytes,
56 expectations, safe identities and non-exit facts are also checked. No snapshots
were autoaccepted. Repository static checks and whitespace checks pass.

## Version 1.0.20, compatibility and output security

EXTRACTOR_VERSION=1.0.20; KNOWN spans 1.0.0–1.0.20 (21). Schema1 and
static-room-v1 are unchanged. Fresh real CLI replacement accepts all 21 canonical
historical versions. Unknown/manual/reviewed/future/malformed/empty outputs return
exit2, do not call the writer and remain byte-identical. All
33 nested dictionary metadata attack locations are refused.

The full existing confinement suite covers protected paths, relative/absolute
escapes, external tracked checkout, symlink/junction handling, atomic failure,
approved build/external outputs and invalid-UTF8 raw_hex. No CLI/writer change or
security behavior delta occurred.

## Whole corpus A/B

Two independent real CLI scans are byte-identical; exit1 retains source quarantine.
Scanned 2336; supported 485;
statuses {'EXTRACTED': 0, 'PARTIAL': 485, 'OUT_OF_SCOPE': 1838, 'QUARANTINED': 13}; facts 2736; findings 4296.
Output bytes: 9808627. SHA-256: `578b3d15dcdc30db660f2a0111e59a3634f7fe11129e46490ddbc86a95778d42`.

Fresh finding distribution: CALLBACK_BEHAVIOR=284, DRIVER_SEMANTICS_UNKNOWN=408, DYNAMIC_EXPRESSION=10, ORDER_SENSITIVE_MUTATION=30, OUT_OF_SCOPE=1319, REQUIRES_SEMANTIC_REVIEW=1623, RNG_SEMANTICS=58, SOURCE_ENCODING_ISSUE=8, SOURCE_SYNTAX_ERROR=5, UNRESOLVED_INCLUDE=97, UNRESOLVED_INHERITANCE=14, UNSUPPORTED_CONSTRUCT=440.

## Semantic delta audit

The baseline receipt identifies exact parent
`53dd575fa5f391568e1426abbf5140dc8b46fa32`. Fresh independent projection comparison
found 0 object/fact/finding/status changes; only extractor_version
changed at document level. This result was checked, not assumed or forced. No new
facts/candidates, quarantine changes, non-exit changes or unrelated statuses occur.
There are therefore no affected real-source mutation paths to enumerate.

## 13 quarantines and 14 ANSI exclusions

The exact 13 quarantine paths remain: eight encoding and five syntax cases. Fresh
checks inspect positive actual-byte corruption and exact reason/span with facts=[].
Grouped/unknown keys do not introduce source quarantine; focused malformed-delimiter,
mapping, inherit, create-tail and encoding controls retain their prior errors.
All 14 ANSI exclusions remain candidate=false, OUT_OF_SCOPE, facts=[], not quarantined.
These retained-source checks do not substitute for the next systematic
quarantine-path Final Re-Audit.

## Exhaustive corpus provenance / ID integrity

Fresh validation checks source SHA/raw/byte ranges/line/column, normalization inputs,
object/fact IDs, finding references and exact summary distributions. All records
remain UNREVIEWED. Safe corpus facts match the exact parent. LF/CRLF grouped-key
findings retain authored spans; no synthetic source or normalized replacement
stream is introduced.

## Archive and nine blocked-report preservation

ARCHIVE-01 remains CLOSED. All ten tracked historical audit raw hashes match
HEAD/index/worktree. P2F10 remains 24,417 bytes / 468 CRLF with SHA
`56e1cd0aa0a573bc4a9505fb5df6bd1cfbd0076849a40f6bd4a4420483cb2213`.
Tracked P2F11 remains
`48f07085604905ef3d603474bae86fb028cff9bbc1088a83769eee16babe9155`.
.gitattributes remains
`b33913bb7279e1ab67762574ab277828a9fd114dae23dceace2f24ae842194d6`.

All nine owner-local reports (P2F11_RERUN, P2F12–P2F19) remain untracked,
unstaged and byte-identical. P2F19 remains
`3a06d404419551833c4afa2b22afee6ecb58b217b279348f69f5906a910d835f`.
Reference tree remains `4106480ab28cce8cd7b55704f8ae9ae062d42d03`, with 2,336-file
raw manifest `744e33e1740db7909129a3ae5e295158341b5012a411af953b144a5075bb0a80`.
No archive normalization or repair was performed.

## Exact-commit gate

This report records pre-commit evidence. The authorized single commit is
`Harden create exit mutation key classification`, parent 53dd575. Every gate above
must run afresh on that immutable commit before its normal phase-branch push.
The final task receipt and ignored post-* evidence identify the exact SHA; this
report is not amended to insert its own hash. No pre-commit result substitutes
for exact-commit verification.

## Residual boundaries

This is a conservative call/key classifier, not a full LPC parser/evaluator.
Unknown current-object keys may cause additional false negatives; that is the
owner-authorized safety policy. Static extraction syntax is not broadened.
Existing macro/include/structural uncertainty remains authoritative. No Native
consumer, gameplay/schema change or Godot runtime validation is part of this pure
parser repair. No runtime session was launched.

## Owner gate

P2F19 is CLOSED. Its Final Re-Audit remains historically BLOCKED on FR19-01 /
HIGH / D3-D6. P2F20 is implemented and awaits owner review. The next Complete
Final Re-Audit, including mandatory systematic quarantine-path coverage, requires
separate authorization. No Final Re-Audit PASS is claimed.

No phase PR, merge, remote CI or P3 was initiated. Main remains the prior stable
integration; Migration Tooling v1 is not integrated on main. The phase branch and
all nine blocked reports are retained.
