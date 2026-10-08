# 茅山 灵心观 content (region plan #6)

How 茅山 comes from `reference/es2/mudlib/d/temple/` and `daemon/class/taoist/`, and what the
LPC says that the code does not. Decisions are in [DECISIONS](DECISIONS.md). Package A places
the rooms and the people; B 茅山派 (林忌's apprentices, 谷衣心法, 天师剑法, 天师正道); C the
player's 茅山道术 in a fight and its practice (观想虫); D the zombies and the sheets (驱尸,
桃符纸, 僵尸追魂符).

## Placed (A)

| Room | LPC `set("objects")` | Native |
|---|---|---|
| sroad (青石官道) | — | mountain map: the broad road from Snow's mountain road (eroad3 east, its drawn steps north), running on south down the hill |
| ladder5–1 (石英岩石阶) | 进香客 (ladder2), 玄真 (ladder1) | the white quartz stairs zigzagging up between rows of pines |
| entrance (灵心观前) | — | the paving before the 山门 (「灵心观」); through the gate is the next map |
| square (灵心观广场) | — | grounds map: the quartz square, the lions and dragon pillars, the censer; the red door north |
| temple1 (大殿) | 林忌, 僵尸侍者, 僵尸护法 | 真武大帝's statue and the altar; round arches east and west |
| corridor1–7 (回廊), inneryard (天井) | 玄和 (inneryard) | the covered walkways round the courtyard (flowers, the well in its north-west corner) |
| temple2 (后殿), trainroom (练功房), restroom1–2 (厢房) | 老道士 (restroom1), 清虚 + 明心 (trainroom) | the rear hall behind its shut red door, the training hall, two guest rooms, each behind its door |
| road1, road2 (青石小径) | road2: reset() draws its guards | the mossy path under the pines round behind the rear hall; the slab by the 藏经楼's door |
| book_room1 (经楼) | — | the 藏经楼's ground floor on the path (bookshelves, the ladder) |
| book_room2 (经楼) | — | library map: the upper floor, 张天师's portrait and the table under its red cloth |

## LPC → native (A)

| LPC | Native |
|---|---|
| create_door() without DOOR_CLOSED (square, corridor7, corridor3, corridor4) | world.json doors with `open`; corridor5's red door starts shut |
| road2.c reset(): `guard_taoist` + (random(3)+1) and `taoist_guard` + (random(3)+1) | six world.json spawns with `draw` groups (InitialSpawnPolicy.DRAWN): one of each group comes at the world's start and at each reset |
| road2.c valid_leave() | exit rule `not_family` (family.maoshan) with `pass_lines` |
| book_room1.c valid_leave() | exit rule `never` with `pass_lines` |
| road1.c valid_leave() | exit rule `kar_slip` (random(kar) < 3): the line, unconcious(), no way through |
| road2.c item_desc slab | a look-only landmark |
| set("class", "taoist") on the NPCs | npcs.json `class`: rankd.c's query_self (贫道) and query_respect in their spar and 打听 lines |
| necromancy/invocation.c | InvocationSpell (召护法): 100 mana, 60 sen, random(max_mana) < 200 nothing, then !random(3) a 天将, else a 阴鬼卒 |
| obj/npc/hell_guard.c | common.npc.hell_guard: a summoned NPC (name_pick 子–亥阴鬼卒, its lines in HIB), 重钢战甲 and 五股钢叉 |
| skills gouyee, taoism, scratching | skills.json (valid_learn lines of the policies already in code); 谷衣心法 hits with std/force.c |

## Source anomalies

- broom1.c and broom2.c are copies of book_room1.c/book_room2.c (broom2 an empty 书库) that
  no exit leads into: not placed. `d/temple/obj/` duplicates `npc/obj/` (NPCs carry through
  `__DIR__`, which is `npc/`); jade_hat.c and robe1.c exist only in `npc/obj/`.
- taolord.c's recruit_apprentice() lowers `apprentice_availavble` (misspelt), so
  `apprentice_available` stays 3 and 林忌 never runs out of places (the bonze, dancer, fighter
  and lama masters share the typo). Nothing resets it either.
- trainer.c's `cast manimate on corpse` names no spell of 茅山道术, and `cast animate on
  corpse` is refused in a fight (animate.c): in its chat_msg_combat both draws do nothing.
- zombie.c and hell_guard.c set chat_chance but no chat_chance_combat, so npc.c chat() never
  runs their chat_msg_combat: the 阴鬼卒 never says 孽障！随我赴阴司受审吧, the zombie never
  bites (do_bite()).
- 林忌 has 天师剑法 100 but maps no sword skill: he fights with 基本剑法.
- sword.c's hit_ob() acts only on a ghost (is_ghost()); tools/tests checks that no ghost NPC
  is placed before it is ported.
- necromancy/astral_vision.c sets apply/astral_vision, which nothing in the mudlib reads.
- earth-warp.c's sheet sets `attach_func`, which attach.c does not call (it knows only
  do_scribe_haunt); attach.c moves the sheet to /obj/void first, so the sheet is lost.
- old_taoist.c's long says 观心观 (the temple is 灵心观): kept as written.
- trainroom.c's short 练功\房 and taoist.c's 运功\导气 are Big5 artifacts; MudOS reads `\房`
  as 房.
- npc/obj/magic_book.c and spells_book.c have a lost character in a comment
  (`(difficulty - int)*5%`).
- daemon/class/taoist/sword.c's 王□ is a character outside GB2312: 王禅 (owner, default).
