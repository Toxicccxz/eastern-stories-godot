# Phase 4B5A：Native Item Save DTO + Restore Validation Foundation

## 范围与结论

本阶段实现 item-domain 的纯 typed snapshot、确定性 capture、完整 prevalidation 和 fresh aggregate
reconstruction。没有文件 IO、JSON/Resource/binary 格式、save slot、World scene、legacy autoload
import、corpse/death、lifecycle、scheduler、Combat、NPC、UI、Catalog 或 Repository。

Phase 4B5 依赖分析已经证明 LPC user save 不是递归 inventory save。本阶段有意现代化：保存所有
当前 native 领域明确表示的 live ItemInstances、containment、stack amount、hand refs 和 armor refs，
不复制 autoload-only 数据丢失。该决定已写入 `DECISIONS.md`。

## 来源

Native 权威实现：

- `game/core/items/item_definition.gd`、`item_instance.gd`
- `game/core/inventory/containment_endpoint.gd`、`inventory_state.gd`、
  `inventory_transfer_service.gd`
- `game/core/equipment/weapon_definition.gd`、`equipped_weapon_ref.gd`、
  `equipment_state.gd`
- `game/core/armor/armor_definition.gd`、`equipped_armor_ref.gd`、
  `armor_numeric_modifiers.gd`、`armor_state.gd`
- `game/core/items/combined/combined_stack_definition.gd`、`combined_stack_state.gd`、
  `combined_stack_collection.gd`、`combined_stack_service.gd`

重新核对的 LPC 上下文：

- `reference/es2/mudlib/feature/autoload.c`
- `reference/es2/mudlib/feature/save.c`
- `reference/es2/mudlib/obj/user.c`
- `reference/es2/mudlib/cmds/usr/quit.c`
- `reference/es2/mudlib/std/money.c`
- `reference/es2/mudlib/obj/bandage.c`
- pending-zero 语义继续以 `reference/es2/mudlib/std/item/combined.c` 为依据。

## Schema version 与快照根

`NativeItemStateSnapshot.CURRENT_SCHEMA_VERSION == 1`。非 1（包括零、负数和未知正数）均返回
`INVALID_SCHEMA_VERSION`；本阶段不建立 migration pipeline，也不把 legacy autoload format当成
native schema version。

根形状：

```text
NativeItemStateSnapshot
  schema_version: int
  item_records: Array[NativeItemRecord]
  combined_stack_records: Array[NativeCombinedStackRecord]
  character_equipment_records: Array[NativeCharacterEquipmentRecord]
  character_armor_records: Array[NativeCharacterArmorRecord]
```

所有 record 都只含 scalar/value snapshots。数组 getter、armor slot getter 和 parent getter均返回
防御性副本，不保留 InventoryState、EquipmentState、ArmorState、CombinedStackState 或 mutable
ItemInstance 引用。

## Record 形状

```text
NativeItemRecord
  item_instance_id: StringName
  item_definition_id: StringName
  own_weight: int
  direct_parent: ContainmentEndpoint?  # null = live unparented

NativeCombinedStackRecord
  item_instance_id: StringName
  amount: int

NativeCharacterEquipmentRecord
  character_id: StringName
  primary_item_instance_id: StringName?   # empty = absent
  secondary_item_instance_id: StringName? # empty = absent

NativeCharacterArmorRecord
  character_id: StringName
  slots: Array[NativeArmorSlotRecord]

NativeArmorSlotRecord
  armor_type: StringName
  item_instance_id: StringName
```

Parent直接复用 `ContainmentEndpoint` 的 `CHARACTER / ITEM / WORLD`。尸体仍应在未来表示为
`ITEM + corpse ItemInstanceId`，没有新增CORPSE endpoint。Snapshot不保存root holder、ancestry、
children、subtree weight或contents weight；这些都从flat direct-parent graph派生。

Logical WORLD ID按值验证和恢复，但本阶段不检查scene/map存在性、不绑定Node或physical position。

## Own weight 与 stack

`InventoryState.own_weight` 是当前唯一权威，所以snapshot保存并原值恢复任意int，不clamp也不按
definition重算。原因包括：raw-zero stack可有独立weight；显式`set_amount(0)`保持旧weight；未来
窄型mutable state也可能改变当前weight。

Stack record只保存amount。Compatibility ID、base weight及其他immutable stack facts来自调用方提供的
`NativeItemDefinitionProjections`。Phase 4B3 的完整实例不变量是双向的：definition具有
`CombinedStackDefinition` projection的每个live item必须恰有一个`CombinedStackState`；普通definition
不得有该state。Validator既拒绝orphan/non-stack/negative/duplicate record，也拒绝stack-capable item
缺少record，避免唯一amount权威静默消失。Capture同样经完整validator拒绝缺少stack state的live实例，
不会发出不完整snapshot。Amount 0是合法live raw state；restore直接注册state，不调用
`CombinedStackService.set_amount(0)`，所以不会制造delayed destruction intent。

Schema v1也不保存已经存在的pending one-second destruction intent。若capture发生在LPC式
`set_amount(0)`窗口，snapshot看到的仍是旧正amount/weight；load后它作为普通live stack存活。这一
兼容选择已单独写入`DECISIONS.md`。

Definition的base weight以后改变时，amount按存档恢复，own weight仍按存档恢复；两者可能不再符合
当前definition公式。本阶段不静默改写权威saved state。

## Definition lookup 边界

`NativeItemDefinitionProjections` 是单次capture/restore调用显式传入的只读内容投影，不是global
Catalog/Repository。它提供：

- known ItemDefinition identity；
- optional WeaponDefinition；
- optional ArmorDefinition；
- optional CombinedStackDefinition。

它在构造时复制immutable scalars并拒绝空、重复、无base item identity或无效projection。Snapshot不
重复保存legacy path、skill type、weapon flags、armor modifiers、stack compatibility或base weight。

Definition内容改变但ID和协议仍兼容时：weapon facts、armor slot/modifier snapshot和stack immutable
facts使用load时的当前projection；ItemInstance identity、amount、parent和own weight仍来自存档。
Definition消失或协议不兼容则typed reject。Content revision pinning延期。

## Capture 与确定性顺序

`NativeItemStateCapture.capture()` 由调用方显式提供ItemInstance集合、InventoryState、
CombinedStackCollection以及per-character Equipment/Armor sources。它不创建global item registry。

Capture先验证：

- 每个显式ItemInstance唯一、非空且已在同一InventoryState注册；
- Inventory没有未被显式集合表示的live item；
- Combined没有orphan或definition-identity失配；
- 每个stack-capable live item均有amount state；
- live Equipment/Armor ref identity没有与ItemInstance失配；
- 生成的完整snapshot通过同一个validator。

Equipment/Armor source数组是调用方对本次item-domain capture范围的显式声明；core没有Character registry
可据以发现未提供的角色aggregate。对已提供source，capture逐一完整记录槽位，并拒绝同一character ID
重复source。`character_id`只验证为非空stable logical ID；所有非空槽位引用还必须是对应
`CHARACTER(character_id)`的direct child，不要求CharacterState/scene/entity lookup。空Equipment record
和空Armor record均合法，分别显式表示空双手与零穿戴槽，但character ID仍不得为空。

稳定顺序为：items和stacks按instance ID；Equipment/Armor records按character ID；Armor slots按exact
armor type。排序只服务确定性diff/test，不参与gameplay identity。

## 完整 prevalidation

`NativeItemStateValidator` 按以下顺序验证，任何失败均返回typed outcome：

1. snapshot与schema version；
2. definition projections；
3. item record形状、唯一identity和known definition；
4. parent endpoint、missing ITEM parent、自环和任意深度cycle；
5. stack reference、definition、非负amount、唯一record及stack-capable item的state完整性；
6. Equipment character、item存在性、direct CHARACTER ownership、weapon projection、重复hand；
7. Armor character、exact slot、item存在性、direct ownership、definition/slot一致、重复slot/
   instance及hand/armor冲突。

不silent repair、不skip record、不drop child。Corrupt snapshot返回`NativeItemStateValidationResult`，
restore result的reconstructed state为null。

Equipment structural validation保留Phase4A1正常可达形状：secondary-only不提升；secondary必须是可作
secondary且非two-handed的definition；`TWO_HANDED | SECONDARY`可保留在primary，但按原始分支顺序
不能占secondary。Two-handed primary加后续secondary或后来穿shield不被“正常化”。不重跑操作时
shield admission或槽位选择。

Armor使用开放非空StringName；`boots`、`feet`、`bandage`等exact slot不归一化。Female-only、skirt、
bandage condition和authored hooks都不属于结构restore。

## Fresh reconstruction 与 trusted seams

只有整个snapshot预验证成功后，`NativeItemStateRestorer`才创建fresh：

1. ItemInstances与InventoryState registration，原值写入own weight；
2. 通过`InventoryState._apply_reparent()`建立flat parent graph；
3. 通过`CombinedStackCollection._register_stack()`恢复amount，不触发weight公式或zero intent；
4. 从当前WeaponDefinition重建refs，通过`EquipmentState._restore_weapons()`一次写入fresh hand state；
5. 从当前ArmorDefinition重建refs/modifiers，通过`ArmorState._restore_equipped_refs()`写入fresh slots；
6. 返回`NativeItemDomainState` bundle。

这些下划线seam仍验证核心结构，只绕开gameplay transition。失败中的temporary fresh objects不暴露；
成功bundle由application/session决定是否采用，没有global install。

Restore不调用：

- `InventoryTransferService.transfer()`：会detach、做capacity gate并允许partial mutation；
- `EquipmentState.wield()`：会重跑slot选择、two-handed/shield gate及历史顺序；
- `ArmorService.wear()`/`ArmorState._apply_wear()`：会把load变成逐件gameplay operation。

## Capacity、原子性与独立性

Restore不接受capacity projection，也不执行capacity gate。只要parent graph结构合法，即使saved
character/container当前over-capacity也恢复；未来普通移动继续使用`InventoryTransferService`的当前
capacity规则。

Native restore与legacy autoload的partial-success loop不同：先完整验证，再构造fresh state；成功返回
完整bundle，失败返回null bundle。对同一snapshot两次restore产生互不共享的Inventory、Combined、
Equipment与Armor aggregates。

## 测试覆盖

测试包括完整representative capture/restore：角色direct主武器、副武器、armor、bag、money；bag内
nested item；unparented live item；logical WORLD item。比较stable identities、definitions、own
weights、direct parents、derived ancestry/root、amount、hand refs、armor slots和current-definition
aggregate，不比较RefCounted identity。

Corrupt矩阵覆盖zero/negative/unknown schema version、duplicate/malformed item IDs、unknown definition、
missing parent、self/two/deep cycle、missing-state/orphan/non-stack/negative/duplicate stack、
duplicate character Equipment/Armor authority、跨character复用装备实例、missing/nested/duplicate/nonweapon
hand、missing/nested/duplicate/mismatched armor、hand/armor冲突及empty authority IDs。另覆盖：

- over-capacity-style高负载仍restore；
- secondary-only不promotion；
- two-handed + later shield保留；
- boots/feet/bandage开放槽；
- raw-zero amount 0 + unusual own weight原值恢复且无intent；
- pending window旧amount/weight存活且无intent；
- definition weapon facts、armor modifier与stack base-weight变化的current/saved authority分界；
- defensive DTO/projection copies和两次restore的Inventory/Combined/Equipment/Armor无mutable shared state；
- capture拒绝显式item集合、stack完整性、重复character source与aggregate不一致；
- capture → restore → capture逐字段canonical一致；
- 空Equipment/Armor record、真正任意非空Armor slot及`TWO_HANDED | SECONDARY`槽位边界。

## 明确延期

文件/JSON/Resource/binary格式、slots/cloud/encryption、SaveManager、legacy autoload importer、physical
World binding、content revision migration、Corpse/Death、ItemLifecycleService、scheduler/Timer、Combat、
NPC、UI、Catalog/Repository和generic component/callback系统全部延期。

下一阶段Phase4B5B可在这一fresh state和stable identity基础上实现typed Item Lifecycle / Destruction
Core；它不能反向把destruction runtime或scheduler字段加入schema v1。
