import json


def entries(path):
    try:
        with open(path, errors="ignore") as transcript:
            for line in transcript:
                try:
                    yield json.loads(line)
                except ValueError:
                    continue
    except (OSError, TypeError):
        return


def is_real_prompt(entry):
    if entry.get("type") != "user" or entry.get("isMeta") or entry.get("isSidechain") or entry.get("isCompactSummary"):
        return False
    content = (entry.get("message") or {}).get("content")
    if isinstance(content, list):
        if any(isinstance(part, dict) and part.get("type") == "tool_result" for part in content):
            return False
        content = " ".join(part.get("text", "") for part in content if isinstance(part, dict))
    if not isinstance(content, str) or content.strip() == "":
        return False
    return not content.startswith("<") or content.startswith("<command-name>")
