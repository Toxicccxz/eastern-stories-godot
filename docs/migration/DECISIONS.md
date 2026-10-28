# Migration Decisions

本文件记录对 ES2 的每处改动和全局规则，一条一项（AGENTS.md「Changing ES2」）。先是按系统归纳的现行规则，
然后是现行条目原文，新的在前、无日期的旧条目在后；被后来条目取代或只有历史意义的条目移到
[DECISIONS_HISTORY](DECISIONS_HISTORY.md)。引用写作 DECISIONS「条目名」。

## 现行规则（按系统）

每条写游戏现在怎么做，后面是出处条目；一条被后来的条目改过一部分时，两条都列出，以这里写的为准。

**产品与流程**
- 以 ES2 为底的现代武侠 RPG：会让今天的玩家却步的规则和节奏可以改，但每处改动在本文件记一条；改动走数据开关，开关留 ES2 原值作「经典模式」。「产品定位」
- 第一版只发桌面端；画面不为手机帧率减配，Android / iOS 的 CI 作业只当构建门槛。「首发只做桌面」
- PR 合并时 owner 没回答的问题按推荐方案生效、标「默认」，owner 随时可以否决。「积压问题的处理」
- 重要或致命的选择先问，全用 ConfirmPrompt，焦点在「取消」；攻击和切磋一律先问并说明对方强弱，逃跑、投降、运功不问。「Ask before an important or deadly choice」「说话和交互」
- 读来像 bug 的 ES2 行为修掉：拒收句不提「其他玩家」，拒收的东西退回，被偷时告诉玩家，蛇药说明还剩多少毒。「Modern fixes: ES2 behaviour that reads as a bug」
- 简体中文是源语言，消息 ID 就是源文本；`tools/l10n/extract_pot.py` 是唯一的提取器；语言跟系统或设置。「Localization: the source text is the key」

**全局驱动规则**
- MudOS `random(n)` 在 n ≤ 0 时为 0 且不抽数；每个移植的 `random()` 都走 `legacy_random(n)`。「MudOS random(n <= 0) is 0, everywhere」
- 命令失败时显示最后一次 `notify_fail()` 的句子。「MudOS notify_fail(): the last call wins」
- 导入时：未知转义 `\X` 得 `X`，颜色宏去掉，没有 `set_weight()` 的东西重 0，LPC 字符串里的硬换行去掉。「Content importer and Snow's first NPCs」「Snow's inner rooms」「卧龙岗 + 绮云镇 3A」
- 其余会让驱动报错的除零或非法值（战斗里 max_gin / max_kee 为 0、修炼百分比、智力 ≤ 0 的自学、请教的运行时错误）返回有类型的失败，不夹值、不崩溃，此前完成的改动保留。「Combat invalid random bounds become ordered typed failures」「Cultivation percentage division by zero」「Self-learning with non-positive intelligence」「Learn legacy runtime errors preserve completed mutations」
- LPC 没定义的顺序换成稳定顺序：状态按 ID 升序更新，死亡和尸体里的物品按稳定实例 ID，致命关系按 CharacterId。「Condition update order」「Death and corpse inventory ordering uses stable instance IDs」「Combat lethal relationships use stable character identity」
- 战斗中一回合 = 一次心跳（`combat_round_ms` 1000），战斗外心跳 2 秒（`heart_beat_ms`）。「One map runtime」「响应性」
- 进行不下去的战斗以 ABORTED 结束，不冻结；开发版报错，测试失败。「A failed fight ends instead of freezing」
- ES2 编译不过的文件可用 override 的 `source_fixes` 修（记为偏离）；NPC id 带区域子目录；Big5 丢的「□」按 `text_replacements.json` 定字。「晚月庄 A」「积压问题的处理」

**地图与体素**
- 所有地图用固定正交斜视体素表现；2D 地图仍是唯一依据（碰撞、站位、交互范围、存档）；左右 45° 两个视角，按钮切换、0.6 秒圆弧；家具只记在布局里。走过的地图只有最近 `voxel_worlds_kept`（3）张保留建好的体素世界，更早的在玩家离开后释放、回去时按原样重建；2D 地图照常全部常驻，释放不碰任何规则、NPC 或存档。「固定俯视体素地图」
- 昼夜跟着游戏里的一天走：ES2 的八段（`day_phases.json`）、一天 24 真实分钟（`day_length_minutes`，经典也是 24），画面按五个关键帧（黎明、白天、黄昏、夜、深夜）在段内平滑过渡，每区一套光（`<区域>/voxel/light.json`），单图只覆盖写了的帧；室外房间的描述末尾接当段天色一句，段开始时室外的人看到一行；设置「昼夜」三档（跟随 / 一直白天 / 一直夜晚）代替 HUD 按钮；时刻存进存档（`day_seconds`）；NPC、门、刷怪、战斗都不看时刻。「昼夜」
- 天气只有云量：natured.c 的五句天色（万里无云 → 乌云密布）每 2–4 游戏小时走一档，跟世界时钟一起推进、一起停；室外描述在当段天色后再接当句；
  画面按云量压暗日光、天色和环境光偏向本区的 `overcast` 色、影子变软，白云飘来飘去的两档有漂过的云影；室内不受影响，灯只看昼夜；换档不提示。
  雾只在原文写了雾的地方：水烟阁山里的晨雾（黎明有、白天无）。存进存档（`sky_level`、`sky_minutes_left`）；配速开关 `sky_weather`，经典关 = 永远晴、不显示那句。
  雨、雪、风不做。「天气」
- 地图尺寸以体素视角下好走为准：路能两人并排、绕过路中间的人；野外能在敌人察觉圈外绕过去，原文守路的除外。「地图尺寸以体素视角为准」
- 每个能进的房间在所属建筑（或院落）自己的图上，由门口的一对通道进出；房间、出口、门锁和站位不变，所有地图常驻。「地图重构」
- 一个高度一张图：攀爬、洞穴、跳落是换图；地形按瓦片碰撞，门和可开关的挡块是节点。「Old Pine: one map per height level, collision on tiles」
- 区域按身体中心归属，只在相邻区域间走；ES2 没有的原生连接写成区域 `links`。「One map runtime」
- 同一张图上相邻同名房间算一处，走进去不再显示描述；标 `distinct` 的照样显示。「Neighbouring rooms of one name are one place」
- 老松林按原文方位排布：坡在空地南边，栈道从 epath3 上崖。崖上是一条林径（东到灌木、南到悬崖边、北绕深林到 cliffdown），没有迷宫；老松寨的路藏在灌木后，跟着刀痕才开、开了就不关（印记存档）。山洞的随机出口是一个固定迷宫。「老松林按原文方位排布」「老松林的林径与藏起来的寨门」「Old Pine remainder A」
- 地图由画家按房间文字画；ES2 只描述、没写房间的去处只画不通。「雪亭镇's maps drawn by the painter」「老松岭's maps drawn by the painter」
- 尸体躺在倒下的地方，会碰墙时最多侧移 40 px。「Old Pine: one map per height level, collision on tiles」

**移动与交互**
- 走路 0.08 秒加到全速（220）、0.06 秒停；身体是直径 34 的圆；贴墙滑动，正面撞上棱角时往两侧最多看 12 px。「手感」
- 走通道换图时淡出淡入，期间世界停住；到达后横幅写「区域 · 地点」；镜头立即对准玩家。「手感」「地图重构」
- 只对够得着的东西给动作：NPC、尸体、地上的东西和地标约 96 px 内，门和服务按各自范围；点地图上的空处不选东西。「The HUD's actions for what is near」「说话和交互」
- E / A 或点击作用于够得着的目标（最近的或面向的，Tab / Y、Q / LB / RB 换），只做一件事的直接做，其余打开两栏交互窗口；窗口开着时世界时间停，「确认」后在世界里发生。「说话和交互」
- 搜刮尸体要站在尸体 96 px 内。「Corpse loot requires a near-corpse spatial range」
- 给予一次可勾选多件；给出已装备的东西或一两黄金以上的钱先问（收赌注、布施的不问）。「说话和交互」「积压问题的处理」
- 问候等玩家第一次走近（136 px）才开始；远处的闲聊不给玩家看；NPC 的话显示在头顶气泡并记入消息。「说话和交互」「手感」
- 请教、练习、打坐、冥思、修行可以「连续」：每步 150 ms，规则和抽数不变，遇到拒绝或白费的一步之前停下并说明。「连续修炼」

**战斗**
- 战斗中世界停住；战斗速度（慢 / 标准 / 快）只改一回合用多少真实秒；句子 0.12 秒一句；结束定格 0.8 秒。「手感：战斗」
- 战斗记录用 combatd.c 的原句，伤害数字跟在句末；闪避、招架的措辞不抽战斗随机流。「Battle narration in ES2's words」
- 有人要杀玩家时显示 kill_ob() 的「看起来X想杀死你！」并钉在战斗记录上方。「How a fight opens」
- 切磋走 fight.c 和 NPC 的 accept_fight；持兵刃的切磋会伤人，照 ES2；兽类不能切磋；凶手是最后一击的人（last_damage_from）。「切磋: fight.c, accept_fight and armed spars」
- 进门一起上：玩家所在区块里见人就打的一伙，有一个够得着就整伙进同一场战斗；出手前提示一拍（500 ms）；打过的人等玩家离开区块再回来才重新察觉。「进门一起上」
- 室内区块整间房就是察觉范围，户外按 NPC 的圈子。「室内察觉」
- 玩家这边要杀的人倒下时停手，卡片上给「了结 / 放过」；放过不记仇；设置「击倒后」可选直接了结（ES2）。「了结 / 放过」
- 逃跑：排队、忙时等，验证通过就成功，留在原地脱离，不耗资源、不抽随机数。「Active Semi-Auto V1 Flee is same-position disengagement」
- 投降：杀你的对手还站着时被拒，否则停战、扣 50 综合评价。「绮云镇 3C」
- 运功、perform、施法在战斗中排队，忙时等；加力立即生效。「Internal power in combat: enforce, exert, the force hit」「The player's perform」「青石村 D」
- 副手兵器的属性也计入；锤、杖的 bash 可以把兵器打飞或打断。「野羊山」
- 杀气狂暴和瞪眼照 ES2 掷骰，但不会落在自己师父身上；第一次到门槛时提示一次。「水烟阁 C」
- 多个敌人的 NPC 每次攻击按 select_opponent() 挑；生死战里站着的谁都不再打谁时结束。「青石村 D」
- 战斗中不能拾取；「运功疗伤」置灰。「积压问题的处理」

**NPC 行为**
- 打听列出 ES2 的话题（这里、名字、传闻和 NPC 自己的）；答复已经做了事就不再接「没听说过」；会让 NPC 翻脸的话题先确认。「NPCs talk and wander; rooms reset」「青石村 B」「刘安禄的揭露」
- 刘安禄的揭露照 guard.c：经验 20000 起问「刘老三」，一半装傻，否则变身血手刘三动手，房间重置不收回。「刘安禄的揭露」
- 闲聊按 npc.c chat() 抽；昏迷的 NPC 不说话、不问候。「NPCs talk and wander; rooms reset」
- 游走只在家和隔壁，可以穿门到下一张图；落脚点离门 48 px 以上，被玩家顶住会侧身让开。「NPCs talk and wander; rooms reset」「地图重构」「积压问题的处理」
- 回应玩家的 call_out 最晚 0.4 秒到；伤人、动手、赶人的问候保留 ES2 的 1 秒。「响应性」
- 买路钱强盗看见欠钱的玩家立即喊一声，2 秒后还在范围里才动手；走过去不记仇。「响应性」「Pacing knobs and 卧龙岗's second」
- NPC 受伤会回复，昏迷后 random(100 − con) + 30 秒醒来。「切磋: fight.c, accept_fight and armed spars」
- 一场战斗结束后 NPC 忘了玩家（召唤出的除外）；在战斗中 random_move 的 NPC 走出这场战斗；带 vendetta 标记的见人就打。「山烟寺 A」「了结 / 放过」「绮云镇 3C」
- NPC 的记忆（对象变量）存档；重生的从 create() 重来。「乔阴 B」
- 召唤物（天将等）的击杀算召唤者的，战斗结束就走。「青石村 D」「青石村 C」

**成长、武学与门派**
- 拜师分 requirements、oath、trial 三种；师父拒绝就结束这次请求；改投他派先问，背叛扣综合评价、betrayer + 1；杀自己的师父也算背叛。「水烟阁 B」「山烟寺 C」「绮云镇 3B」「绮云镇 3C」
- 拜师页列出条件和玩家的数值；请教页写每门能学到几级、卡在哪里。「上限预览和拜师条件」
- 激发在战斗外任何地方都行；练习、打坐、冥思、修行、自学、研读在武学页。「Offense/defense routes B」
- 连续打坐可选「练到 N 再停」；内力上限第一次到 10 / 25 / 50 各给一次小额历练（经典关）；拜师成功盖一张卡片。「新手链与当前目标」
- 打坐、冥思、修行提高上限时立即重算最大精气神，继续游戏时也重算。「积压问题的处理」「Internal power in combat: enforce, exert, the force hit」
- 经验：战斗涓流和回复 ×3、历练奖励、落后补偿、分档潜能上限、打坐 ×6、木人和悬赏榜（见下「节奏开关」）。「经验节奏」「Pacing knobs and 卧龙岗's second」
- 朱鸿雪只派游戏里有的目标；时限 ×1.5、按游戏时间走、存档；任务奖励的潜能上限只止增。「绮云镇 3C」「Pacing knobs and 卧龙岗's second」
- 重兵器和重防具按重量扣轻功，物品详情写明。「积压问题的处理」
- 新角色 14 岁、八项天赋都是 30（不做 15 岁的重抽）；名字是 1–24 个 Unicode 字母；新游戏有「随机名字」和「节奏：现代 / 经典」。「New Player Delayed Gift Randomization」「Generalized Player display names」「手柄」「经典模式总开关」

**物品与经济**
- 给予、丢下、放进、取出照 give.c / drop.c / put.c / get.c；被拒收的那部分留在玩家身上；丢在地上的东西连位置存档。「Give, drop and put; shops and teachers on their NPCs」
- 商店和师父跟着 NPC 本人；昏迷的店主照卖，死了等重置；货无限，每次买都是新物品。「Give, drop and put; shops and teachers on their NPCs」「Snow waiter / dumpling supply loop (S4B only)」
- 付钱按金、银、铜的顺序；钱庄兑换；当铺按价值八折收购（先银后铜，至少 1 文），不做典当和赎回。「Currency exchange / payment core (S3B only)」「Hockshop valuation / payout / sell lifecycle (H2)」
- 飞刀、蛇药、桃符纸等是通用的组合物品；数量到 0 立即销毁。「Old Pine remainder B」
- 一整堆拿不动时捡能拿的部分；赢的钱拿不动的落在脚边。「绮云镇 3D」
- 吃完的肉留骨头，骨头可以喂狗（狗随后跟着走）；有的食物同时是兵器。「积压问题的处理」「黑松山 A」
- 牛皮酒袋可灌清水；喝酒会醉，蒙汗药能下在酒里。「Fresh water supply loop (S6B only)」「青石村 B」
- 新角色的食物和饮水开局是满的（400 / 400）。「Fresh Food / Water Initialization」
- 赌场宝官照 ES2 八成赢；整堆押注赢了也只付两倍；没有婚姻。「绮云镇 3D」

**世界时间与重置**
- 菜单、交互窗口、战斗、换图时世界时间停住；菜单里玩家自己的忙碌照样倒数。「菜单窗口」「说话和交互」
- 玩家离开的地图在回来、重置或有人进出前一次补算到现在，不抽会话随机流；离开超过 3600 秒的部分直接算满；游走补算最多 12 步，邻图的人会走过来。「别的地图时间补算」
- 你不在时 NPC 最多回到 create() 造出时的数值。「别的地图时间补算」
- 冲着玩家来的 call_out 在离开地图时丢弃，师父的拜师答复对空房间说；风泉剑灵的吟诵等玩家回来，并存档。「茅山 B」「乔阴 C」
- 房间各按自己的时间表重置（`room_reset_seconds` 1800，MudOS 公式）：死的 NPC 重生，离家的回家，地上的东西没了才补。「NPCs talk and wander; rooms reset」
- 状态（毒、醉）在心跳上发作，战斗中和玩家昏迷时不走；忙碌也在心跳上消退。「Old Pine remainder B」「Busy wears off on the heart beat」
- 回复按 5 + random(10) 拍计数，关掉游戏的时间不算。「Player recovery / metabolism cadence (S5B only)」
- 玩家昏迷：醒来的时间照 damage.c 抽，黑屏只躺 3 秒，其间世界时间加速走完。「积压问题的处理」

**死亡与阴间**
- 要杀玩家的敌人会补刀；死后有死亡惩罚，玩家变成鬼魂，在鬼门关走阴间回阳。「Player unconsciousness and death follow ES2」「鬼门关 A」
- 尸体按世界时间腐烂（120 / 120 / 60 秒，最后东西散落），玩家自己的也一样。「尸体腐烂」
- 鬼魂看不见，阴阳眼（茅山道术）能看见。「乔阴 B」「鬼门关 B」

**存档**
- 开发版存档不保证兼容：不支持的文件拒绝，不删除；内容变动升 world revision，需要新游戏。「Pre-Cutover Development Save Compatibility」
- 战斗中、动作没做完、玩家昏迷或死亡途中、被押送时不能存档；忙碌照样存。「Native saves require a restart-stable gameplay boundary」「Busy is saved, not waited on」「Player unconsciousness and death follow ES2」「乔阴 D」
- 玩家的 set_temp() 标记、NPC 的记忆、地上的东西都存档；门的开关和房间计数器不存。「Save: the player's set_temp() flags」「乔阴 B」「Give, drop and put; shops and teachers on their NPCs」「Snow's inner rooms」
- 物品存完整状态（嵌套、堆叠、装备栏）；体重和负重上限是独立字段，继续时原样恢复。「Native item persistence preserves the complete represented domain state」「Player Body Facts and Native Continue」
- 召唤出来的观想虫、僵尸不存档。「茅山 C」「茅山 D」

**界面与设置**
- 菜单窗口：角色、武学、背包、任务、声望、百科、系统；系统页是真正的暂停。「菜单窗口」
- 手柄、键盘、鼠标、触屏并存，按键图标跟当前输入方式。「手柄」
- 左上状态卡（名字、菜单、精气神、状态、等待）；左下 toast 显示游戏自己的消息，6–14 秒后淡出。「The HUD: a status card and toasts」「说话和交互」
- 任务页「江湖见闻」只记已发生的事和 NPC 说过的话；百科只收见过的。「任务日志与百科」
- 引路链（新手链、雪亭驿的信、门房的来历）的最新条目在状态卡上多一行「目标」，条目记下时弹「【见闻】…」和「下一步：…」；设置「目标提示」可关。「新手链与当前目标」「雪亭驿的信」
- 新游戏开头盖一张 ES2 主题故事的卡片，继续才进世界。「开场卡片」
- 设置：战斗速度、受击闪红、击倒后（询问 / 直接了结）、目标提示、界面缩放（地图上的字不缩放）、语言。「手感：战斗」「了结 / 放过」「新手链与当前目标」「说话和交互」「Localization: the source text is the key」

**节奏开关（经典模式）**：`common/pacing.json`，不写就是 ES2 原值；套件按经典值跑（`Es2Pacing`、`TestFeel`、`TestAway`、`TestAlert`）
- `player_exp_gain` 3、`player_recovery_gain` 3、`quest_time_percent` 150、`npc_thirst` 10（经典 1 / 1 / 100 / 1）。「Pacing knobs and 卧龙岗's second」
- `player_wake_seconds` 3（经典 0）。「积压问题的处理」
- `reaction_beat_ms` 400、`trial_blow_ms` 700、`dim_fade_ms` 400；强盗的 `toll_attack_delay_ms` 2000。「响应性」「Pacing knobs and 卧龙岗's second」
- `hostile_alert_ms` 500（经典 0）。「进门一起上」
- `away_catch_up_limit_seconds` 3600、`away_wander_moves` 12、`away_neighbour_pulse_seconds` 30（经典 0）。「别的地图时间补算」
- `corpse_rot_seconds` / `corpse_bones_seconds` / `corpse_scatter_seconds` 120 / 120 / 60（就是 ES2）。「尸体腐烂」
- `milestone_rewards`、`catch_up_max_percent` 100、`staged_potential_cap`、`player_exercise_gain` 6、`training_dummies`、`bounty_board`（经典关 / 0 / 1）。「经验节奏」
- `room_reset_seconds` 1800、`combat_round_ms` 1000、`heart_beat_ms` 2000（就是 ES2）。「NPCs talk and wander; rooms reset」「One map runtime」「响应性」
- `feel`：换图淡入淡出、走路、气泡、菜单、战斗演出、`training_step_ms`、`corner_slide_px`（不写 = 0，没有演出）、`voxel_worlds_kept` 3（保留几张图的体素世界；0 = 全留）。「手感」「手感：战斗」「连续修炼」「固定俯视体素地图」
- 新游戏面板的「节奏」：经典把 `milestone_rewards`、`catch_up_max_percent`、`staged_potential_cap`、`player_exercise_gain`、`bounty_board`、`training_dummies`、`day_length_minutes`、`sky_weather` 一起按回 ES2，存进存档，开局后不改。「经典模式总开关」「昼夜」「天气」
- `day_length_minutes` 24（就是 ES2；owner Q3 默认也用 24）。「昼夜」
- `sky_weather` 开（经典关：ES2 从不显示天色，永远晴）。「天气」

**各区域的修复与改动**（细节在各区域条目和 `*_CONTENT.md`）
- 雪亭镇：密室不会把人关在下面；玩家邮件不做；武馆木人和悬赏榜是新内容；店小二的老鼠差事和烤鸡腿、魏无极指向谷场的一句、杜宽托送到绮云镇的信是新内容。「Snow's inner rooms」「Snow's south road and shops」「经验节奏」「客栈的老鼠」「雪亭驿的信」
- 老松岭：只看的描述做成地标；cliffside ↔ pine1 双向；寨门每关一次只补回少了的喽罗。「积压问题的处理」「Old Pine remainder A」
- 卧龙岗、绮云镇：新来的人走得过强盗；陈剑秋拒收的东西退回；朱鸿雪的任务和赌场。「Pacing knobs and 卧龙岗's second」「Modern fixes: ES2 behaviour that reads as a bug」「绮云镇 3C」「绮云镇 3D」
- 水烟阁：正厅的师父照 class 目录那份放；红衣武士的 accept_kill() 生效。「水烟阁 A」「乔阴 A」
- 青石村：玉佩和蒙汗药按代码本意能走通；绝地可以「放弃」回客栈。「青石村 B」「青石村 A」
- 晚月庄：sroad1.c 修好；第二密室的八卦图谁都能跳「西出阳关」出来。「晚月庄 A」
- 山烟寺：前院的护寺武僧补上；船夫收两文钱渡江。「山烟寺 A」
- 乔阴：县衙的抓捕修好；树王坟的洞能下去；鬼魂看不见。「乔阴 A」「乔阴 D」「乔阴 B」
- 天驼关：竹林道修好；大队长的过路钱累计到 30 两。「天驼关 A」「天驼关 C」
- 玉螺湖村：湖心能划船、潜水；还瓜钱要付 60 文，抓人的瓜农倒下就能走。「玉螺湖村 A」「玉螺湖村 B」
- 京师：令牌照 ES2；地下密室的石阶从下面也能开。「京师 A」「京师 B」
- 黑松山：进山的路修好；小娟只救一次。「黑松山 A」「黑松山 B」
- 鬼门关：阴间要自己走回来；路的尽头补了原文缺的句子。「鬼门关 A」

## 老松林的林径与藏起来的寨门 (owner, 2026-10-28)

- **ES2:** pine1–pine7 七间文字一样的「松树林」，出口每次 reset 随机换（pine1、2、4、5、6、7 在 reset() 里、
  pine3 在 create() 里 `random(5)+2`），离开时写「你实在弄不清楚方向……就是这个方向吧」；几条写死的边是骨架
  （pine1 west→pine4、pine4 north→pine5、pine5 north→pine6、pine6 west→pine7、pine7 southwest→cliffdown、
  pine2 east→keep1）。9B1 把它译成一个固定迷宫（一个环、两条死路、一条绕远到 cliffdown）。keep1 叫「老松寨
  秘密入口」，但 pine2 east 是一条普通出口，谁走到都进得去。
- **Owner (2026-10-28):** 进了林间小路后这段太绕，新玩家被第一张悬赏送到老松林空地，很容易走进去迷路；随机出口是
  ES2 在文字里把林子撑大的办法，是故弄玄虚；从现代游戏的角度，「藏在林子里」也不必用这种方式实现。
- **We:** 崖上只有一条踩出来的林径：栈道顶往东到一丛灌木，往南到悬崖边（原文的死路，很短），往北进深林
  （pine3–6），绕到 pine7 的狼狗，再下到 cliffdown，从那里爬 cliff2 回栈道脚。没有环、没有死路。pine2–6 的
  房间 ID 仍挂在原来的三个区块上（pine_entrance / pine_deep / pine_cliff_edge），「松树林」的原文在栈道顶显示
  一次（相邻同名房间不再重复），「弄不清楚方向」那段离开提示不要。老松寨的路藏在灌木后：一扇门
  `oldpine.pine.thicket`（`found_by`「老松寨的小径」，不能用手开，开前不画出口箭头）；旁边的地标「刀痕」
  （`find_way`，用的是 epath1.c 原文里树干上的刀痕）用一次给玩家这枚印记、开门并记一条见闻「树上的刀痕」；印记
  存档，之后再进这张图门就是开的，再用只说「刀痕指的就是灌木后面那条小径」。空地西口加一块原生路牌（西 雪亭镇 ·
  东 小石桥 · 南 下坡道），原文的告示牌不动。pine1 的两个土匪照旧站在去灌木那条路边的洼地里，绕得开。
- **Global (data):** 门的 `found_by`（一枚印记；这样的门 `open` false、`operable` false，由持有印记的玩家进图
  时打开）；地标策略 `find_way`（`mark`、`action`，消息 `found` / `again`）；体素门样 `thicket`。
- **没有经典模式开关：** 地图只有一张，迷宫不能按开关保留。藏的是路不是景：俯视镜头里灌木后面的林地、keep1 门前的
  四个喽罗照样看得见，门开之前走不过去、也没有出口箭头。见闻「树上的刀痕」按 `chain_percent` 10% 计历练（50，和
  第一次到一处地方一样，不按整条故事链的 500）。
- **Save:** world content revision `SOURCE_ENTRY_OLDPINE_TRAIL_V1`；旧开发存档要新游戏。
- 取代「Random Pine room exits become one fixed continuous maze」（移入 DECISIONS_HISTORY）。

## 天气 (美术优化 G, owner 批准 2026-10-27; Q3 做云量和晨雾, 雨先不做)

- **ES2：** `adm/daemons/natured.c` 第 8 行声明了五句天色 `weather_msg`——「天空中万里无云」「几朵淡淡的云彩妆点著清朗的天空」
  「白云在天空中飘来飘去」「厚厚的云层堆积在天边」「天空中乌云密布」——整个 mudlib 只有这一处，从没用过：玩家从来看不到，也没有雨雪。
  雾只在房间文字里：水烟阁 `wpath3.c`「每当清晨山谷中的晨雾慢慢飘起」、`clifftop.c` 的云雾远景；泓水江岸（`d/sanyen`、`d/sunhill`）原文没有雾字。
- **我们：** 五句原样记在 `common/day_phases.json` 的 `sky_levels`，让它真的出现。`SkyState`（`game/core/world/`）记云量 0–4，
  每 2–4 游戏小时（120 + random(121) 分钟，自己的一条随机流，可注入）换一档，每次只走一档、到头折回，不会从万里无云一步跳到乌云密布；
  新游戏从 1（几朵淡淡的云彩）开始、三小时后第一次变；和 `DayClock` 在同一处推进，打架、菜单、转场时一起停。
  文字：室外房间的描述在当段 `desc_msg` 之后再接当句（「太阳正高挂在东方的天空中。天空中万里无云。」两句各带句号）；室内没有；换档不提示（ES2 没有，画面自己会变）。
  画面：体素光照加 `cloud` 量（0 / 0.15 / 0.42 / 0.72 / 1，换档时约 20 真实秒过渡）：云多时日光压到一半、变白、影子变软（`shadow_blur`），
  天色和环境光偏向本区 `light.json` 的 `overcast`（雪亭镇冷蓝灰、天驼关土黄灰、水烟阁云海白……，没写用默认灰青），环境光稍抬，
  乌云密布最暗但路看得清；夜里云也遮月，阴天色按夜的程度压暗。白云飘来飘去的两档（2、3）有云影：一片低频噪声随时间漂过，按玩家位置采样轻调日光，
  整屏一明一暗，没有硬边。室内不受云影响，灯只看昼夜。
  晨雾：水烟阁山里（`waterfog/voxel/mountain.json`）的雾写成帧表的深度雾（起点在人物之后，白天帧密度 0），黎明有、日出末渐薄、白天起没有；
  不用高度雾（夜里会把整图抹黑），深谷和裂谷原有的薄雾不动。泓水原文没写雾，不加。老松林深谷的雾不动；阴间还没有体素。
  存档：根节点必写 `sky_level`（0–4）和 `sky_minutes_left`（0–240）；schema 3 → 4，旧开发存档拒读（开发期不保证兼容）。
  经典模式：配速开关 `sky_weather`（和 `day_length_minutes` 并列，`PacePresets` 经典一起关）；关 = 云量永远 0、描述不接那句、画面永远晴。
- **不改：** 昼夜的八段和五帧、各区已调好的昼夜色、NPC / 门 / 刷怪 / 战斗、洞穴和室内。雨、雪、风都不做（owner：看了云和雾再定）。
  水洼（`weather` 的 `water`）仍是静态的，不随云量变。
- **为什么：** 五句是 ES2 自己写好却没接上的世界感，接上就有了天气的层次；今天的 RPG 天色会变，但变化要慢、要连续，不打断玩家。
  owner 要饱和、有层次，所以每区阴天各有自己的灰，不做整片发灰；雾只放在原文写了雾的地方，路面保持清楚（美术规划 §1）。

## 昼夜 (美术优化 B, owner 批准 2026-10-27; Q3 一天 24 分钟, Q4 加原文两句, Q5 设置三档)

- **ES2：** 昼夜只是文字。`adm/etc/nature/day_phase` 把一天分八段（微曦 240、日出 120、上午 180、正午 180、下午 180、
  傍晚 180、夜晚 120、午夜 240 游戏分钟，共 1440），`natured.c` 一游戏分钟 = 一真实秒地轮转（一天 24 真实分钟），
  每段开始给室外的人一句 `time_msg`，`look.c` 在室外房间（`set("outdoors")`）的描述后接当段的 `desc_msg`。没有任何画面。
  正午的 `event_noon`（法力消散）是法术规则，另案，这里不碰。
- **以前：** HUD 一个「切换夜景」按钮，只有白天和夜晚两帧，全区同一个夜色，不跟时间走。
- **现在：** 八段原样记在 `game/data/common/day_phases.json`（长度、两句原文、对应的画面帧）；`DayClock` 跟世界时钟一起走
  （打架、菜单、转场时停），新游戏从上午（6:00）开始；一天多长是配速开关 `day_length_minutes`，ES2 的 24 也是默认（owner Q3，
  觉得太快再调），经典模式固定 24。
  画面：体素光照从两帧变成五个关键帧——黎明（微曦 + 日出）、白天（上午 / 正午 / 下午）、黄昏（傍晚）、夜（夜晚）、深夜（午夜）；
  每帧在自己那几段的中间保持，到段界前后各最多 60 分钟线性过渡，段切换不跳。灯、窗光、萤火、月光斑、遮挡的夜色都按帧的
  「夜的程度」走（黎明 0.5、白天 0、黄昏 0.45、夜 1、深夜 1），灯从黄昏开始亮起；日光方向黎明在东、黄昏在西、夜里是月亮。
  每区一套光 `game/data/<区域>/voxel/light.json`（`outdoor` / `indoor` 两节，十个区域各按美术规划 §2 包 B 的表写第一版），
  单图的 `light` 只覆盖写了的帧：写成帧表的键按帧合并，旧的 `[白天, 夜晚]` 两值照常能读（当作白天和夜；深夜当作夜，
  黎明、黄昏按帧的时刻插值）并整键覆盖区域默认，所以 95 张图不用一起改。洞穴和寒谷保留自己的两值。
  文字：进入室外房间和「观察」时，描述末尾接当段的 `desc_msg`（原文，带句号）；段开始的那一刻室外的人收到一行 `time_msg`
  （日志 + 一条提示），室内没有，菜单里时间不走所以不会刷屏。
  设置页加「昼夜：跟随游戏时间 / 一直白天 / 一直夜晚」（设置文件第 7 版，旧文件读作跟随），立刻生效，HUD 的按钮去掉；
  左右视角按钮不动。
  存档：根节点必写 `day_seconds`（0–86399），读档从那一刻接着走；存档 schema 2 → 3，旧开发存档拒读（开发期不保证兼容）。
- **不改：** 任何按时刻的规则——NPC 作息、门、刷怪、战斗、法术的正午规则。画面和两句文字只跟着时间走。
- **为什么：** 今天的 RPG 天色跟时间走、灯在黄昏亮起，玩家不按按钮；ES2 的八段和两句是现成的世界感，加画面就够了。
  owner 喜欢黄昏和饱和色，所以每区的黄昏单独调，不做整片发灰。

## 经典模式总开关 (前两小时 E, owner 批准 2026-10-26; Q6 现在做)

- **ES2：** 没有难度或节奏的选择；本项目的每个节奏开关各自留着 ES2 原值作经典值，但没有一处能一起切（STATUS 的已知问题）。
- **我们：** 新游戏面板性别下面一行「节奏：现代（推荐）/ 经典」。经典 = 把 A2 的六个进度开关一起按回 ES2：`milestone_rewards` 关、
  `catch_up_max_percent` 0、`staged_potential_cap` 关、`player_exercise_gain` 1、`bounty_board` 关、`training_dummies` 关
  （`PacePresets`，和套件用的 `Es2Pacing.use_without_progression()` 同一套）；手感类（淡入淡出、气泡、战斗速度、连续修炼）不动。
  选择存进 `CharacterState.pace`（存档可选字段，旧存档读作现代，不升修订号）；会话建世界前先按它设好目录的 pacing（木人、悬赏榜
  从第一张图起就对），会话结束时还原。开局后不能改：设置页没有这一项，角色页「修为」里写明「节奏：经典（开局选定）」。
- **为什么：** 活侠传的教训——难度要在第一屏选；经典的玩家一开始就知道自己玩的是原来的数。中途切会让木人、榜、历练账本对不上。

## 刘安禄的揭露 (前两小时 D, owner 批准 2026-10-26; Q4 揭露照 ES2 留在 20000)

- **ES2：** `d/snow/npc/guard.c` `ask_me()`：问「刘老三」「血手刘三」时，玩家 combat_exp 不到 20000 没反应（ask.c 的「没听说过」）；
  够了则 `random(10) < 5` 说「我...不知道！」，否则变身：title 野羊山寨二寨主、nickname 血手刘三、apply attack 70 / dodge 50 /
  parry 60 / damage 20、combat_exp 50000、aggressive、pursuer、vendetta/authority、杀气 10000、闲聊和战斗闲聊都改成游走，
  带一本《残破刀谱》，对屋里所有人 kill_ob，记 revealed；已揭露再问：「老子就是血手刘三，血手刘三就是你老子！纳命来！」并动手。
  线索散在魏无极「刘安禄」、柳淳风「刘安禄」、樵夫的闲聊、刘安禄自己的战斗闲聊里。
- **我们：** 照移植。揭露走 NPC 的 mood（`moods.revealed`，`lasting`：房间重置不收回，和 ES2 的对象变量一样；title、nickname、
  applies 含 combat_exp +30000、aggressive + hunts_player、游走的闲聊和战斗闲聊、带刀谱），打听规则新增 `asker_exp_at_least`、
  `npc_flag`、`mood`、`attacks`。杀气 10000 和 vendetta/authority 没有原生读者，不记（偏离）。问之前先确认一次
  （「重要或致命的选择先问」：话题的 `confirm`），取消不问。《残破刀谱》照 `blade_book.c` 移植（研读刀法到 40）。
  引路链「门房的来历」把线索连起来：魏无极 → 柳淳风（了结，100% 历练；`next` 到「问问柳淳风」为止）；樵夫的闲聊、刘安禄打架时
  说漏的嘴、揭露本身各记一条。日志新增 `chat` 条件：NPC 在屋里或打架时说出含某几个字的一句，当场记下。老松岭土匪老大那句
  「自从刘老三洗手不干以后」不在链里：他在 ES2 里从不出场（ROADMAP）。魏无极「你带我去见他」的跟随在 LPC 里是死代码，不做。
- **为什么：** 前两小时能埋的最长一根钩子：玩家先知道门房不简单，变强后回来对质才有回报；对质本身不提前，柳淳风的动机留给圣经。

## 雪亭驿的信 (前两小时 C, owner 批准 2026-10-26; Q3 收件人陈剑秋、一两脚钱)

- **ES2：** 杜宽只有「驿站」一句和多人邮件（`send_mail` / `receive_mail` 发信箱，没移植）；驿站房间原文说官府信差因野羊山
  匪患改走飞鸢栈道，驿站索性接百姓的信，木牌上百姓书信每通十文。没有任何送信差事。
- **我们：** 杜宽多两个话题【新增】：「送信」四条规则——没接：给一封「雪亭驿的书信」（原生物品 `native:snow/letter_to_chen`）
  并记 `雪亭驿的信`，台词说明收件人、脚钱和卧龙岗的强人；接了没送：「信送到了么？陈镖头的镖局就在绮云镇街上」；送到了：给一两银子
  （`gives` 银子，记 `脚钱`）；付过：「往后有信，还找你」。「悬赏」一句指门外的榜。「驿站」原句后接「官府的信差都改走飞鸢栈道了，
  咱这儿如今只剩百姓的信」。陈剑秋的 `accept_object` 最前面加一条：收这封信（按物品蓝图），记 `信送到了`，说「哦，雪亭驿的信。
  有劳$RESPECT，替我谢谢杜驿长」；别的东西照旧。引路链「雪亭驿的信」三步（接信 → 送到 → 拿钱，了结算 100% 历练）；新手链学会
  封山剑法后的下一步改指雪亭驿。
- **为什么：** 前两小时要有一件把玩家推出雪亭镇的事：路上经过悬赏榜、卧龙岗的强人（走得过）、第一次到新区域的历练，到了绮云镇
  先认识可拜的镖局。信丢了（扔掉、死了没捡回尸体）杜宽不再给第二封，链就停在那里——开发版先这样，试玩看要不要补。

## 开场卡片 (前两小时 B, owner 批准 2026-10-26; Q2 加「那少年，便是你。」)

- **ES2：** 登录后玩家直接站在饮风客栈里，没有任何开场文字；主题故事（白衣大内高手、黄石隘口、客栈里十四岁的少年和店小二、
  岚城与旋芒宝剑）在 `doc/help/theme`（Annihilator，1994-11-17），要玩家自己 `help theme` 才看得到。
- **我们：** 新游戏进世界的第一刻，世界上盖一张可「继续」的卡片，内容是 `help theme` 的原文节选（第 2–6、8–10、12 段，
  一字不改；Big5 丢的「神□得紧」按 text_replacements 的惯例定为「神秘」），末尾加一句原生的「那少年，便是你。」
  （`common/opening.json`，`OpeningDefinition`）。卡片在时世界时间停住（`hold_world_time`，店小二的招呼等卡片放下才来）；
  只在新游戏出现，存档不存（卡片盖着时不能存档）。读档和测试里的 SOURCE_ENTRY 会话没有它（宿主 `request_opening_card()`）。
- **为什么：** 玩家第一眼得知道自己是谁、在哪、这个世界在忙什么；原文写的正是这家客栈、这个店小二和这个少年，不新造正典。

## 客栈的老鼠 (前两小时 B, owner 批准 2026-10-26)

- **ES2：** 饮风客栈二楼有六只老鼠（`inn_2f.c`，`rat.c`：dodge 120、咬 20、没有 combat_exp），谁也不提它们；店小二只招呼和卖东西
  （`vendor_goods`：dagger、wineskin、dumpling、chicken leg）。原生的店小二此前只卖酒袋和包子，`obj/example/chicken_leg.c`
  没移植。
- **我们：** 店小二多了两个打听话题「老鼠」「楼上」【新增】，三条规则：没清过——「唉，别提了。楼上几间客房闹老鼠……小店请您吃顿热的」；
  清过没谢——「哟，可算清净了！来，刚烤好的鸡腿……」加一句「鸡腿骨头别扔，东街那两条野狗见了骨头就跟人走，怪得很」，
  给一根烤鸡腿并记 `店小二谢过`；谢过以后只剩骨头那一句。六只老鼠全部倒下（打倒或杀死）时玩家得 `客栈老鼠` 标记
  （spawns.json 的 `cleared_mark`，`WorldSpawnClearings` 在日志节拍上看；房间重置让老鼠回来，标记不退）。
  `obj/example/chicken_leg.c` 照原文移植（兵器兼食物，吃完留「啃得精光的鸡腿骨头」，骨头能喂野狗），店小二的货单补成
  ES2 的四样。老鼠本身不改：exp 0、远不如你、不给历练。
- **为什么：** 前十分钟要有第一架，而且输不了；差事给上楼一个理由，鸡腿把 `dog.c` 的跟随彩蛋说出口。
  魏无极「学费」末尾也加了一句【新增】「手头紧？街东头的谷场正缺短工，干一回给一两。」——五两学费和谷场打工在 ES2 里从没人放到一起说。

## 新手链与当前目标 (前两小时 A, owner 批准 2026-10-26; Q1 目标行独立、可关, Q5 打坐小额历练)

- **ES2：** 没有任务追踪，也没有任何「下一步」；玩家靠 `help`、问人和试。
- **我们：** 任务页照旧只记已发生的事（「任务日志与百科」）。另加：
  - **引路链**（`journal.json` 里 `guide: true` 的链，现在只有「雪亭镇的头几天」`snow.newcomer`）：条目和别的链一样记「发生了什么」，
    另有一句 `next`；状态卡多一行「目标：…」，内容是最新一条未了结引路链条目的 `next`（`JournalLog.objective()`）。
    非引路链不许带 `next`（加载报错）。设置里「目标提示」可关（默认开，`ObjectiveHints`，设置文件第 6 版；关掉只剩任务页）。
  - 日志条目记下时在消息和 toast 里说一次 `【见闻】<条目>`，引路链条目再接一句 `下一步：<next>`（目标提示关则不接）。
  - 新的 `when` 条件：`milestone`（历练账本有某项）、`force_at_least`、`exp_at_least`、`skill_at_least`、`family`，都只读 CharacterState。
  - **打坐练到 N 再停**：连续打坐旁选「不限 / 练到 10 / 25 / 50 / 100」，上限每涨一点不再停下，到目标才停（`TrainingRun.target_maximum`）；
    进度写「上限 37 → 50，还差 13」。
  - **打坐的历练**（Q5）：max_force 第一次到 10 / 25 / 50 各给一次历练，阶段单位的 25%（`progression.json` `force` 25、`force_milestones`），
    走 `milestone_rewards` 开关（经典关）。新手链了结的历练按 100%（别的链 500%）。
  - 角色页加「历练」小节：已得的历练倒序列出（最多 8 行），出生地写作「生在雪亭镇」。
  - **拜师卡片**：师父收下玩家时盖一张卡（「柳淳风收下了你。你成了封山剑派第十四代弟子。往后向师父请教……」），继续才走。
- **为什么：** 前两小时的问题是看不见目标和反馈，不是内容不够；把已有的系统摆到眼前，一条可关的线，不锁玩家。
  新手链的 13 条：醒来 → 楼上 → 老鼠 → 谢过 → 拜师 → 基本剑法 → 胜过武馆弟子 → 内力 10 / 25 / 50 → 封山剑法 → 揭悬赏 → 到绮云镇（了结）。

## 老松林按原文方位排布 (owner, 2026-10-25)

- **ES2:** clearing.c's exits send `north` to spath1, but its own text has three ways east, west
  and south with the sign by the south one, and spath1-4 describe a slope south of it, 北高南低;
  cliffside and cliffdown each have a cliff to the west: the gorge's, climbed up from riverbank1
  by cliff1 to the cliffside (it has no way down), and the one climbed down by cliff2 to epath3
  below the bridge; epath3 has a broken plank road up the cliff. Drawn by the exits alone, the slope ran back north beside the way in, and the climbs
  from the maze's far west edge landed on the other side of the map.
- **We:** the exits are kept, the places are drawn where the rooms say they are: the slope south
  of the clearing, the sign by its head; the gorge running south from the falls under the
  bridge; the pine maze and 老松寨 on the high ground east of it, cliffdown on its west edge
  straight above epath3 and the cliffside on the same edge over the gorge. The maze's native way
  in (B2's link, no ES2 exit) moves from the clearing's south side to the plank road up from
  epath3 into pine1; the clearing has only its three ways. The maze keeps its structure (a loop,
  two dead ends, one way on to cliffdown). pine1's two bandits, who in ES2 stand where every
  way into the maze passes, stand in a hollow by the way to the keep: one can go round them to
  the deep maze or the cliffside (owner, 2026-10-25).
  World revision SOURCE_ENTRY_OLDPINE_RELAYOUT_V1.

## 地图尺寸以体素视角为准 (owner, 2026-10-25)

- **以前:** 2D 地图的路、台阶、院子和门洞按俯视色块的比例画；画上体素的建筑、岩石、栏杆和人物之后，路被南边
  的东西挡住，路上站一个人就过不去，野外绕不开敌人。
- **我们:** 地图尺寸以体素视角下好走为准，不保留原 2D 比例。路至少能两人并排、路中间站着人也能从旁边绕过
  且不碰到对方；野外山路要能在敌人的接触（有主动攻击的 NPC 时还有察觉）范围外绕过去；原文说窄的小径、窄巷
  可以比大路窄，但仍要能绕过一个人。路和南边的建筑、岩石之间留空隙，南侧的东西压低（悬崖 `south_rise`、
  树 `bands`/`south_reach`），仍挡的地方用剖开的矮墙。NPC 站位放在路边、院子边。加宽是布局改动：区域、
  传送口和门保留，不打通原本不相连的地方，写死的坐标随新尺寸更新。规则全文在 `docs/design/美术规划.md`
  §2「路和空间」。水烟阁（2026-10-25）是第一个照此放宽的区域；之前做完的雪亭镇、卧龙岗和绮云镇、老松林、
  野羊山随后也放宽（`phase/road-widening`，两侧有房的街约 320 像素，整排房子往外挪）。原文守路的不必
  绕得开：老松寨寨门和寨里的守卫、野羊山山路转角那伙强盗、迷阵里的狼狗、山坡死路上的三个强盗（老松林迷阵口
  两人原也在内，owner 2026-10-25 改成绕得过，见「老松林按原文方位排布」）；其他主动攻击的（雪亭镇的疯狗）
  站在路边，绕得过它的察觉圈（`map_road_room_test`）。

## 首发只做桌面 (owner, 2026-10-24)

- **之前：** 桌面和手机一起做；PR #161 为手机的帧率给体素视图加了一套手机画质档（低分辨率渲染、少阴影、
  只点最近的灯、草丛减半），另有单遍遮挡物和同色合批。
- **owner 决定：** 第一版只发桌面端。手机版等发售后看评价再决定要不要移植。
- **所以：** 画面不为手机帧率减配，各区域的体素地图按桌面定丰富程度；不改画面的优化（合批、少画看不见的
  东西）照常可做。PR #161 不合并，转成草稿封存；分支 `phase/mobile-voxel-perf` 保留，移植手机时从那里
  接着做（先合入最新 main，再在手机上重新量帧率）。CI 照旧跑 Android 和 iOS 两个必需作业（AGENTS.md
  「Git and CI」），只当构建门槛，手机帧率不再是区域的验收条件。

## 进门一起上 (A6, owner 批准 2026-10-24; Q1 整片区块, Q2 单个也给提示, Q3 通用喊话)

- **ES2：** 玩家进房间时，房里每个 NPC 的 feature/attack.c `init()` 各判一次（hatred → vendetta →
  aggressive → berserk），判中就 combatd.c `auto_fight()`：`call_out("start_"+type, 0)`，注释说这一拍是
  给玩家「从凶徒中间溜过去」的机会；`start_*()` 时玩家已不在同一房间就作罢。所以同一房间的凶徒全部出手；
  aggressive 和 vendetta 一声不出（只有 kill_ob 的「看起来X想杀死你！」），hatred 喊 catch_hunt_msg。
- **以前：** 只有 9 个区块（老松寨三间和水潭、野羊山 mroad4、卧龙岗、刑房×2、冰龙厅）用
  `combat_entry: complete_set`，户外只算圈子碰到玩家的；其余是一个打完再来下一个（京师六门、乔阴三门、
  巨蟒池、古墓、福林楼西院、奈何桥、水烟阁二楼等约 19 处）。
- **我们：** 一条规则，`combat_entry` 删除（写了就是 unknown field）。「一伙」= 此刻在玩家所在区块里、
  见人就打的 NPC（hatred、vendetta、aggressive、买路钱到点的强盗；还在等买路钱的强盗跟着上）：其中一个
  还没和玩家打过、够得着玩家（室内同屋，户外它的圈子），整伙进一场战斗，远近都算（owner Q1）。
  518 个区块里 508 个就是一个原房间；合并的 10 个里没有住着两个原房间的凶徒（`hostile_gang_test`
  核对）。hatred 的人只它杀、玩家还手，并喊 catch_hunt_msg，其余互杀，和以前单个出手一样。玩家自己的
  攻击也带上这一伙。berserk 不算在内，照旧各自掷骰、两个人打（#68）；路人、同门、没仇的官兵、玩家这边的
  召唤物和跟班都不算。
- **偏离：打过的人等玩家离开这块地方再回来。** 打过（任何一场有玩家的战斗）的人，玩家还在它的区块里就
  不再先出手，离开再回来才重新察觉（ES2 的 init 是进房间时跑）；户外以前走出圈子再进来就算，现在要
  离开区块。一伙里有新来的人出手时，打过的照样跟上。
- 战斗中世界停住，没人能走进门，所以「战斗中进门的人加入」碰不到，不做。
- **偏离：出手前的提示一拍**（`pacing.json` `hostile_alert_ms` 500，经典 0 = ES2 的 `call_out(0)`；
  B，owner Q2：单个凶徒也给）：一伙察觉玩家时，第一个察觉的人（够得着的人里离玩家最近的）头顶冒红
  「！」并喊一声，同伙名字变红、转身面向玩家；这一拍过完，此刻区块里见人就打的人一起扑上（这一拍里
  进门的也算）。喊话（owner Q3）：hatred 喊 catch_hunt_msg（开打时不再重复）；否则用它自己 ES2 的
  chat_msg_combat 里带「道：」的一句；都没有就用原创的「X发现了你，大喝一声！」；野兽不说话，只冒「！」，
  消息栏记「X发现了你！」。这一拍里离开区块就躲开了，不记仇（ES2 的 `start_*()` 也是玩家不在同一房间就作罢）；
  菜单打开时世界时间停住，这一拍也停；玩家自己出手就立刻开打；买路钱的强盗已经喊过、等过 2 秒，不再加这一拍。
  不存档。suite 一律用 0（`TestAlert`），`hostile_alert_test` 开 500。

## 经验节奏 (A2, owner 批准 2026-10-24; Q1 分档潜能上限, Q2 打坐约 6 倍, Q3 放过也算)

- **ES2：** combat_exp 只从 combatd.c `do_attack()` 来：打中、躲开或挡住比自己强的人才加 1（潜能只在
  打中时加），杀人不给；1000 以上才有朱鸿雪的任务。npc.c `accept_fight()` 里 friendly 的 NPC 从不切磋，
  雪亭能练的对手只有武馆弟子、李火狮（入门后）和醉汉。潜能未用最多 100。exercise.c 每次打坐的内力
  `kee × (基本内功 + 根骨) / 300`。×3 经验下 150→1001 仍要 6–12 小时，打坐到内力 50（封山剑法的
  门槛）要 1.8–2.4 小时。
- **我们（pacing.json 开关，经典值 = ES2，`tests/support/es2_pacing.gd` 用经典值）：**
  - `milestone_rewards`（经典 false）：一次性的「历练」奖励，`common/progression.json` 定档：第一次切磋
    胜过某种 NPC（切磋由玩家那一击结束，按 NPC 定义算一次）、第一次击败名单上的有名人物（切磋胜过、
    打倒或杀死都算，替代切磋那份）、了结一段任务链（journal.json 的 `final` 条目）、读通一本书（研读把技能读过书的 max_skill）、
    第一次到一个区域（出生地不算；鬼魂在阴间不算，死亡不给奖励）和名单上的名胜。数额是玩家当前阶段单位的百分之几，潜能是经验的一半；
    「远不如你」的对手不给也不记账。账本 `CharacterState.milestones` 存档。
  - `catch_up_max_percent`（经典 0）：落后补偿。区域有 `recommended_exp`（world.json）；经验低于所在区域
    的推荐值时，战斗涓流和历练奖励的经验、潜能多「差距 / 推荐值」这么多，最多 100%，赶上就是 0；零头
    存在 `gain_carry` 里，不抽随机数。朱鸿雪的任务奖励和 NPC 不受影响。角色页写明。
  - `staged_potential_cap`（经典 false = 100）：潜能未用上限按阶段（100 到 30000；一份奖励按加完经验后
    所到的阶段算），战斗和朱鸿雪的任务奖励共用；被截时明说（朱鸿雪的任务奖励在经典 100 下也说），战斗把潜能打满时也说一次。
  - `player_exercise_gain`（经典 1）：打坐所得内力 ×6；得 0 的一次仍是 0，瓶颈不变。模拟：根骨 30 时
    内力 0→50 约 23–25 分钟（经典 108 分钟），根骨 20 约 47 分钟。
- **为什么：** 今天的玩家不会为一个门槛磨 6 小时；只调倍率解决不了「附近没有更强的对手」。原公式一行
  没改，只在它给出的数上加开关。
- **模拟：** `tests/sim/exp_pacing_sim.gd` 按 `tests/fixtures/exp_pacing_route.json` 的路线在真实 session
  里切磋、请教、打坐、走故事链；`exp_pacing_sim_test.gd` 是回归（1001 在 60–130 分钟，打坐 18–28 分钟，
  经典无历练）。PR A 路线三个种子 82–115 分钟到 1001；封山剑派弟子约 62 分钟内力到 50。
- **PR B，新内容（数据在 `game/data/native/`，`legacy_source` 写明 native）：**
  - `training_dummies`（经典 false）：淳风武馆教练场五具木人（初阶到五阶，300–6000 经验），只能切磋
    （攻击被拒，木人随时应战；杀气发作、天邪虎啸和偷窃都不会把它卷进生死战），经验只照 combatd.c 原公式
    给：玩家比它强了就不再给，刷不爆。木人的天赋写死，建世界时不抽随机数，原有 NPC 的抽签不变。
  - `bounty_board`（经典 false）、`bounty_refresh_seconds` 600：雪亭驿门外的悬赏榜。同时贴 3 张，按玩家
    经验分 5 档（流窜毛贼到杀人魔头），出没点 7 处轮流（不抽随机数）；一次只能揭一张；做完或放弃的那张
    600 秒游戏时间后才补（第一次看榜时才贴出来，没看过的榜不进存档）；玩家长了一档，没揭的榜换成新档；恶人「远不如你」就不贴。走进出没点，恶人从
    路旁跳出（召唤式 NPC，不进存档，读档后再走进去会再出来）。玩家亲手杀死或「放过」都算完成（Q3：放过
    = 押送官府，不加杀气、不计杀人数，打完后押走）；奖励是阶段单位的 120%（历练，可重复，不记账）加
    该档赏银。任务日志有「官府悬赏」一链。
- **模拟（PR B 路线，加木人和悬赏）：** 三个种子 103–111 分钟到 1001，135–138 分钟到 2500；1001 之后的
  平台由悬赏接上。恶人的经验在本档下沿（100、400、1000、2500、5500），第一张悬赏不是赌命；模拟角色学得
  少，后几档偶尔会把它打死（真实玩家这时技能更高）。

## 产品定位 (owner, 2026-10-23)

- **之前：** AGENTS.md 的使命是「重建经典 ES2」——默认忠实，每处改动都是一条要 owner 单独同意的偏离；
  节奏开关的默认值必须重现原作。
- **owner 决定：** 这是一款**以 ES2 为底子的现代武侠 RPG**（「这个游戏毕竟是现代游戏」）。ES2 的世界、
  人物、物品、武功、门派、任务和原文仍是地基；会让今天的玩家却步的规则、节奏和表现可以改；世界的空白
  可以按批准的计划补新区域、门派、人物和任务。
- **规则（AGENTS.md「Mission」「Sources」「Changing ES2」）：** 计划先给现代做法，ES2 的做法放在旁边；
  任何改动都不悄悄做，每处在本文件记一条；移植来的公式不就地改，改动走数据开关，开关留 ES2 原值作
  「经典模式」，默认用商定的现代值；批准的计划之内不再逐条问，改变方向的事（系统设计、区域故事、删
  ES2 内容）仍先问 owner。新内容的数据标明出处，和 ES2 内容分得开。
- **已有的开关不追溯改动：** 现有 pacing 等开关的默认值照旧，各自在以后的包里按这条重新商定。还没有
  一键切回 ES2 的「经典模式」总设置，需要时另做。

## 尸体腐烂 (owner 批准 Q2, 2026-10-23)

- **ES2（obj/corpse.c）:** 死后 120 秒 decay(1)：「X的尸体开始腐烂了，发出一股难闻的恶臭。」，改名
  「腐烂的尸体」，不再 is_character（身上穿的东西脱不下来）。gender 的 switch 没写 break，所以永远不会叫
  「男尸 / 女尸」。再过 120 秒 decay(2)：「…被风吹乾了，变成一具骸骨。」，改名「一具枯乾的骸骨」，id 变成
  skeleton，不再 is_corpse（化尸粉、驱尸都找不到它），但里面的东西还能拿。再过 60 秒 decay(3)：
  「一阵风吹过，把…化成骨灰吹散了。」，里面所有东西掉到房间里（穿着的也一样），骸骨销毁。call_out 不管
  房里有没有玩家都会跑。
- **我们:** 照 ES2。按世界时钟上的死亡年龄算阶段：玩家所在的图每拍推进；别的图在补算时推进（「别的地图时间
  补算」），推进时不出声。掉出来的东西落在尸体躺的地方。名字、详情（腐烂和骸骨阶段多一句 corpse.c 的
  long）、附近列表、搜刮面板、化尸粉按钮都按阶段显示。玩家自己的尸体也一样腐烂，东西会落在地上。
- **开关:** `pacing.json corpse_rot_seconds / corpse_bones_seconds / corpse_scatter_seconds`，不写就是
  ES2 的 120 / 120 / 60；哪一段设成 0，尸体就停在前一阶段（第一段为 0：尸体不腐烂，即以前的行为）。
- **存档:** 尸体记录加可选的 `age_ms`（死后多久，有才写；腐烂关着时不写，因为写了也没用），读档后接着算。
  没有这个字段的旧存档从读档时开始算，不升版本。
- 玩家自己的尸体吹散后，死亡卡片写「你的尸体已经化成骨灰，随身物品散落在：某处」（被化尸粉化掉时仍是
  「你的尸体已经不在了」）。驱尸作用在腐烂的尸体上时，穿着的东西也一起掉下来。
- 测试默认关掉腐烂（`TestAway`，同游走开关），因为老测试会在几分钟后才去搜刮、驱尸、化尸；
  `corpse_decay_test` 和 `world_soak_test` 打开。
- 不实现：ES2 房间 `clean_up()` 销毁地上东西（同「NPCs talk and wander; rooms reset」）。

## 别的地图时间补算 (owner 批准, 2026-10-23)

- **ES2:** 没人的房间照样走时间。受伤的 NPC 心跳不停，回到满才关（char.c:111-120），状态照常发作
  （condition.c），昏迷到点醒来（damage.c `call_out("revive")`），重置按定时器跑（room.c）。
  回满的游走 NPC 心跳关掉后就停在原地，直到重置叫它回家（npc.c random_move 只在心跳开着时跑）。
- **以前（茅山 B、地图重构、Inactive resident maps）:** 玩家不在的地图时间完全停住。地图重构后
  店和街分成两张图，在店里时街上的人全都停着。
- **现在:** 世界时钟跟 NPC 心跳时间同步走（打架、菜单、转场时停），每张图记下玩家离开的时刻。
  下面这些事之前，先把那张图「补算」到现在：玩家走进来、那里的房间重置、有 NPC 进出那张图。
  补算一次算完，结果和心跳一直在跑一样：回气、精、神，内力、法力；状态发作（可能把人药倒，
  owner Q3 按 ES2）；忙碌消退；计时效果到期；昏迷的人到点醒来；NPC 自己到点的化尸。
  每个 NPC 用自己的节拍，种子来自世界交互流的种子、地图和欠下的时长，**不抽会话里的任何随机流**，
  所以进出一张图不改变别处的抽签，读档前后结果一样。冲着玩家来的 call_out（偷窃、拜师答复、制作、
  测试、判决）仍按茅山 B 在离开时处理；风泉剑灵念咒仍等玩家回来（乔阴 C）。
  被唤起的僵尸（zombie.c）补算到回复时主人不在，就散去。昏倒时醒来的时间也从补算自己的种子抽；
  唯一会动会话随机流的是玩家下药致死后的击杀奖励，和在玩家眼前时一样。
- **最多回到造出来的样子（NpcHealCeiling）:** 你不在时，NPC 最多回到 create() 造出它时的数值，不会更多。
  定义里没写的值按上限算。ES2 的 `clean_up()` 会把没人去的房间连同里面的人按原样重新载入，所以
  原作造得虚弱的人，玩家找到时还是那样：地牢里的小娟「只剩一口气」（1/1/500），陈天星内力 2000/3200。
  在玩家眼前，心跳照 ES2 一直回。
- **开局:** 新游戏时每张图结算一次（世界在玩家来之前就在运转），所以开局没有哪张图欠时间。
  唯一的变化是 create() 抽到的内力不满上限的人（尚书府护院）开局就是满的。
- **偏离:** `pacing.json away_catch_up_limit_seconds`（3600）：离开更久时，前 3600 秒按节拍算，
  其余直接算到结束：精气神和有效值满、内力法力满、状态和忙碌结束、昏迷的人醒来。ES2 没有上限，
  有效值每次只修 1 点，可能要回几个小时；设成 0 就是 ES2。
- 重置本来就按世界时间在所有地图上跑，跟进不进图无关，进出地图刷不出重置。补算不给玩家任何东西。
- 存档：根节点可选键 `away_ms`，记录每张图（玩家所在的图除外）欠多少毫秒，只写欠着的。没有这个键的
  存档在读档时视为谁都不欠，不升版本。
- **B 游走和巡街（偏离，owner 批准）:** ES2 里回满的游走 NPC 心跳一关就停在原地。现在补算时，
  按它自己的闲聊节拍（`npc.c chat()` 的抽法，用补算自己的种子）走 random_move 和巡街，最多
  `away_wander_moves`（12）步：只在家和隔壁、关着的门过不去、可以穿过店门到街上；巡街的人沿路线走，
  到头折返。不走路径，直接站到最后那个房间的空地上。不会被悄悄放到玩家所在的图上。设成 0 就是 ES2。
  闲聊里的其他动作（说话、喝酒、捡东西）不补算。
- **邻图来客（owner Q1）:** 玩家所在图两道门以内的图，每欠够 `away_neighbour_pulse_seconds`（30）
  就补算一次（每拍只算一张，轮流来）。那边的游走 NPC 这一步正好走进玩家所在的图时，就从门口进来，
  玩家看到「X走了过来。」，进门的问候、察觉照常。设成 0 就是 ES2。
- 测试：suite 默认按 ES2 跑这两个开关（0，`TestAway`，同 `TestFeel` 的做法），因为老测试会走过、
  清点或找到「房间放的人」。`away_wander_test` 和 `world_soak_test` 打开 pacing.json 的值。
- 存档只记「时间能改变状态」的图欠的时间。读档后，游走的人从存档里的位置接着走，读档前那段时间的
  游走不重演；这只影响位置，不影响状态。
- C 尸体腐烂（Q2）：见「尸体腐烂」。

## 固定俯视体素地图 (owner, 2026-10-22)

- ES2 的地方是房间、出口和文字描述；原生版先以 2D 地图承载，画面是占位色块。
- 试验（客栈一、二楼与雪亭镇街道）后 owner 决定：**全部地图**都用固定正交斜视的 3D 体素表现，
  按客栈二楼的丰富程度布置（AGENTS.md「Maps and art」）。2D 地图仍是唯一依据：身体、碰撞、
  NPC 状态、交互范围、门条件、传送、存档位置和 RNG；体素层只显示，输入按镜头方向转换。
- 上下楼、攀爬、洞穴、跳落照旧用转场；坡道和台阶仍是 2D 路径，高度只在画面上表现。
- owner（2026-10-22）增加左右视角按钮：水平朝向固定为左、右各 45°，保留原俯角；
  只在按按钮时切换，镜头不随行走自动旋转。owner（2026-10-23）要求切换动画：用 0.6 秒等距圆弧
  缓入缓出，途中可反向切换；输入和投影逐帧跟随，近侧墙过中线时换侧。选择跨地图保留，不写存档。
- 家具只记一处：地图布局里阻挡格带 `look`，画家把它写进场景的 Furnishings，体素层照此画。
  不挡路的装饰（灯、窗、地毯、挂画）在 `game/data/<region>/voxel/<map>.json`。
- 近侧墙剖成矮墙（`low_walls`，不参与遮挡）；遮挡只在主角、附近可见 NPC 周围局部渐变透明；
  花草拨动、风摆、蝶群、昼夜光照都是画面状态，不推进游戏时间、不写存档。
- 新增家具会缩小可走区域：属于地图布局改动，各房的门、出口和刷怪点保持可达（走查测试）。
- 原 2D 色块地砖不再显示，只作布局与碰撞；`docs/design/美术规划.md` 的像素画法由体素规范取代。
- **保留几张图的体素世界**（2026-10-28）：所有地图常驻（「地图重构」「别的地图时间补算」），体素世界建好后原本也一直留着，
  连走 18 张图静态内存从 611 MB 涨到 2029 MB（每张约 80 MB）。现在会话按最近进入的顺序只保留 `feel.voxel_worlds_kept`（3）
  张图的体素世界，更早的在玩家离开后释放（3D 节点、遮挡材质、灯光全部放掉，视角、昼夜帧保留），回去时按首次的路径重建、
  画面一致；0 = 全部保留（旋钮之前的行为）。只是画面层的事：2D 地图、NPC、物品、门、存档一概不变。

## 了结 / 放过 (owner 批准, 2026-10-20)

- **ES2:** after the player's 攻击 (kill.c: kill_ob() both ways), feature/attack.c remove_enemy()
  keeps a killer's unconscious victim, combatd.c fight() always strikes one lying unconscious,
  and std/char.c heart_beat() kills it on the next wound: about a second after the fall it is
  dead, with no way to change one's mind (no halt command; surrender.c is refused while the
  enemy kills the player). Only walking out of the room as it falls spares it. One the player
  only fights back (fight_ob()) is let be when it falls (clean_up_enemy()), as here already.
- **Ours (deviation, owner 批准):** a player today does not mean every won fight to end in a
  death, and many NPCs refuse a 切磋. When one the player's side is killing falls — the player
  (standing) or one they called (WorldMapNpcs.summoner_of(): the 天将, the 护法's 天将 or 阴鬼卒,
  the zombie and its 追魂符) has its kill_ob() — those of them who kill it hold their blow
  (remove_killer(), remembering where it stood among their kill marks and enemies) and its
  battle card shows 了结 and 放过; the button is the choice, nothing asks again. The fight is not
  paused: the others fight on, and while one waits the fight goes on.
  - **了结:** the held kill_ob()s are back where they stood and the player turns on it: the next
    blow kills, as ES2. Everything a death does is unchanged (MKS, 杀气, 朱鸿雪's task, the
    vendetta mark, 弑师). The button reads 了结（任务目标） for 朱鸿雪's target, 了结（弑师） for the
    player's own master.
  - **放过:** the player's side no longer kills it. It lies where it fell and comes to on its own
    time; with nobody else to fight, the fight is over (won). 你住了手，放了X一条生路。
  - **Owner (2026-10-20): 放过 bears no grudge** (reverses the plan's Q1, ES2's attack.c
    init() hatred): a fight's end forgets the player, as it does after a flight and for every NPC
    but a conjured one. One that attacks anyone on sight (a robber, a garrison on a vendetta)
    still does, by its own rule.
  - **Owner (2026-10-20): the countdown runs.** NPCs' revive call_outs stand still in a fight
    here (their heart beat runs outside fights), unlike ES2. A held one's runs on the fight's
    clock (as the player's own waking in a fight), shown on its card (昏迷 · 约 N 秒后醒来); if it
    comes to before the player chose, the held kill_ob()s are back and the fight goes on as ES2's
    (X慢慢睁开眼睛，清醒了过来。). Others lying in a fight still wake after it.
  - **Owner (Q2): the player's summons follow the choice.** Anyone else on any side — 老公公 come to
    help, an NPC with its own kill_ob() — keeps to ES2.
  - The player falls or dies while one is held: nobody can choose, the held kill_ob()s are back.
    Only those standing hold: one of the player's called lying down keeps its mark (it strikes
    nobody), and with nobody standing to strike nothing is asked.
  - A won fight in which nobody of the other side died says 你赢了这场战斗。 without pointing at a
    corpse to loot (after 放过, or when the player only fought back).
  - Not saved: a held one lives only inside a fight, and Save is refused in a fight.
- **Owner (Q3): the setting 击倒后 — 询问 / 直接了结**, 询问 by default; 直接了结 is ES2 throughout.
  Settings schema 5 (`after_knockout`: ask / finish); an older file reads as 询问. The suites run
  直接了结 (run_suite.gd, as TestFeel): the rules they pin are ES2's; `spare_or_finish_test`
  turns on 询问.

## 上限预览和拜师条件 (owner, 2026-10-19)

- **ES2:** learn.c says why a lesson fails only when it is asked, one reason at a time; how far
  a teacher takes a skill (the teacher's level, master.c's 20 levels a betrayal and a third of
  the level for one not his own, valid_learn(), level³/10 combat_exp) is never told. A master's
  attempt_apprentice() says only the first check the student fails, when asked.
- **Ours (deviation, owner):** the 请教 page says under each skill how far the player can learn
  it there and what stops it (还能学到 22 级（22 级要再学，须实战经验 ≥ 1064）。), or why not at all
  (学不了：你已学到柳淳风的 150 级。), and what stops a lesson now (潜能已经用完, 精不够). LearnQuote
  walks learn.c's level-bound checks up from the player's level, nothing changed. The 武学 page
  says how far 练习 takes a skill (the basic skill's level; progress only, or full, at it) and
  how far 打坐 / 冥思 / 修行 raise their maximum (the bottleneck).
- **拜师 (deviation, owner):** the popup's 拜师 page lists the master's checks with the player's
  values, met or not (定力 ≥ 20（你 30） ✓), 查看 counts them. What a master asks without saying
  it is told no more (owner Q3): 须通过考验 (三招, 三鞭), 拜师时另有要求 (the oath), 须另有机缘 (陈天星's
  letter); 骆云舟's mark reads 另有条件 until he has said it (his refusal sets marks/书生), then his
  own line.

## 连续修炼 (owner, 2026-10-19)

- **ES2:** learn, practice, exercise, meditate and respirate do one step per command, set no busy
  and take no count (exercise's number is the kee each sitting spends); the player types the
  command again. feature/alias.c's MAX_REPEAT 30 throws out a player who sends one command 30
  times running: a server's guard against bots, not ported (as the login daemons).
- **Ours:** 请教 (the teacher panel) and 练习, 打坐, 冥思, 修行 (the 武学 page) also have 连续…: the
  same command again and again through the same services, every rule and draw unchanged (a run
  leaves the save, RNG included, as the single button pressed as often), a step every
  `training_step_ms` (150; 0 all at once, as in the suites) with a count, a bar and 停止 (B / Esc).
  World time stays held on those pages (owner Q1), so nobody comes in meanwhile; a step that
  starts a fight (茅山道术's 观想虫) ends the run. A run stops on a refusal (the command's own
  lines: potential, kee, force or sen short, the 70 % thresholds, the teacher tired …), a level
  or a maximum up, a fall, a fight, the teacher out of reach, the page closed or left, 停止.
- **Deviation — the log:** a run is told in one summary (你向柳淳风请教「基本剑法」3 次：基本剑法进度
  +31，精 -66，潜能 -3。), the lines a level, a skill_improved() or a maximum gives, then why it
  stopped; each step's own lines are not printed. The single buttons keep ES2's lines.
- **Deviation — no step for nothing (owner Q2):** a run stops *before* a step that would spend
  and gain nothing, and says why: learn with gin not above its cost (learn.c takes all the gin
  left: 你今天太累了), learn of a martial skill whose level³/10 is above combat_exp (gin spent: 也许
  是缺乏实战经验), practice in weak mode once this level's progress is past (L+1)² (improve_skill()
  drops the rest at the level), a sitting that gains nothing (酸麻), a sitting at the bottleneck
  that would take the power back to its maximum. The single buttons still do what ES2 does.

## Busy is saved, not waited on (owner, 2026-10-17)

- **What changed:** Save no longer refuses while the player or an NPC is busy (the
  "Inactive resident maps" and Save-eligibility entries above blocked it). Both busy facts
  (action.c's busy and interrupt) are saved with their character on every map and restored
  exactly; a spent busy whose interrupt value stands stays so, as action.c leaves it.
- **Why:** inactive maps freeze, so an NPC left busy there (the player's 遁 away from a fight)
  kept Save refused until the player went back. A modern RPG saves the state instead of making
  the player wait on something they cannot see. Busy's formulas and its wearing off on the
  heart beat are unchanged; guarding, opponents and lethal intent still block.

## 说话和交互 (owner, 2026-10-17)

Before the unified playtest, NPC speech and interaction were rebuilt as presentation and entry
points (owner's plan, Q1–Q3 as recommended). **Rules are unchanged**: who says what, when a fight
starts, what each action does and refuses are ES2's; the feel's knobs (`pacing.json` `feel`)
decide only where and when the player sees them, and the suites run with them off (as ES2).
- **问候** (init()'s greeting call_out): ES2 starts it as the player comes into the room. Here it
  waits until the player first comes near the NPC (within `speech_reach_px` 136, four body
  widths, and on the screen) and starts then, once per visit to the room (Q1): its wait, and a
  harmful greeting's second to step aside, count from that moment. A player who never comes near
  is not greeted (nor hurt by a greeting that harms).
- **闲聊** (npc.c chat()): the roll is ES2's; a line drawn while the player is far off is not shown
  to them (not even in 消息). What the NPC does on a chat (walks, drinks, steals) happens as before.
- **Where lines show**: what NPCs say (greetings, chat, stories, chants, the toll robber's 喝令)
  shows over their heads and goes into 消息; the bottom left's toasts keep the game's own messages.
  A room's title and description show in the top right for 4 s (+40 ms a character past 40,
  `room_text_ms` / `room_text_char_ms`) and go into 消息 (Q3); 观察 shows them again.
- **交互**: E (pad A) or a click / tap on a thing in reach goes to the target (the nearest, or a
  near one the player faces; Tab / Y and Q / LB / RB step to the others), marked with a ring and
  「E 交互」. A thing that does one thing (a door, an item on the floor, a room's service, a sign
  only looked at) does it at once (Q2); the others open the interaction popup: the thing's name and
  title, how it is (昏迷不醒，约 N 秒后醒来; 正等着你留下买路财), what it is to the player
  (look.c's relation, the strength line), then every option it offers. One the rules refuse now
  is greyed with ES2's own line where it has one (fight.c: 这里禁止战斗。 / %s已经无法战斗了。,
  kill.c: 这里不准战斗。, apprentice.c: 你必须先把%s弄醒。), else a short native one (拾取:
  离得太远，够不着。; 给予 to one lying unconscious: give.c's 这里没有这个人。 would contradict
  what the player sees, so {npc}昏迷不醒，收不了东西。; owner, 2026-10-17). A landmark with an action (放弃,
  抓住藤蔓) always opens the popup, never a stray click. A greeting still waiting when a fight
  starts in the room is forgotten (ES2's had long been said). 拜师 and 给予 are on the popup;
  the HUD's card keeps the name, 菜单, 精气神, conditions and waits only.
- **The popup is one window, two columns, one size** (owner's playtest, 2026-10-17): it keeps
  a fixed share of the screen (75 % × 70 %, never under 820 × 440, so a small or scaled
  screen is nearly all popup), each column
  scrolling itself. The options on the left (no 查看 row); on the right its 查看 — opening the
  popup looks at the thing (look.c: name and title, description, relation, strength; the status
  lines above; a corpse's or landmark's own look). Opening it therefore does what 查看 did, ES2's
  look side effects included (look.c's berserk, a landmark's look function). B / Esc / 返回 (the
  frame's 关闭 on a page) go back to 查看, then close; B on a question is its 取消.
- **World time stands still while the popup shows, every page included; acts are confirmed
  on the right, then done in the world** (owner, 2026-10-17, like Skyrim's menus): a row shows
  what it is about and a 确认 on the right; 确认 closes the popup and the act happens with world
  time running, so an NPC's answer (拜师's within the 0.4 s reaction beat, a story told line by
  line, a 接话) comes in the world, in bubbles.
  - **Deviation: 攻击 and 切磋 always ask** (ES2 and the HUD before: only when risky): the page
    says how strong the NPC looks, then the risk's warning or a plain question. So do 疗伤他人,
    驱尸, 还瓜钱 and a landmark's actions (抓住藤蔓, a dial's turn: each turn reopens the popup).
  - **拜师** (and 发誓恪守门规, 接受测试, 取消拜师请求, which follow it and were the teacher panel's
    own buttons): the master's name, family and what he teaches, the teacher panel's question
    when one applies (betrayal, first master, change of master, a master who attacks a traitor),
    确认. Whether he takes the player was not told before (owner Q1: ES2 tells only by asking);
    since 2026-10-19 the page lists his conditions (「上限预览和拜师条件」).
    请安 to one's own master is done at once. The teacher panel shown as 请教's page leaves these
    to the popup's rows.
  - **Deviation: 给予 gives several things at once** (ES2: one give per command): the page lists
    what the player carries to tick (a stack's amount beside it); the 背包's questions (an
    equipped thing, a large sum, a letter that recruits at once) show as warnings above
    确认给予, which can be pressed once something is ticked. 确认 closes the popup, then give.c
    runs for each ticked thing in the list's order while the NPC still takes gifts.
  - **偷窃**: a thing chosen (or 随手摸一样) is confirmed with what is aimed at and the warning;
    the theft's three seconds then pass in the world. **行贿**: the amount and its button are
    the confirmation; taken, the popup closes.
  - **Pages done on the spot stay**: 购买 / 请教 / any service's panel, 打听, 拾取 on a corpse
    — their results come at once, world time stopped. An 打听 answer that starts something the
    NPC goes on with (大队长's 黄石隘口 told line by line, an NPC's own call_out) closes the
    popup for it to happen, the answer shown as toasts (owner Q2).
- **系统 keeps the status card** (owner, 2026-10-17): the pause (系统) still pauses the tree; the
  HUD's card stays behind the menu there, as behind its other tabs.
- **界面缩放 and the map's own text** (#138, owner 2026-10-17): the 界面缩放 grows the interface
  only; names over bodies, landmark and floor-item labels are drawn on the map and stay its size.

## 室内察觉 (an aggressive NPC indoors notices the room)

**Owner (2026-10-16, after 地图重构 R2):** ES2's aggressive NPCs act from init(), on whoever is
in their room. The native stand-in was a presence circle (spawn `presence_radius`, 120 px);
the remap grew rooms past it, so one could walk round a hall's 护院. Now a zone marked
`indoors` (a building's room, a tent, a cave, a dungeon, from the remap survey's
classification of the ES2 rooms) is the presence: an aggressive NPC there notices the player
the moment both are in the room (the player's arrival or the NPC's, by any way), complete_set
rooms and toll contact alike, and nobody in the next room. Streets and the wild keep the
circle (owner: only rooms inside). The radius knobs of the 狮子 (400) and the 白鳞冰龙 (260)
went with it: their rooms are indoors. 194 zones: the survey's inside rooms less two
balconies whose LPC sets outdoors (阳台, 观景台). An NPC that only may go berserk (attack.c
init()'s roll: 淳于怀太, the 福林楼 guards) rolls on the player's arrival in its room too.
Once noticed, an NPC waits for the player to leave the room and come back (a flight stands
where it was, as the circle's leaving and coming back); one that took no part in the fight
that started meanwhile notices the player anew when it ends (the next 护院). Since「进门一起上」
(2026-10-24) everyone there who attacks on sight comes at once, and outdoors too those who fought wait
for the player to leave their zone.

## 地图重构 (owner, 2026-10-16)

ES2's rooms have no size; the first native maps drew a town's rooms side by side on one map, too
small for a body and its NPCs. Now maps follow a scale standard in body widths
(`tools/maps/standard.json`; owner: a building no smaller than its description says), and every
enterable room is on its building's (or walled compound's: owner Q1) own map, entered by a passage
pair on its door, the town keeping its facade. Rules and content are unchanged: rooms, exits
(one-way ones stay one-way), doors and locks (a door on a passage is one door on both maps), exit
rules, scripted moves and where each NPC stands. Owner Q2–Q4: towns scaled and buildings' maps
laid from their exits; wild maps not rescaled, their buildings and caves moved out; every map
stays resident. 晚月庄's and 水烟阁's compounds were already their own maps: grown ×1.5 as drawn,
and the rooms their descriptions call large grown to that class (owner).
What follows from it:
- An NPC walks through a door onto the next map as it walks into the next room (wanderers, one
  called over, one walking out of a fight, followers); a save counts one on its way out as through
  the door.
- Leaving a room by its door is leaving it (a trap on the way out); a master's 拜师 answer still
  due is said to the empty room as the player leaves the map (茅山 B).
- 茅山 B's rule stands (a map's world time stands still while the player is on another): NPCs act
  only on the player's map, which since the remap is a building or its street (owner to judge at
  the playtest). Superseded by「别的地图时间补算」(2026-10-23): a map catches up when the player comes back.
- A door's fade is the shorter `door_fade_*` and names no place; world revisions
  `SOURCE_ENTRY_REMAP_*` (development saves need a New Game).

## 手感：战斗 (现代化修正 III B2, 2026-10-16)

B 包的战斗部分（同一批准方案）。**规则和结果不变**：
- **战斗速度（设置，不进存档）**：慢 / 标准 / 快。一场战斗有自己的时钟，一回合永远是 `combat_round_ms`
  的规则时间：计时效果、按回合算的忙碌、规则时间都不变；速度只改这段时钟走多少真实秒——慢档一回合用 150%
  的时间，快档 60%（`feel` 的 `battle_slow_percent` / `battle_fast_percent`；标准就是回合本身）。战斗中改设置，
  从下一帧起生效。设置文件升到第 3 版（`battle_speed`、`hit_flash`），旧文件读作标准、闪红开。
- **任务时限（owner Q2）**：朱鸿雪的任务时间在战斗中按这场战斗的时钟走：每回合耗 1 秒，三档一样；标准档
  和以前完全一样。
- **战斗演出**：一回合的句子 0.12 秒一句（`battle_line_ms`）；一回合讲不完时压缩间隔，保证在下一回合之前
  讲完。角色卡等句子讲完再更新：气条 0.25 秒滑到新值（`bar_tween_ms`），掉气时闪红 0.15 秒（`hit_flash_ms`；
  设置「受击闪红」可关）。战斗面板和菜单一样淡入。
- **结束定格**：结果出来后，面板停在最后几句上 0.8 秒（`battle_end_hold_ms`），最后一击也显示在卡片上；
  这段时间世界停住（停住原因 `battle_end`）、玩家不能走、面板不接受操作；之后才出胜负那句、恢复世界。

## 菜单窗口 (界面重构 A, 2026-10-15)

ROADMAP「After the grey box」第 2 步（owner 2026-10-15：先做第 2 步）。一个带标签页的菜单窗口
（角色、武学、背包、任务、声望、百科、系统）取代 HUD 的导航行（观察、角色、背包、补给、消息）；HUD 卡片
留名字、地点（点它就是观察）、精气神、状态和附近列表，加一个「菜单」按钮。不改游戏规则：
- **偏离（owner Q1，2026-10-15）：菜单打开时世界时间停止。** ES2 是 MUD，世界永远在走；本作单机，
  菜单开着时 NPC 心跳（走动、call_out、苏醒）、精气神恢复和状态、定时效果、朱鸿雪任务的时间、房间危险
  和重置、隐藏通道、拦路收费的计时和待发的攻击都不推进（`WorldSessionController.hold_world_time()`）。
  做法是停住世界时钟，不是暂停节点树：背包、武学、补给的动作照常立即生效（它们的闸门要求世界在走，
  一个都没放开）；动作立即引发的战斗照常开始，菜单随之关闭、时间恢复；要等时间的后果（NPC 下一个心跳
  才回应）关菜单后发生。玩家自己动作后的忙碌（busy）照样倒计时（owner：ES2 忙碌时心跳只用来
  continue_action，连着运功不会被挡）。系统页仍是原来的暂停（节点树暂停，存档要求它）；战斗中按 Esc
  只显示系统页（原来战斗中也只有暂停菜单）。方案时我先说「整棵树暂停、吃喝打坐照常」，那不成立，这是
  owner 看过替代方案后定的做法。
- 键盘：C 角色、K 武学、I 背包、J 任务，在菜单里 Q / E 切换标签、再按当前标签的键关闭；L 观察。
- 菜单里的确认框（请确认）和游识神通的提问显示在菜单之上，取消回到原页；其他面板（商店、拾取、观察…）
  打开时菜单先关。游识神通选定去处、移动玩家的物品动作（玛瑙手镯祈祷）先关菜单。
- 角色页把 score 的同一批数字分块显示；任务页现在是朱鸿雪的任务（quest.c 原句）和消息记录，故事链在
  之后的「任务和百科」PR；声望、百科先占位。

## 手柄 (界面重构 B, 2026-10-15)

ROADMAP「After the grey box」第 2 步的 B 包：手柄和键盘、鼠标、触屏并存，不改游戏规则。
- 键位（手柄按 Xbox 位置；键盘不变的照旧）：左摇杆 / 十字键走路；A 确认（Enter/空格），B 返回（Esc）；
  **Start 打开菜单（上次的标签页），Back 是系统页（暂停）**，键盘 M 打开菜单、Esc 仍是暂停（以前 Start
  就是暂停）；菜单里 LB / RB 切换标签（Q / E）；X 观察（L）；右摇杆滚动长文字（PgUp / PgDn）。
- 走路时 HUD 卡片的附近列表：Y（Tab）进入，十字键 / 摇杆在按钮间移动、人站着不动，A 按下，B 或
  Y 退出；原地没有门或商店可用时 A 也进入列表；键盘 WASD、鼠标点击直接退出。
- 打开面板时焦点落在第一个可操作的控件上（确认框落在取消），关闭后回到打开前的按钮；菜单换页落在该页
  第一个控件，没有就落在标签上；关闭菜单回到原处。数字框（打坐量、加力、行贿、背包数量、钱庄数量）
  用左右键增减。
- 战斗：LB / RB 换目标（Q / E），Y 战斗记录（L），B 依次关闭记录、取消提问、取消已排定的操作
  （Backspace），**Esc 仍是暂停**；逃跑、投降没有专用键（防误按），用十字键选中再按 A。
- 按钮和提示上显示当前输入方式的按键图标（手柄按名称分 Xbox / PlayStation / Nintendo，键盘是键帽，
  触屏不显示），换输入方式立即更新。图标是代码画的占位图。
- **新增（owner 问题，未答前按推荐）：新游戏界面的「随机名字」。** ES2 登录时手打名字；手柄打不了字，
  所以姓名框下加一个按钮，从 `data/new_game/names.json` 的姓和名里取一个（名字按已选性别）；键盘照常
  可以自己打。

## 任务日志与百科 (界面重构 C, 2026-10-15)

ROADMAP「After the grey box」第 2 步的 C 包。ES2 没有任务日志，玩家靠自己记；百科对应 `help`。
- **新增（owner Q3）：任务页的「江湖见闻」只记已发生的事和 NPC 说过的话，不提示下一步。** 每条故事链
  的条目写在 `data/common/journal.json`，各有一个条件：身上的标记、临时标记、身上带着某件物品、见过某人，
  或问过某人某个话题（问的当下记）。条件第一次成立时记下（每半秒查一次，菜单开着也查），存进存档
  （`CharacterState.journal`），之后标记清掉、物品给出去也不会消失。一条链有记下的条目才显示，只显示
  记下的条目，按发生顺序；最新有进展的链在最前。NPC 的原话直接取自他的问话数据，不另抄一份。不留存档
  痕迹的情节（单纯走路、打斗）记不下来。
- **新增（owner Q2）：百科的「江湖常识」是 ES2 `doc/help` 里给玩家看的条目**，指令换成游戏里的按钮名
  （score → 角色页，enable → 激发，exercise → 打坐，kill / fight → 攻击 / 切磋，study → 研读，learn →
  请教……），只属于 MUD 的内容去掉：巫师、玩家间的事（拜玩家为师、玩家帮派、组队、频道、留言板）、
  `about`、`cmds`、`rules`、`setup` 之类的目录页、`plan`（巫师的区域计划，有剧透）、`attitude`（巫师
  设定说明）、`whatsnew`、`map.es2`。和游戏不符的句子也去掉：天赋要综合评价 100 才看得到（角色页一直
  显示数值）、正午法力散失、撕衣服包扎（都没有）、叛师技能减半（ES2 的 apprentice.c 也不减）、
  花紫会（陆有财不在游戏里）、`force` 里游戏没有的运功。蓝芷萍按游戏里的名字写作蓝止萍。原文转码丢失的
  字按上下文补回（尸、虫、筑、炼、范、箓、链、秘）；「□精」无法确认，那句改写为不用这个词。
- 百科的其他部分由数据生成，**只收见过的**：武学 = 学会的技能（类别、可激发为、运功、等级），物品 =
  拿过的东西（第一次带在身上时记下，存档 `known_items`），门派 = 自己的门派和见过其门人的门派，人物 =
  见过的人（游识神通的名单，查看时看到的样子）。
- 手柄：百科的分类、条目都是按钮；读条目时 B / Esc 先回列表，不关菜单。

## 手感 (现代化修正 III B1「世界」, 2026-10-15)

ROADMAP「After the grey box」第 1 步 B 包的世界部分（owner 2026-10-15 批准方案，Q1、Q2 按推荐，拆成 B1 世界 /
B2 战斗）。ES2 没有画面，这些都是新增的表现；**不改规则和结果**。时长都在 `common/pacing.json` 的 `feel`
里（`FeelDefinition`），不写就是 0 = 以前的样子。
- **换图**：玩家走进通往别的地图的通道，画面先 0.15 秒变黑（`map_fade_out_ms`）再换图；任何换图之后 0.2 秒
  渐亮（`map_fade_in_ms`；法术、复活之类不是走出来的换图直接从黑渐亮，逻辑次序不变）。这段时间世界停住
  （停住原因 `map_transition`），玩家不能走：淡入淡出不占任何人的时间。到达后上方横幅写「区域 · 地点」1.6 秒。
- **镜头**：换图和同图瞬移后立即对准玩家，不再滑过去；边界取地图画出来的范围（画家生成的地图本来手填的
  就是这个，客栈二楼和地窖以前没边界），比屏幕小的地图居中；跟随平滑 `camera_follow_speed` 6（原值）。
  只有玩家的走动和镜头用物理插值（高刷新率屏幕上不抖）；NPC 每帧移动，不插值。
- **走路**：0.08 秒加到全速（`move_accel_ms`），0.06 秒停住（`move_stop_ms`），全速 220 不变；俯视角滑行
  （贴墙斜走顺着墙滑）。**碰撞体改圆（owner Q1）**：玩家和 NPC 的 34×34 方块改成直径 34 的圆，转角和两人
  之间不再卡；比 34 窄的缝照旧过不去；凶徒、强盗的警戒圈用玩家的形状判定，斜着走近最多晚约 7 像素触发。
  身体边上的小三角是朝向（最后走的方向，八方向）。
  **贴墙滑动**（owner 2026-10-24，`corner_slide_px` 12）：走进墙时沿墙方向保持原速滑过去，不再按夹角减速；
  几乎正面撞上一条棱（窄路的台阶、岩角）时，往两侧最多看 12 像素，哪边一挪就能绕过去就往哪边滑。
  只改玩家自己走路的手感，身体大小、碰撞和能过的缝都不变。
- **交互提示**：A / 回车作用的东西（门、服务；没有就是最近的人或物，A 进它在卡片上的那一组）画金圈，
  名字上方写按键和做什么（玩家常站在它下面）；它说话时气泡在提示上面。到达横幅放在状态卡右边空出的地方。
- **头顶气泡**：NPC 的闲聊、问候和剧本台词、讲述（筱薇、大队长）、剑灵的吟诵、强盗的喝令显示在说话人头顶
  2.5 秒（超过 24 字每字多 0.06 秒，`speech_bubble_ms` / `speech_bubble_char_ms`），「X说道：」这类开头去掉，
  喝令是红字。记录照旧全写。强盗喝之前先写岗上的描述，红字一定在描述后面。
- **菜单**：0.12 秒淡入（`menu_fade_ms`），世界照旧从按下那一刻停住；关闭是立即的，玩家马上能走。
- 套件默认关掉 feel（`TestFeel`：淡入淡出会让走通道的旧测试晚一拍换图）；`feel_test` 打开测。

## 响应性 (现代化修正 III A「等待」, 2026-10-15)

ROADMAP「After the grey box」第 1 步的 A 包（owner 2026-10-15 批准方案，问题 1–3 按推荐）。规则：玩家刚做的
事要马上有回应；等待本身有玩法或戏剧意义的保留节奏，但让玩家看见进度；世界照常走拍。**只改「何时显示」，
不改公式和结果。** 每个时长都是 `common/pacing.json` 的旋钮，不写就是 ES2 原值（`PacingDefinition`）；
NPC 数据里的 ES2 秒数原样保留。

- **偏离：`reaction_beat_ms` 400**（ES2：各 call_out 自己的秒数）。回应玩家的 NPC call_out 最晚 0.4 秒到，
  比 ES2 早的不变：林忌、蓝止萍、玄智的拜师答复（`call_out("do_recruit", 2)`）、进门问候
  （`call_out("greeting", 1)`；oldliu.c 是 2 秒，游戏一律 1 秒）、程不平判决（2 秒）、黑衣人化尸
  （`call_out("dissolve", 1)`）、僵尸散去（1 秒）、小娟的呼救（3 秒；数据里标 `reaction`）。慢著，一个一个来
  因此几乎碰不到。**会伤人、下毒、动手或把人赶走的问候保留 ES2 的 1 秒**（家丁、神像、琼衣/韶吟/欣郁、刘老农
  的报仇、天驼关赶人的兵）：那一秒是走过去的窗口，和买路钱同理（owner，#127 Q1）。
- **偏离：`trial_blow_ms` 700**（ES2：0）。於兰天武的三招、瑷伦的三鞭照 champion.c 在接受时一次打完（伤害、
  台词、拜师结果当下就定，之间什么也插不进来），通过的测试再每 0.7 秒讲一招，卡片显示「X的测试：第 N / 3 招」；
  菜单开着、打架时讲述停住，离开地图就一次讲完。没接住的测试当下一次讲完、立即倒下（否则会先黑屏、后出那一招；
  owner，#127 Q2）。
- **偏离：买路钱的强盗**（gangster.c 一声不吭直接动手，买路财那句只是 1% 的闲聊）：欠买路钱的玩家一进他的
  范围，他立即喊出自己的第一句闲聊（数据 `toll_shout`，红字警示），头顶和附近列表里的名字变红；owner 10-06 定的 2 秒走过窗口
  （`toll_attack_delay_ms`）不变，从这一声开始算（他昏着、在打架时不算）。走上岗一趟只喊一次，在范围边上进进
  出出不重喊；付过钱的不喊。
- **新增（owner Q3）：讲述序列可「继续」。** 筱薇做竹蜻蜓、大队长讲黄石隘口（make_stage 每 2 秒一句）、黑白
  无常对鬼魂的五句话（每 5 秒；数据标 `hurry`）保持原节奏，卡片显示「X：第 N / 总 句」和「继续」按钮，
  按钮立即出下一句，后面的间隔照旧；A / 回车在当地没有门、商店之类的操作时也是「继续」。黑无常对活人 5 秒后
  动手是逃跑窗口，不能加快。
- **新增：卡片上的等待条。** 忙碌（「忙碌：约 N 秒后空下来」，按心跳倒数）、偷窃的三秒（steal.c 原值不变，
  「等待机会对X下手」）、朱鸿雪任务剩余时间；附近列表里昏迷的 NPC 写「昏迷不醒，约 N 秒后醒来」
  （damage.c 的 revive 延时不变）。小偷偷玩家照旧不出声：不动声色就是玩法，事后那句已有。
- `heart_beat_ms` 2000：战斗外的心跳（闲聊、忙碌倒数、heal_up 的计数）从代码常量改成旋钮，数值不变
  （ES2 driver「通常 2 秒」，S5B B）。战斗回合仍是 `combat_round_ms` 1000。
- `dim_fade_ms` 400（ES2 没有画面：0 = 立即）：昏迷时画面 0.4 秒渐暗。
- 和菜单（「菜单窗口」）一致：以上延时和演出拍都走世界时钟，菜单开着就停；卡片和渐暗是纯显示，用真实时间。
- 只保持 ES2 计时的旧测试在 `Es2Pacing` 下跑（全部旋钮为 ES2 值）；`responsiveness_test` 两种都测。

## 鬼门关 B: 阴阳眼 (2026-10-15)

Plan #13 Q4 (a): necromancy/astral_vision.c is 茅山道术's 阴阳眼 (std/char.c visible() reads
apply/astral_vision; 茅山 A left it out on the wrong reading that nothing does). It follows the
LPC (30 mana, 5 sen, query_skill("spells") seconds, refused while it runs, busy 3 in a fight, its
line when it ends); while it runs the living player sees ghosts as a ghost does, so 乔阴's 孤魂野鬼
can be fought for its 布条. Native only in how it is reached:
- **Cast at oneself, from the 武学 page (法术) outside a fight and the battle panel in one**: one
  button each (the file casts on its caster whoever is named). Its 5 sen knocking the player out
  is asked first (the owner's rule on choices that can knock out).
- **Its seconds run on world time outside a fight and by the fight's rounds in one, and a Save
  keeps them**, as every timed apply's (powerup's).

## 鬼门关 A: 阴间 and the way back (2026-10-15)

Plan #13 (owner, 2026-10-15: Q1 (a), Q2 (a), Q3 (b), Q4 (a) as recommended, the defaults as
proposed). A ports d/death and replaces the direct revival at the Snow temple ([Player
unconsciousness and death follow ES2](#player-unconsciousness-and-death-follow-es2-2026-09-30));
B is 阴阳眼 and the 孤魂野鬼's 布条 (Q4 (a)). What each LPC function became is in
[DEATH_CONTENT](DEATH_CONTENT.md); it follows the LPC except:
- **Owner (Q1 (a)): 阴间 is walked.** A dead player is a ghost (damage.c die(): ghost, 1/1 gin, kee
  and sen) and, past the death card, stands at 鬼门关 (DEATH_ROOM) before the white gargoyle. The
  card (你死了, what the death cost, where the corpse lies) waits for 继续 (默认 D1); the gargoyle's
  lines are no longer on it, and its 跳过 button is gone.
- **Owner (Q2 (a)): a gargoyle does not wander off while his lines run** (NpcHooks `calls_hold`);
  ES2's chat random_move cut them short about half the time (the player followed, and he began
  again). He wanders as before otherwise.
- **Owner (Q3 (b)): 路的尽头 reads 浓雾在这里聚成一堵墙，路到这里就断了。** (a `source_fixes` of
  road3.c); ES2's text was the placeholder 「..... 还没想到 ....」. The long road's loop stays.
- **默认 D4: the little shop's 打听 lists 回家**, the double's one topic (ES2: ask <one's own id> about
  回家, typed), as 打听 lists ES2's topics everywhere.
- **默认 D6: one round of a gargoyle's lines at a time**: coming back starts them anew; ES2's
  init() started a second chain beside a running one (doubled lines).
- **默认 D7: a ghost may Save; Continue puts it at 鬼门关** (logind.c: a ghost logs in at
  DEATH_ROOM) from wherever it was saved, and the gargoyle's lines begin again; the long road's
  count stays behind. The card and the move back to life are not saved (Save waits).
- **Owner: 遁 at oneself fails for a ghost** (你失败了。, the cost spent, as 游识神通's): dun.c asks
  nothing of is_ghost(), so a ghost could take itself to the Snow temple and stay a ghost there,
  unable to eat or drink, until it died again.
- **A ghost lying unconscious when a gargoyle's last line comes is moved once it comes to**
  (ES2 moved it at once, unconscious).
- **As ES2 (D5):** a ghost killed in 阴间 leaves no corpse (chard.c), what it carries falls, a
  killer takes killer_reward() again, and the ghost is back at 鬼门关 after the card; its card names
  no corpse. Attacking a 阴鬼牙将 (400000 exp, against a ghost's 1/1 kee) is asked first (its
  `attack_ask`, the owner's rule on choices that can kill; ordinary 攻击 is not asked). A ghost cannot eat or drink
  (food.c, liquid.c), fails 游识神通 (drift_sense.c: 你失败了。, the cost paid), is 【 鬼  魂 】 with
  (鬼气) before its name (rankd.c, name.c), and sees ghosts (char.c visible(): the 阴鬼牙将); an
  NPC that is no ghost does not see it (its turns pass by perception, combatd.c). The gargoyles
  answer anyone (wgargoyle.c asks nothing). 酆都城门 lets nobody back south (NPCs walk it, as
  !userp() did). The long road refuses four tries north and lets the fifth through; a refused try
  puts the player back at the road's south end (the scenery that never changes), and leaving the
  road any way starts the count anew (delete_temp()). The living reach 阴间 only by 游识神通 to a
  gargoyle met as a ghost (drift_sense.c finds no one the player cannot see: no 阴鬼牙将 for the
  living); there the white gargoyle and the little shop send them to the temple as well
  (reincarnate() asks nothing of ghost: eff_ back to max), and 黑无常 says 喂！阳人来阴间做什么？
  and attacks.
- **Not ported:** block.c (离岛) and jail.c (绿岛), wizard punishment rooms; spath1.c (墙边小路),
  which no exit leads into; tell_room() lines and the vision line for other players.
- **The gargoyles' five seconds stand still while the player fights** (the world stands still in a
  fight; ES2's call_out counted on).
- **Global (data):** ScriptedAct step `reincarnate` (reincarnate() and the move to the temple, the
  act's last step, made by the session the same frame after its map's beat) and condition `ghost`
  (true or false); NpcHooks `calls_hold`;
  exit rule `tries` {temp, value, point}; CharacterState `ghost` (saved only when true). The death
  map is region `death` (阴间), map `death.realm`.
- **Save:** world content revision `SOURCE_ENTRY_DEATH_V1` (a new map and the ghost); older
  development saves need a New Game.

## 黑松山 B: the 地牢, 淳于怀太 and 小娟 (2026-10-15)

The plan's B (「黑松山 A」 below: owner Q2 (a), F1–F4; M3, M7 默认). What each LPC function became is
in [CHUENYU_CONTENT](CHUENYU_CONTENT.md#lpc--native-b); it follows the LPC except:
- **Owner (Q2 (a)): the rescue happens once.** Thanked, 刘老农 and 娟儿 leave for good (`leave`: no
  reset makes them anew); killed, 小娟 is not made anew (her spawn is `once`); after his revenge
  刘老农 no longer asks after her (our mark 老刘报仇: ES2 cleared marks/murder and he asked again).
- **Owner (F1): the thanks only with 娟儿 standing beside the player**; with marks/老刘 alone he asks
  after her. ES2's 小娟 destructed herself five seconds after meeting him (goaway()); here she leaves
  with him (刘老农领着娟儿匆匆离去).
- **Owner (F2): she follows every way the player leads**: the maze's ways, the rope, the slab, the
  climbs, the chain, other maps and through a door shut behind (ES2: go.c's exits only). Saved where
  she stands, on any map; her room's reset does not call her home while she follows (ES2's
  return_home() did, from anywhere).
- **Owner (F3): 攻击 on 小娟 is asked first** (只剩一口气), and the player's own berserk never falls on
  her (as on their master, 水烟阁 C). **Owner (F4): only the player leads her**
  (ES2's init() started followhim for any living thing that came in, a rat too).
- **默认 (M3): the maze as passages**, its exits as the LPC writes them (the one-way ones too).
- **默认 (M7): 刘老农's 悲愤欲绝 lasts until his room resets**: the title, the temporary applies, his
  chat and his hatred end there (ES2: until he was destructed).
- **His revenge comes with his greeting**, a second after the player comes in (ES2's killhim() a
  second later still). Of killhim()'s five set_temp() applies only apply/damage (combatd.c) and
  apply/force (skill.c query_skill("force"), unused: his force_factor is 0) are read, here as in ES2;
  apply/combat_exp is read by nothing, so he is no million-exp fighter (the plan said so).
- **M6 (默认): 刘老农's last line loses its stray ”.**
- **小娟's twenty seconds stand still while the player fights** (the world stands still in a fight;
  ES2 counted on). Leaving and coming back starts them again (init()'s remove_call_out()).
- **Stays as ES2:** the fall's random(10)+5 off eff_kee and kee; 淳于怀太 shouts and attacks whoever
  comes into the 刑房, at once; the 狱卒 attack whoever comes in (both of a 刑房's together:
  complete_set) and wander; the slab opens on the fifth push for five seconds and shuts on time,
  with the player above too (east_castle reads its fall); the 地牢 has no other way out.
  (`complete_set` superseded by「进门一起上」, 2026-10-24: every zone gathers its gang, `combat_entry` is gone.)
- **Global (data):** NPC `calls` (init()'s call_outs: `after` seconds, started anew by each arrival),
  `moods` (title, applies, flags and chat until the room resets), `die_marks_killer`,
  `attack_ask`/`attack_choice`, `follows_every_way`; spawn `once`; act condition `npc_in`, steps
  `mark`, `npc_mood`, `npc_wield`, `leave`; a hidden passage's `closes_on_time` and `close_beyond`;
  an NPC's random_move through a passage of its map that is no walk (the maze) puts it in the room
  beyond.
- **Save:** world content revision `SOURCE_ENTRY_CHUENYU_B_V1` (a new map); older development saves
  need a New Game.

## 黑松山 A: the road, the mountain and the castle (2026-10-12)

Plan (owner, 2026-10-12: Q1 (a), Q2 (a), F1–F4 as recommended; M1–M7 **默认**, M3 and M7 with
B): A the road,
the mountain and the castle; B the 地牢, 淳于怀太 and 小娟, 刘老农's thanks and revenge. What each
LPC function became is in [CHUENYU_CONTENT](CHUENYU_CONTENT.md); it follows the LPC except:
- **Owner (玉螺湖村 Q2): the way in is repaired.** croad1.c's south led to 玉螺湖村's road1, which
  had no way back, so ES2's players never reached 黑松山; the 黄土大道's spur west now leads there.
- **Owner (Q1 (a)): d/chuenyu's copy of 刘家 is not placed** (dustyroad3, home, littlegarden,
  smallstorage, smallyard and their people: a second 刘老农): ES2 cut it off itself (sunnyroad.c's
  south commented out, croad2.c without a way to it) and placed 刘家 in 玉螺湖村.
- **Owner (Q2 (a), for B): the rescue happens once.** Rescued, 刘老农 and 娟儿 leave for good (小娟
  no longer in the 地牢); killed, 小娟 does not come back, 刘老农 takes his revenge once (as ES2) and
  no longer asks after her. ES2 brought both back at the next reset (a new 銮鱼衡冰 each time).
- **Owner (F1–F4, for B):** the thanks only with 娟儿 beside the player (ES2: the mark alone); she
  follows every way the player goes, climbs and the chain too (ES2: only through exits); attacking
  her is asked first; only the player leads her (ES2: any living thing that stayed 20 seconds).
- **默认 (M1): climbing the castle walls moves the player at once** (ES2 three seconds later; its
  start_busy(3) was stopped at once, so nothing waited but the move).
- **默认 (M2): the mountain's one-way exits are walked both ways** (foot_b_mtn.c's up has no way back
  down from the west street, high_b_mtn2.c's down no way up from the foot; on one map a border is
  walked both ways).
- **The gate's killing air turns one back where they stand** (the street they came up): gate_castle.c
  moved everyone below 2000 combat_exp to the east street, high_b_mtn2, whichever way they came.
- **默认 (M4): food that is a weapon.** pigmeat.c (HAMMER + F_FOOD) is a hammer and six bites of 90,
  eaten while wielded too; it leaves the 山猪骨头 in the hand, the same hammer (finish_eat()
  renames it). u/cloud's 牛腿 (积压 A11: a hammer only until now) is food too and leaves its 牛腿骨.
  Broken, such a weapon is food still (bash_weapon() leaves F_FOOD alone), worth a tenth.
- **默认 (M5):** the 护院's pursuer is not modelled (as everywhere); the 园工's two cast animate draws
  do nothing (as 茅山's NPCs').
- **默认 (M6): two slips fixed in the room texts** (north_garden.c calls itself the 东花园; bedroom.c
  puts the 膳房 west, its exit is south) and the 卖花姑娘's stray leading space; the 家丁's
  家丁喝道： inside his own say and the cook's unclosed quote stay.
- **Stays as ES2:** the gate turns back combat_exp below 2000; the 夹道's arrows (15 seconds, then
  every 5; random(10)+35 off eff_kee and kee) can knock out and kill (a volley that fells the player
  ends that moment; the next comes five seconds on); the 巨型犬 (attitude killer) attack only by
  berserk; a 紫衣家丁 who stops one whose random(per) is below 20 turns aggressive for good (attacks
  on sight, past the player's death, until he is made anew; his rude name and spar answers are not
  modelled).
- **Global (data):** attitude `killer`; act condition `per_below` (a greeting's rolls draw from the
  NPCs' stream); act step `hurt` (eff and current together, base + random); world `hazards`
  (an act again and again while the player stays); food on a weapon; the painter takes an act
  service that moves the player on its map as a way (a climb over a wall).
- **Save:** world content revision `SOURCE_ENTRY_CHUENYU_V1` (a new region); older development saves
  need a New Game.

## 京师 B: 尚书府 and the city's secrets (2026-10-12)

The plan's B (「京师 A」 below: owner Q1 (b), Q2 (a); M1, M3, M4 默认). What each LPC function
became is in [CITY_CONTENT](CITY_CONTENT.md#lpc--native-b); it follows the LPC except:
- **Owner (Q2 (a)): the 地下密室's stairs open from below.** Its 天花板 (推开) opens the altar's way
  for the same three seconds; the lines are jitan.c's own (天花板…露出一个向上的阶梯 below, and on
  closing 天花板…收了回去 below, 地板…盖住了 at the altar). The 天花板's look (天花板上有一块石板，
  似乎可以推开。) is ours: the cell has no item_desc. Unlike Snow's 密室 (4C) the way shuts on time on
  a player below, who opens it again; Continue below finds it shut.
- **默认 (M1): the 门房 hands back less than three taels of gold** (鼻子里哼了一声，头掉了过去。 as
  written, no speaker); with his leave already given, 大人太客气了 and he keeps it (as ES2).
- **默认 (M3): the 门房's leave is spent going in through the 大铁门**; gate.c deleted it whenever
  the player left the gate, west too, without a word. The 护院 on the 小径 ask for the same mark,
  so they let nobody north or east (as ES2; one lying unconscious too, present()); with both dead
  or gone the way is free.
- **默认 (M4): a press that opens nothing clears the turns**; jitan.c kept them, so one wrong try
  left the button dead until the room's reset with nothing said. A right press clears them as
  jitan.c does.
- **Owner (Q1 (b)): the token as ES2.** 废园's flash on every way out south (the (find) hint, the
  hard break and the blank lines go: the button is 草丛 · 寻找); random(kar + 30) >= 35 finds an
  出城令牌 (one carried: 忙活了半天…, no roll); a 守城兵 takes it (destructed) and gives
  marks/令牌; the gates stay shut (这个方向没有出路。). 晚月庄's 杀手令牌 answers to "token" first
  too and does the same, as ES2.
- **The button's turns are buttons** (顺时针转, 逆时针转, then 按下): turn button alone and a wrong
  direction only explained the typed command (not shown).
- **The 院墙 is a map of its own** (wall.c has no exits; climb and jump are moves): 院墙 · 爬上去 on
  the 东街, 尚书府 · 跳进去 into the 废屋, 京师东街 · 跳回去; no 轻功 is asked (as ES2).
- **Stays as ES2:** yuan.c's !userp() needs nothing (the only walker, a 护院, keeps to his room and
  its neighbours); the 小屋's 杀气, the 护院's 客人 and the 花匠's 清尘出事了 lead nowhere (unfinished
  in the LPC); the 花匠 and 庾清尘 cast 茅山's four spells in a fight.
- **Fixed slip:** the 门房's long ended in 的n (a lost backslash): 的 and a line break.
- **Global (data):** NPC `create_rolls` (create()'s own draws in its order: attributes, power,
  combat_exp, the chat chances, skill levels; kept with the NPC) and `name_parts` (a name drawn
  part by part, a form per name); present() of an NPC that drew its name answers to its kind;
  exit rule `no_mark` with several `present` kinds and `spends`; give rule `destroys`; act
  `kar_draw`; landmark policies `dial` (a landmark with several actions) and `dial_below`.
- **Save:** world content revision `SOURCE_ENTRY_CITY_B_V1`; older development saves need a New Game.

## 京师 A: the city, its shops and people (2026-10-12)

Plan (owner, 2026-10-12: Q1 (b), Q2 (a); M1–M4 not answered, so they stand as **默认**): A the
city, its shops and people (陈天星 included); B 尚书府 and the city's secrets. What each LPC
function became is in [CITY_CONTENT](CITY_CONTENT.md); it follows the LPC except:
- **Owner (Q1 (b), for B): the token line as ES2 wrote it.** The 守城兵 tell the player to look for
  a token; 废园's flash and find (random(kar + 30) >= 35) give an 出城令牌, which a guard takes
  (原来是官府中人，您请出城, marks/令牌). The five outer gates stay shut all the same: their out exits
  are commented out and the rooms outside were never written. A puts the guards' refusal on each
  shut gate (城门 · 出城: 没有官府通令…; with the mark or no guard standing, go.c's 这个方向没有出路。).
- **Owner (Q2 (a), for B): the 地下密室's stairs open from below too** (天花板…露出一个向上的阶梯,
  closing after three seconds as the altar's way down does).
- **默认 (M1, B): the 门房 hands back less than three gold** (ES2 kept it). **默认 (M2): 陈天星
  hands back what is not 陈剑秋's letter to the giver** (不要戏弄我！, 这是你的嘛？; ES2 kept it).
  **默认 (M3, B): the 门房's mark is spent only by going in** (not lost walking west). **默认 (M4,
  B): a press that opens nothing clears the altar's turns.**
- **Owner (plan): the letter is asked for first** (it is gone once given, and 陈天星 recruits): the
  rule's question when he will only offer; the 拜师 question (first master, betrayal, a new master)
  when a 拜师 already waits on him and his recruit takes the player at once.
- **Owner (plan): the 店小二 drops a small tip on the floor** (drop all meant it; ES2's give.c
  destructed money after accept_object(), and his drop all dropped only earlier gifts). Below 1000
  (anything but money) it lands at the player's feet; 1000 or more is his and marks/酒楼.
- **默认: no 出城 at the 北门.** Its guards' out command refused there too, but the road north is
  open and is the way out; only the five shut gates offer 出城.
- **默认: the guards are there from the start.** create_door() for a missing exit errors (std/room.c)
  in the gates, the 北门 and nroad1, so create() stopped before setup() and the guards came with
  the room's first reset() in ES2; no door is placed anywhere in A.
- **默认: 反了！反了！ is shown** when a 守城兵 is attacked (do_kill()'s notify_fail(): kill.c went on,
  so ES2 never printed it); the other guards there join, as each one's do_kill() kill_ob()ed the attacker.
- **默认: 陈天星's offer is saved.** recruit.c's offer (pending/recruit) was a temp on the master and
  went with a logout; the player has given the letter for it, so it outlives Continue (kept with
  the player's saved temps).
- **默认: 桃X仙 draws his name, not his id** (nobody sees an NPC's id); his drools stay silent (their
  memory comes only from the chat channel, which nobody else speaks on). A corpse is not among
  what his get all takes (an NPC carrying a body is not modelled).
- **默认: 护国寺, 紫禁城, 监狱, 刑场 and 相国府 are drawn shut** (their exits are commented out and
  the rooms never written). 尚书府 is drawn shut until B; street3's wall and climb, the altar's
  button and 废园's find come with B (city_test fails once B's rooms are placed).
- **Stays as ES2:** 钱千万 always says 吃完了快走 (query("rank") is set on no player); 黑你没商量's
  fight code is unreachable (no_fight bank); real-world jokes kept (桂花 precedent); nroad1.c's
  yell (a typo exit to a room that does not exist) is not ported.
- **Global (data):** give rules `drops` (onto the floor), `recruit` (the NPC's own recruit) and `ask`
  (the 背包 asks first); apprentice kind `silent` (no attempt_apprentice()); NPC `skill_roll` and a
  `chat_chance` rule each NPC draws (saved); chat actions `get_all`, `wear_all`, `wield_all`;
  accept_kill `line`; exit rule `no_mark` with `present` (the NPC's own command). The importer
  keeps the plain ids of a set_name() whose id is drawn.
- **Save:** world content revision `SOURCE_ENTRY_CITY_V1` (a new region); older development saves
  need a New Game.

## 玉螺湖村 B: the 瓜地 (2026-10-11)

The plan's B (「玉螺湖村 A」 below). What each LPC function became is in
[VILLAGE_CONTENT](VILLAGE_CONTENT.md#lpc--native-b-the-瓜地); it follows the LPC except:
- **Owner (plan): 还瓜钱 pays.** meloner.c's do_return() took nothing; now it costs the 西瓜's value
  (60 文), paid as buying from him is (buy.c's can_afford() and pay_money(): 你的钱不够。, or 你没有
  足够的零钱，而对方也找不开...。 when the coins on hand cannot make it), and the fight goes on.
  Paid: 好，咱俩的账就算结了。, both flags go, he goes home (in a fight he walks out of it; move()
  ended it the same way). It is a button on the HUD (his group, while he stands by) and on the battle
  panel (like 行贿); typed `return melon cost`, 你又没欠他什么 and 除了瓜钱 went with the typing, and
  the line's command hint and stray ） with them (水烟阁 B's ruling on hints for buttons).
- **Owner (plan): the way out opens once the 瓜农 who caught the player is down, dead or gone.**
  valid_leave() asked only the thief's flag, so one who killed him never left the 瓜地 (the flag
  is saved now). Another 瓜农 standing there holds nobody; one who wakes holds the player again.
- **Owner (plan, A10): the pick is asked first while the 瓜棚's first 瓜农 is clearly stronger**
  (he would come over to the death).
- **默认 (review): the dead owe nothing.** Killed by him, the player loses both marks and so does
  every 瓜农 holding one: ES2's temps went at the next login, but saved here they would have the
  man who killed them hold them again and ask for his money. Paying one 瓜农 clears any other's
  claim too (a second catch while the first lay unconscious).
- **默认 (review): he does not greet the thief he comes to fight.** ob->move() ran meloner.c's
  init() before kill_ob(), so a second later, mid-fight, ES2 said 这位…要不要买个西瓜解解渴？
- **Not kept:** set_leader(me): he cannot be left while he stands, and a leader is only followed
  by one standing by; nothing else changes.
- **Stays as ES2:** the melon is the thief's whether he is caught or not; only the first 瓜农 in
  the shed comes (present()); one lying unconscious there notices nothing (默认, as kitchen.c's
  cook).
- **Global (data):** an act's `kar_above` (random(kar) > random(n) rolls, drawn once, in order, only
  when reached; the branch is chosen when the command runs) and `present_in` (an NPC standing in
  another room); act steps `comes` (the first such NPC comes beside the player and is the act's NPC:
  its `kill`, its `npc_flag`) and `npc_flag` (its own set_temp()); a room act's `stronger` (A10's
  question); an exit rule `held` (the player's flag and an NPC holding the same one, standing
  there); a fight chat `say_while_flag`; an NPC's `settle` (NpcSettle); a battle action
  `combat.settle.<npc>` that sends its NPC out of the fight.
- **Save:** no new fields (player temps and NPC flags were saved already); the world content
  revision stays SOURCE_ENTRY_VILLAGE_V1.

## 玉螺湖村 A: the village, the lake and its people (2026-10-11)

Plan (owner, 2026-10-11: 按照你的推荐来): A the village, the lake and the people; B the 瓜地 (the
pick, the 瓜农's catch, 还瓜钱). What each LPC function became is in
[VILLAGE_CONTENT](VILLAGE_CONTENT.md); it follows the LPC except:
- **Owner (Q1): the lake's middle works** (repaired). lake.c's replace_program(ROOM) dropped its
  init() and valid_leave(), so ES2 answered paddle and dive with 什么? and its east exit walked
  ashore, though the room invites a dive. Now the boat paddles back (小船 · 划回岸边); stepping east
  off the bow is refused (你正站在船头…); the dive (湖水 · 潜入湖中) is asked first (the only way
  out is through the 白鳞冰龙's hall) and lands in the ice cave, whose 玄冰 offers 放弃 (the Inn,
  as 绝地). Obvious slips: $N你划动双桨 (你划动双桨), the dive's line broken mid-sentence.
- **Owner (Q2): 黑松山 is repaired after 京师** (ROADMAP 12b): ES2 had no way in. The 黄土大道's
  spur west is drawn closed; 刘老农 only asks after 娟儿 until then; his thanks and revenge come
  with 黑松山 (village_test fails once a d/chuenyu room is placed). The 三叉路口's way south to
  京师 is drawn closed the same way (#12).
- **Owner (plan, for B): 还瓜钱 pays the 瓜农 60 文** (不够: 你的钱不够。, the fight goes on; ES2 took
  nothing), **and his block lifts once the catching 瓜农 is down, dead or gone** (ES2 kept the
  thief's flag, so one who killed him never left the 瓜地; the flag is saved now). Asked first
  when the 瓜农 is clearly stronger (A10).
- **The lake's middle is a map of its own** (the boat): only the paddle reaches it, as 乔阴's rooms
  only verbs reach. The lake is no walk: `always` exit rules on the shore's way west (这么大的一片湖，
  你想走过去吗？) and the bow's way east.
- **默认 (plan): the 南房 loads.** A stray } ended lordhouse3.c's do_takeout(), so the room never
  compiled (source_fixes); its shelf (look_shield(): "are this true?"), take_out, push and the
  commented-out 关公 wall are an unfinished mechanism with no outcome: not ported. The 东房's
  wall and stick have no text either.
- **默认 (plan): all six 白鳞冰龙 fall on whoever enters their hall** (`complete_set`, presence 260):
  ES2's aggressive NPCs each attacked on entry.
  (Presence 260 superseded by「室内察觉」, 2026-10-16: the hall is indoors, the room is the presence;
  `complete_set` by「进门一起上」, 2026-10-24: every zone gathers its gang, `combat_entry` is gone.)
- **默认 (plan): 刘老农's greeting comes a second after the player** (the LPC's call_out was 2).
- **默认 (plan): the 渔夫's 桂花 answer is kept** (it names a real university: the author's joke).
- **The 西瓜** (food.c's drink_func): each of its eight bites adds 20 food and 40 water, refused
  once water is full (你肚子太涨了，再也撑不下任何东东了。!); the last leaves a 西瓜皮 (bone: Snow's
  dog takes it, as ES2). F_LIQUID is commented out: its 西瓜汁 is never drunk.
- **Stays as ES2:** the 瓜农's greeting names no speaker (say() as written); the 农妇's age line is
  against her enemy (青石村 A); flowergirl.c in the room directory is a stray copy (not placed).
- **默认: pushing the grass aside while pressed against it steps through.** The way west lies where
  the grass was, so one who pushes while standing against it is on the way: a one-way way opened
  under the player takes them (Snow's floor, which has a way back up, still waits for a step off
  and on). One who pushes from a step away walks west into it. **Close to ES2:** every push opens
  it for five seconds from the first push that found it shut; ES2's older call_out could shut a
  later reopening early (pushes at 0 and 3 s, shut at 5 s; pushed at 6 s, shut at 8 s by the
  second one's call_out), a difference of a few seconds nobody can rely on.
- **Global (data):** an exit rule `always` (refuses everyone); a `hidden_passage` with one portal
  (road6.c's grass: valley2's way back east is an exit) and `every_push` (no count: every push
  opens it, the first close stands; the push line optional); a passage opened under the player,
  with no way back to wait for, takes them through; food `water` (drink_func).
- **Save:** world content revision `SOURCE_ENTRY_VILLAGE_V1` (a new region); older development
  saves need a New Game.

## The HUD's actions for what is near (2026-10-11)

Owner (2026-10-11, from the HUD): the actions show only for what the player can reach.
- Before: a click anywhere on the map selected an NPC, landmark, corpse or floor item and the
  card showed its buttons whatever the distance (ES2's commands name anyone in the room,
  present()); the nearest door or service's button sat in the same row, so 店小二 · 购买 read
  as an action on the 旅客 selected across the room.
- Now the status card lists one group per thing in reach, nearest first: living NPCs in the
  player's place within 96 px (`WorldMapSelection.NEARBY_REACH`, about a shop counter's reach)
  with the services they offer from their body (店小二: 购买, 查看, 攻击 …), corpses and floor
  items there, landmarks within 96 px (or touched, when they need contact), and doors and room
  services within their own authored reach; the 巡捕 leading the player wherever he is (only his
  行贿 while he is beyond reach, from the catch anywhere in the room on). A group goes when its thing leaves reach;
  the others keep their places (a newcomer joins at the end), so no button moves under the
  pointer as NPCs walk about.
- **Owner: a click on the map selects nothing** (as in most modern games). A group's button
  selects its thing, then acts. While no panel is open the selection is the NPC the player
  stands by (the 巡捕 leading them first, else the nearest; nothing when none is near), so
  the 背包's 给 and 画符 go to whom the player stands by; a landmark, corpse or floor item
  the player chose stays selected while it is in reach.
- The rules are unchanged: each action still checks what ES2 checks (the same room,
  present()); the HUD only offers it within reach. The confirm key still opens the nearest
  door or service.

## 天驼关 C: the 黄石穿林路, the mirror and the 竹林道 (2026-10-10)

The plan's C (「天驼关 A」 below, owner Q1: repaired). What each LPC function became is in
[CANYON_CONTENT](CANYON_CONTENT.md#the-竹林道-c); it follows the LPC except:
- **Q1: canyon2.c gets its way west** (source_fixes); the 黄石穿林路 joins the pass map, the mirror is
  a passage into a map of its own (梦幻迷境通道 and the 竹林道), whose upper and lower ways are drawn
  closed (dream/tmp.c, evil/tmp.c: 整修中，请往回走:P, not placed); the stone room is a map of its own.
- **默认: while the gap stands open the stone offers only 进去.** bamboo3.c's move stone took the 20
  gin, 60 kee and 20 sen again and said nothing (the cost comes before its `exits/enter` check).
- **默认: the bookcase gives a 书匣 whenever no 悟疾风劲竹书 exists anywhere** (the book's F_UNIQUE,
  which the mudlib never defines, so parry_book.c did not compile and ES2's search failed; flagged
  `unique`, as 青石村's jade; npc/obj/parry_book.c, a copy nothing places, comments F_UNIQUE out).
  train.c's got (set_temp on the room) is not kept: only ES2's clean_up() forgot it, unloading the
  empty room, so the bookcase gave again some time later; here it gives again once the book is gone,
  the same before and after a Continue.
- **A carried container shows what it holds** (观察: 里面有：, look.c), each with 取出 in the 背包
  (get.c's get from), and takes what is put in it (放进…: put.c looks on the player first); before,
  only one lying in reach opened. The 书匣 is made with the book inside it (slipcase.c's create()).
- **Stays as ES2:** the push spends no force (do_move() only checks force, max_force and
  force_factor); it is asked first only when its cost would knock the player out (owner's rule).
- **Global (data):** an act's `at_least` (force, max_force, force_factor), `room`/`not_room` and
  `set_room`/`clear_room` (a flag of the act's room, as its own set()/set_temp(); by zone; not
  saved) and `exists` (an item of that blueprint anywhere in the world); an item's `contains` (only
  for items an act gives yet: the catalog refuses it on a room's, an NPC's or a vendor's). An act's
  gift too heavy to carry says that it lies at the player's feet, as an NPC's does.
- **Save:** no new fields, nothing moved: the world content revision stays SOURCE_ENTRY_CANYON_V1.

## 天驼关 B: the 印鉴 chain (2026-10-10)

赫造基's secret, the oath at the smooth wall, the 后备兵's two 印鉴, 严廷殷's 古剑. What each LPC
function became is in [CANYON_CONTENT](CANYON_CONTENT.md#the-印鉴-chain-b); it follows the LPC except:
- **Owner (Q3, plan): the oath is a button**, 光滑的山壁 · 发誓：我爱东方故事II, there only for one
  赫造基 told (canyon4.c's add_action() answered nobody else: 什么?). The second accepted wording
  (我爱安尼席洛特尔) and the 不要吵 line for wrong words went with the typing; the command hint
  (swear) is dropped from his secret (水烟阁 B's ruling on hints for buttons). **默认:** the
  button's point on the map has no diamond (a secret; the 光滑的山壁 caption marks the wall).
- **Deviation (默认, asked in the PR): once he gave the real 印鉴, the 后备兵 keeps money**, as he
  says (如果是钱的话，我先没收了。); seller.c returned 0 for it, so the player read that he took
  it and then had it back. Anything else he still refuses (其他的东西我都不要).
- **The two 印鉴 are told apart by what they are.** general.c and seller.c compare names, and the
  real one's differs only by its colour (HIY); item names have no colour yet, so the real one
  reads 印鉴 like the fake (its long says 泛著黄光) and the rules name the item.
- **Stays as ES2:** seller.c's violate_unique() is defined nowhere in the mudlib (0), so its
  你来晚一步了 branch never ran; no_sell is read by nothing (the hockshop takes the fake for its
  value); 严廷殷 keeps the real 印鉴 and gives a 古剑 for each one he is given.
- **The flags are saved** (owner's rule after 乔阴 B): 将军/kick until the swap; the 后备兵's check
  is his memory (saved, made anew with a new 后备兵). **默认: Get_seal keeps him from selling
  again only while the player still carries the fake, or once he swapped it**: ES2 forgot it at
  the next login, and saved for good it would shut out for ever one who gave the fake away or
  sold it before the swap.
- **Global (data):** an accept_object rule's `item` (the gift's blueprint), `giver_carries` (an
  item the giver carries) and `unset_temps` (delete_temp()); a refusal may set temps and move the giver (general.c's return 0 after
  both); a ScriptedAct's `clear_temp`; an act service with no branch for the player offers no
  button; a map layout's service may be `hidden` (no diamond).

## 天驼关 A: the pass, the camp and its people (2026-10-10)

Plan (owner, 2026-10-10: 按你的推荐来): A the clifftop, the pass, the camp and the people; B the
印鉴 chain (the 军师's secret, the swear, the 后备兵's two seals, the 古剑); C the side way west of the
pass. What each LPC function became is in [CANYON_CONTENT](CANYON_CONTENT.md); it follows the LPC
except:
- **Owner (Q1): the 竹林道 is repaired** (C). stone_forest1.c leads east to canyon2.c, which has no
  way west, and nothing else leads in, so ES2's players never saw the 黄石穿林路, the mirror, the
  竹林道 or the stone room; its 悟疾风劲竹书 inherits F_UNIQUE, which the mudlib never defines (the
  search would have failed too). canyon2.c gets the west exit; the book is an item flagged `unique`
  (as 青石村's jade); dream/tmp.c and evil/tmp.c (整修中，请往回走:P) are not placed.
- **Owner (Q2): 大队长's toll adds up.** captain.c judged each gift alone and kept any under 3000
  (30 两) with 你的诚意不够喔，再多缴点吧。, so three gifts of 10 两 were lost and listed nobody:
  what the player gives him is counted (counters `tally/军营`) until it reaches 3000, then marks/军营
  and the count is settled. The 军师's 钱太少了吧！没收。 stays (he says so).
- **Owner (Q3): the swear is a button** (B): once 赫造基 told the secret, 发誓：我爱东方故事II at
  the smooth wall (青石村 B's 接话 precedent); ES2 wanted the oath typed.
- **The clifftop is a map of its own**: the chain is no walk (Old Pine's one map per height).
  Snow's 青石官道 opens south-west where its layout had a "not open" cliff.
- **默认 (plan): the chain is asked first only when it would knock the player out** (owner's rule
  on such choices); going on, they arrive below zero and faint on the heart beat, as ES2.
- **默认 (plan): 大队长's story has no 没听说过 before it** (tell_story() returns 0; 青石村 B: an
  answer that acts ends the asking). Correction to the plan, which said the story stops when the
  player leaves the map: make_stage() tells the asker wherever they are, so leaving the map tells
  the rest at once, as 筱薇's 竹蜻蜓 (晚月庄 C); asking again starts it over (ES2 ran two at once).
- **李信's greeting** comes a second after the player walks in (the greeting delay; ES2's call_out
  was 0) and throws out only one without marks/军营, never while he fights.
- **Obvious slip:** canyon6.c's item_desc key is `mechine` while its long says (machine): the winch
  is looked at.
- **□:** 这里 (裡), 里面, 威风凛凛, 睿智 (叡); 鼎 among the 将军营帐's vessels and 挡点钱来花花 are
  uncertain (**默认**).
- **Stays as ES2:** the soldiers do not join one another's fights (nothing in the LPC; a garrison
  that turns on the player together belongs to the faction work after the regions, WORLD_RELATIONS).
- **Global (data):** an accept_object rule's `tally`; an inquiry rule's `make` (NpcMaking that only
  tells: `gives` optional); a ScriptedAct's `not_mark`.
- **Save:** world content revision `SOURCE_ENTRY_CANYON_V1` (a new region); older development
  saves need a New Game.

## 乔阴 D: 花紫会, stealing and the 县衙 (2026-10-10)

The plan's D (「乔阴 A」 below): 陆得财's 拜师 and teaching, the player's 油流麻香手 and 伏蛟功, the
player's steal, the 县衙's arrest repaired (Q1). What each LPC function became is in
[CHOYIN_CONTENT](CHOYIN_CONTENT.md); it follows the LPC except:
- **Q1 as approved: the 县衙's arrest repaired.** yamen.c's eight 巡捕 stand on the main street
  (the 大堂 is a map of its own) and walk it, from the 衙门口 to the 北门 and back, a zone each time
  their chat calls patrol(), wherever the player is on the map (ES2 stopped an NPC's heart beat
  away from players; BigWay ran on past the 北门 into other regions and skipped s_street3). One
  meeting a player with a caught steal on record catches them when random(10) < 7: crime_lv + 3,
  thief − 1; the player reads its say, 你 for their name (say() left the thief out of it), and a
  native hint; it leads them back along the street a zone a step, their own walking refused
  (嘿嘿, 还想往哪逃?!), and at the 衙门口 takes them into the 大堂 (老爷，人犯已带到，小人巡街去了。).
  Two seconds later 程不平 beats them crime_lv strokes by settle_lawsuit()'s formula, clears the
  crime and puts them out at the 衙门口. On the way ten gold or more (base_value × amount ≥
  100000) frees them, crime_lv − 3; less is refused, crime_lv + 1. Killing a 巡捕 is crime_lv + 5.
  Its gangster and 野羊山寨三寨主 checks name NPCs that never come here; 卧龙岗's marks/强盗 is no
  crime; the drum and charge are not ported. One led who flees a fight gets away (go.c's do_flee()
  took them out of the room, past its do_go(); pursuer is not modelled); a leader knocked out holds
  nobody (ES2 left them stuck behind its do_go() until it woke). Otherwise the chain holds: a
  landmark's way (the 树王坟's hole), a command that moves them and 游识 are refused with its
  嘿嘿, 还想往哪逃?! (ES2's do_go() blocked only `go`, so climbing down the hole was a free escape:
  review, a loophole); should anything still take them to another map, the leader stays behind.
- **Obvious slips fixed in settle_lawsuit():** a value it left at 1 (its effective value below the
  stroke) still took the stroke (receive_wound() to −1: the next heart_beat killed the one its
  lines carry out): it stays at 1; the beating ends when all three are left so (the faint); its
  warning (再敢犯案, 定斩不饶!) is said once, after the strokes (ES2: after each).
- **默认 (plan): stealing is asked first from one clearly stronger** (A10), as one caught is
  attacked to the death; the 偷窃 list offers what the NPC is seen to wear or wield (look.c shows
  only those) and 随手摸一样 (steal.c's pick when the name matches nothing). The steal's three
  seconds run on the map's time: they wait in a fight and end when the player leaves the map.
- **默认 (plan): 陆得财 counts only the money carried** (can_afford(): gold, silver and coins on
  the player; a bank deposit does not count); he looks the student over first (look.c's
  正盯著你看); his nod prints nothing.
- **Custody is not saved:** Save waits (战斗中或动作还没完成时不能存档。) while a 巡捕 leads the
  player and until the sentence; dying ends it.
- **伏蛟功's exerts:** serpentforce.c's exert files do not exist, so exert.c falls back to the basic
  force's (恢复气, 恢复神, 恢复精), as 步玄心法's; the plan's "no exert at all" was wrong. It is
  practised only in a room with resource/water: Old Pine's mountain stream (riverbank1.c,
  riverbank2.c) had lost its water in the port and has it back (a wineskin fills there too).
- **obj/user.c reset()** runs for the player on the rooms' schedule: a caught steal is forgotten
  and, as ES2, a point of potential comes while less than 100 is unspent (not ported before).
- **Global (data):** a placed NPC that draws its name keeps it in a save as one of its named forms
  (`<id>#name=<n>`, as items); apprentice checks `cannot_afford` (the money carried) and `looks`,
  a requirements master's empty accept_say; the chat action `patrol`, an NPC's `patrol` (route and
  `arrest`) and `sentence`; a practice's `water_fail`; thief and crime_lv in the character's
  counters (CrimeRecord); rank 惯窃 above ten caught steals.
- **Save:** world content revision `SOURCE_ENTRY_CHOYIN_D_V1` (new spawns); older development
  saves need a New Game.

## 乔阴 C: 步玄派 (2026-10-10)

The plan's C (「乔阴 A」 below): 骆云舟's 拜师 by the 桃林's mark, the 桃林's notes and ways, his
teaching, the player's 步玄七诀, 小步玄剑, 步玄心法 and 「玄羽乱舞」. What each room and function
became is in [CHOYIN_CONTENT](CHOYIN_CONTENT.md); it follows the LPC except:
- **Owner (option A, asked in #100): 风泉剑灵's chant is saved.** Its place (the stage it says
  next and the seconds till then) is kept on the NPC and goes into its memory record; it counts
  on its map's running time only, so it waits while the player is on another map, in a fight
  (as every NPC call_out) or out of the game, and goes on where it stopped after Continue, the
  time away not counted. ES2's call_out ran on while the player was elsewhere and was lost with
  a reboot. This replaces 乔阴 A's "does not survive Continue" and the plan's "stops when the
  player leaves the map"; for the other call_outs 茅山 B's rule stands.
- **The 桃林 lies apart in the peach woods** (painter): a clearing with taolin.c's six ways
  (north, south, west, east, northwest, southeast), each a path that leads back into the
  clearing from its far side, the 字条 on the tree in its middle; the way in is a path off the
  曼雩台's east edge, and the woods keep the platform out of sight. taolin.c's exits all name the
  room itself, west too: there is no walking back to the platform.
- **Every walk out of the clearing is a step.** ES2 counted only `go <dir>` (its n/e/s/w
  aliases): a bare `east` went to go.c directly and changed nothing, which a walked map cannot
  show.
- **默认 (review): the note the 字条 shows is saved** (msg_no, the room's, drawn anew after each
  way; a save record `maze_notes`), so Continue shows the line the player read; ES2 drew a new
  one when the room loaded again, and a way walked on the old line silently cost three steps.
  Other room state (counters, doors) is still not saved. taolin_steps is the character's (set(),
  saved: CharacterState `counters`).
- **默认 (plan): 放弃 in the 桃林 wakes the player in the Inn**, as in the 神秘洞穴 and 绝地.
- **As ES2:** his refusal (你还是先走一趟东边的桃林吧) marks 书生 and ends the request (山烟寺 C);
  whom he takes loses marks/书生 and marks/桃林, so the way east is shut again for his own; his
  smile is an emote (nothing printed). 「玄羽乱舞」 needs kee 70 and force 70 above max_force.
- **perform.c's `<martial>.` form** (global): a file no weapon use reaches is offered through
  行动 or 轻功 (help perform: perform move.reflexion; 骆云舟's perform move.hasten), so
  「玄羽乱舞」 is on the battle panel with 步玄七诀 enabled for either, whatever is in hand. The
  weapon arts' 字诀 stay offered only with what is in hand (封山剑法 bare-handed as 招架 offers
  nothing, as before).
- **Global (data):** a `note_maze` landmark (the notes and their ways, the counter its way in
  sets, the step rule, the way out and its mark); an apprentice check on a saved mark, with the
  marks a refusal gives and those the recruit clears; a town map's neighbours may be joined by a
  passage on the map instead of a shared edge.
- **Save**: the player's `counters`, an NPC's `memory.chant` and the root's `maze_notes` are
  optional records; world content revision `SOURCE_ENTRY_CHOYIN_C_V1` (the 桃林 moved: a save
  standing where it was would only fail as an invalid position); older development saves need a
  New Game.

## Save: the player's set_temp() flags (2026-10-10)

**Owner** (after 乔阴 B): the player's set_temp() flags are saved. ES2 cleared them at logout,
leaving a multi-player world; a single-player Continue only resumes, and losing a chain's
progress there read as a bug (芳绫's 手镯 secret gone, the 竹蜻蜓 to make again; a second
bracelet from the 碧纱橱; 雨梅's cup kept; 玄智's 跪下受戒 to ask again). They are written in
the player's save record (`temps`, only when there are some). This replaces the rule of
晚月庄 A (temps not saved) and its uses since (山烟寺 B's pending/join_bonze). Unchanged:
set_temp("mind_bug"), the link to a 观想虫 a save leaves out (茅山 C), and a 拜师 answer under
way.

## 乔阴 B: the town's secrets and 姑射山 (2026-10-10)

The plan's B (「乔阴 A」 above) with the owner's Q2 and Q3 as approved and the plan's defaults:
放弃 in the 神秘洞穴 wakes the player in the Inn, so the lift is not asked; the lift's lines are
told to the one who falls (ES2 told them to the room without them and wrote `$N石狮子又…` in the
cave); the 云幡 takes the player down to the 丹炉 (ES2 opened the way for one second; its thunder
strikes only one still on the 云台, so it never reaches them); the 缚仙绳 only where a 仙鹤
stands, asked first when its 50 sen would knock the player out; the vine is not asked (a fall
into the 寒谷 does no harm); the 荷包 is given once. What each room and function became is in
[CHOYIN_CONTENT](CHOYIN_CONTENT.md). Besides:
- **Q2: the hole under the 树王坟** is a landmark (爬下去) with a native line (你攀著粗糙的洞壁，
  爬进了树桩中间的大洞。); the hollow's 洞壁 leads up as in ES2.
- **Q3: ghosts are unseen** (ghost.c, shadow.c is_ghost()): not drawn, picked or walked into;
  they attack and are listed in the fight, though not as a target to choose (present() finds no
  ghost); the player's turn passes when random(100 +
  perception) < 100 (combatd.c fight(), any attacker that is no ghost), told as
  你看不见对手，无从下手。 (the owner's native line; ES2 said nothing); dead, a ghost leaves no
  corpse and what it carried falls (chard.c). As ES2, go.c's lines name a 孤魂野鬼 that wanders in
  or out (only look and present() hide it), and its 布条 cannot be reached before 鬼门关 (#13).
- **Owner: the 仙鹤's attack** (crane.c has no verbs): beast.c's default action 攻击$n的%s，%s
  never filled its two %s (combatd.c replaces only $N, $n, $l, $w): the first is the limb hit, the
  second is left out (仙鹤攻击你的左臂！); no damage, no damage type (伤害).
- **Owner: only the hermit's books go back** as the player walks out of the 草堂, whatever they did
  before; with none, 你离开草堂!. ES2's valid_leave() took every `book` once one had been
  scratched (its set_temp("choyin/\112\151", 0) clears another flag than choyin/书) and
  looped forever on one carried without that flag.
- **The 武官 takes one 桃木箱 in his life** (chest_found, an object variable); another is not
  taken (accept_object() returned 0); his rumors, 箱子 and 桃木箱子 answers go with the first,
  as the 荷包's 游晋 and 心事 do (delete("inquiry/…")).
- **Owner: an NPC's memory is saved** (Save/Continue restores exact state). What an NPC's
  object variables hold goes into its save record (`memory`): every flag as it stands (the
  武官's chest_found, a deleted topic, a toll-taker that fought the player, a dog following
  since its bone, the drunk's has_alcohol, a hunting 观想虫's hatred), a chat chance a
  function changed (woman1.c), the 采药老者's pills left and a thief's times caught. One made
  anew (its room's reset after it died) starts from create() again, as ES2. This replaces
  "object variables count anew" (4E) and the "Continue forgets" of the dog (A11), the
  robbers and the thief (3A) and the drunk (青石村 B). Unchanged: the player's set_temp()
  flags (晚月庄 A; saved too since, see above), a call_out under way (a greeting, a making;
  the 剑灵's chant is saved since 乔阴 C), room counters and doors.
- **Obvious slips fixed:** lionroom.c's smell lacked braces (the first thing in any pack blew
  its carrier out, the line only for the grass): only the 忘忧草 does it, else
  你身上没有忘忧草啊。; goldenrope.c's tie lacked them too (the plan's 仙鹤 default covers it).
- **As ES2:** the 寒谷's vase takes the player out with no orchid in hand (the valley's only way
  out); stove.c's flame line for 桐柏山 has nobody to hear it (only the 云幡's way in loads the
  room).
- **陈剑秋's letter** is the giver's (master_id); 陈天星 takes it in 京师 (#12): a reminder test
  fails once he stands without his accept_object().
- **咒剑王禅 against a ghost** (taoist/sword.c hit_ob(), the 茅山 A reminder): random(max_atman)
  above the ghost's atman / 2 wounds its gin by query_spi() and heals the wielder by as much,
  with its HIY line; otherwise random(query_spi()) adds to the blow.
- **Global (data):** an NPC's die() that makes an item into it (`die_carries`); an item that
  records who got it (`master`: its master form is the player's); a weapon's hit_ob() against
  ghosts (`ghost_bane`); topics an NPC deletes (`forgets`); a room that answers a carried
  item's command (`refuses`); `takes_back` of several items; a vine's `below`; the `lift`
  landmark; an NPC's apply/<skill> (shadow.c apply/blade); a new item draws its name.
- **Save**: world content revision `SOURCE_ENTRY_CHOYIN_B_V1` (new spawns); older development
  saves need a New Game.

## 乔阴 A: the town, its outskirts and its people (2026-10-10)

Owner-approved plan (2026-10-10, 「Q1Q2Q3都按推荐的来」): four packages — A draws every map and
places the people with their arts; B the town's secrets and 姑射山; C 步玄派; D 花紫会, stealing
and the 县衙. The plan's three questions, answered with their recommendations:
- **Q1 (D): the 县衙's arrest is repaired.** ES2's never caught anyone (the 巡捕's patrol fails
  at its first step; 程不平's search runs only with a player in the unreachable 大堂). The 巡捕
  patrol the main street; one meeting a 「贼」 (a failed steal: −1 a reset, halved at death)
  catches them seven times in ten and leads them to the 大堂; 程不平's boards by his formula, then
  the crime is cleared and they are put out at the 衙门口; ten gold or more frees them, less adds
  a crime. Paying the 卧龙岗 toll is no crime (modern fix: its line says one killed). The drum and
  charge are not ported.
- **Q2 (B): the 树王坟's hole is repaired**: a way down to the hollow, and up again; the 武官's
  桃木箱 there gives the 白杨经.
- **Q3 (B): ghosts stay unseen, as ES2**: not drawn or selectable; listed on the battle panel when
  they attack; perception decides the player's turns (native line 你看不见对手，无从下手。); the
  孤魂野鬼's shroud stays out of reach until #13.
Defaults of the plan (owner may veto): 放弃 (wake in the Inn) in the 桃林 and the 神秘洞穴, so the
lift is not asked; the lift's lines fixed (你从洞口掉了下去); the statue's lost character 「举」
(uncertain); the 云幡 takes the player down to the 丹炉 (ES2 opened the way for one second); the
缚仙绳 only where a 仙鹤 is, asked first when its 50 sen would knock the player out; the vine not
asked; the 草堂 takes back only the hermit's books; the 荷包 given once; stealing asked first from
one clearly stronger (A10), the things seen plus 随手摸一样; 陆得财 counts only the money carried;
the 老者's growth not saved; the 剑灵's chant stops when the player leaves the map (owner, 乔阴 C:
it waits and is saved instead); the names
短歌刀法, 乐器, 偷窃; wimpy still not modelled. Not placed: 北冥大鹏, the 石室, d/jail's guard,
beggar/wineskin.c.

**Owner, in the A session (three plan claims rested on dead LPC):**
- **The 北门's north stays shut, as ES2.** n_gate.c's north and oldpine/spath4.c's south are both
  commented out (the plan said one way); the 1995 map put 乔阴 south of the pines, the later
  南岸 took the way in.
- **The hotel guards' accept_kill() runs as meant** (no mudlib code calls it; deviation): when
  the player attacks one, the others of its kind there say 干什么？！ and join; it calls for the
  law (有强人打劫哪... 快去报官！), the player gets vendetta/authority (守城官兵 and 县城官兵 attack
  on sight) and a native hint says so. **The 红衣武士 likewise** (水烟阁 A had kept its
  accept_kill() dead): his line and powerup, the other guard there joins, and every 红衣武士 holds
  the grudge (vendetta/waterfog_guard, their vendetta_mark; killing one marks too), with a hint.
- **The crone's relay_ask() is said** (called by nothing in ES2; deviation): a topic she has no
  answer for (名字, 传闻) gets the deaf line and the basket; 年龄, 这里 and 忘忧草 as authored.

What each room and LPC function became is in [CHOYIN_CONTENT](CHOYIN_CONTENT.md); A follows the
LPC except:
- **Obvious slips fixed:** 玄羽乱舞's 但是$N找不到机会出手！ follows only a round without a blow
  (hasten.c tests a void fight() and printed it every round); the 老者's doubled 说道 and his ghost
  story's full-width ＄N (reads 你).
- **Asking a vendor about its goods (大饼, 包子, 糖葫芦) lists them, as the code means** (the 4D
  precedent, guard.c ask_me): dbase.c calls do_vendor_list() with the vendor itself, so
  get_vendor_list()'s id() check failed and ES2 printed only ask.c's line.
- **The vendors' lists leave out the English ids** that `list` printed (大饼：25文钱); 游晋's English
  topic `trouble` reads 心事 (the player picks topics from a list); the 老者's ghost story shows its
  fake room without English (出口是北边和南边, 黑无常); the crone's (list) is dropped from her line, as
  萧辟尘's command hints were (the 价钱 is the topic list).
- **The 银簪 is worn in the hair** (inherit HEAD and F_DAGGER: one item both armor and weapon is not
  modelled; the girl and the lady wear it).
- **默认: the cranes cannot be fought yet**: a beast without verbs gets beast.c's default action
  with two unfilled %s (攻击$n的%s，%s); B decides it with the 树冠.
- **风泉剑灵 comes at the 曼雩台** (its master never leaves it): a summoned spawn there, saved as any
  NPC; its chant does not survive Continue (call_outs are not saved; owner, 乔阴 C: it is now).
  **默认: one at a time**:
  while it stands, 骆云舟 killed again keeps his sword in his corpse (ES2 made a second soul); a
  player killed holding the sword in the town brings it to the 曼雩台, on another map the sword
  stays in their corpse (ES2: a soul where the killer stood; a lasting NPC cannot yet come off a
  spawn).
- **The 老者's growth** (the plan's "not saved"): his save() file is not ported, so his room's
  reset makes a fresh one; Save/Continue keeps his combat_exp and applies like any NPC's, while
  his pills, an object variable, count anew (4E).
- **Global (data):** an item's drawn name (book.c) is a named form of its own (`name_pick`); a
  martial art's own hit_ob() that wounds (spicyclaw.c) is data (`hit_wound`); an NPC's chat
  special that attacks (hasten.c) attacks as the player's perform does.
- **Maps (painter):** fourteen; the 衙门's courts, the hollow under the stump and every room only
  a verb reaches (树冠, 山洞, 云台, 寒谷, 丹炉, 神秘洞穴) on maps of their own; the 桃林 east of the
  曼雩台, behind 骆云舟 (no_mark 书生).
- **Save**: world content revision `SOURCE_ENTRY_CHOYIN_V1`; older development saves need a New
  Game.

## 山烟寺 C: 八识神通's 神通 (2026-10-09)

What each LPC function became is in [SANYEN_CONTENT](SANYEN_CONTENT.md); it carries out the
plan's defaults (山烟寺 A: Q3, 心识 only on one lying unconscious, 心识 and 空识 asked first) and
the three questions #94 left unanswered, and follows the LPC except:
- **默认 (#94 Q1, global): a master's refusal ends the 拜师 request.** apprentice.c kept a
  refused request pending for every master, so asking again (after doing what the refusal
  said, e.g. 剃度) only heard 对方还没有答应 until 取消拜师请求. Now a check the student falls
  short of (at once, or in a later answer, also one said to an empty room while the student
  had walked off), a master that refuses everyone (安妮儿), one that takes the student for a
  traitor (绝尘子, 瑷伦) or a failed test (瑷伦's lashes, 於兰天武's blows) ends it; the next
  拜师 asks anew (and the traitor's attack is asked first again).
- **默认 (#94 Q2, Q3)**: 跪下受戒 needs 玄智 awake, and 疗伤他人 is for others only (both as
  built in B; lifeheal.c without a name healed its caster).
- **Owner (Q3): 游识 offers the NPCs the player has met.** A kind of NPC met in the player's
  room (an NPC's init() seeing them, or it coming in, a wanderer too) joins
  CharacterState.seen_npcs, saved, in the order met; one conjured, raised or summoned does
  not. The question lists their names, one button each, and 中止施法 (with nobody met yet it
  says 你还没有见过什么人。); a name goes to one of that name in the world now and awake (MudOS
  find_living() skips one whose commands unconcious() disabled), on the player's map first,
  then map by map, beside it (also in a room with no spawn marker; never on a passage). ES2
  asked for an id and find_living() searched the whole world. Nobody of that name now (dead,
  lying unconscious, not come back): 你无法感受到这个人的灵力 and the question again, as ES2,
  and nothing spent; so too, natively, when no free spot beside them is found.
- **Owner: the 神通 are used outside fights.** conjure.c lets 空识 and 心识 run in one (游识
  refuses): 空识 would spend the turn on potential, and 心识 could only wake the enemy being
  killed, as a monk has nobody on their side. The battle panel offers neither; heart_sense.c's
  busy 3 in a fight is ported but not reached.
- **默认 (plan): 心识 only on one lying unconscious.** heart_sense.c also "revived" one awake,
  and combatd.c then said 慢慢睁开眼睛 of them. It is asked first every time (it may always
  fail, and below 102 max_atman always does), with the odds and its cost.
- **Owner: 游识 is asked first when its 30 gin would knock the player out** (the plan named
  心识 and 空识; drift_sense.c takes the gin once the name is found).
- The lights the room sees (一道耀眼的光芒…) are the others' lines: the player reads their own
  line and then the room they arrive in, as in ES2.
- **Save**: seen_npcs is written only when there are some; older saves load (no revision bump).

## 山烟寺 B: 山烟寺 the family (2026-10-09)

What each LPC function became is in [SANYEN_CONTENT](SANYEN_CONTENT.md); it carries out the
plan's defaults (山烟寺 A: 剃度 gives a 法名, asked first; 请你到尼庵 and 震荡 for the lost
characters) and follows the LPC except:
- **Owner: 剃度 is asked first**, saying the name becomes a 法名 (one of 空明圆净虚悟方渡慧法 at
  random before the first character of the name: ES2's name[0..1] was one character in its
  double-byte text; a name in letters gives its first letter, where ES2's two bytes took two). 跪下受戒 is a button on 玄智's 打听 panel once 剃度 or 出家 asked him to
  kneel; the flag it needs (pending/join_bonze) is a temp, forgotten by Continue (晚月庄 A).
  The 法名 and class bonze are saved.
- **默认: 跪下受戒 needs 玄智 awake.** ES2's kneel was an add_action: one could kneel before a
  master lying unconscious, be shaved and renamed while his say printed nothing.
- **玄智's ten a day never run out** (plan): recruit_apprentice() lowers the misspelt
  apprentice_availavble, so 老纳今天已经收了十个弟子 is never said (as 林忌's and 蓝止萍's).
- **Owner: 疗伤他人 works on the selected NPC** (a HUD button beside 驱尸's place, shown when
  莲华心法 is the enabled force), neither side in a fight. ES2's `exert lifeheal` without a name
  worked on oneself (exert_function()'s default target); doc/skill/lotusforce gives it as
  医治他人所受的伤, and the game does not offer it on oneself, on the 武学 page or in a fight.
- **八识神通** is learnt and enabled as 法术 now; practising it gives nothing (essencemagic.c
  has no practice_skill()); its 神通 came with 山烟寺 C.

## 山烟寺 A: 泓水, 日照山 and the temple (2026-10-09)

Owner-approved plan (按照你推荐的来, 2026-10-09): three packages — A places the region (the
maps, the people with their arts, the boat, the kitchen), B 山烟寺 the family (剃度, 玄智's
teaching, the player's 大乘佛法, 诵经, 流云杖法, 莲华心法 with 疗伤他人, learning 八识神通), C the
player's 神通 (空识, 心识, 游识). The plan's three questions, answered with their
recommendations: **the boat carries whoever pays** (Q1, below); **front_yard.c is repaired**
(Q2: it names d/sanyen/npc/monk_guard.c, which does not exist, so ES2's yard stood empty and
朱鸿雪's 护寺武僧 could never be found; the two 护寺武僧 of u/cloud/npc/monk_guard.c stand there,
their look a 知客僧's word for word); **游识神通 goes to an NPC the player has seen** (Q3, C).
Defaults of the plan (owner may veto): 剃度 gives the player a 法名 (asked first, B); the names
流云杖法 and 诵经; the lost characters (请你到尼庵, 震荡, the donor 克某某); the plaques and
梦忆柔's voice word for word; the cook guards the steamer; 心识 and 空识 asked first when they can
knock the player out (C); not ported: the bulletin board, valid_startroom, monk_waiter.c and
the 黄铜禅杖 (placed by nothing), the 独眼头陀's pursuer.
What each room and LPC function became is in [SANYEN_CONTENT](SANYEN_CONTENT.md); it follows
the LPC except:
- **Owner (Q1): the boatman's boat takes whoever pays across** (deviation). ES2 waded the
  river both ways (northriver.c's ferry is dropped by replace_program(ROOM)); boater.c took
  anything worth 2 coins, said 客官可以过江啦！ and 船夫拉过条小船，你走了上去。 and left the payer
  on the dock. Here the same fare puts the player at 江南渡口 after his lines; **owner: he
  asks what he takes** (过江, 摆渡: 交两文钱; ES2's cross_river() said 交五两银子); less is refused with 这么少？我还要养家呀！. The mark is not kept: each crossing
  one fare. The river is still waded both ways; no boat waits on the south bank (none in ES2).
- **默认: the 金门 starts open.** road1.c creates it open, temple.c DOOR_CLOSED; check_door()
  gives the room loaded second the first one's state, and whoever comes up the road loads
  road1.c first; the hall's text says 两扇敞开的金门.
- **Global rule: an NPC's random_move() in a fight walks out of it** (go.c; d/sanyen's 跛僧人
  and 独眼头陀): 往X落荒而逃了。, then it and everyone in the fight stop fighting each other for
  good (ES2's remove_all_enemy() kept the killer marks, so one killing it attacked again on
  meeting: here, as for every NPC but a conjured one, a fight's end forgets them). It is in
  the room it went to at once, so nothing that reaches the room (a roar, a call for help)
  finds it and the battle panel drops it; its body walks there once the fight is over. The
  fight goes on without it, and it counts for no side. A way go.c refuses (busy, a shut door,
  beyond its range) says nothing. A fight its walking out ends reads 战斗结束。 (not
  双方都停了手). An emote in a fight prints nothing, as outside one.
- **accept_fight rules test the challenger's class**: 玄智, the 护寺武僧 and 化缘和尚 answer a monk
  otherwise. **化缘和尚 can be fought** (流云杖法, 莲华心法).
- **The steamer** (kitchen.c): open and take are refused while the cook stands there; five
  馒头 a reset, then 梦忆柔's voice. **默认: a cook lying unconscious says nothing and stops
  nobody** (present() found him, and his 施主偷东西是不好的行为哦 was said by a man out cold:
  a line that contradicts what happens); in ES2 only killing him opened the steamer.
- **Two regions**: 日照山 (the river, the south bank, the path, the gate, the tunnel) and 山烟寺
  (inside the gate); the place reads 日照山 · 江南渡口.
- **默认: the skills' names** (to_chinese()'s dictionary is not in the mudlib): cloudstaff 流云杖法
  (流云轩, its 浮云 and 穿云 moves), chanting 诵经; 大乘佛法, 莲华心法 and 八识神通 are the source's.
- **Save**: world content revision `SOURCE_ENTRY_SANYEN_V1`; older development saves need a
  New Game.

## 晚月庄 D: 晚月庄 the family (2026-10-09)

What each LPC function became is in [LATEMOON_CONTENT](LATEMOON_CONTENT.md); it carries out the
plan's defaults (晚月庄 A: 蓝止萍's ten a day never run out, her 暧昧 line word for word, 瑷伦's
traitor and her lashes asked first) and follows the LPC except:
- **默认: 瑷伦's title comes with her taking the player.** elon.c sets 晚月庄第一代弟子 right after
  the recruit command, which only offers when the player had not asked her first: they carried
  the title outside the family, and the 拜师 that took the offer renamed them 晚月庄开山祖师
  (assign_apprentice() gives generation 1 that title). Here whoever she takes, either way, is
  晚月庄第一代弟子, and an offer changes no title.
- **Her test is offered only to whom it tests** (a woman of 100000 combat_exp; asked first, as
  於兰天武's): do_accept() said 老身不收男徒! to a man and nothing at all to one short of 100000;
  their 拜师 tells them why.
- **默认: 运功意寒睨 aims at the current target**, else at offensive_target() (one of the first
  four enemies at random): ES2's `exert chillgaze <target>` named one, the button names none,
  as 字诀 do. Its lines name the target.
- The first lash not stood says nothing (sigh and shake are emotes, 4E): the lash, then the fall.
  瑷伦 gives no class (elon.c keeps recruit_apprentice()): her apprentice keeps theirs.
- The questions about a master say 她 for a woman (蓝止萍, 瑷伦), and so does recruit.c's offer
  (就向她拜师); they said 他 for everyone.

## 晚月庄 C: the manor's secrets (2026-10-09)

What each LPC function became is in [LATEMOON_CONTENT](LATEMOON_CONTENT.md); it carries out the
plan's defaults (晚月庄 A) and follows the LPC except:
- **筱薇 hands a second 竹子 back** (plan default): 我已经帮你做一个竹蜻蜓了呀!, then 蓝筱薇没有收下。
  (ES2 kept it). She finishes the 竹蜻蜓 wherever the player goes on the map (tell_object(),
  move(who)); **leaving the map, the rest is told at once and the 竹蜻蜓 given** where they
  arrive, since the map's time stops while they are away (茅山 B's rule drops other call_outs).
- **The temps** moon/竹子, moon/竹蜻蜓, moon/问题二 and latemoon/手镯 go with Continue; marks
  dance-book (莫欣芳's answer) is saved (plan).
- **A carried item's own command is a button** (祈祷, 跳「春宫怨」, 用火烧) for what the player
  carries, outside fights as the inventory is (A8); ES2 let one pray out of a fight. Pray and
  春宫怨 are **asked first** when their 50 sen would knock the player out (owner's rule); 取消
  goes back to the 背包. The bracelet's info (使用 (pray start)…) is the button itself.
- **Global rule: a move to another map ends an act** (the steps after it would act on the map
  left behind; the catalog makes it the last step), and an NPC's greeting moves the player only
  on its own map.
- **Searching is a button** on the 碧纱橱 and the 石床, offered before the player knows (ES2 let
  anyone type search; without the secret it finds nothing). Command hints in lines stay ((search
  bracelet)), as A kept them.
- **默认: 无名老妇's `trouble` is asked as 心事**: an English word among the topics read as a bug;
  the answer is hers word for word.
- **默认: the skills' names** (to_chinese()'s dictionary is not in the mudlib): music is 音律
  (mysterrier.c's 音律之学), move 基本行动 (enable.c calls the use 行动).
- Her force (a 晚月庄 member below 160 max_force) raises max gin, kee and sen at once (A7).

## 晚月庄 B: the women's quarters and the rooms' own commands (2026-10-09)

What each LPC function became is in [LATEMOON_CONTENT](LATEMOON_CONTENT.md); it follows the
LPC except:
- **Owner: no powder on leaving the changing room.** bathroom1.c's valid_leave() (rose_poison
  5 for whoever is not a 女性) is dropped by the replace_program(ROOM) that ends its create(),
  so ES2 never ran it (as northriver.c's ferry). 阮欣郁's own powder and kick are ported.
- **A man is asked first** (owner, plan Q2) walking from 内厅穿堂 into the changing room and
  before bathing, with the room's 此处是禁止男性进入; on 确定进去 he is put just inside the
  curtain. Other rooms are not asked. Ponder is asked first when its 50 sen would knock the
  player out (plan default).
- **Owner: the pistils gone** say 西府海棠上的小花蕊已经被摘光了。 (moonc.c said nothing).
- **默认: a pistil eaten by one not poisoned gives no poison.** flower.c set rose_poison to 0
  for anyone below 10, and rose_poison.c makes a 0 flare once (20 sen of wound) right after
  the cure; one poisoned below 10 still has that last bout.
- **A greeting acts on a player lying unconscious** (present() finds them), its lines unread;
  before, nobody greeted an unconscious player. One it takes below zero there dies (std/char.c
  heart_beat(): !living() → die()), and 阮欣郁's kick moves a body too (ob->move()). Her kick
  comes a second after a man walks in, before he can cross the room: a man reaches the pool only
  while she is down.
- 雨梅's latemoon/茶 is a temp: not saved, so after a Continue she gives another cup and a cup
  carried out without the flag is kept (the plan's temps).

## 晚月庄 A: the manor, the garden, the tower and the paths (2026-10-09)

Owner-approved plan (同意，都按你推荐的来, 2026-10-09): four packages — A places the region,
B the women's quarters and the rooms' own commands, C the secrets (竹蜻蜓/玛瑙手镯, 舞曲谱,
杀手令牌, 芙云's 密函), D 晚月庄. The plan's three questions, answered with their
recommendations: **sroad1.c is repaired** (deviation: its missing quote kept ES2 from
compiling it, so the back gate and the path's north-west led nowhere and the grove was a trap
while the tunnel to 山烟寺 is closed); **a man walking into the changing room or bathing is
asked first** (B), other rooms are not; **芙云's letter and 蓝止萍's line stay word for word**.
Defaults of the plan (owner may veto): not placed, as LPC: 颜慧如 (her list names files that
do not exist), 蓝小蝶, 凤姐, 娟姐, 天龙, the copies; the 大蟑螂 (only a mistyped `take` made one);
a floor's dances are the ones the player heard named, any other 不得要领 with its sen spent, a
dance that would knock the player out asked first; 筱薇 hands a second 竹子 back (C); the temps
(茶, 竹子, 竹蜻蜓, 问题二, 手镯) go on Continue, mark/dance-book stays; 瑷伦 kills a member who asks
her as 叛师 (asked first) and her three lashes are asked first; 蓝止萍's ten a day never run
out; the 杀手's pursuer is not ported; a closing NPC shuts the door the player came by.
What each room and LPC function became is in [LATEMOON_CONTENT](LATEMOON_CONTENT.md).
- **The dances come with A**, not B: the second 密室 is left only by dancing 「西出阳关」, and
  flower1.c leads into the secret rooms one way. A `dance` service on each 八卦图: the
  gender's sen check and cost (男 100/50, 女 50/30; miroom 男 100/80, 女 50/50), then the
  dance's line, 有凤来仪's 50 sen more and the move, or 不得要领. The dances are known from
  雨梅's 学舞 and 昭仪's 有凤来仪 (`mark_asker`) and the 书房's 湘绣舞曲图 (a look landmark that
  `teaches` both). Only 有凤来仪 can knock a woman out (30 + 50 from 50). **The second 密室's
  八卦图 offers 西出阳关 to anyone** (**默认**, a step `always`): it is the room's only way out,
  and one who walked south from 内厅穿堂 or danced 有凤来仪 without hearing of it would be shut in
  for good (ES2 let anyone type `dancing out`).
- **Five maps**: the manor (front and rear halls, 36 rooms), the two secret rooms (one way
  in from 内厅穿堂), the 湘园, the front tower's upper floor (stairs from both rear corridors,
  the 观景台's jump down to the 湘园's forecourt) and the hills (the paths and the bamboo
  grove, its five clearings joined by passages as 青石村's 迷阵). 绮云镇's west end opens onto
  the cobbled path; the tunnel east of sroad5 stays closed until #8.
- **东方神教 is not a joinable family** (安妮儿 refuses everyone and is no F_MASTER; 朱鸿雪 only
  gives quests): ROADMAP counts 晚月庄 alone, ten families become nine.
- **Two doors with two names**: eroad1.c and wroad2.c call theirs 雕饰厢门, eastroom.c and
  westroom.c 雕饰房门; a door has one name, the corridor's (**默认**).
- **One colour a line** (**默认**): rose_poison.c's HIG 你中的 HIR 火玫瑰毒 HIG 发作了！ is
  HIG; the dances' 「曲名」 in HIM and the lanterns' BRED HIW lines are plain.
- **Lost characters** (text_replacements.json, **默认**): 椅搭 (红楼梦's chair cover),
  白石崚嶒 (红楼梦 ch.17), 稻香榭 (its text is 稻香村), the upcenter.c punctuation; uncertain:
  雕饰绣栏, 蜿蜒盘旋, 彩霞江水纹, 神龛佛像, 供盘塔磬.
- **意寒功's hit_ob()** (iceforce.c) after std/force.c's: when that returned a number and
  damage_bonus plus it is above 0, random(query_skill("iceforce")) over the sum wounds the
  victim's kee by it, sets iceshock to force_factor / 3 and adds nothing (the hook returns
  its line). **意寒睨** for NPCs (蓝止萍's chat): busy 4 first, then 50 force and 20 sen.
- **NPC ids keep a region subdirectory** (`latemoon.npc.room.servant`): before, a second
  file of one name merged into the first; a clash is now an import error. A file ES2 could not
  compile may be repaired by an override's `source_fixes` (a recorded deviation only).
- **Global rules**: `rigidity` counts in bash_weapon() (the whips are the first items with
  one); `no_drop` refuses drop, give and put (drop.c's own string when it has one).
- 朱鸿雪 can be fought (雪影剑法, 雪影心法); a fight with her stays a fight to the death
  (她不切磋).
- **Save**: world content revision `SOURCE_ENTRY_LATEMOON_V1`; older development saves need a
  New Game.

## 积压问题的处理（2026-10-08，owner 按现代游戏标准批准）

Owner 一次处理了各 PR「待你决定」段里积压的问题。规则（owner，2026-10-08）：**PR 合并时 owner 没有
回答的问题，按 PR 里的推荐方案生效，在这里标「默认」；owner 随时可以否决**，否决后改回并更新记录。
每项一句：来源 PR、ES2 原行为、我们的做法。实现放在括号里写的 PR；在那之前记作 STATUS 的已知问题。
两项等 owner 完整试玩后再定，列在 [STATUS 的「待决定」](../production/STATUS.md#待决定)。

**要做的**
- **A1 装备按重量扣轻功**（#75；单独 PR，**已实现**）：ES2 std/equip.c 对重量 ≥ 3000 而自身没有 dodge 的武器
  扣 重量/3000 轻功，11 个 std/armor 基类对重量 > 3000 的防具扣同样多并覆盖原值，我们只对布衣类做
  了（长剑应 −2、玄苏剑 −5、黑铁杖 −23、盾 −2、天兵战甲 −16……）；做法：实现这两条规则，物品详情
  显示「轻功 −N」，武学页的有效等级随之变。导入器记下 create() 调的是哪个 setup()（`weight_dodge`），
  规则在加载时算，NPC 的装备一样计入战斗，松林的藤蔓（epath2.c 的 query_skill("dodge")）也算；没调
  setup() 的（天师道袍等 EQUIP 护具）和自带 setup() 的 throwing.c（飞刀）不扣。新扣的有 26 种武器；
  防具变了 8 种：两种牛皮盾、狼皮披风、蓑衣、水烟阁武士氅从 0 变负，牛皮靴 +1 → −1，天兵战甲
  −20 → −16、重钢战甲 −30 → −23 反而轻了。**默认**（偏离）：equip.c 也给重兵器设 armor_prop/dodge，
  wear.c 于是能把它当护具「穿」上、只得惩罚；不搬。**默认**：咒剑王禅（taoist/sword.c）在 setup()
  之后、clonep() 分支之外设 weapon_prop/spirituality，复制品自己的 weapon_prop 只有这一项，盖住了
  原型的伤害 44 和轻功 −2（dbase.c 只在复制品没有该键时才查原型）；我们照原型给全部数值。
- **A3 弈者「下棋」**（#56/#63；润色 PR，**已实现**）：ES2 play_chess() 有五成机会把他整串棋子送给对方
  （100 枚，嘴上却说「两枚」），我们没移植；做法：移植 play_chess()，结果写进日志：赢了他给 **两枚**
  （**默认**：照他的话；ES2 给整串），他手里没了就只说「好棋技！佩服。」。数据是带 `chance` 和
  `hands_over` 的打听规则。
- **A4 老松岭只看的描述**（#70；润色 PR，**已实现**）：ES2 的 clearing 告示（官府告示：此处常有歹人出
  没。）、epath3 的脚印、epath2 和 waterfall 的瀑布、cliffside 和 riverbank2 的山壁、passage 的水帘只
  能 look，我们没有；做法：做成只看不用的地标（policy look），和葬剑亭的石碑一样，文字照 item_desc
  原样；waterfall 的山壁（同一房间的 item_desc）一并做了，共 8 个。
- **A5 游荡 NPC**（#71；润色 PR，**已实现**）：ES2 的 random_move 整个换房间，没有「站在门口」一说，我
  们的游荡 NPC 会停在 64 px 的店门里、站着的 NPC 顶住玩家；做法：落脚点离相邻区域、传送口和门 48 px
  以上（区域太小没有这样的点时照旧），不多抽随机数；玩家顶着站立的 NPC 超过 1 秒，NPC 在自己区域里侧
  身让到旁边（确定性地选让开路、离得最近的空位），不换区域；卖东西、教武功、给任务的 NPC 站着不动，
  免得被推出服务范围。
- **A7 最大气**（#47；偏离；现代化修正 II，**已实现**）：ES2 只在登录时按 race/human.c 重算最大气
  （含 max_force/4），打坐练上去后要「继续」一次才变；做法：打坐、冥思、修行练高上限的那一下立即重算
  最大精气神（和「继续」同一个函数），「内力进战斗」条目里「只在继续时重算」那句由此作废。
- **A9 玩家苏醒**（#28；偏离；现代化修正 II，**已实现**）：ES2 让昏迷的玩家真实等 30 秒–2 分钟；
  做法：延时照 damage.c 抽（random(100 − con) + 30），玩家只在黑屏里躺 pacing.json 的
  `player_wake_seconds`（3 秒，默认 0 = ES2 原样），这期间世界时间按延时倍速走（NPC 心跳和苏醒、
  房间重置、call_out、朱鸿雪的任务时限）；正在打的战斗照常速。NPC 的苏醒不变。
- **A10 持兵刃切磋**（#37/#64；现代化修正 II，**已实现**）：ES2 的 accept_fight 不看挑战者自己的
  状态（带伤连续切磋刘安禄会送命），look.c 也没有强弱比较的一句，#64 已对持兵刃的切磋先问；做法：对方
  持兵刃或明显强于玩家时用 ConfirmPrompt，目标详情加一句相对强弱（原生五档：远不如你、不如你、不相上
  下、比你强、比你强得多，按 combat_exp）。**Owner（#79）**：「明显强于」= 至少 4 倍且多 500
  （RelativeStrength）：新角色和武馆弟子切磋不问，和刘安禄、拜师后的李火狮切磋要问。
- **A11 骨头**（#56；润色 PR；偏离）：ES2 finish_eat 让熟牛肉、狗肉、牛腿吃完留下 牛肋骨/狗骨头/
  牛腿骨，别名只有 rib，而 d/snow/npc/dog.c 的 accept_object() 只认 id("bone")（name.c 的 id() 精确
  比对别名），所以原版的狗拒收这三种骨头、从不跟着走，只有示例鸡腿的 bone 喂得进；我们吃完就没了。
  做法：吃完留骨头，骨头可喂狗（修掉 rib/bone 的错配：三个肉文件显然想让狗吃骨头，原样搬过来读起来
  是 bug，owner 批准的现代化修正），狗吃了在同一张图内跟随；「既是食物又是兵器」的牛腿等第二个这样
  的物品再做。**已实现**（狗肉）：最后一口后狗肉变成狗骨头（物品的派生形态，250 g、不值钱、量词 根，
  ES2 沿用肉的 斤），野狗收下骨头「高兴地汪汪叫了起来」，之后玩家在同一张图里换房间它就跟过去（go.c
  的「走了过来。」；路被挡住，比如门在玩家身后关上，它就留在原地；跟着的狗走过去时仍保持选中）；跟随是对象变量，和 ES2 的 leader 一样「继续」后不记得，房间重置照 ES2 叫它回家。
  熟牛肉（beef.c）ES2 里没人卖，没导入；牛腿骨等牛腿成食物。
- **□ 字**（#36/#55；现代化修正 II，**已实现**）：ES2 文本在 Big5 转换中丢了字；游戏里实际有 7 处
  数据、2 处战斗描写（mudlib 里共有 128 处、71 个文件，多数尚未导入，也有有意的标记），原样显示 □；做法：
  `tools/migration/text_replacements.json` 逐个定字，导入器在区域 override 之前套用，套完还剩 □ 就是
  未决项（新区域导入时自动提醒），手写的数据和战斗描写照同一张表改，工具测试守住游戏里不再有 □。
  柳□主 = 柳馆主，□偻 = 佝偻，用力一□ = 砸，血肉□糊 = 模糊，全身□麻 = 酸麻；□伤 定不了：不是
  砍伤或劈伤（weapond.c 自有这两类，走默认句），它和割伤共用「划破皮肉」那组句子，取 擦伤（owner，#79），玩家
  看不到这个词本身。
- **给予贵重物品**（#59；现代化修正 II，**已实现**）：ES2 的 NPC（陈剑秋等）不问就收下任何给他的东
  西，包括兵器和钱；做法：给出已装备的物品或大额钱时 ConfirmPrompt，对所有 NPC 生效。**Owner（#79）**：大额 =
  一次一两黄金（10000 文）以上；收押注或布施的 NPC（宝官、庙祝的功德箱、化缘和尚）给钱不问。
- **润色 PR 顺手修的**（**已实现**）：玩家走出房间时，留在原房间的 NPC 不再保持选中（kill.c 的
  present() 本来就会拒绝）；战斗记录补上 combatd.c announce() 的「X脚下一个不稳，跌在地上一动也不动
  了。」「X死了。」（玩家自己的不写：昏倒时 unconcious() 挡住了玩家的消息，死时 ES2 会印「你死了。」，这里由生死
  画面说）。合并多个房间的
  区域按玩家所在房间显示描述：要给区域补子区域数据、改画图器和场景，不是小改动，留着。
- **闲聊频道行**（#75；现代化修正 II，**已实现**）：ES2 的 command("chat ...") 走 channeld.c 全服
  可见，我们显示成 【闲聊】绝尘子：…；做法：在房间里喊出来，「绝尘子大声喝道：…」，仍是 HIC。
- **措辞和界面**（现代化修正 II，**已实现**）：
  - 誓词日志改「你发誓恪守门规。」（#67；ES2 接受的誓词是 守门规，原来写 你发誓道：守门规）。
  - 地标动作句改自然短语（#44）：五个原来走「{动作}：{地标}」的老松岭地标各有一句，clearing.c、
    riverbank1.c、cliff1.c 的 climb 原话，下大松树一句原生；模板只留作兜底。
  - 去掉「你的目标是X。」日志行（#38）；换目标的「你把目标转向X。」保留。
  - 伤害数字一律紧跟句末、灰色（#38）：最近三行改用战斗记录的同一种写法。
  - 战斗中「运功疗伤」置灰，悬停写 heal.c 的「战斗中运功疗伤？找死吗？」，按了不排队（#47）。
  - 普通日志文字调浅灰（消息、提示、战斗记录同一个颜色），HIW 高亮可辨（#47）。
  - 冥思/修行没学基本咒文/基本法术时，瓶颈句后加「需要先学会基本咒文，法力才能增长。」（修行说基本
    法术、灵力），按钮悬停同句（#75）。
  - 法术和运功按钮悬停说明，如「施法「遁」：脱离战斗，回到雪亭镇城隍庙（80 法力，可能失败）」，数字
    取各文件的常量（#76）。

**保持现状，记为已定**
- A8 战斗中拾取（#43）：ES2 允许战斗中 get（busy 1），我们半自动战斗期间世界冻结；保持冻结。
- #42 拒收的那部分钱留在身上（ES2 先拆再问，拒收的钱丢了）；杨掌柜的 heal_me 按打听者的伤势判断
  （dbase.c 用他自己的）。
- #41 昏迷的 NPC 不说话、不问候（char.c 昏迷时仍跑 chat()）。
- #52 狼狗的气上限抬到 200（wolf_dog.c 写 200，4 岁兽类上限 50，ES2 允许当前值高于上限）；寨门每关
  一次只把 5 个喽罗里死掉或不在场的补回（ES2 每次再加 5 个）。
- #55 bash_weapon 先掷反击再掷 bash（combatd.c 反之，两次掷骰独立）；砸断的飞刀不和完好的合并
  （ES2 按文件合并）。
- #57 野羊山的石屋和北壁裂口只画出来，不能进、不能爬（LPC 里没有对应房间）。
- #60 朱鸿雪的任务目标是 84 个名字、220 条（qlist 里注释掉的 33 条不算）。
- #62 卧龙岗强盗的出手窗口 2 秒（ES2 1 秒，够打一条命令离开；原生走过要 1.2–1.5 秒）。
  （现行见「响应性」，2026-10-15：2 秒从强盗喊出第一句起算。）
- #63 「你拿出一两银子给宝官。」放在开骰之前（ES2 印在最后）。
- #64 安惜迩那类切磋先问（推翻 #48）；菜单两个确认的焦点在「取消」。
- #67 没门派的人接受师父的主动收徒算首次拜师，不算背叛（apprentice.c 判成背叛，recruit.c 修过同一
  bug）；同门换师父先问。
- #68 的三条 Ours：狂暴和瞪眼的战斗只有两个人；生死战里谁都不再打谁时战斗结束；狂暴的喝骂在房间描述
  之后。
- #33/#70 老松岭：cliffside ↔ pine1 双向（pine1.c 没有回去的出口，但 cliffside 是死路）；尸体最多侧
  移 40 px 避开墙；大松树在空地中间偏北；树用侧视，其他俯视；caves 仍是 48 px 的方格迷宫。
- #75 天将在战斗结束时离开（heaven_soldier.c 的 set_leader() 不移植）。
- #76 施法忙乱时排队等（cast.c 直接拒绝）；遁等于逃跑，敌人停手；双方都站着的生死战写「双方都停了
  手」；有两个以上敌人的 NPC 照 select_opponent() 随机挑对手。
- #66 提示 6–14 秒后自己淡出。
- #38 「厮杀」「等你空下来」等原创用语保留（只去掉「你的目标是X。」）。
- #27 牛皮酒袋照原名显示，不另起短名。
- 小屏战斗面板（#38）和移动端应用名（#44）留到手机版阶段。

## 茅山 D: 驱尸 and the sheets (2026-10-08)

What each LPC function became is in [TEMPLE_CONTENT](TEMPLE_CONTENT.md); it carries out
茅山 A's answers and defaults and follows the LPC except:
- **The zombie is the player's wherever it goes** (茅山 A): it walks after them into a
  neighbouring room on any map (go.c's follow_me(), however they got there, as the dog), its
  dispell call_out going along, and Continue starts without it. **It feeds only on the
  player's map and outside fights** (owner, #84): NPC heart beats run only there (ES2: wherever
  it stands; one left on another map waits there, taking nothing).
- **It takes nothing from a master lying unconscious** (owner, #84): ES2's zombie.c heal_up()
  takes 1 gin from them all the same, and unconcious() has set gin to 0, so char.c's next beat
  kills them. Its atman ≤ 10 dispell still comes.
- **Its corpse's things fall where it lay** and **符 go only on 桃符纸, one at a time** (茅山 A,
  默认): ES2 destructs them with the corpse, draws on any carried thing and renames a whole stack.
- **The name on a sheet is someone in the room** (茅山 A): the selected NPC (not a raised one,
  nor one whose fight is not ported yet); put on, the sheet finds the first of that kind in the
  zombie's room; none there: 这里没有…。 and the sheet stays. ES2 throws the sheet away first and
  looks for the name in the whole world, else sends the zombie at whoever put it on.
- **The sheet's fight has the player in it, standing by** on the zombie's side (owner, #84):
  the world stands still as in any fight and the battle panel shows it; fleeing ends it for
  all; the zombie's kill is the player's (killer_reward()). The panel's 攻击 is kill.c at the
  one it goes after (这里不准战斗。 in a no_fight room): the player kills them, they kill the
  player back, and the fight goes on two against one (select_opponent(): three blows in four at
  the zombie, the first enemy); at one's own master it asks first, as the HUD's 攻击. In ES2 it
  is fought beside a player free to walk away, or to type kill.
  set_leader(dest) only ends its following the player: it falls apart at its first heal_up
  out of the fight on the player's map (a few seconds; left on another map, it waits there).
- **Asked first** (owner's rule on choices that knock out, kill or betray): 驱尸 when its 30
  sen, and 画符 when its 40 sen, would knock the player out (animate.c checks only mana,
  scribe.c asks for 30 sen); 画符 when its drop of blood (1 kee off effective) would kill a
  player wounded to 0; 贴符 sending the zombie after the player's own master (弑师, as 攻击).
- **Native lines**: a drawn sheet says 你咬破手指，用鲜血在桃符纸上画了一道僵尸追魂符，写上了…的名字。
  (scribe.c prints nothing; its help tells of the blood); 驱尸's button tells its cost and that
  the zombie lives on 灵力.
- **A combined item on a room's floor** (global rule): an item spawn of one lays a stack of its
  amount on each point (combined.c's set_amount()): Snow's 城隍庙 has its two 桃符纸.

## 茅山 C: 茅山道术's practice and the 观想虫 (2026-10-08)

What each LPC function became is in [TEMPLE_CONTENT](TEMPLE_CONTENT.md); it follows the LPC
except:
- **A save leaves a standing 观想虫 out** (**默认**): Save stays open while it lives (a summoned
  NPC otherwise blocks it); Continue starts without it and without the player's
  set_temp("mind_bug"), as ES2's relogin forgets the temp, the rule the owner chose for D's
  zombie. A conjured NPC carries nothing (the catalog checks).
- **召天将/召护法 against one's own 观想虫 is asked first** (owner's rule on choices that knock
  the player out): the soldier's kill is not the player's hand, so the player faints and learns
  nothing. In a spar 召护法 is asked as 召天将 is.
- **攻击 at an NPC lying unconscious** (global rule, kill.c): the player's lethal attack may start
  a fight with one; the first wound kills it. Before, the HUD offered 攻击 and nothing happened,
  so a beaten 观想虫 could not be finished.
- **Its hatred** (attack.c is_killing(), combatd.c start_hatred()'s catch_hunt_msg) is kept
  for the conjured NPC alone; other NPCs that kill_ob() the player (绝尘子) still forget the
  player when their fight ends, as before.
- **An NPC that falls outside a fight** (a condition's tick) is killed by its last_damage_from,
  as the player already was (the global rule "The killer is last_damage_from"); a fight that
  aborts settles its falls the same way.
- The lines of the practice open the fight: the notify_fail() (你的魂魄正被…缠住) comes before
  kill_ob()'s 看起来…想杀死你, which ES2 prints between them.

## 茅山 B: 茅山派 (2026-10-08)

What each LPC function became (林忌's two-second answer, the women's refusal, 灵神诀) is in
[TEMPLE_CONTENT](TEMPLE_CONTENT.md); it follows the LPC except:
- **NPC call_outs and the player's absence** (global rule; a map's own heart beat is caught up
  since「别的地图时间补算」, these call_outs still go as below): an NPC's call_out (林忌's answer,
  the thief's steal) runs on its map's world time, which stands still in a fight and while the
  player is on another map. One that comes due in a fight waits for its end; leaving the map
  drops them all, since ES2's would come while the player is away and find nobody (recruit.c's
  present(), steal_it()). Except 风泉剑灵's chant (owner, 乔阴 C): it says nothing to anyone in
  particular, so it waits, kept on the NPC and saved, and goes on when the player is back. And
  a master's answer to 拜师 (地图重构 R3): it is said to the empty room as the player leaves the
  map, as when they walked off on one map (a refusal ends the request: 山烟寺 C); since the
  remap a hall's door is a way off the map, and dropped, the request would stay pending.
- **The question before 拜师** (first master, betrayal) is asked at the 拜师, as with 柳淳风 and
  绝尘子, though with 林忌 the change itself comes with his answer two seconds later.

## 茅山 A: the climb, the temple and its people (2026-10-08)

Owner-approved plan (同意, 2026-10-08): four packages — A places the region, B 茅山派, C the
player's 茅山道术 in a fight and its practice, D the zombies and the sheets. The plan's three
questions, answered with their recommendations: a raised zombie follows the player across
maps and is not saved (Continue starts without it, as ES2's relogin); practising 茅山道术
asks nothing (its hover tells of the 观想虫); a 僵尸追魂符 names someone in the room, and one
gone by the time it is put on the zombie is not stuck (the sheet stays). Defaults of the plan
(owner may veto): the three-apprentice count is not ported (it never ran out, see
[TEMPLE_CONTENT](TEMPLE_CONTENT.md)); a raised corpse's contents fall to
the floor (ES2 destructs them with it); 符 are drawn only on 桃符纸, one at a time;
earth-warp is not offered (it never attached and leads to 鬼门关); astral_vision was left out
too on the wrong reading that nothing reads it (std/char.c visible() does: 鬼门关 B ports it as
阴阳眼). What each room and NPC became is in TEMPLE_CONTENT.
- **Maps**: three painter maps (`tools/maps/layouts/temple.json`): the climb (`canvas`), the
  grounds inside the 山门 with the square, the hall, the walkways round the courtyard, the
  halls behind and the 藏经楼's ground floor (`town`), and the 藏经楼's upper floor. Snow's
  mountain road opens its drawn steps north (eroad3.c's exit east; its text: 往北则是通往山上
  的石阶). 25 of the 27 room files are placed (broom1/2: copies no exit leads into).
- **Doors as create_door() leaves them**: four open at the start (square, two guest rooms,
  the training hall), the rear hall's red door shut (DOOR_CLOSED); world.json `open`.
- **road2.c's guards on duty** (`draw` spawns): when the world is made and at each reset of
  road2 one of 清灵/清平/清玄 and one of 清风/清音/清云 is drawn and comes (made anew if dead,
  called home if away); the others stay, as std/room.c leaves an earlier draw standing, so up
  to six stand there in time. ES2 put on duty the draw of the reset before (road2.c sets the
  objects after ::reset()): the same odds, one reset apart. The draws are on the world's
  interaction stream, as room resets.
- **road1.c's moss**: each walk off the path south or north-west draws random(kar) (query("kar"),
  as set); below 3 the player reads the slip, falls unconscious (A9's short wake) and stays
  on the path. Coming onto the path never slips.
- **road2.c's invisible wall** stops all but 茅山派 at the 藏经楼's door; a member going in
  reads road2.c's door line, anyone coming out book_room1.c's (`pass_lines`); tell_room() lines
  only others would see are not shown.
- **An NPC's class** (`set("class")`) is data: rankd.c's words follow it wherever they name the
  NPC, so the taoists call themselves 贫道 (npc.c's spar answer, ask.c), the player asks 清虚
  for 道长's 高招 (fight.c) and calls a guard 死牛鼻子 (kill.c).
- **谷衣心法's 灵神诀** (gouyee/concentrate.c) comes with B, where the player can learn the skill;
  its 疗伤 is fonxanforce's heal.c word for word.
- **召护法 (invocation.c) for NPCs**: 林忌, 僵尸侍者 and 僵尸护法 call a 天将 (one in three) or
  a 阴鬼卒 (obj/npc/hell_guard.c, a summoned NPC like the 天将, its lines in HIB, a new colour)
  to their side. The bolts and 召护法 have their 施法 names now (紫光, 白光, 青光, 召护法): 林忌
  teaches 茅山道术, so the player reaches them with B; a player's bolt that fails says 你失败了
  (netherbolt.c 你失败了！). 僵尸侍者's command("cast (m)animate on corpse") draws do nothing.
- **Not ported, as planned**: 僵尸护法's `pursuer` (as 县城官兵's, 黄霸's and 安惜迩's: 逃跑 keeps
  no killer to follow; each such NPC is a review entry of the importer); temple1.c's bulletin
  board and valid_startroom. sword.c's hit_ob() waits for the first ghost (a tools test fails
  once a ghost NPC is placed).
- **□**: daemon/class/taoist/sword.c's 王□ is 王禅 (**默认**; text_replacements.json).
- The importer's lexer accepts a lost character inside a comment (npc/obj/magic_book.c).
- **Save**: world content revision `SOURCE_ENTRY_TEMPLE_V1`; older development saves need a
  New Game.

## 青石村 D: the player's spells (2026-10-07)

What each LPC function became is in [GREEN_CONTENT](GREEN_CONTENT.md).
- **cast.c on the battle panel**: 施法「遁」 (dun at oneself), 施法「困」 (dun at the current
  target, or offensive_target() with none) and 施法「召天将」 (saveme), offered while the enabled
  spells skill has the file. Like exert and perform (owner's rule) a cast waits while the player
  is busy, where cast.c refuses; cast.c's other refusals (no spells enabled, a spell the skill
  has not, a no_magic room) and the files' own go to the battle log. Both files refuse outside a
  fight, so there is no 施法 elsewhere. Casting improves nothing and magic-array.c refuses practice:
  spells are learnt only, as in ES2.
- **no_magic rooms** are imported (这里不准念咒文); no room placed so far has one (Snow's bank
  comments it out).
- **遁 at oneself ends the fight for the player as a flight does**, after the chant and one of
  the five lights; whoever they called leaves unheard, and the player stands in Snow's 城隍庙
  (/d/snow/temple, also REVIVE_ROOM) a frame later, once the world is free (no fight starts and
  no save is taken meanwhile). The result reads
  你借遁术脱离了战斗。 dun.c's write("你失败了。") now reaches a player caster.
- **The player's 天将** (heaven_soldier.c invocation()): it kill_ob()s each living enemy of the
  player (from the last), each kill_ob()s it back, it comes in on the player's side and the fight
  goes on to the death; the player and a sparring partner still only spar. It finishes an enemy
  that falls, as any killer does, and fights on while the player lies unconscious. **Its kill is
  the player's**: combatd.c killer_reward() hands a `possessed` killer's reward to who called it
  (its `!is_living()` test always holds, as nothing defines is_living()), so MKS, a 朱鸿雪 target,
  bellicosity, a vendetta and killing one's own master all count. It leaves when the fight ends
  (C). Owner's rule on deadly choices: in a spar the battle panel asks first (the partner may
  die, and a dead master is 弑师).
- **Who turns on the player's side kills whom the LPC says**: an NPC's own soldier kill_ob()s its
  caster's living enemies (the player's soldier too, which kills it back; the player only fights
  back); 老公公/老婆婆's ask_for_help() sends the partner at query_temp("killer"), the last one
  the caller kill_ob()ed (the soldier, once it came).
- **An NPC with several enemies** (the player and the soldier) picks one each attack as
  feature/attack.c select_opponent() does: random(4), else the first. An NPC with one enemy still
  keeps its target and draws nothing.
- A fight to the death that stops with both sides standing (nobody fights anyone: a spar partner
  who withstood 天邪虎啸 or outlasted the 天将) ends with 双方都停了手，战斗结束。, not 你赢了.

## 青石村 C: 绝尘派 (2026-10-07)

What each LPC function became is in [GREEN_CONTENT](GREEN_CONTENT.md).
- **A family's member is attacked for asking (juechen/master.c), asked first** (owner's rule on
  deadly choices): 拜师 with 绝尘子 by one whose title is not 普通百姓 opens the shared confirm
  (he will call it betrayal and attack to kill); confirmed, apprentice.c's line, his chat line
  and kill_ob(): he hunts the player, who only fights back. Asked again, apprentice.c only says
  对方还没有答应 (the request stays pending), so he does not attack twice.
- **His chat channel line** (command("chat ...")) shows in the log as channeld.c writes it,
  【闲聊】绝尘子：… in HIC, without the English id; nobody else hears channels in single player.
- **His checks, in order, each with its say**: spi as set (query("spi")), then combat_exp. The
  apprentice rule's `requires` may now be a list of such checks; 柳淳风's and 陈剑秋's single
  check is unchanged. Class taoist: 【 道  士 】 / 【 女  冠 】 on the sheet, 道长 / 仙姑 as respect.
- **召天将's soldier** (obj/npc/heaven_soldier.c) comes into the fight against the caster's
  living enemies (the player fights it back); a spar goes on to the death, as with 天邪虎啸.
  set_leader() is not ported: it leaves, with its lines, as soon as the fight it came into ends
  (heal_up() when not fighting), unconscious or not, and takes what it carries; a dead one leaves
  its corpse. Its name is drawn on creation (`name_pick`, 天甲…天癸神兵) and never saved: no room
  may place an NPC that draws its name, a save is refused while one stands, and its ID
  (summoned.<n>.<definition>.character, n from the saved item allocator) lets Continue check its
  corpse against its definition.
- **遁 at an enemy only for now**: an NPC's cast_spell() names no target, so 绝尘子 holds his
  enemy busy (mana / 200 less its max_mana / 100, plus 2: about 21 rounds at first). The cast at
  oneself (to Snow's temple) comes with the player's spells (D). dun.c's `mana_facter` is a
  misspelt key nothing sets: it adds nothing, as in ES2.
- **冥思 and 修行** are on the 武学 page with an amount (at least 10, 30 to start: their help's
  default; the commands themselves require one). The character sheet shows score.c's 灵力 and
  法力 (内力 is on the 武学 page). With no 基本咒文 (基本法术), meditate.c (respirate.c) hits its
  bottleneck at once and puts mana (atman) back to its maximum, as in ES2.
- Names chinesed.c would give are authored: 基本法术 (magic), 基本咒文 (spells), 小天魔道,
  奇门遁甲, 绝尘心法, 金刚杖法. combatd.c reads no `dodge`/`parry` of an action, so 金刚杖法's are
  left out (as 春风快意刀's). Not ported, as planned: cavehall.c's valid_startroom (Continue starts
  where the save was).

## 青石村 B: the 玉佩 and the 蒙汗药 (2026-10-07)

What each LPC function became is in [GREEN_CONTENT](GREEN_CONTENT.md).
- **Owner (Q2): the chain works as the code means.** In ES2 it broke in three places, each made
  to work: ask.c skips the functions in an answer array (and nothing sets `last_asker`), so
  oldman2.c's set_flag() now runs where it stands and marks the asker; jade.c inherits F_UNIQUE,
  which the mudlib does not define, so the jade is an item flagged `unique` and shen.c's
  violate_unique() asks the whole world (carried, lying about, held by an NPC, in a corpse);
  powder.c's pour makes the drink call effect_in_liquid(), which slumber_drug.c lacks, so the
  poured 蒙汗药 runs its drink_drug() (100 slumber_drug a sip). Correction to the plan: liquid.c
  does call a drink_func (dbase.c query() evaluates a function value), so 极乐逍遥散 worked and
  is ported as it was (the drink's slumber_effect, + 100 a pour; alcohol still adds drunk_apply).
- **The chain's set_temp() flags are saved** (elder_info, give_alcohol, know_drug, can_buy_drug,
  had_jade, in the character's marks). ES2 lost them at a relogin; a Continue would silently undo
  the clues. So a player gets the jade once (had_jade: 你真贪心耶).
- **Owner (Q3): 必有妖孽** is the 打听 panel's 接话 button: say.c's 你说道, then
  oldman2.c's relay_say(). With kee below max_kee / 5, say.c breaks the words up (必有妖孽 ...)
  and he lets them pass.
- **Deviation (modern fixes): 想骗我啊? hands the gift back.** shen.c keeps whatever a buyer
  gives below 10 taels (anything but money is worth 0); here he refuses it. The give_alcohol and
  know_drug flags it deletes stay deleted; can_buy_drug stays, as in the LPC.
- **Deviation: an answer that acted ends the asking.** shen.c's give_jade() and sell_drug()
  return 0, so ask.c went on to a 没听说过 line even after handing over the jade; once such a
  function said or gave something, nothing follows. One that only emotes (command("?"), prints
  nothing) still leaves ask.c to its own lines.
- **Conditions**: drunk.c and slumber_drug.c for the player and NPCs (con + max_force / 50,
  doubled). drunk.c's receive_healing() reaches no function (damage.c has receive_heal()):
  it heals nothing, as in ES2. A daemon's unconcious() takes effect at the next life check, so
  that beat's heal_up() is skipped. What the room sees of an NPC's condition is shown to a player
  there, and an NPC falling unconscious out of a fight shows combatd.c's 脚下一个不稳 line. The
  Snow drunk now gets drunk on his own wine (con 30: past 60 he passes out and comes to).
- whisper.c lines are GRN. 陶壶's 米酒 shows its own name (it read 红酒). 沈万年 stands behind
  his counter where the player at its front reaches him (layout `placed`). An item he hands over
  that the player cannot carry lands at their feet, and they read so (in ES2 give.c failed and
  he kept it); had_jade is set only once the jade was handed over.
- **Save**: a liquid record's `drink_func` and `slumber_effect` are written only when something
  was poured in; no revision bump.

## 青石村 A: the village, the mountain road, the 迷阵 (2026-10-07)

Owner-approved plan (four packages: A places the region, B the 玉佩 and 蒙汗药, C 绝尘派,
D the player's spells). What each room and NPC became is in [GREEN_CONTENT](GREEN_CONTENT.md).
- **Maps**: three painter maps (`tools/maps/layouts/green.json`): the village (`town`), the
  mountain north of it (`canvas`: the cave, the cliff road, 山路尽头, the stone rooms and the
  stream) and the 迷阵 (`canvas`: eight clearings in the mist and 绝地, drawn far apart so the
  camera shows one at a time). 山坳's way east is open. An exit a portal on the same map stands
  for (the 迷阵's, the two one-way ways) is a passage, not a walk: the painter neither joins its
  rooms nor counts them neighbours, and its reach follows the passage to its arrival marker.
- **The 迷阵**: each exit is the LPC's: walking off a clearing's side arrives on the far side of
  where it leads — the same clearing (困, shown again as ES2 shows a room on any move), back
  (涉), on (生) or 绝地 (死). The rooms are all named 迷阵 and `distinct`. eight7.c's
  valid_leave() is the portal's `set_mark` (八卦阵, saved in `marks`).
- **entrance.c, outdoor.c valid_leave()** are `exit_rules` (`combat_exp_below` 100000 on the
  passage east, `not_apprentice_of` 绝尘子 into the hall). A refused passage keeps the player out
  of it. tell_room() lines only others would see are not shown.
- **Owner (Q1): 放弃 in 绝地.** closed.c's only way out is the push (force and max_force 560,
  force_factor 40); in ES2 a weaker player quit and logged in again at their start room (the Inn
  by default), but Continue restores the exact place. 绝地 offers 放弃: the player falls asleep
  and wakes in the Inn (饮风客栈), as that relogin did.
- **water.c, house3.c, closed.c, rope.c** are landmark policies (`search`, `look_spawn`,
  `push_stone`) and the item's `hang`. Native: the web calls a spider in only while one of its
  three points is free (ES2 made a new one every time, three a reset). Owner rule: 上吊 asks
  first; it kills as die() does, with no killer (an old last_damage_from is not counted).
  A zone of rooms that disagree on `outdoors` (Old Pine's canopy: tree3 is outdoors) refuses
  it in all its rooms.
  station0.c's well is a water service (liquid.c's fill to the container's capacity);
  fillwater's fixed 15 is not ported.
- **woman1.c converse_one()** runs in her heart beat, where this_player() is herself, so ES2 only
  ever said 以大欺小啊你...: her line now measures the enemy's age (as the code means). The old
  couple's ask_for_help() kill_ob()s query_temp("killer"), which only a fight to the death sets:
  in a spar nobody comes. kid2's attitude function is drawn each time a spar asks; kid4's gender
  function once, at creation (as other drawn facts).
- **As LPC, not placed**: kid5.c (a wizard's test NPC), npc/master.c (龙若法王: map_skill() lacks
  its quotes and the file does not compile; no room places it), s.c and shen1.c (copies no room
  places; shen1's jade1 does not exist), stone_____stoneroom.c (empty). cavehall.c's
  valid_startroom has no use (Continue starts where the player saved).
- **Save**: world content revision `SOURCE_ENTRY_GREEN_V1` (new maps, 山坳's way east); older
  development saves need a New Game. CharacterState `applies` (create()'s drawn apply/*) is
  written only when there are some.

## 雪亭镇's maps drawn by the painter (2026-10-07)

Owner-approved plan: the last two hand-made maps, Snow's streets (`snow.outdoor`) and the Inn's
ground floor (`snow.inn`), are painter maps (`tools/maps/layouts/snow.json`, technique `town`)
drawn from their room text: the paved square with its old wooden frame, the Inn's front on its
west side (sroad2 hears it to the north), the main street north past the shops to the memorial
arch and the col with its notice board; 淳风武馆 as one walled compound (the gate court with its
stone lions, the sand yard, the weapon hall with its shelf, the hall's five 太师椅, the 天井 with
its pillar and flowers, the long corridor to the inner court); the old 城隍庙 at the square's
corner with its altar; the 黄土小径 winding up east to the mossy mountain road under its cliff;
the 青石官道 with its cart ruts and rows of flowering trees. Inside the Inn: the counter and the
waiter, the travellers' tables, the stairs, the ebony sign by the door and the glowing red-wood
door in the north-west wall. `game/data` is unchanged (zones, doors, portals, services, spawns,
floor items, `no_fight`); in the scenes every position moved. Exits ES2 describes without a room
(the alley east of mstreet4, the way to the next village, 黄石隘口, the steps up from the
mountain road, the 书院's side room, the inner court's shrine and corridors, the Inn's red-wood
door) are drawn only; the Inn's sign and red-wood door, like the other look-only texts, are not
ported yet. Counters, the millstone and furniture are tiles, so no map keeps node collision
but its doors' walls. Owner: the path south to Old Pine loses its blocking wall (as on the Old Pine
side), and the streets' camera follows the other towns (map bounds, no 0.9 zoom). Owner: none of
Snow's same-name neighbours (雪亭镇街道, 黄土小径, 青石官道) is `distinct`: the drawn shops say
what their texts say. World content revision `SOURCE_ENTRY_SNOW_PAINTED_V1`: older development
saves need a New Game.

## Neighbouring rooms of one name are one place (2026-10-07)

Owner: ES2 shows a room's text on every move, and our HUD on every zone the player enters. Rooms
of one name next to each other (the two 黄土小径, 雪亭镇街道's four, 青石官道, 山路, 白石阶梯, the pine
maze's 松树林) read as one place: walking on from one into the next on the same map shows no
arrival text. A room of another name, or one of the name reached any other way (a map change, a
teleport), is described as before; 观察 shows the current room's own text. Owner: a room whose
text says something new under the shared name is flagged `distinct` in world.json and is always
described: 老松寨's hall (keep3), path3 (the snake on the stone), cave5 (the writing on the wall),
张百万家's inner room (rich), 野羊山's cavern2 and cavern4.

## 老松岭's maps drawn by the painter (2026-10-07)

Owner-approved plan: the five hand-made Old Pine maps (forest, cave, gorge, tree, cliff1) and the
box-drawn stone and cliff2 are painter maps (`tools/maps/layouts/oldpine.json`) drawn from their
room text: the winding path from Snow, the round clearing round the great pine, the straight
slope, the gorge under the mossy bridge with the waterfall north of it, the stockade; the pool
under the falls, the stream along the gorge's west wall with rocks to stand on, the bottomless
pool ringed by grass; the candlelit passage behind the curtain; the pine seen from the side, its
trunk and three levels of boughs; the niches as hollows in the cliff over a drop. The pine maze
keeps its fixed maze (a loop, two dead ends, the way on to cliffdown) as gaps between the trees.
`game/data` is unchanged (zones, doors, the gate trap, landmarks, portals, spawns, water services,
the Lake's `complete_set`); in the scenes the landmark areas, the water points, the cliff niches'
zones and some spawn points moved or changed size to fit the drawing (the keep's guards, the
serpents and the arrival points stay put; the Lake's water point stands where the stream falls
in, where it can be fetched out of the serpents' reach as before). Owner: the path north to Snow loses its blocking wall (the
map's edge is closed ground, as on 野羊山); epath3's broken plank road (no exit in ES2) and the sign
by the path to the bandits' slope are drawn only — the sign's and the footprints' `item_desc`
texts (clearing.c, epath3.c) are not ported yet. World content revision
`SOURCE_ENTRY_OLDPINE_PAINTED_V1`: older development saves need a New Game.
(Superseded in part: the sign's and the footprints' texts by「积压问题的处理」A4, 2026-10-08, ported as
look-only landmarks; the Lake's `complete_set` by「进门一起上」, 2026-10-24, `combat_entry` is gone;
the plank road by「老松林按原文方位排布」, 2026-10-25, now the maze's way in from epath3.)

## 绮云镇's upper floors: three maps (2026-10-06)

Owner: the three upper floors were three separate boxes on one map; each is now its own map
(`cloud.tearoom_upstairs`, `cloud.jiyuan_upstairs`, `cloud.duchang_upstairs`), drawn over its building
(the ground floor's size, the stairs down where the ground floor's go up) and furnished from its
room text: 香茗坊二楼's tea tables and the chess board at its far end (里首), 怡红院二楼's wine table,
zither table and screen, the 赌场's gaming tables. 赌场二楼's sign stays undrawn (its `bet` is an
empty TODO in ES2). World content revision `SOURCE_ENTRY_CLOUD_FLOORS_V1`: older development
saves need a New Game.

## 水烟阁 C: the player's 天邪神功 and 杀气 (2026-10-06)

Owner-approved plan ("按你的建议来"); what each LPC piece became is in
[WATERFOG_CONTENT](WATERFOG_CONTENT.md).
- **天邪神功's files for the player**: 运功 offers powerup (提升战斗力) and powerfade (压制杀气) on
  the 武学 page and the battle panel, 天邪虎啸 (roar.c) only on the battle panel: outside a fight its
  file refuses whatever the player has. exert.c's practice stays weak mode (progress, never a
  level: 天邪神功 is learnt).
- **powerfade in a fight**: random(skill) < cps × 3 knocks the user out (unconcious(); the fight's
  life check right after the action makes them fall).
- **天邪虎啸 pulls the room in**: everyone living in the player's zone (an NPC whose fight is not
  ported aside) who does not withstand it (skill / 2 + random(skill / 2) < cps × 2) loses sen, a
  wound too when its force is low, and kill_ob()s the player: one outside the fight comes in (the
  player only fights back), and a spar goes on to the death. Their 看起来X想杀死你！ goes to the
  battle log and is pinned. The struck one's 金星乱冒 line is told to it alone, as ES2.
- **Owner: asked first** in the battle panel (ConfirmPrompt in place of its buttons; the fight goes
  on meanwhile, so the question is no pause): 天邪虎啸 (its cost; everyone who does not withstand
  it turns on the player, a spar becomes deadly) and powerfade in a fight, with its odds from the
  rule (约有 N 成会昏倒). Only when the action would run now; powerfade outside a fight is not asked.
- **The player's berserk** (attack.c init(), combatd.c start_berserk()): when the player comes
  into a zone, and when an NPC comes into theirs (walking, summoned, respawned, going home), each
  living NPC there gets random(bellicosity / 40) > cps; the first over gets start_berserk(): the
  stare; force > (random(b) + b) / 2 calms it; else, bellicosity above score, 去死吧 and the
  player attacks to kill (kill_ob(): the NPC only fights back), else 陪我玩两手吧 and a spar the
  NPC is not asked about. Not in a no-fight zone, nor while fighting or unconscious; never asked
  (the player did not choose it).
  - **Owner: never at the player's own master** (ES2 would; killing him is a betrayal the player
    did not choose). An NPC whose fight is not ported is left out too.
  - **Owner: told once**: when bellicosity first reaches 40 × (cps + 2) (from there random(b / 40)
    can beat cps), the log, and the 武学 page after a powerup, say so (Berserk.WARNING; saved as
    progression.berserk_warned). The 武学 page shows 杀气 and 定力.
- **look.c's glare**: 观察 a living NPC here: random(its bellicosity / 10) > the player's per →
  X突然转过头来瞪你一眼。 and its start_berserk(). An NPC's spar branch (fight_ob(): bellicosity not
  above its score) is ported (cause NPC_SPAR: a spar it starts); the loader no longer refuses
  such an NPC. An NPC's berserk kill is one way, as start_berserk()'s kill_ob(): it kills, the
  player only fights back (疯老头子's was mutual before, as the port's other aggression still is).
- As ES2: the berserk's spar asks nobody, a beast included; a berserk kill counts as any kill.
- powerfade's 100 sen outside a fight can take the player below zero: they fall at once (std/char.c's
  next heart beat), as after 於兰天武's blows.
- **Ours**: a berserk's (or glare's) fight is the two of them, also in a room where aggressive
  NPCs enter fights together; one that cannot begin shows the stare without its shout. The
  player's berserk comes on the world tick after the arrival (auto_fight()'s call_out()), after
  the room's text. A fight to the death in which nobody standing fights anyone any more ends
  (roar.c's sparring partner who withstood it stops after the first blow, as in any spar).

## The HUD: a status card and toasts (2026-10-06)

Owner: the top left becomes a modern status card, and the scene's messages move to the bottom
left as toasts; talk with a character stays in its panel. Presentation only, no rule changes.
- **The card**: the player's name and the place, 精/气/神 as bars with their numbers (气 current /
  effective; the tooltip has current / effective / maximum), the conditions (蛇毒) when there
  are some, then the buttons; a selected thing shows under a 目标 tag with its actions.
- **Toasts** (owner): a new message rises from below and pushes the older one up; with more than
  two, the oldest drifts up and fades out, once it has shown for at least 1.2 s. Lines that come
  together come in one after another (0.3 s apart); more than four waiting drop the oldest. A
  fight's result shows its first line. On touch screens they sit right of the movement pad.
- **Not toasted**: lines that come while a panel that shows its own lines is open (打听, an NPC's
  panel: 请教, a shop, the bank) or while a fight runs (the battle panel shows them); opening
  either clears the toasts. 背包, 拾取, 角色 and 观察 let them through (a gift's answer reads at
  once). 消息 keeps every line, as before.
- **Ours, for the owner to judge**: a toast also fades out by itself after 6–14 s (longer for
  longer text; oldest first), so the map's corner clears; `MessageToasts.LINGER_*` sets it.

## 水烟阁 B: joining 天邪派, its masters' teaching, joining the 武者 (2026-10-06)

Owner-approved plan ("按你的建议来"). What each LPC piece became is in
[WATERFOG_CONTENT](WATERFOG_CONTENT.md).
- **Taking apprentices is one of three rules** (NpcTeaching.ApprenticeRule `kind`, data):
  `requirements` (柳淳风, 陈剑秋), `oath` (萧辟尘), `trial` (於兰天武). recruit.c run by the
  master offers to take a student whose request does not wait on it (pending/recruit); their
  next 拜师 takes them at once (apprentice.c's first branch). A finished 拜师 ends any other
  request (apprentice.c's first branch left it standing). daemon/class/fighter's masters
  give no class: one who comes from 封山剑派 keeps 剑士's class (and can then not join the 武者).
- **Owner: 萧辟尘's oath is a fixed 发誓恪守门规 button** (no typing, every language): it
  swears 守门规, the oath ES2 accepts (你发誓道：守门规); 你发的是什麽鬼誓 never comes. The button
  shows while his request for an oath stands (pending/celestial_swear, transient).
- **Owner: 於兰天武's test is asked first** (ConfirmPrompt: three real blows, a fall when one
  is not stood, death from a bad wound, and what passing does — taken, a betrayal or an offer).
  The rule is unchanged: three combatd.c do_attack() outside any fight (his 妖刀狗屠 wounds),
  after each kee below zero (or the player gone) ends the test with that blow's line; the
  player falls on the heart beat after (run at once), and he is the one who hit last.
- **Modern fixes** (owner: as recommended, ES2 beside):
  - MudOS say() skips this_player(), so in ES2 the challenger never read 於兰天武's lines (很好，
    这是第一招, the three failure lines, 若真的有心…): the player reads them; the say() without a
    speaker reads 於兰天武说道：.
  - The command hints (accept test), (swear), (join) are dropped from the lines, and recruit.c's
    用 apprentice 指令 reads 就向他拜师: the actions are buttons.
  - The test is not offered to his own apprentice (it only ends in 好徒儿), while his offer
    stands (拜师 takes the player), nor while he is not awake or in a fight (champion.c would
    strike unconscious); a test whose first blow cannot be struck does not take place. The
    oath button hides while 萧辟尘 is not awake (his command() would do nothing).
  - **For the owner**: apprentice.c's first branch (taking an offer) compares families without
    asking whether the player has one, so in ES2 a player with no family who takes 於兰天武's or
    萧辟尘's offer reads 决定背叛师门 and loses score and a betrayal; recruit.c fixed the same
    slip on its side ("fix a bug in 1st time recruit"). The port does as recruit.c: a first
    master.
  - score.c's rank (rankd.c query_rank(): 【 武  者 】, 【 剑  士 】, 【 平  民 】) leads the
    character sheet's title line; the ghost's, 杀人魔 and 惯窃 do not apply yet.
  - The player's 天邪神功 powerup and powerfade wait for C (powerfade's faint in a fight and its
    question are not ported): 运功 does not offer them yet (ExertService.AWAITING_PLAYER).
- **First master, betrayal or a change of master is asked where it happens**: at 萧辟尘's oath
  and 於兰天武's test (or the 拜师 after an offer), not at the 拜师 that only asks for them.
  Changing master inside 天邪派 (no betrayal) names what the old master teaches afterwards:
  萧辟尘 only what he knows three times as well (prevent_learn()), 於兰天武 nothing (privs 0).
- recruit.c's offer is said once: offering again tells only the master (对方还没有答应).
- **於兰天武's privs are 0** (assign_apprentice("弟子", 0)): learn.c lets only his own
  apprentices learn from him; another member hears his polite refusal (as ES2).
- **Practice**: practice_skill() checks kee, force and sen, each with its line when it has its
  own (celestrike.c's two, stormdance.c's sen); 天邪神功 is learnt (杀气 at least 50 for each point
  of query_skill() without raw, half the level) and refuses practice.
- **The 正厅's join** (std/room/class_guild.c) is the 樟木匾's action 加入武者同盟 (landmark
  policy `join_class`): a player with no class becomes a 武者 (fighter); one with a class reads
  你已经参加了其他公会。. Its startroom has no use: Continue starts where the player saved.
- **Owner confirmed #64's two points**: a 切磋 that becomes a fight to the death is asked first;
  the menu's two questions keep the focus on 取消.

## Ask before an important or deadly choice (2026-10-06)

Owner: every important or deadly choice is asked first, through one reusable component
(`ConfirmPrompt`, `game/ui/common`) that the unified UI can restyle later. ES2 asks nothing;
the rules themselves are unchanged.
- **Asked**: 攻击 on one's own master (the kill is a betrayal, 3C); 切磋 with an NPC whose
  accept_fight() answers with kill_ob() (安惜迩, 卧龙岗强盗, 飞贼: asked as a fight to the death,
  without its line; the owner had #48's spar with 安惜迩 rechecked, which went without a
  question); 切磋 while the player or the NPC holds a weapon (a blade's blow wounds and can kill;
  the log's 刀剑无眼 hint stays); 化尸粉 on a corpse that still holds things (dust.c destructs it
  whole; 取消 returns to the 背包); the first master's 拜师 (changing family later is a
  betrayal). 3B's betrayal, the hockshop's sale and the menu's 开始新游戏 and 返回主菜单 now use
  the same component.
- A question comes only when the choice will take place: no question for a spar the NPC
  refuses or a room forbids, nor for 拜师 that the master refuses, is unconscious for, or that
  already waits on him (apprentice.c then only says 对方还没有答应). 3B asked a member of another
  family even when the master was going to refuse.
- 取消 holds the focus, and closing the panel (关闭, Back) answers 取消; the menu's two questions
  used to focus their choice.
- **Not asked**: ordinary 攻击, 逃跑, 投降 and 运功 (the action is the intent), 老松岭's 藤蔓 and
  埋骨 (a fall only lands elsewhere), the 宝官's bet.
- With 水烟阁: 於兰天武's three-blow test (B), 天邪虎啸 and powerfade in a fight (C).

## 水烟阁 A: the mountain, the pavilion and their NPCs (2026-10-06)

Owner-approved plan (three packages; this one places the region, B joins 天邪派, C gives the
player 天邪神功). What each room and NPC became is in [WATERFOG_CONTENT](WATERFOG_CONTENT.md).
- **Owner: the 正厅's masters (an obvious slip)**: d/waterfog/guildhall.c places its
  objects as `CLASS_D("fighter") + "champion"`, without the slash: the file does not exist,
  make_inventory()'s new() errors and the room fails to load in ES2. daemon/class/fighter/
  guildhall.c is the same room with the right paths; the 正厅 zone takes both files (the first
  one's text, the second one's 於兰天武, 萧辟尘 and 潘军禅).
- **entrance.c's valid_leave()** is data (world.json `exit_rules`): going north with a weapon in
  hand while a 水烟阁武士 is in the 正门 (present(): one lying unconscious counts, a corpse does
  not), the player stays in the room, back inside its edge, and reads the guard's shout and
  水烟阁武士挡住了你的去路。, once per attempt.
- **item_desc** (the 正厅's sign, 虹谷's stone tablet, 葬剑亭's monolith) are look-only
  landmarks (policy `look`): selected and looked at, no action.
- **萧辟尘's consider()** is the chat function `match_weapon` (NpcWeaponMatch): he says ES2's
  lines and takes up or puts away his long sword. Weapons' wield and unwield lines are not shown
  yet (as everywhere).
- **As ES2, nothing**: the 红衣武士's accept_kill() (no mudlib code calls it) and its
  `guard <dir>` in return_home() (the mudlib has no guard command); exert recover by 天邪神功's
  NPCs (no recover file); 小天邪虎 (no room places it); the fighters' bulletin board.
- **Maps (owner)**: the mountain, the pavilion's ground floor (its own map: the 正门 is a scene
  change, as Snow's Inn) and its upper floor. 聆啸厅's 春秋水色斋, 葬剑亭's 虹台 and 西侧厅's 阳台 have no
  rooms in ES2: no door is drawn to them.
- **Owner: the world's pinned numbers** (maps, rooms, Snow's outdoor portals and passages, a New
  Game's NPCs and items, NPC creation draws, the spawn order) live in
  `tests/fixtures/world_counts.json`; `UPDATE_WORLD_COUNTS=1` on `tests/runtime/world_counts_test.gd`
  re-records them. The saves' revision pins read `WorldContentRevision.CURRENT_PUBLIC`.

## 绮云镇 3D: the 赌场 and the 红娘庄 (2026-10-06)

- **The 宝官 takes bets** (judge.c accept_object()): money given to him is a bet on 小, anything
  without a value() is refused (宝官没有收下。; his 物品不能折价… is a notify_fail that give.c's
  replaces). He says 什么？ 您押小？！好的。, give.c destructs the stake, and random(10) < 8 loses
  (world-interaction stream); else pay_player() pays twice the stake's value in silver and coins
  (a gold tael pays 200 silver taels). Money leaves the game with every stake and is made anew
  for every win: on average a bet returns 0.4 of itself. Data: an `effect: wager` rule and the
  NPC's `wager` (NpcWager). The player reads 你拿出X给宝官。 before the outcome (ES2 printed it
  last).
- **Owner: a whole stack bet and won pays twice, like any bet** (deviation). In ES2 the stake is
  still the player's stack while pay_player() runs, so combined.c's move() merges it into the new
  silver (or coins) and destructs it; give.c then calls value() on the destructed stake and
  stops: the player keeps the stake as well, three times in all, and reads no 你拿出…. Part of a
  stack, or a gold tael (paid in silver), paid twice.
- **Owner: winnings the player cannot carry land at their feet**: of each kind (silver, then
  coins) the player takes what still fits and the rest lies at their feet in one pile, with
  X对你而言太重了，掉在你的脚边。; in ES2 pay_player()'s move() failed and they were lost unseen.
- **Owner: picking up a stack too heavy as a whole takes what fits** (deviation; 你捡起X。 and
  the rest's X对你而言太重了。). get.c takes part of a stack only when the player types the
  amount (`get 50 silver`); the HUD's 拾取 has none, so a pile bigger than the player can carry
  (a win of many gold taels) could never be picked up.
- **Owner: the upper floor has no bet.** duchang2.c's `bet` is a TODO that does nothing (its sign
  promises two taels for one); the 宝官 downstairs is ES2's only game.
- **Owner: no marriage.** mei_po.c's marry needs the partner to be another player (find_player())
  and the 婚约 (obj/marry_card.c) works only between two players (learn.c lets a spouse teach
  across families, skills.c shows a spouse's skills, coupletalk). A single-player game has nobody
  to marry, so the 媒婆 offers neither 结亲 nor 解约; she answers about 婚约 as in ES2. Marrying
  NPCs would be a new design, and through learn.c a way into any family's arts.

## Pacing knobs and 卧龙岗's second (2026-10-06)

Measured at ES2's pace on the native game (real session, combat scheduler and heal_up cadence; a
new character's attributes are all 30, as logind.c sets them): 打坐 from max_force 0 to 50 takes
6.4 h of play (11.6 h at con 20), almost all of it waiting for kee; combat_exp 0 to 1001 takes
some 30-60 h: sparring the six 武馆弟子 gives 120-140 an hour up to about 150, then nothing in the
game gives more than about 30 an hour (combatd.c gives exp only to the weaker side of a blow, a kill
gives none, and a spar is two blows and a minute's rest); the 40 and 50 s tasks lie 9-17 ES2 rooms
from 朱鸿雪, 14-25 s on foot plus the fight.
- **Owner: three knobs in `common/pacing.json`**, integers; left out, each is ES2's pace
  (PacingDefinition). No ported formula changed:
  - `player_exp_gain` 3: every 1 combat_exp do_attack() gives the player (a dodge, a parry, a hit
    either way) is 3, and so is a hit's 1 potential (still only up to 100 unspent). NPCs, quest
    rewards and skill improvement are unchanged.
  - `player_recovery_gain` 3: heal_up() restores three times as much to the player (gin, kee,
    sen, the effective repair, atman, force, mana); the tick's timing and its food and water are
    ES2's. NPCs are unchanged.
  - `quest_time_percent` 150: 朱鸿雪 gives one and a half times god.c's time (40 s becomes 60 s)
    and says so; the save keeps the time she gave.
  - `npc_thirst` 10 (owner, after 青石村 B): heal_up() uses up 10 of an NPC's water a tick
    instead of 1. Only the Snow drunk cares: sated at 380 water he drank again about every 9.5
    minutes, so the 玉佩 chain's second whisper waited 61–157 minutes; now about 5 minutes after
    New Game to his first plea, and 6–14 after a gift. The player's water is ES2's.
  - Suites that pin ES2's own numbers end to end run with the knobs at ES2's pace
    (`tests/support/es2_pacing.gd`); `tests/core/pacing_knobs_test.gd` shows a gain of 1 is ES2.
- **Owner: 卧龙岗 lets a newcomer walk through.** gangster.c's greeting comes a second after the
  player arrives (init(): call_out("greeting", 1)), time for one command out of the room, and go.c
  leaves a fight without a roll, so in ES2 a newcomer walked past; natively the robbers attacked the
  moment the player came into reach and killed a newcomer in 4-5 rounds. Now a robber attacks a
  player still in its reach `toll_attack_delay_ms` after the player came into it: 2000, because
  crossing the native ridge takes 1.2-1.5 s and the way to 南坡 passes within 70 px of the second
  robber (about 1 s in his reach; at 1000 every route tried was caught). Walking on passes both;
  stopping, or walking into one, does not, and the other robber in reach then joins (both
  greetings come from the same arrival). **Deviation:** ES2's greeting kill_ob()s a passer-by who
  has gone, so the robber attacks at once next time; here walking past makes no grudge, and the way
  back has the same time. A fight (stopping in reach, a refused toll, 攻击 or 切磋) still makes one
  until the robber is made anew.
  (Superseded in part by「响应性」, 2026-10-15: the robber shouts on sight and the 2 s count from
  that shout; and by「进门一起上」, 2026-10-24: everyone in the zone who attacks on sight joins.)

## Modern fixes: ES2 behaviour that reads as a bug (2026-10-06)

Owner: the game is for today's players (AGENTS.md, Deviations). ES2's behaviour, then ours:
- give.c's refusal 你只能把东西送给其他玩家操纵的人物。 speaks of other players: the player reads
  X没有收下。 (the thing stays with them, as since 4E).
- b_header.c's accept_object() returns 1 in every branch, so 陈剑秋 kept what he refused (money
  destructed): his 你拿什么东西唬我？ and 这不是你得到的吧 hand the gift back. He keeps his own
  忘忧草 from an outsider (你是何人？为什么有我的忘忧草？).
- vendor.c lists goods priced 0 (the weapon shop's 飞镖, 0两黄金) that buy.c refuses: the shop
  does not list them.
- steal.c tells the robbed player nothing: the player reads 你忽然觉得身上一轻，X不见了！ (HIR), not
  who took it; one robbed while unconscious reads 你昏迷不醒的时候，身上的X被人拿走了！ on waking.
- snake_drug.c lowers the poison by one per dose against a bite's 20, so a dose seemed to do
  nothing: after each dose the player reads what is left, and that each bout wears one off too.
- Kept: study.c's 你是个文盲，先学学读书识字(literate)吧。 already tells an illiterate reader of 说文解字
  what to do.
- With 3C (#60): the quest reward's cap on unspent potential only stops the gain, and a surrender
  before the first blow is refused by a standing killer.

## 绮云镇 3C: 朱鸿雪's quests, killer_reward() for the player, surrender (2026-10-06)

- **The quest command is 朱鸿雪's** (god.c init(): `quest_giver`): beside her, 任务 runs
  give_quest(); when it returns 0 (combat_exp 1000 or less, a task still running) quest.c's lines
  follow, as the command goes on to cmds/usr/quest.c. quest.c's lines also stand on the 角色 page.
  The 15 levels and 220 qlist entries are `common/quests.json` (qlist10000, 13000 and 17000.c
  comment out 11 entries each; they are left out); the player keeps a copy of the task.
- **Owner: she draws only targets the game has.** The draw is among the tier's entries whose
  target is an NPC placed somewhere that can be fought (by name, as killer_reward() compares
  name(1)); a tier with none gives way to the next lower one. With all 84 names in the game it is
  god.c's own draw. `tests/fixtures/quest_targets.json` lists the 41 available and 43 missing
  names; a region package that places one re-records it (UPDATE_QUEST_TARGETS=1).
- **Owner: the task's time runs on play time** (fights, map changes and lying unconscious
  included); pause and a closed game stop it, and the save keeps the time left. In ES2 task_time
  is time() + the quest's seconds, and time() also runs while the player is offline.
- **killer_reward() for a player who kills an NPC**: MKS + 1; the task done when the victim's name
  is its target and its time has not run out (the exp, potential and score rolls, quest_factor,
  unspent potential capped at 100, a negative score's reward negated, tfinished); bellicosity + 1;
  the victim's vendetta_mark marks the killer; killing one's own master (the generation above)
  gives title 普通百姓 and no family, master or rank (the class stays).
- **Owner: killing one's own master counts as betraying the family.** ES2 lowers betrayer by
  one, so the kill washed out a betrayal (or banked one for later), and an expelled player joins
  any family without a betrayal: killing the master was the cheapest way to change families.
  Here it costs what recruit.c's betrayal costs (betrayer + 1, score 0), and the player reads
  why (你亲手杀了自己的师父，被逐出了…！ and the cost; ES2 says nothing).
- **Owner: no ES2 quirk that reads as a bug.** The quest reward's cap on unspent potential (100)
  only stops the gain: ES2 lowered a player above 100. A surrender before the first blow (no
  last_opponent yet) is refused when a standing enemy is killing the surrenderer: ES2 took it, and
  the score, while the killer fought on.
- **vendetta**: an NPC with a vendetta_mark (garrison.c: authority) attacks a player who holds
  vendetta/<mark> on sight (attack.c init(), start_vendetta()); a death with a killer clears it.
  garrison.c's `pursuer` (following who flees) is not ported.
- **Owner: score is shown**: the 角色 page shows score.c's 杀气, 综合评价 and 总共杀过 N 个人.
  Deviation: its 其中有 N 个是其他玩家 is left out (there are no other players).
- **Owner: surrender.c for the player**: 投降 on the battle panel beside 逃跑. A last opponent
  that stands and is killing the player refuses (the 求饶 line); otherwise every enemy that is
  not killing the player stops, the player stops fighting them all and loses 50 score (to 0).
  It waits while the player is busy, as exert and perform (surrender.c has no busy check). In a
  fight to the death whose killers all lie down, an accepted surrender ends the fight as 逃跑
  does: ES2 would go on when a killer came to, which the port's fight cannot wait for. NPCs that
  surrender lose score the same way (their score lives on the definition, so nothing changes).

## 绮云镇 3B: joining 振远镖局 (2026-10-05)

- **Changing family is ported** (the Snow entry's deferred betrayal): an NPC master recruits
  through recruit.c, so a member of another family who is taken says 你决定背叛师门, gets score 0
  and betrayer + 1, and the new family, master, title, class and entry time replace the old ones.
  A member of the same family is recruited as anyone else (new master, generation, title,
  class and entry time), without the betrayal's lines and penalties.
- **Owner: betrayal asks first** (a UI deviation). In a master's panel, 拜师 by a member of
  another family shows what recruit.c will do (score 0, the new number of betrayals and
  master.c's limit, the new family; skills kept) and needs 确定改投; apprentice.c runs at once
  (only its help warns). The rule itself is unchanged.
- **The player's score** (综合评价) is kept and saved (only when it is not 0); betrayal sets it to
  0. Nothing shows it or adds to it before 3C's quests.
- **look.c's relation** (他是你的师父, 同门师兄, 师叔 …) is the last line of 目标详情 for an NPC
  of the player's family; an NPC has no master and enter_time 0 (create_family()).
- **practice_skill() may ask for a weapon in hand** (`practice.weapon`, spring-blade.c's blade),
  checked before kee and with its own line.
- **Owner: Q1 A.** The 忘忧草 is defined but not placed. 陈剑秋's three answers are rules
  (`item_name`, `giver_family`); the letter waits for 乔阴县城's lion (CLOUD_CONTENT, Deferred).
- **Owner: killing one's own master comes with 3C** (killer_reward()'s player side).

## 卧龙岗 + 绮云镇 3A: the streets and shops (2026-10-05)

The region plan's #3; what is placed where is in [CLOUD_CONTENT](CLOUD_CONTENT.md).
- **Two maps, drawn as a town** (owner: not a grid of boxes): the outdoor map holds the road
  from Snow's 雪亭镇街道 winding over 卧龙岗 to the gate, the market street (北, 西, 中, 东, 南市场)
  turning down to the crossroad and the main street across the town; street rooms are stretches
  of one open road with no walls between them, shops and houses are buildings of their own sizes
  along it with their door onto the street their exit names. The three upper floors (香茗坊,
  怡红院, 赌场) are one map of three separate rooms, reached by their stairs. Diagonal exits become
  straight; 南坡 and the second 黄土路 both open onto the gate, as the three lead to each other;
  a cliff keeps 卧龙岗 from the second 黄土路. Closed: south across 泓水 (#8), west to 晚月庄 (#7).
  (Upper floors superseded by「绮云镇's upper floors: three maps」, 2026-10-06; buildings by「地图重构」,
  2026-10-16: every enterable room is on its building's own map.)
- **Owner: the later packages' NPCs stand now** as ordinary NPCs (陈剑秋 and 趟子手, 3B; 朱鸿雪,
  3C; 宝官 and 媒婆, 3D; 船夫, #8). 朱鸿雪 and 化缘和尚 cannot be fought until their arts are
  ported; 春风快意刀 is, for the 家丁 (and so 陈剑秋 and 趟子手).
- **The toll** (gangster.c): a robber attacks a player without marks/强盗 on sight (its greeting's
  kill_passenger()); giving it something worth ten gold taels sets the mark; less, and that robber
  attacks. The native presence (radius 100 here) is the room, and the greeting's call_out a second
  in it (two seconds natively: pacing knobs above), so the toll is paid from the edge of the room. A robber that has
  fought the player attacks on sight from then on, mark or not (kill_passenger()'s attitude,
  attack.c's hatred, after its aggression, a refused toll, the player's 攻击 or 切磋), until it is
  made anew. Its chat and fight lines are set from the start where ES2 sets them at that first
  meeting.
- **Owner: the thief steals** (thief.c, cmds/std/steal.c), the NPC side only (the player's steal
  waits for #9): an arriving player (or the thief arriving) is tried when random(kar) < 2, one
  second later steal.c picks present("silver") or a random carried thing, three seconds later it
  rolls. The player reads nothing when robbed, only when caught; then they fight (fight_ob both
  ways: a spar). An NPC is not robbed, nor is a thing the player dropped in those three seconds
  (steal.c would take it off the floor). His `thief` count and a robber's having fought the
  player are object variables: Continue forgets them, as drunk.c's has_alcohol.
- **Rules as data**: accept_object rules test the giver's gender and raw per (李师师's keepsake)
  and may attack on a refusal (`kill`); greetings draw `out_of` n (switch(random(4)) with fewer
  cases says nothing on the rest); a `line` is shown as written (the say() efun naming its
  speaker). A `->wield()` that finds no free hand leaves the weapon carried (the robber's 飞镖).
- **The archive's hard wrap**: a raw line break inside an LPC string is dropped on import (the
  u/cloud files and daemon/class/fighter/celestial are wrapped at 80 columns).
- **For the owner**: 牛腿 (sold by the butcher) is a hammer only, since food that is also a weapon
  is not supported yet; food eaten up leaves no bones (finish_eat); 弈者's 下棋 is not ported.
  (Bones and 下棋 superseded by「积压问题的处理」A11 and A3, 2026-10-08: both are ported.)
- World content revision `SOURCE_ENTRY_CLOUD_V1`: older development saves need a New Game.

## 野羊山: the mountain road, the caverns, two hands, bash_weapon (2026-10-05)

The region plan's #2; what is placed where is in [GOATHILL_CONTENT](GOATHILL_CONTENT.md).
- **Two maps**: the mountain (mroad1-6, temple1, slope1, canyon1-3, a room each on a 256 px
  grid) and the caverns (cavern1-4), entered east from canyon3; Snow's crossroad leads north
  in. Diagonal exits become straight ones (mroad2 northeast, cavern1 northeast and southeast);
  mroad5's northeast to mroad6 runs through slope1. mroad4's four bandits join one fight
  (`complete_set`).
  (`complete_set` superseded by「进门一起上」, 2026-10-24: every zone gathers its gang, `combat_entry` is gone.)
- **The second hand** (equip.c wield()): a second one-handed SECONDARY weapon goes to the other
  hand, for NPCs as for the player, and every wielded weapon's weapon_prop counts in apply/*,
  damage too (黄霸: 45 and 45); only the primary attacks (combatd.c). A player's second weapon
  counted for nothing before.
- **bash_weapon** (weapond.c; hammers' and staffs' bash, crush, slam): a blow the victim parried
  with a weapon pits weight / 500 + rigidity + str against the victim's: random(wap) over twice
  knocks the weapon to the floor, over once nearly, over half breaks it, else sparks. A broken
  one is 断掉的<name> from then on (value / 10, weapon_prop 0: not wieldable); every weapon has a
  `#broken` form in the catalog and the object keeps its identity (and its place in its
  NPC's loadout). A broken stack (飞刀) stays one, of broken ones, which no longer merge with
  whole ones (combined.c would merge them by file: **for the owner**). No ported item sets
  rigidity (0). The draw comes after the riposte's, where combatd.c draws it before: the attack
  decides the riposte before the runtime runs post_actions (**for the owner**). A special
  file's attacks (fakefault.c's 奋力一击) show their post_actions too. Snow's 铁锤 bashes too.
- **bash's line keeps the source's □** (用力一□, a character lost in its conversion), as
  combat lines keep 血肉□糊.
- **伏蛟功** (serpentforce.c) is a force skill with std/force.c's hit; its exert functions (the
  beggar class) and practice by water are not ported (no teacher in reach).
- **Owner: as LPC**: 银色岩蛭 (no room places it), 死岩蛭 (no code reads `corpse_ob`: leeches leave
  plain corpses), 护心镜 (nobody carries it). 黄霸's pursuer is not modelled (as 安惜迩's).
- World content revision `SOURCE_ENTRY_GOATHILL_V1`: older development saves need a New Game.

## Old Pine remainder B: conditions, combined items, 金银花蛇 and 黑衣人 (2026-10-05)

What is placed where is in [OLDPINE_CONTENT](OLDPINE_CONTENT.md).
- **Conditions update on the heart beat** (supersedes S5B E): on the `5 + random(10)` tick
  update_condition() runs before heal_up(), which CND_NO_HEAL_UP skips (char.c), for the player
  and the active map's NPCs. **Owner: not in a fight** — the world stands still there (S5B D),
  conditions too, where ES2 ticks them; nor while the player lies unconscious (S5B L). The lines
  print in their colour (HIG added). Below zero after a tick the player falls or dies at once
  (char.c heart_beat); the killer is whoever last landed a blow (damage.c `last_damage_from`,
  0 damage too, kept from the fight, not saved) while that NPC still stands on the map, so dying of a bite after
  fleeing costs the death penalty. The HUD names 蛇毒 after 精/气/神 (**owner: keep**):
  presentation only, ES2 shows conditions only through their lines; each condition opts in
  (`shown_name`), so one meant to go unnoticed (slumber_drug) can stay hidden.
- **hit_ob is data** (venomsnake.c; shaoin.c's rose_poison has the same shape): `{condition,
  duration, below, message, color}`. random(damage_bonus) is drawn from the combat stream between
  the martial hit_ob and the strength draw, only for an NPC that has one.
- **Combined items** (`combined` `{base_unit, base_weight, amount}`) are the money stack
  generalized: a new one has create()'s amount, a carried one its carry `amount`
  (`->set_amount()`), and a stack at 0 is destroyed at once (S3B G). drop.c destructs 飞刀 on the
  floor (it has no value); hockshop.c values a stack by `query("value")`, whatever its amount.
  get.c's `get N x` leaves N on the floor and takes the rest: the floor pickup still takes the
  whole stack.
- **weapond.c throw_weapon** runs after the attack and before the riposte: the thrown weapon
  loses one; the last one is unwielded first and its thrower told 你的飞刀用完了！. bash_weapon
  (hammers) is still not ported.
- **killed_enemy is data** (`{say, dissolve_after_ms}`): 黑衣人 laughs and a second of world time
  later dissolves the newest corpse in his room with his 化尸粉 (present() finds the object moved
  in last). **Owner: as ES2**, also the player's own corpse with all it holds. The pending
  dissolve is not saved (a call_out). The death screen's native line on where the corpse lies
  becomes 你的尸体已经不在了。 once it is gone (**owner**; ES2 tells the dead nothing).
- **apply** (snake_drug.c, hurt_drug.c; **owner: 金疮药 too**) is the inventory's 使用, used
  outside a fight as eating is. One 蛇药 lowers snake_poison by one (a bite gives 20) and the last
  leaves it at 0, where snake_poison.c strikes once more before it ends.
- World content revision `SOURCE_ENTRY_OLDPINE_VENOM_V1`: older development saves need a New Game.

## Old Pine remainder A: the keep, the caves and cliff2 (2026-10-04)

The region plan's first package (owner confirmed the order); what is placed where is in
[OLDPINE_CONTENT](OLDPINE_CONTENT.md).
- **One map per height level, as in 3B5.** The stone over path3, the caves below it (cave1-5) and
  cliff2 are maps of their own; path3 `climb up`, stone `climb down`, cliffdown `climb down` and
  cliff2's `climb up`/`climb down` are landmarks that say the room's own line.
- **The caves' random exits become one fixed maze** (as the pine maze): cave1-4 are one zone with
  forks, loops and dead ends and one way on to cave5, whose `eastdown` leads to the waterfall.
- **keep2.c's gate** is a door only its room rule operates (`traps[]`): it starts open; leaving
  keep2 east while it is open shouts, shuts it and brings five 土匪喽罗 into keep2; 常老大's 竹管
  played in keep2 (pipe_notify()) or keep2's reset opens it. ES2 adds five more guards every time
  it shuts; the native trap brings back those of its five that are gone and leaves the living
  ones. Like every door its state is not saved: a Continue finds it open, as a login would.
  The summoned guards' absence is saved; only a summoned spawn's NPC may be alive and absent.
- **The keep's three rooms enter fights as the Lake does** (`combat_entry: complete_set`, P2A-M):
  every aggressive guard in contact joins one encounter, as each one's init() kill_ob()s the
  player on arrival in ES2; a pair entry left guards standing beside the player after a fight.
  Superseded by「进门一起上」(2026-10-24): every zone works so, `combat_entry` is gone.
- **A beast's authored kee above its race's maximum raises the maximum** (wolf_dog.c: kee and
  eff_kee 200 at age 4, max_kee 50). LPC keeps eff_kee over max_kee; a resource state cannot.
  The dog fights with 200 kee as in ES2; it heals back to 200, not to 50.
- **Berserk** (attack.c init(), combatd.c start_berserk()): an NPC that is not aggressive but has
  bellicosity rolls on the player's arrival and, above its score, attacks to kill (疯老头子). Its
  spar branch (fight_ob(), bellicosity not above score) is not ported; the loader refuses such an
  NPC. Bellicosity also counts as courage in a fight (attribute.c query_cor()).

## The player's perform: 封山剑法's 封, 逐, 缺 (2026-10-04)

Owner-approved plan ("四条都照建议做"), second PR of combat talk and specials:
- **perform.c on the battle panel**: one button per perform file the wielded weapon's enabled
  skill reaches (a sword with 封山剑法: 「封」「逐」「缺」; 「点」 powerfocus has no file), against
  the current target (`perform <action> <target>`: no offensive_target() draw), or with none
  while the player has none yet (before their first round: `perform <action>`, the file's
  offensive_target()). Like exert it is queued and waits while the player is busy (perform.c
  refuses) and runs between rounds, as a command does. Use is practice: random(120) <
  query_skill(skill) in weak mode.
- **A special's do_attack()** is a direct TYPE_REGULAR attack through the ordinary attack chain
  (a riposte may follow), with no fight() step (guarding, courage) and whoever is busy, also on a
  killer's unconscious victim (「逐」 and 「封」 only ask is_fighting(); 「缺」 refuses); its lines
  are an ordinary blow's. Nobody falls in the middle of a special: the fight's lifecycle check runs
  after it (char.c heart_beat()), and the victim's last_damage_from is its last landed blow.
- **Owner, obvious slips fixed** (as the reflection line): swordjab.c's attacks use the wielded
  weapon (it passes query("weapon"), never set) and its line comes before them (the source prints
  it after); fakefault.c's 你已经在运用中了。 stops a second 「缺」 (it checks the temp flag and sets
  the permanent one). PR A's two (surrender.c's $N/$n, guard.c's 刘安录) are confirmed.
- **Owner: 「逐」 has no busy**, as in ES2; eff_kee − 10 per use is its only limit.
- **Owner: 「缺」 strikes only in its fight.** Its applies are a timed apply (a round is
  combat_round_ms); ending in the fight against the target still conscious and there, remove_effect()
  strikes both ways. When the fight ends the entry forgets its target: ending on world time after
  it (a decided spar, both standing), in a later fight, or with the performer unconscious, it only
  takes the applies back; ES2 would trade two blows wherever both still stand.
- Codex on #49: several NPC beats in one step fall below zero before each beat's chat.

## Combat talk and NPC specials (2026-10-04)

Owner-approved plan, first of two PRs (the second is the player's perform); what each NPC
does is in [SNOW_CONTENT](SNOW_CONTENT.md#combat-talk-and-specials).
- **npc.c chat() in a fight** runs after an NPC's attack on a beat it is not busy, while it still
  fights, with draws from the fight's random source; after the blow that ends the fight it says
  nothing. A beat whose attack found nobody to fight chats outside a fight in ES2; the world
  stands still during a fight, so it says nothing.
- **Timed applies** (powerup's call_out): a fight's round is combat_round_ms of their time, world
  time counts the rest for the NPCs of the active map (as heal_up and revive). Saved only while
  one runs: older saves still load.
- Outside a fight an NPC below zero gin, kee or sen falls on its next beat (std/char.c), so
  powerfade's 100 sen can knock 安惜迩 out. Not ported: powerfade's faint in a fight (only his
  peaceful chat uses it), the farmer's score loss on surrender (NPC score is not tracked).
- **Owner (confirmed in PR B)**: obvious slips fixed, as with the reflection line: surrender.c's
  swapped $N/$n (the farmer begs, the player refuses) and guard.c's 刘安录 (an override).

## How a fight opens (2026-10-04)

- feature/attack.c kill_ob() tells its victim 看起来X想杀死你！ (HIR) every time: after
  kill.c's line (obj->kill_ob(me)), from combatd.c start_aggressive() and from 安惜迩's
  accept_fight(). The player now sees it for each NPC that fights them to the death; the
  aggressive NPC's native `<name>向你发动攻击！` is gone.
- **Owner:** the battle panel covers the log, so a fight's opening lines (fight.c's or kill.c's
  words, the NPC's answer, the warnings) also open the battle log, and the warnings stay pinned
  under the title for the whole fight. No confirmation dialog: ES2 has none, an NPC's answer is
  content, and Flee is already on the panel.

## Internal power in combat: enforce, exert, the force hit (2026-10-03)

Owner-approved plan ("按你的建议"):
- **enforce.c** on the 武学 page and the battle panel: 0 (none) to query_skill("force") / 2,
  an enabled force needed, no busy or fight check, so in a fight it is set at once (not
  queued) and its Ok. joins the battle log. Ok. stays English, as enable.c's (#46 review).
- **exert.c** with the function files skills.json lists under `exert`: fonxanforce's heal
  (`daemon/class/swordsman/fonxanforce/heal.c`), the basic force's recover, refresh and
  regenerate (`/d/force`), tried in exert.c's order; the last notify_fail() is the line a
  refusal shows. Use is practice: random(120) for the enabled force (weak mode: a player
  never gains a level from it), random(force * 4) for the basic force. The target is always
  oneself, so the files' `target != me` lines never show.
- **Owner:** in a fight 运功 is queued like 逃跑 and waits while the player is busy (等你空下来);
  ES2 refuses with exert.c's ( 你上一个动作还没有完成，不能施用内功。). Out of a fight a busy
  player gets that line.
- **Owner:** powerup and powerfade (天邪神功, `daemon/class/fighter/celestial`) wait for the
  combat specials package with 安惜迩's exert; the player cannot learn 天邪神功 in Snow.
- std/force.c's reflection is told between the move and the damage line (combatd.c adds the
  hit_ob() string there). **Owner:** its third line, 「$N被$N以内力一震」 in the source, shows $n.
- **Owner (#46 review):** Continue is ES2's login: race/human.c runs again for the player and
  max gin, kee and sen are recomputed with a quarter of max atman, force and mana. Eff and
  current stay unless a maximum falls below them: our tracks keep current ≤ eff ≤ max, where
  ES2 leaves them above until they drop (no maximum shrinks in the game yet). A save made after
  max_force grew is therefore not restored bit for bit.
  (Superseded in part by「积压问题的处理」A7, 2026-10-08: a sitting that raises a maximum recomputes
  max gin, kee and sen at once, not only on Continue.)
- **Owner (#46 review):** exercise pace, option B: the pacing knobs package adds a data
  multiplier for exercise gain or kee recovery, default ES2's; the value is set from playtest.

## Offense/defense routes B: the player's own training (2026-10-03)

Owner-approved plan (the package's second PR):
- **enable.c anywhere outside a fight**, on the character panel's 武学 page, for every use a
  special skill can be enabled for (封山剑法: sword and parry). Supersedes D-SMP2-02 (enable only
  beside 柳淳风) and the teacher panel's 启用/停用 (first use only, no reset). enable.c also works
  in a fight; the page closes in one like every portable action. No busy check (enable.c has
  none). Every enable for force (magic, spells) empties force (atman, mana) with enable.c's line,
  the same skill again too; the page does not offer the skill already enabled.
- practice.c, exercise.c, selflearn.c and study.c run from the page with their lines.
  practice_skill() and valid_learn()'s lines are skills.json data; learn.c, practice.c and study.c
  print valid_learn()'s own line (the last notify_fail wins; PR A printed learn.c's).
- study.c reads items.json `study` (obj/old_book.c: force to 10; the scavenger carries it). It
  spends sen and no potential; a negative cost (int over 40 for the book) changes nothing
  (receive_damage() raises an error).
- Lines keep ES2's colours in the log and on the HUD: practice.c HIY, improve_skill() HIC,
  skill_improved() HIW.
- exercise.c lost characters in the source's encoding: 全身□麻 is shown as 全身酸麻 (痠), the
  bottleneck line ends 瓶颈。 The page's 打坐 amount starts at 30 (exercise.c's help), minimum 10.
- **Owner:** ES2's pace stays. Measured: max_force 0 → 50 takes about 8–16 hours of play (kee
  comes back every heal_up, about 21 s); see the pacing knobs package.
  `tests/runtime/run_with_max_force.gd` (opt-in) gives a playtest max_force 49.
- Where the driver would stop the command with an error (a zero maximum in exercise.c, int 0 in
  selflearn.c, a negative study cost) nothing changes and the page says 你现在无法练功 / 自学 / 研读.
- Not yet: the move use (chaos-steps) has no basic skill, so it is not offered; race/human.c adds
  max_force/4 to max kee in setup() (at login in ES2), and the player's maxima are not recomputed.

## Offense/defense routes A: moves as data, apply/* in combat, 柳淳风 and 安惜迩 fought (2026-10-03)

Owner-approved plan (two PRs; this is the first):
- Skill moves, dodge.c/chaos-steps lines and parry.c lines are skills.json data
  (`liuh_ken_definition.gd` is gone); a move's `dodge`/`parry` stay in the LPC (D-SMP2-05). A
  skill with its own hit_ob() is marked `hit_ob` and stops the fight (not ported).
- A weapon without a mapped skill draws its kind's verbs (weapond.c, std/weapon/*.c); hammers,
  staffs and throwing weapons keep `slash` until weapond.c's post_action is ported. Unarmed
  humans draw race/human.c's five moves.
- Every apply/* reaches combat: armor_prop, the primary weapon's weapon_prop (a secondary
  weapon's is not added yet) and the NPC's own set_temp, for any race.
- NPC internal power (force/atman/mana, force_factor) as create() sets it; race/human.c's
  quarter to max gin/kee/sen. fonxanforce and celestial take std/force.c's force hit; its
  reflection line is not narrated yet (needs an unarmed attacker).
- 安惜迩's accept_fight() answers with kill_ob(): he fights to kill, the challenger only fights
  back, so an unconscious 安惜迩 ends it. 柳绘心 refuses every spar; wear.c female_only.
- **Owner:** combat talk with perform/cast/exert waits for its own package (柳淳风's and 柳绘心's
  sword.counterattack, 安惜迩's spells): they fight weaker than in ES2.
- **Owner (PR review):** the verbs of every weapon kind without a post_action and race/human.c's
  moves stay; an NPC whose learn.c always refuses (柳绘心) keeps its 请教, so players find out by
  trying; kill_ob()'s 看起来X想杀死你！ shows in ES2's HIR red (log and HUD), no native warning.
- Revision `SOURCE_ENTRY_SNOW_ROUTES_V1`: older development saves need a New Game.

## Localization: the source text is the key (2026-10-03)

Package 5, owner-approved; rules and how to add a language: [LOCALIZATION](../production/LOCALIZATION.md).
- Simplified Chinese is the source language and a message's ID is its source text (gettext);
  `tools/l10n/extract_pot.py` is the one extractor (Godot's misses `TranslationServer.translate()`,
  const tables and the content files).
- Authored text stays authored in definitions, state and saves (logic compares it) and is
  translated where it is shown or put into a sentence. A family title is saved as
  assign_apprentice() wrote it and shown put together again. Multi-slot templates name their slots.
- The language follows the system unless chosen in Settings (settings schema 2). The game matches
  Chinese by script and loads only that catalog: Godot would give zh_CN and zh_SG the Traditional
  one. A language not listed reads Simplified; a switch applies at once, old log lines stay.
- Fonts are the system's, listed per language; no font is bundled yet. The title reads 东方故事;
  `config/name` stays (it names the user data folder).
- The player's attack now prints cmds/std/kill.c's line (was a native English line); an aggressive
  NPC's kept a native line, replaced by kill_ob()'s warning (How a fight opens, 2026-10-04).

## Busy wears off on the heart beat (2026-10-02)

`std/char.c` heart_beat(): a busy character spends the beat in `continue_action()` (busy − 1;
a non-positive busy clears) and does nothing else that beat. Outside a fight this now runs on
the S5B 2-second beat, for the player and the NPCs of the active map; inside one the encounter
scheduler does it as before. Supersedes S5B C ("existing busy authority remains the only
advancement owner"), under which busy left by a pickup in a fight (get.c `start_busy(1)`) stopped
recovery and Save for good. The beat still stands still with a condition (S5B E) or while the
player is not ACTIVE (S5B L), where char.c would wear busy down too.

## Give, drop and put; shops and teachers on their NPCs (2026-10-02)

Package 4E, from the owner-approved plan:
- **give, drop, put and get from are `cmds/std/give.c`, `drop.c`, `put.c` and `get.c`** on the
  player's own items, from the inventory panel (给<NPC> when an NPC here is selected, 丢下, 放进<容器>
  beside a container; a stack takes an amount). give.c asks the NPC's `accept_object()`, data
  rules (`accept_object`, first match), and prints the NPC's lines, then destructs money
  (`你拿出十文钱给庙祝。`) and moves anything else to the NPC (`你给收破烂的一件布衣。`): `value()`
  exists only in `std/money.c`, so give.c, keeper.c and teacher.c count money alone. No rule, or a
  refusal, prints 你只能把东西送给其他玩家操纵的人物。 drop.c destructs what has neither a value
  nor a money value (因为这样东西并不值钱…). The world stands still in a fight, so these are used
  outside one, as eating and drinking. A container (`set_max_encumbrance()`, the 功德箱) takes what fits;
  拾取 on it lists its contents, each taken out with get.c's 你从功德箱中拿出一些钱。 Stacks merge
  into the player's (combined.c). Corpses are not put targets yet.
- **Deviation (proposed in the 4E PR, for the owner to confirm): a refused part of a stack stays
  with the player.** give/drop/put with an amount
  split the stack before asking (`new(base_name(obj))`); when the NPC or the container then
  refused, ES2's new object had no environment and the money was lost. The port asks first.
- **ES2 oddities kept:** the drunk's "我还有酒" refusal returns 0 (no `return 1`); the wine he
  takes is moved to him and he drinks it. The keeper's 庙祝不收物品的捐献。 never shows: give.c's
  notify_fail replaces it (driver rule below).
  keeper.c's donation eases bellicosity over 100 (`random(val/10) > kar`, then
  `random(kar) + val/1000`), drawn from the world-interaction stream.
- **Dropped items are saved with their place** (`floor_items`: item, zone, position; written only
  when there are some), laid just before the dropper's feet on a spot a save accepts. A
  floor-spawn item carried off and dropped elsewhere, on any map, is a dropped item.
  A living NPC may have lost loadout items (given, dropped, sold) but lists those that exist.
- **drunk.c do_drink() is a chat action** (`drink`): sated at 380 water it sings; else it drinks
  from its alcohol (liquid.c: water +30, the line), drops the emptied wineskin where it stands
  (drop.c's line) and, with none left, clears `has_alcohol` and asks for wine. **Owner:** the
  drunk condition waits for conditions (the player's wine is deferred too); `has_alcohol` is an
  object variable, not saved (Continue starts it at 1, as create()). The 玉佩/蒙汗药 whispers need
  d/green's temp flags.
- **Owner: emotes print nothing** (sing, sigh, shake, grin, smile, hmm, pat): `data/emoted.o` is
  not in the mudlib. 4A's nod (点了点头。) stays.
- **Shops go with their NPCs.** 店小二, 杨掌柜 and 王铁匠 stand in their shops; their goods
  (`vendor` on the NPC) are bought beside the body (buy.c `present()`), also from an unconscious
  vendor (buy.c does not ask `living()`); a dead one sells nothing until its room resets. The bank
  (`bank.c` convert) and the pawn shop (`HOCKSHOP`) stay the rooms' commands; 安惜迩 stands in the
  bank. The waiter's greeting is one of three lines (`greeting.one_of`); `rank_info/respect`
  (小二哥, 柳馆主) is how the player addresses them.
- **Teachers are data.** `skills.json` names the skills the game models (unarmed, liuh-ken,
  literate); an NPC whose family (`create_family()`, `families.json`) or `recognize_apprentice`
  rules admit a student teaches the ones it has, beside its body (X · 请教), with learn.c's lines.
  柳淳风's `attempt_apprentice()` is the `apprentice` rule (cor and cps 20, class swordsman);
  F_MASTER's prevent_learn() applies. 李火狮 teaches 封山剑派 students (his refusal's
  notify_fail, 李火狮不愿意教你拳法。, wins); 魏无极 teaches whoever paid five taels (marks/魏无极,
  saved with the character). learn.c draws its reject_msg before recognize_apprentice() from the
  world-interaction stream, as ask.c's msg_dunno. dodge, parry, sword and force wait for the
  offense/defense package. The master's ID is his NPC definition (`common.npc.swordsman.master`).
- **heal_me() is judged on the asker (as 4D's owner decision; for the owner to confirm).** dbase.c evaluates herbalist.c's 治伤/疗伤/开药 closure with
  the herbalist himself, as guard.c's ask_me (4D); following that owner decision, the asker's
  eff_kee decides (`eff_kee_percent` answers).
- **Owner: 柳淳风 and 安惜迩 cannot be fought yet** (`fight_deferred`): they map sword to
  fonxansword and dodge to chaos-steps, whose actions are not ported, so every fight would abort.
  No 攻击/切磋 until the 封山剑法/乱七星步 package; 安惜迩's accept_fight (a spar becomes a kill)
  comes with it.
  (Superseded by「Offense/defense routes A: … 柳淳风 and 安惜迩 fought」, 2026-10-03: both can be
  fought, 安惜迩's accept_fight() answers with kill_ob().)
- **Deferred:** the dog's bone (no chicken leg yet; following is not ported), the waiter's cake
  (say), vendor.c's and smith.c's purchase lines, betrayal (change of family), combat talk.
  (Since done: combat talk by「Combat talk and NPC specials」, 2026-10-04; betrayal by「绮云镇 3B:
  joining 振远镖局」, 2026-10-05; the dog's bone and following by「积压问题的处理」A11, 2026-10-08.)
- World content revision `SOURCE_ENTRY_SNOW_SERVICES_V1`: older development saves need a New Game.

## MudOS notify_fail(): the last call wins (2026-10-02)

One driver rule for every command the port runs: when a command fails, the player reads the last
`notify_fail()` set before it returned 0. A message an NPC function sets is replaced by a later
one in the command (give.c's 你只能把东西送给其他玩家操纵的人物。 over keeper.c's), and an NPC's own
`return notify_fail(...)` replaces the command's earlier one (fist_trainer.c over learn.c's
reject_msg). say() and command("say") lines print at once and stay.

## NPCs talk and wander; rooms reset (2026-10-02)

Package 4D, from the owner-approved plan:
- **打听 is `cmds/std/ask.c`** on a selected speaking NPC in the player's place (`present()`):
  ES2's own listing (这里, 名字, 传闻, then the NPC's `set("inquiry")` keys) stands in for typing a
  topic; an answer the NPC files under English `here`/`name`/`rumors` sits behind the Chinese topic
  instead of a second entry. The lines follow ask.c and `inquiryd.c` (the question, then the
  answer, the name answer by attitude with rankd.c's rude words, the room's title, `msg_dunno`
  from the world-interaction stream); the `sigh` after a polite name answer prints nothing
  (`data/emoted.o` is not in the mudlib). Beasts get no 打听, as no 切磋. An answer array keeps
  its strings; ask.c skips its 0s and functions.
- **Topics answered by a function are not data.** 刘安禄's 刘老三/血手刘三 are not listed until his
  reveal is ported. guard.c's `ask_me(who)` receives the NPC itself (dbase.c `evaluate(data,
  this_object())`), so in ES2 anyone who asks has a 50% chance to unmask him; owner: when ported,
  the asker's combat_exp gates it, as the code means. 杜宽's 寄信/收信 go with player mail.
- **Chat is `npc.c` chat()** on the S5B 2-second beat for NPCs in the player's place: `char.c`
  turns a healed NPC's heart beat off when no player shares its room. Not ported: that it never
  comes back on until the NPC is hurt (an efficiency artifact ES2's clean_up hid). Lines go to the
  log as written; an unconscious player reads none (damage.c `block_msg/all`). **Deviation:** an
  unconscious NPC says nothing, neither chat (char.c still runs chat()) nor its greeting. Beats
  and their draws are transient, as heal cadences.
- **Owner: an NPC wanders only at home and next door.** `random_move()` draws one of its room's
  exits; the move happens when the place is its home zone or a zone next to home on the same map,
  no closed door is in the way (`room.c` valid_leave()) and the room is migrated; otherwise nothing
  does, as a failed `go`. ES2's random_move is unbounded until reset calls NPCs home. The
  travellers' Inn exits all leave the Inn's map, so they stay in for now (cross-map wandering
  later). go.c's line (旅客往东离开。) shows where it left. The body walks a path over the map's
  tiles (`AStarGrid2D`, a body's width from walls); its place changes at once, a save takes the
  walk's end, and a fight or leaving the map puts walking NPCs there. On the way it passes through
  the player and notices nobody (ES2 moved it in one step); an aggressive one notices whoever is
  where it arrives, as its init() did.
- **The keeper's greeting is data** (`greeting.say`, `$RESPECT` the player): keeper.c's
  `call_out("greeting", 1)` from init() runs one second of world time after the player comes in,
  or after the keeper comes to where the player is (reset), if the player is still there.
- **Room reset is `std/room.c` reset()** on world time, each room on its own schedule: MudOS's
  `TIME_TO_RESET / 2 + random(TIME_TO_RESET / 2)` seconds, with config.ES2's 1800 as
  `pacing.json` `room_reset_seconds` (a knob; the default is ES2's). A dead NPC is made anew on
  its marker (`make_inventory()` for a destructed object; its ID gets the next generation,
  `<point>.character.<n>`); a living one away from home and conscious, not fighting, hurries home
  (急急忙忙地离开了。); weapon_storage.c's reset() clears the shelf's pushes. Every map resets
  (native rooms are always loaded); Old Pine's bandits and serpents come back too. Schedules are
  not saved: Continue starts them afresh.
- **Owner: an item comes back only once it is gone.** reset() remakes a floor item only when the
  one it laid down no longer exists (sold, eaten): one the player carries is not replaced. ES2's
  `clean_up()` (MudOS memory management: an unvisited room was destructed and reloaded with
  everything new) is not ported.
- **Save:** no new fields. An NPC record may name a later generation and stand away from its home
  zone; a corpse may belong to an earlier generation, checked against the NPC's definition. The world
  content revision stays `SOURCE_ENTRY_SNOW_INNER_V1`: 4C saves load.
- **Deferred:** 醉汉's do_drink (its empty wineskin is dropped and he asks for wine: with give and
  drop, 4E), the waiter's greeting and the shopkeepers' answers (with their bodies, 4E), the
  血手刘三 reveal, combat chat (`chat_msg_combat`), cross-map wandering, corpse decay (corpses of
  respawned NPCs stay), speech bubbles.
  (Since done: combat chat by「Combat talk and NPC specials」, 2026-10-04; speech bubbles by「手感」B1,
  2026-10-15; cross-map wandering by「地图重构」, 2026-10-16, through doors onto the next map, and off
  the player's map by「别的地图时间补算」B, 2026-10-23; corpse decay by「尸体腐烂」, 2026-10-23.)

## Snow's inner rooms (2026-10-02)

Package 4C, from the owner-approved plan:
- **Maps.** The Inn's upper floor (inn_2f and its three guest rooms behind 房门, `DOOR_CLOSED`)
  is its own map up the Inn's stairs; the secret storage is its own map below the weapon storage
  (one map per height level, as Old Pine). The school's inner yard (天井), study, guest room,
  inner hall and weapon storage are zones of the outdoor map, walked into through their ES2 exits.
  (Superseded by「地图重构」, 2026-10-16: every enterable room is on its building's own map.)
- **Items lie on the floor.** A room's `set("objects")` naming an item becomes an item spawn:
  the item lies on its marker when the world is created and is picked up with 拾取, as
  `cmds/std/get.c` (busy, no_get 这个东西拿不起来。, move.c's 太重了). Its identity follows from the
  spawn point, so a save keeps no floor position; there is no drop yet. Room reset (items and
  NPCs coming back) is 4D (above).
- **The weapon storage's shelf** (`weapon_storage.c`) is a landmark whose button is ES2's
  `push <direction>` (往左推); `push shelf`'s hint line is not shown. Three pushes open the way
  down and the way up for ten seconds of world time (stopped in a fight). Opening adds an exit,
  as `set("exits/down")` does: a player standing on the opening is not dropped until they step
  onto it again. Pushes while it is
  open keep counting, so the count can pass three and the shelf then does nothing until the room
  resets, as in the LPC; the count is not saved (ES2 room state), so Continue clears it.
- **Deviation: nobody is shut in below.** `secret_storage.c` has no exits; the way up exists
  only while the passage is open, and only if the room happened to be loaded
  (`find_object`). ES2 players escaped by quitting. Native rooms are always loaded, so both ways
  open together, and the passage does not close while the player is below: once the ten
  seconds are up it closes as soon as nobody is down there. Continue below finds the way up
  open. The far-side lines (天花板…) are never seen and are not data.
- **Deferred:** 柳绘心 (`girl.c`, the study) maps sword to fonxansword, whose actions are not
  ported, so every fight with her would abort; she comes with the 封山剑法/乱七星步 package.
  桃符纸 (`/obj/paper_seal`) is a combined item and waits for combined items, with 蛇药 and
  飞刀. The 功德箱 lies in the temple and cannot be taken; putting things in and taking them out
  (`put`, `get from`) come with give (4E). Its `insert_object()` never runs in MudOS (no such
  apply), so a donation changes nothing.
- **Driver rule:** an object without `set_weight()` weighs 0 (`feature/move.c`); the importer
  writes it.
- World content revision `SOURCE_ENTRY_SNOW_INNER_V1`: older development saves need a New Game.

## Snow's south road and shops (2026-10-02)

Package 4B, from the owner-approved plan:
- **Nine rooms, nine zones of the outdoor map**: sroad2-5, the school (书院), the smithy, the
  herbshop, the post office and the Hockshop storage room, walked into through their ES2 exits
  (the storage room through the curtain, no door). sroad4's southwest (`d/canyon`) and sroad5's
  west (`d/waterfog`) end at a boundary with a sign until those regions exist. `herbshop1.c`
  (药铺密室) has no entrance anywhere in the mudlib and is not migrated.
- **Shops are services until 4E**: 杨掌柜 (`herbalist.c`) and 王铁匠 (`smith.c`) are their
  counters' vendor services without bodies, as the waiter and 安惜迩 in 4A.
- **A vendor's own price.** `smith.c` sells through its own `buy_object()` (300 coins for a
  hammer worth 3), not `vendor_goods`: the override file holds such goods with their price, and
  a goods record may carry `price` (absent = the item's value, `feature/vendor.c`). The shop
  panel shows prices as `vendor.c`'s `price_string()` (3两银子, 15文钱); its button reads 购买.
  The smithy's panel lists the hammer too, although `smith.c` has no `list`: in ES2 the price
  is learned by asking him (4D).
- **Deferred:** 蛇药 (a combined item; each dose lowers snake_poison by 1) and applying 金疮药
  (`apply`: refused in a fight or unhurt, restores up to 20 eff_kee, used up) wait for the
  treatment package; the medicine can be bought and sold. NPC wimpy (farmer, woodcutter) and combat talk wait for a later combat package; ask, chat
  and random_move are 4D; 魏无极's tuition and literate are 4E.
- **Omitted:** player mail (杜宽's 寄信/收信, the mailbox, `postoffice.c` `valid_leave`) is a
  multiplayer feature.
- World content revision `SOURCE_ENTRY_SNOW_SOUTH_V1`: older development saves need a New Game.

## Battle narration in ES2's words (2026-10-01)

Owner decisions for the new-player combat package:
- **The battle log prints `combatd.c`'s lines** as `message_vision()` shows them to the player
  (你 for the player, names and `gender.c` pronouns for the others): the action, the dodge line
  of the victim's mapped dodge skill (only `dodge.c` is ported; no content maps another), the
  `parry.c` line chosen by the attacker's weapon, `damage_msg`, `report_status`, `winner_msg`,
  `guard_msg` and the two riposte lines. The damage follows its line as a small grey number.
- **Deviation: dodge and parry wording draws nothing from the combat random source.** The LPC
  picks them with the driver's `random()`; the port's combat stream never had those draws, so
  the presentation picks the line with its own generator. `winner_msg` and `guard_msg` use the
  index Core already draws.
- **Source text as written:** the Big5 `□` stays (血肉□糊, the `□伤` case), and `$w` stays in a
  line whose unarmed action names no weapon (a beast's 刺伤 of 80 or more).
- **Native lines, ES2 has none:** the end-of-fight line (切磋结束。, 你赢了这场战斗。…), the
  player's target, a queued, refused or given-up Flee. Skipped turns and busy print nothing.
- **Deferred:** `std/force.c`'s reflection lines (nobody can enforce yet) and `announce()`
  (昏倒, 死亡) in the battle log.

## 切磋: fight.c, accept_fight and armed spars (2026-10-01)

Owner decisions for the new-player combat package:
- **The 切磋 button runs `cmds/std/fight.c`** on the selected NPC: 这里禁止战斗。 in a `no_fight`
  room, 加油！加油！加油！ when it already fights you, …已经无法战斗了。 when it is down, the
  challenger's line in `rankd.c` words, then the NPC's `accept_fight()`: `npc.c` by attitude and
  health (gin, kee and sen at 90% or more), or the NPC's own rules as data (`accept_fight` in the
  NPC definition, written in the override file). A refusal prints the NPC's line and
  看起来…并不想跟你较量。. The spar ends on the first blow that draws kee (`combatd.c`).
- **Deviation: beasts are not asked.** `fight.c` makes a non-speaking target `kill_ob` you while
  you only fight; that needs a mixed encounter shape and NPCs coming to afterwards. Beasts get
  no 切磋 button for now; the dog can only be attacked.
- **Armed spars as in ES2.** Replaces "Active Semi-Auto V1 SPAR establishment is unarmed-only":
  a weapon on either side wounds (`combatd.c`: `is_killing || weapon`), so a spar can knock out
  or kill, through the normal lifecycle (corpse, gargoyle, temple). A native line, ES2 has none,
  warns when an armed spar starts: 刀剑无眼，持兵刃比试可能真的受伤。.
- **The killer is `last_damage_from`.** Replaces the 2026-09-30 deviation "the penalty applies
  when a lethal opponent is found": whoever landed the last blow is the killer for
  `killer_reward` and the corpse, in a spar too. A kill mark stands in only when no blow is known.
- **NPCs heal and come to.** Extends S5B's "None for NPCs": the NPCs of the active map run
  `heal_up()` on the `char.c` tick between fights (transient cadence, as the player's), also
  while unconscious, as `char.c` does. An unconscious NPC comes to after `damage.c`'s
  `random(100 - con) + 30` s of world time; the countdown is saved (`revive_in_ms`, written only
  while one is pending) and dropped when the NPC dies. Inactive maps stay frozen.

## A failed fight ends instead of freezing (2026-10-01)

Owner decision for the new-player combat package:
- An attack chain that cannot complete, an opportunity whose opponent selection or fight decision
  fails, or a lifecycle that fails now ends the encounter with an `ABORTED` result. Damage dealt
  stays, anyone below zero kee falls or dies (`char.c` heart_beat does that outside a fight), every
  participant drops its fight and kill marks on the others, the world returns and the log shows
  战斗出错，已中止。. It replaces holding the encounter in RESOLVING for good, which refused Flee
  and never ended. A partial death still blocks Save, and later falls on that map abort too,
  until the cause is fixed.
- Development builds `push_error` the cause (failure, opportunity, attack and progression stages).
  A test suite during which a fight aborts fails (`SuiteResult`) unless it takes the count itself.

## MudOS random(n <= 0) is 0, everywhere (2026-10-01)

Owner decision for the new-player combat package:
- **One driver rule.** MudOS `random(n)` returns 0 for `n <= 0` and draws nothing. Every LPC
  `random()` the port runs calls `legacy_random(n)` on its random source (combat, NPC creation,
  world interaction; 16 call sites). A source that answers out of range is still an error.
- **It replaces the per-site exceptions** recorded below: "Combat invalid random bounds become
  ordered typed failures", "Non-positive authored world random bounds become ordered typed
  ambiguities", P2B-ZE1's zero-EXP defense boundary, CXR9's unarmed zero base damage (armed zero
  base and negative apply/damage now follow the formula as well) and S6B's Vine waterfall
  exception (the technical fixture now falls too).
- **In play:** a zero-damage blow that may wound (armed or killing) no longer stalls the fight
  (`random(0) > armor` is false: no wound); zero cps rolls 0 and attacks or ripostes; zero dodge
  falls from the vine; an NPC with no int learns nothing from a miss.
- **Not random(0):** a negative attacker exp would loop `combatd.c`'s defense loop for ever and
  stays an invalid-state failure; `beast.c` leaves spi and kar unset (0), not `random(0) + 5`.

## Content importer and Snow's first NPCs (2026-10-01)

Package 4A, from the owner-approved Package 4 plan:
- **Imported data.** `tools/migration/content_importer.py` writes rooms, items, NPCs, spawns and
  vendors under `game/data/` from the LPC plus `tools/migration/overrides/<region>.json`. Those
  files are generated and never edited by hand (`tools/tests/test_content_import.py`); every LPC
  fact that does not become data is a finding with a recorded decision in the override file.
  Migration Tooling v1 (`room_extractor.py`, `cli.py`) is retired; its lexer (`es2_source.py`)
  stays.
- **Driver rules, applied once:** a string escape MudOS does not know, `\X`, yields `X` (the Big5
  conversion left `功\德`); colour macros (`CYN`, `NOR`, …) are presentation and leave the text.
- **Random `create()` values** (`600+random(400)`, `if (random(10)<7) set("gender", …)`) are data
  rules, drawn when the NPC is created and before its race's draws; saves keep the drawn values.
- **`no_fight` rooms** (temple, workplace): attacking from or into one prints kill.c's
  这里不准战斗。, and aggressive NPCs start nothing there (combatd.c). A zone is no-fight when any of
  its rooms is.
- **Beasts** use every `beast.c` verb they author, one drawn per attack (`query_action`): the
  dogs bite and claw.
- **Deferred, not changed:** the waiter and 安惜迩 stay services without bodies until services are
  bound to their NPC (4E); the square's three 飞刀 travellers wait for combined throwing weapons;
  items lying in rooms (the temple's paper seals and donation box) come with 4C.
- World content revision `SOURCE_ENTRY_SNOW_NPCS_V1`: older development saves need a New Game.

## Old Pine: one map per height level, collision on tiles (2026-09-30)

Owner decisions for Package 3B5:
- **One map per height level.** ES2 joins Old Pine's levels mostly by actions: climb pine
  (`clearing.c` → tree1), hold vine (`epath2.c` → waterfall or passage), climb cliff
  (`riverbank1.c` → cliff1), climb up/down (`cliff1.c`); tree1 `down` and passage `south` are
  exits. They used to sit side by side in one scene, joined by same-map teleports. Now the forest,
  the gorge (waterfall, riverbank1-2, lake), the tree top and the cliff niche are separate maps,
  and each of those moves is a scene transition. No Old Pine portal stays on its map. This
  replaces B2's "waterfall pool is walled from above". Nobody climbs mid-fight (an encounter
  freezes the world), but after a Flee the separated opponent mark used to wait for the next round
  (as LPC's `clean_up_enemy` on the next heart_beat); a transition now clears it on arrival.
  Lethal (killer) marks stay.
- **The forest follows the ES2 exits.** (Placement superseded by「老松林按原文方位排布」,
  2026-10-25; the exits themselves are unchanged.) npath enters from the west (`clearing.c`
  west → npath3), and cliffside is walked into pine1 (`cliffside.c` north). The walk works both
  ways although pine1 has no exit back: cliffside is a dead end with no way down, so this opens
  no route.
- **Static terrain collides through its tiles.** Walls, forest, water, cliffs and chasms carry a
  TileSet physics shape; the map's walkable area is what is painted with walkable tiles. Doors,
  exits closed in one world (e.g. `SnowBlocker`) and other switchable blockers stay nodes. Old Pine
  uses this from 3B5, Snow from 3B6. This replaces 3B4's "collision waits for art".
- **A corpse lies where its body fell**, shifted sideways (at most 40 px, same zone) when its wider
  footprint would overlap a wall, so a save always holds a position Continue accepts.
- **Tile data stays inline.** Large maps keep their `tile_map_data` in the scene file (about 1 MB
  for Old Pine). Terrain layers move into a per-map sub-scene when real art arrives.

## One map runtime: zone ownership, Old Pine geometry and the combat round (2026-09-30)

Owner decisions for Package 3B2 (Old Pine on `WorldMapController`):
- **Zones follow the body's center.** A zone owns the player when its half-open rectangle holds the
  body's center, and the player only moves between neighbouring zones (an ES2 exit, or a `links`
  entry). Old Pine used to switch as soon as the body's edge touched a zone, in any direction.
  Only the player is tracked; NPCs do not walk between zones.
  (NPCs superseded by「NPCs talk and wander; rooms reset」, 2026-10-02: they wander at home and next
  door, and since「地图重构」, 2026-10-16, through doors onto the next map.)
- **Recorded native connections become data.** Central Clearing ↔ Pine Entrance ("Old Pine Outdoor
  directly connects to the Pine Maze") and the fixed maze (Entrance ↔ Deep ↔ Cliff Edge, "Random Pine
  room exits become one fixed continuous maze") are zone `links`.
  (The first link superseded by「老松林按原文方位排布」, 2026-10-25: East Bridge ↔ Pine Entrance, by
  epath3's plank road into pine1; the clearing has only its three ways.)
- **The waterfall pool is walled from above.** `waterfall.c` has only `south`; ES2 reaches it by the
  `epath2.c` vine, `passage.c` south or riverbank2 north. The scene let the player walk down from the
  East Bridge and the South Slope; both edges are now cliffs.
  (Superseded by「Old Pine: one map per height level, collision on tiles」, 2026-09-30: the gorge is
  its own map.)
- **Global rule — one combat round per heart_beat.** Every living object ran on one driver
  heart_beat; the encounter scheduler's interval is `common/pacing.json` `combat_round_ms` (1000, the
  previous feel) on every map. It used to come from an unset Timer on Old Pine only (0 elsewhere).
- The Lake's complete-set entry (P2A-M) is the zone's `combat_entry`, unchanged in behaviour.
  (Superseded by「进门一起上」, 2026-10-24: every zone works so, `combat_entry` is gone.)

## Player unconsciousness and death follow ES2 (2026-09-30)

Owner decision after playtest: a defeated player is no longer a terminal state.
- **Killers finish the job:** an encounter continues while an active enemy still holds the unconscious
  player as a lethal target (`feature/attack.c` `remove_enemy`, `std/char.c` heart_beat). Replaces the
  CXR8 rule that player unconsciousness always ended the encounter as DEFEAT.
- **Waking and dying:** unconscious players wake after `random(100 - con) + 30` s (`damage.c`); dead
  players get the `killer_reward` penalty, the white gargoyle lines and reincarnate at `/d/snow/temple`.
  The technical fixture revision keeps its terminal defeat.
- **Save:** blocked while unconscious or on the way back from death (the player cannot act,
  `disable_player`). This narrows "Native saves require a restart-stable gameplay boundary": UNCONSCIOUS
  and DEAD players are no longer eligible. Older saves holding such a player resume the flow on
  Continue without a second penalty.
- **Deviations:** waking up waits until no encounter is active (LPC's call_out fires regardless; an
  unconscious victim cannot dodge, so killers finish within a few blows). The penalty applies when a
  lethal opponent is found, not from LPC `last_damage_from`. The death realm walk, corpse decay, NPC
  revival and healing while unconscious are not implemented yet.
  (Superseded: the killer by「切磋: fight.c, accept_fight and armed spars」, 2026-10-01, now
  `last_damage_from`, where NPCs also heal, unconscious too, and come to; the death realm walk by
  「鬼门关 A」, 2026-10-15, which replaces the revival at the temple; corpse decay by「尸体腐烂」,
  2026-10-23.)

## Old Pine Lake — owner-locked P2A foundations

Owner authorization (2026-09-26), following [Lake P1](PHASE_OLDPINE_LAKE_SERPENT_PRODUCTION_SOURCE_ANALYSIS.md):

- **M: complete-set admission before freeze.** Revalidate coherent current physical contact,
  identity, existence, ACTIVE/available state, combat location and permission. Include every
  actually eligible aggressive enemy; Player plus five is legal. Same map/zone alone is not
  contact, and LPC `MAX_OPPONENT=4` is selection behavior, not encounter capacity. Manual Attack
  retains its own target policy and also includes eligible aggressive contacts. Use stable ID
  ordering, one transaction, one existing encounter/scheduler and full relationship rollback.
  No signal-order selection, delay-to-collect, mid-combat joining, replacement or reinforcements.
  (Superseded in part by「进门一起上」, 2026-10-24: the whole gang of the player's zone joins, near
  or far, and the alert beat `hostile_alert_ms` (500) collects whoever is in the zone when it ends;
  joining mid-fight still cannot happen, the world stands still.)
- **W: bounded shore Fill.** Reuse direct-held wineskin, ACTIVE, busy/combat, location/distance
  and liquid-service checks. Lake geometry and UI hookup belong to P2B; no environmental Drink,
  general river water, poison or swimming.
- **R: CURRENT WORLD ONLY.** Follow the [development save policy](../production/contracts/NATIVE_SAVE_LOAD_CONTRACT.md#development-save-policy).
  No old/new product-world branches or save migration. Reject incompatible files explicitly;
  never delete, rewrite, respawn, reroll or silently start New Game. P2A retains current public
  SOURCE_ENTRY_V1 with five humans. The future content-marker cutover must be atomic with P2B
  Lake geometry, five additional production slots and complete persistence. Root/item schemas
  change only for a real format change, not a content publication or a Git commit.

This locks M/W and authorizes P2A foundations only. P2B/P2C, Final Audit and integration require
separate owner instructions; historical P1 alternatives remain historical.

## Hockshop valuation / payout / sell lifecycle (H2)

**OWNER APPROVED — H2.** H1 is OWNER APPROVED / CLOSED at
`7dc3efcdbe7a27fd0d39ee648053dff6f7c612b7`. This A–N package is recorded in a
standalone decision-only commit before production implementation. It supersedes H1's
recommendations, not its source archaeology. No Type C redesign is approved.

- **A — Type B scope:** Value/appraisal and irreversible sell only. Defer pawn and its60%
  transaction, tickets, retrieve, custody, loan and auction; no dormant production pawn API.
- **B — Type B truthful omission:** Do not repeat the source ticket/redeem promise or invent
  redemption. The contradictory prose and low-value pawn formatting remain documented defects;
  reconsidering pawn requires a separate owner decision.
- **C — Type A ownership / Type B selection:** Exact ItemInstanceId replaces textual aliases.
  Appraisal and execution independently require current index/inventory existence, Player direct
  ownership and supported leaf content. Wielded/worn items remain eligible. Reject stale, ground,
  nested, other-character, corpse-held, container, living and unknown items; no recursive sale.
- **D — Type B typed representation carrying Type A facts:** Narrow hybrid: exact dumpling
  FoodState.current_value (fresh15, bitten0); valid wineskin Liquid association with existing
  immutable value20; static source projections cloth0, short sword300, long sword700, leather200.
  No universal mutable price, dbase dictionary, query emulator or merchant inventory. Known-zero
  and unsupported are distinct. Current swords have no new depreciation state.
- **E — Type A zero / Type B invalid-state boundary:** Zero appraises WORTHLESS and rejects
  sale with no allocation, payout or destruction. Negative/malformed/unsupported values fail
  closed explicitly; no abs, clamp-to-one or emulated broken coercion for invalid Native state.
- **F — Type A payout / Type B checked boundary:** Checked integer source_value*80 then /100;
  for positive valid values preserve pay_player's result<1→1. Overflow fails before allocation
  or mutation. Quote actual payout; no floating point or pawn calculation API. Fresh dumpling12,
  wineskin16, leather160, short sword240, long sword560.
- **G — Type A physical money:** Silver first (N/100), then coin (N%100), skipping zero.
  Never gold or wallet. Each attempt allocates a new canonical full-quantity stack BEFORE move.
  Do not reuse Bank's amount1 admission or directly grow an existing target. Normal merge retains
  the incoming ID and destroys old same-denomination stacks.
- **H — Type A ordered partial capacity result:** Sold item remains held/equipped during
  admission. Ordinary capacity refusal continues after its required cleanup; retain earlier
  delivered money and destroy the sold item after normal attempts complete, even if both fail.
  No refund, rollback, ground drop, final-total/net-weight preflight or existing-stack bypass.
- **I — NEW Hockshop-specific Type B cleanup:** Immediately after each ordinary capacity
  refusal, destroy that parentless clone through authoritative ItemLifecycle, retaining consumed
  allocator sequence/ID, BEFORE attempting the next denomination. No orphan persistence, ID reuse,
  cleanup timer or compensation. This deliberately replaces later MudOS cleanup, NOT its exact
  timing, and is separately approved, NOT inherited from Work/Bank/Vendor. Cleanup failure returns
  AUTHORITY_FAILURE, retains reached effects and stops: no later denomination or sold-item
  destruction. This supersedes H1's suggested all-attempts-before-cleanup order.
- **J — Type A payout-before-destruction / Type B authority errors:** After normal attempts and
  cleanups, use existing lifecycle with LIVE Player Equipment/Armor/Inventory/Combined authorities.
  Clear the exact hand/worn slot without invented secondary promotion; remove Inventory/stack,
  then Food/Liquid associations, then derived index. Allocation/registration/merge/cleanup or
  final detach/destruction errors stop with typed AUTHORITY_FAILURE and prior effects retained,
  never rollback or false success. Current non-money stack commerce remains unsupported.
- **K — Type B future physical scope:** H3 front room /d/snow/hockshop only; hockshop2 deferred.
  Narrow authored-closed reopenable local door, no generic door engine or persistent door state;
  fresh Session/cold Continue may restore the closed default. No H2 scene/topology/door changes.
- **L — Type B future interaction:** H3 physical room/proximity-scoped exact-instance Value/Sell
  panel, not global Inventory Sell, merchant NPC, stock/cash or anywhere-commerce. H2 provides
  no world permission or player-facing UI; physical gates belong to the separately authorized H3.
- **M — unchanged Save:** Root schema2 / embedded item schema3 / SOURCE_ENTRY_V1. No saved
  transaction, account, stock, ticket, door or sale history. Existing money, item absence,
  equipment/armor and Food/Liquid absence plus allocator continuation carry settled full/partial/
  zero-delivery sales. Restore allocates zero gameplay IDs; legal baseline saves remain supported.
- **N — staged authorization:** H1 closed; H2 typed core current. H3, distinct Final Audit and
  the one final milestone PR are NOT authorized now. Commit/push H2 then stop for owner review.

Sources: `reference/es2/mudlib/std/room/hockshop.c`, `feature/move.c`,
`std/item/combined.c`, `adm/simul_efun/object.c`, `feature/equip.c`, `feature/food.c`,
`feature/liquid.c`, `obj/cloth.c`, `obj/example/dumpling.c`, `obj/example/wineskin.c`,
`d/oldpine/obj/{short_sword,long_sword,leather}.c`, `obj/money/{coin,silver,gold}.c`.
See [H1 archaeology](PHASE_SNOW_HOCKSHOP_LOOT_MONETIZATION_CONTRACT.md). Prior service
failure policies, PlayerBodyFacts, economy, recovery and owner-local tooling remain unchanged.

## Fresh water supply loop (S6B only)

**OWNER APPROVED — S6B.** S6A is OWNER APPROVED / CLOSED at
`945a8bde0d8d2734f737b51fb6619cf42e8ff5cd`. These A–M decisions are committed separately
before implementation. They authorize no final Snow PR, alcohol runtime or next slice.

- **A — source selection:** First source is `d/oldpine/waterfall.c`, resource/water1,
  represented by `oldpine.outdoor.waterfall_basin`. Unlimited; no depletion, reset or cooldown.
- **B — narrow Type B Vine supersession:** For playable SOURCE_ENTRY_V1 only, effective dodge<=0
  selects the existing Waterfall branch through normal presentation/movement with zero World RNG
  draws. No clamp, fake draw, dodge mutation, skill grant or reverse cliff edge. Historical
  random(0) behavior is still unproven; this resolves the monotonic low-dodge intent, not new
  Type A evidence. Positive bounds retain exactly one existing draw, range [0,bound), <5 Waterfall,
  otherwise Passage; invalid draws remain typed failure. Other revisions and authored random-bound
  policies retain their previous ambiguity behavior.
  (Superseded by「MudOS random(n <= 0) is 0, everywhere」, 2026-10-01: zero dodge rolls 0 and falls
  from the vine on every revision.)
- **C — canonical content:** Waiter sells `es2:obj/example/wineskin` from `obj/example/wineskin.c`:
  牛皮酒袋, aliases wineskin/skin, unit个, weight700, value/price20, max15, fresh alcohol/红酒15,
  drunk_apply6. Ordinary ITEM+F_LIQUID, not combined/food/weapon/armor. Unlimited fresh-ID purchases.
- **D — truthful fresh wine:** Preserve RED_WINE15, including through Save/Continue. No empty,
  clear-water or renamed substitute. Staged UI must explain incomplete alcohol support honestly.
- **E — Type B alcohol omission:** Alcohol Drink returns typed ALCOHOL_DEFERRED before mutations:
  zero portions/water/busy/conditions/RNG. No harmless wine substitute. ConditionSystem, drunk,
  missing receive_healing, recovery condition freeze and unconscious/revive remain untouched.
- **F — Type A fill and identity:** Full/partial/empty wine or water can be discarded/refilled
  to CLEAR_WATER15 on the SAME item/definition/parent/weight, zero allocation. No empty-first rule,
  poured-wine item or replacement. Authored drunk_apply6 remains; water never applies drunk.
- **G — water semantics and valid-state boundary:** Validate action/item, ACTIVE/in-world ordinary
  availability, busy, direct ownership, staged combat exclusion, valid positive remaining, then
  Player water<capacity. Success decrements one portion then adds30 water without clamping or
  immediate healing. Body80000 capacity400:400 refuses unchanged,399→429,0→30. Empty0 survives,
  with same ID/parent/weight700/value20/content. No food/condition/busy/RNG mutation. Native legal
  liquid states are remaining0..15; source arbitrary negative truthiness is not normalized.
- **H — Type B reachability:** Specific Player-direct-held instance only, no ground/nested/NPC/
  other-holder use. Distinct wineskins remain independent. This is not full LPC add_action reach.
- **I — Type B noncombat/ACTIVE staging:** Reject active encounter/fighting without busy or other
  mutation. Existing busy blocks but is not advanced/cleared. Successful noncombat use adds no
  busy; source fighting-success busy2 is deferred. Require published active Session, ACTIVE world
  Player and ordinary interaction availability; paused/staged/nonworld/dead/ghost use is excluded.
- **J — wineskin-specific Vendor extension:** Explicitly extend S4B waiter A–D ONLY to this offer.
  Resolve/validate item/liquid/persistence facts and canonical price before affordability/payment;
  malformed static facts reject free. Preserve S3B0/1/2 and ordered payment. After payment allocate
  → full-weight registration → index → fresh liquid state → post-payment capacity transfer.
  No pre-payment final-weight preflight. Paid failure retains money and sequence/ID consumption;
  destroy only safe parentless product through authoritative ItemLifecycle, then liquid association,
  then derived index. No refund/drop/orphan Save/timer/fallback. Cleanup failure is authority failure.
  Truthful paid=true/delivered=false. Dumpling remains unchanged; no generic Vendor/Bank policy.
- **K — Type B typed composition:** Session owns one LiquidCollection keyed by ItemInstanceId;
  LiquidState holds typed RED_WINE/CLEAR_WATER plus remaining. Definitions own max/hydration/drunk
  metadata/display/weight/value. Inventory owns existence/parent/weight. No UI text/dictionary/
  Callable/parent/price in mutable payload, duplicate inventory or generic consumable engine.
  Do not infer universal liquid-versus-food/weapon/armor/stack role exclusivity from this one item.
- **L — Type B embedded format:** Item schema2→3, deterministic typed liquid_consumables records
  of ID/content/remaining. Root schema2, SOURCE_ENTRY_V1, root keys and three saved RNG streams
  unchanged. Strict item1 five historical keys; item2 adds food_consumables; item3 also requires
  liquid_consumables. Unknown/missing/extra keys reject. Legal old1/2 decode with empty liquid
  records then current validation; explicit resave writes3, not old JSON byte equality. Never
  recreate fresh wine for missing state. Reject duplicate/dangling/non-liquid/missing records,
  unknown content, negative/>15 remaining, wrong weight/identity. Both content kinds0..15 valid,
  including empty live items. Restore fresh collection with exact IDs/parents/allocator, no draw
  or allocation/refill. Preserve supported root2/item1 food-validation behavior; root1 unsupported.
- **M — Type B bounded physical/UI scope:** Only Waterfall exposes environmental Fill, requiring
  current active-map/authoritative zone/valid placement/near-marker proof and selected direct-held
  instance. No map-ID-only access or direct environmental Drink. Static marker is not saved/item/NPC.
  Fill validates availability → ownership → busy/combat → water source → liquid facts, then sets
  CLEAR_WATER and max15; Player water unchanged. Held clear-water Drink is map-independent via one
  Session UI. Show contents/remaining and truthful wine-discard action. Riverbanks remain authored
  but staged; no Green/Snow north/Lake or new return shortcut. Work/Bank/dumpling and S5B unchanged.

Source facts: `reference/es2/mudlib/feature/liquid.c`, `obj/example/wineskin.c`,
`d/snow/npc/waiter.c`, `d/oldpine/epath2.c`, `d/oldpine/waterfall.c`, `feature/damage.c`,
`feature/vendor.c`, `feature/finance.c`, `feature/move.c`. See
[S6A archaeology](PHASE_SNOW_TOWN_CORE_HUB_WATER_DRINK_SOURCE_CONTRACT.md).
S4B wine deferral and single-offer boundary are superseded only as explicitly scoped above;
its historical evidence and unrelated decisions remain unchanged. S5B's embedded item2 checkpoint
is historical after L; its recovery behavior, independent body facts and timing remain unchanged.

## Player recovery / metabolism cadence (S5B only)

**OWNER APPROVED — S5B.** S1/S2/S3A/S3B/S3C/S4A/S4B/S5A are OWNER APPROVED / CLOSED.
These A–M choices supersede S5A's recommendations, not its source findings. This ledger is
committed separately before production implementation; it does not authorize a final Snow PR.

- **A — Type A count shape:** Preserve `5 + random(10)` stored countdown5–14 and source
  post-decrement semantics: reset5/6/14 yields recovery on eligible pulse6/7/15. At old0,
  draw/store the next reset before applying recovery. No fixed mean or reroll after a failure.
- **B — Type B timing:** Native S5B uses an owner-approved **2.0-second base pulse because
  the original wall-clock heartbeat period is not proven**. The bundled manual's usual2s
  is supporting context, not proof of ES2 deployment. Unblocked opportunities take6–15
  pulses (12–30 seconds of eligible Native time). Process all complete active-delta pulses
  synchronously in order and retain remainder; reject non-finite/negative time, no silent cap.
- **C — source busy ordering:** At each due base pulse inspect busy at entry. Consume the
  pulse's time but do not decrement countdown, recover, update conditions, advance busy or
  draw RNG. Busy1 still blocks. Existing busy authority remains the only advancement owner.
- **D — Type B staged combat omission:** Source permits nonbusy fighting recovery. S5B
  freezes accumulator/countdown during any active encounter or fighting relationship,
  consuming no recovery RNG/metabolism. Resume the same phase after combat. Do not change
  combat timing or use its scheduler as heartbeat; noncombat world-gate freezes also freeze time.
- **E — staged condition dependency:** Any active condition payload (including unsupported
  IDs or zero/negative durations) freezes the entire S5B phase. No handlers, duration mutation,
  expiry or RNG. Source condition→no-heal→recovery order cannot be partially activated by
  healing while its conditions are frozen. This is not source condition behavior/parity.
- **F — Player-only staged scope:** Exactly one Session-owned cadence for SOURCE_ENTRY_V1
  Player. None for NPCs, inactive residents, corpses or LEGACY_OLDPINE_V1 technical sessions.
  Invalid/unpublished/staged candidates cannot tick; unsafe handoff/swap freezes time.
- **G — Type B Pause:** Freeze the complete phase and resume its exact in-memory remainder
  and countdown, without catch-up or reroll. Menus never grant rest/recovery time.
- **H — no offline simulation:** Closed-app time causes zero recovery/metabolism. No clock,
  login/save timestamp, elapsed offline calculation or bounded catch-up is introduced.
- **I — transient phase:** LPC `tick` is static and not saved. Native Save does not reset the
  live phase; fresh Source Session/Continue creates accumulator0 and draws one initial tick.
  Do not save countdown, accumulator or cadence RNG. Map activation/handoff/rollback, Pause,
  combat and condition appearance/removal retain the same live authority without reroll.
- **J — independent transient RNG:** One typed private recovery random source, with injectable
  deterministic tests and dedicated production RNG; no global random state or use of combat,
  NPC-initialization or world-interaction streams. Continue draws only the new transient stream;
  the three persisted streams restore exactly with zero draws. No RNG field is added to Save.
- **K — unchanged Save contract:** Root schema2, embedded item schema2 and SOURCE_ENTRY_V1
  remain exact. Pre-S5B saves load without migration or new optional keys. Only existing
  character facts mutated by recovery persist. Capture is synchronous at a settled boundary;
  ordinary counting does not itself block Save. No cadence section or recovery timestamp.
- **L — ACTIVE-only staged life scope:** Freeze for UNCONSCIOUS/DEAD/other non-ACTIVE state;
  no recovery, metabolism, revive, ghost behavior or new lifecycle reconciliation. Only an
  existing legitimate return to ACTIVE resumes the retained phase. This omits source paths.
- **M — deferred age/idle:** No age/mud_age clock, idle timeout, user_dump, netdead/login
  heartbeat, age gifts or idle rewards/penalties. This is not a general heartbeat emulator.

Implementation must borrow existing `CharacterRecovery.apply_tick` with current raw magic,
force and spells, Player=true/no-heal=false only after the staging guards. No formula, food,
Work, Bank or Vendor changes. Water remains a real supply limit; no refill/starvation system.
Sources: `reference/es2/mudlib/std/char.c`, `feature/damage.c`, `feature/condition.c`,
`include/condition.h`, `doc/efuns/random`, `set_heart_beat`, `save_object`.
Archaeology: [S5A contract](PHASE_SNOW_TOWN_CORE_HUB_RECOVERY_METABOLISM_CONTRACT.md).

## Snow waiter / dumpling supply loop (S4B only)

**OWNER APPROVED — S4B.** These decisions take effect under the owner's S4B instruction.
S1/S2/S3A/S3B/S3C and S4A analysis are OWNER APPROVED / CLOSED. The historical S4A
recommendation table is not rewritten. This does not authorize a final Snow PR or later goods.

- **A — Vendor-specific Type B:** Resolve/quote, affordability, successful ordered payment,
  allocate/create goods, then attempt full-weight delivery. Ordinary capacity failure keeps all
  payment/depletion and consumed IDs/sequences. Immediately remove the provably parentless
  product through authoritative ItemLifecycle, remove associated food state only after removal,
  then update the derived index. No refund, ground drop, orphan persistence, timer or retry.
  Cleanup failure is an explicit authority failure; no fallback. This is separately approved
  for Vendor, not inherited from Workplace S2 or Bank S3B and not a general failed-transfer policy.
- **B — static validation / ordered failure:** Validate the supported offer, source price,
  item/food/persistence definitions before affordability/payment. Missing/malformed content
  rejects without payment or allocation, never substitutes a product/price. After successful
  payment, allocation/creation/registration failures retain reached money/sequence mutations.
  A known safe parentless live partial product may be cleaned using A's ordered lifecycle.
  Unknown ownership is not destroyed; cleanup failure has no fallback or compensation.
  Capacity admission still uses post-payment inventory, never an earlier final-weight preflight.
- **C — Type B truthful presentation:** Report paid=true/delivered=false when paid goods
  are not received. Suppress LPC Vendor's unconditional success text without changing money order.
  Preserve underlying affordability, payment, allocation, transfer and cleanup evidence.
- **D — Type A stock:** Unlimited clone-on-demand offers; every purchase creates a fresh ID.
  No stock counts, restock, cooldown, merchant money/inventory, sold-out state or stock Save.
- **E — Type B staged omission:** Waiter's missing /obj/example/cake remains deferred.
  No substitute cake, free supplies, birthday relay or persistent gift entitlement.
- **F — deferred wine contract:** No wineskin/red wine, water-only substitute, drunk,
  receive_healing repair or intoxication/lifecycle scheduling. Liquid/condition semantics
  require a later explicit contract.
- **G — Type B initial use reachability:** Eat only the specific Player-direct-held food
  instance, ACTIVE and outside combat with ordinary world interaction available. No ground,
  nested, NPC-held or combat use; no new busy2/timer. Preserve an existing applicable busy
  block. Use remains map-independent, never Inn-only or waiter-proximity-dependent.
- **H — typed state / exact semantics:** Session owns one typed food collection keyed by
  ItemInstanceId, associated with the existing item graph, not CombinedStack/scene/UI/payload.
  Dumpling starts portions3/value15; accepted bite adds food60 without clamping, sets value0
  and decrements one portion. Body-fact weight determines capacity; reject at food>=capacity.
  Final bite uses authoritative immediate item destruction, then removes food association
  and index. If removal fails, already-reached food/value/portion mutations remain, with
  authority failure, no rollback or fallback, and no legal successful Save checkpoint.
- **H1 — bounded embedded format evolution:** NativeItemStateSnapshot current version1→2;
  captures encode item schema2 and deterministic typed food records. Decoder accepts exact
  old schema1 keys as empty food state, or exact schema2 keys including food records.
  Unknown versions/keys, duplicate/dangling/non-food records and missing required food state
  reject. A schema1 dumpling without food state fails, never receives fresh portions.
  Legal live dumpling states are only 3/15, 2/0, 1/0. Root schema2 and SOURCE_ENTRY_V1 stay
  unchanged; root schema1 remains unsupported. Pre-S4B semantic continuation is preserved;
  resaving necessarily changes embedded representation1→2, not byte-identical old JSON.
- **I — deferred authored weapon goods:** No dagger/sword-action substitution, chicken/hammer,
  bone variant or their persistence. These remain real deferred waiter offers, not placeholders.
- **J — Type B staged contact:** One deterministic scene-owned 店小二 commerce contact in
  existing Inn main floor, with only the dumpling offer. No NPC character/body/equipment,
  RNG greeting, combat/death, reset/respawn ledger, AI, birthday relay or dialogue system.
  Static contact reappears as scene content on Continue; no mutable waiter Save record.
  Full waiter parity is explicitly not claimed.

**K — sequencing only:** Owner-approved S3C supplies natural Work→Bank→Inn denomination
access. No starter coins, Vendor change-making or denomination normalization is authorized.
S3B's exact affordability/payment anomalies and source price15 remain unchanged.

Sources: `reference/es2/mudlib/d/snow/inn.c`, `d/snow/npc/waiter.c`,
`obj/example/dumpling.c`, `cmds/std/buy.c`, `feature/vendor.c`, `feature/finance.c`,
`feature/food.c`, `feature/move.c`, `feature/clean_up.c`, `std/item.c`.
These are owner-selected boundaries, not a general consumables/commerce authorization.

## Currency exchange / payment core (S3B only)

**OWNER APPROVED — S3B.** The following A–H decisions are locked by the owner's S3B instruction,
not proposals. S3A is OWNER APPROVED / CLOSED. These decisions do not authorize Bank world/UI,
Vendor purchasing or a general economy framework.

- **A — Type A:** Preserve executable `can_afford()` presence checks, strict `<` comparisons and
  distinct 0/1/2 meanings, including false rejections and false-positive1. Coin100 paying100 is2;
  silver1 paying100 and gold1 paying10000 are1; gold1+silver1 paying9900 is1 although payment fails.
- **B — source order / typed errors:** Payment processes gold → silver → coin. Preserve mutations
  completed before a later error; return a typed failure at that stage. No rollback, refund,
  auto-change, new denomination minting or seller credit. Results expose completed mutations.
- **C — Bank-only Type B:** New target allocation and authored amount1 creation precede its
  one-unit-weight transfer attempt. On ordinary failed delivery, establish the converted target
  amount, debit source in source order, then immediately destroy the parentless target through
  ItemLifecycle. Forget index state only after authoritative removal. Keep consumed sequence;
  no refund/source restoration/drop/persistent orphan/timer/retry. Cleanup failure is an authority
  failure with no fallback. This is separately approved for Bank, not inherited from S2 or applicable
  to Vendor. Exact MudOS cleanup timing is deliberately not preserved.
- **D — Type A:** Existing target growth has no transfer/capacity admission. New targets move at
  amount1 before full growth and before source debit. No final/net/gross weight preflight or
  post-growth veto; over-cap results and strict-cap equality are retained.
- **E — Type A:** Payment and Bank are ordered, non-atomic operations. No generic transaction,
  compensation engine or rollback snapshot. Transactional native Save reconstruction is unrelated.
- **F — Type B:** Finance selects at most one stack per denomination from direct Player inventory
  only. No ground, NPC, bag/recursive or world fallback. Duplicate direct stacks use ascending
  stable-instance-ID selection without summing or merging. Presence remains distinct from amount0.
  Bank retains its source direct-only scope. Removing finance's ground-money fallback is explicit.
- **G — S3B-only Type B:** At each full-consumption point, complete denomination arithmetic,
  invoke existing lifecycle immediately and forget the index only after success before continuing.
  No stale-positive one-second window, timer or pending-destruction save state. Stop on lifecycle
  failure, retaining earlier mutations, without fallback deletion. Global Combined semantics and
  the existing item-schema1 omission remain unchanged outside this composition.
- **H — bounded Type B representation:** Only canonical coin(value1/weight1/unit文), shared
  silver(100/37/两), gold(10000/37/两). Exact source-path stack compatibility; no duplicate silver.
  Same-type exchange retains temporary target growth then source subtraction, not a shortcut.
  Reject unsupported denominations/aliases/custom per-instance values explicitly; use checked
  arithmetic, never overflow/clamp to success. Genuine thousand-cash content remains deferred.

**I — boundary, not a Vendor failure decision:** Vendor fulfillment remains deferred. S2, Bank
cleanup and payment decisions must not be generalized to future goods delivery or other commerce.

Sources: `reference/es2/mudlib/feature/finance.c`, `cmds/std/buy.c`, `feature/vendor.c`,
`std/room/bank.c`, `d/snow/bank.c`, `obj/money/{coin,silver,gold,thousand-cash}.c`,
`std/money.c`, `std/item/combined.c`, `feature/move.c`, `feature/clean_up.c`.
Reviewed archaeology: [S3A contract](PHASE_SNOW_TOWN_CORE_HUB_CURRENCY_EXCHANGE_PAYMENT_CONTRACT.md).

## Snow Workplace undeliverable reward cleanup (S2 only)

**Decision (owner-approved):** When the source work reward is created but cannot be moved to
Player because of capacity, Native preserves the already-applied sen30 then gin30 costs and
consumed SessionItemIdAllocator sequence, then immediately destroys the undelivered reward
through the existing ItemLifecycle authority. Its derived index snapshot is removed only after
authoritative destruction. Native does not refund the work cost, drop the reward, persist the
orphan or introduce a cleanup timer.

**Compatibility impact:** `d/snow/workplace.c` ignores `silver->move(me)` failure; source leaves
a transient ownerless object for later MudOS/driver cleanup (`feature/move.c`, `feature/clean_up.c`).
Immediate deterministic cleanup replaces only that infrastructure lifetime, not eligibility,
resource order, reward amount, inventory outcome or allocator consumption. Exact cleanup-timing
parity is not claimed. Cleanup failure is an authority error with no alternate destruction or
persistent-orphan fallback. This decision applies only to the audited Snow Workplace path; it is
not a general policy for future failed transfers.

### Native Character Entry

**Decision (owner-authorized NGE5B):** Native single-player New Game collects only display name
and an explicit legacy male/female gender selection. MUD account ID/password/email and account
security are not migrated. Name preserves the source meaning of 1–6 Chinese/Han characters,
counted as Unicode code points rather than old-encoding bytes. Invalid input is rejected without
renaming or trimming. Internal stable CharacterId and save keys remain separate from display name.

**Source / impact:** `reference/es2/mudlib/adm/daemons/logind.c::check_legal_name` (called by `get_name`) expresses 1–6 Chinese
characters through 2–12 bytes. The native validator uses Unicode Han membership and does not
recreate multiplayer account or banned-name infrastructure. Birth stats, explicit-save policy and
existing gender-dependent rules are unchanged; no other character creation choices are added.

## Pre-Cutover Development Save Compatibility

**Decision (owner-approved NGE5A1):** Development saves produced before the NGE5B public source
New Game cutover carry no compatibility promise. The project has not publicly released and has
no real-player save compatibility obligation. Schema1 is unsupported: no reader, migration,
upgrade, missing-field interpretation or guaranteed restoration is retained.

Current schema2 + `LEGACY_OLDPINE_V1` remains only as the pre-cutover technical New Game test
profile; it is not a historical-save compatibility contract and has no long-term stability
promise. It may be removed at NGE5B unless the owner establishes a new reason to retain it.
Schema2 + `SOURCE_ENTRY_V1` is the forward save baseline.

Unsupported files are rejected, not automatically deleted, rewritten or archived. Existing
New Game confirmation, explicit Save, primary/tmp/bak transactions, recovery and Session rollback
remain. No second slot or migration UI. NGE5A0 independent body authority and exact schema2
continuation are unchanged. This supersedes old-save A and only the v1 interpretation portion of
the body decision below; it does not authorize NGE5B or public New Game cutover.

## Player Body Facts and Native Continue

**Decision (owner-approved NGE5A0):** Player own body weight and maximum encumbrance are independent
typed runtime facts. Ordinary strength growth, including registered unarmed improvement, does not
refresh either value. Carry and death use those stored facts. Fresh Human initialization reuses the
existing source formulas once. NPC body authority is not merged with Player authority.

**Native continuation:** Future schema2 explicitly saves both facts and cold Continue restores them
exactly. Native Save/Continue does not emulate LPC full-login body reconstruction. Only a future
explicit source-backed body rebuild/transformation event may re-derive established facts.

**Legacy v1 interpretation — SUPERSEDED by NGE5A1 (historical record):** Existing saved maximum_encumbrance is authoritative even when it differs
from current strength*5000. v1 has no Player body_weight: derive that missing field once from saved
current strength, then retain it as runtime authority. Until schema2 exists, v1 capture fails closed
if runtime body weight differs from human_weight(current strength); it cannot silently lose that fact.

**Reason / compatibility impact:** In the same LPC body, unarmed's str+=2 does not invoke setup;
Human weight and chard capacity initialize only when zero, and corpse copies existing facts.
On a full new-body login, static move fields begin at zero and setup may derive them again from
saved strength. Native exact continuation deliberately does not reproduce that login-induced change.
This is a native save-continuation compatibility substitution plus a v1 missing-field interpretation,
not a new growth formula or a legacy world/profile upgrade.

Sources: `reference/es2/mudlib/daemon/skill/unarmed.c`, `feature/skill.c`, `feature/dbase.c`,
`feature/move.c`, `adm/daemons/race/human.c`, `adm/daemons/chard.c`, `adm/daemons/logind.c`,
`obj/user.c`, `std/char.c`, `feature/save.c`.

## New Player Delayed Gift Randomization

**Decision (NGE1 owner-approved B):** Fresh native Human Player starts at age14 with all eight
base attributes30. Do not implement `gift_tag`, a pending gift allocation, a gift RNG stream, or
the delayed age15 login overwrite. This is a **compatibility substitution**, not a claim of exact
legacy execution. Other authorized gameplay attribute progression remains allowed.

**Legacy:** `adm/daemons/logind.c::init_new_player` sets attributes30 and gift_tag; the later full
`enter_world` with age>=15 overwrites them with `10 + random(21)`. `obj/user.c::update_age`
establishes age14 initially. Future native age/mud_age progression MUST NOT automatically reintroduce
this overwrite; a fresh source analysis and owner decision are required first.

## Fresh Food / Water Initialization

**Decision (NGE1 owner-approved B):** Only fresh NEW_GAME birth establishes the body, derives food
and water capacity, then initializes them once to capacity: at weight80000, **400/400**.
This is a **legacy initialization-order compatibility correction**.

**Legacy execution:** `adm/daemons/logind.c` queries capacities before body setup;
`feature/move.c` initially has weight0 and `feature/damage.c` divides weight by200, producing
**0/0**, not400/400. `adm/daemons/race/human.c` later establishes body weight.
Continue, Restore, map transition, respawn/revive, load-failure recovery, returning from Old Pine,
opening menus and general recovery MUST NOT invoke this birth refill. No recovery formula changes.

## Active Semi-Auto V1 Flee is same-position disengagement

**Decision:** The owner authorizes queued, busy-blocked Flee for LETHAL/SPAR,
deterministically successful when execution validation passes. It consumes no
resource or RNG and returns control at the unchanged physical position. Included
opponent and lethal relations are reconciled; V1 retains no cross-Encounter
pursuit/vendetta. No teleport, reward, healing, corpse or timed immunity is added.

**Reason:** `cmds/std/go.c::do_flee` randomizes a room exit, not a general escape
success roll. Continuous native world has no equivalent in-Encounter exit list.
Source `feature/attack.c::remove_all_enemy` leaves killer markers, but persistent
pursuit and killer Save serialization are not represented by this V1 boundary.

**Compatibility impact:** This explicitly differs from legacy killer preservation
and room-exit movement; it does not change ordinary portal/handoff policy. Physical
leave/reenter controls subsequent aggression. Implementation and acceptance
progress are recorded in CXR9; this approved decision is not a validation PASS.

## Native saves require a restart-stable gameplay boundary

(Superseded in part: unconscious and dead players block Save since「Player unconsciousness and death
follow ES2」, 2026-09-30; busy and interrupt are saved, not blocking, since「Busy is saved, not waited
on」, 2026-10-17.)

**Decision:** A native Save is accepted only when every represented character and Old Pine runtime
authority is restart-stable. Ordinary opponents, lethal intent, busy/interrupt state, guarding, pending
aggression, active or committed-partial handoff, pending Cave exit, incomplete death lifecycle, active
combat cadence, and unrepresented temporary attribute modifiers block capture. Stable ACTIVE,
fully committed UNCONSCIOUS, and coherent completed DEAD states remain eligible; non-authoritative UI
state and the schema-v1 combined-stack delayed-destruction omission do not block Save.

**Reason:** These facts either describe an ordered transition that cannot be resumed by the closed save
schema or depend on runtime opportunities intentionally rebuilt fresh after Load. Persisting them merely
to allow Save would turn transient scheduling into durable gameplay state. Capturing after the current
event/frame preserves synchronous mutation ordering without adding a heartbeat or transaction runtime.

**Compatibility impact:** Native Save may reject states in which the LPC runtime could serialize user
fields. It never clears combat/busy state to make a save possible. Once eligible, the complete represented
world is captured all-or-nothing through the native repository; Load reconstructs fresh transient combat,
Area, UI, and cadence state. This is a native process-restart safety policy, not an LPC quit emulation.

## Cross-map ordinary exits use location availability reconciliation

**Decision:** Native cross-map ordinary exits commit the destination `WorldLocationState` and then run a
typed combat-opponent availability reconciliation. They do not reproduce `cmds/std/go.c`'s immediate
`remove_all_enemy()` inside portal or map-handoff code. Ordinary opponent membership can be removed as
out-of-location while independent lethal-target markers continue to follow the closed relationship rules.

**Reason:** Godot physical/world movement is not routed through the LPC directional-command runtime, and
the existing world slice already translates separation into current-location availability facts. Keeping
that boundary avoids hiding command-specific relationship mutation in a generic portal callback and also
allows a busy player to be reconciled without executing an attack or decrementing busy.

**Compatibility impact:** A cross-map ordinary exit such as the future Passage-to-Waterfall transition
cleans ordinary opponents through the explicit post-commit availability opportunity rather than at the
exact `go.c` move-return statement. Lethal intent is not erased merely by handoff. Sources:
`reference/es2/mudlib/cmds/std/go.c`, `game/core/combat/relationship/combat_opponent_selection_service.gd`.

## Combat invalid random bounds become ordered typed failures

(Superseded by「MudOS random(n <= 0) is 0, everywhere」, 2026-10-01: every non-positive `random()`
bound rolls 0 and draws nothing.)

**Decision:** Phase 5B2A returns a typed legacy-invalid result when ordinary attack resolution reaches
`random()` with a non-positive apply-damage, defense-factor, or wound-damage bound. The failure occurs at
the exact source position. Mutations already completed before that position are retained; in particular,
kee damage is not rolled back when the later wound `random(D)` bound is invalid.

Phase 5B2B2 extends the same decision to post-attack progression. A reached health-ratio expression
whose `max_gin` is zero becomes a typed division failure at that exact branch; a reached non-positive
progression `random()` bound or out-of-contract injected draw becomes a typed ordered failure. No
maximum is invented and no prevalidation moves the failure ahead of resolver mutations. Consequently,
late HIT failures preserve prior force, damage/wound, combat-exp, potential, and skill mutations exactly
as far as source order had completed. Sources: `reference/es2/mudlib/adm/daemons/combatd.c`,
`feature/skill.c`.

The Phase 5B2B2 formal audit extends this to the later `report_status(victim, wounded)` expression.
When a positive-damage HIT reaches `selected_kee * 100 / max_kee` with `max_kee == 0`, native code
returns a typed failure at that position, after progression and before busy interruption. Earlier mutations
remain, while busy remains untouched. This avoids both a Godot crash and an invented divisor. Source:
`reference/es2/mudlib/adm/daemons/combatd.c:149-160,390-432`.

Phase 5B3B1 extends the same ordered policy to reached `fight()` perception and courage calls.
`100 + effective perception <= 0` fails only when the target is invisible; visible targets never validate
that bound. `raw cps * 3 <= 0` fails only after perception has passed and only when the victim is living
and not busy; QUICK never validates it. A prior perception draw remains consumed when the later courage
bound fails. Guarding is set before the fixed `random(5)` presentation draw, so an invalid guard draw
retains that mutation. Source: `reference/es2/mudlib/adm/daemons/combatd.c::fight()`.

Phase 5B3B2A extends the policy to the terminal guarding-riposte call
`random(my["cps"])`. The exact REGULAR/negative-or-zero-damage/live-guard predicate is evaluated first;
the victim's guarding flag is then cleared, and only then is the original attacker's current raw cps read
as the random bound. A non-positive bound or out-of-range injected draw returns a typed failure while the
guard clear and all earlier attack/relationship mutations remain committed. No minimum cps is introduced.
Sources: `reference/es2/mudlib/adm/daemons/combatd.c::do_attack()`,
`reference/es2/mudlib/feature/dbase.c::query_entire_dbase()`.

**Reason:** The mudlib does not prove the deployed MudOS/FluffOS behavior for `random(0)` or a negative
bound. Clamping to one, prevalidating all later bounds, or allowing a defense loop to hang would each alter
observable source ordering. A typed result keeps the Godot domain safe while preserving all preceding
integer calculations, random consumption, loop iterations, and resource transitions.

**Compatibility impact:** Valid positive-bound attacks are unchanged. Invalid legacy states return a
diagnosable failure instead of a driver-specific error or hang. A wound-bound failure is explicitly a
partial mutation, not an atomic attack rollback. Sources:
`reference/es2/mudlib/adm/daemons/combatd.c:312-380`,
`reference/es2/mudlib/feature/damage.c:12-68`.

## Condition update order

**Decision:** A single native condition update uses a snapshot of active condition IDs sorted by stable ID string in ascending order.

**Reason:** `feature/condition.c` obtains `keys(conditions)` from an LPC mapping and iterates that array backwards. The mudlib does not define mapping key order as gameplay data, yet multiple conditions can mutate the same resource and therefore need a deterministic native order. Stable ID order is independent of insertion order, hash layout, and save/restore behavior.

**Compatibility impact:** Multiple simultaneous conditions may resolve in a different order from a particular MudOS/FluffOS process. Individual condition formulas, flag aggregation, snapshot behavior, and post-update removal semantics remain unchanged. Source: `reference/es2/mudlib/feature/condition.c`.

## Cultivation percentage division by zero

**Decision:** If a Phase 3B1 health-percentage check reaches a primary resource whose maximum is zero, return a typed `LEGACY_ZERO_MAXIMUM_*_DIVISOR` failure at that exact validation position, without mutation.

**Reason:** `exercise.c`, `meditate.c`, and `respirate.c` calculate `current * 100 / maximum` without guarding zero. The LPC command therefore aborts with a driver division error rather than producing a gameplay failure string. A pure domain transition must not crash the application, and treating zero as merely “below 70%” would hide the source defect and alter validation evidence.

**Compatibility impact:** The native call returns a diagnosable failure instead of throwing a MudOS/FluffOS runtime error. It preserves validation order and the absence of mutation. No positive minimum is imposed on internal-resource current or maximum values. Sources: `reference/es2/mudlib/cmds/std/exercise.c`, `meditate.c`, `respirate.c`.

## Self-learning with non-positive intelligence

**Decision:** Phase 3B2 rejects `selflearn` with a typed `LEGACY_NON_POSITIVE_INTELLIGENCE` failure when base `int` is zero or negative, without mutation.

**Reason:** `selflearn.c` computes `300 / int` without a zero guard. Zero aborts immediately. Negative intelligence produces a negative gin cost and later passes it to `receive_damage()`, which raises an error for negative damage; the LPC path may already have modified potential/skill progress before that error. A native domain transition must not crash or leave a partially applied transaction.

**Compatibility impact:** Normal positive-intelligence behavior is unchanged. Invalid legacy states receive a deterministic typed failure instead of a driver error or partial mutation. This is not a new gameplay minimum for valid characters. Sources: `reference/es2/mudlib/cmds/std/selflearn.c`, `feature/damage.c`.

## Learn legacy runtime errors preserve completed mutations

**Decision:** Phase 3C1 converts division-by-zero, invalid `random()` input, and negative `receive_damage()` points into typed `LearnResult` legacy errors at the exact LPC execution position. Unlike the earlier Selflearn substitution, Learn does not roll back mutations already completed before that point.

**Reason:** `learn.c` has observable mutation-sensitive errors: the raw-zero entry is later than the two intelligence divisions; `learned_points` increments before `random()`; an NPC teacher with a negative gin cost can reach `improve_skill()` and `skill_improved()` before the final negative gin damage errors. Crashing the Godot application is unacceptable, while validating everything before mutation would also change behavior.

**Compatibility impact:** Ordinary Learn behavior is unchanged. Invalid legacy states return a diagnosable result instead of a driver exception, but retain only the raw skill, teacher sen, potential, learned progress, level, or authored effect mutations which LPC had already performed. No minimum intelligence or silent clamp is introduced. Sources: `reference/es2/mudlib/cmds/std/learn.c`, `feature/damage.c`, `feature/skill.c`.

## Learn teacher identity keeps one narrow legacy name field

**Decision:** Native relationships use a stable `TeacherId` (`StringName`) as primary identity, while `ApprenticeshipState` also retains `legacy_master_name` solely for the F_MASTER direct-apprentice predicate.

**Reason:** `learn.c::is_appr_of()` compares master ID plus generation, whereas `feature/apprentice.c::is_apprentice_of()` compares master ID plus persisted master display name and is called by `std/char/master.c::prevent_learn()`. Replacing both with one modern predicate would silently erase a real source discrepancy.

**Compatibility impact:** New content does not use display names as identity, but migrated saves can reproduce the second legacy comparison. The two predicates remain intentionally separate. Sources: `reference/es2/mudlib/cmds/std/learn.c`, `feature/apprentice.c`, `std/char/master.c`.

## Learn runtime facts and randomness are explicit projections

**Decision:** Inventory-based spouse discovery, `present()`/`living()`/`userp()` checks, and `random()` are replaced by typed `TeachingContext` facts plus a deterministic roll supplied by the caller.

**Reason:** These operations belong to LPC inventory/world/runtime infrastructure. The gameplay semantics needed by Learn are only whether this teacher is the spouse, available, a character, awake, and player-style for sen payment, plus a roll satisfying the MudOS range contract.

**Compatibility impact:** Learn retains the original validation order, strict thresholds, player/NPC sen distinction, and random upper-bound formula. The caller is responsible for producing world/relationship facts and a roll `0 <= roll < upper`; Phase 3C1 does not implement their runtime sources. Source: `reference/es2/mudlib/cmds/std/learn.c`.

## Missing Learn policies are explicit

**Decision:** A teacher with no `prevent_learn()` policy has `NO_ADDITIONAL_POLICY` and continues. If relationship fallback requires recognition, a teacher with no recognition policy returns `RECOGNITION_POLICY_ABSENT`; an authored recognition policy whose known dependency is not migrated returns `RECOGNITION_DEPENDENCY_UNAVAILABLE`. An unimplemented authored `valid_learn()` similarly returns `SKILL_LEARN_DEPENDENCY_UNAVAILABLE`.

**Reason:** The mudlib dynamically calls methods which many objects do not define, and does not document the deployed driver's missing-lfun behavior. Prevention is a negative veto and can have an explicit no-veto default; recognition is a positive authorization and cannot be manufactured. Treating every unknown skill hook as the permissive `std/skill.c` default would also erase known authored overrides.

**Compatibility impact:** Teachers and skills whose rules are understood receive explicit policies. “No authored method,” “authored allow,” “authored reject,” and “known dependency unavailable” remain distinguishable. Driver-dependent or not-yet-migrated paths stop with a typed result instead of crashing, silently allowing, or masquerading as a normal authored rejection. Sources: `reference/es2/mudlib/cmds/std/learn.c`, `std/char/master.c`, `std/skill.c`, and the representative teacher/skill daemons listed in `PHASE_3C1_LEARN_CORE.md`.

## Hand-slot state has one native authority

**Decision:** `EquipmentState` exclusively owns the native primary and secondary weapon slots. `EquippedWeaponRef` uses a stable runtime instance ID plus an immutable scalar definition snapshot; the migration does not reproduce the LPC combination of character `query_temp()` object references and a separate mutable item-side `equipped` marker.

**Reason:** The duplicated LPC representation is tied to object environments and dbase/runtime APIs. Recreating both halves would add a compatibility layer and permit divergence without adding gameplay meaning. Stable identity and one authoritative typed state preserve all confirmed slot selection, duplicate, wield-order, and unwield behavior.

**Compatibility impact:** Phase 4A1 transition outcomes match `feature/equip.c`, including secondary-only and two-handed quirks. Later Inventory must enforce cross-owner instance identity and translate move/transfer into an explicit unwield transition; it must not introduce a second authoritative equipped flag. Sources: `reference/es2/mudlib/feature/equip.c`, `cmds/std/wield.c`, `cmds/std/unwield.c`, `feature/move.c`, `std/item.c`.

## Native item persistence preserves the complete represented domain state

**Decision:** Native item schema version 1 snapshots every represented live `ItemInstance`, its exact `InventoryState` own weight and direct parent, `CombinedStackState.amount`, and per-character Equipment/Armor instance references. Restore validates the complete snapshot and reconstructs fresh aggregates all-or-nothing. It does not reproduce LPC's autoload-only inventory loss or replay gameplay transfer/wield/wear operations.

**Reason:** Legacy `F_SAVE` serializes user fields but not ordinary inventory objects. `feature/autoload.c` separately recreates only selected direct inventory objects, and generic hand/armor slot state is not restored. The native domains already own stable instance identity, recursive containment, stack amount, and equipment references; discarding them would make native saves incomplete and would reproduce a runtime limitation rather than gameplay semantics.

**Compatibility impact:** Native saves retain ordinary and nested items plus generic hand/armor state that LPC logout did not retain. Immutable weapon, armor, and stack facts are rebuilt from current definition projections, while saved current own weight is preserved exactly. Legacy autoload is handled by the separate Phase 4B5D one-way importer. Sources: `reference/es2/mudlib/feature/autoload.c`, `feature/save.c`, `obj/user.c`, `cmds/usr/quit.c`, `std/money.c`, `obj/bandage.c`.

## Schema v1 omits pending combined-stack destruction intents

**Decision:** Native item schema version 1 does not persist a pending one-second combined-stack destruction intent. It snapshots only the amount and own weight observable at capture time and restores the stack as an ordinary live instance without synthesizing a new intent.

**Reason:** `std/item/combined.c::set_amount(0)` leaves the old amount and weight observable and schedules destruction through a non-durable `call_out`. Legacy money autoload therefore saves the old visible amount during that window, and the pending callout does not survive reload. Runtime scheduling is deliberately outside Phase 4B5A.

**Compatibility impact:** A pending positive stack can survive reload with its old positive amount and weight; a raw-zero stack restores with amount zero and its exact saved own weight, without automatically scheduling destruction. A future durable scheduler policy would require a new explicit schema decision. Sources: `reference/es2/mudlib/std/item/combined.c`, `std/money.c`, `feature/autoload.c`.

## Legacy autoload import builds validated data instead of replaying login

**Decision:** Phase 4B5D translates legacy autoload strings in original order into an immutable schema-v1 snapshot candidate and typed evidence, then stops. It does not execute `new()`, `move()`, or `autoload()`, does not replay capacity/merge/callback failures, and does not mutate live aggregates. Source-proven bandage wear is represented in candidate Armor data after direct placement; unsupported entries leave the batch explicitly incomplete.

**Reason:** Executing LPC paths would require a compatibility runtime and could leave partial live mutations before a later failure. Phase 4B5A already defines trusted structural reconstruction as the native persistence boundary. A pure importer can preserve traceable data and sequential authored semantics while allowing application policy to reject or inspect incomplete migrations before explicitly restoring anything.

**Compatibility impact:** Imported direct items can reconstruct even where legacy `move(user)` capacity would have failed, and supported entries remain inspectable without reproducing a prior callback abort. No live state changes until a caller separately accepts the candidate and invokes native restore. Sources: `reference/es2/mudlib/feature/autoload.c`, `obj/bandage.c`, `std/item/combined.c`.

## Legacy zero-money import keeps clone state plus a transient intent

**Decision:** Importing a source-produced money parameter `"0"` creates a candidate stack with amount `1` and one unit of the concrete currency's base weight, then emits a typed one-second destruction intent outside schema v1. The importer does not start a timer.

**Reason:** Each concrete money clone executes `set_amount(1)` in `create()`. Its later `autoload("0")` calls `set_amount(0)`, which schedules destruction but does not assign zero or update weight. Saving raw zero in the candidate would invent a state the executable restore path never exposed.

**Compatibility impact:** If an application accepts this unusual candidate but does not later execute the external intent, the one-unit stack remains live. Schema v1 itself is unchanged and still does not durably persist pending destruction. Sources: `reference/es2/mudlib/std/money.c`, `std/item/combined.c`, `obj/money/coin.c`, `gold.c`, `silver.c`, `thousand-cash.c`.

## Item destruction stops on an unexpected native equipment-detach failure

**Decision:** Phase 4B5B prevalidates structure, then attempts exact hand cleanup followed by exact Armor cleanup. If a referenced instance unexpectedly cannot be removed from one of those native authorities, lifecycle returns a typed failure and does not remove the item's Inventory/stack registration. Any earlier successful hand cleanup is not rolled back and is reported in the result.

**Reason:** `feature/move.c::remove()` logs an `unequip()` failure and continues to driver destruction. Reproducing that continuation in the native split-authority model would remove the item while leaving an impossible authoritative Equipment/Armor reference. Current typed transitions normally succeed whenever their identity predicate was true, so this is an invariant-defense path rather than a new gameplay rejection.

**Compatibility impact:** Structurally valid current states preserve LPC's ordinary cleanup-then-destruction behavior. A corrupted or future custom aggregate that reports an item equipped but refuses exact detach keeps the item live instead of reproducing a dangling-reference defect. The result honestly exposes any cleanup already completed; no invented rollback occurs. A composed multi-sibling stack merge commits each successfully destroyed sibling's positive quantity before attempting the next lifecycle transition, so a later injected detach failure cannot erase an earlier sibling's quantity; normal successful final totals and survivor identity are unchanged. Direct-character lifecycle context must contain both authoritative aggregates—explicit empty states mean empty, while `null` means the authority was omitted and is rejected. Sources: `reference/es2/mudlib/feature/move.c`, `feature/equip.c`, `std/item/combined.c`.

## Death and corpse inventory ordering uses stable instance IDs

**Decision:** Phase 4B5C snapshots a victim's direct item IDs in ascending stable-ID order, evaluates `owner_is_killed` policies in that order, and processes survivors in descending snapshot order to preserve `chard.c`'s reverse loop. Corpse final scatter uses ascending direct-child order.

**Reason:** `adm/daemons/chard.c` snapshots `all_inventory(victim)`, invokes hooks over that array, then walks survivors backwards; `obj/corpse.c` walks its `all_inventory()` array forwards. The mudlib does not define object-chain allocation order as authored gameplay data, but policy destruction and ignored transfer failures make order observably affect partial results. `InventoryState.direct_children()` already supplies deterministic stable-ID snapshots, so the death domain must state how legacy forward/reverse traversal maps to that native order.

**Compatibility impact:** A particular MudOS process may have evaluated or moved items in a different object-chain order. Direct-only membership, policy-before-transfer ordering, reverse survivor concept, per-item partial mutations, final forward scatter concept, and all item formulas remain unchanged. Sources: `reference/es2/mudlib/adm/daemons/chard.c`, `obj/corpse.c`.

## Incomplete synchronous death hooks cannot restart the whole death flow

**Decision:** A death-item hook that requires unavailable native runtime work, or a destruction failure after observable cleanup, returns a typed incomplete result with `DO_NOT_RESTART_FROM_BEGINNING`. Phase 4B5C deliberately provides no generic continuation token or scheduler.

**Reason:** `owner_is_killed()` runs synchronously over one direct-inventory snapshot before survivor movement. By the time a native boundary is encountered, a normal death may already have created/placed a corpse and earlier policies may already have destroyed items or detached equipment. Re-running the complete operation would duplicate or reorder those mutations.

**Compatibility impact:** Future NPC/runtime orchestration must continue from the recorded boundary using current authoritative aggregates; it must not call the whole Phase 4B5C process again. This preserves the LPC ordering without introducing callback dispatch or a runtime workflow engine. Sources: `reference/es2/mudlib/adm/daemons/chard.c`, `daemon/class/scholar/windspring.c`, `feature/move.c`.

## Combat lethal relationships use stable character identity

**Decision:** Native combat opponent, lethal-target, and last-opponent identities use stable `CharacterId` values; guarding remains a targetless boolean. Legacy public `id()` strings remain migration metadata and are not used as the authoritative lethal relationship key.

**Reason:** `feature/attack.c` stores live enemy objects but stores `killer` entries as public ID strings. Different live entities can share a public ID, so reproducing that mixed identity model would let one entity's lethal marker accidentally match another entity and would conflict with the stable identity already used by native relationship state.

**Compatibility impact:** Simultaneous legacy entities with the same public ID no longer share or collide on a lethal marker. Cleanup, selection, friendly-stop eligibility, and all local relation mutations remain source-ordered; only the ambiguous public-ID collision is not reproduced. Sources: `reference/es2/mudlib/feature/attack.c`, `reference/es2/mudlib/adm/daemons/combatd.c`.

## Corpse loot requires a near-corpse spatial range

**Decision:** Phase 8B1 replaces LPC same-room corpse reachability with a map-local circular `LootInteractionRange Area2D` of radius 96 Godot pixels, centered on each runtime corpse view. Corpse selection and Inspect may occur by clicking, but Open Loot and every Take re-evaluate the player's current physical presence in that range. The range fact belongs only to the Old Pine scene/world interaction adapter; Inventory, Corpse, stack, and item Core receive no position or distance rule.

**Reason:** `cmds/std/get.c` and `present(arg, environment(me))` make source reachability depend on sharing one discrete room. The native map is continuous and the current player/corpse bodies are roughly 36 pixels wide, so a 96-pixel circle permits deliberate nearby interaction without extending across the 150-pixel spacing between authored bandit spawn centers. `Area2D` supplies the physical representation and enter/exit notifications; execution also checks current corpse/player positions so a corpse created while already overlapping the player cannot miss its initial range fact.

**Compatibility impact:** A player on the same continuous Godot map but farther than 96 pixels from the corpse cannot Open Loot or Take until approaching it. Once admitted, all item ownership, capacity, corpse-worn, stack merge, and fighting/busy results remain governed by the migrated source rules. Source: `reference/es2/mudlib/cmds/std/get.c`; native scene scale: `game/scenes/world/oldpine/oldpine_outdoor.tscn`.

## Snow Martial Progression II — owner-locked P2 boundary

P1 at `c44658ef0e9b557b7a002f4d79ca7bef0fd6b4bd` is OWNER APPROVED / CLOSED.
P2 is authorized on `phase/snow-martial-progression-liuh-ken` only.
The [approved source analysis](PHASE_SNOW_MARTIAL_PROGRESSION_II_SOURCE_ANALYSIS.md)
remains planning authority; this section records the subsequent owner decisions.

| Decision | Locked contract |
| --- | --- |
| D-SMP2-01 | Natural combat_exp >=6, basic unarmed raw >=4, liuh-ken raw >=5, enabled for unarmed. Product acceptance finish, not a source unlock. No automatic reduction. |
| D-SMP2-02 | Explicit Enable/Disable only at valid physical Liu contact: ACTIVE, in range, not paused/fighting/busy. Approved Type B availability substitution, not a source enable restriction. |
| D-SMP2-03 | All four source actions: 古松挂月, 傲雪冬梅, 孤崖听涛, 荒山虎吟; no level unlock. |
| D-SMP2-04 | Full authored text, using committed attacker/victim/limb facts; presentation draws no RNG. |
| D-SMP2-05 | Source dodge/parry metadata is evidence only. No effect on AP/DP/PP, rates, damage or temporary modifiers; CombatActionDefinition and CombatMath do not gain these fields. |
| D-SMP2-06 | Exact reviewed liuh-ken only: known no authored hit effect. Narrow Type B classification; unknown mapped skills remain unavailable. No generic missing-lfun or hook framework. |
| D-SMP2-07 | Reuse generic skill/progression/relation/equipment and three-stream RNG persistence. Root schema2, item schema3, SOURCE_ENTRY_V1 unchanged. Missing required durable state requires owner review. |
| D-SMP2-08 | Attempt full natural EXP6 route on immutable pushed implementation, then mapped combat and full-process Save/cold Continue. No grants, injected XP/stats, favorable production RNG, teleport, enemy/damage/recovery rebalance. If impractical, stop and report the actual acceptance blocker. |

Source-exact Learn ordering, effective skill and primary/secondary weapon distinctions remain Type A.
Select exactly once per attack from the validated current action set, retain all live authority checks,
and compose that selected action into the existing resolver. Each genuine reverse attack reprojects
post-forward live state and draws independently. No singleton-draw optimization or presentation reroll.
Shared responsive/input/layout regressions are required; physical Android/iOS qualification is deferred
to the later owner-authorized Final Audit. No PR, merge, automatic Final Audit, P3 or Migration Tooling
expansion is authorized. All other arts, practice/study, force/techniques, full school/faction systems,
Phase5B4, Lake/serpent and Native generation remain deferred. Type C = 0.

## Generalized Player display names

**Decision (Type B, owner-authorized P2R2):** Replace the historical Chinese-only
display-name restriction with bounded, safe Unicode letter-based names across languages.
Default length is 1–24 code points; attached marks and explicit internal separators
are allowed. Preserve accepted display text exactly, without normalization. Semantic
Character ID remains independent. This is international single-player product compatibility,
not multiplayer uniqueness, account naming or moderation. Source:
[logind.c::check_legal_name](../../reference/es2/mudlib/adm/daemons/logind.c).
The [policy report](PHASE_NEW_GAME_GENERALIZED_NAME_POLICY.md) records rules,
configuration and verification. Birth, gameplay and Save schemas are unchanged.
