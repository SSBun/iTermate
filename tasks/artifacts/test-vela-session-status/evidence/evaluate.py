"""用真实 Vela 和产品 Handler、Bridge 方法做隔离状态判定回归；不启动服务。"""
import asyncio
import hashlib
import importlib.util
import io
import json
from email.message import Message
from pathlib import Path
from types import SimpleNamespace
import threading
import time
import ast

ROOT = Path(__file__).resolve().parent
PROJECT = ROOT.parents[3]
helper_path = PROJECT / 'integrations/laya/iTermate-laya.py'
bridge_path = PROJECT / 'iTermateBridge/iTermateBridge.py'
spec = importlib.util.spec_from_file_location('helper', helper_path)
helper = importlib.util.module_from_spec(spec)
spec.loader.exec_module(helper)
# 仅提取实际 Bridge 方法，避免导入时连接真实终端。
tree = ast.parse(bridge_path.read_text())
cls = next(n for n in tree.body if isinstance(n, ast.ClassDef) and n.name == 'Bridge')
method = next(n for n in cls.body if isinstance(n, ast.AsyncFunctionDef) and n.name == 'update_model_observation')
import os
ns = dict(asyncio=asyncio, os=os, time=time, SUPPORT_DIRECTORY='/unused')
exec(compile(ast.Module(body=[method], type_ignores=[]), str(bridge_path), 'exec'), ns)

pairs = {
 'running': [
 ('正在编译，已完成 42%，请稍候。', 'Compiling, 42% complete. Please wait.'),
 ('正在检查依赖，不需要你操作。', 'Checking dependencies; no action is needed from you.'),
 ('下载中：128 MB / 650 MB，速度 20 MB/s。', 'Downloading: 128 MB / 650 MB at 20 MB/s.'),
 ('测试仍在运行，已执行 12/80 项。', 'Tests are still running: 12 of 80 executed.'),
 ('正在重建索引，剩余 230 个文件。', 'Rebuilding the index, 230 files remaining.'),
 ('正在部署，请勿关闭终端。', 'Deployment in progress. Do not close the terminal.')],
 'awaitingInput': [
 ('请确认范围。', 'Please confirm the scope.'),
 ('确认后我再继续。', 'I will continue after your confirmation.'),
 ('请选择方案 A 或 B。', 'Please choose option A or B.'),
 ('是否允许我重启服务？', 'May I restart the service?'),
 ('请提供项目路径，然后我再继续。', 'Please provide the project path so I can continue.'),
 ('覆盖现有文件？[y/N]', 'Overwrite the existing file? [y/N]')],
 'idle': [
 ('任务完成，所有文件已保存，无需进一步操作。', 'Task complete. All files saved. No further action required.'),
 ('构建成功，进程已退出，退出码 0。', 'Build succeeded. Process exited with code 0.'),
 ('测试全部通过，检查结束。', 'All tests passed. Verification is complete.'),
 ('报告已导出，本次任务结束。', 'Report exported. This task is finished.'),
 ('你之前已经确认，我已完成提交。', 'You already confirmed earlier, and I have completed the commit.'),
 ('文档中的示例是“请确认范围”。文档更新已完成。', 'The documentation example says “Please confirm the scope.” Documentation update is complete.')],
 'unknown': [
 ('项目路径：/tmp/example', 'Project path: /tmp/example'),
 ('版本 2.0.1', 'Version 2.0.1'),
 ('日志片段：2026-01-01', 'Log excerpt: 2026-01-01'),
 ('函数名称：parse_config', 'Function name: parse_config'),
 ('文档示例：“是否继续？”', 'Documentation example: “Continue?”'),
 ('```python\nprint("Working...")\n```', '```python\nprint("Working...")\n```')]
}
rows = [dict(id=f'{label}-{i}-{lang}', expected=label, text=text, language=lang)
        for label, examples in pairs.items() for i, pair in enumerate(examples)
        for lang, text in zip(['zh', 'en'], pair)]
suite = dict(questions=helper.SESSION_QUESTIONS, rows=rows,
             limitations='作者合成的48条均衡回归样本，不是盲标生产数据；两轮不算独立样本。')
assert not (ROOT / 'result.json').exists()
(ROOT / 'suite.json').write_text(json.dumps(suite, ensure_ascii=False, indent=2))
frozen = {str(p.relative_to(PROJECT)): hashlib.sha256(p.read_bytes()).hexdigest()
          for p in [helper_path, bridge_path, Path(__file__), ROOT / 'suite.json']}
(ROOT / 'frozen.json').write_text(json.dumps(frozen, indent=2))
path = Path.home() / '.cache/huggingface/hub' / ('models--' + helper.VELA_ID.replace('/', '--')) / 'snapshots' / helper.VELA_REVISION
agent = helper.VelaAgent(str(path))
agent.predict('Work complete.', helper.SESSION_QUESTIONS)

async def apply_bridge(answers, text):
    screen = SimpleNamespace(number_of_lines=1, line=lambda i: SimpleNamespace(string=text))
    async def get_screen(): return screen
    session = SimpleNamespace(session_id='synthetic', async_get_screen_contents=get_screen)
    bridge = SimpleNamespace(
        app=SimpleNamespace(windows=[SimpleNamespace(tabs=[SimpleNamespace(all_sessions=[session])])]),
        session_statuses={}, model_observations={}, model_cursor=0,
        model_identity=lambda directory: ('frozen',),
        request_model_observation=lambda directory, text, identity: answers)
    await ns['update_model_observation'](bridge)
    return bridge.model_observations.get('synthetic', (None,))[0]

results = []
for repeat in [1, 2]:
    for sample in rows:
        # 实际 HTTP Handler，但使用内存输入输出，不监听端口。
        h = helper.Handler.__new__(helper.Handler)
        h.path = '/v1/session'
        body = json.dumps({'state': sample['text'][-1500:]}).encode()
        h.headers = Message(); h.headers['Content-Length'] = str(len(body)); h.headers['Content-Type'] = 'application/json'
        h.rfile = io.BytesIO(body)
        h.authorized = lambda: True
        h.server = SimpleNamespace(agent=agent, provider='vela', instance='isolated-evaluation', model_id=helper.VELA_ID, inference=threading.Lock())
        captured = []
        h.reply = lambda status, payload: captured.append((status, payload))
        start = time.perf_counter()
        h.do_POST()
        elapsed = (time.perf_counter() - start) * 1000
        status, raw = captured[0]
        if status != 200: raise RuntimeError((status, raw))
        choice = raw['answers']['state']['choice']
        effective = asyncio.run(apply_bridge(raw['answers'], sample['text']))
        results.append(dict(sample, round=repeat, raw=raw, predicted=choice,
                            effective=effective, elapsed_ms=elapsed))
    (ROOT / 'result.json').write_text(json.dumps(dict(model=helper.VELA_ID, revision=helper.VELA_REVISION,
        frozen=frozen, rows=results), ensure_ascii=False, indent=2))
print('完成', len(results), '次推理', flush=True)
