# Migration Tooling v1 — P2F33

**P2F33 FIX IMPLEMENTED — AWAIT OWNER REVIEW / NEXT FINAL RE-AUDIT NOT AUTHORIZED**

## Authorization and frozen identities

本片仅修复 owner-confirmed FR32-01 / blocking MEDIUM / D2、D6。
P2F32 OWNER APPROVED / CLOSED，FR31-01 repair-level CLOSED；Final Re-Audit after P2F32 已运行并 BLOCKED。
38 个此前 semantic blockers 已有实现修复；FR32-01 是第 39 个，不为 harness/attempt 问题另编 semantic FR。
没有重跑已停止的 Final Re-Audit，也没有自动开展下一次 Final Re-Audit。

分支 `phase/migration-tooling-v1`。fresh fetch 后预检 HEAD / origin phase 均为冻结 P2F32
`70f83e52b5c478eec4cd2e86831929d16ed54de9`，subject 为
`Preserve unresolved headers before inherit keyword recovery`。
P2F31 为 `a11863e6694bdb1373961aa76d8c79c559ef8b23`。
main / origin main / merge-base 为 `cd07808cb76147d0b8c0dad9b82d078b49fefe64`。
38 个线性 milestone commits，无 internal merge；预检 tracked/index clean，全状态 phase PR 查询为空。

本报告记录提交前完整验收；承载本报告的唯一提交为 P2F33_SHA，subject 必须为
`Refuse pending preprocessing declarations at reached EOF`，parent 必须为冻结 P2F32。
提交后必须在不可变提交上重跑全部 required acceptance gates 才允许正常 push。
最终交付提供该 SHA 与 post receipts；不 amend 回填本报告，不以 pre 结果代替 post gates。

## Source authority and FR32-01

阅读全文 owner-local Final Re-Audit after P2F32，核验其 30,589 raw bytes、SHA-256
`86fecf8853e11275f9bfe2beef13657ddeb80e3fe4c1f68f5e7b2cc3fb380499`、raw Git blob
`870e655a896f4311a12651ea7f6f441abaae75b1`。
遵守 root/docs AGENTS、[locked D1–D9](DECISIONS.md#migration-tooling-v1-p2--owner-locked-extraction-boundary)，
对照 [P2F29](MIGRATION_TOOLING_V1_P2F29_UNRESOLVED_DECLARATION_HEADER_REFUSAL.md)、
[P2F30](MIGRATION_TOOLING_V1_P2F30_REACHED_HEADER_EOF_UNRESOLVED_DECLARATION_REFUSAL.md)、
[P2F31](MIGRATION_TOOLING_V1_P2F31_INVOKED_INHERIT_MACRO_DECLARATION_PREFLIGHT.md)、
[P2F32](MIGRATION_TOOLING_V1_P2F32_PREPROCESSING_SENSITIVE_INHERIT_KEYWORD_RECOVERY.md) 的既有状态/早拒绝边界。
只读 ES2 依据为 [include](../../reference/es2/mudlib/doc/lpc/preprocessor/include)、
[define](../../reference/es2/mudlib/doc/lpc/preprocessor/define)、
[function](../../reference/es2/mudlib/doc/lpc/constructs/function)、
[types/general](../../reference/es2/mudlib/doc/lpc/types/general)。

header 的 RETURN_TYPE→mixed 实际使用或 RESULT(123)→void 调用消耗后，没有分号、完成 body 或 direct complete proof。
旧 scanner 保留 header_macro/prefix，但 name_state 仍 OPEN；reached EOF guard 仅接受 UNRESOLVED，因而返回 None。
原顺序为 shared miss → raw ROOM metadata allocation → late included-declaration error/fallback → OOS/facts=[]，
ROOM inherit/category 残留。没有已证明的 unsafe fact leakage，不将 MEDIUM 缺陷升级为 HIGH。

## Unified pending-declaration invariant

**OPEN 不等于安全或空声明；UNRESOLVED 也不独占 pending declaration 概念。**
新增局部 `pending_declaration: Token | None`，生命周期独立于 name_state。
它只在当前声明/header 的 actual macro 使用，或 unresolved header 内 directive 使用时创建。
取第一个真实 authored token；不借用通用 prefix 的含义，不因宏定义存在、opaque 内容或未引用 header 而创建。

PREFIX、EMPTY、其他 macro roles、alias 摘要或 name_resume advancement 均不清除 witness。
现有 semicolon、完成 top-level body，以及通过既有 unknown-use/header-macro 约束的直接署名
identifier(signature){body} proof 才清除它。FUNCTION_NAME_CONFIRMED→AFTER_NAME 不另行清除证据；
合法直接证明已经完成清除。普通 inherit keyword predicate 仍排除 active header_macro/unknown_use/prefix/directive，
不会将真实声明预处理参与重新恢复为普通关键字。

reached dependency EOF 只检查 pending witness 是否尚存，不再以单个 enum 值或 unknown_prefix 的存在作为门槛。
命中沿既有 unsupported-prefix / shared pre-segmentation refusal 路径提前拒绝整个对象：
false/OOS、inherits/categories/facts=[]、exit0、无 quarantine，早于 raw inherit、late include、create 与 fact allocation。
根 EOF 仍走既有处理；没有跨文件 token 拼接、macro expansion、参数替换、return-type 推断、类型白名单或新增 LPC grammar。

## State and witness lifecycle

| Event/path | Before state | Witness before | Action | After state | Witness after | Legitimate discharge? |
| --- | --- | --- | --- | --- | --- | --- |
| Actual PREFIX role, consumed 0/1/multiple | OPEN or UNRESOLVED | None/earlier | Record first actual declaration macro; advance authored cursor | OPEN or UNRESOLVED | Live | No |
| Actual EMPTY role | OPEN or UNRESOLVED | None/earlier | Same lifetime; disappearance summary is not completion | OPEN or UNRESOLVED | Live | No |
| SET/CREATE/HELPER/UNKNOWN macro role | OPEN or UNRESOLVED | None/earlier | Record actual use; preserve uncertain header | UNRESOLVED | Live | No |
| Alias, sequential or compatible competing prefix-like roles | OPEN | None/earlier | Preserve first witness through every consumed stage | OPEN | Live | No |
| Directive inside unresolved header | UNRESOLVED | None/earlier | Record/preserve directive or macro witness | UNRESOLVED | Live | No |
| Directive after consumed prefix | OPEN | Live macro | Preserve independently of generic prefix tracking | OPEN | Live | No |
| Existing direct authored function proof | OPEN or UNRESOLVED | Optional live prefix | Clear only inside unchanged direct-name proof condition | FUNCTION_NAME_CONFIRMED | None | Yes |
| Clean inherit keyword recovery | OPEN or UNRESOLVED | None under existing predicate | Existing clean-context keyword handling | AFTER_NAME | None | Existing clean-context rule |
| FUNCTION_NAME_CONFIRMED→AFTER_NAME | FUNCTION_NAME_CONFIRMED | None after direct proof | No additional discharge | AFTER_NAME | None | Already discharged |
| Semicolon | Any | Optional live | Existing hard reset clears witness | OPEN | None | Yes |
| Completed top-level body | Any | Optional live | Existing matched-body reset clears witness | OPEN | None | Yes |
| Reached dependency EOF | Any | Live | Return authored unsupported-prefix hazard | Unchanged | Live/refused | No |
| Root EOF | Any | Optional live | Preserve existing root handling | Unchanged | Unchanged | No |
| Unused definitions / opaque regions / unreferenced headers | Current | None/current | No new declaration witness | Unchanged | Unchanged | Not applicable |

源码审阅覆盖全部 witness 创建、保存、清除路径。所有 OPEN-with-witness 路径均来自 actual EMPTY/PREFIX consumed 分支及其
0/1/多组、对象/函数、别名、顺序使用、兼容竞争定义、指令关联变体；这些路径现在统一受 reached EOF 条件保护。
FNC 仅能由已有直接参数/body 证明进入，AFTER_NAME 来自该证明或无 active declaration witness 的普通继承。
本片不新增其他恢复确定性路径。真实 post-fix trace 确认两个主例仍是 OPEN，但以 live pending token 提前拒绝。

AST 对照冻结 P2F32 仅一个既有方法变化：RoomExtractor.preprocessing_admission_structure_use；没有新增方法。
另更新版本常量。macro effect、pairing、identity classifier、call groups、create-tail、mapping、key classifier、exit finalizer、
lexer、CLI/writer、schema 都不变；不是 late cleanup 或最终 JSON 修补。

## Pre-fix reproduction and exact stopped-audit replay

编辑前 SET primary 与独立标准 include / function-like RESULT / CREATE 样例各 LF/CRLF，共 4 次 real CLI，
重新确认 shared miss、raw inheritance/late include 被调用、false/OOS/facts=[]、ROOM metadata 残留。
独立 method wrappers、fail spies 和 line/state traces 已保存。修复前执行不计入正式修复后验收。

修复后 primary 4 全部早拒绝；原 stopped-audit 60 CLI 的源码与 oracle 保持，40 原失败关闭、20 控制保持行为。

| Exact stopped family | CLI | Result |
| --- | ---: | --- |
| Object TYPE→mixed at EOF, five layouts × LF/CRLF | 10 | Early refusal |
| Function TYPE(x)→void at EOF, five layouts × LF/CRLF | 10 | Early refusal |
| TYPE→NEXT→mixed alias at EOF, same layouts | 10 | Early refusal |
| EMPTY then TYPE at EOF, same layouts | 10 | Early refusal |
| Four complete root-authored counterparts | 8 | Exact parent controls retained |
| Completed TYPE helper body, five layouts | 10 | Exact parent controls retained |
| Unreferenced prefix header | 2 | Exact parent control retained |
| Total | 60 | PASS |

FR31/P2F32 原 closure 64 CLI、FR30 closure 76 CLI，共 140，全新保留；计入 retained 11,038，不重复计数。

## Independent pending-state matrix and controls

新 980 CLI pending matrix 在执行前固定 oracle，覆盖 PREFIX、EMPTY、SET、CREATE、HELPER/NONCRITICAL、UNKNOWN、
competing definitions、prefix/empty alias chains；object/function-like、0/1/multiple authored groups、sequential uses、
literal incomplete identifier、punctuation incomplete header、macro-before/after-unknown、directive-associated pending evidence。
local/nested/standard/cross/nested-cross 五布局和 LF/CRLF 全覆盖。oracle 依据 pending authored declaration，而非宏执行结果。

另 240 CLI controls 覆盖 root EOF、unreferenced header、semicolon/body/direct authored complete proof discharge、
later ordinary inheritance、unused definitions、no-preprocessing incomplete fragments、opaque function/nested bodies、
parameters、mapping、array、strings/comments/multiline text；逐项匹配精确父版本。
没有 indefinite sticky witness，也没有“一切含宏 header 都拒绝”。

FR29–FR32 共性 family 48 CLI：每个历史根因各 minimal primary 和独立 alias，local/standard/nested-cross × LF/CRLF。
共同约束为实际 preprocessing-sensitive pending declaration 不能在真实 hard boundary/direct proof 前静默消失。
原 60-case 内另有 root 与 completed/unreferenced 控制，不将历史 fresh closure 或开发运行重复计数。

## Decision order, provenance and no-widening

REFUSE fixtures 使用相互独立 fail spies 禁止 downstream raw inherit helper、include_hazards、create_body、fact。
依赖 finding 始终锚真实 root-authored include；检查 root path/SHA、exact bytes/span/raw、line、Unicode column，含中文前缀和 LF/CRLF。
没有 dependency offset 套给 root，没有 replacement-derived token/span。

全部 synthetic CLI 与精确 P2F32 parser 比较，禁止 candidate false→true、OOS→PARTIAL/EXTRACTED、新 fact/exit、新 quarantine。
允许的变化仅为真实 pending declaration witness 支持的共享提前拒绝/metadata clearing。
历史 wrapper 的 5,422 CLI 对精确 P2F32 为零对象变化；新修复例仅有带实际 witness 的提前拒绝和 metadata clearing。

## Retained CLI and product tests

每轮正式验收：retained **11,038 CLI** + new P2F33 **1,332 CLI** = **12,370 CLI**。
new = primary4 + exact60 + pending980 + controls240 + common48。
development 的 1,332 CLI 与 migration540 只作开发验证，不计入正式 pre/post 总数。
pre 与 immutable post 使用独立输出命名空间，每轮均重新生成输入并实际调用 CLI。

新增 15 个 contract-level 产品测试，没有删除历史 tests 或放宽无关期望。
focused **15 PASS**；combined P2F22/P2F26–P2F33 **111 PASS**；migration **540 PASS**；full Python **586 PASS**，零失败、零 skips。
repository/static、git diff --check、Markdown links/anchors/whitespace 与 scope/evidence/integrity 均通过。
纯 serializer/parser/tooling 切片无 Godot runtime acceptance criterion，没有声称 live gameplay 或 remote CI。

证据准备时复制了旧 confirmation oracle，同名存在断言在任何新 CLI 前中止；更换为 prefix-confirmation 专用文件名后重新执行四例。
一次准备 trace 读到旧 family oracle，明确不计为 FR32 pre-fix proof；专用 prefix-order-trace 才是本轮原缺陷证据。
PowerShell 不支持 Bash brace expansion 的一次只读搜索未运行，改为正常文件搜索；这些是 harness/命令准备问题，无新 semantic FR。

## Version, compatibility and output security

extractor_version=**1.0.33**；KNOWN 恰为 1.0.0–1.0.33 共 **34**；schema_version=1、profile=static-room-v1 不变。
34 个 canonical versions 均经真实 CLI replacement，输入原件不变。
manual/reviewed/future/unknown/malformed/empty 与全部 **33 nested dictionary pollution positions** 拒绝：
exit2、writer 不调用、目标 raw bytes 不变。

安全矩阵和 full suites 覆盖 protected repo/source/reference/game/docs、absolute/relative/ancestor escape、
external tracked checkout、approved build/external output、read/schema/atomic replace failures、invalid UTF-8 raw_hex。
symlink/junction 为 mocked 分支验证，未声称原生 OS link qualification；CLI/writer 无修改。

## Corpus A/B and exact parent semantic projection

两次独立 whole-corpus real CLI 均 exit1；输出逐字节相等：

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

A/B SHA-256：`166e5315719f86fa8ba37aef2a7f03a4f016e10bbe2b960e36b6473328a53d67`。
精确 P2F32 canonical 通过 frozen hash 与 commit receipt 绑定，SHA
`625d0f5a5c4f7a96bc1d6a41797d8ea63daf639ae7a5d9b4f8658478cd110e98`；未冒称本轮重跑 parent corpus。
新执行完整语义比较：仅 extractor_version 变化，affected real paths=[]，0 object/fact/finding/provenance delta。
supported485→485，无新增 fact/exit/quarantine。

## Quarantine, ANSI, provenance, IDs and summary

13 历史 quarantine 仍为 8 encoding、5 syntax，facts=[]，没有新增。
新读取实际源 bytes，核验既有 reason/span、NUL/replacement、错误引号和不匹配闭合 token。
14 ANSI exclusions 逐项 false/OOS/facts=[]。这是本片回归验证，不是 Gate B 完整 quarantine-path audit。

完整 **9,587 provenance** = facts2,736 + findings4,296 + direct inherits1,799 + normalization inputs756。
新核验 path/SHA、raw/raw_hex、span、line/Unicode column、construct/scope/ordinal、normalization、fact-ID formula、
stable order、finding refs、manifest 与 exact summary；ordinal consumer 在 fresh A/B producer 完成后才执行。
无 duplicate/ghost/orphan/dangling IDs、silent truncation 或 auto APPROVED；记录保持 UNREVIEWED。

## Source immutability and ARCHIVE-01

Reference tree：`4106480ab28cce8cd7b55704f8ae9ae062d42d03`。
2336-file raw manifest：`744e33e1740db7909129a3ae5e295158341b5012a411af953b144a5075bb0a80`。
全部非授权 tracked raw bytes 与预检快照一致；source/reference/game/runtime/save/workflow/DECISIONS 无变更。

ARCHIVE-01 **CLOSED**。十份 tracked historical audit 的 worktree/index/HEAD raw hashes 保持。
P2F10：24,417 bytes / 468 CRLF / SHA
`56e1cd0aa0a573bc4a9505fb5df6bd1cfbd0076849a40f6bd4a4420483cb2213`。
Tracked P2F11：`48f07085604905ef3d603474bae86fb028cff9bbc1088a83769eee16babe9155`。
.gitattributes：`b33913bb7279e1ab67762574ab277828a9fd114dae23dceace2f24ae842194d6`。
28 份 owner-local historical evidence 全部 untracked/unstaged/byte-identical，完整冻结表附后。

## Scope, residual boundary and owner gate

恰五个 tracked 文件：room_extractor.py、test_migration_tooling.py、本报告、STATUS、ROADMAP。
新证据位于 ignored `build/migration-tooling-v1/p2f33/`；历史收据不覆盖，generated corpus 不追踪。
prefix-confirmation/order-trace 是 pre-fix evidence，development-* 不计正式总数，pre-* / post-* 分别记录完整提交前和不可变提交验收。

仍为 bounded conservative extraction：macro summary 不是执行，separate authored units 不是 expanded TU；
不增加 grammar 来恢复候选，不猜测 driver/runtime 行为，没有新 gameplay 或 Native generation。
FR32-01 **implementation repaired, awaiting owner review**。
Gate A 仍 **BLOCKED / INCOMPLETE**；Gate B 仍 **NOT STARTED / INCOMPLETE**。
不得由本片实现 PASS 宣称 complete Final Re-Audit、Gate A PASS 或 39/39 fresh certification。
无 PR、merge、P3、下一次 Final Re-Audit 或下一片修复授权。
只有不可变 post-commit 全门 PASS 才正常 push，main 保持冻结，milestone 尚未集成 main。

**P2F33 FIX IMPLEMENTED — STOP / AWAIT OWNER REVIEW。**

## Owner-local frozen raw hashes

路径前缀 docs/migration/；旧 owner-local 全部未追踪/未暂存。

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

## Tracked archive frozen raw hashes

路径前缀 docs/migration/；旧 owner-local 全部未追踪/未暂存。

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

**P2F33 FIX IMPLEMENTED — STOP / AWAIT OWNER REVIEW。**
