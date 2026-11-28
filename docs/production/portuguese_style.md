# Português (Brasil): style, names and the grammar marks

The Brazilian Portuguese translation is `game/locale/pt_BR.po` (Settings → Idioma → Português
(Brasil) (versão prévia)). Worked out with Muse, 2026-11-27; ★ marks a choice the owner decides.
DECISIONS「Português (preview)」. Check a translation with
`python tools/l10n/check_po.py game/locale/pt_BR.po` (the gate runs it too); batches go in with
`tools/l10n/po_batch.py` ([LOCALIZATION](LOCALIZATION.md#working-on-a-translation)).

Brazilian Portuguese, readable in Portugal: Brazil's words, grammar and spelling, never Portugal's
own. Spelling follows the 1990 agreement (ação, not acção; fato, not facto; elétrico, ótimo).
Brazil reads wuxia through web-novel translations and fansubs (jianghu, Qi, neigong, qinggong,
Shifu, jovem mestre) and through Kung Fu Panda (Shifu). The English text is the model for names and
places; translate from the Chinese.

## Tone

**Brazilian, old but not archaic.** The narration of a historical novel: short, hard sentences.
The period comes from the words (Shifu, benfeitor, este humilde taoísta), not from the pronouns:
never the period-drama voice of Portugal (vós, vosso, tendes, mesóclise as in dar-te-ei) and never
today's talk.

* **vocês** for every plural you, with its third-person verbs; never vós.
* **Never anywhere** (the checker refuses them): Portugal's words — rapariga (moça), miúdo (garoto,
  menino), gajo (sujeito), fixe, bué, autocarro, comboio, pequeno-almoço (café da manhã), telemóvel,
  frigorífico, casa de banho, facto, eléctrico, óptimo, factura; slurs and coarse words a translator
  would add — puto/puta, bicha, viado, porra, caralho, cacete (a curse in the Chinese is droga,
  maldição, inferno); chat spelling — vc, cê; okay, parça, véi, tipo assim; gringo (estrangeiro,
  forasteiro).
* **Not in narration, the codex or the tutorial** (a speaker may, sparingly: a bandit, a child):
  mano, bacana, maneiro, da hora, legal and show as «cool», uai, oxe, trem as «thing», cara as an
  address, tá, tô, né, pra, a gente (write nós). Portugal's gerund «estar a fazer» → «estar
  fazendo».
* **False friends**: apelido is a nickname (a surname is sobrenome), embaraçada is embarrassed,
  esquisito is odd (refined is refinado), tipo only as «kind».
* ES2's own text stays a touch formal; the new story text is short, hard and leaves things unsaid:
  the same number of sentences as the Chinese (Portuguese runs 20–30 % longer than English), no
  added «porque» or «e então», no explaining what the Chinese leaves out.

| Text | Voice | Example |
|---|---|---|
| a room, a place | present, noun sentences welcome | Cheira a artemísia. Sobre a mesa, um bule. |
| a fight, an action now, an NPC's action line | present | Você golpeia o bandido. O bandido recua. |
| a result, the opening, a memory, a quest's record, the journal | past (pretérito perfeito) | A ferida se abriu! |
| the codex | present, a definition | O jianghu é o mundo marcial... |
| buttons, menus | infinitive or noun, sentence case | Salvar jogo, Carregar jogo, Opções |
| tutorial, hints, system lines | você, the imperative | Pressione E para falar. |
| quest objectives | infinitive | Perguntar ao moço. |

## The player

Narration and the system call the player **você**, with the third person's verb: «Você vê um moço
da estalagem.» «Você golpeia o bandido.» A second sentence in a row about the player may leave
você out, as Brazilian prose does («Você empurra a porta. Entra.»), but never when the person
changes, in a fight log (where $N changes fast) or where the verb could be someone else's. você
and o senhor take no capital inside a sentence.

The player as an object: **te** before the verb, as Brazil speaks and writes it in games and novels
(«O bandido te golpeia.», «Ele te olha.»); never o/a or lhe for the player as a direct object (they
read as Portugal's written style), lhe only as a formal indirect object. After a preposition always
**você** (para você, com você, de você), never para te, com te. The possessive is **seu / sua**
(agreeing with the thing owned), never teu; where seu could be someone else's, write dele / dela or
de + the name (a espada de Liu).

An adjective or participle of the player agrees with the player's gender: **rewrite first** (Você
sente cansaço); adjectives in -e (forte, triste) and in -l, -r, -z (cruel, melhor, feliz) have one
form, those in -o change to -a (cansado / cansada, fraco / fraca); when a rewrite loses a state or
the tone, use `{jogador:cansado|cansada}`, whole words.

## você, o senhor and tu

| Who, to whom | Form |
|---|---|
| master → disciple · elder → junior | você |
| disciple → master · junior → elder | o senhor / a senhora (called Shifu: «Shifu, o senhor viu...?») |
| senior brother/sister → junior | você |
| junior → senior brother/sister | o senhor / a senhora; você once close (a story moment) |
| peers of a school | você |
| innkeeper, waiter, servant → guest | o senhor / a senhora |
| shopkeeper, merchant, craftsman → a customer | o senhor / a senhora (a herder, a peon: você) |
| guest → innkeeper or waiter | você |
| bandits ↔ anyone | você, the words rough |
| an official → commoners · commoners → an official | você · Vossa Excelência / o senhor |
| a monk or Daoist → laymen | o senhor / a senhora; an old one teaching: você |

tu is not used (its verbs mark one region of Brazil); vós never. Keep one form per pair of people.

Address: 客官 senhor / senhora (by the guest's gender; in narration o hóspede / a hóspede; freguês
only when a shopkeeper haggles) · 施主 benfeitor / benfeitora (the monks' address) · 贫道 «este
humilde taoísta» · 老衲 «este velho monge» · 在下 eu (este seu criado when formal, never every
sentence) · 师父 Shifu (address, before a name: Shifu Liu; a woman too) · 掌门 Mestre (capital,
alone, only the head of a school: o Mestre Liu) · a craftsman's master is mestre + the trade
(mestre ferreiro), never mestre alone; a teacher in general instrutor · 大侠 grande cavaleiro ·
少侠 jovem cavaleiro · 侠客 cavaleiro errante · 侠义 código dos cavaleiros · 姑娘 moça (narration) /
senhorita (address) · 少爷 jovem mestre · 公子 jovem senhor · 小姐 senhorita · 夫人 senhora · 老爷
senhor / patrão · 前辈 veterano (address: Sênior) · 晚辈 júnior · 长老 Ancião (a title; ancião, lower
case, an old man).

School kin: in the UI and the codex the first time in full — 师兄 / 师姐 irmão mais velho / irmã
mais velha de escola, 师弟 / 师妹 irmão mais novo / irmã mais nova de escola, 师伯 / 师叔 tio mais
velho / tio mais novo de escola; in speech Irmão / Irmã / Tio + the surname (Irmão Liu, Tio Liu).

## Names

One picture, one plain word, as in English: maps, quests and the UI use the Portuguese name.

* **People**: pinyin, surname first, no tones (Liu Chunfeng) — the English text's pinyin; an
  epithet is translated and follows a comma. A Buddhist or Daoist name is one word (Liaochen).
* **Places**: as English: a place named for what one sees is translated, a real proper name keeps
  its pinyin; at most three words on the map, in Brazil's naming pattern X da Y (Pavilhão da Neve
  (雪亭镇), Sombra Alta (乔阴), a Capital (京师)). A place takes the article in a sentence when
  Portuguese gives it one (a Capital, o Passo do Camelo, o Pavilhão da Neve: no Pavilhão da Neve;
  a pinyin name takes none, nor do Sombra Alta and Tece-Nuvens): its row in the
  noun table says so, with its gender, and the mark contracts it (na Capital, à Capital, do Passo
  do Camelo; to Sombra Alta, with no article, a Sombra Alta).
* **Schools**: 派 / 门 Escola · 教 Ordem (东方神教 a Ordem do Corvo Dourado) · 帮 / 会 Irmandade
  (never Guilda, a trade guild; 花紫会 a Irmandade dos Mendigos) · 宫 Palácio · 庄 Solar (a
  historic manor; mansão is a modern villa in Brazil) · 武馆 Salão (academia is a gym in Brazil; in
  full the first time Salão de Artes Marciais). **seita** only in the mouth of those who condemn
  them: in Portuguese it means a heretic cult, so a neutral school is never one, whatever web
  novels do.
* **Moves** are images, at most six words, a noun phrase unless the Chinese is a verb sentence.
* **Items, beasts, generic people** are Portuguese words (野狗 cão selvagem, 牛皮酒袋 odre de couro,
  山贼 bandido, 店小二 moço da estalagem (moço alone where short), 掌柜 estalajadeiro in an inn,
  dono da loja / comerciante in a shop). Books and manuals in quotes: "O Clássico do Coração"
  (inside a said line '...').

## Terms

精 Essência · 气 Qi · 神 Espírito · 魂 Alma · 鬼 fantasma · 内力 Força interior (the resource) · 内功
neigong (the art) · 轻功 qinggong · 潜能 Potencial · 加力 Força extra · 杀气 Aura assassina · 法力
Poder arcano · 灵力 Energia espiritual · 定力 Serenidade · 实战经验 Experiência de combate · 经脉
meridianos · 穴道 pontos de acupuntura (pontos where short) · 心法 método interno · 秘籍 manual secreto
(an old classic: tratado secreto) · 回合 (a fight's round) rodada · 手 (a fight's turn: two in a
round) turno · 江湖 jianghu · 武林 wulin · 两 tael, plural taéis · 文 wen · 里 li · 丈 zhang (wen, li,
zhang never take an s) · 时辰: in the text the Portuguese time (子时 meia-noite, 午时 meio-dia); hora
dupla only in the codex. No HP or MP: the HUD writes Essência / Qi / Espírito / Pot. / Nív. Qi is
capitalised in every sentence.

**Never let two terms collide:** 内力 ≠ 内功, 师父 ≠ 掌门, 大侠 ≠ 英雄 (herói), 神 ≠ 魂 ≠ 鬼, 法力 ≠ 灵力,
回合 ≠ 手.

## Grammar

* Brazilian clitics: before the verb (O bandido te olha; Ele se levanta), never mesóclise; a
  sentence may open with one (Me dê a espada.) in speech; narration opens with the subject.
* Contractions are always written, of the definite article only: de + o do, em + a na, a + o ao,
  a + a à, por + o pelo, and their plurals (dos, nas, aos, às, pelos). The indefinite article is
  not contracted (de um, em uma, never dum, num); para and com never contract (para o, com a).
  After a slot the marks do it; after written text the translator writes them.

## Grammar marks

Portuguese puts an article before a common noun and agrees with its gender and number, and the
article joins the preposition before it; a template does not know the name its slot will hold. The
game finishes a filled line (`PortugueseText`, the shared `RomanceText` with Portuguese's words,
from the noun table `game/locale/pt_BR_nouns.json`, which keeps each name's gender and its whole
plural: garçons, cães, pães, anéis, espadas velhas):

* **article**, right after a slot or token: `{npc}{:o}` the definite article (o moço, a espada
  velha, as tesouras; a proper name takes none: Liu Chunfeng), `{:um}` the indefinite (um moço,
  uma espada), `{:os}` and `{:uns}` the name in its plural with the plural article (as espadas
  velhas, uns moços), `{:0}` — no article — the common noun in lower case («Sou {npc}{:0}»). Write
  the bare preposition before a marked slot; it contracts by itself: «Você fala de {npc}{:o}» →
  «do moço», «em {npc}{:o}» → «no moço», «a {npc}{:o}» → «ao moço» / «à Capital», «por
  {npc}{:o}» → «pelo moço». An article after written text is written by the translator.
* **capitals**: every name in pt_BR.po opens with a capital («Moço da estalagem», «Odre de
  couro»); a common noun goes lower case when the game fills it into a sentence after a mark. So a
  name slot that does not open a sentence always carries a mark.
* **gender**, `{~:ferido|ferida}` — agrees with the nearest marked name before it (else after it),
  **whole words**, m | f; four forms `{~:ferido|ferida|feridos|feridas}` when a plural can occur.
  A slot the game may fill with the player (a site that writes 你 into {who} or {name}) needs
  nothing for its verb (você takes the third person); an adjective after it follows the player's
  gender. Three forms `{~:você form|m|f}` exist for the rare line that needs one.
* **$N and $n** (ES2's actor and target): filled with the player they read Você / você, otherwise
  the name with its article. The verb is the same for você and anyone else, so `$N{:o} golpeia
  $n{:o}` needs no form; the player as $n is te: `$N{:o} {n:te golpeia|golpeia $n{:o}}`; three forms
  for a pronoun `{n:te|o|a}` (the player, m, f). ES2's $P/$p (his, her, your) are not written: whose
  thing it is changes with who $n is, so write the forms — `{n:sua pele|a pele dele|a pele dela}`.
* **the player's gender**, `{jogador:cansado|cansada}` (m | f), whole words.
* **numbers**: `%d {#:dia|dias}` agrees with the number before it (1 | any other; 0 takes the
  plural). `{count} {item}{:pl}` counts a filled name (3 espadas velhas). A list, a reward or an
  inventory line writes «{item} × {count}».
* **Avoid the marks where Portuguese can.** Rewrite rather than stack marks.

## Numbers

Numbers the Chinese writes in characters come out in digits: «{count} wen», «{generation}.ª
geração». Thousands take a point and decimals a comma (1.000; 1,5). A count with no fitting form is
written as a label: «Turnos: %d».

## Typography

* Straight quotes "..." (the pixel face draws “ ” and … full width), single '...' inside; dialogue
  is quoted, not dashed — a game convention, though Brazilian fiction uses the travessão: a said
  line is filled into "{line}", one line is one speaker («O moço diz: "Entre!"»), and a review does
  not change it to dashes. The full stop stays inside the closing quote.
* No ¿ or ¡, no « » (Portugal's and Spain's).
* An ellipsis is three dots `...`.
* Buttons ≤ about 18 letters, tabs ≤ 12: choose a shorter word, never cut one (a tab says Opções,
  a menu Configurações; Carregar jogo, not Carregar alone); Nív. and Pot. are the short forms. UI
  labels in sentence case (Salvar jogo).

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
