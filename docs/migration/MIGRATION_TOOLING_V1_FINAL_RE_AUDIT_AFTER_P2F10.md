# Migration Tooling v1 — Final Re-Audit after P2F10

## Executive verdict

**BLOCKED**

确认 **FR10-01 / MEDIUM / blocking / D9**：合法预处理指令位于根 `create()` 函数体末尾时，
被误当成缺少分号的 LPC 语句，产生 `SOURCE_SYNTAX_ERROR`、`QUARANTINED` 和 exit1。
这是错误隔离有效源文件，不是允许的保守 OUT_OF_SCOPE 覆盖损失。

本轮已确认阻断项：HIGH 0、blocking MEDIUM 1、material D1–D9 defect 1。
这些数字只描述已确认发现；首个阻断项触发后停止扩审，不能作为剩余范围无缺陷的证明。
按 owner 的 BLOCKED 路径执行：不修复、不修改测试、不更新 STATUS/ROADMAP、不提交、不推送。
仅保留最小复现、一个有界同类检查和本份未跟踪报告；无 PR、merge、P3 或远端 CI。

## Frozen identities

| 项目 | 核验值 |
| --- | --- |
| Branch | `phase/migration-tooling-v1` |
| Executable HEAD / origin phase | `8ac248d40cc5e06add22a16a32ef2e37e20f3260` |
| Latest subject | `Fix macro structural boundary and body hazards` |
| main / origin main / merge base | `cd07808cb76147d0b8c0dad9b82d078b49fefe64` |
| Reference tree | `4106480ab28cce8cd7b55704f8ae9ae062d42d03` |
| 初始状态 | tracked/index clean，恰好八份历史审计 untracked |
| PR | GitHub all-state 查询为空 |

已实际 fetch --prune 并检查 branch、HEAD、remote phase、main、merge base、status 和最近20条历史。
没有 reset/rebase/merge/stash/clean/amend/force-push。此次没有新提交，最终 HEAD 仍为 executable SHA。

## 13-commit milestone history

```text
0e5ff6a  Analyze Migration Tooling v1 extraction contract
8108763  Record Migration Tooling v1 P2 decisions
8efc21f  Add Migration Tooling v1 static room extractor
1adb653  Fix Migration Tooling v1 audit blockers
864ebc4  Fix Migration Tooling v1 re-audit blockers
c0c7ffb  Complete weapon and armor migration exclusions
820d478  Complete remaining standard object migration exclusions
8cc5a01  Fix comment-prefixed directive recognition
a9b1946  Fix multiline comments inside directives
b10faed  Fix raw echo directive semantics
12a02e7  Fix resolved include semantic hazards
e033434  Fix macro alias semantic hazards
8ac248d  Fix macro structural boundary and body hazards
```

## Complete diff

main→executable 的完整 path/stat 已核对：23文件，7327行新增、11行删除，仅 docs/tools。
包含 DECISIONS 的41行锁定契约、P1/P2/P2F1–P2F10共12份报告、STATUS/ROADMAP、四个生产
Python 模块、一个测试模块及三个小型手工 fixture 文件。
reference/es2、game、Save/runtime schema、.github/CI 没有差异；未跟踪生成的全语料输出。
全量 diff 的深入秘密/工件审查因首个阻断项中止，不宣称全部完成。

## FR10-01 — valid create-tail directive falsely quarantined

最小复现（所有 `#` 都位于第一列）：

```c
inherit ROOM;
void create() {
    set("short", "authored");
#define UNUSED 1
}
```

实际命令使用外部 TemporaryDirectory 的 source/output root：

```text
python -m tools.migration.cli --source-root <temporary source> --output-root <temporary output>
```

| 项目 | 实际结果 | 契约要求 |
| --- | --- | --- |
| exit | 1 | 无真实源损坏的完整扫描应为0 |
| supported_candidate | true | 可保守拒绝，但不得伪造损坏 |
| status | QUARANTINED | 支持范围外也应为正常语义分类 |
| facts | [] | 不可因虚构语法错误隔离合法文件 |
| code / reason | SOURCE_SYNTAX_ERROR / unterminated create statement | 不存在真实未终止LPC语句 |
| error span | line4 col1，bytes[60,77)，`#define UNUSED 1\n` | 实际是一条完整合法指令 |

根代理独立 CLI 输入 SHA-256：
`8a4ef3f895b53ebe003dc70e97fa2d962389c430bb23d8d1e52a1dab907fc9ab`。
原始字节、输出、命令结果分别位于 ignored 本地证据目录：
`build/migration-tooling-v1/final-p2f10/first-blocker/source/d/room.c`、
`first-blocker/result.json`、`first-blocker/evidence.json`。
独立审计代理的另一份同义最小输入和输出位于 `macro/define-create-tail-LF/`，
输入 SHA 为 `06845e921224ad6c80ec98cd3b1d8f48f19068c2542d9684088a526bd483a60d`。
两份复现的空白布局不同，均在同一冻结 SHA 上触发相同错误。

根因位于 [room_extractor.py](../../tools/migration/room_extractor.py) 的 `create_body`（776–793）：
directive token 被当作普通分号语句的一部分，尾部残留 tokens 触发第793行 SourceError；
`extract` 的655–662行将该异常转换为 QUARANTINED 并清空 facts。
lexer 已正确识别 directive，本缺陷不是 lexer 没有识别 `#define`。

[预处理手册](../../reference/es2/mudlib/doc/concepts/preprocessor) 第6–21行说明预处理先于
LPC 编译；第53–65行说明宏替换后续文本，定义放程序开头仅为惯例。第40–43行说明 include
按出现位置插入文本。该最小输入无需宏求值、参数替换或完整解释器即可确认：未使用的常量
定义不是 LPC 运行时语句，不需要分号。本次没有修改或执行 LPC 源码来“修复”该路径。

## D1–D9

| 决策 | 本轮已完成证据 / 结论 |
| --- | --- |
| D1 | 四个生产模块只使用 Python 标准库；未见第三方 parser、Godot 依赖或 LPC runtime |
| D2 | 冻结语料485候选；精确symbol/literal排除及14个ANSI拒绝有新证据；完整独立admission矩阵因阻断未完成 |
| D3 | 保留 authored declaration，而非最终状态；完整tests通过；独立所有fact/exit挑战未完成 |
| D4 | schema1 / static-room-v1 / 1.0.10；Migration IR独立于runtime/save |
| D5 | 新跑完整语料9587个provenance跨度及fact IDs验证通过 |
| D6 | 未见LPC/宏展开/#if/RNG/callback/继承默认值求值；仅批准的__DIR__ normalization |
| D7 | 新跑输出禁区、closed schema、人工字段保留和11历史版本替换通过 |
| D8 | 原有手工unittest/fixture路径保留；完整tests通过，未修改任何测试或golden |
| D9 | **BLOCKED：FR10-01**，有效create尾部directive被错误隔离 |

## 16 historical blocker matrix

新跑完整迁移测试包括 AuditBlockerRegressionTests、P2F2–P2F10 的全部既有类，全部通过。
下表区分“对应回归通过”和“完整独立审计关闭”：首个新阻断项后，不冒充完成全部关闭裁决。

| # | 历史阻断项 | 本轮证据 |
| --- | --- | --- |
| 1 | Output confinement bypass HIGH | 独立8禁区探针 + 原回归通过 |
| 2 | Continued critical macro shadow HIGH | 原回归通过 |
| 3 | Literal excluded-base admission MEDIUM | 权威表复核 + 原回归通过 |
| 4 | Unresolved include admission MEDIUM | 原回归通过 |
| 5 | Computed mapping false syntax error MEDIUM | 原回归通过 |
| 6 | Nested/manual metadata overwrite HIGH | 独立33节点注入 + 原回归通过 |
| 7 | MONEY/COMBINED_ITEM MEDIUM | 权威表复核 + 原回归通过 |
| 8 | Weapon/armor completeness MEDIUM | 权威表复核 + 原回归通过 |
| 9 | Globals standard-object completeness MEDIUM | 权威表复核 + 原回归通过 |
| 10 | FR-01 comment-prefix HIGH | 原回归通过 |
| 11 | FR5-01 multiline directive false quarantine MEDIUM | 原回归通过；此次FR10-01为不同处理阶段的新D9缺口 |
| 12 | FR6-01 echo swallowed next directive HIGH | 原回归通过 |
| 13 | FR6-02 echo false quarantine MEDIUM | 原回归通过；create尾部echo亦命中FR10-01 |
| 14 | FR7-01 resolved includes HIGH | 原回归通过 |
| 15 | FR8-01 macro aliases HIGH | 原回归通过 |
| 16 | FR9-01 macro structural/body HIGH | 54个P2F10测试通过；全面独立组合检查提前中止 |

不将该表标成十六项已完成独立 CLOSED；在修复并获准重新完整复审前，milestone仍BLOCKED。

## P2F10 macro-effect audit

源码中优先级为 STRUCTURAL_BOUNDARY_HAZARD > UNKNOWN > CREATE_STATE_HAZARD > INERT。
分析使用原始token区域及有界可能定义图，不拼接编译单元、不生成展开后的source/provenance。
既有54项P2F10回归覆盖安全常量/别名、state mutation、structural/unknown、签名参数与body。
新的独立宏矩阵在早期发现FR10-01后中止；不能把旧回归通过等同于该独立矩阵完成。

## Combined macro/include/directive closure

发现首个缺陷后只进行了一个 bounded 同类 sweep：
6 directive families × 3 placements × LF/CRLF = **36个真实CLI案例**。

| 指令类型 | create尾 LF/CRLF | helper尾 LF/CRLF | 顶层 LF/CRLF |
| --- | --- | --- | --- |
| #define UNUSED 1 | 2个错误QUARANTINED / exit1 | 2个PARTIAL / exit0 | 2个PARTIAL / exit0 |
| #undef UNUSED | 同上 | 同上 | 同上 |
| #pragma warnings | 同上 | 同上 | 同上 |
| raw #echo | 同上 | 同上 | 同上 |
| include空头文件 | 同上 | 同上 | 同上 |
| include仅宏定义头文件 | 同上 | 同上 | 同上 |

12个create尾案例全部错误隔离，24个位置对照全部正常；证据为
`build/migration-tooling-v1/final-p2f10/macro/directive-create-sweep.json` 和同目录脚本/输入/输出。
未继续跨缺陷类别扩审；完整root/header/nested/sibling及start/middle/end组合矩阵未完成。

## 14 ANSI exclusions

本轮fresh corpus与P2F9完整输出逐对象/逐finding比较，重新得到14个变化、68个facts删除。
与P2F10报告列出的路径一致。下表每项都为 candidate=false、OUT_OF_SCOPE、facts=[]，
不是QUARANTINED；没有其他object/finding集合变化。所有实际use经有界summary重算为UNKNOWN。

共同原因是 ansi.h 中颜色宏为 `ESC + "..."` 复合替换，ESC本身为string；有界classifier
不证明复合表达式的惰性。这个coverage trade-off按owner解释不阻断，也不要求实现宏求值。
准确use位置与replacement tokens保存在新 `audit-inventory.json`。

| ROOM path | 宏使用（行:名称） | 分类/输出 |
| --- | --- | --- |
| `d/canyon/canyon4.c` | 46:HIB; 46:HIW; 46:HIB; 46:NOR; 47:HIW; 47:NOR; 48:HIW; 48:NOR; 49:HIW; 49:NOR; 50:HIC; 50:HIW; 50:NOR; 51:HIW; 51:NOR; 52:HIW; 52:NOR; 53:HIW; 53:NOR; 54:HIW; 54:NOR; 55:HIW; 55:NOR | UNKNOWN → false/OOS/[]，非隔离 |
| `d/choyin/club.c` | 96:NOR; 100:HIC; 100:NOR | UNKNOWN → false/OOS/[]，非隔离 |
| `d/chuenyu/trap_castle.c` | 45:HIW; 46:NOR | UNKNOWN → false/OOS/[]，非隔离 |
| `d/city/boots.c` | 33:HIY; 33:NOR | UNKNOWN → false/OOS/[]，非隔离 |
| `d/city/cloth.c` | 34:RED; 34:NOR | UNKNOWN → false/OOS/[]，非隔离 |
| `d/green/water.c` | 43:HIW; 43:NOR | UNKNOWN → false/OOS/[]，非隔离 |
| `d/latemoon/gate.c` | 19:BRED; 19:HIW; 19:NOR | UNKNOWN → false/OOS/[]，非隔离 |
| `d/latemoon/latemoon3.c` | 30:NOR; 33:HIC; 33:NOR | UNKNOWN → false/OOS/[]，非隔离 |
| `d/latemoon/latemoon8.c` | 50:HIM; 50:NOR; 55:HIM; 56:NOR | UNKNOWN → false/OOS/[]，非隔离 |
| `d/latemoon/miroom.c` | 8:HIY; 8:NOR; 52:HIG; 53:NOR | UNKNOWN → false/OOS/[]，非隔离 |
| `d/latemoon/park/paroad2.c` | 36:HIM; 37:NOR | UNKNOWN → false/OOS/[]，非隔离 |
| `d/latemoon/room/bathroom.c` | 42:HIG; 42:NOR | UNKNOWN → false/OOS/[]，非隔离 |
| `d/latemoon/room/bathroom1.c` | 34:HIG; 34:NOR | UNKNOWN → false/OOS/[]，非隔离 |
| `d/oldpine/keep2.c` | 40:HIY; 40:NOR | UNKNOWN → false/OOS/[]，非隔离 |

相应replacement chains（直接来自本轮读取的definition tokens；不求值）：

- `RED` → `ESC + "[31m"` → ESC string。
- `HIG` → `ESC + "[1;32m"` → ESC string。
- `HIY` → `ESC + "[1;33m"` → ESC string。
- `HIB` → `ESC + "[1;34m"` → ESC string。
- `HIM` → `ESC + "[1;35m"` → ESC string。
- `HIC` → `ESC + "[1;36m"` → ESC string。
- `HIW` → `ESC + "[1;37m"` → ESC string。
- `BRED` → `ESC + "[41m"` → ESC string。
- `NOR` → `ESC + "[2;37;0m"` → ESC string。

## Actual macro inventory

全C/H本轮重新读取：1817文件，1807可lex，10个词法不可用；686定义（639 object-like、47 function-like）。
下表汇总既有499与当前485候选的实际compilation-unit清单。
definition数量按各组resolved文件集合去重；use数量按root compilation unit计，公共头的use可重复。
这是在途任务完成后的结果汇总，不是在首blocker后新扩展的语义探针。

```json
{
  "previous": {
    "candidates": 499,
    "definitions_in_unique_resolved_files": 77,
    "object_like": 77,
    "function_like_definitions": 0,
    "signature_uses": 0,
    "create_uses": 76,
    "other_body_uses": 51,
    "effects": {
      "INERT": 71,
      "CREATE_STATE_HAZARD": 0,
      "STRUCTURAL_BOUNDARY_HAZARD": 0,
      "UNKNOWN": 56
    },
    "alias_chain_uses": 56,
    "cycles": 0,
    "function_like_uses": 0
  },
  "current": {
    "candidates": 485,
    "definitions_in_unique_resolved_files": 77,
    "object_like": 77,
    "function_like_definitions": 0,
    "signature_uses": 0,
    "create_uses": 64,
    "other_body_uses": 0,
    "effects": {
      "INERT": 64,
      "CREATE_STATE_HAZARD": 0,
      "STRUCTURAL_BOUNDARY_HAZARD": 0,
      "UNKNOWN": 0
    },
    "alias_chain_uses": 0,
    "cycles": 0,
    "function_like_uses": 0
  }
}
```

14 changed objects / 68 removed facts；没有强制维持旧覆盖数。

## Include inventory

新inventory已遍历候选resolved includes；历史include回归已新跑通过。
FR10同类sweep覆盖空/仅宏头文件的create尾include，均造成错误隔离。
safe helper/data/prototype、included set/create/inherit、cycles/repeats、missing/malformed以及
全部方向组合的独立完整复审因首blocker中止，不声明通过。

## Directive inventory and first-column difference

原comment-prefix、continued keyword、multiline comments、LF/CRLF/EOF、echo回归均通过。
工具允许更宽的trivia/comment-prefix指令检测是既有保守策略；本次FR10全部采用手册首列形式，
与该差异无关。新的完整first-column安全性裁决和独立directive矩阵未完成。

## Globals / weapon / armor

独立读取权威headers并核对34个精确literal排除项：globals14、weapon9、armor11。
既有对应symbol/literal回归通过；未添加模糊匹配或修改对象分类。

## SSERVER

权威std/sserver.c仅继承F_CLEAN_UP并提供offensive_target；证据仍不足以新增对象家族排除。
保留bounded residual，不发明分类。

## Output security

本轮独立fresh执行：4个保护目录game/reference/docs/repository root × absolute/parent-relative
=8例全部exit2，writer未调用，目标未出现且父目录条目不变。
批准的build输出和外部输出均成功；外部git checkout tracked文件拒绝覆盖且原字节不变。
证据：`build/migration-tooling-v1/final-p2f10/security/fresh-security-evidence.json`。

## Schema/version compatibility

实际复制并由CLI替换11份历史完整canonical输出1.0.0–1.0.10，全部成功且原历史文件不变。
manual/malformed/empty/unknown/reviewed/future-version六类输出与33个dictionary节点的人工字段
注入，全部exit2 / writer=false / bytes unchanged。schema仍闭合；格式识别不证明作者身份。
独立invalid UTF-8 raw_hex探针与原字节跨度吻合。

## Fact/exit boundary

当前profile保留源码声明及ordered exits，不声称最终dbase状态或权威出口图。
不能仅因静态set和直接add/delete共存就认定新的D3缺陷。
完整既有测试通过；新增独立fact/control-flow/foreign-receiver等矩阵因FR10中止。

## Full provenance

本轮实际重新核验全语料原始字节：

| 类别 | 数量 |
| --- | --- |
| Direct inherits | 1799 |
| Facts | 2736 |
| Findings | 4296 |
| Normalization inputs | 756 |
| raw_hex（真实语料） | 0 |
| Total spans | 9587 |
| Unicode spans | 1239 |
| CRLF-source spans | 3 |

source SHA、byte bounds、raw/raw_hex、line、column及fact ID通过；direct_inherits与P2F9逐条一致。
未生成macro/include的synthetic provenance。额外坏UTF8探针验证raw_hex路径。

## Fresh tests

在冻结executable SHA上新跑：

| 命令/检查 | 实际结果 |
| --- | --- |
| unittest discover tools/tests test_migration_tooling.py -v | 242 PASS |
| unittest discover tools/tests test_*.py -v | 288 PASS |
| repository_checks.py --repository . | PASS |
| git diff --check | PASS |

全部由首blocker前启动的在途检查完成；结果不代表FR10不存在。
本轮没有改生产或tests，没有远端CI；纯parser/tooling审计未运行Godot live gameplay。

## Docs validation

新报告创建前，对当前21份文件实际检查254个Markdown链接、10个anchors，0失败。
既有committed报告引用检查通过；八份历史blocked报告仅保留原始证据，不改其内容或跟踪状态。
本份新报告另做本地链接存在性检查：2个链接、0个anchors、0失败；未更新STATUS/ROADMAP为PASS。
P1/P2/P2F1–P2F10及历史审计的完整文字复读因首blocker中止，不伪装完成所有authority阅读。

## Corpus A/B

两次独立真实CLI新跑结果一致：

```json
{
  "exit": 1,
  "scanned_files": 2336,
  "supported_candidates": 485,
  "statuses": {
    "EXTRACTED": 0,
    "PARTIAL": 485,
    "OUT_OF_SCOPE": 1838,
    "QUARANTINED": 13
  },
  "total_findings": 4296,
  "finding_codes": {
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
  },
  "facts": 2736,
  "bytes": 9808627,
  "sha256": "f97468b5d7da5200c85e2331e2f576a7a728d3c209df7f203a5cfda6ebc6aaa1"
}
```

A bytes == B bytes，A SHA == B SHA；也与提交前后P2F10基线一致。
真实语料不含该最小触发输入，所以语料摘要稳定不代表D9通用failure分类正确。

## All13 quarantine review

本轮程序化逐跨度/原字节检查及与P2F9的完整quarantine记录比较已通过；没有新语料隔离。
13个文件的全部人工逐文件正向损坏复核未完成，因发现FR10后停止扩审。
因此下表是fresh输出/原字节一致性记录，不冒称完成独立人工“均真实损坏”裁决。

| 源文件 | code | reason | line / byte span |
| --- | --- | --- | --- |
| `cmds/std/exercise.c` | SOURCE_ENCODING_ISSUE | NUL or replacement character in source | 57 / [2033,2036) |
| `d/choyin/npc/yamen_po.c` | SOURCE_ENCODING_ISSUE | NUL or replacement character in source | 123 / [4382,4385) |
| `d/latemoon/sroad1.c` | SOURCE_SYNTAX_ERROR | unterminated string | 15 / [402,457) |
| `d/latemoon/upstar/upcenter.c` | SOURCE_ENCODING_ISSUE | NUL or replacement character in source | 11 / [337,340) |
| `d/npc/oldman.c` | SOURCE_SYNTAX_ERROR | mismatched delimiter | 145 / [4819,4820) |
| `d/temple/npc/obj/magic_book.c` | SOURCE_ENCODING_ISSUE | NUL or replacement character in source | 24 / [863,866) |
| `d/temple/npc/obj/spells_book.c` | SOURCE_ENCODING_ISSUE | NUL or replacement character in source | 24 / [840,843) |
| `d/temple/obj/magic_book.c` | SOURCE_ENCODING_ISSUE | NUL or replacement character in source | 24 / [863,866) |
| `d/temple/obj/spells_book.c` | SOURCE_ENCODING_ISSUE | NUL or replacement character in source | 24 / [840,843) |
| `d/village/lordhouse3.c` | SOURCE_SYNTAX_ERROR | mismatched delimiter | 81 / [1737,1738) |
| `u/cloud/npc/goddd.c` | SOURCE_SYNTAX_ERROR | unterminated string | 161 / [4255,4280) |
| `u/cloud/obj/npc/flower_girl/guihua.c` | SOURCE_ENCODING_ISSUE | NUL or replacement character in source | 1 / [4,5) |
| `u/cloud/obj/sword_book.c` | SOURCE_SYNTAX_ERROR | mismatched delimiter | 27 / [907,908) |

## Real-source review

全语料自动source/output覆盖和14个ANSI差异重算已完成；roommaker、street1、school1、pine3、
keep2、lake及13隔离文件的全套独立人工复核在首blocker处停止，不能标为全部PASS。
已读权威room、dbase、treemap及sserver；其余标准对象源/全部历史文档仅部分复核。

## Manifest/summary integrity

2336输入全表示；object IDs/input_paths唯一，顺序确定；finding IDs/references、summary和
code totals精确，UNREVIEWED保持，未见silent truncation。无autoapproval。
extractor-relative manifest：`895d36086e184ba6bf520625c20e882394a0a6169aabf86a1b4c58ba835e2820`。

## Source immutability

reference Git tree保持 `4106480ab28cce8cd7b55704f8ae9ae062d42d03`。
2336文件 path/NUL/hash/LF 原字节manifest保持
`744e33e1740db7909129a3ae5e295158341b5012a411af953b144a5075bb0a80`。
reference/game/Save/CI未修改；生产和测试字节保持冻结commit。

## Historical audit immutability

下面八份历史报告起止SHA一致、未跟踪且未暂存。本份报告为第九份本地未跟踪审计。

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

## Security/artifacts

已确认milestone path范围仅docs/tools，生成的全语料与本轮探针位于ignored build目录。
本轮没有新增tracked artifacts、credentials、Save或binary。完整milestone secrets/personal-data/
copied-code审查尚未完成，不以“没有新增”替代该尚未完成的审计。

## Residual risks

以下是待完成审计需复核的残余项，不能抵消FR10-01：

| 级别 | 风险/边界 |
| --- | --- |
| MEDIUM blocking | FR10-01：bounded create语句处理将合法directive误报源损坏 |
| MEDIUM residual | bounded lexer不是完整LPC grammar；有效但不支持的LPC可拒绝，但不得假隔离 |
| MEDIUM residual | bounded macro classifier不是预处理器；include summary不等于compiler translation unit；需防unsafe positive |
| LOW coverage | UNKNOWN false negatives及14个ANSI覆盖损失是owner允许的保守结果 |
| LOW residual | first-column差异、MudOS driver语义、case-sensitive路径保留审查，不要求driver仿真 |
| MEDIUM operational | 文件系统TOCTOU；schema验证不是作者身份；~9.8MB输出只用于人工审查 |
| LOW source | 历史损坏源不得自动修复；SSERVER分类仍证据有限 |
| MEDIUM release gate | 没有Native consumer、没有本阶段PR CI；公开发布前仍需license/provenance review |

未完成的独立安全/语义审计项目保持PENDING；不把已知范围之外的缺陷数宣称为零。

## PR readiness

**NOT READY FOR PR。** FR10-01是material D9 blocker；不存在PASS docs-only audit commit。
分支仍在 `8ac248d40cc5e06add22a16a32ef2e37e20f3260`，main冻结，phase没有PR。

## Next owner gate

等待owner审阅此本地报告并决定是否授权修复。若修复获准，仍需之后明确授权完整Final Re-Audit；
本轮不继续实施或开PR。STATUS/ROADMAP、DECISIONS、生产/测试文件均未修改。

**MIGRATION TOOLING V1 FINAL RE-AUDIT AFTER P2F10 BLOCKED**

**NOT READY FOR PR — AWAIT OWNER REVIEW**
