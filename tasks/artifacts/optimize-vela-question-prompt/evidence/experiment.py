"""Vela真实提示词实验：开发、选择、留出验收三阶段隔离。"""
import argparse
import hashlib
import json
import math
from pathlib import Path
import platform
import statistics
import time

ROOT=Path(__file__).resolve().parent
PREVIOUS=ROOT.parents[1]/'explore-open-system-one-models/evidence'


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def check_inputs():
    frozen=json.loads((ROOT/'frozen-inputs.json').read_text())
    if (ROOT/'frozen-round2.json').exists():
        frozen.update(json.loads((ROOT/'frozen-round2.json').read_text()))
    for name,sha in frozen.items():
        assert digest(ROOT/name)==sha, name
    return frozen


def metrics(rows):
    errors=[row for row in rows if 'error' in row]
    valid=[row for row in rows if 'error' not in row]
    tp=sum(row['expected']=='question' and row['predicted']=='question' for row in valid)
    tn=sum(row['expected']=='normal' and row['predicted']=='normal' for row in valid)
    fp=sum(row['expected']=='normal' and row['predicted']=='question' for row in valid)
    fn=sum(row['expected']=='question' and row['predicted']=='normal' for row in valid)
    times=sorted(row['elapsed_ms'] for row in valid)
    return dict(n=len(rows),errors=len(errors),correct=tp+tn,accuracy=(tp+tn)/len(rows),tp=tp,tn=tn,fp=fp,fn=fn,precision=tp/(tp+fp) if tp+fp else None,recall=tp/(tp+fn) if tp+fn else None,p50_ms=statistics.median(times) if times else None,p95_ms=times[math.ceil(.95*len(times))-1] if times else None)


def choose(prompts):
    ranked=[]
    for index,prompt in enumerate(prompts):
        path=ROOT/f"dev-{prompt['id']}.json"
        data=json.loads(path.read_text())
        assert data['status']=='complete' and data['prompt']==prompt
        rows=[r for r in data['rows'] if r['round']==1]
        assert len(rows)==48 and len(data['rows'])==96
        m=metrics(rows)
        assert m['errors']==0
        worst=min(metrics([r for r in rows if r['language']==lang])['accuracy'] for lang in ['zh','en'])
        ranked.append(dict(id=prompt['id'],index=index,metrics=m,worst_language_accuracy=worst,source_sha256=digest(path)))
    ranked.sort(key=lambda r:(-r['metrics']['accuracy'],-r['worst_language_accuracy'],r['index']))
    return ranked


def main():
    parser=argparse.ArgumentParser();parser.add_argument('phase',choices=['dev','dev2','select','holdout']);args=parser.parse_args()
    frozen=check_inputs()
    first_prompts=json.loads((ROOT/'prompts.json').read_text())
    second_prompts=json.loads((ROOT/'prompts-round2.json').read_text()) if (ROOT/'prompts-round2.json').exists() else []
    prompts=first_prompts+second_prompts
    if args.phase=='select':
        target=ROOT/'selection.json';assert not target.exists()
        ranked=choose(prompts)
        selected=next(p for p in prompts if p['id']==ranked[0]['id'])
        target.write_text(json.dumps(dict(selected=selected,ranked=ranked,frozen=frozen,selected_at=time.strftime('%Y-%m-%dT%H:%M:%S%z'),script_sha256=digest(Path(__file__))),ensure_ascii=False,indent=2)+'\n')
        print(json.dumps(ranked,ensure_ascii=False,indent=2));return
    if args.phase in ['dev','dev2']:
        assert not (ROOT/'selection.json').exists(), '选择后禁止追加开发实验'
        prompts=first_prompts if args.phase=='dev' else second_prompts
        samples=json.loads((ROOT/'development.json').read_text())
    else:
        selected=json.loads((ROOT/'selection.json').read_text())
        assert selected['frozen']==frozen
        assert choose(prompts)==selected['ranked'], '开发结果或选择已漂移'
        prompts=[selected['selected']] + [p for p in prompts if p['id']=='baseline' and p['id']!=selected['selected']['id']]
        # 留出内容仅在选择已经持久化后载入。
        samples=json.loads((ROOT/'holdout.json').read_text())
    import torch
    import transformers
    from huggingface_hub import snapshot_download
    from transformers import AutoModel
    torch.set_num_threads(4);torch.manual_seed(0)
    model_spec=json.loads((PREVIOUS/'models.json').read_text())['vela']
    path=snapshot_download(model_spec['repo'],revision=model_spec['revision'],local_files_only=True,allow_patterns=['*.json','*.py','*.safetensors','*.pt','*.model','*.txt','*.jinja','LICENSE*','README.md'],ignore_patterns=['onnx/*','assets/*','figures/*'])
    started=time.perf_counter()
    model=AutoModel.from_pretrained(path,trust_remote_code=True,dtype=torch.float32).to('cpu').eval()
    load_ms=(time.perf_counter()-started)*1000
    for prompt in prompts:
        prefix='holdout' if args.phase=='holdout' else 'dev'
        target=ROOT/f"{prefix}-{prompt['id']}.json";assert not target.exists(),target
        question={k:prompt[k] for k in ['instructions','criteria']};question['type']=prompt['kind']
        if prompt.get('typed_state'):question['over']='answer'
        def predict(text):
            state={'answer':text} if prompt.get('typed_state') else text
            with torch.inference_mode():raw=model.system_one(state,{'reply':question})
            answer=raw['answers']['reply']
            predicted=answer['choice'] if prompt['kind']=='choice' else 'question' if answer['noul']>=.5 else 'normal'
            assert predicted in ['normal','question']
            return predicted,raw
        warm=time.perf_counter();warmup=predict('The changes have been saved.')
        report=dict(schema='itermate-vela-prompt/v1',phase=args.phase,prompt=prompt,model=model_spec,frozen=frozen,script_sha256=digest(Path(__file__)),platform=platform.platform(),torch=torch.__version__,transformers=transformers.__version__,backend='torch-cpu-fp32-4threads',load_ms=load_ms,warmup_ms=(time.perf_counter()-warm)*1000,warmup=warmup,started_at=time.strftime('%Y-%m-%dT%H:%M:%S%z'),status='running',rows=[])
        if args.phase=='holdout':report['selection_sha256']=digest(ROOT/'selection.json')
        def save():target.write_text(json.dumps(report,ensure_ascii=False,indent=2,allow_nan=False)+'\n')
        save()
        for round_index in [1,2]:
            for sample in samples:
                row=dict(sample,round=round_index);start=time.perf_counter()
                try:
                    predicted,raw=predict(sample['text'])
                    row.update(predicted=predicted,raw=raw,correct=predicted==sample['expected'])
                except Exception as error:row['error']=type(error).__name__+': '+str(error)
                row['elapsed_ms']=(time.perf_counter()-start)*1000
                report['rows'].append(row)
            save()
        report['status']='complete';report['finished_at']=time.strftime('%Y-%m-%dT%H:%M:%S%z');save()
        print(args.phase,prompt['id'],json.dumps(metrics([r for r in report['rows'] if r['round']==1])),flush=True)


if __name__=='__main__':main()
