# Migration Tooling v1 — Final Re-Audit after P2F7

## 1. Executive verdict

**BLOCKED — NOT READY FOR PR.** Audit date: 2026-09-16.

发现 **FR7-01 / HIGH：resolved include 的非宏语义上下文没有参与准入与 setter/create 可靠性判断**。
实际 CLI 可在头文件定义了本地 `set()` 时，仍输出主文件调用的 short/exit facts；
头文件中的额外 ITEM 继承、重复 create、条件包裹的 setter 也绕过对应保护。
直接写入主文件的等价对照均被既有规则阻止。违反 **D2 / D3 / D6**。

| Gate | Result |
| --- | --- |
| HIGH blockers | 1 — FR7-01 |
| Other confirmed blocking MEDIUM | 0 |
| Material D1–D9 defects | 1 shared include-context defect, multiple manifestations |
| Complete final audit | STOPPED after new material blocker and bounded sibling sweep |
| Production/test/fixture changes | 0 |
| STATUS / ROADMAP / DECISIONS changes | 0 |
| Commit / push / PR / merge | None in this audit |

不能将 `PARTIAL` 或通用 `UNSUPPORTED_CONSTRUCT` warning 当成允许输出不可靠事实的理由。
本工具明确承诺 shadowed setter、duplicate create 和排除类别不产生相应 facts；
已有直接形式回归也要求如此。消费阻断标记降低误用机会，但没有修复 IR 内容的契约错误。

### Frozen reproducer

两个 UTF-8 / LF 文件，末尾均有换行。使用独立临时 source/output 运行真实 CLI，无 mock extractor：

`include/probe.h`:

```c
mixed set(string key, mixed value) { return 0; }
```

`d/probe.c`:

```c
inherit ROOM;
#include <probe.h>
void create(){set("short","must not extract");set("exits",(["east":__DIR__"east"]));}
```

```text
python -m tools.migration.cli --source-root <temporary-source> --output-root <temporary-output>

exit = 0
supported_candidate = true
status = PARTIAL
fields = [inherit, short, exit]
short = "must not extract", classification = EXACT_LITERAL
exit = /d/east, classification = STATIC_NORMALIZED
```

| File | SHA-256 |
| --- | --- |
| include/probe.h | `6ef8253b7fa2c37f2481f473f100ed84258342ed06f9215ab5b5b71c064a27ac` |
| d/probe.c | `5dae64c07c15b51e7dc727bc31fffd89ad48a1f30c0ced5df0a193d0f29468c4` |

把头文件内容直接放到主文件的同一位置：fields 仅 `[inherit]`，不输出 short/exit。
本地 setter 返回 0，不执行 dbase 的写入。原始继承链
[std/room.c](../../reference/es2/mudlib/std/room.c) → F_DBASE 和
[feature/dbase.c](../../reference/es2/mudlib/feature/dbase.c):24 的 `mixed set(string prop, mixed data)`
支持这一比较；不是依赖任意外部 LPC 实现作出的假设。

### Root cause and bounded sibling sweep

[room_extractor.py](../../tools/migration/room_extractor.py):316–350 的 include_hazards
只处理 directive token 中的 critical define/undef 和递归 include。
其余 token 被忽略；已找到、可 lex 的头文件因而被视为不含这些 hazards。
主文件的 conditional 检查在 :355，直接继承类别在 :432–440，setter/create 检查在 :469–483；
它们没有获得头文件的函数、继承或条件包裹的声明信息。
文件存在、lex 成功，并不足以证明已可靠理解这些 include 上下文。

有限同类扫描共 **80 个真实 CLI 样本**：9 个族 × 4 个放置方式 × LF/CRLF = 72，
另加函数原型对照 8 个。放置方式为 inline、`<probe.h>`、`"probe.h"`、传递 include。
未修复生产实现，也未把探针加入正式测试。

| Header content | Inline control | Three include forms × LF/CRLF |
| --- | --- | --- |
| local set function definition | Only inherit | **6/6 incorrectly emit short + normalized exit** |
| second create definition | Only inherit | **6/6 incorrectly emit short + normalized exit** |
| inherit ITEM | OUT_OF_SCOPE, facts=[] | **6/6 admitted, emit inherit + short + exit** |
| inherit "/std/item" | OUT_OF_SCOPE, facts=[] | **6/6 admitted, emit inherit + short + exit** |
| #ifdef CUSTOM around set definition | OUT_OF_SCOPE, facts=[] | **6/6 admitted, emit short + normalized exit** |
| #define set(k,v) ignored(k,v) | Only inherit | 6/6 correctly suppress create facts |
| set function text only in comment | Ordinary facts | 6/6 ordinary facts; no false shadow |
| inherit ITEM text only in string | Ordinary facts | 6/6 ordinary facts; no false category |
| inherit ITEM text only in heredoc | Ordinary facts | 6/6 ordinary facts; no false category |
| set function prototype only | Ordinary facts | 6/6 ordinary facts; not a function definition |

共 **30 个 unsafe included cases**；50 个 inline/negative/control cases 符合对应预期。
80 次均 exit0，说明问题是可靠性判断而非 CLI 崩溃。
重复 create 用例只证明既有“不唯一则不提取”保护被绕过，不要求本工具实现完整编译器诊断。
条件 setter 用例不要求计算 CUSTOM；未知条件本身不能成为安全提取的依据。
普通 include guard 不等于危险函数定义，函数原型也没有被当成定义。

同类实际影响专项：499 个候选对象中，116 个文件含 130 条 include：room.h 110、ansi.h 17、
obj.h/dbase.h/login.h 各 1。逐个读取这 5 个头文件，未见上述函数定义或额外继承，也无传递 include。
dbase.h 的 `set` 是函数原型；其余主要为常量宏和 guards。
**当前语料未确认触发 FR7-01；合成输入已足以证明契约缺陷。**
这不是“实际语料零命中所以 PASS”，也不意味着任何未来 resolved header 都安全。

本地 ignored evidence：`build/migration-tooling-v1/final-p2f7/include-sibling-evidence.json`、
`include-prototype-evidence.json`、`include-actual-uses.json`。输入原文、SHA、facts/findings 均保存；
本报告的复现与表格独立可读，不要求提交这些产物。

## 2. Frozen identities

| Identity | Value |
| --- | --- |
| Repository | Toxicccxz/eastern-stories-godot |
| Branch | `phase/migration-tooling-v1` |
| Executable HEAD / origin phase | `b10faeded5ddf39aefd136d0134bff81ca4446b5` |
| Parent | `a9b19467074b1cc697ba40a40d5954c20b4bc43a` |
| Subject | Fix raw echo directive semantics |
| main / origin main / merge base | `cd07808cb76147d0b8c0dad9b82d078b49fefe64` |
| reference tree | `4106480ab28cce8cd7b55704f8ae9ae062d42d03` |
| Initial tracked/index delta | 0 |
| Initial untracked audits | Exactly 5 protected historical reports |

Fresh fetch completed before the audit. GitHub PR search for this phase branch in all states returned none.
No remote CI was started or claimed. There is no docs-only audit commit because verdict is BLOCKED.

## 3. Ten-commit milestone history

| Commit | Subject |
| --- | --- |
| `0e5ff6a5cbc8d4091102e280c66868ba8763b4bb` | Analyze Migration Tooling v1 extraction contract |
| `8108763d6a4ddb3ad2b110200666424f4042e296` | Record Migration Tooling v1 P2 decisions |
| `8efc21ff8aa4c4c293347386f951631c56559fe2` | Add Migration Tooling v1 static room extractor |
| `1adb6534d579c5a2c1a4d21e166fb244096daa57` | Fix Migration Tooling v1 audit blockers |
| `864ebc4c8a749f3e56a39cd5cf0685b07765fd00` | Fix Migration Tooling v1 re-audit blockers |
| `c0c7ffb3de3e26cadf395772f7503e71d3690e11` | Complete weapon and armor migration exclusions |
| `820d478587fd69d3cf20c861e2694497eac8ef79` | Complete remaining standard object migration exclusions |
| `8cc5a01741232ed062aff52bee0e77b4d4351b39` | Fix comment-prefixed directive recognition |
| `a9b19467074b1cc697ba40a40d5954c20b4bc43a` | Fix multiline comments inside directives |
| `b10faeded5ddf39aefd136d0134bff81ca4446b5` | Fix raw echo directive semantics |

## 4. Complete milestone diff

Fresh main→HEAD diff: **20 files, +5,442 / −11**.

| Group | Files | Added / deleted |
| --- | ---: | ---: |
| docs: DECISIONS, P1/P2/P2F1–P2F7, STATUS/ROADMAP | 12 | +2,743 / −11 |
| tools/migration production modules | 4 | +1,107 / −0 |
| test_migration_tooling.py | 1 | +1,549 / −0 |
| hand-authored fixture source/expected/README | 3 | +43 / −0 |

No game/, reference/, CI workflow or runtime Save delta in this milestone.
Full sensitive-content/manual artifact sign-off remained incomplete at the blocker stop; see §38.

## 5. P1 / P2 / P2F1–P2F7 state

Current owner instruction supersedes older report checkpoints: P1/P2/P2F1–P2F7 are OWNER APPROVED / CLOSED;
FR-01/FR5-01/FR6-01/FR6-02 are closed historical corrections. The five historical audit verdicts remain BLOCKED.
This newly authorized audit is now BLOCKED on FR7-01; it does not revoke the historical correction acceptance.
STATUS/ROADMAP still contain their pre-audit P2F7-await-review checkpoint and are intentionally unchanged.
No phase PR, merge or P3 authorization. The milestone is not fully integrated on main.

## 6. D1–D9

| Rule | Fresh assessment |
| --- | --- |
| D1 | Four modules remain Python stdlib/local imports; no Godot/LPC runtime or third-party parser |
| D2 | **BLOCKED / FR7-01:** included excluded inherits bypass object-category admission |
| D3 | **BLOCKED / FR7-01:** included setter/duplicate create bypass reliable fact boundary |
| D4 | Schema1/static-room-v1/version1.0.7; independent IR; fresh canonical A/B equal |
| D5 | All 9,838 corpus provenance records independently checked; 2,622 directive-probe records checked |
| D6 | **BLOCKED / FR7-01:** unsupported dependency context still yields exact/normalized facts; no LPC execution occurred |
| D7 | Independent output confinement and nested overwrite attacks passed; details §20–21 |
| D8 | Existing stdlib regression suite passed; disposable audit probes remain ignored, no test/golden mutation |
| D9 | Fresh corpus exit1, safe synthetic directives exit0, protected writes exit2; final all-13 manual quarantine sign-off STOPPED |

No rule is declared globally satisfied merely because its existing tests are green.

## 7. Complete thirteen-item historical blocker matrix

“CLOSED” below applies to the original reproducer/regression, not all possible related constructs.

| Historical blocker | Severity | Fresh evidence / disposition |
| --- | --- | --- |
| output target confinement bypass | HIGH | CLOSED: regression + independent 8-target attack |
| continued critical macro shadow bypass | HIGH | CLOSED: regression + split-define/prefix matrices |
| literal excluded base admission | MEDIUM | CLOSED: original direct-form regression; new included-form gap is FR7-01 |
| unresolved include admission | MEDIUM | CLOSED: regression + missing-header directive matrix |
| computed balanced mapping false syntax error | MEDIUM | CLOSED: AuditBlockerRegressionTests in fresh 136-test suite |
| nested/manual metadata overwrite | HIGH | CLOSED: regression + all 33 generated dictionary-node attacks |
| MONEY / COMBINED_ITEM admission | MEDIUM | CLOSED: P2F2RegressionTests on exact HEAD |
| weapon/armor completeness | MEDIUM | CLOSED: P2F3RegressionTests on exact HEAD |
| globals standard-object completeness | MEDIUM | CLOSED: P2F4RegressionTests on exact HEAD |
| FR-01 comment-prefix bypass | HIGH | CLOSED: 100 prefix hazard probes + original cases |
| FR5-01 multiline directive comment false quarantine | MEDIUM | CLOSED: original LF/CRLF CLI + broad generic matrix |
| FR6-01 raw echo swallowing next directive | HIGH | CLOSED: 120 CLI next-line cases |
| FR6-02 raw echo false quarantine | MEDIUM | CLOSED: 60 raw echo cases and 18 split-echo cases |

## 8. Globals authority completeness

Fresh read of [globals.h](../../reference/es2/mudlib/include/globals.h) confirms 16 inheritable object constants:
ROOM, SSERVER and 14 explicit excluded bases (BANK, BULLETIN_BOARD, CHARACTER, CLASS_GUILD,
COMBINED_ITEM, EQUIP, FORCE, HOCKSHOP, ITEM, LIQUID, MONEY, NPC, POWDER, SKILL).
Production exact-literal table matches those 14; inherited-base source reads included bboard/char/npc/equip/powder/skill.
Existing direct symbol/literal authority regressions passed. Planned extra independent full authority matrix was
**STOPPED** on FR7-01; no final authority-wide PASS is claimed.

## 9. Weapon / armor authority completeness

Fresh weapon.h/armor.h reads confirm nine object weapon bases and eleven object armor bases.
Production exact table retains those 20 separately from F_* features and TYPE_* values.
Existing drift and symbol/literal regression tests passed. Additional independent near-name/feature matrix
was **STOPPED**, not silently substituted with an older audit result.

## 10. SSERVER assessment

Fresh read of [sserver.c](../../reference/es2/mudlib/std/sserver.c): F_CLEAN_UP plus offensive_target helper,
enemy selection capped at four and random target selection. Unlike std/skill.c, this is not itself the skill skeleton.
Fresh code-token inventory found **19 direct SSERVER uses: 18 .c and one recover.d**, no literal
`"/std/sserver"` direct use, no supported ROOM candidate involvement. Inventory excludes comment/string/heredoc mentions.
Do not infer SSERVER = SKILL or evaluate helper/RNG semantics. Independent synthetic ROOM+SSERVER acceptance matrix
was not completed before STOP; no additional SSERVER implementation defect is asserted.

## 11. Directive / preprocessor class-wide audit

Completed before FR7-01: **430 actual CLI cases + 484 generic lexer/parts cases**.

| CLI group | Count |
| --- | ---: |
| hostile echo payload then ten critical directive forms, LF/CRLF | 120 |
| five whitespace/comment prefix forms × ten hazards × LF/CRLF | 100 |
| fifteen raw payloads × line/EOF × LF/CRLF | 60 |
| split echo heads × hostile payloads × LF/CRLF | 18 |
| split define LF/CRLF | 2 |
| eight generic/unknown keywords × seven body types × LF/CRLF | 112 |
| real-code/comment/string/heredoc contained # | 10 |
| original FR-01 / FR5-01 reproducers LF/CRLF | 6 |
| genuinely unclosed generic comment/string | 2 |

484 lexical cases cover eleven generic directive families × eleven body shapes × LF/CRLF × newline/EOF.
Bodies include escaped quotes, characters, quoted symbols, //, multiple/multiline blocks, outside continuation,
and a second # after a multiline comment close. Tokens retained full authored bytes; keyword parts were checked.
All planned assertions in this completed matrix passed. This is bounded evidence, not proof of full LPC grammar.
Ignored evidence: `build/migration-tooling-v1/final-p2f7/directive-evidence.json`.

## 12. Authoritative manual review

Freshly read [concepts/preprocessor](../../reference/es2/mudlib/doc/concepts/preprocessor) and
[preprocessor README](../../reference/es2/mudlib/doc/lpc/preprocessor/README),
[define](../../reference/es2/mudlib/doc/lpc/preprocessor/define),
[include](../../reference/es2/mudlib/doc/lpc/preprocessor/include).
They describe include as textual insertion, macros, conditional compilation, raw echo, pragma and @/@@ formatting.
Only echo is documented here as a verbatim remainder-of-line/EOF message; no new error/line raw-message rule inferred.
The include text-insertion rule directly supports FR7-01; recognizing a header path alone cannot erase its declarations.
No driver/runtime implementation was imported or executed.

## 13. First-column / comment-prefix semantics

Manual requires # at the first column. Tool intentionally recognizes preceding whitespace/block-comment trivia,
including multiline prefix and split heads, as the existing conservative contract requires.
Fresh raw C/H inventory found **all 2,060 observed directives at column 1**; no actual whitespace/comment-prefix case.
100 hazard prefix cases suppress the same facts as column-one controls; contained # and real-code prefixes remain distinct.
No material false-positive interpretation was demonstrated in this bounded prefix matrix. Difference remains a driver/tooling
qualification, not a new blocker. This does not excuse the separately confirmed include-context defect.
Damaged-source inventory limitations are stated in §25.

## 14. FR-01

Original comment-prefixed set macro and conditional reproductions were run through CLI in LF/CRLF.
Setter form emits only inherit; conditional form is OUT_OF_SCOPE/facts=[].
The 100-case prefix-hazard sweep also passed. CLOSED for this historical defect.

## 15. FR5-01

Original `#define LABEL 1 /* first\nsecond */` between inherit and create ran via CLI in LF/CRLF:
exit0, candidate=true, PARTIAL, inherit+short; no false quarantine. Multiple block/continuation/EOF shapes
passed the generic matrix. Genuine unclosed comment/string controls still quarantine. CLOSED.

## 16. FR6-01

Six payloads (`/*`, quote, @MARKER, @@MARKER, backslash, plain) × ten next-line forms × LF/CRLF = 120 CLI cases.
Next forms: define/undef ROOM, set, create, __DIR__, missing include, #if.
Each next directive independently recognized. ROOM/include/conditional cases emit no facts; set/create only inherit;
__DIR__ cases retain inherit/short but no normalized exit. CLOSED.

## 17. FR6-02

Raw echo payloads including quote, /*, */, //, @, @@, #, backslash, nested-looking directives, Unicode and mixed text
do not cause false SOURCE_SYNTAX_ERROR. LF/CRLF/EOF controls passed. No hostile payload generates code/facts.
Split keyword echo also preserves the physical-line payload rule. CLOSED.

## 18. Raw echo semantics

Exact lowercase maximal keyword only. Split ec/ho, e/c/ho and head splice were exercised.
Once the keyword completes, payload is raw through physical newline/EOF; trailing message backslash does not swallow
the next critical directive. Same-line # is message data. Payload is not re-lexed by directive_parts.
No runtime echo execution or migration fact was introduced.

## 19. Unknown / pragma directive sweep

echofoo, echo_value, Echo, echo1, unknown, pragma, error and line used generic handling in 112 CLI cases.
Ordinary/quoted/escaped/character/symbol/comment/continued forms neither crash nor acquire echo special handling.
Balanced unsupported forms retain generic warnings; truly unclosed generic delimiters quarantine.
No authoritative second raw-message directive was discovered in the read manuals.

## 20. Output security

Independent external-source attack matrix: game/, reference/es2/, docs/, repository arbitrary root file,
each absolute and repository-parent-relative: **8/8 exit2, writer not called, target absent, parent listing unchanged**.
Approved ignored build output and legitimate external output succeeded. Existing tracked external-checkout target
was refused and bytes preserved. No protected destination was actually written.
Fresh regression tests also cover invalid/root/overlap/linked paths and atomic-write handling.
Filesystem TOCTOU remains a qualification; no claim of hostile-concurrent-filesystem hardening.

## 21. Closed schema / version compatibility

Version1.0.7; known set exactly 1.0.0–1.0.7. All eight complete historical corpus files were freshly recognized
and copied to a temporary target, then successfully replaced by real CLI version1.0.7 output (exit0).
Historical originals unchanged; not merely a top-level version-string test.
Additionally, independent traversal of a generated canonical document found **33 dictionary nodes** across every
requested layer. Unknown manual note injected at each node: **33/33 exit2, writer not called, original bytes unchanged**.
Includes typed value, normalization/input, reference, provenance/raw_hex, manifest entry, summary/status/code maps.
This recognizes a closed structure, not cryptographic authorship; hand-edited known-schema values are not authenticated.

## 22. Fact boundary

**BLOCKED / FR7-01.** Local main-file setter/receiver/nesting/duplicate-create regressions pass, but include definitions
bypass the same rules. Full independent false-positive/fact matrix was stopped at this confirmed defect.
Fresh corpus field allowlist and create scope checks passed mechanically; they do not prove semantic safety.
All corpus long facts remain TEXT_ONLY. No arbitrary gameplay state or inherited defaults were generated.

## 23. Exit boundary

Fresh source reads of street1/school1/pine3/keep2/lake support the intended separation of literal exits,
RNG, doors and runtime mutations. Corpus normalization provenance was fully byte-checked.
However FR7-01 emits SOURCE_DIR_LITERAL_CONCAT exits even when an included local setter means the call is not
the reliable base setter. **This boundary cannot receive PASS.** Extra independent exit ordering/duplicate/dynamic
case matrix was stopped; existing regressions passed but are not a replacement for that planned work.

## 24. Full provenance audit

All **9,838** fresh corpus provenance records checked independently against original raw bytes:

| Category | Count |
| --- | ---: |
| direct inherits | 1,799 |
| facts | 2,804 |
| findings | 4,457 |
| normalization inputs | 778 |
| corpus raw_hex | 0 |

For each: raw SHA, half-open bounds, exact raw slice, 1-based line/Unicode column. 1,295 spans contain non-ASCII;
3 records are from CRLF sources. Fact IDs recomputed; source ordering checked.
Separate invalid UTF-8 `0xff` probe verifies raw_hex variant. Directive CLI matrix adds **2,622** provenance checks:
402 inherit, 742 fact, 1,298 finding, 180 normalization, covering prefix/continuation/multiline/echo/Unicode/CRLF.
Byte accuracy does not make FR7-01 facts semantically eligible.

## 25. Directive keyword inventory

Fresh independent raw-byte state scanner: **1,817 C/H files, 2,060 directives**.

| Kind | Count |
| --- | ---: |
| include | 981 |
| define | 690 |
| undef | 22 |
| if | 15 |
| ifdef | 116 |
| ifndef | 37 |
| elif | 6 |
| else | 22 |
| endif | 168 |
| echo | 0 |
| pragma | 3 |
| unknown | 0 |

Supported candidates contain 130 include directives and no other directive kind.
All 1,817 raw files were scanned, including damaged ones. Production token-span cross-check succeeded for 1,807;
10 cannot produce a complete lexer result (8 encoding/NUL/replacement files and 2 unterminated-string files).
The independent raw scanner includes their readable prefixes but cannot establish compiler semantics beyond corrupt text;
unterminated string content remains opaque through EOF. Zero counts are lexical observations, not a repair or proof of damaged tails.

## 26. Comment-prefix inventory

Fresh count **0**, hence no paths/line numbers/kinds or ROOM output impact found in actual C/H source.
This was recomputed, not copied from P2F5. Synthetic coverage is §11/13/14.

## 27. Directive-internal multiline-comment inventory

Fresh count **0** for block comments starting inside directives and crossing a physical newline.
No actual paths/kinds/ROOM impact found. Scanner distinguishes raw echo payload from a generic block comment.
Synthetic closed/unclosed and second-# cases completed as above.

## 28. Echo inventory

Fresh exact echo count **0**; comment-prefixed echo 0, ROOM involvement 0, actual payload/path/line list empty.
No actual-corpus output delta attributable to echo was found; hostile synthetic payloads remain necessary contract tests.

## 29. Real-source review

Fresh text reads completed for roommaker.c, city/street1.c, snow/school1.c, oldpine/pine3.c, oldpine/keep2.c,
village/lake.c, latemoon/sroad1.c and latemoon/upstar/upcenter.c.
roommaker contains ROOM_CODE heredocs; street1 has ordered __DIR__ exits; school1 includes doors/population;
pine3 has four RNG targets; keep2 mutates exits in callbacks; lake explicitly sets no_clean_up=0.
sroad1 has a broken north key quote; upcenter contains a replacement character.
The complete required 12-source manual facts/findings comparison was **STOPPED**, including remaining
lordhouse3/goddd/sword_book/guihua detailed comparisons. No comprehensive real-source PASS is claimed.

## 30. Fresh local tests

All ran on exact executable `b10faeded5ddf39aefd136d0134bff81ca4446b5` before FR7-01 stop:

| Command | Fresh result |
| --- | --- |
| python -m unittest discover -s tools/tests -p "test_migration_tooling.py" -v | 136 PASS, 15.685s |
| python -m unittest discover -s tools/tests -p "test_*.py" -v | 182 PASS, 16.990s |
| python tools/ci/repository_checks.py --repository . | PASS |
| git diff --check | PASS |

No remote CI run. No Godot live/headless/canonical gameplay run: pure parser/tooling audit does not require gameplay.
Existing tests do not cover FR7-01; green tests do not close it. New probes are audit-only, not test modifications.

## 31. Complete docs validation

Before the new report: **227 local Markdown links, 10 anchors, 0 failures** across changed milestone markdown and
repository authority docs. Targets, relative paths, anchor slugs and tracked status checked; untracked historical
audit targets were not treated as committed links.
This is link validation, not full narrative approval. Complete consistency/manual review was stopped (§39).
Including this new untracked report, final report-quality validation checked **236 links, 10 anchors, 0 failures**.
All 42 numbered sections and trailing whitespace were checked. No docs-only commit exists.

## 32. Whole-corpus A/B

Fresh actual CLI runs to two distinct ignored paths; both completed with exit1:

| Metric | A | B |
| --- | ---: | ---: |
| scanned | 2,336 | 2,336 |
| supported | 499 | 499 |
| EXTRACTED | 0 | 0 |
| PARTIAL | 499 | 499 |
| OUT_OF_SCOPE | 1,824 | 1,824 |
| QUARANTINED | 13 | 13 |
| facts | 2,804 | 2,804 |
| findings | 4,457 | 4,457 |
| bytes | 10,030,223 | 10,030,223 |

Finding distribution: CALLBACK_BEHAVIOR 326; DRIVER_SEMANTICS_UNKNOWN 410; DYNAMIC_EXPRESSION 11;
ORDER_SENSITIVE_MUTATION 36; OUT_OF_SCOPE 1,305; REQUIRES_SEMANTIC_REVIEW 1,713; RNG_SEMANTICS 62;
SOURCE_ENCODING_ISSUE 8; SOURCE_SYNTAX_ERROR 5; UNRESOLVED_INCLUDE 97; UNSUPPORTED_CONSTRUCT 484.
Full findings/status counts independently recomputed, not forced to historical expectations.

## 33. All thirteen quarantines

Fresh emitted set, all **facts=[]**. Corpus byte checker records raw corruption counts and diagnostic context.

| Source path under mudlib | Fresh classification | Fresh evidence / remaining manual work |
| --- | --- | --- |
| cmds/std/exercise.c | ENCODING | U+FFFD count1, diagnostic byte2033 |
| d/choyin/npc/yamen_po.c | ENCODING | U+FFFD count3, first diagnostic byte4382 |
| d/latemoon/upstar/upcenter.c | ENCODING | U+FFFD count1, byte337, heredoc inspected |
| d/temple/npc/obj/magic_book.c | ENCODING | U+FFFD count1, byte863 |
| d/temple/npc/obj/spells_book.c | ENCODING | U+FFFD count1, byte840 |
| d/temple/obj/magic_book.c | ENCODING | U+FFFD count1, byte863 |
| d/temple/obj/spells_book.c | ENCODING | U+FFFD count1, byte840 |
| u/cloud/obj/npc/flower_girl/guihua.c | ENCODING | NUL338 / U+FFFD110; diagnostic byte4 |
| d/latemoon/sroad1.c | SYNTAX | Actual source has missing closing quote in north key; diagnostic later unterminated string |
| d/npc/oldman.c | SYNTAX | Fresh diagnostic/context collected; final independent root-cause read STOPPED |
| d/village/lordhouse3.c | SYNTAX | Fresh diagnostic/context collected; final independent root-cause read STOPPED |
| u/cloud/npc/goddd.c | SYNTAX | Fresh diagnostic/context collected; final independent root-cause read STOPPED |
| u/cloud/obj/sword_book.c | SYNTAX | Fresh diagnostic/context collected; final independent root-cause read STOPPED |

No source was repaired. Positive encoding evidence is distinct from unsupported syntax.
**The requested complete individual manual quarantine acceptance is not finished**, so D9 is not globally signed off.

## 34. Manifest / finding / summary integrity

Fresh independent checks: unique object IDs/input paths; full manifest matches 2,336 physical tracked files;
sorted manifest; source bytes/size/hash; object–manifest association; allowed statuses; finding IDs contiguous per
object and referenced correctly; per-object findings sorted by byte/code/reason; exact summary counts.
Whole-document traversal found **11,934 review_state nodes, all UNREVIEWED** (not just fact/finding nodes).
No object omission or automatic approval observed. Extractor-relative manifest digest:
`895d36086e184ba6bf520625c20e882394a0a6169aabf86a1b4c58ba835e2820`.

## 35. Determinism

Independent outputs A/B are byte-for-byte equal, size10,030,223, both SHA-256:
`1c5e3cbfdcf050a9d7236772aa5c5d409c6951a6fd30093908ea46e4f8b542f6`.
This was freshly computed; equality to P2F7's historical digest is a result, not an expected-output substitution.
Deterministic output can still contain a latent extraction defect, as FR7-01 demonstrates.

## 36. Source immutability

Before/after reference git tree remains `4106480ab28cce8cd7b55704f8ae9ae062d42d03`.
Independent raw-byte manifest over lexically sorted repository-relative paths: 2,336 files,
SHA-256 `744e33e1740db7909129a3ae5e295158341b5012a411af953b144a5075bb0a80`.
Each entry is path + NUL + source SHA-256 + LF. No repair, normalization, source generation or probe residue.
The repository-relative digest and extractor-relative digest intentionally use different path namespaces.

## 37. Historical-audit immutability

All five remain local/untracked/unstaged and byte-identical. Full SHA-256:

| Report basename under docs/migration | SHA-256 |
| --- | --- |
| MIGRATION_TOOLING_V1_FINAL_AUDIT.md | `a61cd221e8b70961d963484dfe953f5e341511967d9cfd66a55159b1bab85d63` |
| MIGRATION_TOOLING_V1_RE_FINAL_AUDIT.md | `c67dc612139bf37a6c6a41d4753b58723b154d0f6e92cdca0ab5a34ad93d0548` |
| MIGRATION_TOOLING_V1_FINAL_RE_AUDIT_AFTER_P2F4.md | `c4ff8faccea5b79d0ba4007d2d616007f4a55fda3b84e58e78875d68f4e4aed0` |
| MIGRATION_TOOLING_V1_FINAL_RE_AUDIT_AFTER_P2F5.md | `0d93333f8db116db7f6af0cb79e201b26228010cc5e85592adf30cdeb4c94be9` |
| MIGRATION_TOOLING_V1_FINAL_RE_AUDIT_AFTER_P2F6.md | `8a9ba2d9bfd666b949b470d872820c63d5adeab26d849deef7e4460b45593b76` |

This report is the sixth untracked audit. No historical report is staged, linked as a committed deliverable or rewritten.

## 38. Security / artifact review

Milestone file inventory and byte sizes were inspected; production modules, tests and fixtures are text;
corpus/probes remain under ignored build. Output-security attacks completed (§20–21).
The requested complete manual diff search for credentials, personal/save data, workstation paths,
third-party copied code and unexpected artifacts was **STOPPED** after FR7-01. No final security/artifact PASS.
No new tracked artifact or dependency was introduced by this audit.

## 39. Documentation consistency

DECISIONS D1–D9 and P2's “only an unambiguous bare set in one create” boundary were explicitly checked against FR7-01.
STATUS/ROADMAP's earlier P2F7 await-review wording is historical relative to the current owner's approval and audit request;
it is not itself a newly discovered implementation blocker. Those files remain unchanged per BLOCKED instructions.
Full P1/P2/P2F1–P2F7 narrative consistency sign-off was **STOPPED**, distinct from completed link validation.
No historical untracked audit is represented here as committed.

## 40. Residual risks

FR7-01 is **HIGH material defect**, not a residual risk. Remaining items are provisional qualifications;
unfinished final checks prevent a complete residual-risk-only verdict.

| Level | Assessment |
| --- | --- |
| HIGH defect | FR7-01 include-context reliability gap; requires separately authorized correction |
| MEDIUM qualification | Bounded lexer/preprocessor is not full LPC grammar; unsupported valid LPC may have false negatives; must not be misclassified as corruption |
| MEDIUM qualification | Historic source corruption and unresolved MudOS/SSERVER semantics require review; no runtime parity claim |
| MEDIUM qualification | License/provenance/public-release clearance is not granted by this private tooling audit; complete milestone artifact review unfinished |
| LOW qualification | First-column manual versus intentional trivia-prefix recognition; tested conservatively, zero observed corpus occurrences |
| LOW qualification | Filesystem TOCTOU remains; canonical structure recognition is not cryptographic authorship |
| LOW qualification | Case-sensitive descriptive paths may differ from workstation lookup; no case repair permitted |
| LOW qualification | Approximately 10 MB IR is ephemeral, verbose and memory-loaded; no Native consumer or runtime approval |
| PENDING integration | No phase PR/remote CI/merge; prior main CI is historical evidence only |

## 41. PR readiness

**NOT READY FOR PR.** Same phase branch remains at b10faeded5ddf39aefd136d0134bff81ca4446b5.
No implementation/test change; no docs-only commit or push. No new branch, draft/final PR, merge or CI weakening.
Migration Tooling v1 has accepted implementation slices but is blocked in final audit and not integrated on main.

## 42. Exact next owner gate

Await owner review of FR7-01 and an explicit decision on a bounded correction on the existing major-phase branch.
This audit does not implement that correction, authorize P3, or silently continue unrelated unfinished checks.
After any authorized correction, a fresh complete audit must finish the stopped items and reevaluate all contracts.
No request for PR/merge approval is made while a material defect remains.

**MIGRATION TOOLING V1 FINAL RE-AUDIT AFTER P2F7 BLOCKED**

**NOT READY FOR PR — AWAIT OWNER REVIEW**
