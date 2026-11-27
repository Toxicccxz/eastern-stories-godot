# Русский: style, names and the grammar marks

The Russian translation is `game/locale/ru.po` (Settings → Язык → Русский (предварительная версия)).
Worked out with Muse, 2026-11-26; ★ marks a choice the owner decides. DECISIONS「Русский (preview)」.
Check a translation with `python tools/l10n/check_po.py game/locale/ru.po` (the gate runs it too);
batches go in with `tools/l10n/po_batch.py` ([LOCALIZATION](LOCALIZATION.md#working-on-a-translation)).

Russian has no wuxia canon to copy: Jin Yong is barely translated (one novel, Книга и меч, 2024),
and none of the wuxia games has a tested Russian text. The frame is sinology's Palladius system for
names, the xianxia web-novel readers' words where they have settled (цзянху, ци, даньтянь, шифу),
and a Russian reader's ear everywhere else.

## Tone

**Old, not archaic.** Literary Russian with a 19th-century novel's steady narration; old words
only in forms of address and set phrases. Never the bylina or fairy-tale voice (молвил, сей, отрок,
аки, дескать, токмо, вельми), never modern talk or loan words (окей, круто, чувак, кайф, норм,
блин, реально, супер). Insults are period ones (Щенок! Наглец! Негодяй!), not modern slang.

* ES2's own text stays a touch formal; the new story text is short, hard and leaves things unsaid:
  the same number of sentences as the Chinese, no added «потому что» or «и тогда», no explaining
  what the Chinese leaves out.
* сударь and сударыня: never (a 19th-century Russian drawing room). господин only from servants,
  officials and the formal: «Чем могу служить, господин?». Between people of the jianghu: a name,
  a title (глава школы), or nothing.

| Text | Voice | Example |
|---|---|---|
| a room, a place | present, noun sentences welcome | В комнате пахнет полынью. На столе — чайник. |
| a fight, an action now, an NPC's action line | present | Вы бьёте бандита. Бандит отступает. |
| a blow's result, the opening, a memory, a quest's record, the journal | past | Рана раскрылась! |
| the codex | present, a definition | Цзянху — вольный мир… |
| buttons, menus | infinitive or noun | Сохранить, Загрузить, Настройки |
| tutorial, hints, system lines | вы, the polite imperative (never Нажми, no пожалуйста) | Нажмите E, чтобы поговорить. |
| quest objectives | infinitive | Расспросить слугу. |

## The player

Narration and the system call the player **вы**, lower case: «Вы видите…», «Вы ударили бандита».
Russian text games have always done so; the past tense and short adjectives take the plural, so
the player's gender is never needed. Вы with a capital only in a letter or a notice.

In dialogue people speak to the player as their relation asks (below). The narration's вы and a
speaker's ты/вы are two systems: never mix them in one line.

## ты and вы

Higher to lower ты, lower to higher вы; equals by closeness; service вы both ways.

| Who, to whom | Form |
|---|---|
| master → disciple · elder → junior | ты |
| disciple → master (with Шифу) · junior → elder | вы, never ты |
| senior brother/sister → junior | ты |
| junior → senior brother/sister | вы; ты only from a story moment that changes it |
| peers of a school | вы on meeting, ты once close |
| waiter, servant → guest · guest → waiter | вы both ways (a guest saying ты is rude in Russian; only an arrogant character does) |
| bandits ↔ the player | ты both ways |
| an official → commoners · commoners → an official | ты · вы + господин; a document Вы |
| a monk or Daoist → laymen | вы when polite, ты when an old one teaches; never ты to everyone |
| laymen → a monk or Daoist | вы |

Address: 客官 господин (дорогой гость) · 施主 благодетель / добрый человек · 贫道 «я, недостойный
даос» · 老衲 «я, старый монах» · 在下 я (ваш покорный слуга when formal; never every sentence) ·
师父 Шифу (address), наставник (narration) · 掌门 глава школы; an abbot настоятель · 大侠 герой
(странствующий герой) · 少侠 юный герой · 姑娘 барышня (a married or older woman госпожа; never
девица, девушка) · 小兄弟 братец (молодой человек neutral) · 师兄 / 师姐 старший брат / старшая
сестра (по школе the first time) · 师弟 / 师妹 младший брат / младшая сестра · 长老 старейшина.
Not шисюн, шицзе, дася, сяося: Russian readers do not know them.

## Names

**People: Palladius**, surname first, the system Russian sinology writes (never from pinyin:
no Кси, Жанг, Бейджинг): -n -нь, -ng -н (Чэнь ≠ Чэн, Линь ≠ Лин); j цз, q ц, x с, zh чж, ch ч,
sh ш, r жэ/ж; e э (Хэ, Цзэ); yi и, ye е, you ю, yu юй. 柳淳风 Лю Чуньфэн.

**Declining a Chinese name:**
* a full name declines only its given name's last syllable, the surname stays: Лю Чуньфэн →
  Лю Чуньфэна, Лю Чуньфэну;
* a man's name ending in a consonant declines (Чуньфэн → Чуньфэна; -нь, -й soft: Цзюнь → Цзюня);
  a woman's never does (Лань Чжипин, у Лань Чжипин);
* a name ending in -о -э -и -у -ю (Лю, Хэ, Ли) never declines, a man's or a woman's;
* a surname alone declines like a given name: мастер Ван → мастера Вана; мастер Лю stays.
`game/locale/ru_nouns.json` holds every such form (below); its rows are read and checked by hand.

**Places** ★ (recommended with Muse): a settlement, mountain, river, temple or monastery is a real
name and is transliterated, the generic word translated, as Russian writes Chinese places (Пекин,
Хуашань, Шаолинь): городок Сюэтин (雪亭镇), городок Циюнь (绮云镇), уезд Цяоинь (乔阴), Ланьчэн (岚城),
храм Шаньянь (山烟寺), трактир «Иньфэн» (饮风客栈: the description says once what the name means).
A place named by plain description, in the wild or a room, is translated: Хребет Старых сосен
(老松岭), Бамбуковая тропа (竹林道), Желтокаменный перевал (黄石隘口), Заброшенный сад (废园). The
glossary marks every place T (transliterated) or П (translated); one place has one name on the
map, in a quest and in speech. The generic words:
镇 городок, 县 уезд, 村 деревня, 城 город, 山 гора, 寺 монастырь, 庙 храм, 观 даосский монастырь,
客栈 постоялый двор / трактир, 镖局 охранная контора, 府 усадьба / управа.

**Schools:** 派 школа (封山剑派 школа меча Фэншань) · 武馆 школа боевых искусств · 教 учение (never
орден) · 帮 / 会 братство (союз, общество for a loose one; шайка for a gang). **секта** only in the
mouth of those who condemn them (it is harsher in Russian than English's sect).

**Moves** are translated as images, a noun phrase of at most four to six words: 饿鬼拦路 «Голодный
дух на пути», not a whole sentence.

**Items, beasts, generic people** are Russian words (野狗 бродячая собака, 牛皮酒袋 кожаный бурдюк,
山贼 разбойник, 店小二 трактирный слуга, then слуга; never половой); books and manuals in «».

## Terms

цзянху (the codex explains it once: «вольный мир рек и озёр») · улинь (codex: мир боевых искусств) ·
ушу · ци · даньтянь · Шифу.
精 气 神 Цзин · Ци · Шэнь (one triad, all transliterated; the codex explains them) · 内力 внутренняя
сила (Сила where the context is clear) · 内功 внутреннее искусство · 轻功 искусство лёгкого шага (a
move: Лёгкий шаг) · 潜能 Потенциал · 加力 Усиление (the button Усилить) · 杀气 Жажда убийства ·
法力 Чародейская сила · 灵力 Духовная энергия · 定力 Сосредоточенность · 实战经验 Боевой опыт ·
经脉 меридианы · 穴道 акупунктурные точки (Точки beside меридианы) · 心法 внутренний метод ·
秘籍 тайное руководство (an item: Тайный свиток) · 手 (a fight's turn) ход · 文 вэнь (never
declined) · 两 лян · 里 ли (the codex: китайская миля) · 丈 чжан · 尺 чи (never сажень, аршин) ·
寸 вершок (close in size and idiomatic: на вершок, вершок за вершком) · 时辰 двойной час · 子时 полночь ·
掌门 глава школы · 长老 старейшина.
No HP or MP; the HUD writes Цзин / Ци / Шэнь / Потенц. / Ур.; an icon and the number rather than
a shorter cut.

## Grammar marks

Russian changes a name with its role in the sentence and agrees verbs with its gender; a template
does not know the name its slot will hold. The game finishes a filled line (`RussianText`):

* **case**, right after a slot or token: `{npc}{:вин}` — `{:им} {:род} {:дат} {:вин} {:твор}
  {:пред}`. «Вы отдаёте {item}{:вин} {npc}{:дат}.» → «Вы отдаёте старую саблю бандиту.»; the
  player (вы) becomes вас, вам, вами. The whole phrase changes (an adjective with its noun), and
  the accusative is the right one for a person or a thing (бандита, меч). After written text the
  translator writes the case.
* **capitals**: every name in ru.po opens with a capital (a label, a button, a list shows it so:
  «Трактирный слуга», «Кожаный бурдюк»); a common noun goes lower case when the game fills it into
  a sentence after a case mark («Вы зовёте трактирного слугу»). So a name slot that does not open a
  sentence always carries a mark, `{:им}` for the nominative: «Здесь стоит {npc}{:им}.» The noun
  table keeps a common noun under its lower-case key; a Chinese name, a place and a title keep the
  capital everywhere.
* **gender**, `{~:ушли|ушёл|ушла|ушло}` — agrees with the nearest case-marked name before it (else
  after it), always in this order: **мн (вы, a plural) | м | ж | ср**; three forms when ср
  cannot occur. A person is the person's gender (a староста who is a woman: ж), a beast or a thing
  the word's (собака: ж, whatever the dog).
* **$N and $n** (ES2's actor and target, always one character): `{N:бьёте|бьёт}` — the player,
  then anyone else; a past tense or short adjective takes `{N:ударили|ударил|ударила|ударило}`
  in the same order. `{n:…}` for $n. Never $P/$p: write the forms (`{n:вас|его|её}`).
* `{N:…}` follows $N, `{n:…}` $n, `{~:…}` the nearest case-marked slot ({npc}{:им}): three
  marks for three kinds of subject, one order for all of them. **The first of three or four forms
  is always the plural** (ушли, ударили, рады, должны): check_po fails a first form that does not
  end in -и or -ы, which catches a form order mixed up.
* **the player's gender**, `{игрок:пришёл|пришла}` (м | ж): for a past tense or short adjective
  of the player spoken to as ты, or speaking as я («Ты {игрок:выбрал|выбрала}.»). The narration's
  вы and a speaker's вы take the plural and need none.
* **numbers**: `%d {#:день|дня|дней}` agrees with the number before it (1 | 2–4 | 5+, 11–14 take
  the third); the translator writes the forms the sentence's case asks for («на 2 дня», «через 5
  дней»). `{count} {item}{:счёт}` counts a filled name (2 кожаных бурдюка). **{:счёт} is not a case**: it
  picks the counted form by the number, for the nominative and an inanimate accusative only
  («У вас 2 кожаных бурдюка», «Вы берёте 3 меча»). A list, a reward or an inventory line writes
  the name in the nominative and the number after it: «{item} × {count}», «{item}: {count}». A
  sentence that would put a counted filled name in another case, or count a person in the
  accusative, is rewritten so that it does not (a translator never leaves «с кожаные бурдюки: 2»).
* **Avoid the marks where Russian can.** Fights and NPC actions are in the present tense, which has
  no gender: «$N {N:бьёте|бьёт} $n{:вин}». An NPC's action line follows its name (`{npc}{action}`):
  write it in the present, opening with a space (« кивает.»). Rewrite rather than stack marks.

## Numbers

Numbers the Chinese writes in characters come out in digits (`ChineseNumber.of`): «{count} вэнь»,
«{generation}-е поколение». A count with no fitting form is written as a label: «Осталось ходов: %d».

## Typography

* Quotes «…». The inner quotes are ASCII straight quotes "…", standing in for „“ because the
  pixel face has “ ” only as two-letter-wide Chinese glyphs: a face that draws them narrow brings
  „“ back everywhere. Dialogue is quoted, not dashed: «Лю Чуньфэн говорит: «…»» — one line is one
  speaker.
* A quotation's full stop goes after the closing quote («Иди».), and a comma before a dash after
  it («Иди», — сказал он); a quotation ending in ? ! or ... keeps its own mark («Кто там?»)
  (Мильчин, Справочник издателя и автора). `RussianText` does this on every shown line, since a
  said line is often filled into «{line}» with its own stop.
* The dash is an em dash with spaces ( — ), never a hyphen; a range takes an en dash (2–4).
* An ellipsis is three dots `...` (the face's … is full width), whatever the Chinese has.
* ё is written where it is said (ещё, её, ушёл).
* Buttons ≤ about 20 letters, tabs ≤ 14: choose a shorter word (Вещи for Инвентарь), never cut one
  (no «Сохр.»); Ур. is the one standard short form. A button may take two lines.

## In-jokes ★

Localized, not translated, as in English: 华工 → Бауманка (МВТУ им. Баумана: an engineering school
everyone knows, the joke's function, not the most famous university) · 八舍 → общага ·
the canteen card → «пропуск в столовую Бауманки» · 魏阮 (微软) → Майк Мягков · «把 NT 也汉化，看你之星
怎么办» → Word pushing Лексикон out: «Русифицируй и NT — и Лексикону конец» · 黑你没商量 → «Без
торга». Items, trigger phrases, buttons and names the game checks stay as they are.

## Checking a batch

`check_po.py` (slots, marks, punctuation) and a read of ten lines against the Chinese: two each of
names, fights, speech, descriptions and UI; two problems or more, read thirty. Every new name goes
into the glossary and `ru_nouns.json` before merging.

## The title

The title screen shows the language's own brushed title and an English line under it (the rule
for every language with its own title; only English has 东方故事 under it). Russian's is the
game's name, Восточные / истории in two lines like the English title, in Mister Brush (a rough
dry-brush capital hand; the owner picked it from three samples, 2026-11-27), with the 侠 seal:
`logo_ru.png`.

## Decided by the owner (2026-11-26)

* Places: the compromise — a real name transliterated with a translated generic word, a place
  named by plain description translated; every place marked T or П in the glossary.
* In-jokes localized as listed (Бауманка, Майк Мягков, Word and Лексикон, «Без торга»).
* The narration calls the player lower-case вы.
