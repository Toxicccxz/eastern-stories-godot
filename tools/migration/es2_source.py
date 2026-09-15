"""Byte-preserving source, deterministic discovery and a bounded LPC lexer."""

from __future__ import annotations

import bisect
import hashlib
import os
from dataclasses import dataclass
from pathlib import Path


class ToolError(Exception):
    """Fatal input/output or tool contract failure (exit2)."""


@dataclass(frozen=True)
class Token:
    kind: str
    text: str
    start: int
    end: int


class SourceError(Exception):
    def __init__(self, reason: str, start: int, end: int, *, encoding: bool = False):
        super().__init__(reason)
        self.start, self.end, self.encoding = start, end, encoding


@dataclass
class Source:
    path: str
    data: bytes

    def __post_init__(self) -> None:
        self.sha256 = hashlib.sha256(self.data).hexdigest()
        self.lines = [0] + [i + 1 for i, byte in enumerate(self.data) if byte == 10]

    def span(self, start: int, end: int, scope: str, construct: str, ordinal: int) -> dict:
        if not 0 <= start <= end <= len(self.data):
            raise ToolError('invalid provenance range')
        line = bisect.bisect_right(self.lines, start)
        prefix = self.data[self.lines[line - 1]:start]
        raw = self.data[start:end]
        result = dict(source_path=self.path, source_sha256=self.sha256, scope=scope,
                      construct=construct, source_ordinal=ordinal, byte_start=start,
                      byte_end_exclusive=end, line=line,
                      column=len(prefix.decode('utf-8', errors='replace')) + 1)
        try:
            result['raw'] = raw.decode('utf-8')
        except UnicodeDecodeError:
            result['raw'] = None
            result['raw_hex'] = raw.hex()
        return result


def safe_path(path: Path) -> Path:
    """Reject links (including Windows junctions) before resolving any component."""
    absolute = Path(os.path.abspath(path))
    for part in [*reversed(absolute.parents), absolute]:
        if part.is_symlink() or part.is_junction():
            raise ToolError('filesystem links/junctions are not supported')
    return absolute.resolve()


def discover(root: Path) -> tuple[Path, list[tuple[str, Source]]]:
    root = safe_path(root)
    if root == Path(root.anchor) or not root.is_dir():
        raise ToolError('source root must be a non-root existing directory')
    mudlib = root / 'mudlib' if (root / 'mudlib').is_dir() else root
    if not (mudlib / 'd').is_dir():
        raise ToolError('source root must contain d/ or mudlib/d/')
    found = []

    def visit(directory: Path) -> None:
        for path in sorted(directory.iterdir(), key=lambda p: p.name):
            checked = safe_path(path)
            if not checked.is_relative_to(root):
                raise ToolError('source path escaped root')
            if path.is_dir():
                visit(path)
            elif path.is_file():
                relative = path.relative_to(root).as_posix()
                source_path = path.relative_to(mudlib).as_posix() if path.is_relative_to(mudlib) else relative
                found.append((relative, Source(source_path, path.read_bytes())))
            else:
                raise ToolError('non-regular source entry')

    visit(root)
    return mudlib, sorted(found, key=lambda entry: entry[0])


def lex(source: Source) -> list[Token]:
    """Scan tokens without preprocessing, expression evaluation or runtime grammar."""
    data = source.data
    try:
        text = data.decode('utf-8')
    except UnicodeDecodeError as error:
        raise SourceError('invalid UTF-8', error.start, error.end, encoding=True) from error
    offsets = [0]
    for char in text:
        offsets.append(offsets[-1] + len(char.encode('utf-8')))
    for bad in ('\x00', '\ufffd'):
        i = text.find(bad)
        if i >= 0:
            raise SourceError('NUL or replacement character in source', offsets[i], offsets[i + 1], encoding=True)
    tokens: list[Token] = []
    i, length = 0, len(text)

    def emit(kind: str, start: int, end: int) -> None:
        tokens.append(Token(kind, text[start:end], offsets[start], offsets[end]))

    def fail(reason: str, start: int) -> None:
        raise SourceError(reason, offsets[start], len(data))

    while i < length:
        start = i
        char = text[i]
        if char.isspace():
            i += 1
        elif text.startswith('//', i):
            end = text.find('\n', i)
            i = length if end < 0 else end
        elif text.startswith('/*', i):
            end = text.find('*/', i + 2)
            if end < 0:
                fail('unterminated block comment', start)
            i = end + 2
        elif char == '#' and not text[text.rfind('\n', 0, i) + 1:i].strip():
            # Directive bodies are opaque, including continued macro definitions.
            while True:
                end = text.find('\n', i)
                if end < 0:
                    i = length
                    break
                continued = text[i:end].rstrip('\r').endswith('\\')
                i = end + 1
                if not continued:
                    break
            emit('directive', start, i)
        elif char == '"':
            i += 1
            while i < length:
                if text[i] == '\\':
                    i += 2
                elif text[i] == '"':
                    i += 1
                    break
                else:
                    i += 1
            else:
                fail('unterminated string', start)
            if i > length:
                fail('unterminated string escape', start)
            emit('string', start, i)
        elif char == "'":
            # Single-character literals; LPC quoted symbols remain opaque tokens.
            j = i + 1
            j += 2 if j < length and text[j] == '\\' else 1
            if j < length and text[j] == "'":
                i = j + 1
                emit('character', start, i)
            else:
                i += 1
                while i < length and (text[i].isalnum() or text[i] == '_'):
                    i += 1
                emit('unknown', start, i)
        elif char == '@':
            i += 1
            array = i < length and text[i] == '@'
            if array:
                i += 1
            tag_start = i
            while i < length and (text[i].isalnum() or text[i] == '_'):
                i += 1
            tag = text[tag_start:i]
            line_end = text.find('\n', i)
            if not tag or not (tag[0].isalpha() or tag[0] == '_') or line_end < 0 or text[i:line_end].strip():
                emit('unknown', start, i)
                continue
            i = line_end + 1
            while i < length:
                end = text.find('\n', i)
                end = length if end < 0 else end
                content_start = i + len(text[i:end]) - len(text[i:end].lstrip(' \t'))
                tag_end = content_start + len(tag)
                suffix = text[tag_end:end].strip(' \t\r')
                if text.startswith(tag, content_start) and (not suffix or suffix[0] in ');,]}'):
                    i = tag_end
                    emit('heredoc_array' if array else 'heredoc', start, i)
                    break
                i = end + 1
            else:
                fail('unterminated multiline text', start)
        elif char.isascii() and (char.isalpha() or char == '_'):
            i += 1
            while i < length and text[i].isascii() and (text[i].isalnum() or text[i] == '_'):
                i += 1
            emit('identifier', start, i)
        elif char.isascii() and char.isdigit():
            i += 1
            while i < length and (text[i].isalnum() or text[i] in '._'):
                i += 1
            emit('number', start, i)
        else:
            pair = text[i:i + 2]
            i += 2 if pair in ('->', '::') else 1
            emit('punctuation', start, i)
    return tokens


def pairs(tokens: list[Token]) -> dict[int, int]:
    """Validate balanced structure only; this is not full LPC syntax validation."""
    opening = {'(': ')', '[': ']', '{': '}'}
    closing = set(opening.values())
    stack: list[int] = []
    matched = {}
    for i, token in enumerate(tokens):
        if token.kind != 'punctuation':
            continue
        if token.text in opening:
            stack.append(i)
        elif token.text in closing:
            if not stack or opening[tokens[stack[-1]].text] != token.text:
                raise SourceError('mismatched delimiter', token.start, token.end)
            first = stack.pop()
            matched[first] = i
    if stack:
        first = tokens[stack[0]]
        raise SourceError('unclosed delimiter', first.start, first.end)
    return matched


def literal(token: Token) -> dict | None:
    """Only decimal integer and a deliberately explicit string escape subset."""
    if token.kind == 'number' and token.text.isascii() and token.text.isdecimal():
        if len(token.text) > 1 and token.text.startswith('0'):
            return None  # Do not guess octal semantics.
        return {'kind': 'integer', 'value': str(int(token.text))}
    if token.kind == 'heredoc':
        body = token.text.split('\n', 1)[1]
        return {'kind': 'text', 'value': body[:body.rfind('\n') + 1]}
    if token.kind != 'string':
        return None
    value, i = [], 1
    escapes = {'n': '\n', 'r': '\r', 't': '\t', 'b': '\b', 'f': '\f',
               'v': '\v', 'a': '\a', '\\': '\\', '"': '"', "'": "'"}
    while i < len(token.text) - 1:
        char = token.text[i]
        if char == '\\':
            i += 1
            if token.text[i] not in escapes:
                return None
            char = escapes[token.text[i]]
        value.append(char)
        i += 1
    return {'kind': 'text', 'value': ''.join(value)}
