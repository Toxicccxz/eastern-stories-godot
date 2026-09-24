# Migration Tooling v1 — P2F1 Audit Blocker Fixes

2026-09-15。**P2F1 FIX IMPLEMENTED — AWAIT OWNER REVIEW / RE-AUDIT NOT YET AUTHORIZED**。

## 1. 授权与冻结基线

首次 Final Audit 为 BLOCKED，owner 确认 HIGH2 / MEDIUM3 并仅授权本修复切片。
P1/P2 已 OWNER APPROVED / CLOSED；[D1–D9](DECISIONS.md#migration-tooling-v1-p2--owner-locked-extraction-boundary)
保持 LOCKED。本报告不作新的 Final Audit 判定。

| 身份 | 值 |
| --- | --- |
| Repository | Toxicccxz/eastern-stories-godot |
| 唯一阶段分支 | phase/migration-tooling-v1 |
| main / base | cd07808cb76147d0b8c0dad9b82d078b49fefe64 |
| 修复前 HEAD / origin phase | 8efc21ff8aa4c4c293347386f951631c56559fe2 |
| P1 | 0e5ff6a5cbc8d4091102e280c66868ba8763b4bb |
| D1–D9 决定提交 | 8108763d6a4ddb3ad2b110200666424f4042e296 |
| reference/es2 Git tree | 4106480ab28cce8cd7b55704f8ae9ae062d42d03 |

fetch 后所有冻结身份一致；阶段 PR 查询包含 open/closed，未发现 PR。
修复提交使用一个 `Fix Migration Tooling v1 audit blockers` 提交，不创建子分支。
自身提交 SHA、提交后测试和 push 后远端一致性在最终 owner 报告中记录，避免自引用提交。

## 2. 原 BLOCKED 审计证据保全

owner-local `docs/migration/MIGRATION_TOOLING_V1_FINAL_AUDIT.md` 只读，保持 untracked。
它不是本提交的文档或链接目标，没有编辑、移动、暂存或提交。

修复前及提交前 SHA-256 均为：
`a61cd221e8b70961d963484dfe953f5e341511967d9cfd66a55159b1bab85d63`。
提交后及 push 后必须再次核对相同 SHA，结果随最终报告提供。

## 3. H1 — 最终输出目标约束

旧 [cli.py](../../tools/migration/cli.py) 用 output_root 是否在仓库内判断保护；
外部临时源 + 仓库父目录 output_root 可令最终 target 回到 game/reference，从而到达 writer。
修复直接检查已通过 safe_path 的最终 target：在 REPOSITORY 内且不在
`build/migration-tooling-v1/` 内即 ToolError / exit2。
source/output 重叠、tracked/manual 文件保护、link/junction 拒绝和原子替换保留。

回归覆盖 game、reference/es2、docs 三个路径，各含绝对及相对 output，共六个攻击组合。
均 exit2、atomic_write 未调用、目标不存在、父目录条目未改变。
仓库内批准的 build 目标仍可接受；独立外部临时输出实际写入成功、exit0，随后随临时目录清理。
独立于 unittest 的三路径绝对目标探针再次得到相同拒绝结果；没有向受保护目录试写。

## 4. H2 — 续行指令分析

旧 directive_parts 将反斜杠作为 token，导致 words[1] 不再是关键宏名称。
[room_extractor.py](../../tools/migration/room_extractor.py) 现在只在 directive 的分析字节视图中
移除反斜杠加 LF / CRLF，然后复用 lexer。维护每个分析字节到原始字节的映射，错误跨度映回原文。
不改变 Source、Token.text、原始 hash 或存储的 provenance；不执行宏、#if 或表达式。

回归涵盖 ROOM/set/__DIR__/create、undef、RO+OM 名称拆分、define 关键字拆分、LF/CRLF。
ROOM 阴影拒绝 candidate；set/create 阴影不产生 create 字段；__DIR__ 阴影不进行路径归一化。
普通 LABEL 续行仍保留安全 short。中文、原始续行及词法错误跨度均按原始字节验证。

## 5. M1 — 精确 literal 排除基类

旧准入只比较符号，`inherit ROOM; inherit "/std/char/npc";` 会错误获得支持。
新策略只识别下列明确常量，来源为
[globals.h](../../reference/es2/mudlib/include/globals.h):54–68，均为既有 D2 排除类别：

| 精确 literal path | 类别 |
| --- | --- |
| /std/room/bank | BANK |
| /std/room/class_guild | CLASS_GUILD |
| /std/force | FORCE |
| /std/room/hockshop | HOCKSHOP |
| /std/item | ITEM |
| /std/liquid | LIQUID |
| /std/char/npc | NPC |
| /std/skill | SKILL |

全部八项分别测试：两条 authored inherit/provenance 保留，精确类别加入 category_candidates，
OUT_OF_SCOPE、supported_candidate=false、无支持事实。类似文件名、不同大小写及未知子类不猜测，
仍保留未解析继承 finding。没有继承求值、NPC/item 提取或扩展语法。

## 6. M2 — include 不确定性前移至准入

旧实现仅阻止后续 create 字段，仍将缺失 include 的 ROOM 标为 supported 并产生 inherit fact。
现在 unresolved include hazard 参与 admission；缺失及传递依赖缺失均不准入，facts=[]，
OUT_OF_SCOPE，显式 UNRESOLVED_INCLUDE。直接观察到 ROOM 阴影时仍保留 UNRESOLVED_INHERITANCE。
仅沿用现有有界 hazard 检查；依赖不确定性不是 SOURCE_SYNTAX_ERROR，不为此 quarantine。

提前返回之前保留 include-context finding，也使原本 OUT_OF_SCOPE 对象的该信息不再被丢弃。
finding 说明整个 include 依赖上下文无法可靠解析，不声称每一条关联 include 的文件都不存在。

## 7. M3 — 计算 mapping 与真正损坏区分

旧 parser 只比较首尾 token，误把 `(["e":"/a"])+(["w":"/b"])` 当一个完整 literal mapping，
切掉首尾后触发伪结构错误。现在验证两层 delimiter 配对确实覆盖整个表达式，再提取 literal entries。
否则报告 DYNAMIC_EXPRESSION，保留 independently safe short/inherit，PARTIAL，无虚构出口。

entry 的额外冒号或未知平衡表达式保守标为 dynamic，不再一概认定 syntax error。
明确缺少 literal separator、空 entry、缺 key/value 或损坏 delimiter 仍 QUARANTINED 并清空事实。
回归包括准确审计复现、嵌套 mapping、ternary、random、closure/computed key、多值及额外冒号。
这些仅作分类，不进行计算。原 LPC mapping 加法出处可见
[dns_master.c](../../reference/es2/mudlib/adm/daemons/network/dns_master.c):604/619 与
[mudlist.c](../../reference/es2/mudlib/cmds/wiz/mudlist.c):25；未使用外部移植版本。

## 8. 版本与旧输出替换策略

extractor_version 从 1.0.0 升为 **1.0.1**；schema1 / static-room-v1 不变。
recognition 接受完整 canonical、UNREVIEWED 的 1.0.0/1.0.1 输出，核对顶层形状、既有 canonical
约束、manifest/hash/identity/status、finding 关联及 summary 一致性；仅有三个版本元数据不够。
未知版本、非 canonical 文本、reviewed 文档、不一致 manifest/summary、顶层人工 notes 拒绝覆盖。
这是格式识别，不是生成者的密码学认证；人工审查材料应保存在独立文件中。

测试实际覆盖 1.0.0 完整输出升级、两个版本的 metadata-only 假 JSON、人工文本、修改/未知输出，
以及既有 tracked-file 与原子替换失败保护。独立检查确认历史 9,950,176 字节 1.0.0 全源输出仍被识别。
历史 [P2 报告](MIGRATION_TOOLING_V1_P2_STATIC_ROOM_EXTRACTOR.md) 保留原版本及结果，不回写历史。

## 9. 回归组与本地验证

[test_migration_tooling.py](../../tools/tests/test_migration_tooling.py) 保留原62项测试及手工 golden。
新增14项：AuditBlockerRegressionTests11项，版本/覆盖兼容3项；子案例覆盖上述边界。
最初10项 blocker 组在未修复8efc21f实现上运行，32个子案例失败，覆盖全部五项缺陷。
之后新增错误偏移测试和版本测试，最终新增14项全通过，没有修改旧断言来掩盖问题。

Python **3.12.14**，本地实际结果：

| 验证 | 结果 |
| --- | --- |
| targeted blocker + CLI | 28 tests PASS |
| migration suite | 76 tests PASS |
| full Python suite | 122 tests PASS |
| repository/static | PASS |
| git diff --check | PASS |
| 独立原始 provenance 检查 | 9,838 个跨度 PASS（facts、findings、direct inherits、normalization inputs） |

命令：`python -m unittest discover -s tools/tests -p test_migration_tooling.py -v`、
`python -m unittest discover -s tools/tests -p test_*.py -v`、
`python tools/ci/repository_checks.py --repository .`、`git diff --check`。
修复提交后按 owner 要求再执行整套验证、双跑、拦截探针和证据 hash，然后才 push。
本报告记录提交前完成结果；提交后精确 SHA 结果由最终报告提供。

**Godot gameplay canonical suite not required/run for this tooling-only fix slice.**
没有运行/声称远端 CI 或实际游戏。既有 Python build 测试的微型 mock APK 不是打包游戏启动证据。

## 10. 全源前后比较

准确输入为 reference/es2；同 profile。历史 baseline JSON hash 已重新核对。

| Metric | Before | After |
| --- | ---: | ---: |
| scanned | 2336 | 2336 |
| supported | 499 | 499 |
| EXTRACTED | 0 | 0 |
| PARTIAL | 499 | 499 |
| OUT_OF_SCOPE | 1824 | 1824 |
| QUARANTINED | 13 | 13 |
| facts | 2804 | 2804 |
| findings | 4360 | 4457 |
| exit | 1 | 1 |

| Finding code | Before | After |
| --- | ---: | ---: |
| REQUIRES_SEMANTIC_REVIEW | 1713 | 1713 |
| UNRESOLVED_INHERITANCE | 0 | 0 |
| UNRESOLVED_INCLUDE | 0 | 97 |
| DYNAMIC_EXPRESSION | 11 | 11 |
| ORDER_SENSITIVE_MUTATION | 36 | 36 |
| RNG_SEMANTICS | 62 | 62 |
| CALLBACK_BEHAVIOR | 326 | 326 |
| DRIVER_SEMANTICS_UNKNOWN | 410 | 410 |
| SOURCE_SYNTAX_ERROR | 5 | 5 |
| SOURCE_ENCODING_ISSUE | 8 | 8 |
| DUPLICATE_DECLARATION | 0 | 0 |
| UNRESOLVED_REFERENCE | 0 | 0 |
| UNSUPPORTED_CONSTRUCT | 484 | 484 |
| OUT_OF_SCOPE | 1305 | 1305 |

唯一数量变化是 M2 提前返回前新增97条 include-context finding，分布在39个原已 OUT_OF_SCOPE
对象。包括 network daemon/service、simul_efun 和 command 的 include 上下文；没有新增准入对象。
逐对象比较仅39个对象 finding_ids 改变，其余对象字段完全一致。
过滤新 UNRESOLVED_INCLUDE 后全体旧 finding 数组完全相等。不存在事实或准入数量的隐性回归。

## 11. Quarantine 逐文件结果

改变 quarantine 状态的路径：**无**。下列每项均 QUARANTINED → QUARANTINED：

| mudlib-relative path | 保持原因 |
| --- | --- |
| cmds/std/exercise.c | encoding corruption |
| d/choyin/npc/yamen_po.c | encoding corruption |
| d/latemoon/sroad1.c | 损坏字符串/出口引号 |
| d/latemoon/upstar/upcenter.c | replacement character |
| d/npc/oldman.c | 缺少调用开头，孤立闭括号 |
| d/temple/npc/obj/magic_book.c | encoding corruption |
| d/temple/npc/obj/spells_book.c | encoding corruption |
| d/temple/obj/magic_book.c | encoding corruption |
| d/temple/obj/spells_book.c | encoding corruption |
| d/village/lordhouse3.c | 注释掉开括号但保留闭括号 |
| u/cloud/npc/goddd.c | 未转义引号造成损坏字符串 |
| u/cloud/obj/npc/flower_girl/guihua.c | NUL / replacement character |
| u/cloud/obj/sword_book.c | 截断 set/et 结构 |

五个 syntax、八个 encoding 真实损坏源继续隔离。没有为降低数字弱化分类，exit1 是正确诊断结果。
M3 的审计复现是合成边界例，并非这13个文件中某一项被误分类的证明。

## 12. 确定性

两次独立 CLI 全源运行，输出均为 ignored build/migration-tooling-v1/p2f1 下临时证据。

| Run | Bytes | SHA-256 |
| --- | ---: | --- |
| A | 10030223 | 4e5e63596041f50c6b73cf83921b3c915d32b927963a1682cdb9f98120d045f2 |
| B | 10030223 | 4e5e63596041f50c6b73cf83921b3c915d32b927963a1682cdb9f98120d045f2 |

byte-for-byte equality PASS。与旧 hash
`c1bd6b7a946e74f07979239242cdbb3f5168ab0577eb502f9896bfc4cda00141`
不同是预期：版本及97条新增 finding/finding_ids 变更，体积增加80,047字节。

## 13. 源与架构完整性

reference Git tree 仍为 `4106480ab28cce8cd7b55704f8ae9ae062d42d03`。
独立枚举 physical/tracked 均2336文件、路径集合相等，没有 probe 或新增源文件。
repo-relative raw-byte manifest 仍为
`744e33e1740db7909129a3ae5e295158341b5012a411af953b144a5075bb0a80`；
IR source-root-relative manifest 仍为
`895d36086e184ba6bf520625c20e882394a0a6169aabf86a1b4c58ba835e2820`。

Game、reference、CI、Save schemas、D1–D9、P1、历史 P2 和手工 fixtures/goldens 无改动。
无第三方依赖、LPC execution、宏/继承求值、Native generation 或游戏状态变更。
Python 逻辑仍只负责 extraction/diagnostics；不是语言完整验证器或运行时。
既有并发恶意文件系统替换风险没有被本次 deterministic target guard 宣称解决。

## 14. 提交范围与检查

仅六个路径：

- tools/migration/cli.py：最终目标保护、旧版本完整输出识别。
- tools/migration/room_extractor.py：H2/M1/M2/M3 与 patch version。
- tools/tests/test_migration_tooling.py：14项新增回归。
- docs/migration/MIGRATION_TOOLING_V1_P2F1_AUDIT_BLOCKER_FIXES.md：本切片报告。
- docs/production/STATUS.md：最小当前状态修正。
- docs/production/ROADMAP.md：最小当前状态修正。

逐项检查 diff；只显式暂存这些路径。ignored corpus/log/verification script 不提交。
原 owner-local BLOCKED audit 保持唯一预期 untracked 文件；不纳入提交。

## 15. Owner review 边界

**P2F1 FIX IMPLEMENTED — AWAIT OWNER REVIEW / RE-AUDIT NOT YET AUTHORIZED**。
五项已确认缺陷的修复验证完成；这不是正式 Final Audit 重跑或 PASS。
阶段尚未集成 main；没有 PR、merge、新远端 CI 或 post-merge CI。
NPC/item extraction、Bank/Hockshop/ClassGuild 支持、Native/Godot generation、语法扩展、
游戏/Save/CI 改动及 P3 均延期且未授权。等待 owner 审查修复提交及另行授权 re-Final-Audit。
