# S0 — ES2 Start-of-Game / Snow Town Source Rebaseline

## EXECUTIVE CONCLUSION

**Does ES2 start in Old Pine? No.** 普通全新账号的默认起点是雪亭镇**饮风客栈**
`/d/snow/inn`，不是老松林。老松林是可从镇上步行进入的邻接野外；接近出生点不等于
“官方新手副本”。依据：`include/login.h`、`adm/daemons/logind.c::enter_world()`、
`d/snow/inn.c`、`d/snow/eroad3.c`、`d/oldpine/npath1.c`。

S0 source analysis/self-review **PASS**；整个 Start-of-Game milestone 仍为
**ANALYSIS IN PROGRESS / NOT IMPLEMENTED — AWAIT OWNER REVIEW**。只提出后续范围，不授权实施。
本文 LPC 相对路径均以 `reference/es2/mudlib/` 为根；“未发现”限定于注明的搜索/调用链，
不是证明整个游戏不存在该能力。本文是静态源码分析，没有运行 LPC server，也不声称遗留
编译器、调度器或缺失函数行为已实测。

### Baseline / unblock

- 分支：`phase/start-of-game-source-rebaseline`，无 PR，不合并。
- 原提示的 Beast 集成点：`a7f0f6fa695a53335878570b80df354a97a48233`，PR #12；
  final PR HEAD `0ab0d68c44ba9844d477eed4c1ed0670707bf9a9`；
  [main workflow 34515556524](https://github.com/Toxicccxz/eastern-stories-godot/actions/runs/34515556524)
  四项 PASS，Beast **FULLY INTEGRATED**。
- 实际 S0 起点是更新后的绿色 main **`208597ea0cbb564cb3822f4003f76bafc8bafa4a`**。
  其间 owner 推送 Godot AI 4.0.4 (`62d2bd5`)，viewport 配置漂移使 CI 阻塞；经独立
  [PR #13](https://github.com/Toxicccxz/eastern-stories-godot/pull/13) 恢复两项 viewport 配置并获授权合并。
  [main workflow 34525138568](https://github.com/Toxicccxz/eastern-stories-godot/actions/runs/34525138568)
  Godot Verify / Windows Release Build / Android Release Build / iOS Build Validation 四项 PASS。
  S0 不重复、回退或携带该修复为自身代码变更，保留当前插件和本机调试配置。

## NEW PLAYER CALL CHAIN

普通新账号、非 reconnect、非 silent、没有旧 player save 的同步路径：

1. `adm/obj/master.c::connect()` 创建 `LOGIN_OB`；`obj/login.c::logon()` 接入
   `LOGIN_D->logon()`。账号连接、密码、权限、telnet 和超时属于旧运行环境，不是待移植 RPG 系统。
2. `adm/daemons/logind.c`：WELCOME → `get_id` / 新账号确认 → `get_name` → 密码及确认 →
   `get_email`。账号 ID 小写化，显示中文名独立；已有账号走 restore/password 路径，不是 fresh。
3. `get_email` 设 `body=USER_OB` 后 `make_body()`，创建 `obj/user.c`，再询问性别。
   `make_body()` 设置 ID 与 `set_name(name, ({id}))`；`feature/name.c` 将主 alias/ID 与显示名分开。
4. `get_gender` 选择男性/女性 → `init_new_player`：title、birthday、potential、八属性、gift_tag、
   food/water、chat channel；此时还没有 `user.setup()`。
5. `enter_world`：连接引用 / exec → **`user.setup()`**。
   `obj/user.c::setup()` 先 `update_age()`，再 `std/char.c::setup()`，最后 `restore_autoload()`。
   Character setup → `CHAR_D->setup_char()` → `adm/daemons/race/human.c::setup_human()` →补 current/effective，
   capacity / reset_action；fresh autoload 数组未初始化，不创建额外物品。
6. **先 `user.save()`，再 login object `save()`**。这是穿衣、gift 随机化、入房之前的存档。
7. `gift_tag && age>=15` 才随机化并删除 tag（fresh 14 岁不执行）；随后无条件创建
   `/obj/cloth` → `move(user)` → `wear()`，后两者返回值未检查。
8. 非 silent 分支输出 MOTD / 邮件提示，选择 ghost / saved startroom / START_ROOM →
   load destination → move；仅 load 抛错时 fallback inn 并设置 startroom，move 失败没有同等处理。
9. 系统频道消息 → `UPDATE_D->check_user(user)`；它清理/迁移已有旧技能，补齐和限制资源，
   没有新手经验或物品赠送。之后 heartbeat、NPC chat、玩家操作会改变状态。

`obj/user.c` 继承 CHARACTER + F_AUTOLOAD + F_SAVE；CHARACTER 的属性、资源、技能、移动等 feature
是组合来源，不是多套初始化。下面表格描述**首次同步 enter_world 完成、尚未玩家操作的状态**，
不把未来 tick、其他玩家投放或掉落的物品算作开局赠礼。

## FRESH PLAYER INITIAL STATE

| 状态 | 源码结果 | 来源/限定 |
| --- | --- | --- |
| ID / name | 用户输入的账号 ID / 中文显示名 | logind `make_body`；不是预设剧情人物 |
| title / gender | 普通百姓 / 所选男性或女性 | logind initialization |
| race / unit / speech | 人类 / 位 / can_speak=1 | chard 默认 race；human default object |
| age / birthday | 14 / 创建时 `time()` | user `update_age`；birthday 不是 age 的计算输入 |
| str/cps/int/cor/con/spi/per/kar | **全部 30** | logind 主动赋值；human 只补 undefined，不覆盖 |
| gift_tag | 1，尚未消费 | age14 未达随机化门槛 |
| potential / learned_points | 99 / 查询为0（未赋值） | logind / dbase 缺失键 |
| combat_exp / score / bellicosity | 查询为0（未赋值） | 初始化及 human 默认无这些赋值 |
| skills / learned / skill_map | 未建立 mapping；raw query=0 | feature/skill，无初始技能写入 |
| family / master / class | 未赋值，无入门派 | 不能从“普通百姓”推断已拜师 |
| gin, eff_gin, max_gin | **100,100,100** | human age<=14；chard 填补 current/effective |
| kee, eff_kee, max_kee | **100,100,100** | 同上 |
| sen, eff_sen, max_sen | **100,100,100** | human age<=30 |
| force/max_force, mana/max_mana, atman/max_atman | 查询均0（未赋值） | 无技能、内功或内部资源赠送 |
| body weight | **80000** | human `40000+(str-10)*2000`；物品重量不在此值内 |
| maximum encumbrance | **150000** | chard `str*5000`，尚无已有 capacity |
| food / water | **0 / 0**，setup 后容量各 **400** | 见下面的初始化顺序证明 |
| direct inventory / encumbrance | 布衣1件 / 3000 | logind + obj/cloth；无初始钱、书、武器 |
| clothing / hands | cloth 槽已穿布衣，armor+1；双手空 | feature/equip；无第二装备 |
| conditions / enemy / ghost | 无已施加 condition / 空敌人 / ghost=0 | 初始 feature 状态；非死亡恢复 |

食物/水的**确定顺序**：`feature/move.c` 的 `static int weight=0` → `obj/user.create()`
及 `std/char.create()` 不设体重 → `init_new_player` 调 `max_*_capacity()` = `query_weight()/200` = 0
并写入 food/water → 后续 human setup 才设 weight80000 → 容量变400，**未补满 food/water**。
`updated.c` 也未补给。不能把作者使用 max_capacity 的意图误写成实际400/400。

`feature/damage.c::heal_up()` 先减正 water/food；user water<1 则在 gin/kee/sen 恢复之前返回，
food<1 则在内部资源恢复之前返回。**这里没有饥饿直接扣血公式**。因此 fresh 资源满但没有
自然补水恢复；这是真正 source-valid 后续可玩性依赖，不应静默“修复”或另送物品。

## AGE / GIFT_TAG BEHAVIOR

`obj/user.c::update_age()`：`age = 14 + age_modify + mud_age/86400`；首次 last_age_set 从0设为
当前 time，本次增长0。之后累计在线更新的秒数，不按 birthday 的真实年月计算；不是一登录15岁。
heartbeat 的 age 更新**不调用 gift 随机化**，重连接也不调用 `enter_world`。

下一次完整登录中，若 tag 存在且 setup 后 age>=15，按 **str → cps → int → cor → con → spi → per → kar**
逐一 `10+random(21)`（10..30），最后删除 tag。成功保留删除后的状态则只随机一次。
save 发生在随机化之前，突然丢失未保存的后续状态可能使下次再次消费旧 tag；正常 quit 会保存。
这是源码顺序风险，不是实现原生“反复刷属性”的授权。

human 先按新 age 算资源，再随机属性；资源最大值本身依 age/内部最大值，不能笼统说依赖八属性。
**体重及负重**则使用随机化前的 str，未在本次 login 重算。move weight/max_encumb 是 static，
新建 body 下一次 setup 再据已保存 str 计算；不应说这个错位永远不恢复。

## COMBAT EXPERIENCE

**fresh 的有效 `combat_exp` 精确为0，而非显式 `set("combat_exp",0)`。**
沿 `obj/login.c` / `logind.c` / `obj/user.c` / `std/char.c` / `chard.c` / `adm/daemons/race/human.c` /
`feature/dbase.c` / `feature/save.c` / `updated.c` 追踪：fresh 没有 user restore，没有经验赋值；
缺失键查询为0，human default object 也没有经验。所继承 feature 的声明/初始化没有补发经验。
不能把 NPC traveller 的600..999，或 oldpine bandit 的600，搬给玩家。

Godot `OldPineWorldSessionController.NEW_GAME_COMBAT_EXPERIENCE=600` 明确为已批准的
**Old Pine Technical Demo / CXR baseline**，不是 ES2 new-account rule；S0 不修改它。

## INITIAL INVENTORY / EQUIPMENT

`obj/cloth.c`：布衣，alias `cloth`，weight3000，material cloth，armor_prop/armor1；
继承 `std/armor/cloth.c` → EQUIP / F_EQUIP。cloth setup 的 dodge 条件是 **weight>3000**，
这里不满足；不能套用 `std/equip.c` 的 >=3000 默认 setup 再叠加一次。wear 在直接角色 inventory
登记 cloth 槽和 worn marker、应用 armor+1。

**Source fresh player does NOT start with the current native long sword.** 自动路径只创建布衣，
没有钱、书、背包、食物、酒袋或武器。房间 spawn、商店库存和手动 pickup 均不是开局赠送。
首次 `restore_autoload` 无条目；布衣无 query_autoload。每次完整 enter_world 都再尝试发一件布衣，
不是 only-new 的分支；重连例外。`cmds/usr/quit.c` 先处理非 autoload 物品掉落再保存。

## START_ROOM / STARTROOM

`include/login.h::START_ROOM` 是无 saved startroom 时的默认值；它不等于所有存档的当前位置。
`cmds/usr/save.c` 仅在房间 `valid_startroom` truthy 时更新玩家 `startroom=base_name(room)`。
Snow 两处标记为1：inn 与 schoolhall；保存于其他房间不更新这个登录落点。
logind 对已有字符串 startroom 不再复查 valid_startroom；ghost 优先 DEATH_ROOM。
silent enter_world 不执行选择房间/移动段；不是普通新手流程。
这不是 home / fast travel API，更不是原生 Save/Continue 精确坐标恢复的替代品。

## SNOW TOWN ROLE

源码证明：雪亭镇集默认登录、复活落点、客栈物资、武馆/书院、兑换/出售、药铺、打工、驿站与
多区域道路于一处。合理推断：它是探索/准备/成长 hub；没有证据规定唯一“第一任务”或毕业副本。

饮风客栈（`d/snow/inn.c`）描述为镇南、外地旅人聚集交换消息的小店，并有老板仙人传闻。
east→square、up→inn_2f、northwest→wizard reception；西北木门初始关闭。
`sign` 普通显示店名，wizard 才多见题字；不是属性/经验奖励。objects：traveller×2、waiter×1；
留言板调用已注释。楼上名气要求只有叙述，房间没有名气 gate。

**原生聚类建议（非实施）**：Snow outdoor 包含广场、街道、东/南道路及对应 zone；Inn 可以作为
同一 Town map 的小室内区，或若多楼层/镜头/遮挡需要而作为一个紧凑 Inn interior map。
推荐先 Town 内小室内功能块验证入口；需要独立 interior 时整栋一图，不按客房拆图。
武馆的院落/房间适合一个较完整 compound；药铺、铁铺、钱庄等小室内优先共用 building-zone 模式。
Snow↔Old Pine 等区域连接才是明确的跨 map portal 候选。

## SNOW TOPOLOGY

独立遍历 **38 个 `d/snow/*.c` 顶层 room**；下表省略共同前缀及 `.c`。
方向为实际 exits，不从 long prose 推断；N/S/E/W/U/D/NE/NW/SE/SW 是方向缩写。

| Room | 实际 exits | objects / 有意义机制 |
| --- | --- | --- |
| inn 饮风客栈 | E square; U inn_2f; NW /d/wiz/entrance | traveller2、waiter1；startroom；西北门/sign |
| inn_2f 客栈二楼 | D inn; W w_room; N n_room; E e_room | rat6；三扇关闭房门 |
| w_room 客房 | E inn_2f | 成对关闭门 |
| n_room 客房 | S inn_2f | 成对关闭门 |
| e_room 客房 | W inn_2f | 成对关闭门 |
| square 广场 | N mstreet1; W inn; S sroad1; E temple | trav_blade3；worker4 已注释 |
| mstreet1 街道 | N mstreet2; S square; W bank; E school1 | 钱庄/武馆入口 |
| mstreet2 街道 | N mstreet3; S mstreet1; W smithy; E workplace | drunk1、scavenger1 |
| mstreet3 街道 | N mstreet4; S mstreet2; E hockshop; W herbshop | 当铺门初始关闭 |
| mstreet4 街道 | N crossroad; S mstreet3; W postoffice | 叙述东巷无 exit |
| crossroad 山坳 | N /d/goathill/mroad1; E /d/green/path6; S mstreet4 | 山寨道路警告 |
| bank 安记钱庄 | E mstreet1 | annihir1；BANK兑换；no_fight/no_magic 注释 |
| smithy 打铁铺子 | E mstreet2 | smith1，定制买铁锤 |
| workplace 谷物加工厂 | W mstreet2 | work；no_fight1 |
| herbshop 桑邻药铺 | E mstreet3 | herbalist1、woodcutter1；药品交易 |
| herbshop1 药铺密室 | 无 | 无入口机制，不能从墙壁叙述认定可达 |
| hockshop 丰登当铺 | W mstreet3; E hockshop2 | HOCKSHOP；西门关闭；master spawn 注释 |
| hockshop2 储藏室 | W hockshop | 无拍卖实现 |
| postoffice 雪亭驿 | E mstreet4 | post_officer1；离开销毁临时 mailbox |
| school 书院 | N sroad2 | teacher1个，使用 npc/teacher.c 而非 teacher1.c |
| school1 武馆大门 | W mstreet1; E school2 | guard1；关闭红门，没有身份/经验出入 gate |
| school2 教练场 | W school1; N weapon_storage; E schoolhall | trainee6、fist_trainer1 |
| schoolhall 大厅 | W school2; E inneryard | swordsman/master1；valid_startroom1；board调用 |
| inneryard 天井 | W schoolhall; E innerhall; N nyard; S guestroom | 柱子文字 |
| innerhall 内院 | W inneryard | 其他叙述房间无 exits |
| nyard 书房 | S inneryard | girl1 |
| guestroom 客房 | N inneryard | prose方位不可替代exit |
| weapon_storage 兵器储藏室 | S school2; 条件D secret_storage | bamboo_sword1；push开机关 |
| secret_storage 地下密室 | 初始无；条件U weapon_storage | /obj/shield1；返回口依加载顺序 |
| sroad1 街道 | N square; W sroad2; E eroad1; S /u/cloud/dragonhill/nroad | 另一条出镇方向 |
| sroad2 街道 | E sroad1; W sroad3; S school | farmer2 |
| sroad3 青石官道 | E sroad2; W sroad4 | 风景描述不是额外出口 |
| sroad4 青石官道 | E sroad3; N sroad5; SW /d/canyon/road | crazy_dog1 |
| sroad5 青石官道 | S sroad4; W /d/waterfog/sroad1 | 水烟阁方向 |
| temple 城隍庙 | W square; S eroad1 | keeper1、/obj/paper_seal2、d/snow/obj/denotation1；no_fight="1" |
| eroad1 黄土小径 | W sroad1; N temple; E eroad2 | 无专属 gate |
| eroad2 黄土小径 | W eroad1; E eroad3 | dog2 |
| eroad3 山路 | W eroad2; E /d/temple/sroad; S /d/oldpine/npath1 | prose石阶“北”与east出口不一致 |

`std/room.c`：setup/reset 创建 objects；这是房间 reset 列表，不是永久同时在场人数，
NPC random_move 后会离开。普通 closed door 可以 `cmds/std/open.c` 打开；closed≠locked。
`cmds/std/go.c` 检查负重、busy、exits、目标加载、source valid_leave，再 move；没有通用入镇任务检查。

`weapon_storage`：`push shelf` 只提示；其他任何非空参数都增加 left_trigger，第三次开 down10秒。
设置对面 up 时只 `find_object(secret_storage)`，不主动 load；第一次才加载密室可能没有上返口。
这是条件连接/加载依赖，不是应无脑制作的正常门。herbshop1 的入口经全 mudlib `.c` 搜索未找到。

## EXTERNAL WORLD CONNECTIONS

| Snow 出口 | 外部目标 | 目标中确认的返回 |
| --- | --- | --- |
| crossroad N | d/goathill/mroad1 | S crossroad |
| crossroad E | d/green/path6 | W crossroad |
| eroad3 E | d/temple/sroad | W eroad3；后续eastup阶梯，不能按旧help误认区域 |
| eroad3 S | d/oldpine/npath1 | N eroad3 |
| sroad1 S | u/cloud/dragonhill/nroad | N sroad1 |
| sroad4 SW | d/canyon/road | NE sroad4；另有climb chain耗资源入峡谷 |
| sroad5 W | d/waterfog/sroad1 | E sroad5 |
| inn NW | d/wiz/entrance | SE inn，门；再往west才验证wizard身份 |

七条常规外部道路 + 一条 wizard reception 连接。`u/` 并不自动等于无效/非游戏内容：dragonhill
是实际双向出口；wizard reception 本身允许玩家意见交流，但编辑/管理空间不是 native world 移植目标。
这里只追每个相邻目标及返回，未宣称审完七个区域的内部系统。

## SPAWN → OLD PINE ROUTE

静态 exits 的两条同长最短路线均为 **6条边**：

```text
inn --E--> square --S--> sroad1 --E--> eroad1 --E--> eroad2 --E--> eroad3 --S--> oldpine/npath1
inn --E--> square --E--> temple --S--> eroad1 --E--> eroad2 --E--> eroad3 --S--> oldpine/npath1
```

起点 waiter1/traveller2；广场 trav_blade3；第二条经过 temple 服务/物品及 no_fight；两条都过
eroad2 dog2；npath1 无 objects。**Fresh、清醒、不忙、未超重时 freely traversable**：没有
锁门、钥匙、缴费、任务、拜师、年龄、经验门槛。动态战斗、移动 NPC 或 runtime load error
不在“静态合法路线”保证内。两条路线不用经过疯狗的 sroad4。

npath1 S→npath2 SE→npath3 E→clearing，再接其他林路；前三段无 authored NPC spawn。
`clearing.c` 有歹人告示；`d/oldpine/npc/bandit.c` aggressive、exp600、sword/parry/dodge10。
源码证明邻接树林、探索与危险，合理推断为早期可选野外；**未证明专为0经验玩家平衡或必须先来**。
Current Godot 从 clearing 直接开始，是跳过 Snow 与 north approach 的技术基线。

## EARLY NPCS

读取全部 **26个 `d/snow/npc/*.c` 顶层文件**，结合 room 实际 spawn，不把存在文件当成出生。

| 类别 / 源文件 | 实际角色/行为与边界 |
| --- | --- |
| waiter | friendly，exp10000/dodge300；greeting、vendor、生日口令cake分支（目标文件缺失） |
| traveller / trav_blade | friendly，exp600+random400；dodge50/unarmed40；后者throwing30+飞刀；漫游、不是主动新手敌人 |
| farmer / woodcutter | exp20/140；农夫friendly遇战求饶；樵夫传闻+漫游+斧，不是武器赠送 |
| drunk / scavenger | 街道NPC；酒品交换线索；拾荒者有旧书但没有交易/赠书回报 |
| smith / herbalist / annihir | 铁锤定制交易 / F_VENDOR药物与不完整诊疗 / 强大钱庄老板；兑换由BANK房间实现 |
| teacher | 书院魏无极，literate60；收价值>=500物品写 marks，再recognize；非普通apprentice门派师父 |
| guard | 武馆刘安禄，exp20000/blade40/parry40；身份询问可揭露群体敌对，不是入门门卫拦路逻辑 |
| fist_trainer / trainee | 教头exp3000，unarmed30/liuh-ken20/dodge30；只认封山家族教学/切磋；弟子6个exp100 |
| girl | 柳绘心，exp1000，家族“封山剑派北宗”；有武功但拒绝所检查的切磋，不自动成为老师 |
| keeper / post_officer | 捐献调整bellicosity / mailbox服务；不是开局强制任务 |
| dog / rat / crazy_dog | 普通狗讨食/骨头跟随、老鼠高dodge；疯狗aggressive，见下节 |
| worker / old_farmer / beggar / mercenary / proposer / teacher1 | 未由这38房间的有效objects引用；worker条目注释。不能计为Snow开局服务。beggar另在u/cloud有引用；teacher1是另一版本，不能替换实际teacher.c |

另由 `schoolhall.c` 引用 `daemon/class/swordsman/master.c` 柳淳风：exp1000000、封山掌门，
已有特殊剑招/装备；其完整战斗不是最小出生 slice 前提。

## TRAINING / SCHOOL

- **书院 ≠ 武馆**。`school.c` 的 teacher 通过 `accept_object` 接受价值>=500（不要求必须money），
  写 `marks/魏无极`。`give.c` 先 accept 后销毁有价值给NPC的物品；不能称老师把钱永久存进背包。
  `learn.c` 的 recognition、teacher raw skill、prevent_learn、valid_learn、potential/gin及经验检查
  决定学习。teacher 的 `accept_learn()` 不是这个 learn 命令的实际 gate。
- `school1/2` 的红门只是 closed。guard 无 valid_leave 拦路。`swordsman/master.attempt_apprentice`
  要有效 cor>=20且cps>=20；fresh30满足。`apprentice.c` 设置pending → NPC `recruit` →
  `feature/apprentice.c::recruit_apprentice` 创建family，再master设置class=swordsman。
  `std/char/master.c::prevent_learn` 管背叛/嫡传限制；不是入门费用。
- fresh raw0 的 basic sword（`daemon/skill/sword.c`→`std/skill.c` 默认valid_learn1）可以在
  完成拜师后开始向master learn。学武门槛 `raw^3/10 > combat_exp` 使用整数除法；exp0不是
  “任何一次learn都禁止”，但很快限制后续成长。此处不设计经验farm或保证战斗胜率。
- `study.c` 必须直接持有带 skill mapping 的物品、raw literate>0，并过 exp_required、
  valid_learn、sen、max_skill。`obj/old_book.c` 为force、exp_required0、sen_cost30、difficulty20、
  max_skill10；在scavenger身上，**没有证明正常付款就送书**。
- `practice.c` 要已映射特殊技能及basic/special均>=1；`selflearn.c` 只许七种basic且raw>=40；
  `exercise.c` 要已映射force。这些已有命令不是无技能新人的免费初始化。
- 在 commands 文件列表中未发现独立 `teach.c`；教学由 learn 与NPC recognition/prevent回调完成，
  不因玩家用词“teach”再造一套系统。

初始可增长能力的路径存在，但需要显式NPC接触/拜师或付款。学习公式已有 native core 可复用；
教学身份、付款、书籍和玩家可见交互不能因 core 存在就称已迁移。

## ECONOMY / SHOPS

| 功能 | 执行源 | 可证明范围 |
| --- | --- | --- |
| 客栈购买 | waiter + feature/vendor + cmds/std/buy | dagger50、wineskin20、dumpling15、chicken leg30（文价值）；不是免费补给 |
| 铁匠 | smith.buy_object / compelete_trade | 中文“铁锤”售价300；货品hammer自身value3，价格不可混同 |
| 药铺 | herbalist + F_VENDOR | hurt_drug2000、snake_drug1000；问诊没有完整治疗实现 |
| 银行 | std/room/bank | convert按base_value；gold/silver/coin；deposit空函数，不是存取款账户 |
| 当铺 | std/room/hockshop | value；pawn60%、sell80%，付款后destruct；没有当票/赎回实现 |
| 打工 | snow/workplace | gin<30或sen<30拒绝；先sen−30再gin−30，新建silver amount1；无busy/exp奖励 |
| 买防具 | 已检查Snow vendor/铁匠 | **NOT FOUND**；login布衣、NPC穿戴≠防具商店 |

依赖：typed物品/stack/value、直接inventory、资金检查/支付、商人报价与交货、NPC授权、
失败时状态顺序及食饮物品作用。不是一个泛化 LPC `buy_object/call_other` dispatcher。

`feature/finance.c::can_afford` 有具体缺陷：**只有coin、没有silver时，价格%10000非0仍返回2**，
即使铜钱足够；单个silver又不能付50文零头。不能把“打工一次→兑完→买匕首”当保证成功路线。
源码可通过的具体资金构型：work两次得2silver，bank convert其中1silver成100coin，保留另1silver，
再买50文dagger（can_afford=1，pay扣50coin）；初始gin/sen100，work两次后40，不依赖先恢复。
这是证明可行构型，不是推广遗留bug或指定唯一玩法；future finance port必须专项决策。

酒袋实际装红酒15份；`feature/liquid.c` 每喝一次water+30、drunk+6，非纯水补给。
包子food_supply60；`feature/food.c` 加food后消耗份数，没有将最后一次补给 clamp到容量。
Snow room未发现 `resource/water`，不能凭客栈“喝茶”描述虚构免费水源。

## FIRST WEAPON AVAILABILITY

**Source does not prescribe a unique first weapon path.**

1. 最近的交易地点就在spawn：waiter售50文匕首（damage4，weight1000）；fresh没钱，须先取得资金，
   上节给出工作/兑换构型。烤鸡腿也是HAMMER，damage1，既食物又可wield，吃完保留骨头。
2. 无金钱/击杀要求的正常pickup：inn E square N mstreet1 E school1，`open east`，
   E school2 N weapon_storage，`get bamboo sword` → `wield`。
   竹剑weight1000/damage10/value100；没有no_get，门不锁、guard无出入拦截。
   这是武馆公共objects物品，不是自动赠送或绑定奖励；reset和他人拿走影响当时是否在场。
3. smith铁锤可买，300文/weight8000/damage15；NPC斧剑和bandit掉落属于另外的战斗/取物路径，
   不能把杀平民或大幅强于玩家的NPC定为正常开局要求。

`cmds/std/get.c`、`cmds/std/wield.c`、`feature/move.c`、`feature/equip.c` 证明直接inventory与容量/
手占用流程。没有“新手必须使用长剑”的源码规则；native oldpine long_sword是独立技术赠品。

## EARLY COMBAT PRESSURE

inn / square初始NPCfriendly，无强制敌人；inn本身**未设 no_fight**，不能称绝对安全房。
`eroad2 dog` 无aggressive字段，exp缺失查询0、attack10/armor3，bite+claw；不是自动敌对。
`rat` 无aggressive，dodge120。`sroad4 crazy_dog` aggressive、exp100、attack15/damage6/armor2，
有漫游：风险不能永久限定在一个点。`adm/daemons/race/beast.c` 可推初始狗资源50/50/50、疯狗70/50/50；
这不是fresh对战胜率承诺。

`feature/attack.c::init` → `combatd.c::auto_fight/start_aggressive` 才产生接触敌对，后者再次检查
same environment/living/no_fight再kill；态度标签不等于所有NPC一出现就攻击。
初始无vendetta/killer、无正bellicosity；没有源证据把fresh直接放进必战压力。
但主动挑衅、移动威胁和guard身份分支会改变结果；Annihir甚至accept_fight转kill。
所有这类角色完整战斗都不应被“town NPC”标签掩盖。

## NEW PLAYER GUIDANCE / QUESTS

`adm/etc/welcome` 是世界标题，`motd` 是测试/规则提示，`new_player` 只有欢迎短句；全mudlib
搜索 `NEW_PLAYER_INFO` 只见宏定义，**未证明新账号自动显示该文件**。
`doc/help/start` 导向newbie/stats/combat/quest；`doc/help/newbie` 解释fight/kill、布条、
食饮、道路、门派。这里有旧信息：食饮恢复说明与damage顺序不一致、英文商品提示与vendor keys不一致，
地理指引也不应覆盖实际exits。`doc/help/quest` 是“套装故事”设计说明，不是开局任务脚本。

room signs、waiter greeting、樵夫传闻、`cmds/std/ask.c` 展示inquiry topics，是探索提示来源。
未发现fresh login自动发quest、固定第一目标、现代marker或出镇任务锁。
存在可选剧情素材：guard身份揭露，teacher谈guard，drunk的elder_info/give_alcohol/know_drug线索；
`d/green/npc/oldman2.c::set_flag` 写elder_info，证明它不是fresh自动已有标记。
仅追这些触发边界，不宣称支线完整可执行。

**询问链实际歧义**：ask读 `ob->query("inquiry/... ")`；dbase.evaluate把`this_object()`（NPC）
传给函数，而不是asker。guard.ask_me(who)的exp>=20000实际检查guard自身，不能写成玩家门槛；
随机揭露后仍会遍历房内角色发起敌对。herbalist.heal_me同样读NPC而非玩家资源。
数组型inquiry里的function分支在ask为空，不会执行；inquiryd仅输出问题，不补执行。
teacher.c还声明/引用follow_player但实现被注释；teacher1有实现却不是school实际spawn文件。
这些需要单独源行为决定，不能据叙述制作一条“已证实完整的新手任务”。

## DEATH / REVIVE

`feature/damage.c::die()`：清condition/奖励/尸体/敌对/team处理后，user current与effective三项各1，
ghost1，move DEATH_ROOM=`d/death/gate`。ghost普通登录也优先这里，不用saved startroom。
gate放白无常；`d/death/npc/wgargoyle.c` 分阶段call_out后 reincarnate，再move REVIVE_ROOM=
`d/snow/temple`。`bgargoyle.c` 有类似流程但先检查ghost（阳人可能被攻击），白无常没有同样检查。
`reincarnate()` 清ghost、effective恢复max，**不直接把current补满**。
昏迷后的 `revive()` 是另一种原地醒来，不等于回阳传送。

damage还有 `DEATH_ROOM->start_death()`，全mudlib搜索未找到其实现；不能编造另一死亡流程。
NPC init/call_out能提供所见回阳路径，但缺失调用在目标driver中的处理没有实测。
S0只标位置/依赖，不修改现有native死亡、尸体或恢复契约。

## CURRENT GODOT VS SOURCE

检查真实 production入口而非测试fixture文档：`game/runtime/world/oldpine_world_session_controller.gd`
的 `_initialize_authorities()` 调 `game/runtime/combat_slice/combat_slice_demo_factory.gd`，覆盖exp，
重建session语义item ID，绑定outdoor。`oldpine_outdoor.tscn` PlayerStart=(450,300)。

| Concern | Current Godot | Source ES2 | Classification |
| --- | --- | --- | --- |
| Fresh location | oldpine.outdoor.central_clearing | snow/inn | technical-demo baseline |
| combat_exp | 600 | 缺失键有效0 | technical-demo/CXR baseline |
| weapon | 自带且wield oldpine long_sword，damage25、weight7000 | 无；需取得 | technical-demo baseline |
| clothing | 新玩家ArmorState空，无login布衣 | 布衣cloth槽、armor1 | not yet migrated |
| attributes | 八项20 | 八项30，后续gift事件 | technical-demo baseline |
| resources | gin220、kee220、sen100，current/effective/max全满 | 三项各100 | technical-demo baseline |
| skills | sword/dodge/parry/unarmed raw10；force/perception0 | 空技能mapping | technical-demo baseline |
| age | Player inspect projection使用20；CharacterState无age/gift年龄权威 | age14+在线累计，gift_tag | not yet migrated；不能说已持久化20岁 |
| food/water | CharacterRecoveryState默认0/0 | 初始0/0、后设容量400 | 数值source-aligned；不是完整补给/生存loop已迁 |
| title/gender | Player展示，factory固定男性 | 中文名/普通百姓/性别输入 | technical-demo baseline |
| nearby NPCs | Old Pine五个人类NPC、12个bootstrap items；Beast不是普通spawn | inn2traveller+waiter，镇上服务/居民 | technical-demo baseline / not yet migrated |
| Old Pine relation | demo主体与起点 | town外树林，可选危险探索 | technical-demo baseline |
| save/startroom | native Host/Session、精确map/位置和状态Save/Continue | valid_startroom更新下次login落点；autoload选择保存 | intentional native substitution |

其他核对：`game/core/characters/character_state.gd`、`character_base_attributes.gd`、
`character_recovery_state.gd`、`game/runtime/characters/world_player_runtime_state.gd`、
`game/runtime/world/oldpine_outdoor_controller.gd`、`game/data/oldpine/oldpine_world_definitions.gd`、
`oldpine_item_content_definitions.gd`、`game/runtime/combat_slice/combat_slice_content_profile.gd`。
这些差异**不是本次发现的production bug**，也不授权改值。Existing Character/Skill/Equipment/
Inventory/Save/CXR与Beast能力可复用，不能重新建立第二套角色或world authority。

## MIGRATION ORDER OPTIONS

| 选项 | Fidelity / reuse | 内容吞吐与QA价值 | 成本/返工风险 |
| --- | --- | --- | --- |
| A 最小Snow入口→Old Pine接入 | 先纠正入口；复用Session/地图/物品/角色 | 很快验证真正初态、hub与旧野外连接 | 低到中；须明示未迁商店/成长，不冒称完整early game |
| B 完整Snow Town foundation | 更完整社会/经济/武馆语义 | 教学、经济、对话、条件门大量新验收面 | 高；尚有finance/inquiry/源缺失争议，易过度框架化 |
| C 继续扩Old Pine再回出生镇 | 继续复用当前内容管线 | 野外内容快，但仍绕过真正开局 | 中到高；后续改初态会再做可玩性/地图门槛验收 |

## RECOMMENDATION

推荐 **A：Source-valid New Game Entry Slice**，作为**待owner确认的下一计划范围**，不是当前实施。
优先冻结角色出生语义/遗留决策、Snow最小功能拓扑、Inn/Square/一条明确出镇路径、Old Pine north
approach接入以及新旧存档边界；保留已集成core，不把flat room graph做成native movement。

先把它定义为可行走、可检查真实状态的**入口切片**，不要称已完成可持续early-game。
若owner要求同一milestone即可自主恢复/成长，则应显式增加下节的最小补给及教学路径预算，
而不是偷加整个Snow或悄悄送剑/经验/免费回血。S0不做这些产品决定，也不写DECISIONS。

## REQUIRED NEXT DEPENDENCIES

| 项目 | 最小入口切片 | 可持续source early-game |
| --- | --- | --- |
| Typed new-character initialization | 必须；不复制login/account协议 | 必须决定age/gift及food初始化兼容边界 |
| Town geometry / spawn / map portal | 必须；出口意图与物理位置分开 | 支持更多服务建筑，复用resident Session |
| Cloth ItemDefinition / wear / item IDs | 必须复用现有inventory/armor/save | tear/bandage另行授权，不重新造equipment |
| NPC角色/互动与威胁 | 明确所选路线实际NPC清单，不伪称全部迁完 | dog的bite+claw分布超出当前serpent-only bite provider，若纳入需窄扩展 |
| 食饮、恢复与物资来源 | 可暂延但必须明示入口不是完整生存loop | food/water0使它成为真正必要项；最小source购买/资金路径或明确批准的替代 |
| Vendor / work / finance | 可延，不虚构免费商店 | 应选一条完整可行路径；旧零钱检查bug必须专项决定 |
| Teacher recognition / learn UI / apprenticeship | 可延；core已存在不等于runtime可用 | 至少一条初始技能取得路径；不能用selflearn40门槛填补 |
| Books / Study / bank账户 / full hockshop | 延后 | 不是首个入口/最初learn的必需品；兑换与存款分开 |
| Native save compatibility | 若切New Game或扩map/content需列为验收 | 老OldPine存档不改写为fresh；不重建旧autoload架构 |
| Phase5B4 special hit/perform/post_action/poison | **不要求** | 完整高手战斗才另立source-backed需求；不能为“以后会用”提前开工 |

技术上可在无商店/教学完成Town入口，但不能在资源无法恢复、初始技能路径未实现时宣布
“完整新手体验已可玩”。Beast已集成≠可以自动放五条蛇；Lake与蛇群不是开局依赖。

美术顺序：先功能拓扑和可走collision/portal及building占位，确定Inn内外关系、camera/HUD与
交互密度；实测后冻结production geometry，再做最终tiles/装饰和UI skin。
不为38个LPC房间先画38套图，也不现在生成美术。

## OUT OF SCOPE

本次无代码、scene、data或test修改；不改ApplicationShell/New Game、exp600、初始长剑、
当前位置/OldPine bootstrap；不实现Snow、Shop、Training、Dialogue、Quest、Lake、五蛇、Phase5B4。
无新save schema，无运行时测试注入，无账号/Telnet/login daemon兼容层。

## RISKS / LEGACY ANOMALIES

| 发现 | 证据分类 / 不得静默处理 |
| --- | --- |
| food/water在weight setup前为0 | 确定执行顺序；与“容量补满”的直觉不符，产品兼容决定待定 |
| gift在setup/save之后，需下一完整login才消费 | 确定顺序；未保存可重复、weight/capacity暂时不符；不是fresh随机10..30 |
| 每次完整login给布衣、move/wear返回忽略 | 确定调用；并非only-new奖励，native不能照搬连接副作用 |
| can_afford缺silver时拒coin-only非整万购买 | 确定分支缺陷；source-valid买物分析必须考虑 |
| smith报价300而物品value3 | 确定不一致；不自动统一价值 |
| bank deposit空；hockshop票据/赎回叙述未实现 | 实现缺口；pawn真销毁，不能从help发明完整银行/当铺 |
| waiter cake引用不存在 | 在该路径尝试创建会失败；不能列免费蛋糕为保证补给 |
| teacher缺follow_player实现，inquiry数组回调空分支 | 源码缺陷/driver编译处理需进一步验证；teacher1不能偷偷替代 |
| function inquiry参数是NPC | dbase + ask链确定；guard的who经验不是玩家经验；herbalist不是玩家治疗 |
| secret_storage回程依find_object既有加载 | 确定条件分支，实际陷入风险取决加载时序 |
| eroad3/clearing等叙述方位不同于exits | 以exits为拓扑，prose为表现参考 |
| herbshop1无入口；未spawn NPC仍在目录 | 可达性/放置未证明，不补造 |
| DEATH_ROOM.start_death缺失；黑白无常ghost检查不同 | 缺失实现/运行语义歧义，不把全套回阳说成已执行验收 |

## SOURCE COVERAGE / SELF-REVIEW

深读新手调用链、fresh分支及直接初始化依赖；room38个全部读取，NPC26个全部读取。
所列外部目标逐文件读取；更远区域不是本次完整审计。路径存在不等于内容已读。

- Entry/state：`adm/obj/master.c`（connect）、`include/login.h`、`include/globals.h`、
  `include/race.h`、`obj/login.c`、`obj/user.c`、`std/char.c`、`adm/daemons/logind.c`、`chard.c`、`updated.c`、
  `adm/daemons/race/human.c`、`beast.c`；`feature/dbase.c`、`name.c`、`move.c`、`save.c`、
  `autoload.c`、`attribute.c`、`damage.c`、`skill.c`、`attack.c`（初始化/敌对/行动）、`apprentice.c`、
  `condition.c`（初始mapping）、`treemap.c`（nested query）。
- Items/trade/training：`obj/cloth.c`、`std/item.c`、`std/equip.c`、`std/armor/cloth.c`、
  `std/weapon/sword.c`、`feature/equip.c`、`vendor.c`、`finance.c`、`food.c`、`liquid.c`、
  `std/char/npc.c`、`std/char/master.c`、`std/skill.c`、`daemon/skill/sword.c`、`literate.c`、
  `daemon/class/swordsman/master.c`；`cmds/usr/save.c`、`quit.c`，`cmds/std/go.c`、`open.c`、
  `get.c`、`give.c`、`wield.c`、`buy.c`、`ask.c`、`learn.c`、`study.c`、`apprentice.c`、
  `recruit.c`、`practice.c`、`selflearn.c`、`exercise.c`（相关主流程）、`look.c`（item_desc显式传玩家）。
- Room dependencies：`std/room.c`、`std/room/bank.c`、`hockshop.c`、`include/room.h`；
  `d/snow/*.c` 全38个见拓扑表；`d/snow/npc/*.c` 全26个见NPC表；物品深读
  `d/snow/npc/obj/bamboo_sword.c`、`hammer.c`，`obj/example/dagger.c`、`wineskin.c`、
  `dumpling.c`、`chicken_leg.c`，`obj/old_book.c`、`obj/money/silver.c`、
  `obj/drug/hurt_drug.c`、`snake_drug.c`、`d/snow/obj/denotation.c`。其他NPC装备仅识别引用，
  不宣称逐一完成动作/属性审计。
- Connections/death：外部连接表8个目标；`d/oldpine/npath2.c`、`npath3.c`、`clearing.c`、
  `d/oldpine/npc/bandit.c`；`d/death/gate.c`、`d/death/npc/bgargoyle.c`、`wgargoyle.c`；
  `adm/daemons/combatd.c`（auto_fight/start_aggressive）、`inquiryd.c`；
  `d/green/npc/oldman2.c`（set_flag）。
- Text/search：`adm/etc/welcome`、`motd`、`new_player`；`doc/help/start`、`newbie`、`quest`、
  `gift`。全mudlib文本搜索gift_tag、NEW_PLAYER_INFO、start_death、teacher1/herbshop1引用；
  Snow范围检查quest/新手、valid_startroom、resource/water、init/valid_leave、objects。

自审重点：fresh与restore/reconnect分开；30与后续随机分开；food实际0与capacity400分开；
effective0与显式赋值分开；服务叙述与可执行方法分开；目录存在与实际spawn分开；
source facts与native产品建议分开。未把既有技术基线误称bug，未改变遗留源。

## VALIDATION

本slice采用docs-only gate：检查允许变更文件、`git diff --check`、文档尾随空白、
新增/编辑文档本地链接与所引用完整路径、`tools/ci/repository_checks.py`。
实际结果：repository/static PASS；37个本地Markdown链接 PASS；文档尾随空白 PASS；
显式完整source路径检查 PASS（自审将三个依上下文省略的路径改成完整路径）。
独立从38个Snow文件提取方向exits进行最短路径搜索，确认两条6边路线；条件门另作人工源核对。
相对base的 production/test/reference/DECISIONS/build/CI/export delta全部为0。
不重跑完整gameplay suite、headless或live game：没有可执行变化，也没有声称玩家路径已实测。
这里的route是静态source合法性，不是Godot live traversal。

## NEXT SLICE READY / NOT READY

**S0分析已可交owner review；Snow implementation NOT AUTHORIZED。**
下一步先确认A的预算/验收范围以及初始化异常、age/gift、早期补给和旧save兼容策略；
否则不足以宣称完整source-valid early game设计已冻结。
本分支仅提交/推送本分析与STATUS/ROADMAP修正；不创建PR、不合并、不自动启动下一slice。
