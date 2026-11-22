# 日本語: style, names and terms

The Japanese translation is `game/locale/ja.po` (Settings → 语言 → 日本語（プレビュー）). Decisions
2026-11-22, worked out with Muse in two rounds; the owner took every recommendation the same day
(「都按推荐来」, the list at the end); DECISIONS「日本語 (preview)」. Check a translation with `python tools/l10n/check_po.py game/locale/ja.po` (the gate runs
it too); batches go in with `tools/l10n/po_batch.py`
([LOCALIZATION](LOCALIZATION.md#working-on-a-translation)).

**The one risk** is turning a Chinese jianghu into a Japanese period drama. Japanese has strong
ready-made voices for samurai, Edo merchants and old men; used whole, 柳淳風 becomes a daimyo, the
inn's waiter an Edo sushi shop, a bandit an Edo street tough. Borrow terms and glyph rules from the
published Jin Yong (徳間書店, 岡崎由美 監修), not a whole set of 役割語.

## Registers

| Text | Register | Example |
|---|---|---|
| narration, room descriptions, the log, fights | 常体: verb sentences 〜する／〜した, noun sentences 〜だ | 床には黄色い細かな砂が敷かれている。 |
| — a room, an attack, what happens now; a quest objective still open | present | 山賊が刀を振りかぶる。 |
| — a blow's result (结果…), the opening, a memory, a finished quest's record | past | 傷口がぱっくりと開いた！ |
| codex (百科) definitions | である | 内力とは……である。 |
| tutorial, hints, system messages | です・ます | 保存しました。 |
| buttons, menus, tabs | nouns or a plain verb (保存, 読込; save data 記録) | 設定、はじめから、続ける、キャンセル |
| quest objectives | る形, never 体言止め | 店小二に話を聞く。 |

Frozen pairs: 新游戏 はじめから; 继续 続ける (the same message is the pause's only button and the
dialogue box's "next line", so not つづきから); 取消 キャンセル; 返回 戻る; 关闭 閉じる.

Shared templates (an unnamed NPC answering a question, `%s摇摇头…`) end neutral: no 〜な, 〜ん,
すまない, which give every speaker one man's voice; 〜ない, 〜です, すみません fit anyone.

Don't write a whole narration in である (it reads as a textbook); である is for definitions.
Chinese has no tense: decide it from what the line does, not from its category.

**Rooms** open with the place and drop the subject, ending in だ: 「你现在正站在雪亭镇南边的一家小客栈里」
雪亭鎮の南にある小さな宿屋の中だ。 立っている only where standing there is the point (a cliff's edge,
a door).

## Voices

Each kind of speaker gets a first person, a second person, endings and banned words — never a
whole dialect. One person keeps one voice; it changes only with the relation.

| Who | 一人称 | 二人称 | Endings | Never |
|---|---|---|---|---|
| jianghu peers, strangers | 私 / 俺 (by the person) | お前 / 君 / あんた | 〜だ、〜か | 拙者, 貴殿 as default |
| a master in his prime (柳淳風) | 私 | the disciple's name; 君 | 〜だ、〜しなさい | わし |
| old masters, old eccentrics (70+) | わし | お前 / お主 | 〜じゃ; 〜のう once in two or three lines | 〜でおじゃる, 〜ぞなもし |
| a disciple to a master | 私 | 師父 | です・ます | |
| to a senior brother/sister | 私 | 師兄 / 師姐 | polite 常体 (no full 敬語) | |
| the inn's waiter, shop help | 手前 / わたくし | お客さん / 旦那 | いらっしゃいませ, 〜でございます; へい、まいど once as a greeting | へい every line, いらっしゃいまし |
| bandits, villains | 俺 / 俺様 | お前; てめえ once or twice a scene | rough 常体 〜だ、〜しろ; 〜しやがれ, 野郎 sparingly | べらんめえ |
| women of the jianghu | 私 | by relation | 〜だ、〜よ | わ / かしら on every woman |
| old women (婆婆) | 私 / あたし | お前さん | 〜だよ; old by vocabulary, not dialect | |
| emperor | 朕 | | 文語 only in edicts | |
| high monks | 拙僧 | | 文語 (〜なり、〜べし) only in sutras, edicts, steles — one element a sentence | |

**Banned everywhere:** ござる (no exception), 〜アルヨ
(a stereotype of Chinese speakers), the whole べらんめえ set, modern slang (やばい、マジ、ウケる)
except inside an in-joke.

**The player.** ES2 fills `$N`/`$n` and `你` with **あなた**. Japanese drops the subject wherever
it can: 「你到了黄石隘口」 黄石峠に着いた。 No one in dialogue says あなた. The fight log's shared
templates cannot drop it (the same line serves an NPC), so あなたは山賊の動きを注視する stands there:
a compromise of the template, kept to the log (the player's own name instead would need a code
change at every place that fills 你). The player's own words use `{self}` (filled by rank, below); a line the
player speaks without it leaves the subject out, or uses 私.

### Self and address (`{self}`, `{respect}`, `$RESPECT`)

Monks, Daoists and nuns keep their kanji self-names; men and women of the jianghu get わたし-type
words by degree; no samurai words. Two Chinese words never become one Japanese word.

| `{self}` | Japanese | | `{respect}` | Japanese |
|---|---|---|---|---|
| 在下 | 在下 (already humble in Japanese; not 拙者, not それがし) | | 客官 | お客さん (formal お客様; 旦那 only from someone who knows the guest is a man) |
| 小女子 | 私（わたし） with です・ます | | 小兄弟 | 若いの (polite お若いの; 兄さん is the reverse) |
| 妾身 | わたくし (わらわ is a princess) | | 姑娘 / 小姑娘 | お嬢さん / お嬢ちゃん |
| 贫僧 | 拙僧 | | 师太 / 小师太 | 師太 |
| 老纳 | 老衲 | | 道长 / 道兄 | 道長 |
| 贫道 | 貧道 | | 大师 | 大師 |
| 贫尼 | 貧尼 (拙僧 is a monk's) | | 壮士 | 若武者 (kept apart from 若いの) |
| 老尼 | 老尼 | | 老前辈 | ご老体 (ご老人 sounds like a care home) |
| 老头子 | わし | | 婆婆 | おばあさん |
| | | | 仙姑 | 仙姑 |

「这位$RESPECT，…」: in a call the 这位 goes (お客さん、どうぞお茶でも); pointing at someone it is
こちらの + the address (这位姑娘是… こちらのお嬢さんは…). Never そこの or もし.

### Lines and actions

* Plain speech in a template is game style, the name and then the line: `{npc}「{line}」`.
* An action with speech keeps the action: `{npc}が首を振った。「聞いたことがない」` (or
  `…首を振って言った。「…」` where the speaking matters).
* Keigo follows 内と外: a waiter speaking to a guest about his own master humbles him
  (番頭が申しますには), never raises him (おっしゃる is for the guest's side).
* An action line that follows an NPC's name opens with its particle, with no comma after it
  (`が入ってきたこちらを見るなり…`). が for a first appearance, a new
  subject or a new action; は for a subject already in play or a state. Three が in a row reads like a
  roll call: vary.

## Names

**Kanji as written, in Japanese forms** (新字体): 剣 気 門 楼 嵐 喬 陰. Old forms Japanese names
still use are kept: 龍 (not 竜), 螢 (not 蛍). People, places, schools, arts, moves and titles keep
their kanji; no katakana pinyin (リュウ・チュンフォン). Readings are not shown in play (the pixel font
has no ruby); a codex entry gives the 音読み once in its first line, in hiragana: a person
柳淳風（りゅう・じゅんぷう） (surname・given name), a place 雪亭鎮（せっていちん）, 嵐城（らんじょう）.
Proper names of shops, halls and temples keep their kanji: 飲風客桟, 水煙閣, 虹台, 太乙観.

* Things you see and use every day are translated into Japanese words: 皮衣 革の上着, 牛皮酒袋
  牛革の酒袋, food, clothes, furniture. Wuxia concepts keep their kanji: 丹薬, 秘笈, 心法, 功法.
* A word that is Chinese but not Japanese is rewritten (出剣 → 剣を抜く, 剧情 is not 劇情).
* **An established Japanese name comes first** (owner 2026-11-22 for every language): official
  usage > published translation (徳間書店 金庸) > game and community usage > our own. 観音,
  般若心経, 閻魔大王, 玉皇大帝.
* **Neither free nor literal:** keep each sentence's facts, order and mood; nothing added or
  dropped; the mood carried by a Japanese sentence, not word for word.
* Words the glossary freezes for recurring roles: 掌柜 X店主 (楊店主), but 飲風客桟's 掌柜 is its
  番頭 (the owner is the wandering immortal); 土匪 野盗 (山贼 山賊); 武士 衛士 (武士 is a samurai);
  管家 家令; 管事 執事; 侍卫 侍衛; 保镖 用心棒; 衙役 捕吏; 狱卒 牢番; 僵尸 キョンシー; 阴间 冥界
  (陰間 is Edo slang). Rooms: 厅 広間 (正厅 大広間, 偏厅 脇の間, 客厅 客間; never 庁, an office, except the established 聚義庁 of 水滸伝),
  大门 正門, 后院 裏庭, 厢房 東棟／西棟, 密室 隠し部屋, 地牢 地下牢, 营帐 天幕, 渡口 渡し, 码头 波止場.
* Every name is in the frozen glossary (`build/ja/kit/names.tsv` in the kit) before it is used.

### Same characters, different meaning (rewrite, never copy)

| Chinese | means | Japanese reads it as | write |
|---|---|---|---|
| 勉强 | barely, reluctantly | study | しかたなく、やっと |
| 老婆 | wife | old woman | 妻、女房 |
| 娘 | mother (她娘, 我娘) | daughter | 母、おっかさん; 姑娘 is お嬢さん |
| 丈夫 | husband | sturdy | 夫 |
| 大丈夫 | a true man | all right | 大丈夫 only for "all right" |
| 先生 | sir, Mr. | teacher, doctor | by context |
| 故事 | story | anecdote, origin of a saying | 話、物語 |
| 走 | walk | run | 歩く |
| 客栈 | inn | (not Japanese) | 宿屋; a proper name keeps it: 飲風客桟 |
| 一刻 | a quarter hour | (Edo) two hours | 四半刻、しばらく |

## Terms

Frozen (Muse round 1, after 徳間書店's glossary): 江湖 · 武林 · 内功 (the method one trains) ·
内力 (the force one spends; never merged with 内功) · 軽功 · 点穴 · 鏢局 · 掌門 · 師父 (a martial
master; 師傅 is a craftsman) · 師兄 / 師姐 / 師弟 / 師妹 · 侠客 · 少侠 若き侠客 in titles and the
codex, never as a form of address.

## Numbers and counting

* A number the game fills (`{count}`, `%d`, money, damage, stats) is in digits: 銅銭10文、長剣3振り.
* A number the translator writes in a story is in kanji: 銀十両、一人、二日、三年.
* 「一个牛皮酒袋」 is the item's name alone (牛革の酒袋); in a sentence add the counter: 剣一振り,
  丹薬一粒, 書一冊, 酒一杯. `{count}{unit}{item}` becomes `{item}{count}{unit}`.
* Units stay: 里 丈 尺 寸 斤 両. The codex says once that a 里 here is the Chinese li of about 500 m
  (a Japanese 里 is 3.9 km); the others differ too little to matter.
* 时辰: 子の刻, 午の刻 (the codex says once that the hours of the day here are double hours). Never 刻 for 时辰 alone: a Chinese 刻 is a quarter hour.

## Typography

* 「」 for speech, 『』 inside quotes and for titles of books and arts (《》 becomes 『』). Every art,
  skill and dance named in running text (a line, a quest, a description, the log) is in 『』:
  『封山剣法』, 『滄海龍吟』, 『点』の字訣; the skill list and buttons show the bare name.
* Buttons aim at 6 full-width characters (8 at most; shorten the word, never the font size), tabs at
  4 (5 at most), kanji compounds before long katakana. A shortening is frozen once chosen:
  背包 持ち物, 声望 名声, 任务 任務.
* 、。！？ full width; …… (two three-dot leaders) for any Chinese …… or ....; no ，；“ ” ‘ ’, no
  ASCII ... (check_po fails on them).
* Every kanji must be one Japanese writes: check_po fails on a kanji outside JIS X 0208 (a
  Simplified form left behind, 剑 气 们), unless it is listed in `JAPANESE_EXTRA_KANJI` (a name's
  rare character the ja pixel face draws).

## In-jokes

ES2's in-jokes are **localized, not translated** (owner 2026-11-22, as in English and Korean): a joke
about 1990s Chinese campuses and software becomes one a Japanese player can read; the joke keeps its
job; items, trigger phrases and any name the game checks stay. Decided:
华工 東大 (東工大 for a science school) · 八舍 東大の第8寮 · 南大食堂磁卡 東大の学食カード ·
「把 NT 也汉化，看你之星怎么办」 Windowsも日本語化してやる、一太郎はどうする？ (or a literal
ネットスケープ) · 魏阮 (微软) マイク・ロソフト · 黑你没商量 値切るな、言い値だ.

## Checking a batch

`check_po.py` (slots, Japanese kanji forms, punctuation); then read at least ten lines against the
Chinese — two each of names, fights, speech, descriptions and UI. Two problems or more: read thirty.
Story and region batches also go to Muse.

## The title

「故事」 in Japanese is the story behind a saying (故事成語): 東方故事 reads as "Eastern anecdotes".
The title screen's line under the logo is **東方物語** (Muse; the plain RPG word, as Eastern Stories
and 동방이야기), or 東方奇譚 (narrower, and close to the Japanese title of Yourcenar's *Nouvelles
orientales*), or 東方故事 kept.

## Decided by the owner (2026-11-22, 「都按推荐来」)

1. Title line 東方物語. 2. 保存・読込. 3. Codex readings in hiragana 音読み. 4. In-jokes localized
(東大, 一太郎, マイク・ロソフト, 言い値屋). 5. No ござる. 6. 子の刻. 7. あなた in the fight log.
8. 花紫会 kept as kanji. 9. Shop and inn names keep their kanji (飲風客桟).
