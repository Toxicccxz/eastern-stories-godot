# Migration Tooling v1 — P2F2 Re-Audit Blocker Fixes

2026-09-15。**P2F2 FIX IMPLEMENTED — AWAIT OWNER REVIEW / NEXT RE-AUDIT NOT YET AUTHORIZED**。

## 1. Authorization / frozen baseline

owner 仅授权第二次 BLOCKED 审计发现的 HIGH1 / MEDIUM1 修复、验证、文档和一个修复提交。
P1/P2/P2F1 均 APPROVED / CLOSED；[D1–D9](DECISIONS.md#migration-tooling-v1-p2--owner-locked-extraction-boundary)
保持 LOCKED，没有另行 Final Audit、PR、merge 或 P3 授权。

| Identity | Verified value |
| --- | --- |
| Repository / branch | Toxicccxz/eastern-stories-godot / phase/migration-tooling-v1 |
| main / base | cd07808cb76147d0b8c0dad9b82d078b49fefe64 |
| Pre-fix executable HEAD / origin phase | 1adb6534d579c5a2c1a4d21e166fb244096daa57 |
| reference/es2 Git tree | 4106480ab28cce8cd7b55704f8ae9ae062d42d03 |
| Preflight tracked worktree / index | clean / clean |
| Preflight untracked | 仅两份预期 BLOCKED 审计报告 |
| Phase PR | open/closed 搜索未返回 PR |

fetch 后身份一致。保持原分支；无 reset/rebase/stash/clean/amend/force-push。

## 2. Second blocked-audit context

首次 Final Audit 的 HIGH2/MEDIUM3 经 [P2F1](MIGRATION_TOOLING_V1_P2F1_AUDIT_BLOCKER_FIXES.md) 修复。
第二次 Re-Final Audit 关闭原五项，但确认嵌套人工字段被覆盖及 MONEY/COMBINED_ITEM 错误准入。
两份审计均为 owner-local untracked 历史证据；本报告不将其作为已提交文档链接，也不改写其结论。

## 3. F2-H1 root cause

旧 recognized_output 只检查 exact top-level keys，嵌套对象仅核对部分属性。
canonical 也未关闭嵌套 schema，因此人工字段可原样序列化，通过 payload equality 后被正常重跑覆盖。
这不是 owner_notes 名称专属问题；任意未知嵌套字段都有相同数据丢失风险。

## 4. Closed-schema overwrite design

[room_extractor.py](../../tools/migration/room_extractor.py) 的 validate_document 是唯一共享校验入口。
canonical 先校验，再序列化；[cli.py](../../tools/migration/cli.py) 的 recognized_output 解析旧字节，
调用同一个 canonical 并比较字节。删除 CLI 里重复而不完整的 schema/integrity 检查。
未知/缺失字段、类型不对、非法 conditional shape 或内部不一致均拒绝，绝不删掉未知字段再覆盖。

校验同时保持原 manifest coverage/hash/order、object identity、review state、finding association、
summary 一致性保护；补充 provenance raw/span 长度和类型、typed value、合法计数检查。
bool 不冒充整数计数。所有 emitted review_state 必须 UNREVIEWED。
不读取旧输出所指向的外部源、不执行源代码，也不提供密码学作者认证。

## 5. Exact closed schema levels

| Layer | Constraint |
| --- | --- |
| document | exact schema/profile/version/review/manifest/objects/findings/summary keys |
| source_manifest | sha256/files only |
| manifest files | exact identity/kind/namespace/hash/size/status/review keys |
| objects | exact identity/namespace/status/candidate/category/inherit/fact/finding-ID keys |
| direct inherits | expression/symbol/provenance only；symbol 可以为 null |
| facts | exact core keys；long 必须且仅可有 TEXT_ONLY；normalized exit 必须且仅可有 normalization |
| findings | exact code/severity/object/reason/blocking/provenance/review/ID keys |
| provenance | exact source/hash/scope/construct/ordinal/byte/line/column/raw keys |
| encoding provenance | raw=null 时必须 raw_hex；正常 raw 不允许 raw_hex；hex 对应不可解码 UTF-8 |
| normalization | rule/version/inputs only；既有 SOURCE_DIR_LITERAL_CONCAT/version1/单 input |
| normalization inputs | 再次执行同一 closed provenance 检查 |
| typed scalar values | text/integer/reference 分别限定 kind/value；十进制整数保留字符串 |
| exit values | exact kind/direction/target/raw direction/raw target/reference keys |
| exit reference | target/status/candidates only；合法 status 和字符串数组 |
| summary | exact scanned/supported/statuses/total findings/finding_codes keys |
| summary.statuses | EXTRACTED/PARTIAL/OUT_OF_SCOPE/QUARANTINED exact keys，非负整数 |
| summary.finding_codes | 仅既有 FindingCode keys、正整数，且与实际数组计数一致 |

列表的成员也验证对应 record 或 scalar 类型，不能通过数组嵌入未知 dict。
未来 schema/version 扩展需显式新增规则；当前版本拒绝未知 future data 来保护文件。

## 6. Old-output compatibility

known versions 明确为 **1.0.0 / 1.0.1 / 1.0.2**，共享当前已知生成形状。
只有完整、canonical、UNREVIEWED、内部一致的文档可覆盖；版本元数据本身不是许可。
三版本均执行真实 CLI 和 os.replace，成功升级/重写为1.0.2，无残留 temporary file。
测试输入包含正常文字、整数、inherit/exit、归一化以及 invalid UTF-8 的 raw_hex 变体。
该输入有一个真实 synthetic quarantine，成功 scan/replace 的退出码为1，而不是工具失败。

另独立核对真实历史全源文件：1.0.0 的9,950,176字节输出和1.0.1的10,030,223字节输出均被识别。
原未知版本、reviewed、manual non-JSON、metadata-only、tracked、manifest/summary 不一致拒绝测试继续通过。
原子替换失败保留旧文件并清理临时文件的既有测试保留。

## 7. Extractor version

行为可观察变化，版本从1.0.1升至 **1.0.2**。IR schema1 / static-room-v1 不变。
未将两种行为标成同一版本；也未为了沿用旧输出 hash 隐藏版本变化。
历史 P1/P2/P2F1 文档不回写；本报告记录新的版本/替换策略。

## 8. F2-H1 adversarial tests

新增 P2F2RegressionTests 中的21个目标位置，覆盖第5节全部 record 层及各 typed value/provenance 变体。
逐一添加 owner_notes 和 future_field，分别以三版本运行：**126个 CLI adversarial 组合**。
全部要求 recognized_output=false、CLI exit2、atomic_write 未调用、旧字节完全相等。
另21个 manual_tag 直接验证 canonical 拒绝；非 key-specific 特判。
非法 conditional fact/provenance shape、typed value 和 count 也有拒绝案例。

独立于 unittest 的真实外部临时 read/write 探针在 object、fact provenance、manifest entry 放入
review_comment：三者均 exit2、writer 未调用、原字节保留。没有使用真实 owner 文件。
此前 H1 的三个 protected target 探针仍在写入前被拒绝，没有保护目录产物。

## 9. F2-M1 root cause

既有 symbolic excluded set 缺 MONEY/COMBINED_ITEM，literal denylist 也缺对应路径。
ROOM 与这些已知物品类混合时只产生 unresolved inheritance，却仍被支持并输出 room facts。

## 10. MONEY / COMBINED_ITEM authority

直接只读核对 [globals.h](../../reference/es2/mudlib/include/globals.h)：

| Source line | Symbol | Exact literal path |
| --- | --- | --- |
| 58 | COMBINED_ITEM | /std/item/combined |
| 64 | MONEY | /std/money |

这两个映射来自权威常量，不来自文件名推断或其他移植。没有修改 globals.h。

## 11. Symbolic and literal exclusion fix

只补入授权的两个符号和两个精确路径，复用原 authored inheritance/provenance/category evidence 机制。
ROOM+MONEY、ROOM+COMBINED_ITEM、ROOM+"/std/money"、ROOM+"/std/item/combined" 四组合均为
supported_candidate=false、OUT_OF_SCOPE、facts=[]；两条 authored inherit 及 raw/hash/span/category 保留。
相似 /std/money_custom 与 /std/item/combined_child 不被猜为这两类，继续保留 unresolved dependency。
没有增加其他 excluded bases、继承求值、NPC/item 提取或语法支持。

## 12. Regression evidence and existing-test adjustments

在修改生产实现之前加入七个新 test methods，旧1adb653实现运行产生106个失败子案例，
包含两个缺陷及新的版本/schema要求；没有 checkout/reset 历史树。修复后七项全部通过。
总测试数从76/122增至83/129。

既有测试只作三处必要调整：升级结果预期1.0.2、metadata-only版本集合加入1.0.2、
构造非法外部输入时用 json.dumps 而不是现在会提前拒绝的 canonical。
原拒绝/保全断言不变，没有修改 golden，也没有通过放松测试隐藏缺陷。

## 13. Local verification

Python3.12.14，提交前实际结果：

| Check | Result |
| --- | --- |
| focused P2F2 regression group | 7 tests PASS |
| migration suite | 83 tests PASS |
| full Python suite | 129 tests PASS |
| repository/static | PASS |
| git diff --check | PASS |
| independent external metadata probes | 3 PASS |
| historical full-output recognition | 1.0.0 / 1.0.1 PASS |

命令为既有 unittest discover（test_migration_tooling.py / test_*.py）、
tools/ci/repository_checks.py --repository . 和 git diff --check。
修复提交后按 owner 要求再执行全套 tests/static/diff、探针、双跑、隔离/源/审计 hash 检查，
全部通过才 push。最终 SHA 和 exact-commit 验证由完成报告记录，避免自引用提交。

**Godot gameplay canonical suite not required/run for this tooling-only P2F2 slice.**
没有远端 CI 或 runtime proof 声明；Python 测试的 mock APK 不是打包游戏验收。

## 14. Whole-corpus before / after

输入准确为 reference/es2，profile static-room-v1：

| Metric | Before | After |
| --- | ---: | ---: |
| scanned | 2336 | 2336 |
| supported | 499 | 499 |
| EXTRACTED | 0 | 0 |
| PARTIAL | 499 | 499 |
| OUT_OF_SCOPE | 1824 | 1824 |
| QUARANTINED | 13 | 13 |
| facts | 2804 | 2804 |
| findings | 4457 | 4457 |
| exit | 1 | 1 |

当前 corpus 没有被新增排除规则改变的混合候选；逐对象比较无字段变化。
finding 分布同前：REQUIRES_SEMANTIC_REVIEW1713、OUT_OF_SCOPE1305、UNSUPPORTED_CONSTRUCT484、
DRIVER_SEMANTICS_UNKNOWN410、CALLBACK_BEHAVIOR326、UNRESOLVED_INCLUDE97、RNG_SEMANTICS62、
ORDER_SENSITIVE_MUTATION36、DYNAMIC_EXPRESSION11、SOURCE_ENCODING_ISSUE8、SOURCE_SYNTAX_ERROR5；
UNRESOLVED_INHERITANCE / DUPLICATE_DECLARATION / UNRESOLVED_REFERENCE 均0。

## 15. Quarantine inventory / delta

路径相对 reference/es2/mudlib；全部仍 QUARANTINED，没有状态变化：

| Path | Reason class |
| --- | --- |
| cmds/std/exercise.c | SOURCE_ENCODING_ISSUE |
| d/choyin/npc/yamen_po.c | SOURCE_ENCODING_ISSUE |
| d/latemoon/sroad1.c | SOURCE_SYNTAX_ERROR |
| d/latemoon/upstar/upcenter.c | SOURCE_ENCODING_ISSUE |
| d/npc/oldman.c | SOURCE_SYNTAX_ERROR |
| d/temple/npc/obj/magic_book.c | SOURCE_ENCODING_ISSUE |
| d/temple/npc/obj/spells_book.c | SOURCE_ENCODING_ISSUE |
| d/temple/obj/magic_book.c | SOURCE_ENCODING_ISSUE |
| d/temple/obj/spells_book.c | SOURCE_ENCODING_ISSUE |
| d/village/lordhouse3.c | SOURCE_SYNTAX_ERROR |
| u/cloud/npc/goddd.c | SOURCE_SYNTAX_ERROR |
| u/cloud/obj/npc/flower_girl/guihua.c | SOURCE_ENCODING_ISSUE |
| u/cloud/obj/sword_book.c | SOURCE_SYNTAX_ERROR |

未改 lexical/mapping 分类、未修源、未降低隔离。exit1 仍是完成扫描并报告真实源损坏。

## 16. Determinism

两个独立 CLI 全源运行：

| Run | Bytes | SHA-256 |
| --- | ---: | --- |
| A | 10030223 | 4317449aaa28f23e3ec302e4f45603d5605cec49bf366deb4f69ac49a8877b0e |
| B | 10030223 | 4317449aaa28f23e3ec302e4f45603d5605cec49bf366deb4f69ac49a8877b0e |

byte-for-byte equality PASS。尺寸不变；与1.0.1 hash不同符合版本变化，不强求旧hash。
完整输出及临时验证脚本/日志仅保存在 ignored build/migration-tooling-v1/p2f2/，不提交。

## 17. Source / game integrity

reference Git tree 保持 `4106480ab28cce8cd7b55704f8ae9ae062d42d03`。
physical/tracked 文件各2336，路径集合相同；repo-relative raw-byte manifest 保持
`744e33e1740db7909129a3ae5e295158341b5012a411af953b144a5075bb0a80`，
source-root-relative manifest 保持 `895d36086e184ba6bf520625c20e882394a0a6169aabf86a1b4c58ba835e2820`。
game/reference/.github/Save/DECISIONS/历史报告无改动；保护目录没有 probe 或 untracked 产物。
没有第三方依赖、LPC execution、Native generation、新源内容或游戏状态变化。

## 18. Both blocked audit reports preserved

起始与提交前实际核对：

| Owner-local untracked report | SHA-256 |
| --- | --- |
| MIGRATION_TOOLING_V1_FINAL_AUDIT.md | a61cd221e8b70961d963484dfe953f5e341511967d9cfd66a55159b1bab85d63 |
| MIGRATION_TOOLING_V1_RE_FINAL_AUDIT.md | c67dc612139bf37a6c6a41d4753b58723b154d0f6e92cdca0ab5a34ad93d0548 |

两者未编辑、未移动、未删除、未暂存、未提交。提交后及 push 后再次核对；最终结果随完成报告提供。

## 19. Changed files / commit boundary

仅六个路径：tools/migration/cli.py、tools/migration/room_extractor.py、
tools/tests/test_migration_tooling.py、本 P2F2 报告、docs/production/STATUS.md、docs/production/ROADMAP.md。
无需新 module 或 fixture。逐项检查 diff，只显式暂存这些路径；一个
`Fix Migration Tooling v1 re-audit blockers` 提交。两份 untracked audit 不纳入提交。

## 20. Deferred scope / limitations

没有新的 Final Audit verdict、PR、merge、P3、NPC/item extraction、Native/Godot generator、
语法扩展、游戏/Save/CI 改动或 D1–D9 重设。
格式校验不提供密码学 provenance，也不把 UNREVIEWED 变成 APPROVED。
一般 lexer/driver 不确定性及并发文件系统替换限制仍属既有边界，非本次两项修复的额外承诺。
未扩展其他类别；进一步类别覆盖由另行授权的正式复审判断。

## 21. Owner-review boundary

**P2F2 FIX IMPLEMENTED — AWAIT OWNER REVIEW / NEXT RE-AUDIT NOT YET AUTHORIZED**。
两项确认缺陷已修复并局部验证；下一步是 owner review，再另行授权正式里程碑复审。
阶段尚未集成 main，没有 PR/remote PR CI/merge/post-merge CI，不自动开始下一切片。
