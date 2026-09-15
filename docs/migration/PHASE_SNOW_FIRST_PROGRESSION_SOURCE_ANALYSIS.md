# Snow First Progression Loop / 淳风武馆 — P1 源码与依赖分析

## 1. Executive conclusion / 结论与授权边界

**P1 ANALYSIS COMPLETE — AWAIT OWNER REVIEW.** 本文是源码考古、Native 缺口及边界建议，
不是 P2 实施决定。所有「建议」均待 owner 审批；没有 gameplay、测试、schema 或工具实现。

- 唯一里程碑分支：`phase/snow-first-progression-loop`。
- 精确基线：`88be5c0e9e297b8f92d38b1f14a131a0cb8abf4e`；创建前本地 HEAD、
  `origin/main` 相同，工作区/index 干净，目标本地分支不存在。
- 基线 [post-main run 34893911519](https://github.com/Toxicccxz/eastern-stories-godot/actions/runs/34893911519)
  为 `push/main`、该 SHA、completed/success；不是本 P1 的 CI。
- 重新读取根及 docs AGENTS、[DECISIONS](DECISIONS.md)、[STATUS](../production/STATUS.md)、
  [ROADMAP](../production/ROADMAP.md)、[README](../../README.md)、
  [Snow final audit](PHASE_SNOW_TOWN_CORE_HUB_FINAL_AUDIT.md)，并检查 Hockshop
  [H1](PHASE_SNOW_HOCKSHOP_LOOT_MONETIZATION_CONTRACT.md)、
  [H2](PHASE_SNOW_HOCKSHOP_LOOT_MONETIZATION_CORE.md)、
  [H3](PHASE_SNOW_HOCKSHOP_LOOT_MONETIZATION_RUNTIME.md)、
  [final audit](PHASE_SNOW_HOCKSHOP_LOOT_MONETIZATION_FINAL_AUDIT.md) 的边界先例。
  历史阶段的「deferred」不是本次 P1 的禁止分析指令，也不是 P2 的实施授权。

**严格结论：未经修改的新玩家能拜柳淳风为师：YES。** 出生有效胆识/定力都是30，
NPC 只要求各至少20。年龄14、经验0、无技能、无门派不是这条 NPC 收徒路径的阻碍。
完整路径是 apprentice → NPC attempt_apprentice → recruit → recruit_apprentice，
不能只摘录 NPC 的两项属性判断。

教师有 **11** 项技能，拜师后新人可立即学习其中 **9** 项（§9–10）。经验0允许武学
从原始0学到3：`0³/10=0, 1³/10=0, 2³/10=0`，原始3再学才因 `27/10=2>0` 失败。
这不是「经验0只能识字」，也不是「经验0可以一直学」。每次实际进步带 RNG，升一级
必须累计进度严格大于平方阈值，不能保证一次点击升级。

**能力变化需要额外谨慎。** 基本拳脚原始2使有效等级从0变1，但经验0、max_sen100时，
战斗整数公式仍把 AP/PP 压到1。仅展示技能等级/新招式文本不构成数值增强证据。
建议 P2 最小候选为「首次拜师 + 基本 unarmed 学习 + 原有 Old Pine 战斗自然经验 + 精确存续」；
自然获得至少2经验后，基本拳脚原始至少2对 AP 的贡献即可与同经验、未学拳脚的反事实比较，
无需移植高级招式、内功或另造训练敌人。此路线**源语义可行，但实际可达性/可玩性尚未运行验证**。
若 owner 要求在首次战斗前、经验仍0时就有数值增强，此候选不满足；不得添加经验礼包或改公式。

全套拜师状态目前并非都能保存。已有 family/master/技能/title 存储不能代表已拥有
enter_time、family title/privs、class、Player score。§19–20 给出版本化扩展建议，不能宣称
「完全不需要 schema 工作」。普通 Learn/Enable 核心已大量存在，但没有学校 runtime wiring。

## 2. Exact source files / 证据索引

LPC 路径以下均相对只读 `reference/es2/mudlib/`；行号为上述冻结基线。S 编号是便于
交叉核验的证据组。Native 的 `game/...` 路径相对仓库根；表内 `core/...`、`runtime/...`、
`tests/...` 相对 `game/`，同组省略目录的文件沿用对应目录。类型/继承以代码为准，不取
`d/skill/` 的重复文件为实现权威：
`include/globals.h:36–37,60,68` 定义 CLASS_D、SKILL_D、FORCE、SKILL。

| 索引 | 精确文件与关键位置 |
| --- | --- |
| S1 路线 | [mstreet1.c](../../reference/es2/mudlib/d/snow/mstreet1.c):15–20；[school1.c](../../reference/es2/mudlib/d/snow/school1.c):9–30；[school2.c](../../reference/es2/mudlib/d/snow/school2.c):9–29；[schoolhall.c](../../reference/es2/mudlib/d/snow/schoolhall.c):7–24 |
| S2 附近 | `d/snow/school.c:7–22`、`inneryard.c:7–28`、`weapon_storage.c:7–87` |
| S3 教师 | [daemon/class/swordsman/master.c](../../reference/es2/mudlib/daemon/class/swordsman/master.c):6–89；同目录 `blackthorn.c:7–27`、`silk_cloth.c:5–17`、`fonxansword/counterattack.c:7–32` |
| S4 NPC | `d/snow/npc/guard.c:9–95`、`fist_trainer.c:5–52`、`trainee.c:5–14` |
| S5 拜师 | [apprentice command](../../reference/es2/mudlib/cmds/std/apprentice.c):7–85；[recruit command](../../reference/es2/mudlib/cmds/std/recruit.c):7–92；[F_APPRENTICE](../../reference/es2/mudlib/feature/apprentice.c):5–67 |
| S6 学习 | [learn.c](../../reference/es2/mudlib/cmds/std/learn.c):16–144；[F_MASTER](../../reference/es2/mudlib/std/char/master.c):4–33 |
| S7 技能状态 | [feature/skill.c](../../reference/es2/mudlib/feature/skill.c):13–77,126–155；[enable.c](../../reference/es2/mudlib/cmds/std/enable.c):7–114；`std/skill.c:23,39,47` |
| S8 技能内容 | `daemon/skill/{unarmed,parry,dodge,sword,force,literate,liuh-ken,fonxanforce,fonxansword,chaos-steps,spider-array}.c`；各自位置列于§9 |
| S9 自修 | `cmds/std/practice.c:7–38`、`selflearn.c:10–53`、`study.c:9–56`、[exercise.c](../../reference/es2/mudlib/cmds/std/exercise.c):7–66；`cmds/std/team.c:64–70` |
| S10 战斗 | [combatd.c](../../reference/es2/mudlib/adm/daemons/combatd.c):165–186,230–408；`feature/attack.c:202–222`；[std/force.c](../../reference/es2/mudlib/std/force.c):5–37 |
| S11 继承/生命周期 | `std/char.c:14–53`、`std/char/npc.c:8–14,26–108,142–150`；`std/room.c:15–77,91–203`；`adm/daemons/chard.c:6–44`；`adm/daemons/race/human.c:26–80` |
| S12 属性/持久性 | `feature/attribute.c:5–32`、`feature/dbase.c:7–8`、`feature/save.c:3–21`、`obj/user.c:8`；`feature/command.c::command_hook/enable_player`、`include/command.h::NPC_PATH/PLR_PATH` |

上述 room、NPC、拜师/学习/技能文件进行了 fresh 源码阅读；大的 combat、持久化文件按
相关函数核验。无外部移植来源，无 LPC 改动。文中的「未见」限定在列明的可执行链/全仓搜索，
不是对未知 ES2 部署或驱动行为的断言。

## 3. Physical school topology / 物理拓扑

已有 New Game 在 Inn。既有 Inn east → Square，Square north → mstreet1；新增最短链：

```text
snow.inn → snow.square → snow.mstreet1
                            east ↔ west
                         school1 大门 [刘安禄]
                            east ↔ west [双侧红漆大门，初始 CLOSED]
                         school2 教练场 [李火狮 + 6 武馆弟子]
                            east ↔ west
                         schoolhall 大厅 [柳淳风]
```

| LPC room | short / exits | 规则、spawn 与本阶段必要性 |
| --- | --- | --- |
| `d/snow/mstreet1` | 雪亭镇街道；W bank/S square/N mstreet2/E school1 | 已实施街道；东入口当前仅保留关闭的分期 frontage |
| `d/snow/school1` | 淳风武馆大门；W mstreet1/E school2 | guard×1；east 红漆大门 DOOR_CLOSED；door item description；必要 |
| `d/snow/school2` | 淳风武馆教练场；W school1/E schoolhall/N weapon_storage | trainee×6、fist_trainer×1；west 同一扇门；必要通路 |
| `d/snow/schoolhall` | 淳风武馆大厅；W school2/E inneryard | CLASS_D(swordsman)/master×1；valid_startroom1；必要终点 |
| `d/snow/inneryard` | 天井；W hall/E innerhall/N nyard/S guestroom | 无本链教师/门禁依赖；柱子文字是附近谜题线索；可延后 |
| `d/snow/weapon_storage` | 兵器储藏室；S school2 | bamboo_sword×1；push 三次触发 down secret_storage，10秒关闭；非拳脚依赖 |
| `d/snow/school` | **书院**；N sroad2 | teacher×1；不是淳风武馆，描述中的西门没有可执行 west exit |

前三个武馆 room 没有自定义通行条件或动态出口。门由 `std/room.c` 处理：closed 时
`valid_leave` 拒绝；open/close 在对面已加载时同步，对面稍后 create 时读取现有状态。
没有门钥匙、会员身份收费、刘安禄阻拦通行的代码。门不是逻辑永久关闭的学校边界。
`std/room.c:112` 的 `status &= (!DOOR_CLOSED)` 实际清空标志，不应泛化成健全的通用锁引擎。
Native 推荐三个**连续 zone**，不是每个 LPC room 一个加载场景。Schoolhall 的 startroom
标记不自动授权更改已批准的 Snow Inn 出生或新增玩家设置出生点命令。

## 4. NPC inventory / 最小路线人口

| 源码 | 数量/位置 | 功能和延后影响 |
| --- | --- | --- |
| `d/snow/npc/guard.c` 刘安禄 | 1 / school1 | 门房但无 entry gate。秘密 inquiry 在 exp≥20000 后可随机暴露身份、加临时属性、变 aggressive、攻击全场并给刀谱；不是拜师前置。可明确分期省略，不能声称已经实现守卫/谜题 |
| `d/snow/npc/trainee.c` 武馆弟子 | 6 / school2 | 男19、exp100、linen；没有专门授课或拜师 callback。是原有人口/可战 NPC，非本链必要。省略后须改写场景呈现，不能显示有六人正在执行未实现训练 |
| `d/snow/npc/fist_trainer.c` 李火狮 | 1 / school2 | unarmed30/liuh-ken20/dodge30；recognize 仅封山家族；同家族 accept_fight，同意切磋。不是柳的收徒 gate，柳可教授其三项。可延后，但明确没有本馆切磋服务 |
| `daemon/class/swordsman/master.c` 柳淳风 | 1 / schoolhall | 本提案唯一必要的教学 NPC；不能省略他的 source identity/收徒判断 |

**柳单独引入是否可行：CONDITIONAL。** 拜师/学习调用链不依赖前三者；可作为 owner
批准的 Type B 人口分期。不是完整学校人口还原，不能保留「大师傅们已在提供服务」的误导呈现。
若 owner 要求在馆内获得战斗经验，李火狮会变成另一个需要正式移植的依赖，不能临时加一个假 trainer。

## 5. 柳淳风 full source profile

| 事实 | 源码值 / 派生方式 |
| --- | --- |
| identity | 柳淳风；nickname 风雨双侠；主 ID `master swordsman`，别名 `swordsman`, `master`（无须发明 `liu chunfeng` 别名） |
| gender/age/race | 男性、44；未显式 race，chard fallback 人类 |
| authored attributes | str27 / cor30 / cps27 / int24 |
| inherited attributes | spi/per/con/kar 未显式设置，各 `random(21)+10`；共4次，依 human setup 的顺序。不能一律填30 |
| resources | force1500 / max_force1500 / force_factor3；无显式 gin/kee/sen。human/chard 派生 current=effective=max：gin150、kee595（220+1500/4）、sen170 |
| attributes queried | 无其他 modifier 时 query_cor30；query_cps28（27+3/2）；query_str30（27+3） |
| family | 封山剑派，generation13，family title 掌门人，privs=-1；显示 title `封山剑派第十三代掌门人`；create_family 不给自身 master/enter_time |
| exp/score | combat_exp1000000 / score200000 |
| attitude | 未 authored，human 默认 peaceful；不能因此改成拒绝所有战斗，NPC 默认 accept_fight 另有资源条件 |
| body | 未显式 weight；human 推导74000，encumbrance str×5000=135000 |
| equipment | setup 后 carry/wield `daemon/class/swordsman/blackthorn`：玄苏剑，15000重量、value2400、init_sword58；carry/wear `silk_cloth`：丝绸马褂，1000重量、cloth槽、value2500、dodge+6/armor+1 |
| learned skills | 11个明确 raw level，见§9；没有 authored per-skill learned progress |
| mappings | unarmed→liuh-ken；sword→fonxansword；parry→fonxansword；dodge→chaos-steps。**没有 force→fonxanforce，也没有 array mapping** |
| combat chat | chance60；唯一 callback perform_action `sword.counterattack`。NPC chat 有 random(100) 和消息索引随机；counterattack 又按经验 RNG，自己 busy1、成功使目标 busy |
| inquiry | 淳风武馆、先人遗志、刘安禄、name、here，五项静态文本；无教学任务物品或前置旗标 |
| teaching callbacks | 自有 attempt_apprentice、recruit_apprentice override；继承 F_MASTER.prevent_learn；无 authored recognize_apprentice |
| class | 教师 create **没有 set class**；其 recruit override 仅在 inherited 成功时给学生 `class=swordsman` |
| timer/death/reset | 无教师专属倒计时/死亡覆盖。继承普通 NPC/character 死亡行为；room reset 若 clone 不存在重建，否则尝试 return_home，后者会检查 living/fighting/exits。不是「永不死固定导师」的源规则 |

counterattack 的 busy 时长使用 `query_skill("fonxansword")/20+2`，不是 raw150直接除20；
以无同名 mapping/modifier 为例 effective75，结果5。完整教师战斗会牵涉武器、映射动作、
技能 hit hook、perform/busy、死亡物品与 respawn，远大于只建立教学关系的范围。

## 6. Apprenticeship executable semantics / 完整拜师链

1. `apprentice <target>` / `apprentice cancel`。cancel 删除自己的临时 pending/apprentice。
2. `present(arg, environment(me))`，目标必须 character、living、不是自己；已有
   `is_apprentice_of`（master ID + **master display name**）则仅请安返回，无重建时间或家族。
3. 目标必须有 family mapping。此处没有学生 gender/race/age/skill/exp 检查，也没有 busy/fighting
   检查；`feature/command.c::command_hook` 没有替它统一补这些 gate。
4. 新人通常没有 teacher pending/recruit：写入学生临时 pending/apprentice，NPC 调
   `attempt_apprentice(student)`。柳先检查 `query_cor()<20 || query_cps()<20`，失败仅说话，
   **pending 留下**，再点同一目标会触发「尚未答应」；源 command cancel 可清除。
5. 接受后执行 NPC command `recruit <student primary id>`。NPC_PATH 含 cmds/std；recruit
   再在相同 environment present 学生，不能是自己。recruit 的 title/exp20000/age18条件
   **仅作用于 userp(me) 的收徒者**，不能错套到柳或年龄14学生。
6. 学生 pending 匹配才进入立即完成；学生须 living。不匹配则教师设置临时 pending/recruit，
   形成另一顺序的握手。
7. 常规 recruit 完成分支只有学生**已有 family 且家族名不同**才 score=0、betrayer+=1。
   初次无家族不会加 betrayer。同家族换师没有这两项惩罚。没有技能减半的可执行代码，
   尽管 apprentice help 声称会减半。
8. `feature/apprentice.c::recruit_apprentice`：若已是该师徒关系则0；教师无 family则0；否则
   用新的 family mapping **替换**学生旧 family，写 master_id/master_name/family_name、
   generation=teacher+1、enter_time=`time()`，assign `弟子`, privs0。
9. 玩家 title 改为 `封山剑派第十四代弟子`；柳 override 在 inherited 返回成功后写 class=swordsman。
   recruit command 删除学生 pending/apprentice。没有学费、资源消耗、潜能奖励或拜师 RNG。

另一条「教师预先邀请 → 玩家 apprentice 接受」在 `apprentice.c:45–51` 只比较家族名，
**缺少已有 family guard**；第一次入门也可能被当背叛。不能把两条命令合成一个未经说明的
通用事务。建议 P2 只实现新玩家发起、柳同步回应这一确切链；重拜请安保留幂等。

持久状态是 family/master/generation/title/privs/enter_time/class，以及已有家族路径的
score/betrayer。pending 是 tmp_dbase，不是常规存档字段；是否以 typed pending/cancel保留
失败后行为、或做一次点击同步交互的 Type B 替代，列入§27，不在 P1 自行决定。

## 7. Fresh-player eligibility / 当前 Native 出生核验

[NewPlayerInitializationPolicy](../../game/core/characters/new_player_initialization_policy.gd):7–25
实际创建 Human identity、age14、普通百姓、八属性30，CharacterProgressionState(0,99,0)，
三资源100/100/100，默认空技能/learned/mappings/family/apprenticeship、force/max_force0、
force_factor0、bellicosity0；出生 cloth 无武器。没有把旧技术战斗样本当新游戏数据。
`CharacterBaseAttributes::effective_courage/effective_composure:57–70` 与 S12 的公式相符。

| 问题 | 严格回答 |
| --- | --- |
| 原始新人能被柳收徒？ | **YES**，cor30/cps30≥20，完成 S5 的普通请求链；须真实到场且老师/学生清醒 |
| 是否要求先识字/拳脚/经验/金钱？ | **NO**，该链未检查这些；不从叙述推导额外 gate |
| 首次是否背叛？ | 正常 apprentice→柳 recruit 路径 **NO**；反向邀请分支有缺陷，见§6 |
| 本版本游戏已能完成？ | **NO**，学校还关闭、无教师交互和拜师执行服务；上述 YES 是源码 eligibility |

## 8. Learn executable semantics / 精确顺序与公式

S6 的顺序如下；全部除法是 LPC 整数除法，本文非负场景等同向下取整。

1. 解析 `learn <skill> from <teacher>`；skill 是传给 query_skill/SKILL_D 的原 ID，
   没有把中文技能名自动解析为 ID 的步骤；to_chinese 只用于输出。
2. 学生 fighting则拒绝；目标 present于同 environment、character、living。没有 teacher fighting、
   学生 busy、年龄或距离数值检查；物理 proximity 是 Native 翻译，不冒称源码原有半径。
3. 扫 direct inventory 的 marrycard并解析在线伴侣；本首学链不依赖它。关系准入：
   master_id匹配 **且 generation=teacher+1**，或 spouse，或同家族且教师privs=-1；
   否则先抽三条拒绝文本之一，再调用 recognize_apprentice；柳没有此 override。
   缺失 lfun 的部署返回行为不明，Native 已按 DECISIONS 显式拒绝缺失正向授权。
4. 教师 raw技能必须非0；先 F_MASTER.prevent_learn，再要求学生 raw < 教师raw。
   F_MASTER：betrayer非0时 `student_raw >= teacher_raw - betrayer*20` 拒绝；
   非 ID+master_name 嫡传时，`teacher_raw <= student_raw*3` 拒绝。它不使用 generation，
   与上面的 private predicate 确实不同。
5. 调技能 valid_learn；顺序和具体条件见§9。然后
   `gin_cost = 150 / teacher_base_int + 150 / student_base_int`。
6. 学生 raw0（不存在或显式0）时 gin_cost乘2，并先 `set_skill(skill,0)`。
   **此零条目可能在后续失败后留下**。这不是全预检后才 mutation的事务。
7. `learned_points >= potential` 拒绝；随后 env/no_teach拒绝。
8. 教师 sen必须 `> gin_cost/5+1`；否则输出疲劳并 command返回1、没有进步或学生扣精。
   只有 userp(teacher)扣这份sen，柳作为NPC不扣，但仍必须满足阈值。
9. 学生 gin必须严格 `> gin_cost` 才尝试进步；否则把 gin_cost设为当前gin，最后耗尽gin，
   command返回1但不增学习点/技能。gin恰等cost也不进步。
10. martial且 `raw³/10 > combat_exp`：无进步、无 learned_points增加，但仍扣完整gin_cost。
11. 进步分支先 `learned_points += 1`；potential总额**不扣**。然后抽：

```text
B = int + combat_exp / (1000 + combat_exp / 1000)
amount = random(B)                  # 0 <= roll < B
if number_of_learned_entries > spi:
    amount /= number_of_learned_entries - spi
if amount == 0: amount = 1
learned[skill] += amount
if learned[skill] > (raw[skill] + 1) * (raw[skill] + 1):
    raw[skill] += 1                 # 一次最多一级，溢出进度丢弃
    learned[skill] = 0
    skill_improved(student)
receive_damage("gin", gin_cost)     # 在技能 callback 之后
```

柳int24、新人int30：常规cost `6+5=11`；raw0为22；教师sen门槛分别>3/>5，实际170。
初始 B=30；random0也会作为1点进度；raw0阈值1，所以roll0/1首次不升级，其余roll可升到1。
最差两次可把一项从0升1（资源许可时），没有一次学多级。重复按钮不是确定性的总进度。
母体 learned mapping 条目数包括零进度条目，不是「已学等级>0的技能数量」。
两次 intelligence除0、随机bound非法或负伤害都是 mutation敏感错误；沿用已批准的
LearnResult typed legacy error，不能提前回滚。source前述拒绝信息 RNG不应偷用 gameplay
流；成功学习 RNG的时点则必须在真正进步分支上。

## 9. Teacher skill inventory / 全部11项

所有源文件位于 `daemon/skill/`；默认继承 `std/skill.c`：type martial、valid_learn=1。
「新人可学」表示刚拜师且仍有资源时能成功进入进步分支，不保证同一次点击升级或一次体力池学完全部。

| Skill | Teacher raw | Source File / lines | Type | valid_learn | Fresh Player Can Learn? / Why |
| --- | ---: | --- | --- | --- | --- |
| unarmed | 40 | `unarmed.c:5–15` | martial | inherited allow；无武器 gate | YES；exp0 raw0可进步 |
| parry | 120 | `parry.c:3–23` | martial | inherited allow | YES；不要求先拿武器 |
| dodge | 80 | `dodge.c:3–16` | martial | inherited allow | YES |
| sword | 150 | `sword.c:3` | martial | inherited allow | YES；基本 sword 学习不要求持剑 |
| force | 40 | `force.c:5–23` | martial | explicit allow | YES；无需先有max_force |
| literate | 60 | `literate.c:5–17` | **knowledge** | inherited allow | YES；不受 learn 的武学经验立方门槛 |
| fonxanforce | 60 | `fonxanforce.c:3–17` → `std/force.c` | martial | explicit allow | YES；**学习本身没有 basic force前置**，enable才有 |
| fonxansword | 150 | `fonxansword.c:54–74` | martial | 按序 max_force≥50；mapped force=fonxanforce；primary weapon是sword | NO；三项均不满足 |
| liuh-ken | 60 | `liuh-ken.c:28–38` | martial | primary/secondary weapon都为空 | YES；出生空手，无 unarmed/force/exp额外前置 |
| chaos-steps | 100 | `chaos-steps.c:15–25` | martial | max_force≥50 | NO；新人max_force0 |
| spider-array | 85 | `spider-array.c:5–17` | martial | inherited allow | YES；学习没有八人组队门槛；**使用**才检查队伍 |

技能增长 callback：unarmed 在新raw `%10==9 && base_str<raw/4` 时str+2；force同样改con；
literate同样改int（S8）。新人的int30高于柳literate60所能触及的阈值，因此不能承诺
「向柳学识字就能提高当前新人悟性」。其直接有用作用是满足 study 的识字非0条件。

## 10. Fresh-player learnability matrix / 真正首学集合

立即可进步集合 = `{unarmed, parry, dodge, sword, force, literate, fonxanforce, liuh-ken, spider-array}`。
第一项不由源码强制指定；建议基本 unarmed，理由是当前战斗已消费它，非另造教程顺序。

| 候选/阶段 | eligible / blocked | 精确阻碍 | 最小解除方式 |
| --- | --- | --- | --- |
| 上述9项，刚入门raw0 | eligible | 无内容前置障碍 | 到场、正确拜师，保持gin>22、教师sen>5、潜能未耗尽 |
| 任一martial raw3，exp0 | blocked（仍扣gin11） | `27/10=2>0` | 自然经验至少2；raw3可升4 |
| martial raw4 | blocked若exp<6 | `64/10=6` | exp≥6可升5；raw5则需12 |
| fonxansword raw0 | blocked于第1条件 | max_force0<50 | max_force50后仍要force映射、主手剑，顺序不可交换 |
| chaos-steps raw0 | blocked | max_force0<50 | 达到max_force50；学会后 enable dodge另需basic dodge非0 |
| liuh-ken携武器 | blocked | 任一手非空 | 通过现有装备动作卸下两手；不能仅检查primary |
| advanced技能已有raw1，basic缺失/0 | learn可继续；enable blocked | enable要求basic raw非0 | 学相应基本技能至少1；不追加到valid_learn里 |
| potential_spent达99且potential99 | blocked | learned_points≥potential | 走原有经验/潜能获得行为；不给新手补发/忽略成本 |

无合法 blanket「最大等级3」限制：只是在exp0下learn的边界。Practice、战斗进步和Study
各自门槛不同。正好阈值的经验可继续；只有 `>` 拒绝，不能改 `>=`。

## 11. Skill dependency graph / 有向依赖

```text
到大厅 + effective cor/cps >=20 → 首次拜柳 → 学习关系通过
     ├─ learn unarmed (任意顺序) ─┐
     ├─ learn liuh-ken (两手空) ─┴─ 两者raw非0 → enable unarmed liuh-ken
     ├─ learn force ────────────┐
     ├─ learn fonxanforce ──────┴─ 两者raw非0 → enable force fonxanforce
     │                                          ↓ current force清0
     │                               exercise +恢复 → max_force增长
     │                                          ↓ max_force>=50
     │                          ┌───────────────┴─────────────┐
     │                     chaos-steps                    fonxansword
     │                    + basic dodge              + force仍映射fonxanforce
     │                    → enable dodge             + 主手sword，后需basic sword/parry
     ├─ literate非0 → 有真实教材才可study                → enable sword/parry
     └─ spider-array非0 → team leader +8成员 → team form spider-array（仅源文本）
```

force/fonxanforce raw最高各3且零modifier时，effective force=1+3=4，exercise上限
`(3+4/5)*10=30`。**经验0仅靠柳的learn加exercise无法到max_force50**。
一个可达解：自然exp≥6 → basic force学到5 → effective至少3（mapped fonxanforce1）
→ cap至少50 → 用exercise/现有恢复积累至max_force50。另有其他技能组合，不能把该示例
硬写为唯一源教程。force从4学5要exp6；不用先去书院或拿藏库剑才能开始拳脚线。

## 12. Enable / mapping semantics

S7：`enable <use> <advanced>`；`enable <use> none`取消。列表允许unarmed/sword/blade/
stick/staff/throwing/force/parry/dodge/magic/spells/move/array/whip。`enable none`单参
并非帮助文字暗示的全取消。base映射自身是提示后成功no-op；advanced和base raw都须非0，
再检查advanced.valid_enable。普通有效正等级路径不是检查「拥有raw条目」就够。

Learned state是raw+per-skill learned；base也在同一raw map。mapping是独立use→skill；
装备在独立两手authority；combat再根据primary选use（无primary为unarmed）。
低层 `map_skill` 只要求目标raw条目存在，甚至允许0，并不执行command的前置，NPC authored
mapping也用这层。不能把底层可映射等同于玩家enable合法。

映射本身无经验/潜能/金钱/RNG/门派条件，也无busy/combat gate。会 reset_action。
force映射把current force置0并receive_damage(kee,0)；magic清atman，spells清mana。
同一映射再次enable仍执行资源清零；取消none不执行这一清零，max不变。
`query_skill(use)=temp_apply + raw_base/2 + raw_mapped`；没有映射则只有base半值和modifier。
skill_map不是static；与skills、learned及dbase随User的F_SAVE一起持久化（S7/S12）。

Native SkillEnableTransition:15–42返回映射改变及resource-reset意图；调用者尚须执行
清零/适当零伤害生命周期并刷新动作。不能仅调用 map_skill 然后宣称enable全链完成。
liuh只可unarmed；fonxanforce只可force；fonxansword可sword/parry；chaos可dodge/move。

## 13. Practice / cultivation / study 的必要边界

- **第一基本拳脚学习不依赖这些系统**。柳的learn足以教到教师/经验/资源允许的边界。
- practice只练已映射的advanced；basic和advanced须≥1、非fighting，再valid_learn、practice_skill。
  进度 `basic/5+1`；`weak_mode = !(basic>advanced)`，玩家weak时只累计进度不升级。
  不是任意无限绕过exp0限制。liuh成功kee-30（恰30允许）；chaos/fonxansword要求kee≥30、
  force≥3并分别扣30/3；fonxanforce明确不能practice。无额外潜能成本或该路径RNG。
- exercise只要求force有映射、显式cost≥10、kee≥cost、sen和gin各百分比≥70、非fighting。
  先扣kee，gain=`cost*(raw_force+base_con)/300`；gain<1也不退。current force加gain，
  若`current>max*2`，仅当`max<(raw_force+effective_force/5)*10`才max+1，然后current=max；
  一次最多max+1，超额丢弃，等于2max不升级。无直接exp条件。
- exercise help写默认30但代码不补默认值。不能按帮助文本发明无参数成功。
- selflearn仅dodge/force/sword/blade/staff/parry/unarmed、raw≥40；cost300/int，经验立方门槛、
  spent+1与random(int+raw)。不是新人解锁手段。非正int沿用DECISIONS已有Type B处理。
- study需要直接持有带skill元数据的教材、literate非0、教材exp_required、skill.valid_learn；
  cost=`sen_cost + sen_cost*(difficulty-int)/20`；先检查sen和raw>max_skill，再扣sen、
  写raw0、improve(literate_raw/5+1)。无须为本首学路线移植读书/教材。
- meditate/respirate不是最小拳脚依赖；只核对已有CultivationService共享边界，不扩成全修炼审计。

## 14. Combat-effect trace / 真正能力变化

S10 原始公式，Native [CombatMath](../../game/core/combat/math/combat_math.gd):5–20逐项对应：

```text
L = effective_skill + apply_attack_or_defense
if L == 0: power = combat_exp / 2
else if max_sen > 0: power = ((L*L*L / 3) / max_sen) * sen + combat_exp
else: power = L*L*L / 3 + combat_exp
AP = max(1, attacker power)
DP = max(1, defender dodge power)     # 随后 busy /3
PP = weapon/unarmed相关分支后min1     # 徒手挡武器等另有条件
```

| 技能 | 源战斗作用 | 当前Native消费/缺口 |
| --- | --- | --- |
| unarmed | 无主手时attack use；双方徒手时也用于defender parry power；非直接增加apply/damage | 投影实时读取state.skills，已有普通拳击动作；可复用 |
| sword | 主手sword时attack power；没剑学了不改变徒手攻击 | 已有获验证短/长剑投影，首学不必加新武器 |
| dodge | defense/dodge power | 已读取；低级exp0数值截断同样适用 |
| parry | defender持主手武器时parry power | 已读取；不能承诺空手时basic parry替代unarmed |
| liuh-ken | 映射后effective unarmed加完整raw，reset_action改选四个招式 | 当前映射动作集传null，直接产生MAPPED_ACTION_DATA_UNAVAILABLE；不能只接UI |
| fonxansword | 映射sword/parry、8个随机动作的damage百分比、perform路径 | Native无对应动作与hit-policy内容；完整移植另需能力范围审核 |
| force / fonxanforce | basic影响exercise cap/gain与恢复；mapped force hit_ob取决于force_factor/current；std/force会扣force和可能反震 | StandardForceHitPolicy已在Core，但runtime对mapped force标AUTHORED_POLICY_UNAVAILABLE；新人factor0，单纯学/映射不自动加伤 |
| chaos-steps | mapping增加dodge；move涉及原following而非Godot速度 | effective dodge已读，但学校内容/玩家enable未接；不得变成走路加速技能 |
| literate | study解锁；特定等级+int | 不直接给combat AP/伤害；柳的60级天花板无法提升int30新人的属性 |
| spider-array | team form需要leader且8人；源function只发文本返回1，未写阵法buff | 非单人战力提升。`array.c`不存在且柳不教array，不影响team form直接按skill调用；不能发明阵法增伤 |

**零经验误判示例：** unarmed3 + liuh3 → L4，`64/3/100=0`，满sen也为0；AP/PP仍1。
liuh动作的dodge(-40/-30)、parry(+40/+30)字段在该 combatd::do_attack **没有被读来修正AP/DP/PP**。
四个动作无damage/force百分比。不能拿这些元数据制造早期命中收益；缺失hit_ob的driver默认
行为也不是新增数值效果证据。fonxansword的damage百分比则确有明确消费位置。

**最小可观察比较：** E=2、unarmed raw2（L1），AP=2；相同E、raw0/1（L0），AP=1。
与同DP比较，真实命中分支的概率变了，不保证下一拳必定中或必胜。E0/E1时两者AP均1。
初始级别2由learn可达；后来经验必须从真实游戏获得。当前Old Pine探哨exp600并非特制
弱训练对象；正常搏斗有风险，本P1不证明新人能稳定完成。既有
`CombatProgressionService::_apply_hit:230–309` 对低AP攻击者的成功hit及受击防守者有
source经验/潜能增长路径；不能简化为「杀敌固定+2经验」。

若选择门派拳法进阶：E≥6时可学unarmed4、liuh5，映射L7；满sen100时
`343/3/100*100+E=100+E`，与不映射L2的E形成明显差异。需要更多学习、自然战斗往返及
mapped动作/hit policy集成，故列为第二候选。若owner要求零经验立即数值增强，以上候选均
未证明满足；须另行核验其它源路线及授权范围，不能直接假定加内功便可解决，更不能改截断/赠属性。

## 15. Existing Native foundation comparison

Ready指已存在的可复用Core/格式，不代表玩家已能操作；本节是静态审计，未运行测试。

| Source concept | Native type/service / 文件 | Ready | Partial | Missing | 分类/说明 |
| --- | --- | --- | --- | --- | --- |
| birth/attributes | `core/characters/new_player_initialization_policy.gd`、`character_base_attributes.gd` | ✓ | | | 出生及effective cor/cps可直接复用 |
| raw/learned/presence | `core/skills/character_skill_state.gd:25–179` | ✓ | | | 精确原始/零条目/learned累计/strict平方增长，source-faithful |
| skill IDs | `core/skills/skill_ids.gd` | ✓ | | | 11项均有常量 |
| skill definitions | `core/skills/skill_definition.gd:22–41` | | ✓ | | 有typed定义，未见生产教师完整11项内容catalog；type/enable必须authored |
| valid_learn | `core/learning/skill_learn_policy_registry.gd:76–156,269–306` | ✓ | | | known注册含基础继承默认；active注册单独调用不包含所有基础技能，注意选入口 |
| Learn ordering | `core/learning/learn_service.gd:26–279` | ✓ | | | 核心faithful，含零条目、严格门槛、spent/RNG顺序；玩家runtime未接 |
| teacher policy | `teacher_definition.gd`、`teaching_context.gd`、`f_master_teacher_prevention_policy.gd` | | ✓ | | stable ID/offer/两种direct predicate已有；柳数据和世界投影缺 |
| mapping | `skill_enable_transition.gd`、`skill_loadout.gd` | | ✓ | | domain检查/变化意图已有，resource-reset执行和UI缺 |
| family | `core/relationships/family_state.gd:6–16` | | ✓ | | 只有family_id/generation，无family title/privs |
| apprenticeship | `core/relationships/apprenticeship_state.gd:7–23` | | ✓ | | master ID/name/betrayer有，enter_time缺 |
| recruit transition | 全仓拜师调用搜索 | | | ✓ | 没有apprentice/recruit执行服务；不能把构造FamilyState当完整路径 |
| title/class/score | `player_identity_facts.gd:7–25` / `world_player_runtime_state.gd` | | ✓ | | title存在但只读身份；玩家class、score未表达 |
| potential/gin/exp | `character_progression_state.gd`、LearnService | ✓ | | | potential_spent即learned_points；gin非vitality；门槛正确 |
| practice | `core/training/practice_service.gd`、`practice_policies.gd` | | ✓ | | 规则与valid_learn组合已有；fonxan不能practice已有policy；liuh专用绑定/runtime未有 |
| exercise | `core/cultivation/cultivation_service.gd:20–102` | ✓ | | | 核心对应源，typed异常已批准；runtime未接 |
| selflearn | `core/training/self_learning_service.gd` | ✓ | | | 已有domain，首学不需要 |
| authored level effects | `core/skills/improvement_effects/skill_improvement_effect_registry.gd` | ✓ | | | Learn共用，不另写等级奖励；需绑定正确skill type |
| NPC base | `core/npcs/npc_definition.gd`、`npc_character_state_factory.gd:150–240`、`npc_runtime_state.gd` | | ✓ | | identity/随机缺省/技能/装备/存续已有，mapped/family/internal初值缺数据入口 |
| NPC persistence | `runtime/persistence/oldpine_world_save_capture.gd:116–153`、`oldpine_world_restore_composition.gd:157–274` | | ✓ | | 当前枚举OldPine，Snow新resident不能自动进入ledger |
| basic combat | `runtime/combat_slice/combat_slice_projection_builder.gd:64–190`、`core/combat/math/combat_math.gd` | ✓ | | | 实时借用同一state，基本技能数值已接 |
| advanced combat | 同上、`combat_action_selector.gd:14–22` | | ✓ | | generic core有优先级，生产mapped set=null；force/martial hook标unavailable |
| world/UI | `snow_world_definitions.gd:56–128`、`snow_outdoor_controller.gd`、`snow_inn_controller.gd:27–31` | | ✓ | | 连续zone/接触面板先例可复用；无学校/教学面板 |
| Save/Continue | codec、snapshot、capture、restorer、staged Session swap | | ✓ | | 当前技能关系字段round-trip基础已有；全部新增拜师字段/新NPC/地图范围仍需补齐 |

## 16. Native/source discrepancies / 不是P1修复单

1. **source-faithful、未接runtime：** Learn/F_MASTER/有效技能/等级成长/experience cap/指定
   valid_learn与exercise，所查正常新人路径无算法差异。没有理由重写一套学习引擎。
2. **已批准Type B：** stable teacher ID+窄legacy_master_name，world/spouse typed facts，
   injected roll，缺失recognition/valid_learn显式policy，legacy错误保留已完成mutation。
   DECISIONS:688–718已经说明，P1不重开或重写这些决定。
3. **incomplete：** Family/Apprenticeship只是学习判定所需子集；拜师执行、class/enter_time等缺失。
   这些不是「源没有该字段」，也不能偷偷丢弃。
4. **incomplete：** NpcFactory创建raw技能但未映射，也未设teacher family/force_factor/max_force。
   它计算资源时internal初值还是0；直接套柳再设置max_force会留下错误kee220，必须正确初始化
   顺序或显式源派生资源595。不是P1授权修改factory。
5. **incomplete：** typed enable返回clear-resource意图，command自映射在源是success/no-op，
   Native change_result false表示无变化；UI不应把「没改变」误显示成不懂技能。
6. **unknown / source oddity：** learn两边家族都缺失时，LPC缺省字符串比较及missing lfun行为
   不能类推为公开奖励；Core要求非空同家族是明确边界。柳有真实家族且新人先拜师，绕开此歧义。
7. **unused in public runtime，而非dead code：** Learn/Practice/Cultivation/Enable有Core测试和
   可复用类型，但检索不到学校application/runtime调用；不能删掉或重新复制。
8. **intentionally unavailable：** mapped攻击内容/force hit还没被生产投影支持，现有fail-closed
   返回是诚实范围边界；不把fallback到普通拳击伪装为高级技能已接通。

## 17. NPC runtime requirements / 教师存续

现有NpcDefinition可以表示柳的名称、别名、年龄、属性缺省、raw技能和可装备物品；
NpcRuntimeState/CharacterState可以持有实际可变资源与技能。它尚不能仅靠authored数据
一次表达family、mapping、internal初值、nickname/称谓与教学policy，需窄内容组合。

教学本身不消耗NPC sen、不改变教师raw技能、不保存徒弟列表；**师徒关系在Player端**。
教师的initial随机四属性仍是source事实；如果采用完整mutable NPC，就必须保存/恢复其
实际生成值、装备、生命和位置，不能Continue时重抽或复活。现有Save只按OldPine spawn
枚举；需接入Snow教师，旧档没有该slot时也需明确升级规则。

最低建议为**教学用途resident contact**，稳定TeacherId+源教学事实，遵循已有Inn窄接触先例；
教学只读projection可从源派生int24/sen170，教师不提供Fight/Kill/取装备/掉落/随机漫游。
这避免无必要地拉入全部教师战斗；但属于**新的Type B功能分期，待owner批准**，不是声称
柳在ES2不可战/不掉装备。NPC图像可以体现玄苏剑和马褂，不能创建可售假物品；全profile
留作authored metadata，不伪造随机spi/con值供规则使用。以后若启用依赖这些值的行为，
必须使用真实NpcFactory与持久化ledger，不能把contact冒充完整NPC状态。

在该建议边界下，教师服务没有新增可变数据，不需把它伪装为OldPine saved NPC；Player
进步和位置必须存。若owner拒绝contact分期而要求完整persistent NPC，§19列出的NPC ledger/
随机初值/装备catalog工作立即成为P2依赖，不能只加一个Marker2D就宣称完成。
无论哪种选择，都不需要通用对话树：现有proximity gate + 单教师typed请求/结果面板足够。

## 18. Minimum physical scope / 推荐三区

**Required now：** 沿现有snow.mstreet1向东，新增建议ID `snow.school1`、`snow.school2`、
`snow.schoolhall`，归属既有snow.outdoor连续resident。保留逐段zone身份、门的物理碰撞和
反向通行；不是跳过yard把柳搬到街边。目标spawn/摆放与地图geometry需P2实际设计验证。

**Useful but deferrable：** yard李火狮切磋、六学员；会让后续本馆练习更完整，但非柳学习必需。
**Explicitly deferred：** weapon_storage免费竹剑/机关、secret_storage、inneryard及其四分支、
其他内院人物、board、设置startroom、书院及书院teacher。school2 north、hall east应作为
明确分期边界呈现，不能宣称源不存在出口或加一个虚构永久门锁。

双侧门推荐具备Open/Close并初始closed；瞬态resident状态、不存门，cold Continue关闭，
角色保存位置排除闭门footprint。Hockshop的Open-only是它自己的已批准范围，不自动授权
学校同样删Close。若owner选择仅Open，必须另列分期决定。

## 19. Persistence/schema analysis

证据：[GameSaveJsonCodec](../../game/core/persistence/game_save_json_codec.gd):58–102,160–223；
`game_save_value_types.gd:259–325`；`character_state_snapshot_restorer.gd:38–129`；
`oldpine_world_save_capture.gd:230–336`。当前严格root2/item3/SOURCE_ENTRY_V1。

| 字段 | 已存？ | 需要的工作 |
| --- | --- | --- |
| family ID/generation | YES | 把source家族名映射稳定ID，名称保留authored metadata |
| master teacher ID/legacy name/betrayer | YES | 当前结构精确保存两类关系判定所需字段 |
| raw技能/learned progress/map/presence | YES | 保留零条目、空map与缺map差别，勿重新生成等级 |
| potential/spent/combat_exp | YES | 花费写spent，精确恢复当前值 |
| gin/kee/sen三轨 | YES | 保存扣精后的current/effective/max，Continue不能填满 |
| force/max_force及factor | YES | 将来启用exercise/enable时沿用；本建议不要求它们有非零初值 |
| 玩家显示title | YES，identity.title | 当前PlayerIdentityFacts只读；需受控替换身份facts seam，保持state/body/ID不变 |
| family title/privs | NO | 源收徒明确写入；首次是弟子/0，可authored派生或显式存储，选择待批准 |
| enter_time | NO | `time()`是入门时刻，不是游戏时长或读档时间；须新typed存储，不可从saved_at反推 |
| class=swordsman | NO | 源NPC override真实写入；不能遗漏，建议typed class ID |
| Player score | NO | 正常首次不写；若支持换门派/反向握手，需表示score及其归零行为 |
| pending/cancel | NO | LPC临时；若保留则瞬态，Save边界不能半完成请求后假称 settled |
| 教师 mutable NPC | 低层格式支持，runtime不支持Snow slot | contact提案无新增教师mutable state；完整NPC方案需ledger/恢复与旧slot迁移 |

**是否必须root bump：不是仅因学习而必需；也不能不经版本设计直接塞字段。** 现codec严格
键集合，character没有独立schema；把enter_time/class写入就发生真实格式演进。
建议owner批准「显式character子版本，旧无版本shape作为历史版本解码，新shape严格校验」，
保留root2、item3和SOURCE_ENTRY_V1；root2支持范围因此需要精确文档和双shape测试。
若owner偏好root新版本，也须保留root2读取；P1不决定版本号/键名。不能为躲schema把
enter_time塞进title、master_name或一段通用JSON字符串。

新增zone本身通常不需要source revision变更：可在既有四resident合同内扩展注册与placement，
保留旧zone/位置有效。新完整NPC的缺slot问题是内容升级问题，source revision不变也得有
明确迁移；不得误称「有泛型NpcSnapshot就全自动兼容」。新增第四个RNG流同样改变格式，
无必要不加。建议成功Learn在现有world-interaction流上抽且只在源进步分支消费，需适配
现有LearnService的attempt-local roll接口以避免预先抽数、重复执行检查和mutation。

## 20. Old-save compatibility

当前root2已有默认空family/master/skills结构。codec→typed snapshot→restorer原样恢复
这些字段，不需给旧玩家凭空拜师或授课。`game/tests/core/game_save_json_codec_test.gd`
已有排序/重复ID/typed snapshot校验，`tests/support/oldpine_world_save_fixture.gd`和
new-player测试提供既有样本；本P1只读这些测试，未宣称它们为新功能跑过。

推荐迁移边界：

- 旧空关系：新关系扩展显式ABSENT/未入门，不填当前时间、不创建class，不赠技能。
- 旧档可能在typed Core保存过非空family/master：不能假定所有合法root2都空。
  原状态精确保留，缺失新时间必须表示UNKNOWN/未记录，不能伪造真实入门时刻；是否接受
  这种legacy关系继续教学需owner定策，不能默默拒绝本来合法的Continue。
- Snow/Hockshop保存位置、卖后物品缺失、装备、food/liquid、allocator与三RNG原样；不触碰item3。
- 当前fresh New Game仍从Inn、空关系开始；以后首次拜师才记录实际时间/身份变化。
- 必须使用本次以前的**实际root2存档fixture/文件副本**测试：空关系、非空合法Core关系、
  inside-Hockshop、普通Snow、OldPine、new school位置、raw0失败残留、学习中间进度和spent。
  cold Continue要保持同一状态语义，不是重新授予一组相同等级而丢掉learned进度。
- 若完整teacher NPC，旧无slot时只在明确升级入口新增合法teacher一次；已有死teacher记录
  不能因「缺live body」就复活。contact方案则没有这个新增slot/重抽问题。

旧档兼容分析为静态结论，不是P1实际Save/Continue实测结果。严禁在P1改migration。

## 21. UI / interaction translation proposal

推荐一个柳专用面板：姓名与源身份、首次拜师、可选技能与当前raw/learned、每次gin成本、
可用potential（total-spent）、真正结果与被拒原因。使用稳定TeacherId，不用显示名做主键。
成本所用base int及资源从当前Player和教师projection读取；点击后重新核验，不以打开面板时的quote授权。
显示11项源教师能力清单可以说明分期，但若P2仅开basic unarmed，其他条目应明确「本阶段未开放」，
不能谎称柳不会教或按钮其实无条件赠一级。

实际到场、正确active map/zone、有效physical placement、接近contact、ACTIVE Session、
面板输入隔离及退出/换图失效复用现有Snow接触模式。建议仅普通非战斗接触；对apprentice/
enable额外排除combat/busy是Type B分期（learn只原生禁fighting），必须owner批准，不能
误报是原始规则。失败保留零条目和扣精结果需要诚实呈现，不统一显示「失败所以无变化」。

推荐一次按钮=一次源Learn，不加自动连点学习、计时收费或资源回血。普通恢复继续由现有
Session cadence拥有；面板是否暂停必须与既有UI生命周期一致，禁止UI私自补gin。
既有WaiterContact是窄接触先例，Hockshop证明了实时authority与location的分离；二者都
不是可以直接传入TeacherDefinition的generic NPC引擎。为一个教师做小面板即可。

## 22. Preliminary Type A / B / C ledger

| 类型 | 本提案内容 | 权限状态 |
| --- | --- | --- |
| A | 原路径/房名/门初态/教师身份；cor/cps、收徒家族结果；Learn顺序和整数公式；真实skill IDs/levels/valid_learn；base对combat的作用；持久状态语义 | 已分析，尚未授权P2实现 |
| A | 经验0可达raw3、strict learned平方门槛、失败扣精/零条目、潜能spent、无自动赠经验 | 必须保留，非建议「修正」 |
| B 已批准先例 | Native typed状态/稳定ID、无LPC runtime、既有Learn legacy error与world facts边界 | 复用对应DECISIONS，不扩为其它系统万能授权 |
| B 待批准 | 连续三区、teacher contact分期、其它人口/侧路省略、门cold默认、proximity、非战斗窗口、pending/cancel翻译、title更新seam、版本化旧档兼容、Learning RNG接线 | 见§27，P1未定 |
| C | 新经验礼包、降低武学/内力条件、改integer公式、练功送武器、把source动作未消费字段变buff、免费学习/新玩家调平 | **0 required；不提议实施** |

## 23. Source oddities / 必须保留或决策

| 现象与证据 | 处理建议 |
| --- | --- |
| school.c是书院，schoolhall sizeof注释1但实际2 exits；大厅说四大师傅但spawn只有柳（S1/S2） | 以可执行topology为Type A，不按名字/注释生成内容 |
| schoolhall replace_program后执行 `"obj/board/swordsman_b"->foo()`；board不是objects spawn | deferred board依赖，不能凭这行承诺大厅可运行论坛；不做LPC动态加载模拟 |
| 拜师正反握手对首次betrayer不同；help称技能减半但未执行（S5） | 保留正常NPC链；另一路分期/错误要owner定，不能给新人扣半技能 |
| 属性门槛用query_cor/query_cps，有bellicosity/factor/modifier（S3/S12） | 精确Type A，不只检查base属性 |
| failed apprentice留下pending，取消后可再试；recruit成功文本不核验override返回值 | type outcome应能揭示具体失败；是否保留pending等待owner |
| 两种direct apprentice predicate不一致（S5/S6） | 已批准保留，不能合并为一个更「正确」判断 |
| raw0先写后失败；fatigue/经验不足也可能command返回1（S6） | 分开executed/progressed/leveled，保持顺序 |
| int24/30是11再raw0翻22，不是浮点12.5；exp0可升3（S6） | 精确Type A |
| random0变1点；strict `>`阈值；每次仅一级、丢溢出；learned条目数量惩罚（S7） | 精确Type A |
| fonxanforce学习无base门槛；柳自己没map force（S3/S8） | 不替教师「修正」mapping，不加学习前置 |
| fonxansword要max_force而非current；basic sword不需要武器（S8） | 精确分开两类技能 |
| 默认学习的spider-array没有战斗buff；enable array依赖的array.c缺失；team form不经enable（S8/S9） | 阵法使用延后，不能认定它不可学，更不能生成阵法加成 |
| team with拼作dellete_temp（team.c:48附近），与首学无关 | 记录危险依赖，team deferred，不修 |
| exercise无实质默认30，超额内力丢弃；learn低等级使cultivation cap不足50 | 源行为保留，不以UI默认/无经验练满补救 |
| source weapon_storage对任意非空非shelf参数都按左推累加，10秒动态通道（S2） | 整个谜题延后，不创造更合理的push左右解析 |
| liuh动作dodge/parry字段未被combatd消费；低级cube计算截断（S10） | 不能把技能名字/动画/进度当数值战力；保留Type A |
| absent hit_ob/recognize等受missing-lfun部署语义影响；teacher carry忽略move成功后wield | 不构造通用兼容层；启用相关路径时需窄policy并披露，不默认万能成功 |

## 24. Migration-tooling observations

**Likely machine-extractable：** room文件路径、literal short/exits/outdoors/objects/count、
create_door静态参数、set_name及alias数组、gender/age/显式属性/exp/score、set_skill的11项、
map_skill的4项、create_family、carry/wield/wear引用及顺序。保留line span、inherit链、
__DIR__/CLASS_D/SKILL_D宏解析来源与authored-vs-derived标记；不把不存在的属性当0/30。

**Requires semantic/manual analysis：** apprentice→command(recruit)→override→inherited及userp
分支；两种师徒判定；valid_learn的顺序；原始/有效skill差异；学习和资源先后mutation；
NPC资源在setup时由max_force影响；combat中实际读哪些字段；static与persistent；
room reset/return_home及dynamic exits；typed Native现有系统是否已承担该规则。

**Dangerous to auto-translate：** 从help推规则、从注释sizeof推边数、从school文件名推武馆、
把`d/skill`与`daemon/skill`混用、把query_skill默认当raw、把老师会的技能当新人能学/能用、
把map_skill当enable、把缺失函数当allow、把source数值field自动接成combat buff、
把整数运算改float/整体除法、自动回滚late failure、按raw技能数量替换learned条目数、
用当前时间补入门时间、把NPC spawn和无状态contact等同、给每个room生成scene。

P1没有写parser/generator/tool，也没有创建Migration Tooling v1分支或scope。

## 25. Recommended P2 scope / 一个有界建议

按实施依赖排序的候选（不是同时实施清单）：

| 排名 | 候选 | 得到什么 / 代价 |
| --- | --- | --- |
| **1 推荐** | 首次拜柳 + **basic unarmed**学习 + 原有combat自然E≥2 + Save/cold Continue | 最少新增教学接线；basic无需enable、不改普通战斗公式。数值收益须E门槛后的真实证据，非承诺经验0立即变强 |
| 2 | unarmed+liuh-ken、enable、原有combat往返至E≥6、学到unarmed4/liuh5 | 更像门派武功；新增4招式/映射/hit-policy/runtime QA，L7有明确数值贡献 |
| 3 | force+fonxanforce、enable、exercise与内力应用 | 源能力链成立，但引入练功、factor/force hit接线与更大UI；非最小教学切片 |

**推荐P2只取候选1**，且须先批准§27：

- Rooms：现有街道向东的school1/2/hall三区和双侧门；关闭侧路是显式分期。
- NPC：一个柳教学contact，真实身份/int24/sen170/家族13/skills元数据；无新combat target，
  不移植guard/fist_trainer/trainee。完整NPC方案如被选择则重新计算依赖，不偷偷扩大本候选。
- Interactions：首次Apprentice、重拜请安、Learn unarmed单次请求；pending/cancel按owner选项。
  其它10项技能不是老师不会，明确分期；不加通用trainer框架。
- Apprenticeship：完整首次结果含家族、master、generation14、title、class、入门时刻；
  无family时不加betrayer、不改score。跨门派/玩家收徒不进入P2公开操作。
- Skills：复用default valid_learn + F_MASTER + LearnService + 既有improve/effects，正确成本和RNG。
  可学到经验/资源允许的等级；**不人为cap到2/3**，2只是最小验证点。
- Mapping：basic unarmed不需要enable，故本候选不开放advanced mapping；不是删除source规则。
- Combat：同一CharacterState被现有投影实时读；真实徒手操作、自然经验获取后记录实际AP/结果，
  用同E/raw不同的domain比较证明技能贡献。禁止只靠Save字段、按钮callback或修改exp做E2实机证据。
- Persistence：实现首次拜师缺失的字段与受控title更新；owner批准的版本化旧shape兼容；
  既有root2/item3/SOURCE_ENTRY_V1不能未经判断破坏。保持Player/body/allocator identity。
- Tests：新增首次拜师链/属性19与20/幂等时间/失败pending、Learn raw0/1/2/3 exp0/2/6、
  gin22与23/11与12、teacher sen5与6、潜能耗尽零条目、roll0/1/29、late failure和RNG消费边界；
  AP E0/E1/E2/高级L6/L7对照；新增字段旧档/冷启动精确round-trip。
- Runtime验收：canonical主场景真实New Game→走路/碰撞/Open/Close→柳UI拜师/学到raw≥2→
  返回真实Old Pine combat/Flee/恢复等现有流程→自然E≥2与能力证据→Save→终止→cold Continue。
  需要helper_live/session_active/game_capture_ready true、current_run_errors空、stale_frame false、
  递增帧号与真实输入。可能失败/无法安全获得经验就如实BLOCKED，不能改敌人/技能/经验配平。
  Headless/deterministic证明公式，真实游戏证明操作与状态生命周期，二者不能互相替代。

在owner审阅前，不把候选1称为「保证可玩/已验证」。如果希望柳家拳才算首个有意义技能，
应显式选择候选2作为新的有界P2授权，而不是分析者自行扩展。

## 26. Explicit deferrals / 本次检查与停止状态

P1没有新增任何源/生产GDScript、scene、Resource/JSON、UI、测试、schema、project/CI/build、
migration tooling；DECISIONS delta0。没有PR，没有P2实现或Migration Tooling v1工作。
建议后续仍延后：武館全人口/完整柳战斗及掉落、玩家互收徒、改投师门/expell、spouse卡、
practice/study/selflearn/exert/perform/阵法、藏库/谜题/内院/board、自动学习队列、免费装备、
full Snow。现有Hockshop/恢复/水/战斗公式与其它里程碑范围保持原有授权。

文档验证：`tools/ci/repository_checks.py` PASS；3个修改文档的120个本地Markdown链接
全部存在；尾空白检查、27个编号章节完整性、精确3文档allowlist及 `git diff --check` PASS。
另行对照源公式、Native引用和建议边界进行了文档自审。**未运行/不声称新的canonical、Godot
live或实机验证**。本P1一个docs-only提交，推唯一phase分支，随后停止等待owner审阅。

## 27. Questions requiring owner decisions

所有项尚未决定，不能从本节的推荐措辞推断已获批准：

1. **能力验收/技能范围：** 是否批准候选1（basic unarmed + 自然经验后数值收益）？若要求
   门派动作与明确更大攻防收益，是否改选候选2？经验0立即数值增强不是已证实的首学结果。
2. **NPC与人口分期：** 是否批准只读教学contact及柳战斗/装备掉落/随机NPC属性行为延后，
   同时省略guard/李火狮/六学员？还是要求完整persistent NPC，承担§17的增量范围？
3. **物理门与状态：** 是否批准同resident三区、侧路分期、双侧Open/Close、cold关闭与
   保存点避门缝？不能直接套用Hockshop的Open-only许可。
4. **拜师握手/受限输入：** 首次NPC同步链是否保留typed pending/cancel及失败后重试语义？
   或批准一次点击的显式Type B替代？是否批准公开操作仅首次/幂等、非战斗/非busy窗口，
   而将改师、逆向邀请与玩家收徒明确延后？
5. **持久化缺项：** 是否批准enter_time/class等typed字段与受控title更新；family title/privs
   是显式存储还是在这个唯一关系中严格派生？建议显式character子版本并保留root2读取、item3/
   SOURCE_ENTRY_V1；旧非空关系的未知入门时间使用UNKNOWN，不伪造。具体格式须先批准。
6. **RNG与数据权威：** 是否批准成功学习借用现有world-interaction流、在源进步点恰好一抽，
   而文本随机不消费gameplay流？持久化实际RNG，不用固定高roll或先抽后发现无效。

所需Type C决定为0；若验收时必须改成长公式/补发经验才可达，应停止并另求owner方向，
不将它包装为Type B补线。P1结论是可供审核的最小范围与风险，不是实施批准。
