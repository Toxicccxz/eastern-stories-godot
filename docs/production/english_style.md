# English: style, names and the grammar marks

The English translation is `game/locale/en.po` (Settings → Language → English (preview)). Owner decisions
2026-11-20/21, worked out with Muse; DECISIONS「English (preview)」. Check a translation with
`python tools/l10n/check_po.py game/locale/en.po` (the gate runs it too); new batches go in with `tools/l10n/po_batch.py` ([LOCALIZATION](LOCALIZATION.md#working-on-a-translation)), never by writing the file again.

## Tone

**Plain, period, spoken.** Not mock-archaic (no thee/thou), not modern American chat. American spelling.
The frame is the Wuxia Society's Jin Yong translations; the shared wuxia vocabulary of the English web-novel
readers (Senior Brother, Elder, this old man, brat, lose face) is welcome; cultivation-novel register
(realms, power levels, a meme a line) is not.

* ES2's own text stays a touch formal; the new story text is short, hard and leaves things unsaid.
* Keep the new writing's gaps: the same number of sentences as the Chinese, no added *because / and then*,
  no explaining a picture or a feeling the Chinese leaves out, the shortest subject where English needs one.
* Never: dude, bro, cool, awesome, okay/OK, whatever, totally, my bad, no worries, guys (as address),
  freaking, sucks, pal, mate. `courting death` at most once or twice, from a bandit or a spoiled young master.

## Voices

Accent is words and grammar first. The only spellings allowed are `'em`, `ya`, `y'know` and a dropped g
(`goin'`), at most one per sentence, and only at level 2.

| Level | Who | Rule |
|---|---|---|
| 0 | narration, codex, UI, most people | ordinary contractions |
| 1 | waiter, friends, children, the Late Moon girls, Guanbei labourers | gonna/wanna, one a sentence |
| 2 | bandits, toughs, drunks, gamblers, jailers | ain't, `'em`, `ya`, dropped g |
| F | monks, Daoists, officials, scholars, eunuchs, ronin, Liu Chunfeng | no contractions at all |

Foreigners (Daqin) leave words out but make no mistakes: "I speak three tongues. None of them well."
Address: 客官 sir / traveler · 施主 Benefactor · 老衲 this old monk · 贫道 this poor Daoist · 在下, 俺, 老子 I ·
阁下 sir / my lord · 恩人 my savior · 咱家 this servant · 本县 this county. 承让 is "Thanks for going easy on me".

## Names

One picture, one plain word; at most one Chinese word on a screen. Maps, quests and the UI use the English
name; pinyin is a person's name, or what a local calls a place in speech.

* People: pinyin, surname first (Liu Chunfeng); an English epithet only where the game has one
  (Liu Chunfeng, the Wind-and-Rain Swordsman).
* Places: a real place keeps its pinyin (Yangzhou); a made-up place named for what you see is translated
  (Tallshade, Cloudweave Town); ES2's own English coinages are kept (waterfog, latemoon, goathill,
  snowshade…), its romanisations are not (sanyen, fonxan). 县 / 镇 / 府 follow what the place is in the game.
* **An established English name comes first** (owner 2026-11-22, with Muse), in this order: official
  (the Palace Museum, scholarship) > published literary translation (Jin Yong's, Wuxia Society) >
  community usage (Wuxiaworld) > a name of our own. It must name the same thing: 紫禁城 is not the
  Forbidden City here (our capital is made up), 观音 is Guanyin, not "the Goddess of Mercy". Halls
  take "Hall of X" (养心殿 Hall of Mental Cultivation, 太和殿 Hall of Supreme Harmony); gods take
  pinyin and their usual title (Zhenwu, King Yama, the Jade Emperor, Meng Po); 心经 the Heart Sutra;
  天师道 the Way of the Celestial Masters; 武状元 Martial Champion; offices follow Hucker's *Dictionary
  of Official Titles* (County Magistrate, Minister, Censor, Head Constable); 时辰 is a double-hour; 两 of silver is the
  established tael; other measures stay pinyin (jin, li, wen); 丈 is about ten feet; 正月十七 the seventeenth day of the first month.
* Neither free nor literal: keep each sentence's facts, order and mood; carry the mood in the English
  sentence, not word for word ("老松寨是老子的寨子" Old Pine Stockade is mine). Form may change where the
  form is the joke (a list stays a list); ES2's engine marks such as (sign) are not prose.
* Schools: 派 that teaches arts = **School**; 教 with a doctrine = **Order**; 帮 / 会 = **Guild**.
  *Sect* and *Cult* only in the mouths of those who condemn them.
* Moves are translated as images (饿鬼拦路 Hungry Ghost Blocks the Road).

Snow Pavilion · Cloudweave Town · Tallshade (乔阴) · the Capital · the Palace City · the Wind City (岚城) ·
Jade Conch Lake / Village · Old Pine Ridge / Stockade / Wood · Goathill · Camelback Pass · Sunlit Mountain ·
Black Pine Mountain · the Foreign Quarter · Beyond the Pass (关北) · the Black Palace (逆灵宫) ·
Yellow Rock Pass · Drinkwind Inn · Rainbow Terrace.
Empty Mountain School (封山剑派) and its Pure Wind Hall (淳风武馆) · the Wayward School (天邪派) ·
the Dustless School · Mount Mao School · Mystic Step School · Latemoon Manor · Waterfog Pavilion ·
Mountain Mist Temple · the Golden Crow Order (东方神教) · the Far-Road Escorts (振远镖局) ·
the Beggars' Guild (花紫会). Spiritpiercer (穿灵) · Whirling Edge (旋芒) · Hanyu's Robe (寒於宝衣) ·
the Heaven-Defier (侮天鬼).

## Terms

精 Essence · 气 Qi · 神 Spirit · 内力 Inner Force (never qi) · 内功 neigong · 轻功 qinggong · 潜能 Potential · 加力 Extra Force ·
杀气 Bloodlust · 法力 Arcane Power · 灵力 Mystic Power · 定力 Resolve · 实战经验 Combat Experience ·
师父 Shifu · 掌门 Master (a title: Master Liu) · 师兄/师妹 Senior Brother / Junior Sister · 长老 Elder ·
江湖 jianghu · 武林 wulin · 手 (a fight's turn) beat · money wen · distance li.
No HP or MP. The HUD may shorten to ESS / QI / SPI / POT / Lv.; every number's hover says the full word,
and reward lines always write it out ("Potential +12").

Neigong is the practice, Inner Force what it builds; keep the two apart. As a skill or category name
they take a capital (Basic Neigong, Qinggong).

## Checking a batch

Before a batch goes into en.po: `check_po.py` (slots, marks, full-width punctuation, modern words);
`build/l10n/term_check.py` in the worktree kit (a glossary name the translation does not use); and a
read of at least ten lines against the Chinese, two each of names, fights, speech, descriptions and
UI. Two problems or more in those ten: read thirty. A new region's first batch gets twice the read.
Every new name goes into the glossary before merging, checked for a clash with another name.

## Grammar marks (ES2 templates)

Chinese has one form for 你 and a name; English does not. In a line with $N (the one acting) and $n
(the one acted on), `MessageGrammar` resolves:

* `{N:flick|flicks}` — the first form when $N is the player, the second otherwise (`{n:…}` for $n).
  Every verb whose subject is $N or $n carries it: `$N {N:are|is}`, `$n {n:leap|leaps}`.
* `{N:he}` `{N:him}` `{N:his}` `{N:himself}` — you / you / your / yourself for the player, else by gender
  (she / her, it for a beast). Never `$P` / `$p` in English. A few sites do not know the other
  side's gender (an apprenticeship's accept line, a spell's target, a move's hover line): there the
  marks give "it", so write those lines without that role's pronoun, or pass the gender first.
* `$N's` / `$n's` — becomes "your" for the player; a name keeps its 's. With $N as subject write
  `{N:his} $w`; `$N's $w` when the weapon is the subject.
* A sentence that opens with "you" or a lower-case name is capitalised for you. Do not open a sentence
  with `$RESPECT` or `{respect}` (forms of address are lower case): "Come in, $RESPECT!"

## Typography and the UI

* Straight quotes `"` and `'`, and `...` for an ellipsis: the pixel font's curly quotes and … are
  full-width Chinese forms.
* One dash: an em dash with no spaces (`word—word`), never ` - ` or ` — `. Ask topics are Title Case.
* An NPC's action line follows its name directly (`{npc}{action}`): start it with a space
  (" sees you and sets down his broom.") or with "'s" ("'s eyes redden for a moment.").
* Plurals: Chinese has none, so avoid "%d beats": write "Beats left: %d", "×%d", "Items inside: {count}."
* Numbers the Chinese writes in characters (十文, 第三代) come out in digits in English (`ChineseNumber.of`):
  write "{count} wen", "Generation {generation}", never a number word around the slot.
* English runs about 1.6× wider than the Chinese in the same font: buttons ≤ 16 characters, tabs ≤ 12,
  move names ≤ 20, status words ≤ 10. Rewrite rather than abbreviate.
* One source word can stand for two things (快 is battle speed *and* a move tag): find one English word
  that fits both, or give the source a `msgctxt`.
