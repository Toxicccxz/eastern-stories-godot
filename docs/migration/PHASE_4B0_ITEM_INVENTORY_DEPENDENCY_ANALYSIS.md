# Phase 4B0：物品与 Inventory 依赖分析

## 1. 范围与结论

本阶段仅分析原始 ES2 LPC mudlib，没有实现 Item、Inventory、Armor 或 Combat，也没有
修改现有 `EquipmentState`。原始 LPC 说明的核心不是一棵“物品类继承树”，而是：

- 每个物件由 `environment()` 指向唯一的直接容器/位置；
- `feature/move.c` 维护该父关系及沿父链传播的重量；
- 角色、物品容器、房间和尸体都可能成为移动目标；
- 穿戴/持用不会改变 containment，装备物仍是角色的直接 inventory；
- `base_name()`（规范 legacy program path，去掉 clone 编号）、clone 对象 identity、显示名和
  aliases 分别承担不同用途；
- authored 对象通过大量 dbase 字段及少量任意 LPC 回调扩展行为。

因此 native 侧应迁移“稳定定义、稳定实例、单父 containment、有序转移、装备引用、
窄型 authored policy”这些语义，而不是复刻 `environment()`、`present()`、
`call_other()` 或 unrestricted dbase。

最小正确分解是 `ItemDefinition`、`ItemInstance`、`InventoryState` 与跨 Inventory / Equipment
的 `InventoryTransferService`。Combined、Armor、持久化和 authored 行为应在其上分层，
不能塞进 `CharacterState` Dictionary、现有 `EquipmentState` 或 World Node。

## 2. 实际检查范围

### 2.1 核心物品、移动、装备和持久化

- `reference/es2/mudlib/std/item.c`
- `reference/es2/mudlib/std/equip.c`
- `reference/es2/mudlib/std/item/combined.c`
- `reference/es2/mudlib/std/money.c`
- `reference/es2/mudlib/feature/move.c`
- `reference/es2/mudlib/feature/equip.c`
- `reference/es2/mudlib/feature/autoload.c`
- `reference/es2/mudlib/feature/save.c`
- `reference/es2/mudlib/feature/name.c`
- `reference/es2/mudlib/feature/finance.c`
- `reference/es2/mudlib/feature/food.c`
- `reference/es2/mudlib/feature/liquid.c`
- `reference/es2/mudlib/feature/vendor.c`
- `reference/es2/mudlib/obj/user.c`
- `reference/es2/mudlib/obj/corpse.c`
- `reference/es2/mudlib/std/char.c`
- `reference/es2/mudlib/std/char/npc.c`
- `reference/es2/mudlib/std/room.c`
- `reference/es2/mudlib/std/room/bank.c`
- `reference/es2/mudlib/std/room/hockshop.c`
- `reference/es2/mudlib/adm/simul_efun/file.c`
- `reference/es2/mudlib/adm/simul_efun/object.c`

### 2.2 命令、死亡和 Combat 消费方

- `reference/es2/mudlib/cmds/std/get.c`
- `reference/es2/mudlib/cmds/std/drop.c`
- `reference/es2/mudlib/cmds/std/give.c`
- `reference/es2/mudlib/cmds/std/put.c`
- `reference/es2/mudlib/cmds/std/wield.c`
- `reference/es2/mudlib/cmds/std/unwield.c`
- `reference/es2/mudlib/cmds/std/wear.c`
- `reference/es2/mudlib/cmds/std/remove.c`
- `reference/es2/mudlib/cmds/std/study.c`
- `reference/es2/mudlib/cmds/usr/quit.c`
- `reference/es2/mudlib/adm/daemons/chard.c`
- `reference/es2/mudlib/adm/daemons/combatd.c`
- `reference/es2/mudlib/adm/daemons/weapond.c`
- `reference/es2/mudlib/feature/attack.c`
- `reference/es2/mudlib/feature/attribute.c`
- `reference/es2/mudlib/feature/skill.c`
- `reference/es2/mudlib/std/skill.c`
- `reference/es2/mudlib/std/force.c`
- `reference/es2/mudlib/doc/efuns/present`
- `reference/es2/mudlib/doc/efuns/all_inventory`
- `reference/es2/mudlib/doc/efuns/deep_inventory`
- `reference/es2/mudlib/doc/efuns/move_object`
- `reference/es2/mudlib/doc/efuns/destruct`
- `reference/es2/mudlib/doc/applies/init`
- `reference/es2/mudlib/doc/applies/move_or_destruct`
- `reference/es2/mudlib/doc/lpc/constructs/switch`

### 2.3 全部标准武器与防具

检查了 `reference/es2/mudlib/std/weapon/` 全部 17 个文件：

- `_axe.c`、`_blade.c`、`_dagger.c`、`_fork.c`、`_hammer.c`、`_staff.c`、
  `_sword.c`、`_whip.c`
- `axe.c`、`blade.c`、`dagger.c`、`fork.c`、`hammer.c`、`staff.c`、
  `sword.c`、`throwing.c`、`whip.c`

检查了 `reference/es2/mudlib/std/armor/` 全部 11 个文件：`armor.c`、`boots.c`、
`cloth.c`、`finger.c`、`hands.c`、`head.c`、`neck.c`、`shield.c`、`surcoat.c`、
`waist.c`、`wrists.c`。

相关头文件为：

- `reference/es2/mudlib/include/weapon.h`
- `reference/es2/mudlib/include/armor.h`
- `reference/es2/mudlib/include/move.h`
- `reference/es2/mudlib/include/globals.h`

### 2.4 代表性 authored 对象与特殊协议

- 容器：`obj/example/bag.c`、`d/canyon/bamboo/obj/slipcase.c`
- 货币：`obj/money/coin.c`、`silver.c`、`gold.c`、`thousand-cash.c`
- 药物：`std/medicine/pill.c`、`std/medicine/powder.c`、`obj/drug/snake_drug.c`
- autoload：`obj/bandage.c`、`obj/marry_card.c`、`obj/roommaker.c`、`obj/token.c`、
  `obj/prize/black_vest.c`
- 特殊装备/死亡：`obj/magic_seal.c`、`obj/mailbox.c`、
  `daemon/class/scholar/windspring.c`
- heterogeneous armor：`d/oldpine/obj/black_suit.c`、`d/oldpine/npc/obj/mask.c`、
  `daemon/class/dancer/snake_sandal.c`、`std/armor/cloth.c`、`d/latemoon/obj/skirt.c`
- NPC 接收：`u/cloud/npc/monk.c`、`d/canyon/npc/general.c`、`d/snow/npc/teacher.c`

此外对全部 1,777 个 `.c` 文件执行了题目要求的 inheritance、containment、move、amount、
autoload、identity、value/weight、container、equipment、weapon/armor property 搜索。统计仅把
可由明确结构模式证明的结果当作数量，不把文件名当作类别证据。

## 3. LPC containment / ownership 模型

### 3.1 `environment()` 的实际含义

对物品而言，`environment(item)` 是唯一的直接父容器/位置，不等同于现代模型中的
“owner”。实际可达形态如下：

| LPC 状态 | 直接 `environment()` | native 语义 |
|---|---|---|
| 角色直接携带 | character object | 角色 inventory 的直接成员 |
| 装在另一物品中 | container item | 嵌套 containment；角色只是根持有者 |
| 地面物品 | room object | World placement/loot endpoint |
| 尸体内物品 | corpse object | 尸体容器的直接成员 |
| 穿戴物 | character object | 仍在角色直接 inventory，另有 worn 引用 |
| 持用武器 | character object | 仍在角色直接 inventory，另有 wielded 引用 |
| combined stack | 任一上述父级 | 一个对象实例加 `amount`，不是多个子物件 |
| 已消耗/销毁 | 无有效 object/environment | 生命周期终止 |

证据主要来自 `feature/move.c`、`feature/equip.c`、四个物品移动命令、
`adm/daemons/chard.c` 和 `obj/corpse.c`。

`environment()` 还被 LPC runtime 用于房间广播、命令安装、同房对象查找等。这些属于
MudOS/FluffOS 对象运行时，不应变成 native 的“任意对象都能做容器”。World Runtime 只需
把某个 ItemInstance 放置到 map/zone/position endpoint；Game Core 维护其逻辑位置和转移
结果。

全库复扫只找到一处活动 `move_object()` 调用，即 `feature/move.c` 自身；其他命中均在 driver
文档中。`deep_inventory()` 只存在于 driver 文档，没有 gameplay `.c` 调用。活动
`first_inventory()/next_inventory()` 仅在 `std/char.c` 扫描房间里的 interactive 对象，并非
另一套物品 ownership。装备 temp 引用、任务 object 引用、mail 数据等只是关联，不改变物件的
直接 environment。未发现 item-like object 使用第二套 containment 机制。

所以“每个可移动实例一个直接 parent/location，加 ancestry/root-holder 查询”足以表达当前物品
核心。它还应显式拒绝 containment cycle；旧 `feature/move.c` 没有在 mudlib 层写出 cycle 检查，
是否由 driver 拒绝属于 runtime 防护，不应靠 native 任意 parent setter 重现。

### 3.2 直接携带与根持有者必须区分

嵌套袋中的物品最终由角色携带，但它不是角色的直接 inventory 成员。LPC 的
`present(arg, me)`、autoload、装备、死亡枚举等大量路径只查看直接 inventory。因此未来
模型至少需要：

- 每个 ItemInstance 的唯一直接 parent/location；
- 可计算的 containment ancestry/root holder；
- 明确的 direct-owned 谓词，供 equip、autoload 和部分命令使用；
- 防止 containment cycle 的 native invariant。

“拥有”和“直接位于”不能只用一个扁平 `Array[ItemId]` 表示。

MudOS 自带文档明确说明：指定第二参数的 `present(str, ob)` 只搜索 `ob` 的 inventory；
`all_inventory(ob)` 也只返回直接 contents。没有参数的 `present()` 才搜索当前对象的直接
inventory以及其 environment 的直接 inventory，同样不递归。对本阶段涉及的路径：

- wield/wear/unwield/remove、drop/give/put 的 source 都是角色直接 child；
- `get X from Y` 先在角色或房间直接找到 `Y`，再只在 `Y` 的直接 inventory 找 `X`；
- `get all from Y`、autoload保存、quit清点和 death转移均使用直接 `all_inventory()`；
- NPC `accept_object()` 接收的是 give 已解析出的直接 child，但调用发生在 transfer 前。

没有命令隐式搜索任意深度的 nested contents。例外只是玩家可以逐层指定当前可直接找到的容器；
放在外层容器里的内层容器本身不能被同一条 `present(..., character)` 递归找到。

## 4. 移动与命令顺序

### 4.1 `feature/move.c::move()`

已确认顺序如下：

1. 若物件 `equipped` 非零，先调用物件 `unequip()`；失败则整个移动失败。
2. 把字符串目的地解析成 LPC object；无效目标立即失败。
3. 检查目的地容量。若目的地已经是当前物件的 ancestor（例如把袋内物品移到持袋角色）
   则不会把同一重量再次当作新增负载而拒绝。
4. 容量失败发生在 containment 和 encumbrance mutation 前。
5. 旧 environment 执行 `add_encumbrance(-weight())`。
6. driver `move_object(destination)` 改变父关系。
7. 新 environment 执行 `add_encumbrance(weight())`。
8. 移动者本身是 interactive living 且非 silent 时，执行房间显示/查看；这是 runtime 表现。

底层移动没有通用 `before_move`、`after_move`、`accept_object` 或 `receive_object` 协议。
MudOS 在 environment 改变后触发对象 `init()` 的命令注册语义也属于 runtime，不应成为
native 通用物品回调总线。`std/item/combined.c` 自行 override `move()`，是明确的 stack
特例。

### 4.2 get / drop / give / put

| 操作 | 已确认的精确 gameplay 顺序 |
|---|---|
| get | 先验证参数和角色 busy；再解析可选 source（角色直接 child优先，再查房间直接 child）并做 living/wizard 搜身检查。数量分支依次做 direct `present`、stack/bounds、split，然后才进入 `do_get()`；`do_get()` 再检查 character/living与 `no_get`，记录旧 environment/equipped，调用 `move(character)`，成功后战斗 busy与表现。`all` 分支先拒绝战斗、要求 source capacity非零，snapshot直接 contents并跳过 character/`no_get`。普通单件分支在 `do_get()` 前也拒绝 living与 `no_get`。 |
| drop | 没有 busy检查。数量分支先 direct `present`；只提前拒绝 string型 `no_drop`，再检查stack/bounds并split；`do_drop()` 才拒绝任意 truthy `no_drop`。随后 `move(room)`，成功后表现；非 character物若 dbase `value` 和 `value()` 都是假则销毁。`all` snapshot角色直接 contents逐件执行。 |
| give | 没有 busy检查。先解析语法并解析同房 living target，再解析角色直接 item。数量分支在split前检查任意 truthy `no_drop`（wizard例外）；`do_give()`再次检查。若 target非 interactive，先调用 `accept_object(giver,item)`，拒绝则不move。随后若 target非 user且 `item->value()` truthy，先表现再直接销毁；否则才 `move(target)`并表现。故普通 NPC 是 **accept在前、valuable销毁在后**，valuable从未进入NPC inventory。 |
| put | 没有 busy检查。先解析 destination：角色直接 child优先，否则房间直接 child，且必须非 living；之后才解析角色直接 source。数量分支先split；`do_put()`到此才检查 `no_drop`，然后 `move(destination)`并表现。`all` snapshot角色直接 contents且跳过 destination本身。命令不检查 `is_container()`。 |

`get from container` 的指定物品路径也不要求 `is_container()`；`get all` 才以
`query_max_encumbrance()` 是否非零作为近似容器判断。低层 move 只认目标容量协议。这说明
旧库中没有一致的 Container interface。

命令层提供正常玩家授权边界，低层 `move()` 并不证明调用者拥有物品。native 应把命令、
AI、死亡、脚本奖励都汇入同一个 typed transfer operation/service，并由调用上下文明确授权和
policy；不能只暴露可任意改 parent 的公共 setter。

### 4.3 失败、callback 与原子性建议

- destination解析确实发生在 `unequip()` **之后**。因此 unequip成功后，字符串目标无法加载、
  destination类型无效或容量不足，都可留下“物品仍在原 containment，但已卸装且 modifiers已移除”
  的状态。`feature/equip.c::unequip()` 已在返回成功前删除手槽/armor槽、重置 action（武器）、
  扣除 applied props并删除 item marker，所以该 partial mutation可直接由源码证明。
- destination与容量失败发生在 parent/encumbrance mutation前。通过这些检查后，旧父级先减重、
  再调用返回 `void` 的 `move_object()`、最后新父级加重；mudlib没有 catch或 rollback。正常成功路径
  只改变一次直接 parent，但若 driver在 `move_object()` 抛错，encumbrance也可能已经部分改变。
- `give` 的 `accept_object()` 是命令层 NPC policy，不是移动目标的通用 callback。
- `no_get`/`no_drop` 是 authored gate；`magic_seal.c` 还会运行时设置 `no_drop`。
- `owner_is_killed()` 只在死亡 daemon 主动枚举时调用。

必须区分两种“原子性”：

- **containment transfer atomicity**：在正常 destination/capacity失败时，parent尚未改变；
- **完整 gameplay transition atomicity**：不成立，因为 Equipment detach已经发生，命令split
  也可能先改变stack。

未来 `InventoryTransferService` 不应把所有步骤伪装成一个不可分事务。它应能返回有序的
detach、validation、containment、merge/lifecycle结果或事件，使调用方知道失败前已发生什么。
若 native决定 rollback并提供更强原子性，这仍是实现阶段的产品兼容决定，本分析不预先选择。

命令本身还有额外 partial mutation：partial get在 `no_get`/move失败前已split；partial put在
`no_drop`前已split；partial drop遇到 boolean型 `no_drop`时也在最终拒绝前split。这些不能被
“transfer失败所以什么都没变”的统一结果掩盖。

## 5. Definition 与 Instance

LPC dbase 允许同一字段在不同对象中既像 definition 又可被运行时修改，不能简单按字段名
机械分层。建议的证据表如下：

| 旧字段/行为 | 常见 authored definition | 已发现 instance mutation / 例外 | 推荐归属 |
|---|---|---|---|
| `base_name()` 程序路径 | clone 模板与恢复来源 | 去掉 clone `#number`，通常也不含 `.c`；不同路径的重复内容仍是不同 definition | `ItemDefinitionId` 的 legacy metadata，不直接当 native ID |
| `name`、`id[]`、`short/long`、`unit` | 多数对象 create/setup 写入 | `weapond.c` 改断裂武器 name；corpse decay改 name/aliases/long；bandage autoload改 name；伪装 armor通过 apply数组改变角色显示 | definition + 明确的 instance overrides/effects；`unit` 当前仍主要是definition |
| `weight` | 多数物品固定 | combined 按数量重算；corpse按 victim生成；容器还有 contents encumbrance | definition base weight；instance quantity/generated override/contents推导总重 |
| `value` / `base_value` | 常为 authored price | 食物使用后置 0；武器破损除以 10；money value 按 amount | definition base value + 窄型 instance override/formula |
| `skill_type`、weapon flags | 标准武器基类写入 | 未发现 authored `skill_type` override；flags 因对象而异 | weapon definition component |
| `weapon_prop` | 通常 authored | `weapond.c` 破坏武器时写 0 | definition stats + instance unusable/override state |
| `armor_type`、`armor_prop` | 通常 authored | 穿戴累计到 character temp；cloth另有每实例 `teared_count`；部分 armor_prop 是文字伪装数组 | armor definition component；数值 modifier、实例使用状态与 presentation effect 分开 |
| `amount` | 无 | 每个 combined clone 独立，split/merge/消费修改 | `CombinedStackState` instance data |
| `equipped` | 无 | item-side `wielded/worn/sealed` marker | 不复制；由 native Equipment/typed effect 单点管理 |
| food/liquid remaining | 容量、供应量 authored | `food_remaining`、`liquid/remaining/type/name/drink_func` 可变，food还会修改instance value | typed consumable/container instance state |
| `no_get` / `no_drop` | 可 authored | magic seal 动态设置 | definition gate + typed instance lock/effect |
| `skill` mapping | 书籍 authored | 未见正常 study 流程修改 | study-source definition component |
| autoload argument | 无 | amount、伴侣名、guild ID、bandage blood state等 | typed persistence DTO / migration payload |

物品定义必须可共享且不可被 instance gameplay 静默修改；原 LPC 中“直接改定义型字段”的
行为要转为 instance override、状态组件或 typed effect，而不是让所有 definitions 可变。

## 6. 稳定身份

原库实际使用了四种不同身份：

1. `base_name(object)`：规范 LPC program path（去掉 clone编号）。Combined merge、split clone、
   autoload恢复使用。
2. clone/object identity：装备引用、移动目标、`present()` 结果、Combat 当前武器使用。
3. `id()` aliases：玩家命令查找；`feature/name.c` 还允许临时 apply/id 完全遮蔽原 aliases。
4. display `name()`：主要是表现，但少数任务脚本直接比较，如
   `d/canyon/npc/general.c` 比较“印鉴”。

因此未来必须分开：

- `ItemDefinitionId`：迁移后稳定、与 Godot 路径和显示文字无关；保留
  `legacy_source_path` 以追溯和导入；
- `ItemInstanceId`：每个运行时实例稳定且唯一，供 containment、equipment、transfer、
  save 和脚本引用；
- aliases/display name：authored 查找与表现数据，不能充当权威 ID。

相同显示名或 aliases 在全库并不唯一；内容相同但路径不同的对象也不会按 LPC combined
规则合并。旧任务若错误地依赖显示名，迁移时应逐条建立 typed compatibility policy，不能
把 display name 提升为全局身份。

未发现需要第三种全局物品 identity。`money_id`、任务角色、guild ID、weapon skill type等是
definition tags、外部关系ID或instance payload，而不是 definition/instance identity的替代品。
未来 quest/interaction可有独立稳定 role/objective ID，但它应引用 ItemDefinitionId或
ItemInstanceId，不应塞进物品主身份。

## 7. Combined / stack 精确语义

来源为 `std/item/combined.c`、`std/money.c`、四种 money、`std/weapon/throwing.c`、
medicine/powder 与 get/drop/give/put 数量分支。

- `amount` 是每个 combined object 的 `static int` instance state。
- `set_amount(v < 0)` 报错；`v == 0` 安排一秒后 destruct，但既不把 `amount` 写成 0，
  也不重算 weight；直到 call_out执行前，旧 amount与旧 weight仍可被查询。正数才赋值并把
  own weight改为 `amount * base_weight`。
- `add_amount(delta)` 委托 `set_amount(amount + delta)`。
- `short()` 用数量、`base_unit` 和基础 short 组合。
- 成功 move 后，仅当 destination 是 `living` 时，扫描其直接 inventory；所有
  `base_name()` 完全相同的 stack 被销毁并把数量并入刚移动的对象。
- room、普通 item container 和 corpse 不会自动 merge；只有 living destination merge。
- split 使用 `new(base_name(original))` 再 `set_amount()`，不会复制原 stack 的其他 mutable
  instance state。
- stack compatibility 只看源路径，不看显示名、aliases、品质、状态或自定义 payload。
- combined own weight乘数量；只有 `std/money.c::value()` 明确把 `base_value * amount`。
  一般 combined 对象的 dbase `value` 不会自动按量相乘。
- throwing weapon 的 post action 会 `add_amount(-1)`；最后一个实例先卸装，随后进入延迟
  destruct 的零量边界。

四种货币定义为 coin（base value/weight 1/1）、silver（100/37）、gold
（10,000/37）、thousand-cash（100,000/3）。`feature/finance.c` 只查询 gold/silver/coin，
`std/room/bank.c` 以整数除法兑换，`std/room/hockshop.c` 以 60%/80% 支付银/铜并销毁原物。

native 不应假定所有相同 definition 都能堆叠。需要显式 stack component/policy，至少定义
definition compatibility、quantity、split cloning policy、merge location policy、weight/value
formula 和 zero lifecycle。是否保留“一秒可见的零量对象”是未来 runtime/compatibility 决策，
不能在本阶段静默正常化。

### 已确认 stack 缺陷

- `cmds/std/get.c` 的部分数量路径确定地减少原 stack，另建“请求数量”clone放回来源，却把
  减少后的原对象交给 `do_get()`。若非 living来源原有 `N`、请求 `A`（`0 < A < N`），成功后
  角色取得 `N-A`，来源留下新clone `A`；仅在 `A == N-A` 时数量表面相同。若后续 `no_get`或
  capacity失败，split仍已发生但两个stack都留在来源。
- 若来源本身是 living（wizard搜身路径），新建的零量clone先 move回该 living，触发 combined
  merge：原 `N-A` 对象被销毁，clone短暂取得 `N-A`后又被 `set_amount(A)`覆盖；随后
  `do_get()`拿到的是已销毁原引用而失败。最终 living仅保留 `A`，其余数量丢失；若同路径还有
  其他直接stack，也会先并入再被覆盖。
- `obj/drug/snake_drug.c` 把 `base_weight` 拼成 `base_weiht`，导致该 stack 重量异常。
- split 只构造同 path默认clone并设置amount，不复制其他instance override；merge也只保留移动
  对象并合计amount。当前扫描未证明某个普通combined内容依赖可变自定义payload，所以这是
  **结构性数据丢失风险**而非已证实玩家路径缺陷。已装备 throwing stack则是已证实例外：被
  merge销毁时会先unequip，存活的移动stack不会自动继承装备状态。

这些必须记录为 legacy 行为/缺陷；实现 Phase 4B3 时再决定兼容或修正，并写明决定。

## 8. 重量与容量

`feature/move.c` 的 `weight()` 返回 own `weight + encumb`。`add_encumbrance(delta)` 修改当前
容器的 contents encumbrance，并沿 `environment()` 父链递归传播相同 delta。因此：

- 嵌套物品的重量最终计入角色负载；
- 容器本身重量和所有后代重量都计入；
- 穿戴/持用物仍在角色内，所以仍计负载，没有装备减重规则；
- drop/move 从旧父链减重，再向新父链加重；
- combined own weight已按 amount 扩展，再进入相同父链；
- `set_weight()` 会对当前 environment 调整差值。

目的地用 `query_encumbrance() + moving.weight() > query_max_encumbrance()` 判断。move 的 ancestor
例外避免“把袋中物拿到角色直接 inventory”被当成新增总负载。`add_encumbrance()` 对负值
underflow 只写 log，没有 clamp；`set_max_encumbrance()` 也没有正数 invariant。

对 `character C -> bag B -> item I` 的源码推演结果为：

| move | ancestor检查 | C上的净重量 | 直接变化 |
|---|---|---:|---|
| `I: B -> C` | destination C在I祖先链，跳过capacity | 0 | B减I，传播到C减I；随后C直接加I |
| `I: C -> B` | B不是I祖先，检查B capacity | 0 | C先减I；B加I并向C传播加I |
| `B: C -> room` | room通常是B祖先，跳过room capacity | `-(B own + I)` | C整棵subtree减一次；room加一次 |
| `B: C -> C内另一容器 D` | D不是B祖先，检查D capacity | 0 | C先减B subtree；D加subtree并向C传播 |
| `B: C -> 另一根的容器` | 目标不在祖先链，检查目标capacity | 旧根减、新根加 | 每条根链各更新一次 |

所以 ancestor例外不是“不更新重量”，而是只跳过capacity；后续 old-parent remove与new-parent add
仍照常执行。`set_weight()` 也可接受任意整数，没有负值clamp，并把 own-weight差值沿当前父链
传播。

Phase 1 已拥有角色 `max_encumbrance` 的种族/属性推导。未来 `InventoryState` 应消费调用方
提供的 capacity limit，不复制 `base str * 5000` 等角色公式。Inventory 自己负责：

- definition own weight与 instance quantity/override；
- containment subtree weight；
- 当前 load与目标 capacity 检查；
- ancestor/cycle 关系；
- transfer 后的确定性重量更新或重算。

旧库 Container protocol 不一致：全库只找到 3 个 `is_container()` 定义（袋、书匣、尸体），
且没有 gameplay调用它；恰好 9 个 authored item文件设置 `max_encumbrance`（袋、书匣、四份
denotation、两份silk bag及一个token），另有尸体由chard运行时赋容量。`put`把任何非living
直接目标都当作候选；move只做数值capacity检查，因此 max=0的对象甚至仍可接收总重为0的物品。
`get all`才以非零 max capacity作为“容器”近似，指定 `get X from Y`不检查。

因此应区分：semantic containment能力来自实际parent关系；`is_container`只是未被这些路径消费
的authored marker；正capacity使正重量contents可进入。未来 typed ContainerComponent仍有必要，
用于声明合法目的地与capacity；若迁移内容确实依赖“零重量放进非容器”，应作为显式legacy
policy，而不是让所有ItemInstance天然成为container。

## 9. 与 Phase 4A1 EquipmentState 的关系

问题的直接答案如下：

1. **正常路径下每个 wielded/worn 物都必须由角色直接携带。** `feature/equip.c` 要求
   `environment()->is_character()`；命令又先用 `present(arg, character)` 限定直接 inventory。
2. **低层 equip 自身部分 enforce ownership shape。** 它证明当前直接 environment 是某个
   character，却不证明调用者授权，也不建立跨角色全局唯一归属。
3. **任意 LPC 低层 dbase/temp 写入能制造不一致。** 正常 `wield()/wear()` 不能装备房间或
   nested item，但 unrestricted `set_temp()` / item marker 可产生命令路径不可能状态。
4. **最终 Equipment 应持 ItemInstanceId 窄引用。** definition facts应由调用方提供的 immutable
   definition lookup/实例投影解析；
   Phase 4A1 的 definition scalar snapshot适合当时独立闭合 Learn，但不应成为完整物品系统的
   第二权威来源。
5. **物品移走时由 transfer orchestration 先清 Equipment。** LPC 是物件 `move()` 调用
   `unequip()`；native 应由 InventoryTransferService 协调 EquipmentState，而不是让
   ItemInstance 反向拥有角色。
6. **drop/give/put 和任意低层 move 都可隐式 unwield/remove。** 命令没有统一先拒绝装备物。
7. **get/drop 不统一拒绝装备。** 从角色取得其装备物时低层 move 可先卸装；drop 同理。

因此后续 integration 需要一次**窄 refactor**：保留现有主/副槽转移语义和 instance ID，
把 definition snapshot 的构造/校验接到 ItemDefinition/ItemInstance 投影，并由 transfer service
保证 direct ownership 和移走前 detach。EquipmentState 不能扩展成 general Inventory，也不能
保存完整 ItemInstance 或容器树。

Phase 4A1 snapshot字段的最终处理应为：

- `instance_id` 是装备槽权威引用，必须解析到仍存在且由该角色直接持有的ItemInstance；
- `weapon_id` 应与未来 `ItemDefinitionId` 使用同一个稳定ID语义，而不是第二套武器身份；
- `skill_type`、`can_wield_as_secondary`、`is_two_handed` 是immutable definition投影。为保持当前
  pure hand-state逻辑，它们可以留作经过校验的cache；definition不可变且构造时ID匹配时，不构成
  mutable第二权威来源；
- `legacy_source_path` 只是追溯cache，不参与ownership或Combat判定；
- 未来 damage、value、name、actions或instance破损状态不得继续扩张为永久slot snapshot，应在
  相应操作时从ItemInstance/ItemDefinition投影取得。

为避免 `InventoryState <-> EquipmentState` 循环依赖，两者都不应直接调用对方。外层
`InventoryTransferService`（或同等窄orchestrator）接收两份状态：先按legacy顺序请求Equipment/
Armor detach，再验证并mutation containment，返回ordered result。InventoryState只拥有parent/
contents/weight事实；EquipmentState只拥有槽引用。

要特别保留的 legacy 顺序：move 先卸装、后容量检查；装备导致的属性移除也先于 containment
mutation。是否原样保留容量失败后的已卸装状态必须在实际 integration 阶段明确决定。

## 10. Armor 语义

### 10.1 类型/槽与状态

`include/armor.h` 定义 11 个标准开放字符串：`head`、`neck`、`cloth`、`armor`、
`surcoat`、`waist`、`wrists`、`shield`、`finger`、`hands`、`boots`。全库还实际发现
`bandage`、`mask`、`feet`，其中 `feet` 与 `boots` 是两个可并存类型。因此不能用只含 11 项
的封闭 enum；未来应使用经过内容验证的开放 `StringName` slot ID。

角色 temp `armor/<type>` 每类只存一个对象，故同一 type 同时只能穿一件。command层先拒绝已有
任意`equipped` marker；低层`wear()`遇到已有marker则直接返回1而不验证type或mutation。对一个
尚未equipped的新wear，顺序为：

1. 验证 item直接位于 character，且`armor_prop`是 mapping；
2. 验证该 armor type 槽为空；
3. **先**写 character `armor/<type>` 引用；
4. 再将 armor_prop 每项累计到 character temp `apply` mapping；
5. 写 item `equipped = "worn"`。

unequip 对 worn item 先删除对应槽，再减去 apply mapping，最后删除 item marker。与武器相同，
状态双写在角色与物件；native 应由 ArmorState 单点拥有槽位。

### 10.2 盾牌、gender 与 modifier

- `shield` 就是 armor type，同时被 `feature/equip.c` 用来阻止首次装备双手武器或增加副武器。
- `cmds/std/wear.c` 在低层 wear 前检查 `female_only` 与 character gender；这属于装备资格 policy，
  不是 ArmorState 原始槽容器本身。
- `std/equip.c` 对weight `>= 3000`且没有 `armor_prop/dodge`/`weapon_prop/dodge` 的generic
  equipment加入负dodge。11个 `std/armor/*` 自己override setup，使用严格 `weight > 3000`，但
  全部错误检查 `armor_apply/dodge` 后写 `armor_prop/dodge`；这会忽略已有
  `armor_prop/dodge`保护，属于可执行键名不一致。
- `armor_prop` 不只是护甲值：全库出现 `armor`、`armor_vs_force`、attack、defense、dodge、
  attributes/skills 等数值；`d/oldpine/obj/black_suit.c` 还把 id/name/short/long 数组塞入同一
  mapping 以伪装角色。

未来 ArmorState 应把 slot refs 与 typed numeric modifier aggregation 分开；presentation/identity
伪装属于 authored effect/presentation projection，不能用通用 `Dictionary[String, Variant]`
污染 Combat core。

全库 active `armor_type` 值复扫确认完整集合为：`head`、`neck`、`cloth`、`armor`、
`surcoat`、`waist`、`wrists`、`shield`、`finger`、`hands`、`boots`、`bandage`、`mask`、
`feet`；没有发现其他literal或dynamic setter。开放字符串domain仍必须保留，因为
`feature/equip.c`不会限制未来/custom type。

### 10.3 Modifier key盘点

对全部 `.c` 的 `armor_prop/<key>` 与 `weapon_prop/<key>` 扫描得到：

| 类别 | 已发现key | 消费边界 |
|---|---|---|
| Combat数值 | `damage`（weapon）、`armor`、`armor_vs_force`、`attack`、`defense`、`dodge` | `combatd.c`、`std/force.c` |
| Character attribute | `composure`、`courage`、`intelligence`、`karma`、`personality`、`spirituality` | `feature/attribute.c` 的 `apply/<name>` |
| Skill modifier | `magic`、`move`、`spells`、`unarmed` | `feature/skill.c` 的 `apply/<skill>` |
| Presentation/disguise | `id`、`name`、`short`、`long` arrays | `feature/name.c` 的 apply读取 |

weapon侧实际key为 `attack,courage,damage,defense,dodge,intelligence,karma,personality,spells,
spirituality`；armor侧实际key为 `armor,armor_vs_force,attack,composure,courage,defense,dodge,id,
intelligence,karma,long,magic,move,name,personality,short,spells,unarmed`。`feature/equip.c` 会透传任意
mapping key，所以源协议理论上仍开放；native应给已知数值类别typed modifier，并为确有内容的
presentation effect单独建模。该开放性不要求一个通用 `Dictionary[String, Variant]` aggregate。

## 11. Combat 物品依赖矩阵

### A. 最小空手、无甲 Combat

Item/Inventory提供的事实为 **零**。`combatd.c` 在 weapon为空时使用 `unarmed`，action来自角色
mapped unarmed skill或race/default action；命中、闪避、空手parry、strength/force/martial/monster
hook、combat exp和gin/kee/sen都来自Character/Skill/Combat领域。armor可作为显式0输入。

因此最小空手/无甲 Combat **技术上现在就能开始**，并不需要先造ItemDefinition、InventoryState
或ArmorState。它仍需独立处理action projection、injectable randomness、combat relationship、
damage/progression和legacy zero/random边界；“没有物品依赖”不等于Combat本身已经简单或可闭合。

### B. 最小 armed Combat

| 事实 | 消费方式 | LPC 来源 |
|---|---|---|
| 主武器存在及instance identity | 选择armed路径、影响双方parry与wound资格 | `feature/attack.c`、`adm/daemons/combatd.c` |
| 主武器 `skill_type` | 选择攻击basic skill与mapped martial action | 同上、`std/weapon/*.c` |
| `weapon_prop/damage`聚合结果 | 作为 `apply/damage` 进入基础damage | `feature/equip.c`、`combatd.c` |
| 至少一个typed action projection | 提供action damage/force/dodge/parry/damage_type等 | `feature/attack.c`、`weapond.c`、skill daemons |
| weapon hit hook的明确default/no-op边界 | 源在命中时无条件尝试weapon `hit_ob` | `combatd.c` |
| 有效direct ownership projection | 防止已移走/销毁实例继续攻击 | `feature/move.c`、`feature/equip.c` |

公式可只消费注入的weapon snapshot，因此完整Inventory不是数学硬依赖；但要成为权威游戏状态，
必须先有ItemInstance identity、direct ownership与transfer-detach invariant。否则Combat会认可悬空
Equipment ref。

### C. 完整普通武器 parity（不含 procedural hook）

| 事实 | 用途 | LPC 来源 |
|---|---|---|
| weapon flags、skill type、damage与immutable action/verbs | 持用约束和标准action选择 | `include/weapon.h`、`std/weapon/*`、`weapond.c` |
| weight、rigidity | 为后续bash提供实例/定义输入 | `weapond.c` |
| mapped skill action优先级、weapon action fallback | 精确保留 `reset_action()` 来源顺序 | `feature/attack.c` |
| primary/secondary/shield事实 | 持用和parry语义；Combat攻击本身只传primary | `feature/equip.c`、`combatd.c` |

### D. Armor / damage reduction 需要

| 事实 | 用途 | LPC 来源 |
|---|---|---|
| aggregate `apply/armor` | weapon或killing攻击的 wound 判断及 wound amount | `feature/equip.c`、`adm/daemons/combatd.c` |
| aggregate `armor_vs_force` | 内力伤害减免 | `std/force.c` |
| attack/defense/dodge modifiers | skill power、闪避/招架相关计算 | `feature/equip.c`、`adm/daemons/combatd.c` |
| worn slot和实例有效性 | remove/move/death后不得继续贡献 | `feature/equip.c`、`feature/move.c` |

因此 Armor **不是启动最小无甲基础 Combat 的硬前置**，但在宣告 weapon/armor/damage parity
或迁移正常装备内容前必须完成。推荐在 Combat core 之前实现 Armor foundation，降低随后
返工；Combat 可先定义 typed armor aggregate 输入而不依赖 ArmorState 的内部结构。

### E. Advanced `post_action` / `hit_ob`

| 事实 | 用途 | LPC 来源 |
|---|---|---|
| typed `post_action` | bash、throw在主damage/表现之后执行 | `combatd.c`、`weapond.c` |
| stack amount与zero lifecycle | throwing每次消费一个，最后先unequip再进入延迟销毁 | `weapond.c`、`combined.c` |
| weapon/victim weight、rigidity、base strength | bash脱手/断裂随机比较 | `weapond.c` |
| item move与instance overrides | bash可drop武器，或改name/value并清空weapon_prop | `weapond.c` |
| force/martial/weapon/monster `hit_ob`有序结果 | 返回文字或整数bonus；依赖不同未来系统 | `combatd.c`、`std/force.c`、7个active authored definitions |

这些不能用任意 callback-name/function字段直接搬运；需要以后按stable definition/skill ID注册的
typed Combat effect，并保留force → action force → martial → weapon/monster → defense reduction →
damage/wound → post_action的调用顺序。

### F. 死亡、掉落与奖励需要

| 事实 | 用途 | LPC 来源 |
|---|---|---|
| direct inventory snapshot | 死亡时逐件调用 policy并转移 | `adm/daemons/chard.c` |
| `owner_is_killed` typed policy | 邮箱/roommaker销毁，windspring生成奖励 | `obj/mailbox.c`、`obj/roommaker.c`、`daemon/class/scholar/windspring.c` |
| worn/wielded 状态及 detach | worn尝试在尸体重穿；wielded仅卸下后进入尸体 | `adm/daemons/chard.c`、`feature/move.c` |
| corpse capacity、contents、decay | loot容器及最终散落 | `obj/corpse.c`、`adm/daemons/chard.c` |
| nested containment | 死亡只枚举直接 inventory；袋内物随袋整体移动 | 同上及 `feature/move.c` |
| instance destroy/generate | 回调和奖励生命周期 | 上述 special item files |

### G. 仅表现需要

- weapon/armor/item display name、short、unit、material；
- action strings、weapon verbs、damage type 的本地化表现；
- get/drop/give/wear/wield/decay 消息；
- black suit 等 apply/name/id/short/long 伪装投影。

来源为 `feature/name.c`、各 standard weapon/armor、commands、`combatd.c`、`weapond.c` 和
`d/oldpine/obj/black_suit.c`。Presentation 可消费 structured results，但不得成为权威数值或
物品生命周期状态。

结论要区分可行性与路线：最小空手/无甲 resolver可以先做，这是技术事实；但当前正式迁移线
推荐仍先完成4B1 identity，再做containment/Equipment integration与Armor projection，以避免
armed/death接口返工。该推荐不是把Item/Armor误称为空手公式硬依赖。完整armed parity应等
ItemInstance ownership稳定，完整armor parity应等ArmorState，death/corpse integration还需
transfer与lifecycle边界。

## 12. Authored 物品结构盘点

全库共有 1,777 个 `.c` 文件。以下是“直接 inherit 明确根类型”的可靠结构计数；类别之间
可能重叠，且自定义中间继承会使它们成为下限而非所有 gameplay items 总数：

| 结构模式 | 文件数 | 说明 |
|---|---:|---|
| `inherit ITEM` | 134 | plain、容器、任务、脚本、尸体等混合 |
| `inherit EQUIP` | 36 | 通用可装备根，仍需看 authored properties |
| 标准 weapon 宏 | 140 | 9 种标准 weapon roots 的直接继承 |
| 标准 armor 宏 | 149 | 11 种标准 armor roots 的直接继承 |
| `inherit COMBINED_ITEM` | 14 | 直接 combined；其子类使用者不全含在此数 |
| `inherit MONEY` | 4 | coin/silver/gold/thousand-cash |
| 上述 item/equip/combined/money/weapon/armor 唯一直系文件 | 477 | 可靠的 authored item 结构下限 |
| `inherit F_FOOD` | 40 | 与其他 item 类重叠 |
| `inherit F_LIQUID` | 12 | 液体容器/饮品 mixin，与其他类别重叠 |
| `set("skill", mapping)` study source | 40 | 书/秘笈等，按字段而非文件名确认 |

进一步分类结论：

- **plain/data item**：多为 ITEM + name/weight/value/unit；134 个直接 ITEM 中混有脚本对象，
  无法仅靠 inheritance精确拆分。
- **weapon / armor**：分别有 140/149 个标准直接继承；另有直接 EQUIP/custom protocol。
- **combined/stack / currency**：14 个 direct combined 和 4 个 MONEY；throwing、medicine 等
  通过中间层继续扩展。
- **food/drink/consumable**：40/12 个 mixin 使用文件；剩余次数、liquid 内容和回调形态不同。
- **container**：只找到 3 个 `is_container()` 实现，却至少 9 个 authored item 设置容量；
  不能给出一个与旧库自称一致的容器总数。
- **book/study source**：40 个明确 skill mapping 文件。
- **quest/key item**：没有统一 marker。通过 display name、id、path、`no_drop`、NPC
  `accept_object()` 或 marks 串联，无法给出可靠总数；`general.c` 的“印鉴”是代表例。
- **scripted item**：全库有 176 个 `.c` 定义 `init()`；其中至少 32 个直接 item-root 文件
  自行注册动作。另有 attach、finish_eat、drink_func、hit_ob、post_action、death callback等。
- **corpse**：`obj/corpse.c` 是特殊 ITEM/container/阶段性 character。
- **temporary/summoned/generated**：`new()`、reward、NPC carry、corpse/zombie 等创建点分散，
  没有统一 type marker，静态总数不可靠。

任务物、脚本物和临时物无法可靠计数本身就是重要架构证据：内容迁移需要显式 schema/tag
和 validation，而不是依赖源路径/文件名猜测。

## 13. Procedural hooks / protocol 归类

| LPC hook/protocol | 发现与语义 | native 归属 |
|---|---|---|
| `init()` | 全库 176 个；通常注册 MUD command，依赖 `this_player/present/environment` | World/interaction adapter 或 typed use action；不放 Item core |
| `accept_object()` | 精确41个 active definition files；多为 NPC任务、金钱、marks | NPC/quest typed acceptance policy，由 give action调用 |
| `receive_object()` | 未找到定义 | 不制造一个通用 receive callback |
| `no_get` / `no_drop` | authored/运行时 gate | Inventory transfer policy + presentation reason key |
| `wear/wield/unequip` | generic equip + 少数 authored override | Equipment/Armor transition；override 转 typed policy/effect |
| object `drop()/get()` | 未找到通用定义 | 不建立 LPC 同名 callback dispatcher |
| `query_autoload()/autoload()` | 5个active query definitions、4个exact `autoload()` definitions；0个 `init_autoload()` | persistence codec/policy registry |
| `owner_is_killed()` | 3 个 authored definitions | death item policy，返回 destroy/generate/keep 等 typed effect |
| food/liquid hooks | 8个active `finish_eat()` definitions；drink/eat function、condition application与powder绑定 | Consumable use policy；Character resource/Condition边界 |
| weapon hooks | 7个active `hit_ob()` definitions；`post_action`只在weapond定义、combatd消费 | future Combat authored effect registry |
| attach/custom verbs | `attach_func`、pour/effect_in_liquid 等 | typed authored interaction；部分需要 World/target context |

不能设计一个 `Dictionary payload + callback_name + call_other()` 的兼容层。每一种已迁移协议应
有窄输入、窄结果和稳定 definition ID registration；依赖尚未迁移的 NPC/Quest/World/Combat
则明确 deferred。

以上“未找到”以全部1,777个 `.c` 的函数定义正则复扫为界：`receive_object()`、对象级
`drop()`、对象级`get()`、`init_autoload()`均为0。custom verbs仍广泛通过176个`init()`注册，
包括attach、tear、pour、eat/drink等，因此“无generic hook”不等于“无程序化物品”。

## 14. Autoload 与 save

`obj/user.c` 组合 `F_AUTOLOAD` 和 `F_SAVE`。`feature/autoload.c` 的真实行为为：

1. 保存时只枚举 `all_inventory(user)`，即直接 inventory；nested contents不会独立保存。
2. 只保留 `query_autoload()` 返回 truthy 的对象。
3. 存储字符串是 `base_name(item)`，可选附加 `":" + string parameter`。
4. 恢复时只用 `catch`包住 `new(file)`；实例化失败才记录并continue。成功实例随后先
   `move(user)`，再调用 `item->autoload(parameter)`。
5. 全库没有活动 `init_autoload()` 实现；实际协议名是 `autoload()`。

`move()`返回值被完全忽略：容量或其他move失败时仍调用 `autoload(param)`，对象可留在其原
environment（新clone通常是null environment）。`autoload()`本身也没有catch；callback抛错会
中断restore loop并可能阻止最后的 `clean_up_autoload()`。missing callback在部署driver中是返回0
还是runtime error，mudlib没有给出可靠规则，必须视为runtime-semantics ambiguity。

活动 `query_autoload()` 来源：

- `std/money.c`：参数是 amount，恢复 stack数量；
- `obj/bandage.c`：仅 equipped bandage自动保存；参数为名称，恢复为 blood_soaked=3并重新 wear；
- `obj/marry_card.c`：伴侣名及在线通知；
- `obj/token.c`：guild ID，且对象另有自己的 F_SAVE 外部状态；
- `obj/roommaker.c`：返回 1，但未发现对应 `autoload()`；因为上述missing-lfun语义未证明，
  这是可疑协议缺口/runtime ambiguity，不能直接断言恢复必然成功或必然报错。

`obj/prize/black_vest.c` 只有注释掉的 query_autoload，不算活动实现。

普通非-autoload inventory **不在 user save 中持久化**。`cmds/usr/quit.c` 对普通玩家先把所有
非-autoload直接物品 drop，再保存并销毁 user；wizards 跳过 drop，但普通 item object也没有
通用恢复数据。通用 equipped/worn state不保存，只有 bandage 这种物件自定义 restore重新穿戴。

未来 native save 应保存 typed ItemInstance DTO、递归 containment graph和 equipment instance IDs；
autoload只应作为旧存档导入/特殊持久化 policy的证据。不能继续保存可执行 LPC path + 任意
colon string。该格式还无法稳健处理参数自身含冒号。

通用装备状态没有被序列化或恢复。money只恢复amount；bandage是唯一确认在自己的autoload中
调用base `wear()`恢复worn状态的物品。其他weapon/armor没有generic slot reconstruction。

## 15. 尸体与死亡转移

来源为 `adm/daemons/chard.c` 和 `obj/corpse.c`：

- ghost死亡：枚举 victim直接 inventory，批量调用 `owner_is_killed(killer)`，移除已被销毁而
  变成 0 的条目，再把剩余物品直接 move 到死亡房间；不创建 corpse。
- 非 ghost：先在房间创建 corpse，复制 victim name/gender/weight，并把 corpse容量设为 victim
  当前最大负载。
- 非 wizard victim：同样只枚举直接 inventory并先调用 death hook。worn item先 move(corpse)，
  低层因此先卸装，然后尝试在 corpse上 `wear()`；失败则落到死亡房间。wielded item走普通分支，
  move 时卸下，不会在尸体重新 wield。
- wizard victim：代码跳过 inventory transfer，防止非法物进入尸体。
- nested contents不会逐件枚举；它们随直接父容器整体移动，也不会逐件收到
  `owner_is_killed()`。
- autoload物没有死亡豁免；是否销毁只由 death hook决定。
- corpse只是 containment endpoint，没有 claimant/loot owner字段。

chard忽略所有item `move()`返回值。特别是worn分支不先确认move成功就调用`wear()`：若corpse
capacity不足，物品会留在victim但已被move尝试卸装，随后又可能在victim上重新wear成功；普通/
wielded分支move失败则可留在victim并保持已卸装。正常情况下corpse capacity复制victim最大负载，
但over-capacity或损坏状态仍可触发该边界。

Corpse 在 120 秒、再 120 秒、再 60 秒三个 call_out阶段腐烂；最终阶段把所有直接 contents
移到周围 environment 后销毁。计时属于未来 runtime scheduling，不属于 Inventory core。
最终释放也忽略每件move返回值；正常room容量足够时会散落，失败后仍留在corpse的物品随后随
corpse销毁。

`animate()` 创建zombie后直接destruct corpse且不搬contents。driver `move_or_destruct` 文档明确：
environment被销毁时contents必须自行移到外层，否则也被销毁；全库唯一active实现
`feature/move.c::move_or_destruct()`只为user移动到VOID，普通item返回而不move。因此当前标准
Item contents会确定地随animate corpse销毁，不再只是推测。自定义override未找到。

腐烂phase 1的gender inner switch没有break；LPC switch文档明确采用C fall-through，所以男性、
女性最终都会继续执行default并得到通用“腐烂的尸体”名称。这是确定的presentation行为。

Death/Combat 未来必须通过 death resolution结果调用 narrow corpse/loot service，不能让
Combat daemon直接遍历 CharacterState Dictionary或操作 World Nodes。

## 16. Legacy 缺陷与歧义清单

| 现象 | 分类 | 审计结论 |
|---|---|---|
| partial get对象/数量颠倒 | 确定的可执行缺陷 | 非living来源取得 `N-A`而留下`A`；living来源还会先merge再覆盖，造成数量丢失 |
| `set_amount(0)`延迟销毁 | 确定的可执行怪异点；产品决定 | 一秒内旧amount/weight不变，不可默认为即时零量 |
| merge/split只保留amount | 结构限制/风险 | 源码确定不复制override；当前普通combined内容的数据损失未逐项证实，不能一概称现存缺陷 |
| `base_weiht` | likely typo但可执行 | snake drug的真实`base_weight`为0，`set_amount(1)`得到0 weight |
| dbase `value`与method `value()` | 协议分裂 + runtime ambiguity | money定义method；大多数item只有dbase value，缺失lfun行为影响give/NPC路径 |
| display/aliases比较 | 确定的脆弱authored行为 | general等按name匹配；不代表display name应成为native identity |
| 不同path不merge/autoload同定义 | 确定行为，不是自身缺陷 | `base_name`就是legacy definition compatibility key |
| 角色slot与item marker双写 | 确定架构怪异点 | 正常路径同步，raw dbase可制造不一致；native已有单权威决定 |
| low-level equip授权不足 | 确定边界 | 只验证environment是某个character；command层才验证当前操作者direct inventory |
| detach早于destination/capacity | 确定partial mutation | 失败可保持原parent但已卸装；full transition不原子 |
| command split早于最终gate | 确定partial mutation | get/put及boolean `no_drop`的drop可在拒绝前已拆stack |
| Container协议分裂 | 确定架构怪异点 | `is_container`未被消费；capacity、put/get规则各自决定 |
| `feet`/`boots`及heterogeneous props | 确定active data，不是缺陷 | 要求开放slot和分离numeric/presentation effects |
| standard armor dodge键 | likely typo且可执行 | 11个标准armor检查`armor_apply/dodge`却写`armor_prop/dodge`，可能覆盖已有值 |
| roommaker autoload无callback | 协议缺口 + runtime ambiguity | query确定存在、callback确定缺失；missing-lfun后果不明 |
| autoload忽略move result | 确定partial behavior | move失败仍调用autoload；callback error也未catch |
| corpse animate contents | 确定可执行行为 | driver规则 + 唯一move_or_destruct实现证明普通item随corpse销毁 |
| corpse gender switch | 确定presentation缺陷 | 无break导致male/female均fall through到default |
| general重复“印鉴”判断 | unreachable/dead | 第二个完全相同condition不可达 |
| money与普通combined value | 确定协议差异，不是自身缺陷 | 只有money method明确按amount乘base_value |
| NPC valuable give | 确定行为（受value method语义制约） | 非interactive先accept；非user且value truthy随后销毁，不move |
| magic seal `equipped="sealed"` | 确定marker过载 | custom unequip清marker，不属于hand/armor slot |
| 六份skirt custom `wear()` | 确定authored quirk | female路径忽略base `::wear()`结果并统一返回1，可把真实slot拒绝表现成command成功 |
| chard忽略item move结果 | 确定partial behavior | corpse transfer/re-wear在capacity失败时可留下异常ownership/equipment状态 |

这些不应在数据导入或 native core中悄悄“修好”。每项进入实际实现时应选择精确兼容、
typed替代或显式修复并记录。

## 17. 推荐 native 架构

### 17.1 数据和状态

```text
ItemDefinition (immutable authored data, stable definition ID,
                legacy source path; later typed components)
          ↓ referenced by
ItemInstance (stable instance ID, definition ID; later narrow typed mutable states)
          ↓ one parent/location
InventoryState (containment graph, direct members, ancestry, weights)
```

`ItemDefinition` 可用 typed Resource或纯 definition object，只有编辑器 authoring确有收益时才
使用 Resource。组件应按证据拆分：container capacity、stack policy、weapon facts、armor facts、
consumable、study source、save policy等；不要建立任意 property Dictionary作为 LPC dbase替身。

`CombinedStackState`应只附着于明确stack-capable的ItemInstance，拥有amount及其zero lifecycle；
普通ItemInstance不应被迫带quantity。`ArmorState`同样是角色装备aggregate，不是每件物品上的
generic state bag。

`ItemInstance` 是纯领域状态，不是 Node。World 中可见的拾取物 Node只持/引用 instance ID，
位置与动画由 World Runtime负责。

`ItemCatalog`/`ItemRepository`不是Phase 4B1必须的domain abstraction。immutable definition lookup
以后可以是caller传入的接口、Resource集合或application content service；runtime instance集合也可
由save/session/inventory aggregate拥有。只有当跨aggregate lookup需求出现时才命名repository，
不要为了两个ID value object预建global service。

### 17.2 Character、Inventory、Equipment 的依赖方向

```text
CharacterState
  ├─ InventoryState / Inventory owner reference
  └─ EquipmentState (ItemInstanceId slots only)

InventoryTransferService
  ├─ receives immutable definition lookup + authoritative item state
  ├─ validates containment/capacity/policies
  ├─ coordinates Equipment detach when leaving direct ownership
  └─ emits typed transfer/lifecycle results

ArmorState
  └─ ItemInstanceId per open armor slot + typed modifier projection
```

为避免循环所有权，建议 CharacterState组合角色自己的 InventoryState与 EquipmentState，但跨角色、
容器、World、corpse转移由外层 domain service协调。Equipment/Armor不拥有 ItemInstance生命周期；
Inventory也不重新实现手槽选择规则。Combat只读取 immutable snapshots/projections和 structured
results，不直接 mutation inventory tree。

权威职责应明确为：ItemDefinition lookup只提供immutable内容；ItemInstance/InventoryState拥有
runtime identity、lifecycle与containment；InventoryTransferService只orchestrate有序规则而不成为
第二份状态；World adapter只把instance ID映射到scene表现。CharacterState可拥有一个inventory root
或其窄引用，具体session级存储形态延后，不要求Inventory与Equipment互相引用。

### 17.3 明确不应放置的位置

- 不在 `CharacterState` 添加 item dbase Dictionary或任意 payload。
- 不把 general inventory、container children或物品定义塞进 `EquipmentState`。
- 不把权威 ItemInstance放进 Node/scene object；Node只是物理表现/交互 adapter。
- 不做 LPC object wrapper、`environment()`模拟器、path-based `call_other()` dispatcher。
- 不用 Autoload singleton保存所有实例；持久化和游戏 session ownership另行设计。
- 不让 ItemDefinition携带运行时 callable closures；authored procedures用 stable-ID typed registry。

## 18. 推荐增量实现顺序

### Phase 4B1：Item Identity + Definition/Instance Foundation

只建立identity与definition/instance分界，最小字段为：

- `ItemDefinition`：`item_definition_id: StringName`、`legacy_source_path: String`；
- `ItemInstance`：`item_instance_id: StringName`、`item_definition_id: StringName`。

两者应是typed pure domain value/state、definition identity不可变，并测试同一definition可产生
多个互不共享的instance identity。此阶段不需要ItemCatalog、ItemRepository、factory service或
generic component map。

Phase 4A1 `WeaponDefinition.weapon_id`应被书面定义为同一个stable ItemDefinitionId语义；
`EquippedWeaponRef.instance_id`对应ItemInstanceId。现有`skill_type`、secondary/two-handed facts可继续
作为immutable、经过构造校验的projection，不在4B1改EquipmentState。无需在ItemDefinition中再次
加入一份generic weapon component来“接管”它。

name/aliases/short/long/unit、base weight/value、quantity、container capacity、inventory parent、
world position、Armor、save DTO、procedural callback、mutable override全部延期。它们都有后续证据，
但都不是建立两个identity层所必需，过早加入反而会在schema尚未审计完成时固化错误边界。

这是**下一项唯一推荐实施阶段**。它先解决所有后续系统共同依赖的 identity与 definition/
instance分界，且可以在不触碰 containment和 Combat的情况下用纯领域测试闭合。

### Phase 4B2：Inventory Containment + Transfer Core

实现单父关系、direct/root ownership、cycle防护、nested weight、capacity输入和 typed transfer
result。接入 Equipment移走前 detach及 ownership invariant；明确记录“卸装后容量失败”是否精确
兼容。暂不实现 authored NPC/quest/world policy。

### Phase 4B3：Combined / Currency / Consumable Instance Semantics

实现显式 stack policy、amount、split/merge、重量/价值及零量生命周期；先覆盖 money和 throwing
所需形状。对 get split defect、mutable-state merge和延迟销毁做书面行为决定。Food/liquid的资源
效果可再按独立小阶段接入，不能顺带实现 Condition/Combat runtime。

### Phase 4B4：Armor Foundation + Equipment/Inventory Integration

实现开放 slot ID、ArmorState、typed numeric modifier aggregation、shield事实来源、wear/remove与
transfer/death detach。presentation伪装和 gender eligibility由窄 policy处理。此阶段后可为 Combat
提供完整 armor projection。

### Phase 4B5：Persistence / Corpse Domain Boundaries

定义递归 ItemInstance save DTO、旧 autoload import、corpse transfer/decay outcomes和 death item
policy接口；调度与 World实体仍不在 Game Core。

### Phase 5A：Combat Dependency Analysis / Minimal Core

在 ItemInstance、direct ownership、Equipment ref与Armor projection稳定后，实施确定性基础命中/
伤害 core。高级 weapon actions、hit hooks、throw/break、death runtime和表现分别增量接入。

此顺序保留“语义先于 runtime”的边界，也避免为了启动 Combat而先造完整内容库。
