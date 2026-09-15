# Migration Tooling v1 — P2 Static Room Extractor

2026-09-15. **IMPLEMENTATION COMPLETE — AWAIT OWNER REVIEW.**
This is source extraction tooling, not ROOM migration completion, semantic approval or Native content.

## 1. Scope and authorization

P1 `0e5ff6a5cbc8d4091102e280c66868ba8763b4bb` is OWNER APPROVED / CLOSED.
The phase remains `phase/migration-tooling-v1`, based on green main
`cd07808cb76147d0b8c0dad9b82d078b49fefe64`.
The first P2 commit, `8108763d6a4ddb3ad2b110200666424f4042e296`, records locked D1–D9
in [DECISIONS](DECISIONS.md#migration-tooling-v1-p2--owner-locked-extraction-boundary) and corrects
current Snow/Tooling status in STATUS/ROADMAP. It was committed and pushed before implementation.
The [P1 analysis](MIGRATION_TOOLING_V1_P1_ANALYSIS.md) remains unchanged historical evidence.

P2 implements only Python standard-library static direct-ROOM extraction, exact provenance and
explicit findings. No PR, merge, P3, NPC/item extraction, LPC execution, semantic migration,
gameplay change, Save change or Godot importer/generator is authorized.

## 2. Locked decisions implemented

| Decision | Implementation |
| --- | --- |
| D1 | Python 3.12-compatible standard library under tools/migration; no Godot/dependency installation |
| D2 | Only reliable unconditional direct ROOM in mudlib-relative d/**/*.c; excluded categories remain unsupported |
| D3 | Identity/inherits, literal short/name/TEXT_ONLY long, approved static flags and ordered static exits |
| D4 | Independent deterministic UTF-8 Migration IR schema_version 1; no game schema changes |
| D5 | Raw-byte SHA-256, half-open byte span, raw source, scope/construct/ordinal, 1-based line/column |
| D6 | No evaluation; explicit dynamic/unsupported findings; only narrow source-directory literal concatenation |
| D7 | Whole-corpus output remains ignored build output; no generated content committed |
| D8 | unittest; hand-authored fixture/projection golden plus independent raw-source assertions |
| D9 | Exit0 completed without quarantine, exit1 completed with quarantine, exit2 fatal tool/input/output failure |

## 3. Architecture and files

- [es2_source.py](../../tools/migration/es2_source.py): raw bytes/hash/location, deterministic discovery,
  filesystem confinement, small lexer, delimiter pairing and narrow scalar recognition.
- [room_extractor.py](../../tools/migration/room_extractor.py): source structure, direct inheritance,
  create statements, ordered facts, static reference checks, typed findings/status, manifest and IR.
- [cli.py](../../tools/migration/cli.py): argparse, output protection, complete serialization and atomic replacement.
- [__init__.py](../../tools/migration/__init__.py): package boundary only.
- [test_migration_tooling.py](../../tools/tests/test_migration_tooling.py): 62 focused unittest cases.
- [fixture notes](../../tools/tests/fixtures/migration_v1/README.md),
  [hand-authored source](../../tools/tests/fixtures/migration_v1/static_room.c),
  [independent projection golden](../../tools/tests/fixtures/migration_v1/static_room.expected.json).

There is no interpreter, runtime object model, dependency evaluator, database, service or cache.
Discovery → lexical/structural extraction → JSON → audit findings stops before Native generation.
The tool uses Git read-only to protect tracked output destinations, not to run LPC or inspect CI.

## 4. CLI

From repository root, with Python 3.12 and Git available:

```text
python -m tools.migration.cli --profile static-room-v1
python -m tools.migration.cli --source-root reference/es2 --output run-a.json
python -m tools.migration.cli --source-root reference/es2 --output run-b.json
```

Default source is the repository's reference/es2; default output root is ignored
`build/migration-tooling-v1/`, default filename `static-rooms.json`.
`--source-root` accepts an ES2 wrapper containing mudlib/d or a mudlib-shaped root containing d.
`--output-root` explicitly selects an intended output directory. `--output` must stay inside it.
There are no execute, approve, migrate-game or generate-Godot options.

Repository-local output is restricted to build/migration-tooling-v1; explicit external output
roots are allowed after confinement/tracked-file checks. Source and output roots cannot overlap.
Links/junctions are conservatively rejected, including in-root links; none are followed.
Existing manual/unrecognized files and tracked files are refused. Repeat scans may replace a
recognized schema1/static-room-v1/extractor1.0.0 output. A temporary file in the same directory is
flushed before atomic replacement. Failed replacement preserves the previous output and removes
the temporary file. Fatal serialization/input failure does not publish a new incomplete manifest.

## 5. IR v1 and source identity

Top-level keys in canonical order:
`schema_version`, `extractor_version`, `profile`, `review_state`, `source_manifest`,
`objects`, `findings`, `summary`.
Version values are 1, 1.0.0 and static-room-v1 respectively.
Canonical JSON uses UTF-8, fixed key layout/indentation, LF, deterministic source-path order and
source-ordered fact arrays. No timestamp, current Git HEAD or workstation absolute path is injected.
The same source bytes and extractor therefore do not change output merely because tooling is committed.

Manifest entries include input_path, source_path, source_namespace, kind (LPC_SOURCE/HEADER/OTHER),
raw-byte size/hash, status and UNREVIEWED. Objects correspond one-to-one with discovered files.
The manifest digest hashes sorted root-relative input_path + NUL + file SHA-256 hex + LF.
Source path preserves case. Root-wrapper files and mudlib files have explicit namespaces/input paths;
the two README files cannot collide.

LPC object IDs are `es2:<mudlib-relative-path-without-.c>`; header IDs retain their extension.
Other-file IDs are `es2-file:<input_path>`. These are source identities, never CharacterId/MapId/
ZoneId/PlayerId or instantiated objects. A file's identity is not inferred from its opening comment.
All object/fact/finding/manifest records start UNREVIEWED; machine approval does not exist.

Integer gameplay literals are typed decimal strings, e.g. kind=integer/value="0". This preserves
precision for future JSON consumers without assuming their number model. Structural counts/offsets
are ordinary JSON integers. Missing fields remain absent, not zero, false, null or inherited defaults.

## 6. Fact and provenance model

Facts contain fact_id, field, classification, review_state, typed value and provenance.
Classification is EXACT_LITERAL or STATIC_NORMALIZED for emitted supported facts. Unknown and
unsupported expressions are represented by typed findings with exact raw spans, not fabricated values.
Long text additionally has text_classification=TEXT_ONLY; prose cardinality has no gameplay effect.

Every fact provenance records source_path, source_sha256, scope, construct, source_ordinal,
byte_start, byte_end_exclusive, line, column and raw. Offsets index original bytes, starting at0;
end is exclusive. Lines/columns start at1; columns count Unicode codepoints, with a tab counting1.
CRLF bytes remain unchanged. Source ordinal is the code token's order, not a runtime execution count.
Fact IDs hash path + source hash + field + byte range, distinguishing identical repeated statements.
Normalization records SOURCE_DIR_LITERAL_CONCAT/version1 and the exact target input span.

For example, current city/street1 short is 京师东街, source SHA-256
`22eae1c00f4141b629316f00517aa540e3747cb9075def30ead725c427ae69a9`, line7/column9,
bytes[67:96]. P2 includes the statement semicolon; P1's illustrative bytes[67:95] excluded it.
Both refer to the same unchanged source. Tests check actual bytes, not only line numbers.
Invalid UTF-8 findings use raw_hex when raw cannot be decoded; no repaired fact is emitted.

## 7. Supported syntax

The lexer separates line/block comments, escaped double-quoted strings, character literals,
opaque quoted symbols, @TAG/@@TAG multiline text, directives and ordinary code tokens.
Tags must occupy the terminator position; a trailing delimiter such as `LONG);` remains code.
Closures with whitespace before `)` still balance; they are never executed.

Only an unambiguous bare `set(key, value);` outer statement in one create body is extracted.
Conditional/nested statements, foreign/qualified receivers and other functions are not initial facts.
Repeated declarations remain in source order and generate duplicate findings, never last-wins state.
Shadowed ROOM/create/set, unresolved include context and conditional preprocessing are handled
conservatively. Conditional compilation is not evaluated or balanced as if all branches coexisted.
Simple include references are inspected for critical macro shadowing; this is dependency inspection,
not a general preprocessor or inherited-default resolver.

Supported text is a single quoted scalar or @TAG scalar. Supported flag values are decimal integer
tokens or scalar text. The explicit escape allowlist is documented in es2_source.literal; unknown
escapes are not guessed. `@@TAG` arrays are retained lexically but are not scalar text facts.

Exits are ordered key/value entries in a literal mapping. Each exit preserves direction_raw,
target_raw, direction, target, provenance and reference status. Both actual `__DIR__"file"` and
explicit `__DIR__ + "file"` represent the approved narrow source-directory concatenation. No
additional expression concatenation/arithmetic is evaluated. Duplicate directions remain visible.
Static absolute source references distinguish EXISTS, MISSING, CASE_MISMATCH, AMBIGUOUS and
UNRESOLVED. No file, spelling, relative traversal, reverse edge or reachability is repaired/inferred.

## 8. Explicit unsupported syntax and semantic boundaries

No general LPC parser is claimed. Balanced but otherwise invalid unknown function bodies are not
certified valid. The tool detects lexical, delimiter and supported-mapping structural failures;
other grammar remains opaque review territory. Octal/hex/float/signed expressions, adjacent quoted
strings, arbitrary macros, variables, function calls, arithmetic, ternaries, array text, preprocessing
branches and computed exits are not evaluated into supported scalar/exit facts.

Callbacks, local/cross-object exit mutations, setup/reset/replacement, doors, population, arbitrary
set fields, closures and RNG produce findings. Unsupported outer create statements and non-create
function bodies retain raw source spans. A static exit can coexist with later mutations without
becoming an authoritative final graph. Missing functions/defaults never mean allow or zero.
No integer formula rewrite, rollback, timestamp substitution, combat buff inference, skill admission
inference or one-room/one-scene mapping is performed.

## 9. Finding and status model

FindingCode is a typed string enum containing all P1-required concepts:
REQUIRES_SEMANTIC_REVIEW, UNRESOLVED_INHERITANCE, UNRESOLVED_INCLUDE, DYNAMIC_EXPRESSION,
ORDER_SENSITIVE_MUTATION, RNG_SEMANTICS, CALLBACK_BEHAVIOR, DRIVER_SEMANTICS_UNKNOWN,
SOURCE_SYNTAX_ERROR, SOURCE_ENCODING_ISSUE, DUPLICATE_DECLARATION, UNRESOLVED_REFERENCE,
UNSUPPORTED_CONSTRUCT and OUT_OF_SCOPE.

Each finding includes code, severity, object identity, reason, prevents_supported_consumption,
exact provenance, stable finding reference within the unchanged source record, and UNREVIEWED.
Objects list finding_ids; global findings are ordered by input path, byte position, code and reason.

| Status | Meaning |
| --- | --- |
| EXTRACTED | All observed constructs covered without blocking findings; still UNREVIEWED |
| PARTIAL | Reliable direct ROOM with supported facts plus unsupported/dynamic dependencies |
| OUT_OF_SCOPE | Discovery-only for this profile; not a successful empty gameplay conversion |
| QUARANTINED | Source syntax/encoding failure; fact array cleared, diagnostic remains |

ROOM inheritance itself has a nonblocking semantic-review dependency. Calls such as setup() have
blocking review findings, so all499 current supported candidates are PARTIAL. This conservatively
reports the remaining runtime boundary; it does not mean their literal fields could not be extracted.

## 10. Failure contract

- Exit0: completed without quarantined syntax/encoding objects; semantic/out-of-scope findings allowed.
- Exit1: completed with quarantine; complete safe diagnostic JSON still emitted.
- Exit2: invalid arguments/root/path, fatal read/write, serialization/schema/invariant or internal failure.

Exit0 never means migration PASS. Unsupported legal syntax is not intentionally relabeled as a
source error. Fatal exceptions are stderr diagnostics, not embedded machine-specific canonical fields.
No truncation/repair/retry of LPC execution exists. Filesystem and recursion resource exhaustion
fail explicitly as exit2 rather than providing a complete-looking partial result.

## 11. Local tests and distinct self-audit

Commands run locally:

```text
python -m unittest discover -s tools/tests -p test_migration_tooling.py -v
python -m unittest discover -s tools/tests -p test_*.py -v
python tools/ci/repository_checks.py --repository .
git diff --check
```

Focused migration suite: **62 tests PASS**. Full Python suite: **108 tests PASS**, including all
46 pre-existing tooling tests. Repository/static checks PASS. No third-party dependency was added.
The existing build tests use tiny mocked package fixtures; their printed APK path is not a new
packaged-game validation claim.

Coverage includes all requested lexer, direct-inherit, text/flag, zero/absence, integer precision,
ordered exits, narrow normalization, RNG/dynamic, mutation, duplicate, provenance, malformed/encoding,
status, deterministic ordering, root/target protection, tracked/manual output refusal, atomic failure
and exit0/1/2 boundaries. Filesystem-link/junction refusal is fault-injected; no Windows privilege
assumption is needed. Real ../ output escape, root overlap and tracked-file refusal are exercised.

The projection golden was hand-authored before extraction tests; no golden regeneration command is
provided. Independent byte/hash assertions cover full provenance, including CRLF/Chinese text and
distinct identical declarations. Real source samples are read in place, not copied or modified.

Separate self-audit checked source/core boundaries, macro shadowing (including comments inside
directives), root/mudlib identity collision, conditional scopes, ordered facts, false syntax errors
from multiline terminators/spaced closures, ternary expressions, output safety and scope coverage.
Corrections stayed in this P2 implementation; no source repair, production game changes or new
semantic decision was introduced. No subagent or gameplay runtime was used.

**Godot gameplay canonical suite not required/run for this tooling-only slice.**
No remote CI was run or claimed for P2.

## 12. Real-source regression evidence

| Source under reference/es2/mudlib | Result |
| --- | --- |
| obj/roommaker.c | ITEM + F_AUTOLOAD, OUT_OF_SCOPE; ROOM_CODE heredoc inheritance never counted as actual ROOM |
| d/city/street1.c | Exact short provenance and ordered biaoju/street2/shenwumen source-directory exits |
| d/snow/school1.c | Two static exits; door, population and closure findings; PARTIAL |
| d/oldpine/pine3.c | No static exits fabricated from RNG expressions; RNG findings retained |
| d/oldpine/keep2.c | Two static source exits coexist with callback and ordered mutation findings |
| d/village/lake.c | Static facts retained with callback/replacement review; no traversal execution |
| d/latemoon/sroad1.c | QUARANTINED for unterminated string detected after malformed exit text; no guessed repair |
| u/cloud/obj/sword_book.c | QUARANTINED for mismatched structure |
| u/cloud/obj/npc/flower_girl/guihua.c | QUARANTINED for encoding/corruption |

## 13. Whole-corpus smoke

Two actual invocations above scanned the current reference/es2 into ignored run-a.json/run-b.json.
Both produced the same results, **exit1**:

| Metric | Actual |
| --- | ---: |
| Scanned files | 2,336 |
| Reliably supported direct ROOM candidates | 499 |
| EXTRACTED | 0 |
| PARTIAL | 499 |
| OUT_OF_SCOPE | 1,824 |
| QUARANTINED | 13 |
| Supported source facts | 2,804 |
| Findings | 4,360 |

P1's559 direct ROOM candidates were whole-mudlib lexical candidates, not this profile's result.
502 are under d/; three are quarantined before reliable admission: latemoon/sroad1.c,
latemoon/upstar/upcenter.c and village/lordhouse3.c. The remaining57 lie outside d/.
The implementation does not hard-code any of these counts as classification logic.

| Finding code | Count |
| --- | ---: |
| REQUIRES_SEMANTIC_REVIEW | 1,713 |
| OUT_OF_SCOPE | 1,305 |
| UNSUPPORTED_CONSTRUCT | 484 |
| DRIVER_SEMANTICS_UNKNOWN | 410 |
| CALLBACK_BEHAVIOR | 326 |
| RNG_SEMANTICS | 62 |
| ORDER_SENSITIVE_MUTATION | 36 |
| DYNAMIC_EXPRESSION | 11 |
| SOURCE_ENCODING_ISSUE | 8 |
| SOURCE_SYNTAX_ERROR | 5 |

Other defined finding codes have zero occurrences in this actual run; focused fixtures exercise
missing/case references, duplicates and unresolved dependencies. Findings and object counts differ:
one object may have many findings; OTHER files only need manifest/OUT_OF_SCOPE records.

The five syntax quarantines are d/latemoon/sroad1.c, d/npc/oldman.c,
d/village/lordhouse3.c, u/cloud/npc/goddd.c and u/cloud/obj/sword_book.c.
The eight encoding quarantines are cmds/std/exercise.c, d/choyin/npc/yamen_po.c,
d/latemoon/upstar/upcenter.c, both temple/npc/obj and temple/obj magic_book.c/spells_book.c pairs,
and u/cloud/obj/npc/flower_girl/guihua.c. No errors were suppressed to obtain exit0.

## 14. Determinism and integrity

Run A SHA-256: `c1bd6b7a946e74f07979239242cdbb3f5168ab0577eb502f9896bfc4cda00141`.
Run B SHA-256: `c1bd6b7a946e74f07979239242cdbb3f5168ab0577eb502f9896bfc4cda00141`.
Exact byte comparison PASS; each canonical output is9,950,176 bytes.
Input manifest SHA-256 is `895d36086e184ba6bf520625c20e882394a0a6169aabf86a1b4c58ba835e2820`.
That manifest uses source-root-relative paths; it intentionally differs from P1's repo-relative hash.

Independent P1-method rescan confirms2,336 unchanged physical/tracked files and the same repo-relative
raw-byte manifest `744e33e1740db7909129a3ae5e295158341b5012a411af953b144a5075bb0a80`.
Reference Git tree before/after remains `4106480ab28cce8cd7b55704f8ae9ae062d42d03`.
Git path checks show no reference/es2, game, gameplay tests, .github, tools/build or tools/ci changes.
There is no generated gameplay/scene/resource/Save output. Whole-corpus output/logs remain ignored.

## 15. Changed paths and verification boundary

Decision commit: only DECISIONS, STATUS and ROADMAP. Implementation commit: the four package files,
one migration test module, three small fixture/golden/note files, this report, and minimal current
P2 completion wording in STATUS/ROADMAP. P1 analysis and historical source/audit evidence are unchanged.

Tests/smokes above ran against the final implementation bytes before committing; no code changes
follow those results. Final commit SHA, parent, remote equality, clean worktree, path whitelist,
diff check and no-open-PR verification are reported to the owner after commit/push, avoiding a
self-referential SHA edit. No separate post-commit full gameplay run is required by repository policy.
The phase remains unmerged and has no PR; implementation completion is not milestone integration.

## 16. Residual limitations and deferred scope

This bounded lexer/structure recognizer is not a language validator. Conservative unsupported
classification can omit valid but unapproved source forms; it never certifies complete runtime state.
Source snapshots assume a quiescent input tree during a scan. Filesystem checks do not claim protection
against a malicious concurrent process replacing directories between checks. No driver is launched.
Small-case path resolution reports uncertainty; it does not reproduce runtime path lookup rules.

Deferred and unauthorized: NPC extraction, item extraction, Bank/Hockshop/ClassGuild support,
door semantics, population semantics, inheritance evaluation, callback/RNG execution,
Learn/recruit/combat migration, Godot importer/generator, mass content migration and P3.
The owner must review P2 before any later slice. No semantic auto-approval or Native generation exists.

**MIGRATION TOOLING V1 P2 IMPLEMENTATION COMPLETE**
**STATIC ROOM EXTRACTION BOUNDARY PRESERVED**
**AWAIT OWNER REVIEW — STOP**
