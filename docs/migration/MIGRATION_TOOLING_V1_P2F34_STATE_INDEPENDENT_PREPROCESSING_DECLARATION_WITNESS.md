# Migration Tooling v1 — P2F34

**P2F34 FIX IMPLEMENTED — AWAIT OWNER REVIEW / NEXT FINAL RE-AUDIT NOT AUTHORIZED**

## Authorization and frozen identities

本片仅实现 owner-confirmed FR33-01 / blocking MEDIUM / D2、D6 的授权修复。
P2F33 OWNER APPROVED / CLOSED，FR32-01 在 repair level CLOSED；Final Re-Audit after P2F33 已执行并 BLOCKED。
此前 39 个 semantic blockers 有实现修复；FR33-01 是第 40 个。harness 准备问题不另编 semantic FR。
没有重跑 Final Re-Audit after P2F33，也没有自动开始 after-P2F34 Final Re-Audit。

分支 `phase/migration-tooling-v1`。Fresh fetch 后父 HEAD / origin phase 均为
`41a37ea1c3d69862d6a814a187b7c7483f49eaa2`，subject 为
`Refuse pending preprocessing declarations at reached EOF`。
P2F32 为 `70f83e52b5c478eec4cd2e86831929d16ed54de9`。
main / origin main / merge-base 为 `cd07808cb76147d0b8c0dad9b82d078b49fefe64`。
39 个线性 milestone commits，无 internal merge。恢复预检仅原有两个 candidate 文件 unstaged、index clean；STATUS/ROADMAP 未变，全状态 phase PR 查询为空。

本报告记录完整提交前验收。承载报告的唯一修复提交为 P2F34_SHA，subject 必须为
`Track preprocessing declaration witnesses across name states`，parent 必须为上述冻结 P2F33。
提交后在不可变提交上重新运行全部 required gates，全部通过才允许正常 push。
最终交付记录该 SHA 与 post receipts；不 amend 回填本报告，不用 pre 代替 post 验收。

## Authority and FR33-01

阅读全文 owner-local stopped Final Re-Audit after P2F33，并核验 33,502 raw bytes、SHA-256
`fdb6890f8b1a489bdf1be1266bb28d4ceca45ee40569cc412b3190d65dfe6b5a`、raw Git blob
`b559fc6516453bb180e6393757a9c607c156871b`。它保持 untracked/unstaged/byte-identical。
遵守本会话已读的 root/docs AGENTS、[locked D1–D9](DECISIONS.md#migration-tooling-v1-p2--owner-locked-extraction-boundary)，
对照 [P2F29](MIGRATION_TOOLING_V1_P2F29_UNRESOLVED_DECLARATION_HEADER_REFUSAL.md)、
[P2F30](MIGRATION_TOOLING_V1_P2F30_REACHED_HEADER_EOF_UNRESOLVED_DECLARATION_REFUSAL.md)、
[P2F31](MIGRATION_TOOLING_V1_P2F31_INVOKED_INHERIT_MACRO_DECLARATION_PREFLIGHT.md)、
[P2F32](MIGRATION_TOOLING_V1_P2F32_PREPROCESSING_SENSITIVE_INHERIT_KEYWORD_RECOVERY.md)、
[P2F33](MIGRATION_TOOLING_V1_P2F33_PENDING_PREPROCESSING_DECLARATION_EOF_REFUSAL.md) 的冻结结构边界。
只读 ES2 依据为 [include](../../reference/es2/mudlib/doc/lpc/preprocessor/include)、
[define](../../reference/es2/mudlib/doc/lpc/preprocessor/define)、
[inherit](../../reference/es2/mudlib/doc/lpc/constructs/inherit)、
[function](../../reference/es2/mudlib/doc/lpc/constructs/function)、
[types/general](../../reference/es2/mudlib/doc/lpc/types/general)。

P2F33 已让 pending_declaration 的保留与 EOF 消费独立于 name_state，但实际宏 witness 的创建仍位于
OPEN/UNRESOLVED 路由内部。普通 authored inherit 自身不是预处理使用；它令状态进入 AFTER_NAME。
随后 BASE 或 SELECT(73) 虽已被 existing machinery 判为 actual_macro=True，仍跳过 witness 创建。
未结束的 reached header 到 EOF 返回 None，raw ROOM metadata 先分配，late include fallback 才拒绝。
最终 false/OOS/facts=[]，但 ROOM inheritance/category 残留；没有已证明的 unsafe fact leakage，不升级为 HIGH。

## Owner stop-loss decision and AR-01

本轮是恢复已有 P2F34 candidate，不是新片或 Attempt 2。Attempt 1 按当时要求正确停止，历史 BLOCKED verdict 不改写。
该报告 raw bytes=19,673；SHA-256=`d9296f417c63724f31a0681a917a071f5c299aa90d1d37322e667ae892e50012`；
raw Git blob=`7b784b2143e7e4f86053aabed4600f9ac472fdea`，保持 untracked/unstaged/byte-identical。
旧三次 AR-01 失败执行与不完整 retained run 仅为历史证据，不计本次 acceptance。

Owner 显式冻结后续 Migration Tooling v1 FINAL BLOCKING THRESHOLD：

| Class | Blocking safety defect |
| --- | --- |
| A | 无可靠证据的 candidate false→true，或 unsafe PARTIAL/EXTRACTED admission |
| B | 不可信 fact/exit 创建，uncertain structure 增加 fact/exit |
| C | 没有正面源损坏证据却 QUARANTINED |
| D | source path/SHA/span/raw/line/column 错误，synthetic provenance，ghost/orphan/duplicate/dangling IDs 或错误 manifest/summary |
| E | protected-path write、escape、拒绝时 writer mutation、schema/version/atomic-output/integrity failure |
| F | 冻结 2,336 源语料中危险且未解释的 candidate/status/fact/exit/quarantine/provenance regression |

Synthetic case 若最终 candidate=false、OUT_OF_SCOPE、facts=[]、无新 exit、无 false quarantine、provenance 真实，
且没有危险 real-corpus delta，仅拒绝比理想 shared preflight 晚或保留未被消费的 inheritance/category metadata，
则为 **ACCEPTED CONSERVATIVE RESIDUAL**，不独立阻断，不自动触发下一 P2Fxx。新的真实 A–F 缺陷必须停止，不能自动修复。
既有 FR29–FR33 与历史产品测试的 early-refusal fixed oracles 全部保留；本政策不许可普遍改为晚期拒绝。
DECISIONS.md / D1–D9 原文不修改。

**AR-01 — OPEN declaration directive late-refusal residual：ACCEPTED / NON-BLOCKING。**
Reached header `void\n#pragma strict_types\n` 加 root continuation 会 shared miss、可先分配 raw ROOM metadata，
再由 include fallback 拒绝。独立 literal `mixed` / `#pragma warnings` 变体同样验证。
本轮 room_extractor.py 与 Attempt 1 候选 raw SHA
`dbd01ece60047731499f083fb7a076de87a7cf70c08b5d1577dba082ad0e4ebd` 完全相同；没有 directive repair。

Accepted residual controls **20 CLI / PASS final-safety oracle**，独立于正常 13,634 structural CLI：
两个 literal prefixes × local/nested/standard/cross/nested-cross × LF/CRLF。
每例要求 exit0、false/OOS/facts=[]、无 source quarantine、新 exit 或 admission widening，并验证实际 authored provenance/IDs/summary。
不要求 direct_inherits/category_candidates 清空，不禁止 include_hazards 调用；不计入 early-refusal PASS 数量。
这只证明最终安全，未宣称更早的共享门精度，也未用 implementation 输出生成新期望。

## State-independent creation invariant

当前顶层 authored declaration/statement 中的实际宏/possible invocation 预处理参与，现在在名称/继承路由之前创建或保留 pending_declaration。
条件复用 existing actual_macro 或 directive-separated invocation witness；不借 replacement 解释恢复基类或函数身份。
首个真实 authored token 是 witness，后续实际使用保留它。名称分类不再决定预处理参与是否存在。

修改为将宏 witness 创建从 OPEN/UNRESOLVED 分支移到 token/group/actual-use 判定之后、possible_inherit/name routing 之前。
不是 `AFTER_NAME and inheritance` 的专用补丁；OPEN、UNRESOLVED、AFTER_NAME 都适用。
原 header_macro 仍在其名称分类职责范围内更新；role、inherit predicate、direct proof、hard resets 和 EOF refusal 均保持原规则。

上下文由现有顶层 cursor 及 matched-group skipping 保证：参数、调用内部、函数/nested body、mapping/array 内部不成为顶层 token。
定义存在、未引用 header、未调用的 function-only macro、string/comment/multiline text 不创建 witness。
真实分号、完成的 top-level body、既有直接署名参数/body 证明可以清除它，不跨声明全局粘连。

## Source-derived CREATE / PRESERVE / DISCHARGE table

| Event/token | Top-level context | Name state before | Actual preprocessing evidence | Pending before | Action | Name state after | Pending after | Discharge reason |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Object/function macro | Open declaration slot | OPEN | Actual use / actual call | None/earlier | Record first authored token before routing | Role-dependent | Live | None |
| Actual macro after unknown prefix | Unresolved header | UNRESOLVED | Actual use | None/earlier | Same state-independent creation | UNRESOLVED or immediate refusal | Live | None |
| Actual base or empty suffix | Pending inheritance | AFTER_NAME | Actual use after raw inherit | None/earlier | Same creation; no function-name recovery | AFTER_NAME | Live | None |
| Directive-separated possible invocation | Exposed declaration token | OPEN/UNRESOLVED/AFTER_NAME | Existing invocation witness | None/earlier | Record use before existing conservative routing | Existing refusal/path | Live until refusal/reset | None |
| PREFIX/EMPTY consumption | Incomplete current header | OPEN/UNRESOLVED | Actual macro, if any | Live/None | Existing role cursor advance | Existing state | Preserved | Consumed role is not completion |
| Unknown identifier/punctuation | Exposed unfinished header | OPEN/UNRESOLVED | No new use unless independently detected | Optional live | Existing unresolved-state routing | UNRESOLVED | Preserved | None |
| Ordinary inherit keyword | Clean context | OPEN/UNRESOLVED | No macro use in keyword itself | None under existing predicate | Existing keyword routing | AFTER_NAME | None; later uses may create | Keyword is not a terminator |
| Directive in unresolved header | Current unresolved declaration | UNRESOLVED | Authored directive | None/live | Existing directive witness creation | UNRESOLVED or immediate refusal | Live | None |
| Directive after live prefix | Current pending declaration | OPEN | Existing live macro participation | Live | Preserve; existing routing | Existing state | Live unless later valid proof/reset | Directive alone does not complete |
| Directive in inheritance | Current inheritance | AFTER_NAME | Authored directive | Optional live | Existing inherit-directive immediate refusal | Refused | Not used to recover certainty | No new change needed |
| Literal void/mixed then directive | Unfinished literal prefix at dependency EOF | OPEN | Directive only, no actual macro | None | Shared early gate misses; late fallback refuses | OPEN / late OUT_OF_SCOPE | None | AR-01 accepted final-safety residual |
| Standalone directive | No unfinished exposed header | OPEN | Definition/directive alone | None | Existing handling, no new pending use | OPEN | None | Not participation in a pending declaration |
| Direct identifier(params){body} | Frozen direct complete proof | OPEN/UNRESOLVED | None at literal name; permitted earlier prefix possible | Optional live | Existing unknown-use/header-macro constraints, then clear | FNC then AFTER_NAME | None | Existing direct authored structural proof |
| FNC transition | Proven direct params/body ahead | FNC | No separate source token at transition | None | Existing enum transition only | AFTER_NAME | None | Already discharged by direct proof |
| Real semicolon | Current top-level statement ends | Any | Any earlier participation | None/live | Hidden-inherit check, then reset | OPEN | None | Authored hard boundary |
| Completed top-level body | Matched body ends | Any | Opaque contents ignored | None/live | Existing matched-body reset | OPEN | None | Authored completed body |
| Reached dependency EOF | Unfinished declaration | Any | Live actual witness | Live | Existing unsupported-prefix early refusal | Refused | Live / consumed by refusal | EOF is not discharge |
| Root EOF | Root unit | Any | Optional live | None/live | Existing root handling | Existing outcome | Not newly interpreted | No P2F34 root-EOF policy |
| Opaque nested/group/text | Skipped source interior | Existing state | No exposed top-level use | None/live | Skip under existing contract | Unchanged until existing reset | No new witness | Not a new declaration use |

AFTER_NAME 的两个入口均审阅：普通 inherit 之后仍可有 unfinished declaration 的实际 use；
FNC 只在直接 authored params/body 已证明后进入，参数组 opaque，紧接 body 的既有 reset 生效。
因此用现有结构边界划分生命周期，不以 enum 标签屏蔽创建，也没有另一套 return-type/name grammar。

## Directive and direct-proof review

UNRESOLVED directive 原本创建 witness，保留不变。OPEN 已实际使用 EMPTY/PREFIX 时已有 live witness，directive 不会丢失它；
没有当前 pending 结构的独立 directive/definition 不创建 witness。AFTER_NAME 来自 inherit 时，existing inheritance witness
立即触发 inherit-directive refusal；来自 FNC 时 params/body 是 directly adjacent，directive 不能藏在两个暴露 token 之间而仍满足该 proof。
参数组内部仍 opaque。没有为了统一形式而修改已经可靠的拒绝路径。
例外 AR-01：literal void/mixed 后 directive 的 OPEN 路径未建立 pending witness，仍由晚期 include fallback 安全拒绝；owner 明确接受并禁止本轮修复。

直接完整 helper、TYPE prefix + 完整 helper、body reset 后 ordinary inherit/safe statement、body 内宏文字、
body 后新 pending actual macro 均分别验证。合法 proof/reset 可以清除旧 witness，后续新声明实际 use 可以建立新的 witness。
宏摘要不是执行，function continuation 不是参数复用，source units 不拼接。

## Pre-fix reproduction and exact FR33 replay

Attempt 1 编辑前先冻结专用 fr33-prefix-oracles：BASE primary、独立 ANCESTOR object、标准 include SELECT function，各 LF/CRLF，共六次 historical real CLI。
历史证据确认 actual_macro=True/AFTER_NAME/pending=None、shared miss、raw inherit 与 late include 调用、false/OOS/facts=[]、ROOM metadata 残留。
保存普通 wrappers、独立 fail spies 与实际 line/state/exception traces；修复前次数不计正式修复后验收。

修复后六例全部 exit0、false/OOS、direct_inherits/category_candidates/facts=[]，共享 early refusal，无 quarantine。
新状态轨迹确认 AFTER_NAME 中实际宏 token 建立 witness，reached EOF 返回 unsupported-prefix。

| Exact stopped-audit family | CLI | Repaired result |
| --- | ---: | --- |
| Object BASE at reached inheritance EOF, five layouts × LF/CRLF | 10 | Early refusal |
| Function SELECT(x), same layouts | 10 | Early refusal |
| ROOTBASE→ALIAS, same layouts | 10 | Early refusal |
| Empty ERASE suffix after literal path, same layouts | 10 | Early refusal |
| Four complete root counterparts with semicolon | 8 | Exact parent retained |
| Four genuine root EOF counterparts without terminator | 8 | Exact parent QUARANTINED/exit1 retained |
| Completed reached inheritance with local semicolon | 10 | Exact parent retained |
| Unreferenced pending header | 2 | Exact parent retained |
| Total | **68** | **PASS: 40 former failures closed, 28 controls retained** |

Source/oracle 从 stopped audit exact 68-case evidence 转换，未根据修复后结果改写。
五布局为 local、nested、standard、cross、nested-cross。
FR32 64 + FR31 64 + FR30 76 + FR29–FR32 common48 = **252 fresh closure CLI PASS**，计入 retained，不重复计数。

## Independent state, inheritance, directive and opaque matrices

新 state matrix **832 CLI**：PREFIX、EMPTY、SET、CREATE、HELPER/NONCRITICAL、UNKNOWN、competing、aliases 八类；
object-like/function-like 实际使用；OPEN、unknown-prefix UNRESOLVED、raw-inherit AFTER_NAME、authored-name 后未结束 header；
五种依赖布局与 LF/CRLF。另含各 role 的 sequential actual uses，覆盖不同名称状态。
oracle 仅依赖实际预处理参与及未结束结构，不推断 BASE/ROLE 的运行时含义。

新 control/directive matrix **358 CLI**：root + reached layouts、same-unit inheritance semicolon、无宏 literal inherit、
direct proof、body reset 后声明/宏 suffix、定义-only、未调用函数宏、standalone directives、inheritance directive、
directive-separated possible invocation、opaque function/nested bodies、parameter groups、mapping、array、string/comment/multiline text。
Required refusal 与 exact-parent control 在执行前区分；没有扩大候选、自动接受或放宽历史 product tests。

准备阶段源码复核将六个尚未执行的 TYPE + directive + direct helper controls 归为 exact-parent：既有 OPEN/direct-proof 规则允许这种证明。
变更发生在 controls34 的任何执行前，并保存 pre-execution-review；没有根据运行结果改期望。
同步该 ignored generator 时一次未指定 UTF-8 的读取触发 Windows GBK decode error；修正读取编码后完成，不影响 product/source 或 semantic gates。
这些准备问题不是新的 semantic FR。正式运行的所有 oracle 均保持冻结。
本次恢复的新验证目录初次未复制 expanded-cases.json，lower 组在 nested_matrix 加载输入时 FileNotFoundError，尚未执行该组 probe。
补齐七份历史 cases/families 文件并校验字节一致，保存不完整 lower 收据；完整 lower 组从首例重跑，不复用部分结果。
这是 harness 准备失败，不是产品安全缺陷；未改变实现或期望。其他独立组继续使用本次 fresh 完整执行。
补充说明写入脚本一次使用默认 GBK 读取含中文草稿失败；明确 UTF-8 后完成，未影响测试执行或产品文件。

## Decision order, provenance and no-widening

Required-refusal cases 独立禁止四条 downstream 路径：inherit_keyword_preprocessing_use、include_hazards、create_body、fact。
因此证明 early refusal 发生在原始 ROOM metadata、late fallback、create processing 和事实分配之前，不只是最终 JSON 相似。
Dependency findings 锚 root-authored include，逐项核验 root source path/SHA、exact raw byte span、line、Unicode column，含中文前缀及 LF/CRLF。
没有 header offset 套给 root，没有 replacement-derived token/span。

每个 synthetic CLI 对象与精确 P2F33 parser 比较，禁止 candidate false→true、OOS→supported、新 fact/exit、新 quarantine。
允许差异仅为真实 unfinished top-level preprocessing witness 对应的 conservative earlier refusal / metadata clearing。
AST 独立比较仅一个既有方法变化：RoomExtractor.preprocessing_admission_structure_use，另更新版本常量；无新增实现方法。
role classifier、macro effect、pairing、inherit predicate、create-tail、mapping、key classifier、exit finalizer、lexer、CLI/writer 与 schema 不变。

## Retained CLI and product tests

每轮正式验收：retained **12,370 CLI** + new P2F34 **1,264 CLI** = **13,634 CLI**。
New = primary6 + exact68 + states832 + controls358。
开发阶段 1,264 CLI 和 migration556 使用版本 1.0.33，仅作开发验证，不计正式 pre/post totals。
正式 pre 与 immutable post 分别使用独立目录重新生成输入、实际调用 CLI，不复用执行结果。

本片共新增 **18** 个 contract-level 产品测试（原 16 项，加 AR-01 最终安全性 2 项）。focused18、combined129（P2F22/P2F26–P2F34）、migration558、full Python604，
全部 PASS、零失败、零 skips。没有删除历史方法或放宽语义断言；历史测试变化仅增加版本 1.0.34 的覆盖和版本断言。
repository/static、git diff --check、Markdown links/anchors/whitespace、scope/evidence/integrity 均通过。
纯静态 parser/tooling 修复无 Godot live gameplay 验收项，不声称 live runtime 或 remote CI。

## Version compatibility and output security

extractor_version=**1.0.34**，KNOWN=1.0.0–1.0.34 共 **35**；schema_version=1、profile=static-room-v1 不变。
35 个完整 canonical version documents 均通过真实 CLI replacement；只使用副本，历史原件 bytes 不变。
manual/reviewed/future/unknown/malformed/empty 及全部 **33 nested dictionary pollution positions** 拒绝：
exit2、writer 不调用、目标 raw bytes 不变。

独立安全矩阵及完整产品套件覆盖 protected repo/source/reference/game/docs、absolute/relative escape、ancestor traversal、
external tracked checkout、approved build/external output、read/schema/atomic replace failure、invalid UTF-8 raw_hex。
另有七项独立 failure-route probes，明确验证 output symlink/junction、read/schema/internal failure、atomic replace 与 invalid destination；
拒绝前 writer 不调用，atomic replace 失败保留旧字节且无 temp residue。
symlink/junction 为 mocked 分支验证，不声称原生 OS link qualification；CLI/writer 未修改。

## Corpus A/B and exact-parent semantic projection

两个 fresh whole-corpus real CLI 均 exit1，逐字节一致：

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

A/B SHA-256：`d997dd7a4825a6e6f47fba0da97333213540062c2c7081209ac5d2c872d0ec81`。
精确 P2F33 canonical 用 commit receipt 和 frozen SHA
`166e5315719f86fa8ba37aef2a7f03a4f016e10bbe2b960e36b6473328a53d67` 绑定；未声称本轮重跑 parent corpus。
新执行完整 projection：仅 extractor_version 变化，affected real paths=[]，0 object/fact/finding/provenance delta。
supported485→485，无新 fact/exit/quarantine。

## Quarantine, ANSI, provenance, IDs and summary

13 历史 quarantine = encoding8 + syntax5，facts=[]，无新增。新读取真实源字节核验原因/span、
NUL/replacement、错误引号、不匹配闭合 token。14 ANSI exclusions 逐项 false/OOS/facts=[]。
这是修复回归证据，不是 Gate B 的完整 quarantine-path certification。

完整 **9,587 provenance** = facts2,736 + findings4,296 + direct inherits1,799 + normalization inputs756。
新核验 source path/SHA、raw/raw_hex、byte span、line/Unicode column、construct/scope/ordinal、normalization、
fact-ID formula、稳定排序、finding refs、manifest、exact summary 和 UNREVIEWED。
ordinal consumer 仅在 fresh A/B producer 完成后执行。无 duplicate/ghost/orphan/dangling IDs、silent truncation 或 auto APPROVED。

## Source immutability, ARCHIVE-01 and evidence preservation

Reference tree：`4106480ab28cce8cd7b55704f8ae9ae062d42d03`。
2336-file raw manifest：`744e33e1740db7909129a3ae5e295158341b5012a411af953b144a5075bb0a80`。
所有非授权 tracked raw bytes 与预检快照一致；source/reference/game/runtime/save/workflow/DECISIONS 无变更。

ARCHIVE-01 **CLOSED**。十份 tracked historical audits 的 worktree/index/HEAD raw hashes 一致。
P2F10：24,417 bytes / 468 CRLF / SHA
`56e1cd0aa0a573bc4a9505fb5df6bd1cfbd0076849a40f6bd4a4420483cb2213`。
Tracked P2F11：`48f07085604905ef3d603474bae86fb028cff9bbc1088a83769eee16babe9155`。
.gitattributes：`b33913bb7279e1ab67762574ab277828a9fd114dae23dceace2f24ae842194d6`。
29 份既有 owner-local evidence 加 Attempt 1，共 30 份，全部 untracked/unstaged/byte-identical，完整冻结表附后。

## Scope, receipts, residual boundaries and owner gate

恰五个授权 tracked files：room_extractor.py、test_migration_tooling.py、本报告、STATUS、ROADMAP。
本次 fresh ignored evidence 位于 `build/migration-tooling-v1/p2f34-resume/`。
原 `p2f34/` 的 fr33-pre-fix-*、development-*、中止的 pre-*、Attempt 1 ledger 保持历史身份，不计本次验收。
新 namespace 的 pre-* / post-* 从头执行，分别记录本次提交前和不可变提交完整验收；generated corpus 不追踪。
最终 acceptance 收据绑定 exact HEAD、代码 hashes、各 gate receipts、corpus 及报告 raw identity。

残余风险：AR-01（LOW，owner accepted，最终安全下的早拒绝精度不足）；bounded parser/macro/include 模型并非完整 driver（MEDIUM，有界范围内接受）；
mocked symlink/junction 与 filesystem TOCTOU 的平台资格限制（LOW，保留）；Gate A/B milestone certification 未完成（仍需 owner gate，不声称全里程碑 PASS）。
仍为 bounded conservative extraction：macro summary 不是执行，separate units 不是 expanded TU；
不添加 LPC grammar，不猜测 inheritance/runtime 行为，不产生 Native output。
FR33-01 仅在 immutable post gates 全部通过并 push 后标记 **IMPLEMENTATION REPAIRED / awaiting owner review**；40 个 blockers 的实现修复不等于 fresh milestone certification。
Gate A 仍 **BLOCKED / INCOMPLETE**，Gate B 仍 **NOT STARTED / INCOMPLETE**。
没有下一次 Final Re-Audit、PR、merge、P3 或另一修复片授权。Milestone 尚未集成 main。
只有 immutable post-commit 全门通过才正常 push，然后停止等待 owner review。

**P2F34 FIX IMPLEMENTED — STOP / AWAIT OWNER REVIEW。**

## Owner-local frozen raw hashes

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
| `MIGRATION_TOOLING_V1_FINAL_RE_AUDIT_AFTER_P2F30.md` | `2d5652da91ef9f4ca31bb31c1f6230b37a6c7ae34f674ce5c4174c8d5d7ba419` |
| `MIGRATION_TOOLING_V1_FINAL_RE_AUDIT_AFTER_P2F31.md` | `88f1cd583e75c488a64ad4d5d27034317674e8938f785a75218f3ab9acb5e64b` |
| `MIGRATION_TOOLING_V1_FINAL_RE_AUDIT_AFTER_P2F32.md` | `86fecf8853e11275f9bfe2beef13657ddeb80e3fe4c1f68f5e7b2cc3fb380499` |
| `MIGRATION_TOOLING_V1_FINAL_RE_AUDIT_AFTER_P2F33.md` | `fdb6890f8b1a489bdf1be1266bb28d4ceca45ee40569cc412b3190d65dfe6b5a` |
| `MIGRATION_TOOLING_V1_P2F34_STATE_INDEPENDENT_PREPROCESSING_DECLARATION_WITNESS_ATTEMPT1_BLOCKED.md` | `d9296f417c63724f31a0681a917a071f5c299aa90d1d37322e667ae892e50012` |

## Tracked archive frozen raw hashes

| File | Raw SHA-256 |
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
| `MIGRATION_TOOLING_V1_FINAL_RE_AUDIT_AFTER_P2F11.md` | `48f07085604905ef3d603474bae86fb028cff9bbc1088a83769eee16babe9155` |
