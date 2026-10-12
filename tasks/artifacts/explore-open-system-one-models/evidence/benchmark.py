"""真实本地推理评估；固定样本，不使用正则分类或mock，不改运行中服务。"""
import argparse
import hashlib
import importlib.metadata
import json
import math
import os
from pathlib import Path
import platform
import resource
import statistics
import time
import traceback
import urllib.error
import urllib.parse
import urllib.request

ROOT = Path(__file__).resolve().parent
RUNTIME = Path("/private/tmp/itermate-system-one-eval")
SUITE = json.loads((ROOT / "suite.json").read_text())
MODELS = json.loads((ROOT / "models.json").read_text())
QUESTION = {"type": "choice", "instructions": SUITE["instructions"], "criteria": SUITE["criteria"]}


def snapshot(name):
    from huggingface_hub import snapshot_download
    spec = MODELS[name]
    return snapshot_download(spec["repo"], revision=spec["revision"], local_files_only=True, allow_patterns=["*.json", "*.py", "*.safetensors", "*.pt", "*.model", "*.txt", "*.jinja", "LICENSE*", "README.md"], ignore_patterns=["onnx/*", "assets/*", "figures/*"])


def service_client():
    directory = Path.home() / "Library/Application Support/iTermate/Laya"
    url = json.loads((directory / "endpoint.json").read_text())["url"]
    parsed = urllib.parse.urlsplit(url)
    assert parsed.scheme == "http" and parsed.hostname == "127.0.0.1" and parsed.port
    assert not parsed.username and not parsed.password
    token = (directory / "api-token").read_text().strip()

    class NoRedirect(urllib.request.HTTPRedirectHandler):
        def redirect_request(self, *args, **kwargs):
            raise RuntimeError("拒绝重定向")

    opener = urllib.request.build_opener(urllib.request.ProxyHandler({}), NoRedirect())

    def request(path, payload=None):
        body = None if payload is None else json.dumps(payload).encode()
        for attempt in range(3):
            req = urllib.request.Request(url.rstrip("/") + path, body, {"Authorization": "Bearer " + token, "Content-Type": "application/json"})
            try:
                with opener.open(req, timeout=10) as response:
                    return json.load(response)
            except urllib.error.HTTPError as error:
                if error.code != 429 or attempt == 2:
                    raise RuntimeError(f"本地服务HTTP {error.code}") from None
                time.sleep(0.3 * (attempt + 1))
    return request


def load_predictor(name, device):
    if name.startswith("laya"):
        client = service_client()
        health = client("/health")
        assert health["ready"] is True
        def predict(text):
            if name == "laya-product":
                raw = client("/v1/session", {"state": text})
                answers = raw["answers"]
                state = answers["state"]["choice"]
                p = answers["state"]["probabilities"][state]
                reply = answers["needs_reply"]["noul"]
                pred = "question" if state == "awaitingInput" and p >= .85 and reply >= .6 else "normal" if state == "idle" and p >= .85 and reply <= .4 else None
                return pred, raw
            q = QUESTION if name == "laya-choice" else {"type": "noul", "instructions": SUITE["instructions"]}
            raw = client("/v1/decide", {"state": text, "questions": {"reply": q}})
            answer = raw["answers"]["reply"]
            pred = answer["choice"] if name == "laya-choice" else "question" if answer["noul"] >= .5 else "normal"
            return pred, raw
        return predict, {"service": health, "backend": "existing-loopback-service", "load_ms": None}

    if name == "system-one":
        from jev.engine import SystemOneEngine
        project = RUNTIME / "system-one"
        model = SystemOneEngine(snapshot("qwen-base"), adapter_path=str(project / "adapters/qwen3-0.6b-structured-v1-synthfiltered-rps"), temperature_path=str(project / "release/temperature-qwen3-0.6b.json"))
        def predict(text):
            raw = model.respond({"state": text, "questions": {"reply": QUESTION}})
            return raw["answers"]["reply"]["choice"], raw
        return predict, {"backend": "mlx", "identity": model.describe()}

    if name == "kev":
        from kev.predictors import LocalPredictor
        from kev.checkpoint import LoadOptions
        model = LocalPredictor(snapshot("kev"), "cpu", LoadOptions(backend="mlx"))
        from kev.api import SystemOneRequest, to_record, to_answers
        import torch
        def predict(text):
            # Use the serving encoder, not LocalPredictor.__call__, which requires labelled training records.
            record, meta = to_record(SystemOneRequest.model_validate({"state": text, "questions": {"reply": QUESTION}}))
            with torch.inference_mode():
                encoded = model.model.encode(model.tok, record, max_state=model.context["max_state"], max_branch=model.context["max_branch"], strict=True)
                logits = model.model.forward(encoded)
                probabilities = [torch.softmax(value, -1).cpu().tolist() for value in logits]
            raw = {"answers": to_answers(probabilities, meta), "input_tokens": len(encoded["ids"])}
            return raw["answers"]["reply"]["choice"], raw
        return predict, {"backend": "mlx", "environment": model.environment}

    import torch
    torch.set_num_threads(4)
    torch.manual_seed(0)
    path = snapshot(name)
    if name == "gliner":
        from gliner2 import AutoExtractor
        model = AutoExtractor.from_pretrained(path, map_location=device)
        model.eval()
        def predict(text):
            with torch.inference_mode():
                raw = model.classify_text(text, {"reply": {"labels": SUITE["criteria"], "prompt": SUITE["instructions"]}}, include_confidence=True)
            return raw["reply"]["label"], raw
    elif name == "gliclass":
        from gliclass import GLiClassModel, ZeroShotClassificationPipeline
        from transformers import AutoTokenizer
        model = GLiClassModel.from_pretrained(path)
        model.eval()
        pipe = ZeroShotClassificationPipeline(model, AutoTokenizer.from_pretrained(path), classification_type="single-label", device=device, progress_bar=False)
        labels = [f"{key}: {value}" for key, value in SUITE["criteria"].items()]
        lookup = dict(zip(labels, SUITE["criteria"]))
        def predict(text):
            with torch.inference_mode():
                raw = pipe(text, labels, prompt=SUITE["instructions"])[0]
            best = max(raw, key=lambda item: item["score"])
            return lookup[best["label"]], raw
    else:
        from transformers import AutoModel
        dtype = torch.bfloat16 if name == "d1" and device != "cpu" else torch.float32
        model = AutoModel.from_pretrained(path, trust_remote_code=True, dtype=dtype).to(device)
        model.eval()
        def predict(text):
            with torch.inference_mode():
                raw = model.system_one(text, {"reply": QUESTION})
            return raw["answers"]["reply"]["choice"], raw
    def synchronized(text):
        if device == "mps":
            torch.mps.synchronize()
        result = predict(text)
        if device == "mps":
            torch.mps.synchronize()
        return result
    return synchronized, {"backend": f"torch-{device}", "threads": 4}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("model", choices=["laya-choice", "laya-noul", "laya-product", "gliner", "gliclass", "vela", "kev", "system-one", "d1"])
    parser.add_argument("--device", default="cpu", choices=["cpu", "mps"])
    parser.add_argument("--tag", default="")
    args = parser.parse_args()
    name = args.model + ("-" + args.tag if args.tag else "")
    target = ROOT / f"result-{name}.json"
    if target.exists():
        raise RuntimeError("禁止覆盖已有评估证据，请使用新的tag")
    report = dict(model=args.model, platform=platform.platform(), python=platform.python_version(), suite_sha256=hashlib.sha256((ROOT / "suite.json").read_bytes()).hexdigest(), harness_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(), spec=MODELS.get(args.model), started_at=time.strftime("%Y-%m-%dT%H:%M:%S%z"), rows=[], status="loading", versions={})
    for package in ["torch", "transformers", "mlx", "mlx-lm", "gliner2", "gliclass", "kev"]:
        try:
            report["versions"][package] = importlib.metadata.version(package)
        except importlib.metadata.PackageNotFoundError:
            pass
    def save():
        target.write_text(json.dumps(report, ensure_ascii=False, indent=2, default=str, allow_nan=False) + "\n")
    save()
    try:
        start = time.perf_counter()
        predict, info = load_predictor(args.model, args.device)
        report.update(info)
        report["initialization_ms"] = (time.perf_counter() - start) * 1000
        start = time.perf_counter()
        report["warmup"] = predict("The requested changes are complete. No response is needed.")
        report["first_inference_ms"] = (time.perf_counter() - start) * 1000
        report["status"] = "running"
        save()
        for round_index in range(SUITE["rounds"]):
            for sample in SUITE["rows"]:
                start = time.perf_counter()
                row = dict(sample, round=round_index + 1)
                try:
                    pred, raw = predict(sample["text"])
                    if pred not in ("normal", "question", None):
                        raise ValueError(f"非法输出类别：{pred}")
                    row.update(predicted=pred, raw=raw, elapsed_ms=(time.perf_counter()-start)*1000, correct=pred == sample["expected"])
                except Exception as error:
                    row.update(error=type(error).__name__ + ": " + str(error), elapsed_ms=(time.perf_counter()-start)*1000)
                report["rows"].append(row)
                save()
                print(name, row["round"], sample["id"], row.get("predicted", row.get("error")), round(row["elapsed_ms"], 1), flush=True)
        report["status"] = "complete"
    except Exception as error:
        report["status"] = "blocked"
        report["error"] = type(error).__name__ + ": " + str(error)
        report["traceback"] = traceback.format_exc()
        print(report["traceback"], flush=True)
    finally:
        report["peak_process_rss_bytes"] = resource.getrusage(resource.RUSAGE_SELF).ru_maxrss
        report["finished_at"] = time.strftime("%Y-%m-%dT%H:%M:%S%z")
        save()


if __name__ == "__main__":
    main()
