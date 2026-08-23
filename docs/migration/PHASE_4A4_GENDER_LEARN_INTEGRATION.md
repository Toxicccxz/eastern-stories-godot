# Phase 4A4：最小 Gender Fact 与 Learn Policy 接线

## 范围与结论

本阶段只增加 `CharacterState.gender: StringName`，并把该事实接入 `stormdance` 与
`tenderzhi` 的 `valid_learn()`。代码保持纯 typed `RefCounted` domain；没有
`CharacterIdentityState`、base/effective gender、创建 UI、race factory、NPC、save、
表现、门派、婚姻、armor、inventory、combat 或 world 依赖。

45 个 active 显式 `valid_learn()` hook 的当前分类为：**44 个完整可执行 + 1 个 legacy
dependency 阻断**。唯一阻断项仍是 `nine-moon`。另有 25 个继承 `std/skill.c` 默认允许
的已知技能，总数仍为 70；未知 ID 仍不自动取得默认 policy。

## 直接复核的 LPC 来源

Gender 表示、默认与创建证据：

- `reference/es2/mudlib/feature/dbase.c`
- `reference/es2/mudlib/adm/daemons/logind.c`
- `reference/es2/mudlib/adm/daemons/chard.c`
- `reference/es2/mudlib/adm/daemons/race/human.c`
- `reference/es2/mudlib/adm/daemons/race/monster.c`
- `reference/es2/mudlib/adm/daemons/race/beast.c`

本阶段实际接线或保持阻断的 authored hook：

- `reference/es2/mudlib/daemon/skill/stormdance.c`
- `reference/es2/mudlib/daemon/skill/tenderzhi.c`
- `reference/es2/mudlib/daemon/skill/nine-moon.c`

`feature/dbase.c` 证明 persistent `dbase` 与 static `tmp_dbase` 分离，普通 `query()` 会
精确返回 authored/default 值；gender 没有 temp/apply 层。`logind.c` 强制新玩家明确选择
男性或女性，因此 native 通用状态不能默认男性。Human fallback 与 monster/beast 缺值
补写属于未来创建/import policy，不进入本阶段。

## Native gender 表示

`CharacterState` 直接拥有一个 scalar：

```gdscript
var gender: StringName = &""
```

同一类型提供四个稳定 canonical authored constants：

| Constant | LPC 值 |
|---|---|
| `GENDER_MALE` | `男性` |
| `GENDER_FEMALE` | `女性` |
| `GENDER_ANIMAL_MALE` | `雄性` |
| `GENDER_ANIMAL_FEMALE` | `雌性` |

空 `&""` 表示 unresolved/absent legacy gender。类型保持开放：任意 custom
`StringName` 可原样保存，不验证、不拒绝、不归一化。`雌性` 不等于 `女性`，`雄性` 不
等于 `男性`；empty、custom 也不等于任何 canonical value。没有 enum、Dictionary、
`is_feminine()`、pronoun 或 biological helper。

每个 `CharacterState` 持有自己的 scalar；无需新增可变 child state，也没有共享默认实例。

## Exact-gender policy primitive

`RequiredGenderSkillLearnPolicy` 只保存：

- policy 自身的稳定 skill ID；
- required `StringName` gender。

它执行一次 `student.gender != required_gender` 精确比较。失败返回 typed
`GENDER_MISMATCH`，并通过既有 `actual_id/required_id` 保存原值与要求值；成功返回
`ALLOWED`。它没有 operator/invert/mode flag、自由 payload、LPC 文本或 identity 条件
解释器。

## Stormdance

`daemon/skill/stormdance.c::valid_learn()` 的源顺序为：

1. `query("gender") == "女性"`；
2. persistent base `query("spi") >= 20`；
3. allow。

Registry 用 `OrderedSkillLearnPolicy` 组合：

```text
required 女性
  -> minimum base spirituality 20
```

新建的 `MinimumBaseSpiritualitySkillLearnPolicy` 只读取
`student.attributes.spirituality`。它不调用 effective spirituality，也不读取
`spirituality_modifier`。边界测试覆盖 19 拒绝、20/21 允许，并证明 gender 与
spirituality 同时失败时先返回 gender mismatch。

## Tenderzhi

`daemon/skill/tenderzhi.c::valid_learn()` 的源顺序为：

1. `query("gender") == "女性"`；
2. `query_temp("weapon")` 与 `query_temp("secondary_weapon")` 都为空；
3. allow。

Registry 组合：

```text
required 女性
  -> RequireBothWeaponRefsEmptySkillLearnPolicy
```

第二步直接复用 Phase 4A2 已审计的两个 legacy weapon reference 事实。测试覆盖两手空、
主武器、副武器单独占用、两引用同时占用，以及 male+armed 时 gender failure 必须先于
weapon failure。

## Nine-moon 仍然阻断

`daemon/skill/nine-moon.c::valid_learn()` 的顺序仍是：

1. female gender；
2. `max_force >= 50`；
3. mapped `force == nine-moon-force`；
4. primary weapon `skill_type == sword`。

这些状态事实现在都可表达，但 authoritative mudlib 中仍没有 active
`daemon/skill/nine-moon-force.c`。Registry 因此继续显式注册
`LEGACY_REQUIRED_SKILL_MISSING` dependency policy；没有发明定义、替换成 `nine-moon` 或
`nine-moon-sword`，也没有把该 hook 改成 executable。

Gender 不再是 `nine-moon` 的缺失状态依赖；缺失 active skill daemon 仍是决定性 blocker。

## Registry 数量

| 集合 | Phase 4A2 | Phase 4A4 |
|---|---:|---:|
| Active explicit overrides | 45 | 45 |
| Executable explicit policies | 42 | 44 |
| Gender-blocked | 2 | 0 |
| Legacy/dependency-blocked | 1 | 1 |
| Inherited `std/skill` defaults | 25 | 25 |
| Known active total | 70 | 70 |

测试使用独立列出的 45 个显式 ID 对每个 policy 求值，确认只有 `nine-moon` 返回
`DEPENDENCY_UNAVAILABLE`；不是从 registry 内部 Dictionary 反推计数。25 个 inherited
ID 也独立列出并验证为 explicit `DefaultSkillLearnPolicy`。Unknown ID 返回 null。

## LearnService 集成

`LearnService` 没有修改，也没有复制 gender 到 `TeachingContext`。它仍在原
`valid_learn()` 位置直接把 student `CharacterState` 交给 policy：教师/关系/raw 等检查
之后，成本、raw-zero 写入、potential、教师 sen、学生 gin 与 `improve_skill()` 之前。

端到端测试证明：

- female + base `spi >= 20` 可成功 Learn `stormdance`；
- female + 两武器引用为空可成功 Learn `tenderzhi`；
- 两条成功路径都以 LPC 阈值可追溯的确定性 improvement amount `2` 让新技能从 raw `0`
  升至 `1`，并显式验证 `SkillImprovementResult` 与既有
  `SkillImprovementEffectRegistry` 返回链；`stormdance` 在等级 `1` 正确评价为无属性
  mutation，`tenderzhi` 正确使用标准空 hook；
- gender mismatch 不创建 raw-zero entry、不消耗 potential、不支付教师 sen、不 damage
  学生 gin，也不调用 `improve_skill()`；
- armed male 的 `tenderzhi` 仍先返回 gender mismatch；
- armed female 通过 gender 后才返回 weapon-reference rejection。

## Legacy anomaly 与明确延期

- `d/green/npc/kid4.c` 的 function-valued gender 是 authored NPC 动态值异常；没有放入
  通用 `CharacterState`，也没有据此建立 effective gender。
- `中性神` 没有 active writer/content，不是 canonical gameplay value。
- Human `男性` fallback、monster/beast `雄性` default、玩家 m/f 创建、旧档 import、save
  和 NPC definition 全部延期到各自 factory/content 阶段。
- Pronoun、称谓、displayed identity、marriage、recruitment、female-only wear、scripted
  room/NPC interaction、inventory、combat、world 与 UI 全部延期。
- `nine-moon-force` repair 明确延期，且在没有 authoritative source 或产品决定前不得猜测。

本阶段没有发生 LPC-to-native 行为替代，因此未修改 `DECISIONS.md`。Phase 4A3 的语义
结论保持成立；其辅助扫描总数有一项审计修正，记录如下。

## 正式审计补强

Phase 4A4 正式审计没有发现生产代码的 gender 表示、精确比较、短路顺序或 registry
分类错误。审计发现原成功路径测试只以 learned progress 间接证明 `improve_skill()` 被
调用，未直接证明 typed improvement result 与 authored-effect registry 链路。上述端到端
测试已改为触发一次确定升级并直接断言两层结果；同时补充独立 malformed legacy
`StringName` 的原值保存与精确 mismatch。该修正只增加证据，不改变生产行为。

全 mudlib `*.c/*.h` 的独立复扫再次得到 61 次 `query("gender")` 调用，但实际只有
253 次 `set(... "gender" ...)` 调用，不是 Phase 4A3 历史文档记录的 254 次；另有
`monster.c` 与 `beast.c` 各一次直接 mapping 写入，所以写入点应为 255、读写点合计应为
316。该差一计数不改变 active 值域、默认来源、consumer 分类或任何 Phase 4A4 生产
规则；为保持历史阶段记录不被本审计改写，修正只记录于本文。
