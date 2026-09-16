# Migration Tooling v1 — Final Re-Audit after P2F8

## 1. Executive verdict

**BLOCKED — NOT READY FOR PR.** 2026-09-16.

新发现 **FR8-01 / HIGH：宏别名可以隐藏 set/create 函数定义或 inherit 结构，绕过根文件与 include 的可靠性保护**。
违反 **D2 / D3 / D6**。本次没有实施修复；发现后只进行有限同类扫描与报告收尾，停止其余独立审计。

| Gate | Result |
| --- | --- |
| HIGH blockers | 1 — FR8-01 |
| Other confirmed blocking MEDIUM | 0 |
| Material D1–D9 defects | 1 shared macro-alias reliability defect |
| Full final-audit completion | STOPPED under owner blocker rule |
| Production/tests/fixtures/STATUS/ROADMAP/DECISIONS modified | None |
| Commit / push / PR / merge | None in this audit |

### Exact reproducer

UTF-8 / LF，两个文件均保留末尾换行。真实 CLI 从临时外部 source-root 提取到另一个临时目录。

`d/hazard.h`:

```c
#define LOCAL_SET set
mixed LOCAL_SET(string key,mixed value){return 0;}
```

`d/room.c`:

```c
#include "hazard.h"
inherit ROOM;
void create(){set("short","unsafe");set("exits",(["east":__DIR__"east"]));}
```

```text
python -m tools.migration.cli --source-root <temporary-source> --output-root <temporary-output>
exit = 0
supported_candidate = true
status = PARTIAL
fields = [inherit, short, exit]
short = "unsafe" / EXACT_LITERAL
exit = /d/east / STATIC_NORMALIZED
```

| File | SHA-256 |
| --- | --- |
| d/hazard.h | `821bc479620dc0ef7f44f7fee257d97817e960ceed29ecc21ef6dbc21f98b6bb` |
| d/room.c | `ba18605554c7c47a6084f3a813067a19016f81a73dbe64e14e8d3666c4dfb086` |

权威 [define 文档](../../reference/es2/mudlib/doc/lpc/preprocessor/define) 规定定义后的宏名按替换文本处理；
[include 文档](../../reference/es2/mudlib/doc/lpc/preprocessor/include) 规定文本包含。因此该头文件定义的是
本地 set 函数，返回 0，不是标准 dbase setter。它直接写成 `mixed set(...)` 时，当前保护只保留 inherit，
不输出 short/exit；取别名后却仍输出。无需执行 LPC 或依赖外部驱动实现，即可确定两种表示的关系。

根 findings 是 UNSUPPORTED_CONSTRUCT、REQUIRES_SEMANTIC_REVIEW、UNRESOLVED_REFERENCE；
后者仅由于测试目标 /d/east 不存在。通用 PARTIAL/warning/消费阻断不能替代对具体 fact 资格的正确判断。
这不是要求工具计算任意宏，而是要求未可靠理解的宏参与声明时不能作“标准 setter 安全”的假设。

### Root cause

[room_extractor.py](../../tools/migration/room_extractor.py):274–319 的 include 结构摘要只识别原始 token：
函数名须恰为 set/create（:302–304），inherit 须恰为开头关键字。
:364–405 的依赖检查只检查宏定义/取消定义的左侧名字是否为 ROOM/set/create/__DIR__（:381）。
LOCAL_SET、LOCAL_CREATE、LOCAL_INHERIT 等别名没有形成危险上下文。
主文件函数/继承结构检测也使用原始名字（约 :470、:486、:524），因此问题不限于头文件。

例如 `#define LOCAL_INHERIT inherit` 后的 `LOCAL_INHERIT NPC;` 不会被摘要识别为包含继承，
也没有保守阻止准入；工具继续输出 ROOM 的 short/exit，违反 D2。
`#define LOCAL_CREATE create` 后的函数定义使 create 不再可靠唯一，但仍产生 create facts，违反 D3。
set 别名还允许不可靠的 __DIR__ exit 归一化，违反 D6。

### Bounded same-class sweep

**110 个真实 CLI subprocess**：11 种输入 × 5 种布局 × LF/CRLF。
布局：主文件直接声明、单头文件、嵌套头文件、两个相邻 include 分开提供宏/声明、根宏+头文件声明。
所有样本 exit0；40 个危险别名样本输出不可靠 short/exit，70 个对照符合其预期边界。

| Family | Cases | Observed result |
| --- | ---: | --- |
| LOCAL_SET → set，声明使用 LOCAL_SET | 10 | **10/10 unsafe**：candidate=true，inherit+short+exit |
| LOCAL_CREATE → create，声明使用 LOCAL_CREATE | 10 | **10/10 unsafe**：未阻止不唯一 create 的 facts |
| LOCAL_INHERIT → inherit，后接 NPC | 10 | **10/10 unsafe**：未阻止准入，仍输出 inherit+short+exit |
| FIRST → SECOND → set 的短别名链 | 10 | **10/10 unsafe**：未阻止 setter facts |
| 整段函数声明宏调用对照 | 10 | OUT_OF_SCOPE / facts=[] |
| 带参数的名字宏对照 NAME(set) | 10 | OUT_OF_SCOPE / facts=[] |
| 直接 set 定义 | 10 | candidate=true / PARTIAL / inherit only |
| 直接 create 定义 | 10 | candidate=true / PARTIAL / inherit only |
| 直接 inherit NPC | 10 | OUT_OF_SCOPE / facts=[] |
| 未使用的 LOCAL_SET 宏 | 10 | 正常保留 root facts |
| 仅给普通 helper 取别名 | 10 | 正常保留 root facts |

没有将“所有宏/所有 include 都不安全”作为期望，也没有要求全面宏展开。
函数宏/整段声明宏对照说明某些复杂未知结构已经保守拒绝；漏洞在看起来像普通声明的别名形式。
未增加或改写任何正式测试。完整输入、SHA、fact/finding 位于 ignored
`build/migration-tooling-v1/final-p2f8/alias-sibling-evidence.json`；报告正文可独立复现。

### Actual-corpus same-class scope

只对该新缺陷进行有限实际语料检查：1,807 个可完整 lex 的 C/H 文件中有 6 条单标识符 object-like
宏别名边，未找到直接或经这种别名链指向 set/create/inherit 的边。
10 个源码损坏文件不能完整 lex，另行记录为覆盖限制，不宣称它们绝对不存在同类文本。
这是潜在别名关系的 token 清单，不是跨文件预处理执行，也不是全体宏形式的穷尽证明。
**尚未证明现有语料受影响；合成输入已证明 material defect。**

## 2. Frozen identities

| Identity | Value |
| --- | --- |
| Repository | Toxicccxz/eastern-stories-godot |
| Branch | phase/migration-tooling-v1 |
| HEAD / origin phase | `12a02e7fd989f40cb7da7059de74e9560b077c59` |
| Subject | Fix resolved include semantic hazards |
| main / origin main / merge base | `cd07808cb76147d0b8c0dad9b82d078b49fefe64` |
| Initial tracked/index | Clean |
| Initial untracked audits | Exactly six |
| Phase PR | None, fresh all-state GitHub search |

Fresh fetch completed. No reset/rebase/merge/stash/clean/amend/force-push. No new CI run or integration claim.
Historical main integration evidence does not count as CI for this phase.

## 3. Eleven-commit milestone history

| Commit | Subject |
| --- | --- |
| 0e5ff6a | Analyze Migration Tooling v1 extraction contract |
| 8108763 | Record Migration Tooling v1 P2 decisions |
| 8efc21f | Add Migration Tooling v1 static room extractor |
| 1adb653 | Fix Migration Tooling v1 audit blockers |
| 864ebc4 | Fix Migration Tooling v1 re-audit blockers |
| c0c7ffb | Complete weapon and armor migration exclusions |
| 820d478 | Complete remaining standard object migration exclusions |
| 8cc5a01 | Fix comment-prefixed directive recognition |
| a9b1946 | Fix multiline comments inside directives |
| b10faed | Fix raw echo directive semantics |
| 12a02e7 | Fix resolved include semantic hazards |

## 4. Complete diff and scope

Fresh main→HEAD: **21 files, +5,967 / −11**.

| Group | Files | Delta |
| --- | ---: | --- |
| DECISIONS, phase reports, STATUS/ROADMAP | 13 | +3,026 / −11 |
| tools/migration modules | 4 | +1,161 |
| migration test module | 1 | +1,737 |
| source/expected/README fixtures | 3 | +43 |

No reference/es2, game, runtime/Save schema or .github/CI delta. No generated corpus in the changed tracked set.
Complete manual sensitive-content/code-origin review was stopped after FR8-01; file inventory alone is not that sign-off.

## 5. D1–D9

| Rule | Fresh evidence / result |
| --- | --- |
| D1 | Existing stdlib module boundary unchanged; no runtime/dependency added in this audit |
| D2 | **BLOCKED FR8-01**: alias-generated inherit bypasses category/include reliability |
| D3 | **BLOCKED FR8-01**: aliases hide standard-setter shadow or create duplication |
| D4 | Fresh schema1/profile static-room-v1/version1.0.8 outputs deterministic |
| D5 | All 9,838 corpus provenance records independently byte-checked; synthetic directive records checked separately |
| D6 | **BLOCKED FR8-01**: no LPC execution, but unreliable context still yields exact/normalized facts |
| D7 | Fresh existing regressions pass; independent output attack rerun STOPPED |
| D8 | Hand-authored fixture reviewed; unittest suite passes; new probes ignored, no snapshot/test edits |
| D9 | Fresh exit1 corpus and positive five syntax-source checks; complete manual all-13 and independent fatal/security matrix STOPPED |

DECISIONS remains locked and unchanged. Contract defects are not residual limitations.

## 6. Fourteen historical blockers

Original reproducer closure is distinguished from newly found related gaps. All named original regression classes
ran within the fresh migration suite; stronger fresh independent evidence is listed where completed.

| Historical finding | Severity | Result / fresh evidence |
| --- | --- | --- |
| Output target confinement bypass | HIGH | CLOSED original regression; independent adversarial rerun pending at stop |
| Continued critical macro shadow | HIGH | CLOSED; split define and prefix matrix |
| Literal excluded base admission | MEDIUM | CLOSED; independent 34-base symbol/literal checks |
| Unresolved include admission | MEDIUM | CLOSED; directive and include matrices |
| Computed mapping false syntax error | MEDIUM | CLOSED; regression + independent computed mapping case |
| Nested/manual metadata overwrite | HIGH | CLOSED original regression; independent full-layer attack rerun stopped |
| MONEY / COMBINED_ITEM admission | MEDIUM | CLOSED; regression + fresh authority cases |
| Weapon/armor completeness | MEDIUM | CLOSED; regression + fresh authority cases |
| Globals object completeness | MEDIUM | CLOSED; regression + fresh authority cases |
| FR-01 comment-prefixed directive bypass | HIGH | CLOSED; 100 prefix CLI cases plus original reproductions |
| FR5-01 multiline directive comment quarantine | MEDIUM | CLOSED; original CLI + generic lexical matrix |
| FR6-01 raw echo next-line bypass | HIGH | CLOSED; 120 next-line CLI cases |
| FR6-02 raw echo false quarantine | MEDIUM | CLOSED; raw/split echo matrix |
| FR7-01 resolved include semantic hazards | HIGH | CLOSED for direct authored structures; 276 new structural cases and direct CLI controls; macro alias gap is FR8-01 |

This table does not assert the whole milestone or all semantic variants are safe.

## 7. Globals authority

Fresh helper reads explicit standard-object definitions from globals.h/weapon.h/armor.h, yielding 34 excluded bases:
14 globals + 9 weapons + 11 armor. For every base, symbol and exact literal with ROOM reject admission;
near-name and near-literal variants stay unresolved rather than being fuzzily classified. **136 cases passed**.
ROOM and SSERVER were deliberately not inferred as excluded bases. Full additional manual authority/source-family
review was stopped; previous implementation reports remain historical evidence, not a new comprehensive sign-off.

## 8. Weapon / armor

Fresh authority-derived tests and existing hand-authored drift regressions agree on 9/11 object bases.
F_SWORD, F_EQUIP and TYPE_ARMOR synthetic controls are not promoted to excluded object categories;
without direct ROOM none is a supported room. No production authority table change.

## 9. SSERVER

Fresh synthetic SSERVER symbol/literal controls: alone OUT_OF_SCOPE; with direct ROOM retain authored inheritance
with unresolved semantics. Actual SSERVER usage inventory and fresh implementation reread were **STOPPED**.
Do not reuse earlier counts as this audit's corpus result or claim a new automatic-exclusion rationale.

## 10. Directive class-wide audit and manual first-column boundary

Completed fresh **430 real CLI cases + 484 generic lexer/parts cases**. CLI groups:
120 echo-next-line, 100 prefix hazards, 60 raw echo, 18 split echo, 2 split define,
112 generic/unknown, 10 opaque/real-code prefix, 6 original FR-01/FR5-01, 2 genuinely unclosed controls.
All expectations passed. Generic bodies include quotes/escaped quotes, characters, quoted symbols, //,
single/multiple/multiline comments, second #, outside continuation, LF/CRLF/EOF.

Manual first-column requirement versus intentionally accepted trivia prefixes remains a tooling difference.
Fresh prefix matrix did not show unsafe output: hazards conservatively suppress facts, while # inside real code,
comments, strings and heredocs is not a new directive. Fresh actual first-column inventory was stopped;
do not copy the prior zero-occurrence claim into this audit.

## 11. Raw echo

Exact echo stays raw through physical newline/EOF. Quotes, comment markers, @/@@, #, Unicode, backslash and nested
directive-looking messages remain payload. Ten kinds of critical next-line directive stay independently recognized.
Continued exact keyword forms work; echofoo/echo_value/Echo/echo1 and unknown/pragma/error/line remain generic.
No new echo defect in completed fresh matrix. Raw echo actual-corpus inventory was not run before stop.

## 12. Resolved include semantic audit

Fresh independent structural matrix: **276 cases** = 23 header variants × 6 layouts × LF/CRLF.
Layouts: before/between/after root declarations, nested relative, cyclic, repeated.
Cases cover direct set/create, ROOM/NPC/ITEM/custom/literal inherit, helper/data/prototype, opaque/nested-body text,
conditional set/create/inherit, malformed braces/encoding/string, missing include, four critical macro names.
All direct-structure expectations passed; root dependency errors never became root SOURCE_SYNTAX_ERROR.

Combined with 165 independently authored authority/fact/false-positive cases, **441 contract probes passed**.
These use the extractor boundary directly; they are not misrepresented as CLI subprocesses.
The later 110 actual CLI alias cases exposed FR8-01 beyond this otherwise passing matrix.
No blanket include rejection or header provenance copying is proposed or implemented.

## 13. Actual include inventory

**STOPPED**. The complete fresh edge/target/nested/cycle/structural inventory script was prepared but not executed.
Prior P2F8 values are not adopted as new results. Only the bounded actual macro-alias inventory in §1 was completed
after discovery, because it directly scopes the new same-class defect.

## 14. Directive inventories

Fresh whole-corpus keyword, comment-prefix, internal multiline-comment and exact echo inventories: **STOPPED**.
No historical counts/zeroes are reported as current findings. The 1,807-file alias-only inventory is not a substitute.

## 15. Output security

Full Python/migration suites freshly include the existing target confinement and write-protection regressions.
The independent absolute/relative protected-target attack matrix and external/build controls were **STOPPED**.
No protected-path writes were attempted in this audit. Do not claim the prior independent 8-case result as freshly run.

## 16. Closed schema / version compatibility

Fresh suite passes all current schema1 / version1.0.0–1.0.8 tests, including unsafe replacement protections.
Fresh corpus serialization is canonical version1.0.8. Independent nine-complete-corpus replacement replay and
all-dictionary-node manual-field attacks were **STOPPED**; no complete final security/schema sign-off.

## 17. Fact / exit boundary

Independent cases passed: false ROOM text/comment/heredoc/literal/indirect/echo controls; foreign/qualified setter,
nested/control flow, local setter, duplicate create, callback writes, explicit zero for all four flags, absent flags,
TEXT_ONLY long, macro/computed text refusal, ordered duplicate exit directions, dynamic targets, case-mismatch
reference and narrow __DIR__ normalization. No reverse graph, path repair, RNG or runtime execution.

**Boundary BLOCKED despite those controls:** FR8-01 allows short/exit in a macro-aliased setter context,
duplicate create alias, and alias-generated excluded inheritance. Fact source bytes being correct does not prove eligibility.

## 18. Full provenance

Fresh A/B output validation checked **9,838 records** independently:
1,799 direct inherit; 2,804 fact; 4,457 finding; 778 normalization inputs.
Checks cover actual source SHA, byte bounds, raw slice, line/Unicode column, source order and recomputed fact IDs.
1,295 spans contain non-ASCII; 3 records are from CRLF sources. Corpus raw_hex count0.
Directive CLI cases add **2,622** provenance checks: 402 inherit, 742 fact, 1,298 finding, 180 normalization.
Fresh independent invalid-UTF8 raw_hex probe was stopped; existing raw_hex regression passed.

## 19. Fresh local tests

Frozen executable remains `12a02e7fd989f40cb7da7059de74e9560b077c59`.

| Check | Fresh result |
| --- | --- |
| python -m unittest discover -s tools/tests -p "test_migration_tooling.py" -v | 161 PASS, 19.148s |
| python -m unittest discover -s tools/tests -p "test_*.py" -v | 207 PASS, 20.542s |
| Independent directive cases | 430 CLI + 484 lexer PASS |
| Independent pre-discovery contract cases | 441 PASS |
| New alias sibling CLI cases | 110 completed; 40 unsafe outputs |
| repository/static standalone command | Not run before blocker stop |
| final diff/immutability/report-quality checks | Performed during report closeout |

No remote CI or Godot live gameplay run. Pure parser audit does not require gameplay validation.
Test success does not close a counterexample outside the tests.

## 20. Documentation validation / consistency

Complete P1/P2/P2F1–P2F8, six historical audits and STATUS/ROADMAP narrative revalidation was **STOPPED**.
DECISIONS D1–D9 and source macro authority were read for the blocker analysis; no authority was changed.
STATUS/ROADMAP retain the accepted P2F8 implementation checkpoint. This current audit is authorized by the new
owner request and does not alter historical awaiting-review text while blocked.
Report closeout checked **240 local Markdown links, 10 anchors, 0 failures**, including relative targets and
committed/untracked reference boundaries. The 29 sections and whitespace also passed. These mechanical checks
do not imply the stopped narrative/security audit was completed.

## 21. Fresh whole-corpus A/B

Both fresh CLI runs: exit1, scanned2,336, supported499, EXTRACTED0, PARTIAL499, OUT_OF_SCOPE1,824,
QUARANTINED13, facts2,804, findings4,457. Each output **10,030,223 bytes**; full byte equality checked.
Both SHA-256: `15d6e81755956e6af05bf786d40728a4654a6cf4471a3a3cc32a46bfb823ce72`.

Finding counts independently recomputed: CALLBACK_BEHAVIOR326; DRIVER_SEMANTICS_UNKNOWN410;
DYNAMIC_EXPRESSION11; ORDER_SENSITIVE_MUTATION36; OUT_OF_SCOPE1305; REQUIRES_SEMANTIC_REVIEW1713;
RNG_SEMANTICS62; SOURCE_ENCODING_ISSUE8; SOURCE_SYNTAX_ERROR5; UNRESOLVED_INCLUDE97; UNSUPPORTED_CONSTRUCT484.
Equality with historical numbers is an observed result, not an imposed acceptance expectation.

## 22. All thirteen quarantine files

Fresh corpus has facts=[] for all13. The five syntax sources were freshly read in full before blocker discovery:

| Path under mudlib | Classification / positive evidence |
| --- | --- |
| d/latemoon/sroad1.c | SYNTAX: north key missing closing quote, later unterminated-string diagnostic |
| d/npc/oldman.c | SYNTAX: orphan message arguments and unmatched closing parenthesis in kill_ob |
| d/village/lordhouse3.c | SYNTAX: commented-out conditional opening leaves active extra closing brace |
| u/cloud/npc/goddd.c | SYNTAX: unescaped internal quote after 说: splits message text; malformed subsequent structure |
| u/cloud/obj/sword_book.c | SYNTAX: duplicated nested et("long", under set("long", leaves outer call unclosed before brace |
| cmds/std/exercise.c | ENCODING: fresh byte check U+FFFD1 |
| d/choyin/npc/yamen_po.c | ENCODING: fresh byte check U+FFFD3 |
| d/latemoon/upstar/upcenter.c | ENCODING: fresh byte check U+FFFD1 |
| d/temple/npc/obj/magic_book.c | ENCODING: fresh byte check U+FFFD1 |
| d/temple/npc/obj/spells_book.c | ENCODING: fresh byte check U+FFFD1 |
| d/temple/obj/magic_book.c | ENCODING: fresh byte check U+FFFD1 |
| d/temple/obj/spells_book.c | ENCODING: fresh byte check U+FFFD1 |
| u/cloud/obj/npc/flower_girl/guihua.c | ENCODING: fresh byte check NUL338 / U+FFFD110 |

Eight encoding entries have positive raw-byte findings, but complete individual manual source/context review was
not finished before STOP. No source repair. Do not label the entire required all13 manual acceptance complete.
The additional six representative room/source-to-output manual comparisons were also stopped.

## 23. Manifest / finding / summary integrity

Completed independent corpus checker verifies all 2,336 physical inputs against tracked reference paths;
unique object IDs; sorted/unique manifest paths; source sizes/hashes; valid finding IDs and per-object references;
exact status/finding-code totals; all emitted statuses within the allowed set; no facts for OUT_OF_SCOPE/QUARANTINED.
7,261 fact/finding review_state nodes visited are UNREVIEWED.
The planned whole-document review_state traversal (including object/manifest nodes) was not run before STOP;
existing validation/tests enforce them, but no new all-node independent count is claimed.

## 24. Source immutability

Reference tree before/after: `4106480ab28cce8cd7b55704f8ae9ae062d42d03`.
Fresh raw-byte manifest over 2,336 lexically sorted repository-relative paths:
`744e33e1740db7909129a3ae5e295158341b5012a411af953b144a5075bb0a80`.
Extractor-relative manifest: `895d36086e184ba6bf520625c20e882394a0a6169aabf86a1b4c58ba835e2820`.
Different path namespaces explain the two digests. No source edit, normalization, game/Save/CI change or probe residue.

## 25. Six protected historical audits

All six remain untracked/unstaged/byte-identical; this report is the seventh untracked audit.

| Basename | SHA-256 |
| --- | --- |
| MIGRATION_TOOLING_V1_FINAL_AUDIT.md | `a61cd221e8b70961d963484dfe953f5e341511967d9cfd66a55159b1bab85d63` |
| MIGRATION_TOOLING_V1_RE_FINAL_AUDIT.md | `c67dc612139bf37a6c6a41d4753b58723b154d0f6e92cdca0ab5a34ad93d0548` |
| MIGRATION_TOOLING_V1_FINAL_RE_AUDIT_AFTER_P2F4.md | `c4ff8faccea5b79d0ba4007d2d616007f4a55fda3b84e58e78875d68f4e4aed0` |
| MIGRATION_TOOLING_V1_FINAL_RE_AUDIT_AFTER_P2F5.md | `0d93333f8db116db7f6af0cb79e201b26228010cc5e85592adf30cdeb4c94be9` |
| MIGRATION_TOOLING_V1_FINAL_RE_AUDIT_AFTER_P2F6.md | `8a9ba2d9bfd666b949b470d872820c63d5adeab26d849deef7e4460b45593b76` |
| MIGRATION_TOOLING_V1_FINAL_RE_AUDIT_AFTER_P2F7.md | `939c23c9ac71749fc815cbfadcc147407d40024efe353edf0090971cdb5a9d38` |

## 26. Security / artifacts

Tracked diff inventory contains only tooling/test/small-fixture/docs files; no reference/game/CI or generated-corpus delta.
Full fresh manual secret/API-key/token/personal-data/Save/binary/temp/workstation-path/third-party-origin review
was **STOPPED**. No security release clearance is inferred. All new probe files and corpus JSON remain ignored under build.

## 27. Residual risks and incomplete qualifications

| Level | Assessment |
| --- | --- |
| HIGH defect | FR8-01, D2/D3/D6: critical semantic structures hidden by macro aliases; not a residual risk |
| MEDIUM qualification | Bounded lexer/preprocessor/include summary is not full LPC grammar/textual compilation; valid unsupported forms may reduce coverage, but unsafe facts cannot be excused on that basis |
| MEDIUM qualification | Historic corruption and MudOS behavior require source review; all13 full manual acceptance is incomplete |
| MEDIUM qualification | License/provenance/public-release clearance and complete sensitive-artifact review remain pending |
| LOW qualification | Manual first-column difference; conservative synthetic prefix behavior passed, actual inventory pending |
| LOW qualification | Filesystem TOCTOU; overwrite structure checks do not authenticate authorship |
| LOW qualification | Case-sensitive descriptive paths and ~10MB in-memory verbose output; no automatic path repair |
| PENDING boundary | SSERVER actual fresh reassessment, Native consumer absent, no phase PR/remote CI or main integration |

## 28. PR readiness

**NOT READY FOR PR.** The phase remains at `12a02e7fd989f40cb7da7059de74e9560b077c59`.
P2F8's directly specified repair remains historical implemented evidence; this wider audit has found a further
material alias-context gap. No audit commit/push, no PR/merge, no Final Re-Audit PASS and no P3.
Tracked/index remain clean; the milestone is not fully integrated on main.

## 29. Exact next owner gate

Await owner review of FR8-01 and a separate decision on bounded correction. Any future correction must address
the root and dependency contexts demonstrated here and retain direct/unused/ordinary alias controls;
this audit does not authorize or implement general macro evaluation or a new preprocessor.
After an authorized correction, another complete audit must finish the stopped checks and reassess all contracts.

**MIGRATION TOOLING V1 FINAL RE-AUDIT AFTER P2F8 BLOCKED**

**NOT READY FOR PR — AWAIT OWNER REVIEW**
