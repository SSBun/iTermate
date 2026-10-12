"""从逐例证据计算指标；拒判及服务失败不伪装成正常回答。"""
import hashlib
import json
import math
from pathlib import Path
import statistics

ROOT = Path(__file__).resolve().parent


def metrics(rows):
    valid = [row for row in rows if "error" not in row and row.get("predicted") in ("normal", "question")]
    tp = sum(row["expected"] == "question" and row["predicted"] == "question" for row in valid)
    tn = sum(row["expected"] == "normal" and row["predicted"] == "normal" for row in valid)
    fp = sum(row["expected"] == "normal" and row["predicted"] == "question" for row in valid)
    fn = sum(row["expected"] == "question" and row["predicted"] == "normal" for row in valid)
    positives = sum(row["expected"] == "question" for row in rows)
    negatives = len(rows) - positives
    latencies = sorted(row["elapsed_ms"] for row in rows if "error" not in row)
    return dict(samples=len(rows), classified=len(valid), errors=sum("error" in row for row in rows), abstained=sum("error" not in row and row.get("predicted") is None for row in rows), correct=tp+tn, accuracy=(tp+tn)/len(rows) if rows else None, tp=tp, tn=tn, fp=fp, fn=fn, question_recall=tp/positives if positives else None, normal_false_positive_rate=fp/negatives if negatives else None, p50_ms=statistics.median(latencies) if latencies else None, p95_ms=latencies[math.ceil(.95*len(latencies))-1] if latencies else None)


def summarize(report):
    first = [row for row in report["rows"] if row["round"] == 1]
    second = {row["id"]: row for row in report["rows"] if row["round"] == 2}
    comparable = [row for row in first if row["id"] in second and "error" not in row and "error" not in second[row["id"]]]
    return dict(model=report["model"], status=report["status"], error=report.get("error"), backend=report.get("backend"), overall=metrics(first), by_language={language: metrics([row for row in first if row["language"] == language]) for language in ["zh", "en"]}, by_split={split: metrics([row for row in first if row["split"] == split]) for split in ["regression", "new"]}, repeated_rows=len(comparable), prediction_flips=sum(row.get("predicted") != second[row["id"]].get("predicted") for row in comparable), initialization_ms=report.get("initialization_ms"), first_inference_ms=report.get("first_inference_ms"), peak_process_rss_bytes=report.get("peak_process_rss_bytes"), failures=[dict(id=row["id"], expected=row["expected"], predicted=row.get("predicted"), error=row.get("error")) for row in first if not row.get("correct")])


def self_check():
    rows = [dict(expected=e, predicted=p, elapsed_ms=i+1) for i, (e, p) in enumerate([("question", "question"), ("normal", "normal"), ("normal", "question"), ("question", "normal"), ("question", None)])]
    result = metrics(rows)
    assert [result[k] for k in ["tp", "tn", "fp", "fn", "abstained"]] == [1, 1, 1, 1, 1]
    assert result["question_recall"] == 1/3
    assert result["normal_false_positive_rate"] == .5
    assert result["accuracy"] == .4
    assert metrics([dict(expected="question", error="offline", elapsed_ms=1)])["errors"] == 1
    assert metrics([])["accuracy"] is None


if __name__ == "__main__":
    self_check()
    suite = json.loads((ROOT / "suite.json").read_text())
    assert len(suite["rows"]) == 48 and len({row["id"] for row in suite["rows"]}) == 48
    expected_hash = hashlib.sha256((ROOT / "suite.json").read_bytes()).hexdigest()
    results = {}
    for path in sorted(ROOT.glob("result-*.json")):
        report = json.loads(path.read_text())
        assert report["suite_sha256"] == expected_hash
        if report["status"] == "complete":
            assert len(report["rows"]) == 96
            for round_index in (1, 2):
                assert {row["id"] for row in report["rows"] if row["round"] == round_index} == {row["id"] for row in suite["rows"]}
        results[path.stem] = summarize(report)
    (ROOT / "summary.json").write_text(json.dumps(results, ensure_ascii=False, indent=2) + "\n")
    for key, result in results.items():
        print(key, result["status"], json.dumps(result["overall"]), result.get("error"))
