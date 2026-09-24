# Migration Tooling v1 — P2F30

**P2F30 FIX IMPLEMENTED — AWAIT OWNER REVIEW / NEXT FINAL RE-AUDIT NOT AUTHORIZED**

## Authorization and frozen identities

本轮仅修复 owner-confirmed FR29-01 / blocking MEDIUM / D2、D6。
P2F29 已由 owner APPROVED / CLOSED，关闭 FR28-01；其后 Final Re-Audit 已运行并 BLOCKED。
本轮没有重跑该审计，也没有开始下一次 Final Re-Audit。
35 个此前语义 blocker 在实现层已修复；FR29-01 为第 36 个，本报告记录其实现修复并等待 owner review。
不把元数据残留升级描述为事实泄漏，不为测试或 harness 问题另编 FR 编号。

分支 `phase/migration-tooling-v1`；冻结父提交、预检 HEAD 与 origin phase 均为
`95a6366eff47bcd1bb4463e102cdb9a5c7a0a53c`。
父提交 subject：`Refuse preprocessing-sensitive unresolved declaration headers`。
main / merge-base：`cd07808cb76147d0b8c0dad9b82d078b49fefe64`。
fresh fetch 后身份一致，tracked worktree/index clean，全状态 phase PR 查询为空。

本报告记录提交前证据；承载本报告的单一提交为 P2F30_SHA，subject 必须为
`Refuse unresolved preprocessing-sensitive reached-header EOF`，parent 必须为上述冻结 P2F29。
提交后必须在不可变提交上重跑全部门禁才允许 push；最终交付提供其 SHA 和提交后收据。
不通过 amend 回填自身 SHA，不以提交前证据代替提交后验证。

## Authority and root cause

本轮完整阅读 root/docs AGENTS、冻结 Final Re-Audit-after-P2F29、
[P2F29 implementation](MIGRATION_TOOLING_V1_P2F29_UNRESOLVED_DECLARATION_HEADER_REFUSAL.md)、
[locked D1–D9](DECISIONS.md#migration-tooling-v1-p2--owner-locked-extraction-boundary)，并检查相关实现、测试与晚期 include fallback。
原始只读依据为 [include](../../reference/es2/mudlib/doc/lpc/preprocessor/include)、
[define](../../reference/es2/mudlib/doc/lpc/preprocessor/define)、
[function](../../reference/es2/mudlib/doc/lpc/constructs/function)、
[types/general](../../reference/es2/mudlib/doc/lpc/types/general)。

P2F29 在 reached header 内已经保留 DECLARATION_HEADER_UNRESOLVED、unknown-prefix 与实际 preprocessing witness，
但到 authored-unit EOF 时仍返回 None。根与依赖分别扫描，导致共享 gate 丢失依赖的未决状态；
raw inherit 先分配 ROOM metadata，之后才由 include_hazards 拒绝。
已到达 include 的文件末尾不是声明分号或 body reset：后续源码可能仍在 include site 继续该声明。

## Repair contract and ordering

共享扫描器新增 keyword-only `reached_dependency=False`；调用方仅对路径不同于根文件的 reached unit 传 True。
到依赖 EOF 时，只有 unresolved-header 状态、unknown-prefix witness 与实际 preprocessing witness 三者俱存，
才返回既有 unsupported-prefix hazard。既有共享拒绝分支随即清空整个对象 admission metadata；
candidate=false、OUT_OF_SCOPE、direct_inherits/category_candidates/facts=[]、CLI exit0，无 quarantine。

顺序为 separate authored units / bounded macro summaries → shared structure gate →
raw inherit → late include fallback → create extraction → fact allocation。
required-refusal 通过 fail spies 证明后四阶段及 inherit-keyword fallback 均未执行。
根 EOF 默认路径、无 preprocessing 的 fragment、semicolon/body reset 保持原有语义。
宏 SET/CREATE/HELPER/EMPTY/PREFIX/UNKNOWN 摘要均不能抹掉上述未决 EOF 状态。

本修复没有拼接 root/header token、展开 include/macro、替换参数、添加类型白名单、恢复真实函数名或实现 LPC 声明语法。
include_hazards 没有修改；不是晚期清空元数据。AST 自审只发现共享扫描器与 extract_structure 两个既有方法变化；
macro effect、pairing、create tail、mapping、key classifier、exit finalizer、lexer、CLI/writer 均未改。

## Independent reproductions and new acceptance matrix

修复前 STORE 与独立改名 ASSIGN 各 LF/CRLF，共 4 次 real CLI，重新确认 exit0/OOS/facts=[]，
但 shared gate=None、raw inherit 与 late fallback 执行、ROOM metadata 残留。
修复后对应 4 次全部共享早拒绝。修复前执行不计入下列修复后总数。

| Matrix | Fresh real CLI | Result |
| --- | ---: | --- |
| Primary STORE / independent ASSIGN × LF/CRLF | 4 | PASS |
| Six stopped-audit EOF shapes × five reached layouts × LF/CRLF | 60 | PASS |
| Generalized roles / witness ordering / EOF groups | 400 | PASS |
| Negative, complete-declaration, reset and opaque controls | 50 | PASS |
| New P2F30 total | 514 | PASS |

60-case core 覆盖 object-name、function-name、object-params、function-params、empty-prefix、helper-name，
local/nested/standard/cross/nested-cross 五种布局；根 continuation 分别保留独立 authored signature/body。
400 泛化覆盖 SET、CREATE、HELPER、EMPTY、PREFIX、UNKNOWN/competing definitions，对象与函数宏、未知 identifier/punctuation、
宏在未知前缀之前/之后、invocation group/parameter group 到 EOF，以及 directive witness。
50 控制逐对象匹配精确父版本，包括 root vs reached EOF、完整 root/header 声明、未引用危险头文件、literal set、
无 PP fragment、body/semicolon reset、独立 directive、nested/parameter/mapping/array/string/comment lookalikes、
未使用 EOF 定义与普通安全 include。未引用 header 对根结果无影响。

required-refusal 的 finding 沿现有 origins 映射落在真实 root-authored include。
逐字节核验 source path/SHA/span/raw、Unicode column、LF/CRLF line；不把 dependency offsets 用于 root，
不创建 replacement token/provenance。所有输出仍 UNREVIEWED；事实字段使用 schema 的 `exit`。

## Retained structural CLI and no-widening

全部保留历史矩阵新执行 8,504 CLI，加本轮 514，共 **9,018 CLI**；下表为每个家族的新执行计数。
每个 CLI 对象与精确 P2F29 比较，禁止 admission 扩大、新事实/exit、新 quarantine。
历史包装矩阵未发现对象差异；旧 product tests 没有历史语义期望变更，仅更新版本断言。
P2F30 必须拒绝的新增 EOF 用例提前清空元数据，是本轮明确授权的收紧。

| Family | CLI | Result |
| --- | ---: | --- |
| `first_gate` | 6 | PASS |
| `fr24` | 90 | PASS |
| `overrefusal` | 68 | PASS |
| `type_prefix_confirm` | 8 | PASS |
| `alias_prefix_confirm` | 2 | PASS |
| `prefix_ownership` | 316 | PASS |
| `fr25` | 276 | PASS |
| `independent26` | 60 | PASS |
| `expanded26` | 402 | PASS |
| `consolidation26` | 178 | PASS |
| `expanded25` | 320 | PASS |
| `independent25` | 48 | PASS |
| `replay23` | 84 | PASS |
| `expanded24` | 348 | PASS |
| `independent24` | 58 | PASS |
| `dependency24` | 216 | PASS |
| `independent2` | 64 | PASS |
| `prefix23` | 46 | PASS |
| `expanded23` | 98 | PASS |
| `keyword22` | 46 | PASS |
| `expanded22` | 82 | PASS |
| `tail_family` | 72 | PASS |
| `expanded21` | 84 | PASS |
| `key_audit` | 500 | PASS |
| `primary21` | 4 | PASS |
| `grouped_matrix` | 94 | PASS |
| `expanded20` | 294 | PASS |
| `create19` | 270 | PASS |
| `after_primary` | 4 | PASS |
| `fr18_matrix` | 56 | PASS |
| `expanded_matrix` | 110 | PASS |
| `nested_matrix` | 148 | PASS |
| `mapping_matrix` | 156 | PASS |
| `cli_matrix` | 492 | PASS |
| `directive_matrix` | 204 | PASS |
| `delimiter_matrix` | 118 | PASS |
| `replay28` | 89 | PASS |
| `siblings28` | 82 | PASS |
| `identifier29` | 996 | PASS |
| `independent29` | 250 | PASS |
| `absorbing` | 570 | PASS |
| `retained-primary` | 4 | PASS |
| `retained-confirm` | 6 | PASS |
| `retained-preliminary` | 3 | PASS |
| `retained-siblings` | 72 | PASS |
| `retained-expanded` | 334 | PASS |
| `retained-independent` | 52 | PASS |
| `retained-fr26` | 100 | PASS |
| `retained-expanded27` | 282 | PASS |
| `retained-independent27` | 56 | PASS |
| `retained-tightening` | 186 | PASS |

## Product tests, harness review and checks

新增 P2F30 产品测试 11 个方法；P2F27–P2F30 focused 共 53 PASS。
完整 migration **502 PASS**、full Python **548 PASS**，无剩余失败、无 skip。
repository/static 与 git diff --check 通过；文档链接/锚点及五文件范围/保全检查作为提交前最后门禁。
这是纯静态 parser 修复，无游戏运行时验收标准；没有声称 Godot live proof。

首次 focused run 的一个新控制错误地要求 `CUSTOM value` 被 directive 打断后再遇分号仍为 candidate=true。
独立加载精确 P2F29 证明它原已由晚期 include fallback 返回 OOS，shared gate=None；新旧对象完全相等。
因此将新控制改为验证 shared reset 加既有晚期拒绝，保留 ROOM metadata；未改变历史产品期望。
`initial-focused.log` 与 `review-control.json` 保留该审查过程。

迁移旧执行脚本至新 ignored 目录时，缺少 parent_model、before-baseline/expanded-cases 等 fixture 文件导致启动失败；
复制原文件后重新执行。新增 root-corruption 控制还使诊断用 lex/pairs 抛出 SourceError，
已在诊断 harness 捕获，实际 CLI 仍接受固定 PARENT oracle 与 no-widening 断言。
这些是 harness 准备/诊断失败，日志保留；没有修改固定 CLI oracle、autoaccept、覆盖历史报告或历史收据。
中断前已完成的执行和复跑不重复计入 9,018 的验收总数。

## Version compatibility and output security

extractor_version=1.0.30，schema_version=1、profile=static-room-v1 不变；KNOWN 恰为 1.0.0–1.0.30。
31 个真实历史 canonical 文档经真实 CLI replacement 全通过，原始基线文件未改。
fresh security 检查 protected repo/game/reference/docs、绝对和相对形式、external tracked checkout、
approved build/external output、invalid/manual/reviewed/future/malformed/empty document、33 个 nested dictionary positions；
拒绝路径均 exit2、writer 未调用、目标未修改。raw_hex 的无效 UTF-8 输出保持有效。
完整套件另覆盖 ancestor/path escape、read failure、atomic replace failure、symlink/junction mocked branches。
没有声称原生 OS junction/symlink 实测；没有改 CLI/writer/schema。

## Corpus A/B and exact parent semantic projection

在当前修复代码上独立运行两次完整扫描，CLI 均 exit1（既有 13 quarantine）。

| Metric | A | B |
| --- | ---: | ---: |
| Scanned | 2336 | 2336 |
| Supported / PARTIAL | 485 | 485 |
| EXTRACTED | 0 | 0 |
| OUT_OF_SCOPE | 1838 | 1838 |
| QUARANTINED | 13 | 13 |
| Facts | 2736 | 2736 |
| Findings | 4296 | 4296 |
| Bytes | 9808627 | 9808627 |

A/B byte-identical，SHA-256 均为
`cb17688072714e51588951875965e6de446daa9b69d70d7eb73d11a53bcbc7c5`。
对照已冻结且核验绑定精确父提交的 P2F29 canonical（不是本轮重跑父扫描）：
9,808,627 bytes，SHA `8c2f00d2442bb3a0dea840ef009a54195bf0e95c228119c1b696e8daec42b7f0`。
完整语义投影 **仅 extractor_version 不同；0 对象变化**，无 admission/fact/exit 增加，无 finding/provenance 变更。
13 quarantine（8 encoding、5 syntax）逐对象完整相同、facts=[]；核验原始字节与既有 span。
14 ANSI 均 candidate=false/OOS/facts=[]，无新增 quarantine。本轮未进行全 quarantine-path 审计。

## Provenance, identities and summary

全语料核验 **9,587** 个 provenance：2,736 fact + 4,296 finding + 1,799 direct inherit + 756 normalization input。
逐项核验 source path/SHA、byte span、raw/raw_hex、line/Unicode column、construct/scope/ordinal、normalization inputs；
重算 deterministic fact IDs、顺序、finding refs 与 summary。
2,336 文件均唯一代表，无重复/ghost/orphan IDs，无自动 APPROVED，无 silent truncation。

## Source and historical evidence preservation

reference tree：`4106480ab28cce8cd7b55704f8ae9ae062d42d03`。
2,336-file raw manifest：`744e33e1740db7909129a3ae5e295158341b5012a411af953b144a5075bb0a80`。
reference/game/runtime/save/workflow 未改；全体非授权 tracked 原始字节与预检快照逐项比对。
ARCHIVE-01 **CLOSED**：10 份 tracked 历史审计在 worktree/index/HEAD 原始 hash 均不变。
P2F10 为 24,417 bytes / 468 CRLF，hash
`56e1cd0aa0a573bc4a9505fb5df6bd1cfbd0076849a40f6bd4a4420483cb2213`；
tracked P2F11 为 `48f07085604905ef3d603474bae86fb028cff9bbc1088a83769eee16babe9155`。
.gitattributes hash 为 `b33913bb7279e1ab67762574ab277828a9fd114dae23dceace2f24ae842194d6`，历史 -text 例外不变。

以下 25 份 owner-local 历史证据均保持 untracked / unstaged / byte-identical，路径前缀为 `docs/migration/`。

| File | Raw SHA-256 |
| --- | --- |
| `MIGRATION_TOOLING_V1_FINAL_RE_AUDIT_AFTER_P2F11_RERUN.md` | `8fc46327ca954ad0089e3ee4fb496bfe8cfe21f497b43ae77432e76ff2bc170b` |
| `MIGRATION_TOOLING_V1_FINAL_RE_AUDIT_AFTER_P2F12.md` | `a0847fdd481867b45e0c1d0b4b4dfdea7e0995a2bb607130fceeff0d8effc04a` |
| `MIGRATION_TOOLING_V1_FINAL_RE_AUDIT_AFTER_P2F13.md` | `adbdaddd424dcebed66ef0e984969fa7d2a949325c184a944d764950ccf9febb` |
| `MIGRATION_TOOLING_V1_FINAL_RE_AUDIT_AFTER_P2F14.md` | `450a982195d670ac7ebc1c38e7afb88cf9a41d52d1bc574d95e605c5ef90a38e` |
| `MIGRATION_TOOLING_V1_FINAL_RE_AUDIT_AFTER_P2F15.md` | `6de33c7bef47e42c4897d6a52858ca6a4e1a97a357e51b1738ac376bd16d3da8` |
| `MIGRATION_TOOLING_V1_FINAL_RE_AUDIT_AFTER_P2F16.md` | `29ac334bfd5e648e92a3845997e50a6c03cc1ab17a99b6b902f15fdb28f899c0` |
| `MIGRATION_TOOLING_V1_FINAL_RE_AUDIT_AFTER_P2F17.md` | `3e4d4a6c8955cb81da7d236360e43f743cd38610d9cdc20e0c3c3f08e9170703` |
| `MIGRATION_TOOLING_V1_FINAL_RE_AUDIT_AFTER_P2F18.md` | `81335715cec2aaf87ecd55f3e62e91f56e4d27ea81b8fa69640e4c6f55ad8396` |
| `MIGRATION_TOOLING_V1_FINAL_RE_AUDIT_AFTER_P2F19.md` | `3a06d404419551833c4afa2b22afee6ecb58b217b279348f69f5906a910d835f` |
| `MIGRATION_TOOLING_V1_FINAL_RE_AUDIT_AFTER_P2F20.md` | `aaba69dcec9047e4f9ac17c83f19c57053a16048276aa28ce5fb5af464393f3d` |
| `MIGRATION_TOOLING_V1_FINAL_RE_AUDIT_AFTER_P2F21.md` | `af57dadfda71f66015f83ef25e80375ee2326922129fc2f8537dbffa7ad6bdf9` |
| `MIGRATION_TOOLING_V1_FINAL_RE_AUDIT_AFTER_P2F21_RERUN.md` | `1db04d337f0b9a0a7268b704630565616492ff5427d2d8a98fc03ec14589f4e6` |
| `MIGRATION_TOOLING_V1_FINAL_RE_AUDIT_AFTER_P2F22.md` | `8f18f5f0afe438c117554fd35b4f2bcb229c13fd3b6a11db47ec3f3a91372bc9` |
| `MIGRATION_TOOLING_V1_FINAL_RE_AUDIT_AFTER_P2F23.md` | `3bea0358bd4a86f8e0bfc7644248491c247d337b03e913ee638ecf572c3fa3f3` |
| `MIGRATION_TOOLING_V1_P2F24_CRITICAL_FUNCTION_STRUCTURE_PREPROCESSING_CONSOLIDATION_ATTEMPT1_BLOCKED.md` | `eaecb3308a3086f01e1fe2232f9105dc8600e168a60658dd89fc9cad4ed93c71` |
| `MIGRATION_TOOLING_V1_FINAL_RE_AUDIT_AFTER_P2F24.md` | `9766f5c7c65b7dafcd9263d3ddcc00b1156ba9331d123be8cbca865cb2048f7d` |
| `MIGRATION_TOOLING_V1_FINAL_RE_AUDIT_AFTER_P2F25.md` | `58e0e8258bfcbb6c0e07ae15a861121c68cb310b1bb36f7600d53a84844640cc` |
| `MIGRATION_TOOLING_V1_P2F26_MACRO_SUPPLIED_CRITICAL_FUNCTION_IDENTITY_PREFLIGHT_ATTEMPT1_BLOCKED.md` | `7f409e5b5c9e2a1040afba20bdcf1d809c583e5ef934a2848d21bb1fc5ecfced` |
| `MIGRATION_TOOLING_V1_P2F26_MACRO_SUPPLIED_CRITICAL_FUNCTION_IDENTITY_PREFLIGHT_ATTEMPT2_BLOCKED.md` | `af444e4a6022a1a823b1795d41fe4319e15aa4321dc5328e11da54bd8bec13a6` |
| `MIGRATION_TOOLING_V1_FINAL_RE_AUDIT_AFTER_P2F26.md` | `4ce54c97b12f70a450faa0c29f86672e5ecf3e9433c2b85cf52bfdafba65b7f4` |
| `MIGRATION_TOOLING_V1_P2F27_DIRECTIVE_TRANSPARENT_FUNCTION_MACRO_INVOCATION_PREFLIGHT_ATTEMPT1_BLOCKED.md` | `b79c6227c6a5cbce6e6c7ad130c0f0be1bbcea182ccc2f687075287ef40dab83` |
| `MIGRATION_TOOLING_V1_FINAL_RE_AUDIT_AFTER_P2F27.md` | `05ef64ab050959aa23653706a116cbcd1559d1ad94fa5e9b0d1b516bf7235305` |
| `MIGRATION_TOOLING_V1_FINAL_RE_AUDIT_AFTER_P2F28.md` | `217193c0f83909be1274a813738bf0561e22b5bc7a47c659e627b88ef736e1df` |
| `MIGRATION_TOOLING_V1_P2F29_UNRESOLVED_DECLARATION_HEADER_REFUSAL_ATTEMPT1_BLOCKED.md` | `0760be6f9cdab6060863019b20e35d494c0d39128c4c76e4d5797be46a9744dd` |
| `MIGRATION_TOOLING_V1_FINAL_RE_AUDIT_AFTER_P2F29.md` | `dceeec904b909832921de610a4cdd1ea8258c101f63ffa505f25ce69e4d58cb8` |

## Scope, residual boundaries and owner gate

仅五文件：room_extractor.py、test_migration_tooling.py、本报告、STATUS.md、ROADMAP.md。
全部临时证据保留在 ignored `build/migration-tooling-v1/p2f30/`；不追踪生成语料或工作站路径。
提交前/后收据分开，`pre-gate.json` / `post-gate.json` 绑定执行 HEAD 与实现/测试 raw SHA，
对应 corpus、security、compatibility、integrity、docs 收据分别保留。

边界仍为 bounded conservative static extraction：EOF 不确定性宁可拒绝，不证明完整 LPC 合法性；
macro summary 不是 expansion，分离依赖扫描不是 expanded translation unit。
root EOF 与无实际 PP witness 的片段保持既有处理，不能据此宣称其完整语法已验证。
无 Native consumer、无实际 driver 执行、无 Godot runtime 改动。

P2F30 实现验收通过后仍等待 owner review；不是 milestone Final Audit PASS。
Structural-Preprocessing Consolidation Audit：**BLOCKED / INCOMPLETE**。
Systematic Quarantine-Path Audit：**NOT STARTED / INCOMPLETE**。
下一次 Complete Final Re-Audit 需要另行明确授权。
没有 PR、merge、remote CI、P3、Native generation 或下一修复片。
分支保留；main 冻结；本 milestone 尚未集成 main。完成不可变提交全部门禁及正常 push 后 STOP。
