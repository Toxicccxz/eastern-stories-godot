# Phase 3A：技能核心状态、定义与启用映射

## 范围

本阶段只实现纯领域技能基础：稳定 `StringName` ID、定义元数据、raw/learned 状态、enabled mapping、有效等级查询、`improve_skill()` 状态转换，以及向 Phase 2A `RecoverySkillLevels` 提供 raw 等级的适配器。没有实现训练命令、能力、战斗、装备、师徒或运行时调度。

## LPC 来源

- 核心：`reference/es2/mudlib/feature/skill.c`、`std/skill.c`、`std/force.c`、`include/skill.h`、`cmds/std/enable.c`、`include/globals.h`。
- enable/recovery 直接依赖：`feature/attack.c::reset_action()`、`feature/damage.c::receive_damage()/heal_up()`。
- modifier 来源边界：`feature/equip.c` 及全库 `query_temp/add_temp/set_temp("apply/<skill>")` 结构搜索。
- 代表 basic/knowledge：`daemon/skill/sword.c`、`force.c`、`magic.c`、`spells.c`、`literate.c`。
- 代表 specialized/force/knowledge：`daemon/skill/fonxansword.c`、`fonxanforce.c`、`essencemagic.c`、`magic-array.c`、`fall-steps.c`、`jin-gang.c`、`yirong.c`。
- 对 `reference/es2/mudlib/daemon/skill/*.c` 的 70 个文件做了完整文件清单，以及 inheritance、`type()`、`valid_enable()`、action table、validation hook 和特殊动作路径结构扫描；并扫描了全 mudlib 的 `map_skill()` 与 `improve_skill()` 调用点。

## daemon/skill 结构分类

- 70 个文件中，13 个继承 `FORCE`，13 个明确返回 `type() == "knowledge"`，44 个定义 `valid_enable()`。
- 16 个文件只有八行或更少，多为 basic/marker skill，例如 `sword`、`blade`、`staff`、`magic`、`spells`。
- 19 个文件包含 action/query_action，19 个包含 perform/exert/cast/conjure/scribe 文件分派，49 个包含学习/练习校验、提升 hook 或命中 hook。
- 因此 definition 只保存共同元数据；动作表、校验规则、特殊动作分派和 procedural hooks 不进入 Phase 3A，也不采用每技能一个 GDScript 的模型。

## 字段映射与模型

| LPC | Godot | 语义 |
|---|---|---|
| `skills[skill]` | `CharacterSkillState` raw level | 持久 raw 等级；定义过的零值与缺失值可区分 |
| `learned[skill]` | learned progress | 提升累计；零值记录仍计入 learned mapping 大小 |
| `skill_map[usage]` | `SkillLoadout` | basic/use ID 到特殊技能 ID 的映射 |
| `query_temp("apply/" + skill)` | `effective_level(..., temporary_modifier)` | 由未来 modifier/equipment 层显式提供的临时输入 |

`SkillDefinition` 的正交字段包括：stable ID、basic/specialized、martial/knowledge、是否继承 `FORCE`、允许的 enabled-use categories，以及 legacy source path。知识类型不等同于 basic；例如 `essencemagic` 是 specialized + knowledge，而 `fonxanforce` 是 specialized + martial + force style。

`CharacterSkillState` 独占其私有 `SkillLoadout`，外部只能通过 typed mapping 方法读写，不能直接改写底层字典或绕过 target-presence 校验。`SkillDefinition` 会复制调用方传入的 enabled-use 数组并只暴露查询，避免共享定义被外部集合修改。

## 查询与映射语义

- raw 查询缺失时返回 `0`。
- effective：`temporary_modifier + raw_basic / 2 + raw_mapped_special`，保留整数除法；mapped skill 缺失时贡献 `0`。
- 低层 `map_skill()` 只要求 mapped target 在 raw mapping 中有已定义 entry；entry 值可以是 `0`，base/use raw entry 不必存在。不存在的 mapped target 不改变映射。
- 相同 use 的新映射完整替换旧值；unmap 只移除该 use。
- `enable.c` 使用 LPC truthiness：raw 等级 `0`（无论缺失还是显式定义）会被玩家 enable 拒绝，但非零负值仍通过；native transition 不添加原版没有的等级下限。
- 删除 skill 会删除其 raw 与 learned entry，但原版不会清理指向它的 `skill_map`；Godot 保留该行为，之后 effective 查询把缺失 mapped raw 当成 `0`。
- `delete_skill()` 只有在 lazy `skills` mapping 从未建立时返回 `0`；一旦该 mapping 存在，删除后通过 `undefinedp()` 返回真，即使请求的 ID 原本缺失。Native state 只为保留这一确定行为记录 mapping 是否曾建立。
- 原版 `set_skill()`/`improve_skill()` 用 daemon 文件存在性验证 ID。Native state 不执行文件路径查找；未来 definition repository/import validation 必须在状态转换前拒绝未知定义，不能重建 `SKILL_D()` 服务定位器。

## 提升语义

`CharacterSkillState.improve_skill()` 直接翻译 `feature/skill.c`：

1. 非 weak player 路径会为缺失 raw skill 建立等级 `0`；weak player 只累计 learned，不建立或提升 raw。
2. 若 learned mapping 的 entry 数大于基础 `spi`，amount 除以 `learned_count - spi`。
3. 除法后 amount 恰为 `0` 时强制为 `1`。
4. learned 累加后，只有严格大于 `(raw + 1)²` 才提升一级；恰好等于阈值不升级。
5. 升级只增加一级，并把 learned 直接清零；超额不结转，也不循环升级。

方法返回是否升级，替代当前阶段不能执行的 daemon `skill_improved()` callback。`force.c`、`literate.c` 等 callback 的属性副作用等待未来明确的技能提升事件处理层。

## enable 与内部资源

`SkillEnableTransition` 保留 `enable.c` 的纯规则：use 必须属于其 `valid_types`，basic 与 special raw 等级必须非零，special definition 必须允许该 use。成功映射返回 typed `SkillMappingChangeResult`：

- `magic` → 请求重置 atman；
- `force` → 请求重置 inner force；
- `spells` → 请求重置 mana；
- 其他 use → 不重置。

结果中的 `applied` 表示校验后映射确实完成，足以让未来调用方重建战斗 action；resource enum 描述必须执行的当前内部资源清零，没有让 skill state 依赖 `CharacterRecoveryState`。重复 enable 同一技能仍返回相同重置请求，对应 LPC 每次成功执行都清零。`enable ... none` 只 unmap，不触发资源重置。原命令随后用零伤害唤醒 heartbeat 的运行时副作用未迁移，因为它不改变资源值且属于调度层。

`jin-gang.c` 声明 `valid_enable("iron-cloth")`，但 `enable.c::valid_types` 没有该类别；native metadata 保留该 legacy use，但玩家 enable transition 会拒绝它。`enable.c` 反而列有 `stick`，而当前 `daemon/skill/` 没有 `stick.c`。

## Phase 2A 关系

`RecoverySkillLevelsAdapter.create_snapshot()` 从 skill state 的 raw `magic`、`force`、`spells` 生成既有 `RecoverySkillLevels`。它忽略 enabled mapping 与 temporary modifier，完全对应 `damage.c::heal_up()` 的 `query_skill(id, 1)`。`CharacterRecovery` 本身仍不依赖 SkillState 或 SkillDefinition。

## 延期与歧义

- learn/practice/selflearn/study、exercise/meditate/respirate，以及所有 perform/exert/cast/conjure/chant/scribe。
- action tables、随机动作、`valid_learn`/`valid_effect`/`practice_skill`、hit hooks、`skill_improved` procedural effects。
- death penalty、live reward、definition repository、authoring/import validation 和完整 authored skill 数据。
- `enable.c` 的 `reset_action()` 与零伤害 heartbeat 唤醒属于战斗/运行时层。
- 一些 NPC 直接 `map_skill("magic", "taoism")`，绕过 `enable.c` 的 `valid_enable()` 校验；低层 mapping API 保留这种可能性，而玩家 enable transition 使用 definition 校验。
