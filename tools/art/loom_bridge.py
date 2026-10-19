"""Keeps one PixelLoomMCP.exe (stdio MCP) alive and exposes it on 127.0.0.1:8765.

POST /call {"name": tool, "arguments": {...}} -> the tool result JSON.
POST /list {} -> tools/list.
Run in the background; loomlib.py calls it.
"""
import json
import subprocess
import sys
import threading
from http.server import BaseHTTPRequestHandler, HTTPServer

EXE = sys.argv[1]
proc = subprocess.Popen([EXE, '--mcp'], stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                        stderr=open(sys.argv[2], 'ab'), bufsize=0)
lock = threading.Lock()
next_id = [0]


def rpc(method, params=None, notify=False):
    with lock:
        msg = {'jsonrpc': '2.0', 'method': method}
        if params is not None:
            msg['params'] = params
        if not notify:
            next_id[0] += 1
            msg['id'] = next_id[0]
        proc.stdin.write((json.dumps(msg, ensure_ascii=False) + '\n').encode('utf-8'))
        proc.stdin.flush()
        if notify:
            return None
        while True:
            line = proc.stdout.readline()
            if not line:
                raise RuntimeError('MCP server closed')
            data = json.loads(line)
            if data.get('id') == msg['id']:
                return data


print(json.dumps(rpc('initialize', {'protocolVersion': '2025-06-18', 'capabilities': {},
                                    'clientInfo': {'name': 'claude-code-bridge', 'version': '1'}}))[:400], flush=True)
rpc('notifications/initialized', notify=True)


class Handler(BaseHTTPRequestHandler):
    def do_POST(self):
        body = json.loads(self.rfile.read(int(self.headers['Content-Length'])) or b'{}')
        try:
            if self.path == '/list':
                out = rpc('tools/list', {})
            else:
                out = rpc('tools/call', body)
        except Exception as e:  # report to the caller
            out = {'bridge_error': repr(e)}
        payload = json.dumps(out, ensure_ascii=False).encode('utf-8')
        self.send_response(200)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Length', str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)

    def log_message(self, *args):
        pass


HTTPServer(('127.0.0.1', 8765), Handler).serve_forever()
