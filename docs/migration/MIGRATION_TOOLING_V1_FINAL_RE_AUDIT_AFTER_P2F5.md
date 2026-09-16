# Migration Tooling v1 — Final Re-Audit after P2F5

**BLOCKED — NOT READY FOR PR — AWAIT OWNER REVIEW**

## 1. Executive verdict / stop boundary

本次在冻结 executable HEAD 上发现新的实质 D9 缺陷 **FR5-01 / MEDIUM**：
预处理指令内部的跨行块注释已在原始源码中闭合，但 lexer 在注释中途截断 directive token，
下游把该截断片段当完整源码重新词法分析，错误报告 `SOURCE_SYNTAX_ERROR: unterminated block comment`，
最终 exit1 / QUARANTINED。这是有效但未正确支持的构造被误标为源码损坏，不是可接受的 residual risk。

新跑的 104/150 测试、语料确定性及全量 provenance 通过，不能抵消该合同缺陷。
owner 要求任何 material defect（包括 MEDIUM）均 BLOCKED 并停止；因此未继续剩余全里程碑验收。
没有修改代码、测试、fixture、DECISIONS、STATUS、ROADMAP；没有 commit/push/PR/merge/P3。
本报告保持 local/untracked。已确认新 HIGH 缺陷数为 0，不将此当作完整审计的 HIGH=0 放行证明。

## 2. Frozen identities and owner state

| 项目 | 实测身份 |
| --- | --- |
| Repository / branch | Toxicccxz/eastern-stories-godot / phase/migration-tooling-v1 |
| main / origin/main / merge-base | cd07808cb76147d0b8c0dad9b82d078b49fefe64 |
| executable HEAD / origin phase | 8cc5a01741232ed062aff52bee0e77b4d4351b39 |
| 初始 tracked worktree / index | clean / clean |
| 初始 untracked | 三个指定历史 BLOCKED 审计 |
| PR | all-state 查询为空 |
| 本次 docs-only audit commit | 无，BLOCKED 禁止提交 |

fetch 后冻结条件全部通过。P1、P2、P2F1–P2F5 均 OWNER APPROVED / CLOSED；D1–D9 LOCKED。
三份旧审计仍是历史 BLOCKED 证据。本次完整复审获授权，但新的 D9 缺陷使结果再次 BLOCKED。
历史报告的 await-review 文案仍保留原时点事实；owner 新指令提供当前 CLOSED 状态。

## 3. Complete eight-commit milestone history

| SHA | Subject |
| --- | --- |
| 0e5ff6a5cbc8d4091102e280c66868ba8763b4bb | Analyze Migration Tooling v1 extraction contract |
| 8108763d6a4ddb3ad2b110200666424f4042e296 | Record Migration Tooling v1 P2 decisions |
| 8efc21ff8aa4c4c293347386f951631c56559fe2 | Add Migration Tooling v1 static room extractor |
| 1adb6534d579c5a2c1a4d21e166fb244096daa57 | Fix Migration Tooling v1 audit blockers |
| 864ebc4c8a749f3e56a39cd5cf0685b07765fd00 | Fix Migration Tooling v1 re-audit blockers |
| c0c7ffb3de3e26cadf395772f7503e71d3690e11 | Complete weapon and armor migration exclusions |
| 820d478587fd69d3cf20c861e2694497eac8ef79 | Complete remaining standard object migration exclusions |
| 8cc5a01741232ed062aff52bee0e77b4d4351b39 | Fix comment-prefixed directive recognition |

## 4. Complete diff scope

main...executable HEAD：**8 commits / 18 unique files / +4457 / -11**。

| 类别 | Files | Additions | Deletions |
| --- | ---: | ---: | ---: |
| P1/P2/P2F1–P2F5 报告 | 7 | 2125 | 0 |
| DECISIONS / STATUS / ROADMAP | 3 | 107 | 11 |
| tools/migration 生产代码 | 4 | 1031 | 0 |
| migration unittest | 1 | 1151 | 0 |
| 小 fixture / golden / README | 3 | 43 | 0 |
| reference / game / .github / Save schema | 0 | 0 | 0 |

没有 tracked whole-corpus 输出。本报告不是该冻结范围的 tracked 变更。

## 5. FR5-01 / MEDIUM — closed multiline directive comment falsely quarantined

最小完整输入：

```c
inherit ROOM;
#define LABEL 1 /* first
second */
void create(){set("short","safe");}
```

`LABEL` 未被使用，不需要宏展开、条件计算或 LPC 执行才能识别注释已闭合。
单行注释对照和独立多行注释对照均正常；仅将已闭合注释放入 directive 即触发错误。
即便该形态暂不纳入可抽取子集，也应保守报告 unsupported/semantic findings，不能把工具切片
造成的未闭合片段当成原始文件的正向语法损坏证据。

| 真实 CLI 样本 | 换行 | exit | candidate | status | fields |
| --- | --- | ---: | --- | --- | --- |
| 指令内部跨行块注释 | LF | 1 | false | QUARANTINED | [] |
| 指令内部跨行块注释 | CRLF | 1 | false | QUARANTINED | [] |
| 指令内部同一行块注释，对照 | LF | 0 | true | PARTIAL | inherit, short |
| 指令内部同一行块注释，对照 | CRLF | 0 | true | PARTIAL | inherit, short |
| 指令后独立跨行块注释，对照 | LF | 0 | true | PARTIAL | inherit, short |
| 指令后独立跨行块注释，对照 | CRLF | 0 | true | PARTIAL | inherit, short |

两个失败样本唯一 finding 都是 SOURCE_SYNTAX_ERROR，reason=`unterminated block comment`。
四个对照均产生 REQUIRES_SEMANTIC_REVIEW 与 UNSUPPORTED_CONSTRUCT。
六次均为真实 CLI subprocess，外部 TemporaryDirectory 隔离，退出后自动清理。

原字节证据：

| 换行 | directive token span | token text | `/*` start | 完整源码 `*/` start |
| --- | --- | --- | ---: | ---: |
| LF | [14,39) | `#define LABEL 1 /* first\n` | 30 | 46 |
| CRLF | [15,41) | `#define LABEL 1 /* first\r\n` | 31 | 48 |

原始源码各有且仅有一对 `/*` 与 `*/`。错误 span 只覆盖注释前半段。

根因链：

1. [es2_source.py](../../tools/migration/es2_source.py):140–151 的 directive 收集器只判断物理换行与末尾反斜线，不维护指令内块注释状态。
2. [room_extractor.py](../../tools/migration/room_extractor.py):60–80 的 directive_parts 重新 lex 截断的 analysis view，于完整原文件中不存在的片段边界抛 SourceError。
3. 同文件:352–354 的条件检测会调用 directive_parts；:361–368 将该错误视为对象源码错误并 QUARANTINED。

直接复现脚本与完整输入、原始 SHA、token、finding provenance 保存在 ignored
`build/migration-tooling-v1/final-p2f5/blocker_reproduction.py` 和 `blocker-reproduction.json`。
该问题是保守失败的分类错误，未发现由此输出危险 fact，故定为 MEDIUM；仍实质违反 D9，必须阻塞。
未改变任何生产规则或补测试。实际语料是否存在该具体形态未继续专项普查，不作零影响断言。

## 6. D1–D9 assessment

| Decision | 本次证据 / 判定 |
| --- | --- |
| D1 | PASS：已读四个模块，Python stdlib/local imports，无 Godot/LPC runtime 或第三方 parser |
| D2 | 已检查的 direct-ROOM、globals、weapon/armor、宏及 include 回归 PASS；完整独立复核因 stop 未完成，不宣称全局准入 PASS |
| D3 | 已检查字段 allowlist、create/set 边界与真实样本通过；未完成剩余独立恶例覆盖 |
| D4 | PASS：schema1/static-room-v1 独立 IR；canonical UTF-8 有序数组，A/B 一致；无 Save 耦合 |
| D5 | PASS：全语料 9838 个 provenance 独立字节/哈希/行列核验，加独立 invalid-UTF8 raw_hex 探针；Unicode/CRLF/续行/注释前缀回归通过 |
| D6 | PASS（已检查实现）：不执行 LPC/macro/条件/closure/RNG/arithmetic/inherited defaults；仅现有窄 __DIR__ literal normalization |
| D7 | PASS：独立八组合拒绝攻击，合法 build/external 成功，其他 checkout tracked 文件保护 |
| D8 | PASS（已检查材料）：unittest、手写小 fixture/golden、手审 authority table；未新增/自动接受 golden |
| D9 | **BLOCKED：FR5-01 将已闭合跨行注释错误标为 SOURCE_SYNTAX_ERROR，exit1 / QUARANTINED** |

未完成项与通过项明确分开；不以已有套件通过替代被中止的完整审计。

## 7. Historical blocker matrix

“CLOSED”在此指其原指定复现/回归本次重新通过，不代表本次里程碑放行。

| Finding | Severity | 原复现状态 / 本次证据 |
| --- | --- | --- |
| H1 output confinement | HIGH | CLOSED；八组合独立探针 |
| H2 continued macro shadow | HIGH | CLOSED；LF/CRLF、四关键名、拆分名称/关键字回归 |
| M1 literal excluded base | MEDIUM | CLOSED；精确字面基类回归 |
| M2 unresolved include | MEDIUM | CLOSED；direct/transitive 回归 |
| M3 computed mapping | MEDIUM | CLOSED；balanced/computed 与 malformed 对照回归 |
| F2-H1 nested metadata overwrite | HIGH | CLOSED；六版本既有矩阵 + 独立33个字典节点 |
| F2-M1 MONEY / COMBINED_ITEM | MEDIUM | CLOSED；symbol/literal 四形式回归 |
| P2F3 weapon/armor completeness | MEDIUM | CLOSED；九武器、十一护甲及 authority drift 回归 |
| P2F4 globals standard objects | MEDIUM | CLOSED；四剩余类别及 globals authority 回归 |
| FR-01 comment-prefixed directives | HIGH | CLOSED；P2F5十方法含四个真实 CLI 回归 |
| FR5-01 directive 内跨行块注释 | MEDIUM | **BLOCKED；本次独立真实 CLI LF/CRLF 复现** |

## 8. FR-01 / lexer line-prefix audit

新跑的104项包含全部 P2F5 十方法：define ROOM/set/create/__DIR__、undef 四名称、
缺失/可解析 include、六种 conditional、三种续行、单/多/跨行前缀注释、旧行代码加注释尾。
每项相关矩阵均覆盖 LF/CRLF。同行已有代码后的 #、注释/字符串/heredoc/array-heredoc 内 #
均保持不透明；原始 byte offset、SHA、行列断言均通过。

既有 `test_original_fr01_real_cli_four_cases` 本次确实启动四次 CLI：define/set LF/CRLF
均 exit0 / candidate=true / PARTIAL / fields=[inherit]；conditional LF/CRLF 均
exit0 / candidate=false / OUT_OF_SCOPE / facts=[]。宏例包含 UNSUPPORTED_CONSTRUCT，
条件例包含 DRIVER_SEMANTICS_UNKNOWN。没有将此前执行结果当作本次证据。
计划中的另一组独立 FR-01 CLI 全 finding-code 记录因 stop 未执行。
FR5-01 发生于 directive 内部跨行注释，与已关闭的 directive 前缀 trivia 问题不同。

## 9. Output confinement / closed schema

外部临时 source root；output-root 指向 repository parent。game、reference/es2、docs、
repository root 任意文件 × absolute/parent-relative 两形式，**8/8**：exit2、writer 未调用、
目标不存在、父目录条目不变。没有先写保护目录再清理。合法 ignored build 和外部输出均 exit0；
另建临时 git checkout 暂存 owner data，目标 tracked 文件拒绝覆盖，字节未变。

版本1.0.0–1.0.5 六份完整 canonical UNREVIEWED 输出均重新识别并实际替换为1.0.5。
独立遍历代表输出的全部33个 dict 节点逐个加入 manual note，包括 document、manifest/entry、
object、inherit、fact/finding、各 provenance、normalization/input、typed value、exit reference、
summary/status/finding count；**33/33** exit2、writer 未调用、原字节不变。
既有六版本×21层×两种未知字段=252组合亦随套件通过；unknown version、reviewed、
假 metadata-only、manifest/summary 不一致、错误 typed value 回归通过。

## 10. Authority completeness / SSERVER

重新读取 globals.h、weapon.h、armor.h，以及 std/bboard、char、char/npc、equip、
medicine/powder、skill、sserver。globals 中 ROOM 为唯一 generic room；BANK/CLASS_GUILD/
HOCKSHOP 为专用房间排除；其余已分类14项中的非ROOM对象均在现有精确排除策略覆盖。
九种 weapon、十一种 armor 的 symbol/literal 对照回归通过；F_* feature 与 TYPE_* 类型标签
没有被当作新标准对象类别加入。

SSERVER 的实际源码仅继承 F_CLEAN_UP，并定义 offensive_target，从敌人数组中选目标；
与明确自称 skill daemon skeleton 的 std/skill.c 不同。原始全语料文本搜索已找到 SSERVER
在 force/spell/action 文件中的引用，也包括一个 recover.d 非C/H文件；未见 literal /std/sserver
继承命中。该搜索只是候选定位，计划的完整独立 code-only / direct-ROOM 联合统计因 stop 未完成。
因此不变更已获 owner 接受的 helper 解释，也不宣称本次已完成其最终独立准入结论。

## 11. Fact / create / exit boundary

实现字段限制为 inherit、short/name/long、四 flags、exit；long 标记 TEXT_ONLY。
只从一个无歧义 create 的 bare local set 抽取；foreign receiver、nested/control flow、duplicate
create、set/create 阴影及 reset/init 回调的既有回归本次通过。零值保留、缺失不填默认。
没有执行门、人口、继承默认、回调、动态状态或任意 setter 字段。

exit 保留顺序与重复方向、direction_raw/target_raw；支持 literal 与既有 __DIR__ literal
拼接（直接相邻或显式 +），无其他表达式计算。reference 只描述存在/大小写/缺失等状态，
不补反向边、不修路径、不承诺可达、不执行 mutation/RNG。剩余独立边界扩展因 stop 未执行。

## 12. Full provenance and record integrity

独立检查新生成语料的 **全部9838个 provenance**，无抽样：

| 类别 | 数量 |
| --- | ---: |
| direct_inherit | 1799 |
| fact | 2804 |
| finding | 4457 |
| normalization input | 778 |
| 合计 | 9838 |

每条检查范围、实际源 SHA、raw==原始字节片段、LF计行、原始行内 Unicode codepoint 列。
覆盖1295个含非ASCII字节的 span、3个来自 CRLF 源文件的记录；当前语料 raw_hex 为0。
另用0xFF源作独立 raw_hex 探针，确认hex对应原 span且无法解码UTF-8。
续行及注释前缀的Unicode/CRLF provenance 另有新跑测试覆盖。

还独立校验所有fact_id重算、事实源码顺序、finding_id顺序及object引用、summary计数、
manifest文件大小/SHA及完整磁盘文件集合。OUT_OF_SCOPE/QUARANTINED facts均为空。
fact/finding共7261条review_state独立核验UNREVIEWED；其他层由新跑闭合schema检查覆盖。

一次性审计脚本先修正了自建source索引未区分source-root/mudlib同名路径的问题；未修改生产代码。
之后所有断言完成并写出corpus-evidence.json，末尾控制台打印因GBK不能显示U+FFFD而失败；
这是审计脚本显示问题，不是扫描/校验失败，完整UTF-8证据文件已检查。

## 13. Real-source review

| 实际源码 | 本次阅读与边界核对 |
| --- | --- |
| obj/roommaker.c | 实际 ITEM + F_AUTOLOAD；两个ROOM_CODE是模板文本；既有真实源回归不准入 |
| d/city/street1.c | literal short、TEXT_ONLY long、north/south/west有序__DIR__出口、outdoors；setup/replace_program不执行 |
| d/snow/school1.c | 两个静态出口可提取；objects数量、门与look_door closure仅findings |
| d/oldpine/pine3.c | 四个random相关出口不固化；原文件名不被错误首行注释覆盖 |
| d/oldpine/keep2.c | 初始两出口与后续delete/reset/pipe_notify分离，不计算动态可达性或五个spawn |
| d/village/lake.c | literal exit与no_clean_up=0保留；init、replace_program、递归valid_leave不推断运行语义 |
| 五个指定损坏样本及其余隔离对象 | 逐项正向损坏证据见下表 |

## 14. Fresh local suites / documentation validation

精确执行身份均为8cc5a01741232ed062aff52bee0e77b4d4351b39：

| 检查 | 实测 |
| --- | --- |
| migration unittest | 104 PASS |
| full Python unittest | 150 PASS |
| repository/static | PASS |
| git diff --check | PASS |
| 16份相关文档本地Markdown链接 | 220 checked，0 failures |
| 其中Markdown anchors | 10 checked，0 failures |

链接检查覆盖本里程碑全部已提交Markdown、STATUS/ROADMAP、DECISIONS、根/docs AGENTS、README、
仓库策略、架构分析、fixture README；检查目标存在、tracked状态及anchor。
没有指向untracked历史audit并伪称已提交的链接。该统计为新BLOCKED报告创建前证据。
历史文档的完整叙述一致性和全diff敏感信息审计尚未完成，不把链接检查说成内容审计。
没有新的远端CI。

Godot gameplay canonical suite not required/run for this tooling-only Final Re-Audit.

## 15. Actual comment-prefixed corpus inventory

**PENDING / STOPPED**。计划中的独立C/H词法inventory尚未运行即发现FR5-01。
不复制P2F5“1817文件、0 occurrence”历史结论；本次不报告新occurrence/paths/kinds/ROOM影响数。

## 16. Fresh full corpus A/B

输出位于 ignored `build/migration-tooling-v1/final-a/static-rooms.json` 和
`build/migration-tooling-v1/final-b/static-rooms.json`，传CLI的--output为这两个路径的绝对形式。
因一次性独立checker索引修正而重新生成两次；下列取最后一对新跑结果，非复制历史输出。

| 指标 | A | B |
| --- | ---: | ---: |
| exit | 1 | 1 |
| scanned | 2336 | 2336 |
| supported | 499 | 499 |
| EXTRACTED | 0 | 0 |
| PARTIAL | 499 | 499 |
| OUT_OF_SCOPE | 1824 | 1824 |
| QUARANTINED | 13 | 13 |
| facts | 2804 | 2804 |
| findings | 4457 | 4457 |
| bytes | 10030223 | 10030223 |

两者SHA-256均为 `618056b67e63a3d3322b9f451b0eadef86f6966fd442c8f832c731dc7043264c`，
逐字节相等。finding分布为：REQUIRES_SEMANTIC_REVIEW1713、OUT_OF_SCOPE1305、
UNSUPPORTED_CONSTRUCT484、DRIVER_SEMANTICS_UNKNOWN410、CALLBACK_BEHAVIOR326、
UNRESOLVED_INCLUDE97、RNG_SEMANTICS62、ORDER_SENSITIVE_MUTATION36、DYNAMIC_EXPRESSION11、
SOURCE_ENCODING_ISSUE8、SOURCE_SYNTAX_ERROR5；其余代码0。

## 17. Individual quarantine review

以下均重新读取实际源字节；**13/13事实为空**，分类与正向原因相符，没有把这些13个既有对象
仅因不支持合法表达式而隔离。路径相对reference/es2/mudlib；行号按原始LF索引。
这不抵消合成FR5-01证明的另一种误隔离路径。

| 路径 | 类别 | 原始源码正向证据 / 结果 |
| --- | --- | --- |
| cmds/std/exercise.c | encoding | L57，U+FFFD共1个，消息文字损坏；PASS |
| d/choyin/npc/yamen_po.c | encoding | 首处L123，U+FFFD共3个；PASS |
| d/latemoon/upstar/upcenter.c | encoding | L11 heredoc内U+FFFD共1个；PASS |
| d/temple/npc/obj/magic_book.c | encoding | L24注释内U+FFFD共1个；按既有源损坏策略隔离，PASS |
| d/temple/npc/obj/spells_book.c | encoding | L24注释内U+FFFD共1个；PASS |
| d/temple/obj/magic_book.c | encoding | L24注释内U+FFFD共1个；PASS |
| d/temple/obj/spells_book.c | encoding | L24注释内U+FFFD共1个；PASS |
| u/cloud/obj/npc/flower_girl/guihua.c | encoding | 原文件338个NUL、110个U+FFFD，首个NUL byte4；PASS |
| d/latemoon/sroad1.c | syntax | north项缺闭引号，后续引号错位；最终L15出现未闭字符串；PASS |
| d/npc/oldman.c | syntax | kill_ob内字符串/参数尾缺对应调用开头，L145多余右括号；PASS |
| d/village/lordhouse3.c | syntax | 条件开头被注释而右花括号保留，L81多余闭括号；PASS |
| u/cloud/npc/goddd.c | syntax | give_quest消息中`说:" 就凭`提前闭合字符串，后续引号错位，末尾L161未闭；PASS |
| u/cloud/obj/sword_book.c | syntax | set("long", 内又嵌残缺et("long",，外层调用未闭，L27错配；PASS |

## 18. Source / protected artifact integrity

reference Git tree：`4106480ab28cce8cd7b55704f8ae9ae062d42d03`，开始及结束一致。
磁盘/tracked source文件均2336，路径集合相等；独立逐字节manifest：

- repo-relative：`744e33e1740db7909129a3ae5e295158341b5012a411af953b144a5075bb0a80`
- extractor source manifest：`895d36086e184ba6bf520625c20e882394a0a6169aabf86a1b4c58ba835e2820`

没有source repair、source/game/Save/CI写入，没有保护目录探针残留；临时source/output仅在
TemporaryDirectory中，审计脚本/JSON在ignored build。没有跟踪语料、第三方依赖、LPC执行或Native生成。
完整milestone敏感信息/机器路径/许可内容审查在stop时未全部完成，不据此出最终安全放行结论。

## 19. Historical audit immutability

三个文件始终只读、untracked、unstaged。开始及结束摘要一致：

| docs/migration下文件 | SHA-256 |
| --- | --- |
| MIGRATION_TOOLING_V1_FINAL_AUDIT.md | a61cd221e8b70961d963484dfe953f5e341511967d9cfd66a55159b1bab85d63 |
| MIGRATION_TOOLING_V1_RE_FINAL_AUDIT.md | c67dc612139bf37a6c6a41d4753b58723b154d0f6e92cdca0ab5a34ad93d0548 |
| MIGRATION_TOOLING_V1_FINAL_RE_AUDIT_AFTER_P2F4.md | c4ff8faccea5b79d0ba4007d2d616007f4a55fda3b84e58e78875d68f4e4aed0 |

## 20. Residual risks / unfinished work / owner gate

FR5-01为MEDIUM material defect，不降格成残余风险。原有bounded lexer非完整LPC grammar、
有效但不支持语法的遗漏、预处理/driver语义、源码损坏、大小写路径、filesystem TOCTOU、
约10MB canonical输出、格式识别不等于密码学作者证明、SSERVER未决helper语义、无PR CI、
无Native consumer以及license/provenance/public-release风险，仍须后续完整复审逐项评估分级。
本次不声称这些全部已获得PASS WITH RESIDUAL RISKS的处理结论。

按owner的发现即停止规则，未完成的主要项目：独立实际注释前缀C/H inventory、SSERVER完整
code-only/direct-ROOM联合统计、其余新增边界恶例、全部历史叙述一致性、完整敏感artifact审查及
最终风险分级。已完成的全provenance、13文件隔离逐项检查和220链接/10anchor验证在上文保留。

最终tracked worktree/index仍干净；仅新增本报告，因此允许的untracked集合从3变4。
没有docs-only提交，没有push。下一步仅等待owner审阅FR5-01并决定是否单独授权修复；
不能创建PR，不合并，不开始P3，也不自行继续审计或实施。

**MIGRATION TOOLING V1 FINAL RE-AUDIT AFTER P2F5 BLOCKED**

**NOT READY FOR PR — AWAIT OWNER REVIEW**
