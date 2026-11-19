"""The 虹台 count (修补 Z; DECISIONS「大会 B」「虹台的票」): the assembly act in game/data/waterfog/world.json
is one long hand-written list of steps with some eighty copies of the nine factions' list. This runs it
over the same JSON the game loads, with a small evaluator of the condition language and the act's step
semantics (game/runtime/world/map/world_map_acts.gd: a step's `when`, `by` ending the act when its speaker
is not on the stage, `choose` going on with the option's steps and the rest, a choose with nothing
offered passed over), over reachable states before 入席:

* exactly one result; each faction one vote line; the counts sung equal the votes; the result follows
  the counts; each head on the platform says one line; the stand option is locked exactly when
  assembly.day.can_stand does not hold;
* every card of the assembly epilogue shows a line, and each card's lead (the result it tells) exactly one;
* every copy of a faction list in the act, conditions.json and the 任务 page names the same factions;
* nothing that writes a mark the votes read can be done once seated (入了虹台的席): only 问话 rules write
  them, and each is refused to one seated.

The states are a model of what each line's rules let a player reach (each faction's marks, the main
story's); every mark in the model must exist in the data, so a renamed mark fails here.
"""

import json
import random
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2] / "game" / "data"


def _load(path):
    return json.loads((ROOT / path).read_text(encoding="utf-8"))


CONDS = {c["id"]: c["when"] for c in _load("story/conditions.json")["conditions"]}
_WORLD = _load("waterfog/world.json")
_SERVICE = next(s for s in _WORLD["services"] if s["id"] == "waterfog.terrace_top.assembly")
ACT = _SERVICE["act"]["acts"][0]
SPAWNS = [s for s in _load("native/spawns.json")["spawns"] if s.get("map") == "waterfog.terrace"]
EPILOGUE = next(e for e in _load("story/epilogue.json")["epilogues"] if e["id"] == "assembly")
QUEST = _load("story/faction_assembly.json")["quests"][0]
XUANMANG = "native:lancheng/xuanmang"
SEATED = "入了虹台的席"
OVER = "大会散了"

FACTIONS = ["fonxan", "celestial", "zhenyuan", "maoshan", "latemoon", "sanyen", "buxuan", "huazi", "juechen"]
NAMES = {"fonxan": "封山剑派", "celestial": "天邪派", "zhenyuan": "振远镖局", "maoshan": "茅山派", "latemoon": "晚月庄",
         "sanyen": "山烟寺", "buxuan": "步玄派", "huazi": "花紫会", "juechen": "绝尘派"}
OUTCOMES = ("当了武林盟主", "颜违做了盟主", "卫沧澜坐回了椅子", "盟主的椅子还空着")
CHOOSES = ("山下出了事，你只来得及管一件：", "九派之外，还有谁要站出来？", "老松岭的旧案：", "逆灵宫剩下的人：", "东方神教：", "旋芒：")
STAND = "我也算一个"

# Each faction's reachable marks before 入席, by its rules (the vote marks are written only before 入席).
FACTION_STATES = {
    "fonxan": [[], ["跟了本宗"], ["跟了本宗", "封山听你的"], ["跟了北宗"], ["跟了北宗", "封山听你的"]],
    "celestial": [[], ["站了颜违"], ["站了颜违", "天邪听你的"], ["站了潘军禅"], ["站了潘军禅", "天邪听你的"]],
    "zhenyuan": [[], ["振远改投旧盟主"],
                 ["振远旧账到此为止", "振远的票随了到此为止"], ["振远旧账到此为止", "振远的票随了到此为止", "振远听你的"],
                 ["振远改投旧盟主", "振远旧账到此为止", "振远的票随了到此为止"],
                 ["振远旧账查到底", "振远的票随了查到底"], ["振远旧账查到底", "振远的票随了查到底", "振远听你的"],
                 ["振远改投旧盟主", "振远旧账到此为止"], ["振远旧账查到底"]],
    "maoshan": [[], ["茅山听你的"], ["茅山的票随了林忌"], ["茅山的票随了林忌", "茅山听你的"],
                ["茅山的票随了花匠"], ["茅山的票随了花匠", "茅山听你的"]],
    "latemoon": [[], ["晚月庄改投颜违"], ["晚月庄听你的"]] + [
        split + turn + mine
        for split in (["晚月庄的票随了庄规", "晚月庄依了庄规"], ["晚月庄的票随了她", "她回了晚月庄"])
        for turn in ([], ["晚月庄改投颜违"]) for mine in ([], ["晚月庄听你的"])],
    "sanyen": [[], ["山烟寺改投旧盟主"]] + [
        split + turn + mine
        for split in (["山烟寺的票随了收经"], ["山烟寺的票随了守寺"])
        for turn in ([], ["山烟寺改投旧盟主"]) for mine in ([], ["山烟寺听你的"])],
    "buxuan": [[], ["步玄听你的"], ["步玄的票随了作证"], ["步玄的票随了作证", "步玄听你的"],
               ["步玄的票随了骆家"], ["步玄的票随了骆家", "步玄听你的"]],
    "huazi": [[], ["花紫会的票随了真龙头", "认了二十三个结"], ["花紫会的票随了真龙头", "认了二十三个结", "花紫会听你的"],
              ["花紫会的票随了陆得财", "认了管事的陆得财"], ["花紫会的票随了陆得财", "认了管事的陆得财", "花紫会听你的"]],
    "juechen": [[], ["绝尘派肯来"]],
}
MAIN_STATES = {
    "slay": [[], ["侮天鬼灭了"]],
    "wei": [[], ["卫沧澜出了尚书府"], ["卫沧澜出了尚书府", "皇叔要回了卫沧澜"], ["卫沧澜出了尚书府", "花紫会偷出了卫沧澜"]],
    "yu": [[], ["庾子建下狱"]],
    "nan": [[], ["告发了南危水"]],
    "cult": [[], ["站了安妮儿"], ["站了朱鸿雪"]],
    "remnant": [[], ["余孽有了去处", "余孽交了官府"], ["余孽有了去处", "招安了余孽"]],
}
HANDLES = ("山道上", "葬剑亭", "官道上", "山下茶棚", "哪件也不管")
STANDS = (STAND, "听我的那几派，投旧盟主", "听我的那几派，投颜违", "坐着听唱票")

# Each card's lead: the lines that tell what the day came to; exactly one of them shows.
CARD_LEADS = {
    "terrace": ("正月十七，",),
    "waterfog": ("正厅的太师椅",),
    "yard": ("九派逐了东方神教", "神教照旧", "虹台上没有人提神教"),
    "north_slope": ("北麓的道观空了", "下了山的道士", "九派的人上了北麓", "茅山的人上了北麓", "官兵上了北麓", "北麓的道观里"),
}

# What writes marks besides 问话 rules: an act's or a call's steps, gifts, fights, a quest's rewards.
GIVER_KEYS = ("mark_giver", "marks_giver", "cleared_mark", "scene_mark", "die_marks_killer", "set_mark", "spar_won_mark", "also_mark")
# The one mark the votes read that is written otherwise: the 终章's end, which 入席 needs.
WRITTEN_BEFORE_SEATING = {"终章"}


def valid(marks):
    """What the model's product allows that the rules do not."""
    if "山烟寺改投旧盟主" in marks and "站了安妮儿" not in marks:
        return False
    if "步玄听你的" in marks and not ({"步玄的票随了作证", "步玄的票随了骆家"} & marks) and "庾子建下狱" not in marks:
        return False
    if "晚月庄改投颜违" in marks and "晚月庄听你的" in marks and not ({"晚月庄的票随了庄规", "晚月庄的票随了她"} & marks):
        return False
    return True


class State:
    def __init__(self, marks, items=()):
        self.marks = set(marks)
        self.items = set(items)
        self._cache = {}

    def mark(self, mark):
        if mark not in self.marks:
            self.marks.add(mark)
            self._cache = {}

    def holds(self, entry):
        if entry is None:
            return True
        kind, value = next(iter(entry.items()))
        if kind == "mark":
            return value in self.marks
        if kind == "cond":
            if value not in self._cache:
                self._cache[value] = self.holds(CONDS[value])
            return self._cache[value]
        if kind == "all":
            return all(self.holds(part) for part in value)
        if kind == "any":
            return any(self.holds(part) for part in value)
        if kind == "not":
            return not self.holds(value)
        if kind == "at_least":
            return sum(1 for part in value["of"] if self.holds(part)) >= value["n"]
        if kind == "item":
            return value in self.items
        raise KeyError("the evaluator does not know '%s'" % kind)


def on_stage(state, npc_id):
    return any(spawn["npc"] == npc_id and state.holds(spawn.get("present")) for spawn in SPAWNS)


def run(state, picks):
    """The act from its first step as 入席 starts it; `picks` choose text -> preferred option prefixes.
    Returns (end, log): end 'done', 'broken' (a speaker not on the stage) or 'stuck' (nothing to pick)."""
    log = []
    steps = list(ACT["steps"])
    speaker = None
    index = 0
    while index < len(steps):
        step = steps[index]
        index += 1
        if "when" in step and not state.holds(step["when"]):
            continue
        if "mark" in step:
            state.mark(step["mark"])
        elif "by" in step:
            if not on_stage(state, step["by"]):
                log.append(("missing", step["by"], None))
                return "broken", log
            speaker = step["by"]
        elif "say" in step or "emote" in step:
            log.append(("say" if "say" in step else "emote", speaker, step.get("say") or step.get("emote")))
        elif "line" in step:
            log.append(("line", None, step["line"]))
        elif "take" in step:
            state.items.discard(step["take"])
        elif "choose" in step:
            choose = step["choose"]
            offered = []
            for option in choose["options"]:
                if "when" in option and not state.holds(option["when"]):
                    continue
                locked = any(state.holds(lock["when"]) for lock in option.get("locked", []))
                offered.append((option, locked))
            if not offered:
                continue
            log.append(("choose", choose["text"], [(option["text"], locked) for option, locked in offered]))
            chosen = None
            for wanted in picks.get(choose["text"], ()):
                chosen = next((option for option, locked in offered if option["text"].startswith(wanted) and not locked), None)
                if chosen is not None:
                    break
            if chosen is None:
                chosen = next((option for option, locked in offered if not locked), None)
            if chosen is None:
                return "stuck", log
            log.append(("picked", choose["text"], chosen["text"]))
            steps = list(chosen.get("steps", [])) + steps[index:]
            index = 0
        elif not ({"epilogue", "restage", "title"} & set(step)):
            raise KeyError("the runner does not know the step %s" % sorted(step))
    return "done", log


def epilogue(state):
    return {card["id"]: [line["text"] for line in card["lines"] if state.holds(line.get("when"))] for card in EPILOGUE["cards"]}


def count_of(state, suffix):
    return sum(1 for faction in FACTIONS if "assembly.day.%s.%s" % (faction, suffix) in CONDS and state.holds({"cond": "assembly.day.%s.%s" % (faction, suffix)}))


CN = "零一两三四五六七八九"


def sampled_days(n, seed):
    rng = random.Random(seed)
    days = []
    while len(days) < n:
        base = set()
        for options in MAIN_STATES.values():
            base.update(rng.choice(options))
        for options in FACTION_STATES.values():
            base.update(rng.choice(options))
        if not valid(base):
            continue
        picks = {CHOOSES[0]: [rng.choice(HANDLES)], CHOOSES[1]: [rng.choice(STANDS)], CHOOSES[2]: [rng.choice(("查到底", "到此为止"))],
                 CHOOSES[3]: [rng.choice(("剿", "交茅山"))], CHOOSES[4]: [rng.choice(("逐", "容"))], CHOOSES[5]: [rng.choice(("交给水烟阁", "还给岚城", "我留着"))]}
        days.append((base, picks, rng.random() < 0.8))
    return days


def walk(entry, on_dict, path=()):
    """Calls on_dict(dict, path) for every dict in `entry`."""
    if isinstance(entry, dict):
        on_dict(entry, path)
        for key, value in entry.items():
            walk(value, on_dict, path + (key,))
    elif isinstance(entry, list):
        for position, value in enumerate(entry):
            walk(value, on_dict, path + (position,))


def marks_read(entry, found):
    """The marks a condition reads, through its named conditions."""
    def visit(node, _path):
        if "mark" in node and isinstance(node["mark"], str):
            found.add(node["mark"])
        if "cond" in node:
            marks_read(CONDS[node["cond"]], found)
    walk(entry, visit)
    return found


class AssemblyCountTest(unittest.TestCase):
    maxDiff = None

    @classmethod
    def setUpClass(cls):
        cls.days = []
        for base, picks, sword in sampled_days(1500, 17):
            state = State(base | {"终章", "拿了虹台请柬"}, [XUANMANG] if sword else [])
            before = {suffix: count_of(State(base | {"终章", SEATED}), suffix) for suffix in ("yan", "old", "self")}
            end, log = run(state, picks)
            cls.days.append((base, picks, state, end, log, before))

    def test_model_marks_exist(self):
        blob = "".join(path.read_text(encoding="utf-8") for path in ROOT.rglob("*.json"))
        used = set()
        for group in list(FACTION_STATES.values()) + list(MAIN_STATES.values()):
            for option in group:
                used.update(option)
        self.assertEqual(sorted(mark for mark in used if '"%s"' % mark not in blob), [])

    def test_the_day_tells_itself_once(self):
        problems = []
        for base, picks, state, end, log, _before in self.days:
            said = [text for kind, _who, text in log if kind == "say"]
            where = sorted(base)[:12]
            if end != "done":
                problems.append((end, [entry for entry in log if entry[0] == "missing"], where))
                continue
            outcomes = [mark for mark in OUTCOMES if mark in state.marks]
            if len(outcomes) != 1:
                problems.append(("outcomes", outcomes, where))
            for faction, name in NAMES.items():
                lines = [text for text in said if text.startswith(name + "——")]
                if len(lines) != 1:
                    problems.append(("vote lines", name, lines, where))
            yan = sum(1 for text in said if re.match(r"^.+——颜违。$", text))
            old = sum(1 for text in said if re.match(r"^.+——(卫盟主|旧盟主)。$", text))
            mine = sum(1 for text in said if re.match(r"^.+——投你。$", text))
            tallies = {"yan": [t for t in said if t.startswith("颜违，") and t.endswith("票。")],
                       "old": [t for t in said if (t.startswith("卫盟主，") or t.startswith("旧盟主，")) and t.endswith("票。")],
                       "self": [t for t in said if t.startswith("你，") and t.endswith("票。")]}
            if tallies["yan"] != ["颜违，%s票。" % CN[yan]]:
                problems.append(("颜违 sung", tallies["yan"], yan, where))
            if len(tallies["old"]) != 1 or not tallies["old"][0].endswith("，%s票。" % CN[old]):
                problems.append(("旧盟主 sung", tallies["old"], old, where))
            stood = "站出来参选" in state.marks
            if tallies["self"] != (["你，%s票。" % CN[mine]] if stood else []):
                problems.append(("你 sung", tallies["self"], mine, where))
            for suffix, sung in (("yan", yan), ("old", old), ("self", mine)):
                if count_of(state, suffix) != sung:
                    problems.append(("count %s" % suffix, count_of(state, suffix), sung, where))
            expected = "当了武林盟主" if mine >= 5 else "颜违做了盟主" if yan >= 5 else "卫沧澜坐回了椅子" if "卫沧澜出了尚书府" in state.marks else "盟主的椅子还空着"
            if outcomes != [expected]:
                problems.append(("result", outcomes, expected, where))
        self.assertEqual(problems[:8], [])

    def test_the_seating_question_tells_the_day(self):
        """入席's question lists that day's trouble (its ask_lines) as the act then marks it, and who will not come."""
        events = {"神教的杀手": "那天神教截轿", "逆灵宫的余孽": "那天余孽放火", "颜违的人": "那天颜违的人堵路", "兵部的人": "那天兵部请喝茶"}
        rows = [row for row in QUEST.get("checklist", []) if str(row.get("label", "")).startswith("那天山下")]
        problems = []
        for base, _picks, state, end, _log, _before in self.days:
            before = State(base | {"终章", "拿了虹台请柬"})
            told = [entry["line"] for entry in ACT.get("ask_lines", []) if before.holds(entry.get("when"))]
            said = {mark for start, mark in events.items() if any(line.startswith("· " + start) for line in told)}
            happened = {mark for mark in events.values() if mark in state.marks}
            if said != happened or (not happened) != any("太平" in line for line in told):
                problems.append(("ask", sorted(said), sorted(happened)))
            if ("绝尘派肯来" not in base) != any(line.startswith("· 绝尘派不来") for line in told):
                problems.append(("绝尘", told))
            shown = [row["label"] for row in rows if before.holds(row.get("if"))]
            if len(shown) != max(1, len(happened)):
                problems.append(("任务页", shown, sorted(happened)))
        self.assertEqual(problems[:8], [])

    def test_the_morning_and_the_sword_can_be_let_go(self):
        problems = []
        for base, picks, state, end, log, _before in self.days:
            morning = [entry for entry in log if entry[0] == "choose" and entry[1] == CHOOSES[0]]
            if morning and "哪件也不管" not in [text for text, _locked in morning[0][2]]:
                problems.append(("no 哪件也不管", sorted(base)[:12]))
            if picks[CHOOSES[0]] == ["哪件也不管"] and morning:
                held = {"那天神教截轿": "山烟寺没上虹台", "那天余孽放火": "茅山没上虹台", "那天颜违的人堵路": "封山没上虹台", "那天兵部请喝茶": "步玄没上虹台"}
                if any(event in state.marks and absent not in state.marks for event, absent in held.items()):
                    problems.append(("held up but came", sorted(base)[:12]))
            if end == "done" and OVER not in state.marks:
                problems.append(("not closed", sorted(base)[:12]))
            if picks[CHOOSES[5]] == ["我留着"] and "旋芒留在了身上" in state.marks and XUANMANG not in state.items:
                problems.append(("kept but taken", sorted(base)[:12]))
        self.assertEqual(problems[:8], [])

    def test_each_head_says_one_line(self):
        problems = []
        for base, _picks, _state, end, log, _before in self.days:
            if end != "done":
                continue
            spoken = {}
            for kind, who, text in log:
                if kind == "say" and text.startswith("唱票之前"):
                    break
                if kind == "say" and who not in (None, "native.npc.assembly_yan_wei", "native.npc.assembly_wei_canglan", "native.npc.assembly_pan_junchan"):
                    spoken.setdefault(who, []).append(text)
            for who, lines in spoken.items():
                if len(lines) != 1:
                    problems.append((who, lines, sorted(base)[:12]))
        self.assertEqual(problems[:8], [])

    def test_the_stand_lock_reads_can_stand(self):
        problems = []
        for base, _picks, state, end, log, _before in self.days:
            asked = [entry for entry in log if entry[0] == "choose" and entry[1] == CHOOSES[1]]
            if end != "done" or not asked:
                continue
            stand = [locked for text, locked in asked[0][2] if text == STAND]
            if len(stand) != 1:
                problems.append(("stand offered", stand))
                continue
            replay = State(base | {"终章", "拿了虹台请柬", SEATED, "九派到了"} | {m for m in state.marks if m.endswith("没上虹台")})
            if stand[0] == replay.holds({"cond": "assembly.day.can_stand"}):
                problems.append(("lock vs can_stand", stand[0], sorted(base)[:12]))
        self.assertEqual(problems[:8], [])

    def test_every_card_tells_one_lead(self):
        problems = []
        for base, _picks, state, end, _log, _before in self.days:
            if end != "done":
                continue
            told = epilogue(state)
            for card, lines in told.items():
                if not lines:
                    problems.append(("empty", card, sorted(base)[:12]))
                leads = [line for line in lines if line.startswith(CARD_LEADS.get(card, ("\0",)))]
                if card in CARD_LEADS and len(leads) != 1:
                    problems.append(("lead", card, leads, sorted(base)[:12]))
                for who in ("陈剑秋", "柳淳风"):
                    if len([line for line in lines if who in line]) > 1:
                        problems.append(("twice", card, who, lines))
        self.assertEqual(problems[:8], [])

    def test_the_epilogue_says_what_the_platform_said(self):
        problems = []
        for base, _picks, state, end, log, _before in self.days:
            if end != "done":
                continue
            said = " ".join(text for kind, _who, text in log if kind == "say")
            terrace = " ".join(epilogue(state)["terrace"])
            if ("那本账烧了" in said) != ("「那本账烧了」" in terrace):
                problems.append(("账烧了", sorted(base)[:12]))
            if "陈剑秋替振远要了一个说法" in terrace and "今天要一个说法" not in said:
                problems.append(("说法", sorted(base)[:12]))
            snow = " ".join(epilogue(state)["snow"])
            if "封山没上虹台" in state.marks and "封山总算等到了这一天" in snow:
                problems.append(("封山 absent but waiting rewarded", sorted(base)[:12]))
        self.assertEqual(problems[:8], [])

    def test_faction_lists_agree(self):
        """Every list of named conditions `assembly[.day].<faction>.<suffix>` names the factions that have it."""
        pattern = re.compile(r"^assembly\.(day\.)?([a-z]+)\.([a-z_]+)$")
        expected = {}
        for cond_id in CONDS:
            match = pattern.match(cond_id)
            if match and match.group(2) in FACTIONS:
                expected.setdefault((match.group(1) or "", match.group(3)), set()).add(match.group(2))
        problems = []

        def faction_of(part):
            names = set()
            marks_free = []

            def visit(node, _path):
                if "cond" in node:
                    match = pattern.match(node["cond"])
                    if match and match.group(2) in FACTIONS:
                        names.add((match.group(1) or "", match.group(2), match.group(3)))
            walk(part, visit)
            return names, marks_free

        def check_list(parts, where):
            keys = []
            for part in parts:
                names, _ = faction_of(part)
                # a part naming one faction: its vote (the 任务 page's parts also name its `stated`)
                factions = {faction for _day, faction, _suffix in names}
                suffixes = {(day, suffix) for day, _faction, suffix in names if suffix != "stated"}
                if len(factions) != 1 or len(suffixes) != 1:
                    return
                keys.append((next(iter(suffixes)), next(iter(factions))))
            if len(keys) < 3 or len({key for key, _faction in keys}) != 1:
                return
            key = keys[0][0]
            members = [faction for _key, faction in keys]
            if len(members) != len(set(members)) or set(members) != expected.get(key, set()):
                problems.append((where, key, sorted(members), sorted(expected.get(key, set()))))

        def visit(node, path):
            for kind in ("any", "all"):
                if isinstance(node.get(kind), list):
                    check_list(node[kind], path)
            if isinstance(node.get("at_least"), dict):
                check_list(node["at_least"]["of"], path)

        walk(ACT, visit, ("act",))
        walk(_load("story/conditions.json"), visit, ("conditions.json",))
        walk(QUEST, visit, ("faction_assembly.json",))
        self.assertEqual(problems, [])

    def test_the_count_rows_read_the_named_conditions(self):
        rows = {row.get("label"): row.get("when") for row in QUEST.get("checklist", []) if row.get("count")}
        self.assertEqual(rows.get("投颜违"), {"cond": "assembly.yan_wins"})
        self.assertEqual(rows.get("听你的"), {"cond": "assembly.self_backed"})
        stand = next(option for step in ACT["steps"] if "choose" in step for option in step["choose"]["options"] if option["text"] == STAND)
        self.assertIn({"not": {"cond": "assembly.day.can_stand"}}, [lock["when"] for lock in stand.get("locked", [])])

    def test_no_vote_changes_once_seated(self):
        """A 问话 rule that writes a mark the votes read is refused to one seated: it lacks 入席 itself, or an
        earlier rule of its topic answers every seated asker (and writes nothing the votes read)."""
        read = set()
        for faction in FACTIONS:
            for suffix in ("yan", "old", "self"):
                cond_id = "assembly.%s.%s" % (faction, suffix)
                if cond_id in CONDS:
                    marks_read(CONDS[cond_id], read)
        written_by_act = set()
        walk(ACT, lambda node, path: written_by_act.add(node["mark"]) if len(path) >= 2 and path[-2] == "steps" and "mark" in node else None)
        votes = read - written_by_act
        problems = []
        for path in sorted(ROOT.rglob("npcs.json")):
            for npc in json.loads(path.read_text(encoding="utf-8")).get("npcs", []):
                for topic, answer in (npc.get("inquiry") or {}).items():
                    if not isinstance(answer, dict):
                        continue
                    rules = answer.get("rules", [])
                    for position, rule in enumerate(rules):
                        writes = ([rule["mark_asker"]] if "mark_asker" in rule else []) + rule.get("marks_asker", [])
                        if not set(writes) & votes:
                            continue
                        if SEATED in rule.get("asker_lacks", []):
                            continue
                        caught = any(
                            set(earlier.get("asker_marks", [])) <= {SEATED} and SEATED in earlier.get("asker_marks", [])
                            and set(earlier.get("asker_lacks", [])) <= {OVER} and not set(earlier) & {"asker_when", "asker_family", "asker_carries"}
                            and not ({earlier.get("mark_asker")} | set(earlier.get("marks_asker", []))) & votes
                            for earlier in rules[:position])
                        if not caught:
                            problems.append((npc["id"], topic, position, sorted(set(writes) & votes)))
        self.assertEqual(problems, [])
        others = []
        for path in sorted(ROOT.rglob("*.json")):
            if path.name == "conditions.json":
                continue

            def visit(node, where, path=path):
                written = []
                if len(where) >= 2 and where[-2] == "steps":
                    written += [node.get("mark")] + list(node.get("marks", []))
                if where and where[-1] in ("spared", "killed", "reward"):
                    written += [node.get("mark")] + list(node.get("marks", []))
                for key in GIVER_KEYS:
                    value = node.get(key)
                    written += value if isinstance(value, list) else [value]
                for mark in written:
                    if mark in votes and mark not in WRITTEN_BEFORE_SEATING:
                        others.append((str(path.relative_to(ROOT)), "/".join(str(part) for part in where[-5:]), mark))
            walk(json.loads(path.read_text(encoding="utf-8")), visit)
        self.assertEqual(others, [], "a mark the votes read written by something other than a 问话 rule: guard it with 入席 and list it here")


if __name__ == "__main__":
    unittest.main()
