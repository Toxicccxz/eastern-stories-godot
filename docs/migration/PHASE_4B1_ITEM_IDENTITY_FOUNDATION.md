# Phase 4B1：Item Identity + Definition/Instance Foundation

## 范围与结论

本阶段只建立不可变 authored definition identity 与 runtime instance identity 的原生边界。
实现是 typed `RefCounted` 纯领域对象，不依赖 Node、Character、Equipment、Inventory、World、
Combat、存档或表现系统，也没有 Catalog、Repository、factory、registry 或通用组件表。

## 权威 LPC 来源

直接复核：

- `reference/es2/mudlib/std/item.c`
- `reference/es2/mudlib/feature/move.c`
- `reference/es2/mudlib/feature/equip.c`
- `reference/es2/mudlib/feature/autoload.c`
- `reference/es2/mudlib/feature/name.c`
- `reference/es2/mudlib/std/item/combined.c`
- `reference/es2/mudlib/adm/simul_efun/file.c`
- `reference/es2/mudlib/adm/simul_efun/object.c`

代表性身份消费者：

- 标准武器：`reference/es2/mudlib/std/weapon/sword.c`
- 标准防具：`reference/es2/mudlib/std/armor/armor.c`
- 货币：`reference/es2/mudlib/std/money.c`、`obj/money/coin.c`
- autoload物品：`reference/es2/mudlib/obj/bandage.c`

`base_name(object)` 由 `file_name()` 去掉 `#clone_number` 得到规范 legacy program path；
combined merge/split 与 autoload reconstruction按该路径处理。装备、移动和命令使用实际 LPC
object identity。`feature/name.c` 的 aliases与display name是查找/表现事实，不是上述任一身份。

## 原生字段与语义

`ItemDefinition`：

- `item_definition_id: StringName`：稳定 native definition ID；不从路径、显示名或 aliases推导。
- `legacy_source_path: String`：只读迁移追溯元数据；不参与 native identity或普通 gameplay规则。

`ItemInstance`：

- `item_instance_id: StringName`：runtime instance的稳定身份，对应 LPC clone/object identity语义。
- `item_definition_id: StringName`：对 authored definition identity 的不可变引用。

两个类仅用下划线 backing fields和无setter getter公开身份。GDScript没有真正的字段私有性；本项目
沿用 Phase 4A1 的约定式封装，不提供公开 mutation API，也不包含可共享的 Array、Dictionary或
其他mutable default。

空 ID 按既有 stable-ID惯例保留为 unresolved/invalid占位，不在构造时自动修正或抛错。后续实际
消费边界负责拒绝无效ID。本阶段不加入全局registry，因此两个对象持相同`item_instance_id`只能
表示未来ownership/session中的无效重复，Phase 4B1不会侦测它。

## `legacy_source_path` 约定

现有迁移代码采用仓库相对、包含`.c`、不以`/`开头的形式，例如：

`reference/es2/mudlib/obj/weapon/longsword.c`

这与driver中的`base_name()`字符串不是同一权威ID；它是可点击、可审计的source metadata。
构造函数原样保存caller输入，不增删leading slash、扩展名或大小写，也不实现通用LPC路径解析。
未来 importer若接收raw `base_name()`，应在自己的兼容边界显式转换成上述source convention。

## Equality / identity

- 两个不同`ItemDefinition`对象只要`item_definition_id`相同，就代表同一逻辑definition；对象引用
  identity与gameplay identity无关。
- 两个`ItemInstance`可以引用同一个`item_definition_id`；只要`item_instance_id`不同，就是不同
  runtime instances。
- definition ID、instance ID、legacy source path、display name和aliases互不等价。
- 本阶段不重载对象引用相等，也不建立global uniqueness service；调用方显式比较稳定ID。

## 与 Phase 4A1 Equipment 的关系

本阶段只确认语义对齐：

- `WeaponDefinition.weapon_id` ↔ `ItemDefinition.item_definition_id`
- `EquippedWeaponRef.instance_id` ↔ `ItemInstance.item_instance_id`

测试证明两边可使用相同`StringName`值。生产Equipment代码、槽位行为和快照结构没有修改；
ItemInstance也不引用EquipmentState。现有`skill_type`、SECONDARY、TWO_HANDED仍是Phase 4A1
不可变weapon projection，不复制到generic ItemDefinition。

## 明确缺失与延期

ItemDefinition没有name、short、long、aliases、unit、weight、value、weapon/armor facts、quantity、
components或callbacks。ItemInstance没有parent/environment、owner、inventory、quantity、equipped、
durability、overrides、world position、Node、save state或Dictionary payload。

InventoryState、transfer、get/drop/give/put、重量/容量、combined/currency、Armor、Combat、autoload/
save、corpse/death、World/UI、authored content migration以及identity allocation全部延期。没有创建
ItemCatalog或ItemRepository；immutable lookup与runtime instance ownership等出现真实需求后再定。

## Phase 4B2 依赖

Phase 4B2可把`item_instance_id`作为containment graph节点/转移引用，把`item_definition_id`作为
未来immutable definition lookup键。它必须在独立InventoryState/transfer边界增加单父关系、
direct/root ownership、cycle防护、重量和Equipment detach协调。parent/location事实究竟由
ItemInstance窄状态还是InventoryState graph承载，应由Phase 4B2结合权威ownership边界决定；
无论选择哪种存储形态，都不得重建任意`environment()`setter，也不得使Equipment直接依赖
instance repository。
