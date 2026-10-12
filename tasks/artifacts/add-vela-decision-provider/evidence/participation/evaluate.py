"""隔离进程加载真实缓存模型，使用产品当前QUESTION_QUESTIONS，不调用现有服务。"""
import argparse
import hashlib
import importlib.metadata
import importlib.util
import json
from pathlib import Path
import platform
import time

ROOT=Path(__file__).resolve().parent
PROJECT=ROOT.parents[4]


def main():
    parser=argparse.ArgumentParser();parser.add_argument('provider',choices=['laya','vela']);args=parser.parse_args()
    spec=importlib.util.spec_from_file_location('helper',PROJECT/'integrations/laya/iTermate-laya.py')
    helper=importlib.util.module_from_spec(spec);spec.loader.exec_module(helper)
    suite=json.loads((ROOT/'suite.json').read_text());frozen=json.loads((ROOT/'frozen.json').read_text())
    assert hashlib.sha256((ROOT/'suite.json').read_bytes()).hexdigest()==frozen['suite_sha256']
    assert hashlib.sha256((PROJECT/'integrations/laya/iTermate-laya.py').read_bytes()).hexdigest()==frozen['helper_sha256']
    assert suite['questions']==helper.QUESTION_QUESTIONS
    model_id=helper.MODEL_ID if args.provider=='laya' else helper.VELA_ID
    revision=helper.MODEL_REVISION if args.provider=='laya' else helper.VELA_REVISION
    path=Path.home()/'.cache/huggingface/hub'/('models--'+model_id.replace('/','--'))/'snapshots'/revision
    target=ROOT/f'result-{args.provider}.json';assert not target.exists()
    report=dict(provider=args.provider,model=model_id,revision=revision,frozen=frozen,script_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),platform=platform.platform(),status='loading',rows=[],versions={},started_at=time.strftime('%Y-%m-%dT%H:%M:%S%z'))
    for package in ['laya-mlx','mlx','torch','transformers']:
        try:report['versions'][package]=importlib.metadata.version(package)
        except importlib.metadata.PackageNotFoundError:pass
    def save():target.write_text(json.dumps(report,ensure_ascii=False,indent=2,allow_nan=False)+'\n')
    save()
    try:
        start=time.perf_counter()
        if args.provider=='vela':
            agent=helper.VelaAgent(str(path));report['backend']='torch-cpu-fp32-4threads'
        else:
            import laya_mlx
            agent=laya_mlx.load(str(path),dtype='float16',device='gpu');report['backend']='mlx-gpu-fp16'
        report['load_ms']=(time.perf_counter()-start)*1000
        agent.predict('The work is complete.',helper.QUESTION_QUESTIONS)
        report['status']='running'
        for round_index in [1,2]:
            for sample in suite['rows']:
                row=dict(sample,round=round_index);start=time.perf_counter()
                try:
                    state,questions=helper.validate_payload({'state':sample['text'],'questions':helper.QUESTION_QUESTIONS},args.provider)
                    raw=agent.predict(state,questions)
                    answer=raw['answers']['question'];assert answer['type']=='choice'
                    predicted=answer['choice'];assert predicted in ['normal','question']
                    row.update(raw=raw,predicted=predicted,correct=predicted==sample['expected'])
                except Exception as error:row['error']=type(error).__name__+': '+str(error)
                row['elapsed_ms']=(time.perf_counter()-start)*1000
                report['rows'].append(row)
            save()
        report['status']='complete'
    except Exception as error:
        report['status']='blocked';report['error']=type(error).__name__+': '+str(error)
    finally:
        report['finished_at']=time.strftime('%Y-%m-%dT%H:%M:%S%z');save()
    print(args.provider,report['status'],len(report['rows']),report.get('error'),flush=True)


if __name__=='__main__':main()
