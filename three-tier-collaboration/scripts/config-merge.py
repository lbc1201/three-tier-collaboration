"""Conservative, stdlib-only TOML scalar merger. Python 3.11+ required."""
import argparse
import base64
import copy
import json
import os
from pathlib import Path
import re
import sys
import tempfile
import tomllib
import uuid

SETTINGS = {
    'model_reasoning_effort': 'medium',
    'agents.enabled': True, 'agents.max_concurrent_threads_per_session': 3,
    'agents.default_subagent_model': 'gpt-6-luna',
    'agents.default_subagent_reasoning_effort': 'medium',
}
MISSING = object()


def safe(path):
    path = Path(os.path.abspath(path))
    for item in [path, *path.parents]:
        if item.is_symlink() or (hasattr(item, 'is_junction') and item.is_junction()):
            raise ValueError('Refusing links or junctions: ' + str(item))
    return path


def parsed(raw):
    return tomllib.loads(raw.decode('utf-8-sig'))


def get(data, key):
    current = data
    for part in key.split('.'):
        if not isinstance(current, dict) or part not in current:
            return MISSING
        current = current[part]
    return current


def literal(value):
    if type(value) is bool:
        return str(value).lower()
    if type(value) in (str, int):
        return json.dumps(value, ensure_ascii=True)
    raise ValueError('Managed configuration values must be scalar strings, integers or booleans.')


def change(raw, key, value):
    """Only edit simple root/[agents] entries; validate the entire semantic diff."""
    data = parsed(raw)
    old = get(data, key)
    if old is value or (old is not MISSING and value is not MISSING and type(old) is type(value) and old == value):
        return raw
    if old is not MISSING:
        literal(old)
    text = raw.decode('utf-8-sig')
    bom = b'\xef\xbb\xbf' if raw.startswith(b'\xef\xbb\xbf') else b''
    nl = '\r\n' if '\r\n' in text else '\n'
    lines = text.splitlines(keepends=True)
    section = ''
    candidates = []
    table_line = None
    first_table = len(lines)
    wanted_section, name = ('agents', key.split('.')[1]) if key.startswith('agents.') else ('', key)
    headers = []
    for i, line in enumerate(lines):
        header = re.match(r'^\s*(\[\[?.*?\]\]?)\s*(?:#.*)?$', line.rstrip('\r\n'))
        if header:
            first_table = min(first_table, i)
            section = header[1][1:-1].strip()
            headers.append((i, section))
            if section == 'agents':
                table_line = i
        pattern = r'^(\s*(?:' + re.escape(name) + '|"' + re.escape(name) + '"|\'' + re.escape(name) + r"')\s*=\s*)(.*?)(\r?\n)?$"
        match = re.match(pattern, line)
        if section == wanted_section and match:
            candidates.append((i, match))
    if old is not MISSING and len(candidates) != 1:
        raise ValueError('Unsupported TOML layout for ' + key + '; no file changes made.')
    if candidates:
        if len(candidates) != 1:
            raise ValueError('Ambiguous TOML layout for ' + key)
        i, match = candidates[0]
        if value is MISSING:
            lines.pop(i)
        else:
            # Preserve an inline comment only after a simple single-line scalar.
            scalar = r'''(?:"(?:[^"\\]|\\.)*"|'[^']*'|true|false|[+-]?\d[\d_]*)'''
            tail = re.fullmatch(scalar + r'([ \t]*(?:#.*)?)', match[2])
            if not tail:
                raise ValueError('Unsupported managed scalar syntax for ' + key)
            lines[i] = match[1] + literal(value) + tail[1] + (match[3] or '')
    elif value is not MISSING:
        entry = name + ' = ' + literal(value) + nl
        if wanted_section == '':
            if first_table > 0 and not lines[first_table - 1].endswith(('\n', '\r')):
                lines[first_table - 1] += nl
            lines.insert(first_table, entry)
        elif table_line is not None:
            lines.insert(table_line + 1, entry)
        else:
            # Inline/dotted agents definitions cannot be safely rewritten here.
            if 'agents' in data:
                raise ValueError('Use a normal [agents] table before merging missing agent settings.')
            if lines and not lines[-1].endswith(('\n', '\r')):
                lines[-1] += nl
            lines += [nl, '[agents]' + nl, entry]
    result = bom + ''.join(lines).encode('utf-8')
    after = parsed(result)
    expected = copy.deepcopy(data)
    container = expected
    if wanted_section:
        container = expected.setdefault('agents', {})
    if value is MISSING:
        container.pop(name, None)
    else:
        container[name] = value
    if after != expected:
        raise ValueError('TOML semantic validation failed for ' + key + '; no file changes made.')
    return result


def pack(value):
    return None if value is None else base64.b64encode(value).decode('ascii')


def unpack(value):
    return None if value is None else base64.b64decode(value)


def plan(action, path):
    path = safe(path)
    if path.name != 'config.toml':
        raise ValueError('ConfigPath must name config.toml.')
    receipt = safe(str(path) + '.three-tier-collaboration.json')
    original = path.read_bytes() if path.exists() else None
    receipt_before = receipt.read_bytes() if receipt.exists() else None
    state = json.loads(receipt_before.decode('utf-8')) if receipt_before else {}
    if state and (state.get('owner') != 'three-tier-collaboration' or state.get('config_path') != str(path)):
        raise ValueError('Unexpected configuration receipt; refusing to overwrite it.')
    raw = original or b''
    data = parsed(raw)
    owned = state.get('keys', {}) if state.get('active') else {}
    warnings = []
    if action == 'install':
        if get(data, 'agents.max_threads') is not MISSING:
            raise ValueError('Legacy agents.max_threads found; migrate it to max_concurrent_threads_per_session before installation.')
        new_owned = {}
        for key, desired in SETTINGS.items():
            before = get(data, key)
            previous = owned.get(key)
            if previous and before is not MISSING and type(before) is type(previous['installed']) and before == previous['installed']:
                new_owned[key] = previous
            elif before is MISSING or type(before) is not type(desired) or before != desired:
                new_owned[key] = {'had_value': before is not MISSING, 'original': None if before is MISSING else before, 'installed': desired}
            raw = change(raw, key, desired)
        state = {'owner': 'three-tier-collaboration', 'version': '1.2', 'active': True,
                 'config_path': str(path), 'keys': new_owned}
    else:
        for key, saved in owned.items():
            if key == 'model':
                warnings.append('Preserved the previously managed default model: model')
                continue
            if key not in SETTINGS:
                raise ValueError('Unexpected managed key in configuration receipt.')
            current = get(parsed(raw), key)
            if current is not MISSING and type(current) is type(saved['installed']) and current == saved['installed']:
                raw = change(raw, key, saved['original'] if saved['had_value'] else MISSING)
            else:
                warnings.append('Preserved a later user change: ' + key)
        if receipt_before:
            state = {'owner': 'three-tier-collaboration', 'version': '1.2', 'active': False,
                     'config_path': str(path), 'keys': {}}
    # No receipt means the uninstaller has no ownership and must not change config.
    after_receipt = (json.dumps(state, indent=2, ensure_ascii=True) + '\n').encode() if state else receipt_before
    after_config = raw if original is not None or action == 'install' else None
    return {'files': [{'path': str(path), 'before': pack(original), 'after': pack(after_config)},
                      {'path': str(receipt), 'before': pack(receipt_before), 'after': pack(after_receipt)}],
            'warnings': warnings}


def atomic(path, content):
    path = safe(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    if content is None:
        if path.exists():
            path.unlink()  # Only a newly created, receipt-owned file during rollback.
        return
    handle, temporary = tempfile.mkstemp(prefix=path.name + '.', suffix='.tmp', dir=path.parent)
    with os.fdopen(handle, 'wb') as stream:
        stream.write(content)
    os.replace(temporary, path)


def apply(edit, backup_root, reverse=False):
    files = edit['files']
    before_key, after_key = ('after', 'before') if reverse else ('before', 'after')
    for file in files:
        path = safe(file['path'])
        current = path.read_bytes() if path.exists() else None
        if current != unpack(file[before_key]):
            raise ValueError('Configuration changed since preflight: ' + str(path))
    done = []
    try:
        for file in files:
            before, after = unpack(file[before_key]), unpack(file[after_key])
            if before == after:
                continue
            path = safe(file['path'])
            if before is not None:
                root = safe(backup_root)
                root.mkdir(parents=True, exist_ok=True)
                backup = root / (path.name + '-before-v1.2-' + uuid.uuid4().hex + '.bak')
                backup.write_bytes(before)
                print('Configuration backup: ' + str(backup))
            atomic(path, after)
            done.append(file)
        for message in edit.get('warnings', []):
            print(message)
    except Exception:
        for file in reversed(done):
            path = safe(file['path'])
            if (path.read_bytes() if path.exists() else None) == unpack(file[after_key]):
                atomic(path, unpack(file[before_key]))
        raise


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('command', choices=['plan-install', 'plan-uninstall', 'apply', 'rollback'])
    parser.add_argument('--config')
    parser.add_argument('--backup-root')
    args = parser.parse_args()
    if args.command.startswith('plan-'):
        print(json.dumps(plan(args.command[5:], args.config), ensure_ascii=True))
    else:
        apply(json.load(sys.stdin), args.backup_root, reverse=args.command == 'rollback')


if __name__ == '__main__':
    try:
        main()
    except Exception as error:
        # No TOML text or potential credentials are printed.
        print('Config merge failed: ' + str(error), file=sys.stderr)
        sys.exit(1)
