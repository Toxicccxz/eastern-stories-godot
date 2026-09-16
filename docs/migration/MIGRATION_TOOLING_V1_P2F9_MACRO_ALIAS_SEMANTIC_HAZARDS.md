# Migration Tooling v1 — P2F9 Macro Alias Semantic Hazards

**P2F9 FIX IMPLEMENTED — AWAIT OWNER REVIEW / FINAL RE-AUDIT NOT YET AUTHORIZED**

## Authorization and frozen baseline

This is the authorized implementation/verification correction for **FR8-01 / HIGH** after
the blocked Final Re-Audit after P2F8. It is not another Final Re-Audit or a milestone PASS.
P2F8 is CLOSED; P2F9 awaits owner review. Another complete Final Re-Audit requires separate
owner authorization. No PR, merge, P3, NPC/item extraction or Native generation is authorized.

- Owning branch: `phase/migration-tooling-v1`.
- Pre-fix local and fetched remote phase: `12a02e7fd989f40cb7da7059de74e9560b077c59`.
- Local/fetched main and merge base: `cd07808cb76147d0b8c0dad9b82d078b49fefe64`.
- Preflight: tracked/index clean, exactly seven blocked audits untracked, no phase PR (all states).
- Authorized single commit subject: `Fix macro alias semantic hazards`.
- Scope: extractor, its tests, this report, STATUS and ROADMAP only.

## Source authority and defect

The [ES2 LPC preprocessor manual](../../reference/es2/mudlib/doc/concepts/preprocessor)
defines object-like `#define identifier token_sequence`, function-like parameter replacement,
include behavior, conditional compilation and undef. Macro identifiers can change a declaration's
meaning even if the critical word does not appear as the macro's own name. Tooling must recognize
this reliability hazard without executing the preprocessor.

Consulted the authoritative [globals](../../reference/es2/mudlib/include/globals.h),
[weapon](../../reference/es2/mudlib/include/weapon.h) and
[armor](../../reference/es2/mudlib/include/armor.h) declarations for the existing exact base boundary.
Actual simple edges were checked in [net/config](../../reference/es2/mudlib/include/net/config.h),
[net/ftpdconf](../../reference/es2/mudlib/include/net/ftpdconf.h) and
[runtime_config](../../reference/es2/mudlib/include/runtime_config.h).
All source remains read-only. No gameplay substitution or DECISIONS change.

The P2F8 blocker has `#define LOCAL_SET set` and a function authored as `LOCAL_SET(...)`
in a resolved header. The previous direct-name check overlooked its setter identity and emitted
short/exit facts from the root create. Hidden create and inherit identities and macro-defined
inherit operands are the sibling cases addressed here.

## Bounded summary architecture and self-review

1. Preserve the existing directive analysis view (line-splice handling and original-byte error
   mapping). Retain its token kinds/offsets internally to distinguish object-like versus
   function-like definitions by adjacency. Raw echo payload never enters that view.
2. Collect root and reachable explicit includes before classification. Keep each original file's
   token array separate. Union definitions across nested, sibling and root/header boundaries;
   no order, condition, undef or include-guard execution. Repeated/cyclic includes terminate.
3. `MacroSummary` retains replacement identifier dependencies and exact excluded literal bases.
   Its iterative graph walk follows arbitrary finite alias chains, retains critical tokens in
   complex sequences, and detects cycles by leaf removal. There is no recursive expansion.
4. Inspect authored top-level declaration/function prefixes and inherit operands using balanced
   structure. Skip actual function bodies, comments, strings, heredocs and raw echo payload.
   Mere definition of an unused critical alias is not a function/ROOM hazard.
5. Feed semantic hazards into the existing admission/create reliability gates. No IR fields,
   synthetic facts, rewritten tokens, copied hidden inherits or provenance changes.

Root and include analysis use the same compilation-unit summary. Original P2F8 include structural
checks remain, including the case where an include cycle returns to the root: its declarations
are still included hazards. Malformed/unresolvable included structure blocks admission without
quarantining otherwise valid root bytes. Original direct define/undef hazards on ROOM, set,
create and __DIR__ remain in force.

| Authored structural context | Policy/result |
| --- | --- |
| Function name/prefix may reach set/create | Suppress create facts; reliable direct ROOM stays candidate/PARTIAL, inherit only |
| Top-level alias may become inherit | candidate=false, OUT_OF_SCOPE, no facts; do not add hidden direct_inherits |
| Authored inherit operand uses a defined macro | Block admission even for ROOM, NPC, ITEM, custom/unknown or literal base |
| Function-like/complex/cyclic identity cannot be classified | Conservatively suppress affected identity; possible whole declaration/inherit blocks admission |
| Single-identifier helper alias, including chains | No set/create hazard |
| Unused critical alias or COLOR/red | Does not independently block facts |
| Function-body mention / opaque payload | Not a top-level declaration use |
| D aliases __DIR__, exit target begins with D | Dynamic/no exit fact; never manufacture STATIC_NORMALIZED output |
| Root conditional compilation | Existing OUT_OF_SCOPE policy; no branch evaluation |
| Conditional definition in resolved header | Union possible definitions; critical uses still blocked |

Single-identifier aliases have bounded known identity; other replacement forms are uncertain.
Top-level unsupported declaration sequences are conservatively inspected as possible declaration
contexts. No general function-like argument substitution, token pasting, expression evaluation,
driver auto-include execution, runtime emulation or regex search of raw source is added.
Implicit driver globals retain the previously approved profile's authored ROOM/exact-base boundary;
this patch does not reinterpret the whole driver environment.

## Regression and CLI evidence

`P2F9RegressionTests` covers simple/chained set/create/inherit, all six required operand targets
and chains, all 34 exact excluded literal bases, includes/nested includes, root/sibling/header
propagation, conditional union, undef/redefinition, cycles, function-like/complex/token-paste
uncertainty, unused/helper/color controls, opaque/body negatives, DIR aliases, direct critical
policy, LF/CRLF, original-byte provenance and an actual 28-case external-temporary-directory CLI
matrix. A further regression preserves include-cycle-to-root behavior.

Fresh pre-commit checks (all LOCAL, none represents remote CI):

| Check | Result |
| --- | --- |
| P2F9 focused | 27 tests PASS |
| Explicit P2F1–P2F8 classes | 96 tests PASS |
| Full migration discovery | 188 tests PASS |
| Full Python discovery | 234 tests PASS |
| repository_checks.py --repository . | PASS |
| git diff --check | PASS |

The previous classes are explicitly rerun: AuditBlockerRegressionTests and P2F2 through P2F8.
These retain output confinement, direct macro shadow, closed schema, authority exclusions,
FR-01, FR5-01, raw echo and resolved include behavior.

An independent real CLI sweep covers 15 families in seven layouts: inline, combined header,
nested combined header, split headers, root macro/header declaration, header definition/root use,
and nested header definition/root use. Every layout runs with LF and CRLF in external
TemporaryDirectory source/output roots. All 210 invocations exit0; zero unsafe short/exit facts.
Below records representative inline results; the saved per-case evidence includes all seven
layouts, newlines, raw source hashes, exit/candidate/status/fields and exact finding codes.

| Family | Exit | Candidate | Status | Facts | Finding codes |
| --- | --- | --- | --- | --- | --- |
| set alias | 0 | true | PARTIAL | inherit | CALLBACK_BEHAVIOR, REQUIRES_SEMANTIC_REVIEW, UNSUPPORTED_CONSTRUCT |
| create alias | 0 | true | PARTIAL | inherit | CALLBACK_BEHAVIOR, REQUIRES_SEMANTIC_REVIEW, UNSUPPORTED_CONSTRUCT |
| inherit keyword alias | 0 | false | OUT_OF_SCOPE | none | OUT_OF_SCOPE, UNRESOLVED_INHERITANCE |
| create alias chain | 0 | true | PARTIAL | inherit | CALLBACK_BEHAVIOR, REQUIRES_SEMANTIC_REVIEW, UNSUPPORTED_CONSTRUCT |
| inherit alias chain | 0 | false | OUT_OF_SCOPE | none | OUT_OF_SCOPE, UNRESOLVED_INHERITANCE |
| NPC operand alias | 0 | false | OUT_OF_SCOPE | none | OUT_OF_SCOPE, UNRESOLVED_INHERITANCE |
| ITEM operand alias | 0 | false | OUT_OF_SCOPE | none | OUT_OF_SCOPE, UNRESOLVED_INHERITANCE |
| set alias chain | 0 | true | PARTIAL | inherit | CALLBACK_BEHAVIOR, REQUIRES_SEMANTIC_REVIEW, UNSUPPORTED_CONSTRUCT |
| declaration macro control | 0 | false | OUT_OF_SCOPE | none | OUT_OF_SCOPE |
| function macro control | 0 | false | OUT_OF_SCOPE | none | OUT_OF_SCOPE |
| direct set control | 0 | true | PARTIAL | inherit | CALLBACK_BEHAVIOR, REQUIRES_SEMANTIC_REVIEW, UNSUPPORTED_CONSTRUCT |
| direct create control | 0 | true | PARTIAL | inherit | REQUIRES_SEMANTIC_REVIEW, UNSUPPORTED_CONSTRUCT |
| direct inherit control | 0 | false | OUT_OF_SCOPE | none | OUT_OF_SCOPE |
| unused alias control | 0 | true | PARTIAL | inherit, short, exit | CALLBACK_BEHAVIOR, REQUIRES_SEMANTIC_REVIEW, UNRESOLVED_REFERENCE, UNSUPPORTED_CONSTRUCT |
| ordinary alias control | 0 | true | PARTIAL | inherit, short, exit | CALLBACK_BEHAVIOR, REQUIRES_SEMANTIC_REVIEW, UNRESOLVED_REFERENCE, UNSUPPORTED_CONSTRUCT |

The combined/declaration macro cases may be OUT_OF_SCOPE rather than inherit-only because the
authored structure does not contain an independently identifiable declaration boundary; no
macro is expanded to recover one. This is intentional conservative refusal.

## Fresh actual C/H inventory

The inventory lexes 1,817 actual C/H files: 1,807 lexable; 10 unavailable (8 encoding, 2 lexical
syntax). It does not count unavailable bytes as zero macro occurrences. Four additional lexable
files have unbalanced aggregate structure for positional inventory (one conditional daemon and
three of the existing syntax quarantines). The full inventory records their paths and reasons.

| Measurement | Fresh result |
| --- | --- |
| Definitions in lexable C/H files | 686 |
| Object-like / function-like | 639 / 47 |
| Simple identifier alias edges | 6 |
| Multi-edge simple chains / cycles | 0 / 0 |
| Replacement paths reaching set / create / inherit / ROOM / __DIR__ | 0 / 0 / 0 / 0 / 0 |
| Macro definitions reaching exact excluded literal bases | 34 |
| Critical replacement uses: top-level function name / statement start / inherit operand | 0 / 0 / 915 |
| New macro hazards among previous supported candidates | 0 |
| Changed supported candidates / changed objects | 0 / 0 |

Reach counts concern replacement paths, not reflexively counting a name as its own alias.
The 34 definitions are the existing standard base constants. Their 915 authored inherit uses
are real inventory observations, not a claim that all global definitions are explicitly included
or active in every compilation unit. The six simple identifier edges below reach no critical
identity; critical positional uses of those six are zero. Global possible-definition union is
used only for this inventory; production uses each resolved compilation unit's definitions.

| Source | Alias edge |
| --- | --- |
| `include/net/config.h:55` | `TCP_SERVICE_LEVEL -> TCP_ALL` |
| `include/net/config.h:63` | `PREF_MAIL -> SVC_TCP` |
| `include/net/config.h:64` | `PREF_FINGER -> SVC_TCP` |
| `include/net/config.h:65` | `PREF_TELL -> SVC_UDP` |
| `include/net/ftpdconf.h:50` | `THE_VERSION -> __VERSION__` |
| `include/runtime_config.h:21` | `BASE_CONFIG_STR -> RUNTIME_CONFIG_BASE` |

## Version and output compatibility

EXTRACTOR_VERSION is `1.0.9`; known generated versions are `1.0.0` through `1.0.9` inclusive.
Schema remains `1`. Fresh copies of complete canonical corpus outputs for all ten versions were
recognized and replaced through the actual CLI (exit0), leaving the historical originals intact.
Unknown/future-version, reviewed, manual, empty and malformed outputs returned exit2, writer not
called, bytes unchanged. The independent closed-schema sweep tested all 33 dictionary locations
for nested manual fields with the same refusal. Eight forbidden output-location probes and a
tracked file in another temporary checkout remain rejected. Approved build/external destinations
work; an invalid-UTF-8 raw_hex probe retains exact bytes. CLI and es2_source.py remain unchanged.

## Full corpus A/B and comparison

Both independent commands use the full `reference/es2` input and profile `static-room-v1`.
Both exit1 because source quarantine remains explicit; this is not an extraction crash.

| Measurement | A | B |
| --- | --- | --- |
| Exit | 1 | 1 |
| Scanned | 2336 | 2336 |
| Supported | 499 | 499 |
| EXTRACTED | 0 | 0 |
| PARTIAL | 499 | 499 |
| OUT_OF_SCOPE | 1824 | 1824 |
| QUARANTINED | 13 | 13 |
| Facts | 2804 | 2804 |
| Findings | 4457 | 4457 |
| Bytes | 10030223 | 10030223 |

A SHA-256 = B SHA-256 = `b37608464f7cb6b74cfc3a1358c5bfb98e29c77aebb05c5041a644833d18a4fd`; bytes are identical.

Against frozen P2F8 version1.0.8 output, every object, fact, finding, source manifest and quarantine
record is equal. Only extractor_version changes. Thus the per-changed-object path/before/after/
reason/macro-evidence list is empty, established by structural JSON comparison rather than totals.
All 9,838 provenance records were independently checked against original source bytes, hashes,
line/column and stable fact IDs, including 778 normalization inputs, 1,295 Unicode spans and
3 CRLF-source records. No synthetic provenance appears.

| Finding code | Count |
| --- | --- |
| CALLBACK_BEHAVIOR | 326 |
| DRIVER_SEMANTICS_UNKNOWN | 410 |
| DYNAMIC_EXPRESSION | 11 |
| ORDER_SENSITIVE_MUTATION | 36 |
| OUT_OF_SCOPE | 1305 |
| REQUIRES_SEMANTIC_REVIEW | 1713 |
| RNG_SEMANTICS | 62 |
| SOURCE_ENCODING_ISSUE | 8 |
| SOURCE_SYNTAX_ERROR | 5 |
| UNRESOLVED_INCLUDE | 97 |
| UNSUPPORTED_CONSTRUCT | 484 |

## Quarantine and source integrity

All 13 quarantine paths, reasons, spans and empty facts match P2F8: 8 encoding and 5 syntax.
No macro semantic hazard created a root SOURCE_SYNTAX_ERROR.

| Path | Code / reason |
| --- | --- |
| `cmds/std/exercise.c` | SOURCE_ENCODING_ISSUE: NUL or replacement character in source |
| `d/choyin/npc/yamen_po.c` | SOURCE_ENCODING_ISSUE: NUL or replacement character in source |
| `d/latemoon/sroad1.c` | SOURCE_SYNTAX_ERROR: unterminated string |
| `d/latemoon/upstar/upcenter.c` | SOURCE_ENCODING_ISSUE: NUL or replacement character in source |
| `d/npc/oldman.c` | SOURCE_SYNTAX_ERROR: mismatched delimiter |
| `d/temple/npc/obj/magic_book.c` | SOURCE_ENCODING_ISSUE: NUL or replacement character in source |
| `d/temple/npc/obj/spells_book.c` | SOURCE_ENCODING_ISSUE: NUL or replacement character in source |
| `d/temple/obj/magic_book.c` | SOURCE_ENCODING_ISSUE: NUL or replacement character in source |
| `d/temple/obj/spells_book.c` | SOURCE_ENCODING_ISSUE: NUL or replacement character in source |
| `d/village/lordhouse3.c` | SOURCE_SYNTAX_ERROR: mismatched delimiter |
| `u/cloud/npc/goddd.c` | SOURCE_SYNTAX_ERROR: unterminated string |
| `u/cloud/obj/npc/flower_girl/guihua.c` | SOURCE_ENCODING_ISSUE: NUL or replacement character in source |
| `u/cloud/obj/sword_book.c` | SOURCE_SYNTAX_ERROR: mismatched delimiter |

Reference tree remains `4106480ab28cce8cd7b55704f8ae9ae062d42d03`.
The sorted repository-relative path/NUL/raw-SHA/LF manifest of all 2,336 reference files remains
`744e33e1740db7909129a3ae5e295158341b5012a411af953b144a5075bb0a80`.
Reference, game/Save, CI, fixtures, DECISIONS, cli.py and es2_source.py are unchanged.
This pure parser/tooling correction has no live gameplay acceptance criterion; Godot live validation
was not run and no runtime proof is claimed.

## Seven frozen blocked audits

All seven stay untracked, unstaged, byte-identical. They are historical BLOCKED evidence,
not this fix report's commit content. The seventh task-start digest is
`P2F8_BLOCKED_AUDIT_START_SHA = 0734b90e65cb05d0ff4fd9eb701871234472f608b4350f48460b2e63fef12419`.

| Filename under docs/migration | SHA-256 |
| --- | --- |
| `MIGRATION_TOOLING_V1_FINAL_AUDIT.md` | `a61cd221e8b70961d963484dfe953f5e341511967d9cfd66a55159b1bab85d63` |
| `MIGRATION_TOOLING_V1_FINAL_RE_AUDIT_AFTER_P2F4.md` | `c4ff8faccea5b79d0ba4007d2d616007f4a55fda3b84e58e78875d68f4e4aed0` |
| `MIGRATION_TOOLING_V1_FINAL_RE_AUDIT_AFTER_P2F5.md` | `0d93333f8db116db7f6af0cb79e201b26228010cc5e85592adf30cdeb4c94be9` |
| `MIGRATION_TOOLING_V1_FINAL_RE_AUDIT_AFTER_P2F6.md` | `8a9ba2d9bfd666b949b470d872820c63d5adeab26d849deef7e4460b45593b76` |
| `MIGRATION_TOOLING_V1_FINAL_RE_AUDIT_AFTER_P2F7.md` | `939c23c9ac71749fc815cbfadcc147407d40024efe353edf0090971cdb5a9d38` |
| `MIGRATION_TOOLING_V1_RE_FINAL_AUDIT.md` | `c67dc612139bf37a6c6a41d4753b58723b154d0f6e92cdca0ab5a34ad93d0548` |
| `MIGRATION_TOOLING_V1_FINAL_RE_AUDIT_AFTER_P2F8.md` | `0734b90e65cb05d0ff4fd9eb701871234472f608b4350f48460b2e63fef12419` |

## Exact-commit gate and owner handoff

This report records pre-commit verification. After the one authorized commit, repeat focused,
P2F1–P2F8, full migration/Python/static, diff, CLI matrix, inventory, corpus A/B, quarantine,
reference and seven audit checks on that exact commit before pushing. Recheck documentation
links/anchors and canonical output compatibility too. Exact commit/run receipts are retained
under ignored `build/migration-tooling-v1/p2f9/post-*` and reported in the owner handoff; this
committed report does not prospectively claim those executions have already passed.

Local evidence is under ignored `build/migration-tooling-v1/p2f9/`: pre/post verification logs,
CLI per-case JSON, macro inventory, A/B outputs and corpus/provenance/quarantine evidence,
output-security/ten-version compatibility results and frozen audit/source integrity receipts.
These disposable probes are not production code or committed fixtures.

Push only the phase branch after the exact-commit checks. Fetch and confirm local HEAD equals
remote phase; frozen main remains unchanged; tracked/index clean; exactly seven blocked audits
untracked; no phase PR. No remote integration CI is run or claimed. The milestone remains
unintegrated on main and awaits owner review plus authorization for another complete Final Re-Audit.
