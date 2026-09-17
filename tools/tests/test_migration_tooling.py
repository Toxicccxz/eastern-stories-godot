"""Deterministic source extraction tests; all fixtures and outputs are tooling-only."""

from __future__ import annotations

import contextlib
import copy
import hashlib
import io
import json
import re
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
from tools.migration.room_extractor import EXCLUDED_LITERAL_BASES, RoomExtractor, canonical, directive_parts, reference, scan


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
        self.assertEqual('1.0.15', json.loads(target.read_bytes())['extractor_version'])

    def test_metadata_only_json_is_never_recognized(self):
        self.write('d/a.c', b'inherit ROOM; void create() {}')
        self.output.mkdir()
        target = self.output / 'static-rooms.json'
        for version in ('1.0.0', '1.0.1', '1.0.2', '1.0.3', '1.0.4', '1.0.5', '1.0.6', '1.0.7', '1.0.8', '1.0.9', '1.0.10', '1.0.11', '1.0.12', '1.0.13', '1.0.14', '1.0.15'):
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
            # Invalid external input must bypass the now-shared strict serializer.
            payload = (json.dumps(previous, ensure_ascii=False, indent=2) + '\n').encode('utf-8')
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


class P2F2RegressionTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.source = Path(self.temp.name) / 'input'
        (self.source / 'd').mkdir(parents=True)
        (self.source / 'd/room.c').write_text(room(
            'set("short","safe");set("long","text only");set("no_fight",0);'
            'set("exits",(["e":__DIR__"room","w":"/d/room"]));'), encoding='utf-8')
        (self.source / 'd/bad.c').write_bytes(b'\xff')
        self.output = Path(self.temp.name) / 'output'
        self.output.mkdir()
        self.target = self.output / 'static-rooms.json'
        self.document, self.scan_code = scan(self.source)

    def run_cli(self):
        with contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
            return cli.main(['--source-root', str(self.source), '--output-root', str(self.output)])

    def levels(self, doc):
        obj = next(o for o in doc['objects'] if o['facts'])
        fact = next(f for f in obj['facts'] if 'normalization' in f)
        diagnostic = next(f for f in doc['findings'] if f['provenance']['raw'] is None)
        return {'document': doc, 'manifest': doc['source_manifest'],
                'manifest_file': doc['source_manifest']['files'][0], 'object': obj,
                'inherit': obj['direct_inherits'][0], 'inherit_provenance': obj['direct_inherits'][0]['provenance'],
                'fact': fact, 'finding': doc['findings'][0], 'fact_provenance': fact['provenance'],
                'finding_provenance': doc['findings'][0]['provenance'],
                'encoding_provenance': diagnostic['provenance'], 'normalization': fact['normalization'],
                'normalization_input': fact['normalization']['inputs'][0], 'exit_value': fact['value'],
                'reference_value': fields(obj, 'inherit')[0]['value'],
                'text_value': fields(obj, 'short')[0]['value'], 'integer_value': fields(obj, 'no_fight')[0]['value'],
                'exit_reference': fact['value']['reference'], 'summary': doc['summary'],
                'statuses': doc['summary']['statuses'], 'finding_codes': doc['summary']['finding_codes']}

    def assert_preserved(self, doc):
        # Deliberately bypass canonical(): this is adversarial input, not producer output.
        payload = (json.dumps(doc, ensure_ascii=False, indent=2) + '\n').encode('utf-8')
        self.target.write_bytes(payload)
        with patch.object(cli, 'atomic_write') as writer:
            result = self.run_cli()
            self.assertEqual(2, result)
            writer.assert_not_called()
        self.assertFalse(cli.recognized_output(payload))
        self.assertEqual(payload, self.target.read_bytes())

    def test_unknown_fields_at_every_generated_layer_preserve_bytes(self):
        for version in ('1.0.0', '1.0.1', '1.0.2', '1.0.3', '1.0.4', '1.0.5', '1.0.6', '1.0.7', '1.0.8', '1.0.9', '1.0.10', '1.0.11', '1.0.12', '1.0.13', '1.0.14', '1.0.15'):
            for level in self.levels(self.document):
                for key in ('owner_notes', 'future_field'):
                    with self.subTest(version=version, level=level, key=key):
                        doc = copy.deepcopy(self.document)
                        doc['extractor_version'] = version
                        self.levels(doc)[level][key] = 'preserve manual data'
                        self.assert_preserved(doc)

    def test_canonical_uses_same_closed_schema(self):
        for level in self.levels(self.document):
            with self.subTest(level=level):
                doc = copy.deepcopy(self.document)
                self.levels(doc)[level]['manual_tag'] = 'keep'
                with self.assertRaises(ToolError):
                    canonical(doc)

    def test_all_known_versions_upgrade_with_real_atomic_replace(self):
        for version in ('1.0.0', '1.0.1', '1.0.2', '1.0.3', '1.0.4', '1.0.5', '1.0.6', '1.0.7', '1.0.8', '1.0.9', '1.0.10', '1.0.11', '1.0.12', '1.0.13', '1.0.14', '1.0.15'):
            with self.subTest(version=version):
                doc = copy.deepcopy(self.document)
                doc['extractor_version'] = version
                payload = canonical(doc)
                self.assertTrue(cli.recognized_output(payload))
                self.target.write_bytes(payload)
                with patch.object(cli.os, 'replace', wraps=cli.os.replace) as replace:
                    self.assertEqual(self.scan_code, self.run_cli())
                    replace.assert_called_once()
                self.assertEqual('1.0.15', json.loads(self.target.read_bytes())['extractor_version'])
                self.assertEqual([self.target], list(self.output.iterdir()))

    def test_conditional_fact_and_provenance_shapes_reject_invalid_variants(self):
        for change in ('text_classification', 'normalization', 'missing_normalization', 'raw_hex', 'missing_raw_hex'):
            with self.subTest(change=change):
                doc = copy.deepcopy(self.document)
                levels = self.levels(doc)
                if change == 'text_classification':
                    levels['fact']['text_classification'] = 'TEXT_ONLY'
                elif change == 'normalization':
                    obj = levels['object']
                    fields(obj, 'short')[0]['normalization'] = copy.deepcopy(levels['normalization'])
                elif change == 'missing_normalization':
                    del levels['fact']['normalization']
                elif change == 'raw_hex':
                    levels['fact_provenance']['raw_hex'] = '00'
                else:
                    del levels['encoding_provenance']['raw_hex']
                self.assert_preserved(doc)

    def test_invalid_typed_values_and_counts_rejected(self):
        for level, key, value in [('integer_value', 'value', 0), ('integer_value', 'value', '01'),
                                  ('text_value', 'value', {}), ('exit_value', 'kind', 'text'),
                                  ('exit_reference', 'candidates', {}), ('statuses', 'PARTIAL', True),
                                  ('summary', 'scanned_files', True), ('finding_codes', 'OUT_OF_SCOPE', -1)]:
            with self.subTest(level=level, key=key):
                doc = copy.deepcopy(self.document)
                self.levels(doc)[level][key] = value
                self.assert_preserved(doc)

    def test_money_combined_symbol_and_literal_excluded(self):
        for expr, category in [('MONEY', 'MONEY'), ('COMBINED_ITEM', 'COMBINED_ITEM'),
                               ('"/std/money"', 'MONEY'), ('"/std/item/combined"', 'COMBINED_ITEM')]:
            with self.subTest(expr=expr):
                text = 'inherit ' + expr + ';' + room('set("short","bad candidate");')
                obj, findings = extract(text)
                self.assertFalse(obj['supported_candidate'])
                self.assertEqual('OUT_OF_SCOPE', obj['status'])
                self.assertEqual([], obj['facts'])
                self.assertEqual([expr, 'ROOM'], [d['expression'] for d in obj['direct_inherits']])
                self.assertIn(category, obj['category_candidates'])
                self.assertIn('OUT_OF_SCOPE', codes(findings))
                for declaration in obj['direct_inherits']:
                    p = declaration['provenance']
                    self.assertEqual(text.encode()[p['byte_start']:p['byte_end_exclusive']].decode(), p['raw'])
                    self.assertEqual(hashlib.sha256(text.encode()).hexdigest(), p['source_sha256'])

    def test_similar_money_combined_literals_are_not_guessed(self):
        for path in ('/std/money_custom', '/std/item/combined_child'):
            obj, findings = extract('inherit "' + path + '";' + room(''))
            self.assertTrue(obj['supported_candidate'])
            self.assertFalse({'MONEY', 'COMBINED_ITEM'} & set(obj['category_candidates']))
            self.assertIn('UNRESOLVED_INHERITANCE', codes(findings))


class P2F3RegressionTests(unittest.TestCase):
    # Hand-reviewed object bases only; never generate expectations from production
    # policy or source headers. Changes in authority require explicit review.
    WEAPONS = {
        'AXE': '/std/weapon/axe', 'BLADE': '/std/weapon/blade',
        'DAGGER': '/std/weapon/dagger', 'FORK': '/std/weapon/fork',
        'HAMMER': '/std/weapon/hammer', 'SWORD': '/std/weapon/sword',
        'STAFF': '/std/weapon/staff', 'THROWING': '/std/weapon/throwing',
        'WHIP': '/std/weapon/whip',
    }
    ARMORS = {
        'HEAD': '/std/armor/head', 'NECK': '/std/armor/neck',
        'CLOTH': '/std/armor/cloth', 'ARMOR': '/std/armor/armor',
        'SURCOAT': '/std/armor/surcoat', 'WAIST': '/std/armor/waist',
        'WRISTS': '/std/armor/wrists', 'SHIELD': '/std/armor/shield',
        'FINGER': '/std/armor/finger', 'HANDS': '/std/armor/hands',
        'BOOTS': '/std/armor/boots',
    }

    def assert_excluded(self, expression, category):
        text = ('inherit ROOM;\ninherit ' + expression + ';\n'
                'void create()\n{\n    set("short", "must not migrate");\n}\n')
        obj, findings = extract(text)
        self.assertFalse(obj['supported_candidate'])
        self.assertEqual('OUT_OF_SCOPE', obj['status'])
        self.assertEqual([], obj['facts'])
        self.assertEqual(['ROOM', expression], [d['expression'] for d in obj['direct_inherits']])
        self.assertIn(category, obj['category_candidates'])
        self.assertIn('OUT_OF_SCOPE', codes(findings))
        for index, declaration in enumerate(obj['direct_inherits']):
            p = declaration['provenance']
            expected_raw = 'inherit ' + ('ROOM' if index == 0 else expression) + ';'
            start = text.index(expected_raw)
            self.assertEqual((start, start + len(expected_raw)),
                             (p['byte_start'], p['byte_end_exclusive']))
            self.assertEqual(expected_raw, p['raw'])
            self.assertEqual(expected_raw.encode(), text.encode()[p['byte_start']:p['byte_end_exclusive']])
            self.assertEqual(hashlib.sha256(text.encode()).hexdigest(), p['source_sha256'])
            self.assertEqual('d/test/room.c', p['source_path'])
            self.assertEqual((index + 1, 1), (p['line'], p['column']))
            self.assertEqual(('top-level', 'inherit'), (p['scope'], p['construct']))

    def test_all_standard_symbols_excluded(self):
        for symbol in self.WEAPONS | self.ARMORS:
            with self.subTest(symbol=symbol):
                self.assert_excluded(symbol, symbol)

    def test_all_standard_literals_excluded(self):
        for symbol, path in (self.WEAPONS | self.ARMORS).items():
            with self.subTest(path=path):
                self.assert_excluded('"' + path + '"', symbol)

    def test_authorized_exact_mapping_complete(self):
        self.assertEqual((9, 11), (len(self.WEAPONS), len(self.ARMORS)))
        for symbol, path in (self.WEAPONS | self.ARMORS).items():
            with self.subTest(symbol=symbol):
                self.assertEqual(symbol, EXCLUDED_LITERAL_BASES.get(path))
        # Feature/mixin bases are outside this object-base authorization.
        for name in ('axe', 'blade', 'dagger', 'fork', 'hammer', 'sword', 'staff', 'whip'):
            self.assertNotIn('/std/weapon/_' + name, EXCLUDED_LITERAL_BASES)

    def test_checked_in_authority_matches_hand_reviewed_mapping(self):
        for header, expected in [('weapon.h', self.WEAPONS), ('armor.h', self.ARMORS)]:
            with self.subTest(header=header):
                text = (REPOSITORY / 'reference/es2/mudlib/include' / header).read_text(encoding='utf-8')
                # Read-only drift check, not a runtime policy generator. F_* are
                # feature bases; numeric flags and TYPE_* are not object bases.
                definitions = re.findall(r'^#define\s+([A-Z_]+)\s+"(/std/(?:weapon|armor)/[^"\n]+)"\s*$',
                                         text, re.MULTILINE)
                objects = [(symbol, path) for symbol, path in definitions if not symbol.startswith('F_')]
                self.assertEqual(len(expected), len(objects))
                self.assertEqual(expected, dict(objects))

    def test_similar_unknown_bases_are_not_guessed(self):
        for expression in ('"/std/weapon/sword_custom"', '"/std/weapon/dagger_child"',
                           '"/std/armor/cloth_custom"', '"/std/armor/hands_child"',
                           'DAGGER_CHILD', 'CUSTOM_ARMOR'):
            with self.subTest(expression=expression):
                obj, findings = extract('inherit ROOM;\ninherit ' + expression + ';')
                self.assertTrue(obj['supported_candidate'])
                self.assertEqual('PARTIAL', obj['status'])
                self.assertEqual(['ROOM', expression], obj['category_candidates'])
                self.assertFalse(set(self.WEAPONS | self.ARMORS) & set(obj['category_candidates']))
                self.assertIn('UNRESOLVED_INHERITANCE', codes(findings))


class P2F4RegressionTests(unittest.TestCase):
    # Hand-reviewed globals.h object categories relevant to the authorized D2 fix.
    STANDARD_OBJECTS = {
        'BANK': '/std/room/bank', 'BULLETIN_BOARD': '/std/bboard',
        'CHARACTER': '/std/char', 'CLASS_GUILD': '/std/room/class_guild',
        'COMBINED_ITEM': '/std/item/combined', 'EQUIP': '/std/equip',
        'FORCE': '/std/force', 'HOCKSHOP': '/std/room/hockshop',
        'ITEM': '/std/item', 'LIQUID': '/std/liquid', 'MONEY': '/std/money',
        'NPC': '/std/char/npc', 'POWDER': '/std/medicine/powder',
        'ROOM': '/std/room', 'SKILL': '/std/skill',
    }
    NEW_BASES = ('BULLETIN_BOARD', 'CHARACTER', 'EQUIP', 'POWDER')
    SPECIALIZED_ROOMS = {'BANK', 'CLASS_GUILD', 'HOCKSHOP'}
    # Present in the same authority section, but a skill helper rather than one
    # of this slice's four authorized object-family additions. Pin its definition
    # for full-section drift detection without changing its admission semantics.
    OTHER_STANDARD_DEFINITIONS = {'SSERVER': '/std/sserver'}

    def assert_excluded(self, expression, category):
        text = ('inherit ROOM;\ninherit ' + expression + ';\n'
                'void create() { set("short", "must not migrate"); }\n')
        obj, findings = extract(text)
        self.assertFalse(obj['supported_candidate'])
        self.assertEqual('OUT_OF_SCOPE', obj['status'])
        self.assertEqual([], obj['facts'])
        self.assertEqual(['ROOM', expression], [d['expression'] for d in obj['direct_inherits']])
        self.assertIn(category, obj['category_candidates'])
        self.assertIn('OUT_OF_SCOPE', codes(findings))
        for index, declaration in enumerate(obj['direct_inherits']):
            expected = 'inherit ' + ('ROOM' if index == 0 else expression) + ';'
            start = text.index(expected)
            p = declaration['provenance']
            self.assertEqual((start, start + len(expected)), (p['byte_start'], p['byte_end_exclusive']))
            self.assertEqual(expected, p['raw'])
            self.assertEqual(expected.encode(), text.encode()[p['byte_start']:p['byte_end_exclusive']])
            self.assertEqual(hashlib.sha256(text.encode()).hexdigest(), p['source_sha256'])
            self.assertEqual('d/test/room.c', p['source_path'])
            self.assertEqual((index + 1, 1), (p['line'], p['column']))

    def test_four_symbolic_bases_excluded(self):
        for symbol in self.NEW_BASES:
            with self.subTest(symbol=symbol):
                self.assert_excluded(symbol, symbol)

    def test_four_literal_bases_excluded(self):
        for symbol in self.NEW_BASES:
            with self.subTest(symbol=symbol):
                self.assert_excluded('"' + self.STANDARD_OBJECTS[symbol] + '"', symbol)

    def test_near_matches_are_not_guessed(self):
        for expression in ('"/std/bboard_custom"', '"/std/char_child"', '"/std/equip_custom"',
                           '"/std/medicine/powder_child"', 'BULLETIN_BOARD_CHILD',
                           'CHARACTER_CUSTOM', 'EQUIP_CHILD', 'POWDER_CUSTOM'):
            with self.subTest(expression=expression):
                obj, findings = extract('inherit ROOM;\ninherit ' + expression + ';')
                self.assertTrue(obj['supported_candidate'])
                self.assertEqual('PARTIAL', obj['status'])
                self.assertEqual(['ROOM', expression], obj['category_candidates'])
                self.assertFalse(set(self.NEW_BASES) & set(obj['category_candidates']))
                self.assertIn('UNRESOLVED_INHERITANCE', codes(findings))

    def test_globals_standard_object_policy_complete(self):
        self.assertEqual(15, len(self.STANDARD_OBJECTS))
        self.assertEqual({'BANK', 'CLASS_GUILD', 'HOCKSHOP'}, self.SPECIALIZED_ROOMS)
        for symbol, path in self.STANDARD_OBJECTS.items():
            category = ('generic-room' if symbol == 'ROOM' else
                        'specialized-room' if symbol in self.SPECIALIZED_ROOMS else 'non-room-object')
            with self.subTest(symbol=symbol, category=category):
                if category == 'generic-room':
                    self.assertNotIn(path, EXCLUDED_LITERAL_BASES)
                    obj, _ = extract(room('set("short", "plain room");'))
                    self.assertTrue(obj['supported_candidate'])
                    self.assertEqual('EXTRACTED', obj['status'])
                    self.assertEqual('plain room', fields(obj, 'short')[0]['value']['value'])
                else:
                    self.assertEqual(symbol, EXCLUDED_LITERAL_BASES.get(path))
                    self.assert_excluded(symbol, symbol)
                    self.assert_excluded('"' + path + '"', symbol)

    def test_globals_authority_section_matches_hand_reviewed_table(self):
        text = (REPOSITORY / 'reference/es2/mudlib/include/globals.h').read_text(encoding='utf-8')
        section = text.split('// Inheritable Standard Objects\n', 1)[1].split('// User IDs', 1)[0]
        definitions = re.findall(r'^#define\s+([A-Z_]+)\s+"([^"\n]+)"\s*$', section, re.MULTILINE)
        expected = self.STANDARD_OBJECTS | self.OTHER_STANDARD_DEFINITIONS
        self.assertEqual(len(expected), len(definitions))
        self.assertEqual(expected, dict(definitions))

    def test_room_admission_safeguards_remain_required(self):
        for source, path in [(room(''), 'std/room.c'),
                             ('inherit "/std/room"; void create() {}', 'd/test/room.c'),
                             ('#define ROOM ITEM\n' + room(''), 'd/test/room.c'),
                             ('#include "missing.h"\n' + room(''), 'd/test/room.c')]:
            with self.subTest(source=source, path=path):
                obj, _ = extract(source, path=path)
                self.assertFalse(obj['supported_candidate'])
                self.assertEqual('OUT_OF_SCOPE', obj['status'])
                self.assertEqual([], obj['facts'])


class P2F5RegressionTests(unittest.TestCase):
    BODY = 'void create(){set("short","雪");set("exits",(["e":__DIR__ + "next"]));}\n'

    def assert_directive(self, text, directive, dependencies=None):
        raw = text.encode('utf-8')
        source = Source('d/test/room.c', raw)
        tokens = [t for t in lex(source) if t.kind == 'directive' and t.text == directive]
        self.assertEqual(1, len(tokens))
        token = tokens[0]
        start = raw.index(directive.encode('utf-8'))
        self.assertEqual((start, start + len(directive.encode('utf-8'))), (token.start, token.end))
        self.assertEqual(directive.encode('utf-8'), raw[token.start:token.end])
        self.assertEqual(hashlib.sha256(raw).hexdigest(), source.sha256)
        obj, findings = extract(raw, dependencies=dependencies)
        records = obj['direct_inherits'] + obj['facts'] + findings
        for record in records:
            spans = [record['provenance']]
            if 'normalization' in record:
                spans += record['normalization']['inputs']
            for p in spans:
                self.assertEqual(raw[p['byte_start']:p['byte_end_exclusive']], p['raw'].encode('utf-8'))
                self.assertEqual(source.sha256, p['source_sha256'])
                prefix = raw[:p['byte_start']].decode('utf-8')
                self.assertEqual((prefix.count('\n') + 1, len(prefix.rsplit('\n', 1)[-1]) + 1),
                                 (p['line'], p['column']))
        return obj, findings

    def assert_hazard(self, obj, findings, name, structural=False):
        if name == 'ROOM' or structural:
            self.assertFalse(obj['supported_candidate'])
            self.assertEqual('OUT_OF_SCOPE', obj['status'])
            self.assertEqual([], obj['facts'])
        elif name in ('set', 'create'):
            self.assertEqual([], fields(obj, 'short'))
            self.assertEqual([], fields(obj, 'exit'))
            self.assertEqual('PARTIAL', obj['status'])
        else:
            self.assertEqual([], fields(obj, 'exit'))
            self.assertFalse(any('normalization' in f for f in obj['facts']))
            self.assertEqual('雪', fields(obj, 'short')[0]['value']['value'])
        self.assertTrue(findings)

    def test_comment_prefixed_critical_defines_lf_crlf(self):
        for nl in ('\n', '\r\n'):
            for name, tail in [('ROOM', ' NPC'), ('set', '(key,value) ignored(key,value)'),
                               ('create', ' renamed'), ('__DIR__', ' "/wrong/"')]:
                with self.subTest(newline=repr(nl), name=name):
                    directive = '#define ' + name + tail + nl
                    text = 'inherit ROOM;' + nl + '/* 雪 */ ' + directive + self.BODY.replace('\n', nl)
                    obj, findings = self.assert_directive(text, directive)
                    self.assert_hazard(obj, findings, name, structural=name == 'set')

    def test_comment_prefixed_conditionals_lf_crlf(self):
        for nl in ('\n', '\r\n'):
            for keyword in ('if FLAG', 'ifdef FLAG', 'ifndef FLAG', 'elif FLAG', 'else', 'endif'):
                with self.subTest(newline=repr(nl), keyword=keyword):
                    directive = '#' + keyword + nl
                    obj, findings = self.assert_directive('inherit ROOM;' + nl + '/* c */ ' + directive
                                                         + self.BODY.replace('\n', nl), directive)
                    self.assertFalse(obj['supported_candidate'])
                    self.assertEqual('OUT_OF_SCOPE', obj['status'])
                    self.assertEqual([], obj['facts'])
                    self.assertIn('DRIVER_SEMANTICS_UNKNOWN', codes(findings))

    def test_comment_prefixed_undef_all_critical_names(self):
        for nl in ('\n', '\r\n'):
            for name in ('ROOM', 'set', 'create', '__DIR__'):
                with self.subTest(newline=repr(nl), name=name):
                    directive = '#undef ' + name + nl
                    obj, findings = self.assert_directive('inherit ROOM;' + nl + '/* c */ ' + directive
                                                         + self.BODY.replace('\n', nl), directive)
                    self.assert_hazard(obj, findings, name)

    def test_comment_prefixed_missing_and_resolved_includes(self):
        for nl in ('\n', '\r\n'):
            for mode in ('missing', 'resolved', 'shadowed'):
                with self.subTest(newline=repr(nl), mode=mode):
                    directive = '#include <probe.h>' + nl
                    deps = {} if mode == 'missing' else {'include/probe.h': Source('include/probe.h',
                           ('/* header */ #define set other' + nl if mode == 'shadowed' else '// harmless' + nl).encode())}
                    obj, findings = self.assert_directive('/* c */ ' + directive + 'inherit ROOM;' + nl
                                                         + self.BODY.replace('\n', nl), directive, deps)
                    if mode == 'missing':
                        self.assertFalse(obj['supported_candidate'])
                        self.assertEqual('OUT_OF_SCOPE', obj['status'])
                        self.assertEqual([], obj['facts'])
                        self.assertIn('UNRESOLVED_INCLUDE', codes(findings))
                    elif mode == 'shadowed':
                        self.assert_hazard(obj, findings, 'set')
                    else:
                        self.assertTrue(obj['supported_candidate'])
                        self.assertEqual('雪', fields(obj, 'short')[0]['value']['value'])
                    self.assertNotEqual('QUARANTINED', obj['status'])

    def test_comment_prefix_with_continued_directives(self):
        for nl in ('\n', '\r\n'):
            for value in ('#define \\' + nl + 'ROOM NPC', '#define RO\\' + nl + 'OM NPC',
                          '#de\\' + nl + 'fine ROOM NPC'):
                with self.subTest(newline=repr(nl), value=value):
                    directive = value + nl
                    obj, findings = self.assert_directive('inherit ROOM;' + nl + '/* c */ ' + directive
                                                         + self.BODY.replace('\n', nl), directive)
                    self.assert_hazard(obj, findings, 'ROOM')

    def test_multiple_multiline_comment_prefixes(self):
        prefixes = ('', '    ', '/* a */ ', '/* a */ /* b */ ', '  /* a */  /* b */  ',
                    '/*\n a\n*/ ', '/* a\n*/ ', '/* a\n */ /* b\n */ ', 'x /* a\ncontinued */ ')
        for nl in ('\n', '\r\n'):
            for prefix in prefixes:
                with self.subTest(newline=repr(nl), prefix=prefix):
                    directive = '#define set(k,v) ignored(k,v)' + nl
                    obj, findings = self.assert_directive('inherit ROOM;' + nl + prefix.replace('\n', nl)
                                                         + directive + self.BODY.replace('\n', nl), directive)
                    self.assert_hazard(obj, findings, 'set', structural=True)

    def test_actual_code_before_comment_is_not_directive(self):
        for nl in ('\n', '\r\n'):
            for prefix in ('x /* a */ ', 'inherit ROOM; /* a */ '):
                with self.subTest(newline=repr(nl), prefix=prefix):
                    tokens = lex(Source('d/test/room.c', (prefix + '#define ROOM NPC' + nl).encode()))
                    self.assertEqual([], [t for t in tokens if t.kind == 'directive'])
                    self.assertEqual(['#'], [t.text for t in tokens if t.text == '#'])

    def test_hashes_in_comments_strings_and_heredocs_stay_opaque(self):
        samples = ('// #define ROOM NPC\n', '/* #define ROOM NPC */', '/*\n#define ROOM NPC\n*/',
                   '"/* comment */ #define ROOM NPC"', '@TEXT\n#define ROOM NPC\nTEXT\n',
                   '@@TEXT\n#define ROOM NPC\nTEXT\n')
        for nl in ('\n', '\r\n'):
            for text in samples:
                with self.subTest(newline=repr(nl), text=text):
                    tokens = lex(Source('d/test/room.c', text.replace('\n', nl).encode()))
                    self.assertEqual([], [t for t in tokens if t.kind == 'directive'])

    def test_raw_offsets_and_line_state_after_multiline_tokens(self):
        for nl in ('\n', '\r\n'):
            for prefix in ('"雪\ntext" /* c */ ', '@TEXT\n雪\nTEXT; /* c */ '):
                with self.subTest(newline=repr(nl), prefix=prefix):
                    # A token's final physical line still contains code, even
                    # though its body consumed newlines. The following line resets.
                    directive = '#define LABEL "safe"' + nl
                    text = prefix.replace('\n', nl) + '#not_a_directive' + nl + '/* 雪 */ ' + directive
                    self.assert_directive(text, directive)
                    tokens = lex(Source('d/test/room.c', text.encode()))
                    self.assertEqual([directive], [t.text for t in tokens if t.kind == 'directive'])
            directive = '#define FIRST 1' + nl
            next_directive = '#define SECOND 2' + nl
            text = '/* 雪 */ ' + directive + '/* 二 */ ' + next_directive
            self.assert_directive(text, directive)
            self.assert_directive(text, next_directive)

    def test_original_fr01_real_cli_four_cases(self):
        for nl in ('\n', '\r\n'):
            for conditional in (False, True):
                with self.subTest(newline=repr(nl), conditional=conditional), tempfile.TemporaryDirectory() as temp:
                    source = Path(temp) / 'source'
                    (source / 'd').mkdir(parents=True)
                    directive = '#if FOO' if conditional else '#define set(key,value) ignored(key,value)'
                    text = ('inherit ROOM;\n/* audit */ ' + directive + '\n'
                            'void create(){set("short","must not extract");}\n'
                            + ('/* audit */ #endif\n' if conditional else '')).replace('\n', nl)
                    (source / 'd/probe.c').write_bytes(text.encode())
                    output = Path(temp) / 'output'
                    result = subprocess.run([sys.executable, '-m', 'tools.migration.cli', '--source-root', str(source),
                                             '--output-root', str(output)], cwd=REPOSITORY, capture_output=True, text=True)
                    self.assertEqual(0, result.returncode, result.stderr)
                    document = json.loads((output / 'static-rooms.json').read_bytes())
                    obj = document['objects'][0]
                    self.assertEqual([], fields(obj, 'short'))
                    # P2F10: parameter substitution has unknown boundary effects.
                    self.assertFalse(obj['supported_candidate'])
                    self.assertEqual('OUT_OF_SCOPE', obj['status'])
                    self.assertEqual([], obj['facts'])
                    self.assertIn('DRIVER_SEMANTICS_UNKNOWN' if conditional else 'UNRESOLVED_INHERITANCE',
                                  codes(document['findings']))


class P2F6RegressionTests(unittest.TestCase):
    BODY = 'void create(){set("short","safe");}\n'

    def check_directive(self, authored, nl, *, prefix='// 雪\ninherit ROOM;\n', after=None):
        directive = authored.replace('\n', nl)
        prefix = prefix.replace('\n', nl)
        after = self.BODY if after is None else after
        raw = (prefix + directive + after.replace('\n', nl)).encode('utf-8')
        source = Source('d/test/room.c', raw)
        tokens = lex(source)
        directives = [t for t in tokens if t.kind == 'directive']
        self.assertEqual(1, len(directives))
        token = directives[0]
        start = len(prefix.encode('utf-8'))
        self.assertEqual((start, start + len(directive.encode('utf-8'))), (token.start, token.end))
        self.assertEqual(directive, token.text)
        self.assertEqual(raw[token.start:token.end], token.text.encode('utf-8'))
        self.assertEqual(hashlib.sha256(raw).hexdigest(), source.sha256)
        parts = directive_parts(token)
        if after:
            self.assertTrue(any(t.text == 'void' and t.start >= token.end for t in tokens))
        obj, findings = extract(raw)
        self.assertNotEqual('QUARANTINED', obj['status'])
        self.assertNotIn('SOURCE_SYNTAX_ERROR', codes(findings))
        for record in obj['direct_inherits'] + obj['facts'] + findings:
            p = record['provenance']
            self.assertEqual(raw[p['byte_start']:p['byte_end_exclusive']], p['raw'].encode('utf-8'))
            self.assertEqual(source.sha256, p['source_sha256'])
            preceding = raw[:p['byte_start']].decode('utf-8')
            self.assertEqual((preceding.count('\n') + 1, len(preceding.rsplit('\n', 1)[-1]) + 1),
                             (p['line'], p['column']))
        return obj, findings, parts

    def assert_safe(self, obj):
        self.assertTrue(obj['supported_candidate'])
        self.assertEqual('PARTIAL', obj['status'])
        self.assertEqual('safe', fields(obj, 'short')[0]['value']['value'])

    def test_minimal_fr5_01_lf_crlf(self):
        for nl in ('\n', '\r\n'):
            with self.subTest(newline=repr(nl)):
                obj, _, parts = self.check_directive('#define LABEL 1 /* first\nsecond */\n', nl)
                self.assert_safe(obj)
                self.assertEqual(['define', 'LABEL', '1'], parts)

    def test_comment_positions_beginning_middle_end(self):
        for nl in ('\n', '\r\n'):
            for text in ('#define /* 雪\nsecond */ LABEL 1\n', '#define LABEL /* 雪\nsecond */ 1\n',
                         '#define LABEL 1 /* 雪\nsecond */\n'):
                with self.subTest(newline=repr(nl), text=text):
                    obj, _, parts = self.check_directive(text, nl)
                    self.assert_safe(obj)
                    self.assertEqual(['define', 'LABEL', '1'], parts)

    def test_trailing_replacement_tokens_after_close(self):
        for nl in ('\n', '\r\n'):
            obj, _, parts = self.check_directive('#define X /* first\nsecond */ replacement tokens\n', nl)
            self.assert_safe(obj)
            self.assertEqual(['define', 'X', 'replacement', 'tokens'], parts)

    def test_second_hash_after_close_stays_in_same_directive(self):
        for nl in ('\n', '\r\n'):
            obj, _, _ = self.check_directive('#define X /* first\nsecond */ #define Y 1\n', nl)
            self.assert_safe(obj)

    def test_multiple_multiline_comments(self):
        for nl in ('\n', '\r\n'):
            obj, _, parts = self.check_directive('#define LABEL /* one\ntwo */ 1 /* three\nfour */\n', nl)
            self.assert_safe(obj)
            self.assertEqual(['define', 'LABEL', '1'], parts)

    def test_quoted_comment_markers_and_escaped_quotes(self):
        values = ('"/* not a comment */"', '"/* not closed"', '"// not a line comment"',
                  r'"escaped \" /* still string"', r'"backslash \\"', "'/'", "'*'", r"'\''")
        for nl in ('\n', '\r\n'):
            for value in values:
                with self.subTest(newline=repr(nl), value=value):
                    obj, _, _ = self.check_directive('#define TEXT ' + value + '\n', nl)
                    self.assert_safe(obj)
            # LPC quoted symbols are opaque tokens, not unterminated character literals.
            obj, _, _ = self.check_directive("#define TEXT 'symbol /* first\nsecond */\n", nl)
            self.assert_safe(obj)

    def test_line_comments_do_not_open_block_comments(self):
        for nl in ('\n', '\r\n'):
            for tail in ('// comment', '// /* not block', '// " not string', '// trailing \\'):
                with self.subTest(newline=repr(nl), tail=tail):
                    obj, _, parts = self.check_directive('#define LABEL 1 ' + tail + '\n', nl)
                    self.assert_safe(obj)
                    self.assertEqual(['define', 'LABEL', '1'], parts)

    def test_backslash_newline_outside_comment(self):
        for nl in ('\n', '\r\n'):
            for text in ('#define LABEL \\\n1\n', '#define LABEL 1 /* comment */ \\\n2\n',
                         '#de\\\nfine RO\\\nOM NPC /* one\ntwo */\n'):
                with self.subTest(newline=repr(nl), text=text):
                    obj, _, parts = self.check_directive(text, nl)
                    if parts[1] == 'ROOM':
                        self.assertFalse(obj['supported_candidate'])
                        self.assertEqual([], obj['facts'])
                    else:
                        self.assert_safe(obj)

    def test_backslash_inside_multiline_comment(self):
        for nl in ('\n', '\r\n'):
            for space in ('', ' '):
                obj, _, parts = self.check_directive('#define LABEL 1 /* first' + space + '\\\nsecond */\n', nl)
                self.assert_safe(obj)
                self.assertEqual(['define', 'LABEL', '1'], parts)

    def test_other_directive_kinds_remain_conservative(self):
        for nl in ('\n', '\r\n'):
            for name in ('ROOM', 'set', 'create', '__DIR__'):
                with self.subTest(newline=repr(nl), undef=name):
                    obj, _, parts = self.check_directive('#undef /* first\nsecond */ ' + name + '\n', nl)
                    self.assertEqual(['undef', name], parts)
                    if name == 'ROOM':
                        self.assertFalse(obj['supported_candidate'])
                        self.assertEqual([], obj['facts'])
                    elif name in ('set', 'create'):
                        self.assertEqual([], fields(obj, 'short'))
            obj, findings, _ = self.check_directive('#include /* first\nsecond */ <missing.h>\n', nl)
            self.assertFalse(obj['supported_candidate'])
            self.assertEqual('OUT_OF_SCOPE', obj['status'])
            self.assertEqual([], obj['facts'])
            self.assertIn('UNRESOLVED_INCLUDE', codes(findings))
            for keyword in ('if FLAG', 'ifdef FLAG', 'ifndef FLAG', 'elif FLAG', 'else', 'endif'):
                with self.subTest(newline=repr(nl), conditional=keyword):
                    obj, findings, _ = self.check_directive('#' + keyword + ' /* first\nsecond */\n', nl)
                    self.assertFalse(obj['supported_candidate'])
                    self.assertEqual('OUT_OF_SCOPE', obj['status'])
                    self.assertEqual([], obj['facts'])
                    self.assertIn('DRIVER_SEMANTICS_UNKNOWN', codes(findings))

    def test_true_unterminated_block_comment_stays_quarantined(self):
        for nl in ('\n', '\r\n'):
            raw = ('inherit ROOM;\n#define LABEL 1 /* first\nsecond\n').replace('\n', nl).encode()
            obj, findings = extract(raw)
            self.assertEqual('QUARANTINED', obj['status'])
            self.assertEqual([], obj['facts'])
            finding = next(f for f in findings if f['code'] == 'SOURCE_SYNTAX_ERROR')
            self.assertIn('unterminated block comment', finding['reason'])
            p = finding['provenance']
            self.assertEqual(raw.index(b'/*'), p['byte_start'])
            self.assertEqual(raw[p['byte_start']:p['byte_end_exclusive']], p['raw'].encode())

    def test_controls_and_complete_comment_at_eof(self):
        for nl in ('\n', '\r\n'):
            obj, _, _ = self.check_directive('#define LABEL 1 /* comment */\n', nl)
            self.assert_safe(obj)
            obj, _, _ = self.check_directive('#define LABEL 1\n', nl, after='/* first\nsecond */\n' + self.BODY)
            self.assert_safe(obj)
            self.check_directive('#define LABEL 1 /* first\nsecond */', nl, after='')

    def test_p2f5_prefix_and_critical_macro_interaction(self):
        for nl in ('\n', '\r\n'):
            for name, replacement in [('ROOM', 'NPC'), ('set(k,v)', 'ignored(k,v)'), ('create', 'renamed')]:
                for prefix in ('inherit ROOM;\n/* prefix */ ', 'inherit ROOM;\nx /* previous\nline */ '):
                    obj, _, _ = self.check_directive('#define ' + name + ' /* first\nsecond */ ' + replacement + '\n',
                                                      nl, prefix=prefix)
                    self.assertEqual([], fields(obj, 'short'))
            raw = ('x /* prefix */ #define X /* first\nsecond */\n').replace('\n', nl).encode()
            self.assertEqual([], [t for t in lex(Source('x.c', raw)) if t.kind == 'directive'])

    def test_real_cli_fr5_01_matrix(self):
        cases = {'multiline': '#define LABEL 1 /* first\nsecond */\n',
                 'single_line': '#define LABEL 1 /* first second */\n',
                 'independent': '#define LABEL 1\n/* first\nsecond */\n',
                 'unclosed': '#define LABEL 1 /* first\nsecond\n'}
        for nl in ('\n', '\r\n'):
            for name, directive in cases.items():
                with self.subTest(newline=repr(nl), case=name), tempfile.TemporaryDirectory() as temp:
                    source = Path(temp) / 'source'
                    (source / 'd').mkdir(parents=True)
                    text = 'inherit ROOM;\n' + directive + ('' if name == 'unclosed' else self.BODY)
                    (source / 'd/probe.c').write_bytes(text.replace('\n', nl).encode())
                    output = Path(temp) / 'output'
                    result = subprocess.run([sys.executable, '-m', 'tools.migration.cli', '--source-root', str(source),
                                             '--output-root', str(output)], cwd=REPOSITORY, capture_output=True, text=True)
                    doc = json.loads((output / 'static-rooms.json').read_bytes())
                    obj = doc['objects'][0]
                    unclosed = name == 'unclosed'
                    self.assertEqual(1 if unclosed else 0, result.returncode, result.stderr)
                    self.assertEqual(not unclosed, obj['supported_candidate'])
                    self.assertEqual('QUARANTINED' if unclosed else 'PARTIAL', obj['status'])
                    self.assertEqual([] if unclosed else ['inherit', 'short'], [f['field'] for f in obj['facts']])
                    self.assertEqual({'SOURCE_SYNTAX_ERROR'} if unclosed else
                                     {'REQUIRES_SEMANTIC_REVIEW', 'UNSUPPORTED_CONSTRUCT'}, codes(doc['findings']))


class P2F7RegressionTests(unittest.TestCase):
    BODY = 'inherit ROOM;\nvoid create(){set("short","safe");set("exits",(["east":__DIR__"east"]));}\n'
    PAYLOADS = ('plain', '/*', '*/', '//', '"', "'", '"unterminated-looking',
                '/* unterminated-looking', '@MARKER', '@@MARKER',
                '#define set(k,v) ignored(k,v)', '#endif', '\\', '雪 中文 Unicode',
                'mixed " /* // @ @@ #define \\')

    def check_echo(self, authored, nl='\n', *, prefix='// 雪\n', after=None):
        after = self.BODY if after is None else after
        prefix, authored, after = (s.replace('\n', nl) for s in (prefix, authored, after))
        raw = (prefix + authored + after).encode()
        source = Source('d/test/room.c', raw)
        tokens = lex(source)
        token = next(t for t in tokens if t.kind == 'directive')
        start = len(prefix.encode())
        self.assertEqual((start, start + len(authored.encode())), (token.start, token.end))
        self.assertEqual(authored, token.text)
        self.assertEqual(raw[token.start:token.end], token.text.encode())
        self.assertEqual(hashlib.sha256(raw).hexdigest(), source.sha256)
        self.assertEqual(['echo'], directive_parts(token))
        if after:
            self.assertTrue(any(t.start >= token.end for t in tokens))
        obj, findings = extract(raw)
        self.assertNotEqual('QUARANTINED', obj['status'])
        self.assertNotIn('SOURCE_SYNTAX_ERROR', codes(findings))
        records = obj['direct_inherits'] + obj['facts'] + findings
        for record in records:
            p = record['provenance']
            a, b = p['byte_start'], p['byte_end_exclusive']
            self.assertEqual(raw[a:b], p['raw'].encode())
            self.assertEqual(source.sha256, p['source_sha256'])
            preceding = raw[:a].decode()
            self.assertEqual((preceding.count('\n') + 1, len(preceding.rsplit('\n', 1)[-1]) + 1),
                             (p['line'], p['column']))
        if obj['supported_candidate']:
            echo_finding = next(f for f in findings if f['provenance']['byte_start'] == token.start)
            self.assertEqual(authored, echo_finding['provenance']['raw'])
            self.assertEqual('UNSUPPORTED_CONSTRUCT', echo_finding['code'])
        return obj, findings, tokens

    def test_plain_echo_lf_crlf_eof(self):
        for nl in ('\n', '\r\n'):
            self.check_echo('#echo plain\n', nl)
        self.check_echo('#echo plain', after='')

    def test_empty_message(self):
        for nl in ('\n', '\r\n'):
            self.check_echo('#echo\n', nl)
        self.check_echo('#echo', after='')

    def test_raw_quote_comment_heredoc_payload_matrix(self):
        for payload in self.PAYLOADS:
            for nl in ('\n', '\r\n', ''):
                with self.subTest(payload=payload, newline=repr(nl)):
                    self.check_echo('#echo ' + payload + ('\n' if nl else ''), nl or '\n',
                                    after=None if nl else '')

    def test_trailing_backslash_does_not_continue(self):
        for nl in ('\n', '\r\n'):
            for space in ('', ' '):
                obj, _, tokens = self.check_echo('#echo' + space + '\\\n', nl,
                                                  after='#define ROOM NPC\n' + self.BODY)
                self.assertEqual(2, sum(t.kind == 'directive' for t in tokens))
                self.assertFalse(obj['supported_candidate'])

    def test_next_line_critical_macros_and_undef(self):
        hazards = ('define ROOM NPC', 'define set(k,v) ignored(k,v)', 'define create renamed',
                   'define __DIR__ "/wrong/"', 'undef ROOM', 'undef set', 'undef create', 'undef __DIR__')
        for payload in ('/*', '"', '@MARKER', '@@MARKER', '\\', 'plain'):
            for hazard in hazards:
                for nl in ('\n', '\r\n'):
                    with self.subTest(payload=payload, hazard=hazard, newline=repr(nl)):
                        obj, _, tokens = self.check_echo('#echo ' + payload + '\n', nl,
                                                          after='#' + hazard + ' /* closed */\n' + self.BODY)
                        self.assertEqual(2, sum(t.kind == 'directive' for t in tokens))
                        if 'ROOM' in hazard or hazard.startswith('define set('):
                            self.assertFalse(obj['supported_candidate'])
                            self.assertEqual([], obj['facts'])
                        elif '__DIR__' in hazard:
                            self.assertEqual([], fields(obj, 'exit'))
                            self.assertEqual(1, len(fields(obj, 'short')))
                        else:
                            self.assertEqual(['inherit'], [f['field'] for f in obj['facts']])

    def test_next_line_include_and_conditional(self):
        for payload in ('/*', '"', '@MARKER', '@@MARKER', '\\', 'plain'):
            for directive, code in (('#include <missing.h>\n', 'UNRESOLVED_INCLUDE'),
                                    ('#if FOO\n', 'DRIVER_SEMANTICS_UNKNOWN')):
                for nl in ('\n', '\r\n'):
                    obj, findings, tokens = self.check_echo('#echo ' + payload + '\n', nl,
                        after=directive + self.BODY + ('#endif\n' if directive.startswith('#if') else ''))
                    self.assertTrue(any(t.text.startswith(directive.rstrip()) for t in tokens[1:]))
                    self.assertFalse(obj['supported_candidate'])
                    self.assertEqual('OUT_OF_SCOPE', obj['status'])
                    self.assertEqual([], obj['facts'])
                    self.assertIn(code, codes(findings))

    def test_same_line_hash_is_message_not_hazard(self):
        for nl in ('\n', '\r\n'):
            for payload in ('#define ROOM NPC', '#define set(k,v) ignored(k,v)', '#endif'):
                obj, _, tokens = self.check_echo('#echo ' + payload + '\n', nl)
                self.assertEqual(1, sum(t.kind == 'directive' for t in tokens))
                self.assertEqual(['inherit', 'short', 'exit'], [f['field'] for f in obj['facts']])

    def test_exact_keyword_and_unknown_stay_generic(self):
        for word in ('echofoo', 'echo_value', 'Echo', 'unknown', 'echo1'):
            for nl in ('\n', '\r\n'):
                obj, findings = extract(('#' + word + ' /*\n' + self.BODY).replace('\n', nl).encode())
                self.assertEqual('QUARANTINED', obj['status'])
                self.assertIn('SOURCE_SYNTAX_ERROR', codes(findings))

    def test_spacing_and_trivia_before_keyword(self):
        for head in ('#echo', '# echo', '#   echo', '#\techo', '#/* before */echo', '#/* before\nend */ echo'):
            for nl in ('\n', '\r\n'):
                self.check_echo(head + ' /* " @ \\\n', nl)

    def test_split_keyword_uses_existing_continuation_only_in_head(self):
        for head in ('#ec\\\nho', '#e\\\nc\\\nho', '#\\\necho', '# \\\n ec\\\nho'):
            for nl in ('\n', '\r\n'):
                obj, _, tokens = self.check_echo(head + ' /* \\\n', nl,
                                                  after='#define set(k,v) ignored(k,v)\n' + self.BODY)
                self.assertEqual(2, sum(t.kind == 'directive' for t in tokens))
                self.assertFalse(obj['supported_candidate'])
                self.assertEqual('OUT_OF_SCOPE', obj['status'])
                self.assertEqual([], obj['facts'])
        token = lex(Source('d/x.c', b'#ec\\\nhofoo plain\n'))[0]
        self.assertEqual('echofoo', directive_parts(token)[0])

    def test_comment_prefix_positive_and_code_negative(self):
        for nl in ('\n', '\r\n'):
            for prefix in ('/* prefix */ ', '/* one */ /* two */ '):
                obj, _, _ = self.check_echo('#echo /*\n', nl, prefix=prefix,
                                              after='#define ROOM NPC\n' + self.BODY)
                self.assertFalse(obj['supported_candidate'])
            tokens = lex(Source('d/x.c', 'x /* prefix */ #echo plain\n'.replace('\n', nl).encode()))
            self.assertFalse(any(t.kind == 'directive' for t in tokens))

    def test_multiline_prefix_retains_p2f5_line_state(self):
        for nl in ('\n', '\r\n'):
            obj, _, _ = self.check_echo('#echo /*\n', nl, prefix='x /* old line\nnew line */ ',
                                          after='#define ROOM NPC\n' + self.BODY)
            self.assertFalse(obj['supported_candidate'])

    def test_unicode_raw_offsets_and_finding_provenance(self):
        for nl in ('\n', '\r\n'):
            self.check_echo('#echo 雪 中文 " /* \\\n', nl, prefix='/* 雪 */ ')

    def test_directive_parts_never_relexes_echo_payload(self):
        for payload in self.PAYLOADS:
            token = lex(Source('d/x.c', ('#echo ' + payload + '\n').encode()))[0]
            with patch('tools.migration.room_extractor.lex', side_effect=AssertionError('echo payload re-lexed')):
                self.assertEqual(['echo'], directive_parts(token))

    def test_true_non_echo_corruption_remains_quarantined(self):
        for text in ('"unterminated normal string', '/* unterminated comment', '#define X /* first\nsecond'):
            for nl in ('\n', '\r\n'):
                obj, findings = extract(text.replace('\n', nl).encode())
                self.assertEqual('QUARANTINED', obj['status'])
                self.assertEqual([], obj['facts'])
                self.assertIn('SOURCE_SYNTAX_ERROR', codes(findings))

    def test_authoritative_non_echo_directive_families(self):
        # Hand-reviewed doc/concepts/preprocessor families, not generated policy.
        bodies = ('define X 1', 'undef X', 'include <missing.h>', 'if FOO', 'ifdef FOO',
                  'ifndef FOO', 'elif FOO', 'else', 'endif', 'pragma strict_types')
        for body in bodies:
            for nl in ('\n', '\r\n'):
                authored = ('#' + body + ' /* first\nsecond */\n').replace('\n', nl)
                ts = lex(Source('d/x.c', (authored + 'void create(){}\n').encode()))
                self.assertEqual(authored, ts[0].text)
                self.assertEqual(body.split()[0], directive_parts(ts[0])[0])
        for head in ('@MARKER', '@@MARKER'):
            self.assertFalse(any(t.kind == 'directive' for t in lex(Source('x.c', (head+'\ntext\nMARKER\n').encode()))))

    def run_echo_cli(self, text, nl):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp) / 'source'
            (root / 'd').mkdir(parents=True)
            (root / 'd/probe.c').write_bytes(text.replace('\n', nl).encode())
            output = Path(temp) / 'output'
            result = subprocess.run([sys.executable, '-m', 'tools.migration.cli', '--source-root', str(root),
                                     '--output-root', str(output)], cwd=REPOSITORY, capture_output=True, text=True)
            self.assertEqual(0, result.returncode, result.stderr)
            document = json.loads((output / 'static-rooms.json').read_bytes())
            self.assertNotIn('SOURCE_SYNTAX_ERROR', codes(document['findings']))
            return document['objects'][0], document['findings']

    def test_real_cli_fr6_01(self):
        for nl in ('\n', '\r\n'):
            for directive in ('define ROOM NPC', 'define set(k,v) ignored(k,v)', 'define create renamed',
                              'define __DIR__ "/wrong/"', 'include <missing.h>', 'if FOO'):
                obj, findings = self.run_echo_cli('#echo /*\n#' + directive + '\n' + self.BODY, nl)
                if directive.startswith(('define ROOM', 'define set(', 'include', 'if')):
                    self.assertFalse(obj['supported_candidate'])
                    self.assertEqual('OUT_OF_SCOPE', obj['status'])
                    self.assertEqual([], obj['facts'])
                elif '__DIR__' in directive:
                    self.assertEqual(['inherit', 'short'], [f['field'] for f in obj['facts']])
                else:
                    self.assertEqual(['inherit'], [f['field'] for f in obj['facts']])

    def test_real_cli_fr6_02(self):
        for payload in ('"', '/*', '@MARKER', '@@MARKER', '\\', 'plain'):
            for ending in ('\n', '\r\n', ''):
                obj, _ = self.run_echo_cli('#echo ' + payload + ('\n' + self.BODY if ending else ''), ending or '\n')
                self.assertEqual('PARTIAL' if ending else 'OUT_OF_SCOPE', obj['status'])
                self.assertEqual(bool(ending), obj['supported_candidate'])
                self.assertEqual(['inherit', 'short', 'exit'] if ending else [], [f['field'] for f in obj['facts']])


class P2F8RegressionTests(unittest.TestCase):
    ROOT = ('#include "hazard.h"\ninherit ROOM;\n'
            'void create(){set("short","unsafe");set("exits",(["east":__DIR__ + "east"]));}\n')

    def check(self, header, expected='setter', *, extra=None, root=None, newline='\n'):
        sources = {'d/test/hazard.h': header, **(extra or {})}
        deps = {p: Source(p, t.replace('\n', newline).encode()) for p, t in sources.items()}
        raw = (root or self.ROOT).replace('\n', newline).encode()
        obj, findings = extract(raw, dependencies=deps)
        self.assertNotEqual('QUARANTINED', obj['status'])
        self.assertNotIn('SOURCE_SYNTAX_ERROR', codes(findings))
        self.assertNotIn('SOURCE_ENCODING_ISSUE', codes(findings))
        if expected == 'admission':
            self.assertFalse(obj['supported_candidate'])
            self.assertEqual('OUT_OF_SCOPE', obj['status'])
            self.assertEqual([], obj['facts'])
            self.assertIn('UNRESOLVED_INHERITANCE', codes(findings))
        else:
            self.assertTrue(obj['supported_candidate'])
            self.assertEqual('PARTIAL', obj['status'])
            self.assertEqual(['inherit'] if expected == 'setter' else
                             ['inherit', 'short'] if expected == 'dir' else ['inherit', 'short', 'exit'],
                             [f['field'] for f in obj['facts']])
        self.assertEqual(['ROOM'], [d['expression'] for d in obj['direct_inherits']])
        for p in [d['provenance'] for d in obj['direct_inherits']] + [f['provenance'] for f in obj['facts'] + findings]:
            self.assertEqual('d/test/room.c', p['source_path'])
            self.assertEqual(hashlib.sha256(raw).hexdigest(), p['source_sha256'])
            self.assertEqual(p['raw'].encode(), raw[p['byte_start']:p['byte_end_exclusive']])
        return obj, findings

    def test_included_set(self):
        for nl in ('\n', '\r\n'):
            self.check('void set(string key, mixed value) {}\n', newline=nl)

    def test_included_create(self):
        for nl in ('\n', '\r\n'):
            self.check('void create() {}\n', newline=nl)

    def test_included_room_inherit(self):
        self.check('inherit ROOM;\n', 'admission')

    def test_included_excluded_inherit(self):
        for base in ('NPC', 'ITEM', '"/std/item"'):
            self.check('inherit ' + base + ';\n', 'admission')

    def test_included_unknown_inherit(self):
        for base in ('CUSTOM', '"/std/unknown"'):
            self.check('inherit ' + base + ';\n', 'admission')

    def test_nested_set(self):
        self.check('#include <b.h>\n', extra={'include/b.h': 'mixed set(string k,mixed v){return 0;}\n'})

    def test_nested_create(self):
        self.check('#include <b.h>\n', extra={'include/b.h': 'void create(){}\n'})

    def test_nested_inherit(self):
        self.check('#include <b.h>\n', 'admission', extra={'include/b.h': 'inherit CUSTOM;\n'})

    def test_nested_critical_macros(self):
        for name, expected in [('ROOM', 'admission'), ('set', 'setter'), ('create', 'setter'), ('__DIR__', 'dir')]:
            for directive in ('define', 'undef'):
                self.check('#include <b.h>\n', expected,
                           extra={'include/b.h': '#' + directive + ' ' + name + (' other' if directive == 'define' else '') + '\n'})

    def test_nested_missing_include(self):
        _, findings = self.check('#include <b.h>\n', 'admission', extra={'include/b.h': '#include "missing.h"\n'})
        self.assertIn('UNRESOLVED_INCLUDE', codes(findings))

    def test_conditional_potential_definitions(self):
        for directive in ('if 0', 'ifdef CUSTOM', 'ifndef CUSTOM'):
            for code, expected in [('void set(string k,mixed v){}', 'setter'), ('void create(){}', 'setter'),
                                   ('inherit NPC;', 'admission')]:
                self.check('#' + directive + '\n' + code + '\n#endif\n', expected)

    def test_conditional_alternative_shapes_are_unresolved_not_root_corruption(self):
        _, findings = self.check('#if CUSTOM\nvoid set(){\n#else\nvoid set(){\n#endif\n}\n', 'admission')
        self.assertIn('UNRESOLVED_INCLUDE', codes(findings))

    def test_split_conditional_signatures_are_not_joined_into_harmless_definition(self):
        for text in ('void\n#if CUSTOM\nset\n#else\nhelper\n#endif\n(){}\n',
                     'void helper(\n#if CUSTOM\nint x\n#else\nstring x\n#endif\n){}\n'):
            _, findings = self.check(text, 'admission')
            self.assertIn('UNRESOLVED_INCLUDE', codes(findings))

    def test_cyclic_includes_preserve_hazards_and_determinism(self):
        for code, expected in [('', 'safe'), ('void set(){}', 'setter'), ('void create(){}', 'setter'),
                               ('inherit NPC;', 'admission'), ('#define ROOM NPC\n', 'admission')]:
            header = '#include "b.h"\n' + code + '\n'
            deps = {'d/test/b.h': '#include "hazard.h"\n'}
            a = self.check(header, expected, extra=deps)
            self.assertEqual(a, self.check(header, expected, extra=deps))
            self.check('#include "b.h"\n', expected,
                       extra={'d/test/b.h': '#include "hazard.h"\n' + code + '\n'})

    def test_repeated_include_keeps_hazards(self):
        for code, expected in [('void set(){}', 'setter'), ('void create(){}', 'setter'), ('inherit ROOM;', 'admission')]:
            self.check(code, expected, root='#include "hazard.h"\n' + self.ROOT)

    def test_relative_nested_paths_use_including_file_directory(self):
        self.check('#include "headers/a.h"\n', extra={
            'd/test/headers/a.h': '#include "sub/b.h"\n',
            'd/test/headers/sub/b.h': 'void set(){}\n',
            'd/test/sub/b.h': '// misleading root-relative safe header\n'})

    def test_include_path_escape_remains_unresolved(self):
        self.check('#include "../other.h"\n', 'admission', extra={'d/other.h': '// safe\n'})

    def test_comment_string_heredoc_and_nested_body_negatives(self):
        self.check('// void set(){}\n/* inherit NPC; */\n'
                   'string text="void create(){} inherit NPC;";\n'
                   'string long_text=@END\ninherit NPC;\nvoid set(){}\nEND\n;\n'
                   'void helper(){int set; create(); set=1;}\n', 'safe')

    def test_harmless_helper_and_near_names(self):
        self.check('int helper(){return 1;}\nvoid setter(){}\nvoid creator(){}\n', 'safe')

    def test_data_and_prototypes_are_not_function_definitions(self):
        self.check('int x; string foo; mapping data; int set; mixed set(string k,mixed v); void create();\n', 'safe')

    def test_combined_hazards_choose_strongest_boundary(self):
        for text, expected in [('void set(){} void create(){}', 'setter'), ('void set(){} inherit CUSTOM;', 'admission'),
                               ('void create(){} inherit ROOM;', 'admission'), ('#define __DIR__ "/wrong/"\nvoid set(){}', 'setter'),
                               ('#define set other\ninherit NPC;', 'admission')]:
            self.check(text, expected)

    def test_include_order_does_not_erase_compilation_unit_hazards(self):
        bare = self.ROOT.removeprefix('#include "hazard.h"\n')
        for code, expected in [('void set(){}', 'setter'), ('void create(){}', 'setter'), ('inherit CUSTOM;', 'admission')]:
            for root in ('#include "hazard.h"\n'+bare, bare.replace('inherit ROOM;\n', 'inherit ROOM;\n#include "hazard.h"\n'),
                         bare+'#include "hazard.h"\n'):
                self.check(code, expected, root=root)

    def test_malformed_dependency_does_not_quarantine_root(self):
        for text in ('/* unclosed', 'void set(){', 'int x', 'inherit NPC', '}', '\ufffd', '{ weird; }'):
            _, findings = self.check(text, 'admission')
            self.assertIn('UNRESOLVED_INCLUDE', codes(findings))

    def test_bad_dependency_manifest_is_quarantined_separately(self):
        # P2F13: an incomplete header structure is a fragment; genuine lexical
        # corruption still quarantines the dependency separately from the root.
        for raw, expected_code, header_status in ((b'void set(){', 0, 'OUT_OF_SCOPE'),
                                                  (b'/* unclosed', 1, 'QUARANTINED'),
                                                  (b'\xff', 1, 'QUARANTINED')):
            with tempfile.TemporaryDirectory() as tmp:
                root = Path(tmp)
                (root/'d/test').mkdir(parents=True)
                (root/'d/test/room.c').write_bytes(self.ROOT.encode())
                (root/'d/test/hazard.h').write_bytes(raw)
                doc, code = scan(root)
                self.assertEqual(expected_code, code)
                objects = {o['source_path']: o for o in doc['objects']}
                self.assertEqual(header_status, objects['d/test/hazard.h']['status'])
                self.assertEqual([], objects['d/test/hazard.h']['facts'])
                self.assertEqual('OUT_OF_SCOPE', objects['d/test/room.c']['status'])
                self.assertEqual([], objects['d/test/room.c']['facts'])
                self.assertFalse(any(f['code'].startswith('SOURCE_') and f['object_id']=='es2:d/test/room'
                                     for f in doc['findings']))

    def test_real_cli_fr7_matrix_and_root_provenance(self):
        cases = [('set', 'void set(string k,mixed v){}', 'setter'), ('create', 'void create(){}', 'setter'),
                 ('room', 'inherit ROOM;', 'admission'), ('npc', 'inherit NPC;', 'admission'),
                 ('unknown', 'inherit "/std/unknown";', 'admission'), ('helper', 'int helper(){return 1;}', 'safe')]
        cases += [('nested-'+name, text, expected) for name, text, expected in cases[:3]]
        cases += [('nested-missing', '#include "missing.h"\n', 'admission')]
        for nl in ('\n', '\r\n'):
            for name, text, expected in cases:
                with self.subTest(name=name, newline=repr(nl)), tempfile.TemporaryDirectory() as tmp:
                    root = Path(tmp)/'source'
                    (root/'d/test').mkdir(parents=True)
                    source = self.ROOT.replace('\n', nl).encode()
                    (root/'d/test/room.c').write_bytes(source)
                    header = '#include "b.h"\n' if name.startswith('nested-') else text
                    (root/'d/test/hazard.h').write_bytes(header.replace('\n', nl).encode())
                    if name.startswith('nested-'):
                        (root/'d/test/b.h').write_bytes(text.replace('\n', nl).encode())
                    result = subprocess.run([sys.executable, '-m', 'tools.migration.cli', '--source-root', str(root),
                                             '--output-root', str(Path(tmp)/'out')], cwd=REPOSITORY, capture_output=True)
                    self.assertEqual(0, result.returncode, result.stderr)
                    raw = (Path(tmp)/'out/static-rooms.json').read_bytes()
                    doc = json.loads(raw)
                    self.assertEqual(raw, canonical(doc))
                    obj = next(o for o in doc['objects'] if o['source_path']=='d/test/room.c')
                    self.assertEqual(expected != 'admission', obj['supported_candidate'])
                    self.assertEqual('OUT_OF_SCOPE' if expected=='admission' else 'PARTIAL', obj['status'])
                    self.assertEqual([] if expected=='admission' else ['inherit'] if expected=='setter' else ['inherit','short','exit'],
                                     [f['field'] for f in obj['facts']])
                    self.assertEqual(['ROOM'], [i['expression'] for i in obj['direct_inherits']])
                    for fact in obj['facts']:
                        p = fact['provenance']
                        self.assertEqual('d/test/room.c', p['source_path'])
                        self.assertEqual(source[p['byte_start']:p['byte_end_exclusive']], p['raw'].encode())


class P2F9RegressionTests(unittest.TestCase):
    BODY = 'set("short","safe");set("exits",(["east":__DIR__"east"]));'

    def check_case(self, prefix, expected='function', dependencies=None):
        return_obj = None
        for newline in ('\n', '\r\n'):
            raw = (prefix + '\n' + room(self.BODY)).replace('\n', newline).encode()
            deps = {p: Source(p, text.replace('\n', newline).encode())
                    for p, text in (dependencies or {}).items()}
            with self.subTest(prefix=prefix, newline=repr(newline)):
                obj, findings = extract(raw, dependencies=deps)
                self.assertNotIn('SOURCE_SYNTAX_ERROR', codes(findings))
                self.assertEqual(expected != 'inherit', obj['supported_candidate'])
                self.assertEqual('OUT_OF_SCOPE' if expected == 'inherit' else 'PARTIAL', obj['status'])
                self.assertEqual([] if expected == 'inherit' else ['inherit'] if expected == 'function'
                                 else ['inherit', 'short', 'exit'], [f['field'] for f in obj['facts']])
                # No synthetic source: every span still slices the authored root.
                for item in obj['direct_inherits'] + obj['facts'] + findings:
                    p = item['provenance']
                    self.assertEqual(p['raw'].encode(), raw[p['byte_start']:p['byte_end_exclusive']])
                return_obj = obj
        return return_obj

    def test_simple_set(self):
        self.check_case('#define S set\nvoid S(string key,mixed value) {}')

    def test_chain_set(self):
        self.check_case('#define A B\n#define B set\nvoid A() {}')

    def test_simple_create(self):
        self.check_case('#define C create\nvoid C() {}')

    def test_chain_create(self):
        self.check_case('#define A B\n#define B create\nvoid A() {}')

    def test_hidden_inherit(self):
        obj = self.check_case('#define I inherit\nI NPC;', 'inherit')
        self.assertEqual(['ROOM'], [x['symbol'] for x in obj['direct_inherits']])
        self.check_case('#define inherit helper\n', 'inherit')

    def test_chain_inherit(self):
        self.check_case('#define A B\n#define B inherit\nA NPC;', 'inherit')

    def test_inherit_operand_room(self):
        self.check_case('#define BASE ROOM\ninherit BASE;', 'inherit')

    def test_inherit_operand_npc(self):
        self.check_case('#define BASE NPC\ninherit BASE;', 'inherit')

    def test_inherit_operand_item(self):
        self.check_case('#define BASE ITEM\ninherit BASE;', 'inherit')

    def test_inherit_operand_custom(self):
        self.check_case('#define BASE CUSTOM\ninherit BASE;', 'inherit')

    def test_literal_and_chained_bases(self):
        for base in ('ROOM', 'NPC', 'ITEM', 'CUSTOM', '"/std/item"', '"/std/unknown"'):
            self.check_case(f'#define A B\n#define B {base}\ninherit A;', 'inherit')
        for base in EXCLUDED_LITERAL_BASES:
            self.check_case(f'#define BASE "{base}"\ninherit BASE;', 'inherit')

    def test_include_aliases(self):
        for target, use, expected in (('set', 'void A() {}', 'function'),
                                       ('create', 'void A() {}', 'function'),
                                       ('inherit', 'A NPC;', 'inherit'),
                                       ('NPC', 'inherit A;', 'inherit')):
            self.check_case('#include "a.h"\n' + use, expected, {'d/test/a.h': f'#define A {target}\n'})

    def test_nested_include_chains(self):
        for target, use, expected in (('set', 'void A() {}', 'function'),
                                       ('create', 'void A() {}', 'function'),
                                       ('inherit', 'A NPC;', 'inherit'),
                                       ('NPC', 'inherit A;', 'inherit')):
            self.check_case('#include "a.h"\n' + use, expected,
                            {'d/test/a.h': '#include "b.h"\n', 'd/test/b.h': f'#define A B\n#define B {target}\n'})

    def test_cross_file_definition_and_usage(self):
        for target, use, expected in (('set', 'void A() {}', 'function'),
                                       ('create', 'void A() {}', 'function'),
                                       ('inherit', 'A NPC;', 'inherit')):
            self.check_case(f'#define A {target}\n#include "a.h"', expected, {'d/test/a.h': use})
            self.check_case('#include "a.h"\n#include "b.h"', expected,
                            {'d/test/a.h': use, 'd/test/b.h': f'#define A {target}\n'})

    def test_include_cycle_back_to_root_preserves_include_veto(self):
        for header in ('#include "room.c"\n', '#include "a.h"\n'):
            text = header + room(self.BODY)
            deps = {'d/test/room.c': Source('d/test/room.c', text.encode()),
                    'd/test/a.h': Source('d/test/a.h', b'#include "room.c"\n')}
            obj, findings = extract(text, dependencies=deps)
            self.assertFalse(obj['supported_candidate'])
            self.assertEqual('OUT_OF_SCOPE', obj['status'])
            self.assertEqual([], obj['facts'])
            self.assertNotIn('SOURCE_SYNTAX_ERROR', codes(findings))

    def test_conditional_aliases_are_not_evaluated(self):
        for target, use, expected in (('set', 'void A() {}', 'function'), ('inherit', 'A NPC;', 'inherit')):
            self.check_case('#include "a.h"\n' + use, expected,
                            {'d/test/a.h': f'#if FLAG\n#define A {target}\n#endif\n'})
            obj, findings = extract(f'#if FLAG\n#define A {target}\n#endif\n' + use + room(self.BODY))
            self.assertFalse(obj['supported_candidate'])
            self.assertEqual([], obj['facts'])
            self.assertIn('DRIVER_SEMANTICS_UNKNOWN', codes(findings))

    def test_undef_and_redefinition_do_not_erase_hazards(self):
        # P2F10 explicitly makes ambiguous/cyclic signatures inadmissible.
        self.check_case('#define A set\n#undef A\n#define A helper\nvoid A() {}', 'inherit')
        self.check_case('#define A inherit\n#undef A\nA NPC;', 'inherit')

    def test_cycles_terminate_conservatively(self):
        self.check_case('#define A B\n#define B A\nvoid A() {}', 'inherit')
        self.check_case('#define A B\n#define B A\ninherit A;', 'inherit')
        self.check_case('#define A B\n#define B A\n', 'safe')
        self.check_case('#define A B\n#define B A\n#define B set\nvoid A() {}', 'inherit')

    def test_function_like_and_complex_macros(self):
        for target in ('set', 'create'):
            self.check_case(f'#define A(...) {target}(__VA_ARGS__)\nvoid A() {{}}', 'inherit')
            self.check_case(f'#define A {target}(string key,mixed value)\nvoid A {{}}', 'inherit')
            self.check_case(f'#define A B\n#define B(...) {target}(__VA_ARGS__)\nvoid A() {{}}', 'inherit')
        self.check_case('#define I(x) inherit x\nI(NPC);', 'inherit')
        self.check_case('#define BASE(x) x\ninherit BASE(NPC);', 'inherit')
        self.check_case('#define NAME(x) x\nvoid NAME(set) {}', 'inherit')
        self.check_case('#define NAME se ## t\nvoid NAME() {}', 'inherit')
        self.check_case('#define DECL(x) x\nDECL(inherit NPC);', 'inherit')

    def test_unused_critical_aliases(self):
        self.check_case('#define S set\n#define C create\n#define I inherit\n#define BASE NPC\n', 'safe')

    def test_harmless_helper_and_color_aliases(self):
        self.check_case('#define H helper\n#define COLOR red\nvoid H() {}', 'safe')
        self.check_case('#define H J\n#define J helper\nvoid H() {}', 'safe')

    def test_opaque_and_body_mentions_are_not_definitions(self):
        self.check_case('#define S set\n#define I inherit\n'
                        '// void S() {} I NPC;\n/* void S() {} I NPC; */\n'
                        'string text = "void S() {} I NPC;";\n'
                        'string help = @TEXT\nvoid S() {} I NPC;\nTEXT;\n'
                        '#echo void S() {} I NPC; " /*\n'
                        'void helper() { S("x",1); I; }', 'inherit')  # P2F10: actual inherit alias use.
        self.check_case('// #define S set\n/* #define S set */\n'
                        'string text = "#define S set";\n'
                        'string help = @TEXT\n#define S set\nTEXT;\n'
                        '#echo #define S set\nvoid S() {}', 'safe')

    def test_dir_aliases_never_normalize(self):
        for prefix in ('#define D __DIR__\n', '#define D A\n#define A __DIR__\n', '#include "a.h"\n'):
            obj, findings = extract(prefix + room('set("exits",(["east":D "east"]));'),
                                    dependencies={'d/test/a.h': Source('d/test/a.h', b'#define D __DIR__\n')})
            self.assertTrue(obj['supported_candidate'])
            self.assertEqual([], fields(obj, 'exit'))
            self.assertIn('DYNAMIC_EXPRESSION', codes(findings))

    def test_direct_critical_define_undef_policy(self):
        for directive in ('define', 'undef'):
            for name in ('set', 'create'):
                self.check_case(f'#{directive} {name}\n')
            self.check_case(f'#{directive} ROOM\n', 'inherit')
            obj, _ = extract(f'#{directive} __DIR__\n' + room(self.BODY))
            self.assertTrue(fields(obj, 'short'))
            self.assertFalse(fields(obj, 'exit'))

    def test_summary_shape_and_reachability(self):
        from tools.migration.room_extractor import MacroSummary
        macros = MacroSummary()
        text = '#define A B\n#define B set\n#define H helper\n#define F(x) create(x)\n#define O (helper)\n'
        text += '#define D __DIR__\n#define R ROOM\n#define L "/std/item"\n'
        for token in lex(Source('a.h', text.encode())):
            macros.add(token)
        self.assertEqual(({'A', 'B', 'set'}, False), macros.reach('A'))
        self.assertFalse(macros.definitions['O'][0][0])
        self.assertTrue(macros.definitions['F'][0][0])
        for name, target in [('F', 'create'), ('D', '__DIR__'), ('R', 'ROOM'), ('L', '/std/item')]:
            self.assertIn(target, macros.reach(name)[0])

    def test_directive_splices_comments_and_newlines(self):
        self.check_case('/* prefix */ #define A B\\\n\n#define B /* gap */ set\nvoid A() {}')
        self.check_case('#de\\\nfine S se\\\nt\nvoid S() {}')

    def test_real_cli_matrix(self):
        cases = [
            ('set', '#define S set\nvoid S() {}', {}, 'function'),
            ('create', '#define C create\nvoid C() {}', {}, 'function'),
            ('inherit', '#define I inherit\nI NPC;', {}, 'inherit'),
            ('npc', '#define BASE NPC\ninherit BASE;', {}, 'inherit'),
            ('item', '#define BASE ITEM\ninherit BASE;', {}, 'inherit'),
            ('chain-set', '#define A B\n#define B set\nvoid A() {}', {}, 'function'),
            ('chain-create', '#define A B\n#define B create\nvoid A() {}', {}, 'function'),
            ('chain-inherit', '#define A B\n#define B inherit\nA NPC;', {}, 'inherit'),
            ('included-set', '#include "a.h"\nvoid A() {}', {'a.h': '#define A set\n'}, 'function'),
            ('included-create', '#include "a.h"\nvoid A() {}', {'a.h': '#define A create\n'}, 'function'),
            ('included-inherit', '#include "a.h"\nA NPC;', {'a.h': '#define A inherit\n'}, 'inherit'),
            ('nested', '#include "a.h"\nvoid A() {}', {'a.h': '#include "b.h"\n', 'b.h': '#define A B\n#define B set\n'}, 'function'),
            ('unused', '#define S set\n', {}, 'safe'),
            ('helper', '#define H helper\nvoid H() {}', {}, 'safe'),
        ]
        for name, prefix, deps, expected in cases:
            for newline in ('\n', '\r\n'):
                with self.subTest(name=name, newline=repr(newline)), tempfile.TemporaryDirectory() as tmp:
                    source, output = Path(tmp)/'source', Path(tmp)/'output'
                    (source/'d/test').mkdir(parents=True)
                    for path, text in {'room.c': prefix + '\n' + room(self.BODY), **deps}.items():
                        (source/'d/test'/path).write_bytes(text.replace('\n', newline).encode())
                    result = subprocess.run([sys.executable, '-m', 'tools.migration.cli', '--source-root', str(source),
                                             '--output-root', str(output)], cwd=REPOSITORY, capture_output=True)
                    self.assertEqual(0, result.returncode, result.stderr)
                    document = json.loads((output/'static-rooms.json').read_bytes())
                    obj = next(o for o in document['objects'] if o['source_path'] == 'd/test/room.c')
                    self.assertEqual(expected != 'inherit', obj['supported_candidate'])
                    self.assertEqual('OUT_OF_SCOPE' if expected == 'inherit' else 'PARTIAL', obj['status'])
                    self.assertEqual([] if expected == 'inherit' else ['inherit'] if expected == 'function'
                                     else ['inherit', 'short', 'exit'], [f['field'] for f in obj['facts']])


class P2F10RegressionTests(unittest.TestCase):
    BODY = ('set("short","safe");set("name","name");set("long","text");'
            'set("outdoors",1);set("indoors",0);set("no_clean_up",1);set("no_fight",0);'
            'set("exits",(["east":__DIR__"east"]));')
    FIELDS = ['inherit', 'short', 'name', 'long', 'outdoors', 'indoors', 'no_clean_up', 'no_fight', 'exit']

    def check(self, definitions='', declaration='', body='', expected='OUT_OF_SCOPE',
              signature='void create()', dependencies=None, conditional_root=False):
        text = definitions + '\ninherit ROOM;\n' + declaration + '\n' + signature + '{' + self.BODY + body + '}\n'
        result = None
        for newline in ('\n', '\r\n'):
            raw = text.replace('\n', newline).encode()
            deps = {p: Source(p, content.replace('\n', newline).encode()) for p, content in (dependencies or {}).items()}
            with self.subTest(newline=repr(newline), definitions=definitions, body=body):
                obj, findings = extract(raw, dependencies=deps)
                result = obj
                self.assertNotIn('SOURCE_SYNTAX_ERROR', codes(findings))
                self.assertEqual(expected != 'OUT_OF_SCOPE', obj['supported_candidate'])
                self.assertEqual('OUT_OF_SCOPE' if expected == 'OUT_OF_SCOPE' else 'PARTIAL', obj['status'])
                wanted = [] if expected == 'OUT_OF_SCOPE' else ['inherit'] if expected == 'STATE' else self.FIELDS
                self.assertEqual(wanted, [f['field'] for f in obj['facts']])
                self.assertEqual([] if conditional_root else ['ROOM'], [d['symbol'] for d in obj['direct_inherits']])
                for item in obj['direct_inherits'] + obj['facts'] + findings:
                    p = item['provenance']
                    self.assertEqual(hashlib.sha256(raw).hexdigest(), p['source_sha256'])
                    self.assertEqual(p['raw'].encode(), raw[p['byte_start']:p['byte_end_exclusive']])
        return result

    def test_safe_return_type_alias(self):
        self.check('#define INT int', 'INT helper(){return 1;}', expected='SAFE')

    def test_complex_return_prefix(self):
        self.check('#define TYPE int; inherit NPC; int', 'TYPE helper(){return 1;}')

    def test_name_aliases(self):
        self.check('#define H helper', 'void H(){}', expected='SAFE')
        for name in ('set', 'create'):
            self.check(f'#define H {name}', 'void H(){}', expected='STATE')

    def test_safe_parameter_type(self):
        self.check('#define INT int', 'void helper(INT x){}', expected='SAFE')

    def test_signature_modifiers_parameter_names_and_defaults(self):
        self.check('#define MOD nomask\n#define ARG value', 'MOD void helper(int ARG){}', expected='SAFE')
        for signature in ('BAD void helper(){}', 'void helper(int BAD){}',
                          'void helper(int x=BAD){}', 'void helper(int x BAD string y){}'):
            self.check('#define BAD ){} inherit NPC; void tail(', signature)

    def test_other_body_semicolon_is_structural(self):
        self.check('#define RET return;', 'void helper(){RET}')

    def test_ambiguous_sibling_definitions(self):
        self.check('#include "a.h"\n#include "b.h"', body='M;', dependencies={
            'd/test/a.h':'#define M 1\n', 'd/test/b.h':'#define M 2\n'})

    def test_compound_literal_alias_remains_unknown(self):
        # The bounded classifier does not evaluate ANSI-like concatenations.
        self.check('#define ESC "escape"\n#define COLOR ESC+"[31m"', 'void helper(){write(COLOR);}')

    def test_inert_function_like_chain_without_substitution(self):
        self.check('#define ONE(x) N\n#define N 1', 'int helper(){return ONE(0);}', expected='SAFE')

    def test_parameter_structure_uncertain(self):
        self.check('#define P int x, string y', 'void helper(P){}')

    def test_parameter_injects_set(self):
        self.check('#define P ){} mixed set(string k,mixed v){return 0;} void tail(', 'void helper(P){}')

    def test_parameter_injects_create(self):
        self.check('#define P ){} void create(){} void tail(', 'void helper(P){}')

    def test_parameter_injects_inherit(self):
        self.check('#define P ){} inherit NPC; void tail(', 'void helper(P){}')

    def test_between_parameter_close_and_body(self):
        self.check('#define END ; inherit NPC; void tail()', 'void helper() END {}')
        self.check('#define END ; inherit NPC; void tail()', signature='void create() END')

    def test_function_like_signature(self):
        self.check('#define P(x) x', 'void helper(P(set)){}')
        self.check('#define P() ){} void set(){} void tail(', 'void helper(P()){}')

    def test_chained_signature(self):
        self.check('#define A B\n#define B ){} void set(){} void tail(', 'void helper(A){}')

    def test_cyclic_signature(self):
        self.check('#define A B\n#define B A', 'void helper(A){}')

    def test_create_set_alias(self):
        self.check('#define M set', body='M("short","other");', expected='STATE')

    def test_create_add_alias(self):
        self.check('#define M add', body='M("exits/east","/other");', expected='STATE')

    def test_create_delete_alias(self):
        self.check('#define M delete', body='M("exits/east");', expected='STATE')

    def test_create_create_alias(self):
        self.check('#define M create', body='M();', expected='STATE')

    def test_create_inherit_alias(self):
        self.check('#define M inherit', body='M NPC;')

    def test_body_closes_brace(self):
        self.check('#define M }', body='M;')

    def test_body_opens_brace(self):
        self.check('#define M {', body='M;')

    def test_body_semicolon_or_declaration(self):
        for replacement in (';', 'int x;', 'set("short","other");'):
            self.check('#define M ' + replacement, body='M;')

    def test_body_injects_function(self):
        self.check('#define M } mixed set(string k,mixed v){return 0;} void tail(){', body='M;')

    def test_body_injects_inherit(self):
        self.check('#define M } inherit NPC; void tail(){', body='M;')

    def test_function_like_body(self):
        self.check('#define M(x) set(x)', body='M("short");')
        self.check('#define DECL(x) x', body='DECL(set("short","other"));')
        self.check('#define WRAP(x) } x {', body='WRAP(inherit NPC;);')

    def test_body_chains(self):
        for target in ('set', 'add', 'delete', 'create'):
            self.check(f'#define A B\n#define B {target}', body='A("short","other");', expected='STATE')
        self.check('#define A B\n#define B inherit', body='A NPC;')
        self.check('#define A B\n#define B } void tail(){', body='A;')

    def test_body_cycle(self):
        self.check('#define A B\n#define B A', body='A;')
        self.check('#define A B\n#define B A', expected='SAFE')

    def test_other_body_constants(self):
        self.check('#define ONE 1\n#define LABEL "text"', 'int helper(){return ONE;} int other(){return LABEL!=0;}', expected='SAFE')

    def test_other_body_helper_alias(self):
        self.check('#define H helper', 'void helper(){} void other(){H();}', expected='SAFE')

    def test_other_body_escape(self):
        self.check('#define M } void tail(){', 'void helper(){M}')

    def test_other_body_hidden_inherit(self):
        self.check('#define M } inherit NPC; void tail(){', 'void helper(){M}')

    def test_other_body_hidden_functions(self):
        for name in ('set', 'create'):
            self.check(f'#define M }} void {name}(){{}} void tail(){{', 'void helper(){M}')

    def test_header_definition_root_use(self):
        self.check('#include "a.h"', 'void helper(P){}', dependencies={'d/test/a.h':'#define P ){} void set(){} void tail(\n'})
        self.check('#include "a.h"', body='M("short","other");', expected='STATE', dependencies={'d/test/a.h':'#define M set\n'})

    def test_root_definition_header_use(self):
        self.check('#define P ){} void set(){} void tail(\n#include "a.h"', dependencies={'d/test/a.h':'void helper(P){}\n'})

    def test_nested_definition_root_use(self):
        self.check('#include "a.h"', 'void helper(P){}', dependencies={'d/test/a.h':'#include "sub/b.h"\n','d/test/sub/b.h':'#define P ){} void set(){} void tail(\n'})

    def test_conditional_definitions(self):
        self.check('#include "a.h"', body='M("short","other");', expected='STATE', dependencies={'d/test/a.h':'#if FLAG\n#define M set\n#endif\n'})
        self.check('#if FLAG\n#define M set\n#endif', body='M("short","other");', conditional_root=True)

    def test_undef_redefinitions(self):
        self.check('#define M set\n#undef M', body='M("short","other");', expected='STATE')
        self.check('#define M set\n#undef M\n#define M helper', body='M("short","other");')

    def test_comment_prefix_and_continuations(self):
        self.check('/* prefix */ #define M ad\\\nd', body='M("short","other");', expected='STATE')
        self.check('#define M /* first\nsecond */ delete', body='M("exits/east");', expected='STATE')

    def test_opaque_negatives(self):
        self.check('#define BAD } inherit NPC; {\n#echo BAD #define M set " /*',
                   'void helper(){/* BAD */ string x="BAD";string y=@TXT\nBAD\nTXT;\n// BAD\n}',
                   body='/* BAD */ // BAD\n', expected='SAFE')

    def test_authored_provenance_and_no_synthetic_inherit(self):
        obj = self.check('#define BAD inherit NPC;', body='BAD;')
        self.assertEqual('inherit ROOM;', obj['direct_inherits'][0]['provenance']['raw'])
        self.assertEqual([], obj['facts'])

    def test_contained_object_mutator_calls(self):
        for replacement in ('set("short","other")', 'add("exits/east","/other")', 'delete("exits/east")'):
            self.check('#define M ' + replacement, body='M;', expected='STATE')

    def test_state_hazards_before_after_and_nested(self):
        for use in ('M("short","other");', 'if(0){M("short","other");}', 'helper(M("short","other"));'):
            self.check('#define M set', body=use, expected='STATE')
        obj, _ = extract('#define M set\n' + room('M("short","other");' + self.BODY))
        self.assertEqual(['inherit'], [f['field'] for f in obj['facts']])

    def test_parameter_independent_function_like(self):
        self.check('#define ONE(x) 1', 'int helper(){return ONE(0);}', body='ONE(0);', expected='SAFE')
        self.check('#define M(x) set("short","other")', body='M(0);', expected='STATE')

    def test_safe_constants_inside_create(self):
        self.check('#define ONE 1\n#define LABEL "text"', body='helper(ONE,LABEL);', expected='SAFE')

    def test_contained_mutator_in_other_body(self):
        self.check('#define M set("short","other")', 'void helper(){M;}', expected='SAFE')

    def test_source_backed_mapping_mutators(self):
        for name in ('_set', '_delete', 'map_delete', 'set_default_object'):
            self.check('#define M ' + name, body='M(query_entire_dbase(),"short",0);', expected='STATE')

    def test_pasting_stringification_and_unknown_calls(self):
        for replacement in ('se ## t', '# x', 'helper()', '(1+2)'):
            self.check('#define M ' + replacement, body='M;')

    def test_sibling_headers_and_cycle(self):
        self.check('#include "a.h"\n#include "b.h"', dependencies={
            'd/test/a.h':'#define P Q\n#include "b.h"\n',
            'd/test/b.h':'#include "a.h"\n#define Q ){} void set(){} void tail(\nvoid helper(P){}\n'})

    def test_unused_dangerous_definitions(self):
        self.check('#define S set\n#define I inherit\n#define BAD } inherit NPC; {', expected='SAFE')

    def test_effect_classes_and_cycle_termination(self):
        from tools.migration.room_extractor import MacroEffect, MacroSummary
        summary = MacroSummary()
        source = ('#define INT int\n#define ONE 1\n#define M set("short","other")\n'
                  '#define BAD } inherit NPC; {\n#define F(x) x\n#define A B\n#define B A\n')
        for token in lex(Source('macros.h', source.encode())):
            summary.add(token)
        for name, expected in [('INT',MacroEffect.INERT),('ONE',MacroEffect.INERT),
                               ('M',MacroEffect.CREATE_STATE_HAZARD),('BAD',MacroEffect.STRUCTURAL_BOUNDARY_HAZARD),
                               ('F',MacroEffect.UNKNOWN),('A',MacroEffect.UNKNOWN)]:
            self.assertEqual(expected, summary.effect(name))

    def test_real_cli_matrix(self):
        cases = [('parameter','#define P ){} void set(){} void tail(\n','void helper(P){}\n','',False),
                 ('set','#define M set\n','','M("short","other");',True),
                 ('add','#define M add\n','','M("exits/east","/other");',True),
                 ('delete','#define M delete\n','','M("exits/east");',True),
                 ('escape','#define M } void set(){} void tail(){\n','','M;',False),
                 ('inherit','#define M inherit\n','','M NPC;',False),
                 ('function','#define M(x) set(x)\n','','M("short");',False),
                 ('chain','#define M N\n#define N add\n','','M("short",1);',True),
                 ('cycle','#define M N\n#define N M\n','','M;',False)]
        for name, definition, declaration, body, candidate in cases:
            for layout in ('inline', 'header', 'nested'):
                for newline in ('\n','\r\n'):
                    with self.subTest(name=name,layout=layout,newline=repr(newline)), tempfile.TemporaryDirectory() as tmp:
                        source, output = Path(tmp)/'source', Path(tmp)/'output'
                        (source/'d').mkdir(parents=True)
                        files={'d/a.h':definition} if layout=='header' else {'d/a.h':'#include "b.h"\n','d/b.h':definition} if layout=='nested' else {}
                        files['d/room.c']=(definition if layout=='inline' else '#include "a.h"\n')+'inherit ROOM;\n'+declaration+'void create(){'+self.BODY+body+'}\n'
                        for path,text in files.items():(source/path).write_bytes(text.replace('\n',newline).encode())
                        result=subprocess.run([sys.executable,'-m','tools.migration.cli','--source-root',str(source),'--output-root',str(output)],cwd=REPOSITORY,capture_output=True)
                        self.assertEqual(0,result.returncode,result.stderr)
                        doc=json.loads((output/'static-rooms.json').read_bytes())
                        obj=next(o for o in doc['objects'] if o['source_path']=='d/room.c')
                        self.assertEqual(candidate,obj['supported_candidate'])
                        self.assertEqual(['inherit'] if candidate else [],[f['field'] for f in obj['facts']])


class P2F11RegressionTests(unittest.TestCase):
    FIRST = 'set("short","safe");\n'
    REST = ('set("name","name");set("long","text");set("outdoors",1);set("indoors",0);'
            'set("no_clean_up",1);set("no_fight",0);set("exits",(["east":__DIR__"east"]));\n')
    FIELDS = ['inherit', 'short', 'name', 'long', 'outdoors', 'indoors', 'no_clean_up', 'no_fight', 'exit']
    DIRECTIVES = {
        'define': '#define UNUSED 1\n', 'undef': '#undef UNUSED\n',
        'pragma': '#pragma warnings\n', 'echo': '#echo raw ; { #define set x " /* \\\n',
        'empty': '#include "empty.h"\n', 'macro': '#include "macro.h"\n',
        'unknown': '#unsupported message\n',
    }
    HEADERS = {'d/test/empty.h': '', 'd/test/macro.h': '#define UNUSED 1\n'}
    PLACEMENTS = ('start', 'middle', 'tail', 'arguments', 'before-semicolon', 'receiver',
                  'mapping', 'nested', 'helper-tail', 'top-level')

    def source(self, directive, placement):
        body, extra, prefix = self.FIRST + self.REST, '', ''
        if placement == 'start': body = directive + body
        elif placement == 'middle': body = self.FIRST + directive + self.REST
        elif placement == 'tail': body += directive
        elif placement == 'arguments': body += 'set(\n' + directive + '"short","other");\n'
        elif placement == 'before-semicolon': body += 'set("short","other")\n' + directive + ';\n'
        elif placement == 'receiver': body += 'set\n' + directive + '("short","other");\n'
        elif placement == 'mapping': body += 'set("exits",([\n' + directive + '"west":__DIR__"west"]));\n'
        elif placement == 'nested': body += 'if(flag){\n' + directive + 'helper();\n}\n'
        elif placement == 'helper-tail': extra = 'void helper(){\n' + directive + '}\n'
        elif placement == 'top-level': prefix = directive
        else: raise AssertionError(placement)
        return prefix + room(body, extra)

    def check(self, text, expected='FULL', dependencies=None):
        for nl in ('\n', '\r\n'):
            raw = text.replace('\n', nl).encode()
            deps = {p: Source(p, s.replace('\n', nl).encode()) for p, s in (dependencies or {}).items()}
            with self.subTest(newline=repr(nl)):
                obj, findings = extract(raw, dependencies=deps)
                self.assertEqual(expected != 'OOS', obj['supported_candidate'])
                self.assertEqual('OUT_OF_SCOPE' if expected == 'OOS' else 'PARTIAL', obj['status'])
                self.assertEqual([] if expected == 'OOS' else ['inherit'] if expected == 'STATE' else self.FIELDS,
                                 [f['field'] for f in obj['facts']])
                self.assertNotIn('SOURCE_SYNTAX_ERROR', codes(findings))
                self.assertEqual(['ROOM'], [d['symbol'] for d in obj['direct_inherits']])
                for item in obj['facts'] + obj['direct_inherits'] + findings:
                    p = item['provenance']
                    self.assertEqual(hashlib.sha256(raw).hexdigest(), p['source_sha256'])
                    self.assertEqual('d/test/room.c', p['source_path'])
                    self.assertEqual(raw[p['byte_start']:p['byte_end_exclusive']], p['raw'].encode())
                if expected == 'STATE':
                    self.assertTrue(any(f['code'] == 'UNSUPPORTED_CONSTRUCT' and f['prevents_supported_consumption']
                                        and f['provenance']['scope'] == 'create' for f in findings))

    def test_define_start(self):
        self.check(self.source(self.DIRECTIVES['define'], 'start'))

    def test_define_middle(self):
        self.check(self.source(self.DIRECTIVES['define'], 'middle'))

    def test_define_tail(self):
        self.check(self.source(self.DIRECTIVES['define'], 'tail'))

    def test_undef_tail(self):
        self.check(self.source(self.DIRECTIVES['undef'], 'tail'))

    def test_pragma_tail(self):
        self.check(self.source(self.DIRECTIVES['pragma'], 'tail'))

    def test_echo_tail(self):
        self.check(self.source(self.DIRECTIVES['echo'], 'tail'))

    def test_empty_include_tail(self):
        self.check(self.source(self.DIRECTIVES['empty'], 'tail'), 'STATE', self.HEADERS)

    def test_macro_only_include_tail(self):
        self.check(self.source(self.DIRECTIVES['macro'], 'tail'), 'STATE', self.HEADERS)

    def test_unknown_directive_tail(self):
        self.check(self.source(self.DIRECTIVES['unknown'], 'tail'), 'STATE')

    def test_directive_inside_set_arguments(self):
        self.check(self.source(self.DIRECTIVES['define'], 'arguments'), 'STATE')

    def test_directive_between_call_and_semicolon(self):
        self.check(self.source(self.DIRECTIVES['pragma'], 'before-semicolon'), 'STATE')

    def test_directive_between_receiver_and_opening(self):
        self.check(self.source(self.DIRECTIVES['define'], 'receiver'), 'STATE')

    def test_directive_inside_mapping(self):
        self.check(self.source(self.DIRECTIVES['define'], 'mapping'), 'STATE')

    def test_directive_inside_nested_call(self):
        self.check(room(self.FIRST + 'helper(\n#define UNUSED 1\nset("short","other"));\n' + self.REST), 'STATE')

    def test_nested_unsupported_block(self):
        self.check(self.source(self.DIRECTIVES['pragma'], 'nested'))

    def test_helper_tail_control(self):
        self.check(self.source(self.DIRECTIVES['define'], 'helper-tail'))

    def test_top_level_control(self):
        self.check(self.source(self.DIRECTIVES['define'], 'top-level'))

    def test_comment_prefixed_start_middle_tail(self):
        for place in ('start', 'middle', 'tail'):
            self.check(self.source('/* prefix */ #define UNUSED 1\n', place))

    def test_multiline_comment_start_middle_tail(self):
        for place in ('start', 'middle', 'tail'):
            self.check(self.source('#define UNUSED /* first\nsecond */ 1\n', place))

    def test_continued_keyword_start_middle_tail(self):
        for place in ('start', 'middle', 'tail'):
            self.check(self.source('#de\\\nfine UNUSED 1\n', place))

    def test_echo_payload_opaque_and_next_line_independent(self):
        self.check(self.source('#echo text ; { #define set x " /* \\\n#define UNUSED 1\n', 'tail'))
        self.check(self.source('#echo text ; { #define set x " /* \\\n#define ROOM NPC\n', 'tail'), 'OOS')

    def test_true_unfinished_runtime_statement(self):
        for prefix in ('', '#define UNUSED 1\n'):
            for nl in ('\n', '\r\n'):
                obj, findings = extract(room(prefix + 'set("short","unfinished")').replace('\n', nl))
                self.assertEqual('QUARANTINED', obj['status'])
                self.assertEqual([], obj['facts'])
                self.assertTrue(any(f['reason'] == 'unterminated create statement' for f in findings))

    def test_true_lexical_and_delimiter_errors(self):
        for broken in ('set("short",', 'set("short","unterminated);', '/* unclosed', 'set("short","x"];'):
            for nl in ('\n', '\r\n'):
                obj, findings = extract(room('#define UNUSED 1\n' + broken).replace('\n', nl))
                self.assertEqual('QUARANTINED', obj['status'])
                self.assertEqual([], obj['facts'])
                self.assertIn('SOURCE_SYNTAX_ERROR', codes(findings))

    def test_unfinished_runtime_before_tail_directive(self):
        for name in ('define', 'undef', 'pragma', 'echo'):
            for nl in ('\n', '\r\n'):
                obj, findings = extract(room('set("short","unfinished")\n' + self.DIRECTIVES[name]).replace('\n', nl))
                self.assertEqual('QUARANTINED', obj['status'])
                self.assertEqual([], obj['facts'])
                error = next(f for f in findings if f['code'] == 'SOURCE_SYNTAX_ERROR')
                self.assertEqual('unterminated create statement', error['reason'])
                self.assertEqual('set("short","unfinished")', error['provenance']['raw'])

    def test_interrupted_tail_include_may_supply_terminator(self):
        self.check(room(self.FIRST + self.REST + 'set("short","other")\n#include "end.h"\n'),
                   'STATE', {'d/test/end.h': ';'})

    def test_include_runtime_calls(self):
        for statement in ('set("short","other");', 'add("exits/east","/other");',
                          'delete("exits/east");', 'helper();'):
            self.check(self.source('#include "runtime.h"\n', 'tail'), 'STATE', {'d/test/runtime.h': statement})

    def test_include_prototype_and_data(self):
        for content in ('int helper();', 'int value=1;'):
            self.check(self.source('#include "safe.h"\n', 'middle'), 'STATE', {'d/test/safe.h': content})

    def test_missing_include(self):
        self.check(self.source('#include "missing.h"\n', 'tail'), 'OOS')

    def test_malformed_include_dependency(self):
        self.check(self.source('#include "bad.h"\n', 'tail'), 'OOS', {'d/test/bad.h': 'void broken(){'})

    def test_include_inherit_stronger_hazard(self):
        self.check(self.source('#include "bad.h"\n', 'tail'), 'OOS', {'d/test/bad.h': 'inherit NPC;'})

    def test_nested_include(self):
        self.check(self.source('#include "a.h"\n', 'tail'), 'STATE',
                   {'d/test/a.h':'#include "sub/b.h"\n', 'd/test/sub/b.h':'delete("exits/east");'})

    def test_nested_block_include_and_unknown(self):
        self.check(self.source(self.DIRECTIVES['empty'], 'nested'), 'STATE', self.HEADERS)
        self.check(self.source(self.DIRECTIVES['unknown'], 'nested'), 'STATE')

    def test_root_conditionals_still_out_of_scope(self):
        for name in ('if FLAG', 'ifdef FLAG', 'ifndef FLAG', 'elif FLAG', 'else', 'endif'):
            obj, findings = extract(self.source('#' + name + '\n', 'tail'))
            self.assertFalse(obj['supported_candidate'])
            self.assertEqual('OUT_OF_SCOPE', obj['status'])
            self.assertEqual([], obj['facts'])
            self.assertNotIn('SOURCE_SYNTAX_ERROR', codes(findings))

    def test_existing_macro_hazards_remain_stronger(self):
        self.check(self.source('#define UNUSED 1\n#define ROOM NPC\n', 'tail'), 'OOS')
        text = self.source('#define BAD } inherit NPC; {\n', 'tail').replace('set("short","safe");', 'BAD;')
        obj, _ = extract(text)
        self.assertFalse(obj['supported_candidate'])
        self.assertEqual('OUT_OF_SCOPE', obj['status'])
        self.assertEqual([], obj['facts'])

    def test_provenance_no_included_facts(self):
        self.check(self.source('#include "runtime.h"\n', 'tail'), 'STATE',
                   {'d/test/runtime.h':'set("short","injected");set("exits",(["west":"/injected"]));'})

    def test_early_and_late_facts_suppressed_together(self):
        self.check(room(self.FIRST + 'set(\n#pragma warnings\n"name","interrupted");\n' + self.REST), 'STATE')

    def test_directive_position_matrix(self):
        for name, directive in self.DIRECTIVES.items():
            for place in self.PLACEMENTS:
                expected = ('FULL' if place in ('helper-tail', 'top-level') else
                            'STATE' if name in ('empty', 'macro', 'unknown') or
                            place in ('arguments', 'before-semicolon', 'receiver', 'mapping') else 'FULL')
                with self.subTest(name=name, placement=place):
                    self.check(self.source(directive, place), expected, self.HEADERS)

    def test_original_reproducer_real_cli(self):
        for nl in ('\n', '\r\n'):
            with tempfile.TemporaryDirectory() as tmp:
                root, output = Path(tmp)/'source', Path(tmp)/'output'
                (root/'d').mkdir(parents=True)
                (root/'d/room.c').write_bytes(room('set("short","authored");\n#define UNUSED 1\n').replace('\n', nl).encode())
                result = subprocess.run([sys.executable, '-m', 'tools.migration.cli', '--source-root', str(root),
                                         '--output-root', str(output)], cwd=REPOSITORY, capture_output=True)
                self.assertEqual(0, result.returncode, result.stderr)
                document = json.loads((output/'static-rooms.json').read_bytes())
                obj = document['objects'][0]
                self.assertTrue(obj['supported_candidate'])
                self.assertEqual('PARTIAL', obj['status'])
                self.assertEqual(['inherit', 'short'], [f['field'] for f in obj['facts']])
                self.assertNotIn('SOURCE_SYNTAX_ERROR', codes(document['findings']))


class P2F12RegressionTests(unittest.TestCase):
    # Handwritten macro/literal/malformed triplets; no generated expansion oracle.
    CASES = {
        '{': ('inherit ROOM;\nvoid create() M\nset("short","x");\n}\n',
              'inherit ROOM;\nvoid create() {\nset("short","x");\n}\n',
              'inherit ROOM;\nvoid create()\nset("short","x");\n}\n'),
        '}': ('inherit ROOM;\nvoid create() {\nset("short","x");\nM\n',
              'inherit ROOM;\nvoid create() {\nset("short","x");\n}\n',
              'inherit ROOM;\nvoid create() {\nset("short","x");\n'),
        '(': ('inherit ROOM;\nvoid create() { set M "short","x"); }\n',
              'inherit ROOM;\nvoid create() { set("short","x"); }\n',
              'inherit ROOM;\nvoid create() { set "short","x"); }\n'),
        ')': ('inherit ROOM;\nvoid create() { set("short","x" M; }\n',
              'inherit ROOM;\nvoid create() { set("short","x"); }\n',
              'inherit ROOM;\nvoid create() { set("short","x"; }\n'),
        '[': ('inherit ROOM;\nvoid create() { set("exits", (M "east":"/d/test/room",])); }\n',
              'inherit ROOM;\nvoid create() { set("exits", (["east":"/d/test/room",])); }\n',
              'inherit ROOM;\nvoid create() { set("exits", ("east":"/d/test/room",])); }\n'),
        ']': ('inherit ROOM;\nvoid create() { set("exits", (["east":"/d/test/room",M)); }\n',
              'inherit ROOM;\nvoid create() { set("exits", (["east":"/d/test/room",])); }\n',
              'inherit ROOM;\nvoid create() { set("exits", (["east":"/d/test/room",)); }\n'),
    }

    def check(self, text, expected, dependencies=None):
        for newline in ('\n', '\r\n'):
            raw = text.replace('\n', newline).encode('utf-8')
            deps = {p: Source(p, t.replace('\n', newline).encode('utf-8'))
                    for p, t in (dependencies or {}).items()}
            with self.subTest(newline=repr(newline), source=text):
                r, fs = extract(raw, paths={'d/test/room.c'}, dependencies=deps)
                self.assertEqual(expected, r['status'])
                if expected == 'OUT_OF_SCOPE':
                    self.assertFalse(r['supported_candidate'])
                    self.assertEqual([], r['facts'])
                    self.assertEqual([], r['direct_inherits'])
                    self.assertEqual({'OUT_OF_SCOPE', 'DRIVER_SEMANTICS_UNKNOWN'}, codes(fs))
                    self.assertTrue(all(f['provenance']['raw'] in ('M', 'A', 'OPEN', 'DROP', 'ONE') for f in fs))
                elif expected == 'QUARANTINED':
                    self.assertEqual([], r['facts'])
                    self.assertIn('SOURCE_SYNTAX_ERROR', codes(fs))
                    # The original failed pairing still owns the diagnostic span.
                    with self.assertRaises(SourceError) as failure:
                        pairs(lex(Source('d/test/room.c', raw)))
                    error = next(f for f in fs if f['code'] == 'SOURCE_SYNTAX_ERROR')
                    self.assertEqual(str(failure.exception), error['reason'])
                    self.assertEqual(failure.exception.start, error['provenance']['byte_start'])
                    self.assertEqual(failure.exception.end, error['provenance']['byte_end_exclusive'])
                else:
                    self.assertTrue(r['supported_candidate'])
                    self.assertTrue(r['facts'])
                    self.assertNotIn('SOURCE_SYNTAX_ERROR', codes(fs))
                for f in fs + r['facts']:
                    p = f['provenance']
                    self.assertEqual('d/test/room.c', p['source_path'])
                    self.assertEqual(hashlib.sha256(raw).hexdigest(), p['source_sha256'])
                    self.assertEqual(raw[p['byte_start']:p['byte_end_exclusive']].decode(), p['raw'])

    def delimiter(self, mark):
        macro, _, _ = self.CASES[mark]
        self.check('#define M ' + mark + '\n' + macro, 'OUT_OF_SCOPE')

    def test_object_open_brace(self):
        self.delimiter('{')

    def test_object_close_brace(self):
        self.delimiter('}')

    def test_object_open_parenthesis(self):
        self.delimiter('(')

    def test_object_close_parenthesis(self):
        self.delimiter(')')

    def test_object_open_square(self):
        self.delimiter('[')

    def test_object_close_square(self):
        self.delimiter(']')

    def test_handwritten_controls_all_six(self):
        for _, literal_source, _ in self.CASES.values():
            self.check(literal_source, 'EXTRACTED')

    def test_true_malformed_all_six(self):
        for _, _, malformed in self.CASES.values():
            self.check(malformed, 'QUARANTINED')

    def test_unused_dangerous_all_six(self):
        for mark, (_, _, malformed) in self.CASES.items():
            self.check('#define M ' + mark + '\n' + malformed, 'QUARANTINED')

    def test_used_pairing_neutral_replacements(self):
        for replacement in ('1', '"text"', '"{(["', "'}'", ';', '#', '{}', '(1)', '[1]', '1 + 2'):
            self.check('#define M ' + replacement + '\ninherit ROOM;\nvoid create()\nset("short",M);\n}\n',
                       'QUARANTINED')

    def test_alias_chain_open_brace(self):
        self.check('#define A B\n#define B {\n' + self.CASES['{'][0].replace(' M', ' A'), 'OUT_OF_SCOPE')

    def test_alias_chain_close_parenthesis(self):
        self.check('#define A B\n#define B C\n#define C )\n' + self.CASES[')'][0].replace(' M', ' A'), 'OUT_OF_SCOPE')

    def test_iterative_long_alias_chain(self):
        definitions = '#define A N0\n' + ''.join(f'#define N{i} N{i + 1}\n' for i in range(1100)) + '#define N1100 {\n'
        self.check(definitions + self.CASES['{'][0].replace(' M', ' A'), 'OUT_OF_SCOPE')

    def test_used_cycle(self):
        self.check('#define A B\n#define B A\n' + self.CASES['{'][0].replace(' M', ' A'), 'OUT_OF_SCOPE')

    def test_unused_cycle(self):
        self.check('#define A B\n#define B A\n' + self.CASES['{'][2], 'QUARANTINED')

    def test_competing_pairing_definition(self):
        for definitions in ('#define M 1\n#define M {\n', '#define M {\n#undef M\n#define M 1\n'):
            self.check(definitions + self.CASES['{'][0], 'OUT_OF_SCOPE')

    def test_competing_neutral_definitions(self):
        self.check('#define M 1\n#define M "text"\n' + self.CASES['{'][0], 'QUARANTINED')

    def test_token_paste_can_hide_pairing_macro_identity(self):
        self.check('#define OPEN {\n#define M OP ## EN\n' + self.CASES['{'][0], 'OUT_OF_SCOPE')

    def test_function_open_brace_invocation(self):
        self.check('#define M() {\n' + self.CASES['{'][0].replace(' M', ' M()'), 'OUT_OF_SCOPE')

    def test_function_close_parenthesis_invocation(self):
        self.check('#define M() )\n' + self.CASES[')'][0].replace(' M', ' M()'), 'OUT_OF_SCOPE')

    def test_function_parameter_dependent_invocation(self):
        self.check('#define M(x) x\ninherit ROOM;\nvoid create() M({)\nset("short","x");\n}\n', 'OUT_OF_SCOPE')

    def test_function_drops_delimiter_argument(self):
        self.check('#define DROP(x)\ninherit ROOM;\nvoid create() { DROP({) set("short","x"); }\n', 'OUT_OF_SCOPE')

    def test_function_invalid_signature_invoked(self):
        self.check('#define M(x\n' + self.CASES['{'][0].replace(' M', ' M()'), 'OUT_OF_SCOPE')

    def test_function_name_is_not_invocation(self):
        self.check('#define M() {\n' + self.CASES['{'][0], 'QUARANTINED')

    def test_unused_function_macro(self):
        self.check('#define M() {\n' + self.CASES['{'][2], 'QUARANTINED')

    def test_alias_function_invoked_and_bare(self):
        definitions = '#define A B\n#define B M\n#define M() {\n'
        self.check(definitions + self.CASES['{'][0].replace(' M', ' A()'), 'OUT_OF_SCOPE')
        self.check(definitions + self.CASES['{'][0].replace(' M', ' A'), 'QUARANTINED')

    def test_internal_function_invocation_in_object_replacement(self):
        self.check('#define A M({)\n#define M(x)\n' + self.CASES['{'][0].replace(' M', ' A'), 'OUT_OF_SCOPE')

    def test_direct_header_definition(self):
        self.check('#include "delimiters.h"\n' + self.CASES['{'][0], 'OUT_OF_SCOPE',
                   {'d/test/delimiters.h': '#define M {\n'})

    def test_nested_header_definition(self):
        self.check('#include "a.h"\n' + self.CASES['{'][0], 'OUT_OF_SCOPE',
                   {'d/test/a.h': '#include "nested/b.h"\n', 'd/test/nested/b.h': '#define M {\n'})

    def test_sibling_root_header_aliases(self):
        self.check('#define A B\n#include "a.h"\n#include "b.h"\n' + self.CASES['{'][0].replace(' M', ' A'),
                   'OUT_OF_SCOPE', {'d/test/a.h': '#define B C\n', 'd/test/b.h': '#define C {\n'})

    def test_header_function_macro(self):
        self.check('#include <delimiters.h>\n' + self.CASES['{'][0].replace(' M', ' M()'), 'OUT_OF_SCOPE',
                   {'include/delimiters.h': '#define M() {\n'})

    def test_include_cycles_and_conditional_definitions(self):
        self.check('#include "a.h"\n' + self.CASES['{'][0], 'OUT_OF_SCOPE',
                   {'d/test/a.h': '#include "b.h"\n', 'd/test/b.h': '#include "a.h"\n#ifdef X\n#define M {\n#endif\n'})

    def test_safe_or_missing_include_is_not_pairing_evidence(self):
        for deps in ({}, {'d/test/a.h': ''}, {'d/test/a.h': '#define UNUSED {\n'},
                     {'d/test/a.h': 'int helper(){return 1;}\n'}, {'d/test/a.h': '"bad'}):
            self.check('#include "a.h"\n' + self.CASES['{'][2], 'QUARANTINED', deps)

    def test_opaque_comments(self):
        self.check('#define OPEN {\n// OPEN\n/* OPEN */\n' + self.CASES['{'][2], 'QUARANTINED')

    def test_opaque_strings(self):
        self.check('#define OPEN {\nstring label="OPEN";\n' + self.CASES['{'][2], 'QUARANTINED')

    def test_opaque_characters_and_symbols(self):
        self.check("#define O {\n#define OPEN {\nint label='O';\nmixed symbol='OPEN;\n" + self.CASES['{'][2], 'QUARANTINED')

    def test_opaque_heredoc(self):
        self.check('#define OPEN {\nstring label=@TEXT\nOPEN\nTEXT;\n' + self.CASES['{'][2], 'QUARANTINED')

    def test_opaque_echo_and_unused_replacement(self):
        self.check('#define OPEN {\n#echo OPEN({\n#define OTHER OPEN\n' + self.CASES['{'][2], 'QUARANTINED')

    def test_root_conditional_does_not_enter_gate(self):
        for directive in ('if 1', 'ifdef X', 'ifndef X', 'elif 1', 'else', 'endif'):
            with patch.object(RoomExtractor, 'pairing_uncertain_use', side_effect=AssertionError('must stay lazy')):
                r, fs = extract('#' + directive + '\n' + self.CASES['{'][2])
            self.assertEqual('OUT_OF_SCOPE', r['status'])
            self.assertNotIn('SOURCE_SYNTAX_ERROR', codes(fs))

    def test_paired_source_does_not_enter_gate(self):
        for source in (self.CASES['{'][1], '#define M {\n' + room('M; set("short","x");'),
                       '#define M "text"\n' + room('set("short",M);')):
            with patch.object(RoomExtractor, 'pairing_uncertain_use', side_effect=AssertionError('must stay lazy')):
                extract(source)

    def test_lexical_and_encoding_errors_bypass_gate(self):
        for invalid in (b'\xff', b'\0', '\ufffd'.encode(), b'"unterminated', b'/* unterminated'):
            raw = b'#define OPEN {\ninherit ROOM;\nvoid create() OPEN\n' + invalid
            with patch.object(RoomExtractor, 'pairing_uncertain_use', side_effect=AssertionError('must stay lazy')):
                r, fs = extract(raw)
            self.assertEqual('QUARANTINED', r['status'])
            self.assertEqual([], r['facts'])
            self.assertTrue(codes(fs) & {'SOURCE_ENCODING_ISSUE', 'SOURCE_SYNTAX_ERROR'})

    def test_original_reproducer_real_cli(self):
        text = '#define OPEN {\ninherit ROOM;\nvoid create() OPEN\n    set("short", "x");\n}\n'
        for newline in ('\n', '\r\n'):
            with tempfile.TemporaryDirectory() as directory:
                base = Path(directory); source = base / 'source'; (source / 'd').mkdir(parents=True)
                raw = text.replace('\n', newline).encode(); (source / 'd/room.c').write_bytes(raw)
                result = subprocess.run([sys.executable, '-m', 'tools.migration.cli', '--source-root', str(source),
                                         '--output-root', str(base / 'output')], cwd=REPOSITORY, capture_output=True)
                self.assertEqual(0, result.returncode, result.stderr)
                doc = json.loads((base / 'output/static-rooms.json').read_bytes())
                self.assertEqual('1.0.15', doc['extractor_version'])
                self.assertEqual('OUT_OF_SCOPE', doc['objects'][0]['status'])
                self.assertEqual([], doc['objects'][0]['facts'])
                self.assertNotIn('SOURCE_SYNTAX_ERROR', codes(doc['findings']))
                for f in doc['findings']:
                    self.assertEqual('OPEN', f['provenance']['raw'])
                    self.assertEqual(hashlib.sha256(raw).hexdigest(), f['provenance']['source_sha256'])


class P2F13RegressionTests(unittest.TestCase):
    # Include-site source, header, independently handwritten literal, true defect.
    CASES = {
        '{': ('inherit ROOM;\nvoid create()\n#include "part.h"\nset("short","雪");\n}\n',
              '{\n', 'inherit ROOM;\nvoid create(){set("short","雪");}\n',
              'inherit ROOM;\nvoid create()\nset("short","雪");}\n'),
        '}': ('inherit ROOM;\nvoid create(){set("short","雪");\n#include "part.h"\n',
              '}\n', 'inherit ROOM;\nvoid create(){set("short","雪");}\n',
              'inherit ROOM;\nvoid create(){set("short","雪");\n'),
        '(': ('inherit ROOM;\nvoid create\n#include "part.h"\n){set("short","雪");}\n',
              '(\n', 'inherit ROOM;\nvoid create(){set("short","雪");}\n',
              'inherit ROOM;\nvoid create){set("short","雪");}\n'),
        ')': ('inherit ROOM;\nvoid create(\n#include "part.h"\n{set("short","雪");}\n',
              ')\n', 'inherit ROOM;\nvoid create(){set("short","雪");}\n',
              'inherit ROOM;\nvoid create({set("short","雪");}\n'),
        '[': ('inherit ROOM;\nvoid create(){set("exits", (\n#include "part.h"\n"n":"/d/n"]));}\n',
              '[\n', 'inherit ROOM;\nvoid create(){set("exits", (["n":"/d/n"]));}\n',
              'inherit ROOM;\nvoid create(){set("exits", ("n":"/d/n"]));}\n'),
        ']': ('inherit ROOM;\nvoid create(){set("exits", (["n":"/d/n"\n#include "part.h"\n));}\n',
              ']\n', 'inherit ROOM;\nvoid create(){set("exits", (["n":"/d/n"]));}\n',
              'inherit ROOM;\nvoid create(){set("exits", (["n":"/d/n"));}\n'),
    }

    def check(self, source, headers=None, *, status='OUT_OF_SCOPE', exit_code=0,
              bad_headers=(), anchor=None, real_cli=False):
        for newline in ('\n', '\r\n'):
            with self.subTest(newline=repr(newline)), tempfile.TemporaryDirectory() as directory:
                base = Path(directory); root = base / 'source'; (root / 'd').mkdir(parents=True)
                authored = {'d/test.c': source, **(headers or {})}
                raw = {p: (t.encode() if isinstance(t, str) else t).replace(b'\n', newline.encode())
                       for p, t in authored.items()}
                for path, data in raw.items():
                    target = root / path; target.parent.mkdir(parents=True, exist_ok=True); target.write_bytes(data)
                if real_cli:
                    output = base / 'output'
                    run = subprocess.run([sys.executable, '-m', 'tools.migration.cli', '--source-root', str(root),
                                          '--output-root', str(output)], cwd=REPOSITORY, capture_output=True)
                    code = run.returncode; doc = json.loads((output / 'static-rooms.json').read_bytes())
                else:
                    doc, code = scan(root)
                self.assertEqual(exit_code, code)
                record = next(o for o in doc['objects'] if o['source_path'] == 'd/test.c')
                self.assertEqual(status, record['status'])
                diagnostics = [f for f in doc['findings'] if f['object_id'] == record['object_id']]
                if status in ('OUT_OF_SCOPE', 'QUARANTINED'):
                    self.assertFalse(record['supported_candidate']); self.assertEqual([], record['facts'])
                else:
                    self.assertTrue(record['supported_candidate']); self.assertTrue(record['facts'])
                if status == 'QUARANTINED':
                    self.assertIn('SOURCE_SYNTAX_ERROR', codes(diagnostics))
                else:
                    self.assertFalse(codes(diagnostics) & {'SOURCE_SYNTAX_ERROR', 'SOURCE_ENCODING_ISSUE'})
                if anchor:
                    for finding in diagnostics:
                        self.assertEqual('d/test.c', finding['provenance']['source_path'])
                        self.assertEqual(anchor.replace('\n', newline), finding['provenance']['raw'])
                for obj in doc['objects']:
                    if not obj['source_path'].endswith('.h'):
                        continue
                    self.assertFalse(obj['supported_candidate']); self.assertEqual([], obj['facts'])
                    self.assertEqual('QUARANTINED' if obj['source_path'] in bad_headers else 'OUT_OF_SCOPE', obj['status'])
                def provenance(value):
                    if isinstance(value, dict):
                        if 'byte_end_exclusive' in value:
                            data = raw[value['source_path']]; start = value['byte_start']; end = value['byte_end_exclusive']
                            self.assertEqual(hashlib.sha256(data).hexdigest(), value['source_sha256'])
                            self.assertEqual(data[start:end], bytes.fromhex(value['raw_hex']) if value['raw'] is None else value['raw'].encode())
                            self.assertEqual(data[:start].count(b'\n') + 1, value['line'])
                            line_start = data.rfind(b'\n', 0, start) + 1
                            self.assertEqual(len(data[line_start:start].decode('utf-8', errors='replace')) + 1, value['column'])
                        for child in value.values(): provenance(child)
                    elif isinstance(value, list):
                        for child in value: provenance(child)
                provenance(doc)

    def delimiter(self, delimiter):
        source, fragment, _, _ = self.CASES[delimiter]
        self.check(source, {'d/part.h': fragment}, anchor='#include "part.h"\n')

    def test_include_open_brace(self): self.delimiter('{')
    def test_include_close_brace(self): self.delimiter('}')
    def test_include_open_parenthesis(self): self.delimiter('(')
    def test_include_close_parenthesis(self): self.delimiter(')')
    def test_include_open_bracket(self): self.delimiter('[')
    def test_include_close_bracket(self): self.delimiter(']')

    def test_handwritten_literal_controls(self):
        for delimiter, (_, _, literal_source, _) in self.CASES.items():
            self.check(literal_source, status='PARTIAL' if delimiter in '[]' else 'EXTRACTED')

    def test_true_malformed_roots(self):
        for _, _, _, malformed in self.CASES.values():
            self.check(malformed, status='QUARANTINED', exit_code=1)

    def test_safe_include_preserves_original_error(self):
        for fragment in ('', '#define ONE 1\n', 'int helper(){return 1;}\n', ';\n', '#define UNUSED {\n'):
            self.check(self.CASES['{'][0], {'d/part.h': fragment}, status='QUARANTINED', exit_code=1)
        text = self.CASES['{'][0]
        with self.assertRaises(SourceError) as original: pairs(lex(Source('d/test.c', text.encode())))
        record, findings = extract(text, path='d/test.c', dependencies={'d/part.h': Source('d/part.h', b'')})
        error = next(f for f in findings if f['code'] == 'SOURCE_SYNTAX_ERROR')
        self.assertEqual(str(original.exception), error['reason'])
        self.assertEqual(original.exception.start, error['provenance']['byte_start'])
        self.assertEqual(original.exception.end, error['provenance']['byte_end_exclusive'])

    def test_nested_fragment_reaches_root_directive(self):
        self.check(self.CASES['{'][0], {'d/part.h': '#include "nested/open.h"\n', 'd/nested/open.h': '{\n'},
                   anchor='#include "part.h"\n')

    def test_standard_fragment(self):
        self.check(self.CASES['}'][0].replace('"part.h"', '<part.h>'), {'include/part.h': '}\n'},
                   anchor='#include <part.h>\n')

    def test_cooperating_fragments_paired_root(self):
        self.check('inherit ROOM;\nvoid create()\n#include "open.h"\nset("short","x");\n#include "close.h"\n',
                   {'d/open.h': '{\n', 'd/close.h': '}\n'})

    def test_repeated_cycle_include_graph_is_bounded(self):
        self.check(self.CASES['{'][0], {'d/part.h': '#include "cycle.h"\n#include "cycle.h"\n',
                                      'd/cycle.h': '#include "part.h"\n{\n'}, anchor='#include "part.h"\n')

    def test_sibling_provenance_uses_reaching_include(self):
        self.check('#include "safe.h"\n' + self.CASES['{'][0], {'d/safe.h':'#define ONE 1\n', 'd/part.h':'{\n'},
                   anchor='#include "part.h"\n')

    def test_unreferenced_raw_header_does_not_excuse_root(self):
        self.check(self.CASES['{'][3], {'d/unreferenced.h':'{\n'}, status='QUARANTINED', exit_code=1)

    def test_standalone_header_delimiters(self):
        for delimiter in '{}()[]':
            self.check(room('set("short","x");'), {'include/fragment.h': delimiter+'\n'}, status='EXTRACTED')

    def test_standalone_structural_fragments_beyond_pairs(self):
        for fragment in ('inherit ROOM', 'void create(){set("short","x")}', 'inherit ROOM;\nvoid create(){set("exits", (["n":]));}'):
            self.check(room('set("short","x");'), {'include/fragment.h':fragment}, status='EXTRACTED')

    def test_balanced_header_never_promoted_or_emits_facts(self):
        self.check(room('set("short","root");'), {'d/fake_room.h':room('set("short","header");')}, status='EXTRACTED')

    def test_header_encoding_corruption(self):
        for raw in (b'\xff', b'\0', '\ufffd'.encode()):
            self.check(room('set("short","x");'), {'include/bad.h':raw}, status='EXTRACTED', exit_code=1,
                       bad_headers=('include/bad.h',))

    def test_header_lexical_corruption(self):
        for raw in ('"unfinished', '/* unfinished', '@TEXT\nunfinished', '#define X "unfinished\n'):
            self.check(room('set("short","x");'), {'include/bad.h':raw}, status='EXTRACTED', exit_code=1,
                       bad_headers=('include/bad.h',))

    def test_existing_quoted_symbol_policy_is_not_redefined(self):
        self.check(room('set("short","x");'), {'include/symbol.h':"'symbol\n'{'\n"}, status='EXTRACTED')

    def test_valid_root_with_lexically_bad_header(self):
        self.check('#include "bad.h"\n'+room('set("short","x");'), {'d/bad.h':'"unfinished'},
                   exit_code=1, bad_headers=('d/bad.h',))

    def test_real_root_defect_with_lexically_bad_header(self):
        for bad in ('"unfinished', '#define X "unfinished\n{\n'):
            self.check(self.CASES['{'][0], {'d/part.h':bad}, status='QUARANTINED', exit_code=1,
                       bad_headers=('d/part.h',))

    def test_missing_include_policy_unchanged(self):
        self.check('#include "missing.h"\n'+room('set("short","x");'))
        self.check(self.CASES['{'][0], status='QUARANTINED', exit_code=1)

    def test_macro_recovery_precedes_raw_fragment_recovery(self):
        with patch.object(RoomExtractor, 'include_pairing_uncertain_use', side_effect=AssertionError('macro already explains failure')):
            record, findings = extract('#define OPEN {\ninherit ROOM;\nvoid create() OPEN set("short","x");}')
        self.assertEqual('OUT_OF_SCOPE', record['status']); self.assertEqual([], record['facts'])

    def test_normal_paired_root_does_not_enter_new_gate(self):
        with patch.object(RoomExtractor, 'include_pairing_uncertain_use', side_effect=AssertionError('must be lazy')):
            self.check('#include "safe.h"\n'+room('set("short","x");'), {'d/safe.h':'#define X 1\n'}, status='PARTIAL')

    def test_root_conditionals_bypass_new_gate(self):
        with patch.object(RoomExtractor, 'include_pairing_uncertain_use', side_effect=AssertionError('must be lazy')):
            for directive in ('if 1', 'ifdef X', 'ifndef X', 'elif 1', 'else', 'endif'):
                self.check('#'+directive+'\n'+self.CASES['{'][3])

    def test_root_lexical_and_encoding_errors_bypass_new_gate(self):
        with patch.object(RoomExtractor, 'include_pairing_uncertain_use', side_effect=AssertionError('must be lazy')):
            for raw in (b'\xff', b'\0', b'"unfinished', b'/* unfinished'):
                record, findings = extract(raw)
                self.assertEqual('QUARANTINED', record['status'])

    def test_original_fr12_reproducer_real_cli(self):
        self.check('inherit ROOM;\nvoid create()\n#include "open.h"\n    set("short", "x");\n}\n',
                   {'d/open.h':'{\n'}, anchor='#include "open.h"\n', real_cli=True)



class P2F14RegressionTests(unittest.TestCase):
    # Independently authored inputs/expectations, never extractor-generated.
    CASES = [
        ('include-function-invocation', '#define END() ;\ninherit ROOM\n#include "tail.h"\n', {'d/tail.h': 'END()\n'}, 'OUT_OF_SCOPE'),
        ('include-neutral-invocation', '#define END() 1\ninherit ROOM\n#include "tail.h"\n', {'d/tail.h': 'END()\n'}, 'QUARANTINED'),
        ('direct', 'inherit ROOM\n#include "semi.h"\nvoid create() {}\n', {'d/semi.h': ';\n'}, 'OUT_OF_SCOPE'),
        ('at-eof', 'inherit ROOM\n#include "semi.h"\n', {'d/semi.h': ';\n'}, 'OUT_OF_SCOPE'),
        ('nested', 'inherit ROOM\n#include "outer.h"\nvoid create() {}\n', {'d/outer.h': '#include "semi.h"\n', 'd/semi.h': ';\n'}, 'OUT_OF_SCOPE'),
        ('standard', 'inherit ROOM\n#include <semi.h>\nvoid create() {}\n', {'include/semi.h': ';\n'}, 'OUT_OF_SCOPE'),
        ('safe-sibling', '#include "safe.h"\ninherit ROOM\n#include "semi.h"\nvoid create() {}\n', {'d/safe.h': 'int helper() { return 1; }\n', 'd/semi.h': ';\n'}, 'OUT_OF_SCOPE'),
        ('literal-base', 'inherit "/std/room"\n#include "semi.h"\nvoid create() {}\n', {'d/semi.h': ';\n'}, 'OUT_OF_SCOPE'),
        ('whole-expression', 'inherit\n#include "base.h"\nvoid create() {}\n', {'d/base.h': 'ROOM;\n'}, 'OUT_OF_SCOPE'),
        ('macro-object', '#define END ;\ninherit ROOM END\nvoid create() {}\n', {}, 'OUT_OF_SCOPE'),
        ('macro-alias', '#define END ;\n#define FIN END\ninherit ROOM FIN\nvoid create() {}\n', {}, 'OUT_OF_SCOPE'),
        ('macro-function', '#define END() ;\ninherit ROOM END()\nvoid create() {}\n', {}, 'OUT_OF_SCOPE'),
        ('macro-header', '#include "macros.h"\ninherit ROOM END\nvoid create() {}\n', {'d/macros.h': '#define END ;\n'}, 'OUT_OF_SCOPE'),
        ('literal', 'inherit ROOM;\nvoid create() {}\n', {}, 'EXTRACTED'),
        ('literal-fact', 'inherit ROOM;\nvoid create() { set("short", "x"); }\n', {}, 'EXTRACTED'),
        ('missing-terminator', 'inherit ROOM\nvoid create() {}\n', {}, 'QUARANTINED'),
        ('empty-include', 'inherit ROOM\n#include "empty.h"\nvoid create() {}\n', {'d/empty.h': ''}, 'QUARANTINED'),
        ('safe-include', 'inherit ROOM\n#include "safe.h"\nvoid create() {}\n', {'d/safe.h': 'int helper() { return 1; }\n'}, 'QUARANTINED'),
        ('unused-macro', '#define END ;\ninherit ROOM\nvoid create() {}\n', {}, 'QUARANTINED'),
        ('neutral-used-macro', '#define BASE ROOM\ninherit BASE\nvoid create() {}\n', {}, 'QUARANTINED'),
        ('unreferenced-header', 'inherit ROOM\nvoid create() {}\n', {'d/semi.h': ';\n'}, 'QUARANTINED'),
        ('missing-include', 'inherit ROOM\n#include "missing.h"\nvoid create() {}\n', {}, 'OUT_OF_SCOPE'),
        ('whole-literal', 'inherit\n#include "base.h"\nvoid create() {}\n', {'d/base.h': '"/std/room";\n'}, 'OUT_OF_SCOPE'),
        ('suffix', 'inherit "/std/"\n#include "tail.h"\n', {'d/tail.h': '+ "room";\n'}, 'OUT_OF_SCOPE'),
        ('unrelated-missing', '#include "missing.h"\ninherit ROOM\nvoid create() {}\n', {}, 'QUARANTINED'),
        ('unrelated-terminator', '#include "semi.h"\ninherit ROOM\nvoid create() {}\n', {'d/semi.h': ';\n'}, 'QUARANTINED'),
        ('safe-data', 'inherit ROOM\n#include "safe.h"\nvoid create() {}\n', {'d/safe.h': 'int x;\n'}, 'QUARANTINED'),
        ('untyped-helper', 'inherit ROOM\n#include "safe.h"\nvoid create() {}\n', {'d/safe.h': 'helper(){return 1;}\n'}, 'QUARANTINED'),
        ('missing-nested', 'inherit ROOM\n#include "outer.h"\n', {'d/outer.h': '#include "missing.h"\n'}, 'OUT_OF_SCOPE'),
        ('missing-standard', 'inherit ROOM\n#include <missing.h>\n', {}, 'OUT_OF_SCOPE'),
        ('include-macro-path', 'inherit ROOM\n#include UNKNOWN\n', {}, 'OUT_OF_SCOPE'),
        ('cross-header', '#include "a.h"\n#include "b.h"\ninherit ROOM END\n', {'d/a.h': '#define END FIN\n', 'd/b.h': '#define FIN ;\n'}, 'OUT_OF_SCOPE'),
        ('cycle', '#define END FIN\n#define FIN END\ninherit ROOM END\n', {}, 'OUT_OF_SCOPE'),
        ('competing', '#define END 1\n#define END 2\ninherit ROOM END\n', {}, 'OUT_OF_SCOPE'),
        ('paste', '#define END A ## B\ninherit ROOM END\n', {}, 'OUT_OF_SCOPE'),
        ('invalid-function', '#define END(x ;\ninherit ROOM END()\n', {}, 'OUT_OF_SCOPE'),
        ('parameter', '#define END(x) x\ninherit ROOM END(1)\n', {}, 'OUT_OF_SCOPE'),
        ('neutral-number', '#define V 1\ninherit ROOM V\nvoid create(){}\n', {}, 'QUARANTINED'),
        ('neutral-function', '#define V() 1\ninherit ROOM V()\nvoid create(){}\n', {}, 'QUARANTINED'),
        ('uninvoked-function', '#define V() ;\ninherit ROOM V\nvoid create(){}\n', {}, 'QUARANTINED'),
        ('later-macro', '#define END ;\ninherit ROOM\nvoid create(){END}\n', {}, 'QUARANTINED'),
        ('later-untyped-macro', '#define END ;\ninherit ROOM\ncreate(){END}\n', {}, 'QUARANTINED'),
        ('later-include', 'inherit ROOM\nvoid create(){\n#include "semi.h"\n}\n', {'d/semi.h': ';\n'}, 'QUARANTINED'),
        ('unused-define-at-boundary', 'inherit ROOM\n#define END ;\nvoid create(){}\n', {}, 'QUARANTINED'),
        ('raw-echo', 'inherit ROOM\n#echo ; raw "\nvoid create(){}\n', {}, 'QUARANTINED'),
        ('pragma', 'inherit ROOM\n#pragma strict_types\nvoid create(){}\n', {}, 'QUARANTINED'),
        ('undef', 'inherit ROOM\n#undef END\nvoid create(){}\n', {}, 'QUARANTINED'),
        ('later-authored-semicolon', 'inherit ROOM\nvoid create(){set("short","x");}\n', {}, 'QUARANTINED'),
        ('include-before-later-authored-semicolon', 'inherit ROOM\n#include "semi.h"\nvoid create(){set("short","x");}\n', {'d/semi.h': ';\n'}, 'OUT_OF_SCOPE'),
        ('uncertain-second', 'inherit ROOM;\ninherit ROOM\n#include "semi.h"\nvoid create(){}\n', {'d/semi.h': ';\n'}, 'OUT_OF_SCOPE'),
        ('uncertain-first', 'inherit ROOM\n#include "semi.h"\ninherit ROOM;\nvoid create(){}\n', {'d/semi.h': ';\n'}, 'OUT_OF_SCOPE'),
    ]

    def check(self, text, headers, status):
        for newline in ('\n', '\r\n'):
            raw = text.replace('\n', newline).encode()
            deps = {p: Source(p, h.replace('\n', newline).encode()) for p, h in headers.items()}
            record, findings = extract(raw, path='d/probe.c', dependencies=deps)
            with self.subTest(newline=repr(newline), text=text):
                self.assertEqual(status, record['status'])
                if status == 'OUT_OF_SCOPE':
                    self.assertFalse(record['supported_candidate'])
                    self.assertEqual([], record['facts'])
                    self.assertEqual([], record['direct_inherits'])
                    self.assertEqual([], record['category_candidates'])
                    self.assertNotIn('SOURCE_SYNTAX_ERROR', codes(findings))
                    self.assertIn('DRIVER_SEMANTICS_UNKNOWN', codes(findings))
                elif status == 'QUARANTINED':
                    self.assertEqual([], record['facts'])
                    error = next(f for f in findings if f['code'] == 'SOURCE_SYNTAX_ERROR')
                    self.assertEqual('unterminated inherit', error['reason'])
                    self.assertEqual('inherit', error['provenance']['raw'])
                for f in findings + record['facts']:
                    p = f['provenance']
                    self.assertEqual(hashlib.sha256(raw).hexdigest(), p['source_sha256'])
                    self.assertEqual(raw[p['byte_start']:p['byte_end_exclusive']].decode(), p['raw'])
        return record, findings

    def test_pending_declaration_matrix(self):
        for name, text, headers, status in self.CASES:
            with self.subTest(case=name): self.check(text, headers, status)

    def test_long_alias_chain(self):
        defs = ''.join(f'#define A{i} A{i+1}\n' for i in range(1100))+'#define A1100 ;\n'
        self.check(defs+'inherit ROOM A0\n', {}, 'OUT_OF_SCOPE')

    def test_finding_anchors(self):
        for text, headers, anchor in [
            ('inherit ROOM\n#include "a.h"\n', {'d/a.h':'#include "nested/semi.h"\n','d/nested/semi.h':';'}, '#include "a.h"\n'),
            ('inherit ROOM\n#include "missing.h"\n', {}, '#include "missing.h"\n'),
            ('#define END ;\ninherit ROOM END\n', {}, 'END'),
        ]:
            _, ff = self.check(text, headers, 'OUT_OF_SCOPE')
            self.assertTrue(all(f['provenance']['raw'].replace('\r\n','\n') == anchor for f in ff))

    def test_missing_dependency_finding(self):
        _, ff = self.check('inherit ROOM\n#include "missing.h"\n', {}, 'OUT_OF_SCOPE')
        self.assertIn('UNRESOLVED_INCLUDE', codes(ff))

    def test_multiple_authored_inherits(self):
        r, _ = extract('inherit ROOM; inherit "/custom/base"; void create(){}')
        self.assertEqual('PARTIAL', r['status']); self.assertEqual(2, len(fields(r, 'inherit')))

    def test_authored_valid_path_is_lazy(self):
        with patch.object(RoomExtractor, 'inherit_boundary_uncertain', side_effect=AssertionError('must stay lazy')):
            self.check('inherit ROOM;\nvoid create(){}', {}, 'EXTRACTED')
            r, _ = self.check(room('set("short","x");'), {}, 'EXTRACTED')
            self.assertEqual('x', fields(r, 'short')[0]['value']['value'])

    def test_existing_exclusions(self):
        for base in ('NPC', 'ITEM', 'BANK', 'HOCKSHOP', '"/std/weapon/sword"', '"/std/armor/boots"'):
            r, _ = extract(f'inherit ROOM; inherit {base}; void create(){{}}')
            self.assertFalse(r['supported_candidate']); self.assertEqual([], r['facts'])

    def test_header_fragments(self):
        for fragment in (';', 'ROOM;', '{', '}', '(', ')', '[', ']', 'inherit ROOM'):
            r, ff = RoomExtractor(Source('include/x.h', fragment.encode()), set(), {}).extract(header=True)
            self.assertEqual('OUT_OF_SCOPE', r['status']); self.assertEqual([], r['facts'])
            self.assertNotIn('SOURCE_SYNTAX_ERROR', codes(ff))

    def test_header_corruption(self):
        for raw in (b'\xff', b'\0', b'"unfinished', b'/* unfinished', b'@TEXT\nunfinished'):
            r, _ = RoomExtractor(Source('include/x.h', raw), set(), {}).extract(header=True)
            self.assertEqual('QUARANTINED', r['status']); self.assertEqual([], r['facts'])



class P2F15RegressionTests(unittest.TestCase):
    # Hand-authored expectations; includes the complete 24 x LF/CRLF FR14 matrix.
    CASES = [
        ('direct', '#define TAIL() ; void create()\ninherit ROOM TAIL() {}\n', {}, 'OUT_OF_SCOPE'),
        ('alias', '#define END TAIL\n#define TAIL() ; void create()\ninherit ROOM END() {}\n', {}, 'OUT_OF_SCOPE'),
        ('alias-two', '#define END MID\n#define MID TAIL\n#define TAIL() ; void create()\ninherit ROOM END() {}\n', {}, 'OUT_OF_SCOPE'),
        ('parameter', '#define TAIL(x) ; void create()\ninherit ROOM TAIL(1) {}\n', {}, 'OUT_OF_SCOPE'),
        ('substituted-name', '#define TAIL(name) ; void name()\ninherit ROOM TAIL(create) {}\n', {}, 'OUT_OF_SCOPE'),
        ('header', '#include "defs.h"\ninherit ROOM TAIL() {}\n', {'d/defs.h': '#define TAIL() ; void create()\n'}, 'OUT_OF_SCOPE'),
        ('nested', '#include "defs.h"\ninherit ROOM TAIL() {}\n', {'d/defs.h': '#include "inner.h"\n', 'd/inner.h': '#define TAIL() ; void create()\n'}, 'OUT_OF_SCOPE'),
        ('standard', '#include <defs.h>\ninherit ROOM TAIL() {}\n', {'include/defs.h': '#define TAIL() ; void create()\n'}, 'OUT_OF_SCOPE'),
        ('cross-header', '#include "a.h"\n#include "b.h"\ninherit ROOM END() {}\n', {'d/a.h': '#define END TAIL\n', 'd/b.h': '#define TAIL() ; void create()\n'}, 'OUT_OF_SCOPE'),
        ('literal-base', '#define TAIL() ; void create()\ninherit "/std/room" TAIL() {}\n', {}, 'OUT_OF_SCOPE'),
        ('valid-first', '#define TAIL() ; void create()\ninherit "/custom/base";\ninherit ROOM TAIL() {}\n', {}, 'OUT_OF_SCOPE'),
        ('keyword-int', '#define int ;\ninherit ROOM int\nvoid create() {}\n', {}, 'OUT_OF_SCOPE'),
        ('keyword-private', '#define private ; void create()\ninherit ROOM private {}\n', {}, 'OUT_OF_SCOPE'),
        ('object-tail', '#define TAIL ; void create()\ninherit ROOM TAIL {}\n', {}, 'OUT_OF_SCOPE'),
        ('direct-end-call', '#define END() ;\ninherit ROOM END()\nvoid create() {}\n', {}, 'OUT_OF_SCOPE'),
        ('raw-include-tail', 'inherit ROOM\n#include "tail.h"\n{}\n', {'d/tail.h': '; void create()\n'}, 'OUT_OF_SCOPE'),
        ('literal', 'inherit ROOM;\nvoid create() {}\n', {}, 'EXTRACTED'),
        ('literal-short', 'inherit ROOM;\nvoid create() {set("short","x");}\n', {}, 'EXTRACTED'),
        ('literal-multiple', 'inherit "/custom/base";\ninherit ROOM;\nvoid create() {}\n', {}, 'PARTIAL'),
        ('true-typed', 'inherit ROOM\nvoid create() {}\n', {}, 'QUARANTINED'),
        ('true-untyped', 'inherit ROOM\ncreate() {}\n', {}, 'QUARANTINED'),
        ('unused-tail', '#define TAIL() ; void helper()\ninherit ROOM\nvoid create() {}\n', {}, 'QUARANTINED'),
        ('neutral-untyped', '#define TAIL() 1\ninherit ROOM TAIL() {}\n', {}, 'QUARANTINED'),
        ('later-tail', '#define TAIL() ;\ninherit ROOM\nvoid create() {TAIL()}\n', {}, 'QUARANTINED'),
        ('different-name', '#define FINISH() ; void create()\ninherit ROOM FINISH() {}\n', {}, 'OUT_OF_SCOPE'),
        ('function-to-object', '#define FINISH() END\n#define END ; void create()\ninherit ROOM FINISH() {}\n', {}, 'OUT_OF_SCOPE'),
        ('keyword-void', '#define void ;\ninherit ROOM void\ncreate() {}\n', {}, 'OUT_OF_SCOPE'),
        ('keyword-static', '#define static ; void create()\ninherit ROOM static {}\n', {}, 'OUT_OF_SCOPE'),
        ('keyword-neutral', '#define int 1\ninherit ROOM int x;\n', {}, 'QUARANTINED'),
        ('normal-int', 'inherit ROOM\nint x;\n', {}, 'QUARANTINED'),
        ('normal-string', 'inherit ROOM\nstring foo;\n', {}, 'QUARANTINED'),
        ('normal-private', 'inherit ROOM\nprivate void helper() {}\n', {}, 'QUARANTINED'),
        ('normal-static', 'inherit ROOM\nstatic int value;\n', {}, 'QUARANTINED'),
        ('comment-only', '#define FINISH() ; void create()\ninherit ROOM /* FINISH() {} */\ncreate() {}\n', {}, 'QUARANTINED'),
        ('string-only', '#define FINISH() ; void create()\ninherit "FINISH"\ncreate() {}\n', {}, 'QUARANTINED'),
        ('character-only', "#define X ;\ninherit ROOM 'X'\ncreate() {}\n", {}, 'QUARANTINED'),
        ('quoted-symbol-only', "#define FINISH() ; void create()\ninherit ROOM 'FINISH\ncreate() {}\n", {}, 'QUARANTINED'),
        ('heredoc-only', '#define FINISH() ; void create()\ninherit @END\nFINISH() {}\nEND\ncreate() {}\n', {}, 'QUARANTINED'),
        ('raw-echo-only', '#define FINISH() ; void create()\ninherit ROOM\n#echo FINISH() {}\ncreate() {}\n', {}, 'QUARANTINED'),
        ('whitespace-call', '#define FINISH() ; void create()\ninherit ROOM FINISH () {}\n', {}, 'OUT_OF_SCOPE'),
        ('multiline-call', '#define FINISH() ; void create()\ninherit ROOM FINISH\n(\n)\n{}\n', {}, 'OUT_OF_SCOPE'),
        ('competing', '#define FINISH() 1\n#define FINISH() ; void create()\ninherit ROOM FINISH() {}\n', {}, 'OUT_OF_SCOPE'),
        ('cycle', '#define FINISH NEXT\n#define NEXT FINISH\ninherit ROOM FINISH() {}\n', {}, 'OUT_OF_SCOPE'),
        ('unused-cycle', '#define FINISH NEXT\n#define NEXT FINISH\ninherit ROOM\ncreate() {}\n', {}, 'QUARANTINED'),
        ('paste', '#define FINISH() F ## N\ninherit ROOM FINISH() {}\n', {}, 'OUT_OF_SCOPE'),
        ('invalid-function', '#define FINISH(x ;\ninherit ROOM FINISH() {}\n', {}, 'OUT_OF_SCOPE'),
        ('parameter-structural', '#define FINISH(x) x\ninherit ROOM FINISH(END) {}\n', {}, 'OUT_OF_SCOPE'),
        ('unused-unknown', '#define FINISH() F ## N\ninherit ROOM\ncreate() {}\n', {}, 'QUARANTINED'),
        ('neutral-function-alias', '#define FINISH() VALUE\n#define VALUE 1\ninherit ROOM FINISH() {}\n', {}, 'QUARANTINED'),
        ('uncertain-before-later-valid', '#define FINISH() ; void create()\ninherit ROOM FINISH() {}\ninherit "/custom/base";\n', {}, 'OUT_OF_SCOPE'),
        ('excluded-before-uncertain', '#define FINISH() ; void create()\ninherit NPC;\ninherit ROOM FINISH() {}\n', {}, 'OUT_OF_SCOPE'),
        ('valid-multiple', 'inherit ROOM;inherit "/custom/base";void create(){}\n', {}, 'PARTIAL'),
        ('valid-authored', 'inherit ROOM;void create(){}\n', {}, 'EXTRACTED'),
        ('valid-authored-short', 'inherit ROOM;void create(){set("short","x");}\n', {}, 'EXTRACTED'),
    ]

    def check(self, text, headers, status):
        for newline in ('\n', '\r\n'):
            raw = text.replace('\n', newline).encode()
            deps = {p: Source(p, h.replace('\n', newline).encode()) for p, h in headers.items()}
            r, ff = extract(raw, path='d/probe.c', dependencies=deps)
            with self.subTest(newline=repr(newline), text=text):
                self.assertEqual(status, r['status'])
                if status == 'OUT_OF_SCOPE':
                    self.assertFalse(r['supported_candidate'])
                    self.assertEqual([], r['facts'])
                    self.assertEqual([], r['direct_inherits'])
                    self.assertEqual([], r['category_candidates'])
                    self.assertNotIn('SOURCE_SYNTAX_ERROR', codes(ff))
                elif status == 'QUARANTINED':
                    self.assertEqual([], r['facts'])
                    error = next(f for f in ff if f['code'] == 'SOURCE_SYNTAX_ERROR')
                    self.assertEqual('unterminated inherit', error['reason'])
                    self.assertEqual('inherit', error['provenance']['raw'])
                for f in ff + r['facts']:
                    p = f['provenance']
                    self.assertEqual(hashlib.sha256(raw).hexdigest(), p['source_sha256'])
                    self.assertEqual(raw[p['byte_start']:p['byte_end_exclusive']].decode(), p['raw'])
        return r, ff

    def test_function_and_keyword_boundary_matrix(self):
        for name, text, headers, status in self.CASES:
            with self.subTest(case=name): self.check(text, headers, status)

    def test_long_function_alias_chain(self):
        defs = ''.join(f'#define A{i} A{i+1}\n' for i in range(1100))+'#define A1100() ; void create()\n'
        self.check(defs+'inherit ROOM A0() {}\n', {}, 'OUT_OF_SCOPE')

    def test_nested_macro_provenance(self):
        _, ff = self.check('#include "outer.h"\ninherit ROOM CLOSE() {}\n',
                          {'d/outer.h':'#include "inner.h"\n', 'd/inner.h':'#define CLOSE() ; void create()\n'}, 'OUT_OF_SCOPE')
        self.assertTrue(all(f['provenance']['raw']=='CLOSE' for f in ff))

    def test_keyword_macro_provenance(self):
        _, ff = self.check('#define static ; void create()\ninherit ROOM static {}\n', {}, 'OUT_OF_SCOPE')
        self.assertTrue(all(f['provenance']['raw']=='static' for f in ff))

    def test_valid_authored_declaration_stays_lazy(self):
        with patch.object(RoomExtractor, 'inherit_boundary_uncertain', side_effect=AssertionError('must stay lazy')):
            self.check('inherit ROOM;void create(){}', {}, 'EXTRACTED')
            self.check(room('set("short","x");'), {}, 'EXTRACTED')


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

    def test_keep2_complex_body_macros_reject_authored_boundary(self):
        r = self.objects['d/oldpine/keep2.c']
        # HIY/NOR reach compound ESC + string replacements through ansi.h.
        self.assertFalse(r['supported_candidate'])
        self.assertEqual([], r['facts'])
        self.assertEqual('OUT_OF_SCOPE', r['status'])
        self.assertIn('UNRESOLVED_INHERITANCE', codes(self.findings('d/oldpine/keep2.c')))

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
