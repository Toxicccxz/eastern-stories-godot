# Migration Tooling v1 — P2F27 Directive-Separated Function-Macro Invocation

**P2F27 FIX IMPLEMENTED — AWAIT OWNER REVIEW / FINAL RE-AUDIT NOT YET AUTHORIZED**

## Attempt 2 authorization and frozen identities

This is the owner's explicit conservative contract tightening after the uncommitted
Attempt 1 failure. FR26-01 was HIGH / D2-D3. This repair's local gates pass; owner
review and the next Structural Final Audit remain outstanding. The systematic
quarantine-path audit remains INCOMPLETE. This is not a milestone Final Re-Audit.

- Branch: `phase/migration-tooling-v1`.
- Frozen executable parent: `e4087d9e8d514cb4bbe4f560cb436b46f46d366c`.
- Frozen main: `cd07808cb76147d0b8c0dad9b82d078b49fefe64`.
- Extractor: `1.0.27`; known canonical versions `1.0.0` through `1.0.27` (28).
- Phase PR: none in the fresh all-state query. No merge, remote CI or P3.
- Exactly five authorized files: extractor, its test module, this report, STATUS and ROADMAP.

## Attempt 1 blocked regression and owner decision

Attempt 1 used additional directive-separated call groups to resolve terminal roles.
Its `NEXT() / #pragma / () / helper` case widened frozen P2F26 OUT_OF_SCOPE to PARTIAL
with inherit/name/exit facts. It stopped before commit. The owner then withdrew the
requirement to preserve directive-separated helper admission and authorized stronger
false negatives. More precise terminal recovery is explicitly forbidden here.

The complete historical Attempt 1 report is retained below, and its separate
owner-local copy remains untracked/unstaged with raw SHA-256
`b79c6227c6a5cbce6e6c7ad130c0f0be1bbcea182ccc2f687075287ef40dab83`.

## Refusal barrier and direct-adjacent behavior

While the top-level declaration name/prefix slot remains unresolved, matched authored
call groups retain their distinct cursors and first intervening directive witness.
Single-name object/function metadata may show that a function stage could require
such a group. At that boundary the shared pre-segmentation gate immediately refuses:
`candidate=false`, `OUT_OF_SCOPE`, empty direct inherits/categories/facts, CLI exit0.
No EMPTY/PREFIX/HELPER/SET/CREATE/UNKNOWN terminal is resolved after this boundary.

The original P2F26 classifier receives only adjacent groups and is byte-structurally
unchanged. Ordinary identifiers, literals, semicolons, braces, operators and commas
stop group discovery; no later group is borrowed. Each adjacent group advances at
most one function stage. An established helper name closes the name slot, so its
suffix does not reopen this barrier. Nested uses, standalone directives and
unreferenced dependencies retain old behavior.

Root, local, nested, standard, cross-header and nested-cross-header cases use the
same gate. Dependency hits precede include-hazard fallback and fact allocation;
findings anchor the root include. Root findings use the actual macro use/directive.
No replacement-derived token/span, expansion, parameter substitution, branch evaluation,
include splicing, function recovery or general LPC grammar was added. Shape traversal
is iterative. The lexer, CLI, MacroSummary and all create-tail/exit/finalizer methods
remain unchanged. The second changed existing method only describes the new refusal
in findings; the shared gate's early return already clears admission metadata.

## Source authority and locked boundary

The local [preprocessor manual](../../reference/es2/mudlib/doc/concepts/preprocessor),
[define reference](../../reference/es2/mudlib/doc/lpc/preprocessor/define),
[function syntax](../../reference/es2/mudlib/doc/lpc/constructs/function), and
[dbase setter](../../reference/es2/mudlib/feature/dbase.c) were consulted.
[Owner-locked D1–D9](DECISIONS.md#migration-tooling-v1-p2--owner-locked-extraction-boundary)
remain unchanged. Python 3.12 stdlib only; no game/save/runtime change or live-game
acceptance criterion. Godot gameplay validation is not applicable to this parser repair.

## Fresh pre-commit acceptance evidence

| Gate | Fresh result |
| --- | --- |
| P2F27 focused methods | 15 PASS |
| Exact FR26 replay | 100 CLI PASS |
| Attempt 1 expanded replay | 282 CLI PASS |
| Attempt 1 independent replay | all 56 CLI PASS |
| New contract differential sweep, including C01/C02 and old helper | 186 CLI PASS |
| All P2F27 synthetic no-widening comparisons | 624 CLI PASS against exact P2F26 |
| Retained P2F26 and earlier CLI families | 5,422 CLI PASS |
| Total synthetic CLI | 6,046 PASS |
| P2F26 focused / prior repair methods | 13 / 371 PASS |
| Full migration / full Python | 464 / 510 PASS |
| Canonical version replacement | 28 PASS |
| Output security / closed nested schema | PASS; 33 nested positions |
| Repository checks / diff whitespace | PASS |
| Finalizer independence probes | 40 key traces + 12 allocation probes PASS |

New oracles were fixed before execution. The old 100/282/56 source arrangements were
reused without altering historical evidence. Twenty-eight arrangements changed from
parent-equivalence to full refusal under owner sections 4–16 (56 LF/CRLF executions).
The retained P2F26 `mixed` object/function and formerly `uninvoked` shapes received
explicit pre-run stronger-refusal expectations. No unrelated historical oracle changed.
An initial replay setup stopped before any CLI because serialized JSON had platform
newlines; the harness now compares the already-frozen parsed oracle, without changing
its source, ID or expectation. The receipt aggregator also had a 276-to-286 count typo; it was corrected against the unchanged FR25 276-run receipt. Neither issue changed an acceptance oracle or production code.

The new differential sweep covers all six terminal roles, adjacent/single/multiple/
conditional directive placements, object/function alias shapes, six dependency
placements, hard boundaries, helper suffixes, nested uses and unreferenced headers.
Each P2F27 CLI compares candidate/status/facts to the frozen parent: no false-to-true
candidate, OUT_OF_SCOPE-to-PARTIAL/EXTRACTED, new facts/exits or new quarantine.
Fact-allocation and late-fallback spies prove refusal occurs before facts. Separate
unit assertions forbid terminal-role classification after the barrier is detected.

## Corpus A/B, safety budget, provenance and real exclusions

Two fresh independent scans are byte-identical. Each returns exit1 for the retained
13 actual source quarantines. Both outputs contain 9,808,627 bytes; SHA-256:
`c26649b08b7cb11139918165c38bc0177f49d0dd5cc60d4dd783e300d6832376`.

- Scanned: 2,336; supported: 485; EXTRACTED 0; PARTIAL 485; OUT_OF_SCOPE 1,838; QUARANTINED 13.
- Facts: 2,736; findings: 4,296. Summary and finding-code counts recomputed exactly.
- Exact P2F26 semantic comparison: zero object/fact/finding delta; only extractor_version changes.
- Safety budget: old supported 485, new supported 485, delta 0, affected paths none.
- All 13 quarantines freshly checked at raw byte offsets: 8 encoding, 5 syntax; zero new quarantine.
- All 14 ANSI exclusions remain candidate=false, OUT_OF_SCOPE and facts=[].
- All provenance, normalization inputs, source hashes, byte spans, line/column, raw/raw_hex,
  fact IDs, finding IDs, references, ordering and UNREVIEWED state validated exhaustively.
- No duplicate/ghost/orphan facts, dangling finding references or missing source records.

## Security, archives and scope

Output confinement, writer-not-called failures, atomic-write behavior, protected paths,
external checkout, mocked symlink/junction path flags, malformed/manual/reviewed/future
schemas and every discovered nested dictionary position retain the established safety
gates. Invalid UTF-8 raw_hex is independently exercised. No CLI/writer change.

All 21 owner-local historical artifacts remain untracked/unstaged and byte-identical;
all 10 tracked historical audits retain raw hashes. ARCHIVE-01 remains CLOSED.
P2F10 remains 24,417 bytes / 468 CRLF with frozen hash; `.gitattributes` is unchanged.
Reference tree: `4106480ab28cce8cd7b55704f8ae9ae062d42d03`.
Raw 2,336-file manifest:
`744e33e1740db7909129a3ae5e295158341b5012a411af953b144a5075bb0a80`.
No reference/game/runtime/DECISIONS/workflow mutation. All generated evidence stays
ignored under `build/migration-tooling-v1/p2f27-attempt2/`.

## Commit and owner gate

All pre-commit gates passed before STATUS/ROADMAP were updated. The authorized single
commit is `Refuse directive-separated function macro invocation`, directly on the
frozen parent. Publication additionally requires repeating every acceptance gate on
that immutable commit, verifying exactly five files, unchanged evidence and frozen
main. Exact commit and post-commit receipts are reported at completion; pre-commit
results above do not substitute for that gate.

Intentional residual limitation: directive-separated harmless helper/empty/prefix
macros may now be refused. This false-negative bias is owner-authorized; bounded
shape summaries are not driver execution. Structural Final Audit and the systematic
quarantine-path audit still must be completed under a later explicit authorization.
STOP for owner review; no PR, merge, remote CI, next Final Re-Audit or P3.

## Preserved Attempt 1 report — historical, superseded candidate

The following is the complete prior report text. Its present-tense statements and
counts describe Attempt 1 only; the Attempt 2 sections above control current status.

# Migration Tooling v1 — P2F27 Directive-Transparent Function-Macro Invocation Preflight

**P2F27 BLOCKED — UNCOMMITTED CANDIDATE / FR26-01 REMAINS OPEN**

## Authorization / frozen identities

Owner authorized only FR26-01 / HIGH / D2-D3 repair. Sections 52 and 73 require a
hard stop on independent-sweep or pre-commit acceptance failure and prohibit adding
a special-case patch afterward. That stop was triggered. This is not an implemented
or accepted P2F27 result; no implementation-complete top status is claimed.

| Identity | Verified value |
| --- | --- |
| Branch | `phase/migration-tooling-v1` |
| HEAD / origin phase | `e4087d9e8d514cb4bbe4f560cb436b46f46d366c` |
| Subject | `Preflight macro-supplied critical function identity` |
| Main / merge-base | `cd07808cb76147d0b8c0dad9b82d078b49fefe64` |
| Pre-edit tracked worktree / index | Clean |
| Phase PR, any state | None; fresh all-state query returned empty |

The current candidate modifies only `tools/migration/room_extractor.py` and
`tools/tests/test_migration_tooling.py`. This new report is untracked. STATUS,
ROADMAP, DECISIONS, old reports, lexer, CLI, attributes, game, workflow and legacy
source remain unchanged. The index remains clean. No reset/restore/checkout/stash/
clean/rebase/merge/amend/force push was used. No commit, push, PR, merge, P3, remote
CI or next Final Re-Audit was performed.

## FR26-01 root cause

The old preflight counted only immediately adjacent authored call groups. DROP or
RETURNS followed by a directive and a matched group was classified as an uninvoked
function-only name and therefore NONCRITICAL, prematurely closing the function-name
slot. Later effective set/create structure was missed. Fresh pre-edit primary and
independent LF/CRLF CLI reproductions confirmed supported PARTIAL results with
inherit/name/exit facts: **4 baseline CLI**, on exact frozen P2F26.

The source authority remains the local
[preprocessor manual](../../reference/es2/mudlib/doc/concepts/preprocessor),
[define reference](../../reference/es2/mudlib/doc/lpc/preprocessor/define),
[function syntax](../../reference/es2/mudlib/doc/lpc/constructs/function) and
[dbase set semantics](../../reference/es2/mudlib/feature/dbase.c), read in the
preceding audit and retained as the repair basis. This is not a gameplay migration
or a driver conformance claim.

## Why immediate-parenthesis invocation ownership was unsafe

A directive between the macro name and its authored group does not prove that
the macro is uninvoked after preprocessing. A conservative summary can acknowledge
possible group ownership without interpreting the directive or substituting tokens.
The candidate addresses that input to the existing role classifier, but failed a
separate frozen-parent negative control described below.

## Directive-transparent possible-call model

Candidate method `preprocessing_possible_call_groups` scans only directive tokens
and distinct matched authored parenthesis groups. It returns each group's ending
cursor and the cumulative first directive witness. A witness is committed to the
returned record only when a group is reached; trailing directives are not attached
retroactively to a completed invocation. The unchanged P2F26 role classifier receives
the resulting possible-call count.

## Hard token boundaries

Every ordinary identifier, literal, semicolon, brace, comma, operator or unrelated
punctuation stops this narrow helper. It does not enter a matched group's contents.
Focused tests cover hard boundaries and directives before/after completed calls.
No declaration grammar or full expression parser was added.

## Call-group cursor ownership

Proven EMPTY/PREFIX outcomes resume after the K-th distinct group supplied to the
role classifier. Zero-consumption object macros retain their original cursor.
Ambiguous consumption continues through existing UNKNOWN handling. A focused test
checks separate first and second group cursors; 1101 function stages are iterative.

## Structural preprocessing witness preservation

The candidate stores the consumed group's first directive witness until a later
critical or unknown identity is examined. Semicolon/body boundaries clear it. A
literal set/create after an erased/prefix-producing function macro is refused even
without another directive later in the signature. The witness remains authored
source data and does not represent an executed directive.

## EMPTY function macro flow

Empty function macros can keep the name slot open after possible invocation groups
across directives. The exact C01 family and single-gap tests refuse before facts.
Helper differential controls in the expanded matrix retain parent behavior.

## PREFIX function macro flow

Function-supplied mixed/void/static prefixes proceed to the eventual name. This
closes the exact C02 and type/modifier positive families. However a two-stage
function chain ending in PREFIX and then helper changes an older conservative
parent refusal to admission. That compatibility failure blocks this candidate.

## SET / CREATE function macro flow

Function-macro results naming set/create are assessed against distinct authored
groups and structural witnesses. Original unsafe root and late-fallback dependency
variants pass the frozen FR26 family in this candidate. They do not establish full
repair acceptance after the independent negative failure.

## HELPER negative flow

Definite helper names still close the name slot; suffix macros are not reinterpreted
as another function identity. Direct helper and empty/type-before-helper controls
pass in the expanded matrix. The independent continuation-to-helper case below
does **not** preserve frozen-parent output. This is a repair acceptance regression,
not a new numbered historical semantic blocker or proof that helper overrides set.

## Blocking independent negative — no oracle rewrite

Prewritten case: `boundary-6-root-lf`, expected **PARENT** (complete object/findings
equal to exact frozen P2F26). The independently authored source is:

```c
#define NEXT() LAST
#define LAST() mixed
inherit ROOM;
NEXT()
#pragma warnings
() helper(){}
void create(){set("name","ownership");set("exits",(["east":"/d/y"]));}
```

| Result | Frozen P2F26 | Current uncommitted P2F27 |
| --- | --- | --- |
| supported_candidate | false | true |
| status | OUT_OF_SCOPE | PARTIAL |
| direct_inherits/category_candidates | empty | ROOM retained |
| facts | empty | inherit, name, exit |

The independent sweep stops at its first failing execution: 53/56 CLI executed,
52 satisfied their oracle and one failed. The remaining three planned executions
were not run as acceptance. Four narrowly scoped confirmation executions separately
reproduce root/nested LF/CRLF differences. Root confirms the new candidate/facts.
Nested dependencies remain OUT_OF_SCOPE via late include fallback, with no facts,
but acquire direct ROOM metadata that the frozen parent cleared. Nested results
are not described as fact leakage.

The unchanged role classifier in P2F26 sees only NEXT's first group, reaches an
uninvoked returned LAST and returns UNKNOWN, leading to conservative refusal.
The candidate supplies both possible groups, resolves PREFIX, then reaches a
definite NONCRITICAL helper. This removes the old refusal and widens admission.
Sections 23/52 require frozen-parent helper behavior, and the acceptance policy
does not authorize silently accepting widened candidates or added facts.

This finding distinguishes semantic evidence from compatibility: the bounded
terminal is helper, and this report does **not** claim a proven local set override
in this negative fixture. Nevertheless the explicitly frozen PARENT oracle failed;
it cannot be autoaccepted or changed after execution. FR26-01 remains open because
the overall authorized repair did not pass. No one-case patch was appended.

## Single-gap critical cases

Focused and expanded positives where the sole directive is between a macro name
and its invocation group passed. The candidate does not need a later literal
set/create directive to refuse those cases. The complete independent acceptance
still failed for the separate helper case.

## Root/dependency shared preflight

All positive FR26 replay cases now have a shared pre-segmentation hit, candidate=false,
OUT_OF_SCOPE and empty inherit/category/fact fields. Instrumentation makes raw
inherit parsing, include_hazards fallback and fact allocation fail if reached.
Positive expanded cases cover root, local, nested, standard, cross and nested-cross
authored units. Conditional-root fixtures retain their pre-existing early conditional
refusal, while direct shared-scanner probes verify the positive structural pattern.

## Dependency provenance

Positive dependency findings anchor the actual root include origin. LF/CRLF/Unicode
focused tests verify root paths, hashes and exact raw spans. Replacement tokens are
not emitted as provenance. The independent helper negative's late-fallback metadata
change is recorded as a failure, not counted as successful preflight behavior.

## No macro/directive execution

No macro expansion, parameter substitution, branch evaluation or directive execution.
No external preprocessor or LPC runtime was invoked. Generic MacroSummary.reach/effect
were not modified. Focused instrumentation prohibits using generic reach/effect or
create-tail expansion as the positive structural decision mechanism.

## No expansion/recovery/grammar

No synthetic Token, recovered function, expanded translation unit, include splicing,
pointer/reference grammar or general declaration grammar. Existing P2F26 role logic,
P2F25 inheritance logic and the reached-unit loop are preserved in the candidate.

## Original FR26 100 CLI replay

**100/100 PASS**: 4 original confirmation executions and S01–S24's 96 executions.
All 48 prior failures meet the frozen oracle; all 52 prior satisfying executions
remain within it. The S13 SAFE_FACTS oracle permits the now-more-conservative full
refusal without rewriting its historical requirement. Original reports/fixtures
were not modified. This is a passed subset, not an overall P2F27 PASS.

## S01–S24 sibling replay

24 authored shapes × root/dependency × LF/CRLF = **96 CLI**, included in the 100
above, not added again. All REFUSE cases also require shared-preflight hits; late
include refusal with retained metadata is not accepted. PARENT negatives compare
the complete object/findings, and the original source family is retained.

## Expanded P2F27 invocation matrix

**141 authored arrangements / 282 CLI PASS.** Handwritten oracles cover empty,
type/modifier, set/create/helper, object/function aliases, multiple callable stages,
single/multiple directives, both signature gaps, hard boundaries, helper suffixes,
nested code/text, competing/unknown roles and unreferenced dependencies. All twelve
directive kinds plus a multiple-directive sequence are represented. Six source
locations are included. Oracles were serialized before execution.

## Independent invocation-ownership sweep

Separate handwritten matrix: **28 arrangements / 56 planned CLI**. It does not
derive oracles from product tests or the expanded matrix. It covers EMPTY/PREFIX
versus set/helper, set/create/helper identities, object aliases, direct calls,
uninvoked/no-call, semicolon/nested boundaries and a returned-function continuation.
It executed **53 CLI: 52 PASS, 1 FAIL**, then stopped immediately. No expectation
adjustment or snapshot regeneration. Four later narrow confirmation CLI prove
the same failure in root and nested LF/CRLF; no unrelated regression work followed.

## P2F26 regression

NOT RUN complete 366/276/402/60/68/178/316 matrices after the independent failure.
The frozen-parent model used by the negative controls is loaded from exact
`e4087d9e8d514cb4bbe4f560cb436b46f46d366c` Git blobs in ignored evidence.

## P2F25 regression

NOT RUN full FR24 90 or expanded matrices; hard-stop rule.

## P2F24 regression

NOT RUN full 84/348/58/216/64 matrices; hard-stop rule.

## Historical regressions

Full P2F1–P2F26 repair suites, P2F11–P2F16 structural and P2F17–P2F20 exit matrices
were NOT RUN after the failure. No historical closure is newly claimed.

## Fresh tests and counts

| Gate | Fresh result |
| --- | --- |
| Frozen P2F26 pre-edit reproduction | 4 CLI reproduce FR26-01 |
| New P2F27 focused methods | 11/11 PASS |
| Exact FR26 replay | 100/100 CLI PASS |
| Expanded invocation matrix | 282/282 CLI PASS |
| Independent matrix | 53 executed; 52 PASS, 1 FAIL; 3 not run |
| Narrow failed-negative confirmation | 4 CLI reproduce parent differences |
| Candidate CLI executions | 439 total |
| Total CLI including pre-edit baseline | 443 total |
| Full migration / full Python suites | NOT RUN |
| Repository checks | NOT RUN after stop |
| Diff / new-report whitespace and links | Checked at closeout |

Source-level and monkey-patch probes are additional in-process checks, not CLI
counts. No live Godot was required or claimed for this pure parser repair.

## Version 1.0.27

Uncommitted candidate version is 1.0.27; KNOWN includes 1.0.0–1.0.27 (28), schema1
and static-room-v1 unchanged. Current-version product assertions were updated and
1.0.27 appended to version loops. No historical semantic oracle was rewritten.
The failed candidate is not a published 1.0.27 release.

## Compatibility

28-version canonical replacement and closed-schema invalid-output gates NOT RUN
after the independent failure. No successful compatibility claim.

## Output security

Full retained output-security matrix NOT RUN after stop. CLI/writer unchanged.

## Corpus A/B

NOT RUN. No prior corpus hash/count is presented as fresh candidate evidence.

## Semantic delta

Whole-corpus projection against P2F26 NOT RUN. The confirmed negative fixture
widens candidate admission and adds facts relative to P2F26; it cannot be accepted
as a zero-delta or permitted conservative result. No real-source impact is inferred.

## 13 quarantines

NOT freshly rescanned or re-justified in this attempt. No D9 closure claim.

## 14 ANSI

NOT freshly rerun in this attempt. Historical results are not acceptance evidence.

## Provenance / IDs / summary

Passed positive cases refuse before allocation and retain real authored witnesses.
Focused and matrix checks cover dependency include origins and distinct groups.
Exhaustive whole-corpus ID/provenance/summary validation NOT RUN. The negative's
new facts are a frozen-behavior failure even though they have authored spans.

## ARCHIVE-01

**CLOSED / preserved.** Ten historical tracked raw hashes were checked against
working, HEAD and index bytes. P2F10 remains 24417 bytes / 468 CRLF. Attributes remain
`b33913bb7279e1ab67762574ab277828a9fd114dae23dceace2f24ae842194d6`.

| Tracked audit | SHA-256 |
| --- | --- |
| `MIGRATION_TOOLING_V1_FINAL_AUDIT.md` | `a61cd221e8b70961d963484dfe953f5e341511967d9cfd66a55159b1bab85d63` |
| `MIGRATION_TOOLING_V1_FINAL_RE_AUDIT_AFTER_P2F4.md` | `c4ff8faccea5b79d0ba4007d2d616007f4a55fda3b84e58e78875d68f4e4aed0` |
| `MIGRATION_TOOLING_V1_FINAL_RE_AUDIT_AFTER_P2F5.md` | `0d93333f8db116db7f6af0cb79e201b26228010cc5e85592adf30cdeb4c94be9` |
| `MIGRATION_TOOLING_V1_FINAL_RE_AUDIT_AFTER_P2F6.md` | `8a9ba2d9bfd666b949b470d872820c63d5adeab26d849deef7e4460b45593b76` |
| `MIGRATION_TOOLING_V1_FINAL_RE_AUDIT_AFTER_P2F7.md` | `939c23c9ac71749fc815cbfadcc147407d40024efe353edf0090971cdb5a9d38` |
| `MIGRATION_TOOLING_V1_RE_FINAL_AUDIT.md` | `c67dc612139bf37a6c6a41d4753b58723b154d0f6e92cdca0ab5a34ad93d0548` |
| `MIGRATION_TOOLING_V1_FINAL_RE_AUDIT_AFTER_P2F8.md` | `0734b90e65cb05d0ff4fd9eb701871234472f608b4350f48460b2e63fef12419` |
| `MIGRATION_TOOLING_V1_FINAL_RE_AUDIT_AFTER_P2F9.md` | `ed1721c2de295defb3d7ada595fe73a4db199462a3ef97b61540782d96bc95a4` |
| `MIGRATION_TOOLING_V1_FINAL_RE_AUDIT_AFTER_P2F10.md` | `56e1cd0aa0a573bc4a9505fb5df6bd1cfbd0076849a40f6bd4a4420483cb2213` |
| `MIGRATION_TOOLING_V1_FINAL_RE_AUDIT_AFTER_P2F11.md` | `48f07085604905ef3d603474bae86fb028cff9bbc1088a83769eee16babe9155` |

## Twenty owner-local evidence hashes

All remain untracked, unstaged and byte-identical. This new implementation report
is separate from those twenty historical artifacts and is also untracked.

| Owner-local historical artifact | SHA-256 |
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
| `MIGRATION_TOOLING_V1_FINAL_RE_AUDIT_AFTER_P2F25.md` | `58e0e8258bfcbb6c0e07ae15a861121c68cb310b1bb36f7600d53a84844640cc` |
| `MIGRATION_TOOLING_V1_P2F26_MACRO_SUPPLIED_CRITICAL_FUNCTION_IDENTITY_PREFLIGHT_ATTEMPT1_BLOCKED.md` | `7f409e5b5c9e2a1040afba20bdcf1d809c583e5ef934a2848d21bb1fc5ecfced` |
| `MIGRATION_TOOLING_V1_P2F26_MACRO_SUPPLIED_CRITICAL_FUNCTION_IDENTITY_PREFLIGHT_ATTEMPT2_BLOCKED.md` | `af444e4a6022a1a823b1795d41fe4319e15aa4321dc5328e11da54bd8bec13a6` |
| `MIGRATION_TOOLING_V1_FINAL_RE_AUDIT_AFTER_P2F26.md` | `4ce54c97b12f70a450faa0c29f86672e5ecf3e9433c2b85cf52bfdafba65b7f4` |

## Source immutability / changed-file scope

Reference tree: `4106480ab28cce8cd7b55704f8ae9ae062d42d03`.
Raw 2336-file manifest:
`744e33e1740db7909129a3ae5e295158341b5012a411af953b144a5075bb0a80`.
No source/game/runtime/workflow mutation. Closeout compares every tracked file to
preflight bytes, allowing only the two authorized candidate executable/test paths.
STATUS/ROADMAP remain untouched because all gates did not pass. The source/classifier
snapshot and test expectations remain available for owner review; no cleanup/reset.

## Residual boundaries

The independent frozen-parent regression is **not accepted** as a residual risk.
The demonstrated helper terminal does not establish an unsafe setter override, but
it does not authorize changing a frozen oracle or widening admission either.
There is no new semantic blocker number. FR26-01 remains open pending an accepted
repair. Full grammar, macro/directive execution, include expansion and function
recovery remain outside scope. No broad refactor is justified by this failure.

## Owner gate

**P2F27 BLOCKED before commit.** No one-case patch was appended after the failed
independent gate. Candidate source/test changes remain unstaged and uncommitted;
this new report remains untracked. Index clean; all twenty earlier evidence artifacts
untouched. No PR, merge, remote CI, P3 or next Final Re-Audit. Main and remote phase
remain at their frozen identities. The milestone is not integrated on main.

**MIGRATION TOOLING V1 P2F27 BLOCKED**
**FR26-01 REMAINS OPEN — AWAIT OWNER REVIEW**
