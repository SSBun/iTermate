"""回复二分类与显式已读回归；只运行提取的产品方法，不连接终端。"""
import ast
import asyncio
import os
from pathlib import Path
import time
from types import SimpleNamespace
import unittest

TREE = ast.parse(Path(__file__).with_name('iTermateBridge.py').read_text())
CLASS = next(node for node in TREE.body if isinstance(node, ast.ClassDef) and node.name == 'Bridge')
NAMESPACE = dict(asyncio=asyncio, os=os, time=time, SUPPORT_DIRECTORY='/unused')
for name in ['update_model_observation', 'clear_finished_status']:
    method = next(node for node in CLASS.body if getattr(node, 'name', None) == name)
    exec(compile(ast.Module(body=[method], type_ignores=[]), '<product-method>', 'exec'), NAMESPACE)


class ResponseStatusTests(unittest.IsolatedAsyncioTestCase):
    def make_bridge(self, choice='awaitingInput'):
        screen = SimpleNamespace(number_of_lines=1, line=lambda index: SimpleNamespace(string='请确认范围。'))
        async def contents(): return screen
        session = SimpleNamespace(session_id='one', async_get_screen_contents=contents)
        bridge = SimpleNamespace(
            app=SimpleNamespace(windows=[SimpleNamespace(tabs=[SimpleNamespace(all_sessions=[session])])]),
            session_statuses={}, model_observations={}, model_response_texts={}, model_read_responses={},
            model_cursor=0, agent_managed_session_ids={'one'},
            model_identity=lambda directory: ('stable',),
            request_model_observation=lambda *args: {'state': {'choice': choice, 'probabilities': {choice: 0.7}}})
        bridge.set_session_status = lambda key, status, **kwargs: bridge.session_statuses.update({key: {'status': status, 'activityKind': 'agent'}})
        return bridge

    async def test_binary_waiting_does_not_require_second_probability(self):
        bridge = self.make_bridge()
        await NAMESPACE['update_model_observation'](bridge)
        self.assertEqual(bridge.model_observations['one'][0], 'awaitingInput')
        NAMESPACE['clear_finished_status'](bridge, 'one')
        self.assertEqual(bridge.model_observations['one'][0], 'awaitingInput')

    async def test_model_idle_read_identity_survives_refresh(self):
        bridge = self.make_bridge('idle')
        await NAMESPACE['update_model_observation'](bridge)
        NAMESPACE['clear_finished_status'](bridge, 'one')
        await NAMESPACE['update_model_observation'](bridge)
        self.assertEqual(bridge.model_read_responses['one'], bridge.model_response_texts['one'])

    async def test_only_explicit_activation_acknowledges_native_completion(self):
        bridge = self.make_bridge()
        bridge.session_statuses['one'] = {'status': 'finished', 'activityKind': 'agent'}
        NAMESPACE['clear_finished_status'](bridge, 'one', acknowledge_agent=False)
        self.assertEqual(bridge.session_statuses['one']['status'], 'finished')
        NAMESPACE['clear_finished_status'](bridge, 'one')
        self.assertEqual(bridge.session_statuses['one']['status'], 'idle')
        bridge.session_statuses['one']['status'] = 'awaitingInput'
        NAMESPACE['clear_finished_status'](bridge, 'one')
        self.assertEqual(bridge.session_statuses['one']['status'], 'awaitingInput')
