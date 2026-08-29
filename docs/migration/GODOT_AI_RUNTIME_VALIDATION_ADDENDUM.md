# Godot AI 实时运行补充验证

日期：2026-08-29

## 原因与证据边界

Windows 将 TCP 5940–6039 保留后，原远程调试端口 6007 会造成游戏已启动但 Godot AI game helper 无法连接。当前本机改用 6107，并使用 Godot AI 插件/服务端 3.2.4；补测期间持续确认 `helper_live=true`、`session_active=true`、`game_capture_ready=true`，实时截图均为 `stale_frame=false` 且帧号持续增长。

此前通过的 headless、领域测试、场景持久化和自动化物理输入证据不受该端口问题影响。本附录只补“真实运行窗口收到输入并产生可观察状态变化”的证据，不重新解释旧公式或规则。

## Phase 9B3B2 跨地图真实路径

### 默认失败分支

- 从 Session 初始 Outdoor 用 `move_right` 实际移动 Player：`(450, 300) -> (1183.334, 300)`。
- 在游戏 framebuffer 中用鼠标真实点击 Vine；HUD 显示 `Selected landmark: 藤蔓`，Inspect 显示 authored 藤蔓文本，按钮显示 `Hold vine`。
- 真实点击 `Hold vine` 后进入 Waterfall 分支；Player 到达 `(1200, 780)`，World HUD 清除选择，日志依次显示抓藤蔓和坠谷文本。
- 活动地图仍为 `oldpine.outdoor`，运行树仍只有一个活动地图子节点。

### Passage 成功与 SouthExit 返回

- Reset 后以 QA 状态准备把 raw dodge 从 10 调到 12，得到 effective dodge 6；注入 `ScriptedWorldInteractionRandomSource([5])`，没有修改生产代码或分支公式。
- 再次用实际移动、Vine 点击、Inspect 和 `Hold vine` 进入 Passage。
- 运行树变为 `OldPineWorldSession -> ActiveMapSlot -> OldPineCavePassage`，且活动子节点数严格为 1。
- 进入 Cave 时：map/zone/combat location 分别为 `oldpine.cave`、`oldpine.cave.waterfall_passage`、`oldpine.cave.waterfall_passage`；Player 位于 VineLanding `(0, 120)` 且 `player_controlled=true`。
- 未直接发射 SouthExit 信号。用真实 `move_down` 输入让 `CharacterBody2D` 进入 SouthExit Area，随后返回 Outdoor Waterfall。
- 返回后 `last_passage_exit_handoff_result().succeeded()` 为 true，活动地图为 `oldpine.outdoor`，活动子节点数仍为 1，WorldInteraction RNG 调用数仍为 1。
- 往返前后同一 Player runtime 和 InventoryState 实例身份保持不变，raw dodge 仍为 12；返回位置进入 Waterfall Basin，没有双 Player、双活动地图或自动反弹。

## Old Pine 综合实时交互 smoke

### 战斗与死亡

- 用真实方向输入把 Player 移入 South Slope，并用 framebuffer 鼠标点击 authored `土匪探哨`。
- HUD 正确显示 NPC 名称、`200 / 200 / 200` 和 authored Inspect 文本。
- 真实点击 Attack 后，`OpportunityTimer` 连续推进攻防；HUD/日志显示 attack、dodge、riposte、damage 与资源下降。
- 该自然运行最终由探哨杀死 Player：Player 为 `-1 / -1 / 220`、状态 DEAD、Timer 停止，并出现可见 `Player's corpse`。这补足了 Phase 6B2/6B3 的 live cadence、HUD、死亡和尸体证据。

### NPC 尸体、Loot、Inventory 与武器手位

- 在独立干净运行中，仅为缩短 QA 时间，使用既有 typed state 把一名探哨准备到 `current=-1/effective=-1`，再通过既有 combat/lifecycle 入口生成 DEAD NPC 和尸体；Player 保持 ACTIVE、220 kee。
- Player 随后全部使用真实移动靠近尸体，并用鼠标真实完成：选择尸体 -> Open Loot -> Take 短剑 -> Take 银子。
- Loot 初始显示 `短剑`、`银子 ×3`；两次 Take 后显示 Empty，尸体 direct contents 数为 0。
- 真实打开 Inventory 后显示 `短剑`、`银子 ×3`、`长剑 [PRIMARY]`；短剑 Inspect 显示 authored long、weapon、sword、damage 15。
- 实际按钮序列验证：

  1. Wield 短剑 -> `短剑 [SECONDARY]`；
  2. Unwield 长剑 -> PRIMARY 为空，短剑仍为 SECONDARY，不自动晋升；
  3. Unwield 短剑 -> 双手为空；
  4. 再 Wield 短剑 -> `短剑 [PRIMARY]`，SECONDARY 为空。
- 最终 PRIMARY 引用的是从尸体取得的同一短剑 ItemInstance，Player 仍为 ACTIVE。

## 未重复的实时路径

- 没有再为皮衣单独完成一轮可复现的 live Wear/Remove。尝试把 Fat corpse、战斗和玩家位置组合成快速 QA 状态时，真实战斗生命周期继续推进并杀死 Player；这种人工组合状态不作为生产缺陷或 Armor 结论。
- Phase 9B2 的 ArmorState、NPC WEAR、尸体皮衣、Take、Wear/Remove 与战斗投影仍由既有专项 headless/运行时测试证明；本次补证只宣称武器/loot 玩家路径已实时走通。
- 两次只读 QA `game_eval` 曾查询不存在的临时字段并触发 debugger break；均停止该临时运行并从主场景干净重启。后续新 run 的启动结果为 helper live、`current_run_errors=[]`，game log 只有 helper 注册信息。这些 eval 错误不是生产脚本错误。

## 结论

- Phase 9B3B2 的 Vine 默认 Waterfall、受控 Passage 成功和物理 SouthExit 返回现已有真实玩家输入、实时运行树、live 状态及非陈旧截图证据。
- Phase 9B3B1 的单活动地图槽、跨地图 handoff 和 authority identity 保持也由同一路径补证。
- Phase 6B2/6B3、7B2、8B1/8B2 的移动、选择、Attack cadence、死亡/尸体、Loot、Take、Inventory、Inspect、Wield/Unwield 已由一条整合 live smoke 补证，无需逐阶段重跑。
- 7B3 的 portal/aggression、9B1 的完整迷宫路线和 9B2 的 Wear/Remove 不因本次未重复人工演示而失效；其既有自动化物理/领域测试仍是权威回归证据。
- 本补测没有修改生产 GDScript、场景或 `reference/es2`。本机 `project.godot` 的 6107 调试参数继续保留为未提交本机配置。
