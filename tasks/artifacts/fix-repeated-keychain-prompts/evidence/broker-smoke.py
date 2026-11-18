import json
import os
from pathlib import Path
import subprocess
import tempfile
import time

root = Path(__file__).resolve().parents[4]
evidence = Path(__file__).parent
swift_source = (root / 'iTermate/AIModelService.swift').read_text()
broker = swift_source.split('@MainActor\nprivate final class AIRequestBroker {', 1)[1].split('\nprivate final class AIRedirectPolicy', 1)[0]
ts_source = (root / 'integrations/pi/iTermate-integration.ts').read_text()
client = ts_source.split('async function remoteAIRequest(', 1)[1].split('\nasync function completeRemoteLLM', 1)[0]

with tempfile.TemporaryDirectory(prefix='itermate-ai-') as temporary:
    temporary = Path(temporary)
    support = temporary / 'support'
    swift = temporary / 'smoke.swift'
    swift.write_text('''import Foundation
import Network
import Darwin
struct AIModelError: Error { init(_ message: String) {} }
enum AIConfigurationStore {
    static let directory = URL(fileURLWithPath: ''' + json.dumps(str(support / 'AI')) + ''')
}
@MainActor
private final class AIRequestBroker {''' + broker + '''
@main struct Smoke {
    @MainActor static func main() async throws {
        let broker = try AIRequestBroker(onFailure: { fatalError("Broker failed") }) { account, body in
            if body["input"] as? String == "wait" {
                do { try await Task.sleep(nanoseconds: 60_000_000_000) }
                catch {
                    try Data("cancelled".utf8).write(to: AIConfigurationStore.directory.appendingPathComponent("cancelled"))
                    throw error
                }
            }
            return ["account": account, "model": body["model"] ?? "", "synthetic": true]
        }
        try await Task.sleep(nanoseconds: 60_000_000_000)
        withExtendedLifetime(broker) {}
    }
}
''')
    executable = temporary / 'broker'
    subprocess.run(['swiftc', '-parse-as-library', str(swift), '-o', str(executable)], check=True)
    server = subprocess.Popen([str(executable)], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    try:
        socket_path = support / 'AI/requests.sock'
        for _ in range(100):
            if socket_path.exists() and socket_path.stat().st_mode & 0o777 == 0o600:
                break
            if server.poll() is not None:
                raise RuntimeError('Broker exited: ' + server.stderr.read().decode())
            time.sleep(0.03)
        else:
            raise RuntimeError('Broker did not create its socket')
        node = temporary / 'client.ts'
        node.write_text('''import { lstatSync, chmodSync } from "node:fs";
import { join } from "node:path";
import { connect, type Socket } from "node:net";
const supportDirectory = ''' + json.dumps(str(support)) + ''';
class SummaryGenerationError extends Error { constructor(reason: string) { super(reason); } }
async function remoteAIRequest(''' + client + '''
const value = await remoteAIRequest("decision", {model: "gpt-6-luna", input: "synthetic"}, new AbortController().signal);
if (value.synthetic !== true || value.model !== "gpt-6-luna" || value.account !== "decision") throw Error("Unexpected broker response");
console.log("Synthetic request: passed");
const controller = new AbortController();
const pending = remoteAIRequest("decision", {input: "wait"}, controller.signal);
setTimeout(() => controller.abort(), 50);
try { await pending; throw Error("Cancellation was ignored"); }
catch (error) { if (error.message !== "timeout") throw error; }
console.log("Client cancellation: passed");
chmodSync(join(supportDirectory, "AI/requests.sock"), 0o666);
try { await remoteAIRequest("decision", {}, new AbortController().signal); throw Error("Unsafe socket accepted"); }
catch (error) { if (error.message !== "provider") throw error; }
chmodSync(join(supportDirectory, "AI/requests.sock"), 0o600);
console.log("Unsafe socket permissions: rejected");
''')
        result = subprocess.run(['node', '--experimental-strip-types', str(node)], capture_output=True, text=True, timeout=10)
        print(result.stdout, end='')
        if result.returncode:
            raise RuntimeError(result.stderr)
        for _ in range(100):
            if (socket_path.parent / 'cancelled').exists():
                break
            time.sleep(0.01)
        else:
            raise RuntimeError('Provider task was not cancelled after client disconnect')
        print('Provider task cancellation: passed')
        print('Socket permissions:', oct(socket_path.stat().st_mode & 0o777))
        print('Directory permissions:', oct(socket_path.parent.stat().st_mode & 0o777))
    finally:
        server.terminate()
        server.communicate(timeout=5)
    node.write_text(node.read_text().split('const value = await remoteAIRequest(', 1)[0] + '''
try { await remoteAIRequest("decision", {}, new AbortController().signal); throw Error("Missing App was accepted"); }
catch (error) { if (error.message !== "provider") throw error; }
console.log("App unavailable: failed without credential fallback");
''')
    result = subprocess.run(['node', '--experimental-strip-types', str(node)], capture_output=True, text=True, timeout=10)
    print(result.stdout, end='')
    if result.returncode:
        raise RuntimeError(result.stderr)
print('No Keychain read or provider request was made.')
