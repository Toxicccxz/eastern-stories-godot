# Migration Tooling v1 — Final Re-Audit after P2F6

## 1. Executive verdict

**BLOCKED — NOT READY FOR PR**

冻结可执行提交：`a9b19467074b1cc697ba40a40d5954c20b4bc43a`。
发现同一指令词法缺陷族的两个实质问题：

| ID | Severity | Contract | Finding |
| --- | --- | --- | --- |
| FR6-01 | HIGH | D2 / D3 / D6 | `#echo` 原样消息被当作块注释或续行，吞掉下一行关键指令，绕过 admission/set/create/__DIR__/include 保护并输出不可靠 facts |
| FR6-02 | MEDIUM, blocking | D9 | 合法 `#echo` 消息中的引号、块注释标记及 @/@@ 被按 LPC 语法重新解析，伪造源码损坏并 QUARANTINED |

HIGH blockers = **1**；blocking MEDIUM = **1**。这不是可降格接受的 residual risk。
两项归为同一 defect family，不声称已完成全部里程碑复审。
按本次 owner §41 规则，首次确认误隔离后停止无关复审，仅完成同类 sibling sweep、报告与完整性收尾。
没有修复生产代码、测试或 fixture，没有修改 STATUS/ROADMAP/DECISIONS，没有提交、推送、PR 或合并。

## 2. Frozen identities

fetch origin --prune 后核实：

| 项目 | 实测 |
| --- | --- |
| Repository / branch | Toxicccxz/eastern-stories-godot / phase/migration-tooling-v1 |
| main / origin/main / merge-base | cd07808cb76147d0b8c0dad9b82d078b49fefe64 |
| HEAD / origin phase | a9b19467074b1cc697ba40a40d5954c20b4bc43a |
| parent | 8cc5a01741232ed062aff52bee0e77b4d4351b39 |
| subject | Fix multiline comments inside directives |
| milestone commits | 9 |
| initial tracked worktree / index | clean / clean |
| initial untracked | 四个指定历史 BLOCKED audit |
| phase PR | all-state search 无结果 |
| owner gate | P1/P2/P2F1–P2F6 CLOSED；FR-01/FR5-01 CLOSED；D1–D9 LOCKED |

owner 最新指令关闭 P2F6；已提交的 P2F6 报告及 STATUS/ROADMAP 仍记录此前 await-review 时点。
本次 BLOCKED 不改写它们，也不把这种时序差异称作新的实现缺陷。

## 3. Nine-commit history

| SHA | Subject |
| --- | --- |
| 0e5ff6a5cbc8d4091102e280c66868ba8763b4bb | Analyze Migration Tooling v1 extraction contract |
| 8108763d6a4ddb3ad2b110200666424f4042e296 | Record Migration Tooling v1 P2 decisions |
| 8efc21ff8aa4c4c293347386f951631c56559fe2 | Add Migration Tooling v1 static room extractor |
| 1adb6534d579c5a2c1a4d21e166fb244096daa57 | Fix Migration Tooling v1 audit blockers |
| 864ebc4c8a749f3e56a39cd5cf0685b07765fd00 | Fix Migration Tooling v1 re-audit blockers |
| c0c7ffb3de3e26cadf395772f7503e71d3690e11 | Complete weapon and armor migration exclusions |
| 820d478587fd69d3cf20c861e2694497eac8ef79 | Complete remaining standard object migration exclusions |
| 8cc5a01741232ed062aff52bee0e77b4d4351b39 | Fix comment-prefixed directive recognition |
| a9b19467074b1cc697ba40a40d5954c20b4bc43a | Fix multiline comments inside directives |

没有 audit docs commit；冻结 SHA 保持不变。

## 4. Complete diff scope

main...executable HEAD：**19 unique files / +4916 / -11**。

| 类别 | Files | Additions | Deletions |
| --- | ---: | ---: | ---: |
| milestone reports + DECISIONS + STATUS/ROADMAP | 11 | 2474 | 11 |
| tools/migration production | 4 | 1058 | 0 |
| migration unittest | 1 | 1341 | 0 |
| small fixture / expected projection / README | 3 | 43 | 0 |
| reference / game / Save runtime schemas / .github CI | 0 | 0 | 0 |

没有跟踪生成的 whole-corpus JSON。本报告是额外 untracked 文件，不属于上述冻结 diff。
文件清单与统计已核验；完整历史文档语义和全 diff 敏感内容审查因 blocker 尚未完成。

## 5. D1–D9

| Decision | 本次结果与证据边界 |
| --- | --- |
| D1 | 已读生产模块仍使用 Python stdlib/local imports，无 Godot/第三方 parser/LPC runtime；CLI 使用 git 子进程做 tracked-file 保护 |
| D2 | **BLOCKED / FR6-01**：ROOM 宏、undef ROOM 和 missing include 均可被前一条 echo 消息吞掉，candidate 错误为 true |
| D3 | **BLOCKED / FR6-01**：set/create 宏保护被绕过后输出 short/exit；已有事实字段 allowlist 本身未改 |
| D4 | 新 CLI 探针仍为 schema1/static-room-v1/version1.0.6；全语料独立完整性和确定性未完成 |
| D5 | 同类90探针的528条 provenance 独立字节/SHA/行列校验通过；全语料 provenance 尚未运行，不能引用旧9838作为本次结果 |
| D6 | **BLOCKED / FR6-01**：吞掉 __DIR__ shadow 后仍进行 SOURCE_DIR_LITERAL_CONCAT，缺失可靠归一化前提；没有实际执行 LPC |
| D7 | 已有 output-confinement 回归随本次118测试通过；独立攻击矩阵因 stop 未执行，不给完整复审 PASS |
| D8 | 已有 stdlib unittest 与小手写 fixture 本次通过；本次独立审计探针只存 ignored build，没有新增/改动生产测试或 golden |
| D9 | **BLOCKED / FR6-02**：合法原样消息误报 SOURCE_SYNTAX_ERROR、exit1、空facts |

## 6. Historical blocker matrix

以下 CLOSED 仅表示各原始缺陷回归在本次精确 SHA 的新测试运行中通过；不代表同类边界全部正确。
新问题不撤销 owner 对旧修复的批准，也不以旧修复已关闭替代当前 blocker。

| Historical finding | Severity | Fresh original-regression result |
| --- | --- | --- |
| output target confinement bypass | HIGH | CLOSED，AuditBlockerRegressionTests |
| continued critical macro shadow bypass | HIGH | CLOSED，AuditBlockerRegressionTests |
| literal excluded base admission | MEDIUM | CLOSED，AuditBlockerRegressionTests |
| unresolved include admission | MEDIUM | CLOSED，AuditBlockerRegressionTests |
| computed balanced mapping false syntax error | MEDIUM | CLOSED，AuditBlockerRegressionTests |
| nested/manual metadata overwrite | HIGH | CLOSED，P2F2RegressionTests |
| MONEY / COMBINED_ITEM admission | MEDIUM | CLOSED，P2F2RegressionTests |
| weapon/armor completeness | MEDIUM | CLOSED，P2F3RegressionTests |
| globals object completeness | MEDIUM | CLOSED，P2F4RegressionTests |
| FR-01 comment-prefixed directive bypass | HIGH | CLOSED，P2F5RegressionTests + 本次独立4个CLI |
| FR5-01 multiline directive comment false quarantine | MEDIUM | CLOSED，P2F6RegressionTests + 本次独立8个CLI |

## 7. Globals completeness

既有 globals authority/exclusion 回归新跑通过。完整独立重读 authority 的 symbol/literal 矩阵
**PENDING / STOPPED**；没有用旧报告结论冒充本次完整独立 sweep。

## 8. Weapon / armor completeness

既有9武器/11护甲及 authority drift 回归新跑通过；新的独立 F_*/TYPE_* / near-match authority sweep
**PENDING / STOPPED**。没有修改排除策略。

## 9. SSERVER

完整 source/corpus usage 重新审查 **PENDING / STOPPED**。本次没有把 helper 解释提升为新的
确认结论，也没有把 SSERVER 加入排除集。其最终 semantic boundary 仍须后续完整复审。

## 10. Directive lexer class-wide audit / new defect family

### Authoritative evidence

只读查阅 [原始 LPC Preprocessor Manual](../../reference/es2/mudlib/doc/concepts/preprocessor)，
Debugging 部分 L179–188 明确描述 `#echo`，L186–188 原文：

> The rest of the line (or end-of-file, which ever comes first) is the
> message, and is printed verbatim. It's not necessary to enclose text
> with quotes.

因此 `#echo` 的消息不是需要配平的 LPC 字符串/块注释/heredoc；消息中 `/*` 不能使下一物理行
变成当前消息的一部分。这是仓库内权威方言文档，不依赖外部移植或执行 LPC。
本次不实现或执行 echo，不要求解释其输出语义；仅要求保守工具不要伪造损坏或漏掉后续真实指令。

### FR6-01 / HIGH — swallowed next directive

精确真实 CLI 输入（LF；CRLF 亦独立运行）：

```c
#echo /*
#define set(k,v) ignored(k,v) /* closed */
inherit ROOM;
void create(){set("short","unsafe");set("exits",(["east":__DIR__"east"]));}
```

第一行是打印 `/*` 的消息，第二行是独立 set macro。`/* closed */` 是第二行自身闭合的注释。
当前 lexer 却产生一个 directive：

```text
#echo /*\n#define set(k,v) ignored(k,v) /* closed */\n
```

LF token span=[0,52)，CRLF=[0,54)；directive_parts 均只返回 `['echo']`。
define 的完整文本被消费为 echo 的块注释，include_hazards 无法看见 set 宏。

| Newline | Exit | Candidate | Status | Fact fields |
| --- | ---: | --- | --- | --- |
| LF | 0 | true | PARTIAL | inherit, short, exit |
| CRLF | 0 | true | PARTIAL | inherit, short, exit |

short=`unsafe`；exit east 被归一化成 `/d/east`。findings 为 REQUIRES_SEMANTIC_REVIEW、
UNSUPPORTED_CONSTRUCT、UNRESOLVED_REFERENCE，没有 macro-shadow 保护。
把第一行消息换为 `plain` 的对照，set 宏正常识别，只剩 inherit fact。

原始输入 SHA-256：

- LF：`56fe524dc0ffbb1dd2f84980b9a3824a70abf39c52b36e3c575b229bda6b746f`
- CRLF：`d2e869bb181ee0c797d77efd4b326700c4a66bc0994be4179075cf1a11c64c95`

### FR6-02 / MEDIUM — fabricated source corruption

把下面任一消息放在 BODY 前，LF/CRLF 真实 CLI 均 exit1 / candidate=false /
QUARANTINED / facts=[] / SOURCE_SYNTAX_ERROR：

```text
#echo unmatched " message
#echo message /* literal
#echo @MARKER
#echo @@MARKER
```

对应 reason 为 unterminated string / unterminated block comment / unterminated multiline text。
消息本应保留为不解释的文本，不能据其未闭合 LPC 构造指控原文件损坏。

### Root cause and bounded sibling sweep

[es2_source.py](../../tools/migration/es2_source.py) L140–181 对所有 # directive 使用同一套
quote/comment/continuation 状态；L159–163 把 echo 消息中的 `/*` 当块注释并越过物理换行，
L146–151 把消息尾反斜线当续行。
[room_extractor.py](../../tools/migration/room_extractor.py) L60–80 又对所有 directive 的完整内容
用普通 LPC lexer 重新扫描；L77 会把 echo 消息的引号或 @ 标记解释成源码语法。
L353 的 conditional 检查即可触发 SourceError；L361–368 将其转为 SOURCE_SYNTAX_ERROR。
吞指令则在 L314–348 的 hazard 检查中丢失关键指令，之后 L431 起准入判断缺少 hazard。

有限 sweep 共 **90 次实际 CLI subprocess**，所有 source/output 均位于外部 TemporaryDirectory：

| Group | Cases | Fresh result |
| --- | ---: | --- |
| 8种echo消息 × LF/CRLF/EOF | 24 | 10个误隔离，14个对照非隔离 |
| 9种下一行hazard × plain/`/*`/尾反斜线 × LF/CRLF | 54 | 18个plain对照维持保护；36个吞指令样本绕过保护 |
| FR-01 / FR5-01 同类历史控制 | 12 | 全部符合已批准边界 |

消息矩阵：普通文本、单个双引号、`/*`、`@MARKER`、`@@MARKER`、闭合块注释标记、
平衡引号中的标记、`//` 标记。EOF 时 quote/block 各仍误隔离；@/@@ 在 EOF 不误隔离，
而带物理换行时误报 unterminated multiline text，进一步显示通用 LPC re-lex 造成分类差异。

九种 hazard：define ROOM/set/create/__DIR__，undef ROOM/set/create/__DIR__，include missing。
plain 对照中 ROOM/include 阻断准入；set/create 仅 retain inherit；__DIR__ 不生成 exit。
`/*` 与尾反斜线消息两组均输出 inherit/short/exit，9×2×2=36。尾反斜线结果依据同一手册
“rest of the line”规则记录；HIGH 判定仅凭 `/*` 组已充分成立，不依赖该额外续行样本。

已有 P2F5/P2F6 回归覆盖 prefix/whitespace/comment/string/heredoc/continuation/endings 等组合并通过；
独立完整 cross-product 与其他 #pragma/#error/#line/unknown bodies 扩展因本缺陷族确认后停止，
不声称这90例等于用户要求的全部 class-wide final sweep。

完整输入、token spans、parts/error、原始哈希、facts/findings/provenance 存在 ignored：
`build/migration-tooling-v1/final-p2f6/echo_sibling_sweep.py` 与 `echo-sibling-evidence.json`。
证据 JSON SHA-256：`dbc3999f425efeef39ddd79274c498ed2c8a23cc516b5696cbad47410fbadf52`。

## 11. FR-01 fresh real CLI

独立4例（每行 LF/CRLF 各一次）：

| Case | Exit | Candidate | Status | Facts | Codes |
| --- | ---: | --- | --- | --- | --- |
| comment-prefix define/set | 0 | true | PARTIAL | inherit | REQUIRES_SEMANTIC_REVIEW, UNSUPPORTED_CONSTRUCT |
| comment-prefix paired conditional | 0 | false | OUT_OF_SCOPE | [] | DRIVER_SEMANTICS_UNKNOWN, OUT_OF_SCOPE |

没有 unsafe short/exit，原 FR-01 CLOSED。

## 12. FR5-01 fresh real CLI

独立8例（每行 LF/CRLF 各一次）：

| Case | Exit | Candidate | Status | Facts | Codes |
| --- | ---: | --- | --- | --- | --- |
| directive内部跨行块注释 | 0 | true | PARTIAL | inherit, short, exit | A |
| 单行块注释控制 | 0 | true | PARTIAL | inherit, short, exit | A |
| directive后独立跨行注释 | 0 | true | PARTIAL | inherit, short, exit | A |
| 真正未闭合块注释 | 1 | false | QUARANTINED | [] | SOURCE_SYNTAX_ERROR |

A=REQUIRES_SEMANTIC_REVIEW、UNSUPPORTED_CONSTRUCT、UNRESOLVED_REFERENCE。
此处 BODY 增加 __DIR__ exit 用于同类保护对照，故与旧最小复现相比多一个 exit fact 和缺失目标 finding。
原 P2F6 最小复现另外随既有测试新跑通过。FR5-01 CLOSED。

## 13. Output security

既有 output-confinement/tracked-target 回归本次通过；新的独立 absolute/relative × 四保护目标
攻击矩阵 **PENDING / STOPPED**。同类90探针只写外部临时目录，不写 game/reference/docs 探针目标。

## 14. Closed schema

七版本1.0.0–1.0.6识别、真实atomic replace及unknown/manual字段保护随118测试通过。
新的独立全节点攻击和七份历史完整canonical文件替换 **PENDING / STOPPED**。
未知schema/结构的既有拒绝测试通过，不据此给出完整独立输出安全审计结论。

## 15. Fact boundary

原字段/one-create/bare-set/control-flow/callback回归本次通过；独立 #echo sweep 证明 set/create
shadow 保护可绕过，见 FR6-01。其他新事实边界扩展 **PENDING / STOPPED**。

## 16. Exit boundary

原顺序/重复方向/raw值/有限归一化回归通过；本次 __DIR__ shadow 被吞后仍输出 `/d/east`，
归一化前提不可靠。未运行/修复 source、reverse edges、reachability、RNG或mutation。

## 17. Full provenance

全语料独立 provenance 审计 **PENDING / STOPPED**。本次只对90个同类CLI结果独立核验：

| Kind | Records |
| --- | ---: |
| direct inherit | 70 |
| facts | 168 |
| findings | 240 |
| normalization inputs | 50 |
| total | 528 |

528条全部检查原文件SHA、byte范围、raw原字节、authored LF计行/列；directive tokens另逐个核验
start/end/raw。源 span 正确并不能证明分类正确：FR6-02 的错误诊断也可以准确指向普通消息文本。
独立Unicode/raw_hex全覆盖未执行；既有相关回归随套件通过。没有复制历史9838计数。

## 18. Actual comment-prefix inventory

**PENDING / STOPPED**，未重新运行完整C/H source-position inventory。
不复制旧1817/零命中作为本次结果。

## 19. Actual directive-internal multiline-comment inventory

**PENDING / STOPPED**。仅作同类定位的行首 `#echo` C/H 文本搜索无命中；这不是完整词法inventory，
也不能据此声称本次真实语料影响为零。paths/kinds/ROOM影响完整统计未完成。

## 20. Real-source review

本次为新缺陷查阅原始 doc/concepts/preprocessor、doc/lpc/preprocessor/README、define及strings文档。
实际 roommaker/street1/school1/pine3/keep2/lake 和损坏源的逐项独立源-IR对照 **PENDING / STOPPED**。
旧 RealSourceTests 已新跑通过，不等同于上述独立人工审查。

## 21. Fresh tests

两个套件在首次 probe 确认 blocker 前已并行启动，随后正常完成；没有在发现后启动无关完整复审。

| Command | Fresh result on a9b194670... |
| --- | --- |
| python -m unittest discover -s tools/tests -p test_migration_tooling.py -q | 118 PASS，14.267s |
| python -m unittest discover -s tools/tests -p test_*.py -q | 164 PASS，16.000s |
| independent bounded echo/FR CLI sweep | 90次完成，确认上述阻断，不能称为全PASS |
| repository/static dedicated command | PENDING / STOPPED（其unittest包含于164） |
| git diff --check | PASS，收尾确认tracked零差异 |

这些是本地工具验证；没有远端 CI。
Godot gameplay canonical suite not required/run for this tooling-only audit.

## 22. Docs validation

全里程碑 links/anchors/committed-reference 独立统计 **PENDING / STOPPED**。
本报告仅校验自己的3个local Markdown链接（全部目标tracked）、0个anchor，0失败；不把它算作全量文档检查。
根/docs约束与D1–D9已核对；完整P1/P2/P2F1–P2F6/历史审计/STATUS/ROADMAP叙述一致性本次未完成。
此前连续任务的阅读上下文不能替代本次停止后未完成的独立复审结论。

## 23. Corpus A/B

**NOT RUN / STOPPED**。本次没有生成新的完整语料A/B，不复制旧2336/499/2804/4457等提取计数。
2336只在下文作为本次文件完整性检查的磁盘/tracked文件数出现，不是新提取结果。

## 24. Quarantine all thirteen

以下仅列 owner 指定的历史集合；每行当前独立正向损坏审查均 **PENDING / STOPPED**，
不把上次的损坏证据或facts=[]断言当作本次新证据。

| Historical path relative to mudlib | Historical class | This audit |
| --- | --- | --- |
| cmds/std/exercise.c | encoding | PENDING |
| d/choyin/npc/yamen_po.c | encoding | PENDING |
| d/latemoon/upstar/upcenter.c | encoding | PENDING |
| d/temple/npc/obj/magic_book.c | encoding | PENDING |
| d/temple/npc/obj/spells_book.c | encoding | PENDING |
| d/temple/obj/magic_book.c | encoding | PENDING |
| d/temple/obj/spells_book.c | encoding | PENDING |
| u/cloud/obj/npc/flower_girl/guihua.c | encoding | PENDING |
| d/latemoon/sroad1.c | syntax | PENDING |
| d/npc/oldman.c | syntax | PENDING |
| d/village/lordhouse3.c | syntax | PENDING |
| u/cloud/npc/goddd.c | syntax | PENDING |
| u/cloud/obj/sword_book.c | syntax | PENDING |

新合成FR6-02已足以证明D9违反，不必修改或“修复”其中任何历史源码。

## 25. Manifest / finding integrity

完整语料finding IDs/order、object refs、summary/review states/manifest独立校验 **PENDING / STOPPED**。
90个小探针CLI均正常产生完整输出，无exit2；不能外推为全语料完整性PASS。

## 26. Determinism

新的全语料A/B大小/SHA/逐字节比较 **NOT RUN / STOPPED**。
历史1.0.6哈希没有作为本次确定性证据重复引用。

## 27. Source immutability

冻结reference tree与当前均为 `4106480ab28cce8cd7b55704f8ae9ae062d42d03`。
收尾重新读取2336个磁盘source文件，集合与git tracked paths一致；repo-relative raw-byte manifest为：

`744e33e1740db7909129a3ae5e295158341b5012a411af953b144a5075bb0a80`

与冻结证据一致。第一次临时完整性脚本误用Windows Path对象排序与字符串排序比较，断言失败；
改为两边统一POSIX相对路径字符串排序后通过，文件集合/字节没有变化。仅修正一次性审计脚本，
没有更改生产、测试或源文件。没有source repair/normalization/probe artifacts。

## 28. Historical audit immutability

四份文件开始及结束逐字节摘要一致，均untracked/unstaged，从未编辑、移动、暂存或提交：

| docs/migration file | SHA-256 |
| --- | --- |
| MIGRATION_TOOLING_V1_FINAL_AUDIT.md | a61cd221e8b70961d963484dfe953f5e341511967d9cfd66a55159b1bab85d63 |
| MIGRATION_TOOLING_V1_RE_FINAL_AUDIT.md | c67dc612139bf37a6c6a41d4753b58723b154d0f6e92cdca0ab5a34ad93d0548 |
| MIGRATION_TOOLING_V1_FINAL_RE_AUDIT_AFTER_P2F4.md | c4ff8faccea5b79d0ba4007d2d616007f4a55fda3b84e58e78875d68f4e4aed0 |
| MIGRATION_TOOLING_V1_FINAL_RE_AUDIT_AFTER_P2F5.md | 0d93333f8db116db7f6af0cb79e201b26228010cc5e85592adf30cdeb4c94be9 |

## 29. Security / artifacts

完整milestone敏感内容/第三方来源/机器路径审查 **PENDING / STOPPED**，不出最终安全放行结论。
本次没有依赖、LPC执行、Native生成、game/Save/CI/DECISIONS修改，没有跟踪语料输出。
一次性探针及JSON保留在ignored build，合成源码仅在外部TemporaryDirectory，运行后自动清理。
最终tracked worktree/index干净，untracked恰为四份历史audit加本报告，共五份。

## 30. Residual risks

| Level | Assessment |
| --- | --- |
| HIGH blocker | FR6-01，真实macro/include保护绕过，不能降为bounded-parser风险 |
| blocking MEDIUM | FR6-02，合法消息误隔离，不能降为不支持语法的普通遗漏 |
| LOW / other residuals | 未完成最终独立分级，不给PASS WITH RESIDUAL RISKS |

后续完整复审仍需分别评估：bounded lexer并非完整LPC grammar、无preprocessor执行、有效但
不支持LPC的false negatives、历史源码损坏、MudOS/driver semantics、filesystem TOCTOU、
大小写路径差异、约10MB输出规模、结构识别不等于密码学作者证明、SSERVER边界、无Native
consumer、尚无PR远端CI、license/provenance/public-release风险。
其中任何实质D1–D9缺陷必须单列为blocker，不能包装成残余风险。

## 31. PR readiness

**NOT READY FOR PR**。本次没有docs-only audit commit，没有push，没有PR、merge或auto-merge。
分支保留；未开始P3；没有删除历史审计。

## 32. Next owner gate

仅等待owner审阅本缺陷族并决定是否另行授权修复。当前任务未授权修复，故不实施、不补生产测试。
修复后仍需新的完整Final Re-Audit，完成本报告明确标记的所有PENDING项；不能跳过这些项目
直接创建里程碑PR。

**MIGRATION TOOLING V1 FINAL RE-AUDIT AFTER P2F6 BLOCKED**

**NOT READY FOR PR — AWAIT OWNER REVIEW**
