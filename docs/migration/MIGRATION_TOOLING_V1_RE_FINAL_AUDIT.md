# Migration Tooling v1 — Re-Final Audit after P2F1

2026-09-15。审计范围为整个里程碑，执行身份固定为 `1adb6534d579c5a2c1a4d21e166fb244096daa57`。

## 1. Executive verdict

**BLOCKED — NOT READY FOR PR。当前 HIGH blockers = 1；MEDIUM defects = 1。**

原 HIGH2 / MEDIUM3 的指定复现均已关闭。但完整里程碑独立复审确认两个新问题：

- **RA-01 / HIGH：嵌套人工备注被输出识别器接受，随后实际覆盖丢失。** 详见第13节。
- **RA-02 / MEDIUM：已知物品基类 MONEY / COMBINED_ITEM 与 ROOM 混合继承仍被准入。** 详见第15节。

新鲜76/122测试及全源确定性通过，不抵消独立发现。没有修改任何工具、测试、fixture、
DECISIONS、game、reference 或 CI。按 BLOCKED 分支保留 executable HEAD，不创建提交、不 push，
STATUS/ROADMAP 不改为 PASS；本报告作为新的 untracked 本地审计证据保留。

## 2. Frozen identities

| 身份 | 核对结果 |
| --- | --- |
| Repository | Toxicccxz/eastern-stories-godot |
| Branch | phase/migration-tooling-v1 |
| main / origin main / merge-base | cd07808cb76147d0b8c0dad9b82d078b49fefe64 |
| executable HEAD / origin phase | 1adb6534d579c5a2c1a4d21e166fb244096daa57 |
| reference/es2 Git tree | 4106480ab28cce8cd7b55704f8ae9ae062d42d03 |
| 初始 tracked worktree/index | clean / clean |
| 初始 untracked | 仅原 BLOCKED Final Audit |
| phase PR | open/closed 查询均未返回 PR |

fetch 后所有身份与 owner 冻结值一致。P1、P2、P2F1 均 OWNER APPROVED / CLOSED，
D1–D9 LOCKED；本次仅获复审授权，不含修复、PR、merge 或 P3。

## 3. Full commit history

| 顺序 | Commit | Subject |
| --- | --- | --- |
| P1 | 0e5ff6a5cbc8d4091102e280c66868ba8763b4bb | Analyze Migration Tooling v1 extraction contract |
| Decisions | 8108763d6a4ddb3ad2b110200666424f4042e296 | Record Migration Tooling v1 P2 decisions |
| P2 | 8efc21ff8aa4c4c293347386f951631c56559fe2 | Add Migration Tooling v1 static room extractor |
| P2F1 | 1adb6534d579c5a2c1a4d21e166fb244096daa57 | Fix Migration Tooling v1 audit blockers |
| Re-Final Audit | 无提交 | 本地 BLOCKED 报告；executable HEAD 不变 |

## 4. Full milestone diff

main...executable HEAD：**4 commits，14 files，+2795 / -11**。

| 类别 | Files | Additions | Deletions |
| --- | ---: | ---: | ---: |
| Migration analysis/reports | 3 | 1101 | 0 |
| DECISIONS/STATUS/ROADMAP | 3 | 91 | 11 |
| tools/migration | 4 | 903 | 0 |
| tooling tests | 1 | 657 | 0 |
| fixtures/goldens/fixture notes | 3 | 43 | 0 |
| gameplay/runtime/Save schemas | 0 | 0 | 0 |
| reference/es2 | 0 | 0 | 0 |
| CI/build/config | 0 | 0 | 0 |

本次审计没有新增 tracked delta；本报告不计入上述冻结14文件差异。

## 5. First BLOCKED audit summary

原报告记录 H1 最终路径保护绕过、H2 续行关键宏绕过、M1 literal NPC 混合准入、
M2 未解析 include 仍被准入、M3 mapping 加法误隔离。原报告保持 owner-local untracked，
不是本次可执行权威，也没有被改写成 PASS。

## 6. P2F1 repair summary

[P2F1](MIGRATION_TOOLING_V1_P2F1_AUDIT_BLOCKER_FIXES.md) 改为 target-based guard、
带字节映射的 directive splicing、八项 exact literal exclusion、include admission barrier、
whole-mapping delimiter 检查与保守动态分类。版本1.0.1，并增加旧输出识别和14项测试。
本次不复用旧结果代替新运行，也没有回写历史 P1/P2/P2F1 报告。

## 7. H1 closure evidence — CLOSED

独立临时源位于仓库之外，output-root 为 REPOSITORY.parent。
game、reference/es2、docs 三目录，绝对与 output-root-relative 两种形式，共六组合：
全部 CLI exit2、atomic_write 未触达、target absent、父目录条目未改变。
测试拦截 writer，没有先向保护目录试写再清理。

[cli.py](../../tools/migration/cli.py):78 的判断基于 safe_path 后的最终 target。
批准的 build 子树实际全源 CLI 写入成功（诊断 exit1）；独立外部临时目录实际写入 exit0。
原 H1 已关闭；这不代表第13节的既有文件识别安全已经通过。

## 8. H2 closure evidence — CLOSED

32个独立 critical cases：ROOM/set/__DIR__/create × LF/CRLF × 名称前续行、名称内续行、
directive keyword 内续行、undef。ROOM 阴影拒绝准入；set/create 阴影不输出 create 字段；
__DIR__ 阴影不输出归一化出口。两种换行下的 benign LABEL 仍保留安全 short/exit。
每个案例的 fact、inherit、finding raw/hash 均按原始字节检查。

directive_parts 仅处理分析视图，保留原 token 和错误位置映射；未执行宏或 #if。
原 H2 已关闭。

## 9. M1 closure evidence — CLOSED for the confirmed literal defect

独立读取 [globals.h](../../reference/es2/mudlib/include/globals.h):54–68，比对当前八项表：

| Exact literal | Category |
| --- | --- |
| /std/room/bank | BANK |
| /std/room/class_guild | CLASS_GUILD |
| /std/force | FORCE |
| /std/room/hockshop | HOCKSHOP |
| /std/item | ITEM |
| /std/liquid | LIQUID |
| /std/char/npc | NPC |
| /std/skill | SKILL |

八项均保留两条 authored inherit，加入明确 category，OUT_OF_SCOPE、candidate=false、facts=[]。
代码没有 fuzzy filename/subclass 猜测。原 literal NPC 缺陷已关闭；第15节是不同已知 symbolic
物品基类的遗漏，不能据此把完整 D2 宣称为 PASS。

## 10. M2 closure evidence — CLOSED

直接缺 include、传递缺 include、传递缺 include 加 ROOM shadow 三案例均为
OUT_OF_SCOPE、supported_candidate=false、facts=[]、UNRESOLVED_INCLUDE 存在。
依赖不确定性不被标为 syntax corruption；ROOM shadow 仍有 inheritance evidence。
原 M2 已关闭。

## 11. M3 closure evidence — CLOSED

准确复现 `(["e":"/a"])+(["w":"/b"])` 及 nested mapping、ternary、RNG value、closure、
computed key、额外冒号、多值未知形式，共八项，均 PARTIAL，保留 safe short，无 fabricated exit，
有 DYNAMIC_EXPRESSION，无 SOURCE_SYNTAX_ERROR。
另四项明确损坏 mapping（缺 separator、空 entry、缺 value、错 delimiter）均 QUARANTINED，facts 清空。
原 M3 已关闭；不是扩展计算语义，也不认证所有平衡 LPC 都合法。

## 12. D1–D9 compliance

| Decision | Result | Evidence / limit |
| --- | --- | --- |
| D1 | PASS | Python3.12.14、stdlib AST imports、工具位于 tools/migration，无 Godot/第三方依赖 |
| D2 | BLOCKED | RA-02：MONEY/COMBINED_ITEM 混合 ROOM 被错误支持 |
| D3 | PASS for field/scope subset | 仅 identity/inherit/text/四 flags/ordered exits；错误类别准入另由 D2 阻断 |
| D4 | PASS | 独立 schema1/static-room-v1；无游戏 schema delta |
| D5 | PASS | 独立检查9838个原始字节跨度、hash、line/column |
| D6 | PASS | 无 LPC/宏/RNG/继承执行；只有限 __DIR__ literal normalization |
| D7 | PASS for output locations | H1六组合关闭；产物仅 ignored build/外部临时目录；既有文件覆盖安全另被 RA-01 阻断 |
| D8 | PASS | stdlib unittest、既有手写 fixture/golden；本次未更新 |
| D9 | BLOCKED | RA-01 的应拒绝人工注释输出返回 exit0 并覆盖；普通0/1/2用例通过不弥补此分支 |

## 13. Version 1.0.1 / old-output safety — RA-01 HIGH

当前版本确为1.0.1。独立外部临时目录实际 CLI 检查：

| Previous file | Expected exit | Actual exit | Preserved |
| --- | ---: | ---: | --- |
| 完整 canonical UNREVIEWED 1.0.0 | 0 | 0 | 正常升级 |
| 完整 canonical UNREVIEWED 1.0.1 | 0 | 0 | 相同字节 |
| metadata-only fake | 2 | 2 | yes |
| unknown version | 2 | 2 | yes |
| root APPROVED | 2 | 2 | yes |
| altered manifest hash | 2 | 2 | yes |
| object/manifest source_path 不一致 | 2 | 2 | yes |
| inconsistent summary | 2 | 2 | yes |
| root owner_notes | 2 | 2 | yes |
| object owner_notes | 2 | **0** | **no，备注丢失** |
| fact owner_notes | 2 | **0** | **no，备注丢失** |
| manifest-file owner_notes | 2 | **0** | **no，备注丢失** |
| noncanonical compact JSON | 2 | 2 | yes |

最小重现：用 extractor 生成普通最小 ROOM 的完整 IR，添加
`document['objects'][0]['owner_notes'] = 'Owner review: retain this note'`，保持 indent2/LF JSON，
写入外部临时 output/static-rooms.json。再次运行同 source/output CLI。
recognized_output 返回 True；CLI 返回0；实际文件被替换，备注消失。
同样可在 facts[0] 或 source_manifest.files[0] 添加该字段，结果一致。

根因：[cli.py](../../tools/migration/cli.py):31 只对白名单顶层键作精确检查；40–66 检查部分嵌套
字段和统计一致性，没有拒绝嵌套人工字段。canonical 对未知嵌套字段原样序列化，因此
`canonical(previous) == payload` 不能证明该对象没有人工备注。destination:98 随即授权覆盖。
这不是要求密码学认证，也不是 TOCTOU；是可直接识别的额外人工字段未被拒绝。

严重性 HIGH：正常重跑即可无声损失已有人工审查资料，违反本次第11节拒绝 owner/manual notes
和既有 manual-output preservation 合同。实际损失只发生于本审计创建的可丢弃示例，没有真实资料受影响。
需要另行授权修复及独立回归；本次禁止修复。

## 14. Lexer/provenance audit

已检查 byte Source、UTF-8/NUL/U+FFFD 拒绝、comment/string/escape/heredoc/array heredoc、
directive capture/splicing、delimiter pairing。新鲜 suite 覆盖 Unicode、CRLF、错误 offset。
新鲜全源独立检查 facts/findings/direct inherits/normalization inputs 共9838个跨度，
raw 或 raw_hex、SHA-256、zero-based start/end-exclusive、1-based line/codepoint column 均通过。
lexer 是有界识别器，不是完整语法认证器；没有修复原始字节。

## 15. ROOM admission audit — RA-02 MEDIUM

评论、字符串、heredoc模板、conditional compilation、critical macro shadow、缺 include，
既有排除符号及八项 literal policy 的测试通过。roommaker 是 ITEM + F_AUTOLOAD，
OUT_OF_SCOPE，两个 ROOM_CODE 模板没有被当作实际 ROOM 继承。

但独立检查以下两个明确定义的物品符号：

```c
inherit ROOM;
inherit MONEY; // 另一个独立案例换为 COMBINED_ITEM
void create() { set("short", "mixed item"); }
```

两案例实际均 candidate=true、PARTIAL、facts=[inherit, inherit, short]，只有额外
UNRESOLVED_INHERITANCE，未 OUT_OF_SCOPE。预期 D2 item 类别排除：candidate=false、facts=[]。

权威证据：[globals.h](../../reference/es2/mudlib/include/globals.h):58/64 明确定义
COMBINED_ITEM=/std/item/combined、MONEY=/std/money；[money.c](../../reference/es2/mudlib/std/money.c):3
直接 inherit COMBINED_ITEM。[combined.c](../../reference/es2/mudlib/std/item/combined.c) 提供堆叠物品
amount、重量、move 合并和自动清除语义；既有 architecture 也明确将其归为 game items。
这不需要通过模糊文件名或任意继承求值猜类别。

根因：[room_extractor.py](../../tools/migration/room_extractor.py):280–286 的 symbolic excluded set
包含 ITEM 但缺 MONEY、COMBINED_ITEM。此问题独立于已经修复的 literal NPC 案例；完整 D2
不能用“未知附加继承只标 PARTIAL”容纳已知排除类别。严重性 MEDIUM，与原 M1 准入错误同类。
没有在本次全源扫描发现这两种混合对象；合成反例仍证明准入规则缺口。代码与测试未改。

## 16. Fact extraction audit

一处可靠 create、bare set、local setter shadow、foreign receiver、nested/control scopes、
reset/init/valid_leave 排除、重复 setter 保持顺序、显式0与缺省区分均经代码及新鲜 suite 检查。
short/name 为 literal；long TEXT_ONLY；只 outdoors/indoors/no_clean_up/no_fight；无 inherited defaults。
RA-02 会把这些字段从错误对象类别输出，属于 admission failure，不能因字段自身 literal 而忽略。

## 17. Exit extraction audit

有序 mapping、重复方向、raw direction/target、绝对 literal 和窄 __DIR__ 归一化保留。
reference 仅报告 EXISTS/MISSING/CASE_MISMATCH/AMBIGUOUS/UNRESOLVED；不补边、修路径或算 reachability。
未知表达式与 callback/RNG 不执行；keep2 静态出口与随后 mutation 同时存在并 PARTIAL。
原计算 mapping 误隔离已关闭，未扩大语义子集。

## 18. Findings/status audit

14个要求的 FindingCode 均存在。只 EXTRACTED/PARTIAL/OUT_OF_SCOPE/QUARANTINED，输出恒 UNREVIEWED。
全源 OUT_OF_SCOPE/QUARANTINED facts 为空；PARTIAL 允许独立安全 facts；EXTRACTED 不代表迁移批准。
原始源错误继续诊断；没有通过删除真实错误得到 exit0。

## 19. CLI/output safety

source/output overlap、path escape、link/junction、tracked file、atomic failure 清理的现有用例
在新鲜 suite 通过；H1 的 ancestor-root攻击独立通过。RA-01 使整体覆盖安全 BLOCKED。
可写输出位置正确不等于允许覆盖其中含人工字段的现有文件。没有更改 CLI/测试来规避结论。

## 20. Real-source review

直接读取并对照新鲜输出：roommaker.c、city/street1.c、snow/school1.c、oldpine/pine3.c、
oldpine/keep2.c、village/lake.c、latemoon/sroad1.c、latemoon/upstar/upcenter.c、
village/lordhouse3.c、cloud sword_book.c；另读取 oldman/goddd 错误附近及 encoding 原始字节。
street1 保留京师东街及三个原始出口；school1 两静态出口与 door/population/closure findings；
pine3 四随机目标不输出静态出口；keep2 保留两出口及 mutation；lake 保留显式 no_clean_up=0 和 callbacks。
损坏样本与隔离理由一致，无源修复。MONEY/COMBINED_ITEM 源另用于 RA-02。

## 21. Fresh tests

全在精确 executable HEAD `1adb6534d579c5a2c1a4d21e166fb244096daa57` 运行：

- Python3.12.14；migration suite **76 PASS**，full Python **122 PASS**。
- repository/static PASS；worktree 和 main...HEAD diff --check PASS。
- 额外独立闭环检查：H1六、H2三十二加benign二、M1八、M2三、M3八加malformed四均通过。
- 新 overwrite 13案例中三个嵌套备注保护失败；新物品准入两个案例失败。
- 文档校验包含本新报告：8份文档、202个 local targets、6个 anchors 全通过；31个必需章节完整。

既有测试通过不表示新反例通过。新探针仅 ignored build 临时脚本/JSON，不添加或修改测试文件。
**Godot gameplay canonical suite not required/run for this tooling-only Re-Final Audit.**
没有运行远端 CI；mock APK 测试输出不是实际打包游戏证明。

## 22. Fresh corpus metrics

两次新 CLI 输出位于 ignored build/migration-tooling-v1/re-final-audit/run-a.json 和 run-b.json。

| Metric | Fresh actual |
| --- | ---: |
| scanned | 2336 |
| supported | 499 |
| EXTRACTED | 0 |
| PARTIAL | 499 |
| OUT_OF_SCOPE | 1824 |
| QUARANTINED | 13 |
| facts | 2804 |
| findings | 4457 |
| exit A / B | 1 / 1 |

| Finding code | Count |
| --- | ---: |
| REQUIRES_SEMANTIC_REVIEW | 1713 |
| UNRESOLVED_INHERITANCE | 0 |
| UNRESOLVED_INCLUDE | 97 |
| DYNAMIC_EXPRESSION | 11 |
| ORDER_SENSITIVE_MUTATION | 36 |
| RNG_SEMANTICS | 62 |
| CALLBACK_BEHAVIOR | 326 |
| DRIVER_SEMANTICS_UNKNOWN | 410 |
| SOURCE_SYNTAX_ERROR | 5 |
| SOURCE_ENCODING_ISSUE | 8 |
| DUPLICATE_DECLARATION | 0 |
| UNRESOLVED_REFERENCE | 0 |
| UNSUPPORTED_CONSTRUCT | 484 |
| OUT_OF_SCOPE | 1305 |

与 post-P2F1 全文 JSON 相同；没有恢复目标数字的操作或 hard-coded census。

## 23. Quarantine inventory

路径相对 reference/es2/mudlib。全部与 P2F1 相同，没有 status change：

| Path | Reason class | 原始问题 / detector line |
| --- | --- | --- |
| cmds/std/exercise.c | SOURCE_ENCODING_ISSUE | U+FFFD / 57 |
| d/choyin/npc/yamen_po.c | SOURCE_ENCODING_ISSUE | U+FFFD / 123 |
| d/latemoon/sroad1.c | SOURCE_SYNTAX_ERROR | line12坏引号，检测到未闭字符串 / 15 |
| d/latemoon/upstar/upcenter.c | SOURCE_ENCODING_ISSUE | U+FFFD / 11 |
| d/npc/oldman.c | SOURCE_SYNTAX_ERROR | 缺调用开头，孤立闭括号 / 145 |
| d/temple/npc/obj/magic_book.c | SOURCE_ENCODING_ISSUE | U+FFFD / 24 |
| d/temple/npc/obj/spells_book.c | SOURCE_ENCODING_ISSUE | U+FFFD / 24 |
| d/temple/obj/magic_book.c | SOURCE_ENCODING_ISSUE | U+FFFD / 24 |
| d/temple/obj/spells_book.c | SOURCE_ENCODING_ISSUE | U+FFFD / 24 |
| d/village/lordhouse3.c | SOURCE_SYNTAX_ERROR | 注释开括号而保留闭括号 / 81 |
| u/cloud/npc/goddd.c | SOURCE_SYNTAX_ERROR | line92未转义引号，后续未闭字符串 / 161 |
| u/cloud/obj/npc/flower_girl/guihua.c | SOURCE_ENCODING_ISSUE | 338 NUL、110 U+FFFD / 1 |
| u/cloud/obj/sword_book.c | SOURCE_SYNTAX_ERROR | 截断 set/et 结构 / 27 |

这些是真实字节/结构损坏；没有因 v1 不会计算正常 mapping 而保留误隔离，也没有削弱隔离来降低数字。

## 24. Determinism

| Run | Bytes | SHA-256 |
| --- | ---: | --- |
| Fresh A | 10030223 | 4e5e63596041f50c6b73cf83921b3c915d32b927963a1682cdb9f98120d045f2 |
| Fresh B | 10030223 | 4e5e63596041f50c6b73cf83921b3c915d32b927963a1682cdb9f98120d045f2 |

逐字节相等；与历史 post-P2F1 相等。工具/源未改变，确定性通过。

## 25. Source immutability

reference tree `4106480ab28cce8cd7b55704f8ae9ae062d42d03` 不变。
独立 physical/tracked 枚举均2336项且路径相等；repo-relative raw-byte manifest 仍为
`744e33e1740db7909129a3ae5e295158341b5012a411af953b144a5075bb0a80`。
无 source/game delta 或 probe；没有生成源文件、Save/user data 或 Native 输出。

## 26. First BLOCKED audit immutability

原 owner-local `docs/migration/MIGRATION_TOOLING_V1_FINAL_AUDIT.md` 保持未暂存、未提交、未改动。
起始核对 SHA-256：`a61cd221e8b70961d963484dfe953f5e341511967d9cfd66a55159b1bab85d63`。
结束再次核对为相同值；本报告使用不同路径，不替换原报告。

## 27. Security/artifact audit

完整14文件差异均为文本；没有二进制、整棵复制源、凭证、token、Save/user data 或 tracked corpus。
运行时/IR 没有工作站绝对路径、时间戳或机器状态；历史文档的路径/运行证据不作为生成数据。
临时证据只在 ignored build 和自动清理的 external temporary tree；所有受保护目标均未创建。
AST 仅 stdlib/relative imports、无 eval/exec LPC；subprocess 仅 Git 文件保护。
发现的覆盖安全缺陷单独列为 RA-01，而不是以安全放置本次产物来掩盖。

## 28. Documentation consistency

根/docs AGENTS、repository policy、architecture、DECISIONS 与 P1/P2/P2F1/STATUS/ROADMAP
已对照。旧 P1 建议、P2 等待审查、P2F1 等待授权措辞保留历史；最新 owner 指令明确关闭 P1/P2/P2F1。
当前复审 BLOCKED，因此 PASS-only STATUS/ROADMAP 更新条件未满足。
DECISIONS delta=0；没有把新缺陷通过修改 D2/D9 变成允许行为。
没有新的 frozen PASS-audited HEAD，也没有 PR/CI/merge/P3 状态暗示。

## 29. Residual risks

| Severity | Item | Disposition |
| --- | --- | --- |
| HIGH blocker | RA-01：嵌套人工备注被覆盖丢失 | 需单独修复授权，当前阻断 |
| MEDIUM defect | RA-02：MONEY/COMBINED_ITEM 错误准入 | 需修正已知排除类别，当前阻断 |
| MEDIUM residual | bounded lexer 非完整 LPC grammar，可能漏提取 | 明确未知/保守结果；无完整语义认证 |
| MEDIUM residual | preprocessor/driver/inherited defaults 不确定 | 不执行、不猜测；人工语义审查 |
| MEDIUM residual | 13个真实损坏源 | 继续隔离，不修源 |
| MEDIUM residual | concurrent filesystem TOCTOU | 已知限制；与 H1/RA-01 确定性缺陷不同 |
| LOW residual | case-sensitive path semantics | 如实报告 case/missing，不修复 |
| LOW residual | 10MB 级 canonical JSON | 当前本地可接受；不需要新增缓存/数据库 |
| LOW residual | old-output recognition 非密码学认证 | 无认证要求，但可识别人工字段必须受保护 |
| LOW deferred gate | 无 PR remote CI、无 Native consumer | 后续授权门禁，不单独作为缺陷 |
| Separate unresolved | Native license / ES2 provenance ledger | 未解决且未改动，不作公开发布/商用许可结论 |

## 30. PR readiness

**NOT READY FOR PR。** 原五项关闭不等于完整里程碑通过；新 HIGH1/MEDIUM1 阻断。
没有 PASS commit、push、PR、auto-merge、merge、P3、NPC/item support 或 Native importer。
分支与所有历史提交保留。

## 31. Exact next owner gate

owner 审查本 BLOCKED 报告，决定是否另行授权同阶段分支上的最小修复切片，处理
RA-01 嵌套人工字段保护与 RA-02 明确物品类别准入，然后重新授权 frozen-head Re-Final Audit。
本审计不执行这些修复、不新增回归测试，也不替 owner 授权下一阶段。

**MIGRATION TOOLING V1 RE-FINAL AUDIT BLOCKED**
**NOT READY FOR PR — AWAIT OWNER REVIEW**
