# Migration Tooling v1 — Final Milestone Audit

## 1. Executive verdict

**BLOCKED — NOT READY FOR PR. HIGH blockers = 2.**

Fresh tests and whole-corpus output reproduce P2's evidence, but independent adversarial checks
find two material contract failures: repository output confinement can be bypassed, and continued
critical macro declarations bypass shadow detection. Three additional medium defects are recorded.
Passing the existing62/108 tests does not resolve these findings.

This audit changes no production code, tests, fixtures, schema, reference, game, CI or configuration.
No LPC is executed. Dangerous output probes intercept the writer; no probe writes into game/reference.
P1 and P2 are OWNER APPROVED / CLOSED; D1–D9 are LOCKED, as specified by this audit's owner instruction.
That approval does not remove newly discovered integration blockers. PR, merge and P3 remain unauthorized.

## 2. Frozen identities and authority

Audit date: 2026-09-15. Repository: Toxicccxz/eastern-stories-godot.

| Identity | Verified value |
| --- | --- |
| Branch | phase/migration-tooling-v1 |
| Main/base/merge-base | cd07808cb76147d0b8c0dad9b82d078b49fefe64 |
| Local executable HEAD / origin phase | 8efc21ff8aa4c4c293347386f951631c56559fe2 |
| Initial worktree/index | Clean/clean |
| Phase PR search | No PR returned, including closed/open states |
| Source Git tree | 4106480ab28cce8cd7b55704f8ae9ae062d42d03 |

Fresh fetch matched every frozen identity. Root/docs AGENTS, DECISIONS, STATUS, ROADMAP,
[P1 analysis](MIGRATION_TOOLING_V1_P1_ANALYSIS.md),
[P2 report](MIGRATION_TOOLING_V1_P2_STATIC_ROOM_EXTRACTOR.md),
[repository policy](../production/REPOSITORY_POLICY.md),
[architecture](ES2_ARCHITECTURE_ANALYSIS.md), existing tooling conventions and the previous
[Snow final audit](PHASE_SNOW_FIRST_PROGRESSION_FINAL_AUDIT.md) were reviewed.
Current explicit owner decisions override historical P1 recommendations/checkpoints.

## 3. Full commit history

| Order | Commit | Subject |
| --- | --- | --- |
| 1 | 0e5ff6a5cbc8d4091102e280c66868ba8763b4bb | Analyze Migration Tooling v1 extraction contract |
| 2 | 8108763d6a4ddb3ad2b110200666424f4042e296 | Record Migration Tooling v1 P2 decisions |
| 3 | 8efc21ff8aa4c4c293347386f951631c56559fe2 | Add Migration Tooling v1 static room extractor |

All three phase commits were audited, not just the implementation commit. History was not rewritten.

## 4. Full milestone diff

Frozen main...P2: **13 files, +2,276 / -11**.

| Category | Files | Additions/deletions |
| --- | ---: | ---: |
| P1/P2 analysis/report docs | 2 | +852 / -0 |
| DECISIONS, STATUS, ROADMAP | 3 | +87 / -11 |
| Migration package code | 4 | +819 / -0 |
| Migration unittest module | 1 | +475 / -0 |
| Fixture, projection golden, fixture README | 3 | +43 / -0 |
| Game/runtime/gameplay tests/Save schemas | 0 | 0 |
| reference/es2 | 0 | 0 |
| .github/build/config | 0 | 0 |

Code files are tools/migration/{__init__,es2_source,room_extractor,cli}.py; tests are
tools/tests/test_migration_tooling.py; fixture files are under tools/tests/fixtures/migration_v1/.
This new audit document is separate from that frozen13-file comparison.

## 5. D1–D9 compliance

| Decision | Verdict | Evidence |
| --- | --- | --- |
| D1 stdlib/location | PASS | Python3.12.14; AST import audit finds only stdlib/relative package imports; no Godot runtime dependency |
| D2 supported admission | BLOCKED | FA-02 critical macro continuation, FA-03 excluded literal inheritance, FA-04 unresolved include admission |
| D3 bounded facts | BLOCKED | Field allowlist exists, but FA-02 emits facts despite unresolved critical setter/base context |
| D4 independent IR | PASS | schema1/static-room-v1, ordered arrays, typed decimal-string literals; no Save schema change |
| D5 exact provenance | PASS | All7,164 emitted fact/finding source spans checked independently against original bytes |
| D6 no guessing/evaluation | BLOCKED | No eval/exec/LPC execution, but FA-02 still normalizes __DIR__ under missed critical shadowing |
| D7 generated-output boundary | BLOCKED | Actual smoke outputs ignored; FA-01 allows targets outside approved repository output subtree |
| D8 unittest/expected data | PASS, coverage gaps | Small independently authored golden, stdlib tests; missing cases documented below |
| D9 exits/failure | BLOCKED | FA-01 unsafe target reaches writer with exit0; FA-05 computed expression incorrectly gets source-error exit1 |

## 6. HIGH FA-01 — ancestor output root bypasses repository target protection

Location: [cli.py](../../tools/migration/cli.py), lines21–30, especially29.
The repository restriction checks **output_root**, not the resolved **target**. If output_root
is the repository's parent, it is outside REPOSITORY and that guard is skipped. With a valid source
root in an unrelated temporary directory, the source/output overlap check also passes.

Reproduction configuration, all paths derived rather than workstation-specific:

```text
source_root = a temporary directory outside the repository ancestor, containing d/probe.c
output_root = REPOSITORY.parent
output = REPOSITORY / "game/audit-probe-never-written.json"
```

`destination()` accepts that path. It also accepts a new target under reference/es2 with the same
configuration. The tracked-file guard does not reject a new untracked filename.
An end-to-end `cli.main()` probe with `atomic_write` intercepted by unittest.mock returned **0**,
called the writer with the game target, and emitted a successful scan summary.
The intercept prevented all writes; the target remained absent before and after the probe.

Expected: reject the protected resolved target before writer invocation, exit2, regardless of
whether an explicitly supplied output root is a repository ancestor. An explicit output root
does not authorize generated artifacts in game/reference. This is a deterministic validation
bypass, not the already disclosed concurrent-filesystem race limitation.

Correction and regression tests require separate owner authorization. No fix was made here.

## 7. HIGH FA-02 — continued critical directives evade shadow detection

Locations: [es2_source.py](../../tools/migration/es2_source.py) directive capture, lines123–136;
[room_extractor.py](../../tools/migration/room_extractor.py), directive_parts and lines148–155,
258–260, 284 and368–375.

In-memory source reproducer at logical d/audit/probe.c:

```c
#define \
ROOM NPC
inherit ROOM;
void create() { set("short", "not reliably a room"); }
```

The lexer preserves the continued directive, but directive_parts leaves the backslash token;
include_hazards takes words[1] as the macro name. It therefore misses ROOM. Actual result:
supported_candidate=true, PARTIAL, emitted inherit + EXACT_LITERAL short, only generic unsupported
directive/semantic-inheritance findings. It does not produce the critical admission rejection.

The same shape with `set other` emits a short fact from an unproven setter. With
`__DIR__ "/other/"` and `set("exits", (["e": __DIR__"x"]));`, it emits the normalized target
`/d/audit/x` despite unresolved critical __DIR__ context.

The audit does not execute the macro or assume historical driver behavior. Even if this directive
shape is outside the implementation subset, the required conservative behavior is to withhold
unproven admission/facts/normalization. Generic PARTIAL does not turn an unsafe supported fact into
a proven static fact. Fixing this need not introduce macro execution or broaden LPC support.

## 8. MEDIUM FA-03 / FA-04 — additional admission gaps

FA-03, room_extractor.py lines223–228,254–260: excluded categories are compared only to macro-name
strings. `inherit ROOM; inherit "/std/char/npc"; void create(){set("short","mixed");}` is admitted,
emits two inherit facts and short, and is PARTIAL. The literal base is the exact NPC path documented
by reference/es2/mudlib/include/globals.h:65. It should not be treated as a supported ROOM/NPC mixture.
No full NPC object conversion is present, but the admission boundary is incomplete.

FA-04, lines258–260 versus284: `#include <absent.h>` followed by direct ROOM is still
supported_candidate=true and emits an inherit fact, although create field extraction is withheld.
The missing header could change ROOM; the audit contract requires no unresolved critical context
for supported admission. UNRESOLVED_INCLUDE correctly exists, but candidate/status admission is
not fully conservative. No such missing-include instance was reported in the current corpus run.

## 9. MEDIUM FA-05 — computed mappings incorrectly quarantined

Location: room_extractor.py lines347–352. The exit recognizer checks only the first/last two tokens,
then strips them as though they enclose the whole expression.

```c
inherit ROOM;
void create() {
    set("exits", (["e":"/a"]) + (["w":"/b"]));
}
```

Actual: QUARANTINED, no facts, SOURCE_SYNTAX_ERROR from delimiter checking of the incorrectly
sliced inner token list. A completed scan of this object returns exit1. Expected: no arithmetic
evaluation, explicit DYNAMIC_EXPRESSION/unsupported finding, PARTIAL and no syntax quarantine
solely because the expression is computed. Mapping addition is present in the authoritative corpus,
e.g. adm/daemons/network/dns_master.c:604,619 and cmds/wiz/mudlist.c:25.
This is a synthetic boundary reproduction, not an explanation of the13 current corpus quarantines.

## 10. Lexer/source model audit

Raw bytes, hashes, byte offsets, CRLF retention and codepoint indexes work for the current corpus
and focused cases. Comments/strings/character tokens, quoted-symbol unknowns, heredoc scalar/arrays,
terminator suffixes and delimiter pairing are separated without an LPC runtime. NUL/U+FFFD/invalid
UTF-8 are explicit failures. The implementation honestly disclaims full LPC grammar validation.
roommaker's two ROOM_CODE templates are not mistaken for actual inheritance.

Ordinary directive comments and body continuations have tests, but continuation before/inside a
critical macro name is missing. The lexical preservation passes; its hazard-analysis integration
is BLOCKED by FA-02. Unknown syntax must not acquire semantics merely because tokens were retained.

## 11. Create scope, text and flags

Reviewed outer create statement splitting, qualified receivers, conditional blocks, reset/init/
valid_leave bodies, duplicate create, local set definitions and source-order preservation.
Ordinary covered cases pass: only bare outer create setters yield fields; repeated setters remain
distinct; long is TEXT_ONLY; zero differs from absence; floats/octal/arithmetic/macros are not coerced.
Only outdoors/indoors/no_clean_up/no_fight are allowed. No inferred inverse/default flag appears.
Overall fact/scope assurance remains BLOCKED because missed critical macro context defeats the gate.

## 12. Static exits and dynamic behavior

Literal paths and narrow __DIR__ forms preserve raw direction/target and normalization metadata.
No reverse edge, repair, RNG draw, reachability or callback result is generated. Duplicate directions
remain ordered; reference status is descriptive. Local and cross-object mutations, create_door,
objects, random, call_out, add_action, replace_program, closures and foreign calls produce findings.
keep2 and pine3 preserve the intended static/dynamic distinction.
Overall exit audit is BLOCKED by FA-02's missed __DIR__ context and FA-05's false quarantine.

## 13. Findings and object status

All14 required FindingCode concepts exist as machine-readable enums. Current records include
severity, reason, object ID, blocking flag, provenance and UNREVIEWED. EXTRACTED/PARTIAL/
OUT_OF_SCOPE/QUARANTINED are bounded; no machine APPROVED state exists. Current out-of-scope and
quarantined objects have empty fact arrays. PARTIAL objects retain supported facts plus findings.
The representation passes; completeness/correct classification is BLOCKED in the reproduced cases.

## 14. Provenance audit

Independently verified **2,804 facts + 4,360 findings = 7,164 records** against raw source bytes:
SHA-256, start/end-exclusive range, raw/raw_hex, line, codepoint column and UNREVIEWED all match.
Current fact IDs distinguish identical statements at different offsets. The focused CRLF/Chinese
cases pass. Street1 short remains bytes[67:96], line7/column9; P1's illustrative span excluded the
semicolon. This successful provenance check proves where extracted text came from, not its admission.

## 15. IR/determinism audit

schema_version1, extractor_version1.0.0, static-room-v1, ordered records/keys, LF UTF-8 and typed
decimal strings are independent of game schemas. No generated timestamp, absolute workstation path,
NaN or random-order field was found. Manifest/object coverage and unique object IDs pass, including
wrapper README versus mudlib/README. Canonical guards reject unsupported status/field invariants.

## 16. CLI safety audit

Covered default output root, source/output overlap, ../ target escape, links/junctions, tracked files,
unrecognized manual output and atomic failure cases pass. A same-directory temporary file is flushed
before replacement; injected replacement failure preserves the old file and cleans its temporary file.
These existing tests do not exercise an ancestor output root with an independent external source.
Overall CLI safety is BLOCKED by FA-01. No protected path was actually written during this audit.

## 17. Independent real-source review

| Source, relative to reference/es2/mudlib | Review result |
| --- | --- |
| obj/roommaker.c | Actual ITEM + F_AUTOLOAD; template inherit text stays inside heredoc; OUT_OF_SCOPE |
| d/city/street1.c | Exact short/long, three ordered source-directory exits; lifecycle findings remain |
| d/snow/school1.c | Two literal exits plus objects/create_door/closure findings; no door migration |
| d/oldpine/pine3.c | Four random target expressions yield no fabricated static exit |
| d/oldpine/keep2.c | Two source exits coexist with valid_leave/reset/pipe mutation findings |
| d/village/lake.c | init/actions/recursive valid_leave/replacement remain review territory |
| d/latemoon/sroad1.c | Broken quote/colon on line12; detector eventually reports unclosed string at15 |
| d/latemoon/upstar/upcenter.c | Literal U+FFFD in long text line11; quarantine follows locked corruption policy |
| d/village/lordhouse3.c | Commented opening if brace at73 but remaining closing brace76 causes excess closure |
| u/cloud/obj/sword_book.c | Nested truncated set/et(long at13–17 leaves unmatched structure |
| u/cloud/obj/npc/flower_girl/guihua.c | Actual NUL plus replacement characters, not repaired |
| d/npc/oldman.c | Lines141–145 contain call arguments/closing parenthesis without the opening call |
| u/cloud/npc/goddd.c | Unescaped interior quote at92 disrupts later tokenization; final detection at161 |

The13 current quarantines are consistent with observed corruption/structural errors and the locked
encoding policy. No current-corpus normal supported object was proven falsely quarantined here.
That does not negate the independent FA-05 counterexample or certify full LPC validity for other files.

## 18. Fresh whole-corpus results

Both new runs execute frozen8efc21f against unchanged reference/es2, writing only to ignored
build/migration-tooling-v1/final-audit/run-a.json and run-b.json.

| Metric | Actual |
| --- | ---: |
| Files | 2,336 |
| Supported candidates | 499 |
| EXTRACTED / PARTIAL | 0 / 499 |
| OUT_OF_SCOPE / QUARANTINED | 1,824 / 13 |
| Facts / findings | 2,804 / 4,360 |
| Exit A / Exit B | 1 / 1 |

Finding distribution: REQUIRES_SEMANTIC_REVIEW1713, OUT_OF_SCOPE1305, UNSUPPORTED_CONSTRUCT484,
DRIVER_SEMANTICS_UNKNOWN410, CALLBACK_BEHAVIOR326, RNG_SEMANTICS62,
ORDER_SENSITIVE_MUTATION36, DYNAMIC_EXPRESSION11, SOURCE_ENCODING_ISSUE8, SOURCE_SYNTAX_ERROR5.
Other defined codes have zero occurrences. No hard-coded count logic was found.
The source errors explain exit1; they were not suppressed or repaired. Counts match P2 exactly.

## 19. Fresh determinism and source integrity

| Run | Bytes | SHA-256 |
| --- | ---: | --- |
| A | 9,950,176 | c1bd6b7a946e74f07979239242cdbb3f5168ab0577eb502f9896bfc4cda00141 |
| B | 9,950,176 | c1bd6b7a946e74f07979239242cdbb3f5168ab0577eb502f9896bfc4cda00141 |

Byte-for-byte equality PASS. Independent enumeration verifies2,336 physical files equal the Git
source listing, no added source outputs, and unchanged repo-relative raw-byte manifest
`744e33e1740db7909129a3ae5e295158341b5012a411af953b144a5075bb0a80`.
Source tree remains `4106480ab28cce8cd7b55704f8ae9ae062d42d03`.

## 20. Test audit and fresh local verification

Python3.12.14; all commands run before any tracked audit edit, on frozen executable HEAD:

```text
python -m unittest discover -s tools/tests -p test_migration_tooling.py -v
python -m unittest discover -s tools/tests -p test_*.py -v
python tools/ci/repository_checks.py --repository .
git diff --check
python -m tools.migration.cli --output final-audit/run-a.json
python -m tools.migration.cli --output final-audit/run-b.json
```

Focused62 PASS; full Python108 PASS; repository/static PASS; whitespace diff PASS.
Fresh documentation target/anchor validation follows the P2 method; final counts are reported with
this audit document included. Probes are temporary/in-memory audit observations, not added fixtures
or modified tests. No golden was regenerated. The existing projection golden is12 lines and the
hand-authored source fixture18 lines, with independent span assertions elsewhere.

Tests meaningfully exercise the requested ordinary cases. They miss ancestor output roots,
continued critical macro names, literal excluded-base aliases, strict unresolved-include admission
and composite mapping expressions. These are gaps, not reasons to reinterpret green tests as audit PASS.

**Godot gameplay canonical suite not required/run for this tooling-only Final Audit.**
No remote CI was triggered or claimed. Existing mocked package-test output is not packaged-game proof.

## 21. Security/artifact review

All four production package files use stdlib/relative imports. AST review found no eval/exec calls;
subprocess use is read-only Git output protection, not LPC. No third-party vendor/dependency change,
credential/token, user Save data, workstation-specific canonical field, large source copy or tracked
build output was found in the phase diff. Fixtures are minimal; whole-corpus JSON remains ignored.
No game/config/reference/CI changes exist in either the phase diff or this audit's work.
The genuine security boundary defect is FA-01; safe observed artifact placement does not excuse it.

## 22. Documentation consistency

Historical P1/P2 checkpoints remain intact. Current owner authority closes P1/P2 and locks D1–D9;
the old STATUS/ROADMAP text awaiting P2 review is superseded by this instruction and this audit result.
P2's broad statements about protected outputs and critical shadowing are not fully supported by code,
as FA-01/02 show. Its concrete local counts, source hash and determinism evidence reproduce correctly.
Source extraction is not content migration; PARTIAL is not semantic approval.

Because the audit is BLOCKED, the owner instruction's PASS-only STATUS/ROADMAP update is not applied.
DECISIONS remains unchanged. The PASS-gated audit commit/push workflow is not taken: this report is
left as the sole new untracked document for owner review; executable/local/remote phase HEAD stays8efc21f.
No new frozen PASS-audited milestone SHA is declared.

## 23. Severity-ranked risks

| Severity | Item | Disposition |
| --- | --- | --- |
| HIGH | FA-01 resolved target can bypass protected repository directories | Blocks integration; separate fix authorization required |
| HIGH | FA-02 continued critical directives allow unproven supported facts/normalization | Blocks integration; separate fix authorization required |
| MEDIUM | FA-03 literal excluded base still admitted | Correct admission before renewed audit |
| MEDIUM | FA-04 unresolved include remains supported candidate | Correct admission before renewed audit |
| MEDIUM | FA-05 computed mapping mislabeled source syntax failure | Correct classification before renewed audit |
| MEDIUM residual | Bounded lexer, conservative omissions, preprocessor/driver uncertainty | Explicit unsupported behavior; no runtime parity claim |
| MEDIUM residual | Legacy malformed/corrupt source | Retain diagnostics; no source repair authorization |
| MEDIUM residual | Filesystem TOCTOU under malicious concurrent mutation | Known limitation distinct from deterministic FA-01 |
| LOW residual | Case-sensitive source references and platform path differences | Preserve case/report uncertainty; no repair |
| LOW residual | Approximately9.95MB whole-corpus JSON | Acceptable local ephemeral size; no database/cache needed |
| LOW integration | No remote PR CI or Native consumer yet | Expected deferred gates, not evidence of compatibility |
| Separate unresolved | License/provenance ledger discrepancies | No commercial/legal clearance claimed or changed |

HIGH blockers=2, not0. Deferred features alone were not counted as blockers.

## 24. Deferred scope and PR readiness

**NOT READY FOR PR.** No production/test/fixture correction was made during audit.
NPC/item extraction, Bank/Hockshop/ClassGuild support, door/population semantics, inheritance
evaluation, callback/RNG execution, Learn/recruit/combat migration, Native importer/generator,
mass content migration, P3, PR creation and merge remain outside authorization.

## 25. Exact next owner gate

Owner review of this BLOCKED report, followed by explicit authorization for a bounded correction
slice on the same phase branch. That slice should address FA-01–05 with independent regression
coverage while preserving D1–D9, then undergo a new frozen-head final audit. No automatic next slice,
audit PASS commit, PR or merge follows from this report. Existing main remains unchanged and green
per the accepted baseline; this tooling milestone is not integrated on main.

**MIGRATION TOOLING V1 FINAL AUDIT BLOCKED**
**NOT READY FOR PR — AWAIT OWNER REVIEW**
