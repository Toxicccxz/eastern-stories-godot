# Status

_One page, overwritten as work progresses. History lives in git and PRs._

以代码、合并记录和 [DECISIONS](../migration/DECISIONS.md) 为准。旧文档（历史 `PHASE_*` 报告、区域笔记的
LPC 对照）里写的「未做」「暂缓」不是任务：要做的只在本页「待制作」和 [ROADMAP](ROADMAP.md) 里。

## 已实现

主场景 `res://scenes/application/application_shell.tscn`（菜单 → 新游戏 / 继续）。全部在 `main` 上。

**区域**（细节见各区域笔记 `docs/migration/<区域>_CONTENT.md`；房间为 ES2 房间文件数）

| 区域 | 入口 | 房间 | 地图 | 体素 |
|---|---|---|---|---|
| 雪亭镇 | 起点（饮风客栈） | 37/38 | 13 | 13 |
| 老松岭 | 雪亭镇山路南 | 41/41 | 9 | 9 |
| 野羊山 | 山坳北 | 15/16 | 3 | 3 |
| 卧龙岗 + 绮云镇 | 雪亭镇街道南 | 43/43 | 18 | 18 |
| 水烟阁 | 青石官道西 | 28/28 | 3 | 3 |
| 青石村 | 山坳东 | 39/39 | 12 | 12 |
| 茅山 | 山路东 | 25/27 | 9 | 9 |
| 晚月庄 | 绮云镇西 | 74/74 | 5 | 5 |
| 泓水南岸 + 山烟寺 | 绮云镇渡口；晚月庄隧道 | 26/26 | 7 | — |
| 乔阴县城 | 泓水南岸东 | 61/62 | 16 | — |
| 天驼关 | 青石官道西南 | 25/27 | 6 | — |
| 玉螺湖村 | 天驼关南 | 26/26 | 7 | — |
| 京师 | 玉螺湖村三叉路口南 | 55/55 | 12 | — |
| 黑松山 | 黄土大道西岔 | 32/37 | 4 | — |
| 鬼门关（阴间） | 死亡 | 9/12 | 3 | — |

ES2 覆盖：536/551 房间，239/286 种 NPC，9/9 可加入的门派，33/36 特殊武学和 22/26 基本武学，84/84
任务目标（计法见 [ROADMAP](ROADMAP.md#region-plan)）。没放的房间和 NPC 是 ES2 里没有入口、整修中或没有
房间放置的，原因记在 ROADMAP 区域表和区域笔记。

**系统**

* **地图**：全部 127 张图由 `tools/maps/layouts/<区域>.json` 经画图工具生成，按比例规范（`tools/maps/standard.json`）；
  每栋可进的楼是自己的图，经门进出。体素视角（DECISIONS「固定俯视体素地图」）已覆盖 8 个区域 72 张图：
  左右两个 45° 视角、昼夜、近侧墙剖开、出口箭头；路和空间按体素视角放宽（「地图尺寸以体素视角为准」）。
  老松岭外景按原文方位排布（「老松林按原文方位排布」）。八个区域按[美术规划](../design/美术规划.md)第 1 节
  各有自己的配色和植被（樱花只在雪亭镇，水烟阁的红枫只在青石官道，雪亭镇旧大石板和青灰墙，绮云镇灰青瓦，青石村
  青灰石板、苔绿崖壁和石板瓦，灵心观白石阶、山绿松林、白墙朱柱灰瓦，晚月庄淡青围墙、梅桂海棠杏、紫琉璃）；
  不同路面相接处互相咬合，不是直线。
  其余区域是 2D 平色地块，往返各用各的镜头。
* **战斗**：半自动遭遇战（逃跑、投降），ES2 招式描写，武器、护甲、内力、特殊招式和法术；同一区块里见人就打的
  一起出手，出手前有提示一拍（「进门一起上」）；楼里进房间就动手（「室内察觉」）；了结 / 放过（「了结 / 放过」）；
  战斗速度 慢 / 标准 / 快。
* **成长**：拜师和 9 个门派，请教 / 练习 / 打坐 / 冥思 / 修行可连续进行，学习上限和拜师条件可预览，内力
  （打坐、加力、运功），历练奖励、落后补偿、分档潜能上限、悬赏榜和木人（「经验节奏」）。
* **世界**：世界时间、房间重置、NPC 游走和对话气泡、回到别的地图时补算它的时间（「别的地图时间补算」）、尸体
  腐烂（「尸体腐烂」）、死亡后的阴间和回阳路、状态（中毒、醉酒、蒙汗药等）、钱币和钱庄、商店、当铺、工作。
* **界面**：带标签页的菜单窗口（角色、武学、背包、任务、声望、百科、系统；声望是占位），手柄，靠近才说话的
  气泡，两栏交互弹窗（开着时世界时间停住，重要选择先确认），任务页的江湖见闻日志，逻辑分辨率 1280×720、窗口 / 无边框全屏 / 全屏、
  界面缩放 100/125/150%、设置「击倒后」。只有简体中文（[LOCALIZATION](LOCALIZATION.md)）。
* **存档**：手动存档 / 继续，原子写入，不支持的文件拒读；世界修订号 `SOURCE_ENTRY_OLDPINE_RELAYOUT_V1`，旧开发
  存档要新游戏（[存档契约](contracts/NATIVE_SAVE_LOAD_CONTRACT.md)）。

## 待试玩

已经做完、等 owner 统一试玩（ROADMAP「After the grey box」第 1 步）的手感和节奏：

* 体素地图：野羊山、老松岭（含路面加宽和按原文方位重排）、卧龙岗 + 绮云镇、水烟阁；雪亭镇、卧龙岗 + 绮云镇、
  老松岭、野羊山放宽后的路（#165）。
* 区域配色：雪亭镇的旧大石板和青灰墙、绮云镇灰青瓦和古槐垂柳竹、水烟阁只在官道有红枫，看颜色能否认出地方；
  各种路面相接处不再是直线。
* 经验节奏：combat_exp 0 → 1001 在模拟路线上约 1.7–1.8 小时（`tests/sim/`）；打坐 max_force 0 → 50 在 con 30
  约 24 分钟；朱鸿雪 60 秒的任务限时在要走路的地图上是否来得及。
* 进门一起上的提示一拍（0.5 秒）、了结 / 放过、连续修炼的总结、尸体腐烂的时长、别的地图补算回来时的样子。
* 雪亭镇室内的生活气息（磨损、旧墙、挂件、桌面、角落杂物；杂物多少和脏旧程度在 `room_life.json` 里调）。
* 青石村体素地图（12 张）：石板路和车辙、石屋石板瓦、大榕树、采石场、三面环山；山路、锁链木门、八卦与大石门；
  迷阵八间各自的天色、地面和天气（雾浓淡、闪电、火光）；村里各屋的生活气息；雪亭镇山坳东端的过渡。
* 灵心观体素地图（9 张）：重画的山道（白石阶、转角平台、两侧高松、石灯、山下的雪亭镇、远峰白楼）、山门；广场的石狮、
  龙纹石柱和大香炉，大殿的真武金身、鲜花素果和圆形拱门，回廊朱柱，天井的井和花木，后殿的张天师画像、宝剑和牌位，
  练功房、厢房、藏经楼上下层；雪亭镇山路北端的过渡。
* 晚月庄体素地图（5 张）：庄外鹅卵石路和林子、淡青围墙拱门「晚月庄」、朱红大门两串灯笼；前庭、大厅紫檀雕案与屏风、
  梅花后院、长廊和石壁画、金灯架宫灯的夹道、仪门、饭厅膳房大圆桌、厨房、书房厢房、后厅舞厅、密室八卦与『舞』、
  更衣室和小花池的凤凰神像；二楼佛堂的区冥、天龙、凤凰和琉璃鹤照壁、回廊和观景台；湘园花石子路、月洞门翠嶂、
  海棠垂柳、假山曲洞芭蕉、桂花园、三座桥和紫琉璃沁芳亭、稻香榭茅屋杏花、竹林后门；山路杂草峭壁、隧道口、竹林；
  绮云镇西口的过渡。

## 待制作

室内生活气息 B（绮云镇、卧龙岗、水烟阁楼里）和 C（野羊山小土地庙、老松寨聚义厅）。之后按 [ROADMAP](ROADMAP.md)
的顺序；下一个包是**泓水南岸与山烟寺的体素地图**（先照「路和空间」放宽）。之后依次是其余六个
区域的体素、雪亭镇建筑立面细化、ROADMAP「After the grey box」第 1 步的试玩清单和 owner 的完整试玩。

## 待决定

一项等 owner 完整试玩后再定：A2 的任务限时（见「待试玩」）。规则（owner，2026-10-08）：PR 合并时 owner 没有
回答的问题，按 PR 里的推荐方案生效，在 DECISIONS 里标「默认」，owner 随时可以否决（「积压问题的处理」）。

## Known issues

* A failed attack chain ends the fight with 战斗出错，已中止。 (development builds log why); the cause
  still has to be fixed in the content or rule that tripped it.
* Beasts cannot be asked to spar (ES2's `fight` on a beast is a one-sided kill); attack them.
* 刘安禄's 刘老三/血手刘三 are not listed until his reveal is ported. NPCs never flee a losing fight
  (`wimpy`) and do not follow who flees (`pursuer`). Nothing can be put into a corpse.
* On the player's own map a wanderer moves only where the player is (ES2's heart beat); other maps are
  caught up when the player comes back.
* Conditions do not tick in a fight (owner) nor while the player lies unconscious.
* There is no single 经典模式 switch yet: each knob keeps ES2's value as its classic value in the data
  (DECISIONS「产品定位」).
* A zone that merges several rooms (10 of them) shows only its first room's text.
* 绮云镇: 熟牛肉 is not in the game (nobody sells it in ES2); a carried 布袋 is not opened.
* 乔阴: only one 风泉剑灵 stands at a time (骆云舟 killed again while it stands keeps his sword); the
  采药老者's growth lasts only as long as he does (his save file is not ported).
* 22 classes keep `OldPine*` names (persistence, world runtime, the loot panel) and the session scene is still
  `scenes/world/oldpine/oldpine_world_session.tscn`, although they cover every map; pre-B2 Old Pine
  suites drive combat through a test-only cadence (`historical_world_combat_fixture.gd`). The legacy
  technical fixture (`CombatSliceContentProfile`, demo factory) keeps its own copy of the long sword's facts.
* Log lines written before a language switch stay in the old language, as do a dead zombie's name on
  its corpse and name labels made before the switch.
* Room labels and NPC names overlap in places on the 2D maps. An NPC that walks away from the player
  stays selected (its actions are refused, kill.c `present()`); one the player walks away from does not.

Platforms: the first release is desktop only (DECISIONS「首发只做桌面」); CI still builds Windows, Android
and an unsigned iOS compile. The provisional app ID `com.example.easternstoriesgodot` must be replaced
before signing. Licensing: no root project license; ES2 rights are unresolved
([LICENSE_PROVENANCE](LICENSE_PROVENANCE.md)) — settle before any public distribution.

## How to verify

See [BUILD](BUILD.md). Full gate: `python tools/ci/verify.py --godot <godot>` (~10 min locally; fails on a
`SCRIPT ERROR` line, or when `python tools/l10n/extract_pot.py` was not run after a text change). Single
suites: `<godot> --headless --path game --script res://tests/run_suite.gd -- <suite paths>`. Maps: edit
`tools/maps/layouts/<region>.json`, then `python -m tools.maps.paint <region>` (the tools tests fail on a
hand-edited scene). A longer soak: `ES_SOAK_HOURS=8` before the `world_soak_test` suite.
