# Migration Tooling v1 — P2F31

**P2F31 FIX IMPLEMENTED — AWAIT OWNER REVIEW / NEXT FINAL RE-AUDIT NOT AUTHORIZED**

## Authorization and frozen identities

本片仅修复 owner-confirmed FR30-01 / blocking MEDIUM / D2、D6。
P2F30 已 OWNER APPROVED / CLOSED；FR29-01 在修复层关闭。
Final Re-Audit after P2F30 已 BLOCKED，本轮没有重跑，也没有开始下一次 Final Re-Audit。
36 个此前语义 blocker 在实现层修复；FR30-01 为第 37 个，本报告记录修复并等待 owner review。
Gate A 仍 BLOCKED / INCOMPLETE，Gate B 仍 NOT STARTED / INCOMPLETE。

分支 `phase/migration-tooling-v1`；fresh fetch 后 HEAD / origin phase / 冻结父提交均为
`4b09419470c55afc0d4ddaca163cf343a8e1a12c`，subject 为
`Refuse unresolved preprocessing-sensitive reached-header EOF`。
main / origin main / merge-base 均为 `cd07808cb76147d0b8c0dad9b82d078b49fefe64`。
tracked/index clean，全状态 phase PR 查询为空。没有重写历史或切换工作区。

本报告记录提交前验收。承载本报告的单一提交为 P2F31_SHA，subject 必须为
`Route invoked inherit macros through declaration preflight`，parent 必须为上述冻结 P2F30。
提交后必须在该不可变提交上重新运行全部门禁才允许正常 push；最终交付提供 SHA 与提交后收据。
不 amend 回填自身 SHA，不以提交前结果代替提交后验证。

## Authority and root cause

阅读 root/docs AGENTS、owner-local Final Re-Audit-after-P2F30 全文、
[P2F30 implementation](MIGRATION_TOOLING_V1_P2F30_REACHED_HEADER_EOF_UNRESOLVED_DECLARATION_REFUSAL.md)、
[P2F29 contract](MIGRATION_TOOLING_V1_P2F29_UNRESOLVED_DECLARATION_HEADER_REFUSAL.md)、
[P2F22 keyword safety](MIGRATION_TOOLING_V1_P2F22_MACRO_SHADOWED_INHERIT_KEYWORD_SAFETY.md) 相关部分、
[locked D1–D9](DECISIONS.md#migration-tooling-v1-p2--owner-locked-extraction-boundary) 及共享 scanner/helper/tests。
原始只读依据为 [include](../../reference/es2/mudlib/doc/lpc/preprocessor/include)、
[define](../../reference/es2/mudlib/doc/lpc/preprocessor/define)、
[function](../../reference/es2/mudlib/doc/lpc/constructs/function)、
[types/general](../../reference/es2/mudlib/doc/lpc/types/general)。

P2F30 已判断 actual_macro，却在 declaration identity 分支另以 `critical.text != 'inherit'` 排除同名实际调用。
其 fallback 仅凭拼写推进 AFTER_NAME，丢失 header_macro / unknown_use 和未决状态。
raw ROOM 元数据因而先分配，late include/macro fallback 才拒绝；已确认 facts=[]，未把缺陷夸大为事实泄漏。

## Repair contract: keyword spelling versus macro ownership

共享扫描器逐 token 统一计算 actual_macro，再形成唯一 inherit_keyword predicate。
对象宏不需要调用列表；函数宏必须有直接署名匹配调用组才成为实际使用。
已有 directive-separated possible-invocation helper 保留不确定性 witness；这类情况走既有早拒绝，不能恢复为关键字。
继承识别、generic identifier 路由和 AFTER_NAME fallback 均使用同一 predicate。
header_macro / unknown_use / direct-name 判断复用 actual_macro，不再重复一套略有不同的调用测试。

因此 `#define inherit(x) set` 加 `inherit ROOM;` 中的函数宏未调用，仍走原有真实继承处理；
`inherit(...)` 实际调用进入普通宏结构路径；对象宏 shadowing 保持 P2F22 的保守拒绝。
不因同名定义存在或未引用头文件而扩大拒绝。没有白名单、保留字语法、宏展开、参数替换、include splicing 或 late metadata cleanup。

AST 与内容自审仅发现共享 scanner 一个既有方法变化，另更新版本常量。
该方法内只有一处 inherit 拼写比较，用于上述 predicate；没有遗留直接按拼写关闭状态的分支。
unchanged hidden-inherit helper 只产生保守拒绝，不恢复函数名或关闭声明状态；下游 raw keyword parser 位于共享 gate 之后。
lexer、MacroSummary、identity helpers、create-tail、mapping、key classifier、exit finalizer、CLI/writer 均未改。

## Fresh reproduction and exact stopped-audit replay

编辑前 SET primary 与独立 BUILD→CREATE alias 各 LF/CRLF，共四次 real CLI：shared=None、exit0、
candidate=false/OOS、facts=[]，一条 ROOM direct inherit 与 ROOM category 留存。
实际 method/line trace 确认 actual_macro=True 时仍进入 AFTER_NAME；reached EOF 也丢失未决状态。
修复后四例全部共享早拒绝，direct_inherits/category_candidates/facts=[]。

原审计 72 CLI 按冻结源码与 oracle 重放，全部通过：

| Family | CLI | Result |
| --- | ---: | --- |
| SET invoked inherit，root + five reached layouts | 12 | Early refusal |
| CREATE invoked inherit，同六布局 | 12 | Early refusal |
| NEXT→STORE→SET alias，同六布局 | 12 | Early refusal |
| reached EOF `function inherit()`，五布局 | 10 | Early refusal |
| renamed WRITE() 控制，六布局 | 12 | Early refusal retained |
| uninvoked inherit(x)，六布局 | 12 | Parent behavior retained |
| literal local set，LF/CRLF | 2 | Inherit-only retained |

此前 34 barrier failures 全部关闭，38 个既有控制保持契约。

## Independent collision matrix, controls and ordering

独立 796 CLI 覆盖十种形式：SET、CREATE、HELPER、EMPTY、prefix alias、set/create alias chains、competing/UNKNOWN、
object shadow 与 object alias；supported/unknown identifier/unknown punctuation prefix、macro-before-name、parameter/call groups、
directive-separated invocation、reached EOF 与完整 body。
root、local、nested、standard、cross、nested-cross，以及 LF/CRLF 均覆盖。

另 208 CLI 按精确 P2F30 控制 oracle 比对：普通继承、未调用函数宏、undef/redefine/conditional、
semicolon/body reset、独立 directive、完整 helper、root EOF、无 PP fragment、nested body、参数、mapping、array、
string/comment 和 unreferenced header。P2F30 的 514 原有 EOF/opaque/control CLI 亦全部保留。
所有 oracle 在运行前固定，没有依据结果 autoaccept 或放宽历史期望。

required-refusal 使用独立 fail spies：inherit_keyword_preprocessing_use（raw-inherit downstream）、
include_hazards、create_body、fact 均不可调用；不是只检查最终 JSON。
真实依赖 refusal findings 锚 root-authored include，并逐项核验 root SHA、span/raw、line/Unicode column。
没有将 header offsets 套给 root，也没有 replacement-derived token/provenance。

## Retained matrices and exact-parent no-widening

每轮正式门禁保留 **9,018 CLI**（P2F30 前 8,504 + P2F30 514），新增 P2F31 **1,080 CLI**
（4 + 72 + 796 + 208），合计 **10,098 CLI**。开发/中断/重复运行不计入此验收总数。
完整保留 P2F30–P2F11 家族及 P2F22；所有 synthetic 输出对精确 P2F30 parser 比对。
禁止 candidate false→true、OOS→supported、新事实/exit、新 quarantine。
授权变化只允许实际 keyword-shaped macro structural witness 导致整对象更早拒绝。
历史 wrapper 集合有 12 个 expanded22 合成用例诊断变化：object cycle、function continuation cycle、competing definitions、invalid definition、parameter-dependent、compound replacement 六形态 × LF/CRLF。每例 actual inherit 宏使用触发 shared unsupported-prefix；旧/新均 OOS、facts/inherits/categories=[]，仅早拒绝诊断改变。逐对象源字节与 witness 保存在 gate 收据。新增主例变化为已授权的早期 metadata clearing。

## Tests and execution receipts

新增 11 个契约级产品测试方法；既有方法没有删除，历史语义断言没有放宽，仅版本断言加入 1.0.31。
P2F31 focused **11 PASS**；P2F22/P2F26–P2F31 combined **84 PASS**；migration **513 PASS**；
full Python **559 PASS**。零剩余失败、零 skips。repository/static、git diff --check、Markdown links/anchors/whitespace 均通过。
本片纯静态 parser，不需要 Godot live gameplay；没有声称 live 或 remote CI。

证据位于新的 ignored `build/migration-tooling-v1/p2f31/`，旧 audit/implementation 输出未覆盖。
`initial-*` 是版本更新前开发验证；`pre-*` 是一次不计入验收的准备中断：版本更新脚本按 Windows 默认 GBK 读取 UTF-8 测试文件失败，
extractor 版本先变而测试/新 runner 的断言未同步，随后错误启动了一批检查，出现旧版本断言失败。
明确 UTF-8 后完成授权版本同步，保留原日志；没有语义 oracle 变更或产品行为修补。
旧 runner 拷贝还遇到同名 confirmation oracle，保留 fresh diagnostic 文件，正式 primary31/replay31 从冻结审计源码另存。
正式 `pre31-*` 在稳定实现/测试字节上完整重跑；`post-*` 必须在单一不可变提交上完整重跑。
补充 ordinal 检查的初版曾错误地要求非 LPC 文档也通过 lexer；对照 scan 的 source-kind 分派后改为验证这些文件没有 facts/inherits/findings，再为全部 9,587 条 provenance 重算序号，结果通过。
所有总数只统计正式完整收据，不双计开发执行。

## Version compatibility and output security

extractor_version=1.0.31，KNOWN 恰为 1.0.0–1.0.31，共 32；schema=1、profile=static-room-v1 不变。
32 个真实历史 canonical 文档经真实 CLI replacement 全通过，历史输入未改。
manual/reviewed/future/unknown/malformed/empty 及全部 33 个 nested dictionary pollution positions 拒绝：
exit2、writer 未调用、目标原始字节不变。
完整 existing output security 覆盖 protected repo/source/reference/game/docs、ancestor、relative/absolute escape、
external tracked checkout、approved build/external、read/schema/atomic replace failures、invalid UTF-8 raw_hex。
symlink/junction 为 mocked 分支验证，没有声称原生 OS 实测。CLI/writer/schema 未修改。

## Corpus A/B and semantic projection

两次独立 whole-corpus CLI 均 exit1，仅包含既有真实 quarantine。

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

A/B byte-identical，SHA-256：`54718462642fcaa1e4222af2fa618e7e7a5fb885d9462222f6019149359bd053`。
精确父 P2F30 canonical 由 frozen hash/commit receipt 绑定，hash 为
`cb17688072714e51588951875965e6de446daa9b69d70d7eb73d11a53bcbc7c5`；未冒称本轮重新运行父语料扫描。
全语义投影仅 extractor_version 不同，**0 object/fact/finding/provenance delta**。
无 supported 增加、fact/exit 增加或新 quarantine。

## Quarantine, ANSI, provenance, IDs and summary

13 个 quarantine 与父版完整相同（8 encoding、5 syntax），facts=[]；重新读取 actual bytes 核验既有原因/span。
14 个 ANSI 排除均 candidate=false/OOS/facts=[]。本片没有 D9 修改，也没有开展 Gate B 系统审计。
全语料验证 **9,587 provenance**：2,736 facts、4,296 findings、1,799 direct inherits、756 normalization inputs。
核验 source path/SHA、span、raw/raw_hex、line/Unicode column、construct/scope/ordinal、normalization inputs，
重算 fact ID formula、排序、finding references、exact summary，2,336 文件完整且唯一。
无 duplicate/ghost/orphan IDs、silent truncation、自动 APPROVED；仍 UNREVIEWED。

## Immutability, ARCHIVE-01 and owner-local evidence

Reference tree：`4106480ab28cce8cd7b55704f8ae9ae062d42d03`。
2,336-file raw manifest：`744e33e1740db7909129a3ae5e295158341b5012a411af953b144a5075bb0a80`。
全部非授权 tracked bytes 与 fresh snapshot 比对；reference/game/runtime/save/workflow/DECISIONS 无修改。
ARCHIVE-01 **CLOSED**：十份 tracked archives 在 worktree/index/HEAD raw hashes 均保持。
P2F10：24,417 bytes、468 CRLF、SHA `56e1cd0aa0a573bc4a9505fb5df6bd1cfbd0076849a40f6bd4a4420483cb2213`。
tracked P2F11：`48f07085604905ef3d603474bae86fb028cff9bbc1088a83769eee16babe9155`。
.gitattributes：`b33913bb7279e1ab67762574ab277828a9fd114dae23dceace2f24ae842194d6`。

26 个 owner-local historical files 全部 untracked/unstaged/byte-identical；新增历史 #26 after-P2F30 原始
24,434 bytes、SHA `2d5652da91ef9f4ca31bb31c1f6230b37a6c7ae34f674ce5c4174c8d5d7ba419`。
完整 hash 清单如下，路径前缀为 docs/migration/。

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

## Scope, residual boundaries and owner gate

五文件限定：room_extractor.py、test_migration_tooling.py、本报告、STATUS.md、ROADMAP.md。
全部生成语料、执行脚本与临时证据保持 ignored；没有生成 Native 内容或追踪工作站路径。
仍是 bounded conservative static extraction，macro summaries 不等于 expansion，分离的 authored units 不等于 expanded TU。
未知 grammar/preprocessor/driver 行为保守拒绝；本实现闭合不等于整个 milestone 被审计通过。

FR30-01：**implementation repaired, awaiting owner review**。
Gate A：**BLOCKED / INCOMPLETE**；Gate B：**NOT STARTED / INCOMPLETE**。
无 PR、merge、remote CI、新 Final Re-Audit、P3、Native generation 或其他修复片。
只有不可变提交全部复验 PASS 才正常 push；main 冻结，分支保留，milestone 尚未集成 main。
完成交付后 **STOP — AWAIT OWNER REVIEW**。
