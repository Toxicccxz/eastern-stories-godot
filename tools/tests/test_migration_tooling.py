"""Deterministic source extraction tests; all fixtures and outputs are tooling-only."""

from __future__ import annotations

import contextlib
import hashlib
import io
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch


REPOSITORY = Path(__file__).resolve().parents[2]
if str(REPOSITORY) not in sys.path:
    sys.path.insert(0, str(REPOSITORY))
from tools.migration import cli
from tools.migration.es2_source import Source, SourceError, ToolError, discover, lex, literal, pairs
from tools.migration.room_extractor import RoomExtractor, canonical, reference, scan


FIXTURES = Path(__file__).parent / 'fixtures/migration_v1'


def extract(text: str | bytes, path: str = 'd/test/room.c', paths: set[str] | None = None,
            dependencies: dict[str, Source] | None = None) -> tuple[dict, list[dict]]:
    data = text.encode('utf-8') if isinstance(text, str) else text
    return RoomExtractor(Source(path, data), paths or set(), dependencies or {}).extract()


def room(body: str, extra: str = '') -> str:
    return 'inherit ROOM;\nvoid create() {\n' + body + '\n}\n' + extra


def fields(record: dict, field: str) -> list[dict]:
    return [f for f in record['facts'] if f['field'] == field]


def codes(findings: list[dict]) -> set[str]:
    return {f['code'] for f in findings}


class LexerTests(unittest.TestCase):
    def test_line_and_block_comments_do_not_produce_code(self):
        tokens = lex(Source('x.c', b'// inherit ROOM;\n/* inherit ROOM; */ inherit ITEM;'))
        self.assertEqual(['inherit', 'ITEM', ';'], [t.text for t in tokens])

    def test_string_escaped_quote_and_backslash(self):
        token = lex(Source('x.c', br'"a\"b\\c // /* inherit ROOM;"'))[0]
        self.assertEqual('a"b\\c // /* inherit ROOM;', literal(token)['value'])

    def test_character_literals_are_opaque(self):
        ts = lex(Source('x.c', b"'{' '\\n' '\\''"))
        self.assertEqual(['character'] * 3, [t.kind for t in ts])
        self.assertEqual({}, pairs(ts))

    def test_quoted_symbol_is_unsupported_not_executed(self):
        self.assertEqual('unknown', lex(Source('x.c', b"'symbol"))[0].kind)

    def test_heredoc_excludes_code_and_keeps_suffix(self):
        ts = lex(Source('x.c', b'@CODE\ninherit ROOM;\nCODE);'))
        self.assertEqual(['heredoc', 'punctuation', 'punctuation'], [t.kind for t in ts])
        self.assertEqual('inherit ROOM;\n', literal(ts[0])['value'])

    def test_heredoc_similar_identifier_is_body(self):
        ts = lex(Source('x.c', b'@CODE\nCODE_EXTRA\nCODE is text\nCODE\n'))
        self.assertEqual('CODE_EXTRA\nCODE is text\n', literal(ts[0])['value'])

    def test_array_heredoc_not_scalar(self):
        ts = lex(Source('x.c', b'@@LINES\na\nb\nLINES\n'))
        self.assertEqual('heredoc_array', ts[0].kind)
        self.assertIsNone(literal(ts[0]))

    def test_multibyte_crlf_offsets(self):
        raw = '// 雪\r\n\tset("short", "雪");'.encode('utf-8')
        source = Source('x.c', raw)
        ts = lex(source)
        self.assertEqual(9, ts[0].start)
        p = source.span(ts[0].start, ts[-1].end, 'create', 'call:set', 1)
        self.assertEqual((2, 2), (p['line'], p['column']))
        self.assertEqual(raw[9:].decode('utf-8'), p['raw'])

    def test_unterminated_comment_string_multiline(self):
        for raw in [b'/* a', b'"unfinished', b'@TEXT\nunfinished', b'"escape\\']:
            with self.subTest(raw=raw), self.assertRaises(SourceError):
                lex(Source('x.c', raw))

    def test_encoding_corruption(self):
        for raw in [b'\xff', b'\x00', '\ufffd'.encode('utf-8')]:
            with self.subTest(raw=raw), self.assertRaises(SourceError) as caught:
                lex(Source('x.c', raw))
            self.assertTrue(caught.exception.encoding)

    def test_balanced_spaced_closure(self):
        pairs(lex(Source('x.c', b'set("x", (:this_object(), ({"a"}): ));')))

    def test_mismatched_delimiters(self):
        with self.assertRaises(SourceError):
            pairs(lex(Source('x.c', b'([)]')))

    def test_preprocessor_continuation_is_opaque(self):
        ts = lex(Source('x.c', b'#define TEXT \\\n inherit ROOM;\ninherit ITEM;'))
        self.assertEqual('directive', ts[0].kind)
        self.assertEqual(['inherit', 'ITEM', ';'], [t.text for t in ts[1:]])


class RoomFactTests(unittest.TestCase):
    def test_hand_authored_projection_golden(self):
        data = (FIXTURES / 'static_room.c').read_bytes()
        record, findings = extract(data, paths={'d/test/east.c', 'd/test/west.c', 'd/test/north.c'})
        actual = dict(status=record['status'], fields=[f['field'] for f in record['facts']],
                      text=[f['value']['value'] for f in record['facts'] if f['field'] in {'short', 'name', 'long'}],
                      flags=[f['value'] for f in record['facts'] if f['field'] in {'no_fight', 'outdoors'}],
                      exits=[dict(direction=f['value']['direction'], target=f['value']['target'], classification=f['classification']) for f in fields(record, 'exit')],
                      finding_codes=[f['code'] for f in findings])
        expected = json.loads((FIXTURES / 'static_room.expected.json').read_text(encoding='utf-8'))
        self.assertEqual(expected, actual)
        self.assertEqual('TEXT_ONLY', fields(record, 'long')[0]['text_classification'])

    def test_non_room_categories_are_out_of_scope(self):
        for category in ['BANK', 'HOCKSHOP', 'CLASS_GUILD', 'NPC', 'ITEM', 'SWORD', 'CLOTH', 'F_FOOD']:
            with self.subTest(category=category):
                r, f = extract(f'inherit {category}; void create() {{ set("short", "x"); }}')
                self.assertEqual('OUT_OF_SCOPE', r['status'])
                self.assertEqual([], r['facts'])

    def test_room_outside_d_is_not_supported(self):
        r, _ = extract(room('set("short", "x");'), 'u/room.c')
        self.assertFalse(r['supported_candidate'])

    def test_multiple_inherit_retained_without_flattening(self):
        r, f = extract('inherit ROOM; inherit F_CUSTOM; void create() {}')
        self.assertEqual(['ROOM', 'F_CUSTOM'], r['category_candidates'])
        self.assertEqual(2, len(fields(r, 'inherit')))
        self.assertIn('UNRESOLVED_INHERITANCE', codes(f))
        self.assertEqual('PARTIAL', r['status'])

    def test_room_and_explicit_excluded_category_is_not_supported(self):
        r, _ = extract('inherit ROOM; inherit NPC; void create() {}')
        self.assertFalse(r['supported_candidate'])

    def test_fake_inherit_all_noncode_forms(self):
        text = '// inherit ROOM;\n/* inherit ROOM; */\ninherit ITEM;\nstring s="inherit ROOM;";\nstring t=@CODE\ninherit ROOM;\nCODE\n;'
        r, _ = extract(text)
        self.assertEqual(['ITEM'], r['category_candidates'])
        self.assertFalse(r['supported_candidate'])

    def test_explicit_zero_is_distinct_from_absent(self):
        r, _ = extract(room('set("no_fight", 0); set("indoors", 1);'))
        self.assertEqual({'kind': 'integer', 'value': '0'}, fields(r, 'no_fight')[0]['value'])
        self.assertEqual([], fields(r, 'outdoors'))

    def test_large_integer_is_exact_decimal_string(self):
        r, _ = extract(room('set("no_fight", 9007199254740993);'))
        self.assertEqual('9007199254740993', fields(r, 'no_fight')[0]['value']['value'])

    def test_unknown_null_macro_arithmetic_not_coerced(self):
        for expression in ['NULL', '0.0', '1 + 2', '077', '"a" + "b"', 'VALUE', 'random(0)']:
            with self.subTest(expression=expression):
                r, f = extract(room(f'set("no_fight", {expression});'))
                self.assertEqual([], fields(r, 'no_fight'))
                self.assertIn('DYNAMIC_EXPRESSION', codes(f))

    def test_repeated_declarations_have_order_and_distinct_identity(self):
        r, f = extract(room('set("short", "x"); set("short", "x");'))
        facts = fields(r, 'short')
        self.assertEqual(2, len(facts))
        self.assertNotEqual(facts[0]['fact_id'], facts[1]['fact_id'])
        self.assertLess(facts[0]['provenance']['source_ordinal'], facts[1]['provenance']['source_ordinal'])
        self.assertIn('DUPLICATE_DECLARATION', codes(f))

    def test_only_unambiguous_create_receiver(self):
        text = room('ob->set("short", "foreign"); if (x) set("short", "conditional"); if (x) {set("short", "nested");}',
                    'void reset() {set("short", "reset");}')
        r, f = extract(text)
        self.assertEqual([], fields(r, 'short'))
        self.assertIn('UNSUPPORTED_CONSTRUCT', codes(f))
        self.assertIn('CALLBACK_BEHAVIOR', codes(f))

    def test_shadowed_setter_not_treated_as_base_set(self):
        r, _ = extract(room('set("short", "x");', 'void set(string a, string b) {}'))
        self.assertEqual([], fields(r, 'short'))

    def test_conditional_preprocessor_not_evaluated(self):
        r, f = extract('#if MODE\ninherit ROOM;\n#else\ninherit NPC;\n#endif\nvoid create() {}')
        self.assertFalse(r['supported_candidate'])
        self.assertIn('DRIVER_SEMANTICS_UNKNOWN', codes(f))

    def test_redefined_room_or_dir_not_guessed(self):
        r, _ = extract('#define ROOM NPC\n' + room('set("short", "x");'))
        self.assertFalse(r['supported_candidate'])
        r, f = extract('#define __DIR__ "/elsewhere/"\n' + room('set("exits", (["e": __DIR__"x"]));'))
        self.assertEqual([], fields(r, 'exit'))
        self.assertIn('DYNAMIC_EXPRESSION', codes(f))

    def test_directive_comments_do_not_hide_shadowing_or_condition(self):
        for directive in ['#define ROOM/**/ NPC\n', '#if/**/FEATURE\n', '#undef/**/ROOM\n']:
            with self.subTest(directive=directive):
                r, _ = extract(directive + room('set("short", "x");'))
                self.assertFalse(r['supported_candidate'])

    def test_unresolved_include_prevents_setter_assumptions(self):
        r, f = extract('#include <missing.h>\n' + room('set("short", "x");'))
        self.assertEqual([], fields(r, 'short'))
        self.assertIn('UNRESOLVED_INCLUDE', codes(f))

    def test_include_shadow_dependency_is_inspected(self):
        deps = {'include/custom.h': Source('include/custom.h', b'#define set my_set\n')}
        r, _ = extract('#include <custom.h>\n' + room('set("short", "x");'), dependencies=deps)
        self.assertEqual([], fields(r, 'short'))

    def test_unknown_field_preserves_full_statement(self):
        r, f = extract(room('set("objects", (["npc": 5]));'))
        self.assertEqual(['inherit'], [fact['field'] for fact in r['facts']])
        diagnostic = next(x for x in f if x['code'] == 'UNSUPPORTED_CONSTRUCT')
        self.assertEqual('set("objects", (["npc": 5]));', diagnostic['provenance']['raw'])

    def test_all_fact_provenance_matches_original_bytes(self):
        raw = (FIXTURES / 'static_room.c').read_bytes().replace(b'\n', b'\r\n')
        r, findings = extract(raw)
        for obj in r['facts'] + findings:
            p = obj['provenance']
            self.assertEqual(hashlib.sha256(raw).hexdigest(), p['source_sha256'])
            self.assertEqual(p['raw'].encode('utf-8'), raw[p['byte_start']:p['byte_end_exclusive']])
            prefix = raw[:p['byte_start']].decode('utf-8')
            self.assertEqual(prefix.count('\n') + 1, p['line'])
            self.assertEqual(len(prefix.rsplit('\n', 1)[-1]) + 1, p['column'])

    def test_malformed_mapping_quarantines_and_clears_facts(self):
        for entry in ['"north" "bad"', ',"e": "x"', '"n":']:
            with self.subTest(entry=entry):
                r, f = extract(room('set("short", "x"); set("exits", ([' + entry + ']));'))
                self.assertEqual('QUARANTINED', r['status'])
                self.assertEqual([], r['facts'])
                self.assertIn('SOURCE_SYNTAX_ERROR', codes(f))


class ExitTests(unittest.TestCase):
    def test_literal_and_dir_exits_order(self):
        r, _ = extract(room('set("exits", (["e": "/d/e", "w": __DIR__"w", "n": __DIR__ + "n"]));'))
        self.assertEqual(['e', 'w', 'n'], [f['value']['direction'] for f in fields(r, 'exit')])
        self.assertEqual('/d/test/w', fields(r, 'exit')[1]['value']['target'])
        self.assertEqual(1, fields(r, 'exit')[1]['normalization']['version'])

    def test_random_variable_and_arithmetic_remain_dynamic(self):
        r, f = extract(room('set("exits", (["e": __DIR__"pine" + random(5), key: "x", "w": DEST]));'))
        self.assertEqual([], fields(r, 'exit'))
        self.assertIn('RNG_SEMANTICS', codes(f))
        self.assertEqual(3, sum(x['code'] == 'DYNAMIC_EXPRESSION' for x in f))

    def test_duplicate_direction_retained(self):
        r, f = extract(room('set("exits", (["e": "/a", "e": "/b"]));'))
        self.assertEqual(2, len(fields(r, 'exit')))
        self.assertIn('DUPLICATE_DECLARATION', codes(f))

    def test_ternary_mapping_is_dynamic_not_syntax_error(self):
        r, f = extract(room('set("exits", (["e": flag ? "/a" : "/b"]));'))
        self.assertEqual('PARTIAL', r['status'])
        self.assertEqual([], fields(r, 'exit'))
        self.assertIn('DYNAMIC_EXPRESSION', codes(f))

    def test_local_callback_and_cross_object_exit_mutations(self):
        r, f = extract(room('set("exits", (["e": "/a"])); delete("exits/e");',
                            'void reset() { ob->set("exits/e", "b"); set("exits", variable); }'))
        self.assertEqual(1, len(fields(r, 'exit')))
        self.assertEqual('PARTIAL', r['status'])
        self.assertEqual(3, sum(x['code'] == 'ORDER_SENSITIVE_MUTATION' for x in f))

    def test_multiple_exit_assignments_even_empty_first(self):
        _, f = extract(room('set("exits", ([])); set("exits", (["e": "/a"]));'))
        self.assertIn('DUPLICATE_DECLARATION', codes(f))

    def test_reference_case_missing_ambiguous_dynamic(self):
        self.assertEqual('EXISTS', reference('/d/A', {'d/A.c'})['status'])
        self.assertEqual('CASE_MISMATCH', reference('/d/a', {'d/A.c'})['status'])
        self.assertEqual('AMBIGUOUS', reference('/d/AB', {'d/Ab.c', 'd/aB.c'})['status'])
        self.assertEqual('MISSING', reference('/d/absent', set())['status'])
        self.assertEqual('UNRESOLVED', reference('../outside', set())['status'])


class ScanAndCliTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name)
        self.source = self.base / 'input'
        (self.source / 'd').mkdir(parents=True)
        self.output = self.base / 'output'

    def write(self, path: str, data: bytes):
        file = self.source / path
        file.parent.mkdir(parents=True, exist_ok=True)
        file.write_bytes(data)

    def run_cli(self, *extra: str):
        with contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
            return cli.main(['--source-root', str(self.source), '--output-root', str(self.output), *extra])

    def test_discovery_all_files_and_order(self):
        self.write('d/z.c', b'inherit ROOM; void create() {}')
        self.write('d/A.c', b'inherit ITEM;')
        self.write('include/x.h', b'// header')
        self.write('README', b'text')
        r, code = scan(self.source)
        self.assertEqual(0, code)
        self.assertEqual(['README', 'd/A.c', 'd/z.c', 'include/x.h'], [f['input_path'] for f in r['source_manifest']['files']])
        self.assertEqual(4, len(r['objects']))

    def test_reversed_enumeration_does_not_change_output(self):
        self.write('d/z.c', b'inherit ROOM; void create() {}')
        self.write('d/a.c', b'inherit ROOM; void create() {}')
        first = canonical(scan(self.source)[0])
        original = Path.iterdir
        with patch.object(Path, 'iterdir', lambda p: iter(reversed(list(original(p))))):
            second = canonical(scan(self.source)[0])
        self.assertEqual(first, second)
        self.assertNotIn(str(self.base).encode(), first)
        self.assertNotIn(b'timestamp', first)
        self.assertNotIn(b'\r\n', first)

    def test_exit0_and_atomic_repeat(self):
        self.write('d/a.c', b'inherit ROOM; void create() {}')
        self.assertEqual(0, self.run_cli())
        before = (self.output / 'static-rooms.json').read_bytes()
        self.assertEqual(0, self.run_cli())
        self.assertEqual(before, (self.output / 'static-rooms.json').read_bytes())

    def test_exit1_still_emits_diagnostics(self):
        self.write('d/a.c', b'inherit ROOM; void create() {')
        self.write('d/b.c', b'\xff')
        self.assertEqual(1, self.run_cli())
        r = json.loads((self.output / 'static-rooms.json').read_bytes())
        self.assertEqual(2, r['summary']['statuses']['QUARANTINED'])
        self.assertIn('raw_hex', r['findings'][-1]['provenance'])

    def test_exit2_bad_arguments(self):
        with contextlib.redirect_stderr(io.StringIO()), self.assertRaises(SystemExit) as caught:
            cli.main(['--profile', 'execute-lpc'])
        self.assertEqual(2, caught.exception.code)

    def test_exit2_unsafe_source_root(self):
        with self.assertRaises(ToolError):
            scan(self.base)

    def test_exit2_output_escape_and_source_overlap(self):
        self.assertEqual(2, self.run_cli('--output', '../escape.json'))
        with self.assertRaises(ToolError):
            cli.destination(self.source, self.source / 'out', Path('x.json'))
        with self.assertRaises(ToolError):
            cli.destination(self.source, REPOSITORY / 'game', Path('x.json'))

    def test_links_and_junctions_rejected(self):
        for method in ['is_symlink', 'is_junction']:
            with self.subTest(method=method), patch.object(Path, method, return_value=True), self.assertRaises(ToolError):
                discover(self.source)

    def test_existing_manual_output_not_replaced(self):
        self.output.mkdir()
        file = self.output / 'static-rooms.json'
        file.write_bytes(b'manual notes')
        self.assertEqual(2, self.run_cli())
        self.assertEqual(b'manual notes', file.read_bytes())

    def test_tracked_external_file_not_replaced(self):
        self.output.mkdir()
        subprocess.run(['git', 'init', '-q', str(self.output)], check=True, capture_output=True)
        file = self.output / 'static-rooms.json'
        file.write_bytes(b'{}')
        subprocess.run(['git', '-C', str(self.output), 'add', 'static-rooms.json'], check=True, capture_output=True)
        self.assertEqual(2, self.run_cli())
        self.assertEqual(b'{}', file.read_bytes())

    def test_fatal_write_preserves_existing_and_cleans_temp(self):
        self.write('d/a.c', b'inherit ROOM; void create() {}')
        self.assertEqual(0, self.run_cli())
        target = self.output / 'static-rooms.json'
        before = target.read_bytes()
        with patch('tools.migration.cli.os.replace', side_effect=OSError('test write failure')):
            self.assertEqual(2, self.run_cli())
        self.assertEqual(before, target.read_bytes())
        self.assertEqual([target], list(self.output.iterdir()))

    def test_fatal_read_does_not_emit_output(self):
        self.write('d/a.c', b'inherit ROOM; void create() {}')
        with patch('tools.migration.es2_source.Path.read_bytes', side_effect=OSError('test read failure')):
            self.assertEqual(2, self.run_cli())
        self.assertFalse((self.output / 'static-rooms.json').exists())

    def test_schema_invariant_failure_is_exit2_without_output(self):
        self.write('d/a.c', b'inherit ROOM; void create() {}')
        report, code = scan(self.source)
        report['objects'][0]['status'] = 'APPROVED'
        with patch('tools.migration.cli.scan', return_value=(report, code)):
            self.assertEqual(2, self.run_cli())
        self.assertFalse((self.output / 'static-rooms.json').exists())

    def test_root_and_mudlib_same_name_files_have_distinct_identity(self):
        self.write('mudlib/d/a.c', b'inherit ROOM; void create() {}')
        self.write('mudlib/README', b'inside')
        self.write('README', b'outside')
        r, _ = scan(self.source)
        self.assertEqual(3, len({o['object_id'] for o in r['objects']}))
        self.assertEqual(['source-root', 'mudlib', 'mudlib'], [o['source_namespace'] for o in r['objects']])

    def test_previous_complete_100_output_upgrades_atomically(self):
        self.write('d/a.c', b'inherit ROOM; void create() {}')
        previous, _ = scan(self.source)
        previous['extractor_version'] = '1.0.0'
        self.output.mkdir()
        target = self.output / 'static-rooms.json'
        target.write_bytes(canonical(previous))
        self.assertEqual(0, self.run_cli())
        self.assertEqual('1.0.1', json.loads(target.read_bytes())['extractor_version'])

    def test_metadata_only_json_is_never_recognized(self):
        self.write('d/a.c', b'inherit ROOM; void create() {}')
        self.output.mkdir()
        target = self.output / 'static-rooms.json'
        for version in ('1.0.0', '1.0.1'):
            payload = json.dumps(dict(schema_version=1, profile='static-room-v1', extractor_version=version)).encode()
            target.write_bytes(payload)
            with patch.object(cli, 'atomic_write') as writer:
                self.assertEqual(2, self.run_cli())
                writer.assert_not_called()
            self.assertEqual(payload, target.read_bytes())

    def test_edited_reviewed_or_unknown_output_not_replaced(self):
        self.write('d/a.c', b'inherit ROOM; void create() {}')
        self.output.mkdir()
        target = self.output / 'static-rooms.json'
        for edit in ('version', 'review', 'manifest', 'summary', 'notes'):
            previous, _ = scan(self.source)
            if edit == 'version':
                previous['extractor_version'] = '9.0.0'
            elif edit == 'review':
                previous['review_state'] = 'APPROVED'
            elif edit == 'manifest':
                previous['source_manifest']['sha256'] = '0' * 64
            elif edit == 'summary':
                previous['summary']['scanned_files'] = 123
            else:
                previous['owner_notes'] = 'preserve'
            payload = canonical(previous)
            target.write_bytes(payload)
            with self.subTest(edit=edit):
                self.assertEqual(2, self.run_cli())
                self.assertEqual(payload, target.read_bytes())


class AuditBlockerRegressionTests(unittest.TestCase):
    """P2F1: adversarial admission, provenance and classification boundaries."""

    def test_h1_parent_output_root_cannot_reenter_protected_checkout(self):
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / 'input'
            (source / 'd').mkdir(parents=True)
            (source / 'd/probe.c').write_text(room(''), encoding='utf-8')
            for folder in ('game', 'reference/es2', 'docs'):
                target = REPOSITORY / folder / 'p2f1-never-written.json'
                before = sorted(p.name for p in target.parent.iterdir())
                self.assertFalse(target.exists())
                for output in (target, target.relative_to(REPOSITORY.parent)):
                    with self.subTest(folder=folder, output=str(output)), patch.object(cli, 'atomic_write') as writer:
                        with contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
                            result = cli.main(['--source-root', str(source), '--output-root',
                                               str(REPOSITORY.parent), '--output', str(output)])
                        self.assertEqual(2, result)
                        writer.assert_not_called()
                self.assertFalse(target.exists())
                self.assertEqual(before, sorted(p.name for p in target.parent.iterdir()))
            allowed = cli.DEFAULT_OUTPUT_ROOT / 'p2f1-allowed.json'
            self.assertEqual(allowed, cli.destination(source, REPOSITORY.parent, allowed))

    def check_shadow(self, directive, name):
        text = directive + room('set("short", "雪"); set("exits", (["e":__DIR__"x"]));')
        record, findings = extract(text)
        if name == 'ROOM':
            self.assertFalse(record['supported_candidate'])
            self.assertEqual([], record['facts'])
            self.assertIn('UNRESOLVED_INHERITANCE', codes(findings))
        elif name in ('set', 'create'):
            self.assertEqual([], fields(record, 'short'))
            self.assertEqual([], fields(record, 'exit'))
        else:
            self.assertEqual([], fields(record, 'exit'))
            self.assertFalse(any('normalization' in f for f in record['facts']))
        raw = text.encode('utf-8')
        for entry in record['facts'] + findings + record['direct_inherits']:
            p = entry['provenance']
            self.assertEqual(raw[p['byte_start']:p['byte_end_exclusive']].decode('utf-8'), p['raw'])
            self.assertEqual(hashlib.sha256(raw).hexdigest(), p['source_sha256'])
        self.assertTrue(any(f['provenance']['raw'] == directive for f in findings))

    def test_h2_continued_critical_names_lf_and_crlf(self):
        for newline in ('\n', '\r\n'):
            for name in ('ROOM', 'set', '__DIR__', 'create'):
                with self.subTest(newline=repr(newline), name=name):
                    self.check_shadow('#define \\' + newline + name + ' replacement' + newline, name)

    def test_h2_split_keyword_name_and_undef(self):
        for newline in ('\n', '\r\n'):
            for directive in ('#define RO\\' + newline + 'OM NPC',
                              '#de\\' + newline + 'fine ROOM NPC',
                              '#undef \\' + newline + 'ROOM'):
                with self.subTest(directive=directive):
                    self.check_shadow(directive + newline, 'ROOM')

    def test_h2_benign_continuation_does_not_block_safe_facts(self):
        for newline in ('\n', '\r\n'):
            directive = '#define LABEL \\' + newline + '"label"' + newline
            record, findings = extract(directive + room('set("short", "safe");'))
            self.assertTrue(record['supported_candidate'])
            self.assertEqual('safe', fields(record, 'short')[0]['value']['value'])
            self.assertNotIn('UNRESOLVED_INHERITANCE', codes(findings))

    def test_h2_spliced_directive_error_offsets_use_original_bytes(self):
        for newline in ('\n', '\r\n'):
            text = '#define LABEL \\' + newline + '"雪'
            record, findings = extract(text)
            self.assertEqual('QUARANTINED', record['status'])
            p = findings[-1]['provenance']
            self.assertEqual(text.encode('utf-8').index(b'"'), p['byte_start'])
            self.assertEqual('"雪', p['raw'])

    def test_m1_exact_literal_excluded_bases(self):
        # Independent expectations from include/globals.h:54-68; no inferred subclasses.
        bases = {'/std/room/bank': 'BANK', '/std/room/class_guild': 'CLASS_GUILD',
                 '/std/force': 'FORCE', '/std/room/hockshop': 'HOCKSHOP', '/std/item': 'ITEM',
                 '/std/liquid': 'LIQUID', '/std/char/npc': 'NPC', '/std/skill': 'SKILL'}
        for base, category in bases.items():
            with self.subTest(base=base):
                text = 'inherit ROOM; inherit "' + base + '"; void create(){set("short","mixed");}'
                record, findings = extract(text)
                self.assertFalse(record['supported_candidate'])
                self.assertEqual([], record['facts'])
                self.assertEqual(2, len(record['direct_inherits']))
                self.assertEqual('"' + base + '"', record['direct_inherits'][1]['expression'])
                self.assertEqual('inherit "' + base + '";', record['direct_inherits'][1]['provenance']['raw'])
                self.assertIn(category, record['category_candidates'])
                self.assertIn('OUT_OF_SCOPE', codes(findings))

    def test_m1_does_not_guess_indirect_or_similar_names(self):
        for base in ('/custom/npc', '/std/char/npc_child', '/STD/char/npc'):
            record, findings = extract('inherit "' + base + '"; ' + room(''))
            self.assertTrue(record['supported_candidate'])
            self.assertIn('UNRESOLVED_INHERITANCE', codes(findings))

    def test_m2_missing_include_rejects_admission_without_quarantine(self):
        record, findings = extract('#include <missing.h>\n' + room('set("short", "x");'))
        self.assertFalse(record['supported_candidate'])
        self.assertEqual('OUT_OF_SCOPE', record['status'])
        self.assertEqual([], record['facts'])
        self.assertIn('UNRESOLVED_INCLUDE', codes(findings))
        self.assertNotIn('SOURCE_SYNTAX_ERROR', codes(findings))

    def test_m2_transitive_missing_include_retains_shadow_evidence(self):
        dep = Source('include/test.h', b'#include <missing.h>\n#define ROOM NPC\n')
        record, findings = extract('#include <test.h>\n' + room(''), dependencies={dep.path: dep})
        self.assertFalse(record['supported_candidate'])
        self.assertEqual([], record['facts'])
        self.assertTrue({'UNRESOLVED_INCLUDE', 'UNRESOLVED_INHERITANCE'} <= codes(findings))

    def test_m3_computed_mapping_and_balanced_values_remain_partial(self):
        expressions = ['(["e":"/a"])+(["w":"/b"])',
                       '(["e": (["nested":"/a"])])',
                       '(["e": flag ? "/a" : "/b"])',
                       '(["e": random(2)])', '(["e": (: choose, "a:b" :)])',
                       '([(: choose :) : "/a"])', '(["e": "/a"; "/b"])',
                       '(["e": value:other])']
        for expression in expressions:
            with self.subTest(expression=expression):
                record, findings = extract(room('set("short","safe"); set("exits",' + expression + ');'))
                self.assertEqual('PARTIAL', record['status'])
                self.assertEqual('safe', fields(record, 'short')[0]['value']['value'])
                self.assertEqual([], fields(record, 'exit'))
                self.assertIn('DYNAMIC_EXPRESSION', codes(findings))
                self.assertNotIn('SOURCE_SYNTAX_ERROR', codes(findings))

    def test_m3_genuinely_malformed_mapping_stays_quarantined(self):
        for expression in ('(["e" "/a"])', '([,"e":"/a"])', '(["e":])', '(["e":"/a"]) )'):
            with self.subTest(expression=expression):
                record, findings = extract(room('set("short","safe"); set("exits",' + expression + ');'))
                self.assertEqual('QUARANTINED', record['status'])
                self.assertEqual([], record['facts'])
                self.assertIn('SOURCE_SYNTAX_ERROR', codes(findings))


class RealSourceTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.result, cls.code = scan(REPOSITORY / 'reference/es2')
        cls.objects = {o['source_path']: o for o in cls.result['objects']}

    def findings(self, path):
        return [f for f in self.result['findings'] if f['provenance']['source_path'] == path]

    def test_roommaker_is_item_not_room(self):
        r = self.objects['obj/roommaker.c']
        self.assertFalse(r['supported_candidate'])
        self.assertEqual(['ITEM', 'F_AUTOLOAD'], r['category_candidates'])

    def test_street1_static_provenance(self):
        r = self.objects['d/city/street1.c']
        f = fields(r, 'short')[0]
        self.assertEqual('京师东街', f['value']['value'])
        self.assertEqual((67, 96), (f['provenance']['byte_start'], f['provenance']['byte_end_exclusive']))
        self.assertEqual((7, 9), (f['provenance']['line'], f['provenance']['column']))
        self.assertEqual('22eae1c00f4141b629316f00517aa540e3747cb9075def30ead725c427ae69a9', f['provenance']['source_sha256'])
        self.assertEqual(['/d/city/biaoju', '/d/city/street2', '/d/city/shenwumen'], [f['value']['target'] for f in fields(r, 'exit')])

    def test_school_reports_population_door_and_closure(self):
        r = self.objects['d/snow/school1.c']
        self.assertEqual(2, len(fields(r, 'exit')))
        self.assertEqual('PARTIAL', r['status'])
        raw = '\n'.join(f['provenance']['raw'] for f in self.findings('d/snow/school1.c'))
        self.assertIn('create_door', raw)
        self.assertIn('"objects"', raw)
        self.assertIn('CALLBACK_BEHAVIOR', codes(self.findings('d/snow/school1.c')))

    def test_pine3_random_exits_not_evaluated(self):
        self.assertEqual([], fields(self.objects['d/oldpine/pine3.c'], 'exit'))
        self.assertIn('RNG_SEMANTICS', codes(self.findings('d/oldpine/pine3.c')))

    def test_keep2_static_facts_and_mutation_findings(self):
        r = self.objects['d/oldpine/keep2.c']
        self.assertEqual(2, len(fields(r, 'exit')))
        self.assertEqual('PARTIAL', r['status'])
        self.assertIn('ORDER_SENSITIVE_MUTATION', codes(self.findings('d/oldpine/keep2.c')))

    def test_lake_retains_callback_lifecycle_boundary(self):
        r = self.objects['d/village/lake.c']
        self.assertEqual('PARTIAL', r['status'])
        self.assertTrue({'CALLBACK_BEHAVIOR', 'DRIVER_SEMANTICS_UNKNOWN'} <= codes(self.findings('d/village/lake.c')))

    def test_actual_malformed_source_quarantined(self):
        for path in ['d/latemoon/sroad1.c', 'u/cloud/obj/sword_book.c', 'u/cloud/obj/npc/flower_girl/guihua.c']:
            with self.subTest(path=path):
                self.assertEqual('QUARANTINED', self.objects[path]['status'])
                self.assertEqual([], self.objects[path]['facts'])
        self.assertEqual(1, self.code)

    def test_whole_input_coverage_and_no_autoapproval(self):
        objects = self.result['objects']
        self.assertEqual(len(self.result['source_manifest']['files']), len(objects))
        self.assertEqual(len(objects), len({o['object_id'] for o in objects}))
        self.assertEqual(len(objects), len({o['input_path'] for o in objects}))
        self.assertEqual(len(objects), sum(self.result['summary']['statuses'].values()))
        for obj in objects:
            self.assertEqual('UNREVIEWED', obj['review_state'])
            self.assertNotEqual('APPROVED', obj['status'])


if __name__ == '__main__':
    unittest.main()
