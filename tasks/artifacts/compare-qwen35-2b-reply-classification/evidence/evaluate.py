"""沿用已冻结的前轮协议，仅实测本机 Qwen3.5-2B，不调用 Vela 或 0.8B。"""
import collections
import datetime
import hashlib
import json
import math
from pathlib import Path
import random
import statistics
import time
import urllib.error
import urllib.request

HERE = Path(__file__).resolve().parent
BASELINE = HERE.parents[1] / 'compare-qwen35-08b-reply-classification/evidence'
MODEL = 'qwen3.5:2b'
LABELS = ['normal', 'question']


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, *args, **kwargs):
        return None


def main():
    protected = json.loads((HERE / 'protected-files.json').read_text())

    def check_protected():
        for name, expected in protected.items():
            assert hashlib.sha256(Path(name).read_bytes()).hexdigest() == expected, name

    check_protected()
    dataset = (BASELINE / 'cases.json').read_bytes()
    source = (BASELINE / 'results-20261020T094324Z.json').read_bytes()
    previous = json.loads(source)
    protocol = previous['protocol']
    cases = json.loads(dataset)['cases']
    assert hashlib.sha256(dataset).hexdigest() == previous['dataset_sha256']
    assert len(cases) == len({c['id'] for c in cases}) == 40
    assert collections.Counter((c['expected'], c['language']) for c in cases) == {
        (label, language): 10 for label in LABELS for language in ['zh', 'en']}
    opener = urllib.request.build_opener(urllib.request.ProxyHandler({}), NoRedirect())

    def request(path, body=None):
        data = None if body is None else json.dumps(body, ensure_ascii=False).encode()
        req = urllib.request.Request('http://127.0.0.1:11434' + path, data=data,
                                     headers={'Content-Type': 'application/json'})
        with opener.open(req, timeout=protocol['http_timeout_seconds']) as response:
            return json.load(response)

    tags = request('/api/tags')
    assert {m['name'] for m in tags['models']} == {'qwen3.5:0.8b', MODEL}
    selected = next(m for m in tags['models'] if m['name'] == MODEL)
    show = request('/api/show', {'model': MODEL})
    version = request('/api/version')
    assert version == previous['environment']['ollama'], 'Ollama 版本改变'
    stamp = datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%SZ')
    result_path = HERE / ('results-' + stamp + '.json')
    assert not result_path.exists()
    result = {
        'schema': 'qwen2b-reply-evaluation/v1', 'time_utc': stamp,
        'dataset_sha256': hashlib.sha256(dataset).hexdigest(),
        'baseline_result_sha256': hashlib.sha256(source).hexdigest(),
        'script_sha256': hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
        'protocol': protocol,
        'environment': {'ollama': version, 'installed_models': tags['models'],
                        'selected_model': selected, 'model_details': show.get('details'),
                        'thinking_support': show.get('thinking')},
        'historical_baseline_metrics': previous['metrics'],
        'baseline_note': 'Vela 和 0.8B 为前轮保存结果，本轮未重新推理；延迟并非同场配对比较。',
        'current_execution_note': 'protocol 原样保存前轮定义；本轮仅执行 2B，沿用三轮洗牌次序，但不执行其中描述的双模型交替调度。',
        'load_calls': [], 'calls': []}

    def save():
        result_path.write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')

    def classify(text):
        started = time.monotonic()
        row = {'model': MODEL}
        try:
            response = request('/api/chat', {
                'model': MODEL,
                'messages': [{'role': 'system', 'content': protocol['qwen_system_prompt']},
                             {'role': 'user', 'content': text}],
                'think': protocol['qwen_think'], 'stream': False,
                'options': protocol['qwen_options'], 'keep_alive': '10m'})
            row['output'] = response['message']['content']
            row['timings'] = {key: response.get(key) for key in [
                'total_duration', 'load_duration', 'prompt_eval_count',
                'prompt_eval_duration', 'eval_count', 'eval_duration']}
            row['unexpected_thinking_characters'] = len(response['message'].get('thinking', ''))
            assert response['model'] == MODEL and response['done']
            assert response.get('done_reason') == 'stop'
            assert row['unexpected_thinking_characters'] == 0
            decoded = json.loads(row['output'])
            assert isinstance(decoded, dict) and set(decoded) == {'label'}
            assert decoded['label'] in LABELS
            row['label'] = decoded['label']
        except urllib.error.HTTPError as error:
            row['error'] = 'HTTP ' + str(error.code)
        except (urllib.error.URLError, TimeoutError, AssertionError, KeyError, ValueError, TypeError) as error:
            row['error'] = type(error).__name__
        row['wall_ms'] = round((time.monotonic() - started) * 1000, 3)
        row['within_800ms'] = row['wall_ms'] <= protocol['product_deadline_ms']
        return row

    unload = request('/api/generate', {'model': MODEL, 'keep_alive': 0})
    result['environment']['unload_response_done_reason'] = unload.get('done_reason')
    before = request('/api/ps')
    assert all(m['name'] != MODEL for m in before['models']), '2B 未卸载'
    for phase in ['unloaded-first-call', 'same-input-hot-call']:
        call = classify('The work is complete.')
        call['phase'] = phase
        result['load_calls'].append(call)
        save()
        print(phase, call.get('label', call.get('error')), call['wall_ms'], flush=True)
        assert not str(call.get('error', '')).startswith('HTTP '), '模型服务调用失败'
    result['environment']['ps_after_load'] = request('/api/ps')
    for repeat in range(protocol['repeats']):
        ordered = list(cases)
        random.Random(protocol['order_seed'] + repeat).shuffle(ordered)
        for case in ordered:
            assert (BASELINE / 'cases.json').read_bytes() == dataset
            row = classify(case['text'])
            row.update(case_id=case['id'], repeat=repeat + 1,
                       expected=case['expected'], language=case['language'])
            result['calls'].append(row)
            save()
            print(repeat + 1, case['id'], row.get('label', row.get('error')), row['wall_ms'], flush=True)
            time.sleep(.05)
    check_protected()
    after = request('/api/tags')
    assert {m['name'] for m in after['models']} == {'qwen3.5:0.8b', MODEL}
    assert next(m for m in after['models'] if m['name'] == MODEL)['digest'] == selected['digest']
    entries = result['calls']
    valid = [r for r in entries if 'label' in r and 'error' not in r]
    durations = sorted(r['wall_ms'] for r in entries)
    matrix = {label: dict.fromkeys(LABELS, 0) for label in LABELS}
    for row in valid:
        matrix[row['expected']][row['label']] += 1
    result['metrics'] = {
        'requests': len(entries), 'valid': len(valid), 'errors': len(entries) - len(valid),
        'correct': sum(r['label'] == r['expected'] for r in valid), 'matrix': matrix,
        'false_positives': matrix['normal']['question'],
        'false_negatives': matrix['question']['normal'],
        'wrong_case_ids': sorted({r['case_id'] for r in valid if r['label'] != r['expected']}),
        'error_case_ids': sorted({r['case_id'] for r in entries if 'error' in r}),
        'wall_ms_p50': statistics.median(durations),
        'wall_ms_p95_nearest_rank': durations[math.ceil(.95 * len(durations)) - 1],
        'wall_ms_max': max(durations), 'over_800ms': sum(not r['within_800ms'] for r in entries),
        'deadline_correct': sum(r.get('label') == r['expected'] and r['within_800ms']
                                and 'error' not in r for r in entries),
        'round_correct': [sum(r.get('label') == r['expected'] and 'error' not in r
                              for r in entries if r['repeat'] == repeat) for repeat in [1, 2, 3]]}
    save()
    print(json.dumps({'result_file': str(result_path), 'metrics': result['metrics']}, ensure_ascii=False, indent=2))


if __name__ == '__main__':
    main()
