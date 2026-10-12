"""仅下载评估需要的权重及推理代码，固定版本并保留下载结果。"""
import json
from pathlib import Path
import shutil
import sys
import time
from huggingface_hub import snapshot_download

ROOT = Path(__file__).resolve().parent
models = json.loads((ROOT / "models.json").read_text())
results = {}
for name in sys.argv[1:] or models:
    started = time.time()
    try:
        if shutil.disk_usage(ROOT).free < 12 * 1024**3:
            raise RuntimeError("剩余空间不足12GiB，停止下载以保护现有环境")
        spec = models[name]
        patterns = ["*.json", "*.py", "*.safetensors", "*.pt", "*.model", "*.txt", "*.jinja", "LICENSE*", "README.md"]
        path = snapshot_download(spec["repo"], revision=spec["revision"], allow_patterns=patterns, ignore_patterns=["onnx/*", "assets/*", "figures/*"], max_workers=3)
        results[name] = dict(path=path, seconds=time.time()-started, revision=spec["revision"])
    except Exception as error:
        results[name] = dict(error=str(error), seconds=time.time()-started)
    (ROOT / ("downloads-" + "-".join(sys.argv[1:] or ["all"]) + ".json")).write_text(json.dumps(results, indent=2)+"\n")
    print(name, results[name], flush=True)
