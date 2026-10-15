# 鬼门关 content (region plan #13)

How 阴间 comes from `reference/es2/mudlib/d/death/` and the death code (`feature/damage.c` die(),
reincarnate(); `include/login.h` DEATH_ROOM, REVIVE_ROOM; `adm/daemons/chard.c` make_corpse();
`adm/daemons/logind.c`), and what the LPC says that the code does not. Decisions are in
[DECISIONS](DECISIONS.md) (「鬼门关 A」 holds the owner's answers and the defaults). Package A is 阴间
and the way back; B is 阴阳眼 and the 孤魂野鬼's 布条.

## Placed

9 of 12 rooms on one map, `death.realm` (region `death`, 阴间), reached only by dying.

| Map | Rooms | People | Ways |
|---|---|---|---|
| death.realm (阴间) | bridge1, bridge, gate, gateway, road1, inn1, inn2, road2, road3 | 阴鬼牙将 ×4 (bridge), 白无常 (gate), 黑无常 (gateway) | walked south to north; no way back south from gateway; road2's north refused four times; the way out is reincarnate() (the gargoyles' last line, the little shop's 回家) to the Snow temple |

Not placed: block.c (「离岛」管训所) and jail.c (绿岛), wizard punishment rooms nothing leads into;
spath1.c (墙边小路), west of the gateway in its text but no exit leads into it (gateway.c has no
west). d/death/obj/ holds byte-identical copies of npc/obj/'s fork.c and hell_armor.c (one item
each, both sources listed).

## LPC → native

| LPC | Native |
|---|---|
| damage.c die() for a user: gin/kee/sen and eff_ 1, ghost = 1, move(DEATH_ROOM) | PlayerDeathRules.die() (CharacterState `ghost`); the death card (PlayerLifeOverlay) until 继续, then WorldSessionController moves the ghost to `death.gate.arrival` |
| DEATH_ROOM->start_death() | gate.c defines none: call_other() did nothing |
| damage.c reincarnate(), move(REVIVE_ROOM) | ScriptedAct step `reincarnate`: the session makes the move to `snow.temple.revive` the same frame, after the map's beat; ghost = 0, eff_ back to max |
| wgargoyle.c / bgargoyle.c init(), death_stage() | NpcHooks `calls`: five lines at 5, 10, 15, 20 and 25 seconds after the player comes in while they stay (present(ob)); the last with the fog line and `reincarnate`; `calls_hold` (owner Q2): no random_move while they are to come. 白无常 in HIW, 黑无常 in HIB |
| bgargoyle.c death_stage() for one who is no ghost (say, kill_ob()) | not ported: only earth-warp.c sent the living here, and it never worked |
| wgargoyle.c chat_msg's (: this_object(), "random_move" :) | random_move |
| hell_guard.c set_name(order[random(12)] + "阴鬼牙将"), is_ghost() | `name_parts`; `ghost` (seen only by a ghost, no corpse); vendetta_mark hell (killing one marks vendetta/hell) |
| gateway.c valid_leave() | exit rule `death.gateway.no_return` (`always`) for the player only |
| road2.c valid_leave(), long_road | exit rule `death.road2.long_road` (`tries`): set_temp("long_road") counts; the fifth try goes on; a refused one is put back at `death.road2.long_road`; leaving road2 any way deletes it |
| road3.c 「..... 还没想到 ....」 | source fix (owner Q3 (b)): 浓雾在这里聚成一堵墙，路到这里就断了。 |
| gate.c's short with raw ANSI escapes | source fix: 鬼门关 (the colour is presentation) |
| inn1.c item_desc shadows, inn2.c item_desc wall | look landmarks, word for word |
| inn1.c redirect_ask(), do_stuff() | act service `death.inn1.ask_home` (人影 · 打听「回家」): the two write() lines, `reincarnate` |
| logind.c: a ghost logs in at DEATH_ROOM | Continue of a ghost puts it at `death.gate.arrival` (D7) |
| chard.c make_corpse() of a ghost | the player's DeathContext carries `ghost`: no corpse, the things fall |
| food.c, liquid.c is_ghost() | FoodUseResult / LiquidUseResult `GHOST` (你已经是鬼了，不能吃东西！/ 喝东西！) |
| drift_sense.c is_ghost() | DriftSenseConjure: 你失败了。 after the cost |
| rankd.c query_rank() is_ghost(), name.c (鬼气) | RankWords.query_rank(…, ghost): 【 鬼  魂 】; the character sheet's (鬼气) |
| char.c visible() | a ghost player sees ghost NPCs (bodies drawn, picked, met); NPCs' combat profile `sees()` reads the player's ghost |

## Source anomalies

- gate.c's short holds raw terminal escapes instead of the ansi.h macros.
- road3.c is unfinished (「还没想到」); the long road leads to it all the same.
- spath1.c's text describes a way west from the gateway that no exit makes.
- bgargoyle.c's living-visitor branch can only fire for one earth-warp.c brought, and attach.c
  never ran that sheet (DECISIONS 茅山).
- A gargoyle that walked off (random_move) cut its own chain (present(ob) fails); one entered
  twice ran two chains.

## Not done (and where it goes)

- B: 阴阳眼 (daemon/class/taoist/necromancy/astral_vision.c): std/char.c visible() reads
  apply/astral_vision, so it lets a living 茅山 player see ghosts; [TEMPLE_CONTENT](TEMPLE_CONTENT.md)
  said nothing reads it, which was wrong. It is the only way to the 孤魂野鬼's 布条 in 乔阴.
