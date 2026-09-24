# Migration Tooling v1 — Final Re-Audit after P2F4

2026-09-15。**BLOCKED — NOT READY FOR PR。已确认 HIGH blockers = 1。**

## 1. Executive verdict / stop boundary

独立 adversarial 检查确认新缺陷 FR-01：块注释前缀使关键预处理指令不被识别；在已出现 direct ROOM 后，
setter macro 阴影仍输出 room facts，甚至标为 EXTRACTED。相同根因可绕过条件编译准入检查。
这违反 D2/D3/D6 的可靠准入、无阴影 create/set 与不评估预处理条件的边界。
owner 明确要求发现任何实质缺陷即停止，不在本审计修复。故终止后续全里程碑验收，不给出 PASS。
本报告仅为新的 local/untracked BLOCKED 证据；不更新 STATUS/ROADMAP，不 commit/push，不创建 PR。

## 2. Frozen identities

| Identity | Verified value |
| --- | --- |
| Repository / branch | Toxicccxz/eastern-stories-godot / phase/migration-tooling-v1 |
| main / origin main / merge-base | cd07808cb76147d0b8c0dad9b82d078b49fefe64 |
| executable HEAD / origin phase | 820d478587fd69d3cf20c861e2694497eac8ef79 |
| Initial tracked worktree / index | clean / clean |
| Initial untracked | 仅两份指定历史 BLOCKED 审计 |
| Phase PR | all-state search returned none |
| Audit commit | 无；BLOCKED 分支不提交 |

fetch 后身份一致；main 后恰好7个阶段提交。无 reset/rebase/merge/stash/clean/amend/force-push。

## 3. Seven-commit history

| SHA | Subject |
| --- | --- |
| 0e5ff6a5cbc8d4091102e280c66868ba8763b4bb | Analyze Migration Tooling v1 extraction contract |
| 8108763d6a4ddb3ad2b110200666424f4042e296 | Record Migration Tooling v1 P2 decisions |
| 8efc21ff8aa4c4c293347386f951631c56559fe2 | Add Migration Tooling v1 static room extractor |
| 1adb6534d579c5a2c1a4d21e166fb244096daa57 | Fix Migration Tooling v1 audit blockers |
| 864ebc4c8a749f3e56a39cd5cf0685b07765fd00 | Fix Migration Tooling v1 re-audit blockers |
| c0c7ffb3de3e26cadf395772f7503e71d3690e11 | Complete weapon and armor migration exclusions |
| 820d478587fd69d3cf20c861e2694497eac8ef79 | Complete remaining standard object migration exclusions |

## 4. Full diff scope

main...executable HEAD：**17 files，+4009 / -11**。本地 untracked 审计不计入。

| Category | Files | Additions | Deletions |
| --- | ---: | ---: | ---: |
| P1/P2/P2F1–P2F4 analysis/reports | 6 | 1867 | 0 |
| DECISIONS/STATUS/ROADMAP | 3 | 103 | 11 |
| tools/migration production | 4 | 1020 | 0 |
| migration unittest | 1 | 976 | 0 |
| fixture/golden/README | 3 | 43 | 0 |
| reference/game/CI/config/generated corpus | 0 | 0 | 0 |

## 5. Owner state / documentation

P1/P2/P2F1/P2F2/P2F3/P2F4 OWNER APPROVED / CLOSED；D1–D9 LOCKED。
两个旧审计保持历史 BLOCKED。本次 Final Re-Audit 获授权但新发现导致 BLOCKED。
旧阶段报告中的 await-review 是历史记录；本报告不回写它们，也不将 owner 已接受的修复说成未实施。
PR/merge/P3 未授权。STATUS/ROADMAP 保持审计前内容，不写 PASS。

## 6. FR-01 / HIGH — comment-prefixed directive bypass

相关代码：

- [es2_source.py](../../tools/migration/es2_source.py):129：仅当原始行内 # 前面全为空白才产生 directive token。
- [room_extractor.py](../../tools/migration/room_extractor.py):314–352：hazard/conditional 检查依赖 directive token。
- 同文件:410–419：函数识别可把未识别的 #define/#if 前缀吸收进 create 的 declaration prefix。
- 同文件:467–476：未记录 setter hazard 时执行静态 create/set 提取。

lexer 虽然跳过块注释，行首检查仍看含注释的原字符串。# 因此前进为 punctuation，未交给 directive_parts。
随后结构解析没有将该未知前缀保守阻断；不是仅漏一条 warning，而是输出不应输出的精确事实。

最小复现 A：

```c
inherit ROOM;
/* audit */ #define set(key,value) ignored(key,value)
void create(){set("short","must not extract");}
```

真实 CLI：**exit0、supported_candidate=true、EXTRACTED**，输出 inherit 与
short="must not extract"，short classification=EXACT_LITERAL；无 macro/unsupported finding。
只有既有 inheritance REQUIRES_SEMANTIC_REVIEW。把注释前缀去掉的对照则正确不输出 short，状态 PARTIAL。
因此是本实现对于语义相关预处理上下文的识别差异，不需要执行任何 LPC 来复现。

最小复现 B：

```c
inherit ROOM;
/* audit */ #if FLAG
void create(){set("short","must not extract");}
/* audit */ #endif
```

真实 CLI：**exit0、supported_candidate=true、PARTIAL**，仍输出 short。
没有识别条件编译，只有末尾 unknown construct 的 UNSUPPORTED_CONSTRUCT，不能替代 D2 的拒绝准入。
即使特定 driver 对这种前缀有不同接受规则，工具也不能把未理解的 # 指令当成可靠 create 前缀并输出 EXTRACTED；
应保守保留不确定性，而非跨过已锁定的宏/条件保护。

LF/CRLF 各运行 A/B，共**4个真实 CLI 复现全部触发**。四者 directive_tokens=[]，# 均为 punctuation。
原始源码、输出 facts/findings 和 token evidence 保存在 ignored
build/migration-tooling-v1/final-re-audit-p2f4/blocker-reproduction.json。
输入/输出使用独立外部 TemporaryDirectory，退出后自动清理；无保护目录试写。
当前 reference 的同类行形状搜索无匹配；属于 latent but contract-relevant 缺陷，不声称已有真实语料被误迁移。

## 7. D1–D9 assessment

| Decision | Current audit evidence / disposition |
| --- | --- |
| D1 | 已读四个生产模块，Python stdlib-only；无 Godot/LPC/第三方 runtime 依赖 |
| D2 | **BLOCKED**：FR-01 条件上下文仍 admitted |
| D3 | **BLOCKED**：FR-01 setter macro 阴影仍输出 short |
| D4 | 当前 schema1/static-room-v1、独立 IR；套件通过，但完整独立输出审计因 stop 未完成 |
| D5 | 既有 CRLF/Unicode/raw provenance 回归通过；全源逐条独立验算未执行，不宣称最终 PASS |
| D6 | **BLOCKED**：无 LPC 执行，但 FR-01 对宏/条件上下文作不可靠静态事实判断 |
| D7 | 既有保护目录攻击回归通过；计划新增第四目录独立矩阵未完成 |
| D8 | unittest、手写小 fixture/golden 与分类表、只读 authority drift；无自动接受快照 |
| D9 | 回归包含退出码/完整性/替换保护；本次恶例 exit0 是未隔离输出，不是独立退出码定义错误 |

未完成项标为未完成，不用历史证据填充本次独立 PASS。

## 8. Historical blocker matrix

| Finding | Original severity | Fresh regression / final audit status |
| --- | --- | --- |
| output target confinement | HIGH | 既有 exploit 回归 PASS；扩展独立复核未完成 |
| continued critical macro shadow | HIGH | 原续行矩阵 PASS；宏/条件总体保护被新 FR-01 阻断 |
| literal excluded base | MEDIUM | 原回归 PASS |
| unresolved include admission | MEDIUM | direct/transitive 回归 PASS |
| computed mapping classification | MEDIUM | balanced/malformed 对照回归 PASS |
| nested manual metadata overwrite | HIGH | 五版本嵌套保全回归 PASS；新独立递归矩阵未完成 |
| MONEY/COMBINED_ITEM | MEDIUM | 四形式回归 PASS |
| weapon/armor completeness | MEDIUM | P2F3 五方法回归 PASS |
| remaining globals completeness | MEDIUM | P2F4 六方法回归 PASS |

这张表区分已实际重跑的旧复现与尚未完成的独立复核；不以总体测试绿给出全部最终 CLOSED 结论。

## 9. Output confinement

已读 destination/atomic_write；原 tests 的绝对/相对 game/reference/docs 目标攻击均通过。
本次发现 FR-01 后未继续扩展为四目录独立探针矩阵。没有覆盖保护路径或留下探针文件。

## 10. Continued macros

原 ROOM/set/__DIR__/create、undef、split identifier/keyword、LF/CRLF 回归均通过。
FR-01 发生在进入 directive_parts 之前；不能因为 splicing 测试通过就认定所有预处理入口都可靠。

## 11. Literal bases / includes / computed mappings

exact-base lookup 仍为固定 mapping，新增四项/武器防具均保留。原 NPC literal、direct/transitive missing include、
mapping 加法/嵌套/ternary/RNG/closure/computed-key/colon-bearing 与 malformed 对照测试全部通过。
本次不改变其实现，也不因新 FR-01 否定这些已通过的具体案例。

## 12. Nested metadata / versions

已读 shared validate_document、canonical、recognized_output。闭合字段与 conditional shape 检查仍存在。
本次全套运行覆盖1.0.0–1.0.4 canonical replacement、五版本×21层×2字段=210保全组合，
未知版本、metadata-only、reviewed、manual、manifest/summary、typed shape、tracked target 回归通过。
独立于既有 tests 的全层注入矩阵未完成，不能称为本次独立再验证已全部完成。

## 13. MONEY / COMBINED_ITEM

两符号/两路径与 ROOM 混合继承均由 fresh regression 验证排除；相似路径不猜测。

## 14. Weapon / armor

P2F3 fresh regression 覆盖9 weapon+11 armor symbols、20 exact literals、手写映射、两头文件 drift、
6 near matches。全部通过。生产无路径前缀分类，未把 F_* 或 TYPE_* 自动加入 object policy。

## 15. Globals table

P2F4 fresh regression 覆盖四新增基类的八形式、8 near matches、15 classified definitions、
完整16-definition authority drift、ROOM safeguard。全部通过。新发现不涉及新增排除项遗漏。

## 16. SSERVER assessment

本次重新读取 std/skill.c 与 std/sserver.c。前者明确是 skill daemon skeleton，定义 valid_learn/type/
perform/cast 等接口；后者仅继承 F_CLEAN_UP 并提供 offensive_target，未继承 ITEM/NPC/SKILL。
源码搜索找到19条 inherit SSERVER（含非.c 的 d/force/recover.d）；位置在 daemon/class 和 d/force。
这些证据支持将其作为明确的 helper semantic-review residual，而不是仅因名字在 globals 就新增对象类别。
未发现足以把 SSERVER 本身认定为新 D2 对象类别的证据；新语料 candidate 独立交叉核对因 stop 未完成。
本次 blocker 是 FR-01，不是 SSERVER 未在 denylist。

## 17. Lexer / provenance

已读 lexer/pairs/literal/Source.span，检查发现 FR-01 原始行前缀与 token 上下文不一致。
既有 invalid UTF-8、NUL/replacement、Unicode、CRLF、续行 offset 回归通过。
没有完成本次全源所有 provenance 的 byte/hash/line/column/ordinal 独立校验，保持 PENDING。

## 18. ROOM / create / set

comments/string/heredoc、roommaker、d/ 范围、literal /std/room、不间接推断、重复 create、setter function
shadow、嵌套控制/receiver/callback 的既有回归通过。但未知预处理前缀被识别成 create 声明的一部分，
导致 FR-01；此边界未满足最终可靠性要求。

## 19. Text / flags

literal short/name/long TEXT_ONLY、explicit zero、absent、large decimal string、macro/arithmetic 保守处理
的既有测试通过。FR-01 的错误是产生事实的上下文不可靠，不是本次发现字符串值解码错误。

## 20. Exits

现有 ordered duplicate entries、raw target、__DIR__ 窄拼接、normalization、case/missing/ambiguous
描述性引用、static+mutation PARTIAL 的测试通过。没有 reverse/reachability 或 LPC evaluation 代码。
全源规范化 provenance 的独立验算未完成。

## 21. Findings / status

正常实现保留四种 status 与 UNREVIEWED；OOS/quarantine empty facts 回归通过。
FR-01 A 错误给出 EXTRACTED，说明该标签虽不代表语义批准，仍不能作为未理解宏上下文的可靠静态结果。

## 22. Real-source review coverage

fresh suite 读取 roommaker/street1/school1/pine3/keep2/lake 及损坏源并通过既有断言。
本次独立逐源复核未全部完成（包括全部13隔离源的正证据重检）；未将上轮记录复制为本轮新验证。
已独立重读 skill/sserver 并执行 SSERVER 引用搜索。

## 23. Fresh local checks

所有运行均在精确 executable SHA 820d478587fd69d3cf20c861e2694497eac8ef79：

| Check | Fresh result |
| --- | --- |
| migration unittest discover | 94 PASS |
| full Python unittest discover | 140 PASS |
| repository/static | PASS |
| git diff --check | PASS |
| FR-01 real CLI LF/CRLF × macro/conditional | 4/4 reproduced defect |
| no-comment control | correctly suppresses short |
| repository-wide docs/link/anchor audit | 未完成，因 material-defect stop |

日志位于 ignored build/migration-tooling-v1/final-re-audit-p2f4/。
没有修改生产、tests 或 fixture 来产生结果。Python mock APK 不是游戏打包验收。

**Godot gameplay canonical suite not required/run for this tooling-only Final Re-Audit.**

## 24. Whole corpus / determinism boundary

本次 unittest 的 RealSourceTests 实际执行 scan，但没有独立 CLI 全源双跑或保存其完整 metrics。
不提供假冒 fresh 的2336/499/13/2804/4457 或历史 hash。本次 whole-corpus/determinism gate **未完成**。
历史 P2F4 数字和 hash 仍仅是历史证据，可见原 P2F4 报告，不作为此次 PASS 依据。

## 25. Quarantine boundary

未完成全部隔离源的 fresh positive-evidence 独立检查，因此本次不宣称13项 quarantine 全部重审通过。
历史 inventory=8 encoding+5 syntax，未修改任何 lexical/quarantine 实现；源无变化不替代本次验收。

## 26. Source integrity

reference Git tree `4106480ab28cce8cd7b55704f8ae9ae062d42d03`。
本次独立读取 physical2336文件，与 tracked 路径集合相等；repo-relative raw-byte manifest 为
`744e33e1740db7909129a3ae5e295158341b5012a411af953b144a5075bb0a80`，与冻结基线一致。
reference/game/Save/runtime/.github 未写入，外部 temporary probes 已清理。

## 27. Historical audit integrity

开始和结束均核对，保持 untracked/unstaged/unchanged：

| Report | SHA-256 |
| --- | --- |
| MIGRATION_TOOLING_V1_FINAL_AUDIT.md | a61cd221e8b70961d963484dfe953f5e341511967d9cfd66a55159b1bab85d63 |
| MIGRATION_TOOLING_V1_RE_FINAL_AUDIT.md | c67dc612139bf37a6c6a41d4753b58723b154d0f6e92cdca0ab5a34ad93d0548 |

二者不作为 committed artifact 链接，不编辑、不暂存、不提交。

## 28. Security / artifact scope

17文件列表无 binaries、生成全源输出、bulk source copies、user save 或 CI/config 改动。
生产 imports 为 stdlib，subprocess 仅 Git 路径保护；无 LPC execution/Native generator。
repository/static 通过；完整里程碑 credentials/绝对路径/第三方来源逐项独立检查因 stop 未完成。
不得将未完成项描述为最终安全 PASS。

## 29. Documentation consistency

历史审计和修复文档保持原样；本次 owner CLOSED 状态由本报告第5节记录。
不更新 STATUS/ROADMAP 为 PASS，不改 DECISIONS。新报告属于 phase-scoped docs/migration。

## 30. Risks

- **HIGH / material blocker:** FR-01 宏阴影/条件准入绕过，四个真实 CLI 复现。
- **MEDIUM / residual requiring later assessment:** bounded lexer 非完整 LPC grammar、preprocessor uncertainty、
  unsupported valid syntax 的误漏风险；driver/case 语义、SSERVER helper 边界；不能用这些概括性风险降级 FR-01。
- **MEDIUM / operational residual:** output TOCTOU、格式识别非密码学作者认证、reference license/public-release review。
- **LOW / deferred capability:** 约10MB output 的成本、尚无 Native consumer、尚无 PR CI；本身不构成此 blocker。
- 历史真实损坏源码需要隔离；此次隔离正证据复核尚未完成，不给出额外 correctness 保证。

## 31. Required correction boundary

后续修复需 owner 单独授权；本次没有改动任何可执行/测试字节。
应覆盖注释前缀、LF/CRLF、含换行块注释、关键宏/条件指令，并防止未知 # 前缀被吞为可靠 create 声明。
修复策略必须保留原始 provenance、避免预处理执行，不能仅加提示后继续输出不可靠 facts。

## 32. Unfinished required checks

四目录独立 output attack、递归独立 nested metadata injection、全源所有 provenance、全源 CLI A/B、
13隔离源独立正证据、完整代表源重读、完整 docs/link/anchor 与 artifact audit 均需后续重审。
因为 owner 要求 material defect 即停止，未在发现 blocker 后继续执行这些验收步骤。

## 33. Audit changes / no commit

唯一新可见文件为本 local/untracked 报告；其余审计脚本/日志在 ignored build 输出。
tracked worktree/index 保持 clean，HEAD/origin phase 不变。无审计提交、无 push。

## 34. PR readiness

**NOT READY FOR PR**。测试绿不能替代独立发现，也不构成 PR 授权。

## 35. Next owner gate

Owner review FR-01 并决定是否授权下一修复切片；本任务不自行实现修复。
修复完成后仍需新的完整复审，不能把本次未完成检查标记为已通过。

## 36. Final disposition

**MIGRATION TOOLING V1 FINAL RE-AUDIT BLOCKED**

**NOT READY FOR PR — AWAIT OWNER REVIEW**

No PR。No merge。No P3。
