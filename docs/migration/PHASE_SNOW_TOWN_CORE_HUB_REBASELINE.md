# S1 — Snow Town Core Hub Restoration / Source Rebaseline & Dependency Analysis

## EXECUTIVE RESULT

**S1 SOURCE REBASELINE / DEPENDENCY ANALYSIS COMPLETE — AWAIT OWNER REVIEW.**
这是 source archaeology / planning-only slice，不是 Snow implementation approval。
Major branch：`phase/snow-town-core-hub`；exact integrated base：
`047f29083e881156abbdad6ed480bffc1350dfa8`。没有 gameplay、scene、test、schema 或 revision 修改。

本文标签含义：**SOURCE FACT** = 实际读到的 LPC 执行代码/数据；**CURRENT NATIVE FACT** = 当前
Godot 代码事实；**INFERENCE** = 明示前提的源码推导/规划建议；**OWNER DECISION REQUIRED** = 尚未批准的行为替代。
所有未带目录前缀的 LPC 路径均以 `reference/es2/mudlib/` 为根；`Snow` 简写指 `d/snow/`。
读取原始文件、继承链和调用方，不借用外部 ES2 port；未运行 LPC driver，不把静态推导称为原版实测。

- **SOURCE FACT**：全量 Snow 为 **107 个 .c**：38 rooms + 26 NPC + 21 `obj` + 22 `npc/obj`。
  额外 `npc/keeper.txt` 是非执行副本，不计 NPC。20 个本地 NPC 定义在 Snow room 的 active
  `objects` 中被引用，共35个实例槽；另有外部柳淳风1槽，总36。不是26个NPC全都出生在Snow。
- **SOURCE FACT**：无需武器、钱、技能或师门即可 `work`；一次仅检查 gin/sen>=30，
  依次损耗 sen30、gin30，再创建1 silver。没有忙碌、cooldown、RNG或经验奖励。
- **SOURCE FACT**：兵器房的竹剑是地面物品，无收费/师门/偷盗检查；武馆门是可打开的普通门。
  “无名小卒不能住宿”“后院需馆主允许”均没有对应 Snow gate 代码，不能照文字添加。
- **SOURCE FACT**：钱庄只有兑换实现；deposit空、无withdraw。当铺pawn/sell为支付后销毁物品，
  没有当票/赎回。Inn有付费食物/酒/匕首，但免费蛋糕引用缺文件；Snow没有`resource/water`。
- **SOURCE FACT**：柳淳风收徒只检查有效cor/cps>=20；fresh30满足，可免费学literate。
  魏无极是另一条500文认可路径，不是唯一第一技能来源，且其文件有未实现函数闭包风险。
- **CURRENT NATIVE FACT**：钱币堆叠值、Inventory/Armor、Learn/Practice/Recovery规则已经存在；
  缺的是窄的城镇服务、生产内容和runtime接线，不是另一个货币/角色/技能/存档权威。
- **INFERENCE**：最小下一slice应是 **S2 — Work income + source currency composition + minimal access**，
  以“无钱出生→走到加工厂→工作→银两入同一item graph→Save/Continue”验证第一条可用经济边。
  不先铺满38房间，不把整个NPC表当作一次bulk migration。重复生活闭环还依赖恢复/消费接线。

## CURRENT NATIVE BASELINE

**CURRENT NATIVE FACT**：Source-valid New Game Entry 已通过 [PR #15](https://github.com/Toxicccxz/eastern-stories-godot/pull/15)
合并；post-main [34631309438](https://github.com/Toxicccxz/eastern-stories-godot/actions/runs/34631309438)
四项成功，exact SHA同上。历史slice证据见 [NGE6](PHASE_NEW_GAME_ENTRY_FINAL_AUDIT.md)，不重写其历史checkpoint。

`game/core/characters/new_player_initialization_policy.gd::create`：Human、age14、八属性30、exp0、
potential99/spent0、gin/kee/sen各100/100/100、内资源0、无技能/师门/武器/钱；body80000、capacity150000，
food/water400是已批准的出生顺序修正，不是LPC原始初始化结果。
`application/new_game/new_player_inventory_composition.gd`只组合出生布衣；body/identity各有既定authority。
`game/data/snow/snow_world_definitions.gd`仅定义Inn main floor与Square/sroad1/eroad1–3路线；
`game/runtime/world/oldpine_world_session_controller.gd`组合4个resident maps及既有Old Pine内容。
Snow NPC count常量是traceability，不会spawnNPC。当前公共入口已非技术exp600/长剑出生。

## COMPLETE SNOW ROOM INVENTORY

**SOURCE FACT**：以下38行即完整root `.c`集合，每行source为`d/snow/<ID>.c::create`。
N/E/S/W/U/D/NW/SW表示实际exit key；不根据long文字补出口。外部用全路径。
O=`outdoors="snow"`；I=未设置outdoors（不是美术/屋顶的推断）。Native“是”只指几何/既有路线，非population/services。
门C=DOOR_CLOSED，非locked；`std/room.c` + `cmds/std/open.c`允许普通打开。

| ID / short | O/I | 完整静态exits | objects / special / gate | Native |
| --- | --- | --- | --- | --- |
| inn / 饮风客栈 | I | E square; U inn_2f; NW /d/wiz/entrance | traveller2, waiter1; NW门C; sign; valid_startroom | 是（主层/E） |
| inn_2f / 饮风客栈二楼 | I | W w_room; N n_room; D inn; E e_room | rat6; W/N/E门C | 否 |
| n_room / 客房 | I | S inn_2f | S门C | 否 |
| e_room / 客房 | I | W inn_2f | W门C | 否 |
| w_room / 客房 | I | E inn_2f | E门C | 否 |
| square / 广场 | O | N mstreet1; W inn; S sroad1; E temple | trav_blade3; worker4被注释 | 是（W/S） |
| mstreet1 / 雪亭镇街道 | O | W bank; S square; N mstreet2; E school1 | 无 | 否 |
| mstreet2 / 雪亭镇街道 | O | N mstreet3; S mstreet1; W smithy; E workplace | drunk1, scavenger1 | 否 |
| mstreet3 / 雪亭镇街道 | O | S mstreet2; N mstreet4; E hockshop; W herbshop | E门C | 否 |
| mstreet4 / 雪亭镇街道 | I | N crossroad; S mstreet3; W postoffice | long提东巷，mapping无E | 否 |
| crossroad / 山坳 | O | N /d/goathill/mroad1; E /d/green/path6; S mstreet4 | 告示仅文字 | 否 |
| sroad1 / 雪亭镇街道 | O | W sroad2; N square; S /u/cloud/dragonhill/nroad; E eroad1 | 无 | 是（N/E） |
| sroad2 / 雪亭镇街道 | O | W sroad3; S school; E sroad1 | farmer2 | 否 |
| sroad3 / 青石官道 | O | W sroad4; E sroad2 | 无 | 否 |
| sroad4 / 青石官道 | O | N sroad5; E sroad3; SW /d/canyon/road | crazy_dog1;进入有侵略风险 | 否 |
| sroad5 / 青石官道 | O | W /d/waterfog/sroad1; S sroad4 | 无 | 否 |
| eroad1 / 黄土小径 | O | E eroad2; N temple; W sroad1 | 无 | 是（E/W） |
| eroad2 / 黄土小径 | O | E eroad3; W eroad1 | dog2 | 是（无狗） |
| eroad3 / 山路 | O | S /d/oldpine/npath1; E /d/temple/sroad; W eroad2 | long方向与mapping不全一致，以mapping为准 | 是（W/S） |
| bank / 安记钱庄 | I | E mstreet1 | annihir1; BANK convert/deposit; no_fight/no_magic注释 | 否 |
| smithy / 打铁铺子 | I | E mstreet2 | smith1 | 否 |
| workplace / 谷物加工厂 | I | W mstreet2 | 无NPC; work/sign; no_fight1 | 否 |
| hockshop / 丰登当铺 | I | W mstreet3; E hockshop2 | W门C; HOCKSHOP value/pawn/sell;master spawn注释 | 否 |
| hockshop2 / 储藏室 | I | W hockshop | 锁箱/拍卖仅描述，无objects | 否 |
| herbshop / 桑邻药铺 | I | E mstreet3 | herbalist1, woodcutter1; cabinet/sign描述 | 否 |
| herbshop1 / 药铺密室 | I | 无 | 无objects/commands;没有入口 | 否 |
| postoffice / 雪亭驿 | I | E mstreet4 | post_officer1; valid_leave销毁mbox | 否 |
| school / 书院 | I | N sroad2 | teacher1槽（文件teacher.c，不是teacher1.c）;西厢无exit | 否 |
| school1 / 淳风武馆大门 | O | W mstreet1; E school2 | guard1; E门C | 否 |
| school2 / 淳风武馆教练场 | O | N weapon_storage; W school1; E schoolhall | trainee6, fist_trainer1; W门C | 否 |
| schoolhall / 淳风武馆大厅 | I | W school2; E inneryard | CLASS_D(swordsman)/master1; valid_startroom;留言板load | 否 |
| inneryard / 天井 | O | S guestroom; N nyard; W schoolhall; E innerhall | pillar文字 | 否 |
| nyard / 书房 | I | S inneryard | girl1;书架仅文字，没有books spawn | 否 |
| guestroom / 客房 | I | N inneryard | 属武馆，不属Inn；画无互动实现 | 否 |
| innerhall / 武馆内院 | I | W inneryard | 祠堂/卧房/厨房仅文字，没有其它exit | 否 |
| weapon_storage / 兵器储藏室 | I | S school2 | npc/obj/bamboo_sword1; push shelf相关动态D | 否 |
| secret_storage / 地下密室 | I | 无 | obj/shield1;动态U取决于加载时机 | 否 |
| temple / 城隍庙 | I | S eroad1; W square | keeper1, obj/denotation1, /obj/paper_seal2; no_fight="1" | 否 |

## TOPOLOGY

**SOURCE FACT**：上表是完整有向邻接表；下图只是聚类摘要，完整方向/门以上表为准。

```text
external GoatHill/Green <- crossroad - mstreet4 - mstreet3 - mstreet2 - mstreet1 - square
                                      |           |           |           |        |
                                   postoffice  herb/pawn   smith/work   bank/school1 inn - inn_2f - 3 rooms
                                                                            |        |
                                                                        school2    sroad1 - eroad1 - eroad2 - eroad3 -> Old Pine/Temple region
                                                                        /     \       |        |
                                                          weapon_storage    schoolhall |      temple - square
                                                                :                |   sroad2 - school (书院)
                                                          secret_storage     inneryard |
                                                                         /    |    \  sroad3 - sroad4 - sroad5 -> Waterfog
                                                                   guestroom nyard innerhall   |SW
                                                                                            Canyon
herbshop1: isolated; sroad1 S -> DragonHill; inn NW -> wizard reception
```

**SOURCE FACT**：38房中36房由静态Snow exits连通；secret_storage需动态入口；herbshop1孤立。
这是拓扑可达，不保证每个引用对象能在该driver编译/加载（下文source quality），也不保证避开游走NPC。
`weapon_storage::do_push`：空参数return0；精确`"shelf"`只给提示，其他任意非空参数均加left_trigger1；
达到**恰好3**且无down时开路、删计数、10秒后关闭。不是检查`left`字符串，更非skill/random puzzle。
上行只在**开门当时**`find_object(secret_storage)`成功时设置；首次随后`go down`才加载密室，可能没有up。
关门时删两侧exit；reset调用ROOM reset并清left_trigger。共享room状态，不是每Player独立谜题。

**INFERENCE — recommended native embodiment（未锁定）**：

| Source cluster | 建议形态 | 理由/边界 |
| --- | --- | --- |
| Square + mstreet1–4 + sroad1–5 + eroad1–3 + crossroad | 延展一个连续town outdoor map + zones | 同一城镇道路，保留区域边界而非每room loading |
| Inn + inn_2f + n/e/w_room | 扩展现有Inn resident，楼层/门内zones | 不把武馆guestroom误并入Inn；楼层视觉方案以后验证 |
| school1/2/hall + yards + guestroom + weapon/secret | 一个school complex或户外院落+独立building | 同一武馆；密室门状态独立，非新region |
| school | 独立小书院interior或town建筑zone | 不与武馆trainer混为一处 |
| bank / smithy / workplace / herbshop / hockshop2 | 小室可town-local interior；大建筑才独立resident | 按碰撞、视觉和handoff需求决定，不由LPC文件数量决定 |
| temple | town-local或独立interior候选 | no_fight与未来revive需同一zone语义；不改变当前死亡政策 |
| herbshop1 / secret room | 等source缺陷review再决定 | 不创建自动连通的假出口 |

## EXTERNAL REGION BOUNDARIES

**SOURCE FACT**：逐一读到目标文件及回程：
`crossroad N→d/goathill/mroad1 (S回)`；`E→d/green/path6 (W回)`；
`sroad1 S→u/cloud/dragonhill/nroad (N回)`；`sroad4 SW→d/canyon/road (NE回)`；
`sroad5 W→d/waterfog/sroad1 (E回)`；`eroad3 E→d/temple/sroad (W回)`；
`eroad3 S→d/oldpine/npath1 (N回)`；`inn NW→d/wiz/entrance (SE回，门)`。
8条外部边均有目标文件，不能因为`u/`路径就判断DragonHill是admin玩法。
`d/wiz/entrance::valid_leave`只限制进一步W进入wizard hall，普通人可进接待室；
其init禁止练功命令、留言板属管理员沟通基础设施，建议不作玩家hub服务迁移。
Canyon的继续`climb chain`损耗gin20/kee30/sen10，属外部冒险，不是Snow工作前置。
Temple region不是Snow城隍庙；Old Pine连接已native，其余外区只记边界，不授权扩展。

## NPC POPULATION

**SOURCE FACT**：以下完整26文件的identity/stats来自各`create()`。
H=未显式race，经`std/char::setup→chard::setup_char→human::setup_human`成为人类；
B=显式野兽。未列八属性不是30：H每项缺值random(21)+10；B缺str/con为random(41)+5、
cor random(21)+5、int/cps random(11)+5、per random(31)+5、spi0、kar缺失查询0。
H gender缺省男性、attitude peaceful；B gender缺省雄性、无human attitude fallback。
exp“缺0”是缺字段查询值，不是显式set0。`std/char::setup`还消耗tick RNG，future authored RNG顺序须另核。

| Snow npc/*.c | 名称 / aliases | race; age; gender | 显式八属性 | exp; attitude | raw skills / map_skill |
| --- | --- | --- | --- | --- | --- |
| annihir | 安惜迩 / annihir | H;26;男 | str22 cor30 cps30 int26 per23 con24 spi30 kar25 | 200000;friendly | unarmed/parry/dodge/force/celestrike/celestial/fonxansword/six-chaos-sword/chaos-steps/spells/necromancy各100；force→celestial,unarmed→celestrike,dodge→chaos-steps,sword→fonxansword（重复set）,spells→necromancy；无raw sword |
| beggar | 乞丐 / beggar | H;53;男 | str27 |100;默认 | 无 |
| crazy_dog | 疯狗 / crazy dog,dog | B;4;默认雄 | str26 cor30 |100;aggressive | 无；apply attack15/damage6/armor2 |
| dog | 野狗 / dog | B;3;默认雄 | str24 cor26 |缺0;无 | 无；apply attack10/armor3 |
| drunk | 醉汉 / drunk,man,drunk man | H;17;男 | con30 str30 |100;heroism | 无 |
| farmer | 农夫 / farmer | H;33;男 | 无 |20;friendly | 无 |
| fist_trainer | 李火狮 / trainer,lee | H;28;男 | str26 int14 |3000;heroism | unarmed30,liuh-ken20,dodge30；unarmed→liuh-ken |
| girl | 柳绘心 / liuh wheixin,liuh,wheixin | H;15;女 | str16 cor24 cps11 per27 int27 |1000;friendly | unarmed20,parry40,dodge50,sword30,force30,literate70,fonxanforce40,fonxansword40,liuh-ken40,chaos-steps70；unarmed→liuh-ken,sword/parry→fonxansword,dodge→chaos-steps |
| guard | 刘安禄 / liu anru,liu | H;26;男 | str29 cor30 cps30 int11 |20000→revealed50000;heroism→aggressive | blade40,parry40；无mapping |
| herbalist | 杨掌柜 / herbalist yang,yang | H;54;男 | 无 |1300;friendly | literate70,dodge60,unarmed60 |
| keeper | 庙祝 / keeper | H;74;男 | 无 |1;friendly | 无 |
| mercenary | 逄义 / pangyi | 显式人类;33;默认男 | 无 |缺0;默认 | sword70,dodge70,unarmed80,move80,force65,fonxanforce80,fonxansword80,chaos-steps70,liuh-ken80,literate60；sword→fonxansword,unarmed→liuh-ken,dodge→**chaos-steos**,force→fonxanforce |
| old_farmer | 老农夫 / old farmer,farmer | H;63;男 | 无 |20;friendly | 无 |
| post_officer | 杜宽 / post officer,officer | H;43;男 | 无 |800;friendly | literate70,dodge50,unarmed40 |
| proposer | 媒婆 / proposer | H;38;女 | 无 |缺0;friendly | 无 |
| rat | 老鼠 / rat | B;1;默认雄 | 无 |缺0;无 | dodge120；limbs头/身体,verbs bite |
| scavenger | 收破烂的 / scavenger | H;47;男 | str27 |10;默认 | 无 |
| smith | 王铁匠 / wang,smith | H;33;男 | 无 |400;默认 | 无 |
| teacher | 魏无极 / teacher,wey | H;47;男 | int26 |缺0;peaceful | literate60 |
| teacher1 | 魏无极 / teacher,wey | H;47;男 | int26 |缺0;peaceful | literate60 |
| trainee | 武馆弟子 / trainee | H;19;男 | 无 |100;默认 | 无（不能从身份名推导拳法） |
| trav_blade | 旅客 / traveller | H;15+random50;random10<7男否则女 | 无 |600+random400;friendly | dodge50,throwing30,unarmed40；score=5-random10 |
| traveller | 旅客 / traveller | H;15+random50;同上 | 无 |600+random400;friendly | dodge50,unarmed40；score=5-random10 |
| waiter | 店小二 / waiter | H;22;男 | 无 |10000;friendly | dodge300 |
| woodcutter | 樵夫 / woodcutter | H;26;男 | str30 |140;默认 | 无 |
| worker | 苦力 / worker | H;27;男 | str27 |缺0;friendly | 无 |

完整population / service / lifecycle矩阵（Source Room均指room::objects，0不等于文件不存在）：

| NPC | Source Room | Count | Role / Combat / chat | Service / equipment / dependencies | Fresh-player relevance |
| --- | --- | --- | --- | --- | --- |
| traveller | inn |2| ambient,friendly拒普通挑战；chat40 random_move | cloth worn,coin100；无ask/service | 不送武器/指导 |
| waiter | inn |1| vendor；chat无；init1秒greeting random3 | F_VENDOR；4种stock；relay_say蛋糕缺引用 | 补给/付费匕首 |
| rat | inn_2f |6| beast ambient，高dodge120，无chat | 无物品/服务 | 不是住宿规则 |
| trav_blade | square |3| ambient,friendly；chat40 random_move | npc/obj/throwing_knife100 wield,cloth worn,coin100 | 不能将装备当免费货架 |
| dog | eroad2 |2| ambient；chat6（move/嗅/讨食等） | accept_object bone→set_leader；无loot配置 | 跟随非通行条件 |
| annihir | bank |1| service；accept_fight转kill；pursuer1,wimpy70 | longsword+cloth, gold10；三内资源/max各1000/factor3；chat15 powerfade，combat40 spells/exert/counterattack | 兑换由room负责，不必交战 |
| drunk | mstreet2 |1| ambient/quest-like；chat10 do_drink | cloth+wineskin；water>=380唱歌；耗尽酒袋drop；give alcohol→elder_info/give_alcohol/know_drug链 | 没有直接奖励钱/酒 |
| scavenger | mstreet2 |1| ambient；chat20包含move；拒挑战 | force/max30 factor1；/obj/old_book,coin50；accept任意物不付钱 | **不是收购商** |
| herbalist | herbshop |1| vendor/healer描述，friendly | F_VENDOR两药；max gin200/kee400/sen300；coin80；init list；ask heal_me | 真实治疗只在药物 |
| woodcutter | herbshop |1| ambient；chat15含move/野羊山抱怨；wimpy10 | npc/obj/lumber_axe wield,cloth worn | 没有卖斧hook |
| smith | smithy |1| vendor（不用F_VENDOR） | npc/obj/hammer wield；ask；buy_object+compelete_trade |300文铁锤，不锻造 |
| farmer | sroad2 |2| ambient；combat chat50叫喊/surrender,wimpy60 | npc/obj/raincoat+sandals worn,coin20 | 无工作/补给函数 |
| crazy_dog | sroad4 |1| hostile；chat15 move；combat消息有配置但没chat_chance_combat | F_ATTACK→COMBAT_D auto_fight | 西路危险，不是工作前置 |
| teacher | school |1| trainer；peaceful | 500文mark认可；ask数组；follow_player声明但实现被注释 | literacy路径有source quality问题 |
| guard | school1 |1| guard/hidden hostile；combat chat15 | npc/obj/blade+cloth；ask身份揭露、变属性、全室kill、生成blade_book | 不检查出入师门；不要误触身份话题 |
| trainee | school2 |6| ambient/默认战斗；无训练hook | npc/obj/linen worn | 没有免费教学 |
| fist_trainer | school2 |1| trainer；对同派允许fight | force/max120 factor1；ask3；recognize只封山剑派 | 拜师后基本拳/柳家拳/闪躲 |
| 外部 柳淳风 | schoolhall |1| master；combat chat60 sword.counterattack | `daemon/class/swordsman/master.c`+F_MASTER；blackthorn+silk_cloth | 免费入派/教学重要路径 |
| girl | nyard |1| special/ambient；拒挑战；combat chat25含counterattack | npc/obj/thin_sword+pink_cloth+shoe；force/max200 factor2；family=封山剑派北宗14代 | 不是普通封山剑派全权限teacher |
| keeper | temple |1| service；init1秒greeting | accept金钱降低bellicosity的条件/RNG；无回血 | 捐赠，非复活执行者 |
| post_officer | postoffice |1| mail service | coin70；ask产生MAILBOX_OB，需在startroom | 多人邮件，不是任务投递 |
| beggar | 无Snow spawn |0| ambient；chat15move；拒挑战 | force/max200 factor2；/obj/old_book；accept不付回报 | /u/cloud/monky.c有2槽，不能当Snow新人礼物 |
| old_farmer | 无Snow spawn |0| ambient；combat50 surrender,wimpy60 | raincoat/sandals,coin20 | 未用，不自动放入 |
| teacher1 | 无Snow spawn |0| trainer副本 | 与teacher同收费/mark；follow_player有实现，数组调用方仍不执行闭包 | 不静默替换teacher |
| mercenary | 无Snow spawn |0| hire service；F_MERCENARY缺定义 | force1000/max600；剑衣；pay>=10000，boss/on_duty，(value/10000)*1440秒回家；family封山13 | 高价+broken dependency，defer |
| proposer | 无Snow spawn |0| marriage service | color_cloth；男/非bonze/can_speak/无spouce；follow/accept_order/propose忙循环；只对userp女性 | 多人婚姻，非核心hub |
| worker | 无Snow active spawn |0| hire service，不是雇主 | cloth；pay>=100，boss_id；(value/100)*1440秒；accept_order拒kill/fight，accept_info匹配boss | 花钱雇人，与加工厂赚钱无关 |

上述20个本地定义在Snow中各只被一个room引用；数量>1表示多个clone槽，不是多个服务定义。
仓库反向引用另见`d/city/street8/9/13/17.c`各1个scavenger（字面路径缺前导slash，记录原样）；
street10/11/12/14/15、jiaowu的同类引用被注释，不能计数。
`npc/obj`依赖不能与`obj`混淆：21个同名文件中20个逐文件SHA256字节一致；old_book不同，另多throwing_knife。

共有行为：`std/char/npc.c`carry_object先new→move→返回，add_money先carry再set_amount；chat是
`std/char::heart_beat`驱动，random_move发go，room reset追踪clone并尝试return_home。
`feature/attack.c::init→combatd::auto_fight/start_aggressive`会在同处/存活/no_fight条件复核后kill；
不能把friendly、heroism、peaceful统一理解为“不会战斗”。未迁移cast/exert/perform、pursuer、
spider-array八人阵、NPC自由游走，不因为模型已有Combat就假定这些高阶行为可用。

**SOURCE FACT（外部任务边界）**：drunk::accept_object只接受remaining>5的酒，且自身has_alcohol=0
时才推进elder_info→give_alcohol→know_drug（不同次供酒）；没有直接金钱奖励。
反向追到`d/green/npc/oldman2.c::set_flag`需last_asker，且放在inquiry数组；当前ask既不执行
数组闭包也不设置last_asker，因此不能把这一前置当成已闭合可用任务。
`d/green/npc/shen.c::give_jade/sell_drug/accept_object`消费这些临时标志，涉及jade unique检查、
1000文蒙汗药等外区内容；这是依赖边界，不是Snow first-hour已证明可获得的奖励链，不在本milestone展开。

## ITEM / OBJECT INVENTORY

**SOURCE FACT**：21个Snow `obj/*.c`全表。W为set_weight，V为query("value")，D为weapon_prop/damage；
不是`value()`方法，也不是成交价。相同名`npc/obj`字节相同者仍是不同legacy来源/merge identity。
下表除old_book外同名`npc/obj`数据相同；T表示在Snow active路径取到的是**npc/obj**版。

| Item / definition basename | W / V | 类型及作用 | Source acquisition / cost-condition / repeatability | Core hub relevance |
| --- | --- | --- | --- | --- |
| 竹剑 bamboo_sword |1000/100| sword D10,EDGED | weapon_storage→npc/obj版1；open普通门→get；非无限复制 | 免费第一剑 |
| 单刀 blade |4000/500| blade D25,EDGED | guard持有T；战斗/死亡或非living搜取才是路径，无出售 | 非fresh常规购买 |
| 残破刀谱 blade_book |600/260| blade书：exp1000,sen30,difficulty20,max40 | guard揭露时生成T；不是书房spawn | 后期/揭露链 |
| 艳红绸衫 color_cloth |1000/500| cloth armor1,personality1,female_only | proposer T，Snow无spawn | 未用 |
| 功德箱 denotation |默认0/1| ITEM,no_get,capacity10000,insert_object | temple→obj版1；非Player可拿物 | 捐赠hook断链，见Temple |
| 乌雪莲 ebony_lotus |90/30000| FOOD一口100；tonic force60/max_force2000 | 两目录均无Snow获取引用 | 不自动成为药铺stock |
| 人参 ginseng |50/3000| FOOD一口30；tonic atman5/max_atman150 | 同上 | eat_tonic缺失 |
| 铁锤 hammer |8000/3| hammer D15 | smith持有/购买新clone T；价300，不是V3 | 实际买武器 |
| 雪莲 ice_lotus |90/4500| FOOD一口50；tonic force5/max_force300 | 无Snow获取引用 | 不声称能加内功 |
| 粗布衣 linen |5000/40| cloth armor2 | trainee T6套；非free floor | NPC loadout |
| 铁斧 lumber_axe |22000/11| axe D11,EDGED+TWO_HANDED | woodcutter T；无出售 | 不送、不借 |
| 旧书 old_book |600/70| force：exp0,sen30,difficulty20,max10 | obj版无Snow获取引用；npc/obj版F_UNIQUE缺宏、replica旧农历、max30 | 不混同scavenger的/obj/old_book |
| 旧农历 old_book_r |600/30| 普通ITEM，无skill mapping | npc/obj版被unique书replica字段引用；无可用unique实现 | 非skill书 |
| 粉红绸衫 pink_cloth |1000/600| cloth armor1,personality3,female_only | girl T | NPC loadout |
| 蓑衣 raincoat |7000/30| surcoat armor2,personality-1 | farmer/old_farmer T | active农夫2件 |
| 草鞋 sandals |900/10| boots dodge0 | farmer/old_farmer T | active农夫2双 |
| 牛皮盾 shield |7000/340| shield armor5,defense3 | secret_storage→obj版1；动态密道 | 来源可达但可能困住 |
| 绣花小鞋 shoe |900/300| boots armor1,female_only | girl T | NPC loadout |
| 细剑 thin_sword |1400/700| sword D16,EDGED,courage-4 | girl T；`d/latemoon/room/npc/killer.c`也引用该版 | 不作初始赠品 |
| 苍绒剑 whitethorn |15000/2400| sword D63,EDGED | 两目录无Snow acquisition；柳馆主持的是blackthorn | 不是馆主当前武器 |
| 灵芝 agaric |35/4000| FOOD一口30；tonic mana5/max_mana150 | 无Snow获取引用 | eat_tonic缺失 |

`npc/obj/throwing_knife.c`是额外第22文件：THROWING，amount100，base_weight300/base_value80，
D20，flag0；trav_blade携带1 stack，因此每个初始stack重30000。不是100个ItemInstances。
普通COMBINED没有MONEY::value，不能把base_value80自动当8000现金或pawn报价。

**SOURCE FACT**：继承带来的额外行为：`std/equip::setup`给>=3000重量的武器/护具默认dodge
`-weight/3000`（对应prop原值为false时）；`std/armor/{cloth,surcoat,boots,shield}::setup`则
检查`armor_apply/dodge`、weight>3000，不调用父setup。因此linen dodge-1、raincoat/shield -2，
出生cloth恰3000不扣。`std/armor/cloth::init/do_tear`允许cloth material最多撕4次生成bandage，
写teared_count；不能把衣物只当不可变definition。thin_sword courage-4是装备修正，不改base cor。

外部定义是Snow acquisition的一部分，必须同时纳入候选内容范围：

| Item / exact source | W / price/value | Source acquisition | Repeatable / condition | Core hub relevance |
| --- | --- | --- | --- | --- |
| /obj/example/dagger |1000/V50,D4,SECONDARY+EDGED| waiter stock dagger | buy无限new，需finance准入 |50文第一匕首 |
| /obj/example/dumpling |80/V15| waiter stock dumpling |3口，每口food60；首次吃V0，末口销毁 |180 food/15文 |
| /obj/example/chicken_leg |350/V30,D1 hammer| waiter stock chicken leg |4口每40；最后变bone重150保留weapon_prop |160 food，骨头可喂狗 |
| /obj/example/wineskin |700/V20| waiter stock、drunk inventory |15次每water30；alcohol drunk_apply6；可refill但Snow没水源 |付费水分，有drunk副作用 |
| /obj/example/cake |缺文件| waiter relay_say生日触发 |无法证明成功创建；其它地区cake不是替代依据 |**BROKEN，不计免费食物** |
| /obj/drug/hurt_drug |30/V2000| herbalist medicine stock |每次新买；apply受伤且非战斗，消耗整颗 |20点有效kee |
| /obj/drug/snake_drug |base_weiht拼错/V1000| herbalist snake drug stock |amount1；apply蛇毒减1、用量减1 |错误weight有效0，需compat review |
| /obj/money/silver |每两37/base_value100| work每次1；bank兑换/pawn支付 |源头无次数上限但资源/容量有界 |现金权威应为item graph |
| /obj/money/coin |每文1/base_value1| bank/pawn；traveller100,farmer20等 |NPC持有不等于可免费拿 |零钱 |
| /obj/money/gold |每两37/base_value10000| bank兑换；annihir10 |不是fresh赠送 |非起始必要 |
| /obj/cloth |3000，无V，armor1| fresh出生；多NPC装备 |无价值不能pawn；最多tear4条 |免费包扎材料 |
| /obj/bandage |200，无V| CLOTH::do_tear |同一布条blood_soaked<2可用；bandage槽、condition40 |免费伤口护理依赖 |
| /obj/old_book |600/V70，force max10| beggar/scavenger carry |没有送书/买书hook；活NPC搜身被get拒 |战利品，不是无门槛读物 |
| /obj/paper_seal |amount1,W5，无V| temple2个对象槽 |可get；法术封符属未来 |不能当有价钱币 |
| /obj/longsword |7000/V400,D25| annihir/mercenary loadout |非fresh免费来源；当前技术剑不替代竹剑 |高危loot |
| daemon/class/swordsman/blackthorn |15000/V2400,D58| 柳淳风wield |没有免费授剑hook |不同于whitethorn |
| daemon/class/swordsman/silk_cloth |1000/V2500，armor1,dodge6| 柳淳风wear |没有赠衣hook |高端loadout |
| /obj/board/swordsman_b |board，无需物品价值| schoolhall load后BULLETIN_BOARD setup move |非clone货物 |多人留言设施 |

**SOURCE FACT**：ROOM::reset保存对象指针；拿走但对象仍存在的竹剑/盾不会仅因移出room就补一件；
只有原对象被销毁、所跟踪槽不存在才可重建。NPC游走则尝试召回。不能实现每入房免费再发剑。
NPC corpse可继承直接inventory，来源见`chard::make_corpse`；生活循环不要求抢劫NPC。
全mudlib引用检索没有为Snow四种补品或obj/whitethorn找到有效获取链；文件存在≠stock。

## FRESH PLAYER ACCESSIBILITY

**INFERENCE（前提：相应room/NPC能加载，普通门可open，不主动触发战斗）**：
38房中，Inn起点所在静态连通分量36房无需钱/技能/年龄/exp/key/master检查；
这包括普通Inn房间、武馆前后院、school书院、各商店/加工厂。No gate不是no danger：
sroad4疯狗通过F_ATTACK自动攻击，且多名NPC能random_move，不能保证西路永远安全。
其它NPC通常的friendly不是强制no_fight；bank也没有有效和平标记。

| 内容 | 实际gate | Fresh输入结果 | 不能推导的替代 |
| --- | --- | --- | --- |
| 普通Inn房/武馆门/当铺门 | DOOR_CLOSED→open | 能打开，不收费 | 不加名望、钥匙或住宿系统 |
| workplace | gin>=30且sen>=30 |100起步通过，连续3次后各10（不计恢复） | 无busy/cooldown/strength门槛 |
| bamboo_sword | get忙碌/no_get/容量；source剑无no_get |150000容量足够，cloth3000+剑1000 | 不要求入派/任务/偷盗 |
| secret_storage | 任意3次非空且非精确shelf的push；10秒window | 无技能/力气门槛，但up有加载漏洞 | 不提供不存在的保底返回 |
| herbshop1 | 无入口、无柜子动作 | 不可达 | 不因cabinet/wall描述新增密道 |
| 柳淳风收徒 | query_cor/cps均>=20 |30/30通过；招募写family/master/class | 不需先有literate/钱/剑/exp |
| 李火狮 | recognize family_name=封山剑派 |fresh无门派不通过；柳收徒后通过 | 不把整个武馆免费教学开放给所有人 |
| 魏无极 | marks/魏无极（首次给value()>=500） |fresh不通过 | 不将先生的accept_learn=1当成免认可 |
| 商业 | price>=1,can_afford=1 |初始0不通过 | 不自动找零/赠初始钱 |
| book study | direct inventory,raw literate>0及书/skill门槛 |fresh不通过 | 不因书架文字生成book |
| selflearn | 七种基本技能之一且raw>=40 |fresh不通过 | 不用它制造第一技能 |
| source revive | death域/ghost/reincarnate→REVIVE_ROOM |非城镇主动服务 | 不修改已批准native death policy |

**CURRENT NATIVE FACT**：实际可玩仍限NGE6路线；“source reachable”绝不表示这些32个deferred房现已native。

## FIRST-HOUR SOURCE LOOP

不是保证一小时通关的教程，也没有source规定分钟配额。下列是**INFERENCE**，由各条SOURCE FACT组合：

```text
Inn -> Square -> mstreet1 -> mstreet2 -> workplace
    work [gin/sen各-30] -> 1 silver（无exp/potential奖励）
    重复/等待恢复 -> 持银 -> bank.convert -> 可用零钱 -> Inn购买食物/酒/匕首

mstreet1 -> school1 -> open east -> school2 -> weapon_storage -> get bamboo sword
school2 -> schoolhall -> apprentice 柳淳风 -> learn基本技/literate
                               -> 同派李火狮 -> unarmed / liuh-ken / dodge
                            [资源/潜能/经验上限限制，不是无限训练]
```

注意下面ECONOMY的零钱缺陷：**一银全换铜并不保证buy成功**。源码可绕行的例子是工作两次，
只兑换其中1银，保留1银+100铜，然后买50文匕首/15文包子/20文酒袋。
不把“绕过bug需要留银”宣传成合理教学设计；native行为需owner review。

| 起始问题 | Source-backed答案 |
| --- | --- |
|1 第一笔钱|workplace工作1次1银；另一可行但不可无限刷的来源是免费竹剑拿去hockshop sell得80铜 |
|2 无门槛工作?|无钱/武器/skill/师门/exp门槛，但有gin/sen各30门槛；不是绝对无条件 |
|3 工作奖励|只有1 silver；不增加exp、potential、skill或属性 |
|4–5 第一武器|免费get竹剑；或有合适钱后waiter匕首50、smith铁锤300、鸡腿30也是hammer武器 |
|6–7 第一技能/谁教|柳淳风免费收徒后可教literate等；李火狮同派三技能；魏无极先500文认可 |
|8 learn/practice资源|learn耗gin、成功耗potential并受martial exp门槛；practice需已学基本+special与mapping及各skill资源 |
|9 food/water|Inn包子/鸡腿/红酒；没有Snow水源flag，不能在Inn免费fill |
|10 没钱能补给?|本Snow集合没有成功闭合的免费食物/饮水路径；生日蛋糕文件缺失。布衣可免费tear包扎，不是food |
|11 医药|herbalist卖两药；衣物tear→bandage是另一免费外伤护理链；描述施药不等于实装 |
|12 战斗是否前置|赚钱/取第一剑/初学不要求战斗；martial learn在raw3时3³/10=2>exp0受限，继续成长需经验来源。工作/买卖不产exp，不能承诺纯工作无限练武 |
|13 新手引导NPC?|waiter迎客、sign/inquiry介绍局部服务；**NO SOURCE EVIDENCE**存在统筹first-hour的tutorial NPC |
|14 特定顺序?|**NO SOURCE EVIDENCE**要求“先工作再拜师再战斗”；存在局部hard gates，不是线性任务链 |

习武较快提升不是source保证，原版有真实限制；S1不重新平衡战斗或补送经验。
书院付费literacy不是必要前置：免费柳师也有literate60，须把两路径并列。

## INN SERVICES

**SOURCE FACT**：`inn.c`只放traveller2、waiter1，无住宿交易、sleep/rest/heal/storage函数。
`inn_2f`的名望文字没有检查；n/e/w_room仅门+房间。`guestroom`在武馆，不能并成旅馆豪华房。
`waiter::init/greeting`一秒后同场检查+随机迎客；`relay_say`由`cmds/std/say::main`全室relay触发：
msg含ES2/es2与生日快乐，且Player direct inventory无cake则new `/obj/example/cake`。
**SOURCE FACT：该文件缺失**，不能用其它城镇cake替代、不能据此承诺免费回血/食物。
`F_VENDOR`定义无限按需clone的四项stock；`buy.c`支付先于`compelete_trade`，move返回没检查。
traveller没有ask/inquiry、任务或教学，只是游走/战斗/现金衣物population。
`valid_startroom`是MUD login起点保存能力；没有“在Inn才能存档”的source rule，native Save不改。

## WORKPLACE

**SOURCE FACT**：`workplace.c`继承ROOM、包含dbase/room头；sign称老板但没有雇主NPC对象。
唯一动作`init→do_work`，没有参数解析需求：

1. `this_player()`；若gin<30 **或** sen<30则拒绝，无mutation。
2. 输出劳动结束文字，`receive_damage("sen",30)`，然后`receive_damage("gin",30)`。
3. `new(SILVER_OB)`→set_amount(1)→move(Player)；没有检查move成功，return1。

等于30允许，结果0不是昏迷（char阈值<0）；effective/maximum不变。没有kee消费；
无random、计件物品、roll、属性技能门槛、延迟、busy/cooldown、工时、exp奖励或先付费。
no_fight由room一般战斗规则处理，do_work自身不检查fighting/busy/ghost；不能擅自补游戏规则。
单次command无多人共享奖励库；ROOM人口reset与work收入无关。满负重时可能已扣资源但钱move失败，
需在后续窄事务里明确preserve ordered result或经批准修正，不假装LPC原子化。

**INFERENCE**：它是此集合最直接、可重复、无战斗的第一收入来源，故推荐；“最自然”是按
门槛/路线/依赖作出的判断，不是作者明确的新手引导指令。fresh100可立即工作3次，各余10。
**SOURCE FACT**：`damage::heal_up`每次先扣正food/water各1；扣后water<1的Player不恢复主资源；
con30内资源0时gin/kee/sen每次+10至effective，达到后effective不足才+1；food不足仅挡后续内资源恢复。
不加饥渴直接伤害。`std/char::heart_beat`以5+random10及post-decrement tick调度，busy提前return，
condition本次flags可阻止整个heal_up。不能把纯恢复计算假称已有native日常tick。

## SCHOOL / TRAINING

**SOURCE FACT**：school=独立书院；school1/2/hall/storage/yards=淳风武馆。
人口/拓扑见完整表。schoolhall `CLASS_D("swordsman")+"/master"`是柳淳风：
人类男44、str27/cor30/cps27/int24、exp1000000、score200000、force/max1500 factor3；
raw unarmed40/parry120/dodge80/sword150/force40/literate60/fonxanforce60/fonxansword150/
liuh-ken60/chaos-steps100/spider-array85；map unarmed→liuh-ken,sword/parry→fonxansword,dodge→chaos-steps。
**没有force→fonxanforce的map_skill调用**，不能替NPC脑补mapping。衣物/武器见item表。

`attempt_apprentice`只拒有效cor<20或cps<20，然后command recruit；
`cmds/std/apprentice.c→recruit.c→feature/apprentice.c::recruit_apprentice`写master id/name、
family/generation14、enter_time、title/privs；NPCoverride再写class=swordsman。
普通用户recruit的age/exp限制不适用于NPC馆主；首次走recruit路径不误记betrayer。
`F_MASTER::prevent_learn`对betrayer按teacher_raw-betrayer*20限制；非嫡传限自身raw*3。
李火狮没有自己的family mapping，而用recognize_apprentice判断学生封山剑派；不是系统默认同派放行。
柳绘心的family是**封山剑派北宗**，不等于封山剑派；无recognize教学开放、无收徒override。

### 学习规则依赖

| Framework | Source semantics | Fresh意义 / native现状 |
| --- | --- | --- |
| learn | teacher当前同处/character/awake→关系/recognize→raw/prevent→valid_learn→gin成本→potential等；gin_cost=150/teacher.int+150/student.int，raw0翻倍；teacher.sen严格>cost/5+1、student.gin严格>cost；成功spent+1并improve随机量 | 柳int24，freshint30：初次22gin，随后11；魏int26初次20/随后10。已有LearnService，不新造 |
| martial exp | my_raw³/10 > combat_exp则不进步但仍损gin；literate type knowledge免此门槛 | exp0可进raw1–3，raw3起不能再用learn提高martial；不同技能valid_learn另限 |
| progression | feature/skill::improve_skill：learned分散惩罚、零量变1、strict > (raw+1)²、每call至多1级/learned归0、callback |复用CharacterSkillState及authored improvement registry |
| practice | 必须enable的special+basic均>=1；valid_learn，skill.practice_skill成功后improve(basic/5+1)，basic<=special时Player weak |不是从0学第一招；现有PracticeService但仅有限authored policies |
| study | direct持书、raw literate非0；exp_required、skill.valid_learn；cost=sen_cost+sen_cost*(difficulty-int)/20；sen>=cost；raw>max才挡；improve(literate/5+1) |书表有效但无免费获取链；不花potential，当前缺StudyService/书状态内容接线 |
| selflearn |仅七种basic、raw>=40；gin300/int、potential和raw³/10经验限制 |不是fresh入口；已有SelfLearningService |
| exercise |已mapped force、kee_cost>=10及gin/sen>=70%；增force=kee_cost*(raw force+con)/300；strict overflow增max受技能上限约束 |已有Cultivation规则，尚无完整城镇训练入口；不能初始发max_force50 |

`daemon/skill/liuh-ken::valid_learn`要求两手无weapon；practice要求kee>=30并扣30，无内力消费。
`fonxansword`要求max_force>=50、force映射fonxanforce、主手skill_type=sword；practice扣kee30/force3。
`chaos-steps`要求max_force>=50，practice同扣；`fonxanforce::practice_skill`始终拒绝，需learn/exert。
`spider-array::form_array`要求8名team成员，是以后团队体系，不因馆主会该技能就纳入hub。

### 魏无极与ask缺陷

`teacher::accept_object`首次`ob->value()>=500`写永久`marks/魏无极=1`；recognize依该mark；
随后继续收赠但不自动上课。普通ITEM的`query("value")`不是MONEY::value，不能等价任意V500商品付学费。
`teacher.c`把follow_player实现注释却仍创建闭包；仅声明不能证明driver接受，是加载风险。
`teacher1.c`有实现但无Snow spawn，不能自动替换。
`ask.c`查询`ob->query("inquiry/"+topic)`，`dbase::query`通过evaluate传**this_object即NPC**，不是asker。
因此guard::ask_me的参数exp门槛实际先读guard自身20000；herbalist::heal_me通常读自身满eff/max。
数组里string照输出、function分支空，不执行teacher数组中的follow_player；没有设置last_asker。
这是实质source调用链问题，不能将每个inquiry声明当作正确的玩家任务脚本。

## WEAPON ACQUISITION

**SOURCE FACT**：免费竹剑是最少前置的source-valid剑，不是赠送/借用：
Inn→Square→mstreet1→school1→open E→school2→N weapon_storage→get sword。
guard没有valid_leave拦截，get只检busy/物体/no_get/重量；剑无ownership/family/处罚字段。
拿走与wield是两个动作，装备必须direct inventory；`feature/move`移物先unequip再检查目的地/容量，
失败可能留下“仍在原处但已脱装备”；后续 commerce/pawn不能绕过已迁移的ordered transition。
smith卖**npc/obj/hammer**300文，尽管定义V3；没有卖blade/sword，也没有材料收集/锻造。
waiter dagger50和可当hammer的鸡腿30均是其它合法购买路径。secret盾是护具，不当成第一剑。
NPC刀、细剑、铁斧、飞刀、玄苏剑没有借/买/授予函数，只能分析loot等路径，不能称正常fresh可获得。

## ECONOMY

**SOURCE FACT**：MONEY继承COMBINED，coin/silver/gold按1/100/10000计值，重量1/37/37；
一个对象+amount，living direct inventory按base_name合并，incoming对象保留。`set_amount(0)`
仅预约1秒销毁，**不先将amount改0**；本slice不重做已闭合的Combined/ItemLifecycle兼容政策。

| Economic edge | 产生/消耗 | 实现/风险 |
| --- | --- | --- |
| work |产生1silver|扣sen/gin后new/move；无余额池 |
| vendor/Smith buy |销毁/减少Player钱，创建商品|buy→can_afford→pay_money→compelete_trade（拼法原样）；无卖家余额/stock减少/自动找零 |
| bank convert |币种转换，总价值按整数比值|无利息/费率；高面额整除round-down；deposit空 |
| pawn/sell |创建银+铜，销毁商品|60%/80%V，payout最低1；不是保存抵押物 |
| teacher fee |销毁给NPC的money对象，写mark|give先accept_object后按value销毁；非银行账户 |
| donations / hire |money sink，改状态/雇佣计时|keeper / worker / mercenary；后两者没Snow spawn |
| NPC loot |已有spawn money进入corpse|非杀怪额外自动爆钱；reset可能补NPC，非永久一次内容 |
| herbs/food |花钱买后消费item|消耗状态需持久化，不将definition V当immutable instance价值 |

### 不能忽略的finance缺陷

`feature/finance.c::can_afford/pay_money`用单参数present；仓库`doc/efuns/present`明确先搜
当前对象inventory，再搜当前environment的inventory，因此可误用地面钱，且不是递归wallet。
`can_afford`没有silver时，只要price%10000非0就返回2，**即使铜钱足够**。
例如只有100coin买50文匕首被当成不能找零；这不是推测。silver存在而coin不存在时，
中间组合面额检查又被跳过。`pay_money`可能晚抛Not enough money，且之前已消费部分币。
先支付再create/move商品也不是全交易原子；满负重可造成扣钱却没到手。

**INFERENCE**：钱应继续是现有item graph里的denominated stacks；不必新增第二个Player wallet余额。
窄的MoneyPayment/Exchange/Commerce服务可在既有Inventory+Combined+Lifecycle上编排，
但是否修正上述scope/找零/失败损失属于行为decision，不在S1自动决定。
“钱庄依赖account因此整个钱庄不移植”不成立；兑换是本地游戏规则，deposit根本未实装。

## FOOD / DRINK

**SOURCE FACT**：`feature/food::do_eat`先检查id、ghost、busy、剩余非0、当前food<容量；
若drink_func为truthy还检查water，随后直接加food_supply（可能越过cap，不post-clamp），
可选加water_supply；战斗busy2；V设0、remaining减1，末口调用finish_eat否则destruct。
eat_func调用已注释。Snow四补品声称tonic的mapping没有有效执行函数。
`feature/liquid::do_drink`同类ghost/busy/cap precheck，remaining先-1、water+30，战斗busy2；
liquid/drink_func truthy时query可能已执行闭包，否则按type alcohol累计drunk。
`fill`要求当前room resource/water，写清水/remaining=max_liquid/drink_func0；Snow38房均未设置水源。
外部Old Pine河岸/瀑布有水源，但不作为S1无风险fresh Snow补给承诺。

**INFERENCE**：消费部分必须保留amount/剩余口数/液体类型/当前value/骨头变体，不能只删除整item。
不增加“普通房间免费喝水”或“睡旅馆满血”。生日cake缺引用，免费食物结论为
**NO SOURCE EVIDENCE（在本Snow实际可用链中）**，不是断言整个ES2没有免费食物。

## HERBS / MEDICINE

**SOURCE FACT**：herbalist只有medicine=2000、snake drug=1000两项stock。没有medicine/herb skill gate。
heal_me只按eff_kee/max_kee比例>=100或>=95回复文字，<95无return实现且不改任何资源；
经ask参数链还通常看到自己，不是患者。不能扩写成免费治疗。
hurt_drug apply无物品参数匹配/忙碌检查；非战斗且diff=max_kee-eff_kee非0；
value=min(20,diff)，直接eff_kee+=value，消耗物品；不改current kee（负diff异常也不能静默更正）。
snake_drug apply无战斗阻止，condition snake_poison>0才更新为old-1，再add_amount(-1)；
不是解掉全部中毒。`base_weiht`拼错使weight走0，zero amount延迟销毁风险沿用Combined分析。
药物repeatability是vendor无限new，非同颗无限使用。

免费外伤护理来自 **已有布衣**：`std/armor/cloth::do_tear`→`obj/bandage::do_bandage`，
非战斗/伤口存在/没占bandage槽、blood_soaked<2，move目标后`::wear`、condition bandaged40、blood_soaked+1。
armor modifiers attack/defense/unarmed各-10；`daemon/condition/bandaged::update_condition`先cure kee3，
减duration后依据旧duration判断继续，因此旧0那次仍先cure。不能把它改成current heal。
`remove`先父remove（可能已unequip）再判断equipped，清condition有顺序缺陷；autoload另强制blood_soaked3。
已有Condition domain不等于现有Player有bandage item interaction；需要窄装备/消费状态持久化。

## BANK

**SOURCE FACT / executable source semantics**：BANK解析数量/from/to；只允许>=1且余额足够，
读取base_value，不足高币值时amount向下凑倍数；目标未持有时先new→move→set_amount，
已有时先add_amount；最后扣from。没有手续费、deposit account或跨玩家转账。
**Source bug / ambiguity**：忽略move失败；同币转换未禁止；zero amount销毁延时；from可通过alias选非money
但base_value必须非0；auto默认只有gold→silver、silver→coin。**deposit是空函数**。
**Infrastructure-only**：无账户实现可迁移，不从“钱庄”名字推导在线存款。
**INFERENCE**：应提取兑换服务，不创建BankAccount；sign也只宣称兑换。

## HOCKSHOP

**SOURCE FACT / executable**：value/pawn/sell只搜索Player direct inventory；拒money_id，
取`query("value")`而非value()。pawn60%、sell80%，整数除法；pay_player最低1，按银+铜创建，随后destruct原物。
普通no_drop/equipped并未在command检查；实际销毁还会走装备remove。不能直接用UI删图标代替Lifecycle。
**Broken/incomplete**：sign/value文字说当票与retrieve，但没有当票对象创建、存储抵押物或retrieve action；
hockshop2没有拍卖/柜子数据；不因文字实现赎回。master spawn是注释，不是缺少必须店主。
`value_string`value<1只赋1而没有return，是另一格式化漏洞；不是经济新规则。
**INFERENCE**：可分离sell；pawn若开放必须明确仅60%卖断或等待修复decision，不伪装可赎回。

## POST OFFICE

**SOURCE FACT**：post_officer send_mail/receive_mail检查startroom后给MAILBOX_OB；mailbox::init绑定
Player id，保存`data/mail/<首字母>/<id>`，FINGER_D获取account并写new_mail，find_player决定在线通知/释放。
UI编辑由input_to/F_EDIT；room valid_leave销毁临时信箱。sign“每封10文/赔偿”的收费规则没有在该链实现。
**MULTIPLAYER / ACCOUNT INFRASTRUCTURE — DEFER / DO NOT PORT AS-IS**。
可保留建筑/历史说明作为以后内容，不创建空mail系统、不改造为未经source支持的快递任务。

## TEMPLE / REVIVE DEPENDENCY

**SOURCE FACT**：no_fight truthy字符串"1"、paper_seal两槽、keeper、donation箱。
keeper接受有value()对象：val>100、bellicosity>0且random(val/10)>kar时减random(kar)+val/1000；
不clamp到0，没有heal/revive。普通ITEM无value方法不能按商品V替代钱币。
donation箱只有insert_object hook，`put::do_put→move`根本不调用它；全mudlib检索也没通用调用点。
故把钱put进箱能形成containment，不证明捐款销毁/消业；箱no_get不阻止取其内容，不能把它当安全money sink。

`include/login.h`：REVIVE_ROOM=/d/snow/temple，DEATH_ROOM=/d/death/gate。
`damage::die`ghost=1、主资源current/effective1、move gate、调用start_death；gate只有create、
没有start_death实现。其spawn white gargoyle的init/call_out death_stage另驱动五段对白，
reincarnate清ghost/恢复effective到max、move REVIVE_ROOM（不会同时把current全部回满）。
black gargoyle同类路径但非ghost会攻击。缺失start_death/driver absent-method处理仍是source quality问题，
不能把“寺庙等于免费复活按钮”作为现有API。
**OWNER DECISION REQUIRED（后续若恢复legacy death）**：是否把已批准native death路径改成阴间→庙；
本S1及推荐S2不改，Temple的地图可独立于复活机制。

## MUD INFRASTRUCTURE FILTER

| Feature | Classification | Native处理建议 |
| --- | --- | --- |
| work、get、货币兑换、商品支付、消费、教学、装备、condition效果 | GAMEPLAY SEMANTIC | typed规则+existing state+窄service入口 |
| ROOM reset clone跟踪、NPC回家、动态密道计时 | GAMEPLAY SEMANTIC + runtime infrastructure混合 | 保留补充/状态意图，调度另设计；不模拟心跳/每入房reset |
| parser present/id、add_action、command、call_other | MUD runtime infrastructure | semantic interaction/stable IDs，不做命令字符串dispatch框架 |
| mailbox/new_mail/finger/account、board文章、worker tell/order与proposer真实Player婚配 | MULTIPLAYER / ACCOUNT INFRASTRUCTURE | defer，不端到端照搬；雇佣玩法需另立scope |
| wizard接待/内区、wizardp例外、euid/security | ADMIN / WIZARD INFRASTRUCTURE | 不进入普通Player产品路径 |
| valid_startroom、联机idle/reconnect、user save_object/autoload | ACCOUNT/runtime persistence | native Host/Save权威已替代，继续手动Save而非旅馆绑定 |
| cake/eat_tonic/teacher closure、密室首次无回程、finance、捐箱hook | AMBIGUOUS / source defects | 显式review，不把bug修复冒称原版 |
| all_inventory population、NPC关系/掉落 | GAMEPLAY SEMANTIC with MUD embodiment | native实例/ledger/interaction；不复制room对象模型 |

## CURRENT NATIVE CAPABILITIES

**CURRENT NATIVE FACT**：本次直接检查类字段/调用处，而非只按文件名归类。
以下native路径以`game/`为根；不是全量旧phase再审计。

| Authority | 当前可复用实现/证据 | Snow接入不能假定的能力 |
| --- | --- | --- |
| Player birth/body | `core/characters/new_player_initialization_policy.gd::create`、`application/new_game/new_player_runtime_composition.gd`、独立PlayerBodyFacts | 不为工作重置Player、不再发cloth |
| Character resources/skills | `core/characters/character_state.gd`含三资源/recovery/conditions/skills/progression/family/apprenticeship/exact equipment | base attributes与derived/equipment要分开 |
| Inventory/Equipment/Armor | `core/inventory/inventory_state.gd`、`inventory_transfer_service.gd`；`core/equipment/equipment_state.gd`、`core/armor/armor_state.gd`；native restore exact refs | 没有通用commerce、give/tear/eat交互；不能新建第二装备对 |
| Item definitions/stacks | `core/items/item_definition.gd`仅ID/source；`combined/combined_stack_service.gd`有register/set/add/split/transfer_and_merge，`currency_definition.gd`已value_for_amount | 没有生产Snow银铜stock/price/food/液体定义；wallet不是必要新authority |
| NPC identity/body/loadout | `core/npcs/npc_definition.gd`、`npc_character_state_factory.gd`、`npc_runtime_state.gd`已有Human/Beast、base overrides、raw skills、loadout/armor | Attitude仅PEACEFUL/AGGRESSIVE；raw skill定义无mapping，不能直接复原全Snow友善/豪侠/教学/高阶动作 |
| Interaction/world embodiment | `runtime/world/world_interaction_target.gd`有character/landmark/item stable target；`world_character_body_2d.gd`与既有Inspect/Loot/Equipment适配 | 没有NPC vendor/trainer/say/ask服务UI，不能塞到Combat handler |
| CXR/combat/lifecycle | `runtime/world/oldpine_world_session_controller.gd`给CombatEncounterCoordinator真实bindings及world gate；已有death/corpse链 | 高级spells/perform/exert、自由NPC行为/师徒不自动具备 |
| Recovery | `core/characters/character_recovery.gd::apply_tick`；RecoverySkillLevelsAdapter及condition结果边界 | 对`game/runtime`/`game/application`检索无CharacterRecovery调用；Session::_process仅推进encounter，不是城镇日常恢复 |
| Learning | `core/learning/learn_service.gd::learn`、TeachingContext、teacher policies；`core/training/practice_service.gd/self_learning_service.gd`；cultivation闭合规则 | 无Snow teacher实例/收费mark/收徒interaction；PracticePolicies仅fall-steps/fonxanforce厂方法，不能假定柳家拳已接 |
| Relationships | `core/relationships/family_state.gd`、`apprenticeship_state.gd`存family/generation/master/name/betrayer |不是完整recruit/认可/师门系统，class/title/enter_time/mark需审视 |
| Resident maps/handoff | `runtime/world/world_resident_map_coordinator.gd`、`world_resident_map_controller.gd`与SnowWorldDefinitions，Session共享player+inventory+allocator | 新interior可复用；不建每room一个独立Session |
| Save + off-map | `core/persistence/game_save_snapshot.gd`、`game_save_value_types.gd`、`runtime/persistence/oldpine_world_save_capture.gd/oldpine_world_restore_composition.gd` |严格按OldPineSpawnDefinitions.all_spawns完整ledger匹配；额外/缺槽失败，NPC不能任意跨map恢复 |
| Item persistence | `NativeItemStateSnapshot`既有item/combined/equipment/armor四组record；`native_item_definition_projections.gd`窄内容输入；production OldPineNativeItemDefinitionProjections |当前definitions白名单是OldPine+source cloth/corpse，不能只在runtime创建新货币而不加restore投影 |
| Allocation/RNG | Session持有SessionItemIdAllocator和combat/npc_initialization/world_interaction三源；schema2保存续点 | 新工作无RNG；商店newID用同一allocator；NPC随机必须按既有流隔离，不能Godot global RNG |
| Public Save boundary | `runtime/persistence/source_entry_save_repository.gd`仅SOURCE_ENTRY_V1；Host唯一current Session |不重新开放pre-cutover旧档，不改settings持久化 |

## MISSING PRIMITIVES

**INFERENCE：只有本Snow源真实用到且当前缺的项目才列在这里。**

| Snow Feature | Required Existing Native System | Missing Native System | Blocking? |
| --- | --- | --- | --- |
| Work reward | CharacterState/receive_damage,Inventory,Combined,allocator/lifecycle | 窄work intent/result+银币生产definition/发放编排 | S2 yes |
| Money exchange/payment | CurrencyDefinition/stack graph |币种内容、denomination quote/扣款/兑换策略、source异常裁决 |buy yes；收入本身no |
| Vendor buy |item definitions/index/restore projections,transfer |稳定stock/price报价、支付→交付结果、服务交互 |Inn买卖yes |
| Food/drink |resources/body capacity/conditions/ItemLifecycle |typed consumable与liquid实例状态、消费/finish变体、生产接线 |完整补给yes |
| Daily recovery |CharacterRecovery+raw skill adapter+condition cycle |world-active恢复机会调度、pause/encounter/mobile生命周期边界 |重复work/learn闭环yes |
| NPC population |NpcDefinition/factory/body/spawn/ledger |Snow authored facts、raw mapping和attitude差异、服务capability；允许当前revision的ledger整合 |各NPC slice yes，非全新NPCSystem |
| Trainer |LearnService/TeachingContext/Family/Apprenticeship |NPC offer/proximity、收费认可typed mark、收徒规则/反馈 |教学yes |
| Practice/cultivation入口 |既有规则/skills/effects/RNG |authored柳家拳等policy+玩家训练交互 |0级教学no；后续yes |
| Study/books |skills/improvement/resource |StudyService+typed book definition/获取路径 |初学not necessary |
| Pawn |Inventory/Lifecycle/Combined |sell估价/支付；pawn缺失赎回须owner选择 |core钱源no |
| Bank account |无有效source账户实现 |**不列缺失primitive**，不凭deposit空函数造账户 |no |
| Medicine/bandage |Condition/Armor/Resource |物品消费效果/tear与blood state/装备同步 |伤口护理yes，赚钱no |
| Doors/secret |WorldLocation/physical map/handoff |窄door/passage state+interaction；计时/保存语义 |work no，武馆/密室按所选物理体现 |
| Scene/interior handoff |既有resident coordinator |新geometry/zone/spawn配置，不缺通用handoff引擎 |内容实施时yes |
| Save evolution |现有schema2及native item snapshot |特定新增字段/definition/ledger规则覆盖 |变化对应slice必须完成 |

不需要generic quest engine、ECS、万能dialogue graph、service locator、generic property bag、LPC VM。
不创建另一个Inventory持久化model或把权威现金同时放wallet与stack。新字段应该是窄typed状态。

## PERSISTENCE IMPACT

**CURRENT NATIVE FACT**：schema2已存三资源、内资源/food/water、skills/progression、family/master、
NPC ledger及各map位置、corpse、item graph、allocator与三RNG。没有food口数、liquid、teacher mark、
tear/blood计数、dynamic passage或银行账户字段。

| 候选内容 | 新持久状态 / 风险 | 所需边界 |
| --- | --- | --- |
| 扩街/小室静态geometry |geometry本身无保存字段，但新增zone/map/合法位置需restore支持 | WorldLocation合法集合/安全点；不把zone重命名当纯美术 |
| Work |无source cooldown/busy状态；改变既有gin/sen + 钱item |same item snapshot/allocator；move失败有无收入必须反映 |
| Static vendor stock |source无限stock，无需存库存余额；商品实例必须存 |stock声明可静态；购入ID/value/消费变体需严谨 |
| NPC population |新stable spawn slots、age随机、loadout和死亡/离图状态 |现restore exact OldPine ledger必须扩展；保存时不“补齐未见NPC” |
| Food/liquid |remaining、type/value变动、骨头变体；wine empty仍物品 |现NativeItemStateSnapshot无这些字段，不可丢失后满瓶restore |
| Daily recovery |资源已存；scheduler余时/condition机会是否续接待决定 |不能离线补tick或读档免费刷新 |
| Learn/recruit |skills/progression/family/master已有；teacher付费mark、class/title部分语义额外 |不保存Node/Teacher object；有mark才认可 |
| Book study |book skill配置静态，skills/sen动态已存 |定义白名单+study流程，无需把技能表复制进item实例 |
| Pawn/sell/exchange |被销毁ID和新币、变化amount已受item authority支配 |不得保存仍已销毁的equipped refs；不虚构抵押账本 |
| Bandage / secret |tear4上限、blood_soaked、bandage关联；passage open计时/trigger |只在该slice新增typed续点；不能用空Dictionary逃避schema契约 |
| Bank/mail |deposit没实现；mail为account文件 |本milestone不新增账户/mail schema |

## WORLD CONTENT REVISION IMPACT

**CURRENT NATIVE FACT**：`world_content_revision.gd`只有LEGACY_OLDPINE_V1与SOURCE_ENTRY_V1；
public只接受后者。`oldpine_world_restore_composition::_restore_npc_ledger`逐个旧spawn点要求记录存在，
并要求saved map等于spawn.map、最终数量相等；不能新增SnowNPC后静默重解释旧save。
`OldPineNativeItemDefinitionProjections::create`对可恢复definition设白名单。

- **INFERENCE：可保持同revision候选**：纯文案/显示修正、同zone内部不改变合法位置的美术，
  或用现有字段且不改变旧内容契约的规则接线；必须逐slice证明，不能一概“content不影响save”。
- **INFERENCE：需要新内容revision或明确更改支持边界**：新增spawn slots/新map-zone合法集合、
  变更loadout/定义含义/既存点位、NPC跨map持久化。不能悄悄仍叫SOURCE_ENTRY_V1并硬塞默认NPC。
- 新food/liquid/mark字段是**结构schema问题**，不由revision字符串单独解决；S1不实现schema3。
- **OWNER DECISION REQUIRED**：采用新revision并明确旧source save unsupported，或提供显式有界转换？
  当前早期政策支持前者作为建议；pre-cutover旧档仍UNSUPPORTED，无长期migration平台设计。

## OWNER DECISIONS REQUIRED

只列行为/兼容决策；服务名、Resource与RefCounted选择不需要owner产品裁决。以下均未写入DECISIONS。

### Decision 1 — currency/payment的可执行异常

**Source fact**：present可读地面钱；有足够铜无银仍拒小额buy；支付/交付可能部分失败。
**Why native cannot preserve it literally**：native无隐式环境查询，必须显式选money owner与ordered failure语义；
exact bug-preservation虽可编码，却会成为玩家产品规则，不能悄悄选正常wallet语义。
**Option A**：明确只用Player direct money，修正面额组合判断，保留无自动找零；交付失败策略明确补偿/拒绝。
**Option B**：保留可复现bug及先付后丢失，在typed结果公开legacy失败。
**Recommended option**：A，逐缺陷限定批准，不附带经济平衡改价。阻塞purchase/exchange设计，不阻塞work源读数。

### Decision 2 — time / reset在单机世界的语义

**Source fact**：MUD恢复用随机tick；共享room reset追回NPC/缺槽补物；密道10秒。
**Why native cannot preserve it literally**：现有Session/CXR冻结和app暂停不同于持续多人server，
必须选择玩家暂停、离图、退出时是否推进，不能模拟MUD heartbeat充数。
**Option A**：world-active且允许模拟时推进恢复，暂停/后台/encounter gate下不推进；不补离线时间；
补货/respawn另立有界政策，绝不每次进图刷新。
**Option B**：显式休息/劳动回合推进或真实墙钟离线推进（均属更大redesign）。
**Recommended option**：A；机会间隔/RNG消耗及timer续点在恢复slice形成精确契约，不在S1发明秒数。

### Decision 3 — broken authored内容是否修补

**Source fact**：cake缺文件、teacher未定义closure/ask错传对象、tonic缺函数、捐箱hook不接、
密室首入无up、pawn无赎回、death gate无start_death。
**Why native cannot preserve it literally**：不能以“source-valid service”名义创建原本不存在的成功效果。
**Option A**：先defer坏链，仅迁移已闭合source功能；每条真正需要恢复时另提最小repair证据。
**Option B**：现在批准补全作者可能意图（需单独定义未知效果/费用/出口/任务结果）。
**Recommended option**：A。不是授权恢复所有半成品；尤其不用别区cake或teacher1替换来隐藏问题。

### Decision 4 — Snow population与source save cutoff

**Source fact**：旧SOURCE_ENTRY_V1只有4residents与OldPine固定NPC ledger；新增slots会使旧save不匹配。
**Why native cannot preserve it literally**：不可能既strict exact graph restore又无声明地加入缺失NPC。
**Option A**：内容cutover明确新revision/所需schema，旧source save unsupported，保留文件但不迁移。
**Option B**：批准一套明确旧→新有界转换（补NPC/随机数/位置规则必须定义）。
**Recommended option**：A，符合早期开发政策；正式值/切换时机由实现计划review后确定。S1无V2。

### Decision 5 — future death/revive（不阻塞core收入）

**Source fact**：原版ghost→阴间→城隍庙，与已批准native死亡流程不同。
**Why native cannot preserve it literally**：需要改生命周期、Player/corpse关系、保存与世界内容，不是Temple放置即可。
**Option A**：本milestone维持现有死亡政策、Temple只做已授权城镇内容。
**Option B**：单独批准legacy死亡/复活迁移milestone。
**Recommended option**：A；不在Snow core hub夹带死亡重做。

## PROPOSED IMPLEMENTATION SLICES

**INFERENCE / proposals only**：按source依赖、fresh相关性、可端到端验证、authority复用、保存风险、
阻塞项与scope containment排序。不把所有下列候选自动纳入“必须本milestone完成”。

| Slice | Source scope / why now | Dependencies / player-visible result | Persistence / exit criterion |
| --- | --- | --- | --- |
| S2 — Work income + source currency composition + minimal access | workplace + silver；最少无NPC无随机第一笔钱 |最小mstreet1/2至workplace物理通路，既有角色/stack/allocator；出生无钱→work得1银 |货币restore投影、资源准确扣减、fresh Save/Continue；不送别的物品、不装全部NPC |
| S3 — Currency exchange/payment boundary | BANK::convert、FINANCE、buy框架 |Decision1；使银转零钱与可用支付可验证，非bank账户 |无第二wallet；失败顺序/容量/stack销毁/RNG0及Save精确续接 |
| S4 — Inn vendor + typed food/drink consumption | waiter+真实4stock，不含missing cake |S3、NPC service/必要population ledger、消费状态；真实买/吃/喝 |Decision4；remaining/type/value/骨头保存不复原；NPC强度不近似 |
| S5 — World-active recovery loop | damage::heal_up + char condition边界 |Decision2；接既有Recovery/Condition规则，暂停/后台/战斗冻结清楚 |不需全skill系统重做；余时/恢复保存政策明确；重复work→补给→恢复→work闭环 |
| S6 — School access + source weapon pickup | school1/2/storage，竹剑 |已有Get/Equipment；门/最小guard安全行为需完整source审计，不做密道 |free sword只一份与taken/dead/reset状态，存取装备一致 |
| S7 — Narrow apprenticeship + teaching |柳淳风/李火狮、learn/recruit/指定skills；书院另候选 |复用Learn/Family/Skill；建立免费teacher路径，明确exp0上限；高阶战斗行为未支持不冒充完整NPC |family/master/必要class/title/mark契约；学会→Save→继续；不能近似技能mapping |
| S8 — Smith + basic wound care |smith铁锤；herbalist两药或cloth→bandage分开子slice |commerce/condition/equip已可用；无genericcrafting；snakeweight与bandage拆除缺陷需局部review |物品消费、血染/撕布计数、condition/armor保存；不迁四tonic |
| Later candidates — sell / remaining streets/population / interiors |hockshop sell、门后空间、ambient NPC |不扩成pawn retrieve、mail、fullquest；逐个NPC处理chat/游走/attitude差异 |每次内容变动审核spawn ledger、revision及离图行为 |

S4与S5可在owner review后调整先后，但恢复必须在宣称“可持续工作/训练循环”前闭合；
消费有状态schema依赖，不因为formula简单就忽略。S6免费武器不依赖商业，可在经济slice受
产品决策阻塞时作为替代提案，不能未授权自动切换。书院魏无极不是首个低阻塞teacher：
需要修复source质量+收费mark；武馆柳师有现成family authority可复用，但高阶NPC行为仍非零成本。
主街一次铺满、所有ambient/hostile人口、inn上层、postoffice、herbshop1、秘密机关/北宗/雇佣/婚姻
不优先于可验证core loop。任何生产NPC若尚无法忠实战斗，必须缩scope或明确缺口，不以静态“摊位”冒充完整人物。

## RECOMMENDED NEXT SLICE

**S2 — Work income + source currency composition + minimal access**，仅推荐，未开始。
source basis：`d/snow/workplace.c::do_work` + `obj/money/silver.c` + `std/money.c` +
`std/item/combined.c` + `feature/damage.c` + `feature/move.c`；路线依据square/mstreet1/mstreet2/workplace。
只给一笔劳动所得、同一Inventory/Combined/allocator、same-schema可表达部分的严格continuation。
可检查连续3次与第4次拒绝，但没有日常恢复前不宣称循环完整；不臆造老板NPC、cooldown或exp奖励。
S2批准前需review新增位置/content revision边界及reward move失败政策；不是现在实现。

## SOURCE QUALITY / VERIFICATION LEDGER

以下区分实际执行、未接通与runtime不确定，不自动fix LPC：

| Finding | Classification / evidence | Planning consequence |
| --- | --- | --- |
| school/workplace/inn的地图文字多于实际功能 |描述≠代码；38 create逐行核对 |不添加住宿名望gate/厨房/auction |
| secret首入无回程 |确定的find_object加载依赖 |新native必须经Decision3选择，不自动补门 |
| `ask_me(who)`收到NPC自己 |dbase.evaluate参数+本仓库evaluate文档证明；不是神秘dispatcher |guard门槛不能写成“玩家exp>=20000才能触发”；揭露后全室其他角色照样危险 |
| teacher闭包无实现 |source明显不完整；未跑LPC，不断言具体编译器报错文字 |不能保证该room实际load成功；teacher1不自动顶替 |
| F_MERCENARY/F_UNIQUE |globals/header无定义、无实现；mercy mapping typo chaos-steos |unused不迁，标broken |
| Snow herbs eat_tonic |无定义，FOOD不调用eat_func；closure构造可能报错 |仅记录tonic数据，不声称资源增长 |
| cake |目标文件不存在 |不声称免费生日补给 |
| denotation |insert_object无调用链；不是自动捐赠 |不凭容量型container推断hook |
| finance |present scope、零钱判断、支付顺序确定 |独立decision，非runtime模糊说辞 |
| smith `compelete_trade` |拼写奇怪但与buy调用完全一致，**可执行，不是bug** |保留功能不移植字符串API |
| hammer V3 vs300报价 |确定不同价，不擅自统一 |商店报价与物品残值分开 |
| pawn |确定付钱销毁；redeem是未实现文字 |不实现虚假赎回功能 |
| room reset |活着但拿走的item仍占原slot；NPC回家与item不一样 |不按进入重刷；与native长期ledger需decision |
| Combined zero |延迟destruct且amount仍旧；split不复制可变状态 |复用已审计authority，不引入额外状态丢失 |
| snake_drug |base_weiht确定拼写错误；无base_value |不要把weight100和stack总价当source fact |
| CLOTH dodge |armor_apply检查/armor_prop写入不同key |已知兼容事实，勿借分析修改Armor |
| bandage remove/autoload |remove先unequip再查；autoload血染3却wear |未来消费slice需按现有condition/装备边界专项审查 |
| source death gate |start_death没有实现；gargoyle另一init路径存在 |不声称完整source death server已运行 |
| no_fight / guard doorway |workplace/temple有；guard无通行函数 |不凭“门房”身份造拜师门禁 |

Source coverage（可重现）：完整`d/snow/*.c`38、`npc/*.c`26、`obj/*.c`21均读取；
`npc/obj`22逐个hash与已读同名比对，20相同、old_book差异和throwing_knife额外文件全文读取；keeper.txt读取。
除了正文逐函数引用，向外直接检查：

- `include/{globals,room,weapon,armor,login}.h`；`std/{room,char,item,equip,money,skill}.c`；
  `std/char/{npc,master}.c`；`std/room/{bank,hockshop}.c`；`std/item/combined.c`；
  `std/weapon/{sword,_sword,axe,blade,hammer,dagger,throwing}.c`；`std/armor/{cloth,surcoat,boots,shield}.c`。
- `feature/{vendor,finance,food,liquid,dbase,move,equip,attribute,apprentice,damage}.c`，
  `feature/skill.c::improve_skill`、`feature/attack.c::init/kill_ob`；
  `adm/daemons/{chard,inquiryd}.c`、`adm/daemons/race/{human,beast}.c`、
  `adm/daemons/combatd.c::auto_fight/start_*`、`adm/obj/simul_efun.c`include清单；
  本仓库`doc/efuns/{present,evaluate}`支持runtime语义判定。
- `cmds/std/{buy,give,put,get,open,go,ask,say,learn,study,practice,selflearn,apprentice,recruit,exercise}.c`；
  `daemon/skill/{literate,liuh-ken,fonxansword,fonxanforce,chaos-steps,spider-array}.c`相关学习/练习/阵型函数。
- `daemon/class/swordsman/{master,blackthorn,silk_cloth}.c`；上表外部商品/衣服/书/钱/药/符纸/绷带；
  `std/medicine/powder.c`用于区分药粉而非将snake药归错；`daemon/condition/bandaged.c`；
  `obj/mailbox.c`账户/发信路径、`std/bboard.c`setup/保存路径、`obj/board/swordsman_b.c`。
- 八条外区连接目标；`d/death/gate.c`和`d/death/npc/{wgargoyle,bgargoyle}.c`；
  `d/city/street{8,9,13,17}.c`、`u/cloud/monky.c`证明外部复用。跨全mudlib检索Snow引用、
  herbshop1/secret_storage、eat_tonic、insert_object、F_UNIQUE/F_MERCENARY、resource/water，注释与active引用分开。
  `d/green/npc/{oldman2,shen}.c`用于drunk标志的外部前置/消费者边界，不声称完整Green任务已审计。

S1 verification：只运行branch/base、documentation links、trailing whitespace、`git diff --check`和
changed-path allowlist；不新建测试、不重跑18k suite、不跑desktop/mobile游戏。该豁免只针对docs-only。
game/reference/es2/DECISIONS/build/CI/export/project.godot delta均要求0。
三份变更文档的58个本地链接均有效，尾随空白0，`git diff --check`通过；独立移除注释后重数
room::objects，确认20个本地NPC定义/35槽及外部master1槽。远端基线/提交身份由最终交付报告记录。

## OUT OF SCOPE

没有实现Snow新room/NPC/item、commerce、work、trainer、food/medicine、bank/pawn/mail、dialogue/UI、
schema3、SOURCE_ENTRY_V2、自动存档、respawn/reset引擎、Lake、五蛇、Phase5B4或下个slice。
未改LPC、旧branch/worktree、owner-local Godot AI配置/备份；未开PR、未merge。
本milestone只有S1分析完成；未来实施与最终PR均等待owner明确指令。
