# NGE0 — Source-valid New Game Entry Compatibility Contract / Dependency Analysis

## EXECUTIVE RESULT

**NGE0 OWNER APPROVED；NGE1 foundation 已获授权；当前 New Game cutover 仍未授权。**
NGE1 owner 指令正式批准 gift B / food-water B / old-save A，已记录于
[DECISIONS](DECISIONS.md)。其余技术建议不是自动实施授权；下文 NGE0 source coverage 与
docs-only validation 保留为该分析提交的历史证据。NGE1 实现/验证见
[Player initialization](PHASE_NEW_GAME_ENTRY_PLAYER_INITIALIZATION.md)。

- Major branch：`phase/source-valid-new-game-entry`，从绿色 main
  `d9b9a7cde6553623cf06b76ff828fa4f8a13c0ab` 开始。
- S0 / [PR #14](https://github.com/Toxicccxz/eastern-stories-godot/pull/14)：
  **COMPLETE / FULLY INTEGRATED ON MAIN**；上述 merge 的
  [workflow 34531552148](https://github.com/Toxicccxz/eastern-stories-godot/actions/runs/34531552148)
  Godot Verify / Windows / Android / iOS 四项 PASS。
- 明确建议：**gift B（不移植延迟洗点）/ food-water B（body setup 后按容量初始化）/
  old saves A（原状态恢复，仅 New Game 改入口）**。前两项属于兼容替代，不冒称原版执行结果。
- 当前 Old Pine / exp600 / starting long sword 保持原样。本次只有本文和 STATUS / ROADMAP 变更。
- `WorldLocation` 已能表达 region + map + zone + position；实际 Session/restore 仍限定 Old Pine。
  未来需要窄的角色初始化和内容版本边界，不能只改 START_ROOM 或重写旧档。

以下 LPC 路径以 `reference/es2/mudlib/` 为根。依据为本次静态读源；没有运行 LPC server，
不将源码推导包装为原版实测，也不声称未来 Snow runtime 已通过验证。
S0 背景见 [source rebaseline](PHASE_START_OF_GAME_SOURCE_REBASELINE.md)，
现有存档权威见 [Native Save contract](../production/contracts/NATIVE_SAVE_LOAD_CONTRACT.md)。

## SOURCE FACTS LOCKED

这里锁定的是普通 fresh account 的首次同步 `enter_world()`，不是旧档恢复、reconnect 或后续 tick。

| 输入/状态 | 源码事实 | 核查位置 |
| --- | --- | --- |
| 起点 | `/d/snow/inn` 饮风客栈 | `include/login.h`；`logind.c::enter_world`；`d/snow/inn.c` |
| race/title/gender | 人类 / 普通百姓 / 输入男性或女性 | `chard.c::setup_char`；`logind::get_gender/init_new_player` |
| age | 14；不是 birthday 推导的真实年龄 | `obj/user.c::update_age/setup` |
| 八属性 | str/cps/int/cor/con/spi/per/kar 全30；gift_tag=1 | `logind::init_new_player` |
| progression | potential99；combat_exp、learned_points 缺失，查询有效0 | logind、`feature/dbase.c`、human、updated |
| gin/kee/sen | 各 current/effective/maximum = 100/100/100 | `race/human.c` age<=14；`chard::setup_char` |
| internal resources | force/max_force/mana/max_mana/atman/max_atman 有效0 | 初始化链无赋值；dbase缺失字段 |
| body/encumbrance | weight80000；maximum encumbrance150000 | human `40000+(str-10)*2000`；chard `str*5000` |
| food/water | 执行结果0/0；setup后容量400/400 | `feature/move.c`、`damage.c`、logind顺序 |
| 初始物品 | 一件布衣，weight3000，cloth槽，armor+1，hands empty | `obj/cloth.c`、`std/armor/cloth.c`、`feature/equip.c` |
| weapon/money/skills | 无开局武器、钱或初始技能 | logind、`feature/skill.c`、updated |

`std/armor/cloth.c` 的 dodge 扣减条件是 weight>3000，出生布衣不满足。不得附送当前技术长剑、
把 NPC 的经验搬给 Player，或用显式零等级技能记录代替原先尚未建立的 skills mapping。
布衣是 logind 在 setup/save 之后创建、move、wear（不检查后两者返回值）；正常新人体重和容量
允许它进入 inventory 并穿上。每次完整 login 都尝试发衣，不代表 native Continue 也应重复发衣。

## GIFT_TAG ANALYSIS

直接重读 [logind](../../reference/es2/mudlib/adm/daemons/logind.c)、
[user](../../reference/es2/mudlib/obj/user.c)、
[human](../../reference/es2/mudlib/adm/daemons/race/human.c)、
[char](../../reference/es2/mudlib/std/char.c)、
[save feature](../../reference/es2/mudlib/feature/save.c)、
[quit](../../reference/es2/mudlib/cmds/usr/quit.c)。

1. fresh `init_new_player` 显式写30，旁边保留注释 `/*10 + random(21)*/`，并设gift_tag1。
2. `user.setup` 先 `update_age`，再 `char.setup`、autoload恢复。
   `age = 14 + age_modify + mud_age / 86400`，整数除法；首次静态 last_age_set=0，
   本次计入的时间差为0。普通新账号 age_modify/mud_age 有效0，故age14。
3. `char.heart_beat` 的较慢更新段为 interactive Player 调用 update_age，但**不消费gift_tag**。
   mud_age是按这些调用累计的时间差；不能直接等同离线真实年龄或设计一套日历。
4. `enter_world` 在 setup 后先调用 **user.save → login.save**，然后才检查 tag 和 age>=15。
   fresh不触发。累计age达到15以后，须再经完整 enter_world 才触发。
5. 精确顺序：**str → cps → int → cor → con → spi → per → kar**，每项 `10+random(21)`，
   10..30包含两端，八次随机；最后删除gift_tag。使用 setup 后的新age作为判断，
   不要求恰好15（16岁且仍有tag也执行）。没有“只能降低初始属性”的比较；覆盖届时字段值。
6. `get_passwd` 找到已有body以及 `confirm_relogin` 接管连接，都走 `reconnect`；
   logind reconnect只接线、`user.reconnect`、updated，不调用 enter_world/setup/gift。
   silent enter_world 仍检查gift；silent只包围显示/入房段。
7. 已成功持久化tag删除后，后续完整登录不再随机。若randomization后尚未保存就丢失body/进程，
   之前的save仍含tag和旧属性，下次可能再次分配；**不是无条件永久只触发一次**。
8. 正常 quit先drop非autoload物品、保存/销毁link，再 `me.save()`、destruct；
   普通Player路径将新属性与tag删除持久化。`cmds/usr/save.c` 也可显式保存，
   仅valid_startroom时改下次登录点。不能把正常quit和异常断电混同。

额外顺序风险：human体重与chard负重在gift之前计算，gift后本次不重新setup；
static weight/max_encumb 不随F_SAVE持久化，下次新body setup会用保存后的str重算。
资源最大值依据age与内部资源maximum，不能说八属性随机后都需要立即重算生命上限。

意图证据有冲突：`doc/help/gift` 称天赋在人产生时选定、不再改变；logind有旧随机式注释及
“check if need allot gift”。这些支持“曾设计随机分配”，**不能证明提前到New Game就是当前执行语义**，
也不能推导这是已获批准的设计。帮助文档还含旧显示门槛，权威仍是可执行源码。

## GIFT_TAG OPTIONS

| 方案 | Source fidelity | Player experience | Save determinism / RNG ownership | 返工风险 |
| --- | --- | --- | --- | --- |
| A exact legacy | 最高，含age>=15、完整登录、顺序错位 | 玩了一段时间后属性突变；可能覆盖成长 | 需持久化age/mud_age/tag与专属随机流；明确native哪个事件等同完整登录；保留save-before-effect还会有重抽窗口 | 高：目前没有年龄时钟、登录事件或gift流；不能将每次Continue直接等同 |
| B 固定初始30、不移植gift延迟随机 | fresh忠实，后续行为显式替代 | 无隐藏洗点；数值透明 | 创建不消耗gift RNG，Continue不重复初始化；只保存当前属性 | 最低；仍需年龄事实统一及其持久化 |
| C New Game一次随机10..30 | 不忠实fresh30；只有旧注释/帮助支持意图解释 | 创建时即可知道差异，不会后期突然变化 | typed创建输入+独立可重放随机源；结果保存；不能偷用combat/NPC/world流 | 中：新UI/seed/失败重试约束；不必要的随机化扩张 |

**B — OWNER APPROVED（NGE1）**。这不是把所有属性永久锁30：已迁移技能升级/其他合法成长仍可修改属性，
只是不用gift_tag再次覆盖。年龄14为出生事实；本NGE不新增在线计龄/15岁自动成长系统，
必须明示该时间系统延期，不能暗示“照旧长到15岁但忘记实现callback”。若owner选A/C，须先重估切片。

## FOOD/WATER ANALYSIS

读源：[move](../../reference/es2/mudlib/feature/move.c)、
[damage](../../reference/es2/mudlib/feature/damage.c)、
[food](../../reference/es2/mudlib/feature/food.c)、
[liquid](../../reference/es2/mudlib/feature/liquid.c)、
[updated](../../reference/es2/mudlib/adm/daemons/updated.c)。

**SOURCE EXECUTION：** move的`static int weight=0`；user/char create不设体重；
init_new_player在setup前调用两个capacity函数，它们均为`query_weight()/200`，故写入0/0。
之后human才设`40000+(30-10)*2000=80000`，容量变400，食水没有再次赋值。
updated只迁移部分旧技能并校正gin/kee/sen，不补食水。user.reset只涉及potential/thief。

**LIKELY AUTHOR INTENT：** 使用max_capacity函数而非字面0是“想按容量补满”的直接线索；
但没有找到说明初始化先后顺序的修正注释或后续补满步骤。重查 `doc/help/start/newbie/gift`、
adm初始化/update函数、NPC基础类以及现存`feature/foodold.c/foodbak.c`：
帮助只强调食饮和购买，且对恢复的说明与damage执行顺序不一致；food旧副本是食用行为，
不是另一条玩家初始化链（F_FOOD明确指food.c）。NPC setup也不能证明玩家应该满食水：
heal_up的userp门槛让NPC无食水仍能恢复。**足以提出补满建议，不足以把400/400称为已证实原版结果。**

### 一次符合条件的 heal_up

1. water>0先减1，food>0再减1；零和负数不自动改写。
2. Player减后water<1立即返回：不恢复gin/kee/sen，也不到内部资源段。
3. 否则按gin→kee→sen，各加 `con/3 + 对应atman/force/mana当前值/10`（整数除法）。
   达到旧effective时current封顶于旧effective；effective<maximum则只加1。
4. 再检查减后food<1；此时三项恢复已经发生，但内部资源不恢复。
5. atman→force→mana，分别加raw magic/force/spells除2，封顶各maximum；源码条件是maximum非零且current<maximum。
6. std/char的当前condition-update返回CND_NO_HEAL_UP时，整个heal_up短路不调用，食水也不消耗。
   busy/生命周期/heartbeat决定何时到达此机会，不属于food公式。

独立边界例：fresh0/0调用返回0，仍满100，但战后损失不会靠此自然恢复；
water1→0同样阻止恢复；water2、food0、con30、无内部资源时，损伤current最多加10，
而内部资源段跳过。food0不阻止三项恢复，只要water减后>=1。无饥饿/脱水直接扣血公式。
水充足时，刚修复的effective不会同一步被current追上；不要改成一次全部治满。

**当前native不是已经运行这套生存时钟**：
`game/core/characters/character_recovery.gd::apply_tick`保存相同纯规则；
本次在`game/runtime`搜索未找到CharacterRecovery/heal_up调用（搜索词为`CharacterRecovery`、`heal_up`）。
补查`character_recovery.gd`预加载路径也无runtime命中；此结论限定于当前检出的production代码。
因此不能声称现在Old Pine每隔几秒会因0/0扣血，或选400就自动获得战后恢复。
建立自动恢复/计龄时钟须另行授权；NGE保持纯创建/通行/存档验收。

### Source early supply：有购买路径，没有证实免费水源

- `d/snow/npc/waiter.c` + `feature/vendor.c` + `cmds/std/buy.c`：酒袋20文、包子15文；
  greeting“喝杯茶”只是文字，没有免费加water。生日cake引用的`obj/example/cake.c`不存在，不能作为依赖。
- `obj/example/wineskin.c`：红酒15份，每次liquid.do_drink先remaining−1，再water+30，
  alcohol加drunk6。不是无副作用的清水；fill需房间resource/water。
  搜索整个`d/snow`未找到resource/water定义。
- `obj/example/dumpling.c`：3份，每口food+60。food/liquid都是事前容量检查，最后一口可能超容量，
  没有事后clamp。drunk的部分分支调用不存在于damage中的receive_healing，需后续专项处理。
- `d/snow/workplace.c`：gin/sen至少30才可工作，先sen−30再gin−30，付1silver。
  两次工作从100降到40，得到2silver。`std/room/bank.c`兑换1silver→100coin，留1silver；
  可按finance的当前零钱分支购买20文酒袋和15文包子，余1silver+65coin。
  这是静态可支付构型，不是已实现Godot买卖或真人完整路线验收。
- 只把全部silver换coin会撞上`feature/finance.c::can_afford`缺silver却拒非整万金额的分支；
  不能假设“有够多铜钱就买得到”。bank.deposit为空，不需把完整银行账户加入补给范围。

## FOOD/WATER OPTIONS

| 方案 | Source fidelity | 初期可玩性/恢复 | 实施依赖 |
| --- | --- | --- | --- |
| A 精确0/0 | 完全保留结果 | 初始三项满；一旦受损，不能借heal_up恢复；不等于立即饿死 | 最小初始化；必须诚实声明无自给恢复loop |
| B setup后按容量初始化400/400 | 显式兼容修正；符合max_capacity写法的可能意图 | 允许未来有限次数正常恢复，不是永久免食水或免费回血 | 调用既有容量公式，创建一次；Continue绝不补满；不需vendor/经济 |
| C 0/0 + 即时source补给loop | 保留初态和实际食饮 | 有真正后续补给，但红酒/零钱bug不能隐藏 | 工作/工资stack、兑换、vendor/payment、食饮实例状态/保存、UI、醉酒集成；远超入口 |

**B — OWNER APPROVED（NGE1）**，只在新角色body facts确定后初始化一次。不是修改heal_up或导入旧档补给。
如果owner坚持A，可接受“无战斗胜利/无持续生存承诺的入口切片”；
若选C，应明确扩展预算或独立Snow Supply milestone，不借NGE偷带完整经济。
选择B也仍把可持续补给/成长留到后续，400/400不是early-game完成证明。

## LEGACY NATIVE SAVE CONTRACT

**Legacy Native Technical-Demo Save**：Snow New Game cutover之前，正式Godot版本产生的合法native档。
包含任何已经取得的属性、技能/经验、物品、Old Pine位置、NPC死亡、尸体和RNG状态；不是损坏档，
也不能用“不是原版fresh”理由清除。不能只识别恰好exp600的档：玩家可能已经成长。

### 当前实读实现

| 层 | 已有能力及限制 | 代码 |
| --- | --- | --- |
| Root | format=`eastern-stories-native-save`，schema1，session_kind只接受`oldpine`；一个slot | `game/core/persistence/game_save_snapshot.gd`、`game_save_snapshot_validator.gd` |
| Metadata | format/schema/saved_at_utc/optional build_commit/storage_profile/slot_id；无world revision | `game/core/persistence/game_save_value_types.gd` |
| Codec | 要求所有已知字段且拒绝未知字段；只能读当前schema；不能悄悄往v1加新key | `game/core/persistence/game_save_json_codec.gd::_obj/_decode_root` |
| Player | gender、八属性/force_factor/bellicosity、三资源、内部资源/食水、progression、skills/mapping/learned、conditions、family/apprenticeship | value_types `CharacterStateSnapshot` |
| Player runtime | character_id、life/exists/combat_available、max encumbrance、location、x/y；**无age、title、name、gift_tag、mud_age或独立race/body_weight** | value_types `PlayerRuntimeSnapshot`；`game/runtime/characters/world_player_runtime_state.gd` |
| Item authority | `NativeItemStateSnapshot` v1：实例ID/定义ID/weight/direct parent、combined状态、Equipment/Armor refs | `game/core/persistence/native_item_state_snapshot.gd`、`native_item_record.gd`、`native_item_persistence_composition.gd` |
| Location | region/map/zone/combat_location + 有限浮点坐标；Player位置是active-map唯一存档权威 | value_types、`game/core/world/world_location_state.gd` |
| NPC ledger | spawn/point/definition/character身份、角色状态、年龄/body/capacity、位置、live loadout IDs；dead记录是tombstone | `game/runtime/persistence/oldpine_world_restore_composition.gd::_restore_npc_ledger` |
| Corpse | ID、victim、age/gender/name、stage、worn、位置；交叉验证死亡者和item | 同文件`_restore_corpses`；当前尸体仅outdoor |
| RNG/IDs | combat/NPC-init/world-interaction各seed/state；allocator scope+next；索引派生 | `random_stream_snapshot.gd`、`session_item_id_allocator.gd`、`native_item_persistence_composition.gd`（均core/persistence） |
| Repository | default-v1.json；tmp验证→bak轮换→替换；错误不默选恢复档 | `game/runtime/persistence/game_save_repository.gd` |

标准save coordinator不传build_commit，故它通常是null，不能当世界内容版本或旧档类别判据。
`OldPineWorldRestoreComposition.prepare`不要求Player经验600、八属性20或必须有剑；
它从snapshot重建状态，校验resource invariant、capacity等。**Player数值不是technical-baseline schema**。
但固定`oldpine.player`、OldPine region、outdoor/cave、已知zone、五个authored NPC spawn slot、
Equipment/Armor角色集合、definition projections、loadout规则都是实际恢复限制。
洞穴只接受waterfall passage zone；并非当前定义的全部洞穴zone都可存档落地。

### New Game 与 Continue 分离

`ApplicationShellController`明确分开New Game/Continue/backup-temp intents；已有档时New Game先确认。
`OldPineGameRuntimeHost`为唯一current-Session owner（0..1）；
New Game实例化session场景→`OldPineWorldSessionController._initialize_authorities`→
`CombatSliceDemoFactory.create_player`，覆盖exp600、映射起点并创建/装备semantic long sword。
当前factory八属性20、gin/kee220、sen100、sword/dodge/parry/unarmed10，force/perception显式0。
五NPC物品实例为3×2 + tall2 + fat3 =11，加Player sword=12；货币数量不是实例个数。

Continue → Host → `OldPineSessionLoadCoordinator` → Repository decode →
`OldPineWorldRestoreComposition.prepare` → fresh item graph / exact Equipment+Armor objects →
fresh Player/NPC bindings → staged RESTORE Session → physical placement validation → activate/reparent。
**RESTORE不调用New Game factory，不重新抽NPC，不发剑或补血**；失败不伪装New Game，旧Session回滚保留。
Gameplay RNG按保存状态恢复，runtime object identity新建，semantic IDs精确保留。

已知跨层硬编码：`OldPineOutdoorController._death_context_for`使用Player name=`Player`、age20、
human_weight(str)；restorer对Player corpse也验证这组常量。这不是Player存档里已经有age20。
新age14/name/title若仅改UI，会造成未来尸体和Save不一致；须在cutover前消除这些消费者的事实分叉。
旧档则保留其既有20岁尸体语义，不以新14岁规则重新校验它。

## SAVE COMPATIBILITY OPTIONS

| 方案 | 用户状态/风险 | 结论 |
| --- | --- | --- |
| A Preserve old saves exactly | Continue仍恢复原位置、属性/成长、装备、NPC死活、corpse、RNG；未来切换后只有New Game采用Snow | **OWNER APPROVED（NGE1）**；新增字段缺省只能解释旧事实，不重算或发赠品 |
| B migrate into Snow | 改坐标/region即改变保存状态；填Snow NPC可能重抽随机/复活tombstone；删长剑/经验损害既得状态 | 无强理由，不推荐；不是简单schema migration |
| C reset incompatible | 丢失档、物品/进度和实际用户投入；可省工程但成本不应由玩家默认承担 | 不推荐；只有owner明确牺牲兼容才可考虑 |

**New Game behavior revision != existing Save rewrite**。语义精确保留不要求新writer字节完全一致，
但读取、失败、仅预览不能修改原文件；以后玩家主动Save可写升级格式，仍保留全部可表示状态。
旧档缺失的新字段须按legacy profile解释，不能根据exp/装备猜年龄或倒推“初始天赋”。
旧档不自动升级世界人口；如以后允许旧世界进入新增Snow，应另定显式内容扩展政策，
不能在本NGE恢复时悄悄创造新状态。未知/坏档仍按既有错误及显式恢复流程报告，不放宽校验蒙混通过。

## WORLD CONTENT REVISION

**需要一个窄、typed、与schema分开的内容合同标识（建议world_content_revision）。**
不是为每次git commit递增，也不是generic migration framework。

- 现有`session_kind=oldpine`足以识别已知v1运行合同，却不能区分未来同一Session里的旧人口合同和Snow入口合同。
  optional build_commit不可靠，时间戳/存档名/角色exp也不是替代。
- 建议先只支持两个明确profile：legacy Old Pine v1、Snow-entry v1（名字待实现切片定名）。
  revision选择允许的地图、definition集合、spawn ledger预期和缺失Player事实解释；
  **绝不覆写保存的角色数值**，birth policy也绝不在restore重新运行。
- v1无revision时，已通过原v1 decoder/校验的档按legacy profile解释；未知revision拒绝，
  不默认为“最新内容”，不在老world ledger要求新Snow slots。
- future新增持久字段和revision会改变JSON形状。建议下一版root schema2保留严格v1读取路径，
  仅窄版本分支；item schema仍v1。不修改slot路径以偷偷绕过旧档，不同时造第二套Inventory模型。
- schema2是**建议的未来依赖，不是本次修改**。owner若选择A精确gift，尚需持久化age累计/tag/专属RNG；
  若选B可省这些执行状态，但仍需一致的出生/角色事实及legacy缺省解释。
- 本milestone可先让legacy profile保持旧两图能力，新profile持有Snow+Old Pine。
  不需要第二个current Session、两个Host或复制整个存档架构。

## PLAYER INITIALIZATION AUTHORITY

**推荐新增窄的typed `NewPlayerInitializationPolicy`（或等价factory seam），不要扩充DemoFactory为正式创角引擎。**
其输入只包括已批准的初始化profile、选定gender与必要identity；输出fresh CharacterState及最小Player事实。
体重/负重/资源复用`CharacterDerivedValues`，food容量复用`CharacterRecovery`，不复制公式。

- 与现有CharacterState、Progression、SkillState、Equipment、Armor组合；无Node、dbase/query/set或race registry。
- 角色年龄、显示名/标题、human身体事实应有单一typed持有者供inspect、death context、save消费。
  当前gender已在CharacterState，避免复制第二份。age14不只藏在projection。
- 初始布衣作为authored ItemDefinition/ArmorDefinition，在Session composition以既有Inventory/Armor服务
  创建/穿戴；初始化policy不自己另建世界inventory。补充cloth content/projection/inspect/death coverage，
  不把tear、bandage制作或食饮变体一并迁移。
- Session owns一套allocator/inventory/stacks/RNG/player，初始化policy只在NEW_GAME运行一次。
  Restore继续注入Phase4恢复出来的**同一Equipment/Armor对象**，不能重建第二份。
- `oldpine.player`及`oldpine-session-...`是既有semantic标识，不是把Player锁在Old Pine的物理位置。
  保留旧IDs/allocator scope及continuation；新局也可先沿用opaque标识，避免无价值的大规模改名。
  ID scope用Crypto entropy，不消耗gameplay RNG；不能用gift随机流兼作ID。
- 不先改掉技术New Game。可先构建并测试policy，等Snow和save兼容完整后，才由独立获授权切片切换入口。

### 最小名字/性别 UI 规划

LPC的账号ID/password/email/Chinese name/gender混在连接链中；单机只需要RPG identity和角色选择，
不需要Telnet账号、安全、邮箱或旧中文字节数验证。
建议NGE保留semantic ID及显示名`Player`（作为明确native占位），不要求姓名编辑UI；
title使用普通百姓，gender在New Game确认后、构建前由最小typed选择输入提供。
如果owner要姓名输入，则加独立display_name持久化并同时改inspect/尸体消费者，不把输入姓名变成Item/Player ID。
取消创角不创建Session、不动旧档；Continue跳过创角；移动端/键鼠/手柄焦点沿用Shell约束。
这些都是未来规划，本次不添加UI。

## START LOCATION ARCHITECTURE

Authoritative authored start固定`/d/snow/inn`；native结构仍为
**ApplicationShell → 一个持久Host → 0..1 Session → resident maps / 1 active map → Player physical body**。
Core WorldLocation只记录语义ID；World Runtime拥有位置、spawn marker、collision与portal。

建议最小Snow outdoor聚类square、sroad1、eroad1/2/3为一张连续图，分别用zone追踪LPC内容。
Inn可先作为同图小室内区（最小成本），或以一个紧凑interior map经门口portal连接square；
若采用独立Inn，整间客栈一图，不按MUD每个room拆scene。NGE2实施前冻结该几何选择，
出生marker必须属于inn zone且物理可站立；不直接把Player放square再标legacy inn。

明确最小源路线：inn east→square south→sroad1 east→eroad1 east→eroad2 east→eroad3 south→
oldpine/npath1（可回程）；不是square向南直接传林间空地。
Old Pine north_approach zone已涵盖npath1/2/3，保留既有图形/ID；Snow边界以一对named-spawn portal接北侧入口。
source exits决定连接意义，RPG平面长度/弯曲不是照搬离散步进。

NPC欠账必须公开：inn有traveller2/waiter1，square有trav_blade3，eroad2有dog2。
最小入口几何切片可暂不迁这些人口，但必须称**source-valid Player entry/topology slice**，
不是完整source Snow；不得画假商人却声称能买卖。可选旁路/楼上/外区未迁，不编造quest锁；
以明确内容边界处理，细节在地图切片审查。到Old Pine入口即满足本次候选目标，无必胜战斗。

### 现有机制的可复用与限制

- `game/core/world/world_location_state.gd`和`portal_definition.gd`已可用region/map/zone、
  destination spawn、source metadata；不需要一个新的current_room模型。
- `OldPineWorldSessionController`当前实例化固定outdoor/cave，返回OldPineResidentMapController类型；
  map registry/configure/handoff流程可复用，必须抽出实际共用的resident-map/Session契约，
  不能让Snow控制器伪装OldPine，亦不需要先做万能WorldManager。
- 当前capture从outdoor枚举所有NPC/corpse，restore验证固定region/两图/slots；
  `OldPineMapPlacementValidator`还有zone→CollisionShape路径白名单。未来须按受支持map/profile分发，
  geometry变化也可能让旧坐标失效，保留Old Pine既有几何/校验，不能强行clamp玩家位置。
- 仅增加map字符串不足以恢复Snow：save capture、content lookup、NPC ledger、corpse归属、
  location validation、staging/activation、Host/coordinator类型边界必须一同通过集成测试。
- 最小推荐先保持Old Pine五NPC的eager初始化与已知顺序；恢复只读保存ledger，零gameplay RNG。
  新Snow profile若暂无NPC，不发明“未访问=没出生”新ledger状态。lazy spawn及Snow人口增加另行定范围。

## MINIMUM NGE MILESTONE

**候选顺序调整：保存兼容设计/fixture必须前置；公开New Game cutover必须后置。**
以下均属同一major branch，不另开slice PR。表格不是实施授权。

| 切片 | 最小范围 | Gate |
| --- | --- | --- |
| NGE1 | approved初始化policy、最小Player事实、布衣data/穿戴composition、old-save解释fixtures | 精确age14/30/100/99/0/cloth；gender；无剑钱skills；三兼容选择获批；不切当前菜单 |
| NGE2 | Inn最小物理入口、shared resident-map/Session seam | 真spawn、collision/移动；出生事实跨UI/death/save消费者一致 |
| NGE3 | square+sroad1+eroad1/2/3连续outdoor | 无每room加载；Inn门口或zone跨越正确；公开未迁人口/服务 |
| NGE4 | Snow↔Old Pine north_approach | 原Player/Inventory/Equipment/Armor/RNG对象保持；不动敌人数值；往返/冻结/输入回归 |
| NGE5 | versioned保存兼容、Snow及Old Pine Save/Continue、最终New Game cutover | v1 legacy无重写；new profile可fresh-process恢复；失败回滚/显式recovery；无gift/food重发 |
| NGE6 | focused→正式全套审计→真实玩家入口/往返/保存验收→唯一final PR | 合规范围、Windows/Android代表路径；PR四项；仅owner授权merge；green main后集成 |

NGE1可先锁schema/profile与legacy fixtures，但不可抢跑写schema；NGE5不是到最后才发现age/尸体缺字段。
New Game切换到Snow前，NGE2–5必须同时成立，否则技术baseline保持。
验收：正确创建→客栈出生→实际走路→Old Pine北入口→往返→保存/进程重启Continue。
旧档另测：已成长Player、空手/已有装备、NPC tombstone、尸体、跨图位置、allocator及RNG精确恢复。
**不要求新手击败bandit、不降敌人数值、不赠送剑/钱/exp弥补可玩性。**

## DEPENDENCIES

| 依赖 | 最小处理 / 延后边界 |
| --- | --- |
| 三owner政策 | gift B / food-water B / old-save A：OWNER APPROVED；仅NGE1 foundation已授权 |
| Player metadata与持久化 | birth age/title/identity的一份事实；旧Player age20尸体语义必须保留，不能编造历史mud_age |
| cloth Item/Armor/content | 复用现有实例/穿戴/存档；补定义及玩家可见投影，不做泛型item payload |
| Session/map membership | region-aware地图组合、实际collision/portal验收；不替换Core权威 |
| world-content revision | 两个明确合同、窄v1兼容；不以build_commit/null或exp猜测 |
| Save/Continue | 原生精确位置/state，非LPC startroom/autoload；不可自动把旧玩家送Snow |
| Supply（若C） | work工资、coin+silver转换、付款bug决定、vendor、食饮状态和保存、drunk及交互；另列Snow Supply预算 |
| Training/economy | 全部延期；已有Skill Core不等于教学/商店/打工runtime已迁 |
| 年龄/自动恢复 | 当前无Player年龄时钟或runtime heal_up接线；另行定义暂停、离线及计时契约，不以MUD heartbeat实现 |

## NGE0 HISTORICAL OUT OF SCOPE

本次不改New Game、scene、source、save schema、tests、DECISIONS、build/CI/export。
不实现Snow/Inn/Square/NPC/Shop/Training/Lake/Phase5B4；不跑完整gameplay suite或真人重复测试。
不实现account/password/email、通用创角引擎、migration framework、race registry、LPC property VM。
不创建PR、不合并，不调整敌人/死亡规则，不要求完整38房/26NPC、银行账户、当铺、书院、外部区域。

## OWNER DECISIONS — APPROVED FOR NGE1

1. **gift B — OWNER APPROVED**：不创建gift_tag、pending allocation、gift RNG或age15 callback。
   将来实现aging也不得自动恢复覆盖，需重新source analysis + owner decision；其他正常属性成长不受限。
2. **food/water B — OWNER APPROVED**：body确定后fresh birth一次400/400；LPC执行结果仍为0/0。
   Continue/Restore/换图/复活/失败恢复/回菜单绝不补满。
3. **old-save A — OWNER APPROVED**：精确保留，不送Snow、不重设经验、不改物品/NPC/corpse/RNG/allocator。
   v1自身解释为legacy technical profile，禁止按经验、长剑、timestamp猜测。

后续milestone验收范围仍需相应切片授权，不将上述三选择扩大为完整生存成长体验；
名字可先Player+gender选择，Inn几何与未迁人口边界在后续地图切片冻结。
世界revision及schema2只是为批准政策服务的窄技术建议；没有授权时不实现。

## RECOMMENDATION

**B / B / A。** 保留source fresh年龄14/30属性/资源100/潜能99/经验0/布衣空手；
明确取消延迟gift覆盖，并仅在新建身体后给当前容量食水。保留所有合法native旧档的实际状态。
这个组合最小化隐藏惩罚、随机流及经济范围扩张，同时明确承认两项兼容替代。
以上三项已获批准并写入DECISIONS；其余建议仍不替代授权。

## SOURCE COVERAGE / DISTINCT SELF-REVIEW

本次直接读源，不仅复述S0。重点重新核查文件：

- Entry/状态：`adm/daemons/logind.c`、`obj/user.c`、`adm/daemons/race/human.c`、
  `adm/daemons/chard.c`（setup及尸体相关段）、`adm/daemons/updated.c`、`std/char.c`、
  `feature/save.c`、`feature/move.c`、`feature/damage.c`、`feature/dbase.c`（查询/默认）、
  `feature/skill.c`（初始mapping/raw）、`feature/equip.c`、`cmds/usr/quit.c`、`cmds/usr/save.c`、`include/login.h`。
- 食饮/意图：`feature/food.c`、`feature/liquid.c`、`feature/foodold.c`、`feature/foodbak.c`、
  `std/char/npc.c`（初始化/行为基础）、`doc/help/start`、`doc/help/newbie`、`doc/help/gift`；
  `include/globals.h`核F_FOOD/F_LIQUID定义。旧food副本不作为现行规则。
- 物品/供给：`obj/cloth.c`、`std/armor/cloth.c`、`d/snow/npc/waiter.c`、`feature/vendor.c`、
  `feature/finance.c`、`cmds/std/buy.c`、`d/snow/workplace.c`、`d/snow/bank.c`、`std/room/bank.c`、
  `obj/example/wineskin.c`、`obj/example/dumpling.c`、`obj/money/silver.c`、`obj/money/coin.c`、
  `std/money.c`、`std/item/combined.c`（确认工资合并/价值）、`daemon/condition/drunk.c`。
- 路线：`d/snow/inn.c`、`square.c`、`sroad1.c`、`eroad1.c`、`eroad2.c`、`eroad3.c`、
  `d/oldpine/npath1.c`、`d/snow/npc/dog.c`；其余Snow沿用S0的范围分析，不宣称本次重读全部38房/26NPC。
- Searches：全mudlib的gift_tag/max_food_capacity/max_water_capacity；adm、user/NPC基础类的食水赋值；
  Snow全文的food/water/resource、水源；help/adm文本的初始化线索。未作跨分支历史考古，
  未发现证据不等同整个ES2从未有过另一版本。
- Native重点：上文列出的root/value types/validator/codec/item composition/allocator、Player state、
  CharacterDerivedValues/Recovery、demo factory、Session NEW_GAME/RESTORE、Host、save capture、
  restore composition/service、load coordinator、repository、map placement validator、WorldLocation/Portal、
  OldPine spawn/NPC/content projections、Shell intents和outdoor death context。

自审区分：source执行/意图；属性初始化/后续成长；age更新/gift触发；capacity/当前食水；
原生角色数据/内容限定；新局/Continue；schema/content revision；proposal/owner decision；
静态路径/真实玩家验证。未把已有技术基线当bug。

## NGE0 HISTORICAL VALIDATION

Docs-only gate：只允许本文、STATUS、ROADMAP；检查相对base全部路径与未跟踪文件，
production/tests/reference/DECISIONS/build/CI/export delta必须为0；执行repository/static、
git diff --check、编辑文档尾随空白和本地Markdown链接检查。
不重跑完整gameplay suite，不声称headless或live gameplay验收：本次没有可执行变更。
实际执行：repository/static PASS；52个本地Markdown链接目标存在；三份编辑文档尾随空白PASS；
git diff --check PASS；含新文档的三文件allowlist PASS；相对base的production/tests/reference/
DECISIONS/build/CI/export delta全部为0。Python使用已有解释器，未新增依赖。

## NGE1 READY / NOT READY

**NGE1 AUTHORIZED — 三项兼容选择已批准。**
NGE1执行记录以独立初始化文档为准；不代表整个milestone集成完成。
NGE1完成后仍HARD STOP等待owner review，不自动进入NGE2，不创建PR或merge。
