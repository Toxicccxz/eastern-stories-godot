# Migration Tooling v1 — P1 Source / Extraction Contract Analysis

日期：2026-09-15。**P1 分析完成，提案等待 owner review；未实施 extractor，P2 未授权。**

## 1. Objective and non-goals

设计一个可重复、可追溯的 ES2/LPC 半自动提取流程：机器整理明确的源码事实及疑点，
人审查继承、条件、状态变更与 Native 表达。目标是减少机械抄写和漏项，不减少语义审查。
ES2 决定 WHAT / WHY / RESULT；Godot 决定架构、物理世界、交互和表现。

这不是 LPC→GDScript 编译器、LPC/MudOS 模拟器、通用预处理器、自动内容迁移器或
一键场景生成器。P1 不创建工具生产代码、测试 fixture、输出 schema 文件、游戏内容或新语义决定。
默认迁移意图为 Type A；偏离原作必须有独立、明确、有限的 Type B 批准；Type C 未获批准不得实施。
**词法提取置信度与 Type A/B/C 是不同维度。机器不得把成功解析标为已获迁移批准。**

## 2. Authoritative baseline and ordered branch preparation

| 身份 | 值 |
| --- | --- |
| Repository | `Toxicccxz/eastern-stories-godot` |
| 唯一基线 main / P1 parent | `cd07808cb76147d0b8c0dad9b82d078b49fefe64` |
| 基线来源 | Snow First Progression [PR #19](https://github.com/Toxicccxz/eastern-stories-godot/pull/19) 标准 merge commit |
| 已接受的基线门禁 | post-main [run 34985105844](https://github.com/Toxicccxz/eastern-stories-godot/actions/runs/34985105844)，既有完成证据；本 P1 没有运行远端 CI |
| 初始本地分支 / HEAD | `main` / 上述基线；worktree/index clean |
| 新阶段分支 | `phase/migration-tooling-v1`；建立前本地、远端均不存在 |
| 建立时 HEAD / merge-base | 两者均为上述基线 |
| `reference/es2` Git tree | `4106480ab28cce8cd7b55704f8ae9ae062d42d03`，只读 |

先结束历史分支清理，再建立新阶段。下列候选最初本地、远端均存在；每个远端 tip 都经
`git merge-base --is-ancestor origin/<branch> origin/main` exit0 验证，随后逐个普通远端删除。
本地在精确 main 上仅使用 `git branch -d`。清理没有产生提交；建立新阶段后不再清理。

| 候选分支 | 删除前精确 tip | 远端 | 本地 |
| --- | --- | --- | --- |
| `phase/10d-post-redesign-release-validation` | `6817832f161edbe1005b2ce99819962ce61f0124` | 已删除 | 已删除 |
| `docs/phase10d-integration-closure` | `1d6857e290c61049cd88b09c0b51ff4e2d8daf8c` | 已删除 | 保留：worktree 占用，安全删除拒绝 |
| `phase/beast-foundation-serpent-runtime` | `0ab0d68c44ba9844d477eed4c1ed0670707bf9a9` | 已删除 | 保留：worktree 占用，安全删除拒绝 |
| `codex/hotfix-viewport-config` | `1753aa428e0e0feb74298ee2dd3ea24c8064ae5e` | 已删除 | 保留：worktree 占用，安全删除拒绝 |
| `phase/start-of-game-source-rebaseline` | `b0a58c205253cf5fcb3f35bac7dab22d403c9c67` | 已删除 | 已删除 |
| `phase/source-valid-new-game-entry` | `56ae4ba9bf20b2d7d81b7b9fb5ea5854b23662e2` | 已删除 | 已删除 |
| `phase/snow-town-core-hub` | `8f33739e19542f04ff42a4dc0c1ee95f4d5d73ad` | 已删除 | 已删除 |
| `phase/snow-hockshop-loot-monetization` | `c37645dfffd3584ae80072a70d15634947f8ae5d` | 已删除 | 已删除 |
| `maintenance/post-hockshop-integration-closeout` | `e70801417c9049128fc0e0e7dca07f7940906ec4` | 已删除 | 已删除 |
| `phase/snow-first-progression-loop` | `f8e2e000d6e2e425ed50508c2609eedf5ab73215` | 已删除 | 已删除 |

初始真实分支共 12 个本地、12 个远端，不把 `origin/HEAD` 别名另算一个分支。
始终保留 `main`，以及本地/远端 `phase/10d-technical-demo-release-gate`
(`26fef9512355eaa851b268d2b2ae7fc955915aa4`)；没有未知候选或祖先检查失败。
另保留上表三个受 worktree 保护的本地分支，未用 `-D`、未改动那些 worktree。
清理后、建立新阶段前：5 个本地分支、2 个远端分支；新阶段不覆盖任何历史 ref。

已阅读 [root AGENTS](../../AGENTS.md)、[docs AGENTS](../AGENTS.md)、
[DECISIONS](DECISIONS.md)、[STATUS](../production/STATUS.md)、[ROADMAP](../production/ROADMAP.md)、
[README](../../README.md)、[最终 Snow 审计](PHASE_SNOW_FIRST_PROGRESSION_FINAL_AUDIT.md)、
[ES2 架构分析](ES2_ARCHITECTURE_ANALYSIS.md)、
[开局源码重基线](PHASE_START_OF_GAME_SOURCE_REBASELINE.md)、
[Learn 依赖分析](PHASE_3C0_LEARN_DEPENDENCY_ANALYSIS.md)、
[Snow P1](PHASE_SNOW_FIRST_PROGRESSION_SOURCE_ANALYSIS.md)及
[仓库策略](../production/REPOSITORY_POLICY.md)。发现的适用 AGENTS 只有根目录和 docs 两份。
当前架构记录实际在 `docs/migration/ES2_ARCHITECTURE_ANALYSIS.md`；没有 `docs/ARCHITECTURE.md`。

实际代码/源码与当前 owner 决定优先；STATUS/ROADMAP 仍保留审计前 PR 待授权措辞，
不能推翻已经完成的 #19 集成和本次 P1 授权。没有规则强制 P1 更新这两份文件，故遵照
本次范围保持原样，DECISIONS 也不变。对 migration tooling/extractor/source extraction/LPC/
reference 的搜索未发现现有生产 extractor；已有 autoload/save importer 是不同的领域边界，不能复用为源码执行器。

## 3. Real ES2 corpus census

### 3.1 Method and limits

本次重新计算，未照抄历史计数。文件集合由 `git ls-files -z -- reference/es2` 给出，
并与磁盘递归文件集合逐个比较：一致，无额外文件。大小取当前原始 bytes。
`.c` 是待分析 LPC 对象候选，`.h` 是依赖头文件；扩展名本身不证明有效语法或可加载性。

临时词法普查脚本与结果位于忽略的 `build/mtv1-census*`，不进入提交。
扫描先识别注释、双引号字符串、单字符字面量和 `@TAG`/`@@TAG` 多行文本，
再计数 identifier/token；不展开条件编译，不执行函数，不运行 LPC driver。
下列 call-like 计数是“标识符后跟左括号”的出现次数，**包含定义、声明及调用**，
不是执行次数、唯一规则数或成功事件数。按文件去重的数量另列。
损坏文件仍属于 corpus 分母，词法结果只能作为审查候选，不能成为合格对象。

可复算步骤：固定基线及 source tree → 按 POSIX 相对路径排序清单 → 读取原始 bytes →
统计后缀/目录/大小 → UTF-8 严格解码并另查 NUL/U+FFFD → 屏蔽注释/字符串/多行文本 →
计数继承及 call-like token → 对 `set("exits", expression)` 平衡括号分参 →
检查窄字符串 mapping 模式 → 按文件去重。此算法只是普查定义，不是未来 parser 合格标准。

当前全文件清单摘要 SHA-256：
`744e33e1740db7909129a3ae5e295158341b5012a411af953b144a5075bb0a80`。
排序使用完整 POSIX 路径的区分大小写 Unicode codepoint 顺序，不使用 Windows Path 比较规则。
计算输入为每个排序路径 `reference/es2/...` 的 UTF-8 bytes、NUL、该文件 bytes 的
SHA-256 小写 hex、LF，顺序拼接后再 SHA-256。摘要绑定本次磁盘 bytes；不是 Git tree hash。

### 3.2 Counts and distribution

| 项目 | 本次实测 |
| --- | ---: |
| 全部 tracked / 磁盘文件 | 2,336 / 2,336 |
| `.c` / `.h` / 二者合计 | 1,777 / 40 / 1,817 |
| 无后缀 / 其余后缀 | 491 / 28 |
| 全部 bytes | 3,229,497 |
| `.c` + `.h` bytes | 2,088,620 |
| `.c` 物理行 | 78,142（LF 计行，非空末行也计一行；空文件为0行） |
| `.c`/`.h` UTF-8 解码成功 | 1,817；不等于原文无损或语法正确 |
| 含 CRLF 的 source/header 文件 | 2 |
| `.c` 含 NUL / 含 U+FFFD | 1 / 8；有重叠 |

其余后缀含 `.c%`、`.o`、`.new`、配置、备份与文本等；不自动按 LPC 执行。
`.c` 一级目录：`d` 1,150；`daemon` 148；`cmds` 130；`u` 120；`obj` 74；
`adm` 66；`std` 46；`feature` 27；`quest` 16，合计 1,777。

| `d/` 子目录 | `.c` | `d/` 子目录 | `.c` |
| --- | ---: | --- | ---: |
| canyon | 54 | choyin | 128 |
| chuenyu | 100 | city | 100 |
| death | 19 | force | 3 |
| goathill | 36 | graveyard | 2 |
| green | 63 | jail | 1 |
| latemoon | 205 | npc | 3 |
| oldpine | 80 | sanyen | 44 |
| skill | 47 | snow | 107 |
| temple | 59 | village | 40 |
| waterfog | 53 | wiz | 6 |

目录不是语义分类；`d/skill` 不是地区，`u/` 含其他作者版本，不把同名文件合并为同一身份。
`daemon/class` 71、`daemon/skill` 70、`daemon/condition` 7；`adm/daemons` 56。
`cmds` 子目录 std51、usr24、wiz30、arch11、imm9、adm3、debug2，总数130。

### 3.3 Likely types and structural patterns

以下为直接继承/显式标记候选，**各行可重叠，不是活跃 world 实例总数**。
宏名以 [globals.h](../../reference/es2/mudlib/include/globals.h)、
[weapon.h](../../reference/es2/mudlib/include/weapon.h)、[armor.h](../../reference/es2/mudlib/include/armor.h)核对。

| 候选 | 文件数 | 判定口径 |
| --- | ---: | --- |
| ROOM | 559 | 去掉注释及文本后直接 `inherit ROOM` |
| Room family | 564 | ROOM559 + BANK2 + CLASS_GUILD2 + HOCKSHOP1 |
| NPC | 307 | 直接 `inherit NPC`；NPC 标准对象自身继承 CHARACTER，不包含在307内 |
| ITEM | 134 | 直接 `inherit ITEM`，不是所有可携带物 |
| Weapon / armor | 140 / 149 | 对应标准类型宏或 `/std/weapon/`、`/std/armor/` 直接继承 |
| Food / liquid | 40 / 11 | F_FOOD / F_LIQUID 标记 |
| Vendor / master | 27 / 18 | F_VENDOR / F_MASTER 标记，不等于公开服务数量 |
| Container-like ITEM | 3 | bag、slipcase、corpse 含 `is_container()`；功能含义仍须人工读 |

`set_max_encumbrance(...)` 在11文件出现12次，包括 Character/feature；不能据此把所有11文件归为容器。
ROOM 中 city54、choyin62、latemoon74、oldpine41、snow36；Snow 另含 BANK/HOCKSHOP，
不能把36解释成原作全 Snow 房间数。旧架构文档的561是文本搜索匹配口径：
[roommaker.c](../../reference/es2/mudlib/obj/roommaker.c):68–79、128–137 的两个 ROOM_CODE
文本块各含一次 `inherit ROOM`，但该对象实际继承 ITEM + F_AUTOLOAD。排除这两个文本匹配得到559。

| 词法形态 | 出现次数 | 涉及文件 |
| --- | ---: | ---: |
| inherit 声明 | 1,828 | 1,680 |
| 多个 inherit 的文件 | — | 127 |
| heredoc 文本块 | 769 | 751 |
| 成功分参的 `set("exits", ...)` | 546 | 546 |
| 其中仅字符串键/值 mapping | 119 | 119 |
| 字符串或窄 `__DIR__`/字符串拼接 mapping，含前119 | 533 | 533 |
| 其余 exits 表达式 | 13 | 13 |
| `set/add/delete("exits/<literal>", ...)` | 28 | 9 |
| `set("objects", ...)` | 231 | 231 |
| create_door call-like | 94 | 91 |
| set_skill / map_skill call-like | 1,167 / 286 | 223 / 113 |
| create_family call-like | 50 | 50 |
| attempt_apprentice / recruit_apprentice call-like | 17 / 25 | 17 / 14 |
| carry_object / new call-like | 401 / 97 | 212 / 66 |
| wield / wear call-like | 124 / 261 | 118 / 187 |
| set combat_exp / score | 286 / 78 | 285 / 77 |
| random call-like | 525 | 206 |
| call_out / add_action call-like | 141 / 187 | 96 / 138 |
| closure `:)` token 对 | 369 | 213 |
| valid_leave / valid_learn / valid_enable call-like | 71 / 65 / 45 | 41 / 65 / 45 |
| heart_beat call-like | 1 | 1 |
| replace_program call-like | 403 | 403 |
| 跨对象箭头 `->` | 4,354 | 687 |
| destruct / save_object / restore_object call-like | 79 / 9 / 6 | 59 / 4 / 4 |

显式属性 set 次数/文件数：str161/158、cor119/116、cps88/85、int102/101、con49/48、
spi43/42、per51/50、kar21/20；force134/131、max_force132/129、force_factor117/115。
它们包括动态赋值、跨对象写入和重复赋值，不全是 NPC 的 literal 初始属性。
静态 exits 表达式也可能出现在回调或受后续 mutation 影响，533 **不是 P2 可直接迁移的房间数**。
9文件的局部 exits 变更不是完整动态图计数：变量索引、别名和跨对象修改需要依赖分析。
大量类共享唯一 `std/char.c::heart_beat`，因此1绝不意味着只有一个实体有 heartbeat。

## 4. Representative source patterns and findings

以下源码分析以该 source tree 为基准；相对链接指向仓库文件，行号按本次原文件，未运行 LPC server。

| 来源 / 位置 | 可见事实 | 不能自动推出的结论 |
| --- | --- | --- |
| [city/street1.c](../../reference/es2/mudlib/d/city/street1.c):3–24 | ROOM、short、heredoc、三个 `__DIR__` exits、outdoors | 文本里的镖局故事不是任务/奖励；邻接不是自动 Godot scene |
| [snow/school1.c](../../reference/es2/mudlib/d/snow/school1.c):16–28 | 两个 literal exits、guard数量1、create_door、look_door closure | 注释 sizeof不决定数量，描述“两只石狮”不创建两个NPC；门状态须读继承 |
| [city/eastdoor1.c](../../reference/es2/mudlib/d/city/eastdoor1.c):24–55 | out出口被注释，但仍create_door(out)；valid_leave消费mark | 不补回出口；[std/room.c](../../reference/es2/mudlib/std/room.c):150–157会检查缺失exit，需记录源矛盾 |
| [oldpine/pine3.c](../../reference/es2/mudlib/d/oldpine/pine3.c):14–20 | 四个 random-dependent出口表达式 | 不取随机值、不展开成保证可达边、不用文件首行错误pine1注释改身份 |
| [oldpine/keep2.c](../../reference/es2/mudlib/d/oldpine/keep2.c):18–76 | 静态表、valid_leave封路/生成五个攻击者、reset/pipe_notify开路 | 静态边不代表总可行；不能把五个条件spawn并入常驻数量 |
| [village/lake.c](../../reference/es2/mudlib/d/village/lake.c):20–55 | replace_program与本地init、paddle/dive、未限定valid_leave递归调用并存 | 不假定callbacks仍存活或自动修正为 `::valid_leave`；标为生命周期/调用审查 |
| [city/npc/guard.c](../../reference/es2/mudlib/d/city/npc/guard.c):19–30 | str/cor/cps等被重复赋相同值 | 不静默去重；保持两个源码位置和顺序，不能凭重复推导双倍属性 |
| [canyon/npc/general.c](../../reference/es2/mudlib/d/canyon/npc/general.c):25–108 | literal属性/EXP/skills/maps，ordered carry→wield/ wear，accept_object | nickname有ANSI宏；两个相同name条件不能合并或自动修错；交换/容量/失败另审 |
| [Liu master](../../reference/es2/mudlib/daemon/class/swordsman/master.c):8–89 | 全部11skills、4maps、create_family、装备调用、拜师override | 老师知道不等于学生能学/用；不自动变成已获批的bounded contact |
| [oldpine/serpent.c](../../reference/es2/mudlib/d/oldpine/npc/serpent.c):7–33 | race野兽、limbs/verbs、临时apply、EXP/score | setup/race/战斗解释不可省略；不能把临时apply任意当永续buff |
| [snow/waiter.c](../../reference/es2/mudlib/d/snow/npc/waiter.c):3–69 | F_VENDOR、goods表、greeting RNG、条件cake生成 | goods不是有库存实例；日常greeting与生日赠礼不是同一规则 |
| [bag.c](../../reference/es2/mudlib/obj/example/bag.c):7–19 / [slipcase.c](../../reference/es2/mudlib/d/canyon/bamboo/obj/slipcase.c):8–23 | identity、weight、capacity、container方法；书匣会new书 | 可记语法，不执行is_container；容量并非所有容器都靠同一字段 |
| [short_sword.c](../../reference/es2/mudlib/d/oldpine/obj/short_sword.c):9–21 / [cloth.c](../../reference/es2/mudlib/obj/cloth.c):11–21 | literal value/weight、init_sword(15,SECONDARY)、armor_prop | init调用是依赖，不把参数无审查投成Native buff/slot |
| [dumpling.c](../../reference/es2/mudlib/obj/example/dumpling.c):8–18 / [wineskin.c](../../reference/es2/mudlib/obj/example/wineskin.c):8–26 | clone/default分支，food/current liquid与原型事实分开 | 文本八九升与max_liquid15不可换算；初始value不等于吃过后的value |
| [feature/dbase.c](../../reference/es2/mudlib/feature/dbase.c):15–51 | default_ob回退、query最终evaluate | 字面量缺失不是0；记录闭包不等于执行query得到值 |
| [std/char/npc.c](../../reference/es2/mudlib/std/char/npc.c):8–14,89–150 | carry new→move，chat/evaluate及skill daemon调用 | move返回未检查，不承诺携带成功；map不是自动技能效果 |
| [fonxansword.c](../../reference/es2/mudlib/daemon/skill/fonxansword.c) valid_learn/query_action | 内力/映射/持剑约束，动作随机选取 | action metadata必须追到实际消费者；valid_enable和valid_learn不同 |
| [learn.c](../../reference/es2/mudlib/cmds/std/learn.c):66–129 | integer费用、raw0先写、potential/teacher/gin/EXP门槛、spent→random→improve→gin | 失败可能保留已发生变化，不能重排、浮点化或事务回滚 |

真实源码质量问题需显式保留：

- [latemoon/sroad1.c](../../reference/es2/mudlib/d/latemoon/sroad1.c):11–14 的north项引号/冒号损坏，
  不属于546个成功分参的exit表；不能从注释或邻居自动补齐。
- [u/cloud sword_book](../../reference/es2/mudlib/u/cloud/obj/sword_book.c):13–18 出现嵌套残缺的 `et("long",`；
  [guihua.c](../../reference/es2/mudlib/u/cloud/obj/npc/flower_girl/guihua.c)含NUL、替换字符和拼接残片，必须隔离。
- U+FFFD还出现在exercise、yamen_po、upcenter及四个magic/spells book路径；成功UTF-8解码不证明原始汉字可恢复。
- 实际继承出现 DAEMON4、F_UNIQUE3、F_MERCENARY1；在当前include定义中未解析到它们。
  不构造猜测base或默认允许。其作用域与driver/include环境需审查。
- [config.ES2](../../reference/es2/mudlib/adm/etc/config.ES2):31,39–40声明/include及自动globals.h，
  所以不能以“文件没有显式include globals.h”为由推断ROOM未定义，也不能运行任意预处理代码。

## 5. Machine-extractable fact contract

所有字段都套用第9节 provenance；“高置信”仅指能证明这个源码构造存在。
区分 authored declaration 与运行时有效值。缺失字段保持 absent，不填0/false/当前时间/默认种族。

| 对象 | 可提取候选 | 规范化边界 / 后续依赖 |
| --- | --- | --- |
| 通用 | 路径、source hash、直接inherit原文、include引用、function/construct位置 | category可多标签/UNKNOWN；父类型解析记录依赖，不展平继承 |
| Room | literal short/name、long文本、exit键/目标、outdoors/indoors等显式静态flag | long/help永远TEXT_ONLY；exits为源邻接声明，不是物理位置/可通行保证 |
| Room人口 | `set("objects", ([path: integer]))` | 数量只来自literal值；保留列表顺序/重复键；reset/new/conditional另报 |
| Room门 | create_door的direction/name/other_side/status参数及位置 | 参数literal可记，DOOR_CLOSED等symbol留依赖；不得补默认状态或配对成功 |
| NPC身份 | set_name名字及有序aliases、nickname、gender、age | 显示名不作稳定ID；ANSI表达式不自动strip；姓名不能证明身份等价 |
| NPC属性 | 显式str/int/cor/cps/con/spi/per/kar、EXP、score、force/max/factor | 只记赋值目标/类型/条件；不应用human/race/setup默认公式 |
| NPC技能 | set_skill的skill/raw literal；map_skill的base→mapped引用 | raw不是effective；mapping不授权enable/learn/perform |
| NPC家族 | create_family的name/generation/title实参 | 调用参数不是最终关系，privs/master/entry time由继承/命令决定 |
| NPC装备 | carry_object、新建路径、wield/wear receiver关系和源码先后顺序 | `setup`前后、返回检查、间插mutation必须保留；不宣称生成或装备成功 |
| Item身份/数值 | name/aliases、unit、value、set_weight/base_weight等literal | clone/prototype/current状态分层；value可为方法/动态值，不能按名称补币种或单位 |
| Weapon/armor | inherit类别、init_*实参、明确weapon/armor属性 | SECONDARY等宏保持引用；派生damage/skill_type/slot须标准base审查 |
| Food/liquid/container | 明确portions/supply/liquid映射/capacity，相关mixins与方法引用 | 方法体/毁坏回调只记录，不能计算可吃次数、容量生命周期或自动导入Save |
| Actions/callbacks | 函数名、closure原文、source span、可见目标引用 | REFERENCES ONLY；无调用、执行或自动游戏效果 |

整数保留原token及十进制精确表示；不转换float，不做公式计算。
简单相邻字符串与显式字符串拼接可作为单独批准的 normalization 规则；保留组成token及来源。
任意宏、函数宏、变量插值、算术、条件表达式保持 unresolved。
`__DIR__`若获批仅做 source-relative path 的有名规范化，不运行driver；记录输入路径、规则版本、
宏冲突/include依赖。相对/绝对source路径分开，不把source `/d/...`当操作系统绝对路径。

## 6. Semantic/manual-review contract

| 构造 | 必须人工审查的内容 |
| --- | --- |
| callbacks / closures / function bodies | 参数、receiver、条件、调用次序、可达性、异常与副作用；不是可执行IR |
| inheritance / default_ob / setup | 覆盖、继承链、include条件、fallback、初始化先后；不能猜测/复制base行为 |
| valid_learn / valid_enable / recognition | 不同的准入问题；[std/skill.c](../../reference/es2/mudlib/std/skill.c):23存在明确default，不代表任何missing函数都allow |
| recruitment overrides与继承 | teacher attempt→command recruit→feature结果→class；时间、重复拜师、betrayer另审 |
| raw/effective技能与属性 | [skill.c](../../reference/es2/mudlib/feature/skill.c):63–78包含raw/2、映射技能、temporary apply；[attribute.c](../../reference/es2/mudlib/feature/attribute.c)含有效属性规则 |
| mutation / partial failure / no rollback | raw0可在potential拒绝前建立；spent可在后续失败前消耗；必须审计发生顺序 |
| integer math / RNG | 截断顺序、符号、零除、overflow边界、bounds/draw次序；不计算随机常量或使用全局random(0)假设 |
| lifecycle / destruction / replacement | clonep/default、new/move/destruct、replace_program、返回失败与残留状态 |
| Save/Load / delayed calls / heartbeat | transient vs persistent、真实tick/callback时序、历史缺失值；不推出Native schema或offline行为 |
| command dispatch / combat chain | user input、authority、跨对象/daemon读写、反击链与先前effects；不从action标签制造伤害 |
| dynamic mappings/exits/spawns | alias mutation、索引表达式、条件创建、reset再生、find_object/load差异 |
| missing/undefined functions / driver | unknown与显式default有别；缺头文件、未定义宏、varargs缺省、missing lfun、历史driver语义需独立证据 |

源 [combatd.c](../../reference/es2/mudlib/adm/daemons/combatd.c):362–366 的防御循环与
已批准ZE1是具体例子：提取器只能指出random边界；不能复制ZE1为普遍源规则。
已有 DECISIONS 的 Native pending、门瞬态、UNKNOWN入门时间、有限contact等决定也不能
自动套用到其他对象。继承解析成功只建立审查依赖图，不提供可执行的继承模拟。

## 7. Dangerous-inference blacklist

必须拒绝以下变换，而不是把它们作为方便的默认值：

1. help/description → gameplay rule；comments → cardinality/behavior。
2. filename、首行Room注释或目录名 → gameplay身份/角色/物理分类。
3. teacher knows skill → 玩家可学/用；map_skill → 自动enable/use。
4. missing function → allow；缺失字段 → 0/false/default。
5. action metadata → combat buff；temporary apply → 未审计的永久modifier。
6. integer formula → float改写；合并除法、改比较顺序或负数截断。
7. failed action → rollback；重试时从头重放有副作用的链。
8. missing timestamp → 当前时间；clone defaults → 当前实例状态。
9. source NPC spawn → bounded contact等价；source room → 单个Godot scene。
10. random(0) → 通用返回值；随机出口 → 固定边或所有可能边都保证可走。
11. inherited behavior → 猜测复制；无显式global include → 忽略自动include。
12. successful parsing → semantic approval；高词法confidence → Type A PASS。
13. heredoc内代码模板 → 当前对象声明；字符串里的注释标记 → 注释。
14. 重复set/map键 → 静默覆盖/去重；无显式return检查 → 操作必然成功。
15. 多文件同名/同alias → 同一对象；有正向exit → 自动补反向exit。
16. 缺失目标/损坏引号 → 按邻居、描述或拼写近似自动修复。
17. `replace_program(ROOM)` → 文件必定没有有意义的override。
18. UTF-8可解码 → 文本无损；NUL/替换字符 → 静默删除/替换。
19. 注释掉的代码、不可判定预处理分支 → 当前生效；任意#define → 自动安全常量。

## 8. Proposed normalized intermediate representation

**推荐 UTF-8 JSON schema_version=1，但本 P1 不创建 schema 实现。** JSON易读、可比较，
契合现有标准库Python工具，无需数据库/插件。它是 extraction IR，绝不是游戏Save格式：
root2/item3/SOURCE_ENTRY_V1均不改动。

建议一个manifest + 按路径排序的object records数组 + findings数组。小规模可放在一个JSON文件；
另输出Markdown摘要仅供审查。Canonical JSON固定键序、缩进、LF、不加运行时间或机器绝对路径。
有序call/alias/mapping entries保持源码顺序；不为“确定性”排序玩法声明数组。

| 记录字段 | 合同 |
| --- | --- |
| schema_version / extractor_version / profile | IR版本与语法子集版本，独立于Native schema；未知版本消费方拒绝 |
| source_manifest | repo revision（若可得）、source tree（若可得）、每文件SHA-256/size/encoding、scope与排除原因 |
| object_id / source_path | `es2:<mudlib-relative-path-without-.c>`源定义ID + 保留.c的相对路径；不是Native CharacterId或实例ID |
| category_candidates / direct_inherits / includes | 多候选及依据位置、解析状态、dependency refs；不猜唯一类别 |
| facts | path/kind/value或unresolved、provenance、scope/condition、source_ordinal、receiver、syntax classification |
| references | authored path与normalization分开；target存在/缺失/大小写冲突/未解析状态；不补反向边 |
| findings / object_status | explicit diagnostics；OUT_OF_SCOPE、PARTIAL、QUARANTINED、EXTRACTED均不是APPROVED |
| review_state / migration_classification | 初始UNREVIEWED；人工审批材料在独立层引用exact source/fact IDs；机器不批准Type B/C |

事实分类建议：`EXACT_LITERAL`、`STATIC_NORMALIZED`、`UNRESOLVED_EXPRESSION`、
`SEMANTIC_REVIEW_REQUIRED`、`UNSUPPORTED_CONSTRUCT`。这些可配套保存，例如raw skill=40是literal，
但effective skill依赖仍需semantic review。不要用一个百分比掩盖不支持的语法。
`value`使用typed scalar；integer以规范十进制字符串保存（例如kind=integer/value="40"），
防止消费者浮点丢精度；raw token始终保留。UNKNOWN与已知null/0、absent有明确区别。

例：下面是手工核对的单fact展示，不是已实施工具的输出；不是完整object schema。

```json
{
  "object_id": "es2:d/city/street1",
  "field": "short",
  "kind": "text",
  "value": "京师东街",
  "classification": "EXACT_LITERAL",
  "review_state": "UNREVIEWED",
  "source": {
    "path": "d/city/street1.c",
    "sha256": "22eae1c00f4141b629316f00517aa540e3747cb9075def30ead725c427ae69a9",
    "function": "create",
    "construct": "call:set",
    "byte_start": 67,
    "byte_end_exclusive": 95,
    "line": 7,
    "column": 9,
    "raw": "set(\"short\", \"京师东街\")"
  }
}
```

退出和人口mapping用entry数组而不是JSON object，以免重复键在JSON加载时消失。
单个statement多字段引用同一个construct及各自expression span。跨文件合成事实若以后获批，
必须列全部来源和normalization steps；不把合成值伪装成单文件literal。

## 9. Provenance and identity model

每个fact与finding必需：精确相对路径、文件SHA-256、construct类型、function或top-level scope、
原始expression、分类、source ordinal、字节范围。行/列是附加人读索引，不能单独作为稳定ID。
推荐 byte offsets从0开始、end exclusive，UTF-8解码后的行/列从1开始、列按Unicode codepoint，
tab算一个codepoint、不按视觉宽度。CRLF原字节保留；不在计算span之前换行归一化。

Raw span hash + file hash + path + kind + byte范围组成稳定fact identity；重复声明以范围区分，
同bytes重复扫描稳定，
文件改变时旧审查标为STALE，不能跨revision沿用审批。行号可漂移，source hash是追溯锁。
规范化另记规则ID/version和每个input span；`__DIR__`记录当前源目录，不依赖工作站cwd。

区分source manifest（实际输入bytes）与Git commit/tree（仓库身份）。跨平台如checkout换行不同，
manifest/span变化是诚实结果；要求逐byte一致的golden使用固定LF fixture bytes或固定Git blob快照。
不用当前时间/绝对路径污染确定性输出；基准耗时写单独非canonical日志。
人工决定必须绑定源hash、审查范围、对应DECISIONS/owner批准，不能只记录“已看过master.c”。

## 10. Unsupported/dynamic finding and failure model

沿用项目偏好的明确类型和大写状态，而非自由文本猜测。以下均是建议命名，尚未实现。

| Finding code | 触发例 / 处理 |
| --- | --- |
| REQUIRES_SEMANTIC_REVIEW | 完整函数体、override、derived state；保持引用，不执行 |
| UNRESOLVED_INHERITANCE / UNRESOLVED_INCLUDE | 未知base/macro/include、cycle；不得猜默认或静默跳过 |
| DYNAMIC_EXPRESSION | random、变量、宏函数、计算出口；原expression/span完整保留 |
| ORDER_SENSITIVE_MUTATION | 重复赋值、setup/carry/wield/wear、失败前变更；按source ordinal呈现 |
| RNG_SEMANTICS / CALLBACK_BEHAVIOR | bounds、闭包、call_out、valid_leave；不要pre-roll或调用 |
| DRIVER_SEMANTICS_UNKNOWN | missing lfun、replace_program、预处理/默认参数含义不明 |
| SOURCE_SYNTAX_ERROR / SOURCE_ENCODING_ISSUE | 失配括号/引号、NUL/U+FFFD；隔离对象，报告byte location，不自动修复 |
| DUPLICATE_DECLARATION / UNRESOLVED_REFERENCE | duplicate set/key、目标缺失/case冲突；不last-wins/补边 |
| UNSUPPORTED_CONSTRUCT / OUT_OF_SCOPE | 合法但超出子集，或NPC/item等尚未支持；两者不同，不伪称源错误 |

finding包含severity、作用域、source hash/span、related refs、阻断原因、下一步审查问题。
`REQUIRES_SEMANTIC_REVIEW`通常是预期INFO/WARNING；语法/读取失败是对象ERROR。
unknown constructs保留原范围；manifest保证每个发现的输入有结果状态。已确认literal可以留作
诊断，但QUARANTINED对象不进入供消费的静态fact集合；PARTIAL对象始终携带未覆盖范围。

推荐处理：全扫描继续收集每对象问题；严重manifest/I/O/schema/路径越界/输出写入错误使整次失败。
对象语法/encoding错误仍完成诊断输出，但进程exit1表示存在quarantine；纯预期out-of-scope/
semantic findings返回0并明确统计，不能解释为语义PASS。非法参数或工具内部失败exit2。
输出用同目录临时文件完成后原子替换指定输出，不覆盖source、game或已有人工编辑文件；
致命失败不得留下看似完整的新manifest。退出策略需owner第18节确认。

## 11. Smallest useful v1 architecture

| Stage | 职责与边界 |
| --- | --- |
| A — Discovery | 单次确定性只读遍历；manifest列.c/.h及其他文件；候选分类只看已识别inherit/依据；限制source root，不跟随逃逸symlink/junction |
| B — Syntactic extraction | 小lexer + 窄结构识别器：正确跳过comments/strings/heredoc，识别函数/statement/作用域并平衡括号；仅允许的literal与有名normalization；绝不eval/exec LPC |
| C — IR | Versioned JSON、typed literal、ordered facts、exact spans、unknowns、dependencies；不含Native节点/实例/Save状态 |
| D — Audit reports | 对象coverage、缺失依赖、动态/顺序/RNG/driver问题、可追溯候选邻接表；所有图边标为authored，不承诺可达/双向 |
| E — Future Native generation | 仅描述边界，另阶段授权；人工确定区域聚类、条件、Native IDs与typed data后才消费批准的IR；不自动写game/ |

推荐Python3.12标准库，位于未来 `tools/migration/`，复用现有tools的argparse/pathlib/
dataclass/unittest习惯。不会把parser放Godot runtime或依赖Godot editor启动。
P2代码、CLI及fixture名由获批实施再落地，本任务不创建这些文件。

当前 [ZoneDefinition](../../game/core/world/zone_definition.gd)、
[MapDefinition](../../game/core/world/map_definition.gd)、
[SnowWorldDefinitions](../../game/data/snow/snow_world_definitions.gd)已经区分物理map/zone/portal与legacy IDs；
[SourceDumpling](../../game/data/items/source_dumpling.gd)提供明确typed定义。
未来生成器应接入这些经审查的契约，不能另建ROOM graph作为物理运行时，或把IR当dbase全局字典。
已有 [LearnService](../../game/core/learning/learn_service.gd)等领域规则不由提取器重写。
版本迁移、schema parser、工具测试与报告都是工具领域；不得据此增加游戏存档schema。

## 12. Recommended P2 bounded implementation slice

推荐只交付 **static room source facts + provenance + complete unsupported report**。
全树发现对象，首批fact extraction限定 `d/**/*.c` 中可识别直接 `inherit ROOM` 的对象；
BANK/HOCKSHOP/CLASS_GUILD、NPC、item、daemon、cmds只列manifest/依赖及OUT_OF_SCOPE。

首批字段：source identity、直接inherit引用、create中literal short/name、TEXT_ONLY long，
literal exit entries，以及显式outdoors/indoors/no_clean_up/no_fight静态string/integer。
`__DIR__` + literal路径拼接作为单独可审查的有限normalization推荐纳入；任意宏展开不纳入。
只有语法定位和receiver明确的statement才生成fact；条件编译/条件分支保留条件，
未知宏、重写exits、callback不被跳过，产生PARTIAL/findings，不解释执行后最终值。

P2不抽取完整门/人口服务合同，只报告对应construct和待审依赖。room.h中门常量可链接出处，
不实现门行为。人口与NPC/item静态字段是之后的扩展候选，需先证明lexer/provenance/coverage。
P2不支持公式求值、Learn/recruit/combat、runtime、daemon语义、callbacks执行、任何Godot生成。

这样已有静态城镇路线便于核对与聚类，但无法绕过真实物理地图设计或语义审批。
验收不是“支持533间房”，而是：支持子集正例逐byte可追溯、负例不误提取、所有输入有明确状态、
same bytes输出确定、source零改动、无Native gameplay输出。P2实施前必须确认第18节决定。

## 13. Future deterministic test / fixture strategy

设计而不实施测试。未来建议标准库unittest放 `tools/tests/test_migration_*.py`，
小fixture/golden放 `tools/tests/fixtures/migration_v1/`；本P1这些路径不创建。

| 测试组 | 手工可审核的断言 |
| --- | --- |
| 最小正例 | literal ROOM/name/long/exits/flags准确；expected IR手写而不是用被测工具自生成 |
| Source样本 | city/street1、school1、keep2、pine3、eastdoor1、village/lake；每个明确应提取/应报告的构造 |
| Provenance | bytes[start:end]精确等于raw，中文/CRLF/tab/同值重复statement/同名不同目录；hash改动使旧approval失效 |
| Lexical边界 | //与/* */在字符串中；转义引号/反斜线；多行文本含LPC代码；heredoc terminator与相似正文；相邻字符串 |
| Mapping边界 | duplicate keys、trailing commas、nested mapping/array、missing target、__DIR__、动态key/value、重写与别名 |
| Unsupported/coverage | 函数体/closures/includes/conditional编译/未知field均有span及finding；不silent field loss；OUT_OF_SCOPE不是空成功对象 |
| Malformed input | sroad1/sword_book形态、unterminated string/comment/heredoc、NUL/U+FFFD/无效UTF-8；隔离而非修复，验证退出策略 |
| Ordering | carry→wield→wear、重复set、condition scopes保留次序；不把字典排序当执行顺序 |
| Determinism / filesystem | 输入枚举打乱输出不变；限制路径越界/symlink/case collision；no timestamps；相同bytes跨平台golden一致 |
| Regression | 手审固定真实样本revision/hash + 小型完整输出golden；新增语法只以独立审查扩充，不能批量接受snapshot变化 |

Reference永远只读。可用原仓库文件做只读integration样本；紧凑fixture复制必要片段并保留
path/revision/hash/line范围/许可出处，或作者手写语法最小例，不能移动/编辑原文件。
许可未解决时不把整套source/golden发布到第三方；源码片段的出处记录不等于法律许可结论。
失败golden必须包含findings，不靠忽略错误使测试绿。整corpus smoke验证manifest覆盖与稳定性，
不以P1词法计数作语义覆盖率或P2正确性的唯一oracle。

## 14. Scale and performance

源/header约2.09 MB，整体约3.23 MB；最大`.c`是ftpd.c 57,689 bytes，其次combatd.c 29,632、
dns_master.c 21,124。本机临时词法扫描一次约0.93秒（warm文件缓存、非性能SLA）。
早期未跳过heredoc的粗扫约4.73秒且有错误计数；这说明正确词法边界比添加缓存更有价值。
这里只是当前工作站观测，没有跨平台benchmark或未来parser性能保证。

v1每次重扫整个树足够。依赖图在内存中按manifest构建，检测cycle/深度和大小限制即可。
不需要数据库、后台服务、language server、persistent cache或分布式计算。
上限/深度保护与扫描超限应明确ERROR，不silent truncate；具体默认阈值由P2基于实测设定，
不为了接受损坏输入而无限制递归。后续实测证明瓶颈才讨论缓存，缓存不能掩盖source hash变化。

## 15. Risks and mitigations

| 风险 | 优先级 | 对策 |
| --- | --- | --- |
| 词法误识别/复杂预处理被当事实 | 高：P2正确性门禁 | heredoc负例、scope定位、allowlist、未知构造显式报告；不以regex全集当parser |
| parsed被误读为approved | 高：架构门禁 | IR恒带UNREVIEWED、分类分轴；无直写game入口；Native生成另授权 |
| 已存在损坏/缺base/文字丢失 | 中 | per-object quarantine、原bytes/hash、不中断其他诊断，不修source |
| 继承默认/时序/随机/partial failure漏审 | 中 | dependency/finding ledger；人工追完整链；不承诺最终状态 |
| path/case/symlink/整数精度差异 | 中 | root confinement、case-aware source IDs、原bytes位置、typed整数字符串 |
| fixture版权/敏感历史资料 | 中 | 最小必要fixture及provenance；仅内部分析，保留既有许可待决，不自动发布source |
| 旧状态文档滞后 | 低 | 本文明确当前owner基线；按授权保持STATUS/ROADMAP不变，不借机closeout |
| 未来过早做NPC/场景生成 | 中 | P2静态room子集；其他阶段不由本分析批准 |

这些是提案需要控制的风险，不是在P1中发现可通过改生产代码解决的任务。

## 16. P1 validation and scope audit

交付路径仅本文件。临时普查脚本/JSON在ignored build，既不是生产extractor也不是提交fixture。
采用已有 [repository_checks.py](../../tools/ci/repository_checks.py) 做LOCAL静态检查；
该脚本本身不是完整Markdown验证器。仓库未发现独立的通用Markdown/link验证入口，
故另以临时只读检查核对本文件的本地Markdown targets、章节结构、JSON示例/span和计数求和。

提交前检查：`git diff --check`、文件清单、未跟踪文件及暂存内容。
提交后检查：`git diff --check origin/main...HEAD`、name-status/stat、parent和远端phase SHA。
精确检查结果、最终commit SHA在完成报告给出，不为写入自身SHA再追加提交。
不得更改 `reference/es2/`、`game/`（包括tests/config/export）、root tests、tools生产目录或`.github/`。
没有修改DECISIONS、STATUS、ROADMAP或README。P1不需要新Godot实机验收；未运行/声称新的远端CI。

## 17. Explicit deferred scope

所有生产extractor/lexer/schema/test代码、静态NPC/item字段扩展、门/人口执行规则、
继承求值器、公式/战斗/Learn/recruit自动迁移、driver模拟、Native importer/generator、
场景/角色批量生成、游戏内容和Save变化、Migration Tooling P2、PR及merge均延期。
清理被worktree占用的三个本地分支不在新阶段继续执行。

## 18. Owner decisions required before P2

以下都是**建议，尚未批准**。P1完成不授权P2；请owner决定后再实施。

| 决定 | 推荐 |
| --- | --- |
| 1. 实施语言/位置 | Python3.12标准库，`tools/migration/`；无Godot runtime依赖或第三方parser |
| 2. 首批对象子集 | `d/**/*.c`的直接ROOM静态事实；name/short/TEXT_ONLY long/exits/少量显式flags；其余只发现并报告 |
| 3. IR格式/schema | 独立version1 UTF-8 JSON，ordered entry arrays、typed整数十进制字符串；不改游戏schema |
| 4. Provenance | 原source path/hash + function/construct + byte半开范围 + 1-based行/列 + raw + rule/version；hash变更使review过期 |
| 5. 动态/unsupported政策 | 不执行、不猜测、不丢弃；explicit findings/coverage；有限__DIR__路径normalization，其余宏保留未解析 |
| 6. 生成中间文件 | 日常whole-corpus输出默认ignored `build/migration-tooling-v1/`，不提交；只提交手审小golden/明确审查报告 |
| 7. Fixture/golden | 标准库unittest + provenance完整的最小snippet/真实只读样本；expected手审，禁止无审查自动更新 |
| 8. Native生成边界 | 必须独立后续授权；extractor不写game，不能把语义UNREVIEWED记录作为生成批准 |
| 9. 失败政策 | 继续生成per-object诊断；语法/encoding隔离并exit1，致命input/output/internal失败exit2，预期out-of-scope/semantic finding不伪作错误或语义PASS |

**P1 ANALYSIS ONLY — AWAIT OWNER REVIEW.**
