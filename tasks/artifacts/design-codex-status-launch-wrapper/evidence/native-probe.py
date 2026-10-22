"""隔离验证真实 Codex 的 Unix WebSocket 传输；不创建 thread 或模型轮次。"""
import base64
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import socket
import subprocess
import tempfile
import threading
import time

root = Path('/Users/caishilin/Desktop/personal/iTermate')
spec = importlib.util.spec_from_file_location('wrapper_tests', root / 'integrations/status/test_codex_wrapper.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
wrapper = module.wrapper

with tempfile.TemporaryDirectory(prefix='itc-native-', dir='/tmp') as directory:
    backend = Path(directory) / 'backend.sock'
    home = Path(directory) / 'home'
    home.mkdir()
    (home / '.codex').mkdir()
    environment = dict(os.environ, HOME=str(home), CODEX_HOME=str(home / '.codex'))
    with open(Path(directory) / 'stderr.log', 'w') as error_log:
        process = subprocess.Popen(
            ['codex', 'app-server', '--listen', 'unix://' + str(backend)],
            stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=error_log,
            env=environment, cwd=home, start_new_session=True,
        )
        peers = []
        threads = []
        try:
            deadline = time.monotonic() + 15
            while not backend.exists():
                if process.poll() is not None:
                    raise RuntimeError((Path(directory) / 'stderr.log').read_text()[-3000:])
                assert time.monotonic() < deadline, 'native startup timed out'
                time.sleep(.05)
            client, local = socket.socketpair()
            upstream = socket.socket(socket.AF_UNIX)
            upstream.connect(str(backend))
            peers = [client, local, upstream]
            monitor = wrapper.StatusMonitor()
            for source, destination, server in ((local, upstream, False), (upstream, local, True)):
                thread = threading.Thread(target=wrapper.relay, args=(source, destination, monitor, server), daemon=True)
                thread.start()
                threads.append(thread)
            client.settimeout(5)
            key = base64.b64encode(os.urandom(16)).decode()
            client.sendall(('GET / HTTP/1.1\r\nHost: localhost\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Version: 13\r\nSec-WebSocket-Key: ' + key + '\r\n\r\n').encode())
            headers = b''
            while b'\r\n\r\n' not in headers:
                headers += client.recv(1)
            assert headers.startswith(b'HTTP/1.1 101 '), headers.split(b'\r\n')[0]
            accept = base64.b64encode(hashlib.sha1((key + '258EAFA5-E914-47DA-95CA-C5AB0DC85B11').encode()).digest())
            assert accept in headers
            received = []
            observer = wrapper.WebSocketObserver(received.append)
            observer.upgraded = True
            def response(request_id):
                while True:
                    for message in received:
                        if message.get('id') == request_id:
                            assert 'error' not in message, message['error']
                            return message['result']
                    observer.feed(client.recv(65536))
            client.sendall(module.frame({'id': 1, 'method': 'initialize', 'params': {'clientInfo': {'name': 'itermate_protocol_probe', 'version': '1.0'}}}, mask=True))
            initialized = response(1)
            client.sendall(module.frame({'method': 'initialized', 'params': {}}, mask=True))
            client.sendall(module.frame({'id': 2, 'method': 'thread/loaded/list', 'params': {}}, mask=True))
            loaded = response(2)
            assert loaded.get('data') == [], loaded
            print(json.dumps({'nativeHandshake': True, 'initialize': True, 'loadedThreads': 0, 'observerClosed': monitor.closed}))
        finally:
            for peer in peers:
                peer.close()
            wrapper.stop_process(process, process_group=True)
            for thread in threads:
                thread.join(timeout=1)
            print(json.dumps({'ownedBackendExited': process.poll() is not None}))
