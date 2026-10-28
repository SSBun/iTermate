"""只读查询自有测试app-server：用TUI原生前缀唯一扩展完整thread ID。"""
import hashlib
import json
import os
import pathlib
import re
import stat
import sys
import uuid
from websockets.sync.client import unix_connect

request = json.load(sys.stdin)
path = pathlib.Path(request['socket'])
prefix = request['prefix'].lower()
expected = request['expected'].lower()
info = path.lstat()
if not stat.S_ISSOCK(info.st_mode) or info.st_uid != os.getuid():
    raise RuntimeError('test_socket_identity_invalid')
if not re.fullmatch(r'[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{5}', prefix):
    raise RuntimeError('native_prefix_invalid')
result = {'readonly_methods': ['initialize', 'thread/loaded/list', 'thread/read']}
with unix_connect(str(path), uri='ws://localhost/', open_timeout=3, close_timeout=1, compression=None, max_size=2*1024*1024) as connection:
    sequence = 0

    def rpc(method, params):
        global sequence
        sequence += 1
        identifier = 'identity-probe-' + str(sequence)
        connection.send(json.dumps({'id': identifier, 'method': method, 'params': params}))
        for _ in range(256):
            message = json.loads(connection.recv(timeout=3))
            if message.get('id') == identifier:
                if 'error' in message:
                    return None, message['error'].get('code')
                return message.get('result'), None
        raise RuntimeError('bounded_rpc_response_not_found')

    initialization, error = rpc('initialize', {
        'clientInfo': {'name': 'itermate_identity_probe', 'title': 'iTermate identity probe', 'version': '0.1'},
        'capabilities': {'experimentalApi': True},
    })
    if error:
        result['initialize_error_code'] = error
    else:
        connection.send(json.dumps({'method': 'initialized'}))
        ids = []
        cursor = None
        for _ in range(4):
            page, error = rpc('thread/loaded/list', {'cursor': cursor, 'limit': 100})
            if error:
                result['list_error_code'] = error
                break
            ids.extend(value.lower() for value in page.get('data', []) if isinstance(value, str))
            cursor = page.get('nextCursor')
            if cursor is None:
                break
        matches = sorted({value for value in ids if value.startswith(prefix)
                          and str(uuid.UUID(value)) == value})
        result.update(loaded_count=len(ids), matching_count=len(matches),
                      full_id_matches_status=len(matches) == 1 and matches[0] == expected,
                      pages_complete=cursor is None)
        if len(matches) == 1:
            identifier = matches[0]
            result['thread_hash'] = hashlib.sha256(identifier.encode()).hexdigest()[:16]
            metadata, error = rpc('thread/read', {'threadId': identifier, 'includeTurns': False})
            if error:
                result['read_error_code'] = error
            else:
                thread = metadata.get('thread', {})
                source = thread.get('source')
                result.update(read_id_matches=thread.get('id', '').lower() == identifier,
                              status_type=(thread.get('status') or {}).get('type'),
                              source_is_root=isinstance(source, str) and source in ('cli', 'vscode', 'exec', 'appServer'),
                              has_rollout_path=bool(thread.get('path')))
print(json.dumps(result), flush=True)
