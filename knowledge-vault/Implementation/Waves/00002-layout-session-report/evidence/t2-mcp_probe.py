#!/usr/bin/env python3
"""Throwaway stdio MCP server for the T2 measurement: one tool, `ping`, whose
every call is appended to the log file named by T2_MCP_LOG. JSON-RPC 2.0, one
message per line, as the MCP stdio transport specifies."""
import json
import os
import sys

LOG = os.environ.get("T2_MCP_LOG", "/dev/null")


def log(entry):
    with open(LOG, "a") as f:
        f.write(json.dumps(entry) + "\n")


def reply(msg_id, result):
    sys.stdout.write(json.dumps({"jsonrpc": "2.0", "id": msg_id, "result": result}) + "\n")
    sys.stdout.flush()


for line in sys.stdin:
    line = line.strip()
    if not line:
        continue
    msg = json.loads(line)
    method, msg_id = msg.get("method"), msg.get("id")
    log({"method": method})
    if method == "initialize":
        reply(msg_id, {
            "protocolVersion": msg["params"].get("protocolVersion", "2025-06-18"),
            "capabilities": {"tools": {}},
            "serverInfo": {"name": "probe", "version": "0"},
        })
    elif method == "tools/list":
        reply(msg_id, {"tools": [{
            "name": "ping",
            "description": "Records a note for the aineo T2 measurement.",
            "inputSchema": {"type": "object", "properties": {"note": {"type": "string"}}, "required": ["note"]},
        }]})
    elif method == "tools/call":
        log({"call": msg["params"]})
        reply(msg_id, {"content": [{"type": "text", "text": "pong"}]})
    elif msg_id is not None:
        reply(msg_id, {})
