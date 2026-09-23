# Migration Tooling v1 — P2F29

**P2F29 FIX IMPLEMENTED — AWAIT OWNER REVIEW / FINAL RE-AUDIT NOT YET AUTHORIZED**

## Authorization / frozen identities

本报告记录 FR28-01 / HIGH / D2–D3 的授权修复及 Attempt 2 验证，不是下一次 Final Re-Audit。
分支为 `phase/migration-tooling-v1`；冻结父提交为 `da817c042520932c0bb95f35c99cb8cb9a20cc12`，
main / merge-base 为 `cd07808cb76147d0b8c0dad9b82d078b49fefe64`。
预检 fetch 后本地与远端 phase 一致，index 干净，全状态 phase PR 查询为空。
没有 reset、restore、stash、clean、amend 或历史重写。

本文件记录提交前的完整通过证据；承载本文件的单一修复提交即 P2F29_SHA。
只有在该不可变提交上重新执行全部验收门并通过后才允许 push；实际 SHA 与提交后收据由最终交付记录。
不得用本报告的提交前结果替代提交后验证，也不得通过 amend 回填自身 SHA。

## Attempt-1 blocked macro-role recovery

Attempt 1 在提交前停止：虽然引入 UNRESOLVED 状态，SET/CREATE 宏角色仍能过早恢复函数名确定性。
其 996 矩阵在 `E-6-0-0` 中断，250 独立矩阵未运行，迁移套件有 41 条失败记录。
本轮按 owner 指令继续原候选，没有丢弃既有实现。原报告已逐字节复制为 owner-local 历史证据 #24：
`MIGRATION_TOOLING_V1_P2F29_UNRESOLVED_DECLARATION_HEADER_REFUSAL_ATTEMPT1_BLOCKED.md`，
SHA-256 为 `0760be6f9cdab6060863019b20e35d494c0d39128c4c76e4d5797be46a9744dd`。
该副本保持 untracked / unstaged；当前 live report 记录本次结果，未覆盖任何历史审计。

## FR28-01 root cause / why arbitrary identifiers cannot close the name slot

旧扫描把不在已知前缀集合中的普通 identifier 当作 NONCRITICAL 函数名。
`function STORE` 中的未知 `function` 因而过早关闭名称位置；Attempt 1 又允许宏摘要 SET/CREATE 恢复该位置。
宏可能代表类型、前缀或名字；摘要结果不是实际署名 token 的结构证明。

本次阅读并遵守 root/docs AGENTS、[D1–D9](DECISIONS.md#migration-tooling-v1-p2--owner-locked-extraction-boundary)，
对照 [ES2 function](../../reference/es2/mudlib/doc/lpc/constructs/function)、
[preprocessor](../../reference/es2/mudlib/doc/concepts/preprocessor) 与
[define](../../reference/es2/mudlib/doc/lpc/preprocessor/define)，以及冻结 FR28 和 Attempt-1 复现证据。
本次是纯静态 parser 修复，没有迁移新游戏规则，无需 Godot live gameplay 验证。

## Unified unresolved declaration-header contract

状态为 DECLARATION_HEADER_OPEN、DECLARATION_HEADER_UNRESOLVED、FUNCTION_NAME_CONFIRMED、AFTER_NAME。
未知 identifier 和未知标点共同保留 unresolved header；EMPTY/PREFIX/SET/CREATE/NONCRITICAL/UNKNOWN 宏语义角色均不能恢复它。
实际 macro witness 被保留，即使它早于后续未知 identifier；宏别名链和函数宏摘要不构造合成名称 token。
预处理参与未解析函数声明结构时，共享 pre-segmentation gate 直接拒绝整对象：candidate=false、OUT_OF_SCOPE，
direct_inherits、category_candidates、facts 全空，不继续恢复 setter/create/helper。
原有继承预检、角色分类器和 opaque group 边界保持各自职责。

## Definite direct function-name evidence / no growing type whitelist

只有实际署名 identifier 直接连接匹配的 `(...)` 和匹配的 `{...}`，且该关系没有参与中的预处理不确定性，
才可作为直接函数名证明；分号与完成的 top-level body 重置 header 状态。
`CUSTOM_TYPE helper(){}`、`function helper(){}` 不需要解释类型，也不会仅因未知类型而新拒绝。
`CUSTOM_TYPE helper` 与参数之间的 directive 或 actual macro 则不能作为直接证明。
FUNCTION_DECL_PREFIXES 未添加 function/buffer/class/*/&/[]。没有 LPC 类型语法、宏展开、参数替换、include splicing 或执行器。
AST 对照证明只修改共享 scanner 和 extract_structure 诊断文字；另更新版本常量。
MacroSummary、lexer、CLI、create-tail、mapping、exit finalizer 和 property-key 实现保持原样。

## Root C01/C02 closure / SET-CREATE regression closure

原始 FR28 的 89 次真实 CLI 重放全部通过：49 个原失败满足预先固定的整对象 REFUSE，40 个原控制保持安全。
82 次 sibling 重放是独立再次执行，明确不把一次执行重复计数。
Attempt-1 的 PREFIX→set 与 RESULT→NEXT→create 后接 authored helper/directive 的恢复路径已关闭。
未知 identifier、标点、宏 prefix/helper/set/create、name→params 与 params→body 缺口使用统一规则。

## Dependency early refusal / provenance

root、local、nested、standard、cross-header、nested-cross-header 使用同一 scanner。
REFUSE 矩阵使用 fact、raw-inherit、late-include fail spies 证明拒绝早于分配事实与后置 fallback。
依赖诊断锚定 root-authored include；没有把 dependency offset 套在 root 上。
header witness 与 preprocessing witness 均来自实际输入，未使用 replacement 文本作为 provenance。

## No-preprocessing controls / resets / nested controls

普通直接函数、未知前缀加直接署名函数、statement/body reset、独立 directive、未引用 header、
函数体、参数、mapping、array、nested block、字符串和注释中的同名内容均有控制。
预先固定的 parent 或 SAFE_TIGHTEN oracle 只容许精确 P2F28 相等，或有实际 unresolved-header witness 的完整保守拒绝。
宏摘要不能替代直接名字证明，因此 `mixed helper EMPTY` 加 directive 的旧安全例现在可以拒绝。
这项收紧由 owner 明确授权；不是扩大类型识别或猜测 helper 安全性。

## Fresh matrices / historical regressions

996 expanded 与 250 independent 均完整运行；两套 oracle 保持 Attempt-1 执行前原始字节，未依据结果重写。
新增 absorbing-role 矩阵 570 CLI，覆盖六类宏角色、对象/函数宏、LF/CRLF、root/dependency、两个 directive 缺口、
直接署名证明、分号/body reset、nested 和 unreferenced 控制。其 oracle 在执行前固定。
下表是提交前每个完整矩阵的实际 CLI 次数；开发中断和重跑前缀不计入合计。

| Matrix | Real CLI | Result |
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

合计 **8504 CLI**。P2F28 的 471 与 P2F27 的 624 完整保留；P2F26/P2F25/P2F24 以及 P2F23–P2F11
的全部保留矩阵已重新运行。migration **491**、full Python **537** 均通过，零剩余失败、零 skip；repository/static 与 diff check 通过。
独立结构/CLI 回归、完整套件与 AST 自审分开执行；不是以 focused tests 代替完整验收。

## Synthetic no-widening / authorized historical expectation changes

所有新结构矩阵逐对象与精确 P2F28 比较；完整历史 CLI 包装器在临时输入销毁前也逐对象比较。
禁止 false→true candidate、OOS→PARTIAL/EXTRACTED、新增 fact/exit 或新 quarantine；结果均无扩大。
历史控制变化只能是有 authored unresolved-header + preprocessing witness 的全拒绝，或更早清空元数据。
所有变化收据包含原源码字节、旧/新对象、witness、candidate/fact/quarantine delta；没有 autoaccept snapshot。

历史脚本的旧 finding 文案、旧 helper admission、继承事实保留断言发生失败后，逐例确认才调整。
独立验证包装器自身曾误以普通源入口比较 standalone header fragment；已改为 CLI 同样的 header 分类，
并跳过不完整 dependency unit 的 shared pairing 尝试（与产品入口一致）。这没有改变产品实现或固定新矩阵 oracle。

## 41 migration-test failure review

以下每一行是一条 Attempt-1 的原失败记录，逐项确认已授权。所有新结果均为 OUT_OF_SCOPE、candidate=false、
facts/direct_inherits/category_candidates=[]；Q 表示是否 QUARANTINED。A 表示 Attempt-2 §4–6/16–19 的 absorbing role 规则；
D 表示缺乏直接署名连续 signature/body；E 表示共享 gate 提前拒绝并清空元数据。
表中保留具体测试/子例和实际 token witness，不以整体测试通过替代逐项审查。

| # | Test / subcase | Old expectation | Authored witness (header / preprocessing) | Candidate | Facts | Q | Rule / authorized |
| ---: | --- | --- | --- | --- | --- | --- | --- |
| 1 | P2F10RegressionTests.test_between_parameter_close_and_body (newline="'\\n'", definitions='#define END ; inherit NPC; void tail()', body='') | {"expected": "OUT_OF_SCOPE", "cleared_admission": false, "declaration": "void helper() END {}", "signature": "void create()"} | d/test/room.c: helper / END | False → False | 0 → 0 | False → False | A/D/E; yes |
| 2 | P2F10RegressionTests.test_between_parameter_close_and_body (newline="'\\r\\n'", definitions='#define END ; inherit NPC; void tail()', body='') | {"expected": "OUT_OF_SCOPE", "cleared_admission": false, "declaration": "void helper() END {}", "signature": "void create()"} | d/test/room.c: helper / END | False → False | 0 → 0 | False → False | A/D/E; yes |
| 3 | P2F10RegressionTests.test_complex_return_prefix (newline="'\\n'", definitions='#define TYPE int; inherit NPC; int', body='') | {"expected": "OUT_OF_SCOPE", "cleared_admission": false, "declaration": "TYPE helper(){return 1;}", "signature": "void create()"} | d/test/room.c: TYPE / TYPE | False → False | 0 → 0 | False → False | A/D/E; yes |
| 4 | P2F10RegressionTests.test_complex_return_prefix (newline="'\\r\\n'", definitions='#define TYPE int; inherit NPC; int', body='') | {"expected": "OUT_OF_SCOPE", "cleared_admission": false, "declaration": "TYPE helper(){return 1;}", "signature": "void create()"} | d/test/room.c: TYPE / TYPE | False → False | 0 → 0 | False → False | A/D/E; yes |
| 5 | P2F10RegressionTests.test_name_aliases (newline="'\\n'", definitions='#define H helper', body='') | {"expected": "SAFE", "cleared_admission": false, "declaration": "void H(){}", "signature": "void create()"} | d/test/room.c: H / H | True → False | 9 → 0 | False → False | A/D/E; yes |
| 6 | P2F10RegressionTests.test_name_aliases (newline="'\\r\\n'", definitions='#define H helper', body='') | {"expected": "SAFE", "cleared_admission": false, "declaration": "void H(){}", "signature": "void create()"} | d/test/room.c: H / H | True → False | 9 → 0 | False → False | A/D/E; yes |
| 7 | P2F10RegressionTests.test_signature_modifiers_parameter_names_and_defaults (newline="'\\n'", definitions='#define BAD ){} inherit NPC; void tail(', body='') | {"expected": "OUT_OF_SCOPE", "cleared_admission": false, "declaration": "BAD void helper(){}", "signature": "void create()"} | d/test/room.c: BAD / BAD | False → False | 0 → 0 | False → False | A/D/E; yes |
| 8 | P2F10RegressionTests.test_signature_modifiers_parameter_names_and_defaults (newline="'\\r\\n'", definitions='#define BAD ){} inherit NPC; void tail(', body='') | {"expected": "OUT_OF_SCOPE", "cleared_admission": false, "declaration": "BAD void helper(){}", "signature": "void create()"} | d/test/room.c: BAD / BAD | False → False | 0 → 0 | False → False | A/D/E; yes |
| 9 | P2F24DependencyRegressionTests.test_dependency_matrix (case='control-#define GAP\nmixed helper GAP (){}', newline="'\\n'") | {"refused": false, "name": "control-#define GAP\nmixed helper GAP (){}"} | d/a.h: helper / GAP | True → False | 3 → 0 | False → False | A/D/E; yes |
| 10 | P2F24DependencyRegressionTests.test_dependency_matrix (case='control-#define GAP\nmixed helper GAP (){}', newline="'\\r\\n'") | {"refused": false, "name": "control-#define GAP\nmixed helper GAP (){}"} | d/a.h: helper / GAP | True → False | 3 → 0 | False → False | A/D/E; yes |
| 11 | P2F24DependencyRegressionTests.test_dependency_matrix (case='control-#define GAP\nhelper GAP (){}', newline="'\\n'") | {"refused": false, "name": "control-#define GAP\nhelper GAP (){}"} | d/a.h: helper / GAP | True → False | 3 → 0 | False → False | A/D/E; yes |
| 12 | P2F24DependencyRegressionTests.test_dependency_matrix (case='control-#define GAP\nhelper GAP (){}', newline="'\\r\\n'") | {"refused": false, "name": "control-#define GAP\nhelper GAP (){}"} | d/a.h: helper / GAP | True → False | 3 → 0 | False → False | A/D/E; yes |
| 13 | P2F26RegressionTests.test_handwritten_identity_matrix (case='competingTrue', newline="'\\n'") | {"refused": false, "name": "competingTrue"} | d/fn.h: IDENTITY / IDENTITY | False → False | 0 → 0 | False → False | A/D/E; yes |
| 14 | P2F26RegressionTests.test_handwritten_identity_matrix (case='competingTrue', newline="'\\r\\n'") | {"refused": false, "name": "competingTrue"} | d/fn.h: IDENTITY / IDENTITY | False → False | 0 → 0 | False → False | A/D/E; yes |
| 15 | P2F26RegressionTests.test_single_function_name_slot_with_empty_prefixes_and_suffixes (name='mixed helper E') | {"name": "mixed helper E"} | d/a.c: helper / E | True → False | 2 → 0 | False → False | A/D/E; yes |
| 16 | P2F26RegressionTests.test_single_function_name_slot_with_empty_prefixes_and_suffixes (name='helper E') | {"name": "helper E"} | d/a.c: helper / E | True → False | 2 → 0 | False → False | A/D/E; yes |
| 17 | P2F26RegressionTests.test_single_function_name_slot_with_empty_prefixes_and_suffixes (name='mixed E helper') | {"name": "mixed E helper"} | d/a.c: helper / E | True → False | 2 → 0 | False → False | A/D/E; yes |
| 18 | P2F26RegressionTests.test_single_function_name_slot_with_empty_prefixes_and_suffixes (name='mixed E E2 helper') | {"name": "mixed E E2 helper"} | d/a.c: helper / E | True → False | 2 → 0 | False → False | A/D/E; yes |
| 19 | P2F26RegressionTests.test_single_function_name_slot_with_empty_prefixes_and_suffixes (name='mixed F() helper') | {"name": "mixed F() helper"} | d/a.c: helper / F | True → False | 2 → 0 | False → False | A/D/E; yes |
| 20 | P2F26RegressionTests.test_single_function_name_slot_with_empty_prefixes_and_suffixes (name='mixed helper X(opaque)') | {"name": "mixed helper X(opaque)"} | d/a.c: helper / X | False → False | 0 → 0 | False → False | A/D/E; yes |
| 21 | P2F26RegressionTests.test_single_function_name_slot_with_empty_prefixes_and_suffixes (name='mixed E helper W') | {"name": "mixed E helper W"} | d/a.c: helper / E | True → False | 2 → 0 | False → False | A/D/E; yes |
| 22 | P2F26RegressionTests.test_type_prefix_positions_precede_fact_allocation (identity='T helper', newline="'\\n'", dependency=True) | {"identity": "T helper"} | d/fn.h: helper / T | False → False | 0 → 0 | False → False | A/D/E; yes |
| 23 | P2F26RegressionTests.test_type_prefix_positions_precede_fact_allocation (identity='T helper', newline="'\\r\\n'", dependency=True) | {"identity": "T helper"} | d/fn.h: helper / T | False → False | 0 → 0 | False → False | A/D/E; yes |
| 24 | P2F26RegressionTests.test_type_prefix_positions_precede_fact_allocation (identity='T2 helper', newline="'\\n'", dependency=True) | {"identity": "T2 helper"} | d/fn.h: helper / T2 | False → False | 0 → 0 | False → False | A/D/E; yes |
| 25 | P2F26RegressionTests.test_type_prefix_positions_precede_fact_allocation (identity='T2 helper', newline="'\\r\\n'", dependency=True) | {"identity": "T2 helper"} | d/fn.h: helper / T2 | False → False | 0 → 0 | False → False | A/D/E; yes |
| 26 | P2F26RegressionTests.test_type_prefix_positions_precede_fact_allocation (identity='E T helper', newline="'\\n'", dependency=True) | {"identity": "E T helper"} | d/fn.h: helper / E | False → False | 0 → 0 | False → False | A/D/E; yes |
| 27 | P2F26RegressionTests.test_type_prefix_positions_precede_fact_allocation (identity='E T helper', newline="'\\r\\n'", dependency=True) | {"identity": "E T helper"} | d/fn.h: helper / E | False → False | 0 → 0 | False → False | A/D/E; yes |
| 28 | P2F26RegressionTests.test_type_prefix_positions_precede_fact_allocation (identity='T helper E', newline="'\\n'", dependency=True) | {"identity": "T helper E"} | d/fn.h: helper / T | False → False | 0 → 0 | False → False | A/D/E; yes |
| 29 | P2F26RegressionTests.test_type_prefix_positions_precede_fact_allocation (identity='T helper E', newline="'\\r\\n'", dependency=True) | {"identity": "T helper E"} | d/fn.h: helper / T | False → False | 0 → 0 | False → False | A/D/E; yes |
| 30 | P2F26RegressionTests.test_type_prefix_positions_precede_fact_allocation (identity='mixed helper T', newline="'\\n'", dependency=True) | {"identity": "mixed helper T"} | d/fn.h: helper / T | False → False | 0 → 0 | False → False | A/D/E; yes |
| 31 | P2F26RegressionTests.test_type_prefix_positions_precede_fact_allocation (identity='mixed helper T', newline="'\\r\\n'", dependency=True) | {"identity": "mixed helper T"} | d/fn.h: helper / T | False → False | 0 → 0 | False → False | A/D/E; yes |
| 32 | P2F26RegressionTests.test_type_prefix_positions_precede_fact_allocation (identity='M helper', newline="'\\n'", dependency=True) | {"identity": "M helper"} | d/fn.h: helper / M | False → False | 0 → 0 | False → False | A/D/E; yes |
| 33 | P2F26RegressionTests.test_type_prefix_positions_precede_fact_allocation (identity='M helper', newline="'\\r\\n'", dependency=True) | {"identity": "M helper"} | d/fn.h: helper / M | False → False | 0 → 0 | False → False | A/D/E; yes |
| 34 | P2F26RegressionTests.test_type_prefix_positions_precede_fact_allocation (identity='helper E', newline="'\\n'", dependency=True) | {"identity": "helper E"} | d/fn.h: helper / E | False → False | 0 → 0 | False → False | A/D/E; yes |
| 35 | P2F26RegressionTests.test_type_prefix_positions_precede_fact_allocation (identity='helper E', newline="'\\r\\n'", dependency=True) | {"identity": "helper E"} | d/fn.h: helper / E | False → False | 0 → 0 | False → False | A/D/E; yes |
| 36 | P2F9RegressionTests.test_harmless_helper_and_color_aliases (prefix='#define H helper\n#define COLOR red\nvoid H() {}', newline="'\\n'") | {"expected": "safe"} | d/test/room.c: H / H | True → False | 3 → 0 | False → False | A/D/E; yes |
| 37 | P2F9RegressionTests.test_harmless_helper_and_color_aliases (prefix='#define H helper\n#define COLOR red\nvoid H() {}', newline="'\\r\\n'") | {"expected": "safe"} | d/test/room.c: H / H | True → False | 3 → 0 | False → False | A/D/E; yes |
| 38 | P2F9RegressionTests.test_harmless_helper_and_color_aliases (prefix='#define H J\n#define J helper\nvoid H() {}', newline="'\\n'") | {"expected": "safe"} | d/test/room.c: H / H | True → False | 3 → 0 | False → False | A/D/E; yes |
| 39 | P2F9RegressionTests.test_harmless_helper_and_color_aliases (prefix='#define H J\n#define J helper\nvoid H() {}', newline="'\\r\\n'") | {"expected": "safe"} | d/test/room.c: H / H | True → False | 3 → 0 | False → False | A/D/E; yes |
| 40 | P2F9RegressionTests.test_real_cli_matrix (name='helper', newline="'\\n'") | {"expected": "safe", "name": "helper"} | d/test/room.c: H / H | True → False | 3 → 0 | False → False | A/D/E; yes |
| 41 | P2F9RegressionTests.test_real_cli_matrix (name='helper', newline="'\\r\\n'") | {"expected": "safe", "name": "helper"} | d/test/room.c: H / H | True → False | 3 → 0 | False → False | A/D/E; yes |

## Additional reviewed test deltas

Attempt 2 在同一批旧方法中额外触发 18 条收紧记录，完整套件又暴露 19 条早期宏/conditional 断言；下面逐例记录。
create 被实际宏定义遮蔽时，原先只保留 inherit 事实，现在从共享 gate 清空整个对象；undef-only 控制不被一并改变。
split conditional signature 原先走晚期 include uncertainty，现在先由 unresolved header 拒绝；同样没有新事实或隔离。

| # | Test / subcase | Old expectation | Authored witness (header / preprocessing) | Candidate | Facts | Q | Rule / authorized |
| ---: | --- | --- | --- | --- | --- | --- | --- |
| 1 | P2F10RegressionTests.test_name_aliases (newline="'\\n'", definitions='#define H set', body='') | {"expected": "STATE", "cleared_admission": false, "declaration": "void H(){}", "signature": "void create()"} | d/test/room.c: H / H | True → False | 1 → 0 | False → False | A/D/E; yes |
| 2 | P2F10RegressionTests.test_name_aliases (newline="'\\r\\n'", definitions='#define H set', body='') | {"expected": "STATE", "cleared_admission": false, "declaration": "void H(){}", "signature": "void create()"} | d/test/room.c: H / H | True → False | 1 → 0 | False → False | A/D/E; yes |
| 3 | P2F10RegressionTests.test_name_aliases (newline="'\\n'", definitions='#define H create', body='') | {"expected": "STATE", "cleared_admission": false, "declaration": "void H(){}", "signature": "void create()"} | d/test/room.c: H / H | True → False | 1 → 0 | False → False | A/D/E; yes |
| 4 | P2F10RegressionTests.test_name_aliases (newline="'\\r\\n'", definitions='#define H create', body='') | {"expected": "STATE", "cleared_admission": false, "declaration": "void H(){}", "signature": "void create()"} | d/test/room.c: H / H | True → False | 1 → 0 | False → False | A/D/E; yes |
| 5 | P2F9RegressionTests.test_real_cli_matrix (name='set', newline="'\\n'") | {"expected": "function", "name": "set"} | d/test/room.c: S / S | True → False | 1 → 0 | False → False | A/D/E; yes |
| 6 | P2F9RegressionTests.test_real_cli_matrix (name='set', newline="'\\r\\n'") | {"expected": "function", "name": "set"} | d/test/room.c: S / S | True → False | 1 → 0 | False → False | A/D/E; yes |
| 7 | P2F9RegressionTests.test_real_cli_matrix (name='create', newline="'\\n'") | {"expected": "function", "name": "create"} | d/test/room.c: C / C | True → False | 1 → 0 | False → False | A/D/E; yes |
| 8 | P2F9RegressionTests.test_real_cli_matrix (name='create', newline="'\\r\\n'") | {"expected": "function", "name": "create"} | d/test/room.c: C / C | True → False | 1 → 0 | False → False | A/D/E; yes |
| 9 | P2F9RegressionTests.test_real_cli_matrix (name='chain-set', newline="'\\n'") | {"expected": "function", "name": "chain-set"} | d/test/room.c: A / A | True → False | 1 → 0 | False → False | A/D/E; yes |
| 10 | P2F9RegressionTests.test_real_cli_matrix (name='chain-set', newline="'\\r\\n'") | {"expected": "function", "name": "chain-set"} | d/test/room.c: A / A | True → False | 1 → 0 | False → False | A/D/E; yes |
| 11 | P2F9RegressionTests.test_real_cli_matrix (name='chain-create', newline="'\\n'") | {"expected": "function", "name": "chain-create"} | d/test/room.c: A / A | True → False | 1 → 0 | False → False | A/D/E; yes |
| 12 | P2F9RegressionTests.test_real_cli_matrix (name='chain-create', newline="'\\r\\n'") | {"expected": "function", "name": "chain-create"} | d/test/room.c: A / A | True → False | 1 → 0 | False → False | A/D/E; yes |
| 13 | P2F9RegressionTests.test_real_cli_matrix (name='included-set', newline="'\\n'") | {"expected": "function", "name": "included-set"} | d/test/room.c: A / A | True → False | 1 → 0 | False → False | A/D/E; yes |
| 14 | P2F9RegressionTests.test_real_cli_matrix (name='included-set', newline="'\\r\\n'") | {"expected": "function", "name": "included-set"} | d/test/room.c: A / A | True → False | 1 → 0 | False → False | A/D/E; yes |
| 15 | P2F9RegressionTests.test_real_cli_matrix (name='included-create', newline="'\\n'") | {"expected": "function", "name": "included-create"} | d/test/room.c: A / A | True → False | 1 → 0 | False → False | A/D/E; yes |
| 16 | P2F9RegressionTests.test_real_cli_matrix (name='included-create', newline="'\\r\\n'") | {"expected": "function", "name": "included-create"} | d/test/room.c: A / A | True → False | 1 → 0 | False → False | A/D/E; yes |
| 17 | P2F9RegressionTests.test_real_cli_matrix (name='nested', newline="'\\n'") | {"expected": "function", "name": "nested"} | d/test/room.c: A / A | True → False | 1 → 0 | False → False | A/D/E; yes |
| 18 | P2F9RegressionTests.test_real_cli_matrix (name='nested', newline="'\\r\\n'") | {"expected": "function", "name": "nested"} | d/test/room.c: A / A | True → False | 1 → 0 | False → False | A/D/E; yes |
| 19 | AuditBlockerRegressionTests.test_h2_continued_critical_names_lf_and_crlf (newline="'\\n'", name='create') | {"name": "create"} | d/test/room.c: create / create | True → False | 1 → 0 | False → False | A/D/E; yes |
| 20 | AuditBlockerRegressionTests.test_h2_continued_critical_names_lf_and_crlf (newline="'\\r\\n'", name='create') | {"name": "create"} | d/test/room.c: create / create | True → False | 1 → 0 | False → False | A/D/E; yes |
| 21 | P2F5RegressionTests.test_comment_prefixed_critical_defines_lf_crlf (newline="'\\n'", name='create') | {"name": "create"} | d/test/room.c: create / create | True → False | 1 → 0 | False → False | A/D/E; yes |
| 22 | P2F5RegressionTests.test_comment_prefixed_critical_defines_lf_crlf (newline="'\\r\\n'", name='create') | {"name": "create"} | d/test/room.c: create / create | True → False | 1 → 0 | False → False | A/D/E; yes |
| 23 | P2F7RegressionTests.test_next_line_critical_macros_and_undef (payload='/*', hazard='define create renamed', newline="'\\n'") | Lists differ: ['inherit'] != [] | d/test/room.c: create / create | True → False | 1 → 0 | False → False | A/D/E; yes |
| 24 | P2F7RegressionTests.test_next_line_critical_macros_and_undef (payload='/*', hazard='define create renamed', newline="'\\r\\n'") | Lists differ: ['inherit'] != [] | d/test/room.c: create / create | True → False | 1 → 0 | False → False | A/D/E; yes |
| 25 | P2F7RegressionTests.test_next_line_critical_macros_and_undef (payload='"', hazard='define create renamed', newline="'\\n'") | Lists differ: ['inherit'] != [] | d/test/room.c: create / create | True → False | 1 → 0 | False → False | A/D/E; yes |
| 26 | P2F7RegressionTests.test_next_line_critical_macros_and_undef (payload='"', hazard='define create renamed', newline="'\\r\\n'") | Lists differ: ['inherit'] != [] | d/test/room.c: create / create | True → False | 1 → 0 | False → False | A/D/E; yes |
| 27 | P2F7RegressionTests.test_next_line_critical_macros_and_undef (payload='@MARKER', hazard='define create renamed', newline="'\\n'") | Lists differ: ['inherit'] != [] | d/test/room.c: create / create | True → False | 1 → 0 | False → False | A/D/E; yes |
| 28 | P2F7RegressionTests.test_next_line_critical_macros_and_undef (payload='@MARKER', hazard='define create renamed', newline="'\\r\\n'") | Lists differ: ['inherit'] != [] | d/test/room.c: create / create | True → False | 1 → 0 | False → False | A/D/E; yes |
| 29 | P2F7RegressionTests.test_next_line_critical_macros_and_undef (payload='@@MARKER', hazard='define create renamed', newline="'\\n'") | Lists differ: ['inherit'] != [] | d/test/room.c: create / create | True → False | 1 → 0 | False → False | A/D/E; yes |
| 30 | P2F7RegressionTests.test_next_line_critical_macros_and_undef (payload='@@MARKER', hazard='define create renamed', newline="'\\r\\n'") | Lists differ: ['inherit'] != [] | d/test/room.c: create / create | True → False | 1 → 0 | False → False | A/D/E; yes |
| 31 | P2F7RegressionTests.test_next_line_critical_macros_and_undef (payload='\\', hazard='define create renamed', newline="'\\n'") | Lists differ: ['inherit'] != [] | d/test/room.c: create / create | True → False | 1 → 0 | False → False | A/D/E; yes |
| 32 | P2F7RegressionTests.test_next_line_critical_macros_and_undef (payload='\\', hazard='define create renamed', newline="'\\r\\n'") | Lists differ: ['inherit'] != [] | d/test/room.c: create / create | True → False | 1 → 0 | False → False | A/D/E; yes |
| 33 | P2F7RegressionTests.test_next_line_critical_macros_and_undef (payload='plain', hazard='define create renamed', newline="'\\n'") | Lists differ: ['inherit'] != [] | d/test/room.c: create / create | True → False | 1 → 0 | False → False | A/D/E; yes |
| 34 | P2F7RegressionTests.test_next_line_critical_macros_and_undef (payload='plain', hazard='define create renamed', newline="'\\r\\n'") | Lists differ: ['inherit'] != [] | d/test/room.c: create / create | True → False | 1 → 0 | False → False | A/D/E; yes |
| 35 | P2F7RegressionTests.test_real_cli_fr6_01 | Lists differ: ['inherit'] != [] | d/probe.c: create / create | True → False | 1 → 0 | False → False | A/D/E; yes |
| 36 | P2F8RegressionTests.test_nested_critical_macros | {"expected": "setter", "name": "create"} | d/test/room.c: create / create | True → False | 1 → 0 | False → False | A/D/E; yes |
| 37 | P2F8RegressionTests.test_split_conditional_signatures_are_not_joined_into_harmless_definition | {"expected": "admission"} | d/test/hazard.h: set / #else\n | False → False | 0 → 0 | False → False | A/D/E; yes |

另有两个 provenance 测试方法的四个具体输入单独核对：TYPE+set、TYPE+WRITER 现在保留 TYPE 与实际名字 token；
root ALIAS 的 LF/CRLF 保留 ALIAS 自身而不是后来的 pragma。旧/新 candidate=false、facts=0、quarantine=false；
所有 span 均复核实际字节。dependency 对应项仍只使用 root include。没有合成 replacement provenance。

## Version 1.0.29 / compatibility / security

schema_version=1、profile=static-room-v1、extractor_version=1.0.29；KNOWN 精确为 1.0.0–1.0.29，共 30。
30 份真实完整 canonical 历史文档均通过真实 CLI 原子替换。
manual/reviewed/future/unknown/malformed/empty，以及独立发现的全部 33 个 nested dictionary 位置污染，
均 exit2、writer not called、目标字节不变。输出 confinement、外部 tracked checkout、批准的 build/external 输出通过。
完整套件还检查 ancestor/escape、链接/junction 拒绝分支、读取失败、schema 失败与 atomic replace 失败保留旧字节。
链接/junction 分支使用 mock，不声称创建了真实 OS 链接；CLI/writer 实现未改变。
invalid UTF-8 的 raw_hex 也单独验证，不以本语料未触发 raw_hex 代替证明。

## Corpus A/B / semantic delta / safety budget

两次独立完整扫描均 exit1；2336 输入全部表示，EXTRACTED0、PARTIAL485、OUT_OF_SCOPE1838、QUARANTINED13，
facts2736、findings4296。每份 9,808,627 bytes，A/B 完全字节一致：
`8c2f00d2442bb3a0dea840ef009a54195bf0e95c228119c1b696e8daec42b7f0`。
与具有 exact P2F28 HEAD 收据的原 canonical 输出比较，除 extractor_version 外整个文档完全相等。
旧 supported485 → 新485，delta0，受影响真实路径=[]；candidate、status、inherits、facts、IDs、findings、categories 均无变化。

| Finding code | Count |
| --- | ---: |
| CALLBACK_BEHAVIOR | 284 |
| DRIVER_SEMANTICS_UNKNOWN | 408 |
| DYNAMIC_EXPRESSION | 10 |
| ORDER_SENSITIVE_MUTATION | 30 |
| OUT_OF_SCOPE | 1319 |
| REQUIRES_SEMANTIC_REVIEW | 1623 |
| RNG_SEMANTICS | 58 |
| SOURCE_ENCODING_ISSUE | 8 |
| SOURCE_SYNTAX_ERROR | 5 |
| UNRESOLVED_INCLUDE | 97 |
| UNRESOLVED_INHERITANCE | 14 |
| UNSUPPORTED_CONSTRUCT | 440 |

## 13 quarantines / 14 ANSI exclusions

13 个 quarantine 的确切路径、原因、span 与父提交完全一致；8 encoding + 5 syntax，facts=[]。
再次检查实际字节中的 NUL/replacement、缺失引号与失配 closure；没有新增 quarantine。
这只是修复回归验证，不宣称完成尚待授权的系统性 quarantine-path Final Audit。

| Path | Reason | Byte span |
| --- | --- | --- |
| `cmds/std/exercise.c` | NUL or replacement character in source | 2033–2036 |
| `d/choyin/npc/yamen_po.c` | NUL or replacement character in source | 4382–4385 |
| `d/latemoon/sroad1.c` | unterminated string | 402–457 |
| `d/latemoon/upstar/upcenter.c` | NUL or replacement character in source | 337–340 |
| `d/npc/oldman.c` | mismatched delimiter | 4819–4820 |
| `d/temple/npc/obj/magic_book.c` | NUL or replacement character in source | 863–866 |
| `d/temple/npc/obj/spells_book.c` | NUL or replacement character in source | 840–843 |
| `d/temple/obj/magic_book.c` | NUL or replacement character in source | 863–866 |
| `d/temple/obj/spells_book.c` | NUL or replacement character in source | 840–843 |
| `d/village/lordhouse3.c` | mismatched delimiter | 1737–1738 |
| `u/cloud/npc/goddd.c` | unterminated string | 4255–4280 |
| `u/cloud/obj/npc/flower_girl/guihua.c` | NUL or replacement character in source | 4–5 |
| `u/cloud/obj/sword_book.c` | mismatched delimiter | 907–908 |

14 个 ANSI 路径均 candidate=false / OUT_OF_SCOPE / facts=[]：

- `d/canyon/canyon4.c`
- `d/choyin/club.c`
- `d/chuenyu/trap_castle.c`
- `d/city/boots.c`
- `d/city/cloth.c`
- `d/green/water.c`
- `d/latemoon/gate.c`
- `d/latemoon/latemoon3.c`
- `d/latemoon/latemoon8.c`
- `d/latemoon/miroom.c`
- `d/latemoon/park/paroad2.c`
- `d/latemoon/room/bathroom.c`
- `d/latemoon/room/bathroom1.c`
- `d/oldpine/keep2.c`

## Provenance / IDs / summary

全语料 9,587 条 provenance（2,736 facts、4,296 findings、1,799 direct inherits、756 normalization inputs）
逐项验证 path/SHA/byte span/raw、line/Unicode column、construct/scope/ordinal 与 normalization。
fact-ID 公式、稳定顺序、finding 引用、manifest、summary、UNREVIEWED 状态均验证；没有 ghost/orphan/duplicate ID 或自动 APPROVED。
提前拒绝发生在 fact 分配前，不会留下 earlier unsafe create facts；未受影响 ID 与精确 P2F28 相同。

## ARCHIVE-01 / source immutability / scope

ARCHIVE-01 CLOSED。10 个 tracked 历史报告与 24 个 owner-local 历史报告逐一核验原始 SHA，历史证据均未暂存。
P2F10 仍为 24,417 bytes、468 CRLF；.gitattributes 原始 SHA 为
`b33913bb7279e1ab67762574ab277828a9fd114dae23dceace2f24ae842194d6`，其 -text 例外保持原状。
reference tree=`4106480ab28cce8cd7b55704f8ae9ae062d42d03`；2336 文件原始 manifest=
`744e33e1740db7909129a3ae5e295158341b5012a411af953b144a5075bb0a80`。
全部非授权 tracked 文件的原始 SHA 也核对不变。没有 source/game/runtime/CI/schema 修改；没有第三方依赖、生成 corpus 或临时证据进入提交。

### Twenty-four owner-local historical hashes

| Filename | Raw SHA-256 |
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

### Ten tracked historical archive hashes

| Filename | Raw SHA-256 |
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

## Reproducibility / documentation / exact-commit gate

忽略目录 `build/migration-tooling-v1/p2f29a2/` 保存固定 oracle、源码、真实 CLI 输出、每项比较和 suite 日志。
提交前汇总为 pre-gate-summary.json；提交后须重新生成 post-* 全套门与 post-gate-summary.json，绑定承载提交 HEAD。
pre/post 的核心源 SHA 必须相同：

| File | Raw SHA-256 |
| --- | --- |
| tools/migration/room_extractor.py | `7e3a7e483325f55c120f75237f3bd3b41c9565f95564fe35a20c87766cc8270a` |
| tools/tests/test_migration_tooling.py | `874b0659515a417fb9d947922014761d13cd0b0cc9d977b34b082413c0a4e288` |

Markdown 检查涵盖 tracked milestone 文档、当前 report、STATUS/ROADMAP 的相对链接和 anchors；
repository/static、diff whitespace、五文件 scope 和历史保存检查必须在暂存前、提交后再通过。
只暂存 extractor、测试、本报告、STATUS、ROADMAP；提交 subject 为
`Refuse preprocessing-sensitive unresolved declaration headers`，父提交必须为冻结 P2F28。
不得在提交后修改实现或 amend；若不可变提交验证失败，停止且不 push。

## Residual boundaries / owner gate

授权的保守 false negatives 是 v1 边界；不是 LPC grammar/preprocessor/runtime。
宏摘要不执行参数替换，include 摘要不是 expanded TU；未覆盖语义必须保守处理。
filesystem TOCTOU、schema validation 不等于作者授权、driver 差异及未完成的结构/隔离路径总审仍是既有边界。
已确认契约缺陷不能降级成 accepted residual risk。本次实施验证未发现候选、事实、exit 或 quarantine 扩大。

FR28-01 修复已实现，等待 owner review；不把它直接宣称为下一次 Final Audit CLOSED。
Structural-Preprocessing Consolidation Final Audit 仍必需；Systematic Quarantine-Path Audit 仍 INCOMPLETE。
当前 phase 未集成到 main；无 phase PR、无 merge、无新 remote CI 或 post-main CI 证明；P3 未授权。
提交后全门通过并推送后停止，下一次 Final Re-Audit 必须由 owner 另行授权。
