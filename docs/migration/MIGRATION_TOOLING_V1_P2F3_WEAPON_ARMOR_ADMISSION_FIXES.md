# Migration Tooling v1 — P2F3 Weapon / Armor Admission Fixes

2026-09-15。**P2F3 FIX IMPLEMENTED — AWAIT OWNER REVIEW / NEXT RE-FINAL-AUDIT NOT YET AUTHORIZED**。

## 1. Authorization / frozen baseline

Owner 仅授权补齐标准武器/防具 object bases 的 D2 准入排除、测试、全源双跑、文档及一个修复提交。
P1/P2/P2F1/P2F2 已 APPROVED / CLOSED；D1–D9 LOCKED。里程碑仍需另行授权的正式复审。

| Identity | Verified value |
| --- | --- |
| Repository / branch | Toxicccxz/eastern-stories-godot / phase/migration-tooling-v1 |
| main / origin main | cd07808cb76147d0b8c0dad9b82d078b49fefe64 |
| Pre-fix HEAD / origin phase | 864ebc4c8a749f3e56a39cd5cf0685b07765fd00 |
| Pre-fix subject | Fix Migration Tooling v1 re-audit blockers |
| Pre-fix parent | 1adb6534d579c5a2c1a4d21e166fb244096daa57 |
| Preflight tracked worktree / index | clean / clean |
| Phase PR | all-state search returned no PR |

fetch 后身份一致，仅有两份允许的 untracked 历史审计。没有 reset/rebase/merge/stash/clean/amend/force-push。

## 2. Owner discovery / D2 root cause

Owner 复查发现一个 MEDIUM 完整性缺口：symbolic exclusion 缺 DAGGER/FORK/SURCOAT/WAIST/WRISTS/HANDS；
literal denylist 缺少全部20个标准武器/防具路径。ROOM 混合继承因此可能仍输出静态 room facts。
[D2](DECISIONS.md#migration-tooling-v1-p2--owner-locked-extraction-boundary) 已排除这些对象；本次落实既有决定，
不改变 D1–D9 或扩大提取能力。两个历史 BLOCKED 审计不回写。

## 3. Hand-reviewed weapon authority

只读核对 [weapon.h](../../reference/es2/mudlib/include/weapon.h) 第14–22行：

| Symbol | Exact object base |
| --- | --- |
| AXE | /std/weapon/axe |
| BLADE | /std/weapon/blade |
| DAGGER | /std/weapon/dagger |
| FORK | /std/weapon/fork |
| HAMMER | /std/weapon/hammer |
| SWORD | /std/weapon/sword |
| STAFF | /std/weapon/staff |
| THROWING | /std/weapon/throwing |
| WHIP | /std/weapon/whip |

## 4. Hand-reviewed armor authority

只读核对 [armor.h](../../reference/es2/mudlib/include/armor.h) 第5–15行：

| Symbol | Exact object base |
| --- | --- |
| HEAD | /std/armor/head |
| NECK | /std/armor/neck |
| CLOTH | /std/armor/cloth |
| ARMOR | /std/armor/armor |
| SURCOAT | /std/armor/surcoat |
| WAIST | /std/armor/waist |
| WRISTS | /std/armor/wrists |
| SHIELD | /std/armor/shield |
| FINGER | /std/armor/finger |
| HANDS | /std/armor/hands |
| BOOTS | /std/armor/boots |

## 5. Non-object constants / feature boundary

没有将 F_AXE/F_BLADE/F_DAGGER/F_FORK/F_HAMMER/F_SWORD/F_STAFF/F_WHIP 纳入 object denylist，
没有改变它们的 feature inheritance 语义。TYPE_*、TWO_HANDED/SECONDARY/EDGED/POINTED/LONG 不是本次对象基类。
只读检查当前候选的 direct inherit/category evidence，没有 ROOM 候选含这些 F_* 或其精确 feature 路径。
未发现要求扩大本切片的实际 F_* 准入问题；这不是一般 feature 语义审计。

## 6. Symbolic completion

[room_extractor.py](../../tools/migration/room_extractor.py) 的既有 symbolic set 仅增加六个遗漏符号。
保留所有原有排除，包括 MONEY/COMBINED_ITEM、SPEAR/GLOVES 等既有项；不把历史项重新解释为本次权威集合。
授权的20个符号与 ROOM 混合继承全部 supported_candidate=false、OUT_OF_SCOPE、facts=[]。

## 7. Exact literal completion

EXCLUDED_LITERAL_BASES 追加第3–4节20个精确 path→symbol 映射，保留原10项，共30项。
继续用字典精确匹配；无 startswith、regex-prefix 准入、文件名猜测、子类查询或继承求值。
20个 literal 与 ROOM 混合继承也全部 false / OUT_OF_SCOPE / empty facts。
两种形式均保留两条 authored inherit、expression、raw、source SHA-256、byte span、行列、scope/construct、
category evidence 及 OUT_OF_SCOPE finding。未输出 unsupported 对象的 short/name/long/flags/exits。

## 8. Non-fuzzy regression

| Unknown inherit | Result |
| --- | --- |
| /std/weapon/sword_custom | supported candidate / PARTIAL / UNRESOLVED_INHERITANCE |
| /std/weapon/dagger_child | supported candidate / PARTIAL / UNRESOLVED_INHERITANCE |
| /std/armor/cloth_custom | supported candidate / PARTIAL / UNRESOLVED_INHERITANCE |
| /std/armor/hands_child | supported candidate / PARTIAL / UNRESOLVED_INHERITANCE |
| DAGGER_CHILD | supported candidate / PARTIAL / UNRESOLVED_INHERITANCE |
| CUSTOM_ARMOR | supported candidate / PARTIAL / UNRESOLVED_INHERITANCE |

这六项只保留 ROOM 和 authored expression，不新增任何已知武器/防具 category；未猜测兼容性。

## 9. Version / closed-output safety

EXTRACTOR_VERSION 从1.0.2升至 **1.0.3**；KNOWN_EXTRACTOR_VERSIONS 明列1.0.0/1.0.1/1.0.2/1.0.3。
四版本完整 canonical 输出均通过真实 CLI/os.replace 升级或重写为1.0.3。
未知版本、人工字段、metadata-only、非法 conditional shape、manifest/summary 不一致仍拒绝；拒绝后原字节保留。
closed schema 校验逻辑不改；仅版本集合和说明文字更新。cli.py 无改动。

## 10. Focused regression matrix

新增 P2F3RegressionTests 五个 test methods，expected mappings 在 TEST 手写，独立于生产表。

| Test | Cases / assertions | Result |
| --- | --- | --- |
| all standard symbols | 9 weapon + 11 armor；ROOM first，short must not migrate | 20 PASS |
| all standard literals | 对应20个精确路径，保留 authored literal | 20 PASS |
| exact mapping completeness | 20映射、9/11数量、8 feature paths 不纳入 | PASS |
| authority drift | 两个只读权威头文件与手写表完全一致 | 2 PASS |
| no fuzzy classification | 四路径、两符号 | 6 PASS |

生产修复前，新五项测试得到46个失败子案例：6 symbolic、20 literal、20 completeness；其余通过。
修复后全部通过。P2F2RegressionTests 七项也运行：MONEY/COMBINED_ITEM四组合、旧版本、closed schema 等保持通过。
嵌套未知字段覆盖四版本×21层×2字段=168个 CLI 保全组合；另21个 canonical 人工字段拒绝检查保持。
完整测试继续覆盖 output confinement、continued macros、unresolved includes、computed mappings 等历史边界。

## 11. Authority drift mechanism

测试只读提取 checked-in headers 的标准对象定义，并与手写9/11表比对（含数量和 exact pairs）。
新增/遗漏/改名/路径变动会失败，要求显式复核；不会动态扩大 expected table。
测试中的 source-definition regex 仅核对权威文本；生产准入不使用 regex、不运行头文件解析器。

## 12. Complete local verification

Python3.12.14；提交前 fresh results：

| Check | Result |
| --- | --- |
| targeted P2F3 + P2F2 | 5 + 7 = 12 methods PASS |
| migration suite | 88 PASS（原83） |
| full Python suite | 134 PASS（原129） |
| repository/static checks | PASS |
| git diff --check | PASS |
| independent nested metadata protection | 3 probes PASS；exit2、writer 未调用、字节相等 |
| independent protected output targets | game/reference/docs 三处均写入前拒绝，无产物 |

实际执行 unittest discover -s tools/tests -p test_migration_tooling.py / test_*.py -v、
tools/ci/repository_checks.py --repository . 以及 git diff --check。
提交后再跑定向、两套完整 tests、static、base...HEAD diff、语料双跑/隔离/完整性检查，全部通过才 push。
exact commit SHA 与提交后实际结果由最终回复提供，避免文档提交自引用。

**Godot gameplay canonical suite not required/run for this tooling-only P2F3 slice.**
这是本地工具验证，无远端 CI、实时游戏或打包启动证据声明；Python mock APK 不属游戏验收。

## 13. Whole-corpus before / after

准确输入 reference/es2/，profile static-room-v1；与保留的 P2F2 1.0.2 全源输出逐对象比较：

| Metric | P2F2 | P2F3 |
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

finding 分布保持：REQUIRES_SEMANTIC_REVIEW1713、OUT_OF_SCOPE1305、UNSUPPORTED_CONSTRUCT484、
DRIVER_SEMANTICS_UNKNOWN410、CALLBACK_BEHAVIOR326、UNRESOLVED_INCLUDE97、RNG_SEMANTICS62、
ORDER_SENSITIVE_MUTATION36、DYNAMIC_EXPRESSION11、SOURCE_ENCODING_ISSUE8、SOURCE_SYNTAX_ERROR5；
UNRESOLVED_INHERITANCE/DUPLICATE_DECLARATION/UNRESOLVED_REFERENCE 均0。

## 14. Changed-object inventory

**0个对象变化**，无 previous/new status 或 triggering inherit 可列。
此缺陷由测试可复现，但当前真实语料候选中没有触发新增排除的混合继承。
不是通过强制保持计数达到一致；所有对象字段逐一比较相等。

## 15. Quarantine inventory

以下路径相对 reference/es2/mudlib；与 P2F2 完全一致，新增0、移除0、状态变化0：

| Path | Reason |
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

8 encoding、5 syntax。exit1 表示扫描完成但存在隔离，不是工具异常；未降低 quarantine。

## 16. Determinism

| Independent CLI run | Bytes | SHA-256 |
| --- | ---: | --- |
| A | 10030223 | cc793647c1c9d70597276347a62bdd51e556108ddf0f0968b4443ceef10fcb67 |
| B | 10030223 | cc793647c1c9d70597276347a62bdd51e556108ddf0f0968b4443ceef10fcb67 |

byte-for-byte equality PASS。P2F2 同尺寸 hash 为4317449aaa28f23e3ec302e4f45603d5605cec49bf366deb4f69ac49a8877b0e；
新 hash 因 extractor_version 变更而变化，未强求历史 hash。
运行输出/日志/临时验证脚本仅位于 ignored build/migration-tooling-v1/p2f3/，不提交。

## 17. Source / game immutability

reference Git tree 保持 `4106480ab28cce8cd7b55704f8ae9ae062d42d03`；physical/tracked 各2336文件，路径集合相等。
repo-relative raw-byte manifest 保持 `744e33e1740db7909129a3ae5e295158341b5012a411af953b144a5075bb0a80`；
source-root-relative manifest 保持 `895d36086e184ba6bf520625c20e882394a0a6169aabf86a1b4c58ba835e2820`。
reference/es2、game、.github、Save/schema/config、DECISIONS 与历史报告无写入或差异。
保护目录无 probe/untracked 产物；没有生成语料入库、第三方依赖、LPC execution 或 Native generation。

## 18. Historical audit immutability

起始及提交前检查保持，提交后/push 后再次验证：

| Local untracked report | SHA-256 |
| --- | --- |
| MIGRATION_TOOLING_V1_FINAL_AUDIT.md | a61cd221e8b70961d963484dfe953f5e341511967d9cfd66a55159b1bab85d63 |
| MIGRATION_TOOLING_V1_RE_FINAL_AUDIT.md | c67dc612139bf37a6c6a41d4753b58723b154d0f6e92cdca0ab5a34ad93d0548 |

均不编辑/移动/删除/暂存/提交，不作为已提交文档链接。

## 19. Changed paths

仅五个：tools/migration/room_extractor.py、tools/tests/test_migration_tooling.py、本报告、
docs/production/STATUS.md、docs/production/ROADMAP.md。cli.py 无需变化；无需新 fixtures。
STATUS/ROADMAP 仅更新 owner review 与本切片验证状态；未改 D1–D9。

## 20. Verification / architectural review boundary

独立于测试复核生产 diff：只有固定类别/路径表与补丁版本变化；先准入后 facts 的既有边界保留，
源码和 provenance 仍原样保留，UI/World/Game Core 无依赖变化。闭合输出校验未放宽。
此处是本修复切片自检，不给出 milestone Final Audit / Re-Final Audit verdict。

## 21. Commit / deferred scope

逐路径检查并显式暂存五文件，仅一个 `Complete weapon and armor migration exclusions` 提交。
完成 exact-commit 验证后 push 原 phase branch，fetch 核对本地/远端一致、main 不变、仅两份审计 untracked。
无 PR/merge/P3、武器防具或 NPC/item 提取、Native/Godot 生成、fuzzy/subclass/inheritance evaluator，
无 F_* 语义扩展、源修复、gameplay/Save/CI 改动。

## 22. Owner-review boundary

**P2F3 FIX IMPLEMENTED — AWAIT OWNER REVIEW / NEXT RE-FINAL-AUDIT NOT YET AUTHORIZED**。
本切片完成仅代表授权 D2 缺口修复。里程碑仍未集成 main，须 owner review 后另行授权正式复审；
fresh Final Audit 通过前不具备 PR readiness。无本阶段 PR CI、merge 或 post-merge CI。
