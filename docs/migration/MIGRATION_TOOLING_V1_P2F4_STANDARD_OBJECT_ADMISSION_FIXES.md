# Migration Tooling v1 — P2F4 Standard Object Admission Fixes

2026-09-15。**P2F4 FIX IMPLEMENTED — AWAIT OWNER REVIEW / FINAL RE-AUDIT NOT YET AUTHORIZED**。

## 1. Authorization / frozen state

仅授权 globals.h 四个剩余对象基类的 D2 排除、测试、全源验证、文档和一个修复提交。
P1/P2/P2F1/P2F2/P2F3 已 OWNER APPROVED / CLOSED，D1–D9 LOCKED。

| Identity | Verified value |
| --- | --- |
| Repository / branch | Toxicccxz/eastern-stories-godot / phase/migration-tooling-v1 |
| main / origin main | cd07808cb76147d0b8c0dad9b82d078b49fefe64 |
| Pre-fix HEAD / origin phase | c0c7ffb3de3e26cadf395772f7503e71d3690e11 |
| Pre-fix subject | Complete weapon and armor migration exclusions |
| Pre-fix parent | 864ebc4c8a749f3e56a39cd5cf0685b07765fd00 |
| Tracked worktree / index | clean / clean |
| Untracked | 仅两份指定历史 BLOCKED 审计 |
| PR | all-state search returned no phase PR |

fetch 后所有冻结身份一致。沿用原阶段分支，无 reset/rebase/merge/stash/clean/amend/force-push。

## 2. D2 completeness discovery

Owner 的 globals standard-object 检查确认 BULLETIN_BOARD、CHARACTER、EQUIP、POWDER 尚未进入
symbolic/literal 排除表。与 ROOM 混合继承时会误准入并提取 room facts。
本次落实既有 [D2](DECISIONS.md#migration-tooling-v1-p2--owner-locked-extraction-boundary)，不改 D1–D9。

## 3. Hand-reviewed globals authority

只读核对 [globals.h](../../reference/es2/mudlib/include/globals.h) 的 Inheritable Standard Objects 节。
测试手写以下15项授权相关对象表，expected values 不来自生产 mapping：

| Symbol | Exact path | D2 classification |
| --- | --- | --- |
| BANK | /std/room/bank | specialized room / excluded |
| BULLETIN_BOARD | /std/bboard | non-room object / excluded |
| CHARACTER | /std/char | non-room object / excluded |
| CLASS_GUILD | /std/room/class_guild | specialized room / excluded |
| COMBINED_ITEM | /std/item/combined | non-room object / excluded |
| EQUIP | /std/equip | non-room object / excluded |
| FORCE | /std/force | non-room object / excluded |
| HOCKSHOP | /std/room/hockshop | specialized room / excluded |
| ITEM | /std/item | non-room object / excluded |
| LIQUID | /std/liquid | non-room object / excluded |
| MONEY | /std/money | non-room object / excluded |
| NPC | /std/char/npc | non-room object / excluded |
| POWDER | /std/medicine/powder | non-room object / excluded |
| ROOM | /std/room | only generic room category; existing safeguards still required |
| SKILL | /std/skill | non-room object / excluded |

该源码节实际还有第16项 **SSERVER → /std/sserver**。只读检查 [sserver.c](../../reference/es2/mudlib/std/sserver.c)：
它继承 F_CLEAN_UP，提供 offensive_target 技能目标选择辅助函数，没有此四项的 ITEM/CHARACTER 家族证据。
本次明确只新增四项，因此不改变 SSERVER 准入分类；在 OTHER_STANDARD_DEFINITIONS 中单独手写其定义，
让 authority drift 测试仍覆盖完整16项，不隐去它，也不声称已对它作新的 D2 语义审批。
后续如需改变该辅助基类的准入，需 owner 另行授权；当前完整性结论限定于授权的15项对象表。

## 4. BULLETIN_BOARD family evidence

[bboard.c](../../reference/es2/mudlib/std/bboard.c):7 直接 inherit ITEM；globals.h 映射 /std/bboard。
因此属于已排除的 ITEM family。没有迁移留言板内容、保存或交互行为。

## 5. CHARACTER family evidence

[npc.c](../../reference/es2/mudlib/std/char/npc.c):5 直接 inherit CHARACTER；globals.h 映射 /std/char。
[char.c](../../reference/es2/mudlib/std/char.c) 定义 is_character 并组合角色 features，证明其角色基类身份。
不执行或翻译其 heartbeat、combat、feature inheritance。

## 6. EQUIP family evidence

[equip.c](../../reference/es2/mudlib/std/equip.c):3 直接 inherit ITEM；globals.h 映射 /std/equip。
只确认物品家族，不提取装备内容、重量或 dodge 规则。

## 7. POWDER family evidence

[powder.c](../../reference/es2/mudlib/std/medicine/powder.c):3 直接 inherit COMBINED_ITEM；
globals.h 映射 /std/medicine/powder。COMBINED_ITEM 的排除已由 P2F2 批准；本次没有容器/药粉行为推断。

## 8. Symbolic exclusions

仅增加 BULLETIN_BOARD、CHARACTER、EQUIP、POWDER，保留全部原有 symbolic exclusions。
四项均在 ROOM first、第二条继承相应符号、create 设置 short 的输入下验证。

## 9. Exact literal exclusions

EXCLUDED_LITERAL_BASES 仅新增四个精确 path→symbol 项，由30项变34项；既有 lookup 不变。

| Symbol | Exact literal | Symbol result | Literal result |
| --- | --- | --- | --- |
| BULLETIN_BOARD | /std/bboard | PASS | PASS |
| CHARACTER | /std/char | PASS | PASS |
| EQUIP | /std/equip | PASS | PASS |
| POWDER | /std/medicine/powder | PASS | PASS |

八个 case 均 candidate=false、OUT_OF_SCOPE、facts=[]；保留两条 authored inherit、精确 expression、
source path/hash、byte span/raw、行列、category evidence 与 OUT_OF_SCOPE finding。

## 10. No-fuzzy policy

生产继续用 exact dictionary lookup，不使用 /std/ 或 /std/medicine/ 前缀，不作大小写折叠或子类推断。

| Near-match expression | Result |
| --- | --- |
| /std/bboard_custom | PARTIAL / unresolved extra inheritance |
| /std/char_child | PARTIAL / unresolved extra inheritance |
| /std/equip_custom | PARTIAL / unresolved extra inheritance |
| /std/medicine/powder_child | PARTIAL / unresolved extra inheritance |
| BULLETIN_BOARD_CHILD | PARTIAL / unresolved extra inheritance |
| CHARACTER_CUSTOM | PARTIAL / unresolved extra inheritance |
| EQUIP_CHILD | PARTIAL / unresolved extra inheritance |
| POWDER_CUSTOM | PARTIAL / unresolved extra inheritance |

八项保留现有 supported ROOM candidate，不新增四个已知类别；全部有 UNRESOLVED_INHERITANCE finding。

## 11. Global standard-object completeness tests

15项表显式区分 generic-room、specialized-room、non-room-object。
ROOM 正常样例为 EXTRACTED 且保留 short；其余14项逐一断言 exact mapping 并运行 symbol/literal 混合继承，
共28个排除案例。BANK/CLASS_GUILD/HOCKSHOP 不因路径包含 room 而获准入。
另四个 safeguard cases 拒绝：d/ 外路径、仅 literal /std/room、ROOM 宏阴影、missing include。
没有将表转为自动准入；ROOM 字符串路径依然不能代替实际 direct inherit ROOM。

## 12. Read-only authority drift

测试只读取 Inheritable Standard Objects 到 User IDs 之间的节，核对完整16个手写定义及数量。
新增、删除、改名或路径变化将失败，要求复核；SSERVER 明列为本切片未改变策略的辅助定义。
目录/daemon/clonable/F_* 定义不混入表。生产无 globals.h 动态解析或策略生成。

## 13. Version / output security

EXTRACTOR_VERSION **1.0.3 → 1.0.4**；known versions 明列1.0.0/1.0.1/1.0.2/1.0.3/1.0.4。
五版本完整 canonical 输出均通过真实 CLI/os.replace 更新为1.0.4；另核对五版本历史全源输出均被识别。
闭合 schema 校验逻辑和 cli.py 均无改变；未知版本、nested manual metadata、metadata-only 等仍拒绝并保留字节。
五版本×21层×2未知字段=210个 CLI 保全组合通过；另21个 canonical 人工字段拒绝测试通过。

## 14. Focused regressions / preservation

新增 P2F4RegressionTests 六个方法：4 symbols、4 literals、8 near matches、15项 policy、16项 authority drift、
4个 ROOM safeguards。生产修复前这六项产生12个失败子案例（4 symbols、4 literals、4 mapping omissions）。
修复后通过。明确重跑 P2F3 五项：9武器/11防具符号、20路径、完整性/漂移与非模糊边界全部 PASS。
明确重跑 P2F2 七项：MONEY/COMBINED_ITEM 四形式、版本兼容和闭合 schema 全部 PASS。
完整套件继续覆盖 P2/P2F1 confinement、continued macro、unresolved include、computed mapping 等旧边界。

## 15. Complete local verification

Python3.12.14。提交前 fresh results：

| Check | Result |
| --- | --- |
| focused P2F4/P2F3/P2F2 | 6 + 5 + 7 = 18 methods PASS |
| migration suite | 94 PASS（原88） |
| full Python suite | 140 PASS（原134） |
| repository/static | PASS |
| git diff --check | PASS |
| independent nested manual metadata probes | 3 PASS，exit2，writer 未调用，原字节保留 |
| independent protected output target probes | game/reference/docs 全部写入前拒绝，无产物 |

命令：unittest discover -s tools/tests -p test_migration_tooling.py / test_*.py -v、
tools/ci/repository_checks.py --repository .、git diff --check。
提交后重复定向/完整两套 tests、static、origin phase...HEAD diff、全源双跑和完整性验证，通过后才 push。
最终提交 SHA 和 exact-commit 实际结果在最终回复记录，避免文档自引用。

**Godot gameplay canonical suite not required/run for this tooling-only P2F4 slice.**
未运行远端 CI；无 live gameplay 或 packaged-startup 声明。Python 的 mock APK 不是游戏验收。

## 16. Corpus before / after

准确输入 reference/es2/，profile static-room-v1；与 P2F3 1.0.3 输出比较：

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

finding 分布不变：REQUIRES_SEMANTIC_REVIEW1713、OUT_OF_SCOPE1305、UNSUPPORTED_CONSTRUCT484、
DRIVER_SEMANTICS_UNKNOWN410、CALLBACK_BEHAVIOR326、UNRESOLVED_INCLUDE97、RNG_SEMANTICS62、
ORDER_SENSITIVE_MUTATION36、DYNAMIC_EXPRESSION11、SOURCE_ENCODING_ISSUE8、SOURCE_SYNTAX_ERROR5；
UNRESOLVED_INHERITANCE/DUPLICATE_DECLARATION/UNRESOLVED_REFERENCE 均0。

## 17. Changed objects

逐对象字段比较，**变化0**。无 triggering inherit、old/new candidate/status 或 fact delta 可列。
四项缺口是 latent but contract-relevant；当前真实候选没有触发新增排除的混合继承。
计数没有被固定或强制保持一致。

## 18. Quarantine comparison

13条（encoding8、syntax5），与 P2F3 路径/原因完全一致；新增0、移除0、状态或原因变化0。
以下路径相对 reference/es2/mudlib：

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

未改源、未降 quarantine；exit1 是扫描完成且保留真实隔离。

## 19. Determinism

| CLI run | Bytes | SHA-256 |
| --- | ---: | --- |
| A | 10030223 | 237f44fb88600cdd425bd6bf7dbf111dd9faa56c7ebc8291013ece2e65f99e36 |
| B | 10030223 | 237f44fb88600cdd425bd6bf7dbf111dd9faa56c7ebc8291013ece2e65f99e36 |

逐字节相等 PASS。P2F3 同尺寸 hash 为cc793647c1c9d70597276347a62bdd51e556108ddf0f0968b4443ceef10fcb67；
版本变化导致新 hash，不要求旧 hash 相同。输出/日志/验证脚本仅留 ignored build/migration-tooling-v1/p2f4/。

## 20. Source / game immutability

reference tree 保持 `4106480ab28cce8cd7b55704f8ae9ae062d42d03`，physical/tracked 各2336文件，路径集合相同。
repo-relative raw-byte manifest 保持 `744e33e1740db7909129a3ae5e295158341b5012a411af953b144a5075bb0a80`；
source-root-relative manifest 保持 `895d36086e184ba6bf520625c20e882394a0a6169aabf86a1b4c58ba835e2820`。
reference/game/.github/Save/gameplay/config/DECISIONS 与历史报告无改动；保护目录无探针产物。
无生成 corpus 入库、第三方依赖、LPC execution 或 Native generation。

## 21. Historical audit immutability

起始、提交前检查哈希不变；提交后及 push 后再次核对。二者始终 untracked、unstaged，不作 committed links：

| Report | SHA-256 |
| --- | --- |
| MIGRATION_TOOLING_V1_FINAL_AUDIT.md | a61cd221e8b70961d963484dfe953f5e341511967d9cfd66a55159b1bab85d63 |
| MIGRATION_TOOLING_V1_RE_FINAL_AUDIT.md | c67dc612139bf37a6c6a41d4753b58723b154d0f6e92cdca0ab5a34ad93d0548 |

均未编辑、移动、删除、暂存或提交。

## 22. Changed files / commit

仅 tools/migration/room_extractor.py、tools/tests/test_migration_tooling.py、本报告、
docs/production/STATUS.md、docs/production/ROADMAP.md 五个路径。cli.py 和历史 P1/P2/P2F1/P2F2/P2F3 报告无改动。
独立于测试逐项复核 diff：只有四组排除、版本更新、对应验证及状态文档；无运行时架构边界变化。
显式暂存五路径，仅一个 `Complete remaining standard object migration exclusions` 提交。

## 23. Deferred scope

没有 Final/Re-Final Audit verdict、PR、merge、P3、NPC/item/container 内容提取、Native/Godot generation，
没有 general inheritance evaluator、F_* 语义修改、动态 globals policy 或 fuzzy classification。
SSERVER 策略保持原样，第3/12节明确记录其权威定义和授权边界，不作额外排除。

## 24. Owner-review boundary

**P2F4 FIX IMPLEMENTED — AWAIT OWNER REVIEW / FINAL RE-AUDIT NOT YET AUTHORIZED**。
四项授权缺口已修复并局部验证；milestone 仍需 owner review 后另行授权 fresh Final/Re-Final Audit，
尚不具备 PR readiness。未集成 main，无本阶段 PR CI、merge 或 post-merge CI；停止等待 owner review。
