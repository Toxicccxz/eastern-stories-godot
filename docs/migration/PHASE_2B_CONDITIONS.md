# Phase 2B：Conditions

## 范围

本阶段实现 character condition 的 typed 持久状态、稳定 ID、添加/替换/移除、一次显式更新、flag 聚合，以及对既有角色资源操作的最小集成。代码为纯 `RefCounted` 领域逻辑，不决定何时更新，不包含 heartbeat、Timer、场景、战斗或表现层。

## 检查过的 LPC 来源

- 核心：`reference/es2/mudlib/feature/condition.c`、`include/condition.h`、`feature/damage.c`、`std/char.c`、`include/globals.h`。
- 全部 daemon：`daemon/condition/bandaged.c`、`drunk.c`、`iceshock.c`、`poison.c`、`rose_poison.c`、`slumber_drug.c`、`snake_poison.c`。
- condition 来源/解除：`feature/liquid.c`、`obj/bandage.c`、`obj/drug/snake_drug.c`、`obj/slumber_drug.c`、`obj/toy/poison_dust.c`、`daemon/skill/iceforce.c`、`d/oldpine/npc/venomsnake.c`、`d/latemoon/park/npc/obj/flower.c`，以及全 mudlib 的 `apply_condition()` / `query_condition()` 结构搜索。
- 设计说明：`reference/es2/mudlib/doc/mudlib/condition`。

## 全量 daemon 分类

| ID / 文件 | payload | 每次更新的领域行为 | 旧版到期判断 | Phase 2B |
|---|---|---|---|---|
| `bandaged` | `int duration` | 若 `eff_kee < max_kee`，curing kee `3` | 先写 `duration - 1`；旧 duration 恰为 `0` 才移除 | 已实现 |
| `drunk` | `int duration` | 依 `con`、`max_force` 分段：昏迷、sen damage，较低段还调用不存在的 `receive_healing()` | 昏迷分支立即移除；否则旧 duration 恰为 `0` 才移除 | 延期 |
| `iceshock` | `int duration` | gin damage `25`、kee wound `25`、sen damage `25` | 旧 duration `< 1` 移除 | 未纳入代表集 |
| `poison` | mapping：`damage`、`duration`、`message` | kee damage、半量 kee wound，并修改 mapping | mapping duration `< 1` 移除 | 缺陷，延期 |
| `rose_poison` | `int duration` | sen wound `20`、kee damage `10` | 旧 duration `< 1` 移除 | 未纳入代表集 |
| `slumber_drug` | `int duration` | 高剂量对 living character 调用昏迷；中段仅输出文字 | 昏迷分支立即移除；否则旧 duration 恰为 `0` 才移除 | 延期生命周期部分 |
| `snake_poison` | `int duration` | kee wound `10`、sen damage `10` | 旧 duration `< 1` 移除 | 已实现 |

六个 daemon 使用不受范围约束的整数 duration；`poison.c` 是唯一 mapping payload。Godot 使用 `DurationConditionPayload` 和明确字段的 `PoisonConditionPayload`，共同继承受控的 `ConditionPayload`，没有复制 LPC 的任意 mixed/Dictionary API。

## Godot 状态与更新模型

- `ConditionIds` 保存原 daemon 文件名对应的稳定 `StringName` ID。
- `CharacterConditionState` 内部使用 `Dictionary[StringName, ConditionPayload]`，但不暴露通用属性路径或原始 collection；相同 ID 的新 payload 完整替换旧 payload，对应 `apply_condition()`。
- `CharacterState.conditions` 组合该状态；默认 collection 和 payload 都是实例私有的。
- `ConditionEffect` 是显式 typed handler；`ConditionSystem` 注册 handler，不使用文件路径、`call_other()` 或全局 daemon。
- `update_once()` 对调用开始时的 ID snapshot 各更新一次。handler 返回的 flags 按 bitwise OR 聚合；没有 `CND_CONTINUE` 的原 ID 在 handler 返回后移除，即使 handler 刚替换了同 ID payload。
- 当前迁移是部分 condition 集：没有已注册 handler 的 deferred ID 保留在状态中但不更新，避免因“尚未迁移”而冒充 LPC 的“daemon 文件缺失”并破坏存档。

LPC mapping 的 `keys()` 顺序没有可依赖的内容语义，随后又以 `while(i--)` 反向遍历。Godot 对 snapshot 按稳定 ID 字符串升序更新，使保存/恢复和添加顺序不改变结果；这是明确迁移决定，记录于 `DECISIONS.md`。

## Flags 与 CharacterRecovery 边界

| LPC | Godot |
|---|---|
| `CND_CONTINUE = 1` | `ConditionUpdateFlags.CONTINUE` |
| `CND_NO_HEAL_UP = 2` | `ConditionUpdateFlags.NO_HEAL_UP` |
| OR 后的 `cnd_flag` | `ConditionUpdateResult.combined_flags` |
| 当前恢复机会是否阻断 | `ConditionUpdateResult.no_heal_up` |

`ConditionSystem` 不调用 `CharacterRecovery`。调用方显式执行 condition update，再把 `result.no_heal_up` 传给 Phase 2A 的 `CharacterRecovery.apply_tick()`。每次 update 都产生新 result，因此 no-heal 只影响当前恢复机会。

七个现存 daemon 没有任何一个返回 `CND_NO_HEAL_UP`；该 bit 只存在于 header 和 `std/char.c` 的组合逻辑。测试用非 gameplay handler 验证聚合和 Phase 2A 接口，没有虚构一个 ES 条件。

## 已保留的特殊边界

- `snake_poison` 在旧 duration 为 `0` 或负数时仍先造成一次 wound/damage，然后移除。
- `bandaged` 在旧 duration 为 `0` 时仍先 curing 一次，然后移除。
- `bandaged` 只判断 `!duration`，所以负 duration 会永久继续并逐次减少；未静默修正。
- `bandaged` 即使 effective kee 已满、没有数值变化，只要旧 duration 非零仍返回 continue。
- 多条件修改同一资源时按已记录的稳定顺序执行，并保留 damage、wound、cure 各自的 Phase 1 夹取行为。

## 缺陷、歧义与延期

- `drunk.c` 调用 `receive_healing("gin", 10)` / `receive_healing("kee", 15)`，但 inspected mudlib 只有 `receive_heal()`；全库也没有其他 `receive_healing()` 定义。没有猜测这是拼写错误并替换。高剂量分支还依赖完整 `unconcious()` 生命周期，因此 drunk handler 整体等待明确缺陷决策和生命周期系统。
- `poison.c` 没有发现任何 application site。它接收 mapping，却把该 mapping 写入 `snake_poison` ID；下一次 `snake_poison.c` 期待的是 int duration。这一不兼容行为只保留为 typed payload 证据，不实现 handler。
- `slumber_drug` 的高剂量昏迷调用等待角色生命周期；`iceshock`、`rose_poison` 虽只依赖现有资源 API，但为保持本阶段代表集最小而延期。
- condition 输出文字属于未来 presentation。死亡时 `clear_condition()` 的调用属于未来 death lifecycle；collection 已提供 `clear()`，本阶段不实现死亡流程。
- 调度周期、busy、condition 与 recovery 的调用时机、heartbeat 开关全部延期。`ConditionSystem.update_once()` 只执行一次明确请求。
