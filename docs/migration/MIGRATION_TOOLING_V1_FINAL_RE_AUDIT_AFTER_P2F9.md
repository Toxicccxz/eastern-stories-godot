# Migration Tooling v1 — Final Re-Audit after P2F9

## 1. Executive verdict

**BLOCKED — NOT READY FOR PR.** 2026-09-16.

新确认 **FR9-01 / HIGH：宏替换可以越过原始参数区或函数体边界，引入 set/create/inherit；
当前结构检查跳过这些区域，仍允许不可靠的 ROOM 准入和 create facts。**
违反 **D2 / D3 / D6**，是一个共同的结构边界可靠性缺陷，不是可接受的 residual risk。

| Gate | 本轮结果 |
| --- | --- |
| 已确认 HIGH blockers | 1 — FR9-01 |
| 另行确认的 blocking MEDIUM | 0；不代表未完成范围已通过 |
| 已确认 material D1–D9 defects | 1 个共同根因，影响 D2/D3/D6 |
| 完整审计 | 组合语义检查发现 blocker，按 owner stop rule 中止其余独立审计 |
| Production / tests / fixtures / STATUS / ROADMAP / DECISIONS | 未修改 |
| Commit / push / PR / merge / P3 | 本轮均未执行 |
| 新报告 | 仅本地、untracked、unstaged |

本轮没有修复。发现后只完成最小复现保留、有限同类扫描、相关源码/语义核对和完整性收尾。
未把上轮的 188/234 tests、corpus A/B 或历史 PASS 当作本轮新证据。

## 2. Frozen identities

| 项目 | 值 |
| --- | --- |
| Repository | Toxicccxz/eastern-stories-godot |
| Branch | phase/migration-tooling-v1 |
| Local HEAD / fetched origin phase | `e0334346a3bfadbdd58fe213898361bdd6df6081` |
| Latest subject | Fix macro alias semantic hazards |
| main / origin main / merge base | `cd07808cb76147d0b8c0dad9b82d078b49fefe64` |
| 起始 tracked/index | clean |
| 起始 untracked | 恰好七份历史 BLOCKED 审计 |
| Phase PR | 新鲜 all-state GitHub 查询：无 |

已执行 fetch --prune、branch、全部指定 rev-parse、merge-base、status 和 graph -18。
未执行 reset/rebase/merge/stash/clean/amend/force-push。

## 3. Twelve-commit milestone history

以下为本轮重新读取的完整 main→executable history。

| SHA | Subject |
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
| `12a02e7fd989f40cb7da7059de74e9560b077c59` | Fix resolved include semantic hazards |
| `e0334346a3bfadbdd58fe213898361bdd6df6081` | Fix macro alias semantic hazards |

## 4. Complete milestone diff

本轮重新读取完整 name-status/stat：**22 files，6,610 insertions，11 deletions**。
reference/es2、game（包括 Save/runtime schemas）、.github、tools/ci 相对 main 零改动。
新增工具、一个小型手审 fixture 和里程碑文档；没有 whole-corpus output 出现在 tracked 文件列表中。
本轮没有改变任何已跟踪文件。

```text
M	docs/migration/DECISIONS.md
A	docs/migration/MIGRATION_TOOLING_V1_P1_ANALYSIS.md
A	docs/migration/MIGRATION_TOOLING_V1_P2F1_AUDIT_BLOCKER_FIXES.md
A	docs/migration/MIGRATION_TOOLING_V1_P2F2_RE_AUDIT_BLOCKER_FIXES.md
A	docs/migration/MIGRATION_TOOLING_V1_P2F3_WEAPON_ARMOR_ADMISSION_FIXES.md
A	docs/migration/MIGRATION_TOOLING_V1_P2F4_STANDARD_OBJECT_ADMISSION_FIXES.md
A	docs/migration/MIGRATION_TOOLING_V1_P2F5_COMMENT_PREFIXED_DIRECTIVE_FIXES.md
A	docs/migration/MIGRATION_TOOLING_V1_P2F6_MULTILINE_DIRECTIVE_COMMENT_FIXES.md
A	docs/migration/MIGRATION_TOOLING_V1_P2F7_RAW_ECHO_DIRECTIVE_FIXES.md
A	docs/migration/MIGRATION_TOOLING_V1_P2F8_RESOLVED_INCLUDE_SEMANTIC_HAZARDS.md
A	docs/migration/MIGRATION_TOOLING_V1_P2F9_MACRO_ALIAS_SEMANTIC_HAZARDS.md
A	docs/migration/MIGRATION_TOOLING_V1_P2_STATIC_ROOM_EXTRACTOR.md
M	docs/production/ROADMAP.md
M	docs/production/STATUS.md
A	tools/migration/__init__.py
A	tools/migration/cli.py
A	tools/migration/es2_source.py
A	tools/migration/room_extractor.py
A	tools/tests/fixtures/migration_v1/README.md
A	tools/tests/fixtures/migration_v1/static_room.c
A	tools/tests/fixtures/migration_v1/static_room.expected.json
A	tools/tests/test_migration_tooling.py
```

## 5. Authority reviewed and coverage limit

已读 root/docs AGENTS、DECISIONS 中锁定的 D1–D9、P2F9 的宏摘要/结构位置方案、
after-P2F8 审计的 FR8-01 相关章节、CLI/source lexer，以及当前宏摘要、include、
函数/继承准入与 create 提取路径。原始权威相关章节：

- [LPC preprocessor manual](../../reference/es2/mudlib/doc/concepts/preprocessor)：宏用 token sequence 替换后续标识符；含参数宏与 include 语义。
- [define](../../reference/es2/mudlib/doc/lpc/preprocessor/define) 与 [include](../../reference/es2/mudlib/doc/lpc/preprocessor/include)。
- [function](../../reference/es2/mudlib/doc/lpc/constructs/function) 与 [inherit](../../reference/es2/mudlib/doc/lpc/constructs/inherit)：函数形状与本地同名函数覆盖继承定义。
- [std/room.c](../../reference/es2/mudlib/std/room.c) 的 F_DBASE 继承、[feature/dbase.c](../../reference/es2/mudlib/feature/dbase.c) 的标准 set 实现。

**完整 P1/P2/P2F1–P2F9、七份旧审计、STATUS/ROADMAP、全部测试及全部标准对象的逐文复核尚未完成。**
阻断在前置组合语义检查阶段已被真实 CLI 确认，因此依本轮第24节停止无关审计，不能宣称全部权威阅读或全部门禁已完成。

## 6. FR9-01 minimal reproducer

以下是 inherit 放在最前的单文件代表样本，UTF-8/LF，末尾有换行。
`d/room.c`：

```c
inherit ROOM;
#define P ){} mixed set(string k,mixed v){return 0;} void tail(
void helper(P){}
void create(){set("short","unsafe");set("exits",(["east":__DIR__"east"]));}
```

源文件 SHA-256：`4eca7cc6c52cb23d550c37424ea7256b92238f3e2d98a05b9b0aebe14de3aa26`。
原始发现样本仅将 inherit 放在 helper 后，SHA 为
`3acc22461273774f032f6f6698cb5f5428fe45d5322cba1e7fefd32f9027a322`；两种顺序都复现。

每次测试使用两个互不重叠的外部 TemporaryDirectory source/output 路径，真实命令：

```text
python -m tools.migration.cli --source-root <temporary-source> --output-root <temporary-output>
exit = 0
schema_version = 1
profile = static-room-v1
extractor_version = 1.0.9
supported_candidate = true
status = PARTIAL
facts = inherit, short, exit
short = "unsafe" / EXACT_LITERAL
exit = /d/east / STATIC_NORMALIZED
```

finding codes：CALLBACK_BEHAVIOR、REQUIRES_SEMANTIC_REVIEW、UNRESOLVED_REFERENCE、
UNSUPPORTED_CONSTRUCT。UNRESOLVED_REFERENCE 仅因测试目标 /d/east 不存在。
PARTIAL、UNREVIEWED 或通用 directive warning 不能替代对具体事实资格的保护。

### Hand-authored literal control

按权威 token-sequence 替换规则，P 的替换文本闭合 helper 参数与函数，声明本地 set，再开启 tail。
下列直接源码对照由审计手工书写，没有调用预处理器，也没有执行 LPC：

```c
inherit ROOM;
void helper(){} mixed set(string k,mixed v){return 0;} void tail(){}
void create(){set("short","unsafe");set("exits",(["east":__DIR__"east"]));}
```

对照 SHA：`4096634ef2acc602e7c302b7ee36d171fc93ee192c79e400ebdd5616f14f3aac`。
真实 CLI 对照结果：exit0、candidate=true、PARTIAL、**inherit only**。
直接本地 set 返回 0，并非 F_DBASE::set；通过宏表达该结构时却允许 short/exit，违反同一可靠性边界。
不需要求工具执行宏；需要它在边界可能变化而未能证明安全时保守拒绝相关事实。

## 7. Root cause and violated contract

[room_extractor.py](../../tools/migration/room_extractor.py):177–183 识别到原始函数形状后，
只向 `use()` 传 `ts[start:i]`（181），即开括号之前的前缀；随后直接跳到整个函数体之后（182）。
参数区与函数体里的 P 都不会参与宏使用可靠性检查。
该跳过策略先假定了源文件里的括号/大括号边界不会被宏替换改变。

本轮只读诊断确认 `MacroSummary.reach("P")` 已含 `set`，且 uncertain=true，
但 `macro_structure_hazards(...)` 返回空集。问题不在未收集定义，而在相关使用位置未被分析。
included_structure_hazards 同样依据原始函数形状跳过 body，无法补上该缺口。
659–667 的 create 门禁因此仍将 setter scope 当作可靠，输出 short/exit。

| D-rule | 缺陷效果 |
| --- | --- |
| D2 | 同类替换可引入 inherit NPC，仍 candidate=true 且输出 ROOM facts |
| D3 | 本地 set 或额外 create 被替换文本引入，未抑制 create facts |
| D6 | 在无法证明标准 setter/结构可靠的上下文中仍推断事实，包含 STATIC_NORMALIZED exit |

这不是普通函数体中的 set 调用或无害宏提及。具有跨边界分隔符的替换序列使“这里仍是参数/函数体”
本身不可靠。无害参数宏、无害 body 宏和未使用的危险定义必须继续区别处理；不得用全局禁用宏代替。

## 8. Combined semantic closure sweep

实际执行 **59 次 CLI**：先完成 **29 个机制组合 × LF/CRLF = 58 个通过的代表检查**，
随后第59个参数宏样本发现上述缺陷并停止原计划的无关部分。

已覆盖：header定义/root使用、root定义/header使用、定义与使用都在header、跨headers别名链、
条件header/root定义、raw echo中宏语法及下一物理行独立、comment-prefix、multiline directive comment、
alias与included set/create组合、duplicate create、hidden inherit与included inheritance、六种inherit operand、
DIR alias、undef/redefine、循环、function-like、unused/helper、safe data/prototype、relative/nested/repeated/cyclic include。
期望为人工写定的 fact/candidate/status 边界，不从工具结果生成 golden。

## 9. Bounded same-class sibling sweep

发现后仅进行 **16 families × 6 layouts × LF/CRLF = 192 次真实 CLI**。
六种布局：inline、combined header、header definition/root use、root definition/header use、
nested combined header、split headers。所有调用 exit0。
**108 个跨边界危险案例输出不可靠 facts；84 个安全/直接声明对照符合预期。**

| Family | Cases | Unsafe | Fact fields |
| --- | ---: | ---: | --- |
| parameter set | 12 | 12 | inherit,short,exit |
| parameter create | 12 | 12 | inherit,short,exit |
| parameter inherit | 12 | 12 | inherit,short,exit |
| parameter chain | 12 | 12 | inherit,short,exit |
| parameter function-like | 12 | 12 | inherit,short,exit |
| body set | 12 | 12 | inherit,short,exit |
| body create | 12 | 12 | inherit,short,exit |
| body inherit | 12 | 12 | inherit,short,exit |
| body function-like | 12 | 12 | inherit,short,exit |
| unused delimiter macro | 12 | 0 | inherit,short,exit |
| ordinary parameter macro | 12 | 0 | inherit,short,exit |
| ordinary body macro | 12 | 0 | inherit,short,exit |
| literal set control | 12 | 0 | inherit |
| literal create control | 12 | 0 | inherit |
| literal inherit control | 12 | 0 | none |
| name alias control | 12 | 0 | inherit |

参数组中 object-like/function-like/别名链均受影响；函数体内的跨大括号替换也受影响。
同类 create/inherit 样本表明边界盲点不限于 setter 名称。
直接 setter/create 控制只有 inherit；直接 inherit NPC 控制无 facts；旧式具名 set 别名控制也只有 inherit。
这证明 P2F9 已保护的名称别名路径存在，而结构边界路径尚未闭合。

## 10. Actual corpus — bounded same-class inventory only

只重新计算与已确认缺陷有关的 C/H 宏替换分隔符清单：

| 项目 | Fresh count |
| --- | ---: |
| Lexable C/H | 1807 |
| 无法完整 lex | 10 |
| Lexable 文件中的宏定义 | 686 |
| 单个替换序列分隔符不平衡 | 0 |

10 个损坏输入作为覆盖限制保留，未当作零宏文件。该检查不求条件或编译单元的实际宏展开，
也不是所有可能组合的穷尽证明。**未证明真实语料已受影响；合成输入已证明 material defect。**
此处数字本轮重新读取计算；完整 directive/include/alias inventories 按 blocker rule 未执行。

## 11. D1–D9 gate status

| Gate | 本轮状态 |
| --- | --- |
| D1 Python stdlib/tooling boundary | 已读 CLI/lexer/相关 extractor；完整依赖审核未完成 |
| D2 Reliable direct ROOM | **FAIL — FR9-01** |
| D3 Supported fact boundary | **FAIL — FR9-01** |
| D4 IR independence/version | 合成 CLI 为 schema1/profile static-room-v1/version1.0.9；完整审计未完成 |
| D5 Provenance | 本轮合成根对象1712个span核对通过；全语料 NOT RUN |
| D6 No speculative evaluation | **FAIL — FR9-01**；没有新增执行器，但错误信任宏前结构 |
| D7 Output confinement | 完整攻击矩阵 NOT RUN |
| D8 Hand-authored expectations | 本轮 probe 人工设定预期；完整正式测试审查 NOT RUN |
| D9 Exit boundary | 251次合成CLI均exit0；exit1/exit2完整新验 NOT RUN |

## 12. Fifteen historical blockers

不因历史修复记录就把下列全部标成 fresh CLOSED；本轮提前阻断。

| # | 历史问题 | 本轮覆盖状态 |
| --- | --- | --- |
| 1 | Output target confinement | NOT RUN |
| 2 | Continued critical macro shadow | 完整专门回归 NOT RUN |
| 3 | Literal excluded bases | 仅宏操作数代表案例；完整权威表 NOT RUN |
| 4 | Unresolved includes | 完整缺失依赖复验 NOT RUN |
| 5 | Computed mapping false syntax | NOT RUN |
| 6 | Nested/manual overwrite | NOT RUN |
| 7 | MONEY / COMBINED_ITEM | NOT RUN |
| 8 | Weapon/armor completeness | NOT RUN |
| 9 | Globals object completeness | NOT RUN |
| 10 | Comment-prefix bypass | 组合中的代表案例通过；类级完整复验未完成 |
| 11 | Multiline directive comments | 组合中的代表案例通过；类级完整复验未完成 |
| 12 | Raw echo next-line swallowing | 组合中的代表案例通过；类级完整复验未完成 |
| 13 | Raw echo false quarantine | 组合中的代表案例通过；类级完整复验未完成 |
| 14 | Resolved include hazards | set/create/inherit与安全helper/prototype代表通过；完整审计未完成 |
| 15 | Macro alias hazards | 具名别名/链代表通过；发现共享领域新缺陷 FR9-01，不能作完整闭合声明 |

## 13. Macro alias / include audit

本轮 macro 与 include 交叉结果见第8–10节；无“全部宏/全部include不安全”的假设。
参数/函数体边界缺陷在根文件和全部五类include布局重现，不能用已有的具名宏可达性来替代位置覆盖。
完整 include malformed/missing/conditional-structure 及别名清单因阻断未完成。

## 14. Directive/preprocessor and first-column semantics

组合中的 raw echo、comment-prefix 和 multiline-comment 代表案例通过。
完整 continued keyword、code-before-#、EOF、unknown、pragma 类级重验未完成。
手册 first-column 与工具 trivia-prefix over-recognition 的全面安全性评估未完成，不能在本轮认定为已接受 residual。

## 15. Globals / weapon / armor / SSERVER

完整新权威表、全部std对象实现与继承、SSERVER用法/实现重评均 NOT RUN：在前置语义门禁发现 blocker 后停止。
不能引用旧表数字作为本轮完整权威验证，也没有据此扩大或缩小准入政策。

## 16. Output security / closed schema / version compatibility

game/reference/docs/root absolute+relative攻击、writer-not-called检查、approved destination controls、
1.0.0–1.0.9完整输出替换和unknown/reviewed/manual/malformed拒绝矩阵：本轮 NOT RUN。
上轮实现证据仍保留，但不是此次 Final Re-Audit 新证据。

## 17. Fact and exit boundary

已确认不可靠 short 与 normalized exit，详情见最小复现；未新增任何事实种类。
所有251次probe exit0，符合这些输入未被隔离这一观察；exit0不等于语义正确。
完整 exit1/exit2、fatal/internal failure门禁未重新执行。

## 18. Provenance

对本轮59+192个合成根对象的 inherits/facts/findings 共 **1712** 个 provenance 记录，
重新核对 raw SHA、原始字节切片、byte bounds、line/column，包含 LF/CRLF，均通过。
没有宏展开产生的来源记录；本缺陷是 fact eligibility 错误，不能由来源字节正确抵消。
全语料 inherit/fact/finding/normalization/raw_hex/Unicode 数量与逐项证明：**NOT RUN**。

## 19. Fresh test suites

完整 migration unittest、full Python unittest、repository/static：**NOT RUN under blocker stop rule**。
本轮新执行251次真实CLI和一个有限实际宏清单，不将历史188/234单测数量写成fresh结果。
没有修改正式 tests/fixtures，也没有运行远端 CI。纯工具审计无需 Godot gameplay/live validation。

## 20. Documentation validation

完整里程碑文档 local links/anchors/relative/untracked引用检查：**NOT RUN**。
仅对新报告本身做存在性/相对链接与 diff whitespace 收尾；不声明全体里程碑文档通过。
STATUS/ROADMAP 没有 PASS 更新，DECISIONS 未改。

## 21. Corpus A/B

**NOT RUN**：发现 material defect 后，按明确指令停止 routine corpus checks。
不复用上轮 bytes/SHA/counts 作为本轮数据，不宣称本轮全语料 determinism PASS。

## 22. All 13 quarantine files / real-source spot review

全13文件逐字节损坏核验以及 roommaker/street1/school1/pine3/keep2/lake source-result spot review：
**NOT RUN**。有限宏清单中的10个unlexable文件仅记录扫描覆盖限制，不构成本轮逐项 quarantine复核。

## 23. Manifest / finding / summary integrity

合成输出完整到达、JSON可读取、根对象fact/finding可定位；本轮未完成全语料覆盖/唯一性/ordering/
summary计数/UNREVIEWED的独立审计，不引用上轮结果代替。

## 24. Source immutability and artifact boundary

本轮fresh完整性检查：reference树仍为 `4106480ab28cce8cd7b55704f8ae9ae062d42d03`。
所有2336个reference文件的排序 path/NUL/raw-SHA/LF清单摘要仍为
`744e33e1740db7909129a3ae5e295158341b5012a411af953b144a5075bb0a80`。
tracked/index clean；executable、tests、fixtures、game、Save、CI及生产文档未改。

安全/凭据/外部复制源码/个人绝对路径等全milestone逐行审计未完成；不声称通过该门禁。
本次新增probe、复现源和输出均位于 ignored `build/migration-tooling-v1/final-p2f9/`。
没有把它们加入index，唯一新非ignored文件是本报告。

## 25. Seven historical blocked audits

起始与结束均重新核对以下哈希，保持 untracked、unstaged、byte-identical。
新增本报告后 untracked审计总数应为 **8**。

| Filename under docs/migration | SHA-256 |
| --- | --- |
| `MIGRATION_TOOLING_V1_FINAL_AUDIT.md` | `a61cd221e8b70961d963484dfe953f5e341511967d9cfd66a55159b1bab85d63` |
| `MIGRATION_TOOLING_V1_FINAL_RE_AUDIT_AFTER_P2F4.md` | `c4ff8faccea5b79d0ba4007d2d616007f4a55fda3b84e58e78875d68f4e4aed0` |
| `MIGRATION_TOOLING_V1_FINAL_RE_AUDIT_AFTER_P2F5.md` | `0d93333f8db116db7f6af0cb79e201b26228010cc5e85592adf30cdeb4c94be9` |
| `MIGRATION_TOOLING_V1_FINAL_RE_AUDIT_AFTER_P2F6.md` | `8a9ba2d9bfd666b949b470d872820c63d5adeab26d849deef7e4460b45593b76` |
| `MIGRATION_TOOLING_V1_FINAL_RE_AUDIT_AFTER_P2F7.md` | `939c23c9ac71749fc815cbfadcc147407d40024efe353edf0090971cdb5a9d38` |
| `MIGRATION_TOOLING_V1_RE_FINAL_AUDIT.md` | `c67dc612139bf37a6c6a41d4753b58723b154d0f6e92cdca0ab5a34ad93d0548` |
| `MIGRATION_TOOLING_V1_FINAL_RE_AUDIT_AFTER_P2F8.md` | `0734b90e65cb05d0ff4fd9eb701871234472f608b4350f48460b2e63fef12419` |

## 26. Residual risks — no acceptance granted

FR9-01 已是 HIGH blocker，不降格为 residual。其余项目以下仅为待继续审计的分类清单，
并不代表本轮已评估/接受它们或证明没有其他 blocker。

| 待重评项目 | 暂定等级/状态 |
| --- | --- |
| bounded lexer 非完整LPC grammar；合法unsupported漏提取 | MEDIUM，待复审；false quarantine若确认属于blocker |
| bounded preprocessing / macro summary 非宏展开 | HIGH：已确认FR9-01；剩余边界待复审 |
| include summary 非真实translation unit | HIGH受FR9-01影响；其余边界待复审 |
| first-column差异 | 待定；必须区分保守拒绝与实质契约缺陷 |
| 历史源码损坏 | MEDIUM，13项新复核未完成 |
| MudOS/driver semantics | MEDIUM，不能猜测执行 |
| Filesystem TOCTOU | MEDIUM，输出攻击复验未完成 |
| Case-sensitive paths | LOW，路径语义复验未完成 |
| 约10MB输出体积 | LOW，历史规模，本轮未新测 |
| Overwrite validation不等于authorship | MEDIUM，完整兼容性/安全矩阵未执行 |
| SSERVER | MEDIUM，完整新权威证据未检查 |
| 无Native consumer | LOW，阶段范围限制 |
| 无remote PR CI | 后续集成门禁未开始，不能当作绿灯 |
| License/provenance/public release | MEDIUM，公开发布门禁未在本轮复核 |

## 27. Evidence retained

ignored目录 `build/migration-tooling-v1/final-p2f9/`：

- closure-evidence.json：59次发现前组合检查，含每次源字节/hash、fact/finding与预期。
- first-blocker.json、minimal-reproducer/source/d/room.c、minimal-reproducer/result.json：首次完整复现。
- representative/source/d/room.c：inherit-first最小代表。
- sibling-evidence.json：192次有限同类CLI；16 families、6 layouts、LF/CRLF。
- root-cause.json：summary含set且uncertain，而结构hazards为空的只读诊断。
- boundary-inventory.json：当前C/H宏替换边界有限清单及10项覆盖限制。
- integrity.json、frozen-audits.json：来源完整性和七份历史哈希。

报告中的最小源、手写对照、实际结果和hash可独立复现，不依赖忽略目录的长期保留。
没有执行/引入完整宏展开器，也没有运行LPC。

## 28. PR readiness and next gate

**NOT READY FOR PR**。冻结 executable/remote phase仍为 `e0334346a3bfadbdd58fe213898361bdd6df6081`；
main仍为 `cd07808cb76147d0b8c0dad9b82d078b49fefe64`；本里程碑尚未集成main。
本轮无PR/merge，因此无本阶段PR CI或post-merge main CI；未启动任何远端CI。

停止并交owner review FR9-01。下一步需要owner另行授权修复；本轮不会直接修复或开启下一slice。
若以后修复，应在同一major-phase branch保守处理可能改变分组/声明边界的宏使用，同时保持安全宏对照，
不需也不应顺势构建完整预处理器。修复后仍需重新授权并完成所有尚未完成的Final Re-Audit门禁。

**MIGRATION TOOLING V1 FINAL RE-AUDIT AFTER P2F9 BLOCKED**
**NOT READY FOR PR — AWAIT OWNER REVIEW**
