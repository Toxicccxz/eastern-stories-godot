# 黑松山 content (region plan #12b)

How the region comes from `reference/es2/mudlib/d/chuenyu/`, and what the LPC says that the code
does not. Decisions are in [DECISIONS](DECISIONS.md) (「黑松山 A」 holds the plan, the owner's
answers and the defaults). Package A draws the road, the mountain and the castle; B the 地牢,
淳于怀太 and 小娟, and 刘老农's thanks and revenge in 玉螺湖村.

## Placed

23 of 37 rooms in A, on two maps; B places the 地牢's nine.

| Map | Rooms | People | Ways |
|---|---|---|---|
| chuenyu.main (黑松山) | croad1–2, sunnyroad, base_b_m, foot_b_mtn, high_b_mtn, rope_bridge, high_b_mtn2, gate_castle, east_castle, west_castle, trap_castle, west_garden, north_garden, west_blackge, storage, center, east_blackge, east_garden, south_garden | 卖花姑娘, 紫衣家丁 ×2, 园工, 蜜蜂 ×2, 小园工 ×4, 护院 ×2, 女佣人, 巨型犬 ×3 | east to 玉螺湖村's 黄土大道 (road1); the 城门 (shut) to the 夹道; 城墙 · 爬上去 between the clifftops and the gardens; 铁链 · 顺着走下去 from the bridge; the 储藏室's 木门 (shut); each hall's stairs up |
| chuenyu.upstairs (淳于's rooms) | bedroom, yiantai, kitchen | 信鸽 ×2, 厨子 | the two stairs down; the 玉帘门 (shut) to the 膳房 |

Not placed: the copy of 刘家 (dustyroad3, home, littlegarden, smallstorage, smallyard, with a
second 刘老农, 采花妞, 大老鼠 and smallyard's 蛐蛐, 蚂蚁 and 蝴蝶): ES2 cut it off (sunnyroad.c's
south is commented out, croad2.c has no way to it) and placed its rooms and people in 玉螺湖村
(owner Q1 (a)). jiading.c and jiading2.c (青衣, 蓝衣家丁) and npc/xiaojuan.c (a copy of
xiaojuan2.c) are placed by no room.

## LPC → native (A)

| LPC | Native |
|---|---|
| croad1.c south → d/village/road1 (road1.c has no way back) | portals `chuenyu.croad1.south` / `village.road1.west` (owner, 玉螺湖村 plan Q2: the spur west off the 黄土大道) |
| croad2.c's tea house | the text's only: drawn as a building with no door |
| sunnyroad.c no_fight, no_magic | room flags; the 卖花姑娘's random_move takes her to the crossing and the foot |
| foot_b_mtn.c up → high_b_mtn (no way down from there), high_b_mtn2.c down → base_b_m (no way up) | zone borders walked both ways (M2) |
| gate_castle.c init(): combat_exp < 2000 moved back to high_b_mtn2 | exit rules `chuenyu.high_b_mtn.killing_air` and `chuenyu.high_b_mtn2.killing_air` (`combat_exp_below` 2000): 你被黑松堡散出的强烈杀气当了回来。, the player staying on the street they came up (ES2 moved them to high_b_mtn2). The only ways onto the gate are the two streets' |
| trap_castle.c init(), arrowing() | hazard `chuenyu.trap_castle.arrows`: 15 s after coming in, then every 5 s while the player stays, the two HIW lines and eff_kee and kee down random(10)+35 (`hurt`); it can knock out and kill (the room's look and noise warn). Leaving and coming back waits 15 s again |
| east/west_castle.c, east/west_garden.c climb, fliping() | act services `chuenyu.<room>.climb` (城墙 · 爬上去): the climb's and the jump's lines, then move() at once (M1: ES2 three seconds later; its start_busy(3) was stopped at once anyway) |
| rope_bridge.c do_climb() | act service `chuenyu.rope_bridge.climb` (铁链 · 顺着走下去) to the foot; the room's only line for anything else (这里只有一条铁链（chain）。) is the chain's look. The comment's dodge check was never written |
| center.c roping() | B (the fall into the 地牢); A has the rope's look |
| item_desc | look landmarks, word for word (北花园's and the 夹道's 巨石, the 圆孔, the 声音, the 青石板) |
| jiading3.c checklooking(), kill_passenger() | greeting rule `per_below` 20 (random(query("per")) < 20) a second after the player comes in: his two says (家丁喝道： inside his own say kept, as 刘老农说道), npc_flags hunts_player (kill_ob()'s killer list: attack.c's hatred, cleared by the player's death) and aggressive (set("attitude", "aggressive"): he attacks on sight for good, until made anew) and the kill |
| guard.c init() kill_ob(), pursuer | capability aggressive_on_player_presence; pursuer not modelled (M5) |
| wolfdog.c attitude "killer" | attitude killer: aggressive for npc.c accept_fight() and ask.c, not for attack.c init(); its bellicosity 3000 berserks. Its chat_msg_combat is never said (no chat_chance_combat) |
| gardener.c chat_msg_combat | cast invocation (召护法); its two cast animate draws do nothing (M5, as 茅山's NPCs) |
| flower_seller.c, cook.c greeting() | greeting one_of, the say() lines as written (the 卖花姑娘's stray leading space dropped; the cook's unclosed quote kept) |
| pigmeat.c (HAMMER + F_FOOD), finish_eat() | food that is a hammer (M4): six bites of 90, eaten while wielded too; it leaves the 山猪骨头 (rib, bone), the same hammer. u/cloud's 牛腿 likewise (牛腿骨) |
| qiwine.c | a wineskin of 竹叶青 (alcohol, drunk_apply 10) |

## Source anomalies

- The mudlib keeps two copies of the objects: `obj/` (what the rooms place) and `npc/obj/` (what
  the NPCs carry; the flowers are coloured there, and npc/obj/hengbing.c is worth 50000 against
  obj/hengbing.c's 500000). Each NPC's own copy is used.
- bedroom.c's long puts the 膳房 west; its exit (and door) is south. north_garden.c's long calls it
  the 东花园. Both fixed (M6: override source_fixes).
- tortureroom2.c is a copy of tortureroom.c with the same exits; tunnel4.c's push count was 13
  (commented) and is 5 (B).
- east_castle.c's 青石板 opens only from below (tunnel4.c's push).
