"""隔离部署及真实本机 API 路径诊断；不执行单元测试或修改用户安装态。"""
from pathlib import Path
import hashlib
import json
import os
import subprocess
import tempfile
import time
import urllib.error
import urllib.request

ROOT = Path(__file__).resolve().parents[4]
HERE = Path(__file__).resolve().parent
HELPER = ROOT / 'integrations/laya/iTermate-laya.py'


def main():
    opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
    observed = {'mode': 'isolated deployment and real local inference; not a test suite',
                'helper_sha256': hashlib.sha256(HELPER.read_bytes()).hexdigest(), 'cases': []}
    with tempfile.TemporaryDirectory(prefix='itermate-2b-classifier-') as temporary:
        directory = Path(temporary)
        python = directory / 'LocalLLM/runtime/bin/python'
        subprocess.run(['/opt/homebrew/bin/uv', 'venv', '--python', '3.12', str(python.parent.parent)],
                       check=True, capture_output=True, timeout=90)
        environment = dict(os.environ, PYTHONDONTWRITEBYTECODE='1')
        deploy = subprocess.run([str(python), str(HELPER), 'download', '--directory', str(directory),
                                 '--provider', 'local-llm'], env=environment, check=True,
                                capture_output=True, text=True, timeout=30)
        observed['deployment_events'] = [json.loads(line) for line in deploy.stdout.splitlines() if line.startswith('{')]
        marker = json.loads((directory / 'LocalLLM/model.json').read_text())
        observed['deployed_model'] = marker['model']
        observed['deployed_revision'] = marker['revision']
        worker = subprocess.Popen([str(python), str(HELPER), 'serve', '--directory', str(directory),
                                   '--provider', 'local-llm', '--parent-pid', str(os.getpid())],
                                  env=environment, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        try:
            started = time.monotonic()
            for _ in range(250):
                if worker.poll() is not None:
                    raise RuntimeError('Classifier bridge failed to start')
                if (directory / 'endpoint.json').exists():
                    break
                time.sleep(.1)
            else:
                raise RuntimeError('Classifier bridge readiness deadline exceeded')
            observed['startup_ms'] = round((time.monotonic() - started) * 1000, 3)
            endpoint = json.loads((directory / 'endpoint.json').read_text())
            token = (directory / 'api-token').read_text().strip()
            base = endpoint['url']
            if not base.startswith('http://127.0.0.1:'):
                raise RuntimeError('Unexpected endpoint')

            def call(path, state=None, headers=None):
                payload = None if state is None else json.dumps({'state': state}, ensure_ascii=False).encode()
                request = urllib.request.Request(base + path, data=payload,
                    headers={'Content-Type': 'application/json', 'Authorization': 'Bearer ' + token, **(headers or {})})
                started = time.monotonic()
                try:
                    with opener.open(request, timeout=11) as response:
                        status, value = response.status, json.load(response)
                except urllib.error.HTTPError as error:
                    status, value = error.code, json.load(error)
                return {'status': status, 'wall_ms': round((time.monotonic() - started) * 1000, 3),
                        'identity_matches': value.get('provider') == 'local-llm' and value.get('instance') == endpoint['instance'] if status == 200 else None,
                        'response': {key: item for key, item in value.items() if key != 'instance'}}

            observed['health'] = call('/health')
            for name, text in [
                ('completed-calculation', '按点赞数格式化规则计算：13528 为 1.3万，19999 为 1.9万。当前两端都是截断，不四舍五入。'),
                ('requires-choice', '请选择导出格式：JSON 还是 CSV？请选一个，我再继续。'),
                ('completed-work', '修改已完成，类型检查通过，无需你进一步回复。'),
            ]:
                row = call('/v1/question', text)
                row['name'] = name
                observed['cases'].append(row)
            observed['session_compatibility'] = call('/v1/session', '请选择方案 A 或方案 B。')
            observed['bad_token'] = call('/health', headers={'Authorization': 'Bearer invalid'})
            observed['browser_origin'] = call('/health', headers={'Origin': 'https://example.invalid'})
            observed['generic_decision'] = call('/v1/decide', 'A reply')
            observed['oversized_reply'] = call('/v1/question', 'x' * 3001)
        finally:
            worker.terminate()
            try:
                worker.communicate(timeout=5)
            except subprocess.TimeoutExpired:
                worker.kill()
                worker.communicate()
    observed['isolated_worker_stopped_and_credentials_removed'] = True
    (HERE / 'local-llm-diagnostics-final.json').write_text(json.dumps(observed, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps(observed, ensure_ascii=False, indent=2))


if __name__ == '__main__':
    main()
