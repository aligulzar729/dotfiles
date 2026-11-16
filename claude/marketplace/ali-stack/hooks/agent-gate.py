#!/usr/bin/env python3
import json
import re
import sys

from transcript import entries, is_real_prompt

MAX_AGENTS_PER_REQUEST = 3
OPUS_WORK = re.compile(r"review|plan|judge|debug|design|architect|critique|council|audit", re.I)
OPUS_TYPES = {"Plan"}


def deny(reason):
    print(json.dumps({"hookSpecificOutput": {
        "hookEventName": "PreToolUse",
        "permissionDecision": "deny",
        "permissionDecisionReason": reason,
    }}))
    sys.exit(0)


def launches_before(path, current_id):
    """Agent launches since the last real prompt, before the current one, not counting failed launches."""
    failed = {
        part.get("tool_use_id")
        for entry in entries(path)
        for part in ((entry.get("message") or {}).get("content") or [])
        if isinstance(part, dict) and part.get("type") == "tool_result" and part.get("is_error")
    }
    launched = []
    for entry in entries(path):
        if is_real_prompt(entry):
            launched = []
        elif entry.get("isSidechain"):
            continue
        for part in (entry.get("message") or {}).get("content") or []:
            if not isinstance(part, dict):
                continue
            if entry.get("type") == "assistant" and part.get("type") == "tool_use" and part.get("name") in ("Agent", "Task"):
                if part.get("id") == current_id:
                    return len([i for i in launched if i not in failed])
                launched.append(part.get("id"))
    return len([i for i in launched if i not in failed])


def main():
    event = json.load(sys.stdin)
    tool = event.get("tool_input") or {}
    kind = tool.get("subagent_type") or "general-purpose"
    model = tool.get("model")
    description = tool.get("description") or ""
    user_asked = "(user asked)" in description

    if kind == "fork":
        return
    if not model:
        deny("Set `model` on every Agent call: haiku to find files, run tests or read logs; sonnet to read code or make scoped edits (use the worker agent); opus only for planning, debugging, review or design judgement.")
    if model == "opus" and kind not in OPUS_TYPES and not OPUS_WORK.search(description) and not user_asked:
        deny("Opus subagents are for planning, debugging an unknown cause, review or design judgement. Use sonnet (worker) or haiku (Explore) for this task, or name the opus-level work in the description.")
    if not user_asked and launches_before(event.get("transcript_path"), event.get("tool_use_id")) >= MAX_AGENTS_PER_REQUEST:
        deny(f"Maximum {MAX_AGENTS_PER_REQUEST} subagents for one request. Do the rest yourself, or, only if the user asked for more agents, add `(user asked)` to the description.")


try:
    main()
except Exception:
    sys.exit(0)
