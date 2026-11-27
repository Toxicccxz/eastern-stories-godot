# Español (Latinoamérica): style, names and the grammar marks

The Spanish translation is `game/locale/es_419.po` (Settings → Idioma → Español (Latinoamérica)
(vista previa)). Worked out with Muse, 2026-11-27; ★ marks a choice the owner decides.
DECISIONS「Español (preview)」. Check a translation with
`python tools/l10n/check_po.py game/locale/es_419.po` (the gate runs it too); batches go in with
`tools/l10n/po_batch.py` ([LOCALIZATION](LOCALIZATION.md#working-on-a-translation)).

One Spanish for Latin America and Spain: Latin American words first, nothing only one side reads.
Spanish has a little wuxia canon: Salamandra's Jin Yong (Leyendas de los héroes cóndor, 2021, done
from Anna Holmwood's English) for the form of names and epithets, and the Spanish web-novel
translators' words where they agree (jianghu, Qi, neigong, qinggong, Shifu). The English text is
the model for names and places; translate from the Chinese.

## Tone

**Neutral Latin American, old but not archaic.** The narration of a historical novel: short, hard
sentences, never the period-drama voice (vuestra merced, vos, os, habéis, mas como pero) and never
modern talk.

* **ustedes** for every plural you, with its third-person verbs; never vosotros, vuestro, os.
  No voseo.
* **Never** (a word that is rude on one side or only one side's slang): coger (write tomar, agarrar,
  recoger), concha (caracola, caparazón), pendejo, chingar, vale, guay, mola, flipar, chido, güey,
  che, boludo, tío as a filler, okey, bro, onda, genial as a catch-phrase, chévere, padre (= great).
* ES2's own text stays a touch formal; the new story text is short, hard and leaves things unsaid:
  the same number of sentences as the Chinese (sentences, not words: Spanish runs 20–30 % longer),
  no added «porque» or «y entonces», no explaining what the Chinese leaves out.

| Text | Voice | Example |
|---|---|---|
| a room, a place | present, noun sentences welcome | Huele a ajenjo. Sobre la mesa, una tetera. |
| a fight, an action now, an NPC's action line | present | Golpeas al bandido. El bandido retrocede. |
| a result, the opening, a memory, a quest's record, the journal | past (pretérito) | ¡La herida se abrió! |
| the codex | present, a definition | El jianghu es el mundo marcial… |
| buttons, menus | infinitive or noun, sentence case | Guardar partida, Cargar, Ajustes |
| tutorial, hints, system lines | tú, the imperative | Pulsa E para hablar. |
| quest objectives | infinitive | Preguntar al mozo. |

One Chinese passage in three voices (Muse's sample):

* narration — 你推开客栈的木门，一股酒气扑面而来。 Empujas la puerta de madera de la posada y el olor
  a vino te da en la cara. (tú's verb, no tú, present, one sentence);
* the waiter to a guest, usted — 客官里面请！要住店还是打尖？ ¡Pase, señor! ¿Busca habitación o solo
  viene a comer?;
* a bandit to the player, tú — 小子，把银子交出来，饶你不死！ ¡Muchacho, suelta la plata y te dejo
  vivir! (short, hard, no courtesy word; plata is silver and money in Latin America).

## The player

Narration and the system call the player **tú** and leave the tú out, as Spanish does: «Ves a un
mozo de la posada.» «Golpeas al bandido.» (an explicit Tú only for a contrast: «Tú golpeas al
bandido; él te golpea a ti.»). An adjective or participle of the player agrees with the player's gender: **rewrite
first** (Sientes cansancio, Te cuesta respirar; an adjective in -e or -l has one form: fuerte,
débil, inconsciente); when a rewrite loses a state or the tone, use the mark
`{jugador:cansado|cansada}`, whole words (`{jugador:un discípulo|una discípula}`). Someone who
speaks to the player as usted still agrees with the player's gender.

## tú and usted

Higher to lower tú, lower to higher usted; equals by closeness. Keep one form per pair of people
(a relation list beside the glossary), never switching line by line.

| Who, to whom | Form |
|---|---|
| master → disciple · elder → junior | tú |
| disciple → master (Shifu) · junior → elder | usted |
| senior brother/sister → junior | tú |
| junior → senior brother/sister | usted; tú once close (a story moment) |
| peers of a school | usted on meeting, tú once close |
| innkeeper, waiter, servant → guest | usted |
| guest → innkeeper or waiter | usted on meeting; a regular, a bandit or a spoiled young master: tú |
| bandits ↔ anyone | tú |
| an official → commoners · commoners → an official | tú · usted (+ señor) |
| a monk or Daoist → laymen | usted; an old one teaching may say tú |

Address: 客官 señor / señora (by the guest's gender; in narration el huésped / la huésped) ·
施主 benefactor / benefactora (the monks' fixed address; never donante, a blood donor) · 贫道 «este humilde taoísta» · 老衲 «este viejo monje» · 在下 yo (este servidor when
formal, never every sentence) · 师父 Shifu (address, before a name: Shifu Liu; a woman too);
maestro, lower case, only for any teacher · 掌门 Maestro (a title: el Maestro Liu); in full
Maestro de la escuela ★ · 大侠 gran caballero · 少侠 joven caballero · 侠客 caballero errante ·
侠义 código de caballería · 姑娘 señorita (address and narration) · 师兄 / 师姐 hermano mayor /
hermana mayor (de escuela, the first time in the UI or codex) · 师弟 / 师妹 hermano menor / hermana
menor · 师伯 / 师叔 tío mayor / tío menor de escuela · 师侄 sobrino de escuela · 长老 Anciano (a
title; anciano, lower case, an old man).

## Names

One picture, one plain word, as in English: maps, quests and the UI use the Spanish name.

* **People**: pinyin, surname first, no tones (Liu Chunfeng) — the English text's pinyin; an
  epithet is translated and follows a comma (Liu Chunfeng, el Espadachín del Viento y la Lluvia).
  A Buddhist or Daoist name is one word (Liaochen, Xuanzhi); a title before it is translated
  (玄智和尚 el monje Xuanzhi).
* **Places**: as English: a place named for what one sees is translated, a real proper name keeps
  its pinyin; at most three words on the map, de/del left out where Spanish can (Pabellón
  Nevado (雪亭镇: Nevado as in Sierra Nevada; the first mention in a text el pueblo de Pabellón
  Nevado), Sombra Alta (乔阴), la Capital (京师)). A place named for its look takes the article in a
  sentence when Spanish gives it one (el Paso del Camello). A room is a plain word (habitación de
  huéspedes, plaza).
* **Schools**: 派 / 门 Escuela (封山剑派 Escuela de la Montaña Vacía) · 教 Orden (东方神教 la Orden
  del Cuervo Dorado: dorado, golden, not de oro) · 帮 / 会 Hermandad (never Gremio, a trade guild;
  Cofradía for a religious one; 花紫会 la Hermandad de los Mendigos) · 宫 Palacio · 庄 Mansión ·
  武馆 Escuela or Salón (淳风武馆 Salón del Viento Puro). **secta** only in the mouth of those who
  condemn them.
* **Moves** are images, at most six words, a noun phrase unless the Chinese is a verb sentence
  (饿鬼拦路 Fantasma hambriento cierra el paso).
* **Items, beasts, generic people** are Spanish words (野狗 perro salvaje, 牛皮酒袋 odre de cuero,
  山贼 bandido, 掌柜 posadero, 店小二 mozo de la posada, Mozo where short); books in «».

## Terms

精 Esencia · 气 Qi · 神 Espíritu (never Alma) · 内力 Fuerza interior (the resource) · 内功 neigong (the
art) · 轻功 qinggong · 潜能 Potencial · 加力 Fuerza extra · 杀气 Sed de sangre · 法力 Poder arcano ·
灵力 Poder místico · 定力 Temple · 实战经验 Experiencia de combate · 经脉 meridianos · 穴道 puntos de
acupuntura · 心法 método interno · 秘籍 manual secreto · 手 (a fight's turn) turno · 江湖 jianghu
(the codex: el mundo marcial) · 武林 wulin · 两 tael, taels · 文 wen (never plural) · 里 li · 丈 zhang ·
时辰: in the text the Spanish time (子时 medianoche, 午时 mediodía, 卯时 al amanecer, 酉时 al atardecer);
hora doble only in the codex. No HP or MP: the HUD writes Esencia / Qi / Espíritu / Pot. / Niv.

**Never let two terms collide:** 内力 ≠ 内功, 师父 ≠ 掌门, 大侠 ≠ 英雄 (héroe).

## Grammar

* Latin American object pronouns: lo / la for the direct object, le for the indirect, se lo / se la
  when both (Se la das, never Le la das); no leísmo.
* su is ambiguous (his, her, their, your): where it could mislead, write the name or tu.
* The personal a: a person as the direct object takes a (Ves a un hombre); a beast in a fight is
  an opponent and takes it too (Golpeas al perro salvaje), as does a beast one knows (Alimentas al
  caballo); game hunted in general does not (Cazas jabalíes); a thing never (Empuñas la espada).
* A feminine noun with a stressed a takes el in the singular (el hacha, el águila herida, las
  hachas): its row in the noun table says so.

## Grammar marks

Spanish puts an article before a common noun and agrees with its gender and number; a template does
not know the name its slot will hold. The game finishes a filled line (`SpanishText`, from the noun
table `game/locale/es_nouns.json`):

* **article**, right after a slot or token: `{npc}{:el}` the definite article (el mozo de la
  posada, la espada vieja, los guantes; a proper name takes none: Liu Chunfeng), `{:un}` the
  indefinite (un mozo, una espada, un hacha), `{:los}` and `{:unos}` the name in its plural with
  the plural article (las espadas viejas, unos mozos), `{:0}` — zero, no article — the common noun
  in lower case («Soy {npc}{:0}»). a + el
  and de + el contract by themselves: «Hablas con {npc}{:el}» → «Hablas con el mozo», «Te acercas a
  {npc}{:el}» → «Te acercas al mozo». An article after written text is written by the translator.
* **capitals**: every name in es_419.po opens with a capital (a label, a button, a list shows it so:
  «Mozo de la posada», «Odre de cuero»); a common noun goes lower case when the game fills it into
  a sentence after a mark. So a name slot that does not open a sentence always carries a mark.
* **gender**, `{~:herido|herida}` — agrees with the nearest marked name before it (else after it),
  **whole words** (hablador|habladora; never a suffix: fuerte has one form), m | f; four forms
  `{~:herido|herida|heridos|heridas}` (m | f | mp | fp) when a plural can occur ({:los}, {:pl}).
  A slot the game may fill with the player (a site that writes 你 into {who} or {name}) takes
  three forms, tú | m | f: «{who}{:el} {~:sientes|siente|siente} frío»; two or four forms after
  tú follow the player's gender. A person is the person's
  gender (a woman who is the head of a village: f), a beast or a thing the word's (la serpiente).
* **$N and $n** (ES2's actor and target, always one character): `{N:golpeas|golpea}` — the player
  (tú), then anyone else; three forms for an object pronoun `{n:te|lo|la}` (the player, m, f).
  Their names take the article mark like a slot: `$N{:el} {N:golpeas|golpea} a $n{:el}`. The player
  as a subject is left out («Golpeas al bandido»); as an object write the clitic in the forms:
  `$N{:el} {n:te golpea|golpea a $n{:el}}`. Never $P/$p: write `{N:tu|su}`, and the name where su
  would mislead.
* **the player's gender**, `{jugador:cansado|cansada}` (m | f), whole words.
* **numbers**: `%d {#:día|días}` agrees with the number before it (1 | any other). `{count}
  {item}{:pl}` counts a filled name (3 espadas viejas). A list, a reward or an inventory line writes
  the name and the number after it: «{item} × {count}».
* **Avoid the marks where Spanish can.** Rewrite rather than stack marks.

## Numbers

Numbers the Chinese writes in characters come out in digits (`ChineseNumber.of`): «{count} wen»,
«{generation}.ª generación». A count with no fitting form is written as a label: «Turnos: %d».

## Typography

* Straight quotes "…" (the pixel face draws “ ” and … full width), single '…' inside. Dialogue is
  quoted, not dashed: «El mozo dice: "¡Pase!"» — one line is one speaker. The full stop stays
  **inside** the closing quote (El mozo dice: "Pase."): a game convention, against the RAE on
  purpose, because a said line is filled into "{line}" with its own stop; a review does not move it.
* ¿…? and ¡…! always paired; the opening mark is never left out.
* An ellipsis is three dots `...`, whatever the Chinese has.
* Buttons ≤ about 18 letters, tabs ≤ 12: choose a shorter word, never cut one (no «Guard.»);
  Niv. and Pot. are the standard short forms. UI labels in sentence case (Guardar partida).

## In-jokes ★

Localized, not translated, so both sides of the ocean read them: Microsoft, Windows NT and Netscape
stay (the 1990s joke works everywhere; 魏阮 = 微软 becomes Mike Rosoft as in English) · 华工 →
la Politécnica (an engineering school every country has) · 八舍 → la residencia ocho.
Items, trigger phrases, buttons and names the game checks stay as they are.

## Checking a batch

`check_po.py` (slots, marks, punctuation, the never list) and a read of ten lines against the
Chinese: two each of names, fights, speech, descriptions and UI; two problems or more, read thirty.
Every new name goes into the glossary and `es_nouns.json` before merging.

## The title ★

Historias de Oriente («Historias», plural like Stories; «Oriente», the cultural East, not the
compass's Este).
