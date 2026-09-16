# Migration Tooling v1 — P2F8 Resolved Include Semantic Hazards

**P2F8 FIX IMPLEMENTED — AWAIT OWNER REVIEW / FINAL RE-AUDIT NOT YET AUTHORIZED**

## 1. Authorization and frozen starting point

Owner authorized only FR7-01 repair on `phase/migration-tooling-v1`.
Fresh fetch/preflight confirmed local/origin phase `b10faeded5ddf39aefd136d0134bff81ca4446b5`,
subject `Fix raw echo directive semantics`; main/origin main/merge base
`cd07808cb76147d0b8c0dad9b82d078b49fefe64`. GitHub phase-branch PR search returned none.
Initial tracked/index delta zero; exactly six historical blocked audits untracked.

This is a correction implementation report, not a Final Re-Audit verdict. No PR, merge, P3, reference repair,
gameplay/Save/CI change or DECISIONS edit is authorized. One commit: `Fix resolved include semantic hazards`.
Commit identity and exact-commit rerun results are reported at task completion; this report cannot embed its own SHA.

## 2. FR7-01 root cause and source rationale

The previous include_hazards inspected critical define/undef directives and recursive include paths, but
ignored ordinary LPC declarations in resolved files. An included local set definition could therefore leave
root short/exit facts eligible, duplicate create could leave root create apparently unique, and included
inheritance could bypass reliable direct-ROOM admission.

[LPC include documentation](../../reference/es2/mudlib/doc/lpc/preprocessor/include) and
[preprocessor manual](../../reference/es2/mudlib/doc/concepts/preprocessor) describe textual inclusion.
The semantic compilation unit includes the header's declarations even though IR provenance must remain
attached to the authored object source. [std/room.c](../../reference/es2/mudlib/std/room.c) inherits F_DBASE;
[feature/dbase.c](../../reference/es2/mudlib/feature/dbase.c) defines the standard setter.
[dbase.h](../../reference/es2/mudlib/include/dbase.h) contains prototypes, which are not replacement definitions.
No external port, LPC runtime execution or complete preprocessor was used.

## 3. Bounded hazard-summary architecture

[room_extractor.py](../../tools/migration/room_extractor.py) adds included_structure_hazards:

- Existing byte-preserving lexer and pairs provide source-structural tokens/balancing.
- Scan top-level declarations; skip function bodies and grouped initializers. No raw-text regex searches.
- Function definitions named set/create yield those hazards; prototypes, ordinary functions and unrelated data do not.
- Any authored top-level inherit yields `included inherit`, regardless of base name/category.
- Unbalanced, unterminated or structurally interrupted include content becomes unresolved dependency context.

Recursive include_hazards unions this structural summary with existing ROOM/set/create/__DIR__ macro hazards
and unresolved include. Each dependency path is visited once per root. No source concatenation, synthetic root,
macro expansion, conditional execution, inherited-default resolution, or new IR fields.
Only room_extractor.py changes in production; es2_source.py and cli.py remain unchanged.

## 4. Resulting extraction boundaries

| Included content | Root candidate/status | Root facts |
| --- | --- | --- |
| set definition | true / PARTIAL | inherit only |
| create definition | true / PARTIAL | inherit only |
| any top-level inherit, including ROOM/NPC/ITEM/custom/literal | false / OUT_OF_SCOPE | [] |
| malformed/unresolvable dependency | false / OUT_OF_SCOPE | [] |
| harmless helper/data/prototype | true / PARTIAL | supported root facts retained |

No header inherit is copied into root direct_inherits. All root facts/findings retain root source SHA and raw
byte spans. Missing-target exit reference warnings remain descriptive; no new exit is manufactured.
The existing generic directive and unsupported-scope findings carry the conservative result; schema is unchanged.

## 5. Nested, repeated, cyclic and relative includes

Hazards propagate through multiple include levels. Quoted paths resolve against the including file's own directory;
angle paths retain the standard include namespace; missing targets and `..`/absolute escapes stay unresolved.
Explicit nested relative test includes a misleading root-relative safe file to catch incorrect path origin.

Cycles and repeated includes terminate via per-root visited paths; each visited declaration contributes to the
hazard union. Tests place hazards on either side of a cycle and compare deterministic results. Safe cycles alone
do not automatically block extraction. Include multiplicity is not used as evidence that a hazard is harmless.

Include placement before inherit, between inherit/create or after create is treated as compilation-unit context.
This intentionally conservative whole-source assessment does not simulate textual execution order.

## 6. Conditional and malformed dependency behavior

Balanced conditional branches are all inspected for potential set/create/inherit declarations, including #if 0;
no condition is evaluated. Ordinary header guards do not by themselves block admission.
If alternative branch structures cannot be balanced, the dependency is unresolved.
If a directive interrupts a declaration or function signature, the summarizer refuses to join different branch
fragments into an apparently harmless definition. This is conservative dependency rejection, not root corruption.

Malformed header strings/comments/braces/encoding or unterminated declarations block reliable root admission.
The root remains OUT_OF_SCOPE with dependency findings, never SOURCE_SYNTAX_ERROR merely because its dependency
failed. The header can independently be QUARANTINED as its own manifest entry; dedicated scan tests verify this.
Valid but unsupported complex conditional structure may thus reduce extraction coverage without falsely
quarantining the root. This is a bounded summary, not a complete LPC syntax validator.

## 7. False-positive controls and self-review

Comments, strings and heredocs mentioning set/create/inherit are opaque. Function-body identifiers/calls,
local variable set, functions setter/creator, helper functions, unrelated data and function prototypes remain allowed.
Tests also cover combinations: set+create, set+inherit, create+inherit, macro+set, macro+inherit;
the strongest applicable conservative boundary wins.

Distinct implementation self-review checked source ownership of provenance, no synthetic source assembly,
no root header-fact copying, cycle union behavior, path origin, conditional branch joining, and unchanged closed
schema. The split-signature protection and its regression test resulted from this review.
No change to D1–D9 or a blanket “all includes unsafe” shortcut.

## 8. Fresh actual include inventory

Fresh source-position-aware inventory of all 1,817 C/H files, using lexer/directive tokens and an independent
raw scanner for readable include positions in damaged files. Structural summaries apply only to safely lexed
included sources; no raw regex infers function/inherit hazards.

| Metric | Result |
| --- | ---: |
| Include occurrences / edges | 981 |
| Resolved edges | 945 |
| Unresolved edges | 36 |
| Unique resolved included files | 45 (37 headers, 8 .c files) |
| Nested edges from an included file | 24: 23 resolved, 1 unresolved |
| Observed cycles | 0 |
| Included files with top-level set definitions | 0 |
| Included files with top-level create definitions | 0 |
| Included files with top-level inherit | 8 |
| Malformed resolved included files | 0 |
| Existing ROOM candidates affected | 0 |

The eight inheritance-bearing included files are `std/weapon/axe.c`, `blade.c`, `dagger.c`, `fork.c`,
`hammer.c`, `staff.c`, `sword.c`, `whip.c`. Their conditional `inherit EQUIP` was directly checked in source;
the new summary does not assume that AS_FEATURE chooses the branch without that inheritance.
These dependencies do not change any currently supported ROOM object.
Critical macro hazard: include/globals.h defines ROOM. Transitive unresolved hazard: include/net/macros.h
includes missing include/uid.h. No included set/create/__DIR__ critical macro was observed.

The 24 nested edges are 16 weapon .c→weapon.h/dbase.h edges plus eight networking-header edges;
the latter comprise seven resolved edges and the uid.h miss. Unresolved total36 comprises:
flock.h1, config.h3, daemons.h2, uid.h6, post.h1, mailer.h2, priv.h1; eight absolute
`/adm/simul_efun/*.c` paths and twelve absolute `/doc/help.h` paths rejected under current path rules.
“Unresolved” includes unsupported path forms, not just physically missing files.

Ten corrupt C/H files cannot produce a complete lexer result. Raw-readable directive inventory includes
their available text but does not claim compiler semantics beyond corruption; malformed string tails remain opaque.
All 45 resolved included targets were safely lexed/summarized. No unsafe zero count was forced.

## 9. Fresh real CLI matrix

Independent subprocesses, temporary external sources/outputs, each row run under LF and CRLF: **20/20 PASS**.
Root includes hazard.h, inherits ROOM, and declares short plus __DIR__ exit. Header variants are independently authored.

| Header case | exit | candidate | status | fields | finding codes |
| --- | ---: | --- | --- | --- | --- |
| set | 0 | true | PARTIAL | inherit | REQUIRES_SEMANTIC_REVIEW, UNSUPPORTED_CONSTRUCT |
| create | 0 | true | PARTIAL | inherit | same |
| inherit ROOM | 0 | false | OUT_OF_SCOPE | [] | OUT_OF_SCOPE, UNRESOLVED_INHERITANCE |
| inherit NPC | 0 | false | OUT_OF_SCOPE | [] | same |
| inherit literal unknown | 0 | false | OUT_OF_SCOPE | [] | same |
| nested set | 0 | true | PARTIAL | inherit | REQUIRES_SEMANTIC_REVIEW, UNSUPPORTED_CONSTRUCT |
| nested create | 0 | true | PARTIAL | inherit | same |
| nested inherit | 0 | false | OUT_OF_SCOPE | [] | OUT_OF_SCOPE, UNRESOLVED_INHERITANCE |
| nested missing include | 0 | false | OUT_OF_SCOPE | [] | OUT_OF_SCOPE, UNRESOLVED_INCLUDE, UNRESOLVED_INHERITANCE |
| harmless helper | 0 | true | PARTIAL | inherit, short, exit | REQUIRES_SEMANTIC_REVIEW, UNSUPPORTED_CONSTRUCT, UNRESOLVED_REFERENCE |

The helper exit target is intentionally absent in the tiny fixture. All root provenance SHA/slices are verified;
no included inheritance appears in root direct_inherits. Separate formal regression CLI cases also check canonical output.

## 10. Tests and verification

Final pre-commit executable/test content results:

| Check | Fresh result |
| --- | --- |
| P2F8RegressionTests | 25 PASS |
| Explicit P2F8 + P2F1–P2F7 classes | 96 PASS (25 new + 71 prior) |
| Full migration suite | 161 PASS |
| Full Python suite | 207 PASS |
| repository/static checks | PASS |
| git diff --check | PASS |
| Independent real CLI matrix | 20 PASS |

P2F1 class is named AuditBlockerRegressionTests; P2F2–P2F7 classes retain their existing names.
Old output protection, continued macros, closed schema, authority exclusions, FR-01, FR5-01 and raw echo regressions
all ran explicitly. Existing tests changed only their current-version expectations/compatibility sets;
new behavior coverage lives in P2F8RegressionTests. Fixtures are unchanged.

Local results are not CI. No remote workflow or Godot gameplay suite was run; this pure parser/dependency correction
does not require live gameplay. Required exact-commit replay follows the single commit and is reported at completion.

## 11. Version and replacement security

EXTRACTOR_VERSION = 1.0.8; known versions exactly 1.0.0–1.0.8; schema_version=1, profile=static-room-v1.
Closed validation schema and CLI writer are unchanged.

All nine complete canonical corpus outputs were freshly tested for safe replacement by real CLI in temporary
external targets, including current1.0.8; historical originals unchanged. Independently generated small complete
documents were also tested across all nine versions.
33 actual generated dictionary nodes received unknown manual fields: **33/33 exit2, writer not called, bytes unchanged**.
The full suite retains reviewed/unknown/manual rejection and validates all nine version-tagged attacks.
Eight protected repository-target attacks were refused; approved ignored build and external output controls passed.
No schema loosening, manual-data stripping or cryptographic authorship claim.

## 12. Full corpus A/B, delta and determinism

Two fresh independent CLI runs against reference/es2:

| Metric | A | B |
| --- | ---: | ---: |
| exit | 1 | 1 |
| scanned | 2,336 | 2,336 |
| supported | 499 | 499 |
| EXTRACTED | 0 | 0 |
| PARTIAL | 499 | 499 |
| OUT_OF_SCOPE | 1,824 | 1,824 |
| QUARANTINED | 13 | 13 |
| facts | 2,804 | 2,804 |
| findings | 4,457 | 4,457 |
| bytes | 10,030,223 | 10,030,223 |

Both SHA-256: `15d6e81755956e6af05bf786d40728a4654a6cf4471a3a3cc32a46bfb823ce72`; full bytes equal.
Compared with the frozen P2F7 baseline (verified SHA
`1c5e3cbfdcf050a9d7236772aa5c5d409c6951a6fd30093908ea46e4f8b542f6`), every object/fact/finding/manifest/summary
is identical; only extractor_version changes. **Changed-object list: empty.** No number was preserved artificially.

Finding counts: CALLBACK_BEHAVIOR326, DRIVER_SEMANTICS_UNKNOWN410, DYNAMIC_EXPRESSION11,
ORDER_SENSITIVE_MUTATION36, OUT_OF_SCOPE1305, REQUIRES_SEMANTIC_REVIEW1713, RNG_SEMANTICS62,
SOURCE_ENCODING_ISSUE8, SOURCE_SYNTAX_ERROR5, UNRESOLVED_INCLUDE97, UNSUPPORTED_CONSTRUCT484.

## 13. Quarantine comparison

All 13 paths, source-error reasons and empty facts match P2F7 exactly; no root quarantine introduced by dependency inspection.

| Kind / reason | Paths under mudlib |
| --- | --- |
| Encoding: NUL or replacement character in source | cmds/std/exercise.c; d/choyin/npc/yamen_po.c; d/latemoon/upstar/upcenter.c; d/temple/npc/obj/magic_book.c; d/temple/npc/obj/spells_book.c; d/temple/obj/magic_book.c; d/temple/obj/spells_book.c; u/cloud/obj/npc/flower_girl/guihua.c |
| Syntax: unterminated string | d/latemoon/sroad1.c; u/cloud/npc/goddd.c |
| Syntax: mismatched delimiter | d/npc/oldman.c; d/village/lordhouse3.c; u/cloud/obj/sword_book.c |

This is a focused before/after comparison, not completion of the previous stopped final audit's broader manual sign-off.

## 14. Integrity and reference immutability

Independent byte checks cover all 9,838 corpus provenance records: 1,799 inherit, 2,804 fact,
4,457 finding, 778 normalization inputs. SHA, bounds, raw bytes, Unicode/CRLF line/column and fact IDs verified.
Manifest full coverage/sorting, IDs, summaries and finding references checked. No header bytes fabricated as root provenance.

Reference git tree: `4106480ab28cce8cd7b55704f8ae9ae062d42d03`.
2,336-source raw manifest SHA over sorted repository-relative paths:
`744e33e1740db7909129a3ae5e295158341b5012a411af953b144a5075bb0a80`.
Extractor-relative manifest SHA: `895d36086e184ba6bf520625c20e882394a0a6169aabf86a1b4c58ba835e2820`.
Reference/game/Save/CI/DECISIONS and the existing fixture files remain unchanged.

## 15. Six protected audit hashes

All remain untracked/unstaged; no historical audit is edited or linked as a committed report.
P2F7_BLOCKED_AUDIT_START_SHA is frozen from this task's first read.

| Basename under docs/migration | SHA-256 |
| --- | --- |
| MIGRATION_TOOLING_V1_FINAL_AUDIT.md | `a61cd221e8b70961d963484dfe953f5e341511967d9cfd66a55159b1bab85d63` |
| MIGRATION_TOOLING_V1_RE_FINAL_AUDIT.md | `c67dc612139bf37a6c6a41d4753b58723b154d0f6e92cdca0ab5a34ad93d0548` |
| MIGRATION_TOOLING_V1_FINAL_RE_AUDIT_AFTER_P2F4.md | `c4ff8faccea5b79d0ba4007d2d616007f4a55fda3b84e58e78875d68f4e4aed0` |
| MIGRATION_TOOLING_V1_FINAL_RE_AUDIT_AFTER_P2F5.md | `0d93333f8db116db7f6af0cb79e201b26228010cc5e85592adf30cdeb4c94be9` |
| MIGRATION_TOOLING_V1_FINAL_RE_AUDIT_AFTER_P2F6.md | `8a9ba2d9bfd666b949b470d872820c63d5adeab26d849deef7e4460b45593b76` |
| MIGRATION_TOOLING_V1_FINAL_RE_AUDIT_AFTER_P2F7.md | `939c23c9ac71749fc815cbfadcc147407d40024efe353edf0090971cdb5a9d38` |

## 16. File scope and exact-commit replay

Exactly five intended files: room_extractor.py, test_migration_tooling.py, this phase report,
[STATUS](../production/STATUS.md), [ROADMAP](../production/ROADMAP.md). Only explicit staging is authorized.
Ignored evidence/scripts stay under build/migration-tooling-v1/p2f8; no corpus, temporary fixture or audit report is staged.

After the single commit, rerun focused P2F8, explicit P2F1–P2F7, full migration/Python, static/diff,
independent CLI matrix, actual inventory, corpus A/B and quarantine comparison, source integrity and six audit hashes.
Then push the same phase branch, fetch, verify local=origin phase, frozen main, clean tracked/index and exactly six
untracked audits, and verify no phase PR. These actions are authorized closure of this correction only.

## 17. Owner boundary

FR7-01's specified include semantic hazards are addressed by the bounded summary and fresh checks above.
P2F7 remains CLOSED; its Final Re-Audit remains historical BLOCKED evidence. P2F8 is implemented and awaits owner review.
Another complete Final Re-Audit is required and **not yet authorized**. No automatic continuation into that audit,
PR, merge, P3, Native consumer or adjacent migration. No claim of full LPC grammar/preprocessor support or final milestone PASS.

**P2F8 FIX IMPLEMENTED — AWAIT OWNER REVIEW / FINAL RE-AUDIT NOT YET AUTHORIZED**
