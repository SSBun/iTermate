"""复用已审查的模型适配器，只替换本任务冻结定义和输出位置。"""
import importlib.util
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent
PREVIOUS = ROOT.parents[1] / 'explore-open-system-one-models/evidence'
spec = importlib.util.spec_from_file_location('decision_benchmark', PREVIOUS / 'benchmark.py')
benchmark = importlib.util.module_from_spec(spec)
spec.loader.exec_module(benchmark)
benchmark.ROOT = ROOT
benchmark.SUITE = json.loads((ROOT / 'suite.json').read_text())
benchmark.QUESTION = {'type': 'choice', 'instructions': benchmark.SUITE['instructions'], 'criteria': benchmark.SUITE['criteria']}

if __name__ == '__main__':
    benchmark.main()
