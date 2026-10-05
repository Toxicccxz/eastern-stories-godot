# 野羊山 content (region plan #2)

How 野羊山 comes from `reference/es2/mudlib/d/goathill/`, and what the LPC says that the code
does not. Decisions are in [DECISIONS](DECISIONS.md).

## Placed

| Room | LPC `set("objects")` | Native |
|---|---|---|
| mroad1 | — | mountain map; south to Snow's crossroad |
| mroad2, mroad3, mroad5, mroad6 | — | mountain map |
| mroad4 (山路转角) | 土匪爪牙 ×3, 土匪首领 | aggressive, one fight together |
| temple1 (小土地庙) | 黄霸 | two 大金槌, 熊皮短靴, 伏蛟功; friendly |
| slope1, canyon1-3 | — | mountain map; canyon3 east into the caverns |
| cavern1 | 岩蛭 ×2 | caverns map |
| cavern2 | 肥岩蛭, 岩蛭 ×3 | |
| cavern3 (岩穴) | 大岩蛭 ×2, 巨岩蛭 ×2 | |
| cavern4 | 岩蛭 ×2, 大岩蛭 | |

## Source anomalies

- `cavern1.c.c` is an empty copy (空房间) nothing leads to: no room.
- `silver_worm.c` (银色岩蛭, 400000 exp) is placed by no room or code.
- The leeches set `corpse_ob` to `obj/dead_leech.c` (死岩蛭, a tonic food that rots), but no
  mudlib code reads `corpse_ob`: chard.c makes a plain corpse.
- `breast_mirror.c` (护心镜, twice: `obj/` and `npc/obj/`) is carried by nobody.
- weapond.c's bash line `$N挥舞$w，往$n的$l用力一□` lost a character in the source's conversion.
- 黄霸's long says 也羊山 for 野羊山.
