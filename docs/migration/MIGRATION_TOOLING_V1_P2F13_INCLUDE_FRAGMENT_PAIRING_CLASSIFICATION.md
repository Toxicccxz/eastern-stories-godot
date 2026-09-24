# Migration Tooling v1 — P2F13: Include fragment pairing / header classification

**P2F13 FIX IMPLEMENTED — AWAIT OWNER REVIEW / FINAL RE-AUDIT NOT YET AUTHORIZED**

## Authorization / frozen identities

Owner authorization covers FR12-01 / blocking MEDIUM / D9, bounded sibling controls,
one implementation commit, exact-commit verification and phase-branch push. It does not
authorize another Final Re-Audit, PR, merge, P3, source expansion or runtime changes.

| Identity | Frozen value |
| --- | --- |
| Branch | `phase/migration-tooling-v1` |
| Pre-fix executable HEAD / origin phase | `842c287c14675954c3d86e6ec1694fcc14513360` |
| Pre-fix subject | `Fix macro-supplied delimiter preflight` |
| Main / origin main / merge base | `cd07808cb76147d0b8c0dad9b82d078b49fefe64` |
| Reference Git tree | `4106480ab28cce8cd7b55704f8ae9ae062d42d03` |

Preflight fetched origin, checked the branch/references/history, clean tracked worktree/index,
the two expected untracked reports and all frozen archival hashes. The all-state phase PR
query returned no PR. The authorized tracked scope is exactly the extractor, its test module,
this report, STATUS and ROADMAP. All disposable evidence is under ignored
`build/migration-tooling-v1/p2f13/`; older evidence is preserved.

## FR12-01 root cause

Authored root delimiter pairing ignored raw punctuation supplied by resolved textual includes.
P2F12 could explain imbalance through an actually used macro, but a header containing only
`{` has no macro definition/use. The root error was therefore re-raised as source corruption.
The local authoritative [include documentation](../../reference/es2/mudlib/doc/lpc/preprocessor/include)
and [preprocessor manual](../../reference/es2/mudlib/doc/concepts/preprocessor) explain that header
contents take effect at the include site. No gameplay mechanic or external port was consulted.

## Two independent failure modes

First, a root containing `void create()` followed by `#include "open.h"`, a setter and `}`
was falsely quarantined when `open.h` supplied `{`. Second, the scanner ran full standalone
structure extraction on `.h` inputs; even a correctly refused root could still exit 1 because
its legal header fragment was quarantined. Both paths are addressed without producing facts
from the preprocessed structure.

## Header fragment classification

`scan()` now explicitly marks HEADER extraction. The existing byte lexer and directive
lexical views must succeed before header structural recovery is permitted. Subsequent
standalone structural failure is classified as OOS with existing OUT_OF_SCOPE and
DRIVER_SEMANTICS_UNKNOWN findings. Partial structural facts/inherit metadata/findings are
discarded on that recovery path. Headers always remain unsupported and have no facts.

This covers arbitrary lexically complete structural fragments, including an unfinished
inherit declaration or runtime statement, rather than matching six literal delimiter strings.
Normal header analysis and its existing diagnostics remain where it succeeds. Only HEADER
classification receives this structural recovery; `.c` corruption rules remain intact.

## Root raw-include pairing uncertainty

The `.c` order stays lex → root conditional policy → authored pairs. Successful pairing
uses the existing extraction path. On pairing failure, P2F12 macro uncertainty runs first.
Only if no macro explains the uncertainty does the new include-fragment helper inspect
resolved dependency units. A lexically valid unit whose standalone `pairs()` fails is
sufficient evidence for conservative root OOS, candidate=false, facts=[].

Without that evidence, the original root SourceError is re-raised, retaining reason and
byte span. The two root OOS findings anchor to the authored root include directive that
reaches the uncertain dependency. Header punctuation never becomes root provenance.

## Why this is not include expansion

The helper only lexes each dependency separately and checks its authored pairing. It never
concatenates root/header source or token lists, substitutes macros, constructs expanded
translation units, generates delimiters, evaluates conditions, runs cpp/LPC or claims the
fully preprocessed unit is valid. Existing literal and narrow `__DIR__` normalization rules
are unchanged. No source lexer, CLI, schema, gameplay or runtime file was modified.

## Resolved include traversal reuse

The existing `macro_context()` resolver/traversal is reused. Its optional origin map records
the reaching root directive for each discovered dependency, propagated across nested units.
Existing path rules, visited-unit handling, macro collection and normal hazard analysis stay
unchanged. Cyclic/repeated graphs remain bounded. Unreferenced headers cannot explain root
imbalance; missing or lexically malformed dependencies do not qualify as raw fragments.

A distinct implementation self-review compared old/new ASTs: only existing `macro_context`,
`extract` and `scan` changed, and one include-pairing helper was added. Removing the optional
origin bookkeeping leaves the original collector body identical. MacroSummary, normal
structure/statement extraction and include hazard methods are unchanged. New paths contain
no execution or synthetic Token construction; direct review confirms no source splicing.
Evidence: `self-audit.json`.

## Direct six delimiters

LF/CRLF CLI fixtures provide `{ } ( ) [ ]` through a real resolved header at a legal include
site. All 12 now have root OOS, header OOS, no facts, no SOURCE_SYNTAX_ERROR and exit 0.
Independent handwritten literal equivalents preserve ordinary extraction; missing-delimiter
controls without preprocessing evidence retain genuine source quarantine and exit 1.

## Nested includes

A root include reaching another header containing a raw opener is OOS/exit0; both headers
are OOS. Root findings point to the root directive, not the nested header. Unit tests also
cover repeated/cyclic graphs and an unrelated earlier sibling include to verify origin selection.

## Standard includes

`#include <end.h>` resolves through the existing `include/` rule. A closing-delimiter fragment
produces root/header OOS and exit0 with the authored standard include as root provenance.

## Cooperating headers

When opening/closing braces come from two headers and authored root pairs already succeed,
the new root recovery gate is not entered. Existing include hazards conservatively refuse
the root, while both headers are now OOS. Header false quarantine no longer forces exit1.

## Safe-include negative controls

Empty, balanced, helper/function, semicolon-only and inert-definition headers do not excuse
an unrelated root delimiter defect. Missing include plus paired valid root retains existing
OOS/exit0 policy; missing include plus root imbalance remains QUARANTINED/exit1. No blanket
include waiver or unresolved-include policy change was introduced.

## Unused macro negative controls

A header containing only `#define OPEN {` cannot hide root corruption if OPEN is unused:
the directive is opaque to raw pairing, and P2F12 still requires actual macro use. Existing
macro aliases, invoked/uninvoked functions, cycles, competing definitions, inert/opaque
uses and included macro definitions are covered by the historical repair suite.

## Header lexical corruption

Invalid UTF-8, NUL/U+FFFD, unterminated strings/comments/heredocs and lexically broken
directive replacements retain existing encoding/syntax quarantine. Header structural
recovery is enabled only after both ordinary and directive lexical views succeed.
Valid root plus a bad header remains root OOS/header QUARANTINED/exit1. A genuinely malformed
root plus a bad header records both real errors. Existing quoted-symbol/character lexer
policy is preserved; no new LPC lexical grammar was invented.

## Header standalone fragment tests

Whole-source CLI scans with only headers cover six raw delimiters, incomplete declarations,
balanced ROOM-like headers, missing runtime terminators, macro definitions and opaque quoted
tokens. Lexically valid fragments remain HEADER/OOS, unsupported and fact-free. Balanced
headers are never promoted to ROOM candidates, and no header inherit is promoted to a fact.
Genuine lexical header controls independently cause exit1, as required.

## P2F1–P2F12 regressions

Fresh pre-commit validation passed:

| Check | Result |
| --- | --- |
| P2F13 focused class | 29 tests |
| Explicit P2F1–P2F12 repair classes | 257 tests |
| Complete migration suite | 351 tests |
| Full Python suite | 397 tests |
| Repository checks / diff whitespace | PASS |

The P2F8 `test_bad_dependency_manifest_is_quarantined_separately` contained an old expectation
that `void set(){` in a header must quarantine. Its first fresh run failed under the newly
authorized header rule. That fixture is retained and now explicitly expects OOS/exit0;
an unterminated block comment was added as the genuine syntax-corruption counterpart, and
the original invalid-UTF-8 quarantine remains. This is a disclosed contract update, not removal
of a failure case. All 257 historical methods subsequently passed. Current-version assertions
and known-version replacement loops were updated to 1.0.13.

Historical semantic blockers through FR11 remain closed under the repair regressions.
Targeted mocks separately prove that raw-fragment recovery is not called for successfully
paired roots, root conditionals, lexical/encoding errors or an already-explained macro failure.

## Real CLI matrix

110 fresh subprocess cases use external TemporaryDirectory source/output roots. The original
64-case independent FR12 audit family is retained, including its independently handwritten
literal controls; no product test fixture or generated expected output supplies the oracle.
Additional cases cover standalone headers, lexical errors, missing/unreferenced includes and
the exact primary FR12 reproducer. Each case runs in LF and CRLF.

Results: 72 exit0 and 38 exit1. False root quarantines among legal raw-fragment cases = 0;
false header quarantines among lexically valid fragments = 0; unsafe facts = 0. True malformed
roots and genuinely corrupt headers remain quarantined. Per-case records include root/header
statuses, candidate/fact fields, finding codes/reasons, input raw hex/SHA, output SHA and
validated provenance. Evidence: `pre-cli-evidence.json` and `pre-cli/`.

## Version 1.0.13

EXTRACTOR_VERSION is `1.0.13`; known canonical versions are `1.0.0` through `1.0.13`.
Schema version remains 1 and profile remains `static-room-v1`. No IR schema change.

## Output compatibility

All 14 real historical/current canonical outputs were copied to external temporary targets
and freshly replaced through the CLI; original evidence bytes remained unchanged. Separate
guards reject manual, malformed, empty, unknown, reviewed and future-version output with
exit2, writer not called and original bytes preserved. Checks also cover 33 nested unknown
metadata injections, eight protected destination forms, tracked external output protection,
approved output controls and raw_hex provenance. CLI/output/schema validation code is unchanged.

## Corpus A/B

Two independent pre-commit scans of all reference inputs produced identical bytes:

| Metric | A and B |
| --- | --- |
| Exit | 1 |
| Scanned / supported | 2,336 / 485 |
| EXTRACTED / PARTIAL | 0 / 485 |
| OUT_OF_SCOPE / QUARANTINED | 1,838 / 13 |
| Facts / findings | 2,736 / 4,296 |
| Bytes | 9,808,627 |
| SHA-256 | `43081801160d6d02acbbe5595423d709ecd308dfe9f11814f8a59a3b6625465a` |

Finding counts: CALLBACK_BEHAVIOR 284; DRIVER_SEMANTICS_UNKNOWN 408; DYNAMIC_EXPRESSION 10;
ORDER_SENSITIVE_MUTATION 30; OUT_OF_SCOPE 1,319; REQUIRES_SEMANTIC_REVIEW 1,623;
RNG_SEMANTICS 58; SOURCE_ENCODING_ISSUE 8; SOURCE_SYNTAX_ERROR 5; UNRESOLVED_INCLUDE 97;
UNRESOLVED_INHERITANCE 14; UNSUPPORTED_CONSTRUCT 440.

Comparison with exact P2F12 implementation evidence at `842c287` gives **zero semantic delta**:
objects/status/candidate/facts/direct inherits/findings/reasons/spans are identical.
Only extractor-version metadata differs. No unexplained delta was accepted.

## 13 quarantines

Fresh source-byte/span review and exact baseline comparison retain eight encoding and five
syntax quarantines; all are `.c`, all have empty facts. Encoding paths are
`cmds/std/exercise.c`, `d/choyin/npc/yamen_po.c`, `d/latemoon/upstar/upcenter.c`,
the magic/spells book pair under both `d/temple/npc/obj/` and `d/temple/obj/`, and
`u/cloud/obj/npc/flower_girl/guihua.c`. Original NUL/U+FFFD evidence remains.
Syntax paths are `d/latemoon/sroad1.c`, `d/npc/oldman.c`, `d/village/lordhouse3.c`,
`u/cloud/npc/goddd.c` and `u/cloud/obj/sword_book.c`: two unterminated strings and three
mismatched delimiters, with original reason/span/context retained in corpus evidence.
No real `.c` corruption was downgraded by an unrelated include.

## 14 ANSI exclusions

All 14 exact baseline objects remain candidate=false/OOS/facts=[]/not quarantined:
`d/canyon/canyon4.c`, `d/choyin/club.c`, `d/chuenyu/trap_castle.c`, `d/city/boots.c`,
`d/city/cloth.c`, `d/green/water.c`, `d/latemoon/gate.c`, `d/latemoon/latemoon3.c`,
`d/latemoon/latemoon8.c`, `d/latemoon/miroom.c`, `d/latemoon/park/paroad2.c`,
`d/latemoon/room/bathroom.c`, `d/latemoon/room/bathroom1.c`, `d/oldpine/keep2.c`.
No ANSI expression evaluation or coverage-policy change was introduced.

## Provenance

Root raw-fragment OOS findings use the actual reaching root include token. Header fragment
findings reference only the header's authored bytes. Nested and sibling cases explicitly
check the root anchor. No expanded root/header source, synthetic punctuation or copied
header fact exists. CLI tests validate source hashes, raw/raw_hex, byte ranges, line and
column from actual source bytes, including LF/CRLF and Unicode unit fixtures.

Complete corpus verification checks 9,587 provenance records: 1,799 direct inherits,
2,736 facts, 4,296 findings and 756 normalization inputs; 1,239 Unicode span records and
three CRLF-source records. The real corpus has no raw_hex span; independent invalid-UTF-8
controls cover that variant. Manifest, summary, fact IDs, finding references, source ordering
and UNREVIEWED state are checked. No records are automatically approved.

## Archive preservation

ARCHIVE-01 remains CLOSED. All nine frozen historical audits and the tracked P2F11 blocked
report retain original Git/index/worktree bytes. P2F10 remains 24,417 bytes/468 CRLF with SHA
`56e1cd0aa0a573bc4a9505fb5df6bd1cfbd0076849a40f6bd4a4420483cb2213`.
Tracked P2F11 remains SHA
`48f07085604905ef3d603474bae86fb028cff9bbc1088a83769eee16babe9155`.
`.gitattributes` stays byte-identical, SHA
`b33913bb7279e1ab67762574ab277828a9fd114dae23dceace2f24ae842194d6`.
All frozen values are retained in `frozen.json` and checked by `integrity.py`.

Reference raw manifest remains
`744e33e1740db7909129a3ae5e295158341b5012a411af953b144a5075bb0a80` over 2,336 files.
No reference/game/Save/runtime/workflow/DECISIONS/CLI/source-lexer/historical audit changes.

## FR11 blocked report preservation

Owner-local `MIGRATION_TOOLING_V1_FINAL_RE_AUDIT_AFTER_P2F11_RERUN.md` remains untracked,
unstaged and byte-identical, SHA
`8fc46327ca954ad0089e3ee4fb496bfe8cfe21f497b43ae77432e76ff2bc170b`.

## FR12 blocked report preservation

Owner-local `MIGRATION_TOOLING_V1_FINAL_RE_AUDIT_AFTER_P2F12.md` remains untracked,
unstaged and byte-identical, SHA
`a0847fdd481867b45e0c1d0b4b4dfdea7e0995a2bb607130fceeff0d8effc04a`.
Neither blocked report belongs in this commit, and neither is rewritten as a passing audit.

## Residual boundary

Pairing uncertainty permits conservative refusal; it does not prove that any combination
of include fragments compiles. A lexically valid header can be structurally incomplete or
unsupported without being labeled corrupt. Missing dependencies provide no fragment bytes,
and lexical corruption is never excused merely by header classification. The bounded lexer
and existing path/macro/conditional policies are preserved. There is no Native generation,
full preprocessor, runtime execution or source repair. Pure parser/tooling work requires no
live Godot gameplay; no live-game or remote-CI result is claimed.

## Owner gate

P2F12 is CLOSED. Its Final Re-Audit was BLOCKED on FR12-01; P2F13 addresses that family and
awaits owner review. Another complete Final Re-Audit is required and not yet authorized.
No PR, merge or P3 is authorized. The milestone is not fully integrated on main.

All numeric results above are explicitly **pre-commit implementation evidence**. After the
single `Fix include fragment pairing classification` commit, the complete focused/historical/
full suites, CLI matrix, security/compatibility, corpus A/B, provenance and integrity gates
must rerun on the frozen exact commit before push. Separate ignored `post-*` receipts record
that SHA and fresh results; the final response reports them without amending this report.
Push/fetch must confirm local=origin phase, frozen main, clean tracked/index state and both
unchanged untracked reports. Stop for owner review / Final Re-Audit authorization.
