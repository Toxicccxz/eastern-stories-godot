# 天驼关 content (region plan #10)

How the region comes from `reference/es2/mudlib/d/canyon/`, and what the LPC says that the code
does not. Decisions are in [DECISIONS](DECISIONS.md) (「天驼关 A」 holds the plan, the owner's
answers and the defaults). Package A draws the pass, the camp and the 兵器库 and places the
people; B the 印鉴 chain (the 军师's secret, the swear, the 后备兵's two seals, the 古剑); C the
side way west of the pass (黄石穿林路, the mirror, the 竹林道, the stone and the 劲竹书).

## Placed (A)

17 of the 27 room files, on three maps. The 黄石穿林路, 梦幻迷境 and 竹林道 (8 rooms) come with C
(owner, plan Q1: repaired); dream/tmp.c and evil/tmp.c (整修中，请往回走:P) are not placed.

| Map | Rooms | People | Ways |
|---|---|---|---|
| canyon.clifftop (碎石小路) | road | — | north-east to Snow's 青石官道 (sroad4); the chain down |
| canyon.pass (黄石隘口, 天驼关) | canyon1–7, camp1–8 | 小兵 ×2 at the gate, 小兵 ×4, 老兵, 小队长 ×2, 大队长, 老队长, 李信, 严廷殷, 赫造基 | the chain up; south of the valley nothing yet (玉螺湖村 is #11); east into the 将军营帐 only with marks/军营 |
| canyon.armory (兵器库) | blackmarket | 后备兵 | east out onto 隘口中道; the way in is the oath at its smooth wall (B) |

The chain is no walk, so the clifftop is a map of its own (Old Pine's one map per height).

## LPC → native (A)

| LPC | Native |
|---|---|
| snow/sroad4.c southwest, road.c northeast | portals `snow.sroad4.southwest` / `canyon.road.northeast` (Snow's "not open" cliff is the gravel path now) |
| road.c, canyon1.c do_climb() | act services `canyon.road.chain` (爬下去: 20 gin, 30 kee, 10 sen) and `canyon.canyon1.chain` (爬上去: 30, 40, 20): message_vision(), receive_damage(), the move whatever is left; one taken below zero faints on the heart beat, and is asked first (owner's rule); the tell_room() lines are for others |
| road.c, canyon1.c, canyon5.c, canyon6.c item_desc | look landmarks; canyon6.c's key is misspelt `mechine` (look machine found nothing): looked at as the long names it |
| camp2.c resource/water | water service `canyon.camp2.well` |
| camp7.c valid_leave() | exit rule `canyon.camp7.east` (`no_mark` 军营) |
| vice_general.c init()/greeting() | greeting rule (`not_mark` 军营): 大胆狂徒，竟私闯此地，给我滚出去 and the move to camp2, a second after the player comes in (ES2: call_out 0), not while he fights |
| captain.c accept_object() | rules: worth nothing → ㄟ....Ｔhank Ｙou!!! (kept; grin prints nothing); listed → 哦喔！还真有心啊; else the gifts add up under `tally` 军营 (owner, Q2) until 3000 (30 两): listed, the count settled; less → 你的诚意不够喔，再多缴点吧。 (kept, counted) |
| captain.c tell_story(), make_stage() | inquiry rule `make` (NpcMaking without gives): the seven HIG lines two seconds apart to the asker, wherever they are (leaving the map: the rest at once, as 晚月庄 C); asking again starts it over (ES2 ran two at once) |
| general.c, adviser.c, seller.c accept_object(); canyon4.c do_swear() | [the 印鉴 chain](#the-印鉴-chain-b) |

Lost characters (text_replacements.json): 这□ → 这里 (裡), 里面, 营帐里; 威风凛凛; 睿智 (叡); uncertain:
□、簋、爵 → 鼎 (the vessels in the 将军营帐), 挡点□来花花 → 挡点钱来花花 (老兵 asking for money).

## The 印鉴 chain (B)

| LPC | Native |
|---|---|
| adviser.c accept_object() | rules: worth nothing → ㄟ....Ｔhank Ｙou!!! (kept); told already (set_temp 军营/swear) → 即然你那么有心，那我就勉强收起来了。 (kept); 800 or more → the three lines of the secret (its hint (swear) dropped: the oath is a button) and 军营/swear; less → 钱太少了吧！没收。 (kept, as he says) |
| canyon4.c init(), do_swear() | act service `canyon.canyon4.swear` (光滑的山壁 · 发誓：我爱东方故事II, owner Q3), offered only with 军营/swear, its point without a diamond: set_temp(军营/swear, 0) (`clear_temp`), the ten message_vision() lines (你 for $N, each in its opening colour) and the move into the 兵器库; the tell_room() lines are for others |
| seller.c accept_object() | value() exactly 30000 (three gold, 300 silver …): the fake 印鉴 and Get_seal, once (after it, while the player still carries the fake or once he swapped: 我已经给你了啊。/那么多钱，那我就没收了:P, kept; one who lost the fake buys again, 默认); violate_unique() exists nowhere (0); without his own temp check, the fake from one with 将军/kick → the real one, 将军/kick deleted, check set (an NPC flag, saved); otherwise 你给我这个做什么？我不要，你拿回去吧。 (refused); with check, money is kept and the rest refused (deviation, 默认) |
| general.c accept_object() | the real 印鉴 (`item`, the names differ only by colour) → 真是谢谢你了。, 为了答谢你，这把古剑送你，当做报酬吧。 and a new 古剑 (he keeps the 印鉴; smile prints nothing); the fake → three lines, set_temp 将军/kick, the move to the camp fire and return 0 (严廷殷没有收下。, the fake stays with the player); worth nothing → Thank You; anything else → 啊，真是谢谢你了。 |
| npc/obj/fake_seal.c, seal.c, old_sword.c | items made only by these gifts: 印鉴 worth 3000 (weight 0: base_weight is combined.c's), the real 印鉴 (HIY name shown plain; long 泛著黄光), 古 剑 (研读: sword to 50 from 2500 exp, 20 sen at difficulty 15) |

The way through: 30 taels to the 大队长 (A), 8 to the 军师, the oath, 3 gold to the 后备兵, the fake
to 严廷殷 (thrown out), 8 taels more and the oath again, the fake back to the 后备兵, the real one
to 严廷殷.

## Not placed

npc/obj/chicken_leg.c, cola.c (only a replica_ob), hat2.c, wineskin.c and npc/obj/parry_book.c (a
copy of the 竹林道's book without F_UNIQUE): nothing carries or places them. `replica_ob`
(broken_sword.c, cloud_armor.c, old_sword.c, the books) is read only by F_UNIQUE, which the mudlib
never defines.
