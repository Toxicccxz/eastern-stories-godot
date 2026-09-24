# Migration Tooling v1 — P2F14: Preprocessor inherit declaration boundary

**P2F14 FIX IMPLEMENTED — AWAIT OWNER REVIEW / FINAL RE-AUDIT NOT YET AUTHORIZED**

## Authorization / frozen identities

本次仅修复 FR13-01 / blocking MEDIUM / D9 的 pending inherit 声明边界家族。
Owner授权同分支实施、聚焦与完整本地验证、一个提交、精确提交复验、push；不授权下一次Final Re-Audit、PR、merge或P3。

| Identity | Frozen value |
| --- | --- |
| Branch | `phase/migration-tooling-v1` |
| Pre-fix HEAD / origin phase | `0e3801cc5b6852dd0ab2819826d4ddbf31b660fc` |
| Pre-fix subject | `Fix include fragment pairing classification` |
| Main / origin main / merge base | `cd07808cb76147d0b8c0dad9b82d078b49fefe64` |
| Reference Git tree | `4106480ab28cce8cd7b55704f8ae9ae062d42d03` |

fetch后核对19个线性提交及冻结状态；初始tracked/index clean，只有三份预期untracked历史报告。
all-state阶段PR查询零项。授权文件严格限制为extractor、测试模块、本报告、STATUS、ROADMAP。
所有临时证据位于ignored `build/migration-tooling-v1/p2f14/`，原审计报告及原始源代码不修改。

## FR13-01 root cause

[本地include权威说明](../../reference/es2/mudlib/doc/lpc/preprocessor/include)和
[preprocessor manual](../../reference/es2/mudlib/doc/concepts/preprocessor)允许文本include及后续标识符宏替换。
因此header提供`;`或`ROOM;`时，authored根文件没有`;`不等于源损坏。
旧实现却在分析这些依赖前抛出`unterminated inherit`，产生QUARANTINED/exit1。
本次只处理此静态工具分类问题，没有迁移或改变游戏机制，也没有采用外部移植代码。

## Old declaration-order failure

旧代码在遇到顶层inherit后一直向后寻找第一个authored分号，找不到就立即报错；
随后才调用include/macro风险分析。
这既会忽略真正参与声明的预处理器内容，也可能借用后续函数或下一条inherit中的分号。

## Pending inherit declaration model

从inherit之后逐token扫描，authored `;`正常结束声明。
遇到下一个inherit、明确的类型/声明修饰关键字、body opening或可识别的无类型函数定义时，结束pending范围。
这个范围边界是保守的有限模型，不是完整LPC语法。
只有不能建立authored声明终止边界时才调用新helper；普通`inherit ROOM;`的测试显式patch helper，确认不会调用。

helper只检查pending范围中的实际include和宏使用。
完整compilation-context宏定义仍由现有`macro_context()`提供；定义存在不等于实际使用。
参与声明的每条include单独交给同一个既有遍历器，保留root origin；不存在第二套include路径解析规则。

## Why this is not preprocessing

只汇总原始token是否证明边界中性或无法确定，不连接root/header，不展开宏、不替换参数、不执行条件，
不插入分号、不构造新的Token或预处理后LPC，不执行cpp/LPC，不求值继承表达式。
AST自审确认：既有method只有`RoomExtractor.extract_structure`改变，新增两个同名边界helper；imports未变。
P2F12/P2F13 pairing路径、宏effect/reach、lexer、CLI和writer均保持原样。

## Include-supplied terminator

原始FR13反例`inherit ROOM`后include `;`：现在root OOS、candidate=false、facts=[]、无SOURCE_SYNTAX_ERROR、exit0。
header保持HEADER/OOS、fact-free。没有恢复inherit fact。

header检查仅接受expression-shaped原始前缀的终止符，或前缀上的不确定宏使用；
不会因为helper body或普通类型变量声明里有分号而免除root错误。

## Whole-expression include

独立手写`ROOM;`和`"/std/room";` header、root仅含inherit，均保守OOS。
已覆盖literal base后include分号，以及`"/std/"`后include `+ "room";`的表达式后缀。
都不恢复可靠的inherit、category或fact。

## Nested/standard/EOF includes

本地相对路径、nested目录链、标准`include/`路径、EOF无后续函数均覆盖LF/CRLF。
root finding锚定参与声明的root include；不会锚定较早无关safe sibling或nested header的标点。

## Missing include policy

本次owner明确锁定：pending inherit中的missing/unresolved include，无法证明其不会提供声明尾部。
现在保守OOS/exit0，发出OUT_OF_SCOPE、DRIVER_SEMANTICS_UNKNOWN、UNRESOLVED_INCLUDE。
覆盖本地/standard/macro-path/nested missing，诊断锚定真实root include。
这不证明源可编译；unknown preprocessing不等于已证明损坏。

这是对FR13审计40-case矩阵中missing-include负对照的显式政策更新。
P2F13原有“missing include加根delimiter损坏”测试保持不变并通过；本次不改其处理。

## Declaration-position scoping

无关早期include、函数体内的后续END/include、下一条声明均不能提供当前inherit的恢复证据。
正常函数与无类型函数两个位置负对照都覆盖。后续函数里的真实`;`不会成为当前inherit的terminator。

## Safe/empty/unrelated include negatives

空header、`int x;`、有返回语句的typed/untyped helper、只定义但不使用END的header，都保持root QUARANTINED。
未引用semicolon header、较早的safe/semicolon/missing include也不豁免缺失terminator。
真正缺分号控制保持原始`unterminated inherit`及raw `inherit`错误span。

## Object-like macro terminator

实际声明中`END`且定义为`;`，保守OOS，root finding锚定authored END。
没有读取替换字节生成根文件事实。

## Alias chains

别名按有向依赖迭代遍历；1100条边压力控制通过，未使用Python递归。
循环通过图上移除叶子的现有风格处理为不确定，不尝试展开。

## Function-like terminator

实际调用END()的terminator、使用参数的replacement都保守拒绝；不替换任何argument。
未调用function-like宏不贡献replacement；实际调用但单个中性字面量replacement仍不能提供分号。
另测header中的END()调用及其neutral对照，避免丢失调用形状。

## Header-defined/cross-header macros

root实际END使用可依赖header定义；不同已解析headers中的END→FIN→`;`使用同一MacroSummary。
定义来源可以跨header，但参与条件仍是当前pending声明中的实际使用。

## Cycles/unknown macro uncertainty

实际使用cycle、competing definitions、token paste、invalid function shape或复杂replacement时，边界中性不可证明，返回OOS。
空/single-atom replacement及其alias链可证明中性；复合表达式保守拒绝，不做算术或token运算。

## Unused/neutral macro negatives

未使用END、实际使用VALUE=1/BASE=ROOM、neutral function call、uninvoked function macro均不豁免真实缺分号。
`#define`本身不是输出；raw echo、pragma、undef也不供给terminator。

## Multiple inherit behavior

valid first +uncertain second、uncertain first +valid later都在事实输出前OOS。
多个正常authored inherits保留既有PARTIAL和独立inherit facts；精确symbol/literal excluded bases分类保持。

## Facts/direct-inherit suppression

新拒绝路径发生在事实发射循环之前；清空先前收集的direct_inherits/category_candidates，返回默认OOS/candidate=false。
facts始终为空，没有把不确定表达式碎片提升为可迁移语义。

## Finding provenance

include和missing依赖锚定当前root directive，macro锚定当前root usage；nested依赖传播root origin。
所有新CLI provenance对原始bytes/hash/span/raw/line/column核验，未产生synthetic terminator或跨文件root provenance。
全语料核验9,587个provenance：direct inherit1,799、facts2,736、findings4,296、normalization inputs756；
Unicode span1,239、CRLF-source span3、raw_hex0。独立invalid UTF-8 probe验证raw_hex路径。

## Header P2F13 preservation

保留P2F13 HEADER策略。`;`、ROOM;、六种delimiter和incomplete declaration不会因standalone结构不完整被隔离。
invalid UTF-8、NUL、unterminated string/comment/heredoc等真实词法损坏仍QUARANTINED。
P2F13的29个历史方法及完整110-case CLI系列重新运行通过。

## P2F1–P2F13 regressions

本地P2F14聚焦9个test methods，包含51种独立手写矩阵 × LF/CRLF及额外long-chain/laziness/provenance/header/exclusion检查。
所有历史repair classes共286个tests通过，包含FR7–FR12所指定路径。
完整migration360、Python406、repository_checks、git diff --check通过。
这些是修复验收，不是新的Final Re-Audit；没有宣称里程碑终审PASS。

## Real CLI matrix

实际subprocess CLI使用external TemporaryDirectory source/output，共228 cases：exit0=146、exit1=82。

| Group | Cases |
| --- | --- |
| 保留P2F13全系列 | 110 |
| 原40-case FR13家族 +新scoping/unknown controls | 102 |
| 1100-alias LF/CRLF | 2 |
| exact exclusions | 12 |
| 多个正常inherits | 2 |

对原40例及新案例逐项验证expected状态、候选、facts、direct_inherits/category、header状态、finding和原始来源。
合法/不确定inherit案例false quarantine=0，unsafe facts=0；无预处理不确定性的真正malformed控制保持QUARANTINED。
每例JSON保存源hex/hash、输出、诊断、provenance；没有snapshot自动接受流程。

## Version 1.0.14

EXTRACTOR_VERSION=1.0.14；known集合1.0.0–1.0.14。
schema_version=1、profile=static-room-v1保持；没有Save/runtime schema变化。

## Output compatibility

真实历史canonical output 1.0.0–1.0.14各取副本，15种实际CLI替换均成功；历史输出原件不变。
unknown/manual/reviewed/malformed/future六类不安全输出拒绝exit2、writer未调用、原字节不变。
独立33处nested字典注入同样拒绝；closed schema未修改。

既有安全tests全部通过；额外8组protected目录路径形式拒绝且writer未调用，外部tracked checkout受保护，
approved external/build目的地仍成功。原子写入失败等既有回归包含在完整migration suite；CLI/writer没有修改。

## Corpus A/B

两次新扫描：exit1、scanned2,336、supported485、EXTRACTED0、PARTIAL485、OOS1,838、QUARANTINED13、facts2,736、findings4,296。
A/B均9,808,627 bytes、逐字节一致，SHA-256均为：

`115ba99ca1c75a244cac8eb4fd6cee5eed099df60404b0dd3c9cf604b132fa4d`

对照精确P2F13 `0e3801cc5b6852dd0ab2819826d4ddbf31b660fc` post证据：
仅移除extractor_version后，整个JSON语义完全相同，object/status/candidate/fact/finding/direct-inherit delta=0。
完整输入manifest与reference文件原始hash一致；无截断、自动APPROVED或不稳定排序。

| Finding code | Count |
| --- | --- |
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

## 13 quarantines

8 encoding、5 syntax，精确集合及诊断不变，全部facts=[]。
编码项对实际raw bytes核验NUL/U+FFFD；syntax项重读源及其diagnostic byte位置：
sroad1的north键引号缺失、goddd第92行多余未转义引号导致词法错位；oldman孤立调用尾`)`、lordhouse3注释掉条件但保留close braces、sword_book多余closing brace。
没有任何一项由本次inherit恢复路径降级。

| Source | Reason | Diagnostic line | Bytes |
| --- | --- | --- | --- |
| `cmds/std/exercise.c` | NUL or replacement character in source | 57 | [2033,2036) |
| `d/choyin/npc/yamen_po.c` | NUL or replacement character in source | 123 | [4382,4385) |
| `d/latemoon/sroad1.c` | unterminated string | 15 | [402,457) |
| `d/latemoon/upstar/upcenter.c` | NUL or replacement character in source | 11 | [337,340) |
| `d/npc/oldman.c` | mismatched delimiter | 145 | [4819,4820) |
| `d/temple/npc/obj/magic_book.c` | NUL or replacement character in source | 24 | [863,866) |
| `d/temple/npc/obj/spells_book.c` | NUL or replacement character in source | 24 | [840,843) |
| `d/temple/obj/magic_book.c` | NUL or replacement character in source | 24 | [863,866) |
| `d/temple/obj/spells_book.c` | NUL or replacement character in source | 24 | [840,843) |
| `d/village/lordhouse3.c` | mismatched delimiter | 81 | [1737,1738) |
| `u/cloud/npc/goddd.c` | unterminated string | 161 | [4255,4280) |
| `u/cloud/obj/npc/flower_girl/guihua.c` | NUL or replacement character in source | 1 | [4,5) |
| `u/cloud/obj/sword_book.c` | mismatched delimiter | 27 | [907,908) |

## 14 ANSI exclusions

以下精确14项仍candidate=false/OOS/facts=[]/not QUARANTINED；没有ANSI求值：

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

## Archive preservation

十份tracked历史audit在HEAD/index/worktree均匹配冻结hash；P2F10原始24,417 bytes /468 CRLF，SHA
`56e1cd0aa0a573bc4a9505fb5df6bd1cfbd0076849a40f6bd4a4420483cb2213`；
tracked P2F11 SHA为`48f07085604905ef3d603474bae86fb028cff9bbc1088a83769eee16babe9155`。
`.gitattributes`及其单文件`-text`例外不变，ARCHIVE-01 CLOSED。
reference tree保持冻结值，全部2,336个文件的仓库路径/hash manifest仍为
`744e33e1740db7909129a3ae5e295158341b5012a411af953b144a5075bb0a80`。

## Three blocked-report preservation

| Owner-local untracked report | Frozen SHA-256 |
| --- | --- |
| `MIGRATION_TOOLING_V1_FINAL_RE_AUDIT_AFTER_P2F11_RERUN.md` | `8fc46327ca954ad0089e3ee4fb496bfe8cfe21f497b43ae77432e76ff2bc170b` |
| `MIGRATION_TOOLING_V1_FINAL_RE_AUDIT_AFTER_P2F12.md` | `a0847fdd481867b45e0c1d0b4b4dfdea7e0995a2bb607130fceeff0d8effc04a` |
| `MIGRATION_TOOLING_V1_FINAL_RE_AUDIT_AFTER_P2F13.md` | `adbdaddd424dcebed66ef0e984969fa7d2a949325c184a944d764950ccf9febb` |

三份均不编辑、不stage、不提交；提交前与提交后精确验证脚本核对hash和untracked/unstaged状态。

## Distinct verification and exact-commit gate

实现后进行了独立diff/AST审阅、真实CLI矩阵、全语料provenance/manifest及正向损坏证据检查。
纯parser修复不要求live gameplay；未启动Godot，也不宣称live证明。
源码、CLI、安全输出写入器和运行时边界均未扩展。

本报告随唯一提交`Fix preprocessor inherit declaration boundary`冻结；parent必须为上述pre-fix SHA。
提交后必须在精确SHA重新执行focused9、prior286、migration360、Python406、static/diff、228 CLI、15版兼容、
输出安全、corpus A/B、13隔离、14 ANSI、provenance、自审及全部archive/三份报告哈希，再允许push。
提交前receipt前缀为`pre-`；提交后为`post-`，不能将前者冒充后者。
精确SHA与post结果保存在ignored `post-verification.json`及各分项receipt，并在owner完成报告中给出。
本文件不自称包含尚未发生的post-commit结果，不追加第二个提交或amend来填入自身SHA。

## Residual boundary

解析仍是bounded lexer/structural summary，有限类型/函数边界识别和expression-prefix规则不是完整LPC语法。
复杂/competing/循环宏允许保守OOS，不承诺所有预处理程序可被静态识别。
声明位置missing include的OOS只表示未知，绝不表示已通过真实driver编译。
真正encoding/lexical损坏与无相关不确定性的unterminated inherit控制保持。
未增加Native consumer、NPC/item抽取、游戏/Save修改；没有PR或远端CI证据。

## Owner gate

P2F13 CLOSED；其后Final Re-Audit因FR13-01 BLOCKED。本次P2F14修复实施完成，等待owner审阅。
这是修复验收，不是另一次完整终审。push后停止；完整Final Re-Audit须新的明确授权。
无PR、merge、branch deletion、P3或历史改写。

**MIGRATION TOOLING V1 P2F14 FIX COMPLETE**

**FR13-01 PREPROCESSOR-SUPPLIED INHERIT-BOUNDARY FALSE-QUARANTINE BLOCKER ADDRESSED**

**TRUE UNTERMINATED INHERIT DETECTION PRESERVED**

**ARCHIVE-01 REMAINS CLOSED**

**READY FOR OWNER REVIEW / FINAL RE-AUDIT AUTHORIZATION — STOP**
