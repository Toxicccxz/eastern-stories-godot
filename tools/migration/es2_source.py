"""A bounded LPC lexer over byte-preserving source (used by content_importer)."""

from __future__ import annotations

from dataclasses import dataclass


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


def directive_keyword(text: str, start: int = 0) -> tuple[str, int]:
    """Read only the directive head; return its name and authored character end.

    Keep accepted trivia and keyword splices, but never inspect payload as LPC.
    A splice joins a keyword only when another identifier character follows it.
    Thus an echo's trailing backslash remains message data, including before #.
    """
    def splice_end(i: int) -> int:
        while text.startswith('\\\n', i) or text.startswith('\\\r\n', i):
            i += 3 if text.startswith('\\\r\n', i) else 2
        return i

    i = start + 1
    while i < len(text):
        end = splice_end(i)
        if end != i:
            i = end
        elif text[i].isspace() and text[i] != '\n':
            i += 1
        elif text.startswith('/*', i):
            end = text.find('*/', i + 2)
            if end < 0:
                return '', i  # The generic scanner retains its original error.
            i = end + 2
        else:
            break
    if i == len(text) or not (text[i].isascii() and (text[i].isalpha() or text[i] == '_')):
        return '', i
    name = []
    while i < len(text):
        end = splice_end(i)
        if end < len(text) and text[end].isascii() and (text[end].isalnum() or text[end] == '_'):
            name.append(text[end])
            i = end + 1
        else:
            break
    return ''.join(name), i


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
    line_prefix_is_trivia = True

    def emit(kind: str, start: int, end: int) -> None:
        nonlocal line_prefix_is_trivia
        tokens.append(Token(kind, text[start:end], offsets[start], offsets[end]))
        # Strings/heredocs end with non-trivia on their final physical line.
        # A directive consumes its final newline, when present, unlike other tokens.
        line_prefix_is_trivia = kind == 'directive' and text[end - 1:end] == '\n'

    def fail(reason: str, start: int) -> None:
        raise SourceError(reason, offsets[start], len(data))

    while i < length:
        start = i
        char = text[i]
        if char.isspace():
            if char == '\n':
                line_prefix_is_trivia = True
            i += 1
        elif text.startswith('//', i):
            end = text.find('\n', i)
            i = length if end < 0 else end
        elif text.startswith('/*', i):
            end = text.find('*/', i + 2)
            if end < 0:
                fail('unterminated block comment', start)
            # Comments are trivia; a newline inside one also discards any code
            # prefix on the earlier line. Keep original source/offsets untouched.
            if '\n' in text[i:end + 2]:
                line_prefix_is_trivia = True
            i = end + 2
        elif char == '#' and line_prefix_is_trivia:
            keyword, head_end = directive_keyword(text, i)
            if keyword == 'echo':
                # ES2 doc/concepts/preprocessor: the rest of the physical line
                # or EOF is a verbatim message, including quotes/comments/\\.
                end = text.find('\n', head_end)
                i = length if end < 0 else end + 1
                emit('directive', start, i)
                continue
            # Keep the complete raw directive. Only an outside-comment newline
            # without continuation terminates it; quoted delimiters are opaque.
            quoted = False
            while i < length:
                if text[i] == '\n':
                    previous = i - 2 if i > start and text[i - 1] == '\r' else i - 1
                    continued = text[previous:previous + 1] == '\\'
                    i += 1
                    if not continued:
                        break
                elif quoted:
                    if text[i] == '\\':
                        i = min(i + 2, length)
                    elif text[i] == '"':
                        quoted = False
                        i += 1
                    else:
                        i += 1
                elif text.startswith('/*', i):
                    end = text.find('*/', i + 2)
                    if end < 0:
                        fail('unterminated block comment', i)
                    i = end + 2
                elif text.startswith('//', i):
                    end = text.find('\n', i)
                    i = length if end < 0 else end + 1
                    break
                elif text[i] == '"':
                    quoted = True
                    i += 1
                elif text[i] == "'":
                    # Same bounded character-literal rule as the outer lexer;
                    # an LPC quoted symbol must not hide a following comment.
                    end = i + (3 if text[i + 1:i + 2] == '\\' else 2)
                    i = end + 1 if text[end:end + 1] == "'" else i + 1
                else:
                    i += 1
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
