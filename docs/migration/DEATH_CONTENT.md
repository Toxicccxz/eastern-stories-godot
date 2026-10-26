# 鬼门关 content (region plan #13)

How 阴间 comes from `reference/es2/mudlib/d/death/` and the death code (`feature/damage.c` die(),
reincarnate(); `include/login.h` DEATH_ROOM, REVIVE_ROOM; `adm/daemons/chard.c` make_corpse();
`adm/daemons/logind.c`), and what the LPC says that the code does not. Decisions are in
[DECISIONS](DECISIONS.md) (「鬼门关 A」 holds the owner's answers and the defaults, 「鬼门关 B」
阴阳眼's). Package A is 阴间 and the way back; B is 阴阳眼
(`daemon/class/taoist/necromancy/astral_vision.c`) and the 孤魂野鬼's 布条 (`d/choyin/npc/ghost.c`,
`obj/cloth_piece.c`).

## Placed

9 of 12 rooms on three maps, `death.realm` (region `death`, 阴间) and its two shops, reached only by
dying.

| Map | Rooms | People | Ways |
|---|---|---|---|
| death.realm (阴间) | bridge1, bridge, gate, gateway, road1, road2, road3 | 阴鬼牙将 ×4 (bridge), 白无常 (gate), 黑无常 (gateway) | walked south to north; no way back south from gateway; road2's north refused four times; the way out is reincarnate() (the gargoyles' last line, the little shop's 回家) to the Snow temple |
| death.inn1_house, inn2_house (interiors) | inn1 (小店); inn2 (黑店) | — | out east and west onto road1 |

No map here has a voxel view yet (no `game/data/death/voxel/`).

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
| bgargoyle.c death_stage() for one who is no ghost (say, kill_ob()) | calls[0] with act condition `ghost` false: 喂！阳人来阴间做什么？, npc_flag hunts_player and kill; his lines are `ghost` true. The living come here only by 游识神通 to a gargoyle met as a ghost |
| wgargoyle.c chat_msg's (: this_object(), "random_move" :) | random_move |
| hell_guard.c set_name(order[random(12)] + "阴鬼牙将"), is_ghost() | `name_parts`; `ghost` (seen only by a ghost, no corpse); vendetta_mark hell (killing one marks vendetta/hell) |
| gateway.c valid_leave() | exit rule `death.gateway.no_return` (`always`) for the player only |
| road2.c valid_leave(), long_road | exit rule `death.road2.long_road` (`tries`): set_temp("long_road") counts; the fifth try goes on; a refused one is put back at `death.road2.long_road`; leaving road2 any way deletes it |
| road3.c 「..... 还没想到 ....」 | source fix (owner Q3 (b)): 浓雾在这里聚成一堵墙，路到这里就断了。 |
| gate.c's short with raw ANSI escapes | source fix: 鬼门关 (the colour is presentation) |
| inn1.c item_desc shadows, inn2.c item_desc wall | look landmarks, word for word |
| bridge1 and bridge (奈何桥), road1 and road2 (鬼门大道): one name each | bridge1 and road2 `distinct`: their own text is read on arrival (the owner's rule for neighbours of one name) |
| inn1.c redirect_ask(), do_stuff() | act service `death.inn1.ask_home` (人影 · 打听「回家」): the two write() lines, `reincarnate` |
| logind.c: a ghost logs in at DEATH_ROOM | Continue of a ghost puts it at `death.gate.arrival` (D7): on the realm's map at once, from any other (遁 takes a ghost along) by a move the session makes once the world lets it |
| drift_sense.c select_target(): me->visible(ob) | PlayerEssenceMagic.drift_target() skips whom the player does not see (the ghosts, for the living) |
| chard.c make_corpse() of a ghost | the player's DeathContext carries `ghost`: no corpse, the things fall |
| food.c, liquid.c is_ghost() | FoodUseResult / LiquidUseResult `GHOST` (你已经是鬼了，不能吃东西！/ 喝东西！) |
| drift_sense.c is_ghost() | DriftSenseConjure: 你失败了。 after the cost |
| dun.c at oneself (no ghost check) | DunSpell: a ghost fails, 你失败了。 after the cost (owner) |
| rankd.c query_rank() is_ghost(), name.c (鬼气) | RankWords.query_rank(…, ghost): 【 鬼  魂 】; the character sheet's (鬼气) |
| char.c visible() | a ghost player, or one whose 阴阳眼 runs (CharacterState.sees_ghosts()), sees ghost NPCs (bodies drawn, picked, met); in a fight CombatSliceCharacterBinding.sees() asks it each turn |
| astral_vision.c cast() | AstralVisionSpell, 茅山道术's `cast`: the 武学 page's 法术 button outside a fight, the battle panel's 阴阳眼 (at oneself) in one; apply/astral_vision a CharacterTimedApplies entry of query_skill("spells") seconds |
| astral_vision.c remove_effect() | the spell's remove_effect(): on world time PlayerMartialArts.effects_ended(), in a fight the scheduler's SPECIAL_EFFECT_ENDED; the ghosts are unseen again from that frame |
| ghost.c carry_object(cloth_piece) | 孤魂野鬼's `carry`; dead it leaves no corpse and the 布条 falls (chard.c); `study` spells, max_skill 40 |

## Source anomalies

- gate.c's short holds raw terminal escapes instead of the ansi.h macros.
- road3.c is unfinished (「还没想到」); the long road leads to it all the same.
- spath1.c's text describes a way west from the gateway that no exit makes.
- bgargoyle.c's living-visitor branch fires for one 游识神通 brings to him (earth-warp.c's sheet
  never ran: DECISIONS 茅山).
- dun.c (遁) has no ghost check: a ghost could take itself to the Snow temple and stay a ghost
  there (owner: here it fails for a ghost; DunSpell).
- A gargoyle that walked off (random_move) cut its own chain (present(ob) fails); one entered
  twice ran two chains.
- study.c refuses only above max_skill: the 布条 still reads at 基本咒文 40 (to 41).
- astral_vision.c is the only way a living player ever sees a ghost: a dead one reincarnates before
  leaving 阴间, so the 孤魂野鬼 and its 布条 are 茅山's alone.

## Not done (and where it goes)

- ghost.c's env/wimpy 70: no NPC flees by wimpy yet (DECISIONS: wimpy is not modelled).
