#!/usr/bin/env python3
"""Compile a compact harness briefing from the memory bundle and state files.

Usage: compile-briefing.py <harness-dir> [--features-only] [--write]

Shared by the SessionStart hook (cold-start context) and the /start skill
(dynamic `!` injection). Prints markdown; prints nothing if no state exists.
With --write, also writes the briefing to <harness-dir>/session-briefing.md.

Memory layers are read from the OKF v0.1 bundle at <harness-dir>/memory/
(one markdown concept file per entry, YAML frontmatter with a `type` field).
Legacy JSON memory files (pre-OKF) are used as a fallback so the briefing
still works on projects that have not run the setup.sh migration yet.
"""
import json
import os
import sys

RESERVED = {"index.md", "log.md"}


def load(path):
    try:
        with open(path) as f:
            return json.load(f)
    except Exception:
        return None


def parse_concept(path):
    """Parse an OKF concept file -> dict of frontmatter fields + body sections.

    Frontmatter keys land as-is (string values, quotes stripped). Body
    `## Heading` sections land under 'section:<lowercased heading>'.
    Unknown keys and value types are tolerated per OKF v0.1.
    """
    try:
        with open(path, encoding="utf-8") as f:
            lines = f.read().splitlines()
    except Exception:
        return None
    data = {}
    i = 0
    if lines and lines[0].strip() == "---":
        i = 1
        while i < len(lines) and lines[i].strip() != "---":
            line = lines[i]
            if ":" in line and not line.startswith((" ", "\t", "-", "#")):
                key, _, value = line.partition(":")
                value = value.strip()
                if len(value) >= 2 and value[0] == value[-1] and value[0] in "\"'":
                    value = value[1:-1]
                data[key.strip()] = value
            i += 1
        i += 1
    section = None
    body = {}
    for line in lines[i:]:
        if line.startswith("## "):
            section = "section:" + line[3:].strip().lower()
            body[section] = []
        elif line.startswith("# ") and "heading" not in data:
            data["heading"] = line[2:].strip()
        elif section and line.strip():
            body[section].append(line.strip())
    for key, value in body.items():
        data[key] = " ".join(value)
    return data


def read_concepts(bundle_dir):
    """Read all concept files in a bundle directory, sorted by timestamp/name."""
    if not os.path.isdir(bundle_dir):
        return []
    concepts = []
    for name in sorted(os.listdir(bundle_dir)):
        if not name.endswith(".md") or name in RESERVED or name.startswith("."):
            continue
        c = parse_concept(os.path.join(bundle_dir, name))
        if c is not None:
            c["_file"] = name
            concepts.append(c)
    concepts.sort(key=lambda c: (c.get("timestamp", ""), c["_file"]))
    return concepts


def concept_title(c):
    return c.get("title") or c.get("heading") or c["_file"]


def main():
    if len(sys.argv) < 2:
        return
    harness = sys.argv[1]
    features_only = "--features-only" in sys.argv[2:]
    write = "--write" in sys.argv[2:]
    memory = os.path.join(harness, "memory")
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

    # 2. Recent decisions (last 5) from memory/decisions/ (OKF bundle)
    decisions = read_concepts(os.path.join(memory, "decisions"))
    if not decisions:  # legacy JSON fallback (pre-OKF projects)
        data = load(os.path.join(memory, "episodic", "decisions.json")) or {}
        decisions = [
            {"title": e.get("decision", "?"), "feature": e.get("feature") or "", "_file": ""}
            for e in data.get("entries", [])
        ]
    if decisions:
        parts.append("## Recent Decisions")
        for c in reversed(decisions[-5:]):
            feat = c.get("feature", "")
            parts.append(
                "- " + str(concept_title(c))[:80] + (" ({})".format(feat) if feat else "")
            )

    # 3. Failures to avoid (last 3) from memory/failures/
    failures = read_concepts(os.path.join(memory, "failures"))
    if not failures:
        data = load(os.path.join(memory, "procedural", "failures.json")) or {}
        failures = [
            {"title": e.get("approach", "?"), "section:root cause": e.get("rootCause", "?"), "_file": ""}
            for e in data.get("entries", [])
        ]
    if failures:
        parts.append("## Approaches to AVOID")
        for c in reversed(failures[-3:]):
            root = c.get("section:root cause") or c.get("rootCause") or "?"
            parts.append(
                "- {} -> {}".format(str(concept_title(c))[:60], str(root)[:60])
            )

    # 4. Learned rules (active, up to 5) from memory/rules/
    rules = read_concepts(os.path.join(memory, "rules"))
    if not rules:
        data = load(os.path.join(memory, "learned", "rules.json")) or {}
        rules = [
            {"title": r.get("title", "?"), "description": r.get("description", ""),
             "active": "false" if r.get("active", True) is False else "true", "_file": ""}
            for r in data.get("rules", [])
        ]
    rules = [r for r in rules if str(r.get("active", "true")).lower() != "false"][:5]
    if rules:
        parts.append("## Learned Rules")
        for r in rules:
            desc = str(r.get("description", ""))[:60]
            parts.append("- " + str(concept_title(r)) + (": " + desc if desc else ""))

    # 5. Last session summary
    data = load(os.path.join(harness, "claude-progress.json")) or {}
    summary = data.get("summary", "") or (data.get("lastSession", {}) or {}).get("summary", "")
    if summary:
        parts.append("## Last Session\n" + str(summary)[:200])

    output = "\n".join(parts)
    output = "\n".join(output.split("\n")[:120])
    print(output)

    if write and output:
        try:
            from datetime import datetime, timezone

            stamp = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
            with open(os.path.join(harness, "session-briefing.md"), "w") as f:
                f.write("# Session Briefing\nLast updated: {}\n\n{}\n".format(stamp, output))
        except Exception:
            pass


if __name__ == "__main__":
    main()
