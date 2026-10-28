#!/usr/bin/env python3
"""隔离共享app-server实测：原生前缀加官方只读API，在落盘前扩展完整thread身份。"""
import ctypes
import datetime
import hashlib
import json
import os
import pathlib
import pty
import re
import select
import signal
import struct
import subprocess
import termios
import time
import tomllib
import uuid
import tempfile
import shutil
import ast

ROOT = pathlib.Path(__file__).resolve().parents[4]
EVIDENCE = pathlib.Path(__file__).resolve().parent
BINARY = pathlib.Path.home() / '.local/share/mise/installs/node/22.22.2/lib/node_modules/@openai/codex/node_modules/@openai/codex-darwin-arm64/vendor/aarch64-apple-darwin/bin/codex'
TEST_HOME = pathlib.Path(tempfile.mkdtemp(prefix='it-id-shared-', dir='/tmp')).resolve()
SERVER_SOCKET = TEST_HOME / 'server.sock'
SERVER = None
TEST_HOME.chmod(0o700)
WORKSPACE = TEST_HOME / 'workspace'
WORKSPACE.mkdir()
# 仅向当前用户的测试进程提供已有登录文件的路径引用，不复制或记录凭据。
(TEST_HOME / 'auth.json').symlink_to(pathlib.Path.home() / '.codex/auth.json')
original_configuration = tomllib.loads((pathlib.Path.home() / '.codex/config.toml').read_text())
minimal_configuration = 'approval_policy = "never"\nsandbox_mode = "read-only"\n[tui]\nterminal_title = ["app-name", "thread-id"]\n'
minimal_configuration += '\n[projects.' + json.dumps(str(WORKSPACE)) + ']\ntrust_level = "trusted"\n'
if isinstance(original_configuration.get('model'), str):
    minimal_configuration = 'model = ' + json.dumps(original_configuration['model']) + '\n' + minimal_configuration
(TEST_HOME / 'config.toml').write_text(minimal_configuration)
(TEST_HOME / 'config.toml').chmod(0o600)
EVENTS = []
CHILDREN = []
bridge_tree = ast.parse((ROOT / 'iTermateBridge/iTermateBridge.py').read_text())
prefix_function = next(node for node in bridge_tree.body
                       if isinstance(node, ast.FunctionDef) and node.name == 'codex_thread_id_prefix')
prefix_namespace = {'re': re}
exec(compile(ast.Module(body=[prefix_function], type_ignores=[]), '<production-prefix-parser>', 'exec'), prefix_namespace)
parse_native_prefix = prefix_namespace['codex_thread_id_prefix']


def emit(event, **fields):
    row = {'at': datetime.datetime.now().astimezone().isoformat(), 'event': event, **fields}
    EVENTS.append(row)
    (EVIDENCE / 'api-shared-results.json').write_text(json.dumps(EVENTS, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps(row, ensure_ascii=False), flush=True)


def thread_hash(identifier):
    return hashlib.sha256(identifier.lower().encode()).hexdigest()[:16] if identifier else None


def plain(data):
    data = re.sub(rb'\x1b\][^\x07]*(?:\x07|\x1b\\)', b'', data)
    data = re.sub(rb'\x1b\[[0-?]*[ -/]*[@-~]', b'', data)
    return data.decode('utf-8', errors='replace')


class Terminal:
    def __init__(self, name):
        self.name = name
        self.buffer = b''
        self.closed = False
        args = [str(BINARY), '--remote', 'unix://' + str(SERVER_SOCKET), '--no-alt-screen', '-C', str(WORKSPACE)]
        # 不传-c或no-daemon，两个TUI连接同一个自有测试app-server；配置只在临时目录。
        pid, master = pty.fork()
        if pid == 0:
            os.chdir(WORKSPACE)
            env = dict(os.environ)
            for key in list(env):
                if key in ('ITERM_SESSION_ID', 'TERM_SESSION_ID') or key.startswith('CODEX_'):
                    env.pop(key, None)
            env.update(TERM='xterm-256color', COLORTERM='truecolor', TERM_PROGRAM='iTermate-test-pty',
                       CODEX_HOME=str(TEST_HOME))
            os.execve(BINARY, args, env)
        self.pid, self.master = pid, master
        self.tty = ""
        CHILDREN.append(self)
        termios.tcsetwinsize(master, (40, 130))
        self.pump(2)
        output = subprocess.check_output(['ps', '-p', str(pid), '-o', 'tty='], text=True).strip()
        self.tty = '/dev/' + output
        emit('launched', name=name, pid=pid, tty=self.tty, independent_mode=False,
             private_shared_endpoint=True, sandbox='read-only')

    def pump(self, seconds):
        until = time.monotonic() + seconds
        while time.monotonic() < until:
            ready, _, _ = select.select([self.master], [], [], min(0.1, max(0, until-time.monotonic())))
            if not ready:
                continue
            try:
                chunk = os.read(self.master, 65536)
            except OSError:
                return
            if not chunk:
                return
            self.buffer = (self.buffer + chunk)[-400000:]
            if b'\x1b[6n' in chunk:
                os.write(self.master, b'\x1b[1;1R')
            if b'\x1b]11;?' in chunk:
                os.write(self.master, b'\x1b]11;rgb:0000/0000/0000\x07')
            if b'\x1b[c' in chunk:
                os.write(self.master, b'\x1b[?1;2c')

    def send(self, value):
        # 将粘贴与Enter分开，避免TUI的粘贴突发检测把Enter当作正文换行。
        if value.endswith('\r'):
            os.write(self.master, value[:-1].encode())
            self.pump(0.7)
            os.write(self.master, b'\r')
            self.pump(0.5)
        else:
            os.write(self.master, value.encode())
            self.pump(0.3)

    def status_id(self):
        before = len(self.buffer)
        self.send('/status\r')
        self.pump(2)
        text = plain(self.buffer[max(0, before-100):])
        match = re.findall(r'(?:Session|Thread)(?:\s+ID)?\s*:\s*([0-9a-f]{8}-[0-9a-f-]{27})', text, re.I)
        identifier = match[-1].lower() if match else None
        emit('status_identity', name=self.name, has_explicit_identity=identifier is not None,
             thread_hash=thread_hash(identifier), login_prompt=bool(re.search(r'Sign in|Log in', text)),
             trust_prompt='Do you trust' in text, output_chars=len(text))
        return identifier

    def native_prefix(self):
        titles = re.findall(rb'\x1b\][02];([^\x07\x1b]*)\x07', self.buffer)
        return parse_native_prefix(titles[-1].decode('utf-8', errors='replace')) if titles else None

    def owned_rollouts(self):
        output = subprocess.run(['lsof', '-p', str(SERVER.pid), '-Fn'], capture_output=True, text=True).stdout
        result = []
        for line in output.splitlines():
            if not line.startswith('n') or 'rollout-' not in line or not line.endswith('.jsonl'):
                continue
            path = pathlib.Path(line[1:])
            try:
                with path.open() as handle:
                    metadata = json.loads(handle.readline())
                payload = metadata.get('payload', {})
                if isinstance(payload.get('source'), str) and payload.get('cwd') == str(WORKSPACE):
                    result.append((payload['id'].lower(), path, metadata.get('timestamp')))
            except (OSError, ValueError, KeyError):
                pass
        return result

    def stop(self):
        if self.closed:
            return
        self.closed = True
        emit('stopping_test_process', name=self.name, pid=self.pid)
        # 只终止由本脚本fork且尚未waitpid回收的测试进程，绝不按名称批量kill。
        try:
            os.kill(self.pid, signal.SIGTERM)
        except ProcessLookupError:
            pass
        deadline = time.monotonic() + 4
        exited = 0
        while time.monotonic() < deadline:
            self.pump(0.1)
            exited, _ = os.waitpid(self.pid, os.WNOHANG)
            if exited:
                break
        if not exited:
            os.kill(self.pid, signal.SIGKILL)
            deadline = time.monotonic() + 3
            while time.monotonic() < deadline:
                self.pump(0.1)
                exited, _ = os.waitpid(self.pid, os.WNOHANG)
                if exited:
                    break
        if not exited:
            emit('cleanup_incomplete', name=self.name, pid=self.pid)
            return
        os.set_blocking(self.master, False)
        termios.tcflush(self.master, termios.TCIOFLUSH)
        os.close(self.master)
        emit('cleaned_test_process', name=self.name, pid=self.pid)


probe = subprocess.Popen([str(ROOT / '.build/codex-identity-research/monitor')], stdin=subprocess.PIPE,
                         stdout=subprocess.PIPE, text=True, env={**os.environ, 'CODEX_HOME': str(TEST_HOME)})


def observe(label, terminal, expected=None):
    prefix = terminal.native_prefix()
    request = {'ttys': [terminal.tty], 'expected': {terminal.tty: expected} if expected else {},
               'terminalThreadPrefixes': {terminal.tty: prefix} if prefix is not None else {}}
    probe.stdin.write(json.dumps(request) + '\n')
    probe.stdin.flush()
    rows = json.loads(probe.stdout.readline())
    emit('monitor_observation', case=label, observations=rows,
         native_prefix_length=len(prefix) if prefix is not None else None,
         native_prefix_matches_status=bool(prefix and expected and expected.lower().startswith(prefix.lower())))
    if prefix and expected:
        count_before = len(list(TEST_HOME.rglob('rollout-*.jsonl')))
        rpc = subprocess.run([
            '/Users/caishilin/Library/Application Support/iTerm2/iterm2env/versions/3.14.0/bin/python3',
            str(EVIDENCE / 'daemon-prefix-probe.py')], input=json.dumps({
                'socket': str(SERVER_SOCKET), 'prefix': prefix, 'expected': expected}),
            text=True, capture_output=True, timeout=15)
        if rpc.returncode == 0:
            api_result = json.loads(rpc.stdout)
            emit('native_prefix_api_resolution', case=label, result=api_result,
                 rollout_count_before=count_before, rollout_count_after=len(list(TEST_HOME.rglob('rollout-*.jsonl'))))
        else:
            emit('native_prefix_api_resolution', case=label, rpc_process_failed=True)
    return rows[0]


try:
    server_env = {key: value for key, value in os.environ.items() if not key.startswith('CODEX_')}
    server_env.update(CODEX_HOME=str(TEST_HOME), RUST_LOG='error')
    SERVER = subprocess.Popen([str(BINARY), 'app-server', '--listen', 'unix://' + str(SERVER_SOCKET)],
                              stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, env=server_env)
    deadline = time.monotonic() + 15
    while time.monotonic() < deadline and not SERVER_SOCKET.exists() and SERVER.poll() is None:
        time.sleep(0.1)
    if not SERVER_SOCKET.exists():
        raise RuntimeError('isolated_app_server_socket_unavailable')
    emit('isolated_app_server_started', pid=SERVER.pid, private_unix_socket=True)
    a = Terminal('A')
    a.pump(3)
    id_a = a.status_id()
    observe('A_before_first_prompt', a, id_a)
    a.send('Reply exactly ITERMATE_IDENTITY_PROBE_A. Do not use tools or read or modify files.\r')
    first = None
    deadline = time.monotonic() + 35
    while time.monotonic() < deadline:
        a.pump(0.4)
        roots = a.owned_rollouts()
        if len(roots) == 1:
            first = roots[0]
            break
    if first is None:
        text = plain(a.buffer)
        safe_tail = re.sub(r'[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+', '<email>', text[-1800:])
        safe_tail = re.sub(r'/[^\s\"\']+', '<path>', safe_tail)
        safe_tail = re.sub(r'[A-Za-z0-9_-]{32,}', '<redacted>', safe_tail)
        emit('first_rollout_unavailable', output_chars=len(text),
             trust_prompt='Do you trust' in text, login_prompt=bool(re.search(r'Sign in|Log in', text)),
             contains_probe_prompt='ITERMATE_IDENTITY_PROBE_A' in text,
             contains_error=bool(re.search(r'error|failed|unrecognized|unexpected', text, re.I)),
             terminal_tail=safe_tail)
        raise RuntimeError('测试进程未在截止时间内产生可核验的自有rollout，后续真实对话场景未执行')
    id_a = first[0]
    emit('owned_rollout', name='A', thread_hash=thread_hash(id_a), metadata_timestamp=first[2])
    a.pump(0.5)
    observe('A_with_owned_rollout', a, id_a)
    # 只在测试TUI内中止合成回复，随后/new验证无新prompt切换是否仍绑定旧thread。
    a.send('\x03')
    a.pump(1)
    a.send('/new\r')
    a.pump(1)
    id_b = a.status_id()
    emit('new_conversation_distinct', explicit_identity_available=id_b is not None,
         different_from_A=id_b is not None and id_b != id_a,
         own_rollout_count=len(a.owned_rollouts()))
    observe('after_new_before_first_prompt', a, id_b)
    a.send('Reply exactly ITERMATE_IDENTITY_PROBE_B. Do not use tools or read or modify files.\r')
    deadline = time.monotonic() + 25
    while time.monotonic() < deadline:
        a.pump(0.4)
        roots = a.owned_rollouts()
        if id_b and any(root[0] == id_b for root in roots):
            emit('new_conversation_materialized', own_rollout_count=len(roots), thread_hash=thread_hash(id_b))
            observe('after_new_first_prompt', a, id_b)
            break
    else:
        emit('new_conversation_rollout_unavailable')
    if id_a and id_b:
        a.send('\x03')
        a.pump(1)
        a.send('/resume ' + id_a + '\r')
        a.pump(1)
        resumed_a = a.status_id()
        emit('resume_identity', requested='A', matches_requested=resumed_a == id_a)
        observe('resume_A_without_new_prompt', a, resumed_a)
        a.send('/resume ' + id_b + '\r')
        a.pump(1)
        resumed_b = a.status_id()
        emit('resume_identity', requested='B', matches_requested=resumed_b == id_b)
        observe('resume_B_without_new_prompt', a, resumed_b)
    # 同目录第二个TUI连接相同服务，验证客户端标题互不串用。
    c = Terminal('C')
    c.pump(1)
    id_c = c.status_id()
    c.send('Reply exactly ITERMATE_IDENTITY_PROBE_C. Do not use tools or read or modify files.\r')
    deadline = time.monotonic() + 25
    while time.monotonic() < deadline:
        c.pump(0.4)
        if id_c and any(root[0] == id_c for root in c.owned_rollouts()):
            break
    actual_a = a.status_id()
    emit('shared_client_isolation', A_still_B=actual_a == id_b, C_distinct=id_c not in (id_a, id_b))
    request = {'ttys': [a.tty, c.tty], 'expected': {a.tty: actual_a, c.tty: id_c},
               'terminalThreadPrefixes': {a.tty: a.native_prefix(), c.tty: c.native_prefix()}}
    probe.stdin.write(json.dumps(request) + '\n')
    probe.stdin.flush()
    both = json.loads(probe.stdout.readline())
    emit('two_tuis_one_server', observations=both, all_exact=all(row['matchesExpected'] and row['hasThread'] for row in both))
    c.stop()
    a.stop()
except Exception as error:
    safe_lines = []
    if CHILDREN:
        text = plain(CHILDREN[-1].buffer)
        for line in text.splitlines():
            if re.search(r'error|failed|unexpected|unrecognized|fork|crash', line, re.I):
                line = re.sub(r'[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+', '<email>', line)
                line = re.sub(r'/[^\s\"\']+', '<path>', line)
                line = re.sub(r'[A-Za-z0-9_-]{32,}', '<redacted>', line)
                safe_lines.append(line[:500])
    emit('test_stopped', reason=str(error) if isinstance(error, RuntimeError) else type(error).__name__,
         errno=getattr(error, 'errno', None), os_reason=getattr(error, 'strerror', None),
         startup_errors=safe_lines[:5])
finally:
    for terminal in CHILDREN:
        try:
            terminal.stop()
        except (OSError, ChildProcessError):
            pass
    probe.stdin.close()
    probe.wait(timeout=5)
    if SERVER is not None:
        if SERVER.poll() is None:
            SERVER.terminate()
            try:
                SERVER.wait(timeout=4)
            except subprocess.TimeoutExpired:
                SERVER.kill()
                SERVER.wait(timeout=3)
        emit('isolated_app_server_stopped', pid=SERVER.pid, exited=SERVER.poll() is not None)
        SERVER.stderr.close()
    config_check = {}
    for name, expected in json.loads((EVIDENCE / 'before-sha256.json').read_text()).items():
        p = pathlib.Path(name)
        actual = hashlib.sha256(p.read_bytes()).hexdigest() if p.is_file() else None
        config_check[p.name] = actual == expected
    emit('protected_files_unchanged', checks=config_check)
    # 仅删除本脚本创建的私有临时目录；删除auth符号链接不会删除原登录文件。
    shutil.rmtree(TEST_HOME)
    emit('isolated_test_home_removed', removed=not TEST_HOME.exists())
