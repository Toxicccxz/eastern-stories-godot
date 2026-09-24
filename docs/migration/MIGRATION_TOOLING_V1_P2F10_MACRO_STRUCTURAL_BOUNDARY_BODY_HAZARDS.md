# Migration Tooling v1 — P2F10 macro structural boundary and body hazards

**P2F10 FIX IMPLEMENTED — AWAIT OWNER REVIEW / FINAL RE-AUDIT NOT YET AUTHORIZED**

## Authority and frozen baseline

This is the owner-authorized FR9-01 HIGH repair and same-class sibling closure, not another
Final Re-Audit or an integration verdict. P2F9 is CLOSED; the subsequent Final Re-Audit
was BLOCKED on FR9-01 (D2/D3/D6). Another complete Final Re-Audit requires owner authorization.

- Branch: `phase/migration-tooling-v1`.
- Pre-fix HEAD and origin phase: `e0334346a3bfadbdd58fe213898361bdd6df6081`.
- Frozen main/origin main/merge base: `cd07808cb76147d0b8c0dad9b82d078b49fefe64`.
- Reference tree: `4106480ab28cce8cd7b55704f8ae9ae062d42d03`.
- Preflight fetch and identity checks passed; index/tracked worktree started clean;
  exactly eight historical blocked audits were untracked. No phase PR existed.
- Authorized completion: exactly one commit, `Fix macro structural boundary and body hazards`,
  exact-commit verification, push this phase branch, then STOP.

## Source authority and root cause

[LPC preprocessor manual](../../reference/es2/mudlib/doc/concepts/preprocessor) describes token
replacement, parameter substitution and textual includes before compilation. The extractor must
not assume that authored braces still delimit the same functions after preprocessing.
P2F9 inspected top-level identity prefixes but skipped parameters and body identifiers.
An actual macro use could inject a local setter, a create function or inheritance while the
extractor continued emitting authored `short` and normalized exits.

[dbase.c](../../reference/es2/mudlib/feature/dbase.c) provides the bounded state-mutation authority:
`set` updates dbase, `add` delegates to `set`, and `delete` uses `_delete`/`map_delete`.
[treemap.c](../../reference/es2/mudlib/feature/treemap.c) implements `_set` and `_delete` on mapping
paths. `set_default_object` changes fallback identity and calls `ob->add("no_clean_up", 1)`.
Those seven names plus the explicitly required lifecycle `create` participate in macro effects.
Temporary APIs use separate `tmp_dbase`; no broad gameplay mutator registry was invented.
Direct bare add/delete handling is unchanged; this repair makes no new claim about their runtime
execution. No independent direct-mutation repair is included.

## Bounded classification and extraction policy

`MacroSummary.effect` walks possible replacement dependencies without recursive expansion,
argument substitution, source concatenation, synthetic tokens or new provenance. All reachable
definitions contribute. Repeated identical definitions are compatible; competing definitions,
cycles and unsupported complex expressions are uncertain. Results are cached within the summary.

| Effect | Evidence | Extraction policy at an actual use |
| --- | --- | --- |
| INERT | Empty replacement, single identifier/literal with no dangerous/uncertain reachable definition | Preserve ordinary extraction; inherited macro-operand restrictions still apply |
| CREATE_STATE_HAZARD | Known state/lifecycle alias or balanced contained call to one of those names | Root create: suppress every create-derived fact, retain authored inherit only |
| STRUCTURAL_BOUNDARY_HAZARD | Braces, semicolon, token paste/stringification, unbalanced replacement delimiters or hidden inherit | Reject ROOM candidate, OUT_OF_SCOPE, facts empty |
| UNKNOWN | Unsupported compound replacement, parameter substitution, competing definitions or cycle | Reject ROOM candidate, OUT_OF_SCOPE, facts empty |

Structural effects outrank unknown, which outranks state effects. Replacement delimiter
uncertainty is classified semantically; it is not thrown as a root SOURCE_SYNTAX_ERROR.

`macro_regions` exposes original token slices for the entire signature: return/type/modifier
prefix, name, parameters including names/default-like expressions/commas, and suffix before `{`.
Unknown or structural uses anywhere in that slice veto admission. `INT -> int`, `MOD -> nomask`
and ordinary helper-name aliases remain safe. Simple known setter/create declaration-name aliases
retain the prior inherit-only suppression. Contained calls in signatures cannot establish a
stable identity and are rejected.

Root create bodies are no longer opaque to actual defined-macro identifier uses, including
nested expressions/blocks and uses before or after literal setters. State-only hazards suppress
short/name/long/all four flags/exits together, without ordering or last-write-wins evaluation.
Other bodies allow inert constants and helper aliases, and do not execute contained state calls;
but a structural or unknown effect anywhere in them invalidates authored top-level boundaries.

Function-like replacements are accepted only where no formal-parameter substitution is needed:
`ONE(x) 1` is inert; `M(x) set("short","other")` is state-only. `M(x) set(x)`, `DECL(x) x`,
variadic substitution and unknown calls reject candidate admission. Balanced call recognition
does not evaluate arguments. Any dangerous reachable replacement still wins.

Definitions and uses share the existing resolved compilation-unit summary across root, nested
and sibling headers. The two-pass collection checks root-definition/header-use as well as the
reverse. Include cycles terminate through visited paths. No conditional is evaluated and undef
does not erase a possible definition. Existing root-conditional OUT_OF_SCOPE behavior is retained.
Unresolved include handling, source namespace and authored direct_inherits remain unchanged.

Only identifier tokens referring to actual definitions count as uses. Comments, strings,
heredocs and raw #echo payload remain opaque. Unused `S -> set`, `I -> inherit`, brace-containing
macros and unused cycles do not block. Critical direct-name shadow guards remain as before.

## Distinct implementation review and sibling sweep

After implementation, reviewed the changed classification, region traversal and admission/create
gates separately against the source manual, mutation APIs, original FR9 parameter/body families
and the actual corpus delta. No LPC expansion, rewrite, runtime coupling or synthetic inheritance
was introduced. `es2_source.py`, `cli.py`, schema 1 and profile `static-room-v1` are unchanged.
Extractor version is 1.0.10; recognized versions are exactly 1.0.0 through 1.0.10.

P2F10RegressionTests has 54 methods, with LF/CRLF subcases. Coverage includes all forty requested
dimensions plus modifier/parameter-name/default/comma sites, state call order/nesting, independent
function-like replacements, mapping mutators, ambiguous sibling definitions, unknown compound
literals, token paste/stringification, and contained helper-body state calls.

| Requested dimensions | Regression coverage |
| --- | --- |
| 1–4: return/name/type aliases | safe/complex return prefix, name aliases, safe parameter type |
| 5–12: parameter/signature boundaries | full parameter replacement, set/create/inherit injection, suffix, function-like, chained/cyclic signatures |
| 13–17: create mutation identities | set/add/delete/create/inherit aliases |
| 18–25: create structural/complex uses | closing/opening brace, semicolon/declaration, function/inherit injection, function-like/chained/cyclic body uses |
| 26–30: other bodies | constants/helper aliases safe; boundary escape/hidden inherit/hidden functions rejected |
| 31–36: unit propagation | header/root both directions, nested/sibling headers, conditionals, undef/redefinition, LF/CRLF |
| 37–40: negative/CLI/provenance | opaque negatives, real subprocess matrix, authored byte spans and no synthetic inherit |

All P2F1–P2F9 regression classes are explicitly rerun (AuditBlockerRegressionTests and P2F2–P2F9).
Their output confinement, closed schema, exclusions, continuation/direct shadow, FR-01/FR5-01,
echo and include protections remain tested. Ordinary/unused P2F9 controls stay green.

Some old expectations are deliberately stricter under the owner's P2F10 policy: P2F5/P2F7
parameter-dependent setter macros formerly retained inherit, but now reject candidate admission;
P2F9 ambiguous/cyclic/function-like identity macros now reject rather than only suppress create.
A real inherit-alias identifier in a helper body is no longer an opaque mention. Simple aliases,
undef-only controls, comments/string/heredoc/echo negatives and unused definitions keep their
prior safe behavior. The real keep2 fixture now follows the compound-macro policy below.

## Real CLI matrix

210 fresh external TemporaryDirectory CLI subprocess cases: 21 families × five layouts × LF/CRLF.
Layouts are inline, header definition, nested definition, root-definition/header-use and sibling
header use. Root-create mutation families keep their use in root create in each layout; helper
signature/body families exercise the reverse and sibling directions directly.
Families include parameter injection, set/add/delete/create, body escape, hidden function/inherit,
function-like, chain/cycle, conditional/undef, type/constants/helper controls, unused dangerous
definitions, contained calls, inert function-like, suffix and opaque payloads.
Every row records exit/candidate/status/fact fields/finding codes and input bytes/hash.
The focused class independently runs 54 subprocess cases (nine hazards × three layouts × LF/CRLF).

CLI summary: `{"exits": {"0": 210}, "statuses": {"OUT_OF_SCOPE": 74, "PARTIAL": 136}, "total": 210, "unsafe_facts": 0}`. State cases retain only inherit;
structural/unknown cases have no facts; safe cases retain all nine authored fields. All byte-span
and root-hash checks pass.

## Fresh actual C/H inventory

Re-read all 1,817 C/H files: 1,807 lexable, ten lexically unavailable; structural-unavailable
roots/dependencies are reported separately, never counted as zero. Found 686 definitions
(639 object-like, 47 function-like). Every lexable C/H root received a fresh resolved-unit walk.
The candidate inventory covers the previous 499 supported ROOM roots and their resolved includes;
counts below are actual identifier occurrences per compilation unit, not unique macro names.

| Previous 499 candidates + includes | Occurrences |
| --- | --- |
| Signature uses | 0 |
| Create-body uses | 76 |
| Other-body uses | 51 |
| Inert signature uses | 0 |
| Unknown signature uses | 0 |
| All inert uses | 71 |
| All unknown uses | 56 |
| Create-state hazards | 0 |
| Explicit structural hazards | 0 |
| Alias-chain uses | 56 |
| Function-like uses | 0 |
| Cycle uses | 0 |
| Candidate objects / fact sets changed | 14 / 14 |

All-unit counts (each root plus resolved includes; dependencies can recur across roots):

```json
{
  "regions": {
    "statement": 148,
    "body": 1419,
    "create": 321,
    "inherit": 290
  },
  "effects": {
    "UNKNOWN": 1314,
    "INERT": 848,
    "STRUCTURAL_BOUNDARY_HAZARD": 16
  },
  "inert_signature": 0,
  "uncertain_signature": 0,
  "create_state": 0,
  "alias_chain": 1215,
  "function_like": 205,
  "cycle": 0
}
```

All 14 changed objects use compound ANSI aliases defined in
[ansi.h](../../reference/es2/mudlib/include/ansi.h), such as `HIW -> ESC + "[1;37m"` and
`NOR -> ESC + "[2;37;0m"`, with `ESC` a string. The classifier intentionally does not prove
compound-expression inertness or evaluate concatenation: those reachable replacements are
UNKNOWN. This is conservative exclusion, not a claim that ANSI strings really inject structure.
The semicolon inside a quoted ANSI string is not treated as punctuation. Single-string constants
remain inert. No artificial preservation of the old 499 count was applied.

## Every changed object

Each row changes candidate true/PARTIAL to candidate false/OUT_OF_SCOPE, with facts `[]`.
The prior field sequence is shown in authored order, including repeated exits; all 68 prior facts
in these rows are removed. No other object or finding set changed. Each listed use is UNKNOWN
through an ANSI compound alias chain. Complete before/after fact values, IDs, provenance, findings
and exact use byte ranges are retained in local `pre-inventory.json` and repeated `post-inventory.json`.

| ROOM path | P2F9 fact fields | Exact macro use sites (line:name; root source) |
| --- | --- | --- |
| `d/canyon/canyon4.c` | inherit, short, long, exit, exit, exit | 46:HIB (body, byte 1140); 46:HIW (body, byte 1169); 46:HIB (body, byte 1176); 46:NOR (body, byte 1195); 47:HIW (body, byte 1224); 47:NOR (body, byte 1291); 48:HIW (body, byte 1320); 48:NOR (body, byte 1387); 49:HIW (body, byte 1416); 49:NOR (body, byte 1483); 50:HIC (body, byte 1512); 50:HIW (body, byte 1519); 50:NOR (body, byte 1575); 51:HIW (body, byte 1604); 51:NOR (body, byte 1671); 52:HIW (body, byte 1700); 52:NOR (body, byte 1767); 53:HIW (body, byte 1796); 53:NOR (body, byte 1863); 54:HIW (body, byte 1892); 54:NOR (body, byte 1959); 55:HIW (body, byte 1988); 55:NOR (body, byte 2055) |
| `d/choyin/club.c` | inherit, short, long, exit, exit, no_fight, no_clean_up | 96:NOR (body, byte 2559); 100:HIC (body, byte 2725); 100:NOR (body, byte 2761) |
| `d/chuenyu/trap_castle.c` | inherit, short, long, exit, outdoors | 45:HIW (body, byte 1282); 46:NOR (body, byte 1465) |
| `d/city/boots.c` | inherit, short, long, exit | 33:HIY (body, byte 761); 33:NOR (body, byte 787) |
| `d/city/cloth.c` | inherit, short, long, exit | 34:RED (body, byte 840); 34:NOR (body, byte 877) |
| `d/green/water.c` | inherit, short, long, exit, exit | 43:HIW (body, byte 932); 43:NOR (body, byte 946) |
| `d/latemoon/gate.c` | inherit, short, long, exit, exit, outdoors | 19:BRED (create, byte 539); 19:HIW (create, byte 544); 19:NOR (create, byte 605) |
| `d/latemoon/latemoon3.c` | inherit, short, long, exit | 30:NOR (body, byte 747); 33:HIC (body, byte 853); 33:NOR (body, byte 892) |
| `d/latemoon/latemoon8.c` | inherit, short, long, exit | 50:HIM (body, byte 1495); 50:NOR (body, byte 1521); 55:HIM (body, byte 1776); 56:NOR (body, byte 1813) |
| `d/latemoon/miroom.c` | inherit, long, exit | 8:HIY (create, byte 84); 8:NOR (create, byte 97); 52:HIG (body, byte 1466); 53:NOR (body, byte 1503) |
| `d/latemoon/park/paroad2.c` | inherit, short, long, exit, exit | 36:HIM (body, byte 913); 37:NOR (body, byte 995) |
| `d/latemoon/room/bathroom.c` | inherit, short, long, exit | 42:HIG (body, byte 1029); 42:NOR (body, byte 1083) |
| `d/latemoon/room/bathroom1.c` | inherit, short, long, no_fight, exit, exit | 34:HIG (body, byte 927); 34:NOR (body, byte 984) |
| `d/oldpine/keep2.c` | inherit, short, long, exit, exit | 40:HIY (body, byte 824); 40:NOR (body, byte 939) |

## Complete local verification

Pre-commit local verification passed:

| Check | Result |
| --- | --- |
| P2F10 focused regressions | 54 tests PASS |
| Explicit P2F1–P2F9 classes | 123 tests PASS |
| `python -m unittest discover -s tools/tests -p "test_migration_tooling.py" -v` | 242 tests PASS |
| `python -m unittest discover -s tools/tests -p "test_*.py" -v` | 288 tests PASS |
| `python tools/ci/repository_checks.py --repository .` | PASS |
| `git diff --check` | PASS |
| Actual CLI / actual inventory / corpus A/B | PASS |
| Confinement / closed schema / historical compatibility / frozen integrity | PASS |

This report is committed with the fix. Exact-commit execution must rerun the entire set above
after the one commit, including provenance/quarantine and audit hashes, before push. Its receipt
records the new exact HEAD in ignored local `build/migration-tooling-v1/p2f10/post-verification.json`;
the completion message supplies that verified SHA. The report does not substitute pre-commit
results for that gate. No remote CI is run or claimed. This parser/tooling-only change does not
require live Godot gameplay; none was used as evidence.

Complete canonical historical generated documents for versions 1.0.0 through 1.0.10 were copied
to external temporary output roots and replaced by actual CLI runs: eleven PASS, originals unchanged.
Unknown/manual/reviewed/future-version/empty/malformed outputs each return exit2, writer not called,
original bytes unchanged. Eight forbidden output paths, external/build safe outputs, 33 nested
manual-field locations, invalid-UTF8 raw_hex and another checkout's tracked output protection pass.

## Whole corpus A/B and provenance

Two independent real CLI runs against `reference/es2` each return exit1 because of the unchanged
source quarantines. Counts are measured; not forced to the P2F9 baseline.

| Metric | P2F9 | P2F10 A = B |
| --- | --- | --- |
| Scanned | 2336 | 2336 |
| Supported | 499 | 485 |
| EXTRACTED | 0 | 0 |
| PARTIAL | 499 | 485 |
| OUT_OF_SCOPE | 1824 | 1838 |
| QUARANTINED | 13 | 13 |
| Facts | 2804 | 2736 |
| Findings | 4457 | 4296 |
| Bytes | 10030223 | 9808627 |

A bytes = B bytes; A SHA = B SHA = `f97468b5d7da5200c85e2331e2f576a7a728d3c209df7f203a5cfda6ebc6aaa1`.

Finding-code distribution:

```json
{
  "CALLBACK_BEHAVIOR": 284,
  "DRIVER_SEMANTICS_UNKNOWN": 408,
  "DYNAMIC_EXPRESSION": 10,
  "ORDER_SENSITIVE_MUTATION": 30,
  "OUT_OF_SCOPE": 1319,
  "REQUIRES_SEMANTIC_REVIEW": 1623,
  "RNG_SEMANTICS": 58,
  "SOURCE_ENCODING_ISSUE": 8,
  "SOURCE_SYNTAX_ERROR": 5,
  "UNRESOLVED_INCLUDE": 97,
  "UNRESOLVED_INHERITANCE": 14,
  "UNSUPPORTED_CONSTRUCT": 440
}
```

Fresh authored provenance checks: `{"crlf_source_records": 3, "direct_inherit_provenance": 1799, "fact_provenance": 2736, "finding_provenance": 4296, "normalization_input_provenance": 756, "provenance_records": 9587, "unicode_span_records": 1239, "unreviewed_records": 7032}`.

All 9,587 spans match original root byte slices, raw/hash, line/column and relevant fact IDs;
normalization input spans remain authored. No replacement-view bytes enter IR provenance.
All 1,799 direct-inherit records remain byte-identical to P2F9; no hidden/injected inherit is added.
Manifest ordering, coverage, finding IDs/references and UNREVIEWED state pass.
The 2,336-file raw path/NUL/hash/LF manifest remains
`744e33e1740db7909129a3ae5e295158341b5012a411af953b144a5075bb0a80`.
The extractor-relative manifest remains
`895d36086e184ba6bf520625c20e882394a0a6169aabf86a1b4c58ba835e2820`.

## Exact quarantine comparison

All thirteen quarantine paths, source hashes, reason strings and provenance records equal P2F9.
There are eight SOURCE_ENCODING_ISSUE and five SOURCE_SYNTAX_ERROR records; every quarantined
object has zero facts. Macro uncertainty introduces zero new syntax/encoding quarantines.

| Source path | Finding | Exact reason |
| --- | --- | --- |
| `cmds/std/exercise.c` | SOURCE_ENCODING_ISSUE | NUL or replacement character in source |
| `d/choyin/npc/yamen_po.c` | SOURCE_ENCODING_ISSUE | NUL or replacement character in source |
| `d/latemoon/sroad1.c` | SOURCE_SYNTAX_ERROR | unterminated string |
| `d/latemoon/upstar/upcenter.c` | SOURCE_ENCODING_ISSUE | NUL or replacement character in source |
| `d/npc/oldman.c` | SOURCE_SYNTAX_ERROR | mismatched delimiter |
| `d/temple/npc/obj/magic_book.c` | SOURCE_ENCODING_ISSUE | NUL or replacement character in source |
| `d/temple/npc/obj/spells_book.c` | SOURCE_ENCODING_ISSUE | NUL or replacement character in source |
| `d/temple/obj/magic_book.c` | SOURCE_ENCODING_ISSUE | NUL or replacement character in source |
| `d/temple/obj/spells_book.c` | SOURCE_ENCODING_ISSUE | NUL or replacement character in source |
| `d/village/lordhouse3.c` | SOURCE_SYNTAX_ERROR | mismatched delimiter |
| `u/cloud/npc/goddd.c` | SOURCE_SYNTAX_ERROR | unterminated string |
| `u/cloud/obj/npc/flower_girl/guihua.c` | SOURCE_ENCODING_ISSUE | NUL or replacement character in source |
| `u/cloud/obj/sword_book.c` | SOURCE_SYNTAX_ERROR | mismatched delimiter |

## Eight frozen blocked audits

`P2F9_BLOCKED_AUDIT_START_SHA` is
`ed1721c2de295defb3d7ada595fe73a4db199462a3ef97b61540782d96bc95a4`.
All eight files below remain untracked, unstaged and byte-identical; they are not part of this commit.

| File under docs/migration | SHA-256 |
| --- | --- |
| `MIGRATION_TOOLING_V1_FINAL_AUDIT.md` | `a61cd221e8b70961d963484dfe953f5e341511967d9cfd66a55159b1bab85d63` |
| `MIGRATION_TOOLING_V1_FINAL_RE_AUDIT_AFTER_P2F4.md` | `c4ff8faccea5b79d0ba4007d2d616007f4a55fda3b84e58e78875d68f4e4aed0` |
| `MIGRATION_TOOLING_V1_FINAL_RE_AUDIT_AFTER_P2F5.md` | `0d93333f8db116db7f6af0cb79e201b26228010cc5e85592adf30cdeb4c94be9` |
| `MIGRATION_TOOLING_V1_FINAL_RE_AUDIT_AFTER_P2F6.md` | `8a9ba2d9bfd666b949b470d872820c63d5adeab26d849deef7e4460b45593b76` |
| `MIGRATION_TOOLING_V1_FINAL_RE_AUDIT_AFTER_P2F7.md` | `939c23c9ac71749fc815cbfadcc147407d40024efe353edf0090971cdb5a9d38` |
| `MIGRATION_TOOLING_V1_RE_FINAL_AUDIT.md` | `c67dc612139bf37a6c6a41d4753b58723b154d0f6e92cdca0ab5a34ad93d0548` |
| `MIGRATION_TOOLING_V1_FINAL_RE_AUDIT_AFTER_P2F8.md` | `0734b90e65cb05d0ff4fd9eb701871234472f608b4350f48460b2e63fef12419` |
| `MIGRATION_TOOLING_V1_FINAL_RE_AUDIT_AFTER_P2F9.md` | `ed1721c2de295defb3d7ada595fe73a4db199462a3ef97b61540782d96bc95a4` |

## File scope and owner gate

Exactly five tracked paths comprise the repair: `tools/migration/room_extractor.py`,
`tools/tests/test_migration_tooling.py`, this phase report, and minimal
[STATUS](../production/STATUS.md) / [ROADMAP](../production/ROADMAP.md) updates.
No reference/game/Save/CI/DECISIONS/fixture changes; no additional dependency.
Disposable evidence/scripts stay under ignored `build/migration-tooling-v1/p2f10/`.

Implementation is ready for owner review. Milestone integration remains blocked pending owner
review and an explicitly authorized complete Final Re-Audit. No Final Re-Audit verdict is issued
here. No phase PR, merge, new remote CI or P3 work is authorized or performed. Main remains frozen.
After the one verified commit is pushed, STOP.
