"""下载完成后顺序运行真实模型，模型之间不并行占用加速器。"""
import json
import os
from pathlib import Path
import subprocess
import time

ROOT = Path(__file__).resolve().parent
RUNTIME = Path('/private/tmp/itermate-system-one-eval')
results = {}
started = time.monotonic()
for model, download, env, device in [
    ('gliner', 'gliner', 'torch-env', 'cpu'),
    ('gliclass', 'gliclass', 'torch-env', 'cpu'),
    ('vela', 'vela', 'torch-env', 'cpu'),
    ('kev', 'kev', 'mlx-env', 'cpu'),
    ('system-one', 'qwen-base', 'mlx-env', 'cpu'),
    ('d1', 'd1', 'torch-env', 'mps'),
]:
    while True:
        manifest = ROOT / 'downloads-all.json'
        try:
            downloads = json.loads(manifest.read_text()) if manifest.exists() else {}
        except json.JSONDecodeError:
            downloads = {}
        if download in downloads:
            break
        if time.monotonic() - started > 3600:
            raise TimeoutError('等待下载超过一小时，保留已有证据')
        time.sleep(10)
    if 'error' in downloads[download]:
        results[model] = dict(status='download_failed', error=downloads[download]['error'])
    else:
        with (ROOT / f'run-{model}.log').open('w') as log:
            try:
                process = subprocess.run([str(RUNTIME / env / 'bin/python'), str(ROOT / 'benchmark.py'), model, '--device', device], stdout=log, stderr=subprocess.STDOUT, timeout=900, env={**os.environ, 'HF_HUB_DISABLE_XET':'1', 'HF_HUB_DOWNLOAD_TIMEOUT':'60', 'TOKENIZERS_PARALLELISM':'false'})
                results[model] = dict(exit_code=process.returncode)
            except subprocess.TimeoutExpired:
                results[model] = dict(status='timed_out', timeout_seconds=900)
    (ROOT / 'candidate-run-status.json').write_text(json.dumps(results, ensure_ascii=False, indent=2)+'\n')
    print(model, results[model], flush=True)
subprocess.run(['python3', str(ROOT / 'summarize.py')], check=True)
