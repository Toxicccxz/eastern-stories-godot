# Migration Tooling v1 — P2F11 Create-body directive segmentation

**P2F11 FIX IMPLEMENTED — AWAIT OWNER REVIEW / FINAL RE-AUDIT NOT YET AUTHORIZED**

## Authorization / frozen baseline

本次仅执行owner授权的FR10-01（blocking MEDIUM / D9）修复、同类位置边界检查、测试、版本更新、
语料/完整性验证及唯一提交/推送。不执行Final Re-Audit，不创建PR，不合并，不启动P3。
P2F10已CLOSED；其后的Final Re-Audit因FR10-01 BLOCKED。

| 项目 | 冻结值 |
| --- | --- |
| Branch | `phase/migration-tooling-v1` |
| Pre-fix HEAD / origin phase | `8ac248d40cc5e06add22a16a32ef2e37e20f3260` |
| main / origin main / merge base | `cd07808cb76147d0b8c0dad9b82d078b49fefe64` |
| Reference tree | `4106480ab28cce8cd7b55704f8ae9ae062d42d03` |
| 初始状态 | tracked/index clean，恰好九份历史审计untracked |
| PR | all-state查询为空 |
| 唯一提交主题 | `Fix create body directive segmentation` |

已按顺序fetch并核对上述身份；九份历史审计哈希在写代码前验证。
适用根AGENTS与docs/AGENTS的阶段文档规则；报告位于docs/migration。
无reset/rebase/merge/stash/clean/amend/force-push。

## FR10-01 root cause

lexer已经把合法预处理指令保留为directive token。旧create_body仅按嵌套块、配对结构和分号
分段，把create尾部directive留在pending runtime范围，最后误抛unterminated create statement。

```c
inherit ROOM;
void create() {
    set("short", "authored");
#define UNUSED 1
}
```

修复前：exit1 / candidate=true / QUARANTINED / facts=[]。
修复后真实CLI（LF与CRLF）：exit0 / candidate=true / PARTIAL / facts=[inherit, short]，
没有SOURCE_SYNTAX_ERROR。普通directive仍产生语义审查finding，不被当成已执行或批准。

## Directive vs LPC statement boundary

[预处理手册](../../reference/es2/mudlib/doc/concepts/preprocessor)说明预处理在LPC编译前，宏用于
后续文本替换，include按出现位置文本插入。directive不要求LPC语句分号。
本次依据该权威处理语义边界，没有修复legacy source或模拟预处理器。

独立修复复核已检查：只改create_body的可靠性/分段和版本；既有macro/include全局hazard优先，
不会把合法directive整体删除后拼接运行时片段；emit facts前完成全部create可靠性判断。
这属于实现自检，不是新一轮Final Re-Audit裁决。

## Two-phase segmentation architecture

Phase A首先检查整个authored create token序列，包括嵌套深度上的include/未知directive。
随后规划原始source slices：独立directive、完整外层语句、已不支持的嵌套块。
遇到跳过的配对表达式前，检查内部directive，不再因直接跳到matching ')'而漏掉中断。
issues以原始token索引记录、排序输出；没有构造替代source或新token。

Phase B只在计划可靠时调用原statement提取器。若有中断、create内include或未知directive，
先给出blocking UNSUPPORTED_CONSTRUCT并返回，全部create-derived facts不生成；已提取的可靠
direct inherit保留。没有先生成create facts再补删的路径。

## Standalone directive handling

位于完整语句边界的define/undef/pragma/echo单独消费；不传入statement、不要求分号。
start/middle/tail以及连续多条指令均受测。无害unused定义保留普通short/name/long/flags/exits。
原有ROOM/set/create/__DIR__ shadow、宏结构和include admission规则仍先行生效。

## Interrupted statement handling

directive在receiver与'('之间、调用')'与';'之间、或其他进行中的外层语句内部时，
整段create不可靠：candidate=true / PARTIAL / inherit-only，除非既有更强hazard要求OOS。
finding明确说明Preprocessor directive interrupts create statement，provenance指向原始directive。
前后已经写在源里的所有create字段一起抑制，避免只漏掉被打断的那个setter。

## Paired-expression handling

set参数、exit mapping、nested call及配对内容中的directive在Phase A显式检查。
任何中断都会抑制该create中short/name/long/四类flags/全部exits。不会把跨directive的tokens
拼接成一个获支持setter，也不会因合法directive缺分号而制造语法错误。

## Nested-block handling

已有unsupported nested block继续不提取；其中无害独立define/pragma等不会全局杀掉ROOM，
外层可靠静态facts仍可保留。include/未知directive在任意create深度都被Phase A发现并抑制
create facts；既有宏状态/结构hazard仍可提供更强的抑制或OOS结果。

## Include-in-create policy

所有实际位于根create的include都保守抑制create facts，即使是空头文件、仅宏定义、prototype
或data header，也不新增“已证明无害”的细分推断。该覆盖损失属于本次明确允许的保守策略。
现有dependency规则仍负责解析root/nested/relative/missing/malformed以及更强的inherit/macro hazard。
不拼接include源码、不复制header事实或provenance到root。

实际覆盖empty、macro-only、prototype、data、set/add/delete/arbitrary statement、inherit、missing、
malformed、nested include。缺失/坏依赖遵循原OOS规则；坏header自身可真实隔离，但合法root不被假隔离。

## Unknown directive policy

create内无法证明无害的未知非条件directive抑制全部create facts，并保留语义finding。
没有把未知directive直接当成LPC语法错误。所有root #if/ifdef/ifndef/elif/else/endif继续受原有
root conditional OUT_OF_SCOPE门禁控制，没有求值条件或放宽该规则。

## Echo policy

复用既有raw physical-line echo lexer；引号、注释起始、分号、括号、嵌套#、尾部反斜线都只是
echo payload。下一物理行独立处理。函数体末尾echo不再形成伪运行时语句。
comment-prefix、multiline-comment与continued keyword的create start/middle/tail均覆盖LF/CRLF。

## True malformed controls

没有删除最终未终止运行时语句检查。未闭合string/comment、mismatched delimiter、未闭合调用
以及真实缺少分号的runtime tail仍QUARANTINED。
特别加入：缺分号调用后跟define/undef/pragma/echo，仍报真实unterminated create statement，
错误跨度指向runtime调用，而不是把directive误报成损坏源。

如果尾部被include或未知语义指令打断，不能断言它不可能补足语句；该情形保守抑制facts。
例如缺少authored ';'的调用后include包含';'，真实编译前文本可以完整；测试确保不会假隔离。
这不执行include，也不将不可靠片段送入statement提取器。

## Bounded sibling matrix

P2F11RegressionTests共38个手工测试方法，覆盖owner全部30项要求，另增加unfinished-tail与
include-supplied terminator等同类边界。
七类directive × 十种placement × LF/CRLF = 140个组合，通过测试辅助函数逐一断言fields/status/
candidate/findings与root provenance。独立CLI再构造对应输入；另有140例in-process位置复查记录。

| Directive families | Placements | Newlines |
| --- | --- | --- |
| define / undef / pragma / echo / empty include / macro-only include / unknown | create start、between statements、tail、call args、')'与';'之间、receiver与'('之间、exit mapping、nested unsupported block、helper-tail、top-level | LF / CRLF |

无害独立位置保留九类源字段；interrupted/uncertain位置inherit-only；更强hazard按既有规则OOS。

## Real CLI matrix

204个实际subprocess案例，均使用external TemporaryDirectory source/output roots。
覆盖上述140组合、10类include内容、三种directive词法形式×三位置、真正损坏输入、nested call、
未完成调用后的四类指令、include补分号、连续指令、echo下一行与opaque comment对照。
每行记录exit、candidate、status、fact fields、finding codes、quarantine reason和输入hash/bytes。

```json
{
  "total": 204,
  "exits": {
    "0": 186,
    "1": 18
  },
  "statuses": {
    "PARTIAL": 182,
    "OUT_OF_SCOPE": 6,
    "QUARANTINED": 16
  },
  "false_quarantines": 0,
  "unsafe_create_facts": 0
}
```

真实损坏root的16例保持隔离；另2例malformed header使整体exit1，但root按OOS处理。
所有合法directive案例的root false SOURCE_SYNTAX_ERROR为0；interrupted/uncertain create facts泄漏为0。
原FR10历史六类×tail/helper/top-level×LFCRLF共36格包含在新矩阵内；其中12个原错误隔离格已修复。

## P2F1–P2F10 regressions and complete local checks

显式运行AuditBlockerRegressionTests与P2F2–P2F10类：177 tests PASS。
FR-01/FR5-01、raw echo、resolved include、macro alias、P2F10 structural/body effects均保留。
除版本升级断言加入1.0.11外，没有放宽旧测试期望。

| 检查 | 提交前结果 |
| --- | --- |
| P2F11 focused | 38 PASS |
| P2F1–P2F10 explicit classes | 177 PASS |
| unittest discover -s tools/tests -p test_migration_tooling.py -v | 280 PASS |
| unittest discover -s tools/tests -p test_*.py -v | 326 PASS |
| repository_checks.py --repository . | PASS |
| git diff --check | PASS |
| real CLI / directive positions / corpus delta / source integrity | PASS |

报告随唯一fix提交。提交后必须在该exact SHA上完整复跑以上检查及corpus A/B、provenance、
quarantine、ANSI与九审计哈希，再推送。exact SHA和各组exit记录在ignored
`build/migration-tooling-v1/p2f11/post-verification.json`，最终完成消息提供该SHA。
不把提交前结果冒充exact-commit证据。本次无远端CI；pure parser/tooling变更不要求Godot live验证。

## Version 1.0.11 / output compatibility

EXTRACTOR_VERSION=1.0.11，KNOWN_EXTRACTOR_VERSIONS精确包含1.0.0–1.0.11。
schema_version仍1，profile仍static-room-v1；es2_source.py、cli.py和IR schema未变。
12份真实完整historical canonical outputs复制到临时输出目录，由CLI实际成功替换，历史原文件不变。
manual/malformed/empty/unknown/reviewed/future-version六类输出、33个嵌套dict人工字段注入均
exit2 / writer未调用 / 原字节保留。八个保护目录路径组合拒绝，approved build/external输出允许，
其他checkout的tracked输出拒绝，raw_hex独立坏UTF8跨度验证通过。没有schema放宽。

## Corpus A/B

两次独立真实CLI对reference/es2完整扫描，均exit1（真实语料13个既有隔离）。

| Metric | P2F10 | P2F11 A = B |
| --- | --- | --- |
| scanned | 2336 | 2336 |
| supported | 485 | 485 |
| EXTRACTED | 0 | 0 |
| PARTIAL | 485 | 485 |
| OUT_OF_SCOPE | 1838 | 1838 |
| QUARANTINED | 13 | 13 |
| facts | 2736 | 2736 |
| findings | 4296 | 4296 |
| bytes | 9808627 | 9808627 |

A bytes == B bytes；A SHA == B SHA == `d00fbdb3c1ee128aca9b7a96bd73cfb91a48632cbf627203f07a854b66b88509`。

与P2F10逐object、逐finding、逐direct-inherit比较为**零差异**；只有document extractor_version变化。
未强制维持指标，没有未解释的object/fact delta。

Finding-code distribution：

```json
{
  "CALLBACK_BEHAVIOR": 284,
  "DRIVER_SEMANTICS_UNKNOWN": 408,
  "DYNAMIC_EXPRESSION": 10,
  "ORDER_SENSITIVE_MUTATION": 30,
  "OUT_OF_SCOPE": 1319,
  "REQUIRES_SEMANTIC_REVIEW": 1623,
  "RNG_SEMANTICS": 58,
  "SOURCE_ENCODING_ISSUE": 8,
  "SOURCE_SYNTAX_ERROR": 5,
  "UNRESOLVED_INCLUDE": 97,
  "UNRESOLVED_INHERITANCE": 14,
  "UNSUPPORTED_CONSTRUCT": 440
}
```

## Quarantine comparison

13个quarantine的路径、status、finding reason及完整provenance记录与P2F10精确相等。
仍是8 encoding / 5 syntax，均facts=[]；directive uncertainty没有造成新语料隔离。
合法directive与真正损坏的区分另外由CLI/手工回归验证。

| Source path | Code | Exact reason |
| --- | --- | --- |
| `cmds/std/exercise.c` | SOURCE_ENCODING_ISSUE | NUL or replacement character in source |
| `d/choyin/npc/yamen_po.c` | SOURCE_ENCODING_ISSUE | NUL or replacement character in source |
| `d/latemoon/sroad1.c` | SOURCE_SYNTAX_ERROR | unterminated string |
| `d/latemoon/upstar/upcenter.c` | SOURCE_ENCODING_ISSUE | NUL or replacement character in source |
| `d/npc/oldman.c` | SOURCE_SYNTAX_ERROR | mismatched delimiter |
| `d/temple/npc/obj/magic_book.c` | SOURCE_ENCODING_ISSUE | NUL or replacement character in source |
| `d/temple/npc/obj/spells_book.c` | SOURCE_ENCODING_ISSUE | NUL or replacement character in source |
| `d/temple/obj/magic_book.c` | SOURCE_ENCODING_ISSUE | NUL or replacement character in source |
| `d/temple/obj/spells_book.c` | SOURCE_ENCODING_ISSUE | NUL or replacement character in source |
| `d/village/lordhouse3.c` | SOURCE_SYNTAX_ERROR | mismatched delimiter |
| `u/cloud/npc/goddd.c` | SOURCE_SYNTAX_ERROR | unterminated string |
| `u/cloud/obj/npc/flower_girl/guihua.c` | SOURCE_ENCODING_ISSUE | NUL or replacement character in source |
| `u/cloud/obj/sword_book.c` | SOURCE_SYNTAX_ERROR | mismatched delimiter |

## 14 ANSI exclusions

P2F10的14个保守ANSI/compound-macro排除逐一重核，全部保持candidate=false、OUT_OF_SCOPE、
facts=[]且非QUARANTINED。本次未改macro architecture或授权恢复任何一个候选。

| Source path | P2F11 |
| --- | --- |
| `d/canyon/canyon4.c` | false / OUT_OF_SCOPE / [] / 非隔离 |
| `d/choyin/club.c` | false / OUT_OF_SCOPE / [] / 非隔离 |
| `d/chuenyu/trap_castle.c` | false / OUT_OF_SCOPE / [] / 非隔离 |
| `d/city/boots.c` | false / OUT_OF_SCOPE / [] / 非隔离 |
| `d/city/cloth.c` | false / OUT_OF_SCOPE / [] / 非隔离 |
| `d/green/water.c` | false / OUT_OF_SCOPE / [] / 非隔离 |
| `d/latemoon/gate.c` | false / OUT_OF_SCOPE / [] / 非隔离 |
| `d/latemoon/latemoon3.c` | false / OUT_OF_SCOPE / [] / 非隔离 |
| `d/latemoon/latemoon8.c` | false / OUT_OF_SCOPE / [] / 非隔离 |
| `d/latemoon/miroom.c` | false / OUT_OF_SCOPE / [] / 非隔离 |
| `d/latemoon/park/paroad2.c` | false / OUT_OF_SCOPE / [] / 非隔离 |
| `d/latemoon/room/bathroom.c` | false / OUT_OF_SCOPE / [] / 非隔离 |
| `d/latemoon/room/bathroom1.c` | false / OUT_OF_SCOPE / [] / 非隔离 |
| `d/oldpine/keep2.c` | false / OUT_OF_SCOPE / [] / 非隔离 |

## Provenance / reference integrity

全语料fresh验证9587个原始跨度：direct inherits1799、facts2736、findings4296、normalization inputs756；
Unicode跨度1239，CRLF-source跨度3，真实语料raw_hex0（独立坏UTF8探针覆盖raw_hex）。
source SHA、byte bounds、exact raw、line/column、fact IDs、finding references、manifest排序/覆盖和
UNREVIEWED状态通过。新的directive finding只用原root token跨度，无synthetic include/directive事实。

reference tree保持 `4106480ab28cce8cd7b55704f8ae9ae062d42d03`。
2336文件raw path/NUL/hash/LF manifest保持
`744e33e1740db7909129a3ae5e295158341b5012a411af953b144a5075bb0a80`；
extractor-relative manifest保持
`895d36086e184ba6bf520625c20e882394a0a6169aabf86a1b4c58ba835e2820`。
无reference/game/Save/CI/DECISIONS/fixture变更，无第三方依赖。

## Nine audit hashes

以下九份blocked审计始终untracked、unstaged、byte-identical，不纳入提交。

| docs/migration 文件 | SHA-256 |
| --- | --- |
| `MIGRATION_TOOLING_V1_FINAL_AUDIT.md` | `a61cd221e8b70961d963484dfe953f5e341511967d9cfd66a55159b1bab85d63` |
| `MIGRATION_TOOLING_V1_FINAL_RE_AUDIT_AFTER_P2F4.md` | `c4ff8faccea5b79d0ba4007d2d616007f4a55fda3b84e58e78875d68f4e4aed0` |
| `MIGRATION_TOOLING_V1_FINAL_RE_AUDIT_AFTER_P2F5.md` | `0d93333f8db116db7f6af0cb79e201b26228010cc5e85592adf30cdeb4c94be9` |
| `MIGRATION_TOOLING_V1_FINAL_RE_AUDIT_AFTER_P2F6.md` | `8a9ba2d9bfd666b949b470d872820c63d5adeab26d849deef7e4460b45593b76` |
| `MIGRATION_TOOLING_V1_FINAL_RE_AUDIT_AFTER_P2F7.md` | `939c23c9ac71749fc815cbfadcc147407d40024efe353edf0090971cdb5a9d38` |
| `MIGRATION_TOOLING_V1_RE_FINAL_AUDIT.md` | `c67dc612139bf37a6c6a41d4753b58723b154d0f6e92cdca0ab5a34ad93d0548` |
| `MIGRATION_TOOLING_V1_FINAL_RE_AUDIT_AFTER_P2F8.md` | `0734b90e65cb05d0ff4fd9eb701871234472f608b4350f48460b2e63fef12419` |
| `MIGRATION_TOOLING_V1_FINAL_RE_AUDIT_AFTER_P2F9.md` | `ed1721c2de295defb3d7ada595fe73a4db199462a3ef97b61540782d96bc95a4` |
| `MIGRATION_TOOLING_V1_FINAL_RE_AUDIT_AFTER_P2F10.md` | `56e1cd0aa0a573bc4a9505fb5df6bd1cfbd0076849a40f6bd4a4420483cb2213` |

## File scope / owner gate

正好五个tracked变更文件：`tools/migration/room_extractor.py`、
`tools/tests/test_migration_tooling.py`、本报告、[STATUS](../production/STATUS.md)与[ROADMAP](../production/ROADMAP.md)。
所有一次性脚本、矩阵、原始输出与收据留在ignored `build/migration-tooling-v1/p2f11/`。

P2F11实现完成，等待owner review。之后仍需owner明确授权另一轮完整Final Re-Audit；
本报告不是Final Re-Audit裁决，milestone未集成main。无PR、merge、P3或新远端CI。
唯一fix提交经exact-commit验证后push当前phase，保留九份历史审计，然后STOP。
