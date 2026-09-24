# Migration Tooling v1 — P2F28 Unsupported Declaration Prefix / Preprocessing Refusal

**P2F28 FIX IMPLEMENTED — AWAIT OWNER REVIEW / FINAL RE-AUDIT NOT YET AUTHORIZED**

## Authorization / frozen identities

The owner authorized only FR27-01 / HIGH / D2-D3, as conservative contract tightening.
P2F27 is CLOSED. Its Final Re-Audit was BLOCKED at this structural admission defect;
the structural audit and systematic quarantine-path audit are not complete.
This document records an implementation repair, not a milestone Final Re-Audit.

- Branch: `phase/migration-tooling-v1`.
- Executable parent: `ffd863d25f9e71bec3d2b1019ce685a6b491b2ea`.
- Parent subject: `Refuse directive-separated function macro invocation`.
- Frozen main / merge-base: `cd07808cb76147d0b8c0dad9b82d078b49fefe64`.
- Fresh preflight: local and remote phase identical; tracked worktree/index clean;
  no phase PR in any state; 22 owner-local historical files untracked/unstaged.
- Scope: extractor, product test module, this report, STATUS and ROADMAP only.

## FR27-01 root cause

The frozen scanner changed DECLARATION_PREFIX to AFTER_NAME on unsupported `*`.
That token did not establish a function name. A function-only macro separated from
its authored call by a directive was then invisible to the P2F27 invocation barrier.
Raw segmentation could miss the effective local setter and retain unsafe create facts.
Dependency fallback sometimes removed facts but retained ROOM metadata, also violating
the shared early-preflight contract.

## Why `*` must not close the name slot

An authored token outside the supported prefix subset says only that structure is
unknown. It cannot prove a name was seen. The unsupported token is retained as an
authored witness, while the name slot remains unresolved for preprocessing checks.

## Unsupported declaration-prefix contract

Only the existing literal prefix set and proven EMPTY/PREFIX macro roles remain
supported. Unsupported pre-name material plus preprocessing-sensitive declaration
structure triggers full refusal: CLI exit0, candidate=false, OUT_OF_SCOPE, empty
direct_inherits/category_candidates/facts. No partial create/exit graph survives.

## Why no array/pointer grammar is added

No punctuation receives a type meaning. `*`, `&`, balanced `[]` and other punctuation
are witnesses of unsupported syntax. Matched groups remain opaque. No return type,
function declaration, macro replacement or include-spliced translation unit is built.
The LPC [types reference](../../reference/es2/mudlib/doc/lpc/types/general) and actual
`query_path`/`query_commands` in [command.c](../../reference/es2/mudlib/feature/command.c)
explain why punctuation is not evidence that a name already occurred; their grammar
is deliberately not implemented.

## Unknown-prefix state

DECLARATION_PREFIX_UNKNOWN retains the first unsupported authored token. Actual or
possibly directive-separated macro invocation is checked without resolving the
unsupported prefix. Macro terminal roles cannot close this unknown slot. Supported
prefix/empty roles retain their existing bounded authored cursor handling.
Definite literal residue still stops invocation ownership; a later ordinary name
cannot donate its call list to an earlier uninvoked function-only macro.

## Preprocessing interaction rule

The scanner retains a preprocessing witness while prefix structure is unresolved.
It refuses declaration-like continuation affected by that witness. A definite name
does not allow suffix macros to claim a second name. Semicolons and completed bodies
reset the unknown witness; punctuation alone does not. Existing inheritance state
and decision order are unchanged.

## Root primary closure

Before edits, the exact owner primary was freshly reproduced in LF and CRLF:
candidate=true, PARTIAL, ROOM metadata and inherit/name/exit facts. Both now refuse
before raw inheritance segmentation, dependency fallback or any fact allocation.
Root diagnostics use the actual unsupported prefix and preprocessing witness.

## Independent alias closure

The independent RESOLVE-to-TARGET primary likewise reproduced unsafe inherit/short/exit
facts before edits, in both newline forms. Both now fully refuse. No macro argument
substitution or returned terminal recovery is used to classify the unsupported prefix.

## Dependency early-preflight closure

Root, local, nested, standard, cross-header and nested-cross-header arrangements use
the same pre-segmentation gate. Every positive new CLI case also runs fact-allocation,
include-hazard and raw-inherit spies. Reaching any later stage fails acceptance.

## Dependency provenance

Findings for reached dependency structure anchor the root-authored include directive.
Header offsets are never applied to root bytes. Unreferenced dependencies have zero
effect. New root findings truthfully describe unsupported syntax; they do not claim
that a punctuation token has a particular LPC type meaning.

## No-preprocessing unknown-prefix controls

Unsupported punctuation alone does not create a new refusal. Literal helper bodies,
standalone directives before a declaration or after its completed body, and nested
or textual lookalikes retain frozen-parent behavior within the fixed oracles.

## Statement/body reset controls

Semicolon and completed-body cases do not carry unknown state into another declaration.
No-call controls preserve authored ownership barriers: `F / directive / ;` and
`F / directive / ordinary()` do not lend the later group to F.

## P2F27 invocation-barrier preservation

All 624 retained CLI cases pass: FR26 100, expanded 282, independent 56 and differential
186. All 15 P2F27 focused methods pass. The possible-call and directive-invocation
helpers are structurally unchanged, including no terminal analysis across the barrier.

## P2F26 role-classifier preservation

The direct-adjacent critical-role classifier is unchanged. P2F26 focused13, complete
prefix ownership and independent/expanded/consolidation matrices pass. MacroSummary
reach/effect and macro_regions remain unchanged. No new helper or parser is added.

## P2F25 inheritance preservation

Inheritance preflight, create-tail, mapping, exit staging, mutation finalizer and all
other existing methods remain unchanged. The complete retained P2F25/P2F24 and older
families pass, including P2F23 through P2F11 and earlier repairs.

## Original FR27 replay

All 81 audit CLI runs pass: six completed confirmations, 72 siblings, and three retained
preliminary inputs evaluated against full refusal. The earlier preliminary logger's
incorrect expectation that every failure leaked an exit was not used as an oracle.

## 72-CLI sibling replay

All 32 former failures are corrected. All 40 prior PASS executions remain within their
original oracle; full-refusal dependency cases clear metadata in the shared gate.
Parent-equivalence controls preserve both object and finding records.

## Expanded unknown-prefix matrix

334 fresh CLI pass across six punctuation forms, literal set/create, function/object
macros, empty/prefix/helper/unknown results, directive placements, multiple/conditional
directives, all dependency arrangements and negative/reset controls. Sources and
expectations were fixed before execution.

## Independent contract sweep

52 separately hand-authored CLI pass across supported/unknown helper prefixes,
literal critical names, object/function names, before-name directives, no-call
boundaries, statement/body reset and nested controls; root/dependency and LF/CRLF.
The matrix is not generated from product tests.

## No-widening gate

All 471 new CLI cases compare against the exact frozen P2F27 executable. An additional
47 actual product-test extraction calls compare against that same parent. All 785
root/dependency objects in the new CLI fixtures are independently compared too. No new
candidate, fact, exit or quarantine; no OUT_OF_SCOPE-to-PARTIAL/EXTRACTED transition.
The original 72 siblings also preserve their fixed equivalence/refusal expectations.

Two harness setup problems did not execute failed product acceptance: a missing bracket
in the oracle-author script, and Windows rejecting `*` in a fixture directory name.
The latter was corrected only in the filesystem label. No source/oracle changed and
no implementation was revised after executing the acceptance matrices.

## Version 1.0.28 and fresh test suites

Schema remains 1; profile remains static-room-v1. Known versions are exactly 1.0.0
through 1.0.28. Fresh pre-commit results:

| Gate | Result |
| --- | --- |
| New focused / P2F27 focused / P2F26 focused | 8 / 15 / 13 PASS |
| Earlier repair methods | 371 PASS |
| Full migration / full Python | 472 / 518 PASS |
| New P2F28 synthetic CLI | 471 PASS |
| Retained P2F27 CLI | 624 PASS |
| Earlier retained CLI | 5,422 PASS |
| Total synthetic CLI | 6,517 PASS |
| Product fixture parent comparisons | 47 PASS |
| Finalizer independence | 40 key traces + 12 probes PASS |
| Repository checks / diff whitespace | PASS |

## Compatibility

All 29 canonical historical output versions are freshly accepted and replaced through
the real CLI. Manual/reviewed/future/unknown/malformed/empty outputs and all 33 discovered
nested metadata dictionary positions fail with exit2 before writer invocation, preserving
the original target bytes.

## Output security

Full retained output-confinement and failure tests pass: protected repository/source/game/docs
targets, path escapes, external tracked checkout, approved build/external output, atomic-write
failure and invalid UTF-8 raw_hex. Symlink/junction path flags use the retained mocked tests;
this report does not claim a newly created native junction. CLI/writer code is unchanged.

## Corpus A/B

Two fresh complete scans are byte-identical; each exits 1 for the same 13 genuine
quarantines. 9,808,627 bytes each; SHA-256 `34b0a3965cf8c6ebdd5668af546d6371f70e5f84021141636a3c238e269d60e4`.

Scanned 2336; supported 485; statuses
`{"EXTRACTED": 0, "OUT_OF_SCOPE": 1838, "PARTIAL": 485, "QUARANTINED": 13}`; facts 2736; findings 4296.
Finding-code distribution: `{"CALLBACK_BEHAVIOR": 284, "DRIVER_SEMANTICS_UNKNOWN": 408, "DYNAMIC_EXPRESSION": 10, "ORDER_SENSITIVE_MUTATION": 30, "OUT_OF_SCOPE": 1319, "REQUIRES_SEMANTIC_REVIEW": 1623, "RNG_SEMANTICS": 58, "SOURCE_ENCODING_ISSUE": 8, "SOURCE_SYNTAX_ERROR": 5, "UNRESOLVED_INCLUDE": 97, "UNRESOLVED_INHERITANCE": 14, "UNSUPPORTED_CONSTRUCT": 440}`.

## Safety budget / semantic delta

Old supported 485; new supported 485; delta 0; affected paths none.
Exact frozen-parent projection has zero object/fact/finding delta; only extractor_version changes.

## 13 quarantines

All 13 source defects are freshly verified at their actual byte offsets: eight encoding
and five syntax cases. Exact reason/span and empty facts remain unchanged. There are
no new quarantines. This repair does not claim completion of the wider quarantine-path audit.

## 14 ANSI exclusions

All fourteen exact historical ANSI paths remain candidate=false, OUT_OF_SCOPE, facts=[].
The complete path list and per-path assertions are retained in the ignored delta receipt.

## Provenance / IDs / summary

All corpus provenance and normalization input spans, source hashes, raw/raw_hex, lines,
columns, fact/finding IDs, references, order and UNREVIEWED states are independently
checked. New structural fixtures additionally validate 1,996 provenance spans across
471 CLI documents. No replacement-derived token/span, ghost/orphan/duplicate fact ID
or dangling finding reference is introduced; summaries are recomputed exactly.

## Source authority and immutable source

Root/docs AGENTS, owner-locked [D1–D9](DECISIONS.md#migration-tooling-v1-p2--owner-locked-extraction-boundary),
the [preprocessor manual](../../reference/es2/mudlib/doc/concepts/preprocessor),
[define](../../reference/es2/mudlib/doc/lpc/preprocessor/define),
[include](../../reference/es2/mudlib/doc/lpc/preprocessor/include),
[function syntax](../../reference/es2/mudlib/doc/lpc/constructs/function), types and
[dbase setter](../../reference/es2/mudlib/feature/dbase.c) inform this bounded repair.
Python 3.12 standard library only. No gameplay/live-runtime acceptance applies.

Reference tree: `4106480ab28cce8cd7b55704f8ae9ae062d42d03`.
Raw 2,336-file manifest: `744e33e1740db7909129a3ae5e295158341b5012a411af953b144a5075bb0a80`.
No reference, game, save/runtime, workflow, lexer, CLI or DECISIONS change.

## ARCHIVE-01

ARCHIVE-01 remains CLOSED. All ten tracked audit hashes agree in HEAD, index and
worktree. P2F10 remains 24,417 bytes / 468 CRLF; `.gitattributes` raw SHA-256 remains
`b33913bb7279e1ab67762574ab277828a9fd114dae23dceace2f24ae842194d6`.

| File | Raw SHA-256 |
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

## Twenty-two owner-local evidence hashes

All remain untracked, unstaged and byte-identical, including the blocked P2F27 Final
Re-Audit. They are never included in the five-file staging list.

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
| `MIGRATION_TOOLING_V1_FINAL_RE_AUDIT_AFTER_P2F25.md` | `58e0e8258bfcbb6c0e07ae15a861121c68cb310b1bb36f7600d53a84844640cc` |
| `MIGRATION_TOOLING_V1_P2F26_MACRO_SUPPLIED_CRITICAL_FUNCTION_IDENTITY_PREFLIGHT_ATTEMPT1_BLOCKED.md` | `7f409e5b5c9e2a1040afba20bdcf1d809c583e5ef934a2848d21bb1fc5ecfced` |
| `MIGRATION_TOOLING_V1_P2F26_MACRO_SUPPLIED_CRITICAL_FUNCTION_IDENTITY_PREFLIGHT_ATTEMPT2_BLOCKED.md` | `af444e4a6022a1a823b1795d41fe4319e15aa4321dc5328e11da54bd8bec13a6` |
| `MIGRATION_TOOLING_V1_FINAL_RE_AUDIT_AFTER_P2F26.md` | `4ce54c97b12f70a450faa0c29f86672e5ecf3e9433c2b85cf52bfdafba65b7f4` |
| `MIGRATION_TOOLING_V1_P2F27_DIRECTIVE_TRANSPARENT_FUNCTION_MACRO_INVOCATION_PREFLIGHT_ATTEMPT1_BLOCKED.md` | `b79c6227c6a5cbce6e6c7ad130c0f0be1bbcea182ccc2f687075287ef40dab83` |
| `MIGRATION_TOOLING_V1_FINAL_RE_AUDIT_AFTER_P2F27.md` | `05ef64ab050959aa23653706a116cbcd1559d1ad94fa5e9b0d1b516bf7235305` |

## Residual boundaries

Unsupported prefix plus preprocessing can refuse harmless declarations. This is the
owner-authorized false-negative bias, not an implementation of LPC complex types.
Macro summaries are not macro execution; dependency summaries are not expanded units.
General grammar, execution, substitution, Native consumers and P3 remain outside scope.
No confirmed contract defect is reclassified as accepted residual risk.

## Owner gate

All pre-commit gates passed before STATUS/ROADMAP updates. Exactly one five-file commit
is authorized: `Refuse preprocessing-sensitive unsupported declaration prefixes`, with
the frozen P2F27 parent. Publication additionally requires every acceptance gate on
that immutable commit, including fresh A/B scans, compatibility/security, hashes,
documentation checks and five-file scope. Post-commit receipts and final SHA are
reported at completion; pre-commit evidence does not substitute.

Evidence stays ignored under `build/migration-tooling-v1/p2f28/`. Next Structural Final
Audit still requires owner review/authorization. Systematic Quarantine-Path Audit remains
INCOMPLETE. No PR, merge, remote CI, next Final Re-Audit or P3. Main is unchanged.
