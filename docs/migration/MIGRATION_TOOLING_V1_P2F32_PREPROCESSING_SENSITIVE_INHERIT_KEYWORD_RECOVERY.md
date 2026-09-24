# Migration Tooling v1 — P2F32

**P2F32 FIX IMPLEMENTED — AWAIT OWNER REVIEW / NEXT FINAL RE-AUDIT NOT AUTHORIZED**

## Authorization and frozen identities

本片仅修复 owner-confirmed FR31-01 / blocking MEDIUM / D2、D6。
P2F31 已 OWNER APPROVED / CLOSED，FR30-01 在修复层关闭；Final Re-Audit after P2F31 已运行并 BLOCKED。
37 个此前语义 blocker 已有实现修复，FR31-01 是第 38 个；实现尝试或 harness 问题不另编语义 FR。
本轮没有重跑该 Final Re-Audit，没有开展下一次 Final Re-Audit。

分支 `phase/migration-tooling-v1`。Fresh fetch 后父提交、HEAD 与 origin phase 均为
`a11863e6694bdb1373961aa76d8c79c559ef8b23`，subject 为
`Route invoked inherit macros through declaration preflight`。
P2F30 为 `4b09419470c55afc0d4ddaca163cf343a8e1a12c`。
main / origin main / merge-base 均冻结于 `cd07808cb76147d0b8c0dad9b82d078b49fefe64`。
预检 tracked/index clean；全状态 phase PR 查询为空。历史保持 37 个线性提交，无内部 merge。

本报告记录提交前完整验收；承载本报告的单一提交为 P2F32_SHA，subject 必须为
`Preserve unresolved headers before inherit keyword recovery`，parent 必须为冻结 P2F31。
提交后必须在不可变提交上重跑全部验收门才允许正常 push；最终交付提供该 SHA 与提交后收据。
不 amend 回填本报告，不以提交前结果代替提交后验证。

## Authority and FR31-01 root cause

已阅读全文 owner-local Final Re-Audit after P2F31，并对照 root/docs AGENTS、
[locked D1–D9](DECISIONS.md#migration-tooling-v1-p2--owner-locked-extraction-boundary)、
[P2F31](MIGRATION_TOOLING_V1_P2F31_INVOKED_INHERIT_MACRO_DECLARATION_PREFLIGHT.md)、
[P2F30](MIGRATION_TOOLING_V1_P2F30_REACHED_HEADER_EOF_UNRESOLVED_DECLARATION_REFUSAL.md) 和
[P2F29](MIGRATION_TOOLING_V1_P2F29_UNRESOLVED_DECLARATION_HEADER_REFUSAL.md) 的状态边界。
只读 ES2 authority 为 [include](../../reference/es2/mudlib/doc/lpc/preprocessor/include)、
[define](../../reference/es2/mudlib/doc/lpc/preprocessor/define)、
[function](../../reference/es2/mudlib/doc/lpc/constructs/function)、
[types/general](../../reference/es2/mudlib/doc/lpc/types/general)。

P2F31 已正确区分同一单元内实际调用的 inherit 宏和普通 `inherit ROOM;` 中未调用的函数宏。
但 reached header 以 `RETURN_TYPE inherit` 或 `RESULT inherit` 结束时，没有本单元内紧邻调用组，
因此 inherit_keyword=True。该名称之前已有实际宏声明 witness，仍被推进 AFTER_NAME；
reached EOF guard 所需的 UNRESOLVED 状态被丢弃。
根单元的 authored continuation 不在该 token 列表中，local absence of call group 不能证明声明已完成。

确认后果是 shared miss → raw ROOM allocation → late include fallback → candidate=false/OOS，
facts=[]，一条 ROOM inherit 与 ROOM category 残留。没有把该 MEDIUM 缺陷夸大为 HIGH fact leakage。

## Repair contract: preserve active preprocessing state

共享 scanner 将可能的 inherit token witness 与可恢复确定性的普通继承 keyword 分开。
`possible_inherit` 保留 P2F31 的 actual-macro / directive-invocation 检查，仅供原有可能继承及指令拒绝路径使用；
它本身不关闭 declaration-name slot。

唯一普通 keyword predicate 另外要求当前 statement/header 没有 header_macro、unknown_use、prefix 或 prefix_directive。
存在这些实际署名 witness 时，keyword-shaped inherit 进入原有 generic unresolved-header 路径，
不能仅凭拼写和本单元缺少调用组恢复为 AFTER_NAME。reached dependency EOF 因而保留并上报结构不确定性。
既有 shared refusal 在 raw inheritance、late include、create 或 fact allocation 前拒绝整对象，
candidate=false、OUT_OF_SCOPE、direct_inherits/category_candidates/facts=[]、exit0，无 quarantine。

可能继承 witness 仍能触发既有 inherit-directive 拒绝，不会因为收紧名称恢复而丢掉此前指令边界保护。
分号、完成的 top-level body 和既有直接署名结构证明保留原有职责；不使用“inherit 必须是首 token”的规则。
无 preprocessing witness 的 literal prefix 不因本片新增拒绝。

没有 cross-file token splicing、include/root concatenation、macro expansion、parameter substitution、return-type 推断、
保留字 grammar 或 type whitelist；没有查看 root continuation 来重建 header 声明。
不是 late include cleanup。CLI/writer、schema、lexer、MacroSummary、mapping、create-tail、property-key 与 exit finalizer 均未改。

## Pre-fix confirmations and exact stopped-audit replay

编辑前 SET primary 和独立标准 include 的 RESULT→function / BUILD→create 样例各 LF/CRLF，共 4 次 real CLI，
重新确认 shared miss、raw ROOM 元数据分配、late fallback、OOS/facts=[]。
正常 method wrappers、独立 fail spies 和两条实际 line/state traces 记录上述顺序；独立 CREATE 例明确从
UNRESOLVED、unknown_prefix/use/header_macro=RESULT 进入 AFTER_NAME。
这些修复前执行不计入正式修复后验收总数。

修复后 primary 4 CLI 全部提前拒绝；原 stopped-audit 的 60 CLI 使用冻结源码/oracle 新执行：

| Family | CLI | Result |
| --- | ---: | --- |
| Known prefix macro → inherit→SET at reached EOF, five layouts × LF/CRLF | 10 | PASS |
| Unknown function + EMPTY macro + inherit→SET, same layouts | 10 | PASS |
| Unknown prefix → inherit→BUILD→CREATE, same layouts | 10 | PASS |
| Prefix aliases → inherit→NEXT→STORE→SET, same layouts | 10 | PASS |
| Renamed WRITE controls | 10 | PASS |
| Complete root-authored counterparts | 8 | PASS |
| Ordinary inherit with uninvoked function macro | 2 | PASS |
| Total | 60 | PASS |

原 40 barrier failures 全部关闭，20 个控制保持契约。
FR30/P2F31 主例与独立例 4，加原 72-case family，共 **76 closure CLI PASS**；计入 retained P2F31 矩阵，未重复计数。

## Independent recovery matrix and controls

新增 **768 CLI** 独立矩阵在执行前固定 oracle。覆盖 PREFIX/mixed、EMPTY、HELPER/NONCRITICAL、SET、CREATE、
UNKNOWN/compound、alias chain、competing definitions，object-like 与 function-like prefix。
分别组合 uninvoked inherit function macro、invoked inherit function macro、object-like inherit shadowing、无 inherit 宏定义。
包括 reached EOF、完整 root continuation、directive-separated structure、local/nested/standard/cross/nested-cross、LF/CRLF。
oracle 是保守结构拒绝，未根据 replacement 执行结果判断真函数身份。

另 **108 CLI** exact-parent controls：普通 inheritance、未调用同名函数宏、undef/redefine/conditional、
semicolon/body/helper reset、standalone directive、无预处理 literal prefix、root continuation、
function/nested body、parameters、mapping/array、strings、comments/multiline text，以及 unreferenced headers。
普通未调用函数宏定义不等于 macro invocation；未引用 header 对根输出零影响。
开发阶段 940 CLI 完整通过后，正式 pre-commit / immutable post-commit 使用独立输出命名空间重新运行。
开发结果不混入正式总数。

## Decision-order spies and provenance

REFUSE fixtures 除最终 JSON 外，检查 shared scanner 的实际命中，并使用独立 fail spies 禁止后续调用
inherit_keyword_preprocessing_use、include_hazards、create_body、fact。
五种依赖布局的 findings 使用 root-authored include，而非 dependency offset；逐项检查 root path/SHA、
exact span/raw、line、Unicode column，含中文前缀与 LF/CRLF。
没有 synthetic replacement token/provenance，也没有把 header byte span 套用到 root。

## Same-decision-class source review

检查 shared scanner 中所有声明状态关闭/恢复点：普通继承 predicate、EMPTY/PREFIX 的 authored cursor、
direct-name proof、FUNCTION_NAME_CONFIRMED→AFTER_NAME、semicolon reset、completed top-level body reset、reached EOF。
只有无 active preprocessing witness 的普通继承允许 keyword recovery；宏 role 摘要仍不能解决未决 header。
direct-name 仍要求既有 authored matching parameter/body 结构及原 witness 约束；opaque groups 不被展开。
hidden-inherit helper 只拒绝，不恢复 certainty；晚期 raw keyword parser 位于 shared gate 之后。
保留可能继承的 directive-hazard witness 不构成名称证明，也不分配元数据。

AST 对照精确 P2F31 仅发现一个既有方法变化：RoomExtractor.preprocessing_admission_structure_use；没有新增方法，
其他方法、顶层函数、imports、MacroEffect/CreateTailEffect 不变，另更新版本常量。
未发现需要超出本授权状态保留契约的修复；这项实现自审不等于 Gate A Final Audit。

## Retained CLI and no-widening

完整保留 **10,098 CLI**（历史/P2F30 9,018 + P2F31 1,080），新增 P2F32 **940 CLI**
（primary4 + exact60 + independent768 + controls108），每轮正式验收总计 **11,038 CLI**。
全部输出与精确 P2F31 parser 比较，禁止 candidate false→true、OOS→supported、新事实/exit、新 quarantine。
只允许真实 preprocessing declaration witness 支持的完整保守拒绝。
历史 wrapper 矩阵与精确 P2F31 为 0 object changes；全部 no-widening 断言通过。新修复例仅有授权的提前拒绝及元数据清空。

## Tests, version and verification

新增 12 个 P2F32 契约级产品测试；历史测试没有删除或放宽。版本断言和历史兼容集合增加 1.0.32。
P2F32 focused **12 PASS**；P2F22/P2F26–P2F32 combined **96 PASS**；migration **525 PASS**；
full Python **571 PASS**，零失败、零 skips。repository/static、git diff --check、Markdown links/anchors/whitespace、
scope/evidence/integrity 检查通过。纯静态 parser 不要求 Godot live gameplay，未声称 live 或 remote CI。

extractor_version=1.0.32，KNOWN 恰为 1.0.0–1.0.32 共 33；schema_version=1、profile=static-room-v1 不变。

## Compatibility and output security

33 个历史 canonical outputs 经真实 CLI replacement 全通过；输入原件未改。
manual/reviewed/future/unknown/malformed/empty，以及全部 33 个 nested dictionary pollution positions 均拒绝：
exit2、writer 未调用、目标原始字节不变。
安全检查与完整套件覆盖 protected repository/source/reference/game/docs、ancestor、absolute/relative escape、
external tracked checkout、approved build/external、read/schema/atomic replace failure、invalid UTF-8 raw_hex。
symlink/junction 为 mocked 分支验证，未声称原生 OS link qualification。CLI/writer/schema 没有修改。

## Corpus A/B and exact-parent semantic projection

两次独立 whole-corpus real CLI 均 exit1；输出 byte-identical：

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

A/B SHA-256：`625d0f5a5c4f7a96bc1d6a41797d8ea63daf639ae7a5d9b4f8658478cd110e98`。
精确 P2F31 canonical 由 frozen raw hash 与 commit receipt 绑定，SHA 为
`54718462642fcaa1e4222af2fa618e7e7a5fb885d9462222f6019149359bd053`；未冒称本轮重跑 parent corpus。
全语义投影只有 extractor_version 变化，**0 object/fact/finding/provenance delta**，affected real paths=[]。
supported485→485，无 candidate/fact/exit 增加或新 quarantine。

## Quarantine, ANSI, provenance, IDs and summary

13 历史 quarantine 完全保持：8 encoding、5 syntax、facts=[]；新读取 actual bytes 检查既有 reason/span 与根源字节。
14 ANSI exclusions 全部 candidate=false/OOS/facts=[]。没有 D9 语义改变，也没有启动 Gate B 系统审计。

完整 **9,587 provenance**：2,736 facts、4,296 findings、1,799 direct inherits、756 normalization inputs。
核验 path/source SHA、raw/raw_hex、span、line/Unicode column、construct/scope/ordinal、normalization inputs；
重算 fact-ID formula、顺序、finding references、manifest 与 exact summary。
ordinal validator 仅在 fresh corpus producer 完成且文件确认存在之后运行。
无 duplicate/ghost/orphan/dangling IDs、silent truncation 或 auto APPROVED；records 仍 UNREVIEWED。

## Immutability, ARCHIVE-01 and evidence preservation

Reference tree：`4106480ab28cce8cd7b55704f8ae9ae062d42d03`。
2,336-file raw manifest：`744e33e1740db7909129a3ae5e295158341b5012a411af953b144a5075bb0a80`。
全部非授权 tracked raw bytes 与 fresh snapshot 一致；reference/game/runtime/save/workflow/DECISIONS 无修改。

ARCHIVE-01 **CLOSED**：十份 tracked historical audit 的 worktree/index/HEAD raw hashes 保持。
P2F10：24,417 bytes、468 CRLF、SHA
`56e1cd0aa0a573bc4a9505fb5df6bd1cfbd0076849a40f6bd4a4420483cb2213`。
tracked P2F11：`48f07085604905ef3d603474bae86fb028cff9bbc1088a83769eee16babe9155`。
.gitattributes：`b33913bb7279e1ab67762574ab277828a9fd114dae23dceace2f24ae842194d6`。

27 份 owner-local historical evidence 全部 untracked/unstaged/byte-identical。
最新 after-P2F31 保持 28,353 bytes，SHA
`88f1cd583e75c488a64ad4d5d27034317674e8938f785a75218f3ab9acb5e64b`。
完整 owner-local frozen table 附后；没有编辑、规范化或 stage 历史 evidence。

## Scope, receipts, residual boundaries and owner gate

恰限五文件：room_extractor.py、test_migration_tooling.py、本报告、STATUS、ROADMAP。
新执行证据位于 ignored `build/migration-tooling-v1/p2f32/`；历史收据未覆盖，generated corpus 未追踪。
confirmation/order-trace 为 pre-fix evidence，development-* 为不计总数的开发验证，
pre-* 为正式提交前收据，post-* 必须绑定唯一不可变 P2F32_SHA。

仍为 bounded conservative static extraction。Macro summary 不等于 expansion，separate authored units 不等于 expanded TU；
未知语法/driver 行为保守拒绝，不靠扩大 LPC grammar 完成本片。没有迁移新 gameplay 或生成 Native 内容。

FR31-01：**implementation repaired, awaiting owner review**。
Structural-Preprocessing Consolidation Audit 仍 **BLOCKED / INCOMPLETE**；Systematic Quarantine-Path Audit 仍 **NOT STARTED / INCOMPLETE**。
不能由本片实现验证宣称 Gate A PASS 或 38/38 final certification。
无新 Final Re-Audit、PR、merge、remote milestone CI、P3 或另一个修复片。
只有全部 immutable post-commit gates PASS 后才正常 push；main 冻结，milestone 尚未集成 main。
**STOP — AWAIT OWNER REVIEW。**

## Owner-local frozen hash table

路径前缀为 docs/migration/；全部保持 untracked / unstaged。

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

## Tracked archive frozen hash table

Worktree / index / HEAD 三处原始字节保持。

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

**P2F32 FIX IMPLEMENTED — AWAIT OWNER REVIEW。**
