#!/usr/bin/env python3
"""Compile a compact harness briefing from the memory/state files.

Usage: compile-briefing.py <harness-dir> [--features-only]

Shared by the SessionStart hook (cold-start context) and the /start skill
(dynamic `!` injection). Prints markdown; prints nothing if no state exists.
"""
import json
import os
import sys


def load(path):
    try:
        with open(path) as f:
            return json.load(f)
    except Exception:
        return None


def main():
    if len(sys.argv) < 2:
        return
    harness = sys.argv[1]
    features_only = "--features-only" in sys.argv[2:]
    parts = []

    # 1. Active features (id, name, status, criteria count)
    data = load(os.path.join(harness, "features", "active.json")) or {}
    feats = data.get("features", [])
    if feats:
        parts.append("## Active Features")
        for feat in feats[:10]:
            line = "- {}: {} [{}]".format(
                feat.get("id", "?"), feat.get("name", "?"), feat.get("status", "?")
            )
            desc = feat.get("description", "")
            if desc:
                line += "\n  " + desc[:100]
            ac = feat.get("acceptanceCriteria", [])
            if ac:
                line += "\n  Acceptance: {} scenarios".format(len(ac))
            parts.append(line)

    if features_only:
        print("\n".join(parts))
        return

    # 2. Recent decisions from episodic memory (last 5)
    data = load(os.path.join(harness, "memory", "episodic", "decisions.json")) or {}
    entries = data.get("entries", [])[-5:]
    if entries:
        parts.append("## Recent Decisions")
        for e in reversed(entries):
            dec = str(e.get("decision", "?"))[:80]
            feat = e.get("feature", "")
            parts.append("- " + dec + (" ({})".format(feat) if feat else ""))

    # 3. Failures to avoid (last 3)
    data = load(os.path.join(harness, "memory", "procedural", "failures.json")) or {}
    entries = data.get("entries", [])[-3:]
    if entries:
        parts.append("## Approaches to AVOID")
        for e in reversed(entries):
            parts.append(
                "- {} -> {}".format(
                    str(e.get("approach", "?"))[:60], str(e.get("rootCause", "?"))[:60]
                )
            )

    # 4. Learned rules (active, up to 5)
    data = load(os.path.join(harness, "memory", "learned", "rules.json")) or {}
    rules = [r for r in data.get("rules", []) if r.get("active", True)][:5]
    if rules:
        parts.append("## Learned Rules")
        for r in rules:
            desc = str(r.get("description", ""))[:60]
            parts.append("- " + str(r.get("title", "?")) + (": " + desc if desc else ""))

    # 5. Last session summary
    data = load(os.path.join(harness, "claude-progress.json")) or {}
    summary = data.get("summary", "") or (data.get("lastSession", {}) or {}).get("summary", "")
    if summary:
        parts.append("## Last Session\n" + str(summary)[:200])

    output = "\n".join(parts)
    print("\n".join(output.split("\n")[:120]))


if __name__ == "__main__":
    main()
