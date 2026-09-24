# Migration Tooling v1 — P2F6 指令内部跨行块注释修复

**P2F6 FIX IMPLEMENTED — AWAIT OWNER REVIEW / FINAL RE-AUDIT NOT YET AUTHORIZED**

## 1. Authorization / frozen baseline

本次仅修复 FR5-01 / MEDIUM，验证回归与语料，更新本报告及 STATUS/ROADMAP，创建并推送一个修复提交。
P1、P2、P2F1–P2F5 均 OWNER APPROVED / CLOSED；FR-01 HIGH 已关闭；D1–D9 LOCKED。
P2F5 后完整复审因 FR5-01 BLOCKED。本次不是完整复审，不给出 Final Re-Audit PASS。

| 项目 | task-start 实测 |
| --- | --- |
| Repository / branch | Toxicccxz/eastern-stories-godot / phase/migration-tooling-v1 |
| main / origin/main / merge-base | cd07808cb76147d0b8c0dad9b82d078b49fefe64 |
| HEAD / origin phase | 8cc5a01741232ed062aff52bee0e77b4d4351b39 |
| subject | Fix comment-prefixed directive recognition |
| parent | 820d478587fd69d3cf20c861e2694497eac8ef79 |
| tracked worktree / index | clean / clean |
| untracked | 仅四个指定 BLOCKED audit |
| PR | all-state 查询未发现该分支 PR |

fetch 后所有冻结条件一致，无 reset/rebase/merge/stash/clean/amend/force-push。
根及 docs 指令、DECISIONS、P1/P2/P2F1–P2F5 报告、四份 blocked audit、STATUS/ROADMAP、
lexer/extractor/CLI及迁移测试构成本次阅读上下文。文档按阶段归档至 docs/migration，未修改 DECISIONS。

第四份审计在任务开始重新计算并冻结：

`P2F5_BLOCKED_AUDIT_START_SHA = 0d93333f8db116db7f6af0cb79e201b26228010cc5e85592adf30cdeb4c94be9`

## 2. FR5-01 reproducer / old behavior

```c
inherit ROOM;
#define LABEL 1 /* first
second */
void create(){set("short","safe");}
```

旧实现在 LF/CRLF 下均 exit1、candidate=false、QUARANTINED、facts=[]，
SOURCE_SYNTAX_ERROR reason 为 `unterminated block comment`。
原始源码含匹配的 `*/`；误报来自工具截断 directive，而非真实源码损坏，违反 D9。

旧 directive 分支仅寻找下一个物理换行，并判断前面是否为反斜线；不知道换行位于块注释内部。
产生的 token 只包含 `#define LABEL 1 /* first\n`。directive_parts 随后重新 lex 这个片段，
把人工截断造成的未闭合注释当作 SourceError。

新 P2F6RegressionTests 在生产修复前运行：14方法、25个失败记录，确认测试能捕获旧行为。
之后修复原边界，不吞异常、不降低 quarantine 等级。

## 3. Directive-boundary scanner

生产修复仅在 [es2_source.py](../../tools/migration/es2_source.py) 的 directive 分支。
状态/处理如下：

| 输入上下文 | 行为 |
| --- | --- |
| 普通 directive 内容 | 继续扫描原始文本 |
| 真正的块注释起点 `/*` | 消费到其匹配 `*/`，内部换行不结束 directive |
| 块注释闭合 | 回到普通内容，继续本行 trailing replacement tokens，不在 `*/` 处结束 |
| 注释外物理换行 | 无既有反斜线续行则结束 token；包含该终止换行 |
| 注释外反斜线续行 | 保持 P2F1/P2F5 LF/CRLF 规则，包括拆分关键字和名称 |
| 双引号字符串 | 识别转义和结束引号，其中 `/*`、`//` 不改变注释状态 |
| 单字符字面量 | 使用与外层 lexer 一致的窄规则，避免误吞 quoted symbol 后的真注释 |
| 行注释 | 内容不透明，其换行结束 directive；内部 `/*`、引号不生效 |
| 真正 EOF 前未闭合块注释 | 原 SourceError 路径，精确指向原始 `/*` 到 EOF，仍隔离 |

在块注释内已确定处于注释状态才寻找闭合符，不是在未区分引号/行注释的文本上盲搜 `*/`。
注释内行末反斜线不是维持 token 的理由：完整注释本身被整体消费。闭合后第二个 `#`
仍是当前 directive 的内容，不生成另一个独立 directive token。create 留在下一独立构造。

directive_parts 无需修改，现在收到完整原始 token，其已有注释处理即可安全工作。
CLI、admission、宏阴影与条件判断、quarantine规则均未修改。

## 4. Focused matrix / provenance

新增14个独立方法，核心样本均覆盖 LF/CRLF：

| 矩阵 | 验证结果 |
| --- | --- |
| 最小FR5-01 | 非隔离、保留安全short |
| define关键字后／名称后／值后跨行注释 | 完整token；parts均为define/LABEL/1 |
| 闭合后 replacement tokens | 保留在同一token，下一create独立 |
| 闭合后第二个# | 外层仅一个directive token |
| 两段跨行块注释 | 两段完整，未吞下一构造 |
| 字符串内注释标记、转义引号/反斜线、字符字面量、quoted symbol | 不误开注释，真注释正常识别 |
| 行注释含块注释标记、引号或尾部反斜线 | 仍在该行换行终止 |
| 注释外续行、split keyword/name | 保留既有续行与关键宏阻断 |
| 注释内行末反斜线，有/无前导空格 | 无误隔离，原始换行保留 |
| undef四个关键名 | 原保守规则生效 |
| include missing | OUT_OF_SCOPE、UNRESOLVED_INCLUDE，非错误隔离 |
| if/ifdef/ifndef/elif/else/endif | 拒绝可靠静态准入、DRIVER_SEMANTICS_UNKNOWN |
| 真未闭合块注释 | QUARANTINED、SOURCE_SYNTAX_ERROR、空facts |
| 独立跨行注释、单行注释、闭合注释恰在EOF | 原边界正确 |
| P2F5前缀与内部跨行注释组合 | 宏保护保留；同行真实代码后的#仍不识别 |

每个正向helper断言 Token.start 为原始#、Token.end 为正确终点、text与原字节切片完全相等，
source SHA精确，下一void位于token之外。direct inherit/fact/finding的raw、SHA、行列亦逐条核对。
使用Unicode前缀及注释测试多字节偏移；所有CRLF原样保留，不归一化，不删除注释后重建源。
独立注释控制明确不进入先前directive。已闭合EOF与真正未闭合EOF分开验证。

## 5. Real CLI matrix

另用独立外部TemporaryDirectory与真实CLI subprocess运行八例，结果如下。
A = REQUIRES_SEMANTIC_REVIEW + UNSUPPORTED_CONSTRUCT；B = SOURCE_SYNTAX_ERROR。

| Case | Newline | Exit | Candidate | Status | Fact fields | Findings |
| --- | --- | ---: | --- | --- | --- | --- |
| directive内部跨行块注释 | LF | 0 | true | PARTIAL | inherit, short | A |
| directive内部跨行块注释 | CRLF | 0 | true | PARTIAL | inherit, short | A |
| 单行块注释控制 | LF | 0 | true | PARTIAL | inherit, short | A |
| 单行块注释控制 | CRLF | 0 | true | PARTIAL | inherit, short | A |
| directive后独立跨行注释 | LF | 0 | true | PARTIAL | inherit, short | A |
| directive后独立跨行注释 | CRLF | 0 | true | PARTIAL | inherit, short | A |
| 真正未闭合注释 | LF | 1 | false | QUARANTINED | [] | B |
| 真正未闭合注释 | CRLF | 1 | false | QUARANTINED | [] | B |

short均为原独立literal `safe`；没有宏执行或任意语义推断。

## 6. Version / previous regressions / local verification

EXTRACTOR_VERSION = **1.0.6**，known versions精确为1.0.0–1.0.6。schema_version仍为1，
闭合schema未放宽。七版本完整canonical输出识别及真实atomic replacement通过；另外复制
历史完整语料1.0.0–1.0.5与新1.0.6到外部临时目录，七份均经真实CLI成功替换为1.0.6，原件不变。

未知版本、nested manual字段、reviewed数据、metadata-only假输出、非法typed shape、
不一致manifest/summary仍拒绝覆盖，exit2、writer未调用、原字节不变。
七版本×21层×两字段的294组合由既有闭合schema回归覆盖；另重新运行object/provenance/
manifest file三个人工字段保全探针及game/reference/docs三种保护输出探针，均通过。

| 本地检查 | 本次实测 |
| --- | --- |
| P2F6 focused | 14 PASS |
| P2F1 / P2F2 / P2F3 / P2F4 / P2F5 | 11 / 7 / 5 / 6 / 10 PASS，共39 |
| Migration suite | 118 PASS（前104） |
| Full Python | 164 PASS（前150） |
| repository/static | PASS |
| git diff --check | PASS |

P2F1输出保护、续行宏、literal exclusion、缺include、computed mapping；P2F2嵌套元数据与
MONEY/COMBINED_ITEM；P2F3武器/护甲；P2F4globals；P2F5前缀正反例，全部保留。

命令使用Python3.12.14与stdlib unittest：

```text
python -m unittest tools.tests.test_migration_tooling.P2F6RegressionTests -v
python -m unittest tools.tests.test_migration_tooling.AuditBlockerRegressionTests tools.tests.test_migration_tooling.P2F2RegressionTests tools.tests.test_migration_tooling.P2F3RegressionTests tools.tests.test_migration_tooling.P2F4RegressionTests tools.tests.test_migration_tooling.P2F5RegressionTests -v
python -m unittest discover -s tools/tests -p "test_migration_tooling.py" -v
python -m unittest discover -s tools/tests -p "test_*.py" -v
python tools/ci/repository_checks.py --repository .
git diff --check
```

这些是本地验证，不称作CI；没有运行远端CI。
Godot gameplay canonical suite not required/run for this tooling-only P2F6 slice.

## 7. Actual corpus multiline-directive-comment inventory

独立只读原字节游标扫描reference/es2全部 **1817 C/H文件**，具体检测“在directive内开始、
跨越换行的块注释”，不是P2F5的comment-prefix inventory。处理ordinary/string/character/
block/line-comment、续行及外层heredoc；不靠宽松多行正则或仅靠production lexer。
保存原始位置，合成正反例先验证扫描器，随后与可完成production lex的原始token位置交叉核对。

| 项目 | 本次结果 |
| --- | --- |
| multiline block-comment occurrence inside directive | 0 |
| paths / directive kinds | [] / [] |
| 涉及 direct ROOM candidate | 0 |
| 改变输出的对象 | 0 |

10个production lexer无法完整读取的既有损坏文件仍被原字节inventory覆盖：8个编码问题文件，
以及sroad1.c和goddd.c的未闭合字符串；未闭合字符串保持不透明，不尝试修复或越过其尾部猜代码。
其余1807文件完成交叉核对。非C/H的519文件仍属于完整source manifest。

## 8. Full corpus / quarantine / determinism

| Metric | P2F5 / 1.0.5 | P2F6 / 1.0.6 |
| --- | ---: | ---: |
| scanned | 2336 | 2336 |
| supported | 499 | 499 |
| EXTRACTED | 0 | 0 |
| PARTIAL | 499 | 499 |
| OUT_OF_SCOPE | 1824 | 1824 |
| QUARANTINED | 13 | 13 |
| facts | 2804 | 2804 |
| findings | 4457 | 4457 |
| CLI exit | 1 | 1 |

全部对象字段逐一比较，changed-object inventory=[]。当前语料未含本次目标形态；修复的是
对抗样本确认的潜在错误分类，没有为保持历史计数而调整实现。
finding分布前后相同：REQUIRES_SEMANTIC_REVIEW1713、OUT_OF_SCOPE1305、UNSUPPORTED_CONSTRUCT484、
DRIVER_SEMANTICS_UNKNOWN410、CALLBACK_BEHAVIOR326、UNRESOLVED_INCLUDE97、RNG_SEMANTICS62、
ORDER_SENSITIVE_MUTATION36、DYNAMIC_EXPRESSION11、SOURCE_ENCODING_ISSUE8、SOURCE_SYNTAX_ERROR5；其余0。

隔离仍为 **13 = 8 encoding + 5 syntax**；path/code/reason均无变化。所有隔离facts为空，
真正损坏的安全处理没有降低。路径相对reference/es2/mudlib：

- encoding：cmds/std/exercise.c、d/choyin/npc/yamen_po.c、d/latemoon/upstar/upcenter.c、
  d/temple/npc/obj/magic_book.c、d/temple/npc/obj/spells_book.c、d/temple/obj/magic_book.c、
  d/temple/obj/spells_book.c、u/cloud/obj/npc/flower_girl/guihua.c。
- syntax：d/latemoon/sroad1.c、d/npc/oldman.c、d/village/lordhouse3.c、u/cloud/npc/goddd.c、
  u/cloud/obj/sword_book.c。

独立A/B CLI全语料输出均 **10,030,223 bytes**，SHA-256均为：

`139896d19a3d88cf89b7e842008d86733a89113feebaaabdf09da06b30142848`

A/B逐字节相等。与1.0.5历史hash不同是版本字段变为1.0.6的预期结果。
命令为 `python -m tools.migration.cli --source-root reference/es2 --profile static-room-v1`
加各自ignored build目的地的绝对 `--output`。原始证据与临时审查脚本保留在ignored
`build/migration-tooling-v1/p2f6/`，不提交。

## 9. Immutability / changed files / owner boundary

reference/es2 tree保持 **4106480ab28cce8cd7b55704f8ae9ae062d42d03**。
磁盘/tracked source路径集合相等，均2336；原字节manifest：

- repo-relative：`744e33e1740db7909129a3ae5e295158341b5012a411af953b144a5075bb0a80`
- extractor source：`895d36086e184ba6bf520625c20e882394a0a6169aabf86a1b4c58ba835e2820`

四份历史BLOCKED报告始终只读、未暂存、未提交，任务开始与提交前摘要一致：

| docs/migration下文件 | SHA-256 |
| --- | --- |
| MIGRATION_TOOLING_V1_FINAL_AUDIT.md | a61cd221e8b70961d963484dfe953f5e341511967d9cfd66a55159b1bab85d63 |
| MIGRATION_TOOLING_V1_RE_FINAL_AUDIT.md | c67dc612139bf37a6c6a41d4753b58723b154d0f6e92cdca0ab5a34ad93d0548 |
| MIGRATION_TOOLING_V1_FINAL_RE_AUDIT_AFTER_P2F4.md | c4ff8faccea5b79d0ba4007d2d616007f4a55fda3b84e58e78875d68f4e4aed0 |
| MIGRATION_TOOLING_V1_FINAL_RE_AUDIT_AFTER_P2F5.md | 0d93333f8db116db7f6af0cb79e201b26228010cc5e85592adf30cdeb4c94be9 |

变更精确限定六文件：es2_source.py的directive边界、room_extractor.py的版本两行、
test_migration_tooling.py的14方法与七版本期望、本报告、STATUS、ROADMAP。
没有source/game/Save/CI/D1–D9变更，没有源归一化、临时源探针、第三方依赖、LPC执行、
宏展开、条件计算或Native生成；生成语料不跟踪。未发现本修复范围内另一项material blocker。

本报告记录提交前真实证据。唯一修复提交建立后，将对精确提交重新运行focused、历史回归、
完整测试、八例CLI、实际inventory、全语料A/B、隔离和完整性，再推送原分支。
最终提交SHA、重复检查与远端核对在任务交付报告，不为写入自身SHA追加提交。
四份旧audit继续untracked/unstaged。P2F6等待owner review；新的完整Final Re-Audit需单独授权。
未补做此前审计未完成章节，不创建PR、不合并、不开始P3。
