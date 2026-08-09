#!/usr/bin/env python3
"""Extract the user's messages from a Claude Code session transcript.

Decisions live in what the user said — their corrections, rejections and
"нет, не так". Those messages are a small fraction of a transcript that is
mostly tool output, so pulling them out turns an unreadable 60 MB file into
something a reader (or a subagent) can go through in one pass.

Usage:
    extract-session-messages.py <transcript.jsonl> [output.txt]

Prints a summary; writes numbered messages to the output file (default:
alongside the transcript as <name>-messages.txt).
"""

import json
import sys
from pathlib import Path

# Long pastes are almost always logs or command output the user dropped in for
# diagnosis. The decision, if any, is stated at the top.
MAX_CHARS = 4000


def extract(transcript: Path, out: Path) -> int:
    messages = []
    for line_no, line in enumerate(transcript.open(encoding="utf-8", errors="replace")):
        try:
            entry = json.loads(line)
        except ValueError:
            continue
        if entry.get("type") != "user":
            continue
        content = (entry.get("message") or {}).get("content")
        if isinstance(content, list):
            content = " ".join(
                part.get("text", "") for part in content if isinstance(part, dict)
            )
        if not isinstance(content, str) or not content.strip():
            continue
        # Tool results and system-injected blocks are not the user talking.
        if content.startswith("<") or "tool_use_id" in content:
            continue
        messages.append(
            f"--- #{len(messages) + 1} (line {line_no}) ---\n{content[:MAX_CHARS]}"
        )

    out.write_text("\n\n".join(messages), encoding="utf-8")
    return len(messages)


def main() -> int:
    if len(sys.argv) < 2:
        print(__doc__.strip(), file=sys.stderr)
        return 2
    transcript = Path(sys.argv[1]).expanduser()
    if not transcript.exists():
        print(f"no such transcript: {transcript}", file=sys.stderr)
        return 1
    out = (
        Path(sys.argv[2]).expanduser()
        if len(sys.argv) > 2
        else transcript.with_name(transcript.stem + "-messages.txt")
    )
    count = extract(transcript, out)
    size_mb = transcript.stat().st_size / 1024 / 1024
    print(f"{count} messages from {size_mb:.1f} MB → {out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
