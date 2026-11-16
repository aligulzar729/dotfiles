#!/usr/bin/env python3
"""Usage stats from Claude Code session logs: python3 scan.py [days]."""
import json
import re
import sys
from collections import Counter
from datetime import datetime, timedelta, timezone
from pathlib import Path

DAYS = int(sys.argv[1]) if len(sys.argv) > 1 else 7
SINCE = datetime.now(timezone.utc) - timedelta(days=DAYS)
CORRECTION = re.compile(r"^(no\b|wrong|still\b|revert|again\b|i said|that's not|not what)", re.I)


def real_prompt(entry):
    if entry.get("type") != "user" or entry.get("isMeta") or entry.get("isSidechain") or entry.get("isCompactSummary"):
        return None
    content = (entry.get("message") or {}).get("content")
    if isinstance(content, list):
        if any(isinstance(p, dict) and p.get("type") == "tool_result" for p in content):
            return None
        content = " ".join(p.get("text", "") for p in content if isinstance(p, dict))
    if not isinstance(content, str) or not content.strip() or content.startswith("<"):
        return None
    return content


sessions = []
models, agent_types, bash_heads = Counter(), Counter(), Counter()
prompts = corrections = 0

for path in Path.home().glob(".claude/projects/*/*.jsonl"):
    if datetime.fromtimestamp(path.stat().st_mtime, timezone.utc) < SINCE:
        continue
    peak, days, count = 0, set(), 0
    for line in path.open(errors="ignore"):
        try:
            entry = json.loads(line)
        except ValueError:
            continue
        stamp = entry.get("timestamp")
        if stamp and not entry.get("isSidechain"):
            days.add(datetime.fromisoformat(stamp.replace("Z", "+00:00")).astimezone().date())
        text = real_prompt(entry)
        if text is not None:
            count += 1
            corrections += bool(CORRECTION.search(text.strip()))
        if entry.get("type") != "assistant" or entry.get("isSidechain"):
            continue
        message = entry.get("message") or {}
        usage = message.get("usage") or {}
        peak = max(peak, sum(usage.get(k, 0) for k in ("input_tokens", "cache_read_input_tokens", "cache_creation_input_tokens")))
        for part in message.get("content") or []:
            if not isinstance(part, dict) or part.get("type") != "tool_use":
                continue
            tool_input = part.get("input") or {}
            if part.get("name") in ("Agent", "Task"):
                models[tool_input.get("model") or "(none)"] += 1
                agent_types[tool_input.get("subagent_type") or "general-purpose"] += 1
            elif part.get("name") == "Bash":
                head = (tool_input.get("command") or "").strip().split()
                if head:
                    bash_heads[head[0]] += 1
    if count:
        prompts += count
        sessions.append({"project": path.parent.name, "peak": peak, "days": len(days), "prompts": count})

print(f"Last {DAYS} days: {len(sessions)} sessions, {prompts} prompts")
print(f"Sessions over 400k context: {sum(s['peak'] > 400_000 for s in sessions)}")
print(f"Sessions with 40+ prompts: {sum(s['prompts'] >= 40 for s in sessions)}")
print(f"Sessions across days: {sum(s['days'] > 1 for s in sessions)}")
print(f"Correction rate (rough): {corrections / prompts:.0%}" if prompts else "Correction rate: n/a")
print("Agent models:", dict(models.most_common()))
print("Agent types:", dict(agent_types.most_common(6)))
print("Top Bash commands:", dict(bash_heads.most_common(10)))
print("Projects:", dict(Counter(s["project"] for s in sessions).most_common(5)))
