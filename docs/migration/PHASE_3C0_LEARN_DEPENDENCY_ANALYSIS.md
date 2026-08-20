# Phase 3C0：Learn 依赖分析

## 结论

原作 `learn` 不是一个教师对象自行执行的能力，而是
`cmds/std/learn.c` 集中编排的一次学习事务。它同时读取教师定义/状态、
玩家师门关系、玩家技能与进度、技能自身的 `valid_learn()` 规则，并在成功路径中
调用已有的 `improve_skill()`。LPC 的对象查找、动态方法调用、dbase 路径和消息输出
不应成为 Godot 架构。

下一实现阶段不需要先建立完整 NPC、世界或门派系统。最小可行方案是：以稳定 ID
描述 `TeacherDefinition` 与 `TeachingOffer`，由调用方提交窄化的
`TeachingContext`，再由纯领域 `LearnService` 编排现有角色、技能与 authored effect
系统。为了忠实表达通用准入规则，需先增加一个最小、只读语义明确的
`FamilyState` / `ApprenticeshipState`；招募、叛师、逐出、称号和门派剧情可留待后续。

本文只分析，不新增生产 GDScript，也不改变既有领域行为。

## 权威来源与检查范围

完整阅读的核心文件：

- `reference/es2/mudlib/cmds/std/learn.c`
- `reference/es2/mudlib/feature/skill.c`
- `reference/es2/mudlib/std/skill.c`
- `reference/es2/mudlib/feature/apprentice.c`
- `reference/es2/mudlib/std/char.c`
- `reference/es2/mudlib/std/char/npc.c`
- `reference/es2/mudlib/std/char/master.c`
- `reference/es2/mudlib/feature/attribute.c`
- `reference/es2/mudlib/feature/damage.c`
- `reference/es2/mudlib/feature/name.c`
- `reference/es2/mudlib/include/globals.h`
- `reference/es2/mudlib/include/skill.h`
- `reference/es2/mudlib/cmds/std/apprentice.c`
- `reference/es2/mudlib/cmds/std/recruit.c`
- `reference/es2/mudlib/cmds/std/expell.c`

任务指定的 `reference/es2/mudlib/std/npc.c` 在原库中不存在。`NPC` 宏实际指向
`/std/char/npc`（`include/globals.h`），因此检查的是
`reference/es2/mudlib/std/char/npc.c`。

完整阅读的代表性教师/师父：

- `reference/es2/mudlib/daemon/class/swordsman/master.c`
- `reference/es2/mudlib/daemon/class/fighter/master.c`
- `reference/es2/mudlib/daemon/class/fighter/champion.c`
- `reference/es2/mudlib/daemon/class/bonze/master.c`
- `reference/es2/mudlib/daemon/class/scholar/master.c`
- `reference/es2/mudlib/daemon/class/ninja/master.c`
- `reference/es2/mudlib/daemon/class/juechen/master.c`
- `reference/es2/mudlib/daemon/class/dancer/master.c`
- `reference/es2/mudlib/daemon/class/beggar/master.c`
- `reference/es2/mudlib/daemon/class/taoist/taolord.c`
- `reference/es2/mudlib/d/city/npc/chen.c`
- `reference/es2/mudlib/d/green/npc/master.c`
- `reference/es2/mudlib/u/cloud/npc/b_header.c`
- `reference/es2/mudlib/d/snow/npc/teacher.c`
- `reference/es2/mudlib/d/snow/npc/teacher1.c`
- `reference/es2/mudlib/d/snow/npc/fist_trainer.c`
- `reference/es2/mudlib/u/cloud/npc/girl.c`
- `reference/es2/mudlib/d/temple/npc/trainer.c`
- `reference/es2/mudlib/d/temple/npc/tfighter.c`
- `reference/es2/mudlib/d/latemoon/room/npc/old.c`

此外结构扫描了全部 16 个 `inherit F_MASTER` 对象：上述门派师父之外还包括
`daemon/class/assassin/master.c`、`daemon/class/lama/master.c`、
`daemon/class/ronin/master.c`、`d/latemoon/room/npc/aaa.c`、
`d/latemoon/room/npc/elon.c`。扫描内容包括身份、家族创建、技能表、拜师与招募入口。

`SKILL_D(skill)` 固定解析至 `/daemon/skill/<skill>`。因此结构读取了
`reference/es2/mudlib/daemon/skill/` 中全部 45 个显式定义
`valid_learn()` 的文件：

- `bloodystrike.c`、`bolomiduo.c`、`buddhism.c`、`celestial.c`、
  `celestrike.c`、`chaos-steps.c`、`cloudstaff.c`、`deisword.c`
- `essencemagic.c`、`fall-steps.c`、`fonxanforce.c`、`fonxansword.c`、
  `force.c`、`gouyee.c`、`iceforce.c`、`jin-gang.c`
- `jingang-staff.c`、`juechen-force.c`、`linbo-steps.c`、`liuh-ken.c`、
  `lotusforce.c`、`magic-array.c`、`meihua-shou.c`、`mysterrier.c`
- `mystforce.c`、`mystsword.c`、`necromancy.c`、`nine-moon.c`、
  `notraces.c`、`pyrobat-steps.c`、`qidaoforce.c`、`scratching.c`
- `serpentforce.c`、`shortsong-blade.c`、`six-chaos-sword.c`、
  `snowshade-force.c`、`snowshade-sword.c`、`snowwhip.c`
- `spicyclaw.c`、`spring-blade.c`、`stormdance.c`、`taoism.c`、
  `tenderzhi.c`、`ts-fist.c`、`wu-shun.c`

没有覆盖函数的技能继承 `std/skill.c::valid_learn()`，默认允许。`d/skill/` 中存在
若干旧副本，但运行路径由 `include/globals.h::SKILL_D` 指向 `daemon/skill/`；旧副本
不是 Learn 的动态目标。

全库还检索了 `learn_skill()`、`learn_from()`、`accept_learn()`、
`valid_learn()`、`recognize_apprentice()`、`prevent_learn()`、
`is_apprentice_of()`、family/master 字段、`potential`、`learned_points`、
`skill_improved()` 以及教学相关 `improve_skill()` 调用。结果是：

- 不存在 `learn_skill()` 或 `learn_from()` 定义/调用。
- `accept_learn()` 只存在于两个魏无极文件，`learn.c` 从不调用它。
- `prevent_learn()` 只有 `std/char/master.c` 定义。
- 自定义 `recognize_apprentice()` 只有魏无极两份、李火狮和李师师四类文件。
- 教学导致技能进度的直接调用只有 `cmds/std/learn.c` 中的
  `me->improve_skill(...)`；`practice`、`selflearn`、`study` 是独立路径。

`skill_improved()` 搜索再次确认 active authored callback 是
`daemon/skill/celestial.c`、`force.c`、`literate.c`、`music.c`、
`nine-moon.c`、`six-chaos-sword.c`、`stormdance.c`、`tao-mystery.c`、
`unarmed.c` 九个；另有 `std/skill.c` 默认空 hook 与 `d/skill/` 的旧副本。Learn
没有专属回调分派，它只通过 `feature/skill.c::improve_skill()` 进入已经迁移的同一
callback/effect 路径。

## `learn.c` 的精确执行与变更顺序

以下顺序来自 `cmds/std/learn.c`，顺序本身属于兼容语义：

1. 解析 `learn <skill> from <teacher>`。这是命令层输入解析。
2. 若学生正在战斗，拒绝。
3. 在学生当前 environment 中用 `present()` 找对象，并要求其
   `is_character()`。
4. 要求教师 `living()`。
5. 扫描学生全部随身物品，寻找 `id == "marrycard"`；解析婚约物品名称，
   再以 `find_player(target)` 得到伴侣对象。它只用于后面的教师身份豁免。
6. 调用 `learn.c` 私有的 `is_appr_of(student, teacher)`：学生
   `family/master_id` 必须等于教师 `id`，且学生 generation 必须恰好是教师
   generation 加一。
7. 若不是上一步意义下的嫡传弟子、教师也不是当前在线伴侣，则：只有当双方
   family name 相同且教师 `family/privs == -1` 时自动通过；否则调用教师
   `recognize_apprentice(student)`，返回假则拒绝。
8. 读取教师 `query_skill(skill, 1)` 原始等级。值为 0 时拒绝。
9. 调用教师 `prevent_learn(student, skill)`。通用师父 mixin 的规则见下节。
10. 读取学生 `query_skill(skill, 1)` 原始等级；学生等级大于等于教师时拒绝。
11. 调用目标技能 daemon 的 `valid_learn(student)`；失败则拒绝。
12. 计算 `gin_cost = 150 / teacher.int + 150 / student.int`。这里直接读取持久字段
    `query("int")`，不是 `query_int()`；保持 LPC 整数除法。
13. 若学生原始等级为 0，成本翻倍，并立即 `set_skill(skill, 0)`。
14. 若 `learned_points >= potential`，拒绝。
15. 输出“请教”文本。
16. 若教师 `env/no_teach` 为真，拒绝。
17. 通知教师。
18. 教师当前 `sen` 必须严格大于 `gin_cost / 5 + 1`。否则本次命令返回已处理，
    不扣学生 gin、不消耗 potential。若教师是玩家，扣除相同 sen；NPC 教师只做
    阈值检查，不扣 sen。
19. 学生当前 `gin` 必须严格大于 `gin_cost` 才有机会获得进度：
    - 若技能 type 为 `martial`，且 `my_skill^3 / 10 > combat_exp`，不获得进度；
    - 否则先令 `learned_points += 1`，再调用
      `improve_skill(skill, random(int + combat_exp / (1000 + combat_exp / 1000)))`。
20. 若学生 gin 不严格大于成本，把实际成本改为当前 gin，不获得进度。
21. 通过教师疲劳检查后的所有路径都以 `receive_damage("gin", gin_cost)` 扣学生
    当前 gin；随后返回成功。

几个容易遗漏的顺序后果：

- 初学技能的零等级条目在 potential、`env/no_teach` 和教师疲劳检查之前写入；
  所以后续失败仍可能留下“已定义但等级为 0”的技能。
- `valid_learn()` 在该零等级条目写入之前执行。
- `learned_points` 只在实际调用 `improve_skill()` 的分支增加；教师疲劳、gin
  不足或 martial 经验不足均不消耗 potential。
- `skill_improved()` 由 `improve_skill()` 同步触发，发生在学生 gin 扣除之前。
- 一次 Learn 对 `improve_skill()` 只调用一次；等级增长、无 carry、回调和 authored
  effect 规则应继续由已经关闭的 Phase 3A/3B3 实现负责，Learn 不重算它们。

## 1. `cmds/std/learn.c` 自己拥有的行为

它拥有一次教学事务的编排、验证顺序、成本/随机上界/经验门槛公式、potential
消耗时点、学生 gin 消耗，以及是否调用 `improve_skill()` 的决定。它还混入了命令
解析、同场对象查找、婚约物品扫描和文本输出；后四者不是领域职责。

## 2. 教师/师父对象拥有的行为

教师提供身份、持久基础智力、当前 sen、原始技能及等级、family/generation/privs、
`env/no_teach` 状态，以及两种可选 authored policy：

- `recognize_apprentice(student)`：在通用关系不能自动放行时识别学生。
- `prevent_learn(student, skill)`：`F_MASTER` 的背叛者和非嫡传等级限制。

NPC 的拜师条件（例如性别、属性、战斗经验、任务信物）属于如何取得师徒/门派
关系，并不由 Learn 本身重新检查。

## 3. 通用检查与 NPC authored 检查

通用检查包括：不在战斗、教师可交互/清醒、关系准入、教师拥有更高的非零原始
技能、`valid_learn()`、potential、教师 sen、学生 gin、martial combat-exp 门槛。

authored NPC 检查仅通过 `recognize_apprentice()` 或取得师徒关系的前置剧情表达：

- 魏无极检查 `marks/魏无极`；该 mark 由交付至少 500 value 的物品设置。
- 李师师检查 `marks/李师师`；该 mark 由交付无价值信物且满足性别/外貌条件设置。
- 李火狮接受任何 `family_name == 封山剑派` 的学生。
- `F_MASTER::prevent_learn()` 对 `betrayer` 和非嫡传学生统一限制，不是每个 NPC
  各写一份。

## 4. Learn 实际需要哪些状态

| 候选状态 | Learn 是否直接需要 | 精确用途 |
| --- | --- | --- |
| 当前 master 关系 | 是 | 私有 `is_appr_of()` 的 `master_id` 与 generation 检查；`F_MASTER` 还调用另一版 `is_apprentice_of()` |
| 同 faction/family | 是 | 与教师 `privs == -1` 组合，决定是否免除 `recognize_apprentice()` |
| generation | 是 | Learn 私有嫡传判断要求学生 generation 为教师加一 |
| title | 否 | 只出现在拜师/招募/展示等相邻系统，Learn 不读 |
| privileges | 是，但只读教师值 | `-1` 表示同门学生可跳过识别；不是通用权限系统的需求 |
| NPC/教师身份 | 是 | master 关联、伴侣豁免和 mark policy 都需要稳定身份；不需要 NPC AI |
| 技能可教性 | 是 | 教师目标技能原始等级必须非零且高于学生 |
| player potential | 是 | `learned_points >= potential` 时拒绝 |
| learned_points | 是 | 成功进度分支加一 |
| combat experience | 是 | martial 经验门槛及随机上界 |
| attributes | 是 | 双方持久基础 intelligence；部分 `valid_learn()` 另读属性 |
| raw/effective skill | 两者皆可能 | 主流程只用 raw；技能 hook 可能读 raw、effective 或映射 |
| mapped skill | 主流程否、hook 可能是 | 如 `fonxansword`、`mysterrier`、`nine-moon`、`snowshade-sword` |

## 5. 验证与 mutation 顺序

精确顺序见上方 1–21。未来 `LearnService` 应用阶段必须以结果对象记录失败位置，
不能先汇总所有验证再统一 mutation，因为原作在部分后期失败前已创建零等级技能；
也不能在验证前扣 potential 或 gin。

## 6. 消耗的资源/进度值

- 学生 `gin`（Godot `CharacterState.essence.current`）：只在教师有足够 sen 后扣除；
  不足时扣到 LPC 的 0 路径，`receive_damage()` 的现有语义继续复用。
- 玩家教师 `sen`（Godot `spirit.current`）：阈值为 `gin_cost / 5 + 1`，且仅原作
  `userp(teacher)` 扣除。未来应由明确的 `teacher_pays_spirit_cost` 语义表达，不能把
  `userp()` 移植为运行时类型判断。
- `learned_points`（现有 `potential_spent`）：仅成功调用 `improve_skill()` 前加一。
- `learned[skill]`：由现有 `CharacterSkillState.improve_skill()` 修改。
- food、water、force、mana、atman、金钱均不由 Learn 直接消耗。魏无极的 500
  value 是取得 authored 认可 mark 的前置事件，不是每次学习成本。

## 7. `improve_skill()` 何时发生

仅当教师 sen 严格充足、学生 gin 严格大于成本、且 martial 经验门槛通过时发生。
调用前先加 `learned_points`。随机入参上界为：

```text
student.int + student.combat_exp / (1000 + student.combat_exp / 1000)
```

这里的 `student.int` 也是持久基础字段，不包含 `apply/intelligence`。

## 8. raw 与 effective 等级

Learn 主流程对教师等级、学生比较、初学判断及 `my_skill^3 / 10` 全部使用
`query_skill(skill, 1)`，即 raw。它不使用该技能的映射结果。

但是 Learn 始终调用 `valid_learn()`，而 authored hook 并不统一：

- 显式 raw：`celestrike` 读 raw `celestial`，`linbo-steps` 读 raw
  `literate`，`mystsword` 读 raw `mystforce`。
- effective：`celestial`、`essencemagic`、`gouyee`、`lotusforce`、
  `magic-array`、`mysterrier`、`necromancy`、`wu-shun` 使用未带 raw 参数的
  `query_skill()`。
- mapped：`fonxansword`、`mysterrier`、`nine-moon`、`snowshade-sword` 调用
  `query_skill_mapped()`。

因此未来技能学习 policy 不能粗暴概括成“只需 raw skill snapshot”。

## 9. 参与的 `valid_learn()` hook

任意被请求技能的 daemon hook 都参与；没有“只有教师技能表中某几类才调用”的
捷径。45 个覆盖函数的实际约束可归纳如下：

- 恒允许：例如 `force`、`bolomiduo`、`fonxanforce`、`iceforce`、
  `jin-gang`、`juechen-force`、`mystforce`、`pyrobat-steps`、
  `qidaoforce`、`serpentforce`、`shortsong-blade`、`spring-blade`。
- 内部资源上限/属性：例如多个步法要求 `max_force >= 50`，`snowwhip` 要求
  `max_force >= 150`，`cloudstaff`/`jingang-staff` 检查
  `str + max_force / 10 >= 50`，`stormdance` 检查 gender 与 base spi。
- 技能前置/比例：例如 `celestrike`、`essencemagic`、`lotusforce`、
  `magic-array`、`mysterrier`、`mystsword`、`necromancy`、`wu-shun`。
- 装备/空手：剑、鞭技能检查当前武器类型；多种掌/指/爪要求双手无武器。
- 映射前置：`fonxansword` 等要求指定 force 映射。
- 性别/道德状态：`stormdance`、`tenderzhi`、`nine-moon` 检查女性；
  `buddhism`/`taoism` 限制 bellicosity，`celestial` 要求足够 bellicosity。

这证明需要窄化、按 skill ID 注册的 `SkillLearnPolicy`，而不是把所有依赖塞进
`SkillDefinition` 或 LearnService 的大 `match`。装备、战斗与未来状态尚未具备时，
只实现依赖已关闭领域的代表 hook，其余明确返回“policy dependency unavailable”，
不能静默放行。

## 10. NPC-specific 拒绝规则

Learn 时实际可拒绝的 NPC policy 只有：

- `recognize_apprentice()` 的 mark/family 规则；
- `F_MASTER::prevent_learn()`：
  - 若 `betrayer != 0` 且学生 raw 等级 `>= teacher_raw - betrayer * 20`，拒绝；
  - 若学生不是 `feature/apprentice.c` 意义下的嫡传弟子，且教师 raw
    `<= student_raw * 3`，拒绝。
- 教师自身 `env/no_teach`、当前 sen 与技能表状态。

性别、属性、金钱、任务信物、战斗测试等大多是“能否拜师/取得认可 mark”的规则，
不是每次 Learn 重新执行的教师拒绝规则。

## 11. 无需嫡传师徒关系也可教学的 NPC

- `d/snow/npc/teacher.c` 与 `teacher1.c`：有 `marks/魏无极` 即可学其
  `literate`，不创建 family。
- `u/cloud/npc/girl.c`：有 `marks/李师师` 即可学其 `literate`。
- `d/snow/npc/fist_trainer.c`：任何封山剑派成员均可通过识别，不要求李火狮为
  当前 master。
- 同 family 且教师 `privs == -1` 的门派成员可绕过识别；若教师继承
  `F_MASTER`，非嫡传学生仍受“教师等级必须严格高于学生三倍”的限制。
- 伴侣对象可绕过关系识别，但仍需通过教师技能、`prevent_learn()`、技能 hook 与
  资源检查。

## 12. 要求 apprenticeship/family 的教师

- 所有普通 `F_MASTER` 师父天然支持嫡传学生；多数 `create_family()` 后保留
  `privs == -1`，也允许同门非嫡传按三倍规则学习。
- `daemon/class/fighter/champion.c` 与 `d/city/npc/chen.c` 在
  `create_family()` 后显式 `assign_apprentice(..., 0)`，因此同门非嫡传不会取得
  `privs == -1` 豁免；没有自定义 `recognize_apprentice()`，实际可依赖的稳定路径
  是先成为其嫡传弟子。
- 李火狮要求 family name 为封山剑派，但不要求 current master。
- 其他 master 的属性/任务/性别门槛控制招募关系的建立；例如骆云舟要求桃林
  mark、陈天星要求推荐信、於兰天武要求三招测试、绝尘子要求 spi 与
  combat_exp。这些应留在未来招募/剧情 policy，而不是复制到 Learn。

## 13. 应丢弃或替换的 LPC 运行时机制

| LPC 机制 | Godot 处理 |
| --- | --- |
| `this_player()`、命令字符串解析 | UI/交互层构造 typed request |
| `present(teacher, environment(me))` | World Runtime 解析交互目标；领域层接收稳定 teacher ID/context |
| `living()`、`is_character()` | typed context 中的可交互/清醒事实，不保留动态探测 |
| `all_inventory()` + 婚约名称解析 | 未来关系系统提供 `teacher_is_spouse`；Learn 不读库存 |
| `find_player()`、`userp()` | 单机领域显式关系与教师成本策略 |
| `query()/set()/add()` 路径 | 具体 typed state/transition |
| `SKILL_D()` 路径拼接、动态 `call_other` | 按稳定 skill ID 显式注册 policy/effect |
| `notify_fail()`、`printf()`、`tell_object()`、`message_vision()` | typed failure/completion/presentation events |
| `environment()`、同房间对象身份 | World 层可达性，不进入 LearnService |
| `heart_beat()` | Learn 是一次性事务；不需要调度器 |

## 14. 必需的稳定 ID

- `teacher_id`：唯一 authored 教师身份，不使用显示名、LPC `id` 别名或对象路径做
  运行时身份。保留 `legacy_source_path`、`legacy_primary_id` 仅作迁移元数据。
- `family_id`：稳定门派 ID，不以中文 `family_name` 比较；显示名独立。
- `skill_id`：直接复用现有 `StringName` 技能 ID/`SkillIds` 约定。
- `master_teacher_id`：学生 current master 的稳定 teacher ID。不要继续存
  `master_name`；generation 作为独立数值字段保留。
- 若保留伴侣教师豁免，关系状态也以 character/teacher stable ID 表达。

LPC 的 `set_name()` 把第一个别名写入 `query("id")`，而
`feature/apprentice.c` 又同时持久化 `master_id` 和显示 `master_name`。同库还存在
两份魏无极以及多份重复/复制师父对象，说明显示名、别名和文件路径都不能单独作为
新系统唯一身份。

## 15. LearnService 前最小 typed domain model

建议只增加以下窄模型：

```text
TeacherDefinition
  teacher_id
  family_id? / family_generation? / teaching_privilege
  authored base-intelligence / offer defaults (NPC only)
  authored_offers: TeachingOffer[]
  recognition_policy_id?
  prevention_policy_id?
  teacher_spirit_cost_policy
  legacy metadata

TeachingOffer
  skill_id
  teacher_raw_level snapshot

ApprenticeshipState / FamilyState
  family_id?
  generation?
  master_teacher_id?
  legacy_betrayer_count

TeachingContext
  teacher_id
  is_student_fighting
  teacher_is_available / teacher_is_awake
  teacher_base_intelligence
  teacher_current_spirit
  requested TeachingOffer snapshot (skill_id + current raw level)
  teacher_pays_spirit_cost
  teacher_is_spouse
  narrow typed recognition-policy input/result
  deterministic improvement roll

LearnService
  validates and mutates one transaction in LPC order
  returns LearnResult + SkillImprovementResult + authored effect result
```

`TeacherDefinition` 不应是完整 `NpcDefinition`，也不应拥有位置、AI、对话、动画或
scene 节点。`TeachingOffer` 是明确的教学投影；不能把整个教师
`CharacterSkillState` 作为可变共享对象暴露给 Learn。

静态 NPC 可由 `TeacherDefinition` 物化上述 context；玩家教师或未来会成长的 NPC
必须从其当前 typed state 生成快照，不能把可变 intelligence、sen 或 raw level
误存为共享 definition 状态。`teacher_id` 表示逻辑角色身份，不是 scene instance
或 Node ID。

技能侧建议增加按 skill ID 注册的 `SkillLearnPolicy`。policy 只读取所需 typed
snapshot；需要尚未实现的装备/道德/世界状态时明确延期，不建立通用 payload 或
dbase 替身。

## 16. 能否在完整 NPC/world 前实现 Learn

可以。World Runtime 只需先解析“当前可交互教师是谁”，把稳定 ID 和清醒/可用事实
传入。教师教学投影、关系判断、成本和技能进度都可在纯领域运行。视觉 NPC 的位置、
移动、AI、对话与 respawn 不影响公式或状态变更顺序。

## 17. 哪些部分必须先有更广泛的 Faction/Apprenticeship

完整门派系统不必先行。Learn 的硬依赖只是：family 相等、双方 generation、current
master identity、教师 `privs == -1` 与学生 `betrayer` 次数的只读状态。

以下不应阻塞代表性 Learn：招募握手、拜师剧情、叛师时技能减半、逐出、门派称号、
每日收徒名额、信物/任务、玩家收徒资格。它们属于后续 Faction/Apprenticeship
实现。为避免未来迁移，建议下一阶段先落一个最小关系 state，再实现 LearnService，
而不是用若干布尔参数永久替代关系语义。

## 18. 可直接复用的已关闭系统

- `CharacterProgressionState`：直接复用 `combat_experience`、`potential`、
  `potential_spent`（legacy `learned_points`）。
- `CharacterSkillState`：直接复用 raw 查询、零等级已定义状态和
  `improve_skill()`；不向其中加入教师 ID 或教学规则。
- `SkillDefinition`：复用 skill ID、martial/knowledge type 与 legacy metadata；
  不把所有 `valid_learn()` 条件硬塞进该类。
- `SkillImprovementResult`：直接传播等级变化结果。
- `SkillImprovementEffectRegistry`：在 `improve_skill()` 返回后应用已迁移的
  `skill_improved()` authored effect。
- Phase 1/2A 的 attributes、essence/spirit、internal resources：提供 Learn 成本与
  已能表达的 skill policy 输入。

尚缺的是 Learn 事务结果、教师教学投影、最小关系 state 与 skill learn policy。

## 19. 遗留缺陷、矛盾与不明确处

1. Learn 私有 `is_appr_of()` 与 `feature/apprentice.c::is_apprentice_of()` 不一致：
   前者检查 master ID + generation、不检查 master name；后者检查 master ID +
   master name、不检查 generation。随后 `F_MASTER::prevent_learn()` 使用后者，故同一
   学生可能先被视为嫡传，又在防止教学时被视为非嫡传。
2. Learn 动态调用 `recognize_apprentice()` 与 `prevent_learn()`，但多数 NPC 没有
   前者，非 `F_MASTER` 教师没有后者。原驱动对不存在 lfun 的返回/错误策略未由
   mudlib 明示；新系统不能依赖这种动态缺省，应显式注册“无额外 policy”。
3. 两个魏无极定义 `accept_learn()`，但 Learn 从不调用，属于不可达接口。
4. `env/no_teach` 全库只发现 Learn 的读取，没有发现设置者；保留为窄化可用状态前
   需确认是否来自运行时管理命令或缺失内容。
5. 初学时 `set_skill(skill, 0)` 早于 potential/no-teach/疲劳检查，造成失败也创建
   零级技能。未来若保留兼容行为，必须在结果和测试中明确，不能静默“修正”。
6. `gin_cost` 对双方 `int == 0` 没有保护；负 intelligence 会产生负成本，而
   `receive_damage()` 明确拒绝负伤害。这是 legacy error boundary，不应擅自发明
   最小 intelligence。
7. 随机上界同样没有非正值保护，异常的 intelligence/combat-exp 可能使
   `random()` 非法；`learned_points` 已在调用 random 前增加。
8. 教师技能判定 `if (!master_skill)` 只明确排除 0；负技能值随后通常在学生等级
   比较处拒绝，但异常负状态的行为不整洁。
9. 教师 sen 必须严格 `>` 阈值，学生 gin 也必须严格 `>` 成本；相等会分别导致
   教师疲劳或学生无进度。不能改成 `>=`。
10. NPC 教师需有足够 sen，却不支付 sen；玩家教师支付。新系统要保留这一区别，
    但用显式成本策略而不是“是否为玩家对象”。
11. `master_id` 来自首个 LPC 别名，`master_name` 来自可变显示名；复制教师文件、
    重名与改名都会破坏关系稳定性。
12. 婚约豁免通过库存对象名字解析和在线玩家查找完成，既耦合库存又耦合在线对象；
    游戏规则的真实语义只是“当前教师是伴侣”。
13. `daemon/class/dancer/master.c` 等多处把
    `apprentice_available` 初始化后误写为 `apprentice_availavble`，每日名额可能不
    会正确减少；这是招募缺陷，不属于 Learn 修复范围。
14. `d/green/npc/master.c` 的 `map_skill("spells",magic-array)` 缺少字符串引号，
    是代表性 authored NPC 源缺陷；不影响本分析的 Learn 架构结论。

这些兼容选择应在实际实现阶段逐项测试并在确需决策时写入 `DECISIONS.md`；本分析
阶段不替原作选择修复策略。

## 20. 是否必须先完成所有 authored 教师

不必。一个小而有代表性的集合即可证明架构，建议未来测试夹具为：

- 纯门派嫡传：`daemon/class/swordsman/master.c`（柳淳风）。
- 同门非嫡传 + `F_MASTER` 三倍限制：同一封山 family 下的柳淳风。
- family trainer：`d/snow/npc/fist_trainer.c`（李火狮）。
- mark/付费认可：`d/snow/npc/teacher.c`（魏无极）。
- mark/剧情信物认可：`u/cloud/npc/girl.c`（李师师）。
- `privs == 0`、基本要求嫡传：`d/city/npc/chen.c` 或
  `daemon/class/fighter/champion.c`。
- authored skill policy：让柳淳风教授 `fonxansword`，覆盖 max_force、映射与剑
  装备依赖；在装备阶段前应得到明确的“依赖尚不可用”结果。
- knowledge skill：魏无极教授 `literate`，证明 knowledge 不受 martial
  combat-exp 门槛。
- 玩家教师投影：不需要视觉 NPC，只测试 sen 阈值和支付策略。

所有教师以后均可由数据和注册 policy 扩展，无需“一 NPC 一 Learn 脚本”。

## 教师/师父结构分类

| 实际类别 | Learn 相关语义 | 代表源 |
| --- | --- | --- |
| 门派 master | family/generation/privs、技能表、`F_MASTER::prevent_learn()` | `daemon/class/swordsman/master.c`、`daemon/class/fighter/master.c`、`daemon/class/bonze/master.c` |
| 同门非嫡传师父 | `privs == -1` 免 recognize，但受教师等级严格高于学生三倍限制 | 同上配合 `std/char/master.c` |
| 嫡传倾向的 master | 显式把 privs 改为 0，同门不自动放行 | `daemon/class/fighter/champion.c`、`d/city/npc/chen.c` |
| family trainer | 自己不是 master，以 `recognize_apprentice()` 检查门派 | `d/snow/npc/fist_trainer.c` |
| mark/费用 teacher | 无 family，以持久 mark 认可学生；只提供少量技能 | `d/snow/npc/teacher.c`、`teacher1.c` |
| mark/故事 teacher | 由信物/人物条件设置 mark，再认可 | `u/cloud/npc/girl.c` |
| 任务/属性/性别/经验门槛的招募者 | 门槛决定能否建立关系，不是 Learn 每次校验 | `daemon/class/scholar/master.c`、`juechen/master.c`、`dancer/master.c`、`d/city/npc/chen.c`、`fighter/champion.c` |
| 玩家教师 | 与 NPC 同样提供技能和关系事实，但实际支付 sen | `cmds/std/learn.c` 的 `userp(ob)` 分支 |

没有发现独立的“教师按学生等级 authored 拒教”API；等级限制来自通用
`prevent_learn()`、教师技能上限和技能自己的 `valid_learn()`。也没有发现每次 Learn
直接消耗金钱的教师。NPC 的属性/任务 gate 应归类为招募或认可前置，不能误写成
LearnService 内的通用规则。

## 推荐的后续 phase 拆分

### Phase 3C1：最小关系状态与 Learn 核心

- 增加稳定 `FamilyId`/`TeacherId` 约定及最小 `FamilyState` /
  `ApprenticeshipState`。
- 增加不可变/防共享可变状态的 `TeacherDefinition`、`TeachingOffer` 与窄
  `TeachingContext`。
- 实现纯领域 `LearnService`、typed `LearnResult`、确定性随机输入。
- 精确覆盖通用顺序、成本、strict boundaries、零级技能副作用、potential、martial
  门槛、玩家/NPC 教师 sen 差异。
- 复用 `CharacterSkillState`、`SkillImprovementResult` 与 effect registry。
- 只用无需未来系统的代表教师/技能证明架构。

### Phase 3C2：Skill Learn Policy

- 按 skill ID 显式注册 `valid_learn()` policy。
- 先迁移只依赖已关闭属性、资源、技能与映射的 hook。
- 装备、道德/战斗或其他未建状态的 hook 明确延期，不能默认允许。

### 后续 Faction/Apprenticeship 与 authored teacher content

- 实现招募、叛师、逐出、称号、privilege 赋值、任务/mark 来源。
- 批量迁移各教师定义与 authored recognition/recruitment policy。
- World Runtime 只负责 NPC 位置、可交互性与把 teacher ID 交给核心。
- Presentation 消费 LearnResult，不持有权威进度。

推荐的下一实现阶段是 **Phase 3C1：最小关系状态与 Learn 核心**。它能先锁定
`learn.c` 最容易出错的状态变更顺序与边界，同时不迫使项目提前建立完整 NPC、库存、
门派剧情或世界运行时。
