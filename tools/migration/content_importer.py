"""Import ES2 rooms, NPCs, items, spawns and vendors into game/data JSON.

Best effort, never executes LPC: the regular `create()` facts of each object are
read into the record fields of docs/migration/CONTENT_DATA_FORMAT.md. Anything
else (other functions, closures, conditions, facts the game does not model yet)
becomes a *finding* that a person reviews. Decisions live in
tools/migration/overrides/<region>.json and are applied on every run, so the
generated files are never edited by hand:

    python -m tools.migration.content_importer           # write game/data, report
    python -m tools.migration.content_importer --check   # fail on any difference

What each region imports follows from its world.json: the rooms of its zones,
the NPCs and items those rooms place (`set("objects")`), what the NPCs carry
and the goods of the vendors the overrides name. Records already in a file keep their
order (spawn order fixes NPC random draws); new records are appended.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from dataclasses import dataclass, field
from pathlib import Path

from .es2_source import Source, SourceError, Token, lex, pairs


REPOSITORY = Path(__file__).resolve().parents[2]
MUDLIB = REPOSITORY / 'reference/es2/mudlib'
DATA = REPOSITORY / 'game/data'
OVERRIDES = Path(__file__).resolve().parent / 'overrides'
REPORT = REPOSITORY / 'build/import/review.md'

# include/ansi.h colour macros. Colour is presentation; the text is kept.
ANSI_MACROS = {
    'NOR', 'BLK', 'RED', 'GRN', 'YEL', 'BLU', 'MAG', 'CYN', 'WHT', 'HIR', 'HIG', 'HIY',
    'HIB', 'HIM', 'HIC', 'HIW', 'HBRED', 'HBGRN', 'HBYEL', 'HBBLU', 'HBMAG', 'HBCYN',
    'HBWHT', 'BBLK', 'BRED', 'BGRN', 'BYEL', 'BBLU', 'BMAG', 'BCYN', 'BOLD', 'CLR',
    'HOME', 'REF', 'BLINK', 'REV', 'U',
}
# include/globals.h path macros: CLASS_D("swordsman") is "/daemon/class/swordsman".
PATH_MACROS = {'CLASS_D': '/daemon/class/'}
WEAPON_KINDS = {'AXE', 'BLADE', 'DAGGER', 'FORK', 'HAMMER', 'SWORD', 'STAFF', 'THROWING', 'WHIP'}
# std/item/combined.c and what inherits it besides money (std/weapon/throwing.c).
COMBINED_KINDS = {'COMBINED_ITEM', 'THROWING', 'POWDER'}
ARMOR_KINDS = {'ARMOR', 'BOOTS', 'CLOTH', 'FINGER', 'HANDS', 'HEAD', 'NECK', 'SHIELD',
               'SURCOAT', 'WAIST', 'WRISTS'}
# include/weapon.h; only the flags the game models.
WEAPON_FLAGS = {'TWO_HANDED': 'two_handed', 'SECONDARY': 'secondary'}
RACES = {'人类': 'human', '野兽': 'beast'}
ATTRIBUTES = ['str', 'cor', 'int', 'spi', 'cps', 'per', 'con', 'kar']
RESOURCES = [prefix + track for track in ('gin', 'kee', 'sen') for prefix in ('', 'eff_', 'max_')]
# Internal power has no eff_ tier (force, atman, mana).
RESOURCES += [prefix + track for track in ('force', 'atman', 'mana') for prefix in ('', 'max_')]
APPLY_KEYS = ['attack', 'damage', 'armor', 'dodge', 'defense', 'parry']
ATTITUDES = {'peaceful', 'friendly', 'heroism', 'aggressive'}
# NPC fields whose create()-time random draws the loader models.
RANDOM_INTEGER_KEYS = {'set age', 'set combat_exp', 'set score'}
RANDOM_TEXT_KEYS = {'set gender'}
# Bookkeeping calls with no game meaning.
SILENT_CALLS = {'setup', 'seteuid', 'set_default_object', 'replace_program'}
SILENT_ROOM_KEYS = {'no_clean_up', 'valid_startroom'}


class ImportError_(Exception):
    """The importer cannot continue (missing file, unparsable source, bad override)."""


# --- LPC values -------------------------------------------------------------

@dataclass(frozen=True)
class Const:
    """An identifier the importer does not evaluate (DOOR_CLOSED, SECONDARY, __FILE__)."""
    name: str


@dataclass(frozen=True)
class Closure:
    text: str


class ColoredText(str):
    """A string an include/ansi.h macro opens (`CYN "..." NOR`): still the text, and
    `color` names the macro for the fields that keep it (chat lines)."""
    color: str

    def __new__(cls, text: str, color: str) -> 'ColoredText':
        value = super().__new__(cls, text)
        value.color = color
        return value


@dataclass(frozen=True)
class Unknown:
    text: str


@dataclass(frozen=True)
class RandomInt:
    """`base + random(n)` (sign 1) or `base - random(n)` (sign -1)."""
    base: int
    sign: int
    n: int


@dataclass(frozen=True)
class RandomChoice:
    """`if (random(n) < below) set(key, then); else set(key, else_)`."""
    n: int
    below: int
    then: object
    else_: object


def is_plain(value) -> bool:
    """Plain data: str, int, and lists/dicts of plain data."""
    if isinstance(value, (str, int)):
        return True
    if isinstance(value, list):
        return all(is_plain(v) for v in value)
    if isinstance(value, dict):
        return all(isinstance(k, str) and is_plain(v) for k, v in value.items())
    return False


def decode_string(token: Token) -> str:
    """MudOS string escapes. An unknown escape keeps the character and drops the
    backslash (the Big5 conversion left `功\\德`-style escapes; DECISIONS)."""
    escapes = {'n': '\n', 't': '\t', 'r': '\r', '"': '"', '\\': '\\', "'": "'",
               'a': '\a', 'b': '\b', 'f': '\f', 'v': '\v'}
    text, out, i = token.text[1:-1], [], 0
    while i < len(text):
        if text[i] == '\\' and i + 1 < len(text):
            out.append(escapes.get(text[i + 1], text[i + 1]))
            i += 2
        elif text[i] in '\r\n':
            # No LPC string holds a raw line break: the archive's 80-column hard
            # wrap (u/cloud, daemon/class/fighter/celestial) put it there.
            i += 1
        else:
            out.append(text[i])
            i += 1
    return ''.join(out)


def heredoc(token: Token) -> str:
    body = token.text.split('\n', 1)[1]
    return body[:body.rfind('\n') + 1]


# --- LPC objects --------------------------------------------------------------

@dataclass
class Call:
    name: str
    args: list
    chain: list[str]
    chain_args: list = field(default_factory=list)   # the arguments of each chained call


@dataclass
class LpcObject:
    path: str                      # 'd/snow/npc/worker.c'
    inherits: list[str] = field(default_factory=list)
    calls: list[Call] = field(default_factory=list)
    functions: list[str] = field(default_factory=list)
    findings: list[str] = field(default_factory=list)

    @property
    def directory(self) -> str:
        return self.path.rsplit('/', 1)[0] + '/'

    def sets(self) -> dict:
        """`set(key, value)` calls of create(), last one wins, authored order."""
        result = {}
        for call in self.calls:
            if call.name == 'set' and len(call.args) == 2 and isinstance(call.args[0], str):
                result.pop(call.args[0], None)
                result[call.args[0]] = call.args[1]
        return result

    def first(self, name: str) -> Call | None:
        return next((call for call in self.calls if call.name == name), None)


class Parser:
    """Reads one LPC file: its inherits, function names and the calls of create()."""

    def __init__(self, path: str, data: bytes):
        self.object = LpcObject(path)
        self.data = data
        try:
            tokens = lex(Source(path, data))
            self.tokens = [t for t in tokens if t.kind != 'directive']
            self.match = pairs(self.tokens)
        except SourceError as error:
            raise ImportError_(f'{path}: cannot lex ({error})') from error

    def parse(self) -> LpcObject:
        ts, i = self.tokens, 0
        while i < len(ts):
            if ts[i].text == 'inherit':
                stop = self.statement_end(i, len(ts))
                if stop == i + 2 and ts[i + 1].kind == 'identifier':
                    self.object.inherits.append(ts[i + 1].text)
                else:
                    # inherit __DIR__"base"; or "/std/x": the importer cannot tell what it is.
                    self.object.inherits.append(self.text(i + 1, stop))
                    self.object.findings.append('inherit by path: ' + self.text(i + 1, stop))
                i = stop + 1
                continue
            # [modifiers] [type] name ( ... ) { ... }   or a prototype ending in ';'
            j = i
            while j < len(ts) and ts[j].kind == 'identifier' or (j < len(ts) and ts[j].text == '*'):
                j += 1
            if j > i and j < len(ts) and ts[j].text == '(' and ts[j - 1].kind == 'identifier':
                close = self.match.get(j)
                if close is not None and close + 1 < len(ts) and ts[close + 1].text == '{':
                    name, body_end = ts[j - 1].text, self.match[close + 1]
                    if name == 'create':
                        self.statements(close + 2, body_end)
                    else:
                        self.object.functions.append(name)
                    i = body_end + 1
                    continue
            # Global declarations and prototypes: skip to the end of the statement.
            while i < len(ts) and ts[i].text != ';':
                i = self.match.get(i, i) + 1 if ts[i].text in '([{' else i + 1
            i += 1
        return self.object

    # Statements inside create().
    def statements(self, start: int, end: int) -> None:
        i = start
        while i < end:
            i = self.statement(i, end)

    def statement(self, i: int, end: int) -> int:
        ts = self.tokens
        if ts[i].text == ';':
            return i + 1
        if ts[i].text == '{':
            close = self.match[i]
            self.statements(i + 1, close)
            return close + 1
        if ts[i].text == 'if':
            return self.conditional(i, end)
        if ts[i].text in ('for', 'foreach', 'while', 'switch', 'do'):
            # The body ends the statement (`do` also takes its `while (...);`).
            stop = self.branch_end(i + 1 if ts[i].text == 'do' else self.match[i + 1] + 1, end)
            if ts[i].text == 'do':
                stop = self.statement_end(stop, end) + 1
            self.object.findings.append(f'{ts[i].text} in create(): ' + self.text(i, stop))
            return stop
        stop = self.statement_end(i, end)
        call = self.call(i, stop)
        if call is None:
            self.object.findings.append('statement in create(): ' + self.text(i, stop))
        elif call.name not in SILENT_CALLS or getattr(self, 'keep_silent', False):
            self.object.calls.append(call)
        return stop + 1

    def statement_end(self, i: int, end: int) -> int:
        while i < end and self.tokens[i].text != ';':
            i = self.match.get(i, i) + 1 if self.tokens[i].text in '([{' else i + 1
        return i

    def conditional(self, i: int, end: int) -> int:
        ts = self.tokens
        close = self.match[i + 1]
        condition = self.text(i + 2, close)
        then_start = close + 1
        then_end = self.branch_end(then_start, end)
        else_start = else_end = None
        if then_end < end and ts[then_end].text == 'else':
            else_start = then_end + 1
            else_end = self.branch_end(else_start, end)
        after = else_end if else_end is not None else then_end
        if re.fullmatch(r'clonep\s*\(\s*\)', condition):
            # `if (clonep()) set_default_object(__FILE__); else { ...facts... }`
            if any(c.name != 'set_default_object' for c in self.branch_calls(then_start, then_end, keep_silent=True)):
                self.object.findings.append('condition in create(): clonep() branch does more than set_default_object')
            if else_start is not None:
                self.statements(else_start, else_end)
            return after
        chance = re.fullmatch(r'random\s*\(\s*(\d+)\s*\)\s*<\s*(\d+)', condition)
        if chance and else_start is not None:
            then = self.branch_calls(then_start, then_end)
            else_ = self.branch_calls(else_start, else_end)
            if (len(then) == len(else_) == 1 and then[0].name == else_[0].name == 'set'
                    and then[0].args[0] == else_[0].args[0]):
                choice = RandomChoice(int(chance[1]), int(chance[2]), then[0].args[1], else_[0].args[1])
                self.object.calls.append(Call('set', [then[0].args[0], choice], []))
                return after
        self.object.findings.append('condition in create(): if (' + condition + ')')
        return after

    def branch_end(self, start: int, end: int) -> int:
        if self.tokens[start].text == '{':
            return self.match[start] + 1
        if self.tokens[start].text == 'if':
            probe = Parser.__new__(Parser)
            probe.tokens, probe.match, probe.data, probe.object = self.tokens, self.match, self.data, LpcObject('')
            return probe.conditional(start, end)
        return self.statement_end(start, end) + 1

    def branch_calls(self, start: int, end: int, keep_silent: bool = False) -> list[Call]:
        probe = Parser.__new__(Parser)
        probe.tokens, probe.match, probe.data, probe.object = self.tokens, self.match, self.data, LpcObject('')
        probe.keep_silent = keep_silent
        if self.tokens[start].text == '{':
            probe.statements(start + 1, end - 1)
        else:
            probe.statement(start, end)
        if probe.object.findings:
            return [Call('?', [], [])]
        return probe.object.calls

    def call(self, i: int, stop: int) -> Call | None:
        ts = self.tokens
        if ts[i].text == '::':
            i += 1
        if not (ts[i].kind == 'identifier' and i + 1 < stop and ts[i + 1].text == '('):
            return None
        close = self.match[i + 1]
        call = Call(ts[i].text, [self.value(a, b) for a, b in self.arguments(i + 2, close)], [])
        j = close + 1
        while j < stop:
            if not (ts[j].text == '->' and j + 2 < stop and ts[j + 2].text == '('):
                return None
            call.chain.append(ts[j + 1].text)
            call.chain_args.append([self.value(a, b) for a, b in self.arguments(j + 3, self.match[j + 2])])
            j = self.match[j + 2] + 1
        return call

    def arguments(self, start: int, end: int) -> list[tuple[int, int]]:
        parts, i, begin = [], start, start
        while i < end:
            if self.tokens[i].text == ',':
                parts.append((begin, i))
                begin = i + 1
            i = self.match.get(i, i) + 1 if self.tokens[i].text in '([{' else i + 1
        if begin < end:
            parts.append((begin, end))
        return parts

    # Expressions.
    def value(self, start: int, end: int):
        ts = self.tokens
        if end - start == 0:
            return Unknown('')
        if ts[start].text == '(' and self.match.get(start) == end - 1:
            inner = ts[start + 1].text if start + 1 < end else ''
            if inner == '{' and self.match.get(start + 1) == end - 2:
                return [self.value(a, b) for a, b in self.arguments(start + 2, end - 2)]
            if inner == '[' and self.match.get(start + 1) == end - 2:
                return self.mapping(start + 2, end - 2)
            if inner == ':':
                return Closure(self.text(start, end))
            return self.value(start + 1, end - 1)
        if end - start == 2 and ts[start].text == '-' and ts[start + 1].text.isdecimal():
            return -int(ts[start + 1].text)
        random_int = self.random_int(start, end)
        if random_int is not None:
            return random_int
        flags = self.flags(start, end)
        if flags is not None:
            return flags
        # String concatenation: literals, heredocs, __DIR__, colour macros, `+`.
        pieces, i, color = [], start, ''
        while i < end:
            token = ts[i]
            if token.kind == 'string':
                pieces.append(decode_string(token))
            elif token.kind == 'heredoc':
                pieces.append(heredoc(token))
            elif token.text == '__DIR__':
                pieces.append('/' + self.object.directory)
            elif (token.text in PATH_MACROS and i + 3 < end and ts[i + 1].text == '('
                    and ts[i + 2].kind == 'string' and ts[i + 3].text == ')'):
                pieces.append(PATH_MACROS[token.text] + decode_string(ts[i + 2]))
                i += 4
                continue
            elif token.text in ANSI_MACROS:
                # The macro that opens the text is its colour.
                if not color and not ''.join(pieces) and token.text != 'NOR':
                    color = token.text
                pieces.append('')
            elif token.text == '+' and pieces:
                pass
            elif token.kind == 'number' and end - start == 1:
                return int(token.text) if token.text.isdecimal() else Unknown(token.text)
            elif token.kind == 'identifier' and end - start == 1:
                return Const(token.text)
            else:
                return Unknown(self.text(start, end))
            i += 1
        return ColoredText(''.join(pieces), color) if color else ''.join(pieces)

    def mapping(self, start: int, end: int) -> dict | Unknown:
        result = {}
        for a, b in self.arguments(start, end):
            colon = next((k for k in range(a, b) if self.tokens[k].text == ':'), None)
            if colon is None:
                return Unknown(self.text(start, end))
            result[self.value(a, colon)] = self.value(colon + 1, b)
        return result

    def random_int(self, start: int, end: int) -> RandomInt | None:
        text = self.text(start, end)
        match = re.fullmatch(r'\(?\s*(\d+)\s*([+-])\s*random\s*\(\s*(\d+)\s*\)\s*\)?', text)
        if match:
            return RandomInt(int(match[1]), 1 if match[2] == '+' else -1, int(match[3]))
        match = re.fullmatch(r'\(?\s*random\s*\(\s*(\d+)\s*\)\s*\+\s*(\d+)\s*\)?', text)
        if match:
            return RandomInt(int(match[2]), 1, int(match[1]))
        return None

    def flags(self, start: int, end: int) -> list[Const] | None:
        names = [t.text for t in self.tokens[start:end]]
        if len(names) >= 3 and all(n == '|' for n in names[1::2]) and all(n.isupper() for n in names[0::2]):
            return [Const(n) for n in names[0::2]]
        return None

    def text(self, start: int, end: int) -> str:
        """The authored source of tokens [start, end), whitespace collapsed."""
        if start >= end:
            return ''
        raw = self.data[self.tokens[start].start:self.tokens[end - 1].end].decode('utf-8')
        return ' '.join(raw.split())


# --- Paths and IDs ------------------------------------------------------------

def source_path(lpc_path: str) -> str:
    """'/d/snow/npc/dog' or 'd/snow/npc/dog.c' -> 'd/snow/npc/dog.c'."""
    path = lpc_path.lstrip('/')
    return path if path.endswith('.c') else path + '.c'


def es2_id(path: str) -> str:
    return 'es2:' + source_path(path).removesuffix('.c')


def basename(path: str) -> str:
    return source_path(path).rsplit('/', 1)[-1].removesuffix('.c')


def region_of(path: str) -> str:
    """`d/<region>/...`; u/cloud is a whole town (绮云镇, region `cloud`, 卧龙岗 included)
    and its sunhill subdirectory the south bank; anything else is `common`."""
    parts = source_path(path).split('/')
    if parts[0] == 'd' and len(parts) > 2:
        return parts[1]
    if parts[:2] == ['u', 'cloud'] and len(parts) > 2:
        return 'sunhill' if parts[2] == 'sunhill' else 'cloud'
    return 'common'


def npc_id(path: str) -> str:
    """`snow.npc.dog`; a class daemon's NPC keeps its class: `common.npc.swordsman.master`."""
    parts = source_path(path).split('/')
    if parts[:2] == ['daemon', 'class'] and len(parts) == 4:
        return f'common.npc.{parts[2]}.{basename(path)}'
    return f'{region_of(path)}.npc.{basename(path)}'


class Corpus:
    """Parsed LPC objects by source path, read on demand."""

    def __init__(self, mudlib: Path = MUDLIB):
        self.mudlib = mudlib
        self.cache: dict[str, LpcObject] = {}

    def exists(self, path: str) -> bool:
        return (self.mudlib / source_path(path)).is_file()

    def get(self, path: str) -> LpcObject:
        path = source_path(path)
        if path not in self.cache:
            file = self.mudlib / path
            if not file.is_file():
                raise ImportError_(f'missing LPC file {path}')
            self.cache[path] = Parser(path, file.read_bytes()).parse()
        return self.cache[path]

    def same_bytes(self, left: str, right: str) -> bool:
        a, b = self.mudlib / source_path(left), self.mudlib / source_path(right)
        return a.is_file() and b.is_file() and a.read_bytes() == b.read_bytes()


# --- Records ------------------------------------------------------------------

@dataclass
class Finding:
    """An LPC fact the importer did not turn into data. `key` is what a review
    decision names (`set chat_msg`, `function accept_object`); `detail` shows it."""
    source: str
    key: str
    detail: str = ''


class Importer:
    def __init__(self, corpus: Corpus, data: Path = DATA, overrides: Path = OVERRIDES):
        self.corpus = corpus
        self.data = data
        self.overrides = {p.stem: json.loads(p.read_text(encoding='utf-8'))
                          for p in sorted(overrides.glob('*.json'))}
        # An NPC a region names as a vendor sells from its body (`vendor` on its record).
        self.vendor_paths = {source_path(v) for o in self.overrides.values() for v in o.get('vendors', [])}
        self.records: dict[str, dict[str, dict]] = {}   # file -> id -> record
        self.findings: list[Finding] = []
        self.generated_fields: dict[str, int] = {}       # record id -> fields read from LPC
        self.override_fields: dict[str, int] = {}        # record id -> fields set/dropped by hand

    def add(self, file: str, record: dict) -> None:
        bucket = self.records.setdefault(file, {})
        if record['id'] not in bucket:
            bucket[record['id']] = record
            self.generated_fields[record['id']] = len(record)

    def item_record(self, record_id: str) -> dict:
        return next((bucket[record_id] for bucket in self.records.values() if record_id in bucket), {})

    def note(self, source: str, key: str, detail: str = '') -> None:
        source = source_path(source)
        if not any(f.source == source and f.key == key for f in self.findings):
            self.findings.append(Finding(source, key, detail))

    def run(self) -> None:
        for region, override in self.overrides.items():
            if region != 'common':
                world = json.loads((self.data / region / 'world.json').read_text(encoding='utf-8'))
                self.import_region(region, world, override)
        for path in self.overrides.get('common', {}).get('items', []):
            self.item(path)
        self.apply_overrides()

    def import_region(self, region: str, world: dict, override: dict) -> None:
        skips = {(source_path(room), source_path(target))
                 for room, targets in override.get('spawn_skip', {}).items() for target in targets}
        used = set()
        for zone in world.get('zones', []):
            for room_id in zone['rooms']:
                room_path = source_path(room_id.removeprefix('es2:'))
                self.add(f'{region}/rooms.json', self.room(room_path))
                objects = self.corpus.get(room_path).sets().get('objects', {})
                for target, quantity in (objects.items() if isinstance(objects, dict) else []):
                    if not isinstance(target, str):
                        self.note(room_path, 'objects', describe(target))
                    elif (room_path, source_path(target)) in skips:
                        used.add((room_path, source_path(target)))
                    else:
                        self.spawn(region, zone, room_path, source_path(target), quantity)
        for room, target in sorted(skips - used):
            raise ImportError_(f'overrides/{region}.json: spawn_skip {room} {target} matches no room object')
        hand_read = override.get('vendor_goods', {})
        for path in set(hand_read) - set(override.get('vendors', [])):
            raise ImportError_(f'overrides/{region}.json: vendor_goods {path} is not in vendors')
        for vendor in override.get('vendors', []):
            self.vendor(region, vendor, override.get('vendor_skip', {}).get(vendor, {}), hand_read.get(vendor))
        for path in override.get('items', []):
            self.item(path)
        # NPCs that code makes instead of a room (house3.c call_spider()).
        for path in override.get('npcs', []):
            self.npc(path)

    # Rooms.
    def room(self, path: str) -> dict:
        lpc = self.corpus.get(path)
        sets = lpc.sets()
        record = {'id': es2_id(path), 'short': sets.get('short'), 'long': sets.get('long')}
        exits = sets.get('exits', {})
        if isinstance(exits, dict) and not all(isinstance(t, str) for t in exits.values()):
            self.note(path, 'exits', describe(exits))
            exits = {d: t for d, t in exits.items() if isinstance(t, str)}
        if exits:
            record['exits'] = {d: es2_id(t) for d, t in exits.items()}
        # cmds/std/kill.c, fight.c: "这里不准战斗。"
        if sets.get('no_fight', 0) != 0:
            record['no_fight'] = True
        # rope.c hang_self(): set("outdoors") (any area name) means under the open sky.
        if sets.get('outdoors', 0) not in (0, None):
            record['outdoors'] = True
        for key, value in sets.items():
            if key == 'item_desc':
                self.note(path, 'set item_desc', ', '.join(map(str, value)) if isinstance(value, dict) else describe(value))
            elif key not in ('short', 'long', 'exits', 'objects', 'no_fight', 'outdoors') and key not in SILENT_ROOM_KEYS:
                self.note(path, f'set {key}', describe(value))
        for call in lpc.calls:
            if call.name != 'set':
                self.note(path, call.name, describe(call.args))
        self.function_findings(path, lpc)
        return record

    # Spawns, NPCs and items lying in rooms.
    def spawn(self, region: str, zone: dict, room_path: str, target: str, quantity) -> None:
        """An NPC spawn (`spawns`), or an item on the floor (`item_spawns`, room.c make_inventory())."""
        if not self.corpus.exists(target):
            self.note(room_path, f'objects {target}', 'file does not exist')
            return
        if not isinstance(quantity, int) or quantity < 1:
            self.note(room_path, f'objects {target}', f'quantity {describe(quantity)}')
            return
        is_npc = 'NPC' in self.corpus.get(target).inherits
        room_name, name = basename(room_path), basename(target)
        prefix = zone['id'] if zone['id'].rsplit('.', 1)[-1] == room_name else f"{zone['id']}.{room_name}"
        record = {
            'id': (zone['map'] if zone['map'].rsplit('.', 1)[-1] == room_name else f"{zone['map']}.{room_name}")
                  + f".{name}{'s' if quantity > 1 else ''}",
            'npc' if is_npc else 'item': self.npc(target) if is_npc else self.item(target),
            'map': zone['map'],
            'zone': zone['id'],
            'points': [f'{prefix}.{name}.{n}' for n in range(1, quantity + 1)],
            'legacy_room': room_path,
            'legacy_quantity': quantity,
        }
        self.add(f"{region}/{'spawns' if is_npc else 'item_spawns'}.json", record)

    def npc(self, path: str) -> str:
        record_id = npc_id(path)
        file = f'{region_of(path)}/npcs.json'
        if record_id in self.records.get(file, {}):
            return record_id
        lpc = self.corpus.get(path)
        sets = lpc.sets()
        name = lpc.first('set_name')
        if name is None or len(name.args) != 2 or not is_plain(name.args):
            raise ImportError_(f'{path}: no plain set_name()')
        record: dict = {'id': record_id, 'legacy_source': path, 'name': name.args[0], 'aliases': name.args[1]}
        handled = set()

        def take(key: str, field: str | None = None) -> None:
            if key in sets:
                handled.add(key)
                value = self.authored(path, f'set {key}', sets[key])
                if value is not None:
                    record[field or key] = value

        take('nickname')
        take('title')
        if 'race' in sets:
            handled.add('race')
            if sets['race'] not in RACES:
                self.note(path, 'set race', describe(sets['race']))
            elif RACES[sets['race']] != 'human':
                record['race'] = RACES[sets['race']]
        for key in ('gender', 'age', 'long'):
            take(key)
        for group, keys in (('attributes', ATTRIBUTES), ('resources', RESOURCES)):
            values = {k: self.authored(path, f'set {k}', v) for k, v in sets.items() if k in keys}
            handled.update(values)
            values = {k: v for k, v in values.items() if v is not None}
            if values:
                record[group] = values
        take('combat_exp')
        take('score')
        take('bellicosity')
        # attack.c init(): attacks whoever holds vendetta/<mark> (killer_reward() gives it).
        take('vendetta_mark')
        take('force_factor')
        # rankd.c query_respect(): how others address this NPC.
        if isinstance(sets.get('rank_info/respect'), str):
            handled.add('rank_info/respect')
            record['rank_info'] = {'respect': sets['rank_info/respect']}
        # feature/apprentice.c create_family(name, generation, title); privs -1.
        family = lpc.first('create_family')
        if family is not None and len(family.args) == 3 and is_plain(family.args):
            record['family'] = {'name': family.args[0], 'generation': family.args[1], 'title': family.args[2]}
        elif family is not None:
            self.note(path, 'create_family', describe(family.args))
        # std/char/master.c prevent_learn(): limits what a master teaches.
        if 'F_MASTER' in lpc.inherits:
            record['f_master'] = True
        if path in self.vendor_paths:
            # Its goods are the vendors[] record (vendor()); buy.c needs the vendor present.
            handled.add('vendor_goods')
            record['vendor'] = f'{region_of(path)}.vendor.{basename(path)}'
        if 'attitude' in sets:
            handled.add('attitude')
            if sets['attitude'] in ATTITUDES:
                record['attitude'] = sets['attitude']
            else:
                self.note(path, 'set attitude', describe(sets['attitude']))
        skills = {c.args[0]: self.authored(path, f'set_skill {c.args[0]}', c.args[1])
                  for c in lpc.calls if c.name == 'set_skill'}
        skills = {k: v for k, v in skills.items() if v is not None}
        if skills:
            record['skills'] = skills
        skill_map = {c.args[0]: c.args[1] for c in lpc.calls if c.name == 'map_skill' and is_plain(c.args)}
        if skill_map:
            record['skill_map'] = skill_map
        carry = []
        for call in lpc.calls:
            if call.name == 'carry_object' and isinstance(call.args[0], str):
                item_source = source_path(call.args[0])
                entry = {'item': self.item(item_source), 'source': item_source}
                equip = [c for c in call.chain if c in ('wield', 'wear')]
                if equip:
                    entry['equip'] = equip[0]
                # ->set_amount(n) on a combined item; else the amount its create() sets.
                amounts = [args[0] for c, args in zip(call.chain, call.chain_args)
                           if c == 'set_amount' and len(args) == 1 and type(args[0]) is int]
                combined = self.item_record(entry['item']).get('combined')
                if combined is not None:
                    entry['amount'] = amounts[-1] if amounts else combined['amount']
                if len(call.chain) != len(equip) + (len(amounts) if combined is not None else 0):
                    self.note(path, 'carry_object chain', f'{item_source} -> {call.chain}')
                carry.append(entry)
            elif call.name == 'add_money' and len(call.args) == 2 and is_plain(call.args):
                money = f'obj/money/{call.args[0]}.c'
                carry.append({'item': self.item(money), 'source': money, 'amount': call.args[1]})
            elif call.name in ('carry_object', 'add_money'):
                self.note(path, call.name, describe(call.args))
        if carry:
            record['carry'] = carry
        take('limbs')
        take('verbs')
        apply = {}
        for call in lpc.calls:
            if call.name != 'set_temp':
                continue
            key = str(call.args[0])
            if key.startswith('apply/') and key.removeprefix('apply/') in APPLY_KEYS:
                value = self.authored(path, f'set_temp {key}', call.args[1])
                if value is not None:
                    apply[key.removeprefix('apply/')] = value
            else:
                self.note(path, f'set_temp {key}', describe(call.args[1:]))
        if apply:
            record['apply'] = apply
        if record.get('attitude') == 'aggressive':
            record['capabilities'] = ['aggressive_on_player_presence']
        handled.update(self.chat(path, sets, record))
        handled.update(self.inquiry(path, sets, record))
        for call in lpc.calls:
            if call.name not in {'set', 'set_name', 'set_skill', 'map_skill', 'carry_object', 'add_money', 'set_temp', 'create_family'}:
                self.note(path, call.name, describe(call.args))
        for key, value in sets.items():
            if key not in handled:
                self.note(path, f'set {key}', describe(value))
        self.function_findings(path, lpc)
        self.add(file, record)
        return record_id

    @staticmethod
    def chat(path: str, sets: dict, record: dict) -> set[str]:
        """npc.c chat(): `chat_chance` and `chat_msg`, in a fight `chat_chance_combat`
        and `chat_msg_combat`. Entries are lines (a coloured one as {"say", "color"}),
        `(: random_move :)`, npc.c's perform_action, cast_spell and exert_function, and
        `(: command, "surrender" :)`. Both keys stay findings unless every entry is data:
        dropping one would change `random(sizeof(msg))`; a chance without lines never fires."""
        handled = set()
        for chance_key, lines_key in (('chat_chance', 'chat_msg'), ('chat_chance_combat', 'chat_msg_combat')):
            chance, lines = sets.get(chance_key), sets.get(lines_key)
            if not isinstance(chance, int) or not isinstance(lines, list) or not lines:
                continue
            entries = [Importer.chat_entry(line, lines_key == 'chat_msg_combat') for line in lines]
            if None in entries:
                continue
            record[chance_key] = chance
            record[lines_key] = entries
            handled |= {chance_key, lines_key}
        return handled

    @staticmethod
    def chat_entry(line, in_fight: bool) -> str | dict | None:
        """One entry as data, or None. random_move is data only outside a fight (the
        game moves no NPC out of one yet)."""
        if isinstance(line, ColoredText):
            return {'say': str(line), 'color': line.color}
        if isinstance(line, str):
            return line
        if isinstance(line, Closure) and ''.join(line.text.split()) == '(:random_move:)':
            return None if in_fight else {'action': 'random_move'}
        match = re.fullmatch(r'\(:\s*(perform_action|cast_spell|exert_function|command)\s*,\s*"([^"]+)"\s*:\)',
                             line.text if isinstance(line, Closure) else '')
        if match is None:
            return None
        function, argument = match.groups()
        if function == 'perform_action':
            skill, _, action = argument.partition('.')
            return {'action': 'perform', 'skill': skill, 'function': action} if action else None
        if function == 'command':
            return {'action': argument} if argument == 'surrender' else None
        return {'action': 'cast' if function == 'cast_spell' else 'exert', 'function': argument}

    def inquiry(self, path: str, sets: dict, record: dict) -> set[str]:
        """ask.c answers: a string, or an array whose strings are said in turn (ask.c
        skips 0 and does nothing with a function in it). A topic answered by a
        function is a finding `inquiry <topic>`."""
        topics = sets.get('inquiry')
        if not isinstance(topics, dict):
            return set()
        answers = {}
        for topic, answer in topics.items():
            if isinstance(answer, str):
                answers[topic] = [answer]
            elif isinstance(answer, list) and all(isinstance(a, (str, int, Closure)) for a in answer):
                answers[topic] = [a for a in answer if isinstance(a, str)]
                for function in (a for a in answer if isinstance(a, Closure)):
                    self.note(path, f'inquiry {topic}', describe(function))
            else:
                self.note(path, f'inquiry {topic}', describe(answer))
        if answers:
            record['inquiry'] = answers
        return {'inquiry'}

    def authored(self, path: str, key: str, value):
        """A plain value, or one of the random forms the loader models; else a finding."""
        if isinstance(value, RandomInt) and key in RANDOM_INTEGER_KEYS:
            return {'base': value.base, 'plus_random' if value.sign > 0 else 'minus_random': value.n}
        if isinstance(value, RandomChoice) and key in RANDOM_TEXT_KEYS and is_plain([value.then, value.else_]):
            return {'random': value.n, 'below': value.below, 'then': value.then, 'else': value.else_}
        if is_plain(value):
            return value
        self.note(path, key, describe(value))
        return None

    def function_findings(self, path: str, lpc: LpcObject) -> None:
        for finding in lpc.findings:
            key, _, detail = finding.partition(': ')
            self.note(path, key, detail)
        for name in lpc.functions:
            self.note(path, f'function {name}')

    # Items.
    def item(self, path: str) -> str:
        canonical, copies = self.canonical_item(source_path(path))
        record_id = es2_id(canonical)
        file = f'{region_of(canonical)}/items.json'
        if record_id in self.records.get(file, {}):
            return record_id
        lpc = self.corpus.get(canonical)
        sets = lpc.sets()
        name = lpc.first('set_name')
        if name is None or not is_plain(name.args):
            raise ImportError_(f'{canonical}: no plain set_name()')
        record: dict = {'id': record_id, 'legacy_sources': [canonical, *copies], 'name': name.args[0]}
        if len(name.args) > 1:
            record['aliases'] = name.args[1]
        handled = {'long', 'unit', 'material', 'value', 'no_get'}
        for key in ('long', 'unit', 'material'):
            if key in sets:
                record[key] = sets[key]
        if sets.get('no_get', 0) != 0:
            record['no_get'] = True
        # cmds/std/wear.c: only a 女性 character wears it.
        if sets.get('female_only', 0) != 0:
            handled.add('female_only')
            record['female_only'] = True
        # cmds/std/study.c: set("skill", ([name, exp_required, sen_cost, difficulty, max_skill])).
        study = sets.get('skill')
        if isinstance(study, dict) and isinstance(study.get('name'), str):
            handled.add('skill')
            record['study'] = {'skill': study['name'], **{k: study[k] for k in (
                'exp_required', 'sen_cost', 'difficulty', 'max_skill') if k in study}}
        inherits = set(lpc.inherits)
        weapon_kinds = sorted({k.removeprefix('F_') for k in inherits} & WEAPON_KINDS)
        armor_kinds = sorted(inherits & ARMOR_KINDS)
        weight = lpc.first('set_weight')
        combined_kinds = inherits & COMBINED_KINDS
        if 'MONEY' not in inherits and not combined_kinds:
            # feature/move.c: `static int weight = 0;` until set_weight().
            record['weight'] = 0 if weight is None else weight.args[0]
        if 'value' in sets:
            record['value'] = sets['value']
        # feature/move.c: a container holds up to set_max_encumbrance() (put in, get from).
        capacity = lpc.first('set_max_encumbrance')
        if capacity is not None and len(capacity.args) == 1 and type(capacity.args[0]) is int:
            record['max_encumbrance'] = capacity.args[0]
        init_name = ''
        amount = lpc.first('set_amount')
        if combined_kinds:
            # combined.c: weight = amount * base_weight; create()'s set_amount() is the
            # amount a new one has. base_value is read only by std/money.c's value().
            handled.update(('base_unit', 'base_weight', 'base_value'))
            record['combined'] = {'base_unit': sets.get('base_unit'), 'base_weight': sets.get('base_weight', 0),
                                  'amount': amount.args[0] if amount is not None and amount.args else 1}
        if weapon_kinds:
            kind = weapon_kinds[0]
            init_name = 'init_' + kind.lower()
            init = lpc.first(init_name)
            if init is None:
                self.note(canonical, init_name, 'missing')
            else:
                weapon = {'skill': kind.lower(), 'damage': init.args[0]}
                # equip.c wield(): weapon_prop/* other than damage become the wielder's apply/*.
                apply = {k.removeprefix('weapon_prop/'): v for k, v in sets.items()
                         if k.startswith('weapon_prop/') and k != 'weapon_prop/damage'}
                handled.update('weapon_prop/' + k for k in apply)
                if apply:
                    weapon['apply'] = apply
                flags = init.args[1] if len(init.args) > 1 else []
                names = []
                for flag in flags if isinstance(flags, list) else [flags]:
                    if isinstance(flag, Const) and flag.name in WEAPON_FLAGS:
                        names.append(WEAPON_FLAGS[flag.name])
                    else:
                        self.note(canonical, 'weapon flag', describe(flag))
                if names:
                    weapon['flags'] = names
                record['weapon'] = weapon
        elif armor_kinds or ('EQUIP' in inherits and isinstance(sets.get('armor_type'), str)):
            # std/armor/<kind>.c sets armor_type; an EQUIP sets it itself (armor.h TYPE_*).
            props = {k.removeprefix('armor_prop/'): v for k, v in sets.items() if k.startswith('armor_prop/')}
            handled.update('armor_prop/' + k for k in props)
            handled.add('armor_type')
            record['armor'] = {'type': armor_kinds[0].lower() if armor_kinds else sets['armor_type'], 'props': props}
        elif 'MONEY' in inherits:
            keys = ('money_id', 'base_value', 'base_unit', 'base_weight')
            handled.update(keys)
            record['money'] = {k: sets[k] for k in keys if k in sets}
        elif 'F_FOOD' in inherits:
            handled.update(('food_remaining', 'food_supply'))
            record['food'] = {'remaining': sets.get('food_remaining'), 'supply': sets.get('food_supply')}
        elif 'F_LIQUID' in inherits:
            handled.update(('max_liquid', 'liquid'))
            record['liquid'] = {'max_liquid': sets.get('max_liquid'), **sets.get('liquid', {})}
        modelled = {'ITEM', 'MONEY', 'F_FOOD', 'F_LIQUID', *armor_kinds, *weapon_kinds, *combined_kinds,
                    *(['EQUIP'] if 'armor' in record and not armor_kinds else []),
                    *('F_' + k for k in weapon_kinds)}
        for kind in sorted(inherits - modelled):
            self.note(canonical, f'inherit {kind}')
        for call in lpc.calls:
            if call.name not in {'set', 'set_name', 'set_weight', init_name} and not (
                    call.name == 'set_amount' and ('combined' in record or 'money' in record)) and not (
                    call.name == 'set_max_encumbrance' and 'max_encumbrance' in record):
                self.note(canonical, call.name, describe(call.args))
        for key, value in sets.items():
            if key not in handled:
                self.note(canonical, f'set {key}', describe(value))
        self.function_findings(canonical, lpc)
        self.add(file, record)
        return record_id

    def canonical_item(self, path: str) -> tuple[str, list[str]]:
        """`d/x/npc/obj/f.c` byte-identical to `d/x/obj/f.c` is one item named by the obj/ file."""
        if '/npc/obj/' in path:
            primary = path.replace('/npc/obj/', '/obj/')
            return (primary, [path]) if self.corpus.same_bytes(primary, path) else (path, [])
        if path.startswith('d/') and '/obj/' in path:
            copy = path.replace('/obj/', '/npc/obj/', 1)
            if self.corpus.same_bytes(path, copy):
                return path, [copy]
        return path, []

    # Vendors.
    def vendor(self, region: str, path: str, skipped: dict, hand_read: dict | None = None) -> None:
        """`set("vendor_goods")` (feature/vendor.c), or goods read by hand from the
        vendor's own buy_object() (override `vendor_goods`: {key: {item, price}})."""
        path = source_path(path)
        lpc_goods = self.corpus.get(path).sets().get('vendor_goods')
        if hand_read is not None:
            if lpc_goods is not None:
                raise ImportError_(f'vendor_goods {path}: the LPC sets vendor_goods; read it, not a hand list')
            for key, entry in hand_read.items():
                if (not isinstance(entry, dict) or set(entry) - {'item', 'price'} or not isinstance(entry.get('item'), str)
                        or ('price' in entry and (type(entry['price']) is not int or entry['price'] < 1))):
                    raise ImportError_(f'vendor_goods {path} {key!r}: expected {{"item": path, "price"?: integer >= 1}}')
            goods = {key: entry['item'] for key, entry in hand_read.items()}
        else:
            goods = lpc_goods
        if not isinstance(goods, dict):
            raise ImportError_(f'{path}: no vendor_goods mapping')
        for key in set(skipped) - set(goods):
            raise ImportError_(f'vendor_skip {path} {key!r} is not one of its goods')
        records = []
        for key, item in goods.items():
            if key in skipped:
                continue
            record = {'key': key, 'item': self.item(item)}
            if hand_read is not None and 'price' in hand_read[key]:
                record['price'] = hand_read[key]['price']
            records.append(record)
        self.add(f'{region}/vendors.json', {
            'id': f'{region_of(path)}.vendor.{basename(path)}',
            'legacy_source': path,
            'goods': records,
        })

    # Overrides: "set": {id: {field: value}}, "drop": {id: [field]}.
    def apply_overrides(self) -> None:
        index = {rid: record for bucket in self.records.values() for rid, record in bucket.items()}
        for region, override in self.overrides.items():
            for rid, fields in override.get('set', {}).items():
                if rid not in index:
                    raise ImportError_(f'overrides/{region}.json: set names unknown record {rid}')
                index[rid].update(fields)
                self.override_fields[rid] = self.override_fields.get(rid, 0) + len(fields)
            for rid, names in override.get('drop', {}).items():
                if rid not in index:
                    raise ImportError_(f'overrides/{region}.json: drop names unknown record {rid}')
                for name in names:
                    if index[rid].pop(name, None) is None:
                        raise ImportError_(f'overrides/{region}.json: drop {rid}.{name} is not generated')
                self.override_fields[rid] = self.override_fields.get(rid, 0) + len(names)

    def decisions(self) -> dict[tuple[str, str], str]:
        """Review decisions: "review": {source: {finding key: decision}}."""
        result = {}
        for override in self.overrides.values():
            for source, decisions in override.get('review', {}).items():
                for key, decision in decisions.items():
                    result[(source_path(source), key)] = decision
        return result


def describe(value) -> str:
    if isinstance(value, Const):
        return value.name
    if isinstance(value, (Closure, Unknown)):
        return value.text
    if isinstance(value, RandomInt):
        return f'{value.base} {"+" if value.sign > 0 else "-"} random({value.n})'
    if isinstance(value, RandomChoice):
        return f'random({value.n}) < {value.below} ? {describe(value.then)} : {describe(value.else_)}'
    if isinstance(value, list):
        return '({ ' + ', '.join(describe(v) for v in value) + ' })'
    if isinstance(value, dict):
        return '([ ' + ', '.join(f'{describe(k)}: {describe(v)}' for k, v in value.items()) + ' ])'
    return json.dumps(value, ensure_ascii=False)


# --- Output ---------------------------------------------------------------------

ALWAYS_MULTILINE = {'exits'}
WIDTH = 120


def inline(value) -> str:
    if isinstance(value, dict):
        if not value:
            return '{}'
        return '{ ' + ', '.join(f'{json.dumps(k, ensure_ascii=False)}: {inline(v)}' for k, v in value.items()) + ' }'
    if isinstance(value, list):
        return '[' + ', '.join(inline(v) for v in value) + ']'
    return json.dumps(value, ensure_ascii=False)


def field_text(key: str, value, depth: int) -> str:
    """One field of a record: inline when it fits, else one element per line."""
    pad = '\t' * depth
    head = f'{pad}{json.dumps(key, ensure_ascii=False)}: '
    if isinstance(value, list) and value and all(isinstance(v, dict) for v in value):
        items = ',\n'.join('\t' * (depth + 1) + inline(v) for v in value)
        return f'{head}[\n{items}\n{pad}]'
    one_line = head + inline(value)
    if not isinstance(value, (list, dict)) or (key not in ALWAYS_MULTILINE and len(one_line.expandtabs(4)) <= WIDTH):
        return one_line
    if isinstance(value, dict):
        body = ',\n'.join(field_text(k, v, depth + 1) for k, v in value.items())
        return f'{head}{{\n{body}\n{pad}}}'
    items = ',\n'.join('\t' * (depth + 1) + inline(v) for v in value)
    return f'{head}[\n{items}\n{pad}]'


def render(kind: str, records: list[dict]) -> str:
    blocks = ['\t\t{\n' + ',\n'.join(field_text(k, v, 3) for k, v in r.items()) + '\n\t\t}' for r in records]
    return '{\n\t"' + kind + '": [\n' + ',\n'.join(blocks) + '\n\t]\n}\n'


def outputs(importer: Importer, data: Path = DATA) -> dict[str, str]:
    """File (relative to game/data) -> generated text. Existing records keep their order."""
    result = {}
    for file, records in sorted(importer.records.items()):
        kind = file.rsplit('/', 1)[-1].removesuffix('.json')
        existing = data / file
        order = []
        if existing.is_file():
            order = [r['id'] for r in json.loads(existing.read_text(encoding='utf-8')).get(kind, [])]
        ids = [rid for rid in order if rid in records] + [rid for rid in records if rid not in order]
        result[file] = render(kind, [records[rid] for rid in ids])
    return result


def open_findings(importer: Importer) -> list[Finding]:
    decisions = importer.decisions()
    return [f for f in importer.findings if (f.source, f.key) not in decisions]


def stale_decisions(importer: Importer) -> list[tuple[str, str]]:
    return sorted(set(importer.decisions()) - {(f.source, f.key) for f in importer.findings})


def review_report(importer: Importer) -> str:
    decisions = importer.decisions()
    lines = ['# Content import review', '',
             'Generated by `python -m tools.migration.content_importer`. Findings are LPC facts that',
             'did not become data. Decide each in `tools/migration/overrides/<region>.json` (`review`).', '',
             '## NPC records', '',
             '| NPC | fields from LPC | override fields | findings |', '|---|---|---|---|']
    for file, records in sorted(importer.records.items()):
        if file.endswith('/npcs.json'):
            for rid, record in records.items():
                count = sum(1 for f in importer.findings if f.source == record['legacy_source'])
                lines.append(f"| {rid} | {importer.generated_fields[rid] - 2} | "
                             f"{importer.override_fields.get(rid, 0)} | {count} |")
    lines.append('')
    by_source: dict[str, list[Finding]] = {}
    for finding in importer.findings:
        by_source.setdefault(finding.source, []).append(finding)
    for source in sorted(by_source):
        lines.append(f'## {source}')
        for f in by_source[source]:
            decision = decisions.get((f.source, f.key), '**OPEN**')
            detail = f' `{f.detail[:200]}`' if f.detail else ''
            lines.append(f'- `{f.key}`{detail} — {decision}')
        lines.append('')
    return '\n'.join(lines)


def generate(mudlib: Path = MUDLIB, data: Path = DATA, overrides: Path = OVERRIDES) -> tuple[Importer, dict[str, str]]:
    importer = Importer(Corpus(mudlib), data, overrides)
    importer.run()
    return importer, outputs(importer, data)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.split('\n\n', 1)[0])
    parser.add_argument('--check', action='store_true', help='compare instead of writing; exit 1 on any difference')
    args = parser.parse_args(argv)
    try:
        importer, files = generate()
    except ImportError_ as error:
        print(f'content_importer: {error}', file=sys.stderr)
        return 2
    changed = [f for f, text in files.items()
               if not (DATA / f).is_file() or (DATA / f).read_text(encoding='utf-8') != text]
    for f in changed:
        if args.check:
            print(f'differs: game/data/{f}')
        else:
            (DATA / f).write_text(files[f], encoding='utf-8', newline='\n')
            print(f'wrote game/data/{f}')
    REPORT.parent.mkdir(parents=True, exist_ok=True)
    REPORT.write_text(review_report(importer), encoding='utf-8', newline='\n')
    unresolved = open_findings(importer)
    stale = stale_decisions(importer)
    for f in unresolved:
        print(f'open finding: {f.source}: {f.key} {f.detail[:120]}')
    for source, key in stale:
        print(f'stale review decision: {source}: {key}')
    print(f'{len(files)} files, {len(importer.findings)} findings, {len(unresolved)} open; '
          f'report: {REPORT.relative_to(REPOSITORY).as_posix()}')
    return 1 if (args.check and changed) or unresolved or stale else 0


if __name__ == '__main__':
    sys.exit(main())
