# Migration Tooling v1 — P2F35 Directive-Separated Pairing Uncertainty

**P2F35 FIX IMPLEMENTED — PRE-COMMIT GATES PASS — AWAIT IMMUTABLE POST-COMMIT GATES / OWNER REVIEW.**

## Authorization and frozen identities

Owner approved P2F35 only: repair FR34-01, blocking MEDIUM / D9 / owner class C false quarantine.
P2F34 and FR33-01 remain OWNER APPROVED / CLOSED. Forty prior blockers have implementation repairs;
FR34-01 is semantic blocker 41. This is an implementation slice, not another Final Re-Audit.

- Branch: `phase/migration-tooling-v1`.
- Exact parent: `3e22564e3ea64582abb77384e84dbeb07861dd96`, `Track preprocessing declaration witnesses across name states`.
- Frozen main: `cd07808cb76147d0b8c0dad9b82d078b49fefe64`; 40 linear parent commits, no internal merge.
- Fresh fetch and all-state PR lookup: exact local/remote identities; no phase PR.
- Exactly five authorized files: room_extractor.py, test_migration_tooling.py, this report, STATUS and ROADMAP.
- Extractor 1.0.35; schema 1; static-room-v1; canonical versions 1.0.0–1.0.35, 36 total.

Root/docs instructions, [D1–D9](DECISIONS.md#migration-tooling-v1-p2--owner-locked-extraction-boundary),
the complete stopped owner-local Final Re-Audit after P2F34, the
[P2F27 contract](MIGRATION_TOOLING_V1_P2F27_DIRECTIVE_TRANSPARENT_FUNCTION_MACRO_INVOCATION_PREFLIGHT.md#refusal-barrier-and-direct-adjacent-behavior),
[LPC preprocessor manual](../../reference/es2/mudlib/doc/concepts/preprocessor) and
[define reference](../../reference/es2/mudlib/doc/lpc/preprocessor/define) were consulted.
The owner-local stopped report remains untracked; its frozen identity is recorded below rather than linked from tracked documentation.

## FR34-01 reproduction and repair

```c
#define DROP(x)
inherit ROOM;
void create(){
DROP
#pragma strict_types
(})
}
```

Independent header: `#define ERASE(unused)` in `include/remove.h`; root includes `<remove.h>` and
uses `ERASE`, then `#echo independent audit`, then `(])` inside create.
Both fixtures were independently authored with fixed before/after oracles before execution.
All four LF/CRLF real CLI reproductions on frozen P2F34 returned exit1 / QUARANTINED / facts=[];
four direct MacroSummary call traces proved invoked=False. Four post-repair CLI cases return
exit0 / candidate=false / OUT_OF_SCOPE / facts=[], with DRIVER_SEMANTICS_UNKNOWN rather than SOURCE_SYNTAX_ERROR.
Direct traces now record invoked=True, and each diagnostic anchors the authored DROP/ERASE token.

The failed root pairs() call preceded admission scanning. pairing_uncertain_use previously inspected only the next token;
a directive therefore hid a possible function-macro call. Argument removal/transformation prevents positive corruption proof.
This crosses the owner's C threshold even though no facts leaked. Safe late OOS refusal is not the same defect.

The only behavioral method change advances a local cursor over zero or more consecutive directive tokens after an actual
defined identifier, then tests the next authored token for `(`. Every other token stops ownership. It does not pair the
malformed argument, skip ordinary syntax, interpret directives, splice includes or expand/substitute macros.
Existing MacroSummary.pairing_uncertain handles aliases, cycles, competing definitions, invalid signatures and argument removal unchanged.
Direct adjacency remains supported. No synthetic token, replacement-derived span or header offset is represented as root provenance.

## Bounded pairing matrix and true-corruption controls

The frozen independent matrix contains 984 real CLI executions:

- 960 uncertainty cases: six macro forms (empty, parameter-dependent, function alias, object alias, competing definitions,
  object cycle), four adjacency/directive layouts (adjacent, pragma, echo, multiple), four malformed groups, five reached
  definition layouts (root, local, standard, nested, cross-header), LF/CRLF.
- 24 true-corruption controls: no/unused macro, bare function name without a following call, ordinary balanced object macro,
  unrelated mismatch, and identifier/semicolon/operator/comma/braces/literal barriers; LF/CRLF.
- All uncertainty roots are false/OOS/fact-free; all true-corruption controls retain SOURCE_SYNTAX_ERROR/Q/exit1/facts=[].
- Exact-parent comparisons show no candidate/fact widening or new quarantine. The permitted delta is removal of false quarantine.
- Of the984:600 parent false quarantines become OOS,360 previous OOS controls remain OOS,24 true quarantines remain Q.
- All finding path/SHA/raw spans/line/Unicode-column checks pass. The independent primary contributes four further CLI cases.

No full grammar claim, macro engine, new Gate A cross-product or unrelated repair was introduced.

## Frozen Gate A regression and product evidence

Gate A historically PASSED in Final Re-Audit after P2F34. Here it is regression-only:
13,634/13,634 normal structural CLI PASS, with the original repaired early-refusal oracles retained.
This includes historical delimiter_matrix118, directive_matrix204, first_gate6, include-fragment and macro-delimiter families,
P2F27 repaired directive invocation families, and all retained families through P2F11. No frozen expectation was weakened.
AR-01 separately:20/20 FINAL-SAFETY PASS, owner ACCEPTED / NON-BLOCKING. It may retain nonconsumable metadata before late refusal.
No new AR or unrelated FR was assigned; pending-declaration Gate A methods are AST-identical to P2F34.

| Fresh pre-commit gate | Result |
| --- | --- |
| P2F35 focused / combined regression methods | 10 / 139 PASS |
| Migration / full Python unittest discovery | 568 / 614 PASS; zero failures/skips |
| New pairing / independent primary CLI | 984 / 4 PASS |
| Frozen structural / AR-01 CLI | 13,634 / 20 PASS |
| Canonical real CLI replacements | all36 PASS |
| Closed-schema nested pollution | all33 positions refused: exit2, no writer, bytes unchanged |
| Manual/reviewed/future/unknown/malformed/empty output | all6 refused: exit2/no writer/unchanged |
| Output confinement / approved output / external checkout | PASS |
| Read/schema/internal/atomic/destination failures; mocked links/junctions | all7 failure-route probes PASS |
| Invalid UTF-8 raw_hex / provenance / IDs / manifest / summary | PASS |
| Repository static / diff whitespace / Markdown | PASS before staging |

Initial disposable-harness launches exposed missing helper/fixture copies and stale version assertions; these were corrected
without changing behavioral oracles. Failed harness-start logs are retained and excluded from acceptance counts.
An initial quarantine receipt printed non-GBK text and failed console output after its assertions; the console is now ASCII-escaped.
Affected checks were rerun. No product safety gate or frozen regression failed in those setup attempts.

## Corpus and exact parent projection

Two independent fresh current CLI scans each exit1 for the 13 authored corrupt sources, not a tooling/output failure.
Both:2336 scanned, supported/PARTIAL485, EXTRACTED0, OUT_OF_SCOPE1838, QUARANTINED13,
facts2736, findings4296, bytes9808627. A/B are byte-identical.

P2F35 corpus SHA-256: `f864ada742317b69fffd4e2fdd5ac9b1656ec00f23ed1048d93682bdbf4b76d8`.

A fresh scan using byte-exact P2F34 modules reproduced parent canonical SHA
`d997dd7a4825a6e6f47fba0da97333213540062c2c7081209ac5d2c872d0ec81`.
Comparison to that identity-bound parent has affected paths=[], zero object/fact/finding/provenance delta;
only extractor_version changes. All14 frozen ANSI exclusions remain false/OOS/facts=[].
All9587 provenance records pass:2736 facts+4296 findings+1799 direct inherits+756 normalization inputs.
Source/hash/byte spans/raw/raw_hex/Unicode columns/scope/construct/ordinal/normalization/fact IDs/order/finding refs
and exact manifest/summary pass. No duplicate, ghost, orphan or dangling IDs; UNREVIEWED stays unchanged.

## All 13 genuine quarantines — actual-byte review

Five syntax sources were read in full, with ansi.h inspected in full. Eight encoding cases were inspected at their actual raw
offending spans and surrounding source. All13 independently re-extract as Q/noncandidate/fact-free with truthful provenance.
For three pairing failures the resolved macro contexts, actual uses, directive-separated possible calls and include fragments
were freshly enumerated: no pairing-uncertainty witness. No historical quarantine was silently removed.

| Source | Actual byte range / line | Reason and preprocessing proof |
| --- | --- | --- |
| `cmds/std/exercise.c` | [2033,2036) / 57 | Authored NUL/U+FFFD bytes; positive D9 lexical/encoding corruption before macro processing. |
| `d/choyin/npc/yamen_po.c` | [4382,4385) / 123 | Authored NUL/U+FFFD bytes; positive D9 lexical/encoding corruption before macro processing. |
| `d/latemoon/sroad1.c` | [402,457) / 15 | Malformed exit string: north: __DIR__ is inside an opening quote; quote parity remains broken through EOF. No local define/include; no macro can repair authored lexical quoting. |
| `d/latemoon/upstar/upcenter.c` | [337,340) / 11 | Authored NUL/U+FFFD bytes; positive D9 lexical/encoding corruption before macro processing. |
| `d/npc/oldman.c` | [4819,4820) / 145 | kill_ob has a bare color-prefixed string sequence and environment(), this_object() followed by an extra ). No matching message call opener. Only ansi.h; all reached actual color macros are balanced object replacements, with no callable macro or include fragment. |
| `d/temple/npc/obj/magic_book.c` | [863,866) / 24 | Authored NUL/U+FFFD bytes; positive D9 lexical/encoding corruption before macro processing. |
| `d/temple/npc/obj/spells_book.c` | [840,843) / 24 | Authored NUL/U+FFFD bytes; positive D9 lexical/encoding corruption before macro processing. |
| `d/temple/obj/magic_book.c` | [863,866) / 24 | Authored NUL/U+FFFD bytes; positive D9 lexical/encoding corruption before macro processing. |
| `d/temple/obj/spells_book.c` | [840,843) / 24 | Authored NUL/U+FFFD bytes; positive D9 lexical/encoding corruption before macro processing. |
| `d/village/lordhouse3.c` | [1737,1738) / 81 | Commented-out case 6 if/open-brace leaves an extra closing brace in do_takeout; mismatch at line81. No authored defines/includes or callable macro witness. |
| `u/cloud/npc/goddd.c` | [4255,4280) / 161 | Unescaped quote after 说: in message_vision breaks string parity; lexer reports the final unmatched quote at EOF. Only ansi.h is included; its replacements are object color strings, not quote repair or call ownership. |
| `u/cloud/obj/npc/flower_girl/guihua.c` | [4,5) / 1 | Authored NUL/U+FFFD bytes; positive D9 lexical/encoding corruption before macro processing. |
| `u/cloud/obj/sword_book.c` | [907,908) / 27 | Nested typo et("long", inside set("long", leaves outer set parenthesis open at closing else brace line27. No authored defines/includes or callable macro witness. |

## Source, archive and evidence preservation

Reference tree: `4106480ab28cce8cd7b55704f8ae9ae062d42d03`.
2336-file raw manifest: `744e33e1740db7909129a3ae5e295158341b5012a411af953b144a5075bb0a80`.
ARCHIVE-01 CLOSED. All10 tracked historical audit raw hashes remain equal in worktree/index/HEAD;
P2F10 retains24417 bytes/468 CRLF and SHA `56e1cd0aa0a573bc4a9505fb5df6bd1cfbd0076849a40f6bd4a4420483cb2213`.
`.gitattributes` SHA `b33913bb7279e1ab67762574ab277828a9fd114dae23dceace2f24ae842194d6` is unchanged.
All31 owner-local historical files remain untracked/unstaged/byte-identical; no historical evidence was rewritten.
Evidence#31 Final Re-Audit after P2F34 remains39376 bytes and raw SHA
`f6939bacb6bdcb94a8480db2c64587277333e2e08a86a54aa40e4f646f0cd90c`.

| Preserved owner-local file | Raw SHA-256 |
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
| `MIGRATION_TOOLING_V1_FINAL_RE_AUDIT_AFTER_P2F28.md` | `217193c0f83909be1274a813738bf0561e22b5bc7a47c659e627b88ef736e1df` |
| `MIGRATION_TOOLING_V1_P2F29_UNRESOLVED_DECLARATION_HEADER_REFUSAL_ATTEMPT1_BLOCKED.md` | `0760be6f9cdab6060863019b20e35d494c0d39128c4c76e4d5797be46a9744dd` |
| `MIGRATION_TOOLING_V1_FINAL_RE_AUDIT_AFTER_P2F29.md` | `dceeec904b909832921de610a4cdd1ea8258c101f63ffa505f25ce69e4d58cb8` |
| `MIGRATION_TOOLING_V1_FINAL_RE_AUDIT_AFTER_P2F30.md` | `2d5652da91ef9f4ca31bb31c1f6230b37a6c7ae34f674ce5c4174c8d5d7ba419` |
| `MIGRATION_TOOLING_V1_FINAL_RE_AUDIT_AFTER_P2F31.md` | `88f1cd583e75c488a64ad4d5d27034317674e8938f785a75218f3ab9acb5e64b` |
| `MIGRATION_TOOLING_V1_FINAL_RE_AUDIT_AFTER_P2F32.md` | `86fecf8853e11275f9bfe2beef13657ddeb80e3fe4c1f68f5e7b2cc3fb380499` |
| `MIGRATION_TOOLING_V1_FINAL_RE_AUDIT_AFTER_P2F33.md` | `fdb6890f8b1a489bdf1be1266bb28d4ceca45ee40569cc412b3190d65dfe6b5a` |
| `MIGRATION_TOOLING_V1_P2F34_STATE_INDEPENDENT_PREPROCESSING_DECLARATION_WITNESS_ATTEMPT1_BLOCKED.md` | `d9296f417c63724f31a0681a917a071f5c299aa90d1d37322e667ae892e50012` |
| `MIGRATION_TOOLING_V1_FINAL_RE_AUDIT_AFTER_P2F34.md` | `f6939bacb6bdcb94a8480db2c64587277333e2e08a86a54aa40e4f646f0cd90c` |

## Residual limits and owner gate

Bounded uncertainty is not preprocessing execution or LPC-driver conformance. Possible invocation may conservatively refuse
otherwise usable input; it never proves execution or admits facts. Existing MacroSummary policies remain unchanged.
AR-01 is accepted; existing frozen FR regressions remain mandatory. Mocked link/junction checks are not native filesystem
qualification; existing TOCTOU limits remain. Pure parser work has no live Godot acceptance criterion.

This report records pre-commit evidence. Delivery requires one five-file commit with exact parent above, subject
`Recognize directive-separated macro pairing uncertainty`, followed by ALL fresh immutable-commit acceptance gates.
Post-commit receipts and exact commit identity are retained under ignored `build/migration-tooling-v1/p2f35/`;
do not amend this report to pretend those later runs preceded its commit. A failed post gate forbids push.
Only after all pass is a normal phase push authorized. FR34-01 is IMPLEMENTATION REPAIRED upon successful delivery,
not final Gate B certification. Gate B remains BLOCKED / INCOMPLETE pending an owner-authorized Final Re-Audit.
No PR, merge, remote CI, P3, Native output, P2F36 or another Final Re-Audit is authorized. Stop for owner review.
