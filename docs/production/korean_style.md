# 한국어: style, names and particles

The Korean translation is `game/locale/ko.po` (Settings → 언어 → 한국어 (미리 보기)). Decisions
2026-11-22, worked out with Muse; DECISIONS「한국어 (preview)」. Check a translation with
`python tools/l10n/check_po.py game/locale/ko.po` (the gate runs it too); batches go in with
`tools/l10n/po_batch.py` ([LOCALIZATION](LOCALIZATION.md#working-on-a-translation)).

The frame is Korean wuxia as its readers know it: the Korean Jin Yong translations (김영사, 곽정,
영호충, 화산파) for names, speech and forms of address; 天涯明月刀's Korean terms for the game's
systems; 열혈강호 for move names. Not machine Korean, not modern chat.

## Registers

| Who, to whom | Register | Example |
|---|---|---|
| narration, room descriptions, the log, fights | 해라체 평서 | 산적이 칼을 휘두른다. |
| — a room, an attack, what happens now | present | 바닥에 모래가 깔려 있다. |
| — a blow's result (结果…), the opening, a memory, a quest's record and journal text | past | 상처가 벌어졌다! 소년은 하늘을 바라보았다. |
| peers in the jianghu, strangers, grown-ups | 하오체 | 못 들어 봤소. 물어보시오. |
| a man's elder to a junior, a master to a disciple | 하게체: -네, -게, -ㄴ가, -세 (not -지, -군) | 책은 함 속에 있네. 자네가 가져오게. |
| a woman elder (师太, 婆婆, a woman master) | 하오체, or 해체 kept soft | 그렇게 하오. |
| a disciple to a master, a waiter or servant to a guest | 합쇼체 throughout (no 해요체 -요, -군요) | 사부님, 알겠습니다. |
| — the waiter's own flavour | 옵쇼 / 굽쇼, sparingly | 어서 옵쇼! |
| an emperor, a master or abbot in a formal moment | 하소서체, rarely | 황공하옵니다. |
| bandits, villains, insults, an order to a child | 해라체 | 네놈, 물러가라! |
| close friends, children, a child spoken to kindly | 해체 | 밥 먹어. |
| tutorial, hints, system messages | 합니다체 | 저장했습니다. … 하십시오. |
| buttons, menus, tabs | nouns | 저장, 불러오기, 설정 |
| quest objectives | noun form in -기 | 점소이에게 묻기. |
| codex (百科) | 해라체, a definition's voice | 내공은 … 이다. |

One person keeps one register; it changes only with the relation (taking a master, a feud, a
break). Never 해요체 in the codex or the tutorial.

**The player.** ES2's templates fill `$N`/`$n` and `你` with **당신**, the second person of a
narrated game (Disco Elysium's Korean narration does the same). Where the Chinese writes 你 into
a sentence, leave the subject out if Korean can: 「你到了黄石隘口」 황석애구에 이르렀다. No one in
dialogue says 당신: people say 그대, 자네, 너, 네놈, 소협, 대협, or a name or title. 阁下 is left out
or becomes a title; 귀하 only in letters and notices.

## Particles after a slot

A name filled into `{npc}`, `{item}`, `$N`, `$n`, `$p`, `%s` changes the particle after it.
Write both forms after the slot, consonant form first; the game picks one when the line is
filled (`KoreanParticles`):

* `은(는)`, `이(가)`, `을(를)`, `과(와)`, `아(야)` (vocative), `이여(여)`, `이었(였)`;
* `(으)로`, `(으)로서`, `(으)로써`, `(으)로부터` — 로 after a vowel or ㄹ;
* `(이)` before any ending that drops it after a vowel: `(이)라는`, `(이)나`, `(이)란`, `(이)며`,
  `(이)든지`, `(이)라도`, `(이)오`, `(이)다`.

A pair only goes right after a slot or token (past a closing quote: `‘{topic}’을(를)`), or opens
an NPC's action line, which follows its name: `이(가) 빗자루를 내려놓는다.` After text you wrote,
write the form yourself; check_po fails on a pair there. The pairs never reach the screen.

Status lines (`{status}`) and other fragments filled into another sentence are whole clauses
that do not lean on a particle: `( $N: {status} )`.

## Names

**Korean Sino readings (한자음) with 두음법칙**, as the Korean Jin Yong does: people, places,
schools, arts, moves, titles. Never pinyin, never ES2's English ids (waterfog, latemoon...).

설정진 雪亭镇 · 기운진 绮云镇 · 교음현 乔阴 · 경사 京师 · 황성 皇城 · 람성 岚城 (an exception to
두음법칙: 남성 is "male") · 옥라호 玉螺湖 · 노송림/노송령/노송채 老松林/岭/寨 · 야양산 野羊山 ·
천타관 天驼关 · 일조산 日照山 · 흑송산 黑松山 · 번방 番坊 · 관북 关北 · 역령궁 逆灵宫 ·
황석고개 黄石隘口 (a natural pass: 고개) · 음풍객잔 饮风客栈 · 채홍대 虹台 (홍대 is a Seoul district) · 수연각 水烟阁 ·
봉산검파 封山剑派 · 순풍무관 淳风武馆 · 천악파 天邪派 (천사 is "angel") · 동방신교 东方神教 ·
진원표국 振远镖局 · 만월장 晚月庄 · 화자회 花紫会 · 모천귀 侮天鬼 · 유순풍 柳淳风 (淳 순) · 원본 原令 (원령 is a vengeful ghost) ·
유회심 柳绘心 · 선망보검 旋芒宝剑.

* Check a new name against everyday Korean: a reading that is a common word (천사 angel, 남성
  male, 홍대) is changed, and the change goes in the glossary. Readings that context separates
  (설정 settings, 기운 energy, 사형 death penalty) stay.
* Moves keep their Sino reading (饿鬼拦路 아귀난로); the hover or codex says what it means in a line.
* Items, food, furniture and everyday things are translated as Korean words, not read
  (皮衣 가죽옷, 牛皮酒袋 소가죽 술부대); a named treasure is read (旋芒宝剑 선망보검).
* Every new name goes into the glossary (`build/ko/names.tsv` in the kit) before it is used.
* **An established Korean name comes first** (owner 2026-11-22 for every language): official
  usage > published translation (the Korean Jin Yong, 고전 번역) > game and community usage > our
  own. It must name the same thing: 观音 관음, 心经 반야심경, 阎王 염라대왕, 孟婆 맹파,
  玉皇大帝 옥황상제; offices as Korean history writes them (县令 현령, 尚书 상서, 捕头 포두).
* **Neither free nor literal:** keep each sentence's facts, order and mood; no added detail,
  nothing dropped; carry the mood in a Korean sentence, not word for word.

## In-jokes

ES2's in-jokes are **localized, not translated** (owner 2026-11-22, as in English): a joke a
Korean player cannot read (a Chinese university, 1990s Chinese software, a dorm number) becomes
one they can — a Korean university, a dorm, the Microsoft–한글과컴퓨터 story of 1998, 魏阮 (微软)
as 마이크 로소프트. The joke keeps its job (an anachronism stays one, a boast a boast); items,
flowers, trigger phrases, buttons and any name the game checks stay as they are; real people's
names stay. Each one is listed for Muse in its batch. Settled with Muse: 华中理工大学 / 华工 카이스트 ·
八舍 카이스트 기숙사 8동 (the number stays: it is how the lines recognise each other) · 南大食堂磁卡
서울대 학식 카드 · 「把 NT 也汉化，看你之星怎么办」 the 1998 attempt to end 아래아한글 with money
(MS가 돈으로 아래아한글을 없애려던 그때처럼 — the line says what happened; MS did not buy 한컴) ·
魏阮 (微软) 마이크 로소프트 · 黑你没商量 묻지 마 바가지.

## Terms

江湖 강호 · 武林 무림 · 内功 내공 (what is trained) · 内力 내력 (what is spent) · 轻功 경공 ·
精/气/神 정·기·신 · 潜能 잠재력 · 实战经验 실전 경험 · 杀气 살기 · 法力 법력 · 灵力 영력 ·
定力 평정심 (not 정력, which reads as stamina) · 师父 사부(님) · 掌门 장문인 · 师兄/师弟/师姐/师妹 사형/사제/사저/사매 · 长老 장로 ·
客官 손님 · 施主 시주 · 贫道 빈도 · 老衲 노납 · 贫僧 빈승 · 在下 재하 · 大侠 대협 · 少侠 소협 ·
店小二 점소이 · 掌柜 장궤 · 大内 대내 · 镖局 표국 · 腰牌 요패 · 盟主 맹주.
承让: 양보해 주셔서 감사합니다 (합쇼체), 봐주셔서 고맙소 (하오체). No HP or MP.

Units: 文 문, 两 냥, 里 리, 丈 장, 尺 척, 斤 근, 时辰 시진. A number the translator writes is a Korean
number word, native up to 99 with the traditional units (은자 열 냥, 엽전 열 문, 한 시진, 세 자루),
Sino from 100 (백 냥) and for order (제3대). A number the game fills (`{count}`, `%d`, money,
damage) is digits: 엽전 10문, 장검 3자루. 正月十七 정월 열이레.

## Counting and articles

Korean does not say "one" when it hands over or finds a thing: 一个牛皮酒袋 is 소가죽 술부대.
`一{unit}{item}` is `{item}`; `{count}{unit}{item}` is `{item} {count}{unit}` (장검 3자루).

## Typography

* Quotes “ ” outside, ‘ ’ inside (Chinese 「」 → “ ”, 『』 → ‘ ’); 《》 for book and manual titles.
* One … for any Chinese …… or ....; one em dash — with no spaces.
* . , : ; ! ? ( ) — never 。，、：；！？（）. 【】 in log tags may stay.
* Korean wraps at spaces: the game keeps each word whole on a line (`KoreanText`), so mind
  long words in narrow buttons. Buttons ≤ 8 syllables, tabs ≤ 5.
* No Han characters in the text (check_po fails on one): the font draws them, but the player
  should not need them.

## Checking a batch

`check_po.py` (slots, particles, Han, punctuation); then read at least ten lines against the
Chinese — two each of names, fights, speech, descriptions and UI. Two problems or more in those
ten: read thirty. Story and region batches also go to Muse.
