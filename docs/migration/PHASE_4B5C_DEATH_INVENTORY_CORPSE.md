# Phase 4B5C：Death Inventory + Corpse Foundation

## 范围与结论

本阶段只实现 `CHAR_D->make_corpse()` 所需的纯领域死亡物品与尸体语义。它接收已经由外层决定的
死亡上下文，不实现 `feature/damage.c::die()` 的复活检查、immortal wizard 提前返回、Condition
清理、Combat 公告、killer reward、队伍/敌对清理、玩家 ghost 转换或 NPC body 销毁。

实现为 typed `RefCounted` GDScript；没有 Node、Timer、SceneTree、World/NPC runtime、Combat、UI、
通用 callback dispatcher、ItemCatalog/Repository 或存档 schema 变更。`reference/es2/` 保持只读。

## 权威 LPC 来源

逐行复核：

- 死亡边界：`reference/es2/mudlib/feature/damage.c`、`std/char.c`、`std/char/npc.c`；
- death inventory：`reference/es2/mudlib/adm/daemons/chard.c`；
- 尸体：`reference/es2/mudlib/obj/corpse.c`；
- 移动/装备/销毁：`feature/move.c`、`feature/equip.c`、`std/equip.c`、
  `adm/simul_efun/object.c`、`doc/efuns/destruct`、`doc/applies/move_or_destruct`；
- 三个 active death hooks：`obj/mailbox.c`、`obj/roommaker.c`、
  `daemon/class/scholar/windspring.c`；
- windspring 依赖：`daemon/class/scholar/sword_soul.c`；
- corpse consumers：内容相同的 `daemon/class/taoist/animate.c`、
  `daemon/class/taoist/necromancy/animate.c`、`d/skill/necromancy/animate.c`，以及
  `obj/npc/zombie.c`；
- 自定义 wear：`obj/bandage.c`，以及
  `d/latemoon/{obj,npc/obj}/skirt.c`、`skirt4.c`、`skirt5.c`。完整复扫还确认
  `skirt2.c`、`skirt3.c`、`skirt6.c` 没有覆盖 `wear()`，只使用标准 `feature/equip.c` 行为；
- 标准 Armor 槽：`include/armor.h` 与 Phase 4B4 已复核的 `std/armor/*` inheritance。

另对完整 mudlib 复扫 `owner_is_killed`、`make_corpse`、`is_ghost`、`wizardp`、`corpse`、
`is_corpse`、`is_character`、`decayed`、`decay(`、`animate(`、`wear(`、`unequip(` 与
`destruct(`。`owner_is_killed()` 的 active authored definition 仍精确为三份；除
`feature/move.c` 外，物品只在 `std/item/combined.c` 覆盖 `move()`，其 living-only 合并不适用于尸体。

## `die()` 与本阶段的边界

`feature/damage.c:130-161` 的外层顺序为：必要时 revive → immortal wizard return → clear
conditions → announce → killer reward → `make_corpse()` → corpse 再次 move → combat/team cleanup →
user ghost transition 或 NPC destruction。本阶段仅实现 `make_corpse()` 的 inventory/corpse 领域，
不会提前接管其他步骤。第二次 corpse move 也留给未来 death runtime adapter。

## DeathContext

`DeathContext` 是无 setter 的一次性事实投影，精确包含：

- `victim_character_id`；
- `victim_is_ghost`、`victim_is_wizard`；
- 已解析的 logical `victim_environment` transfer destination；
- 与 victim ID 绑定且同时含 Equipment/Armor authority 的 `ItemLifecycleOwnerContext`；
- victim display name、gender、age；
- victim `query_weight()` 的 own/body weight 快照；
- victim `query_max_encumbrance()` 快照；
- windspring 所需的 `victim_matches_sword_soul_alias`；
- killer 是否存在，以及存在时的可选 logical endpoint；killer不存在才按 LPC 回退owner endpoint，
  killer存在但尚无可解析environment则返回dependency unavailable；
- 三个独特自定义裙款（两套目录共六份文件）动态 `this_player()->query("gender")` 所需的可选
  legacy rewear actor gender。

它不持有 CharacterState、CombatState、Node、物理坐标或通用 Dictionary。最后一项不能用 victim
gender 替代：LPC 明确读取 `this_player()`，该 runtime 身份在 heartbeat/callout 路径可能缺失。

## Direct snapshot 与确定顺序

服务只 snapshot：

`InventoryState.direct_children(CHARACTER(victim_character_id))`

Bag 的 nested child 不单独执行 death policy；Bag 成功移动时 subtree 自动跟随。Snapshot 在任何
policy mutation 前建立。Native 使用 stable instance ID 升序执行 policies；幸存者按该 snapshot
逆序（降序）转移，以保留 `chard.c` 的 reverse survivor loop。最终 corpse scatter 对 direct
contents 使用升序。MudOS object-chain 次序不是 authored 数据；这一可观察替代已记录于
`DECISIONS.md`。

## DeathItemPolicy

`DeathItemPolicyRegistry` 只接受 stable `ItemDefinitionId -> DeathItemPolicy` 显式注册；没有
`call_other()`、路径 dispatch、callback string 或 Variant payload。未知 definition 默认 `KEEP`。
`DeathItemFacts` 必须由一个不可变 `ItemInstance` 投影构造，并从同一对象同时取得 instance ID 与
definition ID；接口不再允许把一个 live instance ID 与另行传入的其他 definition ID 配对。该窄投影
仍不是 ItemCatalog/Repository，调用方负责提供当前 live instance 的快照。
由于 Phase 4B5C 禁止 authored item bulk migration，core 不发明三件物品的 native definition ID；
content/application composition 在有正式 ID mapping 时注册：

| LPC definition | typed policy | 精确效果 |
| --- | --- | --- |
| `obj/mailbox.c` | `DestroyDeathItemPolicy` | `DESTROY_ITEM`，经 Lifecycle `DESTROY_SUBTREE` |
| `obj/roommaker.c` | `DestroyDeathItemPolicy` | 同上；不混入 autoload |
| `daemon/class/scholar/windspring.c` | `WindspringDeathItemPolicy` | owner 是 `sword soul` 时 KEEP；否则 deferred spawn intent |

Windspring 非 KEEP 分支的 LPC 顺序是 create/move sword_soul → reset/chant → destruct sword。Core
返回 `DeferredNpcSpawnIntent`，携带 source item ID、logical endpoint、legacy NPC source metadata，
并声明 `SPAWN_RESET_CHANT_THEN_DESTROY_SOURCE`。由于尚无 native NpcDefinition mapping，
`npc_definition_id` 保持 unresolved；服务在该 item 停止，不把剑当普通 survivor，也不提前销毁。
此前已完成的 policy destruction 不回滚。

每次 `DESTROY_ITEM` 都保留完整 `ItemLifecycleResult`，包括失败结果与已经发生的 hand/Armor detach。
因此 `destroyed_instance_ids` 只列实际移除项，不能掩盖“物品仍 live 但部分 authority 已清理”的失败。

## Ghost、wizard 与 normal 分支

- Ghost 优先于 wizard：执行 direct policies，逆序逐件尝试 move 到 victim environment，忽略普通
  move failure并继续，不创建尸体。失败前成功的 hand/Armor detach 不回滚；ghost 没有 corpse rewear。
- 非 ghost 先注册 ordinary corpse `ItemInstance`、以 victim own weight 登记、尝试放入 victim
  environment并创建初始 decay intent，然后才检查 wizard。
- Wizard 得到已创建/已尝试放置的空尸体；不运行 policies，不转移 inventory，victim direct items
  保持原 parent。
- Normal 在 corpse 创建后运行 policies，再按逆序逐件转移。每次 move 结果均记录；普通失败不会
  停止后续 item，也不会回滚先前成功项。

Windspring 已形成 spawn intent 时返回 `DEFERRED_RUNTIME_EFFECT`；killer存在但其environment不可解析时
返回独立的 `POLICY_DEPENDENCY_UNAVAILABLE`，不会把“尚无可执行intent”伪装成 deferred effect。
这些 Windspring runtime dependency、裙子动态 actor dependency，以及发生过部分 mutation 的 policy
destruction failure 都返回 `BLOCKED_INCOMPLETE` 与 `DO_NOT_RESTART_FROM_BEGINNING`。这不是 continuation
token或调度器：本阶段没有 resume API。调用方必须保留 typed 结果与当前权威 aggregates，不能从
`process()` 起点盲目重放（normal 分支可能已经创建尸体，且先前 policy/move/detach 可能已生效）。
未来 runtime adapter 完成窄依赖后应使用专门的后续编排，而不是重新执行整个死亡物品流程。

Corpse placement 复用 `InventoryTransferService` 并保存结果。失败时 corpse 仍是 live unparented item，
后续可证明的 corpse-content 处理继续；不制造 World fallback。`damage.c` 的第二次 move 明确延期。

## CorpseState 与权威分工

`CorpseState` 精确保存：

- corpse ItemInstance ID；
- victim stable character ID、display name、gender、age snapshots；
- `decay_stage`；
- maximum contents encumbrance；
- narrow exact `armor_type -> item_instance_id` corpse-worn projection。

它不是 CharacterState，也不保存 parent、children、own weight、stack、EquipmentState、ArmorState 或
numeric modifiers。`InventoryState` 仍唯一拥有 corpse liveness、parent、own weight与contents；
`CombinedStackCollection` 仍拥有 amount association。应用在 Lifecycle 确认 corpse ID 被移除后丢弃
CorpseState，不添加 `destroyed` flag。

尸体内容 endpoint 仍为 `ContainmentEndpoint.ITEM(corpse_item_instance_id)`，没有 CORPSE kind。
最大内容负载来自 victim death-time max encumbrance；衰变不改变它。

## Wielded / worn 与重穿

Wielded item 走普通 transfer：先 unwield，再验证 corpse capacity。成功后进入 corpse 且不重持；
失败则可留在 victim direct inventory但保持 unwielded。

Worn item 的顺序严格为：在 reverse survivor loop 处理到该物品时读取当前 worn status →
transfer(corpse)（先从 victim Armor detach）→ 不论 transfer 成败都执行 source-equivalent rewear →
rewear report false 时尝试 move 到 victim
environment。若 transfer 失败后 parent 仍是 victim，generic base rewear 通过 `ArmorService.wear()`
恢复 victim Armor contribution；这不是 transaction rollback。

Corpse 不获得 ArmorState。Generic base wear 只把 exact slot/instance 写入 `CorpseState` projection；
`boots` 与 `feet` 保持独立开放槽。Fresh slot collision返回 false并触发 room fallback。

`DeathRewearPolicyRegistry` 只表达 active authored 差异：

- Bandage：`wear()` 固定返回 0且不调用 base，所以必走 fallback；
- 三个独特 authored skirt（`skirt.c`、`skirt4.c`、`skirt5.c`，各自在 `obj` 与 `npc/obj`
  重复一份）：动态 actor不是 `女性`时返回 false；是`女性`时调用 base但忽略其结果并总返回1，故
  slot collision可使物品仍在 corpse但未穿戴，并抑制 fallback；
- actor gender 未提供时返回 typed dependency unavailable，并保留此前完成的 move/detach。

这不是 generic wear callback executor，也没有迁移 bandage condition、female_only command gate或文本。

## Corpse-worn compatibility quirk

Fresh stage 0 满足 `is_character()`，所以 corpse-worn item 可先清投影再尝试转移；目的地失败不会
恢复投影。第一次 decay 后 `is_character()` 为 false，而旧 equipped marker 在 LPC 中保留；以后
`move()` 的 unequip失败使物品锁在 corpse。

`CorpseContentTransferService` 保留这个规则：stage 0 可 release；stage >= 1 返回
`CORPSE_WORN_LOCKED`。规则不进入 generic InventoryState。最终 scatter 同样使用此 gate，所以锁定
护甲失败留在 corpse，并由最终 Lifecycle subtree destruction移除。这是兼容原行为，不是现代化。
`CorpseState._try_wear()` 还要求目标 item 当前 live 且是该 corpse 的 direct child，避免一开始就产生
悬空投影。所有 4B5C 内部取出/最终 scatter 路径均经过 corpse-aware gate。

`InventoryTransferService` 本身仍不知道 corpse-worn projection，因此外部若绕过 gate 直接搬运尸体
内容，确实可能制造 stale projection。这不是许可；未来 loot/get、corpse-aware move以及直接销毁
编排都必须路由 `CorpseContentTransferService` 或同等窄 orchestration。Phase 4B5C 不为此扩展通用
Inventory API，也不实现 command/runtime adapter。

## Decay intents 与 final scatter

纯状态机与 source exact timing：

| 当前阶段 | 下一阶段 | intent delay |
| --- | --- | ---: |
| 0 fresh | 1 rotten | 120 秒 |
| 1 rotten | 2 skeleton | 120 秒 |
| 2 skeleton | 3 final | 60 秒 |

Intent 只含 corpse ID、expected stage、next stage、delay；没有 Timer、Callable、method name或调度。
Transition拒绝 ID mismatch、错误current/next、skip/reverse及错误delay，并要求 corpse仍由
InventoryState登记。

Final transition先写 stage 3，再 snapshot direct corpse contents。若 corpse有parent，caller必须提供
与该parent一致的 destination projection；服务逐件尝试 transfer并忽略普通失败。随后无条件调用
`ItemLifecycleService.destroy_item(..., DESTROY_SUBTREE)`：成功散落项存活，失败项和 corpse-worn项
随 corpse按stable post-order移除，stack association同步清除。若 corpse无parent，不作scatter，整个
subtree直接移除。结果保存每次尝试及最终 Lifecycle evidence；无rollback。
若最终 Lifecycle 因缺少 direct-character owner context 等原因失败，结果为
`FINAL_DESTRUCTION_FAILED`：stage 3 与此前成功 scatter 保持生效，corpse 仍 live，失败事实不会被
伪装成 finalized。尸体 own weight 不计入其 contents capacity；内容总重恰好等于 maximum 时允许转入。

`obj/corpse.c` phase1 gender switch无 break，最终对男性/女性均落到generic rotten presentation；这是
表现缺陷，本阶段只记录，不污染 gameplay state。

## Animate、World/NPC 与持久化延期

`animate.c` 只接受 stage0/1 `is_corpse()` target；`corpse->animate()` 要求environment，创建/移动/
配置 zombie后才 destruct corpse且不搬contents。由于尚无 NPC runtime和安全 completion handshake，
本阶段不返回一个会误导caller立即destroy的“半完成”API；animate整体作为明确 typed-runtime dependency
延期到拥有 spawn completion语义的阶段。现有 Lifecycle `DESTROY_SUBTREE` 已能在未来正确表达其最终
contents destruction。

World Runtime仅需以后把 logical endpoints绑定到map/zone/position；本阶段不加载scene或验证物理位置。
Phase 4B5A schema仍为 v1，未增加 corpse/death/pending字段。Active corpse runtime persistence与
legacy autoload importer都延期。

## Phase 4B5D 及后续依赖

明确延期：Combat resolver、death/revive/ghost character lifecycle、killer rewards、condition cleanup、
team/enemy cleanup、NPC body destruction、sword_soul/zombie runtime、actual scheduling、World Nodes、
corpse loot/get adapters、presentation、active corpse persistence以及 command policies。Phase 4B5D不得
把本阶段结果误当成完整 `die()`。
