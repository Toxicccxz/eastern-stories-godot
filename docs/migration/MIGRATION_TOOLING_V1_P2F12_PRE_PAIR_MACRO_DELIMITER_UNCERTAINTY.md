# Migration Tooling v1 — P2F12: Pre-pair macro / preprocessor delimiter uncertainty

**P2F12 FIX IMPLEMENTED — AWAIT OWNER REVIEW / FINAL RE-AUDIT NOT YET AUTHORIZED**

## Authorization / frozen identities

Owner authorization is limited to FR11-01 / blocking MEDIUM / D9, its bounded siblings,
one implementation commit, exact-commit verification and phase-branch push.
This report records implementation verification, not a new Final Re-Audit.

| Identity | Frozen value |
| --- | --- |
| Branch | `phase/migration-tooling-v1` |
| Pre-fix HEAD / origin phase | `77751c680383cd31bc87b2dbd7224c67326ffa0e` |
| Previous executable implementation | `301fc35e9e719c6838c336aefb5054f7ccee4bde` |
| Main / origin main / merge base | `cd07808cb76147d0b8c0dad9b82d078b49fefe64` |
| Reference tree | `4106480ab28cce8cd7b55704f8ae9ae062d42d03` |

Preflight fetched origin, checked these identities, inspected 24 history entries, and
confirmed a clean tracked worktree/index and no phase PR in any state. The sole expected
untracked file was the owner-local FR11 blocked rerun report described below.
Only the extractor, migration tests, this report, STATUS and ROADMAP belong in the commit.

## FR11-01 root cause

An object macro such as `#define OPEN {` can supply an opening delimiter used by
`void create() OPEN ... }`. Authored tokens alone contain an unmatched closing brace.
That imbalance does not positively establish source corruption while actual preprocessing
can affect the delimiter structure. The old code quarantined it before examining macro use.

## Old failure ordering

The old order was lexing, root conditional policy, authored `pairs()`, structure extraction,
then include/macro hazard classification. The premature pairing exception produced
`SOURCE_SYNTAX_ERROR`, `QUARANTINED`, and CLI exit 1 for this preprocessing-dependent family.

## New pre-pair gate

The gate is lazy despite its name: it runs only when root authored `pairs()` raises
`SourceError`. Successful pairing still calls the existing `extract_structure()` path.
After a pairing failure, an actual pairing-uncertain macro use causes conservative refusal;
without that evidence the original exception is re-raised with its original reason and span.
Root conditional handling remains before pairing. Encoding and lexical failures retain
their earlier error path and never reach this gate.

## Why this is not macro expansion

The gate reuses tokenized definitions and identity dependencies in `MacroSummary`.
It does not replace identifiers, synthesize delimiters or an expanded token stream,
concatenate header/root source, substitute arguments, run cpp/LPC, or evaluate conditions.
The legacy reference consulted is the local LPC preprocessor documentation:
`reference/es2/mudlib/doc/lpc/preprocessor/{README,define,include}` and
`reference/es2/mudlib/doc/concepts/preprocessor`. No gameplay rule is being migrated.

A separate implementation self-review compared old/new ASTs. Only the existing
`include_hazards()` and `extract()` methods changed; all other existing method bodies
remain identical. The original include collection statements and subsequent analysis loop
are identical after extracting the collector. Three narrowly scoped methods were added.
Their ASTs contain no eval/exec/compile or Token construction; direct code inspection
confirms no substitution, execution, source concatenation or argument evaluation.

## Pairing-relevant macro classification

`MacroSummary.pairing_uncertain(name, invoked)` answers only whether this use makes an
authored pairing error unreliable. It does not reuse the broader structural-effect flag
as a blanket waiver. Replacement delimiter failure, invoked function macros, reachable
cycles and uncertain token-pasted identities can prevent proof of pairing neutrality.
Every possible definition participates in the union. Lone `;` and `#` remain neutral.

## Actual-use detection

Only root identifier tokens whose names have collected definitions are considered.
Definition presence alone is insufficient. The gate returns the original root-use token,
which anchors both findings. Function-like definitions require invocation context.

## Object-like macros

The existing `pairs(replacement)` checks authored replacement tokens without expansion.
Unbalanced `{`, `}`, `(`, `)`, `[` and `]` replacements are pairing-relevant. Balanced
ordinary replacements are neutral unless an identifier dependency introduces uncertainty.
Adjacent token-paste markers with identifier operands are conservatively uncertain because
the resulting macro identity is not represented by a literal dependency edge; no pasted
identifier is computed. A lone hash does not activate that rule.

## Alias chains

The iterative graph follows identifier dependencies across possible definitions, carrying
whether a dependency is followed by `(` or is the trailing alias receiving the root call.
It handles aliases to opening/closing delimiters and invoked function macros. A 1,100-link
chain verifies that traversal does not depend on Python recursion depth.

## Function-like macros

Actual invocations are conservatively uncertain: preprocessing can introduce delimiters or
remove/replace delimiter-bearing arguments, including empty `DROP(x)` replacements and
invalid signatures. Tests cover structural replacements, parameter-dependent replacement,
argument removal, aliases and invocation inside an object replacement. Bare function names
and uninvoked definitions do not by themselves mask real corruption.

## Cycles / competing definitions

Iterative leaf removal detects reachable cycles without recursive expansion. Used cycles
make pairing unprovable; unused cycles have no effect. Competing definitions are unioned,
not resolved by last-definition-wins or condition evaluation. One relevant alternative is
sufficient; competing neutral alternatives retain the original syntax failure.

## Included macro definitions

`macro_context()` shares the existing directive scan, bounded include resolution, recursive
unit discovery and `MacroSummary.add()` collection. The normal include hazard analysis
continues after that same collector. Direct, nested and sibling headers, cross-file aliases,
function macros, include cycles and conditional header definitions are covered.
Safe, missing, empty, malformed or unused-dangerous includes alone do not excuse imbalance.
There is no any-include-to-OOS shortcut and no header source splicing.

## Unused-dangerous controls

All six delimiter families define a dangerous macro but never use it in genuinely malformed
source. Both LF and CRLF forms remain quarantined. Unused cycles and function definitions
also preserve the original error.

## Inert controls

Used number, string, character, semicolon, lone hash, balanced braces/parentheses/brackets
and ordinary expression replacements do not hide a separate real delimiter defect.

## Opaque-token controls

Comments, strings, character/quoted-symbol tokens, heredocs, raw echo payloads and unused
directive replacement text do not count as root identifier uses. Negative controls preserve
quarantine despite dangerous names appearing only in those opaque contexts.

## True malformed controls

Each delimiter family includes a handwritten genuinely malformed source without relevant
preprocessing evidence. These retain `SOURCE_SYNTAX_ERROR`, empty facts and exit 1.
Tests compare the original `pairs()` reason and byte span. Invalid UTF-8, NUL/replacement
characters and lexical corruption remain governed by the existing error policy.

## Findings / OOS state

The uncertainty path returns `supported_candidate=false`, `status=OUT_OF_SCOPE`, no facts
and no direct-inherit extraction. Its two findings use existing codes `OUT_OF_SCOPE` and
`DRIVER_SEMANTICS_UNKNOWN`, explaining that preprocessing prevents reliable static-room
admission and authored imbalance is insufficient corruption evidence. It produces neither
source syntax nor source encoding findings; the isolated CLI case exits 0.

## P2F1–P2F11 regressions

Fresh pre-commit runs passed:

| Check | Result |
| --- | --- |
| P2F12 focused class | 42 tests |
| Every P2F1–P2F11 repair class | 215 tests |
| Full migration suite | 322 tests |
| Full Python suite | 368 tests |
| Repository checks / diff whitespace | PASS |

Historical semantic blockers 1–17 remain closed under these regression checks. Existing
output confinement, continued shadowing, exclusions, unresolved includes, computed mappings,
manual metadata, FR-01 and FR5–FR10 repairs remain covered. Normal paired P2F10/P2F11
behavior and root conditional handling are unchanged; targeted mocks prove the new gate
is not called on normal paired, conditional, encoding-failure or lexical-failure paths.

## Real CLI matrix

118 actual subprocess CLI cases use external temporary source/output roots. Handwritten
fixtures, independent of the production classifier, include all six delimiter families
in LF/CRLF, equivalent literal controls, true malformed and unused-dangerous controls,
plus aliases, cycles, competing definitions, function invocations, DROP arguments,
header definitions and opaque/inert controls. The original FR11 reproducer is included.

Results: 44 preprocessing-uncertain OOS cases, 12 literal EXTRACTED cases and 62 quarantined
malformed/negative controls; 56 exit-0 and 62 exit-1 results. False quarantines among the
preprocessing-uncertain fixtures: 0. Facts emitted by those uncertain fixtures: 0.
Per-case evidence records exit, candidate, status, fact fields, finding codes, source hash,
original bytes, provenance and quarantine reasons.

## Version 1.0.12

Extractor version is `1.0.12`; known canonical versions are `1.0.0` through `1.0.12`.
Schema version remains 1 and profile remains `static-room-v1`. There is no IR schema change.

## Output compatibility

All 13 real historical/current canonical outputs were freshly copied to external temporary
destinations and replaced successfully through the CLI; original evidence bytes stayed intact.
Unknown/manual/reviewed/malformed/future guards remain exit 2, no writer call and unchanged
bytes. Additional checks exercise 33 nested manual/unknown-field injections, eight protected
absolute/parent-relative destinations, tracked external output protection, allowed output
controls and invalid-UTF-8 raw-byte evidence. No output guard was changed.

## Corpus A/B

Two independent pre-commit complete scans produced identical bytes:

| Metric | A and B |
| --- | --- |
| Exit | 1 |
| Scanned / supported | 2,336 / 485 |
| EXTRACTED / PARTIAL | 0 / 485 |
| OUT_OF_SCOPE / QUARANTINED | 1,838 / 13 |
| Facts / findings | 2,736 / 4,296 |
| Bytes | 9,808,627 |
| SHA-256 | `399a90501ea0a298fbfcd417602651e79c32060c82215a1e11209f84440110a6` |

Finding distribution: CALLBACK_BEHAVIOR 284; DRIVER_SEMANTICS_UNKNOWN 408;
DYNAMIC_EXPRESSION 10; ORDER_SENSITIVE_MUTATION 30; OUT_OF_SCOPE 1,319;
REQUIRES_SEMANTIC_REVIEW 1,623; RNG_SEMANTICS 58; SOURCE_ENCODING_ISSUE 8;
SOURCE_SYNTAX_ERROR 5; UNRESOLVED_INCLUDE 97; UNRESOLVED_INHERITANCE 14;
UNSUPPORTED_CONSTRUCT 440.

Comparison with the P2F11 canonical corpus gives **zero semantic object/finding changes**,
including candidate/status/facts, finding reasons, direct inherits and quarantine evidence.
The complete JSON version metadata changes as expected; the old whole-document hash is
not used as the new version's acceptance requirement.

## 13 quarantine comparison

The exact 13 paths, reasons and spans match P2F11: eight encoding and five syntax errors.
Encoding paths are `cmds/std/exercise.c`, `d/choyin/npc/yamen_po.c`,
`d/latemoon/upstar/upcenter.c`, both magic/spells books under each of
`d/temple/npc/obj/` and `d/temple/obj/`, and `u/cloud/obj/npc/flower_girl/guihua.c`.
Syntax paths are `d/latemoon/sroad1.c`, `d/npc/oldman.c`, `d/village/lordhouse3.c`,
`u/cloud/npc/goddd.c` and `u/cloud/obj/sword_book.c`.
Fresh raw-source inspection retains positive corruption evidence; none becomes OOS.

## 14 ANSI exclusions

All 14 remain candidate=false, OOS, empty facts and not quarantined:
`d/canyon/canyon4.c`, `d/choyin/club.c`, `d/chuenyu/trap_castle.c`, `d/city/boots.c`,
`d/city/cloth.c`, `d/green/water.c`, `d/latemoon/gate.c`, `d/latemoon/latemoon3.c`,
`d/latemoon/latemoon8.c`, `d/latemoon/miroom.c`, `d/latemoon/park/paroad2.c`,
`d/latemoon/room/bathroom.c`, `d/latemoon/room/bathroom1.c`, `d/oldpine/keep2.c`.
No ANSI concatenation evaluation was introduced.

## Provenance

The new findings reference only actual authored root-use tokens. No expanded macro source,
synthetic delimiter, header fact or copied header provenance is emitted. CLI evidence checks
original raw slices/hashes in LF/CRLF fixtures. Complete corpus checking validates 9,587
provenance records: 1,799 direct inherits, 2,736 facts, 4,296 findings and 756 normalization
inputs, including 1,239 Unicode span records and three CRLF-source records.
The full reference file manifest remains
`744e33e1740db7909129a3ae5e295158341b5012a411af953b144a5075bb0a80`.

## Archive evidence preservation

ARCHIVE-01 remains CLOSED. All nine previously frozen historical audit hashes and the
original tracked P2F11 blocked archive were rechecked against HEAD, index/worktree as
applicable. P2F10 raw Git blob remains 24,417 bytes, 468 CRLF, SHA-256
`56e1cd0aa0a573bc4a9505fb5df6bd1cfbd0076849a40f6bd4a4420483cb2213`.
Original tracked P2F11 blocked archive SHA-256 is
`48f07085604905ef3d603474bae86fb028cff9bbc1088a83769eee16babe9155`.
`.gitattributes`, including the P2F10 `-text` exception, stays byte-identical; SHA-256
`b33913bb7279e1ab67762574ab277828a9fd114dae23dceace2f24ae842194d6`.
No historical report, DECISIONS, legacy source, game/runtime, workflow, CLI or source lexer
is changed. Frozen hashes are retained in ignored `build/migration-tooling-v1/p2f12/frozen.json`.

## FR11 blocked rerun report preservation

`MIGRATION_TOOLING_V1_FINAL_RE_AUDIT_AFTER_P2F11_RERUN.md` remains owner-local, untracked,
unstaged and byte-identical. Frozen `FR11_BLOCKED_RERUN_START_SHA` is
`8fc46327ca954ad0089e3ee4fb496bfe8cfe21f497b43ae77432e76ff2bc170b`.
It is not part of this implementation commit and is not rewritten as a passing audit.

## Residual boundary

This is conservative bounded refusal, not proof that macro-dependent source compiles.
Function invocations, cycles and token-pasted identity uncertainty may reject extractable
content, intentionally without producing unsafe facts. Unresolved dependencies alone do
not waive root errors. Driver preprocessing, full LPC parsing and Native generation remain
outside scope. This pure parser/tooling change does not require live Godot gameplay;
no live-game or remote-CI evidence is claimed.

## Owner gate

P2F11 is CLOSED; its rerun Final Re-Audit was BLOCKED by FR11-01. P2F12 addresses that
blocker and awaits owner review. Another complete Final Re-Audit is required and has not
been authorized. No PR, merge, P3 or next milestone is authorized by this report.

All numeric results above are explicitly **pre-commit** implementation evidence. After the
single `Fix macro-supplied delimiter preflight` commit, the complete checks must run again
on the frozen exact commit before push. Separate ignored `post-*` receipts under
`build/migration-tooling-v1/p2f12/` record that SHA and fresh results; the completion message
reports them without rewriting this report or amending the commit. Push/fetch must confirm
local=origin phase, frozen main, clean tracked/index state, preserved untracked evidence
and no phase PR. Stop there for owner review / Final Re-Audit authorization.
