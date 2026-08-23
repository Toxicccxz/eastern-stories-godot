# Phase 4A3：Character Gender Usage Analysis

## 范围与结论

本阶段只分析 `reference/es2/mudlib/` 的 gender 语义，没有实现 native 字段、策略、
创建流程、NPC、装备、门派、婚姻或世界事件。权威源码给出的最小模型是一个**开放值域、
通常在初始化后保持稳定的持久标量**，不是 base/current/effective 身份系统。

建议下一阶段直接在 `CharacterState` 上增加一个开放 `StringName` gender fact。当前证据
不足以证明需要独立 `CharacterIdentityState`，更不支持 base/effective 双层。正常 native
角色应由对应的创建/导入策略显式解析 gender；通用 `CharacterState` 不应擅自采用人类
男性默认值。

## 全库搜索方法与精确计数

对全部 `*.c`、`*.h` 执行了以下结构性搜索，并直接阅读所有 `query("gender")` 命中：

- `query("gender")`、`set("gender")`、`add/delete("gender")`；
- `query_temp/set_temp/add_temp/delete_temp` 与 `apply/*gender*`；
- `query_gender`、`set_gender` 以及裸 `gender`；
- `男性`、`女性`、`无性`，以及扫描发现的 `雄性`、`雌性`、`中性神`；
- 邻接身份概念：`age`、`race`、`species`、`body/body_type`、`eunuch`、
  `disguise`、`yirong`、`transformation/polymorph`、婚姻、family/recruit、
  title、class/master recognition。

精确结果：

| 项目 | 数量 | 说明 |
|---|---:|---|
| `query("gender")` 调用 | 61 | 分布在 59 个源码行；`u/cloud/npc/mei_po.c:78` 与 `cmds/std/look.c:119` 各在一行调用两次 |
| `set("gender", ...)` 调用 | 254 | 包括玩家、NPC、race master default 与 corpse copy |
| race daemon 直接 mapping 写入 | 2 | `monster.c`、`beast.c` 的 `my["gender"] = "雄性"` |
| gender 写入点合计 | 256 | 254 + 2 |
| gender 读写调用/写入点合计 | 317 | 61 + 256 |

61 次读取进一步分为：35 次 gameplay/lifecycle 读取、22 次纯展示读取、1 次 inactive
旧技能副本读取，以及 3 次整段注释中的读取。统计没有把仅包含称谓的普通中文文本算成
gender 规则。

直接写入的 string literal 出现次数为 `男性` 169、`女性` 77、`雄性` 3、`雌性`
6。两条分支可以位于同一次写入中，所以 literal 次数不是写入调用数：
`d/green/npc/kid4.c` 的一次 `set` 同时含 `男性` 与 `女性` 两个候选值。另一个非固定值
写入是 `adm/daemons/chard.c` 将死者当前查询结果复制给 corpse。

## 17 个权威源码问题

1. **玩家在哪里初始化？** `adm/daemons/logind.c::get_email()` 创建 `USER_OB` 后，
   `get_gender()` 强制玩家输入 `m/M` 或 `f/F`，分别直接写入 `男性` 或 `女性`；空输入和
   其他输入只会重新询问。随后才调用 `init_new_player()`、`enter_world()`、
   `user->setup()` 与 `user->save()`。
2. **NPC 在哪里 authored？** 大多数 NPC 的 `create()` 直接
   `set("gender", ...)`。结构扫描发现 307 个直接 `inherit NPC;` 文件，其中 245 个
   文件显式 set gender。该比例不含通过 `F_MASTER` 等间接继承 NPC 的对象。
3. **是否为 dbase 持久 string？** 通常是。`feature/dbase.c` 的非 static `dbase`
   mapping 保存该标量；玩家的 `obj/user.c` 继承 `feature/save.c`，`save_object()` 自动
   序列化它。`tmp_dbase` 是 static，但 gender 从未存入其中。
4. **active source/content 的精确值？** 实际被赋给角色/NPC/race default 的值只有
   `男性`、`女性`、`雄性`、`雌性`。`中性神` 只出现在 pronoun helper 的兼容分支，未
   找到 active writer/content；未找到 `无性`。
5. **框架是否限制值域？** 否。`feature/dbase.c::set()` 接受任意 mixed value，限制仅是
   authored convention；没有 gender validator、getter/setter 或 enum。
6. **能否缺失？** 能。任意尚未 setup 的对象可没有 key；不少直接 NPC 文件未显式写。
7. **缺失在运行时意味着什么？** `query()` 在没有值时返回 `0`。已完成 human setup 的
   对象通过 `default_ob` 读取 `human.c` master copy 的 `男性`，但仍可能没有自己的
   dbase key；monster/beast setup 则在自己的 dbase 中补写 `雄性`。任何尚未完成相应
   setup 的缺值对象仍读到 `0`。
8. **创建后能否改变？** 通用 dbase API 技术上允许再次写入或删除；但全库没有正常玩家
   创建后的 gender mutator。固定值 NPC 与创建时随机 NPC 在 setup 后保持稳定。
9. **是否有 command/skill/item/quest/spell/transformation/disguise/admin mutation？**
   没有找到 gender 专用 mutation。`daemon/class/nomad/yirong/yirong.c` 只改变 `id`、
   `name` 与 `yirong`；不读写 gender。`cmds/usr/set.c` 只能写 `env/*`，没有开放任意
   character property。巫师若通过通用代码执行能力直接调用 `set` 理论上仍可破坏值，
   但源码中没有 gender 管理命令。
10. **是否区分 biological/base/displayed/temporary/transformed gender？** 否。所有规则
    与展示都读同一个 `query("gender")`。
11. **是否存在 gender 的 query_temp/apply？** 不存在。
12. **规则用精确 string 还是 helper？** gameplay 规则全部直接比较 string；
    `gender_pronoun()`/`gender_self()` 仅供展示。
13. **比较是否大小写敏感且精确？** 是，使用 LPC `==`/`!=` 的精确 string equality；
    没有规范化。
14. **是否参与算术或排序？** 否，只用于相等/不等分支与展示选择。
15. **是否有实际 active 第三/中性值？** 人类没有。非人类有独立的 `雄性`、`雌性`；
    `中性神` 没有 writer/content，`无性` 不存在。
16. **是否可能出现 malformed/custom string？** 可以，因 dbase 无限制。多数规则会把它
    当作“不等于要求值”；pronoun helper 会落入 `它`。这与 normal authored domain
    只有四个值必须分开看。
17. **是否自动参与 save/load？** 是。玩家 gender 位于普通 `dbase`，而 `obj/user.c` →
    `F_SAVE` → `save_object/restore_object` 保存/恢复整个非 static state，无专用处理。

## 存储、默认与生命周期

### 玩家创建与持久化链

```text
adm/daemons/logind.c::get_email
  -> make_body(USER_OB)
  -> get_gender: explicit 男性/女性
  -> init_new_player
  -> enter_world
  -> obj/user.c::setup
  -> std/char.c::setup
  -> adm/daemons/chard.c::setup_char
  -> obj/user.c::save -> feature/save.c::save_object
```

有效创建流程没有“未选择时默认男性”：空值/非法值只会重试。`human.c` master copy 的
男性 fallback 是 race setup 的查询默认，不是 login choice 的替代。恢复旧玩家时，
`make_body()` 后 `restore()` 先还原 dbase，再进入 `setup()`。

`adm/daemons/chard.c::make_corpse()` 将 victim 的已解析 gender 查询结果写到 corpse，
因此 corpse 拥有独立 persistent scalar；它不建立角色 gender 的变更关系。

### NPC authored 行为

- 显式标量非常常见：245/307 个直接 NPC 文件写 gender；间接 NPC 另有显式写入。
- `adm/daemons/race/human.c` 通过 `set_default_object()` 给缺值 human 提供查询 fallback
  `男性`，不补写对象自己的 key。
- `adm/daemons/race/monster.c` 与 `race/beast.c` 对缺值对象直接补写 `雄性`。
- `d/city/npc/walker.c`、`d/choyin/npc/visitor.c`、`d/snow/npc/traveller.c` 与
  `trav_blade.c` 在 `create()` 中随机选一次标量，之后稳定。
- `d/green/npc/kid4.c` 是唯一特殊形状：dbase 中保存 function closure；由于
  `feature/dbase.c::query()` 会 `evaluate()` function，每次读取都可能重新得到男性或
  女性。这不是 `query_temp`、apply、base/effective 或 transformation，属于 authored
  动态值异常。未来迁移该 NPC 时应单独决定是否改为 spawn-time 随机并记录行为差异，
  不能由此为所有角色建立 effective gender。

玩家与 NPC 最终都通过同一个 `query("gender")` 表示和消费；差异只在赋值/default
策略，而不是字段类型。

### 可变性与 base/effective 结论

从正常角色规则看，gender 是“构造/authoring 后稳定”的身份标量：玩家只在创建时写入，
固定或 create-time 随机 NPC 之后也不再修改。它在 LPC 类型层面并非 immutable，因为
通用 `set/delete` 没有封装限制；`kid4` 还证明 dbase 技术上可保存动态 function value。
这两个运行时漏洞/特例都不构成通用 gameplay mutation API。源码没有 base、displayed、
current、effective 或 temporary gender 的任何成对状态。

## Gameplay consumer 完整表

下表覆盖 35 次 gameplay/lifecycle `query("gender")`。除特别说明外，全部读取普通
`dbase/default_ob` 解析结果（P），没有一项读取 temp/apply。当前迁移可达性中的“阻断”
表示 policy 已注册但因缺事实而返回 typed dependency failure；其余系统尚未迁移。

| 类别 | 源码与位置 | 精确读取/期望 | 不满足时的效果 | 顺序（影响短路/副作用） | 当前迁移可达性 |
|---|---|---|---|---|---|
| A | `daemon/skill/stormdance.c::valid_learn` | P；`gender == 女性` | 拒绝学习 | **第 1 项**，之后才检查 base `spi >= 20` | 已注册，gender 阻断 |
| A | `daemon/skill/tenderzhi.c::valid_learn` | P；`gender == 女性` | 拒绝学习 | **第 1 项**，之后才检查 primary 与 secondary weapon 都为空 | 已注册，gender 阻断 |
| A | `daemon/skill/nine-moon.c::valid_learn` | P；`gender == 女性` | 拒绝学习 | **第 1 项**；之后依次 `max_force >= 50`、mapped force 精确为 `nine-moon-force`、主武器为 sword | 已注册，仍以缺失 legacy skill 阻断 |
| B | `daemon/class/bonze/master.c::ask_for_join` | P；`gender == 男性` | 不设置 `pending/join_bonze` | 先拒绝已经是 `class == bonze`，再检查 gender | 未迁移 |
| B | `daemon/class/bonze/master.c::do_recruit` | P；`gender == 男性` | 只说拒绝文本，不执行 recruit | gender 第 1，随后才要求 `class == bonze` | 未迁移 |
| B | `daemon/class/dancer/master.c::do_recruit` | P；`gender == 女性` | 不执行 recruit | gender 第 1；通过后 `per/age` 只改变附加文本，不是 admission gate | 未迁移 |
| B | `daemon/class/taoist/taolord.c::do_recruit` | P；`gender == 男性` | 不执行 recruit | gender 是唯一 admission 条件 | 未迁移 |
| B | `d/latemoon/room/npc/elon.c::do_accept` | P；`gender == 女性` | 返回且不开始测试 | gender 第 1，之后才检查 `combat_exp` 并执行三次 combat attack | 未迁移；依赖 NPC/combat/world |
| B | `d/latemoon/room/npc/elon.c::attempt_apprentice` | P；`gender == 女性` | 不 recruit | 先 `combat_exp >= 100000`，再 gender，再检查 title/叛师分支 | 未迁移 |
| D | `cmds/std/wear.c::do_wear` | P；仅当 item `female_only` 时要求 `女性` | 在调用 item `wear()` 前拒绝 | 先读 item flag，short-circuit 后读 gender，再执行 wear | 未迁移；Phase 4A1 只有武器手位 |
| D | `d/latemoon/obj/skirt.c`、`d/latemoon/obj/skirt4.c`、`d/latemoon/obj/skirt5.c`、`d/latemoon/npc/obj/skirt.c`、`d/latemoon/npc/obj/skirt4.c`、`d/latemoon/npc/obj/skirt5.c` 的 `wear()` | P；`gender == 女性`（共 6 次读取） | 不调用父类 wear | gender 在父类 wear 前 | 未迁移 |
| E | `d/latemoon/latemoon8.c::do_dancing` | P；分别精确匹配 `男性`、`女性`（2 次） | 其他/缺失值绕过两套 sen 门槛和首次消耗 | **先**按男性 `sen >=100`/damage 50 或女性 `sen >=50`/damage 30，**后**验证 arg；`yu-fong` 后续另 damage 50 并移动 | 未迁移 |
| E | `d/latemoon/miroom.c::do_dancing` | P；分别精确匹配 `男性`、`女性`（2 次） | 其他/缺失值绕过两套 sen 门槛和消耗 | **先**男性 `sen >=100`/damage 80 或女性 `sen >=50`/damage 50，**后**验证 `arg == out` 并移动 | 未迁移 |
| E | `d/latemoon/room/bathroom.c::do_takebath` | P；`gender == 女性` | 非女性施加 `rose_poison=15`；女性反而 damage gin 10、heal sen `random(5)+5` | 先验证 `arg == bath`，再 gender 分支 | 未迁移；依赖 condition/random/world action |
| E | `d/latemoon/room/bathroom1.c::valid_leave` | P；`gender == 女性` | 非女性施加 `rose_poison=5`，仍允许离开 | gender effect 在 `return 1` 前 | 未迁移 |
| F | `u/cloud/npc/girl.c::receive_object` | P；取得 mark 实际要求 `gender != 女性` 且 `per >=25` | 女性、低 per 或有价值物品均不设置 `marks/李师师` | 先 item value；复合式先检查 `per <25`，再 gender；成功后设置 mark | 未迁移；该 mark 是已分析 Learn recognition 的前置来源 |
| F | `d/latemoon/npc/fuyun.c::greeting` | P；精确 `gender == 男性` | 非男性无 gender 效果 | 男性触发双方 combat relation | 未迁移；NPC/combat/world |
| F | `d/latemoon/npc/shinyu.c::greeting` | P；精确 `gender == 男性` | 非男性只关闭门 | 男性依次 damage gin 50、kee 100、sen 50，并移动出房间 | 未迁移；NPC/world |
| F | `d/latemoon/room/npc/fireangel.c::greeting` | P；精确 `gender == 男性` | 非男性无 gender 效果 | 男性触发双方 combat relation | 未迁移；NPC/combat/world |
| F | `d/latemoon/room/npc/tenlon.c::greeting` | P；精确 `gender == 男性` | 非男性无 gender 效果 | 男性触发双方 combat relation | 未迁移；NPC/combat/world |
| F | `d/latemoon/room/npc/shinyu.c::greeting` | P；精确 `gender == 男性` | 非男性只关闭门 | 男性先关门、施加 `rose_poison=10`，再 damage gin 50/kee 100/sen 50 并移动 | 未迁移；NPC/condition/world |
| F | `d/latemoon/room/npc/shaoin.c::greeting` | P；精确 `gender == 男性` | 非男性只关闭门 | 男性 damage sen 20、施加 poison 2、NPC force +50、关门 | 未迁移；NPC/condition/world |
| F | `d/latemoon/room/npc/yuchoun.c::greeting` | P；精确 `gender == 男性` | 非男性只关闭门 | 男性 damage sen 10、NPC force +50、关门 | 未迁移；NPC/world |
| G | `u/cloud/npc/mei_po.c::do_marry` | P；比较双方 gender **相等**（2 次读取） | 相等则拒绝；不相等才继续 | 先对象/婚姻状态/living/年龄，再 gender equality，再拒绝 self | 未迁移；custom/malformed 的不同字符串也可通过 |
| G | `d/snow/npc/proposer.c::ask_for_employment` | P；发起者 `gender == 男性` | 不开始提亲流程 | 先 `can_speak`、再 `class != bonze`、再 gender、再已有 spouse/custom | 未迁移 |
| G | `d/snow/npc/proposer.c::do_propose` | P；目标 `gender == 女性` | 与目标缺失、非 user、不能说话一起走“找不到姑娘”分支 | 先解析命令与目标，再在复合条件末尾检查 gender | 未迁移 |
| I | `adm/daemons/chard.c::make_corpse` | P；复制 victim 当前已解析值 | 无 mismatch；写入 corpse 普通 dbase | long 中先另读一次作 pronoun（展示），随后复制 gender，再复制其他 corpse state | 未迁移；属 corpse lifecycle |

### 没有 gameplay consumer 的类别

- **C（perform/cast/exert/skill action）**：未发现 active gender rule；三个技能命中都是
  `valid_learn()`。
- **H（combat formula）**：未发现命中率、伤害、闪避、奖励等中心 combat formula 读取
  gender。晚月 NPC 因 gender 发起战斗或伤害属于 NPC interaction（F），不是 combat
  数值公式。

## Pure presentation 使用摘要

22 次纯展示读取不会改变准入或游戏状态：

- `adm/daemons/rankd.c`：5 次，选择称谓；
- `adm/simul_efun/message.c`：2 次，消息代词；
- `adm/daemons/emoted.c`：2 次，emote 代词；
- `adm/daemons/chard.c`：1 次，corpse long 的代词（同函数另一次复制属于 I）；
- `cmds/usr/score.c`：1 次，显示原始 gender；
- `obj/corpse.c`：1 次，corpse 描述；
- `cmds/std/look.c`：4 次调用，代词、女性外貌描述和同门称谓；
- `d/choyin/npc/judgeman.c`：1 次，通缉文本代词；
- `d/snow/npc/girl.c`：1 次，只选择拒绝比武的台词；两支都返回拒绝；
- `u/cloud/npc/mei_po.c`：1 次，解除婚约时选择称谓；
- `obj/marry_card.c`：3 次，婚书/配偶称谓。

`adm/simul_efun/gender.c::gender_pronoun()` 映射 `男性`、`中性神` 为“他”，`女性` 为
“她”，`雄性`/`雌性` 及 missing/custom default 为“它”。`gender_self()` 的女性分支与
default 都返回“你”。这些 helper 不应进入 gameplay identity state；未来 presentation
层可以独立处理。

## K：legacy defect、歧义与不可达代码

- `daemon/class/lama/master.c` 中两个 gender 读取位于完整的 `/* ... */` 注释块，不能
  当作 active recruitment rule。
- `d/latemoon/entrance.c` 的女性读取位于注释块，不能当作 active room gate。
- `d/skill/stormdance.c` 是旧路径的重复实现；active `SKILL_D` 路径使用
  `daemon/skill/stormdance.c`。两份 gender/spi 顺序一致，但迁移只以 active daemon 为准。
- `d/green/npc/kid4.c` 的 function-valued gender 会随每次 query 重新随机，是唯一观察到
  的动态异常；没有证据表明这是通用身份机制。
- `gender_pronoun()` 接受 `中性神`，但全库没有对应 writer/content；它是未证实可达值。
- human 缺 key 时通过 default object 得到 `男性`，monster/beast 却补写自己的 `雄性`；
  save 中“显式男性”和“human fallback 男性”可有不同底层形状，但规则查询结果相同。
- exact comparison 导致 `雄性` 并不等于 `男性`：雄性动物不会触发只匹配男性的晚月
  规则；missing/custom 也常绕过 `== 男性` 与 `== 女性` 的两个分支。
- `!= 女性` 规则会把男性、雄性、雌性、missing、custom 全部归到同一支；这包括浴室
  poison 与 female-only item 拒绝。不得擅自改成二值 enum 后反转判断。
- 婚姻用“两值不相等”而不是明确“男性+女性”，所以两个不同 custom 值也可能通过。
- `daemon/class/nomad/yirong/yirong.c` 改写 persistent `id/name`，却在移除时
  `delete_temp("yirong")` 而先前写的是 persistent `set("yirong", 1)`；这是相邻 disguise
  实现自己的可疑点，不涉及 gender，也不应在本阶段修复。
- 一些 gender gate 的内容与现代产品设计可能不合适，但只要代码确定，就属于 source
  semantics 而不是软件 defect。是否保留、改写或移除属于未来产品决定，必须另行记录。

## Stormdance、Tenderzhi、Nine-moon

### `stormdance`

`daemon/skill/stormdance.c::valid_learn()` 的精确顺序是：

1. persistent/resolved gender 必须精确等于 `女性`；
2. base dbase `spi` 必须 `>= 20`；
3. 成功。

Phase 1 已提供 base spirituality，因此最小 gender fact 足以让该 hook 完整执行。

### `tenderzhi`

`daemon/skill/tenderzhi.c::valid_learn()` 的精确顺序是：

1. gender 必须精确等于 `女性`；
2. legacy `weapon` 与 `secondary_weapon` 两个 temp 引用都必须为空；
3. 成功。

Phase 4A1/4A2 已提供并接线精确的双手引用事实，因此最小 gender fact 足以让该 hook
完整执行；不得先返回装备失败而跳过原始第一项。

### `nine-moon`

`daemon/skill/nine-moon.c::valid_learn()` 的精确顺序是：

1. gender 精确等于 `女性`；
2. `max_force >= 50`；
3. mapped `force` 精确等于 `nine-moon-force`；
4. primary weapon 存在且 `skill_type == sword`；
5. 成功。

gender、internal resource、mapped skill 和 primary sword facts 均可表达，但全 mudlib
仍没有 active `daemon/skill/nine-moon-force.c` 权威实现。增加 gender 只能解除第一项，
不能让 `nine-moon` 成为可执行 policy，也不能修复该缺失技能。

## Native architecture 方案比较

### Option A：`CharacterState.gender`（推荐）

优点是最小、直接表达单一持久事实，consumer 只做精确相等判断；也符合现有
`CharacterState` 作为 typed character domain composition root 的结构。gender 自身没有
方法、状态转换、临时 modifier 或生命周期行为，单独对象目前不能承载额外已证实语义。

建议约束：

- typed `StringName`，默认空值表示“尚未由创建/import/race policy 解析”；
- 定义四个 canonical authored 常量，但不要拒绝 custom legacy value；
- 不在 `CharacterState` 内设 universal `男性` default；player creation 与 human NPC
  fallback 的来源不同，应由未来 factory/importer 处理；
- gameplay policy 只读取该 fact；identity 不依赖 Learn、Equipment、NPC、UI、World 或
  faction service；
- pronoun、称谓、文案映射留在 presentation。

### Option B：`CharacterIdentityState.gender`（当前不推荐）

它能给未来 identity 字段留命名空间，但现有证据没有显示多个即将迁移且共享同一生命周期
的字段：`age` 随在线时间变化，`class/family/title` 随门派流程变化，`name/id` 可被 yirong
影响，`race` 又参与独立的派生值/setup policy。现在为了一个无行为 scalar 新建 state
只增加组合层。若未来先完成 race/character creation/import 的联合审计并证明多个稳定字段
确实共同构造、保存和克隆，再做小范围提取仍来得及。

### Option C：`base_gender + current/effective_gender`（拒绝）

无 source evidence：没有 temp/apply gender、没有变性/变身/disguise gender、没有恢复到
base gender 的流程。`kid4` 的 function-valued anomaly 不能推广成所有角色的双层状态。

不要建立 broader Profile：账号/email/password、显示名、pronoun、title、family 与 gameplay
gender 的职责和生命周期不同。

## 推荐值表示

推荐开放 `StringName`，而不是 enum 或 Dictionary/value-object：

- canonical normal authored domain：`&"男性"`、`&"女性"`、`&"雄性"`、`&"雌性"`；
- absent：`&""`，保留“尚未解析/旧存档缺 key”的事实；
- custom/corrupted legacy：保留原字符串，不静默 normalize；
- `中性神` 可由未来 presentation/import compatibility 层识别，但在找到真实 authored
  state 前不列为 canonical gameplay value。

开放 `StringName` 可忠实保留 exact equality、动物值和异常旧档，同时仍比通用 Dictionary
严格。一个 enum 会强迫 missing/custom 归入某个正常值，并改变 `!= 女性`、双分支 bypass
及婚姻 unequal comparison 的结果。

## Migration impact 与 future NPC implication

增加最小 gender fact 后立即可解除：

- `stormdance`：完全可执行；
- `tenderzhi`：完全可执行；
- `nine-moon`：只能表达并验证第一项，整体仍因 `nine-moon-force` 缺失而阻断。

因此 45 个 active `valid_learn()` override 可从 Phase 4A2 的 **42 executable + 2 gender
blocked + 1 legacy defect blocked** 变为 **44 executable + 1 legacy defect blocked**。
`LearnService` 无需依赖 identity，也无需改变既有顺序；应由两个窄 gender equality policy
与 `OrderedSkillLearnPolicy` 组合 stormdance/tenderzhi。

近后续还会复用同一 fact 的系统包括：female-only armor/wear、门派/拜师 admission、
李师师 mark acquisition、婚姻关系、晚月 NPC/room scripted interactions 和 corpse metadata。
它们都未因本分析获得实现授权。

未来 `NpcDefinition` 应允许显式 authored gender，并由 race-aware spawn/factory policy 处理
缺值 default。不要把 gender 仅当 description 文本，也不要把 `kid4` 的 function closure
存入定义；该单例需要独立、可测试的 authored spawn rule 或明确的迁移决策。

## 精确下一实现阶段

建议 **Phase 4A4：Minimal Character Gender Fact and Learn Policy Integration**，范围严格为：

1. 在纯 domain `CharacterState` 上增加开放 `StringName gender` 与四个 canonical constants；
2. 默认保留 absent，不实现 player/NPC/race factory、UI、presentation 或 save service；
3. 增加一个窄的 exact-gender Learn policy primitive；
4. 按 LPC 顺序接线 `stormdance` 与 `tenderzhi`；
5. `nine-moon` 继续显式以 missing legacy skill 阻断；
6. 测试 female/exact mismatch、animal/missing/custom、短路顺序、独立角色状态，以及 registry
   45/44/0/1 分类。

## 直接检查的权威 LPC 文件

核心存储、创建、继承与持久化：

- `feature/dbase.c`、`feature/save.c`
- `std/char.c`、`std/char/npc.c`、`obj/user.c`
- `adm/daemons/logind.c`、`adm/daemons/chard.c`
- `adm/daemons/race/human.c`、`race/monster.c`、`race/beast.c`
- `adm/simul_efun/gender.c`

技能、门派与学习邻接：

- `daemon/skill/stormdance.c`、`tenderzhi.c`、`nine-moon.c`
- `d/skill/stormdance.c`
- `daemon/class/bonze/master.c`、`dancer/master.c`、`taoist/taolord.c`、
  `lama/master.c`
- `d/latemoon/room/npc/elon.c`
- `u/cloud/npc/girl.c`

装备、关系、世界与 NPC consumer：

- `cmds/std/wear.c`
- `d/latemoon/obj/skirt.c`、`skirt4.c`、`skirt5.c` 及
  `d/latemoon/npc/obj/` 对应三文件
- 全部 33 个 `female_only` authored item 定义（由全库 property scan 覆盖）
- `u/cloud/npc/mei_po.c`、`obj/marry_card.c`、`d/snow/npc/proposer.c`
- `d/latemoon/latemoon8.c`、`miroom.c`、`room/bathroom.c`、`room/bathroom1.c`
- `d/latemoon/npc/fuyun.c`、`npc/shinyu.c`
- `d/latemoon/room/npc/fireangel.c`、`tenlon.c`、`shinyu.c`、`shaoin.c`、
  `yuchoun.c`
- `d/snow/npc/girl.c`、`d/choyin/npc/judgeman.c`

展示、动态/default 与相邻身份：

- `adm/daemons/rankd.c`、`adm/daemons/emoted.c`、`adm/simul_efun/message.c`
- `cmds/std/look.c`、`cmds/usr/score.c`、`obj/corpse.c`
- `d/green/npc/kid4.c`、`d/city/npc/walker.c`、`d/choyin/npc/visitor.c`、
  `d/snow/npc/traveller.c`、`trav_blade.c`
- `daemon/class/nomad/yirong/yirong.c`、`cmds/usr/set.c`
- 注释命中 `d/latemoon/entrance.c`

此外对全部 mudlib `*.c/*.h` 执行了上述 gender/value 与邻接身份模式扫描；生产结论只使用
直接读取过的命中和其直接依赖，没有从文件名推断规则。
