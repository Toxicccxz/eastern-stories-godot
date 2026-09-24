# Migration Tooling v1 — P2F26 Macro-Supplied Critical Function Identity Preflight

**P2F26 FIX IMPLEMENTED — AWAIT OWNER REVIEW / FINAL RE-AUDIT NOT YET AUTHORIZED**

## Authorization / frozen identities

Owner-authorized repair of FR25-01 / HIGH / D2-D3, continued through Attempt 3 on
`phase/migration-tooling-v1`. Frozen main/merge-base:
`cd07808cb76147d0b8c0dad9b82d078b49fefe64`. Pre-fix HEAD, fetched origin phase and
required single-commit parent: `eff4823aed39c0bcec6f869b023fdab2cc350f3f`
(`Preflight directive-sensitive inherit structure`). Fetch, identities, empty index
and all-state phase PR absence were verified. The unstaged candidate was continued;
no reset/restore/stash/clean, history rewrite or separate P2F27 was used.

Exactly five tracked files are authorized: extractor, existing test module, this
report, [STATUS](../production/STATUS.md), [ROADMAP](../production/ROADMAP.md).
[D1–D9](DECISIONS.md#migration-tooling-v1-p2--owner-locked-extraction-boundary) stay
locked. P2F25 is CLOSED; the historical Final Re-Audit after P2F25 remains BLOCKED.
This is implementation verification, not the next Final Re-Audit.

## FR25-01 root cause

The old pre-segmentation gate recognized only authored literal set/create. An
actual macro supplying either identity could lose its signature context at a
directive; later macro hazard handling then missed the override/duplicate create
and admitted unreliable create-derived facts. The repair refuses the whole object
before raw segmentation, inheritance facts, create dispatch or exit staging.

## Attempt-1 blocked regression / why generic reach was unsuitable

Attempt 1 fixed the sixteen original unsafe executions but over-refused
`mixed helper EMPTY`. Generic `MacroSummary.reach().uncertain` includes empty and
atomic replacements, which is not proof that they can supply a critical identity.
Attempt 2 introduced a dedicated identity summary without changing generic reach.
Its helper/EMPTY correction is retained. The complete blocked Attempt-1 report was
copied byte-for-byte before Attempt-2 edits, raw SHA-256
`7f409e5b5c9e2a1040afba20bdcf1d809c583e5ef934a2848d21bb1fc5ecfced`.

## Attempt-2 blocked regression / why NONCRITICAL was insufficient

Attempt 2 treated a safely noncritical identifier as the function name even when
it represented a return type. `TYPE -> mixed` before literal set/create closed the
name position prematurely, regressing the frozen parent's literal-critical gate.
Independent `RETURNS -> TYPEOF -> mixed` reproduced the same escape. Attempt 2
stopped without commit. Before Attempt-3 code edits, its report was copied exactly,
SHA-256 `af444e4a6022a1a823b1795d41fe4319e15aa4321dc5328e11da54bd8bec13a6`.
Neither implementation-attempt regression adds a historical semantic blocker number.
Both blocked copies remain owner-local, untracked and unstaged.

## Dedicated roles / declaration-prefix category

The single identity helper now summarizes structural role, not general macro
semantics. `FUNCTION_DECL_PREFIXES` explicitly contains only void, int, string,
object, mapping, mixed, float, status, static, private, protected, public, nomask,
varargs and nosave. It excludes inherit, set, create and ordinary names.

| Bounded result | Role / action |
| --- | --- |
| Empty replacement | EMPTY: no name token, continue |
| Single-name chain to the exact type/modifier set | PREFIX: continue to the name |
| Literal or reachable set/create | SET/CREATE: critical name |
| Single-name chain to an ordinary helper identifier | NONCRITICAL: close name position |
| Multi-token, parameter-dependent, paste, invalid or cyclic relationship | UNKNOWN: conservatively assess possible function structure |
| Number/string/character before a name | UNKNOWN: neither a declaration prefix nor a name |

All applicable definitions participate. All empty/prefix outcomes remain prefix-like
when authored cursor advancement agrees; all safe helper names close the name slot.
Empty/name, prefix/name and critical/prefix disagreements are structural UNKNOWN.
A critical/name-only mixture retains a critical result. Different possible call
ownership never authorizes a guessed cursor advance.

## Function-name slot state machine

The shared scanner uses DECLARATION_PREFIX, FUNCTION_NAME and AFTER_NAME. Known
authored or macro-supplied types/modifiers, plus proven empty prefixes, continue the
search. A definite helper owns the name position and prevents suffix macros from
being reconsidered. Critical/unknown identities inspect authored groups and
preprocessing-sensitive gaps. Semicolons and completed bodies reset the state;
matched group interiors, strings, comments and directive payloads stay opaque.

An uncertain role can still be a prefix before a later authored name; it must not
prematurely close that possibility. Unsupported prefix punctuation also remains
structurally unknown. No pointer/reference or general declaration grammar is added.
A standalone directive before a declaration or after a complete body does not
become an in-signature gap.

## Actual macro use / call ownership / alias iteration

Object aliases consume no authored group. Applicable function-like definitions
consume their own immediate matched group, exactly once. Later callable stages may
consume further adjacent groups before the structural gap; no argument list is
reused. Authored uninvoked function-only names do not supply replacement identity.
An unresolved returned callable remains uncertain. Arguments remain opaque.
Single-name relationships and cycles are processed iteratively; 1100-stage controls
terminate deterministically. There is no expansion, substitution or synthetic token.

## Signature gaps / full-object refusal

Both name-to-parameters and parameters-to-body gaps, including multiple directives,
are covered for literal and macro-supplied set/create. A hit clears inheritance and
category metadata and returns candidate=false, OUT_OF_SCOPE, facts=[] before any
fact allocation. No setter recovery, winning-create selection or emit-then-delete
rollback is used. No-directive macro-critical and macro-type controls preserve
their historical safe object/findings exactly.

## Root / dependency consistency and provenance

The unchanged P2F24 reached-unit iteration applies one shared scanner to root,
local/nested/standard/cross/nested-cross headers with the current bounded macro
context. No unit concatenation or include splicing occurs. Unreferenced headers
have zero effect. Root critical findings use the real authored function name or
name macro plus its structural witness; a known TYPE prefix does not masquerade as
the function name. Dependency findings use the real root include origin, never a
header offset applied to root bytes. No replacement-derived span is emitted.

## TYPE/set/create and RETURNS closure — first gate

Thirteen focused methods pass. Immediately afterward the mandatory primary
TYPE/mixed/set, TYPE/void/create and independent RETURNS alias sources pass in
LF/CRLF: six CLI executions, full refusal. The exact eight-case Attempt-2 supplement
and two-case independent alias confirmation also pass. Product tests fail if
positive structural cases allocate facts and separately verify root/include spans.

## Attempt-1 helper closure — second gate

The exact FR24 90-CLI matrix runs next; B23 helper EMPTY LF/CRLF matches complete
frozen P2F25 object/findings. Independent NOTHING/harmless root/dependency controls
also match the frozen parent loaded separately from exact Git object bytes.
Helper names followed by empty, type-like or unknown macros gain no spurious
critical-refusal findings. Known type/modifier prefixes before helpers remain safe.

## Attempt-3 prefix ownership sweep / ambiguity policy

New handwritten oracles cover 158 shapes / 316 CLI: type/modifier aliases, empty
prefixes, helper suffixes, critical name aliases/functions, both signature gaps,
prefix/name, empty/prefix, empty/name, prefix/critical and empty/critical ambiguity,
multi-token and parameter-dependent prefixes, all fifteen exact prefix terminals,
normal/no-directive controls and reached-header arrangements. Every negative
compares complete frozen-parent object/findings; every positive fully refuses.

Two semantic oracle refinements were made before execution, as expressly required
by the continuation instructions: Attempt-2 all-helper competing/mixed definitions
are NONCRITICAL (four shapes in the retained expansion); Attempt-3 atomic
number/string/character before the name are UNKNOWN (six root/header shapes in the
68-CLI over-refusal matrix). Neither is a post-failure snapshot rewrite. Historical
attempt evidence is preserved. During pre-gate code review, critical/prefix role
ambiguity and unsupported punctuation were refined; interrupted preparatory runs
are not final acceptance evidence. The complete run below uses the final code.
The first nested-matrix launch stopped before behavioral assertions because the
new evidence directory lacked seven copied historical fixture files. Those files
were restored byte-identically, and current-version labels in two retained scripts
were corrected from 1.0.25 to 1.0.26. The runner resumed at the affected matrix;
no production code, source fixture or semantic expectation changed. The failed
bootstrap receipt and fixture hashes remain in ignored evidence.

## Original FR25 / retained repair matrices

FR25 passes 276 CLI: 220 structural, 8 independent, 48 B01–B24 siblings. All sixteen
old unsafe executions now fully refuse; 248 historical outputs are exact. Twelve
previously safe B06/B07/B08/B10/B11/B12 LF/CRLF outputs use the authorized earlier
refusal with cleared metadata. Original 366-CLI audit coverage includes FR24's 90.

| Family | Fresh standalone CLI |
| --- | --- |
| P2F26 retained expansion / independent | 402 / 60 |
| Attempt-2 over-refusal / balanced consolidation | 68 / 178 |
| P2F25 expansion / independent | 320 / 48 |
| FR23 / P2F24 original, root, independent, dependency, second independent | 84 / 348 / 58 / 216 / 64 |
| P2F23 prefix / expansion | 46 / 98 |
| P2F22 keyword / expansion | 46 / 82 |
| P2F21 original / expansion / primary | 72 / 84 / 4 |
| P2F20 original / key / expansion | 94 / 500 / 294 |
| P2F19 create / primary / sibling / expansion | 270 / 4 / 56 / 110 |
| P2F18 nested / P2F17 mapping | 148 / 156 |
| P2F11–P2F16 retained CLI / directive / delimiter | 492 / 204 / 118 |

Forty key traces and twelve finalizer-independence probes also pass. No historical
repair test was removed or autoaccepted. Standalone CLI total, including all
mandatory and supplementary P2F26 gates: **5422**.

## Fresh full suites / production scope

All **48 pre-commit groups** pass. Focused P2F26: **13**; retained P2F1–P2F25 repair
methods: **371**; migration suite: **449**; full Python suite: **495**. Repository
checks and diff whitespace checks pass. Pure parser scope does not require live Godot.

AST self-review confirms only one existing production method changes and one helper
is added, plus the exact prefix set and version constants. The P2F25 inheritance
state machine and P2F24 unit loop/origins are preserved. Generic reach/effect,
macro regions, lexer, CLI/writer, create-tail, mapping, key/receiver classifiers,
exit staging/finalizer, imports and other methods remain unchanged.
Source authority includes the local LPC [define reference](../../reference/es2/mudlib/doc/lpc/preprocessor/define)
and [function syntax](../../reference/es2/mudlib/doc/lpc/constructs/function).
No external implementation, driver execution, full grammar or function recovery.

## Version compatibility / closed schema / output security

Version remains **1.0.26**, known **1.0.0–1.0.26** (27), schema1/static-room-v1
unchanged. Fresh actual canonical replacement of every historical version passes;
original artifacts are untouched. Invalid manual/reviewed/future/unknown/malformed/
empty documents and all discovered nested metadata positions refuse with exit2,
no writer call and identical target bytes. Retained confinement/atomic-write and
supported symlink/junction checks, protected/tracked targets, approved build/external
outputs and invalid-UTF8 raw_hex validation pass in the suites/security matrix.

## Whole corpus A/B / semantic delta / manifest

Two independent complete CLI scans exit1 and are byte-identical: **9808627 bytes**,
SHA-256 **`a623125fe38df549c8f7815c98e1258f02c3b0f1e5fa9fa9b94d4d87a2427537`**.

```json
{
  "summary": {
    "scanned_files": 2336,
    "supported_candidates": 485,
    "statuses": {
      "EXTRACTED": 0,
      "PARTIAL": 485,
      "OUT_OF_SCOPE": 1838,
      "QUARANTINED": 13
    },
    "total_findings": 4296,
    "finding_codes": {
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
  },
  "facts": 2736,
  "provenance": {
    "provenance_records": 9587,
    "direct_inherit_provenance": 1799,
    "unreviewed_records": 7032,
    "fact_provenance": 2736,
    "unicode_span_records": 1239,
    "normalization_input_provenance": 756,
    "crlf_source_records": 3,
    "finding_provenance": 4296
  }
}
```

Compared against exact P2F25 canonical output bound to `eff4823...`, there is
zero semantic delta. Removing only extractor_version makes complete documents
equal: no new candidate/fact/exit, unrelated status change, or changed safe ID.
The zero delta is observed, not achieved by changing source expectations.

## Thirteen quarantines / fourteen ANSI exclusions

The exact thirteen quarantines retain empty facts and identical reasons/spans:
eight actual encoding defects and five syntax defects. Self-audit independently
checks the NUL/replacement bytes, two malformed quote lines and three unmatched
closures. All fourteen historical ANSI exclusions remain candidate=false,
OUT_OF_SCOPE, facts=[], not QUARANTINED. Per-source evidence is in the ignored
corpus/delta/self-audit receipts; no quarantine behavior is silently changed.

## Provenance / fact-ID / summary integrity

All 2336 inputs, source hashes, exact byte spans/raw text, line/column, normalization
inputs, ordinals, fact identities, finding references and manifest/summary counts
are checked. No ghost/orphan/duplicate IDs or dangling references. Review state
remains UNREVIEWED. Refusal precedes fact allocation; suppressed facts receive no
IDs. Root TYPE/name provenance and dependency root-include provenance are separately
tested. Helper controls preserve complete parent findings.

## ARCHIVE-01 / source immutability

ARCHIVE-01 remains CLOSED. Ten tracked historical audit hashes and working/index/HEAD
archive bytes are preserved. P2F10: 24417 bytes / 468 CRLF, hash
`56e1cd0aa0a573bc4a9505fb5df6bd1cfbd0076849a40f6bd4a4420483cb2213`;
tracked P2F11 `48f07085604905ef3d603474bae86fb028cff9bbc1088a83769eee16babe9155`;
attributes `b33913bb7279e1ab67762574ab277828a9fd114dae23dceace2f24ae842194d6`.
Reference tree `4106480ab28cce8cd7b55704f8ae9ae062d42d03`; raw 2336-file manifest
`744e33e1740db7909129a3ae5e295158341b5012a411af953b144a5075bb0a80` unchanged.
No legacy source, game, runtime schema, workflow or generated corpus is modified/tracked.

## Nineteen owner-local historical evidence hashes

All remain untracked/unstaged and byte-identical in `docs/migration/`.

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

## Exact-commit gate / residual boundaries / owner gate

Pre-commit results above bind the final candidate bytes. After one authorized
commit, every one of the 48 groups must run again on its immutable SHA before push.
Ignored `build/migration-tooling-v1/p2f26-attempt3/` contains pre/post logs, handwritten
oracles, per-case receipts, corpus/security/compatibility results, nineteen evidence
hashes and five staged-file hashes. `exact-commit-receipt.json` records the final
SHA without a self-referential report amend. Completion additionally requires remote
phase SHA agreement and unchanged frozen main.

This remains bounded static role classification, not a preprocessor/compiler.
Macro conditions/scoping, expanded declarations, complex type grammar and runtime
execution are outside scope. UNKNOWN structures conservatively refuse; confirmed
contract defects are not accepted residual risks. Structural-Preprocessing
Consolidation Final Audit is still required; Systematic Quarantine-Path Audit remains
INCOMPLETE. No PR, merge, remote CI, P3 or next Final Re-Audit is authorized.
The milestone is not fully integrated on main.

**READY FOR OWNER REVIEW / FINAL RE-AUDIT AUTHORIZATION — STOP**
