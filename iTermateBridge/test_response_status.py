"""只保留生命周期回复状态，不连接终端或调用模型。"""
import ast
from pathlib import Path
from types import SimpleNamespace
import unittest

SOURCE = Path(__file__).with_name('iTermateBridge.py').read_text()
TREE = ast.parse(SOURCE)
CLASS = next(node for node in TREE.body if isinstance(node, ast.ClassDef) and node.name == 'Bridge')
NAMESPACE = {}
METHOD = next(node for node in CLASS.body if getattr(node, 'name', None) == 'clear_finished_status')
exec(compile(ast.Module(body=[METHOD], type_ignores=[]), '<product-method>', 'exec'), NAMESPACE)


class ResponseStatusTests(unittest.TestCase):
    def test_bridge_has_no_screen_classifier_or_model_snapshot(self):
        methods = {getattr(node, 'name', None) for node in CLASS.body}
        self.assertFalse(methods & {'update_model_observation', 'model_state', 'request_model_observation'})
        self.assertNotIn('async_get_screen_contents', SOURCE)
        self.assertNotIn('modelState', SOURCE)
        self.assertNotIn('modelResponseUnread', SOURCE)

    def test_only_explicit_activation_acknowledges_native_completion(self):
        bridge = SimpleNamespace(session_statuses={}, agent_managed_session_ids={'one'})
        bridge.set_session_status = lambda key, status, **kwargs: bridge.session_statuses.update({key: {'status': status, 'activityKind': 'agent'}})
        bridge.session_statuses['one'] = {'status': 'finished', 'activityKind': 'agent'}
        NAMESPACE['clear_finished_status'](bridge, 'one', acknowledge_agent=False)
        self.assertEqual(bridge.session_statuses['one']['status'], 'finished')
        NAMESPACE['clear_finished_status'](bridge, 'one')
        self.assertEqual(bridge.session_statuses['one']['status'], 'idle')
        bridge.session_statuses['one']['status'] = 'awaitingInput'
        NAMESPACE['clear_finished_status'](bridge, 'one')
        self.assertEqual(bridge.session_statuses['one']['status'], 'awaitingInput')
