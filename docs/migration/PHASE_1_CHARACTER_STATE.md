# Phase 1: Character State Foundation

Phase 1 implements only deterministic, presentation-independent character state. The Godot code uses typed `RefCounted` classes and does not reproduce LPC dbase access, inheritance, heartbeats, or runtime object behavior.

## Authoritative LPC sources

- `reference/es2/mudlib/feature/attribute.c` — effective attribute calculations.
- `reference/es2/mudlib/feature/damage.c` — current/effective/maximum resource mutation and threshold side effects.
- `reference/es2/mudlib/adm/daemons/chard.c` — race setup dispatch, full-resource initialization, and encumbrance.
- `reference/es2/mudlib/adm/daemons/race/human.c` — human resource maxima and weight.
- `reference/es2/mudlib/adm/daemons/race/monster.c` — monster resource maxima and weight.
- `reference/es2/mudlib/std/char.c` — character composition and death-before-unconscious threshold order.
- `reference/es2/mudlib/cmds/usr/hp.c` and `cmds/usr/score.c` — displayed meanings of `gin`/`kee`/`sen` and the eight attributes.
- `reference/es2/mudlib/include/race.h`, `include/race/monster.h`, and `include/race/beast.h` — race daemon identities and weight constants.

## Legacy-to-Godot mapping

| LPC field | Godot field | Meaning |
| --- | --- | --- |
| `str`, `cor`, `int`, `spi`, `cps`, `per`, `con`, `kar` | `strength`, `courage`, `intelligence`, `spirituality`, `composure`, `personality`, `constitution`, `karma` | Base attributes |
| `force_factor`, `bellicosity` | Same names | Persistent inputs used by effective attribute formulas |
| `apply/strength` etc. | `<attribute>_modifier` | Typed modifier slots; their future producers are out of scope |
| `gin`, `eff_gin`, `max_gin` | `essence.current`, `.effective`, `.maximum` | Essence resource track |
| `kee`, `eff_kee`, `max_kee` | `vitality.current`, `.effective`, `.maximum` | Vitality resource track |
| `sen`, `eff_sen`, `max_sen` | `spirit.current`, `.effective`, `.maximum` | Spirit resource track |

`CharacterState` composes attributes plus those three resource tracks. A resource enforces `-1 <= current <= effective <= maximum`, with non-negative maximum. Invalid negative maxima are rejected rather than silently normalized. The `-1` floor preserves the sentinel used by `feature/damage.c`; zero remains conscious/alive because `std/char.c` tests strictly below zero.

## Implemented formulas and rules

- Effective attributes reproduce `feature/attribute.c`, including integer division for `bellicosity / 50` and `force_factor / 2`.
- Damage lowers current only; wound lowers effective and clamps current to it. Values crossing below zero saturate at `-1`.
- Healing raises current up to effective. Curing raises effective up to maximum. Return values preserve the differing LPC behavior: capped healing returns the request, while capped curing returns the amount applied.
- Negative damage, wound, healing, and curing amounts trigger the debug assertion corresponding to LPC `error()` and are rejected before mutation even when Godot assertions are disabled.
- Aggregate character status checks any effective track below zero for death before checking any current track below zero for unconsciousness.
- Human and monster maximum `gin`/`kee`/`sen` age formulas are direct translations of their race daemons. Positive human `max_atman`, `max_force`, and `max_mana` inputs contribute one quarter using integer division.
- Weight formulas use each race's `BASE_WEIGHT` and `(str - 10) * 2000`. Maximum encumbrance uses base `str * 5000` from `chard.c`.

## Deliberately deferred ambiguity and behavior

- Random default age/attribute generation is excluded to keep Phase 1 deterministic.
- The LPC files do not define one authoritative validation range for authored ages or attributes. The pure calculators preserve the formula branches for any integer and do not invent input clamps.
- Race setup preservation rules—including human `userp()` recomputation, monster authored maxima, existing weight, and existing encumbrance—belong to a future character-initialization policy; this phase exposes pure calculators only.
- `chard.c` initializes undefined current/effective fields to their maxima. The native model has no undefined-field state; constructing a fully initialized character from derived maxima remains a future factory responsibility.
- `heal_up()`, food/water, atman/force/mana regeneration, and skill-derived recovery are coupled to systems outside Phase 1.
- Unconscious/revive timers, death, ghosts, corpses, rewards, and `last_damage_from` are lifecycle/combat behavior, not resource-state mutation.
- Race defaults, beast formulas, limbs, actions, speech, gender, and NPC setup are not part of the minimal character foundation.
- Direct LPC dbase writes could temporarily violate resource ordering. The native model deliberately maintains the requested invariant at its boundary rather than recreating unrestricted `set()` behavior.

## Legacy defects noted

- `race/monster.c` contains duplicated assignments in the over-60 `max_gin` branch and over-30 `max_kee` branch. The duplicate has no value-level effect and is omitted.
- The LPC function name `unconcious()` is misspelled. Native names use `unconscious`.
- Monster setup initializes only `str`, `int`, `per`, and `con`; no defaults for the other base attributes are inferred here.
