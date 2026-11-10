#!/usr/bin/env python3
"""Minimal stand-in for the YouTrack article API - enough for yt-sync.sh.
State lives in memory for the life of the server, so successive sync runs
see what the previous run created."""
import json, re, sys
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.parse import urlparse, parse_qs

PROJECT = 'PROJ'
ARTS = {}      # id -> article dict
SEQ = [0]

def new_id():
    SEQ[0] += 1
    return f'1-{SEQ[0]}', f'{PROJECT}-A-{SEQ[0]}'

class H(BaseHTTPRequestHandler):
    def log_message(self, *a): pass

    def _send(self, obj, code=200):
        body = json.dumps(obj).encode() if obj is not None else b''
        self.send_response(code)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Length', str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _read(self):
        n = int(self.headers.get('Content-Length') or 0)
        return json.loads(self.rfile.read(n) or b'{}')

    def do_GET(self):
        u = urlparse(self.path); q = parse_qs(u.query)
        if u.path == '/api/admin/projects':
            return self._send([{'id': '0-0', 'shortName': PROJECT}])
        if u.path == '/api/articles':
            skip = int(q.get('$skip', ['0'])[0]); top = int(q.get('$top', ['100'])[0])
            rows = sorted(ARTS.values(), key=lambda a: a['id'])[skip:skip + top]
            return self._send(rows)
        m = re.fullmatch(r'/api/articles/([^/]+)/attachments', u.path)
        if m:
            return self._send([])
        return self._send([], 404)

    def do_POST(self):
        u = urlparse(self.path)
        if u.path == '/_reset':          # test-only: start the next case clean
            ARTS.clear(); SEQ[0] = 0
            return self._send({'ok': True})
        if u.path == '/api/articles':
            p = self._read()
            aid, idr = new_id()
            ARTS[aid] = {'id': aid, 'idReadable': idr,
                         'summary': p.get('summary'), 'content': p.get('content') or '',
                         'parentArticle': p.get('parentArticle'),
                         'project': {'shortName': PROJECT}}
            return self._send({'id': aid, 'idReadable': idr})
        m = re.fullmatch(r'/api/articles/([^/]+)', u.path)
        if m and m.group(1) in ARTS:
            p = self._read()
            ARTS[m.group(1)].update({k: v for k, v in p.items() if k in ('content', 'summary')})
            return self._send({'id': m.group(1)})
        return self._send({}, 404)

    def do_DELETE(self):
        m = re.fullmatch(r'/api/articles/([^/]+)', urlparse(self.path).path)
        if m: ARTS.pop(m.group(1), None)
        return self._send(None)

if __name__ == '__main__':
    port = int(sys.argv[1])
    HTTPServer(('127.0.0.1', port), H).serve_forever()
