"""对运行中的本机 Vela 服务执行固定场景评估，不启动或修改服务。"""
import collections
import datetime
import hashlib
import json
import pathlib
import statistics
import time
import urllib.error
import urllib.parse
import urllib.request

HERE = pathlib.Path(__file__).resolve().parent
ROOT = pathlib.Path.home() / 'Library/Application Support/iTermate/Laya'
LABELS = ['running', 'awaitingInput', 'idle', 'unknown']


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, *args, **kwargs):
        return None


def main():
    dataset_bytes = (HERE / 'scenarios.json').read_bytes()
    cases = json.loads(dataset_bytes)['cases']
    assert len(cases) == 40 and len({c['id'] for c in cases}) == 40
    assert collections.Counter(c['expected'] for c in cases) == dict.fromkeys(LABELS, 10)
    assert all(0 < len(c['text']) <= 1500 for c in cases)
    assert all(sum(c['expected'] == label and c['language'] == lang for c in cases) == 5
               for label in LABELS for lang in ['zh', 'en'])
    identity = tuple((ROOT / name).read_bytes() for name in
                     ['configuration.json', 'analysis-enabled', 'endpoint.json'])
    config, endpoint = json.loads(identity[0]), json.loads(identity[2])
    assert config['provider'] == endpoint['provider'] == 'vela'
    assert config['analysisEnabled'] and config['serviceEnabled']
    assert identity[1].decode() == config['revision']
    url = urllib.parse.urlparse(endpoint['url'])
    assert url.scheme == 'http' and url.hostname == '127.0.0.1' and url.port
    token = (ROOT / 'api-token').read_text().strip()
    opener = urllib.request.build_opener(urllib.request.ProxyHandler({}), NoRedirect())

    def check_identity():
        assert identity == tuple((ROOT / name).read_bytes() for name in
                                 ['configuration.json', 'analysis-enabled', 'endpoint.json']), '服务配置发生变化'

    def request(path, text=None):
        check_identity()
        payload = None if text is None else json.dumps({'state': text}, ensure_ascii=False).encode()
        req = urllib.request.Request(f'http://127.0.0.1:{url.port}{path}', data=payload,
                                     headers={'Authorization': 'Bearer ' + token, 'Content-Type': 'application/json'})
        with opener.open(req, timeout=30) as response:
            value = json.load(response)
        check_identity()
        assert value['provider'] == 'vela' and value['instance'] == endpoint['instance'], '服务身份不一致'
        return value

    health = request('/health')
    assert health['ready']
    stamp = datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%S%fZ')
    result_path = HERE / ('results-' + stamp + '.json')
    result = {'schema': 'vela-session-evaluation/v1', 'time_utc': stamp,
              'dataset_sha256': hashlib.sha256(dataset_bytes).hexdigest(),
              'provider': health['provider'], 'model': health['model'],
              'endpoint_instance_sha256': hashlib.sha256(endpoint['instance'].encode()).hexdigest(),
              'timeout_seconds': 30, 'bridge_timeout_seconds': 0.8,
              'note': '单轮合成场景评估；原样发送文本，不重写提示词；仅429最多重试两次。显示规则按无权威生命周期状态且缓存未过期计算。',
              'cases': []}
    for case in cases:
        entry = dict(case)
        for attempt in range(3):
            started = time.monotonic()
            try:
                response = request('/v1/session', case['text'])
                elapsed = (time.monotonic() - started) * 1000
                assert response['model'] == health['model'], '模型身份变化'
                state = response['answers']['state']
                choice = state['choice']
                assert choice in LABELS
                probability = state['probabilities'][choice]
                needs_reply = response['answers'].get('needs_reply', {}).get('noul', 0)
                shown = choice != 'unknown' and probability >= 0.85 and (choice != 'awaitingInput' or needs_reply >= 0.6)
                entry.update(predicted=choice, correct=choice == case['expected'],
                             shown=shown, wall_ms=round(elapsed, 3), attempts=attempt + 1,
                             within_bridge_timeout=elapsed <= 800,
                             response={k: v for k, v in response.items() if k != 'instance'})
                break
            except urllib.error.HTTPError as error:
                if error.code == 429 and attempt < 2:
                    time.sleep(0.5)
                    continue
                entry.update(error='HTTP ' + str(error.code), attempts=attempt + 1)
                break
            except (urllib.error.URLError, TimeoutError) as error:
                entry.update(error=type(error).__name__, attempts=attempt + 1)
                break
        result['cases'].append(entry)
        result_path.write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
        print(case['id'], entry.get('predicted', entry.get('error')), flush=True)
    check_identity()
    assert (HERE / 'scenarios.json').read_bytes() == dataset_bytes
    good = [c for c in result['cases'] if 'predicted' in c]
    shown = [c for c in good if c['shown']]
    matrix = {label: dict.fromkeys(LABELS, 0) for label in LABELS}
    for c in good:
        matrix[c['expected']][c['predicted']] += 1
    correct = sum(c['correct'] for c in good)
    result['metrics'] = {
        'total': len(cases), 'successful': len(good), 'errors': len(cases) - len(good),
        'correct': correct, 'accuracy_all': correct / len(cases),
        'accuracy_successful': correct / len(good) if good else None,
        'per_class': {label: {'total': 10, 'correct': sum(c['correct'] for c in good if c['expected'] == label)} for label in LABELS},
        'confusion_matrix': matrix,
        'shown': len(shown), 'coverage_all': len(shown) / len(cases),
        'shown_correct': sum(c['correct'] for c in shown),
        'shown_accuracy': sum(c['correct'] for c in shown) / len(shown) if shown else None,
        'unknown_false_displays': sum(c['expected'] == 'unknown' for c in shown),
        'known_display_coverage': sum(c['expected'] != 'unknown' for c in shown) / 30,
        'over_bridge_timeout': sum(not c['within_bridge_timeout'] for c in good),
        'wall_ms_median': statistics.median(c['wall_ms'] for c in good) if good else None,
        'wall_ms_max': max((c['wall_ms'] for c in good), default=None),
        'per_language': {lang: {'total': 20, 'correct': sum(c['correct'] for c in good if c['language'] == lang)} for lang in ['zh', 'en']},
    }
    result_path.write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps({'result_file': str(result_path), 'metrics': result['metrics']}, ensure_ascii=False, indent=2))


if __name__ == '__main__':
    main()
