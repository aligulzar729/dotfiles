#!/usr/bin/env python3
import json
import sys
from datetime import datetime, timezone

from transcript import entries, is_real_prompt

MAX_CONTEXT = 400_000
MAX_PROMPTS = 40
MAX_IDLE_SECONDS = 3600


def parse_time(value):
    return datetime.fromisoformat(value.replace("Z", "+00:00"))


def main():
    event = json.load(sys.stdin)
    prompts, context, first, last = 0, 0, None, None
    for entry in entries(event.get("transcript_path")):
        stamp = entry.get("timestamp")
        if stamp and not entry.get("isSidechain"):
            first = first or stamp
            last = stamp
        if is_real_prompt(entry):
            prompts += 1
        usage = (entry.get("message") or {}).get("usage") if entry.get("type") == "assistant" else None
        if usage and not entry.get("isSidechain"):
            context = usage.get("input_tokens", 0) + usage.get("cache_read_input_tokens", 0) + usage.get("cache_creation_input_tokens", 0)

    now = datetime.now(timezone.utc)
    reasons = []
    if context > MAX_CONTEXT:
        reasons.append(f"context is {context // 1000}k tokens (limit {MAX_CONTEXT // 1000}k)")
    if prompts >= MAX_PROMPTS:
        reasons.append(f"{prompts} user prompts (limit {MAX_PROMPTS})")
    if last and (now - parse_time(last)).total_seconds() > MAX_IDLE_SECONDS:
        reasons.append("the user was idle for more than 1 hour")
    if first and parse_time(first).astimezone().date() != now.astimezone().date():
        reasons.append("the session started on an earlier day")
    if not reasons:
        return

    message = (
        "SESSION LIMIT PASSED: " + "; ".join(reasons) + ". "
        "Answer the current prompt only if it is a small follow-up. Otherwise, write a handoff "
        "with the `handoff` skill and tell the user to start a new session."
    )
    print(json.dumps({"hookSpecificOutput": {"hookEventName": "UserPromptSubmit", "additionalContext": message}}))


try:
    main()
except Exception:
    sys.exit(0)
