# Migration Tooling v1 — P2F23

**P2F23 FIX IMPLEMENTED — AWAIT OWNER REVIEW / FINAL RE-AUDIT NOT YET AUTHORIZED**

## Authorization / frozen identities

FR22-01 / HIGH / D2-D3 only, on `phase/migration-tooling-v1`.
Pre-fix HEAD and fetched origin phase: `5ad40706f13d683c15b22019462b2415c8323c2f`, subject
`Guard macro-shadowed inherit keywords`. Frozen main/merge-base:
`cd07808cb76147d0b8c0dad9b82d078b49fefe64`. Fresh fetch and all-state PR search (none)
passed; tracked worktree/index were clean and thirteen owner-local reports were preserved.
Five authorized files only: extractor, migration tests, this report, STATUS and ROADMAP.

Authority consulted: [locked D1-D9](DECISIONS.md), original [preprocessor manual](../../reference/es2/mudlib/doc/concepts/preprocessor),
[define](../../reference/es2/mudlib/doc/lpc/preprocessor/define), [include](../../reference/es2/mudlib/doc/lpc/preprocessor/include),
[inherit](../../reference/es2/mudlib/doc/lpc/constructs/inherit) and
[globals.h](../../reference/es2/mudlib/include/globals.h). No external port, runtime execution or new migration decision.

## FR22-01 root cause

The blocked audit demonstrated that an empty macro prefix hides an authored excluded inheritance:

```c
#define EMPTY
inherit ROOM;
EMPTY inherit NPC;
void create(){ set("short", "unsafe mixed class"); }
```

Previously candidate=true / PARTIAL with ROOM and short facts, although the complete inheritance
structure was unreliable. Independent header DISCARD(42)/ITEM reproduced the same issue.
The unchanged historical P2F22 audit records 164 CLI runs and 36 unsafe admissions.
This repair freshly replays those exact FR22 source bytes and preserves all controls.

## Why statement-start-only inherit recognition was unsafe

Only i==start reached the original inherit parser. A preceding empty/inert macro sent the complete segment to unknown_top; macro_regions also saw a statement, and INERT yielded no inheritance hazard. An earlier ROOM declaration then admitted an incomplete inheritance subset.

## Unknown-top pre-admission safety gate

The new preprocessing_hidden_inherit_use helper inspects unknown_top statements after initial segmentation but before direct identification, include_hazards, excluded-category admission and fact allocation. It returns only two authored tokens: the prefix use and hidden top-level inherit. macro_regions is unchanged.

## Top-level depth rule

Matched authored call groups are skipped as opaque regions. inherit inside arguments, mappings, arrays or parenthesized argument expressions is not treated as a declaration. The helper requires a semicolon-terminated statement and does not cross directives.

## Pure preprocessing-prefix rule

Every prefix token must be an actual macro use or an immediately attached matched call group. Ordinary identifiers, numbers, strings, unrelated parentheses and intervening non-macro tokens stop recognition. Neutral replacements are not evaluated; the task explicitly permits conservative refusal based on actual use alone.

## Actual macro-use classification

The existing root/resolved-header MacroSummary definitions are reused. An object-like possibility is an actual use; a function-only definition needs a following authored matched opening parenthesis. Competing object/function possibilities are conservative. An uninvoked function-only name does not qualify.

## Invocation-group handling

Consecutive matched parentheses following an actual macro use remain opaque prefix material, including A()() and A()()(). This refusal gate does not prove callable expansion, generate tokens, reuse arguments or modify the P2F21 continuation engine.

## No macro expansion

The helper never calls MacroSummary.effect, reach or create_tail_effect to interpret the prefix. Mocked assertions prove refusal without those methods. Macro context is collected, not executed; no substitution, include splicing or expanded stream is created.

## No inherit recovery

No attempt is made to strip the prefix and parse NPC, ITEM, ROOM, a literal or a custom base. The authored keyword establishes uncertainty only; the expression is not recovered into inheritance metadata.

## Full-object refusal

OUT_OF_SCOPE / candidate=false / facts=[] / direct_inherits=[] / category_candidates=[]. The findings explain the uncertain root prefix and unrecovered authored inherit. No source quarantine is manufactured.

## Earlier-inheritance clearing

All prior direct inherit metadata and categories are cleared. Tests include multiple reliable inherits before the hidden declaration and hidden excluded inheritance before a later ROOM. Source ordering cannot restore admission.

## Fact-allocation safety

A fact() spy raises if allocation occurs. Tests with earlier inheritance, create text and exit declarations prove the gate returns before any inherit/create/exit fact allocation; there is no emit-then-remove rollback.

## Object/function prefix families

Object empty, function empty, opaque arguments, aliases, object-to-function, function-to-object, ambiguous possibilities and inert/neutral replacements are covered. No class-specific target recovery is required.

## Callable-style prefix groups

Two/three authored call groups are covered in original and expanded matrices; 1,100 adjacent groups are stress-tested. The authored cursor advances iteratively, without recursion or continuation expansion.

## Multiple prefixes

Empty object sequences, mixed function/object prefixes and combinations of independent callable-style groups are covered. A separate stress case contains 1,100 authored macro uses; all produce deterministic full refusal.

## Header/nested/standard/cross-header definitions

Local, nested, standard and cross-header macro/alias definitions are covered through existing traversal. Finding source_path/hash/spans remain root-authored, never header replacement bytes.

## Nonmacro prefix negative controls

ordinary_identifier, numeric, text and intervening nonmacro prefix cases retain their exact pre-edit object/finding records. Function-only definitions without invocation do not activate the helper. This does not broaden the parser into source validity checking.

## Nested-inherit negative controls

DROP(inherit NPC), mapping/array/parenthesized equivalents remain governed by existing unsupported-source policy. Their nested token cannot trigger the new gate.

## Statement-boundary controls

EMPTY; inherit ROOM remains candidate=true/PARTIAL under existing policy; EMPTY; inherit NPC remains OUT_OF_SCOPE with normal excluded inheritance metadata. These expectations were handwritten and validated on the frozen pre-edit executable. Define/undef/include/pragma/echo/conditional/unknown directive separations do not stitch prefix and keyword.

## Original FR22 sibling matrix

Fresh exact FR22: 46 CLI = primary2 + independent-header2 + handwritten-completion2 + original siblings40.
All **36 former unsafe admissions eliminated**; 10 controls preserve exact object/finding records.
The original twenty shapes retain their source bytes and expectations: sixteen repaired shapes
(32 LF/CRLF runs), four control shapes (8 runs). Original FR20/FR21 are separately rerun below.

## Expanded P2F23 matrix

46 handwritten shapes plus 3 stress shapes, LF and CRLF: **98 CLI PASS**.
Includes custom/literal/ROOM hidden inherits, ordering, multiple prefixes, headers, nonmacro/nested
negatives and directive/statement boundaries. Before editing the executable, 92 direct extractor
runs captured historical controls and checked handwritten expected statuses. After repair every
negative control matches its historical complete object/finding output; none was autoaccepted.
Focused methods separately prove allocation order, provenance, no expansion and stress determinism.

## FR21/P2F22 regressions

Original 46 CLI and expanded 82 CLI pass, including keyword actual-use refusal, uninvoked functions, genuine unterminated inherits, headers and clearing. All seven P2F22 methods pass. The keyword helper and narrow macro_structure_hazards skip are AST-identical to the parent.

## FR20/P2F21 regressions

Original 72 CLI, expanded 84 CLI and primary4 pass. All eight retained methods pass. CreateTailEffect, create_tail_effect and create_tail_uncertain_use are AST-identical; no continuation engine changes.

## P2F14/P2F15 regressions

The 492-CLI historical header/inherit/pending/tail matrix passes, including include/macro terminators, declaration and function boundaries, typed/untyped boundaries and multiple inheritance. Retained P2F14/P2F15 methods also pass.

## P2F17–P2F20 regressions

Original FR19 94 CLI, independent key matrix500, expanded key294 and primary4 pass;
40 finalizer-independence probes pass. Hidden expression family270 plus 12 finalizer probes,
expanded110 and FR18 family56 pass. Nested148 and mapping156 CLI pass. Exit staging/finalizer,
mapping, property/receiver classifier and flat registration are AST-identical to the parent.

## P2F1–P2F22 regressions

All 348 retained repair methods pass. Complete migration suite: **420 PASS**;
complete Python suite: **466 PASS**; focused P2F23: **7 PASS**.
All 31 pre-commit gate groups pass, including repository_checks and git diff --check.
The retained directive204 and delimiter118 CLI families also pass. Total repair/regression
CLI matrices: **2,878** (compatibility24 and corpus scans are separate).

## Version 1.0.23

EXTRACTOR_VERSION=1.0.23, KNOWN_EXTRACTOR_VERSIONS=1.0.0 through 1.0.23 (24). schema_version=1 and static-room-v1 are unchanged. Existing test changes outside P2F23 are only version assertions/compatibility lists.

## Compatibility

All 24 preserved canonical historical/current versions pass real CLI replacement. Unknown/future/manual/reviewed/malformed/empty outputs are rejected with exit2, no writer call and unchanged target bytes. Historical input output files remain unchanged.

## Output security

Full existing unit security suite and independent confinement/closed-schema probes pass, including protected paths, tracked checkout, symlink/junction and atomic failure coverage where supported. All 33 nested generated dictionary positions reject unknown metadata. Invalid UTF-8 raw_hex handling remains correct. CLI and writer are byte-identical to parent; no security-policy delta.

## Corpus A/B

Two independent full scans each return exit1 with byte-identical output.
Scanned 2336; supported 485.
Statuses: `{"EXTRACTED": 0, "PARTIAL": 485, "OUT_OF_SCOPE": 1838, "QUARANTINED": 13}`.
Facts 2736; findings 4296.
Bytes each: 9808627. SHA-256: `c12210cc8b9ccfbdadd19544701c691e2c27a3a6bc1abeac871479d539ebe962`.

Finding distribution: `{"CALLBACK_BEHAVIOR": 284, "DRIVER_SEMANTICS_UNKNOWN": 408, "DYNAMIC_EXPRESSION": 10, "ORDER_SENSITIVE_MUTATION": 30, "OUT_OF_SCOPE": 1319, "REQUIRES_SEMANTIC_REVIEW": 1623, "RNG_SEMANTICS": 58, "SOURCE_ENCODING_ISSUE": 8, "SOURCE_SYNTAX_ERROR": 5, "UNRESOLVED_INCLUDE": 97, "UNRESOLVED_INHERITANCE": 14, "UNSUPPORTED_CONSTRUCT": 440}`.

## Semantic delta

Fresh full-document comparison against stored exact-parent 5ad4070 output (receipt bound to that SHA) establishes zero semantic delta except extractor_version. No candidate/fact/inherit/status/quarantine/finding changes. No unexplained or assumed delta was accepted.

## 13 quarantines

Exact historical set remains 8 encoding and 5 syntax, with facts=[], unchanged diagnostics/spans and actual-byte verification. Encoding defects retain NUL/replacement bytes; syntax samples retain malformed quotes/unmatched delimiters. Actual source contexts were inspected. This is repair regression validation, not completion of the next systematic quarantine-path Final Re-Audit.

## 14 ANSI exclusions

All fourteen remain candidate=false / OUT_OF_SCOPE / facts=[] / not QUARANTINED, checked individually from the historical path list. No ANSI evaluation added.

## Provenance / ID integrity

New rejection findings anchor only the root prefix token and root inherit token, with UTF-8 and
CRLF span/hash/line checks. No replacement or synthetic token provenance. The fresh whole-corpus
validation checks raw/raw_hex, SHA, spans, line/column, normalization inputs, fact-ID formula and
uniqueness, finding IDs/references/order, UNREVIEWED and exact summaries. Counts:
`{"crlf_source_records": 3, "direct_inherit_provenance": 1799, "fact_provenance": 2736, "finding_provenance": 4296, "normalization_input_provenance": 756, "provenance_records": 9587, "unicode_span_records": 1239, "unreviewed_records": 7032}`. Unaffected facts retain exact parent IDs/provenance.

## ARCHIVE-01

CLOSED. All ten tracked historical raw hashes match frozen values. P2F10 remains 24,417 bytes / 468 CRLF / SHA-256 `56e1cd0aa0a573bc4a9505fb5df6bd1cfbd0076849a40f6bd4a4420483cb2213`; tracked P2F11 `48f07085604905ef3d603474bae86fb028cff9bbc1088a83769eee16babe9155`. .gitattributes remains `b33913bb7279e1ab67762574ab277828a9fd114dae23dceace2f24ae842194d6`; no archive edit.

## Thirteen owner-local report preservation

All thirteen reports through P2F22 remain untracked, unstaged and byte-identical to the owner-frozen hashes. P2F22 SHA-256: `8f18f5f0afe438c117554fd35b4f2bcb229c13fd3b6a11db47ec3f3a91372bc9`. Reference tree remains `4106480ab28cce8cd7b55704f8ae9ae062d42d03`; raw 2,336-file manifest `744e33e1740db7909129a3ae5e295158341b5012a411af953b144a5075bb0a80`. No source/game/runtime/schema/.github/DECISIONS changes.

## Residual boundaries

This bounded refusal gate concerns only a terminated unknown top-level segment with a pure actual-macro
prefix and authored top-level inherit. It does not normalize source, interpret replacement results,
recover declarations or redesign region parsing. Definite nonmacro prefixes and nested inherit tokens
remain under prior policy. This permitted conservatism may reject harmless macro prefixes; it does not
introduce support for expanded LPC. No confirmed contract defect is accepted as residual risk.

Distinct AST self-review permits only extract_structure changes and the new helper among methods;
all module functions, macros/enum classes, keyword gate, create-tail and exit safety remain identical.
Pure parser/tooling work: Godot live gameplay validation is not required or claimed.

## Owner gate

P2F22 is CLOSED. Its Final Re-Audit remains historically BLOCKED on FR22-01. P2F23 is implemented;
owner review and separately authorized next Complete Final Re-Audit remain required. The systematic
quarantine-path audit remains **INCOMPLETE** and mandatory in that next audit. No milestone PASS.

This report records pre-commit validation. Create one commit `Guard preprocessing-sensitive inherit prefixes`
with parent 5ad4070, then rerun all 31 required gates on the immutable resulting SHA before push.
Exact-SHA receipts retain the post-commit results; the report is not amended to embed its own SHA.
Only after those pass is the same phase branch pushed. No PR, merge, remote CI, P3 or next Final Re-Audit.
The phase is not integrated on main. Stop for owner review after verified push.
