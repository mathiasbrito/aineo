#!/usr/bin/env python3
"""Throwaway stdio MCP server that records every raw line Claude Code sends and
every reply it writes, to the file named by T2_MCP_LOG. One tool, `report`,
with the C6 input schema; never called in this recording."""
import json
import os
import sys

LOG = os.environ.get("T2_MCP_LOG", "/dev/null")


def log(direction, line):
    with open(LOG, "a") as f:
        f.write(direction + " " + line.rstrip("\n") + "\n")


def reply(msg_id, result):
    line = json.dumps({"jsonrpc": "2.0", "id": msg_id, "result": result})
    log("S->C", line)
    sys.stdout.write(line + "\n")
    sys.stdout.flush()


log("ENV", json.dumps({k: v for k, v in os.environ.items() if k.startswith("AINEO") or k in ("NVIM", "PATH_PROBE")}))
for line in sys.stdin:
    if not line.strip():
        continue
    log("C->S", line)
    msg = json.loads(line)
    method, msg_id = msg.get("method"), msg.get("id")
    if method == "initialize":
        reply(msg_id, {
            "protocolVersion": msg["params"].get("protocolVersion"),
            "capabilities": {"tools": {}},
            "serverInfo": {"name": "aineo-probe", "version": "0"},
        })
    elif method == "tools/list":
        reply(msg_id, {"tools": [{
            "name": "report",
            "description": "Probe.",
            "inputSchema": {"type": "object", "properties": {"task": {"type": "string"}}, "required": ["task"]},
        }]})
    elif msg_id is not None:
        reply(msg_id, {})
log("EOF", "stdin closed")
