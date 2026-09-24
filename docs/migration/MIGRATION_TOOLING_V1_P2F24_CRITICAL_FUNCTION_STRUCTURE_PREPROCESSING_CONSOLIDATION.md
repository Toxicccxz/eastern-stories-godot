# Migration Tooling v1 — P2F24 Critical Function Structure Preprocessing Consolidation

**P2F24 FIX IMPLEMENTED — AWAIT OWNER REVIEW / FINAL RE-AUDIT NOT YET AUTHORIZED**

## Authorization / frozen identities

FR23-01 / HIGH / D2-D3, on `phase/migration-tooling-v1`. Frozen parent and pre-commit remote phase: `92ef69e8f20a00b60f855750bfa6ff87987c94a8`, subject `Guard preprocessing-sensitive inherit prefixes`. Frozen main/merge-base: `cd07808cb76147d0b8c0dad9b82d078b49fefe64`. Fresh fetch and all-state phase PR search found no PR.

Attempt 2 continued the existing unstaged P2F24 candidate without reset/discard. Version remains 1.0.24. Exactly five authorized eventual tracked paths: extractor, migration tests, this live report, STATUS, ROADMAP. No source/runtime/Save/CLI/writer/DECISIONS change.

Authority: [D1-D9](DECISIONS.md), original [define](../../reference/es2/mudlib/doc/lpc/preprocessor/define), [include](../../reference/es2/mudlib/doc/lpc/preprocessor/include), [function](../../reference/es2/mudlib/doc/lpc/constructs/function), [inherit](../../reference/es2/mudlib/doc/lpc/constructs/inherit), [ROOM](../../reference/es2/mudlib/std/room.c) and [DBASE](../../reference/es2/mudlib/feature/dbase.c). Local function overrides affect inherited property semantics; an included declaration participates in the root object's compilation context. No external port or LPC runtime was used.

## FR23-01 root cause

Raw preceding-name and parameter-to-body adjacency can misidentify a preprocessing-sensitive local set override or another create. Trusting the remaining ordinary create then publishes unsafe literal facts. The original multiline root reproduction freshly leaked inherit/short/exit in both LF/CRLF before Attempt 1; the separate header reproduction leaked inherit/name/exit. PARTIAL and UNREVIEWED do not excuse unsafe subsets.

## Why raw function-name/body adjacency was unsafe

A removable macro may separate an authored set/create name from its possible parameters or separate parameters from the body. Raw discovery can call the function GAP or miss it entirely. Literal arguments to set cannot be trusted while local setter or duplicate-create structure is unresolved. The repair refuses uncertainty instead of trying to determine the real declaration.

## Attempt-1 independent blocker

Attempt 1 implemented the root-source gate and passed 6 focused tests, original FR23 84 CLI and expanded root 348 CLI. Its independent 29-shape matrix stopped at shape 28: a resolved header authored `mixed set GAP (...) { return value; }`, while the root retained name and exit facts. Shape 29 (hidden header create) was not run. The owner-mandated stop was observed: no commit/push; the live report recorded BLOCKED.

Attempt 2 retains that history and fixes the dependency gap. It does not reinterpret the prior incomplete attempt as having passed.

## Why root-only consolidation was incomplete

The original new helper scanned self.tokens even though macro_context already knew about resolved authored units. Macro definitions from headers were available, but a critical function authored inside a header never reached the same scanner. included_structure_hazards could also misname that function from raw adjacency. Both facts require one structural reliability rule across all reached units.

## Unified critical-function structural safety invariant

Before candidate admission and any inheritance/create/exit fact allocation, every reached authored unit is checked for the bounded preprocessing-sensitive admission structures. The shared preprocessing_admission_structure_use(tokens, macros) detects critical set/create gaps and hidden inherit prefixes. A hit clears collected inheritance/category state and returns candidate=false / OUT_OF_SCOPE / facts=[]. Existing inheritance, conditional, fragment and include hazards remain in force. This is bounded conservative extraction, not proof of arbitrary LPC validity.

## Resolved authored-unit model

The caller obtains one existing MacroSummary, separate (source_path, tokens) units and root include origins from macro_context(self.tokens, origins=origins). Root, local, nested, standard and cross-header units remain separate; traversal visits each reached source once. Unreferenced dependency files do not participate. No synthetic translation unit or tokens are built.

## Dependency structural scanner

The same scanner and macro-use/group/depth rules apply to root and dependency tokens. Each unit is paired independently. If a dependency cannot be paired, the scanner defers to existing include/fragment conservative handling; it does not convert fragment uncertainty into source quarantine or waive unresolved-include hazards. A normal direct set/create/inherit stays with the old included-structure policy.

## Critical set handling

Both root and dependency authored set name/body gaps cause full-object refusal before fact allocation. Empty macros, aliases, actual function macro uses and callable-style groups do not hide a local setter from the trust gate. The setter is never recovered or executed.

## Critical create handling

Both root and dependency create name/body gaps cause full-object refusal. This covers another create before or after an ordinary create, without choosing a winning definition. Direct recognizable create controls retain exact old outputs.

## Name to parameter gap

A sequence of actual macro uses and authored matched groups between set/create and possible parameters is a refusal witness. Object-like possibilities count as actual use; function-only definitions require an immediately following matched call group. Uninvoked function-only names and unrelated nonmacro tokens stop the gap scan.

## Parameter to body gap

The same loop detects macro/directive material between a parameter group and an authored body. Both-gap cases share the same rule, rather than separate set-middle/create-suffix implementations. Multiple authored groups remain opaque; their argument contents are not interpreted.

## Directive gap

Fresh root and dependency matrices cover define, undef, pragma, echo, unknown directives and resolved includes between critical name/parameter/body pieces. Findings describe uncertain adjacency; no directive is executed. Directives split inheritance-prefix statements under the existing P2F23 rule.

## Actual macro-use classification

One global bounded MacroSummary from existing traversal is reused by root/dependency scanning. Mixed object/function possibilities remain conservative. No replacement classification is used to reconstruct a signature. Existing replacement-effect machinery outside the new gate is unchanged.

## Multiple gaps/call groups

The scanner advances over authored matched parenthesis groups iteratively. It handles multiple actual macro tokens, both gaps and A()() / A()()() forms without proving expansion, reusing arguments or calling create_tail_effect. Existing approximately 1100-alias/call/gap stress cases remain deterministic and nonrecursive.

## Hidden inheritance primitive

The existing preprocessing_hidden_inherit_use accepts an optional already-built MacroSummary; otherwise its original root API/behavior remains. The shared scanner calls that same primitive on semicolon-terminated top-level slices. Pure preprocessing prefixes before authored inherit (including custom bases) veto admission without recovering inherited classes. The P2F22 inherit-keyword gate remains unchanged.

## Top-level depth

Paired call/parameter/mapping/array/body groups remain opaque to the outer scan. Critical text inside arguments, helper bodies, nested blocks, strings, comments and multiline text does not become top-level structure. The scanner resets the top-level slice after statements, directives and body blocks and never stitches across a semicolon.

## Function-order independence

All reached units are checked before candidate calculation or create dispatch. Root functions after an ordinary create, later dangerous includes and nested/cross-header definitions cannot escape by ordering. For multiple dangerous dependencies, first traversed deterministic root include origin is sufficient; repeated runs and both include orders are tested.

## Helper/nonmacro/nested negative controls

Root Attempt-1 controls remain byte/record exact. Dependency controls compare complete objects and findings against pre-Attempt-2 outputs: helper gaps, ordinary nonmacro interposition, direct normal functions/inheritance, prefixes before the whole function or between type/name, nested identifiers, text and statement boundaries. No broad veto on every helper was introduced.

## Full-object refusal

A new-gate hit clears direct_inherits/category_candidates while supported_candidate remains false, status OUT_OF_SCOPE and facts empty. OUT_OF_SCOPE/INFO and DRIVER_SEMANTICS_UNKNOWN explain unreliability. The helper returns a witness only; no declaration, category, parameter or dependency fact is recovered.

## Fact-allocation safety

Fact() spies cover every positive root and dependency handwritten fixture with matching source/include paths. They raise on any allocation. All pass, proving refusal precedes inherit/create/exit allocation rather than emit-then-remove rollback. Safe control facts keep their existing IDs.

## No macro expansion

No argument substitution, condition evaluation, macro execution, expanded tokens or include splicing. Focused mocks forbid effect/reach/create-tail-summary interpretation on the root positive gate path.

## No function recovery

The implementation does not remove a macro token, rebuild set/create, choose a duplicate definition, normalize source or synthesize a function name. Dependency code is evidence of uncertainty, not a source of recovered migration facts.

## No general LPC grammar

The change uses existing lexed tokens, bounded pairs and exact admission-critical names. No return-type, modifier, parameter or overload grammar; no new parser dependency, driver/runtime emulation or external code.

## Root include provenance

Root uncertainty retains the authored critical/gap tokens. Dependency uncertainty replaces the unit witness only for finding location with origins[source_path], the real root-authored include directive. Dependency byte offsets are never applied to the root. Both findings use the real root source hash/span/line/column; no synthetic set/create/inherit token.

## Nested include provenance

For root -> outer.h -> inner.h, an inner hazard anchors to the root include of outer.h. Fresh Unicode LF/CRLF tests verify source path/hash/raw slice/line/column, and assert that replacement/header names do not appear as root tokens.

## Header hidden set closure

The exact Attempt-1 shape 28 now exits 0 with candidate=false / OUT_OF_SCOPE / facts=[]. No name, exit or inherit fact remains. Its fixed oracle is unchanged.

## Header hidden create closure

Previously unexecuted shape 29 now runs in LF/CRLF and fully refuses. There is no winning-create selection. The original independent matrix is now complete: 29/29 shapes, 58 CLI.

## Header hidden inherit closure

Fresh dependency `EMPTY inherit NPC;` and `EMPTY inherit "/custom/base";` refuse the entire root object. The existing root inheritance primitive supplies the same conservative test in each authored unit; no excluded-class recovery is used.

## Nested/standard/cross-header coverage

Dependency expansion authors dangerous set/create/inherit in local, nested, standard, cross-header and nested-cross-header contexts. Multiple clean/dangerous includes and combined root/dependency hazards pass. Definitions and declarations may reside in different reached units; the bounded global MacroSummary is shared.

## Unreferenced dependency controls

An unused header containing dangerous set/create/inherit contributes no root hazard. Only macro_context-reached units enter the shared scan. The independent sweep also verifies this negative.

## Direct dependency structure controls

Before editing Attempt 2, complete outputs for ordinary direct header set/create were saved with 4 real CLI runs (LF/CRLF), together with 216 direct-extractor baselines for the dependency matrix. Fresh after-results preserve the direct set/create/inherit and helper/statement-boundary control outputs exactly. A direct included set is not automatically upgraded to full-object refusal.

## Original FR23 84 CLI

Exact prior audit source bytes replayed fresh: 8 first sequence + 4 independent/control + 72 siblings = 84. All 40 previously violating executions now fully refuse; all 44 prior satisfying outputs retain complete objects/findings. No original fixed oracle was changed.

## Exact 36-shape sibling matrix

All 36 shapes / 72 CLI remain part of the exact 84: 18 former violating shapes fixed, 18 satisfying shapes preserved, in LF/CRLF. This preserves Attempt 1 root behavior while adding dependency-authored structure.

## Expanded P2F24 matrix

Root expansion remains 174 shapes / 348 CLI, including 171 handwritten shapes and 3 iterative stress cases. Dependency expansion adds 108 shapes / 216 CLI. Both newline modes pass. Negative controls use frozen pre-edit full output comparisons, not generated replacement goldens.

## 29-shape independent matrix completion

Attempt-1 independent matrix ran all 29 shapes / 58 CLI with unchanged oracles. Shapes 1–27 remain satisfying; header hidden set and header hidden create now refuse. No early stop or unexecuted remainder is hidden.

## Second independent consolidation sweep

A new sweep authored independently of the product test case generator ran 32 shapes / 64 CLI. It spans root and dependency inherit/set/create, name/body/both gaps, cross/nested/standard contexts, directives, helpers/nested names, unreferenced headers, ordinary direct structure, semicolon boundaries, fragments and multiple dangerous dependencies. Every fixed oracle passed. Both root and resolved-dependency consolidation gates passed before full historical validation.

## FR22/P2F23 regression

Fresh exact 46 audit CLI plus expanded 98 CLI, stress and retained fact-allocation/provenance tests pass. The inheritance-prefix primitive has only optional context injection; existing root semantics and fixed historical matrices remain unchanged.

## FR21/P2F22 regression

Fresh exact 46 CLI plus expanded 82 CLI pass. Macro-shadowed inherit and uninvoked function-like keyword behavior remain; the keyword gate is unchanged.

## FR20/P2F21 regression

Fresh original 72 CLI, expanded 84 CLI and primary 4 CLI pass. Tail enum/effect/continuation code is AST-identical to the frozen parent; no call ownership or argument reuse change.

## FR16-FR19 regressions

Fresh key matrix 500 CLI + original grouped family 94 + expanded 294 + 40 finalizer-independence probes; hidden create expression 270 CLI + 12 finalizer probes; additional primary 4, FR18 56, expanded 110, nested 148 and mapping 156 CLI all pass. Exit staging, property/receiver classification, flat registration and finalization remain unchanged.

## P2F11-P2F15 regressions

Fresh header/inherit/pending/create-tail combined gate 492 CLI, directives 204 and delimiter uncertainty 118 CLI pass, together with all retained repair unit methods. No new header-fragment quarantine is introduced.

## P2F1-P2F23 regressions

All 355 retained repair unit methods pass. One explicitly reviewed expectation was aligned with P2F24's authorized metadata-clearing invariant: P2F10 `void create() END { ... }` previously required retained direct ROOM metadata on OUT_OF_SCOPE. It now requires empty direct inheritance and category metadata; its candidate/status/facts/provenance assertions remain. The adjacent helper-function control retains the original expectation. This is not a source behavior patch or an independent-oracle change.

The first development run exposed that stale assertion in LF/CRLF; its failed log/receipt is preserved in ignored evidence. Full validation was restarted after the single expectation change. No other retained repair-test semantic expectation changed.

## Fresh tests

Fresh complete pre-commit gate: **36 validation groups, all PASS**.

| Gate | Fresh count |
|---|---:|
| P2F24 focused unit methods | 10 |
| Retained P2F1-P2F23 repair methods | 355 |
| Full migration unittest suite | 430 |
| Full Python unittest suite | 476 |
| Retained/new standalone fixture CLI executions | 3648 |
| Real historical version replacement CLI | 25 |

Counts distinguish fixture matrices from CLI calls performed internally by unit tests and security probes. Repository checks and git diff --check pass. This pure parser/tooling slice requires no Godot gameplay run; none is claimed. Exact-commit verification must repeat all 36 groups after the one commit and before push; pre-commit evidence cannot substitute.

## Version 1.0.24

Version remains 1.0.24 throughout Attempt 2. KNOWN contains exactly 1.0.0–1.0.24 (25). Schema version 1 and static-room-v1 are unchanged.

## Compatibility

25 real CLI replacements consume preserved canonical outputs from each historical version, including fresh 1.0.24. Unknown/future/manual/reviewed/malformed/empty outputs and unknown nested dictionary metadata reject with exit2, writer not called, target bytes unchanged. No schema change.

## Output security

Complete retained security/unit matrix passed: protected root/game/reference/docs destinations, absolute/relative escape, tracked target and external tracked checkout, approved build/external destinations, existing link/junction guards and atomic-write behavior. Independent closed-schema traversal attacked 33 actual dictionary positions. Invalid UTF-8 raw_hex provenance also passed. No CLI/writer implementation change or security delta.

## Corpus A/B

Two fresh complete scans of the candidate both exit1 for the same 13 historical source quarantines. Scanned 2336; supported 485; EXTRACTED 0 / PARTIAL 485 / OUT_OF_SCOPE 1838 / QUARANTINED 13; facts 2736; findings 4296.

A bytes = B bytes = **9808627**. A SHA-256 = B SHA-256 = `d8cc5dbc0f27bd751f5b5be4098f521d3fd444b83b9ddfa7c32511696ebb7a57`. Byte equality asserted.

| Finding code | Count |
|---|---:|
| CALLBACK_BEHAVIOR | 284 |
| DRIVER_SEMANTICS_UNKNOWN | 408 |
| DYNAMIC_EXPRESSION | 10 |
| ORDER_SENSITIVE_MUTATION | 30 |
| OUT_OF_SCOPE | 1319 |
| REQUIRES_SEMANTIC_REVIEW | 1623 |
| RNG_SEMANTICS | 58 |
| SOURCE_ENCODING_ISSUE | 8 |
| SOURCE_SYNTAX_ERROR | 5 |
| UNRESOLVED_INCLUDE | 97 |
| UNRESOLVED_INHERITANCE | 14 |
| UNSUPPORTED_CONSTRUCT | 440 |

## Semantic delta

Exact parent output is bound to frozen P2F23 SHA `92ef69e8f20a00b60f855750bfa6ff87987c94a8` and raw output hash `c12210cc8b9ccfbdadd19544701c691e2c27a3a6bc1abeac871479d539ebe962`. Fresh comparison proves zero document semantic delta after removing extractor_version only. No affected real path; no new candidates, facts, exits, inheritance change or quarantine change. This is measured, not assumed from historical counts.

## 13 quarantines

All 13 exact source paths, findings, byte spans and empty facts match the parent. Fresh raw-byte probes identify 8 NUL/replacement-character issues and 5 malformed-string/delimiter cases; malformed source lines were separately inspected. P2F24 is not a D9 repair.

| Path | Reason | Byte start/end |
|---|---|---|
| `cmds/std/exercise.c` | NUL or replacement character in source | 2033 / 2036 |
| `d/choyin/npc/yamen_po.c` | NUL or replacement character in source | 4382 / 4385 |
| `d/latemoon/sroad1.c` | unterminated string | 402 / 457 |
| `d/latemoon/upstar/upcenter.c` | NUL or replacement character in source | 337 / 340 |
| `d/npc/oldman.c` | mismatched delimiter | 4819 / 4820 |
| `d/temple/npc/obj/magic_book.c` | NUL or replacement character in source | 863 / 866 |
| `d/temple/npc/obj/spells_book.c` | NUL or replacement character in source | 840 / 843 |
| `d/temple/obj/magic_book.c` | NUL or replacement character in source | 863 / 866 |
| `d/temple/obj/spells_book.c` | NUL or replacement character in source | 840 / 843 |
| `d/village/lordhouse3.c` | mismatched delimiter | 1737 / 1738 |
| `u/cloud/npc/goddd.c` | unterminated string | 4255 / 4280 |
| `u/cloud/obj/npc/flower_girl/guihua.c` | NUL or replacement character in source | 4 / 5 |
| `u/cloud/obj/sword_book.c` | mismatched delimiter | 907 / 908 |

## 14 ANSI exclusions

All 14 exact historical paths remain candidate=false / OUT_OF_SCOPE / facts=[] / not QUARANTINED.

- `d/canyon/canyon4.c`
- `d/choyin/club.c`
- `d/chuenyu/trap_castle.c`
- `d/city/boots.c`
- `d/city/cloth.c`
- `d/green/water.c`
- `d/latemoon/gate.c`
- `d/latemoon/latemoon3.c`
- `d/latemoon/latemoon8.c`
- `d/latemoon/miroom.c`
- `d/latemoon/park/paroad2.c`
- `d/latemoon/room/bathroom.c`
- `d/latemoon/room/bathroom1.c`
- `d/oldpine/keep2.c`

## Provenance / ID integrity

Fresh fixture and full-corpus validation checks source/raw hashes, byte spans, raw/raw_hex, Unicode line/column, normalization inputs, unique deterministic fact IDs, finding references/order, review states, summaries and manifest completeness. Dependency findings anchor root includes, while root findings retain authored critical/gap tokens. No ghost/orphan/duplicate IDs; safe unaffected facts retain exact parent IDs. Suppressed structural objects never allocate facts.

## ARCHIVE-01

CLOSED. Ten tracked historical audit raw/HEAD/index hashes preserved. P2F10: 24,417 bytes, 468 CRLF, SHA-256 `56e1cd0aa0a573bc4a9505fb5df6bd1cfbd0076849a40f6bd4a4420483cb2213`; tracked P2F11 `48f07085604905ef3d603474bae86fb028cff9bbc1088a83769eee16babe9155`. `.gitattributes` hash `b33913bb7279e1ab67762574ab277828a9fd114dae23dceace2f24ae842194d6`, historical -text exception unchanged.

## Fifteen owner-local evidence artifacts

All prior fourteen reports remain untracked/unstaged/byte-identical, plus the Attempt-1 blocked copy. Prior fourteen raw hashes:

| File in docs/migration | SHA-256 |
|---|---|
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

## Attempt-1 evidence preservation

Before further implementation edits, the live report matched frozen raw SHA-256 `eaecb3308a3086f01e1fe2232f9105dc8600e168a60658dd89fc9cad4ed93c71` and was copied byte-for-byte to `MIGRATION_TOOLING_V1_P2F24_CRITICAL_FUNCTION_STRUCTURE_PREPROCESSING_CONSOLIDATION_ATTEMPT1_BLOCKED.md`. The copy remains owner-local/untracked/unstaged at that hash. It is never part of the five-file commit. The live report may change; the blocked evidence does not.

## Source and implementation preservation

Reference tree `4106480ab28cce8cd7b55704f8ae9ae062d42d03`; raw 2336-file manifest `744e33e1740db7909129a3ae5e295158341b5012a411af953b144a5075bb0a80`. AST comparison proves existing module-level functions (including macro_regions), enums and all methods except the optional-context inheritance primitive and extract_structure are unchanged. Exactly one new shared scanner method. No CLI/es2_source/game/reference/.github/DECISIONS change.

## Residual boundaries

The scanner is bounded conservative refusal, not complete LPC/preprocessor validation. Possible macro definitions are summarized without execution; authored units are not an expanded TU. Unresolved/incomplete dependencies retain existing conservative handling. The full Structural-Preprocessing Consolidation Final Audit is still required; the Systematic Quarantine-Path Audit remains incomplete. No whole-milestone PASS or PR readiness is inferred from this repair.

## Owner gate

P2F23 is CLOSED. FR23-01's authorized root/resolved-dependency structural class is addressed by P2F24 implementation and fresh local gates. This is not the next Complete Final Re-Audit.

Exactly one five-file commit with subject `Consolidate preprocessing-sensitive critical function structure` and frozen parent is authorized only after all pre-commit gates; all exact-commit gates must pass before push. Exact SHA/counts/preservation receipts are stored under ignored `build/migration-tooling-v1/p2f24a2/` and reported to the owner. No PR, merge, remote CI, branch rewrite or P3. No post-main integration claim. Stop after push for owner review / Final Re-Audit authorization.
