"""Tests of agent-context.py: a request counted once with its final usage, a
malformed line and an entry without a request id skipped, and the row it prints.

Run: python3 .claude/scripts/test-agent-context.py
"""
import io
import json
import os
import runpy
import tempfile
import unittest
from contextlib import redirect_stdout

SCRIPT = os.environ.get("AGENT_CONTEXT", os.path.join(os.path.dirname(os.path.abspath(__file__)), "agent-context.py"))


def entry(request, usage):
    return json.dumps({"requestId": request, "message": {"usage": usage}})


class AgentContextTest(unittest.TestCase):
    """agent-context.py against a transcript of two requests, one repeated, and two lines it must skip."""

    def setUp(self):
        self.mod = runpy.run_path(SCRIPT)
        fd, self.path = tempfile.mkstemp(suffix=".jsonl")
        with os.fdopen(fd, "w") as f:
            f.write(entry("r1", {"input_tokens": 1, "cache_creation_input_tokens": 10, "cache_read_input_tokens": 0, "output_tokens": 2}) + "\n")
            f.write(entry("r1", {"input_tokens": 1, "cache_creation_input_tokens": 10, "cache_read_input_tokens": 0, "output_tokens": 5}) + "\n")
            f.write("{not json\n")
            f.write(json.dumps({"message": {"usage": {"input_tokens": 999}}}) + "\n")
            f.write(entry("r2", {"input_tokens": 3, "cache_creation_input_tokens": 20, "cache_read_input_tokens": 11, "output_tokens": 7}) + "\n")

    def tearDown(self):
        os.unlink(self.path)

    def test_a_request_counts_once_with_its_final_usage(self):
        rows = self.mod["usage_rows"](self.path)
        self.assertEqual([r["output_tokens"] for r in rows], [5, 7])

    def test_the_row_reports_the_last_requests_context_and_the_totals(self):
        out = io.StringIO()
        with redirect_stdout(out):
            self.mod["main"]([self.path])
        row = out.getvalue().splitlines()[2]
        self.assertEqual(row, f"| {os.path.basename(self.path)} | 2 | 34 | 4 | 30 | 11 | 12 |")


if __name__ == "__main__":
    unittest.main()
