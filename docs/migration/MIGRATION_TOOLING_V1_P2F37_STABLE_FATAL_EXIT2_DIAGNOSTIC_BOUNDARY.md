# Migration Tooling v1 — P2F37 stable fatal exit2 diagnostic boundary

## Result and owner authorization

**P2F37 IMPLEMENTED / PRE-COMMIT ACCEPTANCE PASS / AWAIT OWNER REVIEW.**

FR36-01 (semantic blocker43, MEDIUM / BLOCKING, owner Class E, D9) is repaired at implementation level. This is the owner-authorized resume of the existing P2F37 candidate, not Attempt2, FR37-01, a new repair slice, or a Final Re-Audit. The 42 previous blockers retain their implementation repairs.

P2F36 remains OWNER APPROVED / CLOSED. Gate A remains PASS / FROZEN; AR-01 remains ACCEPTED / NON-BLOCKING. Final Re-Audit after P2F36 remains historically BLOCKED. Gate B remains BLOCKED / INCOMPLETE and requires a separate owner-authorized Final Re-Audit continuation. This implementation report does not certify Gate B or PR readiness.

Branch: `phase/migration-tooling-v1`. Exact parent / pre-commit HEAD / fetched origin phase: `2bee421a57ad7d358426e6d1ba4551792251cf5f`. Parent subject: `Fail closed when Git output protection cannot be verified`. Frozen main/origin main/merge-base: `cd07808cb76147d0b8c0dad9b82d078b49fefe64`. Fresh all-state phase PR query returned none.

The ordinary fatal reporter from Attempt1 was retained. Resume changed only its incomplete argparse diagnostic sibling and added its focused controls. The existing three candidate files, clean index, unchanged STATUS/ROADMAP, and35 owner-local raw hashes were verified before editing.

## Attempt1 historical stop and root cause

Owner-local evidence35, `MIGRATION_TOOLING_V1_P2F37_STABLE_FATAL_EXIT2_DIAGNOSTIC_BOUNDARY_ATTEMPT1_BLOCKED.md`, remains10809 bytes, SHA-256 `9c67f8eb33d8b1ca4008b4778701191209380f3bdfbe210f9f2f2b439f820826`, raw Git blob `08009783d3f247d96f67352a0082842b8344a640`. Its20-test result was18 PASS,1 FAIL,1 ERROR,0 SKIP. The required hard stop was honored; no candidate or evidence was discarded.

Fresh parent reproduction during this P2F37 work showed missing-root normal stderr exit2; real closed-stderr exit120; independent write-failing sink OSError escaping main; independent child with traceback recovery exit1. Manual-output and invalid-profile siblings also produced2 normally and120 with closed stderr, with no target mutation. Those nine parent subprocess executions and one API confirmation remain distinct from repaired-candidate results.

Python3.12.14 argparse._print_message catches AttributeError/OSError from file.write and suppresses them. It then raises SystemExit2. Merely moving parse_args inside an ordinary Exception handler cannot detect a suppressed error, so the broken buffered stderr survives and may fail at interpreter shutdown, producing120. This was independently confirmed in Attempt1. It remains FR36-01; no new FR was assigned.

## Implementation and D9 contract

The [locked contract](DECISIONS.md#migration-tooling-v1-p2--owner-locked-extraction-boundary) remains:

- exit0: complete tooling execution without genuine source quarantine;
- exit1: complete scan/document containing genuine source quarantine;
- exit2: fatal argument/root/path/I/O/schema/internal/output failure.

[cli.py](../../tools/migration/cli.py) adds a local MigrationArgumentParser subclass. Its bounded _print_message override preserves argparse-owned message content, chooses stderr only when no stream was supplied, writes and explicitly flushes, and allows ordinary transport exceptions to propagate. No stdlib or global argparse monkeypatch, new argument grammar, or new stdio framework is introduced.

parse_args stays inside main's ordinary Exception boundary. A fatal error is best-effort formatted/written/flushed as `FATAL: TypeName: message`. If formatting, write, or flush raises an ordinary Exception, sys.stderr becomes io.StringIO, then main returns2. The replacement prevents a broken buffered stderr from changing the intended process result during normal interpreter shutdown. Loss of unavailable diagnostic text is accepted; wrong exit classification is not. Swallow-only handling would not provide that shutdown guarantee.

Healthy invalid arguments retain argparse usage/error and SystemExit2. Healthy --help retains SystemExit0 and normal stdout help. KeyboardInterrupt remains uncaught. No broad SystemExit/BaseException catch, os._exit, stdout diagnostic fallback, or closed-stdout help redesign exists.

Destination protection, scan/serialization ordering, canonical schema recognition, and atomic write/flush/fsync/replace boundaries are unchanged. Machine-specific diagnostics remain stderr-only and never enter canonical IR.

## Scope and version

Exactly six successful tracked files are authorized: cli.py; room_extractor.py; test_migration_tooling.py; this report; STATUS.md; ROADMAP.md.

[room_extractor.py](../../tools/migration/room_extractor.py) differs from the exact parent only in EXTRACTOR_VERSION1.0.37 and appending1.0.37 to KNOWN. All38 versions1.0.0–1.0.37 remain; schema_version1 and profile static-room-v1 are unchanged. No source-classification, macro, pairing, inherit, create-tail, mapping, mutation classifier, finalizer, or fact-allocation code changed.

[Product tests](../../tools/tests/test_migration_tooling.py) retain every existing test, except three current producer-version assertions updated to1.0.37 and three complete historical lists with1.0.37 appended. Historical1.0.36 and earlier fixture bytes are unchanged. The24 new focused tests include the preserved20 plus argparse flush/non-I/O failure, normal help, and real normal invalid-profile controls. Frozen Gate-A expectations were not edited.

DECISIONS, es2_source, schemas, reference/es2, game/runtime/save, workflows and dependencies are unchanged. This pure CLI/tooling slice changes no gameplay mechanic and requires no live Godot proof.

## Fresh pre-commit acceptance

| Gate | Actual result |
| --- | --- |
| P2F37 focused | 24 PASS |
| Combined P2F22/P2F26–P2F37 | 181 PASS |
| Migration suite | 610 PASS |
| Full Python suite | 656 PASS |
| Retained P2F36 / P2F35 focused | 18 / 10 PASS |
| Independent FR36 diagnostic family | 24 PASS:12 subprocess +12 API |
| FR35 Git/non-Git matrix | 39 PASS +2 real subprocess controls |
| FR34 primary/independent | 4 CLI PASS with4 direct invocation traces |
| P2F35 pairing regression | 984 CLI PASS |
| Frozen Gate A | 13634/13634 CLI,72 families PASS |
| AR-01 | 20/20 final-safety PASS |
| Historical canonical replacement | 38/38 real CLI PASS |
| Invalid documents / nested pollution | 6 classes /33 dictionary positions PASS |
| Retained output fault probes | 7 +5 PASS |
| Repository/static / diff check | PASS |

Product suites have zero failures, errors and skips. All runs start from the first case; no historical receipt substitutes for fresh execution. The71 copied frozen input/oracle files were checked byte-identical. Disposable runner adaptations change only exact parent/version/count/output namespace bookkeeping.

## Diagnostic and output-security evidence

Fresh real normal and closed-stderr subprocess pairs cover missing-root, manual output, schema refusal and invalid profile. Every fatal case exits2, stdout is empty, and the target remains absent or byte-identical. Healthy invalid-profile stderr retains normal argparse content.

Independent API write/flush sinks cover missing-root, argparse, schema, internal, fatal Git marker, and format-failure paths. Each returns2 with a safe replacement stream and writer0. Separate subprocess wrappers keep write/flush-failing sinks installed through actual shutdown for missing-root and argparse: all exit2 without traceback/120. Product tests additionally verify source-read, serialization, KeyboardInterrupt and atomic-replace behavior.

The complete required output matrix combines product tests and independent security/Git/failure probes: repository/source/reference/game/docs confinement; absolute/relative escape and ancestors; existing tracked targets and external checkout; Git rev-parse and ls-files0/1/fatal; .git directory/file and inspection errors; healthy untracked and ordinary non-Git output; source read/schema/internal/serialization/roundtrip/write/flush/fsync/replace; invalid destination; invalid UTF-8 raw_hex; modeled symlink/junction; fatal diagnostic and argparse write/flush transport.

Rejected pre-write destinations/documents return2 with writer0 and unchanged bytes. Atomic fault controls preserve the prior target and leave no temporary residue. Modeled link/junction evidence is explicitly modeled, not a claim of OS-created links. The six invalid document classes are manual, reviewed, future, unknown, malformed and empty. All33 independently enumerated nested dictionary pollution locations reject with exit2/writer0/unchanged bytes. Historical canonical originals are only read/copied and remain byte-identical.

## Corpus A/B and exact parent projection

Two independently executed complete CLI scans return1 and produce identical canonical bytes:

- scanned2336; supported485; EXTRACTED0; PARTIAL485; OUT_OF_SCOPE1838; QUARANTINED13;
- facts2736; findings4296; output bytes9808627;
- A/B SHA-256 `ff22c77b04e4033d8f70f1d4c10ef6746b6ad005e4715c79b786a608b321fe60`.

A fresh scan using modules read directly from Git at exact parent `2bee421a57ad7d358426e6d1ba4551792251cf5f` reproduces P2F36 SHA-256 `9e780e357dfe06c0cf838b1bb15d333c1436c6e64f00d2a90c93379f22135417`. Full document comparison after removing extractor_version is equal: affected real paths=[], candidate/status delta0, fact delta0, finding delta0, provenance delta0, unchanged13 quarantines. No unexplained semantic change exists.

Finding distribution: CALLBACK_BEHAVIOR284; DRIVER_SEMANTICS_UNKNOWN408; DYNAMIC_EXPRESSION10; ORDER_SENSITIVE_MUTATION30; OUT_OF_SCOPE1319; REQUIRES_SEMANTIC_REVIEW1623; RNG_SEMANTICS58; SOURCE_ENCODING_ISSUE8; SOURCE_SYNTAX_ERROR5; UNRESOLVED_INCLUDE97; UNRESOLVED_INHERITANCE14; UNSUPPORTED_CONSTRUCT440.

## Real sources, provenance and IDs

All13 genuine quarantine files were freshly checked through the extractor and against actual bytes:8 encoding and5 syntax, candidate=false/facts=[]. Their reasons, spans, hashes, line/Unicode column and relevant preprocessing witnesses retain the baseline. All14 ANSI exclusions remain candidate=false, OUT_OF_SCOPE, facts=[].

All9587 provenance records were validated:2736 facts,4296 findings,1799 direct inherits and756 normalization inputs. Validation covers source path/hash, raw/raw_hex, byte span, line/Unicode column, scope/construct, independently recomputed source ordinal, normalization inputs/rule/version, fact-ID derivation, stable ordering, unique identities, finding references, exact manifest/summary and UNREVIEWED. No duplicate/ghost/orphan/dangling IDs or automatic approval was found.

## Source, archive and evidence preservation

Reference tree: `4106480ab28cce8cd7b55704f8ae9ae062d42d03`. Fresh2336-file raw manifest: `744e33e1740db7909129a3ae5e295158341b5012a411af953b144a5075bb0a80`.

ARCHIVE-01 CLOSED: all10 tracked historical audit raw hashes match frozen copies/index/HEAD; P2F10 retains24417 bytes/468 CRLF and SHA-256 `56e1cd0aa0a573bc4a9505fb5df6bd1cfbd0076849a40f6bd4a4420483cb2213`. .gitattributes retains SHA-256 `b33913bb7279e1ab67762574ab277828a9fd114dae23dceace2f24ae842194d6`. All35 owner-local historical files remain untracked/unstaged/byte-identical. Final Re-Audit after P2F36 remains25661 bytes with SHA-256 `ebb9973c42132758817fc1f52663c9becb9d4e5b3170d284cd3bf4a4f54c170c`.

All tracked bytes outside authorized scope and all original fixtures are preserved. Generated corpus, fault probes and machine-specific receipts remain ignored under `build/migration-tooling-v1/p2f37-resume/`; Attempt1 evidence remains in its original namespace. Local Markdown targets/anchors/whitespace and exact scope are rechecked before staging and after commit.

## Immutable acceptance and owner gate

Authorized commit subject: `Preserve exit2 when fatal diagnostics cannot be written`; exact parent as above. Only the six authorized files may be staged. This report records completed pre-commit evidence; the immutable commit must rerun every required gate from scratch with separate post receipts before normal push. Any failure means stop without amend or push. The post-commit SHA and results are reported to the owner, avoiding a self-referential commit identity inside this document.

This slice is implementation delivery on the existing phase branch, not integration on main. No phase PR or new remote CI is authorized. No Final Re-Audit, Gate-B continuation, P2F38, PR, merge, P3 or Native output follows automatically.

**AWAIT OWNER REVIEW — STOP AFTER VERIFIED NORMAL PUSH.**
