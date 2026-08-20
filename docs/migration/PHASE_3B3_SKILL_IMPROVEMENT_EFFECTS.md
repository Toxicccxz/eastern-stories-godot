# Phase 3B3：技能升级事件与作者效果

## 范围与架构

本阶段补齐 `CharacterSkillState.improve_skill()` 成功升级后、LPC `skill_improved()` 之前的缺口。通用技能状态只返回 typed snapshot `SkillImprovementResult`：技能 ID、升级前后 raw level、是否升级、升级前后 learned。它不认识任何作者技能 ID，也不执行作者副作用。

`SkillImprovementEffectRegistry` 以稳定技能 ID 显式注册狭窄 policy。调用者仅在取得升级结果后交给 registry；registry 返回 typed `SkillImprovementEffectResult`，区分未升级、默认空 hook、已检查但无 mutation，以及已应用。它不模拟 `SKILL_D`、daemon 路径调用、`call_other()` 或 dbase API，且不依赖 Node、场景、调度、战斗或表现层。

`PracticeService` 与 `SelfLearningService` 仅传播并应用该结果，没有重算 Phase 3A 的 learned 惩罚、最少 1 点、严格平方阈值、单次一级、清零不结转或 weak-player 规则。Practice 的 policy 资源 mutation 仍在升级前；Selflearn 的作者回调仍在升级后、gin damage 前，和 LPC 调用栈一致。Cultivation 未改动。

## 权威 LPC 来源

- 通用触发：`reference/es2/mudlib/feature/skill.c`、`std/skill.c`、`include/skill.h`、`include/globals.h`。
- 状态 mutation 与当前调用顺序：`feature/dbase.c`、`feature/attribute.c`、`feature/damage.c`、`std/char.c`。
- 九个 active authored hook：`daemon/skill/celestial.c`、`force.c`、`literate.c`、`music.c`、`nine-moon.c`、`six-chaos-sword.c`、`stormdance.c`、`tao-mystery.c`、`unarmed.c`。
- 全 mudlib 扫描发现的旧副本：`d/skill/force.c`、`literate.c`、`six-chaos-sword.c`、`unarmed.c`。
- 当前调用路径：`cmds/std/practice.c`、`cmds/std/selflearn.c`、`daemon/skill/fall-steps.c`、`daemon/skill/fonxanforce.c`。

审计时重新扫描整个 `reference/es2/mudlib/`，共找到 14 个 `skill_improved()` 函数定义：`std/skill.c` 的标准空 hook、`daemon/skill/` 下 9 个 active authored hook，以及 `d/skill/` 下 4 个旧副本。另有 `feature/skill.c` 的唯一调用点。此前“9 个 hook”只对 active `daemon/skill/` 成立，不能表述为全 mudlib 的函数定义总数。

`include/globals.h` 将 `SKILL_D(x)` 固定为 `/daemon/skill/` 加技能 ID；全库引用搜索没有发现将 `/d/skill/*.c` 用作 `feature/skill.c::improve_skill()` 回调目标的路径。因此 native registry 只映射 9 个 active authored hook，不能为四个旧副本再执行一次效果。`feature/skill.c` 在 raw level 加一、learned 清零之后同步调用 active hook。

## 全部函数定义的结构分类

| skill ID / 精确来源 | 触发条件与 state read | state mutation | 等级基准 / 随机 / 依赖 | 分类与处理 |
|---|---|---|---|---|
| 默认 / `std/skill.c` | 每次升级调用；不读 state | 无 | 无随机、无外部依赖 | A：以 `NO_AUTHORED_EFFECT` 表示 |
| `celestial` / `daemon/skill/celestial.c` | `s = new raw celestial`；`s % 10 == 9 && base cps < s / 4` | base `cps += 2` | 新等级；无随机；仅 CharacterState | A：已实现为 composure |
| `force` / `daemon/skill/force.c` | `s = new raw force`；`s % 10 == 9 && base con < s / 4` | base `con += 2` | 新等级；无随机；仅 CharacterState | A：已实现为 constitution |
| `literate` / `daemon/skill/literate.c` | `s = new raw literate`；`s % 10 == 9 && base int < s / 4` | base `int += 2` | 新等级；无随机；仅 CharacterState | A：已实现为 intelligence |
| `music` / `daemon/skill/music.c` | `s = new raw music`；`s % 10 == 9 && base spi < s / 4` | base `spi += 2` | 新等级；无随机；仅 CharacterState | A：已实现为 spirituality |
| `nine-moon` / `daemon/skill/nine-moon.c` | active hook 却读取当前 raw `nine-moon-sword % 10` | 整十 `bellicosity += 2000`，否则 `+= 200` | 不使用触发技能的新/旧等级；无随机；仅 skill/attribute state | D：ID 错配；按字面行为实现 |
| `six-chaos-sword` / `daemon/skill/six-chaos-sword.c` | new raw `six-chaos-sword % 10 == 0` | 整十 `bellicosity += 1000`，否则 `+= 100` | 新等级；无随机；仅 CharacterState | A：已实现 |
| `stormdance` / `daemon/skill/stormdance.c` | `s = new raw stormdance`；`s % 10 == 9 && base per < s / 4` | base `per += 2` | 新等级；无随机；仅 CharacterState | A：已实现为 personality |
| `tao-mystery` / `daemon/skill/tao-mystery.c` | 每次升级；不读等级 | `bellicosity += 100` | 新/旧等级均不参与；无随机；仅 CharacterState | A：已实现 |
| `unarmed` / `daemon/skill/unarmed.c` | `s = new raw unarmed`；`s % 10 == 9 && base str < s / 4` | base `str += 2` | 新等级；无随机；仅 CharacterState | A：已实现为 strength |
| `force` / `d/skill/force.c` | 与 active force hook 相同 | base `con += 2` | 若被调用则读当前 raw force；无随机 | D：不可由 `SKILL_D` 到达的旧副本，不重复注册 |
| `literate` / `d/skill/literate.c` | 与 active literate hook 相同 | base `int += 2` | 若被调用则读当前 raw literate；无随机 | D：不可由 `SKILL_D` 到达的旧副本，不重复注册 |
| `six-chaos-sword` / `d/skill/six-chaos-sword.c` | 与 active six-chaos hook 相同 | `bellicosity += 1000/100` | 若被调用则读当前 raw；无随机 | D：不可由 `SKILL_D` 到达的旧副本，不重复注册 |
| `unarmed` / `d/skill/unarmed.c` | 与 active 文件冲突：读取 raw `force`，再检查 `% 10 == 9` 和 base str | base `str += 2` | 不读取 unarmed 等级；无随机 | D：不可到达且与 active hook 冲突，不迁移 |

分类含义：A 可由当前 CharacterState/attribute typed state 完整表达；B 需要狭窄延期 output；C 需要未来 combat/NPC/world/inventory/runtime；D 是旧源码缺陷、冲突或不可达副本。扫描没有 B 或 C 定义。所有 active hook 都不依赖 randomness、combat、condition、NPC、world、inventory 或 runtime scheduling；文字只是 presentation。

## 精确效果语义

六个基础属性 hook 共用已确认公式：

```text
s = 升级后的 raw level
if s % 10 == 9 and base_attribute < integer_divide(s, 4):
    base_attribute += 2
```

比较发生在 mutation 前；相等不增加。LPC `add()` 是原值直接相加，因此 native 实现不 clamp，`+2` 后可以超过 `s / 4`。一个 hook 每次 `improve_skill()` 最多调用一次，但它可在以后每个 `...9` 等级再次满足条件。

`six-chaos-sword` 在升级后的 raw level 为 10 的倍数时加 1000 杀气，否则加 100；`tao-mystery` 每次升级加 100。杀气同样不 clamp。文字没有写入 domain state；typed effect result 已携带 mutation 种类、数值及前后值，足够未来表现层使用。

## Practice / Selflearn 集成

- 当前已迁移 Practice policy 中，`fall-steps` 可升级但继承 `std/skill.c` 的空 hook，因此结果为 `NO_AUTHORED_EFFECT`；`fonxanforce` 的 practice hook 始终失败。不存在当前可达且有作者 mutation 的 Practice 技能，service 仍完整传播升级事件，未来新增已审计 policy 时无需复制升级规则。
- Selflearn 白名单里的 `force` 与 `unarmed` 当前可达；二者在 raw level 升到 `...9` 且对应 base attribute 严格低于 `s / 4` 时，现已分别精确增加 base con/str 2。
- 未升级时 registry 返回 `NOT_LEVELED_UP`，不检查或执行作者 policy。未知技能升级对应 `std/skill.c` 默认空 hook，返回 `NO_AUTHORED_EFFECT`。九个 active authored hook 全部具有当前可执行的字面语义，没有 deferred gameplay callback。

当前可达性逐项复核：

| 路径 | 技能 | active authored hook | 结果 |
|---|---|---|---|
| Practice | `fall-steps` | 无，继承标准空 hook | 可升级，返回 `NO_AUTHORED_EFFECT` |
| Practice | `fonxanforce` | 无；其 practice hook 先返回失败 | 不会调用 `improve_skill()` |
| Selflearn | `dodge` | 无 | 正常 progression + 标准空 hook |
| Selflearn | `force` | 有 | 已保留 con `+2` 边界效果 |
| Selflearn | `sword` | 无 | 正常 progression + 标准空 hook |
| Selflearn | `blade` | 无 | 正常 progression + 标准空 hook |
| Selflearn | `staff` | 无 | 正常 progression + 标准空 hook |
| Selflearn | `parry` | 无 | 正常 progression + 标准空 hook |
| Selflearn | `unarmed` | 有 | 已保留 str `+2` 边界效果 |

因此当前实现的 Practice + Selflearn 已保留所有可达的 authored level-up state mutation；没有因 deferred callback 丢失已确认 mutation。

## 缺陷、歧义与延期

`include/globals.h` 定义 `SKILL_D(x)` 为 `/daemon/skill/` 加技能 ID；因此 `nine-moon.c` 的触发 daemon ID 是 `nine-moon`，但其 hook 唯一读取 `nine-moon-sword`。全 mudlib 搜索未找到 `nine-moon-sword` daemon，也未找到能证明这两个 ID 等价的技能状态写入路径。`feature/skill.c::query_skill(skill, 1)` 对缺失 raw skill 返回 0，所以按字面行为，缺失 `nine-moon-sword` 时 `0 % 10 == 0`，每次 `nine-moon` 升级都会加 2000 杀气。本阶段保留这一可确定的运行时语义；没有改读 `nine-moon`，也没有 clamp。它被记录为 D 类旧缺陷/作者意图歧义，但不伪装成未来依赖。此处没有新增设计决定，因此不更新 `DECISIONS.md`。

四个 `d/skill/` 定义不是 typed deferred gameplay effect，而是当前 LPC dispatch 不可达的旧源码副本；把它们注册进 active registry 会造成重复或冲突效果。若未来 authored-skill 内容迁移发现明确直接使用 `/d/skill/` 的历史存档或脚本证据，需要重新审查，尤其是读取 `force` 的旧 `d/skill/unarmed.c`。

所有 active hook 的消息文字延期到表现层。learn、study、教师、师徒/门派、物品/书籍、战斗、perform/exert/cast/conjure、动作表、运行时调度和 UI/world 均未实现。未来这些系统若也调用通用 `improve_skill()`，必须在其各自已审计的升级调用点消费同一 typed result；不得把作者副作用塞回 `CharacterSkillState`。
