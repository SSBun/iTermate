"""离线缓存加载，串行执行候选，保留每次真实输出。Laya仍调用已运行的loopback服务。"""
import hashlib
import json
import os
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parent
PREVIOUS = ROOT.parents[1] / 'explore-open-system-one-models/evidence'
RUNTIME = Path('/private/tmp/itermate-system-one-eval')
models = [('laya-choice','torch-env','cpu'), ('laya-noul','torch-env','cpu'), ('gliner','torch-env','cpu'), ('gliclass','torch-env','cpu'), ('vela','torch-env','cpu'), ('kev','mlx-env','cpu'), ('system-one','mlx-env','cpu'), ('d1','torch-env','mps')]
manifest = {'schema':'itermate-agent-question-run/v1', 'sources':{}, 'runs':{}}
for path in [ROOT/'suite.json', ROOT/'prepare.py', ROOT/'evaluate.py', Path(__file__), PREVIOUS/'benchmark.py', PREVIOUS/'models.json', PREVIOUS/'summarize.py', PREVIOUS/'environment.json']:
    manifest['sources'][str(path)] = hashlib.sha256(path.read_bytes()).hexdigest()
for model, environment, device in models:
    with (ROOT/f'run-{model}.log').open('x') as log:
        try:
            result = subprocess.run([str(RUNTIME/environment/'bin/python'),str(ROOT/'evaluate.py'),model,'--device',device], stdout=log, stderr=subprocess.STDOUT, timeout=600, env={**os.environ,'HF_HUB_OFFLINE':'1','TRANSFORMERS_OFFLINE':'1','TOKENIZERS_PARALLELISM':'false','PYTHONDONTWRITEBYTECODE':'1'})
            manifest['runs'][model] = {'exit_code':result.returncode}
            path = ROOT/f'result-{model}.json'
            if path.exists():
                report = json.loads(path.read_text())
                manifest['runs'][model].update(status=report['status'],rows=len(report['rows']),error=report.get('error'))
        except subprocess.TimeoutExpired:
            manifest['runs'][model] = {'status':'timeout','seconds':600}
    (ROOT/'run-manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
    print(model,manifest['runs'][model],flush=True)
