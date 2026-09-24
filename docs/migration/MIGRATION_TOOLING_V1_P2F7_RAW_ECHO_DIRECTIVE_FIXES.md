# Migration Tooling v1 — P2F7 raw echo directive fixes

**P2F7 FIX IMPLEMENTED — AWAIT OWNER REVIEW / FINAL RE-AUDIT NOT YET AUTHORIZED**

## 1. Frozen baseline and scope

仅修复 FR6-01 HIGH 与 FR6-02 blocking MEDIUM。P1/P2/P2F1–P2F6 OWNER CLOSED，
FR-01/FR5-01 CLOSED，D1–D9 LOCKED。P2F6 后完整复审 BLOCKED；本次不是完整复审。

| Identity | task-start verified value |
| --- | --- |
| Repository / branch | Toxicccxz/eastern-stories-godot / phase/migration-tooling-v1 |
| main / origin/main / merge-base | cd07808cb76147d0b8c0dad9b82d078b49fefe64 |
| HEAD / origin phase | a9b19467074b1cc697ba40a40d5954c20b4bc43a |
| parent | 8cc5a01741232ed062aff52bee0e77b4d4351b39 |
| subject | Fix multiline comments inside directives |
| worktree / index | tracked clean / clean |
| untracked | 恰好五份指定历史BLOCKED审计 |
| phase PR | all-state查询无结果 |

已fetch核对，没有reset/rebase/merge/stash/clean/amend/force-push。
根/docs约束、D1–D9、P1/P2/P2F1–P2F6及五份历史审计、STATUS/ROADMAP、迁移代码和测试
构成本连续任务阅读上下文；本次重新核对权威preprocessor manual、当前代码和冻结证据。

任务开始重新计算第五份报告：

`P2F6_BLOCKED_AUDIT_START_SHA = 8a9ba2d9bfd666b949b470d872820c63d5adeab26d849deef7e4460b45593b76`

## 2. FR6-01 / FR6-02 and authority

FR6-01 的原始故障形态：

```c
#echo /*
#define set(k,v) ignored(k,v) /* closed */
inherit ROOM;
void create(){set("short","unsafe");set("exits",(["east":__DIR__"east"]));}
```

旧实现把前两行当一个directive，parts只剩echo，漏掉set宏；LF/CRLF均exit0、candidate=true、
PARTIAL并输出inherit/short/exit。同族还绕过ROOM、create、__DIR__、undef、include保护。
FR6-02则把echo消息中的单个引号、`/*`、@MARKER、@@MARKER重新lex为LPC语法，误报
unterminated string/comment/multiline text，exit1、QUARANTINED、空facts。

[ES2 LPC Preprocessor Manual](../../reference/es2/mudlib/doc/concepts/preprocessor) Debugging部分
L179–188明确规定：echo后直到物理行末或EOF的剩余内容是原样消息，不要求用引号包围。
因此消息中的 `/* */ // " ' @ @@ #` 及反斜线都只是文本，不能开启LPC结构、产生嵌套指令或续行。
本次只修复词法边界及可靠性保护，不实现echo输出、不执行LPC或预处理器。

## 3. Narrow architecture / keyword / raw bytes

[es2_source.py](../../tools/migration/es2_source.py) 新增小型directive_keyword helper，只读取指令头，
返回区分大小写的完整ASCII identifier及其原始字符终点。复用已支持的头部空白、块注释trivia、
反斜线LF/CRLF拼接规则；不对payload调用普通lexer。

- 精确echo：lexer从keyword终点找到第一物理LF，包含该LF；若没有则到EOF。CRLF原样保留。
- 非echo：原P2F6 generic directive scanner原样执行，comment/string/line-comment/continuation规则不变。
- directive_parts：同一helper识别echo后立即返回 `['echo']`，不再splice或re-lex消息。
- 原始Source、SHA、token start/end/text均不重建；finding保留完整 authored directive。
- 不产生runtime echo fact；现有UNSUPPORTED_CONSTRUCT供人工审阅。

普通 `#echo`、`# echo`、`#   echo`、tab以及头部既有comment trivia均测试通过。
`#echofoo`、`#echo_value`、`#Echo`、`#echo1`不匹配echo。
`#unknown /*`保持原generic未闭合注释隔离；没有全局吞异常或降级syntax error。

## 4. Split keyword / continuation decision

权威手册的echo原样消息规则与本工具已批准的P2F1/P2F5关键字续行结合使用：
下面的前两行先拼出echo关键字，再把消息作为原样物理行数据，第三行独立识别：

```c
#ec\
ho /*
#define ROOM NPC
```
这是明确的bounded tooling处理，不宣称已执行或完整复刻任意历史driver。

测试包含上述拆分、多次拆分、#之后先续行、LF/CRLF和头部空白。
只有续行之后仍为identifier字符时才连接当前关键字；最大identifier仍须精确等于echo，
故同样拆分但后半段为hofoo时属于generic echofoo，不误识别。
关键字完成后的尾反斜线不延续消息；包括#echo紧接反斜线、无空格且下一行直接为 #define，
仍产生两个独立directive。关键字续行与消息续行明确分开。

空消息的LF/CRLF/EOF、带消息的EOF、/*/引号/@/@@/尾反斜线EOF全部非误隔离。
同一消息内的 #define/#endif不生成第二个directive，也不激活宏或条件hazard。
P2F5的注释前缀、跨行注释尾前缀可识别echo；同行真实代码后的#仍不识别。

## 5. Hand-reviewed authoritative directive family table

完整阅读manual的include/macros/conditional/debugging/compiler/text-formatting章节。
以下为手审证据，不动态生成生产策略：

| Family | v1 body style |
| --- | --- |
| define | 既有bounded tokenized；关键宏保护 |
| undef | 既有bounded tokenized；保守hazard |
| include | 既有bounded tokenized；unresolved依赖阻断 |
| if / ifdef / ifndef / elif / else / endif | 既有bounded tokenized；不计算分支，保守阻断 |
| echo | RAW PHYSICAL-LINE MESSAGE，唯一特殊payload路径 |
| pragma | 既有bounded keyword-style，非raw echo |
| @ / @@ | text formatting shortcuts，不是普通# directive |

上述10种非echo关键字各有LF/CRLF跨行注释控制，确认P2F6完整边界仍有效。
unknown及echo近似关键字保留generic规则；不扩展未知directive语义或其他迁移类别。

## 6. Focused tests and provenance

新增 **18个 P2F7RegressionTests 方法**，在生产修复前实际运行，记录80个失败、70个错误；
修复后18个方法全部通过。分开覆盖：plain/empty/raw矩阵、尾反斜线、下一行关键宏与undef、
include/conditional、同一行#、exact keyword、spacing/trivia、split keyword、两种prefix、
Unicode/provenance、禁止parts调用lex、真实损坏控制、权威family表和两个真实CLI矩阵。

raw矩阵15种消息覆盖LF/CRLF/EOF；每个正向helper检查原#的Token.start、精确物理行末或EOF的
Token.end、Token.text==原字节切片、source SHA、facts/inherits/findings原始raw及行列。
含Unicode前缀、中文消息、CRLF及拆分关键字；支持候选的echo finding保留完整消息。
mock证明directive_parts不会对echo消息调用lex，而非仅证明某些字符未报错。

旧普通未闭合LPC字符串、块注释、非echo指令内未闭合注释仍QUARANTINED、空facts。
P2F5 code-before-hash、comments/string/heredoc hashes，P2F6全部comment/quote/continuation
及真未闭合控制保留通过。

## 7. Independent real CLI matrices

另用独立审计脚本真实subprocess运行 **90例 = FR6-01 72例 + FR6-02 18例**。
所有合成source/output均外部TemporaryDirectory，不把source probe写入reference或game。

FR6-01：6种payload（/*、双引号字符、@MARKER、@@MARKER、尾反斜线、plain）
×6种下一行指令×LF/CRLF。下表每行在所有6种payload与两种换行下结果相同：

| Next directive | Exit | Candidate | Status | Fact fields | Finding codes |
| --- | ---: | --- | --- | --- | --- |
| define ROOM NPC | 0 | false | OUT_OF_SCOPE | [] | OUT_OF_SCOPE, UNRESOLVED_INHERITANCE |
| define set(k,v) ignored(k,v) | 0 | true | PARTIAL | inherit | REQUIRES_SEMANTIC_REVIEW, UNSUPPORTED_CONSTRUCT |
| define create renamed | 0 | true | PARTIAL | inherit | REQUIRES_SEMANTIC_REVIEW, UNSUPPORTED_CONSTRUCT |
| define __DIR__ "/wrong/" | 0 | true | PARTIAL | inherit, short | DYNAMIC_EXPRESSION, REQUIRES_SEMANTIC_REVIEW, UNSUPPORTED_CONSTRUCT |
| include missing.h | 0 | false | OUT_OF_SCOPE | [] | OUT_OF_SCOPE, UNRESOLVED_INCLUDE, UNRESOLVED_INHERITANCE |
| paired if FOO / endif | 0 | false | OUT_OF_SCOPE | [] | DRIVER_SEMANTICS_UNKNOWN, OUT_OF_SCOPE |

undef ROOM/set/create/__DIR__另外在focused测试的6种payload×LF/CRLF矩阵验证，保持对应宏保护。

FR6-02：`"`、`/*`、@MARKER、@@MARKER、尾反斜线、plain各运行LF/CRLF/EOF：

| Ending / source shape | Cases | Exit | Candidate | Status | Fact fields | Finding codes |
| --- | ---: | ---: | --- | --- | --- | --- |
| LF/CRLF，后接独立ROOM/create | 12 | 0 | true | PARTIAL | inherit, short, exit | REQUIRES_SEMANTIC_REVIEW, UNSUPPORTED_CONSTRUCT, UNRESOLVED_REFERENCE |
| EOF，仅echo | 6 | 0 | false | OUT_OF_SCOPE | [] | OUT_OF_SCOPE |

全部无SOURCE_SYNTAX_ERROR。独立探针对438条provenance逐项检查：inherit72、facts84、
findings270、normalization12；原字节/SHA/行列全部通过。438仅指这些探针，不是全语料审计计数。

## 8. Version / output safety / complete local checks

EXTRACTOR_VERSION=**1.0.7**；KNOWN精确为1.0.0–1.0.7；schema_version仍1，closed schema不变。
八版本完整UNREVIEWED输出识别及真实atomic replacement回归通过；另复制历史完整语料
1.0.0–1.0.6及当前1.0.7，八份均经真实CLI成功替换为1.0.7，历史原件字节不变。
未知版本、reviewed、nested manual、metadata-only fake、invalid typed structure、manifest/
summary不一致仍拒绝覆盖，exit2、writer未调用、原字节保全。
闭合schema未知字段回归为8版本×21层×2字段=336组合；另外独立重跑三层manual字段和
game/reference/docs输出保护探针，均保全字节/不调用writer。

| Local check | Fresh result |
| --- | --- |
| P2F7 focused | 18 PASS |
| P2F1 / P2F2 / P2F3 / P2F4 / P2F5 / P2F6 | 11 / 7 / 5 / 6 / 10 / 14 PASS，共53 |
| Migration suite | 136 PASS（此前118） |
| Full Python | 182 PASS（此前164） |
| repository/static | PASS |
| git diff --check | PASS |

命令：python -m unittest tools.tests.test_migration_tooling.P2F7RegressionTests -v；
逐项历史regression class；python -m unittest discover -s tools/tests -p test_migration_tooling.py -v；
同命令pattern=test_*.py；python tools/ci/repository_checks.py --repository .；git diff --check。
使用Python3.12 stdlib；以上为本地测试，不称作远端CI。
Godot gameplay canonical suite not required/run for this tooling-only P2F7 slice.

## 9. Actual source-position inventories

独立raw-byte游标扫描实际 **1817 C/H文件**，保留source位置并区分code/comments/strings/
character/heredoc/array-heredoc及directive状态。先运行手写合成sanity，再与可完整lex的
production directive start/end逐项交叉验证，不用宽松全文正则计数或动态生成生产策略。

| Keyword | Count |
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
| Total | 2060 |

echo occurrence=0；paths/line numbers/raw payload summaries=[]；comment-prefixed echo=0；
涉及supported ROOM candidate=0；输出对象变化=0。未发现需提交owner审查的未知directive family。

10个既有损坏文件无法完成production lex（8 encoding，以及sroad1/goddd未闭合字符串），
仍纳入独立raw inventory；对真实未闭合字符串保持不透明到EOF，不猜测其后内容是代码。
其余1807文件完成token位置交叉验证。当前结果是本次新跑，不复用以前零命中结论。

## 10. Full corpus / quarantine / A-B determinism

| Metric | P2F6 / 1.0.6 | P2F7 / 1.0.7 |
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

逐对象完整字段比较changed objects=[]。隔离仍13=8 encoding+5 syntax，所有隔离path/code/reason
均无变化，不修复reference，不以维持计数为实现目标。
finding distribution：REQUIRES_SEMANTIC_REVIEW1713、OUT_OF_SCOPE1305、UNSUPPORTED_CONSTRUCT484、
DRIVER_SEMANTICS_UNKNOWN410、CALLBACK_BEHAVIOR326、UNRESOLVED_INCLUDE97、RNG_SEMANTICS62、
ORDER_SENSITIVE_MUTATION36、DYNAMIC_EXPRESSION11、SOURCE_ENCODING_ISSUE8、SOURCE_SYNTAX_ERROR5。

独立全语料A/B各 **10,030,223 bytes**，逐字节相等，SHA-256均为：

`1c5e3cbfdcf050a9d7236772aa5c5d409c6951a6fd30093908ea46e4f8b542f6`

与P2F6不同来自extractor_version变化；没有对象delta。
真实CLI命令为python -m tools.migration.cli --source-root reference/es2 --profile static-room-v1，
分别提供ignored build中A/B绝对--output。完整证据在ignored build/migration-tooling-v1/p2f7/。

## 11. Source / five audits / changed files

reference/es2 tree：`4106480ab28cce8cd7b55704f8ae9ae062d42d03`，冻结/验证期间不变。
磁盘/tracked source集合均2336，逐字节repo-relative manifest：
`744e33e1740db7909129a3ae5e295158341b5012a411af953b144a5075bb0a80`；
extractor source manifest：`895d36086e184ba6bf520625c20e882394a0a6169aabf86a1b4c58ba835e2820`。

五份历史报告始终只读、untracked/unstaged，任务开始及验证摘要一致：

| docs/migration file | SHA-256 |
| --- | --- |
| MIGRATION_TOOLING_V1_FINAL_AUDIT.md | a61cd221e8b70961d963484dfe953f5e341511967d9cfd66a55159b1bab85d63 |
| MIGRATION_TOOLING_V1_RE_FINAL_AUDIT.md | c67dc612139bf37a6c6a41d4753b58723b154d0f6e92cdca0ab5a34ad93d0548 |
| MIGRATION_TOOLING_V1_FINAL_RE_AUDIT_AFTER_P2F4.md | c4ff8faccea5b79d0ba4007d2d616007f4a55fda3b84e58e78875d68f4e4aed0 |
| MIGRATION_TOOLING_V1_FINAL_RE_AUDIT_AFTER_P2F5.md | 0d93333f8db116db7f6af0cb79e201b26228010cc5e85592adf30cdeb4c94be9 |
| MIGRATION_TOOLING_V1_FINAL_RE_AUDIT_AFTER_P2F6.md | 8a9ba2d9bfd666b949b470d872820c63d5adeab26d849deef7e4460b45593b76 |

预期变更精确六文件：es2_source.py、room_extractor.py、test_migration_tooling.py、本报告、
STATUS、ROADMAP。cli.py、source/game/Save/CI/DECISIONS不变，没有生成语料跟踪、第三方依赖、
LPC执行、macro/conditional evaluation或Native generation。

## 12. Verification / owner boundary

已独立检查generic-vs-echo分支、exact identifier边界、消息不重lex、原始provenance、下一行
hazard及scope；未发现本修复范围内另一个material defect。无关bounded-LPC/其他语义风险留给
另行授权的完整Final Re-Audit，不自行实施一般preprocessor。

本报告记录提交前实测。唯一修复提交后，会在精确提交上重新运行focused、P2F1–P2F6、完整
测试、90例真实CLI、两个inventory、完整语料A/B、quarantine和完整性核验，全部通过才推送。
精确提交SHA与远端最终核对在交付回复记录，不为记录自身SHA追加提交。

P2F7等待owner review；另一轮完整Final Re-Audit尚未授权。本次不补做此前审计未完成项目，
不宣告Final Re-Audit PASS，不创建PR、不合并、不开始P3。
