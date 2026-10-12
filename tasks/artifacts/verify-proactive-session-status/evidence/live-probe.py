import asyncio
import collections
import json
import os
from pathlib import Path
import socket
import stat
import time
import uuid
import iterm2

root = Path.home() / '.iTermate/pi-live'
allowed_states = {'idle', 'running', 'awaitingInput', 'finished', 'detached'}

def alive(pid):
    try:
        os.kill(pid, 0)
        return True
    except OSError:
        return False

async def main(connection):
    app = await iterm2.async_get_app(connection)
    terminal_ids = [s.session_id for w in app.windows for t in w.tabs for s in t.all_sessions]
    counts = collections.Counter(terminal_ids)
    results = []
    for path in sorted(root.glob('*.json'))[:32]:
        info = path.lstat()
        if not stat.S_ISREG(info.st_mode) or info.st_uid != os.getuid() or info.st_size > 16384:
            continue
        descriptor = json.loads(path.read_text())
        identity = str(uuid.UUID(descriptor['id']))
        pid = descriptor.get('pid')
        endpoint = root / (identity[:16] + '.sock')
        if descriptor.get('version') != 1 or descriptor.get('socketPath') != str(endpoint):
            continue
        if not isinstance(pid, int) or pid <= 1 or not alive(pid):
            continue
        if not 0 <= time.time() - descriptor.get('updatedAt', 0) <= 8:
            continue
        info = endpoint.lstat()
        if not stat.S_ISSOCK(info.st_mode) or info.st_uid != os.getuid():
            continue
        row = {
            'sample': len(results) + 1,
            'terminal': descriptor.get('terminal'),
            'uniquely_matches_iterm_session': counts[descriptor.get('terminalSessionId')] == 1,
            'descriptor_has_lifecycle_status': any(k in descriptor for k in ['status', 'state', 'isIdle', 'isStreaming']),
            'canArchive': descriptor.get('canArchive'),
        }
        # Only status is sent. The installed handler rejects non-archive actions before any mutation.
        request = {'action': 'status', 'token': descriptor['token'], 'sessionId': descriptor['sessionId']}
        try:
            with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as client:
                client.settimeout(2)
                client.connect(str(endpoint))
                client.sendall((json.dumps(request) + '\n').encode())
                buffer = b''
                while b'\n' not in buffer and len(buffer) < 16384:
                    part = client.recv(4096)
                    if not part:
                        break
                    buffer += part
                response = json.loads(buffer.split(b'\n', 1)[0])
                row['query_ok'] = response.get('ok') is True
                row['response_fields'] = sorted(response.keys())
                row['reported_status'] = response.get('status') if response.get('status') in allowed_states else None
                row['known_rejection'] = response.get('error') == 'Pi session identity or authorization changed. Refresh and retry.'
        except (OSError, ValueError):
            row['query_result'] = 'unavailable'
        row['pid_alive_after_query'] = alive(pid)
        results.append(row)
    print(json.dumps({'iterm_session_count': len(terminal_ids), 'fresh_live_endpoints': len(results), 'samples': results}, ensure_ascii=False, indent=2))

iterm2.run_until_complete(main)
