# Migration Tooling v1 — P2F5 注释前缀指令识别修复

**P2F5 FIX IMPLEMENTED — AWAIT OWNER REVIEW / FINAL RE-AUDIT NOT YET AUTHORIZED**

## 授权与冻结基线

本文件是 P2F5 修复记录，不是 Final Audit 判定。P1、P2、P2F1–P2F4 均为
OWNER APPROVED / CLOSED，D1–D9 保持锁定。P2F4 后的 Final Re-Audit 因 FR-01 HIGH
停止；本次仅获准修复该问题、验证回归、更新本报告及 STATUS/ROADMAP、创建并推送一个提交。
不恢复先前中止的全里程碑审计，不创建 PR、不合并、不进入 P3。

开始时 fetch、分支、远端、merge-base、索引及工作树检查均符合冻结条件：

| 项目 | 值 |
| --- | --- |
| 分支 | `phase/migration-tooling-v1` |
| main / origin/main / merge-base | `cd07808cb76147d0b8c0dad9b82d078b49fefe64` |
| 修复前 HEAD / origin phase | `820d478587fd69d3cf20c861e2694497eac8ef79` |
| 修复前 subject | `Complete remaining standard object migration exclusions` |
| PR | 所有状态查询未发现该分支 PR |
| 初始工作树 | tracked/index 干净；仅三个指定 audit 文件 untracked |

main 后七个提交依次为：

```text
0e5ff6a5cbc8d4091102e280c66868ba8763b4bb
8108763d6a4ddb3ad2b110200666424f4042e296
8efc21ff8aa4c4c293347386f951631c56559fe2
1adb6534d579c5a2c1a4d21e166fb244096daa57
864ebc4c8a749f3e56a39cd5cf0685b07765fd00
c0c7ffb3de3e26cadf395772f7503e71d3690e11
820d478587fd69d3cf20c861e2694497eac8ef79
```

已阅读根及 docs 指令、DECISIONS、P1/P2/P2F1–P2F4 报告、三个本地阻塞审计、
STATUS/ROADMAP、lexer/extractor/CLI 和迁移测试。原 LPC 语料只读；本次不迁移游戏机制。
既有权威类别回归继续读取 `mudlib/include/globals.h`、`weapon.h`、`armor.h`。

## FR-01 根因与修复

原识别条件检查 `#` 前的原始物理行切片是否 `.strip()` 后为空。
lexer 跳过块注释时没有改变该原始切片，因而 `/* audit */ #define ...` 中的 `#`
成为普通标点。下游宏阴影及条件编译防护以 directive token 为输入，无法看到漏掉的指令。
例如以下原审计样本曾 exit0 / supported=true / EXTRACTED，并错误生成 short：

```c
inherit ROOM;
/* audit */ #define set(key,value) ignored(key,value)
void create(){set("short","must not extract");}
```

主修复位于 `tools/migration/es2_source.py`，使用 `line_prefix_is_trivia`：

| 消费内容 | 当前物理行状态 |
| --- | --- |
| 文件开头、普通换行 | true |
| 空白、同一行块注释 | 保持 |
| 含换行的块注释 | true；前一行代码不污染注释末行 |
| 普通 token、字符串、heredoc | false；结束行仍包含非空白词法内容 |
| directive 消费末尾换行 | true；无末尾换行则 false |
| 行注释 | 内容不透明；随后消费换行时重置 |

仅状态为 true 时识别 `#`。因此 `x /* a\ncontinued */ #define ...` 可以识别，
而 `x /* same line */ #define ...` 不可以。多条连续指令、多行字符串和 heredoc 后的
新行均有独立回归。LF 与 CRLF 语义相同；CRLF 不转换，换行仍由原始 `\n` 定位。
下游 admission、include_hazards、条件检测、create/set 抽取和 CLI 均未加特判。

没有去注释后的源缓冲、没有重新索引或源码修复。Token.start/end、text、Source.span、
raw、SHA-256、行列继续基于原字节。正向样本逐项检查 `#` 起点、完整指令终点、raw 字节相等、
源 SHA，以及 direct_inherit/fact/finding/normalization input 的原始 provenance；
Unicode 注释、Unicode 字符串、LF/CRLF 均覆盖。注释前缀不混入 directive token 文本。

## 定向矩阵

以下全部通过，换行相关样本均覆盖 LF/CRLF：

| 正向输入 | 新行为 |
| --- | --- |
| 注释前缀 define ROOM | 拒绝可靠 ROOM admission；OUT_OF_SCOPE；facts=[] |
| define set | PARTIAL；不生成 short/exit |
| define create | PARTIAL；不生成 create 内 short/exit |
| define __DIR__ | 不做路径 normalization、不生成该 exit；保留独立安全 short |
| undef ROOM/set/create/__DIR__ | 进入各自已有保守防护；不计算宏状态 |
| include missing | UNRESOLVED_INCLUDE；candidate=false；OUT_OF_SCOPE；facts=[]；非 QUARANTINED |
| include resolved | 普通头文件保留安全事实；头文件内注释前缀 set 阴影阻止危险事实 |
| if/ifdef/ifndef/elif/else/endif | candidate=false；OUT_OF_SCOPE；facts=[]；DRIVER_SEMANTICS_UNKNOWN |
| define 换行后 ROOM、RO\\ 换行 OM、de\\ 换行 fine | 续行防护生效；原 directive raw/provenance 保留 |
| 无前缀、空白、单/多块注释、多行注释、带旧行代码的注释尾 | 按当前物理行 trivia 识别 |

| 反向输入 | 结果 |
| --- | --- |
| `x /* a */ #...` | 无 directive token |
| `inherit ROOM; /* a */ #...` | 无 directive token |
| 行注释内 # | 不泄漏 directive token |
| 单行/多行块注释内 # | 不泄漏 directive token |
| 字符串内 # | 不泄漏 directive token |
| heredoc / array heredoc 内 # | 不泄漏 directive token |
| 跨行字符串或 heredoc 结束行上的 # | 不误识别；随后新行的合法 # 正常识别 |

新类 `P2F5RegressionTests` 包含 10 个独立测试方法；修复前运行产生 61 个失败子用例，
修复后全部通过。原审计的两个样本还通过独立真实 CLI subprocess 分别运行 LF/CRLF。
条件样本为 `/* audit */ #if FOO`、`set("short","conditional")`、`/* audit */ #endif`。

| 真实 CLI | exit | supported_candidate | status | fact fields | finding codes |
| --- | --- | --- | --- | --- | --- |
| define/set LF | 0 | true | PARTIAL | inherit | REQUIRES_SEMANTIC_REVIEW, UNSUPPORTED_CONSTRUCT |
| define/set CRLF | 0 | true | PARTIAL | inherit | REQUIRES_SEMANTIC_REVIEW, UNSUPPORTED_CONSTRUCT |
| conditional LF | 0 | false | OUT_OF_SCOPE | [] | DRIVER_SEMANTICS_UNKNOWN, OUT_OF_SCOPE |
| conditional CRLF | 0 | false | OUT_OF_SCOPE | [] | DRIVER_SEMANTICS_UNKNOWN, OUT_OF_SCOPE |

四例均不输出 short。CLI exit0 表示这些有效但受限输入没有源损坏，不等于全部事实安全可提取。

## 版本与本地验证

EXTRACTOR_VERSION 从 1.0.4 升为 1.0.5；known versions 精确为 1.0.0–1.0.5。
schema_version 与闭合 schema 未修改。完整 canonical UNREVIEWED 输出的六版本识别、
真实 atomic replacement 与升级为 1.0.5 均通过。拒绝未知版本、嵌套未知/手工字段、
reviewed 数据、metadata-only 假输出、不一致 manifest/summary、错误类型记录时保留原字节。
另有 object / fact provenance / manifest file 三个手工字段探针，均 exit2、未调用 writer、
原字节不变；game/reference/docs 三种保护输出目的地均拒绝且没有落盘。
另将本地保存的 1.0.0–1.0.4 完整历史语料输出及新 1.0.5 输出复制至临时目录，
六份均被 recognized_output 接受并经真实 CLI 成功替换为 1.0.5（exit0）；历史原件未变。

| 本地检查 | 修复前方法数 | 修复后新跑 |
| --- | --- | --- |
| P2F5 focused | — | 10 PASS |
| P2F1 / P2F2 / P2F3 / P2F4 显式回归 | 11 / 7 / 5 / 6 | 29 PASS |
| Migration suite | 94 | 104 PASS |
| 全量 Python | 140 | 150 PASS |
| repository/static | — | PASS |
| git diff --check | — | PASS |

P2F1 覆盖输出保护、续行阴影、精确排除、缺 include、computed mapping；P2F2 覆盖闭合嵌套
schema、手工元数据、MONEY/COMBINED_ITEM；P2F3 覆盖全部 weapon/armor 符号/字面路径、
authority drift、非模糊类别；P2F4 覆盖 BULLETIN_BOARD/CHARACTER/EQUIP/POWDER、
globals 完整性、SSERVER 定义锁定且 admission 语义不变。

可复现命令：

```text
python -m unittest tools.tests.test_migration_tooling.P2F5RegressionTests -v
python -m unittest tools.tests.test_migration_tooling.AuditBlockerRegressionTests tools.tests.test_migration_tooling.P2F2RegressionTests tools.tests.test_migration_tooling.P2F3RegressionTests tools.tests.test_migration_tooling.P2F4RegressionTests -v
python -m unittest discover -s tools/tests -p "test_migration_tooling.py" -v
python -m unittest discover -s tools/tests -p "test_*.py" -v
python tools/ci/repository_checks.py --repository .
git diff --check
python -m tools.migration.cli --source-root reference/es2 --profile static-room-v1 --output build/migration-tooling-v1/p2f5/pre-a.json
python -m tools.migration.cli --source-root reference/es2 --profile static-room-v1 --output build/migration-tooling-v1/p2f5/pre-b.json
```

使用本机 Python 3.12.14。以上为本地证据，不称作 CI；未运行/触发远端 CI。
Godot gameplay canonical suite not required/run for this tooling-only P2F5 slice.

## 实际语料指令清单

对 reference/es2 中全部 1,817 个 `.c`/`.h` 源文件执行只读、保持位置的原字节词法游标扫描，
处理行/块注释、注释内换行、引号、heredoc/array heredoc、指令续行；不是宽松正则搜索。
剩余 519 个非 C/H 文件纳入全语料 manifest，而非 LPC directive 词法统计。
独立扫描包含 10 个 production lexer 无法完整读取的文件：8 个既有编码问题文件、
`d/latemoon/sroad1.c` 与 `u/cloud/npc/goddd.c` 的未闭合字符串；未闭合内容保持不透明，
没有尝试修复。其余 1,807 文件与 production lexer 的原始 directive span 交叉核对一致。

| 项目 | 结果 |
| --- | --- |
| 实际注释前缀 directive occurrence | 0 |
| 路径 | [] |
| directive kinds | [] |
| 涉及 direct ROOM candidates | 0 |
| 因新识别改变的对象 | [] |

FR-01 在本次真实语料中为潜在缺陷，由对抗样本触发；不是为了保留历史计数而调整规则。

## 完整语料与隔离

| 指标 | P2F4 / 1.0.4 | P2F5 / 1.0.5 |
| --- | --- | --- |
| scanned | 2336 | 2336 |
| supported | 499 | 499 |
| EXTRACTED | 0 | 0 |
| PARTIAL | 499 | 499 |
| OUT_OF_SCOPE | 1824 | 1824 |
| QUARANTINED | 13 | 13 |
| facts | 2804 | 2804 |
| findings | 4457 | 4457 |
| CLI exit | 1 | 1 |

逐对象全部字段比较无变化，changed-object inventory=[]。隔离的 path/code/reason 与 P2F4
一致；exit1 保留了既有损坏源的报告行为。finding-code 分布前后相同：

```text
REQUIRES_SEMANTIC_REVIEW 1713
OUT_OF_SCOPE           1305
UNSUPPORTED_CONSTRUCT   484
DRIVER_SEMANTICS_UNKNOWN 410
CALLBACK_BEHAVIOR        326
UNRESOLVED_INCLUDE        97
RNG_SEMANTICS             62
ORDER_SENSITIVE_MUTATION  36
DYNAMIC_EXPRESSION       11
SOURCE_ENCODING_ISSUE      8
SOURCE_SYNTAX_ERROR        5
```

UNRESOLVED_INHERITANCE、DUPLICATE_DECLARATION、UNRESOLVED_REFERENCE 均为 0。
当前 13 个隔离路径如下（相对 `reference/es2/mudlib/`），无新增、移除或原因变化：

| 编码问题（8） | 语法问题（5） |
| --- | --- |
| cmds/std/exercise.c | d/latemoon/sroad1.c |
| d/choyin/npc/yamen_po.c | d/npc/oldman.c |
| d/latemoon/upstar/upcenter.c | d/village/lordhouse3.c |
| d/temple/npc/obj/magic_book.c | u/cloud/npc/goddd.c |
| d/temple/npc/obj/spells_book.c | u/cloud/obj/sword_book.c |
| d/temple/obj/magic_book.c | |
| d/temple/obj/spells_book.c | |
| u/cloud/obj/npc/flower_girl/guihua.c | |

独立 A/B CLI 双跑均为 10,030,223 bytes，逐字节相等，两者 SHA-256 均为：

`618056b67e63a3d3322b9f451b0eadef86f6966fd442c8f832c731dc7043264c`

P2F4 历史 SHA 为 `237f44fb88600cdd425bd6bf7dbf111dd9faa56c7ebc8291013ece2e65f99e36`；
版本值变化导致新摘要，与对象内容无变化不矛盾。

## 完整性、文件范围与后续边界

reference/es2 Git tree 始终为 `4106480ab28cce8cd7b55704f8ae9ae062d42d03`。
磁盘文件与 tracked 路径均为 2,336；逐路径/字节 SHA manifest 校验一致：

- repo-relative manifest: `744e33e1740db7909129a3ae5e295158341b5012a411af953b144a5075bb0a80`
- extractor source manifest: `895d36086e184ba6bf520625c20e882394a0a6169aabf86a1b4c58ba835e2820`

三个本地 audit 文件仅只读校验，未编辑、改名、移动、暂存或提交；开始与提交前摘要一致。
第三份摘要在本任务开始时实测冻结，非沿用未知历史摘要：

| docs/migration 下文件 | SHA-256 |
| --- | --- |
| MIGRATION_TOOLING_V1_FINAL_AUDIT.md | a61cd221e8b70961d963484dfe953f5e341511967d9cfd66a55159b1bab85d63 |
| MIGRATION_TOOLING_V1_RE_FINAL_AUDIT.md | c67dc612139bf37a6c6a41d4753b58723b154d0f6e92cdca0ab5a34ad93d0548 |
| MIGRATION_TOOLING_V1_FINAL_RE_AUDIT_AFTER_P2F4.md | c4ff8faccea5b79d0ba4007d2d616007f4a55fda3b84e58e78875d68f4e4aed0 |

本次变更精确限定六个文件：

- `tools/migration/es2_source.py`：物理行 trivia 状态。
- `tools/migration/room_extractor.py`：仅版本与 known versions。
- `tools/tests/test_migration_tooling.py`：P2F5 对抗测试及六版本期望。
- 本报告。
- `docs/production/STATUS.md`、`docs/production/ROADMAP.md`：最小状态更新。

没有修改 legacy source、game、Save、CI、D1–D9；没有跟踪语料输出或临时探针；没有第三方依赖、
LPC 执行、宏展开、条件求值、通用预处理器、NPC/item 抽取或 Native/Godot generation。
没有发现本切片内另一项 material blocker；此陈述不是完整 Final Re-Audit 的结论。

本报告记录提交前已完成证据。唯一修复提交建立后，必须对该精确提交重新运行上述本地测试、
四个真实 CLI 样本、语料双跑、原字节 directive inventory、隔离比较和完整性检查，再推送同一分支。
精确提交 SHA、重复验证及 push/fetch 后身份在任务交付中报告，避免报告自引用其提交哈希。
最终仍应仅三个 audit 文件 untracked/unstaged。P2F5 等待 owner review；新一轮全里程碑
Final Re-Audit 需单独授权，当前没有 PR、merge 或 P3 授权。
