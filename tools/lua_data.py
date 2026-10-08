"""Read literal Lua data tables; expressions and executable code are rejected."""
import json
import re

TOKEN = re.compile(r'\s+|--\[\[.*?\]\]|--[^\n]*|"(?:[^"\\]|\\.)*"|\d+(?:\.\d+)?|[A-Za-z_]\w*|[{}\[\]=,;.-]', re.S)


def read_table(source, name):
    """Parse only the table assigned to a named variable, without evaluating Lua."""
    start = re.search(rf'\b{re.escape(name)}\s*=\s*(?={{)', source)
    if not start:
        raise ValueError(f"Missing literal table: {name}")
    text, position, tokens = source[start.end():], 0, []
    # Tokenize lazily only through the balanced outer table, rejecting unknown syntax.
    depth = 0
    while position < len(text):
        match = TOKEN.match(text, position)
        if not match:
            raise ValueError(f"Unsupported Lua data at {text[position:position + 40]!r}")
        position = match.end()
        token = match[0]
        if token.isspace() or token.startswith('--'):
            continue
        tokens.append(token)
        depth += (token == '{') - (token == '}')
        if depth == 0:
            break
        if depth > 32 or len(tokens) > 500_000:
            raise ValueError("Lua data limits exceeded")
    index = 0

    def take(expected=None):
        """Consume one token and enforce punctuation when required."""
        nonlocal index
        token = tokens[index] if index < len(tokens) else None
        if token is None or (expected is not None and token != expected):
            raise ValueError(f"Expected {expected!r}, found {token!r}")
        index += 1
        return token

    def value():
        """Read primitive literals and nested tables; never resolve identifiers."""
        token = take()
        if token == '{':
            result, ordinal = {}, 1
            while tokens[index] != '}':
                if tokens[index] == '[':
                    take('['); key = value(); take(']'); take('=')
                    child = value()
                elif index + 1 < len(tokens) and tokens[index + 1] == '=':
                    key = take(); take('='); child = value()
                else:
                    key, child = ordinal, value()
                    ordinal += 1
                if key in result:
                    raise ValueError(f"Duplicate data key: {key}")
                result[key] = child
                if tokens[index] in (',', ';'):
                    take()
                elif tokens[index] != '}':
                    raise ValueError("Executable expression in data")
            take('}')
            return result
        if token.startswith('"'):
            return json.loads(token)
        if token == '-':
            return -float(take())
        if token[0].isdigit():
            return float(token) if '.' in token else int(token)
        if token in ('true', 'false', 'nil'):
            return {'true': True, 'false': False, 'nil': None}[token]
        raise ValueError(f"Executable expression in data: {token}")

    result = value()
    if index != len(tokens):
        raise ValueError("Unconsumed data tokens")
    return result
