# Phase 4B5：Persistence / Corpse / Item Lifecycle 依赖分析

## 1. 范围与结论

本阶段仅重新分析原始 ES2 LPC 与已关闭的 native Item/Inventory/Equipment/Armor/Combined
边界，没有修改 production GDScript，也没有实现 DTO、存档格式、restore、destruction、death、
corpse、scheduler、World、Combat 或 legacy importer。

主要结论：旧 user save 只保存 user object 的非 `static` 变量，并以 autoload 字符串额外重建
少数**直接 inventory**物件；它不是递归 inventory save。Native 不应复制这种数据丢失模型，
而应保存 stable instance/definition IDs、每实例 own weight、单父 containment、stack amount，以及
Equipment/Armor 的 instance references。Restore 必须使用独立的批量验证/重建路径，不能重放
`InventoryTransferService`、`wield()` 或 `wear()`。

死亡、尸体和销毁又是另一条依赖链：直接 inventory snapshot → typed death-item policies →
有序 transfer/lifecycle → corpse state/decay intents。它不应与 save codec 合并。当前证据足以在后续
引入通用、窄型 `ItemLifecycleService`，但不需要给每件物品增加 `PENDING/DESTROYED` mutable flag；
Phase 4B3 的零数量物品在一秒窗口内仍是 live item，pending callout 是 runtime intent。

## 2. 权威来源与扫描范围

逐行读取：

- persistence：`feature/autoload.c`、`feature/save.c`、`feature/dbase.c`、`obj/user.c`、
  `cmds/usr/save.c`、`cmds/usr/quit.c`、`adm/daemons/logind.c`；
- active autoload：`std/money.c`、`obj/bandage.c`、`obj/marry_card.c`、`obj/token.c`、
  `obj/roommaker.c`；
- death/corpse：`feature/damage.c`、`adm/daemons/chard.c`、`obj/corpse.c`、`std/char.c`、
  `std/char/npc.c`；
- lifecycle/runtime：`adm/simul_efun/object.c`、`feature/move.c`、`std/item.c`、
  `std/item/combined.c`、`doc/efuns/destruct`、`doc/applies/move_or_destruct`、
  `doc/efuns/call_out`、`call_out_info`、`find_call_out`、`remove_call_out`、`sscanf`、
  `save_object`、`restore_object`、`call_other`；
- authored death hooks：`obj/mailbox.c`、`obj/roommaker.c`、
  `daemon/class/scholar/windspring.c`；
- corpse consumer：`daemon/class/taoist/necromancy/animate.c`、`obj/npc/zombie.c`。

全 mudlib 复扫 `query_autoload`、`autoload()`、`init_autoload`、`save`、`restore`、
`save_object`、`restore_object`、`owner_is_killed`、`destruct()`、函数定义 `remove()`、
`move_or_destruct`、`call_out`、`corpse` 与 `animate`。活动定义计数为：

- `query_autoload()`：5；
- matching `autoload()`：4；
- `init_autoload()`：0；
- authored `owner_is_killed()`：3；
- item-specific `remove()` override：1（`obj/bandage.c`；其他额外定义属于 daemons）。

## 3. Legacy user save 模型

`obj/user.c` 组合 `CHARACTER + F_AUTOLOAD + F_SAVE`。`save_object()` 的 driver 文档规定：保存
当前对象所有非 `static` 变量；普通 object reference 保存为 0；默认不写零值。对 user 来说，
这包括 persistent `dbase`、skills/learned/mappings、conditions、damage feature 的 `ghost` 等
继承字段，以及 `save_autoload()` 临时填入的非 static `autoload` array。

它不包括：`tmp_dbase`、move feature 的 static weight/encumbrance、combat enemy arrays、team object
references、heartbeat tick/callouts、default object reference等 runtime state。`obj/user.c::save()`
顺序是：

1. `save_autoload()`；
2. `save_object(user file)`；
3. `clean_up_autoload()`，只清 live memory 中的临时 array。

Normal inventory objects 并不会被 `F_SAVE` 递归序列化。Login 先 `user->restore()`，随后
`user->setup()`；setup 最后调用 `restore_autoload()`。之后 `logind.c` 总会另外创建并穿上一件
starter cloth，这也不是 generic equipment restore。

### Quit 分支

- 普通玩家：snapshot `all_inventory(me)`；对每个 `query_autoload()` false 的直接物件调用
  `drop`。成功 drop 的物件及其 nested subtree 留在当前 room runtime；drop 失败的物件仍在 user，
  但不会写入 autoload，user destruct 时随 user 销毁。然后保存、销毁 user。
- Wizard：完全跳过上述 drop loop；save 仍只记录 autoload-compatible direct items，随后销毁
  user。所有 non-autoload direct items 及其 nested contents 随 user 销毁，而不是保存或落地。
- Autoload item：留在 user 中直到 save；路径/参数写入 user save，旧 runtime object 随 user
  销毁，下次 login 创建新 clone。
- Nested autoload item：不会被枚举。它不会因为“根持有者是 user”而自动保存；若外层 parent
  被 drop，它只作为 runtime subtree 跟随，若外层随 user 销毁则一并销毁。

因此旧行为明确区分 direct child 与 root-owned descendant，也明确不等于“保存整个 inventory”。

## 4. Autoload save 协议

`feature/autoload.c::save_autoload()` 调用无参数 `all_inventory()`，即当前 user 的 direct
inventory。每个对象调用 `query_autoload()`：false/0 跳过；truthy 时先写 `base_name(item)`。
只有返回值是 string 时才附加 `":" + parameter`；truthy non-string（roommaker 的 `1`）只保存
path。

格式为：

```text
/canonical/lpc/program
/canonical/lpc/program:string-parameter
```

`base_name()` 是去掉 clone suffix 的 legacy program path，不是 native definition ID。
`restore_autoload()` 用 `sscanf(entry, "%s:%s", file, param)`。`doc/efuns/sscanf` 明确说明前一
`%s` 匹配到 literal delimiter，后一 `%s` 接收剩余字符串，因此以**第一个 colon**分隔；parameter
中的后续 colon 原样保留。由于活动 LPC program path 不含 colon，这一解析本身无歧义。真正问题是
path 可执行、parameter 无类型、没有版本或 definition mapping，不能作为 native save schema。

没有 colon 时 `param = 0`，但 restore 仍调用 `autoload(0)`。

## 5. Autoload restore 顺序与失败边界

每条 entry 的精确顺序：

1. 解析 file/param；
2. `catch(ob = new(file))`；
3. new 失败时提示、log、continue；
4. `export_uid(ob)`；
5. `ob->move(user)`；
6. 忽略 move 返回值；
7. `ob->autoload(param)`；
8. 全 loop 完成后 `clean_up_autoload()`。

只有 `new(file)` 在 catch 内。`export_uid`、move 和 callback 都没有 catch。Move 因 capacity等失败
时，新 clone 通常仍是 unparented，但 callback照常执行。Money可在 unparented状态恢复 amount；
bandage 的 `::wear()` 则依赖 character environment，在此边界不能完成正常穿戴；具体是返回失败还是
触发runtime error取决于driver对null object调用的语义，源码不足以进一步断言。

Callback 抛错会中断整个 loop：后续 entries 不恢复，最后 cleanup不执行，autoload array仍留在
live user state。Mudlib没有 rollback已成功创建/移动/恢复的前序 items。

Roommaker 没有 `autoload()`。Mudlib其他注释表明 deployed driver通常把 missing lfun视作0/no-op，
但 `call_other` 文档没有明确承诺该错误行为；因此“callback确定缺失”是事实，restore究竟无声成功
还是 runtime error仍保留为 driver-semantics ambiguity。

## 6. 五个活动 autoload 实现

| 对象 | `query_autoload()` | matching callback | 恢复状态/副作用 | 装备状态 |
| --- | --- | --- | --- | --- |
| `std/money.c` | `query_amount() + ""`，包括字符串 `"0"` | 有 | parse int并调用 `set_amount()`；恢复 combined amount与weight | 无 |
| `obj/bandage.c` | 仅 item有任意 `equipped` marker时返回当前 name | 有 | set name；强制 `blood_soaked = 3`；调用 base `::wear()`，结果忽略 | 唯一明确自行恢复 worn 的实现 |
| `obj/marry_card.c` | 从 `this_player()` direct inventory中按 id找 card，再从 name解析partner | 有 | 查 online partner、发消息、重建 display name | 无；依赖 online/runtime与脆弱 display-name identity |
| `obj/token.c` | truthy `guild_id` | 有 | intended 从独立 guild save恢复 dbase；失败会删 holder family并destruct token | 无；callback参数未使用，见下述缺陷 |
| `obj/roommaker.c` | integer `1` | **无** | path-only entry；missing callback结果依赖 driver | 无 |

具体异常：

- Bandage不是 round-trip：保存的是 name，不保存原 `blood_soaked`，restore固定写3。若 move失败或
  bandage slot冲突，wear结果没有检查。
- Marry card 的 query依赖 `this_player()`，而 user save也可能由 shutdown/login runtime代表调用；
  其序列化上下文可能不是 item owner，属于确定的耦合风险。
- Token `autoload(string name)` 完全未使用保存的 `name/guild_id`，却立即调用基于当前
  `query("guild_id")` 的 `restore()`。新 clone没有显式写该 ID；这是 apparent executable defect。
  精确报错/字符串转换结果取决于 driver，但源码不能证明它正确恢复目标 guild。
- `obj/prize/black_vest.c` 的 query只在注释中，不计活动实现。

## 7. Legacy equipment persistence

LPC 没有 generic primary/secondary/worn serialization。Character temp dbase不保存；item-side
object references也无法通过 `save_object()`保留。普通 weapon/armor不进入 autoload，quit后不恢复。

唯一确认的 worn reconstruction是 bandage callback。Money只恢复 amount。Login starter cloth是
新建默认物件，不是原衣物/槽位恢复。Native save不应为了兼容这个旧限制而丢弃 EquipmentState、
ArmorState 或普通 ItemInstances；实现这一现代化时应在 `DECISIONS.md` 明确记录 persistence行为
扩展，但本分析阶段不写决定。

## 8. Native save schema 建议

序列化 schema 与 JSON/Resource/binary格式必须分开。纯 DTO/validator建议位于
`game/core/persistence/`；文件IO、slot选择、加密/压缩和Godot平台路径属于 application save层。
Core domains不依赖 serializer或filesystem。

最小 item-domain snapshot：

```text
NativeItemStateSnapshot
  schema_version
  item_records[]
    item_instance_id
    item_definition_id
    own_weight
    optional direct_parent { endpoint_kind, endpoint_id }
  combined_stack_records[] { item_instance_id, amount }
  character_equipment_records[]
    character_id
    optional primary_item_instance_id
    optional secondary_item_instance_id
  character_armor_records[]
    character_id
    slots[] { armor_type, item_instance_id }
```

DTO数组按stable ID/slot排序，以便确定性diff与测试。`parent`采用每实例flat parent record，而不是
recursive tree：它与 `InventoryState` 的单父权威一一对应，能自然表达 unparented、CHARACTER、
ITEM、WORLD与corpse ITEM endpoints，也便于先创建所有实例再验证forward references/cycles。
Runtime仍只有InventoryState拥有parent；DTO只是snapshot，不是第二份live authority。

### Definition 与 instance

Definition content不重复保存。每个实例只保存definition ID；restore由application提供的immutable
definition lookup/projection重建 Weapon/Armor/Stack facts，不需要在core预建ItemCatalog或Repository。
Instance/persistence facts包括：instance ID、own weight、parent、stack amount以及未来由source证明的
窄型mutable components（例如bandage blood state），不能扩成dbase Dictionary。

Own weight必须保存：当前它是InventoryState权威；stack显式零请求保留旧weight，raw-zero注册也可
具有独立weight，因此不能总由`amount * base_weight`无损重算。Equipment ref中的skill type/flags和
Armor ref中的slot/modifier snapshot应由当前immutable definitions重建，save只存instance refs；aggregate
modifier不保存。

最小schema从第一版就应有正整数 `schema_version`。未知版本typed reject。Native schema版本与
legacy autoload import是两条独立路径；可选content build/revision可放application envelope用于诊断
definition变化，不是首版core DTO必填字段。

## 9. World 与 recursive containment

Schema可以无损保存 logical WORLD endpoint ID，但当前没有World Runtime，不能证明该ID对应哪个map、
zone、position或scene instance。Phase 4B5A可验证endpoint形状并保留ID；实际physical restoration、
spawn position和失效地图fallback必须延期到World save层。

Character direct items、nested ITEM contents和corpse contents都使用同一个parent record。Corpse继续是
`ITEM + corpse ItemInstanceId` endpoint；没有证据需要新增CORPSE endpoint kind。Moving/saving一个bag
subtree不扁平化children。

## 10. Restore dependency 与顺序

Future native restore应构造新的aggregates，并在任何authoritative mutation前完整预验证：

1. 验证schema version和DTO基本形状；取得immutable definition projections；
2. 验证全部instance IDs唯一、definition IDs已知；创建所有unparented ItemInstances；
3. 验证/创建typed mutable components，尤其stack definition匹配且amount非负；
4. 以保存的own weight在新InventoryState注册全部items；
5. 批量验证全部parent refs：parent item存在、endpoint有效、每实例最多一个parent、无cycle；
6. 通过trusted batch reconstruction seam一次建立parent graph；
7. 验证Equipment refs存在、属于对应character direct inventory、primary/secondary不重复、与weapon
   definition相符；通过trusted restore seam设置refs；
8. 验证Armor exact slots不重复、instance不重复、item直接属于character、definition/type一致，并与
   hand refs无同instance冲突；由definition重建modifier snapshots，再trusted restore；
9. 返回完整成功aggregate或typed restore failure；不在半完成live state上继续。

Restore不应重放 `InventoryTransferService`：它会先detach、做capacity gate、产生partial mutation和
gameplay transfer结果。也不应逐件调用`wield()`/`wear()`：saved合法状态可包含secondary-only、
双手+secondary等legacy顺序怪异点；普通操作验证、shield gate、female/custom eligibility都不是load
side effects。

需要独立、受限的batch reconstruction seam。它仍执行结构invariants，但不执行命令/transfer效果。
Trusted native save应恢复保存时的over-capacity状态，不以当前gameplay capacity拒绝；definition变更
导致的overload可报告warning，由正常玩法以后处理。Legacy autoload import则可单独选择更严格或
兼容其move-failure行为。

### Corrupt save策略

Core validator应在mutation前返回typed failure，而不是自动repair：

| 情形 | 建议 |
| --- | --- |
| duplicate instance ID | reject whole item snapshot |
| unknown definition ID | reject；legacy importer可先做显式ID mapping |
| missing parent item / invalid endpoint | reject graph |
| containment cycle | reject graph |
| equipment ref missing/not direct/not weapon | reject equipment section，默认使整snapshot失败 |
| armor ref missing/not direct/type mismatch | reject armor section，默认使整snapshot失败 |
| duplicate armor slot或instance | reject |
| same instance同时hand/worn | reject native save |
| stack state用于non-stack definition或negative amount | reject |
| unresolved physical WORLD placement | structure可保留；application/world binding deferred，不伪造位置 |

Application可另提供“导入后降级/隔离”工具，但不能把silent skip变成core restore默认。

## 11. Item lifecycle 与 destruction

当前native实际有：registered live、unparented live、contained live、已由stack merge移除，以及live item
附带的一次delayed destruction intent。Source没有要求每件物品持久保存 `LIVE/PENDING/DESTROYED`
enum。被移除实例应从authoritative collections消失；`PENDING` stack在callout触发前仍有旧amount、
旧weight且可以move/save/death，所以把它标成不可用状态反而会改变行为。

Phase 4B5B引入通用typed `ItemLifecycleService` 已有充分理由：stack absorption、combined零callout、
death policies、corpse final/animate和future quit/runtime removal都需要一致清理。但service应只负责：

- 验证live instance；
- 按exact instance协调direct-owner Equipment/Armor detach；
- 按明确child disposition执行leaf removal或post-order subtree destruction；
- 从InventoryState、CombinedStackCollection及未来窄型instance-state collections移除关联；
- 返回removed IDs、detach证据、child transfer/failure等typed result。

它不调用Quest/NPC callback、不删除Node、不调度Timer、不决定death rewards。Phase 4B3
`_remove_registered_leaf()` 在该服务出现前继续保持stack-specific；以后可由共同内部primitive取代，
但不应现在扩大公开访问。

### LPC destruct精确语义

Simul efun先调用 `ob->remove(euid)`，成功返回后才调用driver `efun::destruct(ob)`。
`feature/move.c::remove()`：限制只能由simul efun调用；保护非root销毁user；若equipped则尝试
unequip（失败仅log，仍继续）；从environment减去**own weight**；维护default-object计数。

Driver在environment被destroy时，对其direct contents调用 `move_or_destruct(dest)`。若content没有
移出就一并destroy。全库唯一active实现是`feature/move.c`：只有`userp(item)`会move到VOID；普通
items/combined/corpse不move，所以随parent递归destroy。`obj/bandage.c`是唯一item remove override：
它先调用base remove，再检查仍有equipped marker才清bandaged condition；正常base unequip已删marker，
所以该cleanup通常不可达，是apparent authored defect。

## 12. owner_is_killed policies

`chard.c` 对所有direct inventory对象执行array call，然后移除已destruct而变为0的refs。只有三个
active authored definitions：

| Path | 精确效果 | Future typed分类 |
| --- | --- | --- |
| `obj/mailbox.c` | destruct self | `DESTROY_ITEM` |
| `obj/roommaker.c` | destruct self | `DESTROY_ITEM` |
| `daemon/class/scholar/windspring.c` | 若owner自身id为`sword soul`则KEEP；否则以killer（空则owner）定位room，spawn `sword_soul` NPC、reset/chant，再destroy sword | deferred `DESTROY_ITEM + SPAWN_NPC_AT_WORLD_ENDPOINT`；依赖NPC/World/Combat context |

未来可有按stable ItemDefinitionId显式注册的 `DeathItemPolicy`，unknown/default为KEEP。Result必须是
窄型union/effects，不能有`SPECIAL: Variant`或callback name。Windspring在NPC/World尚未实现时应返回
typed dependency-unavailable/deferred effect，不制造假NPC状态。

## 13. Death外层顺序

`feature/damage.c::die()` 的相关顺序是：必要时revive → immortal wizard early return → clear
conditions → combat announce → killer reward → `CHAR_D->make_corpse()` → 若返回corpse再move一次到
victim environment → 清combat relationships/team → user变ghost并move death room，或destruct NPC。

Combat只需未来产生death outcome/context；direct inventory、corpse和lifecycle可以在没有Combat
resolver时独立测试。Killer reward、ghost character资源和NPC destruction不应塞入CorpseState。

## 14. Ghost death

`chard.c`首先检查`victim->is_ghost()`，早于wizard branch：

1. snapshot `all_inventory(victim)` direct items；
2. 对snapshot全部调用 `owner_is_killed(killer)`；
3. 从array移除已destroy的0 refs；
4. 逆序调用每个survivor `move(environment(victim))`；
5. 忽略所有move返回值；
6. 返回0，不创建corpse。

Direct hand/worn items在move尝试最前面先detach。失败时parent仍是victim但装备已解除。Nested contents
不单独收death hook，随direct parent subtree移动。这个流程需要logical WORLD endpoint与现有
InventoryTransferService，不需要World Node。

## 15. Normal corpse创建与wizard branch

非ghost先创建`CORPSE_OB`，设置：

- name和aliases；
- long；
- `age`；
- `gender`；
- `victim_name`；
- corpse own weight = `victim->query_weight()`；
- max contents encumbrance = `victim->query_max_encumbrance()`；
- parent = victim当前environment。

其中own weight/capacity和victim identity snapshot有domain意义；name/long/gender主要支持表现，
`victim_name`还用于animate zombie命名。未来最小组合为普通`ItemInstance(corpse definition ID)` +
optional `CorpseState`，而不是CorpseItem subclass或完整CharacterState。

Wizard branch发生在corpse创建/放置**之后**：`wizardp(victim)`只跳过owner hooks和inventory transfer，
所以得到空corpse。Wizard user的items仍随user移往death room；若最终destroy的是wizard NPC/body，
普通contents按driver规则随body销毁。Ghost branch不经过这项豁免；immortal wizard更早在
`damage.c::die()`直接返回。

## 16. Normal direct inventory sequence

非wizard：corpse已创建后才snapshot direct inventory；执行全部death hooks；移除0 refs；再逆序处理
survivors：

- `equipped == "worn"`：`move(corpse)` → move内部先unequip → 无论move成功与否都调用`wear()` →
  wear失败才尝试`move(victim room)`；三个返回值都忽略。
- wielded item：走普通`move(corpse)`；move先unwield，不在corpse重新wield。
- ordinary/stack/container：普通`move(corpse)`；combined amount保持，stack没有generic death hook。

Character→Bag式subtree语义自然适用：若direct item是bag，bag只收一次hook并整体移动，nested item
不单独收hook。Corpse capacity等于victim max encumbrance；正常未超载inventory通常可容纳，但
over-capacity、hook mutation或损坏state可触发partial failures。

### Move failure quirks

- Worn move因capacity失败：move已从victim ArmorState detach但parent仍是victim；随后`wear()`在
  victim上通常重新成功，因此item可能留在原victim并重新穿戴。若wear失败，fallback room move仍
  被尝试。
- Wielded/ordinary move失败：item可留在victim；wielded已经detached，不会恢复。
- Worn move成功但corpse slot collision：wear失败，fallback room move；fallback失败则留在corpse
  unworn。
- Chard不检查corpse自身初次move，也不检查`damage.c`对corpse的第二次move。

这些是确定的source partial mutation，不应被未来clean transaction静默覆盖。Native实现时应返回
ordered transfer/equipment evidence；是否现代化成更强atomicity需要显式compatibility决定。

## 17. CorpseState、capacity 与 endpoint

建议未来 `CorpseState` 最小保存：corpse item instance ID、original character/stable identity（若有）、
victim display-name snapshot、gender/age presentation snapshot、decay stage、maximum contents weight，
以及下述narrow corpse-worn projection。Corpse own weight和parent仍由InventoryState唯一拥有；contents
仍是普通ITEM endpoint children。不要新增CORPSE endpoint kind。

`CorpseState`不持有children array、InventoryState、CharacterState或Node。Destination capacity由
CorpseState投影给Inventory transfer，与任何其他container projection相同。

## 18. Corpse上的worn armor

新corpse `decayed == 0` 时 `is_character() == true`，目的正是让转入的worn armor能调用base wear；
LPC会在corpse temp dbase写armor slot/apply modifiers和item marker。Corpse不是living Combat角色，
未发现consumer读取这些modifier用于伤害；给corpse完整native ArmorState/CharacterState没有必要。

但rewear不只是表现：phase 1把`decayed`设为1后corpse不再`is_character()`，原worn marker仍存在。
之后取走或最终scatter该item时，move先调用unequip；unequip因owner不再是character返回0，move失败。
因此120秒后仍worn的armor会变得不可移动，并在corpse最终destruct时随corpse销毁。这是确定的legacy
gameplay quirk。

最小native模型应在CorpseState中保存窄型 `armor_type -> item_instance_id` corpse-worn projection，
只用于loot/decay/presentation顺序；不累计ArmorNumericModifiers，也不复用character ArmorState。
是否保留“phase1后不可取、最终销毁”应在Phase 4B5C实现前作compatibility决定，不能在本分析中
默认为现代可拾取。

Save/restore角色Equipment/Armor与death时corpse-worn projection是两个独立问题，不建立通用
equipment serialization/lifecycle manager。

## 19. Corpse decay 与final scatter

精确schedule：clone create后120秒到phase1；再120秒到phase2；再60秒到phase3，总计300秒。

| Stage | Domain事实 | Presentation | Next intent |
| --- | --- | --- | --- |
| 0 | `is_corpse=true`, `is_character=true` | fresh corpse | phase1 after120s |
| 1 | `is_corpse=true`, `is_character=false` | rotten corpse | phase2 after120s |
| 2 | `is_corpse=false`, `is_character=false` | skeleton | phase3 after60s |
| 3 | final release/destruction | ash message | none |

Phase1 gender switch没有break；MudOS/C fall-through使男性和女性最终也执行default，名称都成为通用
“腐烂的尸体”。这是presentation defect，不进入ItemLifecycle core。

Phase3若corpse有environment：snapshot direct contents，逐件`move(environment)`，忽略失败；之后无条件
destruct corpse。成功items散落到logical WORLD parent；失败items仍在corpse并随driver subtree
destruction销毁。上述stage1 worn armor会系统性落入失败组。没有environment则跳过release并直接
销毁全部contents。

Future pure decay transition应返回domain-specific `CorpseDecayScheduleIntent(corpse_id, next_stage,
delay_seconds)`，final result返回待scatter direct IDs、transfer results与destroy intent。Runtime adapter
决定何时触发；不使用callback names或generic `ScheduledDomainAction`。

## 20. Animate/destruction

`is_corpse()`只在stage0/1为true，所以necromancy可在前240秒调用animate。`corpse::animate()`：验证有
environment → 创建zombie →按victim_name命名 → move到corpse environment →调用zombie animate →
**不搬任何contents**即destruct corpse。Zombie的`animate(who,time)`忽略time参数，只设置possessed/
leader，是另一个authored/runtime缺陷。

Driver对被destroy environment的contents调用`move_or_destruct(outer environment)`：普通items不move，
确定随corpse销毁；若异常地含user，唯一F_MOVE实现会将user移到VOID。这里没有普通item contents
survival ambiguity，也没有其他active move_or_destruct override。

Animate依赖NPC definition/spawn、logical World placement和runtime，明确延期；ItemLifecycle只需能按
明确请求destroy corpse subtree。

## 21. Pending zero destruction 与save/death

`combined.c::set_amount(0)`不把amount或weight写0，只在当前object安排1秒callout。Callout不是
`save_object`变量，也没有durable scheduler persistence。

- 在窗口内保存money：autoload看到旧amount并保存它。若旧amount为正（例如1减到0请求），重登会
  `set_amount(old positive)`，pending intent丢失，item复活。若raw amount本来就是0，保存参数`"0"`，
  restore再次`set_amount(0)`并新建1秒intent。
- 普通combined不是autoload；普通玩家quit会尝试drop，wizard/body destruction则立即销毁它。
- 窗口内发生death：item仍是live direct/nested object，照常进入hook/transfer/corpse；原callout继续
  计时，触发后在当前位置destruct。

因此当前native应继续把pending作为runtime-owned `CombinedStackDestructionIntent`，不把item标成
non-live。Native save要不要持久化remaining delay会改变legacy logout行为，必须作为未来产品决定；
Phase 4B5A首版建议不保存runtime intent，但应在load后明确允许旧amount item存活，并记录该兼容
选择。若未来希望可靠销毁，则以专门typed intent DTO扩展schema，而不是generic scheduler callback。

## 22. Legacy autoload importer边界

Legacy importer应在native DTO/restore基础稳定后实施，不执行LPC path：

1. parse first-colon legacy entry；
2. 用显式legacy path→ItemDefinitionId mapping；
3. 由application提供新的ItemInstanceId；
4. 创建direct CHARACTER parent record；
5. 按definition注册窄typed decoder。

Money decoder把parameter转amount，建立CombinedStackState并计算/验证weight。Bandage decoder恢复legacy
name/blood=3并产生“请求corpse-independent Armor restore”的typed authored effect；marry card恢复partner
identity/display state但online通知交给runtime；token必须显式处理unused-ID defect；roommaker缺callback且
是wizard tool，可报告unsupported/skip。不存在generic `autoload(method_name)` dispatcher。

## 23. World/runtime边界

需要logical WORLD endpoint但不需要Node的domain操作：ghost scatter、corpse placement、worn fallback、
final scatter、windspring spawn intent。真正依赖World Runtime：将endpoint绑定map/zone/position、显示
corpse/loot、spawn zombie/sword soul、处理无效scene placement。

需要runtime scheduling：corpse 120/120/60 decay和combined 1秒destruction。两者应保持各自typed intent；
未来scheduler可以接收共同接口，但不能存function name/Callable/Variant args。是否pause、是否跨save继续、
使用game time或wall time都需产品决定，source只证明server wall seconds/callout。

## 24. 推荐实现分解

依赖关系支持四个窄实现单元：

1. **Phase 4B5A — Native Item Save DTO + Restore Validation Foundation**：纯typed snapshot records、
   schema version、完整prevalidation、fresh aggregate reconstruction，以及Inventory/Equipment/Armor的
   trusted restore seams；无IO、格式、World binding或legacy import。
2. **Phase 4B5B — Item Lifecycle / Destruction Core**：leaf/subtree removal、Equipment/Armor detach、
   stack collection cleanup与typed results；吸收Phase4B3 narrow seam，但无scheduler/callback。
3. **Phase 4B5C — Death Inventory + Corpse Foundation**：direct snapshot、三项explicit death policies、
   ghost/normal/wizard分支、CorpseState、corpse-worn projection与decay intents；NPC/World effects只输出
   typed deferred intents。
4. **Phase 4B5D — Legacy Autoload Import**：五个显式path codecs和已记录缺陷处理；不成为native save。

最小且推荐的下一个实现阶段是 **Phase 4B5A**。它只固化已经关闭的ItemInstance、InventoryState、
EquipmentState、ArmorState和CombinedStackState，不依赖Combat、World、corpse runtime或scheduler；并为
后续lifecycle/death与legacy import提供可验证的重建边界。

## 25. 明确延期

Serialization format/IO、save slots/cloud、content repository/catalog、physical World restore、Combat death
emission、killer rewards、ghost lifecycle、NPC spawning、corpse Node/VFX、Timer/scheduler、autoload执行器、
get/drop/give/put、quests、economy、bulk authored items，以及corpse stage1 armor lootability兼容决定全部延期。

本分析发现的token/bandage/roommaker/corpse/zombie缺陷均未静默修复。除纠正Phase4B0对colon parser的
事实陈述外，没有发现已实现native行为需要更新`DECISIONS.md`。
