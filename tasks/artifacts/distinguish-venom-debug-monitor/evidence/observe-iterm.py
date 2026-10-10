import importlib.util
import json
import os
import sys
import iterm2

spec = importlib.util.spec_from_file_location("bridge_source", sys.argv[1])
bridge_source = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bridge_source)
bridge_source.iterm2 = iterm2

async def main(connection):
    app = await iterm2.async_get_app(connection)
    bridge = bridge_source.Bridge(connection, app)
    # Only read iTerm2 variables/prompts and populate this disposable object's memory.
    # Do not start Bridge.run, sockets, background tasks, or alter terminal sessions.
    await bridge.refresh_running_statuses(restore_commands=True)
    windows = await bridge.build_snapshot()
    fd = os.open(sys.argv[2], os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(fd, "w") as output:
        json.dump(windows, output)

iterm2.run_until_complete(main)
