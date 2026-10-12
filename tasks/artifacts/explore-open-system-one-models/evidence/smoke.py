"""独立检查分类API是否可区分官方风格的基础主题；不参与待回复准确率。"""
import json
from pathlib import Path
import torch
from transformers import AutoTokenizer
from gliclass import GLiClassModel, ZeroShotClassificationPipeline
from gliner2 import AutoExtractor
from benchmark import snapshot

root = Path(__file__).resolve().parent
torch.set_num_threads(4)
text = "NASA launched a new Mars rover to search for signs of ancient life."
labels = ["space", "politics", "sports", "technology", "health"]
results = {}
path = snapshot("gliclass")
model = GLiClassModel.from_pretrained(path).eval()
pipe = ZeroShotClassificationPipeline(model, AutoTokenizer.from_pretrained(path), classification_type="single-label", device="cpu", progress_bar=False)
with torch.inference_mode():
    results["gliclass"] = pipe(text, labels)
del pipe, model
model = AutoExtractor.from_pretrained(snapshot("gliner"), map_location="cpu").eval()
with torch.inference_mode():
    results["gliner"] = model.classify_text(text, {"topic":labels}, include_confidence=True)
(root / "api-smoke.json").write_text(json.dumps(results, indent=2)+"\n")
print(json.dumps(results, indent=2))
