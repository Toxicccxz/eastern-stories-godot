# Português (Brasil): style, names and the grammar marks

The Brazilian Portuguese translation is `game/locale/pt_BR.po` (Settings → Idioma → Português
(Brasil) (prévia)). Worked out with Muse, 2026-11-27; ★ marks a choice the owner decides.
DECISIONS「Português (preview)」. Check a translation with
`python tools/l10n/check_po.py game/locale/pt_BR.po` (the gate runs it too); batches go in with
`tools/l10n/po_batch.py` ([LOCALIZATION](LOCALIZATION.md#working-on-a-translation)).

Brazilian Portuguese, readable in Portugal: Brazil's words, grammar and spelling (the 1990
agreement), never Portugal's own. Brazil reads wuxia through web-novel translations and fansubs
(jianghu, Qi, neigong, qinggong, Shifu, seita in the enemies' mouths) and through Kung Fu Panda
(Shifu). The English text is the model for names and places; translate from the Chinese.

## Tone

**Brazilian, old but not archaic.** The narration of a historical novel: short, hard sentences;
never the period-drama voice (vós, vosso, tendes, mesóclise as in dar-te-ei) and never today's
talk.

* **vocês** for every plural you, with its third-person verbs; never vós.
* **Never** (rude in Brazil, Portugal's only, or slang that dates): rapariga (moça), puto/puta,
  bicha (fila is a queue), fixe, bué, miúdo (garoto, menino), autocarro, comboio, pequeno-almoço
  (café da manhã), okay, parça, véi, tipo assim. Portugal's gerund «estar a fazer» → «estar
  fazendo».
* ES2's own text stays a touch formal; the new story text is short, hard and leaves things unsaid:
  the same number of sentences as the Chinese (Portuguese runs 20–30 % longer than English), no
  added «porque» or «e então», no explaining what the Chinese leaves out.

| Text | Voice | Example |
|---|---|---|
| a room, a place | present, noun sentences welcome | Cheira a absinto. Sobre a mesa, um bule. |
| a fight, an action now, an NPC's action line | present | Você golpeia o bandido. O bandido recua. |
| a result, the opening, a memory, a quest's record, the journal | past (pretérito perfeito) | A ferida se abriu! |
| the codex | present, a definition | O jianghu é o mundo marcial… |
| buttons, menus | infinitive or noun, sentence case | Salvar jogo, Carregar, Configurações |
| tutorial, hints, system lines | você, the imperative | Pressione E para falar. |
| quest objectives | infinitive | Perguntar ao garçom. |

## The player

Narration and the system call the player **você**, with the third person's verb: «Você vê um
garçom.» «Você golpeia o bandido.» Two sentences in a row about the player may leave the second
você out, as Brazilian prose does («Você empurra a porta. Entra.»). An adjective or participle of
the player agrees with the player's gender: **rewrite first** (Você sente cansaço; an adjective in
-e or -l has one form: forte, fraco/fraca does not); when a rewrite loses a state or the tone, use
`{jogador:cansado|cansada}`, whole words.

The player as an object: **te** before the verb, as Brazil speaks and writes it in games and
novels («O bandido te golpeia.», «Ele te olha.»); «você» after a preposition (para você, com
você). The possessive is **seu / sua** (your), never teu, and «dele / dela» where seu would read
as the player's. ★

## você, o senhor and tu

| Who, to whom | Form |
|---|---|
| master → disciple · elder → junior | você |
| disciple → master (Shifu) · junior → elder | o senhor / a senhora |
| senior brother/sister → junior | você |
| junior → senior brother/sister | o senhor / a senhora; você once close (a story moment) |
| peers of a school | você |
| innkeeper, waiter, servant → guest | o senhor / a senhora |
| shopkeeper, merchant, craftsman → a customer | o senhor / a senhora (a herder, a peon: você) |
| guest → innkeeper or waiter | você |
| bandits ↔ anyone | você, the words rough |
| an official → commoners · commoners → an official | você · Vossa Excelência / o senhor |
| a monk or Daoist → laymen | o senhor / a senhora; an old one teaching: você |

tu is not used (its verbs mark one region of Brazil). Keep one form per pair of people.

Address: 客官 senhor / senhora (by the guest's gender; in narration o hóspede / a hóspede) ·
施主 benfeitor / benfeitora (the monks' address) · 贫道 «este humilde taoista» · 老衲 «este velho
monge» · 在下 eu (este seu criado when formal, never every sentence) · 师父 Shifu (address, before a
name: Shifu Liu; a woman too); mestre, lower case, any teacher · 掌门 Mestre (a title: o Mestre Liu)
★ · 大侠 grande cavaleiro · 少侠 jovem cavaleiro · 侠客 cavaleiro errante · 侠义 código de cavalaria ·
姑娘 moça (narration) / senhorita (address) · 师兄 / 师姐 irmão mais velho / irmã mais velha (de
escola, the first time in the UI or codex) · 师弟 / 师妹 irmão mais novo / irmã mais nova · 师伯 /
师叔 tio mais velho / tio mais novo de escola · 长老 Ancião (a title; ancião, lower case, an old
man).

## Names

One picture, one plain word, as in English: maps, quests and the UI use the Portuguese name.

* **People**: pinyin, surname first, no tones (Liu Chunfeng) — the English text's pinyin; an
  epithet is translated and follows a comma. A Buddhist or Daoist name is one word (Liaochen).
* **Places**: as English: a place named for what one sees is translated, a real proper name keeps
  its pinyin; at most three words on the map (Pavilhão da Neve (雪亭镇), Sombra Alta (乔阴), a
  Capital (京师)). A place takes the article in a sentence when Portuguese gives it one (a Capital,
  o Passo do Camelo): its row says so, and the mark contracts it (na Capital, do Passo do Camelo).
* **Schools**: 派 / 门 Escola · 教 Ordem (东方神教 a Ordem do Corvo Dourado) · 帮 / 会 Irmandade
  (never Guilda, a trade guild; 花紫会 a Irmandade dos Mendigos) · 宫 Palácio · 庄 Solar · 武馆
  Academia or Salão. **seita** only in the mouth of those who condemn them.
* **Moves** are images, at most six words, a noun phrase unless the Chinese is a verb sentence.
* **Items, beasts, generic people** are Portuguese words (野狗 cão selvagem, 牛皮酒袋 odre de couro,
  山贼 bandido, 掌柜 estalajadeiro, 店小二 garçom da estalagem ★); books in «».

## Terms

精 Essência · 气 Qi · 神 Espírito (never Alma) · 内力 Força interior (the resource) · 内功 neigong
(the art) · 轻功 qinggong · 潜能 Potencial · 加力 Força extra · 杀气 Sede de sangue · 法力 Poder arcano
· 灵力 Poder místico · 定力 Serenidade · 实战经验 Experiência de combate · 经脉 meridianos · 穴道
pontos de acupuntura · 心法 método interno · 秘籍 manual secreto · 手 (a fight's turn) turno · 江湖
jianghu · 武林 wulin · 两 tael, taéis · 文 wen · 里 li · 丈 zhang · 时辰: in the text the
Portuguese time (子时 meia-noite, 午时 meio-dia); hora dupla only in the codex. No HP or MP: the HUD
writes Essência / Qi / Espírito / Pot. / Nív. Qi is capitalised in every sentence.

**Never let two terms collide:** 内力 ≠ 内功, 师父 ≠ 掌门, 大侠 ≠ 英雄 (herói).

## Grammar

* Brazilian clitics: before the verb (O bandido te olha; Ele se levanta), never mesóclise; a
  sentence may open with one (Me dê a espada.) in speech; narration opens with the subject.
* seu is ambiguous (his, her, their, your): where it could mislead, write dele / dela or the name.
* Contractions are always written: do, da, no, na, ao, à, pelo, pela (the marks do it after a
  slot; after written text the translator writes them).

## Grammar marks

Portuguese puts an article before a common noun and agrees with its gender and number, and the
article joins the preposition before it; a template does not know the name its slot will hold. The
game finishes a filled line (`PortugueseText`, the shared `RomanceText` with Portuguese's words,
from the noun table `game/locale/pt_BR_nouns.json`):

* **article**, right after a slot or token: `{npc}{:o}` the definite article (o garçom, a espada
  velha, as tesouras; a proper name takes none: Liu Chunfeng), `{:um}` the indefinite (um garçom,
  uma espada), `{:os}` and `{:uns}` the name in its plural with the plural article (as espadas
  velhas, uns garçons), `{:0}` — no article — the common noun in lower case («Sou {npc}{:0}»). The
  preposition before the slot contracts by itself: «Você fala de {npc}{:o}» → «do garçom», «em
  {npc}{:o}» → «no garçom», «a {npc}{:o}» → «ao garçom» / «à Capital», «por {npc}{:o}» → «pelo
  garçom». An article after written text is written by the translator.
* **capitals**: every name in pt_BR.po opens with a capital («Garçom da estalagem», «Odre de
  couro»); a common noun goes lower case when the game fills it into a sentence after a mark. So a
  name slot that does not open a sentence always carries a mark.
* **gender**, `{~:ferido|ferida}` — agrees with the nearest marked name before it (else after it),
  **whole words**, m | f; four forms `{~:ferido|ferida|feridos|feridas}` when a plural can occur.
  A slot the game may fill with the player (a site that writes 你 into {who} or {name}) needs
  nothing for its verb (você takes the third person); an adjective after it follows the player's
  gender. Three forms `{~:você form|m|f}` exist for the rare line that needs one.
* **$N and $n** (ES2's actor and target): the verb is the same for você and anyone else, so
  `$N{:o} golpeia $n{:o}` needs no form; the player as $n is te: `$N{:o} {n:te golpeia|golpeia
  $n{:o}}`; three forms for a pronoun `{n:te|o|a}` (the player, m, f). Never $P/$p: write
  `{N:seu|seu}` forms or the name.
* **the player's gender**, `{jogador:cansado|cansada}` (m | f), whole words.
* **numbers**: `%d {#:dia|dias}` agrees with the number before it (1 | any other; 0 takes the
  plural). `{count} {item}{:pl}` counts a filled name (3 espadas velhas). A list, a reward or an
  inventory line writes «{item} × {count}».
* **Avoid the marks where Portuguese can.** Rewrite rather than stack marks.

## Numbers

Numbers the Chinese writes in characters come out in digits: «{count} wen», «{generation}.ª
geração». A count with no fitting form is written as a label: «Turnos: %d».

## Typography

* Straight quotes "…" (the pixel face draws “ ” and … full width), single '…' inside; dialogue is
  quoted, not dashed (one line is one speaker): «O garçom diz: "Entre!"». The full stop stays
  inside the closing quote, a game convention: a said line is filled into "{line}" with its own
  stop.
* No ¿ or ¡.
* An ellipsis is three dots `...`.
* Buttons ≤ about 18 letters, tabs ≤ 12: choose a shorter word, never cut one; Nív. and Pot. are
  the short forms. UI labels in sentence case (Salvar jogo).

## In-jokes ★

Localized, not translated: Microsoft, Windows NT and Netscape stay (魏阮 = 微软 becomes Mike Rosoft
as in English) · 华工 → a Poli (the engineering school every Brazilian knows) · 八舍 → o bloco
oito. Items, trigger phrases, buttons and names the game checks stay as they are.

## Checking a batch

`check_po.py` (slots, marks, punctuation, the never list) and a read of ten lines against the
Chinese: two each of names, fights, speech, descriptions and UI; two problems or more, read thirty.
Every new name goes into the glossary and `pt_BR_nouns.json` before merging.

## The title ★

Histórias do Oriente.
