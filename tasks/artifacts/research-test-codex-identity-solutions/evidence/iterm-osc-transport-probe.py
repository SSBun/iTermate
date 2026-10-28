"""仅新建自有iTerm2测试窗口，验证Kiro内层OSC到真实Bridge的转发。"""
import asyncio
import hashlib
import json
import pathlib
import subprocess
import time
import uuid
import iterm2

ROOT = pathlib.Path(__file__).resolve().parents[4]
EVIDENCE = pathlib.Path(__file__).resolve().parent
RESULT = {'test': 'iterm2_kiro_osc_transport', 'created_owned_session': False}


def save():
    (EVIDENCE / 'iterm-transport-results.json').write_text(json.dumps(RESULT, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps(RESULT, ensure_ascii=False), flush=True)


async def bridge_session(session_id):
    path = pathlib.Path.home() / 'Library/Application Support/iTermate/bridge.sock'
    reader, writer = await asyncio.open_unix_connection(str(path))
    try:
        for _ in range(4):
            line = await asyncio.wait_for(reader.readline(), 4)
            value = json.loads(line)
            if value.get('type') != 'snapshot':
                continue
            for window in value.get('windows', []):
                for tab in window.get('tabs', []):
                    for session in tab.get('sessions', []):
                        if session.get('id') == session_id:
                            return session
        return None
    finally:
        writer.close()
        await writer.wait_closed()


async def main(connection):
    session = None
    try:
        app = await iterm2.async_get_app(connection)
        window = await iterm2.Window.async_create(connection)
        if window is None or window.current_tab is None:
            raise RuntimeError('owned_test_window_not_created')
        session = window.current_tab.current_session
        if session is None:
            raise RuntimeError('owned_test_session_not_created')
        ownership = EVIDENCE / 'owned-iterm-session.json'
        ownership.write_text(json.dumps({'session_id': session.session_id}) + '\n')
        ownership.chmod(0o600)
        RESULT['created_owned_session'] = True
        RESULT['session_hash'] = hashlib.sha256(session.session_id.encode()).hexdigest()[:16]
        await asyncio.sleep(3)
        tty = await session.async_get_variable('tty')
        processes = subprocess.check_output(['ps', '-axo', 'pid,ppid,tty,comm'], text=True).splitlines()
        outer = str(tty).removeprefix('/dev/')
        RESULT['outer_has_kiro_wrapper'] = any(
            len(parts := line.split(None, 3)) == 4 and parts[2] == outer and 'kiro-cli-term' in parts[3]
            for line in processes
        )
        marker_id = str(uuid.uuid4())
        prefix = marker_id[:29]
        marker = 'codex | ' + prefix + '...'
        # 只对刚创建且保存了精确Session ID的终端输入。禁止广播。
        command = "printf '\\033]0;%s\\007' '" + marker + "'; /bin/sleep 6\n"
        await session.async_send_text(command, suppress_broadcast=True)
        observations = []
        for _ in range(4):
            await asyncio.sleep(0.8)
            title = await session.async_get_variable('terminalWindowName')
            observations.append(title == marker)
        RESULT['native_title_matches'] = observations
        snapshot = await bridge_session(session.session_id)
        RESULT['bridge_observed_owned_session'] = snapshot is not None
        RESULT['bridge_prefix_matches'] = bool(snapshot and snapshot.get('codexThreadIDPrefix') == prefix)
        RESULT['prefix_length'] = len(prefix)
        RESULT['existing_sessions_received_input'] = False
    except Exception as error:
        RESULT['error'] = type(error).__name__
        if isinstance(error, RuntimeError):
            RESULT['error_detail'] = str(error)
    finally:
        if session is not None:
            try:
                await session.async_close(force=True)
                RESULT['owned_session_closed'] = True
                (EVIDENCE / 'owned-iterm-session.json').unlink(missing_ok=True)
            except Exception as error:
                RESULT['cleanup_error'] = type(error).__name__
        save()


iterm2.run_until_complete(main, retry=False)
